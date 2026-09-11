#!/usr/bin/env bash
# legacy-scan-detect.sh — Deterministic detection cho wf-legacy-scan Stage 0
# Usage: bash .claude/scripts/legacy-scan-detect.sh <project-path> <output-dir>
#
# Input:  project directory path
# Output: project-profile.json in output-dir
#
# WHY deterministic shell script thay vi AI: detection logic la pure file-system
# enumeration — khong can inference. Chay nhanh, reproducible, khong ton token.
#
# Phase G refactor (v5.0):
# - Source legacy-scan-common.sh for shared helpers
# - Use atomic_write_json + validate_json for final output
# - Keep local helpers (normalize_path simple, json_escape compatible) to preserve
#   exact v4.1 output format for downstream consumers.

# Shared library (cross-platform path resolution via BASH_SOURCE[0])
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="legacy-scan-detect"
# shellcheck source=./legacy-scan-common.sh
source "$SCRIPTS_DIR/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

PROJECT_PATH="${1:-.}"
OUTPUT_DIR="${2:-.mc-data/work/legacy-scan}"

# ---------------------------------------------------------------------------
# Helpers (local — override common.sh where v4.1 compat matters)
# ---------------------------------------------------------------------------

# Giu log/warn signature cu "[detect] ..." thay vi "[legacy-scan-detect] INFO: ..."
# de backward-compat voi downstream log parsers.
log()  { echo "[detect] $*" >&2; }
warn() { echo "[detect][WARN] $*" >&2; }

# Normalize path đơn giản — giữ behavior v4.1 (chỉ convert \ → /).
# KHÔNG dùng common.sh normalize_path vì nó convert C:/ → /c/ gây
# path mismatch với string operations downstream.
normalize_path() {
    echo "$1" | tr '\\' '/'
}

# json_escape giữ identical với common.sh (copy cho rõ ràng + tránh surprise).
# json_escape provided bởi common.sh là tương thích.

# Doc noi dung file thanh bien (portable, khong dung mapfile)
read_file() {
    cat "$1" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Project path does not exist or is not a directory: $PROJECT_PATH" >&2
    exit 1
fi

# Kiem tra thu muc co file khong (non-empty)
file_count_check=$(find "$PROJECT_PATH" -maxdepth 2 -type f 2>/dev/null | head -1)
if [ -z "$file_count_check" ]; then
    echo "ERROR: Project directory appears to be empty: $PROJECT_PATH" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
log "Scanning project at: $PROJECT_PATH"
log "Output dir: $OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Stage 1: File counts
# ---------------------------------------------------------------------------

log "Counting files + detecting languages..."

# PERFORMANCE: ONE find traversal for total_files + category counts + per-language counts + test files
# Thay vi 20+ find calls rieng le (v1: 57s → v2: 17s → v3: ~8s cho LARGE projects)
_all_counts=$(find "$PROJECT_PATH" -type f \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" \
    ! -path "*/vendor/*" ! -path "*/bin/*" ! -path "*/obj/*" \
    ! -path "*/.next/*" ! -path "*/.mc-data/*" ! -path "*/.backup*" \
    ! -path "*/.claude/*" ! -path "*/Backup.mc-data/*" \
    ! -path "*/esp-idf/*" ! -path "*/.pub-cache/*" ! -path "*/.dart_tool/*" \
    ! -path "*/Pods/*" ! -path "*/.gradle/*" ! -path "*/.flutter/*" \
    2>/dev/null | awk -F. '{
    total++
    ext=tolower($NF)
    # Category counts
    if (ext ~ /^(ts|tsx|js|jsx|py|cs|java|go|rs|rb|php|swift|kt|dart|c|h|cpp|hpp)$/) src++
    if (ext ~ /^(md|mdx|rst)$/) doc++
    if (ext ~ /^(json|yaml|yml|toml|ini)$/) cfg++
    if (ext ~ /^(png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot|mp4|mp3)$/) ast++
    # Per-language counts
    if (ext=="ts") ts++; if (ext=="tsx") tsx++
    if (ext=="js") js++; if (ext=="jsx") jsx++
    if (ext=="py") py++; if (ext=="cs") cs++
    if (ext=="java") java++; if (ext=="go") go++
    if (ext=="rs") rs++; if (ext=="rb") rb++
    if (ext=="php") php++; if (ext=="swift") swift++
    if (ext=="kt") kt++; if (ext=="dart") dart++
    if (ext=="c") c++; if (ext=="h") h++; if (ext=="cpp") cpp++
    # Test file detection (by filename pattern)
    name = $0; sub(/.*\//, "", name)
    if (name ~ /\.(spec|test)\./ || name ~ /_test\./ || name ~ /Tests\.cs$/ || name ~ /Test\.java$/) tst++
}
END {
    printf "%d %d %d %d %d %d ", total+0, src+0, doc+0, cfg+0, ast+0, tst+0
    printf "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", ts+0,tsx+0,js+0,jsx+0,py+0,cs+0,java+0,go+0,rs+0,rb+0,php+0,swift+0,kt+0,dart+0,c+0,h+0,cpp+0
}')
read total_files source_files doc_files config_files asset_files test_files \
     ts_count tsx_count js_count jsx_count py_count cs_count java_count go_count \
     rs_count rb_count php_count swift_count kt_count dart_count c_count h_count cpp_count \
     <<< "$_all_counts"

# ---------------------------------------------------------------------------
# Stage 2: Language totals (derived from single-pass counts above)
# ---------------------------------------------------------------------------

log "Detecting languages..."

c_total=$((c_count + h_count + cpp_count))
typescript_total=$((ts_count + tsx_count))
javascript_total=$((js_count + jsx_count))

# Sap xep de xac dinh primary language (sort bang so sanh thu cong)
build_lang_json() {
    local pairs=""
    [ "$typescript_total" -gt 0 ] && pairs="$pairs typescript:$typescript_total"
    [ "$javascript_total" -gt 0 ] && pairs="$pairs javascript:$javascript_total"
    [ "$py_count" -gt 0 ]         && pairs="$pairs python:$py_count"
    [ "$cs_count" -gt 0 ]         && pairs="$pairs csharp:$cs_count"
    [ "$java_count" -gt 0 ]       && pairs="$pairs java:$java_count"
    [ "$go_count" -gt 0 ]         && pairs="$pairs go:$go_count"
    [ "$rs_count" -gt 0 ]         && pairs="$pairs rust:$rs_count"
    [ "$rb_count" -gt 0 ]         && pairs="$pairs ruby:$rb_count"
    [ "$php_count" -gt 0 ]        && pairs="$pairs php:$php_count"
    [ "$swift_count" -gt 0 ]      && pairs="$pairs swift:$swift_count"
    [ "$kt_count" -gt 0 ]         && pairs="$pairs kotlin:$kt_count"
    [ "$dart_count" -gt 0 ]       && pairs="$pairs dart:$dart_count"
    [ "$c_total" -gt 0 ]          && pairs="$pairs c_cpp:$c_total"
    echo "$pairs"
}

lang_pairs="$(build_lang_json)"

# Tim primary (max count)
primary_lang="unknown"
primary_count=0
for pair in $lang_pairs; do
    lang="${pair%%:*}"
    count="${pair##*:}"
    if [ "$count" -gt "$primary_count" ]; then
        primary_lang="$lang"
        primary_count="$count"
    fi
done

# Secondary: tat ca ngoai primary co count > 0
secondary_langs_json=""
for pair in $lang_pairs; do
    lang="${pair%%:*}"
    count="${pair##*:}"
    if [ "$lang" != "$primary_lang" ] && [ "$count" -gt 0 ]; then
        secondary_langs_json="$secondary_langs_json\"$lang\","
    fi
done
secondary_langs_json="[${secondary_langs_json%,}]"

# ---------------------------------------------------------------------------
# Stage 3: Framework detection
# ---------------------------------------------------------------------------

log "Detecting frameworks..."

backend_frameworks="[]"
frontend_frameworks="[]"
mobile_frameworks="[]"
database_frameworks="[]"

# --- Scan package.json dependencies (root + per-app for monorepo) ---
# Helper: scan mot package.json va them vao be_list/fe_list/mob_list
scan_pkg_deps() {
    local pkg_file="$1"
    [ -f "$pkg_file" ] || return 0
    local content
    content="$(read_file "$pkg_file")"
    # Backend
    echo "$content" | grep -qi '"express"'   && be_list="$be_list\"express\","
    echo "$content" | grep -qi '"@nestjs'    && be_list="$be_list\"nestjs\","
    echo "$content" | grep -qi '"fastify"'   && be_list="$be_list\"fastify\","
    # Frontend
    echo "$content" | grep -qi '"react"'     && fe_list="$fe_list\"react\","
    echo "$content" | grep -qi '"vue"'       && fe_list="$fe_list\"vue\","
    echo "$content" | grep -qi '"angular"'   && fe_list="$fe_list\"angular\","
    echo "$content" | grep -qi '"next"'      && fe_list="$fe_list\"nextjs\","
    echo "$content" | grep -qi '"nuxt"'      && fe_list="$fe_list\"nuxt\","
    echo "$content" | grep -qi '"svelte"'    && fe_list="$fe_list\"svelte\","
    # Mobile
    echo "$content" | grep -qi '"react-native"' && mob_list="$mob_list\"react-native\","
    echo "$content" | grep -qi '"expo"'         && mob_list="$mob_list\"expo\","
    true  # Dam bao function luon return 0 (tranh set -e exit khi grep khong match)
}

# --- Initialize all framework lists before scanning ---
be_list=""
fe_list=""
mob_list=""
pkg_json="$PROJECT_PATH/package.json"
# Scan root package.json
scan_pkg_deps "$pkg_json"

# Monorepo: scan per-app package.json (tranh miss frameworks chi co trong sub-apps)
if [ -d "$PROJECT_PATH/apps" ]; then
    for app_pkg in "$PROJECT_PATH/apps"/*/package.json; do
        [ -f "$app_pkg" ] && scan_pkg_deps "$app_pkg"
    done
fi
# Multi-project: scan root-level sub-dirs co package.json (e.g., nira-erp/frontend/)
for sub_pkg in "$PROJECT_PATH"/*/package.json "$PROJECT_PATH"/*/frontend/package.json "$PROJECT_PATH"/*/backend/package.json; do
    [ -f "$sub_pkg" ] && scan_pkg_deps "$sub_pkg"
done

if [ -f "$PROJECT_PATH/requirements.txt" ]; then
    req_content="$(read_file "$PROJECT_PATH/requirements.txt")"
    echo "$req_content" | grep -qi "django"  && be_list="$be_list\"django\","
    echo "$req_content" | grep -qi "flask"   && be_list="$be_list\"flask\","
    echo "$req_content" | grep -qi "fastapi" && be_list="$be_list\"fastapi\","
fi
csproj_count=$(find "$PROJECT_PATH" -name "*.csproj" ! -path "*/node_modules/*" ! -path "*/esp-idf/*" 2>/dev/null | wc -l)
[ "$csproj_count" -gt 0 ] && be_list="$be_list\"dotnet\","
[ -f "$PROJECT_PATH/pom.xml" ]         && be_list="$be_list\"spring\","
[ -f "$PROJECT_PATH/build.gradle" ]    && be_list="$be_list\"spring\","
[ -f "$PROJECT_PATH/go.mod" ]          && be_list="$be_list\"go\","
[ -f "$PROJECT_PATH/Cargo.toml" ]      && be_list="$be_list\"rust\","
[ -f "$PROJECT_PATH/Gemfile" ]         && be_list="$be_list\"ruby-on-rails\","
# Scan sub-directories (depth 2) cho projects khong co build files o root
gomod_count=$(find "$PROJECT_PATH" -maxdepth 3 -name "go.mod" ! -path "*/vendor/*" ! -path "*/esp-idf/*" 2>/dev/null | wc -l)
[ "$gomod_count" -gt 0 ] && be_list="$be_list\"go\","
cmake_count=$(find "$PROJECT_PATH" -maxdepth 2 -name "CMakeLists.txt" ! -path "*/esp-idf/*" 2>/dev/null | wc -l)
[ "$cmake_count" -gt 0 ] && be_list="$be_list\"c_embedded\","

# Dedup: loai bo duplicates trong be_list (vi nhieu package.json co the co cung framework)
dedup_list() {
    local input="$1"
    [ -z "$input" ] && { echo ""; return 0; }
    echo "$input" | tr ',' '\n' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//' || true
}
be_list="$(dedup_list "$be_list"),"
backend_frameworks="[${be_list%,}]"

# --- Frontend (fe_list da duoc populate boi scan_pkg_deps) ---
# Them typescript neu co tsconfig.json va dedup
[ -f "$PROJECT_PATH/tsconfig.json" ] && fe_list="$fe_list\"typescript\","
fe_list="$(dedup_list "$fe_list"),"
frontend_frameworks="[${fe_list%,}]"

# --- Mobile (mob_list da duoc populate boi scan_pkg_deps) ---
# Them native frameworks va dedup
# Flutter: root hoac sub-dirs
[ -f "$PROJECT_PATH/pubspec.yaml" ] && mob_list="$mob_list\"flutter\","
pubspec_count=$(find "$PROJECT_PATH" -maxdepth 2 -name "pubspec.yaml" ! -path "*/esp-idf/*" 2>/dev/null | wc -l)
[ "$pubspec_count" -gt 0 ] && mob_list="$mob_list\"flutter\","
xcodeproj_count=$(find "$PROJECT_PATH" -name "*.xcodeproj" ! -path "*/esp-idf/*" 2>/dev/null | wc -l)
[ "$xcodeproj_count" -gt 0 ] && mob_list="$mob_list\"ios-native\","
mob_list="$(dedup_list "$mob_list"),"
mobile_frameworks="[${mob_list%,}]"

# --- Database ---
db_list=""
compose_file=""
[ -f "$PROJECT_PATH/docker-compose.yml" ]  && compose_file="$PROJECT_PATH/docker-compose.yml"
[ -f "$PROJECT_PATH/docker-compose.yaml" ] && compose_file="$PROJECT_PATH/docker-compose.yaml"
if [ -n "$compose_file" ]; then
    compose_content="$(read_file "$compose_file")"
    echo "$compose_content" | grep -qi "postgres" && db_list="$db_list\"postgresql\","
    echo "$compose_content" | grep -qi "mysql"    && db_list="$db_list\"mysql\","
    echo "$compose_content" | grep -qi "mongo"    && db_list="$db_list\"mongodb\","
    echo "$compose_content" | grep -qi "redis"    && db_list="$db_list\"redis\","
fi
[ -f "$PROJECT_PATH/prisma/schema.prisma" ] && db_list="$db_list\"prisma\","
sql_count=$(find "$PROJECT_PATH" -name "*.sql" ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | wc -l)
[ "$sql_count" -gt 0 ] && db_list="$db_list\"sql\","
database_frameworks="[${db_list%,}]"

# ---------------------------------------------------------------------------
# Stage 4: Project structure (monorepo vs single app)
# ---------------------------------------------------------------------------

log "Detecting project structure..."

is_monorepo="false"
monorepo_indicators=""

[ -d "$PROJECT_PATH/apps" ]      && monorepo_indicators="$monorepo_indicators apps"
[ -d "$PROJECT_PATH/packages" ]  && monorepo_indicators="$monorepo_indicators packages"
[ -d "$PROJECT_PATH/libs" ]      && monorepo_indicators="$monorepo_indicators libs"
[ -f "$PROJECT_PATH/lerna.json" ]               && monorepo_indicators="$monorepo_indicators lerna.json"
[ -f "$PROJECT_PATH/nx.json" ]                  && monorepo_indicators="$monorepo_indicators nx.json"
[ -f "$PROJECT_PATH/turbo.json" ]               && monorepo_indicators="$monorepo_indicators turbo.json"
[ -f "$PROJECT_PATH/pnpm-workspace.yaml" ]      && monorepo_indicators="$monorepo_indicators pnpm-workspace.yaml"
if [ -f "$pkg_json" ]; then
    grep -q '"workspaces"' "$pkg_json" 2>/dev/null && monorepo_indicators="$monorepo_indicators workspaces-field"
fi
[ -n "$monorepo_indicators" ] && is_monorepo="true"

# --- Multi-project detection: sub-dirs co build files rieng (go.mod, pubspec.yaml, package.json, CMakeLists.txt) ---
# Nhieu du an lon khong dung apps/ ma dat sub-projects truc tiep o root
multi_project_dirs=""
if [ "$is_monorepo" = "false" ]; then
    multi_count=0
    for sub_dir in "$PROJECT_PATH"/*/; do
        [ -d "$sub_dir" ] || continue
        sub_name="$(basename "$sub_dir")"
        # Bo qua dirs khong phai project
        case "$sub_name" in
            node_modules|.git|dist|build|docs|scripts|.claude|.github|.vscode|R\&D|ops|esp-idf|.mc-data) continue ;;
        esac
        # Kiem tra co build file rieng khong
        has_build=false
        [ -f "$sub_dir/go.mod" ] && has_build=true
        [ -f "$sub_dir/pubspec.yaml" ] && has_build=true
        [ -f "$sub_dir/package.json" ] && has_build=true
        [ -f "$sub_dir/CMakeLists.txt" ] && has_build=true
        [ -f "$sub_dir/Cargo.toml" ] && has_build=true
        [ -f "$sub_dir/pom.xml" ] && has_build=true
        [ -f "$sub_dir/Makefile" ] && has_build=true
        # Nested fullstack: co backend/ hoac frontend/ sub-dir voi build files
        [ -f "$sub_dir/backend/go.mod" ] && has_build=true
        [ -f "$sub_dir/backend/package.json" ] && has_build=true
        [ -f "$sub_dir/frontend/package.json" ] && has_build=true
        [ -f "$sub_dir/backend/Makefile" ] && has_build=true
        if [ "$has_build" = "true" ]; then
            multi_count=$((multi_count + 1))
            multi_project_dirs="$multi_project_dirs $sub_name"
        fi
    done
    if [ "$multi_count" -ge 2 ]; then
        is_monorepo="true"
        monorepo_indicators="$monorepo_indicators multi-project($multi_count)"
    fi
fi

# List apps in monorepo (scan ca apps/ va root-level multi-project dirs)
apps_json="[]"

# Helper: detect app type va framework tu 1 directory
detect_app_info() {
    local app_dir="$1"
    local app_name="$2"
    local app_path="$3"
    local app_type="unknown"
    local app_framework="unknown"

    local local_pkg="$app_dir/package.json"
    if [ -f "$local_pkg" ]; then
        local lc
        lc="$(read_file "$local_pkg")"
        echo "$lc" | grep -qi '"next"'         && { app_type="frontend"; app_framework="nextjs"; }
        echo "$lc" | grep -qi '"react-native"' && { app_type="mobile";   app_framework="react-native"; }
        echo "$lc" | grep -qi '"expo"'         && { app_type="mobile";   app_framework="expo"; }
        echo "$lc" | grep -qi '"express"'      && { app_type="backend";  app_framework="express"; }
        echo "$lc" | grep -qi '"@nestjs'       && { app_type="backend";  app_framework="nestjs"; }
        echo "$lc" | grep -qi '"fastify"'      && { app_type="backend";  app_framework="fastify"; }
        echo "$lc" | grep -qi '"react"'        && [ "$app_type" = "unknown" ] && { app_type="frontend"; app_framework="react"; }
    fi
    [ -f "$app_dir/pubspec.yaml" ] && { app_type="mobile"; app_framework="flutter"; }
    [ -f "$app_dir/go.mod" ] && [ "$app_type" = "unknown" ] && { app_type="backend"; app_framework="go"; }
    [ -f "$app_dir/CMakeLists.txt" ] && [ "$app_type" = "unknown" ] && { app_type="firmware"; app_framework="c_embedded"; }
    # .NET backend detection
    if [ "$app_type" = "unknown" ]; then
        local local_sln
        local_sln=$(find "$app_dir" -maxdepth 1 -name "*.sln" 2>/dev/null | head -1)
        local local_csproj
        local_csproj=$(find "$app_dir" -maxdepth 2 -name "*.csproj" 2>/dev/null | head -1)
        if [ -n "$local_sln" ] || [ -n "$local_csproj" ]; then
            app_type="backend"; app_framework="dotnet"
        fi
    fi
    # Sub-app detection (e.g., nira-erp has backend/ and frontend/)
    if [ -d "$app_dir/backend" ] || [ -d "$app_dir/frontend" ]; then
        app_type="fullstack"
        # Try detect sub-frameworks
        [ -f "$app_dir/backend/go.mod" ] && app_framework="go"
        [ -f "$app_dir/frontend/package.json" ] && app_framework="${app_framework}+react"
    fi
    echo "{\"name\":\"$app_name\",\"path\":\"$app_path\",\"type\":\"$app_type\",\"framework\":\"$app_framework\"}"
}

if [ "$is_monorepo" = "true" ]; then
    apps_entries=""

    # Scan apps/ directory (standard monorepo pattern)
    if [ -d "$PROJECT_PATH/apps" ]; then
        for app_dir in "$PROJECT_PATH/apps"/*/; do
            [ -d "$app_dir" ] || continue
            app_name="$(basename "$app_dir")"
            app_path="$(normalize_path "${app_dir#$PROJECT_PATH/}")"
            entry="$(detect_app_info "$app_dir" "$app_name" "$app_path")"
            apps_entries="$apps_entries$entry,"
        done
    fi

    # Scan root-level multi-project dirs
    if [ -n "$multi_project_dirs" ]; then
        for sub_name in $multi_project_dirs; do
            app_dir="$PROJECT_PATH/$sub_name/"
            [ -d "$app_dir" ] || continue
            app_path="$(normalize_path "$sub_name/")"
            entry="$(detect_app_info "$app_dir" "$sub_name" "$app_path")"
            apps_entries="$apps_entries$entry,"
        done
    fi

    apps_json="[${apps_entries%,}]"
fi

structure_type="single_app"
[ "$is_monorepo" = "true" ] && structure_type="monorepo"

# ---------------------------------------------------------------------------
# Stage 5: Code patterns
# ---------------------------------------------------------------------------

log "Finding code patterns..."

router_files=$(find "$PROJECT_PATH" -type f \
    \( -name "router*" -o -name "*router*" -o -name "routes*" -o -name "*routes*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
    2>/dev/null | wc -l)

module_dirs=$(find "$PROJECT_PATH" -type d -name "modules" \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    2>/dev/null | wc -l)

api_route_files=$(find "$PROJECT_PATH" -type f \
    \( -path "*/api/*" -o -path "*/routes/*" -o -path "*/controllers/*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    2>/dev/null | wc -l)

config_files_count=$(find "$PROJECT_PATH" -maxdepth 3 -type f \
    \( -name "*.config.*" -o -name "*.env" -o -name ".env*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    2>/dev/null | wc -l)

test_dirs=$(find "$PROJECT_PATH" -type d \
    \( -name "tests" -o -name "test" -o -name "__tests__" -o -name "spec" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    2>/dev/null | wc -l)

# ---------------------------------------------------------------------------
# Stage 6: Doc format counts
# ---------------------------------------------------------------------------

log "Counting doc formats..."

md_count=$(find "$PROJECT_PATH" -type f -name "*.md" \
    ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.claude/*" \
    ! -path "*/.mc-data/*" ! -path "*/Backup.mc-data/*" 2>/dev/null | wc -l)
openapi_count=$( (find "$PROJECT_PATH" -type f \( -name "*.yaml" -o -name "*.yml" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.claude/*" \
    ! -path "*/.mc-data/*" 2>/dev/null \
    | xargs grep -li "openapi:" 2>/dev/null || true) | wc -l)
jsdoc_count=$( (find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.js" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.claude/*" \
    ! -path "*/.mc-data/*" 2>/dev/null \
    | xargs grep -l "@param\|@returns\|@description" 2>/dev/null || true) | wc -l)

# ---------------------------------------------------------------------------
# Stage 7: Existing DEVKIT check
# ---------------------------------------------------------------------------

has_mcdata="false"
has_registry="false"
[ -d "$PROJECT_PATH/.mc-data" ]                                      && has_mcdata="true"
[ -f "$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json" ]         && has_registry="true"

# ---------------------------------------------------------------------------
# Stage 7b: Doc Maturity Detection
# ---------------------------------------------------------------------------

log "Detecting doc maturity..."

# --- Phase doc counts ---
phase0_exists="false"
phase0_doc_count=0
if [ -d "$PROJECT_PATH/.mc-data/docs/phase0-brainstorm" ]; then
    phase0_exists="true"
    phase0_doc_count=$(find "$PROJECT_PATH/.mc-data/docs/phase0-brainstorm" -type f -name "*.md" 2>/dev/null | wc -l)
fi

phase1_exists="false"
phase1_doc_count=0
if [ -d "$PROJECT_PATH/.mc-data/docs/phase1-business" ]; then
    phase1_exists="true"
    phase1_doc_count=$(find "$PROJECT_PATH/.mc-data/docs/phase1-business" -type f -name "*.md" 2>/dev/null | wc -l)
fi

phase2_exists="false"
phase2_doc_count=0
if [ -d "$PROJECT_PATH/.mc-data/docs/phase2-features" ]; then
    phase2_exists="true"
    phase2_doc_count=$(find "$PROJECT_PATH/.mc-data/docs/phase2-features" -type f -name "*.md" 2>/dev/null | wc -l)
fi

phase3_exists="false"
phase3_doc_count=0
if [ -d "$PROJECT_PATH/.mc-data/docs/phase3-architecture" ]; then
    phase3_exists="true"
    phase3_doc_count=$(find "$PROJECT_PATH/.mc-data/docs/phase3-architecture" -type f -name "*.md" 2>/dev/null | wc -l)
fi

# --- Registry stats (lightweight grep, no jq dependency) ---
reg_systems=0
reg_modules=0
reg_requirements=0
reg_features=0
reg_impl_done=0
reg_impl_done_pct=0

if [ "$has_registry" = "true" ]; then
    reg_file="$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json"
    # Count array entries by matching "id": "PREFIX-" patterns
    # NOTE: KHONG dung [,{] prefix — pretty-printed JSON co { va "id" tren KHAC dong → match fail
    # NOTE: grep -c exits 1 when count=0, phai dung || true (KHONG dung || echo 0
    # vi echo 0 se append them "0" vao stdout → "0\n0" → integer error)
    reg_systems=$(grep -cE '"id":[[:space:]]*"SYS-' "$reg_file" 2>/dev/null || true)
    reg_modules=$(grep -cE '"id":[[:space:]]*"MOD-' "$reg_file" 2>/dev/null || true)
    reg_requirements=$(grep -cE '"id":[[:space:]]*"REQ-' "$reg_file" 2>/dev/null || true)
    reg_features=$(grep -cE '"id":[[:space:]]*"FEAT-' "$reg_file" 2>/dev/null || true)
    reg_impl_done=$(grep -c '"impl_status".*"done"' "$reg_file" 2>/dev/null || true)
    # Sanitize: dam bao la integer (strip whitespace, default 0)
    reg_systems=$(echo "$reg_systems" | tr -d '[:space:]'); [ -z "$reg_systems" ] && reg_systems=0
    reg_modules=$(echo "$reg_modules" | tr -d '[:space:]'); [ -z "$reg_modules" ] && reg_modules=0
    reg_requirements=$(echo "$reg_requirements" | tr -d '[:space:]'); [ -z "$reg_requirements" ] && reg_requirements=0
    reg_features=$(echo "$reg_features" | tr -d '[:space:]'); [ -z "$reg_features" ] && reg_features=0
    reg_impl_done=$(echo "$reg_impl_done" | tr -d '[:space:]'); [ -z "$reg_impl_done" ] && reg_impl_done=0
    if [ "$reg_requirements" -gt 0 ]; then
        reg_impl_done_pct=$((reg_impl_done * 100 / reg_requirements))
    fi
fi

# --- External docs (khi khong co .mc-data/) ---
readme_files=$(find "$PROJECT_PATH" -maxdepth 3 -type f -iname "readme*" \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.claude/*" \
    ! -path "*/.mc-data/*" 2>/dev/null | wc -l)
wiki_files=0
wiki_doc_dirs=""
[ -d "$PROJECT_PATH/wiki" ] && wiki_doc_dirs="$PROJECT_PATH/wiki"
[ -d "$PROJECT_PATH/docs" ] && wiki_doc_dirs="$wiki_doc_dirs $PROJECT_PATH/docs"
if [ -n "$wiki_doc_dirs" ]; then
    wiki_files=$(find $wiki_doc_dirs -type f -name "*.md" 2>/dev/null | wc -l)
fi
openapi_ext_count="$openapi_count"

# --- Determine maturity level ---
maturity_level="CODE_ONLY"
recommended_action="full_pipeline"

phases_with_docs=0
[ "$phase0_doc_count" -gt 0 ] && phases_with_docs=$((phases_with_docs + 1))
[ "$phase1_doc_count" -gt 0 ] && phases_with_docs=$((phases_with_docs + 1))
[ "$phase2_doc_count" -gt 0 ] && phases_with_docs=$((phases_with_docs + 1))
[ "$phase3_doc_count" -gt 0 ] && phases_with_docs=$((phases_with_docs + 1))

if [ "$has_mcdata" = "true" ]; then
    if [ "$has_registry" = "true" ] && [ "$reg_requirements" -gt 0 ] && [ "$phases_with_docs" -eq 4 ]; then
        # Co day du .mc-data/ voi registry va 4 phases CO NOI DUNG
        if [ "$reg_impl_done_pct" -ge 75 ]; then
            maturity_level="NEAR_COMPLETE"
            recommended_action="fast_track_to_verify_sync"
        else
            maturity_level="CODE_PLUS_DEVKIT_COMPLETE"
            recommended_action="validate_and_gap_analysis"
        fi
    elif [ "$phases_with_docs" -gt 0 ] || [ "$has_registry" = "true" ]; then
        # Co .mc-data/ VA co it nhat 1 phase co docs hoac co registry
        maturity_level="CODE_PLUS_DEVKIT_PARTIAL"
        recommended_action="merge_and_fill_gaps"
    else
        # Co .mc-data/ nhung dirs rong — coi nhu chua co DEVKIT docs
        # Kiem tra external docs
        if [ "$md_count" -ge 5 ] || [ "$openapi_count" -gt 0 ] || [ "$readme_files" -ge 3 ]; then
            maturity_level="CODE_PLUS_EXTERNAL_DOCS"
            recommended_action="full_pipeline"
        else
            maturity_level="CODE_ONLY"
            recommended_action="full_pipeline"
        fi
    fi
elif [ "$md_count" -ge 5 ] || [ "$openapi_count" -gt 0 ] || [ "$readme_files" -ge 3 ]; then
    # Khong co .mc-data/ nhung co nhieu external docs
    maturity_level="CODE_PLUS_EXTERNAL_DOCS"
    recommended_action="full_pipeline"
fi

log "Doc maturity: $maturity_level (recommended: $recommended_action)"

# ---------------------------------------------------------------------------
# Stage 8: Complexity assessment
# ---------------------------------------------------------------------------

log "Calculating complexity..."

# Uoc tinh so systems dua tren cau truc monorepo hoac so lang
estimated_systems=1
if [ "$is_monorepo" = "true" ]; then
    if [ -d "$PROJECT_PATH/apps" ]; then
        app_count=$(find "$PROJECT_PATH/apps" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        estimated_systems="$app_count"
    fi
    # Multi-project: dem so sub-projects phat hien duoc
    if [ -n "$multi_project_dirs" ]; then
        multi_sys_count=0
        for _s in $multi_project_dirs; do multi_sys_count=$((multi_sys_count + 1)); done
        [ "$multi_sys_count" -gt "$estimated_systems" ] && estimated_systems="$multi_sys_count"
    fi
fi

# Uoc tinh so modules: scan nhieu patterns de co estimate chinh xac hon
estimated_modules=5
if [ -d "$PROJECT_PATH/src" ]; then
    estimated_modules=$(find "$PROJECT_PATH/src" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
fi
# Monorepo / multi-project: dem modules trong cac apps/sub-projects
if [ "$is_monorepo" = "true" ]; then
    mono_modules=0
    # Scan apps/ dir
    if [ -d "$PROJECT_PATH/apps" ]; then
        for app_dir in "$PROJECT_PATH/apps"/*/; do
            [ -d "$app_dir" ] || continue
            dotnet_mods=$(find "$app_dir" -maxdepth 1 -mindepth 1 -type d -name "*.Modules.*" 2>/dev/null | wc -l)
            src_mods=0
            [ -d "$app_dir/src/modules" ] && src_mods=$(find "$app_dir/src/modules" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
            [ -d "$app_dir/src" ] && [ "$src_mods" -eq 0 ] && src_mods=$(find "$app_dir/src" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
            mono_modules=$((mono_modules + dotnet_mods + src_mods))
        done
    fi
    # Scan multi-project root-level dirs
    if [ -n "$multi_project_dirs" ]; then
        for sub_name in $multi_project_dirs; do
            app_dir="$PROJECT_PATH/$sub_name"
            [ -d "$app_dir" ] || continue
            src_mods=0
            # Go: internal/ hoac pkg/ pattern
            [ -d "$app_dir/internal" ] && src_mods=$(find "$app_dir/internal" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
            [ -d "$app_dir/src/modules" ] && src_mods=$((src_mods + $(find "$app_dir/src/modules" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)))
            [ -d "$app_dir/src/components/modules" ] && src_mods=$((src_mods + $(find "$app_dir/src/components/modules" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)))
            # Flutter: lib/features/ pattern
            [ -d "$app_dir/lib/features" ] && src_mods=$((src_mods + $(find "$app_dir/lib/features" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)))
            # Firmware: components/ pattern
            [ -d "$app_dir/components" ] && src_mods=$((src_mods + $(find "$app_dir/components" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)))
            mono_modules=$((mono_modules + src_mods))
        done
    fi
    [ "$mono_modules" -gt "$estimated_modules" ] && estimated_modules="$mono_modules"
fi
[ "$estimated_modules" -eq 0 ] && estimated_modules=5

# LPM trigger: source_files > 500 OR doc_files > 100
lpm_triggered="false"
if [ "$source_files" -gt 500 ] || [ "$doc_files" -gt 100 ]; then
    lpm_triggered="true"
fi

# Uoc tinh so sessions: base 3, +1 moi 200 source files, +2 neu LPM
estimated_sessions=3
extra_sessions=$(( (source_files / 200) ))
estimated_sessions=$((estimated_sessions + extra_sessions))
[ "$lpm_triggered" = "true" ] && estimated_sessions=$((estimated_sessions + 2))

# ---------------------------------------------------------------------------
# Stage 9: Write project-profile.json
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Stage 9b: Project Size Classification
# ---------------------------------------------------------------------------

project_size="LARGE"
if [ "$total_files" -lt 100 ]; then
    project_size="SMALL"
elif [ "$total_files" -le 500 ]; then
    project_size="MEDIUM"
fi

log "Project size: $project_size ($total_files files)"

# ---------------------------------------------------------------------------
# Stage 9c: DOCS_ONLY Detection
# ---------------------------------------------------------------------------

if [ "$source_files" -eq 0 ] && [ "$doc_files" -gt 0 ]; then
    maturity_level="DOCS_ONLY"
    recommended_action="docs_first_pipeline"
    log "DOCS_ONLY detected: 0 source files, $doc_files doc files"
fi

# ---------------------------------------------------------------------------
# Stage 10: Write project-profile.json
# ---------------------------------------------------------------------------

PROFILE_FILE="$OUTPUT_DIR/project-profile.json"
SCAN_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
ESCAPED_PROJECT_PATH="$(json_escape "$PROJECT_PATH")"

log "Writing $PROFILE_FILE ..."

# Build JSON content into variable, then atomic_write_json để validate + write nguyên tử.
# Dùng read -d '' heredoc thay vì `cat > file <<EOF` trực tiếp, để có thể jq-validate.
_profile_json="$(cat <<EOF
{
  "scan_timestamp": "$SCAN_TIMESTAMP",
  "project_path": "$ESCAPED_PROJECT_PATH",
  "project_size": "$project_size",
  "file_counts": {
    "total": $total_files,
    "source": $source_files,
    "doc": $doc_files,
    "config": $config_files,
    "test": $test_files,
    "asset": $asset_files
  },
  "languages": {
    "primary": "$primary_lang",
    "secondary": $secondary_langs_json,
    "counts": {
      "typescript": $typescript_total,
      "javascript": $javascript_total,
      "python": $py_count,
      "csharp": $cs_count,
      "java": $java_count,
      "go": $go_count,
      "rust": $rs_count,
      "ruby": $rb_count,
      "php": $php_count,
      "swift": $swift_count,
      "kotlin": $kt_count,
      "dart": $dart_count,
      "c": $c_count,
      "h": $h_count,
      "cpp": $cpp_count
    }
  },
  "frameworks": {
    "backend": $backend_frameworks,
    "frontend": $frontend_frameworks,
    "mobile": $mobile_frameworks,
    "database": $database_frameworks
  },
  "structure": {
    "type": "$structure_type",
    "is_monorepo": $is_monorepo,
    "apps": $apps_json
  },
  "code_patterns": {
    "router_files": $router_files,
    "module_dirs": $module_dirs,
    "api_route_files": $api_route_files,
    "config_files": $config_files_count,
    "test_dirs": $test_dirs
  },
  "doc_formats": {
    "markdown": $md_count,
    "openapi": $openapi_count,
    "jsdoc": $jsdoc_count
  },
  "devkit": {
    "has_mcdata": $has_mcdata,
    "has_registry": $has_registry
  },
  "doc_maturity": {
    "level": "$maturity_level",
    "registry_stats": {
      "systems": $reg_systems,
      "modules": $reg_modules,
      "requirements": $reg_requirements,
      "features": $reg_features,
      "impl_done": $reg_impl_done,
      "impl_done_pct": $reg_impl_done_pct
    },
    "phase_status": {
      "phase0": { "exists": $phase0_exists, "doc_count": $phase0_doc_count },
      "phase1": { "exists": $phase1_exists, "doc_count": $phase1_doc_count },
      "phase2": { "exists": $phase2_exists, "doc_count": $phase2_doc_count },
      "phase3": { "exists": $phase3_exists, "doc_count": $phase3_doc_count }
    },
    "external_docs": {
      "readme_files": $readme_files,
      "wiki_files": $wiki_files,
      "openapi_specs": $openapi_ext_count
    },
    "recommended_action": "$recommended_action"
  },
  "complexity": {
    "estimated_systems": $estimated_systems,
    "estimated_modules": $estimated_modules,
    "lpm_triggered": $lpm_triggered,
    "estimated_sessions": $estimated_sessions
  }
}
EOF
)"

if ! atomic_write_json "$PROFILE_FILE" "$_profile_json"; then
    warn "atomic_write_json failed; falling back to direct write (no validation)"
    printf '%s\n' "$_profile_json" > "$PROFILE_FILE"
fi

# POST-WRITE VALIDATION: ensure output JSON is parseable
if ! validate_json "$PROFILE_FILE"; then
    warn "project-profile.json failed JSON validation — downstream consumers may fail"
fi

log "Done. Profile written to: $PROFILE_FILE"
echo "$PROFILE_FILE"
