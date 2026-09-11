#!/usr/bin/env bash
# mc-common.sh — Shared helpers cho wf-manage-change scripts
# Sprint 1 — Version 1.0 (v3.0.0)
#
# Usage:
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/mc-common.sh"
#   _SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
#
# Cross-platform: Windows Git Bash + WSL + Linux + macOS.

# Guard: không source lại 2 lần
if [[ -n "${_MC_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly MC_COMMON_VERSION="1.0"

readonly MC_ROOT=".mc-data/work/wf-manage-change"
readonly MC_INDEX="$MC_ROOT/_index/sessions.jsonl"
readonly MC_LOCKS_DIR="$MC_ROOT/.locks"

# Stale lock threshold (phút)
readonly MC_LOCK_STALE_MIN="${MCV3_MC_LOCK_STALE_MIN:-60}"

# ─── Logging ────────────────────────────────────────────────

mc_log()   { echo "[${_SCRIPT_NAME:-wf-manage-change}] INFO: $*" >&2; }
mc_warn()  { echo "[${_SCRIPT_NAME:-wf-manage-change}] WARN: $*" >&2; }
mc_err()   { echo "[${_SCRIPT_NAME:-wf-manage-change}] ERROR: $*" >&2; }
mc_debug() {
  if [[ "${MC_DEBUG:-0}" == "1" ]]; then
    echo "[${_SCRIPT_NAME:-wf-manage-change}] DEBUG: $*" >&2
  fi
}

# ─── Platform Detection ─────────────────────────────────────

mc_has_jq()     { command -v jq &>/dev/null; }
mc_has_sha256() { command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; }

# ─── Timestamp ──────────────────────────────────────────────

# ISO-8601 UTC timestamp
mc_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Unix epoch seconds
mc_epoch() { date +%s; }

# ─── Identity ───────────────────────────────────────────────

mc_identity() {
  local user="${USER:-${USERNAME:-unknown}}"
  local host
  host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")
  echo "${user}@${host}"
}

mc_user() { echo "${USER:-${USERNAME:-unknown}}"; }

mc_host() {
  hostname 2>/dev/null || echo "${HOSTNAME:-unknown}"
}

# ─── Registry Path ──────────────────────────────────────────

mc_registry_path() { echo ".mc-data/docs/_meta/req-registry.json"; }

# ─── Directories ────────────────────────────────────────────

mc_ensure_dirs() {
  mkdir -p "$MC_ROOT/_index"
  mkdir -p "$MC_ROOT/.locks"
}

# ─── jq Helpers ─────────────────────────────────────────────

# Validate JSON file. Return 0 if valid, 1 otherwise.
mc_jq_validate() {
  local f="$1"
  [[ ! -f "$f" ]] && return 1
  if mc_has_jq; then
    jq empty "$f" 2>/dev/null
  else
    local first
    first=$(head -c1 "$f" 2>/dev/null)
    [[ "$first" == "{" || "$first" == "[" ]]
  fi
}

# ─── SHA256 ─────────────────────────────────────────────────

mc_sha256() {
  local f="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$f" | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$f" | cut -d' ' -f1
  else
    echo "sha256-unavailable"
  fi
}

# ─── JSON Helpers ───────────────────────────────────────────

# Atomic write JSON: tmp → validate → rename.
# Args: target_path  content
mc_atomic_write_json() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"

  mkdir -p "$(dirname "$target")"
  printf '%s' "$content" > "$tmp"

  if mc_has_jq; then
    if ! jq empty "$tmp" 2>/dev/null; then
      mc_err "mc_atomic_write_json: invalid JSON for $target"
      rm -f "$tmp"
      return 1
    fi
  fi

  mv "$tmp" "$target"
  mc_debug "Wrote $target ($(wc -c < "$target") bytes)"
}

# Append single-line JSON entry to JSONL file.
# Args: file_path  json_object_string
mc_append_jsonl() {
  local file="$1"
  local entry="$2"

  mkdir -p "$(dirname "$file")"

  if mc_has_jq; then
    if ! printf '%s' "$entry" | jq empty 2>/dev/null; then
      mc_err "mc_append_jsonl: invalid JSON entry for $file"
      return 1
    fi
    printf '%s' "$entry" | jq -c '.' >> "$file"
  else
    printf '%s\n' "$entry" >> "$file"
  fi
}

# ─── Library loaded marker ──────────────────────────────────
readonly _MC_COMMON_LOADED=1
mc_debug "mc-common.sh v${MC_COMMON_VERSION} loaded"
