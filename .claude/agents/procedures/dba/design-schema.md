# Playbook: Thiết kế Database Schema

> **Type**: Agent Skill Playbook
> **Agent**: dba
> **Triggered by**: /wf-design (Phase 3) khi cần thiết kế database schema cho hệ thống mới hoặc module mới
> **Output**: `.mc-data/docs/phase3-architecture/database-schema.md` + migration SQL files

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` Phase 3
- Khi cần thiết kế schema cho hệ thống mới từ feature specs
- Khi thêm module mới cần data model riêng
- Khi architect yêu cầu ERD và migration scripts

---

## Procedure

### Bước 1: Đọc context và data requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3

Cần xác định:
□ Danh sách features đã được approve (từ phase2-features/)
□ REQ-IDs liên quan đến data/schema
□ Interface type: API-only / Web App / Mobile App (ảnh hưởng data access patterns)
□ Ước tính data volume: số rows khởi điểm và growth rate hàng tháng
□ Read/write ratio: read-heavy (reporting)? write-heavy (transactional)?
□ Distributed system không? Multi-region? Nếu có → primary key strategy thay đổi
□ Multi-tenancy không? Cách phân tách tenant data?
```

Sau khi đọc xong:
```
READ: .claude/references/team-expert/engineering/database-patterns.md
→ Section 1 (Database Selection Matrix): confirm PostgreSQL là đúng lựa chọn
→ Section 2 (Naming Conventions): áp dụng từ đầu
→ Section 3 (Common Schema Patterns): soft delete, audit trail, multi-tenancy
```

### Bước 2: Entity identification

Từ feature specs, trích xuất tất cả entities:

```
Với mỗi feature spec, liệt kê:
□ Các "danh từ" xuất hiện lặp lại → entity candidates
□ Quan hệ giữa chúng: 1-1, 1-N, N-M
□ Attributes của từng entity
□ Business constraints (một user chỉ có một profile, order phải có ít nhất 1 item...)

Output dạng bảng:
| Entity | Attributes (sơ bộ) | Quan hệ | Notes |
|--------|--------------------|---------|-------|
| users  | id, email, name    | 1:N orders | Auth entity |
```

**Phân biệt entity vs value object:**
- Entity: có identity riêng, tồn tại độc lập → table riêng
- Value object: chỉ có nghĩa trong context của entity cha (địa chỉ giao hàng, line item) → có thể embed JSON hoặc table riêng tùy access pattern

### Bước 3: Normalization — 3NF mặc định

Áp dụng 3NF cho tất cả tables. Chỉ denormalize khi có lý do cụ thể:

```
1NF: Mỗi column chứa giá trị nguyên tử — không array trong column (trừ PostgreSQL ARRAY/JSONB khi justified)
2NF: Mọi non-key column phụ thuộc vào toàn bộ primary key
3NF: Không có transitive dependency — column B không phụ thuộc vào column A là non-key

Khi cho phép denormalize (phải document lý do):
□ Snapshot data: lưu giá sản phẩm tại thời điểm đặt hàng (không thay đổi theo catalog)
□ Tính toán tổng hợp thường xuyên đọc: total_amount trên orders (thay vì SUM từ order_items mỗi lần)
□ Read-heavy analytics: materialized view thay vì denormalize trực tiếp

WHY ghi trong comment SQL: -- Denormalize: lưu snapshot price tại thời điểm order để audit
```

### Bước 4: Primary key strategy

Chọn strategy phù hợp dựa trên context:

```
DISTRIBUTED SYSTEM (microservices, multi-region, external exposure):
→ UUID v7 hoặc ULID: time-ordered, globally unique, URL-safe
→ PostgreSQL: gen_random_uuid() cho UUID v4 (nếu chưa có extension uuid-ossp v7)
→ ULID preferred nếu team dùng application-level generation

SINGLE-NODE MONOLITH (không expose ID ra ngoài):
→ BIGSERIAL (auto-increment): đơn giản, nhỏ hơn, index nhanh hơn
→ Vẫn dùng UUID nếu ID sẽ xuất hiện trong URL hoặc API response

COMPOSITE KEY:
→ Chỉ dùng cho junction tables (N-M relationships): (user_id, role_id)
→ Vẫn thêm surrogate PK nếu table sẽ được reference từ bảng khác

Document lý do chọn trong schema doc:
-- PK Strategy: UUID v4 — exposed in API, distributed-safe
-- PK Strategy: BIGSERIAL — internal only, single-node, performance priority
```

### Bước 5: Foreign keys và referential integrity

```
QUY TẮC:
□ Mọi FK PHẢI có index (tránh Seq Scan khi JOIN)
□ ON DELETE strategy rõ ràng:
   - RESTRICT: FK parent không được xóa nếu còn child (mặc định safe)
   - CASCADE: xóa parent → xóa child theo (dùng cho owned entities: order → order_items)
   - SET NULL: xóa parent → child.fk = NULL (dùng khi child vẫn tồn tại nhưng link bị mất)
□ ON UPDATE RESTRICT (mặc định — không cascade update PK)

CHECK CONSTRAINTS:
□ Giá trị phải dương: CHECK (price > 0)
□ Enum values: CHECK (status IN ('draft', 'active', 'archived'))
□ Business rules đơn giản: CHECK (end_date > start_date)

UNIQUE CONSTRAINTS:
□ Email unique trong users
□ Combination unique: (tenant_id, user_email) trong multi-tenant
□ Partial unique: UNIQUE (user_id) WHERE deleted_at IS NULL (chỉ unique bản ghi chưa xóa)
```

### Bước 6: Index design

```
READ: .claude/references/team-expert/engineering/database-patterns.md
→ Section 4 (Index Strategy Guide)
→ Section 7 (Advanced Query Optimization: covering indexes, partial indexes)

Quy trình thiết kế index:
1. Liệt kê các queries phổ biến (từ feature specs: list, search, filter, sort)
2. Với mỗi query: xác định columns trong WHERE + ORDER BY + JOIN
3. Thiết kế index phù hợp:

□ FK indexes: luôn luôn tạo cho mọi foreign key column
□ Search/filter: composite index (columns WHERE thường dùng cùng nhau)
□ Composite column order: cột có selectivity cao đặt TRƯỚC
□ Covering index (INCLUDE): khi query thường xuyên cần thêm columns ngoài WHERE
□ Partial index: khi chỉ query subset (WHERE deleted_at IS NULL, WHERE status = 'pending')
□ GIN index: cho JSONB fields hoặc full-text search
□ GiST index: cho geospatial data hoặc range types

Lý do cho mỗi index (document trong schema):
-- Index: (user_id, created_at DESC) — ORDER query lịch sử theo user, INCLUDE(status) để index-only scan
```

### Bước 7: Naming conventions

Áp dụng nhất quán từ Section 2 của database-patterns.md:

```
Tables:     snake_case, số nhiều        → users, order_items, product_categories
Columns:    snake_case                  → first_name, created_at, is_active
PK:         id                          → id UUID / id BIGSERIAL
FK:         [singular_table]_id         → user_id, order_id, product_id
Boolean:    is_ hoặc has_ prefix        → is_active, has_verified_email
Timestamp:  _at suffix                  → created_at, updated_at, deleted_at, published_at
Status:     rõ nghĩa, không viết tắt   → status (not sts), order_status
Indexes:    idx_[table]_[columns]       → idx_orders_user_id
Unique idx: uidx_[table]_[columns]      → uidx_users_email
Partial idx: idx_[table]_[cols]_[cond]  → idx_orders_status_pending
Constraints: pk_, fk_, chk_, uq_       → pk_users, fk_orders_users, chk_products_price_positive
```

### Bước 8: Soft delete strategy

```
Áp dụng soft delete cho mọi entity quan trọng (users, orders, products, etc.):

-- Cột chuẩn:
deleted_at  TIMESTAMPTZ DEFAULT NULL     -- NULL = chưa xóa
deleted_by  BIGINT REFERENCES users(id)  -- ai xóa (nếu cần audit)

-- Partial index đi kèm (bắt buộc):
CREATE INDEX idx_[table]_active ON [table] (email) WHERE deleted_at IS NULL;

-- WHY: partial index chỉ index bản ghi chưa xóa → nhỏ hơn full index ~90%
-- Queries thường xuyên filter deleted_at IS NULL nên index này luôn được dùng

NGOẠI LỆ không cần soft delete:
□ Lookup tables / reference data (countries, currencies) — immutable
□ Audit log tables — không bao giờ xóa
□ Time-series metrics — xóa theo retention policy bằng partitioning
```

### Bước 9: Audit columns

```
Mọi bảng quan trọng PHẢI có:

created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
created_by  BIGINT REFERENCES users(id)   -- FK đến users, nullable nếu có system operations
updated_by  BIGINT REFERENCES users(id)   -- FK đến users, nullable

Trigger tự động cập nhật updated_at (đừng rely vào application code):
-- Xem template trigger trong database-patterns.md Section 3b

Audit chi tiết hơn (lịch sử mọi thay đổi):
→ Tạo bảng [entity]_audit_logs riêng:
  id, entity_id, action (INSERT/UPDATE/DELETE), changed_fields (JSONB),
  old_values (JSONB), new_values (JSONB), changed_by, changed_at
→ Trigger AFTER INSERT/UPDATE/DELETE để ghi log
→ Áp dụng khi: financial transactions, sensitive data, compliance requirements
```

### Bước 10: Partitioning plan

```
Cần partitioning khi:
□ Bảng ước tính > 100M rows
□ Time-series data với retention policy
□ Analytics aggregation trên data lớn

READ: .claude/references/team-expert/engineering/database-patterns.md
→ Section 8 (Scaling Strategies: Partitioning)

Chọn partition type:
- RANGE by time (created_at theo tháng): orders, events, logs, audit_logs
- HASH by user_id: phân tán đều khi không có time pattern
- LIST by region/status: khi business phân nhóm rõ ràng

Ví dụ partition declaration:
CREATE TABLE orders (
    id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2026_01 PARTITION OF orders
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Ghi chú: partition key PHẢI có trong PRIMARY KEY khi dùng declarative partitioning
```

### Bước 11: ERD documentation

Sau khi hoàn thiện schema, vẽ ERD text-based trong output doc:

```
Format ASCII ERD:
┌─────────────┐         ┌─────────────┐
│   users     │─────1:N─│   orders    │
│─────────────│         │─────────────│
│ id (PK)     │         │ id (PK)     │
│ email       │         │ user_id(FK) │
│ created_at  │         │ total_amount│
└─────────────┘         └──────┬──────┘
                               │ 1:N
                        ┌──────┴──────┐
                        │ order_items │
                        │─────────────│
                        │ id (PK)     │
                        │ order_id(FK)│
                        │ product_id  │
                        └─────────────┘

Ghi chú:
- 1:1 → ─────1:1─────
- 1:N → ─────1:N─────
- N:M → ─────N:M───── (qua junction table)
```

### Bước 12: Output

```
GHI FILE 1: .mc-data/docs/phase3-architecture/database-schema.md
Cấu trúc:

# Database Schema: [System Name]
<!-- REQ-ID: [REQ-IDs covered] -->

## 1. Tổng quan
- Database: PostgreSQL [version]
- Ước tính data volume: [X rows / tháng]
- Primary key strategy: [UUID v7 / BIGSERIAL] — lý do

## 2. ERD (Entity Relationship Diagram)
[ASCII ERD]

## 3. Table Definitions
[Mỗi table: column definitions, constraints, indexes, lý do thiết kế]

## 4. Index Strategy
[Bảng tổng hợp tất cả indexes: table, index name, columns, type, mục đích]

## 5. Relationships
[Bảng FK relationships]

## 6. Soft Delete & Audit Strategy
[Áp dụng tables nào, exceptions nào]

## 7. Partitioning Plan
[Nếu có]

## 8. Migration Sequence
[Thứ tự tạo tables (dependencies trước)]

---

GHI FILE 2: .mc-data/docs/phase3-architecture/migrations/001_initial_schema.sql
Template:
-- Migration: 001_initial_schema
-- REQ-ID: [REQ-IDs]
-- Author: DBA
-- Date: [YYYY-MM-DD]
-- Description: Initial schema creation

BEGIN;

[CREATE TABLE statements — theo thứ tự dependency]
[CREATE INDEX CONCURRENTLY statements]
[CREATE TRIGGER statements]

COMMIT;

-- === ROLLBACK SCRIPT ===
-- DROP TABLE IF EXISTS [tables theo thứ tự ngược];
```

---

## Checklist trước khi submit

```
Schema Design:
□ Mọi entity đã được xác định từ feature specs
□ 3NF áp dụng — denormalization có lý do document
□ Primary key strategy nhất quán và có lý do
□ Mọi FK có index đi kèm
□ ON DELETE strategy rõ ràng cho từng FK
□ Check constraints cho business rules cơ bản
□ Soft delete trên mọi entity quan trọng
□ Audit columns (created_at, updated_at, created_by, updated_by) đủ
□ Naming conventions nhất quán (snake_case, plural tables)
□ ERD text-based dễ đọc

Indexes:
□ FK indexes: tất cả
□ Composite indexes cho queries phổ biến
□ Partial indexes khi có filtered queries
□ Covering indexes khi cần index-only scan
□ Không index columns thay đổi thường xuyên

Output:
□ REQ-ID references trong file header
□ Migration SQL có rollback script
□ Migration files đặt đúng naming convention: YYYYMMDDHHMMSS_description.sql
□ Lý do mọi quyết định thiết kế được ghi chú rõ ràng
```
