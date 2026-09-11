#!/usr/bin/env bash
# wf-fix-deprecation-block.sh — Deprecation BLOCK v7.1
# Detect legacy v6.x sessions (run-NNN-*) and render CDG to migrate, bypass, or abort.
# Usage: bash .claude/scripts/wf-fix-deprecation-block.sh
# Exit: 0=no legacy paths or user chose migrate_now/force_continue, 2=user abort, 3=no common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common helpers
COMMON_SH="$REPO_ROOT/.claude/scripts/wf-fix-common.sh"
if [ ! -f "$COMMON_SH" ]; then
  echo "ERROR: wf-fix-common.sh not found at $COMMON_SH" >&2
  exit 3
fi
source "$COMMON_SH"

# Escape hatch for CI/CD — bypass CDG entirely
if [ "${MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK:-0}" = "1" ]; then
  echo "WARNING: MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1 — bypassing deprecation block" >&2
  exit 0
fi

# Check for legacy paths
if assert_no_legacy_paths; then
  exit 0  # No legacy paths → continue
fi

LEGACY_COUNT=$(get_legacy_paths_count)

cat <<EOF
⛔ DEPRECATION BLOCK (v7.1 — D1 roadmap: deprecate)

Phát hiện $LEGACY_COUNT session(s) v6.x với pattern run-NNN-*.
v7.1 KHÔNG còn cho phép chạy với legacy paths visible.

D1 roadmap timeline:
  v7.0: dual support (legacy + new)
  v7.1: deprecate (BLOCK với CDG override) ← BẠN ĐANG Ở ĐÂY
  v7.2: remove hoàn toàn

Vui lòng chọn 1 trong 3:

[1] migrate_now    — Auto-invoke wf-fix-migrate-sessions.sh --apply, sau đó tiếp tục
[2] force_continue — 1-shot bypass (legacy paths vẫn visible, KHÔNG migrate)
[3] abort          — Dừng lại với exit E_LEGACY_BLOCK

Escape hatch CI/CD: export MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1 → WARN + continue (không CDG)

Chọn (1/2/3):
EOF

read -r CDG_CHOICE
case "$CDG_CHOICE" in
  1|migrate_now)
    echo "→ Auto-invoke migration script..."
    if ! bash "$REPO_ROOT/.claude/scripts/wf-fix-migrate-sessions.sh" --apply; then
      echo "ERROR: Migration failed. Aborting." >&2
      exit 2
    fi
    echo "→ Migration done. Tiếp tục..."
    exit 0
    ;;
  2|force_continue)
    echo "→ 1-shot bypass: tiếp tục với legacy paths visible (không migrate)"
    exit 0
    ;;
  3|abort|*)
    echo "→ Aborted by user."
    exit 2
    ;;
esac
