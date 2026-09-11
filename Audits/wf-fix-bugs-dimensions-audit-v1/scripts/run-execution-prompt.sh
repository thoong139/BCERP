#!/usr/bin/env bash
# ============================================================================
# Auto-execution loop cho EXECUTION-PROMPT.md
#
# Chạy headless `claude --print` lặp lại — mỗi iteration = 1 phiên fresh
# (TAB mới thật sự, không kế thừa context phiên trước) — tới khi STOP CONDITION
# đạt hoặc vượt MAX_ITER.
#
# Usage:
#   bash plans/wf-fix-bugs-dimensions-audit-v1/scripts/run-execution-prompt.sh
#
# Env vars (override mặc định):
#   MAX_ITER=50                (số iteration tối đa)
#   ITER_TIMEOUT_SEC=5400      (90 phút/iteration)
#   MODEL=sonnet               (sonnet | opus)
#   NO_COMMIT=1                (skip auto-commit, chỉ chạy)
#
# Stop conditions (bất kỳ điều nào):
#   1. git tag plan-wf-fix-bugs-dimensions-audit-v1-DONE đã tồn tại
#   2. Iteration không update EXECUTION-PROMPT.md (stuck → dừng để debug)
#   3. claude CLI exit non-zero kèm không có thay đổi file
#   4. Reach MAX_ITER
# ============================================================================

set -o pipefail

# ---------- Config ----------
PLAN_DIR="plans/wf-fix-bugs-dimensions-audit-v1"
PROMPT_FILE="$PLAN_DIR/EXECUTION-PROMPT.md"
PROGRESS_FILE="$PLAN_DIR/progress.md"
LOG_DIR="$PLAN_DIR/logs"
DONE_TAG="plan-wf-fix-bugs-dimensions-audit-v1-DONE"

MAX_ITER="${MAX_ITER:-50}"
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

log "═══ Auto-execution started ═══"
log "  Plan dir:      $PLAN_DIR"
log "  Prompt file:   $PROMPT_FILE"
log "  Model:         $MODEL"
log "  Max iter:      $MAX_ITER"
log "  Timeout/iter:  ${ITER_TIMEOUT_SEC}s"
log "  Auto-commit:   $([ "$NO_COMMIT" = "1" ] && echo "OFF" || echo "ON")"
log "  Master log:    $MASTER_LOG"

# ---------- Autonomous prompt (fed via stdin) ----------
read -r -d '' SESSION_PROMPT <<'PROMPT_EOF' || true
Bạn đang chạy trong AUTOMATED HEADLESS MODE — 1 phiên trong chuỗi tự động execute kế hoạch
plans/wf-fix-bugs-dimensions-audit-v1/EXECUTION-PROMPT.md. KHÔNG có user trả lời câu hỏi —
mọi quyết định bạn phải tự làm.

NHIỆM VỤ CHO PHIÊN NÀY:
1. Đọc plans/wf-fix-bugs-dimensions-audit-v1/EXECUTION-PROMPT.md đầy đủ §INSTRUCTIONS, §CURRENT
   STATE, §NEXT ACTION, §TASK QUEUE.
2. Identify Current Task ở §CURRENT STATE (dòng "Current Task" và "Sub-task").
3. Lazy-load các file cần thiết cho task đó (theo §NEXT ACTION "Files cần đọc").
4. Execute task tuân thủ Phase 3 trong §INSTRUCTIONS — chạy đến khi DoD pass HOẶC gặp blocker thật.
5. CUỐI PHIÊN BẮT BUỘC update các sections theo Phase 4:
   - §TASK QUEUE: mark [x] cho task done
   - §CURRENT STATE: cập nhật Last session, Current Task (task tiếp theo), Sub-task
   - §NEXT ACTION: viết concrete steps cho phiên kế tiếp
   - §ACTIVITY LOG: append 1 row
   - §BLOCKERS: thêm nếu có
   Cũng update progress.md per-task.

QUY TẮC AUTONOMOUS (BẮT BUỘC — KHÁC BHV-001 thông thường):
- TUYỆT ĐỐI KHÔNG hỏi user xác nhận, KHÔNG hỏi clarification, KHÔNG hỏi "OK để bắt đầu?".
  Bỏ qua bước "Báo cáo user 1 dòng" trong §INSTRUCTIONS Phase 1 — phiên này không có user.
- Khi gặp ambiguity hoặc nhiều cách hiểu: tự phân tích ≥2 phương án, chọn phương án tốt nhất theo
  CORE-023 (chất lượng/correctness/security/completeness > tốc độ), GHI rationale vào §ACTIVITY
  LOG cột "Decisions/Notes". KHÔNG dừng chờ user.
- Khi gặp blocker THẬT (file thiếu không thể tạo, contract upstream sai cần sửa skill khác,
  test infra hỏng, dependency external chưa sẵn sàng): ghi đầy đủ vào §BLOCKERS với
  (a) mô tả, (b) file:line evidence, (c) đề xuất giải pháp, (d) skip-policy → rồi exit phiên.
  KHÔNG block hỏi user.
- Tuân thủ BHV-002/003/004 nguyên vẹn (Simplicity / Surgical / Goal-Driven).
- Tuân thủ Safe-Write Protocol (CORE-006) cho mọi file: read-modify-write atomic, không overwrite
  fields ngoài scope.
- 1 phiên = 1 task. KHÔNG nhảy task. KHÔNG làm thêm "tiện thể" task khác.

TASK PRIORITIZATION (nếu §CURRENT STATE.Current Task không rõ):
- Đọc §TASK QUEUE từ trên xuống, tìm checkbox [ ] đầu tiên CHƯA tick.
- Nếu task đó là Phase N của 1 dimension đang dở (vd QD7 Phase 2), làm tiếp Phase đó.
- Nếu là Stage Gate verify (G0/G1/G2/G3), chạy verify command tương ứng.

OUTPUT YÊU CẦU CUỐI PHIÊN:
- File EXECUTION-PROMPT.md đã update (dùng Edit tool, KHÔNG Write toàn bộ — tránh corrupt).
- File progress.md đã update theo per-dim phase tracker.
- Output artifact của task (vd 08-qd7-compat-audit.md cho QD7 Phase 2, accuracy-report.md cho
  Phase 3 fixtures, v.v.).
- Báo 2 dòng cuối cùng dưới dạng plain text (sẽ được capture vào log):
  "PHIEN_DONE: <mô tả ngắn task vừa làm>"
  "PHIEN_NEXT: <task kế tiếp>"

QUALITY GATE:
- DoD per Phase ở 13-definition-of-done.md PHẢI pass trước khi mark [x].
- Nếu đang giữa Phase mà hết thời gian (do timeout): GHI checkpoint chi tiết vào §NEXT ACTION
  để phiên sau resume từ điểm dừng, KHÔNG mark [x].

BẮT ĐẦU NGAY. KHÔNG hỏi xác nhận. Phiên đầu tiên = đọc file → execute → update → exit.
PROMPT_EOF

# ---------- Helper: extract Current Task line for commit msg ----------
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
    log "✅ STOP CONDITION: tag '$DONE_TAG' đã tồn tại. Dừng sau $((i-1)) iterations."
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

  # Run claude headless — feed prompt via stdin để tránh shell-escape issues
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

  # Capture last 2 status lines from claude output
  PHIEN_DONE_LINE=$(grep -m1 '^PHIEN_DONE:' "$ITER_LOG" 2>/dev/null || echo "")
  PHIEN_NEXT_LINE=$(grep -m1 '^PHIEN_NEXT:' "$ITER_LOG" 2>/dev/null || echo "")
  [[ -n "$PHIEN_DONE_LINE" ]] && log "  $PHIEN_DONE_LINE"
  [[ -n "$PHIEN_NEXT_LINE" ]] && log "  $PHIEN_NEXT_LINE"

  # Stop check 2: file không thay đổi → nghi ngờ stuck
  if cmp -s "$PROMPT_FILE" "$PROMPT_FILE.bak"; then
    log "⚠️  EXECUTION-PROMPT.md KHÔNG được cập nhật trong iteration này."
    log "    Nguyên nhân khả dĩ: claude crash/timeout/permission/no-op."
    log "    Kiểm tra log: $ITER_LOG"
    log "    Dừng để tránh infinite loop. Fix nguyên nhân rồi rerun."
    rm -f "$PROMPT_FILE.bak" "$PROGRESS_FILE.bak"
    break
  fi

  # Cleanup backups
  rm -f "$PROMPT_FILE.bak" "$PROGRESS_FILE.bak"

  # Auto-commit
  if [[ "$NO_COMMIT" != "1" ]]; then
    git add -A "$PLAN_DIR" 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
      COMMIT_MSG="auto-iter-$i: $CURRENT_TASK"
      # Truncate to 200 chars for safety
      COMMIT_MSG="${COMMIT_MSG:0:200}"
      git commit -m "$COMMIT_MSG" >> "$MASTER_LOG" 2>&1 || log "  ⚠️ Commit failed (xem master log)"
      log "  ✓ Committed: $COMMIT_MSG"
    else
      log "  (no changes to commit — chỉ logs/backups thay đổi)"
    fi
  fi

  ITER_DONE=$i

  # Re-check stop condition AFTER iteration (task có thể đã trigger DONE tag)
  if git tag --list 2>/dev/null | grep -qx "$DONE_TAG"; then
    log ""
    log "✅ STOP CONDITION đạt sau iteration $i. Plan COMPLETE."
    break
  fi
done

log ""
log "═══ Auto-execution finished ═══"
log "  Iterations done: $ITER_DONE / $MAX_ITER"
log "  Total time:      ~$(( ($(date +%s) - $(date -d "$START_TS" +%s 2>/dev/null || echo $(date +%s))) / 60 )) min"
log "  Master log:      $MASTER_LOG"

if git tag --list 2>/dev/null | grep -qx "$DONE_TAG"; then
  log "  Status:          ✅ PLAN COMPLETE"
  exit 0
elif [[ "$ITER_DONE" -eq "$MAX_ITER" ]]; then
  log "  Status:          ⚠️ Reached MAX_ITER — chưa DONE, rerun script để tiếp tục."
  exit 2
else
  log "  Status:          ⚠️ Stopped early — kiểm tra master log + iter logs."
  exit 1
fi
