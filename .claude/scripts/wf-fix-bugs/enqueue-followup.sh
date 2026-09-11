#!/usr/bin/env bash
# =============================================================================
# enqueue-followup.sh — APPEND-only follow-up queue helper (Wave 3 G4)
# =============================================================================
# Mục đích:
#   Append 1 entry vào .mc-data/work/wf-fix-bugs/_followup-queue.jsonl
#   với atomic mkdir-based lock (cross-session). File JSONL global
#   (KHÔNG per-session). flock không có trên Git Bash Windows nên dùng mkdir.
#
#   Consumers (downstream):
#     - generate-phase7-reports.sh — populate "Follow-up Suggestions" section
#       trong orchestrator-summary.md
#     - User chạy `/wf-fix-bugs --resume-followup` (future) hoặc đọc queue tay
#
# Schema: followup-queue-v1
#   {
#     "$schema": "followup-queue-v1",
#     "queued_at": "<ISO>",
#     "source_session": "<SESSION_ID>",
#     "session_id": "<SESSION_ID>",  // alias for generate-phase7-reports
#     "kind": "cross_scope_fix" | "e2e_scenario_fix" | "manual_review",
#     "suggested_command": "<bash command>",
#     "items": [{"canonical_id":"...","title":"...","reason":"..."}, ...],
#     "priority": "high" | "medium" | "low",
#     "status": "pending"
#   }
#
# Input (env vars):
#   SOURCE_SESSION       — REQUIRED (canonical SESSION_ID producer)
#   KIND                 — REQUIRED (enum: cross_scope_fix | e2e_scenario_fix | manual_review)
#   SUGGESTED_COMMAND    — REQUIRED (bash command for user to run)
#   PRIORITY             — OPTIONAL (default "high")
#   ITEMS_JSON_FILE      — REQUIRED (path tới file chứa JSON array items[])
#
# Idempotency:
#   Nếu queue đã có entry cùng (source_session, kind) status=pending → SKIP dup,
#   trả existing entry timestamp.
#
# Atomic lock: mkdir-based với 10s timeout. Stale lock (>60s) tự takeover.
#
# Exit codes:
#   0 — Entry appended (hoặc skip dup, both OK)
#   1 — Missing required env vars / files
#   2 — Invalid items JSON
#   3 — Lock acquire fail (timeout 10s)
#
# Outputs:
#   stdout: JSON {queued_at, queued: bool, reason: "appended"|"duplicate_skipped"}
#
# Compatibility: Git Bash + WSL. mkdir-based lock works cross-platform.
# =============================================================================

set -eu

# Required env vars
for var in SOURCE_SESSION KIND SUGGESTED_COMMAND ITEMS_JSON_FILE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: env var \$$var is empty" >&2
    exit 1
  fi
done

PRIORITY="${PRIORITY:-high}"

# Validate KIND
case "$KIND" in
  cross_scope_fix|e2e_scenario_fix|manual_review) : ;;
  *)
    echo "ERROR: invalid KIND=$KIND (must be cross_scope_fix|e2e_scenario_fix|manual_review)" >&2
    exit 1
    ;;
esac

if [ ! -s "$ITEMS_JSON_FILE" ]; then
  echo "ERROR: ITEMS_JSON_FILE not found or empty: $ITEMS_JSON_FILE" >&2
  exit 1
fi

# Validate items JSON
if ! jq -e 'type == "array"' "$ITEMS_JSON_FILE" >/dev/null 2>&1; then
  echo "ERROR: ITEMS_JSON_FILE must contain JSON array" >&2
  exit 2
fi

# Resolve queue file path (CANONICAL — global, not per-session)
QUEUE_DIR=".mc-data/work/wf-fix-bugs"
QUEUE_FILE="$QUEUE_DIR/_followup-queue.jsonl"
LOCK_DIR="$QUEUE_DIR/.followup-queue.lock.d"
LOCK_STALE_SEC="${MCV3_FU_LOCK_STALE_SEC:-60}"
LOCK_TIMEOUT_SEC="${MCV3_FU_LOCK_TIMEOUT_SEC:-10}"

mkdir -p "$QUEUE_DIR"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date +%s)

# ─── Acquire mkdir-based lock with timeout + stale takeover ──────────────────
acquire_lock() {
  local deadline=$((NOW_EPOCH + LOCK_TIMEOUT_SEC))
  while true; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      # Lock acquired — write PID + timestamp metadata
      echo "$$" > "$LOCK_DIR/pid"
      echo "$NOW" > "$LOCK_DIR/acquired_at"
      return 0
    fi
    # Lock held — check if stale
    if [ -f "$LOCK_DIR/acquired_at" ]; then
      local acquired_at_epoch
      acquired_at_epoch=$(stat -c %Y "$LOCK_DIR/acquired_at" 2>/dev/null || echo 0)
      local age=$(($(date +%s) - acquired_at_epoch))
      if [ "$age" -gt "$LOCK_STALE_SEC" ]; then
        rm -rf "$LOCK_DIR" 2>/dev/null || true
        continue
      fi
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      return 3
    fi
    sleep 0.2
  done
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}

trap 'release_lock' EXIT

if ! acquire_lock; then
  echo "ERROR: lock acquire timeout (${LOCK_TIMEOUT_SEC}s)" >&2
  exit 3
fi

# ─── Idempotency check: skip if (source_session, kind) already pending ───────
EXISTING=""
if [ -s "$QUEUE_FILE" ]; then
  EXISTING=$(jq -c --arg sid "$SOURCE_SESSION" --arg k "$KIND" \
    'select(.source_session == $sid and .kind == $k and .status == "pending")' \
    "$QUEUE_FILE" 2>/dev/null | head -1 || true)
fi

if [ -n "$EXISTING" ]; then
  EXISTING_TS=$(echo "$EXISTING" | jq -r '.queued_at' 2>/dev/null || echo "$NOW")
  jq -n --arg ts "$EXISTING_TS" \
    '{queued_at: $ts, queued: false, reason: "duplicate_skipped"}'
  exit 0
fi

# ─── Build entry + append ────────────────────────────────────────────────────
ENTRY=$(jq -nc \
  --arg ts "$NOW" \
  --arg sid "$SOURCE_SESSION" \
  --arg k "$KIND" \
  --arg cmd "$SUGGESTED_COMMAND" \
  --arg pri "$PRIORITY" \
  --slurpfile items "$ITEMS_JSON_FILE" \
  '{
    "$schema": "followup-queue-v1",
    queued_at: $ts,
    source_session: $sid,
    session_id: $sid,
    kind: $k,
    suggested_command: $cmd,
    items: $items[0],
    priority: $pri,
    status: "pending"
  }')

if [ -z "$ENTRY" ]; then
  echo "ERROR: failed to build entry JSON" >&2
  exit 2
fi

# Append as JSONL (one line). Use printf to avoid trailing newline issues.
printf '%s\n' "$ENTRY" >> "$QUEUE_FILE"

jq -n --arg ts "$NOW" '{queued_at: $ts, queued: true, reason: "appended"}'

exit 0
