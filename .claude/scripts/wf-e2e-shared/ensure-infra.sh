#!/usr/bin/env bash
# ensure-infra.sh — Canonical wrapper kết hợp R/W lock + version snapshot + auto-start.
#
# Đảm bảo infrastructure (BE/FE/DB/Playwright) sẵn sàng cho test theo policy:
#   - Live test BẮT BUỘC, KHÔNG silent fallback code analysis (xem CLAUDE.md + protocols 22)
#   - Hạ tầng không chạy → auto-start (retry 2 lần)
#   - Auto-start fail → ESCALATE Nhóm 2 (caller ghi block-test.json), exit 4
#   - Version snapshot lúc acquire reader; nếu BE crash giữa chừng → check version
#     • unchanged → restart inline (upgrade→writer→start→downgrade→reader)
#     • changed   → trong $AUTO_MODE: apply migration mới + restart; ngoài auto: ESCALATE
#
# Usage:
#   bash ensure-infra.sh <resource> <session_id> [feat_id] [intent=read|write] [auto=0|1]
#
# Resources: backend | frontend | database | playwright
# Intent:
#   read  (default)  → acquire reader lock, ensure healthy, snapshot version
#   write            → acquire writer lock (exclusive cho restart/migrate/seed)
#
# Exit codes:
#   0 = ready (caller giữ lock, có thể test/work)
#   1 = generic error (jq/git/docker missing)
#   2 = lock wait timeout (>10 phút) — ESCALATE
#   3 = invalid args
#   4 = auto-start fail sau retry — ESCALATE Nhóm 2
#   5 = version mismatch + NOT auto-mode — ESCALATE để user quyết
#
# Output: JSON {status, lock_held, snapshot_file, ...} trên stdout

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/global-rw-lock.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/version-snapshot.sh"

# Defaults overridable
START_TIMEOUT_SEC="${MCV3_START_TIMEOUT_SEC:-60}"   # poll health 60s sau khi start
START_MAX_RETRY="${MCV3_START_MAX_RETRY:-2}"        # 2 retry → 3 lan thu

# ----------------------------------------------------------------------------
# Health checks per resource
# ----------------------------------------------------------------------------

_ei_health_backend() {
  curl -s -f -o /dev/null --max-time 5 http://localhost:5048/health 2>/dev/null
}

_ei_health_frontend() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null)
  [[ "$code" == "200" || "$code" == "307" || "$code" == "308" ]]
}

_ei_health_database() {
  if command -v docker >/dev/null 2>&1; then
    docker exec eureka-postgres pg_isready -h localhost >/dev/null 2>&1
  else
    return 1
  fi
}

_ei_health_playwright() {
  # Playwright MCP probe: caller PHẢI có sẵn `mcp__plugin_playwright_playwright__browser_navigate`.
  # Trong bash script không gọi được MCP trực tiếp — chỉ check process Playwright hoặc lock file.
  # Convention: nếu lock file resource=playwright có writer hoặc reader của session khác → "in use" nghĩa là MCP available.
  # Khi caller (skill) đã thử navigate thành công trước đó → set MCV3_PLAYWRIGHT_OK=1 trong env.
  [[ "${MCV3_PLAYWRIGHT_OK:-0}" == "1" ]] && return 0
  # Fallback heuristic: kiểm tra port 9222 (default Playwright debug port) hoặc tồn tại browser-mcp.lock cũ
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null --max-time 2 http://localhost:9222/json/version 2>/dev/null && return 0
  fi
  # Không xác định được → coi như cần caller test sau khi acquire lock
  return 0
}

_ei_check_health() {
  case "$1" in
    backend)    _ei_health_backend ;;
    frontend)   _ei_health_frontend ;;
    database)   _ei_health_database ;;
    playwright) _ei_health_playwright ;;
    *) return 1 ;;
  esac
}

# ----------------------------------------------------------------------------
# Start operations per resource
# ----------------------------------------------------------------------------

_ei_start_backend() {
  if command -v docker >/dev/null 2>&1 && \
     [[ -f docker-compose.local.yml ]]; then
    docker compose -f docker-compose.local.yml up -d eureka-api 2>&1 | tail -5 >&2
  else
    # Fallback: dotnet watch background
    ( cd apps/backend && dotnet run --project Eureka.Api > /tmp/eureka-api.log 2>&1 & ) >/dev/null
  fi
}

_ei_start_frontend() {
  ( cd apps/erp-web && pnpm dev > /tmp/erp-web.log 2>&1 & ) >/dev/null
}

_ei_start_database() {
  if command -v docker >/dev/null 2>&1 && [[ -f docker-compose.local.yml ]]; then
    docker compose -f docker-compose.local.yml up -d eureka-postgres 2>&1 | tail -5 >&2
  fi
}

_ei_start_playwright() {
  # Playwright MCP thường được Claude Code spawn, không phải mình. KHÔNG try start.
  # Caller phải tự kiểm tra qua MCP probe sau khi acquire lock.
  return 0
}

_ei_start() {
  case "$1" in
    backend)    _ei_start_backend ;;
    frontend)   _ei_start_frontend ;;
    database)   _ei_start_database ;;
    playwright) _ei_start_playwright ;;
    *) return 1 ;;
  esac
}

_ei_wait_healthy() {
  local resource="$1" timeout="${2:-$START_TIMEOUT_SEC}"
  local elapsed=0
  while (( elapsed < timeout )); do
    if _ei_check_health "$resource"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

_ei_capture_diagnose() {
  local resource="$1" session_dir="${2:-/tmp}"
  mkdir -p "$session_dir" 2>/dev/null
  local log="$session_dir/diagnose-$resource.log"
  {
    echo "=== diagnose $resource at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    case "$resource" in
      backend)
        echo "--- docker ps ---"
        docker ps --filter "name=eureka-api" 2>/dev/null || true
        echo "--- last 50 lines eureka-api log ---"
        docker logs eureka-api --tail 50 2>&1 || tail -50 /tmp/eureka-api.log 2>/dev/null || true
        echo "--- port 5048 ---"
        netstat -an 2>/dev/null | grep 5048 || ss -tlnp 2>/dev/null | grep 5048 || true
        ;;
      frontend)
        echo "--- last 50 lines erp-web log ---"
        tail -50 /tmp/erp-web.log 2>/dev/null || true
        echo "--- port 3000 ---"
        netstat -an 2>/dev/null | grep 3000 || ss -tlnp 2>/dev/null | grep 3000 || true
        ;;
      database)
        echo "--- docker ps eureka-postgres ---"
        docker ps --filter "name=eureka-postgres" 2>/dev/null || true
        echo "--- pg_isready ---"
        docker exec eureka-postgres pg_isready 2>&1 || true
        ;;
      playwright)
        echo "--- Playwright check ---"
        echo "MCV3_PLAYWRIGHT_OK=${MCV3_PLAYWRIGHT_OK:-unset}"
        ;;
    esac
  } > "$log" 2>&1
  echo "$log"
}

# ----------------------------------------------------------------------------
# Migration apply (auto-mode khi version drift)
# ----------------------------------------------------------------------------

_ei_apply_migrations() {
  if command -v dotnet >/dev/null 2>&1 && [[ -d apps/backend/Eureka.Infrastructure ]]; then
    dotnet ef database update \
      --project apps/backend/Eureka.Infrastructure \
      --startup-project apps/backend/Eureka.Api 2>&1 | tail -10 >&2
    return $?
  fi
  echo "ERROR: dotnet ef khong kha dung — khong the apply migration" >&2
  return 1
}

# ----------------------------------------------------------------------------
# Main: ensure_infra <resource> <session_id> [feat_id] [intent] [auto]
# ----------------------------------------------------------------------------

ensure_infra() {
  local resource="${1:?resource required}"
  local session_id="${2:?session_id required}"
  local feat_id="${3:-}"
  local intent="${4:-read}"
  local auto_mode="${5:-0}"

  case "$resource" in
    backend|frontend|database|playwright) ;;
    *) echo "ERROR: resource khong hop le: $resource" >&2; return 3 ;;
  esac

  case "$intent" in
    read|write) ;;
    *) echo "ERROR: intent phai la read hoac write" >&2; return 3 ;;
  esac

  # ---- WRITE intent: caller xin exclusive (restart/migrate/seed) ----
  if [[ "$intent" == "write" ]]; then
    if ! acquire_writer_lock "$resource" "$session_id" "$feat_id" "explicit-write"; then
      echo "ERROR: acquire_writer_lock timeout cho $resource" >&2
      return 2
    fi
    jq -n --arg r "$resource" --arg sid "$session_id" \
      '{status:"ready", resource:$r, session_id:$sid, lock:"writer", intent:"write"}'
    return 0
  fi

  # ---- READ intent ----
  # Bước 1: acquire reader lock
  if ! acquire_reader_lock "$resource" "$session_id" "$feat_id"; then
    echo "ERROR: acquire_reader_lock timeout cho $resource" >&2
    return 2
  fi

  # Bước 2: check health
  if _ei_check_health "$resource"; then
    # OK — snapshot version & return
    if [[ "$resource" == "backend" || "$resource" == "frontend" ]]; then
      snap_file=$(snapshot_version "$resource" "$session_id")
    fi
    jq -n --arg r "$resource" --arg sid "$session_id" --arg snap "${snap_file:-}" \
      '{status:"ready", resource:$r, session_id:$sid, lock:"reader", health:"running", snapshot:$snap}'
    return 0
  fi

  # Bước 3: KHÔNG healthy → check version diff (chỉ với backend)
  local version_changed=0 diff_output=""
  if [[ "$resource" == "backend" ]]; then
    diff_output=$(diff_version "$resource" "$session_id" 2>/dev/null) || version_changed=$?
  fi

  # Bước 4: Quyết định restart hay ESCALATE
  if [[ $version_changed -eq 1 && "$auto_mode" != "1" ]]; then
    # Version changed + NOT auto-mode → ESCALATE
    release_reader_lock "$resource" "$session_id"
    echo "ERROR: version drift detected cho $resource (KHONG auto-mode)" >&2
    echo "$diff_output" >&2
    return 5
  fi

  # Bước 5: Upgrade lên writer để start
  echo "INFO: $resource khong chay — dang upgrade reader -> writer de start" >&2
  if ! upgrade_to_writer "$resource" "$session_id" "auto-restart"; then
    echo "ERROR: upgrade_to_writer timeout cho $resource" >&2
    release_reader_lock "$resource" "$session_id" 2>/dev/null
    return 2
  fi

  # Bước 5b: Apply migration nếu version drift + auto-mode
  if [[ $version_changed -eq 1 && "$auto_mode" == "1" && "$resource" == "backend" ]]; then
    echo "INFO: auto-mode + version drift → apply migration moi" >&2
    if ! _ei_apply_migrations; then
      echo "WARN: apply migration fail — tiep tuc start backend" >&2
    fi
  fi

  # Bước 6: Start với retry
  local attempt=0
  local diag_log=""
  while (( attempt <= START_MAX_RETRY )); do
    attempt=$((attempt + 1))
    echo "INFO: start $resource (attempt $attempt/$((START_MAX_RETRY + 1)))..." >&2
    _ei_start "$resource"
    if _ei_wait_healthy "$resource" "$START_TIMEOUT_SEC"; then
      # Healthy — snapshot + downgrade
      if [[ "$resource" == "backend" || "$resource" == "frontend" ]]; then
        snap_file=$(snapshot_version "$resource" "$session_id")
      fi
      downgrade_to_reader "$resource" "$session_id"
      jq -n --arg r "$resource" --arg sid "$session_id" --arg snap "${snap_file:-}" \
            --arg a "$attempt" '
        {status:"ready", resource:$r, session_id:$sid, lock:"reader",
         health:"started", started_attempts:($a|tonumber), snapshot:$snap}'
      return 0
    fi
    diag_log=$(_ei_capture_diagnose "$resource" "/tmp/wf-e2e-shared-diag-$session_id")
  done

  # Auto-start fail sau retry — release writer, ESCALATE
  release_writer_lock "$resource" "$session_id"
  echo "ERROR: auto-start $resource fail sau $((START_MAX_RETRY + 1)) attempt — ESCALATE Nhom 2" >&2
  echo "DIAGNOSE: $diag_log" >&2
  jq -n --arg r "$resource" --arg sid "$session_id" --arg log "$diag_log" --arg attempts "$attempt" '
    {status:"escalate", resource:$r, session_id:$sid, error_code:"E0XX",
     blocking_reason:"\($r)_not_running", attempts:($attempts|tonumber),
     diagnose_log:$log,
     action_required:"Ghi block-test.json Nhom 2 + AskUserQuestion (Retry/Manual/Cancel)"}'
  return 4
}

# ----------------------------------------------------------------------------
# CLI entry
# ----------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-help}"; shift || true
  case "$cmd" in
    ensure_infra) ensure_infra "$@" ;;
    help|*)
      cat <<EOF
ensure-infra.sh — Canonical wrapper R/W lock + version snapshot + auto-start

USAGE:
  bash ensure-infra.sh ensure_infra <resource> <session_id> [feat_id] [intent] [auto]

ARGS:
  resource:    backend | frontend | database | playwright
  session_id:  vd FEAT-EW-CRM-001-20260514-1000
  feat_id:     optional, vd FEAT-EW-CRM-001
  intent:      read (default) | write
  auto:        0 (default) | 1 — bat auto-mode (apply migration moi khi drift)

EXIT CODES:
  0 = ready
  2 = lock wait timeout 10min — ESCALATE
  3 = invalid args
  4 = auto-start fail — ESCALATE Nhom 2
  5 = version drift + NOT auto — ESCALATE

ENV:
  MCV3_START_TIMEOUT_SEC  (default 60)
  MCV3_START_MAX_RETRY    (default 2)
  MCV3_PLAYWRIGHT_OK      (0|1) — caller danh dau Playwright MCP probe da OK

OUTPUT:
  JSON tren stdout: {status, resource, session_id, lock:"reader|writer", ...}
EOF
      ;;
  esac
fi
