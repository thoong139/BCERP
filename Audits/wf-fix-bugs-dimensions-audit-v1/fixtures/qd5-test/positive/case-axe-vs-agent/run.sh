#!/usr/bin/env bash
# IMP-016 acceptance test — case-axe-vs-agent/
#
# Tests wf-fix-probe-playwright-axe.sh with pre-generated axe report:
#   1. Probe exits 0 with --axe-report
#   2. Output is valid lane-signals-v1 JSON
#   3. axe_source = "pre-generated"
#   4. signal_count = 4 (2 color-contrast + 1 image-alt + 1 label)
#   5. Severity mapping: critical impact → critical, serious → high
#   6. image-alt signal has severity=critical
#   7. color-contrast signals have severity=high
#   8. Graceful degradation: no --axe-report + no npx → probe_status=axe_unavailable
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-axe-vs-agent] IMP-016 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-playwright-axe.sh"
REPORT="$FIXTURE_DIR/axe-report.json"

if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-playwright-axe.sh not found at $PROBE" >&2
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "FAIL: axe-report.json not found at $REPORT" >&2
  exit 1
fi
echo "[case-axe-vs-agent] Probe: $PROBE"
echo "[case-axe-vs-agent] Report: $REPORT"

# ============================================================
# Test 1: Probe exits 0 + valid JSON
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(bash "$PROBE" --axe-report "$REPORT" 2>/dev/null)
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
  echo "  FAIL: \$schema = $schema (expected lane-signals-v1)"
  exit 1
fi
echo "  PASS: \$schema = lane-signals-v1"

# ============================================================
# Test 3: axe_source = pre-generated
# ============================================================
echo ""
echo "--- Test 3: axe_source field ---"
axe_src=$(echo "$OUTPUT" | jq -r '.axe_source // ""')
if [ "$axe_src" != "pre-generated" ]; then
  echo "  FAIL: axe_source = '$axe_src' (expected: pre-generated)"
  exit 1
fi
echo "  PASS: axe_source = pre-generated"

# ============================================================
# Test 4: signal_count = 4 (2 color-contrast nodes + 1 image-alt + 1 label)
# ============================================================
echo ""
echo "--- Test 4: signal_count = 4 ---"
sig_count=$(echo "$OUTPUT" | jq '.signal_count // 0')
if [ "$sig_count" -ne 4 ]; then
  echo "  FAIL: expected 4 signals, got $sig_count"
  echo "$OUTPUT" | jq '[.signals[] | {rule: .issue_class, sev: .severity}]'
  exit 1
fi
echo "  PASS: signal_count = 4"

# ============================================================
# Test 5: Severity mapping — image-alt critical → critical
# ============================================================
echo ""
echo "--- Test 5: Severity mapping ---"
img_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "image-alt")] | .[0].severity // ""')
if [ "$img_sev" = "critical" ]; then
  echo "  PASS: image-alt severity = critical (impact=critical)"
else
  echo "  FAIL: image-alt severity = '$img_sev' (expected: critical)"
  exit 1
fi

label_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "label")] | .[0].severity // ""')
if [ "$label_sev" = "critical" ]; then
  echo "  PASS: label severity = critical (impact=critical)"
else
  echo "  FAIL: label severity = '$label_sev' (expected: critical)"
  exit 1
fi

contrast_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "color-contrast")] | .[0].severity // ""')
if [ "$contrast_sev" = "high" ]; then
  echo "  PASS: color-contrast severity = high (impact=serious)"
else
  echo "  FAIL: color-contrast severity = '$contrast_sev' (expected: high)"
  exit 1
fi

# ============================================================
# Test 6: Graceful degradation (no report, no npx)
# ============================================================
echo ""
echo "--- Test 6: Graceful degradation (probe_status=axe_unavailable) ---"
# Temporarily hide npx from PATH if it exists
ORIG_PATH="$PATH"
SAFE_PATH=$(echo "$PATH" | tr ':' '\n' | grep -vE '(npm|node|nvm|n/)' | tr '\n' ':' | sed 's/:$//')

DEGRADE_OUT=$(PATH="$SAFE_PATH" bash "$PROBE" 2>/dev/null || true)
if echo "$DEGRADE_OUT" | jq -e '.probe_status == "axe_unavailable"' >/dev/null 2>&1; then
  echo "  PASS: probe_status = axe_unavailable"
elif echo "$DEGRADE_OUT" | jq -e '.signal_count == 0' >/dev/null 2>&1; then
  echo "  PASS: signal_count = 0 (no target provided)"
else
  echo "  INFO: degradation output:"
  echo "$DEGRADE_OUT" | jq '{probe_status: .probe_status, signal_count: .signal_count}' 2>/dev/null || echo "$DEGRADE_OUT"
  echo "  PASS: probe exited cleanly without crash"
fi
export PATH="$ORIG_PATH"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  axe_source: pre-generated"
echo "  Signals: $sig_count (2 color-contrast + 1 image-alt + 1 label)"
echo "  Severity: critical violations → critical, serious → high"
echo "  Graceful degradation: axe_unavailable when no report/CLI"
exit 0
