-- Per-FEAT DB Schema Template (CF4)
-- Variables: {schema_name}, {source_schema}
-- Generated bởi feat-schema-init.sh — KHÔNG edit thủ công

-- =============================================================
-- Step 1: Tạo schema namespace cho FEAT này
-- =============================================================
CREATE SCHEMA IF NOT EXISTS {schema_name};

-- =============================================================
-- Step 2: Copy table structure từ source schema
-- (Thực thi qua pg_dump --schema-only | psql — không inline)
-- =============================================================
-- Lệnh: pg_dump "$DATABASE_URL" --schema-only --schema={source_schema} | \
--         sed 's/"{source_schema}"/"{schema_name}"/g' | \
--         psql "$DATABASE_URL"

-- =============================================================
-- Step 3: Seed dữ liệu nếu cần (optional)
-- =============================================================
-- SET search_path TO {schema_name};
-- INSERT INTO ...

-- =============================================================
-- Cleanup (sau khi FEAT completed — chạy feat-schema-cleanup.sh)
-- =============================================================
-- DROP SCHEMA {schema_name} CASCADE;
-- Giữ lại nếu FEAT fail (--retain-for-debug) — auto cleanup sau 24h
