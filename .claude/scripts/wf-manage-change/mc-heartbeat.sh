#!/usr/bin/env bash
# mc-heartbeat.sh — Background heartbeat daemon for session lock
# Usage: mc-heartbeat.sh --id=CHG-20260429-001 &
#
# Runs in background, updates heartbeat_at every INTERVAL seconds.
# Stops when lock file is removed (session ended) or max timeout reached.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

ID=""
INTERVAL=30
MAX_SEC="${MCV3_MC_HEARTBEAT_MAX_SEC:-28800}"  # Default 8 hours

for arg in "$@"; do
  case "$arg" in
    --id=*)       ID="${arg#*=}" ;;
    --interval=*) INTERVAL="${arg#*=}" ;;
    --max-sec=*)  MAX_SEC="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$ID" ]]; then
  mc_err "Usage: mc-heartbeat.sh --id=CHANGE_ID [--interval=30] [--max-sec=28800]"
  exit 2
fi

LOCK_FILE="$MC_ROOT/$ID/.session.lock"
START_EPOCH=$(mc_epoch)
PPID_CHECK="${PPID:-0}"

elapsed_ok() {
  local now
  now=$(mc_epoch)
  local elapsed=$(( now - START_EPOCH ))
  if (( elapsed >= MAX_SEC )); then
    mc_warn "Heartbeat max timeout reached (${elapsed}s >= ${MAX_SEC}s) — stopping"
    return 1
  fi
  return 0
}

parent_alive() {
  # Check if parent process still running (prevent orphans)
  if [[ "$PPID_CHECK" -gt 1 ]]; then
    if ! kill -0 "$PPID_CHECK" 2>/dev/null; then
      mc_warn "Parent process ($PPID_CHECK) gone — heartbeat stopping"
      return 1
    fi
  fi
  return 0
}

while true; do
  sleep "$INTERVAL"

  # Guard: stop if max timeout or parent dead
  if ! elapsed_ok || ! parent_alive; then
    exit 0
  fi

  if [[ -f "$LOCK_FILE" ]]; then
    TIMESTAMP=$(mc_timestamp)
    if mc_has_jq; then
      # Safe: tmp file → validate → rename (atomic, no sed injection risk)
      local_tmp="${LOCK_FILE}.hb.$$"
      if jq --arg ts "$TIMESTAMP" '.heartbeat_at = $ts' "$LOCK_FILE" > "$local_tmp" 2>/dev/null; then
        mv "$local_tmp" "$LOCK_FILE"
      else
        rm -f "$local_tmp"
        mc_warn "Heartbeat jq update failed for $LOCK_FILE"
      fi
    else
      # jq-less: rewrite entire lock file with updated timestamp
      # Read current content, replace heartbeat_at value
      local_content=$(cat "$LOCK_FILE" 2>/dev/null || echo '{}')
      # Best-effort string replace for heartbeat_at field
      local_updated=$(printf '%s' "$local_content" | sed "s/\"heartbeat_at\":\"[^\"]*\"/\"heartbeat_at\":\"$TIMESTAMP\"/" 2>/dev/null || echo "$local_content")
      printf '%s' "$local_updated" > "$LOCK_FILE" 2>/dev/null || true
    fi
    mc_debug "Heartbeat: $LOCK_FILE"
  else
    # Lock removed — stop heartbeat
    mc_log "Lock gone, heartbeat stopping: $LOCK_FILE"
    exit 0
  fi
done
