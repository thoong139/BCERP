# _shared.md — Cross-Cutting Concerns (wf-e2e-batch)

> Load file này tại Phase 0 INIT. Các phase sau chỉ load khi cần tham chiếu.

## State Variables

```bash
# Session
BATCH_ID=""                    # Format: YYYY-MM-DD-{scope}-batch-{NN}
SESSION_DIR=""                 # .mc-data/work/wf-e2e-batch/sessions/{BATCH_ID}/
REGISTRY_PATH=".mc-data/docs/_meta/req-registry.json"
WORK_DIR=".mc-data/work"

# Arguments
SCOPE=""                       # --scope=<module>
FEATS=""                       # --feats=ID1,ID2,...
MAX_PARALLEL=3                 # --max-parallel=N
DRY_RUN=false                  # --dry-run
AUTO=false                     # --auto
NO_SEED=false                  # --no-seed
ENABLE_CHAIN_ROLLBACK=false    # --enable-chain-rollback
HAS_RESUME=false               # --resume
HAS_STATUS=false               # --status

# CI
GITNEXUS_AVAILABLE=false
SERENA_AVAILABLE=false
CI_CONTEXT=""

# Pipeline state
FEAT_LIST=()                   # Array FEAT-IDs sau Phase 1
TOPOLOGY_LEVELS=()             # Array levels sau Phase 2
CURRENT_FEAT_COUNT=0           # Counter cho CF3 gate trigger
GATE_COUNTER=0                 # Số lần gate đã chạy
```

## Batch Session ID Format

```
Format: YYYY-MM-DD-{scope}-batch-{NN}
Ví dụ:  2026-05-15-fin-batch-01
        2026-05-15-manual-batch-03  (khi --feats thay vì --scope)

NN: 01-99, auto-increment nếu session ID đã tồn tại
```

## Phase 0 INIT — Procedure

```
1. Parse $ARGUMENTS:
   IF --status → load procedures/resume-status.md §status handler → STOP
   IF --resume → load procedures/resume-status.md §resume handler → CONTINUE
   ELSE → init new batch session

2. Generate BATCH_ID:
   DATE=$(date +%Y-%m-%d)
   SCOPE_SLUG=$(echo "${SCOPE:-manual}" | tr '[:upper:]' '[:lower:]')
   NN=01; while [ -d "$WORK_DIR/wf-e2e-batch/sessions/${DATE}-${SCOPE_SLUG}-batch-${NN}" ]; do
     NN=$(printf "%02d" $((10#$NN + 1)))
   done
   BATCH_ID="${DATE}-${SCOPE_SLUG}-batch-${NN}"
   SESSION_DIR="$WORK_DIR/wf-e2e-batch/sessions/$BATCH_ID"

3. Create session directory:
   mkdir -p "$SESSION_DIR"

4. Acquire lock:
   Lock file: $SESSION_DIR/.lock
   Content: { "pid": $$, "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "batch_id": "$BATCH_ID" }
   Start heartbeat daemon (update lock mtime mỗi 60s)

5. Init batch-status.json (atomic write):
   READ templates/batch-impact.template.json structure (không dùng làm status file)
   Create $SESSION_DIR/batch-status.json với:
   { "batch_id": "$BATCH_ID", "status": "running", "current_phase": "P0_INIT",
     "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "feats_total": 0,
     "feats_completed": 0, "feats_failed": 0, "feats_blocked": 0 }

6. Append _index/sessions.jsonl:
   mkdir -p "$WORK_DIR/wf-e2e-batch/_index"
   echo '{"batch_id":"'$BATCH_ID'","started_at":"...","scope":"'${SCOPE:-}'","status":"running"}' \
     >> "$WORK_DIR/wf-e2e-batch/_index/sessions.jsonl"

7. CI PRE-GATE (CORE-033):
   Na. bash .claude/scripts/ci-detect.sh → set GITNEXUS_AVAILABLE, SERENA_AVAILABLE
   Nb. bash .claude/scripts/ci-freshness-check.sh → log freshness level
   Nc. bash .claude/scripts/ci-inject-context.sh → CI_CONTEXT

8. IF AUTO=true: READ procedures/auto-resolve.md
   → spawn_auto_resolve_agent() available cho toàn bộ phase sau
   → mkdir -p "$SESSION_DIR/auto-resolve"

9. Log START:
   Append session-log.json: { "event": "START", "phase": "P0_INIT", ... }

POST-GATE P0:
  T1: SESSION_DIR exists
  T2: batch-status.json valid JSON
  T3: .lock acquired
  T4: _index/sessions.jsonl appended
  T5: IF AUTO=true → $SESSION_DIR/auto-resolve/ directory exists
```

## Atomic Write Pattern (CORE-035)

```bash
atomic_write_json() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"

  echo "$content" > "$tmp"
  if jq '.' "$tmp" > /dev/null 2>&1; then
    mv "$tmp" "$target"
  else
    rm -f "$tmp"
    log_error "E001" "Atomic write failed — invalid JSON cho $target"
    return 1
  fi
}
```

## Log Utilities

```bash
log() {
  local msg="$1"
  echo "[wf-e2e-batch] $msg"
  append_session_log "INFO" "$msg"
}

log_error() {
  local code="$1" msg="$2"
  echo "[wf-e2e-batch ERROR $code] $msg"
  append_session_log "ERROR" "[$code] $msg"
  # Append error-ledger.json
  local entry='{"code":"'$code'","message":"'"$msg"'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
  echo "$entry" >> "$SESSION_DIR/error-ledger.json"
}

append_session_log() {
  local level="$1" msg="$2"
  local entry='{"level":"'$level'","message":"'"$msg"'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
  echo "$entry" >> "$SESSION_DIR/session-log.json"
}
```

## Context Budget Check (CORE-038)

```
Kiểm tra trước mỗi phase transition:
< 65%    → Tiếp tục bình thường
65-80%   → Chuẩn bị checkpoint (ghi batch-status.json)
80-90%   → STOP sau phase hiện tại → hướng dẫn --resume
> 90%    → FORCE STOP (E004) — checkpoint bắt buộc
```

## Update batch-status.json

```bash
update_batch_status() {
  local phase="$1" status="${2:-running}"
  local current
  current=$(cat "$SESSION_DIR/batch-status.json")
  local updated
  updated=$(echo "$current" | jq \
    --arg phase "$phase" --arg status "$status" \
    '.current_phase = $phase | .status = $status | .updated_at = now | todate')
  atomic_write_json "$SESSION_DIR/batch-status.json" "$updated"
}
```
