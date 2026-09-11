# Workload Gate Report

## Thông tin chung
- Skill: {skill_name}
- Profile: {profile_used}
- Ngày: {timestamp}

## Workload Estimate
- Tổng items: {items_count}
- Số partitions: {partition_count}
- Ước lượng thời gian: **{total_minutes} phút**
- Threshold: {threshold_minutes} phút

## Gate Decision
- **Status:** {gate_status}
- **Ratio:** {ratio}x

{gate_recommendation}

## Chi tiết Partitions

| # | Group Key | Items | Ước lượng (phút) |
|---|-----------|-------|-------------------|
{partition_rows}
