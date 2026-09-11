# P-QD6-constraint-violation — Kiem tra thieu hoac sai database constraints

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-constraint-violation |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Kiem tra ORM models va migration files phat hien: foreign keys thieu index, business keys thieu UNIQUE constraint, required fields thieu NOT NULL, enum fields thieu CHECK constraint. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## PRE-GATE

```
IF khong tim thay file schema (schema.prisma / *.entity.ts / Configurations/*.cs / drizzle/schema.ts):
  SKIP probe, note "no_orm_schema_files"
```

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-constraint-violation.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-constraint-violation \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-constraint-violation","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien tech stack: Prisma / TypeORM / EF Core / Drizzle
- Doc ORM models, parse field definitions va annotations
- Doc migration files, parse column constraints
- Phat hien 4 loai constraint violation: FK index, UNIQUE, NOT NULL, CHECK

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-constraint-violation --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi SERENA available — find_referencing_symbols la cong cu chinh)

> **Muc dich:** Voi `missing_unique`, `fk_missing_index` — can biet field do dang duoc query/insert nhu the nao de uoc luong impact (vd: missing UNIQUE tren email field bi insert tu N noi → race condition cao).

```bash
if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # Pseudocode:
  # FOR each signal trong $RAW_OUT.signals[] (top 50 theo severity):
  #   field_name = signal.evidence.field_name  # vd: email
  #   entity_class = signal.evidence.entity_class  # vd: User
  #   entity_file = signal.target.file_path  # vd: src/entities/user.entity.ts
  #   
  #   # Find ai dung field
  #   refs = mcp__serena__find_referencing_symbols(
  #     name_path=f"{entity_class}.{field_name}",
  #     relative_path=entity_file
  #   )
  #   signal.evidence.serena_refs_count = len(refs)
  #   signal.evidence.serena_refs_top = refs[0:5]
  #   
  #   # Severity bump rule
  #   IF signal.signal_type == "missing_unique" AND len(refs) > 5:
  #     # Field bi insert tu nhieu noi → race condition risk cao
  #     signal.suggested_severity = "critical"
  #     signal.evidence.severity_bump_reason = f"missing UNIQUE + {len(refs)} insert/query sites"
  #   
  #   IF signal.signal_type == "fk_missing_index" AND GITNEXUS_AVAILABLE:
  #     # Check FK co duoc dung trong query hot path khong
  #     impact = mcp__plugin_gitnexus_gitnexus__impact(target=f"{entity_class}.{field_name}", direction="upstream")
  #     IF "endpoint" in impact.affected_processes:
  #       signal.suggested_severity = "high"  # FK trong endpoint hot → perf risk
  #   
  #   signal.evidence.ci_meta = {gitnexus_used, serena_used, freshness_level, behind_commits}
fi
```

**Graceful:** Serena absent → skip B3, signals giu severity tu B1.

## THINK

Bash script implement logic sau:

1. **FK missing index detection:**
   - Prisma: Tim `@relation` fields, kiem tra neu FK column KHONG co `@@index` hoac `@unique`
   - TypeORM: Tim `@ManyToOne` / `@OneToOne` decorators, kiem tra FK column KHONG co `@Index` hoac `@Unique`
   - EF Core: Tim `HasForeignKey()` / `.WithMany()` calls, kiem tra migration xem co tao index khong
   - Emit `fk_missing_index` signal (severity=high) khi tim thay FK thieu index

2. **Unique constraint detection:**
   - Tim business key fields: email, username, phone, slug, code, tax_id, reference_number
   - Kiem tra cac field nay co `@unique` / `@Index({ unique: true })` / `HasIndex().IsUnique()` khong
   - Kiem tra combined unique: `@@unique([field1, field2])` / `@UniqueConstraint`
   - Emit `missing_unique` signal (severity=high) neu business key thieu UNIQUE

3. **NOT NULL detection:**
   - Prisma: Kiem tra field KHONG co `?` (optional) -> expected NOT NULL
   - TypeORM: Kiem tra `@Column({ nullable: false })` hoac `@IsNotEmpty` decorator
   - EF Core: Kiem tra `.IsRequired()` configuration
   - Cross-ref voi migration: column co `NOT NULL` khong?
   - Emit `missing_not_null` signal (severity=medium) neu required field thieu NOT NULL

4. **CHECK constraint detection:**
   - Tim enum/status fields: status, state, type, role, category, level, priority
   - Kiem tra co CHECK constraint trong migration: `CHECK (status IN ('a', 'b', 'c'))`
   - Kiem tra co enum validation o code level: Prisma `enum`, TypeORM `@Column({ type: "enum" })`, EF `.HasConversion()`
   - Emit `missing_check` signal (severity=medium) neu enum/status field thieu CHECK

5. **Profile-based depth:**
   - quick: Chi kiem tra FK indexes + business key unique tren 5 tables chinh
   - standard: Kiem tra FK indexes + unique + NOT NULL tren tat ca tables
   - deep: Bo sung CHECK constraint detection cho enum fields
   - exhaustive: Kiem tra ca composite keys, partial unique indexes, exclusion constraints

6. **Dedup:** fingerprint = sha256(QD6|table|column|probe_id|constraint_type)

## ACT

Bash script output signals theo schema signal-v2 voi:
- dimension_id: QD6, probe_id: P-QD6-constraint-violation
- signal_type: fk_missing_index | missing_unique | missing_not_null | missing_check
- severity theo Severity Rules
- fixability: agent_fix, domain: backend
- evidence[] voi ORM file path + line, migration file path + line, column definition excerpt
- remediation.suggested_action: goi y cu phap index/constraint can them

Sau do SKILL.md emit signals vao signals.json:

```bash
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra moi Signal co `evidence` tro den file ORM hoac migration
2. Kiem tra fk_missing_index signals co chi ro FK column va referenced table
3. Kiem tra missing_unique signals co chi ro business key field
4. Kiem tra khong co false positives cho:
   - Cascade delete FK (khong can index neu chi co 1-2 rows)
   - Soft delete columns (nullable la intentional)
   - System-generated fields (created_at, updated_at)
5. Moi severity dung voi Severity Rules

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| FK column thieu index tren table > 1000 rows (du doan) | HIGH |
| FK column thieu index tren table nho (< 1000 rows) | MEDIUM |
| Business key field (email, username, slug, code) thieu UNIQUE | HIGH |
| Secondary business key thieu UNIQUE (phone, tax_id) | MEDIUM |
| Required field thieu NOT NULL trong migration | MEDIUM |
| Enum/status field thieu CHECK constraint | MEDIUM |
| Composite unique thieu tren (fk1, fk2) cap | HIGH |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay ORM schema files | Skip probe, note "no_orm_files" |
| DuckDB/SQLite project (khong ho tro CHECK) | Skip CHECK detection, note "no_check_support" |
| Tech stack khong duoc ho tro | Skip probe, note "unsupported_stack" |
| Parse error trong ORM file | Log WARNING, skip model do, tiep tuc cac model khac |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
