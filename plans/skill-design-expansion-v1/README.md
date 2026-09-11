# Plan — skill-design-expansion-v1

> **Trạng thái:** 🔄 IN PROGRESS · **Ngày bắt đầu:** 2026-05-15 · **Owner:** Eureka (IT — ERK Transport)
> **Parent:** Follow-up của [`docs-restructure-v1`](../docs-restructure-v1/) — COMPLETED.

---

## Mục đích

Mở rộng `docs/04-skill-design/` để mọi skill complex có folder design canon riêng (9 file). Hiện chỉ 2/43 skills có folder (wf-fix-bugs, wf-legacy-scan). Mục tiêu Tier 1: bổ sung 5 skill critical.

Lợi ích chính:
- Contributor mới hiểu skill mà không phải đọc source `.claude/skills/`
- Bake design decisions thành tài liệu — giảm drift khi sửa
- Match chuẩn `02-standards/02-skill-standard.md` §10

---

## Files trong plan

| File | Mục đích |
|------|---------|
| [00-master-plan.md](00-master-plan.md) | Vision + skill ranking + DoD + checklist |
| [progress.md](progress.md) | Per-skill tracker + resume protocol + history |

---

## Tier ranking

### Tier 1 — Critical (5 skill, đang làm)

| # | Skill | Version | Lý do critical |
|---|-------|---------|---------------|
| 1 | wf-implement-feature | v4.0 | Dev dùng nhiều nhất, CORE-020 safety gate, spawns agents |
| 2 | wf-e2e-verify | v8.0 | Pipeline 11-step F0→F8, B1/B2/B3 features |
| 3 | wf-analyze-requirements | v2.1 | Multi-agent per dept, 14 phases |
| 4 | wf-design | v3.0 | 7 agent types, Phase 7 LEGACY-only |
| 5 | wf-define-features | v2.1 | Dual-schema digest, 4 producers |

### Tier 2 — High (5 skill, sau Tier 1)

| # | Skill | Version | Lý do |
|---|-------|---------|------|
| 6 | wf-plan-modules | v1.7 | CORE-019 Feature-Level Code Verification |
| 7 | wf-brainstorm | v8.1 | Entry point, branching NEW/LEGACY |
| 8 | wf-preflight | v3.x | Multi-scope health check |
| 9 | wf-manage-change | v3.0 | 11 bash scripts, change-impact.json cross-skill |
| 10 | wf-fix-execute | n/a | Spawned executor cho fix pipeline |

### Tier 3 — Medium (defer)

Các skill còn lại: wf-prepare-deployment, wf-design-ux, wf-add-scope, wf-verify-sync, wf-annotate-code, 11 lane skills (wf-fix-functional, wf-fix-business, ...).

---

## Liên kết

- Parent project: [`../docs-restructure-v1/`](../docs-restructure-v1/) (COMPLETED)
- Template: [`../../docs/04-skill-design/_template/`](../../docs/04-skill-design/_template/)
- Standard: [`../../docs/02-standards/02-skill-standard.md`](../../docs/02-standards/02-skill-standard.md)
- Chuẩn vàng: [`../../docs/04-skill-design/wf-fix-bugs/`](../../docs/04-skill-design/wf-fix-bugs/), [`../../docs/04-skill-design/wf-legacy-scan/`](../../docs/04-skill-design/wf-legacy-scan/)
