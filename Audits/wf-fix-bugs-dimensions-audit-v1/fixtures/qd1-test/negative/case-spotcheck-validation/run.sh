#!/usr/bin/env bash
# REQ-ID: MCV3-TEST (IMP-008 acceptance test)
# case-spotcheck-validation/run.sh — Verify CORE-029 signal schema validation (IMP-008)
#
# Tests signal-validate.sh catches expected violations:
#   Test 1: SIG-001 description too short (12 chars < 50 min) → FAIL per-signal
#   Test 2: SIG-002 file_path non-existent → FAIL per-signal
#   Test 3: SIG-003 confidence = 1.5 → FAIL per-signal
#   Test 4: SIG-004 evidence missing code_snippet → FAIL per-signal
#   Test 5: SIG-005 all-valid signal → validate_signal_batch reports errors for above 4
#   Test 6: calc_sample_size(50) = 5 (min(10, floor(50*0.1)))
#   Test 7: calc_sample_size(120) = 10 (min(10, floor(120*0.1)=12))
#   Test 8: calc_sample_size(3) = 1 (min(10, floor(3*0.1)=0) → forced min 1)
#   Test 9: probe_validate_arg phantom probe → FAIL
#   Test 10: probe_validate_arg valid probe P-QD1-req-registry-xref → PASS
#
# PASS: all 10 checks pass → exit 0
# FAIL: any check fails → exit 1
#
# USAGE: bash run.sh

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$FIXTURE_DIR/../../../../../../../.." && pwd)"
fi

VALIDATE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-signal-validate.sh"
SIGNALS_FILE="$FIXTURE_DIR/invalid-signals.json"
DIM_QD1="$REPO_ROOT/.claude/skills/workflow/wf-fix-functional/dimension.json"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "PASS" ]; then
    echo "  ✅ PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "=== IMP-008 Acceptance Test: CORE-029 Signal Validation ==="
echo "    FIXTURE_DIR=$FIXTURE_DIR"
echo "    REPO_ROOT=$REPO_ROOT"
echo ""

# Source the validate script functions
# shellcheck source=/dev/null
source "$VALIDATE_SCRIPT"

# ── Per-signal validation unit tests ─────────────────────────────────────────

# Test 1: description too short (12 chars)
OUT=$(validate_signal_description "Short desc." 50 2>&1 || true)
if echo "$OUT" | grep -q "FAIL"; then
  check "SIG-001: description too short (12 < 50) → FAIL detected" "PASS"
else
  check "SIG-001: description too short (12 < 50) → FAIL detected" "FAIL"
fi

# Test 2: file_path non-existent
OUT=$(validate_signal_file_path "/nonexistent/path/that/does/not/exist.ts" 2>&1 || true)
if echo "$OUT" | grep -q "FAIL"; then
  check "SIG-002: file_path non-existent → FAIL detected" "PASS"
else
  check "SIG-002: file_path non-existent → FAIL detected" "FAIL"
fi

# Test 3: confidence = 1.5
OUT=$(validate_signal_confidence "1.5" 2>&1 || true)
if echo "$OUT" | grep -q "FAIL"; then
  check "SIG-003: confidence=1.5 out of range → FAIL detected" "PASS"
else
  check "SIG-003: confidence=1.5 out of range → FAIL detected" "FAIL"
fi

# Test 4: evidence missing code_snippet
OUT=$(validate_signal_code_snippet '{"log_excerpt":"Scanned 42 files"}' 2>&1 || true)
if echo "$OUT" | grep -q "FAIL"; then
  check "SIG-004: evidence missing code_snippet → FAIL detected" "PASS"
else
  check "SIG-004: evidence missing code_snippet → FAIL detected" "FAIL"
fi

# Test 5: batch validation catches 4 errors from invalid-signals.json
BATCH_OUT=$(validate_signal_batch "$SIGNALS_FILE" --sample-n 5 2>&1 || true)
# Use awk to count FAIL lines (avoids grep exit-code issues with set -e)
BATCH_ERRORS=$(echo "$BATCH_OUT" | awk '/FAIL/ {c++} END {print c+0}')
echo "    Batch validation output:"
echo "$BATCH_OUT" | sed 's/^/      /'
echo "    Error count: $BATCH_ERRORS"
if [ "$BATCH_ERRORS" -ge 4 ]; then
  check "Batch validation: caught ≥4 errors in invalid-signals.json" "PASS"
else
  check "Batch validation: caught ≥4 errors (got $BATCH_ERRORS)" "FAIL"
fi

# ── calc_sample_size tests ────────────────────────────────────────────────────

# Test 6: calc_sample_size(50) = 5
SZ=$(calc_sample_size 50)
if [ "$SZ" -eq 5 ]; then
  check "calc_sample_size(50) = 5 (min(10, floor(50*0.1)))" "PASS"
else
  check "calc_sample_size(50) = 5 (got $SZ)" "FAIL"
fi

# Test 7: calc_sample_size(120) = 10 (capped at 10)
SZ=$(calc_sample_size 120)
if [ "$SZ" -eq 10 ]; then
  check "calc_sample_size(120) = 10 (capped at max)" "PASS"
else
  check "calc_sample_size(120) = 10 (got $SZ)" "FAIL"
fi

# Test 8: calc_sample_size(3) = 1 (floor(0.3) → 0 → forced min 1)
SZ=$(calc_sample_size 3)
if [ "$SZ" -eq 1 ]; then
  check "calc_sample_size(3) = 1 (floor(0.3)=0 → forced min 1)" "PASS"
else
  check "calc_sample_size(3) = 1 (got $SZ)" "FAIL"
fi

# ── probe_validate_arg tests ──────────────────────────────────────────────────

# Create minimal dim.json for probe validation tests (avoid Windows path issues)
TMP_DIM=$(mktemp -t tmp_dim_XXXXXX.json 2>/dev/null || echo "/tmp/tmp_dim_test.json")
cat > "$TMP_DIM" << 'ENDDIM'
{
  "$schema": "dimension-v1",
  "dimension_id": "QD1",
  "probes": [
    {"id": "P-QD1-req-registry-xref"},
    {"id": "P-QD1-route-config-parse"},
    {"id": "P-QD1-api-smoke"}
  ]
}
ENDDIM

# Test 9: phantom probe → FAIL
OUT=$(probe_validate_arg "P-QD1-phantom-probe-does-not-exist" "$TMP_DIM" 2>&1 || true)
if echo "$OUT" | grep -q "FAIL"; then
  check "probe_validate_arg phantom probe → FAIL detected" "PASS"
else
  check "probe_validate_arg phantom probe → FAIL detected" "FAIL"
fi

# Test 10: valid probe → no FAIL
if probe_validate_arg "P-QD1-req-registry-xref" "$TMP_DIM" > /dev/null 2>&1; then
  check "probe_validate_arg valid probe P-QD1-req-registry-xref → PASS" "PASS"
else
  check "probe_validate_arg valid probe P-QD1-req-registry-xref → PASS" "FAIL"
fi

rm -f "$TMP_DIM" 2>/dev/null || true

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
if [ "$FAIL" -eq 0 ]; then
  echo "  VERDICT: PASS — IMP-008 acceptance criteria met"
  exit 0
else
  echo "  VERDICT: FAIL — $FAIL check(s) failed"
  exit 1
fi
