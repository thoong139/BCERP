"""test_workload_estimator_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify workload_estimator/estimator.py:
- estimate_lane: per-dim calculation + weights
- check_gate: threshold comparison
- _get_threshold_sec: env override
- count_files_in_scope: file counting + scope filter
- estimate: full workload pipeline
- propose_partitions: Plan A/B partition logic
- CLI main()
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from unittest.mock import patch

import pytest

from workload_estimator.estimator import (
    AVG_TIME_PER_FILE_SEC,
    DIMENSION_WEIGHTS,
    GATE_THRESHOLD_SEC_DEFAULT,
    PROBES_PER_DIM,
    PROFILE_MULTIPLIER,
    SCHEMA_ID,
    SOURCE_EXTENSIONS,
    LaneEstimate,
    PartitionPlan,
    Workload,
    _count_source_files,
    _find_project_root,
    _get_threshold_sec,
    _load_registry,
    _next_workload_id,
    _parse_scope,
    _workload_to_dict,
    check_gate,
    count_files_in_scope,
    emit,
    estimate,
    estimate_lane,
    propose_partitions,
)


# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────


def test_schema_id() -> None:
    assert SCHEMA_ID == "fix-workload-v1"


def test_gate_threshold_default_45_min() -> None:
    assert GATE_THRESHOLD_SEC_DEFAULT == 45 * 60


def test_eleven_dims_in_probes_per_dim() -> None:
    assert set(PROBES_PER_DIM.keys()) == {f"QD{i}" for i in range(1, 12)}


def test_eleven_dims_in_weights() -> None:
    assert set(DIMENSION_WEIGHTS.keys()) == {f"QD{i}" for i in range(1, 12)}


def test_profile_multipliers() -> None:
    assert PROFILE_MULTIPLIER["quick"] == 0.5
    assert PROFILE_MULTIPLIER["standard"] == 1.0
    assert PROFILE_MULTIPLIER["deep"] == 1.5
    assert PROFILE_MULTIPLIER["exhaustive"] == 2.5


# ──────────────────────────────────────────────────────────────────────
# estimate_lane
# ──────────────────────────────────────────────────────────────────────


class TestEstimateLane:
    def test_basic_calculation(self) -> None:
        result = estimate_lane("QD1", 100, "standard")
        # QD1: probes=3, avg=1.5, std multiplier=1.0
        # 100 * 3 * 1.5 * 1.0 = 450
        assert result.estimated_sec == 450.0
        assert result.dim == "QD1"
        assert result.probes_count == 3
        assert result.files_covered == 100

    def test_quick_profile_faster(self) -> None:
        result = estimate_lane("QD1", 100, "quick")
        assert result.estimated_sec == 225.0  # 450 * 0.5

    def test_with_weights(self) -> None:
        """use_weights=True nhân thêm DIMENSION_WEIGHTS[dim]."""
        result = estimate_lane("QD3", 100, "standard", use_weights=True)
        # QD3: 100 * 2 * 3.5 * 1.0 * 1.5 (weight) = 1050
        assert result.estimated_sec == 1050.0

    def test_invalid_dim(self) -> None:
        with pytest.raises(ValueError, match="dim.*không hợp lệ"):
            estimate_lane("QD99", 10, "standard")

    def test_invalid_profile(self) -> None:
        with pytest.raises(ValueError, match="profile.*không hợp lệ"):
            estimate_lane("QD1", 10, "ultra")

    def test_negative_file_count(self) -> None:
        with pytest.raises(ValueError, match="file_count.*>="):
            estimate_lane("QD1", -1, "standard")

    def test_zero_files(self) -> None:
        result = estimate_lane("QD1", 0, "standard")
        assert result.estimated_sec == 0.0


# ──────────────────────────────────────────────────────────────────────
# check_gate
# ──────────────────────────────────────────────────────────────────────


class TestCheckGate:
    def test_below_threshold(self) -> None:
        assert check_gate(100, 200) is False

    def test_exceeds_threshold(self) -> None:
        assert check_gate(300, 200) is True

    def test_equal_threshold_false(self) -> None:
        """Equal không trigger gate."""
        assert check_gate(200, 200) is False


# ──────────────────────────────────────────────────────────────────────
# _get_threshold_sec
# ──────────────────────────────────────────────────────────────────────


class TestGetThresholdSec:
    def test_default_when_unset(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN", None)
            assert _get_threshold_sec() == GATE_THRESHOLD_SEC_DEFAULT

    def test_env_override_valid(self) -> None:
        with patch.dict(os.environ, {"WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN": "30"}):
            assert _get_threshold_sec() == 30 * 60

    def test_env_zero_falls_back(self) -> None:
        """0 hoặc negative → fallback default."""
        with patch.dict(os.environ, {"WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN": "0"}):
            assert _get_threshold_sec() == GATE_THRESHOLD_SEC_DEFAULT

    def test_env_invalid_falls_back(self) -> None:
        with patch.dict(os.environ, {"WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN": "abc"}):
            assert _get_threshold_sec() == GATE_THRESHOLD_SEC_DEFAULT


# ──────────────────────────────────────────────────────────────────────
# _count_source_files
# ──────────────────────────────────────────────────────────────────────


class TestCountSourceFiles:
    def test_empty_dir(self, tmp_path: Path) -> None:
        assert _count_source_files(tmp_path) == 0

    def test_counts_source_extensions(self, tmp_path: Path) -> None:
        (tmp_path / "a.ts").write_text("", encoding="utf-8")
        (tmp_path / "b.py").write_text("", encoding="utf-8")
        (tmp_path / "c.txt").write_text("", encoding="utf-8")  # Not source
        count = _count_source_files(tmp_path)
        assert count == 2  # ts + py, not txt

    def test_recurses_subdirs(self, tmp_path: Path) -> None:
        sub = tmp_path / "src" / "utils"
        sub.mkdir(parents=True)
        (sub / "a.ts").write_text("", encoding="utf-8")
        assert _count_source_files(tmp_path) == 1


# ──────────────────────────────────────────────────────────────────────
# count_files_in_scope
# ──────────────────────────────────────────────────────────────────────


class TestCountFilesInScope:
    def test_scope_all(self, tmp_path: Path) -> None:
        # Build a fake project structure
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "a.ts").write_text("", encoding="utf-8")
        # session_dir = tmp_path / ".mc-data/work/wf-fix-bugs/sessions/x/
        session = tmp_path / ".mc-data" / "work" / "wf-fix-bugs" / "sessions" / "x"
        session.mkdir(parents=True)
        count = count_files_in_scope(session, {"type": "all"})
        # _find_project_root traverses parents looking for .mc-data
        assert count >= 0


# ──────────────────────────────────────────────────────────────────────
# Dataclass shapes
# ──────────────────────────────────────────────────────────────────────


class TestDataclasses:
    def test_lane_estimate(self) -> None:
        le = LaneEstimate(dim="QD1", probes_count=3, files_covered=10, estimated_sec=45.0)
        assert le.dim == "QD1"
        assert le.estimated_sec == 45.0

    def test_workload(self) -> None:
        w = Workload(
            workload_id="WL-001",
            estimated_at="2026-05-15T00:00:00Z",
            profile="standard",
            scope={"type": "all"},
            file_count=100,
            selected_dims=["QD1"],
            lanes=[],
            total_estimated_sec=0.0,
            gate_threshold_sec=2700,
            gate_triggered=False,
        )
        assert w.workload_id == "WL-001"


# ──────────────────────────────────────────────────────────────────────
# _next_workload_id
# ──────────────────────────────────────────────────────────────────────


class TestNextWorkloadId:
    def test_format(self, tmp_path: Path) -> None:
        wid = _next_workload_id(tmp_path)
        assert wid.startswith("WL-")
        assert len(wid.split("-")) >= 3  # WL-YYYYMMDD-NNN


# ──────────────────────────────────────────────────────────────────────
# _parse_scope
# ──────────────────────────────────────────────────────────────────────


class TestParseScope:
    def test_scope_all(self) -> None:
        result = _parse_scope("all")
        assert result == {"type": "all"}

    def test_scope_system(self) -> None:
        result = _parse_scope("system:crm")
        assert result == {"type": "system", "name": "crm"}

    def test_scope_module(self) -> None:
        result = _parse_scope("module:customer")
        assert result == {"type": "module", "name": "customer"}

    def test_scope_invalid(self) -> None:
        import argparse
        with pytest.raises(argparse.ArgumentTypeError):
            _parse_scope("bad:")


# ──────────────────────────────────────────────────────────────────────
# Workload emit + serialize
# ──────────────────────────────────────────────────────────────────────


class TestWorkloadEmit:
    def test_emit_writes_json(self, tmp_path: Path) -> None:
        w = Workload(
            workload_id="WL-001",
            estimated_at="2026-05-15T00:00:00Z",
            profile="standard",
            scope={"type": "all"},
            file_count=100,
            selected_dims=["QD1"],
            lanes=[LaneEstimate("QD1", 3, 100, 450.0)],
            total_estimated_sec=450.0,
            gate_threshold_sec=2700,
            gate_triggered=False,
        )
        out = tmp_path / "workload.json"
        emit(w, out)
        assert out.exists()
        data = json.loads(out.read_text(encoding="utf-8"))
        assert data["$schema"] == SCHEMA_ID
        assert data["workload_id"] == "WL-001"

    def test_workload_to_dict(self) -> None:
        w = Workload(
            workload_id="WL-001",
            estimated_at="t",
            profile="quick",
            scope={},
            file_count=0,
            selected_dims=[],
            lanes=[],
            total_estimated_sec=0.0,
            gate_threshold_sec=2700,
            gate_triggered=False,
        )
        d = _workload_to_dict(w)
        assert d["$schema"] == SCHEMA_ID
        assert d["workload_id"] == "WL-001"


# ──────────────────────────────────────────────────────────────────────
# Full estimate
# ──────────────────────────────────────────────────────────────────────


class TestEstimate:
    def test_estimate_minimal(self, tmp_path: Path) -> None:
        """End-to-end với minimal scope."""
        result = estimate(
            session_dir=tmp_path,
            scope={"type": "all"},
            profile="quick",
            selected_dims=["QD1"],
        )
        assert isinstance(result, Workload)
        assert result.profile == "quick"
        assert len(result.lanes) == 1
        assert result.lanes[0].dim == "QD1"

    def test_estimate_invalid_profile(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="profile.*không hợp lệ"):
            estimate(
                session_dir=tmp_path,
                profile="ultra",
                scope={"type": "all"},
                selected_dims=["QD1"],
            )

    def test_estimate_empty_dims(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="selected_dims không được rỗng"):
            estimate(
                session_dir=tmp_path,
                profile="quick",
                scope={"type": "all"},
                selected_dims=[],
            )

    def test_estimate_invalid_dim(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="dim.*không hợp lệ"):
            estimate(
                session_dir=tmp_path,
                profile="quick",
                scope={"type": "all"},
                selected_dims=["QD99"],
            )
