# §13 Lock/Heartbeat Pattern

> **Implementation:** Delegate sang `bash .claude/scripts/wf-fix-common.sh` functions:
> `acquire_lock()`, `start_heartbeat_daemon()`, `release_lock()`, `cleanup()` (trap handler).
> Lock file là JSON theo schema `wf-fix-lock-v1` (xem `acquire_lock` docstring).

## Lock Stale Detection — 2 cơ chế

```
PATH A (cùng host — chính):
  Đọc lock.pid + lock.host từ .lock JSON
  IF lock.host == current_host:
    IF kill -0 lock.pid succeeds → ERROR (active) → STOP (E031)
    ELSE → WARN, takeover (PID chết, không cần đợi stale window)

PATH B (khác host hoặc thiếu PID — fallback):
  Dùng filesystem mtime
  IF age < MCV3_LOCK_STALE_MINUTES (default 60min) → ERROR (active) → STOP (E031)
  ELSE → WARN, takeover (E008)
```

**Lý do:** Heartbeat daemon có thể chết âm thầm (oom kill, signal sai...) trong khi main process vẫn chạy.
PID liveness check phát hiện ngay; mtime check chỉ phát hiện sau khi vượt stale window (60 phút mặc định).

## Pseudocode (đọc `acquire_lock` trong wf-fix-common.sh để biết chi tiết)

```bash
# ACQUIRE — qua acquire_lock() (POSIX atomic mkdir guard + JSON lock metadata)
source .claude/scripts/wf-fix-common.sh
acquire_lock "$SESSION_DIR" || { echo "E031: lock conflict"; exit 1; }

# HEARTBEAT daemon (update .lock mtime + heartbeat field mỗi 30s)
start_heartbeat_daemon "$SESSION_DIR"
HEARTBEAT_PID=$(cat "$SESSION_DIR/.heartbeat.pid")

# CLEANUP — trap đảm bảo release lock + kill daemon khi thoát
trap cleanup EXIT INT TERM
```
