#!/usr/bin/env bash
# Background heartbeat daemon — cập nhật heartbeat_at trong lock file mỗi INTERVAL giây
# Usage: bash as-heartbeat.sh <lock_path> [interval_sec]
#   lock_path: path to .session.lock hoặc .registry.lock
#   interval_sec: default 30
# Chạy trong background: bash as-heartbeat.sh <path> &
# Exit tự động khi lock file bị xóa (unlock signal)
set -euo pipefail

LOCK_PATH="${1:?Usage: as-heartbeat.sh <lock_path> [interval_sec]}"
INTERVAL="${2:-30}"

while [[ -f "$LOCK_PATH" ]]; do
  sleep "$INTERVAL"
  if [[ -f "$LOCK_PATH" ]]; then
    # Update heartbeat_at atomically qua tmpfile
    TMP=$(mktemp "${LOCK_PATH}.XXXXXX" 2>/dev/null || echo "${LOCK_PATH}.tmp.$$.$RANDOM")
    if jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
         '.heartbeat_at = $ts' "$LOCK_PATH" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$LOCK_PATH" 2>/dev/null || rm -f "$TMP"
    else
      rm -f "$TMP" 2>/dev/null || true
    fi
  fi
done
# Lock removed → exit cleanly (no zombie)
