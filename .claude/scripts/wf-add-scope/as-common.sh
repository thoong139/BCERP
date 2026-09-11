#!/usr/bin/env bash
# Shared helpers cho wf-add-scope scripts
# Source: source "$(dirname "${BASH_SOURCE[0]}")/as-common.sh"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Directories (relative to project root — scripts phải chạy từ project root)
WORK_ROOT=".mc-data/work/wf-add-scope"
SESSIONS_DIR="$WORK_ROOT/sessions"
INDEX_DIR="$WORK_ROOT/_index"
INDEX_FILE="$INDEX_DIR/sessions.jsonl"
REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"
REGISTRY_LOCK=".mc-data/docs/_meta/.registry.lock"

# Identity helpers
get_hostname() { hostname 2>/dev/null || echo "unknown"; }
get_user()     { whoami 2>/dev/null || echo "unknown"; }
get_timestamp(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Sanitize ID for filesystem paths — reject traversal + special chars (P0-1 fix)
# Returns 0 + echoes value if valid, returns 1 + error if invalid
sanitize_id() {
  local val="$1"
  local name="${2:-ID}"
  if [[ "$val" =~ \.\. ]] || [[ "$val" =~ / ]]; then
    error "Invalid $name: '$val' contains path traversal characters"
    return 1
  fi
  if ! [[ "$val" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid $name: '$val' — only alphanumeric, dash, underscore allowed"
    return 1
  fi
  echo "$val"
}

# Convert ISO timestamp to epoch seconds — cross-platform (P0-5 fix)
# Handles: GNU date (Linux/Git Bash), BSD date (macOS), Python fallback
to_epoch() {
  local ts="$1"
  # Strip fractional seconds for compatibility
  local ts_clean="${ts%%.*}Z"
  # GNU date (Linux, Git Bash)
  local result
  result=$(date -d "$ts" +%s 2>/dev/null) && { echo "$result"; return 0; }
  # macOS BSD date
  result=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$ts_clean" +%s 2>/dev/null) && { echo "$result"; return 0; }
  # Python fallback
  if command -v python3 >/dev/null 2>&1; then
    result=$(python3 -c "
import datetime, sys
ts = sys.argv[1].replace('Z','+00:00')
print(int(datetime.datetime.fromisoformat(ts).timestamp()))" "$ts" 2>/dev/null) && { echo "$result"; return 0; }
  fi
  echo "0"
}

# Checksum (cross-platform: Linux / macOS / Git Bash Windows)
sha_hash() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "no-checksum"
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$file" 2>/dev/null || echo "no-checksum"
  else
    echo "no-checksum"
  fi
}

# Ensure working dirs exist
ensure_dirs() {
  mkdir -p "$SESSIONS_DIR" "$INDEX_DIR" "$WORK_ROOT/_shared/cache" ".mc-data/work/_trace"
}

# Fail fast nếu jq missing
require_jq() {
  command -v jq >/dev/null 2>&1 || {
    error "jq is required but not found. Install jq to use wf-add-scope scripts."
    error "  Linux: sudo apt-get install jq"
    error "  macOS: brew install jq"
    error "  Windows: https://github.com/jqlang/jq/releases"
    exit 1
  }
}
