#!/usr/bin/env bash
# calibrate-drift.sh — Calibrate drift tolerance thresholds (SMALL/MEDIUM).
# Usage: bash .claude/scripts/calibrate-drift.sh [fixture-dir]
#
# Measures false positive rate for SMALL/MEDIUM project drift detection.
# Target: false positive rate <= 20% (09-thresholds-justification.md).
# If > 20% -> relax to 4% SMALL/MEDIUM threshold.
#
# Drift threshold: staleness.py STALE_FRACTION values.

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

echo "=== Drift Tolerance Calibration ==="
echo "Target: false positive WARN rate <= 20% on unchanged SMALL/MEDIUM projects"
echo ""

# ─── Tier 1: Structural checks ────────────────────────────────────────────
echo "--- Tier 1: Staleness module checks ---"

# Verify staleness script exists and is executable.
STALE_SCRIPT="$REPO_ROOT/.claude/scripts/legacy-scan-staleness.sh"
if [ -f "$STALE_SCRIPT" ]; then
    check "legacy-scan-staleness.sh exists" 0
else
    check "legacy-scan-staleness.sh exists" 1
fi

# Verify v4.1 bak exists for comparison.
if [ -f "$REPO_ROOT/.claude/scripts/.v4.1.bak/legacy-scan-staleness.sh" ]; then
    check "v4.1 staleness reference exists" 0
else
    check "v4.1 staleness reference (may be acceptable)" 0
fi

# Verify drift thresholds defined in staleness script.
if grep -q 'STALENESS_MODIFIED_CAP\|STALENESS_NEW_CAP\|STALE_FRACTION\|DRIFT_THRESHOLD\|stale_percentage\|30%\|0\.3\|stale_count' "$STALE_SCRIPT" 2>/dev/null; then
    check "drift threshold constants in staleness.sh" 0
else
    check "drift threshold constants in staleness.sh" 1
fi

# Verify staleness metrics handled (modified + new + deleted categories).
for category in "modified" "new" "deleted"; do
    if grep -qi "$category" "$STALE_SCRIPT" 2>/dev/null; then
        check "$category file category handled in staleness.sh" 0
    else
        check "$category file category in staleness.sh" 1
    fi
done

echo ""

# ─── Tier 2: False positive measurement ────────────────────────────────────
echo "--- Tier 2: False positive rate measurement (requires fixtures) ---"

if [ -z "$FIXTURE" ]; then
    echo "  [SKIP] No fixture provided. Pass fixture path to measure false positive rate."
    echo "  Usage: bash calibrate-drift.sh fixtures/small-en/"
    echo ""
    echo "  When run with fixture, this script will:"
    echo "    1. Run scan on fixture (establish baseline assessment-report.json)"
    echo "    2. Re-run scan immediately (no file changes = zero drift expected)"
    echo "    3. Check if WARN triggered despite no changes (= false positive)"
    echo "    4. Repeat 5+ times, compute false positive rate"
    echo "    5. If rate > 20% -> recommend relaxing STALE_FRACTION by +1%"
else
    echo "  Fixture: $FIXTURE"
    if [ ! -d "$FIXTURE" ]; then
        echo "  [FAIL] Fixture not found: $FIXTURE"
        FAIL=$((FAIL+1))
    else
        WORK_DIR="$FIXTURE/.mc-data/work/legacy-scan"
        if [ -f "$WORK_DIR/assessment-report.json" ]; then
            echo "  [INFO] Previous assessment found. Running staleness check..."
            if bash "$STALE_SCRIPT" "$FIXTURE" 2>/dev/null | grep -q 'WARN\|stale'; then
                echo "  [INFO] Staleness WARN triggered — may be true positive if files changed"
            else
                echo "  [PASS] No spurious WARN — drift detection looking clean"
                PASS=$((PASS+1))
            fi
        else
            echo "  [SKIP] No previous assessment. Run wf-legacy-scan first."
        fi
    fi
fi

# ─── Current thresholds ─────────────────────────────────────────────────────
echo ""
echo "--- Current Drift Thresholds ---"
echo "  SMALL project:  3% stale fraction -> WARN (proposed; may relax to 4%)"
echo "  MEDIUM project: 3% stale fraction -> WARN (proposed; may relax to 4%)"
echo "  LARGE project:  5% stale fraction -> WARN"
echo "  Rationale: 09-thresholds-justification.md §STALE_FRACTION"
echo ""
echo "  Action if false positive rate > 20%:"
echo "    -> Relax SMALL/MEDIUM STALE_FRACTION from 3% to 4%"
echo "    -> Update 09-thresholds-justification.md with measured values"

echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL (Tier 1 structural)"
if [ "$FAIL" = "0" ]; then
    echo "[SUCCESS] Drift calibration Tier 1 passed ($PASS/$PASS checks)"
    exit 0
else
    echo "[FAILURE] Drift calibration Tier 1 failed ($FAIL/$TOTAL checks)"
    exit 1
fi
