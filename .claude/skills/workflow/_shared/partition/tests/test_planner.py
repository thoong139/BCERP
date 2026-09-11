"""test_planner.py — Unit tests cho partition planner."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from partition.planner import Partition, plan_partitions, estimate_workload


class TestPlanPartitions:
    """Test plan_partitions: grouping, splitting, edge cases."""

    def test_empty_items_returns_empty(self):
        """Items rỗng → partitions rỗng."""
        assert plan_partitions([], "department") == []

    def test_single_item_creates_one_partition(self):
        """1 item → 1 partition."""
        items = [{"department": "sales", "name": "A"}]
        result = plan_partitions(items, "department")
        assert len(result) == 1
        assert result[0].group_key == "sales"
        assert len(result[0].items) == 1

    def test_grouping_by_key(self):
        """Items group đúng theo group_key."""
        items = [
            {"department": "sales", "id": 1},
            {"department": "hr", "id": 2},
            {"department": "sales", "id": 3},
        ]
        result = plan_partitions(items, "department")
        assert len(result) == 2
        groups = {p.group_key: p for p in result}
        assert len(groups["sales"].items) == 2
        assert len(groups["hr"].items) == 1

    def test_split_oversized_group(self):
        """Group > max_per_partition → split thành nhiều partitions."""
        items = [{"department": "sales", "id": i} for i in range(7)]
        result = plan_partitions(items, "department", max_per_partition=5)
        assert len(result) == 2
        assert len(result[0].items) == 5
        assert len(result[1].items) == 2

    def test_missing_group_key_raises(self):
        """Item thiếu group_key → ValueError."""
        items = [{"name": "A"}]
        with pytest.raises(ValueError, match="thiếu field"):
            plan_partitions(items, "department")

    def test_non_dict_item_raises(self):
        """Item không phải dict → ValueError."""
        items = ["not a dict"]
        with pytest.raises(ValueError, match="phải là dict"):
            plan_partitions(items, "department")


class TestEstimateWorkload:
    """Test estimate_workload."""

    def test_estimate_calculation(self):
        """Estimate = items × est_minutes_per_item."""
        partitions = [
            Partition(items=[{}, {}], group_key="sales", group_field="department"),
            Partition(items=[{}], group_key="hr", group_field="department"),
        ]
        result = estimate_workload(partitions, est_minutes_per_item=5.0)
        assert result.total_minutes == 15.0  # 3 items × 5.0
        assert result.items_count == 3
        assert result.partition_count == 2

    def test_estimate_empty(self):
        """Empty partitions → zero estimate."""
        result = estimate_workload([], est_minutes_per_item=3.0)
        assert result.total_minutes == 0.0
        assert result.items_count == 0
