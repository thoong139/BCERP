#!/usr/bin/env bash
# =============================================================================
# validate-lane-outputs.sh — Phase 4 Step 4.7 (Collect & Validate T1-T4 — v10.6)
# =============================================================================
# POST-GATE T1-T4 validation cho tất cả lane outputs:
#   T1 — File Existence (lane-status, signals.json per stream, QD-report)
#   T2 — Structure Validation (JSON shape, signals array)
#   T3 — Content Depth (signal required fields, schema validation)
#   T4 — Cross-Reference Count Matching (CLAIMED vs ACTUAL signals)
#
# E043 handling: QD-report missing → generate stub từ template (best-effort).
# E048 handling: Signal thiếu required field → log warning (drop trong consumer).
# E047 handling: CLAIMED != ACTUAL → emit data_inconsistency flag.
#
# Required env vars:
#   SESSION_DIR, DIMS_ARRAY
#
# Exit codes:
#   0 — Tất cả T1-T4 PASS
#   4 — Có FAIL nhưng không critical (E043 generated stubs, E048 invalid signals)
#   7 — DATA INCONSISTENCY (E047) — orchestrator cần escalate
#
# Output JSON (stdout):
#   {
#     "t1_pass": <int>, "t1_fail": <int>,
#     "t2_pass": <int>, "t2_fail": <int>,
#     "t3_pass": <int>, "t3_fail": <int>,
#     "t4_pass": <int>, "t4_fail": <int>,
#     "lanes_validated": <int>,
#     "data_inconsistencies": [{"dim":"QD1-functional","claimed":3,"actual":5}, ...],
#     "stubs_generated": ["QD1-functional", ...],
#     "invalid_signals": <int>,
#     "probe_failures_count": <int>,
#     "signals_total": <int>,
#     "status": "ok|partial|inconsistent"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR DIMS_ARRAY; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"
QD_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase4-find-bugs/QD-report.md"

T1_PASS=0; T1_FAIL=0
T2_PASS=0; T2_FAIL=0
T3_PASS=0; T3_FAIL=0
T4_PASS=0; T4_FAIL=0
LANES_VALIDATED=0
INVALID_SIGNALS=0
SIGNALS_TOTAL=0

INCONSISTENCIES_JSON='[]'
STUBS_JSON='[]'

for dim in $DIMS_ARRAY; do
  LANE_DIR="$LANES_ROOT/$dim"
  LANES_VALIDATED=$((LANES_VALIDATED + 1))

  # ─── CLEANUP: Xoá file literal "QD-report.md" nếu agent ghi nhầm ──────
  # (Agent đôi khi copy template với tên gốc thay vì rename theo {{DIM_DIR}}-report.md)
  # File chuẩn = "$dim-report.md" (vd: QD6-data-report.md). File literal QD-report.md là rác.
  if [ -f "$LANE_DIR/QD-report.md" ]; then
    echo "CLEANUP: $dim/QD-report.md (literal) — agent ghi nhầm template name, xoá" >&2
    rm -f "$LANE_DIR/QD-report.md"
  fi

  # ─── T1: File Existence ────────────────────────────────────────────────
  T1_OK=1
  [ -f "$LANE_DIR/lane-status.json" ] || { echo "T1 MISSING: $dim/lane-status.json" >&2; T1_OK=0; }
  [ -f "$LANE_DIR/static-scan/signals.json" ] || { echo "T1 MISSING: $dim/static-scan/signals.json" >&2; T1_OK=0; }

  # E043 handling: lane report missing → generate stub với tên CHUẨN ($dim-report.md)
  REPORT_FILE="$LANE_DIR/$dim-report.md"
  if [ ! -f "$REPORT_FILE" ]; then
    echo "E043: $dim lane report missing → generating stub ($dim-report.md)" >&2
    if [ -f "$QD_TPL" ]; then
      DIM_ID="${dim%%-*}"
      sed -e "s|{{DIM_ID}}|$DIM_ID|g" \
          -e "s|{{DIM_NAME}}|$dim|g" \
          -e "s|{{DIM_DIR}}|$dim|g" \
          -e '/_template_notes/d' -e '/_schema_notes/d' \
          "$QD_TPL" > "$REPORT_FILE" 2>/dev/null \
        && STUBS_JSON=$(echo "$STUBS_JSON" | jq --arg d "$dim" '. + [$d]') \
        || echo "WARN: cannot generate stub for $dim" >&2
    fi
  fi

  if [ "$T1_OK" -eq 1 ]; then T1_PASS=$((T1_PASS + 1)); else T1_FAIL=$((T1_FAIL + 1)); fi

  # ─── T2: Structure Validation ──────────────────────────────────────────
  T2_OK=1
  if [ -f "$LANE_DIR/lane-status.json" ]; then
    if ! jq -e '.dimension_id and .status and (.signals_static >= 0) and (.signals_runtime >= 0) and (.signals_llm >= 0)' \
         "$LANE_DIR/lane-status.json" >/dev/null 2>&1; then
      echo "T2 INVALID: $dim/lane-status.json structure" >&2
      T2_OK=0
    fi
  else
    T2_OK=0
  fi

  for sub in static-scan runtime llm-scan; do
    f="$LANE_DIR/$sub/signals.json"
    if [ -f "$f" ]; then
      if ! jq -e '.signals | type == "array"' "$f" >/dev/null 2>&1; then
        echo "T2 INVALID: $dim/$sub/signals.json (signals not array)" >&2
        T2_OK=0
      fi
    fi
  done

  if [ "$T2_OK" -eq 1 ]; then T2_PASS=$((T2_PASS + 1)); else T2_FAIL=$((T2_FAIL + 1)); fi

  # ─── T3: Content Depth (signals required fields) ──────────────────────
  T3_OK=1
  if [ -f "$LANE_DIR/lane-status.json" ]; then
    if ! jq -e '.status == "completed" or .status == "skipped" or .status == "failed"' \
         "$LANE_DIR/lane-status.json" >/dev/null 2>&1; then
      echo "T3 INVALID: $dim status not terminal" >&2
      T3_OK=0
    fi
  fi

  for sub in static-scan runtime llm-scan; do
    f="$LANE_DIR/$sub/signals.json"
    if [ -f "$f" ]; then
      INVALID_IN_FILE=$(jq -r '
        .signals
        | map(select(
            (.id == null) or (.dimension_id == null) or (.probe_id == null) or
            (.severity == null) or (.fixability == null) or (.title == null) or
            (.location.file == null) or (.fingerprint == null) or (.detected_at == null)
          ))
        | length' "$f" 2>/dev/null || echo 0)
      if [ "$INVALID_IN_FILE" -gt 0 ]; then
        echo "E048: $dim/$sub has $INVALID_IN_FILE invalid signals (missing required fields)" >&2
        INVALID_SIGNALS=$((INVALID_SIGNALS + INVALID_IN_FILE))
      fi
    fi
  done

  if [ "$T3_OK" -eq 1 ]; then T3_PASS=$((T3_PASS + 1)); else T3_FAIL=$((T3_FAIL + 1)); fi

  # ─── T4: Cross-Reference Count Matching ───────────────────────────────
  T4_OK=1
  if [ -f "$LANE_DIR/lane-status.json" ]; then
    CLAIMED=$(jq '(.signals_static // 0) + (.signals_runtime // 0) + (.signals_llm // 0)' \
              "$LANE_DIR/lane-status.json" 2>/dev/null || echo 0)
    ACTUAL=0
    for sub in static-scan runtime llm-scan; do
      f="$LANE_DIR/$sub/signals.json"
      if [ -f "$f" ]; then
        CNT=$(jq '(.signals // []) | length' "$f" 2>/dev/null || echo 0)
        ACTUAL=$((ACTUAL + CNT))
      fi
    done
    SIGNALS_TOTAL=$((SIGNALS_TOTAL + ACTUAL))

    if [ "$CLAIMED" != "$ACTUAL" ]; then
      echo "E047 DATA INCONSISTENCY: $dim claims $CLAIMED signals but files have $ACTUAL" >&2
      INCONSISTENCIES_JSON=$(echo "$INCONSISTENCIES_JSON" | jq \
        --arg d "$dim" --argjson c "$CLAIMED" --argjson a "$ACTUAL" \
        '. + [{dim: $d, claimed: $c, actual: $a}]')
      T4_OK=0
    fi
  else
    T4_OK=0
  fi

  if [ "$T4_OK" -eq 1 ]; then T4_PASS=$((T4_PASS + 1)); else T4_FAIL=$((T4_FAIL + 1)); fi
done

# Probe failures count
PROBE_FAIL_COUNT=0
if [ -f "$SESSION_DIR/phase4-find-bugs/probe-failures.log" ]; then
  PROBE_FAIL_COUNT=$(wc -l < "$SESSION_DIR/phase4-find-bugs/probe-failures.log" 2>/dev/null | tr -d ' ')
  [ -z "$PROBE_FAIL_COUNT" ] && PROBE_FAIL_COUNT=0
fi

# Determine overall status
STATUS="ok"
EXIT_CODE=0
INCONSISTENCY_COUNT=$(echo "$INCONSISTENCIES_JSON" | jq 'length')
if [ "$INCONSISTENCY_COUNT" -gt 0 ]; then
  STATUS="inconsistent"
  EXIT_CODE=7
elif [ "$T1_FAIL" -gt 0 ] || [ "$T2_FAIL" -gt 0 ] || [ "$T3_FAIL" -gt 0 ] || [ "$T4_FAIL" -gt 0 ] || [ "$INVALID_SIGNALS" -gt 0 ]; then
  STATUS="partial"
  EXIT_CODE=4
fi

# Emit aggregated JSON
jq -n \
  --argjson t1p "$T1_PASS" --argjson t1f "$T1_FAIL" \
  --argjson t2p "$T2_PASS" --argjson t2f "$T2_FAIL" \
  --argjson t3p "$T3_PASS" --argjson t3f "$T3_FAIL" \
  --argjson t4p "$T4_PASS" --argjson t4f "$T4_FAIL" \
  --argjson lv "$LANES_VALIDATED" \
  --argjson inc "$INCONSISTENCIES_JSON" \
  --argjson stubs "$STUBS_JSON" \
  --argjson is "$INVALID_SIGNALS" \
  --argjson pf "$PROBE_FAIL_COUNT" \
  --argjson st "$SIGNALS_TOTAL" \
  --arg status "$STATUS" \
  '{
    t1_pass: $t1p, t1_fail: $t1f,
    t2_pass: $t2p, t2_fail: $t2f,
    t3_pass: $t3p, t3_fail: $t3f,
    t4_pass: $t4p, t4_fail: $t4f,
    lanes_validated: $lv,
    data_inconsistencies: $inc,
    stubs_generated: $stubs,
    invalid_signals: $is,
    probe_failures_count: $pf,
    signals_total: $st,
    status: $status
  }'

exit "$EXIT_CODE"
