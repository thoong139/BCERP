#!/usr/bin/env bash
# pf-acquire-lock.sh — Acquire session or registry lock (POSIX atomic mkdir)
# Usage: pf-acquire-lock.sh <session|registry> <SESSION_DIR> [TIMEOUT_SEC=30]
# Output: JSON {status, lock_path} or {error, ...}
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

LOCK_TYPE="${1:?Usage: pf-acquire-lock.sh <session|registry> <SESSION_DIR> [TIMEOUT_SEC]}"
SESSION_DIR="${2:?SESSION_DIR required}"
TIMEOUT="${3:-30}"
STALE_MINUTES="${MCV3_LOCK_STALE_MINUTES:-60}"

# Determine lock path
if [[ "$LOCK_TYPE" == "registry" ]]; then
  LOCK_PATH="$REGISTRY_LOCK"
  LOCK_GUARD="${REGISTRY_LOCK}.acquiring"
elif [[ "$LOCK_TYPE" == "session" ]]; then
  LOCK_PATH="$SESSION_DIR/.session.lock"
  LOCK_GUARD="${SESSION_DIR}/.session.lock.acquiring"
else
  echo "{\"error\":\"invalid_lock_type\",\"got\":\"$LOCK_TYPE\",\"valid\":[\"session\",\"registry\"]}"
  exit 1
fi

require_jq
ensure_dirs
mkdir -p "$(dirname "$LOCK_PATH")" 2>/dev/null || true

# POSIX atomic mkdir guard
if ! mkdir "$LOCK_GUARD" 2>/dev/null; then
  # Guard exists — check if existing lock is stale
  if [[ -f "$LOCK_PATH" ]]; then
    HEARTBEAT_AT=$(jq -r '.heartbeat_at // .acquired_at // .started_at // empty' "$LOCK_PATH" 2>/dev/null || echo "")
    if [[ -n "$HEARTBEAT_AT" ]]; then
      # Calculate age in minutes
      STALE_EPOCH=$(date -d "$HEARTBEAT_AT" +%s 2>/dev/null || \
                    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$HEARTBEAT_AT" +%s 2>/dev/null || echo "0")
      NOW_EPOCH=$(date +%s)
      AGE_MINUTES=$(( (NOW_EPOCH - STALE_EPOCH) / 60 ))

      if [[ $AGE_MINUTES -gt $STALE_MINUTES ]]; then
        # Stale lock — allow takeover
        warn "Lock stale (${AGE_MINUTES}min > ${STALE_MINUTES}min threshold). Taking over."
        rm -rf "$LOCK_GUARD"
        mkdir "$LOCK_GUARD" 2>/dev/null || {
          echo "{\"error\":\"takeover_failed\",\"reason\":\"mkdir_race\"}"; exit 1
        }
      else
        # Active lock — check cross-host
        LOCK_HOST=$(jq -r '.host // ""' "$LOCK_PATH" 2>/dev/null || echo "")
        MY_HOST=$(get_hostname)
        if [[ -n "$LOCK_HOST" && "$LOCK_HOST" != "$MY_HOST" ]]; then
          echo "{\"error\":\"lock_held_cross_host\",\"held_by_host\":\"$LOCK_HOST\",\"age_minutes\":$AGE_MINUTES,\"stale_threshold\":$STALE_MINUTES}"
          exit 1
        fi
        # Same host — check if PID still alive
        LOCK_PID=$(jq -r '.pid // 0' "$LOCK_PATH" 2>/dev/null || echo "0")
        if [[ "$LOCK_PID" -gt 0 ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
          echo "{\"error\":\"lock_held_alive\",\"pid\":$LOCK_PID,\"age_minutes\":$AGE_MINUTES,\"host\":\"$LOCK_HOST\"}"
          exit 1
        fi
        # PID dead on same host — allow takeover
        warn "Lock PID $LOCK_PID dead. Taking over."
        rm -rf "$LOCK_GUARD"
        mkdir "$LOCK_GUARD" 2>/dev/null || {
          echo "{\"error\":\"takeover_failed\",\"reason\":\"mkdir_race_dead_pid\"}"; exit 1
        }
      fi
    else
      # Lock file missing or unreadable — assume stale guard
      rm -rf "$LOCK_GUARD"
      mkdir "$LOCK_GUARD" 2>/dev/null || {
        echo "{\"error\":\"guard_stuck\"}"; exit 1
      }
    fi
  else
    # Guard exists but lock file missing — orphaned guard, clean up
    rm -rf "$LOCK_GUARD"
    mkdir "$LOCK_GUARD" 2>/dev/null || {
      echo "{\"error\":\"guard_cleanup_failed\"}"; exit 1
    }
  fi
fi

# After acquiring the guard, also check if a valid lock file already exists
# (handles case where guard was released by previous run but lock file still active)
if [[ -f "$LOCK_PATH" ]]; then
  EXISTING_PID=$(jq -r '.pid // 0' "$LOCK_PATH" 2>/dev/null || echo "0")
  EXISTING_HOST=$(jq -r '.host // ""' "$LOCK_PATH" 2>/dev/null || echo "")
  MY_HOST=$(get_hostname)
  if [[ -n "$EXISTING_HOST" && "$EXISTING_HOST" != "$MY_HOST" ]]; then
    rmdir "$LOCK_GUARD" 2>/dev/null || true
    echo "{\"error\":\"lock_held_cross_host\",\"held_by_host\":\"$EXISTING_HOST\"}"
    exit 1
  fi
  if [[ "$EXISTING_PID" -gt 0 ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    rmdir "$LOCK_GUARD" 2>/dev/null || true
    echo "{\"error\":\"lock_held_alive\",\"pid\":$EXISTING_PID,\"host\":\"$EXISTING_HOST\"}"
    exit 1
  fi
  # Existing lock is dead or no alive PID — allow overwrite
fi

# Write lock file
if [[ "$LOCK_TYPE" == "registry" ]]; then
  jq -n \
    --arg locked_by "${SESSION_DIR##*/}" \
    --arg pid "$$" \
    --arg host "$(get_hostname)" \
    --arg ts "$(get_timestamp)" \
    '{locked_by:$locked_by, pid:($pid|tonumber), host:$host, acquired_at:$ts, heartbeat_at:$ts}' \
    > "$LOCK_PATH"
else
  jq -n \
    --arg sid "${SESSION_DIR##*/}" \
    --arg pid "$$" \
    --arg host "$(get_hostname)" \
    --arg user "$(get_user)" \
    --arg ts "$(get_timestamp)" \
    --argjson interval 30 \
    '{session_id:$sid, pid:($pid|tonumber), host:$host, user:$user, started_at:$ts, heartbeat_at:$ts, heartbeat_interval_sec:$interval}' \
    > "$LOCK_PATH"
fi

# Release atomic guard
rmdir "$LOCK_GUARD"

echo "{\"status\":\"acquired\",\"lock_path\":\"$LOCK_PATH\",\"lock_type\":\"$LOCK_TYPE\"}"
