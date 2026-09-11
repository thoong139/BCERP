#!/usr/bin/env bash
# scan-target-inventory.sh — File structure + key files cho wf-scan-target Phase 2 L1
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/scan-target-inventory.sh <scan-root> <output-dir> <tech-stack-json>
#
# Output: $output_dir/l1-structure.json
#
# Output JSON shape:
# {
#   "$schema": "scan-target-l1-v1",
#   "generated_at": "...",
#   "scan_root": "...",
#   "total_files": 1234,
#   "file_counts_by_ext": {".cs": 234, ".tsx": 145},
#   "dir_structure": ["apps/backend/Domain", ...],
#   "key_files": {
#     "entities": ["Domain/Entities/Customer.cs", ...],
#     "commands": [...],
#     "command_handlers": [...],
#     "queries": [...],
#     "endpoints": [...],
#     "pages": [...],
#     "screens": [...],
#     "components": [...],
#     "api_routes": [...]
#   }
# }

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-inventory"
# shellcheck source=./scan-target-common.sh
source "$SCRIPTS_DIR/scan-target-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Args ────────────────────────────────────────────────────

SCAN_ROOT="${1:?Usage: $0 <scan-root> <output-dir> <tech-stack-json>}"
OUTPUT_DIR="${2:?Output dir required}"
TECH_JSON="${3:-}"   # Optional path to tech-stack.json

if [[ ! -d "$SCAN_ROOT" ]]; then
  log_error "Scan root not a directory: $SCAN_ROOT"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
log_info "Inventorying scan_root: $SCAN_ROOT"

# ─── Read tech_stacks from JSON if provided ─────────────────

declare -a tech_stacks=()
if [[ -n "$TECH_JSON" && -f "$TECH_JSON" && $(has_jq && echo y) == "y" ]]; then
  while IFS= read -r t; do
    [[ -n "$t" ]] && tech_stacks+=("$t")
  done < <(jq -r '.tech_stacks[]?' "$TECH_JSON" 2>/dev/null || echo "")
fi

# Helper: check if tech is in stack
has_tech() {
  local query="$1"
  for t in "${tech_stacks[@]:-}"; do
    [[ "$t" == *"$query"* ]] && return 0
  done
  return 1
}

# ─── Step 1: Total file count + extension histogram ─────────

log_info "Counting files + extension histogram..."

# ONE find traversal for total + per-ext counts (perf optimization)
ext_counts_csv=$(find "$SCAN_ROOT" -type f \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" \
    ! -path "*/vendor/*" ! -path "*/bin/*" ! -path "*/obj/*" \
    ! -path "*/.next/*" ! -path "*/.mc-data/*" ! -path "*/.backup*" \
    ! -path "*/.claude/*" ! -path "*/coverage/*" \
    2>/dev/null | awk -F. '
    NF > 1 {
      ext = "." tolower($NF)
      counts[ext]++
      total++
    }
    NF == 1 { total++; counts["(no-ext)"]++ }
    END {
      print "TOTAL:" total
      for (e in counts) print e ":" counts[e]
    }
  ')

total_files=$(echo "$ext_counts_csv" | grep '^TOTAL:' | cut -d: -f2)
total_files="${total_files:-0}"

# Build file_counts_by_ext JSON
ext_json="{}"
if has_jq; then
  ext_json=$(echo "$ext_counts_csv" | grep -v '^TOTAL:' | awk -F: '{print "{\"key\":\"" $1 "\",\"value\":" $2 "}"}' | jq -s 'map({(.key): .value}) | add // {}')
  [[ -z "$ext_json" || "$ext_json" == "null" ]] && ext_json="{}"
fi

# ─── Step 2: Directory structure (max depth 3) ──────────────

log_debug "Collecting directory structure..."

dir_list_raw=$(find "$SCAN_ROOT" -maxdepth 3 -type d \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" \
    ! -path "*/vendor/*" ! -path "*/bin/*" ! -path "*/obj/*" \
    ! -path "*/.next/*" ! -path "*/.mc-data/*" ! -path "*/.backup*" \
    ! -path "*/.claude/*" ! -path "*/coverage/*" \
    2>/dev/null | head -100)

# Convert to relative paths
dir_list_json="[]"
if has_jq; then
  dir_list_json=$(echo "$dir_list_raw" | while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    rel=$(compute_rel_path "$d" "$SCAN_ROOT")
    [[ -z "$rel" ]] && continue
    echo "$rel"
  done | jq -R . | jq -s .)
fi

# ─── Step 3: Key files by tech stack ────────────────────────

log_debug "Collecting key files by tech stack..."

# Helper: glob pattern → newline-separated relative paths
glob_to_rel() {
  local pattern="$1"
  find "$SCAN_ROOT" -path "$SCAN_ROOT/$pattern" -type f 2>/dev/null | head -200 | while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    compute_rel_path "$f" "$SCAN_ROOT"
  done
}

# Helper: find by name pattern recursive (simpler than glob for **)
find_by_name() {
  local name_pattern="$1"
  local sub_path_filter="${2:-}"   # e.g., "*/Domain/Entities/*"
  if [[ -n "$sub_path_filter" ]]; then
    find "$SCAN_ROOT" -type f -name "$name_pattern" -path "$sub_path_filter" \
      ! -path "*/node_modules/*" ! -path "*/bin/*" ! -path "*/obj/*" \
      ! -path "*/.git/*" ! -path "*/dist/*" \
      2>/dev/null | head -200 | while IFS= read -r f; do
      compute_rel_path "$f" "$SCAN_ROOT"
    done
  else
    find "$SCAN_ROOT" -type f -name "$name_pattern" \
      ! -path "*/node_modules/*" ! -path "*/bin/*" ! -path "*/obj/*" \
      ! -path "*/.git/*" ! -path "*/dist/*" \
      2>/dev/null | head -200 | while IFS= read -r f; do
      compute_rel_path "$f" "$SCAN_ROOT"
    done
  fi
}

# JSON arrays (will be assembled at end)
declare -A KEY_FILES_RAW
to_json_array() {
  local input="$1"
  if has_jq; then
    echo "$input" | jq -R . | jq -s . 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

# ── .NET DDD patterns ──
if has_tech "dotnet"; then
  KEY_FILES_RAW[entities]=$(find_by_name '*.cs' '*/Domain/Entities/*')
  KEY_FILES_RAW[commands]=$(find_by_name '*Command.cs' '*/Application/*')
  KEY_FILES_RAW[command_handlers]=$(find_by_name '*Handler.cs' '*/Application/Commands/*')
  KEY_FILES_RAW[queries]=$(find_by_name '*Query.cs' '*/Application/*')
  KEY_FILES_RAW[query_handlers]=$(find_by_name '*Handler.cs' '*/Application/Queries/*')
  KEY_FILES_RAW[endpoints]=$(find_by_name '*.cs' '*/Endpoints/*')
  KEY_FILES_RAW[ef_configs]=$(find_by_name '*.cs' '*/Infrastructure/Persistence/Configurations/*')
  KEY_FILES_RAW[value_objects]=$(find_by_name '*.cs' '*/Domain/ValueObjects/*')
  KEY_FILES_RAW[domain_events]=$(find_by_name '*.cs' '*/Domain/DomainEvents/*')
  KEY_FILES_RAW[validators]=$(find_by_name '*Validator.cs' '*/Application/*')
fi

# ── Next.js ──
if has_tech "nextjs"; then
  KEY_FILES_RAW[pages]=$(find_by_name 'page.tsx' '*/app/*')
  pages_js=$(find_by_name 'page.jsx' '*/app/*')
  [[ -n "$pages_js" ]] && KEY_FILES_RAW[pages]="${KEY_FILES_RAW[pages]:-}
$pages_js"
  KEY_FILES_RAW[layouts]=$(find_by_name 'layout.tsx' '*/app/*')
  KEY_FILES_RAW[components]=$(find_by_name '*.tsx' '*/components/*')
  KEY_FILES_RAW[hooks]=$(find_by_name 'use*.ts' '*/hooks/*')
  KEY_FILES_RAW[stores]=$(find_by_name '*.ts' '*/stores/*')
  KEY_FILES_RAW[api_routes]=$(find_by_name 'route.ts' '*/api/*')
fi

# ── React Native ──
if has_tech "react-native"; then
  KEY_FILES_RAW[screens]=$(find_by_name '*.tsx' '*/screens/*')
  rn_components=$(find_by_name '*.tsx' '*/components/*')
  if [[ -n "$rn_components" ]]; then
    KEY_FILES_RAW[components]="${KEY_FILES_RAW[components]:-}
$rn_components"
  fi
fi

# ── Vue/Nuxt ──
if has_tech "vue"; then
  KEY_FILES_RAW[pages_vue]=$(find_by_name '*.vue' '*/pages/*')
  KEY_FILES_RAW[components_vue]=$(find_by_name '*.vue' '*/components/*')
fi

# ── Hono / Express ──
if has_tech "hono" || has_tech "express"; then
  KEY_FILES_RAW[routes]=$(find_by_name '*.ts' '*/routes/*')
  routes_js=$(find_by_name '*.js' '*/routes/*')
  [[ -n "$routes_js" ]] && KEY_FILES_RAW[routes]="${KEY_FILES_RAW[routes]:-}
$routes_js"
fi

# ── Generic fallback (when no tech detected) ──
if [[ ${#tech_stacks[@]} -eq 0 ]]; then
  KEY_FILES_RAW[top_level]=$(find "$SCAN_ROOT" -maxdepth 2 -type f \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    2>/dev/null | head -50 | while IFS= read -r f; do
      compute_rel_path "$f" "$SCAN_ROOT"
    done)
fi

# ─── Build key_files JSON object ────────────────────────────

key_files_json="{}"
if has_jq; then
  key_files_json="{"
  first=1
  for k in "${!KEY_FILES_RAW[@]}"; do
    val="${KEY_FILES_RAW[$k]}"
    [[ -z "$val" ]] && continue
    arr_json=$(echo "$val" | grep -v '^$' | sort -u | jq -R . | jq -s .)
    [[ -z "$arr_json" || "$arr_json" == "null" ]] && arr_json="[]"
    [[ $first -eq 0 ]] && key_files_json+=","
    key_files_json+="\"$k\":$arr_json"
    first=0
  done
  key_files_json+="}"
  # Validate, fallback to {} if malformed
  if ! echo "$key_files_json" | jq empty 2>/dev/null; then
    log_warn "key_files JSON malformed, falling back to empty"
    key_files_json="{}"
  fi
fi

# ─── Final output ───────────────────────────────────────────

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
scan_root_norm=$(normalize_path "$SCAN_ROOT")

if has_jq; then
  output=$(jq -n \
    --arg gen "$generated_at" \
    --arg root "$scan_root_norm" \
    --argjson total "$total_files" \
    --argjson exts "$ext_json" \
    --argjson dirs "$dir_list_json" \
    --argjson kf "$key_files_json" \
    '{
      "$schema": "scan-target-l1-v1",
      generated_at: $gen,
      scan_root: $root,
      total_files: $total,
      file_counts_by_ext: $exts,
      dir_structure: $dirs,
      key_files: $kf
    }')
else
  output=$(cat <<EOF
{
  "\$schema": "scan-target-l1-v1",
  "generated_at": "$generated_at",
  "scan_root": "$(json_escape "$scan_root_norm")",
  "total_files": $total_files,
  "file_counts_by_ext": $ext_json,
  "dir_structure": $dir_list_json,
  "key_files": $key_files_json
}
EOF
  )
fi

atomic_write_json "$OUTPUT_DIR/l1-structure.json" "$output"

log_info "L1 inventory: total_files=$total_files, key_file_groups=${#KEY_FILES_RAW[@]}"
log_info "Output: $OUTPUT_DIR/l1-structure.json"
