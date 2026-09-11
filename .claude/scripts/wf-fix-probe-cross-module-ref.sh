#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-cross-module-ref.sh — Helper: Cross-Module Reference Static Analysis (QD10)
#
# Tim consumer code references den provider entity qua import path grep.
# Reuses combined grep approach tu wf-fix-probe-static-deprecated.sh (QD7):147-217:
#   - Single combined regex scan (khong O(N) scans)
#   - EXCLUDE_PATTERN config
#   - classify per match sau grep
#
# USAGE:
#   bash wf-fix-probe-cross-module-ref.sh \
#     --session-dir <path> \
#     --consumer-module <MODULE_ID> \
#     --provider-module <MODULE_ID> \
#     --entity <EntityName> \
#     --source-dir <src/> \
#     [--check-deprecated] \
#     [--output-file <path>]
#
# OUTPUT: JSON tren stdout hoac --output-file
# EXIT CODES: 0 success, 1 error
#
# Author: plan wf-fix-bugs-v9 Wave 2 W2.2


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (pattern tu QD7 wf-fix-probe-static-deprecated.sh:30)
with_runtime_cap "$@"

SESSION_DIR=""
CONSUMER_MODULE=""
PROVIDER_MODULE=""
ENTITY=""
SOURCE_DIR="src/"
CHECK_DEPRECATED=false
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir)       SESSION_DIR="$2"; shift 2 ;;
    --consumer-module)   CONSUMER_MODULE="$2"; shift 2 ;;
    --provider-module)   PROVIDER_MODULE="$2"; shift 2 ;;
    --entity)            ENTITY="$2"; shift 2 ;;
    --source-dir)        SOURCE_DIR="$2"; shift 2 ;;
    --check-deprecated)  CHECK_DEPRECATED=true; shift ;;
    --output-file)       OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help)           sed -n '2,22p' "$0"; exit 0 ;;
    # Absorb with_runtime_cap args (--_runtime-cap-applied, --timeout-seconds)
    --_runtime-cap-applied) shift ;;
    --timeout-seconds)  shift 2 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# Validate required args
[ -z "$CONSUMER_MODULE" ] && { echo "ERROR: --consumer-module required" >&2; exit 1; }
[ -z "$PROVIDER_MODULE" ] && { echo "ERROR: --provider-module required" >&2; exit 1; }
[ -z "$ENTITY" ]          && { echo "ERROR: --entity required" >&2; exit 1; }

# SOURCE_DIR default + fallback
[ -z "$SOURCE_DIR" ] && SOURCE_DIR="src/"
if [ ! -d "$SOURCE_DIR" ]; then
  if [ -d "apps" ]; then
    SOURCE_DIR="apps"
  elif [ -d "src" ]; then
    SOURCE_DIR="src"
  else
    SOURCE_DIR="."
  fi
fi

# EXCLUDE_PATTERN (REUSE: QD7 wf-fix-probe-static-deprecated.sh:99)
EXCLUDE_PATTERN='(node_modules|\.git/|dist/|build/|\.next/|coverage/)'

# Normalize module ID → directory hint
# MOD-CRM → crm | MOD-QUOTATION → quotation
consumer_dir_hint=$(echo "$CONSUMER_MODULE" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
provider_dir_hint=$(echo "$PROVIDER_MODULE" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Temp storage
FINDINGS_TMP=$(mktemp)
FINDINGS_COUNT=0
IMPORT_FOUND="false"
DEPRECATED_FOUND="false"

trap 'rm -f "$FINDINGS_TMP"' EXIT
: > "$FINDINGS_TMP"

# ============================================================
# Step 1: Tim consumer import cua provider entity
# Reuse: combined grep approach tu QD7:147-163 (single scan thay O(N))
# ============================================================
if [ -d "$SOURCE_DIR" ]; then
  # Build combined import regex patterns
  # REUSE: QD7 wf-fix-probe-static-deprecated.sh:149-155 (COMBINED_REGEX build pattern)
  IMPORT_PATTERNS=(
    "import[[:space:]].*${ENTITY}[[:space:]]*from[[:space:]]*['\"].*${provider_dir_hint}"
    "import[[:space:]].*${ENTITY}[[:space:]]*from[[:space:]]*['\"]@modules/${provider_dir_hint}"
    "import[[:space:]].*${ENTITY}[[:space:]]*from[[:space:]]*['\"]@${provider_dir_hint}"
    "import[[:space:]].*from[[:space:]]*['\"].*${provider_dir_hint}.*['\"][[:space:]]*;.*${ENTITY}"
    "require[[:space:]]*\([[:space:]]*['\"].*${provider_dir_hint}.*${ENTITY}"
  )

  COMBINED_IMPORT_REGEX=""
  for pat in "${IMPORT_PATTERNS[@]}"; do
    if [ -z "$COMBINED_IMPORT_REGEX" ]; then
      COMBINED_IMPORT_REGEX="$pat"
    else
      COMBINED_IMPORT_REGEX="$COMBINED_IMPORT_REGEX|$pat"
    fi
  done

  IMPORT_TMP=$(mktemp)
  # REUSE: QD7:160-163 — single grep scan approach
  grep -rEn -e "$COMBINED_IMPORT_REGEX" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --exclude-dir=node_modules --exclude-dir=.git \
    --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$IMPORT_TMP" || true

  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    echo "$file" | grep -qE "$EXCLUDE_PATTERN" && continue

    IS_CONSUMER_FILE="false"
    echo "$file" | grep -qi "$consumer_dir_hint" && IS_CONSUMER_FILE="true"

    IMPORT_FOUND="true"
    FINDINGS_COUNT=$((FINDINGS_COUNT + 1))

    # Escape match for JSON (REUSE: QD7:196 snippet pattern)
    MATCH_SNIPPET=$(echo "$match" | head -c 120 | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')

    printf '{"type":"import_found","file":"%s","line":%s,"match":"%s","is_consumer_file":%s}\n' \
      "$file" "$line" "$MATCH_SNIPPET" "$IS_CONSUMER_FILE" >> "$FINDINGS_TMP"

  done < "$IMPORT_TMP"
  rm -f "$IMPORT_TMP"
fi

# ============================================================
# Step 2: Kiem tra field references trong consumer code
# (Required fields check — intermediate results for probe main loop)
# ============================================================
# (Field checks happen in main probe procedure loop — this helper
#  focuses on import discovery and deprecated detection)

# ============================================================
# Step 3: Tim deprecated imports (khi --check-deprecated)
# Reuse: QD7 deprecated detection approach (wf-fix-probe-static-deprecated.sh:279-309)
# Detect: @deprecated annotation, Old*/Legacy*/V1* prefix patterns
# ============================================================
if $CHECK_DEPRECATED && [ -d "$SOURCE_DIR" ]; then
  # Deprecated patterns cho entity
  # REUSE: QD7 DEPRECATED_PACKAGES logic + PATTERNS approach (QD7:61-97)
  DEP_PATTERNS=(
    "@deprecated.*${ENTITY}"
    "import[[:space:]].*Old${ENTITY}[[:space:]]*from"
    "import[[:space:]].*Legacy${ENTITY}[[:space:]]*from"
    "import[[:space:]].*Deprecated${ENTITY}[[:space:]]*from"
    "import[[:space:]].*V1${ENTITY}[[:space:]]*from"
    "import[[:space:]].*${ENTITY}V1[[:space:]]*from"
    "@Deprecated.*${ENTITY}"
  )

  # Build combined (REUSE: QD7:149-155 combined regex builder)
  DEPRECATED_COMBINED=""
  for pat in "${DEP_PATTERNS[@]}"; do
    if [ -z "$DEPRECATED_COMBINED" ]; then
      DEPRECATED_COMBINED="$pat"
    else
      DEPRECATED_COMBINED="$DEPRECATED_COMBINED|$pat"
    fi
  done

  DEP_TMP=$(mktemp)
  # REUSE: QD7:160-163 single grep scan
  grep -rEn -e "$DEPRECATED_COMBINED" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --exclude-dir=node_modules --exclude-dir=.git \
    --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$DEP_TMP" || true

  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    echo "$file" | grep -qE "$EXCLUDE_PATTERN" && continue

    DEPRECATED_FOUND="true"
    FINDINGS_COUNT=$((FINDINGS_COUNT + 1))

    MATCH_SNIPPET=$(echo "$match" | head -c 120 | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')

    printf '{"type":"deprecated_import_found","file":"%s","line":%s,"match":"%s"}\n' \
      "$file" "$line" "$MATCH_SNIPPET" >> "$FINDINGS_TMP"

  done < "$DEP_TMP"
  rm -f "$DEP_TMP"
fi

# ============================================================
# Build JSON output (REUSE: QD7 output structure pattern)
# ============================================================
# Slurp findings from FINDINGS_TMP into array (REUSE: QD7:466-473 --slurpfile approach)
FINDINGS_ARRAY=$(jq -s '.' "$FINDINGS_TMP" 2>/dev/null || echo "[]")

OUTPUT=$(jq -n \
  --arg probe_id "P-QD10-cross-module-ref-static" \
  --arg consumer "$CONSUMER_MODULE" \
  --arg provider "$PROVIDER_MODULE" \
  --arg entity "$ENTITY" \
  --arg source_dir "$SOURCE_DIR" \
  --argjson import_found "$IMPORT_FOUND" \
  --argjson deprecated_found "$DEPRECATED_FOUND" \
  --argjson findings_count "$FINDINGS_COUNT" \
  --argjson findings "$FINDINGS_ARRAY" \
  --arg now "$(iso_now)" \
  '{
    "probe_id": $probe_id,
    "consumer_module": $consumer,
    "provider_module": $provider,
    "entity": $entity,
    "source_dir": $source_dir,
    "import_found": $import_found,
    "deprecated_found": $deprecated_found,
    "findings_count": $findings_count,
    "findings": $findings,
    "checked_at": $now
  }')

if [ -n "$OUTPUT_FILE" ]; then
  echo "$OUTPUT" > "$OUTPUT_FILE"
else
  echo "$OUTPUT"
fi

exit 0
