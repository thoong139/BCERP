#!/usr/bin/env bash
# scan-target-ui.sh — UI screens & components discovery cho wf-scan-target Phase 2 L3
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/scan-target-ui.sh <scan-root> <output-dir> <tech-stack-json>
#
# Output: $output_dir/l3-ui.json
#
# Detects (LOCAL SOURCE ONLY — URL crawl giữ AI vì cần WebFetch + CDG-07):
#   - Next.js: app/**/page.tsx → routes (extract from path)
#   - React Native: screens/**/*.tsx + screens/*.screen.tsx
#   - Vue: pages/**/*.vue
#   - Components: components/**/*.tsx
#
# Output JSON shape:
# {
#   "$schema": "scan-target-l3-v1",
#   "generated_at": "...",
#   "scan_root": "...",
#   "total_screens": 25,
#   "total_components": 80,
#   "source": "code_scan",
#   "screens": [
#     {"name": "CustomerList", "route": "/crm/customers", "file": "...", "type": "page"},
#     ...
#   ],
#   "components": [
#     {"name": "Button", "file": "...", "type": "ui"},
#     ...
#   ]
# }

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="scan-target-ui"
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
log_info "Scanning UI at: $SCAN_ROOT"

# ─── Read tech_stacks ──────────────────────────────────────

declare -a tech_stacks=()
backend_only="false"
if [[ -n "$TECH_JSON" && -f "$TECH_JSON" && $(has_jq && echo y) == "y" ]]; then
  while IFS= read -r t; do
    [[ -n "$t" ]] && tech_stacks+=("$t")
  done < <(jq -r '.tech_stacks[]?' "$TECH_JSON" 2>/dev/null || echo "")

  fe=$(jq -r '.frontend_present // false' "$TECH_JSON" 2>/dev/null)
  be=$(jq -r '.backend_present // false' "$TECH_JSON" 2>/dev/null)
  if [[ "$fe" == "false" && "$be" == "true" ]]; then
    backend_only="true"
  fi
fi

has_tech() {
  local query="$1"
  for t in "${tech_stacks[@]:-}"; do
    [[ "$t" == *"$query"* ]] && return 0
  done
  return 1
}

# ─── Backend-only short-circuit ─────────────────────────────

if [[ "$backend_only" == "true" ]]; then
  log_info "Backend-only target detected — no UI screens"
  output=$(cat <<EOF
{
  "\$schema": "scan-target-l3-v1",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scan_root": "$(json_escape "$(normalize_path "$SCAN_ROOT")")",
  "total_screens": 0,
  "total_components": 0,
  "source": "skipped",
  "skip_reason": "backend-only target",
  "screens": [],
  "components": []
}
EOF
  )
  atomic_write_json "$OUTPUT_DIR/l3-ui.json" "$output"
  log_info "Output: $OUTPUT_DIR/l3-ui.json"
  exit 0
fi

# ─── Accumulators ───────────────────────────────────────────

SCREENS_TMP=$(mktemp)
COMPONENTS_TMP=$(mktemp)
trap 'rm -f "$SCREENS_TMP" "$COMPONENTS_TMP"' EXIT

emit_screen() {
  local name="$1"
  local route="$2"
  local file="$3"
  local type="${4:-page}"

  if has_jq; then
    jq -nc \
      --arg n "$name" \
      --arg r "$route" \
      --arg f "$file" \
      --arg t "$type" \
      '{name: $n, route: $r, file: $f, type: $t}' \
      >> "$SCREENS_TMP"
  else
    echo "{\"name\":\"$(json_escape "$name")\",\"route\":\"$(json_escape "$route")\",\"file\":\"$(json_escape "$file")\",\"type\":\"$(json_escape "$type")\"}" >> "$SCREENS_TMP"
  fi
}

emit_component() {
  local name="$1"
  local file="$2"
  local type="${3:-shared}"

  if has_jq; then
    jq -nc \
      --arg n "$name" \
      --arg f "$file" \
      --arg t "$type" \
      '{name: $n, file: $f, type: $t}' \
      >> "$COMPONENTS_TMP"
  else
    echo "{\"name\":\"$(json_escape "$name")\",\"file\":\"$(json_escape "$file")\",\"type\":\"$(json_escape "$type")\"}" >> "$COMPONENTS_TMP"
  fi
}

# ─── Helper: extract default export name from .tsx file ────

extract_component_name() {
  local f="$1"
  local default_name="$2"
  # Try: export default function Foo
  local n
  n=$(grep -oE 'export\s+default\s+function\s+[A-Z][a-zA-Z0-9_]*' "$f" 2>/dev/null | head -1 | awk '{print $NF}')
  [[ -n "$n" ]] && { echo "$n"; return; }
  # Try: const Foo = ; export default Foo
  n=$(grep -oE 'export\s+default\s+[A-Z][a-zA-Z0-9_]*' "$f" 2>/dev/null | head -1 | awk '{print $NF}')
  [[ -n "$n" ]] && { echo "$n"; return; }
  echo "$default_name"
}

# ─── Next.js ────────────────────────────────────────────────

if has_tech "nextjs"; then
  log_debug "Scanning Next.js pages..."

  # App Router: src/app/**/page.tsx
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    # Extract route từ path: src/app/[locale]/(dashboard)/crm/customers/page.tsx → /crm/customers
    route=$(echo "$rel" | sed -E 's|^.*/?app/||; s|/page\.(tsx|jsx)$||')
    # Strip route groups (group)
    route=$(echo "$route" | sed -E 's|/?\([^)]*\)||g')
    # Strip parallel slots @slot
    route=$(echo "$route" | sed -E 's|/@[a-zA-Z0-9_-]+||g')
    # Replace dynamic [param] with :param
    route=$(echo "$route" | sed 's|\[\([^]]*\)\]|:\1|g')
    [[ -z "$route" ]] && route="/"
    [[ "$route" != /* ]] && route="/$route"

    name=$(extract_component_name "$f" "$(basename "$(dirname "$f")")")
    emit_screen "$name" "$route" "$rel" "page"
  done < <(find "$SCAN_ROOT" -type f \( -name 'page.tsx' -o -name 'page.jsx' \) \
              ! -path '*/node_modules/*' ! -path '*/.next/*' 2>/dev/null | head -300)

  # Pages Router fallback: src/pages/**/*.tsx
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    # Skip api routes (already in L2) and underscore _app/_document
    [[ "$rel" =~ /api/ ]] && continue
    fname=$(basename "$f")
    [[ "$fname" =~ ^_ ]] && continue

    route=$(echo "$rel" | sed -E 's|^.*/?pages/||; s|\.(tsx|jsx)$||; s|/index$||')
    route=$(echo "$route" | sed 's|\[\([^]]*\)\]|:\1|g')
    [[ -z "$route" ]] && route="/"
    [[ "$route" != /* ]] && route="/$route"

    name=$(extract_component_name "$f" "$(basename "$f" .tsx)")
    emit_screen "$name" "$route" "$rel" "page"
  done < <(find "$SCAN_ROOT" -type f \( -name '*.tsx' -o -name '*.jsx' \) \
              -path '*/pages/*' ! -path '*/node_modules/*' ! -path '*/api/*' 2>/dev/null | head -200)

  # Components
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    name=$(basename "$f" .tsx)
    name=$(basename "$name" .jsx)
    type="shared"
    [[ "$rel" =~ /ui/ ]] && type="ui"
    emit_component "$name" "$rel" "$type"
  done < <(find "$SCAN_ROOT" -type f \( -name '*.tsx' -o -name '*.jsx' \) \
              -path '*/components/*' ! -path '*/node_modules/*' 2>/dev/null | head -200)
fi

# ─── React Native ───────────────────────────────────────────

if has_tech "react-native"; then
  log_debug "Scanning React Native screens..."

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    name=$(basename "$f" .tsx)
    # Strip .screen suffix if exists
    name="${name%.screen}"
    name=$(extract_component_name "$f" "$name")
    emit_screen "$name" "" "$rel" "screen"
  done < <(find "$SCAN_ROOT" -type f \( -name '*.tsx' -o -name '*.screen.tsx' \) \
              \( -path '*/screens/*' -o -path '*/app/*' \) \
              ! -path '*/node_modules/*' ! -path '*/components/*' 2>/dev/null | head -200)

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    name=$(basename "$f" .tsx)
    emit_component "$name" "$rel" "component"
  done < <(find "$SCAN_ROOT" -type f -name '*.tsx' \
              -path '*/components/*' ! -path '*/node_modules/*' 2>/dev/null | head -200)
fi

# ─── Vue ────────────────────────────────────────────────────

if has_tech "vue"; then
  log_debug "Scanning Vue pages..."

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    route=$(echo "$rel" | sed -E 's|^.*/?pages/||; s|\.vue$||; s|/index$||')
    [[ -z "$route" ]] && route="/"
    [[ "$route" != /* ]] && route="/$route"
    name=$(basename "$f" .vue)
    emit_screen "$name" "$route" "$rel" "page"
  done < <(find "$SCAN_ROOT" -type f -name '*.vue' \
              -path '*/pages/*' ! -path '*/node_modules/*' 2>/dev/null | head -200)

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel=$(compute_rel_path "$f" "$SCAN_ROOT")
    name=$(basename "$f" .vue)
    emit_component "$name" "$rel" "component"
  done < <(find "$SCAN_ROOT" -type f -name '*.vue' \
              -path '*/components/*' ! -path '*/node_modules/*' 2>/dev/null | head -200)
fi

# ─── Build final JSON ──────────────────────────────────────

total_screens=0
total_components=0
screens_json="[]"
components_json="[]"

if [[ -s "$SCREENS_TMP" ]] && has_jq; then
  screens_json=$(head -200 "$SCREENS_TMP" | jq -s 'unique_by({name, file}) // []')
  total_screens=$(echo "$screens_json" | jq 'length')
fi
if [[ -s "$COMPONENTS_TMP" ]] && has_jq; then
  components_json=$(head -200 "$COMPONENTS_TMP" | jq -s 'unique_by({name, file}) // []')
  total_components=$(echo "$components_json" | jq 'length')
fi

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
scan_root_norm=$(normalize_path "$SCAN_ROOT")

if has_jq; then
  output=$(jq -n \
    --arg gen "$generated_at" \
    --arg root "$scan_root_norm" \
    --argjson ts "$total_screens" \
    --argjson tc "$total_components" \
    --argjson scr "$screens_json" \
    --argjson cmp "$components_json" \
    '{
      "$schema": "scan-target-l3-v1",
      generated_at: $gen,
      scan_root: $root,
      total_screens: $ts,
      total_components: $tc,
      source: "code_scan",
      screens: $scr,
      components: $cmp
    }')
else
  output=$(cat <<EOF
{
  "\$schema": "scan-target-l3-v1",
  "generated_at": "$generated_at",
  "scan_root": "$(json_escape "$scan_root_norm")",
  "total_screens": $total_screens,
  "total_components": $total_components,
  "source": "code_scan",
  "screens": $screens_json,
  "components": $components_json
}
EOF
  )
fi

atomic_write_json "$OUTPUT_DIR/l3-ui.json" "$output"

log_info "L3 UI: total_screens=$total_screens, total_components=$total_components"
log_info "Output: $OUTPUT_DIR/l3-ui.json"
