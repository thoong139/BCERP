# wf-implement-feature — Design Canon

> **Skill:** `wf-implement-feature` (v5.2.0)
> **Owner:** DEVKIT core team — Eureka (IT — ERK Transport)
> **Cập nhật lần cuối:** 2026-05-15

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Skill author tạo skill mới (tham khảo)** | 01-vision → 03-phase-routing → 04-file-contract → 07-procedures-structure |
| **Skill author sửa skill** | 08-tradeoffs-adr → 03-phase-routing → file bị ảnh hưởng |
| **Reviewer review PR sửa skill** | 09-evals → 04-file-contract → 05-error-codes |
| **End-user gặp bug khi implement** | [`../../06-user-guides/huong-dan-su-dung.md`](../../06-user-guides/huong-dan-su-dung.md) §wf-implement-feature |

---

## 2. Tóm tắt 1 dòng

`wf-implement-feature` — Triển khai code cho 1 hoặc nhiều feature theo TDD + parallel review, hỗ trợ 3 scenarios (NEW/EXTEND/MODIFY), 4 profiles, multi-session resume, cross-skill `--from-fix-bugs`.

**Trigger:** `/wf-implement-feature [feature-name | REQ-ID] [flags]`
**Phase trong workflow:** Phase 5 — Implementation (sau `wf-plan-modules`, trước `wf-verify-sync`)
**Đầu vào chính:** `phase2-features/[sys]/[mod]/*.md` + task files `phase5-implementation/tasks/...` + `req-registry.json`
**Đầu ra chính:** Source code + tests + `impl-status.json` + `impl-report.md` + `phase-summary.md` + registry `impl_status=done`

---

## 3. Files (9)

| # | File | Mục đích | Trạng thái |
|---|------|----------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | Tại sao có skill, mục tiêu, nguyên tắc | ✅ |
| 02 | [02-arguments.md](02-arguments.md) | 16 args + 4 profiles + 3 scenarios + interactions | ✅ |
| 03 | [03-phase-routing.md](03-phase-routing.md) | Phase routing 10 procedures + flow-multi + Mermaid | ✅ |
| 04 | [04-file-contract.md](04-file-contract.md) | PRE/POST-GATE + system-grouped paths + cross-skill produces_for/consumes_from | ✅ |
| 05 | [05-error-codes.md](05-error-codes.md) | Namespace E1xx-E9xx + alias map E001-E014 + auto-fix | ✅ |
| 06 | [06-templates-list.md](06-templates-list.md) | 15 templates (status/plan/report/checkpoint/qa-review/...) | ✅ |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | 14 procedure files outline + state vars + lazy-load | ✅ |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 6 ADR (system-grouped, per-feature lock, profile, cache, --from-fix-bugs, safety gate) | ✅ |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | 19 evals từ evals.json (smoke/resume/extend/profile/cache/...) | ✅ |

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/wf-implement-feature/`](../../../.claude/skills/workflow/wf-implement-feature/)
- Review checklist: [`../../05-review-standards/wf-implement-feature.md`](../../05-review-standards/wf-implement-feature.md)
- User guide: [`../../06-user-guides/huong-dan-su-dung.md`](../../06-user-guides/huong-dan-su-dung.md) §wf-implement-feature
- Standards áp dụng: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md), [CORE-019](../../02-standards/01-core-rules-index.md), [CORE-020](../../02-standards/01-core-rules-index.md)
- Patterns dùng: [lazy-load-procedures](../../03-design-patterns/01-lazy-load-procedures.md), [ci-first-integration](../../03-design-patterns/02-ci-first-integration.md), [parallel-lane-dispatch](../../03-design-patterns/04-parallel-lane-dispatch.md), [auto-detect-fallback](../../03-design-patterns/08-auto-detect-fallback.md)
