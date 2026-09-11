#!/usr/bin/env bash
# =============================================================================
# setup-triage.sh — Phase 5 Step 5.1 (gộp PRE-GATE + E005 + TRACE START — v10.7)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   5.1 PRE-GATE — Verify Phase 4 completed + count signals từ tất cả lanes
#       E005 healthy path: nếu TOTAL_SIGNALS = 0 → update fix-status phase5+phase6
#       skipped (e005_healthy=true) → orchestrator jump Phase 7.
#   5.2 TRACE START — Mark Phase 5 in_progress + APPEND START event
#
# Required env vars:
#   SESSION_DIR, PROFILE, SCOPE
#
# Exit codes:
#   0 — N > 0, Phase 5 in_progress (orchestrator tiếp tục Step 5.3)
#   1 — Required env var missing
#   2 — Phase 4 chưa completed (E040)
#   3 — Atomic write fail (E035)
#   5 — E005 healthy path: N = 0 (orchestrator jump Phase 7)
#
# Output JSON (stdout):
#   {
#     "total_signals": <int>,
#     "signals_static": <int>,
#     "signals_runtime": <int>,
#     "signals_llm": <int>,
#     "e005_healthy": <bool>,
#     "status": "ok|e005"
#   }
#
# Orchestrator usage:
#   PHASE5_S1=$(bash .claude/scripts/wf-fix-bugs/setup-triage.sh) || RC=$?
#   if [ "$RC" = "5" ]; then echo "E005 healthy — jump Phase 7"; else
#     TOTAL_SIGNALS=$(echo "$PHASE5_S1" | jq -r '.total_signals')
#   fi
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR PROFILE SCOPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

# ── PRE-GATE: Phase 4 phải completed ─────────────────────────────────────────
if ! jq -e '.phases.phase4.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1; then
  echo "ERROR: Phase 4 chưa completed (E040). Chạy Phase 4 trước." >&2
  exit 2
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Count signals từ tất cả lanes (static + runtime + llm) ───────────────────
count_signals() {
  # $1 = stream subdir (static-scan|runtime|llm-scan)
  local stream="$1"
  local cnt
  # Use awk sum (cross-platform — bc absent trên Git Bash Windows)
  cnt=$(find "$LANES_ROOT/" -name "signals.json" -path "*/$stream/*" \
        -exec jq '(.signals // []) | length' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
  [ -z "$cnt" ] && cnt=0
  echo "$cnt"
}

SIGNALS_STATIC=$(count_signals "static-scan")
SIGNALS_RUNTIME=$(count_signals "runtime")
SIGNALS_LLM=$(count_signals "llm-scan")
TOTAL_SIGNALS=$((SIGNALS_STATIC + SIGNALS_RUNTIME + SIGNALS_LLM))

# ── E005 healthy path: N = 0 ─────────────────────────────────────────────────
if [ "$TOTAL_SIGNALS" -eq 0 ]; then
  TMP="$FIX_STATUS.tmp.$$"
  if jq --arg ts "$NOW" \
      '.phases.phase5 = {"status": "completed", "reason": "E005", "e005_healthy": true, "completed_at": $ts}
       | .phases.phase6 = {"status": "completed", "reason": "skipped", "e005_healthy": true, "completed_at": $ts}
       | .issues_total = 0
       | .updated_at = $ts' \
      "$FIX_STATUS" > "$TMP" \
     && jq '.' "$TMP" >/dev/null \
     && mv "$TMP" "$FIX_STATUS"; then
    :
  else
    rm -f "$TMP"
    echo "ERROR: Atomic write fix-status.json fail (E035)" >&2
    exit 3
  fi

  # APPEND E005 event vào session-log
  {
    jq -n --arg ts "$NOW" \
        '{phase:5, event:"E005_HEALTHY", timestamp:$ts, total_signals:0, reason:"no signals — jump Phase 7"}'
  } >> "$SESSION_LOG" 2>/dev/null || true

  jq -n --argjson ts "$TOTAL_SIGNALS" --argjson ss "$SIGNALS_STATIC" \
        --argjson sr "$SIGNALS_RUNTIME" --argjson sl "$SIGNALS_LLM" \
        '{total_signals:$ts, signals_static:$ss, signals_runtime:$sr, signals_llm:$sl, e005_healthy:true, status:"e005"}'
  exit 5
fi

# ── TRACE START: Phase 5 in_progress ─────────────────────────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" \
    '.phases.phase5 = {"status": "in_progress", "started_at": $ts}' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E035)" >&2
  exit 3
fi

# APPEND START event
{
  jq -n --arg ts "$NOW" --argjson ts_count "$TOTAL_SIGNALS" \
      --arg profile "$PROFILE" --arg scope "$SCOPE" \
      '{phase:5, event:"START", timestamp:$ts, signals_total:$ts_count, profile:$profile, scope:$scope}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
jq -n --argjson ts "$TOTAL_SIGNALS" --argjson ss "$SIGNALS_STATIC" \
      --argjson sr "$SIGNALS_RUNTIME" --argjson sl "$SIGNALS_LLM" \
      '{total_signals:$ts, signals_static:$ss, signals_runtime:$sr, signals_llm:$sl, e005_healthy:false, status:"ok"}'

exit 0
