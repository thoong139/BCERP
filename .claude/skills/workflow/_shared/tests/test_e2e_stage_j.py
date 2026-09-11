"""test_e2e_stage_j.py — E2E smoke tests cho Stage J.

Test cases:
    1. test_partition_single_workload: 3 dims → 1 workload
    2. test_partition_multi_workload: 7 dims, max=3 → 3 workloads
    3. test_partition_isg_guided: ISG recommends split → follow guidance
    4. test_aggregator_v2_fields: aggregate with dims list → v2 fields populated
    5. test_v6_full_pipeline: profiles.json → resolve → partition → dispatch → aggregate → reports
    6. test_workload_json_schema: fix-workload.json matches expected schema
    7. test_isg_recommender_integration: ISG returns recommendation → partition uses it
    8. test_coverage_report_from_aggregation: coverage-report generated from actual aggregation stats

Tham chiếu:
    - Stage J spec: docs/design/skills/wf-fix-bugs/prompts/stage-J-prompt.md
"""
from __future__ import annotations

from pathlib import Path

import pytest

from lane_dispatch import dispatch_lanes
from partition_planner import partition_dimensions
from profile_resolver import resolve_dimensions
from report_generator import generate_coverage_report, generate_lane_report
from signal_aggregator import aggregate_lane_signals


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent.parent


@pytest.fixture
def shared_root() -> Path:
    return Path(__file__).resolve().parent.parent


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


@pytest.fixture
def profiles_path(shared_root: Path) -> Path:
    return shared_root / "profiles.json"


# ──────────────────────────────────────────────────────────────────────
# J1: partition_dimensions tests
# ──────────────────────────────────────────────────────────────────────


class TestPartitionSingleWorkload:
    """3 dims → 1 workload (fits within max_workload_size)."""

    def test_three_dims_single_workload(self) -> None:
        workloads = partition_dimensions(["QD1", "QD2", "QD5"])
        assert len(workloads) == 1
        assert workloads[0].id == "W01"
        assert workloads[0].dimensions == ["QD1", "QD2", "QD5"]
        assert workloads[0].estimated_probes > 0
        assert workloads[0].estimated_minutes > 0

    def test_eleven_dims_multi_workload(self) -> None:
        workloads = partition_dimensions(
            ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"]
        )
        # max_workload_size default=8 → 11 dims cần 2 workloads
        assert len(workloads) == 2
        all_dims = [d for w in workloads for d in w.dimensions]
        assert set(all_dims) == {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}


class TestPartitionMultiWorkload:
    """11 dims, max=3 → multiple workloads."""

    def test_eleven_dims_max_three(self) -> None:
        workloads = partition_dimensions(
            ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"],
            max_workload_size=3,
        )
        assert len(workloads) >= 4
        # All dimensions covered
        all_dims = [d for w in workloads for d in w.dimensions]
        assert set(all_dims) == {"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"}
        # First workload has core dims
        assert "QD1" in workloads[0].dimensions

    def test_empty_dims_raises(self) -> None:
        with pytest.raises(ValueError, match="rỗng"):
            partition_dimensions([])

    def test_invalid_dim_raises(self) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            partition_dimensions(["QD1", "INVALID"])


class TestPartitionISGGuided:
    """ISG recommends split → follow ISG guidance."""

    def test_isg_guided_split(self) -> None:
        isg_rec = {
            "split": True,
            "groups": [["QD1", "QD2", "QD5"], ["QD3", "QD4"], ["QD6", "QD7"]],
        }
        workloads = partition_dimensions(
            ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"],
            isg_recommendation=isg_rec,
        )
        assert len(workloads) >= 3
        assert workloads[0].dimensions == ["QD1", "QD2", "QD5"]
        assert workloads[1].dimensions == ["QD3", "QD4"]
        assert workloads[2].dimensions == ["QD6", "QD7"]

    def test_isg_no_split_single_workload(self) -> None:
        isg_rec = {"split": False}
        workloads = partition_dimensions(
            ["QD1", "QD2", "QD5"],
            isg_recommendation=isg_rec,
        )
        assert len(workloads) == 1


class TestPartitionCodebaseSizeAware:
    """F6 (Wave 3 v7.4 e2e fix): partition adapts to codebase symbol count.

    Codebase nhỏ (≤5K symbols) → keep default max_workload_size (single workload).
    Codebase lớn (>5K symbols, eg 50K) → halve max_workload_size, force split.
    """

    def test_small_codebase_keeps_default(self) -> None:
        """symbol_count <= 5000 → max_workload_size giữ default=8 → 11 dims → 2 workloads."""
        all_dims_in = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"]
        workloads = partition_dimensions(all_dims_in, symbol_count=4500)
        assert len(workloads) == 2
        all_dims = [d for w in workloads for d in w.dimensions]
        assert set(all_dims) == set(all_dims_in)

    def test_large_codebase_halves_max_size(self) -> None:
        """symbol_count > 5000 (eg 50K) → max_workload_size halved → multi-workload split."""
        all_dims_in = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"]
        workloads = partition_dimensions(all_dims_in, symbol_count=50000)
        # 11 dims, max_size halved → at least 2 workloads
        assert len(workloads) >= 2
        # Tất cả dims vẫn được cover
        all_dims = [d for w in workloads for d in w.dimensions]
        assert set(all_dims) == set(all_dims_in)
        # Mỗi workload không vượt scaled max
        for w in workloads:
            assert len(w.dimensions) <= 4


# ──────────────────────────────────────────────────────────────────────
# J3: Aggregator v2 fields
# ──────────────────────────────────────────────────────────────────────


class TestAggregatorV2Fields:
    """aggregate with dims list → v2 fields populated."""

    def test_v2_fields_populated(
        self, tmp_session_dir: Path, workflow_root: Path
    ) -> None:
        dims = ["QD1", "QD5"]

        # Dispatch first
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

        # v2 fields
        assert stats.dimensions_run == ["QD1", "QD5"]
        assert isinstance(stats.dimensions_with_issues, list)
        assert isinstance(stats.dimensions_without_issues, list)
        assert isinstance(stats.coverage_rate_pct, float)
        assert stats.coverage_rate_pct >= 0.0
        assert stats.dedup_ingested >= 0
        assert stats.dedup_deduplicated >= 0


# ──────────────────────────────────────────────────────────────────────
# J5: Full v6 pipeline
# ──────────────────────────────────────────────────────────────────────


class TestV6FullPipeline:
    """profiles.json → resolve → partition → dispatch → aggregate → reports."""

    def test_full_pipeline(
        self,
        tmp_session_dir: Path,
        workflow_root: Path,
        shared_root: Path,
        profiles_path: Path,
    ) -> None:
        # Step 1: Resolve dimensions from profiles.json
        dims = resolve_dimensions(profiles_path, "standard")
        assert set(dims) == {"QD1", "QD2", "QD5", "QD9", "QD10"}

        # Step 2: Partition
        workloads = partition_dimensions(dims)
        assert len(workloads) == 1
        assert set(workloads[0].dimensions) == {"QD1", "QD2", "QD5", "QD9", "QD10"}

        # Step 3: Dispatch
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=workloads[0].dimensions,
            profile="standard",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        # Step 4: Aggregate with v2 fields
        registry_path, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=workloads[0].dimensions,
        )

        assert registry_path.exists()
        assert stats.dimensions_run == workloads[0].dimensions

        # Step 5: Generate lane reports
        lane_template = shared_root / "templates" / "lane-report.md"
        for dim in workloads[0].dimensions:
            lane_output = tmp_session_dir / "lanes" / dim / "lane-report.md"
            if (tmp_session_dir / "lanes" / dim).exists():
                generate_lane_report(
                    template_path=lane_template,
                    output_path=lane_output,
                    dimension_id=dim,
                    dimension_name=f"Dimension {dim}",
                    profile="standard",
                    session_dir=str(tmp_session_dir),
                    probes_total=stats.by_dimension.get(dim, 0),
                    probes_available=7,
                    signals_count=stats.by_dimension.get(dim, 0),
                    issues_count=stats.by_dimension.get(dim, 0),
                    probe_rows="",
                    issues_detail="See issue-registry.json",
                    recommendations="Review issues",
                    started_at="2026-04-21T10:00:00Z",
                    completed_at="2026-04-21T10:05:00Z",
                )

        # Step 6: Generate coverage report
        coverage_template = shared_root / "templates" / "coverage-report.md"
        coverage_output = tmp_session_dir / "coverage-report.md"
        generate_coverage_report(
            template_path=coverage_template,
            output_path=coverage_output,
            profile="standard",
            dimensions_list=", ".join(workloads[0].dimensions),
            skipped_dimensions="QD3, QD4, QD6, QD7, QD8",
            session_dir=str(tmp_session_dir),
            dimension_rows="",
            total_signals=stats.total_signals,
            total_issues=stats.total_issues,
            dimensions_with_issues=len(stats.dimensions_with_issues),
            dimensions_run=len(stats.dimensions_run),
            coverage_pct=stats.coverage_rate_pct,
            severity_rows="",
            recommendations="Review found issues",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T10:15:00Z",
        )

        assert coverage_output.exists()
        content = coverage_output.read_text(encoding="utf-8")
        assert "{{PROFILE}}" not in content


# ──────────────────────────────────────────────────────────────────────
# J6: Workload JSON schema
# ──────────────────────────────────────────────────────────────────────


class TestWorkloadJSONSchema:
    """WorkloadPlan.to_dict() matches expected schema."""

    def test_workload_dict_schema(self) -> None:
        workloads = partition_dimensions(["QD1", "QD3", "QD5"])
        w = workloads[0].to_dict()

        assert "id" in w
        assert "dimensions" in w
        assert "estimated_probes" in w
        assert "estimated_minutes" in w
        assert w["id"] == "W01"
        assert isinstance(w["dimensions"], list)
        assert isinstance(w["estimated_probes"], int)
        assert isinstance(w["estimated_minutes"], float)


# ──────────────────────────────────────────────────────────────────────
# J7: ISG recommender integration
# ──────────────────────────────────────────────────────────────────────


class TestISGRecommenderIntegration:
    """ISG returns recommendation → partition uses it."""

    def test_isg_recommender_with_partition(self) -> None:
        from isg.isg_recommender import recommend_dimensions

        # Get ISG ranking — auth path boosts QD3 (security), .tsx boosts QD5
        ranked = recommend_dimensions(
            file_paths=["src/auth/login.service.ts"],
            interface_type="web",
            domain=None,
        )

        # v9.1.0: Ranked returns 11 dims with scores (QD1-QD11)
        assert len(ranked) == 11
        top_dims = [dim for dim, score in ranked[:3]]
        assert len(top_dims) == 3

        # Partition using ISG-ranked dims
        top_3 = [dim for dim, _ in ranked[:3]]
        workloads = partition_dimensions(top_3)
        assert len(workloads) == 1
        assert set(workloads[0].dimensions) == set(top_3)


# ──────────────────────────────────────────────────────────────────────
# J8: Coverage report from aggregation stats
# ──────────────────────────────────────────────────────────────────────


class TestCoverageReportFromAggregation:
    """coverage-report generated from actual aggregation stats."""

    def test_coverage_from_stats(
        self, tmp_session_dir: Path, workflow_root: Path, shared_root: Path
    ) -> None:
        dims = ["QD1", "QD2", "QD3"]

        # Dispatch + aggregate
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

        # Generate coverage report from real stats
        coverage_template = shared_root / "templates" / "coverage-report.md"
        coverage_output = tmp_session_dir / "coverage-report.md"

        generate_coverage_report(
            template_path=coverage_template,
            output_path=coverage_output,
            profile="deep",
            dimensions_list=", ".join(stats.dimensions_run),
            skipped_dimensions="QD4, QD5, QD6, QD7",
            session_dir=str(tmp_session_dir),
            dimension_rows="",
            total_signals=stats.total_signals,
            total_issues=stats.total_issues,
            dimensions_with_issues=len(stats.dimensions_with_issues),
            dimensions_run=len(stats.dimensions_run),
            coverage_pct=stats.coverage_rate_pct,
            severity_rows="",
            recommendations="Check found issues",
            started_at="2026-04-21T10:00:00Z",
            completed_at="2026-04-21T10:05:00Z",
        )

        assert coverage_output.exists()
        content = coverage_output.read_text(encoding="utf-8")
        # Stats values should appear in report
        assert str(stats.total_signals) in content
        assert str(stats.total_issues) in content
        # No unresolved placeholders
        assert "{{" not in content
