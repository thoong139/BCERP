#!/usr/bin/env bash
# mc-generate-session-id.sh — Generate unique session ID with retry loop
# Usage: mc-generate-session-id.sh
# Output: CHG-YYYYMMDD-NNN (stdout)
#
# Exit codes: 0 = success, 1 = failed after MAX_RETRIES

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

mc_ensure_dirs

DATE=$(date +%Y%m%d)
MAX_RETRIES=10
SLEEP_SEC=0.05

for attempt in $(seq 1 $MAX_RETRIES); do
  CANDIDATE="CHG-${DATE}-$(printf '%03d' $attempt)"

  # Check trong sessions.jsonl
  if [[ -f "$MC_INDEX" ]]; then
    if grep -q "\"change_id\":\"${CANDIDATE}\"" "$MC_INDEX" 2>/dev/null; then
      continue  # Da ton tai, thu tiep
    fi
  fi

  # Check trong index.json (dual-write compat)
  if [[ -f "$MC_ROOT/index.json" ]]; then
    if mc_has_jq; then
      if jq -e --arg id "$CANDIDATE" '.sessions[] | select(.change_id == $id)' \
           "$MC_ROOT/index.json" > /dev/null 2>&1; then
        continue
      fi
    fi
  fi

  # Unique!
  echo "$CANDIDATE"
  exit 0
done

mc_err "Khong the generate unique session ID sau $MAX_RETRIES lan thu"
exit 1
