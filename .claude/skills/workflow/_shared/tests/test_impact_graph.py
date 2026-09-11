"""test_impact_graph.py — Unit tests cho _shared/impact_graph.

Scope:
    - ``ripple.verify_ripple()`` — ADR-22 rule 2 (depth=1, strength>=0.5)
    - ``builder.build()`` — smoke test tren repo fixture nho
    - CLI entry point ``python -m _shared.impact_graph.ripple verify``
    - Edge cases: graph rong, schema sai, file khong ton tai, issue thieu file_path

Run:
    cd .claude/skills/workflow/_shared
    pytest tests/test_impact_graph.py -v
"""
from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import asdict
from pathlib import Path

import pytest

from _shared.impact_graph import builder
from _shared.impact_graph.ripple import (
    DEFAULT_DEPTH,
    DEFAULT_STRENGTH,
    RippleTarget,
    verify_ripple,
)


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def graph_fixture(tmp_path: Path) -> Path:
    """Impact graph 5 nodes / 4 edges — 1 origin (auth.py), 4 potential dependents.

    Layout:
      src/api.py -----(0.7)---> src/auth.py  (dependent — PASS)
      src/service.py (0.7)----> src/auth.py  (dependent — PASS)
      tests/test_auth.py (0.5)-> src/auth.py  (dependent — PASS, exactly threshold)
      src/utils.py --(0.3)----> src/auth.py  (filtered — below threshold)
    """
    graph = {
        "$schema": "impact-graph.v1",
        "generated_at": "2026-04-20T00:00:00Z",
        "nodes": [
            {"id": "src/auth.py", "type": "file"},
            {"id": "src/api.py", "type": "file"},
            {"id": "src/service.py", "type": "file"},
            {"id": "tests/test_auth.py", "type": "file"},
            {"id": "src/utils.py", "type": "file"},
        ],
        "edges": [
            {"source": "src/api.py", "target": "src/auth.py", "strength": 0.7},
            {"source": "src/service.py", "target": "src/auth.py", "strength": 0.7},
            {"source": "tests/test_auth.py", "target": "src/auth.py", "strength": 0.5},
            {"source": "src/utils.py", "target": "src/auth.py", "strength": 0.3},
        ],
    }
    path = tmp_path / "impact-graph.json"
    path.write_text(json.dumps(graph), encoding="utf-8")
    return path


@pytest.fixture
def empty_graph(tmp_path: Path) -> Path:
    """Graph hop le nhung khong co edges → verify_ripple tra ve [] (graceful)."""
    graph = {"$schema": "impact-graph.v1", "nodes": [], "edges": []}
    path = tmp_path / "empty-graph.json"
    path.write_text(json.dumps(graph), encoding="utf-8")
    return path


@pytest.fixture
def bad_schema_graph(tmp_path: Path) -> Path:
    """Graph voi schema id sai → verify_ripple raise ValueError."""
    graph = {"$schema": "impact-graph.v999", "nodes": [], "edges": []}
    path = tmp_path / "bad-schema.json"
    path.write_text(json.dumps(graph), encoding="utf-8")
    return path


# ──────────────────────────────────────────────────────────────────────
# Core API — verify_ripple
# ──────────────────────────────────────────────────────────────────────


class TestVerifyRipple:
    """ADR-22 rule 2 — depth=1, strength>=0.5."""

    def test_default_constants(self):
        """Defaults phai khop ADR-22 rule 2 — khong duoc im lang thay doi."""
        assert DEFAULT_DEPTH == 1
        assert DEFAULT_STRENGTH == 0.5

    def test_returns_direct_dependents_above_threshold(self, graph_fixture):
        """3 dependents strength>=0.5; utils.py (0.3) bi loai."""
        targets = verify_ripple(
            issue={"id": "T1", "file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
            depth=1,
            strength_threshold=0.5,
        )
        file_paths = {t.file_path for t in targets}
        assert file_paths == {
            "src/api.py",
            "src/service.py",
            "tests/test_auth.py",
        }
        assert "src/utils.py" not in file_paths

    def test_all_results_are_direct_dependents(self, graph_fixture):
        """Depth=1 → tat ca ripple la direct-dependent, distance=1."""
        targets = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
        )
        assert all(t.distance == 1 for t in targets)
        assert all(t.reason == "direct-dependent" for t in targets)
        assert all(t.edge_strength >= 0.5 for t in targets)

    def test_origin_preserved_in_result(self, graph_fixture):
        """Moi RippleTarget phai giu origin = issue.file_path."""
        targets = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
        )
        assert all(t.origin == "src/auth.py" for t in targets)

    def test_issue_without_file_path_raises(self, graph_fixture):
        """Issue thieu file_path va evidence → raise ValueError."""
        with pytest.raises(ValueError, match="Cannot resolve file_path"):
            verify_ripple(
                issue={"id": "NO-FILE"},
                impact_graph_path=graph_fixture,
            )

    def test_issue_resolves_from_target_field(self, graph_fixture):
        """Issue co target.file_path thay vi top-level file_path → van resolve duoc."""
        targets = verify_ripple(
            issue={"target": {"file_path": "src/auth.py"}},
            impact_graph_path=graph_fixture,
        )
        assert len(targets) == 3

    def test_issue_resolves_from_evidence_field(self, graph_fixture):
        """Issue co evidence[0].file_path (Signal v2) → resolve fallback cuoi cung."""
        targets = verify_ripple(
            issue={"evidence": [{"file_path": "src/auth.py"}]},
            impact_graph_path=graph_fixture,
        )
        assert len(targets) == 3

    def test_invalid_depth_raises(self, graph_fixture):
        """Depth < 1 → ValueError."""
        with pytest.raises(ValueError, match="depth must be >= 1"):
            verify_ripple(
                issue={"file_path": "src/auth.py"},
                impact_graph_path=graph_fixture,
                depth=0,
            )

    @pytest.mark.parametrize("bad_strength", [-0.1, 1.01, 2.0])
    def test_invalid_strength_raises(self, graph_fixture, bad_strength):
        """Strength out of [0.0, 1.0] → ValueError."""
        with pytest.raises(ValueError, match="strength_threshold"):
            verify_ripple(
                issue={"file_path": "src/auth.py"},
                impact_graph_path=graph_fixture,
                strength_threshold=bad_strength,
            )

    def test_missing_graph_file_raises(self, tmp_path):
        """Graph path khong ton tai → FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            verify_ripple(
                issue={"file_path": "src/x.py"},
                impact_graph_path=tmp_path / "does-not-exist.json",
            )

    def test_bad_schema_raises(self, bad_schema_graph):
        """Schema id sai → ValueError."""
        with pytest.raises(ValueError, match="Incompatible impact-graph schema"):
            verify_ripple(
                issue={"file_path": "src/x.py"},
                impact_graph_path=bad_schema_graph,
            )

    def test_empty_graph_returns_empty(self, empty_graph):
        """Graph khong co edges → tra ve [] (graceful, khong raise)."""
        targets = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=empty_graph,
        )
        assert targets == []

    def test_strict_threshold_excludes_edge_exactly_at(self, graph_fixture):
        """Strength=0.5 phai >= threshold → INCLUDED khi threshold=0.5."""
        targets_incl = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
            strength_threshold=0.5,
        )
        assert "tests/test_auth.py" in {t.file_path for t in targets_incl}

        # Threshold 0.51 → loai test_auth.py (0.5 < 0.51)
        targets_excl = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
            strength_threshold=0.51,
        )
        assert "tests/test_auth.py" not in {t.file_path for t in targets_excl}

    def test_deterministic_ordering(self, graph_fixture):
        """Output sort theo (distance, -strength, file_path) → ordering on dinh."""
        r1 = verify_ripple(issue={"file_path": "src/auth.py"}, impact_graph_path=graph_fixture)
        r2 = verify_ripple(issue={"file_path": "src/auth.py"}, impact_graph_path=graph_fixture)
        assert [t.file_path for t in r1] == [t.file_path for t in r2]

    def test_no_self_ripple(self, graph_fixture):
        """Origin khong duoc xuat hien trong ripple targets (self-loop skip)."""
        targets = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
        )
        assert "src/auth.py" not in {t.file_path for t in targets}

    def test_ripple_target_is_serializable(self, graph_fixture):
        """RippleTarget phai serializable qua asdict() → JSON-safe."""
        targets = verify_ripple(
            issue={"file_path": "src/auth.py"},
            impact_graph_path=graph_fixture,
        )
        payload = json.dumps({"targets": [asdict(t) for t in targets]})
        parsed = json.loads(payload)
        assert parsed["targets"][0].keys() == {
            "file_path", "reason", "edge_strength", "distance", "origin"
        }


# ──────────────────────────────────────────────────────────────────────
# CLI entry point — python -m _shared.impact_graph.ripple verify
# ──────────────────────────────────────────────────────────────────────


class TestRippleCLI:
    """CLI fallback cho wf-fix-execute Phase 5 §Verify Ripple."""

    def test_cli_verify_returns_same_targets(self, graph_fixture, tmp_path):
        issue_path = tmp_path / "issue.json"
        issue_path.write_text(json.dumps({"id": "T", "file_path": "src/auth.py"}))

        result = subprocess.run(
            [
                sys.executable, "-m", "_shared.impact_graph.ripple", "verify",
                "--issue", str(issue_path),
                "--graph", str(graph_fixture),
                "--depth", "1",
                "--strength", "0.5",
            ],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,  # .claude/skills/workflow
        )
        assert result.returncode == 0, f"CLI failed: {result.stderr}"
        payload = json.loads(result.stdout)
        assert payload["origin"] == "src/auth.py"
        assert payload["target_count"] == 3
        assert {t["file_path"] for t in payload["targets"]} == {
            "src/api.py", "src/service.py", "tests/test_auth.py"
        }

    def test_cli_missing_issue_file(self, graph_fixture, tmp_path):
        result = subprocess.run(
            [
                sys.executable, "-m", "_shared.impact_graph.ripple", "verify",
                "--issue", str(tmp_path / "missing.json"),
                "--graph", str(graph_fixture),
            ],
            capture_output=True, text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 2
        assert "issue file not found" in result.stderr.lower()


# ──────────────────────────────────────────────────────────────────────
# Builder — smoke test
# ──────────────────────────────────────────────────────────────────────


class TestBuilderSmoke:
    """Chi test builder.build() khong crash voi repo nho — de tim regression."""

    def test_build_empty_repo(self, tmp_path):
        """Repo khong co file → graph co 0 nodes, 0 edges nhung van valid schema."""
        graph = builder.build(repo_root=tmp_path)
        assert graph.schema == "impact-graph.v1"
        assert graph.nodes == []
        assert graph.edges == []

    def test_build_single_python_file(self, tmp_path):
        """1 file Python → 1 node, lang detect thanh cong (builder dung 'py' short-form)."""
        (tmp_path / "a.py").write_text("print('hello')\n")
        graph = builder.build(repo_root=tmp_path)
        assert len(graph.nodes) == 1
        assert graph.nodes[0].id == "a.py"
        # Builder dung lang="py" (short) thay vi "python" — match convention trong schema
        assert graph.nodes[0].lang in ("py", "python")

    def test_build_respects_max_files_limit(self, tmp_path):
        """max_files=1 → scan stop sau 1 file."""
        for i in range(5):
            (tmp_path / f"f{i}.py").write_text("x=1\n")
        graph = builder.build(repo_root=tmp_path, max_files=1)
        assert len(graph.nodes) <= 1

    def test_build_output_serializable(self, tmp_path):
        """Graph serializable qua asdict → JSON roundtrip sach."""
        (tmp_path / "a.py").write_text("x = 1\n")
        graph = builder.build(repo_root=tmp_path)
        payload = json.dumps(asdict(graph))
        parsed = json.loads(payload)
        assert parsed["schema"] == "impact-graph.v1"
