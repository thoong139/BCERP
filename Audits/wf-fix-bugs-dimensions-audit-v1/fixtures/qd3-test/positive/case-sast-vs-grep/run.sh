#!/usr/bin/env bash
# IMP-013 acceptance test — case-sast-vs-grep/
#
# Tests wf-fix-probe-static-sast.sh (grep fallback path):
#   1. Probe exits 0
#   2. Output is valid lane-signals-v1 JSON
#   3. sast_backend field is present
#   4. At least 1 signal detected (from src/vulnerable.py)
#   5. No signal references tests/test_vulnerable.py (test exclusion works)
#   6. sql_injection issue_class appears in signals
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-sast-vs-grep] IMP-013 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

PROBE="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-sast.sh"
if [ ! -f "$PROBE" ]; then
  echo "FAIL: wf-fix-probe-static-sast.sh not found at $PROBE" >&2
  exit 1
fi
echo "[case-sast-vs-grep] Probe: $PROBE"

# Disable semgrep if installed so we exercise the grep fallback path
export PATH_BACKUP="$PATH"
if command -v semgrep >/dev/null 2>&1; then
  echo "  NOTE: semgrep detected — overriding PATH to force grep fallback"
  # Create a dummy semgrep that returns nothing so we test grep fallback
  FAKE_BIN_DIR="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$FAKE_BIN_DIR'" EXIT
  cat > "$FAKE_BIN_DIR/semgrep" << 'FAKESEMGREP'
#!/usr/bin/env bash
# Fake semgrep — returns empty results for fixture testing
echo '{"results":[],"errors":[]}'
FAKESEMGREP
  chmod +x "$FAKE_BIN_DIR/semgrep"
  export PATH="$FAKE_BIN_DIR:$PATH"
fi

# ============================================================
# Run probe against fixture directory
# ============================================================
echo ""
echo "--- Test 1: Probe exits 0 + valid JSON ---"
OUTPUT=$(bash "$PROBE" --source-dir "$FIXTURE_DIR" 2>/dev/null)
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
  echo "  FAIL: \$schema = '$schema' (expected: lane-signals-v1)"
  exit 1
fi
echo "  PASS: \$schema = lane-signals-v1"

# ============================================================
# Test 3: sast_backend field present
# ============================================================
echo ""
echo "--- Test 3: sast_backend field ---"
backend=$(echo "$OUTPUT" | jq -r '.sast_backend // ""')
if [ -z "$backend" ]; then
  echo "  FAIL: sast_backend missing"
  exit 1
fi
echo "  PASS: sast_backend = $backend"

# ============================================================
# Test 4: At least 1 signal detected
# ============================================================
echo ""
echo "--- Test 4: At least 1 signal ---"
sig_count=$(echo "$OUTPUT" | jq '.signal_count // 0')
echo "  signal_count: $sig_count"
if [ "$sig_count" -lt 1 ]; then
  echo "  FAIL: expected >= 1 signal, got $sig_count"
  echo "$OUTPUT" | jq '.signals'
  exit 1
fi
echo "  PASS: $sig_count signal(s) detected"

# ============================================================
# Test 5: No signal from tests/ directory (exclusion works)
# ============================================================
echo ""
echo "--- Test 5: Test file exclusion ---"
test_signals=$(echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("/tests/|/test/"; "g"))] | length')
if [ "${test_signals:-0}" -gt 0 ]; then
  echo "  FAIL: $test_signals signal(s) from test files (should be 0)"
  echo "$OUTPUT" | jq '[.signals[] | select(.location.file | test("/tests/|/test/"; "g"))]'
  exit 1
fi
echo "  PASS: 0 signals from test files"

# ============================================================
# Test 6: sql_injection issue_class present
# ============================================================
echo ""
echo "--- Test 6: sql_injection issue detected ---"
sql_count=$(echo "$OUTPUT" | jq '[.signals[] | select(.issue_class == "sql_injection")] | length')
if [ "${sql_count:-0}" -lt 1 ]; then
  echo "  FAIL: no sql_injection signal found"
  echo "$OUTPUT" | jq '[.signals[] | .issue_class]'
  exit 1
fi
echo "  PASS: $sql_count sql_injection signal(s)"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  backend: $backend"
echo "  signals: $sig_count total, $sql_count sql_injection"
echo "  test exclusion: $test_signals signals from test files (0 expected)"
exit 0
