# Phase 2: DB — Chi tiết procedure

## Mục tiêu

Map đầy đủ database schema liên quan. Sinh seed data ~20 bản ghi phủ mọi trường hợp. Verify tính đúng đắn ở tầng DB.

## FIND — Nguồn đọc

0. **Business entities từ Phase 1**: Đọc `findings/business-understanding.md` → lấy danh sách entity nghiệp vụ. Các entity này là input chính để tìm code entity tương ứng.
1. Entity files: `mcp__serena__find_symbol` với tên entity từ business-understanding → tìm class entity. Nếu không tìm thấy → fallback: `apps/backend/Eureka.Modules.{Module}/Domain/Entities/`
2. Value Objects: `Domain/ValueObjects/` — tìm các loại dữ liệu phức tạp
3. EF Config: `apps/backend/Eureka.Infrastructure/Persistence/Configurations/{Module}*/` — dùng `mcp__serena__find_symbol` tìm config class theo entity name
4. DbContext: `Eureka.Infrastructure/Persistence/EurekaDbContext.cs` — tìm DbSet của module
5. Migrations: Grep tên table trong `Eureka.Infrastructure/Persistence/Migrations/`
6. Enum types: `Domain/Enums/` — biết các giá trị hợp lệ

Serena tools:
- `mcp__serena__find_symbol` với tên entity class
- `mcp__serena__get_symbols_overview` với entity file
- `mcp__gitnexus__context` với entity class name

Tổng hợp:
- Danh sách tables + primary key type (UUID/int)
- Columns quan trọng (type, nullable, constraints)
- FK relationships (HasOne/HasMany/HasForeignKey/BelongsTo)
- PostgreSQL schema name (`HasDefaultSchema`)
- CRUD operations: Create / Read / Update / Delete / SoftDelete
- Transaction scope

## ASSESS — Checklist

```
[ ] ≥1 table chính được xác định (tên thật, không phải entity class)
[ ] Entity tìm được khớp với danh sách entity từ business-understanding.md
[ ] Schema name biết (vd "crm", "orders", "finance")
[ ] FK relationships đã map (HasOne/HasMany/HasForeignKey/BelongsTo)
[ ] CRUD operations của feature đã biết
[ ] ≥1 migration file liên quan đã tìm thấy
[ ] Enum values đã biết (nếu có enum columns)
```

Nếu thiếu entity so với business-understanding → BỔ SUNG: tìm lại bằng tên entity nghiệp vụ (có thể entity class tên khác với tên bảng).

Nếu thiếu → BỔ SUNG: đọc thêm entity, config, gitnexus context.

## SEED DATA — Sinh dữ liệu mẫu phong phú

Sau khi ASSESS đủ, sinh seed data cho tất cả tables liên quan:

### Nguyên tắc sinh seed data

Phải có **~20 bản ghi** phủ mọi trường hợp:

```
Nhóm 1: HAPPY PATH (5-8 bản ghi)
  - Bản ghi đầy đủ mọi field (không để null)
  - Các enum values đều có ít nhất 1 bản ghi
  - Các combination trạng thái quan trọng

Nhóm 2: EDGE CASES (5-7 bản ghi)
  - Bản ghi với optional fields = null
  - Bản ghi với giá trị boundary (max length string, 0, rất lớn)
  - Bản ghi với ký tự đặc biệt (tiếng Việt, unicode)
  - Bản ghi liên quan FK (parent + child)

Nhóm 3: TRẠNG THÁI ĐẶC BIỆT (3-5 bản ghi)
  - Soft deleted (IsDeleted = true)
  - Trạng thái cuối của workflow (vd status = "Completed", "Cancelled")
  - Bản ghi lỗi/không hợp lệ có thể xảy ra trong thực tế

Nhóm 4: QUAN HỆ (2-4 bản ghi)
  - Test FK constraint: bản ghi cha + con
  - Test cascade behavior
```

### Format seed data

Sinh SQL INSERT hoặc C# seeder class:

**SQL format:**
```sql
-- Seed data cho {table_name} — {FEAT-ID} v5.0.0
-- Generated: {date}

-- Nhóm 1: Happy path
INSERT INTO {schema}.{table} ({col1}, {col2}, ...) VALUES
  ('uuid-1', 'value1', ...),  -- Case: {mô tả}
  ('uuid-2', 'value2', ...),  -- Case: {mô tả}
  ...;

-- Nhóm 2: Edge cases
INSERT INTO {schema}.{table} ({col1}, {col2}, ...) VALUES
  ('uuid-N', null, ...),  -- Case: optional field null
  ...;
```

**C# Seeder (nếu phù hợp với pattern dự án):**
Tham khảo pattern từ `apps/backend/Eureka.Api/Seeders/`.

### Ghi seed data vào file

Seed data ghi vào `findings/db-seed-data.md` (template `db-seed-data.template.md`).

Format file: mô tả từng nhóm, SQL script, ghi chú coverage.

## TEST — Verify DB

> **Quy tắc:** Live SQL test là **BẮT BUỘC**. DB không chạy → **PHẢI cố gắng khởi động** (xem `_shared.md` §Infrastructure Auto-Start). KHÔNG silent fallback chỉ static review. Auto-start fail sau retry → ESCALATE Nhóm 2 (block-test.json), KHÔNG advance phase.

### Bước 0 — Bảo đảm DB chạy (cross-session safe)

```bash
# Load lock helpers
source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
source .claude/scripts/wf-e2e-shared/version-snapshot.sh

# Reader lock cho query bình thường; nếu có migration apply ở bước 2 → upgrade writer
ensure_infrastructure_running database read || exit_with_escalation
```

Nếu auto-start thất bại sau 2 retry → escalate (ghi block-test.json Nhóm 2 + AskUserQuestion). KHÔNG tiếp tục Phase 2 test.

### Bước 1 — Static review BỔ SUNG (EF Config)

Static review là bước **bổ sung** giúp catch type/constraint bug — KHÔNG phải fallback. Vẫn cần live SQL test ở bước 3.

```
EF Config review:
  [ ] Required columns có [Required] hoặc .IsRequired() trong config?
  [ ] MaxLength có được set cho string columns quan trọng?
  [ ] Index có trên FK + status + columns hay dùng trong WHERE?
  [ ] Soft delete pattern: IsDeleted bool + DeletedAt? timestamp?
  [ ] Timestamp: CreatedAt + UpdatedAt (hoặc tương đương)?
  [ ] UUID primary key: .HasDefaultValueSql("gen_random_uuid()")?
```

### Bước 2 — Migration check (BẮT BUỘC nếu dotnet available)

```bash
dotnet ef migrations list \
  --project apps/backend/Eureka.Infrastructure \
  --startup-project apps/backend/Eureka.Api 2>&1 | tail -10
```

Verify migration liên quan đã apply (tên migration không có `[...]`). Nếu `dotnet` không có → ghi caveat, dùng Bước 3 SQL để verify schema thực tế.

**Nếu có migration pending cần apply:** upgrade lên writer lock vì apply migration thay đổi shared DB schema, có thể ảnh hưởng session khác:

```bash
upgrade_to_writer database "$SESSION_ID" "apply_pending_migration" || exit_with_escalation
dotnet ef database update --project apps/backend/Eureka.Infrastructure --startup-project apps/backend/Eureka.Api
downgrade_to_reader database "$SESSION_ID"
```

### Bước 3 — Live SQL test (BẮT BUỘC)

DB đã được auto-start ở Bước 0. Sử dụng connection string từ `.env` hoặc `appsettings.Development.json`:

```bash
# Kiểm tra table tồn tại + row count thực tế
psql "$CONNECTION_STRING" -c "SELECT COUNT(*) FROM {schema}.{table};"

# Kiểm tra constraint + index thực tế (cross-check với EF Config review)
psql "$CONNECTION_STRING" -c "\d+ {schema}.{table}"

# Apply seed data + verify INSERT hợp lệ (FK, constraints, types)
psql "$CONNECTION_STRING" -f $SESSION_DIR/findings/db-seed-data.md  # hoặc execute SQL block
psql "$CONNECTION_STRING" -c "SELECT COUNT(*) FROM {schema}.{table};"  # verify rows inserted

# Test soft delete query
psql "$CONNECTION_STRING" -c "SELECT * FROM {schema}.{table} WHERE \"IsDeleted\" = false LIMIT 5;"
```

Kết quả live SQL test (status, rows, error messages) ghi vào `db-test-report.md` cùng evidence (raw output snippet ≤20 dòng).

### Cấm

- ❌ KHÔNG ghi `RESULT=PASS` cho test DB mà chưa có live SQL output thực tế.
- ❌ KHÔNG dùng EF Config review thay cho live SQL test khi DB không chạy — phải ESCALATE.
- ✅ EF Config review + Migration check là **bổ sung cạnh** live SQL test, KHÔNG thay thế.

## Output

Ghi các files:
- `findings/db-mapping.md` từ `db-mapping.template.md`
- `findings/db-seed-data.md` từ `db-seed-data.template.md`
- `findings/db-test-report.md` từ `db-test-report.template.md`

Update status.json:
- `phase_2_status = "done"`
- `current_phase = 3`
- `sub_state = "FIND"`
