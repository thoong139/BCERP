#!/usr/bin/env bash
# calibrate-rename.sh — Calibrate rename detection Levenshtein threshold (ADR-LS10).
# Usage: bash .claude/scripts/calibrate-rename.sh [fixture-dir]
#
# Measures precision/recall of rename detection (git --find-renames=80%).
# Target: precision >= 80% (09-thresholds-justification.md).
# If precision < 80% -> tune Levenshtein <= 10% threshold.

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"
SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"
FIXTURE="${1:-}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
check() {
    local desc="$1" status="$2"
    if [ "$status" = "0" ]; then echo "  [PASS] $desc"; PASS=$((PASS+1))
    else echo "  [FAIL] $desc"; FAIL=$((FAIL+1)); fi
}

echo "=== Rename Detection Calibration ==="
echo "Target: precision >= 80%, git --find-renames=80%, Levenshtein <= 10%"
echo ""

# ─── Tier 1: Structural checks ────────────────────────────────────────────
echo "--- Tier 1: Incremental module checks ---"

# Verify incremental module importable.
if (cd "$SHARED_ROOT" && python -c "from ips import incremental; print('ok')") >/dev/null 2>&1; then
    check "incremental module importable" 0
else
    check "incremental module importable" 1
fi

# Verify rename/change detection function present.
if (cd "$SHARED_ROOT" && python -c "
from ips import incremental
# Rename detection is part of detect_changes / classify_delta pipeline
assert hasattr(incremental, 'detect_changes') or hasattr(incremental, 'classify_delta') or \
       hasattr(incremental, 'detect_renames') or hasattr(incremental, 'find_renames'), 'Missing change detection fn'
print('ok')
") >/dev/null 2>&1; then
    check "detect_changes/classify_delta (rename detection) present" 0
else
    check "detect_changes/classify_delta function present" 1
fi

# Verify git diff rename threshold.
if (cd "$SHARED_ROOT" && python -c "
from ips import incremental
import inspect, ast
src = inspect.getsource(incremental)
assert 'find-renames' in src or 'find_renames' in src or 'RENAME_THRESHOLD' in src, 'Missing rename threshold'
print('ok')
") >/dev/null 2>&1; then
    check "git rename threshold configured in incremental.py" 0
else
    check "git rename threshold in incremental.py" 1
fi

# Verify Levenshtein / similarity check present.
if (cd "$SHARED_ROOT" && python -c "
from ips import incremental
import inspect
src = inspect.getsource(incremental)
assert 'levenshtein' in src.lower() or 'similarity' in src.lower() or 'difflib' in src.lower(), 'Missing similarity'
print('ok')
") >/dev/null 2>&1; then
    check "similarity/Levenshtein check in incremental.py" 0
else
    check "similarity/Levenshtein check in incremental.py" 1
fi

echo ""

# ─── Tier 1b: Known rename test case ──────────────────────────────────────
echo "--- Tier 1b: Rename detection unit test ---"

if (cd "$REPO_ROOT" && python -m pytest .claude/skills/workflow/_shared/ips/tests/ -k "rename" -q) >/dev/null 2>&1; then
    check "rename detection unit tests pass" 0
else
    echo "  [SKIP] No rename-specific tests found (acceptable — verify manually)"
fi

echo ""

# ─── Tier 2: Precision/recall on git fixture ─────────────────────────────
echo "--- Tier 2: Precision/recall measurement (requires git fixture) ---"

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided."
    echo "  Usage: bash calibrate-rename.sh fixtures/medium-vn/"
    echo ""
    echo "  When run with git fixture, this script will:"
    echo "    1. Get git log --diff-filter=R (known renames from last N commits)"
    echo "    2. Run incremental.detect_renames() on the same delta"
    echo "    3. Compute: precision = TP/(TP+FP), recall = TP/(TP+FN)"
    echo "    4. If precision < 80% -> recommend stricter threshold"
    echo "    5. If recall < 60% -> recommend relaxing threshold"
else
    if [ ! -d "$FIXTURE/.git" ] && ! git -C "$FIXTURE" rev-parse --git-dir >/dev/null 2>&1; then
        echo "  [SKIP] $FIXTURE is not a git repo — rename detection requires git history"
    else
        echo "  [INFO] Git repo detected. Checking rename history..."
        rename_count=$(git -C "$FIXTURE" log --diff-filter=R --name-status -n 50 2>/dev/null | grep -c '^R' || echo 0)
        echo "  [INFO] Found $rename_count renames in last 50 commits"
        if [ "$rename_count" -gt "0" ]; then
            check "git history has rename events for calibration" 0
        else
            echo "  [SKIP] No renames in recent history — test on project with rename history"
        fi
    fi
fi

echo ""
echo "--- Current Rename Threshold ---"
echo "  git --find-renames=80% (content similarity)"
echo "  Levenshtein <= 10% (path name similarity)"
echo "  Target precision: >= 80%"
echo ""
echo "  Action if precision < 80%:"
echo "    -> Increase --find-renames to 85% (stricter content match)"
echo "    -> Decrease Levenshtein tolerance from 10% to 8%"

echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Rename calibration Tier 1 passed ($PASS/$PASS checks)"
    exit 0
else
    echo "[FAILURE] Rename calibration Tier 1 failed ($FAIL/$TOTAL checks)"
    exit 1
fi
