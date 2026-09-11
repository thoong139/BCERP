# wf-e2e-verify Orchestrator — Main Orchestration

## Main Flow

```
1. PRE-GATE — validate FEAT-ID, registry, sub-skills exist
2. Init session (or resume)
3. **Start cross-session lock daemon** (v7.2.0+) — heartbeat 30s, auto-release stale
4. Parse flags — call legacy-flags.md để map legacy
5. Determine entry step (--from-step or default F1)
6. Sequential spawn F1 → F2 → [F3] → [F4] → F5 → [F6] → F7 → F8
7. POST-VERIFY mỗi step
8. Anti-loop check (F6↔F5)
9. Finalize: orchestrator-summary.md + phase-summary.md
10. **Stop lock daemon + release_all_session_locks**
```

---

## Step 0 — Init Cross-Session Lock Daemon (v7.2.0+)

Trước khi spawn bất kỳ sub-skill nào, orchestrator BẮT BUỘC start heartbeat daemon cho R/W locks:

```bash
# Ngay sau Init session
mkdir -p "$SESSION_DIR/_locks"
bash .claude/scripts/wf-e2e-shared/lock-daemon.sh start "$SESSION_ID" "$SESSION_DIR"

# Mark trong e2e-status.json để sub-skills biết daemon đã start (không double-start)
jq --arg pid "$(cat $SESSION_DIR/_locks/global-lock-daemon.pid)" '
  .lock_daemon = {
    pid: ($pid | tonumber),
    started_by_orchestrator: true,
    started_at: $now
  }
' --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$E2E_STATUS" > "$E2E_STATUS.tmp" \
  && mv "$E2E_STATUS.tmp" "$E2E_STATUS"

log_event "LOCK_DAEMON_START" "init" "Heartbeat 30s, stale 120s, wait timeout 600s"
```

> Sub-skills check `started_by_orchestrator=true` trong meta file để SKIP start daemon riêng.

---

## Step-by-Step Execution

### Step F0 (mandatory — infra-check)

```bash
log_event "START" "F0" "Spawning wf-e2e-infra-check"
update_step_status "F0" "running"

# Load từ: procedures/phase0-infra-check.md (nếu tồn tại)
# Kiểm tra: backend health, frontend health, Playwright MCP, DB connection

INFRA_STATUS=$(check_infra_health)  # → ok | blocked

if [ "${INFRA_STATUS:-ok}" != "ok" ]; then
  mark_session_blocked "BLOCKED_INFRA" "E011-E014"
  update_step_status "F0" "blocked"
  log_error "E011" "F0" "Infra check FAIL — pipeline blocked"
  finalize_orchestrator "blocked"
  exit 1
fi

update_step_status "F0" "completed"
log_event "COMPLETE" "F0" "Infra check passed"
```

### Step F0a (mandatory — wf-e2e-finding)

```bash
log_event "START" "F0a" "Spawning wf-e2e-finding"
update_step_status "F0a" "running"

EXTRA_FLAGS=""
[ "${AUTO:-false}" = "true" ] && EXTRA_FLAGS+=" --auto"

spawn_subskill "F0a" "wf-e2e-finding" "$EXTRA_FLAGS"

if verify_step_outputs "F0a"; then
  update_step_status "F0a" "completed"
  FINDINGS_COUNT=$(ls "$SESSION_DIR/findings/"*.md 2>/dev/null | wc -l)
  # Cập nhật findings_count trong e2e-status.json
  jq --argjson c "$FINDINGS_COUNT" '.steps.F0a.findings_count = $c' "$E2E_STATUS" > "$E2E_STATUS.tmp"
  mv "$E2E_STATUS.tmp" "$E2E_STATUS"
  log_event "COMPLETE" "F0a" "Finding outputs verified ($FINDINGS_COUNT files)"
else
  update_step_status "F0a" "failed"
  log_error "E016" "F0a" "F0a outputs missing after spawn"
  finalize_orchestrator "failed"
  exit 1
fi

# G4: Context Budget Checkpoint Mandatory sau F0a (CORE-038)
# WHY mandatory: F0a tạo ra findings lớn (8 files + cross-module map). F1 live-test tốn context nhiều hơn nữa.
# Checkpoint ở đây giải phóng context để F1-F8 có đủ budget — tránh bị force-stop giữa chừng.
# WHY threshold 512KB (≈50% estimate): findings thường 50-200KB mỗi file. 8 files × 100KB = ~800KB
# nhưng chỉ portion được load vào context. 512KB là conservative threshold an toàn.

findings_size=$(du -sb "${SESSION_DIR}/findings/" 2>/dev/null | cut -f1 || echo "0")
threshold=$((512 * 1024))  # 512KB

if [ "$findings_size" -gt "$threshold" ]; then
  log_event "CHECKPOINT" "F0a" "Findings size ${findings_size}B > threshold ${threshold}B — context checkpoint"
  save_checkpoint

  if [ "${AUTO:-false}" = "false" ]; then
    echo ""
    echo "=========================================="
    echo "G4: Context Budget Checkpoint"
    echo "F0a hoàn tất. Findings: $((findings_size/1024))KB (ngưỡng: $((threshold/1024))KB)."
    echo ""
    echo "Đề xuất: Giải phóng context trước khi chạy F1 live-test."
    echo "  /clear"
    echo "  /wf-e2e-verify $FEAT_ID --session=$SESSION_ID --resume"
    echo "=========================================="
    finalize_orchestrator "checkpoint_required"
    exit 0
  else
    # --auto mode: không hỏi user, tiếp tục (log cảnh báo)
    log_event "WARN" "F0a" "G4: --auto mode, context $((findings_size/1024))KB > threshold — continuing without checkpoint"
  fi
else
  log_event "INFO" "F0a" "G4: findings_size $((findings_size/1024))KB <= threshold $((threshold/1024))KB — context OK, continue"
fi
```

### Step F0b (conditional — seed-manifest)

```bash
SEED_REQ="$SESSION_DIR/seed-requirements.json"

if [ -f "$SEED_REQ" ] && [ "${NO_SEED:-false}" = "false" ]; then
  log_event "START" "F0b" "Spawning wf-e2e-seed-manifest"
  update_step_status "F0b" "running"

  spawn_subskill "F0b" "wf-e2e-seed-manifest" ""

  if verify_step_outputs "F0b"; then
    update_step_status "F0b" "completed"
    log_event "COMPLETE" "F0b" "Seed manifest completed"
  else
    update_step_status "F0b" "failed"
    log_error "E017" "F0b" "Seed manifest fail"
    mark_session_blocked "BLOCKED_SEED" "E017-E018"
    finalize_orchestrator "blocked"
    exit 1
  fi
else
  SKIP_REASON="no seed-requirements.json"
  [ "${NO_SEED:-false}" = "true" ] && SKIP_REASON="--no-seed flag"
  update_step_status "F0b" "skipped" "skip_reason" "$SKIP_REASON"
  log_event "SKIP" "F0b" "Seed manifest skipped: $SKIP_REASON"
fi
```

### Step F1 (mandatory)

```bash
log_event "START" "F1" "Spawning wf-e2e-test"
update_step_status "F1" "running"

EXTRA_FLAGS=""
[ "${AUTO:-false}" = "true" ] && EXTRA_FLAGS+=" --auto"

spawn_subskill "F1" "wf-e2e-test" "$EXTRA_FLAGS"

if verify_step_outputs "F1"; then
  update_step_status "F1" "completed"
  log_event "COMPLETE" "F1" "F1 outputs verified"
else
  update_step_status "F1" "failed"
  log_error "E003" "F1" "F1 outputs missing after spawn"
  # F1 mandatory → exit
  finalize_orchestrator "failed"
  exit 1
fi
```

### Step F2 (default ON; only skipped with explicit --skip=F2)

```bash
# v8.2.0: Queue-based Playwright dispatch.
# F2 không block pipeline — enqueue job, tiếp tục non-browser steps.
# Khi --resume và results có sẵn → load results → completed.
PLAYWRIGHT_OK=$(jq -r '.checks.playwright_mcp.status // "unknown"' "$SESSION_DIR/infra-blockers.json" 2>/dev/null || echo "unknown")
source .claude/skills/workflow/wf-e2e-batch/procedures/playwright-queue.md

if echo "${SKIP_LIST:-}" | grep -q "F2"; then
  update_step_status "F2" "skipped" "skip_reason" "--skip=F2"
  log_event "SKIP" "F2" "User explicit --skip=F2"
elif [ "$PLAYWRIGHT_OK" != "ok" ]; then
  # E013: Playwright MCP không available → BLOCK toàn bộ Playwright (không phải skip)
  log_error "E013" "F2" "BLOCKED: Playwright MCP không available (infra-blockers.json.checks.playwright_mcp)"
  update_step_status "F2" "blocked_no_playwright" "skip_reason" "E013: Playwright không available — restart Claude Code MCP để enable, rồi re-run với --resume"
  log_event "WARN" "F2" "⚠ F2 BLOCKED_NO_PLAYWRIGHT. F7/F8 sẽ cùng bị block. Browser coverage = 0%."
else
  F2_RESULT=$(check_playwright_results "$SESSION_DIR" "F2")
  if [ "$F2_RESULT" = "done" ]; then
    # Results đã có từ playwright-runner → load và mark completed
    log_event "RESULT_LOADED" "F2" "Playwright results available — loading"
    load_playwright_results "$SESSION_DIR" "F2"
    update_step_status "F2" "completed"
    log_event "COMPLETE" "F2" "F2 Playwright results loaded"
  elif [ "$F2_RESULT" = "failed" ]; then
    log_error "E003" "F2" "Playwright job failed (xem playwright-results/F2/completed.json)"
    update_step_status "F2" "failed"
  else
    # Enqueue — pipeline KHÔNG bị block, tiếp tục non-browser steps
    EXTRA_FLAGS=""
    [ "${SHOW_BROWSER:-false}" = "true" ] && EXTRA_FLAGS+=" --show-browser"
    [ "${MOBILE:-false}" = "true" ] && EXTRA_FLAGS+=" --mobile"
    [ "${STRICT_EVIDENCE:-true}" = "true" ] && EXTRA_FLAGS+=" --strict-evidence"
    enqueue_playwright_job "$SESSION_ID" "$FEAT_ID" "F2" "wf-e2e-browser" "$SESSION_DIR" "$EXTRA_FLAGS"
    update_step_status "F2" "queued_playwright" "skip_reason" "Enqueued — chạy /wf-playwright-runner, rồi --resume"
    log_event "QUEUED" "F2" "F2 browser job enqueued vào playwright-queue"
  fi
fi
```

### Step F3 (CONDITIONAL)

```bash
# Check skip rules
source skip-rules.md  # function: should_run_f3()

if should_run_f3; then
  log_event "START" "F3" "block-test có entries blocked"
  update_step_status "F3" "running"
  
  spawn_subskill "F3" "wf-e2e-unblock" ""
  
  if verify_step_outputs "F3"; then
    update_step_status "F3" "completed"
  else
    update_step_status "F3" "failed"
  fi
else
  update_step_status "F3" "skipped" "skip_reason" "block-test empty"
  log_event "SKIP" "F3" "No blocked entries"
fi
```

### Step F4 (CONDITIONAL)

```bash
if should_run_f4; then
  log_event "START" "F4" "implement-required có pending"
  update_step_status "F4" "running"
  
  EXTRA_FLAGS=""
  [ -n "${MAX_IMPL_ITEMS:-}" ] && EXTRA_FLAGS+=" --max-items=$MAX_IMPL_ITEMS"
  
  spawn_subskill "F4" "wf-e2e-implement" "$EXTRA_FLAGS"
  
  if verify_step_outputs "F4"; then
    update_step_status "F4" "completed"
    # Mark retest_after_impl=true
    jq '.summary.retest_after_impl = true' "$E2E_STATUS" > "$E2E_STATUS.tmp"
    mv "$E2E_STATUS.tmp" "$E2E_STATUS"
  else
    update_step_status "F4" "failed"
  fi
else
  update_step_status "F4" "skipped" "skip_reason" "implement-required empty"
  log_event "SKIP" "F4" "No pending implement"
fi
```

### Step F5 (mandatory if F4 ran OR PENDING markers)

```bash
RETEST_NEEDED=false

# Check if F4 ran
F4_STATUS=$(jq -r '.steps.F4.status' "$E2E_STATUS")
[ "$F4_STATUS" = "completed" ] && RETEST_NEEDED=true

# Check PENDING markers in reports
if grep -qE "PENDING|SKIP|⬜" "$SESSION_DIR/findings"/*.md 2>/dev/null; then
  RETEST_NEEDED=true
fi

# Check fixed signals retest_count=0
FIXED_NEED_RETEST=$(jq -r '[.signals[] | select(.status=="fixed" and (.retest_count // 0) == 0)] | length' "$SESSION_DIR/issues.json" 2>/dev/null || echo 0)
[ "$FIXED_NEED_RETEST" -gt 0 ] && RETEST_NEEDED=true

if [ "$RETEST_NEEDED" = "true" ]; then
  log_event "START" "F5" "Retest needed"
  update_step_status "F5" "running"
  
  EXTRA_FLAGS="--scope=all"
  # v7.1.0: --no-playwright deprecated, KHÔNG pass xuống F5 nữa
  
  spawn_subskill "F5" "wf-e2e-retest" "$EXTRA_FLAGS"
  
  if verify_step_outputs "F5"; then
    update_step_status "F5" "completed"
  else
    update_step_status "F5" "failed"
  fi
else
  update_step_status "F5" "skipped" "skip_reason" "No pending items"
  log_event "SKIP" "F5" "Nothing to retest"
fi
```

### Step F6 (CONDITIONAL + anti-loop)

```bash
if should_run_f6; then
  LOOP_COUNT=$(jq -r '.anti_loop.f6_f5_loop_count' "$E2E_STATUS")
  
  if [ "$LOOP_COUNT" -ge 3 ]; then
    log_event "SKIP" "F6" "Anti-loop max 3 vòng F6↔F5 reached"
    log_error "E004" "F6" "Anti-loop reached"
    # ESCALATE
    update_step_status "F6" "skipped" "skip_reason" "anti_loop_max"
  else
    log_event "START" "F6" "Fix loop (iteration $((LOOP_COUNT + 1)))"
    update_step_status "F6" "running"
    
    EXTRA_FLAGS=""
    [ "${AUTO:-false}" = "true" ] && EXTRA_FLAGS+=" --auto"
    
    spawn_subskill "F6" "wf-e2e-fix" "$EXTRA_FLAGS"
    
    if verify_step_outputs "F6"; then
      update_step_status "F6" "completed"
      
      # Increment counter
      jq --argjson c "$((LOOP_COUNT + 1))" '.anti_loop.f6_f5_loop_count = $c' "$E2E_STATUS" > "$E2E_STATUS.tmp"
      mv "$E2E_STATUS.tmp" "$E2E_STATUS"
      
      # Re-run F5 sau F6
      log_event "RESTART" "F5" "Re-running F5 sau F6 fix loop"
      # Recurse F5 step
      # (set F5 status back to "running" + spawn again)
    else
      update_step_status "F6" "failed"
    fi
  fi
else
  update_step_status "F6" "skipped" "skip_reason" "issues.json empty"
  log_event "SKIP" "F6" "No open issues"
fi
```

### Step F7 (default ON; only skipped with explicit --skip=F7)

```bash
# v8.2.0: Queue-based Playwright dispatch — check results trước, enqueue nếu chưa có.
if echo "${SKIP_LIST:-}" | grep -q "F7"; then
  update_step_status "F7" "skipped" "skip_reason" "--skip=F7"
elif [ "${PLAYWRIGHT_OK:-unknown}" != "ok" ]; then
  log_error "E013" "F7" "BLOCKED: Playwright MCP không available — xem F2 BLOCKED_NO_PLAYWRIGHT"
  update_step_status "F7" "blocked_no_playwright" "skip_reason" "E013: Playwright không available"
else
  F7_RESULT=$(check_playwright_results "$SESSION_DIR" "F7")
  if [ "$F7_RESULT" = "done" ]; then
    load_playwright_results "$SESSION_DIR" "F7"
    update_step_status "F7" "completed"
    log_event "COMPLETE" "F7" "F7 Playwright results loaded"
  elif [ "$F7_RESULT" = "failed" ]; then
    update_step_status "F7" "failed"
    log_error "E003" "F7" "Playwright job failed"
  else
    EXTRA_FLAGS=""
    [ "${SHOW_BROWSER:-false}" = "true" ] && EXTRA_FLAGS+=" --show-browser"
    [ "${MOBILE:-false}" = "true" ] && EXTRA_FLAGS+=" --mobile"
    [ "${STRICT_EVIDENCE:-true}" = "true" ] && EXTRA_FLAGS+=" --strict-evidence"
    enqueue_playwright_job "$SESSION_ID" "$FEAT_ID" "F7" "wf-e2e-scenario" "$SESSION_DIR" "$EXTRA_FLAGS"
    update_step_status "F7" "queued_playwright" "skip_reason" "Enqueued — chạy /wf-playwright-runner, rồi --resume"
    log_event "QUEUED" "F7" "F7 scenario job enqueued vào playwright-queue"
  fi
fi
```

### Step F8 (default ON; only skipped with explicit --skip=F8)

```bash
# v8.2.0: Queue-based Playwright dispatch — check results trước, enqueue nếu chưa có.
if echo "${SKIP_LIST:-}" | grep -q "F8"; then
  update_step_status "F8" "skipped" "skip_reason" "--skip=F8"
elif [ "${PLAYWRIGHT_OK:-unknown}" != "ok" ]; then
  log_error "E013" "F8" "BLOCKED: Playwright MCP không available — xem F2 BLOCKED_NO_PLAYWRIGHT"
  update_step_status "F8" "blocked_no_playwright" "skip_reason" "E013: Playwright không available"
else
  F8_RESULT=$(check_playwright_results "$SESSION_DIR" "F8")
  if [ "$F8_RESULT" = "done" ]; then
    load_playwright_results "$SESSION_DIR" "F8"
    update_step_status "F8" "completed"
    log_event "COMPLETE" "F8" "F8 Playwright results loaded"
  elif [ "$F8_RESULT" = "failed" ]; then
    update_step_status "F8" "failed"
    log_error "E003" "F8" "Playwright job failed"
  else
    EXTRA_FLAGS=""
    [ "${SHOW_BROWSER:-false}" = "true" ] && EXTRA_FLAGS+=" --show-browser"
    [ "${MOBILE:-false}" = "true" ] && EXTRA_FLAGS+=" --mobile"
    [ "${STRICT_EVIDENCE:-true}" = "true" ] && EXTRA_FLAGS+=" --strict-evidence"
    enqueue_playwright_job "$SESSION_ID" "$FEAT_ID" "F8" "wf-e2e-demo" "$SESSION_DIR" "$EXTRA_FLAGS"
    update_step_status "F8" "queued_playwright" "skip_reason" "Enqueued — chạy /wf-playwright-runner, rồi --resume"
    log_event "QUEUED" "F8" "F8 demo job enqueued vào playwright-queue"
  fi
fi
```

---

### Step FQ — Process Playwright Queue (auto nếu có queued jobs)

```bash
# v8.2.0: Nếu có queued_playwright steps VÀ Playwright MCP available → process queue ngay.
# Điều này cho phép single-session run hoàn chỉnh khi Playwright OK.
QUEUED_COUNT=$(jq -r '[.steps[] | select(.status=="queued_playwright")] | length' "$E2E_STATUS")

if [ "$QUEUED_COUNT" -gt 0 ] && [ "${PLAYWRIGHT_OK:-unknown}" = "ok" ]; then
  log_event "START" "FQ" "Processing $QUEUED_COUNT queued Playwright job(s)"
  update_step_status "FQ" "running" 2>/dev/null || true

  source .claude/skills/workflow/wf-e2e-batch/procedures/playwright-queue.md
  process_playwright_queue

  # Sau khi runner xong: re-check và load results cho từng queued step
  for QUEUED_STEP in F2 F7 F8; do
    STEP_STATUS=$(jq -r --arg s "$QUEUED_STEP" '.steps[$s].status // "unknown"' "$E2E_STATUS")
    if [ "$STEP_STATUS" = "queued_playwright" ]; then
      RESULT=$(check_playwright_results "$SESSION_DIR" "$QUEUED_STEP")
      if [ "$RESULT" = "done" ]; then
        load_playwright_results "$SESSION_DIR" "$QUEUED_STEP"
        update_step_status "$QUEUED_STEP" "completed"
        log_event "RESULT_APPLIED" "$QUEUED_STEP" "Queue results applied"
      elif [ "$RESULT" = "failed" ]; then
        update_step_status "$QUEUED_STEP" "failed"
        log_error "E003" "$QUEUED_STEP" "Playwright job failed in queue runner"
      fi
    fi
  done

  update_step_status "FQ" "completed" 2>/dev/null || true
  log_event "COMPLETE" "FQ" "Queue processed, steps updated"
elif [ "$QUEUED_COUNT" -gt 0 ]; then
  # Playwright MCP không available — chỉ thông báo, KHÔNG fail pipeline
  log_event "INFO" "FQ" "⚡ $QUEUED_COUNT Playwright job(s) đang trong queue. Playwright MCP không available hiện tại."
fi
```

---

## Finalize

```bash
finalize_orchestrator() {
  local OVERALL_STATUS="$1"  # success | partial | failed
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Aggregate summary
  TOTAL_STEPS=$(jq -r '.steps | length' "$E2E_STATUS")
  COMPLETED=$(jq -r '[.steps[] | select(.status=="completed")] | length' "$E2E_STATUS")
  SKIPPED=$(jq -r '[.steps[] | select(.status=="skipped")] | length' "$E2E_STATUS")
  FAILED=$(jq -r '[.steps[] | select(.status=="failed")] | length' "$E2E_STATUS")
  BLOCKED=$(jq -r '[.steps[] | select(.status=="blocked_no_playwright")] | length' "$E2E_STATUS")
  QUEUED=$(jq -r '[.steps[] | select(.status=="queued_playwright")] | length' "$E2E_STATUS")
  
  ISSUES_TOTAL=$(jq -r '.summary.issues_open + .summary.issues_fixed' "$SESSION_DIR/issues.json" 2>/dev/null || echo 0)
  IMPL_DONE=$(jq -r '[.entries[] | select(.status=="done")] | length' "$SESSION_DIR/implement-required.json" 2>/dev/null || echo 0)
  
  # Update e2e-status final
  jq --arg s "$OVERALL_STATUS" --arg now "$ISO" '
    .current_step = "finalize" |
    .next_action = "DONE" |
    .completed_at = $now |
    .overall_status = $s
  ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
  mv "$E2E_STATUS.tmp" "$E2E_STATUS"
  
  # Write orchestrator-summary.md from template
  cp .claude/skills/workflow/wf-e2e-verify/templates/orchestrator-summary.template.md "$ORCH_SUMMARY"
  # Populate placeholders ({SESSION_ID}, {FEAT_ID}, ...) via sed

  # AUTO mode: tự generate QA checklist từ manual.json — KHÔNG hỏi user
  if [ "${AUTO:-false}" = "true" ]; then
    MANUAL_COUNT=$(jq -r '.pending | length' "$SESSION_DIR/manual.json" 2>/dev/null || echo 0)
    if [ "$MANUAL_COUNT" -gt 0 ]; then
      {
        echo "# QA Checklist — Manual Verification Required"
        echo ""
        echo "Session: ${SESSION_ID} | Feature: ${FEAT_ID}"
        echo ""
        echo "## Items cần QA manual (${MANUAL_COUNT} tổng)"
        echo ""
        jq -r '.pending[] | "- [ ] **\(.id // "?")** \(.description // "no desc") (\(.reason // "manual-only"))"' \
          "$SESSION_DIR/manual.json" 2>/dev/null || echo "- (không đọc được manual.json)"
      } > "$SESSION_DIR/outputs/qa-checklist.md"
      log_event "AUTO_QA_CHECKLIST" "finalize" "Generated qa-checklist.md with ${MANUAL_COUNT} items (auto mode)"
    fi
  fi
  
  # Write phase-summary.md (CORE-028)
  cat > "$SESSION_DIR/phase-summary.md" <<EOF
# Phase Summary — wf-e2e-verify v8.1.0

**Feature:** ${FEAT_ID}
**Session:** ${SESSION_ID}
**Hoàn thành:** ${ISO}
**Trạng thái tổng thể:** ${OVERALL_STATUS}

**Đã làm:** Chạy pipeline E2E 11 bước. ${COMPLETED}/${TOTAL_STEPS} bước hoàn tất, ${SKIPPED} bước bỏ qua (theo skip-rules), ${BLOCKED} bước bị block (Playwright không available), ${QUEUED} bước đang trong queue, ${FAILED} bước fail.

**Kết quả chính:**
- Tổng issues phát hiện: ${ISSUES_TOTAL}
- Implement-required đã xử lý: ${IMPL_DONE}
- Screenshots evidence: $(ls "$SESSION_DIR/screenshots/" 2>/dev/null | wc -l) files
- Browser steps blocked: ${BLOCKED} (Playwright MCP chưa khởi động)
- Browser steps queued: ${QUEUED} (đang chờ playwright-runner xử lý)

**Outputs:**
- findings/ (${FINDINGS_COUNT} files: BR, DB, API, UI, RBAC, State, Cross-Module, AC)
- outputs/test-scenario.md + user-guide.md (filled bởi F7+F8 nếu không bị block)
- block-test.json, issues.json, implement-required.json, manual.json (SSOT)
- screenshots/ (browser, scenario, demo)
$([ "${AUTO:-false}" = "true" ] && echo "- outputs/qa-checklist.md (auto-generated từ manual.json)" || echo "")

**Tiếp theo:** $([ "$BLOCKED" -gt 0 ] && echo "⚠ ${BLOCKED} step(s) bị block — restart Claude Code với Playwright MCP plugin. " || echo "")$([ "$QUEUED" -gt 0 ] && echo "⚡ ${QUEUED} Playwright job(s) đang trong queue — chạy /wf-playwright-runner để process, sau đó /wf-e2e-verify ${FEAT_ID} --session=${SESSION_ID} --resume để apply results. " || echo "")Review orchestrator-summary.md để đánh giá kết quả. Nếu còn block manual → QA team execute outputs/qa-checklist.md. Nếu code chưa stable → /wf-fix-bugs hoặc /wf-e2e-verify --resume.
EOF
  
  # Cleanup per-session lock
  rm -f "$LOCK"

  # Stop cross-session R/W lock daemon — auto release_all_session_locks
  bash .claude/scripts/wf-e2e-shared/lock-daemon.sh stop "$SESSION_DIR" 2>/dev/null || true
  log_event "LOCK_DAEMON_STOP" "finalize" "Released all global R/W locks"

  log_event "FINALIZE" "orchestrator" "Status: $OVERALL_STATUS"
}
```

---

## Crash Recovery — Stale Lock Auto-Release

Nếu orchestrator crash giữa chừng (kill -9, OOM, etc.):

- Daemon process bị mồ côi → tự exit khi phát hiện parent PID không còn alive → `release_all_session_locks` tự động.
- Nếu cả daemon cũng chết → entry trong global lock file có `last_heartbeat` > 120s → `cleanup_stale_locks` (gọi mỗi acquire) tự xóa.
- Session khác đang `acquire_reader_lock` / `acquire_writer_lock` → poll mỗi 5s, sau 600s timeout → ESCALATE AskUserQuestion (Retry/Force release/Cancel).

Lệnh user có thể chạy thủ công để force unlock 1 session bị treo:

```bash
bash .claude/scripts/wf-e2e-shared/global-rw-lock.sh release_all_session_locks "<STUCK_SESSION_ID>"
```
