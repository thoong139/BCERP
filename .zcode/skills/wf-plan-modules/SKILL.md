---
name: wf-plan-modules
version: 3.3.0
last_updated: 2026-05-05
changelog:
  v3.3.0 (2026-05-05):
    - Quality Improvement (synced với wf-implement-feature v5.1.0):
      * A2.5 Quality Requirements section trong task file template (Security, Data Integrity, i18n, Accessibility, Performance checklists)
      * A2.6 Environment Notes section trong task file template (build tool, framework, CSS, server, database detection)
      * Code Quality Scan trong Phase 1.5 (grep patterns G1-G5 cho COMPLETE_EXISTING features)
      * Domain-Specific Injection trong Phase 7.5 (12 domains: e-commerce, finance, logistics, HR, CRM, healthcare, insurance, real estate, education, manufacturing, procurement, retail)
      * Quality sections auto-computed per module type + interface_type + department
  v3.2.0 (2026-04-26):
    - Multi-Session Parallel Safety (synced voi wf-implement-feature v3.2.0):
      * Cross-Process Registry Mutex: Phase 7 step 7.4-LOCK acquire registry lock truoc khi ghi
        (xem _shared.md §Cross-Process Mutex). Ngan race condition khi user chay parallel sessions.
      * A2.4 Scope Files & Parallel Safety section: BAT BUOC architect POPULATE trong moi task file
        (phase7.5-tasks.md). Liet ke EXCLUSIVE_WRITE/CREATE, SHARED_APPEND/READ files + Parallel-Safe Verdict.
      * parallel-safe-groups.md: Phase 7.5 step 7.5.7 sinh huong dan parallel-safe groups
        (template: .claude/doc-framework/phase5-implementation/parallel-safe-groups.md).
      * Phase 7a check 7a.13: A2.4 Quality Gate (T1-T4 verify section + verdict + groups file).
  v3.1.0 (2026-04-26):
    - A6-EXT Quality Gate: them check 7a.12 trong phase7a-verify.md (T1-T5: section ton tai, Coverage Summary, ≥1 file spec, ≥200 tu, khong placeholder)
    - A6-EXT Structured Template: tao .claude/doc-framework/_meta/a6-ext-fragment.md — architect agent POPULATE thay vi viet tu do
    - Update phase7.5-tasks.md §A6-EXT Generation: architect dọc template TRUOC + self-check checklist 8 items
    - Update _contract.json feature-impl notes: reference a6-ext-fragment.md template + 7a.12 verify
    - Fix path bug: phase2-features/features/ → phase2-features/ (feature-impl.md template + stakeholder-review.md)
    - Khac phuc R1+R2 (A6-EXT chat luong khong dong deu) — bao dam wf-implement-feature `$EXECUTABLE_SPEC` du depth
  v3.0.0 (2026-04-23):
    - ADR-OPT rollout Phase 3.4: Session isolation (ADR-OPT-02), Workload Gate (ADR-OPT-03), Topological Lane Dispatch (ADR-OPT-01), CDG (ADR-OPT-08), Signal Aggregation (ADR-OPT-04)
    - Them phase0.5-workload-gate.md — workload estimation truoc lane dispatch
    - Topological Lane Dispatch: parallel lanes theo topological levels (TOPOLOGICAL_LEVELS)
    - Session isolation: $SESSION_DIR = .mc-data/work/wf-plan-modules/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
    - Signal Aggregation: _shared/aggregate dedup outputs truoc ghi _meta/
    - _contract.json dong bo v3.0.0 (session-scoped outputs, CDG token, lane outputs)
    - Template Usage Rule (CORE-031) enforce cho tat ca output files
  v1.7.1 (2026-04-19):
    - Them phase7.5.0-orphan.md — xu ly orphan modules rieng biet
    - Fix phase7c-summary.md — CORE-028 phase summary format
  v1.7.0 (2026-04-19):
    - Tai cau truc procedures/ thanh 16 phase files + _shared.md
    - Them Topological Lane Dispatch (phase4), LEGACY detection, system coverage map
description: |
  Phân tích Dependency Graph giữa các modules và xác định thứ tự implement tối ưu.
  Tạo Phase 5 Implementation Roadmap và Sprint Plans.
  v3.0.0: Session isolation per run, Workload Gate, Topological Lane Dispatch parallel theo dependency levels.

  TRIGGER khi:
  - Dự án có nhiều modules và cần xác định thứ tự implement
  - User hỏi "bắt đầu từ đâu", "module nào trước", "thứ tự implement"
  - Keywords: "kế hoạch module", "plan modules", "dependency analysis", "implementation order"
  - Sau khi hoàn thành /wf-analyze-requirements hoặc /wf-design

  LUÔN trigger khi user cần lên kế hoạch implement nhiều modules — dù không dùng
  từ "plan-modules". Đây là bước chuyển từ requirements/design sang coding.

  KHÔNG trigger khi:
  - Chưa có requirements → dùng /wf-analyze-requirements trước

argument-hint: "[--graph] [--mvp] [--impact=<module>] [--skip-sprints] [--status] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /wf-plan-modules: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Xây dựng dependency graph, xếp modules thành layers, tạo Phase 5 roadmap + sprint plans + task files |
| **Prerequisites** | `.mc-data/docs/_meta/req-registry.json` (có ít nhất 1 module) |
| **Workflow position** | `/wf-design-ux` (or `/wf-design` if API-only) → **/wf-plan-modules** ← YOU ARE HERE → `/wf-implement-feature` |
| **Output** | `module-plan.md` + `dependency-graph.md` + `P5-00-implementation-roadmap.md` + `sprints/` + `tasks/` + `stakeholder-review.md` |
| **Phases** | 0 → 0.5 → 1 → 1.7 → [1.5 LEGACY] → 2 → 3 → 4 → [5 MVP] → [6 IMPACT] → 7 → [7.5.0 ORPHAN] → 7.5 → 7a → 7b → 7c |

## Arguments

| Flag | Mô tả |
|------|-------|
| `--graph` | Chỉ xuất dependency graph diagram, không tạo roadmap |
| `--mvp` | Xác định MVP scope với minimal modules (chạy Phase 5) |
| `--impact=<module>` | Phân tích impact khi thay đổi module cụ thể (chạy Phase 6) |
| `--skip-sprints` | Bỏ qua tạo sprint plans |
| `--status` | Hiển thị trạng thái hiện tại từ planmod-status.json |
| `--resume` | Resume từ checkpoint, tiếp tục phase đang dở |

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` directory (internal) hoặc `doc-framework/` (output docs)
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> Áp dụng cho:
> - **Internal templates** (5 files): `templates/planmod-status.json`, `templates/planmod-plan.md`, `templates/checkpoint.json`, `templates/orphan-no-features.md.tpl`, `templates/implementation-strategy.md.tpl`
> - **doc-framework templates** (5 files): `dependency-graph.md`, `P5-00-implementation-roadmap.md`, `S01-sprint-template.md`, `feature-impl.md`, `stakeholder-review.md`
> - **shared-protocols templates**: `phase-summary.template.md` (§14)

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention), Protocol 7 (PAR), Protocol 8 (CQG-10), Protocol 9 (PLN), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Fix Rules, Cross-Phase Data Flow, Implementation Order Schema.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 7a, 7b): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90%
- **Stakeholder Review** (Phase 7b): SO-01/02/03 với parallel agents
- **Token Limit Prevention** (Phase 2, 7, 7b): xem `_shared.md` §Token Limit Prevention
- **Registry Safe-Write** (Phase 7): CHỈ update field `implementation_order` + `impl_status` (cho DEPRECATED only)
- **Parallel Execution** (Phase 2, 7.5): Batch PARALLEL per module/system
- **Content Quality Gate** (Phase 7a): Verify implementation_order completeness + orphan check + inter-phase consistency

## Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Đọc features từ nhiều modules | **PARALLEL** (Phase 2) |
| Dependency analysis, topological sort | **SEQUENTIAL** (Phase 3-4) |
| Impact analysis, MVP scope | **SEQUENTIAL** (Phase 5-6) |
| Tạo task files theo system | **PARALLEL** (Phase 7.5) |
| Stakeholder Review — `architect` + `qa-lead` (+ optional domain expert) | **PARALLEL** (Phase 7b) |

**Agent Invocation:** Phases 0–7a xử lý trực tiếp (không spawn agent). Chỉ Phase 7.5 và Phase 7b spawn agents:
- Phase 7.5: spawn `architect` per feature để generate A6-EXT + A7-EXT
- Phase 7b: spawn `architect` + `qa-lead` (+ optional 1 domain expert) để review

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

## Work Directory

```
.mc-data/work/wf-plan-modules/
├── planmod-status.json
├── planmod-plan.md
├── checkpoint.json
└── phase-summary.md
```

Templates: `.claude/skills/workflow/wf-plan-modules/templates/`

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

> Phát hiện project type và inject context phù hợp.
> LEGACY_MODE detection theo CORE-021: check `project-context.md` (> 500 bytes).

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. SEVERE (>20 behind) → warning: "Dependency analysis may miss recent module changes." | Freshness status set |

### CI-ROUTE: Dependency Analysis (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus impact + clusters de tu dong map cross-module dependencies.
> **Graceful:** CI unavailable → fallback manual analysis (current behavior, zero regression).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `impact_analysis` | **GitNexus** `impact({module_entry}, upstream, depth=2)` | Manual | Tu dong map cross-module dependencies |
| `project_structure` | **GitNexus** `clusters` / **Serena** `get_symbols_overview` | Glob | Module grouping + per-module symbols |

> **Freshness caveat:** Neu index behind > 0 → "Results based on index N commits behind HEAD."

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Detect LEGACY_MODE: `test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes` → set `$PROJECT_TYPE = LEGACY` | `$LEGACY_MODE` set |
| 0.2 | Kiểm tra prerequisites (CORE-011 forensic): (a) `jq -e '.modules | length > 0' req-registry.json`, (b) `test -f P3-01-architecture.md`, (c) ít nhất 1 `.md` trong `phase2-features/` — FAIL bất kỳ → STOP với hướng dẫn chạy skill còn thiếu | Tất cả 3 pass |
| 0.3 | Routing: Read `procedures/phase0-init.md` (Phase 0 detail + parse args + digest loading) | Phase 0 procedure loaded |

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/wf-plan-modules/checkpoint.json:
    → Read procedures/phase0-init.md §Resume Logic
    → Jump tới phase trong checkpoint.position.current_phase (xem §Phase Routing Map)
  ELSE:
    → STOP: "Không tìm thấy checkpoint. Chạy /wf-plan-modules từ đầu."
```

**Đặc biệt — `--status` handler:**

```
IF $ARGUMENTS chứa "--status":
  IF test -f .mc-data/work/wf-plan-modules/planmod-status.json:
    → Read procedures/phase0-init.md §--status handler
  ELSE:
    → "Chưa có wf-plan-modules session nào."
    → STOP
```

---

## Phase 1–7c: Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-init.md` | Always | Init working files, parse args, LEGACY detect, digest load |
| **0.5** | `procedures/phase0.5-workload-gate.md` | Always | Workload Gate (ADR-OPT-03): DAG preview → estimate → gate decision |
| **1** | `procedures/phase1-validate.md` | Always | Registry validation + Phase 1.7 Upstream Coverage |
| **1.5** | `procedures/phase1.5-legacy-impl.md` | `$LEGACY_MODE = true` | Feature-Level Code Status (CORE-019) |
| **2** | `procedures/phase2-deps.md` | `$MODULE_COUNT >= 3` (skip cho 1-2) | Thu thập Dependencies (PARALLEL) |
| **3** | `procedures/phase3-cycles.md` | `$MODULE_COUNT >= 3` | Phát hiện Circular Dependencies |
| **4** | `procedures/phase4-topo.md` | Always | Topological Sorting → `$LAYERS` |
| **5** | `procedures/phase5-mvp.md` | `--mvp` flag | MVP Scope Analysis |
| **6** | `procedures/phase6-impact.md` | `--impact=<module>` flag | Impact Analysis |
| **7** | `procedures/phase7-outputs.md` | Always | Tạo module-plan, dep-graph, roadmap, sprints + update registry. **Note:** CDG-03/CDG-04 (DEPRECATED downgrade `done→skipped`) được trigger tại §Registry Update step 3c trong phase7-outputs.md — không phải phase riêng. CDG tokens ghi vào `cdg-tokens.json` (xem _contract.json). |
| **7.5.0** | `procedures/phase7.5.0-orphan.md` | `$COVERAGE_STRATEGY == "placeholders"` | Orphan System Placeholders |
| **7.5** | `procedures/phase7.5-tasks.md` | Always | Task files + A6-EXT + A7-EXT |
| **7a** | `procedures/phase7a-verify.md` | Always | Output Verification (Auto-Correction Loop, 12 checks) |
| **7b** | `procedures/phase7b-review.md` | Always | Stakeholder Review (PARALLEL agents) |
| **7c** | `procedures/phase7c-summary.md` | Always | Phase Summary + Session Close |

**Routing flow:**

```
SKILL.md Phase 0 → Read procedures/phase0-init.md → execute → return → SKILL.md Phase 0.5
   ↓
SKILL.md Phase 0.5 → Read procedures/phase0.5-workload-gate.md → execute → return → SKILL.md Phase 1
   ↓
SKILL.md Phase 1 → Read procedures/phase1-validate.md → execute → return → SKILL.md Phase 1.5/2
   ↓
... (tiếp tục theo Phase Routing Map)
   ↓
SKILL.md Phase 7c → Read procedures/phase7c-summary.md → execute → return → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file có thể tham chiếu `procedures/_shared.md` cho cross-cutting protocols (state vars, fix rules).

---

## Output Files

| File | Đường dẫn | Phase | Template |
|------|-----------|-------|---------|
| Status file | `.mc-data/work/wf-plan-modules/planmod-status.json` | 0 | `templates/planmod-status.json` |
| Module plan | `.mc-data/docs/phase5-implementation/module-plan.md` | 7 | — (CORE-031 exception: inline từ LAYERS data) |
| Dependency graph | `.mc-data/docs/phase5-implementation/dependency-graph.md` | 7 | `doc-framework/_meta/dependency-graph.md` |
| Implementation roadmap | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | 7 | `doc-framework/phase5-implementation/P5-00-implementation-roadmap.md` |
| Sprint plans | `.mc-data/docs/phase5-implementation/sprints/S[NN]-[name].md` | 7 | `doc-framework/phase5-implementation/sprints/S01-sprint-template.md` |
| Sprint index | `.mc-data/docs/phase5-implementation/sprints/_index.md` | 7 | `doc-framework/phase5-implementation/sprints/_index.md` |
| Orphan placeholder | `.mc-data/docs/phase5-implementation/tasks/[sys-slug]/_NO-FEATURES.md` | 7.5.0 | `templates/orphan-no-features.md.tpl` |
| Impl task files | `.mc-data/docs/phase5-implementation/tasks/[sys-slug]/[mod-slug]/[feat-slug]-impl.md` | 7.5 | `doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md` |
| Stakeholder review | `.mc-data/docs/phase5-implementation/stakeholder-review.md` | 7b | `doc-framework/phase5-implementation/stakeholder-review.md` |
| Phase summary | `.mc-data/work/wf-plan-modules/phase-summary.md` | 7c | `doc-framework/_meta/phase-summary.template.md` |

### Working Files

| File | Path | Mô tả |
|------|------|-------|
| planmod-status.json | `.mc-data/work/wf-plan-modules/` | Trạng thái chi tiết |
| planmod-plan.md | `.mc-data/work/wf-plan-modules/` | Execution plan |
| checkpoint.json | `.mc-data/work/wf-plan-modules/` | Checkpoint cho resume |
| phase-summary.md | `.mc-data/work/wf-plan-modules/` | Tóm tắt kết quả skill — CORE-028 |

### Output Report (sample)

```markdown
## Module Implementation Plan

### Dependency Graph
graph TD
    Settings --> CRM
    Settings --> HR
    CRM --> Orders

### Implementation Order
| Phase | Layer | Modules | Parallel? |
|-------|-------|---------|-----------|
| 1 | Foundation | Settings, SharedKernel | Yes |
| 2 | Core | CRM, HR | Yes |
| 3 | Business | Orders, Payroll | Yes |

**MVP Scope (nếu có):** Settings → CRM → Orders (3 modules)

### System Coverage
| System | Modules | Features | Status |
|--------|---------|----------|--------|
| SYS-BACKEND | 13 | 38 | ✅ COVERED |
| SYS-WEB-CUSTOMER | 1 | 5 | ✅ COVERED |
| SYS-ERP-WEB | 0 | 0 | ⚠️ ORPHAN |

Coverage: 2/3 systems planned (66%)
Strategy: placeholders
Orphan placeholders: `tasks/erp-web/_NO-FEATURES.md`

### Stakeholder Review Results
| Document | Findings (Critical/High) | Status |
|----------|--------------------------|--------|
| SO-01 Plan Review | 0 | PASSED |
| SO-02 Consistency Check | 0 | PASSED |
| SO-03 Gap Analysis | 0 | PASSED |

Chi tiết: `.mc-data/docs/phase5-implementation/module-plan.md`
Review: `.mc-data/docs/phase5-implementation/stakeholder-review.md`

Next: `/wf-implement-feature [REQ-ID]`
```

---

## Error Handling

> **BẮT BUỘC (CORE-026):** Mọi early exit (STOP trước Phase 7c) PHẢI emit `FAIL` entry vào `.mc-data/work/_trace/session-log.json` ngay tại điểm exit với `{event:"FAIL", skill:"wf-plan-modules", phase_failed:"<phase>", error_code:"<Exx>", error_details:"<msg>"}`. Không để session kết thúc mà không có FAIL log.

| Code | Tình huống | Xử lý |
|------|------------|-------|
| E001 | Registry không tìm thấy | STOP → chạy `/wf-analyze-requirements` trước |
| E002 | Circular dependency phát hiện | Hiển thị solutions, chờ user chọn (Phase 3) |
| E003 | Module không tồn tại | Liệt kê modules có sẵn trong registry |
| E004 | Không có modules | STOP → chạy `/wf-analyze-requirements` trước |
| E005 | JSON parse error | Chạy lại `/wf-analyze-requirements` |
| E006 | Không extract được dependencies | Kiểm tra format feature files |
| E007 | Output verification mismatch (Phase 7a) | List mismatches, retry Phase 7 |
| E008 | Context > 90% | FORCE checkpoint, resume từ phase tiếp theo |
| E009 | POST-GATE fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |
| E010 | Auto-fix gây regression | Rollback fix → escalate with context |
| E011 | Agent timeout trong Phase 7b (parallel review) | Retry agent đó 1 lần. Nếu vẫn timeout → skip agent đó, log warning vào stakeholder-review.md, tiếp tục với kết quả từ agent còn lại. |
| E012 | Upstream Coverage Gap (Phase 1.7): có orphan systems hoặc modules_without_features | Show System Coverage table → escalate user với 3 options (STOP / placeholders / thin_clients). Nếu user chọn STOP → exit skill với message: "Chạy `/wf-define-features` hoặc `/wf-analyze-requirements` để bổ sung scope, sau đó chạy lại `/wf-plan-modules`." |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-analyze-requirements` | Prerequisite |
| `/wf-design` | Prerequisite |
| `/wf-design-ux` | Prerequisite (thay thế /wf-design khi dự án có UI) |
| `/wf-implement-feature` | **Next step** |
| `/status` | Kiểm tra tiến độ |
