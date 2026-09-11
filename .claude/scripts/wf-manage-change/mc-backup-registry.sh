#!/usr/bin/env bash
# mc-backup-registry.sh — Backup registry with timestamp + SHA256 checksum
# Usage: mc-backup-registry.sh
# Output: JSON {"backup_path":"...","checksum":"...","timestamp":...}
#
# Exit codes: 0 = success, 1 = registry not found

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

REGISTRY=$(mc_registry_path)

if [[ ! -f "$REGISTRY" ]]; then
  mc_err "Registry not found: $REGISTRY"
  exit 1
fi

TIMESTAMP=$(mc_epoch)
BACKUP="${REGISTRY}.pre-change-${TIMESTAMP}"

cp "$REGISTRY" "$BACKUP"

# Compute checksum
CHECKSUM=$(mc_sha256 "$BACKUP")

mc_log "Registry backed up: $BACKUP"
mc_log "SHA256: $CHECKSUM"

# Output JSON cho AI consume
if mc_has_jq; then
  jq -n --arg path "$BACKUP" --arg checksum "$CHECKSUM" --argjson ts "$TIMESTAMP" \
    '{backup_path: $path, checksum: $checksum, timestamp: $ts}'
else
  printf '{"backup_path":"%s","checksum":"%s","timestamp":%s}\n' "$BACKUP" "$CHECKSUM" "$TIMESTAMP"
fi
