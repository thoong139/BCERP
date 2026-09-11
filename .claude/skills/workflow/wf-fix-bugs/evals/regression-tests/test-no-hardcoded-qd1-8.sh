#!/usr/bin/env bash
# Regression test (HIGH-6 v9.0.3): KHONG cho phep hardcoded QD1-QD8 trong runtime code.
#
# Bug class: v9.0.0 mark 38/38 task DONE nhung dispatch QD9/QD10 fail vi 6+ vi tri
# hardcode `QD1-QD8` (lane_dispatch.py LLM probes, merge_signals.py ALL_DIMS,
# impact-builder by_dimension, regex test). Test nay FAIL khi pattern quay lai.
#
# Cho phep: comments lich su (vd: "v8.x truoc do hardcode QD1-QD8"), file
# documentation lien quan v9.0.0 patch.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd)}"

# Patterns considered "hardcode QD1-QD8" (block QD9/QD10):
#   1. Tuple/array literal voi exactly QD1..QD8 va end at QD8: ("QD1","QD2",...,"QD8") khong tiep theo "QD9"/"QD10"
#   2. Bash hardcode loop: BY_DIM_QD1=...;BY_DIM_QD2=...;...;BY_DIM_QD8=  (no QD9/QD10)
#   3. Regex \[1-8\] cho probe_id pattern (block QD9/QD10 valid IDs)

# Files to scan: runtime code only (skip docs/, plans/, memory/)
SCAN_PATHS=(
  ".claude/scripts"
  ".claude/skills/workflow/_shared"
  ".claude/skills/workflow/wf-fix-bugs/procedures"
)

FAILED=0

# Test 1: Tuple QD1-QD8 ending at QD8 (Python)
# Match: ("QD1", ..., "QD8") nhung KHONG match khi co "QD9" sau do
PY_HARDCODE=$(grep -rn -E '\("QD1",\s*"QD2",\s*"QD3",\s*"QD4",\s*"QD5",\s*"QD6",\s*"QD7",\s*"QD8"\s*[,)]' "${SCAN_PATHS[@]}" 2>/dev/null \
  | grep -v -E '"QD9"' \
  | grep -v -E '\.pyc$|__pycache__' \
  || true)

if [[ -n "$PY_HARDCODE" ]]; then
  echo "FAIL: Hardcoded Python tuple QD1-QD8 (block QD9/QD10):" >&2
  echo "$PY_HARDCODE" >&2
  echo "" >&2
  FAILED=1
fi

# Test 2: Bash sequential BY_DIM_QD1..QD8 hardcode (impact-builder regression)
BASH_HARDCODE=$(grep -rn -E '^BY_DIM_QD8=\$\(build_dim_stats "QD8"\)\s*$' "${SCAN_PATHS[@]}" 2>/dev/null || true)
if [[ -n "$BASH_HARDCODE" ]]; then
  # Check kế tiếp: nếu sau line này có BY_DIM_QD9 trong cùng 5 lines tiếp theo → OK
  # Approach đơn giản: grep file có QD8= mà không có QD9= = bug
  FILES_WITH_QD8=$(echo "$BASH_HARDCODE" | cut -d: -f1 | sort -u)
  for f in $FILES_WITH_QD8; do
    if ! grep -q "BY_DIM_QD9\|DIMENSIONS=(QD1\|for qd in.*QD10" "$f" 2>/dev/null; then
      echo "FAIL: $f has BY_DIM_QD8= but no QD9/QD10 dispatch (hardcode regression):" >&2
      grep -n "BY_DIM_QD" "$f" >&2
      FAILED=1
    fi
  done
fi

# Test 3: Regex pattern P-QD[1-8] block QD9/QD10 IDs
REGEX_HARDCODE=$(grep -rn -E 'P-QD\[1-8\]' "${SCAN_PATHS[@]}" 2>/dev/null \
  | grep -v -E '\.pyc$|__pycache__' \
  | grep -v -E 'CRIT-5|truoc do' \
  || true)

if [[ -n "$REGEX_HARDCODE" ]]; then
  echo "FAIL: Regex pattern P-QD[1-8] block QD9/QD10 valid probe IDs:" >&2
  echo "$REGEX_HARDCODE" >&2
  echo "" >&2
  echo "Fix: thay [1-8] bang (10|[1-9]) hoac dung config DIMENSIONS list." >&2
  FAILED=1
fi

if [[ "$FAILED" -eq 1 ]]; then
  echo "" >&2
  echo "REGRESSION DETECTED: v9.0.0 fantasy pattern (hardcoded QD1-QD8) quay lai." >&2
  echo "Memo: project_wf-fix-bugs-v9-0-1-patch.md ghi 7 vi tri da duoc va." >&2
  exit 2
fi

echo "PASS: Khong tim thay hardcoded QD1-QD8 pattern trong runtime code."
exit 0
