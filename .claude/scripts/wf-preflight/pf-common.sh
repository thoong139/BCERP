#!/usr/bin/env bash
# pf-common.sh — Shared helpers for wf-preflight scripts
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"
# Do NOT run directly.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Paths (relative to project root — scripts must be run from project root)
WORK_ROOT=".mc-data/work/wf-preflight"
SESSIONS_DIR="$WORK_ROOT/sessions"
INDEX_DIR="$WORK_ROOT/_index"
INDEX_FILE="$INDEX_DIR/sessions.jsonl"
LOCKS_DIR="$WORK_ROOT/.locks"
REGISTRY_LOCK="$LOCKS_DIR/registry.lock"
REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"

# Identity
get_hostname() { hostname 2>/dev/null || echo "unknown"; }
get_user()     { whoami 2>/dev/null || echo "unknown"; }
get_timestamp(){ date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ"; }

# Cross-platform sha256
sha_hash() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" | cut -d' ' -f1
  else
    echo "nohash"
  fi
}

# Ensure required directories exist
ensure_dirs() {
  mkdir -p "$SESSIONS_DIR" "$INDEX_DIR" "$LOCKS_DIR" ".mc-data/work/_trace" 2>/dev/null || true
}

# Fail fast if jq not available
require_jq() {
  command -v jq >/dev/null 2>&1 || {
    error "jq is required but not found."
    error "Install: apt install jq / brew install jq / choco install jq"
    exit 1
  }
}

# Safe jq wrapper — returns default if jq fails
jq_safe() {
  local default="$1"; shift
  jq "$@" 2>/dev/null || echo "$default"
}
