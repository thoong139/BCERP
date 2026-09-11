#!/usr/bin/env python3
"""token_bucket.py — 3-tier token bucket cho wf-fix-* concurrency.

Vai trò:
    Cung cấp rate-limiting 3 tầng (global / inter-lane / intra-probe) với
    token-bucket algorithm. Enforce ADR-22 rule 3: default 12/4/6, không được
    override runtime.

Registry role: NONE. Không ghi req-registry.json.

Tham chiếu:
    - ADR-02: utility module
    - ADR-17: concurrency model
    - ADR-22 rule 3: non-negotiable token bucket defaults
    - CORE-025: song song an toàn
"""
from __future__ import annotations

import argparse
import asyncio
import sys
import time
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import AsyncIterator

# ──────────────────────────────────────────────────────────────────────
# Hằng số — ADR-22 rule 3 (KHÔNG override)
# ──────────────────────────────────────────────────────────────────────

DEFAULT_GLOBAL_CAP: int = 12
DEFAULT_LANE_CAP: int = 4
DEFAULT_INTRA_CAP: int = 6
REFILL_WINDOW_SEC: float = 60.0


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class BucketState:
    """State của 1 token bucket."""

    capacity: int
    tokens: float
    refill_per_sec: float
    last_refill_ts: float

    @classmethod
    def new(cls, capacity: int) -> "BucketState":
        now = time.monotonic()
        return cls(
            capacity=capacity,
            tokens=float(capacity),
            refill_per_sec=capacity / REFILL_WINDOW_SEC,
            last_refill_ts=now,
        )


# ──────────────────────────────────────────────────────────────────────
# 1. Token Bucket (single tier)
# ──────────────────────────────────────────────────────────────────────


class TokenBucket:
    """Token bucket đơn tầng — primitive dùng bởi TokenBucket3Tier.

    Refill liên tục theo thời gian: mỗi giây thêm `capacity / REFILL_WINDOW_SEC` token.
    acquire() block cho đến khi đủ n tokens hoặc timeout.
    """

    def __init__(self, capacity: int) -> None:
        if capacity <= 0:
            raise ValueError(f"TokenBucket: capacity phải > 0, nhận {capacity}")
        self._state = BucketState.new(capacity)
        self._lock = asyncio.Lock()

    def _refill(self) -> None:
        """Refill theo thời gian đã trôi. CALLER phải giữ self._lock."""
        now = time.monotonic()
        elapsed = max(0.0, now - self._state.last_refill_ts)
        if elapsed <= 0:
            return
        added = elapsed * self._state.refill_per_sec
        self._state.tokens = min(
            float(self._state.capacity),
            self._state.tokens + added,
        )
        self._state.last_refill_ts = now

    async def acquire(self, n: int = 1, timeout_ms: int = 30_000) -> bool:
        """Acquire n tokens, block tối đa timeout_ms ms.

        Returns:
            True nếu acquire thành công, False nếu timeout.

        Raises:
            ValueError: n <= 0 hoặc n > capacity.
        """
        if n <= 0:
            raise ValueError(f"TokenBucket.acquire: n phải > 0, nhận {n}")
        if n > self._state.capacity:
            raise ValueError(
                f"TokenBucket.acquire: n={n} vượt capacity={self._state.capacity} "
                "— không bao giờ acquire được, refuse up-front"
            )

        deadline = time.monotonic() + (timeout_ms / 1000.0)

        while True:
            async with self._lock:
                self._refill()
                if self._state.tokens >= n:
                    self._state.tokens -= n
                    return True

                # Tính thời gian cần chờ để có đủ n token
                deficit = n - self._state.tokens
                wait_needed = deficit / self._state.refill_per_sec

            # Check timeout bên ngoài lock
            now = time.monotonic()
            remaining = deadline - now
            if remaining <= 0:
                return False

            # Sleep chỉ đến min(wait_needed, remaining)
            sleep_for = min(wait_needed, remaining)
            # Tránh busy-loop: tối thiểu 1ms
            await asyncio.sleep(max(0.001, sleep_for))

    def tokens_available(self) -> float:
        """Snapshot số token hiện có (không lock, không refill)."""
        return self._state.tokens

    @property
    def capacity(self) -> int:
        return self._state.capacity


# ──────────────────────────────────────────────────────────────────────
# 2. 3-Tier Token Bucket
# ──────────────────────────────────────────────────────────────────────


class TokenBucket3Tier:
    """3 tầng token bucket — global + inter-lane + intra-probe.

    ADR-22 rule 3: default 12/4/6, KHÔNG override runtime (constructor raise).
    """

    def __init__(
        self,
        global_cap: int = DEFAULT_GLOBAL_CAP,
        lane_cap: int = DEFAULT_LANE_CAP,
        intra_cap: int = DEFAULT_INTRA_CAP,
    ) -> None:
        # Guard: enforce ADR-22 rule 3 — reject override
        if (global_cap, lane_cap, intra_cap) != (
            DEFAULT_GLOBAL_CAP,
            DEFAULT_LANE_CAP,
            DEFAULT_INTRA_CAP,
        ):
            raise ValueError(
                "ADR-22 rule 3: không được override default 12/4/6 — "
                f"nhận {global_cap}/{lane_cap}/{intra_cap}"
            )

        self._global = TokenBucket(global_cap)
        self._per_lane: dict[str, TokenBucket] = {}
        self._per_probe: dict[str, TokenBucket] = {}
        self._lane_cap = lane_cap
        self._intra_cap = intra_cap
        self._dict_lock = asyncio.Lock()

    async def _get_lane_bucket(self, lane_id: str) -> TokenBucket:
        """Lazy-create bucket per lane (atomic double-check)."""
        bucket = self._per_lane.get(lane_id)
        if bucket is not None:
            return bucket
        async with self._dict_lock:
            bucket = self._per_lane.get(lane_id)
            if bucket is None:
                bucket = TokenBucket(self._lane_cap)
                self._per_lane[lane_id] = bucket
            return bucket

    async def _get_probe_bucket(self, probe_id: str) -> TokenBucket:
        """Lazy-create bucket per probe (atomic double-check)."""
        bucket = self._per_probe.get(probe_id)
        if bucket is not None:
            return bucket
        async with self._dict_lock:
            bucket = self._per_probe.get(probe_id)
            if bucket is None:
                bucket = TokenBucket(self._intra_cap)
                self._per_probe[probe_id] = bucket
            return bucket

    @asynccontextmanager
    async def acquire(
        self,
        lane_id: str,
        probe_id: str,
        timeout_ms: int = 30_000,
    ) -> AsyncIterator[None]:
        """Context manager: acquire 1 token từ 3 tier, release khi exit.

        Token-bucket không cần explicit release — refill tự diễn ra theo thời gian.

        Raises:
            TimeoutError: nếu không acquire được trong timeout_ms.
        """
        deadline = time.monotonic() + (timeout_ms / 1000.0)

        def _remaining_ms() -> int:
            left_sec = deadline - time.monotonic()
            return max(0, int(left_sec * 1000))

        ok = await self._global.acquire(1, timeout_ms)
        if not ok:
            raise TimeoutError(
                f"TokenBucket3Tier.acquire: timeout ở TIER-1 global "
                f"(lane={lane_id}, probe={probe_id})"
            )

        lane_bucket = await self._get_lane_bucket(lane_id)
        ok = await lane_bucket.acquire(1, _remaining_ms())
        if not ok:
            raise TimeoutError(
                f"TokenBucket3Tier.acquire: timeout ở TIER-2 lane={lane_id} "
                f"(probe={probe_id})"
            )

        probe_bucket = await self._get_probe_bucket(probe_id)
        ok = await probe_bucket.acquire(1, _remaining_ms())
        if not ok:
            raise TimeoutError(
                f"TokenBucket3Tier.acquire: timeout ở TIER-3 probe={probe_id} "
                f"(lane={lane_id})"
            )

        try:
            yield
        finally:
            # Token-bucket KHÔNG release — refill đã bù lại theo thời gian.
            # Đây là design choice: không hoàn trả token để cap burst load.
            pass

    def snapshot(self) -> dict[str, float]:
        """Debug helper: snapshot tokens còn lại ở 3 tier."""
        return {
            "global": self._global.tokens_available(),
            "lanes": {k: b.tokens_available() for k, b in self._per_lane.items()},
            "probes": {k: b.tokens_available() for k, b in self._per_probe.items()},
        }


# ──────────────────────────────────────────────────────────────────────
# CLI stress test (simplified, single-process)
# ──────────────────────────────────────────────────────────────────────


async def _run_stress(duration_sec: int, num_workers: int = 20) -> dict[str, float]:
    """Chạy N coroutine trong duration_sec, đo throughput đơn giản."""
    tb = TokenBucket3Tier()
    counters = {"acquired": 0, "timeouts": 0}
    stop_at = time.monotonic() + duration_sec

    async def worker(wid: int) -> None:
        while time.monotonic() < stop_at:
            try:
                async with tb.acquire(
                    lane_id=f"lane-{wid % 4}",
                    probe_id=f"probe-{wid % 6}",
                    timeout_ms=500,
                ):
                    counters["acquired"] += 1
                    await asyncio.sleep(0.01)
            except TimeoutError:
                counters["timeouts"] += 1
                await asyncio.sleep(0.05)

    await asyncio.gather(*(worker(i) for i in range(num_workers)))
    return {
        "acquired_total": float(counters["acquired"]),
        "timeouts_total": float(counters["timeouts"]),
        "throughput_per_sec": counters["acquired"] / duration_sec,
    }


def _cmd_stress(args: argparse.Namespace) -> int:
    """Simulate load — dùng để verify 3-tier enforcement."""
    result = asyncio.run(_run_stress(args.duration))
    for k, v in result.items():
        print(f"{k}: {v}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="3-Tier Token Bucket")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_stress = sub.add_parser("stress", help="Simulate load")
    p_stress.add_argument(
        "--global", dest="global_cap", type=int, default=DEFAULT_GLOBAL_CAP
    )
    p_stress.add_argument(
        "--lane", dest="lane_cap", type=int, default=DEFAULT_LANE_CAP
    )
    p_stress.add_argument(
        "--intra", dest="intra_cap", type=int, default=DEFAULT_INTRA_CAP
    )
    p_stress.add_argument("--duration", type=int, default=5, help="Seconds")
    p_stress.set_defaults(func=_cmd_stress)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
