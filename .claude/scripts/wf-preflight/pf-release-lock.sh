#!/usr/bin/env bash
# pf-release-lock.sh — Release session or registry lock
# Usage: pf-release-lock.sh <session|registry> <SESSION_DIR>
# Output: JSON {status, lock_path}
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

LOCK_TYPE="${1:?Usage: pf-release-lock.sh <session|registry> <SESSION_DIR>}"
SESSION_DIR="${2:?SESSION_DIR required}"

if [[ "$LOCK_TYPE" == "registry" ]]; then
  LOCK_PATH="$REGISTRY_LOCK"
elif [[ "$LOCK_TYPE" == "session" ]]; then
  LOCK_PATH="$SESSION_DIR/.session.lock"
else
  echo "{\"error\":\"invalid_lock_type\",\"got\":\"$LOCK_TYPE\"}"
  exit 1
fi

# Also clean up acquiring guard if it exists (orphan cleanup)
LOCK_GUARD="${LOCK_PATH}.acquiring"
rm -rf "$LOCK_GUARD" 2>/dev/null || true

if [[ -f "$LOCK_PATH" ]]; then
  rm -f "$LOCK_PATH"
  echo "{\"status\":\"released\",\"lock_path\":\"$LOCK_PATH\",\"lock_type\":\"$LOCK_TYPE\"}"
else
  echo "{\"status\":\"not_found\",\"lock_path\":\"$LOCK_PATH\",\"lock_type\":\"$LOCK_TYPE\"}"
fi
