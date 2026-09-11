#!/usr/bin/env bash
# =============================================================================
# finalize-phase4.sh — Phase 4 Step 4.9 (gộp Update fix-status + TRACE COMPLETE — v10.6)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   4.9 Update fix-status.json — mark phase4 completed + aggregate signals_total
#   4.10 TRACE COMPLETE — APPEND COMPLETE event vào session-log.json
#
# Required env vars:
#   SESSION_DIR, DIMS_ARRAY
#
# Optional env vars:
#   LANES_COMPLETED   (default: count từ lane-status.json)
#   LANES_FAILED      (default: count từ lane-status.json)
#   PROBE_FAILURES    (default: count lines từ probe-failures.log)
#
# Exit codes:
#   0 — Both writes pass
#   1 — Required env var missing
#   3 — Atomic write fail
#
# Output JSON (stdout):
#   {
#     "signals_total": <int>,
#     "lanes_completed": <int>,
#     "lanes_failed": <int>,
#     "probe_failures": <int>,
#     "status": "ok"
#   }
# =============================================================================

set -eu

for var in SESSION_DIR DIMS_ARRAY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Aggregate signals_total + lane status counts ─────────────────────────────
SIGNALS_TOTAL=0
LC_AUTO=0; LF_AUTO=0
for dim in $DIMS_ARRAY; do
  LANE_FILE="$LANES_ROOT/$dim/lane-status.json"
  if [ -f "$LANE_FILE" ]; then
    STATUS=$(jq -r '.status // "pending"' "$LANE_FILE")
    case "$STATUS" in
      completed|skipped) LC_AUTO=$((LC_AUTO + 1)) ;;
      failed)            LF_AUTO=$((LF_AUTO + 1)) ;;
    esac
  fi

  for stream in static-scan runtime llm-scan; do
    f="$LANES_ROOT/$dim/$stream/signals.json"
    if [ -f "$f" ]; then
      CNT=$(jq '(.signals // []) | length' "$f" 2>/dev/null || echo 0)
      SIGNALS_TOTAL=$((SIGNALS_TOTAL + CNT))
    fi
  done
done

LANES_COMPLETED="${LANES_COMPLETED:-$LC_AUTO}"
LANES_FAILED="${LANES_FAILED:-$LF_AUTO}"

# Probe failures count
PROBE_FAILURES_DEFAULT=0
if [ -f "$SESSION_DIR/phase4-find-bugs/probe-failures.log" ]; then
  PROBE_FAILURES_DEFAULT=$(wc -l < "$SESSION_DIR/phase4-find-bugs/probe-failures.log" 2>/dev/null | tr -d ' ')
  [ -z "$PROBE_FAILURES_DEFAULT" ] && PROBE_FAILURES_DEFAULT=0
fi
PROBE_FAILURES="${PROBE_FAILURES:-$PROBE_FAILURES_DEFAULT}"

# ── 4.9: Update fix-status.json (Atomic Write — CORE-035) ────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" --argjson total "$SIGNALS_TOTAL" \
    '.phases.phase4.status = "completed"
     | .phases.phase4.completed_at = $ts
     | .signals_total = $total
     | .updated_at = $ts' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail" >&2
  exit 3
fi

# ── 4.10: TRACE COMPLETE — APPEND event ──────────────────────────────────────
{
  jq -n --arg ts "$NOW" \
      --argjson lc "$LANES_COMPLETED" --argjson lf "$LANES_FAILED" \
      --argjson st "$SIGNALS_TOTAL" --argjson pf "$PROBE_FAILURES" \
      '{phase:4, event:"COMPLETE", timestamp:$ts, lanes_completed:$lc, lanes_failed:$lf, signals_total:$st, probe_failures:$pf}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
jq -n \
  --argjson st "$SIGNALS_TOTAL" \
  --argjson lc "$LANES_COMPLETED" \
  --argjson lf "$LANES_FAILED" \
  --argjson pf "$PROBE_FAILURES" \
  '{
    signals_total: $st,
    lanes_completed: $lc,
    lanes_failed: $lf,
    probe_failures: $pf,
    status: "ok"
  }'

exit 0
