"""test_profile_resolver.py — Unit tests cho profiles module.

Test coverage:
    1. resolve_profile: priority ordering (CLI > recommendation > default)
    2. validate_safety_floor: production enforcement
    3. get_depth_for_phase: depth_map lookup + fallback
    4. estimate_time: time estimation
    5. Edge cases: invalid profile, missing data
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Đảm bảo import path hoạt động
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from profiles.profile_resolver import (
    DEFAULT_PROFILE,
    LINEAR_VALID_PROFILES,
    estimate_time,
    get_depth_for_phase,
    get_max_parallel,
    resolve_profile,
    validate_safety_floor,
)


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────

PROFILES_DIR = Path(__file__).resolve().parent.parent
PROFILES_JSON = PROFILES_DIR / "profiles.json"


@pytest.fixture
def profiles_data():
    """Load profiles.json gốc cho các test cần đọc data."""
    return json.loads(PROFILES_JSON.read_text(encoding="utf-8"))


# ──────────────────────────────────────────────────────────────────────
# 1. resolve_profile — priority ordering
# ──────────────────────────────────────────────────────────────────────


class TestResolveProfile:
    """Test resolve_profile: CLI > recommendation > default."""

    def test_cli_override_takes_priority(self):
        """CLI profile luôn thắng, bất kể recommendation."""
        result = resolve_profile(
            "wf-design",
            cli_profile="deep",
            recommendation={"profile": "quick"},
        )
        assert result == "deep"

    def test_recommendation_used_when_no_cli(self):
        """Recommendation được dùng khi không có CLI override."""
        result = resolve_profile(
            "wf-design",
            cli_profile=None,
            recommendation={"profile": "quick"},
        )
        assert result == "quick"

    def test_default_when_nothing_provided(self):
        """Default 'standard' khi không có CLI và recommendation."""
        result = resolve_profile("wf-design")
        assert result == DEFAULT_PROFILE
        assert result == "standard"

    def test_recommendation_invalid_falls_to_default(self):
        """Recommendation với profile không hợp lệ → default."""
        result = resolve_profile(
            "wf-design",
            cli_profile=None,
            recommendation={"profile": "exhaustive"},  # không có trong linear
        )
        assert result == DEFAULT_PROFILE

    def test_recommendation_missing_key_falls_to_default(self):
        """Recommendation không có 'profile' key → default."""
        result = resolve_profile(
            "wf-design",
            cli_profile=None,
            recommendation={"depth": "full"},
        )
        assert result == DEFAULT_PROFILE

    def test_invalid_cli_raises(self):
        """CLI profile không hợp lệ → ValueError."""
        with pytest.raises(ValueError, match="không hợp lệ"):
            resolve_profile("wf-design", cli_profile="turbo")

    def test_all_valid_profiles(self):
        """Tất cả 3 profile hợp lệ đều được accept qua CLI."""
        for p in LINEAR_VALID_PROFILES:
            result = resolve_profile("wf-design", cli_profile=p)
            assert result == p


# ──────────────────────────────────────────────────────────────────────
# 2. validate_safety_floor
# ──────────────────────────────────────────────────────────────────────


class TestSafetyFloor:
    """Test safety floor enforcement cho production projects."""

    def test_production_standard_passes(self):
        """Production + standard → pass."""
        assert validate_safety_floor("standard", is_production=True) is True

    def test_production_deep_passes(self):
        """Production + deep → pass."""
        assert validate_safety_floor("deep", is_production=True) is True

    def test_production_quick_fails(self):
        """Production + quick → ValueError."""
        with pytest.raises(ValueError, match="production-bound"):
            validate_safety_floor("quick", is_production=True)

    def test_non_production_any_profile(self):
        """Non-production + bất kỳ profile → pass."""
        for p in LINEAR_VALID_PROFILES:
            assert validate_safety_floor(p, is_production=False) is True


# ──────────────────────────────────────────────────────────────────────
# 3. get_depth_for_phase
# ──────────────────────────────────────────────────────────────────────


class TestDepthForPhase:
    """Test depth_map lookup."""

    def test_quick_requirements_is_summary(self):
        """Profile quick + requirements → summary."""
        assert get_depth_for_phase("quick", "wf-analyze-requirements") == "summary"

    def test_quick_features_is_stub(self):
        """Profile quick + features → stub."""
        assert get_depth_for_phase("quick", "wf-define-features") == "stub"

    def test_standard_all_full(self):
        """Profile standard → tất cả phases trả về 'full'."""
        for skill, phase_key in [
            ("wf-analyze-requirements", "requirements"),
            ("wf-define-features", "features"),
            ("wf-design", "design"),
            ("wf-design-ux", "ux"),
        ]:
            assert get_depth_for_phase("standard", skill) == "full"

    def test_deep_all_deep(self):
        """Profile deep → tất cả phases trả về 'deep'."""
        for skill in [
            "wf-analyze-requirements",
            "wf-define-features",
            "wf-design",
            "wf-design-ux",
        ]:
            assert get_depth_for_phase("deep", skill) == "deep"

    def test_explicit_phase_key_override(self):
        """Phase key chỉ định trực tiếp thắng skill_name."""
        result = get_depth_for_phase(
            "quick", "wf-analyze-requirements", phase_key="design"
        )
        assert result == "outline"

    def test_unknown_skill_returns_fallback(self):
        """Skill không có trong SKILL_PHASE_MAP → fallback 'full'."""
        result = get_depth_for_phase("standard", "wf-unknown-skill")
        assert result == "full"

    def test_invalid_profile_raises(self):
        """Profile không hợp lệ → ValueError."""
        with pytest.raises(ValueError, match="không hợp lệ"):
            get_depth_for_phase("exhaustive", "wf-design")


# ──────────────────────────────────────────────────────────────────────
# 4. estimate_time
# ──────────────────────────────────────────────────────────────────────


class TestEstimateTime:
    """Test ước lượng thời gian."""

    def test_quick_15_minutes(self):
        """Profile quick → 15 phút."""
        assert estimate_time("quick") == 15

    def test_standard_45_minutes(self):
        """Profile standard → 45 phút."""
        assert estimate_time("standard") == 45

    def test_deep_90_minutes(self):
        """Profile deep → 90 phút."""
        assert estimate_time("deep") == 90

    def test_invalid_profile_raises(self):
        """Profile không hợp lệ → ValueError."""
        with pytest.raises(ValueError, match="không hợp lệ"):
            estimate_time("exhaustive")


# ──────────────────────────────────────────────────────────────────────
# 5. get_max_parallel
# ──────────────────────────────────────────────────────────────────────


class TestMaxParallel:
    """Test số lanes max parallel."""

    def test_quick_2_lanes(self):
        """Profile quick → 2 lanes."""
        assert get_max_parallel("quick") == 2

    def test_standard_3_lanes(self):
        """Profile standard → 3 lanes."""
        assert get_max_parallel("standard") == 3

    def test_deep_3_lanes(self):
        """Profile deep → 3 lanes."""
        assert get_max_parallel("deep") == 3
