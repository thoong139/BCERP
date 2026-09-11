# Playbook: Tối ưu Query Performance

> **Type**: Agent Skill Playbook
> **Agent**: dba
> **Triggered by**: Khi phát hiện performance issues, N+1 queries, slow query logs, hoặc được developer/architect yêu cầu
> **Output**: Optimization report + improved queries tại `.mc-data/docs/phase3-architecture/query-optimization-report.md`

---

## Khi nào dùng playbook này

- Developer báo cáo query chậm hoặc timeout
- Code reviewer phát hiện N+1 pattern trong ORM
- Performance benchmark thấp hơn target (P95 > 100ms cho critical paths)
- Trước khi deploy tính năng mới có heavy database operations
- Sau khi bảng đạt ngưỡng tăng trưởng (10M+ rows)

---

## Procedure

### Bước 1: Thu thập slow queries

Trước khi optimize bất kỳ thứ gì — thu thập data thực tế:

```sql
-- PostgreSQL: tìm queries chậm nhất (cần pg_stat_statements extension)
SELECT query, calls, mean_exec_time, max_exec_time, total_exec_time, rows
FROM pg_stat_statements
WHERE mean_exec_time > 100 ORDER BY mean_exec_time DESC LIMIT 20;
-- MySQL: dùng Performance Schema events_statements_summary_by_digest
```

```
Nếu không có access production DB:
□ Yêu cầu developer cung cấp slow query log
□ Xem application APM (New Relic, Datadog) hoặc ORM query log
□ Tái hiện trên staging với production-scale data sample
```

### Bước 2: Phân tích EXPLAIN ANALYZE

Với mỗi slow query — chạy EXPLAIN ANALYZE:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;
```

Đọc EXPLAIN output — tìm dấu hiệu:
```
NGUY HIỂM: Seq Scan bảng >100K rows, estimated ≠ actual rows, Sort không index
TỐT: Index Scan, Bitmap Index Scan, cost khớp estimate
```

Ghi baseline: Query text, Execution time (avg/max), Rows scanned, Plan type, Buffer hits/reads

### Bước 3: Xác định loại vấn đề và giải pháp

```
READ: .claude/references/team-expert/engineering/database-patterns.md
→ Section 4 (Index Strategy Guide)
→ Section 6 (Query Optimization Checklist)
→ Section 7 (Advanced Query Optimization)
```

**Phân loại vấn đề:**

```
VẤN ĐỀ 1: MISSING INDEX
Dấu hiệu: Seq Scan trên bảng lớn
Giải pháp:
□ B-tree index cho equality/range WHERE columns
□ Composite index nếu filter nhiều columns cùng lúc
□ Partial index nếu chỉ query subset (WHERE status = 'active')
□ Covering index (INCLUDE) nếu cần thêm columns trong SELECT

VẤN ĐỀ 2: N+1 QUERY
Dấu hiệu: Nhiều queries nhỏ chạy tuần tự trong loop, ORM lazy-load
Giải pháp:
□ Eager loading trong ORM: .include() / .with() / .prefetch_related()
□ JOIN thay vì nhiều queries riêng lẻ
□ DataLoader pattern (GraphQL) — batch queries
□ Batch SELECT: WHERE id IN (id1, id2, ...) thay vì SELECT FROM WHERE id = ?

VẤN ĐỀ 3: INEFFICIENT QUERY STRUCTURE
Dấu hiệu: Subquery chạy cho mỗi row outer, correlated subquery
Giải pháp:
□ JOIN thay vì subquery WHERE IN (SELECT ...)
□ CTE thay vì nested subqueries (readability + sometimes performance)
□ Window function thay vì self-join để lấy ranking/previous row
□ EXISTS thay vì IN khi subquery trả về nhiều rows

VẤN ĐỀ 4: OFFSET PAGINATION
Dấu hiệu: OFFSET lớn chậm dần khi offset tăng
Giải pháp:
□ Cursor-based pagination: WHERE id > last_id ORDER BY id LIMIT N
□ Keyset pagination: WHERE (created_at, id) > ($cursor_ts, $cursor_id)

VẤN ĐỀ 5: SELECT *
Dấu hiệu: Nhiều columns không cần thiết được fetch
Giải pháp:
□ SELECT chỉ columns cần thiết
□ Covering index INCLUDE để index-only scan khi cần
□ Tránh fetch BLOB/TEXT lớn khi chỉ cần metadata

VẤN ĐỀ 6: STALE STATISTICS
Dấu hiệu: Estimated rows << actual rows trong EXPLAIN ANALYZE
Giải pháp:
□ ANALYZE [table]; — cập nhật statistics thủ công
□ Tăng autovacuum frequency cho bảng thay đổi nhiều
□ Tăng default_statistics_target cho columns phức tạp
```

### Bước 4: Viết lại queries

Với từng vấn đề — viết query mới theo pattern phù hợp:
- N+1 → JOIN (eager loading)
- Correlated subquery → Window function (10-100x nhanh hơn)
- OFFSET pagination → Cursor-based: `WHERE (created_at, id) < ($cursor_ts, $cursor_id)`
- SELECT * → SELECT chỉ columns cần thiết

### Bước 5: Thiết kế indexes bổ sung

```sql
-- Luôn dùng CREATE INDEX CONCURRENTLY trên production (không lock table)
CREATE INDEX CONCURRENTLY idx_orders_user_created
    ON orders (user_id, created_at DESC)
    INCLUDE (id, total_amount, status)
    WHERE deleted_at IS NULL;
-- WHY: Composite (user_id, created_at) cho filter + sort;
--      INCLUDE(id, total_amount, status) để index-only scan;
--      Partial (deleted_at IS NULL) giảm kích thước index ~90%

-- MySQL: không có INCLUDE, không có partial index — dùng composite index
CREATE INDEX idx_orders_user_created ON orders (user_id, created_at, id, total_amount, status);
```

Ghi document với mỗi index mới:
```
Index: idx_orders_user_created
Table: orders
Columns: user_id, created_at DESC (+ INCLUDE: id, total_amount, status)
Condition: WHERE deleted_at IS NULL
Size estimate: ~X MB
Queries hưởng lợi: [list queries]
WHY: [lý do cụ thể]
```

### Bước 6: N+1 detection và batch solutions

```
PHÁT HIỆN N+1:
□ Bật ORM query logging, đếm queries/request: N+1 khi = N items + 1
□ Tools: APM (New Relic, Datadog), Django Debug Toolbar, Bullet gem (Rails)

GIẢI QUYẾT: Eager loading trong ORM
□ Sequelize: findAll({ include: [{ model: User }] })
□ Django: select_related('user') (JOIN) / prefetch_related('items') (IN query)
□ TypeORM: leftJoinAndSelect thay vì lazy-load
□ GraphQL: DataLoader pattern (batch SELECT WHERE id IN (...))
```

### Bước 7: Connection pooling và caching review

```
POOL: pool_size = (CPU cores * 2) + effective_disk_spindles
Dấu hiệu vấn đề: "too many connections", connection timeout, idle connections quá nhiều

CACHE CANDIDATES (Redis, TTL-based):
□ Chỉ cache khi: data ít đổi (<1/phút) + query nhiều (>10/giây) + cost cao
□ Patterns: Cache-aside, Write-through, Materialized View (PostgreSQL)
□ KHÔNG cache: financial transactions, real-time inventory, user permissions
```

### Bước 8: Partitioning review

```
□ Bảng >100M rows → cân nhắc range partition by time
□ Verify partition pruning: EXPLAIN phải có "Partitions selected: [specific]"
□ Xem database-patterns.md Section 8 cho guidance
```

### Bước 9: Đo lường sau optimization

Chạy lại `EXPLAIN (ANALYZE, BUFFERS)` + pg_stat_statements sau 24h monitoring.

Ghi kết quả: Query, BEFORE (avg/max/plan), AFTER (avg/max/plan), Improvement %, Index added

### Bước 10: Output

```
GHI FILE: .mc-data/docs/phase3-architecture/query-optimization-report.md

Cấu trúc: Tóm tắt → Slow Queries → Phân tích/Giải pháp per issue (Before/After) → Indexes Đã Thêm (table) → Caching Recommendations → Technical Debt → Monitoring Setup
```

---

## Checklist trước khi submit

```
Thu thập:
□ Slow queries từ pg_stat_statements hoặc slow query log
□ EXPLAIN ANALYZE output cho mỗi slow query
□ Baseline metrics (avg ms, max ms, calls/sec)

Phân tích:
□ Xác định đúng loại vấn đề (missing index, N+1, bad structure, etc.)
□ Không tối ưu dựa trên cảm giác — phải có data từ EXPLAIN

Implement:
□ Indexes dùng CONCURRENTLY trên production (không lock)
□ Query rewrite không thay đổi business logic
□ ORM eager loading thêm vào đúng chỗ
□ Cache chỉ cho data phù hợp (tránh consistency issues)

Đo lường:
□ EXPLAIN ANALYZE sau optimization → improvement được confirm
□ Kết quả before/after ghi rõ số liệu cụ thể
□ Không có regression (other queries không chậm hơn)

Output:
□ REQ-ID references trong report header
□ Mọi index mới có lý do document
□ Technical debt còn lại được note rõ
□ Monitoring recommendations cho ongoing health
```
