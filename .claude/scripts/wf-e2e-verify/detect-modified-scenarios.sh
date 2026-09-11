#!/usr/bin/env bash
# detect-modified-scenarios.sh — Phát hiện scenarios mới/modified kể từ baseline (G1.3)
# Usage: ./detect-modified-scenarios.sh [--since=HEAD~1]
#
# WHY: Pre-flight flakiness check chỉ cần chạy cho scenarios mới/thay đổi.
# Scenarios đã stable (hash không đổi) bỏ qua để tiết kiệm thời gian.
#
# Exit codes: 0 = thành công (in kết quả), 1 = lỗi
set -euo pipefail

SINCE_ARG="HEAD~1"

# Parse --since=VALUE
for arg in "$@"; do
  case "$arg" in
    --since=*) SINCE_ARG="${arg#--since=}" ;;
  esac
done

# Validate git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "NO_GIT_REPO"
  exit 0
fi

# Validate since ref
if ! git rev-parse "$SINCE_ARG" >/dev/null 2>&1; then
  echo "INVALID_REF: $SINCE_ARG"
  exit 0
fi

# Tìm scenario files đã thay đổi
# Pattern: .spec.ts / .spec.js / files trong thư mục scenarios/ / file tên chứa test-scenario
changed=$(git diff "$SINCE_ARG" --name-only 2>/dev/null \
  | grep -E "\.spec\.(ts|js)$|/scenarios/|test-scenario|\.feature$" \
  || echo "")

# Cũng tìm untracked scenario files mới
untracked=$(git ls-files --others --exclude-standard 2>/dev/null \
  | grep -E "\.spec\.(ts|js)$|/scenarios/|test-scenario|\.feature$" \
  || echo "")

combined=""
[ -n "$changed" ] && combined="$changed"
[ -n "$untracked" ] && {
  [ -n "$combined" ] && combined="$combined"$'\n'"$untracked" || combined="$untracked"
}

if [ -z "$combined" ]; then
  echo "NO_CHANGED_SCENARIOS"
  exit 0
fi

echo "CHANGED_SCENARIOS:"
echo "$combined"
