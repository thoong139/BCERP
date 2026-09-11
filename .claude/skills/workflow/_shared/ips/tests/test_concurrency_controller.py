"""Tests for concurrency_controller.py — Phase E Task E.3.

Coverage:
- Basic acquire/release sequential.
- 3-tier caps enforced (global, per_layer, per_probe).
- Reserved slots cho synthesis (L6 only).
- Timeout behavior (non-blocking + bounded wait).
- Idempotent release (double-release OK).
- Double-acquire detection.
- Parallel spawn stress test respects caps.
- Singleton helper.
"""

from __future__ import annotations

import sys
import threading
import time
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import concurrency_controller as cc  # noqa: E402


# ─── Basic Acquire/Release ───────────────────────────────────


class TestBasicAcquireRelease:
    def test_single_acquire_release(self):
        ctrl = cc.ConcurrencyController()
        assert ctrl.acquire("L4", "p.1", "agent-1", timeout_sec=0) is True
        status = ctrl.status()
        assert status["global_in_use"] == 1
        assert status["per_layer"]["L4"] == 1
        assert status["per_probe"]["p.1"] == 1

        ctrl.release("L4", "p.1", "agent-1")
        status = ctrl.status()
        assert status["global_in_use"] == 0
        assert status["per_layer"]["L4"] == 0
        assert status["per_probe"]["p.1"] == 0

    def test_double_acquire_same_key_raises(self):
        ctrl = cc.ConcurrencyController()
        ctrl.acquire("L4", "p.1", "agent-1", timeout_sec=0)
        with pytest.raises(ValueError, match="already active"):
            ctrl.acquire("L4", "p.1", "agent-1", timeout_sec=0)

    def test_release_idempotent_double_release(self):
        ctrl = cc.ConcurrencyController()
        ctrl.acquire("L4", "p.1", "agent-1", timeout_sec=0)
        ctrl.release("L4", "p.1", "agent-1")
        # Second release is no-op.
        ctrl.release("L4", "p.1", "agent-1")
        assert ctrl.status()["global_in_use"] == 0

    def test_release_unknown_key_noop(self):
        ctrl = cc.ConcurrencyController()
        ctrl.release("L4", "p.1", "never-acquired")
        assert ctrl.status()["global_in_use"] == 0


# ─── Cap Enforcement ─────────────────────────────────────────


class TestGlobalCap:
    def test_global_max_minus_reserved_for_non_synthesis(self):
        """Non-L6 layer chỉ dùng được global_max - reserved."""
        ctrl = cc.ConcurrencyController(
            global_max=5, per_layer_max=10, per_probe_max=10, reserved_for_synthesis=2
        )
        # Can acquire 3 (5 - 2 reserved).
        for i in range(3):
            assert ctrl.acquire("L4", f"probe-{i}", f"a-{i}", timeout_sec=0)
        # 4th non-synthesis blocked.
        assert ctrl.acquire("L4", "probe-x", "a-x", timeout_sec=0) is False

    def test_reserved_usable_by_synthesis(self):
        """L6 có thể tiêu toàn bộ global_max incl. reserved."""
        ctrl = cc.ConcurrencyController(
            global_max=4, per_layer_max=10, per_probe_max=10, reserved_for_synthesis=2
        )
        # L4 (non-synthesis) bounded at 2 (4 - 2).
        assert ctrl.acquire("L4", "p", "a1", timeout_sec=0)
        assert ctrl.acquire("L4", "p2", "a2", timeout_sec=0)
        assert ctrl.acquire("L4", "p3", "a3", timeout_sec=0) is False
        # L6 có thể acquire 2 slots (đủ ko có slot cho L4).
        assert ctrl.acquire("L6", "syn", "s1", timeout_sec=0)
        assert ctrl.acquire("L6", "syn2", "s2", timeout_sec=0)
        # 5th không thể — global_max=4.
        assert ctrl.acquire("L6", "syn3", "s3", timeout_sec=0) is False


class TestPerLayerCap:
    def test_per_layer_max_enforced(self):
        ctrl = cc.ConcurrencyController(
            global_max=20, per_layer_max=2, per_probe_max=10
        )
        assert ctrl.acquire("L4", "p1", "a1", timeout_sec=0)
        assert ctrl.acquire("L4", "p2", "a2", timeout_sec=0)
        # 3rd on L4 blocked.
        assert ctrl.acquire("L4", "p3", "a3", timeout_sec=0) is False
        # Other layer OK.
        assert ctrl.acquire("L5", "p4", "a4", timeout_sec=0)


class TestPerProbeCap:
    def test_per_probe_max_enforced(self):
        ctrl = cc.ConcurrencyController(
            global_max=20, per_layer_max=10, per_probe_max=2
        )
        assert ctrl.acquire("L4", "shared-probe", "a1", timeout_sec=0)
        assert ctrl.acquire("L4", "shared-probe", "a2", timeout_sec=0)
        # 3rd on same probe blocked.
        assert ctrl.acquire("L4", "shared-probe", "a3", timeout_sec=0) is False
        # Different probe OK.
        assert ctrl.acquire("L4", "other-probe", "a4", timeout_sec=0)


# ─── Timeout Behavior ────────────────────────────────────────


class TestTimeout:
    def test_non_blocking_returns_false_immediately(self):
        ctrl = cc.ConcurrencyController(
            global_max=1, reserved_for_synthesis=0
        )
        ctrl.acquire("L4", "p", "a1", timeout_sec=0)
        start = time.monotonic()
        result = ctrl.acquire("L4", "p2", "a2", timeout_sec=0)
        elapsed = time.monotonic() - start
        assert result is False
        assert elapsed < 0.1  # truly non-blocking

    def test_bounded_wait_returns_false_at_deadline(self):
        ctrl = cc.ConcurrencyController(
            global_max=1, reserved_for_synthesis=0
        )
        ctrl.acquire("L4", "p", "a1", timeout_sec=0)
        start = time.monotonic()
        result = ctrl.acquire("L4", "p2", "a2", timeout_sec=0.3)
        elapsed = time.monotonic() - start
        assert result is False
        # Should wait ~0.3s (not block forever, not return immediately).
        assert 0.25 <= elapsed < 1.0

    def test_release_wakes_waiter(self):
        """A blocked acquire succeeds once a release fires."""
        ctrl = cc.ConcurrencyController(
            global_max=1, reserved_for_synthesis=0
        )
        ctrl.acquire("L4", "p", "a1", timeout_sec=0)

        result = {"value": None, "elapsed": None}

        def waiter():
            start = time.monotonic()
            result["value"] = ctrl.acquire(
                "L4", "p2", "a2", timeout_sec=2.0
            )
            result["elapsed"] = time.monotonic() - start

        t = threading.Thread(target=waiter)
        t.start()

        # Wait until waiter is blocked.
        time.sleep(0.1)
        ctrl.release("L4", "p", "a1")
        t.join(timeout=2)

        assert result["value"] is True
        assert result["elapsed"] < 1.0  # woke promptly after release


# ─── Parallel Stress ────────────────────────────────────────


class TestParallelStress:
    def test_global_cap_never_exceeded(self):
        """20 threads spawn — global_max=4 never exceeded."""
        ctrl = cc.ConcurrencyController(
            global_max=4,
            per_layer_max=10,
            per_probe_max=10,
            reserved_for_synthesis=0,
        )

        peak = {"value": 0}
        peak_lock = threading.Lock()
        started = threading.Event()
        release_gate = threading.Event()

        def worker(idx):
            key = f"a-{idx}"
            if not ctrl.acquire("L4", f"p-{idx}", key, timeout_sec=5.0):
                return
            try:
                with peak_lock:
                    peak["value"] = max(
                        peak["value"], ctrl.status()["global_in_use"]
                    )
                started.set()
                release_gate.wait(timeout=2.0)
            finally:
                ctrl.release("L4", f"p-{idx}", key)

        threads = [
            threading.Thread(target=worker, args=(i,)) for i in range(20)
        ]
        for t in threads:
            t.start()

        # Wait for first batch to acquire.
        started.wait(timeout=2.0)
        time.sleep(0.1)
        # Peak should reflect the cap.
        assert 1 <= peak["value"] <= 4

        release_gate.set()
        for t in threads:
            t.join(timeout=5.0)
            assert not t.is_alive(), "worker deadlocked"

        # All released.
        assert ctrl.status()["global_in_use"] == 0
        # Peak must respect cap.
        assert peak["value"] <= 4


# ─── Status / Monitoring ─────────────────────────────────────


class TestStatus:
    def test_status_reflects_active_agents(self):
        ctrl = cc.ConcurrencyController()
        ctrl.acquire("L4", "probe.a", "agent-1", timeout_sec=0)
        ctrl.acquire("L5", "probe.b", "agent-2", timeout_sec=0)
        s = ctrl.status()
        keys = {a["key"] for a in s["active_agents"]}
        assert keys == {"agent-1", "agent-2"}
        # held_sec present and non-negative.
        for agent in s["active_agents"]:
            assert agent["held_sec"] >= 0

    def test_active_keys_listing(self):
        ctrl = cc.ConcurrencyController()
        assert ctrl.active_keys() == []
        ctrl.acquire("L4", "p", "k1", timeout_sec=0)
        ctrl.acquire("L5", "p", "k2", timeout_sec=0)
        assert set(ctrl.active_keys()) == {"k1", "k2"}


# ─── Validation ──────────────────────────────────────────────


class TestValidation:
    def test_invalid_global_max_raises(self):
        with pytest.raises(ValueError):
            cc.ConcurrencyController(global_max=0)

    def test_invalid_reserved_raises(self):
        with pytest.raises(ValueError):
            cc.ConcurrencyController(
                global_max=4, reserved_for_synthesis=4
            )
        with pytest.raises(ValueError):
            cc.ConcurrencyController(
                global_max=4, reserved_for_synthesis=-1
            )


# ─── Singleton ───────────────────────────────────────────────


class TestSingleton:
    def test_get_default_returns_same_instance(self):
        cc.reset_default_controller()
        a = cc.get_default_controller()
        b = cc.get_default_controller()
        assert a is b
        cc.reset_default_controller()

    def test_reset_creates_new(self):
        cc.reset_default_controller()
        a = cc.get_default_controller()
        cc.reset_default_controller()
        b = cc.get_default_controller()
        assert a is not b
        cc.reset_default_controller()
