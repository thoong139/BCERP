# wf-design — Design Canon

> **Skill:** `wf-design` (v4.0.0)
> **Owner:** DEVKIT core team — Eureka (IT — ERK Transport)
> **Cập nhật lần cuối:** 2026-05-15

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Architect agent author** | 01-vision → 03-phase-routing § Lane Dispatch per system + 04-file-contract §Signal Aggregation |
| **Skill author sửa procedure** | 08-tradeoffs-adr → 07-procedures-structure → file bị ảnh hưởng |
| **Reviewer PR** | 09-evals → 04-file-contract §registry safe-write (design_status) |
| **End-user** | `--status` mode, hoặc [`../../06-user-guides/huong-dan-su-dung.md`](../../06-user-guides/huong-dan-su-dung.md) §wf-design |

---

## 2. Tóm tắt 1 dòng

`wf-design` — Chuyển feature specs thành **technical design đầy đủ** (Phase 3 architecture, API, database, infra) qua **11 phases với Lane Dispatch per system** + **Signal Aggregation dual-dedup** + **Phase 7 Gap Analysis LEGACY-only**, sinh `phase3-architecture/` docs + cập nhật registry `design_status`.

**Trigger:** `/wf-design [target] [--status] [--resume] [--from-scan=<id|path>]`
**Phase trong workflow:** Phase 3 — Technical Design (sau `wf-define-features`, trước `wf-design-ux` hoặc `wf-plan-modules`)
**Đầu vào chính:** `phase2-features/` + `req-registry.json` (features[]) + optional `target-map.json` (scan baseline)
**Đầu ra chính:** `phase3-architecture/{P3-01-architecture, technical-specs/{api-contract, database-design, infra-spec, integration-map}, stakeholder-review}.md` + `design-summary.json` + `design-input-digest.json` + registry `design_status="completed"`

---

## 3. Files (9)

| # | File | Mục đích | Trạng thái |
|---|------|----------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision — biến requirements thành actionable design | ✅ |
| 02 | [02-arguments.md](02-arguments.md) | 4 args (target/status/resume/--from-scan) | ✅ |
| 03 | [03-phase-routing.md](03-phase-routing.md) | 11 phases routing + Mermaid + LEGACY branching | ✅ |
| 04 | [04-file-contract.md](04-file-contract.md) | Session isolation + 7 agents + cross-skill produces_for | ✅ |
| 05 | [05-error-codes.md](05-error-codes.md) | E000-E016 + auto-fix budget | ✅ |
| 06 | [06-templates-list.md](06-templates-list.md) | 3 internal + 6 doc-framework + digest + strip | ✅ |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | 11 procedure files outline | ✅ |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 5 ADR-OPT (Lane per system, Session, Workload, Aggregator dual-dedup, Strip) + 2 architectural | ✅ |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | 6 evals (new/LEGACY/multi-session LPM/--from-scan/...) | ✅ |

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/wf-design/`](../../../.claude/skills/workflow/wf-design/)
- Review checklist: [`../../05-review-standards/wf-design.md`](../../05-review-standards/wf-design.md)
- Cross-skill: produces digest cho `wf-implement-feature`, consume target-map từ `wf-scan-target`
- Standards áp dụng: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md), [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) (PRIMARY `design_status`)
- Patterns dùng: [lazy-load](../../03-design-patterns/01-lazy-load-procedures.md), [ci-first](../../03-design-patterns/02-ci-first-integration.md), [parallel-lane](../../03-design-patterns/04-parallel-lane-dispatch.md), [checkpoint-resume](../../03-design-patterns/06-checkpoint-resume.md)
