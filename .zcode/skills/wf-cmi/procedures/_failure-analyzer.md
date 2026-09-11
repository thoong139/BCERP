# Engine — Failure Analyzer (v3.0)

> **Stage 5 implemented (2026-05-16)** — full 7-type classification + 2-phase auto-fix + loop-back schema. Port từ `wf-e2e-scenario/procedures/failure-analyzer.md`, đổi paths sang wf-cmi session structure + thêm CMI context (invariant_id, modules_involved, source_dim từ scenarios-manifest).
>
> **Lazy-loaded by:** `procedures/phase10-e2e-resolution.md` (Step 10.2 FOR each FAIL issue)
> **Source:** `.claude/skills/workflow/wf-e2e-scenario/procedures/failure-analyzer.md`
> **Port strategy:** Engine logic giữ nguyên 100% (7-type classify priority + 2-phase auto-fix decision matrix); paths đổi `issues.json` → `e2e-results.json`; context enrich thêm 3 CMI fields (invariant_id, modules_involved, source_dim) từ scenario frontmatter.

---

## A. Mục đích

Engine phân tích từng FAIL issue trong `e2e-results.json`:
1. Collect evidence (console / network / DOM snapshot)
2. Classify failure_type theo 7-type priority order (deterministic, dừng tại match đầu)
3. Xác định layer + suggested owner agent
4. Render resolution direction từ template per type (điền context thực tế)
5. Enrich `e2e-results.json` entry với failure analysis + evidence_refs
6. Accumulate vào `$RESOLUTION_ACCUMULATOR` cho `resolution-report.md` (Step 10.4)
7. **Auto-Fix Attempt** — 2-phase: Phase A browser-fix → Phase B source-code-fix (spawn agent, chỉ khi `--auto-fix-source` + CDG E195 confirm)
8. Append loop-back gap-suggestion kind=`e2e_scenario_fix` (Step 10.3)

**Nguyên tắc:** Không block execution — chỉ enrich + tích lũy. Auto-fix có budget 3 retries/issue (Phase A + Phase B tổng).

---

## B. Bước 1 — Thu Thập Evidence Bổ Sung

```bash
collect_failure_evidence() {
  local ISSUE_ID="$1"

  # 1a. Console messages (JS errors, warnings, logs)
  # Runtime: mcp__plugin_playwright_playwright__browser_console_messages
  CONSOLE_RAW=$(invoke_browser_console_messages 2>/dev/null || echo "[]")

  # 1b. Network requests (API calls, HTTP status codes)
  # Runtime: mcp__plugin_playwright_playwright__browser_network_requests
  NETWORK_RAW=$(invoke_browser_network_requests 2>/dev/null || echo "[]")

  # 1c. DOM snapshot (HTML/text content)
  # Runtime: mcp__plugin_playwright_playwright__browser_snapshot
  DOM_RAW=$(invoke_browser_snapshot 2>/dev/null || echo "")

  # Track partial evidence (set EVIDENCE_PARTIAL=true nếu bất kỳ tool nào fail/timeout)
  EVIDENCE_PARTIAL=false
  [ -z "$CONSOLE_RAW" ] || [ "$CONSOLE_RAW" = "[]" ] && CONSOLE_LINES=0 || \
    CONSOLE_LINES=$(echo "$CONSOLE_RAW" | jq 'length' 2>/dev/null || echo 0)
  [ -z "$NETWORK_RAW" ] || [ "$NETWORK_RAW" = "[]" ] && NETWORK_COUNT=0 || \
    NETWORK_COUNT=$(echo "$NETWORK_RAW" | jq 'length' 2>/dev/null || echo 0)
  DOM_BYTES=${#DOM_RAW}

  [ "$DOM_BYTES" -lt 100 ] && EVIDENCE_PARTIAL=true && \
    log_error "E181" "phase10_analyzer" "DOM snapshot < 100 bytes — partial evidence"
}
```

Nếu bất kỳ tool nào fail/timeout:
- Log **E181** (severity=low) vào `error-ledger.json`
- Set `EVIDENCE_PARTIAL=true`
- Tiếp tục classify với evidence đã thu thập được (KHÔNG abort)

---

## C. Bước 2 — Phân Loại Failure Type (7-Type Priority)

Áp dụng rules theo thứ tự ưu tiên — dừng tại match đầu tiên:

| Priority | `failure_type` | Detection Pattern | Notes |
|----------|---------------|-------------------|-------|
| 1 | `NETWORK_ERROR` | `$NETWORK_RAW` chứa entry có URL khớp `/api/` VÀ status ∈ {400,401,403,404,409,422,429,500,502,503,504} | Generic API failure |
| 2 | `AUTH_FAILURE` | `$NETWORK_RAW` chứa 401/403 HOẶC `$DOM_RAW` chứa: "không có quyền" / "unauthorized" / "Forbidden" / "Access denied" | **Override NETWORK_ERROR** khi status=401/403 (auth fix khác generic network) |
| 3 | `DATA_MISSING` | `$NETWORK_RAW` chứa 404 HOẶC `$DOM_RAW` chứa: "không tìm thấy" / "no data" / "Chưa có dữ liệu" / "No results" / "0 kết quả" | Seed/migration issue |
| 4 | `TEST_SELECTOR` | Step error message chứa: "Element not found" / "selector not found" / "No element matches" / "locator.click: Error" / "strict mode violation" | Test issue, không phải app bug |
| 5 | `UI_BUG` | `$CONSOLE_RAW` chứa: "TypeError" / "Cannot read" / "Cannot access" / "null" / "undefined is not" / "is not a function" | Frontend runtime error |
| 6 | `BUSINESS_RULE` | Không match rules trên VÀ DOM có nội dung hiển thị (không blank/404 page) | Catch-all: với CMI context dùng `modules_involved` + `invariant_id` để route domain expert |
| 7 | `UNKNOWN` | Không match bất kỳ pattern nào | Log **E180** (medium), `failure_type=UNKNOWN`, SKIP auto-fix |

```bash
classify_failure_type() {
  local STEP_ERROR="$1"

  # Priority 2 trước Priority 1: AUTH_FAILURE override NETWORK_ERROR khi 401/403
  if echo "$NETWORK_RAW" | jq -e 'any(.status == 401 or .status == 403)' >/dev/null 2>&1; then
    FAILURE_TYPE="AUTH_FAILURE"
    return 0
  fi
  if echo "$DOM_RAW" | grep -qiE "không có quyền|unauthorized|forbidden|access denied"; then
    FAILURE_TYPE="AUTH_FAILURE"
    return 0
  fi

  # Priority 1: NETWORK_ERROR (4xx/5xx khác 401/403)
  if echo "$NETWORK_RAW" | jq -e 'any((.url | test("/api/")) and (.status >= 400 and .status < 600 and .status != 401 and .status != 403))' >/dev/null 2>&1; then
    FAILURE_TYPE="NETWORK_ERROR"
    return 0
  fi

  # Priority 3: DATA_MISSING
  if echo "$NETWORK_RAW" | jq -e 'any(.status == 404)' >/dev/null 2>&1; then
    FAILURE_TYPE="DATA_MISSING"
    return 0
  fi
  if echo "$DOM_RAW" | grep -qiE "không tìm thấy|no data|chưa có dữ liệu|no results|0 kết quả"; then
    FAILURE_TYPE="DATA_MISSING"
    return 0
  fi

  # Priority 4: TEST_SELECTOR
  if echo "$STEP_ERROR" | grep -qiE "element not found|selector not found|no element matches|locator\.click: error|strict mode violation"; then
    FAILURE_TYPE="TEST_SELECTOR"
    return 0
  fi

  # Priority 5: UI_BUG
  if echo "$CONSOLE_RAW" | grep -qiE "TypeError|cannot read|cannot access|null|undefined is not|is not a function"; then
    FAILURE_TYPE="UI_BUG"
    return 0
  fi

  # Priority 6: BUSINESS_RULE (DOM có content, không match patterns trên)
  if [ "$DOM_BYTES" -gt 500 ]; then
    FAILURE_TYPE="BUSINESS_RULE"
    return 0
  fi

  # Priority 7: UNKNOWN
  FAILURE_TYPE="UNKNOWN"
  log_error "E180" "phase10_analyzer" "Classification UNKNOWN — failure_type fallback"
  return 0
}
```

**Lưu ý priority override:** AUTH_FAILURE (priority 2) override NETWORK_ERROR (priority 1) khi status=401/403 vì auth issues có hướng giải quyết khác (RBAC config) với generic network errors (endpoint fix).

---

## D. Bước 3 — Xác Định Layer + Owner Agent

| `failure_type` | `affected_layer` | `suggested_owner` | Co-spawn (domain signal) |
|----------------|-----------------|-------------------|-------------------------|
| `NETWORK_ERROR` | `backend` | `developer` | domain-expert theo `modules_involved` |
| `AUTH_FAILURE` | `backend` | `security` | `developer` (RBAC middleware) |
| `DATA_MISSING` | `database` | `dba` | `developer` (nếu cần API seed endpoint) |
| `TEST_SELECTOR` | `test` | `qa-lead` | — (single owner) |
| `UI_BUG` | `frontend` | `frontend-developer` | — |
| `BUSINESS_RULE` | `architecture` | `architect` | `developer` + domain-expert (logistics/finance/compliance) theo `modules_involved` |
| `UNKNOWN` | `unknown` | `qa-lead` | manual triage |

**Domain expert co-spawn** route theo `modules_involved` từ scenario frontmatter (CMI-specific enrichment vs wf-e2e-scenario):

```bash
infer_domain_expert() {
  local MODULES_JSON="$1"  # e.g., ["EW-CRM", "EW-FIN-AR"]
  local AGENTS=()

  for MOD in $(echo "$MODULES_JSON" | jq -r '.[]'); do
    case "$MOD" in
      EW-FIN-*|*FIN*|*ACCOUNTING*|*AR*|*AP*|*GL*)
        AGENTS+=("finance-expert") ;;
      EW-LOG-*|*LOG*|*TMS*|*WMS*|*CUSTOMS*|*HSCODE*)
        AGENTS+=("logistics-expert") ;;
      EW-COMP-*|*COMP*|*AUDIT*|*REGULATORY*)
        AGENTS+=("compliance-expert") ;;
      EW-HR-*|*HR*|*PAYROLL*|*EMPLOYEE*)
        AGENTS+=("hr-expert") ;;
      EW-CRM-*|*CRM*|*CUSTOMER*|*SALES*)
        AGENTS+=("sales-expert") ;;
    esac
  done

  # Dedupe
  printf '%s\n' "${AGENTS[@]}" | sort -u | jq -R . | jq -s .
}
```

---

## E. Bước 4 — Resolution Direction (Template per Type)

Điền context thực tế từ evidence vào template. Dùng dữ liệu cụ thể khi có (method, url, status, error message, invariant_expression).

### E.1 NETWORK_ERROR

```
"API [method] [url] trả về [status]. Kiểm tra:
 1) Controller/handler tại endpoint này
 2) Service/usecase business logic
 3) DB query hoặc entity mapping
 (CMI invariant: [invariant_expression] — modules: [modules_involved])"
```

→ Lấy `[method]`, `[url]`, `[status]` từ entry `failed_request` trong NETWORK evidence.

### E.2 AUTH_FAILURE

```
"Permission bị từ chối ([status]). Kiểm tra:
 1) Role của user test trong seed data có đủ quyền không (actor=[scenario.actor])
 2) Permission matrix trong RBAC config
 3) Auth middleware/guard tại endpoint [url]"
```

### E.3 DATA_MISSING

```
"Dữ liệu không tồn tại ([url] → [status]). Kiểm tra:
 1) Seed data / test fixtures đã tạo chưa (xem db-seed-data.md từ Phase 2)
 2) Migration đã chạy chưa (modules: [modules_involved])
 3) Bước tạo data trước trong scenario có pass không"
```

### E.4 TEST_SELECTOR

```
"Selector không tìm thấy — có thể là test issue (không phải app bug). Kiểm tra:
 1) UI component đã đổi cấu trúc DOM so với lúc viết test
 2) Text/label đổi wording
 3) Cập nhật selector trong bước test-scenario.md tương ứng (file [scenario_file])
 Chạy lại với --show-browser để xem trực tiếp"
```

### E.5 UI_BUG

```
"JavaScript runtime error: [error_message]. Kiểm tra:
 1) Null/undefined check trong component liên quan
 2) Props typing và data loading state
 3) Error boundary có bắt được không"
```

→ Lấy `[error_message]` từ CONSOLE (rút gọn xuống ≤80 ký tự).

### E.6 BUSINESS_RULE

```
"UI render kết quả sai so với mong đợi (không có JS error, không có network error).
 CMI invariant violated: [invariant_id] — [invariant_expression]
 Modules involved: [modules_involved]
 Kiểm tra:
 1) Business logic trong service/usecase liên quan
 2) Data transformation và mapping giữa API và UI
 3) Điều kiện hiển thị phía frontend (computed/derived state)
 4) Cross-module saga compensation (nếu cross_module=true)"
```

### E.7 UNKNOWN

```
"Không xác định được nguyên nhân tự động.
 Xem screenshot scenario-[NN]-[slug]-error.png và console log để debug thủ công.
 Gợi ý: chạy lại với --show-browser để quan sát trực tiếp.
 Evidence: console=[console_lines] lines, network=[network_count] requests, dom=[dom_bytes] bytes"
```

---

## F. Bước 5 — Enrich e2e-results.json Entry (Atomic Write)

Đọc `e2e-results.json`, tìm entry theo `issue_id` hiện tại, enrich bằng Atomic Write Pattern (CORE-035):

```bash
enrich_e2e_results_entry() {
  local ISSUE_ID="$1"
  local E2E_RESULTS_FILE="$SESSION_DIR/phase9-e2e-execute/e2e-results.json"
  local TMP="${E2E_RESULTS_FILE}.tmp.$$"

  # Build evidence_refs JSON
  local CONSOLE_TOP3=$(echo "$CONSOLE_RAW" | jq '[.[] | select(.type == "error")] | .[0:3]' 2>/dev/null || echo "[]")
  local FAILED_REQS=$(echo "$NETWORK_RAW" | jq '[.[] | select(.status >= 400 and .status < 600)] | .[0:5]' 2>/dev/null || echo "[]")

  local EVIDENCE_REFS_JSON=$(jq -n \
    --arg ss "$SCREENSHOT_PATH" \
    --argjson cons "$CONSOLE_TOP3" \
    --argjson reqs "$FAILED_REQS" \
    --arg dom_excerpt "$(echo "$DOM_RAW" | head -c 500)" \
    '{
      screenshot_error: $ss,
      console_errors: $cons,
      failed_requests: $reqs,
      dom_excerpt: $dom_excerpt
    }')

  # Atomic write enrich
  jq --arg id "$ISSUE_ID" \
     --arg ft "$FAILURE_TYPE" \
     --arg layer "$AFFECTED_LAYER" \
     --arg res "$RESOLUTION_DIRECTION" \
     --arg owner "$SUGGESTED_OWNER" \
     --argjson partial "$EVIDENCE_PARTIAL" \
     --argjson evidence_refs "$EVIDENCE_REFS_JSON" \
     --argjson cons_lines "$CONSOLE_LINES" \
     --argjson net_count "$NETWORK_COUNT" \
     --argjson dom_bytes "$DOM_BYTES" \
     --arg analyzer_ver "wf-cmi/_failure-analyzer v3.0.0" \
     '(.issues[] | select(.issue_id == $id)) += {
        failure_type: $ft,
        layer: $layer,
        owner_agent: $owner,
        resolution_direction: $res,
        evidence_collected: {
          console_lines: $cons_lines,
          network_requests: $net_count,
          dom_snapshot_bytes: $dom_bytes,
          evidence_partial: $partial
        },
        evidence_refs: $evidence_refs,
        resolution_analyzed_by: $analyzer_ver
     }' "$E2E_RESULTS_FILE" > "$TMP"

  # Validate JSON then atomic move
  if jq -e '."$schema" == "e2e-results-v1"' "$TMP" >/dev/null 2>&1; then
    mv "$TMP" "$E2E_RESULTS_FILE"
  else
    rm -f "$TMP"
    log_error "E181" "phase10_analyzer" "Atomic write fail khi enrich e2e-results.json — schema invalid"
    return 1
  fi
}
```

---

## G. Bước 6 — Append vào Resolution Accumulator

Append một markdown table row vào biến session `$RESOLUTION_ACCUMULATOR` để Step 10.4 dùng tạo `resolution-report.md`:

```bash
append_resolution_accumulator() {
  local SCENARIO_NUM="$1"
  local SCENARIO_NAME="$2"

  local RESOLUTION_ROW="| ${SCENARIO_NUM} | ${SCENARIO_NAME} | ${FAILURE_TYPE} | ${AFFECTED_LAYER} | ${RESOLUTION_DIRECTION:0:80}... | ${SUGGESTED_OWNER} |"
  RESOLUTION_ACCUMULATOR="${RESOLUTION_ACCUMULATOR}
${RESOLUTION_ROW}"
}
```

---

## H. Bước 7 — Auto-Fix Attempt (2-Phase)

> Chạy SAU Bước 1-6. Auto-fix có quyền sửa source code (Phase B) chỉ khi `--auto-fix-source` bật + CDG E195 confirm.
> **2-Phase model:** Phase A browser-fix (nhanh, không đụng code) → Phase B source-code-fix (spawn agent sửa file thật).
> **Budget:** Max 3 retries/issue (Phase A x2 attempts + Phase B x1 attempt). Nếu cả 2 phase fail → giữ FAIL gốc (log E192).

### H.1 Bảng Quyết Định Auto-Fix

| `failure_type` | Phase A (Browser Fix) | Phase B (Source Code Fix) | Agent Spawn |
|----------------|----------------------|--------------------------|-------------|
| `TEST_SELECTOR` | Thử 3 selector variants (data-testid → role+name → CSS) | Sửa selector trong test-scenario.md step | `qa-lead` |
| `AUTH_FAILURE` | Re-login (session refresh) | Fix RBAC config / permission middleware | `security` + `developer` |
| `NETWORK_ERROR` 5xx | Wait 3s → retry (transient check) | Fix backend endpoint / handler / service | `developer` + domain-expert |
| `NETWORK_ERROR` 4xx | — (skip Phase A) | Fix validation / routing / request schema | `developer` + domain-expert |
| `UI_BUG` | Reload page → retry (transient check) | Fix component null check / loading state | `frontend-developer` |
| `BUSINESS_RULE` | — (skip Phase A) | Fix service / usecase logic | `developer` + domain-expert (logistics/finance/compliance) |
| `DATA_MISSING` | Apply seed từ Phase 2 db-seed-data.md HOẶC tạo qua UI form | Tạo seed script / migration / API seed | `dba` + `developer` |
| `UNKNOWN` | ❌ SKIP | ❌ SKIP | — |

> **Tại sao UNKNOWN không fix:** Không có signal cụ thể — spawn agent mà không biết fix gì sẽ tạo code sai hoặc gây side-effect khó kiểm soát.

---

### H.2 Phase A — Browser Fix (KHÔNG sửa source code)

#### H.2.a TEST_SELECTOR — Thử 3 Selector Variants

```bash
phase_a_test_selector() {
  local BUTTON_TEXT="$1"
  local TESTID=$(echo "$BUTTON_TEXT" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')

  # Variant 1: data-testid (preferred — most stable)
  if mcp__plugin_playwright_playwright__browser_click "[data-testid=${TESTID}]" 2>/dev/null; then
    P1_RESULT=PASS
    P1_STRATEGY="selector_variant_data_testid"
    P1_SELECTOR_WORKED="[data-testid=${TESTID}]"
    return 0
  fi

  # Variant 2: ARIA role + name
  if mcp__plugin_playwright_playwright__browser_click "role=button[name='${BUTTON_TEXT}']" 2>/dev/null; then
    P1_RESULT=PASS
    P1_STRATEGY="selector_variant_role_name"
    P1_SELECTOR_WORKED="role=button[name='${BUTTON_TEXT}']"
    return 0
  fi

  # Variant 3: CSS text selector fallback
  if mcp__plugin_playwright_playwright__browser_click "text=${BUTTON_TEXT}" 2>/dev/null; then
    P1_RESULT=PASS
    P1_STRATEGY="selector_variant_text"
    P1_SELECTOR_WORKED="text=${BUTTON_TEXT}"
    return 0
  fi

  P1_RESULT=FAIL
  P1_NOTE="3/3 selector variants failed — chuyển Phase B"
  return 1
}
```

#### H.2.b AUTH_FAILURE — Re-Login

```bash
phase_a_auth_failure() {
  local FE_BASE_URL="${FE_BASE_URL:-http://localhost:3000}"
  local SYSADMIN_EMAIL="${TEST_SYSADMIN_EMAIL:-sysadmin@erktransport.local}"
  local SYSADMIN_PASS="${TEST_SYSADMIN_PASS:-SysAdmin@123}"

  mcp__plugin_playwright_playwright__browser_navigate "${FE_BASE_URL}/login"
  mcp__plugin_playwright_playwright__browser_fill_form "[
    {\"name\":\"email\",\"value\":\"${SYSADMIN_EMAIL}\"},
    {\"name\":\"password\",\"value\":\"${SYSADMIN_PASS}\"}
  ]"
  mcp__plugin_playwright_playwright__browser_click "button[type=submit]"
  mcp__plugin_playwright_playwright__browser_wait_for "[data-testid=dashboard]" 10000

  # Re-run toàn bộ scenario từ đầu
  if re_execute_full_scenario; then
    P1_RESULT=PASS
    P1_STRATEGY="re_login"
    return 0
  fi

  P1_RESULT=FAIL
  P1_NOTE="Re-login OK nhưng scenario vẫn 401/403 — RBAC bug thật, chuyển Phase B"
  return 1
}
```

#### H.2.c NETWORK_ERROR 5xx — Transient Retry

```bash
phase_a_network_5xx() {
  sleep 3

  # Re-execute bước API thất bại
  local NETWORK_RETRY=$(mcp__plugin_playwright_playwright__browser_network_requests 2>/dev/null)

  if ! echo "$NETWORK_RETRY" | jq -e 'any(.status >= 500 and .status < 600)' >/dev/null 2>&1; then
    P1_RESULT=PASS
    P1_STRATEGY="transient_retry_3s"
    return 0
  fi

  P1_RESULT=FAIL
  P1_NOTE="5xx persistent sau 3s wait — confirmed non-transient, chuyển Phase B"
  return 1
}
```

#### H.2.d UI_BUG — Page Reload

```bash
phase_a_ui_bug() {
  mcp__plugin_playwright_playwright__browser_evaluate "() => window.location.reload()"
  mcp__plugin_playwright_playwright__browser_wait_for "body" 8000
  sleep 2  # async data fetch

  local CONSOLE_AFTER=$(mcp__plugin_playwright_playwright__browser_console_messages 2>/dev/null || echo "[]")

  # Console sạch (không còn TypeError) + retry scenario PASS
  if ! echo "$CONSOLE_AFTER" | grep -qiE "TypeError|cannot read|undefined is not"; then
    if re_execute_full_scenario; then
      P1_RESULT=PASS
      P1_STRATEGY="page_reload"
      return 0
    fi
  fi

  P1_RESULT=FAIL
  P1_NOTE="TypeError vẫn còn sau reload — bug thật trong component, chuyển Phase B"
  return 1
}
```

#### H.2.e DATA_MISSING — Apply Seed hoặc UI Create

```bash
phase_a_data_missing() {
  # Strategy 1 (preferred): Apply seed từ Phase 2 db-seed-data.md
  local SEED_FILE="${SESSION_DIR}/findings/db-seed-data.md"
  if [ -f "$SEED_FILE" ]; then
    # Acquire writer lock cho database resource (Protocol 22)
    if acquire_writer_lock database "$SESSION_ID" "$FEAT_ID" "apply_seed_phase10"; then
      # Extract SQL INSERT blocks
      awk '/^```sql/,/^```$/' "$SEED_FILE" | grep -v '^```' > "/tmp/seed-${SESSION_ID}.sql"

      # Execute qua psql
      local CONN_STR="${POSTGRES_CONN:-$(grep -m1 ConnectionStrings apps/backend/Eureka.Api/appsettings.Development.json | jq -r '.ConnectionStrings.DefaultConnection' 2>/dev/null)}"

      if [ -n "$CONN_STR" ] && psql "$CONN_STR" -v ON_ERROR_STOP=1 -f "/tmp/seed-${SESSION_ID}.sql" 2>&1 | tail -20; then
        if re_execute_full_scenario; then
          P1_RESULT=PASS
          P1_STRATEGY="seed_data_apply"
          P1_SEED_FILE="$SEED_FILE"
          P1_SEED_APPLIED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          downgrade_to_reader database "$SESSION_ID"
          return 0
        fi
      fi

      downgrade_to_reader database "$SESSION_ID"
    fi
  fi

  # Strategy 2 (fallback): Tạo qua UI form (nếu scenario có precondition tạo data)
  local CREATE_PATH=$(echo "$SCENARIO_FRONTMATTER" | jq -r '.precondition.create_path // ""' 2>/dev/null)
  if [ -n "$CREATE_PATH" ]; then
    mcp__plugin_playwright_playwright__browser_navigate "${FE_BASE_URL}${CREATE_PATH}"
    mcp__plugin_playwright_playwright__browser_wait_for "form" 5000
    mcp__plugin_playwright_playwright__browser_fill_form "$MINIMUM_REQUIRED_FIELDS"
    mcp__plugin_playwright_playwright__browser_click "button[type=submit]"
    mcp__plugin_playwright_playwright__browser_wait_for "text=thành công" 5000

    if re_execute_full_scenario; then
      P1_RESULT=PASS
      P1_STRATEGY="ui_create_form"
      return 0
    fi
  fi

  P1_RESULT=FAIL
  P1_NOTE="Cả 2 strategy (seed apply + UI create) đều fail — chuyển Phase B"
  return 1
}
```

**NETWORK_ERROR 4xx và BUSINESS_RULE skip Phase A** — chuyển thẳng Phase B (không có browser-fix khả thi).

---

### H.3 Phase B — Source Code Fix (Spawn Agent)

> **Trigger:** Phase A `P1_RESULT=FAIL` HOẶC `failure_type` ∈ {NETWORK_ERROR 4xx, BUSINESS_RULE}.
> **Guard:** Phase B chỉ chạy khi `--auto-fix-source` ON + CDG E195 confirmed.
> **Budget:** 1 spawn / issue. Timeout 5 min / agent. Retry x1 nếu agent return invalid.

#### H.3.a CDG E195 Check (chỉ trigger 1 lần / session)

```bash
check_auto_fix_source_cdg() {
  # Chỉ trigger nếu --auto-fix-source ON
  [ "$AUTO_FIX_SOURCE" != "true" ] && {
    log_error "INFO" "phase10_analyzer" "--auto-fix-source OFF — SKIP Phase B"
    return 1
  }

  # Check CDG đã confirm trong session chưa
  local CDG_TOKEN="$SESSION_DIR/phase10-e2e-resolution/cdg-tokens.json"
  if [ -f "$CDG_TOKEN" ] && jq -e '.tokens[] | select(.code == "E195" and .decision == "confirm")' "$CDG_TOKEN" >/dev/null 2>&1; then
    return 0  # Đã confirm — proceed
  fi

  # Chưa confirm → AskUserQuestion (lần đầu trong session)
  # Runtime: AskUserQuestion({
  #   question: "Phase 10 sắp spawn agent sửa source code cho ${FAIL_COUNT} issues. Tiếp tục?",
  #   options: [
  #     {label: "Confirm spawn agents", description: "Spawn agents, write source files (Recommended cho test envs)"},
  #     {label: "Reject - chỉ browser-fix", description: "Chỉ Phase A, không touch source"},
  #     {label: "Skip Phase 10 hoàn toàn", description: "Log issues vào resolution-report mà không fix"}
  #   ]
  # })

  local DECISION="${USER_CDG_E195_DECISION:-reject}"  # default safe

  # Persist CDG token
  append_cdg_token "phase10-e2e-resolution" "E195-AutoFixSource-Confirm" "$DECISION"

  case "$DECISION" in
    confirm) return 0 ;;
    reject) log_error "INFO" "phase10_analyzer" "User reject Phase B — chỉ browser-fix"; return 1 ;;
    skip) PHASE10_SKIP=true; return 1 ;;
  esac
}
```

#### H.3.b Agent Spawn Pattern (8-section CORE-037)

```bash
spawn_phase_b_agent() {
  local PRIMARY_AGENT="$1"
  local CO_AGENTS_JSON="$2"  # ["finance-expert"] or []

  local AGENT_PROMPT=$(cat <<EOF
# 1. ROLE
Bạn là ${PRIMARY_AGENT} cho wf-cmi v3.0 Phase 10 E2E Resolution auto-fix Phase B.
$([ "$(echo "$CO_AGENTS_JSON" | jq 'length')" -gt 0 ] && echo "Co-spawned cùng: $(echo "$CO_AGENTS_JSON" | jq -r 'join(", ")')")

# 2. TASK
Scenario '${SCENARIO_NAME}' FAIL với failure_type=${FAILURE_TYPE}.
Đọc evidence + sửa code đúng file liên quan. KHÔNG refactor, KHÔNG thêm feature (BHV-003).

# 3. SESSION CONTEXT
- SESSION_DIR: ${SESSION_DIR}
- SCENARIO_FILE: ${SCENARIO_FILE}
- INVARIANT_ID: ${INVARIANT_ID}
- MODULES_INVOLVED: ${MODULES_INVOLVED}
- SOURCE_DIM: ${SOURCE_DIM}

# 4. CI CONTEXT (Protocol 20)
${CI_CONTEXT:-NONE}

# 5. PLAYWRIGHT CONTEXT
Mode: ${PLAYWRIGHT_MODE:-headless}
Base URL: ${FE_BASE_URL}
Browser lock: HELD bởi Phase 9-10 orchestrator — KHÔNG release.

# 6. OUTPUT CONTRACT
Trả về JSON:
{
  "success": true|false,
  "files_modified": ["path/to/file.cs", ...],
  "fix_description": "≤200 chars mô tả fix",
  "confidence_level": "high|medium|low",
  "cannot_fix": false|true,
  "cannot_fix_reason": "(chỉ điền nếu cannot_fix=true)"
}

# 7. OWNERSHIP RULES
- 1 file = 1 writer (BHV-003 surgical change)
- KHÔNG touch file ngoài scope: ${ALLOWED_SCOPE}
- Lock cross-session đã held cho resource: ${LOCK_RESOURCE}

# 8. COMPLETION CRITERIA
- Files modified pass build/test cục bộ (nếu áp dụng)
- Fix surgical — chỉ sửa đúng signal cụ thể
- Nếu không đủ context an toàn → return cannot_fix=true + lý do
EOF
)

  # Spawn agent với timeout 5 min
  local AGENT_OUTPUT=$(timeout 300 invoke_agent_tool \
    --subagent_type="$PRIMARY_AGENT" \
    --prompt="$AGENT_PROMPT" 2>&1)

  local AGENT_EXIT=$?

  if [ "$AGENT_EXIT" -ne 0 ]; then
    log_error "E190" "phase10_analyzer" "Spawn agent $PRIMARY_AGENT timeout hoặc fail"
    # Retry x1
    AGENT_OUTPUT=$(timeout 300 invoke_agent_tool \
      --subagent_type="$PRIMARY_AGENT" \
      --prompt="$AGENT_PROMPT" 2>&1)
    AGENT_EXIT=$?
  fi

  if [ "$AGENT_EXIT" -ne 0 ]; then
    P2_RESULT=FAIL
    P2_NOTE="Agent spawn 2x fail — ESCALATE"
    return 1
  fi

  # Parse agent output
  local SUCCESS=$(echo "$AGENT_OUTPUT" | jq -r '.success // false' 2>/dev/null)
  local FILES_MODIFIED=$(echo "$AGENT_OUTPUT" | jq -c '.files_modified // []' 2>/dev/null)
  local FIX_DESC=$(echo "$AGENT_OUTPUT" | jq -r '.fix_description // ""' 2>/dev/null)
  local CONFIDENCE=$(echo "$AGENT_OUTPUT" | jq -r '.confidence_level // "low"' 2>/dev/null)
  local CANNOT_FIX=$(echo "$AGENT_OUTPUT" | jq -r '.cannot_fix // false' 2>/dev/null)

  if [ "$CANNOT_FIX" = "true" ]; then
    local REASON=$(echo "$AGENT_OUTPUT" | jq -r '.cannot_fix_reason // "unknown"')
    P2_RESULT=SKIP
    P2_NOTE="Agent return cannot_fix=true: $REASON"
    return 1
  fi

  P2_AGENT="$PRIMARY_AGENT"
  P2_FILES_MODIFIED="$FILES_MODIFIED"
  P2_FIX_DESCRIPTION="$FIX_DESC"
  P2_CONFIDENCE="$CONFIDENCE"

  [ "$SUCCESS" = "true" ] && return 0 || { P2_RESULT=FAIL; return 1; }
}
```

#### H.3.c Agent Mapping per failure_type

```bash
get_phase_b_agents() {
  local FT="$1"
  local MODULES="$2"

  local PRIMARY=""
  local CO_AGENTS=$(infer_domain_expert "$MODULES")

  case "$FT" in
    TEST_SELECTOR) PRIMARY="qa-lead"; CO_AGENTS="[]" ;;
    AUTH_FAILURE) PRIMARY="security"; CO_AGENTS=$(jq -n '["developer"]') ;;
    NETWORK_ERROR) PRIMARY="developer" ;;
    UI_BUG) PRIMARY="frontend-developer"; CO_AGENTS="[]" ;;
    BUSINESS_RULE) PRIMARY="developer" ;;
    DATA_MISSING) PRIMARY="dba"; CO_AGENTS=$(jq -n '["developer"]') ;;
  esac

  echo "${PRIMARY}|${CO_AGENTS}"
}
```

---

### H.4 Post-Fix: Wait HMR Reload + Re-Verify

Sau khi agent sửa xong source code:

```bash
post_fix_verify() {
  # PF1: Đợi dev server reload (HMR)
  # Frontend (Vite/Next.js): 3-5s
  # Backend (nodemon/dotnet watch): 5-10s
  local HMR_WAIT=$([ "$AFFECTED_LAYER" = "frontend" ] && echo 5 || echo 10)
  sleep "$HMR_WAIT"

  # PF2: Wait for page ready (max 30s — E191 timeout)
  local HMR_TIMEOUT=30000
  if ! mcp__plugin_playwright_playwright__browser_wait_for "body" "$HMR_TIMEOUT" 2>/dev/null; then
    log_error "E191" "phase10_analyzer" "HMR reload timeout >30s — manual page reload required"
    return 1
  fi

  # PF3: Hard reload browser để nhận HMR update
  mcp__plugin_playwright_playwright__browser_evaluate "() => window.location.reload()"
  mcp__plugin_playwright_playwright__browser_wait_for "body" 10000
  sleep 2

  # PF4: Re-run toàn bộ scenario từ bước đầu
  if re_execute_full_scenario; then
    AUTO_FIX_RESULT=PASS
    return 0
  fi

  AUTO_FIX_RESULT=FAIL
  log_error "E192" "phase10_analyzer" "Post-fix verify FAIL — re-run scenario vẫn fail"
  return 1
}
```

---

## I. Resolution Entry Schema (e2e-results.json + auto_fix object)

Sau cả 2 phase, enrich `e2e-results.json` entry với `auto_fix` object:

### I.1 Khi Phase A thành công (không cần Phase B)

```json
{
  "issue_id": "ISSUE-CMI-SC-001-3",
  "failure_type": "TEST_SELECTOR",
  "layer": "test",
  "owner_agent": "qa-lead",
  "evidence_collected": {
    "console_lines": 5,
    "network_requests": 12,
    "dom_snapshot_bytes": 8421,
    "evidence_partial": false
  },
  "resolution_direction": "Selector không tìm thấy...",
  "auto_fix_attempts": [
    {
      "phase": "A",
      "tactic": "selector_variant_data_testid",
      "result": "PASS",
      "selector_worked": "[data-testid=customer-save-btn]",
      "duration_ms": 1230
    }
  ],
  "final_status": "AUTO_CORRECTED",
  "loop_back_suggestion_id": "SUGG-e2e_scenario_fix-001"
}
```

### I.2 Khi Phase A fail → Phase B success

```json
{
  "issue_id": "ISSUE-CMI-SC-002-5",
  "failure_type": "UI_BUG",
  "layer": "frontend",
  "owner_agent": "frontend-developer",
  "auto_fix_attempts": [
    {
      "phase": "A",
      "tactic": "page_reload",
      "result": "FAIL",
      "duration_ms": 3500,
      "note": "TypeError vẫn còn sau reload"
    },
    {
      "phase": "B",
      "tactic": "spawn_frontend_developer_null_check_fix",
      "result": "PASS",
      "spawned_agent": "frontend-developer",
      "files_modified": ["apps/erp-web/src/components/CustomerForm.tsx"],
      "fix_description": "Added null check: customer?.id ?? '' before rendering",
      "confidence_level": "high",
      "duration_ms": 18500
    }
  ],
  "final_status": "AUTO_CORRECTED",
  "loop_back_suggestion_id": "SUGG-e2e_scenario_fix-002"
}
```

### I.3 Khi cả 2 phase fail (UNRESOLVED)

```json
{
  "issue_id": "ISSUE-CMI-SC-003-7",
  "failure_type": "BUSINESS_RULE",
  "layer": "architecture",
  "owner_agent": "architect",
  "auto_fix_attempts": [
    {
      "phase": "A",
      "tactic": "skip",
      "result": "SKIP",
      "note": "BUSINESS_RULE skip Phase A (cần source-fix)"
    },
    {
      "phase": "B",
      "tactic": "spawn_developer_logistics_expert_invariant_enforce",
      "result": "FAIL",
      "spawned_agent": "developer",
      "co_agents": ["logistics-expert"],
      "note": "Agent return cannot_fix=true: insufficient context để enforce invariant INV-LOG-008"
    }
  ],
  "final_status": "UNRESOLVED",
  "loop_back_suggestion_id": "SUGG-e2e_scenario_fix-003"
}
```

### I.4 Khi SKIP (UNKNOWN)

```json
{
  "issue_id": "ISSUE-CMI-SC-004-2",
  "failure_type": "UNKNOWN",
  "layer": "unknown",
  "owner_agent": "qa-lead",
  "auto_fix_attempts": [],
  "final_status": "MANUAL_TRIAGE",
  "skip_reason": "UNKNOWN failure type — insufficient signal for safe auto-fix (E180)"
}
```

---

## J. Loop-back gap-suggestions APPEND

Sau mỗi issue resolved, APPEND vào `$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json` (schema vẫn `gap-suggestions-v1`, chỉ thêm `kind` value mới):

```bash
append_loop_back_suggestion() {
  local ISSUE_ID="$1"
  local GAP_SUGG_FILE="$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json"
  local TMP="${GAP_SUGG_FILE}.tmp.$$"

  # Generate suggestion id
  local SUGG_INDEX=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix")] | length' "$GAP_SUGG_FILE" 2>/dev/null || echo 0)
  local SUGG_ID=$(printf "SUGG-e2e_scenario_fix-%03d" $((SUGG_INDEX + 1)))

  # Compute confidence từ auto-fix result
  local CONFIDENCE
  case "${AUTO_FIX_RESULT:-FAIL}/${P1_RESULT:-FAIL}/${P2_RESULT:-FAIL}" in
    PASS/PASS/*) CONFIDENCE=0.95 ;;  # Phase A success → high confidence
    PASS/FAIL/PASS) CONFIDENCE=0.85 ;;  # Phase B success → high
    FAIL/*/*) CONFIDENCE=0.30 ;;  # All failed → low (manual review)
    *) CONFIDENCE=0.50 ;;
  esac

  # Determine target_path
  local TARGET_PATH
  if [ -n "$P2_FILES_MODIFIED" ] && [ "$P2_FILES_MODIFIED" != "[]" ]; then
    TARGET_PATH=$(echo "$P2_FILES_MODIFIED" | jq -r '.[0]')
  else
    TARGET_PATH="$SCENARIO_FILE"  # fallback — scenario itself
  fi

  # Build suggestion JSON
  local NEW_SUGG=$(jq -n \
    --arg id "$SUGG_ID" \
    --arg target "$TARGET_PATH" \
    --arg sig_id "$ISSUE_ID" \
    --arg sev "$SEVERITY_INHERITED" \
    --arg rationale "Phase 10 auto-fix: $AUTO_FIX_RESULT. Strategy: ${P1_STRATEGY:-skip}/${P2_AGENT:-none}. ${P2_FIX_DESCRIPTION:-N/A}" \
    --arg inv_id "$INVARIANT_ID" \
    --arg dim "$SOURCE_DIM" \
    --argjson conf "$CONFIDENCE" \
    --arg gen_at "$(date -Iseconds)" \
    '{
      id: $id,
      kind: "e2e_scenario_fix",
      title: ("E2E auto-fix loop-back: " + $sig_id),
      description: $rationale,
      target_path: $target,
      source_signal_ids: [$sig_id],
      confidence: $conf,
      severity: $sev,
      status: "proposed",
      linked_invariant_id: $inv_id,
      source_dim: $dim,
      rationale: $rationale,
      generated_at: $gen_at,
      generated_by: "wf-cmi/phase10-e2e-resolution v3.0"
    }')

  # APPEND to gap-suggestions.json (Atomic Write)
  jq --argjson new "$NEW_SUGG" \
     '.suggestions += [$new] |
      .metadata.suggestion_count = (.suggestions | length) |
      .metadata.kind_breakdown.e2e_scenario_fix = ((.metadata.kind_breakdown.e2e_scenario_fix // 0) + 1) |
      .metadata.status_breakdown.proposed = ((.metadata.status_breakdown.proposed // 0) + 1)' \
     "$GAP_SUGG_FILE" > "$TMP"

  if jq -e '."$schema" == "gap-suggestions-v1"' "$TMP" >/dev/null 2>&1; then
    mv "$TMP" "$GAP_SUGG_FILE"
    echo "$SUGG_ID"  # return for caller to enrich e2e-results
  else
    rm -f "$TMP"
    log_error "E181" "phase10_analyzer" "APPEND gap-suggestions fail — schema invalid"
    return 1
  fi
}
```

**Loop-back guard:**
- APPEND CHỈ kind=`e2e_scenario_fix` (mới, không có trong gap-suggestions-v1 original kinds list).
- KHÔNG re-trigger CD41 → tránh infinite loop. Per-session, scenario synth chỉ 1 lần ở Phase 4 Wave 3.
- Schema VẪN `gap-suggestions-v1` (KHÔNG bump version) — chỉ thêm value cho field `kind` (open enum).

---

## K. Error Codes (E180-E199)

| Code | Severity | Mô tả | Action |
|------|----------|-------|--------|
| **E180** | medium | Classification UNKNOWN — không match 6 pattern | Log warning, set `failure_type=UNKNOWN`, SKIP auto-fix, manual triage prompt |
| **E181** | low | Evidence partial — console/network/DOM capture không complete | Log warning, set `evidence_partial=true`, tiếp tục với partial |
| **E190** | high | Spawn agent fail (timeout >5min hoặc returns invalid) | Retry x1, ESCALATE nếu vẫn fail. Append resolution-report với spawn failure log |
| **E191** | medium | HMR reload timeout (sau source-fix, FE không hot-reload trong 30s) | Manual page reload, re-run scenario |
| **E192** | medium | Post-fix verify FAIL — re-run scenario sau fix vẫn fail | Mark UNRESOLVED, append gap-suggestions với confidence=0.30 |
| **E195** | info | CDG user-facing: `--auto-fix-source` confirm | AskUserQuestion — xem H.3.a |

**Nguyên tắc quan trọng:** E180-E192 KHÔNG block phase. Đây là warnings informational — Phase 10 vẫn tiếp tục xử lý issue tiếp theo trong batch.

---

## L. Kết Quả → Return Phase 10 Step 10.2

```
AUTO_FIX_RESULT = "PASS" (Phase A hoặc Phase B succeed):
  → Update e2e-results.json: final_status="AUTO_CORRECTED", auto_corrected=true
  → APPEND resolution-report row với "✅ AUTO_CORRECTED"
  → APPEND gap-suggestions kind=e2e_scenario_fix, confidence=0.85-0.95
  → Tăng $AUTO_CORRECTED_COUNT

AUTO_FIX_RESULT = "FAIL" (cả Phase A + Phase B đều fail):
  → Update e2e-results.json: final_status="UNRESOLVED"
  → APPEND resolution-report row với "❌ UNRESOLVED"
  → APPEND gap-suggestions kind=e2e_scenario_fix, confidence=0.30 (low, cần manual)
  → Log E192
  → Tăng $UNRESOLVED_COUNT

AUTO_FIX_RESULT = "SKIP" (UNKNOWN hoặc CDG E195 reject):
  → Update e2e-results.json: final_status="MANUAL_TRIAGE"
  → APPEND resolution-report row với "⚠ MANUAL_TRIAGE"
  → APPEND gap-suggestions kind=e2e_scenario_fix, confidence=0.20 (very low)
  → Note: "UNKNOWN — insufficient signal" hoặc "User reject auto-fix-source"
  → Tăng $MANUAL_TRIAGE_COUNT
```

---

## M. Cross-References

| Reference | Purpose |
|-----------|---------|
| `procedures/phase10-e2e-resolution.md` | Consumer — Step 10.2 dispatch engine |
| `procedures/_e2e-runner.md` | Producer of issue entries (Phase 9) |
| `procedures/phase7-gap-cdg.md` §C Step 7.11 | Loop-back target — APPEND gap-suggestions |
| `procedures/_shared.md §22` | Smart retry pattern (Phase A browser-fix dùng) |
| `procedures/_shared.md §14` | R/W lock (DATA_MISSING Phase A acquire writer lock database) |
| `procedures/_shared.md §15` | Agent Prompt Templates (Phase B spawn template) |
| `procedures/_shared.md §18` | CDG token persist (E195 confirm) |
| `templates/e2e-results.json` | Schema `e2e-results-v1` — enrich target |
| `templates/gap-suggestions.json` | Schema `gap-suggestions-v1` — APPEND target |
| `templates/resolution-report.md` | Step 10.4 render target |
| **Source** `.claude/skills/workflow/wf-e2e-scenario/procedures/failure-analyzer.md` | Port reference (Stage 5 port engine logic 100%, đổi paths sang wf-cmi) |

---

> **Stage 5 implemented** — engine port + CMI context enrich (invariant_id, modules_involved, source_dim) + 7-type classify + 2-phase auto-fix + loop-back gap-suggestions APPEND với guard tránh re-trigger CD41.
