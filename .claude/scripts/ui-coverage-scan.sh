#!/usr/bin/env bash
# ui-coverage-scan.sh — Lightweight UI screen/route scan cho wf-verify-sync Phase 5b
# Usage: bash .claude/scripts/ui-coverage-scan.sh [project-path] [output-dir]
#
# Input:  project directory (default: current directory)
# Output: ui-snapshot.json (screens + routes found in codebase)
#
# WHY standalone script: Phase 5b chay sau implement, khong can full inventory.
# Chi scan UI screens/routes, khong scan API/docs/deps nhu inventory.sh.
# Dùng cho cả new + legacy projects.
#
# Detection logic giong inventory.sh screens section:
# - Next.js App Router: app/*/page.tsx → route mapping
# - Next.js Pages Router: pages/**/*.tsx → route mapping
# - React Router: <Route path= patterns (JSX)
# - Vue Router: path: patterns in router files
# - Angular: *-routing.module.ts patterns
#
# Phase G refactor (v5.0):
# - Source legacy-scan-common.sh for shared UI helpers
# - Removed ~80 dòng duplicate: classify_ui_type, is_infra_name, parse_grep_match,
#   detect_frontend_framework_flags, detect_framework_versions, detect_ui_project_root
# - atomic_write_json + validate_json post-write

# Shared library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="ui-coverage-scan"
# shellcheck source=./legacy-scan-common.sh
source "$SCRIPTS_DIR/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

PROJECT_PATH="${1:-.}"
OUTPUT_DIR="${2:-.mc-data/work/wf-verify-sync}"

# ---------------------------------------------------------------------------
# Helpers (local overrides)
# ---------------------------------------------------------------------------

log()  { echo "[ui-coverage-scan] $*" >&2; }
warn() { echo "[ui-coverage-scan][WARN] $*" >&2; }

# Local normalize_path: giữ v4.1 behavior (không convert C:/ → /c/)
normalize_path() { echo "$1" | tr '\\' '/'; }

# rel_path wrapper: dùng common.sh compute_rel_path với PROJECT_PATH global.
rel_path() {
    compute_rel_path "$1" "$PROJECT_PATH"
}

# Find wrapper — exclude standard dirs cho Phase 5b (narrower scope vs inventory.sh)
excluded_find() {
    find "$PROJECT_PATH" \
        -not -path '*/node_modules/*' \
        -not -path '*/.next/*' \
        -not -path '*/.mc-data/*' \
        -not -path '*/dist/*' \
        -not -path '*/build/*' \
        -not -path '*/.git/*' \
        -not -path '*/coverage/*' \
        -not -path '*/.cache/*' \
        -not -path '*/vendor/*' \
        "$@"
}

# ---------------------------------------------------------------------------
# Framework detection tu package.json (dùng shared helpers)
# ---------------------------------------------------------------------------

# Backward-compat: giữ biến FRONTEND_FRAMEWORKS (dùng xuôi trong fw_entries section)
FRONTEND_FRAMEWORKS=""
if [ -f "$PROJECT_PATH/package.json" ]; then
    FRONTEND_FRAMEWORKS="$(cat "$PROJECT_PATH/package.json" 2>/dev/null | tr -d '\n' | grep -oE '"(next|react|vue|@vue/cli|nuxt|@angular/core|svelte|@sveltejs/kit)"[[:space:]]*:[[:space:]]*"[^"]*"' || true)"
fi

# Framework flags từ shared helper (has_vue/has_angular/has_next/has_react/has_rn/has_flutter)
eval "$(detect_frontend_framework_flags "$PROJECT_PATH")"

# Framework versions từ shared helper (fw_next_ver, fw_react_ver, fw_vue_ver, fw_angular_ver)
eval "$(detect_framework_versions "$PROJECT_PATH")"

# ---------------------------------------------------------------------------
# Monorepo detection (dùng shared helper)
# ---------------------------------------------------------------------------

ui_project_root="$(detect_ui_project_root "$PROJECT_PATH")"

# classify_ui_type, is_infra_name, parse_grep_match: dùng shared từ common.sh
# (xem legacy-scan-common.sh — các hàm này đã được extract vào shared library)

# ---------------------------------------------------------------------------
# Scan UI screens
# ---------------------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"
SNAPSHOT_FILE="$OUTPUT_DIR/ui-snapshot.json"

snapshot_screens=""
total_screens=0
total_routes=0

# ===== Next.js App Router =====
while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="$(rel_path "$f")"
    fname="$(basename "$f")"
    escaped_path="$(json_escape "$rel")"
    escaped_name="$(json_escape "$fname")"

    ui_type="$(classify_ui_type "$fname")"
    is_infra="false"
    is_infra_name "$fname" && is_infra="true"

    # Route: STRIP app/ prefix va /page.tsx suffix
    dir_path="$(dirname "$rel")"
    case "$dir_path" in
        app)     dir_path="" ;;
        */app)   dir_path="" ;;
        app/*)   dir_path="${dir_path#app/}" ;;
        */app/*) dir_path="${dir_path#*/app/}" ;;
    esac

    ui_route="null"
    ui_route_source="file-system"

    if [ -n "$dir_path" ] && [ "$dir_path" != "." ]; then
        # Strip parallel slots
        dir_path_clean="$(echo "$dir_path" | sed 's|/@[a-zA-Z]*||g;s|@[a-zA-Z]*/||g')"
        # Strip route groups
        dir_path_clean="$(echo "$dir_path_clean" | sed 's|([^)]*)/||g;s|([^)]*)||g')"
        if [ -n "$dir_path_clean" ] && [ "$dir_path_clean" != "." ]; then
            ui_route="\"$(json_escape "/$dir_path_clean")\""
        else
            ui_route="\"/\""
        fi
        total_routes=$((total_routes + 1))
    else
        ui_route="\"/\""
        total_routes=$((total_routes + 1))
    fi

    ui_module_hint="$(echo "$dir_path" | cut -d'/' -f1 | sed 's/\[//g;s/\]//g;s/(//g;s/)//g')"
    [ -z "$ui_module_hint" ] && ui_module_hint="root"
    escaped_module_hint="$(json_escape "$ui_module_hint")"

    snapshot_screens="$snapshot_screens{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\",\"route\":$ui_route,\"route_source\":\"$ui_route_source\",\"module_hint\":\"$escaped_module_hint\",\"is_infrastructure\":$is_infra},"
    total_screens=$((total_screens + 1))
done < <(excluded_find -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' \) -path '*/app/*')

# ===== Next.js Pages Router =====
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

    snapshot_screens="$snapshot_screens{\"path\":\"$escaped_path\",\"name\":\"$escaped_name\",\"type\":\"$ui_type\",\"route\":\"$escaped_route\",\"route_source\":\"file-system\",\"module_hint\":\"$escaped_module_hint\",\"is_infrastructure\":$is_infra},"
    total_screens=$((total_screens + 1))
    total_routes=$((total_routes + 1))
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
    snapshot_screens="$snapshot_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"jsx-route\",\"module_hint\":\"$escaped_module_hint\",\"is_infrastructure\":false},"
    total_screens=$((total_screens + 1))
    total_routes=$((total_routes + 1))
done < <(excluded_find -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.js' \) \
    | xargs grep -lE '<Route[[:space:]]' 2>/dev/null \
    | xargs grep -nE '<Route[[:space:]]+path=' 2>/dev/null \
    | head -300 || true)

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
        snapshot_screens="$snapshot_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"config-object\",\"module_hint\":\"$escaped_module_hint\",\"is_infrastructure\":false},"
        total_screens=$((total_screens + 1))
        total_routes=$((total_routes + 1))
    done < <(excluded_find -type f \( -name 'router.*' -o -name 'routes.*' \) -o -name 'index.ts' -path '*/router/*' \
        | xargs grep -nE "path:[[:space:]]*['\"]" 2>/dev/null | head -200 || true)
fi

# ===== Angular: *-routing.module.ts =====
if [ "$has_angular" = "true" ]; then
    while IFS= read -r match; do
        parse_grep_match "$match"
        f="$GREP_FILE"; line="$GREP_LINE"
        [ -n "$f" ] && [ -f "$f" ] || continue
        ang_path="$(echo "$line" | grep -oE "path:[[:space:]]*['\"][^'\"]*['\"]" | head -1 | sed "s/path:[[:space:]]*['\"]//;s/['\"]$//" || true)"
        [ -z "$ang_path" ] || [ "$ang_path" = "" ] && continue
        rel="$(rel_path "$f")"
        escaped_route="$(json_escape "$ang_path")"
        escaped_module_hint="$(json_escape "$ang_path")"
        snapshot_screens="$snapshot_screens{\"path\":\"$(json_escape "$rel")\",\"name\":\"$(json_escape "$(basename "$f")")\",\"type\":\"page\",\"route\":\"$escaped_route\",\"route_source\":\"decorator\",\"module_hint\":\"$escaped_module_hint\",\"is_infrastructure\":false},"
        total_screens=$((total_screens + 1))
        total_routes=$((total_routes + 1))
    done < <(excluded_find -type f \( -name '*-routing.module.ts' -o -name '*-routing.ts' \) \
        | xargs grep -nE "path:[[:space:]]*['\"]" 2>/dev/null | head -200 || true)
fi

# ---------------------------------------------------------------------------
# Framework detection for snapshot
# ---------------------------------------------------------------------------

fw_entries=""
if echo "$FRONTEND_FRAMEWORKS" | grep -qi "next"; then
    fw_entries="$fw_entries{\"name\":\"nextjs\",\"version\":\"$fw_next_ver\",\"detection_source\":\"package.json\"},"
fi
if echo "$FRONTEND_FRAMEWORKS" | grep -qi "react" && ! echo "$FRONTEND_FRAMEWORKS" | grep -qi "next"; then
    fw_entries="$fw_entries{\"name\":\"react\",\"version\":\"$fw_react_ver\",\"detection_source\":\"package.json\"},"
fi
if [ "$has_vue" = "true" ]; then
    fw_entries="$fw_entries{\"name\":\"vue\",\"version\":\"$fw_vue_ver\",\"detection_source\":\"package.json\"},"
fi
if [ "$has_angular" = "true" ]; then
    fw_entries="$fw_entries{\"name\":\"angular\",\"version\":\"$fw_angular_ver\",\"detection_source\":\"package.json\"},"
fi
if [ -z "$fw_entries" ]; then
    fw_entries="{\"name\":\"unknown\",\"version\":\"unknown\",\"detection_source\":\"heuristic\"},"
fi

# ---------------------------------------------------------------------------
# GUARD: empty_project
# ---------------------------------------------------------------------------

empty_project="false"
if [ "$total_screens" -eq 0 ]; then
    empty_project="true"
    log "No UI screens found — empty_project=true"
fi

# ---------------------------------------------------------------------------
# Write ui-snapshot.json
# ---------------------------------------------------------------------------

_snapshot_json="$(cat <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
  "project_root": "$ui_project_root",
  "total_screens": $total_screens,
  "total_routes": $total_routes,
  "empty_project": $empty_project,
  "frameworks": [${fw_entries%,}],
  "screens": [${snapshot_screens%,}]
}
EOF
)"

if ! atomic_write_json "$SNAPSHOT_FILE" "$_snapshot_json"; then
    warn "atomic_write_json failed; falling back to direct write"
    printf '%s\n' "$_snapshot_json" > "$SNAPSHOT_FILE"
fi

if ! validate_json "$SNAPSHOT_FILE"; then
    warn "ui-snapshot.json failed JSON validation"
fi

log "ui-snapshot.json: $total_screens screens, $total_routes routes"
