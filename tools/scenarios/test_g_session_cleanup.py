"""test_g_session_cleanup.py — Scenario G: Session cleanup (keep 5).

Verify: cleanup_old_sessions keeps newest 5, deletes oldest.

Kiem tra:
    - cleanup_old_sessions voi keep=5 xoa 2 sessions cu nhat, giu 5 moi nhat.
    - Return value la danh sach cac Path da bi xoa.
    - Sessions con lai la 5 sessions moi nhat (theo mtime).
    - Neu so sessions < keep → khong xoa gi ca.
    - find_latest_session tra ve session moi nhat sau cleanup.
    - validate_session_isolation pass cho sessions con lai.
"""
from __future__ import annotations

import json
from pathlib import Path

from validators.session_validator import (
    cleanup_old_sessions,
    find_latest_session,
    validate_session_isolation,
)


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def _create_session_dir(
    sessions_root: Path,
    session_id: str,
    mtime_offset: int = 0,
) -> Path:
    """Tao mot session dir voi session-state.json.

    Args:
        sessions_root: Thu muc chua cac sessions.
        session_id: ID cua session ( cung la ten thu muc).
        mtime_offset: Offset giay de dieu chinh mtime (0 = hien tai).
    """
    sdir = sessions_root / session_id
    sdir.mkdir(parents=True, exist_ok=True)
    state = {
        "$schema": "session-state-v1",
        "session_id": session_id,
        "skill_name": "wf-test",
        "created_at": f"2026-04-23T10:00:00+00:00",
        "updated_at": f"2026-04-23T10:30:00+00:00",
        "status": "completed",
        "profile_used": "standard",
        "next_action": "",
        "phases": {},
        "cdg_decisions": [],
        "digests_produced": [],
        "lanes_completed": [],
        "errors": [],
    }
    (sdir / "session-state.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return sdir


# ──────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────


class TestSessionCleanup:
    """Kiem tra session cleanup logic — keep N newest, delete rest."""

    def test_cleanup_keeps_5(self, tmp_multi_sessions: Path) -> None:
        """cleanup_old_sessions(keep=5) voi 7 sessions → 5 con lai."""
        all_before = list(tmp_multi_sessions.iterdir())
        assert len(all_before) == 7

        deleted = cleanup_old_sessions(tmp_multi_sessions, keep=5)
        assert len(deleted) == 2

        all_after = [d for d in tmp_multi_sessions.iterdir() if d.is_dir()]
        assert len(all_after) == 5

    def test_deleted_returned(self, tmp_multi_sessions: Path) -> None:
        """cleanup_old_sessions tra ve danh sach 2 Path da bi xoa."""
        deleted = cleanup_old_sessions(tmp_multi_sessions, keep=5)
        assert isinstance(deleted, list)
        assert len(deleted) == 2
        assert all(isinstance(p, Path) for p in deleted)
        # Cac Path da xoa khong ton tai nua
        for d in deleted:
            assert not d.exists(), f"Deleted session still exists: {d}"

    def test_remaining_are_newest(self, tmp_multi_sessions: Path) -> None:
        """5 sessions con lai phai la 5 sessions moi nhat theo mtime."""
        cleanup_old_sessions(tmp_multi_sessions, keep=5)

        remaining = sorted(
            [d for d in tmp_multi_sessions.iterdir() if d.is_dir()],
            key=lambda d: d.stat().st_mtime,
            reverse=True,
        )
        assert len(remaining) == 5

        # Read session-state.json de lay session_id, verify ordering
        remaining_ids: list[str] = []
        for sdir in remaining:
            state_path = sdir / "session-state.json"
            data = json.loads(state_path.read_text(encoding="utf-8"))
            remaining_ids.append(data["session_id"])

        # fixture tao session-0..6 theo thu tu, nen session-6 co mtime moi nhat
        # (tao cuoi cung). cleanup_old_sessions sort by mtime descending,
        # giu 5 moi nhat (session 6,5,4,3,2), xoa 2 cu nhat (session 0,1).
        assert "session-6" in remaining_ids[0]
        assert "session-2" in remaining_ids[4]

        # Session-0 va session-1 da bi xoa
        assert "session-0" not in remaining_ids
        assert "session-1" not in remaining_ids

    def test_less_than_keep_no_deletion(self, tmp_path: Path) -> None:
        """Chi 3 sessions, keep=5 → khong xoa gi ca."""
        sessions_root = tmp_path / "sessions"
        sessions_root.mkdir()

        for i in range(3):
            _create_session_dir(sessions_root, f"2026-04-2{i}-session-{i}")

        deleted = cleanup_old_sessions(sessions_root, keep=5)
        assert deleted == []
        assert len(list(sessions_root.iterdir())) == 3

    def test_find_latest_after_cleanup(self, tmp_multi_sessions: Path) -> None:
        """Sau cleanup, find_latest_session tra ve session moi nhat con lai."""
        cleanup_old_sessions(tmp_multi_sessions, keep=5)

        latest = find_latest_session(tmp_multi_sessions)
        assert latest is not None
        assert latest.exists()

        state_path = latest / "session-state.json"
        data = json.loads(state_path.read_text(encoding="utf-8"))
        # session-6 la moi nhat theo mtime (tao cuoi cung trong fixture)
        assert "session-6" in data["session_id"]

    def test_isolation_after_cleanup(self, tmp_multi_sessions: Path) -> None:
        """validate_session_isolation pass cho cac sessions con lai sau cleanup."""
        cleanup_old_sessions(tmp_multi_sessions, keep=5)

        is_clean, errors = validate_session_isolation(tmp_multi_sessions)
        assert is_clean is True, (
            f"Session isolation violations after cleanup: {errors}"
        )
