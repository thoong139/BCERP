"""test_backpressure.py — Tests cho concurrency.backpressure.

Phạm vi chính:
    - SemaphoreBackpressure happy-path: slot() context manager acquire/release.
    - NOTE-02: inflight() không dùng self._sem._value — đọc từ counter riêng.
    - Constructor guard: max_inflight <= 0 → ValueError.
    - LatencyWindow.add + p95: FIFO, ignore âm, compute quantile.
    - AdaptiveBackpressure: p95 vượt threshold → backoff tăng; giảm → reset.
"""
from __future__ import annotations

import asyncio
from pathlib import Path

import pytest

from concurrency.backpressure import (
    ADAPTIVE_BACKOFF_MAX_MS,
    ADAPTIVE_BACKOFF_MIN_MS,
    ADAPTIVE_BACKOFF_MULTIPLIER,
    ADAPTIVE_LATENCY_THRESHOLD_MS,
    DEFAULT_MAX_INFLIGHT,
    AdaptiveBackpressure,
    LatencyWindow,
    SemaphoreBackpressure,
)


# ──────────────────────────────────────────────────────────────────────
# SemaphoreBackpressure
# ──────────────────────────────────────────────────────────────────────


class TestSemaphoreBackpressure:
    def test_default_max_inflight_constant(self) -> None:
        assert DEFAULT_MAX_INFLIGHT == 24

    def test_constructor_rejects_non_positive(self) -> None:
        with pytest.raises(ValueError, match="max_inflight"):
            SemaphoreBackpressure(0)
        with pytest.raises(ValueError):
            SemaphoreBackpressure(-5)

    def test_slot_happy_path_increments_inflight(self) -> None:
        async def run() -> tuple[int, int]:
            bp = SemaphoreBackpressure(max_inflight=3)
            assert bp.inflight() == 0
            async with bp.slot():
                inside = bp.inflight()
            outside = bp.inflight()
            return inside, outside

        inside, outside = asyncio.run(run())
        assert inside == 1
        assert outside == 0

    def test_slot_note02_counter_matches_expected(self) -> None:
        """NOTE-02 regression: inflight() phải phản ánh chính xác count — không đọc _value."""

        async def run() -> list[int]:
            bp = SemaphoreBackpressure(max_inflight=5)
            counts: list[int] = []
            async with bp.slot():
                counts.append(bp.inflight())  # 1
                async with bp.slot():
                    counts.append(bp.inflight())  # 2
                    async with bp.slot():
                        counts.append(bp.inflight())  # 3
                    counts.append(bp.inflight())  # 2
                counts.append(bp.inflight())  # 1
            counts.append(bp.inflight())  # 0
            return counts

        counts = asyncio.run(run())
        assert counts == [1, 2, 3, 2, 1, 0]

    def test_max_inflight_property(self) -> None:
        bp = SemaphoreBackpressure(max_inflight=7)
        assert bp.max_inflight == 7


# ──────────────────────────────────────────────────────────────────────
# LatencyWindow
# ──────────────────────────────────────────────────────────────────────


class TestLatencyWindow:
    def test_p95_empty_returns_zero(self) -> None:
        w = LatencyWindow()
        assert w.p95() == 0.0
        assert w.size() == 0

    def test_add_negative_ignored(self) -> None:
        w = LatencyWindow()
        w.add(-1.0)
        w.add(-999.0)
        assert w.size() == 0

    def test_fifo_trimming(self) -> None:
        w = LatencyWindow(max_size=3)
        w.add(1.0)
        w.add(2.0)
        w.add(3.0)
        w.add(4.0)
        # Bỏ sample cũ nhất → còn [2,3,4]
        assert w.size() == 3
        assert w.samples_ms == [2.0, 3.0, 4.0]

    def test_p95_simple_distribution(self) -> None:
        w = LatencyWindow()
        for v in range(100):
            w.add(float(v))
        # max_size=50 keeps last 50 samples [50..99]
        # sorted [50..99], len=50, idx = round(0.95 * 49) = 47
        # sorted[47] = 97.0
        assert w.p95() == pytest.approx(97.0)


# ──────────────────────────────────────────────────────────────────────
# AdaptiveBackpressure
# ──────────────────────────────────────────────────────────────────────


class TestAdaptiveBackpressure:
    def test_default_constants(self) -> None:
        assert ADAPTIVE_LATENCY_THRESHOLD_MS == 200.0
        assert ADAPTIVE_BACKOFF_MIN_MS == 10.0
        assert ADAPTIVE_BACKOFF_MAX_MS == 2_000.0
        assert ADAPTIVE_BACKOFF_MULTIPLIER == 2.0

    def test_initial_backoff_is_min(self, tmp_path: Path) -> None:
        ab = AdaptiveBackpressure(registry_path=tmp_path / "registry.json")
        assert ab.current_backoff_ms() == ADAPTIVE_BACKOFF_MIN_MS

    def test_low_latency_keeps_min_backoff(self, tmp_path: Path) -> None:
        ab = AdaptiveBackpressure(registry_path=tmp_path / "r.json")
        # Inject latency thấp bằng cách set start_ts gần now
        import time

        ab._inflight_start_ts = time.monotonic()  # ~0ms latency
        ab.end()
        assert ab.current_backoff_ms() == ADAPTIVE_BACKOFF_MIN_MS

    def test_high_latency_increases_backoff(self, tmp_path: Path) -> None:
        ab = AdaptiveBackpressure(registry_path=tmp_path / "r.json")
        # Fake p95 > threshold bằng cách inject samples trực tiếp
        for _ in range(50):
            ab._latency.add(500.0)  # trên threshold 200
        # Trigger update path bằng end() với start_ts
        import time

        ab._inflight_start_ts = time.monotonic() - 0.5  # ~500ms
        ab.end()
        assert ab.current_backoff_ms() > ADAPTIVE_BACKOFF_MIN_MS

    def test_backoff_capped_at_max(self, tmp_path: Path) -> None:
        ab = AdaptiveBackpressure(registry_path=tmp_path / "r.json")
        ab._current_backoff_ms = ADAPTIVE_BACKOFF_MAX_MS * 10.0
        for _ in range(50):
            ab._latency.add(1000.0)
        import time

        ab._inflight_start_ts = time.monotonic() - 1.0
        ab.end()
        assert ab.current_backoff_ms() <= ADAPTIVE_BACKOFF_MAX_MS

    def test_end_without_start_is_noop(self, tmp_path: Path) -> None:
        ab = AdaptiveBackpressure(registry_path=tmp_path / "r.json")
        # Không crash
        ab.end()
        assert ab.current_backoff_ms() == ADAPTIVE_BACKOFF_MIN_MS
