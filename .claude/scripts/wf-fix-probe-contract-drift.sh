#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-contract-drift.sh — Helper: API Contract Drift Detection (QD10)
#
# Phat hien drift giua provider API spec (OpenAPI/GraphQL/AsyncAPI) va consumer DTOs.
# Reuses QD6 schema-drift-detect approach: extract fields tu 2 nguon, compare per-field.
# Reuses QD7 combined grep approach: single combined regex scan cho DTO discovery.
#
# Execution paths:
#   A. Spec + DTO: Compare OpenAPI/AsyncAPI/GraphQL spec vs TypeScript/Pydantic/C# DTOs (BEST)
#   B. Serena-based: Serena find_symbol PRIMARY (CI-ROUTE) — orchestrator calls MCP directly
#   C. DTO-only grep: No spec found → compare registry required_fields vs consumer DTO fields
#   D. Graceful degradation: No source/spec → probe_status=contract_drift_unavailable
#
# Supported provider spec formats:
#   - OpenAPI 3.x: openapi.yaml, openapi.json, swagger.json, swagger.yaml
#   - AsyncAPI 2.x/3.x: asyncapi.yaml, asyncapi.json
#   - GraphQL: *.graphql, schema.graphql (field extraction via grep)
#
# Supported consumer DTO formats:
#   - TypeScript: *.dto.ts, *.interface.ts, *.type.ts, *Request.ts, *Response.ts
#   - Python/Pydantic: *.py classes extending BaseModel
#   - C#: *Dto.cs, *Request.cs, *Response.cs
#   - Java: *Dto.java, *Request.java, *Response.java
#
# USAGE:
#   bash wf-fix-probe-contract-drift.sh \
#     --source-dir <path>                (default: src, fallback: apps, .)
#     --provider-hint <string>           (lowercase module hint, e.g. "crm")
#     --consumer-hint <string>           (lowercase module hint, e.g. "quotation")
#     --entity <string>                  (entity name, e.g. "Customer")
#     [--spec-file <path>]               (override spec file auto-detection)
#     [--spec-type openapi|graphql|asyncapi]
#     [--profile quick|standard|deep|exhaustive]
#     [--detect-only]                    (only detect spec files, output JSON count)
#     [--detect-spec]                    (detect spec for provider-hint+entity, output {spec_file, spec_type})
#     [--detect-consumer-dto]            (detect consumer DTO for entity, output {dto_file})
#     [--output-file <path>]             (write output JSON to file instead of stdout)
#
# OUTPUT: JSON on stdout (or --output-file). Schema:
#   { diffs: [{drift_type, field_name, provider_type, consumer_type, provider_value, consumer_value}],
#     spec_files_found: N, dto_files_found: N, spec_file: <path>, dto_file: <path>,
#     diff_method: string, spec_type: string }
#
# EXIT CODES: 0 success (even if diffs found), 1 fatal error
#
# Author: plan wf-fix-bugs-v9 Wave 2 W2.3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (pattern from wf-fix-probe-cross-module-ref.sh:32)
[[ "$(type -t with_runtime_cap 2>/dev/null)" == "function" ]] && with_runtime_cap "$@"

SOURCE_DIR="src"
PROVIDER_HINT=""
CONSUMER_HINT=""
ENTITY=""
SPEC_FILE_OVERRIDE=""
SPEC_TYPE_OVERRIDE=""
PROFILE="standard"
DETECT_ONLY=false
DETECT_SPEC=false
DETECT_CONSUMER_DTO=false
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source-dir)          SOURCE_DIR="$2";          shift 2 ;;
    --provider-hint)       PROVIDER_HINT="$2";       shift 2 ;;
    --consumer-hint)       CONSUMER_HINT="$2";       shift 2 ;;
    --entity)              ENTITY="$2";              shift 2 ;;
    --spec-file)           SPEC_FILE_OVERRIDE="$2";  shift 2 ;;
    --spec-type)           SPEC_TYPE_OVERRIDE="$2";  shift 2 ;;
    --profile)             PROFILE="$2";             shift 2 ;;
    --detect-only)         DETECT_ONLY=true;         shift ;;
    --detect-spec)         DETECT_SPEC=true;         shift ;;
    --detect-consumer-dto) DETECT_CONSUMER_DTO=true; shift ;;
    --output-file)         OUTPUT_FILE="$2";         shift 2 ;;
    -h|--help)             sed -n '2,45p' "$0"; exit 0 ;;
    --_runtime-cap-applied) shift ;;
    --timeout-seconds)     shift 2 ;;
    *) echo "WARN: unknown arg $1, ignoring" >&2; shift ;;
  esac
done

# SOURCE_DIR fallback (REUSE QD10 cross-module-ref.sh:66-74)
if [ ! -d "$SOURCE_DIR" ]; then
  if [ -d "apps" ]; then SOURCE_DIR="apps"
  elif [ -d "src" ]; then SOURCE_DIR="src"
  else SOURCE_DIR="."
  fi
fi

# EXCLUDE_PATTERN (REUSE: QD7 wf-fix-probe-static-deprecated.sh:99)
EXCLUDE_PATTERN='(node_modules|\.git/|dist/|build/|\.next/|coverage/|\.cache/)'

# Output helper
_output_json() {
  local json="$1"
  if [ -n "$OUTPUT_FILE" ]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    printf '%s\n' "$json" > "$OUTPUT_FILE"
  else
    printf '%s\n' "$json"
  fi
}

# ============================================================
# MODE: --detect-only (count spec files available)
# ============================================================
if $DETECT_ONLY; then
  SPEC_COUNT=0

  # OpenAPI/Swagger
  OA_COUNT=$(find "$SOURCE_DIR" -maxdepth 8 \
    \( -name "openapi.yaml" -o -name "openapi.json" -o -name "swagger.yaml" -o -name "swagger.json" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | wc -l || echo 0)
  SPEC_COUNT=$((SPEC_COUNT + OA_COUNT))

  # AsyncAPI
  AA_COUNT=$(find "$SOURCE_DIR" -maxdepth 8 \
    \( -name "asyncapi.yaml" -o -name "asyncapi.json" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | wc -l || echo 0)
  SPEC_COUNT=$((SPEC_COUNT + AA_COUNT))

  # GraphQL schemas
  GQL_COUNT=$(find "$SOURCE_DIR" -maxdepth 8 \
    \( -name "*.graphql" -o -name "schema.graphql" -o -name "schema.gql" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | wc -l || echo 0)
  SPEC_COUNT=$((SPEC_COUNT + GQL_COUNT))

  _output_json "{\"spec_files_found\": $SPEC_COUNT, \"openapi\": $OA_COUNT, \"asyncapi\": $AA_COUNT, \"graphql\": $GQL_COUNT}"
  exit 0
fi

# ============================================================
# MODE: --detect-spec (find spec for provider-hint+entity)
# ============================================================
if $DETECT_SPEC; then
  SPEC_FILE=""
  SPEC_TYPE="unknown"

  if [ -n "$SPEC_FILE_OVERRIDE" ] && [ -f "$SPEC_FILE_OVERRIDE" ]; then
    SPEC_FILE="$SPEC_FILE_OVERRIDE"
    SPEC_TYPE="${SPEC_TYPE_OVERRIDE:-openapi}"
  else
    # Try provider-hint directory first, then global
    SEARCH_PATHS=()
    if [ -n "$PROVIDER_HINT" ]; then
      # Monorepo: apps/{provider_hint}/ or src/{provider_hint}/
      for d in "apps/$PROVIDER_HINT" "apps/${PROVIDER_HINT}-service" "apps/${PROVIDER_HINT}-api" \
                "src/$PROVIDER_HINT" "packages/$PROVIDER_HINT"; do
        [ -d "$d" ] && SEARCH_PATHS+=("$d")
      done
    fi
    SEARCH_PATHS+=("$SOURCE_DIR")

    for SEARCH in "${SEARCH_PATHS[@]}"; do
      [ -d "$SEARCH" ] || continue

      # 1. OpenAPI
      CANDIDATE=$(find "$SEARCH" -maxdepth 6 \
        \( -name "openapi.yaml" -o -name "openapi.json" -o -name "swagger.yaml" -o -name "swagger.json" \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -1 || echo "")
      if [ -n "$CANDIDATE" ]; then
        SPEC_FILE="$CANDIDATE"
        SPEC_TYPE="openapi"
        break
      fi

      # 2. AsyncAPI
      CANDIDATE=$(find "$SEARCH" -maxdepth 6 \
        \( -name "asyncapi.yaml" -o -name "asyncapi.json" \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -1 || echo "")
      if [ -n "$CANDIDATE" ]; then
        SPEC_FILE="$CANDIDATE"
        SPEC_TYPE="asyncapi"
        break
      fi

      # 3. GraphQL
      CANDIDATE=$(find "$SEARCH" -maxdepth 6 \
        \( -name "schema.graphql" -o -name "schema.gql" -o -name "${ENTITY:-}.graphql" \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -1 || echo "")
      if [ -n "$CANDIDATE" ]; then
        SPEC_FILE="$CANDIDATE"
        SPEC_TYPE="graphql"
        break
      fi
    done
  fi

  SPEC_FILE_JSON=$(printf '%s' "${SPEC_FILE:-}" | jq -Rs .)
  _output_json "{\"spec_file\": $SPEC_FILE_JSON, \"spec_type\": \"${SPEC_TYPE}\"}"
  exit 0
fi

# ============================================================
# MODE: --detect-consumer-dto (find consumer DTO for entity)
# ============================================================
if $DETECT_CONSUMER_DTO; then
  DTO_FILE=""

  # Search paths: consumer hint dir first, then SOURCE_DIR
  SEARCH_PATHS=()
  if [ -n "$CONSUMER_HINT" ]; then
    for d in "apps/$CONSUMER_HINT" "apps/${CONSUMER_HINT}-web" "apps/${CONSUMER_HINT}-service" \
              "src/$CONSUMER_HINT" "packages/$CONSUMER_HINT"; do
      [ -d "$d" ] && SEARCH_PATHS+=("$d")
    done
  fi
  SEARCH_PATHS+=("$SOURCE_DIR")

  ENTITY_PATTERN="${ENTITY:-}"
  if [ -n "$ENTITY_PATTERN" ]; then
    # TypeScript DTO: <Entity>.dto.ts, <Entity>Dto.ts, <Entity>Request.ts, <Entity>Response.ts
    for SEARCH in "${SEARCH_PATHS[@]}"; do
      [ -d "$SEARCH" ] || continue
      CANDIDATE=$(find "$SEARCH" -maxdepth 8 \
        \( -iname "${ENTITY_PATTERN}.dto.ts" \
           -o -iname "${ENTITY_PATTERN}Dto.ts" \
           -o -iname "${ENTITY_PATTERN}Request.ts" \
           -o -iname "${ENTITY_PATTERN}Response.ts" \
           -o -iname "${ENTITY_PATTERN}.type.ts" \
           -o -iname "${ENTITY_PATTERN}.interface.ts" \
        \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | head -1 || echo "")
      if [ -n "$CANDIDATE" ]; then
        DTO_FILE="$CANDIDATE"
        break
      fi
    done
  fi

  # Fallback: grep for interface/type matching entity name (REUSE QD7 combined grep approach:147-217)
  if [ -z "$DTO_FILE" ] && [ -n "$ENTITY_PATTERN" ]; then
    for SEARCH in "${SEARCH_PATHS[@]}"; do
      [ -d "$SEARCH" ] || continue
      CANDIDATE=$(grep -rl \
        "interface ${ENTITY_PATTERN}\b\|type ${ENTITY_PATTERN}\b\|class ${ENTITY_PATTERN}\b" \
        "$SEARCH" 2>/dev/null \
        | grep -Ev "$EXCLUDE_PATTERN" \
        | grep -E "\.(ts|tsx|py|cs|java)$" \
        | head -1 || echo "")
      if [ -n "$CANDIDATE" ]; then
        DTO_FILE="$CANDIDATE"
        break
      fi
    done
  fi

  DTO_FILE_JSON=$(printf '%s' "${DTO_FILE:-}" | jq -Rs .)
  _output_json "{\"dto_file\": $DTO_FILE_JSON}"
  exit 0
fi

# ============================================================
# MAIN: Full contract drift analysis (provider spec vs consumer DTO)
# ============================================================

[ -z "$ENTITY" ] && { echo "ERROR: --entity required for full drift analysis" >&2; exit 1; }

DIFFS=()
SPEC_FILE=""
SPEC_TYPE="unknown"
DTO_FILE=""
DIFF_METHOD="grep_only"

# ---- Detect spec file ----
if [ -n "$SPEC_FILE_OVERRIDE" ] && [ -f "$SPEC_FILE_OVERRIDE" ]; then
  SPEC_FILE="$SPEC_FILE_OVERRIDE"
  SPEC_TYPE="${SPEC_TYPE_OVERRIDE:-openapi}"
else
  DETECT_RESULT=$(bash "$SCRIPT_DIR/wf-fix-probe-contract-drift.sh" \
    --source-dir "$SOURCE_DIR" --provider-hint "$PROVIDER_HINT" \
    --entity "$ENTITY" --detect-spec 2>/dev/null || echo '{}')
  SPEC_FILE=$(echo "$DETECT_RESULT" | jq -r '.spec_file // ""')
  SPEC_TYPE=$(echo "$DETECT_RESULT" | jq -r '.spec_type // "unknown"')
fi

# ---- Detect consumer DTO ----
if [ -n "$CONSUMER_HINT" ]; then
  DTO_RESULT=$(bash "$SCRIPT_DIR/wf-fix-probe-contract-drift.sh" \
    --source-dir "$SOURCE_DIR" --consumer-hint "$CONSUMER_HINT" \
    --entity "$ENTITY" --detect-consumer-dto 2>/dev/null || echo '{}')
  DTO_FILE=$(echo "$DTO_RESULT" | jq -r '.dto_file // ""')
fi

# ---- Extract provider fields from spec ----
declare -A PROVIDER_FIELDS      # field_name → type
declare -A PROVIDER_REQUIRED    # field_name → "true" if required

_extract_openapi_fields() {
  local spec="$1"
  local entity_lower
  entity_lower=$(echo "$ENTITY" | tr '[:upper:]' '[:lower:]')

  # Parse JSON or YAML OpenAPI spec
  # JSON: use jq; YAML: use python (if available) or grep fallback
  if [[ "$spec" == *.json ]]; then
    # jq: find schema named $ENTITY under components/schemas or definitions
    SCHEMA_JSON=$(jq -r --arg entity "$ENTITY" --arg entity_l "$entity_lower" '
      ((.components.schemas // .definitions) //
       (.paths | to_entries[].value | .responses["200"].content["application/json"].schema // empty)) |
      to_entries[] |
      select(.key == $entity or (.key | ascii_downcase) == $entity_l) |
      .value
    ' "$spec" 2>/dev/null | head -1 || echo "")

    if [ -n "$SCHEMA_JSON" ]; then
      # Extract fields
      while IFS=$'\t' read -r fname ftype freq; do
        PROVIDER_FIELDS["$fname"]="${ftype:-string}"
        [[ "$freq" == "true" ]] && PROVIDER_REQUIRED["$fname"]="true"
      done < <(echo "$SCHEMA_JSON" | jq -r '
        .properties // {} | to_entries[] |
        [.key, (.value.type // "object"), "false"] | @tsv
      ' 2>/dev/null || echo "")

      # Mark required fields
      while IFS= read -r req_field; do
        [ -n "$req_field" ] && PROVIDER_REQUIRED["$req_field"]="true"
      done < <(echo "$SCHEMA_JSON" | jq -r '.required // [] | .[]' 2>/dev/null || echo "")
    fi

  else
    # YAML: grep fallback (limited but zero-dependency)
    # Extract fields from YAML schema block matching entity name
    # Pattern: look for `properties:` section after entity name
    IN_ENTITY=false
    IN_PROPERTIES=false
    INDENT_LEVEL=0

    while IFS= read -r line; do
      if echo "$line" | grep -qiE "^[[:space:]]*(${ENTITY}|${entity_lower})[[:space:]]*:"; then
        IN_ENTITY=true
        INDENT_LEVEL=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        continue
      fi
      if $IN_ENTITY && echo "$line" | grep -qE "^[[:space:]]+properties:"; then
        IN_PROPERTIES=true
        continue
      fi
      if $IN_PROPERTIES; then
        # Field line: `  fieldName:` (indented more than properties)
        if echo "$line" | grep -qE "^[[:space:]]{4,}[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*:"; then
          FNAME=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/:.*//' | tr -d ' ')
          [ -n "$FNAME" ] && PROVIDER_FIELDS["$FNAME"]="string"  # type detection limited in YAML grep
        fi
        # Stop at dedent to same level as entity
        CUR_INDENT=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        if [ "$CUR_INDENT" -le "$INDENT_LEVEL" ] && echo "$line" | grep -qE "^[[:space:]]*[a-zA-Z]"; then
          IN_ENTITY=false
          IN_PROPERTIES=false
        fi
      fi
    done < "$spec"
  fi
}

_extract_graphql_fields() {
  local spec="$1"
  # Extract fields from GraphQL type definition
  # Pattern: `type Customer { field: Type }` or multiline
  IN_TYPE=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE "^type[[:space:]]+${ENTITY}[[:space:]]*\{"; then
      IN_TYPE=true
      continue
    fi
    if $IN_TYPE; then
      if echo "$line" | grep -q "}"; then
        IN_TYPE=false
        continue
      fi
      # Field line: `  fieldName: FieldType`
      if echo "$line" | grep -qE "^[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*:"; then
        FNAME=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*:.*//')
        FTYPE=$(echo "$line" | sed 's/.*:[[:space:]]*//' | sed 's/[![:space:]].*//' | tr -d '[]!')
        [ -n "$FNAME" ] && PROVIDER_FIELDS["$FNAME"]="${FTYPE:-String}"
        # Required in GraphQL = non-null (!) suffix on type
        echo "$line" | grep -q "!$\|! " && PROVIDER_REQUIRED["$FNAME"]="true"
      fi
    fi
  done < "$spec"
}

# Load provider fields from spec
if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  case "$SPEC_TYPE" in
    openapi)  _extract_openapi_fields "$SPEC_FILE" ;;
    asyncapi) _extract_openapi_fields "$SPEC_FILE" ;;  # AsyncAPI components/schemas similar to OpenAPI
    graphql)  _extract_graphql_fields "$SPEC_FILE" ;;
  esac
  DIFF_METHOD="spec_vs_dto"
  echo "INFO: Extracted ${#PROVIDER_FIELDS[@]} provider fields from $SPEC_FILE (type=$SPEC_TYPE)" >&2
else
  echo "WARN: No spec file found for entity $ENTITY — relying on registry required_fields only" >&2
  DIFF_METHOD="registry_vs_dto"
fi

# ---- Extract consumer DTO fields ----
declare -A CONSUMER_FIELDS      # field_name → type

_extract_ts_dto_fields() {
  local dto="$1"
  # TypeScript interface/type: `fieldName: TypeName;` or `fieldName?: TypeName;`
  while IFS= read -r line; do
    if echo "$line" | grep -qE "^[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*\??[[:space:]]*:[[:space:]]*[a-zA-Z]"; then
      FNAME=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[?[:space:]]*:.*//')
      FTYPE=$(echo "$line" | sed 's/.*:[[:space:]]*//' | sed 's/[;[:space:]|].*//')
      [ -n "$FNAME" ] && CONSUMER_FIELDS["$FNAME"]="${FTYPE:-unknown}"
    fi
  done < "$dto"
}

_extract_pydantic_fields() {
  local dto="$1"
  # Python Pydantic: `field_name: str` or `field_name: Optional[str] = None`
  while IFS= read -r line; do
    if echo "$line" | grep -qE "^[[:space:]]{4}[a-z][a-z0-9_]*[[:space:]]*:[[:space:]]*[A-Za-z]"; then
      FNAME=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*:.*//')
      FTYPE=$(echo "$line" | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]=.*//' | sed 's/Optional\[//' | sed 's/\].*//')
      [ -n "$FNAME" ] && CONSUMER_FIELDS["$FNAME"]="${FTYPE:-unknown}"
    fi
  done < "$dto"
}

if [ -n "$DTO_FILE" ] && [ -f "$DTO_FILE" ]; then
  case "$DTO_FILE" in
    *.ts|*.tsx) _extract_ts_dto_fields "$DTO_FILE" ;;
    *.py)       _extract_pydantic_fields "$DTO_FILE" ;;
    *.cs|*.java)
      # C#/Java: grep field declarations
      while IFS= read -r line; do
        if echo "$line" | grep -qE "(public|private|protected)[[:space:]]+[A-Za-z<>?]+[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*[{;]"; then
          FNAME=$(echo "$line" | grep -oE "[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*[{;]" | head -1 | sed 's/[[:space:]]*[{;]$//')
          [ -n "$FNAME" ] && CONSUMER_FIELDS["$FNAME"]="object"
        fi
      done < "$DTO_FILE"
      ;;
    *) _extract_ts_dto_fields "$DTO_FILE" ;;  # default: try TS format
  esac
  echo "INFO: Extracted ${#CONSUMER_FIELDS[@]} consumer fields from $DTO_FILE" >&2
else
  echo "WARN: No consumer DTO file resolved — field comparison will produce no diffs" >&2
fi

# ---- Compute diffs (REUSE QD6 THINK:113-143 schema diff algorithm) ----
DIFFS_JSON="[]"

# Check 1: Fields in provider spec but NOT in consumer DTO → breaking change candidate
for fname in "${!PROVIDER_FIELDS[@]}"; do
  if [ -z "${CONSUMER_FIELDS[$fname]+x}" ]; then
    # Provider has field, consumer does not
    drift_type="field_removed_from_spec"
    if [ "${PROVIDER_REQUIRED[$fname]:-false}" == "true" ]; then
      # Required in provider but missing in consumer → definite breaking change
      drift_type="required_field_added_in_spec"
    fi
    pval="${PROVIDER_FIELDS[$fname]}"
    DIFFS_JSON=$(echo "$DIFFS_JSON" | jq \
      --arg dt "$drift_type" --arg fn "$fname" --arg pv "$pval" \
      '. + [{"drift_type": $dt, "field_name": $fn, "provider_type": $pv, "consumer_type": null, "provider_value": $pv, "consumer_value": null}]' \
      2>/dev/null || echo "$DIFFS_JSON")
  fi
done

# Check 2: Type mismatches (field exists in both but types differ)
for fname in "${!PROVIDER_FIELDS[@]}"; do
  if [ -n "${CONSUMER_FIELDS[$fname]+x}" ]; then
    ptype="${PROVIDER_FIELDS[$fname]}"
    ctype="${CONSUMER_FIELDS[$fname]}"

    # Normalize types for comparison (string/String/str → string)
    ptype_norm=$(echo "$ptype" | tr '[:upper:]' '[:lower:]' | sed 's/optional\[//' | sed 's/\]//')
    ctype_norm=$(echo "$ctype" | tr '[:upper:]' '[:lower:]' | sed 's/optional\[//' | sed 's/\]//' | sed 's/string/string/' | sed 's/number\|int\|float\|double/number/')

    # Map provider OpenAPI types to comparison equivalents
    case "$ptype_norm" in
      integer|int32|int64) ptype_norm="number" ;;
      float|double|number) ptype_norm="number" ;;
      boolean|bool)        ptype_norm="boolean" ;;
      string|str)          ptype_norm="string" ;;
    esac

    case "$ctype_norm" in
      number|int|float|double|integer) ctype_norm="number" ;;
      boolean|bool)                    ctype_norm="boolean" ;;
      string|str)                      ctype_norm="string" ;;
    esac

    if [ "$ptype_norm" != "$ctype_norm" ] && \
       [ "$ptype_norm" != "object" ] && [ "$ctype_norm" != "unknown" ]; then
      DIFFS_JSON=$(echo "$DIFFS_JSON" | jq \
        --arg fn "$fname" --arg pt "$ptype" --arg ct "$ctype" \
        '. + [{"drift_type": "type_mismatch", "field_name": $fn, "provider_type": $pt, "consumer_type": $ct, "provider_value": $pt, "consumer_value": $ct}]' \
        2>/dev/null || echo "$DIFFS_JSON")
    fi
  fi
done

DIFF_COUNT=$(echo "$DIFFS_JSON" | jq 'length' 2>/dev/null || echo 0)
SPEC_FILES_FOUND=$([ -n "$SPEC_FILE" ] && echo 1 || echo 0)
DTO_FILES_FOUND=$([ -n "$DTO_FILE" ] && echo 1 || echo 0)

SPEC_FILE_JSON=$(printf '%s' "${SPEC_FILE:-}" | jq -Rs .)
DTO_FILE_JSON=$(printf '%s' "${DTO_FILE:-}" | jq -Rs .)

RESULT=$(jq -n \
  --argjson diffs "$DIFFS_JSON" \
  --argjson sf "$SPEC_FILES_FOUND" \
  --argjson df "$DTO_FILES_FOUND" \
  --arg spec_file "${SPEC_FILE:-}" \
  --arg dto_file "${DTO_FILE:-}" \
  --arg diff_method "$DIFF_METHOD" \
  --arg spec_type "$SPEC_TYPE" \
  --argjson diff_count "$DIFF_COUNT" \
  '{
    diffs: $diffs,
    diff_count: $diff_count,
    spec_files_found: $sf,
    dto_files_found: $df,
    spec_file: $spec_file,
    dto_file: $dto_file,
    diff_method: $diff_method,
    spec_type: $spec_type
  }' 2>/dev/null || \
  echo "{\"diffs\":[],\"diff_count\":0,\"spec_files_found\":$SPEC_FILES_FOUND,\"dto_files_found\":$DTO_FILES_FOUND,\"error\":\"jq_failed\"}")

_output_json "$RESULT"
echo "INFO: Contract drift analysis complete: entity=$ENTITY diff_count=$DIFF_COUNT method=$DIFF_METHOD" >&2

exit 0
