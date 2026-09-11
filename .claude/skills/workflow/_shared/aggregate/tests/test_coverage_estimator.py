"""Tests cho coverage_estimator — Phase A wf-fix-bugs Coverage Improvement v8."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from aggregate import coverage_estimator as ce


class TestNormalizeStack:
    @pytest.mark.parametrize("inp,expected", [
        (None, "unknown"),
        ("", "unknown"),
        ("typescript-react", "typescript-react"),
        ("ts-react", "typescript-react"),
        ("nextjs", "typescript-nextjs"),
        ("csharp", "csharp-dotnet"),
        ("dotnet", "csharp-dotnet"),
        (".net", "csharp-dotnet"),
        ("python", "python-fastapi"),
        ("django", "python-django"),
        ("golang", "go"),
        ("java", "java-spring"),
        ("typescript_react", "typescript-react"),  # underscore alias
        ("WeIrD-StAcK", "unknown"),
    ])
    def test_normalize(self, inp, expected):
        assert ce._normalize_stack(inp) == expected


class TestDimensionCoverage:
    def test_all_dimensions(self):
        all_dims = list(ce.DIMENSION_WEIGHTS.keys())
        assert ce._compute_dimension_coverage_pct(all_dims) == 100

    def test_empty(self):
        assert ce._compute_dimension_coverage_pct([]) == 0

    def test_subset(self):
        # v8.2 weights (after QD8 added): QD1 (0.18) + QD5 (0.14) = 0.32 → 32
        assert ce._compute_dimension_coverage_pct(["QD1", "QD5"]) == 32


class TestEstimateCoverage:
    def test_csharp_exhaustive_llm(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="exhaustive",
            dimensions=list(ce.DIMENSION_WEIGHTS.keys()),
            llm_enabled=True,
        )
        # base=75 * 1.15 * 1.0 = 86 + 20 LLM = 95 (capped)
        assert result["coverage_estimate_pct"] == 95
        assert result["confidence"] == "high"
        assert result["llm_scan_enabled"] is True
        assert result["stack"] == "csharp-dotnet"

    def test_unknown_quick_no_llm(self):
        result = ce.estimate_coverage(
            stack=None,
            profile="quick",
            dimensions=["QD1"],
            llm_enabled=False,
        )
        # Stack unknown + quick + 1 dim → very low coverage, low confidence
        assert result["coverage_estimate_pct"] < 10
        assert result["confidence"] == "low"
        assert any("Stack không xác định" in s for s in result["blind_spots"])

    def test_typescript_react_deep(self):
        result = ce.estimate_coverage(
            stack="typescript-react",
            profile="deep",
            dimensions=["QD1", "QD2", "QD3", "QD5", "QD6", "QD7"],
            llm_enabled=False,
        )
        # base=65 * 1.0 * (0.20+0.18+0.15+0.15+0.12+0.10=0.90) = 58.5 → 58 or 59
        assert 50 <= result["coverage_estimate_pct"] <= 65
        assert result["confidence"] == "medium"

    def test_llm_bonus_applied(self):
        without_llm = ce.estimate_coverage(
            stack="typescript-react",
            profile="deep",
            dimensions=list(ce.DIMENSION_WEIGHTS.keys()),
            llm_enabled=False,
        )
        with_llm = ce.estimate_coverage(
            stack="typescript-react",
            profile="deep",
            dimensions=list(ce.DIMENSION_WEIGHTS.keys()),
            llm_enabled=True,
        )
        assert with_llm["coverage_estimate_pct"] > without_llm["coverage_estimate_pct"]
        diff = with_llm["coverage_estimate_pct"] - without_llm["coverage_estimate_pct"]
        assert diff == 15  # LLM_BONUS_PCT["deep"]

    def test_cap_at_95(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="exhaustive",
            dimensions=list(ce.DIMENSION_WEIGHTS.keys()),
            llm_enabled=True,
        )
        assert result["coverage_estimate_pct"] <= 95

    def test_blind_spots_always_present(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="exhaustive",
            dimensions=list(ce.DIMENSION_WEIGHTS.keys()),
            llm_enabled=True,
        )
        assert len(result["blind_spots"]) >= 5
        assert any("Race conditions" in s for s in result["blind_spots"])

    def test_recommendations_for_quick_no_llm(self):
        result = ce.estimate_coverage(
            stack="typescript-react",
            profile="quick",
            dimensions=["QD1"],
            llm_enabled=False,
        )
        # Should recommend upgrading profile
        assert any("standard" in r for r in result["recommendations"])
        assert any("dimensions còn thiếu" in r.lower() or "missing" in r.lower() or "thiếu" in r for r in result["recommendations"])

    def test_low_coverage_warning(self):
        result = ce.estimate_coverage(
            stack="vue",
            profile="quick",
            dimensions=["QD1"],
            llm_enabled=False,
        )
        # Should warn about low coverage
        assert result["coverage_estimate_pct"] < 50
        assert any("THẤP" in r or "low" in r.lower() for r in result["recommendations"])

    def test_disclaimer_present(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="standard",
            dimensions=["QD1", "QD2"],
        )
        assert "ƯỚC TÍNH" in result["disclaimer"] or "estimate" in result["disclaimer"].lower()

    def test_schema_version_present(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="standard",
            dimensions=["QD1"],
        )
        assert result["schema"] == "coverage-estimate-v1"
        assert "version" in result


class TestLoadSessionInputs:
    def test_missing_fix_status(self, tmp_path: Path):
        with pytest.raises(FileNotFoundError):
            ce.load_session_inputs(tmp_path)

    def test_load_valid_session(self, tmp_path: Path):
        fix_status = {
            "profile_used": "deep",
            "dimensions_resolved": ["QD1", "QD2", "QD5"],
            "flags": {"llm_scan": False},
        }
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        stack, profile, dims, llm = ce.load_session_inputs(tmp_path)
        assert stack is None  # No stack-info.json
        assert profile == "deep"
        assert dims == ["QD1", "QD2", "QD5"]
        assert llm is False

    def test_load_with_stack_info(self, tmp_path: Path):
        fix_status = {
            "profile_used": "exhaustive",
            "dimensions_resolved": ["QD1", "QD2"],
            "flags": {"llm_scan": True},
        }
        stack_info = {"primary_stack": "typescript-react"}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        (tmp_path / "stack-info.json").write_text(json.dumps(stack_info), encoding="utf-8")
        stack, profile, dims, llm = ce.load_session_inputs(tmp_path)
        assert stack == "typescript-react"
        assert profile == "exhaustive"
        assert llm is True

    def test_corrupt_stack_info_falls_back(self, tmp_path: Path):
        fix_status = {"profile_used": "standard", "dimensions_resolved": ["QD1"], "flags": {}}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        (tmp_path / "stack-info.json").write_text("{not valid json", encoding="utf-8")
        stack, profile, dims, llm = ce.load_session_inputs(tmp_path)
        assert stack is None  # Falls back gracefully


class TestRuntimeCoverage:
    """Tests cho QD9 runtime coverage (v1.1.0)."""

    def test_compute_runtime_pct_no_qd9(self):
        assert ce._compute_runtime_pct(["QD1", "QD2"], "standard") == 0

    def test_compute_runtime_pct_quick_skips(self):
        # QD9 in dims nhưng quick profile → QD9 lane tự skip
        assert ce._compute_runtime_pct(["QD1", "QD9"], "quick") == 0

    def test_compute_runtime_pct_standard(self):
        assert ce._compute_runtime_pct(["QD1", "QD9"], "standard") == 5

    def test_compute_runtime_pct_deep(self):
        assert ce._compute_runtime_pct(["QD9"], "deep") == 8

    def test_compute_runtime_pct_exhaustive(self):
        assert ce._compute_runtime_pct(["QD9"], "exhaustive") == 10

    def test_estimate_with_qd9_adds_runtime(self):
        without_qd9 = ce.estimate_coverage(
            stack="typescript-react",
            profile="standard",
            dimensions=["QD1", "QD2"],
            llm_enabled=False,
        )
        with_qd9 = ce.estimate_coverage(
            stack="typescript-react",
            profile="standard",
            dimensions=["QD1", "QD2", "QD9"],
            llm_enabled=False,
        )
        assert with_qd9["runtime_pct"] == 5
        assert without_qd9["runtime_pct"] == 0
        assert with_qd9["coverage_estimate_pct"] == without_qd9["coverage_estimate_pct"] + 5

    def test_runtime_warn_on_web_project_no_qd9(self):
        result = ce.estimate_coverage(
            stack="typescript-react",
            profile="standard",
            dimensions=["QD1", "QD2"],
            llm_enabled=False,
            interface_type="web",
        )
        assert result["runtime_warn"] is True
        # Phải có recommendation về browser
        assert any("browser" in r.lower() or "QD9" in r or "runtime" in r.lower()
                   for r in result["recommendations"])

    def test_runtime_warn_false_for_api_only(self):
        result = ce.estimate_coverage(
            stack="python-fastapi",
            profile="standard",
            dimensions=["QD1", "QD2"],
            llm_enabled=False,
            interface_type="api-only",
        )
        assert result["runtime_warn"] is False

    def test_runtime_warn_false_when_qd9_runs(self):
        result = ce.estimate_coverage(
            stack="typescript-react",
            profile="standard",
            dimensions=["QD1", "QD9"],
            llm_enabled=False,
            interface_type="web",
        )
        assert result["runtime_warn"] is False

    def test_runtime_warn_false_when_interface_type_none(self):
        result = ce.estimate_coverage(
            stack="typescript-react",
            profile="standard",
            dimensions=["QD1"],
            llm_enabled=False,
            interface_type=None,
        )
        # interface_type=None → no warn (vì không biết có UI hay không)
        assert result["runtime_warn"] is False

    def test_new_fields_present(self):
        result = ce.estimate_coverage(
            stack="csharp-dotnet",
            profile="standard",
            dimensions=["QD1"],
        )
        assert "static_pct" in result
        assert "runtime_pct" in result
        assert "runtime_warn" in result
        assert "runtime_bonus_pct" in result["components"]


class TestLoadSessionInterfaceType:
    def test_missing_file_returns_none(self, tmp_path: Path):
        assert ce.load_session_interface_type(tmp_path) is None

    def test_reads_interface_type(self, tmp_path: Path):
        fix_status = {"interface_type": "web", "profile_used": "standard",
                      "dimensions_resolved": ["QD1"], "flags": {}}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        assert ce.load_session_interface_type(tmp_path) == "web"

    def test_missing_field_returns_none(self, tmp_path: Path):
        fix_status = {"profile_used": "standard", "dimensions_resolved": ["QD1"], "flags": {}}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        assert ce.load_session_interface_type(tmp_path) is None

    def test_corrupt_json_returns_none(self, tmp_path: Path):
        (tmp_path / "fix-status.json").write_text("{bad json", encoding="utf-8")
        assert ce.load_session_interface_type(tmp_path) is None


class TestCLI:
    def test_cli_full_flow(self, tmp_path: Path):
        fix_status = {
            "profile_used": "deep",
            "dimensions_resolved": ["QD1", "QD2", "QD5"],
            "flags": {"llm_scan": False},
        }
        stack_info = {"primary_stack": "typescript-react"}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        (tmp_path / "stack-info.json").write_text(json.dumps(stack_info), encoding="utf-8")

        rc = ce.main(["--session", str(tmp_path)])
        assert rc == 0

        output_path = tmp_path / "coverage-estimate.json"
        assert output_path.exists()
        data = json.loads(output_path.read_text(encoding="utf-8"))
        assert data["stack"] == "typescript-react"
        assert data["profile"] == "deep"
        assert "coverage_estimate_pct" in data

    def test_cli_missing_session(self, capsys):
        rc = ce.main(["--session", "/nonexistent/path"])
        assert rc == 2
        captured = capsys.readouterr()
        assert "không tồn tại" in captured.err or "not exist" in captured.err.lower()

    def test_cli_override_flags(self, tmp_path: Path):
        fix_status = {"profile_used": "quick", "dimensions_resolved": ["QD1"], "flags": {}}
        (tmp_path / "fix-status.json").write_text(json.dumps(fix_status), encoding="utf-8")
        rc = ce.main([
            "--session", str(tmp_path),
            "--stack", "csharp-dotnet",
            "--profile", "exhaustive",
            "--dims", "QD1,QD2,QD3,QD4,QD5,QD6,QD7",
            "--llm-scan",
        ])
        assert rc == 0
        data = json.loads((tmp_path / "coverage-estimate.json").read_text(encoding="utf-8"))
        assert data["stack"] == "csharp-dotnet"
        assert data["profile"] == "exhaustive"
        assert data["llm_scan_enabled"] is True
        assert data["coverage_estimate_pct"] >= 80
