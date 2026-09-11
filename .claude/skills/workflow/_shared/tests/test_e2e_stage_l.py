"""test_e2e_stage_l.py — Multi-workload integration tests cho Stage L.

Test classes:
    1. TestMultiWorkloadDispatch: 7 dims → 3 workloads → sequential dispatch → aggregate
    2. TestISGRecommendedDimensions: ISG recommends dims → resolve → partition → dispatch
    3. TestMultiWorkloadReports: Multi-workload coverage + per-dimension lane reports
    4. TestV2SchemaFields: v2 schema correctness across multi-workload scenarios
    5. TestEdgeCases: Empty signals, single dim, cross-dimension dedup

Tham chiếu:
    - Stage L spec: docs/design/skills/wf-fix-bugs/prompts/stage-L-prompt.md
    - ADR-14: ISG recommendation → workload sizing
    - ADR-15: Partition Planner — Plan A vs Plan B
    - ADR-19: QD3 never cached
    - CORE-007: Cross-skill output path contract
    - CORE-031: Template Usage Rule
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from dimension_registry import get_cache_policy
from isg.isg_recommender import DEFAULT_PROFILE_DIMS, recommend_dimensions
from lane_dispatch import dispatch_lanes
from partition_planner import (
    EST_MINUTES_PER_PROBE,
    PROBES_PER_DIM,
    partition_dimensions,
)
from report_generator import generate_coverage_report, generate_lane_report
from signal_aggregator import aggregate_lane_signals


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    # test file is at: _shared/tests/ → need 3 parents to reach workflow/
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def shared_root() -> Path:
    return Path(__file__).resolve().parent.parent


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


@pytest.fixture
def all_eight_dims() -> list[str]:
    return ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"]


# ──────────────────────────────────────────────────────────────────────
# L1: TestMultiWorkloadDispatch
# ──────────────────────────────────────────────────────────────────────


class TestMultiWorkloadDispatch:
    """7 dims → 3 workloads → sequential dispatch → aggregate all."""

    def test_eight_dims_three_workloads_dispatch(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
        all_eight_dims: list[str],
    ) -> None:
        all_dims = all_eight_dims

        # Step 1: Partition 7 dims into workloads (max=3)
        workloads = partition_dimensions(all_dims, max_workload_size=3)
        assert len(workloads) >= 3, f"Expected >=3 workloads, got {len(workloads)}"

        # All dimensions covered
        covered = [d for w in workloads for d in w.dimensions]
        assert set(covered) == set(all_dims)

        # Step 2: Dispatch each workload separately (sequential)
        for wl in workloads:
            dispatch_lanes(
                session_dir=tmp_session_dir,
                dimensions=wl.dimensions,
                profile="exhaustive",
                workflow_root=workflow_root,
                use_cache=False,
                max_parallel=1,
            )

        # Step 3: Aggregate using full dims list
        registry_path, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=all_dims,
        )

        # Step 4: Verify stats
        assert stats.dimensions_run == all_dims
        assert stats.total_signals >= 0
        assert stats.coverage_rate_pct >= 0.0
        assert isinstance(stats.by_dimension, dict)
        for dim in all_dims:
            assert dim in stats.by_dimension

        # L2: Verify directory structure
        for dim in all_dims:
            lane_dir = tmp_session_dir / "lanes" / dim
            signals_file = lane_dir / "signals.json"
            assert lane_dir.is_dir(), f"Missing lane dir: {lane_dir}"
            assert signals_file.exists(), f"Missing signals.json: {signals_file}"

        # L2: Verify issue-registry.json exists
        assert registry_path.exists()

    def test_multi_workload_fixtures(
        self,
        tmp_session_dir: Path,
        all_eight_dims: list[str],
    ) -> None:
        """Generate fix-workload.json from partition output — verify schema (L3)."""
        all_dims = all_eight_dims

        # Partition into workloads
        workloads = partition_dimensions(all_dims, max_workload_size=3)
        assert len(workloads) >= 3

        # Generate fixtures
        for wl in workloads:
            fixture_dir = tmp_session_dir / "workloads" / wl.id
            fixture_dir.mkdir(parents=True, exist_ok=True)
            fixture_path = fixture_dir / "fix-workload.json"

            fixture_data = wl.to_dict()
            fixture_path.write_text(
                json.dumps(fixture_data, indent=2, ensure_ascii=False),
                encoding="utf-8",
            )

        # Verify each fixture
        for wl in workloads:
            fixture_path = tmp_session_dir / "workloads" / wl.id / "fix-workload.json"
            assert fixture_path.exists(), f"Missing fixture: {fixture_path}"

            data = json.loads(fixture_path.read_text(encoding="utf-8"))

            # Schema: id, dimensions, estimated_probes, estimated_minutes
            assert "id" in data, f"Missing 'id' in fixture {wl.id}"
            assert "dimensions" in data, f"Missing 'dimensions' in fixture {wl.id}"
            assert "estimated_probes" in data, f"Missing 'estimated_probes' in fixture {wl.id}"
            assert "estimated_minutes" in data, f"Missing 'estimated_minutes' in fixture {wl.id}"

            # L3: Verify estimated_probes = sum of PROBES_PER_DIM
            expected_probes = sum(PROBES_PER_DIM.get(d, 0) for d in wl.dimensions)
            assert data["estimated_probes"] == expected_probes, (
                f"Workload {wl.id}: estimated_probes={data['estimated_probes']}, "
                f"expected={expected_probes}"
            )

            # L3: Verify estimated_minutes = estimated_probes * EST_MINUTES_PER_PROBE (rounded)
            expected_minutes = round(expected_probes * EST_MINUTES_PER_PROBE, 1)
            assert data["estimated_minutes"] == expected_minutes, (
                f"Workload {wl.id}: estimated_minutes={data['estimated_minutes']}, "
                f"expected={expected_minutes}"
            )

            # Verify fixture dimensions match workload
            assert data["dimensions"] == wl.dimensions

            # Verify ID format
            assert data["id"] == wl.id
            assert data["id"].startswith("W")


# ──────────────────────────────────────────────────────────────────────
# L1: TestISGRecommendedDimensions
# ──────────────────────────────────────────────────────────────────────


class TestISGRecommendedDimensions:
    """ISG recommends dims → resolve → partition → dispatch."""

    def test_isg_recommended_then_dispatch(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """ISG recommends dims → take top-N → partition → dispatch → aggregate."""
        # ISG ranking for auth-heavy project
        ranked = recommend_dimensions(
            file_paths=[
                "src/auth/login.service.ts",
                "src/auth/jwt.guard.ts",
                "src/auth/password-hash.util.ts",
            ],
            interface_type="web",
            domain=None,
        )

        # v9.1.0: 11 dims (QD1-QD11)
        assert len(ranked) == 11, f"Expected 11 dims, got {len(ranked)}"

        # Take top 3 (standard profile equivalent)
        top_dims = [dim for dim, _ in ranked[:3]]
        assert len(top_dims) == 3

        # Partition those dims
        workloads = partition_dimensions(top_dims)
        assert len(workloads) >= 1

        # Dispatch
        all_dispatched_dims = [d for w in workloads for d in w.dimensions]
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=all_dispatched_dims,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Aggregate
        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=all_dispatched_dims,
        )

        # Verify stats populated
        assert stats.dimensions_run == all_dispatched_dims
        assert stats.total_signals >= 0
        assert stats.coverage_rate_pct >= 0.0

    def test_isg_vs_default_coverage(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """Compare ISG-selected vs default-selected dims — both dispatch+aggregate OK."""
        # Default standard dims
        default_dims = DEFAULT_PROFILE_DIMS["standard"]
        assert set(default_dims) == {"QD1", "QD2", "QD5", "QD9", "QD10"}

        # ISG for auth-heavy project (QD3 = security gets boosted)
        ranked = recommend_dimensions(
            file_paths=["src/auth/login.ts"],
            interface_type="web",
            domain=None,
        )
        isg_dims = [dim for dim, _ in ranked[:3]]

        # Both should be valid subsets of full dimension set
        assert set(default_dims).issubset({"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"})
        assert set(isg_dims).issubset({"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"})

        # Dispatch default dims
        dispatch_lanes(
            session_dir=tmp_session_dir / "default",
            dimensions=default_dims,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        _, default_stats = aggregate_lane_signals(
            session_dir=tmp_session_dir / "default",
            dimensions=default_dims,
        )

        # Dispatch ISG dims
        (tmp_session_dir / "isg").mkdir(parents=True, exist_ok=True)
        dispatch_lanes(
            session_dir=tmp_session_dir / "isg",
            dimensions=isg_dims,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        _, isg_stats = aggregate_lane_signals(
            session_dir=tmp_session_dir / "isg",
            dimensions=isg_dims,
        )

        # Both should have populated stats
        assert default_stats.dimensions_run == default_dims
        assert isg_stats.dimensions_run == isg_dims
        assert default_stats.total_signals >= 0
        assert isg_stats.total_signals >= 0


# ──────────────────────────────────────────────────────────────────────
# L1: TestMultiWorkloadReports
# ──────────────────────────────────────────────────────────────────────


class TestMultiWorkloadReports:
    """Multi-workload coverage report + per-dimension lane reports."""

    def test_multi_workload_coverage_report(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
        shared_root: Path,
        all_eight_dims: list[str],
    ) -> None:
        """3 workloads → aggregate → coverage report populated from real stats."""
        all_dims = all_eight_dims

        # Partition + dispatch + aggregate
        workloads = partition_dimensions(all_dims, max_workload_size=3)
        for wl in workloads:
            dispatch_lanes(
                session_dir=tmp_session_dir,
                dimensions=wl.dimensions,
                profile="exhaustive",
                workflow_root=workflow_root,
                use_cache=False,
                max_parallel=1,
            )

        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=all_dims,
        )

        # Generate coverage report using real stats
        coverage_template = shared_root / "templates" / "coverage-report.md"
        coverage_output = tmp_session_dir / "coverage-report.md"

        generate_coverage_report(
            template_path=coverage_template,
            output_path=coverage_output,
            profile="exhaustive",
            dimensions_list=", ".join(stats.dimensions_run),
            skipped_dimensions="",
            session_dir=str(tmp_session_dir),
            dimension_rows="",
            total_signals=stats.total_signals,
            total_issues=stats.total_issues,
            dimensions_with_issues=len(stats.dimensions_with_issues),
            dimensions_run=len(stats.dimensions_run),
            coverage_pct=stats.coverage_rate_pct,
            severity_rows="",
            recommendations="Review issues across all dimensions",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T11:00:00Z",
        )

        assert coverage_output.exists()
        content = coverage_output.read_text(encoding="utf-8")

        # No unresolved placeholders
        assert "{{" not in content, "Report contains unresolved placeholders"

        # Stats values appear in report
        assert str(stats.total_signals) in content
        assert str(stats.total_issues) in content

    def test_per_dimension_lane_reports(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
        shared_root: Path,
        all_eight_dims: list[str],
    ) -> None:
        """Each dimension gets its own lane report at $SESSION_DIR/lanes/QD*/lane-report.md."""
        all_dims = all_eight_dims

        # Dispatch all
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=all_dims,
            profile="exhaustive",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Aggregate to get stats
        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=all_dims,
        )

        lane_template = shared_root / "templates" / "lane-report.md"
        dim_names = {
            "QD1": "Functional Correctness",
            "QD2": "Business Correctness",
            "QD3": "Security & Privacy",
            "QD4": "Performance & Efficiency",
            "QD5": "Accessibility & UX",
            "QD6": "Data Integrity & Resilience",
            "QD7": "Compatibility & Portability",
            "QD8": "Observability & Reliability",
            "QD9": "Runtime Health",
            "QD10": "Cross-Module Integration",
            "QD11": "Business Completeness",
        }

        for dim in all_dims:
            lane_output = tmp_session_dir / "lanes" / dim / "lane-report.md"
            generate_lane_report(
                template_path=lane_template,
                output_path=lane_output,
                dimension_id=dim,
                dimension_name=dim_names[dim],
                profile="exhaustive",
                session_dir=str(tmp_session_dir),
                probes_total=stats.by_dimension.get(dim, 0),
                probes_available=PROBES_PER_DIM.get(dim, 0),
                signals_count=stats.by_dimension.get(dim, 0),
                issues_count=stats.by_dimension.get(dim, 0),
                probe_rows="",
                issues_detail="See issue-registry.json",
                recommendations="Review findings",
                started_at="2026-04-21T10:00:00Z",
                completed_at="2026-04-21T10:05:00Z",
            )

        # Verify each report exists and has correct dim populated
        for dim in all_dims:
            lane_report = tmp_session_dir / "lanes" / dim / "lane-report.md"
            assert lane_report.exists(), f"Missing lane report: {lane_report}"

            content = lane_report.read_text(encoding="utf-8")
            # Dimension ID populated
            assert dim in content, f"Dimension {dim} not in report"
            # No unresolved placeholders
            assert "{{" not in content, f"Unresolved placeholders in {dim} report"


# ──────────────────────────────────────────────────────────────────────
# L1: TestV2SchemaFields
# ──────────────────────────────────────────────────────────────────────


class TestV2SchemaFields:
    """v2 schema field correctness across multi-workload scenarios."""

    def test_v2_dimensions_run_matches_input(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
        all_eight_dims: list[str],
    ) -> None:
        """After aggregation, dimensions_run matches input dims exactly."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=all_eight_dims,
            profile="exhaustive",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=all_eight_dims,
        )

        assert stats.dimensions_run == all_eight_dims
        assert len(stats.dimensions_run) == 11

    def test_v2_coverage_calculation(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """Coverage rate calculated correctly based on dimensions with/without issues."""
        dims = ["QD1", "QD2", "QD3"]

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=dims,
            profile="deep",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=dims,
        )

        # Formula: len(dimensions_with_issues) / len(dimensions_run) * 100
        expected_rate = round(
            len(stats.dimensions_with_issues) / len(dims) * 100, 1
        )
        assert stats.coverage_rate_pct == expected_rate

        # All dims with 0 signals → coverage 0.0
        if stats.total_signals == 0:
            assert stats.coverage_rate_pct == 0.0

    def test_v2_dedup_stats(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """Dedup stats populated correctly: ingested = total signals, deduplicated = diff."""
        dims = ["QD1", "QD5"]

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=dims,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=dims,
        )

        # dedup_ingested == total_signals (all signals ingested into bus)
        assert stats.dedup_ingested == stats.total_signals

        # dedup_deduplicated == total_signals - total_issues (signals removed by dedup)
        assert stats.dedup_deduplicated == stats.total_signals - stats.total_issues

        # dedup_deduplicated >= 0 (never negative)
        assert stats.dedup_deduplicated >= 0


# ──────────────────────────────────────────────────────────────────────
# L1: TestEdgeCases
# ──────────────────────────────────────────────────────────────────────


class TestEdgeCases:
    """Edge cases: empty signals, single dim, cross-dimension dedup."""

    def test_empty_signals_in_some_dims(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """Some dims have 0 signals — coverage reflects correctly."""
        # Dispatch 3 dims, but only create signals.json for 2 of them
        # (dispatch_lanes creates empty signals.json for all, but we verify
        # that dimensions_without_issues correctly tracks dims with 0 signals)
        dims = ["QD1", "QD2", "QD5"]

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=dims,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Manually clear signals for QD2 to simulate 0 signals
        qd2_signals = tmp_session_dir / "lanes" / "QD2" / "signals.json"
        if qd2_signals.exists():
            empty_data = {
                "$schema": "lane-signals-v1",
                "dimension": "QD2",
                "profile": "standard",
                "generated_at": "2026-04-21T10:00:00Z",
                "probes_executed": 0,
                "cache_policy": {"cache_allowed": True, "used_cache": False},
                "signals": [],
            }
            qd2_signals.write_text(
                json.dumps(empty_data, indent=2), encoding="utf-8"
            )

        _, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=dims,
        )

        # QD2 should be in dimensions_without_issues (0 signals)
        assert "QD2" in stats.dimensions_without_issues, (
            f"QD2 should be in without_issues, got: {stats.dimensions_without_issues}"
        )

        # Coverage < 100% since at least 1 dim has no issues
        if len(stats.dimensions_without_issues) > 0:
            assert stats.coverage_rate_pct < 100.0

    def test_single_dim_workload(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
    ) -> None:
        """1 dim → 1 workload → dispatch → aggregate — minimum viable workload."""
        dims = ["QD1"]

        # Partition: single dim → single workload
        workloads = partition_dimensions(dims)
        assert len(workloads) == 1
        assert workloads[0].dimensions == ["QD1"]
        assert workloads[0].id == "W01"
        assert workloads[0].estimated_probes == PROBES_PER_DIM["QD1"]

        # Dispatch
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=dims,
            profile="quick",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Aggregate
        registry_path, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=dims,
        )

        # Verify stats populated correctly
        assert stats.dimensions_run == ["QD1"]
        assert stats.total_signals >= 0
        assert stats.total_issues >= 0
        assert stats.by_dimension.get("QD1", 0) >= 0
        assert registry_path.exists()

        # Coverage is either 0.0 (no signals) or 100.0 (signals found)
        if stats.total_signals == 0:
            assert stats.coverage_rate_pct == 0.0
        else:
            assert stats.coverage_rate_pct == 100.0


# ──────────────────────────────────────────────────────────────────────
# ADR-19: QD3 never cached
# ──────────────────────────────────────────────────────────────────────


class TestADR19QD3NeverCached:
    """Verify QD3 cache policy is enforced in dimension registry."""

    def test_qd3_cache_not_allowed(self) -> None:
        """QD3 must never be cached (ADR-19 / ADR-22 rule 6)."""
        assert get_cache_policy("QD3") is False

    def test_other_dims_cache_allowed(self) -> None:
        """Non-QD3 dimensions should have cache_allowed=True (trừ QD9/QD11: runtime probes + LLM)."""
        for dim in ["QD1", "QD2", "QD4", "QD5", "QD6", "QD7", "QD8", "QD10"]:
            assert get_cache_policy(dim) is True, f"{dim} should allow caching"
        # QD9 (runtime health) & QD11 (LLM) — intentionally not cached
        assert get_cache_policy("QD9") is False, "QD9 runtime probes should not be cached"
        assert get_cache_policy("QD11") is False, "QD11 LLM probes should not be cached"
