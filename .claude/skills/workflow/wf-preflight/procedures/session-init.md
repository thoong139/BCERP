# Session Init — wf-preflight v3.0+

> Quy trình khởi tạo session: migration, --status, --resume, generate session ID,
> duplicate CDG, create session directory, acquire lock, heartbeat + JSONL index.
> Chạy TRƯỚC Phase 1 (setup). Xem `_shared.md` §Session Glossary.
>
> **KHÔNG đọc standalone** — load khi bắt đầu wf-preflight execution.

---

## Steps (SI.1 → SI.9)

### SI.1 — PRE-GATE Forensic (Protocol 10.4)

```
# T1: Registry tồn tại
test -f ".mc-data/docs/_meta/req-registry.json"

# T2: Content hợp lệ (Protocol 10.4 — check content, không chỉ file existence)
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json

# T3: Working directory đúng
test -d ".mc-data/"

# jq required (CORE)
command -v jq >/dev/null 2>&1
```

Nếu T1/T2 FAIL → STOP: "Registry chưa có requirements. Chạy `/wf-analyze-requirements` trước."
Nếu T3 FAIL → STOP (E011): "Không tìm thấy `.mc-data/` — chạy từ project root."
Nếu jq FAIL → STOP (E014): "jq là required dependency. Cài: `brew install jq` / `apt install jq` / `choco install jq`"

**Parse flags:**
```
$SCOPE_TYPE      ← --scope=all|system|module|feature (default: all)
$SCOPE_NAME      ← --name=<ID> (bắt buộc khi scope != all)
$HAS_FIX_FLAG    ← --fix (boolean)
$HAS_RUN_TESTS_FLAG ← --run-tests (boolean)
$RESUME_ARG      ← --resume[=<SESSION_ID>] (optional SESSION_ID)
$STATUS_FLAG     ← --status (boolean)
$FROM_FLAGS      ← --from-fix-bugs[=<id>], --from-verify-sync[=<id>], etc.
```

**LEGACY_MODE detection (CORE-021):**
```
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md \
              && wc -c < .mc-data/work/legacy-scan/project-context.md | \
                 awk '{exit ($1 > 500) ? 0 : 1}'
```

---

### SI.2 — Migration Check (D4)

```bash
bash .claude/scripts/wf-preflight/pf-migrate-flat-to-sessions.sh
```

Parse output JSON `{status: "migrated"|"already_migrated"|"no_v2_data"}`:
- `migrated` → log "✓ v2 flat data archived to sessions/_legacy-v2/"
- `already_migrated` → log "✓ Migration already done"
- `no_v2_data` → log "✓ No v2 data to migrate"

> preflight-history.md được GIỮ nguyên tại flat path — append-only, không session-scoped.

---

### SI.3 — Handle `--status` flag

Nếu `$STATUS_FLAG` = true:

```
Đọc .mc-data/work/wf-preflight/_index/sessions.jsonl
Filter: entries với event="completed" hoặc event="failed"
Sort: descending by created_at
Take: 10 entries mới nhất
```

**Hiển thị:**
```
=== wf-preflight Sessions ===

| Session ID                  | Scope           | Verdict | Score | Date       |
|-----------------------------|-----------------|---------|-------|------------|
| 2026-05-03-all-01           | all             | PASS    | 87%   | 2026-05-03 |
| 2026-05-02-sys-erp-01       | system=SYS-ERP  | WARN    | 74%   | 2026-05-02 |
| 2026-05-01-all-01           | all             | FAIL    | 52%   | 2026-05-01 |
...

Tổng: [N] sessions. Dùng --resume=<SESSION_ID> để xem chi tiết.
```

EXIT sau khi display (không chạy tiếp).

---

### SI.4 — Handle `--resume` flag

Nếu `$RESUME_ARG` set:

**SI.4.1 — Discover session:**
```
IF --resume=<SESSION_ID> explicitly provided:
  SESSION_ID = <SESSION_ID>
  SESSION_DIR = .mc-data/work/wf-preflight/sessions/$SESSION_ID
  test -d $SESSION_DIR → nếu không → STOP: "Session $SESSION_ID không tìm thấy"

ELSE (--resume không có ID):
  Tìm trong _index/sessions.jsonl: entry mới nhất với status="in_progress"
  Nếu không tìm thấy → STOP: "Không có session in_progress. Dùng --status để xem sessions."
  SESSION_ID = entry.session_id
  SESSION_DIR = .mc-data/work/wf-preflight/sessions/$SESSION_ID
```

**SI.4.2 — Stale check:**
```
LOCK_FILE = $SESSION_DIR/.session.lock
IF test -f $LOCK_FILE:
  HEARTBEAT_AT = jq -r '.heartbeat_at' $LOCK_FILE
  AGE_MINUTES = (NOW - HEARTBEAT_AT) / 60
  IF AGE_MINUTES > 60:
    CDG: "Session $SESSION_ID có lock stale (${AGE_MINUTES}min). Chọn hành động:"
    → [1] Tiếp tục resume (takeover lock)
    → [2] Bắt đầu session mới
    → [3] Hủy
    Nếu user chọn 2 → continue to SI.5 (fresh session)
    Nếu user chọn 3 → EXIT
    Nếu user chọn 1 → proceed to SI.4.3
```

**SI.4.3 — State restore:**
Xem `procedures/resume-routing.md` để chi tiết restore steps.
Export: `$SESSION_ID`, `$SESSION_DIR`. SKIP SI.5–SI.9 (đã có session).

---

### SI.5 — Generate Session ID (D1)

```bash
RESULT=$(bash .claude/scripts/wf-preflight/pf-generate-session-id.sh "$SCOPE_TYPE" "$SCOPE_NAME")
SESSION_ID=$(echo "$RESULT" | jq -r '.session_id')
SESSION_DIR=$(echo "$RESULT" | jq -r '.session_dir')
```

Export `$SESSION_ID`, `$SESSION_DIR` làm global state cho toàn bộ skill execution.

**Kiểm tra:** `$SESSION_ID` phải match pattern `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+-[0-9]{2}$`

---

### SI.6 — Duplicate Run CDG (P2-3)

Tìm sessions cùng scope trong _index/sessions.jsonl hôm nay:

```
TODAY = date +%Y-%m-%d
SAME_SCOPE_TODAY = filter(sessions.jsonl,
  scope_type==$SCOPE_TYPE AND scope_name==$SCOPE_NAME
  AND session_id STARTS WITH TODAY)

COMPLETED_TODAY = filter(SAME_SCOPE_TODAY, status=="completed")
IN_PROGRESS_TODAY = filter(SAME_SCOPE_TODAY, status=="in_progress")
```

**Nếu có `IN_PROGRESS_TODAY` với lock alive:**
```
CDG: "Phát hiện session đang chạy: $IN_PROGRESS_SESSION_ID. Chọn:"
→ [1] Resume session đang chạy (--resume=$IN_PROGRESS_SESSION_ID)
→ [2] Bắt đầu session mới song song
→ [3] Hủy

Nếu chọn 1 → set RESUME_ARG=$IN_PROGRESS_SESSION_ID → SI.4
Nếu chọn 3 → EXIT
Nếu chọn 2 → continue to SI.7
```

**Nếu có `COMPLETED_TODAY` (không có in_progress):**
```
CDG: "Đã chạy wf-preflight $SCOPE_TYPE scope hôm nay (session: $LAST_SESSION_ID, verdict: $LAST_VERDICT). Chạy lại?"
→ [1] Có, bắt đầu session mới
→ [2] Xem report session cũ (--status)
→ [3] Hủy

Nếu chọn 2 → hiển thị path report + EXIT
Nếu chọn 3 → EXIT
Nếu chọn 1 → continue to SI.7
```

---

### SI.7 — Create Session Directory

```bash
mkdir -p "$SESSION_DIR"
mkdir -p "$SESSION_DIR/file_snapshots"    # cho --fix rollback (Phase 6)
mkdir -p ".mc-data/work/wf-preflight/_index"
mkdir -p ".mc-data/work/wf-preflight/.locks"
```

**Initialize preflight-status.json (CORE-031: READ→POPULATE→WRITE):**
```
READ   templates/preflight-status.json
POPULATE:
  session_id    = $SESSION_ID
  host          = $(hostname)
  user          = $(whoami)
  started_at    = $(date -u +%Y-%m-%dT%H:%M:%SZ)
  scope.type    = $SCOPE_TYPE
  scope.name    = $SCOPE_NAME (null nếu scope=all)
  flags.fix     = $HAS_FIX_FLAG
  flags.run_tests = $HAS_RUN_TESTS_FLAG
  status        = "in_progress"
  verdict       = null
  phases.phase_1.status = "not_started"
WRITE  $SESSION_DIR/preflight-status.json
```

**Verify:** `jq '.' $SESSION_DIR/preflight-status.json >/dev/null`

---

### SI.8 — Acquire Session Lock

```bash
LOCK_RESULT=$(bash .claude/scripts/wf-preflight/pf-acquire-lock.sh session "$SESSION_DIR" 30)
```

Parse output:
- `{status:"acquired"}` → proceed
- `{error:"lock_held_alive", pid:N, host:H}` → CDG:
  ```
  "Không thể acquire lock cho session $SESSION_ID.
   Lock đang được giữ bởi PID $N trên host $H.
   Chọn:"
  → [1] Chờ và thử lại (dùng --resume sau khi process kia xong)
  → [2] Force takeover (chỉ khi chắc chắn process kia đã chết)
  → [3] Hủy

  Nếu chọn 1 → EXIT với hướng dẫn
  Nếu chọn 2 → bash pf-release-lock.sh session $SESSION_DIR → re-acquire
  Nếu chọn 3 → EXIT
  ```
- `{error:"lock_held_cross_host"}` → STOP: "Lock held by different host. Multi-developer conflict detected."

---

### SI.9 — Start Heartbeat + JSONL Index Entry

**Start heartbeat daemon:**
```bash
bash .claude/scripts/wf-preflight/pf-heartbeat.sh "$SESSION_DIR/.session.lock" 30 &
HEARTBEAT_PID=$!
```

Update preflight-status.json với heartbeat PID:
```
jq '.lock.heartbeat_pid = '$HEARTBEAT_PID \
   $SESSION_DIR/preflight-status.json > /tmp/pf-status-tmp.json \
   && mv /tmp/pf-status-tmp.json $SESSION_DIR/preflight-status.json
```

**Append in_progress entry to JSONL index:**
```bash
ENTRY=$(jq -n \
  --arg event "in_progress" \
  --arg sid "$SESSION_ID" \
  --arg scope_type "$SCOPE_TYPE" \
  --argjson scope_name "$([ -n "$SCOPE_NAME" ] && echo "\"$SCOPE_NAME\"" || echo "null")" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg host "$(hostname)" \
  --arg user "$(whoami)" \
  --argjson fix_req "$HAS_FIX_FLAG" \
  --argjson run_tests "$HAS_RUN_TESTS_FLAG" \
  '{event:$event,session_id:$sid,scope_type:$scope_type,scope_name:$scope_name,
    created_at:$ts,host:$host,user:$user,fix_requested:$fix_req,
    run_tests:$run_tests,status:"in_progress"}')

bash .claude/scripts/wf-preflight/pf-index-append.sh "$ENTRY"
```

---

## Output → Phase 1

Sau SI.1-SI.9, các biến sau phải được set và exported cho toàn bộ execution:

| Variable | Value |
|----------|-------|
| `$SESSION_ID` | e.g. `2026-05-03-all-01` |
| `$SESSION_DIR` | `.mc-data/work/wf-preflight/sessions/$SESSION_ID` |
| `$SCOPE_TYPE` | `all` / `system` / `module` / `feature` |
| `$SCOPE_NAME` | ID hoặc null |
| `$HAS_FIX_FLAG` | `true` / `false` |
| `$HAS_RUN_TESTS_FLAG` | `true` / `false` |
| `$LEGACY_MODE` | `true` / `false` |
| `$HEARTBEAT_PID` | PID của heartbeat daemon |

**File ready:**
- `$SESSION_DIR/preflight-status.json` — initialized, status=in_progress
- `$SESSION_DIR/.session.lock` — acquired
- `_index/sessions.jsonl` — in_progress entry appended

**Next:** `procedures/phase1-setup.md` (scope resolution + working dir setup)
