# QD4 Test Fixture — Performance Bottlenecks

> **Status:** ✅ Phase 3 DONE (Phiên 27 — 2026-05-08)
> **Lane skill:** `wf-fix-performance` v2.0.0-alpha.s4
> **Số probes:** 6
> **Owner agent:** `performance-benchmarker`
> **Audit report:** [05-qd4-performance-audit.md](../../05-qd4-performance-audit.md)
> **Accuracy report:** [accuracy-report.md](./accuracy-report.md)

## Mục đích

Đo precision/recall của 6 probes Performance — bundle size, API latency, N+1 queries, memory leaks, Core Web Vitals (LCP/FID/CLS), render performance.

## Expected signals per probe

| Probe ID | Signal type(s) | Severity | Positive cases | Negative cases | Notes |
|---|---|:-:|:-:|:-:|---|
| `P-QD4-bundle-size-audit` | `bundle_size`, `n_plus_one_query` | HIGH | pos-01, pos-02 | neg-01 | bash Part 1 (bundle) + Part 2 (N+1) — both run always (D12) |
| `P-QD4-render-perf-check` | `missing_memo` | MEDIUM | pos-05 | neg-03, neg-05 | Static Check 1 only (React-specific); Playwright skip in fixtures |
| `P-QD4-api-latency-probe` | `api_latency` | HIGH | — | — | **SPEC_GAP**: requires `--base-url` + running server |
| `P-QD4-db-query-analysis` | `unbounded_query` | HIGH | pos-04 | neg-04 | Static Check 2 (ORM findMany/findAll without limit) |
| `P-QD4-memory-leak-scan` | `event_listener_leak`, (timer_leak) | HIGH, MEDIUM | pos-03 | neg-02, neg-03, neg-05 | Check 1 (addEventListener) + Check 2 (setTimeout) + Check 4 (WeakMap) |
| `P-QD4-core-web-vitals` | `lcp_slow`, `cls_high`, `inp_slow` | MEDIUM | — | — | **SPEC_GAP**: requires Playwright + running browser |

## Cases

### Positive (5, code có known bugs)

| ID | File | Bug | Probe | Signal | Severity |
|---|---|---|---|---|---|
| pos-01 | `positive/pos-01-large-bundle/dist/main.js` | File ≈1100KB >> 1000KB threshold | P-QD4-bundle-size-audit (Part 1) | `bundle_size` | HIGH |
| pos-02 | `positive/pos-02-n-plus-one/src/user-service.ts` | `await repo.findOne/findById` inside `for(const id of ...)` | P-QD4-bundle-size-audit (Part 2) | `n_plus_one_query` | HIGH |
| pos-03 | `positive/pos-03-event-leak/src/LeakyComponent.tsx` | 3 `addEventListener` + 0 `removeEventListener` in useEffect, no cleanup | P-QD4-memory-leak-scan (Check 1) | `event_listener_leak` | HIGH |
| pos-04 | `positive/pos-04-unbounded-query/src/user-repo.ts` | `prisma.user.findMany()` / `.findAll()` without `.take()` or LIMIT | P-QD4-db-query-analysis (Check 2) | `unbounded_query` | HIGH |
| pos-05 | `positive/pos-05-missing-memo/src/BigDashboard.tsx` | 384 lines, `export default function`, no `React.memo` or `memo(` | P-QD4-render-perf-check (Check 1) | `missing_memo` | MEDIUM |

### Negative (5, code legit, không nên flag)

| ID | File | Why safe | Probe tested |
|---|---|---|---|
| neg-01 | `negative/neg-01-small-bundle/dist/main.js` | ≈80KB < 500KB threshold | P-QD4-bundle-size-audit |
| neg-02 | `negative/neg-02-debounce-settimeout/src/debounce.ts` | `clearTimeout` called before each new `setTimeout` — balanced | P-QD4-memory-leak-scan (Check 2) |
| neg-03 | `negative/neg-03-proper-cleanup/src/CleanComponent.tsx` | `useEffect` returns `() => { window.removeEventListener(...) }` — balanced | P-QD4-memory-leak-scan (Check 1) |
| neg-04 | `negative/neg-04-parameterized-sql/src/user-query.ts` | `db.rawQuery('... WHERE id = $1 LIMIT 1', [userId])` — no ORM unbounded pattern | P-QD4-db-query-analysis (Check 2) |
| neg-05 | `negative/neg-05-weakmap-cache/src/cache.ts` | `new WeakMap()` + `new WeakSet()` — GC-friendly, NOT `new Map()` / `new Set()` | P-QD4-memory-leak-scan (Check 4) |

### Advanced (optional)

Optional — không bắt buộc cho dim này. Phase 3 DoD đã PASS với 5+5 cases.

## Live Run Results (Phiên 27 — 2026-05-08)

```
Total tests run:   14
Passed:            14
Failed:            0
Skipped (SPEC_GAP): 2  (api-latency + CWV — require running server)

Precision = 1.00   Recall = 1.00   F1 = 1.00
```

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd4-test
bash run.sh
```

> **Note:** `run.sh` invokes `wf-fix-probe-static-perf.sh` (external bash) for P1 (bundle + N+1). For P2 (render-perf), P4 (db-query), P5 (memory-leak), run.sh inlines equivalent probe logic since those probes use inline bash in probe spec files (not external scripts). P3 (api-latency) + P6 (CWV) require a running server — documented as SPEC_GAP, skipped.

## Liên quan

- Audit report: [05-qd4-performance-audit.md](../../05-qd4-performance-audit.md)
- Accuracy report: [accuracy-report.md](./accuracy-report.md)
- Expected signals: [expected-signals.json](./expected-signals.json)
- Lane skill: `.claude/skills/workflow/wf-fix-performance/`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
