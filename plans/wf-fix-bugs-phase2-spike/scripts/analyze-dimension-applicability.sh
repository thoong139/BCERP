#!/usr/bin/env bash
# analyze-dimension-applicability.sh — Phase 2 Spike #2B
# Output: dimension-applicability.json (schema dimension-applicability-v1)
#
# Discover modules → scan content signals → map signals → applicable_dims (QD1-QD11)
#
# Signals (content-based, regex grep):
#   has_money, has_auth, has_db, has_api, has_ui, has_i18n,
#   has_form, has_responsive, has_state_machine, has_browser_test
#
# Mapping (signal → dim):
#   QD1 functional       — always applicable
#   QD2 business         — has_money OR has_state_machine
#   QD3 security         — has_auth OR has_api
#   QD4 performance      — has_db OR has_ui
#   QD5 ux-a11y          — has_ui
#   QD6 data integrity   — has_db
#   QD7 compatibility    — has_ui (i18n/responsive deepen)
#   QD8 observability    — has_api OR has_db
#   QD9 runtime health   — has_ui AND has_browser_test
#   QD10 integration     — imports_from_other_modules > 0
#   QD11 business comp.  — is_multi_app (global)

set -uo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
ROOT="${ROOT:-.}"
OUTPUT="${OUTPUT:-./dimension-applicability.json}"
SESSION_ID="${SESSION_ID:-spike-$(date +%Y%m%d-%H%M%S)}"
MAX_FILES_PER_MODULE="${MAX_FILES_PER_MODULE:-5000}"  # cap grep input
START_TS=$(date +%s)

ROOT=$(cd "$ROOT" && pwd)
cd "$ROOT" || { echo "ROOT not accessible: $ROOT" >&2; exit 2; }

# ─── Module discovery ─────────────────────────────────────────────────────────
# Strategy: top-level dirs under apps/, src/, packages/, or known patterns
MODULES=()

# apps/* (most common — monorepo)
if [ -d apps ]; then
  while IFS= read -r m; do
    [ -d "$m" ] && MODULES+=("$m")
  done < <(find apps -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
fi

# src/* (single app)
if [ -d src ]; then
  while IFS= read -r m; do
    [ -d "$m" ] && MODULES+=("$m")
  done < <(find src -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
fi

# packages/* (monorepo shared)
if [ -d packages ]; then
  while IFS= read -r m; do
    [ -d "$m" ] && MODULES+=("$m")
  done < <(find packages -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
fi

# Root-level app dirs (DEVKIT-style: .claude/skills/* etc.)
if [ "${#MODULES[@]}" -eq 0 ]; then
  while IFS= read -r m; do
    [ -d "$m" ] && MODULES+=("$m")
  done < <(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' ! -name 'node_modules' 2>/dev/null)
fi

IS_MULTI_APP="false"
[ "${#MODULES[@]}" -ge 2 ] && IS_MULTI_APP="true"

echo "Discovered ${#MODULES[@]} modules" >&2

# ─── Per-module signal scanning ───────────────────────────────────────────────
EXCLUDE_REGEX="node_modules|\\.git|dist|build|\\.next|out|coverage|__pycache__|bin|obj|target|vendor|\\.venv"
EXTS="ts|tsx|js|jsx|py|cs|java|go|rs|php|rb|vue|svelte|dart|kt|swift|cshtml|razor"

# Helper: detect signal in module via grep -l on N file sample
has_signal() {
  local module="$1"
  local pattern="$2"
  local filelist="$3"
  if [ -z "$filelist" ]; then echo "false"; return; fi
  # Disable pipefail to avoid SIGPIPE failure when head -n 1 short-circuits xargs|grep
  local result
  result=$(set +o pipefail; echo "$filelist" | head -n "$MAX_FILES_PER_MODULE" | xargs -I {} grep -lE "$pattern" "{}" 2>/dev/null | head -n 1)
  if [ -n "$result" ]; then echo "true"; else echo "false"; fi
}

# Aggregate global signals
GLOBAL_MONEY="false"; GLOBAL_AUTH="false"; GLOBAL_DB="false"; GLOBAL_API="false"
GLOBAL_UI="false"; GLOBAL_I18N="false"; GLOBAL_RESP="false"; GLOBAL_BROWSER="false"
GLOBAL_CROSS="false"

# Per-module JSON accumulator
MODULES_JSON_TMP=$(mktemp)
trap 'rm -f "$MODULES_JSON_TMP"' EXIT
echo "[" > "$MODULES_JSON_TMP"
FIRST=1

for mod in "${MODULES[@]}"; do
  # List source files in module
  FILELIST=$(find "$mod" -type f 2>/dev/null \
    | grep -Ev "($EXCLUDE_REGEX)/" \
    | grep -E "\.($EXTS)$")
  FILECOUNT=$(echo -n "$FILELIST" | grep -c '.' 2>/dev/null | tr -d ' \n')
  FILECOUNT=${FILECOUNT:-0}

  if [ "$FILECOUNT" -eq 0 ] 2>/dev/null; then continue; fi

  # Signal detection
  HAS_MONEY=$(has_signal "$mod" "amount|[Pp]rice|[Tt]otal|currency|invoice|payment|commission|[Tt]ax|refund|charge|[Ff]ee|Money|Decimal" "$FILELIST")
  HAS_AUTH=$(has_signal "$mod" "[Ll]ogin|[Ll]ogout|password|[Jj]wt|[Ss]ession|oauth|bearer|[Aa]uthorize|Authorization|hashPassword|signIn|\\[Authorize|Identity\\.|JwtBearer" "$FILELIST")
  HAS_DB=$(has_signal "$mod" "knex|prisma|typeorm|sequelize|mongoose|DbContext|Repository|IRepository|EntityFramework|EF\\.|SELECT |INSERT |UPDATE |DELETE FROM|MigrationBuilder" "$FILELIST")
  HAS_API=$(has_signal "$mod" "express|fastify|@nestjs|FastAPI|gin\\.Engine|@Controller|@RestController|\\[ApiController\\]|\\[Route\\(|\\[HttpGet|\\[HttpPost|IActionResult|ControllerBase|app\\.(get|post|put|delete)|router\\.(get|post|put|delete)" "$FILELIST")
  HAS_FORM=$(has_signal "$mod" "useForm|react-hook-form|formik|<form|FormGroup|FormControl|v-model" "$FILELIST")
  HAS_I18N=$(has_signal "$mod" "i18n|useTranslation|t\\(|translate\\(|locale|i18next|FormattedMessage" "$FILELIST")
  HAS_RESP=$(has_signal "$mod" "@media|breakpoint|sm:|md:|lg:|xl:|responsive|Mobile|isMobile" "$FILELIST")
  HAS_STATE=$(has_signal "$mod" "status|state|transition|workflow|approve|pending|complete|cancel|reject" "$FILELIST")

  # UI presence: check extensions
  if echo "$FILELIST" | grep -qE "\.(jsx|tsx|vue|svelte|cshtml|razor)$"; then
    HAS_UI="true"
  else
    HAS_UI="false"
  fi

  # Browser test infra: check root for playwright/cypress config
  if [ -f "$mod/playwright.config.ts" ] || [ -f "$mod/playwright.config.js" ] || [ -f "$mod/cypress.config.ts" ] || [ -f "$mod/cypress.config.js" ] || [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
    HAS_BROWSER="true"
  else
    HAS_BROWSER="false"
  fi

  # Imports from other modules (cross-module)
  CROSS_IMPORTS=$(echo "$FILELIST" | head -n "$MAX_FILES_PER_MODULE" | xargs -I {} grep -E "from ['\"]\\.\\.|require\\(['\"]\\.\\." "{}" 2>/dev/null | grep -c '.' 2>/dev/null | tr -d ' \n')
  CROSS_IMPORTS=${CROSS_IMPORTS:-0}
  [ -z "$CROSS_IMPORTS" ] && CROSS_IMPORTS=0

  # Module type
  MODTYPE="unknown"
  mod_lower="${mod,,}"
  case "$mod_lower" in
    *mobile*) MODTYPE="mobile" ;;
    *backend*|*api*|*server*) MODTYPE="backend" ;;
    *web*|*frontend*|*-ui*|*client*) MODTYPE="frontend" ;;
    *shared*|*common*|*packages*) MODTYPE="shared" ;;
    *infra*|*config*) MODTYPE="infrastructure" ;;
  esac
  # Refine by signals
  if [ "$MODTYPE" = "unknown" ]; then
    if [ "$HAS_UI" = "true" ]; then MODTYPE="frontend"
    elif [ "$HAS_API" = "true" ]; then MODTYPE="backend"
    elif [ "$HAS_DB" = "true" ]; then MODTYPE="backend"
    fi
  fi

  # Build applicable_dims + skip_dims
  APPLICABLE=("QD1")  # always
  SKIP=()
  declare -A SKIP_REASONS=()

  # QD2 business
  if [ "$HAS_MONEY" = "true" ] || [ "$HAS_STATE" = "true" ]; then APPLICABLE+=("QD2"); else SKIP+=("QD2"); SKIP_REASONS[QD2]="no money/state-machine signals"; fi
  # QD3 security
  if [ "$HAS_AUTH" = "true" ] || [ "$HAS_API" = "true" ]; then APPLICABLE+=("QD3"); else SKIP+=("QD3"); SKIP_REASONS[QD3]="no auth/api signals"; fi
  # QD4 performance
  if [ "$HAS_DB" = "true" ] || [ "$HAS_UI" = "true" ]; then APPLICABLE+=("QD4"); else SKIP+=("QD4"); SKIP_REASONS[QD4]="no db/ui signals"; fi
  # QD5 UX/A11y
  if [ "$HAS_UI" = "true" ]; then APPLICABLE+=("QD5"); else SKIP+=("QD5"); SKIP_REASONS[QD5]="no UI files"; fi
  # QD6 data integrity
  if [ "$HAS_DB" = "true" ]; then APPLICABLE+=("QD6"); else SKIP+=("QD6"); SKIP_REASONS[QD6]="no db signals"; fi
  # QD7 compatibility
  if [ "$HAS_UI" = "true" ]; then APPLICABLE+=("QD7"); else SKIP+=("QD7"); SKIP_REASONS[QD7]="no UI files"; fi
  # QD8 observability
  if [ "$HAS_API" = "true" ] || [ "$HAS_DB" = "true" ]; then APPLICABLE+=("QD8"); else SKIP+=("QD8"); SKIP_REASONS[QD8]="no server-side signals"; fi
  # QD9 runtime health
  if [ "$HAS_UI" = "true" ] && [ "$HAS_BROWSER" = "true" ]; then APPLICABLE+=("QD9"); else SKIP+=("QD9"); SKIP_REASONS[QD9]="no UI or no browser test infra"; fi
  # QD10 integration
  if [ "$CROSS_IMPORTS" -gt 0 ]; then APPLICABLE+=("QD10"); else SKIP+=("QD10"); SKIP_REASONS[QD10]="no cross-module imports"; fi
  # QD11 business completeness — only at multi-app level (defer to global)
  SKIP+=("QD11"); SKIP_REASONS[QD11]="evaluated at global level only"

  # Update globals
  [ "$HAS_MONEY" = "true" ] && GLOBAL_MONEY="true"
  [ "$HAS_AUTH" = "true" ] && GLOBAL_AUTH="true"
  [ "$HAS_DB" = "true" ] && GLOBAL_DB="true"
  [ "$HAS_API" = "true" ] && GLOBAL_API="true"
  [ "$HAS_UI" = "true" ] && GLOBAL_UI="true"
  [ "$HAS_I18N" = "true" ] && GLOBAL_I18N="true"
  [ "$HAS_RESP" = "true" ] && GLOBAL_RESP="true"
  [ "$HAS_BROWSER" = "true" ] && GLOBAL_BROWSER="true"
  [ "$CROSS_IMPORTS" -gt 0 ] && GLOBAL_CROSS="true"

  # JSON entry
  APP_JSON=$(printf '%s\n' "${APPLICABLE[@]}" | jq -R . | jq -s .)
  SKIP_JSON=$(printf '%s\n' "${SKIP[@]}" | jq -R . | jq -s .)
  SKIP_REASONS_JSON='{}'
  for k in "${!SKIP_REASONS[@]}"; do
    SKIP_REASONS_JSON=$(echo "$SKIP_REASONS_JSON" | jq --arg k "$k" --arg v "${SKIP_REASONS[$k]}" '. + {($k): $v}')
  done

  if [ "$FIRST" -eq 0 ]; then echo "," >> "$MODULES_JSON_TMP"; fi
  FIRST=0

  jq -n \
    --arg mod "$mod" \
    --arg mtype "$MODTYPE" \
    --argjson app "$APP_JSON" \
    --argjson skip "$SKIP_JSON" \
    --argjson skip_reasons "$SKIP_REASONS_JSON" \
    --argjson money "$([ "$HAS_MONEY" = "true" ] && echo true || echo false)" \
    --argjson auth "$([ "$HAS_AUTH" = "true" ] && echo true || echo false)" \
    --argjson db "$([ "$HAS_DB" = "true" ] && echo true || echo false)" \
    --argjson api "$([ "$HAS_API" = "true" ] && echo true || echo false)" \
    --argjson ui "$([ "$HAS_UI" = "true" ] && echo true || echo false)" \
    --argjson i18n "$([ "$HAS_I18N" = "true" ] && echo true || echo false)" \
    --argjson form "$([ "$HAS_FORM" = "true" ] && echo true || echo false)" \
    --argjson resp "$([ "$HAS_RESP" = "true" ] && echo true || echo false)" \
    --argjson state "$([ "$HAS_STATE" = "true" ] && echo true || echo false)" \
    --argjson cross "$CROSS_IMPORTS" \
    --argjson fc "$FILECOUNT" \
    '{
      module: $mod,
      module_type: $mtype,
      applicable_dims: $app,
      skip_dims: $skip,
      skip_reasons: $skip_reasons,
      signals: {
        has_money: $money,
        has_auth: $auth,
        has_db: $db,
        has_api: $api,
        has_ui: $ui,
        has_i18n: $i18n,
        has_form: $form,
        has_responsive: $resp,
        has_state_machine: $state,
        imports_from_other_modules: $cross,
        file_count: $fc,
        framework_hints: []
      }
    }' >> "$MODULES_JSON_TMP"

  echo "  $mod ($MODTYPE, $FILECOUNT files): ${#APPLICABLE[@]} applicable, ${#SKIP[@]} skip" >&2
done

echo "]" >> "$MODULES_JSON_TMP"

# Global applicability
GLOBAL_APP=("QD1" "QD8")
GLOBAL_SKIP=()
[ "$GLOBAL_MONEY" = "true" ] && GLOBAL_APP+=("QD2") || GLOBAL_SKIP+=("QD2")
[ "$GLOBAL_AUTH" = "true" ] || [ "$GLOBAL_API" = "true" ] && GLOBAL_APP+=("QD3") || GLOBAL_SKIP+=("QD3")
[ "$GLOBAL_DB" = "true" ] || [ "$GLOBAL_UI" = "true" ] && GLOBAL_APP+=("QD4") || GLOBAL_SKIP+=("QD4")
[ "$GLOBAL_UI" = "true" ] && GLOBAL_APP+=("QD5" "QD7") || GLOBAL_SKIP+=("QD5" "QD7")
[ "$GLOBAL_DB" = "true" ] && GLOBAL_APP+=("QD6") || GLOBAL_SKIP+=("QD6")
[ "$GLOBAL_UI" = "true" ] && [ "$GLOBAL_BROWSER" = "true" ] && GLOBAL_APP+=("QD9") || GLOBAL_SKIP+=("QD9")
[ "$GLOBAL_CROSS" = "true" ] && GLOBAL_APP+=("QD10") || GLOBAL_SKIP+=("QD10")
[ "$IS_MULTI_APP" = "true" ] && GLOBAL_APP+=("QD11") || GLOBAL_SKIP+=("QD11")

# Dedup
GLOBAL_APP=($(printf '%s\n' "${GLOBAL_APP[@]}" | awk '!seen[$0]++'))
GLOBAL_SKIP=($(printf '%s\n' "${GLOBAL_SKIP[@]}" | awk '!seen[$0]++'))

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

# Summary metrics
MODULES_OUTPUT=$(cat "$MODULES_JSON_TMP")
TOTAL_MODS=$(echo "$MODULES_OUTPUT" | jq 'length')
AVG_APP=$(echo "$MODULES_OUTPUT" | jq '[.[].applicable_dims | length] | add / length')
AVG_SKIP=$(echo "$MODULES_OUTPUT" | jq '[.[].skip_dims | length] | add / length')
# Estimate: assume ~5 probes per dim, total probes baseline = 11 * 5 = 55 per module
# Skippable = sum(skip_dims) * 5
SKIPPABLE=$(echo "$MODULES_OUTPUT" | jq '[.[].skip_dims | length] | add * 5')

# Final
mkdir -p "$(dirname "$OUTPUT")"
jq -n \
  --arg sid "$SESSION_ID" \
  --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson modules "$MODULES_OUTPUT" \
  --argjson global_app "$(printf '%s\n' "${GLOBAL_APP[@]}" | jq -R . | jq -s .)" \
  --argjson global_skip "$(printf '%s\n' "${GLOBAL_SKIP[@]}" | jq -R . | jq -s .)" \
  --argjson money "$([ "$GLOBAL_MONEY" = "true" ] && echo true || echo false)" \
  --argjson auth "$([ "$GLOBAL_AUTH" = "true" ] && echo true || echo false)" \
  --argjson db "$([ "$GLOBAL_DB" = "true" ] && echo true || echo false)" \
  --argjson api "$([ "$GLOBAL_API" = "true" ] && echo true || echo false)" \
  --argjson ui "$([ "$GLOBAL_UI" = "true" ] && echo true || echo false)" \
  --argjson i18n "$([ "$GLOBAL_I18N" = "true" ] && echo true || echo false)" \
  --argjson resp "$([ "$GLOBAL_RESP" = "true" ] && echo true || echo false)" \
  --argjson browser "$([ "$GLOBAL_BROWSER" = "true" ] && echo true || echo false)" \
  --argjson cross "$([ "$GLOBAL_CROSS" = "true" ] && echo true || echo false)" \
  --argjson multi "$([ "$IS_MULTI_APP" = "true" ] && echo true || echo false)" \
  --argjson tm "$TOTAL_MODS" \
  --argjson aa "$AVG_APP" \
  --argjson as "$AVG_SKIP" \
  --argjson sk "$SKIPPABLE" \
  --argjson dur "$DURATION" \
  '{
    "$schema": "dimension-applicability-v1",
    session_id: $sid,
    generated_at: $gen,
    global: {
      signals: {
        has_money: $money, has_auth: $auth, has_db: $db, has_api: $api,
        has_ui: $ui, has_i18n: $i18n, has_responsive: $resp,
        has_browser_test: $browser, has_cross_module: $cross, is_multi_app: $multi
      },
      applicable_dims: $global_app,
      skip_dims: $global_skip
    },
    modules: $modules,
    summary: {
      total_modules: $tm,
      avg_applicable_dims: $aa,
      avg_skip_dims: $as,
      total_skippable_probes_estimate: $sk,
      duration_seconds: $dur
    }
  }' > "$OUTPUT"

echo "✓ Written: $OUTPUT" >&2
echo "  Modules: $TOTAL_MODS | Avg applicable: $AVG_APP | Avg skip: $AVG_SKIP | Est. skippable probes: $SKIPPABLE | Duration: ${DURATION}s" >&2
