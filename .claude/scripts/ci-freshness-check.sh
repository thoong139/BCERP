#!/usr/bin/env bash
# =============================================================================
# ci-freshness-check.sh — Compare HEAD vs GitNexus index commit
# =============================================================================
# Protocol 20 implementation: index freshness check (D9).
# Chạy mỗi PRE-GATE, không cache. Chi phí: git rev-parse + git rev-list < 0.1s.
#
# Output: JSON (stdout) — parseable by skill agent
# Exit: 0 (OK) | 1 (WARNING light, <=5 behind) | 2 (STRONG, 6-20) | 3 (SEVERE, >20)
#
# Compatibility: Git Bash + WSL. Pure bash integer arithmetic (no bc, F21).
# Pipefail is NOT used — explicit check after each command instead.
# =============================================================================

set -euo pipefail 2>/dev/null || set -eu  # Graceful for bash < 4.4

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"

# ── Short-circuit: không phải git repo → skip ──
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo '{"status":"skipped","reason":"not a git repository"}'
  exit 0
fi

# ── Check if GitNexus available ──
if [[ ! -f "$CACHE_FILE" ]]; then
  echo '{"status":"skipped","reason":"no cache file"}'
  exit 0
fi

GITNEXUS_AVAILABLE=$(jq -r '.gitnexus.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo '{"status":"skipped","reason":"gitnexus not available"}'
  exit 0
fi

# ── Get index commit from cache ──
INDEX_COMMIT=$(jq -r '.gitnexus.index_commit // ""' "$CACHE_FILE" 2>/dev/null || echo "")
if [[ -z "$INDEX_COMMIT" ]] || [[ "$INDEX_COMMIT" == "null" ]]; then
  echo '{"status":"unknown","reason":"index_commit missing in cache"}'
  exit 0
fi

# ── Compare with HEAD ──
HEAD_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -z "$HEAD_COMMIT" ]]; then
  echo '{"status":"skipped","reason":"cannot resolve HEAD"}'
  exit 0
fi

if [[ "$INDEX_COMMIT" == "$HEAD_COMMIT" ]]; then
  # Emit `level` field even on OK path so downstream consumers can rely on it
  # being present (Protocol 20 §20.7 freshness_level: ok|warning|strong_warning|severe).
  echo "{\"status\":\"ok\",\"level\":\"ok\",\"behind\":0,\"index_commit\":\"$INDEX_COMMIT\",\"head\":\"$HEAD_COMMIT\"}"
  exit 0
fi

# ── Count commits behind (pure integer) ──
BEHIND=$(git rev-list --count "$INDEX_COMMIT..$HEAD_COMMIT" 2>/dev/null || echo "unknown")

if [[ "$BEHIND" == "unknown" ]]; then
  echo "{\"status\":\"unknown\",\"reason\":\"index_commit not in history (index from different branch?)\"}"
  exit 0
fi

# ── Index age check (> 7 ngày = WARNING stderr, không block) ──
INDEXED_AT=$(jq -r '.gitnexus.indexed_at // ""' "$CACHE_FILE" 2>/dev/null || echo "")
if [[ -n "$INDEXED_AT" ]] && [[ "$INDEXED_AT" != "null" ]]; then
  INDEXED_EPOCH=$(date -d "$INDEXED_AT" +%s 2>/dev/null || echo "0")
  if [[ "$INDEXED_EPOCH" != "0" ]]; then
    NOW_EPOCH=$(date +%s)
    INDEX_AGE_DAYS=$(( (NOW_EPOCH - INDEXED_EPOCH) / 86400 ))
    if [[ "$INDEX_AGE_DAYS" -gt 7 ]] 2>/dev/null; then
      echo "[ci-freshness] WARNING: GitNexus index is ${INDEX_AGE_DAYS} days old. Consider re-indexing: gitnexus analyze" >&2
    fi
  fi
fi

# ── Warning levels ──
if [[ "$BEHIND" -le 5 ]]; then
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"light\",\"message\":\"GitNexus index behind HEAD by $BEHIND commits. Impact analysis may miss recent changes.\",\"index_commit\":\"$INDEX_COMMIT\",\"head\":\"$HEAD_COMMIT\"}"
  exit 1
elif [[ "$BEHIND" -le 20 ]]; then
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"strong\",\"message\":\"Index significantly behind ($BEHIND commits). Consider: gitnexus analyze\",\"index_commit\":\"$INDEX_COMMIT\",\"head\":\"$HEAD_COMMIT\"}"
  exit 2
else
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"severe\",\"message\":\"Index is $BEHIND commits behind HEAD. Impact analysis likely incomplete. Recommend re-index before continuing.\",\"index_commit\":\"$INDEX_COMMIT\",\"head\":\"$HEAD_COMMIT\"}"
  exit 3
fi
