#!/usr/bin/env bash
# QD3 fixture runner — invoke wf-fix-probe-static-secret.sh, measure precision/recall.
#
# DESIGN NOTE: Must cd to FIXTURE_DIR before calling probe so that grep returns
# relative paths like "positive/pos-01-aws-key.ts" (no "fixtures/" prefix).
# If the probe runs with an absolute --source-dir, grep returns absolute paths
# containing "fixtures/" which triggers EXCLUDE_PATTERN → 0 signals detected.
#
# USAGE:
#   bash run.sh                 # run probe on positive/ + negative/
#   bash run.sh --dry-run       # validate setup only, do not invoke probe
#
# Phase 3 scope:
#   Phien 12 — live signals from P-QD3-secret-detection on positive/ (5 expected).
#   Negative scan on negative/ — verify 0 FP (5 expected TN).
#   Documented_gap: 6 SPEC-ONLY probes (no bash) not measurable.

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] QD3 fixture — phase 3 (live probe = P-QD3-secret-detection)"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Must cd to fixture dir so grep paths do NOT include "fixtures/" prefix
# (which would match EXCLUDE_PATTERN and drop all signals)
cd "$FIXTURE_DIR"

# ============================================================
# Preflight checks
# ============================================================
EXPECTED="$FIXTURE_DIR/expected-signals.json"
if [ ! -f "$EXPECTED" ]; then
  echo "ERROR: missing expected-signals.json" >&2; exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found — install jq to run this fixture" >&2; exit 1
fi

if ! jq -e '.signals | length >= 10' "$EXPECTED" >/dev/null 2>&1; then
  echo "ERROR: expected-signals.json must have >= 10 entries" >&2; exit 1
fi

# Locate probe script via git root
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-secret.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-secret.sh"
fi
# Fallback: relative path from fixture dir (5 levels up to repo root)
for candidate in \
  "../../../../.claude/scripts/wf-fix-probe-static-secret.sh" \
  "../../../../../.claude/scripts/wf-fix-probe-static-secret.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-secret.sh" >&2; exit 1
fi

echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"
echo "[run.sh] EXPECTED=$EXPECTED ($(jq '.signals | length' "$EXPECTED") expectations)"
echo "[run.sh] positive/: $(ls positive/*.ts positive/*.js positive/*.py 2>/dev/null | wc -l | tr -d ' ') source files"
echo "[run.sh] negative/: $(ls negative/ 2>/dev/null | wc -l | tr -d ' ') files"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run mode → preflight PASS, exit 0"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t qd3-fixture-XXXXXX)"
ACTUAL_POS="$FIXTURE_DIR/.actual-signals-positive.json"
ACTUAL_NEG="$FIXTURE_DIR/.actual-signals-negative.json"

trap 'rm -rf "$SESSION_DIR"' EXIT

# ============================================================
# Step 1: Scan positive/ — expect 5 signals (TP)
# ============================================================
echo ""
echo "[run.sh] --- Step 1: Scanning positive/ (expect 5 signals) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-security" \
  --probe "P-QD3-secret-detection" \
  --profile "standard" \
  --source-dir "positive" \
  > "$ACTUAL_POS"

POS_COUNT="$(jq '.signals | length' "$ACTUAL_POS")"
echo "[run.sh] Positive scan: $POS_COUNT signal(s) emitted (expected: 5)"
jq -r '.signals[] | "  [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
  "$ACTUAL_POS" 2>/dev/null || true

# ============================================================
# Step 2: Scan negative/ — expect 0 signals (TN)
# ============================================================
echo ""
echo "[run.sh] --- Step 2: Scanning negative/ (expect 0 signals = 0 FP) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-security" \
  --probe "P-QD3-secret-detection" \
  --profile "standard" \
  --source-dir "negative" \
  > "$ACTUAL_NEG"

NEG_COUNT="$(jq '.signals | length' "$ACTUAL_NEG")"
echo "[run.sh] Negative scan: $NEG_COUNT signal(s) (expected: 0)"
if [ "$NEG_COUNT" -gt 0 ]; then
  echo "  [WARNING] False Positive(s) detected:"
  jq -r '.signals[] | "  FP: [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
    "$ACTUAL_NEG" || true
fi

# ============================================================
# Step 3: Accuracy summary
# ============================================================
echo ""
echo "[run.sh] --- Step 3: Accuracy summary ---"
TP="$POS_COUNT"
FP="$NEG_COUNT"
FN=$((5 - POS_COUNT))
TN=$((5 - NEG_COUNT))
TOTAL=$((TP + FP + FN + TN))

echo "  Confusion matrix:"
echo "    TP (correct positives):  $TP"
echo "    FP (false positives):    $FP"
echo "    FN (missed positives):   $FN"
echo "    TN (correct negatives):  $TN"
echo "    Total:                   $TOTAL"
echo ""

if [ $((TP + FP)) -gt 0 ]; then
  # Integer precision * 100 for display
  PREC_NUM=$((TP * 100 / (TP + FP)))
  echo "  Precision: $TP / $((TP + FP)) = 0.$PREC_NUM (DoD >= 0.70)"
else
  echo "  Precision: N/A (no signals emitted)"
  PREC_NUM=0
fi

RECALL_NUM=$((TP * 100 / 5))
echo "  Recall:    $TP / 5 = 0.$RECALL_NUM (DoD >= 0.60)"

# CDG verification
CDG_COUNT=$(jq '[.signals[] | select(.cdg_flags | contains(["CDG-SECURITY-LIVE"]))] | length' \
  "$ACTUAL_POS" 2>/dev/null || echo "0")
echo ""
echo "  CDG-SECURITY-LIVE attached: $CDG_COUNT / $POS_COUNT signal(s)"

# Fingerprint format spot check
FP_SAMPLE=$(jq -r '.signals[0].fingerprint // "NONE"' "$ACTUAL_POS" 2>/dev/null || echo "NONE")
echo "  Fingerprint sample (signal 0): $FP_SAMPLE"
TOKEN_COUNT=$(echo "$FP_SAMPLE" | tr '|' '\n' | wc -l | tr -d ' ')
echo "  Fingerprint token count: $TOKEN_COUNT (expected: 6)"

echo ""
if [ "$POS_COUNT" -ge 4 ] && [ "$NEG_COUNT" -eq 0 ]; then
  echo "  VERDICT: PASS (emit >= 4, FP = 0)"
else
  echo "  VERDICT: FAIL (emit=$POS_COUNT, FP=$NEG_COUNT)"
fi
echo "[run.sh] Done. See accuracy-report.md for full analysis."
exit 0
