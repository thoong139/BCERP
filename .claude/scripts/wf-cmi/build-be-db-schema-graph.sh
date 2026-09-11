#!/usr/bin/env bash
# build-be-db-schema-graph.sh — Build be-db-schema-graph.json (Discovery Plugin #12)
# Part of wf-cmi v2.0 Phase 2 (Stage 2.2 — BE plugin set, close 2 BE graphs)
#
# Usage: bash build-be-db-schema-graph.sh <SESSION_DIR> [SCOPE_ROOT]
#   SESSION_DIR  — Absolute path to session dir (mandatory)
#   SCOPE_ROOT   — Backend root to scan (default: apps/backend)
#
# Output: $SESSION_DIR/phase2-discovery/be-db-schema-graph.json
#
# EF Core ModelSnapshot patterns detected (cumulative schema state):
#   table          : modelBuilder.Entity("FQN", b => { ... b.ToTable("name", "schema"); });
#   column         : b.Property<Type>("Name").HasColumnType("varchar(255)").HasMaxLength(255).IsRequired()
#                    (fluent API spans multiple lines until ;)
#   primary_key    : b.HasKey("Id") or b.HasKey("X", "Y")
#   index          : b.HasIndex("Col") [.IsUnique()] [.HasFilter(...)]
#   foreign_key    : b.HasOne("Other").WithMany().HasForeignKey("OtherId").OnDelete(...)
#
# Strategy v1.0: Primary source = DbContextModelSnapshot.cs (cumulative final schema state)
#                Fallback     = scan migration .cs (CreateTable/AddForeignKey/CreateIndex)
#
# Skip conditions (write empty graph + exit 0):
#   - $SCOPE_ROOT directory does not exist (E137)
#   - No DbContextModelSnapshot.cs AND no migration .cs found
#
# Error codes:
#   E137 — Project KHÔNG có EF Core migrations (skip gracefully)
#   E138 — Parser fail (>20% files unparseable → WARN)
#   E139 — Non-skipped but tables=[] (downstream lane fallback Grep)
#
# Parser version: 1.0 (Python helper for multi-line EF fluent API parsing)
# Upgrade path v2.1: `dotnet ef dbcontext info --json` cho full metadata

set -euo pipefail

SESSION_DIR="${1:?SESSION_DIR mandatory}"
SCOPE_ROOT="${2:-apps/backend}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../../skills/workflow/wf-cmi/templates/be-db-schema-graph.json"
[ -n "${MCV3_CMI_BE_DB_SCHEMA_TPL:-}" ] && TPL="$MCV3_CMI_BE_DB_SCHEMA_TPL"

TARGET="$SESSION_DIR/phase2-discovery/be-db-schema-graph.json"
TMP="$TARGET.tmp.$$"
mkdir -p "$(dirname "$TARGET")"

# Max file size: 16MB (snapshots for enterprise systems can reach 3-10MB)
MAX_FILE_SIZE=16777216

log() { echo "[be-db-schema-graph] $*" >&2; }
die() { log "ERROR: $*"; rm -f "$TMP" "$TARGET".*.tmp.$$ 2>/dev/null || true; exit 1; }

write_skipped_graph() {
  local reason="$1"
  log "SKIP: $reason"
  cat > "$TMP" <<EOF
{
  "\$schema": "be-db-schema-graph-v1",
  "session_id": "${SESSION_ID:-unknown}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scope": {"type": "system", "scope_root": "$SCOPE_ROOT", "migrations_pattern": "**/Migrations/*.cs"},
  "tables": [],
  "edges": [],
  "metadata": {
    "build_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scope_root": "$SCOPE_ROOT",
    "source_method": "skipped",
    "ci_index_freshness": "${CI_FRESHNESS:-unknown}",
    "parser_version": "1.0",
    "migration_count": 0,
    "skipped_files": [],
    "table_count": 0,
    "column_count": 0,
    "fk_count": 0,
    "index_count": 0,
    "unique_constraint_count": 0,
    "edge_count": 0,
    "modules_covered": [],
    "cumulative_view": false,
    "kinds_distribution": {
      "tables": 0,
      "columns": 0,
      "foreign_keys": 0,
      "indexes": 0,
      "unique_constraints": 0
    },
    "last_migration_per_module": {},
    "skipped": true,
    "skip_reason": "$reason"
  }
}
EOF
  jq -e '.' "$TMP" > /dev/null || die "Skipped graph JSON invalid"
  mv "$TMP" "$TARGET"
  log "Wrote skipped graph to $TARGET"
  exit 0
}

# ============================================================================
# Skip detection
# ============================================================================
if [ ! -d "$SCOPE_ROOT" ]; then
  write_skipped_graph "scope_root not found: $SCOPE_ROOT"
fi

SNAPSHOT_FILES=$(find "$SCOPE_ROOT" -type f -name '*ModelSnapshot.cs' 2>/dev/null || true)
MIGRATION_FILES=$(find "$SCOPE_ROOT" -type f -path '*/Migrations/*.cs' \
                  ! -name '*ModelSnapshot.cs' ! -name '*.Designer.cs' 2>/dev/null || true)

if [ -z "$SNAPSHOT_FILES" ] && [ -z "$MIGRATION_FILES" ]; then
  write_skipped_graph "No DbContextModelSnapshot.cs or Migrations/*.cs found under $SCOPE_ROOT"
fi

if [ -n "$SNAPSHOT_FILES" ]; then
  CS_FILES="$SNAPSHOT_FILES"
  PARSE_SOURCE="ef_snapshot"
else
  CS_FILES="$MIGRATION_FILES"
  PARSE_SOURCE="ef_migration_parse"
fi

CS_COUNT=$(echo "$CS_FILES" | grep -c '^' 2>/dev/null || echo 0)
MIGRATION_COUNT=$(echo "$MIGRATION_FILES" | grep -c '^' 2>/dev/null || echo 0)
log "Source method: $PARSE_SOURCE — Found $CS_COUNT primary file(s), $MIGRATION_COUNT migration file(s)"

# ============================================================================
# Template strip
# ============================================================================
if [ ! -f "$TPL" ]; then
  die "Template not found: $TPL"
fi
jq 'del(._template_notes)' "$TPL" > "$TMP" || die "Template strip failed"

# ============================================================================
# Python parser — handles both ef_snapshot and ef_migration_parse
# Outputs JSON lines (one per record) to stdout:
#   {"kind": "table", "module": ..., "name": ..., "schema": ..., "line": ..., "pk": [...], "columns": [...], "indexes": [...]}
#   {"kind": "fk_edge", "module": ..., "from_table": ..., "to_table": ..., "name": ..., "on_delete": ...}
# ============================================================================

PARSER_PY=$(cat <<'PYEOF'
import sys, re, json, os

mode = sys.argv[1]  # 'ef_snapshot' or 'ef_migration_parse'
file_path = sys.argv[2]
module = sys.argv[3]

try:
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
except Exception as e:
    print(json.dumps({"kind": "error", "message": str(e)}), file=sys.stderr)
    sys.exit(1)

lines = content.split('\n')

def parse_snapshot():
    """Parse DbContextModelSnapshot.cs — cumulative final schema state."""
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        m = re.search(r'modelBuilder\.Entity\("([^"]+)"\s*,\s*b\s*=>', line)
        if not m:
            i += 1
            continue
        entity_fqn = m.group(1)
        entity_start = i + 1  # 1-based
        depth = 0
        columns = []
        indexes = []
        pk_cols = []
        table_name = entity_fqn.split('.')[-1]
        schema = None
        fks = []
        # Find opening { of entity block
        j = i
        while j < n and '{' not in lines[j]:
            j += 1
        depth = 1
        j += 1
        block_start = j
        while j < n and depth > 0:
            ln = lines[j]
            # Track braces (rough)
            depth += ln.count('{')
            depth -= ln.count('}')
            if depth <= 0:
                break

            # b.Property<Type>("Name")
            pm = re.search(r'b\.Property<([^>]+)>\("([^"]+)"\)', ln)
            if pm:
                col_type = pm.group(1)
                col_name = pm.group(2)
                nullable = col_type.endswith('?')
                ct = col_type.rstrip('?')
                # Read fluent calls until ;
                fluent = ln
                k = j
                while ';' not in fluent and k < n - 1:
                    k += 1
                    fluent += '\n' + lines[k]
                sql_type = None
                max_len = None
                default_val = None
                is_required = bool(re.search(r'\.IsRequired\(\)', fluent))
                is_identity = bool(re.search(r'\.UseIdentityByDefaultColumn|\.ValueGeneratedOnAdd', fluent))
                stm = re.search(r'\.HasColumnType\("([^"]+)"\)', fluent)
                if stm: sql_type = stm.group(1)
                mlm = re.search(r'\.HasMaxLength\((\d+)\)', fluent)
                if mlm: max_len = int(mlm.group(1))
                dvm = re.search(r'\.HasDefaultValue\(([^)]+)\)', fluent)
                if dvm: default_val = dvm.group(1).strip()
                columns.append({
                    "name": col_name,
                    "sql_type": sql_type,
                    "csharp_type": ct,
                    "nullable": nullable and not is_required,
                    "max_length": max_len,
                    "default_value": default_val,
                    "is_identity": is_identity
                })
                j = k + 1
                continue

            # b.HasKey("Id") or b.HasKey("X", "Y")
            km = re.search(r'b\.HasKey\(([^)]+)\)', ln)
            if km:
                pk_cols = [s.strip().strip('"') for s in km.group(1).split(',')]
                j += 1
                continue

            # b.HasIndex(...) [.IsUnique()] [.HasFilter("...")]
            im = re.search(r'b\.HasIndex\(([^)]+)\)', ln)
            if im:
                cols_raw = im.group(1)
                cols = [s.strip().strip('"').strip("new[]{ }") for s in cols_raw.split(',') if s.strip().strip('"').strip("new[]{ }")]
                # Read fluent until ;
                fluent = ln
                k = j
                while ';' not in fluent and k < n - 1:
                    k += 1
                    fluent += '\n' + lines[k]
                is_unique = bool(re.search(r'\.IsUnique\(\)', fluent))
                ifm = re.search(r'\.HasFilter\("([^"]+)"\)', fluent)
                idx_filter = ifm.group(1) if ifm else None
                idx_name = "IX_" + table_name + "_" + "_".join(cols)
                indexes.append({
                    "name": idx_name,
                    "columns": cols,
                    "is_unique": is_unique,
                    "filter": idx_filter
                })
                j = k + 1
                continue

            # b.ToTable("name") or b.ToTable("name", "schema")
            tm = re.search(r'b\.ToTable\("([^"]+)"(?:\s*,\s*"([^"]+)")?\)', ln)
            if tm:
                table_name = tm.group(1)
                if tm.group(2):
                    schema = tm.group(2)
                j += 1
                continue

            # b.HasOne("FQN").WithMany(...).HasForeignKey("Id").OnDelete(...)
            hom = re.search(r'b\.HasOne\("([^"]+)"\)', ln)
            if hom:
                target_fqn = hom.group(1)
                target_name = target_fqn.split('.')[-1]
                # Look ahead for .HasForeignKey("Col") and .OnDelete(DeleteBehavior.X)
                fluent = ln
                k = j
                while ';' not in fluent and k < n - 1:
                    k += 1
                    fluent += '\n' + lines[k]
                fkm = re.search(r'\.HasForeignKey\("([^"]+)"\)', fluent)
                fk_col = fkm.group(1) if fkm else "FK_Unknown"
                odm = re.search(r'\.OnDelete\(DeleteBehavior\.(\w+)\)', fluent)
                on_delete = odm.group(1) if odm else None
                fks.append({"target": target_name, "column": fk_col, "on_delete": on_delete})
                j = k + 1
                continue

            j += 1

        # Emit table record
        print(json.dumps({
            "kind": "table",
            "module": module,
            "name": table_name,
            "schema": schema,
            "line": entity_start,
            "fqn": entity_fqn,
            "pk": pk_cols,
            "columns": columns,
            "indexes": indexes,
            "fks": fks
        }))
        i = j + 1

def parse_migration():
    """Parse migration .cs Up() method — incremental schema changes."""
    text = '\n'.join(lines)

    # CreateTable(name: "X", columns: table => new { ... }
    for m in re.finditer(r'migrationBuilder\.CreateTable\(\s*name:\s*"([^"]+)"', text):
        tbl_name = m.group(1)
        line_no = text[:m.start()].count('\n') + 1
        # Extract columns from following block (until ); for CreateTable)
        start_idx = m.end()
        # Look for "columns: table => new { ... }"
        cm = re.search(r'columns:\s*table\s*=>\s*new\s*\{(.*?)\}\s*,', text[start_idx:start_idx+8192], re.DOTALL)
        cols = []
        if cm:
            cols_block = cm.group(1)
            for cm2 in re.finditer(r'(\w+)\s*=\s*table\.Column<([^>]+)>\(([^)]*)\)', cols_block):
                col_name = cm2.group(1)
                col_type = cm2.group(2)
                args = cm2.group(3)
                sql_type = None
                nullable = False
                max_len = None
                stm = re.search(r'type:\s*"([^"]+)"', args)
                if stm: sql_type = stm.group(1)
                nm = re.search(r'nullable:\s*(true|false)', args)
                if nm: nullable = (nm.group(1) == 'true')
                mlm = re.search(r'maxLength:\s*(\d+)', args)
                if mlm: max_len = int(mlm.group(1))
                cols.append({
                    "name": col_name, "sql_type": sql_type, "csharp_type": col_type.rstrip('?'),
                    "nullable": nullable, "max_length": max_len, "default_value": None, "is_identity": False
                })
        print(json.dumps({
            "kind": "table", "module": module, "name": tbl_name, "schema": None,
            "line": line_no, "fqn": tbl_name, "pk": [], "columns": cols, "indexes": [], "fks": []
        }))

    # AddForeignKey(name: ..., table: ..., principalTable: ..., onDelete: ...)
    for m in re.finditer(
        r'migrationBuilder\.AddForeignKey\(\s*name:\s*"([^"]+)"[^)]*?table:\s*"([^"]+)"[^)]*?principalTable:\s*"([^"]+)"[^)]*?(?:onDelete:\s*ReferentialAction\.(\w+))?',
        text, re.DOTALL):
        print(json.dumps({
            "kind": "fk_edge", "module": module, "name": m.group(1),
            "from_table": m.group(2), "to_table": m.group(3),
            "on_delete": m.group(4) if m.group(4) else None
        }))

    # CreateIndex(name: ..., table: ..., unique: ...)
    for m in re.finditer(
        r'migrationBuilder\.CreateIndex\(\s*name:\s*"([^"]+)"[^)]*?table:\s*"([^"]+)"(.*?)\);',
        text, re.DOTALL):
        idx_name = m.group(1)
        tbl = m.group(2)
        rest = m.group(3)
        is_unique = bool(re.search(r'unique:\s*true', rest))
        print(json.dumps({
            "kind": "index_only", "module": module, "name": idx_name, "table": tbl, "is_unique": is_unique
        }))

if mode == 'ef_snapshot':
    parse_snapshot()
else:
    parse_migration()
PYEOF
)

# ============================================================================
# Helper: extract module short name from file path
# ============================================================================
extract_module() {
  local fp="$1"
  if [[ "$fp" =~ Eureka\.Modules\.([A-Za-z]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$fp" =~ Eureka\.Migration ]]; then
    echo "Migration"
  elif [[ "$fp" =~ Eureka\.Infrastructure ]]; then
    echo "Infrastructure"
  else
    echo "unknown"
  fi
}

# ============================================================================
# Initialize tmp accumulator files
# ============================================================================
TABLES_TMP="$TARGET.tables.tmp.$$"
EDGES_TMP="$TARGET.edges.tmp.$$"
LAST_MIG_TMP="$TARGET.lastmig.tmp.$$"
SKIPPED_FILES_TMP="$TARGET.skipped.tmp.$$"
PARSER_OUT_TMP="$TARGET.parserout.tmp.$$"
echo "[]" > "$TABLES_TMP"
echo "[]" > "$EDGES_TMP"
echo "{}" > "$LAST_MIG_TMP"
echo "[]" > "$SKIPPED_FILES_TMP"
> "$PARSER_OUT_TMP"

PARSED_FILES=0
SKIPPED_COUNT=0

# ============================================================================
# Loop: invoke Python parser per file → accumulate output
# ============================================================================
while IFS= read -r cs_file; do
  [ -z "$cs_file" ] && continue

  FILE_SIZE=$(wc -c < "$cs_file" 2>/dev/null || echo 0)
  if [ ! -r "$cs_file" ] || [ "$FILE_SIZE" -gt "$MAX_FILE_SIZE" ]; then
    log "WARN: skip unreadable/oversized $cs_file (size=$FILE_SIZE)"
    SKIPPED_FILES_NEW=$(jq --arg f "$cs_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  MODULE=$(extract_module "$cs_file")

  # Track last migration per module
  if [[ "$cs_file" =~ /Migrations/([0-9]+)_([A-Za-z0-9_]+)\.cs$ ]]; then
    MIG_TS="${BASH_REMATCH[1]}"
    MIG_NAME="${BASH_REMATCH[2]}"
    CURR=$(jq -r --arg m "$MODULE" '.[$m] // "0_"' "$LAST_MIG_TMP")
    CURR_TS="${CURR%%_*}"
    if [ "$MIG_TS" \> "$CURR_TS" ]; then
      jq --arg m "$MODULE" --arg v "${MIG_TS}_${MIG_NAME}" '.[$m] = $v' "$LAST_MIG_TMP" > "$LAST_MIG_TMP.next"
      mv "$LAST_MIG_TMP.next" "$LAST_MIG_TMP"
    fi
  fi

  # Run Python parser
  if python3 -c "$PARSER_PY" "$PARSE_SOURCE" "$cs_file" "$MODULE" >> "$PARSER_OUT_TMP" 2>>"$TARGET.parser-err.log"; then
    PARSED_FILES=$((PARSED_FILES + 1))
  else
    log "WARN: parser error for $cs_file (see parser-err.log)"
    SKIPPED_FILES_NEW=$(jq --arg f "$cs_file" '. + [$f]' "$SKIPPED_FILES_TMP")
    echo "$SKIPPED_FILES_NEW" > "$SKIPPED_FILES_TMP"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  fi

done <<< "$CS_FILES"

# ============================================================================
# Aggregate: read PARSER_OUT_TMP, group by kind → tables / edges
# ============================================================================
TOTAL_TABLES=0
TOTAL_COLUMNS=0
TOTAL_FKS=0
TOTAL_INDEXES=0
TOTAL_UNIQUE=0
TOTAL_EDGES=0

# Use jq to bulk-process JSON Lines → tables + edges arrays
if [ -s "$PARSER_OUT_TMP" ]; then
  # Tables
  jq -s '
    [.[] | select(.kind == "table") | {
      id: (.module + "." + .name),
      name: .name,
      module: .module,
      schema: .schema,
      file_path: "",
      line: .line,
      primary_key: {columns: .pk, constraint_name: null},
      columns: .columns,
      indexes: .indexes,
      foreign_keys: [.fks[]? | {name: ("FK_" + .target + "_" + .column), columns: [.column], references_table: .target, references_columns: ["Id"], on_delete: .on_delete, on_update: null}],
      unique_constraints: []
    }]
  ' "$PARSER_OUT_TMP" > "$TABLES_TMP"
  TOTAL_TABLES=$(jq 'length' "$TABLES_TMP")
  TOTAL_COLUMNS=$(jq '[.[].columns | length] | add // 0' "$TABLES_TMP")
  TOTAL_INDEXES=$(jq '[.[].indexes | length] | add // 0' "$TABLES_TMP")
  TOTAL_UNIQUE=$(jq '[.[].indexes[]? | select(.is_unique == true)] | length' "$TABLES_TMP")

  # Edges: FK edges from snapshot-extracted .fks[] + standalone fk_edge records from migration
  jq -s '
    [
      (.[] | select(.kind == "table") | .fks[]? as $f | {
        from_table_id: (.module + "." + .name),
        to_table_id: (.module + "." + $f.target),
        kind: "fk",
        via: $f.column,
        on_delete: $f.on_delete
      }),
      (.[] | select(.kind == "fk_edge") | {
        from_table_id: (.module + "." + .from_table),
        to_table_id: (.module + "." + .to_table),
        kind: "fk",
        via: .name,
        on_delete: .on_delete
      })
    ]
  ' "$PARSER_OUT_TMP" > "$EDGES_TMP"
  TOTAL_EDGES=$(jq 'length' "$EDGES_TMP")
  TOTAL_FKS="$TOTAL_EDGES"
fi

log "Parsed $PARSED_FILES file(s): $TOTAL_TABLES tables / $TOTAL_COLUMNS columns / $TOTAL_FKS FKs / $TOTAL_INDEXES indexes ($TOTAL_UNIQUE unique)"

# Parser fail threshold check (E138)
if [ "$CS_COUNT" -gt 0 ]; then
  FAIL_PCT=$(( SKIPPED_COUNT * 100 / CS_COUNT ))
  if [ "$FAIL_PCT" -gt 20 ]; then
    log "WARN E138: parser skip rate $FAIL_PCT% > 20% threshold"
  fi
fi

# ============================================================================
# Compute modules_covered + kinds_distribution
# ============================================================================
MODULES_COVERED=$(jq '[.[].module] | unique' "$TABLES_TMP")
LAST_MIG=$(cat "$LAST_MIG_TMP")
SKIPPED_JSON=$(cat "$SKIPPED_FILES_TMP")

KINDS_DIST=$(jq -n \
  --argjson t "$TOTAL_TABLES" --argjson c "$TOTAL_COLUMNS" \
  --argjson fk "$TOTAL_FKS" --argjson i "$TOTAL_INDEXES" --argjson u "$TOTAL_UNIQUE" \
  '{tables: $t, columns: $c, foreign_keys: $fk, indexes: $i, unique_constraints: $u}')

# ============================================================================
# Populate target JSON (use --slurpfile for large arrays)
# ============================================================================
log "Populating target $TARGET (cumulative_view=$([ "$PARSE_SOURCE" = "ef_snapshot" ] && echo true || echo false))"

CUMULATIVE=$([ "$PARSE_SOURCE" = "ef_snapshot" ] && echo "true" || echo "false")

jq \
  --arg sid "${SESSION_ID:-unknown}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg src "$PARSE_SOURCE" \
  --arg freshness "${CI_FRESHNESS:-unknown}" \
  --slurpfile tables "$TABLES_TMP" \
  --slurpfile edges "$EDGES_TMP" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson modules "$MODULES_COVERED" \
  --argjson mig_count "$MIGRATION_COUNT" \
  --argjson tbl_count "$TOTAL_TABLES" \
  --argjson col_count "$TOTAL_COLUMNS" \
  --argjson fk_count "$TOTAL_FKS" \
  --argjson idx_count "$TOTAL_INDEXES" \
  --argjson uq_count "$TOTAL_UNIQUE" \
  --argjson edge_count "$TOTAL_EDGES" \
  --argjson kinds "$KINDS_DIST" \
  --argjson lastmig "$LAST_MIG" \
  --argjson cumulative "$CUMULATIVE" \
  '. + {
    session_id: $sid,
    generated_at: $ts,
    tables: $tables[0],
    edges: $edges[0],
    metadata: (.metadata + {
      build_at: $ts,
      source_method: $src,
      ci_index_freshness: $freshness,
      migration_count: $mig_count,
      skipped_files: $skipped,
      table_count: $tbl_count,
      column_count: $col_count,
      fk_count: $fk_count,
      index_count: $idx_count,
      unique_constraint_count: $uq_count,
      edge_count: $edge_count,
      modules_covered: $modules,
      cumulative_view: $cumulative,
      kinds_distribution: $kinds,
      last_migration_per_module: $lastmig
    })
  }' "$TMP" > "$TMP.populated"
mv "$TMP.populated" "$TMP"

# ============================================================================
# Validate + atomic write
# ============================================================================
jq -e '.["$schema"] == "be-db-schema-graph-v1"' "$TMP" > /dev/null \
  || die "Schema validation failed"
jq -e '.tables | type == "array"' "$TMP" > /dev/null \
  || die "tables[] not array"
jq -e '.edges | type == "array"' "$TMP" > /dev/null \
  || die "edges[] not array"

mv "$TMP" "$TARGET"
rm -f "$TABLES_TMP" "$EDGES_TMP" "$LAST_MIG_TMP" "$SKIPPED_FILES_TMP" "$PARSER_OUT_TMP"

log "DONE: $TARGET (tables=$TOTAL_TABLES, columns=$TOTAL_COLUMNS, fks=$TOTAL_FKS, indexes=$TOTAL_INDEXES, modules=$(echo "$MODULES_COVERED" | jq 'length'))"
