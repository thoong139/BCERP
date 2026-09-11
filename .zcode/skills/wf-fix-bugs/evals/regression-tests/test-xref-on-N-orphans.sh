#!/usr/bin/env bash
# test-xref-on-N-orphans.sh — Regression test cho Bug #4 (xref O(N×M)).
#
# Trước fix #4: với mỗi orphan REQ-ID, chạy `grep -rEln SOURCE_DIR` (full scan).
#               Trên monorepo, 1000 orphans × 10s/grep = 10000s.
# Sau fix #4:   1 grep pass cho toàn bộ codebase, save thành mapping
#               req_id → (first_file, first_line), lookup O(1) per orphan.
#
# Cách test: tạo registry với 1000 REQ-IDs nhưng KHÔNG xuất hiện trong source
# (= 1000 orphan annotations). Chạy xref probe → đo wall-clock.
#
# Assertions:
#   - Wall-clock < 30s (relax từ ~hours, đủ headroom cho slow CI)
#   - Probe exit = 0
#   - signals.json output có valid schema
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$EVALS_DIR/../../../../.." && pwd)"
PROBE_SCRIPT="$REPO_ROOT/.claude/scripts/wf-fix-probe-static-xref.sh"

PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  # Try python3 first; fall back to python (Windows often has only python).
  if python3 --version >/dev/null 2>&1; then PYTHON_BIN=python3
  elif python --version >/dev/null 2>&1; then PYTHON_BIN=python
  else echo 'ERROR: neither python3 nor python found in PATH' >&2; exit 2; fi
fi

TMP_ROOT="${WF_FIX_XREF_TMP:-$REPO_ROOT/.cache/wf-fix-xref-orphans}"
SESSION_DIR="$TMP_ROOT/session"
SOURCE_DIR="$TMP_ROOT/src"
REGISTRY="$TMP_ROOT/registry.json"
TIME_BUDGET_SEC="${WF_FIX_XREF_BUDGET:-30}"
N_ORPHANS="${WF_FIX_XREF_N:-1000}"

fail() { echo "[xref-orphans-test] FAIL: $*" >&2; exit 1; }
info() { echo "[xref-orphans-test] $*"; }

# Convert bash POSIX path → native path (no-op on Linux, cygpath on Git Bash/Windows)
to_native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}

[ -f "$PROBE_SCRIPT" ] || fail "probe script missing: $PROBE_SCRIPT"

# Setup: clean
rm -rf "$TMP_ROOT"
mkdir -p "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw" "$SOURCE_DIR"

REGISTRY_NATIVE=$(to_native "$REGISTRY")
SOURCE_DIR_NATIVE=$(to_native "$SOURCE_DIR")

# Generate registry với N orphan REQ-IDs (KHÔNG xuất hiện trong $SOURCE_DIR).
# Note: REQ-ID format `REQ-[A-Z]+(-[A-Z]+)?-[0-9]+` (xref probe regex).
info "Generating registry with $N_ORPHANS orphan REQ-IDs…"
"$PYTHON_BIN" - "$REGISTRY_NATIVE" "$N_ORPHANS" <<'PYEOF'
import json, sys
registry_path = sys.argv[1]
n = int(sys.argv[2])
reqs = [{'id': f'REQ-ORPHAN-{i:04d}', 'title': f'Orphan req {i}', 'impl_status': 'not_started'}
        for i in range(n)]
data = {'version': '1.0.0', 'requirements': reqs, 'features': []}
with open(registry_path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
print(f'wrote {n} orphan reqs to {registry_path}')
PYEOF

# Generate small source tree (~500 files) WITHOUT any REQ-ORPHAN-* annotations.
# Mục đích: probe scan source → tất cả N orphans phải lookup O(1) qua pre-built map.
info "Generating 500 stub source files (no matching REQ-IDs)…"
"$PYTHON_BIN" - "$SOURCE_DIR_NATIVE" <<'PYEOF'
import sys
from pathlib import Path
src = Path(sys.argv[1])
for i in range(500):
    bucket = src / f'mod-{i // 50:02d}'
    bucket.mkdir(parents=True, exist_ok=True)
    p = bucket / f'file-{i:04d}.ts'
    p.write_text('// REQ-ID: REQ-OTHER-DEPT-999\nexport const x = ' + str(i) + ';\n', encoding='utf-8')
PYEOF

# git init để git rev-parse trả về $TMP_ROOT (nếu probe relies on it)
( cd "$TMP_ROOT" && git init -q && git config commit.gpgsign false \
    && git -c user.email=ci@local -c user.name=ci commit \
       --allow-empty -q -m "xref-test seed" ) || true

# Run xref probe — đo wall-clock
info "Running xref probe (N=$N_ORPHANS orphans)…"
START_TS=$(date +%s)
set +e
( cd "$TMP_ROOT" && bash "$PROBE_SCRIPT" \
    --session-dir "$SESSION_DIR" \
    --lane wf-fix-functional \
    --probe P-QD1-req-registry-xref \
    --profile standard \
    --source-dir "$SOURCE_DIR" \
    --registry "$REGISTRY" \
    >"$SESSION_DIR/probe.stdout" 2>"$SESSION_DIR/probe.stderr" )
PROBE_EXIT=$?
set -e
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

info "Probe exit=$PROBE_EXIT, elapsed=${ELAPSED}s"

# Assertions
[ "$PROBE_EXIT" = "0" ] || {
  echo "[xref-orphans-test] probe.stderr (last 30):" >&2
  tail -30 "$SESSION_DIR/probe.stderr" >&2 || true
  fail "probe exit=$PROBE_EXIT (expected 0)"
}

awk -v a="$ELAPSED" -v m="$TIME_BUDGET_SEC" 'BEGIN { exit (a > m) ? 1 : 0 }' \
  || fail "wall-clock=${ELAPSED}s > ${TIME_BUDGET_SEC}s (Bug #4 regression — O(N×M))"

# Verify probe output JSON is valid
[ -s "$SESSION_DIR/probe.stdout" ] || fail "probe stdout empty"
PROBE_STDOUT_NATIVE=$(to_native "$SESSION_DIR/probe.stdout")
"$PYTHON_BIN" - "$PROBE_STDOUT_NATIVE" <<'PYEOF' || fail "probe stdout not valid JSON"
import json, sys
data = json.loads(open(sys.argv[1], 'r', encoding='utf-8').read())
if not isinstance(data, (dict, list)):
    print('OUTPUT_NOT_JSON_OBJECT', file=sys.stderr)
    sys.exit(1)
PYEOF

info "PASS: xref probe handled $N_ORPHANS orphans in ${ELAPSED}s (budget=${TIME_BUDGET_SEC}s)"
exit 0
