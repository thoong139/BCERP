#!/usr/bin/env bash
# ============================================================================
# Auto-execution loop cho EXECUTION-PROMPT.md — wf-fix-bugs Audit v2
#
# Chạy headless `claude --print` lặp lại — mỗi iteration = 1 phiên fresh
# (không kế thừa context phiên trước) — tới khi STOP CONDITION đạt hoặc vượt MAX_ITER.
#
# Usage:
#   bash Audits/wf-fix-bugs-Audit-v2/scripts/run-execution-prompt.sh
#
# Env vars:
#   MAX_ITER=30                (số iteration tối đa, default 30)
#   ITER_TIMEOUT_SEC=5400      (90 phút/iteration)
#   MODEL=sonnet               (sonnet | opus)
#   NO_COMMIT=1                (skip auto-commit)
# ============================================================================

set -o pipefail

# ---------- Config ----------
AUDIT_DIR="Audits/wf-fix-bugs-Audit-v2"
PROMPT_FILE="$AUDIT_DIR/EXECUTION-PROMPT.md"
PROGRESS_FILE="$AUDIT_DIR/progress.md"
LOG_DIR="$AUDIT_DIR/logs"
DONE_TAG="audit-wf-fix-bugs-v2-DONE"

MAX_ITER="${MAX_ITER:-30}"
ITER_TIMEOUT_SEC="${ITER_TIMEOUT_SEC:-5400}"
MODEL="${MODEL:-sonnet}"
NO_COMMIT="${NO_COMMIT:-0}"

# ---------- Pre-flight ----------
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERR: $PROMPT_FILE không tồn tại" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERR: 'claude' CLI không có trong PATH" >&2
  exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "ERR: 'timeout' (GNU coreutils) không có. Cài Git Bash hoặc WSL." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

START_TS=$(date +%Y%m%d-%H%M%S)
MASTER_LOG="$LOG_DIR/master-$START_TS.log"

log() {
  local msg="$*"
  echo "[$(date +%H:%M:%S)] $msg" | tee -a "$MASTER_LOG"
}

log "═══ Auto-execution started — Audit v2 ═══"
log "  Audit dir:    $AUDIT_DIR"
log "  Prompt file:  $PROMPT_FILE"
log "  Model:        $MODEL"
log "  Max iter:     $MAX_ITER"
log "  Timeout/iter: ${ITER_TIMEOUT_SEC}s"
log "  Auto-commit:  $([ "$NO_COMMIT" = "1" ] && echo "OFF" || echo "ON")"
log "  Master log:   $MASTER_LOG"

# ---------- Autonomous prompt ----------
read -r -d '' SESSION_PROMPT <<'PROMPT_EOF' || true
Bạn đang chạy trong AUTOMATED HEADLESS MODE — 1 phiên trong chuỗi tự động execute audit
Audits/wf-fix-bugs-Audit-v2/EXECUTION-PROMPT.md. KHÔNG có user trả lời câu hỏi —
mọi quyết định bạn phải tự làm.

NHIỆM VỤ CHO PHIÊN NÀY:
1. Đọc Audits/wf-fix-bugs-Audit-v2/EXECUTION-PROMPT.md đầy đủ §INSTRUCTIONS, §CURRENT
   STATE, §NEXT ACTION, §TASK QUEUE.
2. Đọc Audits/wf-fix-bugs-Audit-v2/audit-checklist.md nếu cần tham chiếu checkpoint.
3. Identify Current Task ở §CURRENT STATE (dòng "Current Task" và "Sub-task").
4. Lazy-load các file cần thiết cho task đó (theo §NEXT ACTION "Files cần đọc").
5. Execute task — kiểm tra code thực tế, grep patterns, validate schemas, đọc procedures.
6. Ghi findings vào `Audits/wf-fix-bugs-Audit-v2/findings/<file>.md` như mô tả trong task.
7. CUỐI PHIÊN BẮT BUỘC update:
   - §TASK QUEUE: mark [x] cho task done
   - §CURRENT STATE: cập nhật Last session, Current Task, Sub-task
   - §NEXT ACTION: viết concrete steps cho phiên kế tiếp
   - §ACTIVITY LOG: append 1 row
   - §BLOCKERS: thêm nếu có
   - progress.md: update per-task log + CP coverage tracker

QUY TẮC AUTONOMOUS (BẮT BUỘC):
- TUYỆT ĐỐI KHÔNG hỏi user xác nhận, KHÔNG hỏi clarification.
- Khi gặp ambiguity: tự phân tích ≥2 phương án, chọn theo CORE-023 (chất lượng > tốc độ),
  GHI rationale vào §ACTIVITY LOG.
- Khi gặp blocker THẬT: ghi §BLOCKERS với (a) mô tả, (b) evidence file:line,
  (c) đề xuất giải pháp, (d) skip-policy → exit.
- Tuân thủ BHV-002/003/004 (Simplicity / Surgical / Goal-Driven).
- 1 phiên = 1 task. KHÔNG nhảy task.

OUTPUT YÊU CẦU CUỐI PHIÊN:
- EXECUTION-PROMPT.md đã update (dùng Edit tool).
- progress.md đã update (dùng Edit tool).
- Findings file tại `Audits/wf-fix-bugs-Audit-v2/findings/<file>.md`.
- 2 dòng cuối:
  "PHIEN_DONE: <mô tả ngắn task vừa làm>"
  "PHIEN_NEXT: <task kế tiếp>"

BẮT ĐẦU NGAY. KHÔNG hỏi xác nhận.
PROMPT_EOF

# ---------- Helper ----------
extract_current_task() {
  awk -F'\\|' '/\*\*Current Task\*\*/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3);
    gsub(/\*\*/, "", $3);
    print $3;
    exit
  }' "$PROMPT_FILE" | head -c 180
}

# ---------- Main loop ----------
ITER_DONE=0
for i in $(seq 1 "$MAX_ITER"); do
  # Stop check 1: tag DONE
  if git tag --list 2>/dev/null | grep -qx "$DONE_TAG"; then
    log "STOP CONDITION: tag '$DONE_TAG' đã tồn tại. Dừng sau $((i-1)) iterations."
    break
  fi

  ITER_TS=$(date +%Y%m%d-%H%M%S)
  ITER_LOG="$LOG_DIR/iter-$(printf '%03d' "$i")-$ITER_TS.log"
  CURRENT_TASK=$(extract_current_task)
  [[ -z "$CURRENT_TASK" ]] && CURRENT_TASK="(unknown)"

  log ""
  log "═══ Iteration $i — $ITER_TS ═══"
  log "  Current Task: $CURRENT_TASK"
  log "  Iter log:     $ITER_LOG"

  # Backup before run
  cp "$PROMPT_FILE" "$PROMPT_FILE.bak"
  [[ -f "$PROGRESS_FILE" ]] && cp "$PROGRESS_FILE" "$PROGRESS_FILE.bak"

  # Run claude headless
  ITER_START=$(date +%s)
  set +e
  echo "$SESSION_PROMPT" | timeout "$ITER_TIMEOUT_SEC" claude \
    --print \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    > "$ITER_LOG" 2>&1
  EXIT_CODE=$?
  set -e
  ITER_END=$(date +%s)
  ITER_DUR=$((ITER_END - ITER_START))

  log "  Exit code:    $EXIT_CODE"
  log "  Duration:     ${ITER_DUR}s"

  # Capture status lines
  PHIEN_DONE_LINE=$(grep -m1 '^PHIEN_DONE:' "$ITER_LOG" 2>/dev/null || echo "")
  PHIEN_NEXT_LINE=$(grep -m1 '^PHIEN_NEXT:' "$ITER_LOG" 2>/dev/null || echo "")
  [[ -n "$PHIEN_DONE_LINE" ]] && log "  $PHIEN_DONE_LINE"
  [[ -n "$PHIEN_NEXT_LINE" ]] && log "  $PHIEN_NEXT_LINE"

  # Stop check 2: prompt file không thay đổi → stuck
  if cmp -s "$PROMPT_FILE" "$PROMPT_FILE.bak"; then
    log "WARNING: EXECUTION-PROMPT.md KHÔNG được cập nhật."
    log "  Nguyên nhân khả dĩ: claude crash/timeout/permission/no-op."
    log "  Kiểm tra: $ITER_LOG"
    log "  Dừng để tránh infinite loop. Fix rồi rerun."
    rm -f "$PROMPT_FILE.bak" "$PROGRESS_FILE.bak"
    break
  fi

  rm -f "$PROMPT_FILE.bak" "$PROGRESS_FILE.bak"

  # Auto-commit
  if [[ "$NO_COMMIT" != "1" ]]; then
    git add -A "$AUDIT_DIR" 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
      COMMIT_MSG="auto-audit-v2-iter-$i: $CURRENT_TASK"
      COMMIT_MSG="${COMMIT_MSG:0:200}"
      git commit -m "$COMMIT_MSG" >> "$MASTER_LOG" 2>&1 || log "  WARNING: Commit failed (xem master log)"
      log "  Committed: $COMMIT_MSG"
    else
      log "  (no changes to commit)"
    fi
  fi

  ITER_DONE=$i

  # Re-check stop condition after iteration
  if git tag --list 2>/dev/null | grep -qx "$DONE_TAG"; then
    log ""
    log "STOP CONDITION đạt sau iteration $i. Plan COMPLETE."
    break
  fi
done

log ""
log "═══ Auto-execution finished ═══"
log "  Iterations done: $ITER_DONE / $MAX_ITER"
log "  Master log:      $MASTER_LOG"

if git tag --list 2>/dev/null | grep -qx "$DONE_TAG"; then
  log "  Status:          PLAN COMPLETE"
  exit 0
elif [[ "$ITER_DONE" -eq "$MAX_ITER" ]]; then
  log "  Status:          Reached MAX_ITER — rerun script để tiếp tục."
  exit 2
else
  log "  Status:          Stopped early — kiểm tra master log + iter logs."
  exit 1
fi
