<!--
_schema_notes:
  purpose: Phase 6 (Regression Map) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Mode: predictive (GitNexus impact) hoặc diff-aware (git diff fallback)
    - Skip note nếu profile=quick hoặc --since không set
  delete_before_write: true
-->
## Phase 6: Regression Map — [STATUS_PASS_SKIPPED_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)

[NẾU SKIPPED:]
**Đã skip:** Profile=[PROFILE] hoặc --since không set. Predictive regression analysis bỏ qua. Tiếp tục Phase 7.

[NẾU PASS/FAIL:]
**Đã làm:** Phân tích regression theo --since=[SINCE_REF] (mode [REGRESSION_MODE]). [PREDICTIVE_SOURCE: GitNexus impact() | diff-aware git diff fallback]. Confidence threshold [CONFIDENCE_THRESHOLD].

**Kết quả:**

- Changed files: [N_CHANGED_FILES]
- Direct callers: [N_DIRECT] (HIGH confidence ≥0.9)
- Transitive callers: [N_TRANSITIVE] (≤[N_HOPS_MAX] hops)
- Affected modules: [N_MODULES] — [AFFECTED_MODULES]
- Affected workflows: [N_WORKFLOWS] — [AFFECTED_WORKFLOWS]
- Test plan: [N_TESTS] tests (HIGH: [N_HIGH], MED: [N_MED], LOW: [N_LOW])

**Tiếp theo:** Phase 7 — GAP + CDG (detect missing artifacts + user decisions).

[NẾU FAIL:]
**Vấn đề:** [ERROR_MESSAGE] (vd E062 GitNexus unavailable + git log fallback fail)
**Cách xử lý:** [RECOVERY_PLAN | DEGRADE_TO_DIFF_AWARE]
