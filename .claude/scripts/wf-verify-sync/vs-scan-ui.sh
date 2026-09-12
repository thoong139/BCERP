#!/usr/bin/env bash
# vs-scan-ui.sh — Phase 3: UI screen-to-feature matcher
# Usage: bash vs-scan-ui.sh --registry <file> [--output <file>] [--interface-type <type>]
# Output: ui-scan-results.json → {screens[], matches[], categories{}, coverage_pct, partial_coverage_pct}
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
REGISTRY_FILE="${REGISTRY_PATH}"
OUTPUT_FILE="/dev/stdout"
INTERFACE_TYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --interface-type) INTERFACE_TYPE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_jq

# ---------------------------------------------------------------------------
# Infrastructure auto-skip list
# ---------------------------------------------------------------------------
# Next.js App Router special files and patterns that are infrastructure, not business screens
INFRA_PATTERNS=(
  "layout.tsx" "layout.ts" "layout.jsx" "layout.js"
  "error.tsx" "error.ts" "error.jsx" "error.js"
  "loading.tsx" "loading.ts" "loading.jsx" "loading.js"
  "template.tsx" "template.ts" "template.jsx" "template.js"
  "default.tsx" "default.ts" "default.jsx" "default.js"
  "global-error.tsx" "global-error.ts" "global-error.jsx" "global-error.js"
  "not-found.tsx" "not-found.ts" "not-found.jsx" "not-found.js"
  "head.tsx" "head.ts" "head.jsx" "head.js"
  "middleware.ts" "middleware.tsx" "middleware.js"
  "_app.tsx" "_app.ts" "_app.jsx" "_app.js"
  "_document.tsx" "_document.ts" "_document.jsx" "_document.js"
  "opengraph-image.tsx" "opengraph-image.ts" "opengraph-image.jsx"
  "sitemap.ts" "sitemap.tsx"
  "robots.ts" "robots.tsx"
  "favicon.ico" "icon.tsx" "icon.ts" "icon.jsx"
  "apple-icon.tsx" "apple-icon.ts" "apple-icon.jsx"
  "route.ts" "route.tsx" "route.js"
)

# ---------------------------------------------------------------------------
# Check if a screen file is infrastructure
# ---------------------------------------------------------------------------
is_infrastructure() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  # Check against all infra patterns
  for pattern in "${INFRA_PATTERNS[@]}"; do
    if [[ "$basename" == "$pattern" ]]; then
      return 0
    fi
  done

  # Check for parallel route slots (@slot directories)
  # Literal ( ) @ \ phải nằm trong quote — parens không quote làm bash parser lỗi
  if [[ "$file" == *"/@/"* ]] || [[ "$file" == *'\@\'* ]]; then
    return 0
  fi

  # Check for intercepting route segments
  if [[ "$file" == *"/("*")"/* ]] && [[ "$file" != *"("*")/page."* ]]; then
    # Route groups: (name)/ is NOT infrastructure, (.) and (..) are
    if [[ "$file" == *"/(.)"* ]] || [[ "$file" == *"/(..)"* ]]; then
      return 0
    fi
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Extract module hint from file path
# ---------------------------------------------------------------------------
get_module_hint() {
  local file="$1"

  # Try to extract module name from path structure
  # e.g. src/app/dashboard/page.tsx → dashboard
  # e.g. app/settings/profile/page.tsx → settings
  local dir
  dir=$(dirname "$file")

  # Extract the segment after app/ or src/app/
  if [[ "$dir" =~ app/([^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$dir" =~ pages/([^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------------------------
# Scan UI directories
# ---------------------------------------------------------------------------
scan_ui_dirs() {
  local ui_dirs=("app" "pages" "src/app" "src/pages")
  local screens=()

  for dir in "${ui_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      # Find page, screen, and component files in UI directories
      while IFS= read -r -d '' file; do
        # Filter: only page/component files
        local basename
        basename=$(basename "$file")
        local ext="${basename##*.}"

        # Accept: tsx, jsx, ts, js (component and page files)
        case "$ext" in
          tsx|jsx|ts|js) ;;
          *) continue ;;
        esac

        # Skip node_modules, dist, .next inside UI dirs
        if [[ "$file" == *"node_modules"* ]] || [[ "$file" == *"/dist/"* ]] || [[ "$file" == *"/.next/"* ]]; then
          continue
        fi

        local is_infra="false"
        if is_infrastructure "$file"; then
          is_infra="true"
        fi

        local mod_hint
        mod_hint=$(get_module_hint "$file")

        # Extract a display name
        local display_name="$basename"
        if [[ "$basename" == "page."* ]]; then
          display_name="$(basename "$(dirname "$file")")/page"
        fi

        screens+=("$(jq -cn \
          --arg path "$file" \
          --arg name "$display_name" \
          --arg is_infra "$is_infra" \
          --arg mod_hint "$mod_hint" \
          '{path: $path, name: $name, is_infrastructure: ($is_infra == "true"), module_hint: $mod_hint}')")

      done < <(find "$dir" -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.ts" -o -name "*.js" \) -print0 2>/dev/null || true)
    fi
  done

  printf '%s\n' "${screens[@]}"
}

# ---------------------------------------------------------------------------
# Match screens to features via jq
# ---------------------------------------------------------------------------
main() {
  # Determine interface type
  if [[ -z "$INTERFACE_TYPE" ]]; then
    INTERFACE_TYPE=$(jq -r '.interface_type // "web"' "$REGISTRY_FILE" 2>/dev/null || echo "web")
  fi

  if [[ "$INTERFACE_TYPE" == "api-only" ]]; then
    info "vs-scan-ui.sh: interface_type=api-only — skipping UI scan"
    jq -n '{
      screens: [],
      total_screens: 0,
      total_business_screens: 0,
      infrastructure_count: 0,
      empty_project: true,
      skipped: true,
      skip_reason: "api_only",
      matches: {},
      coverage_pct: null,
      partial_coverage_pct: null
    }' > "$OUTPUT_FILE"
    return
  fi

  info "vs-scan-ui.sh: Scanning UI screens..."

  # Check if any UI directories exist
  local has_ui_dirs=false
  for dir in app pages src/app src/pages; do
    if [[ -d "$dir" ]]; then
      has_ui_dirs=true
      break
    fi
  done

  if ! $has_ui_dirs; then
    info "No UI directories found — skipping UI scan"
    jq -n '{
      screens: [],
      total_screens: 0,
      total_business_screens: 0,
      infrastructure_count: 0,
      empty_project: true,
      skipped: true,
      skip_reason: "no_ui_directories",
      matches: {},
      coverage_pct: null,
      partial_coverage_pct: null
    }' > "$OUTPUT_FILE"
    return
  fi

  # Scan UI directories
  local screens_json
  screens_json=$(scan_ui_dirs | jq -s '.')

  local total_screens
  total_screens=$(echo "$screens_json" | jq -r 'length')

  if [[ "$total_screens" -eq 0 ]]; then
    jq -n '{
      screens: [],
      total_screens: 0,
      total_business_screens: 0,
      infrastructure_count: 0,
      empty_project: true,
      skipped: true,
      skip_reason: "no_screens_found",
      matches: {},
      coverage_pct: null,
      partial_coverage_pct: null
    }' > "$OUTPUT_FILE"
    return
  fi

  # Get features from registry
  local features_json
  features_json=$(jq -c '[.features // [] | .[] | {id: .id, name: .name, module_id: .module_id, file: (.file // null), req_ids: (.req_ids // [])}]' "$REGISTRY_FILE")

  # Classify screens using jq
  local infra_count
  infra_count=$(echo "$screens_json" | jq -r '[.[] | select(.is_infrastructure == true)] | length')

  local business_screens
  business_screens=$(echo "$screens_json" | jq -c '[.[] | select(.is_infrastructure == false)]')

  local business_count
  business_count=$(echo "$business_screens" | jq -r 'length')

  # Match business screens to features
  jq -n \
    --argjson screens "$screens_json" \
    --argjson features "$features_json" \
    --argjson total "$total_screens" \
    --argjson infra "$infra_count" \
    --argjson business "$business_count" \
    --argjson business_screens "$business_screens" \
  '
    # Match each business screen to features
    def match_screen($s; $feats):
      $feats | map(select(
        # Match by file path substring
        (.file != null and ($s.path | contains(.file))) or
        # Match by module hint
        (.module_id != null and .module_id == $s.module_hint) or
        # Match by name fuzzy
        (.name != null and ($s.name | ascii_downcase | contains(.name | ascii_downcase)))
      )) | if length > 0 then .[0].id else null end;

    # Build match map
    def build_matches($bs; $feats):
      [ $bs[] | {
        screen_path: .path,
        screen_name: .name,
        matched_feature: match_screen(.; $feats),
        category: (if match_screen(.; $feats) != null then "MATCHED" else "MISSING_FROM_FEATURES" end)
      } ];

    # MATCHED count
    (build_matches($business_screens; $features) | map(select(.category == "MATCHED")) | length) as $matched |

    # MISSING_FROM_FEATURES count
    (build_matches($business_screens; $features) | map(select(.category == "MISSING_FROM_FEATURES")) | length) as $missing_from_features |

    # Features without screens (MISSING_FROM_CODE)
    ([ $features[] | select(
      .id as $fid |
      ([build_matches($business_screens; $features)[] | select(.matched_feature == $fid)] | length) == 0
    ) | .id] | length) as $missing_from_code |

    # Coverage calculations
    (if $business > 0 then ($matched / $business * 100 | floor * 10 / 10) else null end) as $coverage_pct |
    (if $business > 0 then (($matched + 0) / $business * 100 | floor * 10 / 10) else null end) as $partial_coverage_pct |

    {
      screens: $screens,
      total_screens: $total,
      total_business_screens: $business,
      infrastructure_count: $infra,
      empty_project: false,
      skipped: false,
      skip_reason: null,
      matches: {
        matched_count: $matched,
        partial_match_count: 0,
        missing_from_features_count: $missing_from_features,
        missing_from_code_count: $missing_from_code,
        matched: [build_matches($business_screens; $features)[] | select(.category == "MATCHED")],
        missing_from_features: [build_matches($business_screens; $features)[] | select(.category == "MISSING_FROM_FEATURES")],
        missing_from_code: [
          $features[] | select(
            .id as $fid |
            ([build_matches($business_screens; $features)[] | select(.matched_feature == $fid)] | length) == 0
          ) | {feature_id: .id, feature_name: .name}
        ]
      },
      coverage_pct: $coverage_pct,
      partial_coverage_pct: $partial_coverage_pct
    }
  ' > "$OUTPUT_FILE"

  local matched count
  matched=$(jq -r '.matches.matched_count // 0' "$OUTPUT_FILE")
  count=$(jq -r '.matches.missing_from_features_count // 0' "$OUTPUT_FILE")

  info "UI scan complete: $total_screens total, $infra_count infra, $business_count business, $matched matched, $count missing"
  info "Output: $OUTPUT_FILE"
}

main
