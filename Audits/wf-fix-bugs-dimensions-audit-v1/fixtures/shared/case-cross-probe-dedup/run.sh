#!/usr/bin/env bash
# IMP-023 acceptance test — case-cross-probe-dedup/
#
# Tests cross-probe dedup namespace key in wf-fix-common.sh:
#   1. dedup_signals() function is available after sourcing wf-fix-common.sh
#   2. Two signals at same (file, line, issue_class) from different probes → 1 signal
#   3. Deduplicated signal keeps highest severity (critical > high)
#   4. dedup_sources contains both probe IDs
#   5. Evidence array has a dedup entry with dedup_namespace_key
#   6. Three signals at same location → 1 signal (3× inflation → 1×)
#   7. Two signals at different locations → NOT deduplicated (2 signals remain)
#   8. make_dedup_namespace_key() generates consistent canonical keys
#
# VERDICT: PASS if all 8 assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-cross-probe-dedup] IMP-023 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

COMMON="$REPO_ROOT/.claude/scripts/wf-fix-common.sh"

if [ ! -f "$COMMON" ]; then
  echo "FAIL: wf-fix-common.sh not found at $COMMON" >&2; exit 1
fi

# Source common helpers
# shellcheck source=/dev/null
source "$COMMON"

# ============================================================
# Test 1: dedup_signals function available after sourcing
# ============================================================
echo ""
echo "--- Test 1: dedup_signals() is available ---"
if declare -f dedup_signals >/dev/null 2>&1; then
  echo "  PASS: dedup_signals is a defined function"
else
  echo "  FAIL: dedup_signals not found after sourcing wf-fix-common.sh"
  exit 1
fi

# ============================================================
# Build test signals using jq
# ============================================================

# SIG_A: QD1/orphan-ui-detect HIGH at src/nav.tsx:42 (missing-label)
SIG_A=$(jq -nc '{
  "$schema": "signal-v2",
  dimension_id: "QD1",
  probe_id: "P-QD1-orphan-ui-detect",
  probe_version: "v1.0",
  severity: "high",
  title: "Orphan UI element without label",
  issue_class: "missing-label",
  location: { file: "src/nav.tsx", line: 42 },
  evidence: [{ type: "code", path: "src/nav.tsx", description: "Line 42" }],
  cdg_flags: [],
  fingerprint: "sha256:aaa",
  remediation: { suggested_action: "add aria-label" }
}')

# SIG_B: QD2/calculation-check CRITICAL at same src/nav.tsx:42 (missing-label)
SIG_B=$(jq -nc '{
  "$schema": "signal-v2",
  dimension_id: "QD2",
  probe_id: "P-QD2-calculation-check",
  probe_version: "v1.0",
  severity: "critical",
  title: "Calculation missing label validation",
  issue_class: "missing-label",
  location: { file: "src/nav.tsx", line: 42 },
  evidence: [{ type: "code", path: "src/nav.tsx", description: "Line 42" }],
  cdg_flags: [],
  fingerprint: "sha256:bbb",
  remediation: { suggested_action: "add validation" }
}')

# SIG_C: QD5/label-consistency MEDIUM at same src/nav.tsx:42 (missing-label)
SIG_C=$(jq -nc '{
  "$schema": "signal-v2",
  dimension_id: "QD5",
  probe_id: "P-QD5-label-consistency",
  probe_version: "v1.0",
  severity: "medium",
  title: "Label consistency issue",
  issue_class: "missing-label",
  location: { file: "src/nav.tsx", line: 42 },
  evidence: [{ type: "code", path: "src/nav.tsx", description: "Line 42" }],
  cdg_flags: [],
  fingerprint: "sha256:ccc",
  remediation: { suggested_action: "fix label" }
}')

# SIG_D: different location src/service.ts:15 (n-plus-1)
SIG_D=$(jq -nc '{
  "$schema": "signal-v2",
  dimension_id: "QD4",
  probe_id: "P-QD4-db-query-analysis",
  probe_version: "v1.0",
  severity: "high",
  title: "N+1 query detected",
  issue_class: "n-plus-1",
  location: { file: "src/service.ts", line: 15 },
  evidence: [{ type: "code", path: "src/service.ts", description: "Line 15" }],
  cdg_flags: [],
  fingerprint: "sha256:ddd",
  remediation: { suggested_action: "add DataLoader" }
}')

# ============================================================
# Test 2: Two signals same (file, line, issue_class) → 1 signal
# ============================================================
echo ""
echo "--- Test 2: two signals same location → 1 signal ---"
TWO_SIGS=$(jq -nc --argjson a "$SIG_A" --argjson b "$SIG_B" '[$a, $b]')
deduped2=$(dedup_signals "$TWO_SIGS")
count2=$(echo "$deduped2" | jq 'length')
if [ "$count2" -eq 1 ]; then
  echo "  PASS: 2 signals deduped to $count2"
else
  echo "  FAIL: expected 1, got $count2"
  echo "  Output: $(echo "$deduped2" | jq '.')"
  exit 1
fi

# ============================================================
# Test 3: Keeps highest severity (critical wins over high)
# ============================================================
echo ""
echo "--- Test 3: deduped signal has highest severity (critical) ---"
sev2=$(echo "$deduped2" | jq -r '.[0].severity')
if [ "$sev2" = "critical" ]; then
  echo "  PASS: severity = critical"
else
  echo "  FAIL: severity = '$sev2' (expected critical)"
  exit 1
fi

# ============================================================
# Test 4: dedup_sources contains both probe IDs
# ============================================================
echo ""
echo "--- Test 4: dedup_sources contains both probe IDs ---"
src_count=$(echo "$deduped2" | jq '[.[] | .dedup_sources // [] | .[]] | length')
has_qd1=$(echo "$deduped2" | jq -r '[.[] | .dedup_sources // [] | .[]] | any(. == "P-QD1-orphan-ui-detect")' 2>/dev/null || echo "false")
has_qd2=$(echo "$deduped2" | jq -r '[.[] | .dedup_sources // [] | .[]] | any(. == "P-QD2-calculation-check")' 2>/dev/null || echo "false")
if [ "$has_qd1" = "true" ] && [ "$has_qd2" = "true" ]; then
  echo "  PASS: dedup_sources contains P-QD1-orphan-ui-detect and P-QD2-calculation-check"
else
  echo "  FAIL: has_qd1=$has_qd1, has_qd2=$has_qd2 (dedup_sources=$(echo "$deduped2" | jq '.[0].dedup_sources'))"
  exit 1
fi

# ============================================================
# Test 5: Evidence has dedup entry with dedup_namespace_key
# ============================================================
echo ""
echo "--- Test 5: evidence has dedup entry with dedup_namespace_key ---"
dedup_entry_count=$(echo "$deduped2" | jq '[.[0].evidence[] | select(.type == "dedup")] | length')
has_ns_key=$(echo "$deduped2" | jq -r '[.[0].evidence[] | select(.type == "dedup" and .dedup_namespace_key != null)] | length > 0')
if [ "$dedup_entry_count" -ge 1 ] && [ "$has_ns_key" = "true" ]; then
  ns_key=$(echo "$deduped2" | jq -r '[.[0].evidence[] | select(.type == "dedup")] | .[0].dedup_namespace_key')
  echo "  PASS: dedup evidence entry present, dedup_namespace_key = $ns_key"
else
  echo "  FAIL: dedup_entry_count=$dedup_entry_count, has_ns_key=$has_ns_key"
  echo "  Evidence: $(echo "$deduped2" | jq '.[0].evidence')"
  exit 1
fi

# ============================================================
# Test 6: Three signals at same location → 1 signal (3× → 1×)
# ============================================================
echo ""
echo "--- Test 6: three signals same location → 1 signal ---"
THREE_SIGS=$(jq -nc --argjson a "$SIG_A" --argjson b "$SIG_B" --argjson c "$SIG_C" '[$a, $b, $c]')
deduped3=$(dedup_signals "$THREE_SIGS")
count3=$(echo "$deduped3" | jq 'length')
if [ "$count3" -eq 1 ]; then
  echo "  PASS: 3 signals deduped to $count3"
else
  echo "  FAIL: expected 1, got $count3"
  exit 1
fi
# Also verify dedup_sources has all 3
src3=$(echo "$deduped3" | jq '.[0].dedup_sources | length')
if [ "$src3" -eq 3 ]; then
  echo "  PASS: dedup_sources has $src3 probes"
else
  echo "  FAIL: dedup_sources has $src3 probes (expected 3)"
  exit 1
fi

# ============================================================
# Test 7: Different locations → NOT deduplicated (2 signals)
# ============================================================
echo ""
echo "--- Test 7: different locations → NOT deduplicated ---"
DIFF_SIGS=$(jq -nc --argjson a "$SIG_A" --argjson d "$SIG_D" '[$a, $d]')
deduped_diff=$(dedup_signals "$DIFF_SIGS")
count_diff=$(echo "$deduped_diff" | jq 'length')
if [ "$count_diff" -eq 2 ]; then
  echo "  PASS: 2 signals at different locations remain 2"
else
  echo "  FAIL: expected 2, got $count_diff"
  exit 1
fi

# ============================================================
# Test 8: make_dedup_namespace_key() generates consistent keys
# ============================================================
echo ""
echo "--- Test 8: make_dedup_namespace_key() consistent output ---"
key1=$(make_dedup_namespace_key "src/nav.tsx" "42" "missing-label")
key2=$(make_dedup_namespace_key "src/nav.tsx" "42" "missing-label")
key3=$(make_dedup_namespace_key "src/service.ts" "15" "n-plus-1")
if [ "$key1" = "$key2" ] && [ "$key1" != "$key3" ]; then
  echo "  PASS: consistent key='$key1', different location='$key3'"
else
  echo "  FAIL: key1='$key1', key2='$key2', key3='$key3'"
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  dedup_signals available: PASS"
echo "  2 signals same loc → 1: PASS"
echo "  highest severity kept: PASS"
echo "  dedup_sources merged: PASS"
echo "  dedup_namespace_key in evidence: PASS"
echo "  3 signals same loc → 1: PASS"
echo "  different locations not deduped: PASS"
echo "  make_dedup_namespace_key consistent: PASS"
exit 0
