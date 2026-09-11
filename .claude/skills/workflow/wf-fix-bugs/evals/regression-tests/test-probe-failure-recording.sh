#!/usr/bin/env bash
# Regression test (HIGH-6 v9.0.3): probe-failures.log recording behavior.
#
# Bug class: v9.0.0 fantasy pattern — orchestrator-dispatched probes (QD9 runtime,
# QD10 cross-module) khi fail KHONG ghi vao probe-failures.log → probe_failures_count
# silent 0 → POST-GATE T5 pass-through.
#
# Test verify behavior end-to-end:
#   1. Helper ghi 1 record JSONL voi schema dung
#   2. Multiple records append append (KHONG overwrite)
#   3. Schema fields khop voi _log_probe_failure trong lane_dispatch.py

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd)}"
HELPER="$REPO_ROOT/.claude/scripts/wf-fix-record-probe-failure.sh"

# Setup tmp dir
TMPDIR_TEST=$(mktemp -d 2>/dev/null || echo "/tmp/wf-fix-test-$$")
mkdir -p "$TMPDIR_TEST"
trap "rm -rf '$TMPDIR_TEST'" EXIT INT TERM

if [[ ! -x "$HELPER" ]] && [[ ! -f "$HELPER" ]]; then
  echo "FAIL: helper script not found at $HELPER" >&2
  exit 1
fi

# T1: Missing args → exit 1
RC=0
bash "$HELPER" 2>/dev/null || RC=$?
if [[ "$RC" -ne 1 ]]; then
  echo "FAIL T1: missing args expected exit 1, got $RC" >&2
  exit 2
fi

# T2: Record 1 failure → file created, schema correct
SESSION_T2="$TMPDIR_TEST/session-t2"
mkdir -p "$SESSION_T2"

bash "$HELPER" \
  --session-dir="$SESSION_T2" \
  --lane=QD9 \
  --probe-id=P-QD9-spa-route-coverage \
  --reason=agent_timeout \
  --returncode=124 \
  --stderr-snippet="Agent did not return within 300s" \
  >/dev/null 2>&1
RC=$?
if [[ "$RC" -ne 0 ]]; then
  echo "FAIL T2: record helper exited $RC (expected 0)" >&2
  exit 3
fi

LOG="$SESSION_T2/probe-failures.log"
if [[ ! -f "$LOG" ]]; then
  echo "FAIL T2: probe-failures.log not created at $LOG" >&2
  exit 3
fi

LINE_COUNT=$(wc -l < "$LOG" | tr -d ' ')
if [[ "$LINE_COUNT" -ne 1 ]]; then
  echo "FAIL T2: expected 1 line, got $LINE_COUNT" >&2
  exit 3
fi

LANE=$(jq -r '.lane' < "$LOG")
PROBE=$(jq -r '.probe_id' < "$LOG")
REASON=$(jq -r '.reason' < "$LOG")
RC_VAL=$(jq -r '.returncode' < "$LOG")
SOURCE=$(jq -r '.source' < "$LOG")

if [[ "$LANE" != "QD9" ]] || [[ "$PROBE" != "P-QD9-spa-route-coverage" ]] || \
   [[ "$REASON" != "agent_timeout" ]] || [[ "$RC_VAL" != "124" ]] || \
   [[ "$SOURCE" != "orchestrator_agent_dispatch" ]]; then
  echo "FAIL T2 schema: lane=$LANE probe=$PROBE reason=$REASON rc=$RC_VAL source=$SOURCE" >&2
  echo "Record:" >&2
  cat "$LOG" >&2
  exit 3
fi

# T3: Append 2 more records → 3 lines total (NOT overwrite)
for i in 1 2; do
  bash "$HELPER" \
    --session-dir="$SESSION_T2" \
    --lane="QD10" \
    --probe-id="P-QD10-test-$i" \
    --reason=empty_output \
    --returncode=0 \
    >/dev/null 2>&1
done

LINE_COUNT=$(wc -l < "$LOG" | tr -d ' ')
if [[ "$LINE_COUNT" -ne 3 ]]; then
  echo "FAIL T3: expected 3 lines after append, got $LINE_COUNT" >&2
  exit 4
fi

# T4: Missing session-dir → exit 2 (caller-safe)
NONEXIST="$TMPDIR_TEST/does-not-exist"
RC=0
bash "$HELPER" \
  --session-dir="$NONEXIST" \
  --lane=QD9 --probe-id=test --reason=test \
  2>/dev/null || RC=$?
if [[ "$RC" -ne 2 ]]; then
  echo "FAIL T4: missing session-dir expected exit 2, got $RC" >&2
  exit 5
fi

echo "PASS: probe-failure recording — schema dung, append-safe, error-safe."
exit 0
