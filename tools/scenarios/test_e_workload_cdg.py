"""test_e_workload_cdg.py — Scenario E: Workload BLOCK + CDG-A02 override + anti-loop.

Verify: workload gate thresholds (0.8 / 1.5), CDG tokens, anti-loop guard.

Kiem tra:
    - check_workload_gate tra ve triggered dung theo time_ratio, features count,
      largest_module.
    - apply_user_choice xu ly 3 options (continue, abort, downgrade).
    - CDG token structure hop le, reject count >= 2 force escalate.
    - Anti-loop guard nguoi cho CDG reject lap lai.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from ips.workload_gate import (
    DEFAULT_FEATURES_TRIGGER,
    DEFAULT_LARGEST_MODULE_FILES,
    DEFAULT_TIME_RATIO_TRIGGER,
    OPTION_ABORT,
    OPTION_CONTINUE,
    OPTION_DOWNGRADE,
    GateResult,
    apply_user_choice,
    check_workload_gate,
)


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────

# Workload nho — khong trigger gate
workload_small: dict = {
    "est_time_min": 10,
    "budget_min": 60,
    "total_features_est": 5,
    "module_count": 3,
}

# Workload lon — trigger nhieu conditions
workload_large: dict = {
    "est_time_min": 100,
    "budget_min": 60,
    "total_features_est": 150,
    "module_count": 5,
}


def _should_escalate(reject_counts: dict[str, int], cdg_id: str) -> bool:
    """Anti-loop guard: reject >= 2 cho cung cdg_id → force ESCALATE.

    Pattern nay duoc dung trong SKILL.md de quyet dinh xem co can
    escalate len user khi CDG bi reject nhieu lan.
    """
    return reject_counts.get(cdg_id, 0) >= 2


# ──────────────────────────────────────────────────────────────────────
# Test Workload Gate
# ──────────────────────────────────────────────────────────────────────


class TestWorkloadGate:
    """Kiem tra workload gate thresholds va trigger conditions."""

    def test_gate_not_triggered_normal(self) -> None:
        """Workload nho (est_time=10, budget=60) khong trigger gate."""
        result = check_workload_gate(workload_small, profile="standard")
        assert isinstance(result, GateResult)
        assert result.triggered is False
        assert result.triggers == []

    def test_gate_triggered_time_ratio(self) -> None:
        """est_time=100, budget=60 → time_ratio > 1.5 → triggered."""
        result = check_workload_gate(workload_large, profile="standard")
        assert result.triggered is True
        # time_ratio = 100/60 = 1.67 > 1.5 threshold
        assert result.time_ratio > DEFAULT_TIME_RATIO_TRIGGER
        assert any("Time estimate" in t for t in result.triggers)

    def test_gate_warn_zone(self) -> None:
        """time_ratio = 1.17 (70/60) — duoi 1.5 threshold, khong trigger time."""
        workload_warn: dict = {
            "est_time_min": 70,
            "budget_min": 60,
            "total_features_est": 5,
            "module_count": 3,
        }
        result = check_workload_gate(workload_warn, profile="standard")
        # 70/60 = 1.17 < 1.5 → time ratio trigger KHONG kich hoat
        assert result.time_ratio < DEFAULT_TIME_RATIO_TRIGGER
        time_trigger_found = any("Time estimate" in t for t in result.triggers)
        assert time_trigger_found is False

    def test_gate_triggered_features_count(self) -> None:
        """total_features_est=150 (>100) → triggered."""
        workload: dict = {
            "est_time_min": 10,
            "budget_min": 60,
            "total_features_est": 150,
            "module_count": 5,
        }
        result = check_workload_gate(workload, profile="standard")
        assert result.triggered is True
        features_trigger = any("features" in t.lower() for t in result.triggers)
        assert features_trigger is True

    def test_gate_triggered_largest_module(self) -> None:
        """largest_module_files=50 (>40) → triggered."""
        workload: dict = {
            "est_time_min": 10,
            "budget_min": 60,
            "total_features_est": 5,
            "module_count": 3,
        }
        result = check_workload_gate(
            workload,
            profile="standard",
            largest_module_files=50,
        )
        assert result.triggered is True
        module_trigger = any("Module" in t for t in result.triggers)
        assert module_trigger is True

    def test_downgrade_recommendation(self) -> None:
        """Profile exhaustive + triggered → recommended_downgrade='deep'."""
        result = check_workload_gate(
            workload_large,
            profile="exhaustive",
        )
        assert result.triggered is True
        assert result.recommended_downgrade == "deep"

    def test_user_choice_continue(self) -> None:
        """OPTION_CONTINUE → action='continue', giu nguyen profile."""
        result = check_workload_gate(workload_large, profile="standard")
        decision = apply_user_choice(OPTION_CONTINUE, result)
        assert decision["action"] == "continue"
        assert decision["new_profile"] == "standard"

    def test_user_choice_abort(self) -> None:
        """OPTION_ABORT → action='abort', new_profile=None."""
        result = check_workload_gate(workload_large, profile="standard")
        decision = apply_user_choice(OPTION_ABORT, result)
        assert decision["action"] == "abort"
        assert decision["new_profile"] is None

    def test_user_choice_invalid(self) -> None:
        """Lua chon khong hop le → raise ValueError."""
        result = check_workload_gate(workload_small, profile="standard")
        with pytest.raises(ValueError, match="choice must be one of"):
            apply_user_choice("invalid-option", result)


# ──────────────────────────────────────────────────────────────────────
# Test CDG + Anti-loop
# ──────────────────────────────────────────────────────────────────────


class TestCDGAntiLoop:
    """Kiem tra CDG token structure va anti-loop guard."""

    def test_cdg_tokens_json_format(self, tmp_path: Path) -> None:
        """CDG tokens JSON co cau truc dung: cdg_tokens[] + cdg_reject_counts."""
        cdg_tokens = {
            "cdg_tokens": [
                {
                    "cdg_id": "CDG-02",
                    "issue_id": "ISS-001",
                    "user_decision": "accept",
                    "decided_at": "2026-04-23T10:00:00+00:00",
                },
                {
                    "cdg_id": "CDG-03",
                    "issue_id": "ISS-002",
                    "user_decision": "reject",
                    "decided_at": "2026-04-23T10:05:00+00:00",
                },
            ],
            "cdg_reject_counts": {"CDG-03": 1},
        }

        token_path = tmp_path / "cdg-tokens.json"
        token_path.write_text(
            json.dumps(cdg_tokens, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

        # Verify JSON parse thanh cong
        loaded = json.loads(token_path.read_text(encoding="utf-8"))
        assert "cdg_tokens" in loaded
        assert "cdg_reject_counts" in loaded
        assert len(loaded["cdg_tokens"]) == 2
        assert loaded["cdg_tokens"][0]["user_decision"] == "accept"
        assert loaded["cdg_tokens"][1]["user_decision"] == "reject"

    def test_cdg_reject_count_triggers_escalate(self) -> None:
        """CDG bi reject 2 lan cho cung cdg_id → force ESCALATE."""
        reject_counts: dict[str, int] = {"CDG-03": 2}

        # Reject count = 2 → should escalate
        assert _should_escalate(reject_counts, "CDG-03") is True

        # Reject count = 1 → not yet escalate
        reject_counts["CDG-03"] = 1
        assert _should_escalate(reject_counts, "CDG-03") is False

        # Khong co entry → 0 → not escalate
        assert _should_escalate(reject_counts, "CDG-99") is False

    def test_cdg_accept_allows_execution(self, tmp_path: Path) -> None:
        """Tat ca CDG tokens duoc accept → khong co block."""
        cdg_tokens = {
            "cdg_tokens": [
                {
                    "cdg_id": "CDG-02",
                    "issue_id": "ISS-001",
                    "user_decision": "accept",
                    "decided_at": "2026-04-23T10:00:00+00:00",
                },
                {
                    "cdg_id": "CDG-03",
                    "issue_id": "ISS-002",
                    "user_decision": "accept",
                    "decided_at": "2026-04-23T10:05:00+00:00",
                },
            ],
            "cdg_reject_counts": {},
        }

        token_path = tmp_path / "cdg-tokens.json"
        token_path.write_text(
            json.dumps(cdg_tokens, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

        loaded = json.loads(token_path.read_text(encoding="utf-8"))

        # Tat ca accept → khong co reject count nao
        assert all(
            t["user_decision"] == "accept" for t in loaded["cdg_tokens"]
        )
        assert sum(loaded["cdg_reject_counts"].values()) == 0

        # Anti-loop check: khong co CDG nao can escalate
        for token in loaded["cdg_tokens"]:
            assert _should_escalate(loaded["cdg_reject_counts"], token["cdg_id"]) is False
