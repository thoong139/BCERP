#!/usr/bin/env bash
# Append session entry vào JSONL index (append-only)
# Usage: bash vs-index-append.sh '<json_entry>'
# Output: JSON {status, total_entries}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

ENTRY="${1:?Usage: vs-index-append.sh '<json_entry>'}"

require_jq
ensure_dirs

# Validate entry là JSON hợp lệ trước khi append
echo "$ENTRY" | jq '.' > /dev/null 2>&1 || {
  echo "{\"error\":\"invalid_json\",\"message\":\"Entry is not valid JSON\"}"
  exit 1
}

# Compact to single line (JSONL requires 1 JSON per line)
COMPACT=$(echo "$ENTRY" | jq -c '.')

# Atomic append via temp file + mv (safe on NTFS — F19)
# POSIX echo >> is not atomic on NTFS; mv is atomic on all filesystems
TEMP_INDEX=$(mktemp "${INDEX_FILE}.XXXXXX" 2>/dev/null || echo "${INDEX_FILE}.tmp.$$.$RANDOM")
PREV_TOTAL=0
if [[ -f "$INDEX_FILE" ]]; then
  cat "$INDEX_FILE" > "$TEMP_INDEX" 2>/dev/null || true
  PREV_TOTAL=$(wc -l < "$INDEX_FILE" | tr -d ' ')
fi
echo "$COMPACT" >> "$TEMP_INDEX"

# Validate before replacing: verify line count is prev + 1
TEMP_TOTAL=$(wc -l < "$TEMP_INDEX" | tr -d ' ')
EXPECTED=$((PREV_TOTAL + 1))
if [[ "$TEMP_TOTAL" -ne "$EXPECTED" ]]; then
  rm -f "$TEMP_INDEX"
  echo "{\"error\":\"append_validation_failed\",\"prev_total\":$PREV_TOTAL,\"temp_total\":$TEMP_TOTAL,\"expected\":$EXPECTED}"
  exit 1
fi

# Atomic rename (safe on NTFS)
mv "$TEMP_INDEX" "$INDEX_FILE" 2>/dev/null || {
  rm -f "$TEMP_INDEX"
  echo "{\"error\":\"mv_failed\",\"message\":\"Could not replace index file atomically\"}"
  exit 1
}

TOTAL=$EXPECTED
echo "{\"status\":\"appended\",\"total_entries\":$TOTAL,\"index_file\":\"$INDEX_FILE\"}"
