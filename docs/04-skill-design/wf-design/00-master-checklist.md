# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit cho skill `wf-design`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant | [x] | **Standard + spawn agents** — 7 agent types: architect, dba, security, devops, ai-engineer, data-engineer, automation-architect |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | v4.0.0, ~400 dòng (lazy-load OK) |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [x] | 10 phase files (`phase0` → `phase8`), `_shared.md` |
| 4 | Tạo `_contract.json` + validate schema | [x] | v4.0.0, registry_scope: PRIMARY for `design_status` (per FEAT-ID); LEGACY mode rebuild requirements/features |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [x] | `design-status.json`, `design-plan.md`, `checkpoint.json` |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | Test cases trong `09-evals-test-cases.md` |
| 7 | Tạo `docs/04-skill-design/wf-design/` (12 file design canon) | [x] | README + 00-master-checklist (file này) + 01-09 + agent-prompt |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [x] | Có ở "Workflow chính" section |
| 9 | Tạo `.claude/commands/wf-design.md` (slash command entry) | [x] | Có |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | **TODO**: chạy `check-skill-design-populated.sh docs/04-skill-design/wf-design/` |

---

## Notes per step

### Step 1 — Variant: Standard + multi-agent (heavy)

`wf-design` spawn 7 agent types × N systems → up to ~21 agent calls/session (3 systems × 7 agents). Lane Dispatch per system → max 10 concurrent (CORE-025). Mỗi system có 1 lane = 7 agents parallel trong lane đó.

→ File `agent-prompt.md` đặc biệt quan trọng — list 7 agent types + dispatch logic per phase.

### Step 3 — Procedures structure (10 phase files)

| Phase | File | Spawn agents? |
|-------|------|---------------|
| 0 | `phase0-context.md` | KHÔNG (load context) |
| 0.5 | `phase0.5-workload-gate.md` | KHÔNG |
| 1 | `phase1-architecture.md` | ✅ architect (per system) |
| 2 | `phase2-specs-parallel.md` | ✅ dba + devops + security (parallel per system) |
| 3 | `phase3-integration.md` | ✅ architect + automation-architect |
| 4 | `phase4-crossval.md` | KHÔNG (cross-validation) |
| 5 | `phase5-review.md` | ✅ stakeholder review (multi-perspective) |
| 6 | `phase6-finalize.md` | KHÔNG (finalize + atomic write) |
| 7 | `phase7-gap.md` | LEGACY only — gap analysis |
| 8 | `phase8-digest-summary.md` | KHÔNG (digest output) |

### Step 4 — Registry Safe-Write

Skill là **PRIMARY** owner của:
- `design_status` (per FEAT-ID)
- LEGACY flow: rebuild full registry (systems[], modules[], departments[], requirements[], features[], interface_type)
- LEGACY: FIX-INVALID role cho `requirements[].impl_status` (invalid → "not_started")

### Step 7 — Design canon files

| File | Trạng thái |
|------|-----------|
| `README.md` | ✅ |
| `00-master-checklist.md` | ✅ (file này) |
| `01-vision-principles.md` | ✅ |
| `02-arguments.md` | ✅ |
| `03-phase-routing.md` | ✅ |
| `04-file-contract.md` | ✅ |
| `05-error-codes.md` | ✅ |
| `06-templates-list.md` | ✅ |
| `07-procedures-structure.md` | ✅ |
| `08-tradeoffs-adr.md` | ✅ |
| `09-evals-test-cases.md` | ✅ |
| `agent-prompt.md` | ✅ (file này tạo cùng) |

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Step 10 chưa tick
- File này còn `_template_notes` block hoặc placeholder gốc
- Phase 1-2 spawn không khớp `agent-prompt.md` §1

---

## Liên kết

- Skill source: [`../../../.claude/skills/workflow/wf-design/SKILL.md`](../../../.claude/skills/workflow/wf-design/SKILL.md)
- Validation script: [`../../../.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- Template canonical: [`../_template/00-master-checklist.md`](../_template/00-master-checklist.md)
