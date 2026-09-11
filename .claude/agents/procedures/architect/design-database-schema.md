# Playbook: Thiết kế Database Schema

> **Type**: Agent Skill Playbook
> **Agent**: architect
> **Triggered by**: /wf-design — Phase 3 khi cần thiết kế data model
> **Output**: `.mc-data/docs/phase3-architecture/database-schema.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` sau khi system architecture và service boundaries đã chốt
- Khi cần xác định entities, relationships, và indexing strategy
- Khi hệ thống có multi-tenancy và cần chọn isolation strategy
- Khi cần lên kế hoạch migration từ schema cũ sang schema mới

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (feature specs), PHASE3 (system architecture)

Cần xác định:
□ Danh sách tất cả entities từ feature specs và requirements
□ Database technology đã chọn (từ system-architecture.md ADR)
□ Multi-tenancy model (single-tenant / schema-per-tenant / row-level tenant_id)
□ Data volume estimates (số rows/tháng, tổng records dự kiến 2 năm)
□ Read/Write ratio (read-heavy → optimize indexes; write-heavy → minimize indexes)
□ Compliance requirements (GDPR → right to erasure; HIPAA → audit trail)
□ Service boundaries đã định nghĩa (để xác định schema ownership)
```

### Bước 2: Entity Identification

```
Từ feature specs và requirements, extract tất cả entities:

a) Đọc từng feature trong req-registry.json
   Với mỗi feature, trả lời:
   → Dữ liệu gì cần lưu trữ?
   → Ai là chủ thể (actor) trong use case này?
   → Có transaction nào cần lưu lịch sử?

b) Phân loại entities:
   - Core Entities (business objects chính): User, Product, Order, Invoice
   - Reference Data (lookup tables, ít thay đổi): Country, Currency, Category
   - Transaction Records (immutable log): OrderHistory, PaymentTransaction, AuditLog
   - Junction Tables (nhiều-nhiều): UserRole, ProductTag, OrderItem

c) Template entity catalogue:

| Entity | Loại | Module | Mô tả | Estimated Rows/Year |
|--------|------|--------|-------|---------------------|
| users | Core | auth | Tài khoản người dùng | 10,000 |
| orders | Core | sales | Đơn hàng | 500,000 |
| order_items | Junction | sales | Dòng sản phẩm trong đơn | 2,000,000 |
| audit_logs | Transaction | system | Nhật ký thao tác | 5,000,000 |
```

### Bước 3: Relationship Mapping

```
Với mỗi cặp entities, xác định relationship type:

ONE-TO-MANY (1:N) — thường gặp nhất:
  users → orders (1 user có nhiều orders)
  orders → order_items
  categories → products

MANY-TO-MANY (M:N) — cần junction table:
  users <→ roles (qua user_roles)
  products <→ tags (qua product_tags)
  users <→ permissions (qua user_permissions)

ONE-TO-ONE (1:1) — thường là extension table:
  users → user_profiles (tách PII riêng)
  orders → order_shipping_details

SELF-REFERENTIAL:
  categories → categories (parent_id, cho category tree)
  employees → employees (manager_id)
  comments → comments (parent_id, cho threaded comments)

Quy tắc:
□ Foreign key trỏ về primary key của bảng cha
□ Không để orphan records (enforce FK constraints hoặc soft-delete)
□ Junction table: đặt tên = bảng1_bảng2 (alphabetical)
```

### Bước 4: Normalization Decisions

```
Áp dụng normalization đến 3NF mặc định, có thể denormalize có chủ đích:

3NF Rules (bắt buộc áp dụng):
□ 1NF: Không có repeating groups, mỗi cell chứa 1 giá trị atomic
□ 2NF: Mọi non-key column phụ thuộc vào toàn bộ primary key
□ 3NF: Không có transitive dependency giữa non-key columns

Denormalization có chủ đích (chỉ khi có lý do rõ ràng):
□ Tránh JOIN phức tạp cho read-heavy queries
□ Cache computed values (total_amount trong orders thay vì tính lại từ items)
□ Snapshot data tại thời điểm transaction (price_at_purchase thay vì JOIN products)

Ghi rõ WHY khi denormalize:
→ "Lưu product_name và price_at_purchase trong order_items vì giá có thể thay đổi
   sau khi đặt hàng. JOIN products để lấy giá hiện tại sẽ trả về giá sai."
```

### Bước 5: Naming Conventions & Column Design

```
Conventions bắt buộc:

TABLE NAMES:
□ snake_case, số nhiều: users, orders, order_items
□ Prefix theo module (nếu shared DB): auth_users, sales_orders, inv_products
□ Junction tables: user_roles, product_categories (alphabetical order)

COLUMN NAMES:
□ snake_case: first_name, created_at, is_active
□ Primary key: id (UUID v7 hoặc BIGSERIAL — chọn 1 nhất quán)
□ Foreign key: {table_singular}_id (user_id, order_id, category_id)
□ Boolean: is_ prefix (is_active, is_deleted, is_verified)
□ Timestamps: created_at, updated_at, deleted_at (cho soft-delete)
□ Enum-like: status VARCHAR(50) với CHECK constraint, không INTEGER
□ Money: BIGINT (tiền nhỏ nhất) hoặc DECIMAL(19,4) — KHÔNG dùng FLOAT

DATA TYPES (PostgreSQL-based — điều chỉnh theo RDBMS được chọn):
□ ID: UUID (gen_random_uuid()) hoặc BIGINT (GENERATED ALWAYS AS IDENTITY)
□ Text short (<255): VARCHAR(n)
□ Text long (notes, description): TEXT
□ Timestamps: TIMESTAMPTZ (luôn lưu timezone)
□ JSON data: JSONB (indexed, not TEXT)
□ Array: PostgreSQL ARRAY hoặc junction table (prefer junction table)
□ Status: VARCHAR(50) + CHECK constraint

STANDARD COLUMNS (mọi bảng đều có):
  id          UUID/BIGINT    PRIMARY KEY
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
  updated_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()

SOFT-DELETE COLUMNS (nếu cần):
  deleted_at  TIMESTAMPTZ    NULL  (NULL = not deleted)
  deleted_by  UUID           NULL  (FK → users.id)
```

### Bước 6: Index Strategy

```
Index rules:

LUÔN index:
□ Primary key (tự động)
□ Foreign key columns (tránh sequential scan khi JOIN)
□ Columns thường xuyên dùng trong WHERE clause
□ Columns thường xuyên dùng trong ORDER BY

COMPOSITE INDEX (thứ tự quan trọng — column có selectivity cao đứng trước):
□ Equality first, then range: (tenant_id, status, created_at)
□ Match query pattern: nếu query WHERE tenant_id=? AND status=? → index (tenant_id, status)

PARTIAL INDEX (index có điều kiện — nhỏ hơn, nhanh hơn):
□ Chỉ index active records: CREATE INDEX ... WHERE deleted_at IS NULL
□ Chỉ index pending orders: CREATE INDEX ... WHERE status = 'PENDING'

FULL-TEXT SEARCH:
□ PostgreSQL: GIN index trên TSVECTOR column
□ Hoặc delegate sang Elasticsearch/OpenSearch cho search phức tạp

UNIQUE INDEX:
□ Natural keys: email trong users, sku trong products
□ Composite unique: (tenant_id, email) cho multi-tenant

KHÔNG index:
□ Columns có cardinality thấp (is_deleted boolean — chỉ 2 values)
□ Columns không dùng trong query predicates
□ Quá nhiều indexes trên bảng write-heavy (mỗi index làm chậm INSERT/UPDATE)

Template bảng index:
| Table | Index Name | Columns | Type | Lý do |
|-------|-----------|---------|------|-------|
| users | idx_users_email | email | UNIQUE | Login lookup |
| orders | idx_orders_user_status | (user_id, status) | COMPOSITE | Lọc orders của user theo status |
| orders | idx_orders_pending | status | PARTIAL (WHERE status='PENDING') | Xử lý queue pending |
```

### Bước 7: Multi-tenancy Strategy

```
Chọn isolation model dựa trên requirements:

| Model | Cơ chế | Data Isolation | Complexity | Phù hợp |
|-------|--------|---------------|-----------|---------|
| Shared Table (Row-level) | tenant_id column trong mọi bảng | Thấp (software) | Thấp | SaaS nhỏ, cost-sensitive |
| Schema per Tenant | Mỗi tenant 1 PostgreSQL schema | Trung bình | Trung bình | SaaS mid-size |
| Database per Tenant | Mỗi tenant 1 DB instance | Cao (hardware) | Cao | Enterprise, regulated industry |

Row-level tenancy (khi chọn Shared Table):
□ tenant_id UUID NOT NULL trong MỌI bảng có data của tenant
□ Row-Level Security (RLS) trong PostgreSQL: FORCE ROW LEVEL SECURITY
□ Composite indexes: (tenant_id, ...) đặt tenant_id đầu tiên
□ Application-level guard: inject tenant_id vào mọi query từ auth context

CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

→ Ghi ADR: "Chọn [model] vì [lý do: cost / compliance / isolation requirement]"
```

### Bước 8: Migration Plan

```
Nguyên tắc migration:
□ Mỗi migration là 1 file riêng, có timestamp: 20260319_001_create_users.sql
□ Migration phải idempotent khi có thể (IF NOT EXISTS, CREATE INDEX CONCURRENTLY)
□ Không có down migration cho production (chỉ có forward migrations)
□ Zero-downtime migration cho schema changes trên production

Zero-downtime migration patterns:
1. ADD COLUMN nullable trước, backfill data, sau đó thêm NOT NULL constraint
2. Rename column: thêm column mới, dual-write, migrate data, xóa column cũ
3. DROP TABLE: đánh dấu unused, verify không có query, drop sau 1 sprint

Migration sequence cho greenfield:
1. Platform tables (tenants, users, roles, permissions)
2. Core domain tables (theo dependency order — không có FK đến bảng chưa tạo)
3. Junction tables (sau khi cả 2 bảng tham chiếu đã tồn tại)
4. Indexes (CREATE INDEX CONCURRENTLY để không lock)
5. Seed data (reference data, default roles, admin users)
```

### Bước 9: Partition & Sharding Strategy (nếu cần)

```
Chỉ áp dụng khi có evidence của scale vấn đề (không premature optimize):

HORIZONTAL PARTITIONING (PostgreSQL native):
Phù hợp khi 1 bảng > 100M rows:

□ Range partitioning (theo thời gian — phổ biến nhất):
   PARTITION BY RANGE (created_at)
   Partitions: audit_logs_2026_q1, audit_logs_2026_q2...
   → Lợi ích: query theo date range chỉ scan partition liên quan

□ Hash partitioning (phân tán đều):
   PARTITION BY HASH (tenant_id)
   → Lợi ích: phân tán write load

□ List partitioning (theo enum):
   PARTITION BY LIST (status)
   → Lợi ích: archive completed records riêng

SHARDING (khi single DB không đủ):
→ Không implement sớm — bắt đầu với vertical scaling và read replicas
→ Chỉ sharding khi đã tối ưu hết indexes, queries, và caching
→ Ghi ADR: "Defer sharding đến khi đạt [metric cụ thể]"
```

### Bước 10: Vẽ ERD

```
Tạo ERD bằng Mermaid hoặc dbdiagram.io notation:

Mermaid ERD example:
```
erDiagram
    USERS ||--o{ ORDERS : places
    USERS {
        uuid id PK
        string email UK
        string full_name
        timestamptz created_at
    }
    ORDERS ||--|{ ORDER_ITEMS : contains
    ORDERS {
        uuid id PK
        uuid user_id FK
        string status
        bigint total_amount
        timestamptz created_at
    }
    ORDER_ITEMS {
        uuid id PK
        uuid order_id FK
        uuid product_id FK
        int quantity
        bigint price_at_purchase
    }
```

Hoặc dùng dbdiagram.io syntax (https://dbdiagram.io):
```
Table users {
  id uuid [pk, default: `gen_random_uuid()`]
  email varchar(255) [unique, not null]
  created_at timestamptz [not null, default: `now()`]
}

Table orders {
  id uuid [pk]
  user_id uuid [ref: > users.id, not null]
  status varchar(50) [not null]
}
```

→ Nhúng diagram vào output document
→ Lưu source code diagram cùng file để có thể chỉnh sửa
```

### Bước 11: Viết Output

```
Ghi vào: .mc-data/docs/phase3-architecture/database-schema.md

Cấu trúc output:

# Database Schema — [Tên dự án]

## 1. Database Technology
[Technology được chọn + version + lý do + link ADR]

## 2. Multi-tenancy Strategy
[Model được chọn + implementation approach + link ADR]

## 3. Naming Conventions
[Quick reference conventions đã chốt]

## 4. Entity Catalogue
[Bảng tất cả entities với loại, module, estimated rows]

## 5. Entity Relationship Diagram
[Mermaid ERD]

## 6. Table Definitions
[Với mỗi table: DDL CREATE TABLE, columns, constraints, data types]

## 7. Index Strategy
[Bảng indexes với lý do cho từng index]

## 8. Partitioning Strategy (nếu có)
[Tables nào được partition, theo tiêu chí gì]

## 9. Migration Plan
[File migration plan, thứ tự tạo tables, seed data]

## 10. Data Lifecycle & Retention
[Soft-delete vs hard-delete policy, archive strategy, GDPR compliance]

## 11. Open Items
[Quyết định chưa chốt, cần confirm với DBA hoặc stakeholders]
```

---

## Checklist trước khi submit

```
□ Mọi entity trong feature specs đều có table definition
□ Naming conventions nhất quán (snake_case, prefix, FK naming)
□ Mọi FK đều có corresponding index
□ Primary key strategy nhất quán (UUID hoặc BIGINT — chọn 1)
□ Timestamps created_at/updated_at trong mọi bảng
□ Money stored as BIGINT (không dùng FLOAT)
□ Multi-tenancy: tenant_id có trong mọi bảng có data của tenant
□ ADR tồn tại cho: database technology, multi-tenancy model, ID strategy
□ ERD diagram được vẽ và nhúng vào document
□ Migration plan có thứ tự tạo tables (dependencies first)
□ Không có circular FK dependencies
□ Indexes được justify (có lý do cho mỗi index, không index blind)
□ Cần coordinate với DBA agent cho complex query optimization
```
