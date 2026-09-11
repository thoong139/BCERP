#!/usr/bin/env python3
"""workload_gate.py — Workload gate decision cho linear skills.

Vai trò:
    Đánh giá workload estimate so với threshold, quyết định:
    - dead_zone (< 0.8×threshold): chạy bình thường
    - warn (0.8-1.5×threshold): cảnh báo, đề xuất Plan A options
    - block (> 1.5×threshold): dừng, yêu cầu Plan B (partition thành workloads)

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-03: Workload gate procedure
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from typing import Any

from .planner import Partition, WorkloadEstimate

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

# Multiplier cho threshold zones
DEAD_ZONE_MULTIPLIER = 0.8
WARN_MULTIPLIER = 1.5

PLAN_A_OPTIONS = [
    "Thu hẹp scope — loại modules thấp priority",
    "Hạ profile (deep → standard, standard → quick)",
    "Override + CDG — user xác nhận tiếp tục với risk",
]


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class GateResult:
    """Kết quả workload gate decision.

    Attributes:
        status: "dead_zone" | "warn" | "block"
        ratio: Tỷ lệ estimate / threshold
        plan_a_options: Các lựa chọn nếu warn/block
        plan_b_partitions: Partitions nếu cần chia nhỏ (Plan B)
    """

    status: str
    ratio: float
    plan_a_options: list[str] = field(default_factory=list)
    plan_b_partitions: list[Partition] | None = None


# ──────────────────────────────────────────────────────────────────────
# Core function
# ──────────────────────────────────────────────────────────────────────


def check_workload_gate(
    estimate: WorkloadEstimate,
    threshold_minutes: float,
) -> GateResult:
    """Đánh giá workload so với threshold.

    Zones:
        - dead_zone: ratio < 0.8 (chạy bình thường)
        - warn: 0.8 ≤ ratio ≤ 1.5 (cảnh báo, đề xuất options)
        - block: ratio > 1.5 (dừng, yêu cầu Plan B hoặc CDG)

    Args:
        estimate: Workload estimate từ plan_partitions.
        threshold_minutes: Ngưỡng thời gian (phút).

    Returns:
        GateResult với status và recommendations.
    """
    if threshold_minutes <= 0:
        raise ValueError("threshold_minutes phải > 0")

    ratio = estimate.total_minutes / threshold_minutes

    if ratio < DEAD_ZONE_MULTIPLIER:
        return GateResult(
            status="dead_zone",
            ratio=ratio,
        )

    if ratio <= WARN_MULTIPLIER:
        return GateResult(
            status="warn",
            ratio=ratio,
            plan_a_options=list(PLAN_A_OPTIONS),
        )

    # Block zone: tính Plan B partitions
    # Chia partitions thành workloads sao cho mỗi workload ≤ threshold
    plan_b = _compute_plan_b(estimate.partitions, threshold_minutes)

    return GateResult(
        status="block",
        ratio=ratio,
        plan_a_options=list(PLAN_A_OPTIONS),
        plan_b_partitions=plan_b,
    )


def _compute_plan_b(
    partitions: list[Partition],
    threshold_minutes: float,
) -> list[Partition]:
    """Tính Plan B: merge partitions thành workloads ≤ threshold.

    First-fit decreasing: sort partitions theo estimated_minutes giảm dần,
    rồi assign vào workloads sao cho tổng mỗi workload ≤ threshold.

    Args:
        partitions: Danh sách partitions gốc.
        threshold_minutes: Ngưỡng mỗi workload.

    Returns:
        Danh sách merged partitions (Plan B workloads).
    """
    if not partitions:
        return []

    # Sort giảm dần theo estimated_minutes
    sorted_parts = sorted(
        partitions, key=lambda p: p.estimated_minutes, reverse=True
    )

    # First-fit decreasing bin packing
    bins: list[tuple[float, list[Partition]]] = []

    for part in sorted_parts:
        placed = False
        for i, (bin_total, bin_parts) in enumerate(bins):
            if bin_total + part.estimated_minutes <= threshold_minutes:
                bins[i] = (bin_total + part.estimated_minutes, bin_parts + [part])
                placed = True
                break

        if not placed:
            bins.append((part.estimated_minutes, [part]))

    # Merge bins thành Partition objects
    result: list[Partition] = []
    for i, (total, parts) in enumerate(bins, 1):
        all_items: list[dict[str, Any]] = []
        group_keys: list[str] = []
        for p in parts:
            all_items.extend(p.items)
            group_keys.append(p.group_key)

        result.append(
            Partition(
                items=all_items,
                group_key=f"workload-{i}",
                group_field="_workload",
                estimated_minutes=total,
            )
        )

    return result
