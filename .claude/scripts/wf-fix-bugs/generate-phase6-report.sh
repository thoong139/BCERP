#!/usr/bin/env bash
# =============================================================================
# generate-phase6-report.sh — Phase 6 Step 6.8 (CORE-028 Phase Report — v10.8)
# =============================================================================
# Implements Step 6.8 — Populate Phase6-report.md template từ aggregated data
# (fix-report.md, docs-sync-report.json, fix-status.json).
#
# Pattern (CORE-031): READ template → POPULATE → STRIP metadata → Atomic Write.
# Tiếng Việt (CORE-028) ≤15 dòng.
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars:
#   STATUS_PASS_FAIL        (default: PASS)
#   STARTED_AT, COMPLETED_AT (default: $NOW)
#   DRY_RUN                 (default: false → "live")
#   FIXED_COUNT, DEFERRED_COUNT, FAILED_COUNT, FILES_CHANGED (default: 0)
#   CI_IMPACT_DONE          (default: "có" nếu ci-impact-report.json tồn tại, "không" nếu không)
#
# Exit codes:
#   0 — Phase6-report.md written
#   1 — Required env var missing
#   2 — Template missing (E035)
#   3 — Atomic write fail
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/Phase6-report.md"
TARGET="$SESSION_DIR/phase6-execute/Phase6-report.md"
DOCS_SYNC="$SESSION_DIR/phase6-execute/docs-sync-report.json"
FIX_REPORT="$SESSION_DIR/phase6-execute/fix-report.md"
CI_IMPACT="$SESSION_DIR/phase6-execute/ci-impact-report.json"

[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }

mkdir -p "$(dirname "$TARGET")"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATUS_PASS_FAIL="${STATUS_PASS_FAIL:-PASS}"
STARTED_AT="${STARTED_AT:-$NOW}"
COMPLETED_AT="${COMPLETED_AT:-$NOW}"
DRY_RUN="${DRY_RUN:-false}"
DRY_RUN_OR_LIVE=$([ "$DRY_RUN" = "true" ] && echo "dry-run" || echo "live")

FIXED_COUNT="${FIXED_COUNT:-0}"
DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
FAILED_COUNT="${FAILED_COUNT:-0}"
FILES_CHANGED="${FILES_CHANGED:-0}"

# CI Impact
if [ -z "${CI_IMPACT_DONE:-}" ]; then
  CI_IMPACT_DONE=$([ -s "$CI_IMPACT" ] && echo "có" || echo "không")
fi

# Docs synced
DOCS_SYNCED=0
if [ -s "$DOCS_SYNC" ]; then
  DOCS_SYNCED=$(jq '(.files_synced // 0)' "$DOCS_SYNC" 2>/dev/null || echo 0)
fi

# Validation flags for sub-skill outputs
FIX_REPORT_VALID=$([ -s "$FIX_REPORT" ] && echo "✓" || echo "✗")
DOCS_SYNC_VALID="✗"
if [ -s "$DOCS_SYNC" ] && jq '.' "$DOCS_SYNC" >/dev/null 2>&1; then
  DOCS_SYNC_VALID="✓"
fi

# v11 (W2-T7): Fix Iteration Loop summary
FIX_ITER_FILE="$SESSION_DIR/phase6-execute/fix-iterations.json"
LOOP_SUMMARY="(không có loop — single-pass)"
if [ -s "$FIX_ITER_FILE" ]; then
  ITER_COUNT=$(jq -r '.current_iteration // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  MAX_ITER=$(jq -r '.max_iterations // 3' "$FIX_ITER_FILE" 2>/dev/null || echo 3)
  FINAL_DEC=$(jq -r '.final_decision // "in_progress"' "$FIX_ITER_FILE" 2>/dev/null || echo "in_progress")
  INIT_FIXED=$(jq -r '.summary.initial_actually_fixed // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  FINAL_FIXED=$(jq -r '.summary.final_fixed_total // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  NET_IMPROVE=$(jq -r '.summary.net_improvement // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  INIT_UNSANCT=$(jq -r '.summary.initial_unsanctioned // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  REMAIN_UNSANCT=$(jq -r '.summary.final_unsanctioned_remaining // 0' "$FIX_ITER_FILE" 2>/dev/null || echo 0)
  LOOP_SUMMARY="Iterations: $ITER_COUNT/$MAX_ITER, decision=$FINAL_DEC. Initial fixed=$INIT_FIXED (unsanctioned=$INIT_UNSANCT) → Final fixed=$FINAL_FIXED (net +$NET_IMPROVE, remaining unsanctioned=$REMAIN_UNSANCT)"
fi

# Populate via sed → atomic write
TMP="$TARGET.tmp.$$"
if sed \
    -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS_FAIL|g" \
    -e "s|\[STARTED_AT\]|$STARTED_AT|g" \
    -e "s|\[COMPLETED_AT\]|$COMPLETED_AT|g" \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[DRY_RUN_OR_LIVE\]|$DRY_RUN_OR_LIVE|g" \
    -e "s|\[CI_IMPACT_DONE\]|$CI_IMPACT_DONE|g" \
    -e "s|\[FIXED\]|$FIXED_COUNT|g" \
    -e "s|\[DEFERRED\]|$DEFERRED_COUNT|g" \
    -e "s|\[FAILED\]|$FAILED_COUNT|g" \
    -e "s|\[FILES_CHANGED\]|$FILES_CHANGED|g" \
    -e "s|\[DOCS_SYNCED\]|$DOCS_SYNCED|g" \
    -e "s|\[FIX_REPORT_VALID\]|$FIX_REPORT_VALID|g" \
    -e "s|\[DOCS_SYNC_VALID\]|$DOCS_SYNC_VALID|g" \
    -e "s|\[LOOP_SUMMARY\]|$LOOP_SUMMARY|g" \
    -e '/_template_notes/d' -e '/_schema_notes/d' \
    "$TPL" > "$TMP" \
   && [ -s "$TMP" ]; then
  mv "$TMP" "$TARGET"
  echo "ok"
  exit 0
else
  rm -f "$TMP"
  echo "ERROR: Phase6-report.md generation fail" >&2
  exit 3
fi
