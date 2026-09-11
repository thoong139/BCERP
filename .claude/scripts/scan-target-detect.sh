#!/usr/bin/env bash
# scan-target-detect.sh — Tech stack detection cho wf-scan-target Phase 1
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/scan-target-detect.sh <target-path> <output-dir>
#
# Output: $output_dir/tech-stack.json
#
# Detects:
#   - Node-based: nextjs, react-native, vue, hono, express, angular, nuxt, svelte, react-spa
#   - .NET: dotnet (with ddd-cqrs vs standard pattern)
#   - Java: java-spring (pom.xml or build.gradle)
#   - Go: go (go.mod)
#   - Python: python (requirements.txt or pyproject.toml)
#   - PHP: php-laravel (composer.json)
#   - Generic: empty array → caller fallback to "generic"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-detect"
# shellcheck source=./scan-target-common.sh
source "$SCRIPTS_DIR/scan-target-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Args ────────────────────────────────────────────────────

TARGET="${1:?Usage: $0 <target-path> <output-dir>}"
OUTPUT_DIR="${2:?Output dir required}"

if [[ ! -d "$TARGET" ]]; then
  log_error "Target path not a directory or does not exist: $TARGET"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
log_info "Detecting tech stack at: $TARGET"

# ─── State ───────────────────────────────────────────────────

declare -a tech_stacks=()
dotnet_pattern=""
monorepo="false"
frontend_present="false"
backend_present="false"

# ─── Helpers ─────────────────────────────────────────────────

# Add to tech_stacks if not duplicate
add_tech() {
  local t="$1"
  for existing in "${tech_stacks[@]:-}"; do
    [[ "$existing" == "$t" ]] && return 0
  done
  tech_stacks+=("$t")
}

# ─── Detect monorepo (workspaces in package.json) ───────────

if [[ -f "$TARGET/package.json" ]]; then
  if has_jq && jq -e '.workspaces' "$TARGET/package.json" >/dev/null 2>&1; then
    monorepo="true"
    log_debug "Monorepo detected (package.json workspaces)"
  fi
fi

# Pnpm workspace
if [[ -f "$TARGET/pnpm-workspace.yaml" ]]; then
  monorepo="true"
  log_debug "Monorepo detected (pnpm-workspace.yaml)"
fi

# Lerna
if [[ -f "$TARGET/lerna.json" ]]; then
  monorepo="true"
  log_debug "Monorepo detected (lerna.json)"
fi

# ─── Detect Node-based frameworks ───────────────────────────

inspect_pkg_json() {
  local pkg="$1"
  [[ ! -f "$pkg" ]] && return 0
  if ! has_jq; then
    if grep -qE '"next"\s*:' "$pkg" 2>/dev/null; then add_tech "nextjs"; frontend_present="true"; fi
    if grep -qE '"react-native"\s*:' "$pkg" 2>/dev/null; then add_tech "react-native"; frontend_present="true"; fi
    if grep -qE '"(vue|nuxt)"\s*:' "$pkg" 2>/dev/null; then add_tech "vue"; frontend_present="true"; fi
    if grep -qE '"hono"\s*:' "$pkg" 2>/dev/null; then add_tech "hono"; backend_present="true"; fi
    if grep -qE '"express"\s*:' "$pkg" 2>/dev/null; then add_tech "express"; backend_present="true"; fi
    if grep -qE '"@angular/core"\s*:' "$pkg" 2>/dev/null; then add_tech "angular"; frontend_present="true"; fi
    if grep -qE '"svelte"\s*:' "$pkg" 2>/dev/null; then add_tech "svelte"; frontend_present="true"; fi
    return 0
  fi

  local deps
  deps=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' "$pkg" 2>/dev/null || echo "")

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    case "$dep" in
      next)              add_tech "nextjs"; frontend_present="true" ;;
      react-native|expo) add_tech "react-native"; frontend_present="true" ;;
      vue|nuxt|@vue/cli) add_tech "vue"; frontend_present="true" ;;
      hono)              add_tech "hono"; backend_present="true" ;;
      express|fastify|koa) add_tech "express"; backend_present="true" ;;
      "@angular/core")   add_tech "angular"; frontend_present="true" ;;
      svelte|@sveltejs/kit) add_tech "svelte"; frontend_present="true" ;;
    esac
  done <<< "$deps"

  # SPA detection: react without next
  if jq -e '.dependencies.react // .devDependencies.react' "$pkg" >/dev/null 2>&1; then
    if ! jq -e '.dependencies.next // .devDependencies.next' "$pkg" >/dev/null 2>&1; then
      add_tech "react-spa"
      frontend_present="true"
    fi
  fi
}

inspect_pkg_json "$TARGET/package.json"

# Monorepo apps/*/package.json (max 10 to avoid slow scans)
if [[ "$monorepo" == "true" && -d "$TARGET/apps" ]]; then
  while IFS= read -r app_pkg; do
    inspect_pkg_json "$app_pkg"
  done < <(find "$TARGET/apps" -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' 2>/dev/null | head -10)
fi

if [[ "$monorepo" == "true" && -d "$TARGET/packages" ]]; then
  while IFS= read -r pkg_pkg; do
    inspect_pkg_json "$pkg_pkg"
  done < <(find "$TARGET/packages" -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' 2>/dev/null | head -10)
fi

# ─── Detect .NET ─────────────────────────────────────────────

dotnet_csproj_count=$(find "$TARGET" -maxdepth 4 -name '*.csproj' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -5 | wc -l)
dotnet_sln_count=$(find "$TARGET" -maxdepth 3 -name '*.sln' 2>/dev/null | head -3 | wc -l)

if [[ "$dotnet_csproj_count" -gt 0 || "$dotnet_sln_count" -gt 0 ]]; then
  backend_present="true"
  if [[ -d "$TARGET/Domain" && -d "$TARGET/Application" && -d "$TARGET/Infrastructure" ]]; then
    dotnet_pattern="ddd-cqrs"
  elif find "$TARGET" -maxdepth 4 -type d -name 'Domain' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | grep -q .; then
    if find "$TARGET" -maxdepth 4 -type d -name 'Application' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | grep -q .; then
      dotnet_pattern="ddd-cqrs"
    else
      dotnet_pattern="standard"
    fi
  else
    dotnet_pattern="standard"
  fi
  add_tech "dotnet-${dotnet_pattern}"
fi

# ─── Detect Java ─────────────────────────────────────────────

if [[ -f "$TARGET/pom.xml" ]] || find "$TARGET" -maxdepth 3 -name 'pom.xml' 2>/dev/null | head -1 | grep -q .; then
  add_tech "java-spring"
  backend_present="true"
fi
if [[ -f "$TARGET/build.gradle" || -f "$TARGET/build.gradle.kts" ]]; then
  add_tech "java-gradle"
  backend_present="true"
fi

# ─── Detect Go ───────────────────────────────────────────────

if [[ -f "$TARGET/go.mod" ]] || find "$TARGET" -maxdepth 3 -name 'go.mod' 2>/dev/null | head -1 | grep -q .; then
  add_tech "go"
  backend_present="true"
fi

# ─── Detect Python ───────────────────────────────────────────

if [[ -f "$TARGET/requirements.txt" || -f "$TARGET/pyproject.toml" || -f "$TARGET/setup.py" ]]; then
  add_tech "python"
  backend_present="true"
fi

# ─── Detect PHP ──────────────────────────────────────────────

if [[ -f "$TARGET/composer.json" ]]; then
  if has_jq && jq -e '.require."laravel/framework"' "$TARGET/composer.json" >/dev/null 2>&1; then
    add_tech "php-laravel"
  else
    add_tech "php"
  fi
  backend_present="true"
fi

# ─── Detect Flutter ──────────────────────────────────────────

if [[ -f "$TARGET/pubspec.yaml" ]]; then
  add_tech "flutter"
  frontend_present="true"
fi

# ─── Build output JSON ───────────────────────────────────────

tech_json="[]"
if [[ ${#tech_stacks[@]} -gt 0 ]]; then
  if has_jq; then
    tech_json=$(printf '%s\n' "${tech_stacks[@]}" | sort -u | jq -R . | jq -s .)
  else
    tech_json="["
    first=1
    for t in "${tech_stacks[@]}"; do
      [[ $first -eq 0 ]] && tech_json+=","
      tech_json+="\"$(json_escape "$t")\""
      first=0
    done
    tech_json+="]"
  fi
fi

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
target_norm=$(normalize_path "$TARGET")

if has_jq; then
  output=$(jq -n \
    --arg gen "$generated_at" \
    --arg target "$target_norm" \
    --argjson tech "$tech_json" \
    --argjson monorepo "$monorepo" \
    --arg dpat "$dotnet_pattern" \
    --argjson fe "$frontend_present" \
    --argjson be "$backend_present" \
    '{
      "$schema": "scan-target-tech-stack-v1",
      generated_at: $gen,
      target: $target,
      monorepo: $monorepo,
      tech_stacks: $tech,
      dotnet_pattern: (if $dpat == "" then null else $dpat end),
      frontend_present: $fe,
      backend_present: $be
    }')
else
  dpat_field='null'
  [[ -n "$dotnet_pattern" ]] && dpat_field="\"$dotnet_pattern\""
  output=$(cat <<EOF
{
  "\$schema": "scan-target-tech-stack-v1",
  "generated_at": "$generated_at",
  "target": "$(json_escape "$target_norm")",
  "monorepo": $monorepo,
  "tech_stacks": $tech_json,
  "dotnet_pattern": $dpat_field,
  "frontend_present": $frontend_present,
  "backend_present": $backend_present
}
EOF
  )
fi

atomic_write_json "$OUTPUT_DIR/tech-stack.json" "$output"

log_info "Detected tech_stacks: ${tech_stacks[*]:-(none)} | monorepo=$monorepo | dotnet_pattern=${dotnet_pattern:-none}"
log_info "Output: $OUTPUT_DIR/tech-stack.json"
