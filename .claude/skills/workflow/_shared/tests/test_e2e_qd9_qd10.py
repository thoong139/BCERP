"""test_e2e_qd9_qd10.py — Regression tests v9.0.2 cho profile + schemas QD9/QD10.

Lock-in tests cho các lỗ hổng v9.0.1 đã sót:
    - F1: profiles.json:exhaustive phải dispatch đủ 10 dimensions [S1]
    - F2: dim-selection.schema.json:enum phải accept QD9/QD10 [S1]
    - F3: fix-workload.schema.json:enum phải accept QD9/QD10 [S1]
    - F4: ISG recommender DIMENSIONS + deep profile mở rộng QD9/QD10 [S2]

Mục tiêu: nếu ai drift về QD1-QD8 trong profile/schema/recommender, test này fail ngay.
File này sẽ mở rộng thêm trong S4 (full regression suite cho probe manifest + cache policy).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[5]
SHARED_ROOT = REPO_ROOT / ".claude" / "skills" / "workflow" / "_shared"
WORKFLOW_ROOT = REPO_ROOT / ".claude" / "skills" / "workflow"
PROFILES_JSON = SHARED_ROOT / "profiles.json"
DIM_SELECTION_SCHEMA = SHARED_ROOT / "isg" / "schemas" / "dim-selection.schema.json"
WORKLOAD_SCHEMA = SHARED_ROOT / "workload_estimator" / "schemas" / "fix-workload.schema.json"


def test_exhaustive_includes_qd9_qd10() -> None:
    """F1: profiles.json exhaustive profile phải có đủ 11 dimensions QD1-QD11."""
    profiles = json.loads(PROFILES_JSON.read_text(encoding="utf-8"))
    dims = profiles["profiles"]["exhaustive"]["dimensions"]
    assert len(dims) == 11, f"exhaustive phải có 11 dimensions, hiện có {len(dims)}"
    assert "QD9" in dims, "exhaustive thiếu QD9 (Runtime Health)"
    assert "QD10" in dims, "exhaustive thiếu QD10 (Cross-Module Integration)"
    assert "QD11" in dims, "exhaustive thiếu QD11 (Business Completeness)"
    assert set(dims) == {f"QD{i}" for i in range(1, 12)}


def test_dim_selection_schema_accepts_qd9() -> None:
    """F2: dim-selection.schema.json — 3 enum (recommendations.dim, selected, skipped) phải accept QD9/QD10."""
    schema = json.loads(DIM_SELECTION_SCHEMA.read_text(encoding="utf-8"))
    rec_enum = schema["properties"]["recommendations"]["items"]["properties"]["dim"]["enum"]
    selected_enum = schema["properties"]["selected"]["items"]["enum"]
    skipped_enum = schema["properties"]["skipped"]["items"]["enum"]
    for enum in (rec_enum, selected_enum, skipped_enum):
        assert "QD9" in enum, f"enum thiếu QD9: {enum}"
        assert "QD10" in enum, f"enum thiếu QD10: {enum}"


def test_workload_schema_accepts_qd10() -> None:
    """F3: fix-workload.schema.json — 2 enum (selected_dims, lanes.dim) phải accept QD9/QD10."""
    schema = json.loads(WORKLOAD_SCHEMA.read_text(encoding="utf-8"))
    selected_enum = schema["properties"]["selected_dims"]["items"]["enum"]
    lanes_enum = schema["properties"]["lanes"]["items"]["properties"]["dim"]["enum"]
    for enum in (selected_enum, lanes_enum):
        assert "QD9" in enum, f"enum thiếu QD9: {enum}"
        assert "QD10" in enum, f"enum thiếu QD10: {enum}"


# ──────────────────────────────────────────────────────────────────────
# Sprint 2 — F4: ISG recommender DIMENSIONS + deep profile
# ──────────────────────────────────────────────────────────────────────


def test_isg_recommender_dimensions_includes_qd9_qd10() -> None:
    """F4: isg_recommender.DIMENSIONS phải mở rộng từ QD1-QD8 → QD1-QD11 (v9.1.0)."""
    from isg.isg_recommender import DIMENSIONS

    assert "QD9" in DIMENSIONS, f"DIMENSIONS thiếu QD9: {DIMENSIONS}"
    assert "QD10" in DIMENSIONS, f"DIMENSIONS thiếu QD10: {DIMENSIONS}"
    assert "QD11" in DIMENSIONS, f"DIMENSIONS thiếu QD11: {DIMENSIONS}"
    assert len(DIMENSIONS) == 11, f"DIMENSIONS phải có 11 phần tử, hiện có {len(DIMENSIONS)}"


def test_isg_deep_profile_includes_qd9() -> None:
    """F4: deep profile phải include QD9 (Runtime Health) — phù hợp coverage deep."""
    from isg.isg_recommender import DEFAULT_PROFILE_DIMS

    deep_dims = DEFAULT_PROFILE_DIMS["deep"]
    assert "QD9" in deep_dims, f"deep profile thiếu QD9: {deep_dims}"


def test_isg_deep_profile_includes_qd10_qd11() -> None:
    """F4: deep profile phải include QD10, QD11 — đồng bộ với profiles.json SSOT (v9.1.0)."""
    from isg.isg_recommender import DEFAULT_PROFILE_DIMS

    deep_dims = DEFAULT_PROFILE_DIMS["deep"]
    assert "QD10" in deep_dims, f"deep profile thiếu QD10 (Cross-Module Integration): {deep_dims}"
    assert "QD11" in deep_dims, f"deep profile thiếu QD11 (Business Completeness): {deep_dims}"


def test_isg_standard_profile_includes_qd9_qd10() -> None:
    """F4: standard profile phải include QD9, QD10 — đồng bộ với profiles.json SSOT (v9.1.0)."""
    from isg.isg_recommender import DEFAULT_PROFILE_DIMS

    standard_dims = DEFAULT_PROFILE_DIMS["standard"]
    assert "QD9" in standard_dims, f"standard profile thiếu QD9: {standard_dims}"
    assert "QD10" in standard_dims, f"standard profile thiếu QD10: {standard_dims}"


# ──────────────────────────────────────────────────────────────────────
# Sprint 4 — F11: Full regression suite cho QD9/QD10
# ──────────────────────────────────────────────────────────────────────


def _load_dim(lane_name: str) -> dict | None:
    """Load dimension.json từ lane directory. Trả về None nếu không tìm thấy."""
    dp = WORKFLOW_ROOT / lane_name / "dimension.json"
    if not dp.exists():
        return None
    return json.loads(dp.read_text(encoding="utf-8"))


class TestDimensionManifestQD9QD10:
    """T4.1 — Probe manifest integrity cho QD9/QD10 (dimension.json + probe files)."""

    LANE_MAP = {"QD9": "wf-fix-runtime-health", "QD10": "wf-fix-integration"}

    @pytest.mark.parametrize("dim", ["QD9", "QD10"])
    def test_dimension_json_exists(self, dim: str) -> None:
        lane = self.LANE_MAP[dim]
        dp = WORKFLOW_ROOT / lane / "dimension.json"
        assert dp.exists(), f"dimension.json not found: {dp}"

    @pytest.mark.parametrize("dim", ["QD9", "QD10"])
    def test_probe_ids(self, dim: str) -> None:
        lane = self.LANE_MAP[dim]
        d = _load_dim(lane)
        if d is None:
            pytest.skip("dimension.json not found")
        for p in d.get("probes", []):
            assert re.match(rf"^P-{dim}-[a-z0-9-]+$", p["id"]), f"Bad probe ID: {p['id']}"

    @pytest.mark.parametrize("dim", ["QD9", "QD10"])
    def test_probe_files(self, dim: str) -> None:
        lane = self.LANE_MAP[dim]
        d = _load_dim(lane)
        if d is None:
            pytest.skip("dimension.json not found")
        for p in d.get("probes", []):
            if p.get("type") == "llm":
                continue  # LLM probes use prompts/, not procedures/probes/
            pf = WORKFLOW_ROOT / lane / "procedures" / "probes" / f"{p['id']}.md"
            assert pf.exists(), f"Missing probe file: {pf}"


class TestQD9RuntimeHealth:
    """T4.2 — QD9 cache policy, lane path, agents (dimension_registry)."""

    def test_qd9_cache_disabled(self) -> None:
        from dimension_registry import get_cache_policy

        assert get_cache_policy("QD9") is False  # Runtime probes always re-run

    def test_qd9_lane_path_resolves(self) -> None:
        from dimension_registry import get_lane_path

        path = get_lane_path("QD9", WORKFLOW_ROOT)
        assert path.name == "wf-fix-runtime-health"

    def test_qd9_agents_present(self) -> None:
        from dimension_registry import get_agents

        assert get_agents("QD9") == ["qa-lead", "frontend-developer"]


class TestQD10Integration:
    """T4.3 — QD10 cache policy, lane path, agents (dimension_registry)."""

    def test_qd10_cache_allowed(self) -> None:
        from dimension_registry import get_cache_policy

        assert get_cache_policy("QD10") is True

    def test_qd10_lane_path_resolves(self) -> None:
        from dimension_registry import get_lane_path

        path = get_lane_path("QD10", WORKFLOW_ROOT)
        assert path.name == "wf-fix-integration"

    def test_qd10_agents_present(self) -> None:
        from dimension_registry import get_agents

        assert get_agents("QD10") == ["architect", "data-engineer"]


class TestExhaustiveProfileFull:
    """T4.4 — Exhaustive profile dispatch 11 dimensions via profile_resolver."""

    def test_exhaustive_dispatches_11_dims(self) -> None:
        from profile_resolver import resolve_dimensions

        dims = resolve_dimensions(PROFILES_JSON, "exhaustive")
        assert len(dims) == 11, f"exhaustive phải dispatch 11 dims, got {len(dims)}: {dims}"
        assert set(dims) == {f"QD{i}" for i in range(1, 12)}

    def test_exhaustive_includes_qd9_qd10(self) -> None:
        """Overlap với S1 standalone test — giữ cả 2 cho clarity (PLAN.md T4.4 note)."""
        from profile_resolver import resolve_dimensions

        dims = resolve_dimensions(PROFILES_JSON, "exhaustive")
        assert "QD9" in dims, "exhaustive thiếu QD9 (Runtime Health)"
        assert "QD10" in dims, "exhaustive thiếu QD10 (Cross-Module Integration)"
        assert "QD11" in dims, "exhaustive thiếu QD11 (Business Completeness)"
