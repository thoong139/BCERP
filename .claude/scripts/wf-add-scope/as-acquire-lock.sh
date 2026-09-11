#!/usr/bin/env bash
# Acquire session lock hoặc registry lock
# Usage: bash as-acquire-lock.sh <TYPE> <SESSION_DIR> [TIMEOUT_SEC]
#   TYPE: session | registry
# Output: JSON {status:"acquired", lock_path} hoặc {error, ...}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

LOCK_TYPE="${1:?Usage: as-acquire-lock.sh <session|registry> <session_dir> [timeout_sec]}"
SESSION_DIR="${2:?Missing SESSION_DIR}"
TIMEOUT="${3:-30}"
STALE_MINUTES="${MCV3_LOCK_STALE_MINUTES:-60}"

require_jq

# Xác định lock paths theo type
if [[ "$LOCK_TYPE" == "registry" ]]; then
  LOCK_PATH=".mc-data/docs/_meta/.registry.lock"
  LOCK_DIR=".mc-data/docs/_meta/.registry.lock.acquiring"
else
  LOCK_PATH="$SESSION_DIR/.session.lock"
  LOCK_DIR="$SESSION_DIR/.session.lock.acquiring"
fi

# Ensure session dir tồn tại
mkdir -p "$SESSION_DIR"

# Helper: check existing lock file for conflicts. Returns 0=ok-to-proceed, 1=block, 2=stale-takeover-ok
_check_existing_lock() {
  [[ ! -f "$LOCK_PATH" ]] && return 0  # No lock file → ok
  HEARTBEAT_AT=$(jq -r '.heartbeat_at // .acquired_at // .started_at // ""' "$LOCK_PATH" 2>/dev/null || echo "")
  if [[ -z "$HEARTBEAT_AT" ]]; then
    warn "Lock file has no timestamp — treating as stale. Taking over."
    return 2
  fi
  STALE_EPOCH=$(to_epoch "$HEARTBEAT_AT")
  NOW_EPOCH=$(date +%s)
  AGE_MINUTES=$(( (NOW_EPOCH - STALE_EPOCH) / 60 ))
  if [[ "$AGE_MINUTES" -gt "$STALE_MINUTES" ]]; then
    warn "Lock stale ($AGE_MINUTES min > $STALE_MINUTES min). Taking over."
    return 2
  fi
  # Fresh lock — check cross-host
  LOCK_HOST=$(jq -r '.host // ""' "$LOCK_PATH" 2>/dev/null || echo "")
  MY_HOST=$(get_hostname)
  if [[ -n "$LOCK_HOST" && "$LOCK_HOST" != "$MY_HOST" ]]; then
    jq -n --arg host "$LOCK_HOST" --argjson age "$AGE_MINUTES" \
      '{error:"lock_held_cross_host", held_by_host:$host, age_minutes:$age}'
    return 1
  fi
  # Same host — check PID
  LOCK_PID=$(jq -r '.pid // 0' "$LOCK_PATH" 2>/dev/null || echo "0")
  if [[ "$LOCK_PID" != "0" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    jq -n --argjson pid "$LOCK_PID" --argjson age "$AGE_MINUTES" --arg lpath "$LOCK_PATH" \
      '{error:"lock_held_alive", pid:$pid, age_minutes:$age, lock_path:$lpath}'
    return 1
  fi
  warn "Lock PID $LOCK_PID dead. Taking over."
  return 2
}

# Pre-check: existing lock file BEFORE mkdir (handles post-acquisition state)
# Use || true to prevent set -e from exiting on non-zero return
_check_existing_lock || CHECK_RESULT=$?
CHECK_RESULT=${CHECK_RESULT:-0}
if [[ $CHECK_RESULT -eq 1 ]]; then
  exit 1  # Block — error already printed by _check_existing_lock
fi

# Try mkdir atomic guard (POSIX atomic operation — prevents race during write)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # .acquiring dir exists (another process mid-acquisition) — re-check lock state
  if [[ -f "$LOCK_PATH" ]]; then
    _check_existing_lock || CHECK_RESULT=$?
    CHECK_RESULT=${CHECK_RESULT:-0}
    if [[ $CHECK_RESULT -eq 1 ]]; then
      exit 1
    fi
    # Stale or dead — clean up and retry
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      echo '{"error":"mkdir_failed_after_stale_cleanup"}'
      exit 1
    fi
  else
    # .acquiring dir leftover, no lock file — clean up
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    mkdir "$LOCK_DIR" || { echo '{"error":"mkdir_failed_cleanup"}'; exit 1; }
  fi
fi

# Write lock file
TS=$(get_timestamp)
if [[ "$LOCK_TYPE" == "registry" ]]; then
  jq -n \
    --arg locked_by "${SESSION_DIR##*/}" \
    --arg pid "$$" \
    --arg host "$(get_hostname)" \
    --arg ts "$TS" \
    '{locked_by:$locked_by, pid:($pid|tonumber), host:$host, acquired_at:$ts, heartbeat_at:$ts}' \
    > "$LOCK_PATH"
else
  jq -n \
    --arg sid "${SESSION_DIR##*/}" \
    --arg pid "$$" \
    --arg host "$(get_hostname)" \
    --arg user "$(get_user)" \
    --arg ts "$TS" \
    --argjson interval 30 \
    '{session_id:$sid, pid:($pid|tonumber), host:$host, user:$user, started_at:$ts, heartbeat_at:$ts, heartbeat_interval_sec:$interval}' \
    > "$LOCK_PATH"
fi

rmdir "$LOCK_DIR" 2>/dev/null || true
echo "{\"status\":\"acquired\",\"lock_path\":\"$LOCK_PATH\",\"lock_type\":\"$LOCK_TYPE\"}"
