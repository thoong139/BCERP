#!/usr/bin/env bash
# vs-finalize-session.sh — Atomic status + checkpoint finalization
# Ensures verify-sync-status.json and checkpoint.json are ALWAYS updated to "completed".
# Called by Phase 6 (mandatory) and vs-postgate-check.sh (safety net auto-fix).
#
# Usage: bash vs-finalize-session.sh \
#   --session-dir <dir> \
#   --session-id <id> \
#   --sync-rate <pct> \
#   --coverage-rate <pct> \
#   --total-req-ids <n> \
#   --implemented <n> \
#   --in-progress <n> \
#   --not-started <n> \
#   --skipped <n> \
#   --orphan-count <n> \
#   --w001-count <n> \
#   --w002-count <n> \
#   --w003-count <n> \
#   --canonical-decision <override|skip|cancel|no_conflict> \
#   [--verdict <READY|PARTIAL_FEATURES|PARTIAL|NOT_READY>] \
#   [--ui-coverage-pct <pct>]
#
# Output: Updates verify-sync-status.json + checkpoint.json in-place.
# Returns: 0 on success, 1 on failure. JSON result on stdout.
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
SESSION_DIR=""
SESSION_ID=""
SYNC_RATE=""
COVERAGE_RATE=""
TOTAL_REQ_IDS=0
IMPLEMENTED=0
IN_PROGRESS=0
NOT_STARTED=0
SKIPPED=0
ORPHAN_COUNT=0
W001_COUNT=0
W002_COUNT=0
W003_COUNT=0
CANONICAL_DECISION="no_conflict"
VERDICT=""
UI_COVERAGE_PCT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir)       SESSION_DIR="$2"; shift 2 ;;
    --session-id)        SESSION_ID="$2"; shift 2 ;;
    --sync-rate)         SYNC_RATE="$2"; shift 2 ;;
    --coverage-rate)     COVERAGE_RATE="$2"; shift 2 ;;
    --total-req-ids)     TOTAL_REQ_IDS="$2"; shift 2 ;;
    --implemented)       IMPLEMENTED="$2"; shift 2 ;;
    --in-progress)       IN_PROGRESS="$2"; shift 2 ;;
    --not-started)       NOT_STARTED="$2"; shift 2 ;;
    --skipped)           SKIPPED="$2"; shift 2 ;;
    --orphan-count)      ORPHAN_COUNT="$2"; shift 2 ;;
    --w001-count)        W001_COUNT="$2"; shift 2 ;;
    --w002-count)        W002_COUNT="$2"; shift 2 ;;
    --w003-count)        W003_COUNT="$2"; shift 2 ;;
    --canonical-decision) CANONICAL_DECISION="$2"; shift 2 ;;
    --verdict)           VERDICT="$2"; shift 2 ;;
    --ui-coverage-pct)   UI_COVERAGE_PCT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_jq

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
if [[ -z "$SESSION_DIR" ]] || [[ ! -d "$SESSION_DIR" ]]; then
  error "session-dir required and must exist: $SESSION_DIR"
  jq -n '{status: "error", error: "missing_session_dir"}'
  exit 1
fi

STATUS_FILE="$SESSION_DIR/verify-sync-status.json"
CHECKPOINT_FILE="$SESSION_DIR/checkpoint.json"
NOW=$(get_timestamp)

status_updated=false
checkpoint_updated=false

# ---------------------------------------------------------------------------
# 1. Finalize verify-sync-status.json
# ---------------------------------------------------------------------------
if [[ -s "$STATUS_FILE" ]] && jq -e '.' "$STATUS_FILE" >/dev/null 2>&1; then
  # Read current status to check if already completed
  CURRENT_STATUS=$(jq -r '.status // "unknown"' "$STATUS_FILE")

  if [[ "$CURRENT_STATUS" == "completed" ]]; then
    info "Status already completed — skipping update"
    status_updated=true
  else
    # Build phase completion entries — set all phases to completed
    PHASES_JSON=$(jq -r '
      def set_completed(name):
        {name: name, status: "completed", started_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")), completed_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")), error: null};
      {
        phase_0: (.phases.phase_0 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_1: (.phases.phase_1 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_2: (.phases.phase_2 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_3: (.phases.phase_3 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_4: (.phases.phase_4 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_5: (.phases.phase_5 // {} | .status = "completed" | .completed_at = "'"$NOW"'"),
        phase_6: (.phases.phase_6 // {} | .status = "completed" | .completed_at = "'"$NOW"'" | .report_generated = true | .registry_updated = true)
      }
    ' "$STATUS_FILE" 2>/dev/null || echo '{}')

    # Use a temporary file for atomic update
    TMP_STATUS="${STATUS_FILE}.tmp.$$"
    jq -c \
      --arg now "$NOW" \
      --arg cd "$CANONICAL_DECISION" \
      --argjson total "$TOTAL_REQ_IDS" \
      --argjson impl "$IMPLEMENTED" \
      --argjson wip "$IN_PROGRESS" \
      --argjson ns "$NOT_STARTED" \
      --argjson skip "$SKIPPED" \
      --argjson orphan "$ORPHAN_COUNT" \
      --argjson w001 "$W001_COUNT" \
      --argjson w002 "$W002_COUNT" \
      --argjson w003 "$W003_COUNT" \
      --arg rate "${SYNC_RATE:-0}" \
      --arg cov_rate "${COVERAGE_RATE:-0}" \
      '
      .status = "completed" |
      .progress_pct = 100 |
      .timestamps.last_updated = $now |
      .timestamps.completed_at = $now |
      .canonical_decision = $cd |
      .sync_results = {
        total_req_ids: ($total | tonumber),
        implemented: ($impl | tonumber),
        in_progress: ($wip | tonumber),
        not_started: ($ns | tonumber),
        skipped_count: ($skip | tonumber),
        w001_anomalies: ($w001 | tonumber),
        w002_anomalies: ($w002 | tonumber),
        w003_anomalies: ($w003 | tonumber),
        orphan_files: ($orphan | tonumber),
        sync_rate_pct: ($rate | tonumber),
        coverage_rate_pct: ($cov_rate | tonumber)
      } |
      .phases.phase_0.status = "completed" | .phases.phase_0.completed_at = $now |
      .phases.phase_1.status = "completed" | .phases.phase_1.completed_at = $now |
      .phases.phase_2.status = "completed" | .phases.phase_2.completed_at = $now |
      .phases.phase_3.status = "completed" | .phases.phase_3.completed_at = $now |
      .phases.phase_4.status = "completed" | .phases.phase_4.completed_at = $now |
      .phases.phase_5.status = "completed" | .phases.phase_5.completed_at = $now |
      .phases.phase_6.status = "completed" | .phases.phase_6.completed_at = $now |
      .phases.phase_6.report_generated = true |
      .phases.phase_6.registry_updated = true
      ' "$STATUS_FILE" > "$TMP_STATUS"

    if jq -e '.' "$TMP_STATUS" >/dev/null 2>&1; then
      mv "$TMP_STATUS" "$STATUS_FILE"
      info "Status finalized: status=completed, progress=100%, sync_rate=${SYNC_RATE}%"
      status_updated=true
    else
      rm -f "$TMP_STATUS"
      warn "Failed to finalize status JSON — invalid output"
    fi
  fi
else
  warn "Status file missing or invalid: $STATUS_FILE"
fi

# ---------------------------------------------------------------------------
# 2. Finalize checkpoint.json
# ---------------------------------------------------------------------------
if [[ -s "$CHECKPOINT_FILE" ]] && jq -e '.' "$CHECKPOINT_FILE" >/dev/null 2>&1; then
  CURRENT_PHASE=$(jq -r '.position.current_phase // "unknown"' "$CHECKPOINT_FILE")

  if [[ "$CURRENT_PHASE" == "completed" ]]; then
    info "Checkpoint already finalized — skipping update"
    checkpoint_updated=true
  else
    TMP_CP="${CHECKPOINT_FILE}.tmp.$$"
    jq -c \
      --arg now "$NOW" \
      --arg cd "$CANONICAL_DECISION" \
      --arg rate "${SYNC_RATE:-0}" \
      --arg cov_rate "${COVERAGE_RATE:-0}" \
      '
      .timestamp = $now |
      .position.current_phase = "completed" |
      .position.current_phase_name = "completed" |
      .position.current_step = "6.10" |
      .position.next_phase = null |
      .position.next_action = "Skill completed successfully" |
      .progress.current_phase = {id: "completed", name: "completed", status: "completed", progress_pct: 100} |
      .progress.pending_phases = [] |
      .data_snapshot.sync_rate = ($rate | tonumber) |
      .data_snapshot.coverage_rate = ($cov_rate | tonumber) |
      .canonical_decision = $cd
      ' "$CHECKPOINT_FILE" > "$TMP_CP"

    if jq -e '.' "$TMP_CP" >/dev/null 2>&1; then
      mv "$TMP_CP" "$CHECKPOINT_FILE"
      info "Checkpoint finalized: phase=completed"
      checkpoint_updated=true
    else
      rm -f "$TMP_CP"
      warn "Failed to finalize checkpoint JSON — invalid output"
    fi
  fi
else
  warn "Checkpoint file missing or invalid: $CHECKPOINT_FILE"
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if $status_updated && $checkpoint_updated; then
  jq -n '{status: "ok", status_updated: true, checkpoint_updated: true}'
  exit 0
elif $status_updated || $checkpoint_updated; then
  jq -n "{status: \"partial\", status_updated: $status_updated, checkpoint_updated: $checkpoint_updated}"
  exit 0
else
  jq -n '{status: "error", error: "both_files_failed"}'
  exit 1
fi
