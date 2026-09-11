#!/usr/bin/env bash
# REQ-ID: MCV3-TEST (IMP-015 acceptance test)
# case-agent-citation/run.sh — Verify agent prompts use GitNexus + Serena + dim.json fixes (IMP-015)
#
# Tests:
#   1. P-QD1-agent-feature-verify.md has GitNexus keyword
#   2. P-QD1-agent-feature-verify.md has Serena keyword
#   3. P-QD1-agent-feature-verify.md has file:line citation requirement
#   4. P-QD2-domain-expert-review.md has GitNexus keyword
#   5. P-QD2-domain-expert-review.md has Serena keyword
#   6. P-QD2-domain-expert-review.md has P1→P4 handoff (p1-domain-summary.json)
#   7. P-QD3-auth-flow-verify.md has AUTH-FLOW-SKIP-NO-ARCH signal type
#   8. QD2 dimension.json has ≥25 agents in dependencies.agents
#   9. QD5 dimension.json has accessibility-auditor in dependencies.agents
#
# PASS: all 9 checks PASS → exit 0
# FAIL: any check FAIL → exit 1
#
# USAGE: bash run.sh

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$FIXTURE_DIR/../../../../../../.." && pwd)"
fi

PROBE_QD1_AGENT="$REPO_ROOT/.claude/skills/workflow/wf-fix-functional/procedures/probes/P-QD1-agent-feature-verify.md"
PROBE_QD2_DOMAIN="$REPO_ROOT/.claude/skills/workflow/wf-fix-business/procedures/probes/P-QD2-domain-expert-review.md"
PROBE_QD3_AUTH="$REPO_ROOT/.claude/skills/workflow/wf-fix-security/procedures/probes/P-QD3-auth-flow-verify.md"
DIM_QD2="$REPO_ROOT/.claude/skills/workflow/wf-fix-business/dimension.json"
DIM_QD5="$REPO_ROOT/.claude/skills/workflow/wf-fix-ux-a11y/dimension.json"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "PASS" ]; then
    echo "  ✅ PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "=== IMP-015 Acceptance Test: Agent prompts + dim.json fixes ==="
echo "    REPO_ROOT=$REPO_ROOT"
echo ""

# Test 1: P-QD1-agent-feature-verify.md has GitNexus
if grep -qi 'GitNexus\|gitnexus' "$PROBE_QD1_AGENT" 2>/dev/null; then
  check "P-QD1-agent-feature-verify.md has GitNexus reference" "PASS"
else
  check "P-QD1-agent-feature-verify.md has GitNexus reference" "FAIL"
fi

# Test 2: P-QD1-agent-feature-verify.md has Serena
if grep -qi 'Serena\|find_symbol\|find_referencing' "$PROBE_QD1_AGENT" 2>/dev/null; then
  check "P-QD1-agent-feature-verify.md has Serena/find_symbol reference" "PASS"
else
  check "P-QD1-agent-feature-verify.md has Serena/find_symbol reference" "FAIL"
fi

# Test 3: P-QD1-agent-feature-verify.md has file:line citation requirement
if grep -qi 'file:line\|file\.ts:[0-9]\|src/.*:[0-9]' "$PROBE_QD1_AGENT" 2>/dev/null; then
  check "P-QD1-agent-feature-verify.md has file:line citation requirement" "PASS"
else
  check "P-QD1-agent-feature-verify.md has file:line citation requirement" "FAIL"
fi

# Test 4: P-QD2-domain-expert-review.md has GitNexus
if grep -qi 'GitNexus\|gitnexus' "$PROBE_QD2_DOMAIN" 2>/dev/null; then
  check "P-QD2-domain-expert-review.md has GitNexus reference" "PASS"
else
  check "P-QD2-domain-expert-review.md has GitNexus reference" "FAIL"
fi

# Test 5: P-QD2-domain-expert-review.md has Serena
if grep -qi 'Serena\|find_symbol\|find_referencing' "$PROBE_QD2_DOMAIN" 2>/dev/null; then
  check "P-QD2-domain-expert-review.md has Serena/find_symbol reference" "PASS"
else
  check "P-QD2-domain-expert-review.md has Serena/find_symbol reference" "FAIL"
fi

# Test 6: P-QD2-domain-expert-review.md has P1→P4 handoff
if grep -qi 'p1-domain-summary\|P1.*P4\|handoff' "$PROBE_QD2_DOMAIN" 2>/dev/null; then
  check "P-QD2-domain-expert-review.md has P1→P4 context handoff" "PASS"
else
  check "P-QD2-domain-expert-review.md has P1→P4 context handoff" "FAIL"
fi

# Test 7: P-QD3-auth-flow-verify.md has AUTH-FLOW-SKIP-NO-ARCH
if grep -q 'AUTH-FLOW-SKIP-NO-ARCH\|auth_flow_no_arch' "$PROBE_QD3_AUTH" 2>/dev/null; then
  check "P-QD3-auth-flow-verify.md has AUTH-FLOW-SKIP-NO-ARCH signal" "PASS"
else
  check "P-QD3-auth-flow-verify.md has AUTH-FLOW-SKIP-NO-ARCH signal" "FAIL"
fi

# Test 8: QD2 dimension.json has ≥25 agents
AGENT_COUNT=$(jq '.dependencies.agents | length' "$DIM_QD2" 2>/dev/null || echo "0")
echo "    QD2 dimension.json agents count: $AGENT_COUNT"
if [ "$AGENT_COUNT" -ge 25 ]; then
  check "QD2 dimension.json has ≥25 agents (was 7, now $AGENT_COUNT)" "PASS"
else
  check "QD2 dimension.json has ≥25 agents (got $AGENT_COUNT)" "FAIL"
fi

# Test 9: QD5 dimension.json has accessibility-auditor
if jq -e '.dependencies.agents | any(. == "accessibility-auditor")' "$DIM_QD5" > /dev/null 2>&1; then
  check "QD5 dimension.json has accessibility-auditor in dependencies.agents" "PASS"
else
  check "QD5 dimension.json has accessibility-auditor in dependencies.agents" "FAIL"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
if [ "$FAIL" -eq 0 ]; then
  echo "  VERDICT: PASS — IMP-015 acceptance criteria met"
  exit 0
else
  echo "  VERDICT: FAIL — $FAIL check(s) failed"
  exit 1
fi
