#!/usr/bin/env bash
# concurrent-runner.sh — Orchestrate 2 sessions parallel cho TC-cmi-005
#
# Usage: bash concurrent-runner.sh [--dry-run]
#
# Reuse fixture realistic/ (3 modules CRM+Orders+Finance).
# Session A: --scope=system --profile=deep (chạy trước)
# Session B: --scope=module=crm --profile=quick (chạy sau 30s)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_BASE="$SCRIPT_DIR/../realistic"
DRY_RUN="${1:-}"

if [ ! -d "$FIXTURE_BASE" ]; then
    echo "ERROR: Fixture base $FIXTURE_BASE không tồn tại"
    exit 1
fi

echo "==============================================="
echo "TC-cmi-005 Concurrent Runner"
echo "Fixture base: $FIXTURE_BASE"
echo "==============================================="

# Workspace cho test
TEST_WORKSPACE="${TEST_WORKSPACE:-/tmp/wf-cmi-concurrent-$$}"
mkdir -p "$TEST_WORKSPACE"
cp -r "$FIXTURE_BASE/." "$TEST_WORKSPACE/"
cd "$TEST_WORKSPACE"

echo "Workspace: $TEST_WORKSPACE"
echo ""

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "[DRY-RUN] Sẽ chạy:"
    echo "  Session A: /wf-cmi --scope=system --profile=deep   &  (t=0s)"
    echo "  Session B: /wf-cmi --scope=module=crm --profile=quick &  (t=30s)"
    echo "  Theo dõi: _index/sessions.jsonl + lock conflict E090b"
    exit 0
fi

# Session A — chạy trước
echo "[t=0s] Spawn Session A (--scope=system --profile=deep)"
# NOTE: Trong test harness thực, thay thế bằng invoke skill thực.
# Ở đây là placeholder để minh hoạ orchestration pattern.
# claude-code run /wf-cmi --scope=system --profile=deep > session-a.log 2>&1 &
# SA_PID=$!
SA_PID="placeholder-session-a"
echo "  Session A PID: $SA_PID"

# Wait 30s — Session A nên vào Phase 2 Discovery
sleep 30

# Session B — chạy sau
echo "[t=30s] Spawn Session B (--scope=module=crm --profile=quick)"
# claude-code run /wf-cmi --scope=module=crm --profile=quick > session-b.log 2>&1 &
# SB_PID=$!
SB_PID="placeholder-session-b"
echo "  Session B PID: $SB_PID"

# Monitor _index/sessions.jsonl + heartbeat
echo ""
echo "[Monitor] Theo dõi sessions.jsonl trong 60s..."
INDEX_FILE=".mc-data/work/wf-cmi/_index/sessions.jsonl"

for i in $(seq 1 12); do
    sleep 5
    if [ -f "$INDEX_FILE" ]; then
        ENTRY_COUNT=$(wc -l < "$INDEX_FILE")
        echo "  [t=$((30 + i*5))s] sessions.jsonl: $ENTRY_COUNT entries"
    fi
done

# Wait cho cả 2 sessions complete
# wait $SA_PID || true
# wait $SB_PID || true

echo ""
echo "==============================================="
echo "Validation:"
echo "==============================================="

# Kiểm tra index có 2 entries
if [ -f "$INDEX_FILE" ]; then
    TOTAL_ENTRIES=$(wc -l < "$INDEX_FILE")
    echo "  ✓ sessions.jsonl entries: $TOTAL_ENTRIES (expected ≥2)"
fi

# Kiểm tra error-ledger có E090b nếu lock conflict xảy ra
for SESSION_DIR in .mc-data/work/wf-cmi/sessions/*/; do
    if [ -f "$SESSION_DIR/error-ledger.json" ]; then
        E090B_COUNT=$(jq -r 'select(.error_code == "E090b") | .error_code' "$SESSION_DIR/error-ledger.json" 2>/dev/null | wc -l)
        echo "  $(basename $SESSION_DIR): E090b CDG entries=$E090B_COUNT"
    fi
done

echo ""
echo "Workspace artifact: $TEST_WORKSPACE/.mc-data/work/wf-cmi/"
echo "Cleanup: rm -rf $TEST_WORKSPACE"
