#!/usr/bin/env bash
# =============================================================================
# finalize-phase5.sh — Phase 5 Step 5.14 (gộp Update fix-status + TRACE COMPLETE — v10.7)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   5.14 Update fix-status.json — mark phase5 completed + issues_total + signals_total
#   5.15 TRACE COMPLETE — APPEND COMPLETE event vào session-log.json
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars (orchestrator có thể override):
#   ISSUES_TOTAL          (default: read từ issue-registry.json)
#   SIGNALS_TOTAL         (default: read từ fix-status.signals_total)
#   CDG_DECISION          (default: read từ cdg-tokens.json tokens[-1].decision)
#   SAFETY_BLOCKERS       (default: read từ safety-check.json blockers length)
#
# Exit codes:
#   0 — Both writes pass
#   1 — Required env var missing
#   3 — Atomic write fail (E035)
#
# Output JSON (stdout):
#   {
#     "issues_total": <int>,
#     "signals_total": <int>,
#     "cdg_decision": "ACCEPT|REJECT|PENDING",
#     "safety_blockers": <int>,
#     "status": "ok"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
SAFETY="$SESSION_DIR/phase5-triage/safety-check.json"
CDG_TOKENS="$SESSION_DIR/phase5-triage/cdg-tokens.json"

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Read defaults nếu env vars không set ─────────────────────────────────────
if [ -z "${ISSUES_TOTAL:-}" ]; then
  ISSUES_TOTAL=$(jq '.total_issues // 0' "$REGISTRY" 2>/dev/null || echo 0)
fi
if [ -z "${SIGNALS_TOTAL:-}" ]; then
  SIGNALS_TOTAL=$(jq '.signals_total // 0' "$FIX_STATUS" 2>/dev/null || echo 0)
fi
if [ -z "${CDG_DECISION:-}" ]; then
  CDG_DECISION=$(jq -r '.tokens[-1].decision // "PENDING"' "$CDG_TOKENS" 2>/dev/null || echo "PENDING")
fi
if [ -z "${SAFETY_BLOCKERS:-}" ]; then
  SAFETY_BLOCKERS=$(jq '(.blockers // []) | length' "$SAFETY" 2>/dev/null || echo 0)
fi

# ── 5.14: Update fix-status.json (Atomic Write — CORE-035) ───────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" --argjson it "$ISSUES_TOTAL" --argjson st "$SIGNALS_TOTAL" \
    '.phases.phase5.status = "completed"
     | .phases.phase5.completed_at = $ts
     | .issues_total = $it
     | .signals_total = $st
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

# ── 5.15: TRACE COMPLETE — APPEND event ──────────────────────────────────────
{
  jq -n --arg ts "$NOW" \
      --argjson it "$ISSUES_TOTAL" --argjson st "$SIGNALS_TOTAL" \
      --arg cdg "$CDG_DECISION" --argjson sb "$SAFETY_BLOCKERS" \
      '{phase:5, event:"COMPLETE", timestamp:$ts, issues_total:$it, signals_total:$st, cdg_decision:$cdg, safety_blockers:$sb}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Emit summary JSON ────────────────────────────────────────────────────────
jq -n \
  --argjson it "$ISSUES_TOTAL" \
  --argjson st "$SIGNALS_TOTAL" \
  --arg cdg "$CDG_DECISION" \
  --argjson sb "$SAFETY_BLOCKERS" \
  '{
    issues_total: $it,
    signals_total: $st,
    cdg_decision: $cdg,
    safety_blockers: $sb,
    status: "ok"
  }'

exit 0
