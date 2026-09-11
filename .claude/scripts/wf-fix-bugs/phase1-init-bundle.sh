#!/usr/bin/env bash
# =============================================================================
# phase1-init-bundle.sh — Phase 1 Wave 4 parallel bundle
# =============================================================================
# Mục đích (v10.11.0 — Phase 1 optimization):
#   Gộp 2 init scripts (init-session-state.sh + init-bug-dashboard.sh) vào 1
#   entry point và CHẠY SONG SONG qua bash `&` + `wait`.
#
# Trước (v10.10): 2 bash invocations tuần tự ~200-400ms
# Sau  (v10.11): 1 bash invocation, parallel internal ~100-200ms (giảm ~50%)
#
# Required env vars (giống init-session-state.sh):
#   SESSION_DIR, SESSION_ID, PROFILE, SCOPE, NAME, DIMS_ARRAY,
#   LEGACY_MODE, DRY_RUN, LLM_SCAN, SHOW_BROWSER, NO_BROWSER,
#   MOBILE_MODE, MOBILE_DEVICE, URL, INTERFACE_TYPE,
#   GITNEXUS_AVAILABLE, SERENA_AVAILABLE, FRESHNESS_LEVEL,
#   PROJECT_NAME (optional — auto-detect)
#
# Exit codes:
#   0 — Cả 2 scripts thành công
#   1 — init-session-state.sh fail (E035 retry x1 ở orchestrator)
#   2 — init-bug-dashboard.sh fail (E035 NON-BLOCKING per _shared.md §19.4)
#   3 — Cả 2 fail (rất hiếm)
#
# Output: JSON (stdout) — merged status:
#   {"state":"ok","dashboard":"ok","duration_ms":150}
#
# Compatibility: Git Bash + WSL. Pure bash + jq + sed (+ optional Python).
# =============================================================================

set -u   # KHÔNG dùng -e — script ngầm xử lý exit codes của 2 sub-scripts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
T0=$(date +%s%3N 2>/dev/null || date +%s)

# ── Validate required env vars (subset — defer chi tiết sang sub-scripts) ────
if [ -z "${SESSION_DIR:-}" ] || [ -z "${SESSION_ID:-}" ]; then
  echo "ERROR: SESSION_DIR + SESSION_ID required" >&2
  exit 1
fi

# PROJECT_NAME auto-detect (cùng pattern init-session-state.sh)
if [ -z "${PROJECT_NAME:-}" ]; then
  PROJECT_NAME=$(jq -r '.project_name // empty' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo "")
  [ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$(pwd)")"
  export PROJECT_NAME
fi

# ── Wave 4 launch — parallel via bash & wait ─────────────────────────────────
LOG_STATE="$SESSION_DIR/.phase1-bundle-state.log.$$"
LOG_DASH="$SESSION_DIR/.phase1-bundle-dash.log.$$"

# Launch 1: init-session-state.sh (env vars đã exported từ orchestrator)
bash "$SCRIPT_DIR/init-session-state.sh" > "$LOG_STATE" 2>&1 &
PID_STATE=$!

# Launch 2: init-bug-dashboard.sh (CLI args interface)
bash "$SCRIPT_DIR/init-bug-dashboard.sh" \
  --session-dir="$SESSION_DIR" \
  --session-id="$SESSION_ID" \
  --project-name="${NAME:-$PROJECT_NAME}" \
  --scope="${SCOPE:-all}" \
  --profile="${PROFILE:-standard}" > "$LOG_DASH" 2>&1 &
PID_DASH=$!

# Wait cho cả 2
wait "$PID_STATE"; EXIT_STATE=$?
wait "$PID_DASH";  EXIT_DASH=$?

# ── Aggregate status ─────────────────────────────────────────────────────────
STATUS_STATE=$([ "$EXIT_STATE" -eq 0 ] && echo "ok" || echo "fail")
STATUS_DASH=$([ "$EXIT_DASH" -eq 0 ] && echo "ok" || echo "fail")

# Echo sub-script output ra stderr cho debug
if [ "$EXIT_STATE" -ne 0 ]; then
  echo "[bundle] init-session-state.sh FAILED (exit=$EXIT_STATE):" >&2
  cat "$LOG_STATE" >&2
fi
if [ "$EXIT_DASH" -ne 0 ]; then
  echo "[bundle] init-bug-dashboard.sh FAILED (exit=$EXIT_DASH):" >&2
  cat "$LOG_DASH" >&2
fi

# Cleanup tmp logs
rm -f "$LOG_STATE" "$LOG_DASH"

# Compute duration
T1=$(date +%s%3N 2>/dev/null || date +%s)
DURATION=$((T1 - T0))

# Output JSON
jq -n \
  --arg state "$STATUS_STATE" \
  --arg dash "$STATUS_DASH" \
  --argjson dur "$DURATION" \
  '{state: $state, dashboard: $dash, duration_ms: $dur}'

# Exit code: state fail = critical (1), dashboard fail = non-blocking (2), cả 2 = 3
if [ "$EXIT_STATE" -ne 0 ] && [ "$EXIT_DASH" -ne 0 ]; then
  exit 3
elif [ "$EXIT_STATE" -ne 0 ]; then
  exit 1
elif [ "$EXIT_DASH" -ne 0 ]; then
  exit 2
fi
exit 0
