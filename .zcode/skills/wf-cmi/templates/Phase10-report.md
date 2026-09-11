<!--
_schema_notes:
  purpose: Phase 10 (E2E Resolution — failure analyzer 7-type + 2-phase auto-fix + loop-back gap-suggestions) report. CORE-028 ≤15 dòng tiếng Việt cho người không chuyên.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Summary: FAIL classified per type + auto-fix outcomes (browser-fix / source-fix) + loop-back suggestions APPEND + next step
    - Note: Phase 10 chỉ chạy nếu Phase 9 có ≥1 FAIL. 0 FAIL → SKIP (không tạo report)
    - Note: --auto-fix-source CDG E195 quyết định cho phép spawn agent sửa source hay không
  delete_before_write: true
-->
## Phase 10: E2E Resolution — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)
Auto-fix source: [AUTO_FIX_SOURCE_ON_OFF] (CDG E195: [USER_DECISION])

**Đã làm:** Phân loại [N_FAIL] failures theo 7 loại (NETWORK_ERROR/AUTH_FAILURE/DATA_MISSING/TEST_SELECTOR/UI_BUG/BUSINESS_RULE/UNKNOWN). Thu evidence (console+network+DOM). Áp dụng 2-phase auto-fix: Phase A browser-fix (retry/re-login/selector fallback), Phase B source-fix (spawn agent nếu có flag).

**Kết quả:**

- Failure type breakdown: NETWORK [N_NET] · AUTH [N_AUTH] · DATA [N_DATA] · SELECTOR [N_SEL] · UI_BUG [N_UI] · BUSINESS [N_BR] · UNKNOWN [N_UNK]
- Auto-fix outcomes: Browser-fix PASS [N_BFIX_PASS]/[N_BFIX_TRY] · Source-fix PASS [N_SFIX_PASS]/[N_SFIX_TRY] (spawn [N_AGENTS] agents)
- Loop-back: APPEND [N_LOOP_BACK] suggestions vào gap-suggestions.json kind="e2e_scenario_fix" (KHÔNG re-trigger CD41)
- File chính: resolution-report.md + updated gap-suggestions.json

**Tiếp theo:** Phase 8 — Report (re-write integrity-report.md với section E2E Summary đầy đủ Phase 9+10 outcomes).

[NẾU FAIL (vd E190 spawn agent fail, E192 HMR reload timeout, E195 user REJECT source-fix):]
**Vấn đề:** [ERROR_MESSAGE] (error code [ERROR_CODE])
**Cách xử lý:** [RECOVERY_PLAN | MANUAL_TRIAGE_REQUIRED]
