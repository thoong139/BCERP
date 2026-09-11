#!/usr/bin/env bash
# mc-release-lock.sh — Release lock (session or registry)
# Usage: mc-release-lock.sh --type=session --id=CHG-20260429-001
#        mc-release-lock.sh --type=registry --id=CHG-20260429-001
#
# Exit codes: 0 = released or not found (idempotent), 2 = invalid args

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

TYPE=""
ID=""

for arg in "$@"; do
  case "$arg" in
    --type=*) TYPE="${arg#*=}" ;;
    --id=*)   ID="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$TYPE" || -z "$ID" ]]; then
  mc_err "Usage: mc-release-lock.sh --type=session|registry --id=CHANGE_ID"
  exit 2
fi

if [[ "$TYPE" == "session" ]]; then
  LOCK_FILE="$MC_ROOT/$ID/.session.lock"
elif [[ "$TYPE" == "registry" ]]; then
  LOCK_FILE="$MC_LOCKS_DIR/registry.lock"
else
  mc_err "Invalid lock type: $TYPE (expected: session | registry)"
  exit 2
fi

if [[ -f "$LOCK_FILE" ]]; then
  rm -f "$LOCK_FILE"
  mc_log "Lock released: $LOCK_FILE"
fi

# Cleanup mkdir-based lock directory (v3.0.1 pattern)
LOCK_DIR="${LOCK_FILE}.d"
if [[ -d "$LOCK_DIR" ]]; then
  rm -rf "$LOCK_DIR"
  mc_log "Lock dir removed: $LOCK_DIR"
fi

if [[ ! -f "$LOCK_FILE" && ! -d "$LOCK_DIR" ]]; then
  mc_debug "Lock already released: $LOCK_FILE"
fi
