#!/usr/bin/env bash
# mc-index-append.sh — Append entry to sessions.jsonl (append-only)
# Usage: mc-index-append.sh --change-id=CHG-001 --status=in_progress
#        [--summary="..."] [--change-type=...] [--risk-level=...]
#        [--completed-at="..."] [--files-changed=N]
#
# Output: none (appends to sessions.jsonl)
# Exit codes: 0 = success, 1 = error, 2 = invalid args

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

CHANGE_ID=""
STATUS=""
SUMMARY=""
CHANGE_TYPE=""
RISK_LEVEL=""
COMPLETED_AT=""
FILES_CHANGED=""

for arg in "$@"; do
  case "$arg" in
    --change-id=*)     CHANGE_ID="${arg#*=}" ;;
    --status=*)        STATUS="${arg#*=}" ;;
    --summary=*)       SUMMARY="${arg#*=}" ;;
    --change-type=*)   CHANGE_TYPE="${arg#*=}" ;;
    --risk-level=*)    RISK_LEVEL="${arg#*=}" ;;
    --completed-at=*)  COMPLETED_AT="${arg#*=}" ;;
    --files-changed=*) FILES_CHANGED="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$CHANGE_ID" || -z "$STATUS" ]]; then
  mc_err "Usage: mc-index-append.sh --change-id=ID --status=STATUS [--summary=...]"
  exit 2
fi

mc_ensure_dirs

IDENTITY=$(mc_identity)
USER=$(echo "$IDENTITY" | cut -d'@' -f1)
HOST=$(echo "$IDENTITY" | cut -d'@' -f2)
TIMESTAMP=$(mc_timestamp)

if mc_has_jq; then
  ENTRY=$(jq -nc \
    --arg cid "$CHANGE_ID" \
    --arg status "$STATUS" \
    --arg ts "$TIMESTAMP" \
    --arg user "$USER" \
    --arg host "$HOST" \
    --arg summary "$SUMMARY" \
    --arg ctype "$CHANGE_TYPE" \
    --arg risk "$RISK_LEVEL" \
    --arg completed "$COMPLETED_AT" \
    --argjson files "${FILES_CHANGED:-null}" \
    '{change_id:$cid, status:$status, created_at:$ts, user:$user, host:$host, summary:$summary, change_type:$ctype, risk_level:$risk, completed_at:(if $completed == "" then null else $completed end), files_changed:$files}')
else
  ENTRY=$(printf '{"change_id":"%s","status":"%s","created_at":"%s","user":"%s","host":"%s","summary":"%s","change_type":"%s","risk_level":"%s"}' \
    "$CHANGE_ID" "$STATUS" "$TIMESTAMP" "$USER" "$HOST" "$SUMMARY" "$CHANGE_TYPE" "$RISK_LEVEL")
fi

mc_append_jsonl "$MC_INDEX" "$ENTRY"
mc_debug "Appended to sessions.jsonl: $CHANGE_ID ($STATUS)"
