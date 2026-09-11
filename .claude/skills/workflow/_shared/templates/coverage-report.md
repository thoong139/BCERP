# Coverage Report — Dimension Scan

## Thông tin chung

| Mục | Giá trị |
|-----|---------|
| **Profile** | {{PROFILE}} |
| **Dimensions chạy** | {{DIMENSIONS_LIST}} |
| **Dimensions bỏ qua** | {{SKIPPED_DIMENSIONS}} |
| **Thời gian** | {{STARTED_AT}} → {{COMPLETED_AT}} |
| **Session** | {{SESSION_DIR}} |

## Dimension Coverage

| Dimension | Tên | Probes | Signals | Issues | Thời gian |
|-----------|-----|--------|---------|--------|-----------|
{{DIMENSION_TABLE_ROWS}}

## Tổng hợp

- **Tổng signals (trước dedup):** {{TOTAL_SIGNALS}}
- **Tổng issues (sau dedup):** {{TOTAL_ISSUES}}
- **Dimensions có issues:** {{DIMENSIONS_WITH_ISSUES}} / {{DIMENSIONS_RUN}}
- **Coverage rate:** {{COVERAGE_PCT}}%

## Phân loại Issues

| Severity | Số lượng |
|----------|----------|
{{SEVERITY_TABLE_ROWS}}

## Đề xuất

{{RECOMMENDATIONS}}

---
*Tạo bởi wf-fix-bugs v6 engine — signal_aggregator.py*
