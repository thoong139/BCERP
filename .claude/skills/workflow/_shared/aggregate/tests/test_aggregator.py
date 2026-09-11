"""test_aggregator.py — Unit tests cho aggregate module."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from aggregate.aggregator import (
    AggregationResult,
    Conflict,
    aggregate_lane_signals,
    dedup_by_composite,
    dedup_by_id,
)


def _write_lane_signal(path: Path, lane_key: str, items: list[dict]) -> None:
    """Helper ghi lane signal file."""
    data = {
        "$schema": "lane-signal-v1",
        "lane_key": lane_key,
        "lane_type": "department",
        "items": items,
        "metadata": {},
    }
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


class TestDedupKeyFunctions:
    """Test dedup key functions."""

    def test_dedup_by_id_default(self):
        """dedup_by_id mặc định dùng field 'id'."""
        fn = dedup_by_id()
        assert fn({"id": "REQ-001"}) == "REQ-001"
        assert fn({"id": "REQ-002"}) == "REQ-002"

    def test_dedup_by_id_custom_field(self):
        """dedup_by_id dùng field tùy chỉnh."""
        fn = dedup_by_id("name")
        assert fn({"name": "sales"}) == "sales"

    def test_dedup_by_composite(self):
        """dedup_by_composite nối fields bằng |."""
        fn = dedup_by_composite(["department", "module"])
        assert fn({"department": "sales", "module": "crm"}) == "sales|crm"

    def test_dedup_by_id_missing_field(self):
        """Field không tồn tại → empty string."""
        fn = dedup_by_id("missing")
        assert fn({"id": "REQ-001"}) == ""

    def test_dedup_by_id_none_value(self):
        """Field có giá trị None → empty string."""
        fn = dedup_by_id("id")
        assert fn({"id": None}) == ""


class TestAggregate:
    """Test aggregate_lane_signals."""

    def test_empty_input(self, tmp_path):
        """Không có file → empty result."""
        result = aggregate_lane_signals([])
        assert result.total_input == 0
        assert result.total_output == 0
        assert result.items == []

    def test_single_lane_no_duplicates(self, tmp_path):
        """1 lane, không trùng → tất cả items giữ lại."""
        path = tmp_path / "lane1.json"
        _write_lane_signal(path, "dept-sales", [
            {"id": "REQ-001", "name": "A"},
            {"id": "REQ-002", "name": "B"},
        ])

        result = aggregate_lane_signals([path])
        assert result.total_input == 2
        assert result.total_output == 2
        assert result.duplicates == 0

    def test_multiple_lanes_with_duplicates(self, tmp_path):
        """2 lanes có items trùng ID → dedup, detect conflict."""
        path1 = tmp_path / "lane1.json"
        path2 = tmp_path / "lane2.json"
        _write_lane_signal(path1, "dept-sales", [
            {"id": "REQ-001", "name": "A"},
            {"id": "REQ-002", "name": "B"},
        ])
        _write_lane_signal(path2, "dept-hr", [
            {"id": "REQ-001", "name": "A_dup"},  # duplicate
            {"id": "REQ-003", "name": "C"},
        ])

        result = aggregate_lane_signals([path1, path2])
        assert result.total_input == 4
        assert result.total_output == 3
        assert result.duplicates == 1
        assert len(result.conflicts) == 1
        assert result.conflicts[0].key == "REQ-001"
        assert len(result.conflicts[0].sources) == 2

    def test_nonexistent_file_skipped(self, tmp_path):
        """File không tồn tại → skip, không crash."""
        result = aggregate_lane_signals([tmp_path / "nonexistent.json"])
        assert result.total_input == 0

    def test_composite_key_dedup(self, tmp_path):
        """Dedup bằng composite key."""
        path1 = tmp_path / "lane1.json"
        path2 = tmp_path / "lane2.json"
        _write_lane_signal(path1, "dept-sales", [
            {"department": "sales", "module": "crm", "id": "1"},
        ])
        _write_lane_signal(path2, "dept-hr", [
            {"department": "sales", "module": "crm", "id": "2"},  # trùng composite
        ])

        key_fn = dedup_by_composite(["department", "module"])
        result = aggregate_lane_signals([path1, path2], key_fn)
        assert result.total_output == 1
        assert result.duplicates == 1
