#!/usr/bin/env bash
# =============================================================================
# finalize-phase6.sh — Phase 6 Step 6.9/6.10 (gộp Update fix-status + TRACE COMPLETE — v10.8)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   6.9 Update fix-status.json — mark phase6 completed + counts metadata
#   6.10 TRACE COMPLETE — APPEND COMPLETE event vào session-log.json
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   DRY_RUN              (default: false)
#   FIXED_COUNT          (default: 0)
#   DEFERRED_COUNT       (default: 0)
#   FAILED_COUNT         (default: 0)
#   FILES_CHANGED        (default: 0)
#
# Exit codes:
#   0 — Both writes pass
#   1 — Required env var missing
#   3 — Atomic write fail (E001)
#
# Output JSON (stdout):
#   {
#     "execution_mode": "live|dry_run",
#     "fixed_total": <int>, "deferred_total": <int>, "failed_total": <int>,
#     "files_changed": <int>,
#     "status": "ok"
#   }
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

DRY_RUN="${DRY_RUN:-false}"
FIXED_COUNT="${FIXED_COUNT:-0}"
DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
FAILED_COUNT="${FAILED_COUNT:-0}"
FILES_CHANGED="${FILES_CHANGED:-0}"

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EXECUTION_MODE=$([ "$DRY_RUN" = "true" ] && echo "dry_run" || echo "live")

# ── 6.9: Update fix-status.json (Atomic Write — CORE-035) ────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" --arg mode "$EXECUTION_MODE" \
      --argjson fixed "$FIXED_COUNT" --argjson deferred "$DEFERRED_COUNT" \
      --argjson failed "$FAILED_COUNT" --argjson files "$FILES_CHANGED" \
    '.phases.phase6 = {
       "status": "completed",
       "execution_mode": $mode,
       "completed_at": $ts,
       "fixed_total": $fixed,
       "deferred_total": $deferred,
       "failed_total": $failed,
       "files_changed": $files
     }
     | .updated_at = $ts' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E001)" >&2
  exit 3
fi

# ── 6.10: TRACE COMPLETE — APPEND event ──────────────────────────────────────
{
  jq -n --arg ts "$NOW" --arg mode "$EXECUTION_MODE" \
      --argjson fixed "$FIXED_COUNT" --argjson deferred "$DEFERRED_COUNT" \
      --argjson failed "$FAILED_COUNT" --argjson files "$FILES_CHANGED" \
      '{phase:"phase6", event:"COMPLETE", timestamp:$ts, execution_mode:$mode, fixed:$fixed, deferred:$deferred, failed:$failed, files_changed:$files}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Emit summary JSON ────────────────────────────────────────────────────────
jq -n --arg mode "$EXECUTION_MODE" \
      --argjson fixed "$FIXED_COUNT" --argjson deferred "$DEFERRED_COUNT" \
      --argjson failed "$FAILED_COUNT" --argjson files "$FILES_CHANGED" \
      '{execution_mode:$mode, fixed_total:$fixed, deferred_total:$deferred, failed_total:$failed, files_changed:$files, status:"ok"}'

exit 0
