#!/usr/bin/env bash
# implement-history-index.sh — Append entry vào .history/implementations-index.jsonl.
# Sprint 1 — Multi-dev safety: append-only JSONL, git-sync friendly.
#
# Usage:
#   bash implement-history-index.sh \
#     --system=erp-web \
#     --feature-slug=customer-management \
#     --feat-id=FEAT-CRM-CUST-001 \
#     --session-id=2026-04-28-103045-laptop \
#     --status=completed \
#     [--scenario=NEW|EXTEND|MODIFY] \
#     [--profile=quick|standard|deep|exhaustive] \
#     [--files-created=12 --files-modified=3 --tests-count=24] \
#     [--decisions-added=2] \
#     [--started-at=ISO8601] \
#     [--completed-at=ISO8601]
#
# v5.0: --system field bổ sung để filter cross-system trong UI / status command.
#       Nếu chưa pass, auto-derive từ registry (graceful).
#
# Output: 0 = appended, 1 = invalid args, 2 = invalid JSON
# Stdout: appended entry (1 line JSON)

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

FEATURE_SLUG=""
SYSTEM_SLUG=""
FEAT_ID=""
SESSION_ID=""
STATUS=""
SCENARIO="NEW"
PROFILE="standard"
FILES_CREATED=0
FILES_MODIFIED=0
TESTS_COUNT=0
DECISIONS_ADDED=0
STARTED_AT=""
COMPLETED_AT=""

for arg in "$@"; do
  case "$arg" in
    --system=*)          SYSTEM_SLUG="${arg#*=}" ;;
    --feature-slug=*)    FEATURE_SLUG="${arg#*=}" ;;
    --feat-id=*)         FEAT_ID="${arg#*=}" ;;
    --session-id=*)      SESSION_ID="${arg#*=}" ;;
    --status=*)          STATUS="${arg#*=}" ;;
    --scenario=*)        SCENARIO="${arg#*=}" ;;
    --profile=*)         PROFILE="${arg#*=}" ;;
    --files-created=*)   FILES_CREATED="${arg#*=}" ;;
    --files-modified=*)  FILES_MODIFIED="${arg#*=}" ;;
    --tests-count=*)     TESTS_COUNT="${arg#*=}" ;;
    --decisions-added=*) DECISIONS_ADDED="${arg#*=}" ;;
    --started-at=*)      STARTED_AT="${arg#*=}" ;;
    --completed-at=*)    COMPLETED_AT="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

# Auto-derive system_slug nếu chưa pass
if [[ -z "$SYSTEM_SLUG" && -n "$FEAT_ID$FEATURE_SLUG" ]]; then
  SYSTEM_SLUG=$(derive_system_slug "${FEAT_ID:-$FEATURE_SLUG}")
fi

[[ -z "$FEATURE_SLUG" ]] && { log_error "--feature-slug required"; exit 1; }
[[ -z "$SESSION_ID" ]] && { log_error "--session-id required"; exit 1; }
[[ -z "$STATUS" ]] && { log_error "--status required"; exit 1; }

# Validate status enum
case "$STATUS" in
  started|in_progress|completed|failed|aborted) ;;
  *) log_error "--status invalid: $STATUS (allowed: started/in_progress/completed/failed/aborted)"; exit 1 ;;
esac

# Numeric validation
for v in "$FILES_CREATED" "$FILES_MODIFIED" "$TESTS_COUNT" "$DECISIONS_ADDED"; do
  [[ "$v" =~ ^[0-9]+$ ]] || { log_error "Numeric value invalid: $v"; exit 1; }
done

# Default timestamps
[[ -z "$COMPLETED_AT" ]] && COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ -z "$STARTED_AT" ]] && STARTED_AT="$COMPLETED_AT"

mkdir -p "$HISTORY_DIR"
INDEX_FILE="$HISTORY_DIR/implementations-index.jsonl"

# ─── Build entry ─────────────────────────────────────────────

CURRENT_HOST=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")

if has_jq; then
  ENTRY=$(jq -nc \
    --arg sys "$SYSTEM_SLUG" \
    --arg fs "$FEATURE_SLUG" \
    --arg fid "$FEAT_ID" \
    --arg sid "$SESSION_ID" \
    --arg host "$CURRENT_HOST" \
    --arg user "${USER:-unknown}" \
    --arg scenario "$SCENARIO" \
    --arg profile "$PROFILE" \
    --arg started "$STARTED_AT" \
    --arg completed "$COMPLETED_AT" \
    --arg status "$STATUS" \
    --argjson fc "$FILES_CREATED" \
    --argjson fm "$FILES_MODIFIED" \
    --argjson tc "$TESTS_COUNT" \
    --argjson da "$DECISIONS_ADDED" \
    '{
      system: $sys,
      feature_slug: $fs,
      feat_id: $fid,
      session_id: $sid,
      host: $host,
      user: $user,
      scenario: $scenario,
      profile: $profile,
      started_at: $started,
      completed_at: $completed,
      status: $status,
      files_created: $fc,
      files_modified: $fm,
      tests_count: $tc,
      decisions_added: $da
    }')
else
  ENTRY=$(printf '{"system":"%s","feature_slug":"%s","feat_id":"%s","session_id":"%s","host":"%s","user":"%s","scenario":"%s","profile":"%s","started_at":"%s","completed_at":"%s","status":"%s","files_created":%d,"files_modified":%d,"tests_count":%d,"decisions_added":%d}' \
    "$SYSTEM_SLUG" "$FEATURE_SLUG" "$FEAT_ID" "$SESSION_ID" "$CURRENT_HOST" "${USER:-unknown}" "$SCENARIO" "$PROFILE" "$STARTED_AT" "$COMPLETED_AT" "$STATUS" "$FILES_CREATED" "$FILES_MODIFIED" "$TESTS_COUNT" "$DECISIONS_ADDED")
fi

# ─── Append (multi-dev safe) ─────────────────────────────────

# Pattern git-sync friendly: append entry < 4KB là atomic trên POSIX
# (filesystem block size + write() atomicity).
# Nếu cần multi-process safety hơn nữa → cần lock; hiện tại single-line
# entry size đảm bảo atomic tại OS level.

append_jsonl "$INDEX_FILE" "$ENTRY"

echo "$ENTRY"
exit 0
