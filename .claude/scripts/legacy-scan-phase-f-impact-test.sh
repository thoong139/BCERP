#!/usr/bin/env bash
# Phase F F.2 smoke test — verify impact-graph.json sinh ra tu session dir
# chay on cac synthesis_mode canonical, va dam bao schema contract.
#
# Usage:
#   bash .claude/scripts/legacy-scan-phase-f-impact-test.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed
#   2 — environment missing (python / jq)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_ROOT="$REPO_ROOT/.claude/skills/workflow/_shared"

# Cross-platform path conversion cho Python (Windows Git Bash -> Windows path)
if command -v cygpath >/dev/null 2>&1; then
  SHARED_ROOT_PY=$(cygpath -w "$SHARED_ROOT")
else
  SHARED_ROOT_PY="$SHARED_ROOT"
fi

command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || {
  echo "[ERR] python khong co trong PATH" >&2; exit 2;
}
command -v jq >/dev/null 2>&1 || { echo "[ERR] jq khong co trong PATH" >&2; exit 2; }

PY=$(command -v python3 || command -v python)

TMP=$(mktemp -d -t wf-legacy-scan-phase-f-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

SESSION="$TMP/sessions/scan-demo"
mkdir -p "$SESSION/inventory" "$SESSION/classified" "$SESSION/extracted"

if command -v cygpath >/dev/null 2>&1; then
  SESSION_PY=$(cygpath -w "$SESSION")
else
  SESSION_PY="$SESSION"
fi

# --- Fixture data ---------------------------------------------------------

cat > "$SESSION/inventory/dependency-graph.json" <<'JSON'
{
  "edges": [
    {"from": "src/crm/customer.ts", "to": "src/finance/ar/invoice.ts"},
    {"from": "src/crm/customer.ts", "to": "src/finance/ar/invoice.ts"},
    {"from": "src/reporting/sales.ts", "to": "src/crm/customer.ts"},
    {"from": "src/finance/ar/invoice.ts", "to": "src/crm/customer.ts"}
  ]
}
JSON

cat > "$SESSION/inventory/schema.json" <<'JSON'
{
  "foreign_keys": [
    {"from_table": "finance", "to_table": "crm", "column": "customer_id"}
  ]
}
JSON

cat > "$SESSION/classified/modules-summary.json" <<'JSON'
{
  "modules": [
    {"id": "crm", "files_count": 12, "domain": "sales", "entities": ["customer"]},
    {"id": "finance", "files_count": 9, "domain": "finance", "entity_refs": ["customer"]},
    {"id": "reporting", "files_count": 4, "domain": "bi"}
  ]
}
JSON

cat > "$SESSION/extracted/modules-summary.json" <<'JSON'
{
  "modules": {
    "crm": {
      "features": [{"FEAT-ID": "FEAT-CRM-CUST-001"}, {"FEAT-ID": "FEAT-CRM-CUST-002"}],
      "description": "Quan ly thong tin khach hang."
    },
    "finance": {
      "features": [{"FEAT-ID": "FEAT-FIN-AR-001"}],
      "description": "Lien ket AR voi khach hang FEAT-CRM-CUST-001 de sinh hoa don."
    },
    "reporting": {
      "features": [{"FEAT-ID": "FEAT-RPT-SALES-001"}],
      "description": "Bao cao doanh thu theo khach hang (uses FEAT-CRM-CUST-002)."
    }
  }
}
JSON

# --- Build impact graphs per synthesis mode ------------------------------

OUT_BASE="$TMP/out"
mkdir -p "$OUT_BASE"

if command -v cygpath >/dev/null 2>&1; then
  OUT_BASE_PY=$(cygpath -w "$OUT_BASE")
else
  OUT_BASE_PY="$OUT_BASE"
fi

PY_RUN() {
  local mode="$1"
  "$PY" - <<PY
import sys
sys.path.insert(0, r"$SHARED_ROOT_PY")
from ips import impact_graph_builder as igb
payload = igb.build_from_session_dir(r"$SESSION_PY", synthesis_mode="$mode")
igb.write_impact_graph(payload, r"$OUT_BASE_PY/impact-$mode.json")
PY
}

MODES=("condensed" "full" "full+insights" "full+divergence")
for m in "${MODES[@]}"; do
  PY_RUN "$m"
done

fail=0

assert_jq() {
  local file="$1" ; local expr="$2" ; local msg="$3"
  if ! jq -e "$expr" "$file" >/dev/null; then
    echo "  [FAIL] $msg ($file)" >&2
    fail=$((fail+1))
  else
    echo "  [OK]   $msg"
  fi
}

echo "[Case 1] condensed mode → nodes co, edges=[]"
F="$OUT_BASE/impact-condensed.json"
assert_jq "$F" '."$schema" == "impact-graph-v1"' "schema=impact-graph-v1"
assert_jq "$F" '.synthesis_mode == "condensed"' "mode=condensed"
assert_jq "$F" '.edges | length == 0' "edges rong"
assert_jq "$F" '.nodes | length == 3' "nodes = 3"

echo "[Case 2] full mode → giu code_import + data_dependency"
F="$OUT_BASE/impact-full.json"
assert_jq "$F" '.synthesis_mode == "full"' "mode=full"
assert_jq "$F" '.edges | length > 0' "co edges"
assert_jq "$F" '[.edges[].relation] | all(. == "code_import" or . == "data_dependency")' "chi 2 loai relation"
assert_jq "$F" '[.edges[].relation] | any(. == "code_import")' "co code_import"
assert_jq "$F" '[.edges[].relation] | any(. == "data_dependency")' "co data_dependency"

echo "[Case 3] full+insights mode → co >=3 relation types"
F="$OUT_BASE/impact-full+insights.json"
assert_jq "$F" '.synthesis_mode == "full+insights"' "mode=full+insights"
assert_jq "$F" '[.edges[].relation] | unique | length >= 3' ">=3 loai relation"

echo "[Case 4] full+divergence mode → co circular + req_cross_ref"
F="$OUT_BASE/impact-full+divergence.json"
assert_jq "$F" '.synthesis_mode == "full+divergence"' "mode=full+divergence"
assert_jq "$F" '.circular_dependencies | length > 0' "co circular (crm <-> finance)"
assert_jq "$F" '[.edges[].relation] | any(. == "req_cross_ref")' "co req_cross_ref"

echo "[Case 5] Schema canonical compliance — tat ca files"
for m in "${MODES[@]}"; do
  F="$OUT_BASE/impact-$m.json"
  assert_jq "$F" '.nodes | type == "array"' "[$m] nodes array"
  assert_jq "$F" '.edges | type == "array"' "[$m] edges array"
  assert_jq "$F" '.summary.total_nodes != null' "[$m] summary.total_nodes"
  assert_jq "$F" '.relation_types_allowed | length == 6' "[$m] 6 relation types allowed"
  assert_jq "$F" '[.edges[].relation] - (.relation_types_allowed // []) | length == 0' "[$m] edges dung allow-list"
done

echo ""
if [ "$fail" -eq 0 ]; then
  echo "Phase F F.2 smoke test PASSED — 4 synthesis modes + schema canonical."
  exit 0
else
  echo "Phase F F.2 smoke test FAILED — $fail check(s) khong pass." >&2
  exit 1
fi
