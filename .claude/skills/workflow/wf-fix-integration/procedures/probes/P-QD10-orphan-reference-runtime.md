# P-QD10-orphan-reference-runtime — Kiem tra Orphan FK References qua DB Query

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD10-orphan-reference-runtime |
| **Loai** | runtime |
| **Profile** | deep, exhaustive |
| **Muc dich** | Kiem tra cac foreign key references thuc te trong DB co bi orphan hay khong: consumer row co fk_field trỏ toi provider.id khong ton tai. Doc cross_module_dependencies[] WHERE binding_type=foreign_key, thuc hien LEFT JOIN query voi sample limit 1000, timeout 30s. Chi dung READ-ONLY connection, tu choi production env (E104 block). |
| **Cache** | NOT allowed (runtime DB query — ket qua thay doi theo data) |
| **Error codes** | E100 (registry corrupt — QD10 base), E104 (production env block — safety critical), E108 (DB connection fail), E109 (DB query timeout) |
| **Migrates from** | (new in v9) |

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| DB query template (READ-ONLY, timeout, sampling) | `QD6 P-QD6-constraint-violation.md` | `:25-42 (SENSE B1 bash delegate)` | Reuse pattern delegate-to-bash + error handling. Thay JOIN logic: LEFT JOIN WHERE provider.id IS NULL. Giu nguyen: timeout 30s, sample 1000, READ-ONLY verify. |
| Production env detection | `QD6 P-QD6-constraint-violation.md` | `:THINK 5 (profile-based depth)` | Reuse env var detection pattern. W3.1 nang cap len E104 hard-block (khong chi profile-based). |
| iterate_module_pairs() + binding_type filter | `procedures/probes/_shared.md` (QD10) | `:139-160` | Reuse pair iteration; filter WHERE binding_type=foreign_key |
| emit_signal_cross_module() + dedup_key | `procedures/probes/_shared.md` (QD10) | `:42-92` | Signal emit voi provider/consumer context |
| sampling / emit_sampling_note | `procedures/probes/_shared.md` (QD10) | `:183-191` | Document sampling khi pairs > threshold |
| with_runtime_cap timeout wrapper | `.claude/scripts/wf-fix-common.sh` | `:with_runtime_cap` | Enforced timeout 30s (KHONG hardcode) |
| jq_int JSON helper | `.claude/scripts/wf-fix-common.sh` | `:jq_int` | CRLF-safe JSON int extraction |

**Diff so voi QD6 constraint-violation:**
- QD6: kiem tra schema/ORM (static file analysis, constraint declarations)
- W3.1: kiem tra DATA thuc te trong DB (runtime LEFT JOIN query, orphan rows)
- Safety level cao hon: QD6 la static (khong co side effect); W3.1 can DB connection → E104 production block bat buoc
- Khong dung CI tool (GitNexus/Serena) — probe nay la pure runtime DB, khong can code analysis
- Signal context: orphan row count, sample IDs, FK field name (thay vi ORM file path)

---

## CI-ROUTE

**P-QD10-orphan-reference-runtime la pure runtime DB probe — KHONG can CI tool.**

Per [03-reuse-ci-parallelism.md §3.3]: `P-QD10-orphan-reference-runtime` → no CI tool (pure runtime DB).

| Task | CI Tool | Fallback | Purpose |
|------|---------|----------|---------|
| Tim provider/consumer table names | — | Parse entity name tu cross_module_deps: "Customer" → "customers" (snake_case plural) | Hurisitc table name mapping: `{entity.toLowerCase()}s` |
| Tim FK column name | — | Parse required_fields[0] (thong thuong la "id" tu provider) + naming convention `{entity_lower}_id` | Heuristic: `customer_id`, `order_id`, etc. |

**Khong co CI tool fallback can thiet.** Probe chay duoc hoat toan qua DB connection + registry data.

---

## PRE-GATE

```
1. IF profile=quick OR profile=standard:
     SKIP probe (W3.1 chi chay deep+ — runtime probes)
     LOG "INFO: P-QD10-orphan-reference-runtime skipped (profile=${PROFILE}, requires deep+)"
     → exit 0

2. CRITICAL SAFETY CHECK (E104 — BẮT BUỘC, khong bypass):
     ENV_NAME=$(printenv DB_ENV || printenv NODE_ENV || printenv APP_ENV || echo "")
     IF [ "$ENV_NAME" = "production" ] OR [ "$ENV_NAME" = "prod" ]:
       ERROR "E104: BLOCKED — Probe P-QD10-orphan-reference-runtime tu choi chay tren production env."
       ERROR "E104: DB_ENV/NODE_ENV/APP_ENV = '${ENV_NAME}'. De chay probe nay, set env=development hoac staging."
       → exit 1 (hard block — khong graceful skip)
     # Neu khong co env var hoac env != production → tiep tuc

3. Kiem tra --db-url flag:
     IF [ -z "${DB_URL:-}" ]:
       SKIP probe, ghi note "skipped_db_credentials_required"
       LOG "INFO: P-QD10-orphan-reference-runtime requires --db-url parameter."
       LOG "INFO: De chay probe nay, truyen: --db-url='postgresql://user:pass@host/db'"
       LOG "INFO: Q7 (DB credentials) chua duoc cau hinh — skip gracefully."
       → emit skip_note + exit 0 (khong phai error)

4. Kiem tra co cross_module_dependencies[] voi binding_type=foreign_key:
     FK_DEP_COUNT=$(jq '
       [.cross_module_dependencies // [] | .[] |
        select(.binding_type == "foreign_key")]
       | length' "$REGISTRY_FILE")
     IF FK_DEP_COUNT == 0:
       SKIP probe, ghi note "skipped_no_fk_dependencies"
       LOG "WARN: QD10 orphan-reference-runtime requires cross_module_dependencies[] with binding_type=foreign_key."
       LOG "WARN: Add entries via wf-detect-cross-module-deps.sh (W2.6) + author registry."
       → exit 0

5. Validate DB_URL format:
     DB_DIALECT=$(echo "$DB_URL" | grep -oE '^(postgresql|postgres|mysql|sqlite|mssql|mariadb)' || echo "")
     IF [ -z "$DB_DIALECT" ]:
       ERROR "E108: DB_URL format khong duoc ho tro. Expected prefix: postgresql://, mysql://, sqlite://, mssql://"
       → exit 1

6. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"

7. Test DB connection (30s timeout):
     IF ! with_runtime_cap 30 bash -c 'echo "SELECT 1" | db_query_readonly "$DB_URL"' > /dev/null 2>&1:
       ERROR "E108: Khong ket noi duoc DB tai $DB_URL (timeout 30s). Kiem tra DB running va credentials."
       → exit 1
```

---

## SENSE

### S1: Load FK Dependencies

```bash
# Doc tat ca FK pairs tu registry
# REUSE: _shared.md:139-160 iterate_module_pairs() adapted — filter binding_type=foreign_key

ALL_FK_DEPS=$(jq -r '
  .cross_module_dependencies // [] | .[] |
  select(.binding_type == "foreign_key") |
  [
    .consumer_module,
    .provider_module,
    .entity,
    (.required_fields // ["id"] | join(",")),
    (.optional_fields // [] | join(","))
  ] | @tsv
' "$REGISTRY_FILE")

TOTAL_FK_COUNT=$(echo "$ALL_FK_DEPS" | grep -c . || echo 0)

# Apply --pair filter neu co
if [ -n "${PAIR_FILTER:-}" ]; then
  ALL_FK_DEPS=$(echo "$ALL_FK_DEPS" | awk -F'\t' -v pair="$PAIR_FILTER" \
    'BEGIN{split(pair,p,"-")} ($1==p[1] && $2==p[2]) || ($1==p[2] && $2==p[1]) {print}')
fi

PAIRS_TO_CHECK=$(echo "$ALL_FK_DEPS" | grep -c . || echo 0)
LOG "INFO: Found $TOTAL_FK_COUNT FK dependencies ($PAIRS_TO_CHECK after filter)" >&2
```

### S2: Detect DB Dialect va Table Name Heuristics

```bash
# DB dialect tu URL prefix (da detect o PRE-GATE)
DB_DIALECT="${DB_DIALECT:-postgresql}"

# Heuristic: entity "Customer" → table "customers" (snake_case plural)
map_entity_to_table() {
  local entity="$1"
  # 1. lowercase
  # 2. plural (naive: them 's')
  # 3. xem xet: Person → people (edge case, hientai skip — dung generic s)
  echo "$entity" | awk '{print tolower($0) "s"}'
}

# Heuristic: provider entity "Customer", consumer required_fields include provider "id"
# → FK column trong consumer = "{entity_lower}_id"
map_entity_to_fk_column() {
  local entity="$1"
  echo "${entity,,}_id"
}

LOG "INFO: DB dialect: $DB_DIALECT — table naming heuristic: entity_lower + 's'" >&2
```

### S3: Sampling Decision

```bash
# Per Section 6.3 guidance: Tables > 1000 rows → sample 1000
# Probe nay: sample 1000 orphan rows per pair (LIMIT 1000 trong query)
SAMPLE_LIMIT=1000
MAX_PAIRS=30  # Sampling: neu pairs > 30, uu tien pairs CRITICAL truoc

if [ "$PAIRS_TO_CHECK" -gt "$MAX_PAIRS" ]; then
  emit_sampling_note "P-QD10-orphan-reference-runtime" "$PAIRS_TO_CHECK" "$MAX_PAIRS"
  LOG "INFO: pairs>$MAX_PAIRS, sampling first $MAX_PAIRS (insertion order)" >&2
  ALL_FK_DEPS=$(echo "$ALL_FK_DEPS" | head -"$MAX_PAIRS")
  PAIRS_TO_CHECK=$MAX_PAIRS
fi
```

---

## THINK

```bash
# Xay dung LEFT JOIN query template per dialect
# REUSE QD6 P-QD6-constraint-violation.md DB query pattern — thay JOIN logic

build_orphan_query() {
  local consumer_table="$1"
  local provider_table="$2"
  local fk_column="$3"
  local sample_limit="$4"
  local dialect="$5"

  # READ-ONLY LEFT JOIN query: tim consumer rows co FK trỏ toi provider khong ton tai
  # Khong co DDL, khong co UPDATE/DELETE/INSERT
  case "$dialect" in
    postgresql|postgres)
      echo "
        SELECT
          c.id        AS consumer_id,
          c.${fk_column} AS fk_value
        FROM ${consumer_table} c
        LEFT JOIN ${provider_table} p ON c.${fk_column} = p.id
        WHERE p.id IS NULL
          AND c.${fk_column} IS NOT NULL
        LIMIT ${sample_limit};
      "
      ;;
    mysql|mariadb)
      echo "
        SELECT
          c.id        AS consumer_id,
          c.\`${fk_column}\` AS fk_value
        FROM \`${consumer_table}\` c
        LEFT JOIN \`${provider_table}\` p ON c.\`${fk_column}\` = p.id
        WHERE p.id IS NULL
          AND c.\`${fk_column}\` IS NOT NULL
        LIMIT ${sample_limit};
      "
      ;;
    sqlite)
      echo "
        SELECT
          c.id        AS consumer_id,
          c.\"${fk_column}\" AS fk_value
        FROM \"${consumer_table}\" c
        LEFT JOIN \"${provider_table}\" p ON c.\"${fk_column}\" = p.id
        WHERE p.id IS NULL
          AND c.\"${fk_column}\" IS NOT NULL
        LIMIT ${sample_limit};
      "
      ;;
    mssql)
      echo "
        SELECT TOP ${sample_limit}
          c.id        AS consumer_id,
          c.[${fk_column}] AS fk_value
        FROM [${consumer_table}] c
        LEFT JOIN [${provider_table}] p ON c.[${fk_column}] = p.id
        WHERE p.id IS NULL
          AND c.[${fk_column}] IS NOT NULL;
      "
      ;;
    *)
      # Generic fallback — PostgreSQL syntax
      echo "
        SELECT c.id, c.${fk_column}
        FROM ${consumer_table} c
        LEFT JOIN ${provider_table} p ON c.${fk_column} = p.id
        WHERE p.id IS NULL AND c.${fk_column} IS NOT NULL
        LIMIT ${sample_limit};
      "
      ;;
  esac
}

LOG "INFO: THINK: Query template ready (dialect=$DB_DIALECT, sample_limit=$SAMPLE_LIMIT)" >&2
```

---

## ACT

### A1: Per-Pair Orphan Detection

```bash
# Moi pair: 1 LEFT JOIN query, timeout 30s (REUSE: with_runtime_cap tu wf-fix-common.sh)
# Parallel class: RUNTIME → chay SEQUENTIAL (Section 4.3 — DB connection limit, singleton)

SIGNAL_COUNT=0
MAX_SIGNALS=100
PAIRS_ANALYZED=0
PAIRS_CLEAN=0
PAIRS_ORPHANED=0
PAIRS_ERROR=0

while IFS=$'\t' read -r consumer_module provider_module entity required_fields_csv _optional; do
  [ -z "$consumer_module" ] && continue
  [ "$SIGNAL_COUNT" -ge "$MAX_SIGNALS" ] && {
    LOG "WARN: max_signals_reached ($MAX_SIGNALS), stopping" >&2
    break
  }

  PAIRS_ANALYZED=$((PAIRS_ANALYZED + 1))

  # Map entity → table name heuristics
  CONSUMER_TABLE=$(map_entity_to_table "$consumer_module" | sed 's/mod-//')
  PROVIDER_TABLE=$(map_entity_to_table "$entity")
  FK_COLUMN=$(map_entity_to_fk_column "$entity")

  # Build query
  QUERY=$(build_orphan_query "$CONSUMER_TABLE" "$PROVIDER_TABLE" "$FK_COLUMN" "$SAMPLE_LIMIT" "$DB_DIALECT")

  RAW_RESULT_FILE="$RAW_DIR/P-QD10-orphan-reference-runtime-${consumer_module}-${provider_module}.json"

  # Execute query voi timeout 30s (E109 khi timeout)
  # CRITICAL: chi dung READ-ONLY connection wrapper
  # db_query_readonly: bash wrapper mo connection bang psql/mysql/sqlite3 tren $DB_URL
  # Chi SELECT, khong co DDL, rollback-safe, connection closed sau query
  QUERY_OK=false
  ORPHAN_COUNT=0
  ORPHAN_SAMPLE_IDS=""

  if with_runtime_cap 30 db_query_readonly "$DB_URL" "$QUERY" > "$RAW_RESULT_FILE.tsv" 2>"$RAW_RESULT_FILE.err"; then
    QUERY_OK=true
    ORPHAN_COUNT=$(wc -l < "$RAW_RESULT_FILE.tsv" | tr -d '[:space:]' || echo 0)
    # Lay sample IDs (toi da 5) de lam evidence
    ORPHAN_SAMPLE_IDS=$(head -5 "$RAW_RESULT_FILE.tsv" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
  else
    QUERY_EXIT=$?
    if [ "$QUERY_EXIT" -eq 124 ]; then
      # Timeout (with_runtime_cap exit code 124)
      LOG "WARN: E109: Query timeout (30s) cho pair ${consumer_module}→${provider_module}" >&2
      PAIRS_ERROR=$((PAIRS_ERROR + 1))
    else
      LOG "WARN: E108: DB query fail cho pair ${consumer_module}→${provider_module}: $(cat $RAW_RESULT_FILE.err)" >&2
      PAIRS_ERROR=$((PAIRS_ERROR + 1))
    fi
    continue
  fi

  # --- Emit signals ---
  if [ "$ORPHAN_COUNT" -gt 0 ]; then
    PAIRS_ORPHANED=$((PAIRS_ORPHANED + 1))
    [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ] && {
      emit_signal_cross_module \
        "P-QD10-orphan-reference-runtime" \
        "orphan_reference_detected" \
        "high" \
        "Orphan FK references: ${ORPHAN_COUNT} rows trong ${consumer_module} tro den ${provider_module}.${entity} khong ton tai" \
        "${ORPHAN_COUNT} row(s) trong consumer table '${CONSUMER_TABLE}' co ${FK_COLUMN} trỏ toi ${PROVIDER_TABLE}.id khong ton tai trong DB. Day la orphan FK references — data inconsistency co the dan den runtime errors (500), lookup failures, hoac silent data corruption. Sample consumer IDs: ${ORPHAN_SAMPLE_IDS}." \
        "$provider_module" \
        "$consumer_module" \
        "db_query_result" \
        "consumer_table=${CONSUMER_TABLE} provider_table=${PROVIDER_TABLE} fk_column=${FK_COLUMN} orphan_count=${ORPHAN_COUNT} sample_ids=${ORPHAN_SAMPLE_IDS} dialect=${DB_DIALECT} query_timeout_30s=true sample_limit=${SAMPLE_LIMIT}"
      SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
      LOG "INFO: Signal orphan_reference_detected: ${consumer_module}→${provider_module} orphan_count=${ORPHAN_COUNT}" >&2
    }
  else
    PAIRS_CLEAN=$((PAIRS_CLEAN + 1))
    LOG "INFO: PASS: ${consumer_module}→${provider_module} FK integrity OK (0 orphans)" >&2
  fi

done <<< "$ALL_FK_DEPS"
```

### A2: FK Field Name Mismatch Check (MEDIUM signal)

```bash
# cross_module_fk_mismatch: khi FK column khai bao trong required_fields[]
# KHONG khop voi naming convention hoac khong ton tai trong consumer table schema
# DB dialect: query INFORMATION_SCHEMA.COLUMNS (supported: postgresql, mysql, mssql)

if [[ "$DB_DIALECT" != "sqlite" ]]; then
  while IFS=$'\t' read -r consumer_module provider_module entity required_fields_csv _optional; do
    [ -z "$consumer_module" ] && continue

    CONSUMER_TABLE=$(map_entity_to_table "$consumer_module" | sed 's/mod-//')
    FK_COLUMN=$(map_entity_to_fk_column "$entity")

    # Query INFORMATION_SCHEMA de kiem tra FK column ton tai
    SCHEMA_QUERY="
      SELECT column_name
      FROM information_schema.columns
      WHERE LOWER(table_name) = LOWER('${CONSUMER_TABLE}')
        AND LOWER(column_name) = LOWER('${FK_COLUMN}')
      LIMIT 1;
    "

    SCHEMA_RESULT=""
    if with_runtime_cap 30 db_query_readonly "$DB_URL" "$SCHEMA_QUERY" > /tmp/schema_check.tsv 2>/dev/null; then
      SCHEMA_RESULT=$(cat /tmp/schema_check.tsv | tr -d '[:space:]')
    fi

    if [ -z "$SCHEMA_RESULT" ]; then
      # FK column khong ton tai → cross_module_fk_mismatch
      [ "$SIGNAL_COUNT" -lt "$MAX_SIGNALS" ] && {
        emit_signal_cross_module \
          "P-QD10-orphan-reference-runtime" \
          "cross_module_fk_mismatch" \
          "medium" \
          "FK column khong tim thay trong schema: ${CONSUMER_TABLE}.${FK_COLUMN} (entity=${entity})" \
          "cross_module_dependency khai bao binding_type=foreign_key cho pair ${consumer_module}→${provider_module} (entity=${entity}), nhung column '${FK_COLUMN}' khong tim thay trong information_schema cua table '${CONSUMER_TABLE}'. Co the: (1) Ten column khac naming convention (khong phai snake_case); (2) Table ten khac; (3) Dependency chua duoc implement." \
          "$provider_module" \
          "$consumer_module" \
          "schema_diff" \
          "consumer_table=${CONSUMER_TABLE} expected_fk_column=${FK_COLUMN} entity=${entity} check=information_schema"
        SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
        LOG "INFO: Signal cross_module_fk_mismatch: ${consumer_module}.${FK_COLUMN} khong ton tai" >&2
      }
    fi

  done <<< "$ALL_FK_DEPS"
fi
```

### A3: Write Summary JSON

```bash
jq -n \
  --arg probe_id "P-QD10-orphan-reference-runtime" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg dialect "$DB_DIALECT" \
  --argjson pairs_total "$TOTAL_FK_COUNT" \
  --argjson pairs_analyzed "$PAIRS_ANALYZED" \
  --argjson pairs_clean "$PAIRS_CLEAN" \
  --argjson pairs_orphaned "$PAIRS_ORPHANED" \
  --argjson pairs_error "$PAIRS_ERROR" \
  --argjson signals "$SIGNAL_COUNT" \
  --argjson sample_limit "$SAMPLE_LIMIT" \
  '{
    probe_id: $probe_id,
    generated_at: $now,
    db_dialect: $dialect,
    pairs_total: $pairs_total,
    pairs_analyzed: $pairs_analyzed,
    pairs_clean: $pairs_clean,
    pairs_orphaned: $pairs_orphaned,
    pairs_error: $pairs_error,
    signals_emitted: $signals,
    sample_limit: $sample_limit,
    sampling: {total: $pairs_total, analyzed: $pairs_analyzed}
  }' > "$RAW_DIR/P-QD10-orphan-reference-runtime-summary.json" 2>/dev/null || \
  LOG "WARN: summary.json write failed — khong block" >&2

LOG "INFO: Orphan reference probe complete (pairs_analyzed=$PAIRS_ANALYZED, orphaned=$PAIRS_ORPHANED, error=$PAIRS_ERROR, signals=$SIGNAL_COUNT)" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-orphan-reference-runtime"
2. Kiem tra moi signal co signal_type trong ["orphan_reference_detected", "cross_module_fk_mismatch"]
3. Kiem tra moi orphan_reference_detected signal co:
   - orphan_count trong evidence[] > 0
   - consumer_table, provider_table, fk_column trong evidence content
4. Kiem tra severity mapping:
   - orphan_reference_detected → high
   - cross_module_fk_mismatch → medium
5. Kiem tra khong co DDL statements trong query_log (KHONG co CREATE/ALTER/DROP/UPDATE/DELETE)
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra env != production (E104) da duoc enforce truoc khi query bat ky
8. Kiem tra summary JSON ton tai trong RAW_DIR voi pairs_analyzed >= 0
9. Kiem tra dedup_key format:
   - orphan_reference_detected → "P-QD10-orphan-reference-runtime:orphan_reference_detected:{consumer_module}:{provider_module}"
   - cross_module_fk_mismatch → "P-QD10-orphan-reference-runtime:cross_module_fk_mismatch:{consumer_module}:{fk_column}"
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Consumer rows co FK trỏ toi provider.id khong ton tai (orphan) | **HIGH** | Orphan FK → runtime 500 errors khi lookup provider (vd: customer not found), data corruption an, business logic sai tren invalid references. Tuong tu constraint violation (QD6 HIGH) nhung la DATA-level, khong phai schema-level. |
| FK column khai bao trong registry khong ton tai trong DB schema | **MEDIUM** | Co the: dependency chua implement, naming mismatch, schema out-of-sync voi registry. Can developer confirm — khong phai guaranteed orphan (co the ten khac). MEDIUM phu hop: can review, khong block immediate. |

> **Rationale HIGH cho orphan_reference_detected:**
> Khi consumer code thuc hien `provider.findById(consumer.fk_field)`, ket qua la `null` hoac throw exception.
> Voi FK referential integrity bi vi pham o DATA layer (khong co DB constraint), dat biet nguy hiem vi:
> (1) Khong co DB-level guard → orphan row ton tai im lang;
> (2) Bug chi hien o runtime khi code access provider data;
> (3) Kho reproduce — chi xay ra voi specific orphan rows.

> **Rationale MEDIUM cho cross_module_fk_mismatch:**
> Column khong tim thay trong information_schema co the la do naming convention khac
> (vd: `cust_id` thay vi `customer_id`). Khong phai guaranteed bug — developer can confirm.
> MEDIUM phu hop: FLAG + review, khong block.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `orphan_reference_detected` | `P-QD10-orphan-reference-runtime:orphan_reference_detected:{consumer_module}:{provider_module}` |
| `cross_module_fk_mismatch` | `P-QD10-orphan-reference-runtime:cross_module_fk_mismatch:{consumer_module}:{fk_column}` |

**Luu y:** 1 signal per pair. Chay lai probe tren cung pair → dedup by key (idempotent).

---

## Signal Schema Examples

### orphan_reference_detected

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-orphan-reference-runtime",
  "dimension_id": "QD10",
  "signal_type": "orphan_reference_detected",
  "severity": "high",
  "title": "Orphan FK references: 37 rows trong MOD-QUOTATION tro den MOD-CRM.Customer khong ton tai",
  "description": "37 row(s) trong consumer table 'quotations' co customer_id trỏ toi customers.id khong ton tai trong DB. Day la orphan FK references — data inconsistency co the dan den runtime errors (500), lookup failures, hoac silent data corruption. Sample consumer IDs: 1042,1087,1091,1102,1199.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-QUOTATION",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {
      "type": "db_query_result",
      "content": "consumer_table=quotations provider_table=customers fk_column=customer_id orphan_count=37 sample_ids=1042,1087,1091,1102,1199 dialect=postgresql query_timeout_30s=true sample_limit=1000"
    }
  ],
  "dedup_key": "P-QD10-orphan-reference-runtime:orphan_reference_detected:MOD-QUOTATION:MOD-CRM"
}
```

### cross_module_fk_mismatch

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-orphan-reference-runtime",
  "dimension_id": "QD10",
  "signal_type": "cross_module_fk_mismatch",
  "severity": "medium",
  "title": "FK column khong tim thay trong schema: orders.customer_id (entity=Customer)",
  "description": "cross_module_dependency khai bao binding_type=foreign_key cho pair MOD-ORDERS→MOD-CRM (entity=Customer), nhung column 'customer_id' khong tim thay trong information_schema cua table 'orders'. Co the: (1) Ten column khac naming convention; (2) Table ten khac; (3) Dependency chua duoc implement.",
  "location": {
    "provider_module": "MOD-CRM",
    "consumer_module": "MOD-ORDERS",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {
      "type": "schema_diff",
      "content": "consumer_table=orders expected_fk_column=customer_id entity=Customer check=information_schema"
    }
  ],
  "dedup_key": "P-QD10-orphan-reference-runtime:cross_module_fk_mismatch:MOD-ORDERS:customer_id"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile=quick hoac standard | SKIP probe (runtime probe chi deep+) → exit 0 |
| env==production | **HARD BLOCK E104** → exit 1 (khong graceful skip) |
| --db-url khong duoc truyen | SKIP gracefully — note "skipped_db_credentials_required" → exit 0 |
| DB URL format khong ho tro | ERROR E108 → exit 1 |
| Khong ket noi duoc DB | ERROR E108 → exit 1 |
| Query timeout (30s) | WARN E109, skip pair do, tiep tuc pair khac |
| binding_type=foreign_key = 0 trong registry | SKIP — note "skipped_no_fk_dependencies" → exit 0 |
| Table khong ton tai trong DB (query error) | WARN + skip pair, ghi note "table_not_found:${TABLE}" → tiep tuc |
| SQLite dialect | Skip A2 (information_schema khong co) — chi chay A1 orphan check |
| pairs > 30 | Sampling: analyze first 30, emit_sampling_note |
| Orphan count = 0 | PASS — khong emit signal |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| Registry parse error (jq fail) | ERROR E100 + exit 1 |

---

## Cache Policy

**NOT allowed** — probe nay la runtime DB query.

Ket qua phu thuoc DATA trong DB tai thoi diem chay — khong the cache.
Moi lan chay probe co the cho ket qua khac neu data thay doi.

Khac voi static probes (QD10 W2.2-W2.4): khong co cache layer nao duoc ap dung.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-orphan-reference-runtime:
  quick: skip
  standard: skip
  deep: run (orphan_detection + fk_mismatch_check khi DB_URL set)
  exhaustive: run (same as deep — khong co extra check, data-level probe)
  parallel_class: runtime
  optional: true (require --db-url, skip gracefully khi khong co)
  max_pairs: 30
  requires_flags: ["--db-url"]
  safety_critical: true
  production_block: E104
```

---

## Acceptance Test

**Synthetic test (W3.1 DoD):**

1. Setup registry voi cross_module_dependency binding_type=foreign_key:
   ```json
   {
     "cross_module_dependencies": [{
       "id": "CMD-QUOTATION-CRM-001",
       "consumer_module": "MOD-QUOTATION",
       "provider_module": "MOD-CRM",
       "entity": "Customer",
       "binding_type": "foreign_key",
       "required_fields": ["id", "name", "code"]
     }]
   }
   ```
2. Setup dev DB (SQLite hoac PostgreSQL dev): Insert quotation row voi `customer_id=9999` (khong ton tai trong `customers` table)
3. Set env: `export DB_ENV=development DB_URL=postgresql://localhost/test_db`
4. Run probe voi `--profile=deep --db-url=$DB_URL`
5. **Expected:**
   - Signal `orphan_reference_detected` (severity=HIGH) voi orphan_count >= 1
   - Sample IDs include row co customer_id=9999
   - Summary JSON: pairs_orphaned=1, signals_emitted=1
6. Verify: `jq 'select(.signal_type == "orphan_reference_detected")' "$SIGNALS_FILE"` → 1 result

**Production block test:**
- Set `DB_ENV=production` → probe phai exit 1 voi "E104: BLOCKED"
- Khong co query nao duoc thuc hien

**Skip test (no --db-url):**
- Chay probe khong co --db-url flag → exit 0 voi note "skipped_db_credentials_required"

**EUREKA acceptance (W3.E2E — deferred, Q7):**
- Sau khi Q7 (DB credentials) duoc cau hinh
- Run `/wf-fix-bugs --dims=QD10 --profile=deep --scope=cross-module-pair --pair=CRM-QUOTATION --db-url=...`
- Expect: Probe complete; signals hoac PASS ro; performance <= 2 phut per pair

**Luu y:** W3.E2E acceptance test bi defer cho toi khi Q7 DB credentials duoc user cung cap.
Probe procedure nay da san sang khi credentials co san.
