#!/usr/bin/env bash
# wf-fix-common.sh — Helpers chung cho /wf-fix-bugs pipeline (v7.0)
#
# Source pattern (từ skill / sub-script):
#   source "$(dirname "$0")/wf-fix-common.sh"           # khi script ở .claude/scripts/
#   source ".claude/scripts/wf-fix-common.sh"           # khi gọi từ repo root
#
# Cross-platform: GNU/Linux, macOS (BSD), Git Bash (MINGW), WSL.
# Dependencies: bash >= 4, jq, coreutils (date/stat).
#
# CONVENTION: Đây là library file (sourced), không set -e/-u ở top-level
# để tránh contaminate shell options của caller. Mỗi function tự xử lý
# error path qua return code. Caller có thể tự `set -euo pipefail`.

# ============================================================
# CONSTANTS
# ============================================================
readonly WF_FIX_LOCK_STALE_MINUTES="${MCV3_LOCK_STALE_MINUTES:-60}"
readonly WF_FIX_HEARTBEAT_INTERVAL_SEC="${MCV3_HEARTBEAT_INTERVAL_SEC:-30}"
readonly WF_FIX_BASE_DIR="${MCV3_FIX_BUGS_BASE_DIR:-.mc-data/work/wf-fix-bugs}"
readonly E_LEGACY_BLOCK=78  # v7.1 V71-D02 — legacy paths abort / migration failed

# ============================================================
# CROSS-PLATFORM PRIMITIVES
# ============================================================

# ISO 8601 UTC timestamp (giây). GNU date hỗ trợ -Iseconds; BSD/Git Bash thì không.
iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# File modification time as Unix epoch. GNU: stat -c %Y; BSD/macOS: stat -f %m.
file_mtime() {
  local f="$1"
  stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0
}

# Age in seconds since file last modified. Returns 0 on error (treats as fresh).
# Lý do: nếu cả `stat -c` (GNU) lẫn `stat -f` (BSD/macOS < 10.13) đều fail,
# `file_mtime` echo 0; nếu compute `now - 0` ta sẽ ra số khổng lồ → caller
# nhầm là stale + takeover → racy. An toàn hơn là treat as fresh (echo 0).
file_mtime_age_seconds() {
  local f="$1"
  local mtime
  mtime=$(file_mtime "$f")
  if [ "$mtime" -eq 0 ]; then
    echo 0
    return
  fi
  echo $(( $(date +%s) - mtime ))
}

# Best-effort hostname (Git Bash đôi khi không có lệnh hostname).
host_name() {
  hostname 2>/dev/null || echo "${HOSTNAME:-${COMPUTERNAME:-unknown-host}}"
}

# Best-effort username.
user_name() {
  whoami 2>/dev/null || echo "${USER:-${USERNAME:-unknown-user}}"
}

# Cross-platform reverse cat (tac equivalent).
# tac la GNU-only, khong co tren macOS/BSD/Git Bash mac dinh.
_tac() {
  if command -v tac >/dev/null 2>&1; then
    tac "$@"
  elif command -v gtac >/dev/null 2>&1; then
    gtac "$@"
  else
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$@"
  fi
}

# ============================================================
# JSON HELPERS
# ============================================================

# JSON-escape một chuỗi tùy ý (output là JSON string literal có quote).
# Dùng jq để tránh phụ thuộc python.
json_escape() {
  jq -nc --arg v "$1" '$v'
}

# Atomic write text (no JSON validation) — F05.004 (Sprint 8).
# $1: target path
# $2: nội dung (chuỗi, có thể multi-line)
# Dùng cho .md, .txt khi không cần jq parse.
atomic_write_text() {
  local target="$1"
  local content="$2"
  local tmp
  tmp=$(mktemp "${target}.XXXXXX") || {
    echo "ERROR: mktemp fail for $target" >&2
    return 1
  }

  printf '%s' "$content" > "$tmp"
  mv "$tmp" "$target"
}

# Atomic write JSON: write vào tmp, validate JSON, rồi mv.
# $1: target path
# $2: nội dung JSON (chuỗi)
#
# F05.006 (Sprint 8): Dùng `mktemp` thay `${target}.tmp.$$.$RANDOM` để chống
# collision khi multiple writers đồng thời (RANDOM 15-bit, max 32767 → easy
# birthday paradox). mktemp dùng kernel-grade randomness + atomic create.
atomic_write_json() {
  local target="$1"
  local content="$2"
  local tmp
  tmp=$(mktemp "${target}.XXXXXX") || {
    echo "ERROR: mktemp fail for $target" >&2
    return 1
  }

  printf '%s\n' "$content" > "$tmp"

  if ! jq '.' "$tmp" > /dev/null 2>&1; then
    rm -f "$tmp"
    echo "ERROR: invalid JSON, write rejected: $target" >&2
    return 1
  fi

  mv "$tmp" "$target"
}

# CRLF-safe integer capture from jq (SB-04 from E2E v7.4.0).
# Trên Git Bash MINGW, command substitution có thể giữ trailing \r khi
# pipeline qua jq + heredoc. Bash integer comparison ([ $X -gt 0 ]) sẽ
# fail với "integer expression expected" nếu $X = "0\r". Helper này strip
# mọi whitespace/CR/LF để đảm bảo output thuần số.
#
# Usage: COUNT=$(jq_int 'length' <<< "$JSON_ARRAY")
#        if [ "$COUNT" -gt 0 ]; then ... fi
jq_int() {
  jq "$@" | tr -d '\r\n\t '
}

# ============================================================
# ERR TRAP HELPER (F05.009 — Sprint 8)
# ============================================================

# `_err_trap` — Default ERR trap: log line/command/rc → stderr.
# Dùng cùng `set -E` để inherit trap vào subshells/functions.
#
# Usage trong script:
#   source wf-fix-common.sh
#   enable_err_trap
#
# Behavior:
#   - Khi command fail (rc != 0) với `set -e`, in `ERROR (rc=N) at file:line: cmd`
#   - Trap return rc → script exit với rc nguyên thủy (không nuốt error)
#   - Idempotent qua env guard `_WF_ERR_TRAP_ACTIVE`
_err_trap() {
  local rc=$?
  local cmd="${BASH_COMMAND:-<unknown>}"
  # BASH_LINENO[0] là line caller; ${BASH_SOURCE[1]} là file caller.
  local src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-<unknown>}}"
  local line="${BASH_LINENO[0]:-${LINENO}}"
  echo "[wf-fix ERR] rc=${rc} ${src}:${line}: ${cmd}" >&2
  return "$rc"
}

# `enable_err_trap` — Activate ERR trap + set -E (inherit to subshells).
# Idempotent: gọi nhiều lần không double-trap.
enable_err_trap() {
  if [[ -n "${_WF_ERR_TRAP_ACTIVE:-}" ]]; then
    return 0
  fi
  export _WF_ERR_TRAP_ACTIVE=1
  set -E
  trap _err_trap ERR
}

# `disable_err_trap` — Tắt ERR trap (cho test/debug). Reset env guard.
disable_err_trap() {
  trap - ERR
  set +E
  unset _WF_ERR_TRAP_ACTIVE
}

# ============================================================
# RUNTIME GUARDS
# ============================================================

# Defensive runtime cap (SB-01 from E2E v7.4.0): re-exec self under `timeout`
# để không probe nào hang trên codebase lớn. Idempotent qua env guard
# `_WF_PROBE_TIMEOUT_WRAPPED` — đứa con sau exec sẽ no-op.
#
# Usage (đặt SAU `source wf-fix-common.sh` trong probe scripts):
#   with_runtime_cap "$@"
#
# Env vars:
#   WF_FIX_PROBE_MAX_RUNTIME_SEC — override cap (default 180s)
#
# Behavior:
#   - `timeout` không có (môi trường minimal) → no-op, log WARN qua stderr
#   - `_WF_PROBE_TIMEOUT_WRAPPED=1` → đã wrapped, no-op
#   - Wrap thành công → process replace, exit code 124 nếu timeout hit
with_runtime_cap() {
  if [[ -n "${_WF_PROBE_TIMEOUT_WRAPPED:-}" ]]; then
    return 0
  fi
  if ! command -v timeout >/dev/null 2>&1; then
    echo "WARN: 'timeout' binary not available — probe runs without runtime cap" >&2
    return 0
  fi
  export _WF_PROBE_TIMEOUT_WRAPPED=1
  # Default 600s (10 min) — phù hợp với codebase 100k+ files (fix #5).
  # Skill SKILL.md mandate Bash tool timeout=300s, nhưng cap nội bộ phải ≥ Bash cap
  # để tránh `timeout` bash giết script trước khi Python subprocess timeout.
  local cap="${WF_FIX_PROBE_MAX_RUNTIME_SEC:-600}"
  exec timeout --preserve-status --signal=TERM "$cap" "$0" "$@"
}

# ============================================================
# SLUG / SESSION ID HELPERS
# ============================================================

# Chuẩn hóa chuỗi thành lowercase-kebab-case (CORE-016/017).
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\+/-/g' \
    | sed 's/^-//; s/-$//'
}

# Sinh session_id theo format D2: YYYY-MM-DD-{scope}-{slug}-{NN}
# $1: scope (all | system | module)
# $2: slug (rỗng nếu scope=all)
# Counter NN tự tăng tuần tự, zero-padded 2 digits; >99 thì dùng 3 digits + log warning.
generate_session_id() {
  local scope="$1"
  local slug="${2:-}"
  local date_str
  date_str=$(date -u +%Y-%m-%d)

  local base
  if [ -z "$slug" ]; then
    base="${date_str}-${scope}"
  else
    base="${date_str}-${scope}-$(slugify "$slug")"
  fi

  # Bao dam parent dir ton tai truoc khi mkdir atomic claim. Single-arg `mkdir`
  # khong tao nested dirs → fresh project chua co sessions/ se fail tat ca 999 retries.
  # `mkdir -p` idempotent, khong race vi tao parent (khong phai claim slot).
  mkdir -p "$WF_FIX_BASE_DIR/sessions" 2>/dev/null || true

  # Atomic claim: mkdir session_dir de tranh TOCTOU race giua check va create.
  # Neu mkdir fail (race voi process khac), tang counter va retry.
  local counter=1
  while true; do
    local session_id session_dir
    if [ "$counter" -le 99 ]; then
      session_id="${base}-$(printf '%02d' "$counter")"
    else
      # Overflow → 3-digit, warn ve su bat thuong
      if [ "$counter" -eq 100 ]; then
        echo "WARNING: session counter overflow > 99 cho base=$base" >&2
      fi
      session_id="${base}-$(printf '%03d' "$counter")"
    fi

    session_dir="$WF_FIX_BASE_DIR/sessions/$session_id"

    # Atomic claim: neu mkdir thanh cong → slot nay la cua chung ta
    if mkdir "$session_dir" 2>/dev/null; then
      printf '%s' "$session_id"
      return 0
    fi

    counter=$((counter + 1))
    if [ "$counter" -gt 999 ]; then
      echo "ERROR: khong the claim session slot sau 999 retries cho base=$base" >&2
      return 1
    fi
  done
}

# Cleanup orphan session directory (claimed by generate_session_id but never
# acquired lock). Caller nên gọi qua trap nếu abort xảy ra giữa
# generate_session_id và acquire_lock — tránh leak directory rỗng.
#
# Chỉ xóa nếu:
#   1. Directory tồn tại
#   2. KHÔNG có .lock file (chưa acquire_lock)
#   3. Directory rỗng (chỉ là claim slot, chưa ghi data)
#
# Pattern khuyên dùng:
#   SESSION_ID=$(generate_session_id "$SCOPE" "$NAME") || exit 1
#   SESSION_DIR="$WF_FIX_BASE_DIR/sessions/$SESSION_ID"
#   trap 'cleanup_orphan_session "$SESSION_DIR"' EXIT
#   acquire_lock "$SESSION_DIR" || exit 1
#   trap - EXIT  # acquire_lock thành công, không cần cleanup
cleanup_orphan_session() {
  local session_dir="$1"
  [ -d "$session_dir" ] || return 0
  [ -f "$session_dir/.lock" ] && return 0
  # Empty check (Bash portable, không phụ thuộc ls -A)
  if [ -z "$(find "$session_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    rmdir "$session_dir" 2>/dev/null && \
      echo "INFO: cleanup orphan session dir: $(basename "$session_dir")" >&2
  fi
}

# General cleanup handler — called by traps set in phase procedures.
# Removes session lock file if it exists, kills heartbeat daemon if PID known.
cleanup() {
  if [ -n "${LOCK_FILE:-}" ] && [ -f "$LOCK_FILE" ]; then
    rm -f "$LOCK_FILE" 2>/dev/null || true
  fi
  if [ -n "${HEARTBEAT_PID:-}" ] && kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}

# ============================================================
# LOCK MANAGEMENT
# ============================================================
#
# Cơ chế: dùng mkdir của ".lock.acquiring" làm POSIX atomic guard
# trước khi đọc/ghi file ".lock" (file chính chứa metadata JSON).
# 2 processes cùng acquire → mkdir chỉ thành công 1 lần → 1 thắng.
#
# Lock file schema (xem 02-target-architecture.md §2.3):
#   { "$schema": "wf-fix-lock-v1", "session_id", "pid", "host", "user",
#     "started_at", "heartbeat", "active_phase", "skill" }
#
# Stale detection (2 cơ chế):
#   1. PID liveness (cùng host): đọc .lock.pid + .host → kill -0 → nếu PID chết → takeover ngay.
#   2. Mtime fallback (khác host hoặc thiếu PID): filesystem mtime > MCV3_LOCK_STALE_MINUTES (default 60min).
# Heartbeat daemon update mtime qua write thường xuyên — file mtime falls behind nếu daemon chết.
# → cảnh báo + takeover.

acquire_lock() {
  local session_dir="$1"
  local lock_file="$session_dir/.lock"
  local lock_guard="$session_dir/.lock.acquiring"

  [ -d "$session_dir" ] || mkdir -p "$session_dir"

  # Neu guard ton tai > 2 phut (SIGKILL giua mkdir va rmdir), takeover de tranh deadlock vinh vien.
  if [ -d "$lock_guard" ]; then
    local guard_age
    guard_age=$(file_mtime_age_seconds "$lock_guard" 2>/dev/null || echo 0)
    if [ "$guard_age" -gt 120 ]; then
      echo "WARNING: stale .lock.acquiring guard (age ${guard_age}s > 120s), removing" >&2
      rm -rf "$lock_guard"
    fi
  fi

  # POSIX atomic guard. Nếu mkdir fail → process khác đang ghi → wait + retry 1 lần.
  if ! mkdir "$lock_guard" 2>/dev/null; then
    sleep 1
    if ! mkdir "$lock_guard" 2>/dev/null; then
      echo "ERROR: lock contention ($lock_guard exists), session=$(basename "$session_dir")" >&2
      return 1
    fi
  fi

  # Từ đây có exclusive write right. Cleanup guard ở mọi exit path.
  local rc=0
  if [ -f "$lock_file" ]; then
    local mtime age_seconds age_minutes lock_pid lock_host current_host
    mtime=$(file_mtime "$lock_file")
    age_seconds=$(( $(date +%s) - mtime ))
    age_minutes=$(( age_seconds / 60 ))
    lock_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    lock_host=$(jq -r '.host // empty' "$lock_file" 2>/dev/null)
    current_host=$(host_name)

    # Path A — same host + PID liveness (most reliable, < 1ms).
    # kill -0 trả về 0 nếu PID còn sống, non-zero nếu chết.
    # Tránh false-positive: PID có thể bị recycle, nhưng same-host + recent mtime đảm bảo
    # không phải lock từ session cũ trùng PID (mtime sẽ > stale threshold).
    if [ -n "$lock_pid" ] && [ "$lock_pid" -gt 0 ] 2>/dev/null && \
       [ -n "$lock_host" ] && [ "$lock_host" = "$current_host" ]; then
      if kill -0 "$lock_pid" 2>/dev/null; then
        echo "ERROR: session locked by live PID $lock_pid on $lock_host (age ${age_minutes}min)" >&2
        cat "$lock_file" >&2
        rc=1
      else
        echo "WARNING: lock holder PID $lock_pid dead on $lock_host, taking over (age ${age_minutes}min)" >&2
      fi
    # Path B — different host hoặc thiếu PID/host → fallback mtime-based stale check.
    else
      if [ "$age_minutes" -lt "$WF_FIX_LOCK_STALE_MINUTES" ]; then
        echo "ERROR: session locked from ${lock_host:-unknown} (age ${age_minutes}min, stale at ${WF_FIX_LOCK_STALE_MINUTES}min)" >&2
        cat "$lock_file" >&2
        rc=1
      else
        echo "WARNING: stale cross-host lock (age ${age_minutes}min), taking over" >&2
      fi
    fi
  fi

  if [ "$rc" -eq 0 ]; then
    # F05.003 (Sprint 8): Build JSON via `jq -n --arg` thay heredoc raw.
    # Lý do: trên Windows domain, $(host_name) có thể trả "DOMAIN\user" chứa
    # backslash → JSON-unsafe → session không start được. jq -n auto-escape
    # mọi ký tự đặc biệt (\, ", control chars) → cross-platform safe.
    local lock_json now
    now=$(iso_now)
    lock_json=$(jq -n \
      --arg session "$(basename "$session_dir")" \
      --argjson pid "$$" \
      --arg host "$(host_name)" \
      --arg user "$(user_name)" \
      --arg started "$now" \
      --arg phase "${ACTIVE_PHASE:-unknown}" \
      --arg skill "${ACTIVE_SKILL:-wf-fix-bugs}" \
      '{
        "$schema": "wf-fix-lock-v1",
        session_id: $session,
        pid: $pid,
        host: $host,
        user: $user,
        started_at: $started,
        heartbeat: $started,
        active_phase: $phase,
        skill: $skill
      }')
    atomic_write_json "$lock_file" "$lock_json" || rc=1
  fi

  rmdir "$lock_guard" 2>/dev/null || true

  if [ "$rc" -eq 0 ]; then
    echo "Lock acquired: $lock_file" >&2
  fi
  return "$rc"
}

# Cập nhật heartbeat timestamp (giữ lock alive).
heartbeat_lock() {
  local session_dir="$1"
  local lock_file="$session_dir/.lock"
  [ -f "$lock_file" ] || return 0

  local now updated
  now=$(iso_now)
  updated=$(jq --arg ts "$now" '.heartbeat = $ts' "$lock_file") || return 1
  atomic_write_json "$lock_file" "$updated"
}

# Giải phóng lock (xóa file). Idempotent.
release_lock() {
  local session_dir="$1"
  rm -f "$session_dir/.lock"
}

# Spawn background daemon update heartbeat mỗi WF_FIX_HEARTBEAT_INTERVAL_SEC.
# Daemon tự thoát khi .lock biến mất.
start_heartbeat_daemon() {
  local session_dir="$1"
  (
    while [ -f "$session_dir/.lock" ]; do
      heartbeat_lock "$session_dir" 2>/dev/null || true
      sleep "$WF_FIX_HEARTBEAT_INTERVAL_SEC"
    done
  ) &
  echo $! > "$session_dir/.heartbeat.pid"
}

# Dừng heartbeat daemon (idempotent).
stop_heartbeat_daemon() {
  local session_dir="$1"
  local pid_file="$session_dir/.heartbeat.pid"
  if [ -f "$pid_file" ]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null || echo "")
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pid_file"
  fi
}

# ============================================================
# SIGNALS LOCK (B1, v8.2.2)
# ============================================================
#
# File-level lock cho lanes/QD*/signals.json — chống ghi đè khi nhiều
# writer (lane_dispatch.py + signal-emit.md + merge_signals.py) cùng
# touch file. Dùng cùng convention với Python (lane_dispatch._signals_lock_*)
# để bash + Python share được lock directory.
#
# Convention: <signals_file>.lock/ (mkdir-based POSIX atomic).
# Timeout: 30s. Stale: 5 phút (bash crash giữa write).
#
# Ngắn gọn (không cần heartbeat) vì write ngắn (<1s). Khác với session
# lock — long-running (>1h), cần heartbeat daemon.
#
# Returns 0 on success, 1 on timeout/contention.
acquire_signals_lock() {
  local signals_file="$1"
  local timeout_sec="${2:-30}"
  local stale_sec="${3:-300}"
  local lock_dir="${signals_file}.lock"

  local waited=0
  while [ "$waited" -lt "$timeout_sec" ]; do
    # Stale takeover: lock_dir tồn tại > stale_sec → coi như writer crash.
    if [ -d "$lock_dir" ]; then
      local age
      age=$(file_mtime_age_seconds "$lock_dir" 2>/dev/null || echo 0)
      if [ "$age" -gt "$stale_sec" ]; then
        echo "WARNING: stale signals lock (age ${age}s > ${stale_sec}s), taking over: $lock_dir" >&2
        rm -rf "$lock_dir"
      fi
    fi

    if mkdir "$lock_dir" 2>/dev/null; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  echo "ERROR: signals lock timeout (${timeout_sec}s), file=$signals_file" >&2
  return 1
}

# Giải phóng signals lock (idempotent).
release_signals_lock() {
  local signals_file="$1"
  local lock_dir="${signals_file}.lock"
  rmdir "$lock_dir" 2>/dev/null || true
}

# ============================================================
# INDEX HELPERS (git-friendly append-only JSONL)
# ============================================================

# Append 1 line vào _index/sessions.jsonl khi tạo session mới.
# $1: session_id  $2: scope  $3: slug (optional)
append_session_index() {
  local session_id="$1"
  local scope="$2"
  local slug="${3:-}"
  local index_file="$WF_FIX_BASE_DIR/_index/sessions.jsonl"
  mkdir -p "$(dirname "$index_file")"

  local line
  line=$(jq -nc \
    --arg sid "$session_id" \
    --arg scope "$scope" \
    --arg slug "$slug" \
    --arg created "$(iso_now)" \
    --arg host "$(host_name)" \
    '{session_id:$sid, scope:$scope, slug:$slug, created_at:$created, host:$host, status:"in_progress"}')

  printf '%s\n' "$line" >> "$index_file"
}

# Append 1 line vào _index/history.jsonl khi đạt phase milestone.
# $1: session_id  $2: event  $3: details (string, optional)
append_history_index() {
  local session_id="$1"
  local event="$2"
  local details="${3:-}"
  local index_file="$WF_FIX_BASE_DIR/_index/history.jsonl"
  mkdir -p "$(dirname "$index_file")"

  local line
  line=$(jq -nc \
    --arg sid "$session_id" \
    --arg event "$event" \
    --arg ts "$(iso_now)" \
    --arg details "$details" \
    '{session_id:$sid, event:$event, timestamp:$ts, details:$details}')

  printf '%s\n' "$line" >> "$index_file"
}

# ============================================================
# LEGACY PATH DETECTION (v7.1+ — D1 roadmap)
# ============================================================
#
# Detect legacy v6.x layout (run-NNN-* dirs) còn tồn tại sau migration window.
# Return:
#   0 — không có legacy paths (clean)
#   1 — có legacy paths VÀ env override KHÔNG bật → caller phải BLOCK
#   0 + WARN log — có legacy paths NHƯNG env override bật → escape hatch
#
# Env vars:
#   MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1 — escape hatch (CI/CD testing)
#   MCV3_FIX_BUGS_BASE_DIR — override base dir (default: .mc-data/work/wf-fix-bugs)

assert_no_legacy_paths() {
  local base_dir="${MCV3_FIX_BUGS_BASE_DIR:-.mc-data/work/wf-fix-bugs}"
  [ -d "$base_dir" ] || return 0  # base dir chưa tồn tại → clean

  local legacy_count
  legacy_count=$(find "$base_dir" -maxdepth 4 -type d -name 'run-[0-9]*' 2>/dev/null | wc -l | tr -d ' ')

  [ "$legacy_count" -eq 0 ] && return 0  # clean

  if [ "${MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK:-0}" = "1" ]; then
    echo "WARNING: phat hien $legacy_count legacy run-NNN-* dirs nhung MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1 → cho phep continue (escape hatch CI/CD)" >&2
    return 0
  fi

  return 1  # caller phải BLOCK + render CDG
}

# Export legacy count cho CDG render
get_legacy_paths_count() {
  local base_dir="${MCV3_FIX_BUGS_BASE_DIR:-.mc-data/work/wf-fix-bugs}"
  [ -d "$base_dir" ] || { echo 0; return; }
  find "$base_dir" -maxdepth 4 -type d -name 'run-[0-9]*' 2>/dev/null | wc -l | tr -d ' '
}

# ============================================================
# SIGNAL DEDUPLICATION (IMP-012)
# ============================================================
#
# make_dedup_namespace_key() — IMP-023: Canonical cross-probe dedup key.
# Format: {file_path}|{line_start}|{issue_class}
# Probe-independent — same location+issue from different probes produces same key.
#
# Usage (bash): key=$(make_dedup_namespace_key "$file" "$line" "$issue_class")
make_dedup_namespace_key() {
  local file="${1:-unknown}" line="${2:-0}" issue_class="${3:-unknown}"
  echo "${file}|${line}|${issue_class}"
}

# dedup_signals() — Remove duplicate signals across probes (IMP-023 namespace).
# Two signals are duplicates if they share the same (file_path, line_start, issue_class).
# When duplicates found: keep highest severity, merge probe sources into evidence.
#
# $1: JSON array of signal-v2 objects (as a string)
# Output: deduplicated JSON array (stdout)
#
# Namespace key: file_path + line_start + (issue_class || title) — cross-probe canonical
# Precedence: critical > high > medium > low > info
# evidence.dedup_sources: list of all probe_ids that flagged the same location
#
# Example:
#   deduped=$(dedup_signals "$signals_json")
dedup_signals() {
  local signals_json="$1"
  if [ -z "$signals_json" ] || [ "$signals_json" = "[]" ] || [ "$signals_json" = "null" ]; then
    echo "[]"
    return 0
  fi

  # Use jq to perform deduplication:
  # 1. Group by canonical cross-probe namespace key (file|line|issue_class)
  # 2. For each group: keep highest severity, merge evidence sources
  jq -c '
    def severity_rank:
      if . == "critical" then 5
      elif . == "high" then 4
      elif . == "medium" then 3
      elif . == "low" then 2
      else 1 end;

    # IMP-023: canonical cross-probe namespace key (probe-independent)
    def dedup_namespace_key:
      (.location.file // .target.file // "unknown") + "|" +
      ((.location.line // .target.line // 0) | tostring) + "|" +
      (.issue_class // (.title | ascii_downcase | gsub("[^a-z0-9_]"; "_") | .[0:40]) // "unknown");

    # Group signals by namespace key
    group_by(dedup_namespace_key) |
    map(
      if length == 1 then .[0]
      else
        # Multiple signals with same key → merge (IMP-023)
        . as $group |
        # Pick signal with highest severity
        (sort_by(.severity | severity_rank) | reverse | .[0]) as $winner |
        # Collect all probe sources
        ($group | map(.probe_id) | unique) as $all_probes |
        # Compute namespace key for this group
        ($group[0] | dedup_namespace_key) as $ns_key |
        # Merge evidence: add dedup info with namespace key
        $winner |
        .evidence += [{
          "type": "dedup",
          "dedup_namespace_key": $ns_key,
          "description": ("IMP-023 dedup: " + ($all_probes | length | tostring) + " probes flagged same location: " + ($all_probes | join(", ")))
        }] |
        .tags += ["deduped"] |
        .dedup_sources = $all_probes
      end
    )
  ' <<< "$signals_json" 2>/dev/null || echo "$signals_json"
}

# ============================================================
# POST-GATE T1-T4 TIERED VALIDATION (W1.3 — speedup v10.0.x)
# ============================================================
#
# validate_post_gate_tiered — Gop 4 jq/grep subprocess thanh 1 helper.
# Bao toan semantics CORE-012 (4 tier checks, AND logic) — chi giam overhead.
#
# Goi tu Phase 6 Step 6.6 cua phase6-execute.md va cac POST-GATE tuong tu.
#
# Inputs:
#   $1 = fix_report path     (vd: $SESSION_DIR/phase6-execute/fix-report.md)
#   $2 = docs_sync_report path (vd: $SESSION_DIR/phase6-execute/docs-sync-report.json)
#
# Tier semantics (BAT BUOC giu nguyen):
#   T1 — File ton tai + non-empty (fix-report.md AND docs-sync-report.json)
#   T2 — Structure (fix-report.md co it nhat 1 H2 section "## ")
#   T3 — Content depth (docs-sync-report.json valid JSON co field files_synced >= 0)
#   T4 — Cross-reference (fix-report.md co keyword "fixed|resolved|repaired|dry")
#
# Output (stdout): "T1=ok|fail T2=ok|fail T3=ok|fail T4=ok|fail"
# Return code: 0 neu TAT CA tier PASS (AND), 1 neu bat ky tier FAIL.
#
# Vi sao gop?
#   - Tieu chuan cu: 4 subprocess calls (2x test, 1x grep, 1x jq) + 1x grep T4 = 5 calls/lan
#   - Helper: cung 5 calls nhung trong 1 function context — giam fork overhead + 1 source nho de debug.
#   - Quan trong: KHONG gop jq voi grep vi semantics khac biet (JSON parse vs regex).
#
# Usage:
#   if validate_post_gate_tiered "$fix_report" "$docs_sync"; then
#     echo "POST-GATE PASS"
#   else
#     echo "POST-GATE FAIL: $(validate_post_gate_tiered "$fix_report" "$docs_sync")" >&2
#   fi
#
# Cross-ref: CORE-012 (POST-GATE T1-T4), CORE-034 (Auto-Fix Budget).
validate_post_gate_tiered() {
  local fix_report="$1"
  local docs_sync="$2"
  local T1 T2 T3 T4

  # T1: File ton tai + non-empty (ca 2 file)
  if [ -s "$fix_report" ] && [ -s "$docs_sync" ]; then
    T1=ok
  else
    T1=fail
  fi

  # T2: Structure check — fix-report.md co section header.
  # Chi chay neu T1 ok (tranh grep file rong/missing).
  if [ "$T1" = "ok" ] && grep -q "## " "$fix_report" 2>/dev/null; then
    T2=ok
  else
    T2=fail
  fi

  # T3: Content depth — docs-sync-report.json valid JSON + co field files_synced.
  if jq -e '.files_synced >= 0' "$docs_sync" > /dev/null 2>&1; then
    T3=ok
  else
    T3=fail
  fi

  # T4: Cross-reference — fix-report.md co keyword chi trang thai fix.
  if grep -qP '(?i)(fixed|resolved|repaired|dry)' "$fix_report" 2>/dev/null; then
    T4=ok
  else
    T4=fail
  fi

  echo "T1=$T1 T2=$T2 T3=$T3 T4=$T4"
  [ "$T1$T2$T3$T4" = "okokokok" ]
}

# =============================================================================
# _context_budget_check — CORE-038 tiered context threshold check (v10.10.0)
# =============================================================================
# Usage: _context_budget_check <phase_num> [<step_id>]
# Reads $MCV3_CONTEXT_PCT env var (orchestrator-set, integer 0-100).
# Return codes:
#   0 = OK (< 65%)
#   1 = PREP_CHECKPOINT (65-80%)
#   2 = STOP_AFTER_PHASE (80-90%)
#   3 = FORCE_STOP_E009 (>= 90%) — caller phải `exit 9`
_context_budget_check() {
  local phase="$1" step="${2:-unknown}"
  local pct="${MCV3_CONTEXT_PCT:-0}"
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Validate input
  case "$pct" in
    ''|*[!0-9]*) pct=0 ;;  # Non-numeric → treat as 0
  esac

  if [ "$pct" -ge 90 ]; then
    echo "E009: Context >= 90% ($pct%) — FORCE STOP @phase${phase} step ${step}" >&2
    if [ -n "${SESSION_DIR:-}" ] && [ -s "$SESSION_DIR/session-log.json" ]; then
      local TMP="$SESSION_DIR/session-log.json.tmp.cbc.$$"
      jq --arg ts "$ts" --argjson p "$phase" --arg s "$step" --argjson pct "$pct" \
         '.events += [{phase:("phase"+($p|tostring)), event:"CHECKPOINT", timestamp:$ts, step:$s, context_pct:$pct, reason:"force_stop_E009"}]' \
         "$SESSION_DIR/session-log.json" > "$TMP" 2>/dev/null \
         && mv "$TMP" "$SESSION_DIR/session-log.json" 2>/dev/null \
         || rm -f "$TMP"
    fi
    return 3
  elif [ "$pct" -ge 80 ]; then
    echo "WARN: Context $pct% (80-90%) — STOP sau phase${phase}, dùng --resume để tiếp tục" >&2
    return 2
  elif [ "$pct" -ge 65 ]; then
    echo "INFO: Context $pct% (65-80%) — chuẩn bị checkpoint @phase${phase} step ${step}" >&2
    return 1
  fi
  return 0
}
