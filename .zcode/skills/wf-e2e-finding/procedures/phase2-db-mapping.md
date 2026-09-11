# F0a — Phase 2: DB MAPPING (FIND only)

## Mục tiêu

Scan migration files + schema để lập bản đồ DB. KHÔNG live-test. Nếu không tìm thấy → ghi N/A có giải thích.

---

## FIND — Nguồn scan

```bash
# 1. Migration files
find apps/backend/ -name "*.cs" -path "*/Migrations/*" | grep -i "$MODULE_ID" | sort | tail -20

# 2. DbContext / entity configurations
find apps/backend/ -name "*DbContext.cs" -o -name "*EntityConfiguration*.cs" | grep -i "$MODULE_ID" | head -10

# 3. Domain entities (class tên khớp feature)
find apps/backend/Eureka.Modules.${MODULE_ID}/Domain/ -name "*.cs" 2>/dev/null | head -20

# 4. Nếu CI available: Serena scan
[ "$SERENA_AVAILABLE" = "true" ] && \
  mcp__serena__search_for_pattern --pattern="DbSet<" --relative_path="apps/backend/Eureka.Modules.${MODULE_ID}/"

# 5. Schema file nếu có
find . -name "*.sql" -o -name "schema.prisma" -o -name "*.dbml" 2>/dev/null | grep -i "$MODULE_ID" | head -5
```

---

## ASSESS — Checklist tự đánh giá

```
[ ] Tìm được ≥1 table/entity chính liên quan feature
[ ] Biết schema name (database schema prefix nếu có)
[ ] Biết các columns quan trọng (PK, FK, required, unique)
[ ] Biết ≥1 FK relationship
[ ] Biết migration file mới nhất
```

Nếu chưa đủ → BỔ SUNG thêm:

```bash
# Grep class definitions
grep -r "class $ENTITY_NAME\b" apps/backend/ --include="*.cs" -l | head -5

# Grep column attributes
grep -A 20 "class $ENTITY_NAME" apps/backend/Eureka.Modules.${MODULE_ID}/Domain/ --include="*.cs" -r | grep -E "Required|MaxLength|FK|Column|Index" | head -20
```

---

## SEED DATA — Chuẩn bị (không chạy)

Thiết kế seed data cho db-seed-data.md gồm ~20 bản ghi SQL INSERT phủ:
- **Happy path**: bản ghi hợp lệ đầy đủ
- **Edge case**: giá trị biên (min/max length, null allowed)
- **State variety**: các trạng thái status khác nhau nếu có
- **FK chains**: bản ghi parent trước, child sau

---

## Output — Ghi 2 files

### db-mapping.md

Từ template `templates/db-mapping.template.md`. Điền:
- Table name + schema name
- Column list (name, type, constraints, FK)
- Relationships (OneToMany, ManyToMany, ...)
- Migration files liên quan (file path + migration ID)
- CRUD operations feature này thực hiện
- Index quan trọng

Nếu không tìm thấy DB artifacts → ghi rõ lý do + đánh dấu E023 warning.

### db-seed-data.md

Từ template `templates/db-seed-data.template.md`. Ghi:
- SQL INSERT statements (~20 bản ghi)
- Nhóm theo mục đích: Happy / Edge / State / FK chain
- Comment giải thích mỗi nhóm

---

## POST-GATE Phase 2

```bash
# T1: 2 files tồn tại
test -f "$FINDINGS_DIR/db-mapping.md" || { log_error "E023" "phase2" "db-mapping.md không tồn tại"; return 1; }
test -f "$FINDINGS_DIR/db-seed-data.md" || { log_error "E023" "phase2" "db-seed-data.md không tồn tại"; return 1; }

# T2: size > 500 bytes (hoặc có N/A explanation)
for F in db-mapping.md db-seed-data.md; do
  SIZE=$(wc -c < "$FINDINGS_DIR/$F")
  [ "$SIZE" -gt 200 ] || { log_error "E023" "phase2" "$F quá nhỏ"; return 1; }
done
```

---

## Cập nhật status.json

```bash
update_phase_status "p2_db" "done"
advance_phase 3 "run P3 API mapping"
log_event "COMPLETE" "phase2" "DB mapping generated"
check_context_budget
```
