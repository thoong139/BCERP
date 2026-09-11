#!/usr/bin/env bash
# Background heartbeat daemon — cập nhật heartbeat_at trong lock file mỗi INTERVAL giây
# Usage: bash vs-heartbeat.sh <lock_path> [interval_sec]
#   lock_path: path to .session.lock
#   interval_sec: default 30
# Chạy trong background: bash vs-heartbeat.sh <path> &
# Exit tự động khi lock file bị xóa (unlock signal)
set -euo pipefail

LOCK_PATH="${1:?Usage: vs-heartbeat.sh <lock_path> [interval_sec] [max_updates]}"
INTERVAL="${2:-30}"
MAX_UPDATES="${3:-1440}"   # Default 12h at 30s intervals (F18)

COUNT=0

while [[ -f "$LOCK_PATH" ]]; do
  sleep "$INTERVAL"
  if [[ -f "$LOCK_PATH" ]]; then
    # Update heartbeat_at + count atomically qua tmpfile
    TMP=$(mktemp "${LOCK_PATH}.XXXXXX" 2>/dev/null || echo "${LOCK_PATH}.tmp.$$.$RANDOM")
    if jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
         --argjson cnt "$((COUNT + 1))" \
         '.heartbeat_at = $ts | .heartbeat_count = $cnt' "$LOCK_PATH" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$LOCK_PATH" 2>/dev/null || rm -f "$TMP"
    else
      rm -f "$TMP" 2>/dev/null || true
    fi
  fi
  COUNT=$((COUNT + 1))
  if [[ $COUNT -ge $MAX_UPDATES ]]; then
    # Auto-exit: max updates reached (zombie guard F18)
    # Remove lock file to release session (parent process likely killed)
    rm -f "$LOCK_PATH" 2>/dev/null || true
    break
  fi
done
# Lock removed or max reached → exit cleanly (no zombie)
