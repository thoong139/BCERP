# ensure_infrastructure_running — Infrastructure Auto-Start Procedure

**Gọi bởi:** `block-classification.md` Nhóm 2 khi phát hiện `backend_not_running` / `fe_not_running` / `missing_permissions`.

**Mục tiêu:** Phát hiện trạng thái hạ tầng → tự động start nếu đang tắt → trả về kết quả (`RUNNING` | `FAILED`).

---

## 1. Detect Infrastructure Status

```bash
function check_service_status() {
  local SERVICE_TYPE="$1"  # backend | frontend | database

  case "$SERVICE_TYPE" in
    backend)
      # Thử GET /health hoặc /api/health
      HEALTH_URL="${BACKEND_URL:-http://localhost:5000}/health"
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$HEALTH_URL" 2>/dev/null || echo "000")
      [ "$STATUS" = "200" ] && echo "RUNNING" || echo "DOWN"
      ;;
    frontend)
      FE_URL="${FRONTEND_URL:-http://localhost:3000}"
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$FE_URL" 2>/dev/null || echo "000")
      [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 400 ] && echo "RUNNING" || echo "DOWN"
      ;;
    database)
      # Kiểm tra DB connection (PostgreSQL mặc định)
      if command -v pg_isready &>/dev/null; then
        pg_isready -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" -q 2>/dev/null \
          && echo "RUNNING" || echo "DOWN"
      else
        # Fallback: kiểm tra port
        nc -z "${DB_HOST:-localhost}" "${DB_PORT:-5432}" 2>/dev/null \
          && echo "RUNNING" || echo "DOWN"
      fi
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}
```

---

## 2. Auto-Start Logic (Max 2 Retries)

```bash
function ensure_infrastructure_running() {
  local INFRA_TYPE="$1"   # backend | frontend | database | all
  local MAX_RETRY=2
  local RETRY=0
  local RESULT="FAILED"

  # Expand "all" → kiểm tra từng service
  local SERVICES=()
  case "$INFRA_TYPE" in
    all)      SERVICES=(database backend frontend) ;;
    *)        SERVICES=("$INFRA_TYPE") ;;
  esac

  for SVC in "${SERVICES[@]}"; do
    RETRY=0
    SVC_STATUS=$(check_service_status "$SVC")

    while [ "$SVC_STATUS" = "DOWN" ] && [ "$RETRY" -lt "$MAX_RETRY" ]; do
      RETRY=$((RETRY + 1))
      log_event "INFRA_START_ATTEMPT" "ensure_infra" "${SVC} down — attempt ${RETRY}/${MAX_RETRY}"

      case "$SVC" in
        backend)
          # Thử khởi động qua docker-compose hoặc dotnet run
          if [ -f "docker-compose.yml" ]; then
            docker-compose up -d backend 2>/dev/null
          elif [ -f "apps/backend/Eureka.Api/Eureka.Api.csproj" ]; then
            dotnet run --project apps/backend/Eureka.Api --no-launch-profile &
          fi
          sleep 10  # Đợi start
          ;;
        frontend)
          if [ -f "docker-compose.yml" ]; then
            docker-compose up -d frontend 2>/dev/null
          elif [ -f "apps/frontend/package.json" ]; then
            cd apps/frontend && npm run dev &
            cd - > /dev/null
          fi
          sleep 8
          ;;
        database)
          if [ -f "docker-compose.yml" ]; then
            docker-compose up -d db postgres 2>/dev/null
          fi
          sleep 5
          ;;
      esac

      SVC_STATUS=$(check_service_status "$SVC")
    done

    if [ "$SVC_STATUS" = "RUNNING" ]; then
      log_event "INFRA_UP" "ensure_infra" "${SVC} is RUNNING (after ${RETRY} attempt(s))"
      RESULT="RUNNING"
    else
      log_event "INFRA_FAILED" "ensure_infra" "${SVC} still DOWN after ${MAX_RETRY} attempts — E041"
      RESULT="FAILED"
      # Không return ngay — tiếp tục check service còn lại (ghi đủ log)
    fi
  done

  echo "$RESULT"
}
```

---

## 3. Caller Pattern (trong block-classification.md Nhóm 2)

```bash
INFRA_RESULT=$(ensure_infrastructure_running "$INFRA_TYPE")

if [ "$INFRA_RESULT" = "RUNNING" ]; then
  # Retry test — KHÔNG ghi block-test.json
  log_event "INFRA_RETRY" "block_classification" "Hạ tầng đã sẵn sàng — retry test"
  return  # Test runner sẽ thử lại
else
  # Fallback: Ghi block + ESCALATE (xem block-classification.md §Decision Tree Nhóm 2)
  write_block_entry blocking_reason="infrastructure_failed"
  # Escalation theo mode (--auto / interactive)
fi
```

---

## 4. Permission Handling (`missing_permissions`)

```bash
function grant_missing_permissions() {
  local PERM_TYPE="$1"  # db_schema | file_write | network_port

  case "$PERM_TYPE" in
    db_schema)
      # Grant schema permissions (PostgreSQL)
      PGPASSWORD="${DB_PASS:-}" psql -h "${DB_HOST:-localhost}" -U "${DB_ADMIN:-postgres}" \
        -c "GRANT ALL ON SCHEMA public TO ${DB_USER:-appuser};" 2>/dev/null
      ;;
    file_write)
      # Fix temp dir permissions
      chmod 777 "${TEMP_DIR:-/tmp}" 2>/dev/null
      ;;
    network_port)
      log_event "WARN" "ensure_infra" "Network port permission không thể auto-fix — cần root hoặc sudo"
      echo "FAILED"
      return
      ;;
  esac
  echo "RUNNING"
}
```

---

## 5. Error Codes

| Code | Mô tả |
|------|-------|
| E040 | Nhóm 1 fallback: auto-seed thất bại sau 2 lần (--auto mode log) |
| E041 | Nhóm 2 fallback: infrastructure auto-start thất bại sau 2 lần (--auto mode log) |
