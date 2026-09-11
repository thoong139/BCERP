#!/usr/bin/env bash
# test-init-status-flags.sh — Regression test cho Bug #2 (init-status không parse --url + --credentials).
#
# Trước fix #2: wf-fix-init-status.sh không parse --url và --credentials →
#               fix-status.json.flags thiếu 2 fields → runtime probe không có context.
# Sau fix #2:   --url=<URL> → flags.url, --credentials=<v> → flags.credentials.
#
# Cách test: chạy wf-fix-init-status.sh với cả 2 flags, đọc fix-status.json,
# verify flags.url và flags.credentials có giá trị đúng.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$EVALS_DIR/../../../../.." && pwd)"
INIT_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-init-status.sh"
TEMPLATE_PATH="$REPO_ROOT/.claude/skills/workflow/_shared/templates/fix-status.json"

TMP_ROOT="$REPO_ROOT/.cache/wf-fix-init-status-test"
SESSION_DIR="$TMP_ROOT/session"

fail() { echo "[init-status-test] FAIL: $*" >&2; exit 1; }
info() { echo "[init-status-test] $*"; }

[ -f "$INIT_SCRIPT" ] || fail "init script missing: $INIT_SCRIPT"
command -v jq >/dev/null 2>&1 || fail "jq not available (required for init-status)"

rm -rf "$TMP_ROOT"
mkdir -p "$SESSION_DIR"

# Tham số test
TEST_URL="http://localhost:3000"
TEST_CREDS="sysadmin@erktransport.local:SysAdmin@123"
TEST_ARGS="--scope=module --name=marketing --profile=deep --full-test --url=$TEST_URL --credentials=$TEST_CREDS --run-tests"

info "Running wf-fix-init-status.sh with --url + --credentials…"
set +e
( cd "$REPO_ROOT" && bash "$INIT_SCRIPT" \
    --session-dir "$SESSION_DIR" \
    --fix-id wf-fix-test-init-status \
    --profile deep \
    --scope module \
    --name marketing \
    --arguments "$TEST_ARGS" \
    >"$TMP_ROOT/stdout" 2>"$TMP_ROOT/stderr" )
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "[init-status-test] stdout:" >&2; cat "$TMP_ROOT/stdout" >&2 || true
  echo "[init-status-test] stderr:" >&2; cat "$TMP_ROOT/stderr" >&2 || true
  fail "wf-fix-init-status.sh exit=$RC"
fi

STATUS_FILE="$SESSION_DIR/fix-status.json"
[ -f "$STATUS_FILE" ] || fail "fix-status.json not created"
jq -e '.' "$STATUS_FILE" >/dev/null 2>&1 || fail "fix-status.json invalid JSON"

# Test 1: flags.url có giá trị đúng (CHỐNG REGRESSION BUG #2)
URL_VAL=$(jq -r '.flags.url // "<NULL>"' "$STATUS_FILE")
[ "$URL_VAL" = "$TEST_URL" ] \
  || fail "flags.url='$URL_VAL' (expected '$TEST_URL') — Bug #2 regression"

# Test 2: flags.credentials có giá trị đúng
CREDS_VAL=$(jq -r '.flags.credentials // "<NULL>"' "$STATUS_FILE")
[ "$CREDS_VAL" = "$TEST_CREDS" ] \
  || fail "flags.credentials='$CREDS_VAL' (expected '$TEST_CREDS') — Bug #2 regression"

# Test 3: existing flags vẫn được parse đúng (chống regression do thêm logic)
SCOPE_VAL=$(jq -r '.flags.scope // "<NULL>"' "$STATUS_FILE")
[ "$SCOPE_VAL" = "module" ] || fail "flags.scope='$SCOPE_VAL' (expected 'module')"

NAME_VAL=$(jq -r '.flags.name // "<NULL>"' "$STATUS_FILE")
[ "$NAME_VAL" = "marketing" ] || fail "flags.name='$NAME_VAL' (expected 'marketing')"

DEEP_VAL=$(jq -r '.flags.deep // false' "$STATUS_FILE")
[ "$DEEP_VAL" = "true" ] || fail "flags.deep='$DEEP_VAL' (expected 'true' from --full-test)"

RESPONSIVE_VAL=$(jq -r '.flags.responsive // false' "$STATUS_FILE")
[ "$RESPONSIVE_VAL" = "true" ] \
  || fail "flags.responsive='$RESPONSIVE_VAL' (expected 'true' from --full-test)"

RUN_TESTS_VAL=$(jq -r '.flags.run_tests // false' "$STATUS_FILE")
[ "$RUN_TESTS_VAL" = "true" ] || fail "flags.run_tests='$RUN_TESTS_VAL' (expected 'true')"

info "PASS: flags.url='$URL_VAL', flags.credentials='$CREDS_VAL', flags.scope='$SCOPE_VAL', flags.deep=$DEEP_VAL"
exit 0
