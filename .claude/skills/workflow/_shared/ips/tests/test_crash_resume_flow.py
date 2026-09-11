"""Crash + Resume Flow Integration Tests — Phase H Task H.4 (Tier 1).

Combines Phase E crash injection + Phase H Resume Router. For each of the
4 checkpoint levels, verifies:

  1. Worker mutates scan-state.json incrementally.
  2. Worker hard-exits via os._exit(9) (kill -9 equivalent).
  3. After crash, scan-state.json on disk is valid + atomic (Phase E).
  4. Resume Router reads the disk state and returns the CORRECT
     action_type + resume_unit (Phase H).

Coverage — 4 crash levels × 3 scenarios = 12 parameterized cases:

| Level | Scenario A (basic)  | Scenario B (mid-way) | Scenario C (near-end) |
|-------|---------------------|----------------------|-----------------------|
| L0    | crash after L1 done | crash after L2 done  | crash after L3 done   |
| L1    | L4 just started     | L4 mid-batch 2/5     | L4 near-end batch 5/5 |
| L2    | L5 module 1 of 8    | L5 module 4 of 8     | L5 module 7 of 8      |
| L3    | L4 partial, 1 done  | L4 partial, 5 done   | L5 partial, 3 done    |

Maps directly to the phase-H.md H.4 matrix (4 levels × 3 fixtures) without
requiring A.3 fixture baselines (deferred parallel per MIGRATION-PROGRESS.md).
Tier 2 E2E (actual /wf-legacy-scan invocation on small-en/medium-vn/large-mixed
fixtures) is BLOCKED until A.3 completes — documented in
legacy-scan-phase-h-resume-test.sh.

Reference:
- docs/design/skills/wf-legacy-scan/implementation/phases/phase-H-resume-routing.md
- docs/design/skills/wf-legacy-scan/03-architecture.md §2.2 routing table
- Phase E crash primitives: test_crash_injection.py
"""

from __future__ import annotations

import json
import multiprocessing as mp
import os
import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import resume_router as rr  # noqa: E402
from ips import scan_state_reader as ssr  # noqa: E402


# ─── Seed helpers ────────────────────────────────────────────


def _seed_state(session_id: str, last_completed: str = "L3") -> dict:
    """Build a minimal valid scan-state with all 6 layers populated."""
    return {
        "$schema": "scan-state-v1",
        "session": {
            "id": session_id,
            "project_path": "/test",
            "profile": "standard",
            "strategy": "S2",
        },
        "depth_map": {
            "L1": "full", "L2": "full", "L3": "full",
            "L4": "standard", "L5": "standard", "L6": "full",
        },
        "synthesis_mode": "full",
        "layers": {
            "L1": {"name": "discovery", "status": "completed", "outputs": []},
            "L2": {"name": "assessment", "status": "completed", "outputs": []},
            "L3": {"name": "inventory", "status": "completed", "outputs": []},
            "L4": {
                "name": "classification", "status": "not_started",
                "depth": "standard", "batch_progress": None,
                "partial": None, "outputs": [],
            },
            "L5": {
                "name": "extraction", "status": "not_started",
                "depth": "standard", "module_progress": None,
                "partial": None, "outputs": [],
            },
            "L6": {"name": "synthesis", "status": "not_started",
                   "synthesis_mode": "full", "outputs": []},
        },
        "ips": {"phase_a": None, "phase_b": None},
        "last_completed": last_completed,
        "status": "in_progress",
        "error_log": [],
    }


def _setup_session(
    tmp_path: Path,
    session_id: str,
    last_completed: str = "L3",
) -> Path:
    """Write seed scan-state.json cho a session. Overrides top-level layers
    nếu caller muốn custom starting state (cascade from last_completed)."""
    session_dir = tmp_path / "sessions" / session_id
    session_dir.mkdir(parents=True)
    state = _seed_state(session_id, last_completed=last_completed)

    # Auto-set earlier layers to completed based on last_completed.
    order = ["L1", "L2", "L3", "L4", "L5", "L6"]
    if last_completed in order:
        idx = order.index(last_completed)
        for lid in order[: idx + 1]:
            state["layers"][lid]["status"] = "completed"

    (session_dir / "scan-state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )
    return session_dir


# ─── Workers — subprocess mutators that crash via os._exit(9) ─


def _l0_worker_variant(
    work_dir_str: str, session_id: str, target_layer: str
) -> None:
    """L0 phase crash — mark target_layer as last_completed then crash."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr_worker

    ssr_worker.WORK_DIR = Path(work_dir_str)
    ssr_worker.update_last_completed(target_layer, session_id=session_id)
    os._exit(9)


def _l1_worker_variant(
    work_dir_str: str, session_id: str,
    current_batch: int, total_batches: int,
) -> None:
    """L1 layer crash — set L4 in_progress + batch_progress directly via
    atomic state write (bypass state machine for test setup), crash mid-work."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr_worker

    ssr_worker.WORK_DIR = Path(work_dir_str)
    session_dir = Path(work_dir_str) / "sessions" / session_id

    state = ssr_worker.read_scan_state(session_id=session_id)
    state["layers"]["L4"]["status"] = "in_progress"
    state["layers"]["L4"]["started"] = ssr_worker._now_iso()  # type: ignore[attr-defined]
    state["layers"]["L4"]["batch_progress"] = {
        "current": current_batch,
        "total": total_batches,
        "completed_batches": [f"b{i}" for i in range(1, current_batch)],
    }
    # last_completed stays "L3" — L4 not yet complete.
    ssr_worker._atomic_write_state(session_dir, state, force=True)  # type: ignore[attr-defined]
    os._exit(9)


def _l2_worker_variant(
    work_dir_str: str, session_id: str,
    current_module: str, total_modules: int, completed: list[str],
) -> None:
    """L2 batch/module crash — L4 completed, L5 mid-way through modules."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr_worker

    ssr_worker.WORK_DIR = Path(work_dir_str)
    session_dir = Path(work_dir_str) / "sessions" / session_id

    state = ssr_worker.read_scan_state(session_id=session_id)
    # Mark L4 complete.
    state["layers"]["L4"]["status"] = "completed"
    state["layers"]["L4"]["completed"] = ssr_worker._now_iso()  # type: ignore[attr-defined]
    # Mark L5 in_progress with module_progress.
    state["layers"]["L5"]["status"] = "in_progress"
    state["layers"]["L5"]["started"] = ssr_worker._now_iso()  # type: ignore[attr-defined]
    state["layers"]["L5"]["module_progress"] = {
        "current": current_module,
        "total": total_modules,
        "completed_modules": completed,
    }
    state["last_completed"] = "L4"
    ssr_worker._atomic_write_state(session_dir, state, force=True)  # type: ignore[attr-defined]
    os._exit(9)


def _l3_worker_variant(
    work_dir_str: str, session_id: str,
    layer: str, completed_items: list[str], current_item: str,
) -> None:
    """L3 intra-batch/module crash — partial.json written for L4 or L5."""
    sys.path.insert(0, str(_SHARED_ROOT))
    from ips import scan_state_reader as ssr_worker

    ssr_worker.WORK_DIR = Path(work_dir_str)
    session_dir = Path(work_dir_str) / "sessions" / session_id

    state = ssr_worker.read_scan_state(session_id=session_id)
    if layer == "L4":
        state["layers"]["L4"]["status"] = "in_progress"
        state["layers"]["L4"]["batch_progress"] = {
            "current": "batch-003",
            "total": 5,
            "completed_batches": ["batch-001", "batch-002"],
        }
        partial_key = "batch_id"
        partial_val = "batch-003"
    else:  # L5
        state["layers"]["L4"]["status"] = "completed"
        state["layers"]["L5"]["status"] = "in_progress"
        state["layers"]["L5"]["module_progress"] = {
            "current": "billing",
            "total": 5,
            "completed_modules": ["auth", "users"],
        }
        state["last_completed"] = "L4"
        partial_key = "module"
        partial_val = "billing"

    ssr_worker._atomic_write_state(session_dir, state, force=True)  # type: ignore[attr-defined]

    # Now write partial.json via normal API.
    ssr_worker.write_layer_partial(
        layer,
        {
            partial_key: partial_val,
            "completed_items": completed_items,
            "current_item": current_item,
        },
        session_id=session_id,
    )
    ssr_worker.flush_pending_writes(session_id=session_id)
    os._exit(9)


# ─── Test harness ────────────────────────────────────────────


def _run_worker(worker, args, timeout: float = 10.0) -> None:
    """Spawn worker in subprocess, wait for crash."""
    ctx = mp.get_context("spawn")
    proc = ctx.Process(target=worker, args=args)
    proc.start()
    proc.join(timeout=timeout)
    assert not proc.is_alive(), "Worker did not exit within timeout"
    assert proc.exitcode != 0, "Expected crash exit code"


def _route_after_crash(
    tmp_path: Path, session_id: str, monkeypatch
) -> dict:
    """Read disk state + run Resume Router in parent process."""
    monkeypatch.setattr(ssr, "WORK_DIR", tmp_path)
    ssr._reset_throttle_state()  # type: ignore[attr-defined]
    return rr.route_resume(session_id=session_id)


# ─── L0 Phase Crash × 3 scenarios ────────────────────────────


class TestL0CrashResumeFlow:
    """L0 = phase checkpoint (last_completed field only)."""

    @pytest.mark.parametrize(
        "seed_state,crash_layer,expected_action",
        [
            # Scenario A: crash after L1 done → next start_L2.
            ("init", "L1", rr.ACTION_START_L2),
            # Scenario B: crash after L2 done → next start_L3.
            ("L1", "L2", rr.ACTION_START_L3),
            # Scenario C: crash after L3 done → next start_L4.
            ("L2", "L3", rr.ACTION_START_L4),
        ],
    )
    def test_l0_phase_resume(
        self,
        tmp_path,
        monkeypatch,
        seed_state: str,
        crash_layer: str,
        expected_action: str,
    ) -> None:
        session_id = f"l0-crash-{crash_layer}"
        _setup_session(tmp_path, session_id, last_completed=seed_state)

        _run_worker(_l0_worker_variant, (str(tmp_path), session_id, crash_layer))

        action = _route_after_crash(tmp_path, session_id, monkeypatch)
        assert action["action_type"] == expected_action, (
            f"L0 crash after {crash_layer}: expected {expected_action}, "
            f"got {action['action_type']}. Notes: {action['notes']}"
        )
        assert action["last_completed"] == crash_layer


# ─── L1 Layer Crash × 3 scenarios ────────────────────────────


class TestL1CrashResumeFlow:
    """L1 = layer status (L4 in_progress + batch_progress.current)."""

    @pytest.mark.parametrize(
        "current_batch,total,description",
        [
            (1, 5, "just-started (batch 1 of 5)"),
            (3, 5, "mid-way (batch 3 of 5)"),
            (5, 5, "near-end (batch 5 of 5)"),
        ],
    )
    def test_l1_layer_resume_from_batch(
        self,
        tmp_path,
        monkeypatch,
        current_batch: int,
        total: int,
        description: str,
    ) -> None:
        session_id = f"l1-crash-b{current_batch}"
        _setup_session(tmp_path, session_id, last_completed="L3")

        _run_worker(
            _l1_worker_variant,
            (str(tmp_path), session_id, current_batch, total),
        )

        action = _route_after_crash(tmp_path, session_id, monkeypatch)
        # L4 in_progress, no partial → batch-level resume.
        assert action["action_type"] == rr.ACTION_RESUME_L4_BATCH, description
        assert action["resume_unit"]["current_batch"] == current_batch
        assert action["resume_unit"]["total_batches"] == total
        # Completed batches preserved.
        assert len(action["resume_unit"]["completed_batches"]) == current_batch - 1


# ─── L2 Batch/Module Crash × 3 scenarios ─────────────────────


class TestL2CrashResumeFlow:
    """L2 = batch/module progress granularity (inter-batch L4, inter-module L5)."""

    @pytest.mark.parametrize(
        "current_module,total,completed,description",
        [
            ("billing", 8, [], "module 1 of 8 — just started"),
            ("billing", 8,
             ["auth", "users", "orders"], "module 4 of 8 — mid-way"),
            ("billing", 8,
             ["auth", "users", "orders", "payments",
              "products", "inventory"], "module 7 of 8 — near-end"),
        ],
    )
    def test_l2_module_resume(
        self,
        tmp_path,
        monkeypatch,
        current_module: str,
        total: int,
        completed: list[str],
        description: str,
    ) -> None:
        session_id = f"l2-crash-{len(completed)}"
        _setup_session(tmp_path, session_id, last_completed="L3")

        _run_worker(
            _l2_worker_variant,
            (str(tmp_path), session_id, current_module, total, completed),
        )

        action = _route_after_crash(tmp_path, session_id, monkeypatch)
        assert action["action_type"] == rr.ACTION_RESUME_L5_MODULE, description
        assert action["resume_unit"]["current_module"] == current_module
        assert action["resume_unit"]["completed_modules"] == completed
        assert action["resume_unit"]["total_modules"] == total


# ─── L3 Intra-Batch/Module Crash × 3 scenarios ───────────────


class TestL3CrashResumeFlow:
    """L3 = intra-batch (L4) / intra-module (L5) — partial.json preserved."""

    @pytest.mark.parametrize(
        "layer,completed,current,expected_action,description",
        [
            # Scenario A: L4 intra-batch, 1 item done.
            ("L4", ["src/a.ts"], "src/b.ts",
             rr.ACTION_RESUME_L4_INTRA_BATCH, "L4 intra-batch 1 done"),
            # Scenario B: L4 intra-batch, 5 items done (mid-batch).
            ("L4",
             ["src/a.ts", "src/b.ts", "src/c.ts", "src/d.ts", "src/e.ts"],
             "src/f.ts",
             rr.ACTION_RESUME_L4_INTRA_BATCH, "L4 intra-batch 5 done"),
            # Scenario C: L5 intra-module, 3 features done.
            ("L5", ["feat-1", "feat-2", "feat-3"], "feat-4",
             rr.ACTION_RESUME_L5_INTRA_MODULE, "L5 intra-module 3 done"),
        ],
    )
    def test_l3_intra_batch_resume(
        self,
        tmp_path,
        monkeypatch,
        layer: str,
        completed: list[str],
        current: str,
        expected_action: str,
        description: str,
    ) -> None:
        session_id = f"l3-crash-{layer}-{len(completed)}"
        _setup_session(tmp_path, session_id, last_completed="L3")

        _run_worker(
            _l3_worker_variant,
            (str(tmp_path), session_id, layer, completed, current),
        )

        action = _route_after_crash(tmp_path, session_id, monkeypatch)
        assert action["action_type"] == expected_action, description
        assert action["resume_unit"]["layer"] == layer
        assert action["resume_unit"]["completed_items"] == completed
        assert action["resume_unit"]["in_flight_item"] == current


# ─── Summary: 12 test cases across 4 levels ──────────────────


def test_h4_summary_12_cases():
    """Sanity marker — phase-H.md H.4 requires 4 levels × 3 scenarios = 12 cases.

    Asserts class structure is complete (no scenario dropped).
    """
    import inspect

    cases_per_class = {
        TestL0CrashResumeFlow: 3,
        TestL1CrashResumeFlow: 3,
        TestL2CrashResumeFlow: 3,
        TestL3CrashResumeFlow: 3,
    }
    total = 0
    for cls, expected in cases_per_class.items():
        methods = [
            name
            for name, _ in inspect.getmembers(cls, inspect.isfunction)
            if name.startswith("test_")
        ]
        # parametrize expands at collection time — count via parametrize marks.
        for meth_name in methods:
            meth = getattr(cls, meth_name)
            marks = getattr(meth, "pytestmark", [])
            for mark in marks:
                if mark.name == "parametrize":
                    # Count scenarios.
                    scenarios = len(mark.args[1])
                    total += scenarios
    assert total == 12, f"Expected 12 scenarios total, got {total}"


if __name__ == "__main__":
    mp.freeze_support()
