<!--
_schema_notes:
  purpose: Phase 9 (E2E Execute & Verify — Playwright runtime verification) report. CORE-028 ≤15 dòng tiếng Việt cho người không chuyên.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Summary: scenarios executed + pass/fail + auto-corrected + quarantined + cross-module + duration + next step
    - Note: SKIP report nếu KHÔNG --exec-scenarios (Phase 9 không chạy)
    - Note: PRE-GATE FAIL (E150 browser unavailable) vẫn ghi report status=SKIPPED với lý do
  delete_before_write: true
-->
## Phase 9: E2E Execute & Verify — [STATUS_PASS_FAIL_SKIPPED]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)
Mode: [MODE_BROWSER_API_ONLY] · Viewport: [VIEWPORT_DESKTOP_MOBILE]

**Đã làm:** Lint [N_SCENARIOS] scenarios → pre-flight 5x stability ([N_STABLE]/[N_TOTAL] stable, [N_QUARANTINED] quarantined) → execute qua Playwright MCP với browser-mcp.lock. Capture screenshot + console + network evidence per scenario.

**Kết quả:**

- Executed: [N_EXECUTED]/[N_TOTAL] scenarios — PASS [N_PASS] · Auto-corrected [N_AUTO_CORRECTED] · FAIL [N_FAIL] · QUARANTINED [N_QUARANTINED]
- Cross-module: [N_CROSS_MODULE]/[N_EXECUTED] scenarios walk xuyên modules
- File chính: e2e-execution-report.md + e2e-results.json + screenshots/ ([N_SCREENSHOTS] ảnh)
- Stable-registry hit: [N_REGISTRY_HIT] (skip 5x pre-flight do hash khớp TTL <30d)

**Tiếp theo:** [IF N_FAIL > 0]: Phase 10 — E2E Resolution (auto-trigger phân loại 7-type + 2-phase auto-fix). [IF N_FAIL = 0]: Phase 8 — Report (build integrity-report.md với section E2E Summary).

[NẾU FAIL/SKIPPED (vd E150 Playwright DOWN, E151 lint fail, E153 lock conflict):]
**Vấn đề:** [ERROR_MESSAGE] (error code [ERROR_CODE])
**Cách xử lý:** [RECOVERY_PLAN | SKIP_NEXT_PHASE_REASON | RETRY_AFTER_USER_FIX]
