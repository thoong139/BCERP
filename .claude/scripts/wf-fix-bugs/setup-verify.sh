#!/usr/bin/env bash
# =============================================================================
# setup-verify.sh — Phase 7 Step 7.1 (gộp PRE-GATE + E005 detect + TRACE START — v10.9)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   7.1 PRE-GATE — Verify Phase 5/6 completed + Forensic content check
#   7.2 TRACE START — Mark Phase 7 in_progress + APPEND START event
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   (none — auto-detect E005 từ fix-status.phase5.e005_healthy)
#
# Exit codes:
#   0 — Phase 7 in_progress (orchestrator tiếp tục Step 7.3 hoặc 7.5 nếu E005)
#   1 — Required env var missing
#   2 — Phase 5/6 chưa completed (E001)
#   3 — Atomic write fail (E075)
#   4 — Inconsistent state (E005 flag set nhưng Phase 5 chưa completed) (E001)
#   6 — Required input files missing (E060 — fix-report or issue-registry)
#
# Output JSON (stdout):
#   {
#     "e005_healthy": <bool>,
#     "route": "normal|e005_skip",
#     "phase6_completed": <bool>,
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
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

# ── PRE-GATE: Phase 5 phải completed ─────────────────────────────────────────
if ! jq -e '.phases.phase5.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1; then
  echo "ERROR: Phase 5 chưa completed (E001). Phase 7 cần Phase 5 hoặc 6 hoàn thành." >&2
  exit 2
fi

# ── E005 detection ───────────────────────────────────────────────────────────
E005_HEALTHY=false
if jq -e '.phases.phase5.e005_healthy == true' "$FIX_STATUS" >/dev/null 2>&1; then
  E005_HEALTHY=true
fi

PHASE6_COMPLETED=false
if jq -e '.phases.phase6.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1; then
  PHASE6_COMPLETED=true
fi

# ── Forensic content check (CORE-011) ────────────────────────────────────────
if [ "$E005_HEALTHY" = "true" ]; then
  # E005 path: verify Phase5-report.md tồn tại
  if [ ! -s "$SESSION_DIR/phase5-triage/Phase5-report.md" ]; then
    echo "ERROR: E005=true nhưng Phase5-report.md không tồn tại (E001 inconsistent state)" >&2
    exit 4
  fi
else
  # Normal path: Phase 6 phải completed + fix-report + issue-registry
  if [ "$PHASE6_COMPLETED" != "true" ]; then
    echo "ERROR: E005=false nhưng Phase 6 chưa completed (E060)" >&2
    exit 6
  fi
  if [ ! -s "$SESSION_DIR/phase6-execute/fix-report.md" ]; then
    echo "ERROR: fix-report.md missing (E060)" >&2
    exit 6
  fi
  if [ ! -s "$SESSION_DIR/phase5-triage/issue-registry.json" ]; then
    echo "ERROR: issue-registry.json missing (E060)" >&2
    exit 6
  fi
fi

# ── Create phase7-verify directory ───────────────────────────────────────────
mkdir -p "$SESSION_DIR/phase7-verify"

# ── TRACE START: Phase 7 in_progress ─────────────────────────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" --argjson e005 "$E005_HEALTHY" \
    '.phases.phase7 = {"status": "in_progress", "started_at": $ts, "e005_healthy": $e005}' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E075)" >&2
  exit 3
fi

# APPEND START event
{
  jq -n --arg ts "$NOW" --argjson e005 "$E005_HEALTHY" \
      '{phase:7, event:"START", timestamp:$ts, e005_healthy:$e005}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Determine route ──────────────────────────────────────────────────────────
ROUTE=$([ "$E005_HEALTHY" = "true" ] && echo "e005_skip" || echo "normal")

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
jq -n --argjson e005 "$E005_HEALTHY" --arg route "$ROUTE" \
      --argjson p6 "$PHASE6_COMPLETED" \
      '{e005_healthy:$e005, route:$route, phase6_completed:$p6, status:"ok"}'

exit 0
