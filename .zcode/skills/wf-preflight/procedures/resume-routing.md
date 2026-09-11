# Resume Routing — wf-preflight v3.0+

> Logic xử lý `--resume` và `--status` flag. Được gọi từ `session-init.md` SI.4.
> KHÔNG đọc standalone — load section cụ thể khi cần.
>
> **Phụ thuộc:** `$SESSIONS_DIR` = `.mc-data/work/wf-preflight/sessions/`
>                `$INDEX_FILE` = `.mc-data/work/wf-preflight/_index/sessions.jsonl`

---

## RR.1 — Flag Detection

```bash
FLAG_RESUME="${FLAG_RESUME:-}"       # --resume[=<SESSION_ID>]
FLAG_STATUS="${FLAG_STATUS:-false}"  # --status
SESSIONS_DIR=".mc-data/work/wf-preflight/sessions"
INDEX_FILE=".mc-data/work/wf-preflight/_index/sessions.jsonl"
```

- Nếu `$FLAG_STATUS = true` → route tới RR.6 (display history) → EXIT
- Nếu `$FLAG_RESUME` set → route tới RR.2
- Nếu không có → proceed bình thường qua session-init.md SI.5+ (fresh session)

---

## RR.2 — Discover Session

**Nếu `--resume=<SESSION_ID>` cung cấp (explicit):**
```bash
SESSION_ID="$FLAG_RESUME"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"

# Check tồn tại
test -d "$SESSION_DIR" || {
  echo "Không tìm thấy session: $SESSION_ID"
  echo "Dùng /wf-preflight --status để xem sessions hiện có."
  exit 1
}

# Load status
STATUS=$(jq -r '.status' "$SESSION_DIR/preflight-status.json" 2>/dev/null || echo "unknown")
VERDICT=$(jq -r '.verdict' "$SESSION_DIR/preflight-status.json" 2>/dev/null || echo "null")
```

Nếu `STATUS = "completed"`:
```
📋 Session $SESSION_ID đã hoàn thành (verdict: $VERDICT).

   (r) Xem report session này
   (n) Bắt đầu session mới
   (q) Hủy
```
- Chọn `r` → đọc `$SESSION_DIR/preflight-report.md` + hiển thị → EXIT
- Chọn `n` → EXIT resume routing → SI.5 (fresh session)
- Chọn `q` → EXIT

**Nếu `--resume` không có SESSION_ID (auto-discover):**
```bash
# Tìm in_progress session mới nhất
LATEST=$(grep '"status":"in_progress"' "$INDEX_FILE" 2>/dev/null \
  | tail -1 \
  | jq -r '.session_id' 2>/dev/null || echo "")

if [[ -z "$LATEST" ]]; then
  echo "Không tìm thấy session in_progress."
  echo "Dùng /wf-preflight --status để xem sessions hiện có."
  exit 1
fi

SESSION_ID="$LATEST"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"
```

---

## RR.3 — Validate Resume State

```bash
# Load checkpoint
CHECKPOINT="$SESSION_DIR/checkpoint.json"
if [[ ! -f "$CHECKPOINT" ]]; then
  echo "WARN: Checkpoint không tìm thấy cho session $SESSION_ID."
  echo "Sẽ restart từ Phase 1 (scope resolution)."
  RESUME_FROM="phase_1"
else
  RESUME_FROM=$(jq -r '.position.next_action // .position.current_phase // "phase_1"' "$CHECKPOINT")
  SCOPE_TYPE=$(jq -r '.context_summary.scope_type // "all"' "$CHECKPOINT")
  SCOPE_NAME=$(jq -r '.context_summary.scope_name // empty' "$CHECKPOINT")
fi

# Xác định thời gian heartbeat gần nhất
LOCK_FILE="$SESSION_DIR/.session.lock"
if [[ -f "$LOCK_FILE" ]]; then
  HEARTBEAT_AT=$(jq -r '.heartbeat_at // .started_at' "$LOCK_FILE" 2>/dev/null || echo "")
else
  HEARTBEAT_AT=""
fi
```

---

## RR.4 — Stale Session CDG

```bash
if [[ -n "$HEARTBEAT_AT" ]]; then
  HEARTBEAT_EPOCH=$(date -d "$HEARTBEAT_AT" +%s 2>/dev/null || \
                    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$HEARTBEAT_AT" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  AGE_MINUTES=$(( (NOW_EPOCH - HEARTBEAT_EPOCH) / 60 ))
else
  AGE_MINUTES=0
fi

STALE_THRESHOLD=${MCV3_LOCK_STALE_MINUTES:-60}

if [[ $AGE_MINUTES -gt $STALE_THRESHOLD ]]; then
```

Hiển thị CDG:
```
┌─────────────────────────────────────────────────────────┐
│  ⚠️  Session có vẻ stale                                 │
│                                                         │
│  Session:     $SESSION_ID                               │
│  Phase cuối:  $RESUME_FROM                              │
│  Không hoạt động: ${AGE_MINUTES} phút                   │
│                                                         │
│  (r) Resume từ $RESUME_FROM                             │
│  (s) Bắt đầu session mới (giữ data cũ)                  │
│  (q) Hủy                                                │
└─────────────────────────────────────────────────────────┘
```

- Chọn `r` → proceed RR.5
- Chọn `s` → EXIT resume routing → session-init.md SI.5 (fresh session)
- Chọn `q` → EXIT

CI/CD bypass: `MCV3_PREFLIGHT_RESUME_STALE_OK=1` → auto-proceed với `r`.

```bash
fi  # end stale check
```

---

## RR.5 — Restore Session State

```bash
# 1. Re-acquire session lock
LOCK_RESULT=$(bash .claude/scripts/wf-preflight/pf-acquire-lock.sh session "$SESSION_DIR" 30)
LOCK_STATUS=$(echo "$LOCK_RESULT" | jq -r '.status // .error')

if [[ "$LOCK_STATUS" != "acquired" ]]; then
  echo "Không thể acquire lock: $LOCK_RESULT"
  exit 1
fi

# 2. Restart heartbeat daemon
bash .claude/scripts/wf-preflight/pf-heartbeat.sh "$LOCK_FILE" 30 &
HEARTBEAT_PID=$!

# 3. Restore env vars từ status + checkpoint
SCOPE_TYPE=$(jq -r '.scope.type // "all"' "$SESSION_DIR/preflight-status.json")
SCOPE_NAME=$(jq -r '.scope.name // empty' "$SESSION_DIR/preflight-status.json")
HAS_FIX_FLAG=$(jq -r '.flags.fix // false' "$SESSION_DIR/preflight-status.json")
HAS_RUN_TESTS_FLAG=$(jq -r '.flags.run_tests // false' "$SESSION_DIR/preflight-status.json")

# 4. Load scores từ checkpoint partial_state
if [[ -f "$CHECKPOINT" ]]; then
  SCORE_REGISTRY=$(jq '.partial_state.scores_snapshot.registry_score' "$CHECKPOINT")
  SCORE_DOCS=$(jq '.partial_state.scores_snapshot.docs_score' "$CHECKPOINT")
  SCORE_SYNC=$(jq '.partial_state.scores_snapshot.sync_score' "$CHECKPOINT")
  SCORE_QUALITY=$(jq '.partial_state.scores_snapshot.quality_score' "$CHECKPOINT")
fi

# 5. Load issues-raw.json nếu có (tránh re-scan phases đã xong)
ISSUES_RAW_FILE="$SESSION_DIR/issues-raw.json"
if [[ -f "$ISSUES_RAW_FILE" ]]; then
  ISSUES_RAW=$(cat "$ISSUES_RAW_FILE")
else
  ISSUES_RAW="[]"
fi
```

Export tất cả variables:
```bash
export SESSION_ID SESSION_DIR SCOPE_TYPE SCOPE_NAME
export HAS_FIX_FLAG HAS_RUN_TESTS_FLAG
export SCORE_REGISTRY SCORE_DOCS SCORE_SYNC SCORE_QUALITY
export HEARTBEAT_PID
```

**Thông báo cho user:**
```
✓ Session $SESSION_ID resumed.
  Scope: $SCOPE_TYPE$([ -n "$SCOPE_NAME" ] && echo "=$SCOPE_NAME")
  Tiếp tục từ: $RESUME_FROM
```

→ Proceed tới phase chỉ định trong `$RESUME_FROM`.

---

## RR.6 — `--status` Display

```bash
# Đọc sessions.jsonl — chỉ entries "completed" + "failed"
COMPLETED=$(grep '"event":"completed"\|"event":"failed"' "$INDEX_FILE" 2>/dev/null || echo "")

if [[ -z "$COMPLETED" ]]; then
  echo "Chưa có session nào hoàn thành."
  echo "Dùng /wf-preflight để bắt đầu session mới."
  exit 0
fi

echo ""
echo "=== wf-preflight Session History ==="
echo ""
printf "%-28s %-18s %-8s %-6s %-20s\n" "Session ID" "Scope" "Verdict" "Score" "Thời gian"
printf "%-28s %-18s %-8s %-6s %-20s\n" "----" "----" "----" "----" "----"

echo "$COMPLETED" | jq -r '. | [.session_id, (.scope_type + (if .scope_name then "="+.scope_name else "" end)), (.verdict // "?"), (.overall_score|tostring // "?"), .completed_at] | @tsv' 2>/dev/null \
  | tail -10 \
  | while IFS=$'\t' read -r sid scope verdict score ts; do
      printf "%-28s %-18s %-8s %-6s %-20s\n" "$sid" "$scope" "$verdict" "$score%" "$ts"
    done

echo ""
echo "Tip: /wf-preflight --resume=$SESSION_ID    — resume session dở dang"
echo "     /wf-preflight --resume                — resume session in_progress mới nhất"
```

EXIT sau khi display.
