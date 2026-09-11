#!/usr/bin/env bash
# =============================================================================
# finalize-phase7.sh — Phase 7 Step 7.10/7.11 (gộp Pipeline DONE + TRACE COMPLETE — v10.9)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   7.10 Update fix-status: phase7=completed + pipeline_status=DONE
#   7.11 TRACE COMPLETE: APPEND COMPLETE event vào session-log + global trace dual-write
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars:
#   E005_HEALTHY        (default: false)
#   TOTAL_ISSUES, FIXED_COUNT, DEFERRED_COUNT, FAILED_COUNT (default: 0)
#   REPO_ROOT           (default: $(pwd))
#
# Exit codes:
#   0 — Both writes pass
#   1 — Required env var missing
#   3 — Atomic write fail (E075)
#
# Output JSON (stdout):
#   {
#     "pipeline_status": "DONE",
#     "phase7_completed": <bool>,
#     "trace_dual_write": <bool>,
#     "status": "ok"
#   }
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

E005_HEALTHY="${E005_HEALTHY:-false}"
TOTAL_ISSUES="${TOTAL_ISSUES:-0}"
FIXED_COUNT="${FIXED_COUNT:-0}"
DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
FAILED_COUNT="${FAILED_COUNT:-0}"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
GLOBAL_TRACE="$REPO_ROOT/.mc-data/work/_trace/session-log.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

# ── v11: PRESERVE pipeline_status enum đã set ở generate-phase7-reports.sh ──
# generate-phase7-reports.sh pre-finalize block đã decide enum value
# (DONE_CLEAN / DONE_WITH_DEFERRED / DONE_NEEDS_FOLLOWUP).
# finalize-phase7.sh chỉ confirm phase7=completed + updated_at, KHÔNG overwrite enum.
PRESERVED_PS=$(jq -r '.pipeline_status // "DONE"' "$FIX_STATUS" 2>/dev/null || echo "DONE")
PIPELINE_STATUS_FINAL="$PRESERVED_PS"

# ── 7.10: Update fix-status (preserve pipeline_status — Atomic Write CORE-035) ─
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" \
    '.phases.phase7.status = "completed"
     | .phases.phase7.completed_at = $ts
     | .updated_at = $ts' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E075)" >&2
  exit 3
fi

echo "INFO(v11): pipeline_status preserved = $PIPELINE_STATUS_FINAL" >&2

# ── 7.11: TRACE COMPLETE — Session log ───────────────────────────────────────
{
  jq -n --arg ts "$NOW" --argjson e005 "$E005_HEALTHY" \
      --argjson ti "$TOTAL_ISSUES" --argjson fc "$FIXED_COUNT" \
      --argjson dc "$DEFERRED_COUNT" --argjson fl "$FAILED_COUNT" \
      '{phase:7, event:"COMPLETE", timestamp:$ts, e005_healthy:$e005, total_issues:$ti, fixed:$fc, deferred:$dc, failed:$fl}'
} >> "$SESSION_LOG" 2>/dev/null || true

# Global trace dual-write (CORE-026) — v11: dùng pipeline_status enum mới
TRACE_DUAL_WRITE=false
mkdir -p "$(dirname "$GLOBAL_TRACE")" 2>/dev/null
if {
  jq -n --arg sid "$SESSION_ID" --arg ts "$NOW" --arg ps "$PIPELINE_STATUS_FINAL" \
      '{session_id:$sid, phase:7, event:"COMPLETE", timestamp:$ts, pipeline_status:$ps}'
} >> "$GLOBAL_TRACE" 2>/dev/null; then
  TRACE_DUAL_WRITE=true
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
# v11: pipeline_status enum thay vì hardcode "DONE"
jq -n --argjson dw "$TRACE_DUAL_WRITE" --arg ps "$PIPELINE_STATUS_FINAL" \
      '{pipeline_status:$ps, phase7_completed:true, trace_dual_write:$dw, status:"ok"}'

exit 0
