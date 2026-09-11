#!/usr/bin/env bash
set -euo pipefail
# wf-fix-step-verify.sh — Verify một step/phase đã hoàn thành đúng spec
#
# Mục đích: gọi bởi wf-fix-execute giữa các phase transitions để xác nhận
# output files đầy đủ + fix-status.json đã update đúng. Khác với
# wf-fix-validate-gate.sh (schema validation per-file), script này kiểm tra
# phase-level completion: status + output presence.
#
# Usage:
#   bash wf-fix-step-verify.sh --step=<step_id> --session-dir=<path>
#
# Step IDs supported (extensible):
#   phase3_execute  → Phase 3 execute completed (fix-log.json non-empty)
#   phase4_verify   → Phase 4 verify completed
#   phase5_report   → Phase 5 report completed (fix-report.md exists)
#
# Exit codes:
#   0 — step verified pass
#   1 — step failed verification (caller can retry)
#   2 — invalid args / SESSION_DIR missing (caller should NOT retry)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 2; }
source "$COMMON_SH"

STEP=""
SESSION_DIR=""

for arg in "$@"; do
  case "$arg" in
    --step=*)        STEP="${arg#*=}" ;;
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    *) echo "wf-fix-step-verify: unknown arg $arg" >&2; exit 2 ;;
  esac
done

if [[ -z "$STEP" || -z "$SESSION_DIR" ]]; then
  echo "wf-fix-step-verify: required --step, --session-dir" >&2
  exit 2
fi

if [[ ! -d "$SESSION_DIR" ]]; then
  echo "wf-fix-step-verify: SESSION_DIR không tồn tại: $SESSION_DIR" >&2
  exit 2
fi

FIX_STATUS="$SESSION_DIR/fix-status.json"
if [[ ! -s "$FIX_STATUS" ]]; then
  echo "wf-fix-step-verify: fix-status.json missing or empty: $FIX_STATUS" >&2
  exit 1
fi

# Step-specific verification logic
case "$STEP" in
  phase3_execute)
    # Phase 3 (wf-fix-execute): batches completed, fix-log non-empty
    jq -e '.phases.phase_3.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1 || {
      echo "[step-verify] phases.phase_3.status != completed" >&2
      exit 1
    }
    [[ -s "$SESSION_DIR/fix-log.json" ]] || {
      echo "[step-verify] fix-log.json missing or empty" >&2
      exit 1
    }
    jq -e '.entries | length > 0' "$SESSION_DIR/fix-log.json" >/dev/null 2>&1 || {
      echo "[step-verify] fix-log.json entries empty" >&2
      exit 1
    }
    ;;
  phase4_verify)
    jq -e '.phases.phase_4.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1 || exit 1
    [[ -s "$SESSION_DIR/fix-log.json" ]] || exit 1
    ;;
  phase5_report)
    jq -e '.phases.phase_5.status == "completed"' "$FIX_STATUS" >/dev/null 2>&1 || exit 1
    [[ -s "$SESSION_DIR/fix-report.md" ]] || exit 1
    ;;
  *)
    echo "wf-fix-step-verify: unsupported step '$STEP' — chỉ chấp nhận phase3_execute|phase4_verify|phase5_report" >&2
    exit 2
    ;;
esac

echo "[step-verify] $STEP — PASS"
exit 0
