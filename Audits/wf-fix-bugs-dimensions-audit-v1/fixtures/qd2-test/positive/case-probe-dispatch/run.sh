#!/usr/bin/env bash
# IMP-025 acceptance test — case-probe-dispatch/ (QD2)
#
# Tests case "$PROBE_ID" dispatch in wf-fix-probe-static-business.sh:
#   1. P-QD2-calculation-check exits 0
#   2. P-QD2-calculation-check emits railway/throw signal (not hardcoded-value)
#   3. P-QD2-hardcoded-value-detect exits 0
#   4. P-QD2-hardcoded-value-detect emits 0 signals (exhaustive needed for magic numbers)
#   5. P-QD2-domain-expert-review exits 0 with SPEC-ONLY-PROBE-SKIP (agent probe)
#   6. Unknown probe ID exits 1 (fail-fast)
#   7. probe_id field matches --probe arg in output
#   8. Signal count isolation: calculation-check does NOT emit hardcoded-value signals
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-probe-dispatch] IMP-025 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-business.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: wf-fix-probe-static-business.sh not found" >&2; exit 1
fi

# Copy source files to a temp dir outside the fixtures/ path (avoid EXCLUDE pattern)
TMP_SRC=$(mktemp -d 2>/dev/null || echo "/tmp/qd2-dispatch-src-$$")
cleanup() { rm -rf "$TMP_SRC"; }
trap cleanup EXIT
cp -r "$FIXTURE_DIR/src/." "$TMP_SRC/"
SRC="$TMP_SRC"

# ============================================================
# Test 1: P-QD2-calculation-check exits 0
# ============================================================
echo ""
echo "--- Test 1: P-QD2-calculation-check exits 0 ---"
if bash "$SCRIPT" --probe P-QD2-calculation-check --source-dir "$SRC" 2>/dev/null | jq '.' >/dev/null 2>&1; then
  echo "  PASS: exit 0 + valid JSON"
else
  echo "  FAIL: non-zero exit or invalid JSON"
  exit 1
fi

# ============================================================
# Test 2: calculation-check finds railway/throw signal
# ============================================================
echo ""
echo "--- Test 2: P-QD2-calculation-check emits throw/railway signal ---"
calc_out=$(bash "$SCRIPT" --probe P-QD2-calculation-check --source-dir "$SRC" 2>/dev/null)
calc_sigs=$(echo "$calc_out" | jq '.signals | length')
if [ "$calc_sigs" -ge 1 ]; then
  title=$(echo "$calc_out" | jq -r '.signals[0].title // ""')
  echo "  PASS: $calc_sigs signal(s), first title: $title"
else
  echo "  FAIL: expected ≥1 signals, got $calc_sigs"
  exit 1
fi

# ============================================================
# Test 3: P-QD2-hardcoded-value-detect exits 0
# ============================================================
echo ""
echo "--- Test 3: P-QD2-hardcoded-value-detect exits 0 ---"
if bash "$SCRIPT" --probe P-QD2-hardcoded-value-detect --source-dir "$SRC" 2>/dev/null | jq '.' >/dev/null 2>&1; then
  echo "  PASS: exit 0 + valid JSON"
else
  echo "  FAIL: non-zero exit or invalid JSON"
  exit 1
fi

# ============================================================
# Test 4: hardcoded-value-detect emits 0 signals (standard profile — magic numbers need exhaustive)
# ============================================================
echo ""
echo "--- Test 4: hardcoded-value-detect standard profile = 0 signals (needs exhaustive) ---"
hv_out=$(bash "$SCRIPT" --probe P-QD2-hardcoded-value-detect --source-dir "$SRC" --profile standard 2>/dev/null)
hv_sigs=$(echo "$hv_out" | jq '.signals | length')
if [ "$hv_sigs" -eq 0 ]; then
  echo "  PASS: 0 signals in standard profile (magic numbers require exhaustive)"
else
  echo "  FAIL: expected 0 signals in standard, got $hv_sigs"
  exit 1
fi

# ============================================================
# Test 5: P-QD2-domain-expert-review = SPEC-ONLY-PROBE-SKIP
# ============================================================
echo ""
echo "--- Test 5: P-QD2-domain-expert-review = SPEC-ONLY-PROBE-SKIP ---"
agent_out=$(bash "$SCRIPT" --probe P-QD2-domain-expert-review --source-dir "$SRC" 2>/dev/null)
agent_status=$(echo "$agent_out" | jq -r '.probe_status // ""')
if [ "$agent_status" = "SPEC-ONLY-PROBE-SKIP" ]; then
  echo "  PASS: probe_status = SPEC-ONLY-PROBE-SKIP"
else
  echo "  FAIL: probe_status = '$agent_status' (expected SPEC-ONLY-PROBE-SKIP)"
  exit 1
fi

# ============================================================
# Test 6: Unknown probe ID exits 1
# ============================================================
echo ""
echo "--- Test 6: unknown probe ID exits 1 ---"
if bash "$SCRIPT" --probe P-QD2-nonexistent-probe --source-dir "$SRC" 2>/dev/null; then
  echo "  FAIL: should have exited 1 for unknown probe"
  exit 1
fi
echo "  PASS: unknown probe exits non-zero (fail-fast)"

# ============================================================
# Test 7: probe_id field matches --probe arg
# ============================================================
echo ""
echo "--- Test 7: probe_id matches --probe arg ---"
pid=$(bash "$SCRIPT" --probe P-QD2-calculation-check --source-dir "$SRC" 2>/dev/null | jq -r '.probe_id // ""')
if [ "$pid" = "P-QD2-calculation-check" ]; then
  echo "  PASS: probe_id = P-QD2-calculation-check"
else
  echo "  FAIL: probe_id = '$pid' (expected P-QD2-calculation-check)"
  exit 1
fi

# ============================================================
# Test 8: isolation — calculation-check does NOT emit hardcoded-value signals
# ============================================================
echo ""
echo "--- Test 8: calculation-check does not emit hardcoded-value signals ---"
calc_sigs_count=$(echo "$calc_out" | jq '[.signals[] | select(.title | test("Magic|hardcoded"; "i"))] | length')
if [ "$calc_sigs_count" -eq 0 ]; then
  echo "  PASS: no magic-number signals in P-QD2-calculation-check output"
else
  echo "  FAIL: found $calc_sigs_count magic/hardcoded signal(s) in calculation-check output (should not cross-run)"
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  P-QD2-calculation-check dispatch: PASS ($calc_sigs signal(s))"
echo "  P-QD2-hardcoded-value-detect dispatch: PASS (0 in standard)"
echo "  Agent probe SPEC-ONLY-PROBE-SKIP: PASS"
echo "  Unknown probe fail-fast: PASS"
echo "  Probe ID isolation: PASS"
exit 0
