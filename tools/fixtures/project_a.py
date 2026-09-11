"""project_a.py — Fixture cho Project A (new project).

Spec: 3 systems (CRM, SALES, INVENTORY) x 2 modules x 3 features = 18 features.
Interface: web+mobile.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SYSTEMS: list[dict[str, str]] = [
    {"id": "SYS-CRM", "name": "CRM", "description": "He thong quan ly khach hang", "prefix": "CRM"},
    {"id": "SYS-SALES", "name": "Sales", "description": "He thong quan ly ban hang", "prefix": "SALES"},
    {"id": "SYS-INV", "name": "Inventory", "description": "He thong quan ly kho", "prefix": "INV"},
]

MODULES: list[dict[str, str]] = [
    {"id": "MOD-CRM-CUST", "system": "SYS-CRM", "slug": "customer", "name": "Customer", "description": "Quan ly khach hang"},
    {"id": "MOD-CRM-CONTACT", "system": "SYS-CRM", "slug": "contact", "name": "Contact", "description": "Quan ly lien he"},
    {"id": "MOD-SALES-ORDER", "system": "SYS-SALES", "slug": "order", "name": "Order", "description": "Quan ly don hang"},
    {"id": "MOD-SALES-QUOTE", "system": "SYS-SALES", "slug": "quote", "name": "Quote", "description": "Bao gia"},
    {"id": "MOD-INV-STOCK", "system": "SYS-INV", "slug": "stock", "name": "Stock", "description": "Quan ly ton kho"},
    {"id": "MOD-INV-PRODUCT", "system": "SYS-INV", "slug": "product", "name": "Product", "description": "Quan ly san pham"},
]

FEATURES_PER_MODULE: list[dict[str, str]] = [
    {"suffix": "list", "name": "Danh sach", "description": "Xem danh sach"},
    {"suffix": "create", "name": "Tao moi", "description": "Tao moi ban ghi"},
    {"suffix": "manage", "name": "Quan ly", "description": "Cap nhat va xoa"},
]


def _build_registry() -> dict[str, Any]:
    """Xay dung req-registry.json data cho Project A."""
    requirements: list[dict] = []
    features: list[dict] = []
    req_counter = 0
    feat_counter = 0

    departments = ["sales", "finance", "logistics"]
    dept_map = {"SYS-CRM": "sales", "SYS-SALES": "sales", "SYS-INV": "logistics"}
    impl_cycle = ["not_started", "not_started", "in_progress", "done", "not_started", "done"]

    for mod in MODULES:
        sys_prefix = next(s["prefix"] for s in SYSTEMS if s["id"] == mod["system"])
        dept = dept_map.get(mod["system"], "sales")

        for feat_tmpl in FEATURES_PER_MODULE:
            req_id = f"REQ-{sys_prefix}-{mod['slug'].upper()}-{req_counter + 1:03d}"
            feat_id = f"FEAT-{sys_prefix}-{mod['slug'].upper()}-{feat_counter + 1:03d}"
            impl = impl_cycle[req_counter % len(impl_cycle)]

            requirements.append({
                "id": req_id,
                "department": dept,
                "module_id": mod["id"],
                "title": f"{feat_tmpl['name']} {mod['name']}",
                "description": feat_tmpl["description"],
                "impl_status": impl,
                "priority": "high",
            })

            features.append({
                "id": feat_id,
                "req_id": req_id,
                "module_id": mod["id"],
                "title": f"{feat_tmpl['name']} {mod['name']}",
                "description": feat_tmpl["description"],
                "impl_status": impl,
            })

            req_counter += 1
            feat_counter += 1

    return {
        "$schema": "req-registry-v4",
        "project": "Project A — New Project",
        "last_updated": "2026-04-23",
        "id_format": {},
        "counters": {"REQ": req_counter, "MOD": 6, "FEAT": feat_counter},
        "systems": [
            {"id": s["id"], "name": s["name"], "description": s["description"], "prefix": s["prefix"]}
            for s in SYSTEMS
        ],
        "modules": [
            {"id": m["id"], "system": m["system"], "name": m["name"], "description": m["description"]}
            for m in MODULES
        ],
        "departments": departments,
        "requirements": requirements,
        "features": features,
        "interface_type": "web+mobile",
    }


def _slugify(text: str) -> str:
    return text.lower().replace(" ", "-")


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _write_md(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _make_digest(schema: str, skill: str, summary: str) -> dict[str, Any]:
    return {
        "$schema": schema,
        "skill": skill,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "summary": summary,
    }


def _make_session(session_root: Path, skill_name: str, phase_status: dict[str, str]) -> Path:
    sid = f"2026-04-23-{skill_name.replace('_', '-')}-001"
    sdir = session_root / sid
    sdir.mkdir(parents=True, exist_ok=True)
    state = {
        "$schema": "session-state-v1",
        "session_id": sid,
        "skill_name": skill_name,
        "created_at": "2026-04-23T10:00:00+00:00",
        "updated_at": "2026-04-23T11:00:00+00:00",
        "status": "completed",
        "profile_used": "standard",
        "next_action": "",
        "phases": phase_status,
        "cdg_decisions": [],
        "digests_produced": [],
        "lanes_completed": [],
        "errors": [],
    }
    _write_json(sdir / "session-state.json", state)
    _write_md(
        sdir / "phase-summary.md",
        f"# Phase Summary — {skill_name}\n\nHoan thanh thanh cong.\n",
    )
    return sdir


def generate_project_a(target_dir: Path) -> Path:
    """Tao full .mc-data/ structure cho Project A.

    Returns:
        Duong dan den thu muc .mc-data/ da tao.
    """
    mc = target_dir / ".mc-data"
    mc.mkdir(parents=True, exist_ok=True)

    registry = _build_registry()

    # _meta files
    meta = mc / "docs" / "_meta"
    _write_json(meta / "req-registry.json", registry)
    _write_json(meta / "project-digest.json", _make_digest("project-digest-v1", "wf-brainstorm", "Project A initialized"))
    _write_json(meta / "dept-digests.json", _make_digest("dept-digests-v1", "wf-analyze-requirements", "3 departments analyzed"))
    _write_json(meta / "feature-briefs.json", _make_digest("feature-briefs-v1", "wf-define-features", "18 features defined"))
    _write_json(meta / "design-input-digest.json", _make_digest("design-input-digest-v1", "wf-design", "Architecture designed"))
    _write_json(meta / "phase1-handoff.json", _make_digest("phase1-handoff-v1", "wf-analyze-requirements", "Phase 1 complete"))

    # Phase 0
    _write_md(mc / "docs" / "phase0-brainstorm" / "P0-01-project-charter.md",
              "# Project Charter\n\n## Ten du an\nProject A\n\n## Mo ta\nHe thong quan ly doanh nghiep\n")

    # Phase 1
    _write_md(mc / "docs" / "phase1-business" / "stakeholder-review.md",
              "# Stakeholder Review\n\n## Kết quả\nĐã review xong Phase 1.\n")

    # Phase 2 — feature specs per module
    for mod in MODULES:
        sys_slug = _slugify(next(s["name"] for s in SYSTEMS if s["id"] == mod["system"]))
        mod_slug = mod["slug"]
        for feat_tmpl in FEATURES_PER_MODULE:
            feat_slug = f"{mod_slug}-{feat_tmpl['suffix']}"
            feat_path = mc / "docs" / "phase2-features" / sys_slug / mod_slug / f"{feat_slug}.md"
            _write_md(feat_path,
                      f"# {feat_tmpl['name']} {mod['name']}\n\n"
                      f"## Mo ta\n{feat_tmpl['description']}\n\n"
                      f"## Chuc nang\n- CRUD operations\n- Validation\n\n")

    # Phase 3
    _write_md(mc / "docs" / "phase3-architecture" / "stakeholder-review.md",
              "# Architecture Review\n\n## Kết quả\nArchitecture approved.\n")

    _write_json(meta / "ux-input-digest.json", _make_digest("ux-input-digest-v1", "wf-design-ux", "UX design complete"))

    # Phase 4
    _write_md(mc / "docs" / "phase4-ux" / "design-system.md",
              "# Design System\n\n## Colors\n- Primary: #2563EB\n- Secondary: #7C3AED\n\n## Typography\n- Heading: Inter\n- Body: Inter\n")

    # Phase 5
    p5 = mc / "docs" / "phase5-implementation"
    _write_md(p5 / "module-plan.md", "# Module Plan\n\n## Thu tu\n1. CRM/Customer\n2. CRM/Contact\n3. Sales/Order\n")
    _write_md(p5 / "dependency-graph.md", "# Dependency Graph\n\n```mermaid\ngraph LR\n    A[CRM] --> B[Sales]\n```\n")
    _write_md(p5 / "P5-00-implementation-roadmap.md", "# Roadmap\n\n## Sprint 1-6\n18 features across 6 modules.\n")
    (p5 / "sprints").mkdir(parents=True, exist_ok=True)
    _write_md(p5 / "sprints" / "S01-crm-customer.md", "# Sprint 1: CRM Customer\n")
    _write_md(p5 / "stakeholder-review.md", "# Implementation Review\n\nApproved.\n")

    # Phase 6
    _write_md(mc / "docs" / "phase6-deployment" / "deployment-guide.md", "# Deployment Guide\n")

    # Sessions
    work = mc / "work"
    for skill in ["wf-analyze-requirements", "wf-define-features", "wf-design", "wf-design-ux", "wf-plan-modules"]:
        session_root = work / skill / "sessions"
        _make_session(session_root, skill, {"phase_0": "completed", "phase_1": "completed"})

    # Deferred findings (optional cross-skill files)
    for skill_dir in ["wf-define-features", "wf-design"]:
        _write_md(work / skill_dir / "deferred-findings.md",
                  "# Deferred Findings\n\nKhong co findings bi defer.\n")

    # Preflight + verify-sync stubs
    _write_md(work / "wf-preflight" / "preflight-report.md",
              "# Preflight Report\n\n## Ket qua\nPASS — tat ca checks OK.\n")
    _write_md(mc / "docs" / "_meta" / "verify-sync.md",
              "# Verify Sync Report\n\n## Ket qua\nTat ca REQ-ID da sync.\n")

    return mc
