"""Tests for ips_recommender.py — Phase C implementation.

Covers:
- CLI parser smoke tests
- run_phase_a() on 3 synthetic fixtures (small-en, medium-vn, large-mixed)
- run_phase_b() module clustering, coupling, hotspots, routing, workload
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_SHARED_ROOT = Path(__file__).resolve().parents[2]
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))

from ips import ips_recommender as ipsr  # noqa: E402


# ─── CLI ─────────────────────────────────────────────────────


class TestCliParser:
    def test_help(self, capsys) -> None:
        parser = ipsr._build_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(["--help"])
        out = capsys.readouterr().out
        assert "phase_a" in out
        assert "phase_b" in out

    def test_phase_a_requires_args(self) -> None:
        parser = ipsr._build_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(["phase_a"])

    def test_phase_a_parses(self) -> None:
        parser = ipsr._build_parser()
        args = parser.parse_args(
            [
                "phase_a",
                "--project-profile", "/tmp/pp.json",
                "--assessment", "/tmp/a.json",
                "--output", "/tmp/o.json",
            ]
        )
        assert args.phase == "phase_a"
        assert str(args.project_profile) in ("/tmp/pp.json", "\\tmp\\pp.json")


# ─── Synthetic Fixture Factories ─────────────────────────────


def _write_profile_pair(
    tmp_path: Path,
    profile: dict,
    assessment: dict,
) -> tuple[Path, Path]:
    pp = tmp_path / "project-profile.json"
    ap = tmp_path / "assessment-report.json"
    pp.write_text(json.dumps(profile, ensure_ascii=False), encoding="utf-8")
    ap.write_text(json.dumps(assessment, ensure_ascii=False), encoding="utf-8")
    return pp, ap


def _small_en_fixture():
    profile = {
        "name": "small-en",
        "file_counts": {"total": 50},
        "top_level_dirs": ["customer", "sales", "reporting"],
        "frameworks": ["React"],
        "dependencies": {"production": ["react", "axios"]},
        "doc_maturity": {"level": "CODE_ONLY"},
    }
    assessment = {
        "maturity_level": "CODE_ONLY",
        "scores": {
            "code_quality": {"score": 75},
            "doc_quality": {"score": 55},
            "alignment": {"score": 60},
        },
    }
    return profile, assessment


def _medium_vn_fixture():
    profile = {
        "name": "medium-vn",
        "file_counts": {"total": 500},
        "top_level_dirs": [
            "qlkh",
            "hoadon",
            "qlns",
            "chamcong",
            "bangluong",
            "nhapkho",
            "xuatkho",
            "baocao",
            "caidat",
            "dangnhap",
        ],
        "frameworks": ["ASP.NET Core", "React"],
        "dependencies": {"production": ["Microsoft.AspNetCore.App"]},
        "doc_maturity": {"level": "CODE_ONLY"},
    }
    assessment = {
        "maturity_level": "CODE_ONLY",
        "scores": {
            "code_quality": {"score": 68},
            "doc_quality": {"score": 40},
            "alignment": {"score": 50},
        },
    }
    return profile, assessment


def _large_mixed_fixture():
    profile = {
        "name": "large-mixed",
        "file_counts": {"total": 1500},
        "top_level_dirs": [
            "billing",
            "invoice",
            "payment",
            "tax",
            "shipping",
            "delivery",
            "customs",
            "warehouse",
            "hr",
            "payroll",
            "sales-crm",
            "quotes",
            "audit-log",
            "compliance",
            "qlkh",
            "hoadon",
            "baogia",
            "vanchuyen",
            "haiquan",
            "khobai",
            "qlns",
            "chamcong",
            "bangluong",
            "tuanthu",
        ],
        "frameworks": ["Node.js", "Express", "React"],
        "dependencies": {"production": ["decimal.js", "express"]},
        "doc_maturity": {"level": "CODE_ONLY"},
    }
    assessment = {
        "maturity_level": "CODE_ONLY",
        "scores": {
            "code_quality": {"score": 62},
            "doc_quality": {"score": 45},
            "alignment": {"score": 55},
        },
    }
    return profile, assessment


# ─── run_phase_a ─────────────────────────────────────────────


class TestRunPhaseA:
    def test_small_en_recommends_standard_or_deep(self, tmp_path) -> None:
        profile, assessment = _small_en_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"

        result = ipsr.run_phase_a(pp, ap, out)

        assert result["recommended_profile"] in ("standard", "deep")
        assert result["detected_domains"]  # at least one
        assert result["detected_domains"][0]["domain"] == "sales"

    def test_medium_vn_detects_multiple_domains(self, tmp_path) -> None:
        profile, assessment = _medium_vn_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"

        result = ipsr.run_phase_a(pp, ap, out)

        domains = {d["domain"] for d in result["detected_domains"]}
        # medium-vn must detect at least sales, hr, finance, operations
        for expected in ("sales", "hr", "finance", "operations"):
            assert expected in domains

    def test_medium_vn_recommends_deep(self, tmp_path) -> None:
        """medium-vn has 4+ domains → multi-domain triggers deep."""
        profile, assessment = _medium_vn_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"
        result = ipsr.run_phase_a(pp, ap, out)
        assert result["recommended_profile"] == "deep"

    def test_large_mixed_recommends_deep(self, tmp_path) -> None:
        profile, assessment = _large_mixed_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"
        result = ipsr.run_phase_a(pp, ap, out)
        assert result["recommended_profile"] == "deep"

    def test_near_complete_recommends_surface(self, tmp_path) -> None:
        profile, assessment = _small_en_fixture()
        assessment["maturity_level"] = "NEAR_COMPLETE"
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"
        result = ipsr.run_phase_a(pp, ap, out)
        assert result["recommended_profile"] == "surface"

    def test_output_schema_fields(self, tmp_path) -> None:
        profile, assessment = _small_en_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"
        result = ipsr.run_phase_a(pp, ap, out)

        for key in (
            "$schema",
            "run_at",
            "recommended_profile",
            "profile_reasoning",
            "detected_domains",
            "unresolved_patterns",
            "warnings",
            "user_overrode_profile",
        ):
            assert key in result

        # File actually written
        assert out.exists()
        on_disk = json.loads(out.read_text(encoding="utf-8"))
        assert on_disk["recommended_profile"] == result["recommended_profile"]

    def test_detected_domains_sorted_desc(self, tmp_path) -> None:
        profile, assessment = _large_mixed_fixture()
        pp, ap = _write_profile_pair(tmp_path, profile, assessment)
        out = tmp_path / "ips-phase-a.json"
        result = ipsr.run_phase_a(pp, ap, out)
        confs = [d["confidence"] for d in result["detected_domains"]]
        assert confs == sorted(confs, reverse=True)


# ─── Phase B Helpers ─────────────────────────────────────────


class TestClusterFilesByModule:
    def test_basic_clustering(self) -> None:
        paths = [
            "src/billing/invoice.ts",
            "src/billing/payment.ts",
            "src/customer/list.ts",
            "apps/frontend/src/components/Button.tsx",
        ]
        mods = ipsr._cluster_files_by_module(paths)
        assert "billing" in mods
        assert "customer" in mods
        # "frontend" is the first non-generic after apps/
        assert "frontend" in mods

    def test_root_files_grouped(self) -> None:
        paths = ["README.md", "index.ts"]
        mods = ipsr._cluster_files_by_module(paths)
        assert "_root" in mods


class TestCoupling:
    def test_crossboundary_edge_counts(self) -> None:
        module_files = {
            "billing": ["src/billing/a.ts"],
            "customer": ["src/customer/b.ts"],
        }
        dep_graph = {
            "edges": [
                {"from": "src/billing/a.ts", "to": "src/customer/b.ts"},
                {"from": "src/customer/b.ts", "to": "src/billing/a.ts"},
            ]
        }
        coupling = ipsr._compute_coupling(module_files, dep_graph)
        assert coupling["billing"] == 2
        assert coupling["customer"] == 2

    def test_intra_module_edges_ignored(self) -> None:
        module_files = {"billing": ["src/billing/a.ts", "src/billing/b.ts"]}
        dep_graph = {
            "edges": [{"from": "src/billing/a.ts", "to": "src/billing/b.ts"}]
        }
        coupling = ipsr._compute_coupling(module_files, dep_graph)
        assert coupling.get("billing", 0) == 0

    def test_missing_dep_graph(self) -> None:
        coupling = ipsr._compute_coupling({"m": ["f"]}, None)
        assert dict(coupling) == {}


class TestHotspots:
    def test_hotspot_picks_top_20pct(self) -> None:
        module_files = {f"m{i}": ["x"] * (i + 1) for i in range(10)}
        coupling = {f"m{i}": i for i in range(10)}
        hs = ipsr._find_hotspots(module_files, coupling)
        # top 20% of 10 = 2 modules
        assert len(hs) == 2
        # Sorted desc — should include m9 (most files + coupling)
        names = {h["module"] for h in hs}
        assert "m9" in names

    def test_single_module_returns_self(self) -> None:
        hs = ipsr._find_hotspots({"m1": ["a", "b"]}, {"m1": 5})
        assert len(hs) == 1
        assert hs[0]["module"] == "m1"


class TestRouteModulesToDomains:
    def test_vn_route_qlkh_to_sales(self) -> None:
        from ips.vietnamese_keywords import load_pool
        pool = load_pool()
        module_files = {"qlkh": ["src/qlkh/a.ts"]}
        ips_a = {"detected_domains": []}
        routing = ipsr._route_modules_to_domains(module_files, ips_a, pool)
        assert "qlkh" in routing
        assert routing["qlkh"]["domain"] == "sales"
        assert routing["qlkh"]["expert"] == "sales-expert"

    def test_en_route_billing_to_finance(self) -> None:
        from ips.vietnamese_keywords import load_pool
        pool = load_pool()
        module_files = {"billing": ["src/billing/x.ts"]}
        ips_a = {"detected_domains": []}
        routing = ipsr._route_modules_to_domains(module_files, ips_a, pool)
        assert routing["billing"]["domain"] == "finance"

    def test_unknown_module_unrouted(self) -> None:
        from ips.vietnamese_keywords import load_pool
        pool = load_pool()
        module_files = {"xyzfoo": ["src/xyzfoo/a.ts"]}
        ips_a = {"detected_domains": []}
        routing = ipsr._route_modules_to_domains(module_files, ips_a, pool)
        assert "xyzfoo" not in routing


class TestEstimateWorkload:
    def test_standard_500_files(self) -> None:
        w = ipsr._estimate_workload("standard", 500, 10)
        # density 0.08 × 500 = 40 features × 1.5 min = 60 min
        assert w["total_features_est"] == 40
        assert w["est_time_min"] == 60
        assert w["budget_min"] == 35
        assert w["exceeds_cap"] is True  # 60 > 52.5 soft cap

    def test_deep_1500_files(self) -> None:
        w = ipsr._estimate_workload("deep", 1500, 20)
        assert w["total_features_est"] == 180  # 0.12 × 1500
        assert w["est_time_min"] == 450  # 180 × 2.5

    def test_surface_zero_workload(self) -> None:
        w = ipsr._estimate_workload("surface", 100, 3)
        assert w["total_features_est"] == 0
        assert w["est_time_min"] == 0


# ─── run_phase_b end-to-end ──────────────────────────────────


class TestRunPhaseB:
    def _write_inventory(self, tmp_path: Path, source_files: list, deps: dict):
        inv_dir = tmp_path / "inventory"
        inv_dir.mkdir()
        (inv_dir / "source-files.json").write_text(
            json.dumps({"files": source_files}, ensure_ascii=False),
            encoding="utf-8",
        )
        (inv_dir / "dependency-graph.json").write_text(
            json.dumps(deps, ensure_ascii=False), encoding="utf-8"
        )
        return inv_dir

    def test_medium_vn_phase_b_output(self, tmp_path) -> None:
        # Build synthetic source-files inventory matching medium-vn modules.
        source_files = []
        modules_map = {
            "qlkh": 50,
            "hoadon": 60,
            "qlns": 50,
            "chamcong": 45,
            "bangluong": 50,
            "nhapkho": 40,
            "xuatkho": 40,
            "baocao": 50,
            "caidat": 40,
            "dangnhap": 75,
        }
        for mod, count in modules_map.items():
            for i in range(count):
                source_files.append({"path": f"src/{mod}/file{i}.ts"})
        deps = {"edges": []}
        inv_dir = self._write_inventory(tmp_path, source_files, deps)

        ips_a = {
            "recommended_profile": "deep",
            "detected_domains": [
                {"domain": "hr", "confidence": 0.85, "recommended_expert": "hr-expert"},
                {"domain": "sales", "confidence": 0.4, "recommended_expert": "sales-expert"},
            ],
        }
        ips_a_path = tmp_path / "ips-phase-a.json"
        ips_a_path.write_text(json.dumps(ips_a, ensure_ascii=False), encoding="utf-8")
        out = tmp_path / "ips-phase-b.json"

        result = ipsr.run_phase_b(inv_dir, ips_a_path, out)

        # Module count = 10
        assert result["module_count"] == 10

        # Routing covers VN-named modules (70% of 10 = 7+)
        routing = result["module_routing"]
        assert len(routing) >= 7, f"expected ≥7 routed modules, got {routing.keys()}"
        assert routing["qlkh"]["domain"] == "sales"
        assert routing["hoadon"]["domain"] == "finance"

        # Workload populated for deep profile
        assert result["workload_estimate"]["total_features_est"] > 0
        assert result["profile_used"] == "deep"

        # File written
        assert out.exists()

    def test_workload_gate_triggers_on_large(self, tmp_path) -> None:
        source_files = [
            {"path": f"src/billing/f{i}.ts"} for i in range(150)
        ]
        inv_dir = self._write_inventory(tmp_path, source_files, {"edges": []})
        ips_a_path = tmp_path / "ips-phase-a.json"
        ips_a_path.write_text(
            json.dumps(
                {"recommended_profile": "deep", "detected_domains": []}
            ),
            encoding="utf-8",
        )
        out = tmp_path / "ips-phase-b.json"

        result = ipsr.run_phase_b(inv_dir, ips_a_path, out)

        # largest_module=150 > 50 → gate triggered
        assert result["workload_gate"]["triggered"] is True
        assert any("largest_module" in r for r in result["workload_gate"]["reasons"])
