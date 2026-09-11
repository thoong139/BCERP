#!/usr/bin/env bash
# QD7 fixture runner — invoke wf-fix-probe-static-deprecated.sh, measure precision/recall.
#
# DESIGN NOTE: Live probe covers 1/5 audit-spec probes: P-QD7-deprecated-api-usage.
#   - 3 detection categories: deprecated_api (JS/TS), deprecated_css (CSS), deprecated_pkg (package.json)
#   - 4 remaining probes (browser-compat, api-version, polyfill, device-breakpoint) = SPEC_GAP
#     (P-QD7-device-breakpoint-test: D15 CRITICAL heredoc PWEOF bug — cannot run as-spec'd)
#
# ACCURACY NOTE: This probe has overlapping patterns (e.g., execCommand matches both the
#   specific HIGH pattern AND the general MEDIUM pattern → 2 signals from 1 code line).
#   Precision/Recall is measured at FILE level, not signal count level:
#     TP = positive file with >= 1 signal emitted
#     FP = negative file with >= 1 signal emitted (must be 0)
#
# FINGERPRINT NOTE (D17): probe emits 6-token sha256 "QD7|file|line|probe_id|type|label"
#   vs signal-emit.md 5-token spec. Format is still sha256:<64-hex>.
#
# USAGE:
#   bash run.sh              # run probe on positive/ and negative/
#   bash run.sh --dry-run    # preflight only, do not invoke probe

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${1:-}"

echo "[run.sh] QD7 fixture — phase 3 (live probe = wf-fix-probe-static-deprecated.sh)"
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

if [ ! -d "positive" ] || [ ! -d "negative" ]; then
  echo "ERROR: positive/ or negative/ directory not found" >&2
  exit 1
fi

if [ ! -f "positive/package.json" ] || [ ! -f "negative/package.json" ]; then
  echo "ERROR: positive/package.json or negative/package.json not found" >&2
  exit 1
fi

# Locate probe via git root or relative fallback
PROBE_SCRIPT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/scripts/wf-fix-probe-static-deprecated.sh" ]; then
  PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-deprecated.sh"
fi
for candidate in \
  "../../../../.claude/scripts/wf-fix-probe-static-deprecated.sh" \
  "../../../../../.claude/scripts/wf-fix-probe-static-deprecated.sh"; do
  if [ -z "$PROBE_SCRIPT" ] && [ -f "$FIXTURE_DIR/$candidate" ]; then
    PROBE_SCRIPT="$(cd "$FIXTURE_DIR/$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    break
  fi
done

if [ -z "$PROBE_SCRIPT" ] || [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: cannot locate wf-fix-probe-static-deprecated.sh" >&2
  exit 1
fi

echo "[run.sh] PROBE_SCRIPT=$PROBE_SCRIPT"
echo "[run.sh] EXPECTED=$EXPECTED ($(jq '.signals | length' "$EXPECTED") expectations)"
echo "[run.sh] positive/: $(ls positive/*.ts positive/*.tsx positive/*.css 2>/dev/null | wc -l | tr -d ' ') code files + package.json"
echo "[run.sh] negative/: $(ls negative/*.ts negative/*.tsx negative/*.css 2>/dev/null | wc -l | tr -d ' ') code files + package.json"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[run.sh] --dry-run mode → preflight PASS, exit 0"
  exit 0
fi

SESSION_DIR="$(mktemp -d -t qd7-fixture-XXXXXX)"
ACTUAL_POS="$FIXTURE_DIR/.actual-signals-positive.json"
ACTUAL_NEG="$FIXTURE_DIR/.actual-signals-negative.json"
trap 'rm -rf "$SESSION_DIR"' EXIT

# ============================================================
# Step 1: Scan positive/ — expect all 5 positive files detected (TP_files = 5)
# Expected signals per category:
#   deprecated_api: pos-01 (execCommand HIGH+MEDIUM cascade), pos-02 (HIGH), pos-04 (CRITICAL)
#   deprecated_css: pos-03 (LOW × 2 occurrences)
#   deprecated_pkg: positive/package.json moment (MEDIUM)
# NOTE: signal COUNT > 5 due to overlapping patterns (cascade) — measure FILE-level detection
# ============================================================
echo ""
echo "[run.sh] --- Step 1: Scanning positive/ (expect all 5 source locations detected) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-compat" \
  --probe "P-QD7-deprecated-api-usage" \
  --profile "standard" \
  --source-dir "positive" \
  --package-json "positive/package.json" \
  > "$ACTUAL_POS"

POS_SIGNAL_COUNT="$(jq '.signals | length' "$ACTUAL_POS")"
echo "[run.sh] Positive scan: $POS_SIGNAL_COUNT total signal(s)"
jq -r '.signals[] | "  [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
  "$ACTUAL_POS" 2>/dev/null || true

# FILE-level TP: count unique source files with at least 1 signal
POS_FILES_DETECTED=$(jq -r '[.signals[].location.file] | unique | length' "$ACTUAL_POS" 2>/dev/null || echo 0)
echo "[run.sh] Positive files detected: $POS_FILES_DETECTED / 5 (file-level TP)"

# ============================================================
# Step 2: Scan negative/ — expect 0 signals (FP = 0)
# neg-01: navigator.clipboard (no deprecated pattern)
# neg-02: useEffect hook (no legacy lifecycle)
# neg-03: transform: scale() (no deprecated CSS)
# neg-04: Buffer.alloc/from (no deprecated constructor)
# package.json: date-fns, axios (not in deprecated list)
# ============================================================
echo ""
echo "[run.sh] --- Step 2: Scanning negative/ (expect 0 signals = 0 FP) ---"
bash "$PROBE_SCRIPT" \
  --session-dir "$SESSION_DIR" \
  --lane "wf-fix-compat" \
  --probe "P-QD7-deprecated-api-usage" \
  --profile "standard" \
  --source-dir "negative" \
  --package-json "negative/package.json" \
  > "$ACTUAL_NEG"

NEG_COUNT="$(jq '.signals | length' "$ACTUAL_NEG")"
echo "[run.sh] Negative scan: $NEG_COUNT signal(s) (expected: 0)"
if [ "$NEG_COUNT" -gt 0 ]; then
  echo "  [WARNING] False positive(s) detected:"
  jq -r '.signals[] | "  FP: [" + .severity + "] " + .location.file + ":" + (.location.line | tostring) + " — " + .title' \
    "$ACTUAL_NEG" || true
fi

# ============================================================
# Step 3: Accuracy summary (FILE-level P/R)
# ============================================================
echo ""
echo "[run.sh] --- Step 3: Accuracy summary (FILE-level measurement) ---"

TP_FILES="$POS_FILES_DETECTED"
FP_FILES="$NEG_COUNT"
FN_FILES=$((5 - POS_FILES_DETECTED))
[ "$FN_FILES" -lt 0 ] && FN_FILES=0
TN_FILES=$((5 - NEG_COUNT))
[ "$TN_FILES" -lt 0 ] && TN_FILES=0

echo "  File-level confusion matrix:"
echo "    TP_files (positive files w/ signal >= 1): $TP_FILES"
echo "    FP_files (negative files w/ signal >= 1): $FP_FILES"
echo "    FN_files (positive files with 0 signals): $FN_FILES"
echo "    TN_files (negative files with 0 signals): $TN_FILES"
echo ""
echo "  Total signals in positive scan: $POS_SIGNAL_COUNT (cascade — overlapping patterns)"
echo "  NOTE: signal count > file count due to overlapping regex patterns (see probe PATTERNS[] lines 56-74)"
echo ""

if [ $((TP_FILES + FP_FILES)) -gt 0 ]; then
  PREC_NUM=$((TP_FILES * 100 / (TP_FILES + FP_FILES)))
  echo "  Precision (file-level): $TP_FILES / $((TP_FILES + FP_FILES)) = 0.$PREC_NUM (DoD >= 0.70)"
else
  echo "  Precision (file-level): N/A (no signals emitted)"
  PREC_NUM=0
fi

RECALL_NUM=$((TP_FILES * 100 / 5))
echo "  Recall (file-level):    $TP_FILES / 5 = 0.$RECALL_NUM (DoD >= 0.60)"

# Fingerprint check — 6-token sha256 (D17)
FP_SAMPLE=$(jq -r '.signals[0].fingerprint // "NONE"' "$ACTUAL_POS" 2>/dev/null || echo "NONE")
echo ""
echo "  Fingerprint sample (signal 0): $FP_SAMPLE"
if echo "$FP_SAMPLE" | grep -qE '^sha256:[0-9a-f]{64}$'; then
  echo "  Fingerprint format: OK (sha256:<64-hex> from 6-token input — D17 documented)"
else
  echo "  Fingerprint format: WARN — expected sha256:<64-hex>"
fi

# Signal category breakdown
echo ""
echo "  Signal categories in positive scan:"
DEP_API=$(jq -r '[.signals[] | select(.title | startswith("Deprecated API"))] | length' "$ACTUAL_POS" 2>/dev/null || echo 0)
DEP_CSS=$(jq -r '[.signals[] | select(.title | startswith("Deprecated CSS"))] | length' "$ACTUAL_POS" 2>/dev/null || echo 0)
DEP_PKG=$(jq -r '[.signals[] | select(.title | startswith("Deprecated package"))] | length' "$ACTUAL_POS" 2>/dev/null || echo 0)
echo "    deprecated_api: $DEP_API signals (pos-01/02/04 — cascade expected for execCommand)"
echo "    deprecated_css: $DEP_CSS signals (pos-03 — 2 occurrences expected)"
echo "    deprecated_pkg: $DEP_PKG signals (positive/package.json — 1 expected)"

# SPEC_GAP notice
echo ""
echo "  SPEC_GAP (4/5 audit-spec probes not live-testable):"
echo "    P-QD7-browser-compat-check  : static grep only, no Playwright browser launch (D1)"
echo "    P-QD7-api-version-compat    : static grep only, no HTTP runtime version check (D1)"
echo "    P-QD7-polyfill-coverage     : browserslist runtime-only, no bash wrapper"
echo "    P-QD7-device-breakpoint-test: D15 CRITICAL heredoc PWEOF bug — fundamentally broken"

echo ""
if [ "$TP_FILES" -ge 4 ] && [ "$NEG_COUNT" -eq 0 ]; then
  echo "  VERDICT: PASS (TP_files >= 4, FP = 0)"
  exit 0
else
  echo "  VERDICT: FAIL (TP_files=$TP_FILES, FP=$NEG_COUNT)"
  exit 1
fi
