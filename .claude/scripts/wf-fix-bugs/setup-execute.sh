#!/usr/bin/env bash
# =============================================================================
# setup-execute.sh — Phase 6 Step 6.1 (gộp PRE-GATE + CDG verify + TRACE START — v10.8)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   6.1 PRE-GATE — Verify Phase 5 completed + fix-plan + issue-registry + CDG tokens accepted
#   6.2 TRACE START — Mark Phase 6 in_progress + APPEND START event
#
# Required env vars:
#   SESSION_DIR, PROFILE
#
# Optional env vars:
#   DRY_RUN          (default: false — included in TRACE START event)
#
# Exit codes:
#   0 — Phase 6 in_progress (orchestrator tiếp tục Step 6.3)
#   1 — Required env var missing
#   2 — Phase 5 chưa completed (E050)
#   3 — Atomic write fail (E001)
#   5 — CDG tokens có pending/rejected (E055)
#   6 — TOTAL_ISSUES = 0 nhưng Phase 5 completed không phải E005 (E061 logic error)
#
# Output JSON (stdout):
#   {
#     "total_issues": <int>,
#     "cdg_pending": <int>,
#     "status": "ok"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR PROFILE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

DRY_RUN="${DRY_RUN:-false}"
FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"
PHASE5_DIR="$SESSION_DIR/phase5-triage"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

# ── PRE-GATE: Phase 5 phải completed ─────────────────────────────────────────
if ! jq -e '.phases.phase5.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1; then
  echo "ERROR: Phase 5 chưa completed (E050). Chạy Phase 5 trước." >&2
  exit 2
fi

# E005 healthy path: Phase 5 đã skip (e005_healthy=true) → KHÔNG run Phase 6
if jq -e '.phases.phase5.e005_healthy == true' "$FIX_STATUS" >/dev/null 2>&1; then
  echo "WARN: Phase 5 đã E005 healthy skip — Phase 6 không nên chạy. Tiếp tục Phase 7." >&2
  jq -n '{total_issues:0, cdg_pending:0, status:"e005_skip"}'
  exit 0
fi

# Verify required files exist
for f in fix-plan.md issue-registry.json cdg-tokens.json; do
  if [ ! -s "$PHASE5_DIR/$f" ]; then
    echo "ERROR: $PHASE5_DIR/$f missing or empty (E050)" >&2
    exit 2
  fi
done

# Verify issue-registry has issues
TOTAL_ISSUES=$(jq '.total_issues // (.issues | length) // 0' "$PHASE5_DIR/issue-registry.json" 2>/dev/null || echo 0)
if [ "$TOTAL_ISSUES" -eq 0 ]; then
  echo "ERROR: TOTAL_ISSUES = 0 nhưng Phase 5 completed không phải E005 (E061 logic error)" >&2
  exit 6
fi

# Verify CDG tokens all accepted — AGGREGATE từ cả 3 phase paths (v10.10.0 fix)
# _shared.md §20.1: Phase 1 (stub), Phase 4 (E090/E090b browser CDG), Phase 5 (CDG-PRE-EXECUTE)
CDG_PENDING=0
for cdg_path in \
    "$SESSION_DIR/phase1-init/cdg-tokens.json" \
    "$SESSION_DIR/phase4-find-bugs/cdg-tokens.json" \
    "$PHASE5_DIR/cdg-tokens.json"; do
  if [ -s "$cdg_path" ]; then
    pending=$(jq '[.tokens[]? | select(.status != "accepted")] | length' "$cdg_path" 2>/dev/null || echo 0)
    CDG_PENDING=$((CDG_PENDING + pending))
  fi
done
if [ "$CDG_PENDING" -gt 0 ]; then
  echo "ERROR: $CDG_PENDING CDG tokens chưa accepted across Phase 1/4/5 (E055). User phải resolve trước khi tiếp tục Phase 6." >&2
  exit 5
fi

# ── TRACE START: Phase 6 in_progress ─────────────────────────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" \
    '.phases.phase6 = {"status": "in_progress", "started_at": $ts}' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E001)" >&2
  exit 3
fi

# APPEND START event vào session-log
{
  jq -n --arg ts "$NOW" --arg prof "$PROFILE" \
      --argjson ti "$TOTAL_ISSUES" --arg dr "$DRY_RUN" \
      '{phase:"phase6", event:"START", timestamp:$ts, profile:$prof, total_issues:$ti, dry_run:$dr}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
jq -n --argjson ti "$TOTAL_ISSUES" --argjson cp "$CDG_PENDING" \
      '{total_issues:$ti, cdg_pending:$cp, status:"ok"}'

exit 0
