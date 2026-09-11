#!/usr/bin/env python3
# wf-fix-lane-to-bus.py — Lane signal → Bus signal schema translator
#
# IMP-022: Translates lane bash output (signal-v2 + location/evidence array)
# to bus input schema (suggested_severity, target, evidence dict, dedup_hints).
#
# Root cause: Signal.from_dict() raises ValueError when lane signals feed bus
# directly — field mismatch between bash output and Python bus expectations.
#
# USAGE:
#   python3 wf-fix-lane-to-bus.py --input lane-signals.json [--output bus-signals.json]
#   python3 wf-fix-lane-to-bus.py --input lane-signals.json --format envelope
#   python3 wf-fix-lane-to-bus.py --validate --input bus-signals.json
#
# EXIT CODES: 0 success, 1 error/validation failure
#
# Schema mapping:
#   severity       -> suggested_severity
#   location{}     -> target{kind:"source_location", file, line, selector, url}
#   evidence[arr]  -> evidence{code_snippet, spec_ref}
#   fingerprint    -> dedup_hints[fingerprint]
#   +              -> emitted_at (ISO 8601)
#
# Canonical 5-token fingerprint (IMP-022):
#   {probe_id}|{file_path}|{line_start}|{issue_class}|{dim_id}
#
# Author: wf-fix-bugs Sprint 6 2026-05-09

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Constants ────────────────────────────────────────────────────────

PROBE_ID_RE = re.compile(r"^P-QD([1-9]|10)-[a-z0-9-]+$")
VALID_DIMS = frozenset({"QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7", "QD8", "QD9", "QD10", "QD11"})
VALID_SEVERITIES = frozenset({"critical", "high", "medium", "low", "warn", "info"})
SEV_NORMALIZE = {"CRITICAL": "critical", "HIGH": "high", "MEDIUM": "medium",
                 "LOW": "low", "WARN": "warn", "INFO": "info",
                 "warning": "warn", "WARNING": "warn"}


# ── Fingerprint ──────────────────────────────────────────────────────

def canonical_fingerprint(probe_id: str, file_path: str,
                           line_start: int | str, issue_class: str,
                           dim_id: str) -> str:
    """Build canonical 5-token fingerprint (IMP-022).

    Format: sha256 of '{probe_id}|{file_path}|{line_start}|{issue_class}|{dim_id}'
    """
    token = f"{probe_id}|{file_path}|{line_start}|{issue_class}|{dim_id}"
    return "sha256:" + hashlib.sha256(token.encode()).hexdigest()


# ── Field translators ────────────────────────────────────────────────

def translate_severity(signal: dict[str, Any]) -> str:
    """severity / suggested_severity / severity_default → normalized string."""
    raw = (signal.get("severity")
           or signal.get("suggested_severity")
           or signal.get("severity_default")
           or "medium")
    return SEV_NORMALIZE.get(raw, raw.lower())


def translate_target(signal: dict[str, Any]) -> dict[str, Any]:
    """location{} → target{kind, file, line, selector, url}."""
    loc = signal.get("location") or {}
    if isinstance(loc, dict):
        return {
            "kind": "source_location",
            "file": loc.get("file") or loc.get("path") or "",
            "line": loc.get("line") or loc.get("line_start") or 0,
            "selector": loc.get("selector") or None,
            "url": loc.get("url") or None,
        }
    # Already in target format
    if isinstance(signal.get("target"), dict):
        t = dict(signal["target"])
        t.setdefault("kind", "source_location")
        return t
    return {"kind": "source_location", "file": "", "line": 0,
            "selector": None, "url": None}


def translate_evidence(signal: dict[str, Any]) -> dict[str, Any]:
    """evidence[array] | evidence{dict} → evidence{dict} for bus."""
    raw = signal.get("evidence")
    if isinstance(raw, dict):
        return raw  # Already bus format

    evidence: dict[str, Any] = {}
    if isinstance(raw, list):
        for entry in raw:
            if not isinstance(entry, dict):
                continue
            kind = entry.get("type") or entry.get("kind") or ""
            content = (entry.get("description")
                       or entry.get("content")
                       or entry.get("path")
                       or "")
            if kind in ("code", "code_snippet") or not evidence.get("code_snippet"):
                evidence["code_snippet"] = content
            elif kind in ("spec", "spec_ref"):
                evidence["spec_ref"] = content

    # Fallback: use description field
    if not evidence:
        desc = signal.get("description") or signal.get("title") or ""
        if len(desc) >= 10:
            evidence["code_snippet"] = desc[:200]

    return evidence if evidence else {"code_snippet": "(no evidence)"}


def translate_dedup_hints(signal: dict[str, Any]) -> list[str]:
    """fingerprint / dedup_hints → list[str] for bus."""
    existing = signal.get("dedup_hints")
    if isinstance(existing, list):
        return existing
    fp = signal.get("fingerprint")
    if fp:
        return [str(fp)]
    return []


# ── Main translator ──────────────────────────────────────────────────

def translate_signal(lane_signal: dict[str, Any]) -> dict[str, Any]:
    """Translate a single lane signal dict to bus signal dict.

    Preserves all original fields not explicitly remapped so downstream
    validators can still see probe_id, title, description, etc.
    """
    # Extract key fields
    dim_id = lane_signal.get("dimension_id", "")
    probe_id = lane_signal.get("probe_id", "")
    title = lane_signal.get("title", "")
    description = lane_signal.get("description", "")

    sev = translate_severity(lane_signal)
    target = translate_target(lane_signal)
    evidence = translate_evidence(lane_signal)
    dedup_hints = translate_dedup_hints(lane_signal)

    # Re-derive canonical fingerprint if dedup_hints would be empty
    if not dedup_hints:
        file_path = target.get("file", "")
        line_start = target.get("line", 0)
        issue_class = re.sub(r"\s+", "_", title.lower())[:40] if title else "unknown"
        dedup_hints = [canonical_fingerprint(probe_id, file_path, line_start,
                                             issue_class, dim_id)]

    bus_signal: dict[str, Any] = {
        "$schema": "signal-v2",
        "dimension_id": dim_id,
        "probe_id": probe_id,
        "probe_version": lane_signal.get("probe_version", "v1.0"),
        "suggested_severity": sev,
        "fixability": lane_signal.get("fixability", "agent_fix"),
        "domain": lane_signal.get("domain", "general"),
        "title": title,
        "description": description,
        "target": target,
        "evidence": evidence,
        "dedup_hints": dedup_hints,
        "cdg_flags": lane_signal.get("cdg_flags", []),
        "remediation": lane_signal.get("remediation", {}),
        "emitted_at": datetime.now(timezone.utc).isoformat(),
    }

    # Forward any extra fields not already mapped
    skip_keys = {"$schema", "severity", "location", "evidence", "fingerprint",
                 "suggested_severity", "target", "dedup_hints", "emitted_at",
                 "generated_at", "detected_at"}
    for k, v in lane_signal.items():
        if k not in bus_signal and k not in skip_keys:
            bus_signal[k] = v

    return bus_signal


def translate_envelope(envelope: dict[str, Any]) -> dict[str, Any]:
    """Translate a lane-signals-v1 envelope to bus-signals envelope."""
    raw_signals = envelope.get("signals", [])
    translated = [translate_signal(s) for s in raw_signals if isinstance(s, dict)]

    return {
        "$schema": "lane-signals-v1-translated",
        "lane": envelope.get("lane", ""),
        "dimension": envelope.get("dimension", ""),
        "probe_id": envelope.get("probe_id", ""),
        "probe_version": envelope.get("probe_version", ""),
        "profile": envelope.get("profile", ""),
        "translated_at": datetime.now(timezone.utc).isoformat(),
        "signal_count": len(translated),
        "signals": translated,
    }


# ── Validation ───────────────────────────────────────────────────────

def validate_bus_signal(signal: dict[str, Any]) -> list[str]:
    """Return list of validation errors for a bus signal."""
    errors: list[str] = []
    required = ["dimension_id", "probe_id", "suggested_severity", "target", "evidence"]
    for field in required:
        if field not in signal:
            errors.append(f"missing required field: {field}")

    if signal.get("dimension_id") not in VALID_DIMS:
        errors.append(f"invalid dimension_id: {signal.get('dimension_id')}")
    if signal.get("probe_id") and not PROBE_ID_RE.match(str(signal["probe_id"])):
        errors.append(f"invalid probe_id format: {signal.get('probe_id')}")
    if not isinstance(signal.get("target"), dict):
        errors.append("target must be an object")
    elif "kind" not in signal["target"]:
        errors.append("target.kind is required")
    if not isinstance(signal.get("evidence"), dict):
        errors.append("evidence must be an object (not array)")
    if not isinstance(signal.get("dedup_hints"), list):
        errors.append("dedup_hints must be an array")
    return errors


# ── CLI ──────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="Translate lane signals to bus format")
    parser.add_argument("--input", required=True, help="Input JSON file (lane signals)")
    parser.add_argument("--output", help="Output JSON file (bus signals). Default: stdout")
    parser.add_argument("--format", choices=["envelope", "signals"],
                        default="envelope",
                        help="Output format: envelope (default) or signals array")
    parser.add_argument("--validate", action="store_true",
                        help="Validate that input is already bus-format")
    args = parser.parse_args()

    try:
        with open(args.input, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR: cannot read input: {e}", file=sys.stderr)
        return 1

    if args.validate:
        # Validate mode: check each signal in envelope or array
        signals = data.get("signals", data) if isinstance(data, dict) else data
        if not isinstance(signals, list):
            signals = [signals]
        all_errors: list[str] = []
        for i, sig in enumerate(signals):
            errs = validate_bus_signal(sig)
            for e in errs:
                all_errors.append(f"signal[{i}]: {e}")
        if all_errors:
            for err in all_errors:
                print(f"FAIL: {err}", file=sys.stderr)
            return 1
        print(f"PASS: {len(signals)} signal(s) valid bus format")
        return 0

    # Translation mode
    if isinstance(data, dict) and "signals" in data:
        result = translate_envelope(data)
        out_signals = result["signals"]
    elif isinstance(data, list):
        out_signals = [translate_signal(s) for s in data if isinstance(s, dict)]
        result = {
            "$schema": "lane-signals-v1-translated",
            "translated_at": datetime.now(timezone.utc).isoformat(),
            "signal_count": len(out_signals),
            "signals": out_signals,
        }
    else:
        out_signals = [translate_signal(data)]
        result = {
            "$schema": "lane-signals-v1-translated",
            "translated_at": datetime.now(timezone.utc).isoformat(),
            "signal_count": 1,
            "signals": out_signals,
        }

    output_data = out_signals if args.format == "signals" else result
    out_json = json.dumps(output_data, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(out_json + "\n", encoding="utf-8")
        print(f"[lane-to-bus] Translated {result.get('signal_count', 0)} signal(s) "
              f"→ {args.output}", file=sys.stderr)
    else:
        print(out_json)

    return 0


if __name__ == "__main__":
    # F05.024 (Sprint 8): Wrap main() với handlers cho KeyboardInterrupt +
    # BrokenPipeError để CLI exit gracefully khi user Ctrl-C hoặc downstream
    # pipe close (vd: `wf-fix-lane-to-bus.py | head` đóng pipe sớm).
    # Default Python exit code 130 (SIGINT) / 32 (SIGPIPE) — match POSIX.
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("[wf-fix-lane-to-bus] interrupted by user", file=sys.stderr)
        sys.exit(130)
    except BrokenPipeError:
        # Đóng stdout an toàn để không raise tiếp khi Python flush ở exit.
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(32)
