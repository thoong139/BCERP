<!--
_schema_notes:
  purpose: GAP detection + auto-suggestions + CDG decisions log. Phase 7 output. User-facing.
  rules:
    - Max 30 dòng total
    - Tiếng Việt, có markdown link đến gap-suggestions.json
    - Group theo kind (test_case, invariant_rule, api_contract, ...)
    - CDG decisions section liệt kê accepted/rejected/deferred
  delete_before_write: true
-->
# Báo cáo GAP + Đề xuất — [SESSION_ID]

**Tổng đề xuất:** [N_TOTAL] — **Đã ACCEPT:** [N_ACCEPTED] — **REJECT:** [N_REJECTED] — **DEFER:** [N_DEFERRED]

## 1. Test case còn thiếu ([N_TEST])

- **[TEST_ID_1]** — [TEST_DESCRIPTION_1] (confidence [CONFIDENCE_1]) — Status: [STATUS_1]
- **[TEST_ID_2]** — [TEST_DESCRIPTION_2] (confidence [CONFIDENCE_2]) — Status: [STATUS_2]

## 2. Invariant rule mới ([N_INV])

- **[INV_ID_1]** ([INV_KIND_1], [INV_SEVERITY_1]) — [INV_EXPRESSION_1] — modules: [INV_MODULES_1]
- **[INV_ID_2]** ([INV_KIND_2], [INV_SEVERITY_2]) — [INV_EXPRESSION_2] — modules: [INV_MODULES_2]

## 3. API contract bổ sung ([N_API])

- **[API_ID_1]** — endpoint [API_PATH_1] (module [API_MODULE_1])

## 4. Documentation snippets ([N_DOC])

- **[DOC_ID_1]** — bổ sung section [DOC_SECTION_1] trong [DOC_FILE_1]

## 5. CDG Decisions Log

| ID | Kind | Decision | Approver | Lý do |
|----|------|----------|----------|-------|
| [SUG_ID_1] | [KIND_1] | [DECISION_1] | [APPROVER_1] | [RATIONALE_1] |
| [SUG_ID_2] | [KIND_2] | [DECISION_2] | [APPROVER_2] | [RATIONALE_2] |

**Bước tiếp theo:** Manual implement accepted suggestions hoặc seed wf-implement-feature qua [gap-suggestions.json](gap-suggestions.json). Sidecar artifact `business-invariants.json` đã APPEND [N_INV_ACCEPTED] entry mới.
