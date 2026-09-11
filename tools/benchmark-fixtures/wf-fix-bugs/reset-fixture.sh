#!/usr/bin/env bash
# reset-fixture.sh — xóa output/ và re-build từ template
#
# Usage:
#   reset-fixture.sh                    # Reset ./output/
#   reset-fixture.sh --target <path>    # Reset custom path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/output"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --help|-h) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -d "$TARGET_DIR" ]; then
  echo "[reset-fixture] Removing $TARGET_DIR ..."
  rm -rf "$TARGET_DIR"
fi

echo "[reset-fixture] Rebuilding ..."
bash "$SCRIPT_DIR/build-fixture.sh" --target "$TARGET_DIR"
