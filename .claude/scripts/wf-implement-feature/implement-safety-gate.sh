#!/usr/bin/env bash
# implement-safety-gate.sh — CORE-020 Pre-Implementation Safety Gate.
# Search existing code TRƯỚC khi viết mới để tránh duplicate/silent overwrite.
#
# Usage:
#   bash implement-safety-gate.sh \
#     --req-id=REQ-CRM-CUST-001 \
#     --feature-name="Customer Management" \
#     --search-terms=customer,Customer,CustomerService \
#     --cwd=. \
#     [--source-dirs=src,apps]
#
# Args:
#   --req-id=<id>         REQ-ID (required, dùng grep tìm REQ-ID comments)
#   --feature-name=<name> Feature name (optional, fallback search)
#   --search-terms=<csv>  Comma-separated search terms (entity/component/endpoint names)
#   --cwd=<path>          Project root (default: current dir)
#   --source-dirs=<csv>   Search dirs (default: src,apps,packages)
#
# Output (stdout): JSON
#   {
#     "existing_files": ["src/modules/crm/customer.entity.ts"],
#     "existing_endpoints": ["POST /customers"],
#     "existing_components": ["CustomerListPage"],
#     "files_with_req_id": ["src/modules/crm/customer.service.ts"],
#     "found_count": 4,
#     "scanned_dirs": ["src","apps"],
#     "scanned_at": "2026-04-28T..."
#   }
#
# Exit codes:
#   0 = scan completed (regardless of found_count)
#   1 = invalid args / cwd missing

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

REQ_ID=""
FEATURE_NAME=""
SEARCH_TERMS=""
CWD="."
SOURCE_DIRS="src,apps,packages"

for arg in "$@"; do
  case "$arg" in
    --req-id=*)        REQ_ID="${arg#*=}" ;;
    --feature-name=*)  FEATURE_NAME="${arg#*=}" ;;
    --search-terms=*)  SEARCH_TERMS="${arg#*=}" ;;
    --cwd=*)           CWD="${arg#*=}" ;;
    --source-dirs=*)   SOURCE_DIRS="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

[[ -z "$REQ_ID" && -z "$SEARCH_TERMS" ]] && {
  log_error "--req-id hoặc --search-terms required"
  exit 1
}
[[ ! -d "$CWD" ]] && { log_error "CWD không tồn tại: $CWD"; exit 1; }

cd "$CWD" || exit 1

# Build list of existing source dirs (skip dirs không tồn tại)
SCAN_DIRS=()
IFS=',' read -ra DIR_ARRAY <<< "$SOURCE_DIRS"
for d in "${DIR_ARRAY[@]}"; do
  d="${d// /}"
  [[ -d "$d" ]] && SCAN_DIRS+=("$d")
done

if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
  # Fallback: project root
  SCAN_DIRS=(".")
fi

# Common excludes (đồng bộ với scan-target-common.sh)
EXCLUDE_GREP=(
  --exclude-dir=node_modules
  --exclude-dir=.git
  --exclude-dir=dist
  --exclude-dir=build
  --exclude-dir=.next
  --exclude-dir=coverage
  --exclude-dir=__pycache__
  --exclude-dir=.venv
  --exclude-dir=venv
  --exclude-dir=bin
  --exclude-dir=obj
  --exclude-dir=target
  --exclude-dir=.mc-data
  --exclude-dir=.cache
)

# ─── 1. Files with REQ-ID comment ────────────────────────────

FILES_WITH_REQ_ID=()
if [[ -n "$REQ_ID" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && FILES_WITH_REQ_ID+=("$line")
  done < <(grep -rl --binary-files=without-match "${EXCLUDE_GREP[@]}" -E "REQ-ID[: ]*$REQ_ID\b|FEAT-ID[: ]*$REQ_ID\b" "${SCAN_DIRS[@]}" 2>/dev/null || true)
fi

# ─── 2. Files with search terms (entity/service/component names) ──

EXISTING_FILES=()
EXISTING_COMPONENTS=()

if [[ -n "$SEARCH_TERMS" ]]; then
  IFS=',' read -ra TERM_ARRAY <<< "$SEARCH_TERMS"
  for term in "${TERM_ARRAY[@]}"; do
    term="${term// /}"
    [[ -z "$term" ]] && continue

    # File name search (entity/service/component pattern)
    while IFS= read -r f; do
      [[ -n "$f" ]] && EXISTING_FILES+=("$f")
    done < <(find "${SCAN_DIRS[@]}" -type f \
      \( -name "*${term}*.entity.ts" -o -name "*${term}*.service.ts" -o -name "*${term}*.controller.ts" \
         -o -name "*${term}*.model.ts" -o -name "*${term}*.repository.ts" \
         -o -iname "${term}.py" -o -iname "${term}_service.py" \
         -o -iname "${term}.cs" -o -iname "${term}Service.cs" -o -iname "${term}Controller.cs" \
         -o -iname "${term}.go" -o -iname "${term}_test.go" \) \
      ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
      ! -path "*/.mc-data/*" ! -path "*/__pycache__/*" 2>/dev/null | head -50 || true)

    # Component name search (frontend)
    while IFS= read -r f; do
      [[ -n "$f" ]] && EXISTING_COMPONENTS+=("$f")
    done < <(find "${SCAN_DIRS[@]}" -type f \
      \( -name "*${term}*.tsx" -o -name "*${term}*.vue" -o -name "*${term}*Page.tsx" -o -name "*${term}*Component.tsx" \) \
      ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
      ! -path "*/.mc-data/*" 2>/dev/null | head -20 || true)
  done
fi

# ─── 3. Existing endpoints (route/controller scan) ───────────

EXISTING_ENDPOINTS=()
if [[ -n "$SEARCH_TERMS" ]]; then
  for term in "${TERM_ARRAY[@]}"; do
    term="${term// /}"
    [[ -z "$term" ]] && continue

    # Pattern: @Get/@Post/@Put/@Delete decorator + path containing term (Nest/Express style)
    # Pattern: app.get('/term...', router.post('/term...
    while IFS= read -r line; do
      [[ -n "$line" ]] && EXISTING_ENDPOINTS+=("$line")
    done < <(grep -rh --binary-files=without-match "${EXCLUDE_GREP[@]}" -E \
      "@(Get|Post|Put|Delete|Patch)\([\"'][^\"']*$term[^\"']*[\"']\)|\.(get|post|put|delete|patch)\([\"'][^\"']*$term[^\"']*[\"']" \
      "${SCAN_DIRS[@]}" 2>/dev/null \
      | head -30 \
      | sed -E "s/.*@(Get|Post|Put|Delete|Patch)\([\"']([^\"']+)[\"']\).*/\1 \2/; s/.*\.(get|post|put|delete|patch)\([\"']([^\"']+)[\"'].*/\1 \2/" \
      | tr '[:lower:]' '[:upper:]' | sort -u || true)
  done
fi

# ─── 4. Dedup arrays ─────────────────────────────────────────

dedup_array_to_jsonarr() {
  local -n arr=$1
  if (( ${#arr[@]} == 0 )); then
    echo "[]"
    return
  fi
  if has_jq; then
    printf '%s\n' "${arr[@]}" | sort -u | jq -R . | jq -s .
  else
    # Fallback raw JSON
    local out="["
    local sep=""
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      out="$out$sep\"$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
      sep=","
    done < <(printf '%s\n' "${arr[@]}" | sort -u)
    echo "$out]"
  fi
}

FILES_REQ_JSON=$(dedup_array_to_jsonarr FILES_WITH_REQ_ID)
EXISTING_FILES_JSON=$(dedup_array_to_jsonarr EXISTING_FILES)
EXISTING_COMP_JSON=$(dedup_array_to_jsonarr EXISTING_COMPONENTS)
EXISTING_ENDPOINTS_JSON=$(dedup_array_to_jsonarr EXISTING_ENDPOINTS)

# ─── 5. Build output JSON ────────────────────────────────────

cd - >/dev/null || true

if has_jq; then
  RESULT=$(jq -nc \
    --argjson files "$EXISTING_FILES_JSON" \
    --argjson endpoints "$EXISTING_ENDPOINTS_JSON" \
    --argjson components "$EXISTING_COMP_JSON" \
    --argjson req_files "$FILES_REQ_JSON" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg dirs "$(IFS=,; echo "${SCAN_DIRS[*]}")" \
    '{
      existing_files: $files,
      existing_endpoints: $endpoints,
      existing_components: $components,
      files_with_req_id: $req_files,
      found_count: (($files|length) + ($endpoints|length) + ($components|length) + ($req_files|length)),
      scanned_dirs: ($dirs | split(",")),
      scanned_at: $ts
    }')
  echo "$RESULT" | jq '.'
else
  TOTAL=$(( ${#EXISTING_FILES[@]} + ${#EXISTING_COMPONENTS[@]} + ${#EXISTING_ENDPOINTS[@]} + ${#FILES_WITH_REQ_ID[@]} ))
  echo "{\"existing_files\":$EXISTING_FILES_JSON,\"existing_endpoints\":$EXISTING_ENDPOINTS_JSON,\"existing_components\":$EXISTING_COMP_JSON,\"files_with_req_id\":$FILES_REQ_JSON,\"found_count\":$TOTAL,\"scanned_dirs\":[],\"scanned_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
fi

exit 0
