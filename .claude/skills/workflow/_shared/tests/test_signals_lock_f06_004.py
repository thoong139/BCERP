"""test_signals_lock_f06_004.py — F06.004 (Sprint 6) signals_lock + heartbeat.

Verify:
- SIGNALS_LOCK_STALE_SEC default = 60s (giảm từ 300s).
- _signals_lock_acquire / _release lifecycle + heartbeat thread cleanup.
- Stale takeover khi mtime > stale_sec (simulate writer crash).
- Heartbeat thread refresh mtime để tránh false-positive stale.

Tests intentionally không sleep dài (>1s) — dùng os.utime để giả mạo mtime.
"""
from __future__ import annotations

import os
import time
from pathlib import Path

import pytest

from lane_dispatch import (
    LOCK_HEARTBEAT_INTERVAL_SEC,
    SIGNALS_LOCK_STALE_SEC,
    _heartbeat_touch,
    _lock_heartbeats,
    _signals_lock_acquire,
    _signals_lock_release,
)


class TestStaleConfig:
    """Verify SIGNALS_LOCK_STALE_SEC default."""

    def test_stale_default_60s(self) -> None:
        """F06.004: default stale = 60s, không phải 300s gốc."""
        # Env LANE_DISPATCH_LOCK_STALE_SEC chưa set → default 60.
        # Test chỉ verify nếu env không set: default phải <= 60.
        assert SIGNALS_LOCK_STALE_SEC <= 60, (
            f"Stale timeout {SIGNALS_LOCK_STALE_SEC}s vẫn quá cao "
            f"so với expected 60s baseline F06.004"
        )

    def test_heartbeat_interval_reasonable(self) -> None:
        """Heartbeat phải << stale_sec để tránh stale false-positive."""
        # Heartbeat phải fire ít nhất 2 lần trong stale window.
        assert LOCK_HEARTBEAT_INTERVAL_SEC < SIGNALS_LOCK_STALE_SEC / 2, (
            f"Heartbeat {LOCK_HEARTBEAT_INTERVAL_SEC}s phải < half "
            f"stale_sec {SIGNALS_LOCK_STALE_SEC}s"
        )


class TestAcquireRelease:
    """Lock acquire/release lifecycle."""

    def test_acquire_release_basic(self, tmp_path: Path) -> None:
        """Acquire → release: lock dir tạo rồi xóa, heartbeat thread cancel."""
        signals = tmp_path / "signals.json"
        lock_dir = signals.with_suffix(signals.suffix + ".lock")

        assert _signals_lock_acquire(signals, timeout_sec=2) is True
        assert lock_dir.exists(), "Lock dir phải được tạo sau acquire"
        assert str(lock_dir) in _lock_heartbeats, (
            "Heartbeat timer phải được register"
        )

        _signals_lock_release(signals)
        assert not lock_dir.exists(), "Lock dir phải bị xóa sau release"
        assert str(lock_dir) not in _lock_heartbeats, (
            "Heartbeat timer phải được unregister"
        )

    def test_release_idempotent(self, tmp_path: Path) -> None:
        """Release lần 2 không raise — idempotent."""
        signals = tmp_path / "signals.json"
        _signals_lock_acquire(signals, timeout_sec=2)
        _signals_lock_release(signals)
        # Lần 2: lock dir đã không còn, không error
        _signals_lock_release(signals)


class TestStaleTakeover:
    """Stale lock takeover khi writer crash."""

    def test_takeover_when_mtime_old(self, tmp_path: Path) -> None:
        """Mtime > stale_sec → rmdir + retry thành công."""
        signals = tmp_path / "signals.json"
        lock_dir = signals.with_suffix(signals.suffix + ".lock")

        # Simulate orphaned lock (writer crashed)
        lock_dir.parent.mkdir(parents=True, exist_ok=True)
        lock_dir.mkdir()

        # Fake mtime cũ — set ngược 100s (>60s default stale)
        old_mtime = time.time() - 100
        os.utime(lock_dir, (old_mtime, old_mtime))

        # Acquire với stale_sec=60 (default) → takeover phải thành công
        # Cancel heartbeat từ orphan (không có) — không cần
        acquired = _signals_lock_acquire(signals, timeout_sec=2, stale_sec=60)
        assert acquired, "Stale takeover phải thành công khi mtime > 60s"

        _signals_lock_release(signals)

    def test_no_takeover_when_mtime_fresh(self, tmp_path: Path) -> None:
        """Mtime < stale_sec → không takeover, timeout."""
        signals = tmp_path / "signals.json"
        lock_dir = signals.with_suffix(signals.suffix + ".lock")

        # Fresh lock (mtime now)
        lock_dir.parent.mkdir(parents=True, exist_ok=True)
        lock_dir.mkdir()

        # Acquire với short timeout — không takeover vì fresh
        acquired = _signals_lock_acquire(signals, timeout_sec=1, stale_sec=60)
        assert not acquired, (
            "Fresh lock (mtime now) không bị takeover trong 1s timeout"
        )

        # Cleanup
        try:
            lock_dir.rmdir()
        except OSError:
            pass


class TestHeartbeatRefresh:
    """Heartbeat thread refresh mtime."""

    def test_heartbeat_touch_updates_mtime(self, tmp_path: Path) -> None:
        """_heartbeat_touch refresh mtime của lock dir."""
        lock_dir = tmp_path / "test-lock.lock"
        lock_dir.mkdir()

        # Set mtime cũ
        old_mtime = time.time() - 100
        os.utime(lock_dir, (old_mtime, old_mtime))
        assert lock_dir.stat().st_mtime < time.time() - 50

        # Touch — should refresh mtime to ~now (but Timer sẽ re-schedule
        # nên test cần cleanup ngay)
        _heartbeat_touch(lock_dir)

        new_mtime = lock_dir.stat().st_mtime
        assert new_mtime > time.time() - 5, (
            f"Heartbeat phải refresh mtime gần now, got {new_mtime}"
        )

        # Cleanup: cancel timer + remove lock dir
        timer = _lock_heartbeats.pop(str(lock_dir), None)
        if timer is not None:
            timer.cancel()
        lock_dir.rmdir()

    def test_heartbeat_skips_missing_dir(self, tmp_path: Path) -> None:
        """_heartbeat_touch return sớm nếu lock_dir đã bị xóa (post-release)."""
        lock_dir = tmp_path / "missing.lock"
        # Không tạo lock_dir
        _heartbeat_touch(lock_dir)  # Phải return không exception
        # Verify không register timer cho missing dir
        assert str(lock_dir) not in _lock_heartbeats
