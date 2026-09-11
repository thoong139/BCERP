# Playwright Queue — Centralized Dispatch Protocol (v8.2.0)

## Mục đích

Tập trung tất cả Playwright jobs từ mọi agent/step vào một hàng đợi chung.
`wf-playwright-runner` xử lý tuần tự (1 job tại 1 thời điểm) — tránh xung đột
browser MCP instance. Agents enqueue và tiếp tục non-browser work; kết quả được
ghi vào session path; agent resume khi có results.

```
Agent (F2/F7/F8)
    │ cần Playwright
    ▼
enqueue_playwright_job() → queue.json (pending)
    │ set step = queued_playwright
    │ tiếp tục non-browser steps
    ▼
wf-playwright-runner (spawn riêng / --run-queue)
    │ đọc queue, process ONE job at a time
    │ gọi Playwright MCP sequentially
    │ ghi {session_dir}/playwright-results/{step}/
    ▼
wf-e2e-verify --resume
    │ F2/F7/F8 check playwright-results/{step}/completed.json
    │ load results → mark completed
    ▼
finalize
```

---

## Queue File

**Path:** `.mc-data/work/playwright-queue/queue.json`
**Scope:** Cross-session, persistent. Một queue cho toàn bộ dự án.

### Schema `playwright-queue-v1`

```json
{
  "schema": "playwright-queue-v1",
  "updated_at": "ISO-8601",
  "jobs": [
    {
      "job_id": "PQ-{YYYY-MM-DD}-{NNN}",
      "session_id": "...",
      "feat_id": "FEAT-xxx",
      "step": "F2",
      "skill": "wf-e2e-browser",
      "session_dir": ".mc-data/work/wf-e2e-verify/sessions/{id}",
      "args": "--strict-evidence --show-browser",
      "status": "pending",
      "enqueued_at": "ISO-8601",
      "started_at": null,
      "completed_at": null,
      "result_path": "{session_dir}/playwright-results/{step}",
      "error": null,
      "priority": 1
    }
  ]
}
```

**Status values:** `pending` | `running` | `done` | `failed`
**priority:** `0` = cao (re-queued sau fail), `1` = bình thường

---

## Functions

### `enqueue_playwright_job()`

```bash
enqueue_playwright_job() {
  local session_id="$1" feat_id="$2" step="$3" skill="$4" session_dir="$5" args="${6:-}"

  QUEUE_DIR=".mc-data/work/playwright-queue"
  QUEUE="$QUEUE_DIR/queue.json"
  mkdir -p "$QUEUE_DIR"

  # Init queue file nếu chưa có
  if [ ! -f "$QUEUE" ]; then
    echo '{"schema":"playwright-queue-v1","jobs":[]}' > "$QUEUE"
  fi

  # Dedup: nếu đã có job pending/running cho session+step → skip (KHÔNG enqueue lại)
  EXISTING=$(jq -r --arg s "$session_id" --arg st "$step" \
    '[.jobs[] | select(.session_id==$s and .step==$st and (.status=="pending" or .status=="running"))] | length' \
    "$QUEUE" 2>/dev/null || echo "0")

  if [ "$EXISTING" -gt 0 ]; then
    echo "ℹ️  Playwright job ${session_id}/${step} đã trong queue — bỏ qua enqueue lại"
    return 0
  fi

  # Generate job_id
  DATE=$(date -u +%Y-%m-%d)
  SEQ=$(jq -r '.jobs | length' "$QUEUE" 2>/dev/null || echo "0")
  JOB_ID="PQ-${DATE}-$(printf '%03d' $((SEQ + 1)))"

  RESULT_PATH="${session_dir}/playwright-results/${step}"
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Atomic add to queue
  jq --arg jid "$JOB_ID" --arg sid "$session_id" --arg fid "$feat_id" \
     --arg stp "$step" --arg sk "$skill" --arg sd "$session_dir" \
     --arg ar "$args" --arg rp "$RESULT_PATH" --arg now "$NOW" '
    .updated_at = $now |
    .jobs += [{
      job_id: $jid, session_id: $sid, feat_id: $fid,
      step: $stp, skill: $sk, session_dir: $sd, args: $ar,
      status: "pending", enqueued_at: $now,
      started_at: null, completed_at: null,
      result_path: $rp, error: null, priority: 1
    }]
  ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

  echo "✅ Playwright job enqueued: $JOB_ID (${feat_id}/${step})"
}
```

### `check_playwright_results()`

```bash
check_playwright_results() {
  local session_dir="$1" step="$2"
  local result_path="${session_dir}/playwright-results/${step}"
  local marker="${result_path}/completed.json"

  if [ -f "$marker" ]; then
    jq -r '.status // "unknown"' "$marker" 2>/dev/null || echo "unknown"
  else
    echo "not_found"
  fi
}
```

### `load_playwright_results()`

```bash
load_playwright_results() {
  local session_dir="$1" step="$2"
  local result_path="${session_dir}/playwright-results/${step}"

  # Copy screenshots về session screenshots/
  if [ -d "${result_path}/screenshots" ]; then
    mkdir -p "${session_dir}/screenshots"
    cp -r "${result_path}/screenshots/." "${session_dir}/screenshots/" 2>/dev/null || true
  fi

  # Copy outputs về session outputs/
  if [ -d "${result_path}/outputs" ]; then
    mkdir -p "${session_dir}/outputs"
    cp -r "${result_path}/outputs/." "${session_dir}/outputs/" 2>/dev/null || true
  fi

  echo "✅ Playwright results loaded cho ${step} từ ${result_path}"
}
```

---

## Runner Process — `process_playwright_queue()`

Được gọi bởi `wf-playwright-runner` (hoặc `wf-e2e-verify --run-queue`).
Process **ONE job at a time** (sequential), dùng Playwright MCP trực tiếp.

```bash
process_playwright_queue() {
  QUEUE=".mc-data/work/playwright-queue/queue.json"

  if [ ! -f "$QUEUE" ]; then
    echo "ℹ️  Queue trống — không có Playwright job nào cần chạy"
    return 0
  fi

  PENDING=$(jq -r '[.jobs[] | select(.status=="pending")] | length' "$QUEUE" 2>/dev/null || echo "0")
  echo "🎭 Playwright Queue Runner: ${PENDING} job(s) pending"

  while true; do
    # Lấy job pending có priority thấp nhất (sort by priority asc, enqueued_at asc)
    JOB_ID=$(jq -r '[.jobs[] | select(.status=="pending")] | sort_by(.priority, .enqueued_at) | first | .job_id // empty' "$QUEUE" 2>/dev/null)
    [ -z "$JOB_ID" ] && break

    # Mark running
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg jid "$JOB_ID" --arg now "$NOW" \
      '(.jobs[] | select(.job_id==$jid)) |= . + {status:"running", started_at:$now}' \
      "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

    # Extract job details
    JOB=$(jq -r --arg jid "$JOB_ID" '.jobs[] | select(.job_id==$jid)' "$QUEUE")
    STEP=$(echo "$JOB" | jq -r '.step')
    SKILL=$(echo "$JOB" | jq -r '.skill')
    SESSION_DIR=$(echo "$JOB" | jq -r '.session_dir')
    FEAT_ID=$(echo "$JOB" | jq -r '.feat_id')
    ARGS=$(echo "$JOB" | jq -r '.args')
    RESULT_PATH=$(echo "$JOB" | jq -r '.result_path')

    echo ""
    echo "▶ Processing: $JOB_ID — ${FEAT_ID}/${STEP} (${SKILL})"
    mkdir -p "$RESULT_PATH/screenshots" "$RESULT_PATH/outputs"

    # Spawn skill với Playwright MCP — chạy TRỰC TIẾP (không spawn agent riêng)
    # Skill được gọi ở đây chạy trong context hiện tại với Playwright MCP available
    PLAYWRIGHT_RESULT_DIR="$RESULT_PATH" \
      spawn_playwright_skill "$SKILL" "$SESSION_DIR" "$FEAT_ID" "$STEP" "$ARGS"
    SKILL_EXIT=$?

    # Ghi completed.json
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [ $SKILL_EXIT -eq 0 ]; then
      STATUS="done"
    else
      STATUS="failed"
    fi

    jq -n --arg s "$STATUS" --arg now "$NOW" --arg jid "$JOB_ID" \
      '{job_id:$jid, status:$s, completed_at:$now}' > "$RESULT_PATH/completed.json"

    # Mark queue done/failed
    ERROR_MSG=""
    [ $SKILL_EXIT -ne 0 ] && ERROR_MSG="Skill exit code $SKILL_EXIT"
    jq --arg jid "$JOB_ID" --arg s "$STATUS" --arg now "$NOW" --arg err "$ERROR_MSG" '
      (.jobs[] | select(.job_id==$jid)) |= . + {status:$s, completed_at:$now, error:($err | if . == "" then null else . end)}
    ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

    # Thông báo session owner (flag file để --resume detect)
    NOTIFY_DIR="${SESSION_DIR}/_playwright_ready"
    mkdir -p "$NOTIFY_DIR"
    echo "$JOB_ID" > "${NOTIFY_DIR}/${STEP}.done"

    echo "$([ $SKILL_EXIT -eq 0 ] && echo '✅' || echo '❌') $JOB_ID → $STATUS"
  done

  DONE=$(jq -r '[.jobs[] | select(.status=="done")] | length' "$QUEUE" 2>/dev/null || echo "0")
  FAILED=$(jq -r '[.jobs[] | select(.status=="failed")] | length' "$QUEUE" 2>/dev/null || echo "0")
  echo ""
  echo "🎭 Queue Runner hoàn tất: ${DONE} done, ${FAILED} failed"
  echo "Để apply results: chạy lại wf-e2e-verify với --resume cho từng session"
}
```

### `spawn_playwright_skill()` — Adapter

```bash
spawn_playwright_skill() {
  local skill="$1" session_dir="$2" feat_id="$3" step="$4" args="$5"

  # Override output path → PLAYWRIGHT_RESULT_DIR (đã set trước khi gọi)
  # Skill được spawn như sub-agent với context đầy đủ
  spawn_subskill "$step" "$skill" "$args \
    --session-dir=$session_dir \
    --output-dir=$PLAYWRIGHT_RESULT_DIR"

  return $?
}
```

---

## Queue Status Report

```bash
playwright_queue_status() {
  QUEUE=".mc-data/work/playwright-queue/queue.json"
  [ ! -f "$QUEUE" ] && echo "Queue không tồn tại" && return

  echo "=== Playwright Queue Status ==="
  TOTAL=$(jq -r '.jobs | length' "$QUEUE")
  PENDING=$(jq -r '[.jobs[] | select(.status=="pending")] | length' "$QUEUE")
  RUNNING=$(jq -r '[.jobs[] | select(.status=="running")] | length' "$QUEUE")
  DONE=$(jq -r '[.jobs[] | select(.status=="done")] | length' "$QUEUE")
  FAILED=$(jq -r '[.jobs[] | select(.status=="failed")] | length' "$QUEUE")

  echo "Total: $TOTAL | Pending: $PENDING | Running: $RUNNING | Done: $DONE | Failed: $FAILED"
  echo ""
  echo "Pending jobs:"
  jq -r '.jobs[] | select(.status=="pending") | "  \(.job_id) — \(.feat_id)/\(.step) (\(.skill)) enqueued: \(.enqueued_at)"' "$QUEUE" 2>/dev/null || echo "  (không có)"
}
```

---

## Resume Detection

Khi `wf-e2e-verify --resume`, F2/F7/F8 kiểm tra:

```bash
# Cờ file: {session_dir}/_playwright_ready/{STEP}.done
# Results: {session_dir}/playwright-results/{STEP}/completed.json

NOTIFY_READY="${SESSION_DIR}/_playwright_ready/${STEP}.done"
RESULT_STATUS=$(check_playwright_results "$SESSION_DIR" "$STEP")

if [ "$RESULT_STATUS" = "done" ] || [ -f "$NOTIFY_READY" ]; then
  → Load results → mark completed
elif [ "$RESULT_STATUS" = "failed" ]; then
  → Mark failed
else
  → Still queued/pending — re-queue hoặc giữ trạng thái
fi
```

---

## Error Codes

| Code | Mô tả |
|------|-------|
| E020 | Queue file corrupt (jq parse fail) — auto-reinit |
| E021 | Skill spawn fail trong runner (exit code ≠ 0) |
| E022 | Result path write fail (permission / disk) |
| E023 | Stale running job (started_at > 30 min, no heartbeat) — auto-reset to pending |
