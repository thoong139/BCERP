# Phase 4 — Documentation + Cross-Skill Sign-off

> **Tạo:** 2026-04-23
> **Trạng thái:** COMPLETE — thực hiện 2026-04-23.
> **Prerequisite:** `phase3-rollout-order.md` §8 Sign-off Criteria PASS — 4/4 skills rolled out.

---

## 1. Mục tiêu Phase 4

1. Update `ADR-downstream-skills-optimization-signoff.md` với evidence từ cả 5 skills (analyze-req + 4 skills Phase 3).
2. Update `CLAUDE.md` — skill descriptions + phase counts (nếu cần).
3. Update `docs/project-description.md` — value proposition cho ADR-OPT.
4. Update orchestrator skills (`workflows/new-project|existing-project|feature-addition`) — version refs.
5. Update `.claude/rules/00-core.md §4b` — add session artifacts + latest pointer rows.
6. Cross-skill integration audit — zero broken cross-refs.

---

## 2. Sign-off Matrix (5/5 skills COMPLETE)

| Skill | Version | F1 SKILL.md | F2 Schema Sync | F3 Session Isolation | F4 Workload Gate | F5 Lane Dispatch | Sign-off Date |
|-------|---------|------------|----------------|---------------------|-----------------|-----------------|---------------|
| wf-analyze-requirements | 3.0.0 | ✅ | ✅ (node) | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | ✅ ADR-OPT-01 | 2026-04-23 |
| wf-define-features | 3.0.0 | ✅ | ✅ | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | ✅ ADR-OPT-01 | 2026-04-23 |
| wf-design | 4.0.0 | ✅ | ✅ | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | ✅ ADR-OPT-01 | 2026-04-23 |
| wf-design-ux | 4.0.0 | ✅ | ✅ | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | ✅ ADR-OPT-01 | 2026-04-23 |
| wf-plan-modules | 3.0.0 | ✅ | ✅ | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | ✅ ADR-OPT-01 | 2026-04-23 |

Evidence chi tiết: xem `ADR-downstream-skills-optimization-signoff.md` §Phase 3.1-3.4 DONE.

Tham chiếu `_shared/lane`, `_shared/partition`, `_shared/aggregate`, `_shared/cdg` — verify module versions unchanged.

---

## 3. Cross-Skill E2E Smoke Tests

| Scenario | Skills chain | Success |
|----------|--------------|---------|
| A — New project | brainstorm → … → prepare-deployment | Canonical `_meta/*.json` không `_template_notes`, `latest` pointer đúng, impl_status không downgrade |
| B — Existing project | legacy-scan → … → prepare-deployment | LEGACY_MODE OK, `legacy-decisions.json` propagate, gap analysis integrate |
| C — Feature addition | add-scope → define-features → design → design-ux → plan-modules | Append-only registry, existing features unchanged |

Chi tiết test scripts deferred sang `phase5-integration-test-plan.md`.

---

## 4. Documentation Updates Checklist

- [x] `CLAUDE.md`: skill table đã chính xác — không cần thay đổi version numbers (bảng dùng lệnh, không version)
- [x] `docs/project-description.md`: fix "Qwen Code" → "Claude Code"; thêm ADR-OPT value prop section + session-scoped work/ structure; thêm table ADR-OPT-01/02/03/04/05/08
- [x] `wf-define-features/SKILL.md`: bump v2.1.0 → v3.0.0, changelog v3.0.0, description + Phase Mapping table cập nhật (phase0.5-workload-gate + phase0.5-legacy-impl-seed)
- [x] `wf-plan-modules/SKILL.md`: bump v1.7.0 → v3.0.0, changelog v3.0.0 với ADR-OPT details
- [x] `.claude/rules/00-core.md §4b`: thêm 10 session artifact rows (session-state.json + phase-summary.md) cho 5 skills (analyze-req, define-features, design, design-ux, plan-modules)
- [x] Orchestrator skills (new-project, existing-project, feature-addition): đã ở v4.0.0 — không cần thay đổi version refs

---

## 5. Phase 4 Exit Criteria

- [x] Sign-off matrix 5/5 skills complete — xem `ADR-downstream-skills-optimization-signoff.md` §Sign-off Matrix
- [ ] 3 E2E smoke tests (A, B, C) PASS — deferred sang `phase5-integration-test-plan.md` (chưa có project test thực tế)
- [x] Cross-skill integration audit: zero broken cross-refs — session paths nhất quán, canonical `_meta/` paths verified
- [ ] Commit + tag `adr-opt-phase3-complete` — pending sau khi E2E tests pass

---

## 6. Evidence Summary

| Item | File thay đổi | Mô tả |
|------|--------------|-------|
| SKILL.md version fix | `wf-define-features/SKILL.md` | v2.1.0 → v3.0.0 |
| SKILL.md version fix | `wf-plan-modules/SKILL.md` | v1.7.0 → v3.0.0 |
| ADR signoff | `ADR-downstream-skills-optimization-signoff.md` | Thêm Phase 3.1-3.4 DONE + Sign-off Matrix 5/5 |
| Project desc | `docs/project-description.md` | Fix "Qwen Code", ADR-OPT value prop, session-scoped work/ |
| Core rules | `.claude/rules/00-core.md §4b` | +10 session artifact rows cho 5 skills |
| Phase 4 doc | `docs/design/skills/phase4-documentation-signoff.md` | Này — trạng thái COMPLETE |

---

## 7. Tham chiếu

- `docs/design/skills/ADR-downstream-skills-optimization-signoff.md`
- `docs/design/skills/phase2-validation-tests.md` (F1-F10 template)
- `docs/design/skills/phase3-rollout-order.md` §8
- `docs/design/skills/phase5-integration-test-plan.md` (next phase)
