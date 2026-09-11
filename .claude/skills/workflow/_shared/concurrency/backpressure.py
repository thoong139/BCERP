#!/usr/bin/env python3
"""backpressure.py — Chặn producer khi downstream (Signal Bus) quá tải.

Vai trò:
    Khi Signal Bus đang atomic-write issue-registry.json, producer (probe)
    phải pause để tránh pile-up. Cung cấp 2 primitive:
        - SemaphoreBackpressure: fixed max in-flight count (hard cap).
        - AdaptiveBackpressure: đo latency của ingest() → exponentially back off.

Registry role: NONE.

Tham chiếu:
    - ADR-17: concurrency model
    - ADR-22 rule 3: token bucket defaults (áp dụng ở token_bucket.py)
    - NOTE-02 (B1 review): tránh truy cập asyncio.Semaphore._value
"""
from __future__ import annotations

import asyncio
import time
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import AsyncIterator

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

DEFAULT_MAX_INFLIGHT: int = 24
ADAPTIVE_LATENCY_THRESHOLD_MS: float = 200.0
ADAPTIVE_BACKOFF_MIN_MS: float = 10.0
ADAPTIVE_BACKOFF_MAX_MS: float = 2_000.0
ADAPTIVE_BACKOFF_MULTIPLIER: float = 2.0


# ──────────────────────────────────────────────────────────────────────
# 1. Semaphore backpressure (simple)
# ──────────────────────────────────────────────────────────────────────


class SemaphoreBackpressure:
    """Producer bị chặn khi có > max_inflight operation đang chờ downstream.

    NOTE-02 (B1 review) đã fix: dùng self._inflight counter riêng, KHÔNG truy cập
    asyncio.Semaphore._value (CPython internal, có thể thay đổi).
    """

    def __init__(self, max_inflight: int = DEFAULT_MAX_INFLIGHT) -> None:
        if max_inflight <= 0:
            raise ValueError(
                f"SemaphoreBackpressure: max_inflight phải > 0, nhận {max_inflight}"
            )
        self._sem = asyncio.Semaphore(max_inflight)
        self._max = max_inflight
        self._inflight: int = 0
        self._counter_lock = asyncio.Lock()

    @asynccontextmanager
    async def slot(self) -> AsyncIterator[None]:
        """Context manager: acquire 1 slot, release khi exit."""
        await self._sem.acquire()
        async with self._counter_lock:
            self._inflight += 1
        try:
            yield
        finally:
            async with self._counter_lock:
                self._inflight -= 1
            self._sem.release()

    def inflight(self) -> int:
        """Số slot đang được hold (đã fix NOTE-02: không dùng _value nội bộ)."""
        return self._inflight

    @property
    def max_inflight(self) -> int:
        return self._max


# ──────────────────────────────────────────────────────────────────────
# 2. Adaptive backpressure (theo latency)
# ──────────────────────────────────────────────────────────────────────


@dataclass
class LatencyWindow:
    """Rolling window đo p95 latency (ms)."""

    samples_ms: list[float] = field(default_factory=list)
    max_size: int = 50

    def add(self, latency_ms: float) -> None:
        """Thêm sample, giữ kích thước ≤ max_size (FIFO)."""
        if latency_ms < 0:
            # Bỏ qua giá trị âm (clock skew) — không raise để không break caller
            return
        self.samples_ms.append(latency_ms)
        if len(self.samples_ms) > self.max_size:
            # FIFO: bỏ sample cũ nhất
            self.samples_ms = self.samples_ms[-self.max_size :]

    def p95(self) -> float:
        """Quantile 95% — trả 0 nếu window rỗng."""
        if not self.samples_ms:
            return 0.0
        sorted_samples = sorted(self.samples_ms)
        # Index p95 theo linear interpolation không cần thiết — dùng nearest-rank đơn giản
        idx = int(round(0.95 * (len(sorted_samples) - 1)))
        return sorted_samples[idx]

    def size(self) -> int:
        return len(self.samples_ms)


class AdaptiveBackpressure:
    """Đo latency của downstream → exponentially back off producer.

    Logic:
        - Gọi `start()` trước mỗi ingest().
        - Gọi `end()` sau ingest() → ghi latency vào window.
        - Nếu p95 > threshold → next `pre_wait()` sẽ sleep exponentially.
        - Nếu p95 < threshold → reset backoff về MIN.
    """

    def __init__(
        self,
        registry_path: Path,
        threshold_ms: float = ADAPTIVE_LATENCY_THRESHOLD_MS,
        min_backoff_ms: float = ADAPTIVE_BACKOFF_MIN_MS,
        max_backoff_ms: float = ADAPTIVE_BACKOFF_MAX_MS,
        multiplier: float = ADAPTIVE_BACKOFF_MULTIPLIER,
    ) -> None:
        self._registry_path = registry_path
        self._threshold_ms = threshold_ms
        self._min_backoff_ms = min_backoff_ms
        self._max_backoff_ms = max_backoff_ms
        self._multiplier = multiplier
        self._latency = LatencyWindow()
        self._current_backoff_ms = min_backoff_ms
        self._inflight_start_ts: float | None = None

    async def pre_wait(self) -> None:
        """Sleep current_backoff_ms trước khi start operation tiếp theo."""
        await asyncio.sleep(self._current_backoff_ms / 1000.0)

    def start(self) -> None:
        """Đánh dấu thời điểm operation bắt đầu."""
        self._inflight_start_ts = time.monotonic()

    def end(self) -> None:
        """Đánh dấu thời điểm operation kết thúc + cập nhật backoff.

        Logic:
            - latency = (now - start_ts) * 1000
            - latency_window.add(latency)
            - p95 = latency_window.p95()
            - if p95 > threshold → backoff *= multiplier (capped at MAX)
            - else → backoff = MIN
        """
        if self._inflight_start_ts is None:
            # end() gọi mà chưa start() — bỏ qua, không raise để tránh crash producer
            return
        now = time.monotonic()
        latency_ms = (now - self._inflight_start_ts) * 1000.0
        self._inflight_start_ts = None

        self._latency.add(latency_ms)
        p95 = self._latency.p95()

        if p95 > self._threshold_ms:
            new_backoff = self._current_backoff_ms * self._multiplier
            self._current_backoff_ms = min(self._max_backoff_ms, new_backoff)
        else:
            self._current_backoff_ms = self._min_backoff_ms

    def current_backoff_ms(self) -> float:
        return self._current_backoff_ms

    def p95_latency_ms(self) -> float:
        """Debug helper: p95 hiện tại."""
        return self._latency.p95()
