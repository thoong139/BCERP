#!/usr/bin/env bash
# wf-fix-multi-app-coordinator.sh — Sequential multi-app browser smoke coordinator (QD9)
#
# Wave 3.7: Ensures QD9 browser probes run per-app SEQUENTIALLY in a monorepo,
# max 1 Playwright browser instance active globally at any time.
#
# Usage:
#   bash wf-fix-multi-app-coordinator.sh \
#     --project-root=<path> \
#     --session-dir=<path> \
#     [--apps=erp-web,smarttax-web,...]   # optional allowlist; default = all web apps
#     [--output=<coordinator-status.json>] \
#     [--dry-run]                          # output plan only, no probe execution
#
# Output — coordinator-status.json:
#   {
#     "coordinator_version": "1.0.0",
#     "project_root": "...",
#     "session_dir": "...",
#     "total_apps_detected": N,
#     "skipped_mobile": N,
#     "apps_queued_count": N,
#     "apps_queued": [
#       {
#         "name": "erp-web",
#         "base_url": "http://localhost:3000",
#         "framework": "nextjs",
#         "status": "queued|running|done|error|skip_missing|skip_mobile",
#         "dev_server_result": "ok|fail|skip_no_script|unknown",
#         "qd9_signals_count": 0,
#         "started_at": null,
#         "completed_at": null,
#         "error": null
#       }
#     ],
#     "browser_lock_path": "...",
#     "status": "planned|running|completed",
#     "generated_at": "...",
#     "started_at": null,
#     "completed_at": null
#   }
#
# Priority order (per W3.7 spec): erp-web → smarttax-web → erktransport.com → web-customer → others
# Mobile apps (Expo/React Native) are automatically excluded from the run list.
#
# MCV3 wf-fix-bugs v9 — Wave 3.7 (QD9 Multi-App Browser Isolation)
# Reuses: wf-fix-detect-base-url.sh (W1.2) + browser lock pattern from _shared.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Argument parsing ────────────────────────────────────────────────────────

PROJECT_ROOT=""
SESSION_DIR=""
APPS_FILTER=""      # comma-separated app name allowlist; empty = all web apps
OUTPUT_FILE=""
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --project-root=*) PROJECT_ROOT="${arg#*=}" ;;
    --session-dir=*)  SESSION_DIR="${arg#*=}" ;;
    --apps=*)         APPS_FILTER="${arg#*=}" ;;
    --output=*)       OUTPUT_FILE="${arg#*=}" ;;
    --dry-run)        DRY_RUN=true ;;
    --help|-h)
      grep '^#' "$0" | head -40 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "WARN: Unknown argument: $arg" >&2
      ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: --project-root is required" >&2
  exit 1
fi

if [[ -z "$SESSION_DIR" ]]; then
  echo "ERROR: --session-dir is required" >&2
  exit 1
fi

# Normalize paths (remove trailing slash)
PROJECT_ROOT="${PROJECT_ROOT%/}"
SESSION_DIR="${SESSION_DIR%/}"

# ─── Priority order (W3.7 spec) ──────────────────────────────────────────────
# Apps earlier in this list get lower priority number → run first.
# Apps not in this list get priority 999 → run after all priority apps.

declare -A PRIORITY_MAP
PRIORITY_MAP["erp-web"]=1
PRIORITY_MAP["smarttax-web"]=2
PRIORITY_MAP["erktransport.com"]=3
PRIORITY_MAP["web-customer"]=4
PRIORITY_MAP["backend"]=5
PRIORITY_MAP["api"]=6

# ─── JSON helpers ─────────────────────────────────────────────────────────────

json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ'
}

# ─── Session Isolation (Part 7 migration) ──────────────────────────────
# Browser isolation handled by playwright-session.js (unique port per session).
# KHONG con browser-singleton.lock — mỗi session có browser riêng.

# ─── Step 1: Detect all apps via W1.2 helper ─────────────────────────────────

DETECT_SCRIPT="$SCRIPT_DIR/wf-fix-detect-base-url.sh"
if [[ ! -f "$DETECT_SCRIPT" ]]; then
  echo "ERROR: wf-fix-detect-base-url.sh not found at: $DETECT_SCRIPT" >&2
  exit 1
fi

echo "[coordinator] Detecting apps in: $PROJECT_ROOT" >&2
DETECT_OUTPUT=$(bash "$DETECT_SCRIPT" --project-root="$PROJECT_ROOT" 2>/dev/null) || {
  echo "ERROR: wf-fix-detect-base-url.sh failed" >&2
  exit 1
}

# Validate JSON output
if ! echo "$DETECT_OUTPUT" | jq '.' >/dev/null 2>&1; then
  echo "ERROR: wf-fix-detect-base-url.sh returned invalid JSON" >&2
  exit 1
fi

TOTAL_ALL=$(echo "$DETECT_OUTPUT" | jq '.apps | length')
SKIPPED_MOBILE=$(echo "$DETECT_OUTPUT" | jq '[.apps[] | select(.status == "mobile_skip")] | length')

echo "[coordinator] Detected $TOTAL_ALL apps, $SKIPPED_MOBILE mobile (skip)" >&2

# ─── Step 2: Filter mobile_skip + apply --apps allowlist ─────────────────────

WEB_APPS_JSON=$(echo "$DETECT_OUTPUT" | jq '[.apps[] | select(.status != "mobile_skip")]')

if [[ -n "$APPS_FILTER" ]]; then
  IFS=',' read -ra ALLOWED_APPS_ARR <<< "$APPS_FILTER"
  ALLOWED_JSON=$(printf '"%s",' "${ALLOWED_APPS_ARR[@]}")
  ALLOWED_JSON="[${ALLOWED_JSON%,}]"
  WEB_APPS_JSON=$(echo "$WEB_APPS_JSON" | jq \
    --argjson allowed "$ALLOWED_JSON" \
    '[.[] | select(.name as $n | ($allowed | index($n)) != null)]')
fi

# ─── Step 3: Sort by priority ─────────────────────────────────────────────────
# Use jq to assign priority value and sort

ORDERED_APPS_JSON=$(echo "$WEB_APPS_JSON" | jq '
  map(
    . + {
      _prio: (
        if .name == "erp-web" then 1
        elif .name == "smarttax-web" then 2
        elif .name == "erktransport.com" then 3
        elif .name == "web-customer" then 4
        elif .name == "backend" then 5
        elif .name == "api" then 6
        else 999
        end
      )
    }
  )
  | sort_by(._prio)
  | map(del(._prio))
')

QUEUED_COUNT=$(echo "$ORDERED_APPS_JSON" | jq 'length')
echo "[coordinator] Web apps queued: $QUEUED_COUNT (sequential order)" >&2

# Print ordered list for log
echo "$ORDERED_APPS_JSON" | jq -r '.[] | "  [\(.name)] \(.base_url) (\(.framework))"' >&2

# ─── Step 4: Build coordinator-status.json (initial plan) ────────────────────

STATUS_FILE="${OUTPUT_FILE:-$SESSION_DIR/coordinator-status.json}"

# Build apps_queued array with status=queued (skip_missing if base_url empty)
APPS_QUEUED_JSON=$(echo "$ORDERED_APPS_JSON" | jq '
  map({
    name: .name,
    base_url: .base_url,
    framework: .framework,
    status: (if (.base_url == "" or .base_url == null) then "skip_missing" else "queued" end),
    dev_server_result: null,
    qd9_signals_count: 0,
    started_at: null,
    completed_at: null,
    error: null
  })
')

GENERATED_AT=$(now_iso)

jq -n \
  --arg version "1.0.0" \
  --arg root "$(json_str "$PROJECT_ROOT")" \
  --arg session "$(json_str "$SESSION_DIR")" \
  --argjson total "$TOTAL_ALL" \
  --argjson skipped "$SKIPPED_MOBILE" \
  --argjson queued "$QUEUED_COUNT" \
  --argjson apps "$APPS_QUEUED_JSON" \
  --arg lock "$(json_str "$BROWSER_LOCK")" \
  --arg gen "$GENERATED_AT" \
  '{
    coordinator_version: $version,
    project_root: $root,
    session_dir: $session,
    total_apps_detected: $total,
    skipped_mobile: $skipped,
    apps_queued_count: $queued,
    apps_queued: $apps,
    browser_lock_path: $lock,
    status: "planned",
    generated_at: $gen,
    started_at: null,
    completed_at: null
  }' > "$STATUS_FILE"

echo "[coordinator] Plan written: $STATUS_FILE" >&2

# ─── Dry-run: output plan and exit ───────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[coordinator] --dry-run: execution skipped" >&2
  cat "$STATUS_FILE"
  exit 0
fi

# ─── Step 5: Sequential execution — bash-side probes per app ─────────────────
# Playwright-based probes (console-network-monitor, auth-aware-smoke, etc.) are
# driven by the Claude orchestrator, which reads coordinator-status.json to know
# the app order and BASE_URL per app.
#
# This step runs only the bash-side dev-server-bootstrap probe per app to:
#   (a) verify the dev server is up before orchestrator attempts Playwright
#   (b) enforce browser lock sequencing (max 1 browser instance globally)

# Mark overall status as running
jq --arg ts "$GENERATED_AT" '.status = "running" | .started_at = $ts' \
  "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

# Read ordered app names + urls from plan
readarray -t APP_NAMES  < <(echo "$APPS_QUEUED_JSON" | jq -r '.[].name')
readarray -t APP_URLS   < <(echo "$APPS_QUEUED_JSON" | jq -r '.[].base_url')
readarray -t APP_INIT_STATUS < <(echo "$APPS_QUEUED_JSON" | jq -r '.[].status')

DEV_PROBE_SCRIPT="$SCRIPT_DIR/wf-fix-probe-dev-server.sh"

for i in "${!APP_NAMES[@]}"; do
  app_name="${APP_NAMES[$i]}"
  base_url="${APP_URLS[$i]}"
  initial_status="${APP_INIT_STATUS[$i]}"

  # Skip apps with no base_url
  if [[ "$initial_status" == "skip_missing" ]]; then
    echo "[coordinator] Skipping $app_name — no base_url detected" >&2
    jq --arg name "$app_name" --arg ts "$(now_iso)" \
      '(.apps_queued[] | select(.name == $name)).status = "skip_missing" |
       (.apps_queued[] | select(.name == $name)).completed_at = $ts' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    continue
  fi

  echo "[coordinator] Processing: $app_name ($base_url)" >&2

  # Mark app as running
  jq --arg name "$app_name" --arg ts "$(now_iso)" \
    '(.apps_queued[] | select(.name == $name)).status = "running" |
     (.apps_queued[] | select(.name == $name)).started_at = $ts' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"


  # Run dev-server-bootstrap probe (bash-side) for this app
  dev_server_result="skip_no_script"
  if [[ -f "$DEV_PROBE_SCRIPT" ]]; then
    if bash "$DEV_PROBE_SCRIPT" \
         --base-url="$base_url" \
         --session-dir="$SESSION_DIR" \
         --app-name="$app_name" 2>/dev/null; then
      dev_server_result="ok"
    else
      dev_server_result="fail"
    fi
  fi


  # Update app status: done
  jq --arg name "$app_name" --arg ts "$(now_iso)" --arg ds "$dev_server_result" \
    '(.apps_queued[] | select(.name == $name)).status = "done" |
     (.apps_queued[] | select(.name == $name)).dev_server_result = $ds |
     (.apps_queued[] | select(.name == $name)).completed_at = $ts' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  echo "[coordinator] $app_name: dev_server=$dev_server_result" >&2
done

# ─── Finalize status ─────────────────────────────────────────────────────────

FINAL_TS=$(now_iso)
jq --arg ts "$FINAL_TS" '.status = "completed" | .completed_at = $ts' \
  "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "[coordinator] Completed. Status: $STATUS_FILE" >&2
cat "$STATUS_FILE"
