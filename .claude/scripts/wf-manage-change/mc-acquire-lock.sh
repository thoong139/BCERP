#!/usr/bin/env bash
# mc-acquire-lock.sh — Acquire lock (session or registry)
# Usage: mc-acquire-lock.sh --type=session --id=CHG-20260429-001
#        mc-acquire-lock.sh --type=registry --id=CHG-20260429-001
#
# Exit codes: 0 = acquired, 1 = busy, 2 = invalid args

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

TYPE=""
ID=""

for arg in "$@"; do
  case "$arg" in
    --type=*) TYPE="${arg#*=}" ;;
    --id=*)   ID="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$TYPE" || -z "$ID" ]]; then
  mc_err "Usage: mc-acquire-lock.sh --type=session|registry --id=CHANGE_ID"
  exit 2
fi

mc_ensure_dirs

if [[ "$TYPE" == "session" ]]; then
  LOCK_FILE="$MC_ROOT/$ID/.session.lock"
  mkdir -p "$MC_ROOT/$ID"
elif [[ "$TYPE" == "registry" ]]; then
  LOCK_FILE="$MC_LOCKS_DIR/registry.lock"
else
  mc_err "Invalid lock type: $TYPE (expected: session | registry)"
  exit 2
fi

# ─── Stale detection ─────────────────────────────────────────

is_stale() {
  local lock="$1"
  # Check both file-based (legacy) and mkdir-based lock
  local lock_data="$lock"
  if [[ ! -f "$lock" ]]; then
    local lock_dir="${lock}.d"
    if [[ -d "$lock_dir" && -f "$lock_dir/lock.json" ]]; then
      lock_data="$lock_dir/lock.json"
    else
      return 0  # No lock → stale (nothing to clean)
    fi
  fi

  local pid="" started_at=""
  if mc_has_jq; then
    pid=$(jq -r '.pid // empty' "$lock_data" 2>/dev/null || echo "")
    started_at=$(jq -r '.started_at // .locked_at // empty' "$lock_data" 2>/dev/null || echo "")
  fi

  # Malformed lock → stale
  [[ -z "$pid" ]] && return 0

  local current_host lock_host
  current_host=$(mc_host)
  lock_host=$(jq -r '.host // empty' "$lock" 2>/dev/null || echo "")

  # Parse timestamp safely — guard against empty string (date -d "" returns NOW, not 0)
  local now lock_ts age_min
  now=$(mc_epoch)
  if [[ -z "$started_at" ]]; then
    lock_ts=0
  else
    lock_ts=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
  fi

  if [[ "$lock_host" != "$current_host" ]]; then
    # Cross-host: check age only
    age_min=$(( (now - lock_ts) / 60 ))
    if (( age_min >= MC_LOCK_STALE_MIN )); then
      mc_warn "Cross-host stale lock (age=${age_min}min >= ${MC_LOCK_STALE_MIN}min)"
      return 0
    fi
    return 1
  fi

  # Same host — check PID alive
  if kill -0 "$pid" 2>/dev/null; then
    # PID alive — check age
    age_min=$(( (now - lock_ts) / 60 ))
    if (( age_min >= MC_LOCK_STALE_MIN )); then
      mc_warn "Lock alive but stale (age=${age_min}min >= ${MC_LOCK_STALE_MIN}min) — takeover"
      return 0
    fi
    return 1  # alive
  fi

  return 0  # PID dead → stale
}

# ─── Lock content builder ────────────────────────────────────

build_lock_content() {
  local ts
  ts=$(mc_timestamp)

  if mc_has_jq; then
    if [[ "$TYPE" == "session" ]]; then
      jq -nc \
        --arg id "$ID" \
        --argjson pid "$$" \
        --arg host "$(mc_host)" \
        --arg user "$(mc_user)" \
        --arg ts "$ts" \
        '{change_id:$id, pid:$pid, host:$host, user:$user, started_at:$ts, heartbeat_at:$ts, heartbeat_interval_sec:30}'
    else
      jq -nc \
        --arg id "$ID" \
        --argjson pid "$$" \
        --arg host "$(mc_host)" \
        --arg user "$(mc_user)" \
        --arg ts "$ts" \
        --arg purpose "registry_update" \
        '{locked_by:$id, pid:$pid, host:$host, user:$user, locked_at:$ts, purpose:$purpose}'
    fi
  else
    if [[ "$TYPE" == "session" ]]; then
      printf '{"change_id":"%s","pid":%d,"host":"%s","user":"%s","started_at":"%s","heartbeat_at":"%s","heartbeat_interval_sec":30}' \
        "$ID" "$$" "$(mc_host)" "$(mc_user)" "$ts" "$ts"
    else
      printf '{"locked_by":"%s","pid":%d,"host":"%s","user":"%s","locked_at":"%s","purpose":"registry_update"}' \
        "$ID" "$$" "$(mc_host)" "$(mc_user)" "$ts"
    fi
  fi
}

# ─── Check existing lock ─────────────────────────────────────

if [[ -f "$LOCK_FILE" ]]; then
  if is_stale "$LOCK_FILE"; then
    mc_warn "Removing stale lock: $LOCK_FILE"
    rm -f "$LOCK_FILE"
  else
    # Lock active — report owner
    lock_pid=$(jq -r '.pid // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
    lock_host=$(jq -r '.host // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
    lock_user=$(jq -r '.user // "?"' "$LOCK_FILE" 2>/dev/null || echo "?")
    mc_err "Lock active: $LOCK_FILE (owner: ${lock_user}@${lock_host}, PID: $lock_pid)"
    mc_err "Neu lock bay, xoa thu cong hoac doi $MC_LOCK_STALE_MIN phut"
    exit 1
  fi
fi

# ─── Acquire via mkdir (POSIX atomic on ALL filesystems) ────

# Use mkdir-based lock directory for true atomicity (same pattern as wf-fix-bugs, wf-add-scope)
LOCK_DIR="${LOCK_FILE}.d"
if mkdir "$LOCK_DIR" 2>/dev/null; then
  # Won the race — write metadata into the lock directory
  build_lock_content > "$LOCK_DIR/lock.json"
  # Symlink for backward compat (procedures expect $LOCK_FILE to exist)
  ln -s "$LOCK_DIR/lock.json" "$LOCK_FILE" 2>/dev/null || true
  mc_log "Lock acquired: $LOCK_FILE"
  exit 0
fi

# Race: someone else got it
mc_err "Lock acquire race lost: $LOCK_FILE"
exit 1
