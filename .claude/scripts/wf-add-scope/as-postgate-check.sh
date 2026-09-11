#!/usr/bin/env bash
# POST-GATE T1→T4 file validation (Protocol 10 — CORE-012)
# Usage: bash as-postgate-check.sh <file_path> <type> [min_words] [required_heading1] [required_heading2] ...
#   type: md | json | any
#   min_words: minimum word count (T3 check), default 50
# Output: JSON {pass, file, results[]}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

FILE_PATH="${1:?Usage: as-postgate-check.sh <file> <type> [min_words] [heading1 ...]}"
FILE_TYPE="${2:-md}"
MIN_WORDS="${3:-50}"
# P1 fix: validate argument count before shift
if [[ $# -lt 3 ]]; then
  REQUIRED_HEADINGS=()
else
  shift 3
  REQUIRED_HEADINGS=("$@")
fi

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

# T2: Structure (headings cho .md / keys cho .json)
if [[ -f "$FILE_PATH" ]]; then
  if [[ "$FILE_TYPE" == "md" && ${#REQUIRED_HEADINGS[@]} -gt 0 ]]; then
    for heading in "${REQUIRED_HEADINGS[@]}"; do
      if grep -qi -- "$heading" "$FILE_PATH" 2>/dev/null; then
        RESULTS+=("{\"tier\":\"T2\",\"check\":\"heading\",\"pattern\":\"$heading\",\"pass\":true}")
      else
        RESULTS+=("{\"tier\":\"T2\",\"check\":\"heading\",\"pattern\":\"$heading\",\"pass\":false}")
        PASS=false
      fi
    done
  elif [[ "$FILE_TYPE" == "json" ]]; then
    if jq '.' "$FILE_PATH" > /dev/null 2>&1; then
      RESULTS+=("{\"tier\":\"T2\",\"check\":\"json_parse\",\"pass\":true}")
    else
      RESULTS+=("{\"tier\":\"T2\",\"check\":\"json_parse\",\"pass\":false,\"detail\":\"invalid JSON\"}")
      PASS=false
    fi
  fi

  # T3: Content depth — word count
  WORD_COUNT=$(wc -w < "$FILE_PATH" | tr -d ' ')
  if [[ "$WORD_COUNT" -ge "$MIN_WORDS" ]]; then
    RESULTS+=("{\"tier\":\"T3\",\"check\":\"word_count\",\"value\":$WORD_COUNT,\"min\":$MIN_WORDS,\"pass\":true}")
  else
    RESULTS+=("{\"tier\":\"T3\",\"check\":\"word_count\",\"value\":$WORD_COUNT,\"min\":$MIN_WORDS,\"pass\":false}")
    PASS=false
  fi
fi

# T4: Cross-reference (basic — check required fields exist cho JSON)
if [[ "$FILE_TYPE" == "json" && -f "$FILE_PATH" ]]; then
  SCHEMA=$(jq -r '.["$schema"] // ""' "$FILE_PATH" 2>/dev/null || echo "")
  if [[ -n "$SCHEMA" ]]; then
    RESULTS+=("{\"tier\":\"T4\",\"check\":\"schema_declared\",\"value\":\"$SCHEMA\",\"pass\":true}")
  else
    RESULTS+=("{\"tier\":\"T4\",\"check\":\"schema_declared\",\"pass\":false,\"detail\":\"no \$schema field\"}")
    # T4 failure là WARN, không block (PASS giữ nguyên)
  fi
fi

# Build results array
RESULTS_JSON=$(printf '%s\n' "${RESULTS[@]}" | jq -s .)
echo "{\"pass\":$PASS,\"file\":\"$FILE_PATH\",\"results\":$RESULTS_JSON}"

[[ "$PASS" == "true" ]] || exit 1
