#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build-progress.py — Build/refresh _runs/progress.json cho wf-test-business-workflow.

Scan .mc-data/docs/phase1-business/workflows/WF-L[0-9]-[0-9][0-9]-*.md
-> _runs/progress.json (idempotent: preserve existing statuses).

Usage:
  python -X utf8 build-progress.py [--workflows-dir=PATH] [--runs-dir=PATH]
"""
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

WF_FILE_RE = re.compile(r"^(WF-L\d-\d{2})-")

STATUS_ORDER = {"pending": 0, "inprogress": 1, "done": 2, "blocked": 3}


def wf_sort_key(wf_id: str):
    m = re.match(r"WF-L(\d)-(\d{2})", wf_id)
    return (int(m.group(1)), int(m.group(2))) if m else (99, 99)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workflows-dir", default=".mc-data/docs/phase1-business/workflows")
    ap.add_argument("--runs-dir", default=".mc-data/work/wf-test-business-workflow/_runs")
    args = ap.parse_args()

    wdir = Path(args.workflows_dir)
    rdir = Path(args.runs_dir)
    if not wdir.is_dir():
        print(f"ERROR: workflows dir not found: {wdir}", file=sys.stderr)
        return 1

    # Existing progress (preserve statuses)
    progress_path = rdir / "progress.json"
    existing: dict = {}
    if progress_path.is_file():
        try:
            existing = json.loads(progress_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"WARN: progress.json unreadable ({e}) — rebuilding", file=sys.stderr)
            existing = {}
    old_workflows = existing.get("workflows", {}) if isinstance(existing.get("workflows"), dict) else {}

    # Scan spec files
    workflows: dict = {}
    for f in sorted(wdir.glob("WF-L*-*.md")):
        m = WF_FILE_RE.match(f.name)
        if not m or f.name.endswith(".bak"):
            continue
        wf_id = m.group(1)
        prev = old_workflows.get(wf_id, {})
        workflows[wf_id] = {
            "status": prev.get("status", "pending"),
            "file": str(f).replace("\\", "/"),
            "session": prev.get("session"),
            "presentation_path": prev.get("presentation_path"),
            "checkpoint": prev.get("checkpoint"),
            "started_at": prev.get("started_at"),
            "completed_at": prev.get("completed_at"),
        }

    if not workflows:
        print(f"WARN: 0 WF-L*.md found in {wdir} — nothing to test yet (E001 khi chạy skill)")

    merged = {
        "$schema": "wf-test-business-workflow-progress-v1",
        "updated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "workflows": {k: workflows[k] for k in sorted(workflows, key=wf_sort_key)},
    }

    rdir.mkdir(parents=True, exist_ok=True)
    tmp = progress_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(merged, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(progress_path)

    counts = {}
    for w in workflows.values():
        counts[w["status"]] = counts.get(w["status"], 0) + 1
    print(f"OK: {len(workflows)} workflows -> {progress_path} | {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
