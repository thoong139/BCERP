#!/usr/bin/env bash
# QD5 fixture runner — invoke wf-fix-probe-static-a11y.sh, measure precision/recall.
#
# DESIGN NOTE: Must cd to FIXTURE_DIR before calling probe so grep returns relative
# paths like "positive/pos-01-img-no-alt.tsx" (no "fixtures/" prefix). Otherwise
# the probe's EXCLUDE_PATTERN matches "fixtures" and drops every signal.
#
# USAGE:
#   bash run.sh              # run probe on positive/ and negative/
#   bash run.sh --dry-run    # preflight only, do not invoke probe

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] QD5 fixture — phase 3 (live probe = wf-fix-probe-static-a11y.sh)"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

cd "$FIXTURE_DIR"

# ============================================================
# Preflight
# ============================================================
EXPECTED="$FIXTURE_DIR/expected-signals.json"
if [ ! -f "$EXPECTED" ]; then
  echo "ERROR: missing expected-signals.json" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found — install jq to run this fixture" >&2
  exit 1
fi

if ! jq -e '.signals | length >= 10' "$EXPECTED" >/dev/null 2>&1; then
  echo "ERROR: expected-signals.json must have >= 10 entries" >&2
  exit 1
fi

# Locate probe via git root or relative fallback
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-a11y.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-a11y.sh"
fi
for candidate in \
  "../../../../.claude/scripts/wf-fix-probe-static-a11y.sh" \
  "../../../../../.claude/scripts/wf-fix-probe-static-a11y.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-a11y.sh" >&2
  exit 1
fi

echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"
echo "[run.sh] EXPECTED=$EXPECTED ($(jq '.signals | length' "$EXPECTED") expectations)"
echo "[run.sh] positive/: $(ls positive/ 2>/dev/null | wc -l | tr -d ' ') files"
echo "[run.sh] negative/: $(ls negative/ 2>/dev/null | wc -l | tr -d ' ') files"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run mode → preflight PASS, exit 0"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t qd5-fixture-XXXXXX)"
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
  --lane "wf-fix-ux-a11y" \
  --probe "P-QD5-static-a11y-check" \
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
  --lane "wf-fix-ux-a11y" \
  --probe "P-QD5-static-a11y-check" \
  --profile "standard" \
  --source-dir "negative" \
  > "$ACTUAL_NEG"

NEG_COUNT="$(jq '.signals | length' "$ACTUAL_NEG")"
echo "[run.sh] Negative scan: $NEG_COUNT signal(s) (expected: 0)"
if [ "$NEG_COUNT" -gt 0 ]; then
  echo "  [WARNING] False positive(s) detected:"
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
[ "$FN" -lt 0 ] && FN=0
TN=$((5 - NEG_COUNT))
[ "$TN" -lt 0 ] && TN=0
TOTAL=$((TP + FP + FN + TN))

echo "  Confusion matrix:"
echo "    TP (correct positives):  $TP"
echo "    FP (false positives):    $FP"
echo "    FN (missed positives):   $FN"
echo "    TN (correct negatives):  $TN"
echo "    Total:                   $TOTAL"
echo ""

if [ $((TP + FP)) -gt 0 ]; then
  PREC_NUM=$((TP * 100 / (TP + FP)))
  echo "  Precision: $TP / $((TP + FP)) = 0.$PREC_NUM (DoD >= 0.70)"
else
  echo "  Precision: N/A (no signals emitted)"
  PREC_NUM=0
fi

RECALL_NUM=$((TP * 100 / 5))
echo "  Recall:    $TP / 5 = 0.$RECALL_NUM (DoD >= 0.60)"

# Fingerprint format check — probe hashes 5-token input "QD5|file|line|probe|issue_type"
# and emits "sha256:<64-hex>". So we verify the hash format rather than counting pipes.
FP_SAMPLE=$(jq -r '.signals[0].fingerprint // "NONE"' "$ACTUAL_POS" 2>/dev/null || echo "NONE")
echo ""
echo "  Fingerprint sample (signal 0): $FP_SAMPLE"
if echo "$FP_SAMPLE" | grep -qE '^sha256:[0-9a-f]{64}$'; then
  echo "  Fingerprint format: OK (sha256:<64-hex> from 5-token input QD5|file|line|probe|issue_type)"
else
  echo "  Fingerprint format: WARN — expected sha256:<64-hex>"
fi

# Issue-type coverage: confirm 5 distinct issue_types matched
ISSUE_TYPES_COUNT=$(jq -r '[.signals[] | .title] | unique | length' "$ACTUAL_POS" 2>/dev/null || echo 0)
echo "  Distinct issue types in positive scan: $ISSUE_TYPES_COUNT (expected: 5)"

echo ""
if [ "$POS_COUNT" -ge 4 ] && [ "$NEG_COUNT" -eq 0 ]; then
  echo "  VERDICT: PASS (positive emit >= 4, negative FP = 0)"
  exit 0
else
  echo "  VERDICT: FAIL (positive emit=$POS_COUNT, negative FP=$NEG_COUNT)"
  exit 1
fi
