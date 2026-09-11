# F7 — Scenario Runner Procedure

**Áp dụng:** Single phase `scenario-run` của F7.

---

## Main Flow

```
1. PRE-GATE → Acquire browser-mcp.lock → Login
2. Parse test-scenario.md → list of scenarios
3. FOR each scenario:
    a. Update status.json: current_scenario_idx, sub_state="executing"
    b. playwright_retry(navigate_to_entry_url, max_attempts=3)
       - FAIL sau 3 lần → status="BLOCKED", skip phần còn lại của scenario
    c. Execute steps from "Bước" column (qua playwright_retry):
       - Type "click <selector>" → mcp__playwright__browser_click
       - Type "fill <selector> with <value>" → mcp__playwright__browser_type
       - Type "select <option> from <selector>" → mcp__playwright__browser_select_option
       - Type "wait <duration>" → mcp__playwright__browser_wait_for
    d. After each step: snapshot → verify "Kết quả mong đợi" match
    e. playwright_retry(capture_screenshot, scenario-NN-slug.png)
       - FAIL → log E077 WARN, tiếp tục (không block)
       - IF --strict-evidence: thiếu screenshot → mark evidence_missing, status=BLOCKED
    f. Update test-scenario.md: fill "Kết quả thực tế" + "Pass/Fail" columns
    g. IF Pass=FAIL → APPEND issues.json (severity=high)
4. Cross-module scenarios: navigate xuyên module, verify reference ID + consistency
5. Release lock → Write scenario-test-report.md → POST-GATE

KHÔNG FALLBACK: Nếu Playwright DOWN hoặc retry exhausted → status = "BLOCKED"
KHÔNG chạy curl/code-only execution thay thế Playwright.
```

---

## Step Execution Pattern

```bash
# Parse step text from "Hành động" column
# Common patterns:

# "Click button 'Tạo Customer'"
mcp__plugin_playwright_playwright__browser_click --selector='button:has-text("Tạo Customer")'

# "Fill email = test@example.com"
mcp__plugin_playwright_playwright__browser_type --selector='input[name=email]' --text='test@example.com'

# "Select 'Active' from status dropdown"
mcp__plugin_playwright_playwright__browser_select_option --selector='select[name=status]' --value='Active'

# "Wait for save success toast"
mcp__plugin_playwright_playwright__browser_wait_for --text='Lưu thành công' --timeout=5000

# "Navigate to /crm/customers"
mcp__plugin_playwright_playwright__browser_navigate --url=http://localhost:3000/crm/customers
```

---

## Expected Result Verification

```bash
# Parse "Kết quả mong đợi" column
# Verify via DOM snapshot

# Pattern 1: Element visible
mcp__plugin_playwright_playwright__browser_snapshot
# Then check if element with selector exists

# Pattern 2: Text content match
EXPECTED_TEXT=$(echo "$ROW" | jq -r '.expected')
ACTUAL=$(mcp__plugin_playwright_playwright__browser_evaluate --code='document.body.innerText')
if echo "$ACTUAL" | grep -q "$EXPECTED_TEXT"; then
  PASS=true
else
  PASS=false
fi

# Pattern 3: URL match
EXPECTED_URL="/crm/customers/123"
CURRENT_URL=$(mcp__plugin_playwright_playwright__browser_evaluate --code='window.location.pathname')
[ "$CURRENT_URL" = "$EXPECTED_URL" ] && PASS=true

# Pattern 4: Network response check
RESPONSES=$(mcp__plugin_playwright_playwright__browser_network_requests)
# Check status code, response shape
```

---

## test-scenario.md Update Pattern

```bash
# Read scenario block
SCENARIO_NUM=1
SCENARIO_BLOCK=$(awk "/^## Kịch bản $SCENARIO_NUM:/,/^## Kịch bản $((SCENARIO_NUM+1)):/" test-scenario.md)

# For each step row, update columns:
# Original: | 1 | Click 'Tạo' | Form mở | | |
# Updated:  | 1 | Click 'Tạo' | Form mở | Form modal hiện ra | ✅ PASS |

# After all steps:
# Append: **Evidence:** [screenshots/scenario-01-tao-customer.png](../screenshots/scenario-01-tao-customer.png)
# Append: **Tested by:** wf-e2e-scenario v1.0.0 at 2026-05-13T16:30:00Z
```

---

## Issue Detection + Failure Analysis

Nếu Pass/Fail = FAIL:

**Bước 1 — APPEND issues.json** (entry cơ bản):

```jsonc
{
  "id": "ISS-NNN",
  "type": "ui-runtime",
  "severity": "high",
  "phase": 7,
  "title": "Scenario {N} step {S} failed: expected {E}, got {A}",
  "description": "...",
  "location": "scenario-{N}-{slug}",
  "evidence": "screenshots/scenario-{N}-{slug}.png",
  "status": "open",
  "discovered_by_skill": "wf-e2e-scenario"
}
```

**Bước 2 — Load failure-analyzer.md** (lazy-load, lần đầu trong session):

```
→ Đọc procedures/failure-analyzer.md (chỉ lần đầu, sau đó dùng lại)
→ Gọi ANALYZE_FAILURE với: SCENARIO_NUM, SCENARIO_NAME, ISSUE_ID="ISS-NNN", STEP_ERROR=<error detail>

[Bước 1-6: Evidence → Classify → Layer/Owner → Resolution → Enrich issues.json → Accumulate]

[Bước 7: Auto-Fix Attempt]
→ Nếu failure_type ∈ {TEST_SELECTOR, AUTH_FAILURE, NETWORK_ERROR(5xx)}:
    → Chạy strategy tương ứng (selector fallback / re-login / transient retry)
    → Nhận lại AUTO_FIX_RESULT: "PASS" | "FAIL" | "SKIP"
→ Nếu failure_type ∈ {UI_BUG, BUSINESS_RULE, DATA_MISSING, UNKNOWN}:
    → AUTO_FIX_RESULT = "SKIP" (không thể fix trong session)
```

**Xử lý kết quả AUTO_FIX_RESULT:**

```
AUTO_FIX_RESULT = "PASS":
  → Đánh dấu scenario: ✅ PASS (auto-corrected)
  → KHÔNG thêm vào $RESOLUTION_ACCUMULATOR
  → Tăng $AUTO_FIX_COUNT
  → Update test-scenario.md row: | ... | ✅ PASS (auto-corrected) |

AUTO_FIX_RESULT = "FAIL" hoặc "SKIP":
  → Đánh dấu scenario: ❌ FAIL (ISS-NNN)
  → Thêm vào $RESOLUTION_ACCUMULATOR
  → Update test-scenario.md row: | ... | ❌ FAIL (ISS-NNN) |
```

---

## scenario-test-report.md Output

```markdown
# Scenario Test Report — F7 wf-e2e-scenario

## Tổng quan
- Feature: {FEAT-ID}
- Session: {SESSION_ID}
- Started: {ISO}
- Completed: {ISO}
- Total scenarios: 8
- Passed: 6
- Auto-corrected (PASS sau auto-fix): 1
- Failed: 1
- Skipped (blocked): 0

## Chi tiết per Scenario

### Kịch bản 1: Tạo Customer happy path — ✅ PASS
- Steps: 5/5 pass
- Evidence: [scenario-01-tao-customer.png](../screenshots/scenario-01-tao-customer.png)
- Duration: 12s

### Kịch bản 2: Validation duplicate email — ❌ FAIL
- Steps: 3/4 pass
- Failed step: 4 (expected error toast, got success)
- Issue: ISS-008
- Failure Type: BUSINESS_RULE | Layer: frontend
- Resolution: UI render kết quả sai so với mong đợi. Kiểm tra: 1) Business logic trong service...
- Evidence: [scenario-02-duplicate.png](../screenshots/scenario-02-duplicate.png)

...

## Cross-Module Scenarios

### Kịch bản 7: TMS → CRM document visibility — ✅ PASS
- Modules: TMS (origin) → CRM (consumer)
- Reference ID consistency: ✅
- Data consistency: ✅
- Saga compensation: N/A

## Issues phát hiện
- ISS-008: validation duplicate email không trigger
- ISS-009: ...

## Hướng Giải Quyết (chỉ có khi có FAIL)

> Sinh tự động từ failure-analyzer. Đây là gợi ý — không phải root cause chính thức.

| # | Scenario | Failure Type | Layer | Hướng Giải Quyết | Owner Đề Xuất |
|---|----------|-------------|-------|------------------|--------------|
| 2 | Validation duplicate email | BUSINESS_RULE | frontend | UI render sai. Kiểm tra service/usecase... | frontend-developer |

**Bước tiếp theo:**
- backend issues → `/wf-fix-bugs --dims=QD1,QD3`
- frontend issues → `/wf-fix-bugs --dims=QD1,QD5`
- test issues → cập nhật test-scenario.md rồi `--resume`
- database issues → kiểm tra seed data + migration rồi `--resume`

## Phase Summary (CORE-028)

Đã chạy 8 kịch bản qua trình duyệt thật. 6 trên 8 pass, 2 fail vì validation logic chưa đúng. Đã ghi 2 issues vào issues.json với hướng giải quyết cụ thể. Cross-module chain hoạt động ổn.
```

---

## Resolution Report Generation (POST-GATE)

Sau khi tất cả scenarios chạy xong, nếu `$RESOLUTION_ACCUMULATOR` không rỗng:

```bash
# Tạo resolution-report.md từ RESOLUTION_ACCUMULATOR
RESOLUTION_REPORT="$F7_DIR/resolution-report.md"

cat > "$RESOLUTION_REPORT" << EOF
# F7 Resolution Report — ${SESSION_ID}

> Sinh tự động bởi failure-analyzer khi phát hiện scenario FAIL.
> Đây là hướng giải quyết gợi ý, không phải root cause chính thức.

## Tổng Quan
- **Tổng FAIL**: ${FAIL_COUNT} scenarios
- **Phân bổ layer**: backend (${COUNT_BACKEND}) | frontend (${COUNT_FRONTEND}) | test (${COUNT_TEST}) | database (${COUNT_DB}) | unknown (${COUNT_UNKNOWN})

## Chi Tiết Hướng Giải Quyết

| # | Scenario | Failure Type | Layer | Hướng Giải Quyết | Owner Đề Xuất |
|---|----------|-------------|-------|------------------|--------------|
${RESOLUTION_ACCUMULATOR}

## Bước Tiếp Theo

- **backend (NETWORK_ERROR / AUTH_FAILURE)**: Chạy \`/wf-fix-bugs --dims=QD1,QD3\`
- **frontend (UI_BUG / BUSINESS_RULE)**: Chạy \`/wf-fix-bugs --dims=QD1,QD5\`
- **test (TEST_SELECTOR)**: Cập nhật selector trong test-scenario.md → chạy lại \`--resume\`
- **database (DATA_MISSING)**: Kiểm tra seed data + migration → chạy lại \`--resume\`
EOF
```

Nếu `$RESOLUTION_ACCUMULATOR` rỗng (all PASS) → **không tạo** resolution-report.md.
