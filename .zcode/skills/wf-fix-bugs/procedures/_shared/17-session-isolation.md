# §17 Session Isolation Protocol

> **Slim (v10.13.0):** Quy tắc đầy đủ trong [CORE-030 — Working Directory Session Isolation](../../../../rules/00-core.md) + [CORE-035 — Phase Output Organization](../../../../rules/00-core.md#4l-core-035-phase-output-organization-b%E1%BA%AFt-bu%E1%BB%99c). File này CHỈ giữ session structure cụ thể cho wf-fix-bugs.

```
SESSION_ID format: YYYY-MM-DD-{scope}-{slug}-{NN}
  scope: scope argument (all/system/module)
  slug: lower-kebab của --name hoặc "auto"
  NN: auto-increment (01, 02, ...)

SESSION_DIR: .mc-data/work/wf-fix-bugs/sessions/$SESSION_ID/

Phase subdirectories created at session init:
  $SESSION_DIR/phase1-init/
  $SESSION_DIR/phase2-scan/
  $SESSION_DIR/phase3-plan/workloads/
  $SESSION_DIR/phase4-find-bugs/lanes/
  $SESSION_DIR/phase5-triage/
  $SESSION_DIR/phase6-execute/
  $SESSION_DIR/phase7-verify/

Index file: .mc-data/work/wf-fix-bugs/_index/sessions.jsonl (APPEND-only)
```
