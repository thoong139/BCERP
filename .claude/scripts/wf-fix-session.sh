#!/usr/bin/env bash
# wf-fix-session.sh — CLI quan ly sessions cua /wf-fix-bugs (v7.0)
#
# Subcommands:
#   list                   List all sessions tu _index/sessions.jsonl (newest first)
#   status <session_id>    Hien thi fix-status.json + lock state cua 1 session
#   release <session_id>   Force release lock cua 1 session (CDG — yeu cau confirm)
#   help                   Hien thi usage
#
# Examples:
#   bash .claude/scripts/wf-fix-session.sh list
#   bash .claude/scripts/wf-fix-session.sh status 2026-04-28-module-payment-01
#   bash .claude/scripts/wf-fix-session.sh release 2026-04-28-all-01

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

BASE_DIR="${MCV3_FIX_BUGS_BASE_DIR:-.mc-data/work/wf-fix-bugs}"
INDEX="$BASE_DIR/_index/sessions.jsonl"

# ============================================================
# Helpers
# ============================================================

usage() {
  cat <<EOF
wf-fix-session.sh — CLI quan ly sessions cua /wf-fix-bugs (v7.0)

USAGE:
  wf-fix-session.sh list
  wf-fix-session.sh status <session_id>
  wf-fix-session.sh release <session_id>
  wf-fix-session.sh help

ENV:
  MCV3_FIX_BUGS_BASE_DIR   Override base dir (default: .mc-data/work/wf-fix-bugs)
EOF
}

# Truncate string voi ellipsis (BHV-002: simplicity).
truncate_id() {
  local id="$1"
  local max_len="${2:-35}"
  if [ "${#id}" -gt "$max_len" ]; then
    echo "${id:0:$((max_len - 3))}..."
  else
    echo "$id"
  fi
}

# Tim duong dan session_dir tu session_id (resolve theo BASE_DIR/sessions/).
resolve_session_dir() {
  local sid="$1"
  echo "$BASE_DIR/sessions/$sid"
}

# Read fix-status.json + return key fields qua jq.
read_status_summary() {
  local sd="$1"
  local sf="$sd/fix-status.json"
  [ -s "$sf" ] || { echo "  (chua co fix-status.json)"; return; }

  jq -r '
    "  Status        : " + (.status // "n/a") +
    "\n  Active skill  : " + (.active_skill // "n/a") +
    "\n  Next action   : " + (.next_action // "n/a") +
    "\n  Phases done   : " + ([.phases | to_entries[] | select(.value.status == "completed") | .key] | join(", ")) +
    "\n  Created at    : " + (.timestamps.created_at // .created_at // "n/a") +
    "\n  Updated at    : " + (.timestamps.last_updated // .updated_at // "n/a")
  ' "$sf" 2>/dev/null || echo "  (fix-status.json invalid JSON)"
}

# Read lock state.
read_lock_state() {
  local sd="$1"
  local lf="$sd/.lock"

  if [ ! -f "$lf" ]; then
    echo "  Lock          : (not held)"
    return
  fi

  local mtime now age_min
  mtime=$(file_mtime "$lf")
  now=$(date +%s)
  age_min=$(( (now - mtime) / 60 ))

  local stale_at="${WF_FIX_LOCK_STALE_MINUTES:-60}"
  local stale_marker=""
  if [ "$age_min" -ge "$stale_at" ]; then
    stale_marker=" (STALE — co the takeover)"
  fi

  echo "  Lock age      : ${age_min}min${stale_marker}"
  jq -r '
    "  Lock holder   : pid=" + (.pid|tostring) + " host=" + .host + " user=" + .user +
    "\n  Lock since    : " + .started_at +
    "\n  Last heartbeat: " + .heartbeat
  ' "$lf" 2>/dev/null || echo "  (lock file corrupted)"
}

# ============================================================
# Subcommands
# ============================================================

cmd_list() {
  if [ ! -s "$INDEX" ]; then
    echo "Khong co session nao trong $INDEX."
    echo "Chay /wf-fix-bugs [mo-ta] de bat dau session moi."
    return 0
  fi

  echo "Sessions (newest first) — $INDEX"
  echo "─────────────────────────────────────────────────────────────"
  printf "%-35s  %-8s  %-15s  %-12s  %s\n" "SESSION_ID" "SCOPE" "SLUG" "CREATED" "LOCK"

  # Read JSONL lines (reverse → newest first).
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local sid scope slug created
    sid=$(echo "$line" | jq -r '.session_id // "?"')
    scope=$(echo "$line" | jq -r '.scope // "?"')
    slug=$(echo "$line" | jq -r '.slug // ""')
    created=$(echo "$line" | jq -r '.created_at // "?"' | cut -c1-10)

    local sd lock_state
    sd=$(resolve_session_dir "$sid")
    if [ -f "$sd/.lock" ]; then
      local mtime age_min
      mtime=$(file_mtime "$sd/.lock")
      age_min=$(( ( $(date +%s) - mtime ) / 60 ))
      if [ "$age_min" -ge "${WF_FIX_LOCK_STALE_MINUTES:-60}" ]; then
        lock_state="STALE(${age_min}m)"
      else
        lock_state="HELD(${age_min}m)"
      fi
    else
      lock_state="-"
    fi

    printf "%-35s  %-8s  %-15s  %-12s  %s\n" "$(truncate_id "$sid" 35)" "$scope" "${slug:--}" "$created" "$lock_state"
  done < <(_tac "$INDEX")
}

cmd_status() {
  local sid="${1:-}"
  if [ -z "$sid" ]; then
    echo "ERROR: thieu <session_id>" >&2
    usage
    exit 1
  fi

  local sd
  sd=$(resolve_session_dir "$sid")
  if [ ! -d "$sd" ]; then
    echo "ERROR: session khong ton tai: $sid" >&2
    echo "Dung 'wf-fix-session.sh list' de xem cac session co san." >&2
    exit 1
  fi

  echo "Session: $sid"
  echo "Path   : $sd"
  echo "─────────────────────────────────────────────────────────────"
  read_status_summary "$sd"
  echo ""
  read_lock_state "$sd"
}

cmd_release() {
  local sid="${1:-}"
  if [ -z "$sid" ]; then
    echo "ERROR: thieu <session_id>" >&2
    usage
    exit 1
  fi

  local sd
  sd=$(resolve_session_dir "$sid")
  if [ ! -d "$sd" ]; then
    echo "ERROR: session khong ton tai: $sid" >&2
    exit 1
  fi

  local lf="$sd/.lock"
  if [ ! -f "$lf" ]; then
    echo "Lock khong ton tai cho session $sid (idempotent — khong can release)."
    exit 0
  fi

  # Hien thi lock holder + age TRUOC khi destructive action (CDG).
  echo "================================================================"
  echo "[CDG] FORCE RELEASE LOCK — Hanh dong KHONG UNDO"
  echo "================================================================"
  echo "Session: $sid"
  read_lock_state "$sd"
  echo ""
  echo "Hau qua:"
  echo "  - Process holding lock (neu con sống) se mat exclusive write right"
  echo "  - Co the gay race condition neu process kia van dang ghi"
  echo ""
  echo "Chi nen release khi chac chan rang:"
  echo "  1. Process kia da quit hoac crash (khong on background)"
  echo "  2. Lock age > ${WF_FIX_LOCK_STALE_MINUTES:-60}min (stale) — chac chan ko ai dung nua"
  echo "================================================================"
  read -r -p "Xac nhan release lock? Type EXACTLY 'release $sid' de tien hanh: " confirm

  if [ "$confirm" != "release $sid" ]; then
    echo "Cancelled — confirmation string khong khop."
    exit 1
  fi

  release_lock "$sd"
  stop_heartbeat_daemon "$sd" 2>/dev/null || true
  echo "Lock released: $sid"

  # Best-effort: append history event.
  append_history_index "$sid" "lock_released_manually" "by=$(user_name)@$(host_name)" 2>/dev/null || true
}

# ============================================================
# Main dispatcher
# ============================================================

CMD="${1:-help}"
shift || true

case "$CMD" in
  list)    cmd_list ;;
  status)  cmd_status "$@" ;;
  release) cmd_release "$@" ;;
  help|-h|--help) usage ;;
  *)
    echo "ERROR: unknown subcommand: $CMD" >&2
    usage
    exit 1
    ;;
esac
