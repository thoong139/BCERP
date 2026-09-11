"""conftest.py — Shared fixtures cho Phase 5 integration tests.

Vai tro:
    - sys.path setup de import _shared modules.
    - Cung cap fixtures dung chung (project dirs, session dirs, registries).
    - CORE-005: docstring tieng Viet; test code English.

Pham vi:
    Phuc vu 8 scenario tests. Import production code tu _shared/.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import pytest

# ──────────────────────────────────────────────────────────────────────
# sys.path setup
# ──────────────────────────────────────────────────────────────────────

# tools/ -> MCV3 root
_MCV3_ROOT = Path(__file__).resolve().parent.parent
# _shared/ for importing lane_dispatch, signal_aggregator, etc.
_SHARED_ROOT = _MCV3_ROOT / ".claude" / "skills" / "workflow" / "_shared"

for p in [str(_MCV3_ROOT), str(_SHARED_ROOT)]:
    if p not in sys.path:
        sys.path.insert(0, p)

# tools/ itself for importing validators/ and fixtures/
_TOOLS_ROOT = Path(__file__).resolve().parent
if str(_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOLS_ROOT))


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def mcv3_root() -> Path:
    """MCV3 project root directory."""
    return _MCV3_ROOT


@pytest.fixture
def shared_root() -> Path:
    """Path to .claude/skills/workflow/_shared/."""
    return _SHARED_ROOT


@pytest.fixture
def tools_root() -> Path:
    """Path to tools/ directory."""
    return _TOOLS_ROOT


@pytest.fixture
def tmp_mc_data(tmp_path: Path) -> Path:
    """Tao .mc-data/ structure trong tmp_path."""
    mc = tmp_path / ".mc-data"
    mc.mkdir()
    (mc / "docs" / "_meta").mkdir(parents=True)
    (mc / "work").mkdir(parents=True)
    (mc / "sync").mkdir(parents=True)
    return mc


@pytest.fixture
def sample_registry_data() -> dict[str, Any]:
    """Minimal req-registry.json v4 data cho tests."""
    return {
        "$schema": "req-registry-v4",
        "project": "Test Project",
        "last_updated": "2026-04-23",
        "id_format": {},
        "counters": {"REQ": 0, "MOD": 0, "FEAT": 0},
        "systems": [
            {"id": "SYS-CRM", "name": "CRM", "description": "CRM System", "prefix": "CRM"},
            {"id": "SYS-SALES", "name": "Sales", "description": "Sales System", "prefix": "SALES"},
            {"id": "SYS-INV", "name": "Inventory", "description": "Inventory System", "prefix": "INV"},
        ],
        "modules": [
            {"id": "MOD-CRM-CUST", "system": "SYS-CRM", "name": "Customer", "description": "Quan ly khach hang"},
            {"id": "MOD-CRM-CONTACT", "system": "SYS-CRM", "name": "Contact", "description": "Quan ly lien he"},
            {"id": "MOD-SALES-ORDER", "system": "SYS-SALES", "name": "Order", "description": "Quan ly don hang"},
            {"id": "MOD-SALES-QUOTE", "system": "SYS-SALES", "name": "Quote", "description": "Bao gia"},
            {"id": "MOD-INV-STOCK", "system": "SYS-INV", "name": "Stock", "description": "Quan ly kho"},
            {"id": "MOD-INV-PRODUCT", "system": "SYS-INV", "name": "Product", "description": "Quan ly san pham"},
        ],
        "departments": ["sales", "finance", "logistics"],
        "requirements": [],
        "features": [],
        "interface_type": "web+mobile",
    }


@pytest.fixture
def tmp_registry(tmp_mc_data: Path, sample_registry_data: dict[str, Any]) -> Path:
    """Tao req-registry.json tai .mc-data/docs/_meta/."""
    path = tmp_mc_data / "docs" / "_meta" / "req-registry.json"
    path.write_text(json.dumps(sample_registry_data, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    """Tao session dir voi session-state.json."""
    session = tmp_path / "sessions" / "2026-04-23-test-session"
    session.mkdir(parents=True)
    state = {
        "$schema": "session-state-v1",
        "session_id": "2026-04-23-test-session",
        "skill_name": "wf-test",
        "created_at": "2026-04-23T10:00:00+00:00",
        "updated_at": "2026-04-23T10:30:00+00:00",
        "status": "in_progress",
        "profile_used": "standard",
        "next_action": "phase_3",
        "phases": {"phase_0": "completed", "phase_1": "completed", "phase_2": "in_progress"},
        "cdg_decisions": [],
        "digests_produced": [],
        "lanes_completed": [],
        "errors": [],
    }
    (session / "session-state.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return session


@pytest.fixture
def tmp_multi_sessions(tmp_path: Path) -> Path:
    """Tao 7 sessions trong sessions/ dir cho cleanup tests."""
    sessions_root = tmp_path / "sessions"
    sessions_root.mkdir(parents=True)

    for i in range(7):
        sid = f"2026-04-{23 - i:02d}-session-{i}"
        sdir = sessions_root / sid
        sdir.mkdir()
        state = {
            "$schema": "session-state-v1",
            "session_id": sid,
            "skill_name": "wf-test",
            "created_at": f"2026-04-{23 - i:02d}T10:00:00+00:00",
            "updated_at": f"2026-04-{23 - i:02d}T10:30:00+00:00",
            "status": "completed",
            "profile_used": "standard",
            "next_action": "",
            "phases": {},
            "cdg_decisions": [],
            "digests_produced": [],
            "lanes_completed": [],
            "errors": [],
        }
        (sdir / "session-state.json").write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    return sessions_root
