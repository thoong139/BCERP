#!/usr/bin/env bash
# implement-common.sh — Shared helpers cho wf-implement-feature bash scripts
# v5.0.0 — System-grouped layout (per-system folders trong work dir).
#
# Usage:
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/implement-common.sh"
#   _SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
#
# Cross-platform: Windows Git Bash + WSL + Linux + macOS.
#
# Layout (v5.0):
#   .mc-data/work/wf-implement-feature/
#   ├── {system_slug}/{feature_slug}/sessions/{session_id}/...
#   ├── {system_slug}/{feature_slug}/current.txt
#   ├── .layout-version           (= "5")
#   ├── .history/implementations-index.jsonl   (entries có field "system")
#   ├── .cache/{system_slug}/{module_slug}/existing-patterns.{git_sha}.json
#   ├── .locks/{system_slug}/{feature_slug}.lock
#   └── _orphan/{feature_slug}/...   (features không tìm thấy system trong registry)
#
# Functions:
#   - log_info / log_warn / log_error / log_debug
#   - has_jq / has_sha256
#   - normalize_slug (Vietnamese-safe, port từ SKILL.md v3.3+)
#   - short_host
#   - generate_session_id
#   - derive_system_slug (v5.0 — query registry để map feature → system_slug)
#   - get_feature_dir / get_active_session (v5.0 — 2-arg: system_slug, feature_slug)
#   - resolve_session_dir (v5.0 — 3-arg: system_slug, feature_slug, resume)
#   - trace_event (append to _trace/session-log.json)
#   - json_escape / validate_json / atomic_write_json / safe_write_json / append_jsonl
#   - ledger_log (Sprint 4 v4.0 — append to error-ledger.json with namespaced codes)

# Guard: không source lại 2 lần
if [[ -n "${_IMPLEMENT_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly IMPLEMENT_COMMON_VERSION="2.0"

readonly FEATURE_BASE_DIR=".mc-data/work/wf-implement-feature"
readonly HISTORY_DIR="$FEATURE_BASE_DIR/.history"
readonly CACHE_DIR="$FEATURE_BASE_DIR/.cache"
readonly LOCKS_DIR="$FEATURE_BASE_DIR/.locks"
readonly TRACE_LOG=".mc-data/work/_trace/session-log.json"
readonly REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"
readonly LAYOUT_VERSION_FILE="$FEATURE_BASE_DIR/.layout-version"
readonly LAYOUT_VERSION_CURRENT="5"
readonly UNKNOWN_SYSTEM_SLUG="_unknown"

# Stale lock thresholds (phút)
readonly IMPLEMENT_FEATURE_LOCK_STALE_MIN="${IMPLEMENT_FEATURE_LOCK_STALE_MIN:-60}"
readonly IMPLEMENT_REGISTRY_LOCK_STALE_MIN="${IMPLEMENT_REGISTRY_LOCK_STALE_MIN:-5}"

# ─── Logging ────────────────────────────────────────────────

log_info()  { echo "[${_SCRIPT_NAME:-wf-implement}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-wf-implement}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-wf-implement}] ERROR: $*" >&2; }
log_debug() {
  if [[ "${IMPLEMENT_DEBUG:-0}" == "1" ]]; then
    echo "[${_SCRIPT_NAME:-wf-implement}] DEBUG: $*" >&2
  fi
}

# ─── Platform Detection ─────────────────────────────────────

has_jq()     { command -v jq &>/dev/null; }
has_sha256() { command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; }

# ─── Slug helpers ───────────────────────────────────────────

# Vietnamese-safe slug normalization (Finding #2 from v3.3+).
# Args: input_string
# Echo: normalized slug (lowercase-kebab-case, max 60 chars).
#
# Steps:
#   1. Vietnamese diacritics fold qua manual lookup table (cross-platform reliable)
#   2. iconv ASCII translit như fallback bổ sung cho ký tự khác
#   3. Replace separators (/, \, _, +) → space
#   4. Lowercase
#   5. Strip non [a-z0-9 ] chars
#   6. Collapse spaces, trim
#   7. Replace spaces → hyphens, collapse multiple hyphens
#   8. Truncate to 60 chars
#
# Lý do dùng manual table: iconv //TRANSLIT trên Git Bash Windows không có
# Vietnamese transliteration → fail silently và truncate string. Manual table
# guarantee correctness cross-platform.
normalize_slug() {
  local input="${1:-}"
  [[ -z "$input" ]] && { echo ""; return 0; }

  # Step 1: Vietnamese diacritics fold (manual lookup, comprehensive).
  # Order: lowercase chars trước, sau đó uppercase. Tất cả 6 dấu × 12 nguyên âm + đ/Đ.
  local folded="$input"
  # a variants
  folded="${folded//à/a}"; folded="${folded//á/a}"; folded="${folded//ả/a}"; folded="${folded//ã/a}"; folded="${folded//ạ/a}"
  folded="${folded//ă/a}"; folded="${folded//ằ/a}"; folded="${folded//ắ/a}"; folded="${folded//ẳ/a}"; folded="${folded//ẵ/a}"; folded="${folded//ặ/a}"
  folded="${folded//â/a}"; folded="${folded//ầ/a}"; folded="${folded//ấ/a}"; folded="${folded//ẩ/a}"; folded="${folded//ẫ/a}"; folded="${folded//ậ/a}"
  # e variants
  folded="${folded//è/e}"; folded="${folded//é/e}"; folded="${folded//ẻ/e}"; folded="${folded//ẽ/e}"; folded="${folded//ẹ/e}"
  folded="${folded//ê/e}"; folded="${folded//ề/e}"; folded="${folded//ế/e}"; folded="${folded//ể/e}"; folded="${folded//ễ/e}"; folded="${folded//ệ/e}"
  # i variants
  folded="${folded//ì/i}"; folded="${folded//í/i}"; folded="${folded//ỉ/i}"; folded="${folded//ĩ/i}"; folded="${folded//ị/i}"
  # o variants
  folded="${folded//ò/o}"; folded="${folded//ó/o}"; folded="${folded//ỏ/o}"; folded="${folded//õ/o}"; folded="${folded//ọ/o}"
  folded="${folded//ô/o}"; folded="${folded//ồ/o}"; folded="${folded//ố/o}"; folded="${folded//ổ/o}"; folded="${folded//ỗ/o}"; folded="${folded//ộ/o}"
  folded="${folded//ơ/o}"; folded="${folded//ờ/o}"; folded="${folded//ớ/o}"; folded="${folded//ở/o}"; folded="${folded//ỡ/o}"; folded="${folded//ợ/o}"
  # u variants
  folded="${folded//ù/u}"; folded="${folded//ú/u}"; folded="${folded//ủ/u}"; folded="${folded//ũ/u}"; folded="${folded//ụ/u}"
  folded="${folded//ư/u}"; folded="${folded//ừ/u}"; folded="${folded//ứ/u}"; folded="${folded//ử/u}"; folded="${folded//ữ/u}"; folded="${folded//ự/u}"
  # y variants
  folded="${folded//ỳ/y}"; folded="${folded//ý/y}"; folded="${folded//ỷ/y}"; folded="${folded//ỹ/y}"; folded="${folded//ỵ/y}"
  # d variants
  folded="${folded//đ/d}"
  # Uppercase variants (sẽ bị tr lowercase ở step 4 — nhưng fold ở đây cho an toàn)
  folded="${folded//À/A}"; folded="${folded//Á/A}"; folded="${folded//Ả/A}"; folded="${folded//Ã/A}"; folded="${folded//Ạ/A}"
  folded="${folded//Ă/A}"; folded="${folded//Ằ/A}"; folded="${folded//Ắ/A}"; folded="${folded//Ẳ/A}"; folded="${folded//Ẵ/A}"; folded="${folded//Ặ/A}"
  folded="${folded//Â/A}"; folded="${folded//Ầ/A}"; folded="${folded//Ấ/A}"; folded="${folded//Ẩ/A}"; folded="${folded//Ẫ/A}"; folded="${folded//Ậ/A}"
  folded="${folded//È/E}"; folded="${folded//É/E}"; folded="${folded//Ẻ/E}"; folded="${folded//Ẽ/E}"; folded="${folded//Ẹ/E}"
  folded="${folded//Ê/E}"; folded="${folded//Ề/E}"; folded="${folded//Ế/E}"; folded="${folded//Ể/E}"; folded="${folded//Ễ/E}"; folded="${folded//Ệ/E}"
  folded="${folded//Ì/I}"; folded="${folded//Í/I}"; folded="${folded//Ỉ/I}"; folded="${folded//Ĩ/I}"; folded="${folded//Ị/I}"
  folded="${folded//Ò/O}"; folded="${folded//Ó/O}"; folded="${folded//Ỏ/O}"; folded="${folded//Õ/O}"; folded="${folded//Ọ/O}"
  folded="${folded//Ô/O}"; folded="${folded//Ồ/O}"; folded="${folded//Ố/O}"; folded="${folded//Ổ/O}"; folded="${folded//Ỗ/O}"; folded="${folded//Ộ/O}"
  folded="${folded//Ơ/O}"; folded="${folded//Ờ/O}"; folded="${folded//Ớ/O}"; folded="${folded//Ở/O}"; folded="${folded//Ỡ/O}"; folded="${folded//Ợ/O}"
  folded="${folded//Ù/U}"; folded="${folded//Ú/U}"; folded="${folded//Ủ/U}"; folded="${folded//Ũ/U}"; folded="${folded//Ụ/U}"
  folded="${folded//Ư/U}"; folded="${folded//Ừ/U}"; folded="${folded//Ứ/U}"; folded="${folded//Ử/U}"; folded="${folded//Ữ/U}"; folded="${folded//Ự/U}"
  folded="${folded//Ỳ/Y}"; folded="${folded//Ý/Y}"; folded="${folded//Ỷ/Y}"; folded="${folded//Ỹ/Y}"; folded="${folded//Ỵ/Y}"
  folded="${folded//Đ/D}"

  # Step 2-8: pipeline normalization
  # iconv vẫn được dùng làm fallback cho non-Vietnamese accents (ñ, é unaccented, etc.)
  printf '%s' "$folded" \
    | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
    | sed -E 's![/\\_+]! !g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's![^a-z0-9 ]!!g; s/  +/ /g; s/^ +//; s/ +$//' \
    | tr ' ' '-' \
    | sed -E 's/-+/-/g' \
    | head -c 60 \
    | sed -E 's/-+$//'
}

# Hostname truncated, lowercase, alphanumeric+hyphen only, max 12 chars.
short_host() {
  local h
  h=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")
  echo "$h" | head -c 12 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | sed -E 's/-+$//'
}

# Generate session ID format: {YYYY-MM-DD}-{HHMMSS}-{shorthost}.
# Multi-session same-second: caller phải retry với suffix -2, -3,...
generate_session_id() {
  local ts host
  ts=$(date -u +%Y-%m-%d-%H%M%S)
  host=$(short_host)
  [[ -z "$host" ]] && host="unknown"
  echo "${ts}-${host}"
}

# ─── System slug derivation (v5.0) ───────────────────────────

# Derive system_slug từ registry, dựa trên feature input.
# Input có thể là: FEAT-ID (FEAT-XXX-NNN), feature_slug (đã normalize), hoặc feature title.
#
# Args:
#   $1 feature_input  — FEAT-ID hoặc feature_slug hoặc title
#   $2 override       — Optional: --system flag value (override toàn bộ logic)
#   $3 registry_path  — Optional: default $REGISTRY_PATH
# Echo: system_slug (lowercase-kebab-case) hoặc $UNKNOWN_SYSTEM_SLUG.
# Returns: 0 luôn (graceful — không fail khi registry missing).
#
# Resolution order:
#   1. $override (nếu truyền) → echo + return
#   2. Registry features[] match by .id (FEAT-ID pattern) → systems[].slug
#   3. Registry features[] match by normalized .name → systems[].slug
#   4. Fallback: derive from system_id stripping "SYS-" prefix
#   5. Fallback cuối: $UNKNOWN_SYSTEM_SLUG
derive_system_slug() {
  local feature_input="${1:-}"
  local override="${2:-}"
  local registry="${3:-$REGISTRY_PATH}"

  # 1. Override
  if [[ -n "$override" ]]; then
    # Nếu override đã là valid slug (lowercase-kebab-case) → pass-through.
    # Nếu là tên hệ thống có dấu/uppercase → normalize.
    if [[ "$override" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      echo "$override"
      return 0
    fi
    local override_norm
    override_norm=$(normalize_slug "$override")
    [[ -n "$override_norm" ]] && { echo "$override_norm"; return 0; }
  fi

  if [[ -z "$feature_input" ]]; then
    echo "$UNKNOWN_SYSTEM_SLUG"
    return 0
  fi

  if [[ ! -f "$registry" ]]; then
    log_debug "derive_system_slug: registry không tồn tại ($registry) — fallback $UNKNOWN_SYSTEM_SLUG"
    echo "$UNKNOWN_SYSTEM_SLUG"
    return 0
  fi

  if ! has_jq; then
    log_warn "derive_system_slug: jq không khả dụng — fallback $UNKNOWN_SYSTEM_SLUG"
    echo "$UNKNOWN_SYSTEM_SLUG"
    return 0
  fi

  local system_id=""

  # 2. Match by FEAT-ID (input có pattern FEAT-XXX-NNN)
  if [[ "$feature_input" =~ ^FEAT-[A-Z0-9-]+$ ]]; then
    system_id=$(jq -r --arg fid "$feature_input" \
      '[.features[]? | select(.id == $fid) | .system_id // empty][0] // empty' \
      "$registry" 2>/dev/null)
  fi

  # 3. Match by normalized name (input là feature_slug)
  if [[ -z "$system_id" || "$system_id" == "null" ]]; then
    while IFS=$'\t' read -r fname fsysid; do
      [[ -z "$fname" ]] && continue
      local fslug
      fslug=$(normalize_slug "$fname")
      if [[ "$fslug" == "$feature_input" ]]; then
        system_id="$fsysid"
        break
      fi
    done < <(jq -r '.features[]? | [.name, .system_id] | @tsv' "$registry" 2>/dev/null)
  fi

  if [[ -z "$system_id" || "$system_id" == "null" ]]; then
    log_debug "derive_system_slug: không tìm thấy feature '$feature_input' trong registry — $UNKNOWN_SYSTEM_SLUG"
    echo "$UNKNOWN_SYSTEM_SLUG"
    return 0
  fi

  # 4. Lookup systems[].slug by id
  local sys_slug
  sys_slug=$(jq -r --arg sid "$system_id" \
    '[.systems[]? | select(.id == $sid) | .slug // empty][0] // empty' \
    "$registry" 2>/dev/null)

  if [[ -z "$sys_slug" || "$sys_slug" == "null" ]]; then
    # 4. Fallback: derive từ system_id (strip SYS- prefix, lowercase, replace _ → -)
    sys_slug=$(echo "$system_id" | sed -E 's/^SYS-//I' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    [[ -z "$sys_slug" ]] && sys_slug="$UNKNOWN_SYSTEM_SLUG"
  fi

  echo "$sys_slug"
}

# ─── Session directory resolution (v5.0 — 2-arg: system + feature) ─

# Get feature directory: $FEATURE_BASE_DIR/{system_slug}/{feature_slug}
# Args: system_slug  feature_slug
# Echo: relative path. Returns 1 nếu thiếu args.
get_feature_dir() {
  local sys="${1:-}"
  local slug="${2:-}"
  if [[ -z "$sys" || -z "$slug" ]]; then
    log_error "get_feature_dir: requires (system_slug, feature_slug) — got sys='$sys' slug='$slug'"
    return 1
  fi
  echo "$FEATURE_BASE_DIR/$sys/$slug"
}

# Get active session id từ current.txt pointer.
# Args: system_slug  feature_slug
# Echo: session id (basename) hoặc empty nếu pointer không tồn tại.
# Returns: 0 if active, 1 if no current.txt, 2 if current.txt points to non-existent dir.
get_active_session() {
  local sys="${1:-}"
  local slug="${2:-}"
  local feature_dir
  feature_dir=$(get_feature_dir "$sys" "$slug") || return 1
  local pointer="$feature_dir/current.txt"

  [[ ! -f "$pointer" ]] && return 1

  local rel_path
  rel_path=$(cat "$pointer" 2>/dev/null | tr -d '\r\n' | head -c 200)
  [[ -z "$rel_path" ]] && return 1

  if [[ ! -d "$feature_dir/$rel_path" ]]; then
    log_warn "current.txt points to non-existent dir: $rel_path"
    return 2
  fi

  basename "$rel_path"
  return 0
}

# Resolve session directory based on resume flag.
# Args: system_slug  feature_slug  resume_flag(true|false)
# Echo: relative path to session dir (relative to project root)
# Side effect: creates session dir + writes current.txt pointer
#
# Behavior:
#   - resume=true  + valid current.txt → reuse existing session
#   - resume=true  + missing/stale current.txt → fallback list newest session, hoặc tạo mới
#   - resume=false → tạo session mới, update current.txt
#   - Multi-session same-second: append -2, -3,... suffix
resolve_session_dir() {
  local sys="${1:-}"
  local slug="${2:-}"
  local resume="${3:-false}"
  local feature_dir
  feature_dir=$(get_feature_dir "$sys" "$slug") || return 1
  mkdir -p "$feature_dir/sessions"

  local pointer="$feature_dir/current.txt"

  if [[ "$resume" == "true" ]]; then
    if [[ -f "$pointer" ]]; then
      local rel_path
      rel_path=$(cat "$pointer" 2>/dev/null | tr -d '\r\n' | head -c 200)
      if [[ -n "$rel_path" && -d "$feature_dir/$rel_path" ]]; then
        echo "$feature_dir/$rel_path"
        return 0
      fi
    fi
    # Fallback: pick newest sessions/* dir
    local newest
    newest=$(ls -1 "$feature_dir/sessions" 2>/dev/null | sort -r | head -1)
    if [[ -n "$newest" && -d "$feature_dir/sessions/$newest" ]]; then
      echo "sessions/$newest" > "$pointer"
      echo "$feature_dir/sessions/$newest"
      return 0
    fi
    log_warn "resolve_session_dir: --resume requested nhưng không tìm thấy session — tạo mới"
  fi

  # Fresh session
  local sid base
  base=$(generate_session_id)
  sid="$base"
  local n=2
  while [[ -d "$feature_dir/sessions/$sid" ]]; do
    sid="${base}-${n}"
    n=$((n + 1))
    if (( n > 100 )); then
      log_error "resolve_session_dir: > 100 collisions cho $base — abort"
      return 1
    fi
  done

  mkdir -p "$feature_dir/sessions/$sid"
  echo "sessions/$sid" > "$pointer"
  echo "$feature_dir/sessions/$sid"
}

# ─── Path helpers (v5.0 — system-scoped locks/cache) ─────────

# Get lock file path: $LOCKS_DIR/{system_slug}/{feature_slug}.lock
# Args: system_slug  feature_slug
get_feature_lock_path() {
  local sys="${1:-}"
  local slug="${2:-}"
  if [[ -z "$sys" || -z "$slug" ]]; then
    log_error "get_feature_lock_path: requires (system_slug, feature_slug)"
    return 1
  fi
  echo "$LOCKS_DIR/$sys/$slug.lock"
}

# Get cache dir path: $CACHE_DIR/{system_slug}/{module_slug}
# Args: system_slug  module_slug
get_cache_dir_for_module() {
  local sys="${1:-}"
  local mod="${2:-}"
  if [[ -z "$sys" || -z "$mod" ]]; then
    log_error "get_cache_dir_for_module: requires (system_slug, module_slug)"
    return 1
  fi
  echo "$CACHE_DIR/$sys/$mod"
}

# ─── Layout version marker (v5.0) ────────────────────────────

# Read layout version từ marker file. Echo "4" nếu marker chưa tồn tại
# (giả định là v4 layout từ trước migration). Echo "5" hoặc giá trị khác nếu có.
# Returns: 0 luôn.
read_layout_version() {
  if [[ ! -f "$LAYOUT_VERSION_FILE" ]]; then
    # Marker chưa tồn tại — kiểm tra base dir có data v4 không
    if [[ -d "$FEATURE_BASE_DIR" ]] && \
       compgen -G "$FEATURE_BASE_DIR/*/sessions/" >/dev/null 2>&1; then
      echo "4"
    else
      echo "$LAYOUT_VERSION_CURRENT"
    fi
    return 0
  fi
  cat "$LAYOUT_VERSION_FILE" 2>/dev/null | tr -d '\r\n' | head -c 4
}

# Write layout version marker (idempotent).
# Args: version_string (default = $LAYOUT_VERSION_CURRENT)
write_layout_version() {
  local v="${1:-$LAYOUT_VERSION_CURRENT}"
  mkdir -p "$FEATURE_BASE_DIR"
  echo "$v" > "$LAYOUT_VERSION_FILE"
}

# ─── Trace event (CORE-026) ─────────────────────────────────

# Append START / COMPLETE / FAIL / CHECKPOINT event to _trace/session-log.json.
# Args: event  feature_slug  session_id  [extra_json='{}']
# Output-only — KHÔNG dùng làm input cho skill khác (CORE-026).
trace_event() {
  local event="$1"
  local feature_slug="${2:-}"
  local session_id="${3:-}"
  local extra_json="${4:-{\}}"

  mkdir -p "$(dirname "$TRACE_LOG")"

  if has_jq; then
    local entry
    entry=$(jq -nc \
      --arg e "$event" \
      --arg fs "$feature_slug" \
      --arg sid "$session_id" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson extra "$extra_json" \
      '{skill:"wf-implement-feature", event:$e, feature_slug:$fs, session_id:$sid, ts:$ts} + $extra' \
      2>/dev/null) || entry=""
    if [[ -n "$entry" ]]; then
      echo "$entry" >> "$TRACE_LOG"
      log_debug "trace_event: $event for $feature_slug/$session_id"
    fi
  else
    # Fallback no-jq: best-effort raw append
    printf '{"skill":"wf-implement-feature","event":"%s","feature_slug":"%s","session_id":"%s","ts":"%s"}\n' \
      "$event" "$feature_slug" "$session_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TRACE_LOG"
  fi
}

# ─── JSON Helpers ───────────────────────────────────────────

# Escape string for JSON embedding (order matters: backslash first).
json_escape() {
  local s="${1:-}"
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
  [[ ! -f "$f" ]] && return 1
  if has_jq; then
    jq empty "$f" 2>/dev/null
  else
    local first
    first=$(head -c1 "$f" 2>/dev/null)
    [[ "$first" == "{" || "$first" == "[" ]]
  fi
}

# Atomic write JSON: tmp → validate → rename.
# Args: target_path  content
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

# Safe write JSON: pretty-print + atomic write + jq validate.
# Args: target_path  raw_json_content
safe_write_json() {
  local target="$1"
  local raw="$2"
  local pretty="$raw"

  if has_jq; then
    pretty=$(printf '%s' "$raw" | jq '.' 2>/dev/null || printf '%s' "$raw")
  fi
  atomic_write_json "$target" "$pretty"
}

# Append single-line JSON entry to JSONL file (multi-dev safe).
# Args: file_path  json_object_string
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
    printf '%s' "$entry" | jq -c '.' >> "$file"
  else
    printf '%s\n' "$entry" >> "$file"
  fi
  log_debug "Appended 1 entry to $file"
}

# ─── Error Ledger (Sprint 4 v4.0) ───────────────────────────

# Maximum entries trong errors[] array (cap để file không phình quá lớn)
readonly LEDGER_MAX_ENTRIES="${LEDGER_MAX_ENTRIES:-100}"

# Append error entry to per-session error-ledger.json (namespaced codes E1xx-E9xx).
# Lazy-init: file chỉ được tạo lần đầu khi có error đầu tiên.
# Atomic write qua tmp + mv → safe với parallel agents (Phase 4 multi-agent reviewers).
#
# Args:
#   $1 code         - Namespaced error code (E[1-9][0-9]{2})
#   $2 phase        - Phase identifier (e.g. phase07-tdd, phase10-finalize)
#   $3 severity     - info | warning | error | critical
#   $4 message      - Human-readable description
#   $5 context      - JSON object (default '{}'), e.g. '{"batch":2,"file":"x.ts"}'
#   $6 auto_resolved - true|false (default false)
#   $7 escalated   - true|false (default false)
#   $8 resolution  - String (default empty)
#
# Required env vars:
#   $SESSION_DIR    - Absolute-relative path to session dir
#   $SESSION_ID     - Session identifier
#   $FEATURE_SLUG   - Feature slug
#
# Returns: 0 on success, 1 if missing env or jq error.
ledger_log() {
  local code="${1:-}"
  local phase="${2:-unknown}"
  local severity="${3:-info}"
  local message="${4:-}"
  local context="${5:-{\}}"
  local auto_resolved="${6:-false}"
  local escalated="${7:-false}"
  local resolution="${8:-}"

  # Validate required args
  if [[ -z "$code" ]]; then
    log_warn "ledger_log: missing code arg — skipped"
    return 1
  fi
  if [[ -z "${SESSION_DIR:-}" || -z "${SESSION_ID:-}" || -z "${FEATURE_SLUG:-}" ]]; then
    log_warn "ledger_log: SESSION_DIR/SESSION_ID/FEATURE_SLUG not set — skipped (code=$code)"
    return 1
  fi
  if ! has_jq; then
    log_warn "ledger_log: jq not available — error not logged (code=$code)"
    return 1
  fi

  # Validate code pattern E[1-9][0-9]{2}
  if [[ ! "$code" =~ ^E[1-9][0-9]{2}$ ]]; then
    log_warn "ledger_log: invalid code pattern '$code' (expected E[1-9][0-9]{2})"
    # Continue anyway — still log to ledger để debug
  fi

  # Validate severity
  case "$severity" in
    info|warning|error|critical) ;;
    *)
      log_warn "ledger_log: invalid severity '$severity' — defaulting to 'info'"
      severity="info"
      ;;
  esac

  local ledger_file="$SESSION_DIR/error-ledger.json"

  # Lazy init: tạo file lần đầu
  if [[ ! -f "$ledger_file" ]]; then
    jq -nc \
      --arg sid "$SESSION_ID" \
      --arg fs "$FEATURE_SLUG" \
      '{"$schema":"error-ledger-v1",schema_version:"1.0",session_id:$sid,feature_slug:$fs,errors:[]}' \
      > "$ledger_file" 2>/dev/null || {
      log_error "ledger_log: failed to init $ledger_file"
      return 1
    }
  fi

  # Validate context is valid JSON (fallback to {} if not)
  local valid_ctx="$context"
  if ! printf '%s' "$context" | jq empty 2>/dev/null; then
    log_warn "ledger_log: invalid context JSON for code=$code — using {}"
    valid_ctx="{}"
  fi

  local ts entry
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  entry=$(jq -nc \
    --arg c "$code" \
    --arg p "$phase" \
    --arg s "$severity" \
    --arg m "$message" \
    --argjson ctx "$valid_ctx" \
    --arg ts "$ts" \
    --argjson ar "$([ "$auto_resolved" = "true" ] && echo true || echo false)" \
    --argjson esc "$([ "$escalated" = "true" ] && echo true || echo false)" \
    --arg res "$resolution" \
    '{code:$c,phase:$p,severity:$s,message:$m,context:$ctx,ts:$ts,auto_resolved:$ar,escalated_to_user:$esc,resolution:$res}' \
    2>/dev/null) || {
    log_error "ledger_log: failed to build entry for code=$code"
    return 1
  }

  # Append + cap với atomic write
  local tmp
  tmp=$(mktemp 2>/dev/null) || tmp="${ledger_file}.tmp.$$"
  if jq --argjson e "$entry" --argjson cap "$LEDGER_MAX_ENTRIES" \
    '.errors += [$e] | if (.errors | length) > $cap then .errors |= .[(. | length - $cap):] else . end' \
    "$ledger_file" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$ledger_file"
  else
    log_error "ledger_log: jq append failed for $ledger_file"
    rm -f "$tmp"
    return 1
  fi

  # Trace event (best-effort)
  trace_event "ERROR_LOGGED" "$FEATURE_SLUG" "$SESSION_ID" \
    "{\"code\":\"$code\",\"severity\":\"$severity\",\"phase\":\"$phase\"}" \
    2>/dev/null || true

  log_debug "ledger_log: appended $code ($severity) at $phase"
  return 0
}

# ─── Library loaded marker ──────────────────────────────────
readonly _IMPLEMENT_COMMON_LOADED=1
log_debug "implement-common.sh v${IMPLEMENT_COMMON_VERSION} loaded"
