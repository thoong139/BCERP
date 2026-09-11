#!/usr/bin/env bash
# lint-scenario.sh — Lint E2E test scenarios theo 6 rules (G1.1)
# Usage: ./lint-scenario.sh <scenario-file> [--json]
#
# Rules:
#   RULE 1: NO_HARDCODED_SLEEP    — waitForTimeout / setTimeout / sleep với số cứng
#   RULE 2: NO_INDEX_SELECTORS    — nth-child hoặc .nth() với index cứng
#   RULE 3: NO_REAL_EXTERNAL_CALLS — gọi thẳng sendgrid/twilio/real-api
#   RULE 4: NO_RAW_TIME_LOGIC     — Date.now() / new Date() trong assertions
#   RULE 5: NO_SHARED_STATE_LEAKAGE — không clear context/cookies giữa scenarios
#   RULE 6: EXPLICIT_WAIT_ASSERTIONS — assertion không có timeout
#
# Exit codes: 0 = PASS, 1 = FAIL (vi phạm BLOCK)
set -euo pipefail

FILE="${1:-}"
JSON_OUTPUT="${2:-}"

[ -z "$FILE" ] && echo "Usage: $0 <scenario-file> [--json]" && exit 1
[ ! -f "$FILE" ] && echo "File not found: $FILE" && exit 1

VIOLATIONS=()
BLOCK=false

# --- RULE 1: NO_HARDCODED_SLEEP ---
# WHY riêng: grep hai pattern riêng để tránh false positive từ waitForResponse
while IFS=: read -r lineno content; do
  if echo "$content" | grep -qE "waitForTimeout\([0-9]+\)|sleep\([0-9]+\)"; then
    escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
    VIOLATIONS+=("{\"rule\":\"NO_HARDCODED_SLEEP\",\"line\":$lineno,\"code\":\"$escaped\",\"suggestion\":\"Dung waitFor state:visible hoac waitForLoadState thay cho hardcoded timeout\"}")
    BLOCK=true
  fi
done < <(grep -n "waitForTimeout\|sleep(" "$FILE" 2>/dev/null | head -20 || true)

# setTimeout riêng vì pattern khác
while IFS=: read -r lineno content; do
  if echo "$content" | grep -qE "setTimeout\([^,]+,[[:space:]]*[0-9]{3,}\)"; then
    escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
    VIOLATIONS+=("{\"rule\":\"NO_HARDCODED_SLEEP\",\"line\":$lineno,\"code\":\"$escaped\",\"suggestion\":\"Thay setTimeout bang waitFor state-based\"}")
    BLOCK=true
  fi
done < <(grep -n "setTimeout(" "$FILE" 2>/dev/null | head -20 || true)

# --- RULE 2: NO_INDEX_SELECTORS ---
while IFS=: read -r lineno content; do
  if echo "$content" | grep -qE "nth-child\([0-9]+\)|\.nth\([0-9]+\)"; then
    escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
    VIOLATIONS+=("{\"rule\":\"NO_INDEX_SELECTORS\",\"line\":$lineno,\"code\":\"$escaped\",\"suggestion\":\"Dung data-testid hoac getByRole/getByLabel thay vi index selector\"}")
    BLOCK=true
  fi
done < <(grep -n "nth-child\|\.nth(" "$FILE" 2>/dev/null | head -20 || true)

# --- RULE 3: NO_REAL_EXTERNAL_CALLS ---
while IFS=: read -r lineno content; do
  escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
  VIOLATIONS+=("{\"rule\":\"NO_REAL_EXTERNAL_CALLS\",\"line\":$lineno,\"code\":\"external-api-call\",\"suggestion\":\"Dung MSW mock thay vi goi truc tiep external service\"}")
  BLOCK=true
done < <(grep -n "sendgrid\.com\|twilio\.com\|smtp\.gmail\|real-[a-z]+-api\|api\.stripe\.com\|api\.paypal\.com" "$FILE" 2>/dev/null | head -20 || true)

# --- RULE 4: NO_RAW_TIME_LOGIC ---
while IFS=: read -r lineno content; do
  # Chỉ flag khi trong assertion context (expect / toBe / toEqual)
  if echo "$content" | grep -qE "expect\(.*Date\.now\(\)|expect\(.*new Date\(\)"; then
    escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
    VIOLATIONS+=("{\"rule\":\"NO_RAW_TIME_LOGIC\",\"line\":$lineno,\"code\":\"$escaped\",\"suggestion\":\"Dung jest.useFakeTimers().setSystemTime(FIXED_DATE) de thay the Date.now() trong assertions\"}")
    BLOCK=true
  fi
done < <(grep -n "Date\.now()\|new Date()" "$FILE" 2>/dev/null | head -20 || true)

# --- RULE 5: NO_SHARED_STATE_LEAKAGE ---
# Kiểm tra: nếu file có nhiều scenario (>1 heading) mà không có clearCookies/clearStorage
SCENARIO_COUNT=$(grep -c "^## Kịch bản\|^## Scenario\|describe(\|it(" "$FILE" 2>/dev/null || echo 0)
HAS_CLEAR=$(grep -c "clearCookies\|clearStorage\|localStorage\.clear\|sessionStorage\.clear\|newContext\|browser\.newPage" "$FILE" 2>/dev/null || echo 0)

if [ "$SCENARIO_COUNT" -gt 1 ] && [ "$HAS_CLEAR" -eq 0 ]; then
  VIOLATIONS+=("{\"rule\":\"NO_SHARED_STATE_LEAKAGE\",\"line\":0,\"code\":\"Multiple scenarios without state reset\",\"suggestion\":\"Them await page.context().clearCookies() va clearStorage() o dau moi scenario\"}")
  BLOCK=true
fi

# --- RULE 6: EXPLICIT_WAIT_ASSERTIONS ---
while IFS=: read -r lineno content; do
  # Tìm expect().toBe/toEqual không có await (immediate assertion)
  if echo "$content" | grep -qE "^\s*expect\(" && ! echo "$content" | grep -qE "await expect|timeout:"; then
    # Chỉ flag nếu assertion là về DOM text/state (có .locator / .getBy)
    if echo "$content" | grep -qE "\.locator\(|\.getBy"; then
      escaped=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
      VIOLATIONS+=("{\"rule\":\"EXPLICIT_WAIT_ASSERTIONS\",\"line\":$lineno,\"code\":\"$escaped\",\"suggestion\":\"Dung await expect(locator).toContainText('...', { timeout: 5000 }) thay vi immediate assertion\"}")
      BLOCK=true
    fi
  fi
done < <(grep -n "^\s*expect(" "$FILE" 2>/dev/null | head -20 || true)

# --- Build output ---
BLOCK_STR="false"
$BLOCK && BLOCK_STR="true"

# Join violations array
VIOLATIONS_JSON="["
if [ "${#VIOLATIONS[@]}" -gt 0 ]; then
  VIOLATIONS_JSON+=$(printf '%s,' "${VIOLATIONS[@]}")
  VIOLATIONS_JSON="${VIOLATIONS_JSON%,}"
fi
VIOLATIONS_JSON+="]"

VIOLATION_COUNT="${#VIOLATIONS[@]}"

if [ "${JSON_OUTPUT:-}" = "--json" ]; then
  printf '{"lint_report_v1":true,"scenario_file":"%s","violations":%s,"block_execution":%s,"violation_count":%d}\n' \
    "$FILE" "$VIOLATIONS_JSON" "$BLOCK_STR" "$VIOLATION_COUNT"
else
  if $BLOCK; then
    echo "LINT FAIL: $VIOLATION_COUNT violation(s) trong $FILE"
    echo ""
    for v in "${VIOLATIONS[@]}"; do
      rule=$(echo "$v" | grep -o '"rule":"[^"]*"' | cut -d'"' -f4)
      lineno=$(echo "$v" | grep -o '"line":[0-9]*' | cut -d: -f2)
      suggestion=$(echo "$v" | grep -o '"suggestion":"[^"]*"' | cut -d'"' -f4)
      echo "  [${rule}] Line ${lineno}: ${suggestion}"
    done
    echo ""
    echo "Fix violations va chay lai lint truoc khi execute scenario."
    exit 1
  else
    echo "LINT PASS: $FILE (0 violations)"
  fi
fi
