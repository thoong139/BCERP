"""project_c.py — Fixture cho Project C (feature addition).

Spec: Base = Project A done + add 1 module (SYS-SALES/Promotion) x 3 features.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fixtures.project_a import generate_project_a, _write_json


def _add_promotion_module(registry: dict[str, Any]) -> dict[str, Any]:
    """Them module Promotion vao registry (append-only)."""
    new_mod = {"id": "MOD-SALES-PROMO", "system": "SYS-SALES", "name": "Promotion", "description": "Quan ly khuyen mai"}
    new_reqs = [
        {"id": "REQ-SALES-PROMO-019", "department": "sales", "module_id": "MOD-SALES-PROMO",
         "title": "Create promotion", "description": "Tao khuyen mai moi", "impl_status": "not_started"},
        {"id": "REQ-SALES-PROMO-020", "department": "sales", "module_id": "MOD-SALES-PROMO",
         "title": "Manage discount", "description": "Quan ly giam gia", "impl_status": "not_started"},
        {"id": "REQ-SALES-PROMO-021", "department": "sales", "module_id": "MOD-SALES-PROMO",
         "title": "Track campaign", "description": "Theo doi chien dich", "impl_status": "not_started"},
    ]
    new_feats = [
        {"id": "FEAT-SALES-PROMO-019", "req_id": "REQ-SALES-PROMO-019", "module_id": "MOD-SALES-PROMO",
         "title": "Create promotion", "description": "Form tao khuyen mai", "impl_status": "not_started"},
        {"id": "FEAT-SALES-PROMO-020", "req_id": "REQ-SALES-PROMO-020", "module_id": "MOD-SALES-PROMO",
         "title": "Manage discount", "description": "Giam gia CRUD", "impl_status": "not_started"},
        {"id": "FEAT-SALES-PROMO-021", "req_id": "REQ-SALES-PROMO-021", "module_id": "MOD-SALES-PROMO",
         "title": "Track campaign", "description": "Dashboard chien dich", "impl_status": "not_started"},
    ]

    updated = json.loads(json.dumps(registry))
    updated["modules"].append(new_mod)
    updated["requirements"].extend(new_reqs)
    updated["features"].extend(new_feats)
    updated["counters"]["MOD"] = len(updated["modules"])
    updated["counters"]["REQ"] = len(updated["requirements"])
    updated["counters"]["FEAT"] = len(updated["features"])
    updated["last_updated"] = "2026-04-23"
    return updated


def get_before_registry(target_dir: Path) -> dict[str, Any]:
    """Tra ve registry truoc khi them module."""
    mc = target_dir / ".mc-data"
    path = mc / "docs" / "_meta" / "req-registry.json"
    return json.loads(path.read_text(encoding="utf-8"))


def get_after_registry(target_dir: Path) -> dict[str, Any]:
    """Tra ve registry sau khi them module."""
    before = get_before_registry(target_dir)
    return _add_promotion_module(before)


def generate_project_c(target_dir: Path) -> Path:
    """Tao Project C: base tu Project A + them module Promotion.

    Returns:
        Duong dan den thu muc .mc-data/ da tao.
    """
    # Step 1: Generate base Project A
    mc = generate_project_a(target_dir)

    # Step 2: Append new module + features
    before = get_before_registry(target_dir)
    after = _add_promotion_module(before)

    # Write updated registry
    _write_json(mc / "docs" / "_meta" / "req-registry.json", after)

    # Write new feature spec stubs
    from fixtures.project_a import _write_md
    promo_dir = mc / "docs" / "phase2-features" / "sales" / "promotion"
    for feat in ["create-promotion", "manage-discount", "track-campaign"]:
        _write_md(promo_dir / f"{feat}.md", f"# {feat}\n\n## Mo ta\nFeature {feat} cho Promotion.\n")

    return mc
