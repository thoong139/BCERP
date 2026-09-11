#!/usr/bin/env bash
# wf-fix-common.test.sh — Smoke test cho 6 helper categories trong wf-fix-common.sh
#
# Cách chạy (từ repo root):
#   bash .claude/scripts/tests/wf-fix-common.test.sh
#
# Yêu cầu: bash >= 4, jq, coreutils

set -uo pipefail  # KHÔNG set -e: muốn run hết tests rồi mới fail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUT="$SCRIPT_DIR/wf-fix-common.sh"

[ -f "$SUT" ] || { echo "FATAL: cannot find $SUT" >&2; exit 1; }

# Sandbox: dùng tmp dir riêng cho từng test, không touch real .mc-data/
TMP_ROOT="$(mktemp -d -t wf-fix-common-test-XXXXXX)"
trap "rm -rf '$TMP_ROOT'" EXIT

# Override base dir để test không pollute repo
export MCV3_FIX_BUGS_BASE_DIR="$TMP_ROOT/wf-fix-bugs"
export MCV3_LOCK_STALE_MINUTES=1   # 1 phút để test stale takeover nhanh
export MCV3_HEARTBEAT_INTERVAL_SEC=1

# shellcheck source=/dev/null
source "$SUT"

# ============================================================
# Test framework (tối giản)
# ============================================================
TESTS_RUN=0
TESTS_PASS=0
TESTS_FAIL=0
FAILURES=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    TESTS_PASS=$((TESTS_PASS + 1))
    echo "  PASS: $label"
  else
    TESTS_FAIL=$((TESTS_FAIL + 1))
    FAILURES+=("$label: expected='$expected', actual='$actual'")
    echo "  FAIL: $label (expected='$expected', actual='$actual')" >&2
  fi
}

assert_true() {
  local label="$1" cmd_rc="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$cmd_rc" -eq 0 ]; then
    TESTS_PASS=$((TESTS_PASS + 1))
    echo "  PASS: $label"
  else
    TESTS_FAIL=$((TESTS_FAIL + 1))
    FAILURES+=("$label: rc=$cmd_rc (expected 0)")
    echo "  FAIL: $label rc=$cmd_rc" >&2
  fi
}

assert_false() {
  local label="$1" cmd_rc="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$cmd_rc" -ne 0 ]; then
    TESTS_PASS=$((TESTS_PASS + 1))
    echo "  PASS: $label"
  else
    TESTS_FAIL=$((TESTS_FAIL + 1))
    FAILURES+=("$label: rc=0 (expected non-zero)")
    echo "  FAIL: $label rc=0 (expected fail)" >&2
  fi
}

# ============================================================
# Test 1: JSON helpers
# ============================================================
echo
echo "=== Test 1: JSON helpers ==="

OUT=$(json_escape 'hello "world"')
assert_eq "json_escape escapes quotes" '"hello \"world\""' "$OUT"

TMP_JSON="$TMP_ROOT/test1.json"
atomic_write_json "$TMP_JSON" '{"key":"value"}'
assert_true "atomic_write_json writes valid JSON" $?
assert_eq "atomic_write_json content correct" "value" "$(jq -r .key "$TMP_JSON")"

# Invalid JSON should be rejected
atomic_write_json "$TMP_ROOT/bad.json" '{not valid' 2>/dev/null
assert_false "atomic_write_json rejects invalid JSON" $?
assert_false "atomic_write_json does not create file on invalid" "$([ -f "$TMP_ROOT/bad.json" ] && echo 0 || echo 1)"

# ============================================================
# Test 2: Slugify + session_id generation
# ============================================================
echo
echo "=== Test 2: Slug & session_id ==="

assert_eq "slugify lowercase" "hello-world" "$(slugify "Hello World")"
assert_eq "slugify special chars" "user-payment-v2" "$(slugify "User_Payment.v2!")"
assert_eq "slugify trim dashes" "abc" "$(slugify "---abc---")"

# session_id format check
SID1=$(generate_session_id "module" "Payment Service")
TODAY=$(date -u +%Y-%m-%d)
assert_eq "session_id format with slug" "${TODAY}-module-payment-service-01" "$SID1"

# Tăng counter khi dir tồn tại
mkdir -p "$MCV3_FIX_BUGS_BASE_DIR/sessions/${TODAY}-module-payment-service-01"
SID2=$(generate_session_id "module" "Payment Service")
assert_eq "session_id increments NN" "${TODAY}-module-payment-service-02" "$SID2"

# Scope=all không có slug
SID3=$(generate_session_id "all" "")
assert_eq "session_id format without slug (all)" "${TODAY}-all-01" "$SID3"

# ============================================================
# Test 3: Lock acquire / release
# ============================================================
echo
echo "=== Test 3: Lock primitives ==="

LOCK_DIR="$TMP_ROOT/wf-fix-bugs/sessions/${TODAY}-test-lock-01"
mkdir -p "$LOCK_DIR"

acquire_lock "$LOCK_DIR" 2>/dev/null
assert_true "acquire_lock fresh succeeds" $?
assert_true "lock file exists after acquire" "$([ -f "$LOCK_DIR/.lock" ] && echo 0 || echo 1)"

# Validate JSON schema
SCHEMA=$(jq -r '."$schema"' "$LOCK_DIR/.lock")
assert_eq "lock JSON has correct schema" "wf-fix-lock-v1" "$SCHEMA"

PID_IN_LOCK=$(jq -r '.pid' "$LOCK_DIR/.lock")
assert_eq "lock JSON pid matches \$\$" "$$" "$PID_IN_LOCK"

# Re-acquire on FRESH lock should FAIL (cùng process, lock vẫn fresh)
acquire_lock "$LOCK_DIR" 2>/dev/null
assert_false "acquire_lock fails on fresh existing lock" $?

# Release + re-acquire
release_lock "$LOCK_DIR"
assert_true "lock removed after release" "$([ ! -f "$LOCK_DIR/.lock" ] && echo 0 || echo 1)"

acquire_lock "$LOCK_DIR" 2>/dev/null
assert_true "acquire_lock succeeds after release" $?

# ============================================================
# Test 4: Lock stale takeover
# ============================================================
echo
echo "=== Test 4: Lock stale takeover ==="

# Backdate mtime của .lock 2 phút (vượt MCV3_LOCK_STALE_MINUTES=1)
LOCK_DIR2="$TMP_ROOT/wf-fix-bugs/sessions/${TODAY}-test-stale-01"
mkdir -p "$LOCK_DIR2"
acquire_lock "$LOCK_DIR2" 2>/dev/null

# Touch backdating: dùng -d (GNU) hoặc -t (BSD)
touch -d "2 minutes ago" "$LOCK_DIR2/.lock" 2>/dev/null \
  || touch -t "$(date -u -v-2M +%Y%m%d%H%M.%S 2>/dev/null || echo '202604280900.00')" "$LOCK_DIR2/.lock" 2>/dev/null \
  || true

STDERR_TMP=$(mktemp)
acquire_lock "$LOCK_DIR2" 2>"$STDERR_TMP"
RC=$?
STDERR_CONTENT=$(cat "$STDERR_TMP")
rm -f "$STDERR_TMP"

assert_true "acquire_lock takes over stale lock" "$RC"
if echo "$STDERR_CONTENT" | grep -q "stale lock"; then
  echo "  PASS: stderr contains 'stale lock' warning"
  TESTS_PASS=$((TESTS_PASS + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
else
  echo "  FAIL: stderr should contain 'stale lock' (got: $STDERR_CONTENT)" >&2
  TESTS_FAIL=$((TESTS_FAIL + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  FAILURES+=("stderr should contain 'stale lock'")
fi

# ============================================================
# Test 5: Heartbeat updates lock file
# ============================================================
echo
echo "=== Test 5: Heartbeat ==="

LOCK_DIR3="$TMP_ROOT/wf-fix-bugs/sessions/${TODAY}-test-heartbeat-01"
mkdir -p "$LOCK_DIR3"
acquire_lock "$LOCK_DIR3" 2>/dev/null

HB_BEFORE=$(jq -r .heartbeat "$LOCK_DIR3/.lock")
sleep 1
heartbeat_lock "$LOCK_DIR3"
HB_AFTER=$(jq -r .heartbeat "$LOCK_DIR3/.lock")

if [ "$HB_BEFORE" != "$HB_AFTER" ]; then
  echo "  PASS: heartbeat timestamp updated ($HB_BEFORE → $HB_AFTER)"
  TESTS_PASS=$((TESTS_PASS + 1))
else
  echo "  FAIL: heartbeat timestamp unchanged" >&2
  TESTS_FAIL=$((TESTS_FAIL + 1))
  FAILURES+=("heartbeat timestamp unchanged")
fi
TESTS_RUN=$((TESTS_RUN + 1))

# ============================================================
# Test 6: Concurrent acquire — only 1 wins
# ============================================================
echo
echo "=== Test 6: Concurrent acquire (race-safe) ==="

LOCK_DIR4="$TMP_ROOT/wf-fix-bugs/sessions/${TODAY}-test-concurrent-01"
mkdir -p "$LOCK_DIR4"

# Spawn 2 sub-shells cùng acquire, count winners
RESULT_FILE="$TMP_ROOT/concurrent-results.txt"
: > "$RESULT_FILE"

(
  if acquire_lock "$LOCK_DIR4" 2>/dev/null; then
    echo "winner-A" >> "$RESULT_FILE"
  else
    echo "loser-A" >> "$RESULT_FILE"
  fi
) &
PID_A=$!

(
  if acquire_lock "$LOCK_DIR4" 2>/dev/null; then
    echo "winner-B" >> "$RESULT_FILE"
  else
    echo "loser-B" >> "$RESULT_FILE"
  fi
) &
PID_B=$!

wait "$PID_A" "$PID_B"

WINNERS=$(grep -c '^winner-' "$RESULT_FILE" || echo 0)
LOSERS=$(grep -c '^loser-' "$RESULT_FILE" || echo 0)

assert_eq "exactly 1 winner in concurrent acquire" "1" "$WINNERS"
assert_eq "exactly 1 loser in concurrent acquire" "1" "$LOSERS"

# ============================================================
# Test 7: Index helpers (append-only JSONL)
# ============================================================
echo
echo "=== Test 7: Index helpers ==="

append_session_index "${TODAY}-module-test-01" "module" "test"
append_session_index "${TODAY}-all-01" "all" ""

INDEX="$MCV3_FIX_BUGS_BASE_DIR/_index/sessions.jsonl"
LINE_COUNT=$(wc -l < "$INDEX" | tr -d ' ')
assert_eq "sessions index has 2 lines" "2" "$LINE_COUNT"

FIRST_SID=$(head -1 "$INDEX" | jq -r .session_id)
assert_eq "sessions index first session_id correct" "${TODAY}-module-test-01" "$FIRST_SID"

append_history_index "${TODAY}-module-test-01" "phase_3_completed" "All probes done"
HISTORY="$MCV3_FIX_BUGS_BASE_DIR/_index/history.jsonl"
HIST_EVENT=$(head -1 "$HISTORY" | jq -r .event)
assert_eq "history index event correct" "phase_3_completed" "$HIST_EVENT"

# ============================================================
# Test 8: Concurrent multi-dev Phase 0 init pattern (S11) — realistic retry
#
# Mô phỏng pattern thực tế từ session-dir.md:
#   gen SID → mkdir -p $SESSION_DIR → acquire_lock → (retry nếu lock fail)
#
# Lý do: generate_session_id chỉ check filesystem (không atomic giữa
# concurrent calls). Atomic guarantee đến từ acquire_lock (mkdir-guard).
# Khi 2 process gen cùng SID, mkdir cả 2 đều success (mkdir -p idempotent),
# nhưng chỉ 1 acquire_lock thành công. Loser retry → re-gen sees winner's
# dir/lock → returns NN+1.
# ============================================================
echo
echo "=== Test 8: Concurrent multi-dev Phase 0 init (S11) ==="

SID_RESULT_FILE="$TMP_ROOT/sid-results.txt"
: > "$SID_RESULT_FILE"

phase0_init_with_retry() {
  local label="$1"
  local max_retry=5
  local attempt=0
  while [ "$attempt" -lt "$max_retry" ]; do
    local sid
    sid=$(generate_session_id "module" "phase0init" 2>/dev/null) || { echo "$label:ERROR-GEN" >> "$SID_RESULT_FILE"; return 1; }
    local sdir="$MCV3_FIX_BUGS_BASE_DIR/sessions/$sid"
    mkdir -p "$sdir"
    if acquire_lock "$sdir" 2>/dev/null; then
      echo "$label:$sid:retry=$attempt" >> "$SID_RESULT_FILE"
      return 0
    fi
    attempt=$((attempt + 1))
    # Brief sleep (sub-second) to let other process update filesystem state
    sleep 0.05 2>/dev/null || true
  done
  echo "$label:ERROR-MAXRETRY" >> "$SID_RESULT_FILE"
  return 1
}

(
  phase0_init_with_retry "A"
) &
PID_A=$!

(
  phase0_init_with_retry "B"
) &
PID_B=$!

wait "$PID_A" "$PID_B"

LINE_A=$(grep '^A:' "$SID_RESULT_FILE")
LINE_B=$(grep '^B:' "$SID_RESULT_FILE")
SID_A=$(echo "$LINE_A" | cut -d: -f2)
SID_B=$(echo "$LINE_B" | cut -d: -f2)

assert_true "Test 8: A acquired SID + lock (no MAXRETRY)" "$([ -n "$SID_A" ] && [ "$SID_A" != 'ERROR-GEN' ] && [ "$SID_A" != 'ERROR-MAXRETRY' ] && echo 0 || echo 1)"
assert_true "Test 8: B acquired SID + lock (no MAXRETRY)" "$([ -n "$SID_B" ] && [ "$SID_B" != 'ERROR-GEN' ] && [ "$SID_B" != 'ERROR-MAXRETRY' ] && echo 0 || echo 1)"
assert_true "Test 8: SID_A != SID_B (distinct sessions sau retry)" "$([ "$SID_A" != "$SID_B" ] && echo 0 || echo 1)"

# Verify both lock files exist
LOCK_A="$MCV3_FIX_BUGS_BASE_DIR/sessions/$SID_A/.lock"
LOCK_B="$MCV3_FIX_BUGS_BASE_DIR/sessions/$SID_B/.lock"
assert_true "Test 8: lock A file exists" "$([ -f "$LOCK_A" ] && echo 0 || echo 1)"
assert_true "Test 8: lock B file exists" "$([ -f "$LOCK_B" ] && echo 0 || echo 1)"

# Verify _index/sessions.jsonl integrity (if it was used) - here we skip since phase0_init_with_retry didn't call append_session_index, focus on lock+SID

# ============================================================
# Test 9: Trace rotation script (S11) — wf-fix-trace-rotate.sh
# ============================================================
echo
echo "=== Test 9: Trace rotation (S11) ==="

ROTATE_SCRIPT="$SCRIPT_DIR/wf-fix-trace-rotate.sh"
TRACE_DIR="$TMP_ROOT/_trace"
mkdir -p "$TRACE_DIR"
TRACE_FILE="$TRACE_DIR/session-log.json"

# 9.1 — small file no-op
echo '{"e":"x"}' > "$TRACE_FILE"
"$ROTATE_SCRIPT" --trace-path "$TRACE_FILE" >/dev/null 2>&1
ROTATE_EXIT=$?
GZ_COUNT_1=$(find "$TRACE_DIR" -name '*.json.gz' 2>/dev/null | wc -l | tr -d ' ')
assert_eq "Test 9.1: small file rotate exit=0 (no-op)" "0" "$ROTATE_EXIT"
assert_eq "Test 9.1: no gz file created for small file" "0" "$GZ_COUNT_1"

# 9.2 — --check small file exit 0
"$ROTATE_SCRIPT" --check --trace-path "$TRACE_FILE" >/dev/null 2>&1
CHECK_EXIT_SMALL=$?
assert_eq "Test 9.2: --check small file exit=0" "0" "$CHECK_EXIT_SMALL"

# 9.3 — large file (11MB) rotate
truncate -s 11M "$TRACE_FILE"
"$ROTATE_SCRIPT" --trace-path "$TRACE_FILE" >/dev/null 2>&1
ROTATE_EXIT_LARGE=$?
GZ_COUNT_2=$(find "$TRACE_DIR" -name '*.json.gz' 2>/dev/null | wc -l | tr -d ' ')
NEW_SIZE=$(wc -c < "$TRACE_FILE" | tr -d ' ')
assert_eq "Test 9.3: large file rotate exit=0" "0" "$ROTATE_EXIT_LARGE"
assert_eq "Test 9.3: 1 gz file created" "1" "$GZ_COUNT_2"
assert_eq "Test 9.3: original truncated to 0 bytes" "0" "$NEW_SIZE"

# 9.4 — --check large file exit 2 (signal needs rotation)
truncate -s 11M "$TRACE_FILE"
"$ROTATE_SCRIPT" --check --trace-path "$TRACE_FILE" >/dev/null 2>&1
CHECK_EXIT_LARGE=$?
assert_eq "Test 9.4: --check large file exit=2 (needs rotation)" "2" "$CHECK_EXIT_LARGE"

# 9.5 — env override threshold 1MB, file 2MB rotates
rm -f "$TRACE_DIR"/*.json.gz 2>/dev/null
truncate -s 2M "$TRACE_FILE"
MCV3_TRACE_ROTATE_THRESHOLD_MB=1 "$ROTATE_SCRIPT" --trace-path "$TRACE_FILE" >/dev/null 2>&1
GZ_COUNT_3=$(find "$TRACE_DIR" -name '*.json.gz' 2>/dev/null | wc -l | tr -d ' ')
assert_eq "Test 9.5: env override 1MB triggers rotation for 2MB file" "1" "$GZ_COUNT_3"

# 9.6 — missing file exit 1
rm -f "$TRACE_FILE"
"$ROTATE_SCRIPT" --trace-path "$TRACE_FILE" >/dev/null 2>&1
MISSING_EXIT=$?
assert_eq "Test 9.6: missing file rotate exit=1" "1" "$MISSING_EXIT"

# ============================================================
# Summary
# ============================================================
echo
echo "============================================================"
echo "TEST SUMMARY: $TESTS_PASS/$TESTS_RUN passed, $TESTS_FAIL failed"
echo "============================================================"
if [ "$TESTS_FAIL" -gt 0 ]; then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
