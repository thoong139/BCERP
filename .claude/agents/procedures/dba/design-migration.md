# Playbook: Thiết kế Database Migration Strategy

> **Type**: Agent Skill Playbook
> **Agent**: dba
> **Triggered by**: Khi cần thay đổi schema trên production database (thêm/sửa/xóa bảng/cột, data migration, restructuring)
> **Output**: Migration plan + migration scripts tại `.mc-data/docs/phase3-architecture/migration-plan.md` + `.mc-data/docs/phase3-architecture/migrations/`

---

## Khi nào dùng playbook này

- Thêm feature mới cần schema changes
- Refactoring data model (rename, restructure, split/merge tables)
- Data migration (backfill, transform existing data)
- Upgrade schema để hỗ trợ multi-tenancy, partitioning, hay audit trail
- Khi devops hoặc architect yêu cầu migration plan trước khi deploy

---

## Procedure

### Bước 1: Current state assessment

Trước khi thiết kế bất kỳ migration nào — hiểu rõ trạng thái hiện tại:

```
THU THẬP THÔNG TIN:
□ Schema hiện tại: đọc migration files đã tồn tại hoặc schema dump
□ Data volume: ước tính số rows trong mỗi bảng sẽ bị ảnh hưởng
□ Dependencies: bảng nào FK đến bảng cần thay đổi?
□ Indexes hiện tại: cần drop/recreate không?
□ Triggers và views: có bị ảnh hưởng không?
□ Application code: ORM models, raw queries nào reference schema cũ?
□ Retention policies: có jobs xóa/archive data không?

PHÂN LOẠI DATA VOLUME:
< 1M rows:   Migration đơn giản, downtime chấp nhận được nếu có maintenance window
1M - 10M:   Cần batch operations, không dùng ALTER TABLE thêm NOT NULL trực tiếp
10M - 100M: Zero-downtime là bắt buộc, expand-contract pattern
> 100M:     Cần online migration tools (pg_repack, gh-ost), plan kỹ từng bước

PostgreSQL — xem schema hiện tại:
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = '[table_name]'
ORDER BY ordinal_position;

-- Size estimate:
SELECT relname AS table, pg_size_pretty(pg_total_relation_size(oid)) AS size
FROM pg_class WHERE relkind = 'r' ORDER BY pg_total_relation_size(oid) DESC LIMIT 20;
```

### Bước 2: Phân loại migration type

```
XÁC ĐỊNH LOẠI MIGRATION:

TYPE A — Schema change only (không có data migration):
  Ví dụ: thêm cột mới nullable, thêm bảng mới, thêm index
  Risk: Thấp
  Strategy: Backward-compatible changes

TYPE B — Data migration only (không thay đổi schema):
  Ví dụ: backfill giá trị mới, normalize data hiện có
  Risk: Trung bình (data integrity, performance impact)
  Strategy: Batch processing với progress tracking

TYPE C — Schema + Data migration (cả hai):
  Ví dụ: rename column (thêm cột mới → backfill → xóa cột cũ)
  Risk: Cao
  Strategy: Expand-Contract (3 phases, multi-deployment)

TYPE D — Destructive migration (drop table, drop column, NOT NULL trên cột có NULLs):
  Risk: Rất cao
  Strategy: Confirm rollback plan rõ ràng, test trên staging trước
```

### Bước 3: Zero-downtime strategies

```
READ: .claude/references/team-expert/engineering/database-patterns.md
→ Section 5 (Migration Best Practices: Zero-Downtime Migration Checklist)
```

**Expand-Contract Pattern (cho TYPE C migrations):**

```
PHASE 1 — EXPAND (Backward-compatible additions):
Mục tiêu: Thêm structures mới mà không break code cũ
Actions:
  □ Thêm cột/bảng mới (nullable)
  □ Code mới đọc cả cột cũ VÀ cột mới (dual-read)
  □ Code mới write vào CẢ HAI cột (dual-write)
  □ Deploy code này TRƯỚC khi backfill data
  → Không cần downtime

PHASE 2 — MIGRATE (Backfill data):
Mục tiêu: Đồng bộ data từ cấu trúc cũ sang mới
Actions:
  □ Batch backfill data vào cột/bảng mới
  □ Verify data integrity sau mỗi batch
  □ Monitor replication lag (nếu có read replicas)
  □ Code vẫn dùng dual-read/dual-write
  → Không cần downtime, chạy background

PHASE 3 — CONTRACT (Remove old structures):
Mục tiêu: Dọn dẹp cấu trúc cũ sau khi code đã migrate hoàn toàn
Pre-conditions:
  □ Tất cả code đã dùng cấu trúc mới
  □ Không còn code nào đọc/ghi cấu trúc cũ
  □ Data integrity verified
Actions:
  □ Remove dual-read/dual-write code
  □ DROP COLUMN / DROP TABLE cũ
  □ DROP INDEX cũ (nếu có)
  → Deploy code mới TRƯỚC, rồi mới chạy DROP
```

Ví dụ: Rename `users.name` → `users.full_name`:
Phase 1: ADD COLUMN full_name, dual-write code
Phase 2: Batch UPDATE SET full_name=name (10K/batch, throttle), verify COUNT=0
Phase 3: Deploy code chỉ dùng full_name, DROP COLUMN name

### Bước 4: Rollback plan

Mỗi migration PHẢI có rollback script trước khi viết migration script:

```
NGUYÊN TẮC ROLLBACK:
□ Viết rollback TRƯỚC khi viết migration — đảm bảo thực sự reversible
□ Test rollback trên staging TRƯỚC khi deploy production
□ Không phải mọi migration đều rollbackable — phải ghi rõ

ROLLBACK BY TYPE:

TYPE A (schema only):
□ DROP TABLE nếu migration là CREATE TABLE
□ DROP COLUMN nếu migration là ADD COLUMN
□ DROP INDEX nếu migration là CREATE INDEX
→ Thường simple và safe

TYPE B (data migration):
□ Backup table trước: CREATE TABLE users_backup_20260319 AS SELECT * FROM users;
□ Rollback: TRUNCATE users; INSERT INTO users SELECT * FROM users_backup_20260319;
→ Cần backup TRƯỚC khi chạy migration

TYPE C (expand-contract):
□ Phase 1 rollback: DROP COLUMN new_col (dễ, chưa có data)
□ Phase 2 rollback: Xóa data đã backfill, reset sang dual-read từ cột cũ
□ Phase 3 rollback: KHÔNG thể rollback nếu đã DROP cột cũ
  → Cần backup hoặc phải ADD COLUMN mới và backfill lại từ đầu
  → Document rõ: "Phase 3 là IRREVERSIBLE — chỉ chạy khi hoàn toàn confident"

KHÔNG ROLLBACKABLE (phải document):
□ DROP TABLE với data quan trọng (cần backup trước)
□ Hash/encrypt data in-place
□ Merge 2 bảng thành 1
```

### Bước 5: Data validation scripts

```
PRE-MIGRATION: Count rows affected, sample data (RANDOM() LIMIT 100), check constraint violations
POST-MIGRATION: Verify count, compare with sample, check orphaned records (FK integrity),
verify constraints, EXPLAIN ANALYZE performance check
```

### Bước 6: Migration sequence planning

```
ĐẶT THỨ TỰ CHO MIGRATIONS (resolve dependencies):

Nguyên tắc:
□ Parent tables TRƯỚC child tables (FK dependencies)
□ Base tables TRƯỚC bảng phụ thuộc
□ Thêm cột TRƯỚC khi thêm constraint NOT NULL
□ Backfill TRƯỚC khi SET NOT NULL
□ CREATE INDEX sau khi bulk insert (nhanh hơn index-then-insert)

Ví dụ sequence:
1. CREATE TABLE users (không FK)
2. CREATE TABLE products (không FK)
3. CREATE TABLE orders (FK → users)
4. CREATE TABLE order_items (FK → orders, products)
5. CREATE INDEX CONCURRENTLY ... (sau khi data đã có)
6. Backfill data (batch)
7. ALTER TABLE ... SET NOT NULL (sau khi backfill xong)

DEPENDENCY GRAPH:
Vẽ ra trước:
  users ←── orders ←── order_items
  products ←──────────────┘

Migration order: users → products → orders → order_items
```

### Bước 7: Performance impact estimate

```
ƯỚC TÍNH THỜI GIAN VÀ IMPACT:

PostgreSQL — thời gian approximate:
□ ADD COLUMN NULL: gần như instant (metadata only)
□ ADD COLUMN NOT NULL DEFAULT: instant trên PG12+ (stored value)
□ ADD COLUMN NOT NULL (no default): instant nếu có DEFAULT, lâu nếu không
□ UPDATE N rows: ~N/10000 giây (10K rows/sec, ước rough với SSD)
□ CREATE INDEX CONCURRENTLY: ~N/5000 giây (5K rows/sec index build)
□ DROP COLUMN: instant (PG chỉ mark, không free space ngay)
□ VACUUM FULL: ~N/1000 giây (1K rows/sec) — avoid on production

MySQL:
□ ADD COLUMN: rewrite table nếu không dùng instant algorithm
□ Dùng: ALTER TABLE ... ALGORITHM=INSTANT (MySQL 8+ supported operations)
□ Không instant → dùng gh-ost hoặc pt-online-schema-change

IMPACT ESTIMATE TEMPLATE:
| Operation | Table | Rows | Estimate Time | Lock Type | Notes |
|-----------|-------|------|---------------|-----------|-------|
| ADD COLUMN full_name | users | 5M | < 1s | Metadata only | PG13+ |
| UPDATE backfill (batch) | users | 5M | ~8-10 phút | Row-level | 10K/batch, 0.1s sleep |
| CREATE INDEX CONCURRENTLY | users | 5M | ~16-20 phút | None | |
| SET NOT NULL | users | 5M | < 1s | Brief schema | After backfill |

THỜI ĐIỂM CHẠY MIGRATION:
□ Low traffic window: typically 2-4 AM local time
□ Không chạy migrations trong peak traffic giờ
□ Thông báo team trước ít nhất 24h
□ Chuẩn bị rollback trong 15 phút đầu sau deploy
```

### Bước 8: Test migration on staging

```
CHECKLIST STAGING TEST:

Chuẩn bị staging:
□ Staging database có data tương đương production (anonymized)
□ Staging data volume ít nhất 10% production (để estimate thời gian realistic)
□ Staging application config giống production

Chạy test:
□ Chạy migration script trên staging
□ Đo thời gian thực tế mỗi bước
□ Verify data integrity post-migration (dùng validation scripts từ Bước 5)
□ Test rollback: chạy rollback script → verify database về trạng thái ban đầu
□ Test application: smoke test các features bị ảnh hưởng

Ghi lại kết quả:
□ Thời gian thực tế từng bước (so sánh với estimate)
□ Issues gặp phải và cách xử lý
□ Rollback thành công không?
□ Application hoạt động đúng không?

RED FLAGS (phải fix trước production):
□ Migration lâu hơn estimate > 50%
□ Rollback không hoàn toàn (còn data residue)
□ Application errors sau migration
□ Data integrity violations
```

### Bước 9: Go-live checklist

```
TRƯỚC KHI DEPLOY PRODUCTION:
□ Migration đã test thành công trên staging
□ Rollback script đã test thành công trên staging
□ Thời gian estimate realistic dựa trên staging results
□ Team đã được thông báo (DBA, Backend dev, DevOps, QA)
□ Monitoring setup: DB metrics, application error rate, slow query log
□ Rollback plan có trong tay và đã được review
□ Database backup đã chạy và verified (nếu chưa có scheduled backup)
□ Maintenance window đã confirm (nếu cần downtime)

TRONG KHI CHẠY MIGRATION:
□ Monitor: disk I/O, CPU, lock waits, replication lag
□ Verify từng bước trước khi sang bước tiếp
□ Nếu bất kỳ step nào fail → DỪNG LẠI, không tiếp tục
□ Log mọi commands đã chạy và thời gian

SAU KHI MIGRATION HOÀN TẤT:
□ Chạy validation scripts → verify data integrity
□ Smoke test application
□ Monitor application error rate 30 phút sau migration
□ Monitor slow query log cho patterns bất thường
□ Update documentation nếu schema thay đổi ảnh hưởng đến other teams
```

### Bước 10: Output

```
FILE 1: .mc-data/docs/phase3-architecture/migration-plan.md
Cấu trúc: Tổng quan → Phân loại (type, zero-downtime, duration, risk) → Current/Target State →
Migration Sequence → Rollback Plan → Validation Scripts → Performance Impact → Staging Results → Go-Live Checklist

FILE 2: .mc-data/docs/phase3-architecture/migrations/[YYYYMMDDHHMMSS]_[description].sql
Template: Header (REQ-ID, author, date, duration) → BEGIN; MIGRATION SQL; COMMIT; → ROLLBACK section → VALIDATION section
```

---

## Checklist trước khi submit

```
Assessment:
□ Data volume estimate đầy đủ cho bảng bị ảnh hưởng
□ FK dependencies đã map ra
□ Application code impact đã xác định

Design:
□ Migration type phân loại đúng (A/B/C/D)
□ Zero-downtime strategy phù hợp với data volume
□ Expand-contract cho TYPE C migrations
□ Rollback plan cho mọi migration (ghi rõ nếu irreversible)

Scripts:
□ Migration script chia thành atomic transactions (BEGIN/COMMIT)
□ Batch processing cho UPDATE/backfill trên bảng lớn
□ CREATE INDEX CONCURRENTLY (không lock)
□ Validation scripts pre và post migration
□ Migration files theo naming: YYYYMMDDHHMMSS_description.sql

Testing:
□ Staging test results documented
□ Rollback tested và verified
□ Estimated duration updated dựa trên staging results

Output:
□ REQ-ID references trong file headers
□ Migration plan document đủ thông tin cho team deploy
□ Go-live checklist ready
```
