#!/usr/bin/env bash
# legacy-scan-assess.sh — Quantitative assessment cho wf-legacy-scan Stage 0A
# Usage: bash .claude/scripts/legacy-scan-assess.sh <project-path> <output-dir>
#
# Input:  project directory, output directory (co project-profile.json)
# Output: assessment-scores.json in output-dir
#
# 3 chieu danh gia: code_quality, doc_quality, alignment
# Thresholds: HIGH >70, MED 40-70, LOW <40, NONE = 0
#
# Phase G refactor (v5.0):
# - Source legacy-scan-common.sh
# - Per-component scoring clamps (fixes overflow bug where sum > 100 pre-final-clamp)
# - STALE_THRESHOLD_DAYS configurable qua env var (was hardcoded 180)
# - atomic_write_json + validate_json post-write

# Shared library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="legacy-scan-assess"
# shellcheck source=./legacy-scan-common.sh
source "$SCRIPTS_DIR/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

PROJECT_PATH="${1:-.}"
OUTPUT_DIR="${2:-.mc-data/work/legacy-scan}"

# ---------------------------------------------------------------------------
# Helpers (local overrides for v4.1 log format + safe path normalize)
# ---------------------------------------------------------------------------

log()  { echo "[assess] $*" >&2; }
warn() { echo "[assess][WARN] $*" >&2; }

normalize_path() { echo "$1" | tr '\\' '/'; }

# json_escape từ common.sh là compatible. Giữ local override để v5.0
# không thay đổi hành vi JSON escaping (quote-compatible, không strip CR).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    echo "$s"
}

# Clamp score vào [0, max] — dùng cho per-component scoring.
# Args: score max
clamp() {
    local s="$1" m="$2"
    if [ "$s" -gt "$m" ]; then echo "$m"
    elif [ "$s" -lt 0 ]; then echo 0
    else echo "$s"
    fi
}

PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Project path does not exist: $PROJECT_PATH" >&2
    exit 1
fi

PROFILE_JSON="$OUTPUT_DIR/project-profile.json"
if [ ! -f "$PROFILE_JSON" ]; then
    warn "project-profile.json not found — some scores will be 0"
fi

# ---------------------------------------------------------------------------
# PASS 1: Single find + awk for ALL file counts
# Thay vi 8+ find traversals rieng le (~29s → ~5s cho LARGE projects)
# ---------------------------------------------------------------------------

log "Calculating code quality score..."

_assess_counts=$(find "$PROJECT_PATH" -type f \
    ! -path "*/node_modules/*" ! -path "*/.git/*" \
    ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" \
    ! -path "*/vendor/*" ! -path "*/bin/*" ! -path "*/obj/*" \
    ! -path "*/.next/*" ! -path "*/.nuxt/*" ! -path "*/coverage/*" \
    ! -path "*/venv/*" ! -path "*/.venv/*" ! -path "*/target/*" \
    ! -path "*/.dart_tool/*" ! -path "*/.mc-data/*" \
    ! -path "*/esp-idf/*" ! -path "*/.pub-cache/*" ! -path "*/.flutter/*" \
    ! -path "*/Pods/*" ! -path "*/.gradle/*" \
    2>/dev/null | awk -F. '{
    name = $0; sub(/.*\//, "", name)
    ext = tolower($NF)
    path = tolower($0)

    # Source files
    if (ext ~ /^(ts|tsx|js|jsx|py|cs|java|go|rs|rb|php|dart|c|h|cpp)$/) {
        src++
        # Test file detection — name pattern OR dir pattern, dem 1 lan moi file
        if (name ~ /\.(spec|test)\./ || name ~ /_test\./ || name ~ /Tests\.cs$/ || name ~ /Test\.java$/ \
            || path ~ /\/__tests__\// || path ~ /\/test\// || path ~ /\/tests\//) tst++
    }
    # Markdown files
    if (ext == "md") {
        md++
        if (tolower(name) ~ /^readme/) readme++
    }
    # YAML files (for openapi check later)
    if (ext == "yaml" || ext == "yml") yaml++
    # API route files
    if (path ~ /\/api\// || path ~ /\/routes\// || path ~ /\/controllers\//) api_route++
}
END {
    printf "%d %d %d %d %d %d %d\n", src+0, tst+0, md+0, readme+0, yaml+0, api_route+0, tst+0
}')
read total_source test_files md_files readme_files yaml_count api_route_files test_files_strict <<< "$_assess_counts"

# ---------------------------------------------------------------------------
# PASS 2: Content-based checks (grep through source files)
# Single find | xargs grep cho TODO/FIXME + REQ-ID counts
# ---------------------------------------------------------------------------

todo_fixme_count=0
req_id_in_code=0
jsdoc_files=0

if [ "$total_source" -gt 0 ]; then
    # Single find traversal, pipe to parallel grep operations via temp file
    _src_list=$(mktemp 2>/dev/null || echo "/tmp/assess-src-$$")
    find "$PROJECT_PATH" -type f \
        \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
           -o -name '*.py' -o -name '*.cs' -o -name '*.java' -o -name '*.go' -o -name '*.rs' \
           -o -name '*.rb' -o -name '*.php' -o -name '*.dart' -o -name '*.c' -o -name '*.h' -o -name '*.cpp' \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" \
        ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" \
        ! -path "*/vendor/*" ! -path "*/bin/*" ! -path "*/obj/*" \
        ! -path "*/.next/*" ! -path "*/.mc-data/*" \
        ! -path "*/esp-idf/*" ! -path "*/.pub-cache/*" ! -path "*/.dart_tool/*" \
        ! -path "*/Pods/*" ! -path "*/.gradle/*" ! -path "*/.flutter/*" \
        -print0 2>/dev/null > "$_src_list"

    # TODO/FIXME count (grep -c outputs filepath:count, extract counts with awk -F:)
    # NOTE: dung || true thay || echo 0 (grep -c exits 1 khi count=0 → echo 0 append "0" vao stdout)
    todo_fixme_count=$(xargs -0 grep -ciE 'TODO|FIXME|HACK|XXX' < "$_src_list" 2>/dev/null \
        | awk -F: '{s+=$NF} END {print s+0}' || true)

    # REQ-ID in code count (grep -c outputs filepath:count, extract counts with awk)
    req_id_in_code=$(xargs -0 grep -c 'REQ-' < "$_src_list" 2>/dev/null \
        | awk -F: '{s+=$NF} END {print s+0}' || true)

    # JSDoc files (only TS/JS)
    jsdoc_files=$(xargs -0 grep -l '@param\|@returns\|@description' < "$_src_list" 2>/dev/null | wc -l || true)

    rm -f "$_src_list" 2>/dev/null
fi

# Ensure clean integers (strip whitespace, newlines — xargs/wc may produce trailing chars)
todo_fixme_count=$(echo "$todo_fixme_count" | tr -d '[:space:]')
req_id_in_code=$(echo "$req_id_in_code" | tr -d '[:space:]')
jsdoc_files=$(echo "$jsdoc_files" | tr -d '[:space:]')
[ -z "$todo_fixme_count" ] && todo_fixme_count=0
[ -z "$req_id_in_code" ] && req_id_in_code=0
[ -z "$jsdoc_files" ] && jsdoc_files=0

# TODO density: todo_fixme / total_source * 100
todo_density=0
if [ "$total_source" -gt 0 ]; then
    todo_density=$((todo_fixme_count * 100 / total_source))
fi

# Test ratio
test_ratio=0
if [ "$total_source" -gt 0 ]; then
    test_ratio=$((test_files * 100 / total_source))
fi

# JSDoc ratio
jsdoc_ratio=0
if [ "$total_source" -gt 0 ]; then
    jsdoc_ratio=$((jsdoc_files * 100 / total_source))
fi

# ---------------------------------------------------------------------------
# 1c-1e: Config checks (filesystem only, fast)
# ---------------------------------------------------------------------------

# Linting config
lint_score=0
# ESLint: legacy config (.eslintrc.*) hoac flat config (eslint.config.*)
( [ -f "$PROJECT_PATH/.eslintrc.js" ] || [ -f "$PROJECT_PATH/.eslintrc.json" ] || \
    [ -f "$PROJECT_PATH/.eslintrc.yml" ] || [ -f "$PROJECT_PATH/.eslintrc.cjs" ] || \
    [ -f "$PROJECT_PATH/eslint.config.js" ] || [ -f "$PROJECT_PATH/eslint.config.mjs" ] || \
    [ -f "$PROJECT_PATH/eslint.config.cjs" ] || [ -f "$PROJECT_PATH/eslint.config.ts" ] ) && lint_score=$((lint_score + 15))
( [ -f "$PROJECT_PATH/.prettierrc" ] || [ -f "$PROJECT_PATH/.prettierrc.json" ] || \
    [ -f "$PROJECT_PATH/.prettierrc.js" ] ) && lint_score=$((lint_score + 10))
[ -f "$PROJECT_PATH/pyproject.toml" ] && grep -q "ruff\|pylint\|flake8\|black" "$PROJECT_PATH/pyproject.toml" 2>/dev/null && lint_score=$((lint_score + 15))
[ -f "$PROJECT_PATH/.editorconfig" ] && lint_score=$((lint_score + 5))

# Monorepo: scan sub-project lint configs too (legacy + flat config)
for sub_lint in "$PROJECT_PATH"/*/eslint.config.* "$PROJECT_PATH"/*/.eslintrc.* ; do
    [ -f "$sub_lint" ] && { lint_score=$((lint_score + 15)); break; }
done
# Biome (modern linter thay the ESLint)
[ -f "$PROJECT_PATH/biome.json" ] || [ -f "$PROJECT_PATH/biome.jsonc" ] && lint_score=$((lint_score + 15))
# v5.0 FIX: Per-component cap at 25 (was uncapped → có thể đạt 60+ với monorepo + biome)
lint_score="$(clamp "$lint_score" 25)"

# CI config
ci_score=0
[ -d "$PROJECT_PATH/.github/workflows" ] && ci_score=$((ci_score + 15))
[ -f "$PROJECT_PATH/.gitlab-ci.yml" ] && ci_score=$((ci_score + 15))
[ -f "$PROJECT_PATH/Jenkinsfile" ] && ci_score=$((ci_score + 15))
# v5.0 FIX: Per-component cap at 15 (was uncapped → có thể đạt 45 với 3 CI systems)
ci_score="$(clamp "$ci_score" 15)"

# TypeScript strict mode
ts_strict=0
if [ -f "$PROJECT_PATH/tsconfig.json" ]; then
    grep -q '"strict"[[:space:]]*:[[:space:]]*true' "$PROJECT_PATH/tsconfig.json" 2>/dev/null && ts_strict=10
fi

# Code Quality Score calculation: Base 50 + bonuses - penalties
# v5.0 FIX: Per-component caps applied above (lint_score ≤25, ci_score ≤15)
# Test bonus is already mutually exclusive (ge 30 OR 10-30), max +15.
# ts_strict max +10. Sum of bonuses ≤ 15+25+15+10 = 65 → base 50 + 65 = 115 → clamp to 100.
code_score=50
test_bonus=0
[ "$test_ratio" -ge 30 ] && test_bonus=15
[ "$test_ratio" -ge 10 ] && [ "$test_ratio" -lt 30 ] && test_bonus=8
code_score=$((code_score + test_bonus))
code_score=$((code_score + lint_score))
code_score=$((code_score + ci_score))
code_score=$((code_score + ts_strict))
[ "$todo_density" -gt 20 ] && code_score=$((code_score - 15))
[ "$todo_density" -gt 10 ] && [ "$todo_density" -le 20 ] && code_score=$((code_score - 8))
[ "$total_source" -eq 0 ] && code_score=0
code_score="$(clamp "$code_score" 100)"

log "Code quality: $code_score (tests=$test_ratio%, TODO=$todo_density%, lint=$lint_score, CI=$ci_score)"

# ---------------------------------------------------------------------------
# 2. Doc Quality Score (0-100)
# ---------------------------------------------------------------------------

log "Calculating doc quality score..."

# OpenAPI detection (small targeted grep on yaml files only)
openapi_files=0
if [ "$yaml_count" -gt 0 ]; then
    openapi_files=$(find "$PROJECT_PATH" -type f \( -name '*.yaml' -o -name '*.yml' \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/esp-idf/*" \
        -print0 2>/dev/null | xargs -0 grep -li "openapi:" 2>/dev/null | wc -l || true)
fi

changelog=$([ -f "$PROJECT_PATH/CHANGELOG.md" ] || [ -f "$PROJECT_PATH/CHANGELOG" ] && echo 1 || echo 0)
contributing=$([ -f "$PROJECT_PATH/CONTRIBUTING.md" ] && echo 1 || echo 0)

# DEVKIT docs (mc-data)
devkit_doc_score=0
phase0_md=0; [ -d "$PROJECT_PATH/.mc-data/docs/phase0-brainstorm" ] && phase0_md=$(find "$PROJECT_PATH/.mc-data/docs/phase0-brainstorm" -type f -name '*.md' 2>/dev/null | wc -l)
phase1_md=0; [ -d "$PROJECT_PATH/.mc-data/docs/phase1-business" ] && phase1_md=$(find "$PROJECT_PATH/.mc-data/docs/phase1-business" -type f -name '*.md' 2>/dev/null | wc -l)
phase2_md=0; [ -d "$PROJECT_PATH/.mc-data/docs/phase2-features" ] && phase2_md=$(find "$PROJECT_PATH/.mc-data/docs/phase2-features" -type f -name '*.md' 2>/dev/null | wc -l)
phase3_md=0; [ -d "$PROJECT_PATH/.mc-data/docs/phase3-architecture" ] && phase3_md=$(find "$PROJECT_PATH/.mc-data/docs/phase3-architecture" -type f -name '*.md' 2>/dev/null | wc -l)
[ "$phase0_md" -gt 0 ] && devkit_doc_score=$((devkit_doc_score + 15))
[ "$phase1_md" -gt 0 ] && devkit_doc_score=$((devkit_doc_score + 15))
[ "$phase2_md" -gt 0 ] && devkit_doc_score=$((devkit_doc_score + 15))
[ "$phase3_md" -gt 0 ] && devkit_doc_score=$((devkit_doc_score + 15))
[ -f "$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json" ] && devkit_doc_score=$((devkit_doc_score + 20))
# v5.0 FIX: Per-component cap at 60 (previous max 80 có thể đẩy doc_score vượt 100 trước final clamp)
devkit_doc_score="$(clamp "$devkit_doc_score" 60)"

# Staleness (stale docs > STALE_THRESHOLD_DAYS, default 180 — configurable qua env var)
stale_docs=0
recent_docs="$md_files"
if [ "$md_files" -gt 0 ]; then
    stale_docs=$(find "$PROJECT_PATH" -type f -name '*.md' -mtime "+${STALE_THRESHOLD_DAYS}" \
        ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/esp-idf/*" \
        2>/dev/null | wc -l)
    recent_docs=$((md_files - stale_docs))
fi

# Doc Quality Score
doc_score=0
[ "$readme_files" -ge 1 ] && doc_score=$((doc_score + 10))
[ "$md_files" -ge 5 ] && doc_score=$((doc_score + 10))
[ "$md_files" -ge 15 ] && doc_score=$((doc_score + 10))
# Bonus cho du an co nhieu docs (>100 files = mature documentation)
[ "$md_files" -ge 100 ] && doc_score=$((doc_score + 10))
[ "$md_files" -ge 500 ] && doc_score=$((doc_score + 5))
[ "$openapi_files" -gt 0 ] && doc_score=$((doc_score + 15))
[ "$changelog" -eq 1 ] && doc_score=$((doc_score + 5))
[ "$contributing" -eq 1 ] && doc_score=$((doc_score + 5))
[ "$jsdoc_ratio" -ge 20 ] && doc_score=$((doc_score + 10))
[ "$jsdoc_ratio" -ge 5 ] && [ "$jsdoc_ratio" -lt 20 ] && doc_score=$((doc_score + 5))
doc_score=$((doc_score + devkit_doc_score))
if [ "$md_files" -gt 0 ]; then
    stale_pct=$((stale_docs * 100 / md_files))
    [ "$stale_pct" -gt 50 ] && doc_score=$((doc_score - 10))
fi
doc_score="$(clamp "$doc_score" 100)"

log "Doc quality: $doc_score (md=$md_files, openapi=$openapi_files, devkit=$devkit_doc_score)"

# ---------------------------------------------------------------------------
# 3. Alignment Score (0-100)
# ---------------------------------------------------------------------------

log "Calculating alignment score..."

alignment_score=0

# DEVKIT registry alignment
reg_reqs=0
reg_impl_done=0
if [ -f "$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json" ]; then
    # NOTE: grep -c exits 1 when count=0, phai dung || true (KHONG dung || echo 0)
    reg_reqs=$(grep -cE '"id":[[:space:]]*"REQ-' "$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json" 2>/dev/null || true)
    reg_impl_done=$(grep -c '"impl_status".*"done"' "$PROJECT_PATH/.mc-data/docs/_meta/req-registry.json" 2>/dev/null || true)
    # Sanitize: dam bao la integer
    reg_reqs=$(echo "$reg_reqs" | tr -d '[:space:]'); [ -z "$reg_reqs" ] && reg_reqs=0
    reg_impl_done=$(echo "$reg_impl_done" | tr -d '[:space:]'); [ -z "$reg_impl_done" ] && reg_impl_done=0
fi

if [ "$reg_reqs" -gt 0 ]; then
    impl_pct=$((reg_impl_done * 100 / reg_reqs))
    alignment_score=$((impl_pct * 60 / 100))
fi
[ "$req_id_in_code" -gt 0 ] && alignment_score=$((alignment_score + 20))
if [ "$api_route_files" -gt 0 ] && [ "$openapi_files" -gt 0 ]; then
    alignment_score=$((alignment_score + 20))
elif [ "$api_route_files" -gt 0 ] && [ "$md_files" -ge 3 ]; then
    alignment_score=$((alignment_score + 10))
fi
alignment_score="$(clamp "$alignment_score" 100)"

log "Alignment: $alignment_score (req_in_code=$req_id_in_code, reg_reqs=$reg_reqs, impl=$reg_impl_done)"

# ---------------------------------------------------------------------------
# 4. Determine thresholds
# ---------------------------------------------------------------------------

classify_level() {
    local score=$1
    if [ "$score" -eq 0 ]; then echo "NONE"
    elif [ "$score" -lt 40 ]; then echo "LOW"
    elif [ "$score" -le 70 ]; then echo "MED"
    else echo "HIGH"
    fi
}

code_level="$(classify_level "$code_score")"
doc_level="$(classify_level "$doc_score")"
alignment_level="$(classify_level "$alignment_score")"

log "Levels: code=$code_level, doc=$doc_level, alignment=$alignment_level"

# ---------------------------------------------------------------------------
# 5. Determine project_size
# ---------------------------------------------------------------------------

total_files=0
if [ -f "$PROFILE_JSON" ]; then
    total_files=$(grep '"total"' "$PROFILE_JSON" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
fi
[ -z "$total_files" ] && total_files=0

if [ "$total_files" -lt 100 ]; then project_size="SMALL"
elif [ "$total_files" -le 500 ]; then project_size="MEDIUM"
else project_size="LARGE"
fi

log "Project size: $project_size ($total_files files)"

# ---------------------------------------------------------------------------
# 6. Write output
# ---------------------------------------------------------------------------

SCORES_FILE="$OUTPUT_DIR/assessment-scores.json"
ASSESS_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
ESCAPED_PROJECT_PATH="$(json_escape "$PROJECT_PATH")"

_scores_json="$(cat <<EOF
{
  "assess_timestamp": "$ASSESS_TIMESTAMP",
  "project_path": "$ESCAPED_PROJECT_PATH",
  "project_size": "$project_size",
  "total_files": $total_files,
  "scores": {
    "code_quality": {
      "score": $code_score,
      "level": "$code_level",
      "details": {
        "total_source_files": $total_source,
        "test_files": $test_files,
        "test_ratio_pct": $test_ratio,
        "todo_fixme_count": $todo_fixme_count,
        "todo_density_pct": $todo_density,
        "lint_score": $lint_score,
        "ci_score": $ci_score,
        "ts_strict": $ts_strict
      }
    },
    "doc_quality": {
      "score": $doc_score,
      "level": "$doc_level",
      "details": {
        "md_files": $md_files,
        "readme_files": $readme_files,
        "openapi_files": $openapi_files,
        "changelog": $changelog,
        "contributing": $contributing,
        "jsdoc_ratio_pct": $jsdoc_ratio,
        "devkit_doc_score": $devkit_doc_score,
        "stale_docs": $stale_docs,
        "recent_docs": $recent_docs
      }
    },
    "alignment": {
      "score": $alignment_score,
      "level": "$alignment_level",
      "details": {
        "req_id_in_code": $req_id_in_code,
        "registry_reqs": $reg_reqs,
        "registry_impl_done": $reg_impl_done,
        "api_route_files": $api_route_files,
        "openapi_files": $openapi_files
      }
    }
  }
}
EOF
)"

if ! atomic_write_json "$SCORES_FILE" "$_scores_json"; then
    warn "atomic_write_json failed; falling back to direct write"
    printf '%s\n' "$_scores_json" > "$SCORES_FILE"
fi

if ! validate_json "$SCORES_FILE"; then
    warn "assessment-scores.json failed JSON validation"
fi

log "Done. Assessment scores written to: $SCORES_FILE"
echo "$SCORES_FILE"
