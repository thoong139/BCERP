#!/usr/bin/env bash
# scout-block.sh — Block agent access to heavy directories
# Triggered: PreToolUse[Glob]
# Exit 2 = block (STDERR message to LLM)
# Exit 0 = allow
# Blocked dirs: node_modules/, __pycache__/, .git/, dist/, build/, .next/, etc.
# Configurable via .claude/.mcignore

set -euo pipefail

HOOK_NAME="scout-block"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_hook-utils.sh
source "$SCRIPT_DIR/_hook-utils.sh"

_start=$(hook_timer_start)

# --- Read tool input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)"
GLOB_PATTERN="$(echo "$INPUT" | jq -r '.tool_input.pattern // ""' 2>/dev/null || true)"
GLOB_PATH="$(echo "$INPUT" | jq -r '.tool_input.path // ""' 2>/dev/null || true)"

# Only act on Glob tool
if [[ "$TOOL_NAME" != "Glob" ]]; then
  hook_log_jsonl "$HOOK_NAME" "skip" "$TOOL_NAME" "" "not-glob" "$(hook_timer_end "$_start")" 0 ""
  exit 0
fi

COMBINED="${GLOB_PATH}/${GLOB_PATTERN}"
COMBINED="$(hook_normalize_path "$COMBINED")"

# --- Load blocked dirs from .mcignore ---
MCIGNORE_FILE=".claude/.mcignore"
BLOCKED_DIRS=()

if [[ -f "$MCIGNORE_FILE" ]]; then
  while IFS= read -r line; do
    line="${line%$'\r'}" # Strip trailing CR (Windows CRLF)
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    BLOCKED_DIRS+=("$line")
  done < "$MCIGNORE_FILE"
else
  # Fallback defaults
  BLOCKED_DIRS=(node_modules __pycache__ .git dist build .next .nuxt vendor)
fi

# --- Check if pattern targets a blocked directory ---
is_blocked() {
  local pattern="$1"
  local dir
  for dir in "${BLOCKED_DIRS[@]}"; do
    # Match if pattern starts with or contains the blocked dir
    if [[ "$pattern" == "${dir}/"* ]] || \
       [[ "$pattern" == *"/${dir}/"* ]] || \
       [[ "$pattern" == *"/${dir}" ]] || \
       [[ "$pattern" == "${dir}" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

if [[ -z "$GLOB_PATTERN" && -z "$GLOB_PATH" ]]; then
  hook_log_jsonl "$HOOK_NAME" "skip" "$TOOL_NAME" "" "no-pattern" "$(hook_timer_end "$_start")" 0 ""
  exit 0
fi

BLOCKED_BY="$(is_blocked "$COMBINED" || is_blocked "$GLOB_PATTERN" || true)"

if [[ -n "$BLOCKED_BY" ]]; then
  echo "scout-block: Glob pattern targets heavy directory '$BLOCKED_BY'. Use a more specific path to avoid token waste. Add exceptions to .claude/.mcignore." >&2
  hook_log_jsonl "$HOOK_NAME" "block" "$TOOL_NAME" "$COMBINED" "blocked:$BLOCKED_BY" "$(hook_timer_end "$_start")" 2 ""
  exit 2
fi

hook_log_jsonl "$HOOK_NAME" "allow" "$TOOL_NAME" "$COMBINED" "ok" "$(hook_timer_end "$_start")" 0 ""
exit 0
