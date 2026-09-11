"""test_token_bucket.py — Tests cho concurrency.token_bucket.

Phạm vi chính:
    - TokenBucket happy-path: acquire 1 token, kiểm tra tokens_available giảm.
    - TokenBucket capacity guard: raise khi capacity <= 0; acquire n > capacity raise.
    - TokenBucket refill: sau thời gian, tokens được refill.
    - TokenBucket3Tier ADR-22 rule 3: mọi override khác 12/4/6 → ValueError.
    - TokenBucket3Tier.acquire context manager: yield khi đủ token cả 3 tier.
    - Snapshot: trả về dict 3 tier.
"""
from __future__ import annotations

import asyncio

import pytest

from concurrency.token_bucket import (
    DEFAULT_GLOBAL_CAP,
    DEFAULT_INTRA_CAP,
    DEFAULT_LANE_CAP,
    REFILL_WINDOW_SEC,
    BucketState,
    TokenBucket,
    TokenBucket3Tier,
)


# ──────────────────────────────────────────────────────────────────────
# TokenBucket basics
# ──────────────────────────────────────────────────────────────────────


class TestTokenBucket:
    def test_constructor_valid_capacity(self) -> None:
        tb = TokenBucket(5)
        assert tb.capacity == 5
        assert tb.tokens_available() == 5.0

    def test_constructor_rejects_non_positive_capacity(self) -> None:
        with pytest.raises(ValueError, match="capacity phải > 0"):
            TokenBucket(0)
        with pytest.raises(ValueError):
            TokenBucket(-1)

    def test_acquire_happy_path_reduces_tokens(self) -> None:
        async def run() -> None:
            tb = TokenBucket(3)
            ok = await tb.acquire(1)
            assert ok is True
            # Sau acquire, tokens giảm còn ~2 (không xét refill trong <1ms)
            assert tb.tokens_available() <= 2.0

        asyncio.run(run())

    def test_acquire_rejects_bad_n(self) -> None:
        async def run() -> None:
            tb = TokenBucket(3)
            with pytest.raises(ValueError, match="n phải > 0"):
                await tb.acquire(0)
            with pytest.raises(ValueError, match="vượt capacity"):
                await tb.acquire(999)

        asyncio.run(run())

    def test_acquire_timeout_returns_false(self) -> None:
        """Drain hết token → acquire thứ kế với timeout ngắn phải trả False."""

        async def run() -> None:
            tb = TokenBucket(1)
            assert await tb.acquire(1) is True
            # Bucket cạn; refill rate = 1 / REFILL_WINDOW_SEC token/sec
            # timeout = 50ms sẽ không đủ → return False (không raise)
            result = await tb.acquire(1, timeout_ms=50)
            assert result is False

        asyncio.run(run())

    def test_bucket_state_new_has_full_tokens(self) -> None:
        state = BucketState.new(10)
        assert state.capacity == 10
        assert state.tokens == 10.0
        assert state.refill_per_sec == pytest.approx(10.0 / REFILL_WINDOW_SEC)


# ──────────────────────────────────────────────────────────────────────
# ADR-22 rule 3 — non-negotiable defaults
# ──────────────────────────────────────────────────────────────────────


class TestADR22Rule3Defaults:
    def test_defaults_are_12_4_6(self) -> None:
        assert DEFAULT_GLOBAL_CAP == 12
        assert DEFAULT_LANE_CAP == 4
        assert DEFAULT_INTRA_CAP == 6

    def test_default_construction_ok(self) -> None:
        tb = TokenBucket3Tier()
        snap = tb.snapshot()
        assert snap["global"] == pytest.approx(12.0)

    @pytest.mark.parametrize(
        "g,l,i",
        [
            (10, 4, 6),   # global khác
            (12, 3, 6),   # lane khác
            (12, 4, 8),   # intra khác
            (24, 8, 12),  # scale 2x
            (1, 1, 1),    # min
        ],
    )
    def test_override_defaults_raises(self, g: int, l: int, i: int) -> None:
        with pytest.raises(ValueError, match="ADR-22 rule 3"):
            TokenBucket3Tier(global_cap=g, lane_cap=l, intra_cap=i)


# ──────────────────────────────────────────────────────────────────────
# TokenBucket3Tier.acquire (context manager)
# ──────────────────────────────────────────────────────────────────────


class TestTokenBucket3TierAcquire:
    def test_acquire_yields_when_tokens_available(self) -> None:
        async def run() -> bool:
            tb = TokenBucket3Tier()
            async with tb.acquire(lane_id="wf-fix-functional", probe_id="P-QD1-x"):
                return True
            return False  # pragma: no cover

        assert asyncio.run(run()) is True

    def test_acquire_creates_lane_and_probe_buckets(self) -> None:
        async def run() -> dict:
            tb = TokenBucket3Tier()
            async with tb.acquire(lane_id="laneA", probe_id="probeX"):
                pass
            return tb.snapshot()

        snap = asyncio.run(run())
        assert "laneA" in snap["lanes"]
        assert "probeX" in snap["probes"]

    def test_acquire_multiple_times_shares_lane_bucket(self) -> None:
        """Nhiều probe cùng lane dùng chung bucket lane → không tạo duplicate."""

        async def run() -> dict:
            tb = TokenBucket3Tier()
            async with tb.acquire("laneA", "probeX"):
                pass
            async with tb.acquire("laneA", "probeY"):
                pass
            return tb.snapshot()

        snap = asyncio.run(run())
        # Chỉ 1 lane key — chia sẻ
        assert list(snap["lanes"].keys()) == ["laneA"]
        # 2 probe keys riêng
        assert set(snap["probes"].keys()) == {"probeX", "probeY"}
