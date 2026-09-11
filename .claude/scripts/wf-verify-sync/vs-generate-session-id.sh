#!/usr/bin/env bash
# Tạo session ID cho wf-verify-sync với counter format (D1=A)
# Usage: bash vs-generate-session-id.sh <SCOPE> [SCOPE_NAME]
#   SCOPE:      all | system | module
#   SCOPE_NAME: tên system hoặc module (required khi SCOPE != "all")
# Output: JSON {session_id, status, action, session_dir}
#   status: "new" | "stale" | "completed" | "active_error"
#   action: "create" | "resume_or_replace" | "list_or_new"
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

SCOPE="${1:?Usage: vs-generate-session-id.sh <all|system|module> [scope_name]}"
SCOPE_NAME="${2:-}"

require_jq
ensure_dirs

# Build slug theo D1=A: all | system-{name} | module-{name}
case "$SCOPE" in
  all)
    SCOPE_SLUG="all"
    ;;
  system)
    if [[ -z "$SCOPE_NAME" ]]; then
      echo '{"error":"missing_scope_name","reason":"SCOPE_NAME required for scope=system"}'
      exit 1
    fi
    # Sanitize scope name
    if ! SAFE_NAME=$(sanitize_id "$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-')" "SCOPE_NAME"); then
      echo '{"error":"invalid_scope_name","reason":"contains invalid characters"}'
      exit 1
    fi
    SCOPE_SLUG="system-${SAFE_NAME}"
    ;;
  module)
    if [[ -z "$SCOPE_NAME" ]]; then
      echo '{"error":"missing_scope_name","reason":"SCOPE_NAME required for scope=module"}'
      exit 1
    fi
    if ! SAFE_NAME=$(sanitize_id "$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-')" "SCOPE_NAME"); then
      echo '{"error":"invalid_scope_name","reason":"contains invalid characters"}'
      exit 1
    fi
    SCOPE_SLUG="module-${SAFE_NAME}"
    ;;
  *)
    echo "{\"error\":\"invalid_scope\",\"reason\":\"scope must be: all|system|module\",\"got\":\"$SCOPE\"}"
    exit 1
    ;;
esac

DATE=$(date +%Y-%m-%d)
PREFIX="${DATE}-${SCOPE_SLUG}-"

# Counter: đếm sessions hiện có với prefix này, tăng 1
EXISTING_COUNT=0
if [[ -d "$SESSIONS_DIR" ]]; then
  EXISTING_COUNT=$(find "$SESSIONS_DIR" -maxdepth 1 -type d -name "${PREFIX}*" 2>/dev/null | wc -l | tr -d ' ')
fi
COUNTER=$(printf "%02d" $((EXISTING_COUNT + 1)))
SESSION_ID="${PREFIX}${COUNTER}"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

# Check collision — session dir đã tồn tại từ trước (counter trùng)?
if [[ -d "$SESSION_DIR" ]]; then
  if [[ -f "$SESSION_DIR/.session.lock" ]]; then
    LOCK_PID=$(jq -r '.pid // 0' "$SESSION_DIR/.session.lock" 2>/dev/null || echo "0")
    LOCK_HOST=$(jq -r '.host // ""' "$SESSION_DIR/.session.lock" 2>/dev/null || echo "")
    MY_HOST=$(get_hostname)
    # Same host: check PID
    if [[ -z "$LOCK_HOST" || "$LOCK_HOST" == "$MY_HOST" ]]; then
      if [[ "$LOCK_PID" != "0" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
        jq -n --arg sid "$SESSION_ID" --argjson pid "${LOCK_PID}" \
          --arg host "$LOCK_HOST" \
          '{error:"session_active", session_id:$sid, pid:$pid, host:$host}'
        exit 1
      fi
    else
      # Cross-host: check heartbeat age
      HEARTBEAT_AT=$(jq -r '.heartbeat_at // .acquired_at // ""' "$SESSION_DIR/.session.lock" 2>/dev/null || echo "")
      if [[ -n "$HEARTBEAT_AT" ]]; then
        STALE_EPOCH=$(to_epoch "$HEARTBEAT_AT")
        if [[ "$STALE_EPOCH" == "-1" ]]; then
          warn "Cannot parse heartbeat timestamp '$HEARTBEAT_AT' — treating as stale (E063)."
          jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" \
            '{session_id:$sid, status:"stale", action:"resume_or_replace", session_dir:$sdir}'
          exit 0
        fi
        NOW_EPOCH=$(date +%s)
        AGE_MINUTES=$(( (NOW_EPOCH - STALE_EPOCH) / 60 ))
        if [[ "$AGE_MINUTES" -le 60 ]]; then
          jq -n --arg sid "$SESSION_ID" --arg host "$LOCK_HOST" --argjson age "$AGE_MINUTES" \
            '{error:"session_active_cross_host", session_id:$sid, host:$host, age_minutes:$age}'
          exit 1
        fi
      fi
    fi
    # Lock stale
    jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" \
      '{session_id:$sid, status:"stale", action:"resume_or_replace", session_dir:$sdir}'
    exit 0
  fi
  # No lock → completed session with same counter (unusual)
  STATUS_VAL=$(jq -r '.status // "unknown"' "$SESSION_DIR/verify-sync-status.json" 2>/dev/null || echo "unknown")
  jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" --arg prev "$STATUS_VAL" \
    '{session_id:$sid, status:"completed", action:"list_or_new", prev_status:$prev, session_dir:$sdir}'
  exit 0
fi

# Fresh session — claim atomically via mkdir (F20: TOCTOU prevention)
# mkdir without -p fails if dir already exists → retry with incremented counter
mkdir_attempt=0
MAX_MKDIR_ATTEMPTS=10
while ! mkdir "$SESSION_DIR" 2>/dev/null; do
  # Another process created this dir between our check and mkdir — increment counter and retry
  mkdir_attempt=$((mkdir_attempt + 1))
  if [[ $mkdir_attempt -ge $MAX_MKDIR_ATTEMPTS ]]; then
    echo "{\"error\":\"mkdir_toctou_exhausted\",\"reason\":\"Failed to claim unique session dir after $MAX_MKDIR_ATTEMPTS attempts\"}"
    exit 1
  fi
  COUNTER=$(printf "%02d" $((EXISTING_COUNT + 1 + mkdir_attempt)))
  SESSION_ID="${PREFIX}${COUNTER}"
  SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"
done
jq -n --arg sid "$SESSION_ID" --arg sdir "$SESSION_DIR" --arg scope "$SCOPE" --arg slug "$SCOPE_SLUG" \
  '{session_id:$sid, status:"new", action:"create", session_dir:$sdir, scope:$scope, scope_slug:$slug}'
