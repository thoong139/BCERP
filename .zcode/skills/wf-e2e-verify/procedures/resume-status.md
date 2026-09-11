# wf-e2e-verify Orchestrator — Resume + Status Handlers

## --status

Read-only display orchestrator dashboard.

```bash
handle_status() {
  resolve_session  # find session (--session or latest --resume-style)
  
  test -f "$E2E_STATUS" || {
    echo "Session $SESSION_DIR không có e2e-status.json — chưa init hoặc corrupt"
    exit 1
  }
  
  # Read state
  FEAT_ID=$(jq -r '.feat_id' "$E2E_STATUS")
  CREATED=$(jq -r '.created_at' "$E2E_STATUS")
  CURRENT=$(jq -r '.current_step' "$E2E_STATUS")
  CONTEXT_PCT=$(jq -r '.context_estimate_pct // 0' "$E2E_STATUS")
  
  # SSOT counters
  ISSUES_OPEN=$(jq -r '[.signals[] | select(.status=="open")] | length' "$SESSION_DIR/issues.json" 2>/dev/null || echo 0)
  ISSUES_FIXED=$(jq -r '[.signals[] | select(.status=="fixed")] | length' "$SESSION_DIR/issues.json" 2>/dev/null || echo 0)
  ISSUES_TOTAL=$(jq -r '.signals | length' "$SESSION_DIR/issues.json" 2>/dev/null || echo 0)
  
  BLOCKS_BLOCKED=$(jq -r '[.blocked_tests[] | select(.status=="blocked")] | length' "$SESSION_DIR/block-test.json" 2>/dev/null || echo 0)
  BLOCKS_RESOLVED=$(jq -r '[.blocked_tests[] | select(.status=="resolved")] | length' "$SESSION_DIR/block-test.json" 2>/dev/null || echo 0)
  BLOCKS_UNBLOCKED=$(jq -r '[.blocked_tests[] | select(.status=="unblocked")] | length' "$SESSION_DIR/block-test.json" 2>/dev/null || echo 0)
  
  IMPL_PENDING=$(jq -r '[.entries[] | select(.status=="pending")] | length' "$SESSION_DIR/implement-required.json" 2>/dev/null || echo 0)
  IMPL_DONE=$(jq -r '[.entries[] | select(.status=="done")] | length' "$SESSION_DIR/implement-required.json" 2>/dev/null || echo 0)
  IMPL_SKIPPED=$(jq -r '[.entries[] | select(.status=="skipped")] | length' "$SESSION_DIR/implement-required.json" 2>/dev/null || echo 0)
  
  MANUAL_PENDING=$(jq -r '[.entries[] | select(.status=="pending")] | length' "$SESSION_DIR/manual.json" 2>/dev/null || echo 0)
  MANUAL_VERIFIED=$(jq -r '[.entries[] | select(.status=="verified")] | length' "$SESSION_DIR/manual.json" 2>/dev/null || echo 0)
  
  LOOP_COUNT=$(jq -r '.anti_loop.f6_f5_loop_count' "$E2E_STATUS")
  
  # Display
  cat <<EOF
================================================================
wf-e2e-verify Orchestrator — Status Dashboard
Session: $SESSION_DIR
FEAT-ID: $FEAT_ID
Created: $CREATED
Current step: $CURRENT
================================================================

8-Step Pipeline:
| Step | Skill          | Status      | Duration | Result |
|------|----------------|-------------|----------|--------|
$(for STEP in F1 F2 F3 F4 F5 F6 F7 F8; do
    STATUS=$(jq -r ".steps.${STEP}.status" "$E2E_STATUS")
    STARTED=$(jq -r ".steps.${STEP}.started_at // \"-\"" "$E2E_STATUS")
    COMPLETED=$(jq -r ".steps.${STEP}.completed_at // \"-\"" "$E2E_STATUS")
    SKIP_REASON=$(jq -r ".steps.${STEP}.skip_reason // \"\"" "$E2E_STATUS")
    SKILL=$(jq -r ".steps.${STEP}.skill" "$E2E_STATUS")
    
    if [ "$STATUS" = "skipped" ]; then
      printf "| %s   | %-14s | %-11s | -        | %s\n" "$STEP" "$SKILL" "$STATUS" "$SKIP_REASON"
    else
      printf "| %s   | %-14s | %-11s | -        | -\n" "$STEP" "$SKILL" "$STATUS"
    fi
done)

SSOT Counters:
- issues.json: open=$ISSUES_OPEN, fixed=$ISSUES_FIXED, total=$ISSUES_TOTAL
- block-test.json: blocked=$BLOCKS_BLOCKED, resolved=$BLOCKS_RESOLVED, unblocked=$BLOCKS_UNBLOCKED
- implement-required.json: pending=$IMPL_PENDING, done=$IMPL_DONE, skipped=$IMPL_SKIPPED
- manual.json: pending=$MANUAL_PENDING, verified=$MANUAL_VERIFIED

Anti-loop counter: f6_f5_loop_count = $LOOP_COUNT / 3
Context: ${CONTEXT_PCT}%

Next action: $(jq -r '.next_action' "$E2E_STATUS")
================================================================
STOP
EOF
  
  exit 0  # No execution
}
```

---

## --resume

Resume orchestrator pipeline từ last incomplete step.

```bash
handle_resume() {
  resolve_session
  
  test -f "$E2E_STATUS" || {
    echo "Session không có e2e-status.json — không thể resume. Hãy chạy lại từ đầu."
    exit 1
  }
  
  # Acquire lock (stale auto-release)
  acquire_lock
  
  # Read state
  CURRENT=$(jq -r '.current_step' "$E2E_STATUS")
  
  # Determine first incomplete step
  RESUME_STEP=""
  for STEP in F1 F2 F3 F4 F5 F6 F7 F8; do
    STATUS=$(jq -r ".steps.${STEP}.status" "$E2E_STATUS")
    if [ "$STATUS" != "completed" ] && [ "$STATUS" != "skipped" ]; then
      RESUME_STEP="$STEP"
      break
    fi
  done
  
  if [ -z "$RESUME_STEP" ]; then
    echo "Session đã hoàn tất hoặc tất cả steps skipped. Không có gì để resume."
    exit 0
  fi
  
  echo "Resume from step: $RESUME_STEP"
  log_event "RESUME" "$RESUME_STEP" "Resuming after interrupt"
  
  # Re-validate previous steps' outputs (PRE-GATE)
  for PREV in F1 F2 F3 F4 F5 F6 F7 F8; do
    if [ "$PREV" = "$RESUME_STEP" ]; then break; fi
    PREV_STATUS=$(jq -r ".steps.${PREV}.status" "$E2E_STATUS")
    if [ "$PREV_STATUS" = "completed" ]; then
      verify_step_outputs "$PREV" || {
        echo "WARN: Step $PREV completed nhưng outputs missing — re-run $PREV"
        update_step_status "$PREV" "pending"
        RESUME_STEP="$PREV"
        break
      }
    fi
  done
  
  # Continue orchestrate.md từ RESUME_STEP
  FROM_STEP="$RESUME_STEP"
  source orchestrate.md  # exec main flow
}
```

---

## Idempotency

- **Steps đã completed:** SKIP, KHÔNG re-spawn
- **Steps đã failed:** Re-spawn nếu user `--resume` (treat như pending)
- **Steps đã skipped:** SKIP forever (skip_reason recorded)
- **Atomic write e2e-status.json:** đảm bảo state không corrupt khi crash

---

## Standalone Mode Resume

Nếu session được tạo bởi legacy command standalone (vd: chỉ chạy F6 qua --fix), session ID có thể được resume:

```bash
# Detect standalone session
STANDALONE_STEP=$(jq -r '.standalone_step // ""' "$E2E_STATUS")

if [ -n "$STANDALONE_STEP" ]; then
  echo "Standalone session detected: $STANDALONE_STEP only"
  RESUME_STEP="$STANDALONE_STEP"
  SKIP_OTHERS=true
fi
```

---

## Lock Stale Detection

```bash
acquire_lock_with_stale_check() {
  if [ -f "$LOCK" ]; then
    AGE=$(($(date +%s) - $(stat -c %Y "$LOCK")))
    if [ "$AGE" -gt 1800 ]; then
      log_error "E008" "init" "Stale lock auto-released (age ${AGE}s)"
      rm "$LOCK"
    else
      log_error "E007" "init" "Active lock held by another process"
      echo "ERROR E007: Session đang chạy. PID lock: $(cat $LOCK). Wait hoặc abort."
      exit 1
    fi
  fi
  echo "$$:$(date +%s):wf-e2e-verify-orchestrator" > "$LOCK"
}
```

---

## Error Codes

| Code | Mô tả |
|------|-------|
| E001 | Session không tồn tại / FEAT-ID invalid |
| E007 | Lock active |
| E008 | Stale lock auto-released |
| E009 | Context >90% FORCE STOP |
