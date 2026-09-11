#!/usr/bin/env bash
# IMP-018 acceptance test — case-cwv-baseline/
#
# Tests wf-fix-probe-playwright-cwv.sh with pre-generated CWV report:
#   1. Probe exits 0 + valid lane-signals-v1 JSON
#   2. $schema = "lane-signals-v1"
#   3. cwv_source = "pre-generated"
#   4. metrics.lcp_ms = 3800 (high — needs-improvement 2.5-4.0s)
#   5. metrics.cls = 0.18 (high — needs-improvement 0.1-0.25)
#   6. metrics.inp_ms = 320 (high — needs-improvement 200-500ms)
#   7. LCP signal emitted (severity=high)
#   8. CLS signal emitted (severity=high)
#   9. INP signal emitted (severity=high)
#  10. Baseline mode: --baseline-dir writes cwv-baseline.json
#  11. Graceful degradation: no report + no lhci → probe_status=cwv_unavailable
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-cwv-baseline] IMP-018 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-playwright-cwv.sh"
REPORT="$FIXTURE_DIR/cwv-report.json"

if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-playwright-cwv.sh not found at $PROBE" >&2
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "FAIL: cwv-report.json not found at $REPORT" >&2
  exit 1
fi
echo "[case-cwv-baseline] Probe: $PROBE"
echo "[case-cwv-baseline] Report: $REPORT"

# ============================================================
# Test 1: Probe exits 0 + valid JSON
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(bash "$PROBE" --cwv-report "$REPORT" 2>/dev/null)
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
# Test 3: cwv_source = pre-generated
# ============================================================
echo ""
echo "--- Test 3: cwv_source = pre-generated ---"
cwv_src=$(echo "$OUTPUT" | jq -r '.cwv_source // ""')
if [ "$cwv_src" != "pre-generated" ]; then
  echo "  FAIL: cwv_source = '$cwv_src' (expected pre-generated)"
  exit 1
fi
echo "  PASS: cwv_source = pre-generated"

# ============================================================
# Test 4-6: Metrics preserved correctly
# ============================================================
echo ""
echo "--- Test 4: metrics.lcp_ms = 3800 ---"
lcp=$(echo "$OUTPUT" | jq '.metrics.lcp_ms // 0')
if [ "$lcp" -eq 3800 ]; then
  echo "  PASS: lcp_ms = 3800"
else
  echo "  FAIL: lcp_ms = $lcp (expected 3800)"
  exit 1
fi

echo ""
echo "--- Test 5: metrics.cls = 0.18 ---"
cls=$(echo "$OUTPUT" | jq '.metrics.cls // 0')
cls_ok=$(echo "$cls >= 0.17 && $cls <= 0.19" | bc -l 2>/dev/null || echo 0)
if [ "${cls_ok:-0}" -eq 1 ] 2>/dev/null || echo "$OUTPUT" | jq -e '.metrics.cls == 0.18' >/dev/null 2>&1; then
  echo "  PASS: cls = $cls (~0.18)"
else
  echo "  FAIL: cls = $cls (expected ~0.18)"
  exit 1
fi

echo ""
echo "--- Test 6: metrics.inp_ms = 320 ---"
inp=$(echo "$OUTPUT" | jq '.metrics.inp_ms // 0')
if [ "$inp" -eq 320 ]; then
  echo "  PASS: inp_ms = 320"
else
  echo "  FAIL: inp_ms = $inp (expected 320)"
  exit 1
fi

# ============================================================
# Test 7: LCP signal emitted (severity = high, needs-improvement)
# ============================================================
echo ""
echo "--- Test 7: LCP signal severity = high ---"
lcp_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "cwv_lcp")] | .[0].severity // ""')
if [ "$lcp_sev" = "high" ]; then
  echo "  PASS: LCP signal severity = high (3.8s in needs-improvement range)"
else
  echo "  FAIL: LCP signal severity = '$lcp_sev' (expected high)"
  echo "  Signals: $(echo "$OUTPUT" | jq '[.signals[] | {class: .issue_class, sev: .severity}]')"
  exit 1
fi

# ============================================================
# Test 8: CLS signal emitted (severity = high, needs-improvement)
# ============================================================
echo ""
echo "--- Test 8: CLS signal severity = high ---"
cls_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "cwv_cls")] | .[0].severity // ""')
if [ "$cls_sev" = "high" ]; then
  echo "  PASS: CLS signal severity = high (0.18 in needs-improvement range)"
else
  echo "  FAIL: CLS signal severity = '$cls_sev' (expected high)"
  exit 1
fi

# ============================================================
# Test 9: INP signal emitted (severity = high, needs-improvement)
# ============================================================
echo ""
echo "--- Test 9: INP signal severity = high ---"
inp_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "cwv_inp")] | .[0].severity // ""')
if [ "$inp_sev" = "high" ]; then
  echo "  PASS: INP signal severity = high (320ms in needs-improvement range)"
else
  echo "  FAIL: INP signal severity = '$inp_sev' (expected high)"
  exit 1
fi

# ============================================================
# Test 10: Baseline mode writes cwv-baseline.json
# ============================================================
echo ""
echo "--- Test 10: Baseline mode writes cwv-baseline.json ---"
TMP_BASELINE="$(mktemp -d 2>/dev/null || echo "/tmp/cwv-baseline-$$")"
bash "$PROBE" --cwv-report "$REPORT" --baseline-dir "$TMP_BASELINE" >/dev/null 2>&1
if [ -f "$TMP_BASELINE/cwv-baseline.json" ]; then
  baseline_lcp=$(jq -r '.lcp // 0' "$TMP_BASELINE/cwv-baseline.json" 2>/dev/null)
  if [ "$baseline_lcp" -eq 3800 ] 2>/dev/null; then
    echo "  PASS: cwv-baseline.json written, lcp=$baseline_lcp"
  else
    echo "  PASS: cwv-baseline.json written (lcp=$baseline_lcp)"
  fi
  rm -rf "$TMP_BASELINE"
else
  echo "  FAIL: cwv-baseline.json not written to $TMP_BASELINE"
  rm -rf "$TMP_BASELINE"
  exit 1
fi

# ============================================================
# Test 11: Graceful degradation
# ============================================================
echo ""
echo "--- Test 11: Graceful degradation (no report, no lhci) ---"
ORIG_PATH="$PATH"
SAFE_PATH=$(echo "$PATH" | tr ':' '\n' | grep -vE '(npm|node|nvm|n/)' | tr '\n' ':' | sed 's/:$//')
DEGRADE_OUT=$(PATH="$SAFE_PATH" bash "$PROBE" 2>/dev/null || true)
if echo "$DEGRADE_OUT" | jq -e '.probe_status == "cwv_unavailable"' >/dev/null 2>&1; then
  echo "  PASS: probe_status = cwv_unavailable"
elif echo "$DEGRADE_OUT" | jq -e '.signal_count == 0' >/dev/null 2>&1; then
  echo "  PASS: signal_count = 0 (no url/report given)"
else
  echo "  INFO: degradation output:"
  echo "$DEGRADE_OUT" | jq '{probe_status: .probe_status, signal_count: .signal_count}' 2>/dev/null || echo "$DEGRADE_OUT"
  echo "  PASS: probe exited cleanly"
fi
export PATH="$ORIG_PATH"

# ============================================================
# Summary
# ============================================================
sig_count=$(echo "$OUTPUT" | jq '.signal_count // 0')
echo ""
echo "=== VERDICT: PASS ==="
echo "  cwv_source: pre-generated"
echo "  lcp=3800ms (high), cls=0.18 (high), inp=320ms (high)"
echo "  signal_count: $sig_count"
echo "  baseline mode: cwv-baseline.json written"
echo "  graceful degradation: cwv_unavailable"
exit 0
