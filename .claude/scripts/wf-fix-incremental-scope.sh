#!/usr/bin/env bash
# wf-fix-incremental-scope.sh — Map git diff changed files → restricted module list
#
# Usage:
#   bash wf-fix-incremental-scope.sh --since=<git-ref> \
#     [--project-root=<path>] [--registry=<path>] [--mapping=<path>] \
#     [--output=<path>]
#
# Output JSON (stdout or --output file):
#   {
#     "since_ref": "HEAD~5",
#     "changed_files": 12,
#     "modules": ["MOD-CRM", "MOD-QUOTATION"],
#     "module_count": 2,
#     "strategy": "mapping"
#   }
#
# Strategies (priority order):
#   mapping   — reads module-code-mapping.json source_file_prefixes (most accurate)
#   heuristic — path-slug matching against registry module IDs (fallback)
#   none      — git diff empty or registry absent → modules: []
#
# Exit codes:
#   0 = success (JSON written/printed)
#   1 = --since not provided
#   2 = git not available or invalid ref
#
# MCV3 wf-fix-bugs v9 — Wave 5.2 (Incremental scoping)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common helpers if available (atomic_write_json, jq_int, etc.)
COMMON_SH="$REPO_ROOT/.claude/scripts/wf-fix-common.sh"
if [[ -f "$COMMON_SH" ]]; then
  # shellcheck source=/dev/null
  source "$COMMON_SH"
fi

# ─── Argument parsing ─────────────────────────────────────────────────────────

SINCE_REF=""
PROJECT_ROOT=""
REGISTRY_PATH=""
MAPPING_PATH=""
OUTPUT_FILE=""

for _arg in "$@"; do
  case "$_arg" in
    --since=*)        SINCE_REF="${_arg#*=}" ;;
    --project-root=*) PROJECT_ROOT="${_arg#*=}" ;;
    --registry=*)     REGISTRY_PATH="${_arg#*=}" ;;
    --mapping=*)      MAPPING_PATH="${_arg#*=}" ;;
    --output=*)       OUTPUT_FILE="${_arg#*=}" ;;
    --help|-h)
      sed -n '2,/^set /p' "$0" | grep '^#' | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
  esac
done

# ─── Validate ─────────────────────────────────────────────────────────────────

if [[ -z "$SINCE_REF" ]]; then
  echo "ERROR: --since=<git-ref> is required" >&2
  echo "  Examples: --since=HEAD~10  --since=v1.0.0  --since=main" >&2
  exit 1
fi

# ─── Defaults ─────────────────────────────────────────────────────────────────

[[ -z "$PROJECT_ROOT" ]] && PROJECT_ROOT="$(pwd)"
[[ -z "$REGISTRY_PATH" ]] && REGISTRY_PATH="$PROJECT_ROOT/.mc-data/docs/_meta/req-registry.json"

# Locate module-code-mapping.json (check multiple candidate paths)
if [[ -z "$MAPPING_PATH" ]]; then
  for _candidate in \
    "$PROJECT_ROOT/.mc-data/work/legacy-scan/module-code-mapping.json" \
    "$PROJECT_ROOT/.mc-data/work/module-code-mapping.json" \
    "$PROJECT_ROOT/module-code-mapping.json"
  do
    if [[ -f "$_candidate" ]]; then
      MAPPING_PATH="$_candidate"
      break
    fi
  done
fi

# ─── Git validation ───────────────────────────────────────────────────────────

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found in PATH" >&2
  exit 2
fi

cd "$PROJECT_ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: $PROJECT_ROOT is not a git repository" >&2
  exit 2
fi

if ! git rev-parse "$SINCE_REF" >/dev/null 2>&1; then
  echo "ERROR: Invalid git ref: '$SINCE_REF'" >&2
  echo "  Use: git log --oneline -20  to find valid refs" >&2
  exit 2
fi

# ─── Git diff ─────────────────────────────────────────────────────────────────

# Collect changed files. tr -d '\r' strips CRLF on Git Bash/Windows.
CHANGED_FILES=()
while IFS= read -r _line; do
  _line="$(echo "$_line" | tr -d '\r')"
  [[ -z "$_line" ]] && continue
  CHANGED_FILES+=("$_line")
done < <(git diff --name-only "${SINCE_REF}" HEAD 2>/dev/null || true)

CHANGED_FILE_COUNT=${#CHANGED_FILES[@]}

# ─── Output helper ────────────────────────────────────────────────────────────

_write_result() {
  local json="$1"
  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    if declare -f atomic_write_json >/dev/null 2>&1; then
      atomic_write_json "$OUTPUT_FILE" "$json"
    else
      printf '%s\n' "$json" > "$OUTPUT_FILE"
    fi
  else
    printf '%s\n' "$json"
  fi
}

# ─── Empty diff ───────────────────────────────────────────────────────────────

if [[ $CHANGED_FILE_COUNT -eq 0 ]]; then
  _write_result "$(jq -n --arg ref "$SINCE_REF" \
    '{since_ref: $ref, changed_files: 0, modules: [], module_count: 0,
      strategy: "none", note: "No files changed since ref"}')"
  exit 0
fi

# ─── Dedup helper (add module only if not already present) ────────────────────

MATCHED_MODULES=()

_add_module() {
  local _mod="$1"
  [[ -z "$_mod" ]] && return
  if [[ ${#MATCHED_MODULES[@]} -gt 0 ]]; then
    local _existing
    for _existing in "${MATCHED_MODULES[@]}"; do
      [[ "$_existing" == "$_mod" ]] && return
    done
  fi
  MATCHED_MODULES+=("$_mod")
}

# Look up registry module ID given a doc_module slug
_lookup_mod_id() {
  local _slug="$1"
  [[ ! -f "$REGISTRY_PATH" ]] && return
  jq -r \
    --arg slug "$_slug" \
    '.modules[]? | select(
      (.id | ascii_downcase | ltrimstr("mod-") | ltrimstr("system-")) == $slug
    ) | .id' \
    "$REGISTRY_PATH" 2>/dev/null \
    | head -1 \
    | tr -d '\r'
}

# Check if any changed file starts with a given prefix
_files_match_prefix() {
  local _prefix="$1"
  [[ ${#CHANGED_FILES[@]} -eq 0 ]] && return 1
  local _f
  for _f in "${CHANGED_FILES[@]}"; do
    [[ "$_f" == ${_prefix}* ]] && return 0
  done
  return 1
}

# Check if any changed file path contains a slug segment (case-insensitive)
_files_match_slug() {
  local _slug="$1"
  [[ ${#CHANGED_FILES[@]} -eq 0 ]] && return 1
  local _f
  for _f in "${CHANGED_FILES[@]}"; do
    if echo "$_f" | grep -qi "/${_slug}/" 2>/dev/null \
       || echo "$_f" | grep -qi "^apps/${_slug}/" 2>/dev/null \
       || echo "$_f" | grep -qi "^src/${_slug}/" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

STRATEGY="none"

# ─── Strategy 1: module-code-mapping.json (source_file_prefixes) ──────────────

if [[ -n "$MAPPING_PATH" ]] && [[ -f "$MAPPING_PATH" ]]; then
  if jq -e '.mappings | length > 0' "$MAPPING_PATH" >/dev/null 2>&1; then
    STRATEGY="mapping"

    while IFS=$'\t' read -r _doc_module _prefixes_json; do
      _doc_module="$(echo "$_doc_module" | tr -d '\r')"
      _prefixes_json="$(echo "$_prefixes_json" | tr -d '\r')"
      [[ -z "$_doc_module" || "$_prefixes_json" == "null" || "$_prefixes_json" == "[]" ]] && continue

      _matched=false
      while IFS= read -r _prefix; do
        _prefix="$(echo "$_prefix" | tr -d '\r')"
        [[ -z "$_prefix" ]] && continue
        if _files_match_prefix "$_prefix"; then
          _matched=true
          break
        fi
      done < <(echo "$_prefixes_json" | jq -r '.[]?' 2>/dev/null || true)

      if [[ "$_matched" == "true" ]]; then
        _mod_id="$(_lookup_mod_id "$_doc_module")"
        if [[ -z "$_mod_id" ]]; then
          # Derive from slug: "crm" → "MOD-CRM"
          _mod_id="MOD-$(echo "$_doc_module" | tr '[:lower:]' '[:upper:]')"
        fi
        _add_module "$_mod_id"
      fi
    done < <(jq -r '.mappings[] | [.doc_module, (.source_file_prefixes // [])] | @tsv' \
      "$MAPPING_PATH" 2>/dev/null || true)
  fi
fi

# ─── Strategy 2: Heuristic — registry module ID slug matching ─────────────────

if [[ "$STRATEGY" == "none" ]] && [[ -f "$REGISTRY_PATH" ]]; then
  if jq -e '.modules | length > 0' "$REGISTRY_PATH" >/dev/null 2>&1; then
    STRATEGY="heuristic"

    while IFS= read -r _mod_id; do
      _mod_id="$(echo "$_mod_id" | tr -d '\r')"
      [[ -z "$_mod_id" ]] && continue

      # Derive slug variants:
      #   MOD-CRM          → slug=crm,           slug_last=crm
      #   MOD-LEGACY-ORDERS → slug=legacy-orders,  slug_last=orders
      _slug="$(echo "$_mod_id" | sed 's/^MOD-//' | tr '[:upper:]' '[:lower:]')"
      _slug_last="$(echo "$_slug" | sed 's/.*-//')"

      if _files_match_slug "$_slug"; then
        _add_module "$_mod_id"
      elif [[ "$_slug_last" != "$_slug" ]] && _files_match_slug "$_slug_last"; then
        _add_module "$_mod_id"
      fi
    done < <(jq -r '.modules[]?.id // empty' "$REGISTRY_PATH" 2>/dev/null || true)
  fi
fi

# ─── Build output JSON ────────────────────────────────────────────────────────

MODULE_COUNT=${#MATCHED_MODULES[@]}

MODULES_JSON="[]"
if [[ $MODULE_COUNT -gt 0 ]]; then
  MODULES_JSON=$(printf '%s\n' "${MATCHED_MODULES[@]}" | sort -u | jq -R . | jq -s .)
  MODULE_COUNT=$(echo "$MODULES_JSON" | jq 'length' | tr -d '\r')
fi

_write_result "$(jq -n \
  --arg ref "$SINCE_REF" \
  --argjson count "$CHANGED_FILE_COUNT" \
  --argjson modules "$MODULES_JSON" \
  --arg strategy "$STRATEGY" \
  --argjson module_count "$MODULE_COUNT" \
  '{
    since_ref:     $ref,
    changed_files: $count,
    modules:       $modules,
    module_count:  $module_count,
    strategy:      $strategy
  }')"
