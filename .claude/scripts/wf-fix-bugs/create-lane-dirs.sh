#!/usr/bin/env bash
# =============================================================================
# create-lane-dirs.sh — Phase 4 Step 4.4 (Create Lane Directories — v10.6)
# =============================================================================
# Implements Step 4.4 — Tạo cấu trúc thư mục + lane-status.json cho MỖI dim
# từ template (CORE-031). Chạy SAU 4.3a Browser CDG (nếu DIMS_ARRAY đã refined
# loại browser dims bị skip).
#
# Required env vars:
#   SESSION_DIR, SESSION_ID, DIMS_ARRAY
#
# Optional env vars:
#   (none)
#
# Exit codes:
#   0 — All lane directories + lane-status.json created
#   1 — Required env var missing
#   2 — Template lane-status.json không tồn tại (CORE-031)
#   3 — mkdir/write fail
#
# Output JSON (stdout):
#   {
#     "lanes_created": <int>,
#     "status": "ok|partial|fail"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID DIMS_ARRAY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase4-find-bugs/lane-status.json"
DIM_PLAN="$SESSION_DIR/phase3-plan/dimension-plan.json"

[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }
[ -s "$DIM_PLAN" ] || { echo "ERROR: dimension-plan.json missing" >&2; exit 1; }

LANES_CREATED=0
OVERALL_EXIT=0

for dim in $DIMS_ARRAY; do
  DIM_ID="${dim%%-*}"
  LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/$dim"

  # Tạo 5 subdirectories
  if ! mkdir -p "$LANE_DIR/raw" "$LANE_DIR/evidence" \
       "$LANE_DIR/static-scan" "$LANE_DIR/runtime" "$LANE_DIR/llm-scan" 2>/dev/null; then
    echo "ERROR: mkdir fail cho $dim" >&2
    OVERALL_EXIT=3
    continue
  fi

  # Đọc dim name từ dimension-plan
  DIM_NAME=$(jq -r --arg id "$DIM_ID" \
    '.dimensions[] | select(.id == $id) | .name // ""' "$DIM_PLAN")

  # Populate lane-status.json từ template (CORE-031: READ → POPULATE → STRIP → WRITE)
  TARGET="$LANE_DIR/lane-status.json"
  TMP="$TARGET.tmp.$$"

  if jq \
      --arg dim_id "$DIM_ID" \
      --arg dim_name "$DIM_NAME" \
      --arg sid "$SESSION_ID" \
      '.dimension_id = $dim_id |
       .dimension_name = $dim_name |
       .session_id = $sid |
       .status = "pending" |
       del(._template_notes, ._schema_notes)' \
      "$TPL" > "$TMP" \
     && jq '.' "$TMP" >/dev/null \
     && mv "$TMP" "$TARGET"; then
    LANES_CREATED=$((LANES_CREATED + 1))
  else
    rm -f "$TMP"
    echo "ERROR: lane-status.json write fail cho $dim" >&2
    OVERALL_EXIT=3
  fi
done

# Emit status JSON
STATUS="ok"
TOTAL_DIMS=$(echo "$DIMS_ARRAY" | wc -w | tr -d ' ')
if [ "$LANES_CREATED" -eq 0 ]; then
  STATUS="fail"
elif [ "$LANES_CREATED" -lt "$TOTAL_DIMS" ]; then
  STATUS="partial"
fi

jq -n \
  --argjson lc "$LANES_CREATED" \
  --argjson tt "$TOTAL_DIMS" \
  --arg st "$STATUS" \
  '{lanes_created: $lc, total_dims: $tt, status: $st}'

exit "$OVERALL_EXIT"
