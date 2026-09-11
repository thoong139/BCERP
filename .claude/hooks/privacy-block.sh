#!/usr/bin/env bash
# privacy-block.sh — Warn on sensitive file access
# Triggered: PreToolUse[Read]
# Behavior: exit 2 (block) for sensitive files — stderr message shown to Claude
#           fail-open (exit 0) on errors or unexpected input
# Blocked patterns: .env*, credentials*, secrets*, *.pem, *.key, id_rsa, id_ed25519
# Exempt: .env.example, .env.sample, .env.template
# Exempt paths: .mc-data/**, .claude/**

set -euo pipefail

HOOK_NAME="privacy-block"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_hook-utils.sh
source "$SCRIPT_DIR/_hook-utils.sh"

_start=$(hook_timer_start)

# --- Read tool input from stdin ---
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
FILE_PATH="$(hook_normalize_path "$FILE_PATH")"

# Only act on Read tool
if [[ "$TOOL_NAME" != "Read" ]]; then
  hook_log_jsonl "$HOOK_NAME" "skip" "$TOOL_NAME" "" "not-read-tool" "$(hook_timer_end "$_start")" 0 ""
  exit 0
fi

# --- Exempt paths ---
is_exempt() {
  local fp="$1"
  # Exempt: .mc-data/, .claude/
  [[ "$fp" == .mc-data/* ]] && return 0
  [[ "$fp" == */.mc-data/* ]] && return 0
  [[ "$fp" == .claude/* ]] && return 0
  [[ "$fp" == */.claude/* ]] && return 0
  return 1
}

# --- Exempt filenames ---
is_exempt_filename() {
  local basename
  basename="$(basename "$1")"
  [[ "$basename" == ".env.example" ]] && return 0
  [[ "$basename" == ".env.sample" ]] && return 0
  [[ "$basename" == ".env.template" ]] && return 0
  return 1
}

# --- Sensitive patterns ---
is_sensitive() {
  local fp="$1"
  local basename
  basename="$(basename "$fp")"

  # .env and variants (but not .env.example etc.)
  if [[ "$basename" == ".env" ]] || [[ "$basename" == .env.* ]]; then
    is_exempt_filename "$fp" && return 1
    return 0
  fi

  # credentials*, secrets*
  [[ "$basename" == credentials* ]] && return 0
  [[ "$basename" == secrets* ]] && return 0

  # *.pem, *.key
  [[ "$basename" == *.pem ]] && return 0
  [[ "$basename" == *.key ]] && return 0

  # SSH private keys
  [[ "$basename" == "id_rsa" ]] && return 0
  [[ "$basename" == "id_ed25519" ]] && return 0
  [[ "$basename" == "id_dsa" ]] && return 0
  [[ "$basename" == "id_ecdsa" ]] && return 0

  return 1
}

# --- Main logic ---
if [[ -z "$FILE_PATH" ]]; then
  hook_log_jsonl "$HOOK_NAME" "skip" "$TOOL_NAME" "" "no-path" "$(hook_timer_end "$_start")" 0 ""
  exit 0
fi

if is_exempt "$FILE_PATH"; then
  hook_log_jsonl "$HOOK_NAME" "exempt" "$TOOL_NAME" "$FILE_PATH" "exempt-path" "$(hook_timer_end "$_start")" 0 ""
  exit 0
fi

if is_sensitive "$FILE_PATH"; then
  # Block access — exit 2 tells Claude Code to block the tool call
  # stderr message is shown to Claude as the reason
  BASENAME="$(basename "$FILE_PATH")"
  echo "BLOCKED: '$BASENAME' may contain sensitive data (credentials, keys, secrets). Skipping read to protect privacy. If you need this file, ask the user to provide the relevant content directly." >&2
  hook_log_jsonl "$HOOK_NAME" "block" "$TOOL_NAME" "$FILE_PATH" "sensitive-file" "$(hook_timer_end "$_start")" 2 ""
  exit 2
fi

hook_log_jsonl "$HOOK_NAME" "allow" "$TOOL_NAME" "$FILE_PATH" "ok" "$(hook_timer_end "$_start")" 0 ""
exit 0
