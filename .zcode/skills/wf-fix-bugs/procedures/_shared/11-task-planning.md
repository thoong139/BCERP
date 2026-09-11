# §11 Task Planning (Protocol 9)

> Phase 1 (entry point) PHẢI init TodoWrite với danh sách 7 phases.
> Mỗi phase POST-GATE PASS → mark phase đó completed.

```
TODOWRITE INIT (Phase 1 Step cuối):

todos = [
  {content: "Phase 1: Init — parse flags, CI PRE-GATE, session init", activeForm: "Initializing session"},
  {content: "Phase 2: Scan Scope — code + doc inventory, interface detection", activeForm: "Scanning scope"},
  {content: "Phase 3: Plan — ISG, partition, workload gate, dispatch plan", activeForm: "Planning work"},
  {content: "Phase 4: Find Bugs — parallel lane dispatch, probe execution", activeForm: "Finding bugs"},
  {content: "Phase 5: Triage — aggregate, classify, CDG handoff, safety check", activeForm: "Triaging issues"},
  {content: "Phase 6: Execute — fix bugs via wf-fix-execute", activeForm: "Executing fixes"},
  {content: "Phase 7: Verify — CQG gates, summaries, fix-impact", activeForm: "Verifying results"}
]

UPDATE pattern (sau mỗi POST-GATE pass):
- Mark phase hiện tại = completed
- Mark phase kế tiếp = in_progress

EARLY EXIT pattern (Phase 5 N=0 → E005):
- Mark Phase 5 = completed (note: E005 healthy)
- Mark Phase 6 = completed (note: skipped — N=0)
- Mark Phase 7 = in_progress
```
