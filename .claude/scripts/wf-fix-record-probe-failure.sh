#!/usr/bin/env bash
set -euo pipefail
# wf-fix-record-probe-failure.sh — Ghi 1 record vao probe-failures.log
#
# Muc dich: cho orchestrator dung khi spawn Agent cho non-static probe (QD9/QD10
# runtime, QD2 domain expert, ...) va agent fail (timeout, malformed output,
# exception). Schema khop voi _log_probe_failure trong lane_dispatch.py.
#
# Anti-fantasy: thieu helper nay → orchestrator-side probe failures bypass
# probe_failures_count guard → workflow co the false-positive "healthy".
#
# Usage:
#   bash wf-fix-record-probe-failure.sh \
#     --session-dir=<path> \
#     --lane=<QD9|QD10|...> \
#     --probe-id=<P-QDx-...> \
#     --reason=<agent_timeout|malformed_output|empty_output|exception|...> \
#     [--returncode=<int>] \
#     [--stderr-snippet=<text>]
#
# Exit codes:
#   0 — recorded
#   1 — invalid args
#   2 — IO error (record skipped — KHONG fail caller)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

SESSION_DIR=""
LANE=""
PROBE_ID=""
REASON=""
RETURNCODE="-1"
STDERR_SNIPPET=""

for arg in "$@"; do
  case "$arg" in
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    --lane=*)        LANE="${arg#*=}" ;;
    --probe-id=*)    PROBE_ID="${arg#*=}" ;;
    --reason=*)      REASON="${arg#*=}" ;;
    --returncode=*)  RETURNCODE="${arg#*=}" ;;
    --stderr-snippet=*) STDERR_SNIPPET="${arg#*=}" ;;
    *) echo "wf-fix-record-probe-failure: unknown arg $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$SESSION_DIR" || -z "$LANE" || -z "$PROBE_ID" || -z "$REASON" ]]; then
  echo "wf-fix-record-probe-failure: required --session-dir, --lane, --probe-id, --reason" >&2
  exit 1
fi

if [[ ! -d "$SESSION_DIR" ]]; then
  echo "wf-fix-record-probe-failure: SESSION_DIR khong ton tai: $SESSION_DIR" >&2
  exit 2
fi

LOG_PATH="$SESSION_DIR/probe-failures.log"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

# Cap stderr_snippet o 500 ky tu (khop _log_probe_failure trong lane_dispatch.py)
if [[ ${#STDERR_SNIPPET} -gt 500 ]]; then
  STDERR_SNIPPET="${STDERR_SNIPPET:0:500}"
fi

# Build JSON record qua jq (escape an toan, khong string concat thu cong)
RECORD=$(jq -nc \
  --arg ts "$TIMESTAMP" \
  --arg lane "$LANE" \
  --arg probe "$PROBE_ID" \
  --arg reason "$REASON" \
  --argjson rc "$RETURNCODE" \
  --arg stderr "$STDERR_SNIPPET" \
  '{
    timestamp: $ts,
    lane: $lane,
    probe_id: $probe,
    reason: $reason,
    returncode: $rc,
    stderr_snippet: $stderr,
    source: "orchestrator_agent_dispatch"
  }') || { echo "wf-fix-record-probe-failure: jq build failed" >&2; exit 2; }

# v10.10.0 fix: dùng flock-based serialization để chống concurrent write race
# từ 11 lanes parallel. POSIX guarantees atomic write < PIPE_BUF (512B macOS,
# 4KB Linux); records có stderr_snippet dài có thể bi torn → flock đảm bảo
# serialization tuyệt đối.
LOCK_PATH="${LOG_PATH}.lock"
if command -v flock >/dev/null 2>&1; then
  # Path A: flock available (Linux, modern Git Bash)
  (
    flock -x 200
    printf '%s\n' "$RECORD" >> "$LOG_PATH"
  ) 200>"$LOCK_PATH" || { echo "wf-fix-record-probe-failure: flock write failed: $LOG_PATH" >&2; exit 2; }
else
  # Path B: flock absent (macOS BSD) — fallback mkdir-based lock với retry
  for attempt in 1 2 3 4 5; do
    if mkdir "${LOCK_PATH}.d" 2>/dev/null; then
      printf '%s\n' "$RECORD" >> "$LOG_PATH"
      rmdir "${LOCK_PATH}.d" 2>/dev/null
      break
    fi
    sleep 0.1
    if [ "$attempt" -eq 5 ]; then
      echo "wf-fix-record-probe-failure: lock retry exhausted, falling back to raw append (race risk)" >&2
      printf '%s\n' "$RECORD" >> "$LOG_PATH" || { echo "wf-fix-record-probe-failure: write failed: $LOG_PATH" >&2; exit 2; }
    fi
  done
fi

echo "[probe-failure] recorded: lane=$LANE probe=$PROBE_ID reason=$REASON" >&2
exit 0
