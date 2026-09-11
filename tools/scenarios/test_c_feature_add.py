"""test_c_feature_add.py -- Scenario C: Feature addition (5 skills).

Verify: Registry append-only, existing features unchanged.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from fixtures.project_c import generate_project_c
from validators.registry_validator import check_no_downgrade, validate_append_only


@pytest.fixture
def project_c_mc(tmp_path: Path) -> Path:
    """Tao Project C fixture trong tmp_path, tra ve .mc-data/ path."""
    return generate_project_c(tmp_path)


@pytest.fixture
def before_registry_file(tmp_path: Path) -> Path:
    """Ghi before registry ra tam de validator doc.

    Build truoc-state tu project A base (truoc khi them promotion module).
    """
    # Build before-state registry: project A base (truoc khi them promotion module)
    from fixtures.project_a import _build_registry
    before_data = _build_registry()
    before_path = tmp_path / "_before_registry.json"
    before_path.write_text(
        json.dumps(before_data, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return before_path


@pytest.fixture
def after_registry_file(project_c_mc: Path) -> Path:
    """Duong dan den registry hien tai (sau khi them promotion module)."""
    return project_c_mc / "docs" / "_meta" / "req-registry.json"


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


@pytest.mark.scenario_c
class TestProjectCFixture:
    """Kiem tra Project C -- feature addition: base A + module Promotion."""

    def test_generates_from_base_a(self, project_c_mc: Path) -> None:
        """Verify base Project A structure van ton tai sau khi generate C."""
        docs = project_c_mc / "docs"
        # Phase dirs tu Project A
        assert (docs / "phase0-brainstorm").is_dir(), "phase0-brainstorm missing"
        assert (docs / "phase1-business").is_dir(), "phase1-business missing"
        assert (docs / "phase2-features").is_dir(), "phase2-features missing"
        assert (docs / "phase3-architecture").is_dir(), "phase3-architecture missing"
        assert (docs / "phase4-ux").is_dir(), "phase4-ux missing"
        assert (docs / "phase5-implementation").is_dir(), "phase5-implementation missing"
        assert (docs / "phase6-deployment").is_dir(), "phase6-deployment missing"

    def test_new_module_in_registry(self, after_registry_file: Path) -> None:
        """Verify MOD-SALES-PROMO ton tai trong registry modules."""
        data = _load_json(after_registry_file)
        module_ids = [m["id"] for m in data.get("modules", [])]
        assert "MOD-SALES-PROMO" in module_ids, (
            f"MOD-SALES-PROMO khong ton tai. Modules: {module_ids}"
        )

    def test_new_features_in_registry(self, after_registry_file: Path) -> None:
        """Verify 3 features moi (FEAT-SALES-PROMO-*) ton tai trong registry."""
        data = _load_json(after_registry_file)
        feature_ids = [f["id"] for f in data.get("features", [])]
        expected = ["FEAT-SALES-PROMO-019", "FEAT-SALES-PROMO-020", "FEAT-SALES-PROMO-021"]
        for feat_id in expected:
            assert feat_id in feature_ids, (
                f"{feat_id} khong ton tai. Features: {feature_ids}"
            )

    def test_append_only_modules(
        self,
        before_registry_file: Path,
        after_registry_file: Path,
    ) -> None:
        """Verify tat ca modules goc van ton tai (append-only, CORE-006)."""
        is_clean, violations = validate_append_only(
            before_registry_file, after_registry_file, section="modules",
        )
        assert is_clean, f"Append-only violations (modules): {violations}"

    def test_append_only_features(
        self,
        before_registry_file: Path,
        after_registry_file: Path,
    ) -> None:
        """Verify tat ca features goc van ton tai (append-only, CORE-006)."""
        is_clean, violations = validate_append_only(
            before_registry_file, after_registry_file, section="features",
        )
        assert is_clean, f"Append-only violations (features): {violations}"

    def test_no_downgrade(
        self,
        before_registry_file: Path,
        after_registry_file: Path,
    ) -> None:
        """Verify khong co downgrade impl_status tu done (CORE-008)."""
        is_clean, violations = check_no_downgrade(
            before_registry_file, after_registry_file,
        )
        assert is_clean, f"Downgrade violations: {violations}"

    def test_new_feature_specs_exist(self, project_c_mc: Path) -> None:
        """Verify 3 feature spec .md files moi ton tai trong phase2-features/sales/promotion/."""
        promo_dir = project_c_mc / "docs" / "phase2-features" / "sales" / "promotion"
        expected_files = ["create-promotion.md", "manage-discount.md", "track-campaign.md"]
        for fname in expected_files:
            fpath = promo_dir / fname
            assert fpath.exists(), f"Feature spec khong ton tai: {fpath}"
