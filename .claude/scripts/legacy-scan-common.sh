#!/usr/bin/env bash
# legacy-scan-common.sh — Shared library cho wf-legacy-scan bash scripts
# Version: 1.0 (Phase B Foundation)
# Source: docs/design/skills/wf-legacy-scan/06-bash-scripts.md §2
#
# Usage:
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/legacy-scan-common.sh"
#   _SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
#
# Cross-platform: Windows Git Bash + WSL + Linux + macOS.

# Guard: không source lại 2 lần.
if [[ -n "${_LEGACY_SCAN_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly LEGACY_SCAN_COMMON_VERSION="1.0"

readonly DEFAULT_EXCLUDE_DIRS=(
  node_modules .git dist build .next .nuxt out coverage
  .cache .turbo vendor __pycache__ .venv venv .idea .vscode
  bin obj Debug Release packages .gradle .mvn target tmp
)

# Configurable caps (env var overrides) — xem 09-thresholds-justification.md §2.6
readonly MAX_API_ENDPOINTS="${LEGACY_SCAN_MAX_API:-500}"
readonly MAX_SCREENS="${LEGACY_SCAN_MAX_SCREENS:-500}"
readonly MAX_IMPORTS_PER_FILE="${LEGACY_SCAN_MAX_IMPORTS:-20}"
readonly MAX_IMPORT_FILES="${LEGACY_SCAN_MAX_FILES:-200}"
readonly MAX_DOC_FILES="${LEGACY_SCAN_MAX_DOC_FILES:-300}"
readonly STALE_THRESHOLD_DAYS="${LEGACY_SCAN_STALE_DAYS:-180}"
readonly CACHE_TTL_DAYS="${LEGACY_SCAN_CACHE_TTL:-14}"

# Concurrency caps (informational — orchestrator enforces)
readonly CONCURRENCY_GLOBAL_MAX="${LEGACY_SCAN_GLOBAL_MAX:-8}"
readonly CONCURRENCY_PER_LAYER_MAX="${LEGACY_SCAN_PER_LAYER_MAX:-3}"
readonly AGENT_TIMEOUT_SEC="${LEGACY_SCAN_AGENT_TIMEOUT_SEC:-300}"
readonly AGENT_TIMEOUT_DEEP_SEC="${LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC:-600}"

# File-lock stale threshold (phút) — sau thời gian này lock coi nhu orphan.
readonly LOCK_STALE_MINUTES="${LEGACY_SCAN_LOCK_STALE_MIN:-60}"

# ─── Logging ────────────────────────────────────────────────

log_info()  { echo "[${_SCRIPT_NAME:-scan}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-scan}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-scan}] ERROR: $*" >&2; }
log_debug() {
  if [[ "${LEGACY_SCAN_DEBUG:-0}" == "1" ]]; then
    echo "[${_SCRIPT_NAME:-scan}] DEBUG: $*" >&2
  fi
}

# ─── Platform Detection ─────────────────────────────────────

has_jq()       { command -v jq &>/dev/null; }
has_python3()  { command -v python3 &>/dev/null; }
# has_python — cross-platform: Git Bash Windows chi co `python`, Linux thuong co `python3`.
has_python()   { command -v python3 &>/dev/null || command -v python &>/dev/null; }
# pick_python — tra ve binary name phu hop goi trong orchestrator scripts.
pick_python()  { command -v python3 &>/dev/null && echo python3 || echo python; }
has_sha256()   { command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; }

# ─── Path Helpers ───────────────────────────────────────────

# Normalize Windows paths to Unix-like (C:\Foo → /c/Foo).
normalize_path() {
  local p="$1"
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/ ]]; then
    local drive="${BASH_REMATCH[1]}"
    p="/${drive,,}/${p:3}"
  fi
  echo "$p"
}

# Resolve absolute path cross-platform.
abs_path() {
  local p="$1"
  if command -v realpath &>/dev/null; then
    realpath "$p" 2>/dev/null || echo "$p"
  else
    (cd "$(dirname "$p")" 2>/dev/null && echo "$(pwd)/$(basename "$p")") || echo "$p"
  fi
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

  # fsync best-effort
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

# ─── File Helpers ───────────────────────────────────────────

# Build find exclusion args from DEFAULT_EXCLUDE_DIRS.
build_excludes() {
  local exclude_args=()
  local dir
  for dir in "${DEFAULT_EXCLUDE_DIRS[@]}"; do
    exclude_args+=( -not -path "*/$dir/*" )
  done
  echo "${exclude_args[*]}"
}

# Count files by extension list.
count_by_ext() {
  local dir="$1"
  shift
  local exts=("$@")
  local pattern=""
  local ext
  for ext in "${exts[@]}"; do
    [[ -n "$pattern" ]] && pattern+=" -o"
    pattern+=" -name '*.$ext'"
  done
  local cmd="find \"$dir\" $(build_excludes) -type f \\( $pattern \\)"
  eval "$cmd" 2>/dev/null | wc -l
}

# Compute file content hash (SHA256).
file_hash() {
  local f="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    log_warn "No SHA256 tool available, using mtime fallback"
    stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || echo "nohash"
  fi
}

# ─── File-Lock (session isolation) ──────────────────────────

# Acquire file lock for a session / resource.
# Args: lockfile [max_wait_seconds]
# Returns 0 if acquired, 1 if busy or stale cleanup failed.
flock_acquire() {
  local lockfile="$1"
  local max_wait="${2:-0}"
  local waited=0

  mkdir -p "$(dirname "$lockfile")"

  while [[ -f "$lockfile" ]]; do
    # Dead process detection (PID-based, sooner than time-based stale):
    local lock_pid
    lock_pid=$(grep '^pid=' "$lockfile" 2>/dev/null | cut -d= -f2)
    if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      log_warn "Lock holder PID $lock_pid dead at $lockfile, cleaning up"
      rm -f "$lockfile"
      break
    fi

    # Stale detection: lock cũ hơn LOCK_STALE_MINUTES phút.
    if [[ -n "$(find "$lockfile" -mmin "+${LOCK_STALE_MINUTES}" 2>/dev/null)" ]]; then
      log_warn "Stale lock detected at $lockfile (> ${LOCK_STALE_MINUTES} min), removing"
      rm -f "$lockfile"
      break
    fi

    if [[ $waited -ge $max_wait ]]; then
      local owner
      owner=$(cat "$lockfile" 2>/dev/null || echo "unknown")
      log_error "Lock busy at $lockfile (owner: $owner)"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done

  # Ghi thông tin owner.
  printf 'pid=%s\nuser=%s\nhost=%s\nacquired=%s\n' \
    "$$" "${USER:-unknown}" "${HOSTNAME:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$lockfile"
  return 0
}

# Release file lock.
flock_release() {
  local lockfile="$1"
  if [[ -f "$lockfile" ]]; then
    rm -f "$lockfile"
    log_debug "Released lock $lockfile"
  fi
}

# ─── Session Helpers ────────────────────────────────────────

# Generate session ID dạng UTC timestamp (YYYY-MM-DDTHH-MM-SS).
generate_session_id() {
  date -u +"%Y-%m-%dT%H-%M-%S"
}

# Khởi tạo session directory với subfolders chuẩn.
# Args: session_root_dir  session_id
# Output: in absolute session dir path tới stdout.
init_session_dir() {
  local work_dir="$1"
  local session_id="$2"
  local session_dir="$work_dir/sessions/$session_id"

  mkdir -p "$session_dir/layers/L4" \
           "$session_dir/layers/L5" \
           "$session_dir/cache"

  echo "$session_dir"
}

# Populate scan-state.json từ template với sed substitution.
# Args: template_path  output_path  session_id  project_path  [strategy]  [maturity_level]
init_scan_state() {
  local template="$1"
  local output="$2"
  local session_id="$3"
  local project_path="$4"
  local strategy="${5:-unknown}"
  local maturity="${6:-unknown}"
  local created_at
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ ! -f "$template" ]]; then
    log_error "Template not found: $template"
    return 1
  fi

  # Escape các giá trị cho sed (xử lý dấu / và &).
  local esc_path esc_strategy esc_maturity
  esc_path=$(printf '%s' "$project_path" | sed -e 's/[\/&]/\\&/g')
  esc_strategy=$(printf '%s' "$strategy" | sed -e 's/[\/&]/\\&/g')
  esc_maturity=$(printf '%s' "$maturity" | sed -e 's/[\/&]/\\&/g')

  sed \
    -e "s|{{SESSION_ID}}|$session_id|g" \
    -e "s|{{CREATED_AT_ISO8601}}|$created_at|g" \
    -e "s|{{CREATED_AT}}|$created_at|g" \
    -e "s|{{PROJECT_PATH}}|$esc_path|g" \
    -e "s|{{STRATEGY}}|$esc_strategy|g" \
    -e "s|{{MATURITY_LEVEL}}|$esc_maturity|g" \
    "$template" > "$output.tmp.$$"

  if ! validate_json "$output.tmp.$$"; then
    log_error "Populated scan-state.json invalid"
    rm -f "$output.tmp.$$"
    return 1
  fi

  mv "$output.tmp.$$" "$output"
  log_info "Initialized scan-state.json at $output"
}

# Khởi tạo session-log.json + error-ledger.json (empty).
init_session_aux_files() {
  local session_dir="$1"
  local session_id="$2"

  local session_log="$session_dir/session-log.json"
  local err_ledger="$session_dir/error-ledger.json"

  atomic_write_json "$session_log" \
    "$(printf '{"$schema":"session-log-v1","session_id":"%s","events":[]}' "$session_id")"

  atomic_write_json "$err_ledger" \
    "$(printf '{"$schema":"error-ledger-v1","session_id":"%s","errors":[]}' "$session_id")"
}

# ─── Deduplication ──────────────────────────────────────────

# Dedup CSV list, preserve order.
dedup_list() {
  local IFS=','
  read -ra ITEMS <<< "$1"
  printf '%s\n' "${ITEMS[@]}" | awk '!seen[$0]++' | tr '\n' ',' | sed 's/,$//'
}

# ─── UI Detection (shared with ui-coverage-scan.sh + inventory.sh) ──────
# Helpers dùng chung cho 2 scripts khi detect routes/screens cross-framework.
# Emit loops giữ nguyên per-script vì output shape khác nhau (snapshot vs manifest),
# nhưng helpers bên dưới loại bỏ ~100 dòng duplicate.

# Classify UI file type từ filename (Next.js App Router convention).
# Args: filename
# Echo: page|layout|error|loading|template|default|component
classify_ui_type() {
  case "$1" in
    page.*)      echo "page" ;;
    layout.*)    echo "layout" ;;
    error.*)     echo "error" ;;
    loading.*)   echo "loading" ;;
    template.*)  echo "template" ;;
    default.*)   echo "default" ;;
    not-found.*) echo "page" ;;
    *)           echo "component" ;;
  esac
}

# Kiểm tra filename có phải infrastructure screen không (Next.js conventions).
# Return 0 nếu là infrastructure, 1 nếu không.
# Args: filename
is_infra_name() {
  case "$1" in
    layout.*|error.*|loading.*|not-found.*|default.*|template.*|\
    global-error.*|head.*|middleware.*|\
    _app.*|_document.*|\
    opengraph-image.*|sitemap.*|robots.*|\
    favicon.*|icon.*|apple-icon.*|\
    route.*)
      return 0 ;;
    *) return 1 ;;
  esac
}

# Parse grep -n output: tách filepath + line content.
# Windows Git Bash: filepath có drive letter (z:/...) → không thể dùng ${match%%:*}.
# Ví dụ: "z:/foo/file.go:42:code" → GREP_FILE="z:/foo/file.go", GREP_LINE="code"
# Args: match_string
# Sets globals: GREP_FILE, GREP_LINE
parse_grep_match() {
  local match="$1"
  if [[ "$match" =~ ^([a-zA-Z]:)?([^:]*):([0-9]+):(.*)$ ]]; then
    GREP_FILE="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    GREP_LINE="${BASH_REMATCH[4]}"
  else
    GREP_FILE=""
    GREP_LINE=""
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

# Detect frontend framework presence flags từ package.json.
# Echo lên stdout dạng key=value space-separated:
#   "has_vue=false has_angular=false has_next=false has_react=false has_rn=false has_flutter=false"
# Caller eval output hoặc parse bằng read.
# Args: project_dir
detect_frontend_framework_flags() {
  local project_dir="$1"
  local has_vue="false" has_angular="false" has_next="false"
  local has_react="false" has_rn="false" has_flutter="false"

  local pkg_json="$project_dir/package.json"
  if [[ -f "$pkg_json" ]]; then
    local deps
    deps="$(tr -d '\n' < "$pkg_json" 2>/dev/null | grep -oE '"(next|react|react-native|expo|vue|@vue/cli|nuxt|@angular/core|svelte|@sveltejs/kit)"[[:space:]]*:[[:space:]]*"[^"]*"' || true)"
    echo "$deps" | grep -qi '"next"'           && has_next="true"
    echo "$deps" | grep -qi '"react"'          && has_react="true"
    echo "$deps" | grep -qi '"react-native"\|"expo"' && has_rn="true"
    echo "$deps" | grep -qi '"vue"\|"@vue/cli"\|"nuxt"' && has_vue="true"
    echo "$deps" | grep -qi '"@angular/core"'  && has_angular="true"
  fi

  # Flutter: check pubspec.yaml
  [[ -f "$project_dir/pubspec.yaml" ]] && has_flutter="true"
  if [[ -d "$project_dir" ]]; then
    local pubspec_count
    pubspec_count=$(find "$project_dir" -maxdepth 2 -name 'pubspec.yaml' 2>/dev/null | wc -l)
    [[ "$pubspec_count" -gt 0 ]] && has_flutter="true"
  fi

  echo "has_vue=$has_vue has_angular=$has_angular has_next=$has_next has_react=$has_react has_rn=$has_rn has_flutter=$has_flutter"
}

# Extract framework version từ package.json.
# Args: pkg_json framework_name
# Echo: version string or "unknown"
extract_framework_version() {
  local pkg_json="$1"
  local fw="$2"
  [[ ! -f "$pkg_json" ]] && { echo "unknown"; return; }

  local version
  version="$(grep -oE "\"$fw\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$pkg_json" 2>/dev/null \
    | grep -oE '"[^"]*"$' | tr -d '"' | sed 's/[^0-9.]//g;s/\.\([^.]*\)$//' | head -1 || echo "")"
  [[ -z "$version" ]] && version="unknown"
  echo "$version"
}

# Detect framework versions block (4 chính: next/react/vue/angular).
# Args: project_dir
# Echo key=value space-separated:
#   "fw_next_ver=1.0 fw_react_ver=18.0 fw_vue_ver=3.0 fw_angular_ver=16.0"
detect_framework_versions() {
  local project_dir="$1"
  local pkg_json="$project_dir/package.json"
  local fw_next_ver fw_react_ver fw_vue_ver fw_angular_ver
  fw_next_ver="$(extract_framework_version "$pkg_json" "next")"
  fw_react_ver="$(extract_framework_version "$pkg_json" "react")"
  fw_vue_ver="$(extract_framework_version "$pkg_json" "vue")"
  fw_angular_ver="$(extract_framework_version "$pkg_json" "@angular/core")"
  echo "fw_next_ver=$fw_next_ver fw_react_ver=$fw_react_ver fw_vue_ver=$fw_vue_ver fw_angular_ver=$fw_angular_ver"
}

# Strip Next.js App Router prefix từ directory path.
# Input: "app/dashboard/users" → "dashboard/users"
# Input: "src/app/dashboard"   → "dashboard"
# Input: "app"                 → ""
# Args: dir_path
strip_nextjs_app_prefix() {
  local dir_path="$1"
  case "$dir_path" in
    app|*/app)   dir_path="" ;;
    app/*)       dir_path="${dir_path#app/}" ;;
    */app/*)     dir_path="${dir_path#*/app/}" ;;
  esac
  echo "$dir_path"
}

# Strip Next.js Pages Router prefix từ directory path.
# Args: dir_path
strip_nextjs_pages_prefix() {
  local dir_path="$1"
  case "$dir_path" in
    pages|*/pages) dir_path="" ;;
    pages/*)       dir_path="${dir_path#pages/}" ;;
    */pages/*)     dir_path="${dir_path#*/pages/}" ;;
  esac
  echo "$dir_path"
}

# Clean Next.js parallel slots + route groups khỏi dir_path.
# - Strip /@slot/ hoặc @slot/ (parallel routes)
# - Strip (group)/ hoặc (group) (route groups)
# Args: dir_path
clean_nextjs_dir_path() {
  local dir_path="$1"
  dir_path="$(echo "$dir_path" | sed 's|/@[a-zA-Z]*||g;s|@[a-zA-Z]*/||g' || echo "$dir_path")"
  dir_path="$(echo "$dir_path" | sed 's|([^)]*)/||g;s|([^)]*)||g' || echo "$dir_path")"
  echo "$dir_path"
}

# Detect UI project root trong monorepo (apps/<name>/ có app|pages|src/app|src/pages).
# Args: project_dir
# Echo: "apps/<name>/" hoặc rỗng.
detect_ui_project_root() {
  local project_dir="$1"
  [[ ! -d "$project_dir/apps" ]] && { echo ""; return; }

  local app_dir app_name
  for app_dir in "$project_dir/apps"/*/; do
    [[ -d "$app_dir" ]] || continue
    if [[ -d "$app_dir/app" || -d "$app_dir/pages" \
       || -d "$app_dir/src/app" || -d "$app_dir/src/pages" ]]; then
      app_name="$(basename "$app_dir")"
      echo "apps/$app_name/"
      return
    fi
  done
  echo ""
}

# ─── Domain Detection (EN — v4.1-compatible) ────────────────

# Detect English domain hints via directory names.
# Phase C sẽ mở rộng với IPS Phase A integration + signals enrichment.
# Args: project_dir output_file
detect_domain_hints_en() {
  local project_dir="$1"
  local output_file="$2"

  local domains_json="["
  local first=1

  # Domain detection rules — synced với 10-vietnamese-keywords.md §2 (EN keywords).
  local -A domain_keywords=(
    ["finance"]="billing invoice payment tax ledger receipt"
    ["procurement"]="procurement sourcing vendor purchase rfq"
    ["sales"]="sales crm pipeline quote deal opportunity"
    ["hr"]="hr payroll leave attendance recruitment employee"
    ["ecommerce"]="cart checkout catalog product fulfillment sku"
    ["operations"]="inventory warehouse stock dispatch"
    ["compliance"]="audit compliance regulatory gdpr"
    ["healthcare"]="patient clinical prescription bhyt fhir hl7"
    ["logistics"]="shipping customs tms wms freight container"
    ["manufacturing"]="bom production mrp work-order"
    ["retail"]="pos store cashier loyalty"
    ["legal"]="contract legal nda msa clause"
    ["insurance"]="policy claim underwriting premium"
    ["education"]="course student lms enrollment curriculum"
  )

  local domain keywords confidence signals sigs_count keyword weight conf_decimal
  for domain in "${!domain_keywords[@]}"; do
    keywords="${domain_keywords[$domain]}"
    confidence=0
    signals="["
    sigs_count=0

    for keyword in $keywords; do
      if find "$project_dir" -maxdepth 4 -type d -iname "*${keyword}*" $(build_excludes) 2>/dev/null | head -1 | grep -q .; then
        weight=4  # 0.4 cho directory match
        confidence=$((confidence + weight))
        [[ $sigs_count -gt 0 ]] && signals+=","
        signals+="{\"type\":\"directory_name\",\"value\":\"$(json_escape "$keyword")\",\"weight\":0.4,\"lang\":\"en\"}"
        sigs_count=$((sigs_count + 1))
      fi
    done

    # Threshold: ≥0.4 confidence (v2.1 raised sẽ enforce ở Phase C IPS layer).
    if [[ $confidence -ge 4 ]]; then
      conf_decimal=$(awk "BEGIN {printf \"%.2f\", $confidence/10}")
      [[ $first -eq 0 ]] && domains_json+=","
      domains_json+="{\"domain\":\"$domain\",\"confidence\":$conf_decimal,\"language\":\"en\",\"signals\":${signals}],\"recommended_expert\":\"${domain}-expert\",\"recommended_agent_type\":\"${domain}-expert\"}"
      first=0
    fi
  done

  domains_json+="]"

  local final_json
  final_json="{\"\$schema\":\"domain-hints-v1\",\"version\":\"1.0\",\"scan_time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"detected_domains\":$domains_json,\"unresolved_patterns\":[],\"all_signals\":{\"package_deps\":[],\"directory_names\":[],\"import_patterns\":[],\"file_patterns\":[],\"vn_keywords\":[]}}"

  atomic_write_json "$output_file" "$final_json"
}

# Detect Vietnamese domain hints — delegates sang Python module.
# Phase B stub: chỉ log intention. Phase C sẽ implement call thật.
# Args: project_dir output_file
detect_domain_hints_vn() {
  local project_dir="$1"
  local output_file="$2"

  if ! has_python3; then
    log_warn "python3 not available — skipping VN domain detection"
    return 0
  fi

  log_debug "[Phase C TODO] Call: python -m workflow._shared.ips.vietnamese_keywords --project '$project_dir' --output '$output_file'"
  # Phase C sẽ replace log_debug bằng exec thật.
}

# ─── Cache Helpers ──────────────────────────────────────────
# Phase E sẽ wire các function này vào probe executor. Phase B giữ implementation
# để bash scripts downstream có thể dùng khi session_cache_enabled=true.

# Compute cache fingerprint (SHA256).
# Args: probe_id input_files...
cache_fingerprint() {
  local probe_id="$1"
  shift
  local input_hashes=""
  local f
  for f in "$@"; do
    [[ -f "$f" ]] && input_hashes+=$(file_hash "$f")
  done
  if command -v sha256sum &>/dev/null; then
    echo -n "${probe_id}|${input_hashes}" | sha256sum | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    echo -n "${probe_id}|${input_hashes}" | shasum -a 256 | awk '{print $1}'
  else
    echo -n "${probe_id}|${input_hashes}" | md5sum | awk '{print $1}'
  fi
}

# Check cache hit. Returns 0 on hit, 1 on miss.
# Args: cache_dir fingerprint
cache_check() {
  local cache_dir="$1"
  local fingerprint="$2"
  local cache_file="$cache_dir/${fingerprint}.json"

  [[ ! -f "$cache_file" ]] && return 1

  if has_jq; then
    local produced_at
    produced_at=$(jq -r '.produced_at // empty' "$cache_file" 2>/dev/null)
    [[ -z "$produced_at" ]] && return 1

    local now_epoch prod_epoch age_days
    now_epoch=$(date -u +%s)
    prod_epoch=$(date -u -d "$produced_at" +%s 2>/dev/null \
                 || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$produced_at" +%s 2>/dev/null \
                 || echo 0)
    age_days=$(( (now_epoch - prod_epoch) / 86400 ))
    [[ $age_days -gt $CACHE_TTL_DAYS ]] && return 1
  fi

  return 0
}

# Write cache entry.
# Args: cache_dir fingerprint data_json
cache_write() {
  local cache_dir="$1"
  local fingerprint="$2"
  local data="$3"

  mkdir -p "$cache_dir"

  local entry
  entry=$(printf '{"$schema":"scan-cache-entry-v1","fingerprint":"sha256:%s","produced_at":"%s","produced_by":"%s@%s","ttl_days":%s,"data":%s}' \
    "$fingerprint" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "${USER:-unknown}" \
    "${HOSTNAME:-unknown}" \
    "$CACHE_TTL_DAYS" \
    "$data")

  atomic_write_json "$cache_dir/${fingerprint}.json" "$entry"
}

# Backward-compat aliases cho API khớp với §phase-B task spec.
cache_lookup() { cache_check "$@"; }
cache_store()  { cache_write "$@"; }

# ─── ledger.json Backward-Compat Generation (v2.1) ──────────
# Gọi ONCE bởi orchestrator tại POST Phase 4 synthesize.
# Projects scan-state.json → ledger.json v4.1 schema (read-only projection).
# Reference: ADR-LS04 revised.
#
# Args: session_dir  [output_path=.mc-data/work/legacy-scan/ledger.json]
generate_legacy_ledger() {
  local session_dir="$1"
  local output_path="${2:-.mc-data/work/legacy-scan/ledger.json}"

  if ! has_jq; then
    log_error "jq required for ledger generation"
    return 1
  fi

  local scan_state="$session_dir/scan-state.json"
  if [[ ! -s "$scan_state" ]]; then
    log_error "scan-state.json not found or empty at $scan_state"
    return 1
  fi

  mkdir -p "$(dirname "$output_path")"

  # Projection jq: scan-state.json → ledger.json v4.1 schema.
  jq '{
    "$schema": "ledger-v4.1",
    "generated_at": (now | todate),
    "session_id": .session.id,
    "strategy": {
      "id": .session.strategy,
      "reasoning": "Generated from scan-state (v2.1 — read-only projection, no reverse-sync)"
    },
    "maturity": {
      "level": .session.maturity_level,
      "stage_modes": (.depth_map | {
        classify: (if .L4 == "skip" then "skip" else "full" end),
        extract: (if .L5 == "skip" then "skip" else "full" end)
      })
    },
    "stages": {
      "detection":  { "status": (.layers.L1.status) },
      "assessment": { "status": (.layers.L2.status) },
      "inventory":  { "status": (.layers.L3.status) },
      "classify":   { "status": (.layers.L4.status) },
      "extract":    { "status": (.layers.L5.status) },
      "synthesize": { "status": (.layers.L6.status) }
    },
    "summary": {
      "total_items": 0,
      "low_confidence_modules": ((.layers.L5.metadata.low_confidence_modules) // [])
    },
    "errors": (.error_log // []),
    "pipeline_status": (if .status == "completed" then "COMPLETE" else "IN_PROGRESS" end)
  }' "$scan_state" > "${output_path}.tmp.$$"

  if ! validate_json "${output_path}.tmp.$$"; then
    log_error "Generated ledger.json invalid"
    rm -f "${output_path}.tmp.$$"
    return 1
  fi

  mv "${output_path}.tmp.$$" "$output_path"
  log_info "ledger.json generated (v4.1 projection) at $output_path"
}

# ─── Library loaded marker ──────────────────────────────────
readonly _LEGACY_SCAN_COMMON_LOADED=1
log_info "legacy-scan-common.sh v${LEGACY_SCAN_COMMON_VERSION} loaded"
