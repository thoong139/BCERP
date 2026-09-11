# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit cho skill `wf-define-features`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant | [x] | **Standard + spawn agents** — BA + product-expert (multi-agent, không phải orchestrator) |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | v3.2.0, ~500 dòng |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [x] | 11 phase files (`phase0` → `phase5`), `_shared.md` |
| 4 | Tạo `_contract.json` + validate schema | [x] | v3.2.0, registry_scope: PRIMARY for `features[]`; SAFE-UPDATE for `impl_status` (chỉ "skipped" cho DEPRECATE) |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [x] | `define-features-status.json`, `feature-briefs.json`, `ui-coverage-gaps.json` |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | Test cases trong `09-evals-test-cases.md` |
| 7 | Tạo `docs/04-skill-design/wf-define-features/` (12 file design canon) | [x] | README + 00-master-checklist (file này) + 01-09 + agent-prompt |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [x] | Có ở "Workflow chính" section |
| 9 | Tạo `.claude/commands/wf-define-features.md` (slash command entry) | [x] | Có |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | **TODO**: chạy `check-skill-design-populated.sh docs/04-skill-design/wf-define-features/` |

---

## Notes per step

### Step 1 — Variant: Standard + multi-agent

`wf-define-features` spawn 2 agent types: BA (Phase 2) + product-expert (Phase 4 stakeholder review). Không phải orchestrator. Thêm Phase 3 cross-validation có check W4.7 (Cross-Module Entity Detection — non-blocking suggest).

→ File `agent-prompt.md` cover BA Phase 2 (feature spec generation) + product-expert Phase 4.

### Step 3 — Procedures structure (11 phase files)

| Phase | File | Mode | Spawn agents? |
|-------|------|------|---------------|
| 0 | `phase0-context.md` | Both | KHÔNG |
| 0.5 | `phase0.5-workload-gate.md` | Both | KHÔNG |
| 0.5L | `phase0.5-legacy-impl-seed.md` | LEGACY only | KHÔNG |
| 1 | `phase1-scope-mapping.md` | Both | KHÔNG (REQ→FEAT mapping) |
| 2 | `phase2-create-specs.md` | Both | ✅ BA per FEAT |
| 2.5 | `phase2.5-feat-mapping.md` | Both | KHÔNG (cross-validate FEAT↔REQ) |
| 2.7 | `phase2.7-ui-coverage.md` | UI projects | KHÔNG (UI coverage check) |
| 3 | `phase3-cross-validation.md` | Both | KHÔNG (W4.7 cross-module check) |
| 4 | `phase4-stakeholder-review.md` | Both | ✅ product-expert (multi-perspective) |
| 5 | `phase5-registry-update.md` | Both | KHÔNG (registry write — main thread only) |

### Step 4 — Registry Safe-Write

Skill là **PRIMARY** owner của:
- `features[]` (gồm `features[].impl_status`)

SAFE-UPDATE role cho:
- `impl_status` (per REQ-ID) — CHỈ set "skipped" cho DEPRECATE module (CORE-022)

**Exception (v3.1+):** `requirements[]` APPEND-ONLY khi dùng `--auto-stub-requirements` flag để fix referential integrity (Phase 5 step 5.3c).

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

## Special checks (W4.7 + Referential Integrity)

| Check | Phase | Behavior |
|-------|-------|----------|
| W4.7 Cross-Module Entity Detection | 3.8 (non-blocking) | Quét MOD-XXX refs từ module khác, suggest user declare cross_module_dependencies[] |
| Referential Integrity | 5.3c (BLOCKING) | Compute orphan REQ-IDs từ features[].req_ids[] − requirements[].req_id; default BLOCK với E020; flag `--auto-stub-requirements` để APPEND stub entries |

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Step 10 chưa tick
- File này còn `_template_notes` block hoặc placeholder gốc
- Phase 3 W4.7 check thiếu
- Phase 5 referential integrity check thiếu (E020 must be defined)

---

## Liên kết

- Skill source: [`../../../.claude/skills/workflow/wf-define-features/SKILL.md`](../../../.claude/skills/workflow/wf-define-features/SKILL.md)
- BA agent: [`../../../.claude/agents/business/business-analyst.md`](../../../.claude/agents/business/business-analyst.md)
- Product expert: [`../../../.claude/agents/business/product-expert.md`](../../../.claude/agents/business/product-expert.md)
- Validation script: [`../../../.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- Template canonical: [`../_template/00-master-checklist.md`](../_template/00-master-checklist.md)
