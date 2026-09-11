#!/usr/bin/env bash
# =============================================================================
# g4-integration-tests.sh — 5 integration tests cho Wave 3 G4 (v11.2.0)
# =============================================================================
# F1. Test fixture session với 5 cross-module items → detect-cross-scope đúng
# F2. Test queue append với 5 parallel calls → JSONL clean, lock không corrupt
# F3. Test orchestrator-summary render → "Follow-up Suggestions" present + count
# F4. Test backward-compat: MCV3_FIX_CROSS_SCOPE_DISABLE=true → G4 skip
# F5. Test build-id-mapping → schema valid, bridges 3 ID schemes
#
# Usage:
#   bash .claude/scripts/wf-fix-bugs/tests/g4-integration-tests.sh
#
# Exit codes:
#   0 — All tests pass
#   1 — One or more tests fail
# =============================================================================

set -u

MCV3_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
TEST_ROOT="/tmp/g4-integration-tests"
PASS=0
FAIL=0
FAILED_TESTS=()

cleanup() {
  rm -rf "$TEST_ROOT" 2>/dev/null
}
trap cleanup EXIT

setup_fresh() {
  cleanup
  mkdir -p "$TEST_ROOT"
  cd "$TEST_ROOT"
}

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_TESTS+=("$1"); echo "FAIL: $1 — $2"; }

# ─── F1: Fixture session với 5 cross-module items ────────────────────────────
test_f1() {
  setup_fresh
  local SESSION_ID="2026-05-17-test-f1-01"
  local SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$SESSION_ID"
  mkdir -p "$SESSION_DIR/phase5-triage" "$SESSION_DIR/phase6-execute"

  # Build issue-registry with 5 cross-module + 3 in-scope
  cat > "$SESSION_DIR/phase5-triage/issue-registry.json" <<'EOF'
{
  "total_issues": 8,
  "issues": [
    {"id":"QD9-RT-001","title":"In-scope issue","severity":"medium","dimension_id":"QD9","location":{"file":"apps/web/src/settings/page1.tsx"}},
    {"id":"QD9-RT-002","title":"In-scope issue 2","severity":"high","dimension_id":"QD9","location":{"file":"apps/web/src/settings/page2.tsx"}},
    {"id":"QD9-RT-003","title":"In-scope issue 3","severity":"low","dimension_id":"QD9","location":{"file":"apps/web/src/settings/utils.ts"}},
    {"id":"QD10-X-001","title":"Cross to customs","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/src/customs/shipments.tsx"}},
    {"id":"QD10-X-002","title":"Cross to finance","severity":"critical","dimension_id":"QD10","location":{"file":"apps/web/src/finance/invoices.tsx"}},
    {"id":"QD10-X-003","title":"Cross to wms","severity":"medium","dimension_id":"QD10","location":{"file":"apps/web/src/wms/inbound.tsx"}},
    {"id":"QD3-X-001","title":"Cross to tms","severity":"high","dimension_id":"QD3","location":{"file":"apps/web/src/tms/dispatch.tsx"}},
    {"id":"QD6-X-001","title":"Cross to hr","severity":"high","dimension_id":"QD6","location":{"file":"apps/web/src/hr/payroll.tsx"}}
  ]
}
EOF

  cat > "$SESSION_DIR/fix-status.json" <<'EOF'
{"scope":"module","name":"settings","phases":{},"updated_at":"2026-05-17T06:00:00Z"}
EOF

  # Run detect-cross-scope
  local out
  out=$(SESSION_DIR="$SESSION_DIR" SESSION_ID="$SESSION_ID" \
    bash "$MCV3_ROOT/.claude/scripts/wf-fix-bugs/detect-cross-scope.sh" 2>/dev/null)

  local count
  count=$(echo "$out" | jq -r '.cross_scope_count // 0')
  local trigger
  trigger=$(echo "$out" | jq -r '.should_trigger_cdg // false')

  if [ "$count" = "5" ] && [ "$trigger" = "true" ]; then
    pass "F1: 5 cross-module items detected (threshold trigger=true)"
  else
    fail "F1: expected count=5,trigger=true; got count=$count,trigger=$trigger" "see fixture"
  fi
}

# ─── F2: 5 parallel enqueue calls ────────────────────────────────────────────
test_f2() {
  setup_fresh
  mkdir -p .mc-data/work/wf-fix-bugs
  echo '[{"canonical_id":"X-001","title":"t1","reason":"file_outside_scope"}]' > items.json

  for i in 1 2 3 4 5; do
    (
      SOURCE_SESSION="parallel-f2-$i" \
      KIND="cross_scope_fix" \
      SUGGESTED_COMMAND="//wf-fix-bugs --scope=cross-module --dims=QD$i" \
      ITEMS_JSON_FILE="$(pwd)/items.json" \
      bash "$MCV3_ROOT/.claude/scripts/wf-fix-bugs/enqueue-followup.sh" >/dev/null 2>&1
    ) &
  done
  wait

  local lines
  lines=$(wc -l < .mc-data/work/wf-fix-bugs/_followup-queue.jsonl 2>/dev/null | tr -d ' ')

  if [ "$lines" = "5" ]; then
    # Verify each line is valid JSON
    local all_valid="true"
    while IFS= read -r line; do
      if ! echo "$line" | jq -e '."$schema" == "followup-queue-v1"' >/dev/null 2>&1; then
        all_valid="false"
        break
      fi
    done < .mc-data/work/wf-fix-bugs/_followup-queue.jsonl

    if [ "$all_valid" = "true" ]; then
      pass "F2: 5 parallel appends → 5 valid JSONL lines"
    else
      fail "F2: JSONL parse fail (corruption)" "lock failed"
    fi
  else
    fail "F2: expected 5 lines, got $lines" "lock race condition"
  fi
}

# ─── F3: orchestrator-summary render Follow-up Section ───────────────────────
test_f3() {
  setup_fresh
  local SESSION_ID="2026-05-17-test-f3-01"
  local SESSION_DIR="$(pwd)/.mc-data/work/wf-fix-bugs/sessions/$SESSION_ID"
  mkdir -p "$SESSION_DIR/phase5-triage" "$SESSION_DIR/phase7-verify"

  echo '{"pipeline_status":"DONE","phases":{},"updated_at":"2026-05-17T06:00:00Z"}' > "$SESSION_DIR/fix-status.json"
  echo '{"total_issues":3,"issues":[]}' > "$SESSION_DIR/phase5-triage/issue-registry.json"

  # Queue with 2 entries for this session
  mkdir -p .mc-data/work/wf-fix-bugs
  cat > .mc-data/work/wf-fix-bugs/_followup-queue.jsonl <<EOF
{"\$schema":"followup-queue-v1","queued_at":"2026-05-17T05:00:00Z","source_session":"$SESSION_ID","session_id":"$SESSION_ID","kind":"cross_scope_fix","suggested_command":"//wf-fix-bugs --scope=cross-module","items":[{"canonical_id":"X1"}],"priority":"high","status":"pending"}
{"\$schema":"followup-queue-v1","queued_at":"2026-05-17T05:01:00Z","source_session":"$SESSION_ID","session_id":"$SESSION_ID","kind":"manual_review","suggested_command":"#manual review","items":[{"canonical_id":"X2"}],"priority":"medium","status":"pending"}
{"\$schema":"followup-queue-v1","queued_at":"2026-05-17T05:02:00Z","source_session":"other-session","session_id":"other-session","kind":"cross_scope_fix","suggested_command":"//other","items":[],"priority":"low","status":"pending"}
EOF

  # Run generate-phase7-reports (from MCV3 root to find templates)
  cd "$MCV3_ROOT"
  # Backup existing queue
  local BACKUP=""
  if [ -s .mc-data/work/wf-fix-bugs/_followup-queue.jsonl ]; then
    BACKUP=".mc-data/work/wf-fix-bugs/_followup-queue.bak.$$"
    mv .mc-data/work/wf-fix-bugs/_followup-queue.jsonl "$BACKUP"
  fi
  mkdir -p .mc-data/work/wf-fix-bugs
  cp "$TEST_ROOT/.mc-data/work/wf-fix-bugs/_followup-queue.jsonl" .mc-data/work/wf-fix-bugs/

  SESSION_DIR="$SESSION_DIR" SESSION_ID="$SESSION_ID" \
  PROFILE=standard SCOPE=module NAME=test \
  DIMS_ARRAY="QD1 QD3 QD9 QD10" \
  FIXED_COUNT=2 DEFERRED_COUNT=0 FAILED_COUNT=0 \
  STATUS_PASS_FAIL=PASS PROJECT_NAME=testp \
  bash "$MCV3_ROOT/.claude/scripts/wf-fix-bugs/generate-phase7-reports.sh" >/dev/null 2>&1

  # Restore backup
  rm -f .mc-data/work/wf-fix-bugs/_followup-queue.jsonl
  [ -n "$BACKUP" ] && mv "$BACKUP" .mc-data/work/wf-fix-bugs/_followup-queue.jsonl
  cd "$TEST_ROOT"

  local summary_file="$SESSION_DIR/phase7-verify/orchestrator-summary.md"
  if [ -s "$summary_file" ]; then
    # Verify: should have section "Follow-up Suggestions" with **2** items (this session only)
    local sect
    sect=$(grep -A 10 "^## Follow-up Suggestions" "$summary_file" 2>/dev/null)
    if echo "$sect" | grep -q "Phát hiện \*\*2\*\* items" && \
       echo "$sect" | grep -q "cross_scope_fix" && \
       echo "$sect" | grep -q "manual_review"; then
      pass "F3: orchestrator-summary renders Follow-up Suggestions with correct count + filter"
    else
      fail "F3: section content mismatch" "expected 2 items, see $summary_file"
    fi
  else
    fail "F3: orchestrator-summary.md not generated" "script failed"
  fi
}

# ─── F4: Backward-compat — MCV3_FIX_CROSS_SCOPE_DISABLE=true ─────────────────
test_f4() {
  setup_fresh
  local SESSION_ID="2026-05-17-test-f4-01"
  local SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$SESSION_ID"
  mkdir -p "$SESSION_DIR/phase5-triage"

  # Build registry with many cross-module items (would normally trigger)
  cat > "$SESSION_DIR/phase5-triage/issue-registry.json" <<'EOF'
{
  "total_issues": 5,
  "issues": [
    {"id":"X1","title":"a","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/customs/a.tsx"}},
    {"id":"X2","title":"b","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/finance/b.tsx"}},
    {"id":"X3","title":"c","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/wms/c.tsx"}},
    {"id":"X4","title":"d","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/tms/d.tsx"}},
    {"id":"X5","title":"e","severity":"high","dimension_id":"QD10","location":{"file":"apps/web/hr/e.tsx"}}
  ]
}
EOF
  echo '{"scope":"module","name":"settings"}' > "$SESSION_DIR/fix-status.json"

  # Run with DISABLE=true
  local out
  out=$(MCV3_FIX_CROSS_SCOPE_DISABLE=true SESSION_DIR="$SESSION_DIR" SESSION_ID="$SESSION_ID" \
    bash "$MCV3_ROOT/.claude/scripts/wf-fix-bugs/detect-cross-scope.sh" 2>/dev/null)

  local count
  count=$(echo "$out" | jq -r '.cross_scope_count // -1')
  local scope
  scope=$(echo "$out" | jq -r '.scope // ""')

  if [ "$count" = "0" ] && [ "$scope" = "disabled" ]; then
    pass "F4: MCV3_FIX_CROSS_SCOPE_DISABLE=true → count=0, scope=disabled"
  else
    fail "F4: expected count=0,scope=disabled; got count=$count,scope=$scope" "disable flag broken"
  fi
}

# ─── F5: build-id-mapping schema validity ────────────────────────────────────
test_f5() {
  setup_fresh
  local SESSION_ID="2026-05-17-test-f5-01"
  local SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$SESSION_ID"
  mkdir -p "$SESSION_DIR/phase5-triage" "$SESSION_DIR/phase6-execute" "$SESSION_DIR/_meta"

  cat > "$SESSION_DIR/phase5-triage/issue-registry.json" <<'EOF'
{
  "total_issues": 3,
  "issues": [
    {"id":"QD9-RT-001","title":"Issue alpha","severity":"medium","dimension_id":"QD9","location":{"file":"src/a.tsx"}},
    {"id":"QD9-RT-002","title":"Issue beta","severity":"high","dimension_id":"QD9","location":{"file":"src/b.tsx"}},
    {"id":"SIG-QD10-001","title":"Issue gamma","severity":"low","dimension_id":"QD10","location":{"file":"src/c.tsx"}}
  ]
}
EOF

  cat > "$SESSION_DIR/phase5-triage/fix-plan.md" <<'EOF'
# Fix Plan

## Execution Plan

| Priority | Issue ID | Action | File(s) | Est. Time | [CDG] Markers |
|----------|----------|--------|---------|-----------|----------------|
| MEDIUM | ISS-20260517-001 | fix | src/a.tsx | 15m | — |
| HIGH | ISS-20260517-002 | fix | src/b.tsx | 30m | — |
| LOW | ISS-20260517-003 | fix | src/c.tsx | 5m | — |
EOF

  cat > "$SESSION_DIR/phase6-execute/fix-report.md" <<'EOF'
# Fix Report

| Issue ID | Title | Note |
|----------|-------|------|
| ISS-001 | Issue alpha resolved | Fixed in src/a.tsx |
| ISS-002 | Issue beta resolved | Fixed in src/b.tsx |
EOF

  # Run from MCV3 root (template path is relative)
  cd "$MCV3_ROOT"
  local sessabs="$TEST_ROOT/$SESSION_DIR"

  local out
  out=$(SESSION_DIR="$sessabs" SESSION_ID="$SESSION_ID" \
    bash "$MCV3_ROOT/.claude/scripts/wf-fix-bugs/build-id-mapping.sh" 2>/dev/null)
  local rc=$?
  cd "$TEST_ROOT"

  if [ "$rc" -ne 0 ]; then
    fail "F5: build-id-mapping exited $rc" "see stderr"
    return
  fi

  local mapping_file="$sessabs/_meta/id-mapping.json"
  if [ ! -s "$mapping_file" ]; then
    fail "F5: id-mapping.json missing" ""
    return
  fi

  # Validate schema + content
  if ! jq -e '."$schema" == "id-mapping-v1"' "$mapping_file" >/dev/null 2>&1; then
    fail "F5: schema mismatch" ""
    return
  fi
  if ! jq -e '.mappings | length == 3' "$mapping_file" >/dev/null 2>&1; then
    fail "F5: expected 3 mappings, got $(jq '.mappings | length' "$mapping_file")" ""
    return
  fi
  # Check matched_to_plan == 3
  local mp
  mp=$(jq -r '.summary.matched_to_plan' "$mapping_file")
  if [ "$mp" != "3" ]; then
    fail "F5: expected matched_to_plan=3, got $mp" ""
    return
  fi

  pass "F5: id-mapping.json valid (schema + 3 mappings + plan match)"
}

# ─── Run all tests ───────────────────────────────────────────────────────────
echo "=== G4 Integration Tests (Wave 3 v11.2.0) ==="
echo ""
test_f1
test_f2
test_f3
test_f4
test_f5
echo ""
echo "=== Results: $PASS pass, $FAIL fail ==="

if [ "$FAIL" -gt 0 ]; then
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done
  exit 1
fi

exit 0
