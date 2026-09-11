"""signal_parser — Parse + validate LLM agent output (Phase C v8).

Validate signals theo lane-signals-v1 schema. Drop hallucinated signals:
- File path khong ton tai
- Line number > file line count
- Confidence < threshold → auto-downgrade severity
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Min description length cho IMP-008 alignment.
MIN_DESCRIPTION_LEN = 50
# Confidence threshold — duoi muc nay → severity=info.
LOW_CONFIDENCE_THRESHOLD = 0.5
# Allowed severities theo signal-v2 schema.
ALLOWED_SEVERITIES = {"critical", "high", "medium", "low", "info", "warn"}


def _extract_balanced(text: str, open_ch: str, close_ch: str) -> Optional[str]:
    """Extract first balanced bracket-pair (handling nested + string escapes)."""
    start = text.find(open_ch)
    while start != -1:
        depth = 0
        in_string = False
        escape = False
        for i in range(start, len(text)):
            ch = text[i]
            if escape:
                escape = False
                continue
            if ch == "\\":
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
                if depth == 0:
                    candidate = text[start : i + 1]
                    try:
                        json.loads(candidate)
                        return candidate
                    except json.JSONDecodeError:
                        break
        start = text.find(open_ch, start + 1)
    return None


def _extract_json_blob(text: str) -> Optional[str]:
    """Extract first valid JSON object/array from text. Handle agent output verbosity.

    Strategy:
    0. Whole-text parse — agent returned pure JSON.
    1. Fenced code block ```json ... ``` (multi-line)
    2. Whichever bracket appears first in text: { ... } object or [ ... ] array
    """
    # 0. Try whole text as JSON first.
    stripped = text.strip()
    if stripped:
        try:
            json.loads(stripped)
            return stripped
        except json.JSONDecodeError:
            pass

    # 1. Try fenced code block ```json ... ``` (greedy across newlines).
    for match in re.finditer(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL):
        candidate = match.group(1).strip()
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            continue

    # 2. Pick whichever bracket appears earlier in text.
    obj_pos = text.find("{")
    arr_pos = text.find("[")
    if obj_pos == -1 and arr_pos == -1:
        return None
    # Pick the earlier one (or whichever is non-negative)
    if obj_pos != -1 and (arr_pos == -1 or obj_pos < arr_pos):
        first = ("{", "}")
        second = ("[", "]")
    else:
        first = ("[", "]")
        second = ("{", "}")
    extracted = _extract_balanced(text, first[0], first[1])
    if extracted is not None:
        return extracted
    return _extract_balanced(text, second[0], second[1])


def _file_exists(file_path: str, source_dir: Path) -> bool:
    """Check if file exists relative to source_dir or absolute."""
    if not file_path or file_path == "N/A":
        return True  # Allow N/A for non-file findings (e.g., system-level)
    abs_path = (source_dir / file_path) if not Path(file_path).is_absolute() else Path(file_path)
    return abs_path.is_file()


def _count_file_lines(file_path: str, source_dir: Path) -> int:
    """Count lines in file. Returns 0 if missing."""
    abs_path = (source_dir / file_path) if not Path(file_path).is_absolute() else Path(file_path)
    if not abs_path.is_file():
        return 0
    try:
        with abs_path.open("r", encoding="utf-8", errors="ignore") as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def _compute_fingerprint(signal: Dict[str, Any]) -> str:
    """Recompute fingerprint canonical: dim|file|line|probe|title."""
    dim = signal.get("dimension_id", "QD0")
    file = (signal.get("location") or {}).get("file", "N/A")
    line = (signal.get("location") or {}).get("line", 0)
    probe = signal.get("probe_id", "P-LLM")
    title = signal.get("title", "")
    raw = f"{dim}|{file}|{line}|{probe}|{title}"
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def validate_signal(
    signal: Dict[str, Any],
    *,
    source_dir: Path,
    probe_id: str,
    lane: str,
    dimension: str,
    confidence: Optional[float] = None,
) -> Tuple[bool, str, Dict[str, Any]]:
    """Validate + normalize 1 signal.

    Returns:
        (valid, reason, normalized_signal). reason="" if valid.
        Sửa các fields còn thiếu (probe_id, lane, fingerprint, schema).
    """
    if not isinstance(signal, dict):
        return False, "signal must be dict", {}

    # Required fields
    title = signal.get("title", "").strip()
    description = signal.get("description", "").strip()
    severity = signal.get("severity", "").strip().lower()

    if not title:
        return False, "missing title", {}
    if len(description) < MIN_DESCRIPTION_LEN:
        return False, f"description too short ({len(description)} < {MIN_DESCRIPTION_LEN})", {}
    if severity not in ALLOWED_SEVERITIES:
        return False, f"invalid severity: {severity}", {}

    # Normalize location
    location = signal.get("location") or {}
    if not isinstance(location, dict):
        return False, "location must be dict", {}
    file_path = location.get("file", "N/A")
    line_no = location.get("line", 0) or 0

    # File existence check
    if file_path and file_path != "N/A":
        if not _file_exists(file_path, source_dir):
            return False, f"file does not exist: {file_path}", {}
        # Line bounds check
        if line_no > 0:
            line_count = _count_file_lines(file_path, source_dir)
            if line_count > 0 and line_no > line_count:
                return False, f"line {line_no} exceeds file line count {line_count}", {}

    # Confidence threshold — auto-downgrade
    if confidence is not None and confidence < LOW_CONFIDENCE_THRESHOLD:
        severity = "info"

    # Build normalized signal
    # Fix F3 (signal_aggregator compatibility): include detected_at + detected_by per signal-v2 schema
    # so signal_aggregator does not silent-drop LLM signals (Signal.from_dict requires emitted_at→detected_at).
    detected_at_iso = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    normalized = {
        "$schema": "signal-v2",
        "dimension_id": dimension,
        "probe_id": probe_id,
        "probe_version": signal.get("probe_version", "v1.0-llm"),
        "severity": severity,
        "fixability": signal.get("fixability", "agent_fix"),
        "domain": signal.get("domain", "general"),
        "title": title,
        "description": description,
        "location": {
            "file": file_path,
            "line": int(line_no),
            "column": location.get("column"),
            "selector": location.get("selector"),
            "url": location.get("url"),
        },
        "evidence": signal.get("evidence") or {
            "code_snippet": None, "test_failure": None, "screenshot": None,
            "related_signals": [], "reproduction_steps": None,
        },
        "remediation": signal.get("remediation") or {
            "suggested_action": "Review LLM finding and verify",
            "test_recommendation": None, "references": [], "estimated_effort_min": 10,
        },
        "cdg_flags": signal.get("cdg_flags", []),
        "fingerprint": "",  # filled below
        "detected_at": detected_at_iso,
        "detected_by": f"{lane}/{probe_id}",
        "probe_metadata": {"lane": lane, "generated_at": signal.get("probe_metadata", {}).get("generated_at", "")},
    }
    normalized["fingerprint"] = _compute_fingerprint(normalized)
    return True, "", normalized


def parse_signals(
    raw_text: str,
    *,
    source_dir: Path,
    probe_id: str,
    lane: str,
    dimension: str,
    max_signals: int = 0,
    static_fingerprints: Optional[set[str]] = None,
) -> Tuple[List[Dict[str, Any]], dict]:
    """Parse agent output text → validated signals list.

    Args:
        raw_text: agent output (may contain extra prose around JSON).
        source_dir: repo root for path validation.
        probe_id, lane, dimension: contract fields.
        max_signals: cap (truncate beyond). 0 = unlimited (quality-first default).
        static_fingerprints: skip signals with these fingerprints (dedup vs static).

    Returns:
        (valid_signals, metadata) — metadata includes counts dropped.
    """
    static_fingerprints = static_fingerprints or set()
    metadata = {
        "raw_signals": 0,
        "validated_signals": 0,
        "dropped_no_json": 0,
        "dropped_invalid": 0,
        "dropped_duplicate": 0,
        "dropped_max_cap": 0,
        "drop_reasons": [],
    }

    # 1. Extract JSON blob
    blob = _extract_json_blob(raw_text)
    if not blob:
        metadata["dropped_no_json"] = 1
        return [], metadata

    try:
        data = json.loads(blob)
    except json.JSONDecodeError:
        metadata["dropped_no_json"] = 1
        return [], metadata

    # 2. Find signals[] — allow various wrapper shapes
    if isinstance(data, list):
        raw_signals = data
    elif isinstance(data, dict):
        raw_signals = data.get("signals", [])
        if not isinstance(raw_signals, list):
            raw_signals = []
    else:
        raw_signals = []

    metadata["raw_signals"] = len(raw_signals)

    # 3. Validate each signal
    valid: List[Dict[str, Any]] = []
    seen_fingerprints: set[str] = set()
    for sig in raw_signals:
        confidence = None
        if isinstance(sig, dict):
            confidence = (sig.get("evidence") or {}).get("confidence")
            if confidence is None:
                confidence = sig.get("confidence")
            try:
                confidence = float(confidence) if confidence is not None else None
            except (TypeError, ValueError):
                confidence = None

        ok, reason, normalized = validate_signal(
            sig, source_dir=source_dir, probe_id=probe_id,
            lane=lane, dimension=dimension, confidence=confidence,
        )
        if not ok:
            metadata["dropped_invalid"] += 1
            metadata["drop_reasons"].append(reason)
            continue

        fp = normalized["fingerprint"]
        if fp in static_fingerprints:
            metadata["dropped_duplicate"] += 1
            continue
        if fp in seen_fingerprints:
            metadata["dropped_duplicate"] += 1
            continue
        seen_fingerprints.add(fp)
        valid.append(normalized)

        if max_signals > 0 and len(valid) >= max_signals:
            metadata["dropped_max_cap"] = len(raw_signals) - len(valid)
            break

    metadata["validated_signals"] = len(valid)
    return valid, metadata
