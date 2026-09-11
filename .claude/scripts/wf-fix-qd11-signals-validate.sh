#!/usr/bin/env bash
# wf-fix-qd11-signals-validate.sh — Validate QD11 signals.json schema
# Returns: 0 (valid), 1 (invalid/missing)
#
# Usage: bash wf-fix-qd11-signals-validate.sh --signals-file <path>
set -euo pipefail

SIGNALS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --signals-file) SIGNALS_FILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SIGNALS_FILE" ]]; then
  echo "ERROR: --signals-file required" >&2
  exit 1
fi

if [[ ! -f "$SIGNALS_FILE" ]]; then
  echo "ERROR: signals file not found: $SIGNALS_FILE" >&2
  exit 1
fi

ERRORS=0

# Validate top-level schema fields
if ! jq -e '."$schema" == "lane-signals-v1"' "$SIGNALS_FILE" >/dev/null 2>&1; then
  echo "FAIL: \$schema != lane-signals-v1" >&2
  ERRORS=$((ERRORS + 1))
fi

if ! jq -e '.dimension == "QD11"' "$SIGNALS_FILE" >/dev/null 2>&1; then
  echo "FAIL: .dimension != QD11" >&2
  ERRORS=$((ERRORS + 1))
fi

if ! jq -e '.lane == "wf-fix-business-completeness"' "$SIGNALS_FILE" >/dev/null 2>&1; then
  echo "FAIL: .lane != wf-fix-business-completeness" >&2
  ERRORS=$((ERRORS + 1))
fi

if ! jq -e '(.signals | type) == "array"' "$SIGNALS_FILE" >/dev/null 2>&1; then
  echo "FAIL: .signals is not array" >&2
  ERRORS=$((ERRORS + 1))
fi

# Validate valid QD11 signal types
VALID_TYPES='["MISSING_FIELD","MISSING_FEATURE","TYPE_MISMATCH","VALIDATION_GAP","MISSING_DOMAIN_FIELD","MISSING_COMPLIANCE_CHECK","MISSING_AUDIT_TRAIL","MISSING_BUSINESS_RULE","UNIMPLEMENTED_REQ","ORPHAN_REQ_ID","GAP_REQ_TO_FEAT"]'
SIGNAL_COUNT=$(jq '.signals | length' "$SIGNALS_FILE" 2>/dev/null || echo "0")

if [[ "${SIGNAL_COUNT:-0}" -gt 0 ]]; then
  # Check mỗi signal có required fields
  if ! jq -e '[.signals[] | select(.signal_type == null or .severity == null or .title == null)] | length == 0' "$SIGNALS_FILE" >/dev/null 2>&1; then
    echo "FAIL: some signals missing required fields (signal_type, severity, title)" >&2
    ERRORS=$((ERRORS + 1))
  fi

  # Check signal_type ∈ VALID_TYPES
  INVALID_TYPES=$(jq -r --argjson valid "$VALID_TYPES" \
    '.signals[].signal_type | select(. as $t | $valid | index($t) | not)' \
    "$SIGNALS_FILE" 2>/dev/null || echo "")
  if [[ -n "$INVALID_TYPES" ]]; then
    echo "FAIL: invalid signal_type(s): $INVALID_TYPES" >&2
    ERRORS=$((ERRORS + 1))
  fi
fi

if [[ $ERRORS -gt 0 ]]; then
  echo "QD11 signals validation FAILED ($ERRORS error(s))" >&2
  exit 1
fi

echo "QD11 signals validation PASSED ($SIGNAL_COUNT signals)"
exit 0
