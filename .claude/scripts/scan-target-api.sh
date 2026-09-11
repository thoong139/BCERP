#!/usr/bin/env bash
# scan-target-api.sh — API endpoints discovery cho wf-scan-target Phase 2 L2
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/scan-target-api.sh <scan-root> <output-dir> <tech-stack-json>
#
# Output: $output_dir/l2-api.json
#
# Detects:
#   - .NET DDD: MapGet/MapPost/MapPut/MapDelete in Endpoints/*.cs + [HttpGet]/[HttpPost] in Controllers
#   - Next.js: route.ts + app/api/**/route.ts (extract HTTP method exports)
#   - Hono: app.get/post/put/delete in route files
#   - Express: router.get/post/put/delete in routes
#
# Output JSON shape:
# {
#   "$schema": "scan-target-l2-v1",
#   "generated_at": "...",
#   "scan_root": "...",
#   "total_endpoints": 42,
#   "source": "code_scan",
#   "endpoints": [
#     {"method": "GET", "path": "/api/customers", "handler": "GetCustomers", "file": "...", "requires_auth": true},
#     ...
#   ]
# }

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-api"
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
log_info "Scanning API endpoints at: $SCAN_ROOT"

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

# ─── Endpoint accumulator ────────────────────────────────────

# Will collect endpoints as one JSON line per endpoint, then assemble
ENDPOINTS_TMP=$(mktemp)
trap 'rm -f "$ENDPOINTS_TMP"' EXIT
SOURCE="none"

emit_endpoint() {
  local method="$1"
  local path="$2"
  local handler="${3:-}"
  local file="${4:-}"
  local requires_auth="${5:-false}"

  if has_jq; then
    jq -nc \
      --arg m "$method" \
      --arg p "$path" \
      --arg h "$handler" \
      --arg f "$file" \
      --argjson auth "$requires_auth" \
      '{method: $m, path: $p, handler: $h, file: $f, requires_auth: $auth}' \
      >> "$ENDPOINTS_TMP"
  else
    echo "{\"method\":\"$(json_escape "$method")\",\"path\":\"$(json_escape "$path")\",\"handler\":\"$(json_escape "$handler")\",\"file\":\"$(json_escape "$file")\",\"requires_auth\":$requires_auth}" >> "$ENDPOINTS_TMP"
  fi
}

# ─── .NET — MapGet/MapPost/etc. + Controllers ──────────────

if has_tech "dotnet"; then
  SOURCE="code_scan"
  log_debug "Scanning .NET endpoints..."

  # Minimal API: MapGet/MapPost/MapPut/MapDelete/MapPatch
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    requires_auth="false"
    grep -qE 'RequireAuthorization\(' "$f" 2>/dev/null && requires_auth="true"

    # Match: app.MapGet("/path/..", handler) — extract method + path + handler hint
    grep -nE '\.(MapGet|MapPost|MapPut|MapDelete|MapPatch)\s*\(\s*"[^"]+"' "$f" 2>/dev/null | head -50 | while IFS= read -r match; do
      method=$(echo "$match" | grep -oE '\.(MapGet|MapPost|MapPut|MapDelete|MapPatch)' | head -1 | sed 's/^\.Map//' | tr '[:lower:]' '[:upper:]')
      path=$(echo "$match" | grep -oE '"\/[^"]+"' | head -1 | tr -d '"')
      handler=$(echo "$match" | grep -oE '[A-Z][a-zA-Z0-9_]*Handler|[A-Z][a-zA-Z0-9_]*Endpoint|[a-z][a-zA-Z0-9_]+Async' | head -1)
      [[ -z "$path" ]] && continue
      emit_endpoint "$method" "$path" "$handler" "$rel" "$requires_auth"
    done
  done < <(find "$SCAN_ROOT" -type f -name '*.cs' -path '*/Endpoints/*' \
              ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | head -100)

  # Also scan files outside /Endpoints/ that have Map* patterns (Program.cs, Module.cs)
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    grep -nE '\.(MapGet|MapPost|MapPut|MapDelete|MapPatch)\s*\(\s*"[^"]+"' "$f" 2>/dev/null | head -20 | while IFS= read -r match; do
      method=$(echo "$match" | grep -oE '\.(MapGet|MapPost|MapPut|MapDelete|MapPatch)' | head -1 | sed 's/^\.Map//' | tr '[:lower:]' '[:upper:]')
      path=$(echo "$match" | grep -oE '"\/[^"]+"' | head -1 | tr -d '"')
      [[ -z "$path" ]] && continue
      emit_endpoint "$method" "$path" "" "$rel" "false"
    done
  done < <(find "$SCAN_ROOT" -maxdepth 3 -type f \( -name 'Program.cs' -o -name '*Module.cs' -o -name '*Routes.cs' \) \
              ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | head -20)

  # Traditional Controllers: [HttpGet]/[HttpPost] attributes
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    # Extract base route from [Route("api/[controller]")]
    base_route=$(grep -oE '\[Route\(\s*"[^"]+"' "$f" 2>/dev/null | head -1 | grep -oE '"[^"]+"' | tr -d '"')
    # Find each [Http*] attribute
    grep -nE '\[Http(Get|Post|Put|Delete|Patch)' "$f" 2>/dev/null | head -30 | while IFS= read -r match; do
      method=$(echo "$match" | grep -oE '\[Http(Get|Post|Put|Delete|Patch)' | head -1 | sed 's/\[Http//' | tr '[:lower:]' '[:upper:]')
      sub_path=$(echo "$match" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
      path="${base_route:-/}${sub_path:+/$sub_path}"
      path=$(echo "$path" | sed 's|//|/|g')
      emit_endpoint "$method" "$path" "" "$rel" "false"
    done
  done < <(find "$SCAN_ROOT" -type f -name '*.cs' -path '*/Controllers/*' \
              ! -path '*/bin/*' ! -path '*/obj/*' 2>/dev/null | head -50)
fi

# ─── Next.js — app/api/**/route.ts ─────────────────────────

if has_tech "nextjs"; then
  SOURCE="code_scan"
  log_debug "Scanning Next.js api routes..."

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    # Extract route from path: src/app/api/foo/bar/route.ts → /api/foo/bar
    route_path=$(echo "$rel" | sed -E 's|^.*/(app/)?api/|/api/|; s|/route\.(ts|js)$||')
    # Handle Next.js dynamic routes [id] → :id
    route_path=$(echo "$route_path" | sed 's|\[\([^]]*\)\]|:\1|g')

    # Find exported HTTP methods
    for method in GET POST PUT DELETE PATCH; do
      if grep -qE "export\s+(async\s+)?(function\s+|const\s+)$method\b" "$f" 2>/dev/null; then
        emit_endpoint "$method" "$route_path" "$method" "$rel" "false"
      fi
    done
  done < <(find "$SCAN_ROOT" -type f \( -name 'route.ts' -o -name 'route.js' \) \
              -path '*/api/*' ! -path '*/node_modules/*' 2>/dev/null | head -200)

  # Pages Router: pages/api/**/*.ts
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    route_path=$(echo "$rel" | sed -E 's|^.*pages/api/|/api/|; s|\.(ts|js)$||; s|/index$||')
    route_path=$(echo "$route_path" | sed 's|\[\([^]]*\)\]|:\1|g')
    emit_endpoint "ANY" "$route_path" "" "$rel" "false"
  done < <(find "$SCAN_ROOT" -type f \( -name '*.ts' -o -name '*.js' \) \
              -path '*/pages/api/*' ! -path '*/node_modules/*' 2>/dev/null | head -100)
fi

# ─── Hono / Express ────────────────────────────────────────

if has_tech "hono" || has_tech "express"; then
  SOURCE="code_scan"
  log_debug "Scanning Hono/Express routes..."

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    # Patterns: app.get('/path', handler), router.post('/path', handler)
    grep -nE '(app|router|api)\.(get|post|put|delete|patch)\s*\(\s*[`'\''"]' "$f" 2>/dev/null | head -50 | while IFS= read -r match; do
      method=$(echo "$match" | grep -oE '\.(get|post|put|delete|patch)\(' | head -1 | sed 's/\.\([a-z]*\)(/\1/' | tr '[:lower:]' '[:upper:]')
      path=$(echo "$match" | grep -oE "['\"\`][^'\"\`]+['\"\`]" | head -1 | sed "s/^['\"\`]//; s/['\"\`]\$//")
      [[ -z "$path" ]] && continue
      emit_endpoint "$method" "$path" "" "$rel" "false"
    done
  done < <(find "$SCAN_ROOT" -type f \( -name '*.ts' -o -name '*.js' \) \
              \( -path '*/routes/*' -o -path '*/api/*' -o -name 'app.ts' -o -name 'server.ts' -o -name 'index.ts' \) \
              ! -path '*/node_modules/*' ! -path '*/dist/*' 2>/dev/null | head -100)
fi

# ─── Build final JSON ──────────────────────────────────────

# Count + assemble endpoints array
total_endpoints=0
endpoints_json="[]"

if [[ -s "$ENDPOINTS_TMP" ]] && has_jq; then
  total_endpoints=$(wc -l < "$ENDPOINTS_TMP" | tr -d ' ')
  # Cap to 500 endpoints
  endpoints_json=$(head -500 "$ENDPOINTS_TMP" | jq -s 'unique_by({method, path}) // []')
  # Recount after dedup
  total_endpoints=$(echo "$endpoints_json" | jq 'length')
fi

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
scan_root_norm=$(normalize_path "$SCAN_ROOT")

if has_jq; then
  output=$(jq -n \
    --arg gen "$generated_at" \
    --arg root "$scan_root_norm" \
    --argjson total "$total_endpoints" \
    --arg src "$SOURCE" \
    --argjson eps "$endpoints_json" \
    '{
      "$schema": "scan-target-l2-v1",
      generated_at: $gen,
      scan_root: $root,
      total_endpoints: $total,
      source: $src,
      endpoints: $eps
    }')
else
  output=$(cat <<EOF
{
  "\$schema": "scan-target-l2-v1",
  "generated_at": "$generated_at",
  "scan_root": "$(json_escape "$scan_root_norm")",
  "total_endpoints": $total_endpoints,
  "source": "$SOURCE",
  "endpoints": $endpoints_json
}
EOF
  )
fi

atomic_write_json "$OUTPUT_DIR/l2-api.json" "$output"

log_info "L2 API: total_endpoints=$total_endpoints, source=$SOURCE"
log_info "Output: $OUTPUT_DIR/l2-api.json"
