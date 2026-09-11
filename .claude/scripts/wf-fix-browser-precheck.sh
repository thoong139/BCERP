#!/usr/bin/env bash
set -euo pipefail
# wf-fix-browser-precheck.sh — Kiểm tra CDG browser khi app có UI nhưng BASE_URL không reachable
#
# Usage:
#   bash wf-fix-browser-precheck.sh [--project-root=<path>] [--interface-type=<type>]
#                                   [--no-browser] [--base-url-detect-output=<json-path>]
#
# Exit codes:
#   0 — Không cần CDG (tiến hành bình thường)
#   2 — Cần CDG (app có UI nhưng không reachable — SKILL orchestrator phải hỏi user)
#   1 — Script error (non-fatal — caller treat as no-CDG để không block workflow)
#
# Output JSON (stdout):
#   {"cdg_required": false, "reason": "<reason>"}
#   {"cdg_required": true, "reason": "no_reachable_app", "unreachable_count": N,
#    "message": "App co UI nhung khong detect duoc BASE_URL dang hoat dong..."}
#
# CDG message (tiếng Việt đầy đủ — hiển thị trong SKILL.md orchestrator):
#   "App có UI nhưng không phát hiện được BASE_URL đang hoạt động.
#    Tiếp tục không có browser test (Y) hay dừng để start dev server (N)?"
#
# MCV3 wf-fix-bugs v9 — Wave 1.7 (Browser CDG Enforcement)

set -uo pipefail

# ─── Argument parsing ─────────────────────────────────────────────────────────

PROJECT_ROOT=""
INTERFACE_TYPE=""
NO_BROWSER=false
BASE_URL_DETECT_OUTPUT=""

for arg in "$@"; do
  case "$arg" in
    --project-root=*)            PROJECT_ROOT="${arg#*=}" ;;
    --interface-type=*)          INTERFACE_TYPE="${arg#*=}" ;;
    --no-browser)                NO_BROWSER=true ;;
    --base-url-detect-output=*)  BASE_URL_DETECT_OUTPUT="${arg#*=}" ;;
    --help|-h)
      sed -n '/^# Usage:/,/^# Exit/p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
  esac
done

# Default project root
[[ -z "$PROJECT_ROOT" ]] && PROJECT_ROOT="$(pwd)"
PROJECT_ROOT="${PROJECT_ROOT%/}"

# ─── Fast exits ───────────────────────────────────────────────────────────────

# --no-browser explicitly set → user opted out of browser tests, no CDG needed
if [[ "$NO_BROWSER" == "true" ]]; then
  printf '{"cdg_required":false,"reason":"no_browser_flag_set"}\n'
  exit 0
fi

# api-only project → no UI to test, no CDG needed
if [[ "$INTERFACE_TYPE" == "api-only" ]]; then
  printf '{"cdg_required":false,"reason":"api_only_project"}\n'
  exit 0
fi

# ─── BASE_URL detection ───────────────────────────────────────────────────────

DETECT_RESULT=""

# Option 1: Use pre-computed detect output file
if [[ -n "$BASE_URL_DETECT_OUTPUT" && -f "$BASE_URL_DETECT_OUTPUT" ]]; then
  DETECT_RESULT=$(cat "$BASE_URL_DETECT_OUTPUT" 2>/dev/null) || DETECT_RESULT=""
fi

# Option 2: Run detect script inline with reachability check
if [[ -z "$DETECT_RESULT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DETECT_SCRIPT="$SCRIPT_DIR/wf-fix-detect-base-url.sh"
  if [[ -f "$DETECT_SCRIPT" ]]; then
    DETECT_RESULT=$(bash "$DETECT_SCRIPT" \
      --project-root="$PROJECT_ROOT" \
      --check-reachable 2>/dev/null) || DETECT_RESULT=""
  fi
fi

# Cannot determine reachability → conservative: no CDG (do not block workflow)
if [[ -z "$DETECT_RESULT" ]]; then
  printf '{"cdg_required":false,"reason":"detect_unavailable"}\n'
  exit 0
fi

# ─── Reachability analysis ────────────────────────────────────────────────────

# Check if any non-mobile app is reachable (status = "reachable")
HAS_REACHABLE=$(printf '%s' "$DETECT_RESULT" | grep -o '"status":"reachable"' 2>/dev/null | head -1 || true)

if [[ -n "$HAS_REACHABLE" ]]; then
  printf '{"cdg_required":false,"reason":"reachable_app_found"}\n'
  exit 0
fi

# Check if ALL detected apps are mobile (status = "mobile_skip") → no CDG for mobile-only
ALL_STATUSES=$(printf '%s' "$DETECT_RESULT" | grep -o '"status":"[^"]*"' 2>/dev/null || true)
NON_MOBILE_COUNT=$(printf '%s' "$ALL_STATUSES" | grep -v '"status":"mobile_skip"' | wc -l | tr -d ' ')

if [[ "$NON_MOBILE_COUNT" -eq 0 ]]; then
  printf '{"cdg_required":false,"reason":"all_apps_mobile"}\n'
  exit 0
fi

# Count unreachable + missing apps (non-mobile, non-reachable)
# Note: grep -c always outputs a number even on no-match (exits 1) — "; true" prevents pipefail exit
UNREACHABLE_COUNT=$(printf '%s' "$ALL_STATUSES" | grep -c '"status":"unreachable"' 2>/dev/null; true)
MISSING_COUNT=$(printf '%s' "$ALL_STATUSES" | grep -c '"status":"missing"' 2>/dev/null; true)
UNREACHABLE_COUNT=${UNREACHABLE_COUNT:-0}
MISSING_COUNT=${MISSING_COUNT:-0}
TOTAL_NO_BROWSER=$((UNREACHABLE_COUNT + MISSING_COUNT))

# CDG required — UI project with no reachable browser target
# Note: Full Vietnamese message is in SKILL.md orchestrator. Script uses ASCII for portability.
CDG_MSG="App co UI nhung khong detect duoc BASE_URL dang hoat dong. Hay start dev server roi chay lai."

printf '{"cdg_required":true,"reason":"no_reachable_app","unreachable_count":%d,"message":"%s"}\n' \
  "$TOTAL_NO_BROWSER" \
  "$CDG_MSG"
exit 2
