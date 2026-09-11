# Phase 6 Group E — Validate + Verify + Dashboard (Step 6.5)

> **Entry condition:** Group D POST-GATE PASS (fix-report + docs-sync-report written bởi execute agent).
> **Exit condition:** POST-GATE T1-T4 PASS, counts extracted, bug-dashboard updated.
> **Next:** [phase6-execute/F-report.md](F-report.md) (Phase Report).
>
> **Shared protocols cần thiết:** None (script delegation only).

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$TOTAL_ISSUES` | Pipeline state |
| `phase6-execute/{fix-report.md, docs-sync-report.json}` | Execute agent outputs |
| `phase5-triage/fix-log.json` | Fix log để append entries |

## Output contract (env vars truyền sang Group F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `FIXED_COUNT`, `DEFERRED_COUNT`, `FAILED_COUNT` | 6.5 | Counts extracted từ fix-report.md |
| `FILES_CHANGED` | 6.5 | Số files thay đổi (git diff --name-only) |
| `phase6-execute/git-diff-files.txt`, `git-diff-stat.txt` | 6.5 | Git diff outputs |
| `bug-dashboard.md` regenerated | 6.5 | Inline regen (match v10.7 pattern) |

---

## Step 6.5 — Validate + Verify + Update Dashboard + Fix Iteration Loop (v11)

**Mục đích:** Gộp 4 việc:
- (a) POST-GATE T1-T4 + extract counts + git diff + update bug-dashboard (v10.x)
- (b) **v11 NEW**: Detect unsanctioned defers qua `verify-defer-reasons.sh`
- (c) **v11 NEW**: Decide fix iteration loop qua `fix-iteration-loop.sh`
- (d) **v11 NEW**: Branching — re-spawn execute (loop) / CDG E095 (escalate) / advance (done)

```bash
export TOTAL_ISSUES   # từ Group A (Step 6.1)

# v10.10.0 fix: Enforce max-1-retry qua persistent counter (file-based).
RETRY_FILE="$SESSION_DIR/phase6-execute/.retry-count-step-6.5"
RETRY_COUNT=$(cat "$RETRY_FILE" 2>/dev/null || echo 0)

PHASE6_S7=$(bash .claude/scripts/wf-fix-bugs/verify-execute-outputs.sh) || RC=$?

if [ "${RC:-0}" -eq 4 ]; then
  if [ "$RETRY_COUNT" -ge 1 ]; then
    echo "E060: POST-GATE FAIL sau retry — auto-fix budget exhausted (CORE-034)" >&2
    # APPEND error-ledger trước khi escalate
    {
      jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{phase:"phase6", error_code:"E060", message:"verify-execute-outputs fail sau retry", timestamp:$ts, retry_count:'"$RETRY_COUNT"'}'
    } >> "$SESSION_DIR/error-ledger.json" 2>/dev/null || true
    exit 1
  fi
  echo "$((RETRY_COUNT + 1))" > "$RETRY_FILE"
  echo "POST-GATE FAIL: re-spawn wf-fix-execute x1 (Auto-Fix Budget CORE-034)"
  # Orchestrator re-run Group D + E — max 1 lần (enforced bởi $RETRY_FILE)
fi

# Export counts để Group F + G dùng
FIXED_COUNT=$(echo "$PHASE6_S7" | jq -r '.fixed_count')
DEFERRED_COUNT=$(echo "$PHASE6_S7" | jq -r '.deferred_count')
FAILED_COUNT=$(echo "$PHASE6_S7" | jq -r '.failed_count')
FILES_CHANGED=$(echo "$PHASE6_S7" | jq -r '.files_changed')
export FIXED_COUNT DEFERRED_COUNT FAILED_COUNT FILES_CHANGED
```

Script thực hiện:
- **POST-GATE T1-T4** (CORE-012): T1 file existence, T2 markdown headers, T3 docs-sync JSON valid, T4 fix-result keywords (fixed|resolved|repaired|dry|deferred|failed)
- **Verify counts**: extract Fixed/Deferred/Failed từ fix-report.md (regex multi-format)
- **Git diff**: `git diff --name-only` + `git diff --stat` ghi vào `git-diff-files.txt` + `git-diff-stat.txt`
- **Dashboard update**: append entry vào `fix-log.json` (atomic) + regenerate `bug-dashboard.md` (inline, match v10.7 pattern)

**VERIFY:**

```bash
ALL_PASS=$(echo "$PHASE6_S7" | jq -r '.post_gate.all_pass')
[ "$ALL_PASS" = "true" ]
test -s "$SESSION_DIR/bug-dashboard.md"
jq -e '.entries | length > 0' "$SESSION_DIR/phase5-triage/fix-log.json"
```

---

### Step 6.5b — Fix Iteration Loop (v11 — Wave 2 G2+G3)

**Mục đích:** Detect unsanctioned defers + decide re-spawn execute với scope thu hẹp, hoặc CDG E095 escalate khi exhaust budget.

**Skip nếu**: `MCV3_FIX_LOOP_DISABLE=true` (backward-compat v10.x behavior).

```bash
# (b) Detect unsanctioned defers
bash .claude/scripts/wf-fix-bugs/verify-defer-reasons.sh > /dev/null 2>&1 || {
  echo "WARN(v11): verify-defer-reasons.sh fail — skip loop, continue legacy" >&2
  # Fall through to legacy finalize (Group F)
}

# (c) Decide loop action
if [ -s "$SESSION_DIR/phase6-execute/unsanctioned-defers.json" ]; then
  LOOP_DECISION=$(bash .claude/scripts/wf-fix-bugs/fix-iteration-loop.sh 2>/dev/null)
  DECISION=$(echo "$LOOP_DECISION" | jq -r '.decision')
  NEXT_ACTION=$(echo "$LOOP_DECISION" | jq -r '.next_action')
  CURRENT_ITER=$(echo "$LOOP_DECISION" | jq -r '.current_iteration')
  UNSANCT_COUNT=$(echo "$LOOP_DECISION" | jq -r '.unsanctioned_count')

  echo "INFO(v11): Loop $DECISION (iter=$CURRENT_ITER, unsanctioned=$UNSANCT_COUNT)"

  case "$NEXT_ACTION" in
    spawn_execute_with_unsanctioned)
      # (d-1) Re-spawn execute với SCOPE THU HẸP — chỉ unsanctioned items
      # Pass UNSANCT_COUNT vào agent prompt + sample items từ unsanctioned-defers.json
      echo "INFO(v11): Re-spawn wf-fix-execute iteration $CURRENT_ITER với $UNSANCT_COUNT unsanctioned items"
      # ORCHESTRATOR GOTO Group D (D-spawn-execute) với context:
      #   - LOOP_ITERATION=$CURRENT_ITER (inject vào prompt)
      #   - UNSANCTIONED_FOCUS=true (skip non-unsanctioned items)
      #   - SAMPLE_ISSUES từ phase6-execute/unsanctioned-defers.json
      # Sau khi execute done → quay lại Step 6.5 (rerun verify + loop)
      # CHÚ Ý: phải break loop nếu fix-execution-result.json không thay đổi
      # giữa 2 iterations (prevent infinite spin)
      ;;
    ask_user_question)
      # (d-2) CDG E095 — budget exhausted, hỏi user
      # SEE: Step 6.5c CDG E095 INLINE block dưới
      :
      ;;
    finalize_phase6|finalize_phase6_legacy)
      # (d-3) Done — advance to Group F
      echo "INFO(v11): Loop $DECISION — advance to Phase Report"
      ;;
  esac
fi
```

---

### Step 6.5c — CDG E095 Escalation (v11 — INLINE AskUserQuestion)

> **⚠ GIỮ ORCHESTRATOR-SIDE — KHÔNG extract sang script:** AskUserQuestion tool call. KHÔNG script được.
>
> **Trigger condition:** `$NEXT_ACTION = "ask_user_question"` (sau MAX_ITER iterations vẫn còn unsanctioned defers).

**CDG E095 prompt:**

```javascript
AskUserQuestion({
  questions: [{
    question: `Phase 6 còn ${UNSANCT_COUNT} items defer dù được phép fix sau ${CURRENT_ITER} iterations. Hành động?`,
    header: "Defer escalation",
    multiSelect: false,
    options: [
      {
        label: "Force-fix với expert agent (Recommended)",
        description: "Spawn domain expert agent (architect / security / domain-expert) cố fix manual scope thu hẹp. +1 iteration ngoài budget."
      },
      {
        label: "Accept defer — ghi vào fix-blockers.md",
        description: "Mark items là 'requires_human_decision' để sprint planning. Pipeline tiếp tục Phase 7 với defer_count tăng."
      },
      {
        label: "Spawn cross-scope session ngay",
        description: "Mở /wf-fix-bugs --scope=cross-module session mới (Wave 3 G4 sẽ chuẩn hóa flow này). Pipeline hiện tại finalize với DONE_NEEDS_FOLLOWUP."
      }
    ]
  }]
})
```

**After user answer:**

```bash
# Ghi decision vào cdg-tokens.json + fix-iterations.json
USER_CHOICE="<from AskUserQuestion answer>"

# Append CDG token
TMP="$SESSION_DIR/phase5-triage/cdg-tokens.json.tmp.$$"
jq --arg gate "E095" --arg dec "$USER_CHOICE" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.tokens += [{gate: $gate, decision: $dec, timestamp: $ts, unsanctioned_count: '"$UNSANCT_COUNT"'}]' \
   "$SESSION_DIR/phase5-triage/cdg-tokens.json" > "$TMP" \
  && mv "$TMP" "$SESSION_DIR/phase5-triage/cdg-tokens.json"

# Update fix-iterations.json với cdg_token
jq --arg gate "E095" --arg dec "$USER_CHOICE" \
   '.cdg_token = {gate: $gate, decision: $dec}' \
   "$SESSION_DIR/phase6-execute/fix-iterations.json" > "$TMP" \
  && mv "$TMP" "$SESSION_DIR/phase6-execute/fix-iterations.json"

# Route theo USER_CHOICE
case "$USER_CHOICE" in
  *Force-fix*)
    # +1 iteration ngoài budget với expert agent
    # Reset .fix-iteration-count để allow +1
    # GOTO Group D với EXPERT_OVERRIDE=true
    ;;
  *Accept*|*Spawn*)
    # Advance to Group F (Phase Report) → finalize
    ;;
esac
```

---

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E060 | T1 fail (file missing) | Re-spawn agent x1 → escalate |
| E060 | T2 fail (structure wrong) | Re-spawn x1 với prompt nhấn schema |
| E060 | T3 fail (content shallow) | Re-spawn x1 với more context |
| E061 | T4 fail (cross-ref missing) | WARN — có thể continue nếu T1-T3 pass |
| E065 | Dashboard write fail | WARN — non-critical, continue |

**Cross-ref:** CORE-012 (POST-GATE T1-T4), CORE-034 (Auto-Fix Budget), CORE-031 (Template), CORE-035.

---

## Group E POST-GATE Verify

```bash
test -s "$SESSION_DIR/bug-dashboard.md" && \
jq -e '.entries | length > 0' "$SESSION_DIR/phase5-triage/fix-log.json" >/dev/null && \
test -n "$FIXED_COUNT" && test -n "$DEFERRED_COUNT" && test -n "$FAILED_COUNT" && \
  echo "Group E PASS" || echo "Group E FAIL"
```

## Next Group

→ Group F Phase Report — đọc [`phase6-execute/F-report.md`](F-report.md)
