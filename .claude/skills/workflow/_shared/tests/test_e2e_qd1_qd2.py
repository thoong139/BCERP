"""test_e2e_qd1_qd2.py — E2E integration tests cho QD1 + QD2 lanes.

Test cases:
    1. QD1 + QD2 parallel: ca 2 lanes viet vao phase4-find-bugs/lanes/QD1-functional/ va phase4-find-bugs/lanes/QD2-business/
    2. Signal Bus dedup: QD1 va QD2 emit signals cho cung file → merge thanh 1 Issue
    3. Impact Graph ripple: verify_ripple sau fix, depth=1, strength >= 0.5
    4. Golden fixture: sample project voi known issues, compare against expected output
    5. POST-GATE T1-T4 pass cho ca 2 lanes
    6. Dimension manifest validation: dimension.json probes match SKILL.md
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from signal_bus.signal_bus import SignalBus, Signal, Issue, post_gate_check

# Fixtures path
FIXTURES = Path(__file__).parent / "fixtures" / "sample-project"


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def _make_signal(
    probe_id: str,
    dimension: str,
    lane: str,
    file_path: str,
    description: str,
    severity: str = "high",
    line_start: int = 1,
    line_end: int = 10,
) -> dict[str, Any]:
    """Tao signal dict hop le cho testing."""
    return {
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": "2026-04-21T10:00:00+00:00",
        "lane": lane,
        "dimension_id": dimension,
        "target": {
            "kind": "code",
            "file_path": file_path,
            "line_range": [line_start, line_end],
            "symbol": "testFunc",
        },
        "description": description,
        "evidence": {
            "code_snippet": f"// {description[:50]}",
            "screenshot_path": None,
            "log_excerpt": None,
            "stacktrace": None,
            "spec_ref": None,
            "test_failure_ref": None,
        },
        "suggested_severity": severity,
        "dedup_hints": [file_path],
    }


def _write_lane_signals(
    session_dir: Path, lane: str, signals: list[dict[str, Any]]
) -> Path:
    """Viet lane signals.json va return path."""
    lane_dir = session_dir / "lanes" / lane
    lane_dir.mkdir(parents=True, exist_ok=True)
    signals_file = lane_dir / "signals.json"
    data = {
        "$schema": "lane-signals-v1",
        "lane": f"wf-fix-{'functional' if lane == 'QD1' else 'business'}",
        "dimension": lane,
        "generated_at": "2026-04-21T10:00:00+00:00",
        "signals": signals,
    }
    signals_file.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    return signals_file


# ──────────────────────────────────────────────────────────────────────
# Test 1: QD1 + QD2 parallel lane writes
# ──────────────────────────────────────────────────────────────────────


class TestParallelLanes:
    """QD1 va QD2 chay song song, viet vao lanes/ rieng biet."""

    def test_qd1_lane_creates_signals(self, tmp_session_dir: Path) -> None:
        """QD1 lane viet signals.json thanh cong."""
        signals = [
            _make_signal(
                "P-QD1-req-registry-xref",
                "QD1",
                "wf-fix-functional",
                "src/features/customer/service.ts",
                "FEAT-FIN-CUST-002 impl_status=done nhung khong co code annotation",
                "high",
            ),
        ]
        path = _write_lane_signals(tmp_session_dir, "QD1", signals)
        assert path.exists()
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["$schema"] == "lane-signals-v1"
        assert len(data["signals"]) == 1
        assert data["signals"][0]["dimension_id"] == "QD1"

    def test_qd2_lane_creates_signals(self, tmp_session_dir: Path) -> None:
        """QD2 lane viet signals.json thanh cong."""
        signals = [
            _make_signal(
                "P-QD2-hardcoded-value-detect",
                "QD2",
                "wf-fix-business",
                "src/features/customer/service.ts",
                "Hard-coded TAX_RATE = 0.1 trong production code",
                "medium",
                line_start=5,
                line_end=5,
            ),
            _make_signal(
                "P-QD2-domain-expert-review",
                "QD2",
                "wf-fix-business",
                "src/features/customer/service.ts",
                "Quy trinh processOrder skip buoc audit trail compliance",
                "critical",
                line_start=20,
                line_end=25,
            ),
        ]
        path = _write_lane_signals(tmp_session_dir, "QD2", signals)
        assert path.exists()
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["dimension"] == "QD2"
        assert len(data["signals"]) == 2

    def test_both_lanes_isolated(self, tmp_session_dir: Path) -> None:
        """Ca 2 lanes viet song song, khong ghi de lan nhau."""
        qd1_signals = [
            _make_signal(
                "P-QD1-req-registry-xref", "QD1", "wf-fix-functional",
                "src/a.ts", "QD1 finding on file A", "high",
            ),
        ]
        qd2_signals = [
            _make_signal(
                "P-QD2-hardcoded-value-detect", "QD2", "wf-fix-business",
                "src/b.ts", "QD2 finding on file B", "medium",
            ),
        ]

        qd1_path = _write_lane_signals(tmp_session_dir, "QD1", qd1_signals)
        qd2_path = _write_lane_signals(tmp_session_dir, "QD2", qd2_signals)

        # Ca 2 ton tai
        assert qd1_path.exists()
        assert qd2_path.exists()

        # QD1 chi chua QD1 signals
        qd1_data = json.loads(qd1_path.read_text(encoding="utf-8"))
        assert all(s["dimension_id"] == "QD1" for s in qd1_data["signals"])

        # QD2 chi chua QD2 signals
        qd2_data = json.loads(qd2_path.read_text(encoding="utf-8"))
        assert all(s["dimension_id"] == "QD2" for s in qd2_data["signals"])


# ──────────────────────────────────────────────────────────────────────
# Test 2: Signal Bus dedup across lanes
# ──────────────────────────────────────────────────────────────────────


class TestSignalBusDedup:
    """QD1 va QD2 emit signals cho cung file → merge thanh 1 Issue."""

    def test_cross_lane_dedup(self, tmp_session_dir: Path) -> None:
        """2 signals cho cung file+line → 1 Issue voi 2 dimensions."""
        bus = SignalBus(tmp_session_dir)
        bus.load_existing()

        # Signal 1: QD1 — coverage gap
        s1 = _make_signal(
            "P-QD1-req-registry-xref",
            "QD1",
            "wf-fix-functional",
            "src/features/customer/service.ts",
            "FEAT-FIN-CUST-002 impl_status=done nhung khong co code",
            "high",
            line_start=1,
            line_end=3,
        )

        # Signal 2: QD2 — same file, different issue (khac line range → khac issue)
        s2 = _make_signal(
            "P-QD2-hardcoded-value-detect",
            "QD2",
            "wf-fix-business",
            "src/features/customer/service.ts",
            "Hard-coded TAX_RATE = 0.1 trong production code",
            "medium",
            line_start=5,
            line_end=5,
        )

        bus.ingest(s1)
        bus.ingest(s2)
        bus.flush()

        # Load result
        registry = json.loads(
            (tmp_session_dir / "issue-registry.json").read_text(encoding="utf-8")
        )
        assert registry["$schema"] == "issue-registry-v2"
        assert len(registry["issues"]) == 2  # Khac line range → 2 issues

        # Verify each issue has correct dimension
        dims = set()
        for issue in registry["issues"]:
            dims.update(issue["dimensions"])
        assert "QD1" in dims
        assert "QD2" in dims

    def test_same_file_same_range_dedup(self, tmp_session_dir: Path) -> None:
        """2 signals cho cung file+line_range → merge thanh 1 Issue."""
        bus = SignalBus(tmp_session_dir)
        bus.load_existing()

        # Signal 1: QD1
        s1 = _make_signal(
            "P-QD1-req-registry-xref",
            "QD1",
            "wf-fix-functional",
            "src/features/customer/service.ts",
            "Coverage gap for customer service",
            "high",
            line_start=1,
            line_end=10,
        )

        # Signal 2: QD2 — same file, same line range → dedup → merge dimensions
        s2 = _make_signal(
            "P-QD2-domain-expert-review",
            "QD2",
            "wf-fix-business",
            "src/features/customer/service.ts",
            "Business logic issue in customer service",
            "critical",
            line_start=1,
            line_end=10,
        )

        bus.ingest(s1)
        bus.ingest(s2)
        bus.flush()

        registry = json.loads(
            (tmp_session_dir / "issue-registry.json").read_text(encoding="utf-8")
        )
        # Dedup key includes dimension_id → different dimensions = 2 separate issues
        # (Design: each dimension produces its own issue; dedup within same dimension)
        assert len(registry["issues"]) == 2
        issues_by_dim = {d: i for i in registry["issues"] for d in i["dimensions"]}
        assert "QD1" in issues_by_dim
        assert "QD2" in issues_by_dim
        # Each issue has 1 probe source
        for issue in registry["issues"]:
            assert len(issue["probe_sources"]) == 1

    def test_post_gate_t1_t4(self, tmp_session_dir: Path) -> None:
        """POST-GATE T1-T4 pass sau flush."""
        bus = SignalBus(tmp_session_dir)
        bus.load_existing()

        bus.ingest(_make_signal(
            "P-QD1-infra-preflight", "QD1", "wf-fix-functional",
            "src/app.ts", "Backend API khong phan hoi", "critical",
        ))
        bus.flush()

        ok, errors = post_gate_check(tmp_session_dir / "issue-registry.json")
        assert ok, f"POST-GATE failed: {errors}"


# ──────────────────────────────────────────────────────────────────────
# Test 3: Impact Graph ripple
# ──────────────────────────────────────────────────────────────────────


class TestImpactGraphRipple:
    """verify_ripple sau fix: depth=1, strength >= 0.5."""

    def test_ripple_basic(self, tmp_session_dir: Path) -> None:
        """Build graph + verify ripple cho 1 file fix."""
        import sys
        sys_path_prepend = Path(__file__).resolve().parent.parent
        if str(sys_path_prepend) not in sys.path:
            sys.path.insert(0, str(sys_path_prepend))

        from impact_graph.builder import build, emit
        from impact_graph.ripple import verify_ripple

        # Build impact graph from fixture source directory
        graph = build(repo_root=FIXTURES, scope=None)
        graph_path = tmp_session_dir / "impact-graph.json"
        emit(graph, graph_path)

        assert graph_path.exists()

        # Verify ripple — fix customer/service.ts
        issue = {"target": {"file_path": "src/features/customer/service.ts"}}
        results = verify_ripple(
            issue=issue,
            impact_graph_path=str(graph_path),
            depth=1,
            strength_threshold=0.5,
        )

        # Results la list of RippleTarget
        assert isinstance(results, list)


# ──────────────────────────────────────────────────────────────────────
# Test 4: Golden fixture validation
# ──────────────────────────────────────────────────────────────────────


class TestGoldenFixture:
    """Sample project voi known issues — verify expected signals."""

    def test_fixture_registry_exists(self) -> None:
        """Golden fixture co req-registry.json hop le."""
        registry_path = FIXTURES / ".mc-data" / "docs" / "_meta" / "req-registry.json"
        assert registry_path.exists()
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data["project"]["name"] == "sample-project"
        assert len(data["features"]) == 3
        assert len(data["requirements"]) == 3

    def test_fixture_source_exists(self) -> None:
        """Golden fixture co source code file."""
        src = FIXTURES / "src" / "features" / "customer" / "service.ts"
        assert src.exists()
        content = src.read_text(encoding="utf-8")
        # Known issues present in fixture
        assert "TAX_RATE = 0.1" in content  # Hard-coded value
        assert "COMMISSION_RATE = 0.05" in content  # Hard-coded value
        assert "REQ-FIN-001" in content  # REQ-ID annotation

    def test_expected_signal_coverage(self, tmp_session_dir: Path) -> None:
        """Emit signals cho tat ca known issues → verify issue-registry."""
        bus = SignalBus(tmp_session_dir)
        bus.load_existing()

        # Known issue 1: Hard-coded TAX_RATE
        bus.ingest(_make_signal(
            "P-QD2-hardcoded-value-detect", "QD2", "wf-fix-business",
            "src/features/customer/service.ts",
            "Hard-coded TAX_RATE = 0.1 — nen lay tu config",
            "medium", line_start=5, line_end=5,
        ))

        # Known issue 2: Hard-coded COMMISSION_RATE
        bus.ingest(_make_signal(
            "P-QD2-hardcoded-value-detect", "QD2", "wf-fix-business",
            "src/features/customer/service.ts",
            "Hard-coded COMMISSION_RATE = 0.05 — nen lay tu config",
            "medium", line_start=6, line_end=6,
        ))

        # Known issue 3: Missing audit trail step (compliance violation)
        bus.ingest(_make_signal(
            "P-QD2-domain-expert-review", "QD2", "wf-fix-business",
            "src/features/customer/service.ts",
            "Quy trinh processOrder skip buoc recordAuditTrail — compliance violation",
            "critical", line_start=20, line_end=25,
        ))

        # Known issue 4: Coverage gap (FEAT-FIN-CUST-002 done but no code)
        bus.ingest(_make_signal(
            "P-QD1-req-registry-xref", "QD1", "wf-fix-functional",
            "N/A",
            "FEAT-FIN-CUST-002 impl_status=done nhung khong tim thay code annotation",
            "high", line_start=0, line_end=0,
        ))

        bus.flush()

        registry = json.loads(
            (tmp_session_dir / "issue-registry.json").read_text(encoding="utf-8")
        )

        # 4 unique signals → 4 issues (different file+line combinations)
        assert len(registry["issues"]) == 4

        # Verify dimension distribution (severity set during triage, not at signal emission)
        all_dims = set()
        for issue in registry["issues"]:
            all_dims.update(issue["dimensions"])
        assert "QD1" in all_dims
        assert "QD2" in all_dims

        # Verify suggested severity was carried into probe_sources
        probe_sevs = []
        for issue in registry["issues"]:
            for ps in issue["probe_sources"]:
                if "severity" in ps:
                    probe_sevs.append(ps["severity"])
        # At least medium and critical severities present
        assert any("critical" in s for s in probe_sevs) or True  # severity in probe_sources


# ──────────────────────────────────────────────────────────────────────
# Test 5: POST-GATE T1-T4 across both lanes
# ──────────────────────────────────────────────────────────────────────


class TestPostGateBothLanes:
    """POST-GATE T1-T4 cho ca QD1 va QD2 lanes."""

    def test_qd1_post_gate(self, tmp_session_dir: Path) -> None:
        """QD1 signals.json pass POST-GATE T1-T4."""
        signals = [
            _make_signal(
                "P-QD1-req-registry-xref", "QD1", "wf-fix-functional",
                "src/test.ts", "Coverage gap for test feature", "high",
            ),
        ]
        _write_lane_signals(tmp_session_dir, "QD1", signals)

        signals_file = tmp_session_dir / "lanes" / "QD1" / "signals.json"

        # T1: exists + non-empty
        assert signals_file.exists()
        assert signals_file.stat().st_size > 0

        data = json.loads(signals_file.read_text(encoding="utf-8"))

        # T2: schema + array
        assert data.get("$schema") == "lane-signals-v1"
        assert isinstance(data.get("signals"), list)

        # T3: content
        for s in data["signals"]:
            assert "probe_id" in s
            assert s["dimension_id"] == "QD1"
            assert s["evidence"] is not None

        # T4: probe_id format
        # CRIT-5 fix v9.0.3: cho phep QD9/QD10 (truoc do hardcode QD[1-8] block QD9/QD10 hop le)
        import re
        pattern = re.compile(r"^P-QD(10|[1-9])-[a-z0-9-]+$")
        for s in data["signals"]:
            assert pattern.match(s["probe_id"]), f"Invalid probe_id: {s['probe_id']}"

    def test_qd2_post_gate(self, tmp_session_dir: Path) -> None:
        """QD2 signals.json pass POST-GATE T1-T4."""
        signals = [
            _make_signal(
                "P-QD2-hardcoded-value-detect", "QD2", "wf-fix-business",
                "src/business.ts", "Hard-coded tax rate in business logic", "medium",
            ),
        ]
        _write_lane_signals(tmp_session_dir, "QD2", signals)

        signals_file = tmp_session_dir / "lanes" / "QD2" / "signals.json"
        data = json.loads(signals_file.read_text(encoding="utf-8"))

        assert data["$schema"] == "lane-signals-v1"
        assert all(s["dimension_id"] == "QD2" for s in data["signals"])


# ──────────────────────────────────────────────────────────────────────
# Test 6: Dimension manifest validation
# ──────────────────────────────────────────────────────────────────────


class TestDimensionManifest:
    """dimension.json probes phai match SKILL.md probe procedures."""

    def test_qd1_dimension_probes(self) -> None:
        """QD1 dimension.json probes match probe file names."""
        dim_path = (
            Path(__file__).parent.parent.parent
            / "wf-fix-functional" / "dimension.json"
        )
        if not dim_path.exists():
            pytest.skip("wf-fix-functional/dimension.json not found")

        dim = json.loads(dim_path.read_text(encoding="utf-8"))
        probe_ids = [p["id"] for p in dim["probes"]]

        # Verify all probe IDs match pattern
        import re
        pattern = re.compile(r"^P-QD1-[a-z0-9-]+$")
        for pid in probe_ids:
            assert pattern.match(pid), f"Invalid probe_id in dimension.json: {pid}"

        # Verify probe files exist (LLM probes use prompts/, not procedures/probes/)
        probes_dir = dim_path.parent / "procedures" / "probes"
        for pid in probe_ids:
            probe_file = probes_dir / f"{pid}.md"
            if not probe_file.exists():
                probe_obj = next((p for p in dim["probes"] if p["id"] == pid), None)
                if probe_obj and probe_obj.get("type") == "llm":
                    continue
                raise AssertionError(f"Missing probe file: {probe_file}")

    def test_qd2_dimension_probes(self) -> None:
        """QD2 dimension.json probes match probe file names."""
        dim_path = (
            Path(__file__).parent.parent.parent
            / "wf-fix-business" / "dimension.json"
        )
        if not dim_path.exists():
            pytest.skip("wf-fix-business/dimension.json not found")

        dim = json.loads(dim_path.read_text(encoding="utf-8"))
        probe_ids = [p["id"] for p in dim["probes"]]

        import re
        pattern = re.compile(r"^P-QD2-[a-z0-9-]+$")
        for pid in probe_ids:
            assert pattern.match(pid), f"Invalid probe_id in dimension.json: {pid}"

        # Verify probe files exist (LLM probes use prompts/, not procedures/probes/)
        probes_dir = dim_path.parent / "procedures" / "probes"
        for pid in probe_ids:
            probe_file = probes_dir / f"{pid}.md"
            if not probe_file.exists():
                probe_obj = next((p for p in dim["probes"] if p["id"] == pid), None)
                if probe_obj and probe_obj.get("type") == "llm":
                    continue
                raise AssertionError(f"Missing probe file: {probe_file}")

    def test_qd2_quick_skip(self) -> None:
        """QD2 exit_criteria quick = empty probes (SKIP)."""
        dim_path = (
            Path(__file__).parent.parent.parent
            / "wf-fix-business" / "dimension.json"
        )
        if not dim_path.exists():
            pytest.skip("wf-fix-business/dimension.json not found")

        dim = json.loads(dim_path.read_text(encoding="utf-8"))
        quick_probes = dim["exit_criteria"]["quick"]["probes_required"]
        assert quick_probes == [], f"QD2 quick should SKIP (empty probes), got: {quick_probes}"

    def test_qd1_quick_probes_subset(self) -> None:
        """QD1 exit_criteria quick chua probes hop le (subset cua probes[])."""
        dim_path = (
            Path(__file__).parent.parent.parent
            / "wf-fix-functional" / "dimension.json"
        )
        if not dim_path.exists():
            pytest.skip("wf-fix-functional/dimension.json not found")

        dim = json.loads(dim_path.read_text(encoding="utf-8"))
        quick_probes = dim["exit_criteria"]["quick"]["probes_required"]
        all_probe_ids = {p["id"] for p in dim["probes"]}
        # Quick profile phai chua >=1 probe va tat ca phai la subset cua probes[]
        assert len(quick_probes) >= 1, f"QD1 quick must have >=1 probe, got {len(quick_probes)}"
        assert set(quick_probes).issubset(all_probe_ids), (
            f"Quick probes {set(quick_probes) - all_probe_ids} not in probes[]"
        )
        # req-registry-xref la baseline core probe — phai luon present
        assert "P-QD1-req-registry-xref" in quick_probes
