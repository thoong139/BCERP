# Lane Report — {{DIMENSION_ID}}

## Thông tin chung

| Mục | Giá trị |
|-----|---------|
| **Dimension** | {{DIMENSION_ID}} — {{DIMENSION_NAME}} |
| **Profile** | {{PROFILE}} |
| **Thời gian** | {{STARTED_AT}} → {{COMPLETED_AT}} |
| **Session** | {{SESSION_DIR}} |

## Kết quả

- **Probes chạy:** {{PROBES_TOTAL}} / {{PROBES_AVAILABLE}}
- **Signals phát hiện:** {{SIGNALS_COUNT}}
- **Issues (sau dedup):** {{ISSUES_COUNT}}

## Chi tiết Probes

| Probe ID | Kết quả | Signals |
|----------|---------|---------|
{{PROBE_TABLE_ROWS}}

## Issues phát hiện

{{ISSUES_DETAIL}}

## Đề xuất

{{RECOMMENDATIONS}}

---
*Tạo bởi wf-fix-bugs v6 engine — lane_dispatch.py*
