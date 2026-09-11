"""emit_signals — Parse agent raw output → write llm-signals.json (lane-signals-v1).

Phase C v8 wire-up part 2: Sau khi orchestrator (Claude main loop) drive
Agent({subagent_type, prompt}) va save raw output, script nay duoc goi de:
    1. Read raw agent output (text file)
    2. parse_signals() → validate signals theo signal-v2 schema
    3. Wrap in lane-signals-v1 envelope
    4. Atomic write → output_signals_path

Usage:
    python -m llm_lane.emit_signals \\
        --session-dir <path> \\
        --probe-id <id> \\
        --dimension <QD1|QD2|...|cross> \\
        --lane <wf-fix-functional|...|cross-cutting> \\
        --raw-output <agent_output_file> \\
        --output-signals <output llm-signals.json path> \\
        [--profile deep|exhaustive] \\
        [--source-dir <repo source root>]

Exit codes:
    0 — success (signals written, may be empty array)
    1 — invalid args / missing file
    2 — parse fail (no JSON found in raw output)
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .signal_parser import parse_signals

LANE_SIGNALS_SCHEMA = "lane-signals-v1"


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    """Write JSON atomically (tmp file + rename)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{Path().resolve().name}.{id(data)}")
    # CORE-035 atomic + sort_keys=True audit_chain checksum determinism (F06.008).
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


def emit_signals(
    *,
    session_dir: Path,
    probe_id: str,
    dimension: str,
    lane: str,
    raw_output_path: Path,
    output_signals_path: Path,
    profile: str = "deep",
    source_dir: Path | None = None,
) -> tuple[int, dict[str, Any]]:
    """Parse raw agent output → write lane-signals-v1 envelope.

    Returns:
        (validated_signal_count, parser_metadata).
    """
    if not raw_output_path.is_file():
        raise FileNotFoundError(f"raw output not found: {raw_output_path}")

    raw_text = raw_output_path.read_text(encoding="utf-8", errors="replace")

    # Source dir defaults to repo root (CWD).
    src_root = source_dir or Path.cwd()

    signals, parse_meta = parse_signals(
        raw_text,
        source_dir=src_root,
        probe_id=probe_id,
        lane=lane,
        dimension=dimension,
    )

    envelope: dict[str, Any] = {
        "$schema": LANE_SIGNALS_SCHEMA,
        "lane": lane,
        "dimension": dimension,
        "probe_id": probe_id,
        "probe_version": "v1.0-llm",
        "profile": profile,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "llm_probe",
        "signals": signals,
        "parser_metadata": parse_meta,
    }

    _atomic_write_json(output_signals_path, envelope)
    return len(signals), parse_meta


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Parse agent raw output → llm-signals.json")
    parser.add_argument("--session-dir", required=True, type=Path)
    parser.add_argument("--probe-id", required=True)
    parser.add_argument("--dimension", required=True,
                        help="QD1..QD11 hoac 'cross' cho cross-cutting probes")
    parser.add_argument("--lane", required=True,
                        help="wf-fix-{functional,business,security,...} hoac 'cross-cutting'")
    parser.add_argument("--raw-output", required=True, type=Path,
                        help="Path to agent raw output text file")
    parser.add_argument("--output-signals", required=True, type=Path,
                        help="Output path for llm-signals.json")
    parser.add_argument("--profile", default="deep",
                        choices=("quick", "standard", "deep", "exhaustive"))
    parser.add_argument("--source-dir", type=Path, default=None,
                        help="Repo source root for path validation (default CWD)")
    args = parser.parse_args(argv)

    if not args.session_dir.is_dir():
        print(f"[emit_signals ERROR] session-dir not found: {args.session_dir}", file=sys.stderr)
        return 1

    try:
        count, meta = emit_signals(
            session_dir=args.session_dir,
            probe_id=args.probe_id,
            dimension=args.dimension,
            lane=args.lane,
            raw_output_path=args.raw_output,
            output_signals_path=args.output_signals,
            profile=args.profile,
            source_dir=args.source_dir,
        )
    except FileNotFoundError as exc:
        print(f"[emit_signals ERROR] {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"[emit_signals ERROR] {exc}", file=sys.stderr)
        return 2

    print(f"OK: wrote {count} signals → {args.output_signals}")
    print(f"  raw_signals     = {meta.get('raw_signals', 0)}")
    print(f"  validated       = {meta.get('validated_signals', 0)}")
    print(f"  dropped_invalid = {meta.get('dropped_invalid', 0)}")
    print(f"  dropped_dup     = {meta.get('dropped_duplicate', 0)}")
    print(f"  dropped_no_json = {meta.get('dropped_no_json', 0)}")

    if count == 0 and meta.get("dropped_no_json", 0) > 0:
        # No JSON found in agent output → exit 2 to signal partial failure
        # (caller có thể retry hoặc skip).
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
