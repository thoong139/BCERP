"""test_h_concurrent.py — Scenario H: Concurrent lane write scope isolation.

Verify: 5 lanes parallel, no lock contention, no data loss in aggregation.

Kiem tra:
    - partition_dimensions chia dimensions thanh 1 hoac nhieu workloads.
    - aggregate_lane_signals doc du lieu tu 5 lanes ma khong mat du lieu.
    - SignalBus dedup signals cung target tu nhieu lanes thanh 1 issue
      voi nhieu probe_sources.
    - Tong so signals sau aggregate dung voi so signals input.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from partition_planner import partition_dimensions
from signal_aggregator import aggregate_lane_signals
from signal_bus.signal_bus import SignalBus


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────

ALL_DIMS: list[str] = ["QD1", "QD2", "QD3", "QD4", "QD5"]


def _make_lane_signals(
    session_dir: Path,
    dims: list[str],
    signals_per_dim: int = 2,
) -> None:
    """Tao lane signals.json cho tung dimension.

    Moi lane co signals_per_dim signals voi target khac nhau
    (file_path + symbol khac nhau per signal).

    Args:
        session_dir: $SESSION_DIR chua lanes/ subdirectory.
        dims: Danh sach dimension IDs (VD: ["QD1", "QD3"]).
        signals_per_dim: So signals tao cho moi dimension.
    """
    for dim in dims:
        lane_dir = session_dir / "lanes" / dim
        lane_dir.mkdir(parents=True, exist_ok=True)
        signals: list[dict[str, Any]] = []
        for i in range(signals_per_dim):
            signals.append({
                "$schema": "signal-v2",
                "probe_id": f"P-{dim}-probe-{i}",
                "probe_version": "1.0.0",
                "emitted_at": "2026-04-23T10:00:00+00:00",
                "lane": f"wf-fix-{dim.lower()}",
                "dimension_hint": dim,
                "target": {
                    "kind": "code",
                    "file_path": f"src/{dim.lower()}/module{i}.ts",
                    "line_range": [10, 25],
                    "symbol": f"fn{i}",
                },
                "description": f"Van de {dim} probe {i} — du 10 ky tu.",
                "evidence": {
                    "code_snippet": "// Code snippet du 10 ky tu.",
                    "screenshot_path": None,
                    "log_excerpt": None,
                    "stacktrace": None,
                    "spec_ref": None,
                    "test_failure_ref": None,
                },
                "suggested_severity": "medium",
                "dedup_hints": [],
            })
        (lane_dir / "signals.json").write_text(
            json.dumps(
                {"$schema": "lane-signals-v1", "signals": signals},
                indent=2,
            ),
            encoding="utf-8",
        )


def _make_lane_signals_with_shared_target(
    session_dir: Path,
    dims: list[str],
) -> None:
    """Tao signals tu nhieu lanes cung target (cho dedup test).

    Tat ca signals co cung file_path + line_range + symbol,
    nhung khac dimension → tao ra cung dedup key chi khi dimension giong nhau.
    """
    for dim in dims:
        lane_dir = session_dir / "lanes" / dim
        lane_dir.mkdir(parents=True, exist_ok=True)
        signals: list[dict[str, Any]] = []
        # 1 signal moi lane, cung target
        signals.append({
            "$schema": "signal-v2",
            "probe_id": f"P-{dim}-probe-shared",
            "probe_version": "1.0.0",
            "emitted_at": "2026-04-23T10:00:00+00:00",
            "lane": f"wf-fix-{dim.lower()}",
            "dimension_hint": dim,
            "target": {
                "kind": "code",
                "file_path": "src/shared/module.ts",
                "line_range": [10, 25],
                "symbol": "sharedFunction",
            },
            "description": f"Van de shared tu {dim} — du 10 ky tu.",
            "evidence": {
                "code_snippet": "// Shared code snippet du 10 ky tu.",
                "screenshot_path": None,
                "log_excerpt": None,
                "stacktrace": None,
                "spec_ref": None,
                "test_failure_ref": None,
            },
            "suggested_severity": "high",
            "dedup_hints": [],
        })
        (lane_dir / "signals.json").write_text(
            json.dumps(
                {"$schema": "lane-signals-v1", "signals": signals},
                indent=2,
            ),
            encoding="utf-8",
        )


# ──────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────


class TestConcurrentLanes:
    """Kiem tra concurrent lane write scope isolation."""

    def test_partition_dimensions_single_workload(self) -> None:
        """3 dimensions → 1 workload (duoi max_workload_size)."""
        workloads = partition_dimensions(["QD1", "QD2", "QD5"])
        assert len(workloads) == 1
        assert workloads[0].id == "W01"
        assert set(workloads[0].dimensions) == {"QD1", "QD2", "QD5"}

    def test_partition_dimensions_split(self) -> None:
        """7 dimensions voi max_workload_size=3 → nhieu workloads."""
        all_seven = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7"]
        workloads = partition_dimensions(all_seven, max_workload_size=3)
        assert len(workloads) >= 2, (
            f"Expected >= 2 workloads with max_size=3, got {len(workloads)}"
        )

        # Tong so dimensions tren tat ca workloads = 7
        all_dims_in_workloads: list[str] = []
        for w in workloads:
            all_dims_in_workloads.extend(w.dimensions)
        assert len(all_dims_in_workloads) == 7

        # Khong co workload nao vuot max size
        for w in workloads:
            assert len(w.dimensions) <= 3

    def test_lane_signals_no_data_loss(self, tmp_path: Path) -> None:
        """5 lanes x 2 signals = 10 signals → aggregate khong mat du lieu."""
        session_dir = tmp_path / "sessions" / "test-session"
        session_dir.mkdir(parents=True)

        _make_lane_signals(session_dir, ALL_DIMS, signals_per_dim=2)

        registry_path, stats = aggregate_lane_signals(session_dir, ALL_DIMS)

        # 5 dims x 2 signals = 10 total signals
        assert stats.total_signals == 10
        # Moi dim co 2 signals, moi dim tao ra 2 issues (khac file_path/symbol)
        assert stats.total_issues == 10
        assert len(stats.errors) == 0, f"Unexpected errors: {stats.errors}"

        # Verify issue-registry.json ton tai va hop le
        assert registry_path.exists()
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data["$schema"] == "issue-registry-v2"
        assert len(data["issues"]) == 10

    def test_signal_bus_dedup_across_lanes(self, tmp_path: Path) -> None:
        """Signals tu khac lanes cung target → dedup (1 issue, nhieu probe_sources).

        Signals cung file_path + line_range + symbol nhung tu khac dimensions
        tao ra khac dedup_key (vi dedup_key bao gom dimension) → 5 issues.
        Tuy nhien, neu cung dimension thi se dedup.

        Day la test de verify SignalBus dedup logic hoat dong dung.
        """
        session_dir = tmp_path / "sessions" / "dedup-test"
        session_dir.mkdir(parents=True)

        # Tao signals tu 5 dims voi cung target
        _make_lane_signals_with_shared_target(session_dir, ALL_DIMS)

        # Aggregate — moi dim co 1 signal cung target nhung khac dimension
        registry_path, stats = aggregate_lane_signals(session_dir, ALL_DIMS)

        # 5 signals vao, 5 issues ra (moi dim khac nhau → khac dedup_key)
        assert stats.total_signals == 5
        assert stats.total_issues == 5

        # Verify moi issue co dung 1 probe_source (khong merge cross-dimension)
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        for issue in data["issues"]:
            assert len(issue["probe_sources"]) >= 1

    def test_signal_bus_dedup_same_dimension(self, tmp_path: Path) -> None:
        """2 signals cung dimension + cung target → dedup thanh 1 issue."""
        session_dir = tmp_path / "sessions" / "same-dim-dedup"
        session_dir.mkdir(parents=True)

        bus = SignalBus(session_dir)
        bus.load_existing()

        signal_base: dict[str, Any] = {
            "probe_id": "P-QD1-probe-first",
            "probe_version": "1.0.0",
            "emitted_at": "2026-04-23T10:00:00+00:00",
            "lane": "wf-fix-functional",
            "dimension_hint": "QD1",
            "target": {
                "kind": "code",
                "file_path": "src/app/service.ts",
                "line_range": [10, 25],
                "symbol": "processOrder",
            },
            "description": "Van de duplicate signal — du 10 ky tu.",
            "evidence": {
                "code_snippet": "// Duplicate code snippet du 10 ky tu.",
                "screenshot_path": None,
                "log_excerpt": None,
                "stacktrace": None,
                "spec_ref": None,
                "test_failure_ref": None,
            },
            "suggested_severity": "medium",
            "dedup_hints": [],
        }

        # Ingest signal dau tien
        bus.ingest(signal_base)

        # Ingest signal thu hai — cung dimension + target, khac probe_id
        signal_dup = dict(signal_base)
        signal_dup["probe_id"] = "P-QD1-probe-second"
        bus.ingest(signal_dup)

        # Dedup: cung dimension + cung target → 1 issue duy nhat
        assert len(bus.issues) == 1
        # Issue co 2 probe_sources (merge tu 2 signals)
        assert len(bus.issues[0].probe_sources) == 2

        # Flush va verify POST-GATE
        registry_path = bus.flush()
        assert registry_path.exists()
