#!/usr/bin/env python3
"""read_trace.py — Đọc và hiển thị session-log.json NDJSON trace events.

Vai trò:
    Công cụ CLI đọc `.mc-data/work/_trace/session-log.json` (NDJSON — CORE-026),
    filter theo skill, hiển thị last-N entries, hỗ trợ troubleshooting.

Su dung:
    python -m _shared.read_trace                          # toan bo events
    python -m _shared.read_trace --skill=wf-fix-bugs      # loc theo skill
    python -m _shared.read_trace --last=20                # 20 event gan nhat
    python -m _shared.read_trace --file=<path>            # chi duong dan khac
    python -m _shared.read_trace --summary                # chi hien thi summary stats

Tham chieu:
    - CORE-026: Execution Trace
    - B4-3: Observability Enhancement
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Duong dan mac dinh
DEFAULT_TRACE_PATH = Path(".mc-data/work/_trace/session-log.json")


# ──────────────────────────────────────────────────────────────────────
# Doc NDJSON
# ──────────────────────────────────────────────────────────────────────


def read_events(trace_path: Path) -> list[dict[str, Any]]:
    """Doc toan bo events tu file NDJSON.

    Bo qua dong corrupt (khong parse duoc).
    """
    if not trace_path.exists():
        return []
    events: list[dict[str, Any]] = []
    with trace_path.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                print(
                    f"[WARN] Dong {line_no} corrupt — bo qua",
                    file=sys.stderr,
                )
    return events


# ──────────────────────────────────────────────────────────────────────
# Filter
# ──────────────────────────────────────────────────────────────────────


def filter_events(
    events: list[dict[str, Any]],
    skill: str | None = None,
    last_n: int | None = None,
) -> list[dict[str, Any]]:
    """Loc events theo skill va/hoac last-N."""
    filtered = events
    if skill:
        skill_lower = skill.lower()
        filtered = [
            e
            for e in filtered
            if e.get("skill", "").lower() == skill_lower
            or skill_lower in e.get("skill", "").lower()
        ]
    if last_n is not None and last_n > 0:
        filtered = filtered[-last_n:]
    return filtered


# ──────────────────────────────────────────────────────────────────────
# Render
# ──────────────────────────────────────────────────────────────────────

# Event type tieng Viet labels
EVENT_LABELS: dict[str, str] = {
    "START": "▶ Bắt đầu",
    "COMPLETE": "✓ Hoàn thành",
    "FAIL": "✗ Thất bại",
    "PHASE_START": "▶ Phase",
    "PHASE_COMPLETE": "✓ Phase",
    "PHASE_FAIL": "✗ Phase",
    "RESUME": "↻ Tiếp tục",
    "CDG_PROMPT": "⚠ CDG",
    "CDG_ACCEPT": "✓ CDG chấp nhận",
    "CDG_REJECT": "✗ CDG từ chối",
}


def _format_event(idx: int, event: dict[str, Any]) -> str:
    """Format 1 event thanh dong readable."""
    ts = event.get("timestamp", "?")
    event_type = event.get("event_type", "UNKNOWN")
    label = EVENT_LABELS.get(event_type, event_type)
    skill = event.get("skill", "?")
    phase = event.get("phase", "")
    detail = event.get("detail", "")

    parts = [f"[{idx:>4}]", ts, f"{label}", f"({skill})"]
    if phase:
        parts.append(f"Phase: {phase}")
    if detail:
        parts.append(f"— {detail}")
    return " ".join(parts)


def render_events(events: list[dict[str, Any]]) -> None:
    """Hien thi events ra stdout."""
    if not events:
        print("(khong co event)")
        return
    for idx, event in enumerate(events, 1):
        print(_format_event(idx, event))


def render_summary(events: list[dict[str, Any]]) -> None:
    """Hien thi thong ke tom tat."""
    if not events:
        print("(khong co event)")
        return

    total = len(events)
    skills: dict[str, int] = {}
    types: dict[str, int] = {}
    fails = 0
    for e in events:
        s = e.get("skill", "?")
        skills[s] = skills.get(s, 0) + 1
        t = e.get("event_type", "UNKNOWN")
        types[t] = types.get(t, 0) + 1
        if "FAIL" in t:
            fails += 1

    print(f"Tong event: {total}")
    print(f"That bai:    {fails}")
    print()
    print("Theo skill:")
    for s, count in sorted(skills.items(), key=lambda x: -x[1]):
        print(f"  {s}: {count}")
    print()
    print("Theo event_type:")
    for t, count in sorted(types.items(), key=lambda x: -x[1]):
        label = EVENT_LABELS.get(t, t)
        print(f"  {label}: {count}")


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Đọc session-log.json trace events (CORE-026)",
    )
    parser.add_argument(
        "--file",
        type=Path,
        default=DEFAULT_TRACE_PATH,
        help="Đường dẫn session-log.json (mặc định: .mc-data/work/_trace/session-log.json)",
    )
    parser.add_argument(
        "--skill",
        type=str,
        default=None,
        help="Lọc theo skill (substring match, case-insensitive)",
    )
    parser.add_argument(
        "--last",
        type=int,
        default=None,
        help="Chỉ hiện N event gần nhất",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Chỉ hiện thống kê tóm tắt, không hiện từng event",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Xuất raw JSON (mỗi event 1 dòng)",
    )

    args = parser.parse_args(argv)

    events = read_events(args.file)
    if not events:
        print(f"[INFO] Khong tim thay event trong {args.file}", file=sys.stderr)
        return 0

    events = filter_events(events, skill=args.skill, last_n=args.last)

    if args.json:
        for e in events:
            print(json.dumps(e, ensure_ascii=False))
    elif args.summary:
        render_summary(events)
    else:
        render_events(events)

    return 0


if __name__ == "__main__":
    sys.exit(main())
