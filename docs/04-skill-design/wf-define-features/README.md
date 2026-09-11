# wf-define-features — Design Canon

> **Skill:** `wf-define-features` (v3.2.0)
> **Owner:** DEVKIT core team — Eureka (IT — ERK Transport)
> **Cập nhật lần cuối:** 2026-05-15

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Skill author tạo skill mới (tham khảo)** | 01-vision → 04-file-contract §dual-schema feature-briefs |
| **Skill author sửa procedure** | 08-tradeoffs-adr → 07-procedures-structure |
| **Reviewer PR** | 09-evals → 04-file-contract §registry safe-write `features[]` + W4.7 |

---

## 2. Tóm tắt 1 dòng

`wf-define-features` — Chuyển `requirements[]` thành `features[]` qua 11 phases với **Referential Integrity Fix** (v3.1) + **Cross-Module Entity Detection** (v3.2 W4.7) + **CF6 Cross-FEAT Ref Detection** (v3.3) + dual-schema `feature-briefs.json` (working ≠ digest).

**Trigger:** `/wf-define-features [scope] [--status] [--resume] [--from-scan=<id>] [--auto-stub-requirements]`
**Phase trong workflow:** Phase 2 — Feature Definition (sau `wf-analyze-requirements`, trước `wf-design`)
**Đầu vào chính:** `phase1-business/` + `req-registry.json` (requirements[]) + optional scan baseline
**Đầu ra chính:** `phase2-features/[sys]/[mod]/*.md` + registry `features[]` + dual-schema `feature-briefs.json`

---

## 3. Files (9)

| # | File | Trạng thái |
|---|------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | ✅ |
| 02 | [02-arguments.md](02-arguments.md) | ✅ |
| 03 | [03-phase-routing.md](03-phase-routing.md) | ✅ |
| 04 | [04-file-contract.md](04-file-contract.md) | ✅ |
| 05 | [05-error-codes.md](05-error-codes.md) | ✅ |
| 06 | [06-templates-list.md](06-templates-list.md) | ✅ |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | ✅ |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | ✅ |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | ✅ |

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/wf-define-features/`](../../../.claude/skills/workflow/wf-define-features/)
- Review checklist: [`../../05-review-standards/wf-define-features.md`](../../05-review-standards/wf-define-features.md)
- Standards áp dụng: CORE-006 (safe-write `features[]`), CORE-007 (cross-skill paths), CORE-031 (Template Usage), CORE-032 (Lazy-Load)
- Patterns dùng: [lazy-load](../../03-design-patterns/01-lazy-load-procedures.md), [parallel-lane](../../03-design-patterns/04-parallel-lane-dispatch.md), [cdg-gate](../../03-design-patterns/10-cdg-gate.md)
