#!/usr/bin/env bash
# legacy-scan-inventory.sh — Deterministic inventory cho wf-legacy-scan Stage 1
# Usage: bash .claude/scripts/legacy-scan-inventory.sh <project-path> <output-dir> <profile-json>
#
# Input:  project directory, output directory, project-profile.json
# Output: screens.json, api-endpoints.json, doc-files.json,
#         source-files.json, dependency-graph.json
#
# WHY shell script: enumeration thuan tuy — find + grep + wc. Khong can AI inference.
# Tat ca output la structured JSON de AI agent o Stage 2 doc va phan tich.
#
# Phase G refactor (v5.0):
# - Source legacy-scan-common.sh for shared UI helpers
# - Removed duplicate: parse_grep_match, classify_ui_type, is_infra_name
# - Configurable caps qua env vars (MAX_API_ENDPOINTS, MAX_SCREENS, MAX_IMPORT_FILES, MAX_IMPORTS_PER_FILE)
# - atomic_write_json + validate_json post-write cho tất cả inventory JSON outputs

# Shared library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="legacy-scan-inventory"
# shellcheck source=./legacy-scan-common.sh
source "$SCRIPTS_DIR/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

PROJECT_PATH="${1:-.}"
OUTPUT_DIR="${2:-.mc-data/work/legacy-scan/inventory}"
PROFILE_JSON="${3:-.mc-data/work/legacy-scan/project-profile.json}"

# ---------------------------------------------------------------------------
# Helpers (local overrides)
# ---------------------------------------------------------------------------

log()  { echo "[inventory] $*" >&2; }
warn() { echo "[inventory][WARN] $*" >&2; }

# Giữ v4.1 normalize_path (không convert C:/ → /c/, tránh path mismatch downstream)
normalize_path() { echo "$1" | tr '\\' '/'; }

# parse_grep_match: dùng từ common.sh (sets GREP_FILE, GREP_LINE globals — identical behavior)

# rel_path: giữ signature cũ, dùng common.sh compute_rel_path
rel_path() {
    compute_rel_path "$1" "$PROJECT_PATH"
}

# Lay kich thuoc file theo bytes (portable: stat -c tren Linux, stat -f tren macOS)
file_size() {
    local f="$1"
    if stat -c%s "$f" 2>/dev/null; then
        return
    fi
    if stat -f%z "$f" 2>/dev/null; then
        return
    fi
    # Fallback: dung wc -c
    wc -c < "$f" 2>/dev/null || echo 0
}

# Lay last-modified date (POSIX compatible)
file_mtime() {
    local f="$1"
    # GNU stat
    stat -c '%Y' "$f" 2>/dev/null && return
    # BSD/macOS stat
    stat -f '%m' "$f" 2>/dev/null && return
    echo "0"
}

# Escape chuoi cho JSON string (thay the backslash va double-quote)
json_escape() {
    local s="$1"
    # Escape backslash truoc, sau do double-quote
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    echo "$s"
}

# Cac thu muc can exclude khoi inventory
EXCLUDE_DIRS=(
    "node_modules" ".git" "dist" "build" "__pycache__"
    "vendor" "bin" "obj" ".next" ".nuxt" ".svelte-kit"
    "coverage" ".coverage" ".tox" "venv" ".venv" "env"
    "target" ".gradle" ".mvn" "Pods" ".dart_tool"
    "esp-idf" ".pub-cache" ".flutter"
    ".claude" ".mc-data" "Backup.mc-data"
)

# Xay dung array exclude cho lenh find (tranh eval — hang tren Windows Git Bash)
EXCLUDE_ARRAY=()
for d in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARRAY+=( "!" "-path" "*/$d/*" "!" "-path" "*/$d" )
done

# find wrapper voi exclude — dung array expansion thay vi eval
excluded_find() {
    find "$PROJECT_PATH" "${EXCLUDE_ARRAY[@]}" "$@" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Project path does not exist: $PROJECT_PATH" >&2
    exit 1
fi

if [ ! -f "$PROFILE_JSON" ]; then
    warn "profile-json not found at $PROFILE_JSON — proceeding without hints"
    PRIMARY_LANG="unknown"
    FRONTEND_FRAMEWORKS=""
    MOBILE_FRAMEWORKS=""
else
    # Doc hints tu profile (su dung grep vi khong co jq bao dam)
    PRIMARY_LANG="$(grep '"primary"' "$PROFILE_JSON" 2>/dev/null | grep -oE '"[a-z_]+"' | tail -1 | tr -d '"' || echo "unknown")"
    FRONTEND_FRAMEWORKS="$(grep '"frontend"' "$PROFILE_JSON" 2>/dev/null | head -1 || echo "")"
    MOBILE_FRAMEWORKS="$(grep '"mobile"' "$PROFILE_JSON" 2>/dev/null | head -1 || echo "")"
fi

mkdir -p "$OUTPUT_DIR"
log "Inventorying project: $PROJECT_PATH"
log "Primary language detected: $PRIMARY_LANG"

# Normalize PROJECT_PATH cho awk (dung trong doc-files va source-files sections)
_norm_project="$(normalize_path "$PROJECT_PATH")/"

# ---------------------------------------------------------------------------
# screens.json — UI screens / pages / views
# ---------------------------------------------------------------------------

log "Scanning screens..."

SCREENS_FILE="$OUTPUT_DIR/screens.json"
screens_entries=""

# Detect screen type tu framework hints
has_vue="false";    echo "$FRONTEND_FRAMEWORKS" | grep -qi "vue"         && has_vue="true"
has_angular="false"; echo "$FRONTEND_FRAMEWORKS" | grep -qi "angular"    && has_angular="true"
has_react="false";  echo "$FRONTEND_FRAMEWORKS" | grep -qi "react"       && has_react="true"
has_next="false";   echo "$FRONTEND_FRAMEWORKS" | grep -qi "next"        && has_next="true"
has_rn="false";     echo "$MOBILE_FRAMEWORKS"   | grep -qi "react-native\|expo" && has_rn="true"
has_flutter="false"; echo "$MOBILE_FRAMEWORKS"  | grep -qi "flutter"     && has_flutter="true"

# Hang so cho file type detection
detect_screen_type() {
    local fpath="$1"
    case "$fpath" in
        */pages/*|*/Pages/*)     echo "page" ;;
        */layouts/*|*/Layouts/*) echo "layout" ;;
        */modals/*|*/Modals/*)   echo "modal" ;;
        */screens/*|*/Screens/*) echo "page" ;;
        *)                       echo "component" ;;
    esac
}

add_screen_entry() {
    local fpath="$1"
    local framework="$2"
    local screen_type
    screen_type="$(detect_screen_type "$fpath")"
    local rel
    rel="$(rel_path "$fpath")"
    local name
    name="$(basename "$fpath")"
    local escaped_path
    escaped_path="$(json_escape "$rel")"
    local escaped_name
    escaped_name="$(json_escape "$name")"
    screens_entries="$screens_entries{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$screen_type\",\"framework\":\"$framework\"},"
}

# React / Next.js: files trong pages/, views/, screens/ hoac export default function *Page
while IFS= read -r f; do
    [ -f "$f" ] && add_screen_entry "$f" "react"
done < <(excluded_find -type f \( -name '*.tsx' -o -name '*.jsx' \) \( -path '*/pages/*' -o -path '*/views/*' -o -path '*/screens/*' -o -path '*/Screens/*' \))

# Next.js App Router: page.tsx/page.jsx trong app/ directory (v13+)
while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Tranh trung lap voi entries da co tu pages/
    echo "$f" | grep -qE "/(pages|views|screens|Screens)/" && continue
    add_screen_entry "$f" "react"
done < <(excluded_find -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' \) -path '*/app/*')

# React: files chua export default function *Page (ngoai pages dir)
while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -qE "export default function [A-Z][a-zA-Z]*Page" "$f" 2>/dev/null || continue
    # Tranh trung lap voi entries da co tu pages/, app/
    echo "$f" | grep -qE "/(pages|views|screens|Screens|app)/" && continue
    add_screen_entry "$f" "react"
done < <(excluded_find -type f \( -name '*.tsx' -o -name '*.jsx' \))

# Vue: *.vue files trong pages/, views/
if [ "$has_vue" = "true" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && add_screen_entry "$f" "vue"
    done < <(excluded_find -type f -name '*.vue' \( -path '*/pages/*' -o -path '*/views/*' \))
fi

# Angular: *.component.ts files
if [ "$has_angular" = "true" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && add_screen_entry "$f" "angular"
    done < <(excluded_find -type f -name '*.component.ts')
fi

# Flutter: Dart files trong screens/ hoac lib/screens/
if [ "$has_flutter" = "true" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && add_screen_entry "$f" "flutter"
    done < <(excluded_find -type f -name '*.dart' \( -path '*/screens/*' -o -path '*/Screens/*' -o -path '*/pages/*' \))
fi

screen_count=$({ echo "$screens_entries" | grep -o '"path"' || true; } | wc -l)
_screens_json="$(cat <<EOF
{
  "count": $screen_count,
  "items": [${screens_entries%,}]
}
EOF
)"
if ! atomic_write_json "$SCREENS_FILE" "$_screens_json"; then
    warn "atomic_write_json failed for screens.json; falling back"
    printf '%s\n' "$_screens_json" > "$SCREENS_FILE"
fi
validate_json "$SCREENS_FILE" || warn "screens.json failed JSON validation"
log "screens.json: $screen_count entries"

# ---------------------------------------------------------------------------
# ui-manifest.json — Consolidated UI structure with route mapping
# ---------------------------------------------------------------------------
# CHI chay khi screens.json co items (screen_count > 0)
# GUARD: neu screen_count == 0 → output ui-manifest.json voi empty_project: true
# ---------------------------------------------------------------------------

UI_MANIFEST_FILE="$OUTPUT_DIR/ui-manifest.json"

if [ "$screen_count" -gt 0 ]; then
    log "Generating ui-manifest.json (route mapping)..."

    # --- Framework version detection ---
    fw_next_ver="unknown"; fw_react_ver="unknown"; fw_vue_ver="unknown"; fw_angular_ver="unknown"
    if [ -f "$PROJECT_PATH/package.json" ]; then
        fw_next_ver="$(grep -oE '"next"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_PATH/package.json" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' | sed 's/[^0-9.]//g;s/\.\([^.]*\)$//' || echo "unknown")"
        fw_react_ver="$(grep -oE '"react"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_PATH/package.json" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' | sed 's/[^0-9.]//g;s/\.\([^.]*\)$//' || echo "unknown")"
        fw_vue_ver="$(grep -oE '"vue"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_PATH/package.json" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' | sed 's/[^0-9.]//g;s/\.\([^.]*\)$//' || echo "unknown")"
        fw_angular_ver="$(grep -oE '"@angular/core"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_PATH/package.json" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"' | sed 's/[^0-9.]//g;s/\.\([^.]*\)$//' || echo "unknown")"
    fi

    # --- Monorepo detection ---
    ui_project_root=""
    ui_monorepo_apps=""
    if [ -d "$PROJECT_PATH/apps" ]; then
        for app_dir in "$PROJECT_PATH/apps"/*/; do
            [ -d "$app_dir" ] || continue
            if [ -d "$app_dir/app" ] || [ -d "$app_dir/pages" ] || [ -d "$app_dir/src/app" ] || [ -d "$app_dir/src/pages" ]; then
                app_name="$(basename "$app_dir")"
                [ -z "$ui_project_root" ] && ui_project_root="apps/$app_name/"
                ui_monorepo_apps="$ui_monorepo_apps$app_name,"
            fi
        done
    fi

    # classify_ui_type, is_infra_name: dùng từ common.sh (shared với ui-coverage-scan.sh)

    manifest_screens=""
    manifest_infra=""
    manifest_route_configs=""
    ui_screens_with_routes=0
    ui_screens_without_routes=0
    ui_routes_without_screens=0
    ui_infra_count=0

    # ===== Next.js App Router: Route Detection 5 buoc =====
    # FIND → STRIP → PARALLEL → GROUP → CLASSIFY
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="$(rel_path "$f")"
        fname="$(basename "$f")"
        escaped_path="$(json_escape "$rel")"
        escaped_name="$(json_escape "$fname")"

        ui_type="$(classify_ui_type "$fname")"
        is_infra="false"
        is_infra_name "$fname" && is_infra="true"

        ui_route="null"
        ui_route_source="file-system"
        ui_route_group="null"
        ui_parallel_slot="null"
        ui_intercepts="null"
        ui_is_modal="false"
        ui_is_layout="false"

        # Buoc 2: STRIP — extract route tu file path
        dir_path="$(dirname "$rel")"
        case "$dir_path" in
            app)     dir_path="" ;;
            */app)   dir_path="" ;;
            app/*)   dir_path="${dir_path#app/}" ;;
            */app/*) dir_path="${dir_path#*/app/}" ;;
        esac

        if [ -n "$dir_path" ] && [ "$dir_path" != "." ]; then
            # Buoc 3: PARALLEL — detect @modal, @sidebar
            if echo "$dir_path" | grep -qE '@[a-zA-Z]+'; then
                slot="$(echo "$dir_path" | grep -oE '@[a-zA-Z]+' | head -1 | sed 's/^@//' || echo "")"
                if [ -n "$slot" ]; then
                    ui_parallel_slot="\"$(json_escape "$slot")\""
                    ui_is_modal="true"
                fi
                # Intercepting routes: (.)xxx, (..)xxx, (...)xxx
                intercept="$(echo "$dir_path" | grep -oE '\(\.{1,3}\)[^/]+' | head -1 | sed 's/^(.\{1,3\})//' || echo "")"
                if [ -n "$intercept" ]; then
                    ui_intercepts="\"$(json_escape "/$intercept")\""
                fi
                # Clean parallel slot from dir_path
                dir_path="$(echo "$dir_path" | sed 's|/@[a-zA-Z]*||g;s|@[a-zA-Z]*/||g' || echo "$dir_path")"
            fi

            # Buoc 4: GROUP — detect route groups (parentheses)
            route_group_match="$(echo "$dir_path" | grep -oE '\([a-zA-Z_-]+\)' | head -1 | tr -d '()' || echo "")"
            if [ -n "$route_group_match" ]; then
                ui_route_group="\"$(json_escape "$route_group_match")\""
                dir_path="$(echo "$dir_path" | sed 's|([^)]*)/||g;s|([^)]*)||g' || echo "$dir_path")"
            fi

            # Build route
            if [ -n "$dir_path" ] && [ "$dir_path" != "." ]; then
                ui_route="\"$(json_escape "/$dir_path")\""
            else
                ui_route="\"/\""
            fi
            ui_screens_with_routes=$((ui_screens_with_routes + 1))
        else
            ui_route="\"/\""
            ui_screens_with_routes=$((ui_screens_with_routes + 1))
        fi

        ui_module_hint="$(echo "$dir_path" | cut -d'/' -f1 | sed 's/\[//g;s/\]//g;s/(//g;s/)//g')"
        [ -z "$ui_module_hint" ] && ui_module_hint="root"
        [ "$ui_type" = "layout" ] && ui_is_layout="true"

        escaped_module_hint="$(json_escape "$ui_module_hint")"

        if [ "$is_infra" = "true" ]; then
            manifest_infra="$manifest_infra{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\"},"
            ui_infra_count=$((ui_infra_count + 1))
        else
            manifest_screens="$manifest_screens{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\",\"route\":$ui_route,\"route_source\":\"$ui_route_source\",\"route_group\":$ui_route_group,\"parallel_slot\":$ui_parallel_slot,\"intercepts\":$ui_intercepts,\"module_hint\":\"$escaped_module_hint\",\"child_screens\":[],\"is_modal\":$ui_is_modal,\"is_layout\":$ui_is_layout},"
        fi
    done < <(excluded_find -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' -o -name 'layout.tsx' -o -name 'layout.jsx' -o -name 'error.tsx' -o -name 'loading.tsx' -o -name 'template.tsx' -o -name 'default.tsx' -o -name 'not-found.tsx' \) -path '*/app/*')

    # ===== Next.js Pages Router: file path → route =====
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="$(rel_path "$f")"
        fname="$(basename "$f")"
        escaped_path="$(json_escape "$rel")"
        escaped_name="$(json_escape "$fname")"

        ui_type="page"
        is_infra="false"
        is_infra_name "$fname" && is_infra="true"

        dir_path="$(dirname "$rel")"
        case "$dir_path" in
            pages|*/pages) dir_path="" ;;
            pages/*)       dir_path="${dir_path#pages/}" ;;
            */pages/*)     dir_path="${dir_path#*/pages/}" ;;
        esac

        fname_no_ext="${fname%.*}"
        if [ "$fname_no_ext" = "index" ]; then
            if [ -n "$dir_path" ] && [ "$dir_path" != "." ]; then
                ui_route="/$dir_path"
            else
                ui_route="/"
            fi
        else
            if [ -n "$dir_path" ] && [ "$dir_path" != "." ]; then
                ui_route="/$dir_path/$fname_no_ext"
            else
                ui_route="/$fname_no_ext"
            fi
        fi

        escaped_route="$(json_escape "$ui_route")"
        ui_module_hint="$(echo "$dir_path" | cut -d'/' -f1)"
        [ -z "$ui_module_hint" ] && ui_module_hint="root"
        escaped_module_hint="$(json_escape "$ui_module_hint")"

        if [ "$is_infra" = "true" ]; then
            manifest_infra="$manifest_infra{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\"},"
            ui_infra_count=$((ui_infra_count + 1))
        else
            manifest_screens="$manifest_screens{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\",\"route\":\"$escaped_route\",\"route_source\":\"file-system\",\"route_group\":null,\"parallel_slot\":null,\"intercepts\":null,\"module_hint\":\"$escaped_module_hint\",\"child_screens\":[],\"is_modal\":false,\"is_layout\":false},"
            ui_screens_with_routes=$((ui_screens_with_routes + 1))
        fi
    done < <(excluded_find -type f \( -name '*.tsx' -o -name '*.jsx' \) -path '*/pages/*' ! -path '*/pages/api/*' ! -path '*/app/*')

    # ===== React Router JSX: grep <Route path= =====
    while IFS= read -r match; do
        parse_grep_match "$match"
        f="$GREP_FILE"; line="$GREP_LINE"
        [ -n "$f" ] && [ -f "$f" ] || continue
        rr_path="$(echo "$line" | grep -oE 'path="[^"]*"' | head -1 | sed 's/path="//;s/"$//' || true)"
        [ -z "$rr_path" ] && rr_path="$(echo "$line" | grep -oE "path='[^']*'" | head -1 | sed "s/path='//;s/'$//" || true)"
        [ -z "$rr_path" ] && continue
        rel="$(rel_path "$f")"
        escaped_route="$(json_escape "$rr_path")"
        ui_module_hint="$(echo "$rr_path" | sed 's|^/||' | cut -d'/' -f1)"
        [ -z "$ui_module_hint" ] && ui_module_hint="root"
        escaped_module_hint="$(json_escape "$ui_module_hint")"
        manifest_screens="$manifest_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"jsx-route\",\"route_group\":null,\"parallel_slot\":null,\"intercepts\":null,\"module_hint\":\"$escaped_module_hint\",\"child_screens\":[],\"is_modal\":false,\"is_layout\":false},"
        ui_screens_with_routes=$((ui_screens_with_routes + 1))
    done < <(excluded_find -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.js' \) \
        | xargs grep -lE '<Route[[:space:]]' 2>/dev/null \
        | xargs grep -nE '<Route[[:space:]]+path=' 2>/dev/null \
        | head -"$MAX_SCREENS" || true)

    # ===== Vue Router: parse path: patterns =====
    if [ "$has_vue" = "true" ]; then
        while IFS= read -r match; do
            parse_grep_match "$match"
            f="$GREP_FILE"; line="$GREP_LINE"
            [ -n "$f" ] && [ -f "$f" ] || continue
            vue_path="$(echo "$line" | grep -oE "path:[[:space:]]*['\"][^'\"]*['\"]" | head -1 | sed "s/path:[[:space:]]*['\"]//;s/['\"]$//" || true)"
            [ -z "$vue_path" ] && continue
            rel="$(rel_path "$f")"
            escaped_route="$(json_escape "$vue_path")"
            ui_module_hint="$(echo "$vue_path" | sed 's|^/||' | cut -d'/' -f1)"
            [ -z "$ui_module_hint" ] && ui_module_hint="root"
            escaped_module_hint="$(json_escape "$ui_module_hint")"
            manifest_screens="$manifest_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"config-object\",\"route_group\":null,\"parallel_slot\":null,\"intercepts\":null,\"module_hint\":\"$escaped_module_hint\",\"child_screens\":[],\"is_modal\":false,\"is_layout\":false},"
            ui_screens_with_routes=$((ui_screens_with_routes + 1))
        done < <(excluded_find -type f \( -name 'router.*' -o -name 'routes.*' \) -o -name 'index.ts' -path '*/router/*' \
            | xargs grep -nE "path:[[:space:]]*['\"]" 2>/dev/null | head -"$MAX_SCREENS" || true)
    fi

    # ===== Angular: *-routing.module.ts =====
    if [ "$has_angular" = "true" ]; then
        while IFS= read -r match; do
            parse_grep_match "$match"
            f="$GREP_FILE"; line="$GREP_LINE"
            [ -n "$f" ] && [ -f "$f" ] || continue
            ang_path="$(echo "$line" | grep -oE "path:[[:space:]]*['\"][^'\"]*['\"]" | head -1 | sed "s/path:[[:space:]]*['\"]//;s/['\"]$//" || true)"
            [ -z "$ang_path" ] && continue
            rel="$(rel_path "$f")"
            escaped_route="$(json_escape "$ang_path")"
            escaped_module_hint="$(json_escape "$ang_path")"
            manifest_screens="$manifest_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"decorator\",\"route_group\":null,\"parallel_slot\":null,\"intercepts\":null,\"module_hint\":\"$escaped_module_hint\",\"child_screens\":[],\"is_modal\":false,\"is_layout\":false},"
            ui_screens_with_routes=$((ui_screens_with_routes + 1))
        done < <(excluded_find -type f -name '*-routing.module.ts' -o -name '*-routing.ts' \
            | xargs grep -nE "path:[[:space:]]*['\"]" 2>/dev/null | head -"$MAX_SCREENS" || true)
    fi

    # --- Route config files ---
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="$(rel_path "$f")"
        fw="react"
        echo "$f" | grep -qi "angular\|routing" && fw="angular"
        echo "$f" | grep -qi "vue\|router" && fw="vue"
        manifest_route_configs="$manifest_route_configs{\"path\":\"$(json_escape "$rel")\",\"framework\":\"$fw\"},"
    done < <(excluded_find -type f \( -name 'router.*' -o -name 'routes.*' -o -name '*-routing.module.ts' -o -name '*-routing.ts' -o -name 'app.routes.ts' \) 2>/dev/null || true)

    # --- Build frameworks array ---
    ui_fw_entries=""
    if echo "$FRONTEND_FRAMEWORKS" | grep -qi "next"; then
        nextjs_count=$({ echo "$manifest_screens" | grep -o '"route_source":"file-system"' || true; } | wc -l)
        ui_fw_entries="$ui_fw_entries{\"name\":\"nextjs\",\"version\":\"$fw_next_ver\",\"detection_source\":\"package.json\",\"screen_count\":$nextjs_count},"
    fi
    if echo "$FRONTEND_FRAMEWORKS" | grep -qi "react" && ! echo "$FRONTEND_FRAMEWORKS" | grep -qi "next"; then
        react_count=$({ echo "$manifest_screens" | grep -o '"jsx-route"' || true; } | wc -l)
        ui_fw_entries="$ui_fw_entries{\"name\":\"react\",\"version\":\"$fw_react_ver\",\"detection_source\":\"package.json\",\"screen_count\":$react_count},"
    fi
    if [ "$has_vue" = "true" ]; then
        vue_count=$({ echo "$manifest_screens" | grep -o '"config-object"' || true; } | wc -l)
        ui_fw_entries="$ui_fw_entries{\"name\":\"vue\",\"version\":\"$fw_vue_ver\",\"detection_source\":\"package.json\",\"screen_count\":$vue_count},"
    fi
    if [ "$has_angular" = "true" ]; then
        angular_count=$({ echo "$manifest_screens" | grep -o '"decorator"' || true; } | wc -l)
        ui_fw_entries="$ui_fw_entries{\"name\":\"angular\",\"version\":\"$fw_angular_ver\",\"detection_source\":\"package.json\",\"screen_count\":$angular_count},"
    fi
    if [ -z "$ui_fw_entries" ]; then
        ui_fw_entries="{\"name\":\"unknown\",\"version\":\"unknown\",\"detection_source\":\"heuristic\",\"screen_count\":$screen_count},"
    fi

    # --- Counts ---
    manifest_screen_count=$({ echo "$manifest_screens" | grep -o '"path"' || true; } | wc -l)
    manifest_infra_count=$({ echo "$manifest_infra" | grep -o '"path"' || true; } | wc -l)
    total_manifest=$((manifest_screen_count + manifest_infra_count))
    ui_screens_without_routes=$((manifest_screen_count - ui_screens_with_routes))
    [ "$ui_screens_without_routes" -lt 0 ] && ui_screens_without_routes=0
    ui_total_routes=$ui_screens_with_routes

    # --- Write ui-manifest.json ---
    _manifest_json="$(cat <<MANIFEST_EOF
{
  "\$schema": "inventory/ui-manifest-v1",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
  "project_root": "$ui_project_root",
  "frameworks": [${ui_fw_entries%,}],
  "total_screens": $total_manifest,
  "total_routes": $ui_total_routes,
  "empty_project": false,
  "screens": [${manifest_screens%,}],
  "infrastructure_screens": [${manifest_infra%,}],
  "route_config_files": [${manifest_route_configs%,}],
  "coverage": {
    "screens_with_routes": $ui_screens_with_routes,
    "screens_without_routes": $ui_screens_without_routes,
    "routes_without_screens": $ui_routes_without_screens,
    "infrastructure_count": $manifest_infra_count
  },
  "_coverage_invariant": "total_screens = screens_with_routes + screens_without_routes"
}
MANIFEST_EOF
)"
    if ! atomic_write_json "$UI_MANIFEST_FILE" "$_manifest_json"; then
        warn "atomic_write_json failed for ui-manifest.json; falling back"
        printf '%s\n' "$_manifest_json" > "$UI_MANIFEST_FILE"
    fi
    validate_json "$UI_MANIFEST_FILE" || warn "ui-manifest.json failed JSON validation"
    log "ui-manifest.json: $total_manifest screens ($manifest_screen_count business, $manifest_infra_count infrastructure), $ui_total_routes routes"
else
    # GUARD: screen_count == 0 → empty manifest
    _empty_manifest_json="$(cat <<EMPTY_EOF
{
  "\$schema": "inventory/ui-manifest-v1",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
  "project_root": "",
  "frameworks": [],
  "total_screens": 0,
  "total_routes": 0,
  "empty_project": true,
  "screens": [],
  "infrastructure_screens": [],
  "route_config_files": [],
  "coverage": {
    "screens_with_routes": 0,
    "screens_without_routes": 0,
    "routes_without_screens": 0,
    "infrastructure_count": 0
  },
  "_coverage_invariant": "total_screens = screens_with_routes + screens_without_routes"
}
EMPTY_EOF
)"
    if ! atomic_write_json "$UI_MANIFEST_FILE" "$_empty_manifest_json"; then
        warn "atomic_write_json failed for empty ui-manifest.json; falling back"
        printf '%s\n' "$_empty_manifest_json" > "$UI_MANIFEST_FILE"
    fi
    validate_json "$UI_MANIFEST_FILE" || warn "ui-manifest.json (empty) failed JSON validation"
    log "ui-manifest.json: empty_project (no screens detected)"
fi

# ---------------------------------------------------------------------------
# api-endpoints.json — API route definitions
# ---------------------------------------------------------------------------

log "Scanning API endpoints..."

API_FILE="$OUTPUT_DIR/api-endpoints.json"
api_entries=""

add_api_entry() {
    local fpath="$1"
    local method="$2"
    local route="$3"
    local rel
    rel="$(rel_path "$fpath")"
    local escaped_path
    escaped_path="$(json_escape "$rel")"
    local escaped_route
    escaped_route="$(json_escape "$route")"
    local escaped_method
    escaped_method="$(json_escape "$method")"
    api_entries="$api_entries{\"path\":\"$escaped_path\",\"method\":\"$escaped_method\",\"route\":\"$escaped_route\",\"handler_file\":\"$escaped_path\"},"
}

# Express / Node: router.get/post/put/delete/patch
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE '\.(get|post|put|delete|patch)\(' | tr -d '.(' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE "['\"](/[^'\"]*)" | head -1 | tr -d "'\"" || true)"
    [ -z "$route" ] && route="(unknown)"
    [ -z "$method" ] && method="ANY"
    add_api_entry "$f" "$method" "$route"
done < <(excluded_find -type f \( -name '*.ts' -o -name '*.js' \) \
    | xargs grep -lE "router\.(get|post|put|delete|patch)\(" 2>/dev/null \
    | xargs grep -nE "router\.(get|post|put|delete|patch)\(" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# NestJS: @Get/@Post/@Put/@Delete/@Patch decorators
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE '@(Get|Post|Put|Delete|Patch)' | tr -d '@' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE "['\"](/[^'\"]*|[^'\"]*)" | head -1 | tr -d "'\"" || true)"
    [ -z "$route" ] && route="/"
    [ -z "$method" ] && method="ANY"
    add_api_entry "$f" "$method" "$route"
done < <(excluded_find -type f -name '*.ts' \
    | xargs grep -lE "@(Get|Post|Put|Delete|Patch)\(" 2>/dev/null \
    | xargs grep -nE "@(Get|Post|Put|Delete|Patch)\(" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# Django / FastAPI: urls.py hoac @app.get/@router.get
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE '@(app|router)\.(get|post|put|delete|patch)' | grep -oiE 'get|post|put|delete|patch' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE "\"(/[^\"]*)" | head -1 | tr -d '"' || true)"
    [ -z "$route" ] && route="(unknown)"
    [ -z "$method" ] && method="ANY"
    add_api_entry "$f" "$method" "$route"
done < <(excluded_find -type f -name '*.py' \
    | xargs grep -lE "@(app|router)\.(get|post|put|delete|patch)" 2>/dev/null \
    | xargs grep -nE "@(app|router)\.(get|post|put|delete|patch)" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# Django urls.py: path() / url()
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    route="$(echo "$line" | grep -oE "'[^']+'" | head -1 | tr -d "'" || true)"
    [ -z "$route" ] && route="(unknown)"
    add_api_entry "$f" "ANY" "$route"
done < <(excluded_find -type f -name 'urls.py' \
    | xargs grep -nE "path\(|url\(" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# .NET: [HttpGet]/[HttpPost] hoac [Route] trong Controllers hoac Endpoints
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE '\[Http(Get|Post|Put|Delete|Patch)\]' | grep -oiE 'Get|Post|Put|Delete|Patch' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE '"[^"]+"' | head -1 | tr -d '"' || true)"
    [ -z "$method" ] && method="ANY"
    [ -z "$route" ] && route="/"
    add_api_entry "$f" "$method" "$route"
done < <(excluded_find -type f -name '*.cs' \( -path '*/Controllers/*' -o -path '*/Endpoints/*' \) \
    | xargs grep -nE "\[Http(Get|Post|Put|Delete|Patch)\]|\[Route\]" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# .NET Minimal API: app.MapGet/MapPost/MapPut/MapDelete
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE 'Map(Get|Post|Put|Delete|Patch)' | grep -oiE 'Get|Post|Put|Delete|Patch' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE '"[^"]+"' | head -1 | tr -d '"' || true)"
    [ -z "$method" ] && method="ANY"
    [ -z "$route" ] && route="/"
    add_api_entry "$f" "$method" "$route"
done < <(excluded_find -type f -name '*.cs' \
    | xargs grep -lE "\.Map(Get|Post|Put|Delete|Patch)\(" 2>/dev/null \
    | xargs grep -nE "\.Map(Get|Post|Put|Delete|Patch)\(" 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# Go frameworks (Gin, Echo, Chi, Fiber): router.GET/POST, e.GET/POST, r.Get/Post, app.Get/Post
# NOTE: dung find truc tiep (khong qua excluded_find) vi EXCLUDE_ARRAY co the gay
# false-negative tren Windows Git Bash khi pipe qua xargs grep cho .go files
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    method="$(echo "$line" | grep -oiE '\.(GET|POST|PUT|DELETE|PATCH)\(' | head -1 | tr -d '.(' | tr '[:lower:]' '[:upper:]' || true)"
    route="$(echo "$line" | grep -oE '"[^"]+"' | head -1 | tr -d '"' || true)"
    [ -z "$method" ] && method="ANY"
    [ -z "$route" ] && route="(unknown)"
    add_api_entry "$f" "$method" "$route"
done < <(find "$PROJECT_PATH" -type f -name '*.go' \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/vendor/*" ! -path "*/esp-idf/*" \
    ! -path "*/.mc-data/*" \
    2>/dev/null \
    | xargs grep -lE '\.(GET|POST|PUT|DELETE|PATCH)\(' 2>/dev/null \
    | xargs grep -nE '\.(GET|POST|PUT|DELETE|PATCH)\(' 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# Go net/http: http.HandleFunc / http.Handle / mux.HandleFunc
while IFS= read -r match; do
    parse_grep_match "$match"
    f="$GREP_FILE"; line="$GREP_LINE"
    [ -n "$f" ] && [ -f "$f" ] || continue
    route="$(echo "$line" | grep -oE '"[^"]+"' | head -1 | tr -d '"' || true)"
    [ -z "$route" ] && route="(unknown)"
    add_api_entry "$f" "ANY" "$route"
done < <(find "$PROJECT_PATH" -type f -name '*.go' \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/vendor/*" ! -path "*/esp-idf/*" \
    ! -path "*/.mc-data/*" \
    2>/dev/null \
    | xargs grep -lE '\.HandleFunc\(|\.Handle\(' 2>/dev/null \
    | xargs grep -nE '\.HandleFunc\(|\.Handle\(' 2>/dev/null \
    | head -"$MAX_API_ENDPOINTS" || true)

# Next.js App Router API routes: app/api/**/route.ts hoac pages/api/**/*.ts
# Detect exported HTTP method handlers: export function GET/POST/PUT/DELETE/PATCH
while IFS= read -r f; do
    [ -f "$f" ] || continue
    for http_method in GET POST PUT DELETE PATCH; do
        grep -qE "export.*(async )?(function ${http_method}|const ${http_method})" "$f" 2>/dev/null || continue
        route="$(echo "$f" | grep -oE '/api/[^.]+' | head -1 || true)"
        [ -z "$route" ] && route="(unknown)"
        add_api_entry "$f" "$http_method" "$route"
    done
done < <(excluded_find -type f \( -name 'route.ts' -o -name 'route.js' -o -name 'route.tsx' -o -name 'route.jsx' \) -path '*/api/*' 2>/dev/null || true)

# Next.js Pages Router API routes: pages/api/**/*.ts — handler functions
while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Pages Router dung export default handler — khong co method cu the, dat ANY
    route="$(echo "$f" | grep -oE '/api/[^.]+' | head -1 || true)"
    [ -z "$route" ] && route="(unknown)"
    add_api_entry "$f" "ANY" "$route"
done < <(excluded_find -type f \( -name '*.ts' -o -name '*.js' \) -path '*/pages/api/*' 2>/dev/null || true)

api_count=$({ echo "$api_entries" | grep -o '"method"' || true; } | wc -l)
_api_json="$(cat <<EOF
{
  "count": $api_count,
  "items": [${api_entries%,}]
}
EOF
)"
if ! atomic_write_json "$API_FILE" "$_api_json"; then
    warn "atomic_write_json failed for api-endpoints.json; falling back"
    printf '%s\n' "$_api_json" > "$API_FILE"
fi
validate_json "$API_FILE" || warn "api-endpoints.json failed JSON validation"
log "api-endpoints.json: $api_count entries"

# ---------------------------------------------------------------------------
# doc-files.json — documentation files
# ---------------------------------------------------------------------------

log "Scanning documentation..."

DOC_FILE="$OUTPUT_DIR/doc-files.json"
_doc_tmp="$OUTPUT_DIR/.doc-items.tmp"

# PERFORMANCE: Single find + batched stat + awk — ghi truc tiep ra temp file
# Tranh luu ket qua trong variable (SIGPIPE khi string qua lon tren Git Bash)
excluded_find -type f \( -name '*.md' -o -name '*.mdx' -o -name '*.rst' \) \
    -exec stat -c '%n	%s' {} + 2>/dev/null \
| awk -F'\t' -v prefix="$_norm_project" '
BEGIN { gsub(/\\/, "/", prefix); count = 0 }
{
    raw_path = $1; size = $2
    gsub(/\\/, "/", raw_path)
    rel = raw_path
    if (index(rel, prefix) == 1) rel = substr(rel, length(prefix) + 1)
    name = rel; sub(/.*\//, "", name)
    ext = tolower(name); sub(/.*\./, "", ext)
    format = "markdown"
    if (ext == "mdx") format = "mdx"
    if (ext == "rst") format = "rst"
    gsub(/\\/, "\\\\", rel); gsub(/"/, "\\\"", rel)
    gsub(/\\/, "\\\\", name); gsub(/"/, "\\\"", name)
    if (count > 0) printf ","
    printf "{\"path\":\"%s\",\"name\":\"%s\",\"format\":\"%s\",\"size_bytes\":%s}", rel, name, format, size
    count++
}
END { }' > "$_doc_tmp"

# TXT trong doc directories (nho, giu per-file approach)
_txt_extra=""
_txt_count=0
while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="$(rel_path "$f")"
    name="$(basename "$f")"
    size="$(file_size "$f")"
    escaped_path="$(json_escape "$rel")"
    escaped_name="$(json_escape "$name")"
    _txt_extra="$_txt_extra,{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"format\":\"text\",\"size_bytes\":$size}"
    _txt_count=$((_txt_count + 1))
done < <(excluded_find -type f -name '*.txt' \( -path '*/docs/*' -o -path '*/doc/*' -o -path '*/documentation/*' \))

# OpenAPI: yaml/yml chua "openapi:" (nho, giu per-file approach)
while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="$(rel_path "$f")"
    name="$(basename "$f")"
    size="$(file_size "$f")"
    escaped_path="$(json_escape "$rel")"
    escaped_name="$(json_escape "$name")"
    _txt_extra="$_txt_extra,{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"format\":\"openapi\",\"size_bytes\":$size}"
    _txt_count=$((_txt_count + 1))
done < <(excluded_find -type f \( -name '*.yaml' -o -name '*.yml' \) \
    | xargs grep -li "^openapi:" 2>/dev/null || true)

# Merge: doc items (tu awk temp file) + txt/openapi extras
_doc_items_size=$(wc -c < "$_doc_tmp" 2>/dev/null || echo 0)
{
    printf '{"count":'
    # Dem entries: so lan "path": xuat hien
    if [ "$_doc_items_size" -gt 0 ]; then
        _md_count=$(grep -o '"path":' "$_doc_tmp" 2>/dev/null | wc -l || echo 0)
        _md_count=$(echo "$_md_count" | tr -d '[:space:]')
        [ -z "$_md_count" ] && _md_count=0
    else
        _md_count=0
    fi
    doc_count=$((_md_count + _txt_count))
    printf '%d,"items":[' "$doc_count"
    cat "$_doc_tmp" 2>/dev/null || true
    printf '%s' "$_txt_extra"
    printf ']}'
} > "$DOC_FILE"
rm -f "$_doc_tmp" 2>/dev/null
validate_json "$DOC_FILE" || warn "doc-files.json failed JSON validation"
log "doc-files.json: $doc_count entries"

# ---------------------------------------------------------------------------
# source-files.json — ALL source code files
# NOTE: Phai chay TRUOC doc-classified.json vi can source_count de detect DOCS_ONLY
# PERFORMANCE: Single find + batched stat + awk JSON generation
# Thay vi per-file subprocess calls (v2: 9m30s → v3: ~30s cho LARGE projects)
# ---------------------------------------------------------------------------

log "Scanning source files..."

SOURCE_FILE="$OUTPUT_DIR/source-files.json"

# Single find cho tat ca source extensions, pipe to stat batch + awk
# stat -c '%n\t%s\t%Y' batches multiple files per invocation (tranh per-file subprocess)
excluded_find -type f \( \
    -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
    -o -name '*.mjs' -o -name '*.cjs' -o -name '*.py' -o -name '*.cs' \
    -o -name '*.java' -o -name '*.go' -o -name '*.rs' -o -name '*.rb' \
    -o -name '*.php' -o -name '*.swift' -o -name '*.kt' -o -name '*.dart' \
    -o -name '*.vue' -o -name '*.c' -o -name '*.h' -o -name '*.cpp' -o -name '*.hpp' \
    \) -exec stat -c '%n	%s	%Y' {} + 2>/dev/null \
| awk -F'\t' -v prefix="$_norm_project" '
BEGIN {
    # Normalize prefix: replace backslash with /
    gsub(/\\/, "/", prefix)
    count = 0
    entries = ""
}
{
    raw_path = $1; size = $2; mtime = $3
    # Normalize path separators
    gsub(/\\/, "/", raw_path)
    # Tao relative path
    rel = raw_path
    if (index(rel, prefix) == 1) {
        rel = substr(rel, length(prefix) + 1)
    }
    # Extract name va extension
    name = rel; sub(/.*\//, "", name)
    ext = name; sub(/.*\./, "", ext); ext = tolower(ext)
    # JSON escape: backslash va double-quote
    gsub(/\\/, "\\\\", rel); gsub(/"/, "\\\"", rel)
    gsub(/\\/, "\\\\", name); gsub(/"/, "\\\"", name)
    if (count > 0) entries = entries ","
    entries = entries "{\"path\":\"" rel "\",\"name\":\"" name "\",\"extension\":\"" ext "\",\"size_bytes\":" size ",\"last_modified\":" mtime "}"
    count++
}
END {
    print "{\"count\":" count ",\"items\":[" entries "]}"
}' > "$SOURCE_FILE"
validate_json "$SOURCE_FILE" || warn "source-files.json failed JSON validation"

source_count=$(grep -o '"count":[0-9]*' "$SOURCE_FILE" | grep -oE '[0-9]+' || echo 0)
log "source-files.json: $source_count entries"

# ---------------------------------------------------------------------------
# doc-classified.json — DOCS_ONLY: phan loai docs theo type
# Chi tao khi source_count == 0 (DOCS_ONLY project)
# ---------------------------------------------------------------------------

if [ "$source_count" -eq 0 ] && [ "$doc_count" -gt 0 ]; then
    log "DOCS_ONLY detected — classifying docs by type..."

    DOC_CLASSIFIED_FILE="$OUTPUT_DIR/doc-classified.json"
    doc_class_entries=""

    classify_doc_type() {
        local fpath="$1"
        local name
        name="$(basename "$fpath" | tr '[:upper:]' '[:lower:]')"
        local content_hint=""
        # Doc 5 dong dau de xac dinh type
        content_hint="$(head -5 "$fpath" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")"

        # Phan loai theo ten file va noi dung
        case "$name" in
            *prd*|*product-req*|*requirement*|*brd*)  echo "prd" ; return ;;
            *spec*|*specification*|*technical*)        echo "spec" ; return ;;
            *wireframe*|*mockup*|*prototype*)          echo "wireframe" ; return ;;
            *meeting*|*minutes*|*notes*)               echo "meeting_notes" ; return ;;
            *api*|*openapi*|*swagger*|*endpoint*)      echo "api_spec" ; return ;;
            *guide*|*manual*|*howto*|*tutorial*)        echo "user_guide" ; return ;;
            *process*|*workflow*|*procedure*|*sop*)     echo "process_doc" ; return ;;
            *changelog*|*release*)                     echo "changelog" ; return ;;
            *readme*)                                  echo "readme" ; return ;;
        esac

        # Fallback: kiem tra noi dung
        if echo "$content_hint" | grep -qiE "requirement|must|shall|phai"; then
            echo "prd" ; return
        fi
        if echo "$content_hint" | grep -qiE "api|endpoint|route|schema"; then
            echo "api_spec" ; return
        fi
        if echo "$content_hint" | grep -qiE "architecture|design|system"; then
            echo "spec" ; return
        fi
        echo "general"
    }

    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="$(rel_path "$f")"
        doc_type="$(classify_doc_type "$f")"
        size="$(file_size "$f")"
        escaped_path="$(json_escape "$rel")"
        doc_class_entries="$doc_class_entries{\"path\":\"$escaped_path\",\"doc_type\":\"$doc_type\",\"size_bytes\":$size},"
    done < <(excluded_find -type f \( -name '*.md' -o -name '*.mdx' -o -name '*.rst' -o -name '*.txt' \))

    # Them OpenAPI files
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        rel="$(rel_path "$f")"
        size="$(file_size "$f")"
        escaped_path="$(json_escape "$rel")"
        doc_class_entries="$doc_class_entries{\"path\":\"$escaped_path\",\"doc_type\":\"api_spec\",\"size_bytes\":$size},"
    done < <(excluded_find -type f \( -name '*.yaml' -o -name '*.yml' \) \
        | xargs grep -li "^openapi:" 2>/dev/null || true)

    doc_class_count=$({ echo "$doc_class_entries" | grep -o '"doc_type"' || true; } | wc -l)
    _doc_class_json="$(cat <<EOF
{
  "count": $doc_class_count,
  "is_docs_only": true,
  "items": [${doc_class_entries%,}]
}
EOF
)"
    if ! atomic_write_json "$DOC_CLASSIFIED_FILE" "$_doc_class_json"; then
        warn "atomic_write_json failed for doc-classified.json; falling back"
        printf '%s\n' "$_doc_class_json" > "$DOC_CLASSIFIED_FILE"
    fi
    validate_json "$DOC_CLASSIFIED_FILE" || warn "doc-classified.json failed JSON validation"
    log "doc-classified.json: $doc_class_count entries (DOCS_ONLY mode)"
fi

# ---------------------------------------------------------------------------
# dependency-graph.json — basic dependency analysis
# ---------------------------------------------------------------------------

log "Analyzing dependencies..."

DEP_FILE="$OUTPUT_DIR/dependency-graph.json"
dep_entries=""
circular_entries=""

# Phan tich package.json dependencies
if [ -f "$PROJECT_PATH/package.json" ]; then
    # Trich xuat dependencies va devDependencies (grep-based, khong can jq)
    # Format: "package-name": "version"
    pkg_deps="$(grep -oE '"[a-zA-Z@][a-zA-Z0-9/_@.-]+"[[:space:]]*:[[:space:]]*"[^"]*"' \
        "$PROJECT_PATH/package.json" 2>/dev/null | grep -v '"scripts"\|"author"\|"license"\|"main"' | head -100 || true)"

    root_deps=""
    while IFS= read -r line; do
        dep_name="$(echo "$line" | grep -oE '"[a-zA-Z@][a-zA-Z0-9/_@.-]+"' | head -1 | tr -d '"')"
        [ -z "$dep_name" ] && continue
        escaped_dep="$(json_escape "$dep_name")"
        root_deps="$root_deps\"$escaped_dep\","
    done <<< "$pkg_deps"

    dep_entries="$dep_entries\"root\":[${root_deps%,}],"
fi

# Phan tich monorepo packages: moi app trong apps/ co package.json rieng
if [ -d "$PROJECT_PATH/apps" ]; then
    for app_dir in "$PROJECT_PATH/apps"/*/; do
        [ -d "$app_dir" ] || continue
        app_pkg="$app_dir/package.json"
        [ -f "$app_pkg" ] || continue
        app_name="$(basename "$app_dir")"

        app_deps=""
        # Tim cac workspace dependencies (dau hieu circular potential)
        while IFS= read -r line; do
            dep_name="$(echo "$line" | grep -oE '"[a-zA-Z@][a-zA-Z0-9/_@.-]+"' | head -1 | tr -d '"')"
            [ -z "$dep_name" ] && continue
            escaped_dep="$(json_escape "$dep_name")"
            app_deps="$app_deps\"$escaped_dep\","
        done < <(grep -oE '"[a-zA-Z@][a-zA-Z0-9/_@.-]+"[[:space:]]*:[[:space:]]*"workspace:[^"]*"' \
            "$app_pkg" 2>/dev/null || true)

        escaped_app="$(json_escape "$app_name")"
        dep_entries="$dep_entries\"$escaped_app\":[${app_deps%,}],"
    done
fi

# Import analysis: nhom top-level directory imports (cho Node.js/TypeScript)
# Lay cac relative imports tu src files va nhom theo thu muc dau tien
declare -A import_counts 2>/dev/null || true

top_level_imports=""
while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Tim cac relative imports
    while IFS= read -r imp; do
        # Lay phan dau tien cua duong dan
        first_seg="$(echo "$imp" | sed "s|['\"]||g" | cut -d'/' -f2)"
        [ -z "$first_seg" ] && continue
        top_level_imports="$top_level_imports$first_seg\n"
    done < <(grep -oE "from ['\"](\.\./|\./)([^'\"]+)" "$f" 2>/dev/null | grep -oE "['\"](\.\./|\./)([^'\"]+)" | head -"$MAX_IMPORTS_PER_FILE" || true)
done < <(excluded_find -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' \) | head -"$MAX_IMPORT_FILES")

# Dem cac import group
import_group_counts=""
if [ -n "$top_level_imports" ]; then
    import_group_data="$(printf "$top_level_imports" | sort | uniq -c | sort -rn | head -20 || true)"
    while IFS= read -r line; do
        count="$(echo "$line" | awk '{print $1}')"
        seg="$(echo "$line" | awk '{print $2}')"
        [ -z "$seg" ] && continue
        escaped_seg="$(json_escape "$seg")"
        import_group_counts="$import_group_counts{\"module\":\"$escaped_seg\",\"import_count\":$count},"
    done <<< "$import_group_data"
fi

_dep_json="$(cat <<EOF
{
  "dependencies": {
    ${dep_entries%,}
  },
  "import_groups": [${import_group_counts%,}],
  "circular": []
}
EOF
)"
if ! atomic_write_json "$DEP_FILE" "$_dep_json"; then
    warn "atomic_write_json failed for dependency-graph.json; falling back"
    printf '%s\n' "$_dep_json" > "$DEP_FILE"
fi
validate_json "$DEP_FILE" || warn "dependency-graph.json failed JSON validation"
log "dependency-graph.json: written"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Inventory Summary ==="
echo "  screens:      $screen_count"
echo "  api-endpoints: $api_count"
echo "  doc-files:    $doc_count"
echo "  source-files: $source_count"
echo "  output dir:   $OUTPUT_DIR"
echo "========================="
