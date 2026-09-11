# Phase 2 Layer 1 — File Structure + Code Analysis

> **Sprint 3 lazy-load refactor.** Map toàn bộ file structure, xác định key files theo tech stack.
> Layer 1 LUÔN chạy (kể cả `--depth=shallow`).

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy sau `phase1-detect.md` POST-GATE PASS.
Là layer DUY NHẤT chạy khi `$scan_depth == "shallow"` (skip L2/L3/L4).

---

## PRE-GATE

```
- $scan_root set
- $detected_tech_stack non-empty
- $SESSION_DIR/intermediate/tech-stack.json valid
- checkpoint.json: phase_1 == "completed"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$scan_root` | Phase 1 | Path để scan |
| `$detected_tech_stack` | Phase 1 | Routing logic theo tech |
| `$dotnet_pattern` | Phase 1 | DDD vs standard |

## Steps

### Layer 1 — File Structure + Code Analysis (Sprint 4 — bash delegation)

> **Token saving:** ~5-10K → ~0.5K (~95% giảm). Bash enumerate file tree + glob key files
> theo tech stack — không cần AI per-file inspection.

```bash
SCAN_ROOT="${scan_root:-$target}"
TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"

# Delegate to bash inventory script
bash .claude/scripts/scan-target-inventory.sh "$SCAN_ROOT" "$SESSION_DIR/intermediate/" "$TECH_STACK_JSON"

# Read result into L1_RESULT (in-memory variable cho Phase 3 reference)
L1_RESULT_PATH="$SESSION_DIR/intermediate/l1-structure.json"

# Sprint 7 PHẦN B — Delta scope filter (chỉ khi $DELTA_MODE == "true")
# Filter key_files arrays để chỉ giữ paths có trong intermediate/changed-files.json.
# total_files giữ nguyên (toàn bộ scan_root) để user thấy context, key_files phản ánh delta.
if [[ "${DELTA_MODE:-false}" == "true" ]]; then
  CHANGED_JSON="$SESSION_DIR/intermediate/changed-files.json"
  Log: "Delta mode: filtering L1 key_files by $TOTAL_CHANGED changed files"

  tmp=$(mktemp)
  jq --slurpfile cf "$CHANGED_JSON" '
    .key_files = (.key_files | with_entries(
      .value = (.value | map(select(. as $p | $cf[0].files | index($p) != null)))
    )) | .delta_filtered = true
  ' "$L1_RESULT_PATH" > "$tmp" && mv "$tmp" "$L1_RESULT_PATH"
fi

total_files=$(jq -r '.total_files' "$L1_RESULT_PATH")
key_files_count=$(jq -r '.key_files | keys | length' "$L1_RESULT_PATH")

Log: "Layer 1 done: total_files=$total_files, key_file_groups=$key_files_count"

save_checkpoint --layer L1 --status completed \
                --intermediate-key l1_result \
                --intermediate-path "intermediate/l1-structure.json"
```

> **Reference (logic detail trong bash script):** xem `.claude/scripts/scan-target-inventory.sh`.
> Detection patterns per tech stack:
> - **.NET DDD**: Domain/Entities, Application/Commands+Queries+Validators, Endpoints, value_objects
> - **Next.js**: pages (App Router page.tsx + Pages Router pages/), layouts, components, hooks, stores, api_routes
> - **React Native**: screens, expo_screens, components
> - **Vue**: pages_vue, components_vue
> - **Hono/Express**: routes (route files trong /routes/)

## POST-GATE

```
- $L1_RESULT set với .total_files, .key_files
- test -s $SESSION_DIR/intermediate/l1-structure.json
- jq empty $SESSION_DIR/intermediate/l1-structure.json
- checkpoint.json: layer_states.L1 == "completed"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$L1_RESULT` | JSON | total_files, file_counts_by_ext, dir_structure, key_files |

## Next Phase

- IF `$scan_depth == "shallow"` → SKIP L2/L3/L4 → Read `procedures/phase3-synthesis.md`
- ELSE → PARALLEL: Read `procedures/phase2-l2-api.md`, `phase2-l3-ui.md`, `phase2-l4-db.md`
