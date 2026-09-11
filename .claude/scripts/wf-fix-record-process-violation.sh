#!/usr/bin/env bash
set -euo pipefail
# wf-fix-record-process-violation.sh — Ghi process violation vào session log
#
# Mục đích: gọi bởi wf-fix-execute khi retry verification hết (≥3 lần fail)
# để track violations. Tương tự wf-fix-record-probe-failure.sh nhưng cho
# process-level violations (step verification, gate failures, ...).
#
# Usage:
#   bash wf-fix-record-process-violation.sh \
#     --violation-id=<PV-...> \
#     --step=<phase3_execute|...> \
#     --retries=<N> \
#     --session-dir=<path>
#
# Output: append JSONL record vào $SESSION_DIR/process-violations.log
#
# Exit codes:
#   0 — recorded
#   1 — invalid args
#   2 — IO error (skip — không fail caller)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

VIOLATION_ID=""
STEP=""
RETRIES="0"
SESSION_DIR=""

for arg in "$@"; do
  case "$arg" in
    --violation-id=*) VIOLATION_ID="${arg#*=}" ;;
    --step=*)         STEP="${arg#*=}" ;;
    --retries=*)      RETRIES="${arg#*=}" ;;
    --session-dir=*)  SESSION_DIR="${arg#*=}" ;;
    *) echo "wf-fix-record-process-violation: unknown arg $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VIOLATION_ID" || -z "$STEP" || -z "$SESSION_DIR" ]]; then
  echo "wf-fix-record-process-violation: required --violation-id, --step, --session-dir" >&2
  exit 1
fi

if [[ ! -d "$SESSION_DIR" ]]; then
  echo "wf-fix-record-process-violation: SESSION_DIR không tồn tại: $SESSION_DIR" >&2
  exit 2
fi

LOG_PATH="$SESSION_DIR/process-violations.log"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build JSON record qua jq (escape an toàn)
RECORD=$(jq -nc \
  --arg ts "$TIMESTAMP" \
  --arg vid "$VIOLATION_ID" \
  --arg step "$STEP" \
  --argjson retries "$RETRIES" \
  '{
    timestamp: $ts,
    violation_id: $vid,
    step: $step,
    retries: $retries,
    source: "wf-fix-execute_step_verification"
  }') || { echo "wf-fix-record-process-violation: jq build failed" >&2; exit 2; }

# Append JSONL (atomic per-line trên POSIX cho line < 4KB)
echo "$RECORD" >> "$LOG_PATH" || { echo "wf-fix-record-process-violation: IO append failed" >&2; exit 2; }

exit 0
