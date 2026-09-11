#!/usr/bin/env bash
# wf-fix-cqg-verify.sh — CQG numeric metric verification (v7.0 S8)
#
# Verify claims trong fix-report.md vs ground truth từ fix-log.json + issue-registry.json.
# Hard enforcement: mismatch > tolerance → exit 1 → POST-GATE FAIL (E001).
#
# Usage:
#   wf-fix-cqg-verify.sh --session-dir <path> [--output <path>] [--tolerance-pct N]
#
# Inputs (read-only):
#   $SESSION_DIR/fix-report.md       — REQUIRED (claims source)
#   $SESSION_DIR/fix-log.json        — REQUIRED (ground truth: entries)
#   $SESSION_DIR/issue-registry.json — REQUIRED (ground truth: total issues)
#
# Output:
#   $SESSION_DIR/cqg-verify.json (default) or --output path
#
# Exit codes:
#   0 — passed=true, all metrics within tolerance
#   1 — invalid args / session-dir not found / required input missing
#   3 — passed=false, mismatches detected (POST-GATE FAIL)
#
# Tolerance: ±5% mặc định, configurable qua --tolerance-pct hoặc env MCV3_FIX_CQG_TOLERANCE_PCT.
#
# 3 metrics (per target arch §3.4):
#   1. issues_fixed_count   — claims "Đã fix N issues" vs jq count fix_status=fixed
#   2. files_modified_count — claims "Files modified: N" vs jq unique files_modified[]
#   3. coverage_pct         — claims "Coverage: N%" vs (fixed/total)*100

set -euo pipefail

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# ============================================================
# ARG PARSING
# ============================================================
SESSION_DIR=""
OUTPUT=""
TOLERANCE_PCT="${MCV3_FIX_CQG_TOLERANCE_PCT:-5}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir)    SESSION_DIR="$2"; shift 2 ;;
    --output)         OUTPUT="$2"; shift 2 ;;
    --tolerance-pct)  TOLERANCE_PCT="$2"; shift 2 ;;
    -h|--help)        sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }

OUTPUT="${OUTPUT:-$SESSION_DIR/cqg-verify.json}"
SESSION_ID=$(basename "$SESSION_DIR")

REPORT="$SESSION_DIR/fix-report.md"
FIX_LOG="$SESSION_DIR/fix-log.json"
ISSUE_REGISTRY="$SESSION_DIR/issue-registry.json"

[ -s "$REPORT" ]         || { echo "ERROR: fix-report.md missing or empty: $REPORT" >&2; exit 1; }
[ -s "$FIX_LOG" ]        || { echo "ERROR: fix-log.json missing or empty: $FIX_LOG" >&2; exit 1; }
[ -s "$ISSUE_REGISTRY" ] || { echo "ERROR: issue-registry.json missing or empty: $ISSUE_REGISTRY" >&2; exit 1; }

# ============================================================
# EXTRACT CLAIMS từ fix-report.md (regex-based)
# Tolerant patterns: tiếng Việt + English, multiple variants
# ============================================================
# CRLF strip cho Windows Git Bash
REPORT_CONTENT=$(tr -d '\r' < "$REPORT")

# issues_fixed_count: tìm "Đã fix N issues" hoặc "Fixed: N" hoặc "Issues fixed: N"
REPORT_FIXED=$(echo "$REPORT_CONTENT" | grep -oE 'Đã fix [0-9]+|Fixed:?[[:space:]]+[0-9]+|Issues fixed:?[[:space:]]+[0-9]+|fixed[[:space:]]*[:=][[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+' | head -1)
REPORT_FIXED="${REPORT_FIXED:-0}"

# files_modified_count: "Files modified: N" hoặc "Files changed: N"
REPORT_FILES=$(echo "$REPORT_CONTENT" | grep -oiE 'Files? modified:?[[:space:]]+[0-9]+|Files? changed:?[[:space:]]+[0-9]+|files_modified[[:space:]]*[:=][[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+' | head -1)
REPORT_FILES="${REPORT_FILES:-0}"

# coverage_pct: "Coverage: N%" hoặc "Coverage: N.NN%"
REPORT_COVERAGE=$(echo "$REPORT_CONTENT" | grep -oiE 'Coverage:?[[:space:]]+[0-9]+\.?[0-9]*[[:space:]]*%' | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
REPORT_COVERAGE="${REPORT_COVERAGE:-0}"

# ============================================================
# COMPUTE GROUND TRUTH từ fix-log + issue-registry
# ============================================================
# actual_fixed: schema fix-log-v1 không có field fix_status/status ở entry level
# (xem _shared/lane/templates/fix-log.json). Theo phase3-batch3.md §3.4, mỗi entry
# trong fix-log.json TƯƠNG ỨNG 1 issue đã fix → count length entries thay vì select field.
# Cross-check optional với issue-registry (single source of truth) ở dưới.
ACTUAL_FIXED=$(jq '[.entries[]?] | length' "$FIX_LOG" 2>/dev/null || echo 0)
# Fallback: nếu fix-log entries rỗng nhưng issue-registry có fixed → dùng registry.
# INT-04 fix: phai dual-field giong wf-fix-impact-builder.sh — phase3-batch1.md set
# `.status="fixed"` (canonical) trong khi evals/legacy dung `.fix_status`. Neu chi check
# `.fix_status` se thay ACTUAL_FIXED=0 trong khi builder thay FIXED>0 → mismatch giả → exit 3.
if [ "$ACTUAL_FIXED" -eq 0 ]; then
  ACTUAL_FIXED=$(jq '[.issues[]? | select((.status // "") == "fixed" or (.fix_status // "") == "fixed" or (.fix_status // "") == "completed")] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
fi

# actual_files: unique files_modified[] across all entries
ACTUAL_FILES=$(jq '
  [.entries[]? | (.files_modified // [])[]? | select(. != null and . != "")] | unique | length
' "$FIX_LOG" 2>/dev/null || echo 0)

# actual_coverage: (fixed / total_issues) * 100
TOTAL_ISSUES=$(jq '.issues | length // 0' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
if [ "$TOTAL_ISSUES" -gt 0 ]; then
  ACTUAL_COVERAGE=$(awk "BEGIN { printf \"%.2f\", ($ACTUAL_FIXED / $TOTAL_ISSUES) * 100 }")
else
  ACTUAL_COVERAGE="0.00"
fi

# ============================================================
# COMPARE per metric (±tolerance%)
# ============================================================
PASSED=true
MISMATCHES='[]'

# check_metric NAME REPORT ACTUAL TOLERANCE_PCT
# Output: JSON object cho metric (đẩy vào array sau)
check_metric() {
  local name="$1"
  local report="$2"
  local actual="$3"
  local tol="$4"

  # diff
  local diff diff_pct abs_diff_pct
  diff=$(awk "BEGIN { printf \"%.2f\", ($report - $actual) }")

  if awk "BEGIN { exit !($actual == 0) }"; then
    if awk "BEGIN { exit !($report == 0) }"; then
      diff_pct="0.00"
    else
      diff_pct="100.00"
    fi
  else
    diff_pct=$(awk "BEGIN { printf \"%.2f\", (($report - $actual) / $actual * 100) }")
  fi

  # abs
  abs_diff_pct=$(awk "BEGIN { v=$diff_pct; if (v<0) v=-v; printf \"%.2f\", v }")

  # CHU Y: function chay trong subshell — KHONG set PASSED/MISMATCHES o day; caller re-computes.
  # status: match | mismatch
  local status
  if awk "BEGIN { exit !($abs_diff_pct > $tol) }"; then
    status="mismatch"
  else
    status="match"
  fi

  jq -nc \
    --arg n "$name" \
    --argjson r "$report" \
    --argjson a "$actual" \
    --argjson d "$diff" \
    --argjson dp "$diff_pct" \
    --argjson tol "$tol" \
    --arg s "$status" \
    '{
      metric: $n,
      report_value: $r,
      actual_value: $a,
      diff: $d,
      diff_pct: $dp,
      tolerance_pct: $tol,
      status: $s
    }'
}

METRIC1=$(check_metric "issues_fixed_count" "$REPORT_FIXED" "$ACTUAL_FIXED" "$TOLERANCE_PCT")
METRIC2=$(check_metric "files_modified_count" "$REPORT_FILES" "$ACTUAL_FILES" "$TOLERANCE_PCT")
METRIC3=$(check_metric "coverage_pct" "$REPORT_COVERAGE" "$ACTUAL_COVERAGE" "$TOLERANCE_PCT")

# Re-read PASSED + MISMATCHES (modified inside check_metric via subshell? No — function runs in same shell)
# But subshell captures from $(check_metric ...) — modifications to PASSED/MISMATCHES inside DON'T persist!
# Workaround: re-compute mismatches từ 3 metrics bằng jq.

ALL_METRICS=$(jq -nc \
  --argjson m1 "$METRIC1" --argjson m2 "$METRIC2" --argjson m3 "$METRIC3" \
  '[$m1, $m2, $m3]')

MISMATCHES=$(jq -c '[.[] | select(.status == "mismatch") | {metric, report: .report_value, actual: .actual_value, diff, diff_pct}]' <<< "$ALL_METRICS")
MISMATCH_COUNT=$(jq 'length' <<< "$MISMATCHES")

if [ "$MISMATCH_COUNT" -gt 0 ]; then
  PASSED=false
  FAIL_REQUIRED_CDG=true
else
  PASSED=true
  FAIL_REQUIRED_CDG=false
fi

# ============================================================
# ASSEMBLE final JSON
# ============================================================
RAN_AT=$(iso_now)

FINAL_JSON=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg ran "$RAN_AT" \
  --argjson passed "$PASSED" \
  --argjson metrics "$ALL_METRICS" \
  --argjson mismatches "$MISMATCHES" \
  --argjson cdg "$FAIL_REQUIRED_CDG" \
  '{
    "$schema": "wf-fix-cqg-verify-v1",
    session_id: $sid,
    ran_at: $ran,
    passed: $passed,
    metrics: $metrics,
    mismatches: $mismatches,
    fail_required_cdg: $cdg
  }')

# ============================================================
# WRITE atomic + validate
# ============================================================
atomic_write_json "$OUTPUT" "$FINAL_JSON" || { echo "ERROR: atomic_write_json failed" >&2; exit 1; }

SCHEMA=$(jq -r '."$schema"' "$OUTPUT")
[ "$SCHEMA" = "wf-fix-cqg-verify-v1" ] || { echo "ERROR: schema mismatch in output: $SCHEMA" >&2; exit 1; }

echo "OK: cqg-verify.json generated → $OUTPUT" >&2
echo "    report_fixed=$REPORT_FIXED actual_fixed=$ACTUAL_FIXED" >&2
echo "    report_files=$REPORT_FILES actual_files=$ACTUAL_FILES" >&2
echo "    report_coverage=$REPORT_COVERAGE actual_coverage=$ACTUAL_COVERAGE tolerance_pct=$TOLERANCE_PCT" >&2
echo "    passed=$PASSED mismatches=$MISMATCH_COUNT" >&2

if [ "$PASSED" = "false" ]; then
  echo "FAIL: CQG verify mismatch — see $OUTPUT" >&2
  jq '.mismatches' "$OUTPUT" >&2
  exit 3
fi

exit 0
