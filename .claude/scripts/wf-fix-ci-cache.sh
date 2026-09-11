#!/usr/bin/env bash
# wf-fix-ci-cache.sh — Session-tier cache wrapper cho gitnexus_impact (W1.2 v10-speedup)
#
# Muc dich: Cache ket qua `gitnexus_impact` trong 1 session de tranh duplicate calls
# trong Phase 3 batches va Phase 5 Verify Loop. Cache scope: file-backed trong
# $SESSION_DIR/.ci-cache/impact/ — la "session-tier" theo nghia logic (file song
# cung session, cleanup cung session, khong leak cross-session).
#
# Note: MCP tool `mcp__plugin_gitnexus_gitnexus__impact` CHI invoke duoc tu agent
# context — KHONG tu bash subshell. Vi vay wrapper khong "tu call gitnexus" ma
# cung cap 3 subcommands cho agent integration:
#
#   lookup  — check cache, neu HIT echo JSON + log entry, exit 0
#                            neu MISS exit 1 (empty stdout), agent invoke MCP impact roi store
#   store   — luu MCP impact result vao cache + log entry
#   bypass  — log truc tiep (khong cache) khi escape hatch/freshness=severe
#
# Bypass conditions (auto-detected by `lookup`):
#   - $MCV3_FIX_CI_CACHE_DISABLED=1  (escape hatch)
#   - freshness_level == "severe"     (stale index → khong dung cache cu)
#   Bypass → exit 1 (force MCP fresh call), agent goi `bypass` subcommand sau khi co result.
#
# Cache key: impact:{HEAD-sha}:{target}:{direction}
#   - HEAD-sha thay doi sau commit → cache auto-invalidate
#   - Session-tier only (in-memory) → tu nhien isolated cross-session, khong leak
#
# Usage:
#   # Lookup
#   RESULT=$(bash .claude/scripts/wf-fix-ci-cache.sh lookup "$SESSION_DIR" "$TARGET" "upstream")
#   if [ -n "$RESULT" ]; then
#     # HIT — RESULT chua JSON impact, log da append tu wrapper
#     echo "$RESULT"
#   else
#     # MISS or BYPASS — agent invoke MCP roi store
#     IMPACT_JSON=$(mcp__plugin_gitnexus_gitnexus__impact ...)
#     bash .claude/scripts/wf-fix-ci-cache.sh store "$SESSION_DIR" "$TARGET" "upstream" "$IMPACT_JSON" "$DURATION_MS"
#   fi
#
# Exit codes:
#   0 — HIT (stdout = cached JSON)
#   1 — MISS or BYPASS (stdout empty; agent must invoke MCP + call `store`)
#   2 — invalid arguments
#   3 — internal error (cache adapter unavailable, etc.)

set -euo pipefail

# ===========================================================================
# Constants & dependencies
# ===========================================================================

readonly SCRIPT_NAME="wf-fix-ci-cache"
readonly REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
readonly SHARED_DIR="$REPO_ROOT/.claude/skills/workflow/_shared"
readonly CACHE_SKILL_NAME="wf-fix-execute"

# NOTE: Khong dung Python cache_adapter._session_cache vi do la in-memory dict —
# khong persist giua subprocess. File-backed cache duoi ($SESSION_DIR/.ci-cache/)
# la "session-tier" theo nghia LOGIC: file nam trong $SESSION_DIR (cleanup khi
# session ket thuc), khong leak cross-session. Phu thuoc: jq + sha256sum/shasum.

# ===========================================================================
# Helpers
# ===========================================================================

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# JSON-escape string (su dung jq -Rs de an toan ky tu dac biet)
json_escape() {
  printf '%s' "$1" | jq -Rs '.' 2>/dev/null || printf '"%s"' "$1"
}

# Lay HEAD commit sha — fallback "no-git" neu khong phai git repo
head_sha() {
  git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "no-git"
}

# Build cache_key — "impact:{sha}:{target}:{direction}"
build_cache_key() {
  local target="$1"
  local direction="$2"
  local sha
  sha="$(head_sha)"
  printf 'impact:%s:%s:%s' "$sha" "$target" "$direction"
}

# Read freshness_level tu $SESSION_DIR/ci-context.json (fallback "unknown")
read_freshness() {
  local session_dir="$1"
  local ctx_file="$session_dir/ci-context.json"
  if [ -s "$ctx_file" ]; then
    jq -r '.freshness_level // .freshness.level // "unknown"' "$ctx_file" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

read_freshness_behind() {
  local session_dir="$1"
  local ctx_file="$session_dir/ci-context.json"
  if [ -s "$ctx_file" ]; then
    jq -r '.freshness_behind_commits // .freshness.behind // 0' "$ctx_file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# Append CI_TOOL_USED entry vao fix-log.json (atomic — tmp file + mv).
# Schema mo rong theo Protocol 20 §20.11 voi 2 fields moi: cache_hit + cache_source.
append_ci_log() {
  local session_dir="$1"
  local cache_hit="$2"        # "true" | "false"
  local cache_source="$3"     # "session_tier" | null
  local duration_ms="$4"
  local result_count="$5"
  local freshness_level="$6"
  local freshness_behind="$7"

  local log_file="$session_dir/fix-log.json"
  local tmp_file="${log_file}.tmp.$$"

  # Source = "null" string thi convert sang JSON null
  local cache_source_json
  if [ "$cache_source" = "null" ] || [ -z "$cache_source" ]; then
    cache_source_json="null"
  else
    cache_source_json="\"$cache_source\""
  fi

  local entry
  entry=$(cat <<EOF
{
  "event": "CI_TOOL_USED",
  "task": "impact_analysis",
  "primary": "gitnexus_impact",
  "secondary": null,
  "fallback_used": false,
  "cache_hit": $cache_hit,
  "cache_source": $cache_source_json,
  "duration_ms": $duration_ms,
  "result_count": $result_count,
  "freshness_behind_commits": $freshness_behind,
  "freshness_level": "$freshness_level",
  "timestamp": "$(iso_now)"
}
EOF
)

  # Initialize log file neu chua co (schema toi thieu: {entries: []})
  if [ ! -s "$log_file" ]; then
    echo '{"entries": []}' > "$log_file"
  fi

  # APPEND atomic
  if jq --argjson new "$entry" '.entries += [$new]' "$log_file" > "$tmp_file" 2>/dev/null; then
    mv "$tmp_file" "$log_file"
  else
    rm -f "$tmp_file"
    echo "[$SCRIPT_NAME] WARN: append CI log failed (jq error)" >&2
  fi
}

# Count result items trong impact JSON (best-effort — schema variant by GitNexus version).
count_impact_result() {
  local json="$1"
  printf '%s' "$json" | jq -r '
    if type == "object" then
      (.impacted_symbols // .affected // .targets // .nodes // [] | length)
    elif type == "array" then length
    else 0 end
  ' 2>/dev/null || echo 0
}

# ===========================================================================
# Cache subcommands (invoke Python cache_adapter inline)
# ===========================================================================

# File-backed session cache.
# Ly do: cache_adapter._session_cache la in-memory dict — khong persist giua subprocess.
# Moi `bash wrapper` lan launch Python process moi → cache reset → cache miss vinh vien.
# Giai phap: persist cache vao $SESSION_DIR/.ci-cache/impact/{sha256(key)}.json.
# Van la "session-tier" theo nghia logic — file nam trong $SESSION_DIR, khong leak cross-session.
# Cache xoa khi session ket thuc (orchestrator cleanup $SESSION_DIR).

# session_cache_file SESSION_DIR KEY → echo path
session_cache_file() {
  local session_dir="$1"
  local key="$2"
  # SHA256 (16 hex) cua key → filename ngan, tranh path-illegal chars
  local hash
  hash=$(printf '%s' "$key" | sha256sum 2>/dev/null | cut -c1-16) || \
    hash=$(printf '%s' "$key" | shasum -a 256 2>/dev/null | cut -c1-16) || \
    hash="$(date +%s%N)"
  printf '%s/.ci-cache/impact/%s.json' "$session_dir" "$hash"
}

# cache_lookup SESSION_DIR KEY → echo JSON neu HIT, echo "" neu MISS
cache_lookup() {
  local session_dir="$1"
  local key="$2"
  local f
  f=$(session_cache_file "$session_dir" "$key")
  if [ -s "$f" ]; then
    # Validate JSON parse + extract .data
    jq -e '.data' "$f" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# cache_store SESSION_DIR KEY JSON → atomic write file ($SESSION_DIR/.ci-cache/impact/{hash}.json)
cache_store() {
  local session_dir="$1"
  local key="$2"
  local json_payload="$3"
  local f
  f=$(session_cache_file "$session_dir" "$key")
  mkdir -p "$(dirname "$f")"
  local tmp="${f}.tmp.$$"
  # Validate JSON payload truoc khi luu
  if ! printf '%s' "$json_payload" | jq -e '.' >/dev/null 2>&1; then
    # Khong phai JSON hop le → khong cache (van log de tracking)
    return 0
  fi
  jq -n --arg key "$key" --argjson data "$json_payload" --arg ts "$(iso_now)" \
    '{key: $key, cached_at: $ts, data: $data}' > "$tmp" 2>/dev/null \
    && mv "$tmp" "$f" \
    || rm -f "$tmp"
}

# ===========================================================================
# Subcommand handlers
# ===========================================================================

cmd_lookup() {
  local session_dir="$1"
  local target="$2"
  local direction="${3:-upstream}"

  local freshness_level
  freshness_level="$(read_freshness "$session_dir")"
  local freshness_behind
  freshness_behind="$(read_freshness_behind "$session_dir")"

  # Bypass conditions — agent se invoke MCP fresh + goi `store` (hoac `bypass` neu severe)
  if [ "${MCV3_FIX_CI_CACHE_DISABLED:-0}" = "1" ]; then
    # Khong log o day — `bypass` subcommand se log sau khi co MCP result
    return 1
  fi
  if [ "$freshness_level" = "severe" ]; then
    # Severe → bypass cache (stale data risk)
    return 1
  fi

  local cache_key
  cache_key="$(build_cache_key "$target" "$direction")"

  local cached
  cached="$(cache_lookup "$session_dir" "$cache_key" || true)"

  if [ -n "$cached" ]; then
    # HIT — log + echo
    local result_count
    result_count="$(count_impact_result "$cached")"
    append_ci_log "$session_dir" "true" "session_tier" 10 "$result_count" \
      "$freshness_level" "$freshness_behind"
    printf '%s\n' "$cached"
    return 0
  fi

  # MISS — agent phai invoke MCP roi `store`. Khong log o day (vi se duplicate entry).
  return 1
}

cmd_store() {
  local session_dir="$1"
  local target="$2"
  local direction="${3:-upstream}"
  local impact_json="$4"
  local duration_ms="${5:-0}"

  local freshness_level
  freshness_level="$(read_freshness "$session_dir")"
  local freshness_behind
  freshness_behind="$(read_freshness_behind "$session_dir")"

  # Khong store khi disabled hoac severe (chi log miss/bypass)
  local cache_disabled="${MCV3_FIX_CI_CACHE_DISABLED:-0}"
  if [ "$cache_disabled" != "1" ] && [ "$freshness_level" != "severe" ]; then
    local cache_key
    cache_key="$(build_cache_key "$target" "$direction")"
    cache_store "$session_dir" "$cache_key" "$impact_json"
  fi

  local result_count
  result_count="$(count_impact_result "$impact_json")"

  # Log: cache_hit=false vi day la MCP fresh call (just stored)
  local source="null"
  if [ "$cache_disabled" = "1" ]; then
    source="bypass_disabled"
  elif [ "$freshness_level" = "severe" ]; then
    source="bypass_severe"
  fi
  append_ci_log "$session_dir" "false" "$source" "$duration_ms" "$result_count" \
    "$freshness_level" "$freshness_behind"
}

cmd_bypass() {
  # Variant cua store khi caller muon explicit log bypass khong cache.
  cmd_store "$@"
}

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME lookup  <session_dir> <target> [direction]
      Exit 0 + stdout=JSON neu HIT. Exit 1 (empty stdout) neu MISS hoac BYPASS.

  $SCRIPT_NAME store   <session_dir> <target> <direction> <impact_json> [duration_ms]
      Luu vao session cache + log CI_TOOL_USED entry voi cache_hit=false.

  $SCRIPT_NAME bypass  <session_dir> <target> <direction> <impact_json> [duration_ms]
      Khong cache, chi log bypass entry (cho escape hatch / freshness=severe).

Env:
  MCV3_FIX_CI_CACHE_DISABLED=1  Escape hatch — luon bypass cache.

Reads:
  \$session_dir/ci-context.json  (freshness_level, freshness_behind_commits)

Writes:
  \$session_dir/fix-log.json     (APPEND CI_TOOL_USED entry, atomic)
EOF
}

# ===========================================================================
# Main
# ===========================================================================

main() {
  local cmd="${1:-}"

  if [ -z "$cmd" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "-h" ]; then
    usage
    exit 2
  fi

  shift

  case "$cmd" in
    lookup)
      if [ "$#" -lt 2 ]; then usage; exit 2; fi
      cmd_lookup "$@"
      ;;
    store)
      if [ "$#" -lt 4 ]; then usage; exit 2; fi
      cmd_store "$@"
      ;;
    bypass)
      if [ "$#" -lt 4 ]; then usage; exit 2; fi
      cmd_bypass "$@"
      ;;
    *)
      echo "[$SCRIPT_NAME] ERROR: unknown subcommand '$cmd'" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
