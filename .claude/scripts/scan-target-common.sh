#!/usr/bin/env bash
# scan-target-common.sh — Shared helpers cho wf-scan-target bash scripts
# Sprint 4 bash delegation — Version 1.0
#
# Usage:
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/scan-target-common.sh"
#   _SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
#
# Cross-platform: Windows Git Bash + WSL + Linux + macOS.
# Functions:
#   - log_info / log_warn / log_error / log_debug
#   - normalize_path / abs_path / compute_rel_path / slugify
#   - json_escape / validate_json / atomic_write_json / json_pretty
#   - has_jq / has_sha256
#   - create_lock / check_lock / release_lock
#   - resolve_session_id

# Guard: không source lại 2 lần
if [[ -n "${_SCAN_TARGET_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly SCAN_TARGET_COMMON_VERSION="1.0"

# Default exclusion dirs khi find traversal
readonly SCAN_TARGET_EXCLUDE_DIRS=(
  node_modules .git dist build .next .nuxt out coverage
  .cache .turbo vendor __pycache__ .venv venv .idea .vscode
  bin obj Debug Release packages .gradle .mvn target tmp
  .mc-data .backup
)

# File-lock stale threshold (phút)
readonly SCAN_TARGET_LOCK_STALE_MINUTES="${SCAN_TARGET_LOCK_STALE_MIN:-60}"

# ─── Logging ────────────────────────────────────────────────

log_info()  { echo "[${_SCRIPT_NAME:-scan-target}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-scan-target}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-scan-target}] ERROR: $*" >&2; }
log_debug() {
  if [[ "${SCAN_TARGET_DEBUG:-0}" == "1" ]]; then
    echo "[${_SCRIPT_NAME:-scan-target}] DEBUG: $*" >&2
  fi
}

# ─── Platform Detection ─────────────────────────────────────

has_jq()       { command -v jq &>/dev/null; }
has_sha256()   { command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; }

# ─── Path Helpers ───────────────────────────────────────────

# Normalize path: \ → /. Giữ Windows drive letter (z:/...) thay vì convert /z/.
# Lý do: downstream consumers (jq, find) vẫn handle đúng, không break path strings.
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

# Relative path từ project root.
# Args: full_path project_root
compute_rel_path() {
  local full
  full="$(normalize_path "$1")"
  local prefix
  prefix="$(normalize_path "$2")/"
  echo "${full#$prefix}"
}

# Slugify: lowercase + replace non-alphanumeric với "-" + dedup "-" + trim.
# Strip "Eureka.Modules." prefix nếu có.
# Args: input_string
slugify() {
  echo "$1" \
    | sed -e 's/^Eureka\.Modules\.//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# Build find exclusion args từ SCAN_TARGET_EXCLUDE_DIRS.
build_excludes() {
  local exclude_args=()
  local dir
  for dir in "${SCAN_TARGET_EXCLUDE_DIRS[@]}"; do
    exclude_args+=( -not -path "*/$dir/*" )
  done
  echo "${exclude_args[*]}"
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
# Wrapper quanh atomic_write_json — auto pretty-print qua jq trước khi ghi
# để output có indentation 2-space chuẩn (human-readable + diff-friendly).
# Args: target_path raw_json_content
# Sprint 6 multi-dev safety — naming aligned với legacy-scan-common.sh pattern.
safe_write_json() {
  local target="$1"
  local raw="$2"
  local pretty="$raw"

  if has_jq; then
    pretty=$(printf '%s' "$raw" | jq '.' 2>/dev/null || printf '%s' "$raw")
  fi
  atomic_write_json "$target" "$pretty"
}

# Append JSON entry as single line vào JSONL file (newline-delimited JSON).
# Pattern git-sync friendly: mỗi entry 1 dòng độc lập → no merge conflict.
# Atomic guarantee: single echo ">>" với entry < 4KB là atomic trên POSIX
# (filesystem block size + write() atomicity). Thực tế entry scans-index ~500 bytes.
# Args: file_path json_object_string
# Sprint 6 multi-dev safety — multi-dev concurrent append không corrupt.
append_jsonl() {
  local file="$1"
  local entry="$2"

  mkdir -p "$(dirname "$file")"

  if has_jq; then
    if ! printf '%s' "$entry" | jq empty 2>/dev/null; then
      log_error "append_jsonl: invalid JSON entry for $file"
      log_error "Entry preview: $(printf '%s' "$entry" | head -c200)"
      return 1
    fi
    # jq -c để force compact (1 dòng), kể cả entry input đã pretty-print
    printf '%s' "$entry" | jq -c '.' >> "$file"
  else
    # Fallback no-jq: best-effort, giả định caller đã pass compact JSON
    printf '%s\n' "$entry" >> "$file"
  fi
  log_debug "Appended 1 entry to $file"
}

# ─── Lock Helpers (Sprint 6 — multi-dev safety hardening) ──

# Tạo lock file với metadata (pid, host, user, started_at, skill, session_id).
# Args: lock_file [session_id]
create_lock() {
  local lock_file="$1"
  local session_id="${2:-unknown}"

  mkdir -p "$(dirname "$lock_file")"

  # JSON format (Sprint 4) — Sprint 6 sẽ thêm heartbeat field
  # BUG-004 fix (v2.0.1): always invoke hostname cmd first (POSIX, cross-platform)
  # với fallback HOSTNAME env var khi cmd fail.
  local current_host
  current_host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")

  cat > "$lock_file" <<EOF
{
  "pid": $$,
  "host": "$current_host",
  "user": "${USER:-unknown}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "skill": "wf-scan-target",
  "session_id": "$(json_escape "$session_id")"
}
EOF
  log_debug "Created lock $lock_file (pid=$$)"
}

# Check lock validity: 0 = lock alive, 1 = no lock, 2 = lock dead (PID không alive).
# Args: lock_file
check_lock() {
  local lock_file="$1"
  [[ ! -f "$lock_file" ]] && return 1   # no lock

  local pid=""
  if has_jq; then
    pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null || echo "")
  fi
  [[ -z "$pid" ]] && return 1   # malformed lock → treat as no lock

  if kill -0 "$pid" 2>/dev/null; then
    return 0   # alive
  else
    return 2   # dead lock — caller có thể cleanup
  fi
}

# Sprint 6 multi-dev safety — Extended lock status với cross-host detection.
# Args: lock_file
# Returns: 0 = alive_local, 1 = no_lock, 2 = dead_local (cleanable), 3 = alive_cross_host (NOT cleanable)
# Stdout (khi có lock): "<status>|<pid>|<host>|<started_at>"
# Lý do tách khỏi check_lock: cross-host không thể `kill -0` → phải check riêng.
check_lock_status() {
  local lock_file="$1"
  [[ ! -f "$lock_file" ]] && return 1   # no lock

  local pid="" host="" started_at=""
  if has_jq; then
    pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null || echo "")
    host=$(jq -r '.host // empty' "$lock_file" 2>/dev/null || echo "")
    started_at=$(jq -r '.started_at // empty' "$lock_file" 2>/dev/null || echo "")
  fi
  if [[ -z "$pid" || -z "$host" ]]; then
    return 1   # malformed lock → treat as no lock
  fi

  local current_host
  current_host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")

  if [[ "$host" != "$current_host" ]]; then
    # Cross-host: KHÔNG thể `kill -0` để check PID alive trên máy khác →
    # mặc định coi như alive (an toàn). User phải dùng session mới hoặc đợi.
    echo "alive_cross_host|$pid|$host|$started_at"
    return 3
  fi

  # Same host → check PID
  if kill -0 "$pid" 2>/dev/null; then
    echo "alive_local|$pid|$host|$started_at"
    return 0
  else
    echo "dead_local|$pid|$host|$started_at"
    return 2
  fi
}

# Release lock (xóa file).
# Args: lock_file
release_lock() {
  local lock_file="$1"
  if [[ -f "$lock_file" ]]; then
    rm -f "$lock_file"
    log_debug "Released lock $lock_file"
  fi
}

# ─── Phase 2 Parallel Execution Helper (v2.0.1 BUG-002 fix) ────

# Run multiple bash scripts in parallel, wait for all, return aggregated exit code.
# Usage: run_phase2_parallel <output_dir> <tech_json> <scan_root> [layers...]
#   layers: subset of [l1 l2 l3 l4] — default all 4
#
# Lý do helper riêng: caller chains `&&` + `&` background gây args parsing fail
# (xem BUG-002 trong test-results-v2.0.md). Helper wrap subshell + wait đúng cách.
#
# Returns: 0 if all scripts succeed, otherwise count of failed scripts.
run_phase2_parallel() {
  local output_dir="$1"
  local tech_json="$2"
  local scan_root="$3"
  shift 3

  local layers=("$@")
  [[ ${#layers[@]} -eq 0 ]] && layers=(l1 l2 l3 l4)

  local scripts_dir
  scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local pids=()
  local failed=0
  local layer

  for layer in "${layers[@]}"; do
    local script_path=""
    case "$layer" in
      l1) script_path="$scripts_dir/scan-target-inventory.sh" ;;
      l2) script_path="$scripts_dir/scan-target-api.sh" ;;
      l3) script_path="$scripts_dir/scan-target-ui.sh" ;;
      l4) script_path="$scripts_dir/scan-target-db.sh" ;;
      *)
        log_warn "run_phase2_parallel: unknown layer '$layer' — skip"
        continue
        ;;
    esac

    [[ ! -f "$script_path" ]] && {
      log_error "run_phase2_parallel: script not found: $script_path"
      failed=$((failed + 1))
      continue
    }

    # Spawn trong subshell để isolate args + redirect logs riêng từng layer.
    # L1 không cần tech_json (ignore arg 3 nếu không dùng).
    if [[ "$layer" == "l1" ]]; then
      ( bash "$script_path" "$scan_root" "$output_dir" >"$output_dir/.${layer}.log" 2>&1 ) &
    else
      ( bash "$script_path" "$scan_root" "$output_dir" "$tech_json" >"$output_dir/.${layer}.log" 2>&1 ) &
    fi
    pids+=($!)
  done

  # Wait + aggregate exit codes
  local pid
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=$((failed + 1))
    fi
  done

  if [[ "$failed" -gt 0 ]]; then
    log_error "run_phase2_parallel: $failed/${#pids[@]} layers failed — check $output_dir/.*.log"
    return "$failed"
  fi

  log_info "run_phase2_parallel: all ${#pids[@]} layers completed"
  return 0
}

# ─── Session ID Resolution (Protocol 18.2) ─────────────────────

# Resolve SESSION_ID format: {YYYY-MM-DD}-{scope-label}[-{N}]
# Args: target  module_arg  sessions_dir
# Echo: resolved session_id
resolve_session_id() {
  local target="$1"
  local module_arg="${2:-}"
  local sessions_dir="$3"

  local date_str
  date_str=$(date +%Y-%m-%d)

  local scope_label
  if [[ -n "$module_arg" && "$module_arg" != "auto" ]]; then
    scope_label=$(slugify "$module_arg")
  elif [[ "$target" =~ ^https?:// ]]; then
    # Extract hostname không TLD
    local hostname
    hostname=$(echo "$target" | awk -F[/:] '{print $4}' 2>/dev/null | sed 's/\.[a-z]*$//')
    scope_label=$(slugify "${hostname:-scan}")
  elif [[ -e "$target" ]]; then
    local basename_str
    basename_str=$(basename "$target")
    scope_label=$(slugify "$basename_str")
  else
    scope_label="scan"
  fi

  [[ -z "$scope_label" ]] && scope_label="scan"

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
readonly _SCAN_TARGET_COMMON_LOADED=1
log_debug "scan-target-common.sh v${SCAN_TARGET_COMMON_VERSION} loaded"
