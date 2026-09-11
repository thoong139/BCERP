#!/usr/bin/env bash
# =============================================================================
# plan-isg-partition.sh — Phase 3 Step 3.3 (gộp ISG Recommender + Partition Planner — v10.5)
# =============================================================================
# Gộp 2 Python CLI calls thành 1 atomic script:
#   3.3 ISG Recommender — refine dimensions theo profile + interface_type
#   3.4 Partition Planner — chia dims thành workloads
#
# Output (qua atomic write):
#   $SESSION_DIR/phase3-plan/isg-result.json
#   $SESSION_DIR/phase3-plan/workloads/W{N}/fix-workload.json (1+ files)
#
# Required env vars (set bởi orchestrator trước khi call):
#   SESSION_DIR, DIMS_ARRAY, PROFILE, INTERFACE_TYPE
#
# Optional env vars:
#   (none — script tự load context từ $SESSION_DIR)
#
# Exit codes:
#   0 — Output JSON emitted (success hoặc fallback)
#   1 — Required env var missing
#
# Output JSON (stdout):
#   {
#     "refined_dims": "QD1,QD2,...",
#     "refined_profile": "quick|standard|deep|exhaustive",
#     "dim_count": <int>,
#     "workload_count": <int>,
#     "total_estimated": <int>,
#     "isg_status": "ok|fallback",
#     "partition_status": "ok|fallback"
#   }
#
# Orchestrator usage:
#   PHASE3_S1=$(bash .claude/scripts/wf-fix-bugs/plan-isg-partition.sh)
#   REFINED_DIMS=$(echo "$PHASE3_S1" | jq -r '.refined_dims')
#   WORKLOAD_COUNT=$(echo "$PHASE3_S1" | jq -r '.workload_count')
#
# v10.10.0 fix: CLI signatures đã align đúng với argparse:
#   - `python -m isg analyze` → `python -m isg emit` (2-step chain)
#   - `python -m partition --items-file --group-key` (prepare items JSON trước)
# Pipeline giờ ưu tiên CLI thật, chỉ fallback khi CLI fail (vd: Python missing).
#
# Compatibility: Git Bash + WSL. Pure bash + jq + python (optional).
# =============================================================================

set -eu

# ── Validate required env vars ───────────────────────────────────────────────
for var in SESSION_DIR DIMS_ARRAY PROFILE INTERFACE_TYPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

OUT_DIR="$SESSION_DIR/phase3-plan"
mkdir -p "$OUT_DIR/workloads"

# ─────────────────────────────────────────────────────────────────────────────
# 3.3 — ISG RECOMMENDER (refine dimensions)
# ─────────────────────────────────────────────────────────────────────────────
ISG_OUT="$OUT_DIR/isg-result.json"
ISG_ANALYZE_OUT="$OUT_DIR/isg-analyze.json"
ISG_STATUS="fallback"

# v10.10.0 fix: dùng đúng CLI signature `isg analyze` (subcommand) → JSON stdout
# capture; sau đó `isg emit` produce dim-selection.json. Trước v10.10.0 dùng
# flat args không khớp argparse → luôn fallback E030.
# Step 1: `analyze` produce recommendations
if python -m isg analyze \
    --session-dir="$SESSION_DIR" \
    --profile="$PROFILE" \
    --scope="${SCOPE:-all}" \
    > "$ISG_ANALYZE_OUT" 2>/dev/null && [ -s "$ISG_ANALYZE_OUT" ]; then
  # Step 2: extract recommended dims từ analyze output → emit dim-selection
  REC_DIMS=$(jq -r '[.recommendations[]? | select(.strength == "strong" or .strength == "medium") | .dim] | join(",")' "$ISG_ANALYZE_OUT" 2>/dev/null)
  if [ -n "$REC_DIMS" ]; then
    if python -m isg emit \
        --selected="$REC_DIMS" \
        --profile="$PROFILE" \
        --scope-type="${SCOPE:-all}" \
        --session-dir="$SESSION_DIR" \
        --output="$ISG_OUT" >/dev/null 2>&1 && [ -s "$ISG_OUT" ]; then
      ISG_STATUS="ok"
    fi
  fi
fi

if [ "$ISG_STATUS" = "fallback" ]; then
  # E030 fallback — dùng DIMS_ARRAY hiện tại + profile passed
  jq -n --arg dims "$DIMS_ARRAY" --arg profile "$PROFILE" \
    '{dimensions: $dims, profile: $profile, fallback: true}' \
    > "$ISG_OUT"
fi

# Extract dimensions từ output — emit format khác analyze, fallback chuẩn
REFINED_DIMS=$(jq -r '
  if .selected then (.selected | join(","))
  elif .dimensions then (if (.dimensions | type) == "array" then (.dimensions | join(",")) else .dimensions end)
  else "" end' "$ISG_OUT" 2>/dev/null)
REFINED_PROFILE=$(jq -r '.profile // "standard"' "$ISG_OUT")
[ -z "$REFINED_DIMS" ] && REFINED_DIMS="$DIMS_ARRAY"
DIM_COUNT=$(echo "$REFINED_DIMS" | tr ',' ' ' | wc -w | tr -d ' ')

# ─────────────────────────────────────────────────────────────────────────────
# 3.4 — PARTITION PLANNER (workloads)
# ─────────────────────────────────────────────────────────────────────────────
PARTITION_STATUS="fallback"

# v10.10.0 fix: prepare items JSON theo signature `partition --items-file --group-key`.
# Convert REFINED_DIMS (comma-separated) → items array với group_key=dim.
ITEMS_FILE="$OUT_DIR/.partition-items.json"
echo "$REFINED_DIMS" | tr ',' '\n' | grep -v '^$' | \
  jq -R -s 'split("\n") | map(select(length>0)) | map({dim: ., scope: "lane"})' \
  > "$ITEMS_FILE" 2>/dev/null

# Estimate minutes per dim theo profile
case "$REFINED_PROFILE" in
  quick) EST_MIN="1.5"; MAX_PER="3" ;;
  standard) EST_MIN="3.0"; MAX_PER="5" ;;
  deep) EST_MIN="5.0"; MAX_PER="7" ;;
  exhaustive) EST_MIN="8.0"; MAX_PER="10" ;;
  *) EST_MIN="3.0"; MAX_PER="5" ;;
esac

PARTITION_OUT="$OUT_DIR/.partition-result.json"
if [ -s "$ITEMS_FILE" ] && python -m partition \
    --items-file="$ITEMS_FILE" \
    --group-key="dim" \
    --max-per-partition="$MAX_PER" \
    --est-minutes="$EST_MIN" \
    > "$PARTITION_OUT" 2>/dev/null && [ -s "$PARTITION_OUT" ]; then
  # Convert partition result → W{N}/fix-workload.json files
  PART_COUNT=$(jq -r '.partition_count // 0' "$PARTITION_OUT")
  if [ "${PART_COUNT:-0}" -gt 0 ]; then
    for i in $(seq 1 "$PART_COUNT"); do
      idx=$((i - 1))
      WDIR="$OUT_DIR/workloads/W${i}"
      mkdir -p "$WDIR"
      jq --arg wid "W${i}" --arg profile "$REFINED_PROFILE" \
         --argjson idx "$idx" \
         '{
           "$schema": "fix-workload-v1",
           workload_id: $wid,
           dimensions: (.partitions[$idx].group_key // ""),
           estimated_issues: (.partitions[$idx].items_count // 0),
           estimated_time_minutes: (.partitions[$idx].estimated_minutes // 0),
           profile: $profile
         }' "$PARTITION_OUT" > "$WDIR/fix-workload.json"
    done
    PARTITION_STATUS="ok"
  fi
fi
rm -f "$ITEMS_FILE" "$PARTITION_OUT" 2>/dev/null

if [ "$PARTITION_STATUS" = "fallback" ]; then
  # E032 fallback — auto-generate 1-workload chứa tất cả dimensions
  mkdir -p "$OUT_DIR/workloads/W1"
  # Ước lượng issues từ scope-analysis.json (1 issue / 10 files)
  SCOPE_JSON="$SESSION_DIR/phase2-scan/scope-analysis.json"
  if [ -s "$SCOPE_JSON" ]; then
    TOTAL_FILES=$(jq -r '.code.total_files // 100' "$SCOPE_JSON")
    ESTIMATED_ISSUES=$(( (TOTAL_FILES + 9) / 10 ))  # ceil(total_files/10)
  else
    ESTIMATED_ISSUES=10
  fi
  [ "$ESTIMATED_ISSUES" -lt 1 ] && ESTIMATED_ISSUES=1

  jq -n \
    --arg dims "$REFINED_DIMS" \
    --argjson est "$ESTIMATED_ISSUES" \
    --arg profile "$REFINED_PROFILE" \
    '{
      "$schema": "fix-workload-v1",
      workload_id: "W1",
      dimensions: $dims,
      estimated_issues: $est,
      estimated_time_minutes: ($est * 2),
      profile: $profile,
      fallback: true
    }' > "$OUT_DIR/workloads/W1/fix-workload.json"
fi

WORKLOAD_COUNT=$(ls -d "$OUT_DIR/workloads/"W*/ 2>/dev/null | wc -l | tr -d ' ')

# Tính TOTAL_ESTIMATED từ tất cả workloads
TOTAL_ESTIMATED=0
for w in "$OUT_DIR/workloads/"W*/fix-workload.json; do
  [ -s "$w" ] || continue
  EST=$(jq -r '.estimated_issues // 0' "$w")
  TOTAL_ESTIMATED=$((TOTAL_ESTIMATED + EST))
done

# ─────────────────────────────────────────────────────────────────────────────
# Emit aggregated JSON to stdout
# ─────────────────────────────────────────────────────────────────────────────
jq -n \
  --arg rd "$REFINED_DIMS" \
  --arg rp "$REFINED_PROFILE" \
  --argjson dc "$DIM_COUNT" \
  --argjson wc "$WORKLOAD_COUNT" \
  --argjson te "$TOTAL_ESTIMATED" \
  --arg is "$ISG_STATUS" \
  --arg ps "$PARTITION_STATUS" \
  '{
    refined_dims: $rd,
    refined_profile: $rp,
    dim_count: $dc,
    workload_count: $wc,
    total_estimated: $te,
    isg_status: $is,
    partition_status: $ps
  }'

exit 0
