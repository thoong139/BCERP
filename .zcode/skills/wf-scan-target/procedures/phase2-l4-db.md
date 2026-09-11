# Phase 2 Layer 4 — Database / Entities Analysis

> **Sprint 3 lazy-load refactor.** Map tất cả data entities, relationships, key fields.
> Skip layer này khi `$scan_depth == "shallow"`.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy PARALLEL với L1/L2/L3 sau `phase1-detect.md` POST-GATE PASS.
Skip nếu `$scan_depth == "shallow"`. Không applicable cho URL targets (trừ khi swagger có schemas).

---

## PRE-GATE

```
- $scan_root set
- $detected_tech_stack non-empty
- $L1_RESULT.key_files set (parallel-safe — entities files đã glob)
- $scan_depth != "shallow"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$scan_root` | Phase 1 | Path để scan |
| `$detected_tech_stack` | Phase 1 | Routing |
| `$target_type` | Phase 0 | URL → swagger schemas |
| `$swagger_data`, `$swagger_available` | Phase 1 | Schema source |
| `$L1_RESULT.key_files["entities"]` | Phase 2 L1 | Entity files đã glob |

## Steps

### Layer 4 — Database / Entities Analysis (Sprint 4 — bash delegation)

> **Token saving:** ~15-40K → ~2K (~95% giảm). Bash extract DbSet<T>, @Entity, Prisma model X
> patterns deterministically — không cần AI inference per-entity.

```bash
SCAN_ROOT="${scan_root:-$target}"
TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"

IF target_type == "local-source":
  # Delegate to bash DB script
  bash .claude/scripts/scan-target-db.sh "$SCAN_ROOT" "$SESSION_DIR/intermediate/" "$TECH_STACK_JSON"

ELIF target_type == "url" AND swagger_available == true:
  # AI-only step — extract schemas từ swagger
  FOR each schema in swagger_data.components.schemas:
    entities.append({name: schema_name, source: "swagger_schema", properties: list_fields(schema)})

  # Save manually as l4-db.json (cùng schema scan-target-l4-v1)
  jq -n --argjson ents "$entities_json" '{
    "$schema": "scan-target-l4-v1",
    generated_at: now | todate,
    scan_root: "'"$target"'",
    total_entities: ($ents | length),
    migrations_count: 0,
    orm: "swagger_schema",
    entities: $ents
  }' > "$SESSION_DIR/intermediate/l4-db.json"

ELSE:
  # URL không swagger → fallback note
  jq -n '{
    "$schema": "scan-target-l4-v1",
    generated_at: now | todate,
    total_entities: 0,
    migrations_count: 0,
    orm: null,
    entities: [{note: "Database entities không trực tiếp accessible từ URL"}]
  }' > "$SESSION_DIR/intermediate/l4-db.json"

# Read result
L4_RESULT_PATH="$SESSION_DIR/intermediate/l4-db.json"

# Sprint 7 PHẦN B — Delta scope filter (chỉ khi $DELTA_MODE == "true" + local-source)
# Filter entities[] theo source_file ∈ changed-files. Skip cho swagger/url.
if [[ "${DELTA_MODE:-false}" == "true" ]] && [[ "$target_type" == "local-source" ]]; then
  CHANGED_JSON="$SESSION_DIR/intermediate/changed-files.json"
  Log: "Delta mode: filtering L4 entities by changed files"

  tmp=$(mktemp)
  jq --slurpfile cf "$CHANGED_JSON" '
    .entities = (.entities // [] | map(
      select(.source_file == null or (.source_file as $sf | $cf[0].files | index($sf) != null))
    )) |
    .total_entities = (.entities | length) |
    .delta_filtered = true
  ' "$L4_RESULT_PATH" > "$tmp" && mv "$tmp" "$L4_RESULT_PATH"
fi

total_entities=$(jq -r '.total_entities' "$L4_RESULT_PATH")
migrations_count=$(jq -r '.migrations_count' "$L4_RESULT_PATH")
detected_orm=$(jq -r '.orm // "none"' "$L4_RESULT_PATH")

Log: "Layer 4 done: total_entities=$total_entities, migrations=$migrations_count, orm=$detected_orm"

save_checkpoint --layer L4 --status completed \
                --intermediate-key l4_result \
                --intermediate-path "intermediate/l4-db.json"
```

> **Reference (logic detail trong bash script):** xem `.claude/scripts/scan-target-db.sh`.
> Detection patterns:
> - **.NET EF Core**: DbContext.cs `DbSet<EntityName>` + Domain/Entities/*.cs (properties + ICollection<X> relationships) + Migrations count (excludes Designer/ModelSnapshot)
> - **Prisma**: schema.prisma `model X { ... }` + prisma/migrations/ count
> - **TypeORM**: *.entity.ts với @Entity decorator, @Column → key_fields
> - **Drizzle**: pgTable/sqliteTable/mysqlTable in schema.ts

### Phase 2 POST-GATE (chạy sau khi cả 4 layers complete)

```
Verify all 4 layers có kết quả (có thể là "not available" nhưng không null):
- L1_RESULT set
- L2_RESULT set
- L3_RESULT set
- L4_RESULT set

save_checkpoint --phase phase_2 --status completed \
                --next-phase phase_3 --next-step build_crud_matrix
```

## POST-GATE

```
- $L4_RESULT set (có thể "not available" nhưng không null)
- test -s $SESSION_DIR/intermediate/l4-db.json
- jq empty $SESSION_DIR/intermediate/l4-db.json
- checkpoint.json: layer_states.L4 == "completed"
- (Phase 2 POST-GATE) checkpoint.json: phase_states.phase_2 == "completed", next_action.phase == "phase_3"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$L4_RESULT` | JSON | total_entities, entities[], migrations_count, orm |

## Next Phase

→ Read `procedures/phase3-synthesis.md`
