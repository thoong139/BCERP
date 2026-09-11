# 06 — Templates List

> **Mục đích file:** 3 skill-local + 6 doc-framework + 1 digest + 2 shared `_meta/` templates.

---

## 1. Skill-local templates (3)

| # | Template path | Output target | Schema |
|---|--------------|--------------|--------|
| 1 | `templates/design-status.json` | `sessions/{id}/design-status.json` + flat | `design-status-v1` |
| 2 | `templates/design-plan.md` | `sessions/{id}/design-plan.md` + flat | (markdown) |
| 3 | `templates/checkpoint.json` | `sessions/{id}/checkpoint.json` + flat (legacy mirror) | `checkpoint-v1` |

---

## 2. doc-framework templates (6 — output docs Phase 1-5)

| # | Template path | Output target |
|---|--------------|--------------|
| 4 | `doc-framework/phase3-architecture/P3-01-architecture.md` | `phase3-architecture/P3-01-architecture.md` |
| 5 | `doc-framework/phase3-architecture/technical-specs/api-contract.md` | `phase3-architecture/technical-specs/api-contract.md` |
| 6 | `doc-framework/phase3-architecture/technical-specs/database-design.md` | `phase3-architecture/technical-specs/database-design.md` |
| 7 | `doc-framework/phase3-architecture/technical-specs/infra-spec.md` | `phase3-architecture/technical-specs/infra-spec.md` |
| 8 | `doc-framework/phase3-architecture/technical-specs/integration-map.md` | `phase3-architecture/technical-specs/integration-map.md` |
| 9 | `doc-framework/phase3-architecture/stakeholder-review.md` | `phase3-architecture/stakeholder-review.md` |

---

## 3. Digest templates (1)

| # | Template path | Output target |
|---|--------------|--------------|
| 10 | `doc-framework/_digests/design-input-digest.template.json` | `_meta/design-input-digest.json` (STRIPPED) |

---

## 4. Shared `_meta/` templates (2)

| # | Template path | Output target |
|---|--------------|--------------|
| 11 | `_meta/deferred-findings-template.md` | `work/wf-design/deferred-findings.md` (conditional) |
| 12 | `_meta/phase-summary.template.md` | `sessions/{id}/phase-summary.md` (CORE-028) |

---

## 5. Per-phase template usage

| Phase | Template(s) READ | Output |
|-------|------------------|--------|
| 0 | `design-status.json` + `design-plan.md` + `checkpoint.json` | sessions/{id}/* + flat sync |
| 0.5 | (workload-report template inline) | sessions/{id}/workload-report.md |
| 1 | `P3-01-architecture.md` | `phase3-architecture/P3-01-architecture.md` |
| 2 | `api-contract.md`, `database-design.md`, `infra-spec.md` | `phase3-architecture/technical-specs/*.md` |
| 3 | `integration-map.md` | `phase3-architecture/technical-specs/integration-map.md` |
| 5 | `stakeholder-review.md` | `phase3-architecture/stakeholder-review.md` |
| 6 | (design-summary inline schema) | `work/wf-design/design-summary.json` + sessions/{id}/ |
| 6 | `deferred-findings-template.md` | `work/wf-design/deferred-findings.md` (conditional) |
| 7 | (gap report templates inline) | `work/legacy-scan/gap-report.md`, `gap-categories.json`, `action-items.json` |
| 8 | `design-input-digest.template.json` + `phase-summary.template.md` | `_meta/design-input-digest.json` STRIPPED + `sessions/{id}/phase-summary.md` |

---

## 6. Template Strip (ADR-OPT-05, CORE-031.b)

Phase 8 BẮT BUỘC strip recursive `_*` keys trước khi ghi canonical:
- `_meta/design-input-digest.json`
- `work/legacy-scan/action-items.json` (Phase 7 LEGACY)

Working artifacts (sessions/{id}/) GIỮ helper keys.

---

## 7. Template versioning

| Template | Version | Khi nào bump |
|----------|---------|--------------|
| `design-status.json` | v1.0 | Phase tracking schema change |
| `P3-01-architecture.md` | v1.0 | Section structure change |
| `design-input-digest.template.json` | v1.0 | Consumer schema change (wf-implement-feature) |

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031, ADR-OPT-05
- File contract: [04-file-contract.md](04-file-contract.md)
- Source: [`.claude/skills/workflow/wf-design/templates/`](../../../.claude/skills/workflow/wf-design/templates/) + [`.claude/doc-framework/phase3-architecture/`](../../../.claude/doc-framework/phase3-architecture/)
