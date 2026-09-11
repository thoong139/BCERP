# P-QD6-schema-drift-detect — Phat hien schema drift giua ORM models va migrations

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-schema-drift-detect |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | So sanh ORM model definitions (schema.prisma, *.entity.ts, Entity Framework configurations) voi migration SQL files. Phat hien columns/tables chi co o 1 ben, type mismatches, missing defaults. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-schema-drift-detect.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-schema-drift-detect \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-schema-drift-detect","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien tech stack (Prisma / TypeORM / Drizzle / EF Core / raw SQL) qua config files va ORM directory structure
- Parse ORM schema files: `schema.prisma`, `*.entity.ts`, `*.configuration.cs`, `drizzle/schema.ts`
- Parse migration files: `prisma/migrations/*/migration.sql`, `src/**/Migrations/*.cs`, `drizzle/migrations/*.sql`
- Cross-compare column sets per table: columns trong model nhung khong co trong migration -> `missing_in_db` signal
- Cross-compare columns trong migration nhung khong co trong model -> `missing_in_code` signal
- So sanh column types (Prisma `String` vs SQL `varchar(255)`, EF `HasMaxLength` vs SQL precision)
- So sanh nullability: `@required`/`IsRequired()` vs `NOT NULL` trong migration
- So sanh defaults: `@default(now())` vs `DEFAULT CURRENT_TIMESTAMP`

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-schema-drift-detect --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi GITNEXUS/SERENA available — use-case kinh dien cho QD6)

> **Muc dich:** Schema drift bug co the cuc ky nguy hiem (CDG-SCHEMA-BREAK). PHAI biet ai dang dung column/table bi mismatch truoc khi propose fix.
> **Tools:** GitNexus impact (upstream callers cua entity), Serena find_referencing_symbols (precise call sites cua field).

```bash
# Sau khi B1 chay xong, raw signals da co. Enrich cho moi signal:
if [[ "$GITNEXUS_AVAILABLE" == "true" || "$SERENA_AVAILABLE" == "true" ]]; then
  ENRICHED_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-schema-drift-detect.enriched.json"
  
  # Pseudocode (orchestrator agent thuc hien MCP calls):
  # FOR each signal trong $RAW_OUT.signals[]:
  #   table = signal.evidence.table_name
  #   column = signal.evidence.column_name (neu co)
  #   entity_file = signal.target.file_path  # vd: src/entities/user.entity.ts
  #   
  #   IF SERENA_AVAILABLE va entity_file:
  #     # Tim entity class symbol
  #     symbols = mcp__serena__get_symbols_overview(entity_file)
  #     entity_class = find symbol kind=class trong symbols
  #     
  #     # Tim ai dung field bi drift
  #     IF column:
  #       refs = mcp__serena__find_referencing_symbols(name_path=f"{entity_class}.{column}", relative_path=entity_file)
  #       signal.evidence.serena_refs_count = len(refs)
  #       signal.evidence.serena_refs_top = refs[0:5]
  #   
  #   IF GITNEXUS_AVAILABLE va entity_class:
  #     impact = mcp__plugin_gitnexus_gitnexus__impact(target=entity_class, direction="upstream")
  #     signal.evidence.gitnexus_callers = impact.direct_callers_count
  #     signal.evidence.gitnexus_processes = impact.affected_processes
  #     # CDG-SCHEMA-BREAK trigger: HIGH risk + critical dimension
  #     IF impact.risk_level IN ("HIGH", "CRITICAL") va signal.signal_type IN ("missing_in_db", "type_mismatch"):
  #       signal.cdg_flag = "CDG-SCHEMA-BREAK"
  #       signal.suggested_severity = "critical"  # bump
  #   
  #   signal.evidence.ci_meta = {
  #     "gitnexus_used": $GITNEXUS_AVAILABLE,
  #     "serena_used": $SERENA_AVAILABLE,
  #     "freshness_level": $FRESHNESS_LEVEL,
  #     "behind_commits": $FRESHNESS_BEHIND
  #   }
  
  # Ghi enriched signals (overwrite RAW_OUT)
  # mv "$ENRICHED_OUT" "$RAW_OUT"
fi
```

**Cap signals enrich:** top 50 theo severity de tranh MCP overload. Signal ngoai top 50 → `ci_meta.gitnexus_used = false`.

**Graceful:** CI absent → skip B3, signals giu nguyen tu B1 (zero regression).

## THINK

Bash script implement logic sau:

1. **Tech stack detection:**
   - `schema.prisma` ton tai -> Prisma stack
   - `**/*.entity.ts` ton tai -> TypeORM stack
   - `drizzle/schema.ts` ton tai -> Drizzle stack
   - `**/Configurations/*.cs` ton tai -> EF Core stack
   - Fallback: raw migration SQL files trong `migrations/` or `migrate/`

2. **Table extraction (truy vet table list tu 2 nguon):**
   - Tu ORM: Prisma `model`, TypeORM `@Entity()`, EF `ToTable()`, Drizzle `createTable()`
   - Tu migrations: `CREATE TABLE` statements

3. **Column comparison per table:**
   - Neu table chi co trong ORM -> emit `missing_in_db` signal (severity=critical)
   - Neu table chi co trong migration -> emit `missing_in_code` signal (severity=high)
   - Neu column chi co trong ORM -> emit `missing_column_in_db` (severity=high)
   - Neu column chi co trong migration -> emit `missing_column_in_code` (severity=medium)
   - Neu column type khac nhau -> emit `type_mismatch` (severity=high)
   - Neu nullability khac nhau -> emit `nullability_mismatch` (severity=medium)
   - Neu default value khac nhau -> emit `default_mismatch` (severity=medium)

4. **Profile-based depth:**
   - `quick`: Chi kiem tra top 10 tables co nhieu columns nhat
   - `standard`: Kiem tra tables co trong exit_criteria probe list
   - `deep`: Tat ca tables, bao gom ca relation columns (FK)
   - `exhaustive`: Tat ca tables + view definitions (CREATE VIEW) + sequence definitions + enum types

5. **Dedup:** fingerprint = sha256(QD6|table|column|probe_id|drift_type)

6. **Skip the nay neu chi co 1 nguon (ORM hoac migration) ton tai -> note `single_source_only`**

## ACT

Bash script (`wf-fix-probe-static-data.sh`) output signals theo schema `signal-v2` voi:
- `dimension_id: "QD6"`, `probe_id: "P-QD6-schema-drift-detect"`
- `signal_type`: `missing_in_db` | `missing_in_code` | `missing_column_in_db` | `missing_column_in_code` | `type_mismatch` | `nullability_mismatch` | `default_mismatch`
- `severity` theo Severity Rules
- `fixability: "agent_fix"`, `domain: "backend"`
- `evidence[]` voi: ORM file path + line, migration file path + line, ORM type, DB type
- `registry_refs` neu co feature_id mapping

Sau khi bash script chay, **SKILL.md append signals vao `signals.json`** qua signal-emit.md helper:

```bash
# Trong SKILL.md / signal-emit.md helper
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
2. Kiem tra moi Signal co `target.file_path` tro den file ORM hoac migration
3. Kiem tra moi Signal co `suggested_severity` trong ["critical","high","medium","low"]
4. Kiem tra moi Signal co `signal_type` trong danh sach hop le
5. Neu output rong (khong co drift) -> write empty signals array, note "no_drift_detected"
6. Neu chi co 1 nguon (ORM hoac migration thieu) -> write 0 signals, note "single_source_only"

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Table ton tai trong ORM nhung khong co trong migration (production DB thieu table) | CRITICAL |
| Table ton tai trong migration nhung khong co trong ORM (production-only table khong duoc code quan ly) | HIGH |
| Column ton tai trong ORM nhung khong co trong migration | HIGH |
| Column ton tai trong migration nhung khong co trong ORM (code khong map duoc) | MEDIUM |
| Column type khac nhau giua ORM va migration (VD: Prisma String vs SQL INT) | HIGH |
| Nullability khac nhau (VD: ORM required vs DB nullable) | MEDIUM |
| Default value khac nhau (VD: ORM default(now) vs DB DEFAULT NULL) | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay ORM schema files | Skip ORM comparison, chi kiem tra migration files, note "no_orm_files" |
| Khong tim thay migration files | Skip migration comparison, chi doc ORM files, note "no_migration_files" |
| Ca hai deu khong tim thay | Skip probe, note "no_schema_sources" |
| Tech stack khong duoc ho tro | Skip probe, note "unsupported_stack" |
| Parse error trong file | Log WARNING, bo qua file do, tiep tuc cac file khac |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
