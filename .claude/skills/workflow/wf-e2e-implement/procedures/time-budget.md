# F4 wf-e2e-implement — Time-Based Budget (v2.0.0)

## Mục đích

Thay thế `--max-items` (deprecated) bằng `--max-time` để kiểm soát thời gian F4 một cách linh hoạt
theo priority. P0 luôn hoàn thành, P1 bắt buộc ≥80%, P2/P3 best-effort với thời gian còn lại.

> **Lý do bỏ --max-items (v2.0.0):** max-items không phân biệt priority — có thể dùng hết budget
> vào P2 tasks trong khi P1 chưa làm. Time-budget với priority enforcement đảm bảo items quan trọng
> được implement trước, và partial completion được report rõ ràng thay vì âm thầm skip.

---

## State Variables

```bash
$MAX_TIME_SECONDS   # Parse từ --max-time arg (vd: "60m" → 3600, "90m" → 5400)
$START_TIME         # Unix timestamp khi F4 bắt đầu
$SESSION_DIR        # Kế thừa từ _shared.md
$IMPL_REQ           # $SESSION_DIR/implement-required.json
$F4_DIR             # $SESSION_DIR/F4-implement/
$DECISIONS_DIR      # .mc-data/work/_decisions/
```

---

## Bước 0: Parse --max-time Argument

```bash
parse_max_time() {
  local RAW="${MAX_TIME:-60m}"
  
  # Xử lý --max-items deprecated
  if [ -n "${MAX_ITEMS:-}" ]; then
    echo "WARN: --max-items deprecated kể từ v2.0.0. Dùng --max-time thay thế."
    echo "  Ví dụ: --max-time=60m"
    # Ignore MAX_ITEMS, dùng MAX_TIME default
    RAW="${MAX_TIME:-60m}"
  fi
  
  # Parse duration: "60m" → 3600, "90m" → 5400, "120m" → 7200
  if echo "$RAW" | grep -qE '^[0-9]+m$'; then
    MINUTES=$(echo "$RAW" | sed 's/m//')
    MAX_TIME_SECONDS=$((MINUTES * 60))
  elif echo "$RAW" | grep -qE '^[0-9]+h$'; then
    HOURS=$(echo "$RAW" | sed 's/h//')
    MAX_TIME_SECONDS=$((HOURS * 3600))
  elif echo "$RAW" | grep -qE '^[0-9]+$'; then
    # Số nguyên → coi là giây
    MAX_TIME_SECONDS="$RAW"
  else
    echo "WARN: Format --max-time không nhận ra ('$RAW'). Dùng default 60m."
    MAX_TIME_SECONDS=3600
  fi
  
  echo "Budget F4: ${MAX_TIME_SECONDS}s ($(( MAX_TIME_SECONDS / 60 ))m)"
}

# Ghi start time
START_TIME=$(date +%s)
```

---

## Hàm check_time_budget()

Gọi trước mỗi P1/P2/P3 item để kiểm tra còn đủ thời gian không.

```bash
check_time_budget() {
  local PRIORITY="$1"  # P0 | P1 | P2 | P3
  
  local NOW=$(date +%s)
  local ELAPSED=$((NOW - START_TIME))
  local REMAINING=$((MAX_TIME_SECONDS - ELAPSED))
  
  # P0: luôn tiếp tục bất kể thời gian
  if [ "$PRIORITY" = "P0" ]; then
    return 0
  fi
  
  # Còn ít hơn 2 phút → kiểm tra P1 completion rate trước khi continue
  if [ "$REMAINING" -lt 120 ]; then
    check_p1_completion_rate
    local P1_STATUS=$?
    
    if [ "$P1_STATUS" -ne 0 ]; then
      return 1  # P1 rate < 80% → STOP
    fi
    
    # P1 rate ≥ 80% nhưng budget gần hết
    if [ "$PRIORITY" = "P2" ] || [ "$PRIORITY" = "P3" ]; then
      echo "INFO: Budget còn ${REMAINING}s — P2/P3 items sẽ bị bỏ qua."
      return 1  # Dừng P2/P3 khi budget gần hết
    fi
  fi
  
  return 0
}
```

---

## Hàm check_p1_completion_rate()

```bash
check_p1_completion_rate() {
  local P1_TOTAL=$(jq '[.entries[] | select(.severity=="P1" and .group==3)] | length' "$IMPL_REQ")
  local P1_DONE=$(jq '[.entries[] | select(.severity=="P1" and .group==3 and .status=="done")] | length' "$IMPL_REQ")
  
  # Tránh chia cho 0
  if [ "$P1_TOTAL" -eq 0 ]; then
    return 0  # Không có P1 → coi như đạt
  fi
  
  # Tính rate dưới dạng phần trăm nguyên (bash không hỗ trợ float)
  local P1_RATE_PCT=$(( P1_DONE * 100 / P1_TOTAL ))
  
  if [ "$P1_RATE_PCT" -lt 80 ]; then
    # Lấy danh sách P1 chưa làm
    local P1_PENDING=$(jq -r '[.entries[] | select(.severity=="P1" and .group==3 and .status!="done") | .id] | join(", ")' "$IMPL_REQ")
    
    # Ghi Phase-report.md với trạng thái partial
    local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$F4_DIR/Phase-report.md" <<EOF
## Phase 4: wf-e2e-implement — PARTIAL

Thời gian: $ISO

**Đã làm:** Implement các task P0 + một phần P1.

**Kết quả:** Hết budget thời gian. Đã implement ${P1_DONE}/${P1_TOTAL} P1 items (${P1_RATE_PCT}% — cần ≥80%).

**P1 chưa implement:** ${P1_PENDING}

**Tiếp theo:** F4 dừng với trạng thái PARTIAL. Không advance sang F5. Xem lại budget (--max-time) hoặc resume F4 với --resume.
EOF
    
    # Cập nhật e2e-status.json: F4 status=partial
    ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg t "$ISO" '
      .steps.F4.status = "partial" |
      .steps.F4.completed_at = $t |
      .current_step = "F4-partial" |
      .next_action = "F4 partial — P1 rate < 80%. Cần resume hoặc tăng budget"
    ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
    jq '.' "$E2E_STATUS.tmp" > /dev/null && mv "$E2E_STATUS.tmp" "$E2E_STATUS"
    
    echo "F4 PARTIAL: P1 completion rate ${P1_RATE_PCT}% < 80%. Dừng F4, KHÔNG advance F5."
    return 1  # Signal caller: STOP
  fi
  
  return 0  # P1 rate đạt yêu cầu
}
```

---

## Hàm handle_decision_required()

Khi một item cần product decision (không thể auto-decide):

```bash
handle_decision_required() {
  local IMPL_REQ_ID="$1"
  local FEAT_ID="$2"
  local CONTEXT_FILE="$3"
  local CONTEXT_LINE="$4"
  local WHY_BLOCKING="$5"
  
  # Tạo thư mục _decisions nếu chưa có
  mkdir -p "$DECISIONS_DIR"
  PENDING_QUEUE="$DECISIONS_DIR/pending-queue.md"
  
  # Auto-increment decision ID
  local MAX_DEC=0
  if [ -f "$PENDING_QUEUE" ]; then
    MAX_DEC=$(grep -oP 'DECISION-\K[0-9]+' "$PENDING_QUEUE" | sort -n | tail -1 || echo "0")
  fi
  local NEXT_DEC=$(printf "%04d" $((MAX_DEC + 1)))
  
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Append vào pending-queue.md
  cat >> "$PENDING_QUEUE" <<EOF

## DECISION-${NEXT_DEC}
- FEAT-ID: ${FEAT_ID}
- Type: BUSINESS_RULE
- Severity: HIGH
- Status: pending
- Description: Item ${IMPL_REQ_ID} cần quyết định để implement
- Context: file=${CONTEXT_FILE}, line=${CONTEXT_LINE}, vì sao blocking=${WHY_BLOCKING}
- Suggested options: [Xem file quyết định riêng nếu cần]
- Deadline: (không set)
- Spawned by: wf-e2e-verify session ${SESSION_ID}
- Created at: ${ISO}
EOF
  
  # Cập nhật entry status → decision_required (KHÔNG "skipped")
  jq --arg id "$IMPL_REQ_ID" --arg dec "DECISION-${NEXT_DEC}" --arg t "$ISO" '
    (.entries[] | select(.id==$id) | .status) = "decision_required" |
    (.entries[] | select(.id==$id) | .decision_ref) = $dec |
    (.entries[] | select(.id==$id) | .decision_at) = $t
  ' "$IMPL_REQ" > "$IMPL_REQ.tmp"
  jq '.' "$IMPL_REQ.tmp" > /dev/null && mv "$IMPL_REQ.tmp" "$IMPL_REQ"
  
  echo "DECISION-${NEXT_DEC} tạo tại: $PENDING_QUEUE"
}
```

---

## Tích hợp vào Entry Iteration Loop (_shared.md)

Trong `_shared.md §Entry Iteration`, thay thế logic `MAX_ITEMS` cũ bằng:

```bash
# Khởi tạo time-budget (LOAD procedures/time-budget.md trước)
parse_max_time
START_TIME=$(date +%s)

# Sort: P0 → P1 → P2 → P3
ENTRIES=$(jq '[.entries[] | select(.status=="pending")] | sort_by(.severity | (if . == "P0" then 0 elif . == "P1" then 1 elif . == "P2" then 2 else 3 end))' "$IMPL_REQ")

echo "$ENTRIES" | jq -c '.[]' | while IFS= read -r entry; do
  IMPL_REQ_ID=$(echo "$entry" | jq -r '.id')
  PRIORITY=$(echo "$entry" | jq -r '.severity')
  
  # Kiểm tra budget trước khi bắt đầu item (trừ P0)
  if ! check_time_budget "$PRIORITY"; then
    echo "INFO: Budget hết hoặc P1 rate < 80% — dừng tại $IMPL_REQ_ID"
    break  # Dừng loop
  fi
  
  # Process item (delegate-impl-feature.md)
  # ...
  
  # Nếu item cần decision → handle_decision_required() thay vì skip
done
```

---

## Summary sau F4

```bash
finalize_f4() {
  local P0_TOTAL=$(jq '[.entries[] | select(.severity=="P0" and .group==3)] | length' "$IMPL_REQ")
  local P0_DONE=$(jq '[.entries[] | select(.severity=="P0" and .group==3 and .status=="done")] | length' "$IMPL_REQ")
  local P1_TOTAL=$(jq '[.entries[] | select(.severity=="P1" and .group==3)] | length' "$IMPL_REQ")
  local P1_DONE=$(jq '[.entries[] | select(.severity=="P1" and .group==3 and .status=="done")] | length' "$IMPL_REQ")
  
  local NOW=$(date +%s)
  local ELAPSED=$((NOW - START_TIME))
  local ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  echo "F4 Summary:"
  echo "  Thời gian: ${ELAPSED}s / ${MAX_TIME_SECONDS}s"
  echo "  P0: ${P0_DONE}/${P0_TOTAL} (phải 100%)"
  echo "  P1: ${P1_DONE}/${P1_TOTAL} (phải ≥80%)"
  
  # Gọi check P1 lần cuối
  if ! check_p1_completion_rate; then
    return 1  # Partial
  fi
  
  # PASS → mark F4 completed
  jq --arg t "$ISO" '
    .steps.F4.status = "completed" |
    .steps.F4.completed_at = $t |
    .current_step = "F5" |
    .next_action = "F4 done → run F5 retest"
  ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
  mv "$E2E_STATUS.tmp" "$E2E_STATUS"
  
  return 0
}
```
