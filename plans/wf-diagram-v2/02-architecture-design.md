# Architecture Design — wf-diagram v2.0

**Ngày tạo:** 2026-05-03
**Trạng thái:** 📐 DRAFT — chờ user duyệt 4 quyết định trong `03-decisions-pending.md`

---

## 1. Target structure

```
.claude/skills/workflow/wf-diagram/
├── SKILL.md                          ≤ 250 dòng — entry point + routing hub
├── _contract.json                    skill-contract-v1, procedure_files[] đầy đủ
├── procedures/
│   ├── _shared.md                    ≤ 250 dòng — state vars, helpers, error matrix, agent prompts (nếu có)
│   ├── resume-status.md              ≤ 200 dòng — --status / --resume dispatcher
│   ├── session-init.md               ≤ 150 dòng — bootstrap helpers (gọi từ phase0)
│   ├── phase0-setup.md               ≤ 200 dòng — Setup & Argument Validation
│   ├── phase1-precheck.md            ≤ 200 dòng — Pre-check Existing Diagrams + CDG-02
│   ├── phase2-source-analysis.md     ≤ 250 dòng — Source Code Analysis (delegate bash)
│   ├── phase3-plan.md                ≤ 200 dòng — Generation Plan + filter rules
│   ├── phase4-system.md              ≤ 250 dòng — System diagrams (PARALLEL 5)
│   ├── phase5-module.md              ≤ 250 dòng — Module diagrams (PARALLEL N+2)
│   ├── phase6-detail.md              ≤ 250 dòng — Detail diagrams (PARALLEL N)
│   ├── phase7-validation.md          ≤ 250 dòng — POST-GATE T1-T4 + report
│   └── flow-legacy.md.bak            (backup of v1.2.0 monolithic flow-new.md)
├── templates/
│   ├── diagram-status.json           (existing — verify schema)
│   ├── checkpoint.json               (existing)
│   ├── phase-summary.md              (existing — verify Protocol 14 fields)
│   ├── analysis.schema.md            (NEW — analysis.json schema doc)
│   ├── system-context.md             (existing — patch Mermaid 8.8.0 safety)
│   ├── system-component.md           (existing — patch)
│   ├── system-erd-context-map.md     (existing — patch)
│   ├── system-actors.md              (existing — patch)
│   ├── system-database.dbml          (existing — verify DBML)
│   ├── module-usecase.md             (existing — patch)
│   ├── module-class.md               (existing — patch)
│   ├── module-erd.dbml               (existing — verify)
│   ├── entity-state.md               (existing — patch)
│   ├── process-activity.md           (existing — patch)
│   └── scenario-sequence.md          (existing — patch)
└── evals/
    └── evals.json                    ≥ 8 cases (5 updated + 3 new)

.claude/scripts/
├── wf-diagram-common.sh              NEW — atomic_write, slugify, parse_args, ISO-8601, lock helpers (chuẩn bị v2.1)
├── wf-diagram-source-scan.sh         NEW — Phase 2 scan source → analysis.json
├── wf-diagram-mermaid-validate.sh    NEW — POST-GATE T2 Mermaid 8.8.0 grep
├── wf-diagram-dbml-validate.sh       NEW — POST-GATE T2 DBML grep
└── wf-diagram-resume-helper.sh       NEW — list 5 latest sessions cho --status
```

---

## 2. SKILL.md routing hub structure

```markdown
---
name: wf-diagram
version: 2.0.0
last_updated: 2026-05-XX
description: |
  Tự động sinh bộ sơ đồ thiết kế (UML + ERD) cho một module trong hệ thống,
  dựa trên source code có sẵn. v2.0.0 — refactor lazy-load (10 phase files,
  5 bash scripts), tuân thủ chuẩn skill cấu trúc của các skill đã overhaul.

  TRIGGER khi: ...
  KHÔNG trigger khi: ...
argument-hint: "..."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# /wf-diagram: $ARGUMENTS

## Overview            (~ 30 dòng)
## Workflow Position   (~ 10 dòng)
## Arguments           (~ 25 dòng)
## Output Files        (~ 60 dòng — table + path resolution + output location)
## Resume & Status     (~ 10 dòng)

## Protocols Reference (~ 5 dòng — pointer)
> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10, 14, 15, 16, 18, 19.
> **Internal shared:** Xem `procedures/_shared.md` — State Variables, Helper Functions, Error Matrix.

## Phase Routing Map (lazy-loaded)   (~ 40 dòng)

| Phase | Procedure file | Điều kiện |
|-------|----------------|-----------|
| Resume/Status | resume-status.md | --status hoặc --resume (TRƯỚC parse args đầy đủ) |
| 0 | phase0-setup.md | Fresh run (entry point) |
| 1 | phase1-precheck.md | Always (sau Phase 0) |
| 2 | phase2-source-analysis.md | Always (sau Phase 1) |
| 3 | phase3-plan.md | Always (sau Phase 2) |
| 4 | phase4-system.md | $scope ∈ {full, system-only} |
| 5 | phase5-module.md | $scope ∈ {full, module-only} AND $user_choice != "skip" |
| 6 | phase6-detail.md | $plan có states/activities/sequences entries |
| 7 | phase7-validation.md | Always (sau Phase 4-6) |

### Routing Flow                     (~ 15 dòng diagram)

## Phase Summary (condensed)         (~ 30 dòng — chi tiết trong procedure files)

## Quy ước viết Mermaid 8.8.0 + DBML  (giữ nguyên — ~ 50 dòng)

## Error Handling Matrix             (~ 15 dòng — quick lookup, canonical _shared.md)

## Related Skills                    (~ 10 dòng)

## References                        (~ 20 dòng — list phase files)

TỔNG: ~250 dòng
```

---

## 3. Phase file template (chuẩn áp dụng cho 8 phase files)

Mỗi phase file self-contained, theo pattern wf-scan-target:

```markdown
# Phase N — {Tên Phase}

> Pointer ngắn cho người đọc: 1 câu mô tả phase này làm gì.

## PRE-GATE

```
- [ ] Điều kiện 1
- [ ] Điều kiện 2
```

## INPUT

| Source | Path / Variable | Note |
|--------|-----------------|------|
| ... | ... | ... |

## OUTPUT

| Path | Schema | Required |
|------|--------|----------|
| ... | ... | ... |

## Steps

### Step N.1 — {Tên step}

```bash
# bash code, dùng helper từ _shared.md hoặc gọi script
```

### Step N.2 — ...

## POST-GATE

```
- [ ] Output exists & non-empty
- [ ] Schema valid (jq validate)
- [ ] phases.phase_N.status = "done" trong checkpoint.json
```

## Error Handling

> Tham chiếu `_shared.md §Error Handling Matrix`. Bảng dưới chỉ là quick lookup.

| Code | Tình huống | Action |
|------|------------|--------|
| ... | ... | ... |

## Next Phase

→ Phase N+1 ({Tên})
```

---

## 4. `_shared.md` structure

```markdown
# Internal Shared Reference — wf-diagram

> Cross-cutting concerns dùng chung cho mọi phase file. SKILL.md và phase files
> tham chiếu file này khi cần helpers, state vars, error handling.

## State Variables Glossary

| Variable | Source | Description |
|----------|--------|-------------|
| $module | --module=<name> | ... |
| $source_path | --source-path=<path> | default `.` |
| $output_path | --output-path=<path> | default `.mc-data/docs/diagrams` |
| $scope | --scope=<value> | full \| module-only \| system-only |
| $session_id | Phase 0.4 | format `{YYYY-MM-DD}-{scope-label}[-{N}]` |
| $session_dir | computed | `.mc-data/work/wf-diagram/sessions/$session_id/` |
| $system_dir | computed (v1.2.0) | module-scoped path resolution |
| $user_choice | Phase 1.3 | overwrite \| skip \| update_missing \| null |
| $analysis | Phase 2 output | content từ analysis.json |
| $plan | Phase 3 output | content từ diagram-status.json.generation_plan |

## Helper Functions

### slugify()
```bash
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}
```
> Hoặc dùng `.claude/scripts/wf-diagram-common.sh::slugify`

### atomic_write_json(file, content)
> Pattern từ `scan-target-common.sh::atomic_write_json`

### append_trace_event(skill, session_id, phase, event)
> Pattern từ Protocol 15

## Agent Prompts

> wf-diagram KHÔNG spawn agents — toàn bộ logic là direct tool + bash.
> Mục này để trống.

## Error Handling Matrix (canonical)

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

## FAIL Event Handler

> Khi POST-GATE T1-T4 fail x3 retries:
> 1. Set diagram-status.status = "failed"
> 2. VẪN tạo phase-summary.md với STATUS="THẤT BẠI" (Protocol 14.1)
> 3. Append trace FAIL event với reason

## analysis.json Schema (analysis-v1)

```json
{
  "$schema": "analysis-v1",
  "session_id": "...",
  "scanned_at": "ISO-8601",
  "modules": [{ "name", "path", "type" }],
  "entities": [{ "name", "module", "columns": [...], "pk", "fks": [...] }],
  "endpoints": [{ "method", "path", "handler", "controller_class", "url_prefix", "sub_folder", "services_called": [...] }],
  "actors": [{ "name", "role", "modules_used": [...], "auth_pattern" }],
  "components": [{ "name", "module", "type", "depends_on": [...] }],
  "state_machines": [{ "entity", "states": [...], "transitions": [...] }],
  "processes": [{ "name", "module", "steps": [...], "decisions": [...], "swimlanes": [...] }],
  "scenarios": [{ "name", "module", "trigger", "participants": [...], "messages": [...], "is_async", "has_error_handling" }],
  "usecase_groups": [{ "group_name", "group_slug", "description", "use_cases": [...], "actors": [...], "grouping_basis" }]
}
```

> Phase 2 POST-GATE verify: `jq -e '.modules | length > 0' analysis.json`
```

---

## 5. Bash scripts design

### `wf-diagram-common.sh`

Helpers chung dùng cho mọi phase + chuẩn bị multi-dev v2.1:

```bash
#!/usr/bin/env bash
# wf-diagram-common.sh — Common helpers cho wf-diagram skill
# Source pattern: .claude/scripts/scan-target-common.sh

set -euo pipefail

# atomic_write_json <file_path> <json_content>
atomic_write_json() { ... }

# json_escape <string>  → escaped JSON string (no quotes)
json_escape() { ... }

# slugify <string>  → lowercase-kebab-case
slugify() { ... }

# parse_args <args>  → echo "module=X|source_path=Y|output_path=Z|scope=W|..."
parse_args() { ... }

# iso8601_now  → "2026-05-03T22:30:00Z"
iso8601_now() { ... }

# ensure_dir <path>  → mkdir -p with verify
ensure_dir() { ... }

# append_trace_event <skill> <session_id> <phase> <event>  → Protocol 15
append_trace_event() { ... }

# generate_session_id <scope_label>  → "{YYYY-MM-DD}-<scope-label>[-{N}]"
generate_session_id() { ... }
```

### `wf-diagram-source-scan.sh`

Phase 2 source scan — output `analysis.json` v1:

```bash
#!/usr/bin/env bash
# wf-diagram-source-scan.sh
# Usage: wf-diagram-source-scan.sh <source_path> <module> <scope> <output_file>

set -euo pipefail

source_path="$1"
module="$2"
scope="$3"
output_file="$4"

# 1. Detect tech stack (delegate hoặc inline)
# 2. Scan modules (folder/namespace/package)
# 3. Scan entities (migrations / ORM models / schema.prisma / EF DbContext)
# 4. Scan endpoints (controllers/routes)
# 5. Scan actors (auth middleware / role checks)
# 6. Scan state machines (enum *Status / type *State)
# 7. Detect usecase groups (controller_class / url_prefix / sub_folder)
# 8. Build analysis.json + atomic_write
# 9. jq validate

echo "{...}" > "$output_file"  # Pseudo
```

### `wf-diagram-mermaid-validate.sh`

POST-GATE T2 — grep 9 patterns block từ Mermaid 8.8.0 Safety Rules:

```bash
#!/usr/bin/env bash
# wf-diagram-mermaid-validate.sh <file>
# Returns: 0 PASS, 1 FAIL with reasons

set -euo pipefail
file="$1"

# 1. Check ```mermaid block exists
grep -q '```mermaid' "$file" || { echo "FAIL: missing mermaid block"; exit 1; }

# 2. Check 8.8.0 safety patterns
errors=()

# Em-dash trong label
grep -nE '\[[^]]*—[^]]*\]' "$file" && errors+=("em-dash trong label")

# Single quote trong label (chỉ check trong [...] hoặc (...))
grep -nE "\[[^]]*'[^]]*'" "$file" && errors+=("single quote trong label")

# subgraph multi-word không quote
grep -nE 'subgraph [A-Za-z0-9_]+ [A-Za-z]' "$file" && errors+=("subgraph multi-word không quote")

# ... 6 patterns còn lại

[ ${#errors[@]} -eq 0 ] || { echo "FAIL: ${errors[*]}"; exit 1; }
echo "PASS"
```

### `wf-diagram-dbml-validate.sh`

POST-GATE T2 cho DBML:

```bash
#!/usr/bin/env bash
# wf-diagram-dbml-validate.sh <file>

grep -q "^Project " "$file" || { echo "FAIL: missing Project block"; exit 1; }
grep -q "^Table " "$file" || { echo "FAIL: missing Table block"; exit 1; }

# Count columns trong Table block (≥1 mỗi block)
# ... awk parse

echo "PASS"
```

### `wf-diagram-resume-helper.sh`

`--status` display 5 latest sessions:

```bash
#!/usr/bin/env bash
# wf-diagram-resume-helper.sh
# Outputs Markdown table 5 latest sessions

sessions_root=".mc-data/work/wf-diagram/sessions"
[ -d "$sessions_root" ] || { echo "Chưa có session nào."; exit 0; }

ls -1t "$sessions_root" | head -5 | while read sid; do
  status=$(jq -r '.status // "unknown"' "$sessions_root/$sid/diagram-status.json" 2>/dev/null)
  module=$(jq -r '.module // "system"' "$sessions_root/$sid/diagram-status.json" 2>/dev/null)
  scope=$(jq -r '.scope // "?"' "$sessions_root/$sid/diagram-status.json" 2>/dev/null)
  echo "| $sid | $module | $scope | $status |"
done
```

---

## 6. Migration v1.2.0 → v2.0.0

### Backward compat checklist

- [x] Session dir format giống v1.2.0 → `--resume` v1.2.0 sessions OK
- [x] `diagram-status.json` schema giống — KHÔNG breaking change
- [x] `checkpoint.json` schema giống — KHÔNG breaking change
- [x] Output paths giống v1.2.0 (module-scoped `_system/`) — KHÔNG breaking change
- [ ] **Risk:** Phase numbering giữ nguyên (0-7) → ✅
- [ ] **Risk:** Nếu user có session v1.2.0 đang `paused` → resume vào v2.0 phải route đúng. Test case trong evals.

### Breaking changes (NONE expected)

Không có breaking changes về output paths, schema, hoặc behavior. v2.0 thuần refactor cấu trúc skill.

---

## 7. Phase Routing Flow (target)

```
SKILL.md entry → Parse $ARGUMENTS
  ├── --status → Read procedures/resume-status.md §CASE A → STOP
  ├── --resume → Read procedures/resume-status.md §CASE B → route to checkpoint.next_action.phase
  └── Fresh run → Read procedures/phase0-setup.md → execute → return
       ↓
Read procedures/phase1-precheck.md → execute → return
       ↓
Read procedures/phase2-source-analysis.md → execute → return
   (gọi: bash wf-diagram-source-scan.sh)
       ↓
Read procedures/phase3-plan.md → execute → return
       ↓ ($scope ∈ {full, system-only})
Read procedures/phase4-system.md → execute → return
   PARALLEL: 5 file system diagrams
       ↓ ($scope ∈ {full, module-only} AND $user_choice ≠ "skip")
Read procedures/phase5-module.md → execute → return
   PARALLEL: class.md + erd.dbml + N usecase group files
       ↓ ($plan có states/activities/sequences)
Read procedures/phase6-detail.md → execute → return
   PARALLEL: N state + N activity + N sequence files
       ↓
Read procedures/phase7-validation.md → execute → STOP (DONE)
   (gọi: bash wf-diagram-mermaid-validate.sh, wf-diagram-dbml-validate.sh)
```

---

## 8. Token saving estimate

| Phase | v1.2.0 (current) | v2.0 (target) | Saving |
|-------|------------------|---------------|--------|
| Load SKILL.md | ~15K (565 dòng × ~28 ch/dòng) | ~7K (~250 dòng) | -53% |
| Load detailed phase steps | ~28K (flow-new.md 915 dòng) | Lazy-load 1 file ~6K | -78% |
| Phase 2 source scan | AI inline grep (~3K) | Bash delegation (~500 token) | -83% |
| Phase 4-6 generation | AI render từng file | AI render PARALLEL | Không đổi token |
| **Tổng (typical run)** | ~46K | ~14K | **-69%** |

> Estimates tham khảo wf-scan-target Sprint 4 (88% bash saving cho enumeration).

---

## 9. Open questions → `03-decisions-pending.md`

(Xem file riêng — 4 quyết định chính cần user duyệt trước Sprint 2)
