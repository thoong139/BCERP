# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit cho skill `wf-analyze-requirements`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant | [x] | **Standard + heavy multi-agent** — spawn BA + 24 domain experts |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | v3.0.0, ~400 dòng (lazy-load OK) |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [x] | 14 phase files (`phase0` → `phase8c`), `_shared.md`, `flow-new.md`, `flow-legacy.md` |
| 4 | Tạo `_contract.json` + validate schema | [x] | v3.0.0, registry_scope: PRIMARY for `requirements[]` + `systems[]` + `modules[]` |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [x] | Templates cho phase1 docs (BR, NFR, stakeholder review, ...) |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | 4 evals: smoke (1 module), integration (multi-domain), legacy mode, resume |
| 7 | Tạo `docs/04-skill-design/wf-analyze-requirements/` (9 file design canon) | [x] | 9 file + README + 00-master-checklist + agent-prompt |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [x] | Có ở "Workflow chính" section |
| 9 | Tạo `.claude/commands/wf-analyze-requirements.md` (slash command entry) | [x] | Có |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | **TODO**: chạy `check-skill-design-populated.sh docs/04-skill-design/wf-analyze-requirements/` |

---

## Notes per step

### Step 1 — Variant: Standard + multi-agent

`wf-analyze-requirements` là skill **multi-agent heavy** — Phase 4 spawn BA + 1-3 domain experts theo project type (HR, Finance, Healthcare, ...). Không phải orchestrator (không gọi sub-skills `wf-*`), nhưng spawn ~5-15 agents/session.

→ File `agent-prompt.md` đặc biệt quan trọng — list 24 domain experts + dispatch logic.

### Step 3 — Procedures structure

15 phase files trong `procedures/`:

| Phase | File | Mode |
|-------|------|------|
| 0 | `phase0-context.md` | Both |
| 0.5 | `phase0.5-workload-gate.md` | Both |
| 1 | `phase1-scope.md` | Both |
| 2 | `phase2-plan.md` | Both |
| 3 | `phase3-ba-parta.md` | Both |
| 3.5 | `phase3.5-legacy.md` | LEGACY only |
| 4 | `phase4-experts-partb.md` | Both |
| 5 | `phase5-existing-docs.md` | Conditional |
| 6 | `phase6-consolidate.md` | Both |
| 6b | `phase6b-workflow.md` | Both |
| 6c | `phase6c-stakeholder.md` | Both |
| 6d | `phase6d-conflict.md` | Both |
| 8 | `phase8-registry.md` | Both |
| 8b | `phase8b-crossval.md` | Both |
| 8c | `phase8c-handoff.md` | Both |

### Step 4 — Registry Safe-Write

Skill là **PRIMARY** owner của:
- `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type`

CHỈ write fields trên — KHÔNG modify `features[]` (đó là wf-define-features).

### Step 7 — Design canon files

| File | Trạng thái |
|------|-----------|
| `README.md` | ✅ |
| `00-master-checklist.md` | ✅ (file này) |
| `01-vision-principles.md` | ✅ |
| `02-arguments.md` | ✅ |
| `03-architecture.md` | ✅ (multi-agent BA + experts pattern) |
| `04-contracts-data-model.md` | ✅ (legacy naming) |
| `05-execution-profiles.md` | ✅ |
| `06-templates-list.md` | ✅ |
| `07-procedures-structure.md` | ✅ |
| `08-tradeoffs-adr.md` | ✅ |
| `09-evals-test-cases.md` | ✅ |
| `agent-prompt.md` | ✅ (file mới — 24 domain experts dispatch) |

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Step 10 chưa tick
- File này còn `_template_notes` block hoặc placeholder gốc
- Domain expert dispatch logic không match `.claude/agents/business/` (24 expert files)

---

## Liên kết

- Skill source: [`../../../.claude/skills/workflow/wf-analyze-requirements/SKILL.md`](../../../.claude/skills/workflow/wf-analyze-requirements/SKILL.md)
- Domain expert pool: [`../../../.claude/agents/business/`](../../../.claude/agents/business/) (24 expert files)
- Validation script: [`../../../.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- Template canonical: [`../_template/00-master-checklist.md`](../_template/00-master-checklist.md)
