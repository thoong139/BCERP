# Procedure: Resume Routing (v3.0)

> **Purpose:** Khi `--resume` flag set, route AI tới đúng phase file dựa trên `verify-sync-status.json` trong session.
> **Caller:** `procedures/phase0-init.md` — Step 0.0c (khi `$HAS_RESUME_FLAG = true`).

---

## Step RR.1 — Discover sessions

Nếu user pass `--resume=<session_id>` → sử dụng trực tiếp `SESSION_ID = <session_id>`.

Nếu chỉ `--resume` (không có ID) → scan JSONL index:

```bash
tail -n 100 .mc-data/work/wf-verify-sync/_index/sessions.jsonl 2>/dev/null | \
  jq -sc 'group_by(.session_id) | map(max_by(.created_at)) | map(select(.status == "in_progress"))'
```

---

## Step RR.2 — Display + select session

```
IF count == 0:
  → STOP "Không có session in_progress để resume.
           Chạy /wf-verify-sync để tạo session mới."

IF count == 1:
  → Auto-select → tiếp tục RR.3

IF count > 1:
  → Hiển thị danh sách (session_id, scope, created_at)
  → AskUserQuestion: "Có [N] sessions in_progress. Chọn session_id để resume:"
```

---

## Step RR.3 — Validate session + re-bind state variables

```bash
SESSION_DIR=".mc-data/work/wf-verify-sync/sessions/$SESSION_ID"
```

Kiểm tra:
1. `test -d "$SESSION_DIR"` — directory tồn tại
2. `test -s "$SESSION_DIR/verify-sync-status.json"` — status file có content

Nếu fail → STOP E013: "Session $SESSION_ID không tồn tại hoặc status file bị mất."

Đọc state từ `$SESSION_DIR/verify-sync-status.json`:
```bash
$SCOPE          = .scope
$NAME           = .scope_name
$HAS_FIX_FLAG   = .arguments.fix
$CURRENT_PHASE  = .current_phase
```

---

## Step RR.4 — Registry fingerprint reconciliation

Đọc fingerprint đã lưu trong checkpoint:
```bash
SAVED_FP=$(jq -r '.registry_state.fingerprint // ""' "$SESSION_DIR/checkpoint.json" 2>/dev/null)
```

Recompute fingerprint hiện tại:
```bash
CURRENT_FP=$(jq -r '[.requirements[].id] | sort | join("|")' .mc-data/docs/_meta/req-registry.json 2>/dev/null || echo "")
```

So sánh:
- `SAVED_FP == CURRENT_FP` → Tiếp tục RR.5 (registry không thay đổi)
- Mismatch → **CDG:**

```
[!] Registry đã thay đổi kể từ session trước.
    Session: $SESSION_ID
    Saved:   $SAVED_FP (tóm tắt)
    Current: $CURRENT_FP (tóm tắt)
Chọn:
  [1] Full scan (bắt đầu lại từ Phase 1 với registry mới)
  [2] Partial resume (tiếp tục từ phase đã dừng, KHÔNG re-scan)
  [3] Force resume (bỏ qua kiểm tra — dùng khi biết thay đổi không ảnh hưởng)
```

→ `full_scan` → reset `$CURRENT_PHASE = 1` → RR.5 (re-acquire lock, re-scan)
→ `partial_resume` | `force_resume` → tiếp tục RR.5 với current phase

---

## Step RR.5 — Re-acquire session lock

```bash
RESULT=$(bash .claude/scripts/wf-verify-sync/vs-acquire-lock.sh session "$SESSION_DIR" 30)
LOCK_STATUS=$(echo "$RESULT" | jq -r '.status // .error')
```

| Kết quả | Xử lý |
|---------|-------|
| `status: "acquired"` | Tiếp tục RR.6 |
| `error: "lock_held_alive"` | **STOP E010** — session đang chạy trên cùng host |
| `error: "lock_held_cross_host"` | **STOP E011** — host khác đang giữ lock |
| Bất kỳ error khác | **STOP E012** — filesystem error |

---

## Step RR.6 — Restart heartbeat daemon

> **F21:** Same guard as session-init.md SI.5 — detect disown + verify PID alive.

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
    if command -v disown >/dev/null 2>&1; then
      disown $HEARTBEAT_PID 2>/dev/null && DISOWN_OK=true || DISOWN_OK=false
    else
      DISOWN_OK=false
    fi
  fi

  echo "$HEARTBEAT_PID" > "$SESSION_DIR/.heartbeat.pid"

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

---

## Step RR.7 — Route to phase file

Đọc `current_phase` từ `verify-sync-status.json`:

| `current_phase` | Action |
|-----------------|--------|
| `"phase_0"` | Continue phase0-init.md từ Step 0.1 (vars đã re-bound) |
| `"phase_1"` | Read `phase1-scan.md` |
| `"phase_2"` | Read `phase2-analyze.md` |
| `"phase_3"` | Read `phase3-ui-coverage.md` |
| `"phase_4"` | Check `$HAS_FIX_FLAG` → đọc `phase4-fix.md` hoặc jump Phase 5 |
| `"phase_5"` | Read `phase5-crossval.md` |
| `"phase_6"` | Read `phase6-report.md` |
| `"completed"` | AskUserQuestion: "Session đã hoàn thành. Tạo session mới hay cần review kết quả?" |

---

## Step RR.8 — Append trace event (CORE-026)

```bash
echo "{\"event\":\"RESUME\",\"skill\":\"wf-verify-sync\",\"session_id\":\"$SESSION_ID\",\"resumed_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"from_phase\":\"$CURRENT_PHASE\"}" \
  >> .mc-data/work/_trace/session-log.json
```
