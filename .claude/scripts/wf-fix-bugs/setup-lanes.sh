#!/usr/bin/env bash
# =============================================================================
# setup-lanes.sh — Phase 4 Step 4.2 (gộp TRACE START + Load PW Metadata — v10.6)
# =============================================================================
# Gộp 2 logical sub-steps thành 1 atomic call:
#   4.2 TRACE START — Mark Phase 4 in_progress (atomic update fix-status.json)
#   4.3 Load Per-Dim Playwright Metadata — đọc needs_playwright từ dimension-plan.json
#
# Required env vars:
#   SESSION_DIR, PROFILE, SCOPE
#
# Optional env vars:
#   (none — script tự load context từ $SESSION_DIR)
#
# Exit codes:
#   0 — TRACE START written + PW metadata loaded
#   1 — Required env var missing
#   2 — dimension-plan.json missing hoặc dim thiếu needs_playwright field (E030)
#   3 — Atomic write fail
#
# Output JSON (stdout):
#   {
#     "dims_array": "QD1-functional QD2-business ... QD9-runtime-health",
#     "dims_count": <int>,
#     "pw_lane_count": <int>,
#     "pw_dims": "QD5-ux-a11y QD9-runtime-health",
#     "status": "ok"
#   }
#
# Orchestrator usage:
#   PHASE4_S1=$(bash .claude/scripts/wf-fix-bugs/setup-lanes.sh)
#   DIMS_ARRAY=$(echo "$PHASE4_S1" | jq -r '.dims_array')
#   PW_LANE_COUNT=$(echo "$PHASE4_S1" | jq -r '.pw_lane_count')
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

# ── Validate required env vars ───────────────────────────────────────────────
for var in SESSION_DIR PROFILE SCOPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

DIM_PLAN="$SESSION_DIR/phase3-plan/dimension-plan.json"
FIX_STATUS="$SESSION_DIR/fix-status.json"
SESSION_LOG="$SESSION_DIR/session-log.json"

[ -s "$DIM_PLAN" ] || { echo "ERROR: dimension-plan.json missing (E030)" >&2; exit 2; }
[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─────────────────────────────────────────────────────────────────────────────
# 4.2 — TRACE START (Atomic Write Pattern — CORE-035)
# ─────────────────────────────────────────────────────────────────────────────
TMP="$FIX_STATUS.tmp.$$"
if jq --arg ts "$NOW" \
    '.phases.phase4 = {"status": "in_progress", "started_at": $ts}' \
    "$FIX_STATUS" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$FIX_STATUS"; then
  :
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fix-status.json fail" >&2
  exit 3
fi

# Append START event vào session-log.json (CORE-026)
DIMS_COUNT_RAW=$(jq -r '.dimensions | length' "$DIM_PLAN")
{
  jq -n --arg ts "$NOW" --argjson dc "$DIMS_COUNT_RAW" \
      --arg profile "$PROFILE" --arg scope "$SCOPE" \
      '{phase:"phase4", event:"START", timestamp:$ts, dimensions_count:$dc, profile:$profile, scope:$scope}'
} >> "$SESSION_LOG" 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# 4.3 — LOAD PER-DIM PLAYWRIGHT METADATA
# ─────────────────────────────────────────────────────────────────────────────
# Build DIMS_ARRAY: lấy thẳng từ field .output_dir đã được route-and-write.sh ghi.
# Canonical convention (SSOT, route-and-write.sh:175): "QD{N}-{lane_skill minus wf-fix-}".
# VD: lane_skill="wf-fix-data" → output_dir="lanes/QD6-data" → DIMS_ARRAY phần tử = "QD6-data".
# tr -d '\r' DEFENSIVE: chống CRLF từ jq output khiến mkdir tạo folder có \r ở cuối.
DIMS_ARRAY=$(jq -r '.dimensions[] | .output_dir | sub("^lanes/"; "")' "$DIM_PLAN" \
  | tr -d '\r' | tr "\n" " " | sed 's/ $//')

# Defensive: fallback nếu .output_dir thiếu (legacy plan format) → derive từ lane_skill
if [ -z "$DIMS_ARRAY" ]; then
  echo "WARN: .output_dir thiếu trong dimension-plan.json — fallback derive từ lane_skill" >&2
  DIMS_ARRAY=$(jq -r '
    .dimensions[]
    | .id + "-" + (.lane_skill | sub("^wf-fix-"; ""))
  ' "$DIM_PLAN" | tr -d '\r' | tr "\n" " " | sed 's/ $//')
fi

DIMS_COUNT=$(echo "$DIMS_ARRAY" | wc -w | tr -d ' ')

# Verify mọi dim trong DIMS_ARRAY có field needs_playwright
PW_LANE_COUNT=0
PW_DIMS=""
for dim in $DIMS_ARRAY; do
  DIM_ID="${dim%%-*}"
  if ! jq -e --arg id "$DIM_ID" '.dimensions[] | select((.id | split("-")[0]) == $id) | has("needs_playwright")' \
       "$DIM_PLAN" >/dev/null 2>&1; then
    echo "ERROR: dimension $DIM_ID thiếu field needs_playwright (Phase 3 chưa migrate v10.3+) — E030" >&2
    exit 2
  fi

  NEEDS_PW=$(jq -r --arg id "$DIM_ID" \
    '.dimensions[] | select((.id | split("-")[0]) == $id) | .needs_playwright // false' "$DIM_PLAN")

  if [ "$NEEDS_PW" = "true" ]; then
    PW_LANE_COUNT=$((PW_LANE_COUNT + 1))
    PW_DIMS="$PW_DIMS $dim"
  fi
done
PW_DIMS=$(echo "$PW_DIMS" | sed 's/^ //;s/ $//')

# Verify lock script tồn tại nếu có PW lane
if [ "$PW_LANE_COUNT" -gt 0 ]; then
  if [ ! -f .claude/scripts/wf-e2e-shared/global-rw-lock.sh ]; then
    echo "ERROR: global-rw-lock.sh không tồn tại — Playwright lane sẽ fail acquire lock (E044)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Emit aggregated JSON to stdout
# ─────────────────────────────────────────────────────────────────────────────
jq -n \
  --arg da "$DIMS_ARRAY" \
  --argjson dc "$DIMS_COUNT" \
  --argjson pc "$PW_LANE_COUNT" \
  --arg pd "$PW_DIMS" \
  '{
    dims_array: $da,
    dims_count: $dc,
    pw_lane_count: $pc,
    pw_dims: $pd,
    status: "ok"
  }'

exit 0
