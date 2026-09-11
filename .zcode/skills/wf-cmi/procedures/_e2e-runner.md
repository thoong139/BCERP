# Engine — E2E Scenario Runner (v3.0)

> **Stage 4 implemented (2026-05-16)** — port từ `wf-e2e-scenario/procedures/scenario-runner.md`, đổi paths sang wf-cmi session structure.
>
> **Lazy-loaded by:** `procedures/phase9-e2e-execute.md` (Step 9.6 FOR each scenario)
> **Source reference:** `.claude/skills/workflow/wf-e2e-scenario/procedures/scenario-runner.md`

---

## A. Mục đích

Engine đọc `test-scenario-CMI-{NN}-{slug}.md` (CD41 sinh ở Wave 3) → parse frontmatter + bảng Bước → dispatch Playwright MCP execute từng step → verify expected result theo 4 mode → fill "Kết quả thực tế" + "Pass/Fail" vào file scenario → emit issue entry vào `e2e-results.json` nếu FAIL → defer Phase 10 classify.

KHÔNG fallback curl/code-only. Nếu Playwright DOWN hoặc retry exhausted → mark `execution_status="BLOCKED"`.

---

## B. Main Flow (Pseudocode)

```
INPUT:
  SCENARIO_FILE   = path tới test-scenario-CMI-{NN}-{slug}.md
  SCENARIO_INDEX  = số thứ tự (1, 2, ..., N)
  SESSION_DIR     = wf-cmi session subdir
  E2E_RESULTS     = path $SESSION_DIR/phase9-e2e-execute/e2e-results.json
  STRICT_EVIDENCE = "true" | "false" (--strict-evidence flag)
  VIEWPORT        = "desktop" | "mobile" (--mobile flag)

EXECUTION:
  1. PARSE SCENARIO_FILE → extract frontmatter + steps_table
  2. UPDATE e2e-results.json: scenarios[$SCENARIO_INDEX].sub_state = "executing"
  3. NAVIGATE TO entry_url qua playwright_retry(max=3)
     → FAIL sau 3 retries → execution_status = "BLOCKED", APPEND issue, RETURN
  4. FOR each step in steps_table:
     a. CLASSIFY step pattern (Click/Fill/Select/Wait/Navigate)
     b. DISPATCH Playwright MCP tool tương ứng qua execute_with_smart_retry()
     c. CAPTURE browser_snapshot
     d. VERIFY "Kết quả mong đợi" theo 4 mode (element/text/URL/network)
     e. RECORD step_result (PASS | FAIL | UNDETERMINED)
     f. IF FAIL AND --strict-evidence: capture per-step screenshot
  5. CAPTURE final screenshot scenario-{NN}-{slug}.png (qua _screenshot-evidence.md)
  6. FILL "Kết quả thực tế" + "Pass/Fail" vào SCENARIO_FILE (Atomic Write)
  7. APPEND scenario entry vào E2E_RESULTS.scenarios[]
     - execution_status: PASS | FAIL | AUTO_CORRECTED | BLOCKED | QUARANTINED
     - failure_detail (nếu FAIL): {step_num, expected, actual, error_message}
     - auto_fix_attempts[] (nếu có retry trong Phase 9 browser-fix)
     - evidence paths
  8. IF cross_module=true → SỬ DỤNG §D Cross-Module flow thay cho linear

OUTPUT:
  - SCENARIO_FILE updated với Pass/Fail columns
  - E2E_RESULTS appended entry
  - Screenshot files in $SESSION_DIR/phase9-e2e-execute/screenshots/
```

---

## C. Step Pattern Recognition (5 kiểu)

### C.1 Pattern Matching Logic

```bash
# Parse "Hành động" column text → classify pattern + extract params
classify_step_pattern() {
  local STEP_TEXT="$1"
  local STEP_LOWER
  STEP_LOWER=$(echo "$STEP_TEXT" | tr '[:upper:]' '[:lower:]')

  case "$STEP_LOWER" in
    click*|nhấp*|nhấn*)
      echo "CLICK"
      ;;
    fill*|nhập*|gõ*)
      echo "FILL"
      ;;
    select*|chọn*)
      echo "SELECT"
      ;;
    wait*|chờ*)
      echo "WAIT"
      ;;
    navigate*|di\ chuyển*|điều\ hướng*)
      echo "NAVIGATE"
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}
```

### C.2 Dispatch Table

| Pattern (cột "Bước") | Playwright MCP tool | Extract params |
|----------------------|---------------------|----------------|
| `Click <selector>` | `browser_click` | selector = phần sau `Click ` |
| `Click button '<text>'` | `browser_click` (role=button,name=text) | text = giữa `'...'` |
| `Fill <field> = <value>` | `browser_type` HOẶC `browser_fill_form` | field + value |
| `Fill form: {f1: v1, f2: v2}` | `browser_fill_form` (multi field) | parse YAML/JSON inline |
| `Select '<option>' from <dropdown>` | `browser_select_option` | option + dropdown selector |
| `Wait <selector>` | `browser_wait_for` (selector mode) | selector |
| `Wait <Nms>` | `sleep N/1000` | duration (rare — không khuyến khích) |
| `Navigate to <URL>` | `browser_navigate` | URL relative hoặc absolute |

### C.3 Dispatch Pseudocode

```bash
dispatch_step() {
  local PATTERN="$1"
  local STEP_TEXT="$2"
  local SELECTOR VALUE

  case "$PATTERN" in
    CLICK)
      # "Click button 'Lưu'" → role=button, name="Lưu"
      if echo "$STEP_TEXT" | grep -qE "button '([^']+)'"; then
        NAME=$(echo "$STEP_TEXT" | sed -nE "s/.*button '([^']+)'.*/\1/p")
        # mcp__plugin_playwright_playwright__browser_click với role + name
        ACTION="mcp__plugin_playwright_playwright__browser_click element=\"button '$NAME'\" ref=\"button[name='$NAME']\""
      else
        SELECTOR=$(echo "$STEP_TEXT" | sed -nE 's/^[Cc]lick[[:space:]]+//p')
        ACTION="mcp__plugin_playwright_playwright__browser_click element=\"$SELECTOR\" ref=\"$SELECTOR\""
      fi
      ;;
    FILL)
      # "Fill email = test@example.com"
      FIELD=$(echo "$STEP_TEXT" | sed -nE 's/^[Ff]ill[[:space:]]+([^=]+)=.*/\1/p' | tr -d '[:space:]')
      VALUE=$(echo "$STEP_TEXT" | sed -nE 's/^[Ff]ill[[:space:]]+[^=]+=[[:space:]]*(.*)/\1/p')
      ACTION="mcp__plugin_playwright_playwright__browser_type element=\"$FIELD field\" ref=\"input[name='$FIELD']\" text=\"$VALUE\""
      ;;
    SELECT)
      # "Select 'Active' from status dropdown"
      OPTION=$(echo "$STEP_TEXT" | sed -nE "s/.*[Ss]elect '([^']+)' from.*/\1/p")
      DROPDOWN=$(echo "$STEP_TEXT" | sed -nE 's/.*from[[:space:]]+(.*)/\1/p')
      ACTION="mcp__plugin_playwright_playwright__browser_select_option element=\"$DROPDOWN\" ref=\"select[name='$DROPDOWN']\" values=[\"$OPTION\"]"
      ;;
    WAIT)
      # "Wait for save success toast"
      TEXT=$(echo "$STEP_TEXT" | sed -nE 's/^[Ww]ait[[:space:]]+(?:for[[:space:]]+)?(.*)/\1/p')
      ACTION="mcp__plugin_playwright_playwright__browser_wait_for text=\"$TEXT\" time=5"
      ;;
    NAVIGATE)
      # "Navigate to /crm/customers"
      URL=$(echo "$STEP_TEXT" | sed -nE 's/^[Nn]avigate[[:space:]]+to[[:space:]]+(.*)/\1/p')
      [[ "$URL" =~ ^https?:// ]] || URL="${FE_BASE_URL}${URL}"
      ACTION="mcp__plugin_playwright_playwright__browser_navigate url=\"$URL\""
      ;;
    UNKNOWN)
      log_error "E160" "step_parse" "Unknown step pattern: $STEP_TEXT"
      return 1
      ;;
  esac

  # Execute với smart retry (xem _shared.md §22)
  execute_with_smart_retry "$ACTION" "$SCENARIO_ID"
}
```

> **Lưu ý:** Trong runtime thực tế, Claude orchestrator gọi trực tiếp Playwright MCP tools (không phải qua bash exec). Pseudocode trên minh họa pattern; engine procedure file mô tả CONTRACT, executor là Claude với tools list khai báo trong `_contract.json.allowed-tools`.

---

## D. Cross-Module Scenarios

### D.1 Detection

Scenario có `cross_module: true` trong frontmatter + `modules_involved: [moduleA, moduleB, ...]` (≥2 modules) sẽ trigger Cross-Module flow.

CD41 đã đảm bảo `cross_module=true` chỉ set khi violation `affected_modules.length > 1` (xem `procedures/lanes/CD41.md §Step 41.5`).

### D.2 Walk Pattern

```
INPUT:
  modules_involved = ["TMS", "CRM", "Finance"]  (từ frontmatter)
  workflow_graph   = Phase 2 output

WALK FLOW:
  1. Identify upstream → downstream pairs từ workflow-graph nodes
     - workflow-graph nodes có moduleA → edges → moduleB → moduleC
     - Map mỗi module → primary entry URL (qua fe-route-graph)
  2. FOR each module in walk sequence:
     a. NAVIGATE to module's entry URL
     b. EXECUTE module-specific steps (filter rows trong scenario có context module)
     c. CAPTURE screenshot scenario-{NN}-{slug}-{module}.png
     d. RECORD module_visited += [module]
  3. VERIFY reference ID consistency:
     - URL params (customer_id, order_id, invoice_id) phải khớp giữa modules
     - DOM-displayed IDs phải nhất quán (qua browser_evaluate)
  4. VERIFY data consistency:
     - FK references intact (vd order.customer_id phải khớp customer.id)
     - State machine transitions nhất quán
  5. (OPTIONAL) Verify saga compensation nếu test failure path
     - Trigger failure ở module N → verify rollback ở module N-1
```

### D.3 Update e2e-results.json Entry

```jsonc
{
  "scenario_id": "CMI-SC-007",
  "cross_module": true,
  "modules_involved": ["TMS", "CRM", "Finance"],
  "modules_visited": ["TMS", "CRM", "Finance"],  // subset actually navigated
  "reference_id_consistency": {
    "checked": true,
    "consistent": true,
    "references_validated": ["order_id", "customer_id"]
  },
  "data_consistency": {
    "checked": true,
    "consistent": true,
    "fk_pairs_validated": ["orders.customer_id → customers.id"]
  },
  "saga_compensation": null,  // hoặc {checked: true, compensated: true, rollback_states: [...]}
  "evidence": {
    "screenshot_path": "phase9-e2e-execute/screenshots/scenario-07-cross.png",
    "module_screenshots": [
      "phase9-e2e-execute/screenshots/scenario-07-tms.png",
      "phase9-e2e-execute/screenshots/scenario-07-crm.png",
      "phase9-e2e-execute/screenshots/scenario-07-finance.png"
    ]
  }
}
```

---

## E. Expected Result Verification (4 mode)

### E.1 Pattern Detection

Parse cột "Kết quả mong đợi" trong table row → classify verification mode:

| Pattern | Verification mode | Tool |
|---------|-------------------|------|
| `Element <selector> visible` | DOM_ELEMENT | `browser_snapshot` → check ARIA snapshot có element |
| `Text '<text>' appears in <selector>` | DOM_TEXT | `browser_snapshot` → grep text |
| `URL = <pattern>` HOẶC `URL contains <substring>` | URL_MATCH | `browser_evaluate(window.location)` |
| `Network request <METHOD> <url> = <status>` | NETWORK_RESPONSE | `browser_network_requests` filter |
| `Toast notification: '<text>'` | DOM_TEXT (toast selector) | `browser_snapshot` → check toast |

### E.2 Verification Logic

```bash
verify_expected_result() {
  local EXPECTED_TEXT="$1"
  local MODE
  local PASS=false

  # Detect mode
  if echo "$EXPECTED_TEXT" | grep -qE "^Element .* visible$"; then
    MODE="DOM_ELEMENT"
    SELECTOR=$(echo "$EXPECTED_TEXT" | sed -nE 's/^Element (.+) visible$/\1/p')
    # Capture snapshot và check selector
    SNAPSHOT=$(mcp__plugin_playwright_playwright__browser_snapshot 2>/dev/null)
    echo "$SNAPSHOT" | grep -q "$SELECTOR" && PASS=true

  elif echo "$EXPECTED_TEXT" | grep -qE "^URL"; then
    MODE="URL_MATCH"
    # Pattern: "URL = /crm/customers/123" or "URL contains crm"
    if echo "$EXPECTED_TEXT" | grep -q "="; then
      EXPECTED_URL=$(echo "$EXPECTED_TEXT" | sed -nE 's/^URL[[:space:]]*=[[:space:]]*(.+)$/\1/p')
      CURRENT=$(mcp__plugin_playwright_playwright__browser_evaluate function="() => window.location.pathname")
      [ "$CURRENT" = "$EXPECTED_URL" ] && PASS=true
    elif echo "$EXPECTED_TEXT" | grep -q "contains"; then
      SUBSTR=$(echo "$EXPECTED_TEXT" | sed -nE 's/^URL[[:space:]]+contains[[:space:]]+(.+)$/\1/p')
      CURRENT=$(mcp__plugin_playwright_playwright__browser_evaluate function="() => window.location.href")
      echo "$CURRENT" | grep -q "$SUBSTR" && PASS=true
    fi

  elif echo "$EXPECTED_TEXT" | grep -qE "^Network"; then
    MODE="NETWORK_RESPONSE"
    # Pattern: "Network request POST /api/customers = 201"
    METHOD=$(echo "$EXPECTED_TEXT" | sed -nE 's/.*Network request[[:space:]]+([A-Z]+)[[:space:]]+.*/\1/p')
    URL_PATTERN=$(echo "$EXPECTED_TEXT" | sed -nE 's/.*Network request[[:space:]]+[A-Z]+[[:space:]]+([^[:space:]]+).*/\1/p')
    EXPECTED_STATUS=$(echo "$EXPECTED_TEXT" | sed -nE 's/.*=[[:space:]]*([0-9]{3}).*/\1/p')
    NETWORK=$(mcp__plugin_playwright_playwright__browser_network_requests 2>/dev/null)
    echo "$NETWORK" | grep -E "$METHOD.*$URL_PATTERN.*$EXPECTED_STATUS" && PASS=true

  elif echo "$EXPECTED_TEXT" | grep -qE "^Toast notification:"; then
    MODE="DOM_TEXT"
    TEXT=$(echo "$EXPECTED_TEXT" | sed -nE "s/^Toast notification:[[:space:]]*'(.+)'[[:space:]]*\$/\1/p")
    SNAPSHOT=$(mcp__plugin_playwright_playwright__browser_snapshot 2>/dev/null)
    echo "$SNAPSHOT" | grep -q "$TEXT" && PASS=true

  else
    # Fallback: text content match generic
    MODE="DOM_TEXT_GENERIC"
    SNAPSHOT=$(mcp__plugin_playwright_playwright__browser_snapshot 2>/dev/null)
    echo "$SNAPSHOT" | grep -qi "$EXPECTED_TEXT" && PASS=true
  fi

  if $PASS; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}
```

> **MODE=UNDETERMINED** khi `browser_snapshot` fail (E161) — engine vẫn record nhưng KHÔNG mark FAIL automatic. Caller (Phase 9) decide skip vs retry.

---

## F. Atomic Update test-scenario.md

Sau khi execute xong 1 scenario, fill "Kết quả thực tế" + "Pass/Fail" columns vào file scenario.

### F.1 Pattern

```bash
update_scenario_file() {
  local SCENARIO_FILE="$1"
  local SCENARIO_NUM="$2"  # 1-indexed
  local STEP_RESULTS_JSON="$3"  # JSON array per step: [{step:1, actual:"...", pass:true}, ...]
  local FINAL_STATUS="$4"  # PASS | FAIL | AUTO_CORRECTED | BLOCKED | QUARANTINED
  local SCREENSHOT_PATH="$5"
  local DURATION_SEC="$6"
  local RETRY_COUNT="$7"

  TMP="${SCENARIO_FILE}.tmp.$$"

  # 1. Read scenario file
  # 2. Tìm bảng Bước → cập nhật cột "Kết quả thực tế" + "Pass/Fail" cho từng row
  #    (Sử dụng awk: track row index trong table, replace cells 4+5)
  awk -v results_json="$STEP_RESULTS_JSON" '
    BEGIN {
      in_table = 0
      step_idx = 0
    }
    /^\|.*Bước.*Hành động.*Kết quả mong đợi.*Kết quả thực tế.*Pass\/Fail.*\|$/ {
      in_table = 1
      print
      next
    }
    in_table && /^\|--/ {
      print
      next
    }
    in_table && /^\|/ {
      step_idx++
      # Parse step results JSON để tìm actual + pass cho step_idx
      # (Đơn giản hóa: dùng jq external hoặc parse trong shell wrapper)
      # Pseudocode: substitute cell 4 (actual) và cell 5 (pass) với data
      print
      next
    }
    in_table && !/^\|/ {
      in_table = 0
      print
      next
    }
    { print }
  ' "$SCENARIO_FILE" > "$TMP"

  # 3. Append "**Evidence:** ..." sau bảng
  printf '\n**Evidence:** [screenshots/%s](../screenshots/%s)\n' \
    "$(basename "$SCREENSHOT_PATH")" "$(basename "$SCREENSHOT_PATH")" >> "$TMP"

  # 4. Append "**Execution:** ..."
  printf '**Execution:** %s (%ds, retry=%d)\n' \
    "$FINAL_STATUS" "$DURATION_SEC" "$RETRY_COUNT" >> "$TMP"
  printf '**Tested by:** wf-cmi v3.0 Phase 9 at %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TMP"

  # 5. Atomic move
  mv "$TMP" "$SCENARIO_FILE"
}
```

### F.2 Markdown Update Example

**Before** (CD41 sinh ra):

```markdown
| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|------------------|------------------|-----------|
| 1 | Navigate to /crm/customers/new | Form modal hiện | | |
| 2 | Fill name = Test | Field updated | | |
| 3 | Click button 'Lưu' | Toast 'Lưu thành công' | | |
```

**After** (Phase 9 fill):

```markdown
| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|------------------|------------------|-----------|
| 1 | Navigate to /crm/customers/new | Form modal hiện | Form modal đã render | ✅ PASS |
| 2 | Fill name = Test | Field updated | Field value="Test" | ✅ PASS |
| 3 | Click button 'Lưu' | Toast 'Lưu thành công' | Element 'button[type=submit]' not found | ❌ FAIL |

**Evidence:** [screenshots/scenario-01-tao-customer-failed.png](../screenshots/scenario-01-tao-customer-failed.png)
**Execution:** FAIL (8s, retry=3)
**Tested by:** wf-cmi v3.0 Phase 9 at 2026-05-16T14:23:45Z
```

---

## G. Issue Entry Schema (vào e2e-results.json scenarios[])

Khi scenario có ≥1 step FAIL → APPEND entry vào `e2e-results.json` theo schema `e2e-results-v1`.

### G.1 Schema

```jsonc
{
  "scenario_id": "CMI-SC-001",
  "scenario_file": "phase4-coverage/lanes/CD41-e2e-synth/scenarios/test-scenario-CMI-01-tao-customer-must-fail.md",
  "execution_status": "FAIL",  // PASS | FAIL | AUTO_CORRECTED | QUARANTINED | BLOCKED | NOT_EXECUTED
  "started_at": "2026-05-16T14:23:37Z",
  "completed_at": "2026-05-16T14:23:45Z",
  "duration_ms": 8120,
  "steps_total": 3,
  "steps_passed": 2,
  "steps_failed_at": 3,  // -1 nếu all PASS
  "evidence": {
    "screenshot_path": "phase9-e2e-execute/screenshots/scenario-01-tao-customer-failed.png",
    "console_log_path": "phase9-e2e-execute/evidence/scenario-01-console.log",
    "network_log_path": "phase9-e2e-execute/evidence/scenario-01-network.json",
    "dom_snapshot_path": "phase9-e2e-execute/evidence/scenario-01-dom.html",
    "evidence_complete": true
  },
  "cross_module": false,
  "modules_visited": ["CRM"],
  "source_violation_id": "CMI-V-abc12345",
  "source_invariant_id": "INV-CRM-001",
  "source_dim": "CD11",
  "severity": "HIGH",
  "failure_detail": {
    "step_num": 3,
    "expected": "Toast 'Lưu thành công'",
    "actual": "Element 'button[type=submit]' not found",
    "error_message": "TimeoutError: Element not found after 5000ms",
    "failure_type_hint": "TEST_SELECTOR"  // hint cho Phase 10 classify (không bắt buộc)
  },
  "auto_fix_attempts": [
    {
      "attempt": 1,
      "strategy": "selector_fallback_button_role",
      "outcome": "FAIL",
      "duration_ms": 2000
    },
    {
      "attempt": 2,
      "strategy": "selector_fallback_text_match",
      "outcome": "FAIL",
      "duration_ms": 2500
    },
    {
      "attempt": 3,
      "strategy": "page_reload_retry",
      "outcome": "FAIL",
      "duration_ms": 3500
    }
  ],
  "phase10_resolution_ref": null  // populated by Phase 10
}
```

### G.2 Append Logic

```bash
append_issue_entry() {
  local E2E_RESULTS="$1"  # path tới e2e-results.json
  local ENTRY_JSON="$2"   # đã build sẵn dạng JSON object

  TMP="${E2E_RESULTS}.tmp.$$"

  # Atomic JSON append (CORE-035)
  jq --argjson entry "$ENTRY_JSON" '.scenarios += [$entry]' "$E2E_RESULTS" > "$TMP"
  jq '.' "$TMP" > /dev/null || { rm -f "$TMP"; log_error "E160" "results_write" "Invalid JSON after append"; return 1; }
  mv "$TMP" "$E2E_RESULTS"
}

# Update summary counters
update_results_summary() {
  local E2E_RESULTS="$1"
  TMP="${E2E_RESULTS}.tmp.$$"
  jq '
    .summary.n_total = (.scenarios | length) |
    .summary.n_executed = ([.scenarios[] | select(.execution_status != "NOT_EXECUTED")] | length) |
    .summary.n_pass = ([.scenarios[] | select(.execution_status == "PASS")] | length) |
    .summary.n_fail = ([.scenarios[] | select(.execution_status == "FAIL")] | length) |
    .summary.n_auto_corrected = ([.scenarios[] | select(.execution_status == "AUTO_CORRECTED")] | length) |
    .summary.n_quarantined = ([.scenarios[] | select(.execution_status == "QUARANTINED")] | length) |
    .summary.n_blocked = ([.scenarios[] | select(.execution_status == "BLOCKED")] | length) |
    .summary.n_cross_module = ([.scenarios[] | select(.cross_module == true)] | length)
  ' "$E2E_RESULTS" > "$TMP" && mv "$TMP" "$E2E_RESULTS"
}
```

---

## H. Failure Handling

### H.1 Classification (Hint Only)

Engine emit `failure_detail.failure_type_hint` (best-guess heuristic):

| Error message pattern | failure_type_hint |
|----------------------|--------------------|
| `Element not found`, `selector`, `no element` | TEST_SELECTOR |
| `401`, `403`, `Unauthorized`, `Forbidden` | AUTH_FAILURE |
| `404`, `Not Found`, `không tìm thấy` | DATA_MISSING |
| `5xx`, `Internal Server Error`, `ECONNREFUSED` | NETWORK_ERROR |
| `TypeError`, `null`, `undefined is not` (trong console) | UI_BUG |
| Expected != Actual (assertion mismatch) | BUSINESS_RULE |
| Khác | UNKNOWN |

Phase 10 sẽ re-classify với evidence đầy đủ (console + network + DOM) — engine chỉ provide hint.

### H.2 Defer Phase 10

Nếu `execution_status == "FAIL"` (sau khi exhausted auto-fix budget 3 retry trong Phase 9):

```bash
# Step 9.6.g defer logic
# KHÔNG xử lý FAIL trong engine — chỉ APPEND entry vào e2e-results.json
# Phase 10 sẽ:
#   1. Load e2e-results.json FAIL entries
#   2. Per entry: collect evidence (console/network/DOM)
#   3. Classify failure_type với evidence đầy đủ
#   4. 2-phase auto-fix (browser-fix → source-fix nếu --auto-fix-source)
#   5. Loop-back gap-suggestions kind="e2e_scenario_fix"
```

---

## I. Cross-References

| Reference | Purpose |
|-----------|---------|
| `procedures/phase9-e2e-execute.md` | Consumer (Step 9.6 — engine entry point) |
| `procedures/_shared.md §22` | `execute_with_smart_retry()` + `classify_failure()` |
| `procedures/_shared.md §21` | Browser lock (acquired ở Step 9.2, held suốt Phase 9) |
| `procedures/_screenshot-evidence.md` | Screenshot convention + cleanup policy |
| `procedures/_failure-analyzer.md` | Consumer (Phase 10 reads issue entries) |
| `procedures/lanes/CD41.md` | Producer (synth scenario files được engine đọc) |
| `templates/e2e-results.json` | Schema `e2e-results-v1` (output entry format) |
| `templates/test-scenario.template.md` | Schema scenario .md input |
| **Source** `.claude/skills/workflow/wf-e2e-scenario/procedures/scenario-runner.md` | Port reference (Stage 10 sẽ DEPRECATE) |

---

> **Stage 4 implemented (2026-05-16)** — engine sẵn sàng cho Phase 9 Step 9.6 dispatch.
> Stage 5 Phase 10 sẽ port `failure-analyzer.md` để consume issue entries từ engine.
