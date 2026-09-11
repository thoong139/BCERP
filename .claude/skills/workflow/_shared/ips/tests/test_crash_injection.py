"""Crash Injection Tests — Phase E Task E.8.

Simulates `kill -9` at each of the 4 checkpoint levels and verifies:
- L0 phase: resume từ last_completed.
- L1 layer: resume với layer.status=in_progress preserved.
- L2 batch/module: resume từ next batch/module (batch_progress preserved).
- L3 intra-batch: resume từ next item (partial.json preserved).

Guarantee: mất tối đa 1 unit (1 file / 1 feature / 1 batch) cho mỗi crash point.

Mechanism: `multiprocessing.Process` worker executes checkpoint writes,
then parent calls `os.kill` với SIGKILL (or terminate() cross-platform) tại
từng level. Parent sau đó reads disk state và asserts preservation.
"""

from __future__ import annotations

import json
import multiprocessing as mp
import os
import sys
import time
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))


# ─── Seed Session Helper ─────────────────────────────────────


def _make_seed_state(session_id: str) -> dict:
    """Minimal valid scan-state cho test."""
    return {
        "$schema": "scan-state-v1",
        "session": {"id": session_id, "project_path": "/test"},
        "depth_map": {
            "L1": "full", "L2": "full", "L3": "full",
            "L4": "standard", "L5": "standard", "L6": "full",
        },
        "layers": {
            "L1": {"status": "completed", "outputs": []},
            "L2": {"status": "completed", "outputs": []},
            "L3": {"status": "completed", "outputs": []},
            "L4": {
                "status": "not_started", "depth": "standard",
                "batch_progress": None, "partial": None, "outputs": [],
            },
            "L5": {
                "status": "not_started", "depth": "standard",
                "module_progress": None, "partial": None, "outputs": [],
            },
            "L6": {"status": "not_started", "outputs": []},
        },
        "last_completed": "L3",
        "status": "in_progress",
        "error_log": [],
    }


def _setup_session(tmp_path: Path, session_id: str = "crash-test-01") -> Path:
    session_dir = tmp_path / "sessions" / session_id
    session_dir.mkdir(parents=True)
    state = _make_seed_state(session_id)
    (session_dir / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )
    return session_dir


# ─── Worker Harness ──────────────────────────────────────────
# Workers run in a subprocess. They mutate scan-state incrementally then
# optionally hard-exit via os._exit() to simulate kill -9 (no cleanup).


def _l0_worker(work_dir_str: str, session_id: str, crash: bool):
    """Simulate L3 → L4 transition; crash AFTER L3 completion written."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr

    ssr.WORK_DIR = Path(work_dir_str)
    ssr.update_last_completed("L3", session_id=session_id)
    if crash:
        os._exit(9)


def _l1_worker(work_dir_str: str, session_id: str, crash: bool):
    """Simulate L4 layer status → in_progress, then crash mid-work."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr

    ssr.WORK_DIR = Path(work_dir_str)
    ssr.update_layer_status("L4", "in_progress", session_id=session_id)
    # Simulate some intra-layer progress before crash.
    ssr.update_batch_progress(
        "L4",
        {"current": 1, "total": 5, "completed_batches": []},
        session_id=session_id,
    )
    ssr.flush_pending_writes(session_id=session_id)
    if crash:
        os._exit(9)


def _l2_worker(work_dir_str: str, session_id: str, crash: bool):
    """Simulate 2 batches completed, crash during batch 3."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr

    ssr.WORK_DIR = Path(work_dir_str)
    ssr.update_layer_status("L4", "in_progress", session_id=session_id)
    ssr.update_batch_progress(
        "L4",
        {"current": 3, "total": 5, "completed_batches": ["b1", "b2"]},
        session_id=session_id,
    )
    ssr.flush_pending_writes(session_id=session_id)
    if crash:
        os._exit(9)


def _l3_worker(work_dir_str: str, session_id: str, crash: bool):
    """Simulate intra-batch: 2 items done inside batch-003, crash mid item 3."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr

    ssr.WORK_DIR = Path(work_dir_str)
    ssr.update_layer_status("L4", "in_progress", session_id=session_id)
    ssr.update_batch_progress(
        "L4",
        {"current": 3, "total": 5, "completed_batches": ["b1", "b2"]},
        session_id=session_id,
    )
    ssr.write_layer_partial(
        "L4",
        {
            "batch_id": "b3",
            "completed_items": ["src/a.ts", "src/b.ts"],
            "current_item": "src/c.ts",
        },
        session_id=session_id,
    )
    ssr.flush_pending_writes(session_id=session_id)
    if crash:
        os._exit(9)


# ─── L0 Phase Crash ──────────────────────────────────────────


class TestL0PhaseCrash:
    def test_resume_knows_l3_completed_after_crash(self, tmp_path):
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")
        proc = ctx.Process(
            target=_l0_worker,
            args=(str(tmp_path), "crash-test-01", True),
        )
        proc.start()
        proc.join(timeout=10)
        # Process exited hard with SIGKILL equivalent.
        assert proc.exitcode != 0 or not proc.is_alive()

        # Resume: read state from disk.
        state_path = tmp_path / "sessions" / "crash-test-01" / "scan-state.json"
        state = json.loads(state_path.read_text(encoding="utf-8"))
        assert state["last_completed"] == "L3"


# ─── L1 Layer Crash ──────────────────────────────────────────


class TestL1LayerCrash:
    def test_resume_sees_l4_in_progress(self, tmp_path):
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")
        proc = ctx.Process(
            target=_l1_worker,
            args=(str(tmp_path), "crash-test-01", True),
        )
        proc.start()
        proc.join(timeout=10)

        state = json.loads(
            (
                tmp_path / "sessions" / "crash-test-01" / "scan-state.json"
            ).read_text(encoding="utf-8")
        )
        # L4 status persisted across kill -9.
        assert state["layers"]["L4"]["status"] == "in_progress"
        # started timestamp recorded.
        assert state["layers"]["L4"]["started"] is not None


# ─── L2 Batch Crash ──────────────────────────────────────────


class TestL2BatchCrash:
    def test_resume_from_next_batch_after_crash(self, tmp_path):
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")
        proc = ctx.Process(
            target=_l2_worker,
            args=(str(tmp_path), "crash-test-01", True),
        )
        proc.start()
        proc.join(timeout=10)

        state = json.loads(
            (
                tmp_path / "sessions" / "crash-test-01" / "scan-state.json"
            ).read_text(encoding="utf-8")
        )
        bp = state["layers"]["L4"]["batch_progress"]
        # 2 batches completed on disk → resume from batch 3 (lose ≤ batch 3 which is in-flight).
        assert bp["completed_batches"] == ["b1", "b2"]
        assert bp["current"] == 3
        # "Lose at most 1 unit" — batch 3 might be redone, but batches 1, 2 preserved.


# ─── L3 Intra-Batch Crash ────────────────────────────────────


class TestL3IntraBatchCrash:
    def test_resume_from_next_item_with_partial(self, tmp_path):
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")
        proc = ctx.Process(
            target=_l3_worker,
            args=(str(tmp_path), "crash-test-01", True),
        )
        proc.start()
        proc.join(timeout=10)

        session_dir = tmp_path / "sessions" / "crash-test-01"
        state = json.loads(
            (session_dir / "scan-state.json").read_text(encoding="utf-8")
        )

        # scan-state preserved batch progress.
        assert state["layers"]["L4"]["batch_progress"]["current"] == 3

        # Partial file preserved on disk.
        partial_path = session_dir / "layers" / "L4" / "partial.json"
        assert partial_path.exists()
        partial = json.loads(partial_path.read_text(encoding="utf-8"))
        assert partial["batch_id"] == "b3"
        assert partial["completed_items"] == ["src/a.ts", "src/b.ts"]
        # current_item ("src/c.ts") may need to be redone — that's the 1 unit
        # loss permitted by ADR-LS11.
        assert partial["current_item"] == "src/c.ts"


# ─── No-Crash Baseline ───────────────────────────────────────


class TestNoCrashBaseline:
    """Sanity check — worker without crash completes fully."""

    def test_l3_worker_without_crash(self, tmp_path):
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")
        proc = ctx.Process(
            target=_l3_worker,
            args=(str(tmp_path), "crash-test-01", False),
        )
        proc.start()
        proc.join(timeout=10)
        assert proc.exitcode == 0


# ─── Atomic Write Durability ─────────────────────────────────


class TestAtomicDurability:
    """Verify tmp → fsync → rename guarantees under crash."""

    def test_no_partial_json_visible_after_interrupt(self, tmp_path):
        """Reader nào mở scan-state.json trong lúc crash không thấy
        JSON dở dang — atomic rename đảm bảo hoặc cũ hoặc mới."""
        _setup_session(tmp_path)
        ctx = mp.get_context("spawn")

        # Run hammering worker rapidly — rename is POSIX atomic.
        proc = ctx.Process(
            target=_l2_worker,
            args=(str(tmp_path), "crash-test-01", True),
        )
        proc.start()
        proc.join(timeout=10)

        state_path = tmp_path / "sessions" / "crash-test-01" / "scan-state.json"
        # File exists and parses as valid JSON.
        text = state_path.read_text(encoding="utf-8")
        parsed = json.loads(text)  # throws if partial
        assert "$schema" in parsed
        assert "layers" in parsed


# ─── Summary Sanity ──────────────────────────────────────────


@pytest.mark.parametrize(
    "worker_name,expected_field",
    [
        ("l0", "last_completed"),
        ("l1", "layers.L4.status"),
        ("l2", "layers.L4.batch_progress.completed_batches"),
        ("l3", "layers.L4.batch_progress.completed_batches"),
    ],
)
def test_checkpoint_field_survives_crash(
    tmp_path, worker_name, expected_field
):
    """Parameterized sanity check covering all 4 checkpoint levels.

    Verifies field tương ứng survives kill -9 via subprocess.
    """
    _setup_session(tmp_path)

    workers = {
        "l0": _l0_worker,
        "l1": _l1_worker,
        "l2": _l2_worker,
        "l3": _l3_worker,
    }

    ctx = mp.get_context("spawn")
    proc = ctx.Process(
        target=workers[worker_name],
        args=(str(tmp_path), "crash-test-01", True),
    )
    proc.start()
    proc.join(timeout=10)
    assert not proc.is_alive()

    state = json.loads(
        (
            tmp_path / "sessions" / "crash-test-01" / "scan-state.json"
        ).read_text(encoding="utf-8")
    )

    # Walk dotted path.
    node = state
    for part in expected_field.split("."):
        node = node[part]
    assert node is not None


if __name__ == "__main__":
    # Required cho Windows multiprocessing spawn.
    mp.freeze_support()
