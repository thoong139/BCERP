#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-dev-server.sh — QD9 Dev Server Bootstrap Probe (P-QD9-dev-server-bootstrap)
#
# Xac nhan dev server da start va accessible truoc khi browser probes chay.
# Neu server chua chay: spawn background process tu package.json scripts.dev,
# doi max 30s, emit signal E095 neu fail.
#
# Usage:
#   bash wf-fix-probe-dev-server.sh \
#     --session-dir=<path> \
#     [--base-url=<http://localhost:PORT>] \
#     [--app-dir=<relative-app-dir-under-project-root>] \
#     [--project-root=<path>] \
#     [--max-wait=30]
#
# Output:
#   $SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/dev-server-state.json  — {status, pid, url, spawned}
#   $SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/raw/P-QD9-dev-server-bootstrap.jsonl  — signals nếu fail
#
# Exit codes: 0 success (server accessible), 0 with signal emit (fail — signal ghi vao JSONL)
#
# MCV3 wf-fix-bugs v9 — Wave 1.4 (QD9 Runtime Health)
# Procedure: .claude/skills/workflow/wf-fix-runtime-health/procedures/probes/P-QD9-dev-server-bootstrap.md


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers (wf-fix-common.sh)
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
if [[ -f "$COMMON_SH" ]]; then
  # shellcheck source=wf-fix-common.sh
  source "$COMMON_SH"
else
  echo "ERROR: wf-fix-common.sh not found at $COMMON_SH" >&2
  exit 1
fi

# Defensive runtime cap (SB-01 v7.4.0): chong hang tren codebases lon
with_runtime_cap "$@"

# ─── Argument parsing ────────────────────────────────────────────────────────

PROBE_ID="P-QD9-dev-server-bootstrap"
SESSION_DIR=""
BASE_URL=""
APP_DIR=""
PROJECT_ROOT="."
MAX_WAIT=30

for arg in "$@"; do
  case "$arg" in
    --session-dir=*)  SESSION_DIR="${arg#*=}" ;;
    --base-url=*)     BASE_URL="${arg#*=}" ;;
    --app-dir=*)      APP_DIR="${arg#*=}" ;;
    --project-root=*) PROJECT_ROOT="${arg#*=}" ;;
    --max-wait=*)     MAX_WAIT="${arg#*=}" ;;
    --help|-h)
      grep '^#' "$0" | head -20 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
  esac
done

# Validate SESSION_DIR
if [[ -z "$SESSION_DIR" ]]; then
  echo "ERROR: --session-dir bắt buộc" >&2
  exit 1
fi

# ─── Setup dirs ───────────────────────────────────────────────────────────────

LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"
RAW_DIR="$LANE_DIR/raw"
DEV_SERVER_STATE="$LANE_DIR/dev-server-state.json"

mkdir -p "$RAW_DIR"

# ─── Signal emit (inline, no browser location) ──────────────────────────────

emit_signal() {
  local severity="$1"
  local title="$2"
  local description="$3"
  local reason="${4:-}"

  jq -n \
    --arg probe "$PROBE_ID" \
    --arg sev "$severity" \
    --arg title "$title" \
    --arg desc "$description" \
    --arg reason "$reason" \
    '{
      "$schema": "signal-v2",
      probe_id: $probe,
      dimension_id: "QD9",
      signal_type: "dev_server_bootstrap_fail",
      severity: $sev,
      title: $title,
      description: $desc,
      location: {},
      evidence: [{"type": "log_excerpt", "content": $reason}],
      cdg_flags: [],
      fixability: "agent_fix"
    }' >> "$RAW_DIR/${PROBE_ID}.jsonl"
  echo "SIGNAL [$severity]: $title" >&2
}

# ─── Step 1: Resolve BASE_URL ────────────────────────────────────────────────

if [[ -z "$BASE_URL" ]]; then
  echo "INFO: BASE_URL chua set, chay wf-fix-detect-base-url.sh..." >&2
  DETECT_SCRIPT="$SCRIPT_DIR/wf-fix-detect-base-url.sh"
  if [[ -f "$DETECT_SCRIPT" ]]; then
    DETECT_JSON=$(bash "$DETECT_SCRIPT" --project-root="$PROJECT_ROOT" 2>/dev/null || echo '{"apps":[]}')
    BASE_URL=$(echo "$DETECT_JSON" | jq -r \
      '.apps[] | select(.status != "mobile_skip" and .base_url != "") | .base_url' \
      2>/dev/null | head -1 || true)
    if [[ -z "${APP_DIR:-}" ]]; then
      APP_DIR=$(echo "$DETECT_JSON" | jq -r \
        '.apps[] | select(.status != "mobile_skip" and .base_url != "") | .name' \
        2>/dev/null | head -1 || true)
    fi
  fi
fi

if [[ -z "${BASE_URL:-}" ]] || [[ "$BASE_URL" == "null" ]]; then
  emit_signal "HIGH" \
    "App URL khong detect duoc — browser probes se bi skip (E094)" \
    "Khong tim duoc URL app web. Cung cap --base-url hoac kiem tra config: package.json scripts.dev, vite.config.ts, next.config.mjs." \
    "E094_BASE_URL_UNKNOWN"
  atomic_write_json "$DEV_SERVER_STATE" \
    '{"status":"skipped","reason":"E094_BASE_URL_UNKNOWN","pid":null,"url":null,"spawned":false}'
  exit 0
fi

echo "INFO: BASE_URL=$BASE_URL" >&2

# ─── Step 2: HTTP HEAD check ─────────────────────────────────────────────────

HTTP_STATUS="000"
if command -v curl >/dev/null 2>&1; then
  HTTP_STATUS=$(curl --max-time 5 --silent \
    -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null || echo "000")
else
  emit_signal "HIGH" \
    "curl khong co — khong the kiem tra dev server (E095)" \
    "curl la required cho dev server health check. Cai curl de chay QD9 probes." \
    "E095_CURL_MISSING"
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc --arg url "$BASE_URL" \
      '{status:"fail",reason:"E095_CURL_MISSING",pid:null,url:$url,spawned:false}')"
  exit 0
fi

if echo "$HTTP_STATUS" | grep -qE '^[23]'; then
  echo "INFO: Dev server da accessible: $BASE_URL (HTTP $HTTP_STATUS) — skip spawn" >&2
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc --arg url "$BASE_URL" \
      '{status:"already_running",pid:null,url:$url,spawned:false}')"
  exit 0
fi

echo "INFO: Dev server chua accessible (HTTP $HTTP_STATUS) — can spawn" >&2

# ─── Step 3: Tim package.json va spawn background ────────────────────────────

PKG_JSON=""
# Thu priority: apps/{APP_DIR}/ → apps/*/ (first match) → project root
CANDIDATES=()
[[ -n "${APP_DIR:-}" ]] && CANDIDATES+=("$PROJECT_ROOT/apps/$APP_DIR/package.json")
# Quet them: apps/*/ (tim cai dau tien co scripts.dev)
for f in "$PROJECT_ROOT"/apps/*/package.json; do
  [[ -f "$f" ]] && CANDIDATES+=("$f")
done
CANDIDATES+=("$PROJECT_ROOT/package.json")

for candidate in "${CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    # Kiem tra co scripts.dev hoac scripts.start khong
    HAS_DEV=$(jq -r '.scripts.dev // .scripts.start // empty' "$candidate" 2>/dev/null || true)
    if [[ -n "$HAS_DEV" ]]; then
      PKG_JSON="$candidate"
      break
    fi
  fi
done

DEV_CMD=""
if [[ -n "$PKG_JSON" ]]; then
  DEV_CMD=$(jq -r '.scripts.dev // .scripts.start // empty' "$PKG_JSON" 2>/dev/null || true)
fi

if [[ -z "${DEV_CMD:-}" ]]; then
  emit_signal "HIGH" \
    "Khong tim duoc dev server command — browser probes se bi skip (E095)" \
    "Khong tim thay scripts.dev hoac scripts.start trong cac package.json da quet: ${CANDIDATES[*]:-none}. Hay start thu cong truoc khi chay /wf-fix-bugs." \
    "E095_NO_DEV_CMD"
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc --arg url "$BASE_URL" \
      '{status:"fail",reason:"E095_NO_DEV_CMD",pid:null,url:$url,spawned:false}')"
  exit 0
fi

PKG_DIR="$(dirname "$PKG_JSON")"
echo "INFO: Spawning dev server: [npm run dev] in $PKG_DIR" >&2

# Spawn background process
# Su dung npm run dev de khoi dong (DEV_CMD co the la "next dev", "vite", v.v.)
(cd "$PKG_DIR" && npm run dev >/dev/null 2>&1) &
DEV_SERVER_PID=$!
echo "INFO: Spawned PID=$DEV_SERVER_PID" >&2

# Cleanup trap khi probe session ket thuc (E095 path hoac error)
# Step 6 se clear trap neu bootstrap thanh cong
cleanup_dev_server() {
  local pid="${DEV_SERVER_PID:-}"
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  echo "INFO: Dev server cleanup PID=${pid:-none}" >&2
}
trap cleanup_dev_server EXIT

# ─── Step 4: Retry HTTP check max MAX_WAIT seconds ───────────────────────────

ELAPSED=0
BOOTSTRAPPED=0

while [[ "$ELAPSED" -lt "$MAX_WAIT" ]]; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  HTTP_STATUS=$(curl --max-time 3 --silent \
    -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null || echo "000")
  if echo "$HTTP_STATUS" | grep -qE '^[23]'; then
    BOOTSTRAPPED=1
    echo "INFO: Dev server ready sau ${ELAPSED}s (HTTP $HTTP_STATUS)" >&2
    break
  fi
  echo "DEBUG: Waiting ${ELAPSED}/${MAX_WAIT}s — HTTP $HTTP_STATUS" >&2
done

# ─── Step 5: Emit signal neu bootstrap fail ───────────────────────────────────

if [[ "$BOOTSTRAPPED" == "0" ]]; then
  emit_signal "HIGH" \
    "Dev server khong start sau ${MAX_WAIT}s — browser probes se bi skip (E095)" \
    "Chay [npm run dev] (PID=$DEV_SERVER_PID, pkg=$PKG_JSON) nhung $BASE_URL van unreachable sau ${MAX_WAIT}s. Kiem tra: port conflict, missing node_modules, env vars. Browser probes (console-monitor, auth-smoke) se bi skip." \
    "E095_TIMEOUT: curl HTTP=000 sau ${MAX_WAIT}s retry"
  atomic_write_json "$DEV_SERVER_STATE" \
    "$(jq -nc \
      --arg url "$BASE_URL" \
      --argjson pid "$DEV_SERVER_PID" \
      --argjson waited "$MAX_WAIT" \
      '{status:"fail",reason:"E095_TIMEOUT",pid:$pid,url:$url,spawned:true,waited_seconds:$waited}')"
  # Trap tu Step 3 se kill pid khi exit
  exit 0
fi

# ─── Step 6: Write dev-server-state.json cho downstream probes ────────────────

atomic_write_json "$DEV_SERVER_STATE" \
  "$(jq -nc \
    --arg url "$BASE_URL" \
    --argjson pid "$DEV_SERVER_PID" \
    '{status:"running",pid:$pid,url:$url,spawned:true}')"
echo "INFO: dev-server-state.json OK — pid=$DEV_SERVER_PID url=$BASE_URL" >&2

# Giai phong trap: server thanh cong, orchestrator chiu trach nhiem
# Orchestrator doc pid tu dev-server-state.json va kill khi session xong:
#   kill $(jq -r '.pid // empty' "$DEV_SERVER_STATE") 2>/dev/null || true
trap - EXIT
echo "INFO: Trap cleared — dev server PID=$DEV_SERVER_PID dang chay (orchestrator manage)" >&2
exit 0
