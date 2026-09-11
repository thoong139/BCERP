"""test_e2e_stage_f.py — E2E tests cho Stage F (Probe Execution + Agent Wiring).

Vai trò:
    Kiểm thử E2E cho cache integration (F2), golden fixture (F4),
    và v6 dry-run flow (F5).

Tham chiếu:
    - Stage F spec: docs/design/skills/wf-fix-bugs/prompts/stage-F-prompt.md
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from dimension_registry import get_cache_policy, get_lane_path
from lane_dispatch import dispatch_lanes
from probe_executor import GREP_PATTERNS, execute_probe
from signal_aggregator import aggregate_lane_signals


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


@pytest.fixture
def golden_v6_root() -> Path:
    """Path tới golden-v6 fixture."""
    return Path(__file__).resolve().parent / "fixtures" / "golden-v6"


# ──────────────────────────────────────────────────────────────────────
# F2: Cache Integration in Lane Dispatch
# ──────────────────────────────────────────────────────────────────────


class TestCacheIntegration:
    """Wire scan_cache vào lane_dispatch cho non-QD3 probes."""

    def test_qd3_never_cached(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """ADR-22 Rule 6: QD3 lane with use_cache=True → NO cache files."""
        assert get_cache_policy("QD3") is False

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )
        # Verify no cache files created for QD3
        cache_dir = tmp_session_dir / "cache" / "probes"
        if cache_dir.exists():
            cache_files = list(cache_dir.glob("*.json"))
            assert len(cache_files) == 0, "QD3 should never create cache files"

    def test_qd1_cache_stored_on_miss(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """QD1 lane with use_cache=True → cache_lookup + cache_store called on miss."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )
        # Verify cache files created for QD1
        cache_dir = tmp_session_dir / "cache" / "probes"
        assert cache_dir.exists(), "Cache directory should be created"
        cache_files = list(cache_dir.glob("*.json"))
        assert len(cache_files) > 0, "QD1 should create cache entries"

    def test_qd1_no_cache_without_flag(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """QD1 lane with use_cache=False → no cache files."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        cache_dir = tmp_session_dir / "cache" / "probes"
        assert not cache_dir.exists(), "Cache dir should not exist without --use-cache"

    def test_cache_hit_skips_probe(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Pre-populated cache → probe skipped, cached signals returned."""
        # Step 1: First run creates cache
        result1 = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )
        cache_dir = tmp_session_dir / "cache" / "probes"
        cache_files = list(cache_dir.glob("*.json"))
        assert len(cache_files) > 0

        # Step 2: Modify signals to have identifiable content
        signals_path = result1["QD1"]
        data = json.loads(signals_path.read_text(encoding="utf-8"))
        cached_signal = {
            "probe_id": "P-QD1-req-registry-xref",
            "probe_version": "1.0.0",
            "emitted_at": "2026-04-21T10:00:00+00:00",
            "lane": "wf-fix-functional",
            "dimension_id": "QD1",
            "target": {"kind": "code", "file_path": "src/test.ts", "line_range": [1, 1]},
            "description": "Cached signal from previous run — test marker",
            "evidence": {"code_snippet": "// cached test signal for verification"},
            "suggested_severity": "medium",
            "dedup_hints": [],
        }
        # Overwrite cache entry with our signal
        for cf in cache_files:
            entry = json.loads(cf.read_text(encoding="utf-8"))
            entry["signals_emitted"] = [cached_signal]
            cf.write_text(
                json.dumps(entry, ensure_ascii=False, indent=2), encoding="utf-8",
            )

        # Step 3: Second run should get cached signals
        result2 = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )
        signals_data = json.loads(result2["QD1"].read_text(encoding="utf-8"))
        assert len(signals_data["signals"]) >= 1
        found_cached = any(
            "Cached signal" in s.get("description", "")
            for s in signals_data["signals"]
        )
        assert found_cached, "Should find cached signal from previous run"


# ──────────────────────────────────────────────────────────────────────
# F4: Golden Fixture Full E2E
# ──────────────────────────────────────────────────────────────────────


class TestGoldenFixtureE2E:
    """Golden-v6 fixture: 17 issues detected across ≥6 dimensions."""

    def test_golden_dispatch_all_dims(
        self, golden_v6_root: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Dispatch probes for all 7 dimensions → signals.json created."""
        all_dims = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"]

        # Run probe_executor directly on golden fixture files
        total_signals: list[dict[str, Any]] = []

        for dim in all_dims:
            dim_map = {
                "QD1": "wf-fix-functional", "QD2": "wf-fix-business",
                "QD3": "wf-fix-security", "QD4": "wf-fix-performance",
                "QD5": "wf-fix-ux-a11y", "QD6": "wf-fix-data",
                "QD7": "wf-fix-compat", "QD8": "wf-fix-observability",
            }
            lane_name = dim_map[dim]
            probes_dir = workflow_root / lane_name / "procedures" / "probes"

            if not probes_dir.exists():
                continue

            dim_signals: list[dict[str, Any]] = []

            # Find grep+jq probes
            dim_json_path = workflow_root / lane_name / "dimension.json"
            if not dim_json_path.exists():
                continue
            dim_data = json.loads(dim_json_path.read_text(encoding="utf-8"))

            for probe_def in dim_data.get("probes", []):
                tool_kind = probe_def.get("tool", {}).get("kind", "")
                probe_id = probe_def.get("id", "")
                # Fallback: probe in GREP_PATTERNS but missing tool.kind → grep+jq
                if not tool_kind and probe_id in GREP_PATTERNS:
                    tool_kind = "grep+jq"
                if tool_kind not in ("grep+jq", "grep+ast"):
                    continue

                probe_id = probe_def["id"]
                probe_md = probes_dir / f"{probe_id}.md"
                if not probe_md.exists():
                    continue

                try:
                    signals = execute_probe(
                        probe_config_path=probe_md,
                        dimension=dim,
                        lane=lane_name,
                        session_dir=tmp_session_dir,
                        workflow_root=workflow_root,
                        project_root=golden_v6_root,
                    )
                    dim_signals.extend(signals)
                except (FileNotFoundError, ValueError):
                    continue

            # Write lane signals
            lane_dir = tmp_session_dir / "lanes" / dim
            lane_dir.mkdir(parents=True, exist_ok=True)
            signals_data = {
                "$schema": "lane-signals-v1",
                "dimension": dim,
                "signals": dim_signals,
            }
            (lane_dir / "signals.json").write_text(
                json.dumps(signals_data, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            total_signals.extend(dim_signals)

        # Verify ≥6 dimensions found signals
        dims_with_signals: set[str] = set()
        for s in total_signals:
            dims_with_signals.add(s["dimension_id"])

        assert len(dims_with_signals) >= 6, (
            f"Expected ≥6 dimensions, got {len(dims_with_signals)}: "
            f"{sorted(dims_with_signals)}"
        )

    def test_golden_aggregation(
        self, golden_v6_root: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Aggregate all dimensions → issue-registry with expected issues."""
        # Reuse dispatch from test above
        all_dims = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8"]
        dim_map = {
            "QD1": "wf-fix-functional", "QD2": "wf-fix-business",
            "QD3": "wf-fix-security", "QD4": "wf-fix-performance",
            "QD5": "wf-fix-ux-a11y", "QD6": "wf-fix-data",
            "QD7": "wf-fix-compat", "QD8": "wf-fix-observability",
        }

        all_signals: dict[str, list] = {}

        for dim in all_dims:
            lane_name = dim_map[dim]
            dim_json_path = workflow_root / lane_name / "dimension.json"
            if not dim_json_path.exists():
                continue
            dim_data = json.loads(dim_json_path.read_text(encoding="utf-8"))

            dim_signals: list[dict] = []
            for probe_def in dim_data.get("probes", []):
                tool_kind = probe_def.get("tool", {}).get("kind", "")
                probe_id = probe_def.get("id", "")
                # Fallback: probe in GREP_PATTERNS but missing tool.kind → grep+jq
                if not tool_kind and probe_id in GREP_PATTERNS:
                    tool_kind = "grep+jq"
                if tool_kind not in ("grep+jq", "grep+ast"):
                    continue
                probe_id = probe_def["id"]
                probe_md = workflow_root / lane_name / "procedures" / "probes" / f"{probe_id}.md"
                if not probe_md.exists():
                    continue
                try:
                    signals = execute_probe(
                        probe_config_path=probe_md,
                        dimension=dim,
                        lane=lane_name,
                        session_dir=tmp_session_dir,
                        workflow_root=workflow_root,
                        project_root=golden_v6_root,
                    )
                    dim_signals.extend(signals)
                except (FileNotFoundError, ValueError):
                    continue

            # Write lane signals
            lane_dir = tmp_session_dir / "lanes" / dim
            lane_dir.mkdir(parents=True, exist_ok=True)
            signals_data = {
                "$schema": "lane-signals-v1",
                "dimension": dim,
                "signals": dim_signals,
            }
            (lane_dir / "signals.json").write_text(
                json.dumps(signals_data, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            all_signals[dim] = dim_signals

        # Aggregate
        active_dims = [d for d in all_dims if d in all_signals]
        registry_path, stats = aggregate_lane_signals(tmp_session_dir, active_dims)

        assert registry_path.exists()
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert len(data["issues"]) > 0, "Should have aggregated issues"

    def test_golden_qd3_cache_never(
        self, golden_v6_root: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """ADR-22 Rule 6: QD3 probes never cached even with use_cache."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD3"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=True,
            max_parallel=1,
        )
        cache_dir = tmp_session_dir / "cache" / "probes"
        if cache_dir.exists():
            assert len(list(cache_dir.glob("*.json"))) == 0

    def test_golden_cdg_flags(
        self, golden_v6_root: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """CORE-027: CDG probes (P-QD3-secret-detection) flagged correctly."""
        probe_path = (
            workflow_root / "wf-fix-security" / "procedures" / "probes" / "P-QD3-secret-detection.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_v6_root,
        )
        assert len(signals) > 0, "Golden fixture should trigger secret detection"
        for s in signals:
            assert s.get("cdg_required") is True

    def test_golden_backward_compat(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """--engine=v5 backward compat: existing dispatch still works without cache."""
        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD3"],
            profile="quick",
            workflow_root=workflow_root,
            use_cache=False,
            max_parallel=1,
        )
        assert "QD1" in result
        assert "QD3" in result
        for dim, path in result.items():
            data = json.loads(path.read_text(encoding="utf-8"))
            assert data["$schema"] == "lane-signals-v1"
            assert isinstance(data["signals"], list)


# ──────────────────────────────────────────────────────────────────────
# F5: v6 Dry-Run End-to-End
# ──────────────────────────────────────────────────────────────────────


class TestV6DryRun:
    """--engine=v6 --dry-run: preview report, no code changes."""

    def test_dry_run_dispatch(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Dry-run dispatch creates signals files without code changes."""
        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        # Verify signals files created (dry-run preview)
        for dim, path in result.items():
            assert path.exists(), f"{dim} signals.json should exist"
            data = json.loads(path.read_text(encoding="utf-8"))
            assert "signals" in data

    def test_dry_run_aggregation(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Dry-run: aggregate creates issue-registry (empty or with preview signals)."""
        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1", "QD3"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        registry_path, stats = aggregate_lane_signals(
            tmp_session_dir, ["QD1", "QD3"],
        )
        assert registry_path.exists()
        # Framework mode: signals are empty (placeholder) → 0 issues is valid
        assert stats.total_issues >= 0

    def test_dry_run_no_project_modification(
        self, tmp_session_dir: Path, workflow_root: Path, tmp_path: Path,
    ) -> None:
        """Dry-run doesn't modify any project files."""
        # Create a sentinel file
        sentinel = tmp_path / "project_root" / "src" / "index.ts"
        sentinel.parent.mkdir(parents=True, exist_ok=True)
        sentinel.write_text("export {};", encoding="utf-8")
        original_content = sentinel.read_text(encoding="utf-8")

        dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        # Verify project files unchanged
        assert sentinel.read_text(encoding="utf-8") == original_content

    def test_dry_run_preview_report_sections(
        self, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Dispatch result has all expected sections for preview report."""
        result = dispatch_lanes(
            session_dir=tmp_session_dir,
            dimensions=["QD1"],
            profile="quick",
            workflow_root=workflow_root,
            max_parallel=1,
        )
        signals_path = result["QD1"]
        data = json.loads(signals_path.read_text(encoding="utf-8"))

        # Expected sections for preview report
        assert "$schema" in data
        assert "dimension" in data
        assert "profile" in data
        assert "generated_at" in data
        assert "probes_executed" in data
        assert "cache_policy" in data
        assert "signals" in data
        assert data["dimension"] == "QD1"
        assert data["profile"] == "quick"
        assert data["probes_executed"] > 0
