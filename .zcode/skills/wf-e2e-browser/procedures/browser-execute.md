# F2 — Browser Execute Procedure

## Main Flow

```
1. PRE-GATE done → Acquire lock → Login
2. Read pre-scan-report.md → list tests
3. FOR each test:
    a. Update status.json current_test_idx
    b. Navigate đến URL
    c. Execute action (theo test type)
    d. Snapshot + verify expected
    e. Capture screenshot browser-{slug}.png
    f. Classify result:
       - PASS → log to browser-test-report.md
       - FAIL_BUG → APPEND issues.json (ui-runtime, severity per impact)
       - FAIL_BLOCKED → block-classification (4 nhóm)
4. Release lock → Write browser-test-report.md → POST-GATE
```

---

## Test Type Execution

### RBAC Test

```bash
# Login với role X
perform_login_with_role "sales-manager"

# Navigate đến page restricted
mcp__playwright__browser_navigate --url=$URL

# Verify role gate:
# - User có quyền → page render đúng + role-specific data
# - User không có quyền → redirect 403 hoặc empty state
SNAPSHOT=$(mcp__playwright__browser_snapshot)

# Check
if [ "$EXPECTED_ACCESS" = "granted" ]; then
  echo "$SNAPSHOT" | grep -q "$ROLE_INDICATOR" || FAIL=true
elif [ "$EXPECTED_ACCESS" = "denied" ]; then
  echo "$SNAPSHOT" | grep -q "403\|Forbidden\|Không có quyền" || FAIL=true
fi
```

### Form Validation Test

```bash
mcp__playwright__browser_navigate --url=$URL

# Fill form với invalid data
mcp__playwright__browser_fill_form --fields='[{"name":"email","value":"invalid"}]'

# Submit
mcp__playwright__browser_click --selector='button[type=submit]'

# Verify error message
SNAPSHOT=$(mcp__playwright__browser_snapshot)
if echo "$SNAPSHOT" | grep -q "$EXPECTED_ERROR_TEXT"; then
  PASS=true
else
  FAIL=true
  # APPEND issues.json: validation không trigger
fi
```

### Loading State / Slow API

```bash
mcp__playwright__browser_navigate --url=$URL

# Capture immediately
SNAPSHOT1=$(mcp__playwright__browser_snapshot)
# Check loading indicator visible
echo "$SNAPSHOT1" | grep -q "Đang tải\|loading-spinner" || FAIL=true

# Wait for data load
mcp__playwright__browser_wait_for --selector="[data-loaded=true]" --timeout=10000

SNAPSHOT2=$(mcp__playwright__browser_snapshot)
# Check loading gone + data visible
```

### Responsive Test (--mobile)

```bash
mcp__playwright__browser_resize --width=375 --height=667
mcp__playwright__browser_navigate --url=$URL

# Verify mobile layout
SNAPSHOT=$(mcp__playwright__browser_snapshot)
# Check mobile navigation visible, desktop hidden, etc.
```

---

## Block Classification trong F2

Nếu test KHÔNG execute được (không phải bug):

```
SWITCH blocking_reason:
  
  "browser_test_data_missing" (Group 1):
    → Auto-fix: seed UI test data
    → Retry
    → Fail 2x → DUAL-WRITE block-test (no implement_required, vì data issue)
  
  "fe_not_running" (Group 2):
    → Auto-fix: pnpm dev --filter=erp-web
    → Wait health
    → Fail 2x → DUAL-WRITE block-test
  
  "feature_not_implemented" (Group 3):
    → DUAL-WRITE block-test + implement-required.json
    → IMPL-REQ entry với suggested_action=implement_ui (hoặc tương tự)
    → priority P0/P1 dựa trên test priority
  
  "requires_visual_inspection" / "requires_manual_interaction" (Group 4):
    → VERIFY CODE via Serena/Grep
    → IF code PASS → DUAL-WRITE block-test (resolved) + manual.json
    → IF code FAIL → APPEND issues.json (escalate)
    → IF INCONCLUSIVE → keep blocked + manual.json INCONCLUSIVE
```

---

## browser-test-report.md Output

```markdown
# Browser Test Report — F2 wf-e2e-browser

## Tổng quan
- Session: {SESSION_ID}
- Pre-scan: 11 candidates → 8 dedup
- Executed: 7 (1 skipped — Nhóm 4 special case, ghi vào manual.json)
- Result: 5 PASS, 1 FAIL_BUG, 1 FAIL_BLOCKED

## Per-Test Results

### Test 1: RBAC sales-manager dashboard — ✅ PASS
- URL: /sales/dashboard
- Role: sales-manager
- Expected: page renders with sales metrics
- Actual: matched
- Evidence: [browser-rbac-sales.png](../screenshots/browser-rbac-sales.png)

### Test 2: Customer create duplicate email — ❌ FAIL_BUG
- URL: /crm/customers/new
- Action: fill email='existing@example.com' + submit
- Expected: error toast 'Email đã tồn tại'
- Actual: form submitted successfully (validation missing)
- Issue: ISS-012
- Evidence: [browser-customer-dup.png](../screenshots/browser-customer-dup.png)

### Test 3: Toast animation — ⚠️ FAIL_BLOCKED (Group 4)
- Blocking: requires_visual_inspection
- Code verification: PASS (toast component logic OK)
- Action: dual-write block-test BLK-008 (resolved) + manual MAN-002
- Evidence: [browser-toast.png](../screenshots/browser-toast.png)

...

## Issues phát hiện
- ISS-012: Customer create form thiếu duplicate email validation

## Block entries added
- BLK-008: Toast animation → manual (MAN-002)

## Implement-required added
- (none in this run — Group 3 ít gặp ở F2 vì F1 đã handle)

## Phase Summary (CORE-028)

Đã pre-scan 11 tests cần browser từ báo cáo F1. Sau dedup còn 8. Đã chạy thành công 7 test qua Playwright. 5 pass, 1 phát hiện bug validation (đã ghi ISS-012), 1 cần kiểm tra mắt (đã verify code OK, ghi vào manual.json). Skipped 1 test cần thanh toán thật.
```
