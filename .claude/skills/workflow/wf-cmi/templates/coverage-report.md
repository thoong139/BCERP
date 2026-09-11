<!--
_schema_notes:
  purpose: Coverage report tiếng Việt cho người vận hành (CORE-028). Phase 5 output v2.0.
  rules:
    - Max 20 dòng total (v2 relaxed cho 26 active dims grouped — v1 ≤15)
    - Tiếng Việt, không jargon
    - Bảng dim list được phase5-aggregate.md Step 5.6 inject vào [DIM_TABLE] (awk replace)
    - Group headers (Core/Frontend/Backend/UX/Logistics/Compliance/Implementation) được procedure thêm trước mỗi dim group
    - SKIPPED dims (v2 baseline 9) KHÔNG hiển thị trong [DIM_TABLE] (chỉ active + dims có signal)
    - Placeholders procedure populate: [OVERALL_STATUS], [OVERALL_PCT], [THRESHOLD], [BELOW_COUNT], [TOTAL_SIGNALS], [TIMESTAMP], [DIM_TABLE]
  delete_before_write: true
-->
## Coverage matrix v2 — Gói C++ Logistics

**Thời điểm:** [TIMESTAMP] — **Ngưỡng:** [THRESHOLD]% — **Tổng:** [OVERALL_PCT]% — **Trạng thái:** [OVERALL_STATUS]

**Tóm tắt:** [BELOW_COUNT] chiều dưới ngưỡng, [TOTAL_SIGNALS] signals (sau dedup).

[DIM_TABLE]

Chi tiết: [coverage-matrix.json](coverage-matrix.json) · Wave breakdown trong matrix `wave_breakdown{}`.
