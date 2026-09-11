#!/usr/bin/env bash
# scan-target-db.sh — DB entities discovery cho wf-scan-target Phase 2 L4
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/scan-target-db.sh <scan-root> <output-dir> <tech-stack-json>
#
# Output: $output_dir/l4-db.json
#
# Detects:
#   - .NET: DbContext.cs (DbSet<T>) + Domain/Entities/*.cs (properties + relationships)
#   - Prisma: schema.prisma (model X { ... })
#   - TypeORM: *.entity.ts (@Entity decorator)
#   - Drizzle: schema.ts (drizzle table definitions)
#   - Migrations: count Migrations/*.cs or migrations/*.ts
#
# Output JSON shape:
# {
#   "$schema": "scan-target-l4-v1",
#   "generated_at": "...",
#   "scan_root": "...",
#   "total_entities": 25,
#   "migrations_count": 12,
#   "orm": "ef-core",
#   "entities": [
#     {"name": "Customer", "source": "entity_file", "key_fields": ["Id", "Name"], "relationships": ["Orders"]},
#     ...
#   ]
# }

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-db"
# shellcheck source=./scan-target-common.sh
source "$SCRIPTS_DIR/scan-target-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Args ────────────────────────────────────────────────────

SCAN_ROOT="${1:?Usage: $0 <scan-root> <output-dir> <tech-stack-json>}"
OUTPUT_DIR="${2:?Output dir required}"
TECH_JSON="${3:-}"

if [[ ! -d "$SCAN_ROOT" ]]; then
  log_error "Scan root not a directory: $SCAN_ROOT"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
log_info "Scanning DB entities at: $SCAN_ROOT"

# ─── Read tech_stacks ──────────────────────────────────────

declare -a tech_stacks=()
if [[ -n "$TECH_JSON" && -f "$TECH_JSON" && $(has_jq && echo y) == "y" ]]; then
  while IFS= read -r t; do
    [[ -n "$t" ]] && tech_stacks+=("$t")
  done < <(jq -r '.tech_stacks[]?' "$TECH_JSON" 2>/dev/null || echo "")
fi

has_tech() {
  local query="$1"
  for t in "${tech_stacks[@]:-}"; do
    [[ "$t" == *"$query"* ]] && return 0
  done
  return 1
}

# ─── Accumulator ───────────────────────────────────────────

ENTITIES_TMP=$(mktemp)
trap 'rm -f "$ENTITIES_TMP"' EXIT
detected_orm=""
migrations_count=0

emit_entity() {
  local name="$1"
  local source="$2"
  local key_fields_json="${3:-[]}"
  local relationships_json="${4:-[]}"

  if has_jq; then
    jq -nc \
      --arg n "$name" \
      --arg s "$source" \
      --argjson kf "$key_fields_json" \
      --argjson rel "$relationships_json" \
      '{name: $n, source: $s, key_fields: $kf, relationships: $rel}' \
      >> "$ENTITIES_TMP"
  else
    echo "{\"name\":\"$(json_escape "$name")\",\"source\":\"$(json_escape "$source")\",\"key_fields\":$key_fields_json,\"relationships\":$relationships_json}" >> "$ENTITIES_TMP"
  fi
}

# ─── .NET — DbContext + Domain Entities ─────────────────────

if has_tech "dotnet"; then
  log_debug "Scanning .NET entities..."

  # 1) DbContext.cs — DbSet<T>
  declare -A dbcontext_entities
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    detected_orm="ef-core"
    # Extract DbSet<EntityName> Properties = ...
    grep -oE 'DbSet<[A-Z][a-zA-Z0-9_]*>' "$f" 2>/dev/null | while IFS= read -r match; do
      name=$(echo "$match" | sed -E 's/DbSet<([^>]+)>/\1/')
      [[ -n "$name" ]] && echo "$name"
    done
  done < <(find "$SCAN_ROOT" -type f -name '*DbContext.cs' \
              ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | head -10) \
    | sort -u > "$ENTITIES_TMP.dbcontext"

  # 2) Domain/Entities/*.cs — read each, extract properties + relationships
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    name=$(basename "$f" .cs)

    # Extract public properties: public {Type} {PropName} { get; set; }
    # Use || true to handle no-match case without breaking set -e
    key_fields_raw=$({ grep -oE 'public\s+[A-Za-z0-9_<>?]+\s+[A-Z][a-zA-Z0-9_]+\s*\{' "$f" 2>/dev/null || true; } | head -10 | awk '{
      # Get the property name (last token before {)
      for (i=NF; i>=1; i--) if ($i != "{") {print $i; break}
    }')

    # Relationships: ICollection<X>, IEnumerable<X>, IReadOnlyCollection<X>
    rels_raw=$({ grep -oE '(ICollection|IEnumerable|IReadOnlyCollection|List|HashSet)<[A-Z][a-zA-Z0-9_]+>' "$f" 2>/dev/null || true; } | head -10 | sed -E 's/.*<([^>]+)>.*/\1/')

    if has_jq; then
      if [[ -n "$key_fields_raw" ]]; then
        kf_json=$(printf '%s\n' "$key_fields_raw" | grep -v '^$' | head -10 | jq -R . | jq -s . 2>/dev/null)
        [[ -z "$kf_json" ]] && kf_json="[]"
      else
        kf_json="[]"
      fi
      if [[ -n "$rels_raw" ]]; then
        rel_json=$(printf '%s\n' "$rels_raw" | grep -v '^$' | head -10 | jq -R . | jq -s 'unique' 2>/dev/null)
        [[ -z "$rel_json" ]] && rel_json="[]"
      else
        rel_json="[]"
      fi
    else
      kf_json="[]"
      rel_json="[]"
    fi

    emit_entity "$name" "entity_file" "$kf_json" "$rel_json"
  done < <(find "$SCAN_ROOT" -type f -name '*.cs' -path '*/Domain/Entities/*' \
              ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | head -100)

  # 3) Add DbSet entities not already in entity files
  if [[ -s "$ENTITIES_TMP.dbcontext" ]]; then
    while IFS= read -r dbset_name; do
      [[ -z "$dbset_name" ]] && continue
      # Check if already emitted via entity file
      if has_jq && [[ -s "$ENTITIES_TMP" ]]; then
        if jq -s --arg n "$dbset_name" 'any(.name == $n)' "$ENTITIES_TMP" 2>/dev/null | grep -q true; then
          continue
        fi
      fi
      emit_entity "$dbset_name" "dbcontext" "[]" "[]"
    done < "$ENTITIES_TMP.dbcontext"
    rm -f "$ENTITIES_TMP.dbcontext"
  fi

  # 4) Migrations count
  migrations_count=$(find "$SCAN_ROOT" -type f -name '*.cs' -path '*/Migrations/*' \
                      ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | wc -l | tr -d ' ')
  # Filter out designer files (often *.Designer.cs duplicates)
  migrations_actual=$(find "$SCAN_ROOT" -type f -name '*.cs' -path '*/Migrations/*' \
                      ! -name '*.Designer.cs' ! -name 'ModelSnapshot.cs' ! -name '*ModelSnapshot.cs' \
                      ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | wc -l | tr -d ' ')
  [[ "$migrations_actual" -gt 0 ]] && migrations_count="$migrations_actual"
fi

# ─── Prisma ─────────────────────────────────────────────────

prisma_files=$(find "$SCAN_ROOT" -type f -name 'schema.prisma' \
                ! -path '*/node_modules/*' 2>/dev/null | head -5)

if [[ -n "$prisma_files" ]]; then
  detected_orm="prisma"
  log_debug "Scanning Prisma schema..."
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    grep -oE '^model\s+[A-Z][a-zA-Z0-9_]*' "$f" 2>/dev/null | awk '{print $NF}' | while IFS= read -r name; do
      [[ -n "$name" ]] && emit_entity "$name" "prisma" "[]" "[]"
    done
  done <<< "$prisma_files"

  # Prisma migrations
  prisma_migrations=$(find "$SCAN_ROOT" -type d -name 'migrations' \
                      -path '*prisma*' 2>/dev/null | head -1)
  if [[ -n "$prisma_migrations" && -d "$prisma_migrations" ]]; then
    pm_count=$(find "$prisma_migrations" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$pm_count" -gt 0 ]] && migrations_count="$pm_count"
  fi
fi

# ─── TypeORM ────────────────────────────────────────────────

typeorm_files=$(find "$SCAN_ROOT" -type f -name '*.entity.ts' \
                  ! -path '*/node_modules/*' 2>/dev/null | head -100)

if [[ -n "$typeorm_files" ]]; then
  [[ -z "$detected_orm" ]] && detected_orm="typeorm"
  log_debug "Scanning TypeORM entities..."
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # Verify @Entity decorator
    if grep -qE '@Entity\s*\(' "$f" 2>/dev/null; then
      name=$(basename "$f" .entity.ts)
      # Extract @Column properties
      kf_raw=$({ grep -B1 -E '@Column\s*\(' "$f" 2>/dev/null || true; } | { grep -oE '[a-z][a-zA-Z0-9_]+\s*[:?]\s*[A-Za-z]' || true; } | head -10 | sed -E 's/[: ?].*$//')
      if has_jq; then
        if [[ -n "$kf_raw" ]]; then
          kf_json=$(printf '%s\n' "$kf_raw" | grep -v '^$' | head -10 | jq -R . | jq -s . 2>/dev/null)
          [[ -z "$kf_json" ]] && kf_json="[]"
        else
          kf_json="[]"
        fi
      else
        kf_json="[]"
      fi
      emit_entity "$name" "typeorm" "$kf_json" "[]"
    fi
  done <<< "$typeorm_files"
fi

# ─── Drizzle ────────────────────────────────────────────────

drizzle_files=$(find "$SCAN_ROOT" -type f -name 'schema.ts' \
                  -path '*/db/*' ! -path '*/node_modules/*' 2>/dev/null | head -5)
if [[ -z "$drizzle_files" ]]; then
  drizzle_files=$(find "$SCAN_ROOT" -type f \( -name '*.schema.ts' -o -path '*/drizzle/*' \) \
                  ! -path '*/node_modules/*' 2>/dev/null | head -5)
fi

if [[ -n "$drizzle_files" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # Drizzle pattern: export const foo = pgTable("foo", { ... })
    if grep -qE '(pgTable|sqliteTable|mysqlTable)\s*\(' "$f" 2>/dev/null; then
      [[ -z "$detected_orm" ]] && detected_orm="drizzle"
      grep -oE 'export\s+const\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*(pgTable|sqliteTable|mysqlTable)' "$f" 2>/dev/null \
        | awk '{print $3}' | while IFS= read -r name; do
        [[ -n "$name" ]] && emit_entity "$name" "drizzle" "[]" "[]"
      done
    fi
  done <<< "$drizzle_files"
fi

# ─── Build final JSON ──────────────────────────────────────

total_entities=0
entities_json="[]"

if [[ -s "$ENTITIES_TMP" ]] && has_jq; then
  entities_json=$(head -300 "$ENTITIES_TMP" | jq -s 'unique_by(.name) // []')
  total_entities=$(echo "$entities_json" | jq 'length')
fi

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
scan_root_norm=$(normalize_path "$SCAN_ROOT")

if has_jq; then
  output=$(jq -n \
    --arg gen "$generated_at" \
    --arg root "$scan_root_norm" \
    --argjson total "$total_entities" \
    --argjson mig "$migrations_count" \
    --arg orm "$detected_orm" \
    --argjson ents "$entities_json" \
    '{
      "$schema": "scan-target-l4-v1",
      generated_at: $gen,
      scan_root: $root,
      total_entities: $total,
      migrations_count: $mig,
      orm: (if $orm == "" then null else $orm end),
      entities: $ents
    }')
else
  orm_field='null'
  [[ -n "$detected_orm" ]] && orm_field="\"$detected_orm\""
  output=$(cat <<EOF
{
  "\$schema": "scan-target-l4-v1",
  "generated_at": "$generated_at",
  "scan_root": "$(json_escape "$scan_root_norm")",
  "total_entities": $total_entities,
  "migrations_count": $migrations_count,
  "orm": $orm_field,
  "entities": $entities_json
}
EOF
  )
fi

atomic_write_json "$OUTPUT_DIR/l4-db.json" "$output"

log_info "L4 DB: total_entities=$total_entities, migrations=$migrations_count, orm=${detected_orm:-none}"
log_info "Output: $OUTPUT_DIR/l4-db.json"
