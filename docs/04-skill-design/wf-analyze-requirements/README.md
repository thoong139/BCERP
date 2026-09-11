# wf-analyze-requirements — Design Canon

> **Skill:** `wf-analyze-requirements` (v3.0.0)
> **Owner:** DEVKIT core team — Eureka (IT — ERK Transport)
> **Cập nhật lần cuối:** 2026-05-15

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **BA/Domain expert agent author** | 01-vision → 03-phase-routing § Lane Dispatch + 04-file-contract §Lane signals |
| **Skill author sửa procedure** | 08-tradeoffs-adr → 07-procedures-structure → file bị ảnh hưởng |
| **Reviewer PR** | 09-evals → 04-file-contract §SSOT registry safe-write |
| **End-user xem progress** | `--status` mode, hoặc [`../../06-user-guides/huong-dan-su-dung.md`](../../06-user-guides/huong-dan-su-dung.md) §wf-analyze-requirements |

---

## 2. Tóm tắt 1 dòng

`wf-analyze-requirements` — Huy động **BA + Domain Experts** phân tích requirements 14 phases (Phase 0 context → Phase 8c handoff), parallel lane dispatch per department, workload gate + signal aggregation + CDG anti-loop, sinh Phase 1 business docs + cập nhật registry `requirements[]`.

**Trigger:** `/wf-analyze-requirements [scope] [--status] [--resume] [--session=<id>]`
**Phase trong workflow:** Phase 1 — Business Analysis (sau `wf-brainstorm`, trước `wf-define-features`)
**Đầu vào chính:** `phase0-brainstorm/` + `req-registry.json` (seed) + optional `legacy-decisions.json`
**Đầu ra chính:** `phase1-business/{departments/*.md, P1-01-overview, P1-02-workflow, stakeholder-review}` + registry `requirements[]` + handoff digests

---

## 3. Files (9)

| # | File | Mục đích | Trạng thái |
|---|------|----------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision BA-first orchestration | ✅ |
| 02 | [02-arguments.md](02-arguments.md) | 4 args (scope/status/resume/session) | ✅ |
| 03 | [03-phase-routing.md](03-phase-routing.md) | 14 phases routing + Mermaid + Lane Dispatch + Workload Gate | ✅ |
| 04 | [04-file-contract.md](04-file-contract.md) | PRE/POST-GATE + session isolation + Lane signals SSOT + cross-skill | ✅ |
| 05 | [05-error-codes.md](05-error-codes.md) | E000-E099 + CDG-A01/A02 | ✅ |
| 06 | [06-templates-list.md](06-templates-list.md) | 9 templates (skill-local) + 4 shared `_shared/templates/` | ✅ |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | 16 procedure files (lazy-load) + `_shared` module imports | ✅ |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 6 ADR-OPT (Lane, Session, Workload, Aggregator, Template Strip, BA-first) | ✅ |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | 20 evals (ERP/CRM/Healthcare/Logistics/Legacy/session-isolation/...) | ✅ |

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/wf-analyze-requirements/`](../../../.claude/skills/workflow/wf-analyze-requirements/)
- Review checklist: [`../../05-review-standards/wf-analyze-requirements.md`](../../05-review-standards/wf-analyze-requirements.md)
- Shared modules: [`.claude/skills/workflow/_shared/`](../../../.claude/skills/workflow/_shared/) — lane, partition, aggregate, cache, cdg
- Standards áp dụng: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md), [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) (PRIMARY role)
- Patterns dùng: [lazy-load-procedures](../../03-design-patterns/01-lazy-load-procedures.md), [parallel-lane-dispatch](../../03-design-patterns/04-parallel-lane-dispatch.md), [agent-prompt-template](../../03-design-patterns/05-agent-prompt-template.md), [checkpoint-resume](../../03-design-patterns/06-checkpoint-resume.md), [cdg-gate](../../03-design-patterns/10-cdg-gate.md)
