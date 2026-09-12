---
name: wf-e2e-retest
version: 1.2.0
last_updated: 2026-09-12
description: |
  F5 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 cờ --retest).
  Scan reports tìm tests PENDING/SKIP/⬜ → re-check điều kiện → retest → cập nhật reports.
  Playwright BẮT BUỘC cho UI items (live browser). FE/Playwright không sẵn sàng → MANDATORY auto-start
  (retry 2 lần); fail → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion. KHÔNG có cờ --no-playwright,
  KHÔNG silent fallback static analysis. Code analysis CHỈ hợp lệ cho item đã được classify Nhóm 4
  (visual, real payment, OAuth real, hardware) từ F1.
  YÊU CẦU --session=<id>.

  TRIGGER khi: "retest", "re-run tests", "kiểm tra lại", "verify fixes", "rescan pending".
  KHÔNG trigger: fix bugs (F6), unblock (F3), implement (F4), full pipeline (orchestrator).

argument-hint: "<FEAT-ID> --session=<id> [--resume] [--status] [--scope=ui|code|all]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__plugin_playwright_playwright__browser_navigate,
  mcp__plugin_playwright_playwright__browser_snapshot,
  mcp__plugin_playwright_playwright__browser_click,
  mcp__plugin_playwright_playwright__browser_type,
  mcp__plugin_playwright_playwright__browser_fill_form,
  mcp__plugin_playwright_playwright__browser_wait_for,
  mcp__plugin_playwright_playwright__browser_take_screenshot,
  mcp__plugin_playwright_playwright__browser_evaluate,
  mcp__plugin_playwright_playwright__browser_close,
  mcp__serena__find_symbol, mcp__serena__search_for_pattern
---

# /wf-e2e-retest: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Scan reports tìm PENDING/SKIP/⬜ items → retest → cập nhật reports + issues.json |
| **Prerequisites** | F1 reports tồn tại trong session (findings/*.md + issues.json + block-test.json) + `--session=<id>` BẮT BUỘC (PRE-GATE) |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | Tất cả `findings/*.md`, `outputs/test-scenario.md`, `issues.json`, `block-test.json` |
| **Output** | `retest-log.md`, UPDATE reports (PENDING→PASS/FAIL), UPDATE `issues.json` (CORE-039) |
| **Playwright** | BẮT BUỘC cho UI items. FE/Playwright chưa sẵn sàng → MANDATORY auto-start, fail → ESCALATE |

### Flow

```
[--session] → [PRE-GATE: F1 reports tồn tại]
→ Scan reports tìm:
  - "PENDING" / "SKIP" / "⬜" markers
  - issues.json signals status=fixed chưa retest (retest_count=0)
  - block-test.json entries status=unblocked chưa retest
→ Categorize: ui | code | integration
→ FOR each pending item:
    IF scope=ui → MANDATORY auto-start (FE + Playwright) → execute via browser. Fail → ESCALATE Nhóm 2, KHÔNG fallback static.
    IF scope=code → MANDATORY auto-start (BE + DB) → curl/dotnet test live. Fail → ESCALATE Nhóm 2.
    IF scope=integration → MANDATORY auto-start full stack → chain test live. Fail → ESCALATE Nhóm 2.
    EXCEPTION: item đã được classify Nhóm 4 từ F1 (visual/real payment/OAuth/hardware) → cho phép static code re-verification.
→ Update reports: PENDING → PASS|FAIL với evidence
→ Update issues.json (CORE-039): retest_count++, retest_result
→ Write retest-log.md
→ DONE
```

---

## Workflow Position

```
F1 outputs → F2 browser → F3 unblock → F4 implement
        │                                       │
        └──────────────────┬────────────────────┘
                           ▼
                      ┌─────────┐
                      │   F5    │ ← wf-e2e-retest (skill này)
                      │ Retest  │ DEFAULT Playwright
                      └────┬────┘
                           ▼ reports updated
                      F6 fix (nếu issues.json còn open)
                           │
                           └─► spawn F5 again (sau fix) — anti-loop max 3 vòng
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID | required |
| `--resume` | Resume từ item chưa retest | - |
| `--status` | Display retest progress + STOP | - |
| `--scope=<ui\|code\|all>` | Phạm vi retest | all |

> **Đã bỏ `--no-playwright`** (v1.1.0). Live test BẮT BUỘC cho mọi item ngoài Nhóm 4. Nếu FE/Playwright/BE/DB không chạy → MANDATORY auto-start (retry 2 lần) → fail → ESCALATE Nhóm 2. Không có đường thoát code-only.

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F5 can CI cho code-retest (API routes, DB queries).

## Phase 0: Scan Pending (BẮT BUỘC — entry point)

> Chi tiết: `procedures/scan-pending.md`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | PRE-GATE: F1 reports tồn tại + ≥1 pending item | Fail → E050 |
| 2 | CI PRE-GATE Na-Nc (code-retest cần API routes/DB queries) | CI flags set |
| 3 | Scan 3 sources (reports PENDING/SKIP/⬜, issues fixed chưa retest, block-test unblocked) → categorize ui/code/integration | Danh sách pending có scope |
| 4 | Route từng item theo scope (playwright-retest / code-retest) | Mỗi item được retest hoặc ESCALATE Nhóm 2 |

## Phase Routing Map (CORE-032 lazy-load)

| # | Phase | Procedure file | Mô tả |
|---|-------|---------------|-------|
| **0** | Scan pending | `procedures/scan-pending.md` | PRE-GATE + scan 3 sources + categorize |
| **1** | UI retest | `procedures/playwright-retest.md` | MANDATORY auto-start FE + Playwright → live browser retest |
| **2** | Code retest | `procedures/code-retest.md` | MANDATORY auto-start BE + DB → curl/dotnet test live |
| **3** | Update reports | `procedures/update-reports.md` | PENDING → PASS/FAIL + evidence; issues.json CORE-039 (retest_count++) |
| **R** | Resume/Status | `procedures/resume-status.md` | --resume / --status handlers |

CI PRE-GATE steps (Na-Nc):

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` (reserved). | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `api_routes` | GitNexus `route_map()` | Grep |
| `project_structure` | Serena `get_symbols_overview` | Glob |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── findings/*.md                    ← READ + UPDATE
├── outputs/test-scenario.md         ← READ + UPDATE
├── issues.json                      ← READ + UPDATE (CORE-039)
├── block-test.json                  ← READ + UPDATE (retest_result)
├── F5-retest/
│   ├── status.json                  ← F5 own state
│   ├── retest-log.md                ← Output chính
│   └── Phase-report.md              ← CORE-028
├── screenshots/
│   └── retest-{slug}.png            ← Per UI retest (Playwright mode)
└── _locks/
    └── browser-mcp.lock             ← Shared với F2, F7, F8 (Playwright mode)
```

---

## Scan Sources

### Reports to scan

```bash
SCAN_PATTERNS=("PENDING" "SKIP" "⬜" "TODO" "(not tested)")
TARGETS=(
  "findings/db-test-report.md"
  "findings/api-test-report.md"
  "findings/ui-test-report.md"
  "findings/integration-test-report.md"
  "outputs/test-scenario.md"
)

# Find pending items
for FILE in "${TARGETS[@]}"; do
  for PATTERN in "${SCAN_PATTERNS[@]}"; do
    grep -nP "$PATTERN" "$SESSION_DIR/$FILE" >> $F5_DIR/pending-items.txt
  done
done
```

### issues.json signals to retest

```bash
# Find signals status=fixed but retest_count=0 (chưa verify after fix)
jq -r '.signals[] | select(.status=="fixed" and (.retest_count // 0) == 0) | .id' issues.json
```

### block-test.json entries to retest

```bash
# Find entries unblocked nhưng retest_result=PENDING
jq -r '.blocked_tests[] | select(.status=="unblocked" and .retest_result=="PENDING") | .id' block-test.json
```

---

## Retest Execution per Scope

### scope=ui (Playwright BẮT BUỘC)

```bash
# Step 0: MANDATORY auto-start FE + Playwright
ensure_infrastructure_running fe || exit_with_escalation
# (Playwright MCP availability check tích hợp trong PRE-GATE T4)

# Step 1+: Execute UI re-checks via Playwright MCP
# Navigate → fill/click → verify → screenshot

# Nếu item được F1 classify Nhóm 4 (visual_inspection, requires_real_payment, etc.):
#   → cho phép static code re-verification (Serena find_symbol), ghi vào manual.json
#   → BLK status="resolved", retest_result="SKIPPED", note="Nhóm 4 special case"
# Không có đường thoát "code-only" cho item ngoài Nhóm 4.
```

### scope=code

```bash
# Re-run db/api code-level tests
# - DB: SQL query test, EF migration check
# - API: curl request → verify response shape
# - Code analysis: static checks (lint, type check)

# Examples:
curl -X GET http://localhost:5048/api/v1/<endpoint> -H "Authorization: Bearer $TOKEN"
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "SELECT ..."
dotnet test --filter "FullyQualifiedName~<test-class>"
```

### scope=integration

```bash
# Re-verify FE→API chain
# - Trace headers, payload, response
# - Cross-module: simulate event publish + consume
```

### scope=all (default)

Combine all 3 scopes sequential.

---

## Report Update Pattern

```bash
# After retest, update each report row:
# Example: api-test-report.md row
# Before: | POST /api/customers | duplicate validation | PENDING | - |
# After:  | POST /api/customers | duplicate validation | PASS    | Re-tested 2026-05-13 17:00 |

# Pattern (sed):
sed -i "s/| ${TEST_REF} | ${EXPECTED} | PENDING |/| ${TEST_REF} | ${EXPECTED} | ${RESULT} | Re-tested ${ISO} |/" $REPORT
```

---

## issues.json CORE-039 Update

Sau mỗi retest item, BẮT BUỘC update issues.json:

```jsonc
{
  "id": "ISS-NNN",
  "retest_count": 1,  // incremented
  "retest_result": "PASS",  // or "FAIL"
  "retest_at": "<ISO>",
  "status": "fixed"  // (giữ fixed nếu PASS; revert "open" nếu FAIL)
}
```

Nếu retest reveal NEW issue → APPEND new signal.

---

## --status

```
================================================================
F5 wf-e2e-retest — Status Dashboard
================================================================

Scan Summary:
- Reports scanned: 5
- Pending items found: 12
  - UI: 5
  - API: 3
  - DB: 2
  - Integration: 2
- issues.json fixed (retest_count=0): 8
- block-test unblocked PENDING: 3

Total to retest: 23

Progress:
| # | Item                  | Scope | Status   | Result   |
|---|----------------------|-------|----------|----------|
| 1 | UI Customer form     | ui    | tested   | ✅ PASS   |
| 2 | API duplicate email  | code  | tested   | ❌ FAIL   |
| 3 | DB constraint UNIQUE | code  | tested   | ✅ PASS   |
| ...

Issues updated: 8 (retest_count++)
New issues from retest: 1 (ISS-015)
Browser lock: NOT HELD
================================================================
STOP
```

---

## PRE-GATE

1. **T1:** F1 reports tồn tại (findings/ + outputs/)
2. **T2:** Schema valid
3. **T3:** Có ≥1 pending item (post scan)
4. **T4 (scope=ui|all):** Playwright MCP available; FE chạy (auto-start nếu cần qua `ensure_infrastructure_running fe`). Fail sau retry → ESCALATE Nhóm 2 thay vì fallback static.
5. **T5 (scope=code|all):** BE + DB chạy (auto-start qua `ensure_infrastructure_running backend/db`). Fail → ESCALATE Nhóm 2.

Fail → E050.

---

## POST-GATE

1. **T1:** `retest-log.md` tồn tại
2. **T2:** Reports updated (PENDING/SKIP markers giảm)
3. **T3:** issues.json signals có retest_count++
4. **T4:** Mỗi retest entry có result (PASS|FAIL|SKIP)

Fail → auto-fix retry x3 → E058.

---

## Error Handling

Codes E050-E059 (per-skill namespace):

| Code | Mô tả |
|------|-------|
| E050 | F1 reports không tồn tại / không có pending |
| E051 | --session thiếu |
| E052 | Browser lock conflict (Playwright mode) |
| E053 | Playwright/FE không available (UI scope) |
| E054 | Anti-loop F6↔F5 max 3 vòng |
| E055 | Curl/dotnet test fail (transient infra) |
| E056 | Report update fail (corrupted markdown) |
| E057 | issues.json update fail (CORE-039) |
| E058 | POST-GATE T4 fail |
| E059 | Atomic write fail |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| FE/Playwright/BE/DB chưa chạy (E053) | MANDATORY auto-start (retry ×2) — KHÔNG silent fallback static analysis | Auto-start fail sau 2 retry → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion |
| Transient test fail (E055) | Retry ×2 với backoff trước khi kết luận FAIL | Fail cả 2 lần → mark FAIL thật, ghi evidence |
| Browser lock conflict (E052) | Chờ lock release (F2/F7/F8 có thể đang giữ) rồi retry | Vẫn conflict → hỏi user |
| Report markdown corrupt (E056) | Rebuild section từ retest-log + evidence | Không rebuild được → giữ raw log, STOP phase |
| Anti-loop F6↔F5 (E054) | Orchestrator tracking; F5 từ chối spawn thêm khi đạt max | Max 3 vòng → E054 escalate orchestrator |
| Item Nhóm 4 (visual/real payment/OAuth/hardware) | Cho phép static code re-verification (exception có từ F1) | Code verify FAIL → DUAL-WRITE manual.json |

---

## Output Files

| File | Path (trong session) | Loại |
|------|----------------------|------|
| retest-log.md + Phase-report.md (CORE-028) | `F5-retest/` | CREATE |
| status.json | `F5-retest/` | CREATE + UPDATE |
| findings/*.md reports | session root | UPDATE (PENDING → PASS/FAIL + evidence) |
| issues.json | session root | UPDATE (CORE-039: retest_count++, retest_result) |

> **Next:** F5 xong → F6 `/wf-e2e-fix` nếu issues.json còn open; hết open → orchestrator `/wf-e2e-verify` tiếp F7/F8.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| F1/F2/F3/F4/F7/F8 | Producer reports + issues entries |
| `wf-e2e-fix` (F6) | F5 spawn sau mỗi fix; F6 spawn F5 từ continuous loop |
| `wf-e2e-verify` orchestrator | Anti-loop tracking |

---

## Backward Compatibility

Legacy `/wf-e2e-verify <FEAT-ID> --retest --session=<id>` → orchestrator spawn F5 standalone.
