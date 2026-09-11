#!/bin/bash
# validate-critical-decision.sh — PreToolUse hook (Write | Edit)
set -euo pipefail
source "${BASH_SOURCE%/*}/_hook-utils.sh"
# CDG-02 WARNING-only: log when overwriting file with content.
# Confirmation logic lies in skill (§6.1b), not in this hook.
# Hook always exits 0 (allow).

JQ_BIN=$(hook_resolve_jq || true)

# Extract target file path from hook input JSON via stdin
TARGET_FILE=""

INPUT=$(cat)

if [[ -n "$JQ_BIN" ]]; then
  TARGET_FILE=$(echo "$INPUT" | "$JQ_BIN" -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  # Fallback: grep-based parsing when jq unavailable
  while IFS= read -r line; do
    if echo "$line" | grep -q '"file_path"'; then
      TARGET_FILE=$(echo "$line" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\(.*\)"/\1/')
    fi
  done <<< "$INPUT"
fi

# Fallback: check environment variable if available
if [ -z "$TARGET_FILE" ] && [ -n "$CLAUDE_FILE_PATH" ]; then
  TARGET_FILE="$CLAUDE_FILE_PATH"
fi

# Nothing to check if no file path found
if [ -z "$TARGET_FILE" ]; then
  exit 0
fi

# 1. Detect: File exists AND has content? (test -s: size > 0 bytes)
if test -s "$TARGET_FILE"; then
  # 2. Check whitelist: files in .mc-data/work/ are free to overwrite
  if [[ "$TARGET_FILE" == *.mc-data/work/* ]]; then
    exit 0  # allow silently
  fi

  # 3. Log WARNING (do not block) — skill logic handles CDG confirmation
  echo "⚠️ WARNING (CDG-02): File \"$TARGET_FILE\" đã có nội dung. Skill nên hỏi user trước khi overwrite (§16 CDG-02)."
fi

# Hook always exits 0 (allow) — confirmation is skill's responsibility
exit 0
