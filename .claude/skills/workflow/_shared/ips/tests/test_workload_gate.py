"""Tests cho workload_gate — Phase F Task F.5.

Coverage:
- 5 trigger conditions (09-thresholds §2.5).
- Env var overrides.
- Profile downgrade map (3-option plan).
- format_warn_message shape.
- apply_user_choice outputs.
- Acceptance criteria (09 §2.5 thresholds).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import workload_gate as wg  # noqa: E402


def _base_estimate(**overrides):
    """Baseline workload estimate — duoi nguong de modify per-test."""
    return {
        "total_features_est": 20,
        "est_time_min": 30,
        "budget_min": 60,
        "exceeds_cap": False,
        "ratio": 0.5,
        "module_count": 5,
        **overrides,
    }


# ---------------------------------------------------------------------------
# Threshold env overrides
# ---------------------------------------------------------------------------


class TestThresholdDefaults:
    def test_time_ratio_default(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("LEGACY_SCAN_WORKLOAD_TIME_RATIO", None)
            assert wg.time_ratio_trigger() == 1.5

    def test_largest_module_default(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("LEGACY_SCAN_WORKLOAD_LARGEST_MOD", None)
            assert wg.largest_module_trigger() == 40

    def test_time_ratio_env_override(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_WORKLOAD_TIME_RATIO": "2.0"}):
            assert wg.time_ratio_trigger() == 2.0

    def test_largest_module_env_override(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_WORKLOAD_LARGEST_MOD": "60"}):
            assert wg.largest_module_trigger() == 60

    def test_invalid_env_falls_back(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_WORKLOAD_TIME_RATIO": "not-a-number"}):
            assert wg.time_ratio_trigger() == 1.5

    def test_negative_env_falls_back(self) -> None:
        with patch.dict(os.environ, {"LEGACY_SCAN_WORKLOAD_TIME_RATIO": "-3"}):
            assert wg.time_ratio_trigger() == 1.5


# ---------------------------------------------------------------------------
# Trigger conditions (5 triggers from 09-thresholds §2.5)
# ---------------------------------------------------------------------------


class TestTriggerConditions:
    def test_no_trigger_default(self) -> None:
        result = wg.check_workload_gate(_base_estimate(), profile="standard")
        assert result.triggered is False
        assert result.triggers == []

    def test_trigger_time_ratio(self) -> None:
        # 100 / 60 = 1.67x > 1.5
        est = _base_estimate(est_time_min=100, budget_min=60)
        result = wg.check_workload_gate(est, profile="deep")
        assert result.triggered is True
        assert any("Time estimate" in t for t in result.triggers)
        assert result.time_ratio == pytest.approx(1.67, abs=0.01)

    def test_trigger_features_count(self) -> None:
        est = _base_estimate(total_features_est=120)
        result = wg.check_workload_gate(est, profile="standard")
        assert result.triggered is True
        assert any("120 features" in t for t in result.triggers)

    def test_trigger_largest_module(self) -> None:
        result = wg.check_workload_gate(
            _base_estimate(), profile="standard", largest_module_files=45
        )
        assert result.triggered is True
        assert any("Module lớn nhất" in t for t in result.triggers)

    def test_largest_module_at_threshold_not_triggered(self) -> None:
        # 40 == threshold → NOT triggered (strict >)
        result = wg.check_workload_gate(
            _base_estimate(), profile="standard", largest_module_files=40
        )
        assert result.triggered is False

    def test_trigger_modules_count(self) -> None:
        result = wg.check_workload_gate(
            _base_estimate(), profile="standard", modules_count=35
        )
        assert result.triggered is True
        assert any("35 modules" in t for t in result.triggers)

    def test_trigger_total_files_deep(self) -> None:
        result = wg.check_workload_gate(
            _base_estimate(), profile="deep", total_files=1200
        )
        assert result.triggered is True
        assert any("1200 files" in t for t in result.triggers)

    def test_total_files_standard_not_trigger(self) -> None:
        # Profile = standard → khong trigger total_files threshold
        result = wg.check_workload_gate(
            _base_estimate(), profile="standard", total_files=1200
        )
        # Chi trigger neu co reasons khac — o day khong co → FALSE
        assert result.triggered is False

    def test_multiple_triggers_aggregated(self) -> None:
        est = _base_estimate(
            total_features_est=120, est_time_min=120, budget_min=60, module_count=40
        )
        result = wg.check_workload_gate(
            est, profile="deep", largest_module_files=60, total_files=1500
        )
        assert result.triggered is True
        # All 5 triggers expected
        assert len(result.triggers) == 5


# ---------------------------------------------------------------------------
# GateResult fields + serialization
# ---------------------------------------------------------------------------


class TestGateResultFields:
    def test_profile_recorded(self) -> None:
        result = wg.check_workload_gate(_base_estimate(), profile="deep")
        assert result.profile == "deep"

    def test_recommended_downgrade(self) -> None:
        est = _base_estimate(total_features_est=120)
        result = wg.check_workload_gate(est, profile="exhaustive")
        assert result.recommended_downgrade == "deep"

    def test_downgrade_map_complete(self) -> None:
        assert wg.PROFILE_DOWNGRADE_MAP["exhaustive"] == "deep"
        assert wg.PROFILE_DOWNGRADE_MAP["deep"] == "standard"
        assert wg.PROFILE_DOWNGRADE_MAP["standard"] == "surface"
        # surface → surface (no further downgrade)
        assert wg.PROFILE_DOWNGRADE_MAP["surface"] == "surface"

    def test_to_dict_shape(self) -> None:
        result = wg.check_workload_gate(_base_estimate(), profile="standard")
        d = result.to_dict()
        expected_keys = {
            "triggered",
            "profile",
            "triggers",
            "time_ratio",
            "estimated_time_min",
            "profile_budget_min",
            "total_features_est",
            "modules_count",
            "largest_module_files",
            "total_files",
            "recommended_downgrade",
        }
        assert set(d.keys()) == expected_keys

    def test_invalid_estimate_raises(self) -> None:
        with pytest.raises(TypeError):
            wg.check_workload_gate("not-a-dict", profile="standard")  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# Threshold override parameters
# ---------------------------------------------------------------------------


class TestOverrideParams:
    def test_time_ratio_override(self) -> None:
        # Default 1.5x would trigger; override to 3.0x should not
        est = _base_estimate(est_time_min=100, budget_min=60)
        result = wg.check_workload_gate(
            est, profile="deep", time_ratio_override=3.0
        )
        assert result.triggered is False

    def test_largest_module_override(self) -> None:
        # Default 40 trigger → override to 100 → not triggered
        result = wg.check_workload_gate(
            _base_estimate(),
            profile="standard",
            largest_module_files=50,
            largest_module_override=100,
        )
        assert result.triggered is False


# ---------------------------------------------------------------------------
# format_warn_message
# ---------------------------------------------------------------------------


class TestWarnMessage:
    def test_no_trigger_message(self) -> None:
        result = wg.check_workload_gate(_base_estimate(), profile="standard")
        msg = wg.format_warn_message(result)
        assert "within expected budget" in msg

    def test_trigger_message_contains_options(self) -> None:
        est = _base_estimate(total_features_est=120, est_time_min=100, budget_min=60)
        result = wg.check_workload_gate(est, profile="deep")
        msg = wg.format_warn_message(result)
        assert wg.OPTION_CONTINUE in msg
        assert wg.OPTION_DOWNGRADE in msg
        assert wg.OPTION_ABORT in msg
        assert "[A]" in msg and "[B]" in msg and "[C]" in msg

    def test_trigger_message_shows_downgrade_target(self) -> None:
        est = _base_estimate(total_features_est=120)
        result = wg.check_workload_gate(est, profile="exhaustive")
        msg = wg.format_warn_message(result)
        assert "exhaustive → deep" in msg


# ---------------------------------------------------------------------------
# apply_user_choice
# ---------------------------------------------------------------------------


class TestApplyUserChoice:
    def _triggered_result(self, profile: str = "deep") -> wg.GateResult:
        est = _base_estimate(total_features_est=120)
        return wg.check_workload_gate(est, profile=profile)

    def test_continue_keeps_profile(self) -> None:
        res = self._triggered_result("deep")
        action = wg.apply_user_choice(wg.OPTION_CONTINUE, res)
        assert action["action"] == "continue"
        assert action["new_profile"] == "deep"
        assert action["log_level"] == "warn"

    def test_downgrade_changes_profile(self) -> None:
        res = self._triggered_result("exhaustive")
        action = wg.apply_user_choice(wg.OPTION_DOWNGRADE, res)
        assert action["action"] == "downgrade"
        assert action["new_profile"] == "deep"

    def test_downgrade_deep_to_standard(self) -> None:
        res = self._triggered_result("deep")
        action = wg.apply_user_choice(wg.OPTION_DOWNGRADE, res)
        assert action["new_profile"] == "standard"

    def test_downgrade_surface_keeps_surface(self) -> None:
        res = self._triggered_result("surface")
        action = wg.apply_user_choice(wg.OPTION_DOWNGRADE, res)
        # Surface can't downgrade further → keep profile
        assert action["new_profile"] == "surface"

    def test_abort_exits_clean(self) -> None:
        res = self._triggered_result("deep")
        action = wg.apply_user_choice(wg.OPTION_ABORT, res)
        assert action["action"] == "abort"
        assert action["new_profile"] is None

    def test_invalid_choice_raises(self) -> None:
        res = self._triggered_result("deep")
        with pytest.raises(ValueError):
            wg.apply_user_choice("invalid-choice", res)


# ---------------------------------------------------------------------------
# Acceptance criteria (per phase-F-impact-incremental.md F.5)
# ---------------------------------------------------------------------------


class TestAcceptanceCriteria:
    def test_gate_triggers_per_09_thresholds(self) -> None:
        """AC: Gate triggers đúng theo 09 §2.5 thresholds."""
        # All 5 trigger conditions, one per test
        cases = [
            ({"est_time_min": 100, "budget_min": 60}, "standard", None, None, None, "time"),
            ({"total_features_est": 120}, "standard", None, None, None, "features"),
            ({}, "standard", None, 45, None, "largest module"),
            ({}, "standard", 35, None, None, "modules count"),
            ({}, "deep", None, None, 1200, "total files"),
        ]
        for est_over, profile, mods, largest, total, name in cases:
            est = _base_estimate(**est_over)
            result = wg.check_workload_gate(
                est,
                profile=profile,
                modules_count=mods,
                largest_module_files=largest,
                total_files=total,
            )
            assert result.triggered is True, f"AC trigger {name} failed"

    def test_3_options_available(self) -> None:
        """AC: 3 options available."""
        assert wg.VALID_OPTIONS == (
            wg.OPTION_CONTINUE,
            wg.OPTION_DOWNGRADE,
            wg.OPTION_ABORT,
        )

    def test_downgrade_logic(self) -> None:
        """AC: downgrade-profile logic works (deep→standard, exhaustive→deep)."""
        res_deep = wg.check_workload_gate(
            _base_estimate(total_features_est=150), profile="deep"
        )
        action = wg.apply_user_choice(wg.OPTION_DOWNGRADE, res_deep)
        assert action["new_profile"] == "standard"

        res_exh = wg.check_workload_gate(
            _base_estimate(total_features_est=150), profile="exhaustive"
        )
        action = wg.apply_user_choice(wg.OPTION_DOWNGRADE, res_exh)
        assert action["new_profile"] == "deep"

    def test_abort_clean_exit(self) -> None:
        """AC: abort exits clean."""
        res = wg.check_workload_gate(
            _base_estimate(total_features_est=150), profile="deep"
        )
        action = wg.apply_user_choice(wg.OPTION_ABORT, res)
        assert action["action"] == "abort"
        assert action["new_profile"] is None

    def test_no_fix_workload_json_generated(self) -> None:
        """AC: KHONG generate fix-workload.json (defer v5.1).

        Dam bao module khong co method tao fix-workload.json.
        """
        assert not hasattr(wg, "generate_fix_workload")
        assert not hasattr(wg, "write_fix_workload")
        assert not hasattr(wg, "partition_planner")
