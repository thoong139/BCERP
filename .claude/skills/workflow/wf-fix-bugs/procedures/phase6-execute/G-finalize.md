# Phase 6 Group G — Finalize (Step 6.7 + 6.7b)

> **Entry condition:** Group F POST-GATE PASS (Phase6-report.md written).
> **Exit condition:** `fix-status.phase6 = completed` + TRACE COMPLETE event appended.
> **Next:** [phase6-execute/POST-GATE.md](POST-GATE.md) (T1-T5 validation) → Phase 7.
>
> **Steps:**
> - **6.7** — Core finalize (TRACE COMPLETE + atomic fix-status update)
> - **6.7b** — **v11.2.0 NEW**: CDG E096 Cross-Scope Detection + Follow-up Queue
>
> **Shared protocols cần thiết:**
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE event pattern (reference only)
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG render pattern (Step 6.7b)

## Input contract (env vars từ Group F)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT`, `$FILES_CHANGED` | Counts để ghi vào fix-status |
| `$DRY_RUN` | Set reason="dry_run" nếu true |

## Output contract (env vars truyền sang POST-GATE)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `fix-status.phase6 = completed` | 6.7 | Atomic update với fixed/deferred/failed_total/files_changed |
| TRACE COMPLETE event appended | 6.7 | session-log.json events[-1].phase = "phase6" event = "COMPLETE" |

---

## Step 6.7 — Finalize Phase 6 (delegated to phase-finalize.sh)

> **v10.16.0:** Inline `finalize-phase6.sh` được thay bằng shared `phase-finalize.sh` để consistency cross-phase. Combines TRACE COMPLETE + atomic fix-status update vào 1 script call.

**Mục đích:** Mark Phase 6 completed + APPEND COMPLETE event.

```bash
# Prepare extra fields cho phases.phase6
if [ "$DRY_RUN" = "true" ]; then
  PHASE_EXTRA_FIELDS=$(jq -n \
    --argjson fixed "${FIXED_COUNT:-0}" \
    --argjson deferred "${DEFERRED_COUNT:-0}" \
    --argjson failed "${FAILED_COUNT:-0}" \
    --argjson files "${FILES_CHANGED:-0}" \
    '{fixed_total: $fixed, deferred_total: $deferred, failed_total: $failed, files_changed: $files, reason: "dry_run"}')
else
  PHASE_EXTRA_FIELDS=$(jq -n \
    --argjson fixed "${FIXED_COUNT:-0}" \
    --argjson deferred "${DEFERRED_COUNT:-0}" \
    --argjson failed "${FAILED_COUNT:-0}" \
    --argjson files "${FILES_CHANGED:-0}" \
    '{fixed_total: $fixed, deferred_total: $deferred, failed_total: $failed, files_changed: $files, execution_mode: "agent_dispatch"}')
fi

# Delegate dual-write trace + fix-status update
SESSION_DIR="$SESSION_DIR" PHASE_NUM=6 \
  PHASE_EXTRA_FIELDS="$PHASE_EXTRA_FIELDS" \
  bash .claude/scripts/wf-fix-bugs/phase-finalize.sh
```

**VERIFY:**

```bash
jq -e '.phases.phase6.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase6.fixed_total >= 0' "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == "phase6" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E001 | Atomic write fail (exit 3) | Retry build tmp x1 |

**Cross-ref:** CORE-035, CORE-026, CORE-006.

---

## Step 6.7b — CDG E096 Cross-Scope Detection + Follow-up Queue (v11.2.0 — Wave 3 G4)

> **⚠ GIỮ ORCHESTRATOR-SIDE — INLINE:** Bước này có 2 phần:
> 1. Script delegation (detect-cross-scope.sh + enqueue-followup.sh) — chạy bash bình thường.
> 2. CDG E096 AskUserQuestion render — KHÔNG extract script được (require tool call).
>
> **Skip nếu**: `MCV3_FIX_CROSS_SCOPE_DISABLE=true` (backward-compat tránh trigger CDG).
>
> **Anti-loop guard**: ghi decision vào `error-ledger.json` + `cdg-tokens.json` với gate=E096, KHÔNG re-fire trong cùng session.
>
> **Position**: Sau Step 6.7 (Group G core finalize), TRƯỚC POST-GATE T1-T5.

**Mục đích:**

Detect cross-scope issues (issues không thuộc current scope nhưng tồn tại trong registry — vd: scope=module=settings nhưng issue file path ở `customs/`). Hỏi user (qua CDG E096) cách xử lý:
- Spawn cross-scope session ngay
- Enqueue follow-up (chỉ thêm vào queue, user xử lý sau)
- Ignore (chấp nhận backlog)

**Phần 1 — Detection (script delegation):**

```bash
# Skip toàn bộ nếu disabled
if [ "${MCV3_FIX_CROSS_SCOPE_DISABLE:-false}" = "true" ]; then
  echo "INFO(v11.2): CDG E096 skipped (MCV3_FIX_CROSS_SCOPE_DISABLE=true)"
else
  # Anti-loop: check if E096 đã fire trong session này
  E096_FIRED=$(jq -r --arg sid "$SESSION_ID" \
    '[.tokens[]? | select(.gate == "E096")] | length' \
    "$SESSION_DIR/phase5-triage/cdg-tokens.json" 2>/dev/null || echo 0)

  if [ "$E096_FIRED" -gt 0 ]; then
    echo "INFO(v11.2): CDG E096 đã fire trong session này — skip (anti-loop)"
  else
    # Step 1: Build id-mapping.json (bridge 3 ID schemes)
    bash .claude/scripts/wf-fix-bugs/build-id-mapping.sh > /dev/null 2>&1 || {
      echo "WARN(v11.2): build-id-mapping fail — continue without canonical ID lookup" >&2
    }

    # Step 2: Detect cross-scope items
    CROSS_SCOPE_JSON=$(bash .claude/scripts/wf-fix-bugs/detect-cross-scope.sh 2>/dev/null) || {
      echo "WARN(v11.2): detect-cross-scope fail — skip CDG E096" >&2
      CROSS_SCOPE_JSON='{"cross_scope_count":0,"should_trigger_cdg":false,"items":[]}'
    }

    CROSS_COUNT=$(echo "$CROSS_SCOPE_JSON" | jq -r '.cross_scope_count // 0')
    SHOULD_TRIGGER=$(echo "$CROSS_SCOPE_JSON" | jq -r '.should_trigger_cdg // false')

    echo "INFO(v11.2): cross_scope_count=$CROSS_COUNT should_trigger_cdg=$SHOULD_TRIGGER (threshold=${MCV3_FIX_CROSS_SCOPE_THRESHOLD:-3})"

    export CROSS_SCOPE_JSON CROSS_COUNT SHOULD_TRIGGER
  fi
fi
```

**Phần 2 — CDG E096 AskUserQuestion (orchestrator INLINE):**

> Trigger condition: `$SHOULD_TRIGGER = "true"` AND `$E096_FIRED == 0`.
>
> Type: **warning** (KHÔNG block POST-GATE — chỉ suggest). Pipeline tiếp tục dù user chọn gì.

```javascript
// Pseudo-code — orchestrator render AskUserQuestion với 3 options
AskUserQuestion({
  questions: [{
    question: `Phát hiện ${CROSS_COUNT} issue thuộc scope khác (cross-module). Xử lý thế nào?`,
    header: "Cross-scope",
    multiSelect: false,
    options: [
      {
        label: "Spawn cross-scope session ngay (Recommended)",
        description: "Echo lệnh `/wf-fix-bugs --scope=cross-module ...` để user copy + run. Đồng thời enqueue vào _followup-queue.jsonl. Pipeline hiện tại finalize với pipeline_status=DONE_NEEDS_FOLLOWUP."
      },
      {
        label: "Enqueue follow-up only",
        description: "Chỉ append entry vào _followup-queue.jsonl. User xử lý sau qua /status hoặc đọc queue tay. Pipeline finalize với DONE_NEEDS_FOLLOWUP."
      },
      {
        label: "Ignore — accept as backlog",
        description: "KHÔNG enqueue, mark items là known backlog. Pipeline finalize bình thường (DONE_CLEAN/DONE_WITH_DEFERRED tùy deferred_total)."
      }
    ]
  }]
})
```

**Phần 3 — Handle user answer + enqueue:**

```bash
# Sau khi user trả lời (USER_CHOICE = "spawn" | "enqueue" | "ignore")
USER_CHOICE="<from AskUserQuestion answer>"  # Orchestrator extracts từ answer

# Append CDG token (anti-loop)
TMP="$SESSION_DIR/phase5-triage/cdg-tokens.json.tmp.$$"
jq --arg gate "E096" --arg dec "$USER_CHOICE" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson cnt "$CROSS_COUNT" \
   '.tokens += [{gate: $gate, decision: $dec, timestamp: $ts, cross_scope_count: $cnt}]' \
   "$SESSION_DIR/phase5-triage/cdg-tokens.json" > "$TMP" \
  && mv "$TMP" "$SESSION_DIR/phase5-triage/cdg-tokens.json"

# Build items file cho enqueue (items[] từ detect-cross-scope output)
ITEMS_FILE="$SESSION_DIR/_meta/cross-scope-items.json"
mkdir -p "$SESSION_DIR/_meta"
echo "$CROSS_SCOPE_JSON" | jq '.items' > "$ITEMS_FILE"

# Build suggested command (priority cao nhất từ items, fallback generic)
SUGGESTED_CMD=$(echo "$CROSS_SCOPE_JSON" | jq -r '.items[0].scope_command // "/wf-fix-bugs --scope=cross-module"')

case "$USER_CHOICE" in
  *spawn*|*Spawn*|*Recommended*)
    # Enqueue + echo command cho user run thủ công
    SOURCE_SESSION="$SESSION_ID" \
    KIND="cross_scope_fix" \
    SUGGESTED_COMMAND="$SUGGESTED_CMD" \
    PRIORITY="high" \
    ITEMS_JSON_FILE="$ITEMS_FILE" \
    bash .claude/scripts/wf-fix-bugs/enqueue-followup.sh > /dev/null

    echo "✅ Đã enqueue cross-scope items. Chạy lệnh sau để xử lý:"
    echo "   $SUGGESTED_CMD"
    ;;
  *enqueue*|*Enqueue*)
    # Chỉ enqueue, không echo command nổi bật
    SOURCE_SESSION="$SESSION_ID" \
    KIND="cross_scope_fix" \
    SUGGESTED_COMMAND="$SUGGESTED_CMD" \
    PRIORITY="high" \
    ITEMS_JSON_FILE="$ITEMS_FILE" \
    bash .claude/scripts/wf-fix-bugs/enqueue-followup.sh > /dev/null

    echo "✅ Đã append $CROSS_COUNT items vào _followup-queue.jsonl. User xem qua /status."
    ;;
  *ignore*|*Ignore*|*backlog*)
    # KHÔNG enqueue — chỉ log
    echo "INFO: Cross-scope items được mark là backlog ($CROSS_COUNT items)."
    ;;
esac
```

**VERIFY (sau khi handle answer):**

```bash
jq -e '.tokens[] | select(.gate == "E096")' \
  "$SESSION_DIR/phase5-triage/cdg-tokens.json" >/dev/null && \
  echo "E096 token recorded" || echo "WARN: E096 token missing"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E096 | detect-cross-scope.sh exit non-zero | WARN, skip CDG, continue |
| E096 | enqueue-followup.sh lock timeout (exit 3) | WARN, retry x1 sau 5s |
| E096 | cdg-tokens.json atomic write fail | WARN, continue (non-critical) |

**Cross-ref:** CORE-027 (CDG), CORE-034 (Error codes), CORE-036 (cross-skill artifact `_followup-queue.jsonl`).

---

## Group G POST-GATE Verify

```bash
jq -e '.phases.phase6.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null && \
jq -e '.events[-1].phase == "phase6" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group G PASS" || echo "Group G FAIL"
```

## Next: Phase 6 POST-GATE

→ Đọc [`phase6-execute/POST-GATE.md`](POST-GATE.md) để validate T1-T5 trước khi advance Phase 7.
