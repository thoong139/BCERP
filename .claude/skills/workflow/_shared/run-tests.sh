#!/usr/bin/env bash
# run-tests.sh — CI entry point cho `_shared` package test suite.
#
# Su dung:
#   ./run-tests.sh                  # chay full suite + coverage gate 80%
#   ./run-tests.sh --fast           # bo qua integration + cov gate (smoke only)
#   ./run-tests.sh --module=ripple  # chay 1 test file
#   ./run-tests.sh --cov-xml        # emit coverage.xml cho CI upload
#
# Exit codes:
#   0 = all pass + coverage >= 80%
#   1 = test fail
#   2 = coverage duoi 80%
#   3 = pytest/pytest-cov chua cai
#
# Tham chieu: B3-4 — pytest CI infrastructure, ADR-23 coverage gate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="full"
MODULE=""
COV_XML=""
for arg in "$@"; do
  case "$arg" in
    --fast) MODE="fast" ;;
    --cov-xml) COV_XML="--cov-report=xml:coverage.xml" ;;
    --module=*) MODULE="${arg#*=}" ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

# Preflight — pytest phai co san. Detect python binary (Windows native dung `python`,
# Linux/WSL/Mac dung `python3`). Fallback de support ca 2 platform.
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "[ERROR] Khong tim thay python3 hoac python interpreter." >&2
  exit 3
fi

if ! "$PY" -c "import pytest" 2>/dev/null; then
  echo "[ERROR] pytest chua cai dat." >&2
  echo "  Cai: $PY -m pip install pytest pytest-cov" >&2
  exit 3
fi

if ! "$PY" -c "import pytest_cov" 2>/dev/null; then
  echo "[ERROR] pytest-cov chua cai dat." >&2
  echo "  Cai: $PY -m pip install pytest-cov" >&2
  exit 3
fi

# Xay command
TARGET="tests/"
if [[ -n "$MODULE" ]]; then
  TARGET="tests/test_${MODULE}.py"
  [[ -f "$TARGET" ]] || { echo "[ERROR] Test file khong ton tai: $TARGET" >&2; exit 1; }
fi

if [[ "$MODE" == "fast" ]]; then
  echo "[INFO] Fast mode — smoke only, bo qua cov gate"
  "$PY" -m pytest "$TARGET" -m "not integration and not slow" -q
elif [[ -n "$MODULE" ]]; then
  echo "[INFO] Module-specific run: $MODULE"
  "$PY" -m pytest "$TARGET" -v --cov=. --cov-report=term-missing $COV_XML
else
  echo "[INFO] Full suite + coverage gate (>= 80%)"
  "$PY" -m pytest "$TARGET" \
    --cov=. \
    --cov-fail-under=80 \
    --cov-report=term-missing \
    $COV_XML
fi

RC=$?
if [[ $RC -eq 0 ]]; then
  echo "[PASS] All tests green."
elif [[ $RC -eq 2 ]]; then
  echo "[FAIL] Coverage below 80% — gate fail (CORE-023)." >&2
else
  echo "[FAIL] Test failures (rc=$RC)." >&2
fi
exit $RC
