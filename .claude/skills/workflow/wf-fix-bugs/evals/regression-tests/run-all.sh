#!/usr/bin/env bash
# run-all.sh — Chạy toàn bộ regression tests + e2e cho /wf-fix-bugs.
# Mỗi test isolation cao (mỗi test setup fixture riêng nếu cần).
#
# Env vars:
#   WF_FIX_LARGE_FIXTURE       Path tới fixture (default: <repo>/.cache/wf-fix-large-fixture)
#   WF_FIX_SKIP_E2E=1          Skip e2e (chỉ chạy 4 regression tests)
#   WF_FIX_FIXTURE_FILES=N     Override target file count (default 50000)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
  local name="$1" path="$2"
  echo ""
  echo "=========================================================="
  echo "TEST: $name"
  echo "=========================================================="
  if bash "$path"; then
    PASS=$((PASS + 1))
    echo "[run-all] $name → PASS"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name")
    echo "[run-all] $name → FAIL"
  fi
}

# 4 regression tests (lightweight, <2 phút each)
run_test "test-isg-name-narrowing"      "$SCRIPT_DIR/test-isg-name-narrowing.sh"
run_test "test-init-status-flags"       "$SCRIPT_DIR/test-init-status-flags.sh"
run_test "test-xref-on-N-orphans"       "$SCRIPT_DIR/test-xref-on-N-orphans.sh"
run_test "test-probe-timeout-not-silent" "$SCRIPT_DIR/test-probe-timeout-not-silent.sh"

# E2E (chỉ chạy nếu không skip — chậm hơn vì 50k fixture)
if [ "${WF_FIX_SKIP_E2E:-0}" != "1" ]; then
  run_test "e2e-large-codebase" "$EVALS_DIR/e2e-large-codebase.test.sh"
fi

echo ""
echo "=========================================================="
echo "SUMMARY: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  - %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
echo "All tests PASSED."
exit 0
