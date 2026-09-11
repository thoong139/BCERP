"""test_workload_gate.py — Unit tests cho workload gate."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from partition.planner import Partition, estimate_workload
from partition.workload_gate import GateResult, check_workload_gate


def _make_estimate(total_minutes: float, n_partitions: int = 2) -> "WorkloadEstimate":
    """Helper tạo WorkloadEstimate với total_minutes giả."""
    from partition.planner import WorkloadEstimate

    parts = [
        Partition(
            items=[{"id": i}],
            group_key=f"p{i}",
            group_field="test",
            estimated_minutes=total_minutes / n_partitions,
        )
        for i in range(n_partitions)
    ]
    return WorkloadEstimate(
        total_minutes=total_minutes,
        partition_count=n_partitions,
        items_count=n_partitions,
        partitions=parts,
    )


class TestWorkloadGate:
    """Test check_workload_gate: zones và recommendations."""

    def test_dead_zone(self):
        """Ratio < 0.8 → dead_zone."""
        est = _make_estimate(30.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "dead_zone"
        assert result.ratio < 0.8

    def test_warn_zone(self):
        """Ratio 0.8-1.5 → warn."""
        est = _make_estimate(60.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "warn"
        assert 0.8 <= result.ratio <= 1.5
        assert len(result.plan_a_options) > 0

    def test_block_zone(self):
        """Ratio > 1.5 → block."""
        est = _make_estimate(120.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "block"
        assert result.ratio > 1.5
        assert result.plan_b_partitions is not None

    def test_zero_threshold_raises(self):
        """Threshold = 0 → ValueError."""
        est = _make_estimate(10.0)
        with pytest.raises(ValueError, match="phải > 0"):
            check_workload_gate(est, threshold_minutes=0)

    def test_exact_boundary_dead_to_warn(self):
        """Ratio = 0.8 chính xác → warn."""
        est = _make_estimate(48.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "warn"

    def test_exact_boundary_warn_to_block(self):
        """Ratio = 1.5 chính xác → warn (boundary inclusive)."""
        est = _make_estimate(90.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "warn"

    def test_just_over_boundary_warn_to_block(self):
        """Ratio > 1.5 → block."""
        est = _make_estimate(91.0)
        result = check_workload_gate(est, threshold_minutes=60.0)
        assert result.status == "block"
