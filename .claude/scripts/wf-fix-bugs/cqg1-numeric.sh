#!/usr/bin/env bash
# =============================================================================
# cqg1-numeric.sh — Phase 7 Step 7.3 (CQG-1 Numeric Metric Verification — v10.11)
# =============================================================================
# Extract expected metrics từ fix-plan.md (Phase 5) và actual metrics từ
# fix-execution-result.json (v10.11 fast-path, schema fix-execution-result-v2)
# hoặc fix-report.md (legacy fallback regex). So sánh delta, fail nếu mismatch > 5%.
#
# v10.11.0 changes:
#   - Ưu tiên đọc fix-execution-result.json (structured JSON, schema v2) — robust.
#   - Nếu file v2 thiếu hoặc invalid → fallback regex Markdown fix-report.md (legacy).
#   - actual_source field trong output JSON: "json_v2" | "regex_md" (cho debug).
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   E005_HEALTHY    (default: false)
#   THRESHOLD_PCT   (default: 5)
#
# Exit codes:
#   0 — CQG-1 PASS (delta ≤ threshold)
#   1 — Required env var missing
#   4 — CQG-1 FAIL (E070 — orchestrator retry x3 → escalate)
#   5 — Skipped (E005_HEALTHY=true)
#
# Output JSON (stdout):
#   {
#     "expected": {"fixed":<int>, "deferred":<int>, "failed":<int>},
#     "actual": {"fixed":<int>, "deferred":<int>, "failed":<int>},
#     "actual_source": "json_v2|regex_md",
#     "deviation_pct": <int>,
#     "pass": <bool>,
#     "skipped": <bool>,
#     "status": "ok|fail|skipped"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

E005_HEALTHY="${E005_HEALTHY:-false}"
THRESHOLD_PCT="${THRESHOLD_PCT:-5}"

# E005 path: skip CQG-1
if [ "$E005_HEALTHY" = "true" ]; then
  jq -n '{expected:{fixed:0,deferred:0,failed:0}, actual:{fixed:0,deferred:0,failed:0}, deviation_pct:0, pass:true, skipped:true, status:"skipped"}'
  exit 5
fi

FIX_PLAN="$SESSION_DIR/phase5-triage/fix-plan.md"
FIX_REPORT="$SESSION_DIR/phase6-execute/fix-report.md"
FIX_EXEC_RESULT="$SESSION_DIR/phase6-execute/fix-execution-result.json"
FIX_PLAN_COUNTS="$SESSION_DIR/phase5-triage/fix-plan-counts.json"

[ -s "$FIX_PLAN" ] || { echo "ERROR: fix-plan.md missing" >&2; exit 1; }
[ -s "$FIX_REPORT" ] || { echo "ERROR: fix-report.md missing" >&2; exit 1; }

# ── v11: Strict mode — EXPECTED từ fix-plan-counts.json (schema v1) ─────────
# Auto-derive nếu thiếu (graceful migration cho sessions v10.x).
EXPECTED_SOURCE="fix_plan_counts_v1"

if [ ! -s "$FIX_PLAN_COUNTS" ]; then
  # Graceful migration: tự generate cho sessions cũ
  if [ -x ".claude/scripts/wf-fix-bugs/derive-fix-plan-counts.sh" ]; then
    echo "INFO(v11): fix-plan-counts.json thiếu — auto-generating cho legacy session" >&2
    bash .claude/scripts/wf-fix-bugs/derive-fix-plan-counts.sh >/dev/null 2>&1 || true
  fi
fi

if [ -s "$FIX_PLAN_COUNTS" ]; then
  EXPECTED_FIXED=$(jq -r '.expected.fixed // 0' "$FIX_PLAN_COUNTS" 2>/dev/null || echo 0)
  EXPECTED_DEFERRED=$(jq -r '.expected.deferred // 0' "$FIX_PLAN_COUNTS" 2>/dev/null || echo 0)
  EXPECTED_FAILED=$(jq -r '.expected.failed // 0' "$FIX_PLAN_COUNTS" 2>/dev/null || echo 0)
else
  # Hard fallback (only when derive script unavailable hoặc fail) — emit WARN
  if [ "${MCV3_FIX_CQG1_ALLOW_REGEX:-0}" != "1" ]; then
    echo "ERROR(v11): fix-plan-counts.json không tồn tại + không generate được. Set MCV3_FIX_CQG1_ALLOW_REGEX=1 để fallback regex (deprecated)." >&2
    exit 1
  fi
  echo "WARN(v11): Fallback regex từ fix-plan.md (KHÔNG deterministic — dùng derive-fix-plan-counts.sh)" >&2
  extract_num() {
    local f="$1" pat="$2" val
    val=$(grep -oiE "$pat" "$f" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    echo "${val:-0}"
  }
  EXPECTED_FIXED=$(extract_num "$FIX_PLAN" "fixed_count[: ]*[0-9]+|expected.*fix.*[0-9]+|sẽ sửa[: ]*[0-9]+|\*\*fixed:\*\* *[0-9]+|fix.*count[: ]*[0-9]+")
  EXPECTED_DEFERRED=$(extract_num "$FIX_PLAN" "deferred_count[: ]*[0-9]+|sẽ hoãn[: ]*[0-9]+|\*\*deferred:\*\* *[0-9]+")
  EXPECTED_FAILED=$(extract_num "$FIX_PLAN" "failed_count[: ]*[0-9]+|sẽ thất bại[: ]*[0-9]+|\*\*failed:\*\* *[0-9]+")
  EXPECTED_SOURCE="regex_md_legacy"
fi

# ── v11: Strict mode — ACTUAL từ fix-execution-result.json (schema v2/v1) ───
ACTUAL_SOURCE="none"
ACTUAL_FIXED=0
ACTUAL_DEFERRED=0
ACTUAL_FAILED=0

if [ -s "$FIX_EXEC_RESULT" ]; then
  SCHEMA=$(jq -r '."$schema" // ""' "$FIX_EXEC_RESULT" 2>/dev/null || echo "")
  if [ "$SCHEMA" = "fix-execution-result-v2" ] || [ "$SCHEMA" = "fix-execution-result-v1" ]; then
    JF=$(jq -r '(.aggregated.fixed_total // .fixed_total // 0) | tostring' "$FIX_EXEC_RESULT" 2>/dev/null || echo "")
    JD=$(jq -r '(.aggregated.deferred_total // .deferred_total // 0) | tostring' "$FIX_EXEC_RESULT" 2>/dev/null || echo "")
    JL=$(jq -r '(.aggregated.failed_total // .failed_total // 0) | tostring' "$FIX_EXEC_RESULT" 2>/dev/null || echo "")
    if [ -n "$JF" ] && [ -n "$JD" ] && [ -n "$JL" ] \
       && echo "$JF$JD$JL" | grep -qE '^[0-9]+$'; then
      ACTUAL_FIXED="$JF"
      ACTUAL_DEFERRED="$JD"
      ACTUAL_FAILED="$JL"
      ACTUAL_SOURCE="json_v2"
    fi
  fi
fi

# Strict gate: nếu không có JSON v2 valid → FAIL (trừ khi escape hatch bật)
if [ "$ACTUAL_SOURCE" = "none" ]; then
  if [ "${MCV3_FIX_CQG1_ALLOW_REGEX:-0}" != "1" ]; then
    echo "ERROR(v11): fix-execution-result.json thiếu hoặc invalid schema (cần v1/v2). Set MCV3_FIX_CQG1_ALLOW_REGEX=1 để fallback regex Markdown (deprecated)." >&2
    exit 1
  fi
  echo "WARN(v11): Fallback regex từ fix-report.md (KHÔNG deterministic)" >&2
  ACTUAL_FIXED=$(extract_num "$FIX_REPORT" "fixed[: ]*[0-9]+|\*\*fixed:\*\* *[0-9]+|đã sửa[: ]*[0-9]+|fixed_count[: ]*[0-9]+")
  ACTUAL_DEFERRED=$(extract_num "$FIX_REPORT" "deferred[: ]*[0-9]+|\*\*deferred:\*\* *[0-9]+|hoãn[: ]*[0-9]+|deferred_count[: ]*[0-9]+")
  ACTUAL_FAILED=$(extract_num "$FIX_REPORT" "\bfailed[: ]*[0-9]+|\*\*failed:\*\* *[0-9]+|thất bại[: ]*[0-9]+|failed_count[: ]*[0-9]+")
  ACTUAL_SOURCE="regex_md_legacy"
fi

echo "INFO(v11): CQG-1 sources: expected=$EXPECTED_SOURCE, actual=$ACTUAL_SOURCE" >&2

# ── Calculate deviation ──────────────────────────────────────────────────────
# Nếu expected = 0 và actual = 0 → 0% deviation (perfect)
# Nếu expected = 0 và actual > 0 → cannot calc % → use absolute diff threshold
# Nếu expected > 0 → standard %
calc_deviation() {
  local exp="$1" act="$2"
  if [ "$exp" -eq 0 ] && [ "$act" -eq 0 ]; then
    echo "0"
  elif [ "$exp" -eq 0 ]; then
    # Soft: treat as 0% nếu actual ≤ 2, else 100%
    if [ "$act" -le 2 ]; then echo "0"; else echo "100"; fi
  else
    local diff=$((act - exp))
    diff=${diff#-}  # absolute value
    awk -v d="$diff" -v e="$exp" 'BEGIN {if(e>0) printf "%d", d*100/e; else print "0"}'
  fi
}

FIXED_DELTA=$(calc_deviation "$EXPECTED_FIXED" "$ACTUAL_FIXED")
DEFERRED_DELTA=$(calc_deviation "$EXPECTED_DEFERRED" "$ACTUAL_DEFERRED")
FAILED_DELTA=$(calc_deviation "$EXPECTED_FAILED" "$ACTUAL_FAILED")

# Worst-case deviation (max of 3)
MAX_DELTA=$FIXED_DELTA
[ "$DEFERRED_DELTA" -gt "$MAX_DELTA" ] 2>/dev/null && MAX_DELTA=$DEFERRED_DELTA
[ "$FAILED_DELTA" -gt "$MAX_DELTA" ] 2>/dev/null && MAX_DELTA=$FAILED_DELTA

# ── Determine PASS/FAIL ──────────────────────────────────────────────────────
PASS=true
[ "$MAX_DELTA" -gt "$THRESHOLD_PCT" ] 2>/dev/null && PASS=false

STATUS="ok"
EXIT_CODE=0
if [ "$PASS" = "false" ]; then
  STATUS="fail"
  EXIT_CODE=4
fi

# ── Emit JSON ────────────────────────────────────────────────────────────────
# v11: thêm expected_source field cho debug/audit (NEW)
jq -n \
  --argjson ef "$EXPECTED_FIXED" --argjson ed "$EXPECTED_DEFERRED" --argjson efl "$EXPECTED_FAILED" \
  --argjson af "$ACTUAL_FIXED" --argjson ad "$ACTUAL_DEFERRED" --argjson afl "$ACTUAL_FAILED" \
  --arg as "$ACTUAL_SOURCE" \
  --arg es "$EXPECTED_SOURCE" \
  --argjson dev "$MAX_DELTA" --argjson p "$PASS" --arg st "$STATUS" \
  '{
    expected: {fixed: $ef, deferred: $ed, failed: $efl},
    actual: {fixed: $af, deferred: $ad, failed: $afl},
    expected_source: $es,
    actual_source: $as,
    deviation_pct: $dev,
    pass: $p,
    skipped: false,
    status: $st
  }'

exit "$EXIT_CODE"
