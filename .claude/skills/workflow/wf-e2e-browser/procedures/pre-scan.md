# F2 — Pre-Scan Procedure

## Goal

Đọc 4 sources từ F1, tìm tests cần BROWSER execution (không phải code-based check).

---

## Pre-Scan Sources

### Source 1: ui-test-report.md

```bash
# Find sections có FAIL/PENDING/⬜ với hint cần browser
grep -nE "FAIL|PENDING|⬜" "$UI_REPORT" | while read -r line; do
  # Check reason
  if echo "$line" | grep -qE "browser|runtime|RBAC|responsive|animation|visual"; then
    # Add to pre-scan list
    echo "$line" >> "$F2_DIR/pre-scan-candidates.txt"
  fi
done
```

### Source 2: integration-test-report.md

```bash
# Find integration tests có UI component
grep -nE "form submit|UI element|browser-test" "$INTEGRATION_REPORT" >> "$F2_DIR/pre-scan-candidates.txt"
```

### Source 3: block-test.json

```bash
# Find blocks có blocking_reason browser-related
jq -r '.blocked_tests[] | select(.blocking_reason | IN("requires_visual_inspection","requires_manual_interaction")) | "\(.id)|\(.test_ref)|\(.blocking_reason)"' "$BLOCK_TEST" >> "$F2_DIR/pre-scan-candidates.txt"
```

### Source 4: issues.json (re-verify after fix)

```bash
# Find ui issues đã fix cần re-verify trong browser
jq -r '.signals[] | select(.type=="ui" and .status=="fixed") | "\(.id)|\(.title)"' "$ISSUES" >> "$F2_DIR/pre-scan-candidates.txt"
```

---

## Deduplication + Priority

```bash
# Dedupe candidates by test_ref
sort -u "$F2_DIR/pre-scan-candidates.txt" -o "$F2_DIR/pre-scan-candidates.txt"

# Assign priority based on source:
# - block-test BLK with feature impact → P0
# - ui-test FAIL → P0
# - integration-test UI dependent → P1
# - block-test visual inspection → P2
# - issues re-verify after fix → P1
```

---

## Output: pre-scan-report.md

```markdown
# Pre-Scan Report — F2 wf-e2e-browser

## Session: {SESSION_ID}
## Generated: {ISO}

## Pre-Scan Sources

| Source | Count |
|--------|-------|
| ui-test-report (FAIL/PENDING with browser hint) | 5 |
| integration-test-report (UI dependent) | 2 |
| block-test (visual_inspection / manual_interaction) | 1 |
| issues (ui fixed, re-verify) | 3 |

Total candidates: 11
After dedup: 8

## Tests to Execute

| # | Source | Test ref | Lý do | Priority | URL |
|---|--------|----------|-------|----------|-----|
| 1 | ui-test | RBAC sales-manager dashboard | runtime check role gate | P0 | /sales/dashboard |
| 2 | ui-test | Customer create form validation | UI runtime + duplicate email | P0 | /crm/customers/new |
| 3 | integration | Order checkout flow | form submit + payment | P1 | /orders/checkout/abc |
| 4 | block-test BLK-005 | Toast animation | visual_inspection | P2 | (manual demo) |
| 5 | issues ISS-003 (fixed) | Loading state for slow API | re-verify | P1 | /tms/trips |
| ... |

## Out of Scope (KHÔNG execute trong F2)

| Skipped | Lý do | Delegated to |
|---------|-------|--------------|
| test-scenario.md scenarios | Là scenarios, KHÔNG individual UI tests | F7 wf-e2e-scenario |
| user-guide.md steps | Là hướng dẫn người dùng | F8 wf-e2e-demo |
| API-only tests | Đã làm bởi F1 Phase 3 | F1 (đã done) |
```
