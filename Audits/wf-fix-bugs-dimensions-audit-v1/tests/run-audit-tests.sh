#!/usr/bin/env bash
# run-audit-tests.sh — Runner cho audit suite (7 dim QD1..QD7).
#
# Su dung:
#   ./run-audit-tests.sh                  # Chay full pytest tests/
#   ./run-audit-tests.sh --dim=QD1        # Chay 1 dim only (test_qd1_probes.py)
#   ./run-audit-tests.sh --compare-baseline  # Stage 4 re-audit: compare precision/recall
#
# Exit codes:
#   0 = all pass (skeleton stage: 7 skipped)
#   1 = test fail
#   3 = pytest chua cai
#
# Tham chieu: 13-definition-of-done.md §Phase 3 (Precision ≥0.7, Recall ≥0.6).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTEST_ARGS=()
DIM_FILTER=""

for arg in "$@"; do
  case "$arg" in
    --dim=*)
      DIM_RAW="${arg#--dim=}"
      DIM_LOWER="$(echo "$DIM_RAW" | tr '[:upper:]' '[:lower:]')"
      DIM_FILTER="test_${DIM_LOWER}_probes.py"
      ;;
    --compare-baseline)
      export AUDIT_COMPARE_BASELINE=1
      ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      PYTEST_ARGS+=("$arg")
      ;;
  esac
done

# Preflight — pytest phai co san
if ! python -c "import pytest" 2>/dev/null; then
  echo "[ERROR] pytest chua cai dat." >&2
  echo "  Cai: pip install pytest" >&2
  exit 3
fi

if [[ -n "$DIM_FILTER" ]]; then
  if [[ ! -f "$DIM_FILTER" ]]; then
    echo "[ERROR] Test file khong ton tai: $DIM_FILTER" >&2
    exit 1
  fi
  echo "[INFO] Dim-specific run: $DIM_FILTER"
  python -m pytest "$DIM_FILTER" -v "${PYTEST_ARGS[@]}"
else
  echo "[INFO] Full audit suite (7 dim QD1..QD7)"
  python -m pytest . -v "${PYTEST_ARGS[@]}"
fi
