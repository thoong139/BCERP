#!/usr/bin/env bash
# pf-postgate-check.sh — POST-GATE T1→T4 validation (CORE-012, Protocol 10)
# Usage: pf-postgate-check.sh <FILE_PATH> <TYPE=md|json> [MIN_WORDS=50] [HEADINGS...]
# Output: JSON {pass, file, results[]}
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

FILE_PATH="${1:?Usage: pf-postgate-check.sh <file> <md|json> [min_words] [heading1 heading2 ...]}"
FILE_TYPE="${2:-md}"
MIN_WORDS="${3:-50}"
shift 3 2>/dev/null || shift $# 2>/dev/null || true
REQUIRED_HEADINGS=("$@")

require_jq

RESULTS=()
PASS=true

# T1: Existence + non-empty
if test -s "$FILE_PATH"; then
  RESULTS+=("{\"tier\":\"T1\",\"check\":\"existence\",\"pass\":true}")
else
  RESULTS+=("{\"tier\":\"T1\",\"check\":\"existence\",\"pass\":false,\"detail\":\"file missing or empty\"}")
  PASS=false
fi

# T2: Structure check (only if file exists)
if [[ -f "$FILE_PATH" ]]; then
  if [[ "$FILE_TYPE" == "md" ]]; then
    # Check required headings for markdown files
    for heading in "${REQUIRED_HEADINGS[@]}"; do
      if grep -qi "$heading" "$FILE_PATH" 2>/dev/null; then
        RESULTS+=("{\"tier\":\"T2\",\"check\":\"heading\",\"pattern\":$(echo "$heading" | jq -R .),\"pass\":true}")
      else
        RESULTS+=("{\"tier\":\"T2\",\"check\":\"heading\",\"pattern\":$(echo "$heading" | jq -R .),\"pass\":false}")
        PASS=false
      fi
    done
  elif [[ "$FILE_TYPE" == "json" ]]; then
    # Check valid JSON structure
    if jq '.' "$FILE_PATH" > /dev/null 2>&1; then
      RESULTS+=("{\"tier\":\"T2\",\"check\":\"json_valid\",\"pass\":true}")
    else
      RESULTS+=("{\"tier\":\"T2\",\"check\":\"json_valid\",\"pass\":false}")
      PASS=false
    fi
  fi
fi

# T3: Content depth (word count or key count)
if [[ -f "$FILE_PATH" ]]; then
  if [[ "$FILE_TYPE" == "json" ]]; then
    # For JSON: count top-level keys
    KEY_COUNT=$(jq 'keys | length' "$FILE_PATH" 2>/dev/null || echo 0)
    if [[ $KEY_COUNT -ge ${MIN_WORDS:-1} ]]; then
      RESULTS+=("{\"tier\":\"T3\",\"check\":\"key_count\",\"value\":$KEY_COUNT,\"min\":${MIN_WORDS:-1},\"pass\":true}")
    else
      RESULTS+=("{\"tier\":\"T3\",\"check\":\"key_count\",\"value\":$KEY_COUNT,\"min\":${MIN_WORDS:-1},\"pass\":false}")
      PASS=false
    fi
  else
    # For MD: word count
    WORD_COUNT=$(wc -w < "$FILE_PATH" | tr -d ' ')
    if [[ $WORD_COUNT -ge $MIN_WORDS ]]; then
      RESULTS+=("{\"tier\":\"T3\",\"check\":\"word_count\",\"value\":$WORD_COUNT,\"min\":$MIN_WORDS,\"pass\":true}")
    else
      RESULTS+=("{\"tier\":\"T3\",\"check\":\"word_count\",\"value\":$WORD_COUNT,\"min\":$MIN_WORDS,\"pass\":false}")
      PASS=false
    fi
  fi
fi

# Build results array
RESULTS_JSON=$(printf '%s\n' "${RESULTS[@]}" | jq -s .)
echo "{\"pass\":$PASS,\"file\":\"$FILE_PATH\",\"type\":\"$FILE_TYPE\",\"results\":$RESULTS_JSON}"
