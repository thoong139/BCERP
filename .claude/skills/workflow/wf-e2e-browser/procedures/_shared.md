# F2 wf-e2e-browser — Shared Protocols (v1.1.0 — T1.5 --strict-evidence)

## Strict Evidence Check (T1.5 --strict-evidence)

```bash
check_strict_evidence() {
  local SCREENSHOT_PATH="$1"
  local STRICT="${STRICT_EVIDENCE:-true}"  # ON by default (inherited from orchestrator)

  if [ "$STRICT" = "true" ]; then
    if [ ! -f "$SCREENSHOT_PATH" ]; then
      log_error "E0B6" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH bị thiếu — evidence_missing BLOCKED"
      echo "evidence_missing"
      return 1
    fi

    SIZE=$(wc -c < "$SCREENSHOT_PATH" 2>/dev/null || echo 0)
    if [ "$SIZE" -lt 1024 ]; then  # < 1KB
      log_error "E0B6" "evidence" "STRICT: Screenshot ${SIZE} bytes < 1KB — evidence_missing BLOCKED"
      echo "evidence_missing"
      return 1
    fi
  fi
  return 0
}

# STRICT_EVIDENCE usage:
# Sau mỗi browser test step → capture screenshot → check_strict_evidence
# Nếu evidence_missing → mark step status="blocked" + append issues.json type="evidence_missing"
# KHÔNG tiếp tục step tiếp theo của cùng browser test group
```

## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F2_DIR = $SESSION_DIR/F2-browser/
$PRE_SCAN = $F2_DIR/pre-scan-report.md
$EXEC_REPORT = $F2_DIR/browser-test-report.md
$STATUS = $F2_DIR/status.json
$LOCK = $SESSION_DIR/_locks/browser-mcp.lock

$UI_REPORT = $SESSION_DIR/findings/ui-test-report.md
$INTEGRATION_REPORT = $SESSION_DIR/findings/integration-test-report.md
$BLOCK_TEST = $SESSION_DIR/block-test.json
$ISSUES = $SESSION_DIR/issues.json
$IMPL_REQ = $SESSION_DIR/implement-required.json
$MANUAL = $SESSION_DIR/manual.json
```

## PRE-GATE

```bash
test -f "$UI_REPORT" || exit_with E020
test -f "$INTEGRATION_REPORT" || exit_with E020
[ -z "${SESSION_ID:-}" ] && exit_with E022

# Load lock helpers (cross-session R/W locks)
source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
source .claude/scripts/wf-e2e-shared/version-snapshot.sh

# MANDATORY auto-start với cross-session R/W locks
# Reader intent — nhiều F2 ở các session khác nhau có thể chạy song song
ensure_infrastructure_running database read || exit_with_escalation
ensure_infrastructure_running backend  read || exit_with_escalation
ensure_infrastructure_running frontend read || exit_with_escalation

# Playwright MCP availability check — single browser instance shared across sessions
# Acquire reader lock TRƯỚC khi probe (tránh 2 session probe cùng lúc gây race)
acquire_reader_lock playwright "$SESSION_ID" "$FEAT_ID" || {
  log_error "E021" "PRE-GATE" "Reader lock playwright timeout — ESCALATE"
  exit_with_escalation
}

mcp__plugin_playwright_playwright__browser_navigate --url=about:blank 2>/dev/null || {
  log_error "E021" "PRE-GATE" "Playwright MCP không khả dụng — ESCALATE Nhóm 2"
  release_reader_lock playwright "$SESSION_ID"
  classify_and_escalate_block --reason "playwright_unavailable" \
    --detail "Playwright MCP không response sau khi acquire lock. ESCALATE thay vì fallback static."
  exit_with_escalation
}
```

## Lock Strategy (cross-session R/W — v1.1.0+)

| Lock | Scope | Khi nào dùng |
|------|-------|--------------|
| `playwright` (global, R/W) | Cross-session — bảo vệ Playwright MCP instance khỏi 2 session probe/navigate đồng thời | F2/F5/F7/F8 acquire reader khi PRE-GATE; release ở Phase end. Writer lock CHỈ khi spawn browser profile mới. |
| `browser-mcp.lock` (per-session) | Trong cùng session — sequential giữa F2/F5/F7/F8 | Giữ nguyên (như cũ) — tránh trong 1 session F2 và F7 chạy navigate cùng lúc. |
| `backend` / `frontend` / `database` (global, R/W) | Cross-session — bảo vệ hạ tầng khỏi restart conflict | Reader khi test, writer khi restart/migrate. |

**Quy tắc:** Cross-session lock BẮT BUỘC release ở Phase end (qua heartbeat daemon, hoặc explicit `release_reader_lock playwright "$SESSION_ID"`). Nếu F2 hang giữa chừng → heartbeat daemon trong session sẽ auto-release sau 2 phút (stale).

## Block Classification (delegate F1 logic)

Tham chiếu `.claude/skills/workflow/wf-e2e-test/procedures/block-classification.md` — 4 nhóm + DUAL-WRITE pattern.

F2 áp dụng cùng logic khi phát hiện browser-blocked tests:
- Nhóm 1 Data → auto-fix (rare for browser, vd: missing test data)
- Nhóm 2 Infra → auto-fix (FE not running)
- Nhóm 3 Not Impl → DUAL-WRITE block-test + implement-required
- Nhóm 4 Hard Test → VERIFY CODE → DUAL-WRITE block-test + manual

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT` tu orchestrator.
> F2 chu yeu dung Playwright — CI chi can cho pre-scan code analysis.

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
| 65-80% | Chuan bi checkpoint (luu status.json + pre-scan-report.md) |
| 80-90% | STOP sau test hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E029 + E009 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E024 Login fail | Critical, STOP |
| E025 Navigate fail | Retry x2, then mark FAIL |
| E026 Snapshot mismatch | APPEND issues.json, mark FAIL |
| E027 Screenshot fail | Log warn, continue |
