# F5 — Update Reports + retest-log.md Procedure

## Report Row Update Pattern

Reports đều dùng markdown table với cột Status. F5 update:

```
Before: | <test_ref> | <expected> | <PENDING|SKIP|⬜> | <notes> |
After:  | <test_ref> | <expected> | <PASS|FAIL>      | Re-tested ISO + evidence link |
```

```bash
# Pattern (atomic write)
update_report_row() {
  local FILE="$1"
  local TEST_REF="$2"
  local RESULT="$3"
  local EVIDENCE="$4"
  
  cp "$FILE" "$FILE.tmp"
  # Escape special chars
  ESCAPED_REF=$(echo "$TEST_REF" | sed 's/[]\/$*.^[]/\\&/g')
  
  # Replace PENDING/SKIP/⬜ với RESULT trong row
  sed -i "/| $ESCAPED_REF |/s/| PENDING |/| ${RESULT} |/" "$FILE.tmp"
  sed -i "/| $ESCAPED_REF |/s/| SKIP |/| ${RESULT} |/" "$FILE.tmp"
  sed -i "/| $ESCAPED_REF |/s/| ⬜ |/| ${RESULT} |/" "$FILE.tmp"
  
  # Add re-tested note
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -i "/| $ESCAPED_REF |/s/| ${RESULT} |/| ${RESULT} | Re-tested ${ISO}${EVIDENCE:+ — ${EVIDENCE}} |/" "$FILE.tmp"
  
  # Validate markdown still valid (simple check: no broken pipes)
  if ! head -1 "$FILE.tmp" | grep -q "^#"; then
    rm "$FILE.tmp"
    exit_with E056
  fi
  
  mv "$FILE.tmp" "$FILE"
}
```

## test-scenario.md Update

test-scenario.md có cấu trúc khác (scenario blocks, không phải single table). F5 update từng row trong table của scenario block đó:

```markdown
### Bước 3: Click 'Tạo Customer'
| Action | Expected | Actual | Pass/Fail |
|--------|----------|--------|-----------|
| Click | Form modal | <Updated> | <PASS|FAIL> |
```

## retest-log.md Output Format

```markdown
# Retest Log — F5 wf-e2e-retest

## Tổng quan
- Session: {SESSION_ID}
- Started: {ISO}
- Completed: {ISO}
- Scope: all
- Playwright enabled: YES (default)

## Pending Items Detected

| Source | Count | Examples |
|--------|-------|----------|
| Reports (PENDING/SKIP/⬜) | 12 | UNIQUE constraint, RBAC sales, ... |
| issues.json (fixed, retest_count=0) | 8 | ISS-001, ISS-005, ... |
| block-test.json (unblocked PENDING) | 3 | BLK-003, BLK-007, BLK-009 |

Total: 23 items

## Retest Results

### Reports

| File | Item | Loại | Re-check method | Result | Notes |
|------|------|------|----------------|--------|-------|
| db-test-report.md | UNIQUE constraint | code:db | psql INSERT duplicate | ✅ PASS | Constraint working |
| api-test-report.md | POST /customers validation | code:api | curl invalid payload | ❌ FAIL | Vẫn miss validation duplicate email — new ISS-018 |
| ui-test-report.md | RBAC sales dashboard | ui | Playwright login sales-manager | ✅ PASS | 5 KPI cards visible |
| ... |

### issues.json (CORE-039 updates)

| ISS-ID | Original status | Retest result | New status | retest_count |
|--------|-----------------|---------------|------------|--------------|
| ISS-001 | fixed | PASS | fixed | 1 |
| ISS-005 | fixed | FAIL | open | 1 |
| ISS-008 | fixed | PASS | fixed | 1 |
| ... |

### block-test.json (retest_result updates)

| BLK-ID | Original | Retest | Updated |
|--------|----------|--------|---------|
| BLK-003 | unblocked PENDING | PASS | retest_result=PASS |
| BLK-007 | unblocked PENDING | FAIL | retest_result=FAIL — issue raised |

## New Issues Discovered

- ISS-018: Customer create vẫn miss duplicate email validation sau fix ISS-005

## Anti-Loop Check

- f6_f5_loop_count: 1 / 3 (safe to continue)

## Phase Summary (CORE-028)

Đã quét 23 items pending. Re-test bằng Playwright (default) cho 8 UI items, curl/psql cho 12 code items. Kết quả: 18 PASS, 4 FAIL (1 vẫn còn bug đã fix trước đó — ghi ISS-018), 1 SKIP. Đã cập nhật báo cáo + issues.json. Còn 1 vòng F6↔F5 trước khi escalate.
```
