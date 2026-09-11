"""test_dimension_registry_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify public API:
- DIMENSION_REGISTRY: 11 entries (QD1-QD11)
- get_lane_path / get_lane_name / get_all_dimensions
- validate_lane_exists / get_cache_policy / get_agents / _get_config
- get_lane_name fallback handling
- CLI main() — argparse paths
"""
from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest

from dimension_registry import (
    DIMENSION_REGISTRY,
    _DEFAULT_LANE_FALLBACK,
    get_agents,
    get_all_dimensions,
    get_cache_policy,
    get_lane_name,
    get_lane_path,
    main,
    validate_lane_exists,
)


# ──────────────────────────────────────────────────────────────────────
# Registry structure
# ──────────────────────────────────────────────────────────────────────


class TestRegistryStructure:
    """Verify DIMENSION_REGISTRY có 11 entries QD1-QD11."""

    def test_eleven_dimensions(self) -> None:
        assert len(DIMENSION_REGISTRY) == 11
        for i in range(1, 12):
            assert f"QD{i}" in DIMENSION_REGISTRY

    def test_each_dim_has_required_fields(self) -> None:
        for dim, config in DIMENSION_REGISTRY.items():
            assert config.dim == dim
            assert config.lane.startswith("wf-fix-")
            assert isinstance(config.agents, list)
            assert isinstance(config.cache_allowed, bool)

    def test_qd3_no_cache(self) -> None:
        """ADR-22 Rule 6: QD3 cache_allowed=False."""
        assert DIMENSION_REGISTRY["QD3"].cache_allowed is False

    def test_qd9_qd11_no_cache(self) -> None:
        """Runtime/LLM dimensions luôn re-run (no cache)."""
        assert DIMENSION_REGISTRY["QD9"].cache_allowed is False
        assert DIMENSION_REGISTRY["QD11"].cache_allowed is False


# ──────────────────────────────────────────────────────────────────────
# get_lane_path
# ──────────────────────────────────────────────────────────────────────


class TestGetLanePath:
    def test_valid_dim(self, tmp_path: Path) -> None:
        path = get_lane_path("QD3", tmp_path)
        assert path == tmp_path / "wf-fix-security"

    def test_invalid_dim_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="không hợp lệ"):
            get_lane_path("QD99", tmp_path)


# ──────────────────────────────────────────────────────────────────────
# get_lane_name (F06.005)
# ──────────────────────────────────────────────────────────────────────


class TestGetLaneName:
    def test_valid_dim(self) -> None:
        assert get_lane_name("QD1") == "wf-fix-functional"
        assert get_lane_name("QD11") == "wf-fix-business-completeness"

    def test_none_falls_back(self) -> None:
        assert get_lane_name(None) == _DEFAULT_LANE_FALLBACK

    def test_invalid_falls_back(self) -> None:
        assert get_lane_name("QD99") == _DEFAULT_LANE_FALLBACK

    def test_custom_default(self) -> None:
        assert get_lane_name(None, default="custom-fallback") == "custom-fallback"
        assert get_lane_name("QD99", default="custom-fallback") == "custom-fallback"


# ──────────────────────────────────────────────────────────────────────
# get_all_dimensions
# ──────────────────────────────────────────────────────────────────────


class TestGetAllDimensions:
    def test_returns_sorted_list(self) -> None:
        dims = get_all_dimensions()
        assert dims == sorted(dims)
        assert len(dims) == 11
        assert dims[0] == "QD1"


# ──────────────────────────────────────────────────────────────────────
# validate_lane_exists
# ──────────────────────────────────────────────────────────────────────


class TestValidateLaneExists:
    def test_lane_dir_missing(self, tmp_path: Path) -> None:
        assert validate_lane_exists("QD3", tmp_path) is False

    def test_lane_dir_no_dimension_json(self, tmp_path: Path) -> None:
        (tmp_path / "wf-fix-security").mkdir()
        assert validate_lane_exists("QD3", tmp_path) is False

    def test_lane_complete(self, tmp_path: Path) -> None:
        lane = tmp_path / "wf-fix-security"
        lane.mkdir()
        (lane / "dimension.json").write_text("{}", encoding="utf-8")
        assert validate_lane_exists("QD3", tmp_path) is True

    def test_invalid_dim_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError):
            validate_lane_exists("QD99", tmp_path)


# ──────────────────────────────────────────────────────────────────────
# get_cache_policy / get_agents
# ──────────────────────────────────────────────────────────────────────


class TestGetCachePolicy:
    def test_qd1_allowed(self) -> None:
        assert get_cache_policy("QD1") is True

    def test_qd3_denied(self) -> None:
        assert get_cache_policy("QD3") is False

    def test_invalid_raises(self) -> None:
        with pytest.raises(ValueError):
            get_cache_policy("QD99")


class TestGetAgents:
    def test_qd3_has_security(self) -> None:
        agents = get_agents("QD3")
        assert "security" in agents

    def test_qd1_empty_list(self) -> None:
        """QD1 functional không pin agent specific."""
        agents = get_agents("QD1")
        assert isinstance(agents, list)

    def test_invalid_raises(self) -> None:
        with pytest.raises(ValueError):
            get_agents("QD99")


# ──────────────────────────────────────────────────────────────────────
# CLI main()
# ──────────────────────────────────────────────────────────────────────


class TestCLI:
    def test_lane_path_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["--dim", "QD3", "--workflow-root", str(tmp_path), "--lane-path"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "wf-fix-security" in captured.out

    def test_cache_policy_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["--dim", "QD3", "--workflow-root", str(tmp_path), "--cache-policy"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "False" in captured.out

    def test_validate_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["--dim", "QD3", "--workflow-root", str(tmp_path), "--validate"])
        captured = capsys.readouterr()
        assert rc == 0
        # Lane dir không tồn tại → False
        assert "False" in captured.out

    def test_agents_subcommand(self, capsys, tmp_path: Path) -> None:
        rc = main(["--dim", "QD3", "--workflow-root", str(tmp_path), "--agents"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "security" in captured.out

    def test_invalid_dim_returns_1(self, capsys, tmp_path: Path) -> None:
        rc = main(["--dim", "QD99", "--workflow-root", str(tmp_path), "--lane-path"])
        captured = capsys.readouterr()
        assert rc == 1
        assert "ERROR" in captured.err
