# Database Patterns - Thiết kế và Best Practices

> **Domain**: Engineering / Database
> **Last Updated**: 2026-03-15
> **Nguồn**: PostgreSQL docs, MongoDB best practices, Martin Fowler — Patterns of Enterprise Application Architecture

---

## 1. Database Selection Matrix

Chọn database phù hợp với use case:

| Database | Type | Phù hợp nhất | Tránh dùng khi |
|----------|------|-------------|----------------|
| PostgreSQL | Relational (OLTP) | Transactional data, complex queries, JSON support | Cần schema-free hoàn toàn |
| MySQL | Relational (OLTP) | Web apps, read-heavy workloads | Complex analytics, JSON-heavy |
| MongoDB | Document Store | Schema linh hoạt, nested documents, rapid iteration | Cần ACID transactions toàn cục |
| Redis | In-memory KV | Cache, session, rate limiting, pub/sub | Primary data store (volatile) |
| Elasticsearch | Search Engine | Full-text search, log analytics, faceted search | Primary transactional store |
| ClickHouse | Columnar (OLAP) | Analytics, aggregations trên hàng tỷ rows | OLTP, frequent updates |
| TimescaleDB | Time-series | IoT, metrics, monitoring data | Non-time-series workloads |

### Decision Guide

```
Cần ACID + relational queries?
    └─ YES → PostgreSQL (ưu tiên) hoặc MySQL

Cần schema linh hoạt + document store?
    └─ YES → MongoDB

Cần cache / session store < 1ms latency?
    └─ YES → Redis

Cần full-text search + faceted navigation?
    └─ YES → Elasticsearch

Cần analytics aggregation trên dữ liệu lớn?
    └─ YES → ClickHouse hoặc BigQuery
```

---

## 2. Naming Conventions

### Tables và Columns

| Element | Convention | Ví dụ |
|---------|-----------|-------|
| Table names | snake_case, số nhiều | `user_accounts`, `order_items` |
| Column names | snake_case | `created_at`, `first_name` |
| Primary key | `id` (bigserial hoặc uuid) | `id BIGSERIAL PRIMARY KEY` |
| Foreign key | `[table_singular]_id` | `user_id`, `order_id` |
| Boolean columns | `is_` hoặc `has_` prefix | `is_active`, `has_verified_email` |
| Timestamp columns | `_at` suffix | `created_at`, `deleted_at` |
| Enum columns | Rõ nghĩa, không viết tắt | `status` (not `sts`) |

### Indexes

| Element | Convention | Ví dụ |
|---------|-----------|-------|
| Index | `idx_[table]_[columns]` | `idx_orders_user_id` |
| Unique index | `uidx_[table]_[columns]` | `uidx_users_email` |
| Partial index | `idx_[table]_[columns]_[condition]` | `idx_orders_status_pending` |

### Constraints và Migrations

| Element | Convention | Ví dụ |
|---------|-----------|-------|
| Primary key | `pk_[table]` | `pk_users` |
| Foreign key | `fk_[table]_[ref_table]` | `fk_orders_users` |
| Check constraint | `chk_[table]_[description]` | `chk_products_price_positive` |
| Migration files | `YYYYMMDDHHMMSS_[description].sql` | `20260315120000_add_user_phone.sql` |

---

## 3. Common Schema Patterns

### 3a. Soft Delete

Xóa logic thay vì physical delete — giữ lại dữ liệu cho audit, recovery.

```sql
-- Thêm cột deleted_at
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Partial index: chỉ index bản ghi chưa xóa (hiệu quả hơn full index)
CREATE INDEX idx_users_active ON users (email) WHERE deleted_at IS NULL;

-- Query mặc định: luôn filter bản ghi chưa xóa
SELECT * FROM users WHERE deleted_at IS NULL AND id = $1;

-- Soft delete
UPDATE users SET deleted_at = NOW() WHERE id = $1;
```

**Lưu ý:** Dùng Row Level Security hoặc view để tự động filter, tránh quên WHERE deleted_at IS NULL.

### 3b. Audit Trail

Theo dõi ai thay đổi gì, khi nào.

```sql
-- Cột chuẩn cho mọi bảng cần audit
created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by   BIGINT REFERENCES users(id),
updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by   BIGINT REFERENCES users(id),

-- Trigger tự động cập nhật updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

Với yêu cầu audit chi tiết hơn, dùng bảng `[table]_audit_log` riêng biệt lưu toàn bộ lịch sử thay đổi.

### 3c. Multi-tenancy

| Chiến lược | Mô tả | Pros | Cons |
|-----------|-------|------|------|
| Schema-based | Mỗi tenant một PostgreSQL schema | Isolation tốt, dễ backup per-tenant | Nhiều schemas khó quản lý khi > 1000 tenants |
| Row-based | Cột `tenant_id` trong mọi bảng | Đơn giản, dễ scale | Rò rỉ dữ liệu nếu quên WHERE tenant_id |
| Database-based | Mỗi tenant một database riêng | Isolation hoàn toàn | Chi phí cao, nhiều connections |

**Khuyến nghị:** Row-based với Row Level Security (RLS) của PostgreSQL là cân bằng tốt nhất cho hầu hết trường hợp.

```sql
-- RLS policy tự động filter theo tenant
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::BIGINT);
```

### 3d. Hierarchical Data

| Pattern | Phù hợp | Query | Insert | Cấu trúc |
|---------|---------|-------|--------|----------|
| Adjacency List | Cây đơn giản, depth nhỏ | Recursive CTE | O(1) | `parent_id` column |
| Materialized Path | Read-heavy, depth lớn | LIKE query | O(1) | `path = '/1/5/12/'` |
| Nested Set | Analytics trên cây | O(1) range query | O(n) rebuild | `lft`, `rgt` columns |

```sql
-- Adjacency List với Recursive CTE (PostgreSQL)
WITH RECURSIVE category_tree AS (
  SELECT id, name, parent_id, 0 AS depth
  FROM categories WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.name, c.parent_id, ct.depth + 1
  FROM categories c JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree ORDER BY depth, name;
```

---

## 4. Index Strategy Guide

| Index Type | Dùng khi | Ví dụ |
|-----------|---------|-------|
| B-tree (mặc định) | Equality, range queries, ORDER BY | `WHERE status = 'active'` |
| Hash | Chỉ equality lookups (hiếm dùng) | `WHERE session_token = $1` |
| GIN | JSON fields, arrays, full-text search | `WHERE tags @> '{golang}'` |
| GiST | Geospatial, range types, full-text | `WHERE location && $bbox` |
| Partial | Chỉ index subset rows | `WHERE deleted_at IS NULL` |
| Composite | Multi-column queries thường xuyên | `(tenant_id, created_at DESC)` |

**Quy tắc index:**
- Index foreign keys (tránh full table scan khi JOIN)
- Composite index: cột có selectivity cao đặt trước
- Không index columns thay đổi thường xuyên (write amplification)
- Monitor index usage: xóa unused indexes

---

## 5. Migration Best Practices

### Zero-Downtime Migration Checklist

```
Giai đoạn 1: Backward-compatible changes (deploy bất kỳ lúc nào)
  - [ ] Thêm cột mới với DEFAULT hoặc nullable
  - [ ] Thêm bảng mới
  - [ ] Thêm index CONCURRENTLY (PostgreSQL)

Giai đoạn 2: Application code thay đổi
  - [ ] Code mới đọc cả cột cũ và mới
  - [ ] Backfill data cho cột mới

Giai đoạn 3: Cleanup (sau khi code mới ổn định)
  - [ ] Drop cột cũ
  - [ ] Drop constraints cũ
```

```sql
-- KHÔNG block table khi tạo index (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- Thêm cột an toàn (nullable trước, rồi set DEFAULT)
ALTER TABLE orders ADD COLUMN discount_pct NUMERIC(5,2);
UPDATE orders SET discount_pct = 0 WHERE discount_pct IS NULL;
ALTER TABLE orders ALTER COLUMN discount_pct SET DEFAULT 0;
ALTER TABLE orders ALTER COLUMN discount_pct SET NOT NULL;
```

---

## 6. Query Optimization Checklist

Trước khi deploy query chậm vào production:

- [ ] Chạy `EXPLAIN (ANALYZE, BUFFERS)` — xem Seq Scan có thể tránh không
- [ ] Kiểm tra N+1: ORM có lazy-load trong loop không?
- [ ] Dùng `SELECT` chỉ các cột cần thiết, không `SELECT *`
- [ ] Pagination: cursor-based thay vì `OFFSET` lớn
- [ ] Batch operations: INSERT/UPDATE nhiều rows một lần
- [ ] Connection pooling: PgBouncer hoặc application-level pool
- [ ] Kiểm tra slow query log (queries > 100ms)

```sql
-- Phát hiện slow queries trong PostgreSQL
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

**Connection Pool Settings (PgBouncer):**

| Pool Mode | Phù hợp | pool_size |
|-----------|---------|-----------|
| Transaction | API servers (stateless) | DB_MAX_CONNECTIONS * 0.8 |
| Session | Applications dùng advisory locks | Nhỏ hơn, theo sessions |

---

## 7. Advanced Query Optimization

### Covering Indexes (INCLUDE Clause)

```sql
-- Không có INCLUDE: phải đọc index + heap cho mỗi row
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Có INCLUDE: tất cả cột cần thiết nằm trong index (Index Only Scan)
CREATE INDEX idx_orders_user_date_covering
  ON orders (user_id, created_at)
  INCLUDE (id, total_amount, status, customer_email);

-- Query: Index Only Scan — không chạm heap
EXPLAIN ANALYZE
SELECT user_id, created_at, total_amount, status FROM orders WHERE user_id = $1;
```

### Window Functions thay Self-Join

```sql
-- BAD: self-join để lấy previous order
SELECT o1.id, o1.total_amount, o2.total_amount AS prev_amount
FROM orders o1
LEFT JOIN orders o2 ON o2.user_id = o1.user_id
    AND o2.created_at = (
        SELECT MAX(created_at) FROM orders
        WHERE user_id = o1.user_id AND created_at < o1.created_at
    );

-- GOOD: window function
SELECT
    id,
    total_amount,
    LAG(total_amount) OVER (PARTITION BY user_id ORDER BY created_at) AS prev_amount
FROM orders;
```

### Partial Indexes Nâng cao

```sql
-- Chỉ index active, pending records — ~10% kích thước full index
CREATE INDEX idx_orders_active_pending
  ON orders (created_at DESC)
  WHERE deleted_at IS NULL AND status = 'pending';

-- Chỉ index chưa xử lý — nhanh hơn 5-10x cho queries phổ biến
CREATE INDEX idx_invoices_unpaid
  ON invoices (due_date)
  WHERE paid_at IS NULL;
```

---

## 8. Scaling Strategies

### Read Replicas

- Đưa read queries (reports, analytics) sang replica để giảm tải primary
- Chú ý replication lag — không dùng replica cho data cần strong consistency

### Connection Pooling với PgBouncer

```
# PgBouncer transaction mode — tối ưu cho serverless/short-lived connections
[databases]
app_db = host=db.example.com port=5432 dbname=production

[pgbouncer]
pool_mode = transaction          # Mỗi transaction mượn 1 connection, trả ngay sau đó
max_client_conn = 1000           # Max connections từ app
default_pool_size = 25           # Actual DB connections
reserve_pool_size = 5            # Extra connections cho traffic spikes
```

**Nguyên tắc pool size**: `(CPU cores * 2) + disk count`

### Partitioning

| Loại | Khi dùng | Ví dụ |
|------|----------|-------|
| Range | Data có thứ tự thời gian | `orders` partition by `created_at` theo tháng |
| Hash | Phân tán đều, không có pattern rõ ràng | `events` partition by `hash(user_id)` |
| List | Phân nhóm theo giá trị cụ thể | `orders` partition by `region` (VN, SG, TH) |

### Sharding Considerations

- Chỉ cân nhắc khi single node đã max out vertical scaling
- Chọn shard key cẩn thận — tránh hot spots, đảm bảo queries thường xuyên không cần cross-shard joins
- Ưu tiên application-level sharding trước database-native sharding

### Caching Layers

```
Request → Redis Cache (TTL-based)
             ↓ cache miss
          PostgreSQL (source of truth)
             ↓ write-through hoặc cache invalidation
          Redis Cache (update)
```

- Cache hot data: user sessions, product catalog, configuration
- Không cache: financial transactions, real-time inventory
- Cache invalidation strategy: TTL + event-driven invalidation

---

## 9. Performance Guidelines & Success Metrics

| Chỉ số | Mục tiêu | Ghi chú |
|--------|----------|---------|
| Query P95 latency | < 100ms | Cho các critical paths (checkout, login, dashboard) |
| Index hit ratio | > 99% | Đo qua `pg_stat_user_indexes` |
| Data integrity violations | 0 | Zero tolerance — constraint failures, orphaned records |
| Migration downtime | < 30 giây | Dùng online migration tools khi cần |
| Backup recovery time | < 15 phút | RTO cho môi trường production |
| Connection pool utilization | < 80% | Để lại buffer cho spike traffic |

### EXPLAIN ANALYZE là Bắt buộc

**Mọi SQL query cần chạy qua `EXPLAIN ANALYZE` trước khi deploy production.**

- Tìm: Seq Scan (cảnh báo trên bảng lớn), Index Scan (tốt), Bitmap Heap Scan (chấp nhận được)
- So sánh: planned time vs actual time; estimated rows vs actual rows (chênh lệch lớn = statistics cũ)
- Nếu Seq Scan trên bảng > 1M rows → cần thêm index

---

## 10. Database Design Output Template

> Chi tiết template: Xem doc-framework hoặc procedure files của DBA agent.
> Bao gồm: ERD, Tables, Indexes, Relationships, Migration Plan.
