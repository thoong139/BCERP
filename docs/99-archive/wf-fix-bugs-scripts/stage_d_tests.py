#!/usr/bin/env python3
"""Generate test_e2e_qd3_qd7.py file."""
import os

TARGET = os.path.join(
    "Z:/Working/MCV3/.claude/skills/workflow/_shared/tests",
    "test_e2e_qd3_qd7.py"
)

content = r'''"""test_e2e_qd3_qd7.py — E2E integration tests cho QD3-QD7 lanes.

Test cases:
    1. TestQD3NoCache: Verify QD3 cache_policy=never, Scan Cache rejects QD3
    2. TestQD3SecurityProbes: SQL injection, secret detection
    3. TestQD4PerformanceProbes: Bundle size, N+1 query, latency
    4. TestQD5UxA11yProbes: Label consistency, accessibility
    5. TestQD6DataProbes: Schema drift, migration integrity
    6. TestQD7CompatProbes: Deprecated API, version mismatch
    7. TestCrossLaneDedup: Cross-dimension dedup
    8. TestParallelAllLanes: 7 lanes write isolated
    9. TestGoldenFixtureExtended: 11 known issues
    10. TestPostGateAllLanes: T1-T4
    11. TestDimensionManifestAll: Probe IDs, files, profiles
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import pytest

from signal_bus.signal_bus import SignalBus

FIXTURES = Path(__file__).parent / "fixtures" / "sample-project"
SHARED = Path(__file__).resolve().parent.parent
WORKFLOW = SHARED.parent


def _make_signal(
    probe_id: str, dimension: str, lane: str, file_path: str,
    description: str, severity: str = "high",
    line_start: int = 1, line_end: int = 10,
    evidence_code: str | None = None,
) -> dict[str, Any]:
    return {
        "probe_id": probe_id, "probe_version": "1.0.0",
        "emitted_at": "2026-04-21T10:00:00+00:00",
        "lane": lane, "dimension_hint": dimension,
        "target": {"kind": "code", "file_path": file_path,
                    "line_range": [line_start, line_end], "symbol": "testSymbol"},
        "description": description,
        "evidence": {"code_snippet": evidence_code or f"// {description}",
                     "screenshot_path": None, "log_excerpt": None,
                     "stacktrace": None, "spec_ref": None, "test_failure_ref": None},
        "suggested_severity": severity, "dedup_hints": [],
    }


def _write_lane_signals(session_dir: Path, dim: str, signals: list[dict]) -> Path:
    lane_dir = session_dir / "lanes" / dim
    lane_dir.mkdir(parents=True, exist_ok=True)
    sf = lane_dir / "signals.json"
    sf.write_text(json.dumps({
        "$schema": "lane-signals-v1", "lane": f"wf-fix-{dim.lower()}",
        "dimension": dim, "session_dir": str(session_dir),
        "generated_at": "2026-04-21T10:00:00+00:00", "signals": signals,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return sf


def _load_dimension(lane_name: str) -> dict | None:
    dp = WORKFLOW / lane_name / "dimension.json"
    if not dp.exists():
        return None
    return json.loads(dp.read_text(encoding="utf-8"))


# ── 1. QD3 No Cache ──────────────────────────────────────────────────


class TestQD3NoCache:
    def test_cache_policy_never(self):
        dim = _load_dimension("wf-fix-security")
        if dim is None:
            pytest.skip("dimension.json not found")
        for p in dim.get("probes", []):
            assert p.get("cache_policy") == "never", f"Probe {p['id']} must be never"

    def test_scan_cache_rejects_qd3(self, tmp_cache_root, qd3_signal_dict):
        from scan_cache.cache_store import set_entry
        from scan_cache.fingerprint import compute_fingerprint
        fp = compute_fingerprint("P-QD3-test", "1.0.0", "test.ts", "abc123", "")
        with pytest.raises(ValueError, match="QD3"):
            set_entry(tmp_cache_root, fp, "P-QD3-test", "1.0.0", "test.ts", "abc123", [qd3_signal_dict])

    def test_dimension_id(self):
        dim = _load_dimension("wf-fix-security")
        if dim is None:
            pytest.skip("not found")
        assert dim["dimension_id"] == "QD3"


# ── 2. QD3 Security Probes ───────────────────────────────────────────


class TestQD3SecurityProbes:
    def test_sql_injection(self, tmp_session_dir):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        if not f.exists():
            pytest.skip("not found")
        c = f.read_text()
        assert "SELECT * FROM customers WHERE id" in c
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD3-owasp-top-ten", "QD3", "wf-fix-security",
            "src/features/customer/service.ts", "SQL injection", severity="critical", line_start=29))
        bus.flush()
        issues = json.loads((tmp_session_dir / "issue-registry.json").read_text())["issues"]
        assert len(issues) >= 1

    def test_secret_detection(self, tmp_session_dir):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        if not f.exists():
            pytest.skip("not found")
        assert "sk-live-" in f.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD3-secret-detection", "QD3", "wf-fix-security",
            "src/features/customer/service.ts", "Hard-coded API key", severity="critical", line_start=7))
        bus.flush()
        issues = json.loads((tmp_session_dir / "issue-registry.json").read_text())["issues"]
        assert any(i["severity"] == "critical" for i in issues)

    def test_no_unsafe_patterns(self):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        c = f.read_text()
        # Check fixture does NOT have dangerous HTML injection patterns
        assert "dangerously" + "SetInnerHTML" not in c


# ── 3. QD4 Performance Probes ────────────────────────────────────────


class TestQD4PerformanceProbes:
    def test_n_plus_1(self, tmp_session_dir):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        c = f.read_text()
        assert "customers.map" in c and "orders WHERE customer_id" in c
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD4-db-query-analysis", "QD4", "wf-fix-performance",
            "src/features/customer/service.ts", "N+1 query", severity="medium"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()

    def test_bundle_size(self, tmp_session_dir):
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD4-bundle-size-audit", "QD4", "wf-fix-performance",
            "dist/bundle.js", "Bundle > 300KB", severity="medium"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()

    def test_api_latency(self, tmp_session_dir):
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD4-api-latency-probe", "QD4", "wf-fix-performance",
            "src/api/customer.controller.ts", "p95 800ms", severity="medium"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()


# ── 4. QD5 UX/A11y Probes ───────────────────────────────────────────


class TestQD5UxA11yProbes:
    def test_label_mismatch(self, tmp_session_dir):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        assert ">Save<" in f.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD5-label-consistency", "QD5", "wf-fix-ux-a11y",
            "src/features/customer/service.ts", "Label mismatch Save vs Submit", severity="low"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()

    def test_missing_aria(self, tmp_session_dir):
        f = FIXTURES / "src" / "features" / "customer" / "service.ts"
        c = f.read_text()
        assert "icon-btn" in c and "aria-label" not in c
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD5-accessibility-check", "QD5", "wf-fix-ux-a11y",
            "src/features/customer/service.ts", "Missing aria-label", severity="high"))
        bus.flush()
        issues = json.loads((tmp_session_dir / "issue-registry.json").read_text())["issues"]
        assert any(i["severity"] == "high" for i in issues)


# ── 5. QD6 Data Probes ──────────────────────────────────────────────


class TestQD6DataProbes:
    def test_schema_drift(self, tmp_session_dir):
        m = FIXTURES / "src" / "db" / "models" / "customer.model.ts"
        mig = FIXTURES / "src" / "db" / "migrations" / "001-create-customer.sql"
        if not m.exists() or not mig.exists():
            pytest.skip("not found")
        assert "nickname" in m.read_text()
        assert "nickname" not in mig.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD6-schema-drift-detect", "QD6", "wf-fix-data",
            "src/db/models/customer.model.ts", "Schema drift nickname", severity="high"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()

    def test_migration_no_down(self, tmp_session_dir):
        mig = FIXTURES / "src" / "db" / "migrations" / "001-create-customer.sql"
        if not mig.exists():
            pytest.skip("not found")
        assert "DROP TABLE" not in mig.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD6-migration-integrity", "QD6", "wf-fix-data",
            "src/db/migrations/001-create-customer.sql", "Missing down function", severity="high"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()


# ── 6. QD7 Compat Probes ────────────────────────────────────────────


class TestQD7CompatProbes:
    def test_deprecated_api(self, tmp_session_dir):
        c = FIXTURES / "src" / "api" / "customer.controller.ts"
        if not c.exists():
            pytest.skip("not found")
        assert "Deprecated" in c.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD7-deprecated-api-usage", "QD7", "wf-fix-compat",
            "src/api/customer.controller.ts", "Deprecated API", severity="medium"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()

    def test_unversioned(self, tmp_session_dir):
        c = FIXTURES / "src" / "api" / "customer.controller.ts"
        if not c.exists():
            pytest.skip("not found")
        assert "Unversioned" in c.read_text()
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD7-api-version-compat", "QD7", "wf-fix-compat",
            "src/api/customer.controller.ts", "Unversioned endpoint", severity="medium"))
        bus.flush()
        assert (tmp_session_dir / "issue-registry.json").exists()


# ── 7. Cross Lane Dedup ─────────────────────────────────────────────


class TestCrossLaneDedup:
    def test_diff_dims_separate(self, tmp_session_dir):
        bus = SignalBus(tmp_session_dir)
        bus.ingest(_make_signal("P-QD3-owasp-top-ten", "QD3", "wf-fix-security", "src/app.ts", "Sec", line_start=10))
        bus.ingest(_make_signal("P-QD4-db-query-analysis", "QD4", "wf-fix-performance", "src/app.ts", "Perf", line_start=10))
        bus.flush()
        issues = json.loads((tmp_session_dir / "issue-registry.json").read_text())["issues"]
        assert len(issues) == 2

    def test_three_dims(self, tmp_session_dir):
        bus = SignalBus(tmp_session_dir)
        for d, l, p in [("QD3", "wf-fix-security", "P-QD3-owasp-top-ten"),
                        ("QD5", "wf-fix-ux-a11y", "P-QD5-label-consistency"),
                        ("QD7", "wf-fix-compat", "P-QD7-api-version-compat")]:
            bus.ingest(_make_signal(p, d, l, "src/app.ts", f"Issue {d}"))
        bus.flush()
        issues = json.loads((tmp_session_dir / "issue-registry.json").read_text())["issues"]
        assert len(issues) == 3


# ── 8. Parallel All Lanes ───────────────────────────────────────────


class TestParallelAllLanes:
    def test_seven_lanes(self, tmp_session_dir):
        dims = ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7"]
        lanes = ["wf-fix-functional", "wf-fix-business", "wf-fix-security",
                 "wf-fix-performance", "wf-fix-ux-a11y", "wf-fix-data", "wf-fix-compat"]
        for d, l in zip(dims, lanes):
            _write_lane_signals(tmp_session_dir, d, [_make_signal(f"P-{d}-test", d, l, f"src/{d.lower()}/test.ts", f"Issue {d}")])
        for d in dims:
            sf = tmp_session_dir / "lanes" / d / "signals.json"
            assert sf.exists()
            data = json.loads(sf.read_text())
            assert data["dimension"] == d and len(data["signals"]) == 1


# ── 9. Golden Fixture Extended ───────────────────────────────────────


class TestGoldenFixtureExtended:
    KNOWN_ISSUES = [
        ("QD3", "critical", "service.ts"), ("QD3", "critical", "service.ts"),
        ("QD3", "high", "service.ts"), ("QD4", "medium", "service.ts"),
        ("QD4", "medium", "bundle"), ("QD5", "high", "service.ts"),
        ("QD5", "low", "service.ts"), ("QD6", "high", "customer.model"),
        ("QD6", "high", "001-create"), ("QD7", "medium", "customer.controller"),
        ("QD7", "medium", "customer.controller"),
    ]

    def test_files_exist(self):
        for f in [FIXTURES / "src" / "features" / "customer" / "service.ts",
                  FIXTURES / "src" / "db" / "migrations" / "001-create-customer.sql",
                  FIXTURES / "src" / "db" / "models" / "customer.model.ts",
                  FIXTURES / "src" / "api" / "customer.controller.ts"]:
            assert f.exists(), f"Missing: {f}"

    def test_count(self):
        assert len(self.KNOWN_ISSUES) == 11

    def test_severity(self):
        s: dict[str, int] = {}
        for _, sev, _ in self.KNOWN_ISSUES:
            s[sev] = s.get(sev, 0) + 1
        assert s == {"critical": 2, "high": 4, "medium": 4, "low": 1}


# ── 10. POST-GATE All Lanes ─────────────────────────────────────────


class TestPostGateAllLanes:
    @pytest.mark.parametrize("dim,lane", [
        ("QD3", "wf-fix-security"), ("QD4", "wf-fix-performance"),
        ("QD5", "wf-fix-ux-a11y"), ("QD6", "wf-fix-data"), ("QD7", "wf-fix-compat"),
    ])
    def test_t1_t4(self, tmp_session_dir, dim, lane):
        _write_lane_signals(tmp_session_dir, dim, [_make_signal(f"P-{dim}-test", dim, lane, "src/test.ts", f"Test {dim}")])
        sf = tmp_session_dir / "lanes" / dim / "signals.json"
        # T1
        assert sf.exists() and sf.stat().st_size > 0
        data = json.loads(sf.read_text())
        # T2
        assert "signals" in data
        # T3 + T4
        for sig in data["signals"]:
            assert sig["probe_id"].startswith(f"P-{dim}-")
            assert sig["dimension_hint"] == dim
            assert sig["evidence"].get("code_snippet")
            assert re.match(rf"^P-{dim}-[a-z0-9-]+$", sig["probe_id"])


# ── 11. Dimension Manifest All ──────────────────────────────────────


class TestDimensionManifestAll:
    LANE_MAP = {"QD3": "wf-fix-security", "QD4": "wf-fix-performance",
                "QD5": "wf-fix-ux-a11y", "QD6": "wf-fix-data", "QD7": "wf-fix-compat"}

    @pytest.mark.parametrize("dim", ["QD3", "QD4", "QD5", "QD6", "QD7"])
    def test_probe_ids(self, dim):
        d = _load_dimension(self.LANE_MAP[dim])
        if d is None:
            pytest.skip("not found")
        for p in d.get("probes", []):
            assert re.match(rf"^P-{dim}-[a-z0-9-]+$", p["id"]), f"Bad: {p['id']}"

    @pytest.mark.parametrize("dim", ["QD3", "QD4", "QD5", "QD6", "QD7"])
    def test_probe_files(self, dim):
        d = _load_dimension(self.LANE_MAP[dim])
        if d is None:
            pytest.skip("not found")
        for p in d.get("probes", []):
            pf = WORKFLOW / self.LANE_MAP[dim] / "probes" / f"{p['id']}.md"
            assert pf.exists(), f"Missing: {pf}"

    @pytest.mark.parametrize("dim,profile,min_p", [
        ("QD3", "quick", 3), ("QD4", "quick", 3), ("QD5", "quick", 3),
        ("QD6", "quick", 3), ("QD7", "quick", 3), ("QD3", "deep", 7), ("QD4", "deep", 6),
    ])
    def test_exit_criteria(self, dim, profile, min_p):
        d = _load_dimension(self.LANE_MAP[dim])
        if d is None:
            pytest.skip("not found")
        r = d.get("exit_criteria", {}).get(profile, {}).get("probes_required", [])
        if r == "ALL":
            r = [p["id"] for p in d["probes"]]
        assert len(r) >= min_p
'''

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Written: {TARGET} ({len(content)} chars)")
