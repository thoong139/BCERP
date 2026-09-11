#!/usr/bin/env bash
# wf-fix-detect-base-url.sh — Auto-detect BASE_URL cho từng app trong monorepo hoặc dự án đơn lẻ
#
# Usage:
#   bash wf-fix-detect-base-url.sh --project-root=<path> [--check-reachable] [--output=<json-path>]
#
# Output JSON format:
#   {
#     "project_root": "<path>",
#     "apps": [
#       {
#         "name": "erp-web",
#         "base_url": "http://localhost:3000",
#         "framework": "nextjs",
#         "status": "detected"
#       },
#       ...
#     ]
#   }
#
# Status values:
#   detected     — URL tự detect từ config files
#   reachable    — URL detect + HTTP check 200 (--check-reachable only)
#   unreachable  — URL detect nhưng server chưa start (--check-reachable only)
#   missing      — Không detect được framework/port
#   mobile_skip  — Mobile app (Expo), bỏ qua browser test
#
# Heuristic order (per W1.2 spec):
#   1. package.json scripts.dev / scripts.start → grep port
#   2. vite.config.{ts,js,mjs} server.port
#   3. next.config.{mjs,js,ts} (default 3000)
#   4. nuxt.config.ts server.port
#   5. docker-compose.{yml,local.yml,minimal.yml} service ports
#   6. .NET launchSettings.json applicationUrl
#
# MCV3 wf-fix-bugs v9 — Wave 1.2 (Foundation)

set -euo pipefail

# ─── Argument parsing ────────────────────────────────────────────────────────

PROJECT_ROOT=""
CHECK_REACHABLE=false
OUTPUT_FILE=""

for arg in "$@"; do
  case "$arg" in
    --project-root=*)  PROJECT_ROOT="${arg#*=}" ;;
    --check-reachable) CHECK_REACHABLE=true ;;
    --output=*)        OUTPUT_FILE="${arg#*=}" ;;
    --help|-h)
      sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
  esac
done

# Default project root to cwd
if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(pwd)"
fi

# Normalize (remove trailing slash)
PROJECT_ROOT="${PROJECT_ROOT%/}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

# JSON string escape (minimal — handle quotes and backslashes)
json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# Build JSON app entry
make_app_entry() {
  local name="$1" base_url="$2" framework="$3" status="$4" port="${5:-}"
  printf '{"name":"%s","base_url":"%s","framework":"%s","status":"%s","port":%s}' \
    "$(json_str "$name")" \
    "$(json_str "$base_url")" \
    "$(json_str "$framework")" \
    "$(json_str "$status")" \
    "${port:-null}"
}

# ─── Framework detection ─────────────────────────────────────────────────────

detect_framework() {
  local dir="$1"

  # Next.js
  if [[ -f "$dir/next.config.mjs" || -f "$dir/next.config.js" || -f "$dir/next.config.ts" ]]; then
    echo "nextjs"; return
  fi

  # Vite
  if [[ -f "$dir/vite.config.ts" || -f "$dir/vite.config.js" || -f "$dir/vite.config.mjs" ]]; then
    echo "vite"; return
  fi

  # Nuxt
  if [[ -f "$dir/nuxt.config.ts" || -f "$dir/nuxt.config.js" ]]; then
    echo "nuxt"; return
  fi

  # Expo (React Native / mobile)
  if [[ -f "$dir/package.json" ]]; then
    if grep -q '"expo"' "$dir/package.json" 2>/dev/null; then
      echo "expo"; return
    fi
    if [[ -f "$dir/app.json" ]] && grep -q '"expo"' "$dir/app.json" 2>/dev/null; then
      echo "expo"; return
    fi
  fi

  # .NET — check for .csproj file (up to 3 levels deep)
  if find "$dir" -maxdepth 3 -name "*.csproj" 2>/dev/null | grep -q .; then
    echo "dotnet"; return
  fi

  # SvelteKit
  if [[ -f "$dir/svelte.config.js" || -f "$dir/svelte.config.ts" ]]; then
    echo "sveltekit"; return
  fi

  # Angular
  if [[ -f "$dir/angular.json" ]]; then
    echo "angular"; return
  fi

  # Generic Node.js
  if [[ -f "$dir/package.json" ]]; then
    echo "node"; return
  fi

  echo "unknown"
}

# ─── Port detection ───────────────────────────────────────────────────────────

# Extract port from package.json scripts.dev or scripts.start
port_from_package_json() {
  local dir="$1"
  local pkg="$dir/package.json"
  [[ -f "$pkg" ]] || return

  # Try --port X or --port=X pattern in dev/start scripts (using -E for portability)
  local port
  port=$(grep -oE -- '--port[= ][0-9]{4,5}' "$pkg" 2>/dev/null | \
         grep -oE '[0-9]{4,5}' | head -1) || true
  echo "${port:-}"
}

# Extract port from vite config
port_from_vite_config() {
  local dir="$1"
  local conf
  for f in "$dir/vite.config.ts" "$dir/vite.config.js" "$dir/vite.config.mjs"; do
    [[ -f "$f" ]] && conf="$f" && break
  done
  [[ -n "${conf:-}" ]] || return

  # Look for port: XXXX pattern (handles port: 3001, port:3001, port : 3001)
  local port
  port=$(grep -E 'port[[:space:]]*:[[:space:]]*[0-9]{4,5}' "$conf" 2>/dev/null | \
         grep -oE '[0-9]{4,5}' | head -1) || true
  echo "${port:-}"
}

# Extract port from nuxt config
port_from_nuxt_config() {
  local dir="$1"
  local conf
  for f in "$dir/nuxt.config.ts" "$dir/nuxt.config.js"; do
    [[ -f "$f" ]] && conf="$f" && break
  done
  [[ -n "${conf:-}" ]] || return

  local port
  port=$(grep -E 'port[[:space:]]*:[[:space:]]*[0-9]{4,5}' "$conf" 2>/dev/null | \
         grep -oE '[0-9]{4,5}' | head -1) || true
  echo "${port:-}"
}

# Extract port from .NET launchSettings.json
port_from_dotnet() {
  local dir="$1"
  # Find launchSettings.json (typically in Properties/)
  local settings
  settings=$(find "$dir" -maxdepth 4 -name "launchSettings.json" 2>/dev/null | head -1)
  [[ -n "$settings" ]] || return

  # Extract first localhost HTTP port — prefer plain HTTP (not HTTPS) lines
  # Pattern: "applicationUrl": "http://localhost:5048"
  local port
  port=$(grep -E '"http://localhost:[0-9]+"' "$settings" 2>/dev/null | \
         grep -oE 'localhost:[0-9]+' | \
         grep -oE '[0-9]{4,5}' | head -1) || true
  # Fallback: any localhost port
  if [[ -z "$port" ]]; then
    port=$(grep -oE 'localhost:[0-9]+' "$settings" 2>/dev/null | \
           grep -oE '[0-9]{4,5}' | head -1) || true
  fi
  echo "${port:-}"
}

# Extract port from docker-compose (for a specific service matching app name)
port_from_docker_compose() {
  local dir="$1"
  local app_name="$2"
  local root_dir="${3:-$dir}"

  # Check docker-compose files in app dir and project root
  local dc_files=()
  for f in "$dir/docker-compose.yml" "$dir/docker-compose.local.yml" \
            "$root_dir/docker-compose.yml" "$root_dir/docker-compose.local.yml" \
            "$root_dir/docker-compose.minimal.yml"; do
    [[ -f "$f" ]] && dc_files+=("$f")
  done

  [[ ${#dc_files[@]} -eq 0 ]] && return

  # Search for service with app_name, extract first port mapping (HOST:CONTAINER)
  local port
  # Port mapping format: "HHHH:CCCC" — extract host port (first 4-5 digit sequence before colon)
  port=$(grep -h -A5 "image:.*${app_name}\|${app_name}:" "${dc_files[@]}" 2>/dev/null | \
         grep -oE '"[0-9]{4,5}:[0-9]{4,5}"' | \
         grep -oE '^"[0-9]+' | \
         grep -oE '[0-9]{4,5}' | head -1) || true
  echo "${port:-}"
}

# Master port resolver
detect_port() {
  local dir="$1"
  local framework="$2"
  local app_name="$3"

  local port=""

  case "$framework" in
    nextjs)
      # 1. package.json scripts for explicit --port
      port=$(port_from_package_json "$dir")
      # 2. docker-compose
      [[ -z "$port" ]] && port=$(port_from_docker_compose "$dir" "$app_name" "$PROJECT_ROOT")
      # 3. Default Next.js port
      echo "${port:-3000}"
      ;;
    vite)
      # 1. vite.config server.port (most reliable)
      port=$(port_from_vite_config "$dir")
      # 2. package.json
      [[ -z "$port" ]] && port=$(port_from_package_json "$dir")
      # 3. docker-compose
      [[ -z "$port" ]] && port=$(port_from_docker_compose "$dir" "$app_name" "$PROJECT_ROOT")
      # 4. Default Vite port
      echo "${port:-5173}"
      ;;
    nuxt)
      port=$(port_from_nuxt_config "$dir")
      [[ -z "$port" ]] && port=$(port_from_package_json "$dir")
      echo "${port:-3000}"
      ;;
    dotnet)
      port=$(port_from_dotnet "$dir")
      [[ -z "$port" ]] && port=$(port_from_docker_compose "$dir" "$app_name" "$PROJECT_ROOT")
      echo "${port:-5000}"
      ;;
    sveltekit)
      port=$(port_from_vite_config "$dir")
      echo "${port:-5173}"
      ;;
    angular)
      port=$(port_from_package_json "$dir")
      echo "${port:-4200}"
      ;;
    node)
      port=$(port_from_package_json "$dir")
      [[ -z "$port" ]] && port=$(port_from_docker_compose "$dir" "$app_name" "$PROJECT_ROOT")
      echo "${port:-3000}"
      ;;
    *)
      echo "3000"
      ;;
  esac
}

# ─── Reachability check ───────────────────────────────────────────────────────

check_reachable() {
  local url="$1"
  # Use curl with short timeout; HTTP 2xx or 3xx = reachable
  if curl --max-time 5 --silent --output /dev/null --write-out '%{http_code}' "$url" 2>/dev/null | \
     grep -qE '^[23]'; then
    echo "reachable"
  else
    echo "unreachable"
  fi
}

# ─── Scan single app directory ────────────────────────────────────────────────

scan_app_dir() {
  local dir="$1"
  local app_name="$2"

  local framework
  framework=$(detect_framework "$dir")

  # Mobile apps — skip browser testing
  if [[ "$framework" == "expo" ]]; then
    make_app_entry "$app_name" "" "expo" "mobile_skip"
    return
  fi

  local port
  port=$(detect_port "$dir" "$framework" "$app_name")

  local base_url="http://localhost:${port}"
  local status="detected"

  if [[ "$CHECK_REACHABLE" == "true" ]]; then
    status=$(check_reachable "$base_url")
  fi

  make_app_entry "$app_name" "$base_url" "$framework" "$status" "$port"
}

# ─── Main scan logic ──────────────────────────────────────────────────────────

apps_entries=()

if [[ -d "$PROJECT_ROOT/apps" ]]; then
  # Monorepo layout: scan apps/ subdirectories
  for app_dir in "$PROJECT_ROOT/apps"/*/; do
    if [[ -d "$app_dir" ]]; then
      app_name=$(basename "$app_dir")
      entry=$(scan_app_dir "$app_dir" "$app_name")
      apps_entries+=("$entry")
    fi
  done
else
  # Single-app layout: scan project root
  app_name=$(basename "$PROJECT_ROOT")
  entry=$(scan_app_dir "$PROJECT_ROOT" "$app_name")
  apps_entries+=("$entry")
fi

# ─── Build output JSON ────────────────────────────────────────────────────────

apps_json_inner=""
for entry in "${apps_entries[@]}"; do
  if [[ -z "$apps_json_inner" ]]; then
    apps_json_inner="$entry"
  else
    apps_json_inner="${apps_json_inner},${entry}"
  fi
done

output_json=$(printf '{"project_root":"%s","apps":[%s]}' \
  "$(json_str "$PROJECT_ROOT")" \
  "${apps_json_inner}")

# ─── Output ───────────────────────────────────────────────────────────────────

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$output_json" > "$OUTPUT_FILE"
  echo "[wf-fix-detect-base-url] Output written to: $OUTPUT_FILE" >&2
fi

echo "$output_json"
