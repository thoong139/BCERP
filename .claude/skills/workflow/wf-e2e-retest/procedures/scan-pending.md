# F5 — Scan Pending Items Procedure

## Sources

### 1. Reports (markdown)

```bash
SCAN_PATTERNS=("PENDING" "SKIP" "⬜" "TODO" "(not tested)" "Chưa test")

for FILE in "${REPORTS[@]}"; do
  test -f "$FILE" || continue
  
  # Find rows có pattern
  for PATTERN in "${SCAN_PATTERNS[@]}"; do
    grep -nP "$PATTERN" "$FILE" | while IFS= read -r line; do
      # Parse row (markdown table)
      # | Test name | Expected | Status | Notes |
      TEST_NAME=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
      
      # Categorize by file
      case "$FILE" in
        *db-test-report*) SCOPE="code:db";;
        *api-test-report*) SCOPE="code:api";;
        *ui-test-report*) SCOPE="ui";;
        *integration-test-report*) SCOPE="integration";;
        *test-scenario*) SCOPE="scenario";;
      esac
      
      echo "$FILE|$line|$TEST_NAME|$SCOPE" >> "$F5_DIR/pending-items.txt"
    done
  done
done
```

### 2. issues.json (fixed but not retested)

```bash
jq -r '.signals[] | select(.status=="fixed" and (.retest_count // 0) == 0) | "issues.json|\(.id)|\(.title)|\(.type)"' "$ISSUES" >> "$F5_DIR/pending-items.txt"
```

### 3. block-test.json (unblocked, retest_result=PENDING)

```bash
jq -r '.blocked_tests[] | select(.status=="unblocked" and .retest_result=="PENDING") | "block-test.json|\(.id)|\(.test_ref)|unblocked"' "$BLOCK_TEST" >> "$F5_DIR/pending-items.txt"
```

### 4. implement-required.json (done items cần verify) — Optional

```bash
jq -r '.entries[] | select(.status=="done" and .retest_result=="PENDING") | "implement-required.json|\(.id)|\(.test_ref)|impl-verify"' "$IMPL_REQ" >> "$F5_DIR/pending-items.txt"
```

## Filter by --scope flag

```
scope=ui → keep rows có SCOPE=ui hoặc SCOPE=integration (UI side)
scope=code → keep rows có SCOPE=code:* (db, api)
scope=all → keep all
```

## Dedupe

Pending items có thể trùng (vd: ISS-NNN trong issues.json đồng thời có row PENDING trong report). Dedupe by `test_ref` + `source`.

## Output: pending-items.txt

```
findings/db-test-report.md|line 45|UNIQUE constraint test|code:db
findings/api-test-report.md|line 78|POST /api/customers validation|code:api
findings/ui-test-report.md|line 22|RBAC role gate|ui
issues.json|ISS-005|fixed customer validation|api
block-test.json|BLK-003|unblocked GET endpoint|unblocked
```

Total count = số items cần retest. Set $TOTAL trong status.json.
