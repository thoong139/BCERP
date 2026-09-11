# wf-e2e-verify Orchestrator — Skip Rules

## Skip Rules F0/F0a/F0b (v8.0.0)

```
F0  (infra-check):    NEVER SKIP — mandatory (pipeline không chạy nếu infra fail)
F0a (wf-e2e-finding): NEVER SKIP — mandatory (foundation cho toàn bộ F1-F8)
F0b (seed-manifest):  SKIP nếu:
                        - seed-requirements.json không tồn tại trong session dir
                        - User pass --no-seed flag
F1  (wf-e2e-test):    NEVER SKIP — mandatory live-test
```

**Lý do F0/F0a không thể skip:** Pipeline từ F1 đến F8 phụ thuộc findings từ F0a. Skip F0a → F1 thiếu context.

---

## Conditional Skip Logic

```bash
should_run_f3() {
  # F3 wf-e2e-unblock: chạy khi block-test.json có entries status=blocked
  
  test -f "$SESSION_DIR/block-test.json" || return 1  # no file → skip
  
  COUNT=$(jq -r '[.blocked_tests[] | select(.status=="blocked")] | length' "$SESSION_DIR/block-test.json")
  [ "$COUNT" -gt 0 ]
}

should_run_f4() {
  # F4 wf-e2e-implement: chạy khi implement-required.json có entries status=pending
  
  test -f "$SESSION_DIR/implement-required.json" || return 1
  
  COUNT=$(jq -r '[.entries[] | select(.status=="pending")] | length' "$SESSION_DIR/implement-required.json")
  [ "$COUNT" -gt 0 ]
}

should_run_f6() {
  # F6 wf-e2e-fix: chạy khi issues.json có signals status=open + per-severity cap chưa đạt
  # v8.0.0: Per-severity caps thay thế global counter < 3
  
  test -f "$SESSION_DIR/issues.json" || return 1
  
  COUNT=$(jq -r '[.signals[] | select(.status=="open")] | length' "$SESSION_DIR/issues.json")
  [ "$COUNT" -gt 0 ] || return 1
  
  # Dùng check_should_run_f6() với per-severity logic (xem §Anti-Loop Rules bên dưới)
  check_should_run_f6
}
```

---

## Decision Tree (canonical)

```
After F1 (always):
  proceed to F2

After F2 (default ON; skip only with --skip=F2):
  → DECIDE F3: should_run_f3()
     ├── true → run F3
     └── false → skip F3

After F3 (or skipped):
  → DECIDE F4: should_run_f4()
     ├── true → run F4
     └── false → skip F4

After F4 (or skipped):
  → run F5 (mandatory if F4 ran OR PENDING markers exist)
     - Mark retest_after_impl=true nếu F4 ran

After F5:
  → DECIDE F6: should_run_f6() [per-severity caps — v8.0.0]
     ├── true → run F6 → increment_loop_count($max_severity) → re-run F5 → re-DECIDE F6
     └── false → proceed F7

F7 (default ON; skip only with --skip=F7):
  → always run unless skipped (Playwright auto-start mandatory)

F8 (default ON; skip only with --skip=F8):
  → always run unless skipped (Playwright auto-start mandatory)

Finalize:
  → write orchestrator-summary + phase-summary
```

---

## Anti-Loop Rules F6↔F5 (v8.0.0 — Per-Severity Caps)

F6 fix có thể tạo new issues khi fix. F5 retest có thể reveal new failures sau fix. Để tránh infinite loop,
v8.0.0 áp dụng per-severity caps thay vì global counter.

### Per-Severity Loop Caps

| Severity | Max loops |
|----------|-----------|
| CRITICAL | 5 |
| HIGH | 4 |
| MEDIUM | 3 |
| LOW | 2 |

### State Schema (trong e2e-status.json)

```json
"f6_f5_loops": {
  "critical": { "count": 0, "cap": 5 },
  "high":     { "count": 0, "cap": 4 },
  "medium":   { "count": 0, "cap": 3 },
  "low":      { "count": 0, "cap": 2 },
  "high_from_f7_used": false
}
```

### Hàm check_should_run_f6()

```bash
check_should_run_f6() {
  # Lấy severity cao nhất của open issues
  local MAX_SEVERITY=$(jq -r '[.signals[] | select(.status == "open") | .severity] | sort | reverse | first // "none"' "$SESSION_DIR/issues.json")
  
  [ "$MAX_SEVERITY" = "none" ] && return 1  # Không có open issues → skip F6
  
  local SEVERITY_LOWER=$(echo "$MAX_SEVERITY" | tr '[:upper:]' '[:lower:]')
  local CURRENT_COUNT=$(jq ".f6_f5_loops.${SEVERITY_LOWER}.count" "$E2E_STATUS")
  local CAP=$(jq ".f6_f5_loops.${SEVERITY_LOWER}.cap" "$E2E_STATUS")
  
  if [ "$CURRENT_COUNT" -ge "$CAP" ]; then
    # Cap đạt giới hạn — hỏi user
    AskUserQuestion:
      Câu hỏi: "Anti-loop cap (${CURRENT_COUNT}/${CAP}) đạt giới hạn cho severity ${MAX_SEVERITY}. Hành động tiếp theo?"
      Options:
        1. "Override + tiếp tục F6 (ghi log CDG-Custom-AntiLoop)"
        2. "Mark các issues còn lại = deferred"
        3. "Cancel session"
    
    # Nếu chọn 1: increment_loop_count, return 0
    # Nếu chọn 2: mark_remaining_issues_deferred(), return 1
    # Nếu chọn 3: cancel_session(), return 1
    return 0  # placeholder — AskUserQuestion branching above
  fi
  
  return 0  # Còn budget → chạy F6
}
```

### HIGH+ từ F7 Override Rule

```bash
check_f7_high_plus_override() {
  # Sau F7 hoàn tất — check nếu F7 phát hiện issue mới HIGH+
  local F7_NEW_HIGH=$(jq '[.signals[] | select(.status=="open" and .source=="f7_scenario" and (.severity=="HIGH" or .severity=="CRITICAL"))] | length' "$SESSION_DIR/issues.json")
  
  if [ "$F7_NEW_HIGH" -gt 0 ]; then
    local HIGH_FROM_F7_USED=$(jq -r '.f6_f5_loops.high_from_f7_used' "$E2E_STATUS")
    
    if [ "$HIGH_FROM_F7_USED" = "false" ]; then
      # Override: BẮT BUỘC route về F6 ít nhất 1 lần
      jq '.f6_f5_loops.high_from_f7_used = true' "$E2E_STATUS" > "$E2E_STATUS.tmp"
      jq '.' "$E2E_STATUS.tmp" > /dev/null && mv "$E2E_STATUS.tmp" "$E2E_STATUS"
      echo "HIGH+ issues từ F7 → force route F6 (1 override slot đã dùng)"
      return 0  # Run F6
    else
      # Đã dùng override slot → apply normal caps
      check_should_run_f6
      return $?
    fi
  fi
  
  return 1  # Không có HIGH+ từ F7
}
```

### Increment Loop Count

```bash
increment_loop_count() {
  local SEVERITY="$1"  # critical | high | medium | low
  jq ".f6_f5_loops.${SEVERITY}.count += 1" "$E2E_STATUS" > "$E2E_STATUS.tmp"
  jq '.' "$E2E_STATUS.tmp" > /dev/null && mv "$E2E_STATUS.tmp" "$E2E_STATUS"
}
```

### Mark Remaining Issues Deferred

```bash
mark_remaining_issues_deferred() {
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg t "$ISO" '
    (.signals[] | select(.status == "open") | .status) = "deferred" |
    (.signals[] | select(.status == "deferred") | .deferred_at) = $t |
    (.signals[] | select(.status == "deferred") | .deferred_reason) = "anti-loop cap reached"
  ' "$SESSION_DIR/issues.json" > "$SESSION_DIR/issues.json.tmp"
  jq '.' "$SESSION_DIR/issues.json.tmp" > /dev/null && mv "$SESSION_DIR/issues.json.tmp" "$SESSION_DIR/issues.json"
}
```

### Orchestrator Integration

Trong `orchestrate.md`, sau F6 hoàn tất:

```bash
# Sau F6 hoàn tất — increment count cho severity đã xử lý
MAX_SEVERITY_PROCESSED=$(jq -r '[.signals[] | select(.status != "open") | .severity] | sort | reverse | first // "none"' "$SESSION_DIR/issues.json")
if [ "$MAX_SEVERITY_PROCESSED" != "none" ]; then
  SEVERITY_LOWER=$(echo "$MAX_SEVERITY_PROCESSED" | tr '[:upper:]' '[:lower:]')
  increment_loop_count "$SEVERITY_LOWER"
fi

# Kiểm tra còn open issues không → nếu có, check anti-loop trước khi vòng F5→F6 tiếp
OPEN_COUNT=$(jq '[.signals[] | select(.status=="open")] | length' "$SESSION_DIR/issues.json")
if [ "$OPEN_COUNT" -gt 0 ]; then
  if check_should_run_f6; then
    # Chạy F5 rồi F6 lại
    run_f5_then_decide_f6
  fi
fi
```

---

## --skip Flag Handling

User có thể opt-out steps qua `--skip=F2,F3,F4,F6`:

```bash
parse_skip_flag() {
  if [ -n "${SKIP_ARG:-}" ]; then
    SKIP_LIST=$(echo "$SKIP_ARG" | tr ',' '\n' | sort -u)
    echo "User requested skip: $SKIP_LIST"
  fi
}

is_user_skipped() {
  local STEP="$1"
  echo "${SKIP_LIST:-}" | grep -q "^$STEP$"
}
```

Nếu `is_user_skipped F4`: orchestrator mark F4 status=skipped với reason="user_skip" và proceed.

**Lưu ý:** Skip F1 KHÔNG được phép (mandatory). Skip F5 KHÔNG khuyến nghị nhưng cho phép. Skip F7/F8 chỉ khi user explicit `--skip=F7,F8`.

---

## --no-playwright Cascading (G2 — v8.0.0)

WHY G2 đóng loophole cũ: Trước v8.0.0, `--no-playwright` skip F2/F7/F8 hoàn toàn và trả về `completed=true`. Điều này tạo "fantasy pass" — pipeline báo thành công nhưng không có browser test nào thực sự chạy. G2 thay thế behavior skip bằng DEGRADE mode.

**TRƯỚC (loophole đã đóng):** `--no-playwright` → skip F2/F5/F7/F8 → `completed=true` (FANTASY)

**SAU (G2):** `--no-playwright` KHÔNG skip phases, chỉ DEGRADE:

```bash
if [ "${NO_PLAYWRIGHT:-false}" = "true" ]; then
  # F2: degraded_no_browser — chỉ static analysis, không execute browser
  EXTRA_FLAGS_F2="--mode=degraded_no_browser"
  # F7: degraded_no_browser — scenario draft only, không execute qua Playwright
  EXTRA_FLAGS_F7="--mode=degraded_no_browser"
  # F8: degraded_no_browser — user-guide draft only, không screenshot
  EXTRA_FLAGS_F8="--mode=degraded_no_browser"

  # Status của mỗi step bị degrade = "degraded_no_browser" (KHÔNG "completed")
  # Orchestrator final status = "degraded" khi bất kỳ step nào là degraded_no_browser

  echo "WARN: --no-playwright active — pipeline se chay o DEGRADE mode"
  echo "      F2/F7/F8 se static-analysis only, khong browser execution"
  echo "      Final status se la 'degraded', KHONG 'completed'"
  echo "      CANH BAO: Khong production-ready — can re-run KHONG co --no-playwright truoc khi ship"

  # F5 vẫn run nhưng pass --no-playwright xuống (static retest)
fi
```

### Degraded Final Status Logic

```bash
finalize_with_degraded_check() {
  # Kiểm tra nếu có step nào bị degrade
  DEGRADED_COUNT=$(jq -r '[.steps[] | select(.status=="degraded_no_browser")] | length' "$E2E_STATUS" 2>/dev/null || echo 0)

  if [ "$DEGRADED_COUNT" -gt 0 ]; then
    OVERALL_STATUS="degraded"
    DEGRADE_MSG="Pipeline chay o DEGRADE mode ($DEGRADED_COUNT buoc khong co browser). Khong production-ready."
    
    # Ghi warning vào phase-summary.md
    echo "" >> "$SESSION_DIR/phase-summary.md"
    echo "---" >> "$SESSION_DIR/phase-summary.md"
    echo "CANH BAO: Da chay khong Playwright ($DEGRADED_COUNT buoc degraded_no_browser)." >> "$SESSION_DIR/phase-summary.md"
    echo "KHONG production-ready. Re-run: /wf-e2e-verify $FEAT_ID" >> "$SESSION_DIR/phase-summary.md"
  fi
}
```

### Phase-summary.md Warning (khi degraded)

Cuối phase-summary.md thêm:
```
---
CANH BAO: Da chay khong Playwright — KHONG production-ready.
Re-run khong co --no-playwright: /wf-e2e-verify {FEAT_ID} --session={SESSION_ID} --from-step=F2
```

Use case hợp lệ cho --no-playwright: CI environment không có browser (draft review, không ship), quick check logic-only trước khi có browser.

---

## --from-step Cascading

User có thể start từ step giữa (skip earlier steps):

```bash
parse_from_step() {
  case "${FROM_STEP:-F1}" in
    "F1"|"") ENTRY="F1" ;;
    "F2") ENTRY="F2" ; SKIP_LIST+=" F1" ;;
    "F3") ENTRY="F3" ; SKIP_LIST+=" F1 F2" ;;
    "F4") ENTRY="F4" ; SKIP_LIST+=" F1 F2 F3" ;;
    "F5") ENTRY="F5" ; SKIP_LIST+=" F1 F2 F3 F4" ;;
    "F6") ENTRY="F6" ; SKIP_LIST+=" F1 F2 F3 F4 F5" ;;
    "F7") ENTRY="F7" ; SKIP_LIST+=" F1 F2 F3 F4 F5 F6" ;;
    "F8") ENTRY="F8" ; SKIP_LIST+=" F1 F2 F3 F4 F5 F6 F7" ;;
  esac
  
  # PRE-GATE: validate skipped steps' outputs exist (vì sau F4 cần F1+F2+F3 outputs)
  for SKIPPED in $SKIP_LIST; do
    # Each skipped step's outputs must exist trong session
    verify_step_outputs "$SKIPPED" || {
      echo "ERROR: --from-step=$ENTRY requires outputs of $SKIPPED but they don't exist"
      exit_with E005
    }
  done
}
```

---

## Standalone Mode Detection

Khi orchestrator được spawn từ legacy command (vd: `--fix=<path>`), behavior thay đổi:

```bash
detect_standalone_mode() {
  # Legacy --fix=<path> → standalone F6
  if [ -n "${FIX_PATH:-}" ]; then
    STANDALONE="F6"
    FROM_STEP="F6"
    SKIP_LIST="F1 F2 F3 F4 F5 F7 F8"
    SUB_FLAGS="--path=$FIX_PATH"
    return
  fi
  
  # Legacy --retest → standalone F5
  if [ "${RETEST:-false}" = "true" ]; then
    STANDALONE="F5"
    FROM_STEP="F5"
    SKIP_LIST="F1 F2 F3 F4 F6 F7 F8"
    return
  fi
  
  # Legacy --unblock-test → standalone F3
  if [ "${UNBLOCK_TEST:-false}" = "true" ]; then
    STANDALONE="F3"
    FROM_STEP="F3"
    SKIP_LIST="F1 F2 F4 F5 F6 F7 F8"
    return
  fi
  
  STANDALONE="false"  # Full pipeline
}
```
