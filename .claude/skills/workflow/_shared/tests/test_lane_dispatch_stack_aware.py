"""Tests cho stack-aware probe dispatch (Phase B v8 wf-fix-bugs)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lane_dispatch import (  # noqa: E402
    PROBE_REGISTRY,
    STATIC_PROBE_SCRIPTS,
    ProbeSpec,
    _is_probe_applicable_for_stack,
    _load_stack_from_session,
)


class TestProbeRegistry:
    def test_registry_non_empty(self):
        assert len(PROBE_REGISTRY) > 0

    def test_static_scripts_derived_from_registry(self):
        assert STATIC_PROBE_SCRIPTS == {pid: spec.script for pid, spec in PROBE_REGISTRY.items()}

    def test_all_specs_valid(self):
        for pid, spec in PROBE_REGISTRY.items():
            assert isinstance(spec, ProbeSpec)
            assert spec.script.endswith(".sh")
            assert len(spec.applicable_stacks) > 0
            assert len(spec.dimensions) > 0
            assert all(d.startswith("QD") for d in spec.dimensions)


class TestApplicabilityCheck:
    def test_any_stack_always_applies(self):
        # P-QD1-req-registry-xref has applicable_stacks=("any",)
        assert _is_probe_applicable_for_stack("P-QD1-req-registry-xref", "csharp-dotnet")
        assert _is_probe_applicable_for_stack("P-QD1-req-registry-xref", "python-fastapi")
        assert _is_probe_applicable_for_stack("P-QD1-req-registry-xref", "go")
        assert _is_probe_applicable_for_stack("P-QD1-req-registry-xref", None)

    def test_react_probe_only_for_react(self):
        # P-QD1-react-contract-check applicable_stacks=("typescript-react", ...)
        assert _is_probe_applicable_for_stack("P-QD1-react-contract-check", "typescript-react")
        assert _is_probe_applicable_for_stack("P-QD1-react-contract-check", "typescript-nextjs")
        assert _is_probe_applicable_for_stack("P-QD1-react-contract-check", "javascript-react")
        # Should NOT apply to non-React stacks
        assert not _is_probe_applicable_for_stack("P-QD1-react-contract-check", "csharp-dotnet")
        assert not _is_probe_applicable_for_stack("P-QD1-react-contract-check", "python-fastapi")
        assert not _is_probe_applicable_for_stack("P-QD1-react-contract-check", "go")

    def test_python_probe_for_python(self):
        assert _is_probe_applicable_for_stack("P-QD1-python-endpoint-check", "python-fastapi")
        assert _is_probe_applicable_for_stack("P-QD1-python-endpoint-check", "python-django")
        assert not _is_probe_applicable_for_stack("P-QD1-python-endpoint-check", "typescript-react")

    def test_secondary_stack_match(self):
        # Monorepo: primary=csharp, secondary=[typescript-nextjs]
        assert _is_probe_applicable_for_stack(
            "P-QD1-react-contract-check", "csharp-dotnet", ["typescript-nextjs"]
        )

    def test_unknown_probe_returns_true(self):
        # Probe không trong registry → fail open (return True), let orchestrator handle
        assert _is_probe_applicable_for_stack("P-NONEXISTENT-ID", "csharp-dotnet")

    def test_no_stack_info_fails_open(self):
        # primary_stack=None → return True (don't silently skip when stack unknown)
        assert _is_probe_applicable_for_stack("P-QD1-react-contract-check", None)

    def test_vue_probe(self):
        assert _is_probe_applicable_for_stack("P-QD1-vue-composition-check", "vue")
        assert not _is_probe_applicable_for_stack("P-QD1-vue-composition-check", "typescript-react")


class TestLoadStackFromSession:
    def test_missing_file_returns_none(self, tmp_path: Path):
        primary, secondary = _load_stack_from_session(tmp_path)
        assert primary is None
        assert secondary == []

    def test_valid_session(self, tmp_path: Path):
        (tmp_path / "stack-info.json").write_text(json.dumps({
            "primary_stack": "typescript-nextjs",
            "secondary_stacks": ["csharp-dotnet"],
        }), encoding="utf-8")
        primary, secondary = _load_stack_from_session(tmp_path)
        assert primary == "typescript-nextjs"
        assert secondary == ["csharp-dotnet"]

    def test_unknown_stack_returns_none(self, tmp_path: Path):
        # primary="unknown" → treated as None (probes fail-open)
        (tmp_path / "stack-info.json").write_text(json.dumps({
            "primary_stack": "unknown",
            "secondary_stacks": [],
        }), encoding="utf-8")
        primary, secondary = _load_stack_from_session(tmp_path)
        assert primary is None

    def test_corrupt_file_returns_none(self, tmp_path: Path):
        (tmp_path / "stack-info.json").write_text("{not valid", encoding="utf-8")
        primary, secondary = _load_stack_from_session(tmp_path)
        assert primary is None
        assert secondary == []

    def test_invalid_secondary_type(self, tmp_path: Path):
        (tmp_path / "stack-info.json").write_text(json.dumps({
            "primary_stack": "go",
            "secondary_stacks": "not-a-list",  # invalid type
        }), encoding="utf-8")
        primary, secondary = _load_stack_from_session(tmp_path)
        assert primary == "go"
        assert secondary == []  # falls back gracefully


class TestStackCoverageMatrix:
    """Verify mỗi probe ID xuất hiện trong PROBE_REGISTRY có valid stack mapping."""

    @pytest.mark.parametrize("stack", [
        "csharp-dotnet", "typescript-react", "typescript-nextjs",
        "python-fastapi", "vue", "go", "java-spring",
    ])
    def test_at_least_one_probe_per_stack(self, stack: str):
        applicable = [pid for pid, spec in PROBE_REGISTRY.items()
                      if "any" in spec.applicable_stacks or stack in spec.applicable_stacks]
        # Mỗi stack phải có ít nhất 1 probe applicable (qua "any" cross-stack hoặc stack-specific)
        assert len(applicable) >= 3, f"Stack {stack} has only {len(applicable)} applicable probes"

    def test_react_has_specific_probes(self):
        react_specific = [pid for pid, spec in PROBE_REGISTRY.items()
                          if "typescript-react" in spec.applicable_stacks
                          and "any" not in spec.applicable_stacks]
        assert len(react_specific) >= 1, "Expected at least 1 React-specific probe"

    def test_python_has_specific_probes(self):
        py_specific = [pid for pid, spec in PROBE_REGISTRY.items()
                       if "python-fastapi" in spec.applicable_stacks
                       and "any" not in spec.applicable_stacks]
        assert len(py_specific) >= 1, "Expected at least 1 Python-specific probe"

    def test_go_has_specific_probes(self):
        go_specific = [pid for pid, spec in PROBE_REGISTRY.items()
                       if "go" in spec.applicable_stacks
                       and "any" not in spec.applicable_stacks]
        assert len(go_specific) >= 1, "Expected at least 1 Go-specific probe"

    def test_vue_has_specific_probes(self):
        vue_specific = [pid for pid, spec in PROBE_REGISTRY.items()
                        if "vue" in spec.applicable_stacks
                        and "any" not in spec.applicable_stacks]
        assert len(vue_specific) >= 1, "Expected at least 1 Vue-specific probe"
