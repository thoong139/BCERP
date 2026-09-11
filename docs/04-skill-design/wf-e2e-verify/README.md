# wf-e2e-verify — Design Canon

> **Skill:** `wf-e2e-verify` (v8.0.0)
> **Owner:** DEVKIT core team — Eureka (IT — ERK Transport)
> **Cập nhật lần cuối:** 2026-05-15

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Sub-skill author** (F0/F0a/F1-F8) | 03-phase-routing → 04-file-contract §SSOT JSONs ownership |
| **Skill author sửa orchestrator** | 08-tradeoffs-adr → 03-phase-routing → 05-error-codes |
| **Reviewer PR sửa orchestrator** | 09-evals → 04-file-contract §anti-loop |
| **End-user gặp pipeline fail** | [`../../06-user-guides/per-skill/wf-e2e-verify.md`](../../06-user-guides/per-skill/) (nếu có) hoặc `--status` |

---

## 2. Tóm tắt 1 dòng

`wf-e2e-verify` — **ORCHESTRATOR** điều phối 11 sub-skills (F0/F0a/F0b/F1-F8) chạy E2E test 1 feature đầy đủ: infra check → finding (FIND only) → seed manifest → code-based test → browser live → unblock/implement/retest/fix → scenario + demo, với anti-loop F6↔F5 và backward-compat legacy flags.

**Trigger:** `/wf-e2e-verify <FEAT-ID> [flags]`
**Phase trong workflow:** Sau `wf-implement-feature` — verify feature đã hoạt động end-to-end
**Đầu vào chính:** `<FEAT-ID>` + `req-registry.json` + feature spec (≥500 bytes) + 11 sub-skill dirs
**Đầu ra chính:** `e2e-status.json` (SSOT 8-step) + `orchestrator-summary.md` + `phase-summary.md` + outputs F0-F8

---

## 3. Files (9)

| # | File | Mục đích | Trạng thái |
|---|------|----------|-----------|
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision orchestrator, problem statement | ✅ |
| 02 | [02-arguments.md](02-arguments.md) | 14 args + legacy flag backward-compat | ✅ |
| 03 | [03-phase-routing.md](03-phase-routing.md) | 11-step pipeline F0→F8 + Mermaid + skip rules + anti-loop | ✅ |
| 04 | [04-file-contract.md](04-file-contract.md) | SSOT JSONs ownership (issues/block-test/implement-required/manual) + e2e-status | ✅ |
| 05 | [05-error-codes.md](05-error-codes.md) | Namespace E001-E089 (orchestrator + delegated sub-skills) | ✅ |
| 06 | [06-templates-list.md](06-templates-list.md) | 4 orchestrator templates + per-skill duplication | ✅ |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | 7 procedures (_shared, orchestrate, skip-rules, legacy-flags, resume-status, phase0/phase1.5) | ✅ |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 6 ADR (monolithic→orchestrator, anti-loop, backward-compat, --strict-evidence, --no-playwright deprecate, F0a FIND-only) | ✅ |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | 9 evals (full pipeline, skip, anti-loop, legacy flags, resume, status) | ✅ |

---

## 4. Liên kết

- Skill source: [`.claude/skills/workflow/wf-e2e-verify/`](../../../.claude/skills/workflow/wf-e2e-verify/)
- Review checklist: [`../../05-review-standards/wf-e2e-verify.md`](../../05-review-standards/wf-e2e-verify.md)
- 8 sub-skills: F0 `wf-e2e-infra-check`, F0a `wf-e2e-finding`, F0b `wf-e2e-seed-manifest`, F1 `wf-e2e-test`, F2 `wf-e2e-browser`, F3 `wf-e2e-unblock`, F4 `wf-e2e-implement`, F5 `wf-e2e-retest`, F6 `wf-e2e-fix`, F7 `wf-e2e-scenario`, F8 `wf-e2e-demo`
- Standards áp dụng: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) — Orchestrator pattern
- Patterns dùng: [lazy-load-procedures](../../03-design-patterns/01-lazy-load-procedures.md), [ci-first-integration](../../03-design-patterns/02-ci-first-integration.md), [cross-skill-artifacts](../../03-design-patterns/03-cross-skill-artifacts.md), [parallel-lane-dispatch](../../03-design-patterns/04-parallel-lane-dispatch.md), [checkpoint-resume](../../03-design-patterns/06-checkpoint-resume.md), [playwright-3-modes](../../03-design-patterns/07-playwright-3-modes.md), [multi-session-locking](../../03-design-patterns/09-multi-session-locking.md)
