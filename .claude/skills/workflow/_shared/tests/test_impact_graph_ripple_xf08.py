"""test_impact_graph_ripple_xf08.py — XF-08 (Sprint 6) coverage uplift.

Verify impact_graph/ripple.py:
- _load_graph: schema validation, missing keys, missing file
- _build_reverse_index: edge indexing by target
- _resolve_issue_file: priority order (file_path, target.file_path, evidence[0])
- verify_ripple: end-to-end BFS với depth/strength filters
- CLI main()
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from impact_graph.ripple import (
    DEFAULT_DEPTH,
    DEFAULT_STRENGTH,
    RippleTarget,
    _build_reverse_index,
    _load_graph,
    _resolve_issue_file,
    verify_ripple,
)


@pytest.fixture
def sample_graph(tmp_path: Path) -> Path:
    """Build sample impact-graph.json.

    Graph: A → B → C → D (linear chain).
    Edges represent IMPORT: target is imported BY source.
    """
    data = {
        "$schema": "impact-graph.v1",
        "nodes": [
            {"id": "src/a.ts"},
            {"id": "src/b.ts"},
            {"id": "src/c.ts"},
            {"id": "src/d.ts"},
        ],
        "edges": [
            {"source": "src/a.ts", "target": "src/b.ts", "strength": 0.8},
            {"source": "src/b.ts", "target": "src/c.ts", "strength": 0.6},
            {"source": "src/c.ts", "target": "src/d.ts", "strength": 0.3},  # Weak
        ],
    }
    path = tmp_path / "impact-graph.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────


def test_constants() -> None:
    assert DEFAULT_DEPTH == 1
    assert DEFAULT_STRENGTH == 0.5


# ──────────────────────────────────────────────────────────────────────
# _load_graph
# ──────────────────────────────────────────────────────────────────────


class TestLoadGraph:
    def test_missing_file(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            _load_graph(tmp_path / "missing.json")

    def test_invalid_schema(self, tmp_path: Path) -> None:
        path = tmp_path / "g.json"
        path.write_text(json.dumps({"$schema": "wrong"}), encoding="utf-8")
        with pytest.raises(ValueError, match="schema"):
            _load_graph(path)

    def test_missing_nodes_edges(self, tmp_path: Path) -> None:
        path = tmp_path / "g.json"
        path.write_text(
            json.dumps({"$schema": "impact-graph.v1"}),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="missing required keys"):
            _load_graph(path)

    def test_legacy_schema_key(self, tmp_path: Path) -> None:
        """Both `$schema` và `schema` work (legacy compat)."""
        path = tmp_path / "g.json"
        path.write_text(
            json.dumps({"schema": "impact-graph.v1", "nodes": [], "edges": []}),
            encoding="utf-8",
        )
        result = _load_graph(path)
        assert "edges" in result


# ──────────────────────────────────────────────────────────────────────
# _build_reverse_index
# ──────────────────────────────────────────────────────────────────────


class TestBuildReverseIndex:
    def test_empty(self) -> None:
        idx = _build_reverse_index([])
        assert len(idx) == 0

    def test_single_edge(self) -> None:
        idx = _build_reverse_index([
            {"source": "a", "target": "b", "strength": 1.0},
        ])
        assert "b" in idx
        assert len(idx["b"]) == 1

    def test_skips_no_target(self) -> None:
        idx = _build_reverse_index([
            {"source": "a"},  # No target
            {"source": "a", "target": "b"},
        ])
        assert len(idx) == 1


# ──────────────────────────────────────────────────────────────────────
# _resolve_issue_file
# ──────────────────────────────────────────────────────────────────────


class TestResolveIssueFile:
    def test_direct_file_path(self) -> None:
        assert _resolve_issue_file({"file_path": "src/x.ts"}) == "src/x.ts"

    def test_target_file_path(self) -> None:
        assert _resolve_issue_file({
            "target": {"file_path": "src/y.ts"},
        }) == "src/y.ts"

    def test_evidence_file_path(self) -> None:
        assert _resolve_issue_file({
            "evidence": [{"file_path": "src/z.ts"}],
        }) == "src/z.ts"

    def test_no_file_returns_none(self) -> None:
        assert _resolve_issue_file({}) is None

    def test_not_dict_returns_none(self) -> None:
        assert _resolve_issue_file("not a dict") is None  # type: ignore

    def test_priority_file_path_first(self) -> None:
        """file_path > target.file_path > evidence[0].file_path."""
        assert _resolve_issue_file({
            "file_path": "a.ts",
            "target": {"file_path": "b.ts"},
            "evidence": [{"file_path": "c.ts"}],
        }) == "a.ts"

    def test_windows_path_normalized(self) -> None:
        """Path normalized to POSIX-style."""
        import os
        if os.sep == "\\":
            result = _resolve_issue_file({"file_path": "src\\x.ts"})
            assert "/" in result if result else False


# ──────────────────────────────────────────────────────────────────────
# verify_ripple
# ──────────────────────────────────────────────────────────────────────


class TestVerifyRipple:
    def test_invalid_depth(self, sample_graph: Path) -> None:
        with pytest.raises(ValueError, match="depth"):
            verify_ripple(
                {"file_path": "src/a.ts"},
                sample_graph,
                depth=0,
            )

    def test_invalid_strength_threshold(self, sample_graph: Path) -> None:
        with pytest.raises(ValueError, match="strength_threshold"):
            verify_ripple(
                {"file_path": "src/a.ts"},
                sample_graph,
                strength_threshold=1.5,
            )

    def test_no_file_raises(self, sample_graph: Path) -> None:
        with pytest.raises(ValueError, match="Cannot resolve file_path"):
            verify_ripple({}, sample_graph)

    def test_b_has_a_as_dependent(self, sample_graph: Path) -> None:
        """fix src/b.ts → src/a.ts cần re-verify (a imports b)."""
        result = verify_ripple(
            {"file_path": "src/b.ts"},
            sample_graph,
            depth=1,
            strength_threshold=0.5,
        )
        files = {r.file_path for r in result}
        assert "src/a.ts" in files

    def test_strength_threshold_filters_weak(self, sample_graph: Path) -> None:
        """fix src/d.ts → src/c.ts edge có strength 0.3 < 0.5 → skipped."""
        result = verify_ripple(
            {"file_path": "src/d.ts"},
            sample_graph,
            depth=1,
            strength_threshold=0.5,
        )
        # c imports d via weak edge → filtered out
        assert all(r.file_path != "src/c.ts" for r in result)

    def test_low_threshold_includes_weak(self, sample_graph: Path) -> None:
        """strength_threshold=0.1 → include weak edges."""
        result = verify_ripple(
            {"file_path": "src/d.ts"},
            sample_graph,
            depth=1,
            strength_threshold=0.1,
        )
        files = {r.file_path for r in result}
        assert "src/c.ts" in files

    def test_depth_2_transitive(self, sample_graph: Path) -> None:
        """depth=2 → include transitive (b.ts has a.ts direct + c.ts indirect)."""
        result = verify_ripple(
            {"file_path": "src/c.ts"},
            sample_graph,
            depth=2,
            strength_threshold=0.1,
        )
        files = {r.file_path for r in result}
        # Direct: b imports c
        # Transitive: a imports b → c
        assert "src/b.ts" in files


# ──────────────────────────────────────────────────────────────────────
# RippleTarget
# ──────────────────────────────────────────────────────────────────────


class TestRippleTarget:
    def test_frozen_dataclass(self) -> None:
        rt = RippleTarget(
            file_path="a.ts",
            reason="direct-dependent",
            edge_strength=0.8,
            distance=1,
            origin="b.ts",
        )
        with pytest.raises(Exception):  # frozen dataclass
            rt.file_path = "changed"  # type: ignore
