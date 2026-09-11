#!/usr/bin/env bash
# test-probe-timeout-not-silent.sh — Regression test cho Bug #3 (lane_dispatch silent failure).
#
# Trước fix #3: probe timeout (exit 143/141) → lane_dispatch nuốt error → returns []
#               → aggregator thấy 0 signals → báo healthy=true (FALSE POSITIVE).
# Sau fix #3:   probe timeout → ghi probe-failures.log → aggregator
#               báo probe_failures_count > 0 → healthy=false.
#
# Cách test: force timeout bằng cách set WF_FIX_PROBE_MAX_RUNTIME_SEC=1
# và chạy probe trên fixture. Probe sẽ bị giết → lane_dispatch phải log failure.
#
# Assertions:
#   - $SESSION_DIR/probe-failures.log tồn tại + có ít nhất 1 record JSONL
#   - signal_aggregator output: probe_failures_count > 0
#   - signal_aggregator output: healthy == false
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$EVALS_DIR/../../../../.." && pwd)"
SHARED_DIR="$REPO_ROOT/.claude/skills/workflow/_shared"
WORKFLOW_DIR="$REPO_ROOT/.claude/skills/workflow"
FIXTURE_GEN="$EVALS_DIR/fixtures/large-codebase/scripts/generate-fixture.py"

FIXTURE_DIR="${WF_FIX_LARGE_FIXTURE:-$REPO_ROOT/.cache/wf-fix-large-fixture}"
SESSION_DIR="${FIXTURE_DIR}/.session-timeout-test"
PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  # Try python3 first; fall back to python (Windows often has only python).
  if python3 --version >/dev/null 2>&1; then PYTHON_BIN=python3
  elif python --version >/dev/null 2>&1; then PYTHON_BIN=python
  else echo 'ERROR: neither python3 nor python found in PATH' >&2; exit 2; fi
fi

fail() { echo "[timeout-test] FAIL: $*" >&2; exit 1; }
info() { echo "[timeout-test] $*"; }

# Convert bash POSIX path → native (no-op on Linux, cygpath on Git Bash/Windows)
to_native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}

# Setup fixture nhỏ (đủ để probe khởi động, không cần 50k)
if [ ! -f "$FIXTURE_DIR/.fixture-marker.json" ]; then
  info "Generating fixture (5000 files)…"
  "$PYTHON_BIN" "$FIXTURE_GEN" --out-dir "$FIXTURE_DIR" \
    --target-files 5000 --target-features 100
fi
[ -f "$FIXTURE_DIR/.mc-data/docs/_meta/req-registry.json" ] || fail "fixture missing registry"
if [ ! -d "$FIXTURE_DIR/.git" ]; then
  ( cd "$FIXTURE_DIR" && git init -q && git config commit.gpgsign false \
      && git -c user.email=ci@local -c user.name=ci commit \
         --allow-empty -q -m "fixture seed" ) || true
fi

rm -rf "$SESSION_DIR"
mkdir -p "$SESSION_DIR/lanes"

# Force probe timeout: cap = 1 second. Probe scripts re-exec dưới timeout(1)
# → SIGTERM trong vòng 1s → exit 143 → fix #3 phải log failure.
info "Running lane_dispatch with WF_FIX_PROBE_MAX_RUNTIME_SEC=1 (force timeout)…"
set +e
( cd "$FIXTURE_DIR" && \
    PYTHONPATH="$SHARED_DIR" \
    WF_FIX_SOURCE_DIR="$FIXTURE_DIR/apps" \
    WF_FIX_PROBE_MAX_RUNTIME_SEC=1 \
    "$PYTHON_BIN" -m lane_dispatch \
      --session-dir "$SESSION_DIR" \
      --dims QD1 \
      --profile standard \
      --workflow-root "$WORKFLOW_DIR" \
      --max-parallel 1 \
      >"$SESSION_DIR/dispatch.stdout" 2>"$SESSION_DIR/dispatch.stderr" )
set -e

# ---------------------------------------------------------------------------
# Assertion 1: probe-failures.log tồn tại + có >= 1 record JSONL hợp lệ
# ---------------------------------------------------------------------------
LOG_FILE="$SESSION_DIR/probe-failures.log"
[ -f "$LOG_FILE" ] || {
  echo "[timeout-test] dispatch.stderr (last 30):" >&2
  tail -30 "$SESSION_DIR/dispatch.stderr" >&2 || true
  fail "probe-failures.log not created (Bug #3 regression — silent failure)"
}

LINES=$(wc -l <"$LOG_FILE" | tr -d ' ')
[ "$LINES" -ge 1 ] || fail "probe-failures.log empty (expected >= 1 record)"

# Validate JSONL: each line is valid JSON with required keys
LOG_FILE_NATIVE=$(to_native "$LOG_FILE")
"$PYTHON_BIN" - "$LOG_FILE_NATIVE" <<'PYEOF' || fail "probe-failures.log JSONL schema invalid"
import json, sys
log_path = sys.argv[1]
required = {'timestamp', 'lane', 'probe_id', 'reason', 'returncode'}
n_ok = 0
with open(log_path, 'r', encoding='utf-8') as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        rec = json.loads(line)
        missing = required - set(rec.keys())
        if missing:
            print(f'JSONL_MISSING_KEYS: {missing}', file=sys.stderr)
            sys.exit(1)
        n_ok += 1
if n_ok < 1:
    print('JSONL_NO_RECORDS', file=sys.stderr)
    sys.exit(1)
print(f'JSONL_OK: {n_ok} records')
PYEOF

# ---------------------------------------------------------------------------
# Assertion 2: signal_aggregator báo healthy=false + probe_failures_count > 0
# ---------------------------------------------------------------------------
info "Running signal_aggregator…"
AGG_OUT=$(
  cd "$SHARED_DIR" && PYTHONPATH="$SHARED_DIR" \
    "$PYTHON_BIN" -m signal_aggregator \
      --session-dir "$SESSION_DIR" --dims QD1
) || fail "signal_aggregator failed"

PROBE_FAIL_COUNT=$(echo "$AGG_OUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin).get('probe_failures_count', -1))")
HEALTHY=$(echo "$AGG_OUT" | "$PYTHON_BIN" -c \
    "import json,sys; print(json.load(sys.stdin).get('healthy', None))")

[ "$PROBE_FAIL_COUNT" -ge 1 ] \
  || fail "probe_failures_count=$PROBE_FAIL_COUNT (expected >= 1) — Bug #3 regression"
[ "$HEALTHY" = "False" ] \
  || fail "healthy=$HEALTHY (expected False) — Bug #3 regression: false-positive healthy"

info "PASS: probe-failures.log has $LINES record(s), probe_failures_count=$PROBE_FAIL_COUNT, healthy=$HEALTHY"
exit 0
