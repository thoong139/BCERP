#!/usr/bin/env python3
"""aggregator.py — Generic signal aggregator + dedup cho linear skills.

Vai trò:
    Gom output từ nhiều lanes (lane-signal.json), dedup theo configurable
    key function, phát hiện conflicts khi items trùng key từ nhiều lanes.

    Khác với signal_bus.py gốc (QD-specific, dedup theo dimension+file+line),
    module này dùng dedup_key_fn do caller cung cấp.

Registry role: NONE.

Tham chiếu:
    - ADR-OPT-04: Generic signal aggregator
    - Refactor từ _shared/signal_bus/signal_bus.py
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class Conflict:
    """Items trùng key từ nhiều lanes.

    Attributes:
        key: Dedup key trùng.
        sources: Lane keys chứa item trùng.
        items: Danh sách items có cùng key.
    """

    key: str
    sources: list[str]
    items: list[dict[str, Any]]


@dataclass
class AggregationResult:
    """Kết quả aggregation.

    Attributes:
        total_input: Tổng items đầu vào (trước dedup).
        total_output: Tổng items sau dedup.
        duplicates: Số items bị loại do duplicate.
        conflicts: Danh sách conflicts phát hiện.
        items: Danh sách items cuối cùng (đã dedup).
    """

    total_input: int
    total_output: int
    duplicates: int
    conflicts: list[Conflict]
    items: list[dict[str, Any]]


# ──────────────────────────────────────────────────────────────────────
# Dedup key functions
# ──────────────────────────────────────────────────────────────────────


def dedup_by_id(id_field: str = "id") -> Callable[[dict[str, Any]], str]:
    """Tạo dedup key function theo 1 ID field.

    Args:
        id_field: Field name dùng làm key (default: "id").

    Returns:
        Function nhận item dict → dedup key string.
    """
    def _fn(item: dict[str, Any]) -> str:
        val = item.get(id_field, "")
        return str(val) if val is not None else ""
    return _fn


def dedup_by_composite(fields: list[str]) -> Callable[[dict[str, Any]], str]:
    """Tạo dedup key function theo composite fields.

    Args:
        fields: Danh sách field names. Values nối bằng "|".

    Returns:
        Function nhận item dict → dedup key string.
    """
    def _fn(item: dict[str, Any]) -> str:
        parts = [str(item.get(f, "")) for f in fields]
        return "|".join(parts)
    return _fn


# ──────────────────────────────────────────────────────────────────────
# Core aggregation
# ──────────────────────────────────────────────────────────────────────


def aggregate_lane_signals(
    lane_outputs: list[Path],
    dedup_key_fn: Callable[[dict[str, Any]], str] | None = None,
) -> AggregationResult:
    """Gom lane outputs, dedup, detect conflicts.

    Logic:
        1. Đọc tất cả lane output files
        2. Flatten items từ mỗi lane
        3. Dedup theo dedup_key_fn
        4. Phát hiện conflicts (items trùng key từ nhiều lanes)
        5. Trả về AggregationResult

    Args:
        lane_outputs: Danh sách path đến lane signal JSON files.
        dedup_key_fn: Function tạo dedup key. None = dedup_by_id("id").

    Returns:
        AggregationResult với deduped items và conflicts.
    """
    if dedup_key_fn is None:
        dedup_key_fn = dedup_by_id("id")

    # Thu thập tất cả items kèm source
    all_items: list[tuple[dict[str, Any], str]] = []
    for lane_path in lane_outputs:
        if not lane_path.exists():
            continue
        try:
            data = json.loads(lane_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue

        lane_key = data.get("lane_key", str(lane_path))
        items = data.get("items", [])
        if isinstance(items, list):
            for item in items:
                if isinstance(item, dict):
                    all_items.append((item, lane_key))

    # Dedup + detect conflicts
    seen: dict[str, tuple[dict[str, Any], str]] = {}
    conflicts: list[Conflict] = []
    duplicates = 0
    conflict_tracker: dict[str, list[tuple[str, dict[str, Any]]]] = {}

    for item, source in all_items:
        key = dedup_key_fn(item)
        if not key:
            continue

        if key in seen:
            duplicates += 1
            # Track conflict
            if key not in conflict_tracker:
                existing_item, existing_source = seen[key]
                conflict_tracker[key] = [
                    (existing_source, existing_item)
                ]
            conflict_tracker[key].append((source, item))
        else:
            seen[key] = (item, source)

    # Build conflicts
    for key, entries in conflict_tracker.items():
        sources = list(dict.fromkeys(e[0] for e in entries))
        items = [e[1] for e in entries]
        conflicts.append(Conflict(key=key, sources=sources, items=items))

    # Final items = unique keys, giữ first-seen
    final_items = [v[0] for v in seen.values()]

    return AggregationResult(
        total_input=len(all_items),
        total_output=len(final_items),
        duplicates=duplicates,
        conflicts=conflicts,
        items=final_items,
    )


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: aggregate lane signals."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Generic signal aggregator")
    parser.add_argument(
        "--lane-files",
        nargs="+",
        required=True,
        type=Path,
        help="Lane signal JSON files",
    )
    parser.add_argument(
        "--dedup-field",
        default="id",
        help="Field name dùng để dedup (default: id)",
    )
    parser.add_argument(
        "--composite-fields",
        nargs="+",
        help="Nếu chỉ định, dùng composite key thay vì single field",
    )

    args = parser.parse_args(argv)

    try:
        if args.composite_fields:
            key_fn = dedup_by_composite(args.composite_fields)
        else:
            key_fn = dedup_by_id(args.dedup_field)

        result = aggregate_lane_signals(args.lane_files, key_fn)

        output = {
            "total_input": result.total_input,
            "total_output": result.total_output,
            "duplicates": result.duplicates,
            "conflicts_count": len(result.conflicts),
            "items_count": len(result.items),
        }

        print(json.dumps(output, indent=2, ensure_ascii=False))
        return 0

    except Exception as exc:
        print(f"[aggregator ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
