#!/usr/bin/env bash
# Release session lock hoặc registry lock
# Usage: bash as-release-lock.sh <TYPE> <SESSION_DIR>
#   TYPE: session | registry
# Output: JSON {status:"released"} hoặc {status:"not_found"}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

LOCK_TYPE="${1:?Usage: as-release-lock.sh <session|registry> <session_dir>}"
SESSION_DIR="${2:?Missing SESSION_DIR}"

# Xác định lock path theo type
if [[ "$LOCK_TYPE" == "registry" ]]; then
  LOCK_PATH=".mc-data/docs/_meta/.registry.lock"
  LOCK_DIR=".mc-data/docs/_meta/.registry.lock.acquiring"
else
  LOCK_PATH="$SESSION_DIR/.session.lock"
  LOCK_DIR="$SESSION_DIR/.session.lock.acquiring"
fi

# Clean up cả lock file lẫn acquiring dir (nếu còn sót)
# P1-3 fix: verify lock session ownership before releasing
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

if [[ "$RELEASED" == "true" ]]; then
  echo "{\"status\":\"released\",\"lock_type\":\"$LOCK_TYPE\",\"lock_path\":\"$LOCK_PATH\"}"
else
  echo "{\"status\":\"not_found\",\"lock_type\":\"$LOCK_TYPE\",\"lock_path\":\"$LOCK_PATH\"}"
fi
