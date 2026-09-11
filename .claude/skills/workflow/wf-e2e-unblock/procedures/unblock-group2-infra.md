# F3 — Group 2 (Infra) Unblock Procedure

**Áp dụng:** blocked_tests có `blocking_reason` ∈ {`backend_not_running`, `fe_not_running`, `missing_permissions`}.

**Strategy:** Auto-fix bằng cách start infrastructure / grant permission. Max 2 retry.

---

## Flow

```
FOR each BLK-NNN với blocking_reason ∈ Group 2:
  1. CHECK trạng thái hiện tại:
     - backend_not_running → curl http://localhost:5048/health
     - fe_not_running → curl -L http://localhost:3000 (check status 200)
     - missing_permissions → query RBAC tables / check role permissions
  
  2. IF healthy:
     → status="unblocked", retest_result="PASS"
     → CONTINUE next BLK
  
  3. ELSE attempt fix:
     - backend_not_running → dotnet watch --project apps/backend/Eureka.Api (timeout 60s)
     - fe_not_running → cd apps/erp-web && pnpm dev (timeout 60s)
     - missing_permissions → INSERT INTO role_permissions ... + invalidate cache
  
  4. Re-check → IF healthy → unblocked. ELSE retry (max 2). Then E033.
```

---

## Infrastructure Auto-Start Pattern

### backend_not_running

```bash
# Check Docker compose status
docker compose -f docker-compose.local.yml ps eureka-api

# Nếu Stopped → start
docker compose -f docker-compose.local.yml up -d eureka-api

# Wait for health
for i in {1..30}; do
  curl -s -f http://localhost:5048/health && break
  sleep 2
done

# IF fail after 60s → auto-diagnose:
#   - Check logs: docker logs eureka-api --tail 50
#   - Check DB connection: pg_isready -h localhost
#   - Check port conflict: netstat -an | grep 5048
```

### fe_not_running

```bash
# Background start
pnpm --filter erp-web dev > /tmp/erp-web.log 2>&1 &
PID=$!

# Wait
for i in {1..30}; do
  curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -E "200|307" && break
  sleep 2
done

# IF fail → kill PID, check log /tmp/erp-web.log
```

### missing_permissions

```bash
# Sysadmin grant permission via SQL
docker exec eureka-postgres psql -U eureka -d eureka_dev -c "
INSERT INTO settings.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM settings.roles r, settings.permissions p
WHERE r.name = '<role>' AND p.code = '<missing-permission>'
ON CONFLICT DO NOTHING;
"

# Invalidate RBAC cache (Redis)
docker exec eureka-redis redis-cli DEL "rbac:role:<role>"
```

---

## Update block-test.json

```jsonc
{
  "id": "BLK-002",
  "status": "unblocked",
  "retest_result": "PASS",
  "unblock_attempts": [
    {
      "at": "2026-05-13T14:35:00Z",
      "action": "docker compose up -d eureka-api + wait health 60s",
      "result": "success",
      "detail": "Backend started, /health returned 200",
      "verification": {
        "method": "curl /health",
        "expected": "200 OK",
        "actual": "200 OK",
        "passed": true
      }
    }
  ]
}
```

---

## Auto-Diagnose Pattern

Nếu 2 retries fail, capture diagnostics:

```bash
# Backend diagnose
{
  echo "=== Docker status ==="
  docker compose -f docker-compose.local.yml ps
  echo "=== Eureka.Api logs (last 50) ==="
  docker logs eureka-api --tail 50
  echo "=== DB connection ==="
  docker exec eureka-postgres pg_isready
  echo "=== Port 5048 ==="
  netstat -an | grep 5048
} > $F3_DIR/diagnose-backend.log

# Append diagnose path vào unblock_attempts[].detail
```

---

## Error Handling

- **Backend không start sau 60s** → E033 + capture diagnose log
- **Port conflict** → suggest user kill process holding port
- **DB connection lost** → escalate Group 1 (data) inheritance
- **Permission grant fail** → check if role exists, suggest manual grant
