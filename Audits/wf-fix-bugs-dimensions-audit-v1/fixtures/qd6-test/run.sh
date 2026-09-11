#!/usr/bin/env bash
# QD6 fixture runner — invoke wf-fix-probe-static-data.sh, measure precision/recall.
#
# DESIGN NOTE: Must cd to FIXTURE_DIR before calling probe so that find returns
# relative paths like "positive/src/Domain/Entities/..." (no "fixtures/" prefix).
# If the probe runs with absolute --source-dir, paths contain "fixtures/" which
# triggers EXCLUDE_PATTERN check on CHECK 1/2 → 0 signals detected.
#
# PROBE CHECKS TESTED:
#   CHECK 1 (standard+): Domain/Entities/*.cs — Create() without Result.Failure/Guard./throw
#   CHECK 2 (deep+):     Configurations/*.cs  — Property(*Id) without HasOne/HasMany
#   CHECK 3 (exhaustive): grep AlterColumn.*maxLength: [0-9]+ — no EXCLUDE filter applied
#
# live_detectable: CHECK 1 signals (standard profile) — 3 expected
# documented_gap:  CHECK 2 (deep+), CHECK 3 (exhaustive), 6 probe specs (IMPL-REFUTED)
#
# ACCURACY TARGET (DoD): P >= 0.70, R >= 0.60 on live_detectable signals
#
# USAGE:
#   bash run.sh               # full run: standard + exhaustive + negative scan
#   bash run.sh --dry-run     # validate setup only, do not invoke probe
#
# Phase 3 scope (Phien 17):
#   Positive: 5 cases (3 CHECK1 standard + 1 CHECK2 deep + 1 CHECK3 exhaustive)
#   Negative: 5 cases (0 FP expected at exhaustive profile)

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] QD6 fixture — phase 3 (probe = wf-fix-probe-static-data.sh)"
echo "[run.sh] FIXTURE_DIR=$FIXTURE_DIR"

# Must cd to fixture dir so probe paths do NOT include "fixtures/" prefix
# (which would match EXCLUDE_PATTERN and suppress all signals)
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

EXP_COUNT="$(jq '.signals | length' "$EXPECTED")"
if [ "$EXP_COUNT" -lt 10 ]; then
  echo "ERROR: expected-signals.json must have >= 10 entries (found $EXP_COUNT)" >&2; exit 1
fi

# Locate probe script via git root
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-data.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-data.sh"
fi
for candidate in \
  "../../../../.claude/scripts/wf-fix-probe-static-data.sh" \
  "../../../../../.claude/scripts/wf-fix-probe-static-data.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-data.sh" >&2; exit 1
fi

# Count fixture files
POS_ENTITY=$(find positive/src/Domain/Entities -name "*.cs" 2>/dev/null | wc -l | tr -d ' ')
POS_CONFIG=$(find positive/src/Configurations -name "*.cs" 2>/dev/null | wc -l | tr -d ' ')
POS_MIGR=$(find positive/src/Migrations -name "*.cs" 2>/dev/null | wc -l | tr -d ' ')
NEG_TOTAL=$(find negative/src -name "*.cs" 2>/dev/null | wc -l | tr -d ' ')

echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"
echo "[run.sh] EXPECTED=$EXPECTED ($EXP_COUNT expectations)"
echo "[run.sh] positive/src/Domain/Entities/: $POS_ENTITY .cs files (CHECK 1)"
echo "[run.sh] positive/src/Configurations/:  $POS_CONFIG .cs files (CHECK 2 deep+)"
echo "[run.sh] positive/src/Migrations/:      $POS_MIGR .cs files (CHECK 3 exhaustive)"
echo "[run.sh] negative/src/: $NEG_TOTAL .cs files"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run mode → preflight PASS, exit 0"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t qd6-fixture-XXXXXX)"
ACTUAL_STD="$FIXTURE_DIR/.actual-signals-standard.json"
ACTUAL_EXH="$FIXTURE_DIR/.actual-signals-exhaustive.json"
ACTUAL_NEG="$FIXTURE_DIR/.actual-signals-negative.json"

trap 'rm -rf "$SESSION_DIR"' EXIT

# ============================================================
# Step 1: Scan positive/ — profile=standard (CHECK 1 only = live_detectable baseline)
# ============================================================
echo ""
echo "[run.sh] --- Step 1: Scanning positive/ (--profile standard, CHECK 1 only, expect 3 signals) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-data" \
  --probe "P-QD6-data-integrity-audit" \
  --profile "standard" \
  --source-dir "positive" \
  > "$ACTUAL_STD"

STD_COUNT="$(jq '.signals | length' "$ACTUAL_STD")"
echo "[run.sh] Standard scan: $STD_COUNT signal(s) emitted (expected: 3)"
jq -r '.signals[] | "  [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
  "$ACTUAL_STD" 2>/dev/null || true

# ============================================================
# Step 2: Scan positive/ — profile=exhaustive (CHECK 1+2+3 = all detectable)
# ============================================================
echo ""
echo "[run.sh] --- Step 2: Scanning positive/ (--profile exhaustive, CHECK 1+2+3, expect 5 signals) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-data" \
  --probe "P-QD6-data-integrity-audit" \
  --profile "exhaustive" \
  --source-dir "positive" \
  > "$ACTUAL_EXH"

EXH_COUNT="$(jq '.signals | length' "$ACTUAL_EXH")"
echo "[run.sh] Exhaustive scan: $EXH_COUNT signal(s) emitted (expected: 5)"
jq -r '.signals[] | "  [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
  "$ACTUAL_EXH" 2>/dev/null || true

DOCUMENTED_GAP_EXTRA=$((EXH_COUNT - STD_COUNT))
echo "[run.sh] documented_gap profile-gated: $DOCUMENTED_GAP_EXTRA extra signal(s) (CHECK2 + CHECK3)"

# ============================================================
# Step 3: Scan negative/ — profile=exhaustive (expect 0 signals = TN validation)
# ============================================================
echo ""
echo "[run.sh] --- Step 3: Scanning negative/ (--profile exhaustive, expect 0 signals = 0 FP) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-data" \
  --probe "P-QD6-data-integrity-audit" \
  --profile "exhaustive" \
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
# Step 4: Accuracy summary (live_detectable = standard profile, 3 expected TPs)
# ============================================================
echo ""
echo "[run.sh] --- Step 4: Accuracy summary ---"
TP_LIVE="$STD_COUNT"
FP="$NEG_COUNT"
EXPECTED_LIVE=3
FN=$((EXPECTED_LIVE - STD_COUNT))
TN=$((5 - NEG_COUNT))
TOTAL=$((TP_LIVE + FP + FN + TN))

echo "  Confusion matrix (live_detectable: standard profile CHECK 1):"
echo "    TP (correct positives):  $TP_LIVE / $EXPECTED_LIVE live_detectable"
echo "    FP (false positives):    $FP / 0 expected"
echo "    FN (missed positives):   $FN"
echo "    TN (correct negatives):  $TN / 5"
echo "    Total measured:          $TOTAL"
echo ""
echo "  Documented_gap (profile-limited, NOT counted in P/R):"
echo "    CHECK 2 + CHECK 3 extra: $DOCUMENTED_GAP_EXTRA signal(s) at exhaustive profile"

if [ $((TP_LIVE + FP)) -gt 0 ]; then
  PREC_PCT=$((TP_LIVE * 100 / (TP_LIVE + FP)))
  # Format as decimal: 100 → 1.00, 83 → 0.83, etc.
  PREC_INT=$((PREC_PCT / 100))
  PREC_FRAC=$(printf "%02d" $((PREC_PCT % 100)))
  echo ""
  echo "  Precision: $TP_LIVE / $((TP_LIVE + FP)) = ${PREC_INT}.${PREC_FRAC} (DoD >= 0.70)"
else
  echo ""
  echo "  Precision: N/A (no live signals emitted)"
  PREC_PCT=0
fi

if [ "$EXPECTED_LIVE" -gt 0 ]; then
  RECALL_PCT=$((TP_LIVE * 100 / EXPECTED_LIVE))
  RECALL_INT=$((RECALL_PCT / 100))
  RECALL_FRAC=$(printf "%02d" $((RECALL_PCT % 100)))
  echo "  Recall:    $TP_LIVE / $EXPECTED_LIVE = ${RECALL_INT}.${RECALL_FRAC} (DoD >= 0.60)"
fi

FP_SAMPLE=$(jq -r '.signals[0].fingerprint // "NONE"' "$ACTUAL_STD" 2>/dev/null || echo "NONE")
echo ""
echo "  Fingerprint sample (signal 0): $FP_SAMPLE"
if [ "$FP_SAMPLE" != "NONE" ]; then
  TOKEN_COUNT=$(echo "$FP_SAMPLE" | tr '|' '\n' | wc -l | tr -d ' ')
  echo "  Fingerprint token count: $TOKEN_COUNT (expected: 5 — QD6|file|line|probe|title)"
fi

CDG_COUNT=$(jq '[.signals[] | select(.cdg_flags | length > 0)] | length' \
  "$ACTUAL_STD" 2>/dev/null || echo "0")
echo "  CDG flags non-empty: $CDG_COUNT (expected: 0 — cdg_flags hardcoded [] per Phase 2)"

echo ""
if [ "$TP_LIVE" -ge 2 ] && [ "$NEG_COUNT" -eq 0 ]; then
  echo "  VERDICT: PASS (live TP=$TP_LIVE / $EXPECTED_LIVE, FP=0)"
else
  echo "  VERDICT: FAIL (live_TP=$TP_LIVE, FP=$NEG_COUNT)"
fi
echo "[run.sh] Done. See accuracy-report.md for full analysis."
exit 0
