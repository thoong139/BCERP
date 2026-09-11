#!/usr/bin/env bash
# =============================================================================
# dry-run-preview.sh — Phase 6 Step 6.3 (Dry-Run Preview — v10.8)
# =============================================================================
# Nếu DRY_RUN=true: render fix-report.md preview + atomic update fix-status
# (phase6.status="completed", reason="dry_run") → orchestrator STOP pipeline.
# Nếu DRY_RUN=false: NO-OP, exit 0 → orchestrator tiếp tục Step 6.4.
#
# Required env vars:
#   SESSION_DIR, PROFILE
#
# Optional env vars:
#   DRY_RUN          (default: false)
#   TOTAL_ISSUES     (default: read từ issue-registry.json)
#
# Exit codes:
#   0 — Live mode (DRY_RUN=false) → orchestrator tiếp tục
#   1 — Required env var missing
#   3 — Atomic write fail (E001)
#   5 — Dry-run preview hoàn tất → orchestrator STOP pipeline (E_DRY_RUN_DONE)
#
# Output JSON (stdout):
#   {
#     "dry_run": <bool>,
#     "preview_path": "<path>|null",
#     "estimated_files": <int>,
#     "estimated_time_min": <int>,
#     "status": "live|dry_run_done"
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

# Live mode: NO-OP
if [ "$DRY_RUN" != "true" ]; then
  jq -n '{dry_run:false, preview_path:null, estimated_files:0, estimated_time_min:0, status:"live"}'
  exit 0
fi

# Dry-run mode: generate preview
FIX_STATUS="$SESSION_DIR/fix-status.json"
PHASE5_DIR="$SESSION_DIR/phase5-triage"
PHASE6_DIR="$SESSION_DIR/phase6-execute"
PREVIEW="$PHASE6_DIR/fix-report.md"
FIX_PLAN="$PHASE5_DIR/fix-plan.md"
REGISTRY="$PHASE5_DIR/issue-registry.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$PHASE6_DIR"

# Default TOTAL_ISSUES từ registry nếu env không set
if [ -z "${TOTAL_ISSUES:-}" ]; then
  TOTAL_ISSUES=$(jq '.total_issues // (.issues | length) // 0' "$REGISTRY" 2>/dev/null || echo 0)
fi

# Đếm estimated files từ fix-plan
ESTIMATED_FILES=$(grep -oP '(src|apps|packages)/[^[:space:]]+' "$FIX_PLAN" 2>/dev/null | sort -u | wc -l | tr -d ' ')
ESTIMATED_FILES=${ESTIMATED_FILES:-0}
ESTIMATED_TIME_MIN_MIN=$ESTIMATED_FILES
ESTIMATED_TIME_MIN_MAX=$((ESTIMATED_FILES * 3))

# Render preview
{
  echo "## 🔍 DRY RUN — Fix Plan Preview"
  echo ""
  echo "**Generated:** $NOW"
  echo "**Profile:** $PROFILE | **Issues:** $TOTAL_ISSUES | **Mode:** dry-run"
  echo ""
  echo "### Issues to Fix"
  echo ""
  grep -E "^\|" "$FIX_PLAN" 2>/dev/null | head -20 || echo "_(Không parse được bảng issues — xem fix-plan.md trực tiếp)_"
  echo ""
  echo "### Estimated Impact"
  echo ""
  echo "- **Files estimated:** $ESTIMATED_FILES"
  echo "- **Issues in scope:** $TOTAL_ISSUES"
  echo "- **Estimated time:** ~${ESTIMATED_TIME_MIN_MIN}-${ESTIMATED_TIME_MIN_MAX} phút"
  echo ""
  echo "### Next Steps"
  echo ""
  echo "Chạy lại lệnh không có \`--dry-run\` để thực thi fix thật."
  echo ""
  echo "> Đây là chế độ preview — KHÔNG có file nào được sửa."
} > "$PREVIEW"

# Atomic update fix-status (phase6 completed dry-run)
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" \
    '.phases.phase6 = {"status": "completed", "reason": "dry_run", "execution_mode": "dry_run", "completed_at": $ts}' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail (E001)" >&2
  exit 3
fi

# Emit JSON
jq -n --arg p "$PREVIEW" --argjson ef "$ESTIMATED_FILES" --argjson et "$ESTIMATED_TIME_MIN_MAX" \
      '{dry_run:true, preview_path:$p, estimated_files:$ef, estimated_time_min:$et, status:"dry_run_done"}'

exit 5
