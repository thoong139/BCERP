"""test_signal_bus_flush_lock_f06_012.py — F06.012 (Sprint 6) flush() cross-process lock.

Verify:
- _acquire_flush_lock / _release_flush_lock lifecycle
- Stale takeover khi mtime > _FLUSH_LOCK_STALE_SEC
- _merge_with_disk_state chống Lost Update (Process A flush sau B
  không overwrite B's issues nếu chưa có trong buffer A)
- Concurrent flush: 2 bus instances cùng session → cả 2 issues persist

Note: Tests sequence được lock chia sẻ thay vì spawn process thật — đủ
verify logic của _merge_with_disk_state.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import pytest

from signal_bus.signal_bus import SignalBus


@pytest.fixture
def session(tmp_path: Path) -> Path:
    """Empty session directory."""
    return tmp_path / "session"


def _make_signal(probe_id: str, file_path: str, line: int = 10) -> dict:
    """Build minimal signal-v2 dict cho ingest."""
    return {
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": "2026-05-15T00:00:00+00:00",
        "lane": "wf-fix-functional",
        "dimension_id": "QD1",
        "target": {
            "kind": "code",
            "file_path": file_path,
            "line_range": [line, line + 5],
            "symbol": "fn",
        },
        "description": "Bug description with enough text for ADR-09 evidence rule",
        "evidence": {"code_snippet": "// hardcoded bug snippet sample text"},
    }


class TestFlushLockLifecycle:
    """Lock acquire/release cơ bản."""

    def test_acquire_release_basic(self, session: Path) -> None:
        """Acquire → release tạo và xóa lock dir."""
        session.mkdir(parents=True, exist_ok=True)
        bus = SignalBus(session)
        lock_dir = bus.registry_path.with_suffix(bus.registry_path.suffix + ".lock")

        assert bus._acquire_flush_lock() is True
        assert lock_dir.exists()
        bus._release_flush_lock()
        assert not lock_dir.exists()

    def test_concurrent_acquire_blocks(self, session: Path) -> None:
        """2 bus cùng session: bus2 acquire trong khi bus1 đang giữ → timeout."""
        session.mkdir(parents=True, exist_ok=True)
        bus1 = SignalBus(session)
        bus2 = SignalBus(session)

        assert bus1._acquire_flush_lock() is True
        try:
            # Override timeout ngắn để test nhanh
            bus2._FLUSH_LOCK_TIMEOUT_SEC = 1
            assert bus2._acquire_flush_lock() is False
        finally:
            bus1._release_flush_lock()


class TestFlushLockStale:
    """Stale takeover."""

    def test_stale_takeover_when_mtime_old(self, session: Path) -> None:
        """Bus1 crash giữ lock → bus2 acquire phải takeover sau stale."""
        session.mkdir(parents=True, exist_ok=True)
        bus1 = SignalBus(session)
        bus2 = SignalBus(session)

        # Simulate bus1 acquired then crashed (lock orphaned)
        bus1._acquire_flush_lock()
        # Fake mtime cũ
        lock_dir = bus1.registry_path.with_suffix(bus1.registry_path.suffix + ".lock")
        old_mtime = time.time() - 100  # > 60s stale default
        os.utime(lock_dir, (old_mtime, old_mtime))

        # Bus2 acquire → stale takeover
        assert bus2._acquire_flush_lock() is True
        bus2._release_flush_lock()


class TestMergeWithDiskState:
    """F06.012: _merge_with_disk_state chống Lost Update."""

    def test_merge_picks_up_concurrent_disk_issues(self, session: Path) -> None:
        """Process A có buffer 1 issue; disk có 1 issue mới từ Process B
        flush trước. Merge phải pick up cả 2 issues vào A buffer.
        """
        session.mkdir(parents=True, exist_ok=True)
        bus_a = SignalBus(session)
        bus_a.load_existing()
        bus_a.ingest(_make_signal("P-QD1-bug-a", "a.ts"))
        # Buffer A: 1 issue (key="a.ts:...")

        # Simulate B flush (write disk independently)
        bus_b = SignalBus(session)
        bus_b.load_existing()
        bus_b.ingest(_make_signal("P-QD1-bug-b", "b.ts"))
        bus_b.flush()
        # Disk có 1 issue từ B

        # Reload bus_a state từ disk
        bus_a._merge_with_disk_state()
        # Buffer A giờ phải có 2 issues (A + B)
        keys = {it.dedup_key for it in bus_a._issues}
        assert len(bus_a._issues) == 2, (
            f"Sau merge với disk state, buffer A phải có 2 issues, "
            f"got {len(bus_a._issues)}: {keys}"
        )

    def test_merge_no_op_when_disk_missing(self, session: Path) -> None:
        """Disk chưa có registry → merge no-op."""
        session.mkdir(parents=True, exist_ok=True)
        bus = SignalBus(session)
        bus.load_existing()
        bus.ingest(_make_signal("P-QD1-bug-x", "x.ts"))
        bus._merge_with_disk_state()
        assert len(bus._issues) == 1

    def test_merge_keeps_buffer_version_on_conflict(self, session: Path) -> None:
        """Dedup_key conflict: disk version bị bỏ, buffer version giữ."""
        session.mkdir(parents=True, exist_ok=True)
        # Setup: disk có 1 issue
        bus_first = SignalBus(session)
        bus_first.load_existing()
        bus_first.ingest(_make_signal("P-QD1-bug-a", "a.ts", line=10))
        bus_first.flush()

        # Buffer A reload từ disk → có 1 issue
        bus_a = SignalBus(session)
        bus_a.load_existing()
        original_count = len(bus_a._issues)
        # Re-merge: disk = same issue → không append duplicate
        bus_a._merge_with_disk_state()
        assert len(bus_a._issues) == original_count, (
            "Cùng dedup_key không append duplicate"
        )


class TestConcurrentFlushIntegrity:
    """End-to-end: 2 flush sequential nhưng không cùng load_existing()."""

    def test_b_flush_after_a_flush_preserves_a_issues(self, session: Path) -> None:
        """Process A flush, then Process B (started before A flush) flush.
        B flush phải preserve A's issues (không Lost Update).

        Without F06.012: B reload buffer cũ → flush ghi đè A.
        With F06.012: B._merge_with_disk_state() trước flush → bao gồm A.
        """
        session.mkdir(parents=True, exist_ok=True)

        # Cả 2 bus load_existing từ empty state
        bus_a = SignalBus(session)
        bus_a.load_existing()
        bus_b = SignalBus(session)
        bus_b.load_existing()

        # A ingest + flush
        bus_a.ingest(_make_signal("P-QD1-bug-a", "a.ts"))
        bus_a.flush()

        # B ingest (B vẫn dùng buffer cũ — empty) + flush
        bus_b.ingest(_make_signal("P-QD1-bug-b", "b.ts"))
        bus_b.flush()

        # Disk phải có CẢ 2 issues
        data = json.loads(bus_b.registry_path.read_text(encoding="utf-8"))
        keys = {it["dedup_key"] for it in data["issues"]}
        assert len(data["issues"]) == 2, (
            f"Sau A.flush + B.flush, disk phải có 2 issues, "
            f"got {len(data['issues'])}: {keys}"
        )
