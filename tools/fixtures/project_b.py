"""project_b.py — Fixture cho Project B (legacy/existing project).

Spec: 2 systems, 5 modules, React+Node+Postgres, doc trust ~60%.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from fixtures.project_a import _write_json, _write_md, _make_digest, _make_session


def _build_legacy_registry() -> dict[str, Any]:
    """Xay dung req-registry.json cho Project B (legacy)."""
    return {
        "$schema": "req-registry-v4",
        "project": "Project B — Legacy System",
        "last_updated": "2026-04-23",
        "id_format": {},
        "counters": {"REQ": 10, "MOD": 5, "FEAT": 10},
        "systems": [
            {"id": "SYS-AUTH", "name": "Auth", "description": "He thong xac thuc", "prefix": "AUTH"},
            {"id": "SYS-CRM", "name": "CRM", "description": "He thong quan ly khach hang", "prefix": "CRM"},
        ],
        "modules": [
            {"id": "MOD-AUTH-USERS", "system": "SYS-AUTH", "name": "Users", "description": "Quan ly tai khoan"},
            {"id": "MOD-AUTH-ROLES", "system": "SYS-AUTH", "name": "Roles", "description": "Quan ly vai tro"},
            {"id": "MOD-CRM-CUSTOMERS", "system": "SYS-CRM", "name": "Customers", "description": "Quan ly khach hang"},
            {"id": "MOD-CRM-CONTACTS", "system": "SYS-CRM", "name": "Contacts", "description": "Quan ly lien he"},
            {"id": "MOD-CRM-REPORTS", "system": "SYS-CRM", "name": "Reports", "description": "Bao cao"},
        ],
        "departments": ["it", "sales"],
        "requirements": [
            {"id": "REQ-AUTH-001", "department": "it", "module_id": "MOD-AUTH-USERS", "title": "Login", "description": "User login", "impl_status": "done"},
            {"id": "REQ-AUTH-002", "department": "it", "module_id": "MOD-AUTH-USERS", "title": "Register", "description": "User register", "impl_status": "done"},
            {"id": "REQ-AUTH-003", "department": "it", "module_id": "MOD-AUTH-ROLES", "title": "Role management", "description": "CRUD roles", "impl_status": "done"},
            {"id": "REQ-AUTH-004", "department": "it", "module_id": "MOD-AUTH-ROLES", "title": "Permission assign", "description": "Assign permissions", "impl_status": "in_progress"},
            {"id": "REQ-CRM-001", "department": "sales", "module_id": "MOD-CRM-CUSTOMERS", "title": "Customer list", "description": "View customers", "impl_status": "done"},
            {"id": "REQ-CRM-002", "department": "sales", "module_id": "MOD-CRM-CUSTOMERS", "title": "Customer detail", "description": "View detail", "impl_status": "done"},
            {"id": "REQ-CRM-003", "department": "sales", "module_id": "MOD-CRM-CONTACTS", "title": "Contact list", "description": "View contacts", "impl_status": "done"},
            {"id": "REQ-CRM-004", "department": "sales", "module_id": "MOD-CRM-CONTACTS", "title": "Contact create", "description": "Create contact", "impl_status": "not_started"},
            {"id": "REQ-CRM-005", "department": "sales", "module_id": "MOD-CRM-REPORTS", "title": "Sales report", "description": "Bao cao doanh so", "impl_status": "done"},
            {"id": "REQ-CRM-006", "department": "sales", "module_id": "MOD-CRM-REPORTS", "title": "Customer report", "description": "Bao cao khach hang", "impl_status": "not_started"},
        ],
        "features": [
            {"id": "FEAT-AUTH-USERS-001", "req_id": "REQ-AUTH-001", "module_id": "MOD-AUTH-USERS", "title": "Login", "description": "Login form", "impl_status": "done"},
            {"id": "FEAT-AUTH-USERS-002", "req_id": "REQ-AUTH-002", "module_id": "MOD-AUTH-USERS", "title": "Register", "description": "Register form", "impl_status": "done"},
            {"id": "FEAT-AUTH-ROLES-003", "req_id": "REQ-AUTH-003", "module_id": "MOD-AUTH-ROLES", "title": "Role CRUD", "description": "Role management", "impl_status": "done"},
            {"id": "FEAT-AUTH-ROLES-004", "req_id": "REQ-AUTH-004", "module_id": "MOD-AUTH-ROLES", "title": "Permission assign", "description": "Assign perms", "impl_status": "in_progress"},
            {"id": "FEAT-CRM-CUSTOMERS-005", "req_id": "REQ-CRM-001", "module_id": "MOD-CRM-CUSTOMERS", "title": "Customer list", "description": "List view", "impl_status": "done"},
            {"id": "FEAT-CRM-CUSTOMERS-006", "req_id": "REQ-CRM-002", "module_id": "MOD-CRM-CUSTOMERS", "title": "Customer detail", "description": "Detail view", "impl_status": "done"},
            {"id": "FEAT-CRM-CONTACTS-007", "req_id": "REQ-CRM-003", "module_id": "MOD-CRM-CONTACTS", "title": "Contact list", "description": "List view", "impl_status": "done"},
            {"id": "FEAT-CRM-CONTACTS-008", "req_id": "REQ-CRM-004", "module_id": "MOD-CRM-CONTACTS", "title": "Contact create", "description": "Create form", "impl_status": "not_started"},
            {"id": "FEAT-CRM-REPORTS-009", "req_id": "REQ-CRM-005", "module_id": "MOD-CRM-REPORTS", "title": "Sales report", "description": "Report page", "impl_status": "done"},
            {"id": "FEAT-CRM-REPORTS-010", "req_id": "REQ-CRM-006", "module_id": "MOD-CRM-REPORTS", "title": "Customer report", "description": "Report page", "impl_status": "not_started"},
        ],
        "interface_type": "web",
    }


def generate_project_b(target_dir: Path) -> Path:
    """Tao full .mc-data/ structure cho Project B (legacy).

    Returns:
        Duong dan den thu muc .mc-data/ da tao.
    """
    mc = target_dir / ".mc-data"
    mc.mkdir(parents=True, exist_ok=True)

    registry = _build_legacy_registry()

    # _meta files
    meta = mc / "docs" / "_meta"
    _write_json(meta / "req-registry.json", registry)
    _write_json(meta / "project-digest.json", _make_digest("project-digest-v1", "wf-brainstorm", "Project B legacy initialized"))
    _write_json(meta / "dept-digests.json", _make_digest("dept-digests-v1", "wf-analyze-requirements", "2 departments analyzed"))
    _write_json(meta / "feature-briefs.json", _make_digest("feature-briefs-v1", "wf-define-features", "10 features defined"))
    _write_json(meta / "design-input-digest.json", _make_digest("design-input-digest-v1", "wf-design", "Legacy architecture analyzed"))

    # Phase docs (stubs)
    _write_md(mc / "docs" / "phase0-brainstorm" / "P0-01-project-charter.md", "# Project Charter\n\nLegacy system onboarding.\n")
    _write_md(mc / "docs" / "phase1-business" / "stakeholder-review.md", "# Stakeholder Review\n\nPhase 1 legacy complete.\n")
    _write_json(meta / "phase1-handoff.json", _make_digest("phase1-handoff-v1", "wf-analyze-requirements", "Phase 1 legacy handoff"))
    _write_md(mc / "docs" / "phase3-architecture" / "stakeholder-review.md", "# Architecture Review\n\nLegacy architecture approved.\n")

    # Phase 4 (web interface)
    _write_json(meta / "ux-input-digest.json", _make_digest("ux-input-digest-v1", "wf-design-ux", "Legacy UX analysis"))
    _write_md(mc / "docs" / "phase4-ux" / "design-system.md", "# Design System\n\nLegacy design system.\n")

    # Phase 5
    p5 = mc / "docs" / "phase5-implementation"
    _write_md(p5 / "module-plan.md", "# Module Plan\n\nLegacy module plan.\n")
    _write_md(p5 / "dependency-graph.md", "# Dependency Graph\n\n```mermaid\ngraph LR\n    A[Auth] --> B[CRM]\n```\n")
    _write_md(p5 / "P5-00-implementation-roadmap.md", "# Roadmap\n\nLegacy implementation roadmap.\n")
    _write_md(p5 / "stakeholder-review.md", "# Implementation Review\n\nLegacy review.\n")
    (p5 / "sprints").mkdir(parents=True, exist_ok=True)

    # Phase 2 feature stubs
    for mod_slug, feats in [
        ("users", ["login", "register"]),
        ("roles", ["role-management", "permission-assign"]),
        ("customers", ["customer-list", "customer-detail"]),
        ("contacts", ["contact-list", "contact-create"]),
        ("reports", ["sales-report", "customer-report"]),
    ]:
        sys_slug = "auth" if mod_slug in ("users", "roles") else "crm"
        for feat in feats:
            _write_md(
                mc / "docs" / "phase2-features" / sys_slug / mod_slug / f"{feat}.md",
                f"# {feat}\n\n## Mo ta\nFeature {feat} cho {mod_slug}.\n",
            )

    # Legacy-specific files (CORE-021: LEGACY_MODE detection)
    legacy = mc / "work" / "legacy-scan"
    _write_md(
        legacy / "project-context.md",
        "# Project Context — Legacy System Analysis\n\n"
        "## Thong tin du an\n"
        "He thong quan ly doanh nghiep Legacy duoc xay dung tu nam 2020.\n"
        "He thong hien dang hoat dong production voi khoang 500 users.\n\n"
        "## Tech Stack\n"
        "- Frontend: React 18.2 + TypeScript 5.1 + Vite 5\n"
        "- Backend: Node.js 20 LTS + Express 4.18\n"
        "- Database: PostgreSQL 15.4 + Prisma ORM 5.x\n"
        "- Auth: JWT + bcrypt + session-based fallback\n"
        "- Deployment: Docker Compose on Ubuntu 22.04\n"
        "- CI/CD: GitHub Actions\n\n"
        "## Database Schema\n"
        "- 23 tables trong public schema\n"
        "- 5 enums (user_role, order_status, payment_method, contact_type, report_frequency)\n"
        "- Foreign keys cascade between auth and crm schemas\n\n"
        "## Architecture\n"
        "- Monolith architecture, khong tach microservices\n"
        "- REST API voi versioning /api/v1/\n"
        "- File uploads via multer + local storage\n"
        "- No caching layer (Redis chua duoc tich hop)\n\n"
        "## Modules\n"
        "- auth/users — quan ly tai khoan, login, register, profile\n"
        "- auth/roles — RBAC roles va permissions\n"
        "- crm/customers — customer CRUD, search, import/export\n"
        "- crm/contacts — contact management voi address book\n"
        "- crm/reports — bao cao doanh so, bao cao khach hang\n\n"
        "## Code Size\n"
        "- Total LOC: ~15,000\n"
        "- Source files: 120\n"
        "- Test files: 35\n"
        "- Config files: 12\n\n"
        "## Known Issues\n"
        "- Khong co rate limiting tren API endpoints\n"
        "- Khong co audit logging\n"
        "- Hardcoded configuration trong mot so files\n",
    )
    _write_json(legacy / "project-profile.json", {
        "$schema": "project-profile-v1",
        "tech_stack": {"frontend": "React 18", "backend": "Node.js 20", "database": "PostgreSQL 15"},
        "total_files": 120,
        "total_loc": 15000,
        "module_count": 5,
    })
    _write_json(legacy / "ledger.json", {
        "$schema": "scan-ledger-v1",
        "stages_completed": ["stage-0", "stage-1", "stage-2", "stage-3", "stage-4"],
        "status": "complete",
    })
    _write_json(legacy / "inventory" / "dependency-graph.json", {
        "$schema": "dependency-graph-v1",
        "nodes": [
            {"id": "auth/users", "type": "module", "files": 25},
            {"id": "auth/roles", "type": "module", "files": 15},
            {"id": "crm/customers", "type": "module", "files": 30},
            {"id": "crm/contacts", "type": "module", "files": 20},
            {"id": "crm/reports", "type": "module", "files": 30},
        ],
        "edges": [
            {"from": "crm/customers", "to": "auth/users", "type": "imports"},
            {"from": "crm/contacts", "to": "auth/users", "type": "imports"},
        ],
    })

    # Module-code mapping
    _write_json(legacy / "module-code-mapping.json", {
        "$schema": "module-code-mapping-v1",
        "mappings": [
            {"module_id": "MOD-AUTH-USERS", "code_paths": ["src/modules/auth/users/"]},
            {"module_id": "MOD-AUTH-ROLES", "code_paths": ["src/modules/auth/roles/"]},
            {"module_id": "MOD-CRM-CUSTOMERS", "code_paths": ["src/modules/crm/customers/"]},
            {"module_id": "MOD-CRM-CONTACTS", "code_paths": ["src/modules/crm/contacts/"]},
            {"module_id": "MOD-CRM-REPORTS", "code_paths": ["src/modules/crm/reports/"]},
        ],
    })

    # Doc quality map
    _write_json(legacy / "doc-quality-map.json", {
        "$schema": "doc-quality-v1",
        "scores": {
            "auth/users": 0.7,
            "auth/roles": 0.5,
            "crm/customers": 0.8,
            "crm/contacts": 0.4,
            "crm/reports": 0.6,
        },
        "average_trust": 0.6,
    })

    # Legacy decisions (CORE-022: wf-brainstorm Phase 0.5)
    _write_json(mc / "work" / "wf-brainstorm" / "legacy-decisions.json", {
        "$schema": "legacy-decisions-v1",
        "decisions": [
            {"module_id": "MOD-CRM-REPORTS", "action": "KEEP", "reason": "Van can bao cao doanh so"},
            {"module_id": "MOD-AUTH-ROLES", "action": "DEPRECATE", "reason": "Se thay bang RBAC moi"},
        ],
        "deprecated_modules": ["MOD-AUTH-ROLES"],
        "divergence_resolutions": [],
    })

    # Source code stubs (simulate legacy codebase)
    src = target_dir / "src"
    _write_md(src / "modules" / "auth" / "users" / "users.controller.ts",
              "// REQ-ID: REQ-AUTH-001\nexport class UsersController { /* login */ }\n")
    _write_md(src / "modules" / "auth" / "users" / "users.service.ts",
              "// REQ-ID: REQ-AUTH-002\nexport class UsersService { /* register */ }\n")
    _write_md(src / "modules" / "crm" / "customers" / "customers.controller.ts",
              "// REQ-ID: REQ-CRM-001\nexport class CustomersController { /* list */ }\n")

    # Sessions + deferred findings + preflight + verify-sync
    work = mc / "work"
    for skill in ["wf-legacy-scan", "wf-brainstorm", "wf-analyze-requirements"]:
        session_root = work / skill / "sessions"
        _make_session(session_root, skill, {"phase_0": "completed"})

    for skill_dir in ["wf-define-features", "wf-design"]:
        _write_md(work / skill_dir / "deferred-findings.md", "# Deferred Findings\n\nKhong co findings bi defer.\n")

    _write_md(work / "wf-preflight" / "preflight-report.md", "# Preflight Report\n\nPASS.\n")
    _write_md(mc / "docs" / "_meta" / "verify-sync.md", "# Verify Sync\n\nTat ca REQ-ID da sync.\n")

    return mc
