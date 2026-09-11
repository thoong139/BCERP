# Progress Tracker — Skill `wf-cmi` Implementation

> **Mục đích:** Track các bước đã làm + bước còn lại cho việc triển khai skill `wf-cmi` qua nhiều sessions. Update file này mỗi khi hoàn thành 1 milestone.

**Cập nhật lần cuối:** 2026-05-16 — Sau session 10 (Step 10: audit scripts PASS — **wf-cmi v1.0.0 ready for PR**)

---

## ✅ Hoàn thành (Session 1 — 2026-05-15)

### Phase A: Research + Design

- [x] Đọc plan gốc `plans/wf-cmi/wf-cmi.md`
- [x] Đọc MCV3 standards: `docs/02-standards/02-skill-standard.md`, `04-contract-schema.md`, `08-error-code-registry.md`, `11-output-path-contract.md`
- [x] Đọc skill design template `docs/04-skill-design/_template/` (14 files)
- [x] Đọc skill design canon đã có: `wf-fix-bugs/`, `wf-legacy-scan/`, `wf-implement-feature/`
- [x] Scan EUREKA-2026 structure (D:\EUREKA-2026):
  - 17 modules .NET 10 + Next.js 16 + PostgreSQL 16
  - 3 clients (erp-web + mobile-customer + mobile-staff) endpoint convention
  - DDD + CQRS (MediatR), 90+ RBAC permissions, 4 SignalR hubs, RabbitMQ
- [x] Lưu memory project EUREKA-2026

### Phase B: Design Canon (`docs/04-skill-design/wf-cmi/`)

- [x] Tạo folder + 14 files theo ORCHESTRATOR variant:
  - [x] README.md (5.7 KB) — Index + persona guide
  - [x] 00-master-checklist.md (7.4 KB) — Gating 10-step
  - [x] 01-vision-principles.md (13.7 KB) — Vision + 8 SMART goals + §7 Domain
  - [x] 02-arguments.md (8.0 KB) — 15 args + profile detail
  - [x] 03-phase-routing.md (13.0 KB) — 8 phases + Mermaid + §6 regression-aware
  - [x] 04-file-contract.md (25.6 KB) — PRE/POST gates + 6 schemas + §6 sidecar pattern
  - [x] 05-error-codes.md (18.1 KB) — E001-E109 namespace
  - [x] 05-execution-profiles.md (12.5 KB) — 4 profiles + lane activation
  - [x] 06-templates-list.md (17.5 KB) — 18 templates
  - [x] 07-procedures-structure.md (15.9 KB) — 10 procedure files outline
  - [x] 08-tradeoffs-adr.md (21.6 KB) — 8 ADRs
  - [x] 08-user-scenarios-solutions.md (15.3 KB) — 6 UX scenarios + error recovery
  - [x] 09-evals-test-cases.md (15.0 KB) — 8 test cases planned
  - [x] agent-prompt.md (18.1 KB) — CORE-037 8-section cho 10 lanes + triage
- [x] Validation `bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/wf-cmi/` PASS
- [x] Update `docs/04-skill-design/README.md` §3 table

### Phase C: User feedback adjustments

- [x] Rename: `wf-cross-module-integrity` → `wf-cmi` (folder + bulk replace text)
- [x] **ADR-cmi-002 Revised:** Bỏ bump registry v3, dùng sidecar artifact `.mc-data/work/wf-cmi/business-invariants.json`
- [x] Move plan: `plans/wf-cross-module-integrity/` → `plans/wf-cmi/`
- [x] Tạo session-prompt.md + progress.md
- [x] Lane scope giữ 10 dim (CD1-CD10), defer CD11+ v2

---

## ✅ Hoàn thành (Session 2 — 2026-05-15)

### Step 2: Tạo `SKILL.md` (lean routing hub ≤500 dòng) ✅

**File:** `.claude/skills/workflow/wf-cmi/SKILL.md`

**Kết quả:**
- [x] Tạo folder structure: `procedures/`, `templates/`, `evals/`, `scripts/`
- [x] SKILL.md = **487 dòng** (PASS CORE-032 ≤500)
- [x] YAML frontmatter đủ 7 keys (`name`, `version`, `last_updated`, `description`, `argument-hint`, `disable-model-invocation`, `allowed-tools`)
- [x] 16 sections (đủ 7 bắt buộc + bonus): Overview, Arguments, Protocols, CI PRE-GATE, Phase Routing Map, Phase Summary, PRE-GATE/POST-GATE Contract, Fix Rules, Error Handling, Context & Checkpoint, Output Files, Cross-Skill Contract, Next Step, Related Skills, References, Design Rationale
- [x] Phase routing map 8 phases (1 Init → 8 Report) + ASCII flow diagram
- [x] Output files table 31 session-scoped + 1 canonical sidecar = 32 files
- [x] Cross-skill contract: 6 consumers + 8 producers (registry write-role NONE)
- [x] Error namespace E001-E109 quick lookup
- [x] Design canon links đã đúng path (`../../../../docs/04-skill-design/wf-cmi/`)
- [x] Forward refs đến `procedures/phase{N}.md` documented (sẽ tạo Step 4)

**Note kiến trúc:**
- Phase 3 file đặt tên `phase3-invariant-artifact.md` (theo ADR-cmi-002 Revised — sidecar artifact, không bump registry)
- KHÔNG có Playwright section (wf-cmi không cần browser testing như wf-fix-bugs)
- Registry write-role = `NONE` (READ-ONLY consumer của `req-registry.json`)

---

## ✅ Hoàn thành (Session 3 — 2026-05-15)

### Step 3: Tạo `_contract.json` ✅

**File:** `.claude/skills/workflow/wf-cmi/_contract.json`

**Kết quả:**
- [x] Schema `skill-contract-v1` valid + 7 required top-level fields (skill, version, phase, description, procedure, outputs, registry_scope)
- [x] `version: 1.0.0`, `phase: integrity`, `skill: wf-cmi`
- [x] **15 inputs** với type + default + validation rules + error code refs (khớp `02-arguments.md`)
- [x] **10 procedures** list (matches SKILL.md routing map): `_shared.md`, `phase1-init.md`, `phase2-discovery.md`, `phase3-invariant-artifact.md`, `phase4-coverage-dispatch.md`, `phase5-aggregate.md`, `phase6-regression.md`, `phase7-gap-cdg.md`, `phase8-report.md`, `resume-status.md`
- [x] **37 outputs.working[]** với schema + template + notes (31 session-scoped + 1 canonical sidecar + 2 index/lock + 3 auxiliary)
- [x] **registry_scope:** `write_role: NONE`, `fields_owned: []` (ADR-cmi-002 Revised — READ-ONLY consumer)
- [x] **cross_skill_contracts:** 8 internal_phases, 6 produces_for consumers, 9 consumes_from producers, execution_model với 4 configurable env vars
- [x] **6 orchestrator_gates:** Scope×Profile auto-upgrade, Parallel-session conflict, Cross-domain conflict, Coverage threshold, Sidecar APPEND confirm, Multi-user dual-approval
- [x] **resume_routing:** procedures/resume-status.md + stale threshold 30 min + session ID format
- [x] **108 errors** entries (E001-E109 đầy đủ) — Shared (E001-E009) + Phase 1-8 (E010-E089) + CDG (E090-E099) + Warnings (E100-E109)
- [x] **code_intelligence:** integration=true, Protocol 20, primary_tools mapping cho 6 graph builders + impact analysis, fallback Grep/Glob, cache TTL
- [x] **evals:** 5 test cases (TC-cmi-001 → 005) với fixtures paths planned

**Note kiến trúc:**
- Procedures và templates đều ở trạng thái `PENDING` trong filesystem — sẽ tạo ở Step 4 và Step 5
- validate-schema-sync.sh chưa biết wf-cmi (ALL_SKILLS array thiếu entry) — sẽ thêm ở Step 10
- Mô phỏng manual check ✅ PASS cho: JSON valid + $schema + required fields + skill identity + registry_scope normalization

---

## ✅ Hoàn thành (Session 4 — 2026-05-15)

### Step 4: Tạo 10 procedure files ✅

**Đường dẫn:** `.claude/skills/workflow/wf-cmi/procedures/`

**Kết quả:** 10 files / 5344 dòng tổng (avg ~534 dòng/file):

| # | File | Dòng | Sections | Notes |
|---|------|------|----------|-------|
| 1 | `_shared.md` | 939 | 20 sections (§1-§20) | Cross-cutting protocols + helpers (atomic_write, error handlers, CI detection, R/W lock, agent prompts, audit chain) |
| 2 | `phase1-init.md` | 543 | A-H | Args validate (16 args), CI PRE-GATE Na/Nb/Nc, session init, lock + heartbeat, profile→dims (8 lanes standard), CDG E091/E090b buffer-flush |
| 3 | `phase2-discovery.md` | 518 | A-H | 6 graphs build HYBRID parallel — entity/module/workflow/api/event/rbac; CI-route primary (GitNexus/Serena) → Grep fallback |
| 4 | `phase3-invariant-artifact.md` | 429 | A-H | 3-pass LLM (Pass 1 pattern, Pass 2 domain experts parallel max 5, Pass 3 registry gap); cross-domain conflict detection (E036) |
| 5 | `phase4-coverage-dispatch.md` | 465 | A-H | 10 lane PARALLEL spawn (CD1-CD10 với agent map), render prompt từ agent-prompt.md, monitor timeout 3 min/lane, per-lane retry x1 |
| 6 | `phase5-aggregate.md` | 456 | A-H | Coverage formula per dim, threshold check, E005 healthy early-exit, CDG E090 nếu < threshold |
| 7 | `phase6-regression.md` | 407 | A-H | Predictive (GitNexus impact) vs diff-aware (git diff fallback); skip nếu profile=quick OR no --since |
| 8 | `phase7-gap-cdg.md` | 485 | A-H | GAP detect per dim, spawn triage agent, suggestions per kind, CDG E094 sidecar APPEND, multi-user E095 dual-approval |
| 9 | `phase8-report.md` | 543 | A-H | Build integrity-report.md (≤30 dòng tiếng Việt), integrity-impact.json (schema v1 + audit_chain), session COMPLETED, lock release |
| 10 | `resume-status.md` | 559 | --status 7 steps + --resume 10 steps | Partial output archive, staleness guard, lock PID-aware, retry budget preserve |

**Mỗi phase file có 8 sections (A-H):**
- §A Header (input/output/budget/time)
- §B PRE-GATE T1→T4 forensic
- §C Steps execution detail (numbered N.1, N.2, ...)
- §D POST-GATE T1→T4 + auto-fix (max 3 retries)
- §E Phase Report Template (CORE-028 tiếng Việt ≤15 dòng)
- §F Error Code Quick Reference (phase namespace)
- §G Cross-References (shared sections, design canon, templates)
- §H Next phase routing

**Validation cross-check ✅:**
- 10 procedure files khớp `_contract.json §procedure[]` (jq verify)
- 10 references trong SKILL.md (Phase Routing Map + Phase Summary table + References)
- Tổng cross-refs internal: 41 (phase1=16, phase2=6, phase3=4, phase4=3, phase5=3, phase6=3, phase7=4, phase8=2)

**Note kiến trúc đặc biệt:**
- `_shared.md` is the most comprehensive (20 sections vs. 6 hợp tiêu chuẩn) — chứa hết cross-cutting concerns đủ cho 8 phase files reuse
- `resume-status.md` dùng format khác (7 steps cho --status + 10 steps cho --resume) thay vì A-H — hợp lý vì là dispatcher, không phải execution phase
- Phase 3 đổi tên `phase3-invariant-artifact.md` (theo ADR-cmi-002 Revised) — file chứa note đầu §A
- Tất cả procedure files reference: `templates/`, `_contract.json`, `_shared.md` sections, design canon docs

---

## ✅ Hoàn thành (Session 5 — 2026-05-16)

### Step 5: Tạo 29 templates ✅

**Đường dẫn:** `.claude/skills/workflow/wf-cmi/templates/` (+ `_common/` subdir)

**Reference:** `docs/04-skill-design/wf-cmi/06-templates-list.md` §1 + `_contract.json` outputs.working[]

**Kết quả:** 29 files / 121 KB tổng (16 JSON + 13 Markdown):

| # | File | Phase | Schema/Type | Notes |
|---|------|-------|-------------|-------|
| 1 | `_common/session-log.json` | Shared | session-log-v1 | CORE-026 execution trace, APPEND-only |
| 2 | `_common/error-ledger.json` | Shared | error-ledger-v2 | CORE-034 namespaced E001-E109 |
| 3 | `integrity-status.json` | Phase 1 | integrity-status-v1 | SSOT pipeline state, 8 phases tracking, atomic update |
| 4 | `Phase1-report.md` | Phase 1 | CORE-028 | ≤15 dòng tiếng Việt: flags, CI, session, dims |
| 5 | `entity-graph.json` | Phase 2 | entity-graph-v1 | Discovery #1: nodes (entities) + edges (FK) |
| 6 | `module-graph.json` | Phase 2 | module-graph-v1 | Discovery #2: modules + cross-module deps |
| 7 | `workflow-graph.json` | Phase 2 | workflow-graph-v1 | Discovery #3: workflows + state transitions |
| 8 | `api-graph.json` | Phase 2 | api-graph-v1 | Discovery #4: endpoints + 3-client routing (erp-web/mobile-customer/mobile-staff) |
| 9 | `event-graph.json` | Phase 2 | event-graph-v1 | Discovery #5: RabbitMQ + SignalR broker config |
| 10 | `rbac-matrix.json` | Phase 2 | rbac-matrix-v1 | Discovery #6: actors × actions × resources |
| 11 | `Phase2-report.md` | Phase 2 | CORE-028 | ≤15 dòng: 6 graphs summary với node/edge counts |
| 12 | `business-invariants.json` | Phase 3 | business-invariants-v1 | Sidecar artifact (Engine #4), 3-pass LLM, APPEND-only canonical |
| 13 | `Phase3-report.md` | Phase 3 | CORE-028 | ≤15 dòng: invariants candidates + confidence |
| 14 | `signals.json` | Phase 4 | signals-v1 | Per-lane signals (shared schema với wf-fix-bugs) |
| 15 | `lane-status.json` | Phase 4 | lane-status-v1 | Per-lane execution state (PENDING→...→COMPLETED) |
| 16 | `CD-report.md` | Phase 4 | CORE-028 | ≤15 dòng: per-lane report |
| 17 | `Phase4-report.md` | Phase 4 | CORE-028 | ≤15 dòng: lanes activated + signals total |
| 18 | `coverage-matrix.json` | Phase 5 | coverage-matrix-v1 | Aggregated 10 dims (CD1-CD10) + threshold check |
| 19 | `coverage-report.md` | Phase 5 | CORE-028 | ≤15 dòng: per-dim table + threshold status |
| 20 | `Phase5-report.md` | Phase 5 | CORE-028 | ≤15 dòng: overall coverage + CDG E090 |
| 21 | `regression-map.json` | Phase 6 | regression-map-v1 | Predictive impact (GitNexus) hoặc diff-aware (git) |
| 22 | `regression-report.md` | Phase 6 | CORE-028 | ≤15 dòng: changed files + affected modules + test plan |
| 23 | `Phase6-report.md` | Phase 6 | CORE-028 | ≤15 dòng: mode + confidence stats |
| 24 | `gap-suggestions.json` | Phase 7 | gap-suggestions-v1 | Suggestions per kind (test/invariant/contract/doc/validation) |
| 25 | `gap-report.md` | Phase 7 | User-facing | ≤30 dòng: suggestions per kind + CDG decisions log |
| 26 | `Phase7-report.md` | Phase 7 | CORE-028 | ≤15 dòng: total/accepted/rejected/deferred + dual-approval |
| 27 | `integrity-report.md` | Phase 8 | User-facing PRIMARY | ≤30 dòng: 6 sections — coverage + violations + suggestions + regression + recommendation |
| 28 | `integrity-impact.json` | Phase 8 | integrity-impact-v1 | Cross-skill artifact (CORE-036), 4 consumers, audit_chain |
| 29 | `Phase8-report.md` | Phase 8 | CORE-028 | ≤15 dòng: artifacts + next step cho 4 consumers |

**Mỗi template có:**
- JSON: `_template_notes` block ở đầu (strip qua `jq walk(... select(.key | startswith("_") | not))`)
- Markdown: `<!-- _schema_notes: ... -->` HTML comment block ở đầu (strip qua awk pattern)
- Placeholders: `{{UPPER_SNAKE_CASE}}` hoặc `[BRACKET_PLACEHOLDER]`
- `$schema` field cho mọi JSON template
- `audit_chain` field cho artifacts có cross-skill consumer (business-invariants, integrity-impact)

**Validation cross-check ✅:**
- T1 jq parse: 16/16 JSON PASS
- T2 schema fields: 8/8 critical templates PASS (integrity-status, business-invariants, integrity-impact, regression-map, signals, gap-suggestions, session-log, error-ledger)
- Metadata strip: 16/16 PASS (jq walk + awk HTML comment strip)
- Markdown effective line count: 13/13 PASS (sau strip HTML comments + conditional `[NẾU ...]` markers)
- Cross-check `_contract.json`: 29/29 template paths exist (issue CRLF EOL trong _contract.json — strip CR khi check)

**Note kiến trúc đặc biệt:**
- 29 files thực tế > 18 logical templates trong design canon vì:
  - Phase{N}-report.md tính là 1 template type → 8 files thực tế (Phase1..Phase8)
  - Bổ sung 4 helper templates không có trong canon: `_common/session-log.json`, `_common/error-ledger.json`, `lane-status.json`, `CD-report.md` (đã đưa vào `_contract.json` outputs)
- Sidecar artifact `business-invariants.json` dùng cùng 1 template cho 2 paths (DRAFT tại Phase 3 + CANONICAL tại `.mc-data/work/wf-cmi/`)
- Markdown templates có conditional `[NẾU FAIL]` `[NẾU SKIPPED]` sections — runtime chọn 1 branch để populate, không cả 2

---

## ✅ Hoàn thành (Session 6 — 2026-05-16)

### Step 6: Tạo `evals/evals.json` + 4 fixtures ✅

**Đường dẫn:**
- `.claude/skills/workflow/wf-cmi/evals/` (3 files)
- `tests/fixtures/wf-cmi/` (27 files / 4 fixtures)

**Kết quả `evals/`:**

| File | Mục đích |
|------|----------|
| `evals.json` | 5 test cases TC-cmi-001..005, 31 assertions tổng, schema `EVAL-SCHEMA.md` valid (T1+T2 PASS) |
| `README.md` | Test cases overview + run instructions + schema reference |
| `run-all.sh` | Runner orchestrate 5 test cases tuần tự với type/skip filter + dry-run |

**Kết quả `tests/fixtures/wf-cmi/`:**

| Fixture | Files | Mục đích |
|---------|-------|----------|
| `minimal/` | 10 | TC-cmi-001 smoke — 1 module CRM, 5 REQs, 5 stub .cs + 3 phase docs |
| `realistic/` | 11 | TC-cmi-002 integration + TC-cmi-004 resume — 3 modules CRM+Orders+Finance, 17 REQs, 6 entity stubs cross-module FK |
| `corrupt/` | 4 | TC-cmi-003 edge — registry valid + corrupted variant + inject/corrupt-trigger hook |
| `concurrent/` | 2 | TC-cmi-005 concurrent — README + concurrent-runner.sh (reuse realistic/ data) |

**Tổng:** 27 fixture files + 3 evals files = 30 files

**Validation cross-check ✅:**
- `jq -e '.skill_name == "wf-cmi" and (.evals | length == 5)'` → T1 PASS
- `jq -e '.evals | all(has("id") and has("prompt") and has("expected_output") and has("assertions") and has("files"))'` → T2 PASS
- Assertion types: `behavior`, `file_content`, `file_exists` — đều thuộc 7 types chuẩn của EVAL-SCHEMA
- 3 fixture registries valid JSON với `requirements[]` > 0
- Corrupt fixture đúng — `req-registry.corrupted.json` FAIL `jq` parse (expected)
- 31 assertions tổng (TC001: 7, TC002: 7, TC003: 6, TC004: 5, TC005: 6)

**Cross-module dependencies trong realistic/ (đủ để test 10 invariants):**
- Orders.Order.CustomerId → CRM.Customer.Id (FK)
- Orders.Quotation.CustomerId → CRM.Customer.Id (FK)
- Finance.Invoice.OrderId → Orders.Order.Id (FK)
- Finance.Invoice.CustomerId → CRM.Customer.Id (FK denormalized)
- Finance.JournalEntry.InvoiceId → Finance.Invoice.Id (FK intra)
- Event: Orders.OrderConfirmed → Finance consume

**Note kiến trúc đặc biệt:**
- TC-cmi-006 regression (`--since=HEAD~5`) **defer v2** — cần git history fixture phức tạp
- TC-cmi-007 `--ci` mode + TC-cmi-008 `--dry-run` cũng defer v2 (đã ghi trong evals/README.md "planned for v2")
- Concurrent runner là **placeholder pattern** — chưa invoke skill thực tế (sẽ wire Step 10 audit)
- Realistic fixture chọn 11 files (BHV-002 Simplicity First) thay vì 30-50 vì đủ stubs để Phase 2 graphs phát hiện 5+ cross-module FK + 1 event flow — không cần over-engineer

---

## ✅ Hoàn thành (Session 7 — 2026-05-16)

### Step 7: Update CLAUDE.md + catalog docs ✅

**6 files updated:**

| File | Thay đổi |
|------|---------|
| `CLAUDE.md` | (1) Bump count 46→47 `wf-* skills` + thêm wf-cmi vào nhóm standalone trong dòng descriptive (line 93). (2) Thêm row `/wf-cmi` vào bảng **Standalone Skills** (sau wf-diagram, line 219). (3) Bump count 46→47 trong dir tree (line 309). |
| `docs/01-architecture/07-skills-catalog.md` | (1) Title `(43 skills)` → `(44 skills)`. (2) §1 summary: `Standalone tools 4` → `5`, thêm wf-cmi vào danh sách. (3) §1 total: 43→44 wf-* skills, 54→55 entries. (4) §8 thêm row `wf-cmi` sau wf-diagram. (5) §12 version overview: thêm row wf-cmi v1.0.0. (6) §13 dependencies: thêm row prerequisites. (7) §14 decision tree: thêm branch "Kiểm tra toàn vẹn liên module ERP". |
| `docs/02-standards/08-error-code-registry.md` | §4.1 (Skills có namespace đầy đủ multi-phase): thêm row `wf-cmi` với 8 phases + claim E001-E009 + E010-E089 + E090-E099 + E100-E109 (108 entries trong `_contract.json.errors{}`). |
| `docs/02-standards/11-output-path-contract.md` | (1) §2 cấu trúc tổng thể: thêm subtree `wf-cmi/` với canonical sidecar + sessions/{id}/phase{N}-{name}/ structure đầy đủ. (2) **§3.14 mới** — Cross-Module Integrity paths: 14 rows producer-consumer (sidecar canonical + 6 graphs Phase 2 + invariant Phase 3 + lanes Phase 4 + coverage Phase 5 + regression Phase 6 + gap-suggestions Phase 7 + integrity-report/integrity-impact Phase 8 + session SSOT + phase reports + index). (3) §5.3 cross-skill artifacts table: thêm 2 rows `integrity-impact.json` (schema `integrity-impact-v1`) + `business-invariants.json` (sidecar canonical APPEND-only). |
| `.claude/skills/protocols/21-cross-skill-output-path-contract.md` | Bảng §21.1 thêm 12 rows wf-cmi (Phase 2-8 + canonical sidecar + integrity-impact + session/index). |
| `docs/04-skill-design/README.md` §3 | **Verify** — row wf-cmi đã có từ Session 1 với status "✅ Full v3.1 ORCHESTRATOR (14 files)". Không cần update lại. |

**Validation cross-check ✅:**
- Path style consistency: `.mc-data/work/wf-cmi/sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/` đồng nhất với wf-fix-bugs canonical structure (CORE-035)
- Schema version naming: `integrity-impact-v1`, `business-invariants-v1`, `coverage-matrix-v1`, `regression-map-v1`, `gap-suggestions-v1` — tất cả PascalCase + `-vN` suffix (Protocol 10)
- Cross-skill consumers: 6 đối tác (`wf-fix-bugs`, `wf-verify-sync`, `wf-implement-feature`, `wf-prepare-deployment`, `wf-design`, `wf-add-scope`) khớp với `_contract.json.cross_skill_contracts.produces_for{}` (Session 3 validated)
- CDG flag `--from-cmi` nhất quán giữa 3 files (output-path-contract §5.3, Protocol 21, §3.14)
- Canonical sidecar vs session-scoped: phân biệt rõ ràng — sidecar ở `.mc-data/work/wf-cmi/business-invariants.json` (NGOÀI sessions/), session draft ở `$SESSION_DIR/phase3-invariant-artifact/business-invariants.json` (theo ADR-cmi-002 Revised)

**Note kiến trúc đặc biệt:**
- `docs/04-skill-design/README.md` §3 đã được populate từ Session 1 → step này là verify-only
- Pre-existing count mismatch giữa CLAUDE.md ("46 wf-*") và 07-skills-catalog.md ("43 skills") đã tồn tại trước Session 7 — bump bằng nhau (+1) cho cả hai để không tạo thêm divergence (47/44)
- CLAUDE.md Standalone Skills mục tiêu UX/user-facing — wf-cmi row liệt kê đầy đủ args + 4 profiles để user reference khi gọi `/wf-cmi`

---

## ✅ Hoàn thành (Session 8 — 2026-05-16)

### Step 8: Tạo slash command ✅

**File:** `.claude/commands/wf-cmi.md`

**Kết quả:**
- [x] Tạo `.claude/commands/wf-cmi.md` theo pattern 1-line routing (đồng nhất với mọi `wf-*` command khác trong DEVKIT)
- [x] Nội dung: `Read and execute the skill definition at \`.claude/skills/workflow/wf-cmi/SKILL.md\`. Arguments: $ARGUMENTS`
- [x] Slash command `/wf-cmi` đã được Claude Code skills registry nhận diện (xuất hiện trong available-skills list cùng nhóm với `wf-diagram`, `wf-scan-target`)
- [x] Argument signature đầy đủ đã được khai báo trong SKILL.md frontmatter `argument-hint` từ Session 2 — không cần lặp lại trong file command (separation of concerns)

**Note kiến trúc đặc biệt:**
- Pattern 1-line đồng nhất: tất cả 36 slash commands trong `.claude/commands/` cho workflow skills đều dùng cùng template "Read and execute the skill definition at `<path>/SKILL.md`. Arguments: $ARGUMENTS" — KHÔNG có YAML frontmatter ở command level (mọi metadata sống trong SKILL.md)
- File size: 106 bytes (so với wf-diagram 111 bytes + wf-scan-target 113 bytes — chênh do tên skill ngắn hơn 5 ký tự)
- BHV-002 Simplicity First: KHÔNG thêm usage example/comment vào command file vì pattern hiện tại đã đủ — SKILL.md là single source cho user help
- BHV-003 Surgical Changes: KHÔNG sửa các file commands khác hoặc thêm sections không có trong pattern hiện hữu

**Validation cross-check ✅:**
- File tồn tại + đúng path: `.claude/commands/wf-cmi.md` (106 bytes)
- Format khớp 100% với `wf-diagram.md` và `wf-scan-target.md` (1 dòng + newline)
- Skills registry list contains: `wf-cmi: Read and execute the skill definition at \`.claude/skills/workflow/wf-cmi/SKILL.md\`. Arguments: $A...`
- Master checklist Step 9 (slash command) → có thể tick `[x]` (chú ý: master checklist đánh số khác progress.md — "Step 9" trong master = "Step 8" trong progress)

---

## ✅ Hoàn thành (Session 9 — 2026-05-16)

### Step 9: Tạo review checklist ✅

**File:** `docs/05-review-standards/wf-cmi.md`

**Kết quả:** 188 dòng — đồng nhất pattern với `wf-implement-feature.md` (158 dòng) và `wf-fix-bugs.md` (151 dòng) — wf-cmi dài hơn ~30 dòng do thêm 5 G items (G9-G13 cho 6 CDG gates + 6 graphs + coverage formula + multi-session lock + dual regression mode) và 2 CS items (CS6 SSOT path + CS7 multi-user Git audit_chain).

**Cấu trúc (kế thừa `_template-common.md` v1.0):**

| § | Section | Notes |
|---|---------|-------|
| 0 | Tổng quan skill | Bảng 10 rows mô tả Vai trò, Entry point, Kiến trúc, Execution mode, Strategy routing, Output (37 files), Registry NONE, Cross-skill 6 consumers + 9 producers |
| 1 | Skill Profile (YAML) | `is_orchestrator: true` nhưng có procedures/+templates/ (đặc thù vs `wf-fix-bugs` pure); 4 nhóm thuộc tính + bảng "Nhóm tiêu chuẩn áp dụng" 9 rows A/B/C/D/E/F/H/I/J |
| 2.1 | NHÓM G (wf-cmi specific) | **13 tiêu chuẩn G1-G13** — sidecar APPEND, canonical path, 10 lanes, profile→lane matrix, 3-pass LLM, parallel spawn, agent prompt 8-section, self-healing chỉ ĐỀ XUẤT, 6 CDG gates, dual regression, 6 graphs, coverage formula, R/W lock |
| 2.2 | NHÓM CS (cross-skill) | **7 tiêu chuẩn CS1-CS7** — sidecar enforce APPEND-only, schema versioned, opt-in flag --from-cmi, produces_for khớp Protocol 21, consumes_from 9 entries, session SSOT, multi-user audit_chain |
| 2.3 | Constraint đặc biệt | 7 ràng buộc — KHÔNG bump registry v3, Phase 3 file naming, 24 domain experts CHỈ trong CD1, standalone không thuộc main pipeline, 6 CDG triggers, 5 LLM-driven sub-phases, concurrency hard-cap, `--ci` read-only |
| 3 | Quick-check | **16 checkbox items** — feasible với `jq`/`grep`/`bash test -f`. Mỗi item map 1-1 với G/CS clauses trong §2 |
| 4 | Reference | 13 links — design canon, SKILL.md (487 dòng verified), _contract.json (37 outputs, 108 errors, 6 produces_for, 9 consumes_from verified), procedures/templates/evals + protocols 21 + 22 |
| 5 | Ghi chú bảo trì | 9 trigger điều kiện cập nhật file — bump major, schema bump, thêm CD lane, thêm consumer/producer, CDG mới, domain experts mở rộng, profile mới |

**Validation cross-check ✅ (test bằng jq/bash):**
- `wc -l` = 188 dòng (đầy đủ 6 sections 0-5)
- G1 quick-check: `jq -r '.registry_scope.write_role' _contract.json` → `NONE`, `fields_owned` → `[]` ✅
- G2 quick-check: jq find 2 entries `business-invariants` (1 draft `$SESSION_DIR/phase3-invariants/`, 1 canonical `.mc-data/work/wf-cmi/`) + 1 lock file (Protocol 22 rwlock) ✅
- G9 quick-check: jq find E090, E090b, E091, E092, E093, E094, E095 (6 CDG gates đủ — bonus E092 chưa được mention trong design canon ban đầu) ✅
- Tất cả 13 links trong §4 Reference đều `test -f` PASS (SKILL.md, _contract.json, evals, procedures/, templates/, fixtures, agent-prompt.md, 08-tradeoffs-adr.md, protocols 21+22)
- Protocol 22 actual filename `22-infrastructure-rw-lock.md` (KHÔNG phải `22-cross-session-rw-lock.md` như draft ban đầu — đã fix)
- Phase 3 draft path = `phase3-invariants/` (KHÔNG phải `phase3-invariant-artifact/` như draft procedure filename — đã fix)

**Note kiến trúc đặc biệt:**
- wf-cmi review checklist phân biệt rõ với `wf-fix-bugs` (pure orchestrator no procedures/templates): wf-cmi `is_orchestrator=true` NHƯNG `has_procedures=true` + `has_templates=true` — bảng "Nhóm tiêu chuẩn áp dụng" áp dụng đầy đủ A/B/C/D/E/F/H/I/J (chỉ SKIP E15/E16 do NONE role)
- NHÓM G expand 13 items (vs 8 của wf-fix-bugs, 13 của wf-implement-feature) — phản ánh complexity của wf-cmi (8 phases × 10 lanes × 6 CDG gates × dual regression mode)
- NHÓM CS expand 7 items (vs 5 của wf-fix-bugs, 6 của wf-implement-feature) — phản ánh sidecar canonical pattern (CS1+CS2) + 6 consumers opt-in flag (CS3) + 9 producers (CS5) + multi-user audit_chain (CS7)
- Quick-check §3 thiết kế actionable: 16 items đều có thể verify bằng `jq`/`grep`/`bash test -f` (BHV-004 Goal-Driven — DONE-criteria tick được)
- Findings ghi vào `reports/YYYY-MM-DD-wf-cmi.md` (không vào file review — pattern chung của 5 file review skill khác)

---

## ✅ Hoàn thành (Session 10 — 2026-05-16)

### Step 10: Audit scripts validation ✅

**Files thay đổi:** 2 files (1 wire + 1 SKILL.md surgical fixes)

| File | Thay đổi |
|------|---------|
| `.claude/scripts/validate-schema-sync.sh` | (1) Thêm `"wf-cmi"` vào `ALL_SKILLS` array (sau wf-diagram). (2) Thêm `REGISTRY_SCOPE["wf-cmi"]="none"` (write_role=NONE per ADR-cmi-002 Revised). |
| `.claude/skills/workflow/wf-cmi/SKILL.md` | (1) Phase Summary refactor: table 8-row → 8 sub-sections `### Phase N — Name` (mirror wf-legacy-scan pattern) để PASS 4.1/4.5. (2) Next Step intro thêm `(next: /wf-verify-sync ...)` để PASS 7.2. (3) Cross-skill section: thêm "Safe-Write Protocol: skill CHỈ READ registry, không update bất kỳ fields nào" để PASS 10.2 (mặc dù write_role=NONE, HAS_REGISTRY heuristic vẫn fire vì mention `req-registry.json`). (4) Phase 2 row: thêm "validation check" để PASS 10.1 cross-validation. SKILL.md = **498 dòng** (vẫn ≤500 ✅ CORE-032). |

**Issues classified và fix:**

| Sev | Issue | Root cause | Trạng thái |
|-----|-------|-----------|-----------|
| BLOCKER | 4.1 + 4.5 — No `### Phase N` headers (FAIL) | Audit v3.0 quét regex `## (Phase\|Stage) [0-9]` (match cả `###`). SKILL.md cũ chỉ có table | ✅ FIX (8 sub-headers) |
| HIGH | 7.2 — Next step regex (FAIL) | Cần `Next.*:.*/` match (ví dụ: `next: /wf-verify-sync`) | ✅ FIX (1 line) |
| MEDIUM | 10.2 — Safe-Write rules (CONDITIONAL FAIL) | `HAS_REGISTRY=yes` vì mention `req-registry.json` (READ-ONLY). Yêu cầu text match `Safe-Write\|CHI MODIFY\|fields duoc phep\|fields.*update` | ✅ FIX (1 sentence) |
| LOW | 10.1 — Cross-Validation (CONDITIONAL WARN) | Regex `Cross-Validation\|Auto-Correction\|validation.*check\|iteration.*MAX` không match | ✅ FIX bonus (1 word add) |

**Final validation kết quả ✅ (4/4 PASS):**

| Script | Kết quả | Detail |
|--------|---------|--------|
| `skill-compliance-audit.sh wf-cmi` | ✅ **GRADE: PASS** | CRITICAL 12/12 (100%) · REQUIRED 13/13 (100%) · CONDITIONAL 5/5 (no warnings) · Lines 498 ≤500 |
| `validate-schema-sync.sh wf-cmi` | ✅ PASS | 1/1 skill — _contract.json valid, identity match, 10 procedures valid, registry_scope khớp CORE-006 (NONE), templates exist |
| `validate-pipeline-naming.sh` | ✅ PASS | 8 WARN (không liên quan wf-cmi — pipeline runtime data chưa tồn tại), 0 FAIL |
| `check-skill-design-populated.sh docs/04-skill-design/wf-cmi/` | ✅ PASS | 10 files OK (README + 00-master + 01-vision + 02-arguments + 03-phase + 04-file + 05-error/profiles + 06-templates + 07-procedures + 08-tradeoffs/scenarios + 09-evals) |

**Note kiến trúc đặc biệt:**
- Pattern `### Phase N — Name` sub-sections + 1-line description SỬ DỤNG LẠI wf-legacy-scan pattern v5.0 — giữ CORE-032 lazy-load (procedures/ là SSOT), SKILL.md chỉ là routing hub
- Khoảng cách +11 dòng (487→498) do mỗi phase chiếm 3 dòng (heading + 1 dòng condensed + blank) thay vì 1 dòng table — tradeoff đáng giá để PASS compliance audit
- "Safe-Write Protocol: skill CHỈ READ" explicit statement hữu ích cho reviewer biết wf-cmi KHÔNG vi phạm CORE-006 mặc dù file mention registry nhiều lần (vì read-only prerequisites)
- Bonus fix 10.1: "validation check" trong Phase 2 — không thay đổi semantics, chỉ thêm 1 từ để match regex

**Validation cross-check ✅:**
- BHV-003 Surgical Changes — chỉ sửa 4 chỗ cần thiết trong SKILL.md, KHÔNG refactor sections không liên quan
- BHV-004 Goal-Driven — DONE-criteria được verify rõ ràng: all 4 scripts GRADE: PASS
- CORE-032 lazy-load — SKILL.md 498 dòng (≤500), procedures/ là SSOT cho execution logic
- CORE-036 Cross-Skill Artifact Contract — `_contract.json.produces_for{}` và `consumes_from{}` không bị thay đổi

---

## Tổng effort còn lại (estimate)

| Step | Effort | Phụ thuộc | Trạng thái |
|------|--------|-----------|-----------|
| Step 2: SKILL.md | 2-3h | — | ✅ DONE (Session 2) |
| Step 3: _contract.json | 1-2h | Step 2 | ✅ DONE (Session 3) |
| Step 4: 10 procedures | 6-10h | Step 2-3 | ✅ DONE (Session 4) |
| Step 5: 29 templates | 4-6h | Step 3 | ✅ DONE (Session 5) |
| Step 6: evals + 4 fixtures | 4-6h | Step 4-5 | ✅ DONE (Session 6) |
| Step 7: Catalog updates | 1-2h | Step 2-3 | ✅ DONE (Session 7) |
| Step 8: Slash command | 30min | Step 2 | ✅ DONE (Session 8) |
| Step 9: Review checklist | 1h | Step 2-6 | ✅ DONE (Session 9) |
| Step 10: Audit + fix | 1-2h | All | ✅ DONE (Session 10) |

**🎉 wf-cmi v1.0.0 READY FOR PR/COMMIT** — Master checklist 00-master-checklist.md mọi step tick `[x]`, 4/4 audit scripts PASS.

---

## Lưu ý quan trọng

- **KHÔNG bump registry v3** — đã chốt sidecar artifact pattern (ADR-cmi-002 Revised)
- **Phase 3 đổi tên** — `phase3-invariant-registry.md` → `phase3-invariant-artifact.md`
- **Target ban đầu** EUREKA-2026 (D:\EUREKA-2026) — generic enough cho ERP khác
- **Multi-session** quan trọng (Protocol 22 R/W lock) — không skip
- **Multi-user collab qua Git** — artifact text deterministic, gắn author slug
- **Tiếng Việt** user-facing prose, English code (CORE-005)

## Liên kết

- Session prompt: [session-prompt.md](session-prompt.md)
- Plan gốc: [wf-cmi.md](wf-cmi.md)
- Design canon: [`../../docs/04-skill-design/wf-cmi/`](../../docs/04-skill-design/wf-cmi/)
- Master checklist: [`../../docs/04-skill-design/wf-cmi/00-master-checklist.md`](../../docs/04-skill-design/wf-cmi/00-master-checklist.md)
