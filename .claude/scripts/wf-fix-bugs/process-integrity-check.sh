#!/usr/bin/env bash
# =============================================================================
# process-integrity-check.sh — Phase 5 Step 5.5 (Process Integrity PI1-PI5 — v10.7)
# =============================================================================
# Audit tính toàn vẹn quy trình Phase 4 → 5:
#   PI1 — Step Completeness: tất cả steps Phase 4 đã chạy?
#   PI2 — Empty Result Recording: lanes không có signals đã ghi nhận?
#   PI3 — Signal Overwrite Detection: 1 file = 1 writer (CORE-025)?
#   PI4 — Dimension Execution Completeness: dim trong plan có lane directory?
#   PI5 — Cross-Source Consistency: static + runtime signals có khớp pattern?
#
# Output: $SESSION_DIR/phase5-triage/process-violations.json (schema process-violations-v1)
# Template (CORE-031): templates/phase5-triage/process-violations.json
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Exit codes:
#   0 — Integrity PASS (zero critical violations)
#   1 — Required env var missing
#   2 — Template missing
#   3 — Atomic write fail
#   4 — Critical violation detected (E052 — orchestrator render CDG)
#
# Output JSON (stdout):
#   {
#     "integrity_pass": <bool>,
#     "total_violations": <int>,
#     "critical_count": <int>,
#     "high_count": <int>,
#     "low_count": <int>,
#     "checks_summary": {"PI1":..., "PI2":..., "PI3":..., "PI4":..., "PI5":...},
#     "status": "ok|violations"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

DIM_PLAN="$SESSION_DIR/phase3-plan/dimension-plan.json"
LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"
FIX_STATUS="$SESSION_DIR/fix-status.json"
PHASE5_DIR="$SESSION_DIR/phase5-triage"
TARGET="$PHASE5_DIR/process-violations.json"
TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/process-violations.json"

[ -s "$DIM_PLAN" ] || { echo "ERROR: dimension-plan.json missing" >&2; exit 1; }
[ -s "$FIX_STATUS" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }
[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }

mkdir -p "$PHASE5_DIR"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Parse dims planned từ dimension-plan
DIMS_PLANNED=$(jq -r '.dimensions[] | .id + "-" + (.name // .id | ascii_downcase | gsub("[^a-z0-9]+"; "-") | sub("^-"; "") | sub("-$"; ""))' "$DIM_PLAN" | tr -d '\r')

VIOLATIONS_JSON='[]'
CRITICAL=0; HIGH=0; LOW=0

append_violation() {
  # $1 = check_id, $2 = severity, $3 = description
  local cid="$1" sev="$2" desc="$3"
  VIOLATIONS_JSON=$(echo "$VIOLATIONS_JSON" | jq \
    --arg cid "$cid" --arg sev "$sev" --arg desc "$desc" \
    '. + [{check: $cid, severity: $sev, description: $desc}]')
  case "$sev" in
    critical) CRITICAL=$((CRITICAL + 1)) ;;
    high)     HIGH=$((HIGH + 1)) ;;
    low)      LOW=$((LOW + 1)) ;;
  esac
}

# ── PI1: Step Completeness ────────────────────────────────────────────────────
PI1_PASS=true
PI1_VIOLATIONS=0
if ! jq -e '.phases.phase4.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1; then
  append_violation "PI1" "critical" "Phase 4 not completed"
  PI1_PASS=false
  PI1_VIOLATIONS=1
fi

# ── PI2: Empty Result Recording ──────────────────────────────────────────────
PI2_PASS=true
PI2_VIOLATIONS=0
for dim in $DIMS_PLANNED; do
  LANE_DIR="$LANES_ROOT/$dim"
  if [ ! -f "$LANE_DIR/lane-status.json" ]; then
    append_violation "PI2" "high" "$dim missing lane-status.json"
    PI2_PASS=false
    PI2_VIOLATIONS=$((PI2_VIOLATIONS + 1))
  fi
done

# ── PI3: Signal Overwrite Detection ──────────────────────────────────────────
PI3_PASS=true
PI3_VIOLATIONS=0
for dim in $DIMS_PLANNED; do
  LANE_DIR="$LANES_ROOT/$dim"
  if [ -d "$LANE_DIR" ]; then
    for sub in static-scan runtime llm-scan; do
      CNT=$(find "$LANE_DIR/$sub" -maxdepth 2 -name "signals.json" 2>/dev/null | wc -l | tr -d ' ')
      if [ "${CNT:-0}" -gt 1 ]; then
        append_violation "PI3" "critical" "$dim/$sub has $CNT signals.json files (overwrite — CORE-025 violation)"
        PI3_PASS=false
        PI3_VIOLATIONS=$((PI3_VIOLATIONS + 1))
      fi
    done
  fi
done

# ── PI4: Dimension Execution Completeness ────────────────────────────────────
PI4_PASS=true
PI4_VIOLATIONS=0
for dim in $DIMS_PLANNED; do
  if [ ! -d "$LANES_ROOT/$dim" ]; then
    append_violation "PI4" "high" "$dim not executed (no lane directory)"
    PI4_PASS=false
    PI4_VIOLATIONS=$((PI4_VIOLATIONS + 1))
  fi
done

# ── PI5: Cross-Source Consistency ────────────────────────────────────────────
PI5_PASS=true
PI5_VIOLATIONS=0
for dim in $DIMS_PLANNED; do
  LANE_DIR="$LANES_ROOT/$dim"
  if [ -d "$LANE_DIR" ]; then
    STATIC_FILES=$(jq -r '(.signals // [])[].location.file // empty' \
      "$LANE_DIR/static-scan/signals.json" 2>/dev/null | sort -u | head -50)
    RUNTIME_FILES=$(jq -r '(.signals // [])[].location.file // empty' \
      "$LANE_DIR/runtime/signals.json" 2>/dev/null | sort -u | head -50)
    # Chỉ flag nếu BOTH sources non-empty và KHÔNG có overlap
    if [ -n "$STATIC_FILES" ] && [ -n "$RUNTIME_FILES" ]; then
      OVERLAP=$(comm -12 <(echo "$STATIC_FILES") <(echo "$RUNTIME_FILES") | wc -l | tr -d ' ')
      if [ "${OVERLAP:-0}" -eq 0 ]; then
        append_violation "PI5" "low" "$dim: static + runtime signals zero file overlap (consistency flag)"
        PI5_PASS=false
        PI5_VIOLATIONS=$((PI5_VIOLATIONS + 1))
      fi
    fi
  fi
done

# ── Build process-violations.json from template (CORE-031) ───────────────────
TOTAL_VIOLATIONS=$((CRITICAL + HIGH + LOW))
INTEGRITY_PASS=true
[ "$CRITICAL" -gt 0 ] && INTEGRITY_PASS=false

TMP="$TARGET.tmp.$$"
jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --argjson violations "$VIOLATIONS_JSON" \
  --argjson total "$TOTAL_VIOLATIONS" \
  --argjson crit "$CRITICAL" \
  --argjson integrity "$INTEGRITY_PASS" \
  --argjson pi1p "$PI1_PASS" --argjson pi1v "$PI1_VIOLATIONS" \
  --argjson pi2p "$PI2_PASS" --argjson pi2v "$PI2_VIOLATIONS" \
  --argjson pi3p "$PI3_PASS" --argjson pi3v "$PI3_VIOLATIONS" \
  --argjson pi4p "$PI4_PASS" --argjson pi4v "$PI4_VIOLATIONS" \
  --argjson pi5p "$PI5_PASS" --argjson pi5v "$PI5_VIOLATIONS" \
  '.session_id = $sid
   | .generated_at = $ts
   | .violations = $violations
   | .total_violations = $total
   | .critical_count = $crit
   | .integrity_pass = $integrity
   | .checks.PI1_step_completeness = {pass: $pi1p, violations: $pi1v}
   | .checks.PI2_empty_result_recording = {pass: $pi2p, violations: $pi2v}
   | .checks.PI3_signal_overwrite_detection = {pass: $pi3p, violations: $pi3v}
   | .checks.PI4_dimension_execution_completeness = {pass: $pi4p, violations: $pi4v}
   | .checks.PI5_cross_source_consistency = {pass: $pi5p, violations: $pi5v}
   | del(._template_notes)' \
  "$TPL" > "$TMP" 2>/dev/null

if [ -s "$TMP" ] && jq '.' "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$TARGET"
else
  rm -f "$TMP"
  echo "ERROR: Atomic write process-violations.json fail (E035)" >&2
  exit 3
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
STATUS="ok"
EXIT_CODE=0
if [ "$CRITICAL" -gt 0 ]; then
  STATUS="violations"
  EXIT_CODE=4
elif [ "$TOTAL_VIOLATIONS" -gt 0 ]; then
  STATUS="violations"
  # high/low warnings: orchestrator continue, không block
  EXIT_CODE=0
fi

jq -n \
  --argjson ip "$INTEGRITY_PASS" \
  --argjson tv "$TOTAL_VIOLATIONS" \
  --argjson c "$CRITICAL" \
  --argjson h "$HIGH" \
  --argjson l "$LOW" \
  --argjson p1p "$PI1_PASS" --argjson p1v "$PI1_VIOLATIONS" \
  --argjson p2p "$PI2_PASS" --argjson p2v "$PI2_VIOLATIONS" \
  --argjson p3p "$PI3_PASS" --argjson p3v "$PI3_VIOLATIONS" \
  --argjson p4p "$PI4_PASS" --argjson p4v "$PI4_VIOLATIONS" \
  --argjson p5p "$PI5_PASS" --argjson p5v "$PI5_VIOLATIONS" \
  --arg st "$STATUS" \
  '{
    integrity_pass: $ip,
    total_violations: $tv,
    critical_count: $c,
    high_count: $h,
    low_count: $l,
    checks_summary: {
      PI1: {pass: $p1p, violations: $p1v},
      PI2: {pass: $p2p, violations: $p2v},
      PI3: {pass: $p3p, violations: $p3v},
      PI4: {pass: $p4p, violations: $p4v},
      PI5: {pass: $p5p, violations: $p5v}
    },
    status: $st
  }'

exit "$EXIT_CODE"
