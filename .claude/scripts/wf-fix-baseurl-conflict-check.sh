#!/usr/bin/env bash
# wf-fix-baseurl-conflict-check.sh — v10.2
# Phát hiện session khác trong wf-fix-bugs đang test cùng BASE_URL.
# Output JSON: {"conflict": bool, "peer_sessions": [{session_id, url, started_at, age_minutes}]}
#
# Usage: bash wf-fix-baseurl-conflict-check.sh --url=<BASE_URL> [--current-session=<SESSION_ID>]
#
# Mục đích: Step 1.9 Browser CDG đọc kết quả này → AskUserQuestion nếu có conflict.
# Escape hatch: env MCV3_PW_ALLOW_SHARED_URL=1 → output empty conflict, không emit warning.

set -euo pipefail

URL=""
CURRENT_SESSION=""
INDEX_FILE=".mc-data/work/wf-fix-bugs/_index/sessions.jsonl"
MAX_AGE_MINUTES=120  # session quá 2 giờ coi như stale, không conflict

for arg in "$@"; do
  case "$arg" in
    --url=*)             URL="${arg#*=}" ;;
    --current-session=*) CURRENT_SESSION="${arg#*=}" ;;
    --index=*)           INDEX_FILE="${arg#*=}" ;;
    --max-age=*)         MAX_AGE_MINUTES="${arg#*=}" ;;
  esac
done

# Escape hatch
if [ "${MCV3_PW_ALLOW_SHARED_URL:-0}" = "1" ]; then
  echo '{"conflict":false,"peer_sessions":[],"bypassed":"MCV3_PW_ALLOW_SHARED_URL"}'
  exit 0
fi

# Skip nếu thiếu URL hoặc index file
if [ -z "$URL" ] || [ ! -f "$INDEX_FILE" ]; then
  echo '{"conflict":false,"peer_sessions":[],"reason":"missing_url_or_index"}'
  exit 0
fi

# Normalize URL — trim trailing slash, lowercase host
NORM_URL=$(echo "$URL" | sed 's:/*$::' | tr '[:upper:]' '[:lower:]')

# Đọc index, lọc:
#  - không phải current session
#  - status in_progress
#  - cùng URL (normalized)
#  - started_at < MAX_AGE_MINUTES
NOW_TS=$(date +%s)
PEER_SESSIONS=$(jq -c --arg cur "$CURRENT_SESSION" --arg url "$NORM_URL" --argjson now "$NOW_TS" --argjson maxAge "$MAX_AGE_MINUTES" '
  select(.session_id != $cur and .status == "in_progress")
  | (.base_url // "" | ascii_downcase | sub("/+$"; "")) as $peer_url
  | select($peer_url == $url)
  | (.started_at // "1970-01-01T00:00:00Z" | fromdateiso8601 // 0) as $started
  | (($now - $started) / 60 | floor) as $age_min
  | select($age_min < $maxAge)
  | {session_id: .session_id, url: $peer_url, started_at: .started_at, age_minutes: $age_min}
' "$INDEX_FILE" 2>/dev/null | jq -s '.' || echo "[]")

PEER_COUNT=$(echo "$PEER_SESSIONS" | jq 'length')

# F05.005 (Sprint 8): Dùng `jq -n` thay shell concat để JSON-safe.
# Shell concat (`"{\"conflict\":...}"`) fail nếu $PEER_SESSIONS chứa ký tự đặc biệt.
if [ "$PEER_COUNT" -gt 0 ]; then
  jq -n --argjson peers "$PEER_SESSIONS" '{conflict: true, peer_sessions: $peers}'
else
  jq -n '{conflict: false, peer_sessions: []}'
fi
