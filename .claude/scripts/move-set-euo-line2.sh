#!/usr/bin/env bash
# move-set-euo-line2.sh — F05.011 (Sprint 8)
#
# Idempotent helper: di chuyển `set -euo pipefail` lên dòng 2 (sau shebang)
# trong các bash scripts có vi phạm convention.
#
# Usage:
#   bash move-set-euo-line2.sh --dry-run          # preview changes
#   bash move-set-euo-line2.sh --apply            # apply in-place
#   bash move-set-euo-line2.sh --apply <file>...  # only specific files
#
# Behavior:
#   - Đọc từng file (default: .claude/scripts/wf-fix-probe-*.sh)
#   - Skip nếu line 2 đã là `set -euo pipefail` (idempotent)
#   - Skip nếu không có dòng `^set -euo pipefail` nào (no-op)
#   - Skip nếu shebang không phải bash
#   - Move: delete original line + insert sau line 1
#
# Exit codes:
#   0 — success (all files processed hoặc no-op)
#   1 — error (file IO, missing args)

set -euo pipefail

MODE="dry-run"
TARGET_FILES=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --apply)   MODE="apply" ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) TARGET_FILES+=("$arg") ;;
  esac
done

# Default scope: tất cả probe scripts
if [ ${#TARGET_FILES[@]} -eq 0 ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while IFS= read -r f; do
    TARGET_FILES+=("$f")
  done < <(ls "$SCRIPT_DIR"/wf-fix-probe-*.sh 2>/dev/null)
fi

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
  echo "ERROR: no target files found" >&2
  exit 1
fi

PROCESSED=0
SKIPPED=0
MOVED=0

for f in "${TARGET_FILES[@]}"; do
  PROCESSED=$((PROCESSED + 1))
  basename_f=$(basename "$f")

  # Skip nếu file không phải bash script
  shebang=$(sed -n '1p' "$f")
  if [[ "$shebang" != *"bash"* && "$shebang" != *"sh"* ]]; then
    echo "[SKIP] $basename_f — non-bash shebang"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Idempotent check: line 2 đã là `set -euo pipefail`?
  line2=$(sed -n '2p' "$f")
  if [[ "$line2" == "set -euo pipefail" ]]; then
    echo "[OK]   $basename_f — already at line 2"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Find existing `set -euo pipefail` line number
  set_line=$(grep -n "^set -euo pipefail$" "$f" | head -1 | cut -d: -f1)
  if [ -z "$set_line" ]; then
    echo "[SKIP] $basename_f — no 'set -euo pipefail' found"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "[FIX]  $basename_f — moving line $set_line → line 2"

  if [ "$MODE" = "apply" ]; then
    # Atomic edit: build content vào tmp, rồi mv
    tmp=$(mktemp "${f}.XXXXXX")
    {
      sed -n '1p' "$f"               # shebang
      echo "set -euo pipefail"       # insert at line 2
      sed -n "2,$((set_line - 1))p" "$f"  # lines 2 to set_line-1
      sed -n "$((set_line + 1)),\$p" "$f" # lines set_line+1 to end (skip original)
    } > "$tmp"
    # Verify syntax trước khi commit
    if ! bash -n "$tmp" 2>/dev/null; then
      echo "ERROR: syntax check fail after edit, rollback $basename_f" >&2
      rm -f "$tmp"
      exit 1
    fi
    mv "$tmp" "$f"
  fi
  MOVED=$((MOVED + 1))
done

echo
echo "Summary: processed=$PROCESSED, moved=$MOVED, skipped=$SKIPPED, mode=$MODE"
if [ "$MODE" = "dry-run" ] && [ "$MOVED" -gt 0 ]; then
  echo "Run with --apply to commit changes."
fi
