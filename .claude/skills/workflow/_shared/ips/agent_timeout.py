"""Agent Timeout & Watchdog — Phase E Task E.4.

Reference: docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md ADR-LS12 (v2.1).

Policy:
- Default 300s cho standard/surface/full depth.
- 600s cho `deep` hoặc `exhaustive` L5 extraction.
- Env override:
  - `LEGACY_SCAN_AGENT_TIMEOUT_SEC` (default 300)
  - `LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC` (default 600)
- Watchdog check interval: 30s.
- On timeout: abort + retry simplified scope (max 2 retries) → skip module + WARN.

Note: Actual agent abort/spawn là trách nhiệm của orchestrator (Claude Agent
tool). Module này cung cấp:
1. Timeout resolution (depth + env vars).
2. Registry tracking active agents + deadlines (per session).
3. `check_expired()` — returns list of expired agent keys cho orchestrator
   kích hoạt abort + retry flow.
4. Retry policy state (attempt counter, max 2).
"""

from __future__ import annotations

import os
import threading
import time
from dataclasses import dataclass, field
from typing import Any


# ─── Defaults & Env Resolution ───────────────────────────────

DEFAULT_TIMEOUT_SEC = 300.0
DEFAULT_DEEP_TIMEOUT_SEC = 600.0
WATCHDOG_INTERVAL_SEC = 30.0
MAX_RETRY_ATTEMPTS = 2

# Depths được coi là "deep" cho timeout policy.
_DEEP_DEPTHS = frozenset({"deep", "exhaustive"})


def resolve_timeout_sec(depth: str | None) -> float:
    """Resolve timeout for agent spawn theo depth + env vars.

    Args:
        depth: Depth level (full/surface/standard/deep/exhaustive/skip/None).

    Returns:
        Timeout seconds (float). Deep/exhaustive → 600s, else 300s.
        Env vars `LEGACY_SCAN_AGENT_TIMEOUT_SEC` /
        `LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC` override defaults.
    """
    is_deep = depth in _DEEP_DEPTHS

    env_key = (
        "LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC"
        if is_deep
        else "LEGACY_SCAN_AGENT_TIMEOUT_SEC"
    )
    fallback = DEFAULT_DEEP_TIMEOUT_SEC if is_deep else DEFAULT_TIMEOUT_SEC

    raw = os.environ.get(env_key)
    if raw is None:
        return fallback
    try:
        value = float(raw)
    except ValueError:
        return fallback
    if value <= 0:
        return fallback
    return value


# ─── Registry ────────────────────────────────────────────────


@dataclass
class AgentEntry:
    """Tracked agent spawn state."""

    key: str
    layer: str
    probe_id: str
    depth: str | None
    started_at: float  # monotonic seconds
    timeout_sec: float
    attempt: int = 1  # 1 = first run, 2 = retry after first timeout

    @property
    def deadline(self) -> float:
        return self.started_at + self.timeout_sec

    def is_expired(self, now: float | None = None) -> bool:
        t = now if now is not None else time.monotonic()
        return t >= self.deadline


@dataclass
class _RegistryState:
    active: dict[str, AgentEntry] = field(default_factory=dict)
    # Count of expired-and-skipped modules for metrics.
    skipped_after_retries: int = 0


class AgentWatchdogRegistry:
    """Tracks active agent spawns with per-agent deadlines.

    Thread-safe. Orchestrator calls:

        reg.register(key, layer, probe, depth)  # when spawn starts
        ...
        # Periodically (every 30s) or before aggregation:
        for entry in reg.check_expired():
            orchestrator.abort(entry.key)
            if entry.attempt < MAX_RETRY_ATTEMPTS:
                reg.mark_retry(entry.key)
                orchestrator.respawn_simplified(entry)
            else:
                reg.mark_skipped(entry.key)
                orchestrator.log_warn(f"Skipping {entry.layer}/{entry.probe_id}")
        ...
        reg.release(key)  # when agent completes OR is abort+skipped
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._state = _RegistryState()

    # ─── Registration ─────────────────────────────────────

    def register(
        self,
        key: str,
        layer: str,
        probe_id: str,
        depth: str | None = None,
        timeout_sec: float | None = None,
    ) -> AgentEntry:
        """Record a new agent spawn. Returns the tracked entry.

        Raises:
            ValueError: key already active.
        """
        resolved_timeout = (
            timeout_sec if timeout_sec is not None else resolve_timeout_sec(depth)
        )
        entry = AgentEntry(
            key=key,
            layer=layer,
            probe_id=probe_id,
            depth=depth,
            started_at=time.monotonic(),
            timeout_sec=resolved_timeout,
            attempt=1,
        )
        with self._lock:
            if key in self._state.active:
                raise ValueError(f"agent {key!r} already registered")
            self._state.active[key] = entry
        return entry

    def release(self, key: str) -> AgentEntry | None:
        """Remove agent from registry (completed / aborted / skipped).

        Idempotent — unknown key returns None.
        """
        with self._lock:
            return self._state.active.pop(key, None)

    def mark_retry(self, key: str) -> AgentEntry | None:
        """Bump attempt counter + reset start_time cho retry run.

        Returns updated entry, or None nếu key unknown hoặc attempt đã tối đa.
        """
        with self._lock:
            entry = self._state.active.get(key)
            if entry is None:
                return None
            if entry.attempt >= MAX_RETRY_ATTEMPTS:
                return None
            entry.attempt += 1
            entry.started_at = time.monotonic()
            return entry

    def mark_skipped(self, key: str) -> AgentEntry | None:
        """Mark agent as skipped-after-retries + remove from active."""
        with self._lock:
            entry = self._state.active.pop(key, None)
            if entry is None:
                return None
            self._state.skipped_after_retries += 1
            return entry

    # ─── Queries ──────────────────────────────────────────

    def check_expired(self, now: float | None = None) -> list[AgentEntry]:
        """Return snapshot of entries whose deadline has passed.

        Caller xử lý: gọi abort → mark_retry hoặc mark_skipped.
        """
        t = now if now is not None else time.monotonic()
        with self._lock:
            return [e for e in self._state.active.values() if e.is_expired(t)]

    def active_count(self) -> int:
        with self._lock:
            return len(self._state.active)

    def skipped_count(self) -> int:
        with self._lock:
            return self._state.skipped_after_retries

    def status(self) -> dict[str, Any]:
        """Snapshot cho monitoring / logs."""
        t = time.monotonic()
        with self._lock:
            return {
                "active_count": len(self._state.active),
                "skipped_after_retries": self._state.skipped_after_retries,
                "entries": [
                    {
                        "key": e.key,
                        "layer": e.layer,
                        "probe_id": e.probe_id,
                        "depth": e.depth,
                        "attempt": e.attempt,
                        "elapsed_sec": round(t - e.started_at, 2),
                        "timeout_sec": e.timeout_sec,
                        "expired": e.is_expired(t),
                    }
                    for e in self._state.active.values()
                ],
            }


# ─── Singleton helper (per-process) ──────────────────────────

_DEFAULT_REGISTRY: AgentWatchdogRegistry | None = None
_DEFAULT_LOCK = threading.Lock()


def get_default_registry() -> AgentWatchdogRegistry:
    """Return shared per-process registry (lazy init)."""
    global _DEFAULT_REGISTRY
    with _DEFAULT_LOCK:
        if _DEFAULT_REGISTRY is None:
            _DEFAULT_REGISTRY = AgentWatchdogRegistry()
        return _DEFAULT_REGISTRY


def reset_default_registry() -> None:
    """Reset singleton — for test isolation only."""
    global _DEFAULT_REGISTRY
    with _DEFAULT_LOCK:
        _DEFAULT_REGISTRY = None


# ─── Watchdog Loop Helper ────────────────────────────────────


def watchdog_tick(
    registry: AgentWatchdogRegistry,
    abort_fn,
    retry_fn,
    skip_fn,
    now: float | None = None,
) -> dict[str, int]:
    """Single watchdog tick — process all expired entries.

    Orchestrator thường call trong loop với sleep `WATCHDOG_INTERVAL_SEC`.

    Args:
        registry: Shared registry instance.
        abort_fn: callable(key, entry) → abort agent spawn.
        retry_fn: callable(key, entry) → spawn simplified retry.
        skip_fn: callable(key, entry) → log WARN + mark module skipped.
        now: Optional monotonic time override (testing).

    Returns:
        Dict with counts: aborted, retried, skipped.
    """
    counts = {"aborted": 0, "retried": 0, "skipped": 0}
    for entry in registry.check_expired(now=now):
        abort_fn(entry.key, entry)
        counts["aborted"] += 1

        if entry.attempt < MAX_RETRY_ATTEMPTS:
            updated = registry.mark_retry(entry.key)
            if updated is not None:
                retry_fn(entry.key, updated)
                counts["retried"] += 1
        else:
            registry.mark_skipped(entry.key)
            skip_fn(entry.key, entry)
            counts["skipped"] += 1
    return counts
