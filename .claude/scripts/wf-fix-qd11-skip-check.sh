#!/usr/bin/env bash
# wf-fix-qd11-skip-check.sh — Check QD11 skip conditions
# Returns: 0 (run QD11), 2 (skip QD11)
# Skip conditions: single_module, api_only, profile_quick
#
# Usage: bash wf-fix-qd11-skip-check.sh --project-root <dir> [--profile <profile>]
set -euo pipefail

PROJECT_ROOT=""
PROFILE="standard"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: --project-root required" >&2
  exit 1
fi

REGISTRY="$PROJECT_ROOT/.mc-data/docs/_meta/req-registry.json"

# Check 1: profile=quick → skip QD11 (LLM probes too expensive for quick)
if [[ "$PROFILE" == "quick" ]]; then
  echo '{"skip":true,"reason":"profile_quick","detail":"QD11 LLM probes bi skip voi profile=quick"}'
  exit 2
fi

# Check 2: api-only → skip QD11 (no business UI to compare)
if [[ -f "$REGISTRY" ]]; then
  INTERFACE_TYPE=$(jq -r '.interface_type // "web"' "$REGISTRY" 2>/dev/null || echo "web")
  if [[ "$INTERFACE_TYPE" == "api-only" ]]; then
    echo '{"skip":true,"reason":"api_only","detail":"QD11 skip: interface_type=api-only, khong co UI module de so sanh pattern"}'
    exit 2
  fi

  # Check 3: single_module → skip QD11 (need >=2 modules for cross-module comparison)
  MODULE_COUNT=$(jq -r '.modules | length // 0' "$REGISTRY" 2>/dev/null || echo "0")
  if [[ "${MODULE_COUNT:-0}" -lt 2 ]]; then
    echo "{\"skip\":true,\"reason\":\"single_module\",\"detail\":\"QD11 skip: chi co ${MODULE_COUNT:-0} module(s), can >=2 de cross-reference pattern\"}"
    exit 2
  fi
fi

# All checks passed → run QD11
echo '{"skip":false,"reason":"eligible","detail":"QD11 eligible: multi-module + non-api-only + profile>=standard"}'
exit 0
