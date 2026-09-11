"""test_probe_executor.py — Tests cho probe_executor module (F1 + F3).

Vai trò:
    Kiểm tra probe .md parsing, grep+jq execution, agent delegation,
    signal validation (CORE-029), và CDG flagging (CORE-027).

Tham chiếu:
    - Stage F spec: docs/design/skills/wf-fix-bugs/prompts/stage-F-prompt.md §F1, §F3
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from probe_executor import (
    GREP_PATTERNS,
    SUPPORTED_TOOL_KINDS,
    execute_probe,
    parse_probe_metadata,
)


# ──────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────


@pytest.fixture
def workflow_root() -> Path:
    """Root của workflow skills."""
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def golden_project(tmp_path: Path) -> Path:
    """Tạo project mẫu với các file có known patterns."""
    src = tmp_path / "src"
    src.mkdir()

    (src / "auth.ts").write_text(
        "const api_key = 'sk-live-abc';\nconst secret = 'xyz';\n",
        encoding="utf-8",
    )
    (src / "orders.ts").write_text(
        "// REQ-ID: REQ-ORD-001\nexport class OrderService {}\n",
        encoding="utf-8",
    )
    (src / "dashboard.tsx").write_text(
        '<button className="icon-btn">X</button>\n',
        encoding="utf-8",
    )
    (src / "db.sql").write_text(
        "CREATE TABLE users (id INT);\nDROP TABLE old;\n",
        encoding="utf-8",
    )
    return tmp_path


@pytest.fixture
def tmp_session_dir(tmp_path: Path) -> Path:
    session = tmp_path / "session"
    session.mkdir(parents=True, exist_ok=True)
    return session


# ──────────────────────────────────────────────────────────────────────
# 1. TestProbeMetadataParsing
# ──────────────────────────────────────────────────────────────────────


class TestParseProbeMetadata:
    """Parse metadata từ probe .md header table."""

    def test_parse_basic_metadata(self) -> None:
        md = """# P-QD1-test-probe

| **Probe ID** | P-QD1-test-probe |
|-----------|---------|
| **Loai** | static |
| **Cache** | allowed |
"""
        meta = parse_probe_metadata(md)
        assert meta.probe_id == "P-QD1-test-probe"
        assert meta.cache_policy == "allowed"
        assert meta.is_cdg is False

    def test_parse_never_cache(self) -> None:
        md = """# P-QD3-test

| **Probe ID** | P-QD3-test |
| **Cache** | NEVER (ADR-22 Rule 6) |
"""
        meta = parse_probe_metadata(md)
        assert meta.cache_policy == "never"

    def test_parse_empty_md(self) -> None:
        meta = parse_probe_metadata("")
        assert meta.probe_id == ""
        assert meta.cache_policy == "allowed"


# ──────────────────────────────────────────────────────────────────────
# 2. TestGrepProbeExecution (F1)
# ──────────────────────────────────────────────────────────────────────


class TestGrepProbeExecution:
    """Grep+jq probe: run grep → return signals with evidence."""

    def test_secret_detection_probe(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """P-QD3-secret-detection finds hardcoded secrets."""
        probe_path = (
            workflow_root / "wf-fix-security" / "probes" / "P-QD3-secret-detection.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        assert len(signals) >= 2  # apiKey + secret
        for s in signals:
            assert "code_snippet" in s["evidence"]
            assert len(s["evidence"]["code_snippet"]) >= 10

    def test_req_registry_xref_probe(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """P-QD1-req-registry-xref finds REQ-ID annotations."""
        probe_path = (
            workflow_root / "wf-fix-functional" / "probes" / "P-QD1-req-registry-xref.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD1",
            lane="wf-fix-functional",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        assert len(signals) >= 1  # REQ-ORD-001 found
        for s in signals:
            assert s["dimension_id"] == "QD1"
            assert "code_snippet" in s["evidence"]

    def test_label_consistency_probe(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """P-QD5-label-consistency finds icon buttons without aria-label."""
        probe_path = (
            workflow_root / "wf-fix-ux-a11y" / "probes" / "P-QD5-label-consistency.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD5",
            lane="wf-fix-ux-a11y",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        assert len(signals) >= 1  # icon-btn found
        for s in signals:
            assert s["dimension_id"] == "QD5"

    def test_schema_drift_probe(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """P-QD6-schema-drift-detect finds schema patterns."""
        probe_path = (
            workflow_root / "wf-fix-data" / "probes" / "P-QD6-schema-drift-detect.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD6",
            lane="wf-fix-data",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        assert len(signals) >= 2  # CREATE TABLE + DROP TABLE

    def test_deprecated_api_probe(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """P-QD7-deprecated-api-usage finds deprecated patterns."""
        probe_path = (
            workflow_root / "wf-fix-compat" / "probes" / "P-QD7-deprecated-api-usage.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD7",
            lane="wf-fix-compat",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        # Our golden_project doesn't have Deprecated/Unversioned → may be 0
        # That's OK — the probe ran without error
        for s in signals:
            assert s["dimension_id"] == "QD7"


# ──────────────────────────────────────────────────────────────────────
# 3. TestAgentProbeExecution (F1)
# ──────────────────────────────────────────────────────────────────────


class TestAgentProbeExecution:
    """Agent probe: delegate to agent_fn or return descriptor."""

    def test_agent_probe_with_callback(
        self, tmp_session_dir: Path, workflow_root: Path, tmp_path: Path,
    ) -> None:
        """Agent probe calls agent_fn with correct subagent_type."""
        probe_path = (
            workflow_root / "wf-fix-security" / "probes" / "P-QD3-auth-flow-verify.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        called_with: list[tuple[str, dict]] = []

        def mock_agent_fn(
            agent_type: str, ctx: dict,
        ) -> list[dict[str, Any]]:
            called_with.append((agent_type, ctx))
            return [{
                "probe_id": "P-QD3-auth-flow-verify",
                "probe_version": "1.0.0",
                "emitted_at": "2026-04-21T10:00:00+00:00",
                "lane": "wf-fix-security",
                "dimension_id": "QD3",
                "target": {
                    "kind": "code",
                    "file_path": "src/auth.ts",
                    "line_range": [1, 10],
                    "symbol": "login",
                },
                "description": "Auth flow verification found potential bypass vulnerability",
                "evidence": {"code_snippet": "// const key = process.env.SECRET_KEY;"},
                "suggested_severity": "critical",
                "dedup_hints": [],
            }]

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=tmp_path,
            agent_fn=mock_agent_fn,
        )
        assert len(called_with) == 1
        assert called_with[0][0] == "security"  # From dimension.json agent field
        assert len(signals) == 1
        assert signals[0]["probe_id"] == "P-QD3-auth-flow-verify"

    def test_agent_probe_without_callback_returns_descriptor(
        self, tmp_session_dir: Path, workflow_root: Path, tmp_path: Path,
    ) -> None:
        """Agent probe without callback returns descriptor."""
        probe_path = (
            workflow_root / "wf-fix-security" / "probes" / "P-QD3-auth-flow-verify.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=tmp_path,
        )
        assert len(signals) == 1
        assert signals[0].get("_agent_descriptor") is True
        assert signals[0]["target"]["agent_type"] == "security"


# ──────────────────────────────────────────────────────────────────────
# 4. TestProbeExecutorErrors
# ──────────────────────────────────────────────────────────────────────


class TestProbeExecutorErrors:
    """Error handling: missing probe, invalid output."""

    def test_missing_probe_raises(
        self, tmp_session_dir: Path, workflow_root: Path, tmp_path: Path,
    ) -> None:
        with pytest.raises(FileNotFoundError, match="không tồn tại"):
            execute_probe(
                probe_config_path=Path("/nonexistent/probe.md"),
                dimension="QD1",
                lane="wf-fix-functional",
                session_dir=tmp_session_dir,
                workflow_root=workflow_root,
                project_root=tmp_path,
            )


# ──────────────────────────────────────────────────────────────────────
# 5. TestSignalValidation (F3)
# ──────────────────────────────────────────────────────────────────────


class TestSignalValidation:
    """CORE-029: all signals pass Signal.from_dict() + validate_evidence."""

    def test_grep_signals_pass_validation(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Grep probe output passes Signal.from_dict validation."""
        from signal_bus.signal_bus import Signal, validate_evidence

        probe_path = (
            workflow_root / "wf-fix-security" / "probes" / "P-QD3-secret-detection.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        for s in signals:
            sig = Signal.from_dict(s)
            ok, err = validate_evidence(sig)
            assert ok, f"Signal {s['probe_id']} failed evidence validation: {err}"

    def test_cdg_probe_flagged(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """CORE-027: P-QD3-secret-detection signals flagged with cdg_required."""
        probe_path = (
            workflow_root / "wf-fix-security" / "probes" / "P-QD3-secret-detection.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD3",
            lane="wf-fix-security",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        assert len(signals) > 0
        for s in signals:
            assert s.get("cdg_required") is True  # CORE-027

    def test_non_cdg_probe_not_flagged(
        self, golden_project: Path, tmp_session_dir: Path, workflow_root: Path,
    ) -> None:
        """Non-CDG probe signals don't have cdg_required."""
        probe_path = (
            workflow_root / "wf-fix-functional" / "probes" / "P-QD1-req-registry-xref.md"
        )
        if not probe_path.exists():
            pytest.skip("Probe .md not found")

        signals = execute_probe(
            probe_config_path=probe_path,
            dimension="QD1",
            lane="wf-fix-functional",
            session_dir=tmp_session_dir,
            workflow_root=workflow_root,
            project_root=golden_project,
        )
        for s in signals:
            assert "cdg_required" not in s or s.get("cdg_required") is False

    def test_all_grep_patterns_have_valid_probes(
        self, workflow_root: Path,
    ) -> None:
        """Every probe_id in GREP_PATTERNS has a corresponding dimension.json entry."""
        for probe_id in GREP_PATTERNS:
            dim = probe_id.split("-")[1]  # P-QD1-... → QD1
            lane_path = Path(__file__).resolve().parent.parent.parent
            # Map dimension to lane directory
            dim_map = {
                "QD1": "wf-fix-functional", "QD2": "wf-fix-business",
                "QD3": "wf-fix-security", "QD4": "wf-fix-performance",
                "QD5": "wf-fix-ux-a11y", "QD6": "wf-fix-data",
                "QD7": "wf-fix-compat", "QD8": "wf-fix-observability",
            }
            lane_name = dim_map.get(dim)
            if not lane_name:
                continue
            probe_md = lane_path / lane_name / "procedures" / "probes" / f"{probe_id}.md"
            assert probe_md.exists(), f"Probe .md missing for {probe_id}"

    def test_supported_tool_kinds_complete(self) -> None:
        """SUPPORTED_TOOL_KINDS includes all tool kinds used in dimension.json."""
        assert "grep+jq" in SUPPORTED_TOOL_KINDS
        assert "bash+jq" in SUPPORTED_TOOL_KINDS
        assert "bash+curl" in SUPPORTED_TOOL_KINDS
        assert "agent" in SUPPORTED_TOOL_KINDS
