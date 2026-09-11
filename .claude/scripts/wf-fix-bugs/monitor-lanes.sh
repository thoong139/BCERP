#!/usr/bin/env bash
# =============================================================================
# monitor-lanes.sh — Phase 4 Step 4.6 (Monitor Loop — v10.6)
# =============================================================================
# Theo dõi tiến độ tất cả lane agents qua poll 30s — exit khi không còn
# in_progress/pending. Bao gồm:
#   - Timeout detection: lane in_progress > 15 phút → E046 → mark failed
#   - Context budget check (CORE-038): >65% prep, >80% checkpoint, >90% FORCE STOP
#
# Required env vars:
#   SESSION_DIR, DIMS_ARRAY
#
# Optional env vars:
#   MCV3_CONTEXT_USAGE  — context % (default: 0, không gate)
#   MCV3_POLL_INTERVAL  — poll interval seconds (default: 30)
#   MCV3_LANE_TIMEOUT   — lane timeout seconds (default: 900 = 15 min)
#
# Exit codes:
#   0 — Tất cả lanes terminal (completed/failed/skipped)
#   8 — Context 80-90%: lưu checkpoint, signal stop_after_collect
#   9 — Context >90%: FORCE STOP E009 — checkpoint bắt buộc
#
# Output JSON (stdout, cuối loop):
#   {
#     "completed": <int>,
#     "failed": <int>,
#     "skipped": <int>,
#     "total": <int>,
#     "stop_after_phase4": <bool>,
#     "exit_reason": "all_terminal|context_80pct|context_90pct"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR DIMS_ARRAY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

POLL_INTERVAL="${MCV3_POLL_INTERVAL:-30}"
LANE_TIMEOUT="${MCV3_LANE_TIMEOUT:-900}"
CONTEXT_PCT="${MCV3_CONTEXT_USAGE:-0}"

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"

STOP_AFTER_PHASE4=false
EXIT_REASON="all_terminal"
LAST_COMPLETED=0; LAST_FAILED=0; LAST_SKIPPED=0; LAST_TOTAL=0

# Helper: atomic write fix-status.json
atomic_update_fix_status() {
  local jq_filter="$1"
  local TMP="$FIX_STATUS.tmp.$$"
  if jq "$jq_filter" "$FIX_STATUS" > "$TMP" \
     && jq '.' "$TMP" >/dev/null \
     && mv "$TMP" "$FIX_STATUS"; then
    return 0
  else
    rm -f "$TMP"
    return 1
  fi
}

while true; do
  COMPLETED=0; FAILED=0; SKIPPED=0; IN_PROGRESS=0; PENDING=0; TOTAL=0

  for dim in $DIMS_ARRAY; do
    TOTAL=$((TOTAL + 1))
    LANE_FILE="$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json"
    [ -f "$LANE_FILE" ] || { PENDING=$((PENDING + 1)); continue; }

    STATUS=$(jq -r '.status // "pending"' "$LANE_FILE" 2>/dev/null || echo "pending")
    case "$STATUS" in
      completed) COMPLETED=$((COMPLETED + 1)) ;;
      skipped)   SKIPPED=$((SKIPPED + 1)) ;;
      failed)    FAILED=$((FAILED + 1)) ;;
      in_progress)
        IN_PROGRESS=$((IN_PROGRESS + 1))
        STARTED=$(jq -r '.started_at // ""' "$LANE_FILE" 2>/dev/null)
        if [ -n "$STARTED" ]; then
          # Cross-platform: dùng date -d (GNU) hoặc gdate (BSD)
          if STARTED_TS=$(date -d "$STARTED" +%s 2>/dev/null); then
            ELAPSED=$(($(date +%s) - STARTED_TS))
            if [ "$ELAPSED" -gt "$LANE_TIMEOUT" ]; then
              echo "E046: Lane $dim timeout (${ELAPSED}s > ${LANE_TIMEOUT}s) — marking failed" >&2
              TMP="$LANE_FILE.tmp.$$"
              jq '.status = "failed" | .errors += [{"code":"E046","message":"Lane timeout"}]' \
                 "$LANE_FILE" > "$TMP" && mv "$TMP" "$LANE_FILE" || rm -f "$TMP"
              FAILED=$((FAILED + 1)); IN_PROGRESS=$((IN_PROGRESS - 1))
            fi
          fi
        fi
        ;;
      *) PENDING=$((PENDING + 1)) ;;
    esac
  done

  echo "[$(date +%H:%M:%S)] Phase 4 Monitor: completed=$COMPLETED skipped=$SKIPPED failed=$FAILED in_progress=$IN_PROGRESS pending=$PENDING (total=$TOTAL)" >&2

  LAST_COMPLETED=$COMPLETED; LAST_FAILED=$FAILED; LAST_SKIPPED=$SKIPPED; LAST_TOTAL=$TOTAL

  # Exit condition: không còn in_progress hoặc pending
  if [ "$IN_PROGRESS" -eq 0 ] && [ "$PENDING" -eq 0 ]; then
    EXIT_REASON="all_terminal"
    break
  fi

  # Context budget check (CORE-038)
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [ "${CONTEXT_PCT:-0}" -ge 90 ]; then
    echo "E009: Context budget >90% (current=${CONTEXT_PCT}%) — FORCE STOP" >&2
    atomic_update_fix_status \
      "(.phases.phase4.status = \"in_progress\")
       | (.phases.phase4.checkpointed_at = \"$NOW_ISO\")
       | (.phases.phase4.context_pct_at_checkpoint = ${CONTEXT_PCT})
       | (.phases.phase4.next_action = \"resume_monitor_loop\")" || true
    {
      jq -n --arg ts "$NOW_ISO" --argjson pct "$CONTEXT_PCT" \
        '{phase:4, event:"CHECKPOINT", timestamp:$ts, reason:"E009_force_stop", context_pct:$pct}'
    } >> "$SESSION_LOG" 2>/dev/null || true
    echo "Hướng dẫn: chạy /wf-fix-bugs --resume sau khi context được reset." >&2

    # Emit final status JSON
    jq -n --argjson c "$COMPLETED" --argjson f "$FAILED" --argjson s "$SKIPPED" \
       --argjson t "$TOTAL" --argjson sap true --arg er "context_90pct" \
       '{completed:$c, failed:$f, skipped:$s, total:$t, stop_after_phase4:$sap, exit_reason:$er}'
    exit 9

  elif [ "${CONTEXT_PCT:-0}" -ge 80 ]; then
    echo "WARN: Context budget ${CONTEXT_PCT}% (80-90%) — checkpoint + STOP sau Phase 4" >&2
    atomic_update_fix_status \
      "(.phases.phase4.checkpointed_at = \"$NOW_ISO\")
       | (.phases.phase4.context_pct_at_checkpoint = ${CONTEXT_PCT})
       | (.phases.phase4.next_action = \"stop_after_collect\")" || true
    {
      jq -n --arg ts "$NOW_ISO" --argjson pct "$CONTEXT_PCT" \
        '{phase:4, event:"CHECKPOINT", timestamp:$ts, reason:"context_80pct_stop_after_phase", context_pct:$pct}'
    } >> "$SESSION_LOG" 2>/dev/null || true
    STOP_AFTER_PHASE4=true
    EXIT_REASON="context_80pct"

  elif [ "${CONTEXT_PCT:-0}" -ge 65 ]; then
    atomic_update_fix_status \
      "(.phases.phase4.context_pct_last_seen = ${CONTEXT_PCT})
       | (.phases.phase4.last_checkpoint_seen_at = \"$NOW_ISO\")" || true
  fi

  sleep "$POLL_INTERVAL"
done

# Emit final status JSON
jq -n --argjson c "$LAST_COMPLETED" --argjson f "$LAST_FAILED" --argjson s "$LAST_SKIPPED" \
   --argjson t "$LAST_TOTAL" --argjson sap "$STOP_AFTER_PHASE4" --arg er "$EXIT_REASON" \
   '{completed:$c, failed:$f, skipped:$s, total:$t, stop_after_phase4:$sap, exit_reason:$er}'

if [ "$STOP_AFTER_PHASE4" = "true" ]; then
  exit 8
fi
exit 0
