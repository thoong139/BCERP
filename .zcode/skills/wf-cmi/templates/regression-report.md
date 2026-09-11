<!--
_schema_notes:
  purpose: Regression scope report tiếng Việt (CORE-028). Phase 6 output.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Liệt kê: changed files (≤5 ví dụ), affected modules, test plan summary
    - Mode: predictive (GitNexus) hoặc diff-aware (git fallback)
  delete_before_write: true
-->
## Phạm vi Regression — [SESSION_ID]

**Mode:** [REGRESSION_MODE] (predictive=GitNexus impact, diff-aware=git diff) — **Since:** [SINCE_REF]

**Thay đổi:** [N_CHANGED_FILES] files (ví dụ: [SAMPLE_FILE_1], [SAMPLE_FILE_2], [SAMPLE_FILE_3]...)

**Ảnh hưởng dự kiến:**

- Modules: [AFFECTED_MODULES] ([N_MODULES] modules)
- Workflows: [AFFECTED_WORKFLOWS] ([N_WORKFLOWS] workflows)
- Test plan: [N_TESTS] tests cần chạy lại — HIGH: [N_HIGH], MEDIUM: [N_MEDIUM], LOW: [N_LOW]

**Confidence threshold:** [CONFIDENCE_THRESHOLD]. Chi tiết: [regression-map.json](regression-map.json).
