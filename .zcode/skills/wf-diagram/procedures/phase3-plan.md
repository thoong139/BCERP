# /wf-diagram — Phase 3: Generation Plan

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.

---

## PRE-GATE

```
- [ ] $session_dir/analysis.json tồn tại (test -s)
- [ ] phases.phase_2.status = "done" trong checkpoint.json
```

---

## Steps

### 3.1 — Build System File List

```
NẾU $scope ∈ {"full", "system-only"}:
  IF $user_choice == "update_missing":
    plan.system_files = $system_missing  # Từ Phase 1.1
  ELSE:
    plan.system_files = ["context.md", "component.md", "erd-context-map.md",
                          "actors.md", "database.dbml"]
ELSE ($scope == "module-only"):
  plan.system_files = []
```

### 3.2 — Build Module File List + Use Case Groups

```
NẾU $scope ∈ {"full", "module-only"} AND $user_choice ≠ "skip":
  # Base files (luôn có)
  base_files = ["class.md", "erd.dbml"]

  # Use case groups — 1 file per group
  groups = analysis.usecase_groups[]
  usecase_files = ["usecases/" + group.group_slug + ".md" for group in groups]

  IF $user_choice == "update_missing":
    plan.module_files = base_files filter (file không tồn tại)
    plan.usecase_groups = groups filter (usecases/{slug}.md không tồn tại)
  ELSE:
    plan.module_files = base_files
    plan.usecase_groups = groups
ELSE:
  plan.module_files = []
  plan.usecase_groups = []
```

### 3.3 — Apply Filter Rules cho Detail Diagrams

```
# Xem SKILL.md §Filter Rules cho canonical definitions

# State diagrams
plan.states = analysis.state_machines[where states.length >= 3]

# Activity diagrams
plan.activities = analysis.processes[where
  steps.length >= 3 OR has_decision_branch == true]

# Sequence diagrams
plan.sequences = analysis.scenarios[where
  services_called.length >= 3
  OR has_complex_error_handling == true
  OR is_async == true]

# Skipped log (cho phase-summary.md sau này)
plan.skipped = []
FOR each entity NOT IN plan.states:
  plan.skipped.append({type:"state", name, reason:"< 3 states"})
FOR each process NOT IN plan.activities:
  plan.skipped.append({type:"activity", name, reason:"< 3 steps and no decision"})
FOR each scenario NOT IN plan.sequences:
  plan.skipped.append({type:"sequence", name, reason:"simple CRUD"})

# update_missing mode — chỉ lấy files chưa tồn tại
IF $user_choice == "update_missing":
  plan.states = filter (states/{slug}.md không tồn tại)
  plan.activities = filter (activities/{slug}.md không tồn tại)
  plan.sequences = filter (sequences/{slug}.md không tồn tại)
```

### 3.4 — Save Plan

```
Edit $session_dir/diagram-status.json:
  generation_plan = $plan  # 6 fields: system_files, module_files, usecase_groups,
                            #           states, activities, sequences, skipped
  phases.phase_3.status = "done"
```

---

## POST-GATE

```
- [ ] $plan đầy đủ 7 fields: system_files, module_files, usecase_groups,
      states, activities, sequences, skipped
- [ ] phases.phase_3.status = "done"
```

---

## Next Phase Routing

```
NẾU $plan.system_files có ≥1 entry:
  → Phase 4: procedures/phase4-system.md

NẾU $plan.system_files rỗng AND $plan.module_files có ≥1 entry:
  → Phase 5: procedures/phase5-module.md

NẾU $plan.system_files rỗng AND $plan.module_files rỗng AND
    ($plan.states OR $plan.activities OR $plan.sequences có entries):
  → Phase 6: procedures/phase6-detail.md

NẾU tất cả rỗng (scope=system-only với all files present + update_missing):
  → Phase 7: procedures/phase7-validation.md
```
