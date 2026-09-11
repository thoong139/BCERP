# F7 wf-e2e-scenario — Shared Protocols (v1.1.0 — T1.3 Tier 1 Refactor)

## Playwright Retry Pattern (T1.3 — CORE: BLOCKED khi fail, không fallback curl)

```bash
playwright_retry() {
  local ACTION_DESC="$1"  # mô tả hành động để log
  local MAX_ATTEMPTS="${2:-3}"

  for ATTEMPT in $(seq 1 "$MAX_ATTEMPTS"); do
    # Thực hiện action (caller truyền vào qua $ACTION)
    if eval "$ACTION"; then
      return 0  # Thành công
    fi

    if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
      SLEEP_SEC=$((ATTEMPT * 5))  # 5s, 10s, 15s
      log_error "E075" "playwright_retry" "Attempt $ATTEMPT/$MAX_ATTEMPTS fail: $ACTION_DESC — sleep ${SLEEP_SEC}s"
      
      # Browser reset giữa các lần retry
      mcp__plugin_playwright_playwright__browser_close 2>/dev/null || true
      sleep "$SLEEP_SEC"
      
      # Re-navigate tới target URL sau browser reset
      if [ -n "${TARGET_URL:-}" ]; then
        mcp__plugin_playwright_playwright__browser_navigate --url="$TARGET_URL" 2>/dev/null || true
      fi
    fi
  done

  # Exhausted — KHÔNG fallback sang curl hoặc code-only
  log_error "E075" "playwright_retry" "BLOCKED: $ACTION_DESC exhausted $MAX_ATTEMPTS attempts"
  echo "BLOCKED"
  return 1
}

# QUYẾT ĐỊNH KỸ THUẬT (WHY BLOCKED, không fallback):
# Fallback curl/code-only cho browser tests tạo ra false confidence — curl không kiểm tra
# rendering, RBAC UI, JavaScript validation, hay UX flow thực sự. Kết quả "PASS" từ curl
# không có giá trị cho E2E verification. BLOCKED buộc người dùng điều tra infrastructure
# thay vì âm thầm bỏ qua lỗi browser.
```

## Strict Evidence Check (T1.5 --strict-evidence)

```bash
check_strict_evidence() {
  local SCREENSHOT_PATH="$1"
  local STRICT="${STRICT_EVIDENCE:-true}"  # ON by default

  if [ "$STRICT" = "true" ]; then
    if [ ! -f "$SCREENSHOT_PATH" ]; then
      log_error "E077" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH bị thiếu — BLOCKED"
      echo "evidence_missing"
      return 1
    fi

    SIZE=$(wc -c < "$SCREENSHOT_PATH" 2>/dev/null || echo 0)
    if [ "$SIZE" -lt 1024 ]; then  # < 1KB
      log_error "E077" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH quá nhỏ (${SIZE} bytes < 1KB) — BLOCKED"
      echo "evidence_missing"
      return 1
    fi
  fi
  return 0
}
```



## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F7_DIR = $SESSION_DIR/F7-scenario/
$SCENARIO = $SESSION_DIR/outputs/test-scenario.md
$REPORT = $F7_DIR/scenario-test-report.md
$STATUS = $F7_DIR/status.json
$SCREENSHOTS = $SESSION_DIR/screenshots/
$LOCK = $SESSION_DIR/_locks/browser-mcp.lock

# Failure Analysis Engine (v1.2.0)
$RESOLUTION_ACCUMULATOR = ""       # Tích lũy markdown rows cho resolution-report.md
$FAILURE_ANALYZER_LOADED = false   # Lazy-load flag — load một lần, dùng lại nhiều scenario
$FAIL_COUNT = 0                    # Đếm tổng scenario FAIL trong session (sau auto-fix)
$AUTO_FIX_COUNT = 0                # Đếm số scenario được auto-fix thành công
$RESOLUTION_REPORT = $F7_DIR/resolution-report.md
```

## PRE-GATE Forensic (CORE-011)

```bash
# T1: scenario file exists
test -f "$SCENARIO" || exit_with E070

# T2: có ≥1 scenario
COUNT=$(grep -c '^## Kịch bản' "$SCENARIO")
[ "$COUNT" -ge 1 ] || exit_with E070

# Load cross-session lock helpers
source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
source .claude/scripts/wf-e2e-shared/version-snapshot.sh

# T3: FE/BE/DB ready với reader lock (cross-session safe)
ensure_infrastructure_running database read || exit_with E072
ensure_infrastructure_running backend  read || exit_with E072
ensure_infrastructure_running frontend read || exit_with E072

# T4: Playwright MCP — acquire reader cross-session trước khi probe
acquire_reader_lock playwright "$SESSION_ID" "$FEAT_ID" || exit_with E071
mcp__plugin_playwright_playwright__browser_navigate --url=about:blank 2>/dev/null || {
  release_reader_lock playwright "$SESSION_ID"
  exit_with E071
}
```

## Lock Strategy (cross-session R/W + per-session lock)

| Lock | Scope | Purpose |
|------|-------|---------|
| `playwright` (global R/W) | Cross-session | Bảo vệ Playwright MCP instance khỏi 2 session navigate đồng thời |
| `backend` / `frontend` / `database` (global R/W) | Cross-session | Reader khi test, writer khi restart |
| `browser-mcp.lock` (per-session) | Trong cùng session F2/F5/F7/F8 | Sequential giữa các sub-skill trong 1 session |

```bash
# Per-session lock (như cũ — giữ tuần tự F2/F5/F7/F8 trong 1 session)
for i in {1..5}; do
  if [ ! -f "$LOCK" ]; then
    echo "$$:$(date -u +%s)" > "$LOCK"
    break
  fi
  AGE=$(($(date -u +%s) - $(stat -c %Y "$LOCK")))
  if [ "$AGE" -gt 1800 ]; then
    echo "$$:$(date -u +%s)" > "$LOCK"
    break
  fi
  sleep 10
done

# Cleanup trap — release CẢ per-session lock VÀ cross-session reader lock
trap '
  rm -f "$LOCK"
  release_reader_lock playwright "$SESSION_ID"
' EXIT
```

## Login Pattern

```bash
# Default sysadmin login
mcp__plugin_playwright_playwright__browser_navigate --url=http://localhost:3000/login

mcp__plugin_playwright_playwright__browser_fill_form --fields='[
  {"name":"email","value":"sysadmin@erktransport.local"},
  {"name":"password","value":"SysAdmin@123"}
]'

mcp__plugin_playwright_playwright__browser_click --selector='button[type=submit]'

mcp__plugin_playwright_playwright__browser_wait_for --selector='[data-testid=dashboard]' --timeout=10000

mcp__plugin_playwright_playwright__browser_take_screenshot --output="$SCREENSHOTS/login-result.png"
```

## Mobile Viewport (--mobile flag)

```bash
mcp__plugin_playwright_playwright__browser_resize --width=375 --height=667  # iPhone SE
# Default desktop: 1280x720
```

## Scenario Parse Pattern

```bash
# Parse test-scenario.md heading + step table
# Each scenario block:
# ## Kịch bản 1: {Tên}
# **Loại:** happy|validation|error|BR|state|cross-module
# **Precondition:** ...
# **Actor:** sysadmin|customer|...
# 
# | Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
# |------|-----------|------------------|------------------|-----------|
# | 1    | ...       | ...              |                  |           |
```

## Atomic Update test-scenario.md

```bash
# Use awk/sed để update specific row của specific scenario
# Hoặc Read whole file → modify → Write back (atomic)

# After each scenario:
# 1. Read test-scenario.md
# 2. Find scenario block by heading
# 3. Update each row's "Kết quả thực tế" + "Pass/Fail" columns
# 4. Append "**Evidence:** screenshots/scenario-NN-slug.png" after table
# 5. Write back atomic (tmp + mv)
```

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F7 chu yeu dung Playwright — CI chi can cho cross-module scenario context lookup.

```bash
GITNEXUS_AVAILABLE=${GITNEXUS_AVAILABLE:-false}
SERENA_AVAILABLE=${SERENA_AVAILABLE:-false}
CI_CONTEXT=${CI_CONTEXT:-""}
```

## Error Ledger (CORE-034)

```bash
ERROR_LEDGER="$SESSION_DIR/error-ledger.json"

log_error() {
  local CODE="$1"; local PHASE="$2"; local MSG="$3"; local RETRY="${4:-0}"
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"timestamp\":\"$ISO\",\"code\":\"$CODE\",\"phase\":\"$PHASE\",\"message\":\"$MSG\",\"retry_count\":$RETRY}" >> "$ERROR_LEDGER"
}
```

## Context & Checkpoint (CORE-038)

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint (luu status.json + scenario-test-report.md) |
| 80-90% | STOP sau scenario hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E079 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E075 Navigate fail | Retry x2, then mark scenario FAIL + capture console errors |
| E076 Snapshot mismatch | APPEND issues.json → **Load failure-analyzer.md** → Bước 1-6 (classify + enrich) → **Bước 7 Auto-Fix** → nếu fix thành công: mark PASS (auto-corrected); nếu fail/skip: mark FAIL |
| E077 Screenshot fail | Log warning, continue (scenario có thể marked partial) |
| E080 Analysis inconclusive | Log warning (severity=medium), set failure_type=UNKNOWN, tiếp tục — không block |
| E081 Evidence partial | Log warning (severity=low), set evidence_partial=true, tiếp tục — không block |
| E082 Auto-fix exhausted | Log warning (severity=medium), auto-fix đã thử nhưng vẫn fail — giữ FAIL gốc, không block |
| Lock conflict | WAIT 10s × 5, then E074 ESCALATE |

## classify_failure() — Smart Retry (G1.2)

WHY: Retry không có phân loại dẫn đến retry cả assertion failures (bug thật) — tốn thời gian và che giấu lỗi. Classification-based retry chỉ retry những lỗi có khả năng phục hồi (timeout, network), còn assertion fail thì push issues ngay.

```bash
classify_failure() {
  local ERROR_TYPE="$1"
  local ERROR_MSG="$2"

  case "$ERROR_TYPE/$ERROR_MSG" in
    *TimeoutError*|*/TimeoutError*) echo "TIMEOUT" ;;
    *net:*|*ECONNREFUSED*|*ECONNRESET*|*ETIMEDOUT*) echo "NETWORK_ERROR" ;;
    *"selector"*|*"no element"*|*"strict mode"*) echo "SELECTOR_NOT_FOUND" ;;
    *"expected"*"received"*|*"toBe"*|*"toEqual"*) echo "ASSERTION_FAIL" ;;
    *TargetClosedError*|*"page was closed"*) echo "BROWSER_CRASH" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# Retry policy theo failure type
# WHY mỗi type có policy riêng:
#   TIMEOUT        → retry với timeout lớn hơn (environment có thể chậm)
#   NETWORK_ERROR  → exponential backoff (server transient issue)
#   SELECTOR_NOT_FOUND → 1 retry với fallback selector (UI có thể chưa render)
#   ASSERTION_FAIL → KHÔNG retry — đây là bug thật, retry che giấu issue
#   BROWSER_CRASH  → restart browser context (2 lần max)
execute_with_smart_retry() {
  local ACTION_DESC="$1"
  local SCENARIO_ID="$2"

  local ATTEMPT=1
  local LAST_ERROR_TYPE=""

  while true; do
    if eval "${ACTION:-true}"; then
      # Update scenario-result.json
      write_scenario_result "$SCENARIO_ID" "stable_pass" "" "$((ATTEMPT - 1))"
      return 0
    fi

    LAST_ERROR_TYPE=$(classify_failure "${LAST_ERROR_TYPE:-UNKNOWN}" "${LAST_ERROR_MSG:-}")

    case "$LAST_ERROR_TYPE" in
      TIMEOUT)
        [ "$ATTEMPT" -ge 3 ] && break
        SLEEP=$((ATTEMPT * 5))
        log_error "E075" "retry" "TIMEOUT attempt $ATTEMPT — sleep ${SLEEP}s, next timeout x2"
        sleep "$SLEEP"
        ;;
      NETWORK_ERROR)
        [ "$ATTEMPT" -ge 5 ] && break
        BACKOFF=$((2 ** (ATTEMPT - 1)))  # 1,2,4,8,16s
        log_error "E075" "retry" "NETWORK_ERROR attempt $ATTEMPT — backoff ${BACKOFF}s"
        sleep "$BACKOFF"
        ;;
      SELECTOR_NOT_FOUND)
        [ "$ATTEMPT" -ge 2 ] && break
        log_error "E075" "retry" "SELECTOR_NOT_FOUND attempt $ATTEMPT — try fallback selector"
        ;;
      ASSERTION_FAIL)
        # KHÔNG retry — bug thật
        log_error "E076" "assertion" "ASSERTION_FAIL: $ACTION_DESC — push HIGH immediately, no retry"
        write_scenario_result "$SCENARIO_ID" "stable_fail" "ASSERTION_FAIL" "$((ATTEMPT - 1))"
        # Append tới issues.json với severity=HIGH
        append_issue "$SCENARIO_ID" "HIGH" "ASSERTION_FAIL" "$ACTION_DESC"
        return 1
        ;;
      BROWSER_CRASH)
        [ "$ATTEMPT" -ge 3 ] && break
        log_error "E075" "browser" "BROWSER_CRASH attempt $ATTEMPT — fresh context"
        mcp__plugin_playwright_playwright__browser_close 2>/dev/null || true
        sleep 2
        ;;
      *)
        [ "$ATTEMPT" -ge 2 ] && break
        log_error "E075" "unknown" "UNKNOWN error attempt $ATTEMPT"
        ;;
    esac

    ATTEMPT=$((ATTEMPT + 1))
  done

  # Exhausted retries
  write_scenario_result "$SCENARIO_ID" "stable_fail" "$LAST_ERROR_TYPE" "$((ATTEMPT - 1))"
  return 1
}

write_scenario_result() {
  local SCENARIO_ID="$1"
  local STATUS="$2"       # stable_pass | stable_fail | retry_recovered | flaky
  local FAIL_TYPE="$3"    # TIMEOUT | ASSERTION_FAIL | ... (rỗng nếu pass)
  local RETRY_COUNT="$4"

  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local RESULT_FILE="$F7_DIR/scenario-results/${SCENARIO_ID}.json"
  mkdir -p "$F7_DIR/scenario-results"

  cat > "$RESULT_FILE.tmp" <<JSON
{
  "scenario_id": "$SCENARIO_ID",
  "status": "$STATUS",
  "fail_type": "$FAIL_TYPE",
  "retry_count": $RETRY_COUNT,
  "recorded_at": "$ISO"
}
JSON
  jq '.' "$RESULT_FILE.tmp" > /dev/null && mv "$RESULT_FILE.tmp" "$RESULT_FILE"
}
```

---

## auto_quarantine() — G1.5

WHY: Flaky scenarios cần cách ly ngay để không block pipeline chính. Đồng thời dispatch expert agents phân tích nguyên nhân — giải phóng người dùng khỏi phải debug thủ công.

```bash
auto_quarantine() {
  local SCENARIO_ID="$1"
  local SCENARIO_FILE="$2"
  local FAIL_STATS_JSON="${3:-{\"runs\":5,\"pass\":0,\"fail\":5,\"flaky\":true}}"

  local QUARANTINE_DIR=".mc-data/work/wf-e2e-verify/quarantine/$SCENARIO_ID"
  mkdir -p "$QUARANTINE_DIR/diagnostic-bundle"

  # Copy scenario file vào quarantine dir
  [ -f "$SCENARIO_FILE" ] && cp "$SCENARIO_FILE" "$QUARANTINE_DIR/"

  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Ghi quarantine-report.json từ template
  cat > "$QUARANTINE_DIR/quarantine-report.json.tmp" <<JSON
{
  "\$schema": "quarantine-report-v1",
  "scenario_id": "$SCENARIO_ID",
  "scenario_file": "$SCENARIO_FILE",
  "quarantined_at": "$ISO",
  "reason": "flaky",
  "fail_stats": $FAIL_STATS_JSON,
  "diagnostic_bundle": {
    "dom_diff": "",
    "network_trace": "",
    "console_errors": "",
    "screenshots": [],
    "timing_analysis": {}
  },
  "fix_proposal_path": "$QUARANTINE_DIR/fix-proposal.md",
  "status": "quarantined",
  "experts_assigned": ["qa-lead", "frontend-developer"],
  "auto_fix_dispatched": true
}
JSON
  jq '.' "$QUARANTINE_DIR/quarantine-report.json.tmp" > /dev/null && \
    mv "$QUARANTINE_DIR/quarantine-report.json.tmp" "$QUARANTINE_DIR/quarantine-report.json"

  # Ghi fix-proposal.md để 2 expert agents bổ sung phân tích
  # WHY parallel dispatch: qa-lead tập trung test design issues, frontend-developer tập trung selector/code issues
  cat > "$QUARANTINE_DIR/fix-proposal.md" <<PROPOSAL
# Fix Proposal: $SCENARIO_ID

**Quarantined at:** $ISO
**Fail stats:** $FAIL_STATS_JSON

## Phân tích cần thực hiện

1. **qa-lead**: Kiểm tra test design — có vi phạm lint rules (G1.1)? Flakiness do async timing?
2. **frontend-developer**: Kiểm tra selector stability, state management, CSS loading order?

## Root Cause (điền sau phân tích)

[TBD]

## Proposed Fixes

[TBD]

## Verify Plan

1. Apply fixes vào scenario file
2. Chạy 5x stability check (G1.3)
3. 5/5 PASS → unquarantine (xóa khỏi quarantine-report.json)
PROPOSAL

  # Log vào session
  log_error "E081" "quarantine" "Scenario $SCENARIO_ID quarantined (flaky) → $QUARANTINE_DIR"

  # Append pending queue cho CDG
  local QUEUE_FILE=".mc-data/work/_decisions/pending-queue.jsonl"
  mkdir -p ".mc-data/work/_decisions"
  echo "{\"type\":\"QUARANTINE\",\"scenario_id\":\"$SCENARIO_ID\",\"severity\":\"HIGH\",\"message\":\"Scenario $SCENARIO_ID bi quarantine (flaky)\",\"timestamp\":\"$ISO\",\"options\":[\"Apply fix-proposal va re-verify\",\"Disable scenario tam thoi\",\"Rewrite scenario\"]}" >> "$QUEUE_FILE"
}
```

Khi `/status`: thêm section "Quarantined Scenarios" nếu `.mc-data/work/wf-e2e-verify/quarantine/` không rỗng.

---

## Cross-Module Scenario Handling

Cross-module scenarios trong test-scenario.md có header `**Loại:** cross-module`. Execute:

```
1. Identify upstream → downstream module pairs from cross-module-map.md
2. Navigate qua mỗi module page sequentially
3. Capture screenshot per step (scenario-N-upstream.png, scenario-N-downstream.png)
4. Verify reference ID consistency (URL params, query strings)
5. Verify data consistency (DOM snapshot từ both modules)
6. Verify saga compensation nếu test failure path
```
