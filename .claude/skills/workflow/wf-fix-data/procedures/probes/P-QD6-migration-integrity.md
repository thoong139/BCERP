# P-QD6-migration-integrity — Kiem tra tinh toan ven cua migration chain

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-migration-integrity |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Xac nhan migration files co tuan tu dung thu tu, co cap up/down, khong chua lenh destructive thieu confirmation, va migration registry table dong bo voi filesystem. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## PRE-GATE

```
IF .mc-data/docs/phase3-architecture/database-*.md KHONG ton tai:
  WARNING: "thieu database architecture docs — migration strategy khong the xac thuc"

IF khong tim thay migration directory:
  SKIP probe, note "no_migration_directory"
```

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-migration-integrity.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-migration-integrity \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-migration-integrity","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien migration directory theo tech stack:
  - Prisma: prisma/migrations/
  - TypeORM: src/**/migrations/ hoac typeorm/migrations/
  - EF Core: **/Migrations/ (Generated Migration Files)
  - Drizzle: drizzle/migrations/
  - Raw SQL: migrations/, migrate/, db/migrations/
- Doc migration files, extract timestamps tu file names + metadata
- Validate ordering: kiem tra gaps trong sequence

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-migration-integrity --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi GITNEXUS available — destructive migration la nguyen nhan #1 cua data loss)

> **Muc dich:** Voi migration co `DROP COLUMN`, `DROP TABLE`, `ALTER COLUMN TYPE` lam mat data — PHAI biet ai dang dung column/table truoc khi cho phep migration apply.
> **CDG trigger:** Migration destructive + impact CRITICAL → `CDG-06` (destructive DB mutation per Protocol 16).

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # Pseudocode:
  # FOR each signal trong $RAW_OUT.signals[] (top 30 theo severity):
  #   IF signal.signal_type IN ("destructive_drop_column", "destructive_drop_table", "type_narrowing"):
  #     dropped_target = signal.evidence.target  # vd: User.email_old hoac orders_archive
  #     
  #     # Find ORM entity tuong ung
  #     entity_class = lookup_entity_for_table(dropped_target.table)
  #     field_path = f"{entity_class}.{dropped_target.column}" if dropped_target.column else entity_class
  #     
  #     # Impact upstream
  #     impact = mcp__plugin_gitnexus_gitnexus__impact(target=field_path, direction="upstream")
  #     signal.evidence.gitnexus_callers = impact.direct_callers_count
  #     signal.evidence.gitnexus_processes = impact.affected_processes
  #     
  #     # Serena precise refs
  #     IF SERENA_AVAILABLE va field_path co column part:
  #       refs = mcp__serena__find_referencing_symbols(name_path=field_path, relative_path=entity_file)
  #       signal.evidence.serena_refs_count = len(refs)
  #       signal.evidence.serena_refs_top = refs[0:5]
  #     
  #     # CDG escalation
  #     IF impact.risk_level IN ("HIGH", "CRITICAL") OR (signal.evidence.serena_refs_count or 0) > 5:
  #       signal.cdg_flag = "CDG-06"  # destructive DB mutation
  #       signal.suggested_severity = "critical"
  #       signal.cdg_payload = {
  #         "sql_preview": signal.evidence.migration_sql,
  #         "blast_radius": impact.direct_callers_count,
  #         "rollback_strategy": "Re-create column + restore from backup"
  #       }
  #     
  #   signal.evidence.ci_meta = {gitnexus_used, serena_used, freshness_level, behind_commits}
fi
```

**Graceful:** GitNexus absent → skip B3, migration destructive signals giu severity tu B1 (vẫn HIGH/CRITICAL theo bash logic).

## THINK

Bash script implement logic sau:

1. **Migration ordering validation:**
   - Parse file names la timestamp-based (Prisma: 20240101000000_init/)
   - Parse file names la sequential (EF Core: 20240101000000_InitialCreate.cs)
   - Kiem tra gap trong sequence (VD: 20240101000001 -> 20240101000003 -> 20240101000002 bi thieu)
   - Kiem tra duplicate timestamps
   - Kiem tra migration dependencies (Prisma migration_lock.toml)

2. **Up/Down pair validation:**
   - Prisma: chi co migration.sql (up-only) -> canh bao neu thieu down strategy
   - EF Core: Up() va Down() methods -> kiem tra ca 2 methods ton tai
   - Drizzle: up/down exports -> kiem tra ca 2 exports
   - Raw SQL: kiem tra file pair NNNN_name.up.sql / NNNN_name.down.sql

3. **Destructive operations detection:**
   - Grep patterns trong migration content:
     - DROP TABLE / DROP COLUMN khong co confirmation comment
     - DROP SCHEMA, CASCADE, TRUNCATE
     - ALTER COLUMN ... TYPE co the gay data loss (type narrowing)
   - Neu co destructive op -> emit destructive_op signal (severity=critical)
   - Neu destructive op co comment "-- CONFIRMED:" -> giam xuong HIGH

4. **Migration registry sync:**
   - Prisma: kiem tra _prisma_migrations table definition
   - EF Core: kiem tra __EFMigrationsHistory table
   - Kiem tra so luong migration files co khop voi registry entries

5. **Profile-based depth:**
   - quick: Chi kiem tra ordering + destructive ops tren 10 gan nhat
   - standard: Kiem tra ordering + destructive ops + up/down pairs
   - deep: Bo sung registry sync + migration content validation
   - exhaustive: Bo sung kiem tra migration idempotency

6. **Dedup:** fingerprint = sha256(QD6|migration_file|probe_id|integrity_type)

## ACT

Bash script output signals theo schema signal-v2:
- dimension_id: QD6, probe_id: P-QD6-migration-integrity
- signal_type: missing_down | ordering_gap | duplicate_timestamp | destructive_op | registry_mismatch | empty_migration
- severity theo Severity Rules
- fixability: agent_fix | manual_fix
- domain: backend
- evidence[] voi file path, line number, SQL excerpt
- remediation.suggested_action

Sau do SKILL.md emit signals vao signals.json:

```bash
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra moi Signal co evidence voi migration file path
2. Kiem tra destructive_op signals co kem SQL excerpt
3. Kiem tra moi severity dung voi Severity Rules
4. Gap nhung migration van run duoc -> giam severity xuong MEDIUM
5. Destructive_op co comment "-- CONFIRMED:" -> giam CRITICAL xuong HIGH
6. Kiem tra false positive cho DROP TABLE IF EXISTS (safe pattern)

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| DROP TABLE / DROP COLUMN khong co confirmation comment | CRITICAL |
| ALTER COLUMN ... TYPE thu hep kieu du lieu | CRITICAL |
| Destructive operation co comment "-- CONFIRMED:" | HIGH |
| Migration file thieu Down() method / down.sql | HIGH |
| So luong migration files khong khop voi registry | HIGH |
| Gap trong migration sequence (timestamp bi nhay) | MEDIUM |
| Duplicate timestamp giua 2 migration files | MEDIUM |
| Migration file content empty | HIGH |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay migration directory | Skip, note no_migration_directory |
| Migration files khong parse duoc timestamp | Fallback fs sort |
| Tech stack khong ho tro down (Prisma) | Chi canh bao, skip missing_down |
| File permission error | Log WARNING, skip file |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
