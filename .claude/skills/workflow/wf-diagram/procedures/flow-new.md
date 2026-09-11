# /wf-diagram — Phase Procedures (flow-new.md)

> Lazy-loaded chi tiết các phase cho `/wf-diagram`. SKILL.md tham chiếu file này khi cần expand
> step-level instructions. Mỗi phase self-contained: PRE-GATE, INPUT, Steps, POST-GATE, Next Phase.

## Reference

- SKILL.md (entry point + overview + arguments + Output Files)
- `_contract.json` (schema contract — outputs.docs[], outputs.working[], registry_scope)
- Protocol 14 (Phase Summary), 15 (Execution Trace), 16 (CDG), 18 (Session Isolation), 19 (Template Usage)
- Filter rules: SKILL.md §"Quy tắc lọc" + `_contract.json.filter_rules`

---

## State Variables Glossary

| Variable | Source | Description |
|----------|--------|-------------|
| `$module` | `--module=<name>` arg | Module cần sinh diagram. Bắt buộc trừ `scope=system-only` |
| `$source_path` | `--source-path=<path>` arg | Root source code, default `.` |
| `$output_path` | `--output-path=<path>` arg | Đường dẫn xuất diagrams, default `.mc-data/docs/diagrams` |
| `$scope` | `--scope=<value>` arg | `full` \| `module-only` \| `system-only`, default `full` |
| `$session_id` | Phase 0.4 generated | Format `{YYYY-MM-DD}-{scope-label}[-{N}]` (Protocol 18.2) |
| `$session_dir` | Computed | `.mc-data/work/wf-diagram/sessions/$session_id/` |
| `$system_dir` | Computed (v1.2.0) | `$output_path/modules/$module/_system` (full/module-only) HOẶC `$output_path/_system` (system-only) |
| `$user_choice` | Phase 1.3 CDG-02 | `overwrite` \| `skip` \| `update_missing` \| null (no conflict) |
| `$analysis` | Phase 2 output | Content từ `analysis.json` |
| `$plan` | Phase 3 output | Content từ `diagram-status.json.generation_plan` |

---

## Phase 0 — Setup & Argument Validation

### PRE-GATE

```
- [ ] $ARGUMENTS đã parse được (CLI args)
- [ ] HOẶC $module được cung cấp HOẶC $scope = "system-only"
- [ ] $source_path tồn tại (test -d)
```

### Steps

#### 0.0 — Resume/Status Dispatch

```
NẾU --resume HOẶC --status:
  Đọc $session_dir/checkpoint.json
  --status:  hiển thị 5 sessions gần nhất (table) → STOP
  --resume:  load checkpoint → route đến next_action.phase
KHÔNG fresh run nếu --resume/--status set.
```

#### 0.1 — Parse Arguments

```bash
# Pseudo-bash extraction
module=$(echo "$ARGUMENTS" | grep -oP -- '--module=\K[^ ]+' || echo "")
source_path=$(echo "$ARGUMENTS" | grep -oP -- '--source-path=\K[^ ]+' || echo ".")
output_path=$(echo "$ARGUMENTS" | grep -oP -- '--output-path=\K[^ ]+' || echo ".mc-data/docs/diagrams")
scope=$(echo "$ARGUMENTS" | grep -oP -- '--scope=\K[^ ]+' || echo "full")
```

#### 0.2 — Validate Args

```
NẾU $scope ≠ "system-only" AND $module == "":
  → STDOUT: "Workflow yêu cầu tên module. Vui lòng cung cấp `--module=<tên>` hoặc dùng `--scope=system-only` nếu chỉ muốn sinh sơ đồ tổng thể."
  → Exit E001 (KHÔNG tạo session, KHÔNG ghi file)

NẾU $scope NOT IN {"full", "module-only", "system-only"}:
  → STDOUT: "--scope phải là full | module-only | system-only"
  → Exit E001
```

#### 0.3 — Validate Source Path

```bash
test -d "$source_path" || {
  echo "ERROR: $source_path không tồn tại. Hãy kiểm tra bằng \`ls\`"
  exit 2  # E002
}
```

#### 0.4 — Generate SESSION_ID (Protocol 18.2)

```
scope_label = lowercase-kebab-case của $module (hoặc "system" nếu scope=system-only)
SESSION_ID = "$(date +%Y-%m-%d)-$scope_label"

NẾU đã có session cùng tên:
  Append suffix -2, -3, ...

# Ví dụ: 2026-04-30-order, 2026-04-30-order-2, 2026-04-30-system
```

#### 0.5 — Create Directories

```bash
mkdir -p ".mc-data/work/wf-diagram/sessions/$SESSION_ID"
mkdir -p "$output_path"
mkdir -p ".mc-data/work/_trace"  # Cho Protocol 15
```

#### 0.6 — Init diagram-status.json (READ → POPULATE → WRITE)

```
1. Read templates/diagram-status.json
2. Populate: session_id, module, source_path, output_path, scope, started_at (ISO-8601)
3. Write → $session_dir/diagram-status.json
4. Verify: jq '.session_id' diagram-status.json ≠ "" AND test -s diagram-status.json
```

#### 0.7 — Init checkpoint.json (READ → POPULATE → WRITE)

```
1. Read templates/checkpoint.json
2. Populate: {{SESSION_ID}}, {{MODULE}}, {{SCOPE}}, {{CREATED_AT_ISO8601}}, args_snapshot
3. Write → $session_dir/checkpoint.json
4. Verify: test -s checkpoint.json
```

#### 0.8 — Append Trace START (Protocol 15)

```
trace_file = ".mc-data/work/_trace/session-log.json"

NẾU không tồn tại:
  Read template: .claude/doc-framework/_meta/session-log.template.json
  Init trace_file

# Atomic append:
tmp=$(mktemp)
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.entries += [{
      "skill": "/wf-diagram",
      "session_id": $sid,
      "phase": "phase_0",
      "event": "START",
      "timestamp": $ts
    }]' "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"
```

### POST-GATE

```
- [ ] $session_dir tồn tại (test -d)
- [ ] diagram-status.json non-empty (test -s)
- [ ] checkpoint.json non-empty
- [ ] trace_file có entry mới (jq '.entries[-1].event' == "START")
```

### Next Phase

→ Phase 1 (Pre-check Existing Diagrams)

---

## Phase 1 — Pre-check Existing Diagrams

### PRE-GATE

```
- [ ] Phase 0 hoàn tất (diagram-status.phases.phase_0.status == "done")
- [ ] $output_path tồn tại
```

### Steps

#### 1.1 — Resolve $system_dir + Check System Diagrams

```bash
# Resolve $system_dir theo $scope (v1.2.0 module-scoped layout)
if [ "$scope" = "system-only" ]; then
  system_dir="$output_path/_system"
else
  system_dir="$output_path/modules/$module/_system"
fi

system_files=("context.md" "component.md" "erd-context-map.md" "actors.md" "database.dbml")
system_missing=()
for f in "${system_files[@]}"; do
  test -f "$system_dir/$f" || system_missing+=("$f")
done
```

#### 1.2 — Check Module Diagrams

```bash
NẾU $scope ∈ {"full", "module-only"}:
  test -d "$output_path/modules/$module" && module_exists=true || module_exists=false
```

#### 1.3 — CDG-02 nếu module diagrams đã tồn tại

```
NẾU $module_exists == true:
  AskUserQuestion:
    "Module `$module` đã có diagram tại $output_path/modules/$module/.
     Hành động:
     (a) Ghi đè toàn bộ
     (b) Bỏ qua module này
     (c) Chỉ cập nhật phần thiếu (giữ nguyên file đã có)"
  → user_choice ∈ {overwrite, skip, update_missing}
```

#### 1.4 — Save User Decision

```
Edit diagram-status.json:
  user_decisions.module_conflict = $user_choice (or null)
```

### POST-GATE

```
- [ ] $system_missing[] đã xác định
- [ ] $user_choice resolved (hoặc null nếu không có conflict)
- [ ] phases.phase_1.status = "done"
```

### Next Phase

→ Phase 2 (Source Code Analysis)

---

## Phase 2 — Source Code Analysis

### PRE-GATE

```
- [ ] $source_path tồn tại
- [ ] Phase 1 hoàn tất
```

### Steps

#### 2.1 — Scan Module Structure

```
Glob $source_path để detect modules:
- folder-based: apps/*/, src/modules/*/, services/*/
- namespace-based (.NET): grep "namespace" *.cs
- package-based (Java/Go): grep "package" *.go *.java

Output: $analysis.modules[] = [{ name, path, type }]
```

#### 2.2 — Read DB Schema

```
Glob theo tech stack:
- SQL migrations: **/migrations/**/*.sql
- ORM models: **/entities/**/*.{ts,cs}, **/models/**/*.py
- Prisma: **/schema.prisma
- TypeORM/EF: grep @Entity / DbContext

Extract: tables[] = [{ name, columns[], pk, fks[] }]
Output: $analysis.entities[] = tables (filter theo $module nếu $scope ≠ system-only)
```

#### 2.3 — Read Inline Spec

```
Grep:
- Docstrings (/** ... */, """ ... """, ''' ... ''')
- JSDoc tags (@param, @returns, @example)
- README.md per module

Extract: notes[] gắn vào entity/endpoint/method tương ứng
```

#### 2.4 — Read Module Code (nếu $module set)

```
Module path = $analysis.modules[where name == $module].path

Phân loại files:
- Controllers/Routes: grep @Controller, app.{get,post}, router.*, [HttpGet]
  → endpoints[] = [{ method, path, handler, services_called[], controller_class, url_prefix, sub_folder }]
- Services/Domain: grep @Service, class *Service, public class *Service
  → services[] + business_logic_steps[]
- Models/Entities: grep @Entity, class * extends BaseEntity
  → classes[] với fields, methods, relationships
- State enums: grep enum.*Status, type.*State, status: ...
  → state_machines[] = [{ entity, states[], transitions[] }]

Extract use case groups (Phase 3.3 sẽ filter):
- Group key (ưu tiên giảm dần):
  1. controller_class (vd: OrderController → group "order")
  2. url_prefix segment đầu (vd: /api/orders/* → group "orders")
  3. sub_folder (vd: src/order/checkout/* → group "checkout")
- Output: usecase_groups[] = [{
    group_name,         # vd: "Order Creation"
    group_slug,         # vd: "order-creation"
    description,        # 1-2 câu mô tả nhóm
    use_cases[],        # endpoints thuộc group này (mỗi endpoint = 1 use case)
    actors[],           # actors có quyền access endpoints trong group
    grouping_basis      # "controller_class" | "url_prefix" | "sub_folder"
  }]
- Module luôn có ≥1 group. Nếu không phát hiện được phân nhóm → 1 group default = $module name.
```

#### 2.5 — Detect Actors

```
Grep:
- Middleware auth: app.use(authMiddleware), [Authorize]
- Role check: hasRole, [Authorize(Roles=...)], @Roles()
- Decorator/attribute: @AllowAnonymous, @AdminOnly

Extract: actors[] = [{ name, role, modules_used[], auth_pattern }]
```

#### 2.6 — Write analysis.json

```
Atomic write:
{
  "$schema": "analysis-v1",
  "session_id": "...",
  "scanned_at": "ISO-8601",
  "modules": [...],
  "entities": [...],
  "endpoints": [...],
  "actors": [...],
  "state_machines": [...],
  "processes": [...],     # Phase 3 sẽ filter
  "scenarios": [...]      # Phase 3 sẽ filter
}

Verify: jq '.modules | length > 0' analysis.json
```

#### 2.7 — Save Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_2 = "done"
  intermediate_outputs.analysis_json = "$session_dir/analysis.json"
  next_action.phase = "phase_3"
```

### POST-GATE

```
- [ ] analysis.json non-empty
- [ ] analysis.modules[] hoặc analysis.entities[] hoặc analysis.endpoints[] có ≥ 1 entry
- [ ] phases.phase_2.status = "done"
```

### Next Phase

→ Phase 3 (Generation Plan)

---

## Phase 3 — Generation Plan

### PRE-GATE

```
- [ ] analysis.json tồn tại
- [ ] phases.phase_2.status = "done"
```

### Steps

#### 3.1 — Build System File List

```
NẾU $scope ∈ {"full", "system-only"}:
  IF $user_choice == "update_missing":
    plan.system_files = $system_missing  # Phase 1.1
  ELSE:
    plan.system_files = ["context.md", "component.md", "erd-context-map.md", "actors.md", "database.dbml"]
ELSE:
  plan.system_files = []
```

#### 3.2 — Build Module File List + Use Case Groups

```
NẾU $scope ∈ {"full", "module-only"} AND $user_choice ≠ "skip":
  # Base files (luôn có)
  base_files = ["class.md", "erd.dbml"]

  # Use case groups (N file, mỗi group 1 file)
  groups = analysis.usecase_groups[]   # từ Phase 2.4
  usecase_files = ["usecases/" + slugify(g.group_name) + ".md" for g in groups]

  IF $user_choice == "update_missing":
    plan.module_files = base_files filter (không tồn tại trong $output_path/modules/$module/)
    plan.usecase_groups = groups filter (file usecases/{slug}.md không tồn tại)
  ELSE:
    plan.module_files = base_files
    plan.usecase_groups = groups
ELSE:
  plan.module_files = []
  plan.usecase_groups = []
```

#### 3.3 — Apply Filter Rules cho Detail Diagrams

```
# State diagrams
plan.states = analysis.state_machines[where states.length >= 3]

# Activity diagrams
plan.activities = analysis.processes[where steps.length >= 3 OR has_decision_branch]

# Sequence diagrams
plan.sequences = analysis.scenarios[where
  services_called.length >= 3
  OR has_complex_error_handling
  OR is_async OR has_callback OR has_webhook
]

# Skipped — populate $plan.skipped[] với lý do
plan.skipped = []
FOR each entity NOT IN plan.states:
  plan.skipped.append({ type: "state", name: entity.name, reason: "< 3 states" })
FOR each process NOT IN plan.activities:
  plan.skipped.append({ type: "activity", name: process.name, reason: "< 3 steps and no decision" })
FOR each scenario NOT IN plan.sequences:
  plan.skipped.append({ type: "sequence", name: scenario.name, reason: "simple CRUD" })

# Update mode — chỉ lấy files chưa tồn tại
IF $user_choice == "update_missing":
  plan.states = filter (file chưa tồn tại trong $output_path/modules/$module/states/)
  plan.activities = filter (...)
  plan.sequences = filter (...)
```

#### 3.4 — Save Plan

```
Edit diagram-status.json:
  generation_plan = $plan
```

### POST-GATE

```
- [ ] $plan đầy đủ 6 fields: system_files, module_files, states, activities, sequences, skipped
- [ ] phases.phase_3.status = "done"
```

### Next Phase

→ Phase 4 (System Diagrams) NẾU $plan.system_files có entries
→ Phase 5 (Module Diagrams) NẾU $plan.module_files có entries (skip Phase 4 nếu rỗng)

---

## Phase 4 — System-wide Diagrams (Conditional)

### PRE-GATE

```
- [ ] $plan.system_files có ≥ 1 entry
- [ ] analysis.json đầy đủ
```

### Steps (PARALLEL — 5 file độc lập)

> Có thể spawn 5 sub-tasks song song theo CORE-025 (isolated write scope, contract ổn định).

#### 4.0 — Resolve $system_dir + mkdir

```bash
# v1.2.0 module-scoped layout
if [ "$scope" = "system-only" ]; then
  system_dir="$output_path/_system"
else
  system_dir="$output_path/modules/$module/_system"
fi
mkdir -p "$system_dir"
```

#### 4.1 — Generate context.md

```
1. Read templates/system-context.md
2. Populate placeholders:
   [SYSTEM_NAME]      ← từ analysis (root project name)
   [ACTOR_NODES]      ← analysis.actors[] → "U1([System Admin])" (KHÔNG dùng emoji prefix trong node ID, để tránh Mermaid 8.8.0 fail; emoji có thể đặt trong label đã quote)
   [EXTERNAL_SYSTEM_NODES] ← analysis.external_systems[]
   [DATA_FLOWS]       ← actors → SYS, SYS → externals
   [CONTEXT_DESCRIPTION] / [ACTORS_LIST] / [EXTERNAL_SYSTEMS_LIST]
3. Apply Mermaid 8.8.0 Safety Rules (xem SKILL.md):
   - Quote labels có space/special-char: `A["Long label with spaces"]`
   - KHÔNG dùng `'` (single quote), `—` (em-dash) trong label — replace bằng `"` quote và `--`
   - KHÔNG dùng `[(...)]` cylinder với content có quote/parens nested
   - subgraph với multi-word: `subgraph ID["Display Name"]`
4. Write → $system_dir/context.md
5. Verify: test -s + grep "flowchart"
```

#### 4.2 — Generate component.md

```
1. Read templates/system-component.md
2. Populate:
   [PRESENTATION_MODULES] / [BUSINESS_MODULES] / [DATA_MODULES]
     ← analysis.modules[] grouped by detected layer
   [MODULE_DEPENDENCIES] ← analysis.modules[].depends_on[]
3. Apply Mermaid 8.8.0 Safety Rules
4. Write → $system_dir/component.md
```

#### 4.3 — Generate erd-context-map.md

```
1. Read templates/system-erd-context-map.md
2. Populate:
   [MODULE_ERD_NODES]   ← cho mỗi module có entity
   [CROSS_MODULE_REFS]  ← FK xuyên module
   [CROSS_REFS_TABLE]   ← bảng Markdown
3. Apply Mermaid 8.8.0 Safety Rules
4. Write → $system_dir/erd-context-map.md
```

#### 4.4 — Generate actors.md

```
1. Read templates/system-actors.md
2. Populate:
   [ACTORS_TABLE_ROWS]  ← analysis.actors[]
   [INTERNAL_ACTORS] / [EXTERNAL_ACTORS] / [SYSTEM_ACTORS]
   [AUTH_PATTERNS]      ← từ analysis.actors[].auth_pattern
3. Write → $system_dir/actors.md
   (Markdown thuần — không cần Mermaid safety rules)
```

#### 4.5 — Generate database.dbml

```
1. Read templates/system-database.dbml
2. Populate:
   [PROJECT_NAME] / [DB_TYPE]   ← analysis.tech_stack
   [TABLE_BLOCKS]               ← cho mỗi entity, render Table block với columns + Note
   [TABLE_GROUPS]               ← group theo module
   [REFERENCES]                 ← Ref: cho mỗi FK
3. Write → $system_dir/database.dbml
4. Verify: grep "Project " AND grep "Table " AND (count "Ref:" >= 0)
```

#### 4.6 — Save Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_4 = "done"
  intermediate_outputs.system_files_done = [...]
  next_action.phase = "phase_5"
```

### POST-GATE

```
- [ ] Mỗi file trong $plan.system_files đều: test -s pass + Mermaid block hoặc DBML Project block
- [ ] phases.phase_4.status = "done"
```

### Next Phase

→ Phase 5 (Module Diagrams) NẾU $plan.module_files có entries
→ Phase 6 (Detail Diagrams) NẾU $plan.module_files rỗng nhưng có states/activities/sequences
→ Phase 7 (Validation) NẾU không có gì để generate thêm

---

## Phase 5 — Module-scoped Diagrams (Conditional)

### PRE-GATE

```
- [ ] $plan.module_files có ≥ 1 entry
- [ ] $user_choice ≠ "skip"
- [ ] analysis có data về $module
```

### Steps (PARALLEL — 3 file độc lập)

#### 5.1 — Generate usecases/{group}.md (PARALLEL per group)

```
mkdir -p "$output_path/modules/$module/usecases"

FOR each group IN $plan.usecase_groups:
  1. Read templates/module-usecase.md
  2. Populate:
     [MODULE_NAME]            ← $module
     [GROUP_NAME]             ← group.group_name
     [GROUP_DESCRIPTION]      ← group.description
     [ACTOR_NODES]            ← group.actors[] (actors có tương tác với use cases trong group)
     [USECASE_NODES]          ← group.use_cases[] — mỗi use case là 1 oval node
     [ACTOR_USECASE_LINKS]    ← actor → use case theo permissions trong group
     [INCLUDE_EXTEND_RELS]    ← phát hiện helper calls (UC1 -. include .-> UC2)
     [USECASES_DESCRIPTION]   ← bảng Markdown các use case của group
                                (cột: Use Case | Actor | Mô tả | Source controller/handler | Include | Extend)
     [RELATED_GROUPS]         ← link sang group khác cùng module:
                                "- [Tên group khác](./{slug}.md) — mô tả ngắn"
                                Để rỗng nếu module chỉ có 1 group.
     [USECASE_NOTES]          ← grouping_basis (controller_class/url_prefix/sub_folder),
                                + use case nào primary/secondary, + // TODO nếu chưa rõ
  3. Write → $output_path/modules/$module/usecases/{slugify(group.group_name)}.md
  4. Verify: test -s + grep "flowchart"

# Lưu ý:
# - Module luôn có ≥1 file usecase (kể cả khi chỉ phát hiện 1 group)
# - PARALLEL: spawn N sub-tasks song song, mỗi task render 1 group file
```

#### 5.2 — Generate class.md

```
1. Read templates/module-class.md
2. Populate:
   [MAIN_CLASSES]          ← analysis.classes[where module == $module]
                              Render với chỉ field/method chính (KHÔNG show all fields)
   [EXTERNAL_CLASSES]      ← analysis.cross_module_refs[] với <<external from {module}>>
   [CLASS_RELATIONSHIPS]   ← inheritance (-->|>), composition (*--), aggregation (o--), association (-->)
   [CLASSES_TABLE] / [EXTERNAL_REFS] / [DESIGN_PATTERNS]
3. Write → $output_path/modules/$module/class.md
```

#### 5.3 — Generate erd.dbml

```
1. Read templates/module-erd.dbml
2. Populate:
   [MODULE_NAME] / [DB_TYPE]
   [MODULE_TABLE_BLOCKS]    ← entities thuộc $module với full columns + Note
   [EXTERNAL_TABLE_BLOCKS]  ← entities từ module khác, // External: from <module>, chỉ show PK
   [MODULE_REFERENCES]      ← Ref: cho FK trong scope module
3. Write → $output_path/modules/$module/erd.dbml
```

#### 5.4 — Save Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_5 = "done"
  intermediate_outputs.module_files_done = ["class.md", "erd.dbml"]
  intermediate_outputs.usecase_groups_done = [<list slugified group filenames>]
  next_action.phase = "phase_6"
```

### POST-GATE

```
- [ ] class.md tồn tại + non-empty
- [ ] erd.dbml tồn tại + non-empty
- [ ] usecases/ folder có ≥1 file (= len($plan.usecase_groups))
- [ ] Mỗi file usecases/{slug}.md non-empty + chứa "flowchart" (Mermaid block)
- [ ] phases.phase_5.status = "done"
```

### Next Phase

→ Phase 6 (Detail Diagrams)

---

## Phase 6 — Detail Diagrams (Conditional, PARALLEL per type)

### PRE-GATE

```
- [ ] $plan có ≥ 1 entry trong states[] OR activities[] OR sequences[]
```

### Steps

#### 6.1 — Generate State Diagrams (PARALLEL per entity)

```
mkdir -p "$output_path/modules/$module/states"

FOR each state_machine IN $plan.states:
  1. Read templates/entity-state.md
  2. Populate:
     [ENTITY_NAME]
     [INITIAL_STATE]
     [STATE_TRANSITIONS]  ← state_machine.transitions[] → "from --> to : event"
     [FINAL_STATES]
     [STATES_TABLE] / [TRANSITIONS_TABLE] / [STATE_NOTES] / [STATE_SOURCE_REFS]
  3. Write → $output_path/modules/$module/states/{slugify(entity_name)}.md
```

#### 6.2 — Generate Activity Diagrams (PARALLEL per process)

```
mkdir -p "$output_path/modules/$module/activities"

FOR each process IN $plan.activities:
  1. Read templates/process-activity.md
  2. Populate:
     [PROCESS_NAME]
     [FIRST_STEP] / [PROCESS_STEPS] / [SWIMLANES] / [DECISION_BRANCHES]
     [PROCESS_DESCRIPTION] / [STEPS_TABLE] / [DECISIONS_TABLE]
     [ERROR_HANDLING] / [ACTIVITY_NOTES]
  3. Write → $output_path/modules/$module/activities/{slugify(process_name)}.md
```

#### 6.3 — Generate Sequence Diagrams (PARALLEL per scenario)

```
mkdir -p "$output_path/modules/$module/sequences"

FOR each scenario IN $plan.sequences:
  1. Read templates/scenario-sequence.md
  2. Populate:
     [SCENARIO_NAME] / [ENDPOINT_OR_TRIGGER]
     [PARTICIPANTS] ← actor + services
     [MAIN_FLOW] / [BRANCHES] / [LOOPS] / [ASYNC_FLOWS]
     [PARTICIPANTS_TABLE] / [STEPS_TABLE] / [ERROR_PATHS]
     [ASYNC_NOTES] / [SOURCE_REFS]
  3. Write → $output_path/modules/$module/sequences/{slugify(scenario_name)}.md
```

#### 6.4 — Save Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_6 = "done"
  intermediate_outputs.{states_done, activities_done, sequences_done}
  next_action.phase = "phase_7"
```

### POST-GATE

```
- [ ] Mỗi file trong $plan.states/activities/sequences đã được sinh, test -s pass
- [ ] Mermaid syntax valid (grep "stateDiagram-v2", "flowchart TD", "sequenceDiagram")
- [ ] phases.phase_6.status = "done"
```

### Next Phase

→ Phase 7 (Validation & Output)

---

## Phase 7 — Validation & Output Report

### PRE-GATE

```
- [ ] Phase 0-6 đã hoàn tất (theo $scope)
```

### Steps

#### 7.1 — POST-GATE T1 (Existence)

```bash
all_pass=true

# System + module base files
FOR each file IN $plan.{system_files, module_files, states, activities, sequences}:
  test -s "$output_path/$file" || { all_pass=false; log_error E007 "$file missing or empty"; }

# Usecase group files (N files trong usecases/)
FOR each group IN $plan.usecase_groups:
  slug=$(slugify "$group.group_name")
  test -s "$output_path/modules/$module/usecases/$slug.md" || {
    all_pass=false; log_error E007 "usecases/$slug.md missing or empty";
  }
```

#### 7.2 — POST-GATE T2 (Structure)

```
FOR each .md file:
  Mermaid block: grep -E '```mermaid' file → count >= 1

FOR each .dbml file:
  grep "Project " file → count == 1
  grep "Table " file → count >= 1
```

#### 7.3 — POST-GATE T3 (Content)

```
FOR each file:
  - .md: phải có ≥ 1 node/class/participant trong Mermaid block (placeholder [...] đã được thay)
  - .dbml: ≥ 1 Table block có ≥ 1 column
NẾU phát hiện placeholder chưa thay (vd "[ACTOR_NODES]") → FAIL T3
```

#### 7.4 — POST-GATE T4 (Cross-reference)

```
- Tên entity/class/bảng nhất quán giữa các diagrams
  (vd "Order" trong class.md == "orders" trong erd.dbml — sau normalize)
- External refs đánh dấu rõ // External: from <module>
- Mismatch → log warning vào diagram-status.json.error_log
```

#### 7.5 — Auto-Correction Loop (max 3 retries — Protocol 2)

```
NẾU bất kỳ T1-T4 fail:
  Retry counter += 1
  Re-run phase tương ứng (4/5/6) với template
  NẾU retry == 3 AND vẫn FAIL:
    Set diagram-status.status = "failed"
    VẪN tiếp tục Phase 7.6 (tạo phase-summary.md với STATUS="THẤT BẠI" — Protocol 14.1)
```

#### 7.6 — Generate phase-summary.md

```
1. Read templates/phase-summary.md
2. Populate (tiếng Việt, ≤ 15 dòng — Protocol 14.2):
   [GENERATED_AT] / [STATUS] / [SESSION_ID]
   [MODULE] / [SOURCE_PATH] / [SCOPE]
   [FILE_COUNT] / [MODULE_COUNT] / [ENTITY_COUNT] / [ENDPOINT_COUNT] / [ACTOR_COUNT]
   [SYSTEM_DIAGRAM_COUNT] / [MODULE_DIAGRAM_COUNT] / [DETAIL_DIAGRAM_COUNT]
   [OUTPUT_PATH]
   [STRENGTHS_AND_GAPS]   ← nêu rõ files bị skip + lý do (filter rules)
   [RECOMMENDATIONS]
3. Write → $session_dir/phase-summary.md
4. Hiển thị nội dung trong conversation (Protocol 14.4)
```

#### 7.7 — Append Trace COMPLETE / FAIL

```
event = (status == "completed") ? "COMPLETE" : "FAIL"

Atomic append vào $trace_file:
  jq '.entries += [{
    "skill": "/wf-diagram",
    "session_id": "...",
    "phase": "phase_7",
    "event": $event,
    "timestamp": "ISO-8601",
    "files_created": [...],
    "warnings": [...]
  }]'
```

#### 7.8 — Save Final Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_7 = "done"
  next_action = null  # DONE
  trigger.reason = "completed"
```

#### 7.9 — Display Output Report

```
Hiển thị bảng tóm tắt như SKILL.md §"Output Report":
| Module | $module |
| Scope | $scope |
| Session | $session_id |
| System diagrams | N |
| Module diagrams | N |
| Detail diagrams | states=X, activities=Y, sequences=Z |
| Skipped (filter rules) | N |
| Verification | T1-T4 PASS / FAILED |

Output:
  - Diagrams: $output_path/
  - Metadata: $session_dir/

Next:
  - Mở $output_path/_system/context.md
  - Render Mermaid: https://mermaid.live
  - Render DBML: https://dbdiagram.io
```

### POST-GATE

```
- [ ] T1-T4 PASS HOẶC status="failed" với phase-summary.md ghi rõ
- [ ] phase-summary.md tồn tại + non-empty (Protocol 14.1 — không skip khi FAIL)
- [ ] trace COMPLETE/FAIL event appended
- [ ] phases.phase_7.status = "done" / "failed"
```

### Next Phase

→ DONE — STOP skill execution.

---

## Error Handling Matrix

> Quick lookup. Canonical: SKILL.md §"Error Handling".

| Code | Tình huống | Action | Retry |
|------|------------|--------|-------|
| E001 | Missing --module + scope ≠ system-only | Display message → STOP | No |
| E002 | --source-path không tồn tại | ERROR + suggest ls → STOP | No |
| E003 | output_path/modules/$module/ exists | CDG-02 (Protocol 16) | — |
| E004 | $module không tìm thấy trong source | WARN + offer scope=system-only → ASK | No |
| E005 | DB schema không tìm thấy | WARN + skip ERD generation | No |
| E006 | Mermaid syntax invalid | Re-render từ template | x3 |
| E007 | DBML parse fail | Re-render → // TODO block | x1 |
| E008 | File write fail | Retry → ESCALATE | x3 |
| E009 | User reject CDG-02 | Skip module, continue (Protocol 16.2.1) | — |

## Helper: slugify()

```bash
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}
# Usage: slugify "Order Status" → "order-status"
```
