#!/usr/bin/env bash
# vs-scan-code.sh — Phase 1 Group B: REQ-ID code scanner
# Usage: bash vs-scan-code.sh [--scope-file <json>] [--src-dirs <dirs>] [--output <file>]
# Output: scan-results.json → {req_id: [file_paths], orphan_files: []}
# Requires: grep, jq (optional — fallback to grep-only mode)
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
SCOPE_FILE=""
SRC_DIRS=""
OUTPUT_FILE=""
EXCLUDE_PATTERNS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope-file) SCOPE_FILE="$2"; shift 2 ;;
    --src-dirs) SRC_DIRS="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --exclude-file) EXCLUDE_PATTERNS_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
: "${SRC_DIRS:="src apps"}"
: "${OUTPUT_FILE:="/dev/stdout"}"

# ---------------------------------------------------------------------------
# Build exclude pattern for grep
# ---------------------------------------------------------------------------
build_exclude_pattern() {
  # Directory exclusions
  local dirs=(
    "node_modules" "dist" "build" ".next" "out" ".git"
    "__generated__" "generated" "coverage" ".turbo" ".mc-data"
  )
  # File pattern exclusions (generated/compiled/config/test files)
  local file_patterns=(
    "*.d.ts" "*.d.cts" "*.d.mts" "*.min.js" "*.min.css"
    "*.bundle.*" "*.generated.*" "*.gen.*" "*.pb.ts" "*_pb.ts" "*_grpc_pb.ts"
    "*.snap" "*.map" "*.js.map" "*.css.map" "*.lock" "*.g.dart" "*.freezed.dart"
    "*.config.*" "*.config" "*.csproj" "*.vbproj" "*.fsproj" "*.vcxproj"
    "*.sln" "*.xaml" "*.axml" "*.props" "*.targets" "*.resx"
    "*.svg" "*.xml" "*.json" "*.jsonc" "*.jsonl" "*.yaml" "*.yml"
    "*.toml" "*.ini" "*.cfg" "*.conf" "*.properties" "*.env*"
    "Dockerfile" "Makefile" "*.gradle" "*.cmake" "CMakeLists.txt"
    "*.css" "*.scss" "*.less" "*.sass" "*.md" "*.mdx" "*.rst" "*.txt"
    "*.sql" "*.prisma" "*.graphql"
    "index.ts" "index.js" "types.ts" "types.js" "constants.ts" "constants.js"
    "*.test.*" "*.spec.*" "*.stories.*" "*.fixture.*"
  )

  # Build --glob arguments for grep
  local globs=""
  for pattern in "${file_patterns[@]}"; do
    globs="$globs --glob=!${pattern}"
  done
  echo "$globs"
}

# ---------------------------------------------------------------------------
# Find source files to scan
# ---------------------------------------------------------------------------
find_source_files() {
  local dirs=($SRC_DIRS)
  local existing_dirs=()
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] && existing_dirs+=("$d")
  done

  if [[ ${#existing_dirs[@]} -eq 0 ]]; then
    warn "No source directories found: $SRC_DIRS"
    echo "[]"
    return
  fi

  # Build a list of files, filtering out excluded dirs
  local find_args=()
  for d in "${existing_dirs[@]}"; do
    # Only search in */src/ subdirectories for monorepo
    if [[ -d "$d" ]]; then
      find_args+=("$d")
    fi
  done

  # Use find to get all files, then filter
  for d in "${find_args[@]}"; do
    find "$d" -type f 2>/dev/null || true
  done
}

# ---------------------------------------------------------------------------
# Check if file should be excluded based on name/extension
# ---------------------------------------------------------------------------
is_excluded_file() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  # Directory component check
  local dirpart
  dirpart=$(dirname "$file")
  for ed in node_modules dist build .next out .git __generated__ generated coverage .turbo .mc-data; do
    if [[ "$dirpart" == *"/$ed"* ]] || [[ "$dirpart" == *"\\$ed"* ]]; then
      return 0
    fi
  done

  # Barrel/utility files
  case "$basename" in
    index.ts|index.js|types.ts|types.js|constants.ts|constants.js) return 0 ;;
  esac

  # Generated/compiled extensions
  case "$basename" in
    *.d.ts|*.d.cts|*.d.mts|*.min.js|*.min.css) return 0 ;;
    *.bundle.*|*.generated.*|*.gen.*|*.pb.ts|*_pb.ts|*_grpc_pb.ts) return 0 ;;
    *.snap|*.map|*.js.map|*.css.map|*.lock|*.g.dart|*.freezed.dart) return 0 ;;
    # Config/build/project files
    *.config.*|*.config|*.csproj|*.vbproj|*.fsproj|*.vcxproj) return 0 ;;
    *.sln|*.xaml|*.axml|*.props|*.targets|*.resx) return 0 ;;
    *.svg|*.xml|*.json|*.jsonc|*.jsonl|*.yaml|*.yml) return 0 ;;
    *.toml|*.ini|*.cfg|*.conf|*.properties|*.env*) return 0 ;;
    Dockerfile|Makefile|*.gradle|*.cmake|CMakeLists.txt) return 0 ;;
    # Style/doc/data
    *.css|*.scss|*.less|*.sass|*.md|*.mdx|*.rst|*.txt) return 0 ;;
    *.sql|*.prisma|*.graphql) return 0 ;;
    # Test
    *.test.*|*.spec.*|*.stories.*|*.fixture.*) return 0 ;;
  esac

  return 1
}

# ---------------------------------------------------------------------------
# Check if a path is within a scope module directory
# ---------------------------------------------------------------------------
is_in_scope_modules() {
  local file="$1"
  local scope_modules="$2"

  if [[ -z "$scope_modules" ]] || [[ "$scope_modules" == "[]" ]]; then
    return 0  # No scope filter = include everything
  fi

  # scope_modules is a JSON array of directory paths
  if command -v jq >/dev/null 2>&1; then
    local mod_count
    mod_count=$(echo "$scope_modules" | jq -r 'length')
    for ((i=0; i<mod_count; i++)); do
      local mod_dir
      mod_dir=$(echo "$scope_modules" | jq -r ".[$i]")
      if [[ -n "$mod_dir" ]] && [[ "$mod_dir" != "null" ]]; then
        if [[ "$file" == "$mod_dir"* ]] || [[ "$file" == *"/$mod_dir/"* ]]; then
          return 0
        fi
      fi
    done
    return 1
  fi

  return 0  # No jq = can't filter by scope modules, include all
}

# ---------------------------------------------------------------------------
# Main scan logic
# ---------------------------------------------------------------------------
main() {
  info "vs-scan-code.sh: Scanning source code for REQ-ID comments..."

  # Parse scope file if provided
  local scope_req_ids=""
  local scope_modules="[]"
  if [[ -n "$SCOPE_FILE" ]] && [[ -f "$SCOPE_FILE" ]] && command -v jq >/dev/null 2>&1; then
    scope_req_ids=$(jq -r '.req_ids | join(" ")' "$SCOPE_FILE" 2>/dev/null || echo "")
    scope_modules=$(jq -c '.modules // []' "$SCOPE_FILE" 2>/dev/null || echo "[]")
  fi

  # Collect all source files
  local all_files
  all_files=$(find_source_files | sort -u)

  if [[ -z "$all_files" ]]; then
    warn "No source files found in: $SRC_DIRS"
    echo '{"req_id_map":{},"orphan_files":[],"total_files_scanned":0,"scan_summary":{"directories_scanned":"'"$SRC_DIRS"'","files_scanned":0,"req_ids_found":0,"orphans_found":0}}'
    return
  fi

  # Initialize associative storage
  declare -A REQ_MAP=()
  local ORPHANS=()
  local FILES_SCANNED=0
  local REQ_IDS_FOUND=0

  # Scan each file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if is_excluded_file "$file"; then
      continue
    fi
    if ! is_in_scope_modules "$file" "$scope_modules"; then
      continue
    fi

    FILES_SCANNED=$((FILES_SCANNED + 1))

    # Search for REQ-ID patterns in file
    # Pattern: REQ-[A-Z]+-digits or REQ-[A-Z]+-[A-Z]+-digits
    local matches
    matches=$(grep -ohE 'REQ-[A-Z]+-[0-9]+|REQ-[A-Z]+-[A-Z]+-[0-9]+' "$file" 2>/dev/null | sort -u || true)

    if [[ -n "$matches" ]]; then
      # File has REQ-IDs
      while IFS= read -r req_id; do
        [[ -z "$req_id" ]] && continue
        # Optional scope filter by REQ-ID
        if [[ -n "$scope_req_ids" ]]; then
          if [[ " $scope_req_ids " != *" $req_id "* ]]; then
            continue
          fi
        fi
        local existing="${REQ_MAP[$req_id]:-}"
        if [[ -n "$existing" ]]; then
          REQ_MAP[$req_id]="$existing"$'\n'"$file"
        else
          REQ_MAP[$req_id]="$file"
        fi
      done <<< "$matches"
    else
      # File has no REQ-ID → orphan
      ORPHANS+=("$file")
    fi
  done <<< "$all_files"

  # Count unique REQ-IDs
  REQ_IDS_FOUND=${#REQ_MAP[@]}

  # Build JSON output
  if command -v jq >/dev/null 2>&1; then
    # Build req_id_map as JSON object
    local json_parts=""
    local first=true
    for req_id in "${!REQ_MAP[@]}"; do
      local files_array
      # Convert newline-separated to JSON array
      files_array=$(echo "${REQ_MAP[$req_id]}" | jq -R -s 'split("\n") | map(select(length > 0))')
      if $first; then
        json_parts="$json_parts\"$req_id\":$files_array"
        first=false
      else
        json_parts="$json_parts,\"$req_id\":$files_array"
      fi
    done

    # Build orphans JSON array
    local orphans_json="[]"
    if [[ ${#ORPHANS[@]} -gt 0 ]]; then
      orphans_json=$(printf '%s\n' "${ORPHANS[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi

    jq -n \
      --argjson req_map "{$json_parts}" \
      --argjson orphans "$orphans_json" \
      --argjson scanned "$FILES_SCANNED" \
      --argjson req_found "$REQ_IDS_FOUND" \
      --argjson orphan_count "${#ORPHANS[@]}" \
      --arg dirs "$SRC_DIRS" \
      '{
        req_id_map: $req_map,
        orphan_files: $orphans,
        total_files_scanned: $scanned,
        scan_summary: {
          directories_scanned: $dirs,
          files_scanned: $scanned,
          req_ids_found: $req_found,
          orphans_found: $orphan_count
        }
      }' > "$OUTPUT_FILE"
  else
    # Fallback: simple JSON without jq
    {
      echo '{'
      echo '  "req_id_map": {'
      local first=true
      for req_id in "${!REQ_MAP[@]}"; do
        $first || echo ','
        echo -n "    \"$req_id\": ["
        local ffirst=true
        while IFS= read -r f; do
          [[ -z "$f" ]] && continue
          $ffirst || echo -n ','
          echo -n "\"$f\""
          ffirst=false
        done <<< "${REQ_MAP[$req_id]}"
        echo -n ']'
        first=false
      done
      echo ''
      echo '  },'
      echo '  "orphan_files": ['
      local ofirst=true
      for f in "${ORPHANS[@]}"; do
        $ofirst || echo ','
        echo -n "    \"$f\""
        ofirst=false
      done
      echo ''
      echo '  ],'
      echo "  \"total_files_scanned\": $FILES_SCANNED,"
      echo '  "scan_summary": {'
      echo "    \"directories_scanned\": \"$SRC_DIRS\","
      echo "    \"files_scanned\": $FILES_SCANNED,"
      echo "    \"req_ids_found\": $REQ_IDS_FOUND,"
      echo "    \"orphans_found\": ${#ORPHANS[@]}"
      echo '  }'
      echo '}'
    } > "$OUTPUT_FILE"
  fi

  info "Scan complete: $REQ_IDS_FOUND REQ-IDs found, ${#ORPHANS[@]} orphans, $FILES_SCANNED files scanned"
  info "Output: $OUTPUT_FILE"
}

main "$@"
