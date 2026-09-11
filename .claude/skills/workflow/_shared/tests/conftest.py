"""conftest.py — Shared fixtures + sys.path setup cho B2 test suite.

Vai trò:
    - Thêm _shared/ vào sys.path để import modules theo tên package.
    - Cung cấp fixtures dùng chung (tmp session dir, sample signals, registry stub).
    - Tuân thủ CORE-005: docstring tiếng Việt; test code English.

Phạm vi:
    Chỉ phục vụ B2 test suite (8 test files). Không import production code ở top-level
    để tránh side-effect khi pytest collect.
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

# tests/ nằm ở _shared/tests/. Parent là _shared/. Thêm vào sys.path để
# import được `from scan_cache.fingerprint import ...`, etc.
_SHARED_ROOT = Path(__file__).resolve().parent.parent
if str(_SHARED_ROOT) not in sys.path:
    sys.path.insert(0, str(_SHARED_ROOT))


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def sample_signal_dict() -> dict[str, Any]:
    """Trả về Signal v2 hợp lệ dưới dạng dict — dùng cho set_entry, signal_bus tests."""
    return {
        "$schema": "signal-v2",
        "probe_id": "P-QD1-sample-probe",
        "probe_version": "0.1.0",
        "emitted_at": "2026-04-20T10:00:00+00:00",
        "lane": "wf-fix-functional",
        "dimension_id": "QD1",
        "target": {
            "kind": "code",
            "file_path": "src/example/module.ts",
            "line_range": [10, 25],
            "symbol": "exampleFunction",
        },
        "description": "Mô tả lỗi tiếng Việt có dấu — đạt ngưỡng 10 ký tự.",
        "evidence": {
            "code_snippet": "// Trích đoạn code mẫu >= 10 ký tự.",
            "screenshot_path": None,
            "log_excerpt": None,
            "stacktrace": None,
            "spec_ref": None,
            "test_failure_ref": None,
        },
        "suggested_severity": "medium",
        "dedup_hints": [],
    }


@pytest.fixture
def qd3_signal_dict() -> dict[str, Any]:
    """Signal QD3 — dùng để test ADR-22 rule 6 enforcement (không được cache)."""
    return {
        "$schema": "signal-v2",
        "probe_id": "P-QD3-security-probe",
        "probe_version": "0.1.0",
        "emitted_at": "2026-04-20T10:00:00+00:00",
        "lane": "wf-fix-security",
        "dimension_id": "QD3",
        "target": {
            "kind": "code",
            "file_path": "src/auth/login.ts",
            "line_range": [5, 15],
            "symbol": "authenticate",
        },
        "description": "Phát hiện vấn đề bảo mật trong auth flow.",
        "evidence": {
            "code_snippet": "// const key = process.env.SECRET;",
            "screenshot_path": None,
            "log_excerpt": None,
            "stacktrace": None,
            "spec_ref": None,
            "test_failure_ref": None,
        },
        "suggested_severity": "high",
        "dedup_hints": [],
    }


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    """Tạo session dir tạm thời, trả về Path."""
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


@pytest.fixture
def tmp_cache_root(tmp_path: Path) -> Path:
    """Tạo cache root tạm thời cho scan_cache tests."""
    cache = tmp_path / "cache" / "probes"
    cache.mkdir(parents=True, exist_ok=True)
    return cache


@pytest.fixture
def tmp_registry(tmp_path: Path) -> Path:
    """Tạo req-registry.json tối thiểu tại tmp_path/.mc-data/docs/_meta/."""
    registry_dir = tmp_path / ".mc-data" / "docs" / "_meta"
    registry_dir.mkdir(parents=True, exist_ok=True)
    registry_path = registry_dir / "req-registry.json"
    registry_data = {
        "project": {"name": "test-project"},
        "systems": [],
        "modules": [],
        "departments": ["finance", "logistics"],
        "requirements": [],
        "features": [],
        "interface_type": "web",
    }
    registry_path.write_text(
        json.dumps(registry_data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return registry_path
