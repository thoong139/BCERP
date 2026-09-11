#!/usr/bin/env bash
# =============================================================================
# init-session-state.sh — Initialize 4 state files in one atomic call
# =============================================================================
# Gộp 3 steps Phase 1 (1.19-1.21) thành 1 script call:
#   1. fix-status.json     (SSOT pipeline state — schema fix-status-v2)
#   2. session-log.json    (CORE-026 execution trace)
#   3. error-ledger.json   (CORE-034 error tracking)
#   4. Phase1-init/Phase1-report.md  (CORE-028 Vietnamese phase report)
#
# Tất cả populate qua CORE-031 (READ template → POPULATE → STRIP → ATOMIC WRITE).
# Mỗi file fail KHÔNG block các file sau (graceful — orchestrator gather errors).
#
# Required env vars (set bởi orchestrator trước khi call):
#   SESSION_DIR, SESSION_ID, PROFILE, SCOPE, NAME, DIMS_ARRAY,
#   LEGACY_MODE, DRY_RUN, LLM_SCAN, SHOW_BROWSER, NO_BROWSER,
#   MOBILE_MODE, MOBILE_DEVICE, URL, INTERFACE_TYPE,
#   GITNEXUS_AVAILABLE, SERENA_AVAILABLE, FRESHNESS_LEVEL
#
# Optional env vars:
#   PROJECT_NAME (auto-detect từ registry → basename pwd nếu rỗng)
#   SKILL_VERSION (default: 10.3.0)
#
# Exit codes:
#   0 — All 4 files populated successfully
#   1 — Required env var missing
#   2 — Template not found (CORE-031 violation)
#   3 — Atomic write fail cho ít nhất 1 file
#
# Output: JSON (stdout) — per-file status:
#   {"fix_status":"ok","session_log":"ok","error_ledger":"ok","phase1_report":"ok"}
#
# Compatibility: Git Bash + WSL. Pure bash + jq + sed.
# =============================================================================

set -eu

# ── Validate required env vars ───────────────────────────────────────────────
REQUIRED_VARS="SESSION_DIR SESSION_ID PROFILE SCOPE DIMS_ARRAY"
for var in $REQUIRED_VARS; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

# ── Defaults for optional vars ──────────────────────────────────────────────
NAME="${NAME:-}"
LEGACY_MODE="${LEGACY_MODE:-false}"
DRY_RUN="${DRY_RUN:-false}"
LLM_SCAN="${LLM_SCAN:-false}"
SHOW_BROWSER="${SHOW_BROWSER:-false}"
NO_BROWSER="${NO_BROWSER:-false}"
MOBILE_MODE="${MOBILE_MODE:-false}"
MOBILE_DEVICE="${MOBILE_DEVICE:-iPhone 14}"
URL="${URL:-}"
INTERFACE_TYPE="${INTERFACE_TYPE:-unknown}"
GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"
FRESHNESS_LEVEL="${FRESHNESS_LEVEL:-skipped}"
SKILL_VERSION="${SKILL_VERSION:-10.3.0}"

# PROJECT_NAME auto-detect
if [ -z "${PROJECT_NAME:-}" ]; then
  PROJECT_NAME=$(jq -r '.project_name // empty' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo "")
  [ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$(pwd)")"
fi

# ── Template paths ───────────────────────────────────────────────────────────
TPL_DIR=".claude/skills/workflow/wf-fix-bugs/templates"
TPL_FIX_STATUS="$TPL_DIR/phase1-init/fix-status.json"
TPL_SESSION_LOG="$TPL_DIR/_common/session-log.json"
TPL_ERROR_LEDGER="$TPL_DIR/_common/error-ledger.json"
TPL_PHASE1_REPORT="$TPL_DIR/phase1-init/Phase1-report.md"

# Validate templates exist (CORE-031)
for tpl in "$TPL_FIX_STATUS" "$TPL_SESSION_LOG" "$TPL_ERROR_LEDGER" "$TPL_PHASE1_REPORT"; do
  if [ ! -f "$tpl" ]; then
    echo "ERROR: Template missing: $tpl (CORE-031 violation)" >&2
    exit 2
  fi
done

# ── Ensure SESSION_DIR exists (defensive — orchestrator should have created it) ──
mkdir -p "$SESSION_DIR"

# ── Timestamp ────────────────────────────────────────────────────────────────
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Status tracking ──────────────────────────────────────────────────────────
STATUS_FIX="fail"
STATUS_LOG="fail"
STATUS_LEDGER="fail"
STATUS_REPORT="fail"
OVERALL_EXIT=0

# ── 1. fix-status.json ───────────────────────────────────────────────────────
TARGET_FIX="$SESSION_DIR/fix-status.json"
TMP_FIX="$TARGET_FIX.tmp.$$"
if jq \
  --arg id "$SESSION_ID" \
  --arg pname "$PROJECT_NAME" \
  --arg profile "$PROFILE" \
  --arg scope "$SCOPE" \
  --arg name "$NAME" \
  --arg dims "$DIMS_ARRAY" \
  --arg gitnexus "$GITNEXUS_AVAILABLE" \
  --arg serena "$SERENA_AVAILABLE" \
  --arg freshness "$FRESHNESS_LEVEL" \
  --arg legacy "$LEGACY_MODE" \
  --arg show_browser "$SHOW_BROWSER" \
  --arg no_browser "$NO_BROWSER" \
  --arg mobile "$MOBILE_MODE" \
  --arg mobile_device "$MOBILE_DEVICE" \
  --arg dry "$DRY_RUN" \
  --arg llm "$LLM_SCAN" \
  --arg url "$URL" \
  --arg iface "$INTERFACE_TYPE" \
  --arg time "$NOW" \
  '.session_id = $id |
   .project_name = $pname |
   .profile = $profile |
   .scope = $scope |
   .name = $name |
   .dimensions = ($dims | split(" ") | map(select(. != ""))) |
   .ci_tools.gitnexus_available = ($gitnexus == "true") |
   .ci_tools.serena_available = ($serena == "true") |
   .ci_tools.index_freshness = $freshness |
   .legacy_mode = ($legacy == "true") |
   .dry_run = ($dry == "true") |
   .llm_scan = ($llm == "true") |
   .show_browser = ($show_browser == "true") |
   .no_browser = ($no_browser == "true") |
   .mobile_mode = ($mobile == "true") |
   .mobile_device = $mobile_device |
   .playwright.show_browser = ($show_browser == "true") |
   .playwright.mode = (if ($show_browser == "true") then "visible" else "headless" end) |
   .playwright.devices = (if ($mobile == "true") then [$mobile_device] else [] end) |
   .playwright.base_url = $url |
   .interface_type = $iface |
   .started_at = $time |
   .updated_at = $time |
   del(._template_notes, ._schema_notes)' \
  "$TPL_FIX_STATUS" > "$TMP_FIX" 2>/dev/null \
  && jq '.' "$TMP_FIX" > /dev/null 2>&1 \
  && mv "$TMP_FIX" "$TARGET_FIX"; then
  STATUS_FIX="ok"
else
  rm -f "$TMP_FIX"
  OVERALL_EXIT=3
fi

# ── 2. session-log.json ──────────────────────────────────────────────────────
TARGET_LOG="$SESSION_DIR/session-log.json"
TMP_LOG="$TARGET_LOG.tmp.$$"
if jq \
  --arg id "$SESSION_ID" \
  --arg ver "$SKILL_VERSION" \
  --arg time "$NOW" \
  '.session_id = $id | .version = $ver | .events = [] | .created_at = $time | del(._template_notes)' \
  "$TPL_SESSION_LOG" > "$TMP_LOG" 2>/dev/null \
  && jq '.' "$TMP_LOG" > /dev/null 2>&1 \
  && mv "$TMP_LOG" "$TARGET_LOG"; then
  STATUS_LOG="ok"
else
  rm -f "$TMP_LOG"
  OVERALL_EXIT=3
fi

# ── 3. error-ledger.json ─────────────────────────────────────────────────────
TARGET_LEDGER="$SESSION_DIR/error-ledger.json"
TMP_LEDGER="$TARGET_LEDGER.tmp.$$"
if jq \
  --arg id "$SESSION_ID" \
  --arg time "$NOW" \
  '.session_id = $id | .created_at = $time | .errors = [] | del(._template_notes)' \
  "$TPL_ERROR_LEDGER" > "$TMP_LEDGER" 2>/dev/null \
  && jq '.' "$TMP_LEDGER" > /dev/null 2>&1 \
  && mv "$TMP_LEDGER" "$TARGET_LEDGER"; then
  STATUS_LEDGER="ok"
else
  rm -f "$TMP_LEDGER"
  OVERALL_EXIT=3
fi

# ── 4. Phase1-report.md ──────────────────────────────────────────────────────
TARGET_REPORT="$SESSION_DIR/phase1-init/Phase1-report.md"
mkdir -p "$(dirname "$TARGET_REPORT")"

# Build display values for template placeholders
GITNEXUS_STATUS=$([ "$GITNEXUS_AVAILABLE" = "true" ] && echo "available" || echo "absent")
SERENA_STATUS=$([ "$SERENA_AVAILABLE" = "true" ] && echo "available" || echo "absent")
PLAYWRIGHT_MODE=$([ "$SHOW_BROWSER" = "true" ] && echo "visible" || echo "headless")
[ "$MOBILE_MODE" = "true" ] && PLAYWRIGHT_MODE="mobile ($MOBILE_DEVICE)"
# CDG count: Phase 1 thu thập tối đa 6 decisions (E090/E090b/E091/E092/E093/E100).
# Wave 2 sẽ giảm xuống 0-1. Khi script này chạy ở Step 1.21 (cuối Phase 1) — chưa chốt.
CDG_COUNT="${CDG_DECISIONS_COUNT:-0}"
STATUS_PASS="PASS"   # Mặc định PASS — orchestrator sẽ update FAIL nếu POST-GATE T1-T4 fail

# sed populate — match canonical placeholders trong templates/phase1-init/Phase1-report.md
if sed \
  -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS|g" \
  -e "s|\[STARTED_AT\]|$NOW|g" \
  -e "s|\[COMPLETED_AT\]|$NOW|g" \
  -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
  -e "s|\[PROFILE\]|$PROFILE|g" \
  -e "s|\[SCOPE\]|$SCOPE|g" \
  -e "s|\[NAME\]|$NAME|g" \
  -e "s|\[GITNEXUS_STATUS\]|$GITNEXUS_STATUS|g" \
  -e "s|\[SERENA_STATUS\]|$SERENA_STATUS|g" \
  -e "s|\[INTERFACE_TYPE\]|$INTERFACE_TYPE|g" \
  -e "s|\[PLAYWRIGHT_MODE\]|$PLAYWRIGHT_MODE|g" \
  -e "s|\[CDG_DECISIONS_COUNT\]|$CDG_COUNT|g" \
  -e '/_template_notes/d' \
  -e '/_schema_notes/d' \
  "$TPL_PHASE1_REPORT" > "$TARGET_REPORT.tmp.$$" \
  && [ -s "$TARGET_REPORT.tmp.$$" ]; then
  mv "$TARGET_REPORT.tmp.$$" "$TARGET_REPORT"
  STATUS_REPORT="ok"
else
  rm -f "$TARGET_REPORT.tmp.$$"
  OVERALL_EXIT=3
fi

# ── Output status ────────────────────────────────────────────────────────────
jq -n \
  --arg fs "$STATUS_FIX" \
  --arg sl "$STATUS_LOG" \
  --arg el "$STATUS_LEDGER" \
  --arg pr "$STATUS_REPORT" \
  '{fix_status: $fs, session_log: $sl, error_ledger: $el, phase1_report: $pr}'

exit "$OVERALL_EXIT"
