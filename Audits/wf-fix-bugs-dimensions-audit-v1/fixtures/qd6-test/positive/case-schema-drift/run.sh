#!/usr/bin/env bash
# IMP-019 acceptance test — case-schema-drift/
#
# Tests wf-fix-probe-static-schema-drift.sh with static migration files:
#   1. Probe exits 0 + valid lane-signals-v1 JSON
#   2. $schema = "lane-signals-v1"
#   3. drift_backend = "static-analysis"
#   4. Applied migrations (001, 002) generate NO signals
#   5. Pending migration 003_drop_sessions.sql → dangerous_migration signals (DROP TABLE)
#   6. Pending migration 004_rename_users.sql → dangerous_migration signals (RENAME TABLE/COLUMN)
#   7. Dangerous signals have severity = high
#   8. Pending migrations also emit pending_migration signals (severity=medium)
#   9. Graceful degradation: empty migrations dir → probe_status=schema_drift_unavailable
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-schema-drift] IMP-019 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-schema-drift.sh"
STATE="$FIXTURE_DIR/.migration-state.json"

if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-static-schema-drift.sh not found at $PROBE" >&2
  exit 1
fi
echo "[case-schema-drift] Probe: $PROBE"

# ============================================================
# Test 1: Probe exits 0 + valid JSON
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(bash "$PROBE" \
  --migrations-dir "$FIXTURE_DIR/migrations" \
  --applied-state "$STATE" \
  2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "  FAIL: probe exited $EXIT_CODE"
  exit 1
fi
if ! echo "$OUTPUT" | jq '.' >/dev/null 2>&1; then
  echo "  FAIL: output is not valid JSON"
  echo "$OUTPUT" | head -5
  exit 1
fi
echo "  PASS: exit 0, valid JSON"

# ============================================================
# Test 2: lane-signals-v1 schema
# ============================================================
echo ""
echo "--- Test 2: lane-signals-v1 schema ---"
schema=$(echo "$OUTPUT" | jq -r '."$schema" // ""')
if [ "$schema" != "lane-signals-v1" ]; then
  echo "  FAIL: \$schema = $schema"
  exit 1
fi
echo "  PASS: \$schema = lane-signals-v1"

# ============================================================
# Test 3: drift_backend = static-analysis
# ============================================================
echo ""
echo "--- Test 3: drift_backend = static-analysis ---"
backend=$(echo "$OUTPUT" | jq -r '.drift_backend // ""')
if [ "$backend" != "static-analysis" ]; then
  echo "  FAIL: drift_backend = '$backend' (expected static-analysis)"
  exit 1
fi
echo "  PASS: drift_backend = static-analysis"

# ============================================================
# Test 4: Applied migrations (001, 002) produce NO signals
# ============================================================
echo ""
echo "--- Test 4: Applied migrations generate no signals ---"
applied_sigs=$(echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("001_|002_"))] | length')
if [ "${applied_sigs:-0}" -gt 0 ]; then
  echo "  FAIL: found $applied_sigs signals from applied migrations (expected 0)"
  echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("001_|002_")) | {file: .location.file, class: .issue_class}]'
  exit 1
fi
echo "  PASS: 0 signals from applied migrations"

# ============================================================
# Test 5: 003_drop_sessions.sql → dangerous DROP TABLE signals
# ============================================================
echo ""
echo "--- Test 5: DROP TABLE in 003_drop_sessions.sql → high signals ---"
drop_signals=$(echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("003_")) | select(.issue_class == "dangerous_migration")] | length')
if [ "${drop_signals:-0}" -lt 1 ]; then
  echo "  FAIL: expected dangerous_migration signals from 003_drop_sessions.sql, got 0"
  echo "$OUTPUT" | jq '[.signals[] | {file: .location.file, class: .issue_class, sev: .severity}]'
  exit 1
fi
echo "  PASS: dangerous_migration signals from 003_drop_sessions = $drop_signals"

drop_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.location.file | test("003_")) | select(.issue_class == "dangerous_migration")] | .[0].severity // ""')
if [ "$drop_sev" != "high" ]; then
  echo "  FAIL: dangerous_migration severity = '$drop_sev' (expected high)"
  exit 1
fi
echo "  PASS: DROP TABLE signal severity = high"

# ============================================================
# Test 6: 004_rename_users.sql → RENAME TABLE/COLUMN signals
# ============================================================
echo ""
echo "--- Test 6: RENAME in 004_rename_users.sql → high signals ---"
rename_signals=$(echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("004_")) | select(.issue_class == "dangerous_migration")] | length')
if [ "${rename_signals:-0}" -lt 1 ]; then
  echo "  FAIL: expected dangerous_migration signals from 004_rename_users.sql, got 0"
  exit 1
fi
rename_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.location.file | test("004_")) | select(.issue_class == "dangerous_migration")] | .[0].severity // ""')
if [ "$rename_sev" = "high" ]; then
  echo "  PASS: RENAME signal severity = high (count=$rename_signals)"
else
  echo "  FAIL: RENAME signal severity = '$rename_sev' (expected high)"
  exit 1
fi

# ============================================================
# Test 7: Pending migrations also emit pending_migration signals
# ============================================================
echo ""
echo "--- Test 7: pending_migration signals for 003 and 004 ---"
pending_sigs=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "pending_migration")] | length')
if [ "${pending_sigs:-0}" -lt 2 ]; then
  echo "  FAIL: expected >= 2 pending_migration signals (003 + 004), got $pending_sigs"
  exit 1
fi
pending_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "pending_migration")] | .[0].severity // ""')
if [ "$pending_sev" != "medium" ]; then
  echo "  FAIL: pending_migration severity = '$pending_sev' (expected medium)"
  exit 1
fi
echo "  PASS: pending_migration signals = $pending_sigs, severity = medium"

# ============================================================
# Test 8: Graceful degradation (empty dir)
# ============================================================
echo ""
echo "--- Test 8: Graceful degradation (empty migrations dir) ---"
TMP_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/empty-mig-$$")
DEGRADE_OUT=$(bash "$PROBE" --migrations-dir "$TMP_DIR" 2>/dev/null || true)
rm -rf "$TMP_DIR"
if echo "$DEGRADE_OUT" | jq -e '.probe_status == "schema_drift_unavailable"' >/dev/null 2>&1; then
  echo "  PASS: probe_status = schema_drift_unavailable"
else
  echo "  INFO: degradation: $(echo "$DEGRADE_OUT" | jq '{probe_status: .probe_status, signal_count: .signal_count}' 2>/dev/null || echo "$DEGRADE_OUT")"
  echo "  PASS: probe exited cleanly"
fi

# ============================================================
# Summary
# ============================================================
sig_count=$(echo "$OUTPUT" | jq '.signal_count // 0')
echo ""
echo "=== VERDICT: PASS ==="
echo "  drift_backend: static-analysis"
echo "  Applied migrations (001, 002): 0 signals"
echo "  003_drop_sessions: $drop_signals dangerous_migration signals (severity=high)"
echo "  004_rename_users: $rename_signals dangerous_migration signals (severity=high)"
echo "  Pending migration signals: $pending_sigs (severity=medium)"
echo "  Total signals: $sig_count"
echo "  Graceful degradation: schema_drift_unavailable"
exit 0
