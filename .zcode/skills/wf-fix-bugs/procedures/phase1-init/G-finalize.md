# Phase 1 Group G — Finalize (Steps 1.17 → 1.18)

> **Entry condition:** Group F POST-GATE PASS (state files + dashboard initialized).
> **Exit condition:** TRACE START event recorded, TodoWrite 7-item list active.
> **Next:** [phase1-init/POST-GATE.md](POST-GATE.md) (Phase 1 POST-GATE validation) → Phase 2.
>
> **Shared protocols cần thiết:**
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE event pattern
> - [`_shared/11-task-planning.md`](../_shared/11-task-planning.md) — TodoWrite init pattern

## Input contract (env vars từ Group F)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$PROFILE`, `$SCOPE`, `$DIMS_ARRAY` | Pipeline config |
| State files initialized | Group F outputs |

## Output contract (env vars truyền sang Phase 2)

| Variable | Mô tả |
|----------|------|
| TRACE START event | Session-local + global trace |
| TodoWrite 7-item | Phase 1 in_progress, Phase 2-7 pending |
| Phase 1 status | `pipeline_status` = "in_progress" |

---

## Step 1.17 — TRACE START (delegated to script)

> **v10.14.0:** ~15 dòng inline bash extracted → `phase1-trace-start.sh` (~70 dòng).
>
> **Pattern canonical:** [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md).

```bash
# Delegate dual-write trace → silent on success
SESSION_DIR="$SESSION_DIR" SESSION_ID="$SESSION_ID" PROFILE="$PROFILE" SCOPE="$SCOPE" DIMS_ARRAY="$DIMS_ARRAY" \
  bash .claude/scripts/wf-fix-bugs/phase1-trace-start.sh
TRACE_EXIT=$?

# Verify session-local trace event appended
if [ "$TRACE_EXIT" -eq 0 ]; then
  jq -e '.events | length > 0' "$SESSION_DIR/session-log.json" >/dev/null
  jq -e '.events[-1].phase == 1 and .events[-1].event == "START"' "$SESSION_DIR/session-log.json" >/dev/null
fi
```

**On Failure:** E035 trace fail → WARN, non-blocking (trace là output-only per CORE-026).

---

## Step 1.18 — TodoWrite Init

> **Pattern canonical:** [`_shared/11-task-planning.md`](../_shared/11-task-planning.md).

Orchestrator gọi `TodoWrite` tool với 7 items:

```javascript
TodoWrite({
  todos: [
    {content: "Phase 1: Init — parse flags, CI PRE-GATE, session setup", status: "in_progress", activeForm: "Running Phase 1: Init"},
    {content: "Phase 2: Scan — scope analysis, code/doc inventory", status: "pending", activeForm: "Running Phase 2: Scan"},
    {content: "Phase 3: Plan — ISG + partition + workload planning", status: "pending", activeForm: "Running Phase 3: Plan"},
    {content: "Phase 4: Find Bugs — dispatch lane agents, collect signals", status: "pending", activeForm: "Running Phase 4: Find Bugs"},
    {content: "Phase 5: Triage — classify issues, CDG gates, fix planning", status: "pending", activeForm: "Running Phase 5: Triage"},
    {content: "Phase 6: Execute — fix bugs, CI impact analysis, docs sync", status: "pending", activeForm: "Running Phase 6: Execute"},
    {content: "Phase 7: Verify — CQG gates, final report, session close", status: "pending", activeForm: "Running Phase 7: Verify"}
  ]
})
```

**Xác minh:**
- 7 items tạo trong TodoWrite
- Phase 1 = `in_progress`, Phase 2-7 = `pending`

**On Failure:** TodoWrite fail → WARN, tiếp tục (todo list là convenience).

**Cross-ref:** BHV-004 (Goal-Driven Execution).

---

## Group G POST-GATE Verify

```bash
# TRACE event recorded
jq -e '.events | length > 0' "$SESSION_DIR/session-log.json" >/dev/null && \
jq -e '.events[-1].event == "START"' "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group G PASS" || echo "Group G FAIL"
```

## Next: Phase 1 POST-GATE

→ Đọc [`phase1-init/POST-GATE.md`](POST-GATE.md) để validate toàn bộ Phase 1 trước khi advance sang Phase 2.
