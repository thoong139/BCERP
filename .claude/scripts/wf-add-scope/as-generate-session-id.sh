#!/usr/bin/env bash
# Tạo session ID + kiểm tra collision
# Usage: bash as-generate-session-id.sh <SYSTEM_ID>
# Output: JSON {session_id, status, action}
#   status: "new" | "stale" | "completed" | "active_error"
#   action: "create" | "resume_or_replace" | "list_or_new_system"
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

SYSTEM_ID="${1:?Usage: as-generate-session-id.sh <SYSTEM_ID>}"

# P0-1 fix: Sanitize SYSTEM_ID before filesystem use
if ! SYSTEM_ID=$(sanitize_id "$SYSTEM_ID" "SYSTEM_ID"); then
  echo '{"error":"invalid_system_id","reason":"contains path traversal or invalid characters"}'
  exit 1
fi

DATE=$(date +%Y-%m-%d)
SYS_SLUG=$(echo "$SYSTEM_ID" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
SESSION_ID="${DATE}-${SYS_SLUG}"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

# Helper: emit JSON via jq (P0-4 fix — no string interpolation)
emit_json() {
  jq -n \
    --arg sid "$SESSION_ID" \
    --arg sdir "$SESSION_DIR" \
    --arg status "$1" \
    --arg action "$2" \
    --arg extra_key "${3:-}" \
    --arg extra_val "${4:-}" \
    '{session_id:$sid, status:$status, action:$action, session_dir:$sdir}' \
    | if [[ -n "$extra_key" ]]; then jq --arg k "$extra_key" --arg v "$extra_val" '. + {($k): $v}'; else cat; fi
}

# Check collision
if [[ -d "$SESSION_DIR" ]]; then
  if [[ -f "$SESSION_DIR/.session.lock" ]]; then
    # Check if lock is alive
    LOCK_PID=$(jq -r '.pid // 0' "$SESSION_DIR/.session.lock" 2>/dev/null || echo "0")
    if [[ "$LOCK_PID" != "0" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
      jq -n --arg sid "$SESSION_ID" --argjson pid "${LOCK_PID:-0}" \
        --arg host "$(jq -r '.host // "unknown"' "$SESSION_DIR/.session.lock" 2>/dev/null || echo "unknown")" \
        '{error:"session_active", session_id:$sid, pid:$pid, host:$host}'
      exit 1
    fi
    # Lock stale → session exists but available for takeover
    jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" \
      '{session_id:$sid, status:"stale", action:"resume_or_replace", session_dir:$sdir}'
    exit 0
  fi
  # No lock → completed session exists (same system, same date)
  STATUS=$(jq -r '.status // "unknown"' "$SESSION_DIR/add-scope-status.json" 2>/dev/null || echo "unknown")
  jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" --arg prev "$STATUS" \
    '{session_id:$sid, status:"completed", action:"list_or_new_system", prev_status:$prev, session_dir:$sdir}'
  exit 0
fi

# No collision → fresh session
jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" \
  '{session_id:$sid, status:"new", action:"create", session_dir:$sdir}'
