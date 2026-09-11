# Shared Probe Conventions — QD9 Runtime Health Verification

Loaded by all 7 probe spec files trong cung directory. Dinh nghia variables, signal emit pattern, session-isolated Playwright (bash-level), CI-ROUTE reference.

---

## Common Variables

```bash
LANE_NAME="wf-fix-runtime-health"
DIMENSION="QD9"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health"
RAW_DIR="$LANE_DIR/raw"
SIGNALS_FILE="$LANE_DIR/signals.json"
DEV_SERVER_STATE="$LANE_DIR/dev-server-state.json"
AUTH_SESSION="$LANE_DIR/auth-session.json"
FLOW_UNRELIABLE="$LANE_DIR/flow-unreliable.json"

# Session-isolated Playwright (bash-level, khong con phu thuoc MCP)
SHARED_DIR=".claude/skills/workflow/_shared"
SESSION_FILE="$SESSION_DIR/playwright-session.json"

# v10.2 — Propagate flags --show-browser / --mobile / --device tu orchestrator
# (orchestrator export SHOW_BROWSER, MOBILE_MODE, MOBILE_DEVICE qua env hoac tu fix-status.json)
if [ -z "${SHOW_BROWSER:-}" ] && [ -f "$SESSION_DIR/fix-status.json" ]; then
  SHOW_BROWSER=$(jq -r '.show_browser // false' "$SESSION_DIR/fix-status.json" 2>/dev/null)
  MOBILE_MODE=$(jq -r '.mobile_mode // false' "$SESSION_DIR/fix-status.json" 2>/dev/null)
  MOBILE_DEVICE=$(jq -r '.mobile_device // "iPhone 14"' "$SESSION_DIR/fix-status.json" 2>/dev/null)
fi
SHOW_BROWSER="${SHOW_BROWSER:-false}"
MOBILE_MODE="${MOBILE_MODE:-false}"
MOBILE_DEVICE="${MOBILE_DEVICE:-iPhone 14}"

# Build PW_CMD voi flag propagation
PW_BASE_ARGS="--session-dir=$SESSION_DIR"
PW_LAUNCH_ARGS=""
[ "$SHOW_BROWSER" = "true" ] && PW_LAUNCH_ARGS="$PW_LAUNCH_ARGS --show-browser=true"
[ "$MOBILE_MODE" = "true" ] && PW_LAUNCH_ARGS="$PW_LAUNCH_ARGS --mobile=true --device=\"$MOBILE_DEVICE\""

PW_CMD="node $SHARED_DIR/playwright-session.js $PW_BASE_ARGS"
PW_LAUNCH_CMD="node $SHARED_DIR/playwright-session.js $PW_BASE_ARGS $PW_LAUNCH_ARGS"
```

## Playwright Session (Bash-Level) — Thay the MCP Playwright

Moi `wf-fix-bugs` session co browser Chromium rieng biet qua port + user-data-dir isolation.
Browser duoc launch 1 lan, giu alive suot session. Cac probe goi qua `$PW_CMD`.

### Launch + Close

```bash
# Launch browser (goi 1 lan o probe dau tien — cac probe sau thay "already_running")
# v10.2: dung PW_LAUNCH_CMD voi flags --show-browser/--mobile/--device propagated tu orchestrator
pw_launch() {
  local result
  result=$($PW_LAUNCH_CMD --action=launch 2>&1) || {
    echo "ERROR: Cannot launch browser: $result" >&2
    return 1
  }
  echo "$result" | jq -r '.status' | grep -qE 'launched|already_running' || {
    echo "ERROR: Browser launch failed: $result" >&2
    return 1
  }
  # Log launch mode cho dieu tra
  local mode=$(echo "$result" | jq -r '.mode // "headless"')
  local mobile=$(echo "$result" | jq -r '.mobile // false')
  echo "INFO: Browser launched (mode=$mode, mobile=$mobile)" >&2
  return 0
}

# Dong browser khi session ket thuc
pw_close() {
  $PW_CMD --action=close 2>/dev/null || true
}

# Usage:
#   pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
#   trap "pw_close" EXIT
```

### Tool Wrappers — Goi tu bash, parse JSON output

```bash
# Navigate toi URL → { status, url, title, redirected }
pw_navigate() {
  $PW_CMD --action=navigate --url="$1" ${2:+--wait-until="$2"} 2>&1
}

# Snapshot DOM → { snapshot, links[], buttons[], forms[], url }
pw_snapshot() {
  $PW_CMD --action=snapshot ${1:+--selector="$1"} 2>&1
}

# Screenshot → { path }
pw_screenshot() {
  mkdir -p "$(dirname "$1")"
  $PW_CMD --action=screenshot --path="$1" ${2:+--full-page="$2"} 2>&1
}

# Evaluate JS → { result }
pw_evaluate() {
  $PW_CMD --action=evaluate --expr="$1" 2>&1
}

# Click element → { clicked, selector, url, title }
pw_click() {
  $PW_CMD --action=click --selector="$1" 2>&1
}

# Type text vao input → { filled, selector, text }
pw_type() {
  $PW_CMD --action=type --selector="$1" --text="$2" 2>&1
}

# Fill nhieu fields cung luc → { filled: [...] }
pw_fill_form() {
  $PW_CMD --action=fill_form --fields="$1" 2>&1
}

# Press key → { pressed }
pw_press_key() {
  $PW_CMD --action=press_key --key="$1" 2>&1
}

# Select dropdown option → { selected }
pw_select() {
  $PW_CMD --action=select --selector="$1" --values="$2" 2>&1
}

# Collect console errors → { errors: [...] }
pw_console() {
  $PW_CMD --action=console 2>&1
}

# Collect network failures (status >= 400) → { failures: [...] }
pw_network() {
  $PW_CMD --action=network 2>&1
}

# Wait time hoac selector → { waited }
pw_wait() {
  $PW_CMD --action=wait ${1:+--time="$1"} ${2:+--selector="$2"} 2>&1
}

# List tabs → { tabs: [{url, title}] }
pw_tabs() {
  $PW_CMD --action=tabs 2>&1
}

# Navigate back → { url, title }
pw_back() {
  $PW_CMD --action=back 2>&1
}

# Hover → { hovered }
pw_hover() {
  $PW_CMD --action=hover --selector="$1" 2>&1
}

# Resize viewport → { resized, viewport }
pw_resize() {
  $PW_CMD --action=resize --width="$1" --height="$2" 2>&1
}

# Upload file → { uploaded }
pw_upload_file() {
  $PW_CMD --action=upload_file --selector="$1" --paths="$2" 2>&1
}

# Close current page → { closed }
pw_close_page() {
  $PW_CMD --action=close_page 2>&1
}
```

## Signal Emit Pattern (Browser Runtime)

Theo `_shared/lane/signal-emit.md` — atomic JSON merge:

```bash
emit_signal_browser() {
  local probe_id="$1"
  local signal_type="$2"   # runtime_console_error | runtime_network_failure | runtime_uncaught_exception | ui_cta_no_response | auth_login_failed | spa_route_unreachable | form_validation_missing | form_validation_bypass
  local severity="$3"
  local title="$4"
  local description="$5"
  local page_url="$6"
  local evidence_type="$7"  # screenshot | log_excerpt | network_trace | dom_snapshot
  local evidence_content="$8"
  local screenshot_path="${9:-null}"

  jq -n \
    --arg pid "$probe_id" \
    --arg st "$signal_type" \
    --arg sev "$severity" \
    --arg title "$title" \
    --arg desc "$description" \
    --arg url "$page_url" \
    --arg ev_type "$evidence_type" \
    --arg ev_content "$evidence_content" \
    --argjson shot "$screenshot_path" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD9",
      signal_type: $st,
      severity: $sev,
      title: $title,
      description: $desc,
      location: {url: $url},
      evidence: [{type: $ev_type, content: $ev_content}],
      screenshot: $shot,
      cdg_flags: [],
      fixability: "agent_fix"
    }' >> "$RAW_DIR/$probe_id.jsonl"
}

emit_signal_no_location() {
  local probe_id="$1" severity="$2" title="$3" description="$4" cdg_flags="$5"
  jq -n \
    --arg pid "$probe_id" --arg sev "$severity" \
    --arg title "$title" --arg desc "$description" \
    --argjson cdg "$cdg_flags" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD9",
      severity: $sev,
      title: $title,
      description: $desc,
      location: {},
      evidence: [],
      cdg_flags: $cdg,
      fixability: "agent_fix"
    }' >> "$RAW_DIR/$probe_id.jsonl"
}
```

## Browser Event Listener Injection

Console errors + network failures + page errors duoc playwright-session.js tu dong thu thap qua event listeners injected trong `connectAndAct()`. Khong can inject thu cong.

Khi probe can doc collected errors:

```bash
# Console errors duoc playwright-session.js tu dong collect
CONSOLE_RESULT=$(pw_console)
CONSOLE_ERRORS=$(echo "$CONSOLE_RESULT" | jq -r '.errors[]? // empty')

# Network failures (status >= 400)
NETWORK_RESULT=$(pw_network)
NETWORK_FAILURES=$(echo "$NETWORK_RESULT" | jq -r '.failures[]? // empty')

# Uncaught exceptions: inject monitoring script vao page truoc khi navigate
# playwright-session.js runNavigate tu dong inject __MCV3_BROWSER_MONITOR__ listeners
UNCAUGHT_LIST=$(pw_evaluate "return (window.__MCV3_BROWSER_MONITOR__?.pageErrors || []).splice(0)")
```

## Playwright Tool Mapping (Old MCP → New Bash-Level)

| Task | Old (MCP) | New (Bash-Level) |
|------|-----------|-----------------|
| Navigate | `mcp__plugin_playwright_playwright__browser_navigate` | `pw_navigate "$URL"` |
| DOM snapshot | `mcp__plugin_playwright_playwright__browser_snapshot` | `pw_snapshot` |
| Screenshot | `mcp__plugin_playwright_playwright__browser_take_screenshot` | `pw_screenshot "$PATH"` |
| Click | `mcp__plugin_playwright_playwright__browser_click` | `pw_click "$SELECTOR"` |
| Fill form | `mcp__plugin_playwright_playwright__browser_fill_form` | `pw_fill_form "$FIELDS_JSON"` |
| Type text | `mcp__plugin_playwright_playwright__browser_type` | `pw_type "$SELECTOR" "$TEXT"` |
| Press key | `mcp__plugin_playwright_playwright__browser_press_key` | `pw_press_key "$KEY"` |
| Console msgs | `mcp__plugin_playwright_playwright__browser_console_messages` | `pw_console` |
| Network reqs | `mcp__plugin_playwright_playwright__browser_network_requests` | `pw_network` |
| Wait | `mcp__plugin_playwright_playwright__browser_wait_for` | `pw_wait "$TIME"` |
| Evaluate JS | `mcp__plugin_playwright_playwright__browser_evaluate` | `pw_evaluate "$EXPR"` |
| Tabs | `mcp__plugin_playwright_playwright__browser_tabs` | `pw_tabs` |
| Back | `mcp__plugin_playwright_playwright__browser_navigate_back` | `pw_back` |
| Dialog | `mcp__plugin_playwright_playwright__browser_handle_dialog` | N/A (auto-accept trong playwright-session.js) |
| Close | `mcp__plugin_playwright_playwright__browser_close` | `pw_close` |

## CI-ROUTE Reference (QD9 Primary)

| Task | CI Tool | Fallback |
|------|---------|---------|
| Locate auth handlers (login form) | **Serena** `find_symbol("login", "auth", "signin")` | Grep "login" |
| Trace navigation graph | **GitNexus** `query("navigation, route, link")` | Parse `<a href>` |
| Map console error → source | **Serena** `find_symbol` theo file:line trong stack | Grep |
| Find SPA router config | **Serena** `find_symbol("Routes", "createBrowserRouter", "pages/")` | Glob |
| Trace feature → UI route | **GitNexus** `query("{feature_id}")` | Grep REQ-ID |
| Find form validators | **Serena** `find_symbol` Zod/Yup/Joi schemas | Grep |

## Error Codes (QD9)

| Code | Name | Description |
|------|------|-------------|
| E094 | BASE_URL_unknown | Khong detect duoc BASE_URL — browser probes bi skip |
| E095 | dev_server_bootstrap_fail | Dev server khong start duoc — browser probes bi skip |
| E096 | browser_unavailable | Khong launch duoc browser (playwright-session.js launch fail) |
| E097 | auth_login_failed | Login that bai sau 2 lan thu |
| E098 | feature_route_broken | Feature impl_status=done nhung route bi broken |

## Severity Quick Reference (QD9)

| Signal Type | Dieu kien | Severity |
|-------------|-----------|----------|
| runtime_uncaught_exception | pageerror bat ky | CRITICAL |
| dev_server_bootstrap_fail | Timeout 30s | HIGH |
| auth_login_failed | 2 lan lien tiep | HIGH |
| runtime_network_failure | HTTP 5xx | HIGH |
| feature_route_broken | impl_status=done nhung broken | HIGH |
| ui_cta_obstructed | Overlay che button co handler (v10.2) | HIGH |
| runtime_console_error | console.error() | MEDIUM |
| runtime_network_failure | HTTP 4xx non-auth | MEDIUM |
| spa_route_unreachable | Route trong router config | MEDIUM |
| ui_cta_no_response | Button khong phan ung | MEDIUM |
| ui_cta_disabled_unexpected | Disabled/pointer-events:none/fieldset disabled bat thuong (v10.2) | MEDIUM |
| form_validation_missing | Submit sai ma khong co error | MEDIUM |
| form_validation_bypass | Form chap nhan invalid data (URL doi/success) | HIGH |
| ui_cta_hidden_with_handler | Opacity rat thap nhung co handler (v10.2) | LOW |

## Output Truncation (CORE-031 + P3)

| Content | Max |
|---------|-----|
| Console error message | 500 chars |
| Stack trace | 20 frames |
| DOM snapshot text | 50KB |
| Network request body | 1KB |
| Screenshot | PNG <= 1MB |

## CDG Flags (QD9)

QD9 khong co CDG flags dac biet. Tat ca signals emit voi `cdg_flags: []`.
Neu phat hien loi CRITICAL tren payment/checkout page → hand-off sang QD3 (security) qua signal metadata.

## Common Self-Check

- Confidence cao chi khi co browser evidence cu the (screenshot + log/network excerpt).
- Severity follow SKILL.md severity_rules.
- Probe nen skip neu dependency check fail (BASE_URL, browser launch fail E096).
- Luon ghi log SKIP co ly do.
