#!/bin/bash
# ============================================
# Hook: validate-ui-component.sh
# Purpose: Kiem tra UI files tuan thu design system rules
# Trigger: PostToolUse (Write|Edit) on UI files
# Version: 1.0.0
# Last Updated: 2026-04-02
#
# Chiến lược 2 tầng:
# - Tầng 1 (per-file): Validate CHỈ file UI vừa write — nhanh
# - Tầng 2 (full-tree): Validate toàn bộ UI consistency — chậm
# ============================================

set -euo pipefail

source "$(dirname "$0")/_hook-utils.sh"
JQ_BIN=$(hook_resolve_jq || true)
TIER=$(hook_detect_tier_mode)

# ============================================
# DEPENDENCY CHECK
# ============================================

if [[ -z "$JQ_BIN" ]]; then
  echo "WARNING DEVKIT Hook: 'jq' not found. Skipping UI validation." >&2
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
# UI FILE DETECTION
# ============================================

UI_EXTENSIONS=(".tsx" ".jsx" ".vue" ".svelte" ".html" ".css" ".scss" ".less")

IS_UI_FILE=false
for ext in "${UI_EXTENSIONS[@]}"; do
  if [[ "$FILE_PATH" == *"$ext" ]]; then
    IS_UI_FILE=true
    break
  fi
done

if [[ "$IS_UI_FILE" == false ]]; then
  exit 0
fi

if [[ "$FILE_PATH" == *".test."* ]] || [[ "$FILE_PATH" == *".spec."* ]] || [[ "$FILE_PATH" == *"__tests__"* ]]; then
  exit 0
fi

if [[ "$FILE_PATH" == *"tailwind.config"* ]] || [[ "$FILE_PATH" == *"next.config"* ]]; then
  exit 0
fi

# ============================================
# UI QUALITY CHECKS
# ============================================

WARNINGS=()
ERRORS=()

EMOJI_LIST=(🎨 🚀 ✨ 💡 ⚡ 🔧 🎯 📊 💰 🏠 📱 💻 ⭐ 🎉 🔥 ❤️ ✅ ❌ ⚠️ 🗑️ ✏️ 📝 🔍 📢 💬 🔔 📦 🛠️ ⚙️ 🔐 📋 📌 🏷️ 📁 🖼️ 🎬)
HAS_EMOJI=false
for emoji in "${EMOJI_LIST[@]}"; do
  if echo "$CONTENT" | grep -qF "$emoji" 2>/dev/null; then
    HAS_EMOJI=true
    break
  fi
done
if [[ "$HAS_EMOJI" == true ]]; then
  ERRORS+=("Emoji used as icon. Use SVG icons (Heroicons/Lucide/Simple Icons) instead.")
fi

if echo "$CONTENT" | grep -qE 'onClick|@click|v-on:click|on:click|handleClick'; then
  if ! echo "$CONTENT" | grep -qE 'cursor-pointer|cursor: pointer'; then
    WARNINGS+=("Interactive element may need 'cursor-pointer' class.")
  fi
fi

if echo "$CONTENT" | grep -qE '#[0-9a-fA-F]{6}'; then
  CONTENT_NO_COMMENTS=$(echo "$CONTENT" | sed 's|//.*||g' | sed 's|/\*.*\*/||g')
  if echo "$CONTENT_NO_COMMENTS" | grep -qE '#[0-9a-fA-F]{6}'; then
    WARNINGS+=("Hardcoded hex color detected. Consider using design system variables.")
  fi
fi

if echo "$CONTENT" | grep -qE 'transition-none|duration-0|transition:\s*none'; then
  WARNINGS+=("Instant transition detected. Use 150-300ms for smooth UX.")
fi

if echo "$CONTENT" | grep -qE 'hover:scale-[2-9]|hover:scale-1[0-9]'; then
  WARNINGS+=("Scale transform on hover may cause layout shift. Consider alternative effects.")
fi

if echo "$CONTENT" | grep -qE '<img[^>]*>'; then
  if ! echo "$CONTENT" | grep -qE '<img[^>]*alt='; then
    WARNINGS+=("Image element missing 'alt' attribute for accessibility.")
  fi
fi

if echo "$CONTENT" | grep -qE '<input[^>]*type="text"'; then
  if ! echo "$CONTENT" | grep -qE 'aria-label|<label|htmlFor'; then
    WARNINGS+=("Input may need associated label or aria-label for accessibility.")
  fi
fi

if echo "$CONTENT" | grep -qE 'bg-white/10|bg-white\/10|bg-black/10|bg-black\/10'; then
  WARNINGS+=("Low opacity glass effect may be invisible in light mode. Use bg-white/80 minimum.")
fi

if echo "$CONTENT" | grep -qE 'text-gray-3[0-9]{2}|text-slate-3[0-9]{2}|text-zinc-3[0-9]{2}'; then
  WARNINGS+=("Light gray text may have insufficient contrast. Ensure 4.5:1 ratio minimum.")
fi

# ============================================
# OUTPUT RESULTS
# ============================================

TOTAL_ISSUES=$((${#WARNINGS[@]} + ${#ERRORS[@]}))

if [[ $TOTAL_ISSUES -gt 0 ]]; then
  echo "" >&2
  echo "====================================================" >&2
  echo "UI/UX Quality Check [Tier $TIER]" >&2
  echo "====================================================" >&2
  echo "" >&2
  echo "File: $FILE_PATH" >&2
  echo "" >&2

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "ERRORS (${#ERRORS[@]}):" >&2
    for error in "${ERRORS[@]}"; do
      echo "  - $error" >&2
    done
    echo "" >&2
  fi

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "WARNINGS (${#WARNINGS[@]}):" >&2
    for warning in "${WARNINGS[@]}"; do
      echo "  - $warning" >&2
    done
    echo "" >&2
  fi

  echo "====================================================" >&2
  echo "Design System: .mc-data/docs/phase4-ux/design-system.md" >&2
  echo "====================================================" >&2
  echo "" >&2
fi

hook_append_metric "validate-ui-component" "completed" "ui-validation" "$FILE_PATH" "$TOTAL_ISSUES" "$TIER"

exit 0
