#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""next-session.py — Spawn Claude Code tab moi cho WF ke tiep (autonomous loop).

Windows: clipboard qua PowerShell Set-Clipboard, window activation + SendKeys qua
PowerShell (WScript.Shell AppActivate/SendKeys). Mirror logic cua next-session.ps1.

Usage:
  python -X utf8 next-session.py [--runs-dir=PATH] [--dry-run]

Exit 0 = spawn OK hoac STOP / het pending (session hien tai EXIT ngay).
Exit 1 = fail -> skill chay FALLBACK MODE in-session (procedures/phase4-spawn-next.md Step 4.6).
"""
import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

EDITOR_CANDIDATES = ["Code", "Cursor", "Windsurf", "Antigravity", "Code - Insiders"]


def log(runs_dir: Path, msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{ts} {msg}"
    print(line)
    try:
        with open(runs_dir / "next-session.log", "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def ps(script: str) -> bool:
    """Run a PowerShell one-liner; return True on success."""
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True, text=True, timeout=30,
        )
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"powershell error: {e}", file=sys.stderr)
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs-dir", default=".mc-data/work/wf-test-business-workflow/_runs")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    runs_dir = Path(args.runs_dir)
    stop_path = runs_dir / "STOP"
    progress_path = runs_dir / "progress.json"
    prompt_path = runs_dir / "prompt-template.md"
    mirror_path = runs_dir / ".machine-mirror.json"

    # 1. STOP check
    if stop_path.exists():
        log(runs_dir, "STOP file detected. No spawn.")
        return 0

    # 2. Pending check
    if progress_path.is_file():
        try:
            progress = json.loads(progress_path.read_text(encoding="utf-8"))
            pending = sum(1 for w in progress.get("workflows", {}).values()
                          if w.get("status") == "pending")
            if pending == 0:
                log(runs_dir, "No pending workflows. Loop complete.")
                return 0
            log(runs_dir, f"{pending} pending workflows.")
        except (json.JSONDecodeError, OSError) as e:
            log(runs_dir, f"WARN: progress.json unreadable ({e}) — skip pending check")

    # 3. Prompt file check
    if not prompt_path.is_file():
        log(runs_dir, f"ERROR: prompt-template.md not found: {prompt_path}")
        return 1

    # 4. Editor app from mirror
    vscode_app = "Code"
    if mirror_path.is_file():
        try:
            mirror = json.loads(mirror_path.read_text(encoding="utf-8"))
            if mirror.get("vscode_app"):
                vscode_app = mirror["vscode_app"]
        except (json.JSONDecodeError, OSError):
            pass

    # 5. Clipboard (UTF-8 via PowerShell)
    prompt_win = str(prompt_path.resolve())
    if not ps(f"Get-Content -Raw -Encoding UTF8 '{prompt_win}' | Set-Clipboard"):
        log(runs_dir, "ERROR: clipboard copy failed. exit 1 -> FALLBACK")
        return 1
    log(runs_dir, "Prompt copied to clipboard.")

    if args.dry_run:
        log(runs_dir, f"[DRY-RUN] Would activate editor ({vscode_app}) and open new Claude Code tab.")
        return 0

    # 6. Activate editor window (AppActivate theo ten process/title)
    shell = "(New-Object -ComObject WScript.Shell)"
    activated = False
    for cand in [vscode_app] + [c for c in EDITOR_CANDIDATES if c != vscode_app]:
        if ps(f"{shell}.AppActivate('{cand}')"):
            log(runs_dir, f"Activated editor window via AppActivate('{cand}').")
            activated = True
            break
    if not activated:
        log(runs_dir, "ERROR: editor window not found/activatable. exit 1 -> FALLBACK")
        return 1
    time.sleep(0.8)

    # 7. SendKeys sequence: command palette -> "Claude Code: New Tab" -> paste -> submit
    seq = [
        ("^+p", 0.8, "Opening command palette (Ctrl+Shift+P)..."),
        ("Claude Code: New Tab", 0.6, "Typing: Claude Code: New Tab"),
        ("{ENTER}", 2.5, "Selecting command, waiting for new tab..."),
        ("^v", 0.5, "Pasting prompt..."),
        ("{ENTER}", 0.3, "Submitting prompt."),
    ]
    for keys, wait, note in seq:
        log(runs_dir, note)
        escaped = keys.replace("'", "''")
        if not ps(f"{shell}.SendKeys('{escaped}')"):
            log(runs_dir, f"ERROR: SendKeys failed at '{keys}'. exit 1 -> FALLBACK")
            return 1
        time.sleep(wait)

    log(runs_dir, "New Claude Code tab spawned. Prompt pasted. exit 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
