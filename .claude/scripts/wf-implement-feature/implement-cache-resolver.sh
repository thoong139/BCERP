#!/usr/bin/env bash
# implement-cache-resolver.sh — Cache validation + hash computation cho pattern cache.
# Sprint 2 — Adaptive Profile (G6 fix, dual invalidation TTL + git SHA hash).
#
# Usage:
#   bash implement-cache-resolver.sh --validate <CACHE_FILE>
#   bash implement-cache-resolver.sh --compute-hash <MODULE_PATH>
#   bash implement-cache-resolver.sh --check-fresh <CACHE_FILE> [--ttl-min=1440]
#   bash implement-cache-resolver.sh --info <CACHE_FILE>
#
# Modes:
#   --validate <CACHE_FILE>
#     Đọc CACHE_FILE.invalidation_hash + .module_path → compute current_hash
#     từ git ls-tree → so sánh. Exit 0 = hash match (valid), 1 = mismatch hoặc invalid JSON.
#
#   --compute-hash <MODULE_PATH>
#     Compute current invalidation hash cho module path. Output: hex sha1 (40 chars).
#     Format: `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum | cut -d' ' -f1`.
#     Nếu không phải git repo hoặc module path không tồn tại → output empty + exit 1.
#
#   --check-fresh <CACHE_FILE> [--ttl-min=N]
#     Check cache fresh theo TTL (mtime). Default 1440 phút (24h).
#     Exit 0 = fresh (within TTL), 1 = expired hoặc file không tồn tại.
#
#   --info <CACHE_FILE>
#     In ra metadata cache (module_slug, git_sha, invalidation_hash, scanned_at, age_min).
#     Exit 0 nếu file đọc được, 1 nếu không.
#
# Cross-platform notes:
#   - Git Bash Windows: jq -r output có \r → strip với tr -d '\r' khi compare strings.
#   - sha1sum vs shasum: dùng sha1sum nếu có, fallback shasum -a 1.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

MODE=""
TARGET=""
TTL_MIN=1440  # 24h default

# ─── Parse args ─────────────────────────────────────────────

# Pattern: 2 positional args (--mode + value) hoặc 3 (mode + value + --ttl-min=N)
for arg in "$@"; do
  case "$arg" in
    --validate|--compute-hash|--check-fresh|--info)
      MODE="$arg"
      ;;
    --ttl-min=*)
      TTL_MIN="${arg#*=}"
      ;;
    --*)
      log_warn "Unknown flag: $arg"
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$arg"
      else
        log_warn "Unexpected positional arg: $arg"
      fi
      ;;
  esac
done

[[ -z "$MODE" ]]   && { log_error "Missing mode. Use --validate, --compute-hash, --check-fresh, or --info."; exit 2; }
[[ -z "$TARGET" ]] && { log_error "Missing target argument cho mode $MODE."; exit 2; }

# ─── sha1 helper (cross-platform) ───────────────────────────

_sha1() {
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 1 | cut -d' ' -f1
  else
    log_error "Neither sha1sum nor shasum available — cannot compute hash"
    return 1
  fi
}

_compute_module_hash() {
  local module_path="$1"
  if ! git rev-parse HEAD >/dev/null 2>&1; then
    log_warn "Not a git repository — cannot compute git-based hash"
    return 1
  fi
  # ls-tree empty result OK → hash của empty input vẫn deterministic
  local result
  result=$(git ls-tree -r HEAD -- "$module_path" 2>/dev/null | _sha1) || return 1
  echo "$result"
}

# ─── Mode dispatch ──────────────────────────────────────────

case "$MODE" in
  --validate)
    CACHE_FILE="$TARGET"
    if [[ ! -f "$CACHE_FILE" ]]; then
      log_warn "Cache file không tồn tại: $CACHE_FILE"
      exit 1
    fi
    if ! has_jq; then
      log_error "jq required cho --validate"
      exit 2
    fi
    if ! jq empty "$CACHE_FILE" 2>/dev/null; then
      log_warn "Cache file invalid JSON: $CACHE_FILE"
      exit 1
    fi
    STORED_HASH=$(jq -r '.invalidation_hash // empty' "$CACHE_FILE" | tr -d '\r')
    MODULE_PATH=$(jq -r '.module_path // empty' "$CACHE_FILE" | tr -d '\r')

    if [[ -z "$STORED_HASH" ]]; then
      log_warn "Cache thiếu .invalidation_hash field — invalid"
      exit 1
    fi
    if [[ -z "$MODULE_PATH" ]]; then
      log_warn "Cache thiếu .module_path field — invalid"
      exit 1
    fi

    CURRENT_HASH=$(_compute_module_hash "$MODULE_PATH" || echo "")
    if [[ -z "$CURRENT_HASH" ]]; then
      log_warn "Không compute được current hash — treat as invalid"
      exit 1
    fi

    if [[ "$STORED_HASH" == "$CURRENT_HASH" ]]; then
      log_debug "Cache valid: hash match ($STORED_HASH)"
      exit 0
    else
      log_info "Cache stale: stored=$STORED_HASH current=$CURRENT_HASH"
      exit 1
    fi
    ;;

  --compute-hash)
    MODULE_PATH="$TARGET"
    if [[ ! -e "$MODULE_PATH" ]]; then
      log_warn "Module path không tồn tại: $MODULE_PATH (compute hash anyway từ git ls-tree)"
    fi
    HASH=$(_compute_module_hash "$MODULE_PATH" || echo "")
    if [[ -z "$HASH" ]]; then
      exit 1
    fi
    echo "$HASH"
    exit 0
    ;;

  --check-fresh)
    CACHE_FILE="$TARGET"
    if [[ ! -f "$CACHE_FILE" ]]; then
      log_debug "Cache file không tồn tại: $CACHE_FILE"
      exit 1
    fi
    if ! [[ "$TTL_MIN" =~ ^[0-9]+$ ]]; then
      log_error "Invalid --ttl-min: $TTL_MIN"
      exit 2
    fi
    # mtime check
    NOW=$(date +%s)
    MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    AGE_SEC=$(( NOW - MTIME ))
    AGE_MIN=$(( AGE_SEC / 60 ))
    if (( AGE_MIN < TTL_MIN )); then
      log_debug "Cache fresh: age=${AGE_MIN}min, ttl=${TTL_MIN}min"
      exit 0
    else
      log_info "Cache expired: age=${AGE_MIN}min >= ttl=${TTL_MIN}min"
      exit 1
    fi
    ;;

  --info)
    CACHE_FILE="$TARGET"
    if [[ ! -f "$CACHE_FILE" ]]; then
      log_warn "Cache file không tồn tại: $CACHE_FILE"
      exit 1
    fi
    if ! has_jq; then
      log_error "jq required cho --info"
      exit 2
    fi
    if ! jq empty "$CACHE_FILE" 2>/dev/null; then
      log_warn "Cache file invalid JSON"
      exit 1
    fi
    NOW=$(date +%s)
    MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    AGE_MIN=$(( (NOW - MTIME) / 60 ))
    jq --argjson age_min "$AGE_MIN" \
       '{module_slug:.module_slug, git_sha:.git_sha, invalidation_hash:.invalidation_hash,
         module_path:.module_path, scanned_at:.scanned_at, age_min:$age_min}' \
       "$CACHE_FILE"
    exit 0
    ;;

  *)
    log_error "Unknown mode: $MODE"
    exit 2
    ;;
esac
