#!/usr/bin/env python3
"""planner.py — Generic partition planner cho linear workflow skills.

Vai trò:
    Chia danh sách items thành partitions theo group_key, ước lượng
    workload, trả về partition plan.

    Khác với partition_planner.py gốc (QD-specific), module này group
    theo bất kỳ key field nào (department, system, module, v.v.).

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-03: Generic partition planner + workload gate
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import OrderedDict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class Partition:
    """Một nhóm items sau khi partition.

    Attributes:
        items: Danh sách items trong partition.
        group_key: Giá trị của group_key (vd: "sales", "crm").
        group_field: Tên field dùng để group (vd: "department").
        estimated_minutes: Thời gian ước lượng.
    """

    items: list[dict[str, Any]]
    group_key: str
    group_field: str
    estimated_minutes: float = 0.0


@dataclass
class WorkloadEstimate:
    """Kết quả ước lượng workload tổng.

    Attributes:
        total_minutes: Tổng thời gian ước lượng.
        partition_count: Số partitions.
        items_count: Tổng số items.
        partitions: Danh sách Partition.
    """

    total_minutes: float
    partition_count: int
    items_count: int
    partitions: list[Partition]


# ──────────────────────────────────────────────────────────────────────
# Core functions
# ──────────────────────────────────────────────────────────────────────


def plan_partitions(
    items: list[dict[str, Any]],
    group_key: str,
    max_per_partition: int = 5,
) -> list[Partition]:
    """Chia items thành partitions theo group_key.

    Logic:
        1. Group items theo giá trị của group_key field
        2. Mỗi group thành 1 Partition
        3. Nếu 1 group > max_per_partition → split thành nhiều partitions

    Args:
        items: Danh sách items cần partition.
        group_key: Field name dùng để group (vd: "department", "system").
        max_per_partition: Số items tối đa mỗi partition.

    Returns:
        Danh sách Partition, sắp xếp theo group_key.

    Raises:
        ValueError: items rỗng hoặc group_key không tồn tại.
    """
    if not items:
        return []

    # Group theo group_key
    groups: OrderedDict[str, list[dict[str, Any]]] = OrderedDict()
    for item in items:
        if not isinstance(item, dict):
            raise ValueError(f"Item phải là dict, nhận {type(item).__name__}")
        key_value = item.get(group_key)
        if key_value is None:
            raise ValueError(
                f"Item thiếu field '{group_key}': {list(item.keys())}"
            )
        key_str = str(key_value)
        if key_str not in groups:
            groups[key_str] = []
        groups[key_str].append(item)

    # Tạo partitions, split nếu vượt max
    partitions: list[Partition] = []
    for group_val, group_items in groups.items():
        if len(group_items) <= max_per_partition:
            partitions.append(
                Partition(
                    items=list(group_items),
                    group_key=group_val,
                    group_field=group_key,
                )
            )
        else:
            # Split thành chunks
            for i in range(0, len(group_items), max_per_partition):
                chunk = group_items[i : i + max_per_partition]
                chunk_suffix = (
                    f"-{i // max_per_partition + 1}"
                    if len(group_items) > max_per_partition
                    else ""
                )
                partitions.append(
                    Partition(
                        items=list(chunk),
                        group_key=f"{group_val}{chunk_suffix}",
                        group_field=group_key,
                    )
                )

    return partitions


def estimate_workload(
    partitions: list[Partition],
    est_minutes_per_item: float = 3.0,
) -> WorkloadEstimate:
    """Ước lượng workload cho partitions.

    Args:
        partitions: Danh sách Partition.
        est_minutes_per_item: Số phút ước lượng cho mỗi item.

    Returns:
        WorkloadEstimate với total, counts, partitions.
    """
    total_items = sum(len(p.items) for p in partitions)

    # Cập nhật estimated_minutes cho mỗi partition
    for p in partitions:
        p.estimated_minutes = len(p.items) * est_minutes_per_item

    total_minutes = sum(p.estimated_minutes for p in partitions)

    return WorkloadEstimate(
        total_minutes=total_minutes,
        partition_count=len(partitions),
        items_count=total_items,
        partitions=list(partitions),
    )


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: partition items từ JSON file."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Generic partition planner")
    parser.add_argument(
        "--items-file",
        required=True,
        type=Path,
        help="JSON file chứa items list",
    )
    parser.add_argument(
        "--group-key",
        required=True,
        help="Field name để group",
    )
    parser.add_argument(
        "--max-per-partition",
        type=int,
        default=5,
        help="Max items per partition",
    )
    parser.add_argument(
        "--est-minutes",
        type=float,
        default=3.0,
        help="Estimated minutes per item",
    )

    args = parser.parse_args(argv)

    try:
        items = json.loads(args.items_file.read_text(encoding="utf-8"))
        if not isinstance(items, list):
            print("[ERROR] items phải là array", file=sys.stderr)
            return 1

        partitions = plan_partitions(items, args.group_key, args.max_per_partition)
        estimate = estimate_workload(partitions, args.est_minutes)

        result = {
            "total_minutes": estimate.total_minutes,
            "partition_count": estimate.partition_count,
            "items_count": estimate.items_count,
            "partitions": [
                {
                    "group_key": p.group_key,
                    "items_count": len(p.items),
                    "estimated_minutes": p.estimated_minutes,
                }
                for p in estimate.partitions
            ],
        }

        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    except Exception as exc:
        print(f"[partition ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
