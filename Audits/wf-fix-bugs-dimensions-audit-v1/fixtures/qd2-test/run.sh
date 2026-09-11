#!/usr/bin/env bash
# run.sh — Execute QD2 static-business probe against fixture source files and validate results.
#
# DESIGN: Must cd to THIS directory before running the probe.
# Reason: bash probe EXCLUDE pattern blocks paths containing "fixtures/".
# By running with --source-dir . from fixtures/qd2-test/, grep outputs paths like
# "./positive/pos-01.../OrderCommandHandler.cs" which do NOT contain "fixtures/" → EXCLUDE passes.
#
# USAGE:
#   bash run.sh [standard|deep|exhaustive]
#   (default: exhaustive — runs all 4 CHECKs, expected 5 signals)
#
# EXIT: 0 = all assertions PASS, 1 = assertion FAIL or probe error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-business.sh"
PROFILE="${1:-exhaustive}"

if [ ! -f "$PROBE_SCRIPT" ]; then
  echo "ERROR: probe script not found: $PROBE_SCRIPT" >&2
  exit 1
fi

# CRITICAL: cd to fixture dir so --source-dir . produces paths WITHOUT "fixtures/" component
cd "$SCRIPT_DIR"

echo "=== QD2 Fixture Run ==="
echo "  Probe   : $PROBE_SCRIPT"
echo "  Profile : $PROFILE"
echo "  CWD     : $SCRIPT_DIR"
echo "  Source  : . (relative, so grep output avoids fixtures/ in path)"
echo ""

OUTPUT=$(bash "$PROBE_SCRIPT" \
  --source-dir . \
  --profile "$PROFILE" \
  --session-dir /tmp \
  2>&1)

if ! echo "$OUTPUT" | jq '.' > /dev/null 2>&1; then
  echo "ERROR: probe did not emit valid JSON" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

SIGNAL_COUNT=$(echo "$OUTPUT" | jq '.signals | length')
echo "Total signals emitted: $SIGNAL_COUNT"
echo "(Expected exhaustive=5: pos-01 CHECK1 + pos-02 CHECK2 + pos-03 CHECK3 + pos-04 CHECK4 + pos-05 CHECK4)"
echo ""

PASS=0
FAIL=0

check_signal() {
  local title="$1" file_suffix="$2"
  if echo "$OUTPUT" | jq -e --arg t "$title" --arg fs "$file_suffix" \
    '.signals[] | select(.title == $t) | select(.location.file | endswith($fs))' \
    > /dev/null 2>&1; then
    echo "  PASS  $title ($file_suffix)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  MISSING: $title ($file_suffix)"
    echo "        (available titles: $(echo "$OUTPUT" | jq -r '.signals[].title' 2>/dev/null | sort -u | tr '\n' '|'))"
    FAIL=$((FAIL + 1))
  fi
}

check_no_signal() {
  local file_suffix="$1" reason="$2"
  if echo "$OUTPUT" | jq -e --arg fs "$file_suffix" \
    '.signals[] | select(.location.file | endswith($fs))' \
    > /dev/null 2>&1; then
    echo "  FAIL  FALSE POSITIVE: signal found for $file_suffix"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS  No signal for $file_suffix  ($reason)"
    PASS=$((PASS + 1))
  fi
}

echo "--- Positive cases (expect signal) ---"
check_signal "Anti-pattern: throw in CommandHandler"   "OrderCommandHandler.cs"
check_signal "Endpoint thieu auth"                     "CartEndpoints.cs"
check_signal "Command thieu Validator"                 "CreateOrderCommand.cs"
check_signal "Magic number trong business logic"       "OrderPolicy.cs"
check_signal "Magic number trong business logic"       "RetryPolicy.cs"

echo ""
echo "--- Negative cases (expect NO signal) ---"
check_no_signal "CreateProductCommandHandler.cs"  "correct railway pattern"
check_no_signal "ProductEndpoints.cs"             "has RequireAuthorization"
check_no_signal "UpdateOrderCommand.cs"           "validator exists adjacent"
check_no_signal "orderService.ts"                 ".ts excluded by --include=*.cs"
check_no_signal "CacheService.cs"                 "Services/ layer, not Domain/Application/"

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $((PASS + FAIL)) TOTAL ==="
echo ""
echo "--- Predicted confusion matrix (exhaustive) ---"
echo "  TP=5 FP=0 FN=0 TN=5"
echo "  Precision=1.00 Recall=1.00 F1=1.00"
echo "  DoD: P>=0.70 R>=0.60 F1>=0.65 FP=0"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "PASS  All fixture checks PASSED — DoD MET"
  exit 0
else
  echo "FAIL  $FAIL check(s) FAILED — investigate above"
  exit 1
fi
