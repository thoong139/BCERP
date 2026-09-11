"""test_f_api_only.py — Scenario F: API-only conditional skip wf-design-ux.

Verify: interface_type == "api-only" → ux-input-digest.json NOT canonical,
wf-plan-modules bypasses UX context correctly.

Kiem tra:
    - Registry co interface_type="api-only" → path contracts lien quan UX bi SKIP.
    - Registry co interface_type="web+mobile" → UX contracts KHONG bi SKIP.
    - validate_all_contracts phan loai dung PASS/FAIL/SKIP.
"""
from __future__ import annotations

import json
from pathlib import Path

from validators.path_contract import (
    PATH_CONTRACTS,
    validate_all_contracts,
    validate_contract,
)


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def _make_api_only_project(tmp_path: Path) -> Path:
    """Tao .mc-data structure voi interface_type='api-only'."""
    mc = tmp_path / ".mc-data"
    mc.mkdir()
    meta = mc / "docs" / "_meta"
    meta.mkdir(parents=True)
    (mc / "work").mkdir(parents=True)

    registry: dict = {
        "$schema": "req-registry-v4",
        "project": "API-Only Test",
        "systems": [],
        "modules": [],
        "requirements": [],
        "features": [],
        "interface_type": "api-only",
    }
    (meta / "req-registry.json").write_text(
        json.dumps(registry, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return mc


def _make_web_mobile_project(tmp_path: Path) -> Path:
    """Tao .mc-data structure voi interface_type='web+mobile'."""
    mc = tmp_path / ".mc-data"
    mc.mkdir()
    meta = mc / "docs" / "_meta"
    meta.mkdir(parents=True)
    (mc / "work").mkdir(parents=True)

    registry: dict = {
        "$schema": "req-registry-v4",
        "project": "Web+Mobile Test",
        "systems": [],
        "modules": [],
        "requirements": [],
        "features": [],
        "interface_type": "web+mobile",
    }
    (meta / "req-registry.json").write_text(
        json.dumps(registry, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return mc


def _find_contract_by_output(output_path: str) -> dict | None:
    """Tim contract entry theo output_path."""
    for contract in PATH_CONTRACTS:
        if contract.output_path == output_path:
            return {"contract": contract}
    return None


# ──────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────


class TestApiOnlySkip:
    """Kiem tra api-only conditional skip logic."""

    def test_api_only_registry(self, tmp_path: Path) -> None:
        """Registry interface_type='api-only' luu dung gia tri."""
        mc = _make_api_only_project(tmp_path)
        registry_path = mc / "docs" / "_meta" / "req-registry.json"
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data["interface_type"] == "api-only"

    def test_ux_digest_not_required(self, tmp_path: Path) -> None:
        """interface_type='api-only' → ux-input-digest.json contract SKIP."""
        mc = _make_api_only_project(tmp_path)

        # Tim ux-input-digest contract
        ux_contract = None
        for contract in PATH_CONTRACTS:
            if "ux-input-digest" in contract.output_path:
                ux_contract = contract
                break

        assert ux_contract is not None, "Khong tim thay ux-input-digest contract"
        assert ux_contract.conditional is not None, "UX digest phai co conditional"

        exists, message = validate_contract(mc, ux_contract)
        assert "SKIP" in message

    def test_design_system_not_required(self, tmp_path: Path) -> None:
        """interface_type='api-only' → design-system.md contract SKIP."""
        mc = _make_api_only_project(tmp_path)

        # Tim design-system contract
        ds_contract = None
        for contract in PATH_CONTRACTS:
            if "design-system" in contract.output_path:
                ds_contract = contract
                break

        assert ds_contract is not None, "Khong tim thay design-system contract"
        assert ds_contract.conditional is not None, "Design system phai co conditional"

        exists, message = validate_contract(mc, ds_contract)
        assert "SKIP" in message

    def test_api_only_path_contracts(self, tmp_path: Path) -> None:
        """validate_all_contracts cho api-only: dem SKIP vs PASS vs FAIL."""
        mc = _make_api_only_project(tmp_path)
        results = validate_all_contracts(mc)

        skip_count = sum(1 for r in results if r["status"] == "SKIP")
        pass_count = sum(1 for r in results if r["status"] == "PASS")
        fail_count = sum(1 for r in results if r["status"] == "FAIL")

        # API-only phai co it nhat 2 UX-related SKIP (ux-input-digest + design-system)
        assert skip_count >= 2, (
            f"Expected >= 2 SKIP contracts for api-only, got {skip_count}"
        )

        # Khong co UX contracts nao FAIL (vi chung da SKIP)
        ux_fails = [
            r for r in results
            if r["status"] == "FAIL"
            and ("ux-input-digest" in r["contract"].output_path
                 or "design-system" in r["contract"].output_path)
        ]
        assert ux_fails == [], (
            f"UX contracts should SKIP for api-only, but got FAIL: "
            f"{[r['contract'].output_path for r in ux_fails]}"
        )

    def test_web_plus_mobile_requires_ux(self, tmp_path: Path) -> None:
        """interface_type='web+mobile' → UX contracts KHONG bi SKIP."""
        mc = _make_web_mobile_project(tmp_path)

        # Tim UX-related contracts
        ux_contracts = [
            c for c in PATH_CONTRACTS
            if "ux-input-digest" in c.output_path
            or "design-system" in c.output_path
        ]
        assert len(ux_contracts) >= 2, "Phai co it nhat 2 UX contracts"

        for ux_contract in ux_contracts:
            exists, message = validate_contract(mc, ux_contract)
            # KHONG SKIP — contract bat buoc cho web+mobile
            assert "SKIP" not in message, (
                f"UX contract {ux_contract.output_path} should NOT skip "
                f"for web+mobile, got: {message}"
            )
            # Vi chua tao file → se FAIL (THIEU), nhung khong SKIP
            assert "THIEU" in message or "OK" in message, (
                f"Expected THIEU or OK for web+mobile, got: {message}"
            )
