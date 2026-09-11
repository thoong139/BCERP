#!/usr/bin/env bash
# Cross-session R/W lock cho infrastructure shared resources (BE/FE/DB/Playwright).
#
# Pattern: multi-reader + single-writer, writer priority (avoid starvation),
# heartbeat 30s, stale 2min auto-release, wait timeout 10 phut roi ESCALATE.
#
# Resources canonical: backend | frontend | database | playwright
# Lock files: .mc-data/_global_locks/{resource}.lock
# Audit trail: .mc-data/_global_locks/_audit/lock-events.jsonl (APPEND-only)
#
# Usage:
#   source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
#   acquire_reader_lock <resource> <session_id> [feat_id]
#   release_reader_lock <resource> <session_id>
#   acquire_writer_lock <resource> <session_id> [feat_id] [reason]
#   release_writer_lock <resource> <session_id>
#   upgrade_to_writer  <resource> <session_id> [reason]
#   downgrade_to_reader <resource> <session_id>
#   heartbeat_session_locks <session_id>
#   cleanup_stale_locks
#   display_lock_status <resource>
#
# Schema lock file (global-rw-lock-v1):
# {
#   "$schema": "global-rw-lock-v1",
#   "resource": "backend",
#   "readers": [{session_id, feat_id, pid, host, acquired_at, last_heartbeat, intent}],
#   "writer": null | {session_id, feat_id, pid, host, acquired_at, last_heartbeat, reason},
#   "writer_pending": [{session_id, feat_id, pid, host, queued_at, reason}],
#   "last_updated": "<ISO>",
#   "lock_file_version": 1
# }
#
# Exit codes (chi cho acquire_*):
#   0 = acquired
#   1 = generic error (jq missing, IO fail)
#   2 = timeout 10min, ESCALATE
#   3 = invalid args

set -uo pipefail

# Globals (overridable via env)
GLOBAL_LOCKS_DIR="${MCV3_GLOBAL_LOCKS_DIR:-.mc-data/_global_locks}"
LOCK_AUDIT_LOG="$GLOBAL_LOCKS_DIR/_audit/lock-events.jsonl"
LOCK_HEARTBEAT_SEC="${MCV3_LOCK_HEARTBEAT_SEC:-30}"
LOCK_STALE_SEC="${MCV3_LOCK_STALE_SEC:-120}"          # 2 min
LOCK_WAIT_TIMEOUT_SEC="${MCV3_LOCK_WAIT_TIMEOUT_SEC:-600}"  # 10 min
LOCK_POLL_INTERVAL_SEC="${MCV3_LOCK_POLL_INTERVAL_SEC:-5}"
LOCK_VALID_RESOURCES="backend frontend database playwright"

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

_lock_iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_lock_epoch_now() { date +%s; }

_lock_host() {
  if command -v hostname >/dev/null 2>&1; then hostname; else echo "${COMPUTERNAME:-unknown}"; fi
}

_lock_user() {
  echo "${USER:-${USERNAME:-unknown}}"
}

_lock_validate_resource() {
  local r="$1"
  case " $LOCK_VALID_RESOURCES " in
    *" $r "*) return 0 ;;
    *) echo "ERROR: invalid resource '$r'. Valid: $LOCK_VALID_RESOURCES" >&2; return 3 ;;
  esac
}

_lock_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq required for R/W lock operations" >&2
    return 1
  fi
}

_lock_file_path() {
  echo "$GLOBAL_LOCKS_DIR/$1.lock"
}

_lock_acquiring_dir() {
  echo "$GLOBAL_LOCKS_DIR/.$1.acquiring"
}

_lock_ensure_dirs() {
  mkdir -p "$GLOBAL_LOCKS_DIR" "$GLOBAL_LOCKS_DIR/_audit" "$GLOBAL_LOCKS_DIR/version-snapshot" 2>/dev/null || true
}

_lock_init_file_if_missing() {
  local resource="$1"
  local file="$(_lock_file_path "$resource")"
  if [[ ! -f "$file" ]]; then
    jq -n --arg r "$resource" --arg now "$(_lock_iso_now)" '{
      "$schema": "global-rw-lock-v1",
      "resource": $r,
      "readers": [],
      "writer": null,
      "writer_pending": [],
      "last_updated": $now,
      "lock_file_version": 1
    }' > "$file"
  fi
}

# Atomic write helper: build via jq filter args, validate, atomic move.
# Usage: _lock_atomic_update <file> <jq_filter> [jq_args...]
_lock_atomic_update() {
  local file="$1"; shift
  local filter="$1"; shift
  local tmp="${file}.tmp.$$"
  if jq "$@" "$filter" "$file" > "$tmp" 2>/dev/null; then
    if jq '.' "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$file"
      return 0
    fi
  fi
  rm -f "$tmp"
  echo "ERROR: atomic update failed for $file" >&2
  return 1
}

# Audit log (APPEND-only JSONL)
_lock_audit() {
  local event="$1" resource="$2" session_id="$3" extra="${4:-{}}"
  _lock_ensure_dirs
  jq -n --arg ev "$event" --arg r "$resource" --arg sid "$session_id" \
        --arg ts "$(_lock_iso_now)" --argjson extra "$extra" \
    '{timestamp:$ts, event:$ev, resource:$r, session_id:$sid} + $extra' \
    >> "$LOCK_AUDIT_LOG" 2>/dev/null || true
}

# Cleanup stale entries (heartbeat older than LOCK_STALE_SEC) from a lock file.
# Returns 0 if mutated, 1 if no change.
_lock_cleanup_stale_in_file() {
  local resource="$1"
  local file="$(_lock_file_path "$resource")"
  [[ -f "$file" ]] || return 1

  local now=$(_lock_epoch_now)
  local stale=$LOCK_STALE_SEC

  # Use jq to filter out stale readers + writer if heartbeat too old.
  # Compare epoch by parsing ISO via mktime in jq.
  local filter='
    def epoch($iso): ($iso | fromdateiso8601);
    def is_alive($entry): ($now - epoch($entry.last_heartbeat // $entry.acquired_at // $entry.queued_at)) <= $stale;

    .readers = (.readers | map(select(is_alive(.)))) |
    (if .writer != null and (is_alive(.writer) | not) then .writer = null else . end) |
    .writer_pending = (.writer_pending | map(select(is_alive(.)))) |
    .last_updated = $now_iso
  '
  _lock_atomic_update "$file" "$filter" \
    --argjson now "$now" --argjson stale "$stale" --arg now_iso "$(_lock_iso_now)"
}

cleanup_stale_locks() {
  _lock_require_jq || return 1
  _lock_ensure_dirs
  local r
  for r in $LOCK_VALID_RESOURCES; do
    _lock_cleanup_stale_in_file "$r" >/dev/null 2>&1 || true
  done
  return 0
}

# Acquiring guard: mkdir-based atomic ticket. 5s wait max.
_lock_acquire_guard() {
  local resource="$1"
  local guard_dir="$(_lock_acquiring_dir "$resource")"
  local i=0
  while ! mkdir "$guard_dir" 2>/dev/null; do
    i=$((i+1))
    if (( i > 25 )); then  # 5s with 0.2s sleep
      # Stale guard? If older than 30s, force-remove
      if [[ -d "$guard_dir" ]]; then
        local mtime=$(stat -c %Y "$guard_dir" 2>/dev/null || stat -f %m "$guard_dir" 2>/dev/null || echo 0)
        local age=$(($(_lock_epoch_now) - mtime))
        if (( age > 30 )); then
          rm -rf "$guard_dir" 2>/dev/null || true
          continue
        fi
      fi
      return 1
    fi
    sleep 0.2
  done
  return 0
}

_lock_release_guard() {
  rmdir "$(_lock_acquiring_dir "$1")" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

# acquire_reader_lock <resource> <session_id> [feat_id]
# Holds reader slot. Waits if a writer holds the lock or writer_pending non-empty
# (writer priority). Returns 0 acquired, 2 timeout.
acquire_reader_lock() {
  local resource="$1" session_id="$2" feat_id="${3:-}"
  _lock_validate_resource "$resource" || return 3
  _lock_require_jq || return 1
  _lock_ensure_dirs
  _lock_init_file_if_missing "$resource"

  local file="$(_lock_file_path "$resource")"
  local started=$(_lock_epoch_now)

  while true; do
    cleanup_stale_locks >/dev/null 2>&1 || true
    _lock_acquire_guard "$resource" || { sleep 1; continue; }

    local can_enter
    can_enter=$(jq -r --arg sid "$session_id" '
      if .writer != null and .writer.session_id != $sid then "no_writer_active"
      elif (.writer_pending | length) > 0 and ([.writer_pending[] | select(.session_id != $sid)] | length) > 0 then "no_writer_pending"
      elif (.readers | map(.session_id) | index($sid)) != null then "already"
      else "yes"
      end
    ' "$file")

    if [[ "$can_enter" == "already" ]]; then
      _lock_release_guard "$resource"
      _lock_audit "reader_reentry" "$resource" "$session_id" '{}'
      return 0
    fi

    if [[ "$can_enter" == "yes" ]]; then
      _lock_atomic_update "$file" '
        .readers += [$entry] | .last_updated = $now
      ' \
        --argjson entry "$(jq -n \
          --arg sid "$session_id" --arg fid "$feat_id" --arg pid "$$" \
          --arg host "$(_lock_host)" --arg now "$(_lock_iso_now)" \
          '{session_id:$sid, feat_id:$fid, pid:($pid|tonumber), host:$host,
            acquired_at:$now, last_heartbeat:$now, intent:"test"}')" \
        --arg now "$(_lock_iso_now)" >/dev/null || {
        _lock_release_guard "$resource"; return 1;
      }
      _lock_release_guard "$resource"
      _lock_audit "reader_acquired" "$resource" "$session_id" \
        "$(jq -nc --arg f "$feat_id" '{feat_id:$f}')"
      return 0
    fi

    _lock_release_guard "$resource"

    # Check timeout
    local elapsed=$(( $(_lock_epoch_now) - started ))
    if (( elapsed >= LOCK_WAIT_TIMEOUT_SEC )); then
      _lock_audit "reader_timeout" "$resource" "$session_id" \
        "$(jq -nc --arg e "$elapsed" '{elapsed_sec:($e|tonumber)}')"
      echo "TIMEOUT: cho reader lock '$resource' qua $LOCK_WAIT_TIMEOUT_SEC giay" >&2
      display_lock_status "$resource" >&2
      return 2
    fi

    # Display progress mỗi 30s
    if (( elapsed > 0 && elapsed % 30 == 0 )); then
      echo "[$resource] waiting reader lock... ${elapsed}s elapsed (reason: $can_enter)" >&2
      display_lock_status "$resource" >&2
    fi
    sleep "$LOCK_POLL_INTERVAL_SEC"
  done
}

# release_reader_lock <resource> <session_id>
release_reader_lock() {
  local resource="$1" session_id="$2"
  _lock_validate_resource "$resource" || return 3
  _lock_require_jq || return 1
  local file="$(_lock_file_path "$resource")"
  [[ -f "$file" ]] || return 0

  _lock_acquire_guard "$resource" || return 1
  _lock_atomic_update "$file" '
    .readers = (.readers | map(select(.session_id != $sid))) |
    .last_updated = $now
  ' --arg sid "$session_id" --arg now "$(_lock_iso_now)" >/dev/null
  _lock_release_guard "$resource"
  _lock_audit "reader_released" "$resource" "$session_id" '{}'
  return 0
}

# acquire_writer_lock <resource> <session_id> [feat_id] [reason]
# Waits for all readers (except self) + other writers to release.
# Self-readers are tolerated: this acts as an upgrade.
acquire_writer_lock() {
  local resource="$1" session_id="$2" feat_id="${3:-}" reason="${4:-unspecified}"
  _lock_validate_resource "$resource" || return 3
  _lock_require_jq || return 1
  _lock_ensure_dirs
  _lock_init_file_if_missing "$resource"

  local file="$(_lock_file_path "$resource")"
  local started=$(_lock_epoch_now)
  local enqueued=0

  while true; do
    cleanup_stale_locks >/dev/null 2>&1 || true
    _lock_acquire_guard "$resource" || { sleep 1; continue; }

    # Enqueue ourselves (1 lan) de writer-priority duoc kich hoat
    if [[ $enqueued -eq 0 ]]; then
      local already_queued
      already_queued=$(jq -r --arg sid "$session_id" '
        (.writer_pending | map(.session_id) | index($sid)) != null
      ' "$file")
      if [[ "$already_queued" != "true" ]]; then
        _lock_atomic_update "$file" '
          .writer_pending += [$entry] | .last_updated = $now
        ' \
          --argjson entry "$(jq -n \
            --arg sid "$session_id" --arg fid "$feat_id" --arg pid "$$" \
            --arg host "$(_lock_host)" --arg now "$(_lock_iso_now)" --arg reason "$reason" \
            '{session_id:$sid, feat_id:$fid, pid:($pid|tonumber), host:$host,
              queued_at:$now, last_heartbeat:$now, reason:$reason}')" \
          --arg now "$(_lock_iso_now)" >/dev/null || true
        _lock_audit "writer_queued" "$resource" "$session_id" \
          "$(jq -nc --arg r "$reason" '{reason:$r}')"
      fi
      enqueued=1
    fi

    # Decide if we can claim writer:
    # - writer null or already us
    # - readers all empty or only us (self-upgrade)
    # - we are the front of writer_pending queue
    local decision
    decision=$(jq -r --arg sid "$session_id" '
      if .writer != null and .writer.session_id != $sid then "blocked_writer"
      elif (.readers | map(select(.session_id != $sid)) | length) > 0 then "blocked_readers"
      elif (.writer_pending | length) > 0 and (.writer_pending[0].session_id != $sid) then "blocked_queue"
      else "go"
      end
    ' "$file")

    if [[ "$decision" == "go" ]]; then
      _lock_atomic_update "$file" '
        .writer = $entry |
        .writer_pending = (.writer_pending | map(select(.session_id != $sid))) |
        .last_updated = $now
      ' \
        --argjson entry "$(jq -n \
          --arg sid "$session_id" --arg fid "$feat_id" --arg pid "$$" \
          --arg host "$(_lock_host)" --arg now "$(_lock_iso_now)" --arg reason "$reason" \
          '{session_id:$sid, feat_id:$fid, pid:($pid|tonumber), host:$host,
            acquired_at:$now, last_heartbeat:$now, reason:$reason}')" \
        --arg sid "$session_id" --arg now "$(_lock_iso_now)" >/dev/null || {
        _lock_release_guard "$resource"; return 1;
      }
      _lock_release_guard "$resource"
      _lock_audit "writer_acquired" "$resource" "$session_id" \
        "$(jq -nc --arg r "$reason" --arg f "$feat_id" '{reason:$r, feat_id:$f}')"
      return 0
    fi

    _lock_release_guard "$resource"

    local elapsed=$(( $(_lock_epoch_now) - started ))
    if (( elapsed >= LOCK_WAIT_TIMEOUT_SEC )); then
      # Remove ourselves from queue when giving up
      _lock_acquire_guard "$resource" && \
        _lock_atomic_update "$file" '
          .writer_pending = (.writer_pending | map(select(.session_id != $sid))) |
          .last_updated = $now
        ' --arg sid "$session_id" --arg now "$(_lock_iso_now)" >/dev/null && \
        _lock_release_guard "$resource"
      _lock_audit "writer_timeout" "$resource" "$session_id" \
        "$(jq -nc --arg e "$elapsed" --arg b "$decision" '{elapsed_sec:($e|tonumber), blocked_by:$b}')"
      echo "TIMEOUT: cho writer lock '$resource' qua $LOCK_WAIT_TIMEOUT_SEC giay (blocked by: $decision)" >&2
      display_lock_status "$resource" >&2
      return 2
    fi

    if (( elapsed > 0 && elapsed % 30 == 0 )); then
      echo "[$resource] waiting writer lock... ${elapsed}s elapsed (blocked: $decision)" >&2
      display_lock_status "$resource" >&2
    fi
    sleep "$LOCK_POLL_INTERVAL_SEC"
  done
}

# release_writer_lock <resource> <session_id>
release_writer_lock() {
  local resource="$1" session_id="$2"
  _lock_validate_resource "$resource" || return 3
  _lock_require_jq || return 1
  local file="$(_lock_file_path "$resource")"
  [[ -f "$file" ]] || return 0

  _lock_acquire_guard "$resource" || return 1
  _lock_atomic_update "$file" '
    (if .writer != null and .writer.session_id == $sid then .writer = null else . end) |
    .last_updated = $now
  ' --arg sid "$session_id" --arg now "$(_lock_iso_now)" >/dev/null
  _lock_release_guard "$resource"
  _lock_audit "writer_released" "$resource" "$session_id" '{}'
  return 0
}

# upgrade_to_writer <resource> <session_id> [reason]
# Convenience: caller already has reader lock; promote to writer.
upgrade_to_writer() {
  local resource="$1" session_id="$2" reason="${3:-upgrade}"
  acquire_writer_lock "$resource" "$session_id" "" "$reason"
}

# downgrade_to_reader <resource> <session_id>
# Releases writer then re-acquires reader (atomic when guard held).
downgrade_to_reader() {
  local resource="$1" session_id="$2"
  _lock_validate_resource "$resource" || return 3
  _lock_require_jq || return 1
  local file="$(_lock_file_path "$resource")"
  [[ -f "$file" ]] || return 1

  _lock_acquire_guard "$resource" || return 1
  _lock_atomic_update "$file" '
    (if .writer != null and .writer.session_id == $sid
        then .writer = null |
             (if (.readers | map(.session_id) | index($sid)) == null then
                .readers += [{
                  session_id: $sid,
                  feat_id: (.writer.feat_id // ""),
                  pid: ($pid|tonumber),
                  host: $host,
                  acquired_at: $now,
                  last_heartbeat: $now,
                  intent: "test"
                }]
              else . end)
        else . end) |
    .last_updated = $now
  ' --arg sid "$session_id" --arg pid "$$" --arg host "$(_lock_host)" --arg now "$(_lock_iso_now)" >/dev/null
  _lock_release_guard "$resource"
  _lock_audit "writer_downgraded_to_reader" "$resource" "$session_id" '{}'
  return 0
}

# heartbeat_session_locks <session_id>
# Update last_heartbeat on all readers/writer/writer_pending entries belonging
# to session_id, across all resources.
heartbeat_session_locks() {
  local session_id="$1"
  _lock_require_jq || return 1
  local r now="$(_lock_iso_now)"
  for r in $LOCK_VALID_RESOURCES; do
    local file="$(_lock_file_path "$r")"
    [[ -f "$file" ]] || continue
    _lock_acquire_guard "$r" 2>/dev/null || continue
    _lock_atomic_update "$file" '
      .readers = (.readers | map(if .session_id == $sid then .last_heartbeat = $now else . end)) |
      (if .writer != null and .writer.session_id == $sid
          then .writer.last_heartbeat = $now else . end) |
      .writer_pending = (.writer_pending | map(if .session_id == $sid then .last_heartbeat = $now else . end)) |
      .last_updated = $now
    ' --arg sid "$session_id" --arg now "$now" >/dev/null
    _lock_release_guard "$r"
  done
  return 0
}

# release_all_session_locks <session_id>
# Used at session shutdown to release everything in 1 call.
release_all_session_locks() {
  local session_id="$1"
  _lock_require_jq || return 1
  local r
  for r in $LOCK_VALID_RESOURCES; do
    local file="$(_lock_file_path "$r")"
    [[ -f "$file" ]] || continue
    _lock_acquire_guard "$r" 2>/dev/null || continue
    _lock_atomic_update "$file" '
      .readers = (.readers | map(select(.session_id != $sid))) |
      (if .writer != null and .writer.session_id == $sid then .writer = null else . end) |
      .writer_pending = (.writer_pending | map(select(.session_id != $sid))) |
      .last_updated = $now
    ' --arg sid "$session_id" --arg now "$(_lock_iso_now)" >/dev/null
    _lock_release_guard "$r"
  done
  _lock_audit "session_released_all" "all" "$session_id" '{}'
  return 0
}

# display_lock_status <resource>
display_lock_status() {
  local resource="$1"
  _lock_validate_resource "$resource" || return 3
  local file="$(_lock_file_path "$resource")"
  if [[ ! -f "$file" ]]; then
    echo "[$resource] lock file chua ton tai (free)"
    return 0
  fi
  jq -r --arg r "$resource" '
    "[" + $r + "] readers=" + ((.readers | length) | tostring) +
    " writer=" + (if .writer != null then .writer.session_id else "none" end) +
    " queued=" + ((.writer_pending | length) | tostring) +
    " | readers: " + ((.readers | map(.session_id) | join(", ")) // "") +
    " | queue: " + ((.writer_pending | map(.session_id + "(" + (.reason // "?") + ")") | join(", ")) // "")
  ' "$file"
}

# -----------------------------------------------------------------------------
# CLI entry (allows: bash global-rw-lock.sh <fn> <args...>)
# -----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-help}"; shift || true
  case "$cmd" in
    acquire_reader_lock|release_reader_lock|acquire_writer_lock|release_writer_lock|\
    upgrade_to_writer|downgrade_to_reader|heartbeat_session_locks|\
    release_all_session_locks|cleanup_stale_locks|display_lock_status)
      "$cmd" "$@"
      ;;
    help|*)
      cat <<EOF
global-rw-lock.sh — Cross-session R/W lock cho BE/FE/DB/Playwright

USAGE:
  bash global-rw-lock.sh <command> [args...]

COMMANDS:
  acquire_reader_lock  <resource> <session_id> [feat_id]
  release_reader_lock  <resource> <session_id>
  acquire_writer_lock  <resource> <session_id> [feat_id] [reason]
  release_writer_lock  <resource> <session_id>
  upgrade_to_writer    <resource> <session_id> [reason]
  downgrade_to_reader  <resource> <session_id>
  heartbeat_session_locks <session_id>
  release_all_session_locks <session_id>
  cleanup_stale_locks
  display_lock_status  <resource>

RESOURCES: backend | frontend | database | playwright

ENV:
  MCV3_GLOBAL_LOCKS_DIR      (default: .mc-data/_global_locks)
  MCV3_LOCK_HEARTBEAT_SEC    (default: 30)
  MCV3_LOCK_STALE_SEC        (default: 120 = 2 phut)
  MCV3_LOCK_WAIT_TIMEOUT_SEC (default: 600 = 10 phut)
  MCV3_LOCK_POLL_INTERVAL_SEC (default: 5)

EXIT CODES:
  0 = OK
  1 = generic error (jq missing, IO fail)
  2 = wait timeout, caller PHAI ESCALATE (KHONG fallback)
  3 = invalid args (resource unknown)
EOF
      [[ "$cmd" == "help" ]] && exit 0 || exit 3
      ;;
  esac
fi
