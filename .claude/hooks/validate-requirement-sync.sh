#!/bin/bash
# ============================================
# Hook: validate-requirement-sync.sh
# Purpose: Kiem tra code changes co reference den requirement
# Trigger: PreToolUse (Write|Edit)
#
# Chiến lược 2 tầng:
# - Tầng 1 (per-file): Validate CHỈ file vừa write — nhanh (~0.5s)
#   Check: REQ-ID presence, basic validation
# - Tầng 2 (full-tree): Validate toàn project — chậm (~3-10s)
#   Chỉ chạy tại phase boundaries
# ============================================

set -euo pipefail

source "$(dirname "$0")/_hook-utils.sh"
JQ_BIN=$(hook_resolve_jq || true)
TIER=$(hook_detect_tier_mode)

# ============================================
# DEPENDENCY CHECK
# ============================================

if [[ -z "$JQ_BIN" ]]; then
  echo "WARNING DEVKIT Hook: 'jq' not found. Skipping REQ-ID validation." >&2
  echo "Install: brew install jq (macOS) or choco install jq (Windows)" >&2
  exit 0
fi

# ============================================
# INPUT PARSING
# ============================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.file_path // empty' 2>/dev/null || true)
CONTENT=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null || true)
FILE_PATH=$(hook_normalize_path "$FILE_PATH")

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# ============================================
# FILE TYPE FILTERING
# ============================================

SKIP_PATTERNS=(
  ".mc-data/"
  "node_modules/"
  "dist/"
  "build/"
  "bin/"
  "obj/"
  ".test."
  ".spec."
  "__tests__/"
)

for pattern in "${SKIP_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    exit 0
  fi
done

SKIP_EXTENSIONS=(
  ".md" ".json" ".yaml" ".yml" ".xml"
  ".lock" ".log" ".env" ".example"
  ".css" ".scss" ".less" ".sass"
  ".svg" ".png" ".jpg" ".jpeg" ".gif" ".ico"
)

for ext in "${SKIP_EXTENSIONS[@]}"; do
  if [[ "$FILE_PATH" == *"$ext" ]]; then
    exit 0
  fi
done

# ============================================
# CODE FILE DETECTION
# ============================================

CODE_EXTENSIONS=(
  ".ts" ".tsx" ".js" ".jsx"
  ".py" ".java" ".cs" ".razor"
  ".go" ".rs" ".rb" ".php"
  ".swift" ".kt" ".scala"
)

IS_CODE_FILE=false
for ext in "${CODE_EXTENSIONS[@]}"; do
  if [[ "$FILE_PATH" == *"$ext" ]]; then
    IS_CODE_FILE=true
    break
  fi
done

if [[ "$IS_CODE_FILE" == false ]]; then
  exit 0
fi

# ============================================
# REQ-ID VALIDATION
# ============================================

REQ_PATTERNS=(
  "REQ-[A-Z]{1,10}-[A-Z]{1,10}-[A-Z]{1,10}-[0-9]{3}"
  "REQ-[A-Z]{1,10}-[A-Z]{1,10}-[0-9]{3}"
  "REQ-[A-Z]{1,10}-[0-9]{3}"
  "REQ-[0-9]{3}"
  "req-id"
  "reqId"
  "@req-id"
  "REQ_ID"
)

for pattern in "${REQ_PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -qiE "$pattern"; then
    exit 0
  fi
done

if [[ -f "$FILE_PATH" ]]; then
  for pattern in "${REQ_PATTERNS[@]}"; do
    if grep -qiE "$pattern" "$FILE_PATH" 2>/dev/null; then
      exit 0
    fi
  done
fi

# ============================================
# TIER 1 VALIDATION (per-file) — Luôn chạy
# ============================================

# Ghi metric
hook_append_metric "validate-requirement-sync" "completed" "tier-1-per-file" "$FILE_PATH" 0 "1"

# Chỉ hiển thị warning nếu Tier 1 phát hiện issue
EXT="${FILE_PATH##*.}"
case "$EXT" in
  ts|tsx|js|jsx)
    COMMENT_EXAMPLE="// REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE="/** @req-id REQ-FIN-001 */"
    ;;
  py)
    COMMENT_EXAMPLE="# REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE="# @req-id REQ-FIN-001"
    ;;
  cs|razor)
    COMMENT_EXAMPLE="// REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE='[Description("REQ-FIN-001")]'
    ;;
  java)
    COMMENT_EXAMPLE="// REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE="/** @req-id REQ-FIN-001 */"
    ;;
  go|rs)
    COMMENT_EXAMPLE="// REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE="// REQ-ID: REQ-FIN-001"
    ;;
  *)
    COMMENT_EXAMPLE="// REQ-ID: REQ-FIN-001"
    DOC_EXAMPLE=""
    ;;
esac

echo "" >&2
echo "====================================================" >&2
echo "WARNING DEVKIT Sync Warning (Tier 1)" >&2
echo "====================================================" >&2
echo "" >&2
echo "File: $FILE_PATH" >&2
echo "" >&2
echo "Code should reference a requirement ID (REQ-XXX-NNN)." >&2
echo "" >&2
echo "Examples for .$EXT files:" >&2
echo "  $COMMENT_EXAMPLE" >&2
if [[ -n "$DOC_EXAMPLE" ]]; then
  echo "  $DOC_EXAMPLE" >&2
fi
echo "" >&2
echo "REQ-ID Formats:" >&2
echo "  REQ-001           - Simple" >&2
echo "  REQ-FIN-001       - With system prefix" >&2
echo "  REQ-FIN-NFR-001   - Non-functional requirement" >&2
echo "  REQ-CRM-INT-001   - Integration requirement" >&2
echo "" >&2
echo "Run '/wf-verify-sync' to check overall sync status." >&2
echo "====================================================" >&2
echo "" >&2

exit 0
