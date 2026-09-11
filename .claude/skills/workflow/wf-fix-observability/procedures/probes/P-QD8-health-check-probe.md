# P-QD8-health-check-probe — Health Check Endpoint Probe

> **Type:** runtime (bash+curl) | **Profile:** standard/deep/exhaustive | **Severity default:** HIGH | **Cache:** skip (runtime data)

Phat hien health check endpoint thieu hoac return false-positive khi internal dep down.

---

## Detection Logic

### Step 1 — Verify health check endpoint exists

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, skip P-QD8-health-check-probe" >&2
  exit 0
fi

# Try common health check paths
HEALTH_PATHS=("/health" "/healthz" "/ping" "/api/health" "/_status" "/readiness" "/liveness")
HEALTHY=0
WORKING_PATH=""

for path in "${HEALTH_PATHS[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$BASE_URL$path" 2>/dev/null)
  if [ "$STATUS" = "200" ]; then
    HEALTHY=1
    WORKING_PATH="$path"
    break
  fi
done

if [ "$HEALTHY" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-health-check-probe" \
    "critical" \
    "Health check endpoint khong ton tai" \
    "Khong tim thay health check endpoint tai any of: ${HEALTH_PATHS[*]}. Production deployment platform (k8s, ECS) yeu cau health check de auto-restart container. Without it → unhealthy pod khong duoc replace." \
    "deployment" 0 \
    "Tested paths: ${HEALTH_PATHS[*]}" \
    "[]"
  exit 0
fi
```

### Step 2 — Check health response shape

```bash
RESPONSE=$(curl -s --max-time 5 "$BASE_URL$WORKING_PATH" 2>/dev/null)

# Check if response is just "OK" / 200 (too simple — no dep status)
SIMPLE_RESPONSE=$(echo "$RESPONSE" | wc -c)
HAS_DEPS_STATUS=$(echo "$RESPONSE" | grep -ciE "database|db|cache|redis|queue|external|deps")

if [ "$SIMPLE_RESPONSE" -lt "20" ] || [ "$HAS_DEPS_STATUS" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-health-check-probe" \
    "high" \
    "Health check response thieu status cua dependencies" \
    "Health check tai $WORKING_PATH return $SIMPLE_RESPONSE bytes, khong co status cua DB/cache/queue. Risk: false-healthy — server up nhung DB down → load balancer van route traffic toi. Recommend: detailed JSON response { status, db, cache, deps[] }." \
    "deployment" 0 \
    "$RESPONSE" "[]"
fi
```

### Step 3 — Check liveness vs readiness separation

```bash
LIVENESS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$BASE_URL/liveness" 2>/dev/null)
READINESS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$BASE_URL/readiness" 2>/dev/null)

if [ "$LIVENESS" != "200" ] && [ "$READINESS" != "200" ]; then
  emit_signal_jsonl \
    "P-QD8-health-check-probe" \
    "medium" \
    "Khong tach liveness vs readiness probe" \
    "K8s/Cloud-native best practice: liveness probe (process alive) tach roi readiness probe (san sang nhan traffic — DB connected, cache warmed). Hien tai chi 1 endpoint $WORKING_PATH → khong support graceful startup/shutdown." \
    "deployment" 0 \
    "Liveness=$LIVENESS, Readiness=$READINESS" "[]"
fi
```

## Negative Patterns (KHONG emit)

1. Project la pure static site (no backend → khong can health check).
2. Project la library/SDK (no deployment).
3. Local dev environment (BASE_URL=localhost:port không production-like).
