#!/usr/bin/env bash
# mc-validate-registry.sh — Validate registry JSON + content (T1-T4)
# Usage: mc-validate-registry.sh
# Output: JSON {"valid":true/false,"requirements_count":N,"size_bytes":N}
#
# Exit codes: 0 = valid, 1 = invalid

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

REGISTRY=$(mc_registry_path)

# T1: File exists
if [[ ! -f "$REGISTRY" ]]; then
  mc_err "Registry not found: $REGISTRY"
  if mc_has_jq; then
    jq -n '{valid:false, error:"file_not_found"}'
  else
    echo '{"valid":false,"error":"file_not_found"}'
  fi
  exit 1
fi

# T2: Non-empty
SIZE=$(wc -c < "$REGISTRY")
if [[ $SIZE -eq 0 ]]; then
  mc_err "Registry is empty: $REGISTRY"
  if mc_has_jq; then
    jq -n '{valid:false, error:"empty_file"}'
  else
    echo '{"valid":false,"error":"empty_file"}'
  fi
  exit 1
fi

# T3: Valid JSON
if ! mc_jq_validate "$REGISTRY"; then
  mc_err "Registry JSON invalid: $REGISTRY"
  if mc_has_jq; then
    jq -n '{valid:false, error:"invalid_json"}'
  else
    echo '{"valid":false,"error":"invalid_json"}'
  fi
  exit 1
fi

# T4: Content checks — must have requirements with length > 0
if mc_has_jq; then
  REQ_COUNT=$(jq '.requirements | length' "$REGISTRY")
  if [[ $REQ_COUNT -eq 0 ]]; then
    mc_err "Registry has no requirements entries"
    jq -n '{valid:false, requirements_count:0, error:"no_requirements"}'
    exit 1
  fi
  mc_log "Registry valid: $REQ_COUNT requirements, $SIZE bytes"
  jq -n --argjson count "$REQ_COUNT" --argjson size "$SIZE" \
    '{valid:true, requirements_count:$count, size_bytes:$size}'
else
  # jq-less T4: check for "requirements" key presence via grep
  if grep -q '"requirements"' "$REGISTRY" 2>/dev/null && grep -q '"id"' "$REGISTRY" 2>/dev/null; then
    mc_log "Registry valid (jq-less check): key 'requirements' present, $SIZE bytes"
    printf '{"valid":true,"requirements_count":-1,"size_bytes":%s,"note":"jq-less T4 — count unavailable"}\n' "$SIZE"
  else
    mc_err "Registry missing 'requirements' key or entries"
    printf '{"valid":false,"error":"no_requirements","note":"jq-less T4 check"}\n'
    exit 1
  fi
fi
