# Phase 0: Infra Health Check — PRE-GATE toàn Session

## Mục đích
Kiểm tra dịch vụ cốt lõi + Docker service discovery TRƯỚC khi bắt đầu bất kỳ E2E phase nào.
- Backend/Frontend/DB fail → BLOCK toàn bộ session (KHÔNG advance F0a/F1-F8).
- Playwright MCP fail → `playwright_available=false` (KHÔNG block session — F2/F7/F8 tự xử lý).

## Input
- Session ID
- FEAT-ID context

## Output
- `infra-blockers.json` (schema infra-precheck-v1) — bao gồm `playwright_available` boolean + `docker_services` map
- Phase 0 report: `Phase0-report.md`
- Trả về `F0_PROCEED=true|false`

---

## Thực Thi

### Bước 1: Backend Health

```bash
check_backend():
  url="http://localhost:5048/health"
  start=$(date +%s%N)
  for attempt in 1 2 3; do
    response=$(curl -fsS --max-time 5 "$url" -o /dev/null -w "%{http_code}" 2>/dev/null)
    if [ "$response" = "200" ]; then
      latency=$(( ($(date +%s%N) - start) / 1000000 ))
      record_check "backend_health" "ok" null "$url" $latency
      return 0
    fi
    [ $attempt -lt 3 ] && sleep 2
  done
  record_check "backend_health" "failed" "E011" "$url" 0
  return 1
```

### Bước 2: Frontend Health

```bash
check_frontend():
  url="http://localhost:3000"
  for attempt in 1 2 3; do
    response=$(curl -fsS --max-time 5 "$url" -o /dev/null -w "%{http_code}" 2>/dev/null)
    if echo "$response" | grep -qE "^[23]"; then  # 200, 301, 302, etc.
      record_check "frontend_health" "ok" null "$url" 0
      return 0
    fi
    [ $attempt -lt 3 ] && sleep 2
  done
  record_check "frontend_health" "failed" "E012" "$url" 0
  return 1
```

### Bước 3: Playwright MCP Echo Test

```
check_playwright_mcp():
  Spawn tạm thời Playwright navigate "about:blank":
  - Dùng mcp__plugin_playwright_playwright__browser_navigate(url="about:blank")
  - Thành công → record_check "playwright_mcp" "ok" null; PLAYWRIGHT_AVAILABLE=true
  - Thất bại / timeout → record_check "playwright_mcp" "failed" "E013"; PLAYWRIGHT_AVAILABLE=false
    ⚠ E013 KHÔNG set F0_PROCEED=false — Playwright fail chỉ block F2/F7/F8, KHÔNG block toàn session.

  Capture Playwright version từ response nếu có.
```

### Bước 4: DB Connection Test

```bash
check_db_connect():
  # Detect driver từ package.json
  if grep -q '"@prisma/client"' package.json 2>/dev/null; then
    driver="prisma"
    cmd="npx prisma db pull --print 2>/dev/null | head -1"
  elif grep -q '"typeorm"' package.json 2>/dev/null; then
    driver="typeorm"
    cmd="npx typeorm schema:log 2>&1 | head -1"
  elif grep -q '"drizzle-orm"' package.json 2>/dev/null; then
    driver="drizzle"
    cmd="npx drizzle-kit check:mysql 2>&1 | head -1"  # or check:pg
  else
    driver="unknown"
    cmd="echo 'no-driver'"
  fi

  result=$($cmd 2>/dev/null)
  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    record_check "db_connect" "ok" null
    return 0
  fi
  record_check "db_connect" "failed" "E014"
  return 1
```

### Bước 5: Docker Service Discovery

```bash
discover_docker_services():
  # Ưu tiên test-parallel compose (dùng khi chạy skill E2E)
  COMPOSE_FILE=""
  for f in docker-compose.test-parallel.yml docker-compose.local.yml docker-compose.yml; do
    [ -f "$f" ] && COMPOSE_FILE="$f" && break
  done

  DOCKER_SERVICES="{}"
  if [ -n "$COMPOSE_FILE" ]; then
    RUNNING=$(docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null || echo "")

    # Services trong docker-compose.test-parallel.yml:
    # backend: 5048-5052:5048 (parallel replicas), frontend: 3000-3004:3000
    # db: 5432, redis: 6379, rabbitmq: 5672/15672
    declare -A SERVICES=(
      ["backend"]="5048"
      ["frontend"]="3000"
      ["db"]="5432"
      ["redis"]="6379"
      ["rabbitmq"]="5672"
    )

    for svc in "${!SERVICES[@]}"; do
      base_port="${SERVICES[$svc]}"

      # backend/frontend có thể scale 1-5 replicas; redis/rabbitmq/db chỉ 1 instance
      max_replicas=1
      [ "$svc" = "backend" ] || [ "$svc" = "frontend" ] && max_replicas=5

      active_count=0
      for offset in $(seq 0 $((max_replicas - 1))); do
        check_port=$((base_port + offset))
        nc -z -w1 localhost "$check_port" 2>/dev/null && active_count=$((active_count + 1))
      done

      if [ "$active_count" -gt 0 ]; then
        status="running"
      else
        status="not_running"
      fi

      DOCKER_SERVICES=$(echo "$DOCKER_SERVICES" | jq \
        --arg s "$svc" --arg p "$base_port" --arg st "$status" --argjson c "$active_count" \
        '.[$s] = {base_port: ($p | tonumber), status: $st, active_replicas: $c}')
    done

    DOCKER_SERVICES=$(echo "$DOCKER_SERVICES" | jq \
      --arg f "$COMPOSE_FILE" '. + {compose_file: $f}')
  else
    DOCKER_SERVICES='{"note": "no docker-compose file found"}'
  fi
  export DOCKER_SERVICES
```

### Bước 6: Tổng hợp và Output

```bash
finalize_f0():
  # CHỈ backend/frontend/db quyết định F0_PROCEED — KHÔNG phải playwright
  all_ok=true
  for check in backend_health frontend_health db_connect; do
    if [ "$(get_check_status $check)" != "ok" ]; then
      all_ok=false
    fi
  done

  # Tạo infra-blockers.json từ template, thêm playwright_available + docker_services
  populate_template "templates/infra-blockers.template.json" \
    | jq --argjson pa "${PLAYWRIGHT_AVAILABLE:-false}" \
         --argjson ds "${DOCKER_SERVICES:-{}}" \
         '.playwright_available = $pa | .docker_services = $ds' \
    > "$SESSION_DIR/infra-blockers.json.tmp"
  mv "$SESSION_DIR/infra-blockers.json.tmp" "$SESSION_DIR/infra-blockers.json"

  # Audit chain
  audit_hash=$(sha256sum "$SESSION_DIR/infra-blockers.json" | cut -d' ' -f1)
  jq --arg hash "sha256:$audit_hash" '.audit_chain = $hash' "$SESSION_DIR/infra-blockers.json" > tmp.$$ && mv tmp.$$ "$SESSION_DIR/infra-blockers.json"

  PLAYWRIGHT_WARN=""
  [ "${PLAYWRIGHT_AVAILABLE:-false}" = "false" ] && \
    PLAYWRIGHT_WARN=" ⚠ Playwright không available — F2/F7/F8 sẽ bị blocked_no_playwright."

  if $all_ok; then
    F0_PROCEED=true
    write_phase_report "Phase0-report.md" "PASS" "Backend/Frontend/DB OK.${PLAYWRIGHT_WARN}"
  else
    F0_PROCEED=false
    blockers=$(jq '.blockers' "$SESSION_DIR/infra-blockers.json")
    write_phase_report "Phase0-report.md" "FAIL" "$(format_blockers_vietnamese $blockers)"

    echo "=== INFRA BLOCKED ==="
    jq -r '.blockers[] | "⚠ \(.component) [\(.error_code)]: \(.message)"' "$SESSION_DIR/infra-blockers.json"
    echo ""
    echo "Lệnh khởi động:"
    for blocker_code in $(jq -r '.blockers[].error_code' "$SESSION_DIR/infra-blockers.json"); do
      case $blocker_code in
        E011) echo "  Backend: dotnet run --project apps/backend/Eureka.Api" ;;
        E012) echo "  Frontend: cd apps/erp-web && pnpm dev" ;;
        E014) echo "  Database: docker compose -f docker-compose.minimal.yml up -d" ;;
      esac
    done
  fi

  # Thông báo Playwright nếu unavailable (KHÔNG exit)
  if [ "${PLAYWRIGHT_AVAILABLE:-false}" = "false" ]; then
    echo "⚠ E013: Playwright MCP không available. Để enable: restart Claude Code với Playwright MCP plugin."
    echo "  F2/F7/F8 sẽ blocked_no_playwright — re-run với --resume sau khi Playwright available."
  fi

  export F0_PROCEED
```

---

## Error Codes

| Code | Mô tả | Hard blocker? |
|------|-------|---------------|
| E011 | Backend health check fail (localhost:5048/health timeout/4xx/5xx) | **YES** — block session |
| E012 | Frontend health check fail (localhost:3000 không phản hồi) | **YES** — block session |
| E013 | Playwright MCP không respond (browser navigate fail) | **NO** — set `playwright_available=false` only |
| E014 | DB connection fail (driver detected nhưng connect thất bại) | **YES** — block session |

---

## Phase Report Template

```
## Phase 0: Infra Health Check — PASS|FAIL|BLOCKED
Thời gian: {ISO-8601}
**Đã làm:** Kiểm tra Backend, Frontend, DB. Docker discovery: {N} services detected. Playwright MCP: {ok|unavailable}.
**Kết quả:** {X}/3 core checks PASS. Playwright available: {true|false}. {Danh sách blockers nếu có}
**Tiếp theo:** {Nếu PASS: F0a wf-e2e-finding | Nếu FAIL: Khởi động dịch vụ bị lỗi | Playwright warn: re-run với Playwright khi available}
```
