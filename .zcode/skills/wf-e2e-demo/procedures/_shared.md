# F8 wf-e2e-demo — Shared Protocols (v1.1.0 — T1.4 Tier 1 Refactor)

## Playwright Retry Pattern (T1.4 — CORE: BLOCKED khi fail, không fallback curl)

```bash
playwright_retry() {
  local ACTION_DESC="$1"
  local MAX_ATTEMPTS="${2:-3}"

  for ATTEMPT in $(seq 1 "$MAX_ATTEMPTS"); do
    if eval "$ACTION"; then
      return 0
    fi

    if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
      SLEEP_SEC=$((ATTEMPT * 5))  # 5s, 10s, 15s
      log_error "E085" "playwright_retry" "Attempt $ATTEMPT/$MAX_ATTEMPTS fail: $ACTION_DESC — sleep ${SLEEP_SEC}s"

      mcp__plugin_playwright_playwright__browser_close 2>/dev/null || true
      sleep "$SLEEP_SEC"

      if [ -n "${TARGET_URL:-}" ]; then
        mcp__plugin_playwright_playwright__browser_navigate --url="$TARGET_URL" 2>/dev/null || true
      fi
    fi
  done

  # Exhausted — KHÔNG fallback sang EVIDENCE_COMPILATION mode
  log_error "E085" "playwright_retry" "BLOCKED: $ACTION_DESC exhausted $MAX_ATTEMPTS attempts"
  echo "BLOCKED"
  return 1
}

# QUYẾT ĐỊNH KỸ THUẬT (WHY bỏ EVIDENCE_COMPILATION):
# EVIDENCE_COMPILATION mode (thu thập evidence từ file tĩnh thay vì chạy browser) tạo ra
# demo-report không có giá trị xác minh thực sự — user-guide "verified" nhưng thực ra
# chưa có ai thao tác trên browser thật. Kết quả mislead QA team và người dùng cuối.
# Thay thế bằng BLOCKED status + rõ ràng lý do → user biết cần fix infrastructure.
```

## Strict Evidence Check (T1.5 --strict-evidence)

```bash
check_strict_evidence() {
  local SCREENSHOT_PATH="$1"
  local STRICT="${STRICT_EVIDENCE:-true}"  # ON by default

  if [ "$STRICT" = "true" ]; then
    if [ ! -f "$SCREENSHOT_PATH" ]; then
      log_error "E086" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH bị thiếu — evidence_missing BLOCKED"
      echo "evidence_missing"
      return 1
    fi

    SIZE=$(wc -c < "$SCREENSHOT_PATH" 2>/dev/null || echo 0)
    if [ "$SIZE" -lt 1024 ]; then  # < 1KB
      log_error "E086" "evidence" "STRICT: Screenshot ${SIZE} bytes < 1KB — evidence_missing BLOCKED"
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
$F8_DIR = $SESSION_DIR/F8-demo/
$GUIDE = $SESSION_DIR/outputs/user-guide.md
$UI_MAP = $SESSION_DIR/findings/ui-mapping.md
$REPORT = $F8_DIR/demo-report.md
$STATUS = $F8_DIR/status.json
$SCREENSHOTS = $SESSION_DIR/screenshots/
$LOCK = $SESSION_DIR/_locks/browser-mcp.lock
```

## PRE-GATE Forensic

```bash
test -f "$GUIDE" || exit_with E080
STEPS=$(grep -cE '^\*\*Bước [0-9]+|^## Bước [0-9]+' "$GUIDE")
[ "$STEPS" -ge 1 ] || exit_with E080

# Load cross-session lock helpers
source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
source .claude/scripts/wf-e2e-shared/version-snapshot.sh

# FE/BE/DB ready với reader lock (cross-session safe)
ensure_infrastructure_running database read || exit_with E082
ensure_infrastructure_running backend  read || exit_with E082
ensure_infrastructure_running frontend read || exit_with E082

# Playwright MCP — acquire reader cross-session trước khi probe
acquire_reader_lock playwright "$SESSION_ID" "$FEAT_ID" || exit_with E081
mcp__plugin_playwright_playwright__browser_navigate --url=about:blank 2>/dev/null || {
  release_reader_lock playwright "$SESSION_ID"
  exit_with E081
}
```

## Lock Strategy (cross-session R/W + per-session lock)

| Lock | Scope | Purpose |
|------|-------|---------|
| `playwright` (global R/W) | Cross-session | Bảo vệ Playwright MCP instance khỏi 2 session đồng thời |
| `backend` / `frontend` / `database` (global R/W) | Cross-session | Reader khi test, writer khi restart |
| `browser-mcp.lock` (per-session) | Trong cùng session F2/F5/F7/F8 | Sequential trong 1 session |

```bash
# Per-session lock pattern same as F7 — acquire + release cuối
# Cleanup trap — release CẢ per-session lock VÀ cross-session reader lock
trap '
  rm -f "$LOCK"
  release_reader_lock playwright "$SESSION_ID"
' EXIT
```

## user-guide.md Parse Pattern

```
# Format chuẩn user-guide.md (F1 phase6-output.md sinh):
# 
# # {Tên tính năng} — Hướng dẫn sử dụng
# 
# ## 1. Mục đích
# ...
# 
# ## 2. Điều kiện chuẩn bị
# - Đăng nhập với role X
# - Có dữ liệu Y
# 
# ## 3. Các bước thao tác
# 
# ### Bước 1: {Tên bước}
# - **Hành động:** Click button "Tạo mới"
# - **Kết quả mong đợi:** Form modal hiện ra
# 
# ### Bước 2: ...
# 
# ## 4. Quy Trình Hoàn Chỉnh (cross-module, nếu có)
# ...
# 
# ## 5. Lỗi Thường Gặp
# ...
```

## Step Execution

```bash
# Parse each "### Bước N: ..." block
# Extract: action (Hành động), expected (Kết quả mong đợi)

# Common actions:
case $ACTION_TYPE in
  "Đăng nhập") perform_login;;
  "Click button|Nhấn nút") mcp__playwright__browser_click;;
  "Nhập|Điền") mcp__playwright__browser_type;;
  "Chọn") mcp__playwright__browser_select_option;;
  "Tải lên|Upload") mcp__playwright__browser_file_upload;;
  "Chờ|Wait") mcp__playwright__browser_wait_for;;
  "Điều hướng đến|Navigate to") mcp__playwright__browser_navigate;;
esac

# After action: snapshot + verify expected
mcp__playwright__browser_snapshot
verify_expected "$EXPECTED"

# Capture
SLUG=$(slugify "$STEP_NAME")
mcp__playwright__browser_take_screenshot --output="$SCREENSHOTS/demo-${NN}-${SLUG}.png"
```

## Accuracy Scoring

```bash
function calculate_accuracy() {
  TOTAL=$(jq -r '.steps_total' "$STATUS")
  EXACT=$(jq -r '[.steps[] | select(.match=="exact")] | length' "$STATUS")
  PARTIAL=$(jq -r '[.steps[] | select(.match=="partial")] | length' "$STATUS")
  
  SCORE=$(echo "scale=2; ($EXACT + 0.5 * $PARTIAL) / $TOTAL * 100" | bc)
  echo "$SCORE"
}
```

## Correction Detection

```bash
# Khi action FAIL (E086) hoặc expected mismatch (E087):
# 1. Capture current DOM state
DOM=$(mcp__playwright__browser_evaluate --code='document.body.innerText')

# 2. Suggest correction:
echo "user-guide.md says: '$EXPECTED'" >> "$REPORT"
echo "Actual UI: '$DOM_RELEVANT_PART'" >> "$REPORT"
echo "Recommendation: Update step text" >> "$REPORT"

# 3. IF --auto-correct: apply update vào $GUIDE qua Edit tool
```

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F8 chu yeu dung Playwright — CI chi can cho user-guide context lookup.

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
| 65-80% | Chuan bi checkpoint (luu status.json + demo-report.md) |
| 80-90% | STOP sau step hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E089 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E086 Action fail | Mark step FAIL, capture error screenshot, log to demo-report.md |
| E087 Expected mismatch | Mark step PARTIAL, log correction recommendation |
| E083 Login fail | Critical, STOP entire F8 |
| Lock conflict | WAIT, then E084 |
