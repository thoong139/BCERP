#!/usr/bin/env bash
# wf-detect-cross-module-deps.sh — Heuristic detection cross_module_dependencies[]
#
# Quet source code de phat hien cross-module references (KHONG ghi registry truc tiep).
# Output JSON suggestions cho user review → manually populate cross_module_dependencies[]
# trong req-registry.json.
#
# Reuses from:
#   - wf-fix-detect-base-url.sh (W1.2): arg parsing pattern, json_str(), output builder
#   - wf-fix-probe-static-deprecated.sh:147-217 (QD7): combined grep single scan approach
#   - wf-fix-probe-cross-module-ref.sh:81-82 (W2.2): module slug derivation pattern
#
# USAGE:
#   bash wf-detect-cross-module-deps.sh \
#     --project-root=<path> \
#     [--registry=<path-to-req-registry.json>] \
#     [--source-dir=<path>] \
#     [--min-confidence=0.3] \
#     [--output=<path.json>] \
#     [--dry-run]
#
# OUTPUT JSON schema: cross-module-dep-suggestions-v1
#   {
#     "$schema": "cross-module-dep-suggestions-v1",
#     "suggestions": [{
#       "consumer_module": "MOD-QUOTATION",
#       "provider_module": "MOD-CRM",
#       "entity": "Crm",
#       "confidence": 0.85,
#       "binding_type_guess": "api|event|foreign_key|denormalized_copy",
#       "import_count": 5,
#       "api_call_count": 1,
#       "type_ref_count": 2,
#       "evidence": [{"file":"...","line":12,"type":"import","snippet":"..."}]
#     }]
#   }
#
# EXIT CODES: 0 success, 1 error
# NOTE: KHONG ghi registry truc tiep — user review + manually populate
#
# MCV3 wf-fix-bugs v9 — Wave 2 W2.6 (Cross-Module Static)

set -euo pipefail

# ─── Argument parsing (REUSE: wf-fix-detect-base-url.sh:40-56 arg loop pattern) ─
PROJECT_ROOT=""
REGISTRY_FILE=""
SOURCE_DIR=""
MIN_CONFIDENCE="0.3"
OUTPUT_FILE=""
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --project-root=*)   PROJECT_ROOT="${arg#*=}" ;;
    --registry=*)       REGISTRY_FILE="${arg#*=}" ;;
    --source-dir=*)     SOURCE_DIR="${arg#*=}" ;;
    --min-confidence=*) MIN_CONFIDENCE="${arg#*=}" ;;
    --output=*)         OUTPUT_FILE="${arg#*=}" ;;
    --dry-run)          DRY_RUN=true ;;
    --help|-h)
      grep '^#' "$0" | head -40 | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      echo "       Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# Default project root to cwd
[[ -z "$PROJECT_ROOT" ]] && PROJECT_ROOT="$(pwd)"
PROJECT_ROOT="${PROJECT_ROOT%/}"

# ─── Helpers ──────────────────────────────────────────────────────────────────

# JSON string escape (REUSE: wf-fix-detect-base-url.sh:69-73)
json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# ISO 8601 timestamp
iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ"
}

# Confidence scoring using awk (float arithmetic, no python3 dependency)
# Formula: import_score * 0.75 + api_score * 0.15 + type_score * 0.10
# Normalization: saturates at 5 imports, 3 api calls, 3 type refs
# Designed so that: >=5 imports -> confidence >= 0.75 (> 0.7 acceptance threshold)
# With 2 imports: 0.30 (above min 0.3 default threshold -- detectable)
score_confidence() {
  local imports=$1 apis=$2 types=$3
  awk "BEGIN {
    si = ($imports > 5 ? 1.0 : $imports / 5.0) * 0.75;
    sa = ($apis > 3 ? 1.0 : $apis / 3.0) * 0.15;
    st = ($types > 3 ? 1.0 : $types / 3.0) * 0.10;
    printf \"%.2f\", si + sa + st
  }"
}

# Is confidence >= min_confidence? (float compare via awk)
conf_meets_threshold() {
  local conf=$1
  awk "BEGIN { exit($conf >= $MIN_CONFIDENCE ? 0 : 1) }"
}

# Module ID → slug (REUSE: wf-fix-probe-cross-module-ref.sh:81-82)
# MOD-CRM → crm, MOD-QUOTATION → quotation, MOD-MC-ORDERS → mc-orders
module_id_to_slug() {
  echo "$1" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# Slug first-word → PascalCase entity name
# crm → Crm, quotation → Quotation, mc-orders → Mc
slug_to_entity() {
  local first="${1%%-*}"
  echo "$first" | awk '{ print toupper(substr($0,1,1)) tolower(substr($0,2)) }'
}

# ─── Registry discovery ────────────────────────────────────────────────────────

if [[ -z "$REGISTRY_FILE" ]]; then
  for candidate in \
    "$PROJECT_ROOT/.mc-data/docs/_meta/req-registry.json" \
    "$PROJECT_ROOT/.mc-data/req-registry.json" \
    "$PROJECT_ROOT/req-registry.json"; do
    if [[ -f "$candidate" ]]; then
      REGISTRY_FILE="$candidate"
      break
    fi
  done
fi

if [[ -n "$REGISTRY_FILE" && ! -f "$REGISTRY_FILE" ]]; then
  echo "ERROR: registry file not found: $REGISTRY_FILE" >&2
  exit 1
fi

[[ -n "$REGISTRY_FILE" ]] && echo "[wf-detect-cross-module-deps] Registry: $REGISTRY_FILE" >&2 \
                           || echo "[wf-detect-cross-module-deps] WARN: No registry found. Will use dir scan." >&2

# ─── Module list construction ─────────────────────────────────────────────────
# Use parallel arrays (bash 3 compatible — no associative arrays needed)

MOD_ID_LIST=()
MOD_SLUG_LIST=()
MOD_NAME_LIST=()

if [[ -n "$REGISTRY_FILE" && -f "$REGISTRY_FILE" ]]; then
  # Parse modules[] array from registry
  # Registry schema: modules[].id (^MOD-), .name, .slug (optional)
  while IFS=$'\t' read -r mid mname mslug; do
    [[ -z "$mid" ]] && continue
    [[ "$mid" != MOD-* ]] && continue
    mslug=$(echo "$mslug" | tr -d '\r')
    slug="${mslug:-$(module_id_to_slug "$mid")}"
    [[ -z "$slug" ]] && slug="$(module_id_to_slug "$mid")"
    MOD_ID_LIST+=("$mid")
    MOD_SLUG_LIST+=("$slug")
    MOD_NAME_LIST+=("${mname:-$mid}")
  done < <(jq -r '.modules[]? | [.id, (.name // ""), (.slug // "")] | @tsv' \
             "$REGISTRY_FILE" 2>/dev/null | tr -d '\r' || true)
fi

# Fallback: scan filesystem for module directories
if [[ ${#MOD_ID_LIST[@]} -lt 2 ]]; then
  echo "[wf-detect-cross-module-deps] WARN: <2 modules in registry. Scanning dirs..." >&2
  for module_dir in \
    "$PROJECT_ROOT"/apps/*/modules/*/ \
    "$PROJECT_ROOT"/apps/*/src/modules/*/ \
    "$PROJECT_ROOT"/src/modules/*/ \
    "$PROJECT_ROOT"/modules/*/; do
    [[ -d "$module_dir" ]] || continue
    slug=$(basename "$module_dir")
    mid="MOD-$(echo "$slug" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    # Avoid duplicates
    already=false
    for existing in "${MOD_ID_LIST[@]:-}"; do
      [[ "$existing" == "$mid" ]] && already=true && break
    done
    $already && continue
    MOD_ID_LIST+=("$mid")
    MOD_SLUG_LIST+=("$slug")
    MOD_NAME_LIST+=("$slug")
  done
fi

TOTAL_MODULES=${#MOD_ID_LIST[@]}

if [[ $TOTAL_MODULES -lt 2 ]]; then
  echo "ERROR: Need ≥2 modules to analyze pairs. Found: $TOTAL_MODULES" >&2
  echo "       Pass --registry=<path-to-req-registry.json> OR ensure modules[] in registry." >&2
  exit 1
fi

echo "[wf-detect-cross-module-deps] Modules detected: $TOTAL_MODULES" >&2
for i in "${!MOD_ID_LIST[@]}"; do
  echo "[wf-detect-cross-module-deps]   ${MOD_ID_LIST[$i]} (slug: ${MOD_SLUG_LIST[$i]})" >&2
done

[[ $TOTAL_MODULES -gt 15 ]] && echo \
  "[wf-detect-cross-module-deps] WARN: $TOTAL_MODULES modules → $((TOTAL_MODULES*(TOTAL_MODULES-1))) pairs (may take a few minutes)" >&2

# ─── Source directory resolution ───────────────────────────────────────────────

if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -d "$PROJECT_ROOT/apps" ]]; then
    SOURCE_DIR="$PROJECT_ROOT/apps"
  elif [[ -d "$PROJECT_ROOT/src" ]]; then
    SOURCE_DIR="$PROJECT_ROOT/src"
  else
    SOURCE_DIR="$PROJECT_ROOT"
  fi
fi

echo "[wf-detect-cross-module-deps] Source dir: $SOURCE_DIR" >&2

# ─── EXCLUDE pattern (REUSE: wf-fix-probe-cross-module-ref.sh:77) ─────────────
EXCLUDE_RE='(node_modules|\.git/|dist/|build/|\.next/|coverage/|\.nuxt/|__pycache__)'

# ─── Dry-run mode ─────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[wf-detect-cross-module-deps] DRY-RUN: Listing pairs that would be analyzed..." >&2
  pair_num=0
  for ci in "${!MOD_ID_LIST[@]}"; do
    for pi in "${!MOD_ID_LIST[@]}"; do
      [[ $ci -eq $pi ]] && continue
      pair_num=$((pair_num + 1))
      consumer_id="${MOD_ID_LIST[$ci]}"
      provider_id="${MOD_ID_LIST[$pi]}"
      provider_slug="${MOD_SLUG_LIST[$pi]}"
      entity=$(slug_to_entity "$provider_slug")
      echo "[dry-run] pair #${pair_num}: $consumer_id → $provider_id (entity: $entity)" >&2
    done
  done
  # Output valid JSON skeleton with zero suggestions
  jq -n \
    --arg schema "cross-module-dep-suggestions-v1" \
    --arg now "$(iso_now)" \
    --arg root "$PROJECT_ROOT" \
    --arg reg "${REGISTRY_FILE:-}" \
    --argjson tm "$TOTAL_MODULES" \
    --argjson pa "$pair_num" \
    '{"$schema":$schema,"generated_at":$now,"project_root":$root,"registry_path":$reg,
      "modules_analyzed":$tm,"pairs_analyzed":$pa,"suggestions_total":0,
      "min_confidence":0,"suggestions":[],
      "_note":"dry-run mode — no analysis performed"}'
  exit 0
fi

# ─── Pair analysis ─────────────────────────────────────────────────────────────

# Single reusable temp file (cleanup on exit) — REUSE: QD7 trap pattern
SCAN_TMP=$(mktemp)
trap 'rm -f "$SCAN_TMP"' EXIT

SUGGESTIONS_JSON=""
SUGGESTION_COUNT=0
PAIRS_ANALYZED=0

echo "[wf-detect-cross-module-deps] Starting pair analysis..." >&2

for ci in "${!MOD_ID_LIST[@]}"; do
  consumer_id="${MOD_ID_LIST[$ci]}"
  consumer_slug="${MOD_SLUG_LIST[$ci]}"

  # Locate consumer source directory (heuristic — match slug in path)
  consumer_src=""
  for candidate in \
    "$SOURCE_DIR"/*/"$consumer_slug"/ \
    "$SOURCE_DIR"/*/"${consumer_slug}s"/ \
    "$SOURCE_DIR"/"$consumer_slug"/ \
    "$SOURCE_DIR"/*/"modules/$consumer_slug"/ \
    "$SOURCE_DIR"/*/"src/$consumer_slug"/; do
    [[ -d "$candidate" ]] && consumer_src="$candidate" && break
  done
  # Intermediate: find-based search for deeper/non-standard structures
  if [[ -z "$consumer_src" ]]; then
    _found=$(find "$SOURCE_DIR" -maxdepth 5 -type d -iname "*${consumer_slug}*" \
      -not -path "*/node_modules/*" -not -path "*/.git/*" \
      -not -path "*/dist/*" -not -path "*/build/*" \
      2>/dev/null | head -1)
    [[ -n "$_found" ]] && consumer_src="$_found"
  fi
  # Fallback: use full source dir (still works, just less targeted)
  [[ -z "$consumer_src" ]] && consumer_src="$SOURCE_DIR"

  for pi in "${!MOD_ID_LIST[@]}"; do
    [[ $ci -eq $pi ]] && continue

    provider_id="${MOD_ID_LIST[$pi]}"
    provider_slug="${MOD_SLUG_LIST[$pi]}"
    provider_entity=$(slug_to_entity "$provider_slug")

    PAIRS_ANALYZED=$((PAIRS_ANALYZED + 1))

    # ── Step 1: Import grep ────────────────────────────────────────────────────
    # Combined regex (REUSE: wf-fix-probe-static-deprecated.sh:147-163 single scan)
    # Matches: from '...slug...', require('...slug...'), import EntityName from
    IMPORT_COMBINED="from[[:space:]]*['\"].*${provider_slug}['\"]|from[[:space:]]*['\"].*/${provider_slug}/|from[[:space:]]*['\"]@${provider_slug}|from[[:space:]]*['\"].*@[a-z-]*/${provider_slug}|require[[:space:]]*\([[:space:]]*['\"].*${provider_slug}|import[[:space:]].*${provider_entity}.*from"

    : > "$SCAN_TMP"
    grep -rEn -e "$IMPORT_COMBINED" "$consumer_src" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --include='*.py' --include='*.java' --include='*.cs' \
      --exclude-dir=node_modules --exclude-dir=.git \
      --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
      --exclude-dir=coverage --exclude-dir=.nuxt \
      2>/dev/null >> "$SCAN_TMP" || true

    IMPORT_COUNT=0
    EVIDENCE_ITEMS=""

    while IFS=: read -r f l m; do
      [[ -z "$f" || -z "$l" ]] && continue
      echo "$f" | grep -qE "$EXCLUDE_RE" && continue
      # Skip files belonging to provider module itself (avoids self-reference)
      echo "$f" | grep -qi "$provider_slug" && continue
      IMPORT_COUNT=$((IMPORT_COUNT + 1))
      # Collect top 3 evidence entries — use jq for safe JSON escaping (fix: CRLF in Windows source)
      if [[ $IMPORT_COUNT -le 3 ]]; then
        rel="${f#$PROJECT_ROOT/}"
        # tr -d '\r\n': strip CRLF before jq (Windows source files have \r in grep match field)
        ev=$(jq -c -n \
          --arg file "$(echo "$rel" | tr -d '\r')" \
          --arg line "$(echo "$l" | tr -d '[:space:]')" \
          --arg snip "$(echo "$m" | tr -d '\r\n' | head -c 100)" \
          '{"file":$file,"line":($line|tonumber),"type":"import","snippet":$snip}' 2>/dev/null || true)
        [[ -n "$ev" ]] && EVIDENCE_ITEMS="${EVIDENCE_ITEMS:+$EVIDENCE_ITEMS,}$ev"
      fi
    done < "$SCAN_TMP"

    # ── Step 2: API call grep ──────────────────────────────────────────────────
    # Matches: /api/slug, slugService., slugClient., slugApi.
    API_COMBINED="/api/${provider_slug}[^a-zA-Z]|/api/v[0-9]+/${provider_slug}[^a-zA-Z]|${provider_entity}Service\.|${provider_entity}Client\.|${provider_entity}Api\.|${provider_slug}-api"

    : > "$SCAN_TMP"
    grep -rEn -e "$API_COMBINED" "$consumer_src" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --include='*.py' --include='*.java' --include='*.cs' \
      --exclude-dir=node_modules --exclude-dir=.git \
      --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
      --exclude-dir=coverage --exclude-dir=.nuxt \
      2>/dev/null >> "$SCAN_TMP" || true

    API_COUNT=0
    while IFS=: read -r f l m; do
      [[ -z "$f" || -z "$l" ]] && continue
      echo "$f" | grep -qE "$EXCLUDE_RE" && continue
      echo "$f" | grep -qi "$provider_slug" && continue
      API_COUNT=$((API_COUNT + 1))
    done < "$SCAN_TMP"

    # ── Step 3: Type reference grep ────────────────────────────────────────────
    # Matches: EntityDTO, EntityModel, EntityType, type X = Entity, interface X extends Entity
    TYPE_COMBINED="${provider_entity}DTO[^a-zA-Z]|${provider_entity}Model[^a-zA-Z]|${provider_entity}Type[^a-zA-Z]|type[[:space:]].*${provider_entity}[[:space:]]*=|interface[[:space:]].*${provider_entity}[^a-zA-Z]"

    : > "$SCAN_TMP"
    grep -rEn -e "$TYPE_COMBINED" "$consumer_src" \
      --include='*.ts' --include='*.tsx' --include='*.d.ts' \
      --exclude-dir=node_modules --exclude-dir=.git \
      --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
      --exclude-dir=coverage \
      2>/dev/null >> "$SCAN_TMP" || true

    TYPE_COUNT=0
    while IFS=: read -r f l m; do
      [[ -z "$f" || -z "$l" ]] && continue
      echo "$f" | grep -qE "$EXCLUDE_RE" && continue
      echo "$f" | grep -qi "$provider_slug" && continue
      TYPE_COUNT=$((TYPE_COUNT + 1))
    done < "$SCAN_TMP"

    # ── Score & filter ─────────────────────────────────────────────────────────
    CONFIDENCE=$(score_confidence "$IMPORT_COUNT" "$API_COUNT" "$TYPE_COUNT")

    conf_meets_threshold "$CONFIDENCE" || continue

    # ── Binding type heuristic ─────────────────────────────────────────────────
    # Scan for event patterns (on/subscribe/emit with provider slug)
    EVENT_COMBINED="on[[:space:]]*\([[:space:]]*['\"]${provider_slug}\.|subscribe.*${provider_slug}|emit[[:space:]]*\([[:space:]]*['\"]${provider_slug}"
    EVENT_COUNT=0
    : > "$SCAN_TMP"
    grep -rEn -e "$EVENT_COMBINED" "$consumer_src" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
      --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
      2>/dev/null >> "$SCAN_TMP" || true
    while IFS=: read -r f l m; do
      [[ -z "$f" || -z "$l" ]] && continue
      echo "$f" | grep -qE "$EXCLUDE_RE" && continue
      EVENT_COUNT=$((EVENT_COUNT + 1))
    done < "$SCAN_TMP"

    # Scan for foreign key patterns (provider_slug_id, provider_slugId)
    FK_COMBINED="${provider_slug}[_][Ii]d[^a-zA-Z]|${provider_slug}Id[^a-zA-Z]|${provider_entity}Id[^a-zA-Z]"
    FK_COUNT=0
    : > "$SCAN_TMP"
    grep -rEn -e "$FK_COMBINED" "$consumer_src" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --include='*.py' --include='*.java' --include='*.cs' \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
      --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
      2>/dev/null >> "$SCAN_TMP" || true
    while IFS=: read -r f l m; do
      [[ -z "$f" || -z "$l" ]] && continue
      echo "$f" | grep -qE "$EXCLUDE_RE" && continue
      FK_COUNT=$((FK_COUNT + 1))
    done < "$SCAN_TMP"

    # Determine binding_type_guess
    BINDING_TYPE="api"
    if [[ $EVENT_COUNT -gt 0 && $EVENT_COUNT -ge $((IMPORT_COUNT / 2 + 1)) ]]; then
      BINDING_TYPE="event"
    elif [[ $FK_COUNT -gt 3 ]]; then
      BINDING_TYPE="foreign_key"
    elif [[ $TYPE_COUNT -gt 0 && $TYPE_COUNT -gt $IMPORT_COUNT && $API_COUNT -eq 0 ]]; then
      BINDING_TYPE="denormalized_copy"
    fi

    # ── Build suggestion JSON ──────────────────────────────────────────────────
    suggestion=$(jq -n \
      --arg consumer  "$consumer_id" \
      --arg provider  "$provider_id" \
      --arg entity    "$provider_entity" \
      --arg conf      "$CONFIDENCE" \
      --arg binding   "$BINDING_TYPE" \
      --argjson ic    "$IMPORT_COUNT" \
      --argjson ac    "$API_COUNT" \
      --argjson tc    "$TYPE_COUNT" \
      --argjson ec    "$EVENT_COUNT" \
      --argjson fk    "$FK_COUNT" \
      --argjson ev    "[${EVIDENCE_ITEMS:-}]" \
      '{
        "consumer_module":    $consumer,
        "provider_module":    $provider,
        "entity":             $entity,
        "confidence":         ($conf | tonumber),
        "binding_type_guess": $binding,
        "import_count":       $ic,
        "api_call_count":     $ac,
        "type_ref_count":     $tc,
        "event_count":        $ec,
        "fk_ref_count":       $fk,
        "evidence":           $ev
      }')

    SUGGESTIONS_JSON="${SUGGESTIONS_JSON:+$SUGGESTIONS_JSON,}$suggestion"
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))

    echo "[wf-detect-cross-module-deps] FOUND: $consumer_id → $provider_id" \
         "(conf=$CONFIDENCE, type=$BINDING_TYPE, imports=$IMPORT_COUNT, api=$API_COUNT, types=$TYPE_COUNT)" >&2
  done
done

# ─── Sort suggestions by confidence DESC ──────────────────────────────────────

SORTED_SUGGESTIONS="[]"
if [[ -n "$SUGGESTIONS_JSON" ]]; then
  SORTED_SUGGESTIONS=$(jq -n "[${SUGGESTIONS_JSON}] | sort_by(.confidence) | reverse" 2>/dev/null \
                       || echo "[${SUGGESTIONS_JSON}]")
fi

# ─── Build final output JSON ───────────────────────────────────────────────────

OUTPUT=$(jq -n \
  --arg schema "cross-module-dep-suggestions-v1" \
  --arg now    "$(iso_now)" \
  --arg root   "$(json_str "$PROJECT_ROOT")" \
  --arg reg    "$(json_str "${REGISTRY_FILE:-}")" \
  --argjson tm "$TOTAL_MODULES" \
  --argjson pa "$PAIRS_ANALYZED" \
  --argjson st "$SUGGESTION_COUNT" \
  --arg     mc "$MIN_CONFIDENCE" \
  --argjson sugs "$SORTED_SUGGESTIONS" \
  '{
    "$schema":          $schema,
    "generated_at":     $now,
    "project_root":     $root,
    "registry_path":    $reg,
    "modules_analyzed": $tm,
    "pairs_analyzed":   $pa,
    "suggestions_total": $st,
    "min_confidence":   ($mc | tonumber),
    "suggestions":      $sugs,
    "_usage_note":      "Review suggestions. To populate registry: copy relevant entries to cross_module_dependencies[] in req-registry.json. Required fields: id, consumer_module, provider_module, entity, binding_type, required_fields[]. Do NOT commit without user review."
  }')

# ─── Output ───────────────────────────────────────────────────────────────────

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$OUTPUT" > "$OUTPUT_FILE"
  echo "[wf-detect-cross-module-deps] Output written to: $OUTPUT_FILE" >&2
fi

echo "$OUTPUT"

echo "[wf-detect-cross-module-deps] Done. $SUGGESTION_COUNT suggestions from $PAIRS_ANALYZED pairs." >&2
