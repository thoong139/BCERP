#!/usr/bin/env bash
# IMP-021 acceptance test — dim-exec-order-test/
#
# Tests execution_order + parallel_groups in all 7 dimension.json files:
#   1. All 7 dim.json files have execution_order field
#   2. All 7 dim.json files have parallel_groups field
#   3. No probe missing from execution_order vs probes[] array
#   4. No extra probes in execution_order not in probes[] array
#   5. parallel_groups cover all probes exactly once
#   6. No duplicate probes within a parallel_group
#   7. execution_order count matches probes[] count for each dim
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[dim-exec-order-test] IMP-021 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

DIMS=(
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-functional/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-business/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-security/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-performance/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-ux-a11y/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-data/dimension.json"
  "$REPO_ROOT/.claude/skills/workflow/wf-fix-compat/dimension.json"
)

PASS=0
FAIL=0
_pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

for dim in "${DIMS[@]}"; do
  dim_name=$(basename "$(dirname "$dim")")
  dim_id=$(jq -r '.dimension_id' "$dim" 2>/dev/null || echo "?")
  echo ""
  echo "--- $dim_id ($dim_name) ---"

  # Test 1: has execution_order field
  eo_len=$(jq '.execution_order | length' "$dim" 2>/dev/null || echo -1)
  if [ "$eo_len" -ge 1 ]; then
    _pass "execution_order present ($eo_len entries)"
  else
    _fail "execution_order missing or empty"
    continue
  fi

  # Test 2: has parallel_groups field
  pg_len=$(jq '.parallel_groups | length' "$dim" 2>/dev/null || echo -1)
  if [ "$pg_len" -ge 1 ]; then
    _pass "parallel_groups present ($pg_len groups)"
  else
    _fail "parallel_groups missing or empty"
    continue
  fi

  # Test 3: no probe missing from execution_order (execution_order covers all probes)
  probe_ids=$(jq -r '[.probes[].id] | sort | .[]' "$dim")
  eo_ids=$(jq -r '[.execution_order[]] | sort | .[]' "$dim")
  missing=$(comm -23 <(echo "$probe_ids") <(echo "$eo_ids") | wc -l | tr -d ' ')
  if [ "$missing" -eq 0 ]; then
    _pass "all probes in execution_order"
  else
    missing_list=$(comm -23 <(echo "$probe_ids") <(echo "$eo_ids") | tr '\n' ',')
    _fail "probes missing from execution_order: $missing_list"
  fi

  # Test 4: no extra probes in execution_order not in probes[]
  extra=$(comm -13 <(echo "$probe_ids") <(echo "$eo_ids") | wc -l | tr -d ' ')
  if [ "$extra" -eq 0 ]; then
    _pass "no phantom probes in execution_order"
  else
    extra_list=$(comm -13 <(echo "$probe_ids") <(echo "$eo_ids") | tr '\n' ',')
    _fail "phantom probes in execution_order: $extra_list"
  fi

  # Test 5: parallel_groups cover all probes exactly once (flat set = execution_order set)
  pg_flat=$(jq -r '[.parallel_groups[] | .[]] | sort | .[]' "$dim")
  pg_missing=$(comm -23 <(echo "$probe_ids") <(echo "$pg_flat") | wc -l | tr -d ' ')
  pg_extra=$(comm -13 <(echo "$probe_ids") <(echo "$pg_flat") | wc -l | tr -d ' ')
  if [ "$pg_missing" -eq 0 ] && [ "$pg_extra" -eq 0 ]; then
    _pass "parallel_groups cover all probes"
  else
    _fail "parallel_groups coverage issue: missing=$pg_missing extra=$pg_extra"
  fi

  # Test 6: no duplicates within any parallel_group
  dup_count=$(jq '[.parallel_groups[] | group_by(.) | .[] | select(length > 1)] | length' "$dim" 2>/dev/null || echo 0)
  if [ "$dup_count" -eq 0 ]; then
    _pass "no duplicate probes within parallel_groups"
  else
    _fail "duplicate probes found in parallel_groups: $dup_count duplicate(s)"
  fi

  # Test 7: execution_order count matches probes count
  probe_count=$(jq '.probes | length' "$dim")
  eo_count=$(jq '.execution_order | length' "$dim")
  if [ "$probe_count" -eq "$eo_count" ]; then
    _pass "execution_order count ($eo_count) matches probes count ($probe_count)"
  else
    _fail "execution_order count=$eo_count vs probes count=$probe_count"
  fi
done

echo ""
echo "=== SUMMARY: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "=== VERDICT: PASS ==="
  exit 0
else
  echo "=== VERDICT: FAIL ==="
  exit 1
fi
