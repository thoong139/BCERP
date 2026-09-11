# F7 — Failure Analysis Engine

**Áp dụng:** Được lazy-load và gọi từ `scenario-runner.md` ngay sau khi phát hiện scenario FAIL.
**Nguyên tắc:** Không block execution — chỉ enrich issues.json và tích lũy data cho resolution-report.md.

---

## Overview

Khi một scenario FAIL, procedure này:
1. Thu thập evidence bổ sung từ Playwright (console logs, network requests, DOM snapshot)
2. Phân loại root cause thành 7 loại (failure_type)
3. Xác định layer bị ảnh hưởng và owner đề xuất
4. Tạo resolution direction cụ thể
5. Enrich issues.json entry hiện tại
6. Tích lũy vào `$RESOLUTION_ACCUMULATOR` cho report
7. **Auto-Fix Attempt** — 2-phase: browser-fix → source-code-fix (spawn agent)

---

## Bước 1: Thu Thập Evidence Bổ Sung

```bash
# 1a. Console messages (JS errors, warnings, logs)
CONSOLE=$(mcp__plugin_playwright_playwright__browser_console_messages)

# 1b. Network requests (API calls, HTTP status codes)
NETWORK=$(mcp__plugin_playwright_playwright__browser_network_requests)

# 1c. DOM snapshot hiện tại (HTML/text content)
DOM=$(mcp__plugin_playwright_playwright__browser_snapshot)
```

Nếu bất kỳ tool nào fail hoặc timeout:
- Log **E081** (severity=low) vào error-ledger.json
- Set `EVIDENCE_PARTIAL=true`
- Tiếp tục với evidence đã thu thập được (không abort)

---

## Bước 2: Phân Loại Failure Type

Áp dụng rules theo thứ tự ưu tiên — dừng tại match đầu tiên:

| Priority | `failure_type` | Signal Detection |
|----------|---------------|-----------------|
| 1 | `NETWORK_ERROR` | `$NETWORK` chứa entry có URL khớp `/api/` VÀ status trong {400,401,403,404,409,422,429,500,502,503,504} |
| 2 | `AUTH_FAILURE` | `$NETWORK` chứa 401 hoặc 403, HOẶC `$DOM` chứa bất kỳ: "không có quyền" / "unauthorized" / "Forbidden" / "Access denied" |
| 3 | `DATA_MISSING` | `$NETWORK` chứa 404 HOẶC `$DOM` chứa bất kỳ: "không tìm thấy" / "no data" / "Chưa có dữ liệu" / "No results" / "0 kết quả" |
| 4 | `TEST_SELECTOR` | Step error message chứa bất kỳ: "Element not found" / "selector not found" / "No element matches" / "locator.click: Error" |
| 5 | `UI_BUG` | `$CONSOLE` chứa bất kỳ: "TypeError" / "Cannot read" / "Cannot access" / "null" / "undefined is not" / "is not a function" |
| 6 | `BUSINESS_RULE` | Không match rules trên VÀ DOM snapshot có nội dung hiển thị (không blank/404 page) |
| 7 | `UNKNOWN` | Không match bất kỳ pattern nào → Log **E080** (severity=medium) |

> Lưu ý AUTH_FAILURE (priority 2) override NETWORK_ERROR (priority 1) khi status là 401/403 — auth issues có hướng giải quyết khác với generic network errors.

---

## Bước 3: Xác Định Layer và Owner

| `failure_type` | `affected_layer` | `suggested_owner` |
|----------------|-----------------|-------------------|
| `NETWORK_ERROR` | `backend` | `developer` |
| `AUTH_FAILURE` | `backend` | `developer` |
| `DATA_MISSING` | `database` | `dba` |
| `TEST_SELECTOR` | `test` | `qa-lead` |
| `UI_BUG` | `frontend` | `frontend-developer` |
| `BUSINESS_RULE` | `frontend` | `frontend-developer` |
| `UNKNOWN` | `unknown` | `qa-lead` |

---

## Bước 4: Tạo Resolution Direction

Điền context thực tế từ evidence vào template. Dùng dữ liệu cụ thể khi có (method, url, status, error message).

**NETWORK_ERROR:**
```
"API [method] [url] trả về [status]. Kiểm tra: 1) Controller/handler tại endpoint này, 2) Service/usecase business logic, 3) DB query hoặc entity mapping"
```
→ Lấy `[method]`, `[url]`, `[status]` từ entry failed_request trong NETWORK evidence.

**AUTH_FAILURE:**
```
"Permission bị từ chối ([status]). Kiểm tra: 1) Role của user test trong seed data có đủ quyền không, 2) Permission matrix trong RBAC config, 3) Auth middleware/guard tại endpoint này"
```

**DATA_MISSING:**
```
"Dữ liệu không tồn tại ([url] → [status]). Kiểm tra: 1) Seed data / test fixtures đã tạo chưa, 2) Migration đã chạy chưa, 3) Bước tạo data trước trong scenario có pass không"
```

**TEST_SELECTOR:**
```
"Selector không tìm thấy — có thể là test issue (không phải app bug). Kiểm tra: 1) UI component đã đổi cấu trúc DOM so với lúc viết test, 2) Text/label đổi wording, 3) Cập nhật selector trong bước test-scenario.md tương ứng. Chạy lại với --show-browser để xem trực tiếp"
```

**UI_BUG:**
```
"JavaScript runtime error: [error_message]. Kiểm tra: 1) Null/undefined check trong component liên quan, 2) Props typing và data loading state, 3) Error boundary có bắt được không"
```
→ Lấy `[error_message]` từ CONSOLE (rút gọn xuống ≤80 ký tự).

**BUSINESS_RULE:**
```
"UI render kết quả sai so với mong đợi (không có JS error, không có network error). Kiểm tra: 1) Business logic trong service/usecase liên quan, 2) Data transformation và mapping giữa API và UI, 3) Điều kiện hiển thị phía frontend (computed/derived state)"
```

**UNKNOWN:**
```
"Không xác định được nguyên nhân tự động. Xem screenshot scenario-[N]-error.png và console log để debug thủ công. Gợi ý: chạy lại với --show-browser để quan sát trực tiếp"
```

---

## Bước 5: Enrich issues.json Entry

Đọc issues.json, tìm entry theo `id` = `ISS-NNN` hiện tại, enrich bằng Atomic Write Pattern (CORE-035):

```bash
TMP="${ISSUES_FILE}.tmp.$$"

jq --arg id "$ISSUE_ID" \
   --arg ft "$FAILURE_TYPE" \
   --arg layer "$AFFECTED_LAYER" \
   --arg res "$RESOLUTION_DIRECTION" \
   --arg owner "$SUGGESTED_OWNER" \
   --argjson partial "$EVIDENCE_PARTIAL" \
   --argjson evidence_refs "$EVIDENCE_REFS_JSON" \
   '(.signals[] | select(.id == $id)) += {
      failure_type: $ft,
      affected_layer: $layer,
      resolution_direction: $res,
      suggested_owner: $owner,
      evidence_partial: $partial,
      evidence_refs: $evidence_refs,
      resolution_analyzed_by: "wf-e2e-scenario/failure-analyzer v1.3.0"
   }' "$ISSUES_FILE" > "$TMP"

jq '.' "$TMP" > /dev/null && mv "$TMP" "$ISSUES_FILE" || {
  rm -f "$TMP"
  log_error "E081" "F7-failure-analyzer" "Atomic write fail khi enrich issues.json" 0
}
```

`$EVIDENCE_REFS_JSON` có cấu trúc:
```json
{
  "screenshot_error": "screenshots/scenario-{N}-error.png",
  "console_errors": ["<top 3 console errors nếu có>"],
  "failed_requests": [{"method": "POST", "url": "/api/...", "status": 500}]
}
```

---

## Bước 6: Append vào Resolution Accumulator

Append một markdown table row vào biến session `$RESOLUTION_ACCUMULATOR` để POST-GATE dùng tạo `resolution-report.md`:

```bash
RESOLUTION_ROW="| ${SCENARIO_NUM} | ${SCENARIO_NAME} | ${FAILURE_TYPE} | ${AFFECTED_LAYER} | ${RESOLUTION_DIRECTION} | ${SUGGESTED_OWNER} |"
RESOLUTION_ACCUMULATOR="${RESOLUTION_ACCUMULATOR}
${RESOLUTION_ROW}"
```

---

## Error Codes Riêng

| Code | Severity | Mô tả | Action |
|------|----------|-------|--------|
| E080 | medium | Failure analysis inconclusive — không match pattern nào | Log warning, set `failure_type=UNKNOWN`, tiếp tục |
| E081 | low | Evidence collection partial — một hoặc nhiều Playwright tool fail | Log warning, set `evidence_partial=true`, tiếp tục |
| E082 | medium | Auto-fix exhausted — cả 2 phase đều fail | Log warning, giữ FAIL gốc, tiếp tục |

**Nguyên tắc quan trọng:** E080/E081/E082 KHÔNG block scenario execution. Đây là warnings informational — skill vẫn tiếp tục chạy scenario tiếp theo.

---

## Bước 7: Auto-Fix Attempt (2-Phase)

> Chạy SAU Bước 1-6. Auto-fix có quyền sửa source code và spawn agent.
> **2-Phase model:** Phase 1 browser-fix (nhanh, không đụng code) → Phase 2 source-code-fix (spawn agent sửa file thật).
> **Budget:** Max 1 attempt / scenario. Nếu cả 2 phase fail → giữ FAIL gốc (log E082).

### Bảng Quyết Định Auto-Fix

| `failure_type` | Phase 1 (Browser Fix) | Phase 2 (Source Code Fix) | Agent Spawn |
|----------------|----------------------|--------------------------|-------------|
| `TEST_SELECTOR` | Thử 3 selector variants | Sửa selector trong test-scenario.md step | `qa-lead` |
| `AUTH_FAILURE` | Re-login (session refresh) | Fix RBAC config / permission middleware | `developer` |
| `NETWORK_ERROR` 5xx | Wait 3s → retry (transient check) | Fix backend endpoint / handler / service | `developer` |
| `NETWORK_ERROR` 4xx | — (skip Phase 1) | Fix validation / routing / request schema | `developer` |
| `UI_BUG` | Reload page → retry (transient check) | Fix component null check / loading state | `frontend-developer` |
| `BUSINESS_RULE` | — (skip Phase 1) | Fix service / usecase logic | `developer` + domain expert |
| `DATA_MISSING` | Tạo data qua UI create form | Tạo seed script / migration / API seed | `dba` |
| `UNKNOWN` | ❌ SKIP | ❌ SKIP | — |

> **Tại sao UNKNOWN không fix:** Không có signal cụ thể — spawn agent mà không biết fix gì sẽ tạo code sai hoặc gây side-effect khó kiểm soát.

---

### Phase 1: Browser Fix (không sửa source code)

#### P1-A: TEST_SELECTOR — Thử 3 Selector Variants

```bash
BUTTON_TEXT="<text visible từ step gốc>"
TESTID=$(echo "$BUTTON_TEXT" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

# Variant 1: Playwright text selector
mcp__plugin_playwright_playwright__browser_click --selector="text=${BUTTON_TEXT}"

# Variant 2: data-testid (kebab-case)
mcp__plugin_playwright_playwright__browser_click --selector="[data-testid=${TESTID}]"

# Variant 3: ARIA role
mcp__plugin_playwright_playwright__browser_click --selector="role=button[name='${BUTTON_TEXT}']"
```

Nếu 1 variant succeed → verify expected → nếu PASS: `P1_RESULT=PASS`.
Nếu cả 3 fail → `P1_RESULT=FAIL` → chuyển Phase 2.

#### P1-B: AUTH_FAILURE — Re-Login

```bash
mcp__plugin_playwright_playwright__browser_navigate --url=http://localhost:3000/login
mcp__plugin_playwright_playwright__browser_fill_form --fields='[
  {"name":"email","value":"sysadmin@erktransport.local"},
  {"name":"password","value":"SysAdmin@123"}
]'
mcp__plugin_playwright_playwright__browser_click --selector='button[type=submit]'
mcp__plugin_playwright_playwright__browser_wait_for --selector='[data-testid=dashboard]' --timeout=10000
# Retry toàn bộ scenario từ đầu
```

Nếu retry PASS → `P1_RESULT=PASS`.
Nếu vẫn 401/403 sau re-login → đây là RBAC bug thật → `P1_RESULT=FAIL` → Phase 2.

#### P1-C: NETWORK_ERROR 5xx — Transient Retry

```bash
sleep 3
# Re-execute bước API thất bại
NETWORK_RETRY=$(mcp__plugin_playwright_playwright__browser_network_requests)
```

Nếu không còn 5xx → `P1_RESULT=PASS`.
Nếu vẫn 5xx → confirmed non-transient → `P1_RESULT=FAIL` → Phase 2.
4xx → skip Phase 1 ngay, vào Phase 2 luôn.

#### P1-D: UI_BUG — Page Reload

```bash
mcp__plugin_playwright_playwright__browser_evaluate --code='window.location.reload()'
mcp__plugin_playwright_playwright__browser_wait_for --selector='body' --timeout=8000
# Đợi thêm 2s cho async data fetch
CONSOLE_AFTER=$(mcp__plugin_playwright_playwright__browser_console_messages)
```

Nếu console sạch + retry PASS → `P1_RESULT=PASS`.
Nếu TypeError vẫn còn sau reload → bug thật trong component → `P1_RESULT=FAIL` → Phase 2.

#### P1-E: DATA_MISSING — 2 strategy theo thứ tự ưu tiên

**P1-E-1 (Ưu tiên 1): Apply seed data từ F1 Phase 2 (canonical)**

F1 Phase 2 đã sinh `findings/db-seed-data.md` chứa SQL INSERT cho mọi entity liên quan. Strategy này re-apply seed data vào DB đang chạy, sau đó retry scenario.

```bash
SEED_FILE="$SESSION_DIR/findings/db-seed-data.md"
test -f "$SEED_FILE" || { echo "no seed file → skip P1-E-1"; P1E1_RESULT=SKIP; }

# Acquire writer lock database (write intent — INSERT vào shared DB)
acquire_writer_lock database "$SESSION_ID" "$FEAT_ID" "apply_seed_for_data_missing" || {
  P1E1_RESULT=FAIL  # lock timeout
}

if [ -z "${P1E1_RESULT:-}" ]; then
  # Extract SQL INSERT blocks từ markdown (giữa ```sql ... ```)
  awk '/^```sql/,/^```$/' "$SEED_FILE" | grep -v '^```' > /tmp/seed-${SESSION_ID}.sql

  # Execute qua psql (connection string từ .env hoặc appsettings)
  CONN_STR="${POSTGRES_CONN:-$(grep -m1 ConnectionStrings apps/backend/Eureka.Api/appsettings.Development.json | jq -r '.ConnectionStrings.DefaultConnection')}"
  psql "$CONN_STR" -v ON_ERROR_STOP=1 -f /tmp/seed-${SESSION_ID}.sql 2>&1 | tail -20

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    P1E1_RESULT=PASS
    SEED_APPLIED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  else
    P1E1_RESULT=FAIL  # SQL error (PK conflict, FK fail, schema mismatch)
  fi

  # Downgrade về reader sau khi apply xong
  downgrade_to_reader database "$SESSION_ID"
fi

# Re-execute scenario từ đầu nếu P1E1 PASS
if [ "$P1E1_RESULT" = "PASS" ]; then
  RERUN=$(re_execute_full_scenario)
  [ "$RERUN" = "PASS" ] && P1_RESULT=PASS && P1_STRATEGY="seed_data_apply"
fi
```

Note: SQL có thể `ON CONFLICT DO NOTHING` để idempotent — F1 Phase 2 đã sinh INSERT với UUID cố định nên re-apply an toàn.

**P1-E-2 (Ưu tiên 2, fallback): Tạo qua UI**

Chỉ chạy nếu P1-E-1 fail (no seed file / seed file thiếu entity cần / SQL error).

```bash
# Đọc **Precondition:** block để xác định entity + create URL
mcp__plugin_playwright_playwright__browser_navigate --url=http://localhost:3000/${CREATE_PATH}
mcp__plugin_playwright_playwright__browser_wait_for --selector='form' --timeout=5000
mcp__plugin_playwright_playwright__browser_fill_form --fields="[${MINIMUM_REQUIRED_FIELDS}]"
mcp__plugin_playwright_playwright__browser_click --selector='button[type=submit]'
mcp__plugin_playwright_playwright__browser_wait_for --text='thành công' --timeout=5000
# Retry scenario từ đầu
```

Nếu UI create + retry PASS → `P1_RESULT=PASS`, `P1_STRATEGY="ui_create_form"`.
Nếu cả 2 strategy fail → `P1_RESULT=FAIL` → Phase 2.

**Cập nhật issues.json (Bước 5 phải bổ sung):**

```json
{
  "auto_fix": {
    "phase1_strategy": "seed_data_apply | ui_create_form",
    "phase1_seed_file": "findings/db-seed-data.md",
    "phase1_seed_applied_at": "<ISO>",
    "phase1_seed_rows_inserted": 12
  }
}
```

---

### Phase 2: Source Code Fix (spawn agent)

Chỉ chạy khi `P1_RESULT=FAIL` hoặc `failure_type` skip Phase 1 (BUSINESS_RULE, NETWORK 4xx).

#### Agent Spawn Pattern

```
Agent({
  subagent_type: "${AGENT_TYPE}",
  prompt: "
    Bạn là ${AGENT_TYPE} trong F7 wf-e2e-scenario auto-fix.
    Scenario '${SCENARIO_NAME}' FAIL với failure_type=${FAILURE_TYPE}.

    Evidence thu thập được:
    - Console errors: ${CONSOLE_ERRORS}
    - Failed API: ${FAILED_REQUESTS}
    - DOM excerpt: ${DOM_EXCERPT}
    - Error screenshot: ${SCREENSHOT_PATH}

    Nhiệm vụ:
    1. Đọc source files liên quan đến failure này
    2. Xác định bug cụ thể
    3. Sửa code — chỉ sửa đúng file liên quan, không sửa gì khác
    4. Ghi lại: files_modified[], fix_description, confidence_level (high/medium/low)
    5. Nếu không đủ context để fix an toàn → trả về cannot_fix=true + lý do cụ thể

    Constraint: Surgical change only (BHV-003) — không refactor, không thêm feature.
  "
})
```

#### Agent Mapping theo failure_type

| `failure_type` | Primary Agent | Co-spawn (nếu có domain signal) |
|----------------|--------------|--------------------------------|
| `TEST_SELECTOR` | `qa-lead` | — |
| `AUTH_FAILURE` | `developer` | `security` (nếu JWT/OAuth liên quan) |
| `NETWORK_ERROR` 5xx | `developer` | domain expert theo module URL |
| `NETWORK_ERROR` 4xx | `developer` | domain expert theo module URL |
| `UI_BUG` | `frontend-developer` | — |
| `BUSINESS_RULE` | `developer` | domain expert theo module (finance/hr/logistics/...) |
| `DATA_MISSING` | `dba` | `developer` (nếu cần API seed endpoint) |

**Domain expert co-spawn** phát hiện qua URL path hoặc module name trong scenario:
- `/finance/`, `/accounting/` → `finance-expert`
- `/hr/`, `/payroll/` → `hr-expert`
- `/logistics/`, `/tms/` → `logistics-expert`
- `/crm/`, `/sales/` → `sales-expert`

---

### Post-Fix: Wait for Reload + Re-verify

Sau khi agent sửa xong source code:

```bash
# PF1: Đợi dev server reload
# Frontend HMR (Vite/Next.js): 3-5s
# Backend (nodemon/ts-node-dev): 5-8s
mcp__plugin_playwright_playwright__browser_wait_for --timeout=5000

# PF2: Hard reload browser để nhận HMR update
mcp__plugin_playwright_playwright__browser_evaluate --code='window.location.reload()'
mcp__plugin_playwright_playwright__browser_wait_for --selector='body' --timeout=10000

# PF3: Re-run toàn bộ scenario từ bước đầu
RERUN_RESULT=$(re_execute_full_scenario)
```

Nếu `RERUN_RESULT=PASS` → `AUTO_FIX_RESULT=PASS`.
Nếu `RERUN_RESULT=FAIL` → `AUTO_FIX_RESULT=FAIL` → log E082.

---

### Kết Quả → Trả Về scenario-runner.md

```
AUTO_FIX_RESULT = "PASS" (Phase 1 hoặc Phase 2 succeed):
  → Đánh dấu: ✅ PASS (auto-fixed: ${phase_used} / ${strategy})
  → Không thêm vào $RESOLUTION_ACCUMULATOR
  → Tăng $AUTO_FIX_COUNT
  → Ghi $AUTO_FIX_LOG entry

AUTO_FIX_RESULT = "FAIL" (cả 2 phase đều fail):
  → Giữ ❌ FAIL
  → Thêm vào $RESOLUTION_ACCUMULATOR
  → Log E082: "Auto-fix exhausted (Phase 1 + Phase 2 failed)"

AUTO_FIX_RESULT = "SKIP" (UNKNOWN):
  → Giữ ❌ FAIL
  → Thêm vào $RESOLUTION_ACCUMULATOR
  → Note: "UNKNOWN — insufficient signal, auto-fix skipped"
```

---

### issues.json: Auto-Fix Fields

Sau cả 2 phase, enrich issues.json entry với `auto_fix` object:

```json
{
  "id": "ISS-NNN",
  "failure_type": "UI_BUG",
  "auto_fix": {
    "phase1_attempted": true,
    "phase1_strategy": "page_reload_retry",
    "phase1_result": "fail",
    "phase1_note": "TypeError vẫn còn sau reload — bug thật trong component",
    "phase2_attempted": true,
    "phase2_agent": "frontend-developer",
    "phase2_files_modified": ["src/components/CustomerForm.tsx"],
    "phase2_fix_description": "Added null check: customer?.id ?? '' before rendering",
    "phase2_result": "pass",
    "final_result": "pass",
    "confidence_level": "high"
  }
}
```

Khi Phase 1 thành công (không cần Phase 2):
```json
{
  "auto_fix": {
    "phase1_attempted": true,
    "phase1_strategy": "selector_fallback",
    "phase1_result": "pass",
    "phase1_variant_used": 2,
    "phase1_selector_worked": "[data-testid=tao-customer]",
    "phase2_attempted": false,
    "final_result": "pass"
  }
}
```

Khi SKIP (UNKNOWN):
```json
{
  "auto_fix": {
    "phase1_attempted": false,
    "phase2_attempted": false,
    "final_result": "skip",
    "skip_reason": "UNKNOWN failure type — insufficient signal for safe auto-fix"
  }
}
```
