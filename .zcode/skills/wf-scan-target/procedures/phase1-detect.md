# Phase 1 — Target Analysis (Tech Stack Detection)

> **Sprint 3 lazy-load refactor.** Phát hiện tech stack, cấu trúc high-level, resolve module name,
> tính target_fingerprint composite.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`compute_fingerprint`, `save_checkpoint`)

## Load Condition

Chạy sau `phase0-setup.md` POST-GATE PASS, hoặc khi `--resume` route đến `phase_1`.

---

## PRE-GATE

```
- $target set, $target_type set
- $SESSION_DIR exists, $SESSION_DIR/scan-status.json valid
- $SESSION_DIR/checkpoint.json valid
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$target`, `$target_type` | Phase 0 | |
| `$module_name`, `$scan_depth` | Phase 0 | |
| `$SESSION_ID`, `$SESSION_DIR` | Phase 0 | |

## Steps

### 1.1 — Tech Stack Detection (Sprint 4 — bash delegation)

> **Token saving:** ~5K → ~0.5K (~90% giảm). Bash chỉ enumerate manifest files,
> không cần AI inference cho deterministic detection.

```bash
IF target_type == "local-source":
  # Delegate to bash script (deterministic enumeration)
  bash .claude/scripts/scan-target-detect.sh "$target" "$SESSION_DIR/intermediate/"

  # Read result
  TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"
  detected_tech_stack=($(jq -r '.tech_stacks[]' "$TECH_STACK_JSON"))
  monorepo=$(jq -r '.monorepo' "$TECH_STACK_JSON")
  dotnet_pattern=$(jq -r '.dotnet_pattern // ""' "$TECH_STACK_JSON")
  frontend_present=$(jq -r '.frontend_present' "$TECH_STACK_JSON")
  backend_present=$(jq -r '.backend_present' "$TECH_STACK_JSON")

  # Fallback to generic if no tech detected
  IF [ ${#detected_tech_stack[@]} -eq 0 ]:
    detected_tech_stack=("generic")
    NOTE "Tech stack không xác định được — chạy generic scan"

ELIF target_type == "url":
  # AI-only step (cần WebFetch — không delegate)
  WebFetch(target) → HTML content
  Check for meta tags, script tags, framework signatures:
    - "_next/" in HTML → framework = "nextjs"
    - "nuxt" in HTML → framework = "nuxt"
    - "<div id='app'>" → framework = "vue"
    - "React" in script → framework = "react"
    - "Angular" → framework = "angular"
  detected_tech_stack = [detected_framework]
  # Also try to fetch swagger
  TRY WebFetch("{target}/swagger.json") OR "{target}/openapi.json" OR "{target}/api-docs"
  IF successful: swagger_available = true; swagger_url = url

  # Save tech-stack.json manually (cho consistency với local-source path)
  jq -n --arg t "$target" --arg fw "$detected_framework" \
     '{ "$schema":"scan-target-tech-stack-v1",
        generated_at: now | todate,
        target: $t,
        monorepo: false,
        tech_stacks: [$fw],
        dotnet_pattern: null,
        frontend_present: true,
        backend_present: false }' \
     > "$SESSION_DIR/intermediate/tech-stack.json"

ELIF target_type == "swagger-spec":
  # AI-only step (cần parse YAML/JSON spec, extract metadata)
  Read {target} → parse JSON/YAML
  Extract: info.title, info.version, tags[]
  detected_tech_stack = ["swagger-openapi"]
  swagger_data = parsed spec

  # Save tech-stack.json
  jq -n --arg t "$target" \
     '{ "$schema":"scan-target-tech-stack-v1",
        generated_at: now | todate,
        target: $t,
        monorepo: false,
        tech_stacks: ["swagger-openapi"],
        dotnet_pattern: null,
        frontend_present: false,
        backend_present: true }' \
     > "$SESSION_DIR/intermediate/tech-stack.json"
```

### 1.2 — Resolve Module Name

```
IF module_name == null OR module_name == "auto":

  IF target_type == "local-source":
    # Try to infer from path
    target_basename = basename of target
    IF target_basename matches known module patterns (VD: "CRM", "Finance", "Orders"):
      module_name = target_basename.toLowerCase()
    ELSE IF target is full repo root:
      module_name = "full-project"
    ELSE:
      module_name = target_basename  # use as-is

  IF target_type == "url":
    module_name = extract hostname từ URL (VD: "example.com")

  IF target_type == "swagger-spec":
    module_name = swagger_data.info.title

  Log: "Module name resolved: {module_name}"
```

### 1.3 — Scope Resolution (khi `--module` cụ thể được chỉ định)

```
IF module_name is NOT "full-project" AND target_type == "local-source":

  # Find the module subdirectory
  SEARCH for module directory:
    Bash: find {target} -type d -iname "*{module_name}*" | head -5
    → Chọn match tốt nhất (thường là Eureka.Modules.{ModuleName} hoặc apps/{module})

  IF found:
    scan_root = matched_directory
    Log: "Scanning module scope: {scan_root}"
  ELSE:
    scan_root = target
    WARN "Module '{module_name}' không tìm thấy trong target — scan toàn bộ target"
```

### 1.4 — Compute target_fingerprint + Save Checkpoint (Sprint 4 — bash delegation)

> Tính target_fingerprint composite (Q6 decision: path+tech+depth+git_head+git_dirty+manifests).
> Sprint 4: implementation moved to `.claude/scripts/scan-target-fingerprint.sh`.
> Persist vào scan-status.json + checkpoint.json để --resume verify.

```bash
# Build CSV string của tech stacks (sorted, dedup)
detected_tech_stack_csv=$(printf "%s\n" "${detected_tech_stack[@]}" | sort -u | tr '\n' ',' | sed 's/,$//')

# Compute fingerprint via bash script (v2.0.1: pass mode for BUG-003 fix)
TARGET_FINGERPRINT=$(bash .claude/scripts/scan-target-fingerprint.sh "$target" "$detected_tech_stack_csv" "$scan_depth" "${CACHE_FP_MODE:-strict}")

# Persist vào scan-status.json
tmp=$(mktemp)
jq --arg fp "$TARGET_FINGERPRINT" '.target_fingerprint = $fp' \
   "$SESSION_DIR/scan-status.json" > "$tmp" && mv "$tmp" "$SESSION_DIR/scan-status.json"

# Persist vào checkpoint.json
tmp=$(mktemp)
jq --arg fp "$TARGET_FINGERPRINT" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.target_fingerprint = $fp | .updated_at = $ts' \
   "$SESSION_DIR/checkpoint.json" > "$tmp" && mv "$tmp" "$SESSION_DIR/checkpoint.json"

Log: "target_fingerprint = ${TARGET_FINGERPRINT:0:16}..."

# Enrich tech-stack.json với module_name + scan_root (giữ nguyên fields từ scan-target-detect.sh)
tmp=$(mktemp)
jq --arg mn "$module_name" --arg sr "$scan_root" \
   '. + { module_name: $mn, scan_root: $sr }' \
   "$SESSION_DIR/intermediate/tech-stack.json" > "$tmp" && mv "$tmp" "$SESSION_DIR/intermediate/tech-stack.json"

save_checkpoint --phase phase_1 --status completed \
                --next-phase phase_2 --next-step layer_1_structure \
                --intermediate-key tech_stack_json \
                --intermediate-path "intermediate/tech-stack.json"
```

### 1.4b — Compute Changed Files (Sprint 7 delta scan — chỉ khi `--since` set)

> **Sprint 7 PHẦN B.** Khi `$SINCE_REF` non-empty (đã validate ở Phase 0.2b), compute danh sách
> file thay đổi giữa `$SINCE_REF` và HEAD bằng `git diff --name-status --find-renames=80`.
> Filter chỉ A/M/R (Added/Modified/Renamed) — skip D (Deleted) vì không scan được file đã xoá.
> Persist vào `intermediate/changed-files.json` cho Phase 2 dùng làm scope filter.
>
> **Note:** Nếu changed files rỗng (0 files thay đổi giữa SINCE_REF..HEAD) → tiếp tục normal scan
> (KHÔNG STOP) — user vẫn có thể muốn scan baseline mà không có change. Log warning để rõ ràng.

```bash
if [[ -n "$SINCE_REF" ]]; then
  Log: "Computing changed files since $SINCE_REF..."

  HEAD_REF=$(git -C "$target" rev-parse HEAD 2>/dev/null || echo "no-head")
  CHANGED_FILES_RAW=$(git -C "$target" diff --name-status --find-renames=80 \
    "$SINCE_REF..HEAD" -- 2>/dev/null || echo "")

  # Filter A/M/R (skip D — Deleted không scan được)
  CHANGED_FILES_LIST=$(echo "$CHANGED_FILES_RAW" \
    | awk '$1 ~ /^[AMR]/ { for (i=2; i<=NF; i++) print $i }' \
    | sort -u)

  TOTAL_CHANGED=$(echo "$CHANGED_FILES_LIST" | grep -c . || echo 0)

  # Persist intermediate/changed-files.json (machine-readable cho Phase 2 scope filter)
  CHANGED_FILES_JSON=$(echo "$CHANGED_FILES_LIST" | jq -R . | jq -s '.')
  jq -n \
    --arg since "$SINCE_REF" \
    --arg head "$HEAD_REF" \
    --argjson total "$TOTAL_CHANGED" \
    --argjson files "$CHANGED_FILES_JSON" \
    '{ "$schema": "scan-target-changed-files-v1",
       generated_at: now | todate,
       since_ref: $since,
       head_ref: $head,
       total_changed: $total,
       scan_mode: "delta",
       files: $files }' \
    > "$SESSION_DIR/intermediate/changed-files.json"

  if [[ "$TOTAL_CHANGED" -eq 0 ]]; then
    log_warn "Không có file thay đổi giữa $SINCE_REF..HEAD (cùng commit hoặc range trống).
              Tiếp tục scan toàn bộ scan_root (--since không có hiệu lực)."
    DELTA_MODE="false"
  else
    Log: "Delta scan: $TOTAL_CHANGED files changed since $SINCE_REF (filter A/M/R, skip D)"
    DELTA_MODE="true"
  fi
else
  DELTA_MODE="false"
fi
```

### 1.5 — Cache Hit Lookup (Sprint 6 multi-dev safety — Q2 = A)

> **Purpose:** Sau khi compute fingerprint, check `_shared/cache/{fingerprint}.json` — nếu hit
> (TTL < 24h) và user KHÔNG pass `--no-cache` → reuse target-map.json từ cache, skip Phase 2-4.
> Generate các output khác từ cached target-map.json ở Phase 5.
>
> **Backward-compat:** Lần scan đầu hoặc `--no-cache` → cache miss → tiếp tục bình thường (no-op).
> **Cross-machine:** fingerprint chứa absolute path → cache TỪ máy khác sẽ KHÔNG match → cache miss
> → re-scan (an toàn, không serve stale data từ máy khác).

```bash
# Skip cache lookup nếu user pass --no-cache (Phase 0 đã set NO_CACHE flag)
# Sprint 7 PHẦN H — Skip cache lookup nếu --since set (delta scan = subset, cache full → mismatch)
if [[ "${NO_CACHE:-false}" == "true" ]]; then
  Log: "--no-cache set — skip cache lookup"
  CACHE_HIT="false"
elif [[ "${DELTA_MODE:-false}" == "true" ]]; then
  Log: "--since set (delta scan) — skip cache lookup (cache là full scan, delta là subset → mismatch)"
  CACHE_HIT="false"
else
  CACHE_FILE=".mc-data/work/wf-scan-target/_shared/cache/${TARGET_FINGERPRINT}.json"

  if [[ -f "$CACHE_FILE" ]]; then
    # TTL check (24h hardcoded — Sprint 7 sẽ make configurable nếu cần)
    CACHE_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    CACHE_TTL_SECONDS=$((24 * 3600))

    if [[ "$CACHE_AGE_SECONDS" -gt 0 ]] && [[ "$CACHE_AGE_SECONDS" -lt "$CACHE_TTL_SECONDS" ]]; then
      AGE_HOURS=$(( CACHE_AGE_SECONDS / 3600 ))
      Log: "✓ Cache hit (age ${AGE_HOURS}h, fingerprint ${TARGET_FINGERPRINT:0:16}...) — reuse target-map.json"

      # Copy cached target-map.json → SESSION_DIR (atomic via cp + sync)
      cp "$CACHE_FILE" "$SESSION_DIR/target-map.json.tmp.$$"
      sync "$SESSION_DIR/target-map.json.tmp.$$" 2>/dev/null || true
      mv "$SESSION_DIR/target-map.json.tmp.$$" "$SESSION_DIR/target-map.json"

      # Mark cache_hit trong scan-status.json
      tmp=$(mktemp)
      jq --arg ch "true" --arg cf "$CACHE_FILE" \
         '.cache_hit = ($ch == "true") | .cache_source = $cf' \
         "$SESSION_DIR/scan-status.json" > "$tmp" && mv "$tmp" "$SESSION_DIR/scan-status.json"

      CACHE_HIT="true"

      # Skip Phase 2-4 — fast-forward checkpoint sang phase_5
      save_checkpoint --phase phase_2 --status skipped --next-phase phase_5 --next-step output_generation
      save_checkpoint --phase phase_3 --status skipped
      save_checkpoint --phase phase_4 --status skipped
      Log: "Phase 2-4 skipped (cache hit) — jump to Phase 5"
    else
      AGE_HOURS=$(( CACHE_AGE_SECONDS / 3600 ))
      Log: "Cache stale (age ${AGE_HOURS}h ≥ 24h) — invalidate, fresh scan"
      CACHE_HIT="false"
    fi
  else
    Log: "Cache miss (fingerprint ${TARGET_FINGERPRINT:0:16}...)"
    CACHE_HIT="false"
  fi
fi
```

## POST-GATE

```
- $detected_tech_stack[] không rỗng (≥ 1 entry, có thể là "generic")
- $module_name không null
- $scan_root set (path hoặc target)
- $TARGET_FINGERPRINT là sha256 string non-empty
- test -s $SESSION_DIR/intermediate/tech-stack.json
- jq empty $SESSION_DIR/intermediate/tech-stack.json
- checkpoint.json: phase_states.phase_1 == "completed", next_action.phase == "phase_2"
- IF $SINCE_REF non-empty: test -s $SESSION_DIR/intermediate/changed-files.json (Sprint 7 delta)
- $DELTA_MODE set (true/false)                                                   # Sprint 7
- $CACHE_HIT set (true/false)                                                    # Sprint 6
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$detected_tech_stack` | array | Tech stacks phát hiện (nextjs, dotnet, react-native, ...) |
| `$dotnet_pattern` | string\|null | `ddd-cqrs` / `standard` (nếu .NET) |
| `$swagger_data`, `$swagger_available` | object/bool | Nếu URL có swagger |
| `$module_name` | string | Resolved module name |
| `$scan_root` | path | Resolved scan directory |
| `$TARGET_FINGERPRINT` | sha256 | Composite hash |
| `$CACHE_HIT` | bool | Sprint 6 — true nếu Phase 1.5 cache hit (skip Phase 2-4) |
| `$DELTA_MODE` | bool | Sprint 7 — true nếu `$SINCE_REF` set + có ≥1 file thay đổi (Phase 2 scope filter) |
| `$TOTAL_CHANGED` | int | Sprint 7 — số file thay đổi (chỉ set khi `$DELTA_MODE == true`) |
| `$HEAD_REF` | string | Sprint 7 — git HEAD commit (cho target-map.delta_scan field) |

## Next Phase

→ IF `$CACHE_HIT == "true"`: Read `procedures/phase5-output.md` directly (skip Phase 2-4 — Sprint 6 cache hit)
→ ELSE: Read `procedures/phase2-l1-structure.md` (always)
→ Then PARALLEL: `procedures/phase2-l2-api.md`, `phase2-l3-ui.md`, `phase2-l4-db.md` (if `$scan_depth != "shallow"`)
