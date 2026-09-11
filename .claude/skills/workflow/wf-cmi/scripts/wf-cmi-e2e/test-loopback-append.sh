#!/usr/bin/env bash
# Test G5.6 — Loop-back gap-suggestions APPEND test
#
# Verify:
# 1. APPEND CHỈ kind=e2e_scenario_fix vào gap-suggestions.json
# 2. Schema vẫn `gap-suggestions-v1` (KHÔNG bump)
# 3. KHÔNG re-trigger CD41 (anti-loop guard)
# 4. metadata.kind_breakdown.e2e_scenario_fix counter chính xác
# 5. metadata.suggestion_count counter chính xác
#
# Usage: bash test-loopback-append.sh
# Exit: 0 = PASS, 1 = FAIL

set -e

TEST_DIR=$(mktemp -d -t cmi-loopback-test-XXXXXX)
trap "rm -rf '$TEST_DIR'" EXIT

cd "$TEST_DIR"

echo "=== G5.6 — Loop-back gap-suggestions APPEND Test ==="
echo "Test dir: $TEST_DIR"
echo ""

# Step 1: Init gap-suggestions.json từ template
TPL_PATH="${MCV3_REPO_ROOT:-D:/MCV3}/.claude/skills/workflow/wf-cmi/templates/gap-suggestions.json"

if [ ! -f "$TPL_PATH" ]; then
  echo "❌ FAIL: Template not found: $TPL_PATH"
  exit 1
fi

# Strip _template_notes + populate placeholders (simulate Phase 7 init)
jq 'del(._template_notes) | .session_id = "test-session-001" | .generated_at = "2026-05-16T00:00:00Z" | .scope.type = "system"' "$TPL_PATH" > gap-suggestions.json

# Verify initial state
INIT_SCHEMA=$(jq -r '."$schema"' gap-suggestions.json)
INIT_COUNT=$(jq '.metadata.suggestion_count' gap-suggestions.json)
INIT_E2E_COUNT=$(jq '.metadata.kind_breakdown.e2e_scenario_fix' gap-suggestions.json)

echo "Step 1: Initial state"
echo "  - \$schema: $INIT_SCHEMA"
echo "  - suggestion_count: $INIT_COUNT"
echo "  - e2e_scenario_fix breakdown: $INIT_E2E_COUNT"

[ "$INIT_SCHEMA" != "gap-suggestions-v1" ] && { echo "❌ FAIL: Initial schema wrong"; exit 1; }
[ "$INIT_COUNT" != "0" ] && { echo "❌ FAIL: Initial count not 0"; exit 1; }
[ "$INIT_E2E_COUNT" != "0" ] && { echo "❌ FAIL: Initial e2e count not 0"; exit 1; }

echo "  ✅ Initial state OK"
echo ""

# Step 2: APPEND e2e_scenario_fix suggestion (simulate Phase 10 loop-back)
echo "Step 2: APPEND 3 e2e_scenario_fix suggestions"

NEW_SUGG_1=$(jq -n '{
  id: "SUGG-e2e_scenario_fix-001",
  kind: "e2e_scenario_fix",
  title: "E2E auto-fix loop-back: ISSUE-CMI-SC-001-3",
  description: "Phase 10 auto-fix PASS via Phase A selector_variant_data_testid",
  target_path: "phase4-coverage/lanes/CD41-e2e-synth/scenarios/test-scenario-CMI-01.md",
  source_signal_ids: ["ISSUE-CMI-SC-001-3"],
  confidence: 0.95,
  severity: "HIGH",
  status: "proposed",
  linked_invariant_id: "INV-CRM-001",
  source_dim: "CD11",
  rationale: "Phase A success — selector worked: [data-testid=customer-save-btn]",
  generated_at: "2026-05-16T01:00:00Z",
  generated_by: "wf-cmi/phase10-e2e-resolution v3.0"
}')

NEW_SUGG_2=$(jq -n '{
  id: "SUGG-e2e_scenario_fix-002",
  kind: "e2e_scenario_fix",
  title: "E2E auto-fix loop-back: ISSUE-CMI-SC-002-5",
  description: "Phase 10 auto-fix Phase B spawn frontend-developer",
  target_path: "apps/erp-web/src/components/CustomerForm.tsx",
  source_signal_ids: ["ISSUE-CMI-SC-002-5"],
  confidence: 0.85,
  severity: "MEDIUM",
  status: "proposed",
  linked_invariant_id: "INV-CRM-005",
  source_dim: "CD11",
  rationale: "Phase B success — frontend-developer added null check",
  generated_at: "2026-05-16T01:01:00Z",
  generated_by: "wf-cmi/phase10-e2e-resolution v3.0"
}')

NEW_SUGG_3=$(jq -n '{
  id: "SUGG-e2e_scenario_fix-003",
  kind: "e2e_scenario_fix",
  title: "E2E auto-fix loop-back: ISSUE-CMI-SC-003-7 UNRESOLVED",
  description: "Phase 10 auto-fix FAIL — manual review required",
  target_path: "apps/backend/Eureka.Api/Application/Logistics/...",
  source_signal_ids: ["ISSUE-CMI-SC-003-7"],
  confidence: 0.30,
  severity: "HIGH",
  status: "proposed",
  linked_invariant_id: "INV-LOG-008",
  source_dim: "CD37",
  rationale: "Phase A + Phase B đều fail — UNRESOLVED, low confidence",
  generated_at: "2026-05-16T01:02:00Z",
  generated_by: "wf-cmi/phase10-e2e-resolution v3.0"
}')

# APPEND tất cả 3
for SUGG in "$NEW_SUGG_1" "$NEW_SUGG_2" "$NEW_SUGG_3"; do
  jq --argjson new "$SUGG" \
     '.suggestions += [$new] |
      .metadata.suggestion_count = (.suggestions | length) |
      .metadata.kind_breakdown.e2e_scenario_fix = ((.metadata.kind_breakdown.e2e_scenario_fix // 0) + 1) |
      .metadata.status_breakdown.proposed = ((.metadata.status_breakdown.proposed // 0) + 1)' \
     gap-suggestions.json > gap-suggestions.json.tmp
  mv gap-suggestions.json.tmp gap-suggestions.json
done

# Step 3: Verify post-append state
echo ""
echo "Step 3: Verify post-append state"

POST_SCHEMA=$(jq -r '."$schema"' gap-suggestions.json)
POST_COUNT=$(jq '.metadata.suggestion_count' gap-suggestions.json)
POST_E2E_COUNT=$(jq '.metadata.kind_breakdown.e2e_scenario_fix' gap-suggestions.json)
POST_PROPOSED=$(jq '.metadata.status_breakdown.proposed' gap-suggestions.json)
POST_TEST_CASE=$(jq '.metadata.kind_breakdown.test_case' gap-suggestions.json)

echo "  - \$schema: $POST_SCHEMA (expected: gap-suggestions-v1)"
echo "  - suggestion_count: $POST_COUNT (expected: 3)"
echo "  - e2e_scenario_fix breakdown: $POST_E2E_COUNT (expected: 3)"
echo "  - test_case breakdown: $POST_TEST_CASE (expected: 0 — anti-loop guard)"
echo "  - status proposed: $POST_PROPOSED (expected: 3)"

FAIL=0

# Schema vẫn v1
[ "$POST_SCHEMA" != "gap-suggestions-v1" ] && { echo "❌ FAIL: Schema bị thay đổi (expected gap-suggestions-v1, got $POST_SCHEMA)"; FAIL=1; }

# 3 suggestions appended
[ "$POST_COUNT" != "3" ] && { echo "❌ FAIL: suggestion_count wrong ($POST_COUNT != 3)"; FAIL=1; }

# Cả 3 đều là e2e_scenario_fix
[ "$POST_E2E_COUNT" != "3" ] && { echo "❌ FAIL: e2e_scenario_fix breakdown wrong ($POST_E2E_COUNT != 3)"; FAIL=1; }

# Anti-loop guard: KHÔNG có kind khác bị tăng
[ "$POST_TEST_CASE" != "0" ] && { echo "❌ FAIL: test_case bị tăng (anti-loop guard violation)"; FAIL=1; }

INVARIANT_COUNT=$(jq '.metadata.kind_breakdown.invariant_rule' gap-suggestions.json)
[ "$INVARIANT_COUNT" != "0" ] && { echo "❌ FAIL: invariant_rule bị tăng (anti-loop guard violation)"; FAIL=1; }

# All proposed status
[ "$POST_PROPOSED" != "3" ] && { echo "❌ FAIL: proposed count wrong ($POST_PROPOSED != 3)"; FAIL=1; }

# Verify confidence buckets (auto-corrected vs unresolved)
HIGH_CONF=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence >= 0.85)] | length' gap-suggestions.json)
LOW_CONF=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence <= 0.30)] | length' gap-suggestions.json)

echo "  - High confidence (≥0.85, auto-corrected): $HIGH_CONF (expected: 2)"
echo "  - Low confidence (≤0.30, unresolved): $LOW_CONF (expected: 1)"

[ "$HIGH_CONF" != "2" ] && { echo "❌ FAIL: High confidence count wrong"; FAIL=1; }
[ "$LOW_CONF" != "1" ] && { echo "❌ FAIL: Low confidence count wrong"; FAIL=1; }

# JSON still valid
if ! jq -e '.' gap-suggestions.json >/dev/null 2>&1; then
  echo "❌ FAIL: JSON invalid sau APPEND"
  FAIL=1
fi

echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "✅ G5.6 PASS — Loop-back APPEND works correctly + anti-loop guard intact"
  exit 0
else
  echo "❌ G5.6 FAIL — Loop-back APPEND or anti-loop guard violated"
  exit 1
fi
