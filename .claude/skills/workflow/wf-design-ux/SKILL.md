---
name: wf-design-ux
version: 4.1.0
last_updated: 2026-09-12
description: |
  UX/UI design cho hệ thống — hỗ trợ cả dự án mới và dự án có sẵn. Tự phát hiện loại dự án và load flow phù hợp.

  v4.1: Workspace-first + working-context — screen inventory & consolidation trước khi chốt màn hình; luồng xuyên phòng ban (actors, cross-module status, ownership); data grid ERP; tab hoàn chỉnh; role-aware.

  DỰ ÁN MỚI: Thiết kế UX/UI từ đầu — design system, navigation, screen groups.
  DỰ ÁN CÓ SẴN (LEGACY_MODE): Trích xuất UX/UI documentation từ frontend code hiện có.

  TRIGGER khi:
  - User nói: "thiết kế UI", "design UX", "giao diện", "screen", "navigation"
  - Sau khi /wf-design hoàn thành (architecture ready)
  - Gọi lệnh: /wf-design-ux [system-name] [--status] [--resume]

  LUÔN trigger khi user cần thiết kế hoặc trích xuất UX/UI cho hệ thống,
  dù không dùng từ "design-ux".

  KHÔNG trigger khi:
  - interface_type == "api-only" → skip, chuyển /wf-plan-modules
  - Chưa có architecture → dùng /wf-design trước
  - Chỉ cần style/CSS cho 1 component → dùng /ui-ux-pro-max

argument-hint: "[all | system-name] [--status] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---

# /wf-design-ux: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | UX/UI design — thiết kế giao diện hoặc trích xuất UX docs từ code hiện có |
| **Prerequisites** | `phase3-architecture/` tồn tại, `interface_type != "api-only"` |
| **Workflow position** | `/wf-design` → **/wf-design-ux** ← YOU ARE HERE → `/wf-plan-modules` |
| **Output** | `phase4-ux/design-system.md` + `phase4-ux/[sys]/Navigation-*.md` + `phase4-ux/[sys]/[mod]/screens-*.md` + `phase4-ux/stakeholder-review.md` + `registry.ux_design_status` |
| **Phases** | 0 → [0.5 LEGACY] → 1 → 2 → 3 → 4 → 5 → 6 → 7 |
| **Duration** | Multi-session (có thể dừng/resume qua checkpoint) |

## Arguments

| Argument | Mô tả | Default |
|----------|--------|---------|
| `all` | Thiết kế/trích xuất UX cho tất cả systems có UI | `all` |
| `system-name` | Thiết kế/trích xuất UX cho system cụ thể | — |
| `--status` | Hiển thị tiến độ, không thực thi | — |
| `--resume` | Resume từ checkpoint đã lưu | — |

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` directory (internal) hoặc `doc-framework/` (output docs)
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> Áp dụng cho:
> - **Internal templates** (3 files): `templates/design-ux-status.json`, `templates/design-ux-plan.md`, `templates/checkpoint.json`
> - **doc-framework templates** (4 files): `phase4-ux/design-system.md`, `phase4-ux/[system]/Navigation-[system].md`, `phase4-ux/[system]/[module]/[screen-group].md`, `phase4-ux/stakeholder-review.md`
> - **Digest template**: `_digests/ux-input-digest.template.json`
> - **Shared templates**: `_meta/phase-summary.template.md`, `_meta/session-log.template.json`

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention), Protocol 7 (PAR), Protocol 8 (CQG), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation), Protocol 11 (Rollback), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **ADR-OPT Techniques (v4.0.0):**
> - **ADR-OPT-01** (Lane Dispatch): Phase 3 — mỗi UI module là 1 lane, parallel dispatch
> - **ADR-OPT-02** (Session Isolation): Phase 0 — `sessions/{id}/` directory isolation
> - **ADR-OPT-03** (Workload Gate): Phase 0.5 — estimate + gate + api-only conditional skip
> - **ADR-OPT-04** (Signal Aggregation): Phase 4 — aggregate lane signals, dedup screen_id
> - **ADR-OPT-05** (Template Strip): Phase 7 — strip `_template_notes` + atomic write digest
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Phase → File Mapping, Session Isolation Protocol, _shared Module Imports, Conditional Skip Handling, LEGACY Context Injection, Agent Prompt Templates, Checkpoint Protocol.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Workflow Context & Screen Consolidation** (Phase 2, v4.1): main conversation — screen inventory + consolidation pass TRƯỚC khi chốt screen groups; minimum necessary screen set, mỗi screen có justification; workspace-first structure — xem `procedures/phase2-navigation.md` §Step 2.0
- **Auto-Correction Loop** (Phase 4, 5): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90%
- **Stakeholder Review** (Phase 5): SO-01/02/03 với parallel agents (ux-designer + architect)
- **Token Limit Prevention** (Phase 1, 3, 5): input compression + skeleton-first + UX digest
- **Registry Safe-Write** (Phase 6): CHỈ update field `ux_design_status`
- **Parallel Execution** (Phase 2, 3, 5): max `$LPM_PARAMS.max_parallel_agents` (Standard: 5, LPM: 3)
- **Content Quality Gate** (Phase 4): CQG-09.1/09.2 + 8 cross-validation checks + 3 ERP working-context checks v4.1 (Screen Justification, Tab Completeness, Cross-Module Context)
- **Large Project Mode** (auto-detect Phase 0): `systems >= 5 OR features >= 40` → compression sớm hơn, skeleton-first, checkpoint per system

## Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Phase 1 (design system) — 3 agents | SEQUENTIAL: brand-guardian → ux-researcher → ux-designer |
| Phase 2 (navigation) — per system | **Step 2.0 Workflow Context + Screen Inventory + Consolidation (main conversation, v4.1) → sau đó** SEQUENTIAL per system; PARALLEL ux-designer + ux-architect trong system |
| Phase 3 (screen groups) — nhiều systems | PARALLEL per system, SEQUENTIAL per module trong system (max 3-5 agents) |
| Phase 4 (cross-validation) | SEQUENTIAL (auto-correction loop) |
| Phase 5 (stakeholder review) | PARALLEL: ux-designer + architect |
| Phase 6 (registry update) | SEQUENTIAL — main conversation, KHÔNG spawn agent |

## Work Directory

```
.mc-data/work/wf-design-ux/
├── design-ux-plan.md                      # Execution plan (9 sections)
├── latest                                 # Pointer tới session ID hiện tại
├── cross-validation-report.md             # Phase 4 output (canonical)
├── sessions/                              # Session isolation (ADR-OPT-02)
│   └── {YYYYMMDD-HHMMSS}-{hash4}/         # Session dir (giữ tối đa 5)
│       ├── session-state.json             # Runtime state + phase status
│       ├── design-ux-status.json          # Metrics, agents_spawned
│       ├── checkpoint.json                # Checkpoint cho resume
│       ├── lanes/
│       │   └── {module-slug}-screens/
│       │       └── signals.json           # Lane output từ Phase 3
│       ├── workload-report.md             # Workload gate output
│       ├── workflow-context.md            # Phase 2 — Workflow map + Screen Inventory + Consolidation (v4.1)
│       ├── aggregation-result.json        # Signal aggregation output
│       ├── ux-input-digest.json           # Working copy (post-strip)
│       └── phase-summary.md              # CORE-028 summary
└── (LEGACY fallback)
    └── ux-checkpoint.json                 # v3.x resume compat
```

Templates: `.claude/skills/workflow/wf-design-ux/templates/`

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

> Phát hiện project type và inject context phù hợp.
> LEGACY_MODE detection theo CORE-021: check `project-context.md` (> 500 bytes).

```
STEP 1: Kiểm tra prerequisites
  (a) test -f .mc-data/docs/_meta/req-registry.json
      IF NOT EXISTS → STOP: "req-registry.json không tìm thấy. Chạy /wf-analyze-requirements."
  (b) test -f .mc-data/docs/phase3-architecture/P3-01-architecture.md
      IF NOT EXISTS → STOP: "Chưa có architecture. Chạy /wf-design trước."

STEP 2: Detect LEGACY_MODE (CORE-021)
  LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
  IF LEGACY_MODE → PROJECT_TYPE = LEGACY

STEP 3: Routing
  → Read procedures/phase0-context.md (Phase 0 detail + UI guard + LPM + scaffold cache)
```

**Phase 0 step summary (audit trail):**

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Check `req-registry.json` + `P3-01-architecture.md` tồn tại | Files exist, nếu thiếu → STOP (E000/E001) |
| 0.2 | Detect LEGACY_MODE (CORE-021) — `project-context.md > 500 bytes` | `$LEGACY_MODE` set |
| 0.3 | Load context: registry (`interface_type`, systems), LEGACY inputs (nếu có) | `$INTERFACE_TYPE`, `$SYSTEMS_WITH_UI` set |
| 0.4 | Session Init (ADR-OPT-02) + LPM detect + scaffold cache | `$SESSION_DIR` tồn tại, session-state.json valid |
| 0.5 | Route → `procedures/phase0-context.md` chi tiết | Phase file dispatched |

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/wf-design-ux/checkpoint.json:
    → Read procedures/phase0-context.md §Resume Logic
    → Jump tới phase trong checkpoint.position.current_phase (xem §Phase Routing Map)
  ELSE IF test -f .mc-data/work/legacy-scan/ux-checkpoint.json:
    → Read procedures/phase0-context.md §Resume Logic (LEGACY fallback)
  ELSE:
    → STOP: "Không tìm thấy checkpoint. Chạy /wf-design-ux từ đầu."
```

**Đặc biệt — `--status` handler:**

```
IF $ARGUMENTS chứa "--status":
  → Read procedures/phase0-context.md §--status Handler
  → Hiển thị trạng thái → STOP
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-context.md` | Always (entry point) | Context Loading + Session Init (ADR-OPT-02) + LPM detect + scaffold cache |
| **0.5-workload** | `procedures/phase0.5-workload-gate.md` | Always (sau Phase 0) | Workload Gate + api-only conditional skip (ADR-OPT-03) |
| **0.5-legacy** | `procedures/phase0.5-legacy-ui-analysis.md` | `$LEGACY_MODE = true` | Existing UI Context — build `$UI_CONTEXT_SUMMARY` |
| **1** | `procedures/phase1-design-system.md` | `$INTERFACE_TYPE != api-only` | Design System — brand/research/design |
| **2** | `procedures/phase2-navigation.md` | `$INTERFACE_TYPE != api-only` | Workflow Context + Screen Inventory & Consolidation (Step 2.0, v4.1) + Navigation Specs per system (SEQUENTIAL) |
| **3** | `procedures/phase3-screen-groups.md` | `$INTERFACE_TYPE != api-only` | Screen Groups — Lane Dispatch (ADR-OPT-01) |
| **4** | `procedures/phase4-crossval.md` | `$INTERFACE_TYPE != api-only` | Signal Aggregation + Cross-Validation (ADR-OPT-04) |
| **5** | `procedures/phase5-review.md` | `$INTERFACE_TYPE != api-only` | Stakeholder Review (PARALLEL ux-designer + architect) |
| **6** | `procedures/phase6-registry.md` | `$INTERFACE_TYPE != api-only` | Registry Safe-Write — `ux_design_status = done` |
| **7** | `procedures/phase7-digest-summary.md` | `$INTERFACE_TYPE != api-only` | Template Strip + Atomic Write digest (ADR-OPT-05) + phase-summary + session log close |

**Routing flow:**

```
SKILL.md Phase 0 → Read procedures/phase0-context.md → execute → return
   ↓ (luôn)
Read procedures/phase0.5-workload-gate.md → execute
   ↓ (IF interface_type == "api-only" → EXIT skill — return success, 0 canonical outputs)
   ↓ (nếu $LEGACY_MODE = true)
Read procedures/phase0.5-legacy-ui-analysis.md → execute → return
   ↓
Read procedures/phase1-design-system.md → execute → return
   ↓
... (tiếp tục theo Phase Routing Map)
   ↓
Read procedures/phase7-digest-summary.md → execute → return → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, LEGACY Injection, Agent Prompts.

---

## Output Files

### Standard (new project)

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | design-system.md | `.mc-data/docs/phase4-ux/` | 1 | `doc-framework/phase4-ux/design-system.md` |
| 2 | Navigation-[sys].md | `.mc-data/docs/phase4-ux/[sys]/` | 2 | `doc-framework/phase4-ux/[system-name]/Navigation-[system].md` |
| 3 | screens-[group].md | `.mc-data/docs/phase4-ux/[sys]/[mod]/` | 3 | `doc-framework/phase4-ux/[system-name]/[module-name]/[screen-group].md` |
| 4 | stakeholder-review.md | `.mc-data/docs/phase4-ux/` | 5 | `doc-framework/phase4-ux/stakeholder-review.md` |
| 5 | ux-input-digest.json | `.mc-data/docs/_meta/` | 7 | `doc-framework/_digests/ux-input-digest.template.json` |
| 6 | Registry update | `req-registry.json` | 6 | — (safe-write) |

### Working files

| File | Path | Phase | Template |
|------|------|-------|----------|
| design-ux-status.json | `.mc-data/work/wf-design-ux/sessions/{SESSION_ID}/` | 0 | `templates/design-ux-status.json` |
| design-ux-plan.md | `.mc-data/work/wf-design-ux/` | 0 | `templates/design-ux-plan.md` |
| checkpoint.json | `.mc-data/work/wf-design-ux/sessions/{SESSION_ID}/` | 0-5 | `templates/checkpoint.json` |
| workflow-context.md | `.mc-data/work/wf-design-ux/sessions/{SESSION_ID}/` | 2 | — (inline schema trong `procedures/phase2-navigation.md` §Step 2.0) — workflow map + screen inventory + consolidation decisions |
| cross-validation-report.md | `.mc-data/work/wf-design-ux/` | 4 | — |
| phase-summary.md | `.mc-data/work/wf-design-ux/sessions/{SESSION_ID}/` | 7 | `doc-framework/_meta/phase-summary.template.md` |

### LEGACY_MODE (additional outputs)

| # | File | Path | Phase |
|---|------|------|-------|
| 7 | existing-ui-analysis.md | `.mc-data/docs/phase4-ux/` | 0.5 |
| 8 | screen-inventory.md | `.mc-data/docs/phase4-ux/[system]/` | 0.5 |
| 9 | design-tokens-baseline.md | `.mc-data/docs/phase4-ux/` | 0.5 |
| 10 | ux-implementation-gap.md | `.mc-data/work/legacy-scan/` | 0.5 |

### API-Only Exit (Phase 0.5.0 Conditional Skip)

Nếu `interface_type == "api-only"` (detected tại Phase 0.5.0):
- `$SESSION_DIR/session-state.json` — `{phases.P0_5.skipped: true, reason: "api-only interface"}`
- `$SESSION_DIR/phase-summary.md` — "Skill skipped — project is api-only."
- **KHÔNG tạo** `ux-input-digest.json` canonical (wf-plan-modules xử lý thiếu digest theo §4b)
- Skill return **success** (không fail) — audit trail trong session

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E000 | `req-registry.json` không tìm thấy | STOP → chạy `/wf-analyze-requirements` |
| E001 | `P3-01-architecture.md` không tìm thấy hoặc FAIL forensic | STOP → chạy `/wf-design` trước |
| E002 | `interface_type == "api-only"` | EXIT Phase 0 → placeholder → hướng dẫn `/wf-plan-modules` |
| E003 | `interface_type` không xác định | AskUserQuestion: web / mobile / web+mobile / api-only |
| E004 | Design system file không tạo được | Retry Phase 1 (max 3×) |
| E005 | Navigation spec fail | Retry phase đó (max 3×), kiểm tra template |
| E006 | Screen group file không tạo được | Retry module đó, hoặc tạo stub |
| E007 | UI-ID duplicate sau 3 iterations | STOP → escalate với danh sách duplicates |
| E008 | Cross-validation fail sau 3 iterations | STOP → báo cáo chi tiết → user quyết định |
| E009 | Stakeholder review Critical/High PENDING sau 3 iterations | STOP + báo cáo → user quyết định |
| E010 | Agent timeout | Retry, hoặc tạo stub inline |
| E011 | Registry write fail | Rollback → re-read → retry write |
| E012 | Context > 90% | FORCE checkpoint, STOP, prompt `--resume` |

---

## Agents Spawned

| Phase | Agent | Mục đích |
|-------|-------|----------|
| 1 | `brand-guardian` | Brand compliance review (conditional — chỉ khi có brand guidelines) |
| 1 | `ux-researcher` | User research context (trước design) |
| 1 | `ux-designer` | Design system |
| 2 | `ux-designer` | Navigation specs (per system) |
| 2 | `ux-architect` | CSS architecture, layout framework (parallel với ux-designer per system) |
| 3 | `ux-designer` | Screen groups (1 agent per system, max 3-5 đồng thời) |
| 4 | `accessibility-auditor` | WCAG compliance check |
| 5 | `ux-designer` | Stakeholder Review Phần B+C (SO-01, SO-02) |
| 5 | `architect` | Stakeholder Review Phần D (SO-03) — gap analysis |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-design` | Prerequisite — cung cấp architecture + business context (actor matrix, lifecycle, integration-map cho cross-module status) |
| `/wf-plan-modules` | Next step — sử dụng UX digest cho planning |
| `/ui-ux-pro-max` | Complementary — cho individual component styling |
| `/wf-legacy-scan` | Entry point cho dự án có sẵn |
| `/existing-project` | Orchestrator workflow |
| `/status` | Kiểm tra tiến độ |

---

## Examples

### Example 1: Happy Path (new project)

```
Phase 0: interface_type=web, LPM=false → PASS
Phase 1: design-system.md (3 agents) → PASS
Phase 2: workflow-context.md (screen inventory + consolidation — Step 2.0) → Navigation-crm.md, Navigation-admin.md → PASS
Phase 3: 10 screen groups sau consolidation (PARALLEL 2 systems) → PASS
Phase 4: Validation 13/13 checks PASS (1 iteration)
Phase 5: APPROVED (0 Critical, 2 Medium RESOLVED)
Phase 6: ux_design_status=done
Phase 7: ux-input-digest.json + phase-summary.md → DONE

Next: /wf-plan-modules để xác định implementation order
```

### Example 2: Multi-Session (large project, LPM)

```
SESSION 1: Phase 0-2 (LPM detected, 6 systems) → CHECKPOINT (Context: 82%, 3 systems done)
SESSION 2 (--resume): Phase 3 systems 4-6 → CHECKPOINT (Context: 78%)
SESSION 3 (--resume): Phase 4-7 → DONE
```

### Example 3: API-Only Exit

```
Phase 0: interface_type=api-only → EXIT
Message: "Dự án không có UI, skip /wf-design-ux. Chạy /wf-plan-modules tiếp theo."
```

### Example 4: LEGACY_MODE

```
Phase 0: LEGACY_MODE=true, interface_type=web → PASS
Phase 0.5: Existing UI context (3 screens detected, Tailwind tokens) → PASS
Phase 1-5: Design với LEGACY injection, TRÍCH XUẤT từ code thay vì thiết kế lại
Phase 6-7: DONE
```
