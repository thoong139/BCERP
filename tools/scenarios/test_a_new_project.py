"""test_a_new_project.py -- Scenario A: New project full path (10 skills).

Verify: Full .mc-data/docs/ tree, no _template_notes leak,
latest pointer, impl_status tracking.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from fixtures.project_a import generate_project_a
from validators.path_contract import validate_all_contracts
from validators.registry_validator import validate_impl_statuses, validate_registry_schema
from validators.schema_validator import validate_all_meta_files, validate_no_template_notes
from validators.session_validator import validate_session_dir


@pytest.fixture
def project_a_mc(tmp_path: Path) -> Path:
    """Tao Project A fixture trong tmp_path, tra ve .mc-data/ path."""
    return generate_project_a(tmp_path)


@pytest.mark.scenario_a
class TestProjectAFixture:
    """Kiem tra Project A -- du an moi day du 10 skills."""

    def test_generates_full_tree(self, project_a_mc: Path) -> None:
        """Verify tat ca phase dirs (phase0-phase6) deu ton tai."""
        docs = project_a_mc / "docs"
        expected_phase_dirs = [
            "phase0-brainstorm",
            "phase1-business",
            "phase2-features",
            "phase3-architecture",
            "phase4-ux",
            "phase5-implementation",
            "phase6-deployment",
        ]
        missing = [p for p in expected_phase_dirs if not (docs / p).is_dir()]
        assert missing == [], f"Thieu phase dirs: {missing}"

    def test_meta_files_valid(self, project_a_mc: Path) -> None:
        """Verify tat ca JSON files trong _meta/ pass validation."""
        results = validate_all_meta_files(project_a_mc)
        assert results, "Khong tim thay meta files"
        failures = {
            name: errors
            for name, (is_valid, errors) in results.items()
            if not is_valid
        }
        assert failures == {}, f"Meta files validation failures: {failures}"

    def test_no_template_notes(self, project_a_mc: Path) -> None:
        """Verify req-registry.json khong chua _template_notes (CORE-031)."""
        registry_path = project_a_mc / "docs" / "_meta" / "req-registry.json"
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        violations = validate_no_template_notes(data)
        assert violations == [], f"Tim thay _template_notes tai: {violations}"

    def test_registry_schema_valid(self, project_a_mc: Path) -> None:
        """Verify req-registry.json schema hop le."""
        registry_path = project_a_mc / "docs" / "_meta" / "req-registry.json"
        is_valid, errors = validate_registry_schema(registry_path)
        assert is_valid, f"Registry schema khong hop le: {errors}"

    def test_impl_statuses_valid(self, project_a_mc: Path) -> None:
        """Verify tat ca impl_status nhan gia tri hop le (CORE-010)."""
        registry_path = project_a_mc / "docs" / "_meta" / "req-registry.json"
        is_valid, errors = validate_impl_statuses(registry_path)
        assert is_valid, f"impl_status khong hop le: {errors}"

    def test_path_contracts_pass(self, project_a_mc: Path) -> None:
        """Verify tat ca cross-skill path contracts duoc thoa man."""
        results = validate_all_contracts(project_a_mc)
        failures = [r for r in results if r["status"] == "FAIL"]
        assert failures == [], (
            f"Path contract failures: {[f['message'] for f in failures]}"
        )

    def test_sessions_valid(self, project_a_mc: Path) -> None:
        """Verify moi session duoc tao boi wf-* skills la hop le."""
        work = project_a_mc / "work"
        session_parents = [
            d for d in work.iterdir() if d.is_dir() and (d / "sessions").is_dir()
        ]
        assert session_parents, "Khong tim thay session dirs"

        for parent in session_parents:
            sessions_dir = parent / "sessions"
            for sdir in sessions_dir.iterdir():
                if sdir.is_dir():
                    is_valid, errors = validate_session_dir(sdir)
                    assert is_valid, f"Session {sdir.name} khong hop le: {errors}"

    def test_feature_specs_exist(self, project_a_mc: Path) -> None:
        """Verify phase2-features/ co 18 feature .md files (3 systems x 2 modules x 3 features)."""
        phase2 = project_a_mc / "docs" / "phase2-features"
        md_files = list(phase2.rglob("*.md"))
        md_count = len(md_files)
        assert md_count == 18, (
            f"Cho 18 feature spec files, thay {md_count}. "
            f"Files: {[str(f.relative_to(phase2)) for f in md_files]}"
        )
