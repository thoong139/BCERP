"""Tests for agent_timeout.py — Phase E Task E.4.

Coverage:
- resolve_timeout_sec: default / deep / env override / invalid env.
- AgentWatchdogRegistry: register/release/mark_retry/mark_skipped.
- check_expired: time-based queries.
- watchdog_tick: abort + retry + skip flow.
- Singleton helpers.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import agent_timeout as at  # noqa: E402


# ─── Timeout Resolution ──────────────────────────────────────


class TestResolveTimeoutSec:
    def test_default_standard(self, monkeypatch):
        monkeypatch.delenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", raising=False)
        assert at.resolve_timeout_sec("standard") == 300.0
        assert at.resolve_timeout_sec("full") == 300.0
        assert at.resolve_timeout_sec("surface") == 300.0
        assert at.resolve_timeout_sec(None) == 300.0

    def test_default_deep(self, monkeypatch):
        monkeypatch.delenv("LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC", raising=False)
        assert at.resolve_timeout_sec("deep") == 600.0
        assert at.resolve_timeout_sec("exhaustive") == 600.0

    def test_env_override_standard(self, monkeypatch):
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", "450")
        assert at.resolve_timeout_sec("standard") == 450.0

    def test_env_override_deep(self, monkeypatch):
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC", "900")
        assert at.resolve_timeout_sec("deep") == 900.0
        assert at.resolve_timeout_sec("exhaustive") == 900.0

    def test_env_deep_does_not_affect_standard(self, monkeypatch):
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC", "999")
        monkeypatch.delenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", raising=False)
        assert at.resolve_timeout_sec("standard") == 300.0
        assert at.resolve_timeout_sec("deep") == 999.0

    def test_invalid_env_falls_back_to_default(self, monkeypatch):
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", "not-a-number")
        assert at.resolve_timeout_sec("standard") == 300.0
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", "-5")
        assert at.resolve_timeout_sec("standard") == 300.0
        monkeypatch.setenv("LEGACY_SCAN_AGENT_TIMEOUT_SEC", "0")
        assert at.resolve_timeout_sec("standard") == 300.0


# ─── Registry: Basic ─────────────────────────────────────────


class TestRegistryBasics:
    def test_register_release_roundtrip(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register("a1", "L4", "p.1", depth="standard")
        assert entry.key == "a1"
        assert entry.layer == "L4"
        assert entry.attempt == 1
        assert entry.timeout_sec == 300.0
        assert reg.active_count() == 1

        released = reg.release("a1")
        assert released is not None
        assert released.key == "a1"
        assert reg.active_count() == 0

    def test_release_unknown_returns_none(self):
        reg = at.AgentWatchdogRegistry()
        assert reg.release("nope") is None

    def test_double_register_raises(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", depth="standard")
        with pytest.raises(ValueError, match="already registered"):
            reg.register("a1", "L4", "p", depth="standard")

    def test_register_deep_uses_600s(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register("a1", "L5", "p", depth="deep")
        assert entry.timeout_sec == 600.0

    def test_register_explicit_timeout_override(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register(
            "a1", "L4", "p", depth="standard", timeout_sec=15.0
        )
        assert entry.timeout_sec == 15.0


# ─── Registry: Expiry ────────────────────────────────────────


class TestExpiry:
    def test_not_expired_before_deadline(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register(
            "a1", "L4", "p", depth="standard", timeout_sec=10.0
        )
        now = entry.started_at + 5.0
        assert entry.is_expired(now) is False
        assert reg.check_expired(now=now) == []

    def test_expired_after_deadline(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register(
            "a1", "L4", "p", depth="standard", timeout_sec=10.0
        )
        now = entry.started_at + 11.0
        assert entry.is_expired(now) is True
        expired = reg.check_expired(now=now)
        assert len(expired) == 1
        assert expired[0].key == "a1"

    def test_mix_expired_and_active(self):
        reg = at.AgentWatchdogRegistry()
        e1 = reg.register("a1", "L4", "p", timeout_sec=10.0)
        reg.register("a2", "L5", "p", timeout_sec=100.0)
        now = e1.started_at + 15.0
        expired = reg.check_expired(now=now)
        keys = {e.key for e in expired}
        assert keys == {"a1"}


# ─── Registry: Retry & Skip ──────────────────────────────────


class TestRetryAndSkip:
    def test_mark_retry_bumps_attempt(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", timeout_sec=10.0)
        updated = reg.mark_retry("a1")
        assert updated is not None
        assert updated.attempt == 2

    def test_mark_retry_resets_start_time(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register("a1", "L4", "p", timeout_sec=10.0)
        # Capture snapshot BEFORE mutation (mark_retry mutates same object).
        original_started = entry.started_at
        # Sleep beyond Windows monotonic clock resolution (~15ms).
        time.sleep(0.05)
        updated = reg.mark_retry("a1")
        assert updated is not None
        assert updated.started_at > original_started

    def test_mark_retry_max_attempts_reached(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", timeout_sec=10.0)
        reg.mark_retry("a1")  # attempt 1 → 2
        assert reg.mark_retry("a1") is None  # already at MAX_RETRY_ATTEMPTS

    def test_mark_retry_unknown_returns_none(self):
        reg = at.AgentWatchdogRegistry()
        assert reg.mark_retry("nope") is None

    def test_mark_skipped_increments_counter(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", timeout_sec=10.0)
        reg.register("a2", "L5", "p", timeout_sec=10.0)
        reg.mark_skipped("a1")
        assert reg.skipped_count() == 1
        assert reg.active_count() == 1
        reg.mark_skipped("a2")
        assert reg.skipped_count() == 2
        assert reg.active_count() == 0


# ─── Watchdog Tick ───────────────────────────────────────────


class TestWatchdogTick:
    def test_tick_no_expired_no_calls(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", timeout_sec=100.0)
        calls = {"abort": 0, "retry": 0, "skip": 0}

        def abort(k, e): calls["abort"] += 1  # noqa: E731, ARG001
        def retry(k, e): calls["retry"] += 1  # noqa: E731, ARG001
        def skip(k, e): calls["skip"] += 1  # noqa: E731, ARG001

        counts = at.watchdog_tick(reg, abort, retry, skip)
        assert counts == {"aborted": 0, "retried": 0, "skipped": 0}
        assert calls == {"abort": 0, "retry": 0, "skip": 0}

    def test_tick_expired_attempt1_retries(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register("a1", "L4", "p", timeout_sec=10.0)
        now = entry.started_at + 15.0
        actions = {"aborted": [], "retried": [], "skipped": []}

        counts = at.watchdog_tick(
            reg,
            abort_fn=lambda k, e: actions["aborted"].append(k),
            retry_fn=lambda k, e: actions["retried"].append(k),
            skip_fn=lambda k, e: actions["skipped"].append(k),
            now=now,
        )
        assert counts == {"aborted": 1, "retried": 1, "skipped": 0}
        assert actions["aborted"] == ["a1"]
        assert actions["retried"] == ["a1"]
        assert actions["skipped"] == []
        # After retry, attempt bumped.
        status = reg.status()
        assert status["entries"][0]["attempt"] == 2

    def test_tick_expired_attempt2_skips(self):
        reg = at.AgentWatchdogRegistry()
        entry = reg.register("a1", "L4", "p", timeout_sec=10.0)
        # Bump to attempt 2 manually.
        reg.mark_retry("a1")
        now = entry.started_at + 15.0
        actions = {"aborted": [], "retried": [], "skipped": []}

        counts = at.watchdog_tick(
            reg,
            abort_fn=lambda k, e: actions["aborted"].append(k),
            retry_fn=lambda k, e: actions["retried"].append(k),
            skip_fn=lambda k, e: actions["skipped"].append(k),
            now=now,
        )
        assert counts == {"aborted": 1, "retried": 0, "skipped": 1}
        assert actions["skipped"] == ["a1"]
        # Removed from registry after skip.
        assert reg.active_count() == 0
        assert reg.skipped_count() == 1


# ─── Status ──────────────────────────────────────────────────


class TestStatus:
    def test_status_empty(self):
        reg = at.AgentWatchdogRegistry()
        s = reg.status()
        assert s["active_count"] == 0
        assert s["skipped_after_retries"] == 0
        assert s["entries"] == []

    def test_status_populated(self):
        reg = at.AgentWatchdogRegistry()
        reg.register("a1", "L4", "p", depth="standard", timeout_sec=20.0)
        reg.register("a2", "L5", "p", depth="deep", timeout_sec=60.0)
        s = reg.status()
        assert s["active_count"] == 2
        by_key = {e["key"]: e for e in s["entries"]}
        assert by_key["a1"]["timeout_sec"] == 20.0
        assert by_key["a2"]["depth"] == "deep"
        assert by_key["a1"]["attempt"] == 1
        assert by_key["a1"]["expired"] is False


# ─── Singleton ───────────────────────────────────────────────


class TestSingleton:
    def test_singleton_same_instance(self):
        at.reset_default_registry()
        a = at.get_default_registry()
        b = at.get_default_registry()
        assert a is b
        at.reset_default_registry()
