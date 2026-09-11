#!/usr/bin/env bash
# =============================================================================
# route-and-write.sh — Phase 3 Step 3.6 (gộp Threshold + Playwright + Routing + Write — v10.5)
# =============================================================================
# Gộp 4 logical sub-steps thành 1 atomic call:
#   3.6 Agent Dispatch Threshold — inline vs agent_dispatch
#   3.7 Playwright Planning — mode + slot reservation
#   3.8 Dimension → Lane Routing — 11 dims → lane skill + agent + probes
#   3.9 WRITE Outputs — work-plan.json + dimension-plan.json (CORE-031 + atomic)
#
# Required env vars (set bởi orchestrator trước khi call):
#   SESSION_DIR, SESSION_ID, REFINED_DIMS, REFINED_PROFILE,
#   WORKLOAD_COUNT, TOTAL_ESTIMATED, INTERFACE_TYPE
#
# Optional env vars:
#   MOBILE_MODE       (default: none)
#   SHOW_BROWSER      (default: empty → headless)
#   RESPONSIVE_MODE   (default: 0 → QD7 không cần browser)
#
# Exit codes:
#   0 — Cả 2 JSONs written + status emitted
#   1 — Required env var missing
#   2 — Template không tồn tại (CORE-031)
#   3 — Atomic write fail
#
# Output JSON (stdout):
#   {
#     "execution_mode": "inline|agent_dispatch",
#     "agent_count": <int>,
#     "context_pct": <int>,
#     "pw_mode": "none|headless|visible|mobile",
#     "pw_dims": "QD9 QD5 QD7" (sequential order),
#     "dimensions_routed": <int>,
#     "status": "ok|fail"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

# ── Validate required env vars ───────────────────────────────────────────────
for var in SESSION_DIR SESSION_ID REFINED_DIMS REFINED_PROFILE WORKLOAD_COUNT TOTAL_ESTIMATED INTERFACE_TYPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

# ── Defaults ─────────────────────────────────────────────────────────────────
MOBILE_MODE="${MOBILE_MODE:-none}"
SHOW_BROWSER="${SHOW_BROWSER:-}"
RESPONSIVE_MODE="${RESPONSIVE_MODE:-0}"

# ── Template paths (CORE-031) ────────────────────────────────────────────────
TPL_DIR=".claude/skills/workflow/wf-fix-bugs/templates/phase3-plan"
TPL_WORKPLAN="$TPL_DIR/work-plan.json"
TPL_DIMPLAN="$TPL_DIR/dimension-plan.json"

for tpl in "$TPL_WORKPLAN" "$TPL_DIMPLAN"; do
  [ -f "$tpl" ] || { echo "ERROR: Template missing: $tpl (CORE-031)" >&2; exit 2; }
done

OUT_DIR="$SESSION_DIR/phase3-plan"
mkdir -p "$OUT_DIR"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
OVERALL_EXIT=0

# ─────────────────────────────────────────────────────────────────────────────
# 3.6 — AGENT DISPATCH THRESHOLD (inline vs agent_dispatch)
# ─────────────────────────────────────────────────────────────────────────────
# Context % estimate: base 15% + 15%/phase completed + 10% Phase 3
COMPLETED_PHASES=$(jq -r '[.phases[]? | select(.status == "completed")] | length' \
  "$SESSION_DIR/fix-status.json" 2>/dev/null || echo "2")
CONTEXT_PCT=$((15 + COMPLETED_PHASES * 15 + 10))
[ "$CONTEXT_PCT" -gt 95 ] && CONTEXT_PCT=95

if [ "$TOTAL_ESTIMATED" -gt 200 ] || [ "$CONTEXT_PCT" -gt 70 ]; then
  EXECUTION_MODE="agent_dispatch"
  if [ "$WORKLOAD_COUNT" -gt 10 ]; then
    AGENT_COUNT=10
  else
    AGENT_COUNT=$WORKLOAD_COUNT
  fi
  [ "$AGENT_COUNT" -lt 1 ] && AGENT_COUNT=1
else
  EXECUTION_MODE="inline"
  AGENT_COUNT=0
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3.7 — PLAYWRIGHT PLANNING (mode + slot reservation)
# ─────────────────────────────────────────────────────────────────────────────
NEEDS_PLAYWRIGHT=false
PLAYWRIGHT_DIMS=""

if [ "$INTERFACE_TYPE" != "api-only" ]; then
  for dim in $(echo "$REFINED_DIMS" | tr ',' ' '); do
    dim_short="${dim%%-*}"
    case "$dim_short" in
      QD5|QD9)
        NEEDS_PLAYWRIGHT=true
        PLAYWRIGHT_DIMS="$PLAYWRIGHT_DIMS $dim"
        ;;
      QD7)
        if [ "$RESPONSIVE_MODE" = "1" ]; then
          NEEDS_PLAYWRIGHT=true
          PLAYWRIGHT_DIMS="$PLAYWRIGHT_DIMS $dim"
        fi
        ;;
    esac
  done
fi

if [ "$NEEDS_PLAYWRIGHT" = true ]; then
  if [ -n "$SHOW_BROWSER" ] && [ "$SHOW_BROWSER" = "true" ]; then
    PW_MODE="visible"
  elif [ "$MOBILE_MODE" != "none" ] && [ -n "$MOBILE_MODE" ]; then
    PW_MODE="mobile"
  else
    PW_MODE="headless"
  fi
  PW_ORDER="QD9 QD5 QD7"
  if [ "$PW_MODE" = "mobile" ]; then
    PW_DEVICES='["iPhone 13","Pixel 7","iPad Pro"]'
  else
    PW_DEVICES='[]'
  fi
else
  PW_MODE="none"
  PW_DEVICES='[]'
  PW_ORDER=""
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3.8 — DIMENSION → LANE ROUTING (11 dims)
# ─────────────────────────────────────────────────────────────────────────────
ROUTING_JSON='{"dimensions": []}'

for dim in $(echo "$REFINED_DIMS" | tr ',' ' '); do
  dim_short="${dim%%-*}"
  case "$dim_short" in
    QD1)  LANE="wf-fix-functional";            AGENT="developer";              PROBES=7; PW=false; PW_PRIO=0 ;;
    QD2)  LANE="wf-fix-business";              AGENT="business-analyst";       PROBES=5; PW=false; PW_PRIO=0 ;;
    QD3)  LANE="wf-fix-security";              AGENT="security";               PROBES=7; PW=false; PW_PRIO=0 ;;
    QD4)  LANE="wf-fix-performance";           AGENT="performance-benchmarker";PROBES=6; PW=false; PW_PRIO=0 ;;
    QD5)  LANE="wf-fix-ux-a11y";               AGENT="accessibility-auditor";  PROBES=7; PW=true;  PW_PRIO=2 ;;
    QD6)  LANE="wf-fix-data";                  AGENT="data-engineer";          PROBES=6; PW=false; PW_PRIO=0 ;;
    QD7)  LANE="wf-fix-compat";                AGENT="frontend-developer";     PROBES=5
          if [ "$RESPONSIVE_MODE" = "1" ]; then PW=true; PW_PRIO=3; else PW=false; PW_PRIO=0; fi ;;
    QD8)  LANE="wf-fix-observability";         AGENT="sre";                    PROBES=7; PW=false; PW_PRIO=0 ;;
    QD9)  LANE="wf-fix-runtime-health";        AGENT="qa-lead";                PROBES=7; PW=true;  PW_PRIO=1 ;;
    QD10) LANE="wf-fix-integration";           AGENT="architect";              PROBES=9; PW=false; PW_PRIO=0 ;;
    QD11) LANE="wf-fix-business-completeness"; AGENT="business-analyst";       PROBES=3; PW=false; PW_PRIO=0 ;;
    *)
      echo "WARNING: Unknown dimension $dim (short: $dim_short) — skipping" >&2
      continue
      ;;
  esac

  # api-only → ép TẤT CẢ Playwright lanes về false
  if [ "$INTERFACE_TYPE" = "api-only" ]; then
    PW=false
    PW_PRIO=0
  fi

  # Profile-based probe adjustment
  case "$REFINED_PROFILE" in
    quick)      PROBES=$((PROBES / 2)) ;;
    deep)       PROBES=$((PROBES * 3 / 2)) ;;
    exhaustive) PROBES=$((PROBES * 2)) ;;
  esac
  [ "$PROBES" -lt 1 ] && PROBES=1

  OUTPUT_DIR="lanes/${dim}-${LANE#wf-fix-}"

  ROUTING_JSON=$(echo "$ROUTING_JSON" | jq \
    --arg dim "$dim" \
    --arg lane "$LANE" \
    --arg agent "$AGENT" \
    --argjson probes "$PROBES" \
    --arg dir "$OUTPUT_DIR" \
    --argjson pw "$PW" \
    --argjson pw_prio "$PW_PRIO" \
    '.dimensions += [{
      id: $dim,
      lane_skill: $lane,
      agent_type: $agent,
      probe_count: $probes,
      output_dir: $dir,
      needs_playwright: $pw,
      playwright_priority: $pw_prio
    }]')
done

DIMENSIONS_ROUTED=$(echo "$ROUTING_JSON" | jq '.dimensions | length')

# Validate unique output_dir (CORE-025)
DUP_COUNT=$(echo "$ROUTING_JSON" | jq -r '.dimensions[].output_dir' | sort | uniq -d | wc -l | tr -d ' ')
if [ "$DUP_COUNT" -gt 0 ]; then
  echo "ERROR: Duplicate output_dir in routing table" >&2
  OVERALL_EXIT=3
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3.9 — WRITE OUTPUTS (CORE-031 + Atomic Write)
# ─────────────────────────────────────────────────────────────────────────────

# Build dims array JSON
DIMS_JSON=$(echo "$REFINED_DIMS" | tr ',' '\n' | jq -R -s '
  split("\n") | map(select(length > 0))')

# ── work-plan.json ───────────────────────────────────────────────────────────
TARGET="$OUT_DIR/work-plan.json"
TMP="$TARGET.tmp.$$"
if jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --arg mode "$EXECUTION_MODE" \
  --argjson agents "$AGENT_COUNT" \
  --argjson workloads "$WORKLOAD_COUNT" \
  --argjson total_est "$TOTAL_ESTIMATED" \
  --arg profile "$REFINED_PROFILE" \
  --argjson dims "$DIMS_JSON" \
  --arg pw_mode "$PW_MODE" \
  --arg pw_order "$PW_ORDER" \
  --argjson pw_devices "$PW_DEVICES" \
  '.session_id = $sid |
   .generated_at = $ts |
   .execution_mode = $mode |
   .agent_count_estimate = $agents |
   .workload_count = $workloads |
   .total_estimated_issues = $total_est |
   .estimated_issues = $total_est |
   .profile = $profile |
   .dimensions = $dims |
   .dimensions_applied = $dims |
   .playwright_planned = ($pw_mode != "none") |
   .playwright = {enabled: ($pw_mode != "none"), mode: $pw_mode, order: ($pw_order | split(" ") | map(select(length > 0))), devices: $pw_devices} |
   .mobile_devices = $pw_devices |
   del(._template_notes, ._schema_notes)' \
  "$TPL_WORKPLAN" > "$TMP" 2>/dev/null \
  && jq '.' "$TMP" >/dev/null 2>&1 \
  && mv "$TMP" "$TARGET"; then
  WP_STATUS="ok"
else
  rm -f "$TMP"
  WP_STATUS="fail"
  OVERALL_EXIT=3
fi

# ── dimension-plan.json ──────────────────────────────────────────────────────
# v10.11.0: thêm $schema cho consumer validation (dimension-plan-v2).
TARGET="$OUT_DIR/dimension-plan.json"
TMP="$TARGET.tmp.$$"
if echo "$ROUTING_JSON" | jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --arg profile "$REFINED_PROFILE" \
  --arg mode "$EXECUTION_MODE" \
  --argjson dc "$DIMENSIONS_ROUTED" \
  '. + {
    "$schema": "dimension-plan-v2",
    session_id: $sid,
    generated_at: $ts,
    isg_profile: $profile,
    profile: $profile,
    execution_mode: $mode,
    total_dimensions: $dc
  }' > "$TMP" 2>/dev/null \
  && jq '.' "$TMP" >/dev/null 2>&1 \
  && mv "$TMP" "$TARGET"; then
  DP_STATUS="ok"
else
  rm -f "$TMP"
  DP_STATUS="fail"
  OVERALL_EXIT=3
fi

# ─────────────────────────────────────────────────────────────────────────────
# Emit aggregated status JSON to stdout
# ─────────────────────────────────────────────────────────────────────────────
STATUS="ok"
[ "$WP_STATUS" = "fail" ] && STATUS="fail"
[ "$DP_STATUS" = "fail" ] && STATUS="fail"

jq -n \
  --arg em "$EXECUTION_MODE" \
  --argjson ac "$AGENT_COUNT" \
  --argjson cpct "$CONTEXT_PCT" \
  --arg pm "$PW_MODE" \
  --arg pd "$(echo "$PLAYWRIGHT_DIMS" | xargs)" \
  --argjson dr "$DIMENSIONS_ROUTED" \
  --arg st "$STATUS" \
  '{
    execution_mode: $em,
    agent_count: $ac,
    context_pct: $cpct,
    pw_mode: $pm,
    pw_dims: $pd,
    dimensions_routed: $dr,
    status: $st
  }'

exit "$OVERALL_EXIT"
