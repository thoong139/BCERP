# Resume & Status Handlers (wf-e2e-batch)

> **Load khi:** user dùng `--resume` hoặc `--status`.

## --status Handler

```
Đọc $WORK_DIR/wf-e2e-batch/_index/sessions.jsonl → lấy 5 sessions gần nhất
Hoặc: tìm sessions/ dir sort theo modified time

Hiển thị:

================================================================
wf-e2e-batch — Status Dashboard
================================================================

Sessions gần đây:
| Batch ID                           | Scope | Status    | FEATs | Pass | Fail | Blocked |
|------------------------------------|-------|-----------|-------|------|------|---------|
| 2026-05-15-fin-batch-01            | fin   | COMPLETED | 5     | 5    | 0    | 0       |
| 2026-05-15-sales-batch-01          | sales | PARTIAL   | 8     | 6    | 1    | 1       |
| 2026-05-15-manual-batch-01         | -     | RUNNING   | 3     | 1    | 0    | 0       |

Session đang chạy (nếu có):
  Batch ID: 2026-05-15-manual-batch-01
  Phase hiện tại: P3_EXECUTE (Level 2/3)
  FEATs hoàn thành: 1/3
  Gate checks: 0/1

Để resume: /wf-e2e-batch --resume --scope=...
================================================================
STOP (không tiếp tục)
```

## --resume Handler

### Bước 1: Phát hiện session cần resume

```bash
find_resumable_session() {
  # Tìm session có status = running hoặc paused_at_gate
  local idx="$WORK_DIR/wf-e2e-batch/_index/sessions.jsonl"

  if [ ! -f "$idx" ]; then
    log_error "E003" "Không có session index — chạy batch mới"
    return 1
  fi

  # Lấy session running gần nhất
  local latest_running
  latest_running=$(grep '"status":"running"' "$idx" | tail -1 | jq -r '.batch_id' 2>/dev/null)

  if [ -z "$latest_running" ]; then
    echo "Không có session running. Danh sách sessions gần đây:"
    tail -5 "$idx" | jq -r '.batch_id + " (" + .status + ")"'
    return 1
  fi

  echo "$latest_running"
}
```

### Bước 2: Stale lock check

```bash
check_stale_lock() {
  local session_dir="$1"
  local lock_file="$session_dir/.lock"

  if [ ! -f "$lock_file" ]; then
    return 0  # Không có lock → OK để resume
  fi

  # Lock age check (>30 min → stale)
  local lock_mtime
  lock_mtime=$(stat -f %m "$lock_file" 2>/dev/null || stat -c %Y "$lock_file" 2>/dev/null)
  local now
  now=$(date +%s)
  local age=$(( now - lock_mtime ))

  if [ "$age" -gt 1800 ]; then  # 30 min
    log "Lock stale ($age giây) — auto-release"
    rm -f "$lock_file"
    return 0
  else
    log_error "E003" "Session lock active (${age}s). Batch khác đang chạy?"
    return 1
  fi
}
```

### Bước 3: Load checkpoint và route

```bash
resume_session() {
  local batch_id="$1"
  SESSION_DIR="$WORK_DIR/wf-e2e-batch/sessions/$batch_id"

  if [ ! -d "$SESSION_DIR" ]; then
    log_error "E003" "Session directory không tồn tại: $SESSION_DIR"
    return 1
  fi

  check_stale_lock "$SESSION_DIR" || return 1

  # Đọc batch-status.json
  local status_file="$SESSION_DIR/batch-status.json"
  if [ ! -f "$status_file" ]; then
    log_error "E003" "batch-status.json không tồn tại"
    return 1
  fi

  BATCH_ID="$batch_id"
  local current_phase
  current_phase=$(jq -r '.current_phase' "$status_file")

  log "Resuming batch $batch_id từ phase $current_phase"

  # Re-acquire lock
  local lock_content
  lock_content=$(jq -n \
    --arg pid "$$" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg bid "$BATCH_ID" \
    '{pid: ($pid | tonumber), resumed_at: $ts, batch_id: $bid}')
  echo "$lock_content" > "$SESSION_DIR/.lock"

  # Route đến phase cần resume
  case "$current_phase" in
    "P0_INIT"|"P1_DISCOVER")
      log "Resume từ Phase 1"
      # Load feat-list hoặc re-run Phase 1
      if [ -f "$SESSION_DIR/feat-list.json" ]; then
        log "feat-list.json đã có — skip Phase 1, resume Phase 2"
        # CONTINUE Phase 2
      else
        # Re-run Phase 1
      fi
      ;;
    "P2_DEPENDENCY")
      log "Resume từ Phase 2"
      if [ -f "$SESSION_DIR/dependency-matrix.json" ]; then
        log "dependency-matrix.json đã có — skip Phase 2, resume Phase 3"
        # CONTINUE Phase 3
      else
        # Re-run Phase 2
      fi
      ;;
    "P3_EXECUTE")
      log "Resume từ Phase 3 — tiếp tục dispatch FEATs còn lại"
      # Load feat_results từ batch-status.json
      # Xác định FEATs chưa chạy
      local completed_feats
      completed_feats=$(jq -r '[.feat_results // {} | to_entries[] | select(.value.status != null) | .key] | .[]' \
        "$status_file" 2>/dev/null)
      log "FEATs đã hoàn thành: $completed_feats"
      # Skip completed FEATs trong Phase 3 loop
      ;;
    "P4_AGGREGATE"*)
      log "Resume từ Phase 4"
      # Re-run aggregate với data có sẵn
      ;;
    *)
      log_error "E003" "Unknown phase để resume: $current_phase"
      return 1
      ;;
  esac
}
```

### Bước 4: Re-validate PRE-GATE trước khi tiếp tục

```
Sau khi xác định phase tiếp theo:
  - Re-run PRE-GATE của phase đó
  - Nếu PRE-GATE fail → WARN + hỏi user có muốn re-run từ phase trước không
  - Nếu PASS → continue execution
```

## Dry-Run Mode

```
IF --dry-run:
  1. Chạy Phase 1 (discover FEATs)
  2. Chạy Phase 2 (build dependency matrix)
  3. Hiển thị topology plan:

  === DRY RUN — Topology Plan ===
  Batch scope: {scope}
  FEATs tìm được: {count}

  Topology Levels:
  Level 1 (không có dependency): FIN-008, FIN-010
  Level 2 (depend level 1):      FIN-006 → FIN-008
  Level 3 (depend level 2):      FIN-011 → FIN-006

  Dispatch plan:
  - Level 1: FIN-008, FIN-010 (parallel, max 3)
  - Level 2: FIN-006 (sau khi FIN-008 pass)
  - Level 3: FIN-011 (sau khi FIN-006 pass)

  Ước tính thời gian: ~{N * 45}min (giả định 45min/FEAT)

  Để chạy thật: /wf-e2e-batch {args} (bỏ --dry-run)
  ===============================
  STOP — không dispatch
```
