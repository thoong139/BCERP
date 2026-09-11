#!/usr/bin/env bash
# implement-acquire-lock.sh — Acquire lock cho wf-implement-feature.
# Sprint 1 bash delegation — DRY pattern cho per-feature lock + registry mutex.
#
# Usage:
#   bash implement-acquire-lock.sh --system=$SYS --slug=$SLUG --type=feature --resume=true|false
#   bash implement-acquire-lock.sh --type=registry [--timeout=30]
#   bash implement-acquire-lock.sh --type=decision-registry [--timeout=30]
#
# Args:
#   --system=<slug>      System slug (required cho --type=feature trong v5.0)
#   --slug=<slug>        Feature slug (required cho --type=feature)
#   --type=<type>        feature | registry | decision-registry
#   --resume=true|false  Khi resume, bỏ qua busy check (cùng session) — default false
#   --feature-id=<id>    FEAT-ID (optional, lưu vào lock metadata cho feature lock)
#   --timeout=<sec>      Wait timeout in seconds (default 30 cho registry; 0 cho feature = fail-fast)
#
# Exit codes:
#   0 = acquired
#   1 = busy (other process alive)
#   2 = timeout (registry/decision-registry only)
#   3 = invalid args
#
# Stdout: lock file path (when acquired) hoặc empty.
# Stderr: log messages.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# ─── Parse args ──────────────────────────────────────────────

SLUG=""
SYSTEM=""
TYPE=""
RESUME="false"
FEAT_ID=""
TIMEOUT=""

for arg in "$@"; do
  case "$arg" in
    --system=*)      SYSTEM="${arg#*=}" ;;
    --slug=*)        SLUG="${arg#*=}" ;;
    --type=*)        TYPE="${arg#*=}" ;;
    --resume=*)      RESUME="${arg#*=}" ;;
    --feature-id=*)  FEAT_ID="${arg#*=}" ;;
    --timeout=*)     TIMEOUT="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

# ─── Validate ────────────────────────────────────────────────

case "$TYPE" in
  feature)
    [[ -z "$SLUG" ]] && { log_error "--slug required cho --type=feature"; exit 3; }
    # v5.0: --system required cho per-system lock scoping
    if [[ -z "$SYSTEM" ]]; then
      # Backward-compat: nếu chưa pass --system, auto-derive (graceful)
      SYSTEM=$(derive_system_slug "$SLUG")
      log_debug "Auto-derived system_slug: $SYSTEM (consider passing --system explicitly)"
    fi
    LOCK_FILE="$LOCKS_DIR/$SYSTEM/$SLUG.lock"
    STALE_MIN="$IMPLEMENT_FEATURE_LOCK_STALE_MIN"
    [[ -z "$TIMEOUT" ]] && TIMEOUT=0   # feature lock fail-fast
    ;;
  registry)
    LOCK_FILE=".mc-data/docs/_meta/.registry.lock"
    STALE_MIN="$IMPLEMENT_REGISTRY_LOCK_STALE_MIN"
    [[ -z "$TIMEOUT" ]] && TIMEOUT=30
    ;;
  decision-registry)
    LOCK_FILE=".mc-data/docs/_meta/.decision-registry.lock"
    STALE_MIN="$IMPLEMENT_REGISTRY_LOCK_STALE_MIN"
    [[ -z "$TIMEOUT" ]] && TIMEOUT=30
    ;;
  *)
    log_error "--type phải là: feature | registry | decision-registry"
    exit 3
    ;;
esac

mkdir -p "$(dirname "$LOCK_FILE")"

# ─── Lock content builder ────────────────────────────────────

build_lock_content() {
  local current_host
  current_host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")

  if has_jq; then
    jq -nc \
      --arg type "$TYPE" \
      --arg slug "$SLUG" \
      --arg sys "$SYSTEM" \
      --arg fid "$FEAT_ID" \
      --argjson pid "$$" \
      --arg host "$current_host" \
      --arg user "${USER:-unknown}" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{type:$type, system_slug:$sys, feature_slug:$slug, feature_id:$fid, pid:$pid, host:$host, user:$user, started_at:$ts, scope_files_exclusive:[]}'
  else
    printf '{"type":"%s","system_slug":"%s","feature_slug":"%s","feature_id":"%s","pid":%d,"host":"%s","user":"%s","started_at":"%s","scope_files_exclusive":[]}' \
      "$TYPE" "$SYSTEM" "$SLUG" "$FEAT_ID" "$$" "$current_host" "${USER:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
}

# ─── Stale detection ─────────────────────────────────────────

is_stale() {
  local lock="$1"
  [[ ! -f "$lock" ]] && return 0   # missing → treated as stale (no lock to honor)

  local pid="" started_at=""
  if has_jq; then
    pid=$(jq -r '.pid // empty' "$lock" 2>/dev/null || echo "")
    started_at=$(jq -r '.started_at // empty' "$lock" 2>/dev/null || echo "")
  fi

  # Malformed → stale
  [[ -z "$pid" ]] && return 0

  # PID alive check (same host only)
  local current_host lock_host
  current_host=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")
  lock_host=$(jq -r '.host // empty' "$lock" 2>/dev/null || echo "")

  if [[ "$lock_host" != "$current_host" ]]; then
    # Cross-host: cannot kill -0 → check age only
    local now lock_ts age_min
    now=$(date +%s)
    lock_ts=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
    age_min=$(( (now - lock_ts) / 60 ))
    if (( age_min >= STALE_MIN )); then
      log_warn "Cross-host lock stale (age=${age_min}min, threshold=${STALE_MIN}min)"
      return 0
    fi
    return 1   # alive
  fi

  # Same host — kill -0
  if kill -0 "$pid" 2>/dev/null; then
    # PID alive — check age cap
    local now lock_ts age_min
    now=$(date +%s)
    lock_ts=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
    age_min=$(( (now - lock_ts) / 60 ))
    if (( age_min >= STALE_MIN )); then
      log_warn "Lock alive but age=${age_min}min >= threshold=${STALE_MIN}min — treat as stale"
      return 0
    fi
    return 1   # alive
  fi

  return 0   # PID dead → stale
}

# ─── Acquire ────────────────────────────────────────────────

acquire_once() {
  # Atomic create với O_EXCL semantics
  mkdir -p "$(dirname "$LOCK_FILE")"
  if ( set -C; build_lock_content > "$LOCK_FILE" ) 2>/dev/null; then
    log_debug "Acquired lock $LOCK_FILE (pid=$$)"
    echo "$LOCK_FILE"
    return 0
  fi
  return 1
}

# Resume mode: bỏ qua check, overwrite lock với current PID
if [[ "$RESUME" == "true" && "$TYPE" == "feature" ]]; then
  mkdir -p "$(dirname "$LOCK_FILE")"
  build_lock_content > "$LOCK_FILE"
  log_info "Resume mode — refreshed lock $LOCK_FILE"
  echo "$LOCK_FILE"
  exit 0
fi

# Existing lock — check stale
if [[ -f "$LOCK_FILE" ]]; then
  if is_stale "$LOCK_FILE"; then
    log_warn "Removing stale lock: $LOCK_FILE"
    rm -f "$LOCK_FILE"
  else
    # Lock alive — try wait nếu có timeout
    if (( TIMEOUT > 0 )); then
      log_info "Lock busy — waiting up to ${TIMEOUT}s"
      WAITED=0
      while (( WAITED < TIMEOUT )); do
        sleep 1
        WAITED=$(( WAITED + 1 ))
        if [[ ! -f "$LOCK_FILE" ]] || is_stale "$LOCK_FILE"; then
          rm -f "$LOCK_FILE"
          break
        fi
      done
      if [[ -f "$LOCK_FILE" ]] && ! is_stale "$LOCK_FILE"; then
        log_error "Lock timeout after ${TIMEOUT}s: $LOCK_FILE"
        exit 2
      fi
    else
      # No wait — fail fast
      local_pid=$(jq -r '.pid // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
      local_host=$(jq -r '.host // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
      local_started=$(jq -r '.started_at // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
      log_error "Lock busy: pid=$local_pid host=$local_host started_at=$local_started"
      exit 1
    fi
  fi
fi

# Try acquire
if acquire_once; then
  exit 0
fi

# Race: someone else got it first
log_error "Lock acquire race lost: $LOCK_FILE"
exit 1
