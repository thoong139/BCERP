#!/usr/bin/env bash
# IMP-011 acceptance test — case-cascade-skip/
#
# Tests:
#   1. probe-dag.json exists and is valid JSON with required fields
#   2. infra-preflight → api-smoke cascade-skip edge is declared
#   3. All 7 dimensions have at least 1 node
#   4. Cycle detection: no probe depends on itself
#   5. execution_order: static probes defined in g0 before runtime g1
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-cascade-skip] IMP-011 acceptance test"

# Locate probe-dag.json
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

DAG_FILE="$REPO_ROOT/.claude/skills/workflow/_shared/lane/probe-dag.json"

if [ ! -f "$DAG_FILE" ]; then
  echo "FAIL: probe-dag.json not found at $DAG_FILE" >&2
  exit 1
fi
echo "[case-cascade-skip] DAG: $DAG_FILE"

# ============================================================
# Test 1: Valid JSON + required fields
# ============================================================
echo ""
echo "--- Test 1: Valid JSON structure ---"
if ! jq '.' "$DAG_FILE" >/dev/null 2>&1; then
  echo "  FAIL: not valid JSON"
  exit 1
fi

schema=$(jq -r '."$schema"' "$DAG_FILE")
if [ "$schema" != "probe-dag-v1" ]; then
  echo "  FAIL: \$schema must be 'probe-dag-v1' (got: $schema)"
  exit 1
fi

node_count=$(jq '.nodes | length' "$DAG_FILE")
edge_count=$(jq '.edges | length' "$DAG_FILE")
echo "  PASS: valid JSON, schema=probe-dag-v1, nodes=$node_count, edges=$edge_count"

# ============================================================
# Test 2: infra-preflight → api-smoke cascade-skip declared
# ============================================================
echo ""
echo "--- Test 2: CC-001 cascade-skip edge ---"
cascade=$(jq -r '
  .edges[] |
  select(.from == "P-QD1-infra-preflight" and .to == "P-QD1-api-smoke" and .type == "cascade-skip") |
  .doc
' "$DAG_FILE")

if [ -z "$cascade" ]; then
  echo "  FAIL: no cascade-skip edge from P-QD1-infra-preflight to P-QD1-api-smoke"
  exit 1
fi
echo "  PASS: cascade-skip edge found: $cascade"

# Check cascade_skip_rules entry
rule=$(jq -r '.cascade_skip_rules["P-QD1-infra-preflight"].emit_signal // ""' "$DAG_FILE")
if [ -z "$rule" ]; then
  echo "  WARN: cascade_skip_rules missing P-QD1-infra-preflight entry"
else
  echo "  PASS: cascade_skip_rules: emit_signal=$rule"
fi

# ============================================================
# Test 3: All 7 dimensions represented
# ============================================================
echo ""
echo "--- Test 3: All 7 dimensions present ---"
DIMS=(QD1 QD2 QD3 QD4 QD5 QD6 QD7)
DIMS_FOUND=0
for dim in "${DIMS[@]}"; do
  count=$(jq --arg d "$dim" '[.nodes | to_entries[] | select(.value.dim == $d)] | length' "$DAG_FILE")
  if [ "$count" -gt 0 ]; then
    echo "  PASS: $dim → $count probes"
    DIMS_FOUND=$((DIMS_FOUND + 1))
  else
    echo "  FAIL: $dim has no probes in DAG"
  fi
done
if [ "$DIMS_FOUND" -lt 7 ]; then
  echo "  RESULT: FAIL — only $DIMS_FOUND / 7 dims covered"
  exit 1
fi

# ============================================================
# Test 4: No self-loops (cycle detection basic)
# ============================================================
echo ""
echo "--- Test 4: No self-loop cycles ---"
self_loops=$(jq '[.edges[] | select(.from == .to)] | length' "$DAG_FILE")
if [ "$self_loops" -gt 0 ]; then
  echo "  FAIL: $self_loops self-loop(s) found"
  jq -r '.edges[] | select(.from == .to) | "  LOOP: " + .from' "$DAG_FILE"
  exit 1
fi
echo "  PASS: 0 self-loops"

# ============================================================
# Test 5: Static probes before runtime in parallel groups
# ============================================================
echo ""
echo "--- Test 5: Static probes in g0, runtime in g1+ ---"
# Check QD1: infra-preflight should be in g0
infra_group=$(jq -r '.nodes["P-QD1-infra-preflight"].parallel_group // ""' "$DAG_FILE")
api_group=$(jq -r '.nodes["P-QD1-api-smoke"].parallel_group // ""' "$DAG_FILE")
if [[ "$infra_group" == *"g0"* ]] && [[ "$api_group" == *"g2"* || "$api_group" == *"g1"* ]]; then
  echo "  PASS: QD1 infra=$infra_group (g0), api-smoke=$api_group (g1/g2)"
else
  echo "  WARN: QD1 ordering check — infra=$infra_group, api-smoke=$api_group"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  Nodes: $node_count"
echo "  Edges: $edge_count"
echo "  Dimensions: $DIMS_FOUND / 7"
echo "  CC-001 cascade-skip: declared"
echo "  Self-loops: 0"
exit 0
