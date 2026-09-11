# Phase 3 Group F — Finalize (Step 3.7)

> **Entry condition:** Group E POST-GATE PASS (Phase3-report.md written).
> **Exit condition:** `fix-status.phase3 = completed` + TRACE COMPLETE event appended.
> **Next:** [phase3-plan/POST-GATE.md](POST-GATE.md) (T1-T4 validation) → Phase 4.
>
> **Shared protocols cần thiết:**
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE event pattern (reference only)

## Input contract (env vars từ Group E)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$REFINED_DIMS`, `$WORKLOAD_COUNT`, `$EXECUTION_MODE` | Plan state để ghi vào fix-status |

## Output contract (env vars truyền sang POST-GATE)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `fix-status.phase3 = completed` | 3.7 | Atomic update với dimensions/workload_count/execution_mode |
| TRACE COMPLETE event appended | 3.7 | session-log.json events[-1].phase = "phase3" event = "COMPLETE" |

---

## Step 3.7 — Finalize (delegated to phase-finalize.sh)

> **v10.16.0:** Inline `jq fix-status update + events += [...]` block thay bằng `phase-finalize.sh` (shared cho Phase 2-7). Combines TRACE COMPLETE + atomic fix-status update vào 1 script call.

**Mục đích:** Atomic update fix-status.json (mark phase3 completed) + append COMPLETE event vào session-log.json + global trace dual-write.

```bash
# Prepare extra fields cho phases.phase3
PHASE_EXTRA_FIELDS=$(jq -n \
  --arg dims "$REFINED_DIMS" \
  --argjson wc "$WORKLOAD_COUNT" \
  --arg mode "$EXECUTION_MODE" \
  '{dimensions: ($dims | split(",")), workload_count: $wc, execution_mode: $mode}')

# Delegate dual-write trace + fix-status update
SESSION_DIR="$SESSION_DIR" PHASE_NUM=3 \
  PHASE_EXTRA_FIELDS="$PHASE_EXTRA_FIELDS" \
  bash .claude/scripts/wf-fix-bugs/phase-finalize.sh
```

**VERIFY:**

```bash
jq -e '.phases.phase3.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase3.execution_mode' "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == "phase3" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json"
```

**On Failure:** E035 — Retry Atomic Write x1, escalate E001.

**Cross-ref:** CORE-026 (Execution Trace), CORE-035 (Atomic Write).

---

## Group F POST-GATE Verify

```bash
jq -e '.phases.phase3.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null && \
jq -e '.events[-1].phase == "phase3" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group F PASS" || echo "Group F FAIL"
```

## Next: Phase 3 POST-GATE

→ Đọc [`phase3-plan/POST-GATE.md`](POST-GATE.md) để validate T1-T4 trước khi advance Phase 4.
