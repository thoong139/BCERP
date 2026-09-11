"""test_profile_resolver_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify:
- resolve_probes: dimension.json → probe IDs (per profile)
- resolve_dimensions: profiles.json → dimension list (per profile, overrides, safety floor)
- _validate_probe_id pattern check
- CLI main() — probes + dimensions subcommands

Test fixtures dùng tmp_path tạo dimension.json + profiles.json giả lập.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from profile_resolver import (
    CORE_DIMS,
    PROBE_ID_PATTERN,
    VALID_PROFILES,
    _validate_probe_id,
    main,
    resolve_dimensions,
    resolve_probes,
)


def _dim_json(probes: list[str], exit_criteria: dict) -> dict:
    """Build minimal dimension.json structure."""
    return {
        "dimension_id": "QD1",
        "probes": [{"id": p, "name": p} for p in probes],
        "exit_criteria": exit_criteria,
    }


# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────


class TestConstants:
    def test_valid_profiles(self) -> None:
        assert VALID_PROFILES == frozenset({"quick", "standard", "deep", "exhaustive"})

    def test_core_dims(self) -> None:
        assert CORE_DIMS == frozenset({"QD1", "QD2", "QD5"})

    def test_probe_id_pattern_matches_valid(self) -> None:
        for pid in [
            "P-QD1-test-x", "P-QD9-runtime-health", "P-QD10-integration", "P-QD11-completeness"
        ]:
            assert PROBE_ID_PATTERN.match(pid)

    def test_probe_id_pattern_rejects_invalid(self) -> None:
        for pid in [
            "P-QD12-x",  # > 11
            "P-QD0-x",  # 0
            "P-QD1-Uppercase",  # uppercase
            "QD1-x",  # missing P prefix
            "p-qd1-x",  # lowercase P
        ]:
            assert not PROBE_ID_PATTERN.match(pid)


# ──────────────────────────────────────────────────────────────────────
# _validate_probe_id
# ──────────────────────────────────────────────────────────────────────


class TestValidateProbeId:
    def test_valid_passes(self) -> None:
        _validate_probe_id("P-QD1-test", 0)

    def test_invalid_raises(self) -> None:
        with pytest.raises(ValueError, match="không match pattern"):
            _validate_probe_id("INVALID", 5)


# ──────────────────────────────────────────────────────────────────────
# resolve_probes
# ──────────────────────────────────────────────────────────────────────


class TestResolveProbes:
    def test_explicit_list(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dimension.json"
        dim_path.write_text(json.dumps(_dim_json(
            ["P-QD1-a", "P-QD1-b"],
            {"standard": {"probes_required": ["P-QD1-a"]}},
        )), encoding="utf-8")
        assert resolve_probes(dim_path, "standard") == ["P-QD1-a"]

    def test_all_profile_returns_everything(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dimension.json"
        dim_path.write_text(json.dumps(_dim_json(
            ["P-QD1-a", "P-QD1-b", "P-QD1-c"],
            {"exhaustive": {"probes_required": "ALL"}},
        )), encoding="utf-8")
        assert resolve_probes(dim_path, "exhaustive") == ["P-QD1-a", "P-QD1-b", "P-QD1-c"]

    def test_empty_list_skip(self, tmp_path: Path) -> None:
        """probes_required=[] → legitimate SKIP (vd: QD2 quick)."""
        dim_path = tmp_path / "dimension.json"
        dim_path.write_text(json.dumps(_dim_json(
            ["P-QD1-a"],
            {"quick": {"probes_required": []}},
        )), encoding="utf-8")
        assert resolve_probes(dim_path, "quick") == []

    def test_invalid_profile(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dimension.json"
        dim_path.write_text("{}", encoding="utf-8")
        with pytest.raises(ValueError, match="profile.*không hợp lệ"):
            resolve_probes(dim_path, "invalid-profile")

    def test_file_not_found(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="không tồn tại"):
            resolve_probes(tmp_path / "missing.json", "standard")

    def test_json_parse_fail(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "bad.json"
        dim_path.write_text("not valid json {", encoding="utf-8")
        with pytest.raises(ValueError, match="JSON parse fail"):
            resolve_probes(dim_path, "standard")

    def test_root_not_object(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "arr.json"
        dim_path.write_text("[]", encoding="utf-8")
        with pytest.raises(ValueError, match="root phải là object"):
            resolve_probes(dim_path, "standard")

    def test_missing_exit_criteria(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dim.json"
        dim_path.write_text(json.dumps({"probes": []}), encoding="utf-8")
        with pytest.raises(ValueError, match="thiếu exit_criteria"):
            resolve_probes(dim_path, "standard")

    def test_profile_not_in_exit_criteria(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dim.json"
        dim_path.write_text(json.dumps({
            "probes": [],
            "exit_criteria": {"quick": {"probes_required": []}},
        }), encoding="utf-8")
        with pytest.raises(ValueError, match="không có trong exit_criteria"):
            resolve_probes(dim_path, "deep")

    def test_invalid_probe_id_in_list(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dim.json"
        dim_path.write_text(json.dumps({
            "probes": [],
            "exit_criteria": {"standard": {"probes_required": ["INVALID"]}},
        }), encoding="utf-8")
        with pytest.raises(ValueError, match="không match pattern"):
            resolve_probes(dim_path, "standard")

    def test_probes_required_wrong_type(self, tmp_path: Path) -> None:
        dim_path = tmp_path / "dim.json"
        dim_path.write_text(json.dumps({
            "probes": [],
            "exit_criteria": {"standard": {"probes_required": 42}},
        }), encoding="utf-8")
        with pytest.raises(ValueError, match="probes_required"):
            resolve_probes(dim_path, "standard")


# ──────────────────────────────────────────────────────────────────────
# resolve_dimensions
# ──────────────────────────────────────────────────────────────────────


def _profiles_json(profile_dims: dict[str, list[str]], safety_applies: list[str] | None = None) -> dict:
    """Build minimal profiles.json."""
    out: dict = {
        "profiles": {p: {"dimensions": d} for p, d in profile_dims.items()},
    }
    if safety_applies is not None:
        out["safety_floor"] = {"applies_to": safety_applies}
    return out


class TestResolveDimensions:
    def test_basic_lookup(self, tmp_path: Path) -> None:
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json({
            "standard": ["QD1", "QD3"],
        })), encoding="utf-8")
        assert resolve_dimensions(path, "standard") == ["QD1", "QD3"]

    def test_override_dims(self, tmp_path: Path) -> None:
        """dims_override replaces base list."""
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json({
            "standard": ["QD1", "QD3"],
        })), encoding="utf-8")
        assert resolve_dimensions(path, "standard", dims_override=["QD5"]) == ["QD5"]

    def test_only_filter(self, tmp_path: Path) -> None:
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json({
            "standard": ["QD1", "QD3", "QD5"],
        })), encoding="utf-8")
        assert resolve_dimensions(path, "standard", only=["QD1", "QD5"]) == ["QD1", "QD5"]

    def test_skip_filter(self, tmp_path: Path) -> None:
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json({
            "standard": ["QD1", "QD3", "QD5"],
        })), encoding="utf-8")
        assert resolve_dimensions(path, "standard", skip=["QD3"]) == ["QD1", "QD5"]

    def test_safety_floor_violation(self, tmp_path: Path) -> None:
        """profile in applies_to + result không có core dim → raise."""
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json(
            {"standard": ["QD1", "QD3"]},
            safety_applies=["standard"],
        )), encoding="utf-8")
        with pytest.raises(ValueError, match="safety floor violation"):
            # Override để không có QD1/QD2/QD5
            resolve_dimensions(path, "standard", dims_override=["QD3"])

    def test_safety_floor_skip_when_quick(self, tmp_path: Path) -> None:
        """profile quick không trong applies_to → safety floor không enforce."""
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps(_profiles_json(
            {"quick": ["QD3"]},
            safety_applies=["standard", "deep"],
        )), encoding="utf-8")
        # Quick + result không có core dim → OK
        assert resolve_dimensions(path, "quick", dims_override=["QD3"]) == ["QD3"]

    def test_invalid_profile(self, tmp_path: Path) -> None:
        path = tmp_path / "p.json"
        path.write_text("{}", encoding="utf-8")
        with pytest.raises(ValueError, match="không hợp lệ"):
            resolve_dimensions(path, "invalid")

    def test_file_not_found(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            resolve_dimensions(tmp_path / "missing.json", "standard")

    def test_json_parse_fail(self, tmp_path: Path) -> None:
        path = tmp_path / "bad.json"
        path.write_text("invalid json {", encoding="utf-8")
        with pytest.raises(ValueError, match="JSON parse fail"):
            resolve_dimensions(path, "standard")

    def test_missing_profiles_key(self, tmp_path: Path) -> None:
        path = tmp_path / "p.json"
        path.write_text("{}", encoding="utf-8")
        with pytest.raises(ValueError, match="thiếu 'profiles'"):
            resolve_dimensions(path, "standard")

    def test_profile_missing(self, tmp_path: Path) -> None:
        path = tmp_path / "p.json"
        path.write_text(json.dumps({"profiles": {"quick": {}}}), encoding="utf-8")
        with pytest.raises(ValueError, match="không có trong profiles"):
            resolve_dimensions(path, "standard")


# ──────────────────────────────────────────────────────────────────────
# CLI main()
# ──────────────────────────────────────────────────────────────────────


class TestCLI:
    def test_probes_subcommand(self, capsys, tmp_path: Path) -> None:
        dim_path = tmp_path / "dim.json"
        dim_path.write_text(json.dumps({
            "probes": [{"id": "P-QD1-a"}],
            "exit_criteria": {"standard": {"probes_required": ["P-QD1-a"]}},
        }), encoding="utf-8")
        rc = main(["probes", "--dimension-json", str(dim_path), "--profile", "standard"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "P-QD1-a" in captured.out

    def test_dimensions_subcommand(self, capsys, tmp_path: Path) -> None:
        path = tmp_path / "p.json"
        path.write_text(json.dumps(_profiles_json({"quick": ["QD1"]})), encoding="utf-8")
        rc = main(["dimensions", "--profiles-json", str(path), "--profile", "quick"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "QD1" in captured.out

    def test_dimensions_lane_shorthand(self, capsys, tmp_path: Path) -> None:
        """--lane shorthand: single-lane focus, không cần profiles.json."""
        path = tmp_path / "p.json"
        # File không cần tồn tại vì lane shortcut bypass safety floor
        path.write_text(json.dumps(_profiles_json({"quick": ["QD1"]})), encoding="utf-8")
        rc = main(["dimensions", "--profiles-json", str(path), "--profile", "quick", "--lane", "QD10"])
        captured = capsys.readouterr()
        assert rc == 0
        assert "QD10" in captured.out

    def test_error_returns_1(self, capsys, tmp_path: Path) -> None:
        rc = main(["probes", "--dimension-json", str(tmp_path / "missing.json"), "--profile", "standard"])
        captured = capsys.readouterr()
        assert rc == 1
        assert "ERROR" in captured.err
