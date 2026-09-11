<!--
_schema_notes:
  purpose: Phase 4 (Coverage Dispatch — 10 lanes PARALLEL) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Lane summary: activated/completed/failed/timeout/skipped
    - Total signals + breakdown
  delete_before_write: true
-->
## Phase 4: Coverage Dispatch (10 lanes PARALLEL) — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)

**Đã làm:** Spawn [N_LANES] lane agents PARALLEL (max concurrency 10): [LANES_ACTIVATED]. Mỗi lane execute scan riêng theo chiều coverage, output signals.json + lane-status.json + CD-report.md.

**Kết quả:**

- COMPLETED: [N_COMPLETED] lanes — [LANES_COMPLETED]
- FAILED: [N_FAILED] lanes — [LANES_FAILED]
- TIMEOUT: [N_TIMEOUT] lanes — [LANES_TIMEOUT] (retry 1x: [N_RETRY_OK]/[N_TIMEOUT] thành công)
- SKIPPED: [N_SKIPPED] lanes (profile=[PROFILE] không active)

**Total signals:** [N_TOTAL_SIGNALS] — MUST: [N_MUST], SHOULD: [N_SHOULD], MAY: [N_MAY], INFO: [N_INFO].

**Tiếp theo:** Phase 5 — Aggregate (compute coverage matrix 10 dims + threshold check).

[NẾU FAIL (>50% lanes fail):]
**Vấn đề:** [ERROR_MESSAGE]
**Cách xử lý:** [RECOVERY_PLAN]
