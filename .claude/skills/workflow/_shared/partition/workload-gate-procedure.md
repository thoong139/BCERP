# Workload Gate Procedure

> Dùng bởi SKILL.md reference khi gọi partition planner + workload gate.

## 1. Hiển thị Estimate cho User

Sau khi `estimate_workload()`:

```
📊 Workload Estimate:
- Tổng items: {items_count}
- Số partitions: {partition_count}
- Ước lượng thời gian: {total_minutes:.0f} phút
- Threshold: {threshold_minutes} phút
```

## 2. Gate Decision → Action

| Status | Ratio | Hành động |
|--------|-------|-----------|
| `dead_zone` | < 0.8 | Tiếp tục bình thường |
| `warn` | 0.8 - 1.5 | Hiển thị cảnh báo + Plan A options |
| `block` | > 1.5 | DỪNG — user phải chọn Plan A hoặc Plan B |

## 3. Plan A Options

Khi status = `warn` hoặc `block`, đề xuất:

1. **Thu hẹp scope** — loại modules/features thấp priority
2. **Hạ profile** — deep → standard, standard → quick
3. **Override + CDG** — user xác nhận tiếp tục với risk, ghi CDG token

## 4. Plan B — Partition thành Workloads

Khi status = `block` và user chọn Plan B:

```
📋 Plan B — Chia thành {N} workloads:
- Workload 1: {keys} — {minutes:.0f} phút
- Workload 2: {keys} — {minutes:.0f} phút
- ...
```

Chạy từng workload tuần tự, checkpoint giữa mỗi workload.

## 5. AskUserQuestion Format

```python
AskUserQuestion(
    questions=[{
        "question": f"Workload ước lượng {total:.0f} phút vượt threshold {threshold} phút. Bạn muốn xử lý sao?",
        "header": "Workload",
        "options": [
            {"label": "Thu hẹp scope", "description": "Loại modules thấp priority"},
            {"label": "Hạ profile", "description": f"Chuyển từ {current} → {lower}"},
            {"label": "Chia workloads (Plan B)", "description": f"Chia thành {n} workload chạy tuần tự"},
            {"label": "Override + CDG", "description": "Tiếp tục với risk — cần CDG confirm"},
        ],
        "multiSelect": False,
    }]
)
```
