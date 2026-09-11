#!/usr/bin/env bash
# wf-diagram-common.sh — Shared helpers cho wf-diagram bash scripts
# Sprint 4 bash delegation — Version 1.0
#
# Usage:
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/wf-diagram-common.sh"
#   _SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
#
# Cross-platform: Windows Git Bash + WSL + Linux + macOS.
# Source pattern: scan-target-common.sh (Sprint 4 wf-scan-target).
#
# Functions:
#   - log_info / log_warn / log_error / log_debug
#   - has_jq
#   - normalize_path / abs_path / slugify
#   - json_escape / validate_json / atomic_write_json / json_pretty / safe_write_json
#   - iso8601_now / ensure_dir
#   - append_trace_event (Protocol 15)
#   - generate_session_id (Protocol 18.2 — {YYYY-MM-DD}-{scope-label}[-{N}])

# Guard: không source lại 2 lần
if [[ -n "${_WF_DIAGRAM_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly WF_DIAGRAM_COMMON_VERSION="1.0"
readonly WF_DIAGRAM_SKILL_NAME="/wf-diagram"

# ─── Logging ────────────────────────────────────────────────

log_info()  { echo "[${_SCRIPT_NAME:-wf-diagram}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-wf-diagram}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-wf-diagram}] ERROR: $*" >&2; }
log_debug() {
  if [[ "${WF_DIAGRAM_DEBUG:-0}" == "1" ]]; then
    echo "[${_SCRIPT_NAME:-wf-diagram}] DEBUG: $*" >&2
  fi
}

# ─── Platform Detection ─────────────────────────────────────

has_jq() { command -v jq &>/dev/null; }

# ─── Path Helpers ───────────────────────────────────────────

# Normalize path: \ → /. Giữ nguyên Windows drive letter (z:/...).
normalize_path() {
  local p="$1"
  echo "$p" | tr '\\' '/'
}

# Resolve absolute path cross-platform.
abs_path() {
  local p="$1"
  if command -v realpath &>/dev/null; then
    realpath "$p" 2>/dev/null || echo "$p"
  elif [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd) || echo "$p"
  elif [[ -f "$p" ]]; then
    local dir base
    dir="$(dirname "$p")"
    base="$(basename "$p")"
    (cd "$dir" 2>/dev/null && echo "$(pwd)/$base") || echo "$p"
  else
    echo "$p"
  fi
}

# Slugify: lowercase + replace non-alphanumeric với "-" + dedup "-" + trim.
# Không strip "Eureka.Modules." prefix (khác wf-scan-target — wf-diagram dùng module name nguyên gốc).
# Args: input_string
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# Tạo dir nếu chưa có. Idempotent.
# Args: path
ensure_dir() {
  local d="$1"
  [[ -d "$d" ]] && return 0
  mkdir -p "$d"
  log_debug "Created dir $d"
}

# ─── Time Helpers ───────────────────────────────────────────

# ISO-8601 UTC timestamp: 2026-05-03T22:30:00Z
iso8601_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ─── JSON Helpers ───────────────────────────────────────────

# Escape string for JSON embedding (order matters: backslash first).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  echo "$s"
}

# Validate JSON file. Return 0 if valid, 1 otherwise.
validate_json() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    return 1
  fi
  if has_jq; then
    jq empty "$f" 2>/dev/null
  else
    local first
    first=$(head -c1 "$f" 2>/dev/null)
    [[ "$first" == "{" || "$first" == "[" ]]
  fi
}

# Atomic write JSON: tmp → validate → rename.
# Usage: atomic_write_json /path/out.json "$content"
atomic_write_json() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"

  mkdir -p "$(dirname "$target")"
  printf '%s' "$content" > "$tmp"

  if has_jq; then
    if ! jq empty "$tmp" 2>/dev/null; then
      log_error "atomic_write_json: invalid JSON for $target"
      log_error "Content preview: $(head -c200 "$tmp")"
      rm -f "$tmp"
      return 1
    fi
  fi

  sync "$tmp" 2>/dev/null || true
  mv "$tmp" "$target"
  log_debug "Wrote $target ($(wc -c < "$target") bytes)"
}

# Pretty-print JSON content.
json_pretty() {
  local content="$1"
  if has_jq; then
    echo "$content" | jq '.'
  else
    echo "$content"
  fi
}

# Safe write JSON: pretty-print + atomic write + jq validate.
# Args: target_path raw_json_content
safe_write_json() {
  local target="$1"
  local raw="$2"
  local pretty="$raw"

  if has_jq; then
    pretty=$(printf '%s' "$raw" | jq '.' 2>/dev/null || printf '%s' "$raw")
  fi
  atomic_write_json "$target" "$pretty"
}

# ─── Trace Event Helper (Protocol 15) ──────────────────────

# Append START / COMPLETE / FAIL event vào session-log.json.
# Path: .mc-data/work/_trace/session-log.json (output-only — KHÔNG dùng làm input — CORE-026).
# Args: session_id phase event [files_created_json_array]
# Event ∈ {START, COMPLETE, FAIL}
append_trace_event() {
  local session_id="$1"
  local phase="$2"
  local event="$3"
  local files_json="${4:-[]}"

  local trace_dir=".mc-data/work/_trace"
  local trace_file="$trace_dir/session-log.json"

  ensure_dir "$trace_dir"

  if [[ ! -f "$trace_file" ]]; then
    echo '{"entries":[]}' > "$trace_file"
  fi

  local ts
  ts=$(iso8601_now)

  if has_jq; then
    local tmp="${trace_file}.tmp.$$"
    jq --arg sid "$session_id" --arg ts "$ts" \
       --arg ev "$event" --arg ph "$phase" \
       --argjson files "$files_json" \
       '.entries += [{"skill":"/wf-diagram","session_id":$sid,
                      "phase":$ph,"event":$ev,"timestamp":$ts,
                      "files_created":$files}]' \
       "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"
  else
    log_warn "append_trace_event: jq not available — skip trace append"
  fi
  log_debug "Trace appended: $event $phase $session_id"
}

# ─── Session ID Resolution (Protocol 18.2) ─────────────────

# Generate SESSION_ID format: {YYYY-MM-DD}-{scope-label}[-{N}]
# Scope label rules:
#   - Nếu $module set → slugify($module)
#   - Nếu scope=system-only và không có module → "system"
#   - Default → "diagram"
# Nếu sessions_dir/{base} đã tồn tại → suffix -2, -3, ...
#
# Args: module(optional) scope sessions_dir
# Echo: resolved session_id
generate_session_id() {
  local module="${1:-}"
  local scope="${2:-full}"
  local sessions_dir="${3:-.mc-data/work/wf-diagram/sessions}"

  local date_str
  date_str=$(date +%Y-%m-%d)

  local scope_label
  if [[ -n "$module" ]]; then
    scope_label=$(slugify "$module")
  elif [[ "$scope" == "system-only" ]]; then
    scope_label="system"
  else
    scope_label="diagram"
  fi

  [[ -z "$scope_label" ]] && scope_label="diagram"

  local base="${date_str}-${scope_label}"
  local final="$base"
  local n=2
  while [[ -d "$sessions_dir/$final" ]]; do
    final="${base}-${n}"
    n=$((n + 1))
  done
  echo "$final"
}

# ─── Library loaded marker ──────────────────────────────────
readonly _WF_DIAGRAM_COMMON_LOADED=1
log_debug "wf-diagram-common.sh v${WF_DIAGRAM_COMMON_VERSION} loaded"
