# P-QD6-data-type-mismatch — Phat hien data type mismatch giua code va database

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-data-type-mismatch |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | So sanh kieu du lieu trong ORM/code voi kieu du lieu trong migration/DB. Phat hien string vs INT, boolean vs TINYINT, Date vs TIMESTAMP, float precision, enum value sync. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-data-type-mismatch.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-data-type-mismatch \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-data-type-mismatch","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien tech stack: Prisma / TypeORM / EF Core / Drizzle
- Doc ORM model annotations va migration column types
- So sanh type mapping per tech stack
- Phat hien boolean/integer mismatch, date precision, numeric scale

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-data-type-mismatch --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

## THINK

Bash script implement logic sau:

1. **Type mapping cross-reference (ORM vs migration):**

   | Kieu ORM | Kieu DB mong doi | Mismatch flags |
   |----------|-----------------|----------------|
   | Prisma String | varchar(n), text, uuid | INT or Float -> mismatch |
   | Prisma Int | integer, int4, int | String or Text -> mismatch |
   | Prisma Boolean | boolean, bool | integer (0/1) -> canh bao |
   | Prisma DateTime | timestamp, timestamptz | date (khong gio) -> precision loss |
   | Prisma Float | real, float4, double precision | integer -> precision loss |
   | TypeORM @Column('varchar') | varchar(n) | text -> co the duoc nhung canh bao |
   | EF Core .HasMaxLength(100) | varchar(100) | varchar(max) -> mismatch |
   | EF Core .HasPrecision(18,2) | decimal(18,2) | float -> precision loss |

2. **Boolean storage detection:**
   - Prisma Boolean mapping sang DB `boolean` -> OK
   - Prisma Boolean mapping sang DB `integer` (0/1) -> emit `boolean_as_integer` (severity=medium)
   - Kiem tra co @map/transformer de chuyen doi boolean sang integer khong
   - Neu co transformer (TypeORM @Column({type: 'tinyint', transformer: ...})) -> accept, giam severity xuong low

3. **Date/Time precision detection:**
   - Prisma DateTime -> DB `timestamp(3)` -> OK
   - Prisma DateTime -> DB `date` (chi ngay, khong gio) -> emit `date_precision_loss` (severity=high)
   - Prisma DateTime -> DB `timestamp(0)` (giay, khong milli) -> emit `ms_precision_loss` (severity=low)
   - Kiem tra @UpdatedAt / @CreateDateColumn co dung timezone khong

4. **Numeric precision detection:**
   - Prisma Float -> DB `decimal` (exact) -> emit `float_vs_decimal` (severity=medium)
   - Prisma Decimal -> DB `float` (approximate) -> emit `decimal_vs_float` (severity=high)
   - So sanh precision/scale: decimal(18,2) vs decimal(10,0) -> precision loss
   - Kiem tra @Column({type: 'decimal', precision: 10, scale: 2}) co khop voi migration khong

5. **Enum value sync detection:**
   - Prisma: So sanh enum definition values voi migration column CHECK constraint values
   - TypeORM: So sanh enum definition trong @Column({type: 'enum', enum: [...]}) voi DB CHECK
   - Phat hien: enum values co trong code nhung khong trong DB, va nguoc lai
   - Emit `enum_value_mismatch` (severity=high) khi co value o 1 ben nhung thieu o ben kia

6. **String length detection:**
   - Prisma: String@db.VarChar(100) vs migration varchar(255) -> khac length
   - EF Core: .HasMaxLength(50) vs migration nvarchar(max) -> thieu max length
   - Emit `string_length_mismatch` (severity=medium)

7. **Profile-based depth:**
   - standard: Chi kiem tra boolean/integer + date precision + enum sync
   - deep: Bo sung numeric precision + string length checks
   - exhaustive: Bo sung kiem tra UUID format, JSON type mapping, array type mapping

8. **Dedup:** fingerprint = sha256(QD6|table|column|probe_id|type_aspect)

## ACT

Bash script output signals theo schema signal-v2 voi:
- dimension_id: QD6, probe_id: P-QD6-data-type-mismatch
- signal_type: boolean_as_integer | date_precision_loss | ms_precision_loss | float_vs_decimal | decimal_vs_float | enum_value_mismatch | string_length_mismatch
- severity theo Severity Rules
- evidence[] voi ORM type annotation (file + line), migration column type (file + line)

Sau do SKILL.md emit signals vao signals.json:

```bash
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra moi Signal co evidence tro den type definition o ca ORM va migration
2. Kiem tra boolean_as_integer signals co kem evidence ve transformer (neu co)
3. Kiem tra enum_value_mismatch signals co danh sach cu the cac values thieu
4. Kiem tra khong co false positives cho:
   - Boolean stored as integer co transformer -> severity giam xuong LOW
   - DateTime vs timestamptz neu app chi can UTC
   - Float vs decimal neu precision < 6 digits
5. Moi severity dung voi Severity Rules

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Boolean field luu duoi dang integer KHONG co transformer | HIGH |
| Boolean field luu duoi dang integer CO transformer | LOW (acceptable pattern) |
| DateTime field mapping sang DATE (chi ngay, mat gio) | HIGH |
| Decimal field mapping sang float (mat precision) | HIGH |
| Float field mapping sang decimal (performance impact) | MEDIUM |
| Enum values khac nhau giua code va DB | HIGH |
| String max length khac nhau giua ORM va migration | MEDIUM |
| Numeric precision khac nhau (VD: decimal(18,2) vs decimal(10,0)) | MEDIUM |
| Timestamp mat milliseconds (timestamp(0)) | LOW |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay ORM files | Skip probe, note "no_orm_files" |
| Khong tim thay migration files | Skip probe, chi kiem tra ORM type consistency, note "no_migration_files" |
| Tech stack khong ho tro type introspection | Skip probe, note "unsupported_stack" |
| Enum values co the empty | Accept empty enum, note "empty_enum_definition" |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
