# 09 — Multi-Session R/W Lock

> **Mức độ ràng buộc:** KHUYẾN NGHỊ khi skill share resource giữa sessions/devs
> **Protocol liên quan:** Protocol 22
> **Khi nào dùng:** Nhiều sessions/dev cùng access live infra (BE/FE/DB/Playwright), CI cache, hoặc cross-session state

---

## 1. Vấn đề pattern giải quyết

Khi 2 user/sessions cùng chạy:
```
Session A: /wf-fix-bugs đang dùng base_url http://localhost:3000
Session B: /wf-e2e-verify cũng cần base_url http://localhost:3000
   ↓
Conflict: port 3000 collision, test data race
```

**Anti-pattern:**
- Hardcode "single session only" → bottleneck
- Mỗi session spawn dev server riêng → resource waste
- Không sync → race condition, corrupted state

**Pattern giải quyết:** **R/W lock cross-session** với:
- Multi-reader (nhiều sessions read concurrent)
- Single-writer (1 session write exclusive)
- Writer priority (avoid starvation)
- Heartbeat (detect stale lock)

---

## 2. Pattern definition

### 2.1. Lock primitives

```
Read lock (shared):
  - Nhiều readers cùng có lock
  - Block writers cho đến khi all readers release
  - File: $RESOURCE.read-locks/$SESSION_ID

Write lock (exclusive):
  - 1 writer độc quyền
  - Block readers + other writers
  - File: $RESOURCE.write-lock
```

### 2.2. Lock acquisition flow

```bash
acquire_read_lock() {
  # Wait if writer holds or writer waiting
  while [ -f "$RESOURCE.write-lock" ] || [ -f "$RESOURCE.write-pending" ]; do
    check_stale_lock
    sleep 1
  done

  # Acquire
  echo "$SESSION_ID|$PID|$(date -Iseconds)" > "$RESOURCE.read-locks/$SESSION_ID"
  start_heartbeat_daemon
}

acquire_write_lock() {
  # Signal intent
  echo "$SESSION_ID|$PID|$(date -Iseconds)" > "$RESOURCE.write-pending"

  # Wait readers release
  while [ -n "$(ls $RESOURCE.read-locks/ 2>/dev/null)" ]; do
    check_stale_locks
    sleep 1
  done

  # Acquire write (atomic)
  ( set -C; mv "$RESOURCE.write-pending" "$RESOURCE.write-lock" )
  start_heartbeat_daemon
}
```

### 2.3. Heartbeat + stale detection

```
Lock file format:
  $SESSION_ID|$PID|$ACQUIRED_AT|$HEARTBEAT_AT

Heartbeat daemon:
  Every 30 seconds:
    Update $HEARTBEAT_AT in lock file

Stale detection:
  If now - $HEARTBEAT_AT > 30 min:
    → Lock is stale (session crashed)
    → Force-release: rm -f $LOCK_FILE
    → Log to session-log.json
```

### 2.4. Writer priority

```
Without priority:
  Reader A → ... → Reader B → ... → Reader C → Writer waits forever (starvation)

With priority:
  Reader A → Writer signals intent ($RESOURCE.write-pending)
  → New readers BLOCKED until writer done
  → Existing readers complete + release
  → Writer acquires
```

---

## 3. Case study — wf-e2e-* skills (Protocol 22)

```
E2E pipeline shared infra:
  - Backend server (port 8000)
  - Frontend server (port 3000)
  - Database (Postgres on 5432)
  - Playwright browser instances

Resource: .mc-data/work/_locks/e2e-infra.lock

Session A (wf-e2e-verify FEAT-A): acquire READ lock (sharing infra OK)
Session B (wf-e2e-verify FEAT-B): acquire READ lock (concurrent test OK)
Session C (wf-e2e-fix): need WRITE lock (apply DB migration)
   ↓
C signals write-pending
A, B continue until done, release
C acquires write, applies migration, releases
   ↓
Next wave of readers can acquire
```

**Heartbeat daemon flow:**
```
Session A acquires lock at 10:00:00
  Heartbeat at 10:00:30, 10:01:00, 10:01:30, ...

Session A crashes at 10:15:00 (no more heartbeat)
   ↓
Session D tries acquire at 10:45:30
  Sees heartbeat_at = 10:14:30 (>30 min ago)
  → Force-release A's lock
  → D acquires
```

---

## 4. Variations / Edge cases

### 4.1. Reader-only resource

```
Resource = read-only data (vd: cached CI detection)
   ↓
Many readers OK, no writer
   ↓
Simplified lock: just heartbeat + stale check
```

### 4.2. Write upgrade

```
Session A holds READ lock
A needs to WRITE (upgrade)
   ↓
Release read lock
Acquire write lock (may block)
   ↓
Risk: another writer can sneak in between
   ↓
Mitigation: atomic upgrade qua "write-intent" file
```

### 4.3. Cross-machine

Lock cơ chế này CHỈ trên 1 máy (filesystem-based).
Multi-machine = mỗi máy có lock riêng → infra-level lock cần dùng Redis/etcd (out of scope MCV3).

### 4.4. Lock file in repo (anti-pattern)

```
❌ Lock file commit vào git → conflict
✅ Lock file trong .mc-data/work/_locks/ → gitignored
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Single global lock cho mọi resource | Per-resource lock (giảm contention) |
| Không có heartbeat → stale forever | Heartbeat mỗi 30s + 30min stale check |
| Không có writer priority → starvation | Signal write-pending, block new readers |
| Retry vô hạn khi lock held | Timeout sau N giây → escalate |
| Lock file format không có timestamp | Cần check stale |
| Sleep 0.1s tight loop để check lock | Sleep ≥1s — tránh CPU burn |
| Force-release stale lock không log | Phải log để audit (debug crash) |
| Lock file commit vào git | Gitignore `.mc-data/work/_locks/` |
| 2 readers cùng update lock file | Atomic write (mv tmp) |
| Quên release lock khi skill abort | Use trap/cleanup hook |

---

## 6. Checklist áp dụng

**Khi skill share resource cross-session:**

- [ ] Identify resource cần lock (vd: base_url, DB schema, browser instance)
- [ ] Lock file ở `.mc-data/work/_locks/{resource-name}.{read,write}-lock`
- [ ] Lock format: `$SESSION_ID|$PID|$acquired_at|$heartbeat_at`
- [ ] Atomic acquire (`set -C` noclobber)
- [ ] Heartbeat daemon update mỗi 30s
- [ ] Stale check: heartbeat > 30 min → force-release + log
- [ ] Writer priority: signal write-pending → block new readers
- [ ] Trap signal: cleanup lock khi skill abort (SIGINT, SIGTERM)
- [ ] Timeout acquire (vd: 5 phút) → escalate qua CDG
- [ ] Read lock: nhiều readers concurrent
- [ ] Write lock: exclusive, wait readers release
- [ ] Test eval: simulate concurrent sessions

---

## 7. Liên kết

- **Protocol 22 (canonical):** [`.claude/skills/protocols/22-infrastructure-rw-lock.md`](../../.claude/skills/protocols/22-infrastructure-rw-lock.md)
- **Case study:** `.claude/scripts/wf-e2e-shared/global-rw-lock.sh`, `lock-daemon.sh`
- **Related patterns:**
  - [`08-auto-detect-fallback.md`](08-auto-detect-fallback.md) — Lock pattern cho CI cache
  - [`06-checkpoint-resume.md`](06-checkpoint-resume.md) — Session lock + heartbeat tương tự
- **Standard:** [`../02-standards/09-session-checkpoint.md`](../02-standards/09-session-checkpoint.md)
