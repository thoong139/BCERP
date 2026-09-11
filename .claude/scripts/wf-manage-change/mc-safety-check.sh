#!/usr/bin/env bash
# mc-safety-check.sh — Pre-execution safety gate
# Usage: mc-safety-check.sh --session-dir=.mc-data/work/wf-manage-change/CHG-20260429-001
# Output: JSON {"gates_passed":true/false,"blockers":[],"warnings":[]}
#
# Checks:
#   1. Registry JSON valid
#   2. No uncommitted changes in target files (warning)
#   3. Affected REQ-IDs exist in registry (warning)
#
# Exit codes: 0 = gates passed (may have warnings), 1 = blockers found

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

SESSION_DIR=""

for arg in "$@"; do
  case "$arg" in
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$SESSION_DIR" ]]; then
  mc_err "Usage: mc-safety-check.sh --session-dir=PATH"
  exit 2
fi

GATES_PASSED=true
BLOCKERS=()
WARNINGS=()

# ─── Check 1: Registry valid ────────────────────────────────

REGISTRY=$(mc_registry_path)
if ! mc_jq_validate "$REGISTRY"; then
  BLOCKERS+=("Registry JSON invalid: $REGISTRY")
  GATES_PASSED=false
fi

# ─── Check 2: Uncommitted changes in target files ───────────

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if [[ -f "$SESSION_DIR/affected-artifacts.json" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      if ! git diff --quiet "$file" 2>/dev/null; then
        WARNINGS+=("Uncommitted changes: $file")
      fi
    done < <(jq -r '.code_affected[].path // empty' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null)
  fi
fi

# ─── Check 3: Registry xref — affected REQ-IDs exist ────────

if [[ -f "$SESSION_DIR/affected-artifacts.json" ]]; then
  while IFS= read -r req_id; do
    [[ -z "$req_id" ]] && continue
    if mc_has_jq; then
      if ! jq -e --arg id "$req_id" '.requirements[] | select(.id == $id)' "$REGISTRY" > /dev/null 2>&1; then
        WARNINGS+=("REQ-ID not found in registry: $req_id")
      fi
    fi
  done < <(jq -r '.registry_changes.requirements_to_update[]? // empty' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null)
fi

# ─── Output ─────────────────────────────────────────────────

if mc_has_jq; then
  if [[ ${#BLOCKERS[@]} -eq 0 ]]; then
    BLOCKERS_JSON='[]'
  else
    BLOCKERS_JSON=$(printf '%s\n' "${BLOCKERS[@]}" | jq -R . | jq -s .)
  fi
  if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    WARNINGS_JSON='[]'
  else
    WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
  fi
  jq -n \
    --argjson passed "$GATES_PASSED" \
    --argjson blockers "$BLOCKERS_JSON" \
    --argjson warnings "$WARNINGS_JSON" \
    '{gates_passed: $passed, blockers: $blockers, warnings: $warnings}'
else
  B_COUNT=${#BLOCKERS[@]}
  W_COUNT=${#WARNINGS[@]}
  printf '{"gates_passed":%s,"blockers_count":%d,"warnings_count":%d}\n' "$GATES_PASSED" "$B_COUNT" "$W_COUNT"
fi

if [[ "$GATES_PASSED" == "true" ]]; then
  exit 0
else
  exit 1
fi
