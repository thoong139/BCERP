"""test_e2e_orchestrator.py — Integration tests cho Stage E (Orchestrator Integration + Lane Dispatch).

Vai trò:
    Kiểm thử E2E cho profile_resolver, dimension_registry, lane_dispatch,
    signal_aggregator, workload_estimator v6, và ISG recommender v6.

Tham chiếu:
    - Stage E spec: docs/design/skills/wf-fix-bugs/prompts/stage-E-prompt.md §E8
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from dimension_registry import (
    DIMENSION_REGISTRY,
    get_all_dimensions,
    get_cache_policy,
    get_lane_path,
    validate_lane_exists,
)
from profile_resolver import resolve_probes


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    """Root của workflow skills — chứa wf-fix-* lane directories."""
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def tmp_dimension_json(tmp_path: Path) -> Path:
    """Tạo dimension.json mẫu cho test."""
    dim_data: dict[str, Any] = {
        "$schema": "dimension-v1",
        "dimension_id": "QD3",
        "probes": [
            {"id": "P-QD3-probe-a", "name": "Probe A"},
            {"id": "P-QD3-probe-b", "name": "Probe B"},
            {"id": "P-QD3-probe-c", "name": "Probe C"},
        ],
        "exit_criteria": {
            "quick": {"probes_required": ["P-QD3-probe-a", "P-QD3-probe-b"]},
            "standard": {"probes_required": ["P-QD3-probe-a", "P-QD3-probe-b", "P-QD3-probe-c"]},
            "exhaustive": {"probes_required": "ALL"},
        },
    }
    path = tmp_path / "dimension.json"
    path.write_text(json.dumps(dim_data, ensure_ascii=False), encoding="utf-8")
    return path


# ──────────────────────────────────────────────────────────────────────
# 1. TestProfileResolver
# ──────────────────────────────────────────────────────────────────────


class TestProfileResolver:
    """Profile resolver — resolve dimension.json → probe IDs."""

    def test_quick_profile_returns_subset(self, tmp_dimension_json: Path) -> None:
        probes = resolve_probes(tmp_dimension_json, "quick")
        assert probes == ["P-QD3-probe-a", "P-QD3-probe-b"]

    def test_standard_returns_list(self, tmp_dimension_json: Path) -> None:
        probes = resolve_probes(tmp_dimension_json, "standard")
        assert len(probes) == 3
        assert "P-QD3-probe-a" in probes

    def test_exhaustive_returns_all(self, tmp_dimension_json: Path) -> None:
        probes = resolve_probes(tmp_dimension_json, "exhaustive")
        assert len(probes) == 3  # ALL → collect all probes[].id

    def test_invalid_profile_raises(self, tmp_dimension_json: Path) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            resolve_probes(tmp_dimension_json, "invalid")

    def test_missing_file_raises(self, tmp_path: Path) -> None:
        missing = tmp_path / "nonexistent.json"
        with pytest.raises(FileNotFoundError):
            resolve_probes(missing, "quick")

    def test_real_qd3_dimension(self, workflow_root: Path) -> None:
        """Test với QD3 dimension.json thực tế."""
        dim_json = workflow_root / "wf-fix-security" / "dimension.json"
        if not dim_json.exists():
            pytest.skip("wf-fix-security/dimension.json not found")
        probes = resolve_probes(dim_json, "quick")
        assert len(probes) == 3
        assert "P-QD3-dependency-vuln-scan" in probes

    def test_real_qd3_exhaustive(self, workflow_root: Path) -> None:
        dim_json = workflow_root / "wf-fix-security" / "dimension.json"
        if not dim_json.exists():
            pytest.skip("wf-fix-security/dimension.json not found")
        probes = resolve_probes(dim_json, "exhaustive")
        assert len(probes) == 8  # QD3 has 8 probes (7 + 1 LLM)


# ──────────────────────────────────────────────────────────────────────
# 2. TestDimensionRegistry
# ──────────────────────────────────────────────────────────────────────


class TestDimensionRegistry:
    """Dimension registry — lookup dimension config."""

    def test_get_all_dimensions(self) -> None:
        # v9.1.0: 11 dimensions (sorted alphabetically — QD10, QD11 after QD1)
        dims = get_all_dimensions()
        assert dims == ["QD1", "QD10", "QD11", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9"]

    def test_get_lane_path_qd3(self, workflow_root: Path) -> None:
        path = get_lane_path("QD3", workflow_root)
        assert path.name == "wf-fix-security"

    def test_get_lane_path_qd1(self, workflow_root: Path) -> None:
        path = get_lane_path("QD1", workflow_root)
        assert path.name == "wf-fix-functional"

    def test_cache_policy_qd3_false(self) -> None:
        assert get_cache_policy("QD3") is False  # ADR-22 Rule 6

    def test_cache_policy_qd4_true(self) -> None:
        assert get_cache_policy("QD4") is True

    def test_cache_policy_all_others_true(self) -> None:
        for dim in ["QD1", "QD2", "QD4", "QD5", "QD6", "QD7"]:
            assert get_cache_policy(dim) is True

    def test_validate_lane_exists_qd1(self, workflow_root: Path) -> None:
        assert validate_lane_exists("QD1", workflow_root) is True

    def test_validate_lane_invalid_dim(self) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            get_lane_path("QD99", Path("/tmp"))

    def test_registry_has_10_entries(self) -> None:
        # v9.1.0: thêm QD11 (wf-fix-business-completeness)
        assert len(DIMENSION_REGISTRY) == 11


# ──────────────────────────────────────────────────────────────────────
# 3. TestWorkloadEstimatorV6
# ──────────────────────────────────────────────────────────────────────


class TestWorkloadEstimatorV6:
    """Workload estimator — dimension weights cho v6 engine."""

    def test_estimate_lane_with_weights(self) -> None:
        from workload_estimator.estimator import estimate_lane

        # QD3 with weight 1.5 should be higher than without
        no_weight = estimate_lane("QD3", 100, "standard")
        with_weight = estimate_lane("QD3", 100, "standard", use_weights=True)
        assert with_weight.estimated_sec > no_weight.estimated_sec

    def test_estimate_lane_qd1_weight_is_1(self) -> None:
        from workload_estimator.estimator import estimate_lane

        no_weight = estimate_lane("QD1", 100, "standard")
        with_weight = estimate_lane("QD1", 100, "standard", use_weights=True)
        assert abs(no_weight.estimated_sec - with_weight.estimated_sec) < 0.01

    def test_dimension_weights_exist(self) -> None:
        from workload_estimator.estimator import DIMENSION_WEIGHTS

        assert len(DIMENSION_WEIGHTS) == 11  # v9.1.0: QD1-QD11
        assert DIMENSION_WEIGHTS["QD3"] == 1.5  # Security — higher cost

    def test_estimate_empty_raises(self) -> None:
        from workload_estimator.estimator import estimate

        with pytest.raises(ValueError, match="không được rỗng"):
            estimate(
                session_dir=Path("/tmp"),
                profile="standard",
                scope={"type": "all"},
                selected_dims=[],
            )


# ──────────────────────────────────────────────────────────────────────
# 4. TestLaneDispatch
# ──────────────────────────────────────────────────────────────────────


class TestLaneDispatch:
    """Lane dispatch — parallel execution."""

    def test_dispatch_sequential_two_lanes(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        from lane_dispatch import dispatch_lanes

        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        assert "QD1" in result
        assert "QD3" in result

    def test_dispatch_qd3_signals_has_no_cache_flag(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        from lane_dispatch import dispatch_lanes

        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        signals_path = result["QD3"]
        data = json.loads(signals_path.read_text(encoding="utf-8"))
        assert data["cache_policy"] == "never"  # ADR-22 Rule 6

    def test_dispatch_qd1_cache_allowed(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        from lane_dispatch import dispatch_lanes

        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        signals_path = result["QD1"]
        data = json.loads(signals_path.read_text(encoding="utf-8"))
        assert data["cache_policy"] == "allowed"

    def test_dispatch_empty_dims_raises(self, tmp_session_dir: Path, workflow_root: Path) -> None:
        from lane_dispatch import dispatch_lanes

        with pytest.raises(ValueError, match="không được rỗng"):
            dispatch_lanes(
                session_dir=tmp_session_dir,
                dimensions=[],
                profile="quick",
                workflow_root=workflow_root,
            )

    def test_dispatch_creates_lanes_dir(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        from lane_dispatch import dispatch_lanes

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        lanes_dir = tmp_session_dir / "lanes" / "QD1"
        assert lanes_dir.is_dir()


# ──────────────────────────────────────────────────────────────────────
# 5. TestSignalAggregation
# ──────────────────────────────────────────────────────────────────────


class TestSignalAggregation:
    """Signal aggregation — lane signals → issue-registry.json."""

    def _create_lane_signals(
        self, session_dir: Path, dim: str, signals: list[dict[str, Any]]
    ) -> Path:
        """Helper: tạo signals.json cho 1 lane."""
        lane_dir = session_dir / "lanes" / dim
        lane_dir.mkdir(parents=True, exist_ok=True)
        signals_path = lane_dir / "signals.json"
        data = {
            "$schema": "lane-signals-v1",
            "dimension": dim,
            "signals": signals,
        }
        signals_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return signals_path

    def test_aggregate_two_lanes(self, tmp_session_dir: Path) -> None:
        from signal_aggregator import aggregate_lane_signals

        self._create_lane_signals(tmp_session_dir, "QD1", [])
        self._create_lane_signals(tmp_session_dir, "QD3", [])

        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD1", "QD3"]
        )
        assert registry_path.exists()
        assert stats.total_signals == 0

    def test_aggregate_with_signals(self, tmp_session_dir: Path) -> None:
        from signal_aggregator import aggregate_lane_signals

        signals = [
            {
                "probe_id": "P-QD3-test-probe",
                "probe_version": "1.0.0",
                "emitted_at": "2026-04-21T10:00:00+00:00",
                "lane": "wf-fix-security",
                "dimension_id": "QD3",
                "target": {
                    "kind": "code",
                    "file_path": "src/auth.ts",
                    "line_range": [1, 10],
                    "symbol": "login",
                },
                "description": "Security issue detected in auth module",
                "evidence": {"code_snippet": "// TODO: fix hardcoded secret key"},
            }
        ]
        self._create_lane_signals(tmp_session_dir, "QD3", signals)

        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD3"]
        )
        assert stats.total_signals == 1
        assert stats.total_issues == 1

    def test_aggregate_empty_signals_valid(self, tmp_session_dir: Path) -> None:
        from signal_aggregator import aggregate_lane_signals

        self._create_lane_signals(tmp_session_dir, "QD1", [])

        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD1"]
        )
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data["issues"] == []

    def test_aggregate_missing_lane_skipped(self, tmp_session_dir: Path) -> None:
        from signal_aggregator import aggregate_lane_signals

        # Không tạo lane signals cho QD5
        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD5"]
        )
        assert len(stats.errors) > 0
        assert "không tồn tại" in stats.errors[0]

    def test_aggregation_stats_accuracy(self, tmp_session_dir: Path) -> None:
        from signal_aggregator import aggregate_lane_signals

        sig1 = [
            {
                "probe_id": "P-QD1-test-a",
                "probe_version": "1.0.0",
                "emitted_at": "2026-04-21T10:00:00+00:00",
                "lane": "wf-fix-functional",
                "dimension_id": "QD1",
                "target": {"kind": "code", "file_path": "a.ts", "line_range": [1, 5], "symbol": "fn1"},
                "description": "Functional bug in module A with enough text",
                "evidence": {"code_snippet": "// bug here in functional code"},
            }
        ]
        sig2 = [
            {
                "probe_id": "P-QD3-test-a",
                "probe_version": "1.0.0",
                "emitted_at": "2026-04-21T10:00:00+00:00",
                "lane": "wf-fix-security",
                "dimension_id": "QD3",
                "target": {"kind": "code", "file_path": "b.ts", "line_range": [1, 5], "symbol": "fn2"},
                "description": "Security issue found during scan enough text",
                "evidence": {"code_snippet": "// hardcoded secret in source code"},
            }
        ]

        self._create_lane_signals(tmp_session_dir, "QD1", sig1)
        self._create_lane_signals(tmp_session_dir, "QD3", sig2)

        _, stats = aggregate_lane_signals(tmp_session_dir, ["QD1", "QD3"])
        assert stats.total_signals == 2
        assert stats.by_dimension.get("QD1") == 1
        assert stats.by_dimension.get("QD3") == 1


# ──────────────────────────────────────────────────────────────────────
# 6. TestOrchestratorV6Flow
# ──────────────────────────────────────────────────────────────────────


class TestOrchestratorV6Flow:
    """End-to-end v6 orchestrator flow tests."""

    def test_full_dispatch_aggregate_flow(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        """Dispatch → aggregate full flow."""
        from lane_dispatch import dispatch_lanes
        from signal_aggregator import aggregate_lane_signals

        # Dispatch 2 lanes
        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        assert len(result) == 2

        # Aggregate
        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD1", "QD3"]
        )
        assert registry_path.exists()
        assert stats.errors == []  # No errors since lanes were created

    def test_single_dimension_dispatch(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        """--dims=QD3 only → single dimension dispatch."""
        from lane_dispatch import dispatch_lanes

        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        assert "QD3" in result
        assert result["QD3"].exists()

    def test_qd3_never_cached_in_signals(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        """ADR-22 Rule 6: QD3 signals must have cache_policy=never."""
        from lane_dispatch import dispatch_lanes

        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,  # Even with use_cache=True
            max_parallel=1,
        )
        data = json.loads(result["QD3"].read_text(encoding="utf-8"))
        assert data["cache_policy"] == "never"
