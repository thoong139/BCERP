#!/bin/bash
# ============================================
# Hook: validate-contract-sync.sh
# Purpose: Validate contract consistency sau moi write
# Trigger: PostToolUse (Write|Edit)
#
# Chiến lược 2 tầng:
# - Tầng 1 (per-file): Validate file vừa write, check incremental consistency
#   Check: REQ-ID trong file vs registry, file structure validation
#   Thời gian: ~ 0.5-1s
#
# - Tầng 2 (full-tree): Validate toàn bộ project, cross-file consistency
#   Check: Tất cả REQ-IDs, modules, design integrity
#   Thời gian: ~ 3-10s
#   Trigger: Tại phase boundaries (MCV3_PHASE_BOUNDARY=true)
# ============================================

set -euo pipefail

source "$(dirname "$0")/_hook-utils.sh"
JQ_BIN=$(hook_resolve_jq || true)
TIER=$(hook_detect_tier_mode)

# ============================================
# DEPENDENCY CHECK
# ============================================

if [[ -z "$JQ_BIN" ]]; then
  echo "WARNING DEVKIT Hook: 'jq' not found. Skipping contract validation." >&2
  exit 0
fi

REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
ISSUES=0

# Skip neu registry chua duoc khoi tao
if [ ! -f "$REGISTRY_FILE" ]; then
  hook_append_metric "validate-contract-sync" "skipped" "missing-registry" "" 0 "$TIER"
  exit 0
fi

# ============================================
# INPUT PARSING
# ============================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.file_path // empty' 2>/dev/null || true)
CONTENT=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null || true)
FILE_PATH=$(hook_normalize_path "$FILE_PATH")

CHECK_MODE="skip"
IS_INCREMENTAL_DOC=false

case "$FILE_PATH" in
  *"/.mc-data/docs/phase2-features/"*.md|".mc-data/docs/phase2-features/"*.md|*"/.mc-data/docs/phase3-architecture/"*.md|".mc-data/docs/phase3-architecture/"*.md)
    IS_INCREMENTAL_DOC=true
    CHECK_MODE="incremental-doc"
    ;;
  "")
    # Nếu FILE_PATH rỗng → full-tree scan, chỉ khi Tier 2
    if [[ "$TIER" == "2" ]]; then
      CHECK_MODE="full-tree-scan"
    else
      hook_append_metric "validate-contract-sync" "skipped" "tier-1-skip-full-scan" "$FILE_PATH" 0 "$TIER"
      exit 0
    fi
    ;;
  *)
    hook_append_metric "validate-contract-sync" "skipped" "out-of-scope" "$FILE_PATH" 0 "$TIER"
    exit 0
    ;;
esac

# ============================================
# TIER 1 vs TIER 2 ROUTING
# ============================================

if [[ "$TIER" == "1" && "$CHECK_MODE" == "full-tree-scan" ]]; then
  # Tier 1 không chạy full-tree scans
  hook_append_metric "validate-contract-sync" "skipped" "tier-1-skip-full-scan" "$FILE_PATH" 0 "1"
  exit 0
fi

if [[ "$TIER" == "2" && "$CHECK_MODE" == "incremental-doc" ]]; then
  # Tier 2 nâng cấp incremental lên full-tree khi tại phase boundary
  CHECK_MODE="full-tree-scan"
fi

# ============================================
# CHECK 1: REQ-ID trong docs co trong registry khong?
# ============================================

if [[ "$IS_INCREMENTAL_DOC" == true || "$CHECK_MODE" == "full-tree-scan" ]]; then
  if [[ "$TIER" == "1" ]]; then
    echo "[Tier 1] Checking REQ-ID in file: $FILE_PATH" >&2
  else
    echo "[Tier 2] Checking REQ-ID registry consistency (full-tree)..." >&2
  fi

  # TODO: Detect status: stub → skip/downgrade check (wf-fix-bugs v1.8.0 compatibility)
  # Stub docs từ /wf-fix-bugs --deep có thể chứa REQ-IDs chưa có trong registry,
  # gây false warnings. Khi triển khai: check frontmatter "status: stub" → skip file.
  if [[ "$IS_INCREMENTAL_DOC" == true ]]; then
    if [[ -f "$FILE_PATH" ]]; then
      MARKDOWN_REQ_IDS=$(grep -hoE "REQ-([A-Z]{1,10}-)*[0-9]{3}" "$FILE_PATH" 2>/dev/null | sort -u || true)
    elif [[ -n "$CONTENT" ]]; then
      MARKDOWN_REQ_IDS=$(echo "$CONTENT" | grep -oE "REQ-([A-Z]{1,10}-)*[0-9]{3}" | sort -u || true)
    else
      MARKDOWN_REQ_IDS=""
    fi
  else
    # Full-tree scan: check tất cả phase2 + phase3 files (cross-platform: use find instead of grep --include)
    MARKDOWN_REQ_IDS=$(find .mc-data/docs/phase2-features/ .mc-data/docs/phase3-architecture/ -name "*.md" -exec grep -hoE "REQ-([A-Z]{1,10}-)*[0-9]{3}" {} + 2>/dev/null | sort -u || true)
  fi

  REGISTRY_REQ_IDS=$("$JQ_BIN" -r '.requirements[]?.id // empty' "$REGISTRY_FILE" 2>/dev/null | sort -u || true)

  if [ -n "$MARKDOWN_REQ_IDS" ] && [ -n "$REGISTRY_REQ_IDS" ]; then
    MARKDOWN_CLEAN=$(echo "$MARKDOWN_REQ_IDS" | tr -d '\r')
    REGISTRY_CLEAN=$(echo "$REGISTRY_REQ_IDS" | tr -d '\r')
    DIFF=$(comm -23 <(echo "$MARKDOWN_CLEAN") <(echo "$REGISTRY_CLEAN"))

    if [ -n "$DIFF" ]; then
      echo "WARNING: Cac REQ-ID sau co trong docs nhung CHUA duoc dang ky vao req-registry.json:" >&2
      echo "$DIFF" | while read -r id; do
        echo "   - $id" >&2
      done
      ISSUES=$((ISSUES + 1))
    fi
  fi
fi

# ============================================
# SUMMARY
# ============================================

if [ $ISSUES -gt 0 ]; then
  echo "" >&2
  echo "WARNING: $ISSUES contract issue(s) phat hien." >&2
  if [[ "$TIER" == "1" ]]; then
    echo "AI MUST fix: cap nhat file hoac req-registry.json de dong bo." >&2
  else
    echo "AI MUST fix: chay lai skill hoac cap nhat req-registry.json de dong bo." >&2
  fi
else
  if [[ "$TIER" == "1" ]]; then
    echo "[Tier 1] File contract check OK" >&2
  else
    echo "[Tier 2] All contracts consistent (full-tree)" >&2
  fi
fi

hook_append_metric "validate-contract-sync" "completed" "$CHECK_MODE" "$FILE_PATH" "$ISSUES" "$TIER"

exit 0
