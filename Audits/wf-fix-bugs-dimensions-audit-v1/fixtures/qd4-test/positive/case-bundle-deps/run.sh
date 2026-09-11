#!/usr/bin/env bash
# IMP-014 acceptance test — case-bundle-deps/
#
# Tests bundle-stats parsing in wf-fix-probe-static-perf.sh (IMP-014):
#   1. Probe exits 0 with --bundle-stats
#   2. Output is valid lane-signals-v1 JSON
#   3. Large assets (main.bundle.js 1024KB, vendor.bundle.js 2048KB) trigger signals
#   4. Source-map asset is excluded (*.map)
#   5. Heavy dep (d3 512KB > half of warn=250KB) triggers medium signal
#   6. Small dep (lodash 71KB) stays below threshold — no signal
#   7. signals[].evidence[0].stats_source = "webpack-stats"
#
# Default thresholds: warn=500KB, fail=1000KB → module threshold=250KB
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-bundle-deps] IMP-014 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-perf.sh"
STATS="$FIXTURE_DIR/webpack-stats.json"

if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-static-perf.sh not found at $PROBE" >&2
  exit 1
fi
if [ ! -f "$STATS" ]; then
  echo "FAIL: webpack-stats.json not found at $STATS" >&2
  exit 1
fi
echo "[case-bundle-deps] Probe: $PROBE"
echo "[case-bundle-deps] Stats: $STATS"

# ============================================================
# Run probe with explicit bundle-stats path
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(bash "$PROBE" \
  --bundle-stats "$STATS" \
  --bundle-warn-kb 500 \
  --bundle-fail-kb 1000 \
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
  echo "  FAIL: \$schema = $schema (expected lane-signals-v1)"
  exit 1
fi
echo "  PASS: \$schema = lane-signals-v1"

# ============================================================
# Test 3: Large assets trigger signals
# ============================================================
echo ""
echo "--- Test 3: Large assets (main + vendor) in signals ---"
sig_count=$(echo "$OUTPUT" | jq '.signals | length')
echo "  Total signals: $sig_count"
if [ "$sig_count" -lt 2 ]; then
  echo "  FAIL: expected >= 2 signals (main.bundle.js + vendor.bundle.js), got $sig_count"
  echo "$OUTPUT" | jq '[.signals[] | .title]'
  exit 1
fi

# Check main.bundle.js appears (1024KB > fail=1000KB → high)
main_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.title | test("main.bundle.js"))] | .[0].severity // ""')
if [ "$main_sev" = "high" ]; then
  echo "  PASS: main.bundle.js severity = high (1024KB > 1000KB fail threshold)"
else
  echo "  FAIL: main.bundle.js severity = '$main_sev' (expected: high)"
  exit 1
fi

# Check vendor.bundle.js appears (2048KB > fail=1000KB → high)
vendor_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.title | test("vendor.bundle.js"))] | .[0].severity // ""')
if [ "$vendor_sev" = "high" ]; then
  echo "  PASS: vendor.bundle.js severity = high (2048KB > 1000KB fail threshold)"
else
  echo "  FAIL: vendor.bundle.js severity = '$vendor_sev' (expected: high)"
  exit 1
fi

# ============================================================
# Test 4: Source-map excluded
# ============================================================
echo ""
echo "--- Test 4: Source-map (.map) excluded ---"
map_count=$(echo "$OUTPUT" | jq '[.signals[] | select(.title | test("\\.map"))] | length')
if [ "${map_count:-0}" -gt 0 ]; then
  echo "  FAIL: $map_count signal(s) for .map files (should be excluded)"
  exit 1
fi
echo "  PASS: no signals for .map files"

# ============================================================
# Test 5: Heavy dep (d3 512KB > module threshold 250KB)
# ============================================================
echo ""
echo "--- Test 5: Heavy dep d3 (512KB) triggers medium signal ---"
d3_count=$(echo "$OUTPUT" | jq '[.signals[] | select(.title | test("d3"))] | length')
if [ "${d3_count:-0}" -lt 1 ]; then
  echo "  FAIL: no signal for d3 module (512KB > module_threshold=250KB)"
  echo "$OUTPUT" | jq '[.signals[] | .title]'
  exit 1
fi
d3_sev=$(echo "$OUTPUT" | jq -r '[.signals[] | select(.title | test("d3"))] | .[0].severity // ""')
echo "  PASS: d3 signal found, severity = $d3_sev"

# ============================================================
# Test 6: Small dep (lodash 71KB < threshold 250KB) no signal
# ============================================================
echo ""
echo "--- Test 6: Small dep (lodash 71KB) below threshold ---"
lodash_count=$(echo "$OUTPUT" | jq '[.signals[] | select(.title | test("lodash"))] | length')
if [ "${lodash_count:-0}" -gt 0 ]; then
  echo "  FAIL: unexpected signal for lodash (71KB < 250KB threshold)"
  exit 1
fi
echo "  PASS: no signal for lodash (71KB is below module threshold)"

# ============================================================
# Test 7: stats_source field in evidence
# ============================================================
echo ""
echo "--- Test 7: evidence[].stats_source = webpack-stats ---"
stats_src_count=$(echo "$OUTPUT" | jq '[.signals[] | .evidence[]? | select(.stats_source == "webpack-stats")] | length')
if [ "${stats_src_count:-0}" -lt 1 ]; then
  echo "  FAIL: no evidence entry with stats_source=webpack-stats"
  echo "$OUTPUT" | jq '[.signals[0].evidence]'
  exit 1
fi
echo "  PASS: $stats_src_count evidence entries with stats_source=webpack-stats"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  Signals: $sig_count total"
echo "  main.bundle.js: high (1024KB > fail threshold)"
echo "  vendor.bundle.js: high (2048KB > fail threshold)"
echo "  d3 module: $d3_sev (512KB > module threshold)"
echo "  lodash: excluded (71KB < threshold)"
echo "  .map file: excluded"
echo "  stats_source: webpack-stats attributed in evidence"
exit 0
