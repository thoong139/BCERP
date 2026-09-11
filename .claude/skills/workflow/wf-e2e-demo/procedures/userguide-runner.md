# F8 — User-Guide Runner Procedure

## Main Flow (v1.1.0 — auto-fix enabled)

```
1. PRE-GATE → Acquire browser-mcp.lock + reader locks (BE/FE/DB/Playwright)
2. Parse user-guide.md → list of steps (sections 2 + 3)
3. Login (theo "Điều kiện chuẩn bị") → screenshot demo-00-login.png
4. FOR each step:
    a. Update status.json current_step_idx
    b. Read action + expected
    c. Execute action (navigate/click/fill/...)
    d. Snapshot + verify expected → match = exact|partial|none
    e. Capture screenshot demo-NN-slug.png
    f. Update status.json steps[idx].match
    g. IF match != exact:
        → APPEND issues.json NGAY (severity theo type)
        → CLASSIFY: accuracy_wording vs real_failure
        → IF accuracy_wording (text diff nhỏ, UI vẫn hoạt động):
            • Log correction vào demo-report
            • Apply qua --auto-correct nếu flag bật
        → IF real_failure (element missing, network error, JS bug, missing data):
            • Delegate sang F7 failure-analyzer pattern (lazy-load shared)
            • Phase 1 browser fix → Phase 2 source code fix (spawn agent)
            • Update issues.json auto_fix object
            • IF auto_fix PASS → continue scenario
            • IF auto_fix FAIL → keep ❌, log resolution
5. Calculate accuracy score
6. IF --auto-correct AND có wording corrections → apply vào user-guide.md atomic write
7. Write demo-report.md với accuracy + corrections list + auto-fix log
8. Release lock → Phase-report.md → DONE
```

---

## Classify: Accuracy Wording vs Real Failure

Sau khi match = `partial` hoặc `none`, phân loại theo signal:

| Signal | Type | Hành động |
|--------|------|-----------|
| DOM có element tương đương nhưng text khác (vd label "Tạo Customer" → "Tạo Khách Hàng") | `accuracy_wording` | Log correction, auto-correct nếu `--auto-correct` |
| Element không tồn tại trong DOM (selector trả về empty) | `real_failure → TEST_SELECTOR or UI_BUG` | Delegate F7 failure-analyzer |
| Action throw error (click on null, navigate timeout) | `real_failure → UI_BUG / NETWORK_ERROR` | Delegate F7 failure-analyzer |
| Action gọi API trả 4xx/5xx | `real_failure → NETWORK_ERROR / AUTH_FAILURE` | Delegate F7 failure-analyzer |
| Expected text về data ("hiển thị danh sách 5 khách hàng") nhưng DOM rỗng | `real_failure → DATA_MISSING` | Delegate F7 failure-analyzer (sẽ apply seed data) |
| Wording đổi + side effect (vd toast khác text + form không reset) | `mixed` | Log wording + delegate F7 cho side effect |

Quy tắc phân biệt nhanh:

```bash
# Sau khi MATCH != exact
classify_step_failure() {
  local ACTION="$1" EXPECTED="$2" SNAPSHOT="$3" CONSOLE="$4" NETWORK="$5"

  # Real failure signals (priority cao)
  if echo "$NETWORK" | jq -e '.[] | select(.status >= 400 and (.url | test("/api/")))' > /dev/null; then
    echo "real_failure"; return
  fi
  if echo "$CONSOLE" | grep -qE "TypeError|undefined is not|Cannot read"; then
    echo "real_failure"; return
  fi
  if echo "$ACTION" | grep -qi "Click\|Nhấn"; then
    LABEL=$(echo "$ACTION" | grep -oP '"[^"]+"' | head -1 | tr -d '"')
    # Element còn trong DOM với text tương tự (>50% từ trùng)?
    SIMILAR=$(echo "$SNAPSHOT" | grep -oiE "$LABEL|$(echo $LABEL | head -c 5)" | head -1)
    if [ -z "$SIMILAR" ]; then
      echo "real_failure"; return  # element không có
    fi
    # Có element tương tự → có thể chỉ đổi text
    echo "accuracy_wording"; return
  fi

  # Default: real_failure nếu không có signal wording rõ ràng
  echo "real_failure"
}
```

---

## Delegate F7 Failure Analyzer (lazy-load shared)

Khi `classify_step_failure` trả `real_failure`:

```bash
# Lazy-load failure-analyzer của F7 — shared procedure (1 lần / session)
if [ "$FAILURE_ANALYZER_LOADED" != "true" ]; then
  source .claude/skills/workflow/wf-e2e-scenario/procedures/failure-analyzer.md.sh 2>/dev/null \
    || echo "INFO: failure-analyzer logic là markdown, agent đọc trực tiếp khi cần"
  FAILURE_ANALYZER_LOADED=true
fi

# Gọi analyzer với context của F8 step
ANALYZE_FAILURE \
  --scenario_num="$STEP_NUM" \
  --scenario_name="Bước $STEP_NUM: $STEP_NAME" \
  --issue_id="$ISSUE_ID" \
  --step_error="$STEP_ERROR" \
  --caller=wf-e2e-demo
```

Lưu ý: F8 dùng cùng 7 failure types + 2-phase auto-fix của F7 — không duplicate logic. Chỉ khác:
- F7 fail → scenario marked ❌, tiếp sang scenario tiếp theo
- F8 fail → step marked ❌, tiếp sang step tiếp theo (cùng flow)
- Auto-fix PASS → mark `✅ PASS (auto-fixed: phase{1|2})`, continue
- Auto-fix FAIL → mark `❌ FAIL (ISS-NNN)`, log resolution, continue

---

## Step Execution Detail

### Parse step block

```
### Bước 3: Tạo Customer mới
- **Hành động:** Click button "Tạo Customer"
- **Kết quả mong đợi:** Modal form "Thông tin Customer" hiện ra với 5 ô input
```

```bash
ACTION_TEXT="Click button \"Tạo Customer\""
EXPECTED_TEXT='Modal form "Thông tin Customer" hiện ra với 5 ô input'
```

### Determine action type

```bash
# Pattern matching:
case "$ACTION_TEXT" in
  *"Click button"*|*"Nhấn nút"*)
    # Extract button label between quotes
    LABEL=$(echo "$ACTION_TEXT" | grep -oP '"[^"]+"' | head -1 | tr -d '"')
    mcp__playwright__browser_click --selector="button:has-text(\"$LABEL\")"
    ;;
  *"Click link"*|*"Nhấn vào liên kết"*)
    LINK=$(echo "$ACTION_TEXT" | grep -oP '"[^"]+"' | head -1 | tr -d '"')
    mcp__playwright__browser_click --selector="a:has-text(\"$LINK\")"
    ;;
  *"Nhập"*|*"Điền"*)
    # "Nhập email = test@example.com vào ô Email"
    FIELD=$(echo "$ACTION_TEXT" | sed 's/.*ô //; s/$//')
    VALUE=$(echo "$ACTION_TEXT" | grep -oP '= \K[^ ]+')
    mcp__playwright__browser_type --selector="input[placeholder*=\"$FIELD\"]" --text="$VALUE"
    ;;
  *"Chọn"*)
    OPTION=$(echo "$ACTION_TEXT" | grep -oP '"[^"]+"' | head -1 | tr -d '"')
    DROPDOWN=$(echo "$ACTION_TEXT" | sed 's/.*dropdown //')
    mcp__playwright__browser_select_option --selector="select" --value="$OPTION"
    ;;
  *"Chờ"*|*"Wait"*)
    DURATION=$(echo "$ACTION_TEXT" | grep -oP '\d+ giây' | grep -oP '\d+')
    mcp__playwright__browser_wait_for --time="$DURATION"
    ;;
  *"Điều hướng"*|*"Navigate"*)
    URL=$(echo "$ACTION_TEXT" | grep -oP 'http[^\s]+|/[a-z/-]+')
    mcp__playwright__browser_navigate --url="$URL"
    ;;
  *)
    # Unknown action → mark PARTIAL, log to corrections
    echo "Unknown action: $ACTION_TEXT" >> "$REPORT"
    MATCH="partial"
    ;;
esac
```

### Verify expected

```bash
# Snapshot
SNAPSHOT=$(mcp__playwright__browser_snapshot)

# Extract keyword from expected
KEYWORD=$(echo "$EXPECTED_TEXT" | head -c 50)

# Check if visible
if echo "$SNAPSHOT" | grep -qi "$KEYWORD"; then
  MATCH="exact"
else
  # Partial check (50% words match)
  WORDS=$(echo "$EXPECTED_TEXT" | tr ' ' '\n' | sort -u)
  MATCHED=0
  TOTAL=0
  while read -r word; do
    [ ${#word} -lt 3 ] && continue  # skip short words
    TOTAL=$((TOTAL+1))
    echo "$SNAPSHOT" | grep -qi "$word" && MATCHED=$((MATCHED+1))
  done <<< "$WORDS"
  
  RATIO=$(echo "scale=2; $MATCHED / $TOTAL" | bc)
  if (( $(echo "$RATIO >= 0.5" | bc -l) )); then
    MATCH="partial"
  else
    MATCH="none"
  fi
fi
```

### Capture + log

```bash
SLUG=$(echo "$STEP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
mcp__playwright__browser_take_screenshot \
  --output="$SCREENSHOTS/demo-${NN}-${SLUG}.png" \
  --full_page=true

# Update status.json
jq --arg n "$STEP_NUM" --arg m "$MATCH" \
  '.steps[($n|tonumber)-1].match = $m' "$STATUS" > "$STATUS.tmp"
mv "$STATUS.tmp" "$STATUS"

# IF MATCH != "exact": log correction
if [ "$MATCH" != "exact" ]; then
  cat >> "$REPORT" <<EOF
### Bước $STEP_NUM: $STEP_NAME

- **user-guide.md says:** $ACTION_TEXT
- **Expected:** $EXPECTED_TEXT
- **Match:** $MATCH
- **Screenshot:** [demo-${NN}-${SLUG}.png](../screenshots/demo-${NN}-${SLUG}.png)

EOF
fi
```

---

## Auto-Correct Mode

Nếu `--auto-correct` flag:

```bash
# After all steps done, apply corrections
# Read demo-report.md "Corrections needed" section
# Use Edit tool để update user-guide.md từng correction

# Example: button label changed
# Edit: old_string="Tạo Customer" → new_string="Tạo Khách Hàng"

# Atomic write: tmp + jq/md-lint validate + mv
# Log changes vào Phase-report.md
```
