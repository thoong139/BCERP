"""Concurrency Controller — 3-tier token bucket cho wf-legacy-scan v5.0.

Reference: docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md ADR-LS12.

Tiers (defaults từ 04-data-model.md §1.1 config.concurrency):
- global_max = 8 (hard cap toàn session)
- per_layer_max = 3 (mỗi layer tối đa 3 parallel agent)
- per_probe_max = 4 (mỗi probe fanout tối đa 4)
- reserved_for_synthesis = 2 (luôn giữ 2 slot cho L6)

API tối giản — `acquire()` / `release()` / `status()`. Thread-safe via single
lock + condition variable. Timeout theo `wait_timeout_sec` (default 60s); hết
timeout return False → caller decide retry hoặc abort.

Phase E Task E.3 — CRITICAL: ngăn context overflow / OOM trên dự án lớn.
Tích hợp với Phase E.4 (per-agent timeout watchdog) để ensure slot không bị
leak khi agent hang.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field
from typing import Any


# ─── Defaults (04-data-model.md §1.1 config.concurrency) ─────

DEFAULT_GLOBAL_MAX = 8
DEFAULT_PER_LAYER_MAX = 3
DEFAULT_PER_PROBE_MAX = 4
DEFAULT_RESERVED_FOR_SYNTHESIS = 2
DEFAULT_ACQUIRE_TIMEOUT_SEC = 60.0

# Layers nào được phép tiêu reserved slot (synthesis layer).
_SYNTHESIS_LAYERS = frozenset({"L6"})


# ─── Controller ──────────────────────────────────────────────


@dataclass
class _TokenState:
    """Internal counters for one controller instance."""

    global_in_use: int = 0
    per_layer_in_use: dict[str, int] = field(default_factory=dict)
    per_probe_in_use: dict[str, int] = field(default_factory=dict)
    # active_agents tracks (agent_key → (layer, probe, acquired_at)) cho release
    # validation + status reporting.
    active: dict[str, tuple[str, str, float]] = field(default_factory=dict)


class ConcurrencyController:
    """3-tier token bucket for agent spawn coordination.

    Usage:
        ctrl = ConcurrencyController()
        if ctrl.acquire("L4", "classify.batch", "agent-001"):
            try:
                ... spawn agent ...
            finally:
                ctrl.release("L4", "classify.batch", "agent-001")
        else:
            ... timeout — retry or abort ...

    Non-blocking variant: `acquire(..., timeout_sec=0)`.
    """

    def __init__(
        self,
        global_max: int = DEFAULT_GLOBAL_MAX,
        per_layer_max: int = DEFAULT_PER_LAYER_MAX,
        per_probe_max: int = DEFAULT_PER_PROBE_MAX,
        reserved_for_synthesis: int = DEFAULT_RESERVED_FOR_SYNTHESIS,
    ) -> None:
        if global_max <= 0:
            raise ValueError("global_max must be > 0")
        if reserved_for_synthesis < 0 or reserved_for_synthesis >= global_max:
            raise ValueError(
                "reserved_for_synthesis must be in [0, global_max)"
            )

        self.global_max = global_max
        self.per_layer_max = per_layer_max
        self.per_probe_max = per_probe_max
        self.reserved_for_synthesis = reserved_for_synthesis

        self._lock = threading.Lock()
        self._cond = threading.Condition(self._lock)
        self._state = _TokenState()

    # ─── Public API ─────────────────────────────────────────

    def acquire(
        self,
        layer: str,
        probe_id: str,
        agent_key: str,
        timeout_sec: float = DEFAULT_ACQUIRE_TIMEOUT_SEC,
    ) -> bool:
        """Acquire token for agent spawn.

        Args:
            layer: Layer ID (L1..L6).
            probe_id: Probe / task identifier (e.g., "L4.classify.batch-003").
            agent_key: Unique agent identifier cho tracking (release + status).
            timeout_sec: Max wait for a free slot. 0 → non-blocking.

        Returns:
            True nếu acquired; False nếu hết timeout (caller quyết retry/abort).

        Raises:
            ValueError: agent_key đã được acquired (double-acquire).
        """
        deadline = time.monotonic() + timeout_sec
        with self._cond:
            while True:
                if agent_key in self._state.active:
                    raise ValueError(
                        f"agent_key {agent_key!r} already active — "
                        "double-acquire detected"
                    )
                if self._can_acquire_locked(layer, probe_id):
                    self._do_acquire_locked(layer, probe_id, agent_key)
                    return True

                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return False
                # Wait for a release notify. Wake no later than `remaining`.
                self._cond.wait(timeout=remaining)

    def release(self, layer: str, probe_id: str, agent_key: str) -> None:
        """Release token. Idempotent — double-release becomes no-op.

        Args:
            layer: Layer ID used at acquire time.
            probe_id: Probe ID used at acquire time.
            agent_key: Agent key used at acquire time.
        """
        with self._cond:
            entry = self._state.active.pop(agent_key, None)
            if entry is None:
                # Idempotent no-op.
                return

            tracked_layer, tracked_probe, _ = entry
            # Use tracked values (source of truth) để tránh silent bug nếu
            # caller pass inconsistent layer/probe.
            _ = layer  # accept both but trust tracked state
            _ = probe_id

            self._state.global_in_use = max(0, self._state.global_in_use - 1)

            layer_count = self._state.per_layer_in_use.get(tracked_layer, 0)
            self._state.per_layer_in_use[tracked_layer] = max(0, layer_count - 1)

            probe_count = self._state.per_probe_in_use.get(tracked_probe, 0)
            self._state.per_probe_in_use[tracked_probe] = max(0, probe_count - 1)

            self._cond.notify_all()

    def status(self) -> dict[str, Any]:
        """Current token usage snapshot cho monitoring / logging.

        Returns:
            Dict with keys:
              - global_in_use, global_max, reserved_for_synthesis
              - per_layer: dict layer → count
              - per_probe: dict probe → count
              - active_agents: list of dicts with key/layer/probe/held_sec
        """
        with self._cond:
            now = time.monotonic()
            return {
                "global_in_use": self._state.global_in_use,
                "global_max": self.global_max,
                "reserved_for_synthesis": self.reserved_for_synthesis,
                "per_layer": dict(self._state.per_layer_in_use),
                "per_probe": dict(self._state.per_probe_in_use),
                "active_agents": [
                    {
                        "key": k,
                        "layer": v[0],
                        "probe": v[1],
                        "held_sec": round(now - v[2], 2),
                    }
                    for k, v in self._state.active.items()
                ],
            }

    def active_keys(self) -> list[str]:
        """Return list of currently-active agent keys."""
        with self._cond:
            return list(self._state.active.keys())

    # ─── Internals (require lock) ───────────────────────────

    def _effective_global_cap(self, layer: str) -> int:
        """Global cap khả dụng cho `layer`.

        Non-synthesis layers chỉ dùng `global_max - reserved_for_synthesis`.
        Synthesis layers (L6) dùng toàn bộ `global_max`.
        """
        if layer in _SYNTHESIS_LAYERS:
            return self.global_max
        return self.global_max - self.reserved_for_synthesis

    def _can_acquire_locked(self, layer: str, probe_id: str) -> bool:
        if self._state.global_in_use >= self._effective_global_cap(layer):
            return False
        if (
            self._state.per_layer_in_use.get(layer, 0) >= self.per_layer_max
        ):
            return False
        if (
            self._state.per_probe_in_use.get(probe_id, 0) >= self.per_probe_max
        ):
            return False
        return True

    def _do_acquire_locked(
        self, layer: str, probe_id: str, agent_key: str
    ) -> None:
        self._state.global_in_use += 1
        self._state.per_layer_in_use[layer] = (
            self._state.per_layer_in_use.get(layer, 0) + 1
        )
        self._state.per_probe_in_use[probe_id] = (
            self._state.per_probe_in_use.get(probe_id, 0) + 1
        )
        self._state.active[agent_key] = (layer, probe_id, time.monotonic())


# ─── Singleton helper (per-process default) ──────────────────

_DEFAULT_CONTROLLER: ConcurrencyController | None = None
_DEFAULT_LOCK = threading.Lock()


def get_default_controller() -> ConcurrencyController:
    """Return shared per-process controller (lazy init).

    Orchestrator + sub-skills thường dùng cùng 1 bucket cho session.
    """
    global _DEFAULT_CONTROLLER
    with _DEFAULT_LOCK:
        if _DEFAULT_CONTROLLER is None:
            _DEFAULT_CONTROLLER = ConcurrencyController()
        return _DEFAULT_CONTROLLER


def reset_default_controller() -> None:
    """Reset singleton — for test isolation only."""
    global _DEFAULT_CONTROLLER
    with _DEFAULT_LOCK:
        _DEFAULT_CONTROLLER = None
