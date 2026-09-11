"""test_integration.py — Cross-module integration tests cho B2 suite.

Vai trò:
    Đảm bảo các module _shared hoạt động đúng KHI ghép lại, không chỉ khi test
    cô lập. Bù các scenario mà unit tests không cover:

    1. **Cache end-to-end:** fingerprint → set_entry → lookup → hit/miss/stale/expired.
    2. **Signal Bus round-trip + dedup:** nhiều signals cùng target → 1 issue, probe_sources hợp.
    3. **QD3 defense-in-depth:** signal_bus chấp nhận QD3 (phải được triage), nhưng
       cache_store reject QD3 (ADR-22 rule 6) — khi combine, dedup_key của QD3 issue
       vẫn normalize được nhưng KHÔNG được cache.
    4. **Token bucket + Backpressure co-operation:** 3-tier acquire song song với
       semaphore slot trong asyncio.gather — đo không deadlock + tôn trọng cap.
    5. **Full probe pipeline smoke:** file → hash_file → fingerprint → probe giả lập
       trả signals → vào signal_bus + cache_store cùng lúc.

Phạm vi:
    Không mock I/O — dùng tmp_path thật. Test async dùng asyncio.run() để tránh
    phụ thuộc pytest-asyncio plugin.

Tham chiếu:
    - ADR-09 evidence validation
    - ADR-17 concurrency model
    - ADR-19 scan cache
    - ADR-22 rule 3 (token bucket 12/4/6), rule 5 (POST-GATE T1-T4), rule 6 (QD3 no-cache)
"""
from __future__ import annotations

import asyncio
import json
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest

from concurrency.backpressure import SemaphoreBackpressure
from concurrency.token_bucket import (
    DEFAULT_GLOBAL_CAP,
    DEFAULT_INTRA_CAP,
    DEFAULT_LANE_CAP,
    TokenBucket3Tier,
)
from scan_cache.cache_lookup import CacheEntry, is_expired, lookup
from scan_cache.cache_store import QD3_FORBIDDEN, clear_older_than, set_entry
from scan_cache.fingerprint import (
    compute_fingerprint,
    hash_config,
    hash_file_content,
)
from signal_bus.signal_bus import SignalBus, post_gate_check


# ══════════════════════════════════════════════════════════════════════
# HELPER — signal builders
# ══════════════════════════════════════════════════════════════════════


def _make_signal(
    probe_id: str = "P-QD1-demo",
    dimension: str = "QD1",
    file_path: str = "src/example.ts",
    line_range: list[int] | None = None,
    symbol: str = "doThing",
    description: str = "Phát hiện vấn đề chất lượng code đủ 10 ký tự.",
    code_snippet: str = "// Đoạn code mẫu >= 10 ký tự.",
    severity: str = "medium",
) -> dict[str, Any]:
    """Tạo Signal v2 dict hợp lệ — helper để giảm boilerplate."""
    return {
        "$schema": "signal-v2",
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": "2026-04-20T10:00:00+00:00",
        "lane": f"wf-fix-{dimension.lower()}",
        "dimension_id": dimension,
        "target": {
            "kind": "code",
            "file_path": file_path,
            "line_range": line_range or [10, 25],
            "symbol": symbol,
        },
        "description": description,
        "evidence": {
            "code_snippet": code_snippet,
            "screenshot_path": None,
            "log_excerpt": None,
            "stacktrace": None,
            "spec_ref": None,
            "test_failure_ref": None,
        },
        "suggested_severity": severity,
        "dedup_hints": [],
    }


# ══════════════════════════════════════════════════════════════════════
# PART 1 — Cache end-to-end (fingerprint → set → lookup)
# ══════════════════════════════════════════════════════════════════════


class TestCacheEndToEnd:
    """fingerprint + cache_store + cache_lookup — full round-trip."""

    def test_set_then_lookup_hit(self, tmp_path: Path) -> None:
        """Flow: hash file → compute fingerprint → set_entry → lookup HIT."""
        # Tạo source file giả
        src = tmp_path / "module.ts"
        src.write_text("export const x = 1;\n", encoding="utf-8")

        # Hash + fingerprint
        file_sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=file_sha,
        )

        # Set entry
        cache_root = tmp_path / "cache" / "probes"
        signals = [_make_signal()]
        entry_path = set_entry(
            cache_root=cache_root,
            fingerprint=fp,
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=file_sha,
            signals=signals,
        )
        assert entry_path.exists()
        assert entry_path.name == f"{fp}.json"

        # Lookup HIT
        hit = lookup(cache_root, fp, file_sha)
        assert hit is not None
        assert hit.fingerprint == fp
        assert hit.probe_id == "P-QD1-demo"
        assert len(hit.signals_emitted) == 1
        assert hit.signals_emitted[0]["dimension_id"] == "QD1"

    def test_lookup_miss_after_file_content_changed(self, tmp_path: Path) -> None:
        """File content thay đổi → fingerprint khác → MISS (stale detection)."""
        src = tmp_path / "module.ts"
        src.write_text("original", encoding="utf-8")

        sha_v1 = hash_file_content(src)
        fp_v1 = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha_v1,
        )

        cache_root = tmp_path / "cache"
        set_entry(
            cache_root=cache_root,
            fingerprint=fp_v1,
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha_v1,
            signals=[_make_signal()],
        )

        # File thay đổi
        src.write_text("modified content different", encoding="utf-8")
        sha_v2 = hash_file_content(src)
        assert sha_v1 != sha_v2

        # Lookup bằng fingerprint cũ + sha mới → stale, entry bị xóa
        hit = lookup(cache_root, fp_v1, sha_v2)
        assert hit is None
        # File entry cũ đã bị xóa do stale
        assert not (cache_root / f"{fp_v1}.json").exists()

    def test_lookup_miss_when_entry_expired(self, tmp_path: Path) -> None:
        """Manually set ttl_expires_at quá khứ → lookup MISS + xóa entry."""
        src = tmp_path / "m.ts"
        src.write_text("x", encoding="utf-8")
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )

        cache_root = tmp_path / "cache"
        cache_root.mkdir(parents=True)
        expired_entry = {
            "$schema": "cache-entry-v1",
            "fingerprint": fp,
            "probe_id": "P-QD1-demo",
            "probe_version": "1.0.0",
            "file_path": str(src),
            "file_content_sha": sha,
            "config_hash": "",
            "cached_at": "2026-01-01T00:00:00+00:00",
            "ttl_expires_at": "2026-01-02T00:00:00+00:00",  # Đã qua
            "signals_emitted": [],
            "metadata": {},
        }
        entry_path = cache_root / f"{fp}.json"
        entry_path.write_text(json.dumps(expired_entry), encoding="utf-8")

        hit = lookup(cache_root, fp, sha)
        assert hit is None
        assert not entry_path.exists()

    def test_qd3_signal_blocked_before_write(self, tmp_path: Path) -> None:
        """ADR-22 rule 6: QD3 signal → set_entry raise ValueError + không ghi file."""
        src = tmp_path / "auth.ts"
        src.write_text("x", encoding="utf-8")
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD3-security",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )

        cache_root = tmp_path / "cache"
        qd3_signals = [_make_signal(probe_id="P-QD3-security", dimension="QD3")]

        with pytest.raises(ValueError, match=QD3_FORBIDDEN):
            set_entry(
                cache_root=cache_root,
                fingerprint=fp,
                probe_id="P-QD3-security",
                probe_version="1.0.0",
                file_path=str(src),
                file_content_sha=sha,
                signals=qd3_signals,
            )
        # Không ghi file
        assert not (cache_root / f"{fp}.json").exists()

    def test_clear_older_than_prunes_expired_entries(self, tmp_path: Path) -> None:
        """Integration: set_entry + manually aged entry + clear_older_than 7d."""
        cache_root = tmp_path / "cache"

        # Entry mới (giữ lại)
        src_new = tmp_path / "new.ts"
        src_new.write_text("new content", encoding="utf-8")
        sha_new = hash_file_content(src_new)
        fp_new = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src_new),
            file_content_sha=sha_new,
        )
        set_entry(
            cache_root=cache_root,
            fingerprint=fp_new,
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src_new),
            file_content_sha=sha_new,
            signals=[_make_signal()],
        )

        # Entry cũ (giả lập cached_at 30 ngày trước)
        old_cached_at = datetime.now(timezone.utc) - timedelta(days=30)
        old_fp = "b" * 64
        old_entry = {
            "$schema": "cache-entry-v1",
            "fingerprint": old_fp,
            "probe_id": "P-QD1-demo",
            "probe_version": "1.0.0",
            "file_path": "deprecated.ts",
            "file_content_sha": "a" * 64,
            "config_hash": "",
            "cached_at": old_cached_at.isoformat(),
            "ttl_expires_at": (
                old_cached_at + timedelta(days=14)
            ).isoformat(),
            "signals_emitted": [],
            "metadata": {},
        }
        (cache_root / f"{old_fp}.json").write_text(
            json.dumps(old_entry), encoding="utf-8"
        )

        assert len(list(cache_root.glob("*.json"))) == 2
        deleted = clear_older_than(cache_root, older_than_days=7)
        assert deleted == 1
        remaining = list(cache_root.glob("*.json"))
        assert len(remaining) == 1
        assert remaining[0].stem == fp_new

    def test_config_hash_affects_fingerprint(self, tmp_path: Path) -> None:
        """config_hash khác → fingerprint khác → cache không share giữa config versions."""
        src = tmp_path / "m.ts"
        src.write_text("x", encoding="utf-8")
        sha = hash_file_content(src)

        cfg1 = tmp_path / ".eslintrc.v1.json"
        cfg1.write_text('{"rules": {"no-any": "error"}}', encoding="utf-8")
        cfg2 = tmp_path / ".eslintrc.v2.json"
        cfg2.write_text('{"rules": {"no-any": "warn"}}', encoding="utf-8")

        h1 = hash_config([cfg1])
        h2 = hash_config([cfg2])
        assert h1 != h2

        fp1 = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
            config_hash=h1,
        )
        fp2 = compute_fingerprint(
            probe_id="P-QD1-demo",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
            config_hash=h2,
        )
        assert fp1 != fp2


# ══════════════════════════════════════════════════════════════════════
# PART 2 — Signal Bus round-trip + dedup
# ══════════════════════════════════════════════════════════════════════


class TestSignalBusDedupIntegration:
    """SignalBus ingest nhiều signals → verify dedup + POST-GATE pass."""

    def test_dedup_merges_probe_sources(self, tmp_path: Path) -> None:
        """3 signals cùng target nhưng 3 probes khác → 1 issue với 3 probe_sources."""
        bus = SignalBus(tmp_path)
        bus.load_existing()

        # Same target (file + line_range + symbol), different probe_id
        targets_args = dict(
            file_path="src/auth/login.ts",
            line_range=[10, 25],
            symbol="login",
            dimension="QD1",
        )
        s1 = _make_signal(probe_id="P-QD1-bug-detect", **targets_args)
        s2 = _make_signal(probe_id="P-QD1-lint-suite", **targets_args)
        s3 = _make_signal(probe_id="P-QD1-ts-strict", **targets_args)

        bus.ingest(s1)
        bus.ingest(s2)
        bus.ingest(s3)

        assert len(bus.issues) == 1
        issue = bus.issues[0]
        # Probe sources hợp (có thể là dict với probe_id+version hoặc string)
        # Convert to set of probe_ids
        pids = {
            src.get("probe_id") if isinstance(src, dict) else src
            for src in issue.probe_sources
        }
        assert pids == {"P-QD1-bug-detect", "P-QD1-lint-suite", "P-QD1-ts-strict"}

    def test_different_line_range_appends_new_issue(self, tmp_path: Path) -> None:
        """Cùng file + symbol nhưng khác line_range → 2 issues riêng."""
        bus = SignalBus(tmp_path)
        bus.load_existing()

        s1 = _make_signal(
            file_path="src/service.ts",
            line_range=[10, 20],
            symbol="doA",
        )
        s2 = _make_signal(
            file_path="src/service.ts",
            line_range=[50, 70],
            symbol="doA",
        )

        bus.ingest(s1)
        bus.ingest(s2)
        assert len(bus.issues) == 2

    def test_flush_passes_post_gate_t1_t4(self, tmp_path: Path) -> None:
        """Flush writes registry, POST-GATE T1-T4 pass."""
        bus = SignalBus(tmp_path)
        bus.load_existing()
        bus.ingest(_make_signal(file_path="src/a.ts", symbol="fa"))
        bus.ingest(_make_signal(file_path="src/b.ts", symbol="fb"))

        registry_path = bus.flush()
        assert registry_path.exists()

        # Verify POST-GATE check idempotent
        ok, errors = post_gate_check(registry_path)
        assert ok is True, f"POST-GATE failed: {errors}"

        # Verify registry content
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data["$schema"] == "issue-registry-v2"
        assert len(data["issues"]) == 2

    def test_load_existing_then_ingest_preserves_issues(self, tmp_path: Path) -> None:
        """Session 1 ingest+flush → Session 2 load+ingest → tổng hợp issues."""
        # Session 1
        bus1 = SignalBus(tmp_path)
        bus1.load_existing()
        bus1.ingest(_make_signal(file_path="src/mod1.ts", symbol="fn1"))
        bus1.flush()

        # Session 2
        bus2 = SignalBus(tmp_path)
        bus2.load_existing()
        assert len(bus2.issues) == 1  # Load từ disk
        bus2.ingest(_make_signal(file_path="src/mod2.ts", symbol="fn2"))
        bus2.flush()

        # Registry có cả 2 issues
        data = json.loads(bus2.registry_path.read_text(encoding="utf-8"))
        assert len(data["issues"]) == 2

    def test_rejects_signal_with_insufficient_evidence(
        self, tmp_path: Path
    ) -> None:
        """ADR-09: evidence code_snippet < 10 chars → raise ValueError trước khi ingest."""
        bus = SignalBus(tmp_path)
        bus.load_existing()
        bad = _make_signal(code_snippet="// hi")  # < 10 chars
        with pytest.raises(ValueError):
            bus.ingest(bad)
        assert len(bus.issues) == 0  # Không add vào registry


# ══════════════════════════════════════════════════════════════════════
# PART 3 — QD3 defense-in-depth (signal_bus accepts, cache_store rejects)
# ══════════════════════════════════════════════════════════════════════


class TestQd3DefenseInDepth:
    """QD3 có thể được normalize thành Issue (phải triage), NHƯNG không được cache."""

    def test_qd3_signal_normalizes_to_issue_with_cdg_required(
        self, tmp_path: Path
    ) -> None:
        """QD3 signal với secrets hint → triage_status='cdg_required'."""
        bus = SignalBus(tmp_path)
        bus.load_existing()

        qd3_signal = _make_signal(
            probe_id="P-QD3-secret-scan",
            dimension="QD3",
            file_path="src/config.ts",
            symbol="loadConfig",
            code_snippet='const api_key = "sk-live-123456";',
        )
        issue = bus.ingest(qd3_signal)
        # Vì có secret hint ("api_key") → CDG required
        assert issue.triage_status == "cdg_required"
        assert "QD3" in issue.dimensions

    def test_qd3_set_entry_rejected_even_if_normalized_ok(
        self, tmp_path: Path
    ) -> None:
        """QD3 signal đã pass signal_bus, nhưng cache_store vẫn reject."""
        bus = SignalBus(tmp_path)
        bus.load_existing()
        qd3 = _make_signal(
            probe_id="P-QD3-secret-scan",
            dimension="QD3",
            code_snippet="// normal qd3 snippet >= 10 char",
        )
        bus.ingest(qd3)  # OK — signal_bus accepts QD3

        # Now try to cache the same signal list → cache_store MUST reject
        cache_root = tmp_path / "cache"
        src = tmp_path / "auth.ts"
        src.write_text("x", encoding="utf-8")
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD3-secret-scan",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )
        with pytest.raises(ValueError, match="QD3"):
            set_entry(
                cache_root=cache_root,
                fingerprint=fp,
                probe_id="P-QD3-secret-scan",
                probe_version="1.0.0",
                file_path=str(src),
                file_content_sha=sha,
                signals=[qd3],
            )

    def test_qd3_mixed_with_qd1_still_rejects_all(self, tmp_path: Path) -> None:
        """Nếu list signals có BẤT KỲ QD3 nào → toàn bộ list bị reject khi cache."""
        cache_root = tmp_path / "cache"
        src = tmp_path / "m.ts"
        src.write_text("x", encoding="utf-8")
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD1-mixed",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )
        mixed = [
            _make_signal(dimension="QD1"),
            _make_signal(probe_id="P-QD3-x", dimension="QD3"),
            _make_signal(dimension="QD2", probe_id="P-QD2-y"),
        ]
        with pytest.raises(ValueError, match="QD3"):
            set_entry(
                cache_root=cache_root,
                fingerprint=fp,
                probe_id="P-QD1-mixed",
                probe_version="1.0.0",
                file_path=str(src),
                file_content_sha=sha,
                signals=mixed,
            )


# ══════════════════════════════════════════════════════════════════════
# PART 4 — Token bucket + Backpressure co-operation (async stress)
# ══════════════════════════════════════════════════════════════════════


class TestConcurrencyIntegration:
    """TokenBucket3Tier + SemaphoreBackpressure chạy song song không deadlock."""

    def test_3tier_defaults_match_adr22_rule3(self) -> None:
        """ADR-22 rule 3: default 12/4/6 không đổi."""
        tb = TokenBucket3Tier()
        snap = tb.snapshot()
        assert snap["global"] == float(DEFAULT_GLOBAL_CAP)
        # lanes/probes lazy — rỗng lúc đầu
        assert snap["lanes"] == {}
        assert snap["probes"] == {}

    def test_tb_and_semaphore_compose_without_deadlock(self) -> None:
        """3-tier acquire wrap bằng semaphore slot — 12 workers fit within caps (global=12, lane=4×3, probe=6×2)."""
        tb = TokenBucket3Tier()
        sem = SemaphoreBackpressure(max_inflight=8)

        counter = {"done": 0, "timeout": 0}
        # 12 workers: lane = wid % 4 (3 workers/lane, ≤ lane_cap=4),
        # probe = wid % 6 (2 workers/probe, ≤ intra_cap=6). Tổng 12 ≤ global_cap=12.
        # Token bucket refill chậm (4/60s ≈ 0.067 tok/s), chỉ fit trong burst đầu.
        N = 12

        async def worker(wid: int) -> None:
            try:
                async with sem.slot():
                    async with tb.acquire(
                        lane_id=f"lane-{wid % 4}",
                        probe_id=f"probe-{wid % 6}",
                        timeout_ms=5_000,
                    ):
                        # Giả lập công việc ngắn
                        await asyncio.sleep(0.005)
                        counter["done"] += 1
            except TimeoutError:
                counter["timeout"] += 1

        async def run() -> None:
            await asyncio.gather(*(worker(i) for i in range(N)))

        asyncio.run(run())
        # 12 ≤ caps → tất cả phải hoàn thành (burst đầu tiên).
        assert counter["timeout"] == 0
        assert counter["done"] == N

    def test_semaphore_inflight_never_exceeds_max(self) -> None:
        """NOTE-02: inflight counter chính xác, không bao giờ vượt max_inflight."""
        sem = SemaphoreBackpressure(max_inflight=3)
        observed_max = {"val": 0}

        async def worker() -> None:
            async with sem.slot():
                observed_max["val"] = max(observed_max["val"], sem.inflight())
                await asyncio.sleep(0.01)

        async def run() -> None:
            await asyncio.gather(*(worker() for _ in range(10)))

        asyncio.run(run())
        assert observed_max["val"] <= 3
        # Sau khi xong, inflight phải về 0
        assert sem.inflight() == 0

    def test_3tier_lanes_isolated(self) -> None:
        """Mỗi lane có bucket riêng — lane-A không ảnh hưởng lane-B (trong giới hạn global)."""
        tb = TokenBucket3Tier()

        async def acquire_on(lane: str, probe: str) -> None:
            async with tb.acquire(lane_id=lane, probe_id=probe, timeout_ms=2_000):
                await asyncio.sleep(0.001)

        async def run() -> None:
            # 4 concurrent cùng lane-A (max lane_cap=4 → OK)
            # + 4 concurrent cùng lane-B (max lane_cap=4 → OK)
            # Tổng 8 ≤ global_cap=12 → không deadlock
            await asyncio.gather(
                *[acquire_on("lane-A", f"probe-A-{i}") for i in range(4)],
                *[acquire_on("lane-B", f"probe-B-{i}") for i in range(4)],
            )

        # Không raise → pass
        asyncio.run(run())

    def test_3tier_override_rejected_at_construction(self) -> None:
        """ADR-22 rule 3: override default 12/4/6 → ValueError."""
        with pytest.raises(ValueError, match="ADR-22 rule 3"):
            TokenBucket3Tier(global_cap=20, lane_cap=4, intra_cap=6)
        with pytest.raises(ValueError, match="ADR-22 rule 3"):
            TokenBucket3Tier(global_cap=12, lane_cap=8, intra_cap=6)
        with pytest.raises(ValueError, match="ADR-22 rule 3"):
            TokenBucket3Tier(
                global_cap=DEFAULT_GLOBAL_CAP,
                lane_cap=DEFAULT_LANE_CAP,
                intra_cap=DEFAULT_INTRA_CAP + 1,
            )


# ══════════════════════════════════════════════════════════════════════
# PART 5 — Full probe pipeline smoke
# ══════════════════════════════════════════════════════════════════════


class TestFullProbePipelineSmoke:
    """Mô phỏng end-to-end flow của 1 probe run:

    1. file on disk
    2. hash_file_content → file_content_sha
    3. compute_fingerprint
    4. probe "chạy" → trả list signals
    5. signal_bus.ingest → normalize → merge → flush
    6. cache_store.set_entry (nếu không phải QD3) → lookup lại → hit
    """

    def test_qd1_probe_writes_both_registry_and_cache(self, tmp_path: Path) -> None:
        """QD1 signal → vào cả issue-registry và cache."""
        # 1. Source file
        src = tmp_path / "src" / "service.ts"
        src.parent.mkdir(parents=True)
        src.write_text(
            "export function login(user: string) { return user; }\n",
            encoding="utf-8",
        )

        # 2. Hash
        sha = hash_file_content(src)
        # 3. Fingerprint
        fp = compute_fingerprint(
            probe_id="P-QD1-bug-detect",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )

        # 4. Probe output
        signals = [
            _make_signal(
                probe_id="P-QD1-bug-detect",
                dimension="QD1",
                file_path=str(src),
                symbol="login",
            )
        ]

        # 5. Signal Bus
        session_dir = tmp_path / "session"
        session_dir.mkdir()
        bus = SignalBus(session_dir)
        bus.load_existing()
        issue = bus.ingest(signals[0])
        registry_path = bus.flush()
        assert registry_path.exists()
        assert issue.issue_id.startswith("ISS-")

        # 6. Cache
        cache_root = tmp_path / "cache"
        entry_path = set_entry(
            cache_root=cache_root,
            fingerprint=fp,
            probe_id="P-QD1-bug-detect",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
            signals=signals,
        )
        assert entry_path.exists()

        # Lookup round-trip
        hit = lookup(cache_root, fp, sha)
        assert hit is not None
        assert hit.probe_id == "P-QD1-bug-detect"
        assert len(hit.signals_emitted) == 1

    def test_qd3_probe_writes_registry_but_not_cache(self, tmp_path: Path) -> None:
        """QD3 signal → vào registry (cdg_required) NHƯNG cache_store reject."""
        src = tmp_path / "auth.ts"
        src.write_text(
            'const secret = "sk-prod-123"; export default secret;\n',
            encoding="utf-8",
        )
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD3-secret-scan",
            probe_version="1.0.0",
            file_path=str(src),
            file_content_sha=sha,
        )

        signal = _make_signal(
            probe_id="P-QD3-secret-scan",
            dimension="QD3",
            file_path=str(src),
            symbol="secret",
            code_snippet='const secret = "sk-prod-123456";',
        )

        # Signal Bus: chấp nhận QD3, mark cdg_required
        session_dir = tmp_path / "session"
        session_dir.mkdir()
        bus = SignalBus(session_dir)
        bus.load_existing()
        issue = bus.ingest(signal)
        assert issue.triage_status == "cdg_required"
        bus.flush()

        # Cache: reject QD3
        cache_root = tmp_path / "cache"
        with pytest.raises(ValueError, match="QD3"):
            set_entry(
                cache_root=cache_root,
                fingerprint=fp,
                probe_id="P-QD3-secret-scan",
                probe_version="1.0.0",
                file_path=str(src),
                file_content_sha=sha,
                signals=[signal],
            )
        # Không có file cache
        assert not (cache_root / f"{fp}.json").exists()


# ══════════════════════════════════════════════════════════════════════
# PART 6 — CacheEntry schema contract
# ══════════════════════════════════════════════════════════════════════


class TestCacheEntrySchemaContract:
    """Đảm bảo CacheEntry.from_json ⇄ set_entry schema consistency."""

    def test_set_entry_output_parseable_by_cache_entry(self, tmp_path: Path) -> None:
        """set_entry ghi schema mà CacheEntry.from_json parse được trực tiếp."""
        src = tmp_path / "m.ts"
        src.write_text("ok", encoding="utf-8")
        sha = hash_file_content(src)
        fp = compute_fingerprint(
            probe_id="P-QD2-contract",
            probe_version="2.0.1",
            file_path=str(src),
            file_content_sha=sha,
        )
        cache_root = tmp_path / "cache"
        entry_path = set_entry(
            cache_root=cache_root,
            fingerprint=fp,
            probe_id="P-QD2-contract",
            probe_version="2.0.1",
            file_path=str(src),
            file_content_sha=sha,
            signals=[_make_signal(dimension="QD2", probe_id="P-QD2-contract")],
            metadata={"elapsed_ms": 42},
        )
        raw = json.loads(entry_path.read_text(encoding="utf-8"))
        entry = CacheEntry.from_json(raw)
        assert entry.fingerprint == fp
        assert entry.probe_id == "P-QD2-contract"
        assert entry.probe_version == "2.0.1"
        assert entry.metadata == {"elapsed_ms": 42}
        assert is_expired(entry) is False

    def test_manually_aged_entry_detected_expired(self, tmp_path: Path) -> None:
        """is_expired() trả True cho entry đã quá hạn."""
        entry = CacheEntry(
            fingerprint="a" * 64,
            probe_id="P-QD1-x",
            probe_version="1.0.0",
            file_path="src/x.ts",
            file_content_sha="b" * 64,
            cached_at="2020-01-01T00:00:00+00:00",
            ttl_expires_at="2020-01-02T00:00:00+00:00",
            signals_emitted=[],
        )
        assert is_expired(entry) is True
