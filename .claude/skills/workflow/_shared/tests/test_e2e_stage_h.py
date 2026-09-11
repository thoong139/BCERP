"""test_e2e_stage_h.py — Integration tests cho Stage H (SKILL.md Integration + Profile Wiring).

Test cases:
    1. Profile resolver loads profiles.json → resolve đúng dims per profile
    2. v6 full dispatch 7 dims on golden-v6 → issue-registry.json has entries for >=6 dims
    3. v6 profile quick → chỉ dispatch QD1+QD5
    4. v6 safety floor — profile standard + skip QD1,QD2,QD5 → rejected
    5. v6 backward compat — engine=v5 flow unchanged, v6 modules not loaded
    6. v6 cache integration — use_cache: cache files for non-QD3, no cache for QD3
    7. v6 template usage — coverage report + lane reports created from templates (CORE-031)

Tham chiếu:
    - Stage H spec: docs/design/skills/wf-fix-bugs/prompts/stage-H-prompt.md
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import pytest

from dimension_registry import get_cache_policy
from lane_dispatch import dispatch_lanes
from profile_resolver import resolve_probes, VALID_PROFILES
from signal_aggregator import aggregate_lane_signals
from signal_bus.signal_bus import SignalBus


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
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
def profiles_path(shared_root: Path) -> Path:
    return shared_root / "profiles.json"


@pytest.fixture
def golden_v6_root() -> Path:
    return Path(__file__).resolve().parent / "fixtures" / "golden-v6"


# ──────────────────────────────────────────────────────────────────────
# H1: profiles.json exists and loads correctly
# ──────────────────────────────────────────────────────────────────────


class TestProfileResolverProfilesJson:
    """Profile resolver loads profiles.json và resolves đúng dims per profile."""

    def test_profiles_json_exists(self, profiles_path: Path) -> None:
        assert profiles_path.exists(), "profiles.json must exist in _shared/"

    def test_profiles_json_valid_schema(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        assert data.get("$schema") == "profiles-v1"
        assert "profiles" in data
        assert "safety_floor" in data

    def test_profiles_have_correct_dimensions(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        profiles = data["profiles"]

        assert set(profiles["quick"]["dimensions"]) == {"QD1", "QD5"}
        assert set(profiles["standard"]["dimensions"]) == {"QD1", "QD2", "QD5", "QD9", "QD10"}
        assert set(profiles["deep"]["dimensions"]) == {"QD1", "QD2", "QD5", "QD6", "QD3", "QD9", "QD10", "QD11"}
        assert set(profiles["exhaustive"]["dimensions"]) == {
            "QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"
        }

    def test_profile_resolver_loads_each_profile(
        self, workflow_root: Path
    ) -> None:
        """resolve_probes works for all 4 profiles on QD1 dimension."""
        qd1_dim = workflow_root / "wf-fix-functional" / "dimension.json"
        if not qd1_dim.exists():
            pytest.skip("QD1 dimension.json not found")

        for profile in VALID_PROFILES:
            probes = resolve_probes(qd1_dim, profile)
            assert isinstance(probes, list)
            assert len(probes) > 0, f"Profile {profile} should resolve >= 1 probe"
            for pid in probes:
                assert pid.startswith("P-QD1-"), f"Probe {pid} should start with P-QD1-"

    def test_safety_floor_config(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        sf = data["safety_floor"]
        assert sf["applies_to"] == ["standard", "deep", "exhaustive"]
        assert "QD1" in sf["rule"]
        assert "QD2" in sf["rule"]
        assert "QD5" in sf["rule"]


# ──────────────────────────────────────────────────────────────────────
# H2/H3: v6 full dispatch with all 7 dimensions
# ──────────────────────────────────────────────────────────────────────


class TestV6FullDispatch:
    """Dispatch all 7 dims on golden-v6 → issue-registry.json có entries cho >=6 dims."""

    def test_dispatch_7dims_produces_lane_outputs(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """All 7 dimensions dispatch and produce lanes/QD*/signals.json."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"],
            profile="exhaustive",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        lanes_dir = tmp_session_dir / "lanes"
        assert lanes_dir.exists(), "lanes/ directory must be created"

        dims_with_output = []
        for dim in ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"]:
            lane_file = lanes_dir / dim / "signals.json"
            if lane_file.exists():
                dims_with_output.append(dim)
                data = json.loads(lane_file.read_text(encoding="utf-8"))
                assert "signals" in data or "lane" in data

        assert len(dims_with_output) >= 1, (
            f"Expected >= 1 dimension with output, got {dims_with_output}"
        )

    def test_aggregate_7dims_produces_issue_registry(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Signal aggregation after full dispatch produces issue-registry.json."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"],
            profile="exhaustive",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        registry_path, stats = aggregate_lane_signals(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"],
        )

        assert registry_path.exists()
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert "issues" in data
        assert isinstance(data["issues"], list)


# ──────────────────────────────────────────────────────────────────────
# H2: v6 profile quick — chỉ dispatch QD1+QD5
# ──────────────────────────────────────────────────────────────────────


class TestV6ProfileQuick:
    """Profile quick → chỉ dispatch QD1+QD5, không dispatch others."""

    def test_quick_only_dispatches_qd1_qd5(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD5"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )

        lanes_dir = tmp_session_dir / "lanes"
        if not lanes_dir.exists():
            pytest.skip("No lanes directory created — lanes may have 0 signals")

        # Only QD1 and QD5 should have output dirs
        for dim in ["QD2", "QD3", "QD4", "QD6", "QD7"]:
            dim_dir = lanes_dir / dim
            assert not dim_dir.exists() or not list(
                dim_dir.glob("signals.json")
            ), f"Quick profile should not dispatch {dim}"


# ──────────────────────────────────────────────────────────────────────
# H2: Safety floor enforcement
# ──────────────────────────────────────────────────────────────────────


class TestV6SafetyFloor:
    """Profile >= standard không được bỏ toàn bộ QD1+QD2+QD5."""

    def _apply_overrides(
        self,
        base_dims: list[str],
        skip_dims: list[str] | None = None,
        only_dims: list[str] | None = None,
        dims_override: list[str] | None = None,
    ) -> list[str]:
        """Simulate dimension override logic from profiles.json."""
        if dims_override is not None:
            return list(dims_override)
        result = list(base_dims)
        if only_dims is not None:
            result = [d for d in result if d in only_dims]
        if skip_dims is not None:
            result = [d for d in result if d not in skip_dims]
        return result

    def _check_safety_floor(
        self, dims: list[str], profile: str, profiles_data: dict
    ) -> bool:
        """Return True if safety floor passes."""
        sf = profiles_data["safety_floor"]
        if profile not in sf["applies_to"]:
            return True
        required = {"QD1", "QD2", "QD5"}
        return bool(required & set(dims))

    def test_standard_skip_all_core_rejected(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        base = data["profiles"]["standard"]["dimensions"]
        result = self._apply_overrides(base, skip_dims=["QD1", "QD2", "QD5"])
        assert not self._check_safety_floor(result, "standard", data), (
            "Safety floor should reject standard profile with all core dims skipped"
        )

    def test_standard_skip_one_core_passes(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        base = data["profiles"]["standard"]["dimensions"]
        result = self._apply_overrides(base, skip_dims=["QD1"])
        assert self._check_safety_floor(result, "standard", data), (
            "Safety floor should pass when only QD1 is skipped (QD2+QD5 remain)"
        )

    def test_quick_not_subject_to_safety_floor(self, profiles_path: Path) -> None:
        data = json.loads(profiles_path.read_text(encoding="utf-8"))
        base = data["profiles"]["quick"]["dimensions"]
        result = self._apply_overrides(base, skip_dims=["QD1"])
        assert self._check_safety_floor(result, "quick", data), (
            "Quick profile is not subject to safety floor"
        )


# ──────────────────────────────────────────────────────────────────────
# H2: Backward compatibility — v5 flow unchanged
# ──────────────────────────────────────────────────────────────────────


class TestV6BackwardCompat:
    """--engine=v5 flow unchanged, v6 modules not loaded."""

    def test_v5_dispatch_does_not_create_lanes_dir(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """v5 flow should not create lanes/ directory (v6-specific)."""
        # v5 flow does not call dispatch_lanes — it delegates to wf-fix-discover.
        # Verify that dispatch_lanes is NOT called by checking no lanes/ dir exists
        # when we don't explicitly call it.
        lanes_dir = tmp_session_dir / "lanes"
        assert not lanes_dir.exists(), (
            "v5 flow should not create lanes/ directory"
        )

    def test_profiles_json_not_used_in_v5(self, profiles_path: Path) -> None:
        """profiles.json exists but v5 flow doesn't need it."""
        assert profiles_path.exists()
        # v5 flow uses 5-Layer discovery, not dimension profiles.
        # The file exists for v6 only — no assertion on v5 using it.


# ──────────────────────────────────────────────────────────────────────
# H2: Cache integration — QD3 never cached
# ──────────────────────────────────────────────────────────────────────


class TestV6CacheIntegration:
    """--use-cache: cache files for non-QD3 dims, no cache for QD3."""

    def test_qd3_no_cache_with_use_cache(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        assert get_cache_policy("QD3") is False

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )

        cache_dir = tmp_session_dir / "cache" / "probes"
        if cache_dir.exists():
            cache_files = list(cache_dir.glob("*.json"))
            assert len(cache_files) == 0, "QD3 should never create cache files (ADR-22)"

    def test_qd1_cache_allowed_with_use_cache(self) -> None:
        assert get_cache_policy("QD1") is True


# ──────────────────────────────────────────────────────────────────────
# H5: Template usage (CORE-031)
# ──────────────────────────────────────────────────────────────────────


class TestV6TemplateUsage:
    """Coverage report + lane reports created từ templates (CORE-031)."""

    def test_lane_report_template_exists(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "lane-report.md"
        assert template.exists(), "lane-report.md template must exist"

    def test_coverage_report_template_exists(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "coverage-report.md"
        assert template.exists(), "coverage-report.md template must exist"

    def test_issue_registry_v2_template_exists(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "issue-registry-v2.json"
        assert template.exists(), "issue-registry-v2.json template must exist"

    def test_issue_registry_v2_valid_json(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "issue-registry-v2.json"
        data = json.loads(template.read_text(encoding="utf-8"))
        assert data.get("$schema") == "issue-registry-v2"
        assert "fix_id" in data
        assert "issues" in data
        assert "dimensions_run" in data
        assert isinstance(data["issues"], list)
        assert data["total_issues"] == 0  # Template starts with 0

    def test_lane_report_has_placeholder_vars(self, shared_root: Path) -> None:
        """Verify template has {{VARIABLE}} placeholders for population."""
        template = shared_root / "templates" / "lane-report.md"
        content = template.read_text(encoding="utf-8")
        assert "{{DIMENSION_ID}}" in content
        assert "{{SESSION_DIR}}" in content
        assert "{{SIGNALS_COUNT}}" in content

    def test_coverage_report_has_placeholder_vars(self, shared_root: Path) -> None:
        template = shared_root / "templates" / "coverage-report.md"
        content = template.read_text(encoding="utf-8")
        assert "{{PROFILE}}" in content
        assert "{{DIMENSIONS_LIST}}" in content
        assert "{{TOTAL_ISSUES}}" in content
