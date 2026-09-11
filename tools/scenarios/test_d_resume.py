"""test_d_resume.py -- Scenario D: Resume mid-phase.

Verify: session-state.json preserves position, resume detects correct state.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import pytest

from validators.session_validator import (
    find_latest_session,
    validate_session_dir,
    validate_session_isolation,
)


def _write_session_state(session_dir: Path, state: dict) -> None:
    """Ghi session-state.json vao session dir."""
    session_dir.mkdir(parents=True, exist_ok=True)
    (session_dir / "session-state.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8",
    )


def _make_base_state(session_id: str, **overrides) -> dict:
    """Tao base session-state dict voi optional overrides."""
    base = {
        "$schema": "session-state-v1",
        "session_id": session_id,
        "skill_name": "wf-test",
        "created_at": "2026-04-23T10:00:00+00:00",
        "updated_at": "2026-04-23T10:30:00+00:00",
        "status": "in_progress",
        "profile_used": "standard",
        "next_action": "phase_3",
        "phases": {"phase_0": "completed", "phase_1": "completed", "phase_2": "in_progress"},
        "cdg_decisions": [],
        "digests_produced": [],
        "lanes_completed": [],
        "errors": [],
    }
    base.update(overrides)
    return base


@pytest.mark.scenario_d
class TestResumeScenario:
    """Kiem tra resume mid-phase -- session state va isolation."""

    def test_session_state_preserves_phase(self, tmp_path: Path) -> None:
        """Verify session-state.json luu dung trang thai pause va next_action."""
        session_dir = tmp_path / "sessions" / "2026-04-23-paused-session"
        state = _make_base_state(
            "2026-04-23-paused-session",
            status="paused",
            next_action="phase_3",
            phases={"phase_0": "completed", "phase_1": "completed", "phase_2": "paused"},
        )
        _write_session_state(session_dir, state)

        # Doc lai va verify
        loaded = json.loads(
            (session_dir / "session-state.json").read_text(encoding="utf-8")
        )
        assert loaded["status"] == "paused", f"Cho 'paused', thay '{loaded['status']}'"
        assert loaded["next_action"] == "phase_3", (
            f"Cho 'phase_3', thay '{loaded['next_action']}'"
        )
        assert loaded["phases"]["phase_2"] == "paused", (
            f"Cho phase_2='paused', thay '{loaded['phases']['phase_2']}'"
        )

    def test_in_progress_session_detected(self, tmp_path: Path) -> None:
        """Verify find_latest_session tra ve session in_progress."""
        sessions_root = tmp_path / "sessions"
        session_dir = sessions_root / "2026-04-23-active-session"
        state = _make_base_state(
            "2026-04-23-active-session",
            status="in_progress",
        )
        _write_session_state(session_dir, state)

        latest = find_latest_session(sessions_root)
        assert latest is not None, "find_latest_session tra ve None"
        assert latest.name == "2026-04-23-active-session", (
            f"Cho '2026-04-23-active-session', thay '{latest.name}'"
        )

    def test_multiple_sessions_latest_found(self, tmp_path: Path) -> None:
        """Verify find_latest_session tra ve session moi nhat theo mtime."""
        sessions_root = tmp_path / "sessions"
        sessions_root.mkdir(parents=True, exist_ok=True)

        # Tao 3 sessions voi mtime khac nhau
        session_names = [
            "2026-04-20-oldest",
            "2026-04-21-middle",
            "2026-04-22-newest",
        ]
        for i, name in enumerate(session_names):
            sdir = sessions_root / name
            state = _make_base_state(name)
            _write_session_state(sdir, state)
            # Dat mtime khac biet: cu nhat -> moi nhat
            mtime = time.time() + (i * 100)
            os.utime(sdir, (mtime, mtime))

        latest = find_latest_session(sessions_root)
        assert latest is not None, "find_latest_session tra ve None"
        assert latest.name == "2026-04-22-newest", (
            f"Cho session moi nhat '2026-04-22-newest', thay '{latest.name}'"
        )

    def test_session_isolation_no_cross_contamination(self, tmp_path: Path) -> None:
        """Verify 2 sessions khac session_id khong bi cross-contaminate."""
        sessions_root = tmp_path / "sessions"

        for sid in ["session-alpha", "session-beta"]:
            sdir = sessions_root / sid
            state = _make_base_state(sid)
            _write_session_state(sdir, state)

        is_clean, errors = validate_session_isolation(sessions_root)
        assert is_clean, f"Session isolation violations: {errors}"

    def test_paused_to_resume_flow(self, tmp_path: Path) -> None:
        """Simulate: tao paused session -> update to in_progress -> validate passes."""
        session_dir = tmp_path / "sessions" / "2026-04-23-resume-test"
        state = _make_base_state(
            "2026-04-23-resume-test",
            status="paused",
            next_action="phase_2",
            phases={"phase_0": "completed", "phase_1": "completed"},
        )
        _write_session_state(session_dir, state)

        # Validate paused state
        is_valid, errors = validate_session_dir(session_dir)
        assert is_valid, f"Paused session khong hop le: {errors}"

        # Simulate resume: update status
        state["status"] = "in_progress"
        state["next_action"] = "phase_2"
        state["phases"]["phase_2"] = "in_progress"
        _write_session_state(session_dir, state)

        # Validate resumed state
        is_valid, errors = validate_session_dir(session_dir)
        assert is_valid, f"Resumed session khong hop le: {errors}"

        loaded = json.loads(
            (session_dir / "session-state.json").read_text(encoding="utf-8")
        )
        assert loaded["status"] == "in_progress"
        assert loaded["phases"]["phase_2"] == "in_progress"

    def test_fix_status_schema(self, tmp_path: Path) -> None:
        """Verify fix-status.json co structure phases dung theo _shared template pattern."""
        fix_status = {
            "$schema": "fix-status-v1",
            "fix_id": "test-fix-001",
            "status": "in_progress",
            "engine_version": "v6",
            "active_skill": "wf-fix-triage",
            "next_action": "phase_2_triage",
            "phases": {
                "phase_1": {"status": "completed", "name": "Lane Dispatch"},
                "phase_2": {"status": "in_progress", "name": "Triage"},
            },
        }

        # Verify expected structure
        assert fix_status["$schema"] == "fix-status-v1"
        assert "phases" in fix_status
        assert isinstance(fix_status["phases"], dict)

        phases = fix_status["phases"]
        assert "phase_1" in phases
        assert "phase_2" in phases
        assert phases["phase_1"]["status"] == "completed"
        assert phases["phase_1"]["name"] == "Lane Dispatch"
        assert phases["phase_2"]["status"] == "in_progress"
        assert phases["phase_2"]["name"] == "Triage"

        # Verify core metadata fields
        assert fix_status["fix_id"] == "test-fix-001"
        assert fix_status["engine_version"] == "v6"
        assert fix_status["active_skill"] == "wf-fix-triage"
        assert fix_status["next_action"] == "phase_2_triage"

        # Ghi ra file va verify lai
        fix_path = tmp_path / "fix-status.json"
        fix_path.write_text(
            json.dumps(fix_status, ensure_ascii=False, indent=2), encoding="utf-8",
        )
        loaded = json.loads(fix_path.read_text(encoding="utf-8"))
        assert loaded == fix_status, "fix-status.json round-trip khong khop"
