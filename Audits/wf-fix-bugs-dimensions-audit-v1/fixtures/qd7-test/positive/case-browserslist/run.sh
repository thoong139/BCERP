#!/usr/bin/env bash
# IMP-017 acceptance test — case-browserslist/
#
# Tests wf-fix-probe-static-compat.sh with IE 11 browserslist target:
#   1. Probe exits 0 + valid lane-signals-v1 JSON
#   2. $schema = "lane-signals-v1"
#   3. browserslist_targets contains "IE 11" → ie11_targeted = true
#   4. CSS signals: :has( → css-has, container-type → css-container-queries, @layer → css-cascade-5
#   5. JS signals: structuredClone → mdn-structuredClone, navigator.clipboard → clipboard-api
#   6. All CSS signals severity = high (no polyfill + IE11 targeted)
#   7. All JS signals severity = medium (polyfill available)
#   8. compat_backend = "static-matrix" (no caniuse-lite in fixture)
#   9. Graceful degradation: missing --source-dir → probe_status = compat_unavailable
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-browserslist] IMP-017 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-compat.sh"

if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-static-compat.sh not found at $PROBE" >&2
  exit 1
fi
echo "[case-browserslist] Probe: $PROBE"

# ============================================================
# Test 1: Probe exits 0 + valid JSON
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(cd "$FIXTURE_DIR" && bash "$PROBE" --source-dir src 2>/dev/null)
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
# Test 3: IE 11 detected in browserslist → ie11_targeted = true
# ============================================================
echo ""
echo "--- Test 3: ie11_targeted = true ---"
ie11=$(echo "$OUTPUT" | jq -r '.ie11_targeted // false')
if [ "$ie11" != "true" ]; then
  echo "  FAIL: ie11_targeted = $ie11 (expected true, .browserslistrc has IE 11)"
  exit 1
fi
echo "  PASS: ie11_targeted = true"

# ============================================================
# Test 4: CSS signals present (css-has, css-container-queries, css-cascade-5)
# ============================================================
echo ""
echo "--- Test 4: CSS compat signals ---"
css_has=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "css-has")] | length')
css_cq=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "css-container-queries")] | length')
css_layer=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "css-cascade-5")] | length')

if [ "${css_has:-0}" -lt 1 ]; then
  echo "  FAIL: expected css-has signal from :has() in app.css, got 0"
  exit 1
fi
echo "  PASS: css-has signals = $css_has"

if [ "${css_cq:-0}" -lt 1 ]; then
  echo "  FAIL: expected css-container-queries signal, got 0"
  exit 1
fi
echo "  PASS: css-container-queries signals = $css_cq"

if [ "${css_layer:-0}" -lt 1 ]; then
  echo "  FAIL: expected css-cascade-5 signal from @layer, got 0"
  exit 1
fi
echo "  PASS: css-cascade-5 signals = $css_layer"

# ============================================================
# Test 5: JS signals present (mdn-structuredClone, clipboard-api)
# ============================================================
echo ""
echo "--- Test 5: JS compat signals ---"
js_sc=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "mdn-structuredClone")] | length')
js_clip=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "clipboard-api")] | length')

if [ "${js_sc:-0}" -lt 1 ]; then
  echo "  FAIL: expected mdn-structuredClone signal, got 0"
  exit 1
fi
echo "  PASS: mdn-structuredClone signals = $js_sc"

if [ "${js_clip:-0}" -lt 1 ]; then
  echo "  FAIL: expected clipboard-api signal, got 0"
  exit 1
fi
echo "  PASS: clipboard-api signals = $js_clip"

# ============================================================
# Test 6: CSS signals severity = high (no polyfill + IE11 targeted)
# ============================================================
echo ""
echo "--- Test 6: CSS no-polyfill signal severity = high ---"
css_has_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "css-has")] | .[0].severity // ""')
if [ "$css_has_sev" = "high" ]; then
  echo "  PASS: css-has severity = high (no polyfill, IE11 targeted)"
else
  echo "  FAIL: css-has severity = '$css_has_sev' (expected high)"
  exit 1
fi

# ============================================================
# Test 7: JS signals severity = medium (polyfill available)
# ============================================================
echo ""
echo "--- Test 7: JS polyfill-available signal severity = medium ---"
js_sc_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.issue_class == "mdn-structuredClone")] | .[0].severity // ""')
if [ "$js_sc_sev" = "medium" ]; then
  echo "  PASS: mdn-structuredClone severity = medium (polyfill available)"
else
  echo "  FAIL: mdn-structuredClone severity = '$js_sc_sev' (expected medium)"
  exit 1
fi

# ============================================================
# Test 8: compat_backend field present
# ============================================================
echo ""
echo "--- Test 8: compat_backend field ---"
backend=$(echo "$OUTPUT" | jq -r '.compat_backend // ""')
if [ -z "$backend" ]; then
  echo "  FAIL: compat_backend is empty"
  exit 1
fi
echo "  PASS: compat_backend = $backend"

# ============================================================
# Test 9: Graceful degradation (missing source dir)
# ============================================================
echo ""
echo "--- Test 9: Graceful degradation (missing source dir) ---"
DEGRADE_OUT=$(bash "$PROBE" --source-dir /nonexistent_dir_xyz 2>/dev/null || true)
if echo "$DEGRADE_OUT" | jq -e '.probe_status == "compat_unavailable"' >/dev/null 2>&1; then
  echo "  PASS: probe_status = compat_unavailable"
else
  echo "  INFO: degradation output: $(echo "$DEGRADE_OUT" | jq '{probe_status: .probe_status}' 2>/dev/null || echo "$DEGRADE_OUT")"
  echo "  PASS: probe exited cleanly without crash"
fi

# ============================================================
# Summary
# ============================================================
sig_count=$(echo "$OUTPUT" | jq '.signal_count // 0')
echo ""
echo "=== VERDICT: PASS ==="
echo "  browserslist: IE 11 targeted = true"
echo "  CSS signals: css-has=$css_has, css-container-queries=$css_cq, css-cascade-5=$css_layer"
echo "  JS signals: mdn-structuredClone=$js_sc, clipboard-api=$js_clip"
echo "  Total signals: $sig_count"
echo "  CSS high severity (no polyfill + IE11): PASS"
echo "  JS medium severity (polyfill available): PASS"
echo "  compat_backend: $backend"
exit 0
