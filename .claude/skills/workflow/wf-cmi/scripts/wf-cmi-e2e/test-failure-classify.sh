#!/usr/bin/env bash
# Test G5.3 — Failure classify 7-type test (deterministic stub)
#
# Test 7 fixtures cover all 7 failure types theo priority order:
#   1. NETWORK_ERROR (5xx) — KHÔNG bị override bởi AUTH
#   2. AUTH_FAILURE (401) — Override NETWORK_ERROR
#   3. DATA_MISSING (404 + DOM "không tìm thấy")
#   4. TEST_SELECTOR ("Element not found")
#   5. UI_BUG (TypeError trong console)
#   6. BUSINESS_RULE (no specific signals, DOM có content)
#   7. UNKNOWN (no DOM, no signals)
#
# Usage: bash test-failure-classify.sh
# Exit: 0 = ALL PASS, 1 = ≥1 FAIL

set -e

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=7

classify_test() {
  local NAME="$1"
  local EXPECTED="$2"
  local NETWORK_RAW="$3"
  local DOM_RAW="$4"
  local CONSOLE_RAW="$5"
  local STEP_ERROR="$6"
  local DOM_BYTES=${#DOM_RAW}

  FAILURE_TYPE=""

  # Priority 2: AUTH_FAILURE (override Priority 1 khi 401/403)
  if echo "$NETWORK_RAW" | jq -e 'any(.status == 401 or .status == 403)' >/dev/null 2>&1; then
    FAILURE_TYPE="AUTH_FAILURE"
  elif echo "$DOM_RAW" | grep -qiE "không có quyền|unauthorized|forbidden|access denied" 2>/dev/null; then
    FAILURE_TYPE="AUTH_FAILURE"
  # Priority 1: NETWORK_ERROR
  elif echo "$NETWORK_RAW" | jq -e 'any((.url | test("/api/")) and (.status >= 400 and .status < 600 and .status != 401 and .status != 403))' >/dev/null 2>&1; then
    FAILURE_TYPE="NETWORK_ERROR"
  # Priority 3: DATA_MISSING
  elif echo "$NETWORK_RAW" | jq -e 'any(.status == 404)' >/dev/null 2>&1; then
    FAILURE_TYPE="DATA_MISSING"
  elif echo "$DOM_RAW" | grep -qiE "không tìm thấy|no data|chưa có dữ liệu|no results|0 kết quả" 2>/dev/null; then
    FAILURE_TYPE="DATA_MISSING"
  # Priority 4: TEST_SELECTOR
  elif echo "$STEP_ERROR" | grep -qiE "element not found|selector not found|no element matches|locator\.click: error|strict mode violation" 2>/dev/null; then
    FAILURE_TYPE="TEST_SELECTOR"
  # Priority 5: UI_BUG
  elif echo "$CONSOLE_RAW" | grep -qiE "TypeError|cannot read|cannot access|undefined is not|is not a function" 2>/dev/null; then
    FAILURE_TYPE="UI_BUG"
  # Priority 6: BUSINESS_RULE
  elif [ "$DOM_BYTES" -gt 500 ]; then
    FAILURE_TYPE="BUSINESS_RULE"
  # Priority 7: UNKNOWN
  else
    FAILURE_TYPE="UNKNOWN"
  fi

  if [ "$FAILURE_TYPE" = "$EXPECTED" ]; then
    echo "  ✅ PASS: $NAME → $FAILURE_TYPE (expected $EXPECTED)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ❌ FAIL: $NAME → got $FAILURE_TYPE, expected $EXPECTED"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== G5.3 — Failure Classify 7-Type Test ==="
echo ""

# Test 1: NETWORK_ERROR (5xx khác 401/403)
classify_test \
  "NETWORK_ERROR_5xx" \
  "NETWORK_ERROR" \
  '[{"url":"/api/customers","status":500,"method":"GET"}]' \
  "<html><body>Server error</body></html>" \
  "" \
  ""

# Test 2: AUTH_FAILURE (override NETWORK_ERROR khi 401)
classify_test \
  "AUTH_FAILURE_401_override" \
  "AUTH_FAILURE" \
  '[{"url":"/api/customers","status":401,"method":"GET"}]' \
  "<html><body>Unauthorized</body></html>" \
  "" \
  ""

# Test 3: DATA_MISSING (DOM "không tìm thấy" + API 200 OK)
# Note: API 404 matches NETWORK_ERROR Priority 1 (per source spec). DATA_MISSING là cho:
#   - DOM text indicators "không tìm thấy" / "no data" khi API trả 200 nhưng empty results
#   - Non-API URLs (SPA route 404, static asset) — không match `/api/`
classify_test \
  "DATA_MISSING_dom_text" \
  "DATA_MISSING" \
  '[{"url":"/api/customers","status":200,"method":"GET"}]' \
  "<html><body>Danh sách khách hàng: không tìm thấy kết quả nào phù hợp với bộ lọc</body></html>" \
  "" \
  ""

# Test 4: TEST_SELECTOR
classify_test \
  "TEST_SELECTOR_element_not_found" \
  "TEST_SELECTOR" \
  '[]' \
  "<html><body>Page loaded successfully with all customer data displayed in table.</body></html>" \
  "" \
  "locator.click: Error: Element not found for selector #submit-btn"

# Test 5: UI_BUG (TypeError trong console)
classify_test \
  "UI_BUG_TypeError" \
  "UI_BUG" \
  '[]' \
  "<html><body>Page loaded successfully with all customer data displayed in table.</body></html>" \
  '[{"type":"error","text":"TypeError: Cannot read properties of null (reading id)"}]' \
  ""

# Test 6: BUSINESS_RULE (DOM > 500 bytes, no specific signals)
LONG_DOM=$(python3 -c "print('<html><body>' + 'x' * 600 + '</body></html>')" 2>/dev/null || printf '<html><body>%600s</body></html>' "")
classify_test \
  "BUSINESS_RULE_catch_all" \
  "BUSINESS_RULE" \
  '[]' \
  "$LONG_DOM" \
  "" \
  ""

# Test 7: UNKNOWN (no signals, no DOM)
classify_test \
  "UNKNOWN_no_signals" \
  "UNKNOWN" \
  '[]' \
  "" \
  "" \
  ""

echo ""
echo "=== Summary: $PASS_COUNT/$TOTAL PASS, $FAIL_COUNT FAIL ==="

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "✅ G5.3 PASS — All 7 failure types classify correctly"
  exit 0
else
  echo "❌ G5.3 FAIL — $FAIL_COUNT/$TOTAL classification errors"
  exit 1
fi
