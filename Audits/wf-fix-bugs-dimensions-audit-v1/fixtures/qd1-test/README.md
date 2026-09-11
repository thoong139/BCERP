# QD1 Test Fixture — Functional Correctness

> **Status:** ✅ Phase 3 DONE (Phiên 7: 5 positive + 5 negative cases, P=1.00, R_live=1.00, F1=1.00 → DoD pass).
> **Lane skill:** `wf-fix-functional` v2.0.0-alpha.s4
> **Số probes:** 7 (chỉ 1/7 — `req-registry-xref` — có bash script độc lập, đo được automatic)
> **Owner agent:** `general-purpose`
> **Audit report:** [02-qd1-functional-audit.md](../../02-qd1-functional-audit.md)
> **Accuracy report:** [accuracy-report.md](./accuracy-report.md)

## Mục đích

Đo precision/recall của 7 probes Functional Correctness — REQ-ID xref, route parsing, infra preflight, API smoke, deep UI traversal, orphan UI detect, agent feature verify. Bao gồm multi-stack (.NET WebAPI + React/TS) và i18n VI.

## Kết quả Phiên 7 (final)

Probe `P-QD1-req-registry-xref` chạy trên `$FIXTURE_DIR` (positive + negative) → emit **5 signals** (identical Phiên 6), match 5/5 live_detectable expectations.

**Confusion matrix:**

| | Probe emits signal | Probe silent |
|---|---|---|
| Should emit (live_detectable) | TP = 5 | FN = 0 |
| Should be silent (negative) | FP = 0 | TN = 5 |

**Metrics:** Precision = 1.00 | Recall_live = 1.00 | F1 = 1.00 | Accuracy = 1.00.

**DoD verdict:** ✅ PASS (Precision ≥ 0.7 ✅, Recall ≥ 0.6 ✅). Chi tiết: [accuracy-report.md](./accuracy-report.md).

> **Caveat:** Recall_live = 1.00 chỉ đại diện 1/7 probe có script. Overall recall trên toàn QD1 estimate ≈ 30-40% sau khi tính 6/7 probe missing bash script (Phase 2 finding).

## Expected signals per probe

| Probe ID | Live Detectable | Documented Gap (no script) | Notes |
|---|:-:|:-:|---|
| `P-QD1-req-registry-xref` | 5 | 2 | Script tồn tại, nhưng MISS orphan FEAT-IDs (chỉ check orphan REQ) — 2 documented gaps |
| `P-QD1-route-config-parse` | 0 | 2 | Không có script; FN-001 (.NET) + FN-002 (template literal) |
| `P-QD1-infra-preflight` | 0 | 0 | Không có script; chưa cover trong Phiên 6 |
| `P-QD1-api-smoke` | 0 | 0 | Không có script; chưa cover trong Phiên 6 |
| `P-QD1-deep-ui-traversal` | 0 | 1 | Không có script; FN-003 (VI CTAs) |
| `P-QD1-orphan-ui-detect` | 0 | 0 | Không có script; chưa cover trong Phiên 6 |
| `P-QD1-agent-feature-verify` | 0 | 0 | Agent-type, không đo được automatic ở Phase 3 |

> 6/7 probe QD1 KHÔNG có bash script độc lập (xem [02-qd1 §Phase 2](../../02-qd1-functional-audit.md#phase-2--code-trace-summary-added-2026-05-08-phiên-5)). Phase 3 fixture chỉ đo automatic được probe `req-registry-xref`. Các probe còn lại được ghi nhận làm `documented_gap` để feed vào §FN scenarios + IMP-QD1-001/002/008/009.

## Cases

### Positive (5 — Phiên 6 ✅)

| File | REQ-IDs | FEAT-IDs | Test target |
|---|---|---|---|
| `pos-01-orphan-feat-id.ts` | REQ-ORPHAN-001 (orphan) | FEAT-NONEXIST-X-001 (orphan, gap) | Orphan REQ + Orphan FEAT (script gap) |
| `pos-02-missing-feat-id.tsx` | REQ-CRM-001 (legit) | (none — coverage_gap target) | Coverage gap HIGH (FEAT-CRM-CUST-001) |
| `pos-03-broken-route.dotnet.cs` | REQ-CATALOG-003 (legit) | FEAT-CATALOG-PROD-003 (legit) | FN-001 .NET route (no script) |
| `pos-04-template-literal-api.tsx` | REQ-API-CALL-007 (orphan) | FEAT-CRM-VIEW-005 (legit) | Orphan REQ + FN-002 template literal (no script) |
| `pos-05-vi-cta.tsx` | REQ-VI-008 (orphan) | FEAT-VI-VIEW-009 (orphan, gap) | Orphan REQ + FN-003 VI CTA (no script) + script gap |

### Negative (5 — Phiên 7 ✅)

| File | REQ-IDs | FEAT-IDs | FP target | Probe emits? |
|---|---|---|:-:|:-:|
| `neg-01-readme-with-fake-req-id.md` | REQ-FAKE-DOC-001 (in markdown) | FEAT-FAKE-DOC-002 (in markdown) | FP-001 | ❌ NO (extension `.md` skip — probe đúng) |
| `neg-02-validation-400.ts` | REQ-CRM-001 (legit) | FEAT-CRM-VIEW-005 (legit) | FP-002 | ❌ NO (REQ/FEAT legit; api-smoke probe chưa có script) |
| `neg-03-async-download.tsx` | REQ-CATALOG-003 (legit) | FEAT-CATALOG-PROD-003 (legit) | FP-003 | ❌ NO (REQ/FEAT legit; deep-ui-traversal probe chưa có script) |
| `neg-04-dynamic-route.tsx` | REQ-CRM-005 (legit) | FEAT-CRM-VIEW-005 (legit) | FP-004 | ❌ NO (REQ/FEAT legit; orphan-ui-detect probe chưa có script) |
| `neg-05-cold-start-mock.json` | (chỉ trong _doc keys, .json không scan) | (chỉ trong _doc keys, .json không scan) | FP-005 | ❌ NO (extension `.json` skip; infra-preflight probe chưa có script) |

→ 5 TN, 0 FP. FP-001 xác nhận không reproduce (probe đúng). FP-002..FP-005 là `documented_gap`, sẽ re-test khi probe được implement.

### Advanced (optional)

Optional — không bắt buộc cho dim này. Phiên 8 hoặc Phase 4 cross-probe quyết định.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd1-test

# Preflight only (validate registry + expected-signals.json)
bash run.sh QD1 --dry-run

# Run probe + dump signals to .actual-signals.json
bash run.sh QD1
```

Phiên 7 status: **TP=5, FP=0, TN=5, FN=0 → P=R_live=F1=1.00 → DoD ✅ PASS.** Xem [accuracy-report.md](./accuracy-report.md).

## Mini Registry

Stub registry tại `.mc-data/docs/_meta/req-registry.json`:
- 4 systems (1 deprecated)
- 4 requirements (REQ-CRM-001, REQ-CRM-005, REQ-CATALOG-003, REQ-INV-002)
- 5 features:
  - 4 in scope (3 done + 1 in_progress) — driving 2 coverage_gap signals
  - 1 skipped — out of scope (FEAT-LEGACY-OLD-099)

## Liên quan

- Audit report: [02-qd1-functional-audit.md](../../02-qd1-functional-audit.md)
- Lane skill: `.claude/skills/workflow/wf-fix-functional/`
- Probe script: `.claude/scripts/wf-fix-probe-static-xref.sh`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
