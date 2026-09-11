#!/usr/bin/env bash
# =============================================================================
# ci-detect.sh — Detect available code intelligence tools with lock protection
# =============================================================================
# Protocol 20 implementation: per-tool TTL, lock acquire/release, repo
# disambiguation, cache schema v1→v2 migration.
#
# Two-phase detection handoff (D2):
#   Phase 1: ci-detect.sh (no args)
#     → Check per-tool TTL → signal skill agent
#   Phase 2: ci-detect.sh --write-cache '<json>'
#     → Skill agent passes MCP detection results → write cache → release lock
#
# Exit codes:
#   0 — Success (all_fresh: load cache, or needs_scan+acquired: proceed, or
#              cache written successfully with >= 1 tool)
#   1 — No CI tools available / not a git repo
#   2 — Lock held by another session → fallback Grep/Glob
#
# Compatibility: Git Bash on Windows. Uses pure bash integer arithmetic (no bc).
# Pipefail is NOT used — explicit check after each command instead.
# =============================================================================

set -euo pipefail 2>/dev/null || set -eu  # Graceful for bash < 4.4

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"
CACHE_DIR=".mc-data/work/_meta"
LOCK_FILE="$CACHE_DIR/.ci-cache.lock"
STALE_TIMEOUT_SEC=60

# ── Utility: ISO 8601 timestamp ──
now_iso() {
  date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── Utility: convert ISO 8601 to epoch seconds ──
iso_to_epoch() {
  local ts="$1"
  local epoch
  if epoch=$(date -d "$ts" +%s 2>/dev/null); then
    echo "$epoch"
  else
    echo "0"
  fi
}

# ── Calculate age in days from ISO 8601 timestamp ──
iso_age_days() {
  local ts="$1"
  local epoch
  if epoch=$(date -d "$ts" +%s 2>/dev/null); then
    :  # Linux/Git Bash
  else
    echo "0"
    return
  fi
  local now_epoch
  now_epoch=$(date +%s)
  echo $(( (now_epoch - epoch) / 86400 ))
}

# ── Ensure cache directory exists ──
mkdir -p "$CACHE_DIR"

# ── Check and migrate cache schema (v1→v2) ──
check_and_migrate_cache() {
  if [[ ! -f "$CACHE_FILE" ]]; then
    return 0  # No cache yet — first run
  fi

  if ! jq -e '.' "$CACHE_FILE" > /dev/null 2>&1; then
    echo "[ci-detect] Corrupt cache file detected — removing for re-scan" >&2
    rm -f "$CACHE_FILE"
    return 0
  fi

  local schema_version
  schema_version=$(jq -r '.schema_version // 1' "$CACHE_FILE" 2>/dev/null || echo "1")

  if [[ "$schema_version" == "1" ]] || [[ "$schema_version" -lt 2 ]] 2>/dev/null; then
    echo "[ci-detect] Cache schema v${schema_version} detected — forcing re-scan for v2 migration" >&2
    rm -f "$CACHE_FILE"
  fi
}

# ── Check index age (> 7 days = WARNING stderr, không block) ──
check_index_age() {
  if [[ ! -f "$CACHE_FILE" ]]; then
    return 0
  fi

  local indexed_at
  indexed_at=$(jq -r '.gitnexus.indexed_at // ""' "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -z "$indexed_at" ]] || [[ "$indexed_at" == "null" ]]; then
    return 0
  fi

  local age_days
  age_days=$(iso_age_days "$indexed_at")
  if [[ "$age_days" -gt 7 ]] 2>/dev/null; then
    echo "[ci-detect] WARNING: GitNexus index is ${age_days} days old. Consider re-indexing: gitnexus analyze" >&2
  fi
}

# ── Check per-tool TTL ──
# Returns: "fresh" | "stale"
# Uses pure bash integer arithmetic (seconds), no bc (F21)
check_tool_ttl() {
  local tool="$1"  # "gitnexus" | "serena"

  if [[ ! -f "$CACHE_FILE" ]]; then
    echo "stale"
    return
  fi

  local checked_at ttl_hours
  checked_at=$(jq -r ".$tool.checked_at // \"1970-01-01T00:00:00Z\"" "$CACHE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
  ttl_hours=$(jq -r ".$tool.ttl_hours // 24" "$CACHE_FILE" 2>/dev/null || echo "24")

  local checked_epoch now_epoch
  checked_epoch=$(iso_to_epoch "$checked_at")
  now_epoch=$(date +%s)

  local elapsed_sec ttl_sec
  elapsed_sec=$(( now_epoch - checked_epoch ))
  ttl_sec=$(( ttl_hours * 3600 ))

  if [[ $elapsed_sec -lt $ttl_sec ]]; then
    echo "fresh"
  else
    echo "stale"
  fi
}

# ── Acquire lock (atomic via noclobber) ──
acquire_lock() {
  mkdir -p "$CACHE_DIR"
  local lock_data
  lock_data="$$|$(hostname 2>/dev/null || echo "unknown")|$(whoami 2>/dev/null || echo "unknown")|$(now_iso)|$(now_iso)"
  if ( set -C; echo "$lock_data" > "$LOCK_FILE" ) 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ── Check if lock is stale (heartbeat > STALE_TIMEOUT_SEC) ──
is_lock_stale() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    return 1  # No lock → not stale
  fi

  # Read heartbeat_at (field 5, pipe-separated)
  local heartbeat_str
  heartbeat_str=$(cut -d'|' -f5 "$LOCK_FILE" 2>/dev/null || echo "1970-01-01")
  local heartbeat_epoch now_epoch age_sec
  heartbeat_epoch=$(iso_to_epoch "$heartbeat_str")
  now_epoch=$(date +%s)
  age_sec=$(( now_epoch - heartbeat_epoch ))

  if [[ $age_sec -gt $STALE_TIMEOUT_SEC ]]; then
    return 0  # Stale
  else
    return 1  # Not stale yet
  fi
}

# ── Break stale lock + re-acquire ──
break_stale_lock() {
  echo "[ci-detect] Breaking stale lock (>${STALE_TIMEOUT_SEC}s)" >&2
  rm -f "$LOCK_FILE"
  acquire_lock
}

# ── Release lock ──
release_lock() {
  rm -f "$LOCK_FILE"
}

# ── Resolve GitNexus repo name from git remote ──
# Extracts repo name for later matching with gitnexus_list_repos() (D11)
resolve_gitnexus_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -z "$remote_url" ]]; then
    echo "unknown"
    return
  fi

  local repo_name
  # Handle multiple URL patterns:
  #   https://github.com/user/repo.git → repo
  #   git@github.com:user/repo.git    → repo
  #   /path/to/repo                   → repo
  repo_name=$(echo "$remote_url" | sed -E 's|.*[:/]([^/]+)/([^/]+?)(\.git)?$|\2|' 2>/dev/null || basename "$remote_url" .git 2>/dev/null || echo "unknown")
  echo "$repo_name"
}

# ── Write cache file ──
write_cache() {
  local gitnexus_available="$1"
  local serena_available="$2"
  local gitnexus_repo="$3"
  local gitnexus_symbols="$4"
  local gitnexus_relationships="$5"
  local gitnexus_flows="$6"
  local timestamp
  timestamp=$(now_iso)

  # Prefer the commit GitNexus actually indexed (from .gitnexus/meta.json:lastCommit).
  # Falls back to HEAD if meta.json missing/unreadable. Using HEAD makes ci-freshness
  # always report behind=0 because cache is written from HEAD, masking real index drift.
  local index_commit=""
  if [[ -f .gitnexus/meta.json ]]; then
    index_commit=$(jq -r '.lastCommit // empty' .gitnexus/meta.json 2>/dev/null || echo "")
  fi
  if [[ -z "$index_commit" ]] || [[ "$index_commit" == "null" ]]; then
    index_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  fi

  local gitnexus_ttl=24
  if [[ "$gitnexus_available" != "true" ]]; then
    gitnexus_ttl=4
  fi

  local serena_ttl=24
  if [[ "$serena_available" != "true" ]]; then
    serena_ttl=1
  fi

  jq -n \
    --arg schema_version "2" \
    --argjson gitnexus_avail "$gitnexus_available" \
    --arg gitnexus_repo "$gitnexus_repo" \
    --argjson gitnexus_symbols "$gitnexus_symbols" \
    --argjson gitnexus_relationships "$gitnexus_relationships" \
    --argjson gitnexus_flows "$gitnexus_flows" \
    --arg index_commit "$index_commit" \
    --argjson gitnexus_ttl "$gitnexus_ttl" \
    --argjson serena_avail "$serena_available" \
    --argjson serena_ttl "$serena_ttl" \
    --arg now "$timestamp" \
    '{
      schema_version: ($schema_version | tonumber),
      gitnexus: {
        available: $gitnexus_avail,
        repo: $gitnexus_repo,
        symbols: $gitnexus_symbols,
        relationships: $gitnexus_relationships,
        execution_flows: $gitnexus_flows,
        index_commit: $index_commit,
        indexed_at: $now,
        checked_at: $now,
        ttl_hours: ($gitnexus_ttl | tonumber)
      },
      serena: {
        available: $serena_avail,
        onboarded: $serena_avail,
        languages: [],
        checked_at: $now,
        ttl_hours: ($serena_ttl | tonumber)
      },
      scanned_at: $now,
      scan_duration_ms: 0
    }' > "$CACHE_FILE"

  # Validate written JSON
  if ! jq -e '.' "$CACHE_FILE" > /dev/null 2>&1; then
    echo "[ci-detect] ERROR: Cache file validation failed after write" >&2
    rm -f "$CACHE_FILE"
    return 1
  fi

  return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# CLI Mode Dispatch
# ══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
  --write-cache)
    # ═══════════════════════════════════════════════
    # Phase 2: Write MCP detection results to cache
    # ═══════════════════════════════════════════════
    # $2 = JSON string from skill agent:
    #   {
    #     "gitnexus_available": true/false,
    #     "gitnexus_repo": "repo-name" | null,
    #     "gitnexus_symbols": N | 0,
    #     "gitnexus_relationships": N | 0,
    #     "gitnexus_flows": N | 0,
    #     "serena_available": true/false
    #   }
    if [[ -z "${2:-}" ]]; then
      echo "[ci-detect] ERROR: --write-cache requires JSON argument" >&2
      release_lock
      exit 1
    fi

    MCP_RESULT="$2"

    GITNEXUS_AVAIL=$(echo "$MCP_RESULT" | jq -r '.gitnexus_available // false')
    GITNEXUS_REPO=$(echo "$MCP_RESULT" | jq -r '.gitnexus_repo // "unknown"')
    GITNEXUS_SYMBOLS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_symbols // 0')
    GITNEXUS_RELS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_relationships // 0')
    GITNEXUS_FLOWS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_flows // 0')
    SERENA_AVAIL=$(echo "$MCP_RESULT" | jq -r '.serena_available // false')

    if ! write_cache "$GITNEXUS_AVAIL" "$SERENA_AVAIL" "$GITNEXUS_REPO" "$GITNEXUS_SYMBOLS" "$GITNEXUS_RELS" "$GITNEXUS_FLOWS"; then
      echo "[ci-detect] ERROR: Cache write failed" >&2
      release_lock
      exit 1
    fi

    release_lock

    if [[ "$GITNEXUS_AVAIL" == "true" ]] || [[ "$SERENA_AVAIL" == "true" ]]; then
      exit 0
    else
      exit 1
    fi
    ;;

  *)
    # ═══════════════════════════════════════════
    # Phase 1: Check cache + signal skill agent
    # ═══════════════════════════════════════════

    mkdir -p "$CACHE_DIR"

    # Check schema version → migrate if needed
    check_and_migrate_cache

    # Short-circuit: not a git repo
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      echo '{"status":"no_git","message":"Not a git repository — CI detection skipped"}'
      exit 1
    fi

    # Force re-scan via env var (respects lock in acquire_lock)
    NEEDS_RESCAN=false
    if [[ "${MCV3_CI_RESCAN:-}" == "1" ]]; then
      echo "[ci-detect] MCV3_CI_RESCAN=1 — forcing re-scan" >&2
      NEEDS_RESCAN=true
    fi

    # ── Check per-tool TTL ──
    if [[ "$NEEDS_RESCAN" != "true" ]] && [[ -f "$CACHE_FILE" ]]; then
      GITNEXUS_FRESH=$(check_tool_ttl "gitnexus" || echo "stale")
      SERENA_FRESH=$(check_tool_ttl "serena" || echo "stale")

      if [[ "$GITNEXUS_FRESH" == "fresh" ]] && [[ "$SERENA_FRESH" == "fresh" ]]; then
        check_index_age  # WARNING stderr nếu index > 7 ngày (không block)
        echo "{\"status\":\"all_fresh\",\"action\":\"load_cache\"}"
        exit 0
      fi
    fi

    # ── Cache stale or missing → try acquire lock ──
    if acquire_lock; then
      check_index_age  # WARNING stderr nếu index > 7 ngày (không block)
      echo "{\"status\":\"needs_scan\",\"action\":\"call_mcp_tools\"}"
      exit 0
    else
      # ── Lock NOT acquired ──
      if is_lock_stale; then
        if break_stale_lock; then
          echo "{\"status\":\"needs_scan\",\"action\":\"call_mcp_tools\",\"note\":\"stale_lock_broken\"}"
          exit 0
        fi
      fi

      # Valid lock held by another session → fallback
      echo "{\"status\":\"lock_held\",\"action\":\"fallback_grep\"}"
      exit 2
    fi
    ;;
esac
