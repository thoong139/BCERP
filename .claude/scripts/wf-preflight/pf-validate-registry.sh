#!/usr/bin/env bash
# pf-validate-registry.sh — Validate req-registry.json (forensic, CORE-011 Protocol 10.4)
# Usage: pf-validate-registry.sh [SESSION_DIR]
# Output: JSON {pass, errors[], systems, modules, requirements, features}
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

SESSION_DIR="${1:-}"  # optional — for context only

require_jq

ERRORS=()
PASS=true

# T1: File exists and non-empty
if ! test -s "$REGISTRY_PATH"; then
  ERRORS+=("T1_FAIL: registry missing or empty at $REGISTRY_PATH")
  PASS=false
fi

if [[ "$PASS" == "true" ]]; then
  # JSON valid
  if ! jq '.' "$REGISTRY_PATH" > /dev/null 2>&1; then
    ERRORS+=("JSON_INVALID: registry is not valid JSON")
    PASS=false
  fi
fi

if [[ "$PASS" == "true" ]]; then
  # Forensic field checks (Protocol 10.4 — content, not just existence)
  SYS_COUNT=$(jq '.systems | length' "$REGISTRY_PATH" 2>/dev/null || echo 0)
  MOD_COUNT=$(jq '.modules | length' "$REGISTRY_PATH" 2>/dev/null || echo 0)
  REQ_COUNT=$(jq '.requirements | length' "$REGISTRY_PATH" 2>/dev/null || echo 0)
  FEAT_COUNT=$(jq '.features | length' "$REGISTRY_PATH" 2>/dev/null || echo 0)

  # Required: at least 1 requirement (core SSOT check)
  if [[ "$REQ_COUNT" -eq 0 ]]; then
    ERRORS+=("REQUIREMENTS_EMPTY: registry has no requirements — run /wf-analyze-requirements first")
    PASS=false
  fi

  # Warn-level checks (not fail)
  WARNINGS=()
  [[ "$SYS_COUNT" -eq 0 ]] && WARNINGS+=("systems array empty")
  [[ "$MOD_COUNT" -eq 0 ]] && WARNINGS+=("modules array empty")
fi

if [[ "$PASS" == "false" ]]; then
  ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
  echo "{\"pass\":false,\"errors\":$ERRORS_JSON}"
  exit 1
fi

# All checks passed
WARNINGS_JSON="[]"
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
fi

echo "{\"pass\":true,\"systems\":$SYS_COUNT,\"modules\":$MOD_COUNT,\"requirements\":$REQ_COUNT,\"features\":$FEAT_COUNT,\"warnings\":$WARNINGS_JSON}"
