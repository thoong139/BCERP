#!/usr/bin/env bash
# feat-schema-cleanup.sh — Dọn dẹp per-FEAT DB schema sau khi FEAT hoàn thành (CF4)
# Usage: ./feat-schema-cleanup.sh <feat-id> <session-id> [--retain-for-debug]
# Exit 0 = success (kể cả khi retain), Exit 1 = error

set -euo pipefail

FEAT_ID="${1:-}"
SESSION_ID="${2:-}"
RETAIN_FLAG="${3:-}"

if [ -z "$FEAT_ID" ] || [ -z "$SESSION_ID" ]; then
  echo "Usage: $0 <feat-id> <session-id> [--retain-for-debug]" >&2
  exit 1
fi

# Reconstruct schema name (phải khớp với feat-schema-init.sh)
FEAT_SLUG=$(echo "$FEAT_ID" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
SESSION_PREFIX=$(echo "$SESSION_ID" | cut -c1-8 | tr '-' '_')
SCHEMA_NAME="test_${FEAT_SLUG}_${SESSION_PREFIX}"

if [ "$RETAIN_FLAG" = "--retain-for-debug" ]; then
  echo "Schema $SCHEMA_NAME được giữ lại để debug (auto-cleanup sau 24h)"
  # Ghi retention marker để cleanup daemon biết
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) retain $SCHEMA_NAME" >> /tmp/wf-e2e-batch-schema-retention.log
  exit 0
fi

DB_URL="${DATABASE_URL:-}"

if [ -z "$DB_URL" ]; then
  echo "INFO: DATABASE_URL không được thiết lập — không có gì để cleanup" >&2
  exit 0
fi

if echo "$DB_URL" | grep -qE "^postgres(ql)?://"; then
  if command -v psql > /dev/null 2>&1; then
    psql "$DB_URL" -c "DROP SCHEMA IF EXISTS \"${SCHEMA_NAME}\" CASCADE;" 2>&1 || {
      echo "WARN: Không thể drop PostgreSQL schema: $SCHEMA_NAME" >&2
      # Không exit 1 — cleanup failure không block batch
    }
    echo "Đã xóa schema: $SCHEMA_NAME"
  else
    echo "WARN: psql không khả dụng — không thể cleanup schema $SCHEMA_NAME" >&2
  fi

elif echo "$DB_URL" | grep -qE "^(file:|sqlite)"; then
  DB_FILE=$(echo "$DB_URL" | sed 's/^file://' | sed 's/^sqlite://')
  DB_DIR=$(dirname "$DB_FILE")
  DB_BASENAME=$(basename "$DB_FILE" .db)
  FEAT_DB_FILE="${DB_DIR}/${DB_BASENAME}_${SCHEMA_NAME}.db"

  if [ -f "$FEAT_DB_FILE" ]; then
    rm "$FEAT_DB_FILE" && echo "Đã xóa: $FEAT_DB_FILE"
  else
    echo "INFO: File không tồn tại (đã được cleanup): $FEAT_DB_FILE"
  fi

else
  echo "INFO: DB type không hỗ trợ per-FEAT schema — không có gì để cleanup" >&2
fi
