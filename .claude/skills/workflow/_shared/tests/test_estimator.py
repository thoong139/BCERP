"""test_estimator.py — Tests cho workload_estimator.estimator.

Phạm vi chính:
    - estimate_lane happy-path: công thức = probes × avg × multiplier × file_count.
    - estimate_lane guards: dim/profile/file_count invalid → raise.
    - check_gate boundary: total <= threshold → False, total > threshold → True.
    - ADR-14 default threshold = 45 phút = 2700s.
    - estimate + emit: schema-conform output fix-workload.json.
    - ADR-22 rule 1: estimator KHÔNG tự drop QD1/QD2/QD5 — user chọn gì return đó.
    - propose_partitions: tạo 2 plans (by_scope + by_dim) khi gate triggered.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from workload_estimator.estimator import (
    AVG_TIME_PER_FILE_SEC,
    GATE_THRESHOLD_SEC_DEFAULT,
    PROBES_PER_DIM,
    PROFILE_MULTIPLIER,
    SCHEMA_ID,
    LaneEstimate,
    PartitionPlan,
    Workload,
    check_gate,
    count_files_in_scope,
    emit,
    estimate,
    estimate_lane,
    propose_partitions,
)


# ──────────────────────────────────────────────────────────────────────
# ADR-14 constants
# ──────────────────────────────────────────────────────────────────────


class TestADR14Defaults:
    def test_default_threshold_is_45_minutes(self) -> None:
        assert GATE_THRESHOLD_SEC_DEFAULT == 45 * 60 == 2700

    def test_schema_id(self) -> None:
        assert SCHEMA_ID == "fix-workload-v1"


# ──────────────────────────────────────────────────────────────────────
# estimate_lane
# ──────────────────────────────────────────────────────────────────────


class TestEstimateLane:
    def test_happy_path_formula(self) -> None:
        # QD1: probes=3, avg=1.5, standard multiplier=1.0
        # 10 files → 10 * 3 * 1.5 * 1.0 = 45.0s
        lane = estimate_lane("QD1", 10, "standard")
        assert lane.dim == "QD1"
        assert lane.probes_count == 3
        assert lane.files_covered == 10
        assert lane.estimated_sec == pytest.approx(45.0)

    def test_profile_multiplier_applied(self) -> None:
        lane_std = estimate_lane("QD5", 20, "standard")
        lane_deep = estimate_lane("QD5", 20, "deep")
        # deep multiplier = 1.5 * standard
        assert lane_deep.estimated_sec == pytest.approx(lane_std.estimated_sec * 1.5)

    def test_zero_files_zero_sec(self) -> None:
        lane = estimate_lane("QD1", 0, "standard")
        assert lane.estimated_sec == 0.0

    def test_invalid_dim_raises(self) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            estimate_lane("QD99", 10, "standard")

    def test_invalid_profile_raises(self) -> None:
        with pytest.raises(ValueError, match="profile"):
            estimate_lane("QD1", 10, "turbo")

    def test_negative_file_count_raises(self) -> None:
        with pytest.raises(ValueError, match=">= 0"):
            estimate_lane("QD1", -1, "standard")


# ──────────────────────────────────────────────────────────────────────
# check_gate
# ──────────────────────────────────────────────────────────────────────


class TestCheckGate:
    def test_below_threshold_false(self) -> None:
        assert check_gate(100.0, 2700) is False

    def test_at_threshold_false(self) -> None:
        """Strict >: equal → KHÔNG trigger."""
        assert check_gate(2700.0, 2700) is False

    def test_above_threshold_true(self) -> None:
        assert check_gate(2701.0, 2700) is True


# ──────────────────────────────────────────────────────────────────────
# Constants sanity
# ──────────────────────────────────────────────────────────────────────


class TestHeuristicTables:
    def test_all_11_dims_covered(self) -> None:
        dims = {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}
        assert set(PROBES_PER_DIM.keys()) == dims
        assert set(AVG_TIME_PER_FILE_SEC.keys()) == dims

    def test_profiles_cover_4_modes(self) -> None:
        assert set(PROFILE_MULTIPLIER.keys()) == {
            "quick",
            "standard",
            "deep",
            "exhaustive",
        }
        assert PROFILE_MULTIPLIER["quick"] < PROFILE_MULTIPLIER["standard"]
        assert PROFILE_MULTIPLIER["deep"] > PROFILE_MULTIPLIER["standard"]


# ──────────────────────────────────────────────────────────────────────
# estimate (full pipeline) + emit (schema-conform)
# ──────────────────────────────────────────────────────────────────────


class TestEstimateAndEmit:
    def test_estimate_returns_workload_with_all_lanes(self, tmp_path: Path) -> None:
        session_dir = tmp_path / "session"
        session_dir.mkdir()
        wl = estimate(
            session_dir=session_dir,
            profile="standard",
            scope={"type": "all"},
            selected_dims=["QD1", "QD2", "QD5"],
        )
        assert isinstance(wl, Workload)
        assert len(wl.lanes) == 3
        assert {l.dim for l in wl.lanes} == {"QD1", "QD2", "QD5"}
        assert wl.profile == "standard"
        assert wl.gate_threshold_sec == GATE_THRESHOLD_SEC_DEFAULT

    def test_adr22_rule1_estimator_does_not_drop_dims(self, tmp_path: Path) -> None:
        """ADR-22 rule 1: estimator phải giữ nguyên selected_dims user đưa vào."""
        session_dir = tmp_path / "session"
        session_dir.mkdir()
        # User chọn ít hơn safety floor — estimator không "sửa giúp"
        wl = estimate(
            session_dir=session_dir,
            profile="quick",
            scope={"type": "all"},
            selected_dims=["QD7"],  # chỉ 1 dim
        )
        assert [l.dim for l in wl.lanes] == ["QD7"]
        assert wl.selected_dims == ["QD7"]

    def test_estimate_empty_selected_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="không được rỗng"):
            estimate(
                session_dir=tmp_path,
                profile="standard",
                scope={"type": "all"},
                selected_dims=[],
            )

    def test_estimate_invalid_profile_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="profile"):
            estimate(
                session_dir=tmp_path,
                profile="nosuch",
                scope={"type": "all"},
                selected_dims=["QD1"],
            )

    def test_emit_writes_schema_conform_json(self, tmp_path: Path) -> None:
        wl = Workload(
            workload_id="WL-20260420-001",
            estimated_at="2026-04-20T00:00:00+00:00",
            profile="standard",
            scope={"type": "all"},
            file_count=10,
            selected_dims=["QD1"],
            lanes=[LaneEstimate(dim="QD1", probes_count=3, files_covered=10, estimated_sec=45.0)],
            total_estimated_sec=45.0,
            gate_threshold_sec=2700,
            gate_triggered=False,
            partition_plans=[],
        )
        out_path = tmp_path / "workloads" / "WL-20260420-001" / "fix-workload.json"
        emit(wl, out_path)

        assert out_path.exists()
        data = json.loads(out_path.read_text(encoding="utf-8"))
        # Schema-conform top-level keys
        for k in (
            "$schema",
            "workload_id",
            "profile",
            "scope",
            "file_count",
            "selected_dims",
            "lanes",
            "total_estimated_sec",
            "gate_threshold_sec",
            "gate_triggered",
            "partition_plans",
        ):
            assert k in data, f"Thiếu field {k}"
        assert data["$schema"] == SCHEMA_ID


# ──────────────────────────────────────────────────────────────────────
# propose_partitions
# ──────────────────────────────────────────────────────────────────────


class TestProposePartitions:
    def test_returns_two_plans(self, tmp_path: Path) -> None:
        wl = Workload(
            workload_id="WL-20260420-001",
            estimated_at="2026-04-20T00:00:00+00:00",
            profile="standard",
            scope={"type": "all"},
            file_count=100,
            selected_dims=["QD1", "QD5"],
            lanes=[
                LaneEstimate(dim="QD1", probes_count=3, files_covered=100, estimated_sec=450.0),
                LaneEstimate(dim="QD5", probes_count=3, files_covered=100, estimated_sec=600.0),
            ],
            total_estimated_sec=1050.0,
            gate_threshold_sec=2700,
            gate_triggered=True,
        )
        plans = propose_partitions(wl, tmp_path)
        assert len(plans) == 2
        kinds = {p.kind for p in plans}
        assert kinds == {"by_scope", "by_dim"}

    def test_plan_b_by_dim_has_one_batch_per_dim(self, tmp_path: Path) -> None:
        wl = Workload(
            workload_id="WL-X",
            estimated_at="2026-04-20T00:00:00+00:00",
            profile="deep",
            scope={"type": "all"},
            file_count=50,
            selected_dims=["QD1", "QD2", "QD5"],
            lanes=[
                LaneEstimate(dim="QD1", probes_count=3, files_covered=50, estimated_sec=337.5),
                LaneEstimate(dim="QD2", probes_count=2, files_covered=50, estimated_sec=300.0),
                LaneEstimate(dim="QD5", probes_count=3, files_covered=50, estimated_sec=450.0),
            ],
            total_estimated_sec=1087.5,
            gate_threshold_sec=2700,
            gate_triggered=True,
        )
        plans = propose_partitions(wl, tmp_path)
        by_dim = next(p for p in plans if p.kind == "by_dim")
        assert len(by_dim.batches) == 3
        dims_in_batches = [b["dim"] for b in by_dim.batches]
        assert dims_in_batches == ["QD1", "QD2", "QD5"]


# ──────────────────────────────────────────────────────────────────────
# count_files_in_scope
# ──────────────────────────────────────────────────────────────────────


class TestCountFilesInScope:
    def test_all_scope_returns_int(self, tmp_path: Path) -> None:
        # Không có project root thật — hàm vẫn không raise; trả số không âm
        result = count_files_in_scope(tmp_path, {"type": "all"})
        assert isinstance(result, int)
        assert result >= 0
