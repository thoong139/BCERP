#!/usr/bin/env bash
# Background heartbeat daemon cho global R/W locks.
# Goi `heartbeat_session_locks <session_id>` moi 30s, lan stale_cleanup_locks moi vong.
# Tu dong exit khi:
#   - File pid daemon bi xoa
#   - Session lock file (session-level) bi xoa hoac stale
#   - PID parent (caller) khong con song
#
# Usage:
#   bash lock-daemon.sh start <session_id> <session_dir>
#     -> ghi daemon PID vao $session_dir/_locks/global-lock-daemon.pid, detach background
#   bash lock-daemon.sh stop  <session_dir>
#     -> kill daemon va release tat ca lock cua session
#
# Daemon loop:
#   while alive: heartbeat -> sleep 30 -> cleanup_stale -> repeat

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_LIB="$SCRIPT_DIR/global-rw-lock.sh"

_daemon_pidfile() {
  echo "$1/_locks/global-lock-daemon.pid"
}

_daemon_metafile() {
  echo "$1/_locks/global-lock-daemon.meta.json"
}

_run_daemon_loop() {
  local session_id="$1" session_dir="$2" parent_pid="$3"
  # shellcheck disable=SC1090
  source "$LOCK_LIB"
  local interval="${MCV3_LOCK_HEARTBEAT_SEC:-30}"

  trap 'release_all_session_locks "'"$session_id"'" 2>/dev/null; exit 0' TERM INT

  while true; do
    # Stop conditions
    if [[ ! -f "$session_dir/.lock" ]]; then
      release_all_session_locks "$session_id" 2>/dev/null || true
      exit 0
    fi
    if ! kill -0 "$parent_pid" 2>/dev/null; then
      # Parent died — release tat ca locks de tranh stuck
      release_all_session_locks "$session_id" 2>/dev/null || true
      exit 0
    fi

    heartbeat_session_locks "$session_id" 2>/dev/null || true
    cleanup_stale_locks 2>/dev/null || true

    sleep "$interval"
  done
}

start() {
  local session_id="$1" session_dir="$2"
  mkdir -p "$session_dir/_locks" 2>/dev/null || true
  local pidfile metafile
  pidfile=$(_daemon_pidfile "$session_dir")
  metafile=$(_daemon_metafile "$session_dir")

  # Da chay roi?
  if [[ -f "$pidfile" ]]; then
    local existing=$(cat "$pidfile" 2>/dev/null || echo "")
    if [[ -n "$existing" ]] && kill -0 "$existing" 2>/dev/null; then
      echo "{\"status\":\"already_running\",\"pid\":$existing}"
      return 0
    fi
    rm -f "$pidfile"
  fi

  # Detach daemon
  ( _run_daemon_loop "$session_id" "$session_dir" "$$" >/dev/null 2>&1 & echo $! ) > "$pidfile"
  local daemon_pid=$(cat "$pidfile" 2>/dev/null || echo 0)

  jq -n --arg sid "$session_id" --arg sdir "$session_dir" \
        --arg pid "$daemon_pid" --arg parent "$$" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    session_id: $sid, session_dir: $sdir,
    daemon_pid: ($pid|tonumber), parent_pid: ($parent|tonumber),
    started_at: $ts
  }' > "$metafile"

  echo "{\"status\":\"started\",\"daemon_pid\":$daemon_pid}"
}

stop() {
  local session_dir="$1"
  local pidfile metafile session_id
  pidfile=$(_daemon_pidfile "$session_dir")
  metafile=$(_daemon_metafile "$session_dir")

  if [[ -f "$pidfile" ]]; then
    local pid=$(cat "$pidfile" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    rm -f "$pidfile"
  fi

  # Release tat ca lock cua session
  if [[ -f "$metafile" ]]; then
    session_id=$(jq -r '.session_id // empty' "$metafile" 2>/dev/null)
    if [[ -n "$session_id" ]]; then
      # shellcheck disable=SC1090
      source "$LOCK_LIB"
      release_all_session_locks "$session_id" 2>/dev/null || true
    fi
  fi

  echo "{\"status\":\"stopped\"}"
}

case "${1:-help}" in
  start) shift; start "$@" ;;
  stop)  shift; stop  "$@" ;;
  help|*)
    cat <<EOF
lock-daemon.sh — Background heartbeat cho global R/W locks

USAGE:
  bash lock-daemon.sh start <session_id> <session_dir>
  bash lock-daemon.sh stop  <session_dir>

Behavior:
  - start: detach background daemon, ghi PID vao session_dir/_locks/global-lock-daemon.pid
  - Daemon heartbeat moi MCV3_LOCK_HEARTBEAT_SEC (default 30s)
  - Daemon tu exit khi session_dir/.lock bien mat hoac parent PID chet
  - stop: kill daemon + release_all_session_locks
EOF
    ;;
esac
