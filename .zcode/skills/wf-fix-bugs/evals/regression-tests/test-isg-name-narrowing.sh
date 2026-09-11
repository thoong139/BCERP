#!/usr/bin/env bash
# test-isg-name-narrowing.sh — Regression test cho Bug #1 (ISG --name argument).
#
# Trước fix #1: phase1-engine.md không pass `--name` cho isg_recommender →
#               output `scope.name=null` dù user gọi /wf-fix-bugs --name=marketing.
# Sau fix #1:   --name được forward → output `scope.name="marketing"`.
#
# Cách test: gọi isg_recommender analyze --scope=module --name=marketing trực tiếp,
# verify JSON output có scope.name == "marketing".
#
# Đây là contract test (chứ không phải engine test) — bảo vệ contract giữa
# phase1-engine.md và isg_recommender CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$EVALS_DIR/../../../../.." && pwd)"
SHARED_DIR="$REPO_ROOT/.claude/skills/workflow/_shared"

PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  # Try python3 first; fall back to python (Windows often has only python).
  if python3 --version >/dev/null 2>&1; then PYTHON_BIN=python3
  elif python --version >/dev/null 2>&1; then PYTHON_BIN=python
  else echo 'ERROR: neither python3 nor python found in PATH' >&2; exit 2; fi
fi

TMP_ROOT="$REPO_ROOT/.cache/wf-fix-isg-name"
SESSION_DIR="$TMP_ROOT/session"

fail() { echo "[isg-name-test] FAIL: $*" >&2; exit 1; }
info() { echo "[isg-name-test] $*"; }

rm -rf "$TMP_ROOT"
mkdir -p "$SESSION_DIR"

info "Running isg_recommender analyze --scope=module --name=marketing…"
set +e
OUTPUT=$( cd "$SHARED_DIR" && PYTHONPATH="$SHARED_DIR" \
    "$PYTHON_BIN" -m isg.isg_recommender analyze \
      --session-dir "$SESSION_DIR" \
      --profile standard \
      --scope module \
      --name marketing \
      2>"$TMP_ROOT/stderr" )
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "[isg-name-test] stderr:" >&2; cat "$TMP_ROOT/stderr" >&2 || true
  fail "isg_recommender exit=$RC"
fi

# Test 1: output là JSON valid
echo "$OUTPUT" | "$PYTHON_BIN" -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
except json.JSONDecodeError as e:
    print(f'NOT_JSON: {e}', file=sys.stderr); sys.exit(1)
if 'scope' not in data:
    print('MISSING_SCOPE', file=sys.stderr); sys.exit(1)
" || fail "output not valid JSON or missing scope"

# Test 2: scope.type == "module"
SCOPE_TYPE=$(echo "$OUTPUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin)['scope']['type'])")
[ "$SCOPE_TYPE" = "module" ] || fail "scope.type='$SCOPE_TYPE' (expected 'module')"

# Test 3: scope.name == "marketing" (CHỐNG REGRESSION BUG #1)
SCOPE_NAME=$(echo "$OUTPUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin)['scope'].get('name', '<NULL>'))")
[ "$SCOPE_NAME" = "marketing" ] \
  || fail "scope.name='$SCOPE_NAME' (expected 'marketing') — Bug #1 regression"

# Test 4: profile được respect
PROFILE_OUT=$(echo "$OUTPUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin).get('profile', '<NULL>'))")
[ "$PROFILE_OUT" = "standard" ] || fail "profile='$PROFILE_OUT' (expected 'standard')"

info "PASS: scope={type=$SCOPE_TYPE, name=$SCOPE_NAME}, profile=$PROFILE_OUT"
exit 0
