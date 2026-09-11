#!/usr/bin/env bash
# IMP-022 acceptance test — case-lane-bus-translation/
#
# Tests wf-fix-lane-to-bus.py translator:
#   1. Translator exits 0 on valid input
#   2. Output has $schema = "lane-signals-v1-translated"
#   3. signal_count = 2
#   4. severity → suggested_severity (HIGH → high, critical → critical)
#   5. location → target with kind="source_location"
#   6. evidence[array] → evidence{dict} (not array)
#   7. fingerprint → dedup_hints[0] preserved
#   8. emitted_at is present in each translated signal
#   9. --validate flag passes on translated output
#  10. --format signals returns array (not envelope)
#  11. Canonical 5-token fingerprint generated when fingerprint absent
#  12. --validate fails on lane-format input (evidence is array)
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-lane-bus-translation] IMP-022 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

TRANSLATOR="$REPO_ROOT/.claude/scripts/wf-fix-lane-to-bus.py"
INPUT="$FIXTURE_DIR/lane-signals-input.json"
TMP_OUT=$(mktemp 2>/dev/null || echo "/tmp/bus-signals-$$")
TMP_ARR=$(mktemp 2>/dev/null || echo "/tmp/bus-array-$$")
TMP_NOFP=$(mktemp 2>/dev/null || echo "/tmp/bus-nofp-$$")

if [ ! -f "$TRANSLATOR" ]; then
  echo "FAIL: wf-fix-lane-to-bus.py not found at $TRANSLATOR" >&2
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  echo "FAIL: lane-signals-input.json not found" >&2
  exit 1
fi

cleanup() { rm -f "$TMP_OUT" "$TMP_ARR" "$TMP_NOFP"; }
trap cleanup EXIT

# ============================================================
# Test 1: translator exits 0
# ============================================================
echo ""
echo "--- Test 1: translator exits 0 ---"
if python3 "$TRANSLATOR" --input "$INPUT" --output "$TMP_OUT" 2>/dev/null; then
  echo "  PASS: exit 0"
else
  echo "  FAIL: translator returned non-zero"
  exit 1
fi

# ============================================================
# Test 2: $schema = lane-signals-v1-translated
# ============================================================
echo ""
echo "--- Test 2: \$schema = lane-signals-v1-translated ---"
schema=$(jq -r '."$schema" // ""' "$TMP_OUT")
if [ "$schema" = "lane-signals-v1-translated" ]; then
  echo "  PASS: \$schema = $schema"
else
  echo "  FAIL: \$schema = '$schema'"
  exit 1
fi

# ============================================================
# Test 3: signal_count = 2
# ============================================================
echo ""
echo "--- Test 3: signal_count = 2 ---"
sig_count=$(jq '.signal_count' "$TMP_OUT")
if [ "$sig_count" -eq 2 ]; then
  echo "  PASS: signal_count = 2"
else
  echo "  FAIL: signal_count = $sig_count"
  exit 1
fi

# ============================================================
# Test 4: severity → suggested_severity
# ============================================================
echo ""
echo "--- Test 4: severity → suggested_severity ---"
sev0=$(jq -r '.signals[0].suggested_severity // ""' "$TMP_OUT")
sev1=$(jq -r '.signals[1].suggested_severity // ""' "$TMP_OUT")
if [ "$sev0" = "high" ] && [ "$sev1" = "critical" ]; then
  echo "  PASS: signals[0].suggested_severity=high, signals[1].suggested_severity=critical"
else
  echo "  FAIL: sev0='$sev0' sev1='$sev1' (expected high, critical)"
  exit 1
fi

# ============================================================
# Test 5: location → target with kind=source_location
# ============================================================
echo ""
echo "--- Test 5: location → target.kind=source_location ---"
t0_kind=$(jq -r '.signals[0].target.kind // ""' "$TMP_OUT")
t0_file=$(jq -r '.signals[0].target.file // ""' "$TMP_OUT")
if [ "$t0_kind" = "source_location" ] && [ -n "$t0_file" ]; then
  echo "  PASS: target.kind=source_location, file=$t0_file"
else
  echo "  FAIL: target.kind='$t0_kind' file='$t0_file'"
  exit 1
fi

# ============================================================
# Test 6: evidence is dict (not array)
# ============================================================
echo ""
echo "--- Test 6: evidence is object (not array) ---"
ev_type=$(jq -r '.signals[0].evidence | type' "$TMP_OUT")
if [ "$ev_type" = "object" ]; then
  echo "  PASS: evidence type = object"
else
  echo "  FAIL: evidence type = '$ev_type' (expected object)"
  exit 1
fi

# ============================================================
# Test 7: fingerprint → dedup_hints[0]
# ============================================================
echo ""
echo "--- Test 7: fingerprint → dedup_hints[0] ---"
dh=$(jq -r '.signals[0].dedup_hints[0] // ""' "$TMP_OUT")
if [[ "$dh" == sha256:* ]]; then
  echo "  PASS: dedup_hints[0] = $dh"
else
  echo "  FAIL: dedup_hints[0] = '$dh' (expected sha256:...)"
  exit 1
fi

# ============================================================
# Test 8: emitted_at present
# ============================================================
echo ""
echo "--- Test 8: emitted_at present ---"
ea=$(jq -r '.signals[0].emitted_at // ""' "$TMP_OUT")
if [[ "$ea" == 2026-* ]] || [[ "$ea" == 20* ]]; then
  echo "  PASS: emitted_at = $ea"
else
  echo "  FAIL: emitted_at = '$ea'"
  exit 1
fi

# ============================================================
# Test 9: --validate passes on translated output
# ============================================================
echo ""
echo "--- Test 9: --validate passes on translated output ---"
if python3 "$TRANSLATOR" --validate --input "$TMP_OUT" 2>/dev/null; then
  echo "  PASS: --validate returns 0"
else
  echo "  FAIL: --validate returned non-zero on translated output"
  exit 1
fi

# ============================================================
# Test 10: --format signals returns array
# ============================================================
echo ""
echo "--- Test 10: --format signals returns array ---"
python3 "$TRANSLATOR" --input "$INPUT" --output "$TMP_ARR" --format signals 2>/dev/null
arr_type=$(jq -r 'type' "$TMP_ARR")
if [ "$arr_type" = "array" ]; then
  echo "  PASS: --format signals output is array"
else
  echo "  FAIL: --format signals output type = '$arr_type'"
  exit 1
fi

# ============================================================
# Test 11: canonical fingerprint generated when fingerprint absent
# ============================================================
echo ""
echo "--- Test 11: canonical fingerprint when fingerprint absent ---"
echo '{"$schema":"lane-signals-v1","lane":"wf-fix-functional","dimension":"QD1","probe_id":"P-QD1-req-registry-xref","probe_version":"v1.0","profile":"standard","generated_at":"2026-05-09T10:00:00Z","signals":[{"$schema":"signal-v2","dimension_id":"QD1","probe_id":"P-QD1-req-registry-xref","probe_version":"v1.0","severity":"medium","fixability":"agent_fix","domain":"backend","title":"Test signal no fp","description":"Test description long enough for evidence","location":{"file":"src/test.ts","line":1},"evidence":[{"type":"code","path":"src/test.ts","description":"some code snippet here"}],"cdg_flags":[]}]}' > "$TMP_NOFP"
python3 "$TRANSLATOR" --input "$TMP_NOFP" --output "$TMP_NOFP.out" 2>/dev/null
gen_fp=$(jq -r '.signals[0].dedup_hints[0] // ""' "$TMP_NOFP.out")
rm -f "$TMP_NOFP.out"
if [[ "$gen_fp" == sha256:* ]]; then
  echo "  PASS: canonical fingerprint generated: $gen_fp"
else
  echo "  FAIL: canonical fingerprint = '$gen_fp'"
  exit 1
fi

# ============================================================
# Test 12: --validate fails on lane-format (evidence array)
# ============================================================
echo ""
echo "--- Test 12: --validate fails on lane-format input ---"
if python3 "$TRANSLATOR" --validate --input "$INPUT" >/dev/null 2>&1; then
  echo "  FAIL: --validate should fail for lane-format (evidence is array)"
  exit 1
fi
echo "  PASS: --validate correctly rejects lane-format input"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  lane-to-bus translator: functional"
echo "  severity → suggested_severity: PASS"
echo "  location → target: PASS"
echo "  evidence[] → evidence{}: PASS"
echo "  fingerprint → dedup_hints: PASS"
echo "  canonical fingerprint generation: PASS"
echo "  --validate mode: PASS"
exit 0
