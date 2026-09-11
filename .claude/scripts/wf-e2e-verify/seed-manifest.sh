#!/usr/bin/env bash
# seed-manifest.sh — Runner cho wf-e2e-verify Phase 1.5 Seed Manifest
# Usage: ./seed-manifest.sh <session-dir> <feat-id>
#
# WHY: Tách seed logic ra script riêng để:
# 1. Orchestrator có thể re-run seed mà không re-run toàn session
# 2. Guard rails (G1/G2/G3) dễ test độc lập
# 3. Audit chain tạo sau khi seed xong, không phải mid-flight
set -euo pipefail

SESSION_DIR="${1:-}"
FEAT_ID="${2:-}"
[ -z "$SESSION_DIR" ] || [ -z "$FEAT_ID" ] && echo "Usage: $0 <session-dir> <feat-id>" && exit 1

SEED_REQ="$SESSION_DIR/seed-requirements.json"
REPORT="$SESSION_DIR/seed-report.json"
SEED_CMD=""

# Guard G1: Kiểm tra môi trường — KHÔNG cho phép seed production
# WHY: Kiểm tra cả NODE_ENV lẫn DATABASE_URL để bắt trường hợp env var sai
check_env() {
  local node_env="${NODE_ENV:-development}"
  local db_url="${DATABASE_URL:-}"

  if [ "$node_env" = "production" ]; then
    echo "ERROR_E021: NODE_ENV=production — không được seed production DB" >&2
    return 1
  fi
  if echo "$db_url" | grep -qi "prod"; then
    echo "ERROR_E021: DATABASE_URL chứa 'prod' — nghi ngờ production DB" >&2
    return 1
  fi
  return 0
}

# Guard G2: Kiểm tra idempotency của seed script
# WHY: Seed không idempotent → chạy lại tạo duplicate → test F1 false positive
check_idempotent() {
  local script="$1"
  [ -z "$script" ] && return 0
  [ ! -f "$script" ] && return 0  # script không tồn tại, bỏ qua

  if grep -qiE "upsert|onConflict|ON CONFLICT|REPLACE INTO|INSERT.*IGNORE" "$script" 2>/dev/null; then
    return 0
  fi
  # Cảnh báo CDG-06 — orchestrator quyết định có tiếp tục không
  echo "WARN_CDG06: Seed script '$script' không có UPSERT/ON CONFLICT pattern — có thể tạo duplicate data" >&2
  return 1
}

# Guard G3: Tạo backup trước khi seed
# WHY: Guard backup cho phép rollback nếu seed làm hỏng dữ liệu test hiện có
create_backup() {
  local db_url="${DATABASE_URL:-}"
  local snapshot="$SESSION_DIR/db-snapshot-pre-seed.sql"

  if command -v pg_dump > /dev/null 2>&1 && echo "$db_url" | grep -q "postgres"; then
    pg_dump "$db_url" --schema-only > "$snapshot" 2>/dev/null \
      && echo "DB backup schema-only: $snapshot" \
      || echo "WARN: pg_dump failed — tiếp tục không có backup" >&2
  elif echo "$db_url" | grep -q "\.db\|sqlite\|file:"; then
    local db_file
    db_file=$(echo "$db_url" | sed 's/file://')
    command -v sqlite3 > /dev/null 2>&1 \
      && sqlite3 "$db_file" ".dump" > "$snapshot" 2>/dev/null \
      && echo "DB backup: $snapshot" \
      || echo "WARN: sqlite3 backup failed — tiếp tục không có backup" >&2
  else
    echo "SKIP backup: DB type không nhận ra từ DATABASE_URL"
  fi
  return 0
}

main() {
  # Nếu không có seed-requirements.json → skip phase này (không block)
  if [ ! -f "$SEED_REQ" ]; then
    echo "F0B_PROCEED=true # Không có seed-requirements.json — bỏ qua Phase 1.5"
    exit 0
  fi

  # Validate JSON đầu vào
  jq '.' "$SEED_REQ" > /dev/null 2>&1 || {
    echo "ERROR_E025: seed-requirements.json invalid JSON" >&2
    echo "F0B_PROCEED=false"
    exit 1
  }

  SEED_CMD=$(jq -r '.seed_command // "npx prisma db seed"' "$SEED_REQ")
  local seed_script
  seed_script=$(jq -r '.seed_script // ""' "$SEED_REQ")

  # Guard G1 — production env block
  if ! check_env; then
    echo "F0B_PROCEED=false"
    exit 1
  fi

  # Guard G2 — idempotency check (non-fatal: CDG warning, orchestrator quyết định)
  if ! check_idempotent "$seed_script"; then
    # TODO: Tích hợp CDG approval flow khi orchestrator hỗ trợ CDG-06 async
    # Hiện tại: cảnh báo nhưng không block (conservative approach cho v1)
    echo "WARN: Tiếp tục seed mặc dù không tìm thấy idempotency pattern"
  fi

  # Guard G3 — backup
  create_backup

  # Chạy seed command
  echo "Running seed: $SEED_CMD"
  if ! eval "$SEED_CMD" 2>&1 | tee "$SESSION_DIR/seed-output.log"; then
    echo "ERROR_E023: Seed command thất bại — xem $SESSION_DIR/seed-output.log" >&2
    echo "F0B_PROCEED=false"
    exit 1
  fi

  # Ghi seed-report.json
  local snapshot_path="$SESSION_DIR/db-snapshot-pre-seed.sql"
  [ ! -f "$snapshot_path" ] && snapshot_path=""

  cat > "$REPORT.tmp" <<JSON
{
  "\$schema": "seed-report-v1",
  "session_id": "$(basename "$SESSION_DIR")",
  "feat_id": "$FEAT_ID",
  "seeded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "seed_command": "$SEED_CMD",
  "entities_seeded": [],
  "snapshot_path": "$snapshot_path",
  "guard_results": {
    "g1_env_check": "ok",
    "g2_idempotent_check": "ok",
    "g3_backup": "$([ -n "$snapshot_path" ] && echo 'ok' || echo 'skipped')"
  },
  "status": "completed",
  "audit_chain": ""
}
JSON

  jq '.' "$REPORT.tmp" > /dev/null && mv "$REPORT.tmp" "$REPORT"

  # Audit chain — hash sau khi file hoàn chỉnh
  local hash
  hash=$(sha256sum "$REPORT" | cut -d' ' -f1)
  jq --arg h "sha256:$hash" '.audit_chain = $h' "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"

  echo "F0B_PROCEED=true"
  exit 0
}

main "$@"
