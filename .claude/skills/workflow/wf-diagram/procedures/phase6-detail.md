# /wf-diagram — Phase 6: Detail Diagrams (Conditional)

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.
> Xem SKILL.md §Mermaid 8.8.0 Safety Rules — BẮT BUỘC khi populate.

---

## PRE-GATE

```
- [ ] $plan có ≥1 entry trong states[] OR activities[] OR sequences[]
- [ ] analysis.json có data tương ứng (test -s)
```

---

## Steps (PARALLEL per type — N files độc lập)

> Theo CORE-025: states/, activities/, sequences/ có isolated write scope
> → có thể spawn sub-tasks song song theo type.

### 6.1 — Generate State Diagrams (PARALLEL per entity)

```
mkdir -p "$output_path/modules/$module/states"

FOR each state_machine IN $plan.states:
  1. Read templates/entity-state.md
  2. Populate:
     [ENTITY_NAME]
     [INITIAL_STATE]      ← state đầu (thường là state đầu tiên trong lifecycle)
     [STATE_TRANSITIONS]  ← state_machine.transitions[]:
                            "from_state --> to_state : event_name"
     [FINAL_STATES]       ← states cuối (delivered, cancelled, closed, v.v.)
     [STATES_TABLE]       ← bảng Markdown: State | Mô tả | Khi nào vào
     [TRANSITIONS_TABLE]  ← bảng: From | To | Event | Điều kiện
     [STATE_NOTES] / [STATE_SOURCE_REFS]
  3. Apply Mermaid 8.8.0 Safety Rules
  4. Write → $output_path/modules/$module/states/{slugify(entity_name)}.md
  5. Verify: test -s + grep "stateDiagram-v2"
```

### 6.2 — Generate Activity Diagrams (PARALLEL per process)

```
mkdir -p "$output_path/modules/$module/activities"

FOR each process IN $plan.activities:
  1. Read templates/process-activity.md
  2. Populate:
     [PROCESS_NAME]
     [FIRST_STEP]        ← bước đầu tiên sau start
     [PROCESS_STEPS]     ← list steps theo thứ tự
     [SWIMLANES]         ← subgraph khi xuyên nhiều actor/service
     [DECISION_BRANCHES] ← {decision?} nodes + Yes/No branches
     [PROCESS_DESCRIPTION] / [STEPS_TABLE] / [DECISIONS_TABLE]
     [ERROR_HANDLING]    ← xử lý lỗi / exception paths
     [ACTIVITY_NOTES]    ← notes về business rules, async steps
  3. Apply Mermaid 8.8.0 Safety Rules
  4. Write → $output_path/modules/$module/activities/{slugify(process_name)}.md
  5. Verify: test -s + grep "flowchart TD"
```

### 6.3 — Generate Sequence Diagrams (PARALLEL per scenario)

```
mkdir -p "$output_path/modules/$module/sequences"

FOR each scenario IN $plan.sequences:
  1. Read templates/scenario-sequence.md
  2. Populate:
     [SCENARIO_NAME] / [ENDPOINT_OR_TRIGGER]
     [PARTICIPANTS]   ← actor + services (theo thứ tự xuất hiện)
     [MAIN_FLOW]      ← message sequence: A->>B: methodName(params)
     [BRANCHES]       ← alt / else blocks
     [LOOPS]          ← loop [...] blocks
     [ASYNC_FLOWS]    ← async messages (-->>)
     [PARTICIPANTS_TABLE] / [STEPS_TABLE] / [ERROR_PATHS]
     [ASYNC_NOTES] / [SOURCE_REFS]
  3. Apply Mermaid 8.8.0 Safety Rules
  4. Write → $output_path/modules/$module/sequences/{slugify(scenario_name)}.md
  5. Verify: test -s + grep "sequenceDiagram"
```

### 6.4 — Save Checkpoint

```
save_checkpoint "phase_6" "phase_7"
Edit checkpoint.json:
  intermediate_outputs.states_done = [<entity slugs>]
  intermediate_outputs.activities_done = [<process slugs>]
  intermediate_outputs.sequences_done = [<scenario slugs>]
```

---

## POST-GATE

```
- [ ] Mỗi file trong $plan.states: test -s + grep "stateDiagram-v2"
- [ ] Mỗi file trong $plan.activities: test -s + grep "flowchart TD"
- [ ] Mỗi file trong $plan.sequences: test -s + grep "sequenceDiagram"
- [ ] KHÔNG có placeholder chưa thay trong bất kỳ file nào
- [ ] phases.phase_6.status = "done"
```

---

## Next Phase

→ Phase 7: `procedures/phase7-validation.md` (Validation & Output Report)
