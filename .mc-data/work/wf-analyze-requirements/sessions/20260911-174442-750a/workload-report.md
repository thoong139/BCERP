# Workload Report — wf-analyze-requirements

| Mục | Giá trị |
| --- | --- |
| Skill | wf-analyze-requirements |
| Profile | standard |
| Timestamp | 2026-09-12T00:55:00+07:00 |
| Items (departments) | 5 |
| Partitions | 1 (max 5 items/partition) |
| est_minutes_per_item | 3.0 |
| Complexity factor | 2.0 (multi-system 6 platforms + compliance domain: AML/KYC, PDPA/GDPR, SoD) |
| LEGACY_MODE | false |
| Total minutes (ước lượng) | 30 |
| Threshold | 45 |
| Gate status | dead_zone |
| Ratio | 0.667 |
| Khuyến nghị | dead_zone → tiếp tục silent, không cần prompt user |

| # | group_key | items | minutes |
| --- | --- | --- | --- |
| 1 | department | DEPT-BOD, DEPT-HR, DEPT-FINANCE, DEPT-SALES, DEPT-OPS | 30 |

> Ghi chú: python _shared/partition không chạy được trên máy này (no Python) — tính heuristic tương đương inline, tham số giữ nguyên theo procedure. Ước lượng chỉ mang tính định hướng thời gian thực thi agent, không giới hạn phạm vi phân tích.
