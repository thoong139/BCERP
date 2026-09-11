# Protocol 22 — Infrastructure R/W Lock (Cross-Session)

> Canonical reference cho cơ chế lock cross-session để **nhiều phiên test e2e** chạy song song trên cùng workspace mà không sập BE/FE/DB/Playwright của nhau.

**Áp dụng từ:** wf-e2e-test v1.2.0, wf-e2e-browser v1.1.0, wf-e2e-retest v1.1.0, wf-e2e-scenario v1.x, wf-e2e-demo v1.x, wf-e2e-verify v7.2.0.

---

## 22.1 Bối cảnh

DEVKIT cho phép nhiều `/wf-e2e-verify <FEAT-ID>` chạy song song (vd 2 dev cùng test 2 feature). Hạ tầng dùng chung:
- **Backend** (port 5048) — 1 process, mọi session test đều phải gọi
- **Frontend** (port 3000) — 1 process Next.js dev
- **PostgreSQL** (port 5432) — 1 instance, schema-per-module
- **Playwright MCP** — 1 browser instance shared cho F2/F5/F7/F8

Nếu không có lock cross-session: session A đang test thì session B restart BE → session A nhận response 503 ngang chừng → ghi nhận sai bug, sai issue.

---

## 22.2 Mô hình R/W Lock

Pattern: **multi-reader + single-writer**, writer-priority queue.

| Vai trò | Khi nào | Cho phép parallel |
|---------|---------|-------------------|
| **Reader** | Test thông thường (chỉ đọc state hạ tầng, không restart/migrate) | YES — nhiều session reader song song OK |
| **Writer** | Restart BE/FE, apply migration, seed shared table | NO — exclusive, chặn mọi reader + writer khác |
| **Writer queued** | Đang chờ tới lượt writer | Reader mới đến phải chờ → tránh writer starvation |

**Tham số mặc định** (override qua env):
- `MCV3_LOCK_HEARTBEAT_SEC=30` — daemon gửi heartbeat mỗi 30s
- `MCV3_LOCK_STALE_SEC=120` — sau 2 phút không heartbeat → auto-release
- `MCV3_LOCK_WAIT_TIMEOUT_SEC=600` — đợi lock tối đa 10 phút → ESCALATE
- `MCV3_LOCK_POLL_INTERVAL_SEC=5` — poll mỗi 5s khi đang đợi

---

## 22.3 Resources

4 resources canonical (CHÍNH XÁC tên này, không alias):

| Resource | Health check | Start command |
|----------|--------------|----------------|
| `backend` | `curl http://localhost:5048/health` | `docker compose up -d eureka-api` |
| `frontend` | `curl http://localhost:3000` → 200/307/308 | `pnpm --filter erp-web dev` |
| `database` | `docker exec eureka-postgres pg_isready` | `docker compose up -d eureka-postgres` |
| `playwright` | MCP `browser_navigate about:blank` | KHÔNG tự start — user bật MCP server |

---

## 22.4 Schema lock file (`global-rw-lock-v1`)

Mỗi resource có 1 lock file: `.mc-data/_global_locks/{resource}.lock`

```json
{
  "$schema": "global-rw-lock-v1",
  "resource": "backend",
  "readers": [
    {
      "session_id": "FEAT-EW-CRM-001-20260514-1000",
      "feat_id": "FEAT-EW-CRM-001",
      "pid": 12345,
      "host": "dev-pc",
      "acquired_at": "2026-05-14T10:05:00Z",
      "last_heartbeat": "2026-05-14T10:05:30Z",
      "intent": "test"
    }
  ],
  "writer": null,
  "writer_pending": [
    {
      "session_id": "FEAT-EW-CRM-002-20260514-1010",
      "feat_id": "FEAT-EW-CRM-002",
      "pid": 12399,
      "host": "dev-pc",
      "queued_at": "2026-05-14T10:06:00Z",
      "last_heartbeat": "2026-05-14T10:06:30Z",
      "reason": "migration_v15"
    }
  ],
  "last_updated": "2026-05-14T10:05:30Z",
  "lock_file_version": 1
}
```

**Audit trail:** `.mc-data/_global_locks/_audit/lock-events.jsonl` (APPEND-only).

**Version snapshot:** `.mc-data/_global_locks/version-snapshot/{session_id}-{resource}.json` chứa `git_head` + `migration_count` lúc acquire lock — dùng để detect khi BE crash giữa chừng (xem §22.7).

---

## 22.5 API Surface

Canonical scripts: `.claude/scripts/wf-e2e-shared/`

| Script | Vai trò |
|--------|---------|
| `global-rw-lock.sh` | Primitives — `acquire_reader_lock`, `acquire_writer_lock`, `upgrade_to_writer`, `downgrade_to_reader`, `release_*`, `heartbeat_session_locks`, `release_all_session_locks`, `cleanup_stale_locks`, `display_lock_status` |
| `version-snapshot.sh` | `snapshot_version <resource> <session>` + `diff_version <resource> <session>` |
| `lock-daemon.sh` | Heartbeat daemon — `start <session_id> <session_dir>` / `stop <session_dir>` |
| `ensure-infra.sh` | **Wrapper khuyến nghị** — kết hợp tất cả: `ensure_infra <resource> <session> <feat_id> <intent> <auto>` |

### Cách dùng (recommended)

```bash
# PRE-GATE của bất kỳ skill nào cần test live
EI=".claude/scripts/wf-e2e-shared/ensure-infra.sh"
AUTO="${AUTO:-0}"

# Test thông thường (multi-session OK)
bash "$EI" ensure_infra database "$SESSION_ID" "$FEAT_ID" read "$AUTO" || exit_with_escalation
bash "$EI" ensure_infra backend  "$SESSION_ID" "$FEAT_ID" read "$AUTO" || exit_with_escalation

# Restart/migrate (exclusive)
bash "$EI" ensure_infra backend  "$SESSION_ID" "$FEAT_ID" write "$AUTO" || exit_with_escalation
# do migration / restart ở đây
release_writer_lock backend "$SESSION_ID"  # hoặc downgrade_to_reader
```

### Exit codes (`ensure-infra.sh`)

| Code | Nghĩa | Caller action |
|------|-------|---------------|
| 0 | Ready, lock acquired | Tiếp tục test |
| 1 | Generic error (jq/docker missing) | Fix env |
| 2 | Wait timeout >10 phút | ESCALATE — ghi block-test.json Nhóm 2 + AskUserQuestion |
| 3 | Invalid args | Sửa caller |
| 4 | Auto-start fail sau retry | ESCALATE Nhóm 2 |
| 5 | Version drift + NOT auto-mode | ESCALATE — user quyết định apply migration hay cancel |

---

## 22.6 Lifecycle Per Session

```
ORCHESTRATOR (wf-e2e-verify) Init:
  1. mkdir SESSION_DIR
  2. write e2e-status.json
  3. bash lock-daemon.sh start <SESSION_ID> <SESSION_DIR>
     → daemon detached, ghi PID vào SESSION_DIR/_locks/global-lock-daemon.pid
     → mark started_by_orchestrator=true trong meta

EACH SUB-SKILL F1-F8:
  PRE-GATE:
    bash ensure-infra.sh ensure_infra <resource> ... read $AUTO
      → tự acquire reader lock (hoặc nếu chưa chạy: writer → start → downgrade)
      → snapshot version cho backend/frontend
  Trong test loop:
    Nếu BE crash giữa chừng:
      bash ensure-infra.sh recover_after_crash <resource> ... $AUTO
        → diff_version, nếu unchanged: writer + restart + downgrade
        → nếu changed + AUTO=1: apply migration + restart
        → nếu changed + NOT AUTO: ESCALATE (exit 5)
  POST-GATE (Phase end):
    Lock vẫn giữ (sub-skill khác có thể dùng)

ORCHESTRATOR Finalize:
  1. write orchestrator-summary.md + phase-summary.md
  2. bash lock-daemon.sh stop <SESSION_DIR>
     → kill daemon
     → release_all_session_locks <SESSION_ID>  (xóa session khỏi mọi readers/writer)

Khi parent PID chết (Ctrl+C, crash):
  → daemon detect parent dead → release_all_session_locks → exit
  → safety net: stale_cleanup tự xóa entries có heartbeat >2 phút
```

---

## 22.7 Crash Recovery với Version Snapshot

Khi BE/FE chết giữa chừng test (vd session khác restart hoặc OOM):

```bash
# Trong test loop, nếu curl trả 503
if ! curl -s -f http://localhost:5048/health; then
  bash .claude/scripts/wf-e2e-shared/ensure-infra.sh \
    recover_after_crash backend "$SESSION_ID" "$FEAT_ID" "${AUTO:-0}"
  case $? in
    0) echo "OK — restarted, tiếp tục test" ;;
    4) escalate_infra_blocked backend ;;
    5) escalate_version_changed backend ;;  # caller xử lý
  esac
fi
```

**Logic recover_after_crash:**

| diff_version result | AUTO mode | Hành động |
|---------------------|-----------|-----------|
| `unchanged` (git_head + migration_count same) | bất kỳ | Upgrade writer → start → downgrade reader. An toàn restart inline. |
| `changed` (session khác migrate/deploy) | `AUTO=1` | Auto apply migration (`dotnet ef database update`) → restart → downgrade. |
| `changed` | `AUTO=0` | ESCALATE — AskUserQuestion: "Apply migration mới / Cancel test / Manual fix". |
| `no_snapshot` | bất kỳ | Restart inline (không có baseline để so sánh). |

---

## 22.8 Anti-Patterns (KHÔNG được làm)

- ❌ Skill restart BE/FE/DB mà KHÔNG acquire writer lock → sập session khác đang test.
- ❌ Bỏ qua exit code 2/4/5 từ `ensure-infra.sh` → silent fail.
- ❌ Fallback "code analysis only" khi `ensure_infra` fail → vi phạm Protocol live-test BẮT BUỘC.
- ❌ Quên `release_*_lock` cuối Phase → starve session khác (daemon stale-cleanup vẫn cứu được sau 2 phút nhưng chậm).
- ❌ Acquire writer lock cho test bình thường → block parallel test không cần thiết.
- ❌ Skill spawn agent mà không pass `$SESSION_ID` và `$AUTO` → agent không heartbeat → stale.

---

## 22.9 Quick Reference Table

| Tình huống | Intent | Resource | Khi nào release |
|------------|--------|----------|-----------------|
| Phase 2 DB query | read | `database` | Phase end |
| Phase 2 DB apply migration | write (1 lần) → release | `database` | Sau migration xong |
| Phase 3 API curl | read | `database` + `backend` | Phase end |
| Phase 5 integration | read | `database` + `backend` + `frontend` | Phase end |
| F2/F5/F7/F8 Playwright | read | `database` + `backend` + `frontend` + `playwright` | Phase end / orchestrator finalize |
| BE crash giữa test | recover_after_crash | `backend` | Auto downgrade sau khi healthy |
| Seed shared table (vd `settings.users`) | write | `database` | Sau INSERT xong |

---

## 22.10 Related Protocols

- Protocol 18 — Session Isolation (per-session locks `_locks/*.lock` trong session dir)
- Protocol 11 — Rollback (race condition recovery)
- Protocol 16 — Critical Decision Gate (escalate khi auto-fix budget cạn)
- CORE-025 — Song song hóa chỉ khi có ownership + isolated scope + stable contract
