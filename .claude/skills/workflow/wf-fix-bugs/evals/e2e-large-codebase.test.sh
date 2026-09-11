#!/usr/bin/env bash
# e2e-large-codebase.test.sh — End-to-end test cho lane_dispatch trên fixture lớn.
#
# Pre-condition: fixture tại $WF_FIX_LARGE_FIXTURE đã được generate
#   (hoặc auto-generate khi chưa có marker).
#
# Assertions (Bug list 2026-05-09 #3, #4, #5):
#   - Total wall-clock time < 300s (5 phút) — chống regression Bug #5 (timeout cap)
#   - probe_failures_count == 0 — chống regression Bug #3 (silent failure)
#   - total_issues > 0 — phải detect coverage gaps trong fixture
#   - signal_aggregator output schema valid
#
# Exit codes: 0 = pass, 1 = assertion fail, 2 = setup error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Cấu hình
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
SHARED_DIR="$REPO_ROOT/.claude/skills/workflow/_shared"
WORKFLOW_DIR="$REPO_ROOT/.claude/skills/workflow"
FIXTURE_GEN="$SCRIPT_DIR/fixtures/large-codebase/scripts/generate-fixture.py"

FIXTURE_DIR="${WF_FIX_LARGE_FIXTURE:-$REPO_ROOT/.cache/wf-fix-large-fixture}"
SESSION_DIR="${WF_FIX_E2E_SESSION_DIR:-${FIXTURE_DIR}/.session-e2e}"
TARGET_FILES="${WF_FIX_FIXTURE_FILES:-50000}"
TIME_BUDGET_SEC="${WF_FIX_E2E_BUDGET:-300}"
PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  # Try python3 first; fall back to python (Windows often has only python).
  if python3 --version >/dev/null 2>&1; then PYTHON_BIN=python3
  elif python --version >/dev/null 2>&1; then PYTHON_BIN=python
  else echo 'ERROR: neither python3 nor python found in PATH' >&2; exit 2; fi
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
fail() { echo "[e2e] FAIL: $*" >&2; exit 1; }
info() { echo "[e2e] $*"; }

assert_le() {
  awk -v a="$1" -v m="$2" 'BEGIN { exit (a > m) ? 1 : 0 }' \
    || fail "$3: $1 > $2"
}
assert_eq() { [ "$1" = "$2" ] || fail "$3: expected '$2' got '$1'"; }
assert_ge() {
  awk -v a="$1" -v m="$2" 'BEGIN { exit (a < m) ? 1 : 0 }' \
    || fail "$3: $1 < $2"
}

# ---------------------------------------------------------------------------
# Step 1: Đảm bảo fixture tồn tại + là git repo
# ---------------------------------------------------------------------------
if [ ! -f "$FIXTURE_DIR/.fixture-marker.json" ]; then
  info "Generating fixture at $FIXTURE_DIR (target=$TARGET_FILES files)…"
  "$PYTHON_BIN" "$FIXTURE_GEN" --out-dir "$FIXTURE_DIR" \
    --target-files "$TARGET_FILES" --target-features 300
fi
[ -d "$FIXTURE_DIR/apps" ] || fail "Fixture missing apps/ at $FIXTURE_DIR"
[ -f "$FIXTURE_DIR/.mc-data/docs/_meta/req-registry.json" ] \
    || fail "Fixture missing registry"

# Probe scripts dùng `git rev-parse --show-toplevel` để resolve REGISTRY path.
# Đảm bảo fixture là git repo (idempotent).
if [ ! -d "$FIXTURE_DIR/.git" ]; then
  info "Initializing git repo in fixture (probe registry resolution)…"
  ( cd "$FIXTURE_DIR" && git init -q && git config commit.gpgsign false \
      && git -c user.email=ci@local -c user.name=ci commit \
         --allow-empty -q -m "fixture seed" ) || true
fi

# ---------------------------------------------------------------------------
# Step 2: Chuẩn bị SESSION_DIR
# ---------------------------------------------------------------------------
rm -rf "$SESSION_DIR"
mkdir -p "$SESSION_DIR/lanes"

# ---------------------------------------------------------------------------
# Step 3: Run lane_dispatch QD1+QD2+QD3 profile=deep
# ---------------------------------------------------------------------------
info "Running lane_dispatch from $FIXTURE_DIR (workflow_root=$WORKFLOW_DIR)…"
START_TS=$(date +%s)

set +e
( cd "$FIXTURE_DIR" && \
    PYTHONPATH="$SHARED_DIR" \
    WF_FIX_SOURCE_DIR="$FIXTURE_DIR/apps" \
    WF_FIX_PROBE_MAX_RUNTIME_SEC="${WF_FIX_PROBE_MAX_RUNTIME_SEC:-600}" \
    "$PYTHON_BIN" -m lane_dispatch \
      --session-dir "$SESSION_DIR" \
      --dims QD1 QD2 QD3 \
      --profile deep \
      --workflow-root "$WORKFLOW_DIR" \
      --max-parallel 3 \
      >"$SESSION_DIR/lane-dispatch.stdout" 2>"$SESSION_DIR/lane-dispatch.stderr" )
DISPATCH_EXIT=$?
set -e
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

info "lane_dispatch exit=$DISPATCH_EXIT, elapsed=${ELAPSED}s"

# ---------------------------------------------------------------------------
# Step 4: Assertions
# ---------------------------------------------------------------------------
# Assert 1: time budget — chống regression Bug #5 (timeout cap quá thấp)
assert_le "$ELAPSED" "$TIME_BUDGET_SEC" "wall-clock time"

# Assert 2: lanes/QD* directories created
LANES_COUNT=$(find "$SESSION_DIR/lanes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
assert_ge "$LANES_COUNT" 1 "lanes created"

# Assert 3: signal_aggregator → output schema valid
info "Running signal_aggregator…"
AGG_OUT=$(
  cd "$SHARED_DIR" && PYTHONPATH="$SHARED_DIR" \
    "$PYTHON_BIN" -m signal_aggregator \
      --session-dir "$SESSION_DIR" --dims QD1 QD2 QD3
) || fail "signal_aggregator failed (exit=$?). lane_dispatch.stderr:$(cat "$SESSION_DIR/lane-dispatch.stderr" 2>/dev/null | tail -20)"

# Schema validation — required keys present
echo "$AGG_OUT" | "$PYTHON_BIN" -c "
import json, sys
data = json.loads(sys.stdin.read())
required = ['total_signals', 'total_issues', 'probe_failures_count',
            'probe_failures', 'healthy', 'dimensions_run']
missing = [k for k in required if k not in data]
if missing:
    print('SCHEMA_MISSING:' + ','.join(missing), file=sys.stderr)
    sys.exit(1)
" || fail "signal_aggregator schema invalid"

PROBE_FAIL_COUNT=$(echo "$AGG_OUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin).get('probe_failures_count', -1))")
TOTAL_ISSUES=$(echo "$AGG_OUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin).get('total_issues', -1))")

# Assert 4: probe_failures_count == 0 — chống regression Bug #3 (silent failure)
assert_eq "$PROBE_FAIL_COUNT" "0" "probe_failures_count"

# Assert 5: total_issues > 0 — fixture có 300 features mix impl_status,
# xref/coverage probe phải tìm thấy gaps. Nếu = 0, có thể probe không chạy.
assert_ge "$TOTAL_ISSUES" 1 "total_issues > 0 (must detect coverage gaps)"

info "PASS: e2e-large-codebase (elapsed=${ELAPSED}s, issues=$TOTAL_ISSUES, probe_failures=$PROBE_FAIL_COUNT, lanes=$LANES_COUNT)"
exit 0
