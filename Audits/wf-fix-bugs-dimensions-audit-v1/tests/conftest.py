"""conftest.py — Shared fixtures cho audit suite (7 dim QD1-QD7).

Vai trò:
    - Cung cấp path constants tới `fixtures/` root.
    - Helper `load_expected_signals(dim_id)` đọc `qd<N>-test/expected-signals.json`.
    - Parametrize fixture `dim_metadata` cho regression test 7 dim.
    - Tuân thủ CORE-005: docstring tiếng Việt; test code English.

Phạm vi (Stage 0):
    Skeleton-only. Stage 1 Phase 3 (build cases) sẽ implement test bodies thực tế
    trong từng `test_qd<N>_probes.py`. Stage 4 (re-audit) sẽ thêm baseline compare.

Tham chiếu:
    - DoD per fixture: precision ≥0.7, recall ≥0.6 (xem 13-definition-of-done.md §Phase 3).
    - Style: align với `.claude/skills/workflow/_shared/adapters/tests/conftest.py`.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

# ──────────────────────────────────────────────────────────────────────
# Path constants
# ──────────────────────────────────────────────────────────────────────

# tests/ nằm ở plans/wf-fix-bugs-dimensions-audit-v1/tests/.
# Parent là plan root → fixtures/ là sibling của tests/.
PLAN_ROOT = Path(__file__).resolve().parent.parent
FIXTURES_ROOT = PLAN_ROOT / "fixtures"


# ──────────────────────────────────────────────────────────────────────
# Dim metadata — 7 dim QD1..QD7
# ──────────────────────────────────────────────────────────────────────
# Mapping (id → name → lane_skill) khớp `wf-fix-bugs` v7.x dimensions
# (xem CLAUDE.md §Workflow & Skills bảng wf-fix-{...}).

_DIM_TABLE: tuple[dict[str, str], ...] = (
    {"id": "QD1", "name": "Functional Correctness", "lane_skill": "wf-fix-functional"},
    {"id": "QD2", "name": "Business Correctness", "lane_skill": "wf-fix-business"},
    {"id": "QD3", "name": "Security & Privacy", "lane_skill": "wf-fix-security"},
    {"id": "QD4", "name": "Performance & Efficiency", "lane_skill": "wf-fix-performance"},
    {"id": "QD5", "name": "Accessibility & UX", "lane_skill": "wf-fix-ux-a11y"},
    {"id": "QD6", "name": "Data Integrity & Resilience", "lane_skill": "wf-fix-data"},
    {"id": "QD7", "name": "Compatibility", "lane_skill": "wf-fix-compat"},
)


def _dim_record(entry: dict[str, str]) -> dict[str, object]:
    """Mở rộng entry _DIM_TABLE với fixture/expected-signals paths."""
    dim_lower = entry["id"].lower()
    fixture_path = FIXTURES_ROOT / f"{dim_lower}-test"
    return {
        "id": entry["id"],
        "name": entry["name"],
        "lane_skill": entry["lane_skill"],
        "fixture_path": fixture_path,
        "expected_signals_path": fixture_path / "expected-signals.json",
        "run_sh_path": fixture_path / "run.sh",
    }


DIM_METADATA: tuple[dict[str, object], ...] = tuple(_dim_record(e) for e in _DIM_TABLE)


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def load_expected_signals(dim_id: str) -> dict:
    """Đọc `expected-signals.json` của 1 dim (vd ``QD1`` hoặc ``qd1``).

    Trả về dict đã parse JSON (schema ``lane-signals-v1``). Raise ``FileNotFoundError``
    nếu fixture chưa tồn tại; raise ``ValueError`` nếu schema không khớp.
    """
    normalized = dim_id.upper()
    matches = [d for d in DIM_METADATA if d["id"] == normalized]
    if not matches:
        raise ValueError(f"Unknown dim_id: {dim_id!r} (expected QD1..QD7)")

    path: Path = matches[0]["expected_signals_path"]  # type: ignore[assignment]
    if not path.is_file():
        raise FileNotFoundError(f"Missing expected-signals.json: {path}")

    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("$schema") != "lane-signals-v1":
        raise ValueError(
            f"Schema mismatch in {path}: expected 'lane-signals-v1', "
            f"got {payload.get('$schema')!r}"
        )
    if payload.get("dimension_id") != normalized:
        raise ValueError(
            f"dimension_id mismatch in {path}: expected {normalized!r}, "
            f"got {payload.get('dimension_id')!r}"
        )
    return payload


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture(scope="session")
def fixtures_root() -> Path:
    """Đường dẫn tuyệt đối tới `fixtures/` root."""
    return FIXTURES_ROOT


@pytest.fixture(params=DIM_METADATA, ids=[d["id"] for d in DIM_METADATA])
def dim_metadata(request: pytest.FixtureRequest) -> dict[str, object]:
    """Parametrize fixture: yield record của từng dim QD1..QD7.

    Dùng trong test cross-dim (vd verify mọi dim có expected-signals.json hợp lệ).
    """
    return request.param


@pytest.fixture
def expected_signals_loader():
    """Trả về helper ``load_expected_signals`` (closure-friendly cho test)."""
    return load_expected_signals
