#!/usr/bin/env python3
"""partition_planner.py — Partition dimensions thành 1+ workloads.

Vai trò:
    Nhận danh sách dimensions (QD1-QD11) + optional ISG recommendation,
    chia thành 1 hoặc nhiều workloads để chạy tuần tự/parallel.

    Logic:
        1. If dimensions <= max_workload_size → single workload
        2. If ISG recommends split → follow ISG guidance
        3. Otherwise → split by priority: core dims (QD1,QD2,QD5) first, then rest

Registry role: NONE. Chỉ đọc input, tạo workload plan.

Tham chiếu:
    - ADR-14: ISG recommendation → workload sizing
    - ADR-15: Partition Planner — Plan A (single-run) vs Plan B (multi-run)
    - Stage J1 spec: docs/design/skills/wf-fix-bugs/prompts/stage-J-prompt.md
"""
from __future__ import annotations

import sys
from dataclasses import asdict, dataclass
from typing import Any

from dimension_registry import DIMENSION_REGISTRY

# Probe counts per dimension — from workload_estimator/estimator.py PROBES_PER_DIM
PROBES_PER_DIM: dict[str, int] = {
    "QD1": 3,
    "QD2": 2,
    "QD3": 2,
    "QD4": 2,
    "QD5": 3,
    "QD6": 2,
    "QD7": 1,
    "QD8": 2,
    "QD9": 7,
    "QD10": 5,
    "QD11": 3,
}


# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

CORE_DIMS: frozenset[str] = frozenset({"QD1", "QD2", "QD5"})

DEFAULT_MAX_WORKLOAD_SIZE: int = 8

# Estimated minutes per probe (conservative heuristic)
EST_MINUTES_PER_PROBE: float = 1.5

# Codebase-size awareness (F6 — Wave 3 v7.4 e2e fix).
# Symbol count > LARGE_CODEBASE_SYMBOL_THRESHOLD → halve max_workload_size
# (floor 2) để buộc multi-workload split, tránh single-workload chạy quá dài.
# Ngưỡng 5000 = phân định codebase nhỏ (vd: MCV3 ~5K) vs lớn (vd: EUREKA-2026).
LARGE_CODEBASE_SYMBOL_THRESHOLD: int = 5000
MIN_MAX_WORKLOAD_SIZE_AFTER_SCALE: int = 2


# ──────────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────────


@dataclass
class WorkloadPlan:
    """Một workload chứa subset của dimensions."""

    id: str  # "W01", "W02", ...
    dimensions: list[str]
    estimated_probes: int
    estimated_minutes: float

    def to_dict(self) -> dict[str, Any]:
        # Emit canonical fix-workload-v1 fields alongside simple fields so
        # workload-gate procedure (Step 1.5.2) can read total_estimated_sec
        # và gate_triggered trực tiếp từ JSON.
        base = asdict(self)
        threshold_sec = 2700  # 45 min — match estimator._get_threshold_sec default
        total_sec = round(self.estimated_minutes * 60, 1)
        base["$schema"] = "fix-workload-v1"
        base["workload_id"] = self.id
        base["total_estimated_sec"] = total_sec
        base["gate_threshold_sec"] = threshold_sec
        base["gate_triggered"] = total_sec > threshold_sec
        return base


# ──────────────────────────────────────────────────────────────────────────
# Core function
# ──────────────────────────────────────────────────────────────────────────


def partition_dimensions(
    dimensions: list[str],
    isg_recommendation: dict[str, Any] | None = None,
    max_workload_size: int = DEFAULT_MAX_WORKLOAD_SIZE,
    symbol_count: int = 0,
) -> list[WorkloadPlan]:
    """Partition dimensions thành 1+ workloads.

    Logic:
        1. Validate dimensions — must be valid QD IDs
        2. Codebase-size awareness: nếu symbol_count > 5000 → halve max_workload_size
        3. If len(dimensions) <= max_workload_size → single workload
        4. If ISG recommends split → follow ISG guidance (group_by field)
        5. Otherwise → split by priority: core dims (QD1,QD2,QD5) first, then rest

    Args:
        dimensions: List of dimension IDs (vd: ["QD1", "QD3", "QD5"]).
        isg_recommendation: Optional ISG recommendation dict with:
            - "split": bool — whether ISG recommends splitting
            - "groups": list[list[str]] — suggested grouping (optional)
            - "strategy": "by_priority" | "by_domain" — split strategy
        max_workload_size: Max dimensions per workload (default 8 = all 8 QDs).
        symbol_count: Total symbols trong codebase (0 = unknown, fallback default).
            >LARGE_CODEBASE_SYMBOL_THRESHOLD (5000) → halve max_workload_size
            (floor 2) để buộc multi-workload, giảm wall-clock per run.

    Returns:
        List of WorkloadPlan objects, each with id, dimensions, estimates.

    Raises:
        ValueError: dimensions rỗng hoặc chứa ID không hợp lệ.
    """
    if not dimensions:
        raise ValueError("partition_dimensions: dimensions rỗng")

    valid_dims = set(DIMENSION_REGISTRY.keys())
    invalid = [d for d in dimensions if d not in valid_dims]
    if invalid:
        raise ValueError(
            f"partition_dimensions: dimensions không hợp lệ: {invalid} "
            f"(cho phép: {sorted(valid_dims)})"
        )

    # Codebase-size scaling — chỉ áp dụng khi caller cung cấp symbol_count > 0.
    # symbol_count == 0 giữ behavior cũ (backward compat).
    if symbol_count > LARGE_CODEBASE_SYMBOL_THRESHOLD:
        scaled = (max_workload_size + 1) // 2  # ceil(7/2)=4
        max_workload_size = max(MIN_MAX_WORKLOAD_SIZE_AFTER_SCALE, scaled)

    # Case 1: fits in single workload
    if len(dimensions) <= max_workload_size and not _isg_forces_split(isg_recommendation):
        return [_make_workload("W01", dimensions)]

    # Case 2: ISG-guided partition
    if isg_recommendation and isg_recommendation.get("split"):
        groups = isg_recommendation.get("groups")
        if groups and isinstance(groups, list):
            isg_workloads = _partition_from_groups(groups)
            # Schema invariant: min 1 workload. Neu ISG groups malformed
            # (tat ca invalid dims), fall-through Case 3 thay vi return rong.
            if isg_workloads:
                return isg_workloads

    # Case 3: default priority-based split
    return _partition_by_priority(dimensions, max_workload_size)


def _isg_forces_split(isg_recommendation: dict[str, Any] | None) -> bool:
    """Check if ISG explicitly recommends splitting."""
    if isg_recommendation is None:
        return False
    return bool(isg_recommendation.get("split")) and bool(isg_recommendation.get("groups"))


def _partition_from_groups(groups: list[list[str]]) -> list[WorkloadPlan]:
    """Create workloads from ISG-provided groups."""
    workloads: list[WorkloadPlan] = []
    for i, group in enumerate(groups):
        if not isinstance(group, list):
            continue
        # Filter to valid dims only
        valid_group = [d for d in group if d in DIMENSION_REGISTRY]
        if not valid_group:
            continue
        wid = f"W{i + 1:02d}"
        workloads.append(_make_workload(wid, valid_group))
    if not workloads:
        # Fallback: single workload with all dims from all groups
        all_dims: list[str] = []
        for g in groups:
            if isinstance(g, list):
                all_dims.extend(d for d in g if d in DIMENSION_REGISTRY)
        if all_dims:
            workloads.append(_make_workload("W01", list(dict.fromkeys(all_dims))))
    return workloads


def _partition_by_priority(
    dimensions: list[str], max_workload_size: int
) -> list[WorkloadPlan]:
    """Split by priority: core dims first, then secondary, then tertiary."""
    core = [d for d in dimensions if d in CORE_DIMS]
    secondary = [d for d in dimensions if d not in CORE_DIMS]

    workloads: list[WorkloadPlan] = []
    idx = 1

    # First workload: core dims (+ fit as many secondary as possible)
    if core:
        remaining_slots = max_workload_size - len(core)
        batch = list(core)
        batch.extend(secondary[:remaining_slots])
        workloads.append(_make_workload(f"W{idx:02d}", batch))
        idx += 1
        secondary = secondary[remaining_slots:]

    # Remaining secondary dims in chunks
    while secondary:
        batch = secondary[:max_workload_size]
        workloads.append(_make_workload(f"W{idx:02d}", batch))
        idx += 1
        secondary = secondary[max_workload_size:]

    if not workloads:
        # Edge case: no core dims, no secondary — shouldn't happen after validation
        workloads.append(_make_workload("W01", dimensions))

    return workloads


def _make_workload(wid: str, dims: list[str]) -> WorkloadPlan:
    """Create a WorkloadPlan with probe + time estimates."""
    total_probes = sum(PROBES_PER_DIM.get(d, 2) for d in dims)
    estimated_minutes = round(total_probes * EST_MINUTES_PER_PROBE, 1)
    return WorkloadPlan(
        id=wid,
        dimensions=dims,
        estimated_probes=total_probes,
        estimated_minutes=estimated_minutes,
    )


# ──────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: partition dimensions into workloads."""
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Partition Planner")
    parser.add_argument(
        "--dims", nargs="+", required=True, help="Dimension IDs (QD1 QD3 QD5 ...)"
    )
    parser.add_argument(
        "--max-size", type=int, default=DEFAULT_MAX_WORKLOAD_SIZE,
        help="Max dimensions per workload",
    )
    parser.add_argument(
        "--isg-json", type=str, default=None,
        help="Path to ISG recommendation JSON (optional)",
    )
    parser.add_argument(
        "--symbol-count", type=int, default=0,
        help=(
            "Total symbols trong codebase (từ ISG recommendation hoặc tool khác). "
            f">{LARGE_CODEBASE_SYMBOL_THRESHOLD} sẽ halve max_workload_size để buộc multi-workload split. "
            "0 (default) = giữ behavior cũ."
        ),
    )

    args = parser.parse_args(argv)

    isg_rec = None
    if args.isg_json:
        try:
            with open(args.isg_json, encoding="utf-8") as fh:
                isg_rec = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[partition_planner ERROR] Cannot read ISG JSON: {exc}", file=sys.stderr)
            return 1

    try:
        workloads = partition_dimensions(
            dimensions=args.dims,
            isg_recommendation=isg_rec,
            max_workload_size=args.max_size,
            symbol_count=args.symbol_count,
        )
        output = [w.to_dict() for w in workloads]
        print(json.dumps(output, indent=2, ensure_ascii=False))
        return 0
    except ValueError as exc:
        print(f"[partition_planner ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
