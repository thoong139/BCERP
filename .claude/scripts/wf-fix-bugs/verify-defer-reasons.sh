#!/usr/bin/env bash
# =============================================================================
# verify-defer-reasons.sh — Wave 2 G3 (v11.0.0)
# =============================================================================
# Detect unsanctioned defers: số items có fixability ∈ {auto_fix, agent_fix}
# trong registry NHƯNG kết quả Phase 6 cuối là deferred. Đây là vi phạm
# Anti-Invention Rule của wf-fix-triage (POST-GATE T6 cấm "defer to backlog"
# cho exhaustive profile).
#
# AGGREGATE APPROACH (v11 — robust với ID schema mismatch giữa registry
# QD9-RT-NNN, fix-plan ISS-YYYYMMDD-NNN, fix-report ISS-NNN):
#   N_should_fix   = items có fixability ∈ {auto_fix, agent_fix} trong registry
#   N_actually_fixed = aggregated.fixed_total từ fix-execution-result.json
#   N_unsanctioned = N_should_fix - N_actually_fixed (approximation)
#
# Future improvement (W3+): normalize ID schemes để cross-join chính xác per-item.
#
# Required env vars:
#   SESSION_DIR
#
# Exit codes:
#   0 — Analysis complete (kể cả có unsanctioned hay không)
#   1 — Required env missing OR registry missing
#   3 — Atomic write fail
#
# Output JSON (stdout): summary
# Output file: $SESSION_DIR/phase6-execute/unsanctioned-defers.json (schema v1)
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

[ -n "${SESSION_DIR:-}" ] || { echo "ERROR: SESSION_DIR required" >&2; exit 1; }

ISSUE_REG="$SESSION_DIR/phase5-triage/issue-registry.json"
FIX_LOG="$SESSION_DIR/phase5-triage/fix-log.json"
FIX_REPORT="$SESSION_DIR/phase6-execute/fix-report.md"
FIX_EXEC_RESULT="$SESSION_DIR/phase6-execute/fix-execution-result.json"
TARGET="$SESSION_DIR/phase6-execute/unsanctioned-defers.json"

[ -s "$ISSUE_REG" ] || { echo "ERROR: issue-registry.json missing" >&2; exit 1; }
mkdir -p "$(dirname "$TARGET")"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Aggregate counts từ issue-registry (registry là SSOT cho fixability) ────
# Count by fixability category
SHOULD_FIX=$(jq '[.issues[]? | select((.fixability // "" | ascii_downcase) == "auto_fix" or (.fixability // "" | ascii_downcase) == "agent_fix")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
LEGITIMATE_DEFER_ELIGIBLE=$(jq '[.issues[]? | select((.fixability // "" | ascii_downcase) == "manual_fix" or (.fixability // "" | ascii_downcase) == "escalate" or (.fixability // "" | ascii_downcase) == "skip")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
TOTAL_ISSUES_REG=$(jq '.issues | length // 0' "$ISSUE_REG" 2>/dev/null || echo 0)

# ── Actual fixed count từ fix-execution-result.json (SSOT) ──────────────────
ACTUAL_FIXED=0
ACTUAL_DEFERRED=0
DATA_SOURCE="none"

if [ -s "$FIX_EXEC_RESULT" ]; then
  SCHEMA=$(jq -r '."$schema" // ""' "$FIX_EXEC_RESULT" 2>/dev/null || echo "")
  if [ "$SCHEMA" = "fix-execution-result-v2" ] || [ "$SCHEMA" = "fix-execution-result-v1" ]; then
    ACTUAL_FIXED=$(jq -r '(.aggregated.fixed_total // .fixed_total // 0)' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
    ACTUAL_DEFERRED=$(jq -r '(.aggregated.deferred_total // .deferred_total // 0)' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
    DATA_SOURCE="fix_execution_result_v2"
  fi
fi

# Fallback: tổng từ fix-log summary entries
if [ "$DATA_SOURCE" = "none" ] && [ -s "$FIX_LOG" ]; then
  # Sum across all is_summary entries (cumulative)
  ACTUAL_FIXED=$(jq '[.entries[]? | select(.is_summary // false) | .fixed // 0] | last // 0' "$FIX_LOG" 2>/dev/null || echo 0)
  ACTUAL_DEFERRED=$(jq '[.entries[]? | select(.is_summary // false) | .deferred // 0] | last // 0' "$FIX_LOG" 2>/dev/null || echo 0)
  DATA_SOURCE="fix_log_summary"
fi

# ── Calculate unsanctioned count ─────────────────────────────────────────────
# Unsanctioned = items có fixability fix-eligible NHƯNG không được fix
# = SHOULD_FIX - ACTUAL_FIXED (clamped to >= 0)
UNSANCTIONED_COUNT=$((SHOULD_FIX - ACTUAL_FIXED))
[ "$UNSANCTIONED_COUNT" -lt 0 ] && UNSANCTIONED_COUNT=0

# Legitimate deferred = items có fixability=manual/escalate/skip
# (đây là deferred chính đáng, không cần fix loop)
LEGITIMATE_COUNT="$LEGITIMATE_DEFER_ELIGIBLE"

# ── Identify specific unsanctioned items (best-effort per-item ID match) ────
# Lookup table: issue-registry → list of {id, fixability, severity, title}
# Cross-validate với fix-log/fix-report bằng nhiều ID schemes (best-effort)
UNSANCT_ITEMS_SAMPLE=$(jq -c '
  [.issues[]?
   | select((.fixability // "" | ascii_downcase) == "auto_fix" or (.fixability // "" | ascii_downcase) == "agent_fix")
   | {id: (.id // .issue_id // ""),
      dimension: (.dimension_id // ""),
      severity: (.severity // ""),
      title: (.title // "")[:80],
      file: (.location.file // .files[0] // ""),
      fixability: ((.fixability // "" | ascii_downcase))}]
   | .[:10]
' "$ISSUE_REG" 2>/dev/null || echo '[]')

# ── Atomic write unsanctioned-defers.json ────────────────────────────────────
TMP="$TARGET.tmp.$$"
jq -n \
  --arg ts "$NOW" \
  --arg ds "$DATA_SOURCE" \
  --argjson should_fix "$SHOULD_FIX" \
  --argjson actual_fixed "$ACTUAL_FIXED" \
  --argjson actual_deferred "$ACTUAL_DEFERRED" \
  --argjson unsanct "$UNSANCTIONED_COUNT" \
  --argjson legit "$LEGITIMATE_COUNT" \
  --argjson total "$TOTAL_ISSUES_REG" \
  --argjson sample "$UNSANCT_ITEMS_SAMPLE" \
  '{
    "$schema": "unsanctioned-defers-v1",
    "generated_at": $ts,
    "summary": {
      "total_issues_registry": $total,
      "should_fix_count": $should_fix,
      "actually_fixed_count": $actual_fixed,
      "actually_deferred_count": $actual_deferred,
      "unsanctioned_count": $unsanct,
      "legitimate_deferred_count": $legit,
      "data_source": $ds,
      "approximation_note": "Aggregate-based (do ID schema mismatch giữa registry/plan/report). Per-item attribution chỉ best-effort qua sample."
    },
    "sample_should_fix_items": $sample
  }' > "$TMP" \
  && jq '.' "$TMP" >/dev/null \
  && mv "$TMP" "$TARGET" \
  || { rm -f "$TMP"; echo "ERROR: write fail" >&2; exit 3; }

# Emit summary cho stdout
jq -c '{summary, target: "'$TARGET'"}' "$TARGET"

echo "INFO(v11): should_fix=$SHOULD_FIX, actual_fixed=$ACTUAL_FIXED, unsanctioned=$UNSANCTIONED_COUNT, legitimate=$LEGITIMATE_COUNT (source=$DATA_SOURCE)" >&2
exit 0
