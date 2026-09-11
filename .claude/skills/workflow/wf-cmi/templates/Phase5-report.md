<!--
_schema_notes:
  purpose: Phase 5 (Aggregate) report v2.0. CORE-028 ≤15 dòng tiếng Việt, cho người không chuyên.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Coverage matrix v2 summary (26 active dims + threshold)
    - [CDG_NOTE] dùng cho E090 trigger (procedure điền nếu user accept/generate/abort)
  placeholders procedure populate (xem phase5-aggregate.md Step 5.8):
    [STATUS] [TIMESTAMP] [OVERALL_PCT] [OVERALL_STATUS] [BELOW_COUNT] [TOTAL_SIGNALS] [CDG_NOTE]
  delete_before_write: true
-->
## Phase 5: Tổng hợp coverage matrix — [STATUS]
Thời gian: [TIMESTAMP]

**Đã làm:** Tổng hợp signals từ các lanes Phase 4 → coverage matrix v2 (35 dims = 26 active Gói C++ + 9 SKIPPED). Dedup theo fingerprint, áp dụng threshold theo profile.

**Kết quả:**
- Coverage tổng: [OVERALL_PCT]% — Trạng thái: [OVERALL_STATUS]
- Số chiều dưới ngưỡng: [BELOW_COUNT]
- Signals (sau dedup): [TOTAL_SIGNALS]
- File đầu ra: coverage-matrix.json + coverage-report.md + signals-aggregated.jsonl
[CDG_NOTE]

**Tiếp theo:** Phase 6 — Regression Map (skip nếu profile=quick hoặc HEALTHY E005 → jump Phase 8).
