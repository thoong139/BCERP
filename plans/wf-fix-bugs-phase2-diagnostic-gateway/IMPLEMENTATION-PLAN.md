# wf-fix-bugs Phase 2 → Diagnostic Gateway — Implementation Plan

> **Status:** APPROVED — Architecture B (Diagnostic Gateway) chosen 2026-05-16
> **Versions:** v10.19 → v10.22 (progressive rollout, 4 sprints)
> **Total effort:** 15-20h spread across 1-2 tháng
> **Driver:** wf-fix-bugs Phase 2 hiện tại quá narrow → không đủ signal cho Phase 3-7 plan/triage/execute/verify tốt

---

## 1. Mission Statement (Phase 2 mới)

> **"Single-pass codebase diagnostic — produce SSOT cho mọi downstream phase consume.
> Sau Phase 2, KHÔNG phase nào được scan codebase từ đầu."**

Phase 2 = **Diagnostic Gateway**, không phải **Enumeration Phase**.

### Nguyên tắc cứng

1. **Single-pass scan** — Phase 2 scan 1 lần, output SSOT files. Phase 3-7 KHÔNG scan lại.
2. **SSOT cho audit** — Phase 7 verify dùng Phase 2 outputs làm baseline để detect regression.
3. **Profile-aware** — `--profile=quick` skip diagnostic (legacy mode); `standard+` full diagnostic.
4. **Cacheable** — output keyed by git HEAD SHA → `--resume` skip Phase 2 nếu cache fresh.
5. **Backward-compat** — schema versioning per output, consumer fallback graceful nếu file missing.

---

## 2. Architecture After Implementation

```
Phase 1 (Init + ISG setup)
      │
      ▼
Phase 2 (DIAGNOSTIC GATEWAY) ───────────────┐
  Outputs SSOT:                              │
  ├─ scope-analysis.json (WHAT)              │  Cache key: git HEAD SHA
  ├─ risk-heatmap.json (WHERE)               │  TTL: 4h available, 1h absent
  ├─ dim-applicability.json (WHICH)          │  Schema versioned independently
  ├─ change-signal.json (CHANGED — v10.22)   │  Atomic write (CORE-035)
  └─ code-inventory.json + doc-inventory.json (legacy retained)
      │
      ▼ (KHÔNG phase nào được scan codebase từ đây trở đi)
Phase 3 Plan ──── workload weighted by risk_score (v10.21)
                  dimension routing per-module (v10.20)
      │
      ▼
Phase 4 Find Bugs ──── lane skills skip dim không applicable (v10.20)
                       lanes ưu tiên hotspot files (v10.21)
      │
      ▼
Phase 5 Triage ──── severity × risk_score ranking (v10.21)
                    domain expert routing per dominant_domain (v10.21)
      │
      ▼
Phase 6 Execute ──── fix order: hotspot CRITICAL → changed → rest (v10.22)
      │
      ▼
Phase 7 Verify ──── consume scope-analysis (baseline) + change-signal (v10.22)
                    detect regression (delta vs baseline)
```

---

## 3. Sprint Breakdown

### Sprint 1 — v10.19: Phase 2 Diagnostic Outputs

**Effort:** 6-8h | **Risk:** Thấp (additive only) | **Default:** OFF (opt-in via `--use-diag`)

#### Deliverables

| Item | Path | Effort |
|------|------|--------|
| Schema `risk-heatmap-v1` | `.claude/skills/workflow/wf-fix-bugs/schemas/risk-heatmap-v1.schema.json` | 0.5h |
| Schema `dim-applicability-v1` | `.claude/skills/workflow/wf-fix-bugs/schemas/dim-applicability-v1.schema.json` | 0.5h |
| Helper script `analyze-risk-heatmap.sh` | `.claude/scripts/wf-fix-bugs/analyze-risk-heatmap.sh` | 1.5h (port + harden từ spike) |
| Helper script `analyze-dim-applicability.sh` | `.claude/scripts/wf-fix-bugs/analyze-dim-applicability.sh` | 1.5h (port + harden từ spike) |
| Phase 2 sub-step 2.3.5 (Optional Diagnostic) | `procedures/phase2-scan.md` Step 2.3.5 | 0.5h |
| Update `scan-and-analyze.sh` orchestrate 2 analyzers | bash | 0.5h |
| Template `risk-heatmap.json` + `dim-applicability.json` | `templates/phase2-scan/` | 0.5h |
| Update Phase2-report.md include risk + dim summary | `templates/phase2-scan/Phase2-report.md` | 0.5h |
| Update `_contract.json` outputs.working[] add 2 entries | bash | 0.3h |
| Add 4 evals (heatmap correctness, dim mapping, schema valid, skip count >0) | `evals/` | 1h |
| Update SKILL.md với `--use-diag` flag doc | `SKILL.md` | 0.2h |

#### Performance Hardening (from spike findings)

1. **Parallel xargs** for git churn — `xargs -P $(nproc)` → 4-8x faster
2. **Default QUICK=1** cho project >2000 files (auto-detect từ Phase 2 file count)
3. **Cache key:** git HEAD SHA + scope name → skip recompute if same
4. **Atomic write** (CORE-035) cho 2 new outputs

#### Acceptance Criteria

- [ ] `risk-heatmap.json` valid schema risk-heatmap-v1
- [ ] `dim-applicability.json` valid schema dim-applicability-v1
- [ ] Cả 2 outputs có audit_chain checksum
- [ ] Phase 2 với `--use-diag`: thêm <60s overhead trên 5K-file project
- [ ] Phase 2 KHÔNG `--use-diag`: hành vi cũ y nguyên (backward-compat)
- [ ] `phase2-routing-smoke-test.sh` mới PASS 100%
- [ ] 4 evals PASS

#### Risk + Mitigation

| Risk | Mitigation |
|------|-----------|
| Pattern detection sai (false positive) | Threshold (≥3 files match) thay vì single-file trigger |
| Performance regression trên large repo | Default QUICK=1 + parallel xargs |
| Schema bumps break downstream | Versioned schema + fallback graceful trong consumer |

---

### Sprint 2 — v10.20: Phase 4 Lane Skip via Dim-Applicability

**Effort:** 3-4h | **Risk:** Thấp (feature flag rollback) | **Default:** ON

#### Deliverables

| Item | Path | Effort |
|------|------|--------|
| Update mọi lane skill PRE-GATE: đọc `dim-applicability.json` | `.claude/skills/workflow/wf-fix-{functional,business,security,...}/procedures/` | 1.5h (11 lanes × ~5 min) |
| Skip module nếu lane's QD ∈ `module.skip_dims[]` | bash check + log SKIP_REASON | 0.5h |
| Update Phase 4 lane prompt template — pass dim-applicability path | `procedures/phase4-find-bugs/D-render-verify.md` + `templates/phase4-lane-agent-prompt.md` | 0.5h |
| Update `phase4-summary.json` schema add `lanes_skipped[]` field | schema bump v1→v2 | 0.3h |
| Add 3 evals (skip works, count accurate, lane reports SKIP) | `evals/` | 0.5h |
| Update Phase4-report.md show skipped lanes + reasons | template | 0.2h |
| Smoke test lane-skip behavior | `phase4-routing-smoke-test.sh` | 0.5h |

#### Acceptance Criteria

- [ ] Lane consume `dim-applicability.json` ở PRE-GATE — graceful fallback nếu file missing
- [ ] Module trong `skip_dims[]` không spawn probes của dim đó
- [ ] `phase4-summary.json` báo `lanes_skipped: N` với reasons
- [ ] Phase4-report.md include "Skipped N probes (saved ~X tokens)"
- [ ] Token saving measurable trên EUREKA test run (target ≥20%)
- [ ] Existing 51/51 Phase 4 smoke tests PASS
- [ ] 3 new evals PASS

#### Risk + Mitigation

| Risk | Mitigation |
|------|-----------|
| Skip dim mà thực ra applicable (false negative) | Threshold conservative (signal phải hiện diện ≥3 file). User override `--no-skip-dims` |
| Phase 4 spawn quá ít agents → miss bugs | A/B test: chạy with/without dim-skip, diff signals. Nếu missing bugs >5% → tighten threshold |
| Lane skill confusion về scope | Pass explicit `MODULE_SCOPE` + `APPLICABLE_DIMS` vào prompt |

---

### Sprint 3 — v10.21: Phase 3 Risk-Weighted + Phase 5 Hotspot Priority

**Effort:** 4-5h | **Risk:** Trung (UX change) | **Default:** ON

#### Deliverables

##### Phase 3 (Workload Gate risk-weighted)

| Item | Effort |
|------|--------|
| Update `plan-isg-partition.sh` consume risk-heatmap.json | 0.5h |
| Workload formula: `workload = sum(file.risk_score)` thay vì pure count | 0.5h |
| CDG-11 threshold tunes for risk-weighted score | 0.3h |
| Update Phase3-report.md show top-5 hotspot files | 0.2h |

##### Phase 5 (Triage Hotspot Priority)

| Item | Effort |
|------|--------|
| Update `wf-fix-triage` skill consume risk-heatmap.json | 0.5h |
| Severity ranking formula: `final = severity × log(risk_score + 1)` | 0.5h |
| Add `dominant_domain` to bug-triage.md per signal | 0.3h |
| Route to domain expert based on `dominant_domain` | 0.3h |
| Update Phase5-report.md show "Top 10 by priority" | 0.3h |

##### Cross-cutting

| Item | Effort |
|------|--------|
| Add 4 evals (workload formula, ranking formula, dominant_domain, top-10 ordering) | 1h |
| Update SKILL.md document risk-weighted behavior | 0.2h |

#### Acceptance Criteria

- [ ] Phase 3 workload report includes `risk_weighted_score`
- [ ] CDG-11 trigger rate decrease ≥30% (false-positive reduction)
- [ ] Phase 5 triage output sorts by `severity × risk_score` not raw severity
- [ ] Top-10 fixes recommended có dominant_domain rõ ràng
- [ ] 4 new evals PASS
- [ ] Existing 35/35 Phase 3 + 42/42 Phase 5 smoke tests PASS

#### Risk + Mitigation

| Risk | Mitigation |
|------|-----------|
| Workload formula tune sai → CDG-11 quá strict/loose | Calibration data từ 3-5 production runs. Configurable threshold via `--workload-threshold` |
| Risk-weighted priority đẩy fake hotspots lên đầu | Spike sample audit: 20 cases random check user-perceived priority |

---

### Sprint 4 — v10.22: Phase 6 Fix Order + Phase 7 Baseline Verify + Change Signal

**Effort:** 5-6h | **Risk:** Trung (verify behavior change) | **Default:** ON

#### Deliverables

##### Change Signal Detection (Spike #1 — finally implemented)

| Item | Effort |
|------|--------|
| Schema `change-signal-v1` | 0.3h |
| Script `analyze-change-signal.sh` (git diff since last `fix-impact.json` or HEAD~N) | 1h |
| Integrate into Phase 2 Step 2.3.5 (Diagnostic Gateway batch) | 0.3h |
| Template `change-signal.json` | 0.2h |

##### Phase 6 (Fix Order)

| Item | Effort |
|------|--------|
| Update `wf-fix-execute` consume risk-heatmap.json + change-signal.json | 0.5h |
| Fix priority queue: hotspot CRITICAL → changed files → rest | 0.5h |
| Update execute-progress.md show "Fixing hotspot N/M" | 0.2h |

##### Phase 7 (Baseline Verify)

| Item | Effort |
|------|--------|
| Phase 7 consume scope-analysis (baseline) + change-signal | 0.5h |
| Verify scope: changed files + impacted files (via ISG) | 0.5h |
| Detect regression: signals exist trong files KHÔNG changed | 0.5h |
| Update Phase7-report.md show "Verified N files, regression detected: 0" | 0.3h |

##### Cross-cutting

| Item | Effort |
|------|--------|
| 5 evals (change-signal correct, fix-order priority, baseline verify, regression detection, schema valid) | 1h |
| Update Phase 6/7 prompts include diagnostic outputs | 0.3h |
| End-to-end E2E test trên EUREKA module fix | 0.5h |

#### Acceptance Criteria

- [ ] `change-signal.json` correctly reports git delta from last `fix-impact.json`
- [ ] Phase 6 execute order: top-N hotspot CRITICAL fixed first (verify trace)
- [ ] Phase 7 verify scope reduced từ "all files" → "changed + impacted only"
- [ ] Verify duration giảm ≥50% trên EUREKA medium test
- [ ] Regression detection trigger nếu fix-impact.json affected_files có signal mới
- [ ] 5 evals PASS
- [ ] E2E test EUREKA PASS
- [ ] Existing 40/40 Phase 6 + 44/44 Phase 7 smoke tests PASS

#### Risk + Mitigation

| Risk | Mitigation |
|------|-----------|
| Phase 7 verify miss regression do scope quá hẹp | Always verify impacted files via ISG, không chỉ changed files. Add `--verify-full` escape hatch |
| change-signal sai khi git history rewritten | Detect via `git reflog` + warn user |
| Fix order priority confuses user | TodoWrite ORCH UI show priority reason ("Fixing CHECKOUT.tsx — hotspot risk_score=87") |

---

## 4. Dependencies Graph

```
v10.19 ─┬─► v10.20 (Phase 4 dim-skip, needs dim-applicability.json)
        │
        ├─► v10.21 (Phase 3+5 risk-weighted, needs risk-heatmap.json)
        │
        └─► v10.22 (Phase 6+7 fix-order/baseline, needs ALL 3 outputs)
```

**Strict ordering:** v10.19 phải merged trước khi v10.20-v10.22 bắt đầu (vì consume từ v10.19 outputs).
**Parallel safe:** v10.20 + v10.21 có thể work song song (different consumers).
**Final integration:** v10.22 phụ thuộc cả v10.20 + v10.21 done.

---

## 5. Migration & Rollback Strategy

### Migration (forward)

- Mỗi sprint version-stamp trong _contract.json
- Schema versioning per output (independent bumps)
- Feature flag `--use-diag` v10.19, default OFF
- v10.20+ default ON nhưng có `--no-diag` escape hatch

### Rollback (backward)

- Mỗi sprint deployable + revertable độc lập
- Consumer skills check schema version, graceful fallback nếu cũ
- Spike outputs preserved tại `plans/wf-fix-bugs-phase2-spike/outputs/` cho regression testing

---

## 6. Open Questions

1. **Threshold calibration:** Risk score 80=CRITICAL, 60=HIGH có đúng cho EUREKA? Cần calibration sau 3-5 production runs. Plan: collect data v10.19 GA → tune thresholds v10.21.
2. **CI integration:** Risk heatmap có dùng GitNexus `impact()` thay vì git log để chính xác hơn? Trade-off: GitNexus more accurate nhưng requires index fresh. Defer to v10.21 evaluation.
3. **User override:** Cho phép user override signals (vd: `signals.has_money: true` manually trong _contract.json.user_overrides)? — defer v10.22
4. **Cache TTL:** 4h fresh, 1h absent — calibration sau real-world usage. Configurable via env var `MCV3_DIAG_CACHE_TTL_HOURS`.
5. **Pattern coverage:** Vue 3 Composition API, Svelte 5, Solid — chưa cover. Add tại v10.20 dim analyzer based on user feedback.

---

## 7. Success Metrics

Đo lường sau khi v10.22 GA:

| Metric | Baseline (v10.18) | Target (v10.22) | Measurement |
|--------|-------------------|------------------|-------------|
| Phase 4 lane spawn count | 100% × dims × modules | -25% (skipped lanes) | `phase4-summary.json.lanes_skipped` |
| Phase 4 token usage | baseline | -25% | Total tokens lane-prompts |
| CDG-11 false positive rate | (current) | -50% | Manual audit 20 runs |
| Phase 5 user-perceived priority accuracy | (baseline survey) | +30% | Survey post-fix |
| Phase 7 verify duration | baseline | -50% on medium repo | Wall-clock |
| Total pipeline duration trên EUREKA | baseline | -15% | Wall-clock |

---

## 8. References

- **Spike data:** `Z:/Working/MCV3/plans/wf-fix-bugs-phase2-spike/`
  - Schemas: `schemas/{risk-heatmap-v1, dimension-applicability-v1}.schema.json`
  - Scripts: `scripts/{analyze-risk-heatmap, analyze-dimension-applicability}.sh`
  - Outputs: `outputs/{mcv3, eureka}/*.json`
  - Report: `spike-report.md` (with weakness analysis + downstream impact)
- **Current Phase 2:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase2-scan.md`
- **Cross-skill contract:** `.claude/skills/workflow/wf-fix-bugs/_contract.json`
- **Behavioral rules:** CORE-032 (Lazy-Load), CORE-035 (Phase Output), CORE-036 (Cross-Skill Artifact), CORE-038 (Context Budget)

---

## 9. Action Items

- [ ] Approve plan này → bắt đầu Sprint 1
- [ ] Confirm threshold calibration approach (calibration runs vs upfront tuning)
- [ ] Confirm CI integration trade-off (git log vs GitNexus impact)
- [ ] Decide cache TTL strategy (hardcoded vs env var)
- [ ] Schedule Sprint 1 kickoff (when?)

---

**Created:** 2026-05-16
**Author:** Architecture analysis post-spike
**Status:** AWAITING APPROVAL → Sprint 1 ready to start
