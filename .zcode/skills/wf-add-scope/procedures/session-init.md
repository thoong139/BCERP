# Procedure: Session Init (v3.0)

> **Mục đích:** Khởi tạo session directory, acquire lock, start heartbeat daemon, append JSONL index.
> **Caller:** `procedures/phase0-context.md` — Step 0.1 (sau khi parse flags, trước Phase 0 main).
> **Output:** `$SESSION_DIR` created + `.session.lock` acquired + heartbeat daemon running + `_index/sessions.jsonl` appended.
> **Bash scripts:** `.claude/scripts/wf-add-scope/` (prefix `as-`) — xem `_shared.md §3.5`.

---

## Điều kiện tiên quyết

- `$SYSTEM_ID` đã được parse từ flags (phase0-context.md Step 0.4)
- `$LEGACY_MODE` đã được detect (phase0-context.md Step 0.6 hoặc `as-detect-legacy.sh`)
- `$MODE` đã được xác định (`from-mapping` | `modules-list` | `interactive` | `from-scan`)
- `$DRY_RUN` đã được parse

---

## Step SI.1 — Generate Session ID + Collision Check

```bash
RESULT=$(bash .claude/scripts/wf-add-scope/as-generate-session-id.sh "$SYSTEM_ID")
```

Parse JSON result theo `status` field:

| status | action | Xử lý |
|--------|--------|-------|
| `"new"` | `"create"` | Tiếp tục SI.3 |
| `"stale"` | `"resume_or_replace"` | CDG (xem §CDG bên dưới) |
| `"completed"` | `"list_or_new_system"` | CDG (xem §CDG bên dưới) |
| `error: "session_active"` | — | **STOP E010** — session đang chạy bởi process khác |

**CDG — status="stale":**
```
[!] Session stale tồn tại: $SESSION_ID (lock PID đã chết)
Chọn:
  [1] Resume từ checkpoint cũ (tiếp tục từ phase đã dừng)
  [2] Replace (xóa session cũ, bắt đầu lại)
  [3] Cancel
```
→ Lưu choice vào `$RESUME_MODE` (`resume` | `replace` | `cancel`)
→ `cancel` → STOP (user initiated)
→ `replace` → rm -rf `$SESSION_DIR` → tiếp tục SI.3
→ `resume` → load `$SESSION_DIR/checkpoint.json` → tiếp tục phase tương ứng (xem `resume-routing.md`)

**CDG — status="completed":**
```
[i] Session này đã hoàn thành: $SESSION_ID ($prev_status)
Chọn:
  [1] Xem report (read-only)
  [2] Chạy lại với system khác (--system=<other_id>)
  [3] Cancel
```
→ `cancel` → STOP

---

## Step SI.2 — Migrate Legacy Flat Layout (one-time, v3.0)

Detect flat layout cũ (trước v3.0 — files nằm thẳng trong `$WORK_ROOT/`):

```bash
FLAT_FILES=()
for f in "add-scope-status.json" "scope-spec.json" "add-scope-plan.md" "dry-run-diff.md"; do
  [[ -f ".mc-data/work/wf-add-scope/$f" ]] && FLAT_FILES+=("$f")
done
```

Nếu `${#FLAT_FILES[@]} > 0` VÀ `sessions/` chưa tồn tại:
```bash
LEGACY_V2_DIR=".mc-data/work/wf-add-scope/sessions/_legacy-v2/$(date +%s)"
mkdir -p "$LEGACY_V2_DIR"
for f in "${FLAT_FILES[@]}"; do
  mv ".mc-data/work/wf-add-scope/$f" "$LEGACY_V2_DIR/"
done
# Log trace event
```

Hiển thị:
```
[i] Đã migrate flat layout v2.0 → sessions/_legacy-v2/<timestamp>/
    Files moved: ${FLAT_FILES[*]}
    Có thể xem lại tại: .mc-data/work/wf-add-scope/sessions/_legacy-v2/
```

Ghi trace event `v2_to_v3_migration` (CORE-026).

**Graceful:** Nếu cả `sessions/` đã tồn tại lẫn không có flat files → skip bước này.

---

## Step SI.3 — Create Session Directory

```bash
SESSION_ID=$(echo "$RESULT" | jq -r '.session_id')
SESSION_DIR=".mc-data/work/wf-add-scope/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR"
```

---

## Step SI.4 — Acquire Session Lock

```bash
LOCK_RESULT=$(bash .claude/scripts/wf-add-scope/as-acquire-lock.sh session "$SESSION_DIR" 30)
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

```bash
nohup bash .claude/scripts/wf-add-scope/as-heartbeat.sh "$SESSION_DIR/.session.lock" 30 \
  > /dev/null 2>&1 &
HEARTBEAT_PID=$!
echo "$HEARTBEAT_PID" > "$SESSION_DIR/.heartbeat.pid"
```

**Fallback** nếu `nohup` không có (Git Bash Windows có thể thiếu):
```bash
bash .claude/scripts/wf-add-scope/as-heartbeat.sh "$SESSION_DIR/.session.lock" 30 &
HEARTBEAT_PID=$!
```

**Cleanup trap** (set trong SKILL.md entry):
```bash
trap 'bash .claude/scripts/wf-add-scope/as-release-lock.sh session "$SESSION_DIR"; \
      kill "$HEARTBEAT_PID" 2>/dev/null || true' EXIT
```

---

## Step SI.6 — Append JSONL Index (status: in_progress)

```bash
ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg sys "$SYSTEM_ID" \
  --arg mode "$MODE" \
  --argjson legacy "$LEGACY_MODE" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "$(hostname 2>/dev/null || echo unknown)" \
  '{
    session_id: $sid,
    target_system: $sys,
    mode: $mode,
    legacy_mode: $legacy,
    created_at: $ts,
    host: $host,
    status: "in_progress",
    modules_added: 0,
    features_added: 0,
    completed_at: null
  }')
bash .claude/scripts/wf-add-scope/as-index-append.sh "$ENTRY"
```

---

## Step SI.7 — Set State Variables

Sau khi SI hoàn thành, các biến sau phải có giá trị hợp lệ:

| Biến | Giá trị | Nguồn |
|------|---------|-------|
| `$SESSION_ID` | `{YYYY-MM-DD}-{sys-slug}` | SI.1 output |
| `$SESSION_DIR` | `.mc-data/work/wf-add-scope/sessions/$SESSION_ID` | SI.3 |
| `$LOCK_PATH` | `$SESSION_DIR/.session.lock` | SI.4 output |
| `$HEARTBEAT_PID` | PID của heartbeat daemon | SI.5 |

---

## Session Finalization (Phase 6)

Khi Phase 6 hoàn thành thành công — cập nhật JSONL index entry:

```bash
# Update entry trong sessions.jsonl (append update entry — không edit in-place)
DONE_ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg sys "$SYSTEM_ID" \
  --arg mode "$MODE" \
  --argjson legacy "$LEGACY_MODE" \
  --arg created "$(jq -r '.created_at' "$SESSION_DIR/.heartbeat.pid" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "$(hostname 2>/dev/null || echo unknown)" \
  --argjson mods "$MODULES_ADDED" \
  --argjson feats "$FEATURES_ADDED" \
  '{session_id:$sid, target_system:$sys, mode:$mode, legacy_mode:$legacy,
    created_at:$created, host:$host, status:"completed",
    modules_added:($mods|tonumber), features_added:($feats|tonumber),
    completed_at:$ts}')
bash .claude/scripts/wf-add-scope/as-index-append.sh "$DONE_ENTRY"
```

Sau đó release lock:
```bash
bash .claude/scripts/wf-add-scope/as-release-lock.sh session "$SESSION_DIR"
kill "$HEARTBEAT_PID" 2>/dev/null || true
```
