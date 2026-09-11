#!/usr/bin/env bash
# detect-modified-scenarios.sh — Detect CMI scenarios mới/modified kể từ baseline (Phase 9 G1.3)
# Usage: ./detect-modified-scenarios.sh <scenarios-dir> [--since=HEAD~1]
#
# WHY: Pre-flight 5x stability check chỉ chạy cho scenarios MỚI/MODIFIED.
# Scenarios đã stable (hash khớp + TTL <30d trong stable-registry.json) được skip.
#
# Output (stdout):
#   ALL_SCENARIOS:<count>          — tổng scenarios trong dir
#   CHANGED_SCENARIOS:<count>      — số scenarios mới/modified
#   <scenario-file-path>           — mỗi dòng 1 path tới scenario .md cần pre-flight
#
# Exit codes: 0 = thành công, 1 = lỗi (dir không tồn tại)
set -euo pipefail

SCENARIOS_DIR="${1:-}"
SINCE_ARG="HEAD~1"

[ -z "$SCENARIOS_DIR" ] && { echo "Usage: $0 <scenarios-dir> [--since=HEAD~1]" >&2; exit 1; }
[ ! -d "$SCENARIOS_DIR" ] && { echo "Dir not found: $SCENARIOS_DIR" >&2; exit 1; }

# Parse --since=VALUE
for arg in "$@"; do
  case "$arg" in
    --since=*) SINCE_ARG="${arg#--since=}" ;;
  esac
done

# Tổng số scenarios
ALL_SCENARIOS=$(find "$SCENARIOS_DIR" -maxdepth 1 -type f -name "test-scenario-CMI-*.md" 2>/dev/null | sort)
ALL_COUNT=$(echo -n "$ALL_SCENARIOS" | grep -c '^' || echo 0)

echo "ALL_SCENARIOS:${ALL_COUNT}"

# Nếu không phải git repo → return tất cả scenarios (conservative: tất cả mới)
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "CHANGED_SCENARIOS:${ALL_COUNT}"
  [ "$ALL_COUNT" -gt 0 ] && echo "$ALL_SCENARIOS"
  exit 0
fi

# Validate since ref
if ! git rev-parse "$SINCE_ARG" >/dev/null 2>&1; then
  # Invalid ref → conservative: return all
  echo "CHANGED_SCENARIOS:${ALL_COUNT}"
  [ "$ALL_COUNT" -gt 0 ] && echo "$ALL_SCENARIOS"
  exit 0
fi

# Tìm scenarios changed
CHANGED=$(git diff "$SINCE_ARG" --name-only -- "$SCENARIOS_DIR" 2>/dev/null \
  | grep -E "/test-scenario-CMI-.*\.md$" || echo "")

# Untracked (mới hoàn toàn — CD41 vừa sinh)
UNTRACKED=$(git ls-files --others --exclude-standard "$SCENARIOS_DIR" 2>/dev/null \
  | grep -E "/test-scenario-CMI-.*\.md$" || echo "")

# Combine + dedupe
COMBINED=""
[ -n "$CHANGED" ] && COMBINED="$CHANGED"
[ -n "$UNTRACKED" ] && {
  if [ -n "$COMBINED" ]; then
    COMBINED="${COMBINED}"$'\n'"${UNTRACKED}"
  else
    COMBINED="$UNTRACKED"
  fi
}

if [ -z "$COMBINED" ]; then
  echo "CHANGED_SCENARIOS:0"
  exit 0
fi

# Dedupe + sort
COMBINED=$(echo "$COMBINED" | sort -u | grep -v '^$')
CHANGED_COUNT=$(echo "$COMBINED" | grep -c '^' || echo 0)

echo "CHANGED_SCENARIOS:${CHANGED_COUNT}"
echo "$COMBINED"
