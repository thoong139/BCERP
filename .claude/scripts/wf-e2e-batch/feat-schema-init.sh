#!/usr/bin/env bash
# feat-schema-init.sh — Tạo per-FEAT DB schema namespace (CF4)
# Usage: ./feat-schema-init.sh <feat-id> <session-id>
# Output (stdout): SCHEMA_NAME=<name>\nDATABASE_URL=<url>
# Exit 0 = success, Exit 1 = error

set -euo pipefail

FEAT_ID="${1:-}"
SESSION_ID="${2:-}"

if [ -z "$FEAT_ID" ] || [ -z "$SESSION_ID" ]; then
  echo "Usage: $0 <feat-id> <session-id>" >&2
  exit 1
fi

# Normalize: FEAT-ID → lowercase, dấu gạch ngang thành gạch dưới
FEAT_SLUG=$(echo "$FEAT_ID" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
# Session prefix: 8 ký tự đầu của SESSION_ID
SESSION_PREFIX=$(echo "$SESSION_ID" | cut -c1-8 | tr '-' '_')
SCHEMA_NAME="test_${FEAT_SLUG}_${SESSION_PREFIX}"

DB_URL="${DATABASE_URL:-}"

if [ -z "$DB_URL" ]; then
  echo "INFO: DATABASE_URL không được thiết lập — bỏ qua per-FEAT schema (shared DB mode)" >&2
  exit 0
fi

# Detect DB type
if echo "$DB_URL" | grep -qE "^postgres(ql)?://"; then
  # PostgreSQL: tạo schema namespace
  if command -v psql > /dev/null 2>&1; then
    psql "$DB_URL" -c "CREATE SCHEMA IF NOT EXISTS \"${SCHEMA_NAME}\";" 2>&1 || {
      echo "ERROR: Không thể tạo PostgreSQL schema: $SCHEMA_NAME" >&2
      exit 1
    }
    echo "SCHEMA_NAME=$SCHEMA_NAME"
    # Append schema query param
    if echo "$DB_URL" | grep -q "?"; then
      echo "DATABASE_URL=${DB_URL}&options=-c%20search_path%3D${SCHEMA_NAME}"
    else
      echo "DATABASE_URL=${DB_URL}?options=-c%20search_path%3D${SCHEMA_NAME}"
    fi
  else
    echo "ERROR: psql không khả dụng — không thể tạo schema namespace" >&2
    exit 1
  fi

elif echo "$DB_URL" | grep -qE "^(file:|sqlite)"; then
  # SQLite: tạo database file riêng cho FEAT
  DB_FILE=$(echo "$DB_URL" | sed 's/^file://' | sed 's/^sqlite://')
  DB_DIR=$(dirname "$DB_FILE")
  DB_BASENAME=$(basename "$DB_FILE" .db)
  NEW_DB_FILE="${DB_DIR}/${DB_BASENAME}_${SCHEMA_NAME}.db"

  # Copy database nếu tồn tại, hoặc tạo mới
  if [ -f "$DB_FILE" ]; then
    cp "$DB_FILE" "$NEW_DB_FILE" || {
      echo "ERROR: Không thể copy SQLite database" >&2
      exit 1
    }
  else
    touch "$NEW_DB_FILE"
  fi

  echo "SCHEMA_NAME=$SCHEMA_NAME"
  echo "DATABASE_URL=file:${NEW_DB_FILE}"

else
  echo "INFO: DB type '$DB_URL' không hỗ trợ per-FEAT schema — sử dụng shared DB mode" >&2
  # Không exit 1 — graceful degradation
  exit 0
fi
