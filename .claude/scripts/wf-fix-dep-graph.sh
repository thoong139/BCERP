#!/usr/bin/env bash
# wf-fix-dep-graph.sh — Build dependency groups tu CRITICAL issues (W2.2 v10-speedup)
#
# Muc dich: Phan tich issues CRITICAL trong issue-registry.json va group theo
# file/symbol overlap → cho phep Phase 3 Batch 1 spawn agent parallel SAFELY
# (issues khac group → khac file/symbol → khong race condition).
#
# Input:  $SESSION_DIR/issue-registry.json (filtered: severity=CRITICAL)
# Output: $SESSION_DIR/phase3-batch1/dep-groups.json
#         {
#           "groups": [["ISS-001", "ISS-002"], ["ISS-003"]],
#           "total_critical": 3,
#           "total_groups": 2,
#           "max_parallel_agents": 3,
#           "escape_hatch_active": false,
#           "generated_at": "2026-05-14T08:00:00Z"
#         }
#
# Algorithm (union-find):
#   1. Build set of (file_paths, symbol) cho moi CRITICAL issue
#   2. Hai issue overlap NEU chia se >=1 file HOAC cung symbol (non-empty)
#   3. Union-find groups → issues cung group sequential, khac group parallel-safe
#
# Escape hatch:
#   MCV3_FIX_BATCH1_PARALLEL_DISABLED=1 → output 1 group containing ALL critical
#   (effectively sequential — fall back hanh vi cu).
#
# Usage:
#   bash .claude/scripts/wf-fix-dep-graph.sh <SESSION_DIR>
#
# Exit codes:
#   0 — Thanh cong (dep-groups.json created)
#   2 — Invalid arguments (missing SESSION_DIR hoac issue-registry.json)
#   3 — Internal error (Python parse fail, atomic write fail, ...)

set -euo pipefail

# ===========================================================================
# Constants & validation
# ===========================================================================

readonly SCRIPT_NAME="wf-fix-dep-graph"

usage() {
  cat <<EOF
Usage: bash $0 <SESSION_DIR>

Required:
  SESSION_DIR — Duong dan tuyet doi den session, chua issue-registry.json

Output:
  \$SESSION_DIR/phase3-batch1/dep-groups.json

Escape hatch:
  MCV3_FIX_BATCH1_PARALLEL_DISABLED=1 → 1 group all (sequential fallback)
EOF
}

if [ $# -lt 1 ]; then
  echo "ERROR: SESSION_DIR required" >&2
  usage >&2
  exit 2
fi

SESSION_DIR="$1"
if [ ! -d "$SESSION_DIR" ]; then
  echo "ERROR: SESSION_DIR khong ton tai: $SESSION_DIR" >&2
  exit 2
fi

ISSUES_JSON="$SESSION_DIR/issue-registry.json"
if [ ! -s "$ISSUES_JSON" ]; then
  echo "ERROR: issue-registry.json khong ton tai hoac rong: $ISSUES_JSON" >&2
  exit 2
fi

OUT_DIR="$SESSION_DIR/phase3-batch1"
OUT_FILE="$OUT_DIR/dep-groups.json"
mkdir -p "$OUT_DIR"

# Determine max_parallel_agents tu $LPM_PARAMS neu duoc set; mac dinh 5 (standard).
# LPM mode: 3, standard mode: 5 (xem _shared.md State Variables Glossary).
MAX_PARALLEL_AGENTS="${MAX_PARALLEL_AGENTS:-5}"
ESCAPE_HATCH="${MCV3_FIX_BATCH1_PARALLEL_DISABLED:-0}"

# ===========================================================================
# Build dep-groups via Python (atomic write)
# ===========================================================================

TMP_FILE="${OUT_FILE}.tmp.$$"
trap 'rm -f "$TMP_FILE"' EXIT

# Export bien cho Python doc tu environment (an toan ky tu dac biet trong path).
export ISSUES_JSON OUT_FILE TMP_FILE MAX_PARALLEL_AGENTS ESCAPE_HATCH

# Cross-platform Python picker — uu tien python3 (Linux/macOS), fallback python (Git Bash Windows).
# LUU Y: Windows co "Microsoft Store" stub `python3.exe` chi mo store khi chay → can test
# bang `--version` de loc cac stub khong functional.
pick_python() {
  if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    echo "python3"
  elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
    echo "python"
  else
    return 1
  fi
}

PY_CMD=$(pick_python) || { echo "ERROR: python/python3 not found in PATH" >&2; exit 3; }

"$PY_CMD" <<'PYEOF' || { echo "ERROR: Python parse/build failed" >&2; exit 3; }
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone

issues_path = os.environ["ISSUES_JSON"]
tmp_path = os.environ["TMP_FILE"]
max_parallel = int(os.environ.get("MAX_PARALLEL_AGENTS", "5"))
escape_hatch = os.environ.get("ESCAPE_HATCH", "0") == "1"

with open(issues_path, "r", encoding="utf-8") as f:
    data = json.load(f)

all_issues = data.get("issues", []) or []
# Filter CRITICAL severity (case-insensitive de robust voi triage output variants)
critical = [
    i for i in all_issues
    if str(i.get("severity") or "").upper() == "CRITICAL"
]


def collect_files(issue):
    """Tap hop file paths tu nhieu source field kha thi."""
    files = set()
    # Field 1: top-level files_modified[] (fix-log entry style — co the co tu enrichment)
    fm = issue.get("files_modified") or []
    if isinstance(fm, list):
        for p in fm:
            if isinstance(p, str) and p.strip():
                files.add(p.strip())
    # Field 2: target.file_path (issue-v2 schema canonical)
    target = issue.get("target") or {}
    if isinstance(target, dict):
        fp = target.get("file_path")
        if isinstance(fp, str) and fp.strip():
            files.add(fp.strip())
    # Field 3: location.file (legacy/alternate)
    loc = issue.get("location") or {}
    if isinstance(loc, dict):
        lf = loc.get("file")
        if isinstance(lf, str) and lf.strip():
            files.add(lf.strip())
    return files


def collect_symbol(issue):
    """Lay symbol tu target.symbol (canonical). Rong → None."""
    target = issue.get("target") or {}
    if isinstance(target, dict):
        sym = target.get("symbol")
        if isinstance(sym, str) and sym.strip():
            return sym.strip()
    return None


def overlap(a_files, a_sym, b_files, b_sym):
    """Hai issue overlap khi chia se >=1 file HOAC cung symbol (non-empty)."""
    if a_files & b_files:
        return True
    if a_sym and b_sym and a_sym == b_sym:
        return True
    return False


# Build feature vectors
features = []
for issue in critical:
    iid = issue.get("issue_id")
    if not iid:
        # Skip issue thieu issue_id (loi data) — khong group duoc
        continue
    features.append({
        "id": iid,
        "files": collect_files(issue),
        "symbol": collect_symbol(issue),
    })

total_critical = len(features)

# Union-find
parent = {f["id"]: f["id"] for f in features}


def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]  # path compression
        x = parent[x]
    return x


def union(x, y):
    px, py = find(x), find(y)
    if px != py:
        parent[px] = py


if escape_hatch:
    # Escape hatch: gom tat ca vao 1 group (sequential)
    for i in range(1, len(features)):
        union(features[0]["id"], features[i]["id"])
else:
    # Pairwise overlap check
    n = len(features)
    for i in range(n):
        for j in range(i + 1, n):
            if overlap(
                features[i]["files"], features[i]["symbol"],
                features[j]["files"], features[j]["symbol"],
            ):
                union(features[i]["id"], features[j]["id"])

# Collect groups (sorted for determinism)
groups_map = defaultdict(list)
for f in features:
    root = find(f["id"])
    groups_map[root].append(f["id"])

# Sort issues within each group + sort groups by first issue_id de output deterministic
groups = sorted(
    [sorted(ids) for ids in groups_map.values()],
    key=lambda g: g[0] if g else "",
)

result = {
    "groups": groups,
    "total_critical": total_critical,
    "total_groups": len(groups),
    "max_parallel_agents": max_parallel,
    "escape_hatch_active": escape_hatch,
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}

with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)
PYEOF

# Validate JSON before atomic move (CORE-035 Atomic Write Pattern)
if ! jq -e '.' "$TMP_FILE" > /dev/null 2>&1; then
  echo "ERROR: tmp dep-groups.json invalid JSON" >&2
  exit 3
fi

mv -f "$TMP_FILE" "$OUT_FILE"

# Quick summary cho operator (stderr — khong an stdout neu caller can)
TOTAL_CRITICAL=$(jq -r '.total_critical' "$OUT_FILE")
TOTAL_GROUPS=$(jq -r '.total_groups' "$OUT_FILE")
ESCAPE_FLAG=$(jq -r '.escape_hatch_active' "$OUT_FILE")
echo "[$SCRIPT_NAME] dep-groups.json built: critical=$TOTAL_CRITICAL groups=$TOTAL_GROUPS escape_hatch=$ESCAPE_FLAG max_parallel=$MAX_PARALLEL_AGENTS" >&2

exit 0
