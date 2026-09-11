#!/usr/bin/env bash
# pf-index-append.sh — Append entry to _index/sessions.jsonl
# Usage: pf-index-append.sh <JSON_ENTRY>
# Output: JSON {status, total_entries}
# POSIX atomic append: single echo < 4KB is guaranteed atomic on POSIX filesystems
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

ENTRY="${1:?Usage: pf-index-append.sh <json_entry>}"

ensure_dirs

# Validate that entry is valid JSON (optional but good practice)
if command -v jq >/dev/null 2>&1; then
  echo "$ENTRY" | jq '.' > /dev/null 2>&1 || {
    echo "{\"error\":\"invalid_json_entry\",\"entry\":$(echo "$ENTRY" | head -c 100)}"
    exit 1
  }
fi

# Atomic append (POSIX guarantee for writes < PIPE_BUF ~4KB)
echo "$ENTRY" >> "$INDEX_FILE"

TOTAL=$(wc -l < "$INDEX_FILE" | tr -d ' ')
echo "{\"status\":\"appended\",\"total_entries\":$TOTAL,\"index_file\":\"$INDEX_FILE\"}"
