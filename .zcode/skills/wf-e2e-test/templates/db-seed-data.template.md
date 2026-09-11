# DB Seed Data — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Tổng: ~{N} bản ghi | Tables: {table list}

## Hướng Dẫn Chạy Seed

```bash
# Option 1: psql trực tiếp
psql "$DATABASE_URL" -f seed-data.sql

# Option 2: Trong psql session
\i path/to/this/seed-script.sql

# Option 3: Copy SQL bên dưới và paste vào DB client
```

> ⚠️ Seed data này dùng cho mục đích **test only**. Chạy trên môi trường dev/staging, không chạy trên production.
> Để rollback: `DELETE FROM {schema}.{table} WHERE id IN ('uuid-1', 'uuid-2', ...);`

---

## Nhóm 1: Happy Path ({N} bản ghi)

*Bản ghi đầy đủ mọi field, mỗi enum value có ít nhất 1 bản ghi.*

```sql
-- {FEAT-ID} Seed Data — Nhóm 1: Happy Path
-- Chạy: psql $DATABASE_URL -c "..."

INSERT INTO {schema}.{table_name} (
  id,
  {col1},
  {col2},
  {enum_col},
  created_at,
  updated_at,
  is_deleted
) VALUES
  -- #1: Case: {mô tả — enum value A, đầy đủ field}
  (gen_random_uuid(), '{value1}', '{value2}', 'STATUS_A', NOW(), NOW(), false),
  -- #2: Case: {mô tả — enum value B}
  (gen_random_uuid(), '{value1}', '{value2}', 'STATUS_B', NOW(), NOW(), false),
  -- #3: Case: {mô tả — trạng thái pending}
  (gen_random_uuid(), '{value1}', null,        'STATUS_C', NOW(), NOW(), false),
  -- #4: Case: {mô tả}
  (gen_random_uuid(), '{value1}', '{value2}', 'STATUS_A', NOW() - INTERVAL '7 days', NOW(), false),
  -- #5: Case: {mô tả — bản ghi cũ nhất}
  (gen_random_uuid(), '{value1}', '{value2}', 'STATUS_B', NOW() - INTERVAL '30 days', NOW() - INTERVAL '1 day', false);
```

## Nhóm 2: Edge Cases ({N} bản ghi)

*Optional fields null, boundary values, ký tự đặc biệt.*

```sql
-- {FEAT-ID} Seed Data — Nhóm 2: Edge Cases

INSERT INTO {schema}.{table_name} (id, {col1}, {col2}, {enum_col}, created_at, updated_at, is_deleted) VALUES
  -- #6: Case: optional field null
  (gen_random_uuid(), '{value1}', null, 'STATUS_A', NOW(), NOW(), false),
  -- #7: Case: max length string (test varchar constraint)
  (gen_random_uuid(), '{255-char string}', '{value2}', 'STATUS_A', NOW(), NOW(), false),
  -- #8: Case: ký tự đặc biệt tiếng Việt
  (gen_random_uuid(), 'Công ty TNHH Vận Tải Hà Nội — Thử nghiệm', '{value2}', 'STATUS_A', NOW(), NOW(), false),
  -- #9: Case: unicode và emoji (nếu column hỗ trợ)
  (gen_random_uuid(), 'Test 中文字符', '{value2}', 'STATUS_B', NOW(), NOW(), false),
  -- #10: Case: numeric boundary (giá trị 0 hoặc âm nếu có decimal/numeric col)
  (gen_random_uuid(), '{value1}', '{value2}', 'STATUS_A', NOW(), NOW(), false);
```

## Nhóm 3: Trạng Thái Đặc Biệt ({N} bản ghi)

*Soft deleted, completed, cancelled, trạng thái cuối workflow.*

```sql
-- {FEAT-ID} Seed Data — Nhóm 3: Trạng Thái Đặc Biệt

INSERT INTO {schema}.{table_name} (id, {col1}, {col2}, {enum_col}, created_at, updated_at, is_deleted, deleted_at) VALUES
  -- #11: Case: soft deleted — không được hiện trong list thông thường
  (gen_random_uuid(), 'Deleted Record', '{value2}', 'STATUS_A', NOW() - INTERVAL '14 days', NOW() - INTERVAL '1 day', true, NOW() - INTERVAL '1 day'),
  -- #12: Case: completed (trạng thái cuối — readonly)
  (gen_random_uuid(), 'Completed Record', '{value2}', 'COMPLETED', NOW() - INTERVAL '5 days', NOW(), false, null),
  -- #13: Case: cancelled
  (gen_random_uuid(), 'Cancelled Record', '{value2}', 'CANCELLED', NOW() - INTERVAL '3 days', NOW(), false, null);
```

## Nhóm 4: Quan Hệ FK ({N} bản ghi)

*Parent + child để test FK constraint và cascade behavior.*

```sql
-- {FEAT-ID} Seed Data — Nhóm 4: Quan Hệ FK
-- Thứ tự: INSERT parent trước, child sau

-- Parent record (bảng cha)
INSERT INTO {schema}.{parent_table} (id, {col}, created_at, updated_at, is_deleted) VALUES
  -- #14: Parent để test HasMany relationship
  ('00000000-0000-0000-0000-seed-parent-01', 'Parent Record 1', NOW(), NOW(), false);

-- Child records (bảng con)
INSERT INTO {schema}.{child_table} (id, {parent_fk_col}, {col}, created_at, updated_at, is_deleted) VALUES
  -- #15: Child thuộc parent #14
  (gen_random_uuid(), '00000000-0000-0000-0000-seed-parent-01', 'Child Record 1', NOW(), NOW(), false),
  -- #16: Child thứ 2 thuộc parent #14 — test count/list
  (gen_random_uuid(), '00000000-0000-0000-0000-seed-parent-01', 'Child Record 2', NOW(), NOW(), false);
```

---

## Coverage Matrix

| Case | Nhóm | Table | Status | Mô tả |
|------|------|-------|--------|-------|
| #1 | Happy | {table} | STATUS_A | Đầy đủ field |
| #2 | Happy | {table} | STATUS_B | Đầy đủ field |
| ... | | | | |

## Rollback Script

```sql
-- Xoá toàn bộ seed data của {FEAT-ID} test session
-- CẢNH BÁO: Chỉ chạy trên dev/staging
DELETE FROM {schema}.{child_table} WHERE {parent_fk_col} = '00000000-0000-0000-0000-seed-parent-01';
DELETE FROM {schema}.{parent_table} WHERE id = '00000000-0000-0000-0000-seed-parent-01';
-- Với các bản ghi gen_random_uuid: rollback bằng cách DELETE WHERE created_at >= '{start_of_test}'
```
