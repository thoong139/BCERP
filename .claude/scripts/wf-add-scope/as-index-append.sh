#!/usr/bin/env bash
# Append session entry vào JSONL index (append-only)
# Usage: bash as-index-append.sh '<json_entry>'
# Output: JSON {status, total_entries}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

ENTRY="${1:?Usage: as-index-append.sh '<json_entry>'}"

require_jq
ensure_dirs

# Validate entry là JSON hợp lệ trước khi append
echo "$ENTRY" | jq '.' > /dev/null 2>&1 || {
  echo "{\"error\":\"invalid_json\",\"message\":\"Entry is not valid JSON\"}"
  exit 1
}

# Atomic append — single echo, < 4KB POSIX guarantee
echo "$ENTRY" >> "$INDEX_FILE"

TOTAL=$(wc -l < "$INDEX_FILE" | tr -d ' ')
echo "{\"status\":\"appended\",\"total_entries\":$TOTAL,\"index_file\":\"$INDEX_FILE\"}"
