<!-- Template: fix-report.md — Bao cao ket qua sau khi fix bugs -->
<!-- Ai viet: AI tu dong generate khi hoan thanh Phase 6 cua /wf-fix-bugs -->

# Bug Fix Report

**Generated:** YYYY-MM-DD HH:mm:ss
**Scope:** [all / system=X / module=Y]
**User Description:** [Mo ta loi tu user hoac "Scan toan bo"]

---

## Executive Summary

| Muc | Gia tri |
|-----|---------|
| **Project** | [Project Name] |
| **Date** | YYYY-MM-DD |
| **Scope** | [all / system=X / module=Y] |
| **Sessions** | X sessions |

---

## Coverage Estimate

> Section nay duoc populate boi `coverage_estimator.py` (Phase A v8 — Honest Framing).
> Source: `coverage-estimate.json` trong session directory.

| Aspect | Value |
|--------|-------|
| **Detected stack** | {{COVERAGE_STACK}} |
| **Profile** | {{COVERAGE_PROFILE}} |
| **Dimensions** | {{COVERAGE_DIMS_COUNT}}/7 ({{COVERAGE_DIMS_LIST}}) |
| **LLM scan** | {{COVERAGE_LLM_ENABLED}} |
| **Estimated coverage** | **{{COVERAGE_PCT}}%** ({{COVERAGE_CONFIDENCE}} confidence) |

### Coverage Components

| Component | Value |
|-----------|-------|
| Stack base coverage | {{COVERAGE_STACK_BASE}}% |
| Profile multiplier | ×{{COVERAGE_PROFILE_MULT}} |
| Dimension coverage | {{COVERAGE_DIM_PCT}}% of full 7 dims |
| Static estimate | {{COVERAGE_STATIC_PCT}}% |
| LLM bonus | +{{COVERAGE_LLM_BONUS}}% |

### Known Blind Spots (KHONG bat duoc boi static analysis)

{{COVERAGE_BLIND_SPOTS_LIST}}

### Recommendations to improve coverage

{{COVERAGE_RECOMMENDATIONS_LIST}}

> ⚠️ **LUU Y QUAN TRONG:** Skill nay KHONG dam bao phat hien 100% bugs.
> Static analysis co gioi han ly thuyet voi race conditions, integration bugs,
> business-rule edge cases, va UX inconsistencies. Hay xem "Known Blind Spots"
> ben tren va plan manual review/runtime testing tuong xung.
>
> {{COVERAGE_DISCLAIMER}}

---

## Metrics

| Metric | Before | After |
|--------|--------|-------|
| Preflight Score | X% | Y% |
| Issues Found | N | — |
| Issues Fixed | N | — |
| Issues Escalated | N | — |
| Docs Updated | N files | — |

**Fix Rate: X%** [>=80% GOOD | 50-79% PARTIAL | <50% NEEDS WORK]

---

## Fixed Issues

| # | Severity | Type | File | Description |
|---|----------|------|------|-------------|
| 1 | CRITICAL | compile_error | src/path/file.ts:NN | [Mo ta] |
| 2 | HIGH | test_failure | tests/path/file.test.ts:NN | [Mo ta] |
| 3 | MEDIUM | lint_error | src/path/file.ts:NN | [Mo ta] |

---

### Runtime Discovery Results

> Ket qua tu Phase 1c — phat hien loi runtime bang Playwright.

| Metric | Value |
|--------|-------|
| **App URL** | [url hoac "Not scanned"] |
| **Pages scanned** | [N] |
| **Console errors** | [N] |
| **Network errors (4xx/5xx)** | [N] |
| **UI issues** | [N] |
| **Form validation issues** | [N] |
| **Runtime exceptions** | [N] |
| **Screenshots** | [N] files tai `.mc-data/work/wf-fix-bugs/evidence/` |

#### Console Errors Fixed

| # | Message | Page | Before | After |
|---|---------|------|--------|-------|
| 1 | [error message] | /path | Present | Fixed |

#### Network Errors Fixed

| # | URL | Status | Method | Page | Fix |
|---|-----|--------|--------|------|-----|
| 1 | /api/endpoint | 500 | GET | /page | Fixed handler |

#### UI Issues Fixed

| # | Type | Element | Page | Fix |
|---|------|---------|------|-----|
| 1 | button_non_functional | #submit-btn | /form | Fixed event handler |

---

### UI→Docs Gaps (Deep Scan)

> Chi hien thi khi `--deep` flag active. Neu khong dung --deep → bo qua section nay.

| Metric | Value |
|--------|-------|
| **Orphan UI actions** | N (M stubs created) |
| **Orphan UI screens** | N (M stubs created) |
| **Orphan UI flows** | N (M stubs created) |
| **Stub docs created** | N files |

| # | Type | Element/Page | Stub Created | Needs Review |
|---|------|-------------|-------------|-------------|
| 1 | ORPHAN_UI_ACTION | [element text] @ [page] | `.mc-data/docs/phase2-features/[sys]/[mod]/[slug].md` | YES / NO |
| 2 | ORPHAN_UI_SCREEN | [page URL] | `.mc-data/docs/phase4-ux/[sys]/[mod]/screens-[slug].md` | YES / NO |
| 3 | ORPHAN_UI_FLOW | [flow name] @ [page] | `.mc-data/docs/phase2-features/[sys]/[mod]/flow-[slug].md` | YES / NO |

---

### E2E Flow Testing Results (--e2e / --full-test)

> Chi hien thi khi `--e2e` hoac `--full-test` flag active.

| Metric | Value |
|--------|-------|
| **Flows tested** | N |
| **Flows passed** | N |
| **Flows failed** | N |
| **Flows partial** | N |

| # | Flow Name | Result | Steps Passed | Failed Step | Fix |
|---|-----------|--------|-------------|-------------|-----|
| 1 | [flow name] | PASS / FAIL | X/Y | [step description] | [fix description] |

---

## Escalated Issues (can user xu ly)

| # | Severity | Type | File | Description | Ly do |
|---|----------|------|------|-------------|-------|
| 1 | HIGH | design_issue | src/path/file.ts | [Mo ta] | [Ly do can user] |

---

## Docs Updated (behavior thay doi)

| # | Doc | Thay doi | Ly do |
|---|-----|---------|-------|
| 1 | phase2-features/[sys]/[mod]/[feat].md | [Mo ta thay doi] | Bug fix: [mo ta bug] |

---

## Fix Batches

### Batch 1: CRITICAL

| # | Issue | File | Status |
|---|-------|------|--------|
| 1 | [Mo ta] | [File] | ✅ Fixed |

### Batch 2: HIGH

| # | Issue | File | Status |
|---|-------|------|--------|
| 1 | [Mo ta] | [File] | ✅ Fixed |

### Batch 3: MEDIUM

| # | Issue | File | Status |
|---|-------|------|--------|
| 1 | [Mo ta] | [File] | ✅ Fixed |

---

## Verify Results

| Check | Result |
|-------|--------|
| Preflight re-scan | ✅ Score improved X% → Y% |
| Tests pass | ✅ All pass |
| REQ-ID comments | ✅ Present in fixed files |
| Docs consistent | ✅ Updated specs match code |
| Reality check | ✅ PASS |

---

## Browser Verification (QD9)

<!-- Chi hien thi khi: flags.no_browser != true AND lane QD9 chay. Bo qua section nay neu QD9 khong chay. -->

- Console errors truoc fix: {{QD9_CONSOLE_BEFORE}}
- Console errors sau fix: {{QD9_CONSOLE_AFTER}}
- Network failures (4xx/5xx) truoc/sau: {{QD9_NETWORK_BEFORE}}/{{QD9_NETWORK_AFTER}}
- Pages tested: {{QD9_PAGES_TESTED}}
- Screenshots: {{QD9_SCREENSHOTS}}
- Auth flows tested: {{QD9_AUTH_FLOWS}}

---

## Next Steps

1. ✅ Bug fix complete
2. 👉 **Recommended:** Run `/wf-verify-sync` de verify full sync
3. 👉 **Optional:** Run `/wf-preflight` de re-check toan bo
4. ⚠️ **Escalated:** [N] issues can user xu ly (xem section "Escalated Issues")

---

*Report auto-generated by DEVKIT `/wf-fix-bugs`*
