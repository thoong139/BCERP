# F5 — Playwright Retest Procedure (BẮT BUỘC cho UI items)

**Áp dụng:** scope=ui hoặc scope=all với UI items. Playwright là BẮT BUỘC — không có cờ opt-out.

**Exception duy nhất:** item đã được F1 classify Nhóm 4 (manual.json với `manual_reason ∈ {visual_inspection, requires_real_payment, requires_external_api, requires_3rd_party_login, requires_hardware, requires_data_volume, requires_human_judgment}`) → cho phép re-verify qua static code analysis (xem §"Nhóm 4 special-case re-verification" cuối file). Mọi item khác: live browser BẮT BUỘC.

## Main Flow

```
1. Acquire browser-mcp.lock (shared với F2, F7, F8)
2. Login qua Playwright
3. FOR each UI pending item:
    a. Navigate đến URL relevant
    b. Execute action (theo test description)
    c. Snapshot + verify expected
    d. Capture screenshot retest-{slug}.png
    e. Determine PASS/FAIL
    f. Update report row + issues.json (CORE-039)
4. Release lock
```

---

## Per-Item Execution

### UI test rows from ui-test-report.md

```bash
# Parse test ref + expected
TEST_REF="RBAC sales-manager dashboard"
EXPECTED="Dashboard hiển thị 5 KPI cards cho sales"
URL="/sales/dashboard"
ROLE="sales-manager"

# Login
perform_login_with_role "$ROLE"

# Navigate
mcp__playwright__browser_navigate --url=http://localhost:3000$URL

# Snapshot
SNAPSHOT=$(mcp__playwright__browser_snapshot)

# Verify
if echo "$SNAPSHOT" | grep -qE "KPI|cards|dashboard"; then
  RESULT="PASS"
else
  RESULT="FAIL"
fi

# Screenshot
mcp__playwright__browser_take_screenshot --output="$SCREENSHOTS/retest-rbac-sales.png"

# Update report + issues
update_report_row "$TEST_REF" "$RESULT" "Re-tested via Playwright at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### issues.json fixed signals re-verify

```bash
# Read signal
ISS_ID="ISS-005"
SIGNAL=$(jq -r --arg id "$ISS_ID" '.signals[] | select(.id==$id)' "$ISSUES")
TYPE=$(echo "$SIGNAL" | jq -r '.type')
LOCATION=$(echo "$SIGNAL" | jq -r '.location')

# If type=ui → Playwright verify
if [ "$TYPE" = "ui" ]; then
  # Reconstruct test scenario from signal description
  # Navigate, execute, verify expected (đã fix)
  RESULT=$(execute_ui_verification "$SIGNAL")
fi

# CORE-039 update
update_issue_retest "$ISS_ID" "$RESULT"
```

### block-test unblocked entries re-verify

```bash
# Find unblocked entries
BLK_ID="BLK-003"
BLK=$(jq -r --arg id "$BLK_ID" '.blocked_tests[] | select(.id==$id)' "$BLOCK_TEST")
TEST_REF=$(echo "$BLK" | jq -r '.test_ref')

# Re-execute original test scenario
# ... per test type

# Update block-test
jq --arg id "$BLK_ID" --arg r "$RESULT" '
  (.blocked_tests[] | select(.id==$id) | .retest_result) = $r
' "$BLOCK_TEST" > "$BLOCK_TEST.tmp" && mv "$BLOCK_TEST.tmp" "$BLOCK_TEST"
```

---

## Nhóm 4 special-case re-verification (DUY NHẤT cho code-only kết quả)

UI item KHÔNG được phép retest theo cách static trừ khi đã được F1 classify Nhóm 4 từ trước (có entry trong `manual.json`):

```bash
# Check item có thuộc Nhóm 4 không
MANUAL_REASON=$(jq -r --arg ref "$TEST_REF" '
  .entries[] | select(.test_ref==$ref) | .manual_reason // empty
' "$MANUAL")

VALID_NHOM4_REASONS=("visual_inspection" "requires_real_payment" "requires_external_api" \
  "requires_3rd_party_login" "requires_hardware" "requires_data_volume" "requires_human_judgment")

is_nhom4=false
for r in "${VALID_NHOM4_REASONS[@]}"; do
  [ "$MANUAL_REASON" = "$r" ] && is_nhom4=true && break
done

if [ "$is_nhom4" = "true" ]; then
  # Nhóm 4 — cho phép static re-verification
  mcp__serena__find_symbol --name_path="$COMPONENT_NAME" --include_body=true

  # Đánh giá static:
  # - Component logic OK?
  # - Hook call API đúng pattern?
  # - i18n key tồn tại?

  RESULT="SKIPPED"   # Nhóm 4 luôn SKIPPED, ghi nhận code_verification_result
  CODE_VERIFY_RESULT="PASS|FAIL|INCONCLUSIVE"   # cập nhật manual.json
  echo "Note: Nhóm 4 special-case ($MANUAL_REASON) — code re-verify ghi vào manual.json, KHÔNG ghi PASS test runtime"
else
  # KHÔNG phải Nhóm 4 → live browser BẮT BUỘC
  log_error "E053" "retest" "Item $TEST_REF cần live browser nhưng FE/Playwright fail. ESCALATE Nhóm 2."
  classify_and_escalate_block \
    --reason "fe_not_running" \
    --detail "Retest UI item không thể chạy live sau auto-start retry. Item không thuộc Nhóm 4."
  exit_with_escalation
fi
```

---

## Browser Lock Coordination

F5 share `browser-mcp.lock` với F2, F7, F8. Acquire trước khi navigate first time, release cuối phase.

```bash
# Acquire (wait 50s max)
for i in {1..5}; do
  if [ ! -f "$LOCK" ] || [ "$(($(date +%s) - $(stat -c %Y "$LOCK")))" -gt 1800 ]; then
    echo "$$:$(date +%s):wf-e2e-retest" > "$LOCK"
    break
  fi
  sleep 10
done
[ -f "$LOCK" ] && grep -q "wf-e2e-retest" "$LOCK" || exit_with E052

trap "rm -f $LOCK" EXIT
```
