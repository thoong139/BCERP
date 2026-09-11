#!/usr/bin/env bash
# legacy-scan-phase-b-smoke.sh — Integration smoke test cho Phase B foundation.
#
# Phạm vi: verify các thành phần Phase B tích hợp đúng end-to-end:
#   1. flock_acquire / flock_release
#   2. init_session_dir + init_scan_state + init_session_aux_files
#   3. Python scan_state_reader (update_layer_status, batch/module progress, append_error)
#   4. generate_legacy_ledger projection
#
# KHÔNG chạy full /wf-legacy-scan pipeline (Phase D mới migrate sub-skills).
# A.3 fixture baseline compare bị deferred — xem MIGRATION-PROGRESS.md.
#
# Usage: bash .claude/scripts/legacy-scan-phase-b-smoke.sh [project-path]

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/legacy-scan-common.sh"
_SCRIPT_NAME="phase-b-smoke"

PROJECT_PATH="${1:-/tmp/b6-synthetic-project}"
if [[ ! -d "$PROJECT_PATH" ]]; then
  mkdir -p "$PROJECT_PATH/src/billing" "$PROJECT_PATH/src/hr"
  echo "// dummy billing" > "$PROJECT_PATH/src/billing/invoice.ts"
  echo "// dummy hr"      > "$PROJECT_PATH/src/hr/employee.ts"
  echo "# Smoke test project" > "$PROJECT_PATH/README.md"
fi

WORK_DIR="$PROJECT_PATH/.mc-data/work/legacy-scan"
mkdir -p "$WORK_DIR"
LOCK_FILE="$WORK_DIR/.session.lock"

# Step 1: Lock.
flock_acquire "$LOCK_FILE" 0 || {
  log_error "Another session is active. Release with: rm $LOCK_FILE"
  exit 1
}
trap 'flock_release "$LOCK_FILE"' EXIT INT TERM

# Step 2: Session init.
SESSION_ID="$(generate_session_id)"
SESSION_DIR="$(init_session_dir "$WORK_DIR" "$SESSION_ID")"
log_info "SESSION_ID=$SESSION_ID"

TEMPLATE="$SCRIPTS_DIR/../skills/workflow/wf-legacy-scan/templates/scan-state.json"
init_scan_state "$TEMPLATE" "$SESSION_DIR/scan-state.json" "$SESSION_ID" "$PROJECT_PATH" "S2" "CODE_ONLY"
init_session_aux_files "$SESSION_DIR" "$SESSION_ID"

# Step 3: Domain detection EN.
detect_domain_hints_en "$PROJECT_PATH" "$SESSION_DIR/domain-hints-test.json"

# Step 4: Python layer progression (requires cygpath on Windows).
WIN_WORK_DIR="$WORK_DIR"
WIN_SESSION_DIR="$SESSION_DIR"
if command -v cygpath &>/dev/null; then
  WIN_WORK_DIR="$(cygpath -w "$WORK_DIR")"
  WIN_SESSION_DIR="$(cygpath -w "$SESSION_DIR")"
fi

SHARED_DIR="$SCRIPTS_DIR/../skills/workflow/_shared"
(cd "$SHARED_DIR" && python -c "
import sys, json
from pathlib import Path
sys.path.insert(0, '.')
from ips import scan_state_reader as ssr
ssr.WORK_DIR = Path(r'$WIN_WORK_DIR')

ssr.update_layer_status('L1', 'in_progress')
ssr.update_layer_status('L1', 'completed')
for lid in ['L2', 'L3', 'L4', 'L5', 'L6']:
    ssr.update_layer_status(lid, 'in_progress')
    ssr.update_layer_status(lid, 'completed')
ssr.update_batch_progress('L4', {'current': 2, 'total': 2, 'completed_batches': [0, 1]})
ssr.update_module_progress('L5', 'billing', 'completed')
ssr.update_module_progress('L5', 'hr', 'completed')
ssr.append_error('L2', {'code': 'W-001', 'severity': 'warn', 'message': 'smoke test warning'})

state = ssr.read_scan_state()
assert state['status'] == 'in_progress'
assert all(state['layers'][l]['status'] == 'completed' for l in ['L1','L2','L3','L4','L5','L6']), 'layer progression failed'
assert state['layers']['L5']['module_progress']['completed'] == ['billing', 'hr']
assert len(state['error_log']) == 1

# Mark session completed cho ledger generation.
state['status'] = 'completed'
Path(r'$WIN_SESSION_DIR' + '/scan-state.json').write_text(
    json.dumps(state, indent=2, ensure_ascii=False), encoding='utf-8'
)
print('Python round-trip OK')
")

# Step 5: Ledger projection.
generate_legacy_ledger "$SESSION_DIR" "$WORK_DIR/ledger.json"

# Step 6: Assertions.
jq -e '.session.id == "'"$SESSION_ID"'"' "$SESSION_DIR/scan-state.json" >/dev/null
jq -e '.pipeline_status == "COMPLETE"' "$WORK_DIR/ledger.json" >/dev/null
jq -e '."$schema" == "ledger-v4.1"' "$WORK_DIR/ledger.json" >/dev/null
jq -e '.stages.detection.status == "completed"' "$WORK_DIR/ledger.json" >/dev/null

flock_release "$LOCK_FILE"
[[ ! -f "$LOCK_FILE" ]] || { log_error "lock not released"; exit 1; }

log_info "Phase B smoke test PASS — session=$SESSION_ID, ledger=$WORK_DIR/ledger.json"
echo "PASS"
