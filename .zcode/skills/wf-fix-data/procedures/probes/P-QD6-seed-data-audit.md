# P-QD6-seed-data-audit — Kiem tra tinh dung dan cua seed data

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-seed-data-audit |
| **Loai** | static |
| **Profile** | deep, exhaustive |
| **Muc dich** | Kiem tra seed data: seed files co ton tai cho reference tables khong, seed data co consistent khong (ID unique, FK references valid), seed data co cover tat ca enum values khong. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## PRE-GATE

```
IF khong tim thay seed files (seed.ts, seed.sql, prisma/seed.ts, drizzle/seed.ts):
  SKIP probe, note "no_seed_files"
```

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-seed-data-audit.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-seed-data-audit \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-seed-data-audit","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien seed files theo ORM stack:
  - Prisma: prisma/seed.ts, prisma/seed.js
  - TypeORM: src/seed/, src/database/seed.ts
  - Drizzle: drizzle/seed.ts
  - Raw SQL: seed.sql, seeds/, data/seed.sql
- Doc migration files de biet reference tables (tables co FK from others)
- Parse seed data JSON/objects
- Kiem tra data consistency

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-seed-data-audit --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

## THINK

Bash script implement logic sau:

1. **Reference table seed coverage:**
   - Doc migration SQL, extract CREATE TABLE statements
   - Identify reference tables: lookup/enum tables (category, status, role, type, config)
   - Heuristic: table co < 50 rows du kien, co FK from nhieu tables khac
   - Kiem tra seed files co insert data cho reference tables khong
   - Neu reference table khong co seed data -> emit `missing_reference_seed` (severity=high)
   - Neu reference table chi co 1 phan enum values -> emit `incomplete_reference_seed` (severity=medium)

2. **Duplicate ID detection:**
   - Parse seed data objects, extract ID values
   - Phat hien duplicate ID trong cung 1 bang -> emit `duplicate_seed_id` (severity=critical)
   - Phat hien duplicate unique business key (slug, code) -> emit `duplicate_seed_key` (severity=high)

3. **FK reference validity:**
   - Doc migration de lay FK constraints (ALTER TABLE ADD FOREIGN KEY)
   - Doc seed data, check FK values co ton tai trong referenced table seed khong
   - Phat hien orphan FK references -> emit `invalid_fk_seed_ref` (severity=critical)
   - Chi kiem tra trong seed data scope (cross-file references)

4. **Enum value coverage:**
   - Doc enum definitions trong code:
     - Prisma: `enum Status { ACTIVE INACTIVE ARCHIVED }`
     - TypeScript: `type Status = 'ACTIVE' | 'INACTIVE' | 'ARCHIVED'`
     - TypeORM: `@Column({type: 'enum', enum: StatusEnum})`
   - Doc seed data cho table tuong ung
   - So sanh enum values vs seed data values
   - Neu enum value thieu trong seed -> emit `enum_value_not_seeded` (severity=medium)
   - Neu seed co value khong co trong enum -> emit `orphan_seed_value` (severity=medium)

5. **Seed data format validation:**
   - Kiem tra seed data types co khop voi model field types khong
   - VD: model field Int -> seed value phai la number, khong phai string
   - VD: model field DateTime -> seed value phai la Date/ISO string
   - Emit `seed_type_mismatch` (severity=medium)

6. **Profile-based depth:**
   - deep: Kiem tra reference seed coverage + duplicate IDs + FK references
   - exhaustive: Bo sung enum value coverage + seed format validation + cross-file FK chain validation

7. **Dedup:** fingerprint = sha256(QD6|seed_table|seed_id|probe_id|consistency_type)

## ACT

Bash script output signals theo schema signal-v2 voi:
- dimension_id: QD6, probe_id: P-QD6-seed-data-audit
- signal_type: missing_reference_seed | incomplete_reference_seed | duplicate_seed_id | duplicate_seed_key | invalid_fk_seed_ref | enum_value_not_seeded | orphan_seed_value | seed_type_mismatch
- severity theo Severity Rules
- evidence[] voi seed file path + line, value excerpt, enum definition reference

Sau do SKILL.md emit signals vao signals.json:

```bash
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra missing_reference_seed signals co chi ro reference table name
2. Kiem tra invalid_fk_seed_ref signals co chi ro FK column va referenced table
3. Kiem tra duplicate_seed_id signals co chi ro ID bi trung
4. Kiem tra khong co false positives cho:
   - Seed data dung UUID (auto-generated, khong co ID trong seed)
   - Reference table co seed data o file khac (cross-file FK)
   - Enum values intentionally not seeded (admin-only values)
5. Moi severity dung voi Severity Rules

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Duplicate ID trong cung 1 bang seed | CRITICAL |
| FK reference trong seed tro den record khong ton tai | CRITICAL |
| Reference table (lookup/enum) hoan toan khong co seed data | HIGH |
| Duplicate unique business key (slug, code) trong seed | HIGH |
| Reference table chi co 1 phan enum values | MEDIUM |
| Enum value tu code khong co trong seed tuong ung | MEDIUM |
| Seed value khong co trong enum definition (orphan) | MEDIUM |
| Seed value type khong khop voi model field type | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay seed files | Skip probe, note "no_seed_files" |
| Seed files empty hoac chi co placeholder | Emit "missing_all_seed_data" signal (severity=high) |
| Khong tim thay migration files (khong xac dinh duoc reference tables) | Chi kiem tra seed internal consistency, note "no_migration_for_ref_check" |
| Seed data dung raw SQL (kho parse) | Parse SQL INSERT statements, note "raw_sql_parsing" |
| Seed data dung factory (faker.js) | Chi kiem tra factory co tao du data cho reference tables khong, note "factory_based_seed" |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
