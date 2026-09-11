# Phase 7 Group F — Finalize Pipeline (Step 7.6)

> **Entry condition:** Group E POST-GATE PASS (4 reports + fix-impact.json schema valid).
> **Exit condition:** `fix-status.pipeline_status = DONE` + `phase7.status = completed` + TRACE COMPLETE event appended (both session + global trace).
> **Next:** [phase7-verify/G-todowrite-display.md](G-todowrite-display.md) (TodoWrite + Completion Display UI tools).
>
> **Shared protocols cần thiết:**
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — Dual-write pattern (session + global trace)
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E075

> **⚠ SPECIAL CASE — KHÔNG migrate sang `phase-finalize.sh`:** Phase 7 finalize có 2 đặc thù khác Phase 5/6:
> 1. `fix-status.pipeline_status=DONE` đã được **pre-finalize** ở Step 7.5 (qua generate-phase7-reports.sh) để audit_chain checksum trong `fix-impact.json` phản ánh trạng thái FINAL (CORE-036 integrity).
> 2. **Dual-write global trace** `.mc-data/work/_trace/session-log.json` (CORE-026 dual-write) — phase-finalize.sh chỉ session-local.
>
> → Migration sang phase-finalize.sh defer (cần adapter). Giữ nguyên `finalize-phase7.sh`.

## Input contract (env vars từ Group E)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID`, `$REPO_ROOT` | Session identity |
| `$E005_HEALTHY`, `$TOTAL_ISSUES`, `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT` | Counts |
| `phase7-verify/{orchestrator-summary.md, fix-impact.json, phase-summary.md, Phase7-report.md}` | Group E outputs |

## Output contract (env vars truyền sang Group G)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `fix-status.pipeline_status = DONE` | 7.6 | Idempotent re-verify (đã pre-finalize ở Step 7.5) |
| `fix-status.phase7.status = completed` | 7.6 | Atomic update với completed_at |
| TRACE COMPLETE session-log | 7.6 | events[-1].phase = "phase7" event = "COMPLETE" |
| TRACE COMPLETE global trace | 7.6 | `.mc-data/work/_trace/session-log.json` dual-write |

---

## Step 7.6 — Finalize Phase 7 (Pipeline DONE + TRACE COMPLETE)

**Mục đích:** Mark `pipeline_status=DONE` + APPEND COMPLETE event (gộp 7.10+7.11 logic legacy). Dual-write session log + global trace.

```bash
export SESSION_ID E005_HEALTHY TOTAL_ISSUES FIXED_COUNT DEFERRED_COUNT FAILED_COUNT REPO_ROOT
PHASE7_S6=$(bash .claude/scripts/wf-fix-bugs/finalize-phase7.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  echo "ERROR: finalize fail (E075)" >&2
  exit "$RC"
fi
```

Script:
1. **v10.10.0 idempotent re-verify:** `fix-status.pipeline_status=DONE` đã được pre-finalize bởi Step 7.5 (generate-phase7-reports.sh) để checksum trong `fix-impact.json` phản ánh trạng thái FINAL. Step 7.6 chỉ idempotent re-verify (atomic update nếu vẫn còn in_progress).
2. APPEND COMPLETE event vào `session-log.json` (CORE-026)
3. **Dual-write** global trace `.mc-data/work/_trace/session-log.json` (CORE-026 dual-write — phase-local + global)
4. Update `phase7.status = completed` + `completed_at`

**VERIFY:**

```bash
jq -e '.phases.phase7.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.pipeline_status == "DONE"' "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase7.completed_at != null' "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == "phase7" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E075 | Atomic write fail (exit 3) | Retry x1 → `_phase7_trace_fail "E075"` → E001 |
| E075 | Trace dual-write fail | WARN — không block (output-only, CORE-026) |

**Cross-ref:** CORE-035 (Atomic Write), CORE-026 (Execution Trace dual-write), CORE-006 (Registry Safe-Write).

---

## Group F POST-GATE Verify

```bash
jq -e '.phases.phase7.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null && \
jq -e '.pipeline_status == "DONE"' "$SESSION_DIR/fix-status.json" >/dev/null && \
jq -e '.events[-1].phase == "phase7" and .events[-1].event == "COMPLETE"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group F PASS (pipeline DONE)" || echo "Group F FAIL"
```

## Next Group

→ Group G TodoWrite + Completion Display — đọc [`phase7-verify/G-todowrite-display.md`](G-todowrite-display.md)
