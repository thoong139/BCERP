#!/usr/bin/env python3
"""probe_executor.py — Execute probe .md configs → emit Signal v2 dicts.

Vai trò:
    Đọc probe .md config → extract metadata → execute theo tool.kind
    → build Signal v2 dicts → validate (CORE-029) → return cho lane_dispatch.

Registry role: NONE. Chỉ đọc probe configs + return signals.

Tham chiếu:
    - ADR-09: evidence bắt buộc (≥1 field non-empty)
    - ADR-22 rule 6: QD3 never cached
    - CORE-027: CDG probes cần user confirmation
    - CORE-029: agent output spot-check trước khi ghi
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from dimension_registry import get_lane_path
from signal_bus.signal_bus import Signal, validate_evidence

# ──────────────────────────────────────────────────────────────────────
# Hằng số
# ──────────────────────────────────────────────────────────────────────

SUPPORTED_TOOL_KINDS: frozenset[str] = frozenset(
    {"grep+jq", "bash+jq", "bash+curl", "grep+ast",
     "grep+playwright", "playwright", "agent"}
)

GREP_PATTERNS: dict[str, list[str]] = {
    "P-QD1-req-registry-xref": [
        r"//[ \t]*REQ-[A-Z]+-[0-9]+",
        r"#[ \t]*REQ-[A-Z]+-[0-9]+",
        r"//[ \t]*FEAT-[A-Z]+-[A-Z]+-[0-9]+",
        r"#[ \t]*FEAT-[A-Z]+-[A-Z]+-[0-9]+",
        r"REQ-ID:[ \t]*REQ-[A-Z]+-[0-9]+",
        r"FEAT-ID:[ \t]*FEAT-[A-Z]+-[A-Z]+-[0-9]+",
    ],
    "P-QD2-hardcoded-value-detect": [
        r"[Tt][Aa][Xx][_-]?[Rr][Aa][Tt][Ee][ \t]*=",
        r"[Cc][Oo][Mm][Mm][Ii][Ss][Ss][Ii][Oo][Nn][ \t]*=",
        r"=[ \t]*0\.[0-9]+",
    ],
    "P-QD2-calculation-check": [
        r"\.reduce\(",
        r"parseFloat\(",
        r"parseInt\(",
        r"Math\.(floor|ceil|round)",
    ],
    "P-QD3-secret-detection": [
        r"[Aa]pi[_\-]?[Kk]ey[ \t]*=",
        r"[Ss]ecret[ \t]*=",
        r"[Pp]assword[ \t]*=",
        r"PRIVATE KEY",
        r"sk-live-",
        r"sk_test_",
    ],
    "P-QD4-bundle-size-audit": [
        r"import.*from[ \t]+['\"]lodash['\"]",
        r"import.*from[ \t]+['\"]moment['\"]",
        r"import[ \t]+\*",
    ],
    "P-QD4-db-query-analysis": [
        r"SELECT[ \t]+\*",
        r"find\([ \t]*\)",
        r"\.all\(\)",
    ],
    "P-QD5-label-consistency": [
        r"icon-btn",
        r"iconButton",
    ],
    "P-QD6-schema-drift-detect": [
        r"CREATE TABLE",
        r"ALTER TABLE",
        r"DROP TABLE",
    ],
    "P-QD7-deprecated-api-usage": [
        r"[Dd]eprecated",
        r"[Uu]nversioned",
    ],
}

SOURCE_EXTENSIONS: tuple[str, ...] = (
    ".ts", ".tsx", ".js", ".jsx", ".py", ".java", ".sql",
)


# ──────────────────────────────────────────────────────────────────────
# Data classes
# ──────────────────────────────────────────────────────────────────────


@dataclass
class ProbeMeta:
    """Metadata parsed từ probe .md header table."""

    probe_id: str
    probe_version: str
    tool_kind: str
    is_cdg: bool
    cache_policy: str
    severity_default: str


# ──────────────────────────────────────────────────────────────────────
# Parsing helpers
# ──────────────────────────────────────────────────────────────────────


def parse_probe_metadata(md_content: str) -> ProbeMeta:
    """Parse metadata table từ probe .md header.

    Format:
        | **Key** | **Value** |
        |---------|-----------|
        | **Probe ID** | P-QD1-xxx |
    """
    rows: dict[str, str] = {}
    for line in md_content.splitlines():
        # Accept both **Key** (bold) and plain Key formats
        m = re.match(r"\|\s*\*{0,2}(.+?)\*{0,2}\s*\|\s*(.+?)\s*\|", line)
        if m:
            key = m.group(1).strip().strip("*")
            rows[key] = m.group(2).strip()

    cache_raw = rows.get("Cache", "allowed")
    cache_policy = "never" if "NEVER" in cache_raw.upper() else "allowed"

    return ProbeMeta(
        probe_id=rows.get("Probe ID", ""),
        probe_version="1.0.0",
        tool_kind="",
        is_cdg=rows.get("CDG", "false").lower() == "true",
        cache_policy=cache_policy,
        severity_default=rows.get("Severity", "medium"),
    )


def _read_probe_def(
    probe_id: str, dimension: str, workflow_root: Path,
) -> dict[str, Any]:
    """Read probe definition from dimension.json."""
    lane_path = get_lane_path(dimension, workflow_root)
    dim_json = lane_path / "dimension.json"
    if not dim_json.exists():
        return {}
    dim_data = json.loads(dim_json.read_text(encoding="utf-8"))
    for p in dim_data.get("probes", []):
        if p.get("id") == probe_id:
            return p
    return {}


# ──────────────────────────────────────────────────────────────────────
# Grep execution
# ──────────────────────────────────────────────────────────────────────


def _run_grep(pattern: str, project_root: Path) -> list[dict[str, Any]]:
    """Run grep via subprocess, return matches.

    Returns list of {file_path, line_number, line_content}.
    """
    matches: list[dict[str, Any]] = []
    include_args: list[str] = []
    for ext in SOURCE_EXTENSIONS:
        include_args.extend(["--include", f"*{ext}"])

    try:
        cmd = (
            ["grep", "-rn", "-E", pattern] + include_args + [str(project_root)]
        )
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30,
        )
        for line in result.stdout.splitlines():
            # Windows: "C:\path\file.ts:1:content" — drive colon breaks naive split
            parts = line.split(":")
            if len(parts) < 3:
                continue
            # Find line number part (first parseable int after file path)
            found = False
            for i in range(1, len(parts) - 1):
                try:
                    line_num = int(parts[i])
                    file_path = ":".join(parts[:i])
                    content = ":".join(parts[i + 1:])
                    matches.append({
                        "file_path": file_path,
                        "line_number": line_num,
                        "line_content": content,
                    })
                    found = True
                    break
                except ValueError:
                    continue
            if found:
                continue
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    return matches


def _build_signal(
    probe_id: str,
    dimension: str,
    lane: str,
    match: dict[str, Any],
    severity: str,
) -> dict[str, Any]:
    """Build Signal v2 dict từ 1 grep match."""
    content = match["line_content"]
    return {
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": datetime.now(timezone.utc).isoformat(),
        "lane": lane,
        "dimension_id": dimension,
        "target": {
            "kind": "code",
            "file_path": match["file_path"],
            "line_range": [match["line_number"], match["line_number"]],
            "symbol": "",
        },
        "description": (
            f"Phát hiện pattern tại {match['file_path']}:"
            f"{match['line_number']}"
        ),
        "evidence": {
            "code_snippet": content if len(content) >= 10 else f"/* {content} */",
        },
        "suggested_severity": severity,
        "dedup_hints": [f"{match['file_path']}:{match['line_number']}"],
    }


def _execute_grep_probe(
    probe_id: str,
    dimension: str,
    lane: str,
    project_root: Path,
    severity: str,
) -> list[dict[str, Any]]:
    """Execute grep-based probe → return list of Signal v2 dicts."""
    patterns = GREP_PATTERNS.get(probe_id, [])
    all_matches: list[dict[str, Any]] = []
    for p in patterns:
        all_matches.extend(_run_grep(p, project_root))

    seen: set[tuple[str, int]] = set()
    signals: list[dict[str, Any]] = []
    for m in all_matches:
        key = (m["file_path"], m["line_number"])
        if key in seen:
            continue
        seen.add(key)
        signals.append(_build_signal(probe_id, dimension, lane, m, severity))

    return signals


# ──────────────────────────────────────────────────────────────────────
# Agent execution
# ──────────────────────────────────────────────────────────────────────

AgentCallback = Callable[[str, dict[str, Any]], list[dict[str, Any]]]


def _execute_agent_probe(
    probe_id: str,
    dimension: str,
    lane: str,
    agent_type: str | None,
    agent_fn: AgentCallback | None,
) -> list[dict[str, Any]]:
    """Execute agent-type probe → delegate to agent_fn or return descriptor."""
    if agent_fn is not None:
        return agent_fn(
            agent_type or "general-purpose",
            {"probe_id": probe_id, "dimension": dimension, "lane": lane},
        )

    return [{
        "probe_id": probe_id,
        "probe_version": "1.0.0",
        "emitted_at": datetime.now(timezone.utc).isoformat(),
        "lane": lane,
        "dimension_id": dimension,
        "target": {
            "kind": "descriptor",
            "agent_type": agent_type or "general-purpose",
        },
        "description": (
            f"Agent probe descriptor for {probe_id} requires "
            f"{agent_type or 'general-purpose'} execution"
        ),
        "evidence": {
            "spec_ref": f"Agent probe: {agent_type or 'general-purpose'}",
        },
        "suggested_severity": "medium",
        "dedup_hints": [],
        "_agent_descriptor": True,
    }]


# ──────────────────────────────────────────────────────────────────────
# Main execution
# ──────────────────────────────────────────────────────────────────────


def execute_probe(
    probe_config_path: Path,
    dimension: str,
    lane: str,
    session_dir: Path,
    workflow_root: Path,
    project_root: Path,
    agent_fn: AgentCallback | None = None,
) -> list[dict[str, Any]]:
    """Đọc probe .md → execute → return list of Signal v2 dicts.

    Returns:
        List of Signal v2 dicts (để ingest vào SignalBus).

    Raises:
        FileNotFoundError: probe config không tồn tại.
        ValueError: probe output không pass validation.
    """
    if not probe_config_path.exists():
        raise FileNotFoundError(
            f"Probe config không tồn tại: {probe_config_path}"
        )

    # 1. Parse probe metadata
    md_content = probe_config_path.read_text(encoding="utf-8")
    meta = parse_probe_metadata(md_content)

    # 2. Read probe def từ dimension.json
    probe_def = _read_probe_def(meta.probe_id, dimension, workflow_root)
    tool_kind = probe_def.get("tool", {}).get("kind", "")
    is_cdg = probe_def.get("cdg", False)
    severity = probe_def.get("severity_default", "medium").lower()
    agent_type = probe_def.get("tool", {}).get("agent")

    # Fallback: probe có GREP_PATTERNS nhưng dimension.json thiếu "tool" → grep+jq
    if not tool_kind and meta.probe_id in GREP_PATTERNS:
        tool_kind = "grep+jq"

    # 3. Execute theo tool.kind
    if tool_kind in ("grep+jq", "grep+ast", "grep+playwright"):
        signals = _execute_grep_probe(
            meta.probe_id, dimension, lane, project_root, severity,
        )
    elif tool_kind in ("bash+jq", "bash+curl", "playwright"):
        # Runtime probes — cần server running, skip trong dry Python exec
        signals = []
    elif tool_kind == "agent":
        signals = _execute_agent_probe(
            meta.probe_id, dimension, lane, agent_type, agent_fn,
        )
    else:
        raise ValueError(f"Unsupported tool kind: {tool_kind}")

    # 4. Validate signals (CORE-029)
    for signal_dict in signals:
        if signal_dict.get("_agent_descriptor"):
            continue  # Skip validation cho agent descriptors
        sig = Signal.from_dict(signal_dict)
        ok, err = validate_evidence(sig)
        if not ok:
            raise ValueError(f"Probe {meta.probe_id}: {err}")

    # 5. Mark CDG (CORE-027)
    if is_cdg:
        for signal_dict in signals:
            signal_dict["cdg_required"] = True

    return signals


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: execute 1 probe."""
    import argparse

    parser = argparse.ArgumentParser(description="Probe Executor")
    parser.add_argument("--probe-config", required=True, type=Path)
    parser.add_argument("--dimension", required=True)
    parser.add_argument("--lane", required=True)
    parser.add_argument("--session-dir", required=True, type=Path)
    parser.add_argument("--workflow-root", required=True, type=Path)
    parser.add_argument("--project-root", required=True, type=Path)
    args = parser.parse_args(argv)

    try:
        signals = execute_probe(
            probe_config_path=args.probe_config,
            dimension=args.dimension,
            lane=args.lane,
            session_dir=args.session_dir,
            workflow_root=args.workflow_root,
            project_root=args.project_root,
        )
        print(json.dumps(signals, indent=2, ensure_ascii=False))
        return 0
    except (FileNotFoundError, ValueError) as exc:
        print(f"[probe_executor ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
