# Phase 3 — Rollout Order + Dependency Matrix

> **Tạo:** 2026-04-23
> **Mục đích:** Thứ tự triển khai 4 skills trong Phase 3 + dependency matrix + rollback plan.
> **Prerequisite:** Đọc `phase3-rollout-design-principles.md` + 4 skill specs (`phase3-wf-*.md`).
> **Hướng dẫn sử dụng:** Mỗi skill rollout **1 phiên riêng** — không gộp.

---

## 1. Critical Path (thứ tự bắt buộc)

```
Phase 3.1 — wf-define-features  v2.1.0 → v3.0.0  (spec: phase3-wf-define-features.md)
    │   • Ít phụ thuộc nhất, pattern gần analyze-req nhất
    │   • Breaking change risk: LOW
    │   • Estimated duration: 1 phiên (~60-90 min)
    ▼
Phase 3.2 — wf-design           v3.0.0 → v4.0.0  (spec: phase3-wf-design.md)
    │   • Phụ thuộc feature-briefs.json từ wf-define-features
    │   • Breaking change risk: MEDIUM (dual dedup key)
    │   • Estimated duration: 1 phiên (~90-120 min)
    ▼
Phase 3.3 — wf-design-ux        v3.0.0 → v4.0.0  (spec: phase3-wf-design-ux.md)
    │   • Conditional (skip nếu api-only) — phụ thuộc design-input-digest.json
    │   • Breaking change risk: LOW
    │   • Estimated duration: 1 phiên (~60-90 min)
    ▼
Phase 3.4 — wf-plan-modules     v1.7.1 → v3.0.0  (spec: phase3-wf-plan-modules.md)
    •   Phụ thuộc tất cả 3 skill trên (digests)
    •   Breaking change risk: HIGH (nhiều outputs, topological dispatch đặc thù)
    •   Estimated duration: 1 phiên (~120-150 min)
```

**Lý do thứ tự:**
1. **wf-define-features đầu** — pattern nhất quán với `wf-analyze-requirements` (đã sign-off), dễ áp dụng, risk thấp nhất.
2. **wf-design kế tiếp** — cần feature-briefs digest từ skill 1; dual dedup key (component_id + api_id) là design pattern mới cần validate trước khi rollout skill khác.
3. **wf-design-ux trước wf-plan-modules** — conditional skip logic (api-only) là edge case đặc thù, rollout trước skill cuối để pattern conditional được validate.
4. **wf-plan-modules cuối** — HIGH risk do topological lane dispatch + nhiều downstream consumers; cần 3 skill trên ổn định làm input.

---

## 2. Dependency Matrix

| Skill | Produces (cho downstream) | Consumes (từ upstream) | Breaking change risk |
|-------|---------------------------|------------------------|---------------------|
| **wf-define-features v3.0.0** | `_meta/feature-briefs.json` (digest) + `phase2-features/**/**/*.md` + `req-registry.json.features[]` + `deferred-findings.md` + `ui-coverage-gaps.json` (LEGACY) | `_meta/dept-digests.json` + `_meta/phase1-handoff.json` + `phase1-business/stakeholder-review.md` | **LOW** — `registry_scope.fields_owned` unchanged, feature-briefs schema unchanged |
| **wf-design v4.0.0** | `_meta/design-input-digest.json` (digest) + `phase3-architecture/*.md` + `technical-specs/*.md` + `req-registry.json.design_status` + `design-summary.json` + `design-report.md` + gap-report.md (LEGACY) | `_meta/feature-briefs.json` + `phase2-features/**/**/*.md` + `req-registry.json.features[]` + `deferred-findings.md` | **MEDIUM** — dual dedup key + session path; downstream schema unchanged nhưng cần verify session→canonical sync |
| **wf-design-ux v4.0.0** | `_meta/ux-input-digest.json` (digest, chỉ khi not api-only) + `phase4-ux/*/*/screens-*.md` + `phase4-ux/design-system.md` + `phase4-ux/*/Navigation-*.md` + `req-registry.json.ux_design_status` | `_meta/design-input-digest.json` + `phase3-architecture/*.md` + `req-registry.json.interface_type` | **LOW** — conditional skip logic isolated ở Phase 0.5.0; wf-plan-modules đã handle trường hợp thiếu ux digest |
| **wf-plan-modules v3.0.0** | `phase5-implementation/module-plan.md` + `dependency-graph.md` + `P5-00-implementation-roadmap.md` + `sprints/S{NN}-*.md` + `tasks/**/**/*-impl.md` + `req-registry.json.implementation_order` + `impl_status` | `_meta/feature-briefs.json` + `_meta/design-input-digest.json` + `_meta/ux-input-digest.json` (conditional) + `phase4-ux/*.md` (conditional) + `phase3-architecture/*.md` | **HIGH** — nhiều outputs + topological dispatch đặc thù + `wf-implement-feature` HIGH dependency on paths |

---

## 3. Per-Skill Rollout Session Procedure

Mỗi phiên rollout **1 skill** phải follow template sau. Mỗi phiên sẽ dùng 4 shared modules: `_shared/partition` (workload gate), `_shared/lane` (dispatch), `_shared/aggregate` (dedup), `_shared/cdg` (override tokens).

### 3.1. Pre-flight Checks (trước khi start)

- [ ] Đọc `phase3-rollout-design-principles.md` full
- [ ] Đọc spec skill tương ứng (`phase3-wf-{skill}.md`) full
- [ ] Verify previous skill sign-off: `grep "Phase 3.X DONE" docs/design/skills/ADR-downstream-skills-optimization-signoff.md`
- [ ] Verify `_shared/partition/`, `_shared/lane/`, `_shared/aggregate/`, `_shared/cdg/` modules stable: `./.claude/scripts/validate-schema-sync.sh _shared`
- [ ] Git status clean cho skill target: `git status .claude/skills/workflow/wf-{skill}/ | grep -q "clean\|nothing to commit"`

### 3.2. Execution Steps (theo spec skill)

1. SKILL.md + _contract.json bump (version, procedure_files[], outputs.working[], Template Usage Rule table)
2. Rename phase files nếu cần (atomic với references update)
3. Tạo mới `phase0.5-workload-gate.md`
4. Update `_shared.md` (4 variables + 2-3 sections mới)
5. Update `phase0-context.md` / `phase0-init.md` (Step 0.2b session creation)
6. Update primary lane phase (Lane Dispatch)
7. Update consolidate phase (Signal Aggregation)
8. Update handoff phase (Template Strip + Atomic Write)
9. Chạy V1-V10 verify checklist từ spec

### 3.3. Post-flight Validation

- [ ] V1-V10 PASS theo spec skill
- [ ] `./.claude/scripts/skill-compliance-audit.sh wf-{skill}` PASS
- [ ] `./.claude/scripts/validate-schema-sync.sh wf-{skill}` PASS
- [ ] Evals thêm ≥3 test cases mới
- [ ] `/audit-devkit-scan` + `/audit-devkit-verify --skill=wf-{skill}` + `/audit-devkit-fix`
- [ ] Integration test với skill tiếp theo (nếu có — xem §4)

### 3.4. Sign-off Update

Sau mỗi skill DONE:
1. Update `docs/design/skills/ADR-downstream-skills-optimization-signoff.md`:
   - Add row: `| Phase 3.X DONE | wf-{skill} | vN.0.0 | F1-F10 pass | YYYY-MM-DD |`
   - Evidence block: grep counts, audit findings breakdown, integration test result
2. Commit với message: `chore(wf-{skill}): bump to vN.0.0 — ADR-OPT rollout Phase 3.X`

---

## 4. Integration Tests Sau Mỗi Skill

| Sau skill | Integration test | Command / Verify |
|-----------|------------------|------------------|
| **wf-define-features v3.0.0** | `wf-design` consume được `feature-briefs.json` (từ session hoặc canonical) | `/wf-define-features` → verify `_meta/feature-briefs.json` không chứa `_template_notes` → `/wf-design` PRE-GATE PASS |
| **wf-design v4.0.0** | `wf-design-ux` + `wf-plan-modules` consume được `design-input-digest.json` | `/wf-design` → verify `_meta/design-input-digest.json` components + apis deduped → `/wf-design-ux` / `/wf-plan-modules` PRE-GATE PASS |
| **wf-design-ux v4.0.0** | Two scenarios: (A) non-api-only, (B) api-only skip | A: `/wf-design-ux` tạo ux-input-digest.json → `/wf-plan-modules` consume. B: `/wf-design-ux` exit Phase 0.5.0 → `/wf-plan-modules` bypass ux digest |
| **wf-plan-modules v3.0.0** | `wf-implement-feature` read nhiều outputs | `/wf-plan-modules` → verify module-plan.md + sprints/ + tasks/ tồn tại → `/wf-implement-feature {feat}` Phase 0 PASS |

**Integration test fail → rollback về version trước của skill đang rollout**, KHÔNG rollout skills tiếp theo cho đến khi resolve.

---

## 5. Rollback Plan

### 5.1. Scope rollback

- **Per-skill rollback:** Nếu skill N fail (V1-V10 không PASS, hoặc integration test fail), rollback chỉ skill N về version trước:
  - Git revert commits của skill N.
  - Verify `git status .claude/skills/workflow/wf-{skill-N}/` clean.
  - Skills N+1...4 KHÔNG chạy cho đến khi skill N resolve.

### 5.2. Rollback triggers

| Trigger | Action |
|---------|--------|
| V1-V10 verify fail ≥3 items | Rollback + phân tích root cause, sửa spec trước khi re-rollout |
| Compliance audit FAIL | Rollback + fix findings, re-run audit |
| Integration test fail | Rollback + điều tra schema/path mismatch, sửa cả 2 skills nếu cần |
| `_shared/` module bug phát hiện trong rollout | STOP toàn bộ Phase 3 — fix `_shared/` + bump minor (không major) + re-validate Phase 2 (wf-analyze-requirements) cũng |
| Downstream skill (e.g. wf-implement-feature) break do path change | Rollback + cập nhật spec `phase3-wf-plan-modules.md` với path migration guide |

### 5.3. Partial rollout acceptable

Trong trường hợp khẩn:
- Chỉ rollout skills 1-2 (wf-define-features + wf-design) là acceptable nếu wf-design-ux / wf-plan-modules có complication.
- User có thể dùng mix: `wf-define-features v3.0.0` + `wf-design v4.0.0` + `wf-design-ux v3.0.0` (chưa rollout) + `wf-plan-modules v1.7.1` (chưa rollout).
- **ĐIỀU KIỆN:** digest schema unchanged → backward-compat tự nhiên. Session isolation không bắt buộc tất cả skills phải đồng bộ.

### 5.4. Không rollback

Rollback KHÔNG áp dụng cho:
- `wf-analyze-requirements v3.0.0` (đã sign-off Phase 2) — giữ nguyên.
- `_shared/` modules (Phase 1 sign-off) — bug ở _shared phải fix, không rollback.
- Evals test cases — chỉ thêm, không rollback (giữ nguyên evidence).

---

## 6. Parallel Rollout? — KHÔNG ĐƯỢC

| Tình huống | Lý do không parallel |
|-----------|---------------------|
| 2 skills rollout song song | Vi phạm CORE-025: thiếu owner rõ ràng, 2 rollout có thể modify chéo `_shared/`, `ADR-OPT-signoff.md` |
| 1 person rollout + 1 AI test song song | Race condition trong compliance audit outputs + session dir conflicts |
| Dev environment + staging environment parallel | Acceptable NẾU có 2 working dirs riêng và không share `.mc-data/` |

**Kết luận:** Mỗi skill 1 phiên, tuần tự. Nếu cần chia tải, chia theo thời gian (sáng/chiều) thay vì parallel.

---

## 7. Estimated Total Duration

| Skill | Rollout | Validation | Integration Test | Sign-off | Total |
|-------|---------|-----------|------------------|----------|-------|
| wf-define-features | 60-90 min | 20-30 min | 15-20 min | 10 min | **~2h** |
| wf-design | 90-120 min | 30-40 min | 20-30 min | 10 min | **~3h** |
| wf-design-ux | 60-90 min | 20-30 min | 30-40 min (2 scenarios) | 10 min | **~2h30** |
| wf-plan-modules | 120-150 min | 30-40 min | 40-60 min (critical) | 10 min | **~4h** |
| **TOTAL (4 skills)** | — | — | — | — | **~11h30** (2-3 sessions/day × 4-5 days) |

---

## 8. Sign-off Criteria Cho Phase 3 (toàn phase)

Phase 3 PASS khi TẤT CẢ:

- [ ] 4 skills đều ở target version (xem `phase3-rollout-design-principles.md` §1)
- [ ] `registry_scope.fields_owned` UNCHANGED cho tất cả 4 skills
- [ ] F1-F10 final verify checklist PASS cho cả 4 skills (xem `phase2-validation-tests.md` template)
- [ ] `/new-project` E2E smoke test PASS (idea → deployment docs)
- [ ] `/existing-project` E2E smoke test PASS (legacy scan → deployment docs)
- [ ] `/feature-addition` E2E smoke test PASS (add scope → define → design → UX → plan → implement)
- [ ] Sign-off doc updated với evidence cho cả 4 skills
- [ ] Phase 4 (documentation + cross-skill signoff) ready to start

---

## 9. Tham chiếu

| Nguồn | Vai trò |
|-------|---------|
| `docs/design/skills/phase3-rollout-design-principles.md` | Shared Constraints + Variable Map |
| `docs/design/skills/phase3-wf-define-features.md` | Skill 1 spec |
| `docs/design/skills/phase3-wf-design.md` | Skill 2 spec |
| `docs/design/skills/phase3-wf-design-ux.md` | Skill 3 spec |
| `docs/design/skills/phase3-wf-plan-modules.md` | Skill 4 spec |
| `docs/design/skills/phase2-validation-tests.md` | Template F1-F10 validation |
| `docs/design/skills/ADR-downstream-skills-optimization-signoff.md` | Sign-off doc |
| `.claude/rules/00-core.md §4b` | Cross-Skill Output Path Contract |
