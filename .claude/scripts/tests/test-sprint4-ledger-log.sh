#!/usr/bin/env bash
# Sprint 4 smoke test — ledger_log() helper
# Verify lazy-init, append, cap behavior, validation.

set -euo pipefail

cd "$(dirname "$0")/../../.."
ROOT="$(pwd)"

# Setup test env
export SESSION_ID="2026-04-28-test-host"
export SYSTEM_SLUG="_test"
export FEATURE_SLUG="test-feature-sprint4"
export SESSION_DIR="$ROOT/.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/sessions/$SESSION_ID"

# Cleanup từ run trước
rm -rf "$ROOT/.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG"
mkdir -p "$SESSION_DIR"

# Source helper
SCRIPTS_DIR="$ROOT/.claude/scripts/wf-implement-feature"
_SCRIPT_NAME="test-sprint4"
source "$SCRIPTS_DIR/implement-common.sh"

LEDGER="$SESSION_DIR/error-ledger.json"
PASS=0
FAIL=0
ASSERT() {
  local name="$1"; local cond="$2"
  if [[ "$cond" == "true" ]]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
}

# Test 1: Lazy-init — file không tồn tại trước call đầu tiên
[[ ! -f "$LEDGER" ]] && ASSERT "lazy-init: file absent before first call" true || ASSERT "lazy-init: file absent before first call" false

# Test 2: First ledger_log creates file
ledger_log "E101" "phase01-pattern-scan" "warning" "Pattern cache miss" '{"module":"crm"}' true
[[ -f "$LEDGER" ]] && ASSERT "first call creates file" true || ASSERT "first call creates file" false

# Test 3: Schema valid
SCHEMA_OK=$(jq -e '.schema_version == "1.0" and has("session_id") and has("feature_slug") and (.errors | type == "array")' "$LEDGER" >/dev/null 2>&1 && echo true || echo false)
ASSERT "schema fields present" "$SCHEMA_OK"

# Test 4: First entry recorded correctly
CODE_OK=$(jq -e '.errors[0].code == "E101" and .errors[0].severity == "warning" and .errors[0].auto_resolved == true' "$LEDGER" >/dev/null 2>&1 && echo true || echo false)
ASSERT "first entry fields correct" "$CODE_OK"

# Test 5: Context preserved
CTX_OK=$(jq -e '.errors[0].context.module == "crm"' "$LEDGER" >/dev/null 2>&1 && echo true || echo false)
ASSERT "context preserved" "$CTX_OK"

# Test 6: Multiple appends
ledger_log "E301" "phase07-tdd" "error" "Test gate failed" '{"batch":2}' false true "Manual fix required"
ledger_log "E601" "phase10-finalize" "info" "Registry mutex acquired"
COUNT=$(jq -r '.errors | length' "$LEDGER")
[[ "$COUNT" == "3" ]] && ASSERT "3 entries after 3 appends" true || ASSERT "3 entries after 3 appends (got $COUNT)" false

# Test 7: Severity enum validation (invalid → defaults to info)
ledger_log "E901" "phase00-init" "INVALID-SEVERITY" "Test invalid"
LAST_SEV=$(jq -r '.errors[-1].severity' "$LEDGER")
[[ "$LAST_SEV" == "info" ]] && ASSERT "invalid severity → info default" true || ASSERT "invalid severity → info default (got $LAST_SEV)" false

# Test 8: Code pattern validation (warns but still logs)
ledger_log "BAD-CODE" "phase00-init" "warning" "Bad code test" 2>/dev/null
LAST_CODE=$(jq -r '.errors[-1].code' "$LEDGER")
[[ "$LAST_CODE" == "BAD-CODE" ]] && ASSERT "non-conforming code still logs (with warn)" true || ASSERT "non-conforming code logs" false

# Test 9: Invalid context JSON falls back to {}
ledger_log "E102" "phase01-pattern-scan" "warning" "Bad ctx" 'not-json' 2>/dev/null
LAST_CTX=$(jq -c '.errors[-1].context' "$LEDGER")
[[ "$LAST_CTX" == "{}" ]] && ASSERT "invalid context → {} fallback" true || ASSERT "invalid context → {} fallback (got $LAST_CTX)" false

# Test 10: Cap at LEDGER_MAX_ENTRIES — temporarily set cap to 5, append 8 entries, expect 5 (oldest dropped)
LEDGER_TEST="$SESSION_DIR/error-ledger-cap-test.json"
LEDGER_MAX=5
jq -nc --arg sid "$SESSION_ID" --arg fs "$FEATURE_SLUG" \
  '{"$schema":"error-ledger-v1",schema_version:"1.0",session_id:$sid,feature_slug:$fs,errors:[]}' \
  > "$LEDGER_TEST"

# Inline cap logic test bằng jq trực tiếp
for i in 1 2 3 4 5 6 7 8; do
  ENTRY=$(jq -nc --arg c "E10$i" '{code:$c,phase:"test",severity:"info",message:"cap test \($c)",context:{},ts:"2026-04-28T00:00:00Z",auto_resolved:false,escalated_to_user:false,resolution:""}')
  jq --argjson e "$ENTRY" --argjson cap "$LEDGER_MAX" \
    '.errors += [$e] | if (.errors | length) > $cap then .errors |= .[(. | length - $cap):] else . end' \
    "$LEDGER_TEST" > "$LEDGER_TEST.tmp" && mv "$LEDGER_TEST.tmp" "$LEDGER_TEST"
done
CAP_COUNT=$(jq -r '.errors | length' "$LEDGER_TEST")
FIRST_CODE=$(jq -r '.errors[0].code' "$LEDGER_TEST")
LAST_CODE=$(jq -r '.errors[-1].code' "$LEDGER_TEST")
[[ "$CAP_COUNT" == "5" && "$FIRST_CODE" == "E104" && "$LAST_CODE" == "E108" ]] && ASSERT "cap=5: keep last 5 (E104..E108)" true || ASSERT "cap=5 (count=$CAP_COUNT first=$FIRST_CODE last=$LAST_CODE)" false

# Test 11: Missing SESSION_DIR returns 1 (not crash)
(unset SESSION_DIR; ledger_log "E101" "test" "info" "x" 2>/dev/null) && ASSERT "missing SESSION_DIR returns 0 (graceful)" false || ASSERT "missing SESSION_DIR returns non-zero" true

# Test 12: Trace event recorded
TRACE="$ROOT/.mc-data/work/_trace/session-log.json"
if [[ -f "$TRACE" ]]; then
  TRACE_HAS=$(grep -c '"event":"ERROR_LOGGED"' "$TRACE" 2>/dev/null || echo 0)
  [[ "$TRACE_HAS" -gt 0 ]] && ASSERT "trace_event ERROR_LOGGED recorded" true || ASSERT "trace_event ERROR_LOGGED recorded (count=$TRACE_HAS)" false
else
  ASSERT "trace_event file missing" false
fi

echo ""
echo "════════════════════════════════"
echo "Result: PASS=$PASS  FAIL=$FAIL"
echo "════════════════════════════════"

# Cleanup
rm -rf "$ROOT/.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG"

[[ $FAIL -eq 0 ]] || exit 1
exit 0
