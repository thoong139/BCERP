#!/usr/bin/env bash
# infra-precheck.sh — Runner cho wf-e2e-verify Phase 0 Infra Check
# Usage: ./infra-precheck.sh <session-dir>
#
# WHY: Script này tách logic bash ra khỏi procedure .md để có thể test độc lập
# và chạy lại mà không cần spawn toàn bộ orchestrator.
set -euo pipefail

SESSION_DIR="${1:-}"
[ -z "$SESSION_DIR" ] && echo "Usage: $0 <session-dir>" && exit 1

RESULT_FILE="$SESSION_DIR/infra-blockers.json"

check_backend() {
  local url="http://localhost:5048/health"
  local status
  for attempt in 1 2 3; do
    status=$(curl -fsS --max-time 5 "$url" -o /dev/null -w "%{http_code}" 2>/dev/null) || status="000"
    [ "$status" = "200" ] && echo "ok" && return 0
    [ "$attempt" -lt 3 ] && sleep 2
  done
  echo "failed"
  return 1
}

check_frontend() {
  local url="http://localhost:3000"
  local status
  for attempt in 1 2 3; do
    status=$(curl -fsS --max-time 5 "$url" -o /dev/null -w "%{http_code}" 2>/dev/null) || status="000"
    [[ "$status" =~ ^[23] ]] && echo "ok" && return 0
    [ "$attempt" -lt 3 ] && sleep 2
  done
  echo "failed"
  return 1
}

check_db() {
  # WHY: Detect driver từ package.json thay vì hardcode để hỗ trợ đa ORM
  if grep -q '"@prisma/client"' package.json 2>/dev/null; then
    npx prisma db pull --print > /dev/null 2>&1 && echo "ok:prisma" || echo "failed:prisma"
  elif grep -q '"typeorm"' package.json 2>/dev/null; then
    npx typeorm schema:log > /dev/null 2>&1 && echo "ok:typeorm" || echo "failed:typeorm"
  elif grep -q '"drizzle-orm"' package.json 2>/dev/null; then
    npx drizzle-kit check > /dev/null 2>&1 && echo "ok:drizzle" || echo "failed:drizzle"
  else
    echo "skipped:unknown"
  fi
}

# Run checks — Playwright MCP phải được orchestrator kiểm tra (không thể gọi từ bash)
BE=$(check_backend 2>/dev/null || echo "failed")
FE=$(check_frontend 2>/dev/null || echo "failed")
DB=$(check_db 2>/dev/null || echo "skipped:unknown")

# Write initial result JSON
mkdir -p "$SESSION_DIR"
cat > "$RESULT_FILE.tmp" <<JSON
{
  "\$schema": "infra-precheck-v1",
  "session_id": "$(basename "$SESSION_DIR")",
  "checked_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "checks": {
    "backend_health": { "status": "$BE", "url": "http://localhost:5048/health" },
    "frontend_health": { "status": "$FE", "url": "http://localhost:3000" },
    "playwright_mcp": { "status": "manual-check-required", "note": "Check bởi orchestrator qua mcp__plugin_playwright" },
    "db_connect": { "status": "$DB" }
  },
  "blockers": [],
  "proceed": false,
  "audit_chain": ""
}
JSON

# Validate JSON trước khi tiếp tục
jq '.' "$RESULT_FILE.tmp" > /dev/null 2>&1 || { echo "ERROR: Invalid JSON generated"; exit 1; }

# Build blockers array bằng jq accumulation
jq_script='.blockers = []'
[ "$BE" = "failed" ] && jq_script+=' | .blockers += [{"component": "Backend", "severity": "CRITICAL", "error_code": "E011", "message": "Backend http://localhost:5048/health không phản hồi sau 3 lần retry"}]'
[ "$FE" = "failed" ] && jq_script+=' | .blockers += [{"component": "Frontend", "severity": "CRITICAL", "error_code": "E012", "message": "Frontend http://localhost:3000 không phản hồi sau 3 lần retry"}]'
echo "$DB" | grep -q "^failed" && jq_script+=' | .blockers += [{"component": "Database", "severity": "CRITICAL", "error_code": "E014", "message": "Kết nối DB thất bại — chạy npx prisma migrate dev hoặc docker-compose up db"}]'

# Set proceed: chỉ true khi BE + FE OK và DB không failed
# WHY: playwright_mcp không thể verify từ bash — orchestrator chịu trách nhiệm check E013
if [ "$BE" = "ok" ] && [ "$FE" = "ok" ] && ! echo "$DB" | grep -q "^failed"; then
  jq_script+=' | .proceed = true'
fi

jq "$jq_script" "$RESULT_FILE.tmp" > "$RESULT_FILE.tmp2" && mv "$RESULT_FILE.tmp2" "$RESULT_FILE"
rm -f "$RESULT_FILE.tmp"

# Audit chain
HASH=$(sha256sum "$RESULT_FILE" | cut -d' ' -f1)
jq --arg h "sha256:$HASH" '.audit_chain = $h' "$RESULT_FILE" > "$RESULT_FILE.tmp" && mv "$RESULT_FILE.tmp" "$RESULT_FILE"

# Output proceed status cho orchestrator đọc
PROCEED=$(jq -r '.proceed' "$RESULT_FILE")
echo "F0_PROCEED=$PROCEED"

# In blockers nếu có để orchestrator hiển thị
if [ "$PROCEED" = "false" ]; then
  echo ""
  echo "=== INFRA BLOCKERS ==="
  jq -r '.blockers[] | "  [\(.error_code)] \(.component): \(.message)"' "$RESULT_FILE"
  echo ""
  echo "Lệnh khởi động:"
  jq -r '.blockers[].error_code' "$RESULT_FILE" | while read -r code; do
    case $code in
      E011) echo "  Backend:   cd apps/backend && npm run dev" ;;
      E012) echo "  Frontend:  cd apps/frontend && npm run dev" ;;
      E014) echo "  Database:  npx prisma migrate dev (hoặc docker-compose up db)" ;;
    esac
  done
fi

exit 0
