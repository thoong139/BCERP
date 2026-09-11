#!/usr/bin/env bash
# pf-heartbeat.sh — Background heartbeat daemon for session lock
# Usage: pf-heartbeat.sh <LOCK_PATH> [INTERVAL_SEC=30]
# Run in background: bash pf-heartbeat.sh $SESSION_DIR/.session.lock 30 &
# Exits automatically when lock file is removed.
LOCK_PATH="${1:?Usage: pf-heartbeat.sh <LOCK_PATH> [INTERVAL_SEC]}"
INTERVAL="${2:-30}"

while [[ -f "$LOCK_PATH" ]]; do
  sleep "$INTERVAL"
  if [[ -f "$LOCK_PATH" ]]; then
    tmp=$(mktemp 2>/dev/null || echo "/tmp/pf-hb-$$")
    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")" \
       '.heartbeat_at = $ts' "$LOCK_PATH" > "$tmp" 2>/dev/null && \
    mv "$tmp" "$LOCK_PATH" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
  fi
done
