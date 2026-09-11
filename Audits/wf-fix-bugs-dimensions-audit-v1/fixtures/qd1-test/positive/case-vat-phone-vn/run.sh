#!/usr/bin/env bash
# REQ-ID: MCV3-TEST (IMP-009 acceptance test)
# case-vat-phone-vn/run.sh — Verify locale-aware form fill (IMP-009)
#
# Tests:
#   1. vat-phone-form.tsx has VN VAT pattern attribute (\d{10}...)
#   2. vat-phone-form.tsx has VN phone pattern (0[35789]...)
#   3. P-QD1-deep-ui-traversal.md has A3-locale section with locale-aware fill logic
#   4. vi/form-fill-patterns.json exists and is valid JSON
#   5. vi/form-fill-patterns.json has MST entry (label_hints contains "MST")
#   6. vi/form-fill-patterns.json has phone VN entry (label_hints contains "SĐT")
#   7. vi/form-fill-patterns.json has CCCD entry (label_hints contains "CCCD")
#
# PASS: all 7 checks PASS → exit 0
# FAIL: any check FAIL → exit 1
#
# USAGE: bash run.sh

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  # Fallback: 7 levels up from fixture dir
  REPO_ROOT="$(cd "$FIXTURE_DIR/../../../../../../.." && pwd)"
fi

PROBE_FILE="$REPO_ROOT/.claude/skills/workflow/wf-fix-functional/procedures/probes/P-QD1-deep-ui-traversal.md"
LOCALE_FILE="$REPO_ROOT/.claude/skills/workflow/_shared/locales/vi/form-fill-patterns.json"
FORM_FILE="$FIXTURE_DIR/vat-phone-form.tsx"

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

echo "=== IMP-009 Acceptance Test: Multi-locale form fill ==="
echo "    FIXTURE_DIR=$FIXTURE_DIR"
echo "    REPO_ROOT=$REPO_ROOT"
echo ""

# Test 1: form fixture has VN VAT pattern attribute (\d{10} — single backslash in source)
if grep -qF 'pattern="\d{10}' "$FORM_FILE" 2>/dev/null; then
  check 'vat-phone-form.tsx has VN VAT pattern attribute (\d{10}...)' "PASS"
else
  check 'vat-phone-form.tsx has VN VAT pattern attribute (\d{10}...)' "FAIL"
fi

# Test 2: form has phone VN pattern (0[35789]...)
if grep -qF '0[35789]' "$FORM_FILE" 2>/dev/null; then
  check "vat-phone-form.tsx has VN phone pattern (0[35789]...)" "PASS"
else
  check "vat-phone-form.tsx has VN phone pattern (0[35789]...)" "FAIL"
fi

# Test 3: probe spec has A3-locale section
if grep -q 'A3-locale' "$PROBE_FILE" 2>/dev/null; then
  check "P-QD1-deep-ui-traversal.md has A3-locale section (IMP-009)" "PASS"
else
  check "P-QD1-deep-ui-traversal.md has A3-locale section (IMP-009)" "FAIL"
fi

# Test 4: form-fill-patterns.json exists and is valid JSON
if [ -f "$LOCALE_FILE" ] && jq '.' "$LOCALE_FILE" > /dev/null 2>&1; then
  check "vi/form-fill-patterns.json exists and is valid JSON" "PASS"
else
  check "vi/form-fill-patterns.json exists and is valid JSON" "FAIL"
fi

# Test 5: MST entry exists in form-fill-patterns.json
if jq -e '[.form_fill_patterns[] | select(any(.label_hints[]; contains("MST")))] | length > 0' \
    "$LOCALE_FILE" > /dev/null 2>&1; then
  check "vi/form-fill-patterns.json has MST/VAT entry" "PASS"
else
  check "vi/form-fill-patterns.json has MST/VAT entry" "FAIL"
fi

# Test 6: Phone VN entry exists (contains "SĐT" or "điện thoại")
if jq -e '[.form_fill_patterns[] | select(any(.label_hints[]; contains("SĐT") or contains("thoại")))] | length > 0' \
    "$LOCALE_FILE" > /dev/null 2>&1; then
  check "vi/form-fill-patterns.json has phone VN entry" "PASS"
else
  check "vi/form-fill-patterns.json has phone VN entry" "FAIL"
fi

# Test 7: CCCD/CMND entry exists
if jq -e '[.form_fill_patterns[] | select(any(.label_hints[]; contains("CCCD") or contains("CMND")))] | length > 0' \
    "$LOCALE_FILE" > /dev/null 2>&1; then
  check "vi/form-fill-patterns.json has CCCD/CMND entry" "PASS"
else
  check "vi/form-fill-patterns.json has CCCD/CMND entry" "FAIL"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
if [ "$FAIL" -eq 0 ]; then
  echo "  VERDICT: PASS — IMP-009 acceptance criteria met"
  exit 0
else
  echo "  VERDICT: FAIL — $FAIL check(s) failed"
  exit 1
fi
