#!/bin/bash
# ============================================
# Hook: validate-naming-convention.sh
# Purpose: Validate module/system naming convention in legacy pipeline output
# Trigger: PostToolUse (Write|Edit)
# CORE Rules: CORE-016, CORE-017
#
# Chiến lược 2 tầng:
# - Tầng 1 (per-file): Validate CHỈ file vừa write
# - Tầng 2 (full-tree): Validate toàn bộ legacy pipeline output
# ============================================

set -euo pipefail

source "$(dirname "$0")/_hook-utils.sh"
JQ_BIN=$(hook_resolve_jq || true)
TIER=$(hook_detect_tier_mode)

# ============================================
# DEPENDENCY CHECK
# ============================================

if [[ -z "$JQ_BIN" ]]; then
  exit 0
fi

# ============================================
# INPUT PARSING
# ============================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.file_path // empty' 2>/dev/null || true)
FILE_PATH=$(hook_normalize_path "$FILE_PATH")

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# ============================================
# SCOPE: chi validate files trong legacy pipeline
# LIMITATION: CORE-016/017 áp dụng cho mọi naming, nhưng hook này chỉ
# validate legacy pipeline output (classified/, extracted/, req-registry.json).
# phase2-features/ file naming được validate bởi skill PRE-GATE thay vì hook.
# ============================================

CLASSIFIED_DIR=".mc-data/work/legacy-scan/classified/"
EXTRACTED_DIR=".mc-data/work/legacy-scan/extracted/"
REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"

IS_PIPELINE_FILE=false
FILE_TYPE=""

if [[ "$FILE_PATH" == *"$CLASSIFIED_DIR"*"batch-"*".json" ]]; then
  IS_PIPELINE_FILE=true
  FILE_TYPE="classified"
elif [[ "$FILE_PATH" == *"$EXTRACTED_DIR"*".json" && "$FILE_PATH" != *"dedup-report"* && "$FILE_PATH" != *"divergences"* && "$FILE_PATH" != *"module-name-normalization"* ]]; then
  IS_PIPELINE_FILE=true
  FILE_TYPE="extracted"
elif [[ "$FILE_PATH" == *"$REGISTRY_PATH"* || "$FILE_PATH" == *"req-registry.json" ]]; then
  IS_PIPELINE_FILE=true
  FILE_TYPE="registry"
fi

if [[ "$IS_PIPELINE_FILE" == false ]]; then
  exit 0
fi

# ============================================
# NAMING CONVENTION: lowercase-kebab-case
# ============================================

KEBAB_CASE_REGEX='^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
VIOLATIONS=()

validate_name() {
  local name="$1"
  local context="$2"
  if [[ -z "$name" || "$name" == "null" ]]; then
    return
  fi
  if ! echo "$name" | grep -qE "$KEBAB_CASE_REGEX"; then
    VIOLATIONS+=("$context: '$name' khong phai lowercase-kebab-case")
  fi
}

# ============================================
# VALIDATION BY FILE TYPE
# ============================================

case "$FILE_TYPE" in
  classified)
    if [[ -f "$FILE_PATH" ]]; then
      SYSTEMS=$("$JQ_BIN" -r '.items[]?.system // empty' "$FILE_PATH" 2>/dev/null | sort -u || true)
      for sys in $SYSTEMS; do
        validate_name "$sys" "classified.system"
      done

      MODULES=$("$JQ_BIN" -r '.items[]?.module // empty' "$FILE_PATH" 2>/dev/null | sort -u || true)
      for mod in $MODULES; do
        validate_name "$mod" "classified.module"
      done
    fi
    ;;

  extracted)
    if [[ -f "$FILE_PATH" ]]; then
      MOD=$("$JQ_BIN" -r '.module // empty' "$FILE_PATH" 2>/dev/null || true)
      validate_name "$MOD" "extracted.module"

      SYS=$("$JQ_BIN" -r '.system // empty' "$FILE_PATH" 2>/dev/null || true)
      validate_name "$SYS" "extracted.system"

      BASENAME=$(basename "$FILE_PATH" .json)
      validate_name "$BASENAME" "extracted.filename"
    fi
    ;;

  registry)
    if [[ -f "$FILE_PATH" ]]; then
      SYSTEM_NAMES=$("$JQ_BIN" -r '.systems[]?.name // empty' "$FILE_PATH" 2>/dev/null | sort -u || true)
      for name in $SYSTEM_NAMES; do
        validate_name "$name" "registry.system"
      done

      MODULE_IDS=$("$JQ_BIN" -r '.modules[]?.id // empty' "$FILE_PATH" 2>/dev/null | sort -u || true)
      SYSTEM_IDS=$("$JQ_BIN" -r '.systems[]?.id // empty' "$FILE_PATH" 2>/dev/null | sort -u || true)
      LOWER_IDS=$(echo "$SYSTEM_IDS" | tr '[:upper:]' '[:lower:]' | sort)
      UNIQUE_LOWER=$(echo "$LOWER_IDS" | sort -u)
      if [[ "$LOWER_IDS" != "$UNIQUE_LOWER" ]]; then
        VIOLATIONS+=("registry: co duplicate system IDs (case-insensitive)")
      fi

      MODULE_IDS_ALL=$("$JQ_BIN" -r '.modules[]?.id // empty' "$FILE_PATH" 2>/dev/null | sort || true)
      LOWER_MODS=$(echo "$MODULE_IDS_ALL" | tr '[:upper:]' '[:lower:]' | sort)
      UNIQUE_LOWER_MODS=$(echo "$LOWER_MODS" | sort -u)
      if [[ "$LOWER_MODS" != "$UNIQUE_LOWER_MODS" ]]; then
        VIOLATIONS+=("registry: co duplicate module IDs (case-insensitive)")
      fi
    fi
    ;;
esac

# ============================================
# OUTPUT (with Tier info)
# ============================================

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo "" >&2
  echo "====================================================" >&2
  echo "WARNING DEVKIT Naming Convention Warning (CORE-016/017) [Tier $TIER]" >&2
  echo "====================================================" >&2
  echo "" >&2
  echo "File: $FILE_PATH" >&2
  echo "" >&2
  echo "Naming violations:" >&2
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v" >&2
  done
  echo "" >&2
  echo "Convention: lowercase-kebab-case (vd: order-management)" >&2
  echo "====================================================" >&2
  echo "" >&2
fi

hook_append_metric "validate-naming-convention" "completed" "legacy-pipeline" "$FILE_PATH" "${#VIOLATIONS[@]}" "$TIER"

exit 0
