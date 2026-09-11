#!/usr/bin/env bash
# browser-lock.sh — Acquire / Release browser-mcp.lock cho Phase 9
# Usage:
#   ./browser-lock.sh acquire <session-dir>      # Acquire lock với TTL 30 min stale auto-release
#   ./browser-lock.sh release <session-dir>      # Release lock (rm)
#   ./browser-lock.sh status  <session-dir>      # Check lock status (held/free/stale)
#
# Logic (port từ _shared.md §21):
# - Per-session lock tại $SESSION_DIR/phase9-e2e-execute/.lock-browser-mcp
# - Content: <pid>:<unix-timestamp> (ISO 8601 string for readability)
# - TTL: 1800 sec (30 min) — auto-release stale lock + reclaim
# - Retry: 5 lần × 10s = max wait 50s
#
# Exit codes: 0=success, 1=fail (lock conflict sau retry)
set -euo pipefail

ACTION="${1:-}"
SESSION_DIR="${2:-}"

[ -z "$ACTION" ] && { echo "Usage: $0 acquire|release|status <session-dir>" >&2; exit 1; }
[ -z "$SESSION_DIR" ] && { echo "Usage: $0 acquire|release|status <session-dir>" >&2; exit 1; }

LOCK_DIR="$SESSION_DIR/phase9-e2e-execute"
LOCK_FILE="$LOCK_DIR/.lock-browser-mcp"
TTL_SEC=1800
MAX_RETRY=5
RETRY_SLEEP=10

acquire_lock() {
  mkdir -p "$LOCK_DIR"

  for i in $(seq 1 "$MAX_RETRY"); do
    if [ ! -f "$LOCK_FILE" ]; then
      # Free → claim
      printf '%s:%s\n' "$$" "$(date -u +%s)" > "$LOCK_FILE"
      printf 'ACQUIRED: pid=%s ts=%s file=%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LOCK_FILE"
      return 0
    fi

    # Lock held — check stale
    LOCK_CONTENT=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -z "$LOCK_CONTENT" ]; then
      # Lock file empty/corrupted — treat as stale
      rm -f "$LOCK_FILE"
      continue
    fi

    LOCK_PID=$(echo "$LOCK_CONTENT" | cut -d: -f1)
    LOCK_TS=$(echo "$LOCK_CONTENT" | cut -d: -f2)
    NOW=$(date -u +%s)
    AGE=$((NOW - LOCK_TS))

    if [ "$AGE" -gt "$TTL_SEC" ]; then
      # Stale lock → auto-release + reclaim
      printf 'E153 stale_lock auto-release: pid=%s age=%ss > ttl=%ss\n' "$LOCK_PID" "$AGE" "$TTL_SEC" >&2
      rm -f "$LOCK_FILE"
      printf '%s:%s\n' "$$" "$NOW" > "$LOCK_FILE"
      printf 'ACQUIRED (after stale-release): pid=%s ts=%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      return 0
    fi

    # Lock alive — wait
    printf 'WAIT attempt %d/%d: lock held by pid=%s age=%ss\n' "$i" "$MAX_RETRY" "$LOCK_PID" "$AGE" >&2
    [ "$i" -lt "$MAX_RETRY" ] && sleep "$RETRY_SLEEP"
  done

  # Exhausted retries
  printf 'E153 failed_to_acquire: after %d retries (max wait %ss)\n' "$MAX_RETRY" "$((MAX_RETRY * RETRY_SLEEP))" >&2
  return 1
}

release_lock() {
  # Lock per-session — Phase 9 procedure quản lý lifecycle.
  # KHÔNG strict pid check vì bash subprocess (script wrapper) có pid khác script gọi.
  # Cross-session safety: Protocol 22 R/W lock (separate mechanism — playwright.rwlock).
  if [ -f "$LOCK_FILE" ]; then
    LOCK_CONTENT=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    LOCK_PID=$(echo "$LOCK_CONTENT" | cut -d: -f1)
    rm -f "$LOCK_FILE"
    printf 'RELEASED: was held by pid=%s, released by pid=%s file=%s\n' "$LOCK_PID" "$$" "$LOCK_FILE"
    return 0
  fi
  printf 'NOTE: lock already released (file missing)\n'
  return 0
}

status_lock() {
  if [ ! -f "$LOCK_FILE" ]; then
    echo "FREE"
    return 0
  fi

  LOCK_CONTENT=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  LOCK_PID=$(echo "$LOCK_CONTENT" | cut -d: -f1)
  LOCK_TS=$(echo "$LOCK_CONTENT" | cut -d: -f2)
  NOW=$(date -u +%s)
  AGE=$((NOW - LOCK_TS))

  if [ "$AGE" -gt "$TTL_SEC" ]; then
    printf 'STALE: pid=%s age=%ss > ttl=%ss\n' "$LOCK_PID" "$AGE" "$TTL_SEC"
  else
    printf 'HELD: pid=%s age=%ss ttl=%ss\n' "$LOCK_PID" "$AGE" "$TTL_SEC"
  fi
}

case "$ACTION" in
  acquire) acquire_lock ;;
  release) release_lock ;;
  status)  status_lock ;;
  *) echo "Unknown action: $ACTION (use acquire|release|status)" >&2; exit 1 ;;
esac
