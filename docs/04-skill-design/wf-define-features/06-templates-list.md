# 06 — Templates List

> **Mục đích file:** 5 skill-local templates + 1 digest schema (cho Phase 6) + dual-schema feature-briefs.

---

## 1. Skill-local templates (5)

| # | Template path | Output target | Schema |
|---|--------------|--------------|--------|
| 1 | `templates/define-features-status.json` | `sessions/{id}/define-features-status.json` + flat | `define-features-status-v1` |
| 2 | `templates/define-features-plan.md` | `sessions/{id}/define-features-plan.md` + flat | (markdown) |
| 3 | `templates/feature-briefs.json` | `sessions/{id}/feature-briefs.json` + flat | **`feature-briefs-working-v1`** (Phase 1 creation use) |
| 4 | `templates/checkpoint.json` | `sessions/{id}/checkpoint.json` + flat | `checkpoint-v1` |
| 5 | `templates/ui-coverage-gaps.json` | `sessions/{id}/ui-coverage-gaps.json` + flat | `ui-coverage-gaps-v1` (LEGACY only) |

---

## 2. doc-framework templates (output docs)

| Template path | Output target |
|--------------|--------------|
| `doc-framework/phase2-features/[feature].md` (template) | `phase2-features/[sys]/[mod]/[feature-slug].md` (NEW) OR `FEAT-XXX-NNN.md` (LEGACY) |
| `doc-framework/phase2-features/stakeholder-review.md` | `phase2-features/stakeholder-review.md` |

---

## 3. Digest template (Phase 6 — Phiên 6)

| # | Template path | Output target | Schema |
|---|--------------|--------------|--------|
| 6 | `doc-framework/_digests/feature-briefs.template.json` | `_meta/feature-briefs.json` (STRIPPED) | **`feature-briefs-digest-v1`** (≠ working schema) |

---

## 4. Per-phase template usage

| Phase | Template(s) READ | Output |
|-------|------------------|--------|
| 0 | `define-features-status.json` | sessions/{id}/* + flat |
| 1 | `define-features-plan.md` + `feature-briefs.json` (WORKING) | sessions/{id}/* + flat |
| 2 | `doc-framework/phase2-features/[feature].md` | `phase2-features/[sys]/[mod]/*.md` |
| 2.7 | `ui-coverage-gaps.json` | sessions/{id}/ui-coverage-gaps.json (LEGACY only) |
| 4 | `doc-framework/phase2-features/stakeholder-review.md` | `phase2-features/stakeholder-review.md` |
| 6 (Phiên 6) | `_digests/feature-briefs.template.json` | `_meta/feature-briefs.json` STRIPPED (DIGEST schema) |

---

## 5. Dual-schema feature-briefs.json — Critical pattern

**Cùng tên file ở 2 location, SCHEMA KHÁC NHAU:**

| Location | Schema | Use |
|----------|--------|-----|
| `work/wf-define-features/feature-briefs.json` | `feature-briefs-working-v1` (`feat_id`, `actors`, `business_rules`, `output_path`) | Phase 1 creation |
| `_meta/feature-briefs.json` | `feature-briefs-digest-v1` (`feature_id`, `summary`, `acceptance_criteria`, `technical_complexity`) | Downstream skills |

Phase 6 (Phiên 6) generate digest schema riêng từ Phase 2 docs. KHÔNG copy working schema.

---

## 6. Template Strip (CORE-031.b)

Phase 6 strip recursive `_*` keys trước khi ghi canonical `_meta/feature-briefs.json`.

---

## 7. Template versioning

| Template | Version | Khi bump |
|----------|---------|----------|
| `define-features-status.json` | v1.0 | Phase tracking change |
| `feature-briefs.json` (working) | v1.0 | Working schema change |
| `feature-briefs.template.json` (digest) | v1.0 | Digest schema change (breaking → wf-design/wf-implement-feature migrate) |
| `ui-coverage-gaps.json` | v1.0 | Coverage classification change |

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031, ADR-OPT-05
- File contract: [04-file-contract.md](04-file-contract.md) §dual-schema
- Source: [`.claude/skills/workflow/wf-define-features/templates/`](../../../.claude/skills/workflow/wf-define-features/templates/)
