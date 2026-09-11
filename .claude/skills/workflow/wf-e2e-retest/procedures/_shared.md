# F5 wf-e2e-retest — Shared Protocols

## State Variables

```
$SESSION_DIR = .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
$F5_DIR = $SESSION_DIR/F5-retest/
$RETEST_LOG = $F5_DIR/retest-log.md
$STATUS = $F5_DIR/status.json
$LOCK = $SESSION_DIR/_locks/browser-mcp.lock

# Inputs (SSOT)
$ISSUES = $SESSION_DIR/issues.json
$BLOCK_TEST = $SESSION_DIR/block-test.json
$REPORTS = (
  "$SESSION_DIR/findings/db-test-report.md"
  "$SESSION_DIR/findings/api-test-report.md"
  "$SESSION_DIR/findings/ui-test-report.md"
  "$SESSION_DIR/findings/integration-test-report.md"
  "$SESSION_DIR/outputs/test-scenario.md"
)

# Flags
$SCOPE = ${SCOPE:-all}  # ui | code | all
# NOTE: --no-playwright đã bị xóa từ v1.1.0. Live test BẮT BUỘC; auto-start mandatory; ESCALATE Nhóm 2 nếu fail.
```

## PRE-GATE

```bash
# T1: reports exist
for R in "${REPORTS[@]}"; do
  test -f "$R" || echo "WARN: $R missing (may skip scope)"
done

# T2: issues.json valid
jq -e '.signals' "$ISSUES" > /dev/null || exit_with E050

# T3: có pending items?
PENDING_COUNT=$(grep -cE "PENDING|SKIP|⬜" "${REPORTS[@]}" 2>/dev/null | awk -F: '{s+=$2} END{print s}')
ISSUES_RETEST_NEEDED=$(jq -r '[.signals[] | select(.status=="fixed" and (.retest_count // 0) == 0)] | length' "$ISSUES")
TOTAL=$((PENDING_COUNT + ISSUES_RETEST_NEEDED))
[ "$TOTAL" -gt 0 ] || { echo "No pending items, nothing to retest"; exit 0; }

# Load cross-session lock helpers
source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
source .claude/scripts/wf-e2e-shared/version-snapshot.sh

# T4 (UI scope): Playwright + FE — reader lock + auto-start mandatory
if [ "$SCOPE" = "ui" ] || [ "$SCOPE" = "all" ]; then
  ensure_infrastructure_running frontend read  || exit_with_escalation
  # Acquire reader lock playwright trước khi probe (cross-session safe)
  acquire_reader_lock playwright "$SESSION_ID" "$FEAT_ID" || {
    log_error "E053" "PRE-GATE" "Reader lock playwright timeout — ESCALATE"
    exit_with_escalation
  }
  mcp__plugin_playwright_playwright__browser_navigate --url=about:blank 2>/dev/null || {
    log_error "E053" "PRE-GATE" "Playwright MCP không khả dụng — ESCALATE thay vì fallback static"
    release_reader_lock playwright "$SESSION_ID"
    exit_with_escalation
  }
fi

# T5 (code scope): BE + DB — reader lock + auto-start mandatory
if [ "$SCOPE" = "code" ] || [ "$SCOPE" = "all" ]; then
  ensure_infrastructure_running database read || exit_with_escalation
  ensure_infrastructure_running backend  read || exit_with_escalation
fi
```

## Scope Routing

```
scope=ui → playwright-retest.md (Playwright BẮT BUỘC; auto-start FE; fail → ESCALATE Nhóm 2)
scope=code → code-retest.md (curl, dotnet test, EF check — auto-start BE+DB; fail → ESCALATE)
scope=all → both, sequential UI then code
```

> Item được F1 classify Nhóm 4 (visual/real payment/OAuth/hardware/human judgment) là **SPECIAL CASE DUY NHẤT** được phép re-verify qua static code analysis. Detect bằng cách check `manual.json` có MAN-NNN với `manual_reason ∈ {visual_inspection, requires_real_payment, requires_external_api, requires_3rd_party_login, requires_hardware, requires_data_volume, requires_human_judgment}`. Mọi item khác: live test BẮT BUỘC.

## CORE-039 issues.json Update (BẮT BUỘC)

Sau mỗi retest item:

```bash
jq --arg id "$ISS_ID" --arg result "$RESULT" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  (.signals[] | select(.id==$id) | .retest_count) = ((.signals[] | select(.id==$id) | .retest_count // 0) + 1) |
  (.signals[] | select(.id==$id) | .retest_result) = $result |
  (.signals[] | select(.id==$id) | .retest_at) = $now |
  (.signals[] | select(.id==$id) | .status) = (if $result == "PASS" then "fixed" elif $result == "FAIL" then "open" else "fixed" end)
' "$ISSUES" > "$ISSUES.tmp" && mv "$ISSUES.tmp" "$ISSUES"
```

## New Issue Detection

Nếu retest reveal NEW issue (chưa có entry):
```bash
NEW_ID="ISS-$(jq -r '[.signals[].id] | map(sub("ISS-"; "") | tonumber) | max + 1' "$ISSUES" | xargs printf "ISS-%03d")"
jq --argjson new "$NEW_ISSUE_JSON" '.signals += [$new]' "$ISSUES" > "$ISSUES.tmp"
mv "$ISSUES.tmp" "$ISSUES"
```

## Anti-Loop Tracking

F5 KHÔNG self-loop. Anti-loop là orchestrator-level (e2e-status.json.anti_loop.f6_f5_loop_count). F5 chỉ chạy 1 lần per orchestrator invocation.

## CI Detection (CORE-033)

> CI detection chay boi orchestrator. Sub-skill doc `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT`.
> F5 can CI cho code-retest (API routes, DB queries).

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
| 65-80% | Chuan bi checkpoint (luu status.json + retest-log.md) |
| 80-90% | STOP sau scope hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E059 style) |

## Error Handling

| Error | Action |
|-------|--------|
| E053 Playwright/FE not running | MANDATORY auto-start (retry 2 lần). Fail → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion. KHÔNG fallback static. |
| E055 Transient fail | Retry x2 với backoff 5s, 15s |
| E056 Report markdown corrupt | Restore from .tmp, escalate |
| E057 CORE-039 fail | Atomic write retry, escalate if persist |
