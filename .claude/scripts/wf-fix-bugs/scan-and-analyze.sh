#!/usr/bin/env bash
# =============================================================================
# scan-and-analyze.sh — Phase 2 Scan & Analyze (gộp Steps 2.3-2.7 v10.4)
# =============================================================================
# Gộp 5 steps Phase 2 thành 1 atomic call:
#   2.3 Interface Type Detection (web|mobile|hybrid|api-only)
#   2.4 Code Inventory          (CI-ROUTE → enumerate files + languages)
#   2.5 Doc Inventory           (req-registry + .mc-data/docs/ + READMEs)
#   2.6 Scope Analysis          (aggregate metrics, dep level, ci_coverage)
#   2.7 WRITE 3 JSON outputs    (CORE-031 READ→POPULATE→ATOMIC WRITE)
#
# Files written (qua CORE-031 templates + Atomic Write Pattern):
#   $SESSION_DIR/phase2-scan/scope-analysis.json  (schema scope-analysis-v2)
#   $SESSION_DIR/phase2-scan/code-inventory.json  (schema code-inventory-v1)
#   $SESSION_DIR/phase2-scan/doc-inventory.json   (schema doc-inventory-v1)
#
# Required env vars (set bởi orchestrator trước khi call):
#   SESSION_DIR, SESSION_ID, SCOPE
#
# Optional env vars:
#   PROFILE                  (default: standard)
#   GITNEXUS_AVAILABLE       (default: false)
#   SERENA_AVAILABLE         (default: false)
#   MOBILE_DEVICE            (default: empty)
#   SOURCE_DIR               (default: src)
#
# Exit codes:
#   0 — All 3 files written + status JSON emitted
#   1 — Required env var missing
#   2 — Template not found (CORE-031 violation)
#   3 — Atomic write fail cho ít nhất 1 file
#
# Output: JSON (stdout) — populated values cho orchestrator eval:
#   {
#     "interface_type": "web|mobile|hybrid|api-only",
#     "mobile_mode": "none|native|cross-platform",
#     "detection_method": "package.json|pubspec.yaml|...",
#     "total_files": <int>,
#     "total_loc": <int>,
#     "req_count": <int>,
#     "feat_count": <int>,
#     "modules_count": <int>,
#     "languages_top": "ts,py,go",
#     "frameworks": "react,...",
#     "dep_level": "low|medium|high",
#     "gitnexus_tasks": "structure,query,...",
#     "serena_tasks": "onboarding,...",
#     "fallback_count": <int>,
#     "status": {
#       "scope_analysis": "ok|fail",
#       "code_inventory": "ok|fail",
#       "doc_inventory":  "ok|fail"
#     }
#   }
#
# Orchestrator usage:
#   PHASE2_DATA=$(bash .claude/scripts/wf-fix-bugs/scan-and-analyze.sh)
#   INTERFACE_TYPE=$(echo "$PHASE2_DATA" | jq -r '.interface_type')
#   TOTAL_FILES=$(echo "$PHASE2_DATA" | jq -r '.total_files')
#
# Compatibility: Git Bash + WSL. Pure bash + jq + find/grep.
# =============================================================================

set -eu

# ── Validate required env vars ───────────────────────────────────────────────
for var in SESSION_DIR SESSION_ID SCOPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

# ── Defaults ─────────────────────────────────────────────────────────────────
PROFILE="${PROFILE:-standard}"
GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"
SOURCE_DIR="${SOURCE_DIR:-src}"

# ── Template paths (CORE-031) ────────────────────────────────────────────────
TPL_DIR=".claude/skills/workflow/wf-fix-bugs/templates/phase2-scan"
TPL_SCOPE="$TPL_DIR/scope-analysis.json"
TPL_CODE="$TPL_DIR/code-inventory.json"
TPL_DOC="$TPL_DIR/doc-inventory.json"

for tpl in "$TPL_SCOPE" "$TPL_CODE" "$TPL_DOC"; do
  [ -f "$tpl" ] || { echo "ERROR: Template missing: $tpl (CORE-031)" >&2; exit 2; }
done

# ── Output dir ───────────────────────────────────────────────────────────────
OUT_DIR="$SESSION_DIR/phase2-scan"
mkdir -p "$OUT_DIR"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCOPE_DIR="${SOURCE_DIR:-.}"
# SCOPE=all/system/module đều scan từ SOURCE_DIR (default "."). SCOPE dùng làm filter key, không map sang path.

# ── Find prune flags (loại trừ noise) ─────────────────────────────────────────
PRUNE='-not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/.mc-data/*" -not -path "*/build/*" -not -path "*/coverage/*"'

# ─────────────────────────────────────────────────────────────────────────────
# 2.3 — INTERFACE TYPE DETECTION
# ─────────────────────────────────────────────────────────────────────────────
WEB_FRAMEWORKS="react|vue|angular|next|nuxt|svelte|remix|astro|solid|gatsby"
WEB_DETECTED=0
MOBILE_DETECTED=0
DETECTION_METHOD=""
FRAMEWORK_LIST=""

# Web detection
if [ -f "package.json" ]; then
  DEPS=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys | join(" ")' package.json 2>/dev/null || echo "")
  if echo "$DEPS" | grep -qiE "$WEB_FRAMEWORKS"; then
    WEB_DETECTED=1
    DETECTION_METHOD="package.json"
    FRAMEWORK_LIST=$(echo "$DEPS" | tr ' ' '\n' | grep -iE "$WEB_FRAMEWORKS" | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')
  fi
fi

# Mobile detection
[ -d "mobile" ] && MOBILE_DETECTED=1 && DETECTION_METHOD="${DETECTION_METHOD:+$DETECTION_METHOD+}mobile/dir"
if [ -f "pubspec.yaml" ] && grep -qi "flutter" pubspec.yaml 2>/dev/null; then
  MOBILE_DETECTED=1
  DETECTION_METHOD="${DETECTION_METHOD:+$DETECTION_METHOD+}pubspec.yaml(flutter)"
  FRAMEWORK_LIST="${FRAMEWORK_LIST:+$FRAMEWORK_LIST,}flutter"
fi
if ls capacitor.config.* 2>/dev/null | head -1 | grep -q .; then
  MOBILE_DETECTED=1
  DETECTION_METHOD="${DETECTION_METHOD:+$DETECTION_METHOD+}capacitor.config"
  FRAMEWORK_LIST="${FRAMEWORK_LIST:+$FRAMEWORK_LIST,}capacitor"
fi
if [ -f "app.json" ] && jq -e '.expo' app.json >/dev/null 2>&1; then
  MOBILE_DETECTED=1
  DETECTION_METHOD="${DETECTION_METHOD:+$DETECTION_METHOD+}app.json(expo)"
  FRAMEWORK_LIST="${FRAMEWORK_LIST:+$FRAMEWORK_LIST,}expo"
fi
NATIVE_COUNT=$(find . -maxdepth 4 \( -name "*.swift" -o -name "*.kt" \) 2>/dev/null | head -5 | wc -l | tr -d ' ')
if [ "$NATIVE_COUNT" -gt 0 ]; then
  MOBILE_DETECTED=1
  DETECTION_METHOD="${DETECTION_METHOD:+$DETECTION_METHOD+}swift|kotlin"
fi

# Determine INTERFACE_TYPE
if [ "$WEB_DETECTED" = "1" ] && [ "$MOBILE_DETECTED" = "1" ]; then
  INTERFACE_TYPE="hybrid"
elif [ "$WEB_DETECTED" = "1" ]; then
  INTERFACE_TYPE="web"
elif [ "$MOBILE_DETECTED" = "1" ]; then
  INTERFACE_TYPE="mobile"
else
  # Edge case: không detect được — check HTML/CSS
  HTML_COUNT=$(find . -maxdepth 3 \( -name "*.html" -o -name "*.css" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -5 | wc -l | tr -d ' ')
  if [ "$HTML_COUNT" -gt 0 ]; then
    INTERFACE_TYPE="web"
    DETECTION_METHOD="html-css-fallback"
  else
    INTERFACE_TYPE="api-only"
    DETECTION_METHOD="api-only-default"
  fi
fi

# Mobile mode
MOBILE_MODE="none"
if [ "$MOBILE_DETECTED" = "1" ]; then
  if [ "$NATIVE_COUNT" -gt 0 ]; then
    MOBILE_MODE="native"
  else
    MOBILE_MODE="cross-platform"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2.4 — CODE INVENTORY (CI-ROUTE)
# ─────────────────────────────────────────────────────────────────────────────
CI_STRUCTURE_SOURCE="glob"
[ "$GITNEXUS_AVAILABLE" = "true" ] && CI_STRUCTURE_SOURCE="gitnexus"
[ "$SERENA_AVAILABLE" = "true" ] && CI_STRUCTURE_SOURCE="serena"

GITNEXUS_TASKS=""
SERENA_TASKS=""
FALLBACK_COUNT=0

if [ "$SERENA_AVAILABLE" = "true" ]; then
  SERENA_TASKS="onboarding,symbol_overview"
elif [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  GITNEXUS_TASKS="clusters,query"
else
  FALLBACK_COUNT=$((FALLBACK_COUNT + 1))
fi

# Source file enumeration
# shellcheck disable=SC2086
TOTAL_FILES=$(eval find "$SCOPE_DIR" -type f \
  \\\( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rs" \
  -o -name "*.sql" -o -name "*.css" -o -name "*.scss" -o -name "*.html" \
  -o -name "*.vue" -o -name "*.svelte" -o -name "*.swift" -o -name "*.kt" \
  -o -name "*.rb" -o -name "*.php" -o -name "*.cs" \
  \\\) $PRUNE 2>/dev/null | wc -l | tr -d ' ')

# Language breakdown (top 5)
# shellcheck disable=SC2086
LANG_BREAKDOWN=$(eval find "$SCOPE_DIR" -type f $PRUNE 2>/dev/null \
  | sed 's/.*\.//' \
  | grep -iE '^(ts|tsx|js|jsx|py|java|go|rs|sql|css|scss|html|vue|svelte|swift|kt|rb|php|cs)$' \
  | sort | uniq -c | sort -rn | head -5 \
  | awk '{print $2":"$1}' | tr '\n' ',' | sed 's/,$//')
LANGUAGES_TOP=$(echo "$LANG_BREAKDOWN" | tr ',' '\n' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')

# Build languages JSON array — schema scope-analysis-v2 yêu cầu "languages": []
LANG_JSON="[]"
if [ -n "$LANG_BREAKDOWN" ]; then
  LANG_JSON=$(echo "$LANG_BREAKDOWN" | tr ',' '\n' | jq -R -s '
    split("\n") | map(select(length > 0) | split(":") | {language: .[0], files: (.[1] | tonumber)})')
fi

# Build by_language map cho code-inventory.json
BY_LANGUAGE_JSON="{}"
if [ -n "$LANG_BREAKDOWN" ]; then
  BY_LANGUAGE_JSON=$(echo "$LANG_BREAKDOWN" | tr ',' '\n' | jq -R -s '
    split("\n") | map(select(length > 0) | split(":") | {(.[0]): (.[1] | tonumber)}) | add // {}')
fi

# LOC estimate (chỉ source langs, skip CSS/HTML để giảm thời gian)
# shellcheck disable=SC2086
TOTAL_LOC=$(eval find "$SCOPE_DIR" -type f \
  \\\( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rs" \
  -o -name "*.swift" -o -name "*.kt" \\\) $PRUNE 2>/dev/null \
  | head -5000 | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
TOTAL_LOC=${TOTAL_LOC:-0}

# Modules detection
MODULES_COUNT=0
BY_MODULE_JSON="{}"
if [ -d "apps" ]; then
  MODULES_LIST=$(find apps -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null \
    | awk -F/ '{print $2}' | sort -u)
  MODULES_COUNT=$(echo "$MODULES_LIST" | grep -c . 2>/dev/null || echo 0)
  if [ "$MODULES_COUNT" -gt 0 ]; then
    BY_MODULE_JSON=$(echo "$MODULES_LIST" | jq -R -s '
      split("\n") | map(select(length > 0)) | map({(.): 0}) | add // {}')
  fi
elif [ -d "$SOURCE_DIR" ]; then
  MODULES_COUNT=1
  BY_MODULE_JSON=$(jq -n --arg sd "$SOURCE_DIR" '{($sd): 0}')
fi

# API routes count (CI-ROUTE)
API_ROUTES_COUNT=0
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  GITNEXUS_TASKS="${GITNEXUS_TASKS:+$GITNEXUS_TASKS,}route_map"
else
  # Fallback: grep common API patterns
  API_ROUTES_COUNT=$(grep -rE "(app\.(get|post|put|delete|patch)|@(Get|Post|Put|Delete|Patch)Mapping|@app\.route)" \
    --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.java" \
    "$SCOPE_DIR" 2>/dev/null | wc -l | tr -d ' ')
  [ "$API_ROUTES_COUNT" -gt 0 ] && FALLBACK_COUNT=$((FALLBACK_COUNT + 1))
fi

# Dependency level
DEP_COUNT=$(find "$SCOPE_DIR" -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
[ "$DEP_COUNT" -gt 5 ] && DEP_LEVEL="high" || { [ "$DEP_COUNT" -gt 2 ] && DEP_LEVEL="medium" || DEP_LEVEL="low"; }

# ─────────────────────────────────────────────────────────────────────────────
# 2.5 — DOC INVENTORY
# ─────────────────────────────────────────────────────────────────────────────
REQ_COUNT=0
FEAT_COUNT=0
REGISTRY_EXISTS=false

if [ -f ".mc-data/docs/_meta/req-registry.json" ]; then
  REGISTRY_EXISTS=true
  REQ_COUNT=$(jq '.requirements | length' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo 0)
  FEAT_COUNT=$(jq '[.requirements[]? .features // []] | flatten | length' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo 0)
fi

# Docs phases inventory
PHASES_JSON="[]"
TOTAL_DOCS=0
if [ -d ".mc-data/docs" ]; then
  PHASES_LIST=""
  for phase_dir in .mc-data/docs/phase*/; do
    [ -d "$phase_dir" ] || continue
    phase_name=$(basename "$phase_dir")
    file_count=$(find "$phase_dir" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    PHASES_LIST="${PHASES_LIST}${phase_name}:${file_count}\n"
    TOTAL_DOCS=$((TOTAL_DOCS + file_count))
  done
  if [ -n "$PHASES_LIST" ]; then
    PHASES_JSON=$(printf "%b" "$PHASES_LIST" | jq -R -s '
      split("\n") | map(select(length > 0) | split(":") | {phase: .[0], doc_count: (.[1] | tonumber)})')
  fi
fi

# REQ-ID annotation tracking
REQ_ID_FILES=0
if [ "$GITNEXUS_AVAILABLE" = "true" ] || [ "$SERENA_AVAILABLE" = "true" ]; then
  [ "$GITNEXUS_AVAILABLE" = "true" ] && GITNEXUS_TASKS="${GITNEXUS_TASKS:+$GITNEXUS_TASKS,}cypher_req_id"
  [ "$SERENA_AVAILABLE" = "true" ] && SERENA_TASKS="${SERENA_TASKS:+$SERENA_TASKS,}find_refs_req_id"
else
  REQ_ID_FILES=$(grep -rl "REQ-ID:" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.java" --include="*.md" \
    "$SCOPE_DIR" 2>/dev/null | wc -l | tr -d ' ')
  [ "$REQ_ID_FILES" -gt 0 ] && FALLBACK_COUNT=$((FALLBACK_COUNT + 1))
fi

# Supplementary docs
README_COUNT=$(find . -maxdepth 2 -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
DOCS_DIR_COUNT=$(find docs/ -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_DOCS=$((TOTAL_DOCS + README_COUNT + DOCS_DIR_COUNT))

# ─────────────────────────────────────────────────────────────────────────────
# 2.6 — SCOPE ANALYSIS (aggregate)
# ─────────────────────────────────────────────────────────────────────────────
CI_FLOWS=0
[ "$GITNEXUS_AVAILABLE" = "true" ] || [ "$SERENA_AVAILABLE" = "true" ] && CI_FLOWS=1

GITNEXUS_TASKS_JSON=$(echo "${GITNEXUS_TASKS:-}" | jq -R 'split(",") | map(select(length > 0))')
SERENA_TASKS_JSON=$(echo "${SERENA_TASKS:-}" | jq -R 'split(",") | map(select(length > 0))')

# ─────────────────────────────────────────────────────────────────────────────
# 2.7 — WRITE 3 JSON OUTPUTS (CORE-031 + Atomic Write)
# ─────────────────────────────────────────────────────────────────────────────
STATUS_SCOPE="fail"
STATUS_CODE="fail"
STATUS_DOC="fail"
OVERALL_EXIT=0

# ── scope-analysis.json ──────────────────────────────────────────────────────
TARGET="$OUT_DIR/scope-analysis.json"
TMP="$TARGET.tmp.$$"
if jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --arg iface "$INTERFACE_TYPE" \
  --arg mobile "$MOBILE_MODE" \
  --arg sdir "$SOURCE_DIR" \
  --arg scope "$SCOPE" \
  --argjson tf "$TOTAL_FILES" \
  --argjson tloc "${TOTAL_LOC:-0}" \
  --argjson langs "$LANG_JSON" \
  --arg dep "$DEP_LEVEL" \
  --argjson reqs "$REQ_COUNT" \
  --argjson feats "$FEAT_COUNT" \
  --argjson flows "$CI_FLOWS" \
  --argjson gnt "$GITNEXUS_TASKS_JSON" \
  --argjson srt "$SERENA_TASKS_JSON" \
  --argjson fbc "$FALLBACK_COUNT" \
  '.session_id = $sid |
   .generated_at = $ts |
   .interface_type = $iface |
   .mobile_mode = $mobile |
   .source_dir = $sdir |
   .scope = $scope |
   .code = {total_files: $tf, total_loc: $tloc, languages: $langs, dependency_level: $dep} |
   .docs = {requirements: $reqs, features: $feats} |
   .ci_coverage = {execution_flows_available: $flows, gitnexus_tasks: $gnt, serena_tasks: $srt, fallback_count: $fbc} |
   del(._template_notes, ._schema_notes)' \
  "$TPL_SCOPE" > "$TMP" 2>/dev/null \
  && jq '.' "$TMP" >/dev/null 2>&1 \
  && mv "$TMP" "$TARGET"; then
  STATUS_SCOPE="ok"
else
  rm -f "$TMP"
  OVERALL_EXIT=3
fi

# ── code-inventory.json ──────────────────────────────────────────────────────
TARGET="$OUT_DIR/code-inventory.json"
TMP="$TARGET.tmp.$$"
if jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --argjson tf "$TOTAL_FILES" \
  --argjson by_lang "$BY_LANGUAGE_JSON" \
  --argjson by_mod "$BY_MODULE_JSON" \
  '.session_id = $sid |
   .generated_at = $ts |
   .total_files = $tf |
   .by_language = $by_lang |
   .by_module = $by_mod |
   del(._template_notes, ._schema_notes)' \
  "$TPL_CODE" > "$TMP" 2>/dev/null \
  && jq '.' "$TMP" >/dev/null 2>&1 \
  && mv "$TMP" "$TARGET"; then
  STATUS_CODE="ok"
else
  rm -f "$TMP"
  OVERALL_EXIT=3
fi

# ── doc-inventory.json ───────────────────────────────────────────────────────
TARGET="$OUT_DIR/doc-inventory.json"
TMP="$TARGET.tmp.$$"
if jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --argjson td "$TOTAL_DOCS" \
  --argjson phases "$PHASES_JSON" \
  --argjson re "$([ "$REGISTRY_EXISTS" = "true" ] && echo true || echo false)" \
  --argjson reqs "$REQ_COUNT" \
  --argjson feats "$FEAT_COUNT" \
  '.session_id = $sid |
   .generated_at = $ts |
   .total_docs = $td |
   .phases_present = $phases |
   .req_registry_exists = $re |
   .req_count = $reqs |
   .feature_count = $feats |
   del(._template_notes, ._schema_notes)' \
  "$TPL_DOC" > "$TMP" 2>/dev/null \
  && jq '.' "$TMP" >/dev/null 2>&1 \
  && mv "$TMP" "$TARGET"; then
  STATUS_DOC="ok"
else
  rm -f "$TMP"
  OVERALL_EXIT=3
fi

# ── Emit aggregated data JSON to stdout ──────────────────────────────────────
jq -n \
  --arg it "$INTERFACE_TYPE" \
  --arg mm "$MOBILE_MODE" \
  --arg dm "${DETECTION_METHOD:-unknown}" \
  --argjson tf "$TOTAL_FILES" \
  --argjson tl "${TOTAL_LOC:-0}" \
  --argjson rc "$REQ_COUNT" \
  --argjson fc "$FEAT_COUNT" \
  --argjson mc "$MODULES_COUNT" \
  --arg lt "${LANGUAGES_TOP:-unknown}" \
  --arg fw "${FRAMEWORK_LIST:-}" \
  --arg dl "$DEP_LEVEL" \
  --arg gnt "${GITNEXUS_TASKS:-}" \
  --arg srt "${SERENA_TASKS:-}" \
  --argjson fbc "$FALLBACK_COUNT" \
  --arg sc "$STATUS_SCOPE" \
  --arg cc "$STATUS_CODE" \
  --arg dc "$STATUS_DOC" \
  '{
    interface_type: $it,
    mobile_mode: $mm,
    detection_method: $dm,
    total_files: $tf,
    total_loc: $tl,
    req_count: $rc,
    feat_count: $fc,
    modules_count: $mc,
    languages_top: $lt,
    frameworks: $fw,
    dep_level: $dl,
    gitnexus_tasks: $gnt,
    serena_tasks: $srt,
    fallback_count: $fbc,
    status: {scope_analysis: $sc, code_inventory: $cc, doc_inventory: $dc}
  }'

exit "$OVERALL_EXIT"
