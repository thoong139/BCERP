#!/usr/bin/env bash
# Migrate add-scope-status.json từ v2.0 → v3.0 schema
# Usage: bash as-migrate-status-v2-to-v3.sh <status_file>
# Output: JSON {status:"migrated"|"already_v3"|"error", ...}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

OLD_FILE="${1:?Usage: as-migrate-status-v2-to-v3.sh <status_file>}"

require_jq

if ! test -f "$OLD_FILE"; then
  echo "{\"error\":\"file_not_found\",\"path\":\"$OLD_FILE\"}"
  exit 1
fi

# Detect v2.0 vs v3.0
SCHEMA=$(jq -r '.schema_version // .["$schema"] // ""' "$OLD_FILE" 2>/dev/null || echo "")
if [[ "$SCHEMA" == "add-scope-status-v3.0" ]]; then
  echo '{"status":"already_v3","action":"none"}'
  exit 0
fi

# Backup before migrate
BACKUP="${OLD_FILE}.v2-backup.$(date +%s)"
cp "$OLD_FILE" "$BACKUP"

# Determine session ID from file
SESSION_ID=$(jq -r '.add_scope_id // .session_id // "unknown"' "$OLD_FILE" 2>/dev/null || echo "unknown")

# Migrate fields — preserve all existing + add v3.0 fields
TMP=$(mktemp)
jq \
  --arg schema "add-scope-status-v3.0" \
  --arg sid "$SESSION_ID" \
  --arg host "$(hostname 2>/dev/null || echo unknown)" \
  --arg user "$(whoami 2>/dev/null || echo unknown)" \
  '. + {
    "$schema": $schema,
    schema_version: $schema,
    session_id: ($sid),
    host: (if .host then .host else $host end),
    user: (if .user then .user else $user end),
    lock: (if .lock then .lock else {
      session_lock_path: (".mc-data/work/wf-add-scope/sessions/" + $sid + "/.session.lock"),
      registry_lock_acquired: false,
      heartbeat_pid: null
    } end),
    audit_chain: (if .audit_chain then .audit_chain else {
      checksum_pre: null,
      checksum_post: null
    } end)
  } |
  if .summary.modules_added | type == "number" then
    .summary.modules_added_v2_count = .summary.modules_added | .summary.modules_added = []
  else . end' \
  "$OLD_FILE" > "$TMP" && mv "$TMP" "$OLD_FILE"

echo "{\"status\":\"migrated\",\"from\":\"v2.0\",\"to\":\"v3.0\",\"backup\":\"$BACKUP\",\"session_id\":\"$SESSION_ID\"}"
