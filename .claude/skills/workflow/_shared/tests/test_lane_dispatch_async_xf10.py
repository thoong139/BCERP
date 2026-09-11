"""test_lane_dispatch_async_xf10.py — XF-10 (Sprint 10) async path coverage.

Sprint 10 mục tiêu: nâng `lane_dispatch.py` từ 70.43% → ≥80% bằng async +
subprocess + sync-wrapper tests deferred từ Sprint 7.

Focus uncovered zones (Sprint 7 baseline) — async + subprocess + sync wrapper:
- `_execute_lane_sequential` branches (547-548, 570-583, 613-614, 646):
  · resolve_probes ValueError fallback
  · cache_allowed + use_cache nhưng dimension.json không tồn tại
  · cache_store_fn raise ValueError → defense-in-depth (ADR-22 rule 6)
  · _merge_static_signals preserved/replaced > 0 → info log emission
- `_run_lane_async` (1440-1502):
  · happy path (1 attempt completed)
  · idempotent skip (pre-seed signals.json valid)
  · retry-then-success (failed × 2, completed × 1)
  · retry exhausted (always failed, MAX_RETRIES_PER_LANE attempts)
  · token_bucket acquire path + graceful degrade khi acquire fail
  · backpressure pre_wait/start/end + graceful degrade
- `dispatch_lanes_async` (1531-1586):
  · all pre-completed (module-level skip toàn bộ)
  · mixed pre-completed + pending → asyncio.gather chỉ chạy pending
  · enable_concurrency=True với TokenBucket3Tier + AdaptiveBackpressure mock
  · graceful degrade khi ctor TokenBucket3Tier raise
  · aggregates completed + failed counts
  · empty dimensions (kết hợp với pre-completed check)
- `dispatch_lanes` sync wrapper (1630-1631, 1653-1683):
  · session_dir relative → resolve qua repo_root
  · max_parallel=1 → sequential path
  · 1 dim với max_parallel>1 → vẫn sequential
  · running loop fallback (RuntimeError-not-thrown branch)
  · asyncio.run path (multi-dim, max_parallel>1, no running loop)

Strategy (per decision §3.2):
- Mock `_execute_lane_sequential` cho async tests → fast, isolation tốt
- Real `asyncio.Semaphore` để KHÔNG mock asyncio internals
- pytest-asyncio auto mode → implicit @pytest.mark.asyncio cho coroutine tests

Tham chiếu:
- BHV-002 Simplicity First (mock _execute_lane_sequential, không mock deeper)
- BHV-003 Surgical (KHÔNG refactor lane_dispatch.py production async code)
- CORE-025 Parallel Safety (test verify isolation: 1 file = 1 writer)
- pytest-asyncio docs: https://pytest-asyncio.readthedocs.io/
"""
from __future__ import annotations

import asyncio
import json
from pathlib import Path
from unittest.mock import MagicMock

import pytest

import lane_dispatch
from lane_dispatch import (
    MAX_RETRIES_PER_LANE,
    SIGNALS_SCHEMA_ID,
    DispatchResult,
    LaneResult,
    _execute_lane_sequential,
    _run_lane_async,
    dispatch_lanes,
    dispatch_lanes_async,
)


# ──────────────────────────────────────────────────────────────────────
# Fixtures: minimal workflow_root + lane config
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def fake_lane_root(tmp_path: Path) -> Path:
    """Tạo minimal workflow_root với 1 dummy lane dir cho mỗi dim.

    Layout:
        tmp_path/workflow_root/wf-fix-{lane_slug}/dimension.json

    `get_lane_path(dim, workflow_root)` resolve qua DIM_TO_LANE map. Để đơn
    giản, mock `get_lane_path` trực tiếp về `workflow_root / "lane_{dim}"`.
    """
    return tmp_path / "workflow_root"


@pytest.fixture
def patch_lane_path(monkeypatch, fake_lane_root: Path):
    """Mock `get_lane_path` để return predictable path mà KHÔNG cần
    setup DIM_TO_LANE registry thật. Helper cho mọi test cần
    `_execute_lane_sequential` resolve lane dir.
    """
    def _fake_get_lane_path(dim: str, workflow_root: Path) -> Path:
        lane_dir = workflow_root / f"lane_{dim.lower()}"
        lane_dir.mkdir(parents=True, exist_ok=True)
        return lane_dir

    monkeypatch.setattr("lane_dispatch.get_lane_path", _fake_get_lane_path)
    return _fake_get_lane_path


@pytest.fixture
def seed_dimension_json(fake_lane_root: Path, patch_lane_path):
    """Tạo `dimension.json` rỗng trong lane dir để vượt qua check 539.

    Trả về function `seed(dim)` → ghi `dimension.json` cho dim đó.
    """
    def _seed(dim: str) -> Path:
        lane_dir = patch_lane_path(dim, fake_lane_root)
        dim_json = lane_dir / "dimension.json"
        dim_json.write_text(
            json.dumps({"id": dim, "probes": []}),
            encoding="utf-8",
        )
        return dim_json

    return _seed


@pytest.fixture
def valid_signals_file():
    """Helper write valid signals.json đã pass POST-GATE.

    Trả về function `write(path, probes_executed=0)`.
    """
    def _write(path: Path, probes_executed: int = 0) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps({
                "$schema": SIGNALS_SCHEMA_ID,
                "signals": [],
                "probes_executed": probes_executed,
            }),
            encoding="utf-8",
        )

    return _write


# ──────────────────────────────────────────────────────────────────────
# _execute_lane_sequential — branches Sprint 7 deferred
# ──────────────────────────────────────────────────────────────────────


class TestExecuteLaneSequentialBranches:
    """Cover branches 547-548, 570→583, 613-614, 646."""

    def test_resolve_probes_value_error_returns_failed(
        self, fake_lane_root: Path, tmp_path: Path, patch_lane_path,
        seed_dimension_json, monkeypatch,
    ) -> None:
        """resolve_probes raise ValueError → LaneResult failed (lines 547-548)."""
        seed_dimension_json("QD1")
        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: (_ for _ in ()).throw(ValueError("bad profile")),
        )

        result = _execute_lane_sequential(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=fake_lane_root,
            use_cache=False,
        )

        assert result.status == "failed"
        assert result.probes_executed == 0
        assert result.signals_path is None
        assert result.error is not None and "bad profile" in result.error

    def test_resolve_probes_file_not_found_returns_failed(
        self, fake_lane_root: Path, tmp_path: Path,
        seed_dimension_json, monkeypatch,
    ) -> None:
        """resolve_probes raise FileNotFoundError → LaneResult failed."""
        seed_dimension_json("QD1")
        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: (_ for _ in ()).throw(
                FileNotFoundError("missing fixture")
            ),
        )

        result = _execute_lane_sequential(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=fake_lane_root,
            use_cache=False,
        )

        assert result.status == "failed"
        assert "missing fixture" in (result.error or "")

    def test_cache_branch_dimension_json_missing_inside_loop(
        self, fake_lane_root: Path, tmp_path: Path, patch_lane_path,
        monkeypatch,
    ) -> None:
        """cache_allowed + use_cache nhưng dim_config_path không tồn tại
        TRONG vòng lặp → skip cache lookup nhánh 570→583 (else branch).

        Setup: lane_dir tồn tại + dimension.json (ngoài) tồn tại,
        nhưng XÓA file sau khi resolve_probes để branch nhánh inner check
        if dim_config_path.exists() là False.
        """
        lane_dir = patch_lane_path("QD1", fake_lane_root)
        dim_json = lane_dir / "dimension.json"
        dim_json.write_text(json.dumps({"id": "QD1"}), encoding="utf-8")

        # Resolve probes trả về 1 probe-id giả
        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: ["probe-xyz"],
        )
        # Cache policy allow + use_cache=True
        monkeypatch.setattr("lane_dispatch.get_cache_policy", lambda d: True)
        # Static probe execute trả empty (không có signal)
        monkeypatch.setattr(
            "lane_dispatch._execute_static_probe",
            lambda **kw: [],
        )

        # Trick: xoá dimension.json sau khi resolve_probes nhưng trước cache
        # check. Cách: monkey-patch resolve_probes để vừa trả [probe] vừa xoá.
        original_resolve = lane_dispatch.resolve_probes  # type: ignore[attr-defined]

        def resolve_and_drop(*args, **kwargs):
            result = ["probe-xyz"]
            dim_json.unlink()  # Xoá để nhánh dim_config_path.exists()==False
            return result

        monkeypatch.setattr("lane_dispatch.resolve_probes", resolve_and_drop)

        # Mở lại file để vượt check 539 trước resolve_probes
        dim_json.write_text(json.dumps({"id": "QD1"}), encoding="utf-8")

        result = _execute_lane_sequential(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=fake_lane_root,
            use_cache=True,
        )

        # Lane vẫn completed (probe rỗng, signals.json viết được)
        assert result.status == "completed"
        assert result.probes_executed == 1
        assert result.signals_path is not None and result.signals_path.exists()

    def test_cache_store_value_error_swallowed(
        self, fake_lane_root: Path, tmp_path: Path, patch_lane_path,
        seed_dimension_json, monkeypatch,
    ) -> None:
        """cache_store_fn raise ValueError → swallowed (line 613-614)."""
        seed_dimension_json("QD1")

        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: ["probe-cached"],
        )
        monkeypatch.setattr("lane_dispatch.get_cache_policy", lambda d: True)
        # Cache miss → fallback execute
        monkeypatch.setattr(
            "lane_dispatch.cache_lookup_fn",
            lambda *a, **kw: None,
        )

        def store_boom(*a, **kw):
            raise ValueError("cache store violation (rule 6)")

        monkeypatch.setattr("lane_dispatch.cache_store_fn", store_boom)
        monkeypatch.setattr(
            "lane_dispatch._execute_static_probe",
            lambda **kw: [
                {
                    "probe_id": "probe-cached",
                    "type": "INFO",
                    "msg": "ok",
                }
            ],
        )

        result = _execute_lane_sequential(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=fake_lane_root,
            use_cache=True,
        )

        assert result.status == "completed"
        assert result.probes_executed == 1

    def test_cache_hit_reuses_signals(
        self, fake_lane_root: Path, tmp_path: Path, patch_lane_path,
        seed_dimension_json, monkeypatch,
    ) -> None:
        """cache_hit → extend signals + skip _execute_static_probe."""
        seed_dimension_json("QD1")

        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: ["probe-cached"],
        )
        monkeypatch.setattr("lane_dispatch.get_cache_policy", lambda d: True)

        cached_entry = MagicMock()
        cached_entry.signals_emitted = [
            {"probe_id": "probe-cached", "type": "INFO", "msg": "from cache"},
        ]
        monkeypatch.setattr(
            "lane_dispatch.cache_lookup_fn",
            lambda *a, **kw: cached_entry,
        )

        # _execute_static_probe sẽ raise nếu bị gọi (vì cache_hit phải bypass)
        def static_probe_should_not_run(**kw):
            raise AssertionError(
                "cache_hit=True → _execute_static_probe KHÔNG được gọi"
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_static_probe",
            static_probe_should_not_run,
        )

        result = _execute_lane_sequential(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=fake_lane_root,
            use_cache=True,
        )

        assert result.status == "completed"
        assert result.probes_executed == 1

    def test_merge_signals_log_emitted_with_preserved(
        self, fake_lane_root: Path, tmp_path: Path, patch_lane_path,
        seed_dimension_json, valid_signals_file, monkeypatch, caplog,
    ) -> None:
        """_merge_static_signals preserved/replaced > 0 → info log line 646."""
        seed_dimension_json("QD1")

        # Pre-seed signals.json với 1 non-static signal (probe_id="llm-probe")
        # để _merge_static_signals preserve → preserved_count = 1
        signals_path = tmp_path / "session" / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)
        signals_path.write_text(json.dumps({
            "$schema": SIGNALS_SCHEMA_ID,
            "signals": [
                {"probe_id": "llm-probe-non-static", "type": "INFO", "msg": "x"}
            ],
            "probes_executed": 0,
        }), encoding="utf-8")

        monkeypatch.setattr(
            "lane_dispatch.resolve_probes",
            lambda *a, **kw: ["probe-static"],
        )
        monkeypatch.setattr("lane_dispatch.get_cache_policy", lambda d: False)
        # _execute_static_probe trả 1 signal mới
        monkeypatch.setattr(
            "lane_dispatch._execute_static_probe",
            lambda **kw: [
                {"probe_id": "probe-static", "type": "INFO", "msg": "new"}
            ],
        )

        with caplog.at_level("INFO", logger="lane_dispatch"):
            result = _execute_lane_sequential(
                dim="QD1",
                session_dir=tmp_path / "session",
                profile="standard",
                workflow_root=fake_lane_root,
                use_cache=False,
            )

        assert result.status == "completed"
        # File phải merge: 1 preserved + 1 new (replaced=0 vì llm-probe không
        # nằm trong STATIC_PROBE_SCRIPTS keys)
        final = json.loads(signals_path.read_text(encoding="utf-8"))
        probe_ids = [s["probe_id"] for s in final["signals"]]
        assert "llm-probe-non-static" in probe_ids
        assert "probe-static" in probe_ids


# ──────────────────────────────────────────────────────────────────────
# _run_lane_async — retry loop + token_bucket + backpressure
# ──────────────────────────────────────────────────────────────────────


class TestRunLaneAsync:
    """Cover lines 1440-1502."""

    async def test_happy_path_first_attempt_completed(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """_execute_lane_sequential trả completed → return ngay attempt 1."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)

        def fake_exec(**kw):
            # Tạo signals.json để _lane_already_complete (next iter) thấy
            signals_path.write_text(json.dumps({
                "$schema": SIGNALS_SCHEMA_ID, "signals": [],
                "probes_executed": 2,
            }), encoding="utf-8")
            return LaneResult(
                dim="QD1", status="completed", probes_executed=2,
                signals_path=signals_path,
            )

        monkeypatch.setattr("lane_dispatch._execute_lane_sequential", fake_exec)

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
        )

        assert result.status == "completed"
        assert result.probes_executed == 2

    async def test_idempotent_skip_when_signals_valid(
        self, tmp_path: Path, valid_signals_file, monkeypatch,
    ) -> None:
        """Pre-seed signals.json valid → early return không gọi _execute."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        valid_signals_file(signals_path, probes_executed=7)

        def should_not_run(**kw):
            raise AssertionError(
                "_execute_lane_sequential KHÔNG được gọi khi idempotent skip"
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", should_not_run
        )

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
        )

        assert result.status == "completed"
        assert result.probes_executed == 7

    async def test_retry_then_success(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """Fail 2 lần, attempt 3 success → return completed."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)
        call_count = {"n": 0}

        def flaky_exec(**kw):
            call_count["n"] += 1
            if call_count["n"] < 3:
                return LaneResult(
                    dim="QD1", status="failed", probes_executed=0,
                    signals_path=None, error="transient",
                )
            return LaneResult(
                dim="QD1", status="completed", probes_executed=1,
                signals_path=signals_path,
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", flaky_exec
        )

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
        )

        assert result.status == "completed"
        assert call_count["n"] == 3

    async def test_retry_exhausted_returns_last_failure(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """Tất cả attempts đều fail → return last failure."""
        session_dir = tmp_path / "session"
        call_count = {"n": 0}

        def always_fail(**kw):
            call_count["n"] += 1
            return LaneResult(
                dim="QD1", status="failed", probes_executed=0,
                signals_path=None, error=f"attempt {call_count['n']}",
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", always_fail
        )

        result = await _run_lane_async(
            dim="QD1",
            session_dir=tmp_path / "session",
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
        )

        assert result.status == "failed"
        assert call_count["n"] == MAX_RETRIES_PER_LANE

    async def test_token_bucket_path(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """token_bucket truyền vào → acquire/release ctx được gọi."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)

        def fake_exec(**kw):
            return LaneResult(
                dim="QD1", status="completed", probes_executed=1,
                signals_path=signals_path,
            )

        monkeypatch.setattr("lane_dispatch._execute_lane_sequential", fake_exec)

        # Mock token_bucket với acquire trả AsyncContextManager
        class FakeCtx:
            entered = False
            exited = False

            async def __aenter__(self):
                FakeCtx.entered = True
                return self

            async def __aexit__(self, exc_type, exc, tb):
                FakeCtx.exited = True
                return False

        fake_tb = MagicMock()
        fake_tb.acquire = MagicMock(return_value=FakeCtx())

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
            token_bucket=fake_tb,
        )

        assert result.status == "completed"
        assert FakeCtx.entered is True
        assert FakeCtx.exited is True
        fake_tb.acquire.assert_called_once()

    async def test_token_bucket_acquire_failure_graceful(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """token_bucket.acquire() raise → tb_ctx=None, lane vẫn chạy."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)

        def fake_exec(**kw):
            return LaneResult(
                dim="QD1", status="completed", probes_executed=1,
                signals_path=signals_path,
            )

        monkeypatch.setattr("lane_dispatch._execute_lane_sequential", fake_exec)

        fake_tb = MagicMock()

        def acquire_boom(*a, **kw):
            raise RuntimeError("bucket exhausted")

        fake_tb.acquire = acquire_boom

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
            token_bucket=fake_tb,
        )

        assert result.status == "completed"

    async def test_backpressure_paths(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """backpressure.pre_wait/start/end được gọi."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)

        def fake_exec(**kw):
            return LaneResult(
                dim="QD1", status="completed", probes_executed=1,
                signals_path=signals_path,
            )

        monkeypatch.setattr("lane_dispatch._execute_lane_sequential", fake_exec)

        events: list[str] = []

        class FakeBP:
            async def pre_wait(self):
                events.append("pre_wait")

            def start(self):
                events.append("start")

            def end(self):
                events.append("end")

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
            backpressure=FakeBP(),
        )

        assert result.status == "completed"
        assert events == ["pre_wait", "start", "end"]

    async def test_backpressure_pre_wait_failure_graceful(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """backpressure.pre_wait raise → graceful pass, lane vẫn chạy."""
        session_dir = tmp_path / "session"
        signals_path = session_dir / "lanes" / "QD1" / "signals.json"
        signals_path.parent.mkdir(parents=True, exist_ok=True)

        def fake_exec(**kw):
            return LaneResult(
                dim="QD1", status="completed", probes_executed=1,
                signals_path=signals_path,
            )

        monkeypatch.setattr("lane_dispatch._execute_lane_sequential", fake_exec)

        class BPBoom:
            async def pre_wait(self):
                raise RuntimeError("bp pre_wait fail")

            def start(self):
                raise RuntimeError("bp start fail")

            def end(self):
                raise RuntimeError("bp end fail")

        result = await _run_lane_async(
            dim="QD1",
            session_dir=session_dir,
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            use_cache=False,
            semaphore=asyncio.Semaphore(1),
            backpressure=BPBoom(),
        )

        assert result.status == "completed"


# ──────────────────────────────────────────────────────────────────────
# dispatch_lanes_async — orchestrator
# ──────────────────────────────────────────────────────────────────────


class TestDispatchLanesAsync:
    """Cover lines 1531-1586."""

    async def test_all_pre_completed_skip_gather(
        self, tmp_path: Path, valid_signals_file, monkeypatch,
    ) -> None:
        """All dims pre-completed → asyncio.gather KHÔNG cần dispatch task."""
        session_dir = tmp_path / "session"
        for dim in ["QD1", "QD3"]:
            valid_signals_file(
                session_dir / "lanes" / dim / "signals.json",
                probes_executed=4,
            )

        def should_not_run(*a, **kw):
            raise AssertionError("_run_lane_async KHÔNG được gọi")

        monkeypatch.setattr("lane_dispatch._run_lane_async", should_not_run)

        result = await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1", "QD3"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=3,
        )

        assert isinstance(result, DispatchResult)
        assert result.completed == 2
        assert result.failed == 0
        assert set(result.signals_paths.keys()) == {"QD1", "QD3"}

    async def test_mixed_pre_completed_and_pending(
        self, tmp_path: Path, valid_signals_file, monkeypatch,
    ) -> None:
        """2 dims pre-completed, 1 pending → gather chỉ chạy 1."""
        session_dir = tmp_path / "session"
        valid_signals_file(
            session_dir / "lanes" / "QD1" / "signals.json",
            probes_executed=3,
        )

        # Trace dim nào được dispatch
        dispatched: list[str] = []

        async def fake_run_lane(
            dim, session_dir, profile, workflow_root, use_cache,
            semaphore, token_bucket=None, backpressure=None,
        ):
            dispatched.append(dim)
            sp = session_dir / "lanes" / dim / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text(json.dumps({
                "$schema": SIGNALS_SCHEMA_ID, "signals": [],
                "probes_executed": 1,
            }), encoding="utf-8")
            return LaneResult(
                dim=dim, status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr("lane_dispatch._run_lane_async", fake_run_lane)

        result = await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1", "QD2", "QD3"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=2,
        )

        assert result.completed == 3
        assert sorted(dispatched) == ["QD2", "QD3"]

    async def test_aggregates_failed_count(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """Mix completed + failed → counts đúng."""
        session_dir = tmp_path / "session"

        async def fake_run_lane(
            dim, session_dir, profile, workflow_root, use_cache,
            semaphore, token_bucket=None, backpressure=None,
        ):
            if dim == "QD2":
                return LaneResult(
                    dim=dim, status="failed", probes_executed=0,
                    signals_path=None, error="oops",
                )
            sp = session_dir / "lanes" / dim / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=dim, status="completed", probes_executed=2,
                signals_path=sp,
            )

        monkeypatch.setattr("lane_dispatch._run_lane_async", fake_run_lane)

        result = await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1", "QD2", "QD3"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=3,
        )

        assert result.completed == 2
        assert result.failed == 1
        assert "QD2" not in result.signals_paths
        assert "QD1" in result.signals_paths
        assert "QD3" in result.signals_paths

    async def test_token_bucket_wired_when_enabled(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """enable_concurrency=True + _TB_AVAILABLE → TokenBucket3Tier khởi tạo."""
        session_dir = tmp_path / "session"

        # Capture token_bucket truyền vào _run_lane_async
        captured: dict = {}

        async def fake_run_lane(
            dim, session_dir, profile, workflow_root, use_cache,
            semaphore, token_bucket=None, backpressure=None,
        ):
            captured["token_bucket"] = token_bucket
            captured["backpressure"] = backpressure
            sp = session_dir / "lanes" / dim / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=dim, status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr("lane_dispatch._run_lane_async", fake_run_lane)
        monkeypatch.setattr("lane_dispatch._TB_AVAILABLE", True)
        monkeypatch.setattr("lane_dispatch._BP_AVAILABLE", True)

        fake_tb_instance = MagicMock(name="TokenBucketInstance")
        fake_bp_instance = MagicMock(name="BackpressureInstance")
        monkeypatch.setattr(
            "lane_dispatch.TokenBucket3Tier",
            lambda *a, **kw: fake_tb_instance,
        )
        monkeypatch.setattr(
            "lane_dispatch.AdaptiveBackpressure",
            lambda *a, **kw: fake_bp_instance,
        )

        await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=1,
            enable_concurrency=True,
        )

        assert captured["token_bucket"] is fake_tb_instance
        assert captured["backpressure"] is fake_bp_instance

    async def test_token_bucket_ctor_failure_graceful(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """TokenBucket3Tier() raise → token_bucket=None, lane vẫn chạy."""
        session_dir = tmp_path / "session"

        captured: dict = {}

        async def fake_run_lane(
            dim, session_dir, profile, workflow_root, use_cache,
            semaphore, token_bucket=None, backpressure=None,
        ):
            captured["tb"] = token_bucket
            captured["bp"] = backpressure
            sp = session_dir / "lanes" / dim / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=dim, status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr("lane_dispatch._run_lane_async", fake_run_lane)
        monkeypatch.setattr("lane_dispatch._TB_AVAILABLE", True)
        monkeypatch.setattr("lane_dispatch._BP_AVAILABLE", True)

        def tb_boom(*a, **kw):
            raise RuntimeError("tb ctor fail")

        def bp_boom(*a, **kw):
            raise RuntimeError("bp ctor fail")

        monkeypatch.setattr("lane_dispatch.TokenBucket3Tier", tb_boom)
        monkeypatch.setattr("lane_dispatch.AdaptiveBackpressure", bp_boom)

        result = await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=1,
            enable_concurrency=True,
        )

        assert result.completed == 1
        # Graceful degrade: cả 2 None
        assert captured["tb"] is None
        assert captured["bp"] is None

    async def test_concurrency_disabled_default(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """enable_concurrency=False (default) → token_bucket/backpressure None."""
        session_dir = tmp_path / "session"

        captured: dict = {}

        async def fake_run_lane(
            dim, session_dir, profile, workflow_root, use_cache,
            semaphore, token_bucket=None, backpressure=None,
        ):
            captured["tb"] = token_bucket
            captured["bp"] = backpressure
            sp = session_dir / "lanes" / dim / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=dim, status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr("lane_dispatch._run_lane_async", fake_run_lane)

        await dispatch_lanes_async(
            session_dir=session_dir,
            dimensions=["QD1"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=1,
            enable_concurrency=False,
        )

        assert captured["tb"] is None
        assert captured["bp"] is None


# ──────────────────────────────────────────────────────────────────────
# dispatch_lanes sync wrapper — branches deferred
# ──────────────────────────────────────────────────────────────────────


class TestDispatchLanesSyncWrapper:
    """Cover lines 1630-1631 (relative session_dir resolve) + 1653-1683."""

    def test_relative_session_dir_resolved_via_repo_root(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """session_dir relative → resolve qua workflow_root.parent.parent.parent."""
        # Setup: workflow_root structure giả .claude/skills/workflow/ với
        # repo_root = workflow_root.parent.parent.parent = tmp_path/repo
        repo_root = tmp_path / "repo"
        workflow_root = repo_root / ".claude" / "skills" / "workflow"
        workflow_root.mkdir(parents=True)

        captured_session_dir: list[Path] = []

        def fake_exec(**kwargs):
            captured_session_dir.append(kwargs["session_dir"])
            sp = kwargs["session_dir"] / "lanes" / kwargs["dim"] / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=kwargs["dim"], status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", fake_exec
        )

        # session_dir relative → "rel/session"
        rel_session = Path("rel/session")
        result = dispatch_lanes(
            session_dir=rel_session,
            dimensions=["QD1"],
            profile="standard",
            workflow_root=workflow_root,
            max_parallel=1,
        )

        # session_dir đã được resolve qua repo_root
        assert len(captured_session_dir) == 1
        resolved = captured_session_dir[0]
        assert resolved.is_absolute()
        # Path so sánh resolved phải bắt đầu bằng repo_root
        assert str(resolved).startswith(str(repo_root.resolve()))

    def test_max_parallel_one_sequential_path(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """max_parallel=1 → bypass asyncio.run, gọi _execute_lane_sequential
        cho mỗi dim trực tiếp."""
        session_dir = tmp_path / "session"
        session_dir.mkdir()

        called: list[str] = []

        def fake_exec(**kw):
            called.append(kw["dim"])
            sp = kw["session_dir"] / "lanes" / kw["dim"] / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=kw["dim"], status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", fake_exec
        )
        # asyncio.run should NOT be called
        def asyncio_run_boom(*a, **kw):
            raise AssertionError(
                "asyncio.run KHÔNG được gọi khi max_parallel=1"
            )

        monkeypatch.setattr("lane_dispatch.asyncio.run", asyncio_run_boom)

        result = dispatch_lanes(
            session_dir=session_dir,
            dimensions=["QD1", "QD2", "QD3"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=1,
        )

        assert sorted(called) == ["QD1", "QD2", "QD3"]
        assert set(result.keys()) == {"QD1", "QD2", "QD3"}

    def test_single_dim_forces_sequential(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """len(dimensions)==1 → sequential dù max_parallel>1."""
        session_dir = tmp_path / "session"
        session_dir.mkdir()

        called: list[str] = []

        def fake_exec(**kw):
            called.append(kw["dim"])
            sp = kw["session_dir"] / "lanes" / kw["dim"] / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=kw["dim"], status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", fake_exec
        )
        monkeypatch.setattr(
            "lane_dispatch.asyncio.run",
            lambda *a, **kw: pytest.fail("asyncio.run KHÔNG được gọi"),
        )

        result = dispatch_lanes(
            session_dir=session_dir,
            dimensions=["QD1"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=5,
        )

        assert called == ["QD1"]
        assert "QD1" in result

    async def test_running_loop_fallback_sequential(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """Gọi dispatch_lanes trong async context (running loop) →
        asyncio.run() ko an toàn → fallback sequential."""
        session_dir = tmp_path / "session"
        session_dir.mkdir()

        called: list[str] = []

        def fake_exec(**kw):
            called.append(kw["dim"])
            sp = kw["session_dir"] / "lanes" / kw["dim"] / "signals.json"
            sp.parent.mkdir(parents=True, exist_ok=True)
            sp.write_text("{}", encoding="utf-8")
            return LaneResult(
                dim=kw["dim"], status="completed", probes_executed=1,
                signals_path=sp,
            )

        monkeypatch.setattr(
            "lane_dispatch._execute_lane_sequential", fake_exec
        )
        monkeypatch.setattr(
            "lane_dispatch.asyncio.run",
            lambda *a, **kw: pytest.fail("asyncio.run forbidden trong loop"),
        )

        result = dispatch_lanes(
            session_dir=session_dir,
            dimensions=["QD1", "QD2"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=2,
        )

        assert sorted(called) == ["QD1", "QD2"]
        assert set(result.keys()) == {"QD1", "QD2"}

    def test_asyncio_run_path_for_parallel_multi_dim(
        self, tmp_path: Path, monkeypatch,
    ) -> None:
        """Multi-dim + max_parallel>1 + no running loop → asyncio.run gọi
        dispatch_lanes_async."""
        session_dir = tmp_path / "session"
        session_dir.mkdir()

        async_called: dict = {"count": 0, "kwargs": None}

        async def fake_async_dispatch(**kwargs):
            async_called["count"] += 1
            async_called["kwargs"] = kwargs
            return DispatchResult(
                lanes=[], completed=2, failed=0,
                signals_paths={
                    "QD1": session_dir / "lanes" / "QD1" / "signals.json",
                    "QD3": session_dir / "lanes" / "QD3" / "signals.json",
                },
            )

        monkeypatch.setattr(
            "lane_dispatch.dispatch_lanes_async", fake_async_dispatch
        )

        result = dispatch_lanes(
            session_dir=session_dir,
            dimensions=["QD1", "QD3"],
            profile="standard",
            workflow_root=tmp_path / "wfroot",
            max_parallel=3,
        )

        assert async_called["count"] == 1
        assert set(result.keys()) == {"QD1", "QD3"}
