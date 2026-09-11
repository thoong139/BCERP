# F3 — Group 1 (Data) Unblock Procedure

**Áp dụng:** blocked_tests có `blocking_reason` ∈ {`missing_seed_data`, `missing_cross_module_data`, `seed_accounts_unavailable`, `actor_account_missing`}.

**Strategy:** Auto-fix bằng cách sinh + chạy seed SQL. Max 2 retry.

---

## Flow

```
FOR each BLK-NNN với blocking_reason ∈ Group 1:
  1. CHECK điều kiện hiện tại:
     - missing_seed_data → SELECT COUNT(*) FROM <table> trong PostgreSQL
     - missing_cross_module_data → SELECT COUNT(*) FROM <upstream_table> 
     - seed_accounts_unavailable → SELECT COUNT(*) FROM users WHERE email IN (...)
     - actor_account_missing → SELECT COUNT(*) FROM customer_accounts WHERE ...
  
  2. IF count > 0 (data đã có):
     → status="unblocked"
     → retest_result="PASS" (cần retest sau)
     → unblock_attempts[].action="verify only — data exists"
     → CONTINUE next BLK
  
  3. ELSE (data thiếu):
     → ATTEMPT 1: sinh seed SQL từ db-seed-data.md → run via psql/EF
     → re-check count
     → IF success → status="unblocked", retest_result="PASS"
     → IF fail → ATTEMPT 2: re-generate seed với context khác (đọc cross-module-map.md cho upstream data)
     → IF fail lần 2 → status="blocked" (keep), unblock_attempts[].result="failed after 2 retries"
```

---

## Seed Generation Pattern (per reason)

### missing_seed_data

```bash
# Read seed SQL từ findings/db-seed-data.md
SEED_SQL=$(grep -A 200 "^## SQL INSERT" $SESSION_DIR/findings/db-seed-data.md)

# Run via psql (Docker container eureka-postgres)
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "$SEED_SQL"

# Verify count
COUNT=$(docker exec eureka-postgres psql -U eureka -d eureka_dev -t -c "SELECT COUNT(*) FROM <schema>.<table>")
```

### missing_cross_module_data

```bash
# Read cross-module-map.md để biết upstream module
UPSTREAM=$(grep "Source Module" $SESSION_DIR/findings/cross-module-map.md | awk '{print $NF}')

# Sinh seed cho upstream entity (vd: TMS Shipment) → CRM Document có data để query
# Pattern: seed upstream → trigger event handler → check downstream
```

### seed_accounts_unavailable

```bash
# Check seeders đã chạy chưa
docker exec eureka-postgres psql -U eureka -d eureka_dev -t -c "SELECT email FROM users WHERE email LIKE '%@erktransport.local'"

# Nếu không có → invoke UserSeeder qua API hoặc re-run seeders
curl -X POST http://localhost:5048/api/v1/admin/seed-test-users -H "Authorization: Bearer <sysadmin-token>"
```

### actor_account_missing

```bash
# Customer mobile test cần CustomerAccount tồn tại
# Sinh customer account fixture
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "INSERT INTO crm.customer_accounts (...) VALUES (...);"
```

---

## Update block-test.json

```jsonc
{
  "id": "BLK-001",
  "status": "unblocked",  // or "blocked" nếu fail
  "retest_result": "PASS",  // or "PENDING" nếu chưa retest
  "unblock_attempts": [
    {
      "at": "2026-05-13T14:30:00Z",
      "action": "run seed SQL từ db-seed-data.md",
      "result": "success",
      "detail": "Inserted 18 rows into crm.customer_accounts (4 nhóm)",
      "verification": {
        "method": "SELECT COUNT(*)",
        "expected": 15,
        "actual": 18,
        "passed": true
      }
    }
  ]
}
```

---

## POST-step: Update summary + Report row

```bash
# Summary
jq '.summary.unblocked += 1 | .summary.still_blocked -= 1' block-test.json

# Append row to unblock-report.md table:
# | BLK-001 | <test_ref> | 1 Data | Sinh seed | PASS |
```

---

## Error Handling

- **2 retries exhausted** → status="blocked" + unblock_attempts[].result="failed_after_retries" + E032
- **Database connection lost** → retry với backoff 5s, 15s, 30s → escalate as Group 2 (infra) nếu vẫn fail
- **Seed SQL syntax error** → log fix-log.md, suggest user review db-seed-data.md → E032
