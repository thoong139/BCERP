# Progress Update — wf-cmi v2.0 (Gói C++ Logistics — 26 lanes)

> **Mục đích:** Track triển khai mở rộng wf-cmi từ v1.0.0 (10 lanes CD1-CD10) → v2.0.0 (26 lanes Gói C++). Update file này mỗi khi hoàn thành milestone.
>
> **Khác với `progress.md`:** File đó track v1.0.0 implementation đã hoàn thành. File này track v2.0.0 expansion (NEW).

**Cập nhật lần cuối:** 2026-05-16 — ✅ **STAGE 8 + STAGE 9 DONE** (Tests + Ship docs hoàn tất, KHÔNG commit/PR per user decision). Stage 8: 8 eval test cases mới TC-cmi-006 → TC-cmi-013 (13 tổng) cover Wave dispatch subset + SSOT mandatory ESCALATE + full 26-lane deep + logistics-critical ★★★ + compliance + NEW additions + integrity-impact v2 backward-compat + status query; evals/README.md update v1+v2 tables; audit gates 3/3 PASS (skill-compliance GRADE PASS 12+13+5 / validate-schema-sync 1/1 / check-skill-design-populated PASS 11 files); 3 profile smoke test PASS (quick 7 lanes Wave1-only + standard 14 lanes 3-wave subset + deep 26 lanes full 3-wave) via wave-coordinator.sh dry-run; performance test methodology documented trong v2-migration-notes.md §5.1 CI timeout adjustment. Stage 9: CHANGELOG.md wf-cmi v2.0.0 entry (>200 dòng); CLAUDE.md wf-cmi entry v1.0 → v2.0; docs/01-architecture/07-skills-catalog.md row + v2.0 quick reference; docs/04-skill-design/wf-cmi/05-execution-profiles.md refresh 26 lanes deep + NEW §11 Wave Dispatch Strategy; NEW docs/06-user-guides/per-skill/wf-cmi-v2-guide.md (~360 dòng end-user guide 15 sections + FAQ); NEW docs/04-skill-design/wf-cmi/v2-migration-notes.md (~280 dòng migration guide 10 sections). Còn lại: EUREKA real dry-run + Stage 4 integration tests (pending stakeholder populate 7 mandatory SSOTs) + commit/PR (deferred per user decision). ✅ **STAGE 7 DONE** (Reports: integrity-report.md v2 template top 10 violations severity-weighted placeholder [TOP_VIOLATIONS_LIST] thay 3 hardcoded slots + ≤55 max bound (10 violations expansion); integrity-impact.json schema v1→v2 với 5 v2 fields mới (lanes_v2.active/skipped/skeleton, wave_breakdown.wave_1/2/3, group_breakdown 7 sections core/frontend/backend/ux/logistics★★★/compliance★★★/implementation★, logistics_critical_signals_count CD28/30/31/37/38/39/40, schema_version_compat readable_by v1+v2) GIỮ NGUYÊN all v1 fields backward-compat consumer fallback; phase8-report.md Step 8.3 rewrite per-group computation + wave summary từ wave-status.json + top 10 severity-weighted MUST=4/HIGH=3/MEDIUM=2/LOW=1, Step 8.4 rewrite v2 schema populate đầy đủ 8 sections (coverage/violations/lanes_v2/wave/group/logistics_critical/schema_compat/regression/gap/consumers/summary/audit), POST-GATE T2 v2 required fields check + T3 ≤55 + 0 leftover placeholders + E084 message update; _contract.json outputs notes ≤55 + cross_skill_contracts.produces_for 4 consumers v1→v2 references + NEW produces_for_schema_compat section định nghĩa backward-compat contract. **5/5 gates PASS** — compliance audit 12+13+5 + schema sync 1/1 + smoke test max bound 52 dòng ≤55 + 0 leftover placeholders + backward-compat verify v1 fields preserved + SKILL.md 487 dòng ≤500 CORE-032). ✅ **STAGE 6 DONE** (Aggregator: phase5-aggregate.md v2 logic + coverage-matrix v2 schema 35 dims + 9 SKIPPED markers + threshold v2 quick60/std80/deep95/exhaust100 + CDG E090 + E005 early exit + wave_breakdown 3 entries; coverage-report.md/Phase5-report.md template ↔ procedure sync 100% — 0 leftover placeholders smoke test; 5/5 gates PASS — compliance audit 12+13+5 + schema sync 1/1 + smoke test). ✅ **STAGE 5 DONE** (Dispatcher refinement: wave-coordinator.sh 5 subcommands + wave-status-v1 template + 11/11 smoke scenarios PASS + 8/8 audit gates PASS). 🎯 **STAGE 4 ĐÓNG HOÀN TOÀN 18/18 lanes** sau sub-stage 4.5 LANE PROCEDURE FILES DONE 2/2 (CD29 Audit Trail Completeness 398 dòng + CD37 Regulatory Compliance ★★★ 435 dòng, tổng 833 dòng, agent-prompt.md §29-30 NEW + renumber §29-32 → §31-34, _contract.json bump `.procedure[]` 26→28, 5/5 gates PASS). Stage 1 HOÀN THÀNH 7/7 gates, Stage 3 HOÀN THÀNH 8/8 SSOT templates, Stage 2 HOÀN TOÀN CLOSE 7/7 graphs (FE plugin set + BE plugin set EUREKA: 1249 tables + 3260 CQRS records, 8/8 gates PASS), Stage 4 sub-stage 4.6 LANE PROCEDURE FILES DONE 3/3 (CD38/CD39/CD40, 1260 dòng), Stage 4 sub-stage 4.4 LANE PROCEDURE FILES DONE 3/3 (CD28/CD30/CD31, 1204 dòng), Stage 4 sub-stage 4.1 LANE PROCEDURE FILES DONE 4/4 (CD11/CD13/CD15/CD18, 1462 dòng), Stage 4 sub-stage 4.2 LANE PROCEDURE FILES DONE 2/2 (CD16/CD17 BE deep lanes), Stage 4 sub-stage 4.3 LANE PROCEDURE FILES DONE 4/4 (CD23/CD24/CD25/CD26 UX lanes, 1625 dòng). **NEW Stage 4 sub-stage 4.3 LANE PROCEDURE FILES DONE 4/4 — CD23.md (387 dòng UX Design System, SSOT ux-conventions mandatory, 5 kinds UXDS-CD23-001..005 với COLOR_HARDCODED severity MUST brand-guardian gate) + CD24.md (388 dòng UX Display Format, SSOT ux-conventions mandatory, 5 kinds UXFMT-CD24-001..005 với VND_DECIMAL_PRESENT severity HIGH TT 78/2021/TT-BTC compliance gate) + CD25.md (413 dòng UX Flow Continuity, SSOT ux-conventions mandatory, 5 kinds UXFLOW-CD25-001..005 với BROKEN_USER_JOURNEY + MISSING_CONFIRMATION_DIALOG severity MUST safety gate) + CD26.md (437 dòng UX Workflow Visibility ★★★ logistics-aware, SSOT workflow-state-machines mandatory + ux-conventions secondary, 3 graphs fe-component/fe-route/be-domain, 5 kinds UXWFV-CD26-001..005 với PROGRESS_HIDDEN logistics-critical HIGH cho Booking/CustomsDeclaration/Invoice). Design canon agent-prompt.md §25-28 mới (+458 dòng, total 2233) + renumber §25-28 cũ → §29-32 (Triage/Spawn/Anti-patterns/Refs). **_contract.json bump `.procedure[]` 22→26 (16/26 lanes có procedure_file) + 4 lanes refined với procedure_file/expected_signal_kinds_5/graph_dependencies/ssot_dependency/stage_4_status. phase4-coverage-dispatch.md update Wave 2+3 signal kinds CD23-26 + spawn callout mapping (CD23→§25, CD24→§26, CD25→§27, CD26→§28) + lane procedure status table CD23-26 → ✅. 5/5 gates PASS sub-stage 4.3** (compliance audit GRADE PASS 12+13+5, schema sync 1/1 PASS, SKILL.md vẫn 487 dòng ≤500 CORE-032, JSON valid, 26 procedure paths verified on disk). Còn lại: sub-stage 4.5 (CD29 + CD37 compliance, ~8 ngày) + integration test sub-stages 4.1/4.3/4.4/4.6 với EUREKA real fixtures + Stage 5-9 (Dispatcher/Aggregator/Reports/Tests/Ship).

---

## 0. Gating Decisions (Chốt 2026-05-16, sau session prompt-update)

| # | Câu hỏi                      | Quyết định                                         | Implication                                                                                                                                                            |
| - | ------------------------------ | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | Profile naming cho 26 lanes    | **Option A — expand `deep` thành 26 lanes** | Breaking change.`--profile=deep` từ 10→26 lanes (~60→90 min). Cần migration notes rõ ràng + WARN khi resume v1 session.                                        |
| 2 | EUREKA mobile apps scope ở v2 | **Chỉ scan `erp-web`**                       | mobile-customer + mobile-staff + web-customer + smarttax-web defer v2.1. Tiết kiệm 30-40% effort Stage 2-4. fe-route-graph + fe-component-graph 1 client thay vì 5. |
| 3 | CD32-CD36 vertical lanes       | **Option B — Merge wf-cmi v3 (36+ lanes)** | v2.0 ship 26 lanes active + thêm 5 **skeleton entries** cho CD32-CD36 trong `_contract.json.lanes_defined[]` với `status: "skeleton-v3-deferred"`. KHÔNG activate trong v2.0 (KHÔNG có procedure file, KHÔNG có template, KHÔNG dispatch). v3.0 sẽ activate qua Wave 4 v3 + procedure design. Rủi ro đã chấp nhận: SKILL.md có thể vi phạm ≤500 dòng ở v3 — cần restructure (vd extract lane table sang `procedures/_lane-catalog.md`) khi tới v3. |
| 4 | Timeline expectation           | **Flexible — quality first**                   | 9 tuần là estimate, không hard deadline. Tuân thủ CORE-023 (Priority Order) — không cut corners.                                                                |

**Agent inventory verify (đã check):** Tất cả 19 agents cho v2 đã sẵn sàng:

- business 5: `business-analyst`, `compliance-expert`, `finance-expert`, `legal-expert`, `logistics-expert`
- design 5: `brand-guardian`, `ui-designer`, `ux-architect`, `ux-designer`, `ux-researcher`
- engineering 8: `architect`, `data-engineer`, `dba`, `developer`, `frontend-developer`, `security`, `sre`, `tech-writer`
- testing 1: `qa-lead`

---

## 1. Quyết Định Scope (Đã Chốt 2026-05-16)

### Gói C++ Logistics — 26 lanes

Sau 8 round design discussion với user, scope cuối cùng:

```
GÓI C BASE (23 lanes):
├── Core 8:        CD1, CD2, CD3, CD4, CD5, CD6, CD7, CD9
├── Frontend 3:    CD11, CD13, CD15
├── Backend 3:     CD16, CD17, CD18
├── UX 4:          CD23, CD24, CD25, CD26
├── Logistics 3:   CD28, CD30, CD31
└── Compliance 2:  CD29, CD37

ADDITIONS (3 lanes):
├── CD38 UI Implementation Coverage   ★ NEW
├── CD39 Error UX & Recovery          ★ NEW
└── CD40 Print & Export Consistency   ★ NEW

TỔNG: 26 lanes
```

### Đã thống nhất BỎ

| Lane                                   | Lý do                                            | Khi nào re-enable                |
| -------------------------------------- | ------------------------------------------------- | --------------------------------- |
| **CD8** Observability (full)     | User không cần performance                      | Pre-production go-live            |
| **CD10** Documentation           | Đắt, không critical hàng ngày                | Pre-release                       |
| **CD12** FE State Integrity      | Deep profile only                                 | Khi cần FE state debugging       |
| **CD14** FE i18n Coverage        | Deep profile only                                 | Khi mở rộng multi-language deep |
| **CD19** Distributed Transaction | Defer (cần SRE expertise)                        | Production hardening              |
| **CD20** Security Deep           | User không cần security                         | Public API / external user        |
| **CD21** Reliability             | Deep profile only                                 | Monitoring readiness              |
| **CD22** Config & Secret         | Defer (chỉ có CD22 trim trong v2.1)             | Production go-live                |
| **CD27** UX Microcopy            | Deep profile only                                 | Khi UX matures                    |
| **CD32-CD36** Vertical sâu      | **Option B**: skeleton trong v2.0, activate v3.0 | wf-cmi v3.0 (Wave 4 v3)         |
| **CD42** Carrier Integration     | Defer v2.1 (logistics-critical nhưng effort cao) | Sau khi tích hợp >5 carriers    |

### Cập nhật Profile Activation

| Profile              | v1.0 (cũ)          | v2.0 (mới — Gói C++ default)                                                                                               | Số lanes                   |
| -------------------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| **quick**      | CD1-CD4, CD7 (5)    | CD1-CD4, CD7, CD16, CD17                                                                                                      | 7                           |
| **standard**   | + CD5, CD6, CD9 (8) | + CD5, CD6, CD9, CD11, CD13, CD18                                                                                             | 13                          |
| **deep**       | + CD8, CD10 (10)    | + CD8\*, CD10\*, CD12\*, CD14\*, CD15, CD22\*, CD23, CD24, CD25, CD26, CD27\*, CD28, CD29, CD30, CD31, CD37, CD38, CD39, CD40 | 26 (\* = deferred/optional) |
| **exhaustive** | All 10 + LLM        | All 26 + LLM enhance + deferred lanes                                                                                         | 30+                         |

→ **Profile mới gọi là `c-plus-plus-logistics` hoặc giữ `deep` rename.**

---

## 2. Breakdown 16 Lanes Mới (Cần Build)

| #  | Lane                                             | Owner Agents                                                      | Complexity | Effort (days) |
| -- | ------------------------------------------------ | ----------------------------------------------------------------- | ---------- | ------------- |
| 1  | **CD11** FE Component Contracts            | `frontend-developer`                                            | Trung      | 2             |
| 2  | **CD13** FE↔BE Contract Sync              | `architect` + `frontend-developer`                            | Trung      | 3             |
| 3  | **CD15** UI Permission Mirror              | `frontend-developer` + `security`                             | Trung      | 2             |
| 4  | **CD16** Domain Logic Integrity            | `architect` + `business-analyst`                              | Cao        | 4             |
| 5  | **CD17** Persistence Consistency           | `dba` + `data-engineer`                                       | Cao        | 4             |
| 6  | **CD18** CQRS Pipeline Integrity           | `architect` + `developer`                                     | Trung      | 3             |
| 7  | **CD23** UX Design System Consistency      | `ui-designer` + `brand-guardian`                              | Trung      | 2             |
| 8  | **CD24** UX Display Format Consistency     | `ux-designer` + `frontend-developer`                          | Thấp      | 2             |
| 9  | **CD25** UX Flow Continuity                | `ux-researcher` + `frontend-developer`                        | Cao        | 3             |
| 10 | **CD26** UX Workflow Visibility            | `ux-designer` + `business-analyst` + `logistics-expert`     | Cao        | 4             |
| 11 | **CD28** MDM Consistency ★★★            | `data-engineer` + `dba` + `logistics-expert`                | Cao        | 5             |
| 12 | **CD29** Audit Trail Completeness          | `data-engineer` + `compliance-expert`                         | Cao        | 3             |
| 13 | **CD30** Time & Numbering Integrity ★★★ | `architect` + `dba` + `logistics-expert`                    | Cao        | 4             |
| 14 | **CD31** Money & Tax Integrity ★★★      | `finance-expert` + `dba` + `architect`                      | Cao        | 4             |
| 15 | **CD37** Regulatory Compliance ★★★      | `compliance-expert` + `legal-expert` + `dba`                | Cao        | 5             |
| 16 | **CD38** UI Implementation Coverage ★     | `ux-researcher` + `frontend-developer` + `business-analyst` | Trung      | 3             |
| 17 | **CD39** Error UX & Recovery ★            | `ux-designer` + `frontend-developer`                          | Trung      | 3             |
| 18 | **CD40** Print & Export Consistency ★     | `ui-designer` + `frontend-developer` + `tech-writer`        | Trung      | 4             |

**Tổng effort lane build:** ~60 ngày (parallel team có thể ship 8-10 tuần).

---

## 3. Graphs Mới Cần Build Trong Phase 2 (7 graphs)

| Graph                        | Cho lane(s) | Effort (days) | Source detect                                                                |
| ---------------------------- | ----------- | ------------- | ---------------------------------------------------------------------------- |
| `fe-component-graph.json`  | CD11        | 2             | Glob `apps/erp-web/components/**/*.tsx` + AST props parse                  |
| `fe-api-client-graph.json` | CD13, CD38  | 3             | Grep `useQuery\|useMutation\|fetch\|axios` + Refit clients                    |
| `fe-permission-graph.json` | CD15, CD38  | 2             | Grep `<PermissionGate>\|usePermission\|<Can>` + AST                          |
| `fe-route-graph.json`      | CD25, CD38  | 2             | Glob `app/**/page.tsx,layout.tsx,middleware.ts` + parse                    |
| `be-db-schema-graph.json`  | CD17        | 3             | Parse EF Migrations + reverse-engineer DB schema                             |
| `be-domain-graph.json`     | CD16        | 4             | Serena `find_symbol` + Grep `: AggregateRoot\|: ValueObject\|IDomainEvent` |
| `be-cqrs-graph.json`       | CD18        | 3             | Grep `IRequest<\|IRequestHandler<\|IValidator<\|IPipelineBehavior<`           |

**Tổng effort graph build:** ~19 ngày.

---

## 4. SSOT Files Mới Cần Define (9 files)

| File                                        | Cho lane(s)                  | Người define                             | Status                                                                                |
| ------------------------------------------- | ---------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| `ux-conventions.json`                     | CD23, CD24, CD25, CD26, CD27 | `ux-designer` + `brand-guardian`       | ⚠ Cần tạo                                                                          |
| `mdm-canonical-entities.json`             | CD28                         | `data-engineer` + `business-analyst`   | ⚠ Cần tạo                                                                          |
| `compliance-mapping.json`                 | CD37                         | `compliance-expert` + `legal-expert`   | ⚠ Cần tạo                                                                          |
| `rbac-permission-catalog.json`            | CD15, CD38                   | `security` + `architect`               | ⚠ Cần tạo                                                                          |
| `workflow-state-machines.json`            | CD3, CD26, CD38              | `business-analyst` + `architect`       | ⚠ Cần tạo                                                                          |
| `audit-critical-entities.json`            | CD29                         | `data-engineer` + `compliance-expert`  | ⚠ Cần tạo                                                                          |
| **`ui-interactivity-spec.json`** ★ | CD38                         | `ux-researcher` + `frontend-developer` | ✅**Template tại `plans/wf-cmi/ui-interactivity-spec.eureka-template.json`** |
| `error-code-catalog.json`                 | CD39                         | `architect` + `tech-writer`            | ⚠ Cần tạo                                                                          |
| `print-export-templates.json`             | CD40                         | `ui-designer` + `tech-writer`          | ⚠ Cần tạo                                                                          |

→ Template `ui-interactivity-spec.eureka-template.json` đã được tạo trước (xem file riêng).

---

## 5. Stage-Based Rollout Plan (9 Stages)

### Stage 1: Foundation Refactor (Tuần 1) — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** Update infrastructure để support 26 lanes thay vì 10.

- [x] Update `_contract.json` — bump 1.0.0→2.0.0, `lanes_defined[]` 40 entries (26 active + 9 SKIPPED + 5 skeleton v3-deferred), `profile_activation{}` (quick=7/standard=13/deep=26/exhaustive=35), 3 schema bumps v1→v2, `migration_notes`, errors E110-E149. **526 dòng, JSON valid.**
- [x] Update SKILL.md — bump v1.0→v2.0, expand lane catalog 10→26 active grouped, migration notes, mobile scope (erp-web only), errors E110-E149 quick lookup. **487 dòng (≤500 CORE-032 ✓).**
- [x] Update `templates/integrity-status.json` — schema v1→v2, thêm `lanes_active_v2[]` + `wave_status{}` + `current_wave` + `migration_check{}`.
- [x] Update `templates/coverage-matrix.json` — schema v1→v2, 35 dim entries (26 PENDING + 9 SKIPPED markers, CD32-CD36 KHÔNG present), thêm `group`/`wave`/`owner_agents` per dim + `wave_breakdown{}`.
- [x] Update `templates/integrity-report.md` — layout 26-dim grouped 7 sections + Wave dispatch summary. **46 dòng content (≤50 relaxed v2 ✓).**
- [x] Update `procedures/phase4-coverage-dispatch.md` — 3-WAVE strategy (W1=10/W2=10/W3=6), LANE_AGENT_MAP 26 + LANE_WAVE_MAP + LANE_NAME_MAP, per-wave gate check (≥3 fail → STOP E120-E122), spawn pattern wave-aware.
- [x] Update `procedures/phase5-aggregate.md` — aggregation 35 dims, expand `get_dim_name`/`get_dim_name_slug`/`get_dim_group`/`get_dim_wave`/`compute_universe_size` cho 35 cases, wave_breakdown compute, POST-GATE T2 check =35 + CD32-36 KHÔNG present.

**Gate Status (7/7 PASS — 2026-05-16):**
- ✅ GATE 1: 3 JSON files valid (jq parse)
- ✅ GATE 2: SKILL.md 487 dòng ≤500 (CORE-032)
- ✅ GATE 3: lanes_defined count = 40
- ✅ GATE 4: profile_activation.deep.lanes_active = 26
- ✅ GATE 5: coverage-matrix 35 dims, CD32-CD36 NOT present
- ✅ GATE 6: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 7: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS

**Next Stage:** Stage 2 (7 graph builders) + Stage 3 (9 SSOT files) song song bắt đầu Tuần 2. Khuyến nghị start ngay Stage 3 (cần stakeholder input cho EUREKA).

---

### Stage 2: Build Phase 2 Graph Builders (Tuần 2-3) — Effort ~19 ngày

**Mục đích:** Build 7 graph mới trong Phase 2 (parallel).

#### Stage 2 Vertical Slice — ✅ HOÀN THÀNH 2026-05-16 (proof-of-pattern, 1/7 graphs)

**Mục đích:** Validate pattern với 1 graph end-to-end trước khi scale 6 graphs còn lại.

- [X] **`fe-component-graph.json`** — Discovery Plugin #7 (CD11 dependency)
  - [X] Template `templates/fe-component-graph.json` (schema `fe-component-graph-v1` + `_template_notes`)
  - [X] Builder script `.claude/scripts/wf-cmi/build-fe-component-graph.sh` (Grep-based parser v1.0, smoke-tested)
  - [X] Update `procedures/phase2-discovery.md` Step 2.8b + POST-GATE plugin handling
  - [X] Update `_contract.json` outputs.working[] (+1 entry, total 39) + errors E137/E138/E139 + internal_phases.phase2
  - [X] Update `templates/Phase2-report.md` — thêm dòng FE Component count + status
  - [X] Smoke test: skip path scenario + real .tsx fixture (2 components, 2 imports parsed)

**Gate Status (Vertical Slice, 6/6 PASS — 2026-05-16):**
- ✅ JSON validity (jq -e): _contract.json + fe-component-graph.json template OK
- ✅ Bash syntax (bash -n): build-fe-component-graph.sh OK
- ✅ Runtime smoke test: skip + real fixture cả 2 PASS
- ✅ SKILL.md vẫn 487 dòng ≤500 (CORE-032)
- ✅ `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS

**Known limitations (documented, v2.1 upgrade path):**
- Parser v1.0 Grep-based — function signature types lost (vd `onSelect: (id: string) => void` → type `(id`). Upgrade v2.1 → `ts-morph` AST.
- Default export pattern detection chỉ match `export default function|const|class`, không match arrow-fn assigned variable trước.

**Đầu ra files (vertical slice):**
- `.claude/skills/workflow/wf-cmi/templates/fe-component-graph.json` (NEW)
- `.claude/scripts/wf-cmi/build-fe-component-graph.sh` (NEW, +252 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/phase2-discovery.md` (MODIFIED, +56 dòng)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +5 entries)
- `.claude/skills/workflow/wf-cmi/templates/Phase2-report.md` (MODIFIED, +1 dòng)

#### Stage 2.1 — 3 FE graphs còn lại — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** Scale pattern fe-component-graph sang 3 FE plugin graphs còn lại (4/7 total Stage 2).

- [X] **`fe-api-client-graph.json`** — Discovery Plugin #8 (CD13 + CD38 dependency)
  - [X] Template `templates/fe-api-client-graph.json` (schema `fe-api-client-graph-v1` + `_template_notes`, 4 kinds_distribution: react_query_hook/refit_interface/raw_fetch/service_function)
  - [X] Builder `.claude/scripts/wf-cmi/build-fe-api-client-graph.sh` (Grep v1.0: RQ hooks + Refit interfaces + raw fetch/axios + sentinel `EPv1:::` cho endpoint_path để bypass MSYS path conv)
  - [X] Smoke test: skip + real fixture (6 nodes, 6 edges, dist: RQ=2/Refit=1/raw=3)
- [X] **`fe-permission-graph.json`** — Discovery Plugin #9 (CD15 + CD38 dependency)
  - [X] Template `templates/fe-permission-graph.json` (schema `fe-permission-graph-v1` + 6 guard_patterns_distribution: PermissionGate/usePermission/Can/hasPermission/authorize_middleware/unknown)
  - [X] Builder `.claude/scripts/wf-cmi/build-fe-permission-graph.sh` (Grep v1.0 với 5 patterns + defensive `|| true` cho inner grep no-match)
  - [X] Smoke test: skip + real fixture (5 nodes, 5 edges, 5 unique permissions, all 5 guard patterns detected)
- [X] **`fe-route-graph.json`** — Discovery Plugin #10 (CD25 + CD38 dependency)
  - [X] Template `templates/fe-route-graph.json` (schema `fe-route-graph-v1` + 7 route_count_by_kind: page/layout/middleware/loading/error/not-found/template + dynamic/protected counts)
  - [X] Builder `.claude/scripts/wf-cmi/build-fe-route-graph.sh` (filesystem v1.0 + sentinel `ROUTEv1:::` cho route_path để bypass MSYS path conv + dynamic [param] + (protected) group detect)
  - [X] Smoke test: skip + real fixture (9 nodes, 6 edges, 1 dynamic route `/dashboard/customers/[id]`, 1 protected route `/admin`)
- [X] Update `procedures/phase2-discovery.md` — Steps 2.8c, 2.8d, 2.8e + POST-GATE plugin_files[4] expand + error codes E130-E135 lane-side fallback table
- [X] Update `_contract.json` — outputs.working[] 39→42 entries (+3 plugin) + fe-component notes refresh (Stage 2.1 status)
- [X] Update `templates/Phase2-report.md` — schema_notes relax 15→18 dòng, thêm 3 plugin graph counters (FE_API_CLIENT_COUNT/STATUS, FE_PERMISSION_COUNT/STATUS, FE_ROUTE_COUNT/STATUS)

**Gate Status (Stage 2.1 FE plugin set, 8/8 PASS — 2026-05-16):**
- ✅ Bash syntax (bash -n): 3 new builders OK
- ✅ JSON validity (jq -e): 3 new templates + updated _contract.json OK
- ✅ Skip path smoke test: 3 builders write `metadata.skipped: true` placeholder
- ✅ Real fixture smoke test: 3 builders parse correctly + MSYS path conv workaround works
- ✅ `_contract.json` outputs.working[] count = 42 (39 original + 3 plugin)
- ✅ SKILL.md vẫn 487 dòng ≤500 (CORE-032)
- ✅ `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS

**Known limitations (documented, v2.1 upgrade path):**
- Parser v1.0 Grep-based — function signature types lost, dynamic permission expressions marked `dynamic_or_variable`, mutationFn HTTP method default POST. Upgrade v2.1 → `ts-morph` AST.
- fe-route-graph filesystem-only — KHÔNG parse `generateMetadata()` exports (SEO/title coverage), KHÔNG parse middleware matcher config. v2.1 add AST.
- Git Bash for Windows MSYS POSIX path conversion: workaround qua sentinel tags (`EPv1:::`, `ROUTEv1:::`) — chỉ ảnh hưởng route/endpoint paths bắt đầu bằng `/`, KHÔNG ảnh hưởng permission strings (vd `crm.customer.read`).

#### Stage 2.2 Vertical Slice — be-domain-graph (1/3 BE plugins) — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** Validate BE plugin pattern với be-domain-graph (CD16 dependency) end-to-end trước khi scale 2 BE graphs còn lại.

- [X] **`be-domain-graph.json`** — Discovery Plugin #11 (CD16 dependency)
  - [X] Template `templates/be-domain-graph.json` (schema `be-domain-graph-v1` + `_template_notes` + 7 kinds_distribution: aggregate_root/entity/value_object/domain_event/domain_event_handler/specification/repository_interface)
  - [X] Builder script `.claude/scripts/wf-cmi/build-be-domain-graph.sh` (Grep base type matching + Python helper cho multi-base parsing + **--slurpfile cho large data bypass argv size limit**, v1.0 line-based)
  - [X] Update `procedures/phase2-discovery.md` Step 2.8f + POST-GATE `plugin_files[5]` expand + Step 2.10 sed thêm 7 BE_DOMAIN placeholders
  - [X] Update `_contract.json` outputs.working[] 42→43 entries (+1 be-domain) + error E133 lane-side mapping note "IMPLEMENTED"
  - [X] Update `templates/Phase2-report.md` schema_notes relax 18→20 dòng, thêm BE Domain line (count + status + 5 kind counters)
  - [X] Smoke test: skip path scenario PASS (write skipped placeholder)
  - [X] Smoke test: **EUREKA-2026 real fixture** PASS (944 DDD types / 1338 edges / 18 modules / aggregate=283, entity=510, VO=19, event=81, handler=47, spec=4, repo=0)

**Gate Status (Stage 2.2 Vertical Slice be-domain, 8/8 PASS — 2026-05-16):**
- ✅ GATE 1: Template JSON valid (jq parse + `$schema` field check)
- ✅ GATE 2: Builder bash syntax OK (`bash -n`)
- ✅ GATE 3: Skip path smoke test PASS (scope_root not found → write skipped placeholder)
- ✅ GATE 4: EUREKA real fixture smoke test PASS (parser ran 886 .cs files → 944 nodes / 1338 edges, 0 skipped, all 6 active kinds detected)
- ✅ GATE 5: `_contract.json` outputs.working[] count = 43 (was 42, +1 be-domain)
- ✅ GATE 6: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 7: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 8: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS

**Known limitations (documented, v2.1 upgrade path):**
- Parser v1.0 Grep-based — multi-base parsing dùng Python3 helper (fallback nguyên chuỗi nếu thiếu Python3, 1 base type duy nhất)
- `properties_count` heuristic — đếm `public Type Prop { get; ... }` từ class line đến `^}` đầu — có thể off cho nested class hoặc class >500 dòng
- `raises_event` attribute tới LAST aggregate_root trong file → misattribute khi 2+ aggregates raise events trong cùng file. v2.1 Roslyn syntax tree fix chính xác
- `repository_interface: 0` trong EUREKA-2026 → heuristic Grep `*Repository*` không match (repository interfaces có thể ở `Infrastructure/Persistence/Repositories/` ngoài `Domain/`). v2.1 expand scan path
- Module "unknown" entry → 1+ types ở path không match `Eureka.Modules.X` hoặc `EventHandlers/X` (vd `Eureka.Infrastructure/Persistence/IntegrationConfiguration.cs`). Acceptable v2.0 — v2.1 thêm path patterns

**Đầu ra files (vertical slice be-domain):**
- `.claude/skills/workflow/wf-cmi/templates/be-domain-graph.json` (NEW, schema `be-domain-graph-v1`)
- `.claude/scripts/wf-cmi/build-be-domain-graph.sh` (NEW, +452 dòng bash)
- `.claude/skills/workflow/wf-cmi/procedures/phase2-discovery.md` (MODIFIED, +57 dòng Step 2.8f + 14 dòng Step 2.10 sed + E133 IMPLEMENTED)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +1 entry outputs.working[] = 43)
- `.claude/skills/workflow/wf-cmi/templates/Phase2-report.md` (MODIFIED, +1 dòng BE Domain + relax 18→20)

#### Stage 2.2 — 2 BE graphs còn lại — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** Close Stage 2 với 2 BE graph builders còn lại (be-db-schema + be-cqrs). Áp dụng pattern be-domain-graph vertical slice với 1 cải tiến quan trọng cho be-cqrs: Python single-pass per file → JSON Lines accumulator + bulk jq aggregate (avoids O(n²) jq-append pattern khi xử lý 2000+ Application/ files trong EUREKA).

- [X] **`be-db-schema-graph.json`** — Discovery Plugin #12 (CD17 dependency)
  - [X] Template `templates/be-db-schema-graph.json` (schema `be-db-schema-graph-v1` + `_template_notes` + 5 kinds: tables/columns/foreign_keys/indexes/unique_constraints + `last_migration_per_module` tracking)
  - [X] Builder `.claude/scripts/wf-cmi/build-be-db-schema-graph.sh` (Python helper inline cho EF Core fluent API multi-line parsing — HasColumnType/HasMaxLength/IsRequired/HasIndex/HasOne span lines until `;`. Max file size 16MB cho enterprise snapshots 3-10MB. Primary source = DbContextModelSnapshot.cs, fallback = Migrations/*.cs)
  - [X] Smoke test: skip path scenario PASS (write skipped placeholder)
  - [X] Smoke test: **EUREKA-2026 real fixture** PASS (1249 tables / 13827 columns / 0 FKs / 2121 indexes / 313 unique constraints / modules=[Infrastructure, Migration] — single DbContext aggregates 17 module tables vào Infrastructure)
- [X] **`be-cqrs-graph.json`** — Discovery Plugin #13 (CD18 dependency)
  - [X] Template `templates/be-cqrs-graph.json` (schema `be-cqrs-graph-v1` + `_template_notes` + 7 kinds: command/query/request_handler/validator/pipeline_behavior/notification/notification_handler + `coverage_indicators` cho lane CD18 early warning)
  - [X] Builder `.claude/scripts/wf-cmi/build-be-cqrs-graph.sh` (Python single-pass per file → JSON Lines accumulator. Bulk jq aggregate cuối — avoids O(n²) jq-append. Coverage indicators computed trong 1 jq pass từ NODES_TMP để tránh argv limit cho 1000+ string IDs)
  - [X] Smoke test: skip path scenario PASS (write skipped placeholder)
  - [X] Smoke test: **EUREKA-2026 real fixture** PASS (3260 nodes / 2698 edges / 18 modules / kinds={command:296, query:257, request_handler:1825, validator:855, pipeline_behavior:7, notification:1, notification_handler:19} / coverage={reqs_no_handler:33, reqs_no_validator:359, handlers_no_request:1288} — handlers_no_request cao do v1.0 module heuristic, v2.1 Roslyn sẽ fix)
- [X] Update `procedures/phase2-discovery.md` — Steps 2.8g + 2.8h + POST-GATE `plugin_files[7]` expand (be-db-schema dùng `.tables` thay `.nodes`) + Step 2.10 sed thêm 14 BE_DB_SCHEMA + BE_CQRS placeholders + error refs E134/E135 marked IMPLEMENTED + cross-refs section
- [X] Update `_contract.json` — outputs.working[] 43 → 45 entries (+2 BE plugins) + be-domain note tail updated "Stage 2.2 BE plugin set COMPLETE" + E134/E135 description bump "IMPLEMENTED" với fallback notes
- [X] Update `templates/Phase2-report.md` — schema_notes relax 20→22 dòng, thêm 2 dòng counters (BE_DB_SCHEMA_COUNT/STATUS/COL/FK/IDX + BE_CQRS_COUNT/STATUS/CMD/QRY/HDL/VAL/NOH/NOV)

**Gate Status (Stage 2.2 close, 8/8 PASS — 2026-05-16):**
- ✅ GATE 1: 2 new template JSON valid (jq parse + `$schema` field check)
- ✅ GATE 2: 2 new builder bash syntax OK (`bash -n`)
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: `_contract.json` valid + outputs.working[] count = 45 (was 43, +2 BE plugins)
- ✅ GATE 5: Phase2-report.md schema_notes relax 22 dòng, 17 content lines
- ✅ GATE 6: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 7: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS
- ✅ GATE 8: Smoke re-test skip path cả 2 builders PASS sau full integration

**Known limitations (documented, v2.1 upgrade path):**
- **be-db-schema** Parser v1.0: Single DbContext shared across modules → tables aggregate vào module `Infrastructure` thay vì từng module riêng. v2.1 → parse `[Table]` attribute hoặc OnModelCreating namespace để phân tách. FK extraction từ snapshot dùng `b.HasOne("FQN")` — convention-based FK (shadow properties) bị miss. KHÔNG parse Owned types. Max file size 16MB.
- **be-cqrs** Parser v1.0: Module attribution heuristic — handler/validator module = file_path module nhưng request có thể ở module khác (handlers_without_request high). v2.1 → Roslyn full namespace resolution. command vs query heuristic dùng name suffix/prefix — default `command` nếu naming không follow convention. KHÔNG detect partial class split. KHÔNG resolve generic constraints (`where T : IRequest<X>`).

**Đầu ra files (Stage 2.2 close):**
- `.claude/skills/workflow/wf-cmi/templates/be-db-schema-graph.json` (NEW, schema `be-db-schema-graph-v1`)
- `.claude/skills/workflow/wf-cmi/templates/be-cqrs-graph.json` (NEW, schema `be-cqrs-graph-v1`)
- `.claude/scripts/wf-cmi/build-be-db-schema-graph.sh` (NEW, ~480 dòng bash + Python helper inline)
- `.claude/scripts/wf-cmi/build-be-cqrs-graph.sh` (NEW, ~410 dòng bash + Python helper inline)
- `.claude/skills/workflow/wf-cmi/procedures/phase2-discovery.md` (MODIFIED, +120 dòng Steps 2.8g/2.8h + Step 2.10 sed expand + POST-GATE update + error refs IMPLEMENTED + cross-refs)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +2 entries outputs.working[] = 45 + be-domain note tail update + E134/E135 IMPLEMENTED descriptions)
- `.claude/skills/workflow/wf-cmi/templates/Phase2-report.md` (MODIFIED, +2 dòng BE counters + relax 20→22)

**Performance:** be-db-schema EUREKA 2 snapshots ≈ 30s. be-cqrs EUREKA 2336 .cs files ≈ 5-6 phút (Python single-pass per file). Tổng BE plugin time ≈ 6-7 phút (acceptable cho profile deep total ~55-90 min).

---

### Stage 3: Define SSOT Files cho EUREKA (Tuần 2-3 song song với Stage 2) — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** Chuẩn bị 9 SSOT files để các lanes có context check.

- [X] **`ui-interactivity-spec.json`** ★ — Template tại `plans/wf-cmi/ui-interactivity-spec.eureka-template.json` (CD38) — 823 lines
- [X] **`ux-conventions.json`** — design tokens, button variants, format rules (CD23-CD27) — 538 lines
- [X] **`mdm-canonical-entities.json`** — 11 master entities + 8 reference data + ownership rules (CD28) — 431 lines
- [X] **`compliance-mapping.json`** — 5 VN + 3 CN + 3 intl regulations (CD37) — 450 lines
- [X] **`rbac-permission-catalog.json`** — 91 permissions × 17 modules + 13 roles + 3 clients (CD15, CD38) — 459 lines
- [X] **`workflow-state-machines.json`** — 9 state machines, 67 states, 59 transitions (CD3, CD26, CD38) — 369 lines
- [X] **`audit-critical-entities.json`** — 13 audit-critical entities + PII access + 4 system categories (CD29) — 359 lines
- [X] **`error-code-catalog.json`** — 28 error codes, 10 categories, 17 recovery actions, 11 UI patterns (CD39) — 635 lines
- [X] **`print-export-templates.json`** — 16 doc templates + 3 label templates + branding (CD40) — 459 lines

**Người làm:** Initial scaffolding bởi Claude. Cần stakeholder review (BA + domain experts) để populate runtime values cho EUREKA.
**Gate:** ✅ 9/9 files pass `jq -e '.'`, mọi file có `$schema` + `_template_notes` + `_instructions` + `validation_rules.rules[]` ≥ 5.
**Tổng:** ~4500 lines, location `plans/wf-cmi/*.eureka-template.json`.

**Sử dụng tiếp theo:**
1. Stakeholder review từng template, điền giá trị thực tế của EUREKA-2026
2. Copy `plans/wf-cmi/*.eureka-template.json` → `EUREKA-2026/.mc-data/docs/_meta/*.json` (strip `_template_notes`, `_instructions`, `_comment`)
3. Auto-generate seed cho mỗi file từ EUREKA source code khi có thể (xem `_maintenance` notes mỗi file)

---

### Stage 4: Build 18 New Lane Agents + Procedures (Tuần 4-9) — Effort ~60 ngày

**Mục đích:** Build từng lane agent với CORE-037 8-section prompt + procedure file.

#### Sub-stage 4.1: Core lanes (existing pattern reuse, 9 ngày) — ✅ HOÀN THÀNH 2026-05-16

**Design canon scaffold + lane procedure files (4/4 DONE 2026-05-16):**

- [X] Add §19/20/21/22 vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — 4 lane sections CORE-037 8 sections per lane (CD11/CD13/CD15/CD18). Renumber §19-22 cũ → §23-26 (Triage + spawn rules + anti-patterns + refs). Update §1 spawn map header mention sub-stage 4.1. agent-prompt.md 1555 dòng (+388 dòng vs trước).
- [X] **CD11** lane procedure `procedures/lanes/CD11.md` (354 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (`fe-component-graph.json` exists + schema + nodes ≥1 + lane dir), Steps CD11.1-CD11.9 (load graph → props type completeness → required flag → naming convention → orphan → duplicate name → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `FECC-CD11-NNN`, fingerprint dedup, file resolution). 5 signal kinds (INCOMPLETE_PROPS_TYPE, MISSING_REQUIRED_FLAG, PROP_NAMING_INCONSISTENCY, ORPHAN_COMPONENT, DUPLICATE_COMPONENT_NAME). Error codes E130-E132 (PRE-GATE) + E040-E045 (POST-GATE). **Wave 1 lane đơn giản — no SSOT mandatory.**
- [X] **CD13** lane procedure `procedures/lanes/CD13.md` (372 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (2 graphs `fe-api-client-graph` + `api-graph` exist + schema + nodes ≥1), Steps CD13.1-CD13.10 (load graphs → normalize routes → FE→BE endpoint existence → BE coverage → HTTP method mismatch → path param coverage → DTO shape drift optional → atomic write). 5 signal kinds (FE_CALLS_NONEXISTENT_BE_ENDPOINT, BE_ENDPOINT_UNUSED_BY_FE, HTTP_METHOD_MISMATCH, ENDPOINT_PARAM_MISSING, DTO_SHAPE_DRIFT). MUST severity cho 404/405 risks. **Wave 2 — cần Wave 1 graphs.**
- [X] **CD15** lane procedure `procedures/lanes/CD15.md` (363 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 với **SSOT** mandatory `rbac-permission-catalog.json` (E144 ESCALATE nếu missing — lane KHÔNG fallback heuristic), Steps CD15.1-CD15.9 (load 2 graphs + SSOT → orphan UI permission → BE auth no UI gate → dynamic unverifiable → naming drift → admin action missing guard → atomic write). 5 signal kinds (ORPHAN_UI_PERMISSION, BE_AUTH_NO_UI_GATE, DYNAMIC_PERMISSION_UNVERIFIABLE, PERMISSION_NAMING_DRIFT, MISSING_PERMISSION_FOR_ADMIN_ACTION). MUST severity cho admin action gap (security risk). **Wave 2 — SSOT-dependent (91 permissions × 17 modules EUREKA).**
- [X] **CD18** lane procedure `procedures/lanes/CD18.md` (373 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (`be-cqrs-graph.json` exists + schema + cmd+hdl ≥1 — không phải CQRS app → SKIP gracefully), Steps CD18.1-CD18.9 (load graphs + preprocessed coverage_indicators → command without handler → command/query without validator → handler without request → notification without subscriber → duplicate handler → atomic write). 5 signal kinds (COMMAND_WITHOUT_HANDLER, COMMAND_WITHOUT_VALIDATOR, HANDLER_WITHOUT_REQUEST, NOTIFICATION_WITHOUT_HANDLER, DUPLICATE_HANDLER). MUST severity cho runtime exception risk (HandlerNotFoundException, AmbiguousHandlerException). **Wave 2 — tận dụng coverage_indicators preprocessed (EUREKA: reqs_no_handler=33, reqs_no_validator=359, handlers_no_request=1288 v1.0 module heuristic).**
- [X] Update `procedures/phase4-coverage-dispatch.md` — Refine LANE_SIGNAL_KINDS_MAP cho CD11/CD13/CD15/CD18 (align với new signal kinds), update lane procedure status table (CD11/CD13/CD15/CD18 → ✅ DONE 2026-05-16 sub-stage 4.1), update spawn callout pattern (mapping lane → §section).
- [X] Update `_contract.json` — `.procedure[]` 13→17 (+4 lane refs), `.lanes_defined[]` CD11/CD13/CD15/CD18 thêm `procedure_file` + corrected `expected_signal_kinds` (5 kinds mỗi lane align design canon) + `graph_dependencies[]` (1/2/2/2 graphs) + `ssot_dependency` (null/null/`rbac-permission-catalog.json`/null) + `stage_4_status: lane-procedure-DONE-2026-05-16`.

**Đầu ra files sub-stage 4.1 (lane procedure build):**
- `docs/04-skill-design/wf-cmi/agent-prompt.md` (MODIFIED, +388 dòng — §19-22 NEW + renumber §19-22 cũ → §23-26 + §1 header refresh)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD11.md` (NEW, 354 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD13.md` (NEW, 372 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD15.md` (NEW, 363 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD18.md` (NEW, 373 dòng — tổng 1462 dòng 4 lane files)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, +12 dòng — signal kinds refine + lane procedure status table + spawn callout)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +4 procedure entries + 4 lanes refined với procedure_file/signal_kinds/graph_dependencies/ssot_dependency/stage_4_status)

**Gate Status (sub-stage 4.1 lane procedure, 6/6 PASS — 2026-05-16):**
- ✅ GATE 1: 4 lane procedure files exist + Markdown format đúng (354/372/363/373 dòng, mỗi file 8 sections §A-§H)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 17 (4 new lane refs) + 7 lanes có `procedure_file` field (CD11/13/15/18/28/30/31)
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: agent-prompt.md 1555 dòng — section numbering correct (§1 → §26)
- ✅ GATE 5: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 6: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 17 procedure paths trong `.procedure[]` đều tồn tại trên disk)

**Known limitations (documented):**
- CD11 parser/AST limitations đã ghi nhận ở Stage 2 vertical slice (Grep-based, function signature types lost — v2.1 ts-morph fix)
- CD13 path param coverage v1.0 heuristic — FE wrapper với generic name (vd `useCustomer()`) bị false positive. v2.1 ts-morph AST.
- CD13 DTO shape drift v1.0 disabled mặc định nếu thiếu type info — chỉ enable khi cả 2 graph có `response_type` field.
- CD15 dynamic permission marked `dynamic_or_variable` — KHÔNG static-verify, signal kind DYNAMIC_PERMISSION_UNVERIFIABLE chỉ log INFO/MAY.
- CD15 admin action heuristic match path/name — false positive nếu component admin trong domain module (vd `apps/erp-web/components/crm/customer-admin-tools.tsx`). v2.1 cross-ref permissions ở parent layout.
- CD18 module heuristic v1.0 Grep-based — handlers_no_request EUREKA fixture cao (1288) do namespace resolution không hoàn hảo. v2.1 Roslyn full namespace resolution. Lane mark severity SHOULD (không MUST) để tránh hard-block false positive.
- 1 SSOT (rbac-permission-catalog.json) cho CD15 — nếu schema bump v2 → v3 sẽ cần migration notes.

**Còn lại sub-stage 4.1 (effort ~3 ngày sau lane procedure DONE):**
- [ ] Lane-specific signal templates / scaffolding tests (vd `signal-fecc-001-incomplete-props.json` fixtures) — optional
- [ ] Integration test với EUREKA-2026 real fixtures cho CD11/CD13/CD15/CD18 — cần stakeholder populate SSOT `rbac-permission-catalog.json` (CD15 mandatory) + ui-interactivity-spec.json (CD13/CD11 nâng accuracy)

#### Sub-stage 4.2: BE deep lanes (10 ngày) — ✅ HOÀN THÀNH 2026-05-16 (lane procedures + full integration test)

**Design canon scaffold (2026-05-16):**
- [X] Add §23 Lane CD16 Domain Logic Integrity vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — CORE-037 8 sections, agent dyad `architect + business-analyst`, Wave 1, graph deps (be-domain-graph primary + be-cqrs-graph secondary cho DOMAIN_EVENT_MISSING cross-ref), no SSOT mandatory, 4 signal kinds (AGGREGATE_BOUNDARY_VIOLATION, DOMAIN_EVENT_MISSING, VALUE_OBJECT_LEAK, ANEMIC_DOMAIN_MODEL), error E133 INFO khi secondary graph thiếu, rule_id format `DDD-CD16-{NNN}`
- [X] Add §24 Lane CD17 Persistence Consistency — agent dyad `dba + data-engineer`, Wave 1, graph deps (be-db-schema-graph primary + be-domain-graph secondary cho SCHEMA_MISMATCH + UNUSED_TABLE_COLUMN cross-ref), no SSOT mandatory, 4 signal kinds (MIGRATION_DRIFT, MISSING_INDEX, SCHEMA_MISMATCH_ENTITY_DB, UNUSED_TABLE_COLUMN — note v1.0 thêm UNUSED_TABLE_COLUMN vs _contract.json baseline ban đầu chỉ có 3), error E133 INFO khi secondary graph thiếu, rule_id format `PERSIST-CD17-{NNN}`
- [X] Renumber existing §23-§26 (Triage, spawn rules, anti-patterns, refs) → §25-§28
- [X] Update §1 spawn map header — mention §23-24 sub-stage 4.2 Wave 1 (CD16/CD17), refine remaining lanes line (removed CD16/CD17 từ "đang scaffold dần")
- [X] Audit gates: `skill-compliance-audit.sh wf-cmi` GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL), `validate-schema-sync.sh wf-cmi` 1/1 PASS, SKILL.md vẫn 487 dòng ≤500 (CORE-032), agent-prompt.md 1775 dòng (+220 dòng vs trước sub-stage 4.2)

**Sub-stage 4.2 lane procedure files — ✅ HOÀN THÀNH 2026-05-16 (2/2 DONE):**

- [X] **CD16** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD16.md` (350 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (`be-domain-graph.json` exists + schema + nodes ≥1 + lane dir, T1b optional `be-cqrs-graph.json` với E133 WARN fallback), Steps CD16.1-CD16.8 (load graphs → aggregate_owners build → AGGREGATE_BOUNDARY_VIOLATION cross-aggregate ref → DOMAIN_EVENT_MISSING với CQRS handler cross-ref → VALUE_OBJECT_LEAK heuristic → ANEMIC_DOMAIN_MODEL indirect detection → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `DDD-CD16-NNN`, fingerprint dedup, entity resolution trong be-domain-graph), 4 signal kinds, error codes E130-E133 + E040-E045. **Wave 1 lane — không phụ thuộc lanes khác. AGGREGATE_BOUNDARY_VIOLATION luôn severity MUST (chặn merge).**
- [X] **CD17** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD17.md` (370 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (`be-db-schema-graph.json` exists + schema + tables ≥1 + lane dir; T1b optional `be-domain-graph.json` với E133 WARN), Steps CD17.1-CD17.8 (load 2 graphs → MIGRATION_DRIFT compare snapshot vs filesystem migrations → MISSING_INDEX cho FK columns → SCHEMA_MISMATCH_ENTITY_DB cross-ref entity properties vs DB columns → UNUSED_TABLE_COLUMN với technical whitelist + FK shadow skip → atomic write), POST-GATE T1-T4 (rule_id format `PERSIST-CD17-NNN`, fingerprint dedup, entity resolution trong cả 2 graphs HOẶC special `DbContextModelSnapshot`), 4 signal kinds. MIGRATION_DRIFT + SCHEMA_MISMATCH (type_drift) luôn severity MUST (data loss risk).

**Integration test với EUREKA-2026 real fixtures — ✅ HOÀN THÀNH 2026-05-16:**

- [X] Build be-domain-graph + be-db-schema-graph cho EUREKA-2026 (apps/backend) → `/tmp/cd16-cd17-eureka-test/phase2-discovery/`
- [X] **CD16 PRE-GATE T1-T4 PASS** với fixture: 944 nodes / 1338 edges / 18 modules / kinds={aggregate_root:283, entity:510, value_object:19, domain_event:81, domain_event_handler:47, specification:4, repository_interface:0}. Schema=`be-domain-graph-v1`, skipped=false, DDD types count=793 (aggregate_root+entity).
- [X] **CD16 lane logic probing:** 217 raises_event edges, 218/283 aggregates KHÔNG raise event = DOMAIN_EVENT_MISSING + ANEMIC strong candidates. `references_entity + aggregates` edges = 0 (graph v1.0 limitation — AGGREGATE_BOUNDARY_VIOLATION coverage = 0 trên EUREKA, v2.1 cần Roslyn parser).
- [X] **CD17 PRE-GATE T1-T3 PASS** với fixture: 1249 tables / 13827 columns / 0 FK / 2121 indexes / 2 modules (Infrastructure aggregates 17 actual). Schema=`be-db-schema-graph-v1`, skipped=false.
- [X] **CD17 lane logic probing:** FK extraction=0 (graph v1.0 limitation — HasOne convention not extracted → MISSING_INDEX coverage=0 trên EUREKA). `last_migration_per_module = {}` (graph v1.0 limitation — MIGRATION_DRIFT cannot compare). Table-entity name matching test: 3/5 matched (`approval_decisions → ApprovalDecision` ✓), 2/5 failed naive English singularization (`approval_escalation_histories → "histori"` invalid; `approval_sla_rules → ApprovalSlaRule` but real entity là `ApprovalSLARule` với caps).
- [X] E133 WARN handling verified — CD16/CD17 gracefully fallback khi secondary graph missing (be-cqrs-graph trong CD16 test, be-domain trong CD17 test).

**Đầu ra files sub-stage 4.2 (lane procedure build):**
- `docs/04-skill-design/wf-cmi/agent-prompt.md` (MODIFIED, +220 dòng — §23-24 NEW + renumber §23-26 cũ → §25-28 + §1 header refresh)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD16.md` (NEW, 350 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD17.md` (NEW, 370 dòng — tổng 720 dòng 2 lane files)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, ~6 dòng — Wave 1 lane table refine CD16/CD17 với procedure file + signal kinds bổ sung UNUSED_TABLE_COLUMN cho CD17, lane procedure status table CD16/CD17 → ✅ DONE, spawn callout mapping CD16→§23, CD17→§24)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +2 procedure entries `.procedure[]` 20→22 + 2 lanes refined với `graph_dependencies[]` array + `procedure_file` + `ssot_dependency: null` + `ssot_optional: false` + `stage_4_status: lane-procedure-DONE-2026-05-16` + CD17 `expected_signal_kinds` thêm UNUSED_TABLE_COLUMN)

**Gate Status (sub-stage 4.2 lane procedure + integration test, 7/7 PASS — 2026-05-16):**
- ✅ GATE 1: 2 lane procedure files exist + Markdown format đúng (350/370 dòng)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 22 (2 new lane refs added) + 2 lanes có `procedure_file` field + signal_kinds count = 4/4 đúng design canon (CD17 thêm UNUSED_TABLE_COLUMN)
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: agent-prompt.md 1775 dòng — section numbering correct (§1 → §28 liên tục, no gaps)
- ✅ GATE 5: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 6: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 22 procedure paths trong `.procedure[]` đều tồn tại trên disk, bao gồm CD16/CD17)
- ✅ GATE 7: Integration test với EUREKA-2026 real fixtures PASS — be-domain-graph build OK (944 nodes), be-db-schema-graph build OK (1249 tables), CD16+CD17 PRE-GATE T1-T4 logic verified, lane Step queries tested với jq cross-ref

**Known limitations (documented):**
- CD16 AGGREGATE_BOUNDARY_VIOLATION coverage=0 trên EUREKA v1.0 fixture — graph parser v1.0 KHÔNG extract `references_entity` + `aggregates` edges (depends on property type analysis, requires Roslyn AST). v2.1 upgrade path.
- CD16 ANEMIC_DOMAIN_MODEL có thể high false positive (218/283 aggregates flagged trên EUREKA) — heuristic chỉ check `raises_event` edges = 0, không track method signatures. v2.1 Roslyn cần track method names + parameters.
- CD16 VALUE_OBJECT_LEAK v1.0 heuristic dùng `base_types[]` pattern matching — KHÔNG verify setter visibility (immutability chính xác cần AST). 19 VOs trên EUREKA → low confidence signal.
- CD17 MIGRATION_DRIFT chỉ chạy được khi graph builder fix `last_migration_per_module` extraction — hiện tại EUREKA fixture empty `{}`. Lane procedure đã document gracefully skip với note "v1.0 limitation".
- CD17 MISSING_INDEX coverage=0 trên EUREKA v1.0 fixture — graph parser v1.0 KHÔNG extract convention-based FK (`HasOne` Fluent API → shadow properties). 0/1249 tables với declared FK. v2.1 upgrade Roslyn để parse OnModelCreating EntityTypeBuilder calls.
- CD17 SCHEMA_MISMATCH_ENTITY_DB chỉ check `column_count > entity.properties_count + 5` heuristic ở v1.0 — KHÔNG cross-ref tên + type cụ thể. Cần graph builder v2.1 track property names trong be-domain-graph + column names trong be-db-schema-graph.
- CD17 UNUSED_TABLE_COLUMN tương tự — chỉ heuristic count, false positive cao. Lane runtime nên document evidence rõ ràng "v1.0 heuristic count-based, requires manual verify".
- Table-entity name matching v1.0 chỉ làm PascalCase + naive singular (drop trailing `s`) — fail với English irregular plurals (`histories → history`, `data → datum`) + acronyms (`SLA, IDs`). v2.1 cần proper English inflection library hoặc lookup table.

**Còn lại sub-stage 4.2 (effort ~3 ngày sau lane procedure + integration test DONE):**
- [ ] Graph builder v2.1 enhancement — extract `references_entity` + `aggregates` edges trong be-domain-graph (cần Roslyn syntax tree)
- [ ] Graph builder v2.1 enhancement — extract convention-based FK trong be-db-schema-graph (parse OnModelCreating)
- [ ] Graph builder v2.1 enhancement — populate `last_migration_per_module{}` đúng cách (parse DbContextModelSnapshot.cs migration metadata)
- [ ] Run CD16/CD17 actual agent dispatch với EUREKA fixture (cần Wave 1 batch spawn từ orchestrator)

#### Sub-stage 4.3: UX lanes (11 ngày) — ✅ LANE PROCEDURE FILES DONE 2026-05-16 (4/4)

**Design canon scaffold + lane procedure files (4/4 DONE 2026-05-16):**

- [X] Add §25/26/27/28 vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — 4 lane sections CORE-037 8 sections per lane (CD23/CD24/CD25/CD26). Renumber §25-28 cũ → §29-32 (Triage + spawn rules + anti-patterns + refs). Update §1 spawn map header mention sub-stage 4.3 Wave 2+3 lanes. agent-prompt.md 2233 dòng (+458 dòng vs trước).
- [X] **CD23** lane procedure `procedures/lanes/CD23.md` (387 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (`fe-component-graph.json` exists + SSOT `ux-conventions.json` mandatory với `design_tokens.colors` ≥1 + `component_variants` ≥1 + CD23 validation_rules ≥2 — E145 ESCALATE nếu missing), Steps CD23.1-CD23.9 (load graph+SSOT → design token drift hex/rgb/spacing/font-size → button/badge variant inconsistent → color hardcoded brand integrity → typography drift → icon library uniformity → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `UXDS-CD23-NNN`, fingerprint dedup, file resolution). 5 signal kinds (DESIGN_TOKEN_DRIFT, BUTTON_VARIANT_INCONSISTENT, COLOR_HARDCODED severity **MUST** brand-guardian gate, TYPOGRAPHY_DRIFT, ICON_INCONSISTENT). Error codes E145+E040-E045+E130. **Wave 2 — SSOT mandatory.**
- [X] **CD24** lane procedure `procedures/lanes/CD24.md` (388 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (graph + SSOT `ux-conventions.json` mandatory với `display_formats` ≥5 categories + CD24 validation_rules ≥3 — E145 ESCALATE), Steps CD24.1-CD24.9 (load + format declarations → date format consistent → number format consistent → currency format consistent multi-currency VND/CNY/USD → timezone drift Asia/Ho_Chi_Minh → VND no-decimal compliance check → atomic write), POST-GATE T1-T4 (rule_id format `UXFMT-CD24-NNN`, VND_DECIMAL_PRESENT severity HIGH enforcement). 5 signal kinds (DATE_FORMAT_INCONSISTENT, NUMBER_FORMAT_INCONSISTENT, CURRENCY_FORMAT_INCONSISTENT, TIMEZONE_DRIFT, VND_DECIMAL_PRESENT severity **HIGH** compliance gate). Regulatory refs: **TT 78/2021/TT-BTC** (e-invoice VN VND no decimal), TT 80/2021 (rounding HALF_UP), 国家税务总局 (CNY decimal 2), VNACCS spec (BOL format), ISO 6346 (container). **Wave 2 — logistics format compliance.**
- [X] **CD25** lane procedure `procedures/lanes/CD25.md` (413 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (2 graphs `fe-route-graph` + `fe-component-graph` + SSOT `ux-conventions.json` mandatory với `ux_flow_continuity.rules[]` ≥1 + `confirmation_patterns` ≥1 + CD25 validation_rules ≥1 — E145 ESCALATE), Steps CD25.1-CD25.9 (load 2 graphs + SSOT → broken user journey link tới route không tồn tại → dead-end page user trap → missing breadcrumb depth ≥3 → inconsistent navigation menu drift → missing confirmation cho destructive action → atomic write), POST-GATE T1-T4 (rule_id format `UXFLOW-CD25-NNN`, safety-critical severity enforcement). 5 signal kinds (BROKEN_USER_JOURNEY severity **MUST** 404 risk, DEAD_END_PAGE, MISSING_BREADCRUMB, INCONSISTENT_NAVIGATION, MISSING_CONFIRMATION_DIALOG severity **MUST** data loss risk). **Wave 2 — safety gate.**
- [X] **CD26** lane procedure `procedures/lanes/CD26.md` (437 dòng — most complex UX lane) — 8 sections §A-§H, PRE-GATE T1-T4 (3 graphs `fe-component-graph` + `fe-route-graph` + `be-domain-graph` + SSOT `workflow-state-machines.json` mandatory với `state_machines{}` ≥1 + complete `states[]`/`transitions[]` + `ux_visibility_requirements.requirements[]` ≥1 — E146 ESCALATE nếu missing) + secondary SSOT `ux-conventions.json` optional cho StatusBadge variants, Steps CD26.1-CD26.9 (load 3 graphs + 2 SSOTs → workflow state UI visibility list+detail → action context indicator near button → actor role display owner/assignee → multi-step progress visualization timeline/stepper (states ≥5) → transition history audit trail (events_published ≥3) → atomic write), POST-GATE T1-T4 (rule_id format `UXWFV-CD26-NNN`, entity resolution trong workflow-state-machines, logistics-critical severity enforcement). 5 signal kinds (WORKFLOW_STATE_UNCLEAR_UI severity **HIGH**, MISSING_STATUS_INDICATOR, ACTOR_ROLE_AMBIGUOUS, PROGRESS_HIDDEN severity **HIGH** cho logistics Booking 8 states + CustomsDeclaration 6 states + Invoice 5 states TT 78/2021, MISSING_TRANSITION_HISTORY). 9 EUREKA state machines reference (Booking/CustomsDeclaration/Invoice/Order/Payment/Quotation/PurchaseOrder/QcInspection/ApprovalRequest). **Wave 3 — final cross-ref, 3 graphs + 2 SSOTs, ★★★ logistics-aware.**
- [X] Update `procedures/phase4-coverage-dispatch.md` — Refine LANE_SIGNAL_KINDS_MAP cho CD23/CD24/CD25/CD26 align với new signal kinds (5 per lane), update lane procedure status table (CD23/CD24/CD25/CD26 → ✅ DONE 2026-05-16 sub-stage 4.3), update spawn callout mapping (CD23→§25, CD24→§26, CD25→§27, CD26→§28).
- [X] Update `_contract.json` — `.procedure[]` 22→26 (+4 lane refs), `.lanes_defined[]` CD23/CD24/CD25/CD26 thêm `procedure_file` + corrected `expected_signal_kinds` (5 kinds mỗi lane align design canon) + `graph_dependencies[]` (1/1/2/3 graphs) + `ssot_dependency` (ux-conventions cho CD23/CD24/CD25, workflow-state-machines cho CD26) + `ssot_secondary` (CD26) + `stage_4_status: lane-procedure-DONE-2026-05-16`. CD24 thêm `compliance_refs[]` (TT 78/2021, TT 80/2021, 国家税务总局, VNACCS, ISO 6346). CD26 thêm `logistics_critical_entities[]` (Booking/CustomsDeclaration/Invoice).

**Đầu ra files sub-stage 4.3 (lane procedure build):**
- `docs/04-skill-design/wf-cmi/agent-prompt.md` (MODIFIED, +458 dòng — §25-28 NEW + renumber §25-28 cũ → §29-32 + §1 header refresh)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD23.md` (NEW, 387 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD24.md` (NEW, 388 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD25.md` (NEW, 413 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD26.md` (NEW, 437 dòng — tổng 1625 dòng 4 lane files)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, +5 dòng — signal kinds refine + lane procedure status table + spawn callout)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +4 procedure entries + 4 lanes refined với procedure_file/signal_kinds/graph_dependencies/ssot_dependency/stage_4_status + CD24 compliance_refs + CD26 logistics_critical_entities)

**Gate Status (sub-stage 4.3 lane procedure, 5/5 PASS — 2026-05-16):**
- ✅ GATE 1: 4 lane procedure files exist + Markdown format đúng (387/388/413/437 dòng, mỗi file 8 sections §A-§H)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 26 (4 new lane refs) + 4 lanes có `procedure_file` field + signal_kinds count = 5/5/5/5 đúng design canon + graph_dependencies = 1/1/2/3 + ssot_dependency present
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 5: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 26 procedure paths trong `.procedure[]` đều tồn tại trên disk, bao gồm 4 lane CD23-26)

**Known limitations (documented, v2.1 upgrade path):**
- CD23 parser v1.0 Grep-based — color hex detection có thể false positive với hex trong comment (vd `// see #FF5733`). v2.1 ts-morph AST.
- CD23 icon library detection chỉ check import statements — không detect dynamic require/lazy load. v2.1 expand pattern.
- CD24 timezone drift v1.0 — chỉ flag `new Date()` standalone, không phát hiện `Date.UTC()` calls hoặc moment().tz() patterns. v2.1 expand AST analysis.
- CD24 VND_DECIMAL_PRESENT chỉ check display layer FE — không enforce backend invoice generation. CD31 Money & Tax lane (sub-stage 4.4) cover backend.
- CD25 broken user journey v1.0 — dynamic path templates `\`/users/${id}\`` chỉ resolve sau template literal eval; static analysis có thể false negative với complex template. v2.1 ts-morph.
- CD25 missing confirmation v1.0 heuristic — destructive handler patterns Grep-based; false positive nếu handler tên `onDelete` nhưng thực ra là soft-delete (intentional). v2.1 semantic analysis.
- CD26 most complex — 3 graphs + 2 SSOTs cross-ref. Risk performance khi EUREKA scale: 944 domain nodes + 1338 edges. Mitigation: SSOT entity list filter trước, không iterate full graph.
- CD26 owner_module heuristic — entity detail page detection match route pattern, có thể miss custom routes (vd `/operations/bookings/[id]/dashboard`). v2.1 add manual route mapping in SSOT.
- 2 SSOTs cần stakeholder populate cho EUREKA: ux-conventions.json (CD23/24/25 mandatory) + workflow-state-machines.json (CD26 mandatory cho 9 entities Booking/Invoice/...).

**Còn lại sub-stage 4.3 (effort ~7 ngày sau lane procedure DONE):**
- [ ] Lane-specific signal templates / scaffolding tests (vd `signal-uxds-001-color-hardcoded.json` fixtures) — optional
- [ ] Integration test với EUREKA-2026 real fixtures cho CD23/CD24/CD25/CD26 — cần stakeholder populate 2 SSOTs (ux-conventions.json mandatory cho CD23-25 + workflow-state-machines.json mandatory cho CD26)
- [ ] Performance optimization CD26 với EUREKA scale (944 domain nodes + 1338 edges) — benchmark + cache strategy

#### Sub-stage 4.4: Logistics-critical lanes (13 ngày) ★★★ — ⏳ DESIGN CANON SCAFFOLD DONE 2026-05-16

**Design canon scaffold (2026-05-16):**
- [X] Add §16 Lane CD28 MDM Consistency vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — CORE-037 8 sections, agent triad `data-engineer + dba + logistics-expert`, Wave 2, graph deps (entity-graph + be-db-schema-graph + be-domain-graph + api-graph), SSOT dep `mdm-canonical-entities.json`, 6 signal kinds (DUPLICATE_MASTER_ENTITY, MISSING_UNIQUE_CONSTRAINT, PARTIAL_UNIQUE_CONSTRAINT, UNAUTHORIZED_MASTER_WRITER, REFERENCE_DATA_DRIFT, MISSING_MDM_SYNC), error E141 ESCALATE khi thiếu SSOT
- [X] Add §17 Lane CD30 Time & Numbering Integrity — agent triad `architect + dba + logistics-expert`, Wave 2, graph deps (be-db-schema-graph + be-domain-graph + be-cqrs-graph + api-graph), SSOT dep `workflow-state-machines.json` (numbering schemes + timezone policy), 6 signal kinds (NAIVE_DATETIME_STORAGE, TIMEZONE_BOUNDARY_DRIFT, MISSING_NUMBERING_UNIQUE, NUMBERING_FORMAT_VIOLATION, MISSING_NUMBERING_RESET, DATE_TYPE_DRIFT), error E142 ESCALATE, VN compliance ref TT 78/2021/TT-BTC + VNACCS
- [X] Add §18 Lane CD31 Money & Tax Integrity — agent triad `finance-expert + dba + architect`, Wave 2, graph deps (be-db-schema-graph + be-domain-graph + be-cqrs-graph + api-graph), SSOT deps `mdm-canonical-entities.json` (currencies) + `compliance-mapping.json` (tax_regulations), 11 signal kinds (WRONG_DECIMAL_SCALE, CRITICAL_FLOAT_MONEY, MISSING_MONEY_VALUE_OBJECT, INCOMPLETE_MONEY_TYPE, CURRENCY_MISMATCH_RISK, MIXED_CURRENCY_HEADER, EXPIRED_TAX_RATE, MISSING_ROUNDING_RULE, INCOMPLETE_TAX_BREAKDOWN, MISSING_FX_AUDIT_TRAIL, HARDCODED_FX_RATE), error E143 ESCALATE, VN tax ref NQ 142/2024/QH15 + TT 80/2021/TT-BTC + CN VAT 13%/9%/6%
- [X] Renumber existing §16-§19 (Triage, spawn rules, anti-patterns, refs) → §19-§22
- [X] Update §1 spawn map header — mention §16-18 sub-stage 4.4 ★★★ Wave 2 (CD28/30/31), refine remaining lanes line (removed CD28-31 from "đang scaffold dần")
- [X] Audit gates: `skill-compliance-audit.sh wf-cmi` GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL), `validate-schema-sync.sh wf-cmi` 1/1 PASS, SKILL.md vẫn 487 dòng ≤500 (CORE-032), agent-prompt.md 1167 dòng (+356 dòng vs trước)

**Sub-stage 4.4 lane procedure files — ✅ HOÀN THÀNH 2026-05-16 (3/3 DONE):**

- [X] **CD28** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD28.md` (375 dòng) — 8 sections §A-§H, PRE-GATE 4 SSOT/graph checks (E141 ESCALATE nếu SSOT missing), Steps CD28.1-CD28.9 (load SSOT → canonical ownership → unique key → multi-writer → reference data drift → cross-module sync → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `MDM-CD28-NNN`, fingerprint dedup, SSOT mapping), error codes E141+E040-E045+E130. **Tích hợp: 4 graphs + 1 SSOT (mdm-canonical-entities.json).**
- [X] **CD30** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD30.md` (397 dòng) — 8 sections §A-§H, PRE-GATE 4 checks (E142 nếu SSOT thiếu timezone_policy hoặc numbering_schemes), Steps CD30.1-CD30.10 (timezone-aware datetime + timezone boundary drift + numbering uniqueness + format regex + reset policy + date-only vs datetime), POST-GATE T1-T4 (rule_id format `TIME-CD30-NNN`), error codes E142+E040-E045+E130. Regulatory refs: TT 78/2021/TT-BTC (VN invoice), VNACCS spec, 国家税务总局 (CN). **Tích hợp: 4 graphs + 1 SSOT (workflow-state-machines.json).**
- [X] **CD31** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD31.md` (432 dòng — phức tạp nhất Wave 2) — 8 sections §A-§H, PRE-GATE 4 checks với **2 SSOTs** (mdm-canonical-entities currencies + compliance-mapping tax_regulations), Steps CD31.1-CD31.10 (decimal precision + Money VO usage + currency mismatch + tax rate compliance + tax breakdown + FX audit trail), POST-GATE T1-T4 (rule_id format `(MONEY|TAX)-CD31-NNN` cross-validate 2 SSOTs), 11 signal kinds (nhiều nhất), error codes E143+E040-E045+E130. Regulatory refs: NQ 142/2024/QH15 (VAT VN 8%), TT 78/2021 (e-invoice), TT 80/2021 (rounding HALF_UP), 国家税务总局 (VAT CN 13%/9%/6%), Incoterms 2020, IFRS, SBV/PBoC/ECB FX. **Tích hợp: 4 graphs + 2 SSOTs.**

**Đầu ra files sub-stage 4.4 (lane procedure build):**
- `.claude/skills/workflow/wf-cmi/procedures/lanes/` (NEW dir)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD28.md` (NEW, 375 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD30.md` (NEW, 397 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD31.md` (NEW, 432 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, +25 dòng — callout note về lane procedure files + signal kinds update CD28/30/31 align design canon)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +3 entries `.procedure[]` 10→13 + add `procedure_file` + corrected `expected_signal_kinds` + `ssot_dependency` + `graph_dependencies` + `stage_4_status` cho CD28/30/31)

**Gate Status (sub-stage 4.4 lane procedure, 5/5 PASS — 2026-05-16):**
- ✅ GATE 1: 3 lane procedure files exist + Markdown format đúng (375/397/432 dòng)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 13 (3 new lane refs added) + 3 lanes có `procedure_file` field + signal_kinds count = 6/6/11 đúng design canon
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 5: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 3 lane procedure paths trong `.procedure[]` đều tồn tại trên disk)

**Known limitations (documented):**
- Lane procedure files dùng bash + jq pseudocode patterns — agent runtime CẦN implement actual signal generation logic (cross-ref graph nodes/edges + SSOT validation_rules). v2.1 có thể extract reusable Python utilities sang `_shared/` (vd `_shared/cmi_signal_builder.py`).
- POST-GATE T3 rule_id validation chỉ check format regex + SSOT mapping — KHÔNG validate semantic correctness của signal. Edge case: agent có thể generate signal với rule_id hợp lệ format nhưng sai semantic (vd dùng `MDM-CD28-002` cho rule UNIQUE thay vì `MDM-CD28-003`). Mitigation: lane completion criteria yêu cầu rule_id match SSOT validation_rules[].id.
- 2 SSOTs cho CD31 → migration complexity nếu schema bump v2 → v3 (cần coordinate cả 2 templates).

**Còn lại sub-stage 4.4 (effort ~6 ngày sau lane procedure DONE):**
- [ ] Lane-specific signal templates / scaffolding tests (vd `signal-mdm-001-duplicate-entity.json` fixtures) — optional, có thể inline trong agent runtime
- [ ] Integration test với EUREKA-2026 real fixtures cho CD28/CD30/CD31 — cần stakeholder populate 3 SSOT templates với giá trị thực tế EUREKA (Carrier/Customer ownership_module + numbering_schemes Invoice/BOL/Customs + tax_regulations VN/CN 2024)

#### Sub-stage 4.5: Compliance & Audit (8 ngày) — ✅ LANE PROCEDURE FILES DONE 2026-05-16 (2/2)

**Design canon scaffold + lane procedure files (2/2 DONE 2026-05-16):**

- [X] Add §29/30 vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — 2 lane sections CORE-037 8 sections per lane (CD29/CD37). Renumber §29-32 cũ → §31-34 (Triage/Spawn/Anti-patterns/Refs). Update §1 spawn map header mention sub-stage 4.5 compliance lanes. agent-prompt.md 2457 dòng (+224 dòng vs trước).
- [X] **CD29** lane procedure `procedures/lanes/CD29.md` (398 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (4 graphs `be-db-schema` + `be-domain` + `be-cqrs` + `api-graph` exist + SSOT `audit-critical-entities.json` MANDATORY E145 ESCALATE nếu missing, lane KHÔNG fallback heuristic vì audit requirements cần explicit entity declaration), Steps CD29.1-CD29.9 (load 4 graphs + SSOT → audit_table existence check trong DB schema → audit_required_actions coverage handlers → immutability violation UPDATE/DELETE statements → tracked_fields capture verification → PII access logging cho READ endpoints VN-PDPL+GDPR → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `AUDIT-CD29-NNN` map ↔ `RULE-CD29-NNN` SSOT, fingerprint dedup, entity resolution). 5 signal kinds (MISSING_AUDIT_TABLE, AUDIT_ACTION_NOT_IMPLEMENTED, AUDIT_MUTABILITY_VIOLATION, TRACKED_FIELD_NOT_CAPTURED severity SHOULD/HIGH, PII_READ_NOT_LOGGED severity **MUST** VN-PDPL Điều 6). Error codes E145+E040-E045+E130. Compliance refs: VN-PDPL (Nghị định 13/2023/NĐ-CP), VN-TT78/2021/TT-BTC (e-invoice immutability), GDPR Art. 30, ISO 27001 A.12.4, SOC 2 CC7.2. **Wave 3 final cross-ref.**
- [X] **CD37** lane procedure `procedures/lanes/CD37.md` (435 dòng — phức tạp nhất Wave 2 sau CD31) — 8 sections §A-§H, PRE-GATE T1-T4 (4 graphs + SSOT `compliance-mapping.json` MANDATORY E143 ESCALATE, T3 require ≥1 regulation trong VN/CN/intl + ≥5 validation_rules), Steps CD37.1-CD37.9 (load 4 graphs + SSOT 3 jurisdictions → compliance check coverage qua entity/endpoint/process/code_pattern resolve → regulatory rule violation static analysis state invariant + allowed values + field pattern → PII governance dimensions consent+erasure+access log+encryption → cross-border CN→VN CAC assessment + GDPR transfer + OFAC sanctions screening → audit freshness last_audited_at >365 days → atomic write với jurisdiction_breakdown metadata VN/CN/intl), POST-GATE T1-T4 (rule_id format `COMP-CD37-NNN` + regulation_ref resolution trong 3 jurisdictions). 5 signal kinds (MISSING_COMPLIANCE_CHECK, REGULATORY_RULE_VIOLATION severity **MUST**, PERSONAL_DATA_UNGOVERNED severity **MUST**, CROSS_BORDER_COMPLIANCE_GAP severity **MUST**, COMPLIANCE_AUDIT_STALE severity MEDIUM). Error codes E143+E040-E045+E130. Compliance refs: 5 VN (TT 78/2021, PDPL 2023, VNACCS, Labor Code 2019, NQ 142/2024/QH15) + 3 CN (Fapiao 国家税务总局, H2010 海关总署, PIPL 2021) + 3 intl (Incoterms 2020, GDPR, OFAC). Cross-lane note: CD29 check call-site, CD37 check structural existence — KHÔNG duplicate. **Wave 2 cross-layer ★★★ compliance-critical.**
- [X] Update `procedures/phase4-coverage-dispatch.md` — Refine LANE_SIGNAL_KINDS_MAP cho CD29/CD37 (5 kinds mỗi lane align design canon), update lane procedure status table (CD29/CD37 → ✅ DONE 2026-05-16 sub-stage 4.5), update spawn callout mapping (CD29→§29, CD37→§30), thêm tag "Sub-stage 4 COMPLETE 18/18 lanes" footer.
- [X] Update `_contract.json` — `.procedure[]` 26→28 (+2 lane refs), `.lanes_defined[]` CD29/CD37 thêm `procedure_file` + corrected `expected_signal_kinds` (5 kinds mỗi lane) + `ssot_optional: false` + `priority` + `graph_dependencies[]` (4 graphs mỗi lane: be-db-schema + be-domain + be-cqrs + api) + `stage_4_status: lane-procedure-DONE-2026-05-16` + `compliance_refs[]` + `rule_id_prefix` (AUDIT-CD29 / COMP-CD37). CD37 thêm `logistics_critical_entities[]` (Invoice/Customer/CustomsDeclaration/TaxDeclaration/EmploymentContract) + `cross_lane_overlap_note` (CD29 vs CD37 complementary).

**Đầu ra files sub-stage 4.5 (lane procedure build):**
- `docs/04-skill-design/wf-cmi/agent-prompt.md` (MODIFIED, +224 dòng — §29-30 NEW + renumber §29-32 cũ → §31-34 + §1 header refresh)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD29.md` (NEW, 398 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD37.md` (NEW, 435 dòng — tổng 833 dòng 2 lane files)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, ~6 dòng — signal kinds refine + lane procedure status table + spawn callout + Stage 4 COMPLETE footer)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +2 procedure entries `.procedure[]` 26→28 + 2 lanes refined với procedure_file/expected_signal_kinds_5/graph_dependencies_4/ssot_optional/stage_4_status + CD29/CD37 compliance_refs/rule_id_prefix + CD37 logistics_critical_entities/cross_lane_overlap_note)

**Gate Status (sub-stage 4.5 lane procedure, 5/5 PASS — 2026-05-16):**
- ✅ GATE 1: 2 lane procedure files exist + Markdown format đúng (398/435 dòng, mỗi file 8 sections §A-§H)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 28 (2 new lane refs) + 2 lanes có `procedure_file` field + signal_kinds count = 5/5 đúng design canon + graph_dependencies = 4/4 + ssot_dependency present (mandatory)
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 5: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 28 procedure paths trong `.procedure[]` đều tồn tại trên disk, bao gồm 2 lane CD29/CD37)

**Known limitations (documented, v2.1 upgrade path):**
- CD29 MISSING_AUDIT_TABLE chỉ check existence trong be-db-schema-graph — KHÔNG validate audit_log_schema.required_columns[] đầy đủ (Id, Timestamp, ActorUserId, ChangedFields, CorrelationId, TenantId, ...). v2.1 expand T2 schema check để verify từng column required + index + RLS policy.
- CD29 AUDIT_ACTION_NOT_IMPLEMENTED v1.0 Grep-based phát hiện audit call patterns — false negative cao nếu dùng custom interceptor (vd `AuditableEntitySaveInterceptor` registered global qua DI). v2.1 cần Roslyn parse DI registration + interceptor binding.
- CD29 TRACKED_FIELD_NOT_CAPTURED chỉ static check property name vs `tracked_fields[]` — KHÔNG runtime verify ChangedFields JSONB actually populated correctly. v2.1 cần integration test fixture.
- CD29 PII_READ_NOT_LOGGED phát hiện endpoints GET liên quan entity, nhưng KHÔNG track GraphQL/gRPC reads. v2.1 expand cho non-REST.
- CD37 MISSING_COMPLIANCE_CHECK heuristic match entity/endpoint/process/code_pattern — false positive nếu requirement có `process` name không follow `*Process` convention (vd `ConsentManager` thay vì `ConsentManagementProcess`). v2.1 cần SSOT thêm `process_class_pattern` override.
- CD37 REGULATORY_RULE_VIOLATION static analysis — không runtime test invariants (vd Invoice.Update() throw guard). Edge case: guard ở base class hoặc decorator pattern → false negative. v2.1 Roslyn syntax tree analysis.
- CD37 CROSS_BORDER_COMPLIANCE_GAP CN-PIPL detection dùng heuristic `customer.region == "CN"` — nếu dùng tenant config hoặc dynamic flag → false negative. v2.1 cần SSOT thêm `cross_border_detection_patterns[]`.
- CD37 COMPLIANCE_AUDIT_STALE chỉ check last_audited_at — KHÔNG validate audit thực sự xảy ra (chỉ trust SSOT). Workflow `annual_regulatory_review` chỉ document, không enforce.
- 2 SSOTs cho CD29/CD37 cần stakeholder populate cho EUREKA: audit-critical-entities.json (13 entities + PII access + 4 system categories) + compliance-mapping.json (5 VN + 3 CN + 3 intl regulations với actual EUREKA mapping).

**Còn lại sub-stage 4.5 (effort ~6 ngày sau lane procedure DONE):**
- [ ] Lane-specific signal templates / scaffolding tests (vd `signal-audit-001-missing-table.json` fixtures) — optional
- [ ] Integration test với EUREKA-2026 real fixtures cho CD29/CD37 — cần stakeholder populate 2 SSOTs (audit-critical-entities mandatory + compliance-mapping mandatory)
- [ ] Cross-lane validation CD29 vs CD37 (PII overlap) — verify 2 lanes không duplicate signals trên cùng entity.

> **🎯 STAGE 4 ĐÓNG HOÀN TOÀN 2026-05-16 — 18/18 lanes có procedure file + design canon section!**
> Tổng 6/6 sub-stages DONE: 4.1 (CD11/13/15/18) + 4.2 (CD16/17) + 4.3 (CD23/24/25/26) + 4.4 (CD28/30/31) + 4.5 (CD29/37) + 4.6 (CD38/39/40).
> Tổng lane procedure files: 18 files, ~6900 dòng. Integration tests pending sau khi stakeholder populate 7 mandatory SSOTs.

#### Sub-stage 4.6: NEW additions (10 ngày) — ✅ LANE PROCEDURE FILES DONE 2026-05-16 (3/3)

**Design canon scaffold (2026-05-16 — đã DONE từ session trước):**
- [X] Add §13 Lane CD38 UI Implementation Coverage vào `docs/04-skill-design/wf-cmi/agent-prompt.md` — CORE-037 8 sections, graph deps (fe-api-client/fe-permission/fe-route), SSOT dep `ui-interactivity-spec.json`, 5 signal kinds (ORPHAN_API_ENDPOINT, MISSING_UI_FOR_USER_FACING_API, INCOMPLETE_CRUD_UI, MISSING_PERMISSION_UI_ELEMENT, WORKFLOW_STATE_NO_UI_TRIGGER), error E144 ESCALATE khi thiếu SSOT
- [X] Add §14 Lane CD39 Error UX & Recovery — 8 sections, graph deps (fe-component/fe-route), SSOT `error-code-catalog.json`, 5 signal kinds (MISSING_ERROR_BOUNDARY, RAW_ERROR_LEAKED_TO_USER, MISSING_RECOVERY_ACTION, ERROR_MESSAGE_NOT_VIETNAMESE, INCONSISTENT_ERROR_DISPLAY), error E147 WARN fallback heuristic
- [X] Add §15 Lane CD40 Print & Export Consistency — 8 sections, graph deps (fe-component/fe-route/api-graph), SSOT `print-export-templates.json`, 5 signal kinds (PRINT_TEMPLATE_DRIFT, PDF_FONT_MISSING, EXCEL_FORMULA_BROKEN, BRAND_LOGO_MISSING_DOC, EXPORT_DATA_MISMATCH_UI), logistics-critical doc types (invoice/BOL/customs declaration)
- [X] Renumber §13-16 → §16-19 (Triage + spawn rules + anti-patterns + references)
- [X] Update §1 spawn map header — v2.0 26 lanes context, 3-WAVE dispatch, ~40 agents/session
- [X] Audit gates: `skill-compliance-audit.sh wf-cmi` GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL), `validate-schema-sync.sh wf-cmi` 1/1 PASS, SKILL.md vẫn 487 dòng ≤500 (CORE-032), agent-prompt.md 811 dòng

**Sub-stage 4.6 lane procedure files — ✅ HOÀN THÀNH 2026-05-16 (3/3 DONE):**

- [X] **CD38** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD38.md` (400 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (4 graphs `fe-api-client` + `fe-permission` + `fe-route` + `api-graph` + SSOT `ui-interactivity-spec.json` MANDATORY — E144 ESCALATE nếu missing, lane KHÔNG fallback heuristic vì UI implementation cần explicit spec), Steps CD38.1-CD38.9 (load graphs+SSOT → orphan API check với grace_period_days → missing UI for user-facing API → incomplete CRUD UI (strict/lenient mode) → missing permission UI element → workflow state no UI trigger CRITICAL → atomic write signals/report/lane-status), POST-GATE T1-T4 (rule_id format `UI-CD38-NNN`, fingerprint dedup, SSOT rule_ref resolve), 5 signal kinds, error codes E144+E040-E045+E130. **Tích hợp: 4 graphs + 1 SSOT mandatory. Wave 3 final cross-ref.**
- [X] **CD39** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD39.md` (416 dòng) — 8 sections §A-§H, PRE-GATE T1-T4 (2 graphs `fe-component` + `fe-route` + SSOT `error-code-catalog.json` OPTIONAL — E147 WARN nếu missing, fallback Grep heuristic vẫn chạy), Steps CD39.1-CD39.9 (load + fallback handle → missing error boundary (Next.js App Router error.tsx/global-error.tsx) → raw error leak detection toast(err.message) → missing recovery action coverage → Vietnamese message check CORE-005 → consistent display pattern → atomic write), POST-GATE T1-T4 (rule_id format `ERR-CD39-NNN`), 5 signal kinds, error codes E147+E040-E045+E130. **Tích hợp: 2 graphs + 1 SSOT optional với graceful degradation.**
- [X] **CD40** lane procedure file `.claude/skills/workflow/wf-cmi/procedures/lanes/CD40.md` (444 dòng — phức tạp nhất Wave 3) — 8 sections §A-§H, PRE-GATE T1-T4 (3 graphs `fe-component` + `fe-route` + `api-graph` + SSOT `print-export-templates.json` OPTIONAL — E148 WARN fallback filesystem scan), Steps CD40.1-CD40.9 (load + scan template files filesystem + brand assets + PDF export endpoints → print template drift (TT 78/2021/TT-BTC e-invoice VN) → PDF font availability VN/CN → Excel formula integrity + UTF-8 BOM CSV → brand logo/identity check external-facing → export data mismatch UI list view → atomic write), POST-GATE T1-T4 (rule_id format `DOC-CD40-NNN`), 5 signal kinds, error codes E148+E040-E045+E130+E132. Regulatory refs: Thông tư 78/2021/TT-BTC (e-invoice VN), VNACCS spec (customs), BOL bilingual VN+EN+CN. **Tích hợp: 3 graphs + 1 SSOT optional + filesystem scan fallback. Logistics document-heavy.**

**Đầu ra files sub-stage 4.6 (lane procedure build):**
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD38.md` (NEW, 400 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD39.md` (NEW, 416 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD40.md` (NEW, 444 dòng — tổng 1260 dòng 3 lane files)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, ~10 dòng — Wave 3 lane table refine với procedure file + signal kinds bổ sung, lane procedure status table CD38-40 → ✅ DONE, spawn callout mapping CD38→§13, CD39→§14, CD40→§15)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, +3 procedure entries `.procedure[]` 17→20 + 3 lanes refined với `graph_dependency: null` + `graph_dependencies[]` + `procedure_file` + `stage_4_status` + `ssot_optional: true` cho CD39/CD40 — CD38 mandatory)

**Gate Status (sub-stage 4.6 lane procedure, 5/5 PASS — 2026-05-16):**
- ✅ GATE 1: 3 lane procedure files exist + Markdown format đúng (400/416/444 dòng)
- ✅ GATE 2: `_contract.json` valid JSON + `.procedure[]` count = 20 (3 new lane refs added) + 3 lanes có `procedure_file` field + signal_kinds count = 5/5/5 đúng design canon
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm)
- ✅ GATE 4: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 5: `validate-schema-sync.sh wf-cmi` → TẤT CẢ 1 SKILLS PASS (validator xác nhận 20 procedure paths trong `.procedure[]` đều tồn tại trên disk, bao gồm 3 lane CD38/39/40)

**Known limitations (documented):**
- CD38 SSOT mandatory — nếu chưa populate `ui-interactivity-spec.json` cho EUREKA, lane sẽ ESCALATE E144 và STOP. Template ready tại `plans/wf-cmi/ui-interactivity-spec.eureka-template.json` (823 dòng). Stakeholder cần điền `endpoint_classifications[]` (~100+ endpoints), `crud_required_entities[]` (~17 entities × 4 ops), `permission_ui_mapping[]` (90+ permissions), `workflow_user_actions{}` cho EUREKA modules.
- CD39 SSOT optional — fallback Grep heuristic vẫn detect được MISSING_ERROR_BOUNDARY (Next.js convention) và RAW_ERROR_LEAKED_TO_USER patterns. Nhưng MISSING_RECOVERY_ACTION skip nếu SSOT thiếu (cần explicit recovery_action declaration), và ERROR_MESSAGE_NOT_VIETNAMESE chỉ check ở SSOT entries (cần error_codes catalog).
- CD40 SSOT optional — fallback filesystem scan tìm template files (.html, .liquid, .hbs, .xml, .cshtml, .razor) và brand assets (logo*, brand*). Nhưng PRINT_TEMPLATE_DRIFT chỉ trigger nếu SSOT có `required_fields[]` declared (compliance docs cần explicit list).
- CD40 Excel formula check v1.0 chỉ static parse — KHÔNG runtime evaluate. v2.1 có thể integrate ExcelJS để parse runtime.
- CD40 export-UI mismatch v1.0 heuristic — match column name approximate (vd `customer_name` vs `Tên KH`) qua manual mapping. v2.1 cải tiến với DTO type analysis.

**Còn lại sub-stage 4.6 (effort ~6 ngày sau lane procedure DONE):**
- [ ] Integration test với EUREKA-2026 real fixtures cho CD38/CD39/CD40 — cần stakeholder populate 3 SSOT templates (ui-interactivity-spec + error-code-catalog + print-export-templates) với giá trị thực tế EUREKA (CD38 mandatory, CD39/CD40 optional nhưng coverage tăng khi có)
- [ ] Brand asset path resolution cho CD40 — verify logo/brand files thực tế trong EUREKA tồn tại + đúng path declared trong SSOT

**Gate per lane:** Agent prompt 8 sections (done qua design canon), signals.json schema (template signals-v1), lane-status.json template (đã có), CD{N}-report.md inline trong procedure file, integration test pass (pending).

---

### Stage 5: Update Phase 4 Dispatcher (Tuần 5 — song song Stage 4) — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** 3-wave dispatch strategy cho 26 lanes — wave coordinator bash script + per-wave gate validation + idempotent state tracking.

- [X] Update `procedures/phase4-coverage-dispatch.md` — 3-WAVE strategy đã có sẵn từ Stage 4 sub-stages (Wave 1: CD1-CD7, CD11, CD16, CD17 / Wave 2: CD13, CD15, CD18, CD23-CD25, CD28, CD30, CD31, CD37 / Wave 3: CD9, CD26, CD29, CD38-CD40). **Stage 5 refine:** wire `.claude/scripts/wf-cmi/wave-coordinator.sh` vào Step 4.2 (init) + Step 4.5 (start/end + gate check qua subcommands thay vì inline pseudocode) + Step 4.6 (note về wave-coordinator handle aggregation) + §G Cross-References bổ sung wave-status.json template + wave-coordinator.sh script. 16 references đến wave-coordinator/wave-status trong procedure file.
- [X] **Wave coordinator script (bash) với gate check per wave** — `.claude/scripts/wf-cmi/wave-coordinator.sh` (394 dòng) với 5 subcommands:
  - `init <SESSION_DIR> <PROFILE>` — strip template metadata + populate session_id/profile + create `phase4-coverage/wave-status.json`
  - `start <SESSION_DIR> <WAVE_ID> "<LANES_CSV>"` — mark started_at + populate lanes_active từ canonical wave map ∩ requested (empty CSV = full canonical)
  - `end <SESSION_DIR> <WAVE_ID>` — aggregate per-lane lane-status.json → wave-status.json + gate threshold check, idempotent re-run KHÔNG double-count
  - `status <SESSION_DIR>` — 3-wave summary với gate_status + counts + duration
  - `gate-check <SESSION_DIR> <WAVE_ID>` — read-only re-evaluate recorded gate_status

  Exit codes: 0=PASS, 1=FAIL_THRESHOLD (≥3 W1/W2 hoặc ≥2 W3 → E120/E121/E122 STOP dispatch), 2=PARTIAL_FAIL (1-2 fail < threshold → E123 WARN + retry). Helper `update_overall_status` compute terminal state qua acceptable matrix (PASS|SKIPPED|PARTIAL_FAIL = OK, FAIL_THRESHOLD = block).
- [X] Per-lane timeout 3 min (E041) — đã có sẵn từ Stage 4 trong phase4-coverage-dispatch Step 4.6 (MCV3_CMI_LANE_TIMEOUT_SEC=180 default).
- [X] **Per-wave gate validation** — gate threshold check trong `wave-coordinator.sh end`: W1+W2 fail_threshold=3, W3 fail_threshold=2. Exit code mapping rõ ràng → orchestrator handle theo BHV-004 verify-then-advance.
- [X] **NEW Template `templates/wave-status.json`** (schema `wave-status-v1`, 73 dòng) — per-wave execution tracking với fields wave_X.{lanes_active, lane_count, lane_outcomes, pass_count, fail_count, timeout_count, skip_count, started_at, completed_at, duration_sec, gate_status, error_code, error_message, fail_threshold, max_concurrency, description}. Top-level: session_id, profile, current_wave (0=pre / 1-3=running / 4=complete sentinel), all_waves_complete, overall_status (PENDING|RUNNING|PASS|FAIL), total_lanes_{active,completed,failed} (computed idempotently từ sum wave_X subfields, KHÔNG accumulate per call).
- [X] Update `_contract.json` — wave-status entry pointed to template (`templates/wave-status.json`) thay vì `null`, notes updated với schema version + subcommands + exit codes + idempotency + CORE-035 path align (`$SESSION_DIR/phase4-coverage/wave-status.json`). `internal_phases.phase4.concurrency` note mention wave-coordinator.sh + exit code mapping (E120/E121/E122/E123).

**Đầu ra files Stage 5:**
- `.claude/skills/workflow/wf-cmi/templates/wave-status.json` (NEW, 73 dòng, schema `wave-status-v1`)
- `.claude/scripts/wf-cmi/wave-coordinator.sh` (NEW, 394 dòng, 5 subcommands)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (MODIFIED, +25 dòng — Step 4.2 init wire + Step 4.5 pseudocode replace inline bash với wave-coordinator subcommands + Step 4.6 note + §G refs)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, ~5 dòng — wave-status template ref + notes expand + internal_phases.phase4.concurrency wave-coordinator mention)

**Technical notes (key engineering decisions):**
- **Git Bash MSYS path conversion safe:** `jq -r` trên Windows emit `\r\n` line endings → `tr -d '\r'` ngay sau jq output để tránh tokenization bug trong for/while loops (CD1\r ≠ CD1)
- **jq dynamic field access:** dùng `.["wave_" + ($w | tostring)]` thay vì `\(...)` interpolation để tránh bash `set -u` conflict với `$w` literal trong double-quoted jq filter strings
- **Atomic write:** `.tmp.$$` build → jq parse validate → POSIX `mv` rename (CORE-035 pattern)
- **Idempotent end:** `total_lanes_completed/failed` computed từ `(wave_1.pass_count + wave_2.pass_count + wave_3.pass_count)` thay vì `(.total + $pc)` accumulation — re-run cùng wave KHÔNG double-count
- **CORE-035 path alignment:** `wave-status.json` ở `$SESSION_DIR/phase4-coverage/` (cùng phase subdirectory), KHÔNG ở top-level $SESSION_DIR

**Gate Status (Stage 5, 8/8 PASS — 2026-05-16):**
- ✅ GATE 1: SKILL.md vẫn 487 dòng ≤500 (CORE-032 không vi phạm — Stage 5 KHÔNG touch SKILL.md, chỉ procedure + template + script)
- ✅ GATE 2: `_contract.json` valid JSON (`jq -e '.version' = "2.0.0"`)
- ✅ GATE 3: `templates/wave-status.json` valid JSON + `$schema = "wave-status-v1"`
- ✅ GATE 4: `wave-coordinator.sh` bash syntax OK (`bash -n`)
- ✅ GATE 5: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 6: `validate-schema-sync.sh wf-cmi` → 1/1 SKILLS PASS (28 procedure paths verified + output templates exist)
- ✅ GATE 7: 28 procedure paths exist on disk (jq + `tr -d '\r'` strip CRLF cho Git Bash)
- ✅ GATE 8: phase4-coverage-dispatch.md có 16 references đến wave-coordinator/wave-status

**Smoke test scenarios (11/11 PASS — 2026-05-16):**
1. `init` — strip template metadata + populate session_id/profile + create `phase4-coverage/wave-status.json` ✅
2. `start` wave 1 với empty CSV → use canonical lanes (10 lanes CD1-CD7,CD11,CD16,CD17) ✅
3. `start` wave 2 với CSV "CD13,CD15,CD18,CD23,CD24" → filter canonical ∩ requested (5 lanes) ✅
4. `end` wave 1 PARTIAL_FAIL (8 pass + 1 fail + 1 timeout = 2 combined < threshold 3 → E123 exit 2) ✅
5. `end` wave 1 PASS all 10 pass (exit 0) ✅
6. `end` wave 2 FAIL_THRESHOLD (3 fail ≥ threshold 3 → E121 exit 1) ✅
7. `end` wave 3 FAIL_THRESHOLD (2 fail ≥ threshold 2 → E122 exit 1) ✅
8. `end` idempotency: re-run cùng wave KHÔNG double-count totals ✅
9. `status` — 3-wave summary format đẹp với gate_status + counts + duration ✅
10. `gate-check` — read-only re-evaluate (PASS=0, PARTIAL_FAIL=2, FAIL_THRESHOLD=1, INCOMPLETE=3) ✅
11. Quick profile (chỉ W1 active) → W2/W3 SKIPPED → overall_status PASS + all_waves_complete=true + current_wave=4 sentinel ✅

**Known limitations (documented, v2.1 upgrade path):**
- `wave-coordinator.sh` runs SYNCHRONOUS — KHÔNG monitor Agent processes (Claude Code spawn Agent qua tool batch, không expose PID). Timeout enforcement vẫn ở orchestrator level qua TodoWrite + manual check.
- `update_overall_status` chỉ tính FAIL khi có wave với `FAIL_THRESHOLD`. Nếu lane fail nhưng wave PARTIAL_FAIL được retry và sau cùng vẫn fail (post-retry), wave-coordinator KHÔNG re-trigger — orchestrator phải tự gọi `end` lại sau retry batch.
- Wave-coordinator KHÔNG handle `--resume` directly — orchestrator phải check `wave-status.json.current_wave` + `wave_X.gate_status` để route resume. Resume mid-wave logic ở `resume-status.md`.
- `start` subcommand requires canonical wave map maintained inline (wave_lanes_canonical bash function). Khi v3 thêm Wave 4 (CD32-CD36 skeleton activate), cần update bash function + map + threshold.

**Cross-skill impact:** KHÔNG (Stage 5 chỉ internal phase 4 refinement, không touch `produces_for{}` hoặc `consumes_from{}` artifact contracts).

**Gate:** ✅ Dry-run với mock data — 3 waves sequential PASS (W1 PASS + W2 PASS + W3 PASS → overall PASS, all_waves_complete=true).

---

### Stage 6: Update Phase 5 Aggregator (Tuần 6) — Effort ~3 ngày

**Mục đích:** Coverage matrix support 26 dims + threshold logic.

- [ ] Update aggregator script — load signals từ 26 lanes
- [ ] Coverage matrix schema bump (`coverage-matrix-v2`) — handle 26 dims
- [ ] SKIPPED markers cho CD8, CD10 (vẫn appear trong matrix với `status: "SKIPPED"`)
- [ ] Threshold check per profile (deep ≥95%, exhaustive 100%)
- [ ] CDG E090 escalate khi below threshold
- [ ] Early exit E005 — 100% coverage + 0 violations → skip Phase 6-7

**Gate:** Matrix validate qua jq schema, threshold logic tested với 3 sample matrices.

---

### Stage 7: Update Report Generation (Tuần 6) — ✅ HOÀN THÀNH 2026-05-16

**Mục đích:** integrity-report.md handle 26 dims gọn gàng + cross-skill artifact schema bump v2 với backward-compat consumer read v1.

- [X] Update `templates/integrity-report.md` — flexible dim table (đã có từ Stage 1)
- [X] Group dims theo nhóm (Core/FE/BE/UX/Logistics★★★/Compliance★★★/Implementation★) — đã có từ Stage 1
- [X] **Top 10 issues prioritization (severity weighted)** — Stage 7 NEW: thay 3 hardcoded slots bằng `[TOP_VIOLATIONS_LIST]` placeholder, procedure sort_by(-sev_w, dim, rule_id) với MUST=4/HIGH=3/MEDIUM=2/LOW=1, multi-line awk insert. Max bound ≤55 dòng (44-48 typical 0-3 violations, 52-55 với 10 top violations).
- [X] **Cross-skill artifact `integrity-impact.json` schema bump v1 → v2** — Stage 7 NEW:
  - `$schema: integrity-impact-v2` (was v1)
  - 5 v2 fields NEW: `lanes_v2{active[],skipped[],skeleton[]}` (26+9+5), `wave_breakdown{wave_1,wave_2,wave_3}` per-wave counts+overall_pct+gate_status, `group_breakdown` 7 sections với critical flag cho logistics/compliance, `logistics_critical_signals_count{total,by_lane,must_severity_count}` từ CD28/30/31/37/38/39/40, `schema_version_compat{current,readable_by:[v1,v2]}` consumer detect hint
  - ALL v1 fields preserved (coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, summary, audit_chain) — backward-compat verified ✅
  - `consumers_recommended_actions` 4 consumers update v2 logic (wf-prepare-deployment dùng logistics_critical_signals_count.must_severity_count + wave_breakdown gate_status để block release)
- [X] Update `procedures/phase8-report.md` — Step 8.3 full rewrite (per-group computation từ COVERAGE_MATRIX + wave summary từ wave-status.json + top 10 severity-weighted + 50+ placeholders sed coverage), Step 8.4 full rewrite (v2 populate 8 sections, jq pipeline merge), POST-GATE T2 v2 required fields check + T3 ≤55 + 0 leftover placeholders check, E084 message ≤30→≤55, §F E084 description bump, §G cross-refs thêm wave-status.json + coverage-matrix.json
- [X] Update `_contract.json` — outputs.working[18] notes ≤30→≤55 + 7 grouped sections detail, cross_skill_contracts.produces_for 4 consumers v1→v2 references chi tiết logic, NEW `produces_for_schema_compat` section định nghĩa `$schema_field_in_artifact='integrity-impact-v2'` + backward-compat contract (consumer detect via $schema, v1 reader OK với v2 artifact)

**Gate Status (Stage 7, 5/5 PASS — 2026-05-16):**
- ✅ GATE 1: `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL)
- ✅ GATE 2: `validate-schema-sync.sh wf-cmi` → 1/1 SKILLS PASS, 28 procedure paths valid, output templates exist
- ✅ GATE 3: SKILL.md vẫn 487 dòng ≤500 (CORE-032 — Stage 7 KHÔNG touch SKILL.md, chỉ template + procedure + _contract)
- ✅ GATE 4: Smoke test max bound (10 top violations) → 52 dòng ≤55 + 0 leftover placeholders, 7 grouped sections render đúng, wave summary đúng, top 10 sorted by severity weight đúng
- ✅ GATE 5: Backward-compat verify — `jq -e` check tất cả v1 fields (coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, summary, audit_chain.{source,checksum,git_commit,author}) đều preserved trong v2 template; tất cả v2 fields mới (lanes_v2.active/skipped/skeleton, wave_breakdown.wave_1/2/3, group_breakdown.logistics.critical, logistics_critical_signals_count.total, schema_version_compat.readable_by[0]='integrity-impact-v1') đều present

**Đầu ra files Stage 7:**
- `.claude/skills/workflow/wf-cmi/templates/integrity-report.md` (MODIFIED, _schema_notes ≤50→≤55 max bound + section 3 hardcoded 3 slots → placeholder `[TOP_VIOLATIONS_LIST]`)
- `.claude/skills/workflow/wf-cmi/templates/integrity-impact.json` (REWRITE FULL, schema v1→v2 với 5 v2 fields mới + skill_version + final_status top-level, all v1 fields preserved, 215 dòng)
- `.claude/skills/workflow/wf-cmi/procedures/phase8-report.md` (MODIFIED, header info v2, Step 8.3 full rewrite ~200 dòng per-group + wave + top 10, Step 8.4 full rewrite ~150 dòng v2 schema populate, POST-GATE T2/T3 update, §F E084 desc, §G refs)
- `.claude/skills/workflow/wf-cmi/_contract.json` (MODIFIED, ~3 dòng outputs notes + ~15 dòng produces_for v2 references + ~10 dòng NEW produces_for_schema_compat section)

**Technical notes (key engineering decisions):**
- **Backward-compat first**: V2 artifact LUÔN có đầy đủ v1 fields → v1 readers (legacy consumer) đọc bình thường, chỉ ignore v2 extras. Producer LUÔN ghi `$schema='integrity-impact-v2'`.
- **Top 10 placeholder pattern (vs hardcoded slots)**: Cho phép adaptive count 0-10 violations, không bloat template với 10 empty slots khi healthy.
- **Severity weight `sev_weight`**: MUST=4, HIGH=3, MEDIUM=2, LOW=1, others=0. Sort `-sev_w, dim, rule_id` → deterministic top 10.
- **Per-group computation từ COVERAGE_MATRIX**: 7 groups (core/frontend/backend/ux/logistics/compliance/implementation) với lane_ids canonical match `_contract.json.lanes_defined` + `group_breakdown` trong template.
- **logistics_critical_signals_count**: 7 lanes ★★★ aggregate (CD28 MDM + CD30 Time + CD31 Money + CD37 Regulatory + CD38 UI + CD39 Error + CD40 Print) — wf-prepare-deployment dùng `must_severity_count > 0` để BLOCK release.
- **Max bound ≤55**: Top 10 violations expansion thêm ~7 dòng vs v1 hardcoded 3 slots. Tradeoff cho compliance với Stage 7 spec "Top 10 prioritization".
- **0 leftover placeholders check**: POST-GATE T3 grep `\[[A-Z_]+\]` count → nếu >0 retry sed populate (catch missing placeholders sớm).

**Known limitations (documented):**
- Consumer skills (wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment) CHƯA implement integrity-impact reader logic — current consumer codebases KHÔNG có `--from-cmi` flag handler hoặc `integrity-impact.json` read. Stage 7 chỉ implement PRODUCER side (wf-cmi). Consumer wire-up là separate effort (cần coordinate với owner mỗi consumer skill).
- Backward-compat contract định nghĩa trong `_contract.json.produces_for_schema_compat` là FORWARD-LOOKING design contract — chưa có integration test thực với consumer reader. Khi consumer wire-up, cần verify $schema field detection logic.
- Wave summary fallback khi `wave-status.json` không tồn tại (vd profile=quick chỉ W1) → tất cả wave hiển thị "—". Acceptable v2 — Stage 5 dispatcher đảm bảo wave-status.json luôn tồn tại sau Phase 4.

**Còn lại sau Stage 7:**
- [ ] Stage 8 (Tests + Audit) ~5 ngày — evals.json 8 new test cases + EUREKA dry-run + smoke 3 profiles (cần stakeholder populate 7 mandatory SSOTs)
- [ ] Stage 9 (Docs + PR) ~3 ngày — CHANGELOG + CLAUDE.md + skills-catalog + user guide + migration notes v1→v2 + PR
- [ ] Consumer-side update (wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment) — wire `--from-cmi` flag + integrity-impact reader với $schema field detection (separate effort)

---

### Stage 8: Tests & Audit (Tuần 7-8) — Effort ~5 ngày

**Mục đích:** Đảm bảo v2.0 không break v1.0 + có integration tests.

- [ ] Update `evals/evals.json` — add 8 new test cases cho new lanes
- [ ] Integration test với EUREKA-2026 dry-run
- [ ] Audit scripts pass:
  - [ ] `skill-compliance-audit.sh wf-cmi`
  - [ ] `validate-schema-sync.sh wf-cmi`
  - [ ] `check-skill-design-populated.sh docs/04-skill-design/wf-cmi/`
- [ ] Manual smoke test 3 profiles (quick, standard, deep)
- [ ] Performance test — full deep run 26 lanes ≤90 min

**Gate:** Tất cả audit pass, smoke test pass, eval test pass ≥7/8.

---

### Stage 9: Documentation & PR (Tuần 9) — Effort ~3 ngày

**Mục đích:** Update docs + ship v2.0.

- [ ] Update CHANGELOG.md — wf-cmi v2.0 release notes
- [ ] Update CLAUDE.md — wf-cmi entry với 26 lanes
- [ ] Update `docs/01-architecture/07-skills-catalog.md` — wf-cmi v2.0
- [ ] Update `docs/04-skill-design/wf-cmi/05-execution-profiles.md` — profile v2 activation
- [ ] User guide tại `docs/06-user-guides/per-skill/wf-cmi-v2-guide.md`
- [ ] Migration notes v1 → v2
- [ ] Create PR `feat(wf-cmi): v2.0.0 — Gói C++ Logistics expansion (26 lanes)`

**Gate:** PR review pass, audit-devkit pass, CHANGELOG có entry.

---

## 6. Timeline Tổng (Sequential View)

```
Tuần 1:    Stage 1 (Foundation refactor)
Tuần 2-3:  Stage 2 (Graphs) + Stage 3 (SSOT)         [song song]
Tuần 4-9:  Stage 4 (18 lanes)                        [parallel sub-stages]
Tuần 5-6:  Stage 5 (Dispatcher) + Stage 6 (Aggregator) [song song với Stage 4]
Tuần 6:    Stage 7 (Reports)
Tuần 7-8:  Stage 8 (Tests + Audit)
Tuần 9:    Stage 9 (Docs + PR)

TỔNG: 9 tuần (~63 ngày dev) cho v2.0 release
```

**Bottleneck:** Stage 4 (60 ngày effort) — cần parallel team hoặc spread time.

---

## 7. Tracking Checklist Tổng (Quick View)

### Stage 1 — Foundation

- [ ] Update _contract.json
- [ ] Update SKILL.md
- [ ] Update integrity-status.json schema
- [ ] Update coverage-matrix.json schema
- [ ] Update integrity-report.md template
- [ ] Update phase4-coverage-dispatch.md
- [ ] Update phase5-aggregate.md

### Stage 2 — Graphs (7 graphs) — ✅ HOÀN THÀNH 7/7 DONE 2026-05-16

- [X] **fe-component-graph** ★ proof-of-pattern (Stage 2 vertical slice)
- [X] **fe-api-client-graph** (Stage 2.1 — RQ hooks + Refit + raw fetch)
- [X] **fe-permission-graph** (Stage 2.1 — PermissionGate/usePermission/Can/hasPermission/authorize)
- [X] **fe-route-graph** (Stage 2.1 — Next.js App Router page/layout/middleware + dynamic/protected)
- [X] **be-domain-graph** ★ Stage 2.2 vertical slice — DDD AggregateRoot/Entity/ValueObject/DomainEvent/Handler/Spec/Repo (smoke-tested EUREKA: 944 nodes / 1338 edges / 18 modules)
- [X] **be-db-schema-graph** (Stage 2.2 close — EF Core ModelSnapshot parser, smoke-tested EUREKA: 1249 tables / 13827 columns / 2121 indexes)
- [X] **be-cqrs-graph** (Stage 2.2 close — MediatR + FluentValidation parser, smoke-tested EUREKA: 3260 nodes / 2698 edges / 18 modules, coverage indicators reqs_no_handler=33)
- [X] Update phase2-discovery.md (Steps 2.8b/c/d/e/**f/g/h** + POST-GATE plugin_files[**7**] + error codes E130-E135 lane-side fallback, **E133/E134/E135 marked IMPLEMENTED**)

### Stage 3 — SSOT Files (9 files) ✅ HOÀN THÀNH 2026-05-16

- [X] **ui-interactivity-spec.json** (template ready)
- [X] ux-conventions.json
- [X] mdm-canonical-entities.json
- [X] compliance-mapping.json
- [X] rbac-permission-catalog.json
- [X] workflow-state-machines.json
- [X] audit-critical-entities.json
- [X] error-code-catalog.json
- [X] print-export-templates.json

### Stage 4 — 18 Lanes

- [⏳] **CD11, CD13, CD15, CD18** (sub-stage 4.1) — design canon ✅ DONE 2026-05-16 (agent-prompt.md §19-22), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{11,13,15,18}.md, 1462 dòng total, 6/6 gates PASS), integration test với EUREKA fixture pending (cần stakeholder populate `rbac-permission-catalog.json` cho CD15)
- [⏳] **CD16, CD17** (sub-stage 4.2) — design canon ✅ DONE 2026-05-16 (agent-prompt.md §23-24), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{16,17}.md, ~720 dòng total, 5/5 audit gates PASS), **integration test với EUREKA-2026 real fixtures ✅ DONE 2026-05-16** (CD16 PRE-GATE T1-T4 PASS với 944 nodes/1338 edges/18 modules; CD17 PRE-GATE T1-T4 PASS với 1249 tables/13827 cols/2121 indexes), known limitations documented (CD16: references_entity edges=0 v1.0 parser limitation; CD17: FK extraction=0 + last_migration empty v1.0 limitations)
- [⏳] **CD23, CD24, CD25, CD26** (sub-stage 4.3) — design canon ✅ DONE 2026-05-16 (agent-prompt.md §25-28), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{23,24,25,26}.md, 1625 dòng total, 5/5 gates PASS), integration test với EUREKA fixture pending (cần stakeholder populate `ux-conventions.json` mandatory cho CD23/24/25 + `workflow-state-machines.json` mandatory cho CD26)
- [⏳] **CD28, CD30, CD31** (sub-stage 4.4) ★★★ — design canon scaffold ✅ DONE 2026-05-16 (agent-prompt.md §16-18), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{28,30,31}.md, 1204 dòng total, 5/5 gates PASS), integration test với EUREKA fixture pending (cần stakeholder populate SSOTs)
- [⏳] **CD29, CD37** (sub-stage 4.5) — design canon ✅ DONE 2026-05-16 (agent-prompt.md §29-30), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{29,37}.md, 833 dòng total, 5/5 gates PASS), integration test với EUREKA fixture pending (~6 ngày, cần stakeholder populate 2 SSOTs: audit-critical-entities.json + compliance-mapping.json — cả 2 mandatory)
- [⏳] **CD38, CD39, CD40** (sub-stage 4.6) ★ NEW — design canon scaffold ✅ DONE 2026-05-16 (agent-prompt.md §13-15), **lane procedure files ✅ DONE 2026-05-16** (procedures/lanes/CD{38,39,40}.md, 1260 dòng total, 5/5 gates PASS), integration test với EUREKA fixture pending (~6 ngày, cần stakeholder populate 3 SSOTs: ui-interactivity-spec mandatory + error-code-catalog + print-export-templates)

### Stage 5 — Dispatcher ✅ HOÀN THÀNH 2026-05-16

- [X] 3-wave dispatch script (`wave-coordinator.sh` 394 dòng, 5 subcommands init/start/end/status/gate-check)
- [X] Wave gate validation (W1+W2 fail_threshold=3, W3 fail_threshold=2, exit codes 0/1/2 → E120/E121/E122/E123)
- [X] Per-lane timeout (đã có sẵn Step 4.6, MCV3_CMI_LANE_TIMEOUT_SEC=180)
- [X] NEW Template `wave-status.json` (schema `wave-status-v1`, 73 dòng, idempotent state tracking)

### Stage 6 — Aggregator ✅ HOÀN THÀNH 2026-05-16

- [X] 26-dim aggregator (`procedures/phase5-aggregate.md` Step 5.1-5.8 — load 26 lanes, dedup, dim group/wave fields)
- [X] Coverage matrix v2 schema (`templates/coverage-matrix.json` — `coverage-matrix-v2`, 35 dim entries baseline)
- [X] SKIPPED marker logic (9 baseline: CD8/CD10/CD12/CD14/CD19/CD20/CD21/CD22/CD27 với `status='SKIPPED'`, `coverage_pct=null`, `reason`, `reactivate_in`)
- [X] Threshold check v2 (quick=60 / standard=80 / deep=95 / exhaustive=100 — đồng bộ `_contract.json.profile_activation`)
- [X] CDG E090 escalate khi `BELOW_COUNT > 0` (AskUser accept/generate/cancel; `--ci` auto-accept)
- [X] E005 early exit khi 0 violations + 100% coverage (jump Phase 8, skip Phase 6-7)
- [X] `wave_breakdown{wave1,wave2,wave3}` per-wave overall_pct (NEW v2)
- [X] **Template ↔ procedure sync fixes (2026-05-16):**
  - `templates/coverage-report.md` rewrite — `[DIM_TABLE]` placeholder cho 26 dims grouped, ≤20 dòng v2 relaxed (procedure inject grouped layout qua awk)
  - `templates/Phase5-report.md` align — placeholders khớp procedure Step 5.8 sed (`[STATUS]/[TIMESTAMP]/[OVERALL_PCT]/[OVERALL_STATUS]/[BELOW_COUNT]/[TOTAL_SIGNALS]/[CDG_NOTE]`)
  - `procedures/phase5-aggregate.md` Step 5.6 + POST-GATE T4 + E056 line-count sync (15 → 20 v2 relaxed)
  - POST-GATE T4 thêm `wave_breakdown=3 entries` validation

**Smoke test (2026-05-16):**
- Mock matrix với 8 active dims (CD1, CD2, CD11, CD16, CD17, CD18, CD28, CD9) → wave_breakdown computation đúng: W1=88.7% (5 lanes), W2=92.5% (2 lanes), W3=70% (1 lane), overall=87.3%, below_count=2, E005 không trigger (1 violation)
- Template populate test: coverage-report.md output 19 dòng (≤20 ✓), Phase5-report.md output 13 dòng (≤15 ✓), 0 leftover placeholders cả 2

**Gate:** ✅ 5/5 PASS
- skill-compliance-audit: 12/12 CRITICAL + 13/13 REQUIRED + 5/5 CONDITIONAL = PASS
- validate-schema-sync: 1/1 PASS, 28 procedure refs valid, templates exist
- Template structure: 35 dims + 9 SKIPPED + wave_breakdown 3 entries + 0 CD32-CD36 (skeleton excluded) + 9 groups
- jq wave_breakdown computation logic verified với mock data
- 0 leftover placeholders sau template populate

### Stage 7 — Reports ✅ HOÀN THÀNH 2026-05-16

- [X] Report template 26-dim grouped (Stage 1 partial + Stage 7 top 10 violations placeholder)
- [X] Group by nhóm (7 sections: Core/FE/BE/UX/Logistics★★★/Compliance★★★/Implementation★)
- [X] integrity-impact.json v2 (schema bump + 5 v2 fields mới + backward-compat all v1 fields preserved)
- [X] phase8-report.md Step 8.3 + Step 8.4 + POST-GATE T2/T3 v2 rewrite
- [X] _contract.json produces_for v1→v2 (4 consumers) + NEW produces_for_schema_compat backward-compat contract
- [X] 5/5 gates PASS — compliance audit + schema sync + smoke test (max bound 52≤55, 0 leftover) + backward-compat verify + SKILL.md ≤500

### Stage 8 — Tests ✅ HOÀN THÀNH 2026-05-16

- [X] **8 new eval test cases TC-cmi-006 → TC-cmi-013** added vào `evals/evals.json` (13 tổng):
  - TC-cmi-006: Wave 1 dispatch subset (CD11+CD16+CD17), Wave 2/3 SKIPPED
  - TC-cmi-007: SSOT mandatory missing (CD15 needs rbac-permission-catalog) → ESCALATE E144
  - TC-cmi-008: Full 26 lanes 3-wave dispatch deep profile (~55-90 min)
  - TC-cmi-009: Logistics-critical CD28+CD30+CD31 ★★★ (multi-currency VND/CNY/USD)
  - TC-cmi-010: Compliance CD29+CD37 (PII VN-PDPL + cross-border CN→VN)
  - TC-cmi-011: NEW additions CD38+CD39+CD40 (UI/Error/Print VN+CN+EN)
  - TC-cmi-012: integrity-impact.json v2 backward-compat (v1 reader reads v2)
  - TC-cmi-013: --status read-only query (no agent spawn, no lock)
  - Update `evals/README.md` với new table v1 + v2 cases
- [ ] EUREKA real dry-run — pending stakeholder populate 7 mandatory SSOTs
- [X] **Audit scripts pass** (3/3):
  - `skill-compliance-audit.sh wf-cmi` → GRADE PASS (12/12 CRITICAL + 13/13 REQUIRED + 5/5 CONDITIONAL)
  - `validate-schema-sync.sh wf-cmi` → 1/1 PASS (28 procedure paths verified)
  - `check-skill-design-populated.sh docs/04-skill-design/wf-cmi/` → PASS (11 files OK)
- [X] **Performance test methodology documented** trong `v2-migration-notes.md` §5.1 CI timeout adjustment. Actual ≤90 min benchmark needs EUREKA real dispatch (pending stakeholder SSOTs).
- [X] **3 profile smoke test PASS** (quick/standard/deep) qua wave-coordinator dry-run:
  - QUICK (7 lanes Wave 1 only): overall PASS, Wave 2/3 SKIPPED via NONE token
  - STANDARD (14 lanes W1+W2+W3 subset): overall PASS (Wave 1=10 + Wave 2=3 + Wave 3=1)
  - DEEP (26 lanes full 3-wave): overall PASS (Wave 1=10 + Wave 2=10 + Wave 3=6)

### Stage 9 — Ship ✅ HOÀN THÀNH 2026-05-16 (docs only, KHÔNG commit/PR)

- [X] **CHANGELOG.md** — wf-cmi v2.0.0 entry mới (>200 dòng) với 5 sections: Quyết định Scope + 18 Lanes mới + 7 Graphs + 9 SSOT templates + Dispatcher 3-wave + Aggregator v2 + Reports v2 + Skill architecture compliance + Testing + Migration notes + Files touched
- [X] **CLAUDE.md** — wf-cmi entry refresh từ v1.0 → v2.0 (line 93 workflow skills section + line 219 standalone skills catalog row)
- [X] **docs/01-architecture/07-skills-catalog.md** — wf-cmi v2.0 catalog row (line 148 + line 195 v2.0 quick reference)
- [X] **docs/04-skill-design/wf-cmi/05-execution-profiles.md** — profile v2 activation refresh: §1 overview với 26 lanes deep + §2 phase activation matrix + §3 expanded lane activation matrix 35 entries (10 Wave 1 + 10 Wave 2 + 6 Wave 3 + 9 SKIPPED + 5 SKELETON) + NEW §11 Wave Dispatch Strategy (~50 dòng)
- [X] **docs/06-user-guides/per-skill/wf-cmi-v2-guide.md** (NEW, ~360 dòng) — End-user guide tiếng Việt với 15 sections + FAQ
- [X] **docs/04-skill-design/wf-cmi/v2-migration-notes.md** (NEW, ~280 dòng) — Migration guide v1→v2 với 10 sections: tóm tắt thay đổi + 4 quyết định kiến trúc chính + migration cho consumer skills/stakeholder/CI/CD/user CLI + known limitations + v2.1 roadmap
- [ ] **PR** — KHÔNG tạo PR per user decision (chỉ edit files, không commit)

---

## 8. Dependencies & Blockers

| Dependency                                                                                  | Blocker?                  | Mitigation                                      |
| ------------------------------------------------------------------------------------------- | ------------------------- | ----------------------------------------------- |
| EUREKA-2026 SSOT files (9 files) cần stakeholder input                                     | ✅ Có thể block Stage 4 | Start collecting input ngay Tuần 1             |
| Cần thêm domain expert agents (compliance-expert, legal-expert, finance-expert đã có?) | ⚠ Verify                 | Check `.claude/agents/business/`              |
| EF Core 10 reverse-engineering tool cho be-db-schema-graph                                  | ⚠ Có sẵn?              | Có thể dùng `dotnet ef dbcontext scaffold` |
| GitNexus index EUREKA-2026                                                                  | ⚠ Cần verify            | Run `npx gitnexus analyze` ở EUREKA          |
| Serena index EUREKA-2026                                                                    | ⚠ Cần verify            | Activate project Serena                         |

---

## 9. Risk Assessment

| Risk                                            | Probability | Impact | Mitigation                                               |
| ----------------------------------------------- | ----------- | ------ | -------------------------------------------------------- |
| 9 SSOT files chưa có → block Stage 4 lanes   | Cao         | Cao    | Stage 3 song song Stage 2, start Tuần 2                 |
| 18 lanes effort > 60 ngày                      | Trung       | Trung  | Parallel team (3-4 dev), hoặc spread 12 tuần           |
| Context budget overflow khi 26 lanes parallel   | Trung       | Cao    | 3-wave dispatch (đã design), max 10 concurrent         |
| Performance > 90 min làm user frustrate        | Thấp       | Trung  | Profile activation flexible,`--dims=` cho phép subset |
| Breaking change v1 → v2 (artifact schema bump) | Cao         | Trung  | Document migration notes + backward-compat đọc v1      |
| SSOT EUREKA stakeholders bận                   | Cao         | Cao    | Có template default, populate dần                      |

---

## 10. Next Step

**Đã hoàn thành (2026-05-16):**

1. ✅ Stage 1 — Foundation Refactor (7/7 gates PASS)
2. ✅ Stage 3 — 9 SSOT files (8 mới + 1 cũ, ~4500 lines, all JSON valid)
3. ✅ Stage 2 Vertical Slice — fe-component-graph proof-of-pattern (1/7 graphs, 6/6 gates PASS, smoke-tested)
4. ✅ **Stage 2.1 FE plugin set** — fe-api-client + fe-permission + fe-route (3/7 graphs, 8/8 gates PASS, smoke-tested với real fixtures + MSYS path conv workaround)
5. ✅ **Stage 2.2 BE plugin vertical slice** — be-domain-graph (5/7 graphs total, 8/8 gates PASS, smoke-tested với EUREKA-2026: 944 DDD types, 1338 edges, 18 modules)
6. ✅ **Stage 2.2 BE plugin set CLOSE** — be-db-schema-graph (1249 tables/13827 cols/2121 indexes) + be-cqrs-graph (3260 nodes/2698 edges/18 modules + coverage indicators) **(7/7 graphs DONE — Stage 2 HOÀN TOÀN ĐÓNG, 8/8 gates PASS)**
7. ✅ **Stage 4 sub-stage 4.6 design canon scaffold** — CD38/CD39/CD40 (agent-prompt.md §13-15, audit PASS)
8. ✅ **Stage 4 sub-stage 4.4 design canon scaffold** — CD28/CD30/CD31 (agent-prompt.md §16-18 logistics-critical Wave 2, 23 signal kinds, errors E141-E143, audit PASS)
9. ✅ **Stage 4 sub-stage 4.4 lane procedure files DONE 3/3** — procedures/lanes/CD28.md (375 dòng MDM Consistency) + CD30.md (397 dòng Time & Numbering) + CD31.md (432 dòng Money & Tax, 2 SSOTs) với 8 sections §A-§H, PRE-GATE T1-T4, Steps 9-10 atomic write, POST-GATE rule_id format + fingerprint dedup. phase4-coverage-dispatch.md updated với lane procedure callout note. _contract.json bump `.procedure[]` 10→13 + lanes_defined refined cho 3 lanes. 5/5 gates PASS.
10. ✅ **Stage 4 sub-stage 4.1 lane procedure files DONE 4/4 (2026-05-16)** — design canon agent-prompt.md §19-22 add cho CD11/CD13/CD15/CD18 (+388 dòng, renumber §19-22 cũ → §23-26). procedures/lanes/CD11.md (354 dòng FE Component Contracts, no SSOT) + CD13.md (372 dòng FE↔BE Contract Sync, 2 graphs) + CD15.md (363 dòng UI Permission Mirror, SSOT-dependent `rbac-permission-catalog.json`) + CD18.md (373 dòng CQRS Pipeline Integrity, 2 graphs + preprocessed coverage_indicators). 8 sections §A-§H mỗi file. 20 signal kinds total. phase4-coverage-dispatch.md update LANE_SIGNAL_KINDS_MAP + lane procedure status table + spawn callout mapping. _contract.json bump `.procedure[]` 13→17 + lanes_defined refined với procedure_file/signal_kinds/graph_dependencies/ssot_dependency/stage_4_status. **6/6 gates PASS**.
11. ✅ **Stage 4 sub-stage 4.6 lane procedure files DONE 3/3 (2026-05-16)** — procedures/lanes/CD38.md (400 dòng UI Implementation Coverage, 4 graphs + SSOT `ui-interactivity-spec.json` MANDATORY E144) + CD39.md (416 dòng Error UX & Recovery, 2 graphs + SSOT `error-code-catalog.json` OPTIONAL E147 fallback Grep) + CD40.md (444 dòng Print & Export Consistency, 3 graphs + SSOT `print-export-templates.json` OPTIONAL E148 fallback filesystem, logistics document-heavy: TT 78/2021 e-invoice VN + VNACCS customs + BOL VN+EN+CN). 8 sections §A-§H mỗi file. 15 signal kinds total (UI-CD38-NNN/ERR-CD39-NNN/DOC-CD40-NNN). phase4-coverage-dispatch.md update Wave 3 lane table + status table CD38-40 → ✅ + spawn callout (CD38→§13, CD39→§14, CD40→§15). _contract.json bump `.procedure[]` 17→20 + 3 lanes refined với `graph_dependency: null` + `graph_dependencies[]` + `procedure_file` + `stage_4_status` + `ssot_optional: true` cho CD39/CD40. **5/5 gates PASS** (compliance audit GRADE PASS 12+13+5, schema sync 1/1 PASS, SKILL.md 487 dòng ≤500 CORE-032, JSON valid, 20 procedure paths verified on disk).
12. ✅ **Stage 4 sub-stage 4.2 lane procedure files DONE 2/2 (2026-05-16)** — design canon agent-prompt.md §23-24 add cho CD16/CD17 (renumber §23-26 cũ → §25-28). procedures/lanes/CD16.md + CD17.md (BE deep lanes, DDD aggregates + persistence consistency cross-ref).
13. ✅ **NEW Stage 4 sub-stage 4.3 lane procedure files DONE 4/4 (2026-05-16)** — design canon agent-prompt.md §25-28 add cho CD23/CD24/CD25/CD26 (+458 dòng total 2233, renumber §25-28 cũ → §29-32). procedures/lanes/CD23.md (387 dòng UX Design System, SSOT ux-conventions mandatory, COLOR_HARDCODED severity MUST brand-guardian gate) + CD24.md (388 dòng UX Display Format, SSOT ux-conventions mandatory, VND_DECIMAL_PRESENT severity HIGH TT 78/2021/TT-BTC compliance gate) + CD25.md (413 dòng UX Flow Continuity, SSOT ux-conventions mandatory + 2 graphs fe-route+fe-component, BROKEN_USER_JOURNEY + MISSING_CONFIRMATION_DIALOG severity MUST safety gate) + CD26.md (437 dòng UX Workflow Visibility ★★★ logistics-aware, SSOT workflow-state-machines mandatory + ux-conventions secondary + 3 graphs fe-component/fe-route/be-domain, PROGRESS_HIDDEN logistics-critical HIGH cho Booking/CustomsDeclaration/Invoice). 8 sections §A-§H mỗi file. 20 signal kinds total (UXDS-CD23-NNN/UXFMT-CD24-NNN/UXFLOW-CD25-NNN/UXWFV-CD26-NNN). phase4-coverage-dispatch.md update LANE_SIGNAL_KINDS_MAP CD23-26 + lane procedure status table CD23-26 → ✅ + spawn callout mapping (CD23→§25, CD24→§26, CD25→§27, CD26→§28). _contract.json bump `.procedure[]` 22→26 + 4 lanes refined với procedure_file/expected_signal_kinds_5/graph_dependencies (1/1/2/3 graphs)/ssot_dependency/stage_4_status + CD24 compliance_refs[] + CD26 logistics_critical_entities[]. **5/5 gates PASS** (compliance audit GRADE PASS 12+13+5, schema sync 1/1 PASS, SKILL.md 487 dòng ≤500 CORE-032, JSON valid, 26 procedure paths verified on disk).
14. ✅ **NEW Stage 4 sub-stage 4.5 lane procedure files DONE 2/2 (2026-05-16)** — design canon agent-prompt.md §29-30 add cho CD29/CD37 (+224 dòng total 2457, renumber §29-32 cũ → §31-34). procedures/lanes/CD29.md (398 dòng Audit Trail Completeness, SSOT audit-critical-entities mandatory, 4 graphs be-db-schema+be-domain+be-cqrs+api, 5 kinds AUDIT-CD29-001..005 với PII_READ_NOT_LOGGED severity MUST VN-PDPL Điều 6) + CD37.md (435 dòng Regulatory Compliance ★★★ compliance-critical, SSOT compliance-mapping mandatory 3 jurisdictions VN+CN+intl, 4 graphs, 5 kinds COMP-CD37-001..005 với REGULATORY_RULE_VIOLATION + PERSONAL_DATA_UNGOVERNED + CROSS_BORDER_COMPLIANCE_GAP severity MUST, jurisdiction_breakdown metadata VN/CN/intl, regulatory refs 5 VN + 3 CN + 3 intl, cross-lane note CD29 call-site vs CD37 structural existence — complementary KHÔNG duplicate). 8 sections §A-§H mỗi file. 10 signal kinds total. phase4-coverage-dispatch.md update LANE_SIGNAL_KINDS_MAP CD29-37 + lane procedure status table CD29/37 → ✅ DONE + spawn callout mapping (CD29→§29, CD37→§30) + "Sub-stage 4 COMPLETE 18/18 lanes" footer. _contract.json bump `.procedure[]` 26→28 + 2 lanes refined với procedure_file/expected_signal_kinds_5/graph_dependencies_4/ssot_optional_false/stage_4_status + CD29 compliance_refs (VN-PDPL/TT78/GDPR/ISO27001/SOC2) + CD37 compliance_refs (5 VN + 3 CN + 3 intl) + CD37 logistics_critical_entities + CD37 cross_lane_overlap_note. **5/5 gates PASS** (compliance audit GRADE PASS 12+13+5, schema sync 1/1 PASS, SKILL.md 487 dòng ≤500 CORE-032, JSON valid, 28 procedure paths verified on disk). **🎯 STAGE 4 ĐÓNG HOÀN TOÀN 18/18 lanes!**
15. ✅ `prompt-update.md`, `progress-update.md`, `ui-interactivity-spec.eureka-template.json`
16. ✅ **Stage 5 Dispatcher refinement DONE (2026-05-16)** — `templates/wave-status.json` (NEW, 73 dòng, schema wave-status-v1) + `.claude/scripts/wf-cmi/wave-coordinator.sh` (NEW, 394 dòng, 5 subcommands init/start/end/status/gate-check, exit codes 0/1/2 maps E120/121/122/123) + `procedures/phase4-coverage-dispatch.md` MODIFIED Step 4.2 init wire + Step 4.5 pseudocode replace inline bash với subcommands + Step 4.6 note + §G refs (16 wave-coordinator/wave-status references) + `_contract.json` MODIFIED wave-status template ref + internal_phases.phase4.concurrency note. **8/8 gates PASS** (compliance audit 12+13+5, schema sync 1/1, SKILL.md 487 dòng, JSON valid, bash syntax, 28 procedure paths, template valid). **11/11 smoke scenarios PASS** (init/start/end PASS+PARTIAL_FAIL+FAIL_THRESHOLD W1/W2/W3, status, gate-check, idempotency, SKIPPED W2/W3 → overall PASS quick profile). Key engineering: Git Bash MSYS path-conv safe (`tr -d '\r'` cho jq output), jq dynamic field access (`.["wave_" + ($w | tostring)]` thay vì interpolation), atomic write `.tmp.$$` → jq parse → mv, idempotent total computation từ sum wave_X subfields, CORE-035 path align `phase4-coverage/wave-status.json`.

**Còn lại trong v2.0 expansion:**

### Stage 4 — 18 Lane Procedures (Tuần 4-9, ~60 ngày total, ~8 ngày còn lại sau sub-stage 4.5)
- Sub-stage 4.1 (9d): CD11, CD13, CD15, CD18 — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (4/4), integration test pending (~3d, cần stakeholder populate `rbac-permission-catalog.json`)**
- Sub-stage 4.2 (10d): CD16, CD17 — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (2/2), integration test pending (~3d)**
- Sub-stage 4.3 (11d): CD23, CD24, CD25, CD26 — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (4/4, 1625 dòng), integration test pending (~7d, cần stakeholder populate 2 SSOTs: ux-conventions.json + workflow-state-machines.json)**
- Sub-stage 4.4 (13d) ★★★: CD28, CD30, CD31 (logistics-critical) — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (3/3), integration test pending (~6d, cần stakeholder populate SSOTs)**
- Sub-stage 4.5 (8d): CD29, CD37 — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (2/2, 833 dòng), integration test pending (~6d, cần stakeholder populate 2 SSOTs: audit-critical-entities + compliance-mapping)**
- Sub-stage 4.6 (10d) ★ NEW: CD38, CD39, CD40 — **design canon ✅, lane procedure files ✅ DONE 2026-05-16 (3/3), integration test pending (~6d, cần stakeholder populate 3 SSOTs: ui-interactivity-spec mandatory + error-code-catalog + print-export-templates)**

**Sub-stage 4 progress:** ✅ **18/18 lanes có procedure_file (Stage 4 ĐÓNG HOÀN TOÀN 2026-05-16)** — sub-stages 4.1 (CD11/13/15/18) + 4.2 (CD16/17) + 4.3 (CD23/24/25/26) + 4.4 (CD28/30/31) + 4.5 (CD29/37) + 4.6 (CD38/39/40) ALL DONE. Tổng ~6900 dòng lane procedure files. Integration tests pending sau khi stakeholder populate 7 mandatory SSOTs.

### Stage 5-9 — Dispatcher / Aggregator / Reports / Tests / Ship (Tuần 5-9) — ⏳ Stage 5+6+7 DONE, Stage 8+ READY

**Ưu tiên (Stage 4+5+6 đã đóng hoàn toàn, tập trung Stage 7+):**

- ✅ **Stage 5 Dispatcher (3-wave) DONE 2026-05-16** — `procedures/phase4-coverage-dispatch.md` wired với `.claude/scripts/wf-cmi/wave-coordinator.sh` (394 dòng, 5 subcommands init/start/end/status/gate-check) + `templates/wave-status.json` (schema wave-status-v1). Per-wave gate check (W1+W2 ≥3 fail → E120/E121, W3 ≥2 fail → E122 STOP; 1-2 fail → E123 PARTIAL_FAIL). Wave coordinator bash script idempotent (re-run `end` cùng wave KHÔNG double-count). 11/11 smoke scenarios PASS, 8/8 audit gates PASS.
- ✅ **Stage 6 Aggregator DONE 2026-05-16** — `procedures/phase5-aggregate.md` v2 logic 26 active + 9 SKIPPED markers (CD8/CD10/CD12/CD14/CD19-22/CD27) với `status='SKIPPED'`/`coverage_pct=null`/`reason`/`reactivate_in`. Coverage matrix v2 schema (`coverage-matrix-v2` — 35 dim entries, KHÔNG có CD32-CD36, group/wave/owner_agents per dim + wave_breakdown{wave1,wave2,wave3}). Threshold check per profile (quick≥60% / standard≥80% / deep≥95% / exhaustive=100% — đồng bộ `_contract.json.profile_activation`). CDG E090 escalate khi `BELOW_COUNT > 0` (AskUser accept/generate/cancel; `--ci` auto-accept). E005 early exit khi 0 violations + 100% coverage (jump Phase 8). **Template ↔ procedure sync fixes:** `coverage-report.md` rewrite với `[DIM_TABLE]` placeholder cho 26 dims grouped + ≤20 dòng v2 relaxed; `Phase5-report.md` align placeholders khớp Step 5.8 sed; POST-GATE T4 thêm wave_breakdown=3 entries check + line-count sync 15→20. **5/5 gates PASS** (compliance audit 12+13+5, schema sync 1/1, smoke test: wave_breakdown computation đúng cho 8 mock active dims, 0 leftover placeholders sau template populate).
- ✅ **Stage 7 Reports DONE 2026-05-16** — `templates/integrity-report.md` thay 3 hardcoded violation slots bằng `[TOP_VIOLATIONS_LIST]` placeholder severity-weighted (MUST>HIGH>MEDIUM>LOW), max bound ≤55 dòng (44-48 typical, 52-55 với 10 top violations). `templates/integrity-impact.json` REWRITE FULL bump schema v1→v2 với 5 v2 fields mới (`lanes_v2{active[],skipped[],skeleton[]}` 26+9+5, `wave_breakdown{wave_1,wave_2,wave_3}` per-wave gate_status, `group_breakdown` 7 sections với critical flag cho logistics/compliance, `logistics_critical_signals_count{total,by_lane,must_severity_count}` từ CD28/30/31/37/38/39/40, `schema_version_compat{readable_by:[v1,v2]}` hint) — **GIỮ NGUYÊN ALL v1 fields** backward-compat consumer fallback (verified jq -e check). `procedures/phase8-report.md` Step 8.3 full rewrite (per-group computation + wave summary từ wave-status.json + top 10 severity-weighted với sev_weight MUST=4/HIGH=3/MEDIUM=2/LOW=1 + 50+ placeholders sed), Step 8.4 full rewrite (v2 populate 8 sections jq pipeline merge), POST-GATE T2 v2 required fields check + T3 ≤55 + 0 leftover placeholders, E084 ≤30→≤55, §F E084 desc, §G refs thêm wave-status.json/coverage-matrix.json. `_contract.json` outputs notes ≤55 + cross_skill_contracts.produces_for 4 consumers v1→v2 + NEW `produces_for_schema_compat` backward-compat contract. **5/5 gates PASS** (compliance audit 12+13+5, schema sync 1/1, SKILL.md 487 dòng ≤500, smoke test max bound 52 dòng ≤55 + 0 leftover, backward-compat verify v1 fields preserved).
- **Stage 7 KHÔNG bao gồm consumer wire-up** — wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment chưa có `--from-cmi` flag handler hoặc integrity-impact reader. Separate effort sau Stage 9.
- **Stage 8 Tests** — Integration test EUREKA-2026 dry-run (cần stakeholder populate 7 mandatory SSOTs trước). 8 eval test cases.
- **Stage 9 Ship** — CHANGELOG, CLAUDE.md, skills-catalog, user guide, migration notes v1→v2, PR.

**Câu hỏi đã chốt (2026-05-16):**

- ✅ Scope: 26 lanes (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40)
- ✅ Profile naming: Option A — expand `deep` thành 26 lanes
- ✅ Mobile scope: chỉ scan `erp-web` (mobile defer v2.1)
- ✅ CD32-CD36: Option B — skeleton entries trong v2.0, activate v3.0
- ✅ Timeline: flexible 9 tuần, quality first
- ✅ Agents inventory: 19 agents v2 đã có sẵn (5 business + 5 design + 8 engineering + 1 testing)
- ✅ Stage 1 + Stage 3 đã hoàn thành (uncommitted, chờ user commit)

**Câu hỏi mở cần stakeholder trước Stage 4:**

- ⚠ Review & populate 8 SSOT templates với giá trị thực tế EUREKA-2026 (CRM products, Customs HS codes, RBAC roles, etc.)
- ⚠ Stage 2 vs Stage 4: build graphs trước hay parallel với lanes? (Stage 4 cần graphs)
- ⚠ Có team external nào tham gia Stage 4 không? (60d effort 1 person)

---

## 11. Communication Plan

| Audience            | Channel       | Cadence     | Content                      |
| ------------------- | ------------- | ----------- | ---------------------------- |
| Dev team            | Daily standup | Hàng ngày | Stage progress, blockers     |
| EUREKA stakeholders | Email/Slack   | Tuần 1     | Request SSOT input (9 files) |
| Product manager     | Demo          | Tuần 5     | Phase 4 Wave 1 working       |
| Tech lead           | Review        | Tuần 9     | PR review v2.0               |

---

## 12. References

| File                                                        | Purpose                              |
| ----------------------------------------------------------- | ------------------------------------ |
| `plans/wf-cmi/wf-cmi.md`                                  | Plan gốc từ user                   |
| `plans/wf-cmi/session-prompt.md`                          | v1.0.0 session prompt                |
| `plans/wf-cmi/progress.md`                                | v1.0.0 progress (DONE)               |
| `plans/wf-cmi/prompt-update.md`                           | **v2.0 session prompt (NEW)**  |
| **`plans/wf-cmi/progress-update.md`**               | **File này — v2.0 progress** |
| `plans/wf-cmi/ui-interactivity-spec.eureka-template.json` | **CD38 SSOT template**         |
| `docs/04-skill-design/wf-cmi/`                            | Design canon (14 files)              |
| `.claude/skills/workflow/wf-cmi/SKILL.md`                 | Current SKILL (v1.0)                 |
| `.claude/skills/workflow/wf-cmi/_contract.json`           | Current contract                     |
