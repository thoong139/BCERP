# Phase 4: Aggregate Results

> **Load khi:** Phase 3 POST-GATE PASS.
> **Input:** Per-FEAT `e2e-status.json` (từ wf-e2e-verify), `batch-status.json`, `gate-report-*.json`
> **Output:** `batch-summary.md`, `batch-impact.json`

## PRE-GATE

```
T1: batch-status.json tồn tại + valid JSON
T2: Phase 3 đã ghi ít nhất 1 FEAT result vào batch-status.json
```

## Steps

### Step 4.1 — Thu thập kết quả tất cả FEATs

```bash
collect_feat_results() {
  local feats
  feats=$(jq -r '.feats[]' "$SESSION_DIR/feat-list.json")

  local results='[]'
  while IFS= read -r feat_id; do
    # Tìm e2e-status.json của FEAT này (từ wf-e2e-verify session)
    local e2e_session_dir
    e2e_session_dir=$(find "$WORK_DIR/wf-e2e-verify/sessions" \
      -maxdepth 1 -type d -name "batch-${BATCH_ID}-${feat_id}*" 2>/dev/null | head -1)

    if [ -z "$e2e_session_dir" ]; then
      # FEAT không có session → blocked hoặc skipped
      local entry
      entry=$(jq -n --arg fid "$feat_id" \
        '{feat_id: $fid, status: "blocked", reason: "Session không được tạo",
          scenarios_pass: 0, scenarios_fail: 0, issues_open: 0, duration_sec: 0}')
      results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
      continue
    fi

    local e2e_status_file="$e2e_session_dir/e2e-status.json"
    if [ ! -f "$e2e_status_file" ]; then
      local entry
      entry=$(jq -n --arg fid "$feat_id" \
        '{feat_id: $fid, status: "failed", reason: "e2e-status.json không tồn tại",
          scenarios_pass: 0, scenarios_fail: 0, issues_open: 0, duration_sec: 0}')
      results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
      continue
    fi

    # Parse e2e-status.json
    local all_steps_status
    all_steps_status=$(jq -r '.steps | to_entries[] | .value.status' "$e2e_status_file" 2>/dev/null)

    # Determine overall status
    local feat_status="completed"
    if echo "$all_steps_status" | grep -q "failed"; then
      feat_status="failed"
    elif echo "$all_steps_status" | grep -q "skipped"; then
      # Có step skipped nhưng không failed → partial
      feat_status="completed"
    fi

    # Count scenarios từ issues.json
    local issues_file="$e2e_session_dir/issues.json"
    local issues_open=0 issues_fixed=0 scenarios_pass=0 scenarios_fail=0
    if [ -f "$issues_file" ]; then
      issues_open=$(jq '[.[] | select(.status == "open")] | length' "$issues_file" 2>/dev/null || echo 0)
      issues_fixed=$(jq '[.[] | select(.status == "fixed")] | length' "$issues_file" 2>/dev/null || echo 0)
    fi

    # Duration từ e2e-status.json
    local duration=0
    duration=$(jq -r '.completed_at // .started_at // empty' "$e2e_status_file" 2>/dev/null | head -1)

    local entry
    entry=$(jq -n \
      --arg fid "$feat_id" \
      --arg status "$feat_status" \
      --argjson sp "$scenarios_pass" \
      --argjson sf "$scenarios_fail" \
      --argjson io "$issues_open" \
      --argjson ifi "$issues_fixed" \
      '{feat_id: $fid, status: $status,
        scenarios_pass: $sp, scenarios_fail: $sf,
        issues_open: $io, issues_fixed: $ifi,
        duration_sec: 0}')
    results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
  done <<< "$feats"

  echo "$results"
}
```

### Step 4.2 — Tính toán summary stats

```bash
compute_stats() {
  local results="$1"

  local total feats_completed feats_failed feats_blocked pass_rate
  total=$(echo "$results" | jq 'length')
  feats_completed=$(echo "$results" | jq '[.[] | select(.status == "completed")] | length')
  feats_failed=$(echo "$results" | jq '[.[] | select(.status == "failed")] | length')
  feats_blocked=$(echo "$results" | jq '[.[] | select(.status == "blocked")] | length')

  # Đếm auto-decisions nếu có
  local auto_decisions_count=0
  if [ -f "$SESSION_DIR/auto-decisions.jsonl" ]; then
    auto_decisions_count=$(grep -c '' "$SESSION_DIR/auto-decisions.jsonl" 2>/dev/null || echo 0)
  fi

  if [ "$total" -gt 0 ]; then
    pass_rate=$(( feats_completed * 100 / total ))
  else
    pass_rate=0
  fi

  # Overall batch status
  local batch_status
  if [ "$feats_blocked" -gt 0 ] || [ "$feats_failed" -gt 0 ]; then
    if [ "$feats_completed" -gt 0 ]; then
      batch_status="PARTIAL"
    else
      batch_status="FAILED"
    fi
  else
    batch_status="COMPLETED"
  fi

  jq -n \
    --argjson total "$total" \
    --argjson completed "$feats_completed" \
    --argjson failed "$feats_failed" \
    --argjson blocked "$feats_blocked" \
    --argjson rate "$pass_rate" \
    --argjson adc "$auto_decisions_count" \
    --arg status "$batch_status" \
    '{total: $total, completed: $completed, failed: $failed, blocked: $blocked,
      pass_rate: $rate, overall_status: $status, auto_decisions_count: $adc}'
}
```

### Step 4.3 — Tạo batch-summary.md (CORE-028, tiếng Việt ≤20 dòng)

```
READ template: templates/batch-summary.template.md (CORE-031)
POPULATE placeholders
WRITE: $SESSION_DIR/batch-summary.md
```

Nội dung điển hình:

```markdown
# Batch E2E Test — Tóm Tắt

**Batch ID:** {batch_id}
**Thời gian:** {started_at} → {completed_at}
**Scope:** {scope | feats list}
**Trạng thái:** COMPLETED | PARTIAL | FAILED | BLOCKED

## Kết Quả Theo FEAT

| FEAT | Trạng thái | Scenarios Pass | Scenarios Fail | Issues Open |
|------|-----------|---------------|---------------|------------|
| ... | | | | |

## Tóm Tắt

- **Tổng FEATs:** {total}
- **PASS:** {passed} ({pass_rate}%)
- **FAIL:** {failed}
- **BLOCKED:** {blocked}
- **Auto-decisions:** {auto_decisions_count} quyết định tự động{nếu > 0: " — xem auto-decisions.jsonl"}

## Hành Động Cần Thiết

{list các FEAT cần attention + lý do}
```

### Step 4.4 — Tạo batch-impact.json

```bash
create_batch_impact() {
  local results="$1"
  local stats="$2"

  # Collect gate results
  local gate_results='[]'
  for gate_file in "$SESSION_DIR"/gate-report-*.json; do
    [ -f "$gate_file" ] || continue
    gate_results=$(echo "$gate_results" | jq --argjson g "$(cat "$gate_file")" '. + [$g]')
  done

  # Collect chain rollback decisions
  local rollback_decisions='[]'
  if [ -f "$SESSION_DIR/chain-rollback-decisions.json" ]; then
    rollback_decisions=$(jq '.decisions' "$SESSION_DIR/chain-rollback-decisions.json")
  fi

  # READ template (CORE-031)
  # templates/batch-impact.template.json đã đọc trước

  local started_at
  started_at=$(jq -r '.started_at' "$SESSION_DIR/batch-status.json")
  local completed_at
  completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local content
  content=$(jq -n \
    --arg schema "e2e-batch-v1" \
    --arg bid "$BATCH_ID" \
    --arg scope "${SCOPE:-}" \
    --arg sat "$started_at" \
    --arg cat "$completed_at" \
    --argjson stats "$stats" \
    --argjson feat_results "$results" \
    --argjson gate_results "$gate_results" \
    --argjson rollback "$rollback_decisions" \
    '{
      "$schema": $schema,
      batch_id: $bid,
      scope: $scope,
      started_at: $sat,
      completed_at: $cat,
      feats_total: $stats.total,
      feats_completed: $stats.completed,
      feats_failed: $stats.failed,
      feats_blocked: $stats.blocked,
      pass_rate: $stats.pass_rate,
      overall_status: $stats.overall_status,
      auto_decisions_count: $stats.auto_decisions_count,
      feat_results: $feat_results,
      gate_results: $gate_results,
      chain_rollback_decisions: $rollback,
      audit_chain: ""
    }')

  # Compute audit_chain
  local chain
  chain=$(echo "$content" | sha256sum | awk '{print $1}')
  content=$(echo "$content" | jq --arg c "$chain" '.audit_chain = $c')

  atomic_write_json "$SESSION_DIR/batch-impact.json" "$content"
  log "batch-impact.json tạo thành công (schema e2e-batch-v1)"
}
```

### Step 4.5 — Finalize batch-status.json

```bash
finalize_batch() {
  local stats="$1"
  local current
  current=$(cat "$SESSION_DIR/batch-status.json")
  local updated
  updated=$(echo "$current" | jq \
    --argjson stats "$stats" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.status = $stats.overall_status |
     .feats_completed = $stats.completed |
     .feats_failed = $stats.failed |
     .feats_blocked = $stats.blocked |
     .completed_at = $ts |
     .current_phase = "P4_AGGREGATE_DONE"')
  atomic_write_json "$SESSION_DIR/batch-status.json" "$updated"

  # Update sessions index
  local idx="$WORK_DIR/wf-e2e-batch/_index/sessions.jsonl"
  # Append completion entry
  echo '{"batch_id":"'$BATCH_ID'","status":"'$(echo "$stats" | jq -r '.overall_status')'","completed_at":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' >> "$idx"

  # Release lock
  rm -f "$SESSION_DIR/.lock"
  log "Lock released"
}
```

## POST-GATE

```
T1: batch-summary.md tồn tại tại $SESSION_DIR/batch-summary.md
T2: batch-impact.json tồn tại + valid JSON
T3: batch-impact.json.$schema = "e2e-batch-v1"
T4: batch-impact.json.audit_chain không rỗng
```

## Display cuối batch

Sau khi POST-GATE pass, hiển thị summary:

```
================================================================
wf-e2e-batch — Batch Complete
Batch ID: {batch_id}
================================================================

Tổng: {total} FEATs
PASS: {passed} ({pass_rate}%)
FAIL: {failed}
BLOCKED: {blocked}
{nếu auto_decisions_count > 0}Auto-decisions: {auto_decisions_count} (xem auto-decisions.jsonl)

{nếu failed/blocked}
FEATs cần xem xét:
  - FIN-006: [lý do]

Xem chi tiết: {SESSION_DIR}/batch-summary.md
Xem impact: {SESSION_DIR}/batch-impact.json
================================================================
```

## Phase 4 Report (CORE-028)

```markdown
## Phase 4: Aggregate — PASS

Thời gian: {ISO-8601}
**Đã làm:** Tổng hợp kết quả {N} FEATs, tạo batch-summary.md và batch-impact.json.
**Kết quả:** {pass_count} PASS / {fail_count} FAIL / {blocked_count} BLOCKED — batch-impact.json (e2e-batch-v1)
**Tiếp theo:** Xem batch-summary.md và sửa các FEAT fail
```

## NEXT → Kết thúc batch. Chạy `/wf-e2e-verify <FEAT-ID>` cho từng FEAT fail để re-test.
