#!/usr/bin/env bash
# IMP-024 acceptance test — case-drop-table-cdg/ (Phase 1)
#
# Tests CDG-DELETE-DATA canonical pattern in wf-fix-probe-static-data.sh:
#   1. P-QD6-migration-integrity exits 0 on valid source
#   2. Emits signal for DROP TABLE with cdg_flags=["CDG-DELETE-DATA"]
#   3. Signal severity = critical for DROP TABLE
#   4. Signal count ≥ 1 for source with DROP TABLE
#   5. cdg_flags is array containing "CDG-DELETE-DATA"
#   6. dimension.json P-QD6-migration-integrity has cdg=true
#   7. dimension.json P-QD6-migration-integrity has cdg_triggers containing CDG-DELETE-DATA
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-drop-table-cdg] IMP-024 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-data.sh"
DIM_JSON="$REPO_ROOT/.claude/skills/workflow/wf-fix-data/dimension.json"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: wf-fix-probe-static-data.sh not found" >&2; exit 1
fi
if [ ! -f "$DIM_JSON" ]; then
  echo "FAIL: wf-fix-data/dimension.json not found" >&2; exit 1
fi

# Copy migrations to temp dir (avoid fixtures/ in path triggering EXCLUDE)
TMP_SRC=$(mktemp -d 2>/dev/null || echo "/tmp/qd6-cdg-src-$$")
cleanup() { rm -rf "$TMP_SRC"; }
trap cleanup EXIT
cp -r "$FIXTURE_DIR/migrations/." "$TMP_SRC/"

# ============================================================
# Test 1: P-QD6-migration-integrity exits 0
# ============================================================
echo ""
echo "--- Test 1: P-QD6-migration-integrity exits 0 ---"
out=$(bash "$SCRIPT" --probe P-QD6-migration-integrity --source-dir "$TMP_SRC" 2>/dev/null)
if echo "$out" | jq '.' >/dev/null 2>&1; then
  echo "  PASS: exit 0 + valid JSON"
else
  echo "  FAIL: non-zero exit or invalid JSON"
  exit 1
fi

# ============================================================
# Test 2: emits signal with cdg_flags=["CDG-DELETE-DATA"]
# ============================================================
echo ""
echo "--- Test 2: emits CDG-DELETE-DATA signal for DROP TABLE ---"
cdg_sigs=$(echo "$out" | jq '[.signals[] | select(.cdg_flags[]? == "CDG-DELETE-DATA")] | length')
if [ "$cdg_sigs" -ge 1 ]; then
  echo "  PASS: $cdg_sigs signal(s) with cdg_flags=CDG-DELETE-DATA"
else
  echo "  FAIL: no signals with cdg_flags=CDG-DELETE-DATA (got $cdg_sigs)"
  echo "  Output: $(echo "$out" | jq '.signals')"
  exit 1
fi

# ============================================================
# Test 3: Signal severity = critical for DROP TABLE
# ============================================================
echo ""
echo "--- Test 3: DROP TABLE signal severity = critical ---"
sev=$(echo "$out" | jq -r '[.signals[] | select(.cdg_flags[]? == "CDG-DELETE-DATA")] | .[0].severity // ""')
if [ "$sev" = "critical" ]; then
  echo "  PASS: severity = critical"
else
  echo "  FAIL: severity = '$sev' (expected critical)"
  exit 1
fi

# ============================================================
# Test 4: signal count ≥ 1
# ============================================================
echo ""
echo "--- Test 4: signal count ≥ 1 ---"
total=$(echo "$out" | jq '.signals | length')
if [ "$total" -ge 1 ]; then
  echo "  PASS: $total signal(s) emitted"
else
  echo "  FAIL: 0 signals (expected ≥1)"
  exit 1
fi

# ============================================================
# Test 5: cdg_flags array contains CDG-DELETE-DATA
# ============================================================
echo ""
echo "--- Test 5: cdg_flags array contains CDG-DELETE-DATA ---"
flag_count=$(echo "$out" | jq '[.signals[0].cdg_flags[]? | select(. == "CDG-DELETE-DATA")] | length')
if [ "$flag_count" -ge 1 ]; then
  echo "  PASS: cdg_flags contains CDG-DELETE-DATA"
else
  flags=$(echo "$out" | jq -r '.signals[0].cdg_flags // "null"')
  echo "  FAIL: cdg_flags = $flags (CDG-DELETE-DATA not found)"
  exit 1
fi

# ============================================================
# Test 6: dimension.json P-QD6-migration-integrity has cdg=true
# ============================================================
echo ""
echo "--- Test 6: dim.json P-QD6-migration-integrity cdg=true ---"
probe_cdg=$(jq -r '.probes[] | select(.id == "P-QD6-migration-integrity") | .cdg' "$DIM_JSON")
if [ "$probe_cdg" = "true" ]; then
  echo "  PASS: P-QD6-migration-integrity cdg=true"
else
  echo "  FAIL: cdg = '$probe_cdg' (expected true)"
  exit 1
fi

# ============================================================
# Test 7: dimension.json cdg_triggers contains CDG-DELETE-DATA
# ============================================================
echo ""
echo "--- Test 7: dim.json cdg_triggers contains CDG-DELETE-DATA ---"
trigger_count=$(jq '[.probes[] | select(.id == "P-QD6-migration-integrity") | .cdg_triggers[]? | select(. == "CDG-DELETE-DATA")] | length' "$DIM_JSON")
if [ "$trigger_count" -ge 1 ]; then
  echo "  PASS: cdg_triggers contains CDG-DELETE-DATA"
else
  triggers=$(jq -r '[.probes[] | select(.id == "P-QD6-migration-integrity") | .cdg_triggers // []] | .[0] // "null"' "$DIM_JSON")
  echo "  FAIL: cdg_triggers = $triggers (CDG-DELETE-DATA missing)"
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  P-QD6-migration-integrity dispatch: PASS"
echo "  CDG-DELETE-DATA cdg_flags: PASS"
echo "  Signal severity=critical: PASS"
echo "  dim.json cdg=true + cdg_triggers: PASS"
exit 0
