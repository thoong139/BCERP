# F5 — Code Retest Procedure (scope=code)

## DB Tests

```bash
# Re-run constraint test
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "
  -- UNIQUE constraint
  INSERT INTO crm.customer_accounts (email, ...) VALUES ('test@example.com', ...);
  INSERT INTO crm.customer_accounts (email, ...) VALUES ('test@example.com', ...);
  -- Expect: ERROR duplicate key
"
RESULT=$?
[ $RESULT -ne 0 ] && PASS=true  # Expected to fail (constraint working)
```

```bash
# Re-run NOT NULL
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "
  INSERT INTO crm.customer_accounts (email) VALUES (NULL);
"
# Expect: ERROR not-null violation
```

```bash
# Re-run CHECK constraint
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "
  INSERT INTO finance.invoices (amount) VALUES (-100);
"
# Expect: ERROR check constraint
```

## API Tests

```bash
# Get token
TOKEN=$(curl -X POST http://localhost:5048/api/v1/auth/login \
  -d '{"email":"sysadmin@erktransport.local","password":"SysAdmin@123"}' \
  -H "Content-Type: application/json" | jq -r '.access_token')

# Happy path
RESP=$(curl -X POST http://localhost:5048/api/v1/crm/customers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","name":"Test","phone":"0123456789"}')

STATUS=$(echo "$RESP" | jq -r '.success')
[ "$STATUS" = "true" ] && PASS=true

# Validation
RESP=$(curl -X POST http://localhost:5048/api/v1/crm/customers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"invalid","name":"","phone":""}')

CODE=$(echo "$RESP" | jq -r '.data.errorCode // .error.code')
[ "$CODE" = "VALIDATION_FAILED" ] && PASS=true

# BR violation
# ... per BR catalog

# Auth
curl -X GET http://localhost:5048/api/v1/crm/customers
# Expect: 401 Unauthorized
```

## Unit Tests

```bash
# Re-run specific unit test
dotnet test apps/backend/Eureka.UnitTests/ \
  --filter "FullyQualifiedName~CustomerServiceTests.DuplicateEmail" \
  --no-build \
  --logger "console;verbosity=normal"

# Parse result
TESTS_PASSED=$(grep -oP "Passed: \K\d+" output.log)
TESTS_FAILED=$(grep -oP "Failed: \K\d+" output.log)
[ "$TESTS_FAILED" -eq 0 ] && PASS=true
```

## Static Analysis (code-bug type)

```bash
# Use Serena to verify code structure
mcp__serena__find_symbol --name_path="$SYMBOL" --include_body=true

# Check logic:
# - Có duplicate check? → grep "FindByEmail"
# - Có throw exception? → grep "throw new"
# - Có RBAC check? → grep "RequireAuthorization"
# - Có business rule? → grep "BR-NNN" or pattern

# Determine PASS/FAIL based on findings
```

## Update Reports

```bash
# Find row by test_ref, replace status column
ROW_PATTERN="| $TEST_REF |"
sed -i "/$ROW_PATTERN/s/| PENDING |/| $RESULT |/" "$REPORT"
sed -i "/$ROW_PATTERN/s/| ⬜ |/| $RESULT |/" "$REPORT"

# Append "Re-tested at" note
sed -i "/$ROW_PATTERN/s/\| $RESULT \|/| $RESULT | Re-tested $(date -u +%Y-%m-%dT%H:%M:%SZ) |/" "$REPORT"
```
