# Database Design — [TÊN DỰ ÁN]

> READS: `phase2-features/[sys]/[mod]/[feat].md` (business rules, entities), `P3-01-architecture.md`
> OUTPUT: DDL, indexes, migration strategy
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: YYYY-MM-DD | DB: PostgreSQL 15+
>
> **📐 Hướng dẫn scale:** Khi hệ thống có >20 tables:
> - Tách file: `database-design/shared.md` (sections 1-2, 4-6) + `database-design/[system].md` (section 3 per system)
> - Shared tables (users, roles, permissions) luôn nằm trong `shared.md`
> - FK cross-system: ghi rõ trong cả 2 file, đánh dấu `-- CROSS-SCHEMA FK`

---

> **📋 ID Format Guide:** `DB-[SCHEMA]-[NNN]` — SCHEMA = tên schema viết hoa (SHARED, CRM, ERP...), NNN = số thứ tự tăng dần per schema bắt đầu từ 001 (VD: DB-SHARED-001, DB-CRM-001). Mỗi table SQL comment phải có DB-ID + REQ-ID + FEAT-ID tương ứng.

---

## 1. Schema Organization

| Schema | System | Mục đích |
|--------|--------|---------|
| `public` | Shared | Users, roles, permissions, sessions |
| `[sys_name]` | SYS-[XXX] | [System data] |
| `[sys_name]` | SYS-[YYY] | [System data] |

**Quy tắc naming:**
```
Tables:  snake_case, plural      (customers, order_items)
Columns: snake_case              (created_at, user_id)
Indexes: idx_[table]_[columns]   (idx_customers_status)
FKs:     fk_[table]_[ref_table]  (fk_orders_customers)
```

---

## 2. Shared Tables (schema: public)

### users
```sql
-- DB-[SCHEMA]-[NNN] | REQ-ID: REQ-[DEPT]-[NNN] | FEAT-ID: FEAT-[SYS]-[MOD]-[NNN]
CREATE TABLE public.users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,          -- bcrypt, rounds=12
  full_name     VARCHAR(200) NOT NULL,
  is_active     BOOLEAN DEFAULT true,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at    TIMESTAMPTZ                      -- soft delete
);

CREATE INDEX idx_users_email ON public.users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON public.users(is_active) WHERE deleted_at IS NULL;
```

### roles
```sql
-- [DB-NNN] | REQ-ID: [REQ-DEPT-NNN]
-- [EXAMPLE: DB-SHARED-002 | REQ-AUTH-002 — xóa dòng này và thay bằng ID thực khi dùng template]
CREATE TABLE public.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(100) UNIQUE NOT NULL,      -- 'sales_manager', 'accountant'
  system      VARCHAR(50) NOT NULL,              -- 'CRM', 'ERP', 'ALL'
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

### user_roles
```sql
-- [DB-NNN]
-- [EXAMPLE: DB-SHARED-003 — xóa dòng này và thay bằng ID thực khi dùng template]
CREATE TABLE public.user_roles (
  user_id    UUID REFERENCES public.users(id) ON DELETE CASCADE,
  role_id    UUID REFERENCES public.roles(id) ON DELETE CASCADE,
  granted_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  granted_by UUID REFERENCES public.users(id),
  PRIMARY KEY (user_id, role_id)
);
```

---

## 3. [SYSTEM_NAME] Tables (schema: [sys_schema])

> Copy section này cho mỗi system/module. Xem business rules trong `features/[sys]/[mod]/[feat].md`

### Module: [Module Name] (MOD-[SYS]-[MOD])

```sql
-- DB-[SYS]-[MOD]-001 | REQ-ID: REQ-[DEPT]-001 | FEAT-ID: FEAT-[SYS]-[MOD]-001
CREATE TABLE [sys_schema].[table_name] (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          VARCHAR(20) UNIQUE,               -- Auto-generate nếu cần
  [field]       VARCHAR(200) NOT NULL,
  [field]       TEXT,
  status        VARCHAR(20) DEFAULT '[DEFAULT]'   -- Enum: VALUE_A, VALUE_B
                CHECK (status IN ('VALUE_A', 'VALUE_B', 'VALUE_C')),
  [ref_id]      UUID REFERENCES [other_schema].[table](id),
  created_by    UUID REFERENCES public.users(id) NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  deleted_at    TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_[table]_status   ON [sys_schema].[table](status) WHERE deleted_at IS NULL;
CREATE INDEX idx_[table]_ref_id   ON [sys_schema].[table]([ref_id]);
CREATE INDEX idx_[table]_search   ON [sys_schema].[table] USING gin(
  to_tsvector('simple', coalesce([field1], '') || ' ' || coalesce([field2], ''))
);
```

---

## 4. Common Patterns

### Auto-generate code
```sql
-- Sequence-based code generation: KH-000001, DH-000001
CREATE SEQUENCE [schema].[table]_code_seq START 1;

-- Trong application code:
code = prefix + String(nextval('[schema].[table]_code_seq')).padStart(6, '0')
-- Ví dụ: 'KH-' + '000001' = 'KH-000001'
```

### Auto-update updated_at
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Áp dụng cho mỗi table:
CREATE TRIGGER update_[table]_updated_at
  BEFORE UPDATE ON [schema].[table]
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Soft delete query pattern
```sql
-- LUÔN thêm WHERE deleted_at IS NULL trong mọi query
SELECT * FROM [table] WHERE id = $1 AND deleted_at IS NULL;
```

---

## 5. Migration Strategy

```
Convention: migrations/[YYYYMMDDHHMMSS]_[description].sql
Ví dụ:      migrations/20240115103000_create_customers_table.sql

Rules:
  ✅ Mỗi migration: 1 DDL thay đổi duy nhất
  ✅ Mọi migration có UP và DOWN section
  ✅ Test migration trên development/staging trước production
  ✅ Backup DB trước khi chạy migration production
  ❌ Không sửa migration đã chạy trên production
  ❌ Không drop column ngay — dùng 3-step: deprecate → migrate data → drop
```

**Template migration file:**
```sql
-- Migration: [description]
-- Date: YYYY-MM-DD
-- Author: [Name]
-- REQ-ID: REQ-[DEPT]-[NNN]
-- FEAT-ID: FEAT-[SYS]-[MOD]-[NNN]

-- === UP ===
[DDL statements here]

-- === DOWN ===
[Rollback statements here]
```

---

## 6. Index Strategy

| Loại | Khi nào tạo | Pattern |
|------|------------|---------|
| Primary Key | Mọi table | UUID, tự động |
| Foreign Key | Mọi FK column | `idx_[table]_[fk_column]` |
| Status filter | Column hay filter | Partial: `WHERE deleted_at IS NULL` |
| Full-text search | Search field | GIN index với `to_tsvector` |
| Unique constraint | Business unique | `UNIQUE` hoặc unique partial index |
| Composite | Hay query combo | `idx_[table]_[col1]_[col2]` |
