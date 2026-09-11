#!/usr/bin/env bash
# Backup registry + checksum trước khi modify
# Usage: bash as-backup-registry.sh <session_dir>
# Output: JSON {backup_path, checksum, size}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

SESSION_DIR="${1:?Usage: as-backup-registry.sh <session_dir>}"

require_jq

# Verify registry tồn tại
if ! test -s "$REGISTRY_PATH"; then
  echo "{\"error\":\"registry_missing\",\"path\":\"$REGISTRY_PATH\"}"
  exit 1
fi

TIMESTAMP=$(date +%s)
BACKUP_NAME="req-registry.json.pre-addscope-${TIMESTAMP}"
BACKUP_PATH=".mc-data/docs/_meta/$BACKUP_NAME"

# Copy + verify integrity (P1-2 fix)
cp "$REGISTRY_PATH" "$BACKUP_PATH"

# Verify backup integrity
if ! jq '.' "$BACKUP_PATH" > /dev/null 2>&1; then
  rm -f "$BACKUP_PATH"
  echo '{"error":"backup_corrupted","reason":"backup file is not valid JSON after copy"}'
  exit 1
fi

# Checksum + size
CHECKSUM=$(sha_hash "$BACKUP_PATH")
SIZE=$(wc -c < "$BACKUP_PATH" | tr -d ' ')

# Format checksum with proper prefix
if [[ "$CHECKSUM" == "no-checksum" ]]; then
  CHECKSUM_FMT="no-checksum"
else
  CHECKSUM_FMT="sha256:$CHECKSUM"
fi

jq -n --arg bp "$BACKUP_PATH" --arg cs "$CHECKSUM_FMT" --argjson size "$SIZE" --argjson ts "$TIMESTAMP" \
  '{backup_path:$bp, checksum:$cs, size:$size, timestamp:$ts}'
