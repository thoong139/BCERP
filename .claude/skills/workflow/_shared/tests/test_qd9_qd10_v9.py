"""test_qd9_qd10_v9.py — Regression tests v9.0.1 cho QD9 + QD10.

Lock-in tests cho 5 mảnh hạ tầng đã sửa khi vá lỗ hổng "fantasy completion" của v9.0:
    1. Signal Bus VALID_DIMENSIONS chứa QD9/QD10
    2. Signal Bus PROBE_ID_PATTERN match P-QD9-* và P-QD10-*
    3. JSON schemas (signal.v2, issue.v2) enum bao gồm QD9/QD10
    4. dimension.json tồn tại + valid cho cả 2 lane
    5. lane_dispatch dispatch end-to-end thành công cho QD9/QD10

Mục tiêu: nếu ai đó remove 1 trong 5 mảnh, test này fail ngay → tránh "drift" trở lại.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[5]
WORKFLOW_ROOT = REPO_ROOT / ".claude" / "skills" / "workflow"
SCHEMAS_DIR = WORKFLOW_ROOT / "_shared" / "signal_bus" / "schemas"

# Make sibling _shared importable
sys.path.insert(0, str(WORKFLOW_ROOT / "_shared"))

from dimension_registry import (  # noqa: E402
    DIMENSION_REGISTRY,
    get_cache_policy,
    get_lane_path,
    validate_lane_exists,
)
from lane_dispatch import _execute_lane_sequential  # noqa: E402
from signal_bus.signal_bus import (  # noqa: E402
    PROBE_ID_PATTERN,
    VALID_DIMENSIONS,
    Signal,
)


# ──────────────────────────────────────────────────────────────────────
# 1. Signal Bus constants — VALID_DIMENSIONS + probe pattern
# ──────────────────────────────────────────────────────────────────────


class TestSignalBusV9Constants:
    """Signal Bus phải accept QD9/QD10 (CORE drift gate)."""

    def test_qd9_in_valid_dimensions(self) -> None:
        assert "QD9" in VALID_DIMENSIONS

    def test_qd10_in_valid_dimensions(self) -> None:
        assert "QD10" in VALID_DIMENSIONS

    def test_qd11_in_valid_dimensions(self) -> None:
        assert "QD11" in VALID_DIMENSIONS

    @pytest.mark.parametrize(
        "probe_id",
        [
            "P-QD9-dev-server-bootstrap",
            "P-QD9-console-network-monitor",
            "P-QD10-cross-module-ref-static",
            "P-QD10-business-flow-runtime",
            "P-QD10-auth-matrix-check",
            "P-QD11-cross-module-comparison",
            "P-QD11-domain-heuristic",
            "P-QD11-registry-gap",
        ],
    )
    def test_probe_id_pattern_matches_v9_probes(self, probe_id: str) -> None:
        assert PROBE_ID_PATTERN.match(probe_id) is not None

    @pytest.mark.parametrize("probe_id", ["P-QD12-foo", "P-QD0-bar", "P-QDx-baz"])
    def test_probe_id_pattern_rejects_invalid(self, probe_id: str) -> None:
        assert PROBE_ID_PATTERN.match(probe_id) is None


# ──────────────────────────────────────────────────────────────────────
# 2. Signal.from_dict — chấp nhận QD9/QD10 signal hợp lệ
# ──────────────────────────────────────────────────────────────────────


def _signal_payload(dim: str, probe_id: str, lane: str, signal_type: str) -> dict:
    return {
        "signal_id": "sig-test",
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": "2026-05-10T00:00:00Z",
        "lane": lane,
        "target": {"kind": "runtime", "file_path": "/tmp/test"},
        "dimension_id": dim,
        "signal_type": signal_type,
        "severity": "HIGH",
        "title": "test signal title",
        "description": "test description here",
        "evidence": {
            "code_snippet": "// snippet >= 10 chars",
            "log_excerpt": "console error log line >= 20 chars long",
        },
    }


class TestSignalFromDictV9:
    """Signal.from_dict accept QD9/QD10 — không còn ValueError."""

    def test_accepts_qd9_signal(self) -> None:
        payload = _signal_payload(
            "QD9",
            "P-QD9-console-network-monitor",
            "wf-fix-runtime-health",
            "runtime_console_error",
        )
        signal = Signal.from_dict(payload)
        assert signal.dimension_id == "QD9"
        assert signal.lane == "wf-fix-runtime-health"

    def test_accepts_qd10_signal(self) -> None:
        payload = _signal_payload(
            "QD10",
            "P-QD10-cross-module-ref-static",
            "wf-fix-integration",
            "cross_module_ref_drift",
        )
        signal = Signal.from_dict(payload)
        assert signal.dimension_id == "QD10"
        assert signal.lane == "wf-fix-integration"

    def test_accepts_qd11_signal(self) -> None:
        payload = _signal_payload(
            "QD11", "P-QD11-foo", "wf-fix-business-completeness", "missing_field"
        )
        signal = Signal.from_dict(payload)
        assert signal.dimension_id == "QD11"
        assert signal.lane == "wf-fix-business-completeness"


# ──────────────────────────────────────────────────────────────────────
# 3. JSON schemas — enum bao gồm QD9/QD10
# ──────────────────────────────────────────────────────────────────────


class TestJsonSchemaV9Enum:
    """signal.v2 + issue.v2 schema phải accept QD9/QD10."""

    def test_signal_v2_dimension_enum_includes_qd9_qd10(self) -> None:
        schema = json.loads(
            (SCHEMAS_DIR / "signal.v2.schema.json").read_text(encoding="utf-8")
        )
        enum = schema["properties"]["dimension_id"]["enum"]
        assert "QD9" in enum
        assert "QD10" in enum

    def test_signal_v2_probe_id_pattern_matches_v9(self) -> None:
        schema = json.loads(
            (SCHEMAS_DIR / "signal.v2.schema.json").read_text(encoding="utf-8")
        )
        # Đường truyền pattern là JSON string (raw regex)
        pattern = schema["properties"]["probe_id"]["pattern"]
        import re

        compiled = re.compile(pattern)
        assert compiled.match("P-QD9-test")
        assert compiled.match("P-QD10-test")
        assert compiled.match("P-QD11-test")   # v9.1.0: QD11 supported

    def test_issue_v2_dimensions_enum_includes_qd9_qd10(self) -> None:
        schema = json.loads(
            (SCHEMAS_DIR / "issue.v2.schema.json").read_text(encoding="utf-8")
        )
        enum = schema["properties"]["dimensions"]["items"]["enum"]
        assert "QD9" in enum
        assert "QD10" in enum


# ──────────────────────────────────────────────────────────────────────
# 4. dimension.json — tồn tại + valid structure cho cả 2 lane
# ──────────────────────────────────────────────────────────────────────


class TestDimensionJsonV9:
    """dimension.json cho QD9 + QD10 phải tồn tại và đúng structure."""

    @pytest.mark.parametrize(
        "dim,lane",
        [
            ("QD9", "wf-fix-runtime-health"),
            ("QD10", "wf-fix-integration"),
        ],
    )
    def test_dimension_json_exists(self, dim: str, lane: str) -> None:
        dim_json = WORKFLOW_ROOT / lane / "dimension.json"
        assert dim_json.exists(), f"dimension.json missing for {dim} at {dim_json}"

    @pytest.mark.parametrize(
        "dim,lane,expected_probe_count",
        [
            # Sprint 5 (v10.2.1) thêm P-QD9-llm-analysis → tổng 9 probes (8 core + 1 LLM gating).
            ("QD9", "wf-fix-runtime-health", 9),
            ("QD10", "wf-fix-integration", 10),
        ],
    )
    def test_dimension_json_probe_count(
        self, dim: str, lane: str, expected_probe_count: int
    ) -> None:
        dim_json = WORKFLOW_ROOT / lane / "dimension.json"
        data = json.loads(dim_json.read_text(encoding="utf-8"))
        assert data["dimension_id"] == dim
        assert len(data["probes"]) == expected_probe_count

    @pytest.mark.parametrize(
        "dim,lane",
        [
            ("QD9", "wf-fix-runtime-health"),
            ("QD10", "wf-fix-integration"),
        ],
    )
    def test_dimension_json_exit_criteria_valid(self, dim: str, lane: str) -> None:
        """exit_criteria.{quick,standard,deep,exhaustive} reference probes thực sự tồn tại."""
        dim_json = WORKFLOW_ROOT / lane / "dimension.json"
        data = json.loads(dim_json.read_text(encoding="utf-8"))
        probe_ids = {p["id"] for p in data["probes"]}

        for profile in ("standard", "deep"):
            required = data["exit_criteria"][profile]["probes_required"]
            assert isinstance(required, list)
            for pid in required:
                assert pid in probe_ids, f"{dim} {profile}: {pid} not in probes[]"

        # quick = empty (cả 2 lane skip trong quick)
        assert data["exit_criteria"]["quick"]["probes_required"] == []

        # exhaustive = "ALL" hoặc list
        exh = data["exit_criteria"]["exhaustive"]["probes_required"]
        assert exh == "ALL" or isinstance(exh, list)

    @pytest.mark.parametrize(
        "dim,lane",
        [
            ("QD9", "wf-fix-runtime-health"),
            ("QD10", "wf-fix-integration"),
        ],
    )
    def test_dimension_json_parallel_groups_match_probes(
        self, dim: str, lane: str
    ) -> None:
        """parallel_groups[][] tất cả probe IDs phải tồn tại + dimension_id khớp."""
        dim_json = WORKFLOW_ROOT / lane / "dimension.json"
        data = json.loads(dim_json.read_text(encoding="utf-8"))
        assert data["dimension_id"] == dim
        probe_ids = {p["id"] for p in data["probes"]}
        for grp in data["parallel_groups"]:
            for pid in grp:
                assert pid in probe_ids


# ──────────────────────────────────────────────────────────────────────
# 5. lane_dispatch — dispatch_lane(QD9/QD10) thành công ở mọi profile
# ──────────────────────────────────────────────────────────────────────


class TestLaneDispatchV9:
    """lane_dispatch._execute_lane_sequential phải trả status=completed cho QD9/QD10."""

    @pytest.fixture
    def session_dir(self, tmp_path: Path) -> Path:
        return tmp_path / "session"

    @pytest.fixture
    def workflow_root(self) -> Path:
        return WORKFLOW_ROOT.resolve()

    @pytest.mark.parametrize(
        "dim,profile,expected_probes",
        [
            # Sprint 5/v10.2.1 đã thêm P-QD9-llm-analysis + bổ sung core probes
            # → exit_criteria QD9 standard=6, deep=9, exhaustive=ALL(9).
            ("QD9", "quick", 0),
            ("QD9", "standard", 6),
            ("QD9", "deep", 9),
            ("QD9", "exhaustive", 9),
            ("QD10", "quick", 0),
            ("QD10", "standard", 3),
            ("QD10", "deep", 6),
            ("QD10", "exhaustive", 10),
        ],
    )
    def test_dispatch_lane_completes(
        self,
        dim: str,
        profile: str,
        expected_probes: int,
        session_dir: Path,
        workflow_root: Path,
    ) -> None:
        result = _execute_lane_sequential(
            dim=dim,
            session_dir=session_dir,
            profile=profile,
            workflow_root=workflow_root,
            use_cache=False,
        )
        assert result.status == "completed", (
            f"{dim}/{profile}: expected completed but got {result.status} "
            f"(error={result.error})"
        )
        assert result.probes_executed == expected_probes, (
            f"{dim}/{profile}: expected {expected_probes} probes "
            f"but got {result.probes_executed}"
        )


# ──────────────────────────────────────────────────────────────────────
# 6. dimension_registry — đăng ký QD9/QD10
# ──────────────────────────────────────────────────────────────────────


class TestDimensionRegistryV9:
    """DIMENSION_REGISTRY phải có QD9 + QD10 mapping tới đúng lane."""

    def test_qd9_registered(self) -> None:
        assert "QD9" in DIMENSION_REGISTRY
        config = DIMENSION_REGISTRY["QD9"]
        assert config.lane == "wf-fix-runtime-health"
        assert config.cache_allowed is False  # runtime probes

    def test_qd10_registered(self) -> None:
        assert "QD10" in DIMENSION_REGISTRY
        config = DIMENSION_REGISTRY["QD10"]
        assert config.lane == "wf-fix-integration"
        assert config.cache_allowed is True  # static probes cho phép cache

    def test_validate_lane_exists_qd9(self) -> None:
        assert validate_lane_exists("QD9", WORKFLOW_ROOT) is True

    def test_validate_lane_exists_qd10(self) -> None:
        assert validate_lane_exists("QD10", WORKFLOW_ROOT) is True

    def test_get_lane_path_qd9(self) -> None:
        path = get_lane_path("QD9", WORKFLOW_ROOT)
        assert path.name == "wf-fix-runtime-health"

    def test_get_lane_path_qd10(self) -> None:
        path = get_lane_path("QD10", WORKFLOW_ROOT)
        assert path.name == "wf-fix-integration"

    def test_get_cache_policy_qd9_runtime(self) -> None:
        # QD9 runtime probes — cache=skip (always re-run)
        assert get_cache_policy("QD9") is False

    def test_get_cache_policy_qd10_mixed(self) -> None:
        # QD10 mix static (cache allowed) + runtime (skip) — registry-level = True
        # (per-probe cache_policy check là trong dimension.json)
        assert get_cache_policy("QD10") is True
