# Progress — wf-diagram v2.0

**Last updated:** 2026-05-03 (Sprint 6 COMPLETED — v2.0.0 RELEASED)
**Phiên hiện tại:** DONE
**Phiên bản đích:** v2.0.0 ✅ RELEASED

---

## Tổng quan trạng thái

| Sprint | Tên | Status | Effort | Phiên |
|--------|-----|--------|--------|-------|
| 1 | Decisions + Gap Analysis | ✅ COMPLETED | 1h | 1/1 done |
| 2 | Split monolith (SKILL.md + 8 phase files + `_shared.md`) | ✅ COMPLETED | 3h | 1/1 |
| 3 | Resume + session-init | ✅ COMPLETED | 2h | 1/1 |
| 4 | Bash scripts (5 scripts) | ✅ COMPLETED | 1.5h | 1/1 |
| 5 | Templates audit + Evals expansion | ✅ COMPLETED | 1.5h | 1/1 |
| 6 | Compliance audit + Smoke test | ✅ COMPLETED | 1.5h | 1/1 |

**Tổng:** ~12-15h, ước tính 6-8 phiên (theo D1=A — chỉ refactor cấu trúc)

---

## Sprint 1 — Decisions + Gap Analysis

**Status:** ✅ COMPLETED 2026-05-03

### Đã làm
- ✅ Phân tích `wf-diagram` SKILL.md (565 dòng), `_contract.json`, `procedures/flow-new.md` (918 dòng), `evals/evals.json`, 14 templates
- ✅ Đối chiếu với 3 skill đã overhaul: `wf-scan-target` v2.0.1, `wf-add-scope` v3.0.0
- ✅ Tạo `00-master-plan.md`, `01-compliance-gaps.md`, `02-architecture-design.md`, `03-decisions-pending.md`, `README.md`, `_next-session-prompt.md`
- ✅ Lưu memory entry `project_wf-diagram-v2-improvement-plan.md`
- ✅ Decisions resolved (All A): D1=A (chỉ refactor), D2=A (5 scripts), D3=A (chỉ patch), D4=A (defer v2.1)

### Files tạo
- `plans/wf-diagram-v2/00-master-plan.md`
- `plans/wf-diagram-v2/01-compliance-gaps.md`
- `plans/wf-diagram-v2/02-architecture-design.md`
- `plans/wf-diagram-v2/03-decisions-pending.md` (All A marked)
- `plans/wf-diagram-v2/progress.md`
- `plans/wf-diagram-v2/README.md`
- `plans/wf-diagram-v2/_next-session-prompt.md`

---

## Sprint 2 — Split monolith

**Status:** ✅ COMPLETED 2026-05-03

### Plan
- Backup `procedures/flow-new.md` → `procedures/flow-legacy.md.bak`
- Tạo `procedures/_shared.md` (state vars, helpers, error matrix, analysis.json schema)
- Tạo 8 phase files: phase0-setup, phase1-precheck, phase2-source-analysis, phase3-plan, phase4-system, phase5-module, phase6-detail, phase7-validation
- Refactor `SKILL.md` thành routing hub ≤ 250 dòng
- Update `_contract.json.procedure_files[]` thành 11 entries

### Verify checklist
- [x] SKILL.md = 240 dòng (≤250 ✅)
- [x] Mỗi phase file ≤ 250 dòng (max: phase7=159, phase0=132) ✅
- [x] Mỗi phase file self-contained (PRE-GATE, Steps, POST-GATE, Next Phase) ✅
- [x] `_shared.md` referenced từ tất cả phase files ✅
- [x] `flow-legacy.md.bak` tồn tại ✅
- [x] `_contract.json.procedure_files[]` có 11 entries ✅
- [x] Compliance audit PASS (12/12 CRITICAL, 12/13 REQUIRED) ✅

### Task tracking
- [x] 2.0 Tạo `sprints/sprint-2-split.md`
- [x] 2.1 Backup flow-new.md → flow-legacy.md.bak
- [x] 2.2 Tạo `procedures/_shared.md` (145 dòng)
- [x] 2.3 Tạo `procedures/phase0-setup.md` (132 dòng)
- [x] 2.4 Tạo `procedures/phase1-precheck.md` (93 dòng)
- [x] 2.5 Tạo `procedures/phase2-source-analysis.md` (140 dòng)
- [x] 2.6 Tạo `procedures/phase3-plan.md` (123 dòng)
- [x] 2.7 Tạo `procedures/phase4-system.md` (132 dòng)
- [x] 2.8 Tạo `procedures/phase5-module.md` (105 dòng)
- [x] 2.9 Tạo `procedures/phase6-detail.md` (111 dòng)
- [x] 2.10 Tạo `procedures/phase7-validation.md` (159 dòng)
- [x] 2.11 Refactor SKILL.md → routing hub 240 dòng (≤250 ✅)
- [x] 2.12 Update `_contract.json` → version 2.0.0, procedure_files[] 11 entries
- [x] 2.13 Smoke test: **PASS** 12/12 CRITICAL (100%), 12/13 REQUIRED (92%)

---

## Sprint 3 — Resume + session-init

**Status:** ✅ COMPLETED 2026-05-03

### Kết quả
- `procedures/resume-routing.md` (~145 dòng): CASE A/B/C, routing table phase_0..phase_7, trace RESUME
- `procedures/session-init.md` (~90 dòng): SI-1..SI-5, POST-GATE, Called By table
- `phase0-setup.md` Step 0.0 updated → reference resume-routing.md
- SKILL.md Phase Routing Map updated → 2 entries mới
- `_contract.json` procedure_files[] 11 → 13 entries
- Compliance: PASS 12/12 CRITICAL (100%), 12/13 REQUIRED (92%) ✅

### Task tracking
- [x] 3.1 Tạo `procedures/resume-routing.md` (145 dòng)
- [x] 3.2 Tạo `procedures/session-init.md` (90 dòng)
- [x] 3.3 Update `phase0-setup.md` Step 0.0
- [x] 3.4 Update SKILL.md Phase Routing Map (2 entries)
- [x] 3.5 Update `_contract.json` procedure_files[] → 13 entries
- [x] 3.6 Compliance audit PASS

---

## Sprint 4 — Bash scripts

**Status:** ✅ COMPLETED 2026-05-03

### Kết quả

5 scripts trong `.claude/scripts/`:

| Script | Size | Mục đích |
|--------|------|----------|
| `wf-diagram-common.sh` | 7.7K | Helpers: log_*, slugify, json_escape, atomic_write_json, safe_write_json, iso8601_now, ensure_dir, append_trace_event (Protocol 15), generate_session_id (Protocol 18.2) |
| `wf-diagram-source-scan.sh` | 14.6K | Phase 2 → analysis.json. Scan modules (folder + .NET namespace), entities (Prisma + TypeORM + SQL + EF DbContext), endpoints (Express/NestJS/.NET/Spring), actors (auth patterns), state_machines (enum *Status/State). Best-effort — mark `_todo` cho fields cần AI refine |
| `wf-diagram-mermaid-validate.sh` | 7.2K | POST-GATE T2: 9 patterns (em-dash, single-quote, subgraph multi-word, `<br/>`, colon, `&` chain, `()`, reserved keyword END, emoji+parens). Cross-platform (LC_ALL=C trick cho byte literals) |
| `wf-diagram-dbml-validate.sh` | 4.3K | POST-GATE T2: Project block, Table blocks, empty tables, inline `[ref:]` warning, external table comment warning |
| `wf-diagram-resume-helper.sh` | 2.8K | --status display 5 latest sessions Markdown table (sort by mtime, parse diagram-status.json phases) |

### Smoke tests (đã chạy)

- common.sh: slugify "Order Status" → "order-status" ✅
- common.sh: generate_session_id module=Order, scope=full → 2026-05-03-order ✅
- source-scan.sh: synthetic NestJS+TypeORM+SQL → modules=2 entities=3 endpoints=2 sm=1 ✅
- mermaid-validate.sh: GOOD passes, BAD detects 8/9 issues, EMPTY block detected ✅
- dbml-validate.sh: GOOD passes, BAD detects 4 issues (missing Project, empty table, inline ref, external) ✅
- resume-helper.sh: empty dir + 2 synthetic sessions render đúng table ✅

### Task tracking

- [x] 4.1 wf-diagram-common.sh (7 helpers + atomic write + trace event + session ID)
- [x] 4.2 wf-diagram-source-scan.sh (4 entity strategies + 4 endpoint strategies + actors + state machines)
- [x] 4.3 wf-diagram-mermaid-validate.sh (9 Mermaid 8.8.0 safety patterns)
- [x] 4.4 wf-diagram-dbml-validate.sh (Project/Table/empty/inline/external)
- [x] 4.5 wf-diagram-resume-helper.sh (--status table 5 sessions)
- [x] 4.6 Smoke tests pass cho 5 scripts

### Findings cho sprint sau

- `source-scan.sh` để `processes`, `scenarios`, `usecase_groups` rỗng → AI tầng phase3-plan derive từ `endpoints + entities` (vì cần hiểu business logic, bash heuristic dễ false positive). Phase3 procedure sẽ document rõ contract này
- `mermaid-validate.sh` Check 7 (`()` trong label) có thể fire khi label legit có `(note)` đã quote — Sprint 5 có thể tinh chỉnh false positive nếu cần
- Phase 2 SKILL.md hiện ghi inline scan logic (steps 2.1-2.6); Sprint 5 cần update để gọi `bash wf-diagram-source-scan.sh` thay vì AI inline scan

---

## Sprint 5 — Templates audit + Evals expansion

**Status:** ✅ COMPLETED 2026-05-03

### Kết quả

**Task 5.1 — Wire bash scripts:**
- `phase2-source-analysis.md`: Replaced Steps 2.1-2.5 (AI inline scan) với bash call `wf-diagram-source-scan.sh`. Step 2.6 → verify only. PRE-GATE: note bash ≥4 + jq requirement.
- `phase7-validation.md`: Replaced Step 7.2 inline grep patterns với script calls `wf-diagram-mermaid-validate.sh` + `wf-diagram-dbml-validate.sh`. Exit code 0=PASS, 1=FAIL.

**Task 5.2 — Template audit:**
- 8 Mermaid templates: ALL PASS ✅ (sau khi fix validator)
- 2 DBML templates: PASS_WITH_WARNINGS ✅ (exit 0, template mode detection)
- `phase-summary.md`: Protocol 14 fields đầy đủ ✅
- `diagram-status.json` + `checkpoint.json`: Schema match _shared.md ✅

**Validator fixes (root cause của 3 failures):**
- `wf-diagram-mermaid-validate.sh`: Filter `%%` comment lines trước khi chạy checks (false positive trên `%% E1[(Database)]` trong templates)
- `wf-diagram-dbml-validate.sh`: Template mode detection — nếu file có `[PLACEHOLDER_BLOCKS]`, skip Check 2+3 (Table count), emit PASS_WITH_WARNINGS

**Task 5.3+5.4 — Evals:**
- 5 evals existing: Updated với output paths mới (`modules/{module}/usecases/` pattern), session_id format `{YYYY-MM-DD}-{module-slug}`, session_files section
- 3 evals mới: EVAL-006 (resume in-progress), EVAL-007 (large module 10 entities), EVAL-008 (error source-path missing)
- Total: 8 evals ✅
- Schema valid: `jq -e '(.evals | length) >= 8 and (.evals[0] | has("id"))'` → true ✅

**Compliance audit:** PASS (12/12 CRITICAL, 12/13 REQUIRED — 1 warning by design) ✅
**Schema sync:** PASS ✅

### Verify checklist Sprint 5

- [x] `phase2-source-analysis.md` Steps 2.1-2.5 đã replace bằng bash call
- [x] `phase7-validation.md` Step 7.2 đã replace bằng script call
- [x] Tất cả 8 Mermaid templates PASS validators
- [x] Tất cả 2 DBML templates PASS_WITH_WARNINGS (exit 0)
- [x] `phase-summary.md` template có đủ Protocol 14 fields
- [x] `diagram-status.json` + `checkpoint.json` schema match `_shared.md`
- [x] `evals.json` có 8 entries (5 updated + 3 new)
- [x] `jq '.'` trên evals.json PASS (valid JSON)
- [x] Compliance audit sau Sprint 5 vẫn PASS

---

## Sprint 6 — Compliance audit + Smoke test

**Status:** ✅ COMPLETED 2026-05-03

### Kết quả

**Task 6.1 — Full compliance audit:**
- Compliance: PASS (12/12 CRITICAL, 12/13 REQUIRED — 1 warning by design) ✅
- Schema sync: PASS ✅

**Task 6.2 — Smoke test scripts trên EUREKA-2026:**
- `wf-diagram-source-scan.sh` on `/apps/backend` + module=orders: ✅
  - modules=100 (all .NET namespaces detected — expected, AI filters in Phase 3)
  - entities=103 (EF DbContext DbSet + SQL tables, incl. partitions — best-effort)
  - endpoints=0 → FIXED: Added Strategy 3b cho .NET Minimal API (`MapGet/MapPost/etc.`) → endpoints=200 ✅
  - state_machines=93 (enums with *Status/*State suffix — expected)
- `wf-diagram-resume-helper.sh --status` empty dir: renders table đúng ✅
- `wf-diagram-mermaid-validate.sh` on system-context template: PASS ✅

**Finding F-01 — .NET Minimal API endpoint detection:**
- Root cause: Strategy 3 chỉ detect `[HttpGet]` attribute style
- EUREKA-2026 dùng `group.MapGet()` minimal API style
- Fix: Added Strategy 3b: grep `.Map(Get|Post|Put|Delete|Patch)(` → endpoints: 0 → 200 ✅
- Applied in `wf-diagram-source-scan.sh` (new strategy between Strategy 3 và 4)

**Task 6.3 — Version bumps:**
- `diagram-status.json` template: "version" 1.0.0 → 2.0.0 ✅
- `checkpoint.json` template: "skill_version" 1.0.0 → 2.0.0 ✅
- `_contract.json` description: updated, removed v1.2.0 ref, added v2.0.0 summary ✅
- `_contract.json` procedure_files: removed `flow-new.md` + `flow-legacy.md.bak` (legacy/backup — not active procedures) ✅
- Final compliance audit: PASS ✅

### Verify checklist Sprint 6

- [x] Compliance audit PASS (12/12 CRITICAL) ✅
- [x] Schema sync PASS ✅
- [x] Smoke test scripts PASS (source-scan + resume-helper + mermaid-validator) ✅
- [x] `analysis.json` tạo bởi bash script (endpoints=200 sau fix) ✅
- [x] Phase 7 T2 validators chạy qua scripts ✅
- [x] SKILL.md + _contract.json version = 2.0.0 ✅
- [x] `diagram-status.json` + `checkpoint.json` version = 2.0.0 ✅

---

## Risks active

| Risk | Mức độ | Mitigation status |
|------|--------|-------------------|
| Refactor làm hỏng v1.2.0 đang chạy | HIGH | Sprint 2: backup `flow-new.md` → `.bak`; SKILL.md refactor giữ nguyên logic routing |
| Bash scripts không cross-platform | MEDIUM | Sprint 4 sẽ source patterns từ `legacy-scan-common.sh` đã proven |
| `analysis.json` schema drift | MEDIUM | Sprint 2: define schema rõ trong `_shared.md` |

---

## Notes giữa các phiên

### 2026-05-03 — Sprint 1 + Sprint 2 (bắt đầu)
- Decisions All A: D1=A (chỉ refactor cấu trúc), D2=A (5 bash scripts), D3=A (chỉ patch templates), D4=A (defer multi-dev v2.1)
- Phiên khác đang làm `wf-verify-sync v3.0` — KHÔNG đụng vào skill đó
- flow-new.md là 918 dòng (8 phases + error matrix + slugify helper)
- SKILL.md là 565 dòng — cần shrink về ≤ 250 dòng routing hub
- Reference pattern: wf-scan-target SKILL.md = 380 dòng routing hub (có Phase Routing Map table)

### Sprint 2 COMPLETED — Results
- SKILL.md: 565 dòng → 240 dòng routing hub (-57%) ✅
- procedures/: 1 file (918 dòng) → 11 files (93-159 dòng mỗi file) ✅
- _contract.json: version 1.2.0 → 2.0.0, procedure_files[] 1→11 entries ✅
- Compliance: PASS (12/12 CRITICAL, 12/13 REQUIRED) — 1 warning expected for routing hub
- Remaining 1 REQUIRED warning: "4.5 Multiple phases (≥2 in SKILL.md)" — by design (phases in procedures/)

### Sprint 3 COMPLETED — Results
- resume-routing.md: CASE A (--status table) + CASE B (--resume pick/route) + routing table phase_0..7
- session-init.md: SI-1 SESSION_ID + SI-2 dirs + SI-3 diagram-status.json + SI-4 checkpoint.json + SI-5 trace START
- No lock file (D4=A defer multi-dev safety to v2.1), no fingerprint check (local source only)
- procedure_files[]: 11 → 13 entries; Compliance PASS maintained

### Sprint 4 COMPLETED — Results

- 5 scripts: common (7.7K) + source-scan (14.6K) + mermaid-validate (7.2K) + dbml-validate (4.3K) + resume-helper (2.8K) = ~36.6K total
- Tất cả qua `bash -n` syntax check + smoke test với synthetic fixtures
- Source scan output `_todo` markers cho ambiguous fields → AI tầng trên refine sau (BHV-002)
- `processes`/`scenarios`/`usecase_groups` cố ý empty trong analysis.json — sẽ được Phase 3 derive
- Cross-platform: ANSI-C `$'\xe2\x80\x94'` cho em-dash byte literal (Windows Git Bash safe), `[[:space:]]` thay vì `\s` (POSIX ERE)

### Sprint 5 COMPLETED — Results

- Validators fixed: mermaid (filter %% comments), dbml (template mode detection)
- 8 Mermaid + 2 DBML templates: ALL PASS (exit 0) ✅
- phase2-source-analysis.md: AI inline steps → bash wf-diagram-source-scan.sh ✅
- phase7-validation.md: inline grep → script calls ✅
- evals.json: 5 updated + 3 new = 8 total ✅
- Known: evals.json check in sprint plan used `(. | type) == "array"` (root type) but file is wrapper object → corrected check: `(.evals | type) == "array"` → PASS ✅

### Sprint 6 COMPLETED — v2.0.0 RELEASED

- Compliance PASS (12/12 CRITICAL) + Schema sync PASS ✅
- Smoke test: source-scan EUREKA-2026 (modules=100, entities=103, endpoints=200 after fix, sm=93) ✅
- **F-01 fix: .NET Minimal API detection** — Added Strategy 3b `MapGet/MapPost` → endpoints: 0→200
- Version bumps: SKILL.md=2.0.0, _contract.json=2.0.0, diagram-status.json=2.0.0, checkpoint.json=2.0.0 ✅
- _contract.json cleanup: removed flow-new.md + flow-legacy.md.bak from procedure_files ✅
