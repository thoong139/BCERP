#!/usr/bin/env bash
# Release session lock cho wf-verify-sync
# Usage: bash vs-release-lock.sh <TYPE> <SESSION_DIR>
#   TYPE: session | registry
# Output: JSON {status:"released"} hoặc {status:"not_found"} hoặc {status:"wrong_session"}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

LOCK_TYPE="${1:?Usage: vs-release-lock.sh <session|registry> <session_dir>}"
SESSION_DIR="${2:?Missing SESSION_DIR}"

# LOCK PATH PATTERN (F23):
#   wf-verify-sync uses skill-specific lock paths:
#   - Session lock:  $SESSION_DIR/.session.lock
#   - Registry lock: .mc-data/docs/_meta/.verify-sync-registry.lock
#   Other skills use different patterns (e.g., .decision-registry.lock,
#   .req-registry.lock). Standardization deferred to cross-cutting initiative.
#
# Xác định lock path theo type
if [[ "$LOCK_TYPE" == "registry" ]]; then
  LOCK_PATH=".mc-data/docs/_meta/.verify-sync-registry.lock"
  LOCK_DIR=".mc-data/docs/_meta/.verify-sync-registry.lock.acquiring"
else
  LOCK_PATH="$SESSION_DIR/.session.lock"
  LOCK_DIR="$SESSION_DIR/.session.lock.acquiring"
fi

# Verify lock session ownership before releasing
RELEASED=false
if [[ -f "$LOCK_PATH" ]]; then
  LOCK_SESSION=$(jq -r '.session_id // .locked_by // ""' "$LOCK_PATH" 2>/dev/null || echo "")
  EXPECTED_SESSION="${SESSION_DIR##*/}"
  if [[ -n "$LOCK_SESSION" && "$LOCK_SESSION" != "$EXPECTED_SESSION" && "$LOCK_SESSION" != "unknown" ]]; then
    jq -n --arg lt "$LOCK_TYPE" --arg lpath "$LOCK_PATH" --arg owner "$LOCK_SESSION" \
      '{status:"wrong_session", lock_type:$lt, lock_path:$lpath, owned_by:$owner}'
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    exit 0
  fi
  rm -f "$LOCK_PATH"
  RELEASED=true
fi
rm -rf "$LOCK_DIR" 2>/dev/null || true

# Kill heartbeat nếu có PID file
HEARTBEAT_PID_FILE="$SESSION_DIR/.heartbeat.pid"
if [[ -f "$HEARTBEAT_PID_FILE" ]]; then
  HEARTBEAT_PID=$(cat "$HEARTBEAT_PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$HEARTBEAT_PID" ]] && kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
  fi
  rm -f "$HEARTBEAT_PID_FILE"
fi

if [[ "$RELEASED" == "true" ]]; then
  echo "{\"status\":\"released\",\"lock_type\":\"$LOCK_TYPE\",\"lock_path\":\"$LOCK_PATH\"}"
else
  echo "{\"status\":\"not_found\",\"lock_type\":\"$LOCK_TYPE\",\"lock_path\":\"$LOCK_PATH\"}"
fi
