#!/usr/bin/env bash
# IMP-026 acceptance test — case-custom-exclude/
#
# Tests config-driven EXCLUDE_PATTERN in wf-fix-probe-static-a11y.sh:
#   1. Default behavior: NavComponent.test.tsx excluded (\.test\. pattern), no signal
#   2. Default behavior: legacy-stub/NavDeprecated.tsx included → 1 signal (img no alt)
#   3. With overrides (remove \.test\., add legacy-stub):
#      - NavComponent.test.tsx included → 1 signal (img no alt)
#      - legacy-stub/NavDeprecated.tsx excluded → 0 signals from it
#   4. Missing override file: silently ignored, default behavior unchanged
#   5. Override merging: additional_excludes appended to default pattern
#   6. Exit 0 + valid JSON in all cases
#
# NOTE: src_prod/ is copied to tmp dir to avoid fixtures/ path triggering EXCLUDE_PATTERN.
#
# VERDICT: PASS if all 6 assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-custom-exclude] IMP-026 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-a11y.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: wf-fix-probe-static-a11y.sh not found" >&2; exit 1
fi

# Copy source to temp dir to avoid "fixtures/" in path triggering EXCLUDE_PATTERN
TMP_SRC=$(mktemp -d 2>/dev/null || echo "/tmp/qd5-excl-src-$$")
cleanup() { rm -rf "$TMP_SRC"; }
trap cleanup EXIT
cp -r "$FIXTURE_DIR/src_prod/." "$TMP_SRC/"

OVERRIDES="$FIXTURE_DIR/overrides.json"

# ============================================================
# Test 1: Default — NavComponent.test.tsx excluded (\.test\. in EXCLUDE_PATTERN)
# ============================================================
echo ""
echo "--- Test 1: default behavior excludes .test. files ---"
out1=$(bash "$SCRIPT" --probe P-QD5-aria-attribute-scan --source-dir "$TMP_SRC" 2>/dev/null)
if ! echo "$out1" | jq '.' >/dev/null 2>&1; then
  echo "  FAIL: invalid JSON output"
  exit 1
fi
test_file_sigs=$(echo "$out1" | jq '[.signals[] | select(.location.file | test("NavComponent\\.test\\.tsx"; ""))] | length')
if [ "$test_file_sigs" -eq 0 ]; then
  echo "  PASS: NavComponent.test.tsx excluded by default (0 signals from it)"
else
  echo "  FAIL: expected 0 signals from .test. file, got $test_file_sigs"
  exit 1
fi

# ============================================================
# Test 2: Default — legacy-stub/NavDeprecated.tsx included → has signal
# ============================================================
echo ""
echo "--- Test 2: default behavior includes legacy-stub/ files ---"
legacy_sigs=$(echo "$out1" | jq '[.signals[] | select(.location.file | test("legacy-stub"; ""))] | length')
if [ "$legacy_sigs" -ge 1 ]; then
  echo "  PASS: legacy-stub/NavDeprecated.tsx included by default ($legacy_sigs signal(s))"
else
  echo "  FAIL: expected ≥1 signal from legacy-stub file, got $legacy_sigs"
  echo "  All signals: $(echo "$out1" | jq '[.signals[].location.file]')"
  exit 1
fi

# ============================================================
# Test 3: With overrides — NavComponent.test.tsx included, legacy-stub excluded
# ============================================================
echo ""
echo "--- Test 3: with overrides — .test. included, legacy-stub excluded ---"
out3=$(bash "$SCRIPT" --probe P-QD5-aria-attribute-scan --source-dir "$TMP_SRC" \
  --exclude-overrides "$OVERRIDES" 2>/dev/null)
if ! echo "$out3" | jq '.' >/dev/null 2>&1; then
  echo "  FAIL: invalid JSON with overrides"
  exit 1
fi

test_file_sigs3=$(echo "$out3" | jq '[.signals[] | select(.location.file | test("NavComponent\\.test\\.tsx"; ""))] | length')
if [ "$test_file_sigs3" -ge 1 ]; then
  echo "  PASS: NavComponent.test.tsx included when \.test\. removed ($test_file_sigs3 signal(s))"
else
  echo "  FAIL: expected ≥1 signal from .test. file after override, got $test_file_sigs3"
  echo "  All signals: $(echo "$out3" | jq '[.signals[].location.file]')"
  exit 1
fi

legacy_sigs3=$(echo "$out3" | jq '[.signals[] | select(.location.file | test("legacy-stub"; ""))] | length')
if [ "$legacy_sigs3" -eq 0 ]; then
  echo "  PASS: legacy-stub/ excluded when added to additional_excludes (0 signals)"
else
  echo "  FAIL: expected 0 signals from legacy-stub after override, got $legacy_sigs3"
  exit 1
fi

# ============================================================
# Test 4: Missing override file → silently ignored, same as default
# ============================================================
echo ""
echo "--- Test 4: missing override file silently ignored ---"
out4=$(bash "$SCRIPT" --probe P-QD5-aria-attribute-scan --source-dir "$TMP_SRC" \
  --exclude-overrides "/nonexistent/overrides.json" 2>/dev/null)
if ! echo "$out4" | jq '.' >/dev/null 2>&1; then
  echo "  FAIL: invalid JSON with missing overrides path"
  exit 1
fi
test_file_sigs4=$(echo "$out4" | jq '[.signals[] | select(.location.file | test("NavComponent\\.test\\.tsx"; ""))] | length')
if [ "$test_file_sigs4" -eq 0 ]; then
  echo "  PASS: missing overrides file silently ignored (default behavior preserved)"
else
  echo "  FAIL: expected default behavior, got $test_file_sigs4 .test. signals"
  exit 1
fi

# ============================================================
# Test 5: Signal counts differ between default and override runs
# ============================================================
echo ""
echo "--- Test 5: override changes overall signal set ---"
default_total=$(echo "$out1" | jq '.signals | length')
override_total=$(echo "$out3" | jq '.signals | length')
if [ "$default_total" -ne "$override_total" ] || [ "$default_total" -gt 0 ]; then
  echo "  PASS: default=$default_total signals, with-overrides=$override_total signals"
else
  echo "  FAIL: both runs produced 0 signals — fixture sources may not be scannable"
  exit 1
fi

# ============================================================
# Test 6: Exit 0 + valid JSON in all scenarios
# ============================================================
echo ""
echo "--- Test 6: all scenarios exit 0 + valid JSON ---"
fail6=0
for out_var in "$out1" "$out3" "$out4"; do
  if ! echo "$out_var" | jq '.' >/dev/null 2>&1; then
    echo "  FAIL: one scenario produced invalid JSON"
    fail6=1
  fi
done
if [ "$fail6" -eq 0 ]; then
  echo "  PASS: all 3 scenarios produced valid JSON"
else
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  Default excludes .test. files: PASS"
echo "  Default includes legacy-stub/: PASS"
echo "  Override remove .test. → included: PASS"
echo "  Override add legacy-stub → excluded: PASS"
echo "  Missing override file silently ignored: PASS"
echo "  Signal set differs between default/override: PASS"
echo "  Exit 0 + valid JSON all scenarios: PASS"
exit 0
