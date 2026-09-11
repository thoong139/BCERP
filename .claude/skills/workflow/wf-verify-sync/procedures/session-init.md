# Procedure: Session Init (v3.0)

> **Mục đích:** Khởi tạo session directory, acquire lock, start heartbeat daemon, append JSONL index.
> **Caller:** `procedures/phase0-init.md` — Step 0.0b (sau khi parse flags, trước Phase 0 main steps).
> **Output:** `$SESSION_DIR` created + `.session.lock` acquired + heartbeat daemon running + `_index/sessions.jsonl` appended.
> **Bash scripts:** `.claude/scripts/wf-verify-sync/` (prefix `vs-`) — xem `procedures/_shared/` directory.

---

## Điều kiện tiên quyết

- `$SCOPE` đã được parse từ flags (`all` | `system` | `module`)
- `$NAME` đã được parse (tên system hoặc module khi `$SCOPE != all`)
- `$HAS_RESUME_FLAG` đã được parse

---

## Step SI.1 — Generate Session ID + Collision Check

```bash
RESULT=$(bash .claude/scripts/wf-verify-sync/vs-generate-session-id.sh "$SCOPE" "$NAME")
```

Parse JSON result theo `status` field:

| status | action | Xử lý |
|--------|--------|-------|
| `"new"` | `"create"` | Tiếp tục SI.2 |
| `"stale"` | `"resume_or_replace"` | CDG (xem §CDG bên dưới) |
| `"completed"` | `"list_or_new"` | CDG (xem §CDG bên dưới) |
| `error: "session_active"` | — | **STOP E010** — session đang chạy bởi process khác |
| `error: "session_active_cross_host"` | — | **STOP E010** — session đang chạy trên host khác |

**CDG — status="stale":**
```
[!] Session stale tồn tại: $SESSION_ID (lock PID đã chết)
Chọn:
  [1] Resume từ checkpoint cũ (tiếp tục từ phase đã dừng)
  [2] Replace (bắt đầu fresh scan)
  [3] Cancel
```
→ Lưu choice vào `$RESUME_MODE` (`resume` | `replace` | `cancel`)
→ `cancel` → STOP (user initiated)
→ `replace` → rm -rf `$SESSION_DIR` → tiếp tục SI.2
→ `resume` → load checkpoint → tiếp tục phase tương ứng (xem `resume-routing.md`)

**CDG — status="completed":**
```
[i] Session này đã hoàn thành: $SESSION_ID
Chọn:
  [1] Xem report session cũ (read-only)
  [2] Chạy mới với scope khác
  [3] Cancel
```
→ `cancel` → STOP

---

## Step SI.2 — Migrate Legacy Flat Layout (one-time, v3.0)

Detect flat layout cũ (v2.x — files nằm thẳng trong `$WORK_ROOT/`):

```bash
WORK_ROOT=".mc-data/work/wf-verify-sync"
FLAT_FILES=()
for f in "verify-sync-status.json" "checkpoint.json" "ui-coverage-report.md" \
         "ui-snapshot.json" "phase-summary.md"; do
  [[ -f "$WORK_ROOT/$f" ]] && FLAT_FILES+=("$f")
done
# verify-sync-history.md GIỮ Ở top-level (KHÔNG migrate)
```

Nếu `${#FLAT_FILES[@]} > 0` VÀ `sessions/` chưa tồn tại:
```bash
LEGACY_V2_DIR="$WORK_ROOT/sessions/_legacy-v2/$(date +%s)"
mkdir -p "$LEGACY_V2_DIR"
for f in "${FLAT_FILES[@]}"; do
  mv "$WORK_ROOT/$f" "$LEGACY_V2_DIR/"
done
```

Hiển thị:
```
[i] Đã migrate flat layout v2.x → sessions/_legacy-v2/<timestamp>/
    Files moved: ${FLAT_FILES[*]}
    Note: verify-sync-history.md giữ ở top-level.
    Có thể xem lại tại: .mc-data/work/wf-verify-sync/sessions/_legacy-v2/
```

Ghi trace event `v2_to_v3_migration` (CORE-026).

**Graceful:** Nếu `sessions/` đã tồn tại HOẶC không có flat files → skip SI.2 hoàn toàn.

---

## Step SI.3 — Create Session Directory (nếu chưa tồn tại)

> **F20:** vs-generate-session-id.sh đã pre-create dir với `mkdir` atomic cho status="new".
> `mkdir -p` ở đây là safety net cho resume path (dir đã tồn tại).

```bash
SESSION_ID=$(echo "$RESULT" | jq -r '.session_id')
SESSION_DIR=".mc-data/work/wf-verify-sync/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR"
```

---

## Step SI.4 — Acquire Session Lock

> **F23 — Lock path convention:** wf-verify-sync dùng pattern `<skill>-registry.lock` cho registry lock
> (`.verify-sync-registry.lock`) và `.session.lock` trong session dir cho session lock.
> Các skills khác dùng pattern khác (`.decision-registry.lock`, `.req-registry.lock`).
> Standardization deferred to cross-cutting initiative.

```bash
LOCK_RESULT=$(bash .claude/scripts/wf-verify-sync/vs-acquire-lock.sh session "$SESSION_DIR" 30)
```

Parse theo `status`/`error`:

| Kết quả | Xử lý |
|---------|-------|
| `status: "acquired"` | Tiếp tục SI.5 |
| `error: "lock_held_alive"` | **STOP E010** — cùng host, PID còn sống |
| `error: "lock_held_cross_host"` | **STOP E011** — host khác đang giữ lock |
| Bất kỳ error khác | **STOP E012** — filesystem error |

---

## Step SI.5 — Start Heartbeat Daemon

> **F21:** Trên Windows Git Bash, `disown` không tồn tại và `|| true` swallow lỗi.
> Giải pháp: detect disown thành công, verify PID alive sau 2s, retry nếu cần.

```bash
HEARTBEAT_SPAWN_OK=false
RETRY_COUNT=0
MAX_RETRIES=2

while [[ "$HEARTBEAT_SPAWN_OK" != "true" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  if command -v nohup >/dev/null 2>&1; then
    nohup bash .claude/scripts/wf-verify-sync/vs-heartbeat.sh \
      "$SESSION_DIR/.session.lock" 30 > /dev/null 2>&1 &
    HEARTBEAT_PID=$!
  else
    bash .claude/scripts/wf-verify-sync/vs-heartbeat.sh \
      "$SESSION_DIR/.session.lock" 30 > /dev/null 2>&1 &
    HEARTBEAT_PID=$!
    # Detect disown availability on Windows Git Bash
    if command -v disown >/dev/null 2>&1; then
      disown $HEARTBEAT_PID 2>/dev/null && DISOWN_OK=true || DISOWN_OK=false
    else
      DISOWN_OK=false  # Windows — disown not available, rely on & backgrounding
    fi
    if [[ "$DISOWN_OK" == "false" ]]; then
      # Fallback: use & with PID tracking (process survives parent but won't auto-reap)
      # This is normal on Windows Git Bash — heartbeat process stays alive via &
    fi
  fi

  echo "$HEARTBEAT_PID" > "$SESSION_DIR/.heartbeat.pid"

  # Verify PID is alive after 2s (F21 guard)
  sleep 2
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    HEARTBEAT_SPAWN_OK=true
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
      warn "Heartbeat PID $HEARTBEAT_PID died immediately — retrying (attempt $RETRY_COUNT/$MAX_RETRIES)"
    fi
  fi
done

if [[ "$HEARTBEAT_SPAWN_OK" != "true" ]]; then
  warn "Heartbeat daemon failed to start after $MAX_RETRIES attempts — continuing without heartbeat"
  HEARTBEAT_PID=""
  rm -f "$SESSION_DIR/.heartbeat.pid"
fi
```

**Cleanup trap** (set trong SKILL.md entry):
```bash
trap 'bash .claude/scripts/wf-verify-sync/vs-release-lock.sh session "$SESSION_DIR"; \
      [[ -n "$HEARTBEAT_PID" ]] && kill "$HEARTBEAT_PID" 2>/dev/null || true' EXIT
```

---

## Step SI.6 — Append JSONL Index (status: in_progress)

```bash
ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg scope "$SCOPE" \
  --arg name "$NAME" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "$(hostname 2>/dev/null || echo unknown)" \
  '{
    session_id: $sid,
    scope: $scope,
    scope_name: $name,
    created_at: $ts,
    host: $host,
    status: "in_progress",
    reqs_total: 0,
    sync_rate: null,
    completed_at: null
  }')
bash .claude/scripts/wf-verify-sync/vs-index-append.sh "$ENTRY"
```

---

## Step SI.7 — Set State Variables

Sau khi SI hoàn thành, các biến sau phải có giá trị hợp lệ:

| Biến | Giá trị | Nguồn |
|------|---------|-------|
| `$SESSION_ID` | `{YYYY-MM-DD}-{scope-slug}-{NN}` | SI.1 output |
| `$SESSION_DIR` | `.mc-data/work/wf-verify-sync/sessions/$SESSION_ID` | SI.3 |
| `$LOCK_PATH` | `$SESSION_DIR/.session.lock` | SI.4 output |
| `$HEARTBEAT_PID` | PID của heartbeat daemon | SI.5 |

---

## Session Finalization (Phase 6 sẽ gọi)

Khi Phase 6 hoàn thành thành công — append completion entry vào JSONL:

```bash
DONE_ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg scope "$SCOPE" \
  --arg name "$NAME" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "$(hostname 2>/dev/null || echo unknown)" \
  --argjson total "${REQS_TOTAL:-0}" \
  --argjson rate "${SYNC_RATE:-null}" \
  '{session_id:$sid, scope:$scope, scope_name:$name,
    created_at: $ts, host:$host, status:"completed",
    reqs_total:$total, sync_rate:$rate,
    completed_at:$ts}')
bash .claude/scripts/wf-verify-sync/vs-index-append.sh "$DONE_ENTRY"
```

Sau đó release lock + kill heartbeat:
```bash
bash .claude/scripts/wf-verify-sync/vs-release-lock.sh session "$SESSION_DIR"
kill "$HEARTBEAT_PID" 2>/dev/null || true
```
