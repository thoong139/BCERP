<!--
_schema_notes:
  purpose: Báo cáo tổng hợp cuối session v3.0, cho người không chuyên đọc. User-facing PRIMARY output.
  rules:
    - Max 70 dòng total (v3 relaxed từ 55: 55 dòng v2 base + tối đa 15 dòng E2E Execution Summary section conditional)
    - Typical case (0-3 violations, --exec-scenarios=off): 44-48 dòng. Max bound v2 (10 violations): 52-55 dòng. Max bound v3 (10 violations + E2E section full): 67-70 dòng.
    - Tiếng Việt, English chỉ cho REQ-ID/FEAT-ID/file path
    - Có 7-8 sections: Tổng quan + Coverage 26 chiều grouped (Core/FE/BE/UX/Logistics/Compliance/Implementation) + Wave summary + Top vi phạm (10 entries severity-weighted MUST>HIGH>MEDIUM>LOW) + [E2E Execution Summary (v3 conditional)] + Đề xuất + Regression + Khuyến nghị
    - 9 SKIPPED dims hiển thị compact ở cuối table với icon ⏭
    - Mỗi violation/suggestion có markdown link đến file detail
    - Placeholder [TOP_VIOLATIONS_LIST] được awk insert multi-line từ Step 8.3; nếu 0 violation thì chỉ in "_Không phát hiện vi phạm._"
    - Section "E2E Execution Summary" (v3 NEW): CHỈ render nếu --exec-scenarios bật (e2e_execution_summary != null trong integrity-impact.json). Placeholder [E2E_SECTION] được awk insert từ Step 8.3 v3.
    - Khi --exec-scenarios=off → placeholder [E2E_SECTION] thay bằng chuỗi rỗng (section bỏ qua hoàn toàn)
  delete_before_write: true
-->
# Báo cáo Cross-Module Integrity v3.0 — [SESSION_ID]

**Phạm vi:** [SCOPE_TYPE] — [MODULES]
**Profile:** [PROFILE] (ngưỡng [THRESHOLD]%) · **Thời gian:** [DURATION]
**Trạng thái:** [STATUS_PASS_WARN_FAIL] · **Coverage tổng:** [OVERALL_PCT]%

## 1. Coverage 26 chiều Gói C++ Logistics

| Nhóm | Lanes | Coverage | Status | Vi phạm |
|------|-------|----------|--------|---------|
| **Core** (8, W1+W3) | CD1-CD7, CD9 | [CORE_AVG_PCT]% | [CORE_STATUS] | [CORE_VIOLATIONS] |
| **Frontend** (3, W1-W2) | CD11, CD13, CD15 | [FE_AVG_PCT]% | [FE_STATUS] | [FE_VIOLATIONS] |
| **Backend** (3, W1-W2) | CD16, CD17, CD18 | [BE_AVG_PCT]% | [BE_STATUS] | [BE_VIOLATIONS] |
| **UX** (4, W2-W3) | CD23-CD26 | [UX_AVG_PCT]% | [UX_STATUS] | [UX_VIOLATIONS] |
| **Logistics ★★★** (3, W2) | CD28 MDM, CD30 Time&Num, CD31 Money&Tax | [LOGISTICS_AVG_PCT]% | [LOGISTICS_STATUS] | [LOGISTICS_VIOLATIONS] |
| **Compliance ★★★** (2, W2-W3) | CD29 Audit, CD37 Regulatory | [COMPLIANCE_AVG_PCT]% | [COMPLIANCE_STATUS] | [COMPLIANCE_VIOLATIONS] |
| **Implementation ★** (3, W3) | CD38 UI, CD39 Error UX, CD40 Print&Export | [IMPL_AVG_PCT]% | [IMPL_STATUS] | [IMPL_VIOLATIONS] |

**⏭ SKIPPED v2 (9):** CD8, CD10, CD12, CD14, CD19-22, CD27 (reactivate v2.1 hoặc exhaustive)

## 2. Tổng quan Wave dispatch
| Wave | Lanes | PASS | FAIL/TIMEOUT | Thời gian |
|------|-------|------|--------------|-----------|
| W1 (10) | [W1_LANES_LIST] | [W1_PASS] | [W1_FAIL] | [W1_DURATION] |
| W2 (10) | [W2_LANES_LIST] | [W2_PASS] | [W2_FAIL] | [W2_DURATION] |
| W3 (6) | [W3_LANES_LIST] | [W3_PASS] | [W3_FAIL] | [W3_DURATION] |

## 3. Vi phạm chính (top [TOP_N], severity-weighted MUST>HIGH>MEDIUM>LOW)
[TOP_VIOLATIONS_LIST]

[E2E_SECTION]

## 4. Đề xuất ([N_TOTAL] artifacts) — chi tiết [gap-suggestions.json](../phase7-gap-cdg/gap-suggestions.json)
- [N1] test case · [N2] invariant rule · [N3] API contract bổ sung · [N4] SSOT entries (vd ui-interactivity-spec, mdm-canonical-entities) · [N_E2E_FIX] e2e_scenario_fix (v3 loop-back từ Phase 10)

## 5. Regression scope
[N_FILES] files đổi từ [SINCE_REF] → [N_MODULES] module ảnh hưởng — [regression-map.json](../phase6-regression/regression-map.json)

## 6. Khuyến nghị (theo Priority Order CORE-023)
- **Critical**: [ACTION_LOGISTICS_COMPLIANCE] (CD28/CD30/CD31/CD37 violations)
- **Verify**: [ACTION_FOR_VERIFY_SYNC] → `/wf-verify-sync --from-cmi`
- **Fix**: [ACTION_FOR_FIX_BUGS] → `/wf-fix-bugs --from-cmi`
- **Implement**: [ACTION_FOR_IMPLEMENT_FEATURE] → `/wf-implement-feature --from-cmi`
- **E2E verify (v3)**: [ACTION_FOR_E2E] → `/wf-cmi --scope=... --exec-scenarios --profile=deep` (chỉ khi muốn live runtime verify Playwright)

**File chi tiết:** [coverage-matrix.json](../phase5-aggregate/coverage-matrix.json) · [business-invariants.json](../phase3-invariants/business-invariants.json) · [integrity-impact.json](integrity-impact.json) (schema v3) · [phase9-e2e-execute/](../phase9-e2e-execute/) (nếu --exec-scenarios) · [phase10-e2e-resolution/](../phase10-e2e-resolution/) (nếu Phase 10 chạy)

---

<!--
E2E_SECTION TEMPLATE (Step 8.3 v3 awk insert nếu --exec-scenarios bật. Nếu off → thay [E2E_SECTION] bằng chuỗi rỗng).
Section structure (max 15 dòng):

## 3.5. E2E Execution Summary (Playwright runtime verify)

| Metric | Value |
|--------|-------|
| Scenarios sinh (CD41) | [N_SYNTH] |
| Scenarios executed | [N_EXEC] |
| PASS | [N_PASS] |
| Auto-corrected | [N_AUTO_CORRECTED] |
| FAIL | [N_FAIL] |
| Quarantined | [N_QUARANTINED] |
| Cross-module | [N_CROSS_MODULE]/[N_EXEC] |
| Thời gian (P9+P10) | [PHASE9_DURATION] + [PHASE10_DURATION] |
| Loop-back gap-suggestions | +[N_LOOP_BACK] |

**Top 3 failure types:** [TOP_FAILURE_TYPES_COMMA_LIST]
**Evidence:** [phase9-e2e-execute/screenshots/](../phase9-e2e-execute/screenshots/) · **Resolution:** [phase10-e2e-resolution/resolution-report.md](../phase10-e2e-resolution/resolution-report.md)
-->

