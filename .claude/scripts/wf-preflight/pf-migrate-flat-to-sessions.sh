#!/usr/bin/env bash
# pf-migrate-flat-to-sessions.sh — Migrate v2 flat layout to v3 sessions/ layout (D4)
# Usage: pf-migrate-flat-to-sessions.sh
# Output: JSON {status, archive_path?}
# Idempotent: safe to run multiple times.
# NOTE: preflight-history.md is KEPT at flat path (append-only, not session-scoped)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

FLAT_STATUS="$WORK_ROOT/preflight-status.json"
LEGACY_BASE="$SESSIONS_DIR/_legacy-v2"

# Idempotency check 1: already migrated
if [[ -d "$LEGACY_BASE" ]]; then
  echo "{\"status\":\"already_migrated\",\"legacy_dir\":\"$LEGACY_BASE\"}"
  exit 0
fi

# Idempotency check 2: no v2 flat data to migrate
if [[ ! -f "$FLAT_STATUS" ]]; then
  echo "{\"status\":\"no_v2_data\",\"checked_path\":\"$FLAT_STATUS\"}"
  exit 0
fi

# Migrate: create archive directory
TS=$(date +%Y%m%d-%H%M%S)
ARCHIVE_PATH="$LEGACY_BASE/$TS"
mkdir -p "$ARCHIVE_PATH"

# Move flat files (NOT preflight-history.md — keep flat for backward compat)
MOVED=()
for f in preflight-status.json preflight-report.md checkpoint.json phase-summary.md; do
  if [[ -f "$WORK_ROOT/$f" ]]; then
    mv "$WORK_ROOT/$f" "$ARCHIVE_PATH/$f"
    MOVED+=("$f")
  fi
done

# Log to JSONL index
ensure_dirs
MOVED_JSON=$(printf '%s\n' "${MOVED[@]}" | jq -R . | jq -s .)
ENTRY="{\"event\":\"v2_archived\",\"archive_path\":\"$ARCHIVE_PATH\",\"files_moved\":$MOVED_JSON,\"ts\":\"$(get_timestamp)\"}"
echo "$ENTRY" >> "$INDEX_FILE"

MOVED_COUNT=${#MOVED[@]}
echo "{\"status\":\"migrated\",\"archive_path\":\"$ARCHIVE_PATH\",\"files_moved\":$MOVED_COUNT,\"ts\":\"$TS\"}"
