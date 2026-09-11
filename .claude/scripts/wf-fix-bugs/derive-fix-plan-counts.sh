#!/usr/bin/env bash
# =============================================================================
# derive-fix-plan-counts.sh — Wave 1 G1 (v10.19.0)
# =============================================================================
# Derive expected counts từ fix-plan.md (Phase 5 output) → ghi fix-plan-counts.json
# (schema fix-plan-counts-v1). Phase 7 CQG-1 đọc file này thay regex Markdown.
#
# Rationale: regex `fixed_count[:= ]*[0-9]+` trong cqg1-numeric.sh không
# deterministic trên fix-plan.md có hàng trăm dòng action="fix" — pick wrong
# number → CQG-1 PASS giả. Script này đếm CHÍNH XÁC bằng table row pattern.
#
# Required env vars:
#   SESSION_DIR
#
# Exit codes:
#   0 — fix-plan-counts.json written successfully
#   1 — Required env var missing hoặc fix-plan.md missing
#   3 — Atomic write fail
#
# Output JSON (stdout): summary của counts
# Output file: $SESSION_DIR/phase5-triage/fix-plan-counts.json (schema v1)
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

[ -n "${SESSION_DIR:-}" ] || { echo "ERROR: SESSION_DIR required" >&2; exit 1; }

FIX_PLAN="$SESSION_DIR/phase5-triage/fix-plan.md"
ISSUE_REG="$SESSION_DIR/phase5-triage/issue-registry.json"
TARGET="$SESSION_DIR/phase5-triage/fix-plan-counts.json"

[ -s "$FIX_PLAN" ] || { echo "ERROR: fix-plan.md missing tại $FIX_PLAN" >&2; exit 1; }

# ── Đếm theo Action column trong markdown table ──────────────────────────────
# Table format: | <Priority> | <Issue ID> | <Action> | <File(s)> | <Est. Time> | [CDG] |
# Actions canonical (per wf-fix-triage Anti-Invention Rule): fix | manual_review | escalate | skip
# Variants accepted: auto_fix, agent_fix (treated as fix)

count_action() {
  local action_pattern="$1"
  local n
  # grep -c outputs "0" + exits 1 on no match → wrap với `|| true` để set -e không trigger
  n=$(grep -cE "^\| (CRITICAL|HIGH|MEDIUM|LOW) \|[^|]+\| ${action_pattern} \|" "$FIX_PLAN" 2>/dev/null || true)
  echo "${n:-0}"
}

FIX_COUNT=$(count_action "(fix|auto_fix|agent_fix)")
MANUAL_COUNT=$(count_action "manual_review")
ESCALATE_COUNT=$(count_action "escalate")
SKIP_COUNT=$(count_action "skip")

# Tổng deferred = manual + escalate + skip (legitimate non-fix actions)
DEFERRED_TOTAL=$((MANUAL_COUNT + ESCALATE_COUNT + SKIP_COUNT))

# ── Cross-validate với issue-registry.json (nếu có) ──────────────────────────
REG_FIX=0
REG_DEF=0
REG_TOTAL=0

if [ -s "$ISSUE_REG" ]; then
  REG_FIX=$(jq '[.issues[]? | select(.fixability == "auto_fix" or .fixability == "agent_fix" or .fixability == "AUTO_FIX" or .fixability == "AGENT_FIX")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
  REG_DEF=$(jq '[.issues[]? | select(.fixability == "manual_fix" or .fixability == "escalate" or .fixability == "skip" or .fixability == "MANUAL_FIX" or .fixability == "ESCALATE" or .fixability == "SKIP")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
  REG_TOTAL=$(jq '.issues | length // 0' "$ISSUE_REG" 2>/dev/null || echo 0)
fi

# ── Detect mismatch giữa plan và registry (warn) ─────────────────────────────
WARN_MISMATCH="false"
if [ "$REG_TOTAL" -gt 0 ] && [ "$REG_FIX" -ne "$FIX_COUNT" ]; then
  WARN_MISMATCH="true"
  echo "WARN: Plan action=fix count ($FIX_COUNT) khác Registry fixability=auto/agent_fix count ($REG_FIX)" >&2
fi

# ── Atomic write fix-plan-counts.json ────────────────────────────────────────
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP="$TARGET.tmp.$$"

jq -n \
  --argjson plan_fix "$FIX_COUNT" \
  --argjson plan_manual "$MANUAL_COUNT" \
  --argjson plan_escalate "$ESCALATE_COUNT" \
  --argjson plan_skip "$SKIP_COUNT" \
  --argjson def_total "$DEFERRED_TOTAL" \
  --argjson reg_fix "$REG_FIX" \
  --argjson reg_def "$REG_DEF" \
  --argjson reg_total "$REG_TOTAL" \
  --argjson warn_mismatch "$WARN_MISMATCH" \
  --arg ts "$NOW" \
  --arg src_plan "$FIX_PLAN" \
  '{
    "$schema": "fix-plan-counts-v1",
    "generated_at": $ts,
    "source": {
      "fix_plan": $src_plan,
      "issue_registry": "phase5-triage/issue-registry.json"
    },
    "expected": {
      "fixed": $plan_fix,
      "deferred": $def_total,
      "failed": 0
    },
    "breakdown": {
      "plan_action_fix": $plan_fix,
      "plan_action_manual_review": $plan_manual,
      "plan_action_escalate": $plan_escalate,
      "plan_action_skip": $plan_skip,
      "registry_fixability_auto_or_agent": $reg_fix,
      "registry_fixability_manual_escalate_skip": $reg_def,
      "registry_total_issues": $reg_total
    },
    "cross_validation": {
      "plan_vs_registry_mismatch": $warn_mismatch
    }
  }' > "$TMP" \
  && jq '.' "$TMP" >/dev/null \
  && mv "$TMP" "$TARGET" \
  || { rm -f "$TMP"; echo "ERROR: write fail tại $TARGET" >&2; exit 3; }

# Emit summary cho stdout
jq -c '{expected: .expected, breakdown: .breakdown, target: "'$TARGET'"}' "$TARGET"

echo "OK: $TARGET (expected_fixed=$FIX_COUNT, expected_deferred=$DEFERRED_TOTAL)" >&2
exit 0
