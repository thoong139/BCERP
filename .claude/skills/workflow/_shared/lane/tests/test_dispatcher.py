"""test_dispatcher.py — Unit tests cho lane module.

Test coverage:
    1. dispatch_lanes: empty list, single lane, multiple parallel lanes
    2. LaneConfig/LaneResult: dataclass construction
    3. write_lane_signal / load_lane_signal: I/O helpers
    4. Timeout handling
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from lane.dispatcher import (
    LaneConfig,
    LaneResult,
    dispatch_lanes,
    load_lane_signal,
    write_lane_signal,
)


@pytest.fixture
def tmp_dir(tmp_path):
    """Tạo thư mục tạm cho test output."""
    return tmp_path


def _make_lane(key: str, tmp_dir: Path) -> LaneConfig:
    """Helper tạo LaneConfig."""
    return LaneConfig(
        key=key,
        agent_type="business-analyst",
        prompt=f"Analyze {key}",
        output_path=tmp_dir / f"{key}.json",
        context={"lane_type": "department"},
    )


# ──────────────────────────────────────────────────────────────────────
# 1. dispatch_lanes
# ──────────────────────────────────────────────────────────────────────


class TestDispatchLanes:
    """Test dispatch_lanes: empty, single, multiple."""

    def test_empty_lanes_returns_empty(self):
        """Không có lane → trả về list rỗng."""
        results = dispatch_lanes([])
        assert results == []

    def test_single_lane_succeeds(self, tmp_dir):
        """1 lane → 1 result success."""
        lane = _make_lane("dept-sales", tmp_dir)
        results = dispatch_lanes([lane])
        assert len(results) == 1
        assert results[0].key == "dept-sales"
        assert results[0].status == "success"
        assert results[0].duration_ms >= 0
        assert results[0].error is None

    def test_multiple_lanes_parallel(self, tmp_dir):
        """3 lanes → 3 results, tất cả success."""
        lanes = [
            _make_lane(f"lane-{i}", tmp_dir)
            for i in range(3)
        ]
        results = dispatch_lanes(lanes, max_parallel=3)
        assert len(results) == 3
        assert all(r.status == "success" for r in results)

    def test_output_file_created(self, tmp_dir):
        """Lane chạy xong → output file tồn tại."""
        lane = _make_lane("dept-hr", tmp_dir)
        dispatch_lanes([lane])
        assert lane.output_path.exists()

    def test_output_has_correct_schema(self, tmp_dir):
        """Output file có $schema đúng."""
        lane = _make_lane("dept-finance", tmp_dir)
        dispatch_lanes([lane])
        data = json.loads(lane.output_path.read_text(encoding="utf-8"))
        assert data.get("$schema") == "lane-signal-v1"
        assert data["lane_key"] == "dept-finance"


# ──────────────────────────────────────────────────────────────────────
# 2. write_lane_signal / load_lane_signal
# ──────────────────────────────────────────────────────────────────────


class TestLaneSignalIO:
    """Test lane signal I/O helpers."""

    def test_write_and_load_roundtrip(self, tmp_dir):
        """Ghi → đọc → data khớp."""
        path = tmp_dir / "signal.json"
        items = [{"id": "REQ-001"}, {"id": "REQ-002"}]
        metadata = {"agent_type": "business-analyst", "profile": "standard"}

        write_lane_signal(path, "dept-sales", "department", items, metadata)

        data = load_lane_signal(path)
        assert data["lane_key"] == "dept-sales"
        assert data["lane_type"] == "department"
        assert len(data["items"]) == 2
        assert data["metadata"]["agent_type"] == "business-analyst"

    def test_load_nonexistent_raises(self, tmp_dir):
        """Đọc file không tồn tại → FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            load_lane_signal(tmp_dir / "nonexistent.json")

    def test_write_creates_parent_dirs(self, tmp_dir):
        """Ghi file tạo parent directories nếu chưa có."""
        path = tmp_dir / "nested" / "dir" / "signal.json"
        write_lane_signal(path, "test", "system", [])
        assert path.exists()


# ──────────────────────────────────────────────────────────────────────
# 3. Data classes
# ──────────────────────────────────────────────────────────────────────


class TestDataClasses:
    """Test LaneConfig và LaneResult dataclass."""

    def test_lane_config_defaults(self):
        """LaneConfig có context mặc định là {}."""
        config = LaneConfig(
            key="test",
            agent_type="developer",
            prompt="Do something",
            output_path=Path("/tmp/out.json"),
        )
        assert config.context == {}

    def test_lane_result_with_error(self):
        """LaneResult có thể chứa error."""
        result = LaneResult(
            key="test",
            status="error",
            output_path=Path("/tmp/out.json"),
            duration_ms=100,
            error="Agent failed",
        )
        assert result.status == "error"
        assert result.error == "Agent failed"

    def test_lane_result_timeout(self):
        """LaneResult có thể represent timeout."""
        result = LaneResult(
            key="test",
            status="timeout",
            output_path=Path("/tmp/out.json"),
            duration_ms=300000,
            error="Timeout sau 300s",
        )
        assert result.status == "timeout"
