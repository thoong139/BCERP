<!--
_schema_notes:
  purpose: Per-lane CORE-028 Vietnamese report (≤15 dòng cho lane chuẩn; ≤20 dòng cho CD41 do có CD41-specific metrics). 1 per active lane (5-27 reports/session tùy profile).
  rules:
    - Max 15 dòng total (chuẩn) | Max 20 dòng (CD41 — thêm 5 dòng E2E synth metrics)
    - Tiếng Việt, không jargon
    - 4 fields chuẩn: Đã làm, Kết quả, Tiếp theo, Vấn đề (nếu có)
    - Lane ID format: CD{N}-{name} (vd CD1-business-domain, CD4-api-contract, CD41-e2e-synth)
    - CD41 conditional section (v3): nếu LANE_ID=CD41, render thêm "**E2E synth metrics**" block với scenarios synthesized + skipped low_confidence + cross-module + filter dims
    - Placeholder [CD41_SECTION] được awk insert khi LANE_ID=CD41; khác CD41 → thay bằng chuỗi rỗng
  delete_before_write: true
-->
## Lane [LANE_ID] ([LANE_NAME]) — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)
Agent: [AGENT_TYPE]

**Đã làm:** Quét [N_FILES] file trong [N_MODULES] modules theo chiều [DIM_NAME]. Sử dụng [CI_SOURCE] (primary) / [FALLBACK_TOOL] (fallback).

**Kết quả:** [N_SIGNALS] signals — MUST: [N_MUST], SHOULD: [N_SHOULD], MAY: [N_MAY], INFO: [N_INFO]. Coverage cấp lane: [LANE_COVERAGE_PCT]%. File đầu ra: signals.json + lane-status.json.

[CD41_SECTION]

**Tiếp theo:** Orchestrator aggregate signals tại Phase 5 — coverage matrix sẽ tổng hợp với các lanes còn lại.

[NẾU FAIL/TIMEOUT:]
**Vấn đề:** [ERROR_MESSAGE] (error code [ERROR_CODE])
**Cách xử lý:** [RETRY_PLAN | ESCALATE_REASON]

<!--
CD41_SECTION TEMPLATE (chỉ insert khi LANE_ID=CD41 — Phase 4 dispatch awk substitute):

**E2E synth metrics (CD41 v3):**
- Scenarios synthesized: [N_SYNTH] / valid [N_VALID] / skipped low_confidence [N_SKIPPED_LOW]
- Cross-module scenarios: [N_CROSS_MODULE]/[N_VALID]
- Filter dims applied: [FILTER_DIMS_COMMA_LIST]
- Manifest: [LANE_DIR]/scenarios-manifest.json
- Phase 9 input ready: [PHASE9_READY_YES_NO] (yes nếu --exec-scenarios bật + manifest có ≥1 valid scenario)

Khác CD41 → [CD41_SECTION] thay bằng chuỗi rỗng → keep lane report 15 dòng standard.
-->

