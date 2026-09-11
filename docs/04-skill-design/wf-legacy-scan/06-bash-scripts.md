# 06 — Bash Script Redesign

> **Đọc trước:** [05-profiles-ips.md](05-profiles-ips.md)
> **Đọc tiếp:** [07-migration-plan.md](07-migration-plan.md)

---

## 1. Tổng Quan Vấn Đề

Tổng 5 bash scripts liên quan (verified line counts):

| Script | Dòng | Vấn đề chính |
|--------|------|-------------|
| `legacy-scan-detect.sh` | 806 | Dead code, JSON bằng string concat, không schema validation |
| `legacy-scan-inventory.sh` | 1,062 | `head -N` hardcoded (40+ instances), circular dependency là stub, duplication ~300 dòng với ui-coverage-scan.sh |
| `legacy-scan-assess.sh` | 398 | Scoring overflow (clamp total only), staleness hardcoded 180 days, fragile timestamp parsing |
| `legacy-scan-staleness.sh` | 301 | `head` limits, fallback chain phức tạp |
| `ui-coverage-scan.sh` | 362 | ~200 dòng UI detection duplicate với inventory.sh |
| **Total** | **2,929** | |

**Common issues across all scripts:**
- JSON generation via heredoc + string concatenation → edge cases với special chars
- No post-write validation → invalid JSON silent
- Code duplication (`normalize_path`, `json_escape`, `EXCLUDE_DIRS`, logging)
- Hardcoded caps (`head -500`, `head -300`, `head -200`, `head -100`, `head -20`)
- No shared library — mỗi script tự định nghĩa helpers
- Cross-platform issues (Windows Git Bash `BASH_SOURCE` vs `$0`)

---

## 2. Shared Library: `legacy-scan-common.sh`

### 2.1 Design

Tạo file `.claude/scripts/legacy-scan-common.sh` chứa shared functions, constants, và validation helpers.

```bash
#!/usr/bin/env bash
# legacy-scan-common.sh — Shared library cho wf-legacy-scan bash scripts
# Version: 1.0
# Usage: 
#   SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPTS_DIR/legacy-scan-common.sh"
# 
# Cross-platform compatibility: Windows Git Bash + WSL + Linux + macOS
# - Uses BASH_SOURCE[0] instead of $0 for source path resolution
# - normalize_path() handles Windows C:\ → /c/ conversion

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───────────────────────────────────────────────

readonly LEGACY_SCAN_COMMON_VERSION="1.0"
readonly DEFAULT_EXCLUDE_DIRS=(
  node_modules .git dist build .next .nuxt out coverage
  .cache .turbo vendor __pycache__ .venv venv .env .idea .vscode
  bin obj Debug Release packages .gradle .mvn target tmp
)

# Configurable caps (environment variable overrides)
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

# ─── Logging ────────────────────────────────────────────────

# _SCRIPT_NAME set by sourcing script: _SCRIPT_NAME="legacy-scan-detect"
log_info()  { echo "[${_SCRIPT_NAME:-scan}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-scan}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-scan}] ERROR: $*" >&2; }
log_debug() { [[ "${LEGACY_SCAN_DEBUG:-0}" == "1" ]] && echo "[${_SCRIPT_NAME:-scan}] DEBUG: $*" >&2 || true; }

# ─── Path Helpers ───────────────────────────────────────────

# Normalize Windows paths to Unix-like (for Git Bash)
normalize_path() {
  local p="$1"
  p="${p//\\//}"           # backslash → forward slash
  if [[ "$p" =~ ^([A-Za-z]):/ ]]; then
    local drive="${BASH_REMATCH[1]}"
    p="/${drive,,}/${p:3}" # C:/ → /c/
  fi
  echo "$p"
}

# Resolve absolute path cross-platform
abs_path() {
  local p="$1"
  if command -v realpath &>/dev/null; then
    realpath "$p" 2>/dev/null || echo "$p"
  else
    (cd "$(dirname "$p")" 2>/dev/null && echo "$(pwd)/$(basename "$p")") || echo "$p"
  fi
}

# ─── JSON Helpers ───────────────────────────────────────────

# Check if jq is available
has_jq() { command -v jq &>/dev/null; }

# Escape string for JSON embedding
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"      # \ → \\
  s="${s//\"/\\\"}"       # " → \"
  s="${s//$'\n'/\\n}"     # newline → \n
  s="${s//$'\t'/\\t}"     # tab → \t
  s="${s//$'\r'/}"        # strip CR
  echo "$s"
}

# Validate JSON file (silent — return 0 if valid, 1 if invalid)
validate_json() {
  local f="$1"
  if has_jq; then
    jq empty "$f" 2>/dev/null
  else
    # Fallback: check starts with { or [
    local first
    first=$(head -c1 "$f" 2>/dev/null)
    [[ "$first" == "{" || "$first" == "[" ]]
  fi
}

# Atomic write JSON: write to temp, validate, then move
# Usage: atomic_write_json "/path/to/output.json" "$json_content"
atomic_write_json() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"

  printf '%s' "$content" > "$tmp"

  if has_jq; then
    if ! jq empty "$tmp" 2>/dev/null; then
      log_error "atomic_write_json: invalid JSON for $target"
      log_error "Content preview: $(head -c200 "$tmp")"
      rm -f "$tmp"
      return 1
    fi
  fi

  mv "$tmp" "$target"
  log_debug "Wrote $target ($(wc -c < "$target") bytes)"
}

# Pretty-print JSON inline (uses jq if available)
json_pretty() {
  local content="$1"
  if has_jq; then
    echo "$content" | jq '.'
  else
    echo "$content"
  fi
}

# ─── File Helpers ───────────────────────────────────────────

# Build find exclusion arguments
# Usage: find "$dir" $(build_excludes) -type f
build_excludes() {
  local exclude_args=()
  for dir in "${DEFAULT_EXCLUDE_DIRS[@]}"; do
    exclude_args+=( -not -path "*/$dir/*" )
  done
  echo "${exclude_args[*]}"
}

# Count files by extension list
count_by_ext() {
  local dir="$1"
  shift
  local exts=("$@")
  local pattern=""
  for ext in "${exts[@]}"; do
    [[ -n "$pattern" ]] && pattern+=" -o"
    pattern+=" -name '*.$ext'"
  done
  eval find "$dir" $(build_excludes) -type f \\( $pattern \\) 2>/dev/null | wc -l
}

# Compute file content hash (SHA256)
file_hash() {
  local f="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    log_warn "No SHA256 tool available, using mtime fallback"
    stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f"
  fi
}

# ─── Domain Detection ───────────────────────────────────────

# Output: domain-hints.json (preliminary)
# Args: project_dir output_file
detect_domain_hints() {
  local project_dir="$1"
  local output_file="$2"
  
  local domains_json="["
  local first=1
  
  # Domain detection rules — synced với 02-scan-layers.md §SL5
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
  
  for domain in "${!domain_keywords[@]}"; do
    local keywords="${domain_keywords[$domain]}"
    local confidence=0
    local signals="["
    local sigs_count=0
    
    # Check directory names
    for keyword in $keywords; do
      if find "$project_dir" -maxdepth 4 -type d -iname "*${keyword}*" $(build_excludes) 2>/dev/null | head -1 | grep -q .; then
        local weight=4   # 0.4 for dir match
        confidence=$((confidence + weight))
        [[ $sigs_count -gt 0 ]] && signals+=","
        signals+="{\"type\":\"directory_name\",\"value\":\"$(json_escape "$keyword")\",\"weight\":0.4}"
        sigs_count=$((sigs_count + 1))
      fi
    done
    
    # Threshold for inclusion (>= 0.4 confidence)
    if [[ $confidence -ge 4 ]]; then
      local conf_decimal=$(awk "BEGIN {printf \"%.2f\", $confidence/10}")
      [[ $first -eq 0 ]] && domains_json+=","
      domains_json+="{\"domain\":\"$domain\",\"confidence\":$conf_decimal,\"signals\":${signals}],\"recommended_expert\":\"${domain}-expert\"}"
      first=0
    fi
  done
  
  domains_json+="]"
  
  local final_json="{\"\$schema\":\"domain-hints-v1\",\"detected_domains\":$domains_json,\"scan_time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
  atomic_write_json "$output_file" "$final_json"
}

# ─── Deduplication ──────────────────────────────────────────

# Dedup CSV list, preserve order
dedup_list() {
  local IFS=','
  read -ra ITEMS <<< "$1"
  printf '%s\n' "${ITEMS[@]}" | awk '!seen[$0]++' | tr '\n' ',' | sed 's/,$//'
}

# ─── Cache Helpers ──────────────────────────────────────────

# Compute cache fingerprint
# Args: probe_id input_files... 
cache_fingerprint() {
  local probe_id="$1"
  shift
  local input_hashes=""
  for f in "$@"; do
    [[ -f "$f" ]] && input_hashes+=$(file_hash "$f")
  done
  if command -v sha256sum &>/dev/null; then
    echo -n "${probe_id}|${input_hashes}" | sha256sum | awk '{print $1}'
  else
    echo -n "${probe_id}|${input_hashes}" | shasum -a 256 | awk '{print $1}'
  fi
}

# Check cache hit
# Args: cache_dir fingerprint
cache_check() {
  local cache_dir="$1"
  local fingerprint="$2"
  local cache_file="$cache_dir/${fingerprint}.json"
  
  [[ ! -f "$cache_file" ]] && return 1
  
  # Check TTL
  if has_jq; then
    local produced_at=$(jq -r '.produced_at // empty' "$cache_file" 2>/dev/null)
    [[ -z "$produced_at" ]] && return 1
    
    # Compute age
    local now_epoch=$(date -u +%s)
    local prod_epoch=$(date -u -d "$produced_at" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$produced_at" +%s 2>/dev/null)
    local age_days=$(( (now_epoch - prod_epoch) / 86400 ))
    
    [[ $age_days -gt $CACHE_TTL_DAYS ]] && return 1
  fi
  
  return 0
}

# Write cache entry
# Args: cache_dir fingerprint data_json
cache_write() {
  local cache_dir="$1"
  local fingerprint="$2"
  local data="$3"
  
  mkdir -p "$cache_dir"
  
  local entry="{
    \"\$schema\": \"scan-cache-entry-v1\",
    \"fingerprint\": \"sha256:$fingerprint\",
    \"produced_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"produced_by\": \"${USER:-unknown}@${HOSTNAME:-unknown}\",
    \"ttl_days\": $CACHE_TTL_DAYS,
    \"data\": $data
  }"
  
  atomic_write_json "$cache_dir/${fingerprint}.json" "$entry"
}

# ─── Library loaded marker ──────────────────────────────────
readonly _LEGACY_SCAN_COMMON_LOADED=1
log_debug "legacy-scan-common.sh v$LEGACY_SCAN_COMMON_VERSION loaded"
```

### 2.2 Cross-Platform Compatibility

**Issue:** `source` path resolution khác biệt giữa Linux/macOS và Windows Git Bash.

**Solutions:**
1. Sử dụng `BASH_SOURCE[0]` thay vì `$0` để resolve script directory.
2. `SCRIPTS_DIR` constant tự động normalize Windows paths.
3. `normalize_path()` function xử lý `C:\` → `/c/` conversion.
4. `file_hash()` dùng `sha256sum` (Linux) hoặc `shasum -a 256` (macOS) fallback.
5. `date -d` (Linux) vs `date -j -f` (macOS) handled.

**Test matrix:**
- Windows Git Bash (mingw64)
- WSL2 Ubuntu
- Linux Debian/Ubuntu
- macOS Darwin

**Sourcing pattern (chuẩn cho mọi script):**

```bash
# Standard pattern — works on all platforms
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/legacy-scan-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
```

### 2.3 Benefits

| Trước | Sau |
|-------|-----|
| `json_escape()` defined in each script | 1 definition in common.sh |
| `normalize_path()` defined in each script | 1 definition in common.sh |
| `EXCLUDE_DIRS` array in each script | 1 constant + `build_excludes()` |
| Logging reinvented per script | `log_info/warn/error/debug` shared |
| No JSON validation | `validate_json()` + `atomic_write_json()` |
| Hardcoded caps | Environment variable overrides |
| No jq usage | `has_jq()` detection + jq validation when available |
| No cache support | `cache_check`, `cache_write`, `cache_fingerprint` |
| No domain detection | `detect_domain_hints()` shared |

---

## 3. Script-by-Script Improvements

### 3.1 `legacy-scan-detect.sh` (L1 — Discovery)

**Changes:**

| Item | Before | After |
|------|--------|-------|
| JSON generation | Heredoc + string concat | `atomic_write_json()` |
| Dead code | `file_contains` unused | Remove |
| Validation | None | `validate_json()` post-write |
| Domain hints | None | Add `detect_domain_hints()` call (preliminary) |
| Shared functions | Duplicated | `source legacy-scan-common.sh` |
| Cross-platform | $0 ambiguity | BASH_SOURCE[0] |

**New output:** `domain-hints.json` (preliminary, enriched by L2)

**Estimated line reduction:** 806 → ~640 (shared library absorbs ~170 lines, dead code removal)

### 3.2 `legacy-scan-inventory.sh` (L3 — Inventory)

**Changes:**

| Item | Before | After |
|------|--------|-------|
| `head -500` API cap | Hardcoded | `$MAX_API_ENDPOINTS` (configurable) |
| `head -300` screen cap | Hardcoded | `$MAX_SCREENS` (configurable) |
| `head -200` import files cap | Hardcoded | `$MAX_IMPORT_FILES` (configurable) |
| `head -20` imports per file | Hardcoded | `$MAX_IMPORTS_PER_FILE` (configurable) |
| Circular dependency | Stub (`"circular": []`) | Basic cycle detection via DFS coloring |
| UI detection code | ~300 lines duplicated với ui-coverage-scan.sh | Extract to shared functions in common.sh |
| JSON generation | String concat per file | `atomic_write_json()` per file |
| Import analysis | Hardcoded limits | Configurable + cache-aware |
| Schema validation | None | `validate_json()` per output file |

**Circular dependency detection (basic — DFS coloring):**

```bash
# detect_cycles deps_file
# Reads adjacency list JSON, returns cycles array (or empty)
detect_cycles() {
  local deps_file="$1"
  
  if ! has_jq; then
    log_warn "jq not available, skipping circular dependency detection"
    echo "[]"
    return 0
  fi
  
  # DFS with coloring (WHITE/GRAY/BLACK)
  # Implementation in inventory.sh — calls jq + bash arrays
  # Output: JSON array of cycle paths
  
  jq -c '
    .modules as $modules |
    [
      $modules[] | 
      . as $m |
      # Simplified DFS — real impl in inventory.sh
      select(.dependencies | length > 0) |
      {module: .id, fanout: (.dependencies | length)}
    ]
  ' "$deps_file"
}
```

**Estimated line reduction:** 1,062 → ~720 (shared library + dedup absorb ~340 lines)

### 3.3 `legacy-scan-assess.sh` (L2 — Assessment)

**Changes:**

| Item | Before | After |
|------|--------|-------|
| Scoring overflow | Clamp total only | Clamp per-component (fix overflow bug) |
| Staleness threshold | Hardcoded 180 days | `$STALE_THRESHOLD_DAYS` (configurable) |
| Domain hints enrichment | None | Read L1 domain-hints.json, enrich với assessment signals + import patterns |
| Timestamp handling | `date -d` with fallbacks | `has_jq` → use jq for date parsing; fallback platform-specific |
| JSON output | String concat | `atomic_write_json()` |
| Strategy selection | In-script logic | Cleaner separation |

**Scoring fix (per-component clamp):**

```bash
# Before (v4.1) — overflow possible:
code_score=$((base + test_bonus + lint + ci + ts_strict))
[ "$code_score" -gt 100 ] && code_score=100  # late clamp

# After (v5.0) — per-component cap:
lint_score=$((lint_checks))
[ "$lint_score" -gt 25 ] && lint_score=25    # per-component cap
ci_score=$((ci_checks))
[ "$ci_score" -gt 15 ] && ci_score=15        # per-component cap
test_bonus=$((test_count > 0 ? 10 : 0))
[ "$test_bonus" -gt 10 ] && test_bonus=10    # per-component cap

code_score=$((base + test_bonus + lint_score + ci_score + ts_strict))
[ "$code_score" -gt 100 ] && code_score=100  # final safety clamp
```

**Domain enrichment (new):**

```bash
# Read L1 domain-hints.json (preliminary)
# Add assessment-based signals:
# - File pattern signals (*.ledger.ts → finance, *.patient.ts → healthcare)
# - Import pattern signals (sample top imports → grep domain keywords)
# Update domain-hints.json with enriched confidence
enrich_domain_hints() {
  local domain_file="$1"
  local source_files="$2"
  
  # Sample top 100 source files for import patterns
  local samples=$(jq -r '.files[].path' "$source_files" | head -100)
  # Grep for domain keywords in samples
  # Update confidence scores in domain_file
}
```

**Estimated line reduction:** 398 → ~310 (shared library + cleanup)

### 3.4 `legacy-scan-staleness.sh`

**Changes:**

| Item | Before | After |
|------|--------|-------|
| `head -1000` limit | Hardcoded | Configurable via env var |
| `head -500` limit | Hardcoded | Configurable |
| Timestamp parsing | 3-way fallback chain | Use `jq` for ISO parse when available; clearer fallback |
| Output format | Plain JSON string | `atomic_write_json()` |
| Cache integration | None | Use cache_fingerprint for delta detection |

**Estimated line reduction:** 301 → ~230

### 3.5 `ui-coverage-scan.sh`

**Changes:**

| Item | Before | After |
|------|--------|-------|
| UI detection (~200 lines) | Duplicated với inventory.sh | Source shared functions from common.sh |
| Logging | Inline | Use shared `log_*` functions |
| Path normalization | Inline | Use `normalize_path` |
| JSON output | String concat | `atomic_write_json()` |

**Estimated line reduction:** 362 → ~150 (UI detection moved to shared)

---

## 4. UI Detection Deduplication

### 4.1 Problem

`legacy-scan-inventory.sh` (lines ~380-680) và `ui-coverage-scan.sh` (lines ~80-280) chia sẻ code near-identical cho:
- Framework version detection from package.json
- React Router route extraction
- Vue Router route extraction
- Angular routing module detection
- Next.js App/Pages Router detection
- UI screen deduplication logic

### 4.2 Solution

Extract shared UI detection functions vào `legacy-scan-common.sh`:

```bash
# ─── UI Detection (shared with ui-coverage-scan.sh) ───────

# Detect framework + version from package.json
detect_frameworks() {
  local project_dir="$1"
  local pkg_json="$project_dir/package.json"
  
  [[ ! -f "$pkg_json" ]] && echo '{"frameworks": []}' && return
  
  if has_jq; then
    jq -c '{
      frameworks: [
        (.dependencies // {}) * (.devDependencies // {}) |
        to_entries |
        .[] |
        select(.key | test("^(react|vue|@angular/core|next|nuxt|svelte|astro|remix)$")) |
        {name: .key, version: .value}
      ]
    }' "$pkg_json"
  else
    echo '{"frameworks": []}'  # fallback
  fi
}

# Detect Next.js App Router routes
detect_nextjs_app_routes() {
  local project_dir="$1"
  local app_dir
  for candidate in "app" "src/app" "apps/web/app" "apps/web/src/app"; do
    [[ -d "$project_dir/$candidate" ]] && app_dir="$project_dir/$candidate" && break
  done
  [[ -z "${app_dir:-}" ]] && return
  
  # Find all page.tsx/page.jsx/page.ts/page.js files
  find "$app_dir" -type f \( -name "page.tsx" -o -name "page.jsx" -o -name "page.ts" -o -name "page.js" \) $(build_excludes) | head -"$MAX_SCREENS"
}

# Detect Next.js Pages Router routes
detect_nextjs_pages_routes() { ... }

# Detect React Router routes
detect_react_routes() { ... }

# Detect Vue routes
detect_vue_routes() { ... }

# Detect Angular routes
detect_angular_routes() { ... }

# Build UI manifest from detected routes
build_ui_manifest() {
  local screens_json="$1"
  local frameworks_json="$2"
  local output="$3"
  
  if has_jq; then
    jq -s --slurpfile frameworks "$frameworks_json" '
      {
        "$schema": "ui-manifest-v1",
        "frameworks": $frameworks[0].frameworks,
        "screens": .,
        "coverage": {
          "total_screens": length,
          "screens_with_routes": [.[] | select(.route != null)] | length
        }
      }
    ' "$screens_json" > "$output"
  fi
}
```

### 4.3 Impact

| File | Before (duplicated lines) | After |
|------|--------------------------|-------|
| `legacy-scan-inventory.sh` | ~300 lines UI detection | Call shared functions |
| `ui-coverage-scan.sh` | ~200 lines UI detection | Call shared functions |
| `legacy-scan-common.sh` | 0 | ~250 lines (new shared) |
| **Net reduction** | — | **~250 lines removed** |

---

## 5. jq Integration Strategy

### 5.1 Principle: Use jq when available, graceful fallback

```bash
if has_jq; then
  # Validate all JSON outputs
  for f in "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/inventory/*.json; do
    [[ -f "$f" ]] && validate_json "$f" || log_error "Invalid JSON: $f"
  done
else
  log_warn "jq not found. Skipping JSON validation. Install jq for robust output."
fi
```

### 5.2 Where jq is used

| Usage | Required? | Fallback |
|-------|-----------|----------|
| Post-write JSON validation | Recommended | Skip + warn |
| Atomic write (temp + validate + mv) | Recommended | Direct write |
| Domain hint generation | Optional | Basic grep-based |
| Assessment score calculation | Optional | Bash arithmetic expansion |
| Cache fingerprint (read entries) | Recommended | Skip cache + warn |
| UI manifest build | Recommended | Skip (manifest optional) |
| Circular dependency detection | Required | Skip + return empty array |

### 5.3 No jq dependency for core functionality

Core script functionality (detect, assess, inventory) **vẫn chạy được không cần jq**. jq chỉ dùng cho validation và enhanced features. Fallback behavior documented per script.

**Recommendation:** Display install hint at script start:

```bash
if ! has_jq; then
  log_warn "jq not installed. Some features will be degraded:"
  log_warn "  - JSON validation skipped"
  log_warn "  - Cache integration limited"
  log_warn "  - Circular dependency detection skipped"
  log_warn "Install: brew install jq | apt install jq | scoop install jq"
fi
```

---

## 6. Implementation Order

```
Phase 1: Create legacy-scan-common.sh
  ├── Extract shared functions từ all 4 scripts
  ├── Add new shared functions (validate_json, atomic_write_json, cache_*, etc.)
  ├── Add UI detection shared functions
  └── Test on Windows Git Bash + WSL + Linux + macOS

Phase 2: Refactor legacy-scan-detect.sh (simplest, least risk)
  ├── Source common.sh
  ├── Replace duplicated functions với shared
  ├── Add domain-hints.json generation (preliminary)
  ├── Add jq validation
  └── Test: run on test project, compare output với v4.1 baseline

Phase 3: Refactor legacy-scan-assess.sh
  ├── Source common.sh
  ├── Fix scoring overflow (per-component clamp)
  ├── Add configurable staleness threshold
  ├── Add domain hints enrichment
  ├── Add jq validation
  └── Test: scoring comparison với v4.1

Phase 4: Refactor legacy-scan-inventory.sh (largest, most risk)
  ├── Source common.sh
  ├── Replace UI detection với shared functions
  ├── Make caps configurable
  ├── Implement basic circular dependency detection (replace stub)
  ├── Add jq validation per output
  ├── Add cache integration
  └── Test: inventory comparison với v4.1

Phase 5: Update ui-coverage-scan.sh
  ├── Source common.sh
  ├── Replace UI detection với shared functions
  ├── Add jq validation
  └── Test: UI coverage output unchanged

Phase 6: Refactor legacy-scan-staleness.sh
  ├── Source common.sh
  ├── Add configurable limits
  ├── Add cache fingerprint integration
  └── Test: staleness detection

Phase 7: Add new bash helpers (cache, fingerprint)
  ├── Cache management commands
  └── Test cache hit/miss scenarios
```

---

## 7. Testing Strategy

### 7.1 Unit Tests (per function)

Cho mỗi shared function:
- Input validation
- Edge cases (empty, special chars, Unicode)
- Cross-platform behavior

### 7.2 Integration Tests

Cho mỗi script:
- Run on small test project (10 files) — compare output với golden file
- Run on medium test project (200 files) — performance baseline
- Run on large test project (1,500 files) — stress test
- Crash injection (kill mid-script) — verify atomic write doesn't corrupt
- Run with `LEGACY_SCAN_DEBUG=1` for verbose logging

### 7.3 Cross-Platform CI

GitHub Actions matrix:
- ubuntu-latest (Linux)
- macos-latest (Darwin)
- windows-latest (Git Bash)
- ubuntu-latest WSL emulation

### 7.4 Backward-Compat Tests

- Run v5.0 scripts on project that was scanned by v4.1
- Verify ledger.json compatible
- Verify downstream sub-skills (wf-legacy-classify, wf-legacy-extract) still work

---

## 8. Performance Targets

| Project Size | v4.1 Baseline | v5.0 Target | Improvement |
|--------------|---------------|-------------|-------------|
| Small (50 files) | 30s | ≤25s | -17% |
| Medium (500 files) | 90s | ≤75s | -17% |
| Large (1,500 files) | 300s | ≤240s | -20% |
| Very Large (5,000 files) | OOM/timeout | ≤600s with caps | Functional |

**Re-scan with cache:**

| Files Changed | Re-scan Time |
|---------------|--------------|
| 10% | ~30% of full scan |
| 30% | ~50% of full scan |
| 70% | ~90% of full scan (cache marginal) |

---

## 9. Total Line Count Summary

| Script | v4.1 | v5.0 | Delta |
|--------|------|------|-------|
| `legacy-scan-detect.sh` | 806 | ~640 | -166 |
| `legacy-scan-inventory.sh` | 1,062 | ~720 | -342 |
| `legacy-scan-assess.sh` | 398 | ~310 | -88 |
| `legacy-scan-staleness.sh` | 301 | ~230 | -71 |
| `ui-coverage-scan.sh` | 362 | ~150 | -212 |
| `legacy-scan-common.sh` | 0 | ~600 | +600 |
| **Total** | **2,929** | **~2,650** | **-279** |

Net reduction ~10%, but main benefit là:
- **0 dòng duplicated** (vs ~500 dòng before)
- **100% JSON validation** (vs 0% before)
- **Cross-platform robust** (vs Windows fragile before)
- **Configurable caps** (vs hardcoded before)
