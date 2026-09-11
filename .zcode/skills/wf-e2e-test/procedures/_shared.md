# Shared — wf-e2e-verify v5.0.0

## State Machine Chi Tiết

### status.json Schema

```json
{
  "session_id": "{FEAT-ID}-{YYYYMMDD-HHmm}",
  "feat_id": "FEAT-EW-XXX-NNN",
  "feat_name": "...",
  "spec_path": ".mc-data/docs/phase2-features/...",
  "started_at": "ISO8601",
  "current_phase": 0,
  "sub_state": "FIND|ASSESS|BO_SUNG|TEST|VERIFY|DONE",
  "context_estimate_pct": 0,
  "phases": {
    "phase_0_status": "done|in_progress|not_started",
    "phase_1_status": "done|in_progress|not_started",
    "phase_1_bo_sung_count": 0,
    "phase_1_verify_attempts": 0,
    "phase_2_status": "done|in_progress|not_started",
    "phase_2_bo_sung_count": 0,
    "phase_3_status": "done|in_progress|not_started",
    "phase_3_bo_sung_count": 0,
    "phase_4_status": "done|in_progress|not_started",
    "phase_4_bo_sung_count": 0,
    "phase_5_status": "done|in_progress|not_started",
    "phase_6_status": "done|in_progress|not_started"
  },
  "notes": []
}
```

## Context Budget Protocol

Sau mỗi BỔ SUNG iteration, ước tính context usage (số file đã đọc / complexity).

Nếu ước tính >65%:
```
⚠️ CONTEXT BUDGET CẢNH BÁO
Context ước tính đã vượt 65%. Để tránh mất dữ liệu, hãy:
1. Tôi sẽ ghi checkpoint hiện tại vào status.json
2. Dùng /compact để giải phóng context
3. Resume bằng: /wf-e2e-verify --resume --session={SESSION_ID} --phase={N}
```

Ghi checkpoint: update `status.json` với `current_phase`, `sub_state`, `bo_sung_count`, notes.

## Assess Checklist per Phase

### Phase 1 — Business
```
CẦN CÓ:
  ✓ Mục đích: rõ, cụ thể (không chỉ copy tên feature)
  ✓ Actors: ≥1 role cụ thể (không chỉ "người dùng")
  ✓ Dữ liệu: ≥1 entity/bảng chính
  ✓ Flow: ≥3 bước cụ thể
  ✓ Business rules: ≥1 BR cụ thể
```

### Phase 2 — DB
```
CẦN CÓ:
  ✓ ≥1 table chính được xác định (tên thật)
  ✓ Schema name (PostgreSQL schema-per-module)
  ✓ FK/relationships (nếu có)
  ✓ CRUD operations: biết create/read/update/delete nào
  ✓ Migration file tồn tại
```

### Phase 3 — API
```
CẦN CÓ:
  ✓ ≥1 endpoint với route + method
  ✓ Handler class + file path
  ✓ Validator (nếu có)
  ✓ Permission string (nếu RequireAuthorization)
  ✓ Response type/shape
```

### Phase 4 — UI
```
CẦN CÓ:
  ✓ ≥1 page/route path
  ✓ ≥1 React Query hook (useQuery hoặc useMutation)
  ✓ Main component file
  ✓ Loading + error state trong code
```

## BỔ SUNG Strategies

Thứ tự đọc thêm khi thiếu info:

1. **Feature spec chi tiết** — đọc lại section chưa đọc kỹ
2. **Serena find_symbol** — tìm entity/handler/command theo tên
3. **gitnexus query** — tìm theo concept
4. **gitnexus context** — xem caller/callee của symbol
5. **Grep trực tiếp** — grep keyword trong source code
6. **Related features** — đọc `dependencies` từ registry
7. **Architecture docs** — `.mc-data/docs/phase3-architecture/`

## CI Detection (CORE-033)

> CI detection chay boi orchestrator (wf-e2e-verify) tai Phase Init.
> Sub-skill doc bien moi truong `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$CI_CONTEXT` tu orchestrator.
> Neu sub-skill duoc invoke standalone -> fallback Grep/Glob.

```bash
GITNEXUS_AVAILABLE=${GITNEXUS_AVAILABLE:-false}
SERENA_AVAILABLE=${SERENA_AVAILABLE:-false}
CI_CONTEXT=${CI_CONTEXT:-""}
```

## Error Ledger (CORE-034)

APPEND-only JSONL — khong rebuild toan bo array moi lan ghi.

```bash
ERROR_LEDGER="$SESSION_DIR/error-ledger.json"

log_error() {
  local CODE="$1"
  local PHASE="$2"
  local MSG="$3"
  local RETRY="${4:-0}"
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"timestamp\":\"$ISO\",\"code\":\"$CODE\",\"phase\":\"$PHASE\",\"message\":\"$MSG\",\"retry_count\":$RETRY}" >> "$ERROR_LEDGER"
}
```

## Atomic Write Pattern (CORE-035)

Moi JSON state file phai: tmp build → jq validate → atomic move.

```bash
atomic_write_json() {
  local TARGET="$1"
  local TMP="${TARGET}.tmp.$$"
  jq '.' "$TMP" > /dev/null || { rm -f "$TMP"; echo "FAIL: invalid JSON"; return 1; }
  mv "$TMP" "$TARGET"
}
```

## Context & Checkpoint (CORE-038)

| Context Usage | Hanh dong |
|---------------|-----------|
| < 65% | Tiep tuc binh thuong |
| 65-80% | Chuan bi checkpoint (luu status.json) |
| 80-90% | Luu checkpoint, STOP sau phase hien tai -> huong dan --resume |
| > 90% | FORCE STOP (E009) — checkpoint bat buoc, khong advance |

## Resume Protocol

Khi `--resume`:
1. List sessions: `ls .mc-data/work/wf-e2e-verify/sessions/` filter by FEAT-ID prefix
2. Load `status.json` của session mới nhất (hoặc theo `--session=`)
3. Read `current_phase` + `sub_state`
4. Jump tới phase đó, restore context từ các output files đã ghi

## Error Handling

| Code | Trigger | Action |
|------|---------|--------|
| E001 | FEAT-ID không trong registry | In lỗi + gợi ý ID đúng → DỪNG |
| E002 | Spec file không tồn tại | In path mong đợi → DỪNG |
| E003 | Session không tìm thấy để resume | List sessions có sẵn → DỪNG |
| E004 | Registry không parse được | Check file integrity → DỪNG |
| E005 | Session dir không tạo được | Check permissions → DỪNG |

---

## Infrastructure Auto-Start (BẮT BUỘC khi live-test required)

**Nguyên tắc cốt lõi (chốt):**
- Live test (DB / API / FE) là **BẮT BUỘC** ở Phase 2-5.
- Nếu hạ tầng không chạy → **PHẢI cố gắng khởi động** trước, KHÔNG silent fallback "code analysis".
- Auto-start fail sau retry → ESCALATE blocking (ghi block-test.json Nhóm 2 + AskUserQuestion), KHÔNG advance phase.
- **Code analysis CHỈ là kết quả hợp lệ trong 1 trường hợp duy nhất:** test bản chất cần con người (Nhóm 4: visual inspection, real payment, OAuth real, hardware, human judgment). Mọi trường hợp khác → live test mandatory.

### Parallel-safe: Cross-session R/W Lock (BẮT BUỘC)

Nhiều session có thể chạy song song (vd: 2 feature test cùng lúc). Để 1 session không sập BE/FE/DB/Playwright của session khác:

- **Reader lock** = test thông thường (chỉ đọc state hạ tầng, không restart/migrate). Nhiều session reader song song OK.
- **Writer lock** = restart BE/FE, apply migration, seed data shared. Exclusive — chặn mọi reader + writer khác.
- **Writer priority**: khi có writer queued, reader mới đến phải chờ → tránh writer starvation.
- **Heartbeat 30s**, **stale 2 phút** auto-release, **wait timeout 10 phút** → ESCALATE.

Canonical scripts:

| Script | Vai trò |
|--------|---------|
| `.claude/scripts/wf-e2e-shared/global-rw-lock.sh` | R/W lock primitives — `acquire_reader_lock`, `acquire_writer_lock`, `upgrade_to_writer`, `downgrade_to_reader`, `heartbeat_session_locks`, `release_all_session_locks`, `display_lock_status` |
| `.claude/scripts/wf-e2e-shared/version-snapshot.sh` | `snapshot_version` + `diff_version` (git HEAD + migration count) |
| `.claude/scripts/wf-e2e-shared/lock-daemon.sh` | Background heartbeat daemon — auto release khi session chết |
| `.claude/scripts/wf-e2e-shared/ensure-infra.sh` | **Wrapper one-shot**: kết hợp lock + version snapshot + auto-start + escalate. Caller chỉ cần gọi 1 dòng bash thay vì define function inline. |

```bash
LOCK_LIB=".claude/scripts/wf-e2e-shared/global-rw-lock.sh"
VER_LIB=".claude/scripts/wf-e2e-shared/version-snapshot.sh"
# shellcheck disable=SC1090
source "$LOCK_LIB"
source "$VER_LIB"

# Hoặc dùng wrapper one-shot (recommended cho hầu hết trường hợp):
# bash .claude/scripts/wf-e2e-shared/ensure-infra.sh ensure_infra <resource> <session_id> <feat_id> <intent> <auto>
```

### Heartbeat daemon — start một lần ở Phase 0 SETUP

```bash
# Phase 0 SETUP của F1 (hoặc Init của orchestrator)
bash .claude/scripts/wf-e2e-shared/lock-daemon.sh start "$SESSION_ID" "$SESSION_DIR"
# Daemon tự exit khi session_dir/.lock biến mất hoặc parent PID chết
# → release_all_session_locks tự động

# Phase 6 OUTPUT / orchestrator finalize:
bash .claude/scripts/wf-e2e-shared/lock-daemon.sh stop "$SESSION_DIR"
```

### Canonical auto-start pattern (gọi trước mọi live test)

```bash
# ensure_infrastructure_running <component> [intent=read|write] [retry_count=2]
# component ∈ {database, backend, frontend, playwright}
# intent  = read  → multi-session test OK
#         = write → exclusive (restart, migrate, seed shared DB)
ensure_infrastructure_running() {
  local COMPONENT="$1"
  local INTENT="${2:-read}"
  local MAX_RETRY="${3:-2}"
  local SESSION_ID="${SESSION_ID:?missing SESSION_ID}"
  local FEAT_ID="${FEAT_ID:-}"

  case "$INTENT" in
    read)
      _ensure_running_read_intent "$COMPONENT" "$MAX_RETRY" || return 1 ;;
    write)
      _ensure_running_write_intent "$COMPONENT" "$MAX_RETRY" || return 1 ;;
    *)
      echo "ERROR: invalid intent '$INTENT' (read|write)"; return 3 ;;
  esac
}

# Read intent: acquire reader lock → check health → nếu chưa chạy thì
# UPGRADE thành writer để start, sau đó DOWNGRADE về reader.
_ensure_running_read_intent() {
  local COMPONENT="$1" MAX_RETRY="$2"

  acquire_reader_lock "$COMPONENT" "$SESSION_ID" "$FEAT_ID" || {
    _escalate_lock_timeout "$COMPONENT" "reader"; return 1;
  }

  if check_component_health "$COMPONENT"; then
    # Session khác đã start; ghi snapshot version để detect crash sau này
    snapshot_version "$COMPONENT" "$SESSION_ID" >/dev/null
    return 0
  fi

  # Chưa chạy → cần writer lock để start (avoid double-start race)
  release_reader_lock "$COMPONENT" "$SESSION_ID"
  acquire_writer_lock "$COMPONENT" "$SESSION_ID" "$FEAT_ID" "start_$COMPONENT" || {
    _escalate_lock_timeout "$COMPONENT" "writer"; return 1;
  }

  # Re-check sau khi giành writer (có thể session khác đã start xong)
  if check_component_health "$COMPONENT"; then
    snapshot_version "$COMPONENT" "$SESSION_ID" >/dev/null
    downgrade_to_reader "$COMPONENT" "$SESSION_ID"
    return 0
  fi

  local attempt=0
  while [ $attempt -le $MAX_RETRY ]; do
    [ $attempt -eq 0 ] && echo "ℹ️  $COMPONENT chưa chạy — đang khởi động..." \
                       || echo "⚠️  $COMPONENT retry $((attempt+1))/$((MAX_RETRY+1))..."
    start_component "$COMPONENT"
    wait_for_health "$COMPONENT" 60
    if check_component_health "$COMPONENT"; then
      echo "✅ $COMPONENT đã khởi động"
      snapshot_version "$COMPONENT" "$SESSION_ID" >/dev/null
      downgrade_to_reader "$COMPONENT" "$SESSION_ID"
      return 0
    fi
    attempt=$((attempt+1))
  done

  # Hết retry — release writer lock, diagnose, ESCALATE
  capture_diagnose "$COMPONENT" > "$SESSION_DIR/F1-test/diagnose-$COMPONENT.log"
  release_writer_lock "$COMPONENT" "$SESSION_ID"
  escalate_infra_blocked "$COMPONENT"
  return 1
}

# Write intent: caller chủ động muốn restart/migrate. Acquire writer, làm việc,
# caller có trách nhiệm release/downgrade.
_ensure_running_write_intent() {
  local COMPONENT="$1"
  acquire_writer_lock "$COMPONENT" "$SESSION_ID" "$FEAT_ID" "explicit_write" || {
    _escalate_lock_timeout "$COMPONENT" "writer"; return 1;
  }
  # Caller chịu trách nhiệm: do work + release_writer_lock / downgrade_to_reader
  return 0
}

# Version-aware restart guard: gọi khi BE health-check fail giữa chừng (BE chết).
# Trong --auto mode: tự apply migration mới nếu version đã đổi (do session khác migrate).
# Ngoài --auto: ESCALATE.
guard_restart_with_version_check() {
  local COMPONENT="$1"
  local diff_output
  diff_output=$(diff_version "$COMPONENT" "$SESSION_ID")
  local diff_rc=$?

  case $diff_rc in
    0)  # unchanged → restart inline an toàn
        echo "ℹ️  $COMPONENT crash — version không đổi, restart inline" ;;
    1)  # changed → session khác đã migrate/redeploy
        if [ "${AUTO:-false}" = "true" ]; then
          echo "ℹ️  $COMPONENT version thay đổi — auto mode: apply migration mới + restart"
          apply_pending_migrations || true
        else
          echo "⚠️  $COMPONENT version thay đổi giữa chừng. Diff:"
          echo "$diff_output"
          _escalate_version_changed "$COMPONENT"
          return 1
        fi ;;
    2)  # no snapshot → bỏ qua, restart bình thường
        : ;;
  esac
  return 0
}

apply_pending_migrations() {
  if command -v dotnet >/dev/null 2>&1 && [ -d apps/backend/Eureka.Infrastructure ]; then
    dotnet ef database update \
      --project apps/backend/Eureka.Infrastructure \
      --startup-project apps/backend/Eureka.Api 2>&1 | tail -20
  else
    echo "WARN: dotnet không khả dụng — skip migration apply"
  fi
}

_escalate_lock_timeout() {
  local COMPONENT="$1" KIND="$2"
  classify_and_escalate_block \
    --reason "infrastructure_lock_timeout" \
    --detail "Chờ ${KIND} lock '$COMPONENT' quá 10 phút. Xem .mc-data/_global_locks/$COMPONENT.lock để biết session đang giữ."
}

_escalate_version_changed() {
  local COMPONENT="$1"
  classify_and_escalate_block \
    --reason "version_changed_during_test" \
    --detail "$COMPONENT crash giữa chừng + version đã đổi (session khác migrate/deploy). Cần user quyết định apply migration hay hủy test. Trong --auto mode, sẽ tự apply migration."
}
```

### check_component_health

```bash
check_component_health() {
  case "$1" in
    database|db)
      docker exec eureka-postgres pg_isready -h localhost > /dev/null 2>&1 ;;
    backend)
      curl -s -f http://localhost:5048/health > /dev/null 2>&1 ;;
    frontend|fe)
      HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
      [ "$HTTP" = "200" ] || [ "$HTTP" = "307" ] ;;
    playwright)
      # MCP probe: navigate about:blank — nếu trả về OK là MCP available
      mcp__plugin_playwright_playwright__browser_navigate --url=about:blank >/dev/null 2>&1 ;;
  esac
}
```

### start_component (delegate)

```bash
start_component() {
  case "$1" in
    database|db)
      docker compose -f docker-compose.local.yml up -d eureka-postgres ;;
    backend)
      docker compose -f docker-compose.local.yml up -d eureka-api ;;
    frontend|fe)
      # Background start, capture PID for cleanup nếu cần
      ( cd apps/erp-web && pnpm dev > /tmp/erp-web.log 2>&1 & )
      sleep 2 ;;
    playwright)
      # Playwright MCP không có "start" — nếu probe fail là user phải bật MCP server
      echo "WARN: Playwright MCP không response. User cần bật MCP server."
      return 1 ;;
  esac
}
```

### escalate_infra_blocked (KHÔNG fallback code analysis)

```bash
escalate_infra_blocked() {
  local COMPONENT="$1"
  local REASON_MAP_db="db_not_running"
  local REASON_MAP_backend="backend_not_running"
  local REASON_MAP_fe="fe_not_running"
  local REASON_VAR="REASON_MAP_$COMPONENT"
  local BLOCKING_REASON="${!REASON_VAR}"

  # 1. GHI block-test.json (Nhóm 2 — Infra) — KHÔNG ghi PASS, KHÔNG advance phase
  append_block_test_entry \
    --blocking_reason "$BLOCKING_REASON" \
    --blocking_detail "Auto-start $COMPONENT thất bại sau 2 retry. Diagnose: $SESSION_DIR/F1-test/diagnose-$COMPONENT.log" \
    --status "blocked" \
    --group 2

  # 2. Log error ledger
  log_error "E0XX" "infra" "$COMPONENT không khởi động được sau retry"

  # 3. ESCALATE — AskUserQuestion blocking (KHÔNG silent fallback)
  echo ""
  echo "🚫 ESCALATE: Hạ tầng $COMPONENT không khởi động được."
  echo "    Diagnose log: $SESSION_DIR/F1-test/diagnose-$COMPONENT.log"
  echo ""
  echo "    Lựa chọn:"
  echo "    1) Retry sau khi user fix tay (gõ 'retry')"
  echo "    2) Cancel pipeline (gõ 'cancel')"
  echo ""
  echo "    KHÔNG có lựa chọn 'fallback code analysis' — live test là BẮT BUỘC."
  echo "    Code analysis chỉ hợp lệ cho Nhóm 4 (test bản chất cần con người: visual, real payment, OAuth real, hardware)."

  # Trả về để caller stop, KHÔNG advance phase
  return 1
}
```

### Vị trí gọi auto-start (per phase)

| Phase | Component cần auto-start | Intent | Trước khi gọi |
|-------|--------------------------|--------|----------------|
| **Phase 2 DB (apply migration mới)** | `database` | **write** | Trước `dotnet ef database update` (writer exclusive, tránh conflict với session khác) |
| **Phase 2 DB (query)** | `database` | `read` | Trước SQL live test |
| **Phase 3 API** | `database` + `backend` | `read` | Trước `curl` request |
| **Phase 4 UI (static mapping)** | — | — | Static read code, không cần lock |
| **Phase 5 Integration** | `database` + `backend` + `frontend` | `read` | Trước chain test FE→API |
| **Phase 2-5 (seed data shared schema)** | `database` | **write** | Trước INSERT seed vào shared table (vd: `settings.users`) — tránh PK conflict |

### Khi BE crash giữa chừng (vd: session khác restart)

```bash
# Trong test loop: nếu curl fail giữa chừng
if ! check_component_health backend; then
  guard_restart_with_version_check backend || return 1
  # Nếu version unchanged → restart inline (acquire writer, restart, downgrade)
  acquire_writer_lock backend "$SESSION_ID" "$FEAT_ID" "crash_restart"
  start_component backend; wait_for_health backend 60
  downgrade_to_reader backend "$SESSION_ID"
fi
```

### Quy tắc nghiêm ngặt

- ❌ KHÔNG ghi "Test sẽ là code analysis only" khi infra không chạy.
- ❌ KHÔNG ghi `RESULT=PASS` cho test live khi infra fail (kể cả nếu code static review OK).
- ❌ KHÔNG advance phase tiếp theo khi auto-start fail.
- ✅ ĐƯỢC ghi `RESULT=SKIPPED + verification_method=static_code_review` CHỈ khi test thuộc Nhóm 4 (cần con người) — xem `block-classification.md`.
- ✅ ĐƯỢC ghi static review (EF Config, validator code) như **bổ sung** cạnh live test, KHÔNG thay thế.
