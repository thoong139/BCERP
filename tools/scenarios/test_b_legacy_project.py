"""test_b_legacy_project.py -- Scenario B: Existing project full path (13 skills).

Verify: LEGACY_MODE detect (CORE-021), legacy-decisions.json propagate,
gap analysis integration, module-code-mapping.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from fixtures.project_b import generate_project_b
from validators.path_contract import validate_all_contracts


@pytest.fixture
def project_b_mc(tmp_path: Path) -> Path:
    """Tao Project B fixture trong tmp_path, tra ve .mc-data/ path."""
    return generate_project_b(tmp_path)


def _load_json(path: Path) -> dict:
    """Helper doc va parse JSON file."""
    return json.loads(path.read_text(encoding="utf-8"))


@pytest.mark.scenario_b
class TestProjectBFixture:
    """Kiem tra Project B -- du an legacy/existing day du 13 skills."""

    def test_legacy_mode_detected(self, project_b_mc: Path) -> None:
        """Verify LEGACY_MODE detect dung (CORE-021): project-context.md ton tai va > 500 bytes."""
        ctx = project_b_mc / "work" / "legacy-scan" / "project-context.md"
        assert ctx.exists(), "project-context.md khong ton tai -- LEGACY_MODE khong detect duoc"
        size = ctx.stat().st_size
        assert size > 500, (
            f"project-context.md chi {size} bytes -- can > 500 cho CORE-021"
        )

    def test_legacy_decisions_exist(self, project_b_mc: Path) -> None:
        """Verify legacy-decisions.json ton tai va co deprecated_modules list (CORE-022)."""
        decisions_path = (
            project_b_mc / "work" / "wf-brainstorm" / "legacy-decisions.json"
        )
        assert decisions_path.exists(), "legacy-decisions.json khong ton tai"
        data = _load_json(decisions_path)
        assert "deprecated_modules" in data, "Thieu 'deprecated_modules' key"
        assert isinstance(data["deprecated_modules"], list), (
            "deprecated_modules phai la list"
        )

    def test_module_code_mapping_exists(self, project_b_mc: Path) -> None:
        """Verify module-code-mapping.json ton tai va la JSON hop le."""
        mapping_path = project_b_mc / "work" / "legacy-scan" / "module-code-mapping.json"
        assert mapping_path.exists(), "module-code-mapping.json khong ton tai"
        data = _load_json(mapping_path)
        assert "mappings" in data, "Thieu 'mappings' key trong module-code-mapping"
        assert isinstance(data["mappings"], list), "'mappings' phai la list"

    def test_doc_quality_map(self, project_b_mc: Path) -> None:
        """Verify doc-quality-map.json ton tai voi trust scores."""
        quality_path = project_b_mc / "work" / "legacy-scan" / "doc-quality-map.json"
        assert quality_path.exists(), "doc-quality-map.json khong ton tai"
        data = _load_json(quality_path)
        assert "scores" in data, "Thieu 'scores' key trong doc-quality-map"
        assert "average_trust" in data, "Thieu 'average_trust' key"
        assert 0 <= data["average_trust"] <= 1, "average_trust ngoai range [0, 1]"

    def test_depgraph_exists(self, project_b_mc: Path) -> None:
        """Verify dependency-graph.json ton tai trong legacy-scan/inventory/."""
        depgraph = (
            project_b_mc / "work" / "legacy-scan" / "inventory" / "dependency-graph.json"
        )
        assert depgraph.exists(), "dependency-graph.json khong ton tai"
        data = _load_json(depgraph)
        assert "nodes" in data, "Thieu 'nodes' key trong dependency-graph"
        assert "edges" in data, "Thieu 'edges' key trong dependency-graph"

    def test_source_code_stubs(self, tmp_path: Path, project_b_mc: Path) -> None:
        """Verify src/ directory co it nhat 3 source files (legacy codebase simulation)."""
        src = tmp_path / "src"
        assert src.is_dir(), "src/ directory khong ton tai"
        source_files = list(src.rglob("*.ts"))
        assert len(source_files) >= 3, (
            f"Cho >= 3 source files, thay {len(source_files)}"
        )

    def test_registry_has_done_status(self, project_b_mc: Path) -> None:
        """Verify mot so requirements co impl_status='done' (legacy da implement)."""
        registry_path = project_b_mc / "docs" / "_meta" / "req-registry.json"
        data = _load_json(registry_path)
        done_reqs = [
            r for r in data.get("requirements", [])
            if r.get("impl_status") == "done"
        ]
        assert len(done_reqs) > 0, "Legacy project phai co it nhat 1 req voi impl_status='done'"

    def test_path_contracts_legacy(self, project_b_mc: Path) -> None:
        """Verify LEGACY_MODE conditional contracts resolve (khong SKIP khi project-context.md > 500 bytes)."""
        results = validate_all_contracts(project_b_mc)

        # Kiem tra khong co FAIL
        failures = [r for r in results if r["status"] == "FAIL"]
        assert failures == [], (
            f"Path contract failures: {[f['message'] for f in failures]}"
        )

        # Kiem tra LEGACY_MODE contracts duoc resolve (khong SKIP)
        legacy_contracts = [
            r for r in results
            if r["contract"].conditional == "LEGACY_MODE"
        ]
        for lc in legacy_contracts:
            assert lc["status"] != "SKIP", (
                f"LEGACY_MODE contract bi SKIP khi project-context.md > 500 bytes: "
                f"{lc['contract'].output_path}"
            )
