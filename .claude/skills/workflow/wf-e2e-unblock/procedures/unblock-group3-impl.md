# F3 wf-e2e-unblock — Group 3: Strict Task Generation (v2.0.0)

## Mục đích

Xử lý Nhóm 3 (blocking_reason: `feature_deferred`, `feature_not_implemented`) — F3 **không** tự
implement, nhưng BẮT BUỘC phải generate đủ thông tin cho F4 wf-e2e-implement thực hiện đúng.

> **Lý do thêm strict generation (v2.0.0):** F4 delegate cần biết chính xác file, dòng, và signature
> cần implement. Nếu thiếu, F4 phải tự tìm → tăng nguy cơ sai target, overwrite code không liên quan.
> Yêu cầu rõ ràng ở F3 → F4 implement an toàn hơn (CORE-020).

---

## State Variables (kế thừa từ _shared.md)

```
$SESSION_DIR, $BLOCK_TEST, $IMPL_REQ = $SESSION_DIR/implement-required.json
$F3_DIR = $SESSION_DIR/F3-unblock/
```

---

## Bước 1: Collect Group 3 Entries

```bash
# Lấy tất cả entries Group 3 còn blocked
GROUP3_ENTRIES=$(jq '[.blocked_tests[] | select(.status=="blocked" and (.blocking_reason == "feature_deferred" or .blocking_reason == "feature_not_implemented"))]' "$BLOCK_TEST")

GROUP3_COUNT=$(echo "$GROUP3_ENTRIES" | jq 'length')
```

Nếu `GROUP3_COUNT = 0` → bỏ qua file này, không có gì cần xử lý.

---

## Bước 2: AUTO-FLAG requires_arch_review

```bash
# Nếu ≥5 tasks Nhóm 3 → trigger CDG-07
if [ "$GROUP3_COUNT" -ge 5 ]; then
  REQUIRES_ARCH_REVIEW=true
  
  # CDG-07: AskUserQuestion trước khi advance sang F4
  AskUserQuestion:
    Câu hỏi: "Phát hiện ${GROUP3_COUNT} tasks cần implement. ≥5 tasks gợi ý cần review kiến trúc trước. Tiếp tục F4?"
    Options:
      1. "Tiếp tục F4 (auto-implement)"
      2. "Dừng để review kiến trúc"
      3. "Chỉ implement P0/P1, defer P2/P3 còn lại"
    
    # Nếu user chọn 2: STOP F3, ghi note vào unblock-report.md
    # Nếu user chọn 3: set ARCH_REVIEW_FILTER_P2=true (chỉ generate P0/P1 với requires_arch_review=false; P2/P3 set requires_arch_review=true + status=pending-arch-review)
    # Nếu user chọn 1: tiếp tục bình thường, REQUIRES_ARCH_REVIEW=true trên tất cả entries
else
  REQUIRES_ARCH_REVIEW=false
fi
```

---

## Bước 3: Strict Task Generation cho Mỗi Entry

Với **MỖI** BLK-NNN trong Group 3:

### 3.1 — Resolve target_file

```bash
resolve_target_file() {
  local BLK_ID="$1"
  local FEAT_ID="$2"
  local TEST_REF="$3"
  
  # Ưu tiên 1: CI tool (Serena find_symbol từ test_ref keyword)
  if [ "$SERENA_AVAILABLE" = "true" ]; then
    TARGET=$(mcp__serena__search_for_pattern --substring_pattern="$TEST_REF" --paths_include_glob="**/*.{ts,py,cs,go,java}")
    [ -n "$TARGET" ] && echo "$TARGET" | head -1 | awk '{print $1}' && return
  fi
  
  # Ưu tiên 2: Grep fallback
  TARGET=$(grep -rl "$TEST_REF" . --include="*.ts" --include="*.py" --include="*.cs" --include="*.go" 2>/dev/null | head -1)
  [ -n "$TARGET" ] && echo "$TARGET" && return
  
  # Ưu tiên 3: Đọc location_hint từ block-test.json entry (nếu có)
  HINT=$(jq -r --arg id "$BLK_ID" '.blocked_tests[] | select(.id==$id) | .location_hint // ""' "$BLOCK_TEST")
  [ -n "$HINT" ] && echo "$HINT" && return
  
  # Fallback: trả về empty string (sẽ bị bắt ở POST-GATE T3)
  echo ""
}
```

### 3.2 — Resolve target_line

```bash
resolve_target_line() {
  local TARGET_FILE="$1"
  local SYMBOL_HINT="$2"
  
  [ -z "$TARGET_FILE" ] && echo "" && return
  
  # Dùng Serena nếu available
  if [ "$SERENA_AVAILABLE" = "true" ]; then
    # Serena trả 0-based line → +1 để hiển thị 1-based
    RANGE=$(mcp__serena__find_symbol --name_path="$SYMBOL_HINT" --relative_path="$TARGET_FILE" 2>/dev/null | grep -oP '"line":\K[0-9]+' | head -1)
    [ -n "$RANGE" ] && echo "$((RANGE+1))" && return
  fi
  
  # Fallback: grep line number
  LINE=$(grep -n "$SYMBOL_HINT" "$TARGET_FILE" 2>/dev/null | head -1 | cut -d: -f1)
  [ -n "$LINE" ] && echo "$LINE" && return
  
  echo ""
}
```

### 3.3 — Generate proposed_signature

```bash
generate_proposed_signature() {
  local BLK_ID="$1"
  local EXPECTED_BEHAVIOR="$2"
  local TARGET_FILE="$3"
  
  # Đọc context từ expected_behavior để suy ra signature
  # Ví dụ: "POST trả 400 với code DUPLICATE_EMAIL" → "async createCustomer(dto: CreateCustomerDto): Promise<CustomerResponse>"
  # Đây là LLM-generated step — generate dựa trên available context
  
  # Lấy suggested_action từ block-test.json (endpoint_missing, validation_missing, ...)
  SUGGESTED_ACTION=$(jq -r --arg id "$BLK_ID" '.blocked_tests[] | select(.id==$id) | .suggested_action // ""' "$BLOCK_TEST")
  FEAT_ID=$(jq -r --arg id "$BLK_ID" '.blocked_tests[] | select(.id==$id) | .feat_id // ""' "$BLOCK_TEST")
  
  # Generate signature dựa theo ngữ cảnh
  # BẮT BUỘC phải có độ dài > 10 chars và đủ thông tin để F4 hiểu
  # Format gợi ý: "<access> <function_name>(<params>): <return_type>"
  # Ví dụ: "async validateDuplicateEmail(email: string, companyId: string): Promise<boolean>"
  echo "${SUGGESTED_ACTION}_${FEAT_ID}(/* params */): /* ReturnType */"
}
```

### 3.4 — Generate acceptance_criteria (≥3 items)

```bash
generate_acceptance_criteria() {
  local BLK_ID="$1"
  local EXPECTED_BEHAVIOR="$2"
  local TEST_REF="$3"
  
  # Tạo ≥3 criteria từ expected_behavior + test_ref
  # Format: bullet list plain text array
  
  # Criterion 1: Happy path từ expected_behavior
  # Criterion 2: Error/edge case
  # Criterion 3: Test reference linkage
  
  jq -n \
    --arg b1 "Khi input hợp lệ → ${EXPECTED_BEHAVIOR}" \
    --arg b2 "Khi input không hợp lệ → throw/return lỗi với message rõ ràng (BusinessError hoặc HTTP 4xx)" \
    --arg b3 "Test pass: ${TEST_REF}" \
    '[$b1, $b2, $b3]'
}
```

---

## Bước 4: Write Entry vào implement-required.json (schema v2)

```bash
append_group3_impl_req() {
  local BLK_ID="$1"
  local FEAT_ID="$2"
  local SEVERITY="$3"
  local DESCRIPTION="$4"
  local TARGET_FILE="$5"
  local TARGET_LINE="$6"
  local PROPOSED_SIG="$7"
  local ACCEPTANCE_CRITERIA="$8"  # JSON array string
  local REQUIRES_ARCH_REVIEW="$9"
  
  # Auto-increment IMPL-REQ-NNN
  MAX_ID=$(jq -r '.entries | map(.id | ltrimstr("IMPL-REQ-") | tonumber) | max // 0' "$IMPL_REQ")
  NEXT_ID=$(printf "IMPL-REQ-%03d" $((MAX_ID + 1)))
  
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  NEW_ENTRY=$(jq -n \
    --arg id "$NEXT_ID" \
    --arg at "$ISO" \
    --arg feat_id "$FEAT_ID" \
    --arg desc "$DESCRIPTION" \
    --arg sev "$SEVERITY" \
    --arg tfile "$TARGET_FILE" \
    --arg tline "$TARGET_LINE" \
    --arg psig "$PROPOSED_SIG" \
    --argjson ac "$ACCEPTANCE_CRITERIA" \
    --argjson arch "${REQUIRES_ARCH_REVIEW:-false}" \
    --arg blk_id "$BLK_ID" \
    '{
      "id": $id,
      "blk_id": $blk_id,
      "feat_id": $feat_id,
      "severity": $sev,
      "group": 3,
      "description": $desc,
      "discovered_at": $at,
      "discovered_by_skill": "wf-e2e-unblock",
      "target_file": $tfile,
      "target_line": $tline,
      "proposed_signature": $psig,
      "acceptance_criteria": $ac,
      "requires_arch_review": $arch,
      "status": "pending",
      "implemented_at": null,
      "implementer": null,
      "delegate_session_id": null,
      "code_refs": [],
      "related_blk_id": $blk_id,
      "related_iss_ids": [],
      "retest_after_impl": true,
      "retest_result": "PENDING"
    }')
  
  # Atomic write (CORE-035)
  jq --argjson entry "$NEW_ENTRY" '.entries += [$entry] | .last_updated = now | todate' "$IMPL_REQ" > "$IMPL_REQ.tmp"
  jq '.' "$IMPL_REQ.tmp" > /dev/null || exit_with E036
  mv "$IMPL_REQ.tmp" "$IMPL_REQ"
  
  # Cập nhật unblock_attempts trong block-test.json
  jq --arg id "$BLK_ID" --arg next_id "$NEXT_ID" --arg at "$ISO" '
    (.blocked_tests[] | select(.id==$id) | .unblock_attempts) += [{
      "at": $at,
      "action": "skip — delegate to F4 wf-e2e-implement",
      "result": "deferred",
      "detail": ("Group 3 requires code implementation. See implement-required.json " + $next_id)
    }]
  ' "$BLOCK_TEST" > "$BLOCK_TEST.tmp"
  jq '.' "$BLOCK_TEST.tmp" > /dev/null || exit_with E037
  mv "$BLOCK_TEST.tmp" "$BLOCK_TEST"
  
  echo "$NEXT_ID"
}
```

---

## Bước 5: POST-GATE T3 Validation (BẮT BUỘC v2.0.0)

```bash
validate_group3_strict_fields() {
  local ERRORS=0
  
  # Đọc tất cả Group 3 entries từ implement-required.json
  GROUP3_IMPL_ENTRIES=$(jq '[.entries[] | select(.group == 3)]' "$IMPL_REQ")
  
  while IFS= read -r entry; do
    IMPL_ID=$(echo "$entry" | jq -r '.id')
    
    # CHECK 1: target_file
    TARGET_FILE=$(echo "$entry" | jq -r '.target_file // ""')
    if [ -z "$TARGET_FILE" ]; then
      log_error "E030" "F3-post-gate" "IMPL-REQ $IMPL_ID thiếu target_file" 0
      ERRORS=$((ERRORS + 1))
    fi
    
    # CHECK 2: target_line (pattern: ^[0-9]+(-[0-9]+)?$)
    TARGET_LINE=$(echo "$entry" | jq -r '.target_line // ""')
    if [ -z "$TARGET_LINE" ] || ! echo "$TARGET_LINE" | grep -qE '^[0-9]+(-[0-9]+)?$'; then
      log_error "E030" "F3-post-gate" "IMPL-REQ $IMPL_ID thiếu hoặc sai format target_line (nhận được: '$TARGET_LINE')" 0
      ERRORS=$((ERRORS + 1))
    fi
    
    # CHECK 3: proposed_signature (len > 10)
    PROPOSED_SIG=$(echo "$entry" | jq -r '.proposed_signature // ""')
    SIG_LEN=${#PROPOSED_SIG}
    if [ "$SIG_LEN" -le 10 ]; then
      log_error "E030" "F3-post-gate" "IMPL-REQ $IMPL_ID proposed_signature quá ngắn (len=$SIG_LEN, cần >10)" 0
      ERRORS=$((ERRORS + 1))
    fi
    
    # CHECK 4: acceptance_criteria (array với ≥1 item)
    AC_LEN=$(echo "$entry" | jq '.acceptance_criteria | length')
    if [ "$AC_LEN" -lt 1 ]; then
      log_error "E030" "F3-post-gate" "IMPL-REQ $IMPL_ID acceptance_criteria rỗng (cần ≥1 item)" 0
      ERRORS=$((ERRORS + 1))
    fi
    
  done < <(echo "$GROUP3_IMPL_ENTRIES" | jq -c '.[]')
  
  if [ "$ERRORS" -gt 0 ]; then
    echo "POST-GATE T3 FAIL: $ERRORS lỗi trong Group 3 strict fields. F3 bị BLOCK."
    echo "Chi tiết: $SESSION_DIR/error-ledger.json"
    return 1
  fi
  
  echo "POST-GATE T3 PASS: Tất cả Group 3 entries có đủ 4 required fields."
  return 0
}
```

Nếu validation fail sau max 3 retry → E030 → BLOCK F3 completion, không update status="completed".

---

## Gọi từ _shared.md

Trong `_shared.md §group3-skip`, thay thế logic cũ bằng:

```
FOR each BLK-NNN with blocking_reason ∈ {feature_deferred, feature_not_implemented}:
  LOAD procedure: unblock-group3-impl.md
  RUN: Strict Task Generation (Bước 1-4 trên)
  
AFTER all Group 3 processed:
  RUN: validate_group3_strict_fields() → POST-GATE T3
  IF FAIL → auto-fix retry (max 3) → E030
  IF PASS → mark group3_status="completed"
```
