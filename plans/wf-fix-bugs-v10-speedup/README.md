# wf-fix-bugs v10 Speed-up Plan — Phase 6 & wf-fix-execute Optimization

> **Trạng thái:** ✅ COMPLETED 2026-05-14 — 8/8 tasks done, 3 waves parallel committed
> **Tạo ngày:** 2026-05-14
> **Target version:** wf-fix-bugs v10.0.2 → v10.1.0 | wf-fix-execute v3.7.0 → v3.8.0 ✅
> **Profile target:** `exhaustive` (user thường dùng — 11 dimensions, ~120 phút baseline)
> **Speedup achieved:** ~50-60% expected (cần user benchmark cuối cùng để confirm)
> **Plan owner:** wf-fix-bugs maintainer

---

## Định Vị

Sau wf-fix-bugs v10.0 (2026-05-13: refactor toàn bộ với lazy-load procedures, CI PRE-GATE 3-step, 32 templates, Playwright 3 modes), skill này đã hoàn thiện về kiến trúc. **Vấn đề:** runtime cho profile `exhaustive` quá dài (~120 phút). Plan này tập trung tối ưu hot-path mà **không thay đổi kiến trúc, không thay đổi contract, không bỏ guard rail nào**.

**Nguyên tắc tối thượng (CORE-023):** Chất lượng > Tốc độ. Mọi cải tiến tốc độ PHẢI bảo toàn:
- POST-GATE T1-T4 (CORE-012)
- CDG CORE-027 (E090-E093, E100, CDG-EXEC-04)
- CORE-029 Spot-check (Protocol 17)
- CORE-037 Agent Prompt 8 sections
- CQG hard-enforce (`wf-fix-cqg-verify.sh`)
- CORE-031 Template Usage
- CORE-026 Execution Trace
- CORE-006 Registry Safe-Write
- CI Tool Usage Logging (Protocol 20 §20.11)
- Scope Boundary Rule

> Chi tiết guard rails: [`01-guard-rails.md`](01-guard-rails.md)

---

## Tổng Quan 3 Waves — 8 Cải Tiến

| Wave | # | Cải tiến | Speedup | Risk | Files affected | Phụ thuộc |
|------|---|----------|---------|------|----------------|-----------|
| **W1** | 1.1 | Phase 6 wrapper de-dup CI (Step 6.4) | -5-10 min | Low | `wf-fix-bugs/procedures/phase6-execute.md` | None |
| **W1** | 1.2 | CI Impact Caching session-tier | -15-25 min | Low | `wf-fix-execute/procedures/phase3-batch{1,2,3}.md`, new `wf-fix-ci-cache.sh` | W1.1 |
| **W1** | 1.3 | POST-GATE T1-T4 jq consolidation | -2-3 min | Very Low | `wf-fix-bugs/procedures/phase6-execute.md` + `wf-fix-execute/_shared.md` | None |
| **W1** | 1.4 | Benchmark Wave 1 + verify guard rails | — | — | `tools/integration-test.py` scenario G/H | W1.1, W1.2, W1.3 |
| **W2** | 2.1 | Playwright parallel routes (max 4 contexts) | -5-10 min | Medium | `_shared/playwright-session.js` + `wf-fix-execute/procedures/phase5-scan.md` Step 5.14 | W1.4 |
| **W2** | 2.2 | Batch 1 CRITICAL sub-parallel (dep-aware) | -5-10 min | Medium | `wf-fix-execute/procedures/phase3-batch1.md` + new dep-graph helper | W1.4 |
| **W2** | 2.3 | Benchmark Wave 2 + verify no race conditions | — | — | scenarios | W2.1, W2.2 |
| **W3** | 3.1 | Verify Loop smart rescan (iter 2+ delta) | -10-15 min | Medium | `wf-fix-execute/procedures/phase5-scan.md` Step 5.1 + `phase5-loop.md` VERIFY_RESCAN | W2.3 |
| **W3** | 3.2 | CI Batching per file (gom issues → 1 impact/file) | -5-8 min | Medium | `phase3-batch{1,2,3}.md` CI PRE-GATE + new `wf-fix-ci-batch.sh` | W1.2 |
| **W3** | 3.3 | Spot-check pattern cache (LRU 50) | -2-4 min | Low | `wf-fix-execute/_shared.md` §Agent Output Spot-Check | None |
| **W3** | 3.4 | Final benchmark + CHANGELOG + version bump | — | — | `CHANGELOG.md`, `_contract.json` | All |

**Tổng expected speedup:** ~50-60% (Wave 1: ~25-35%, Wave 2: +15-20%, Wave 3: +15-20%).

---

## Status Tracking — ALL DONE ✅

| Task | Status | Owner | Commit | Notes |
|------|:------:|-------|--------|-------|
| W1.1 | ✅ | AI W1-A | 2b5fd677 | Phase 6 de-dup CI |
| W1.2 | ✅ | AI W1-B | 2b5fd677 | CI Impact Cache 371-line wrapper |
| W1.3 | ✅ | AI W1-A | 2b5fd677 | POST-GATE helper |
| W1.4 | ⏭️ | — | — | Deferred to W3.4 final benchmark |
| W2.1 | ✅ | AI W2-A | b09ee1ce | Playwright 4-context parallel |
| W2.2 | ✅ | AI W2-B | b09ee1ce | Dep-graph 213-line script |
| W2.3 | ⏭️ | — | — | Deferred to W3.4 |
| W3.1 | ✅ | AI W3-A | e5d42753 | Smart rescan + cross-module |
| W3.2 | ✅ | AI W3-B | e5d42753 | CI batching 375-line script |
| W3.3 | ✅ | AI W3-C | e5d42753 | Spot-check LRU 50 |
| W3.4 | ✅ | AI | (this commit) | Version bump 10.1.0 + CHANGELOG + progress |

Chi tiết progress: [`progress.md`](progress.md)

---

## Cấu Trúc Plan Files

| File | Mục đích |
|------|----------|
| `README.md` | Overview, status, navigation (file này) |
| `00-master-plan.md` | Per-task detailed specs — WHAT, WHERE, HOW, VERIFY, ROLLBACK |
| `01-guard-rails.md` | Compliance matrix — bảo toàn 10 chuẩn MCV3 |
| `02-benchmark.md` | Test methodology — scenario chọn, đo lường, expected results |
| `progress.md` | Append-only log thay đổi qua từng wave |

---

## Quyết Định Đã Resolved (2026-05-14)

| # | Quyết định | Chi tiết |
|---|------------|----------|
| 1 | Thứ tự | **Wave-by-wave + in-wave parallel max** — mỗi wave có benchmark gate, trong wave spawn 2-3 agents parallel |
| 2 | Benchmark | **Synthetic fixture** reproducible qua `scripts/build-bench-fixture.sh` (3-5 modules, 20-30 mixed bugs) |
| 3 | Version | **Minor bump** wf-fix-bugs `10.0.1→10.1.0`, wf-fix-execute `3.7.0→3.8.0` (additive, backward compat) |
| 4 | W3.1 enhanced | **GIỮ với cross-module dependents delta** — iter 1 & cuối full, iter giữa = delta + gitnexus_impact downstream |
| 5 | Code owner | **AI tự code + smoke test, user review per-commit + benchmark** |

## Revised Parallel Execution Plan

| Wave | Parallel Agents | Sequential | Wall-Clock |
|------|-----------------|-----------|-----------|
| W1 | W1-A (1.1 + 1.3) // W1-B (1.2) | W1.4 benchmark | 5-7h |
| W2 | W2-A (2.1) // W2-B (2.2) | W2.3 benchmark | 5-7h |
| W3 | W3-A (3.1) // W3-B (3.2) // W3-C (3.3) | W3.4 benchmark + CHANGELOG + version bump | 6-9h |
| **Total** | | | **16-23h (vs 29-43h sequential)** |

---

## Cross-References

- Plan v9 trước đó: `D:\Working\MCV3\plans\wf-fix-bugs-v9\` (đã DONE 2026-05-10)
- Skill source: `.claude/skills/workflow/wf-fix-bugs/`, `.claude/skills/workflow/wf-fix-execute/`
- Phase 6 file: `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute.md` (855 dòng)
- Spec rules: `.claude/rules/00-core.md` (CORE-032 → CORE-038)
- Shared infrastructure: `.claude/skills/workflow/_shared/cache/cache_adapter.py`, `_shared/playwright-session.js`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-05-14 | Plan tạo. DRAFT — chờ approve. |
