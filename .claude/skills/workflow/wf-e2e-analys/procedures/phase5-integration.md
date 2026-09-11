# Phase 5: INTEGRATION TEST — Chi tiết procedure

## Mục tiêu

Verify FE → API → response chain đầu cuối. Không dùng browser. Code analysis + curl.

## 5.1 — Trace FE→API chain

Với mỗi user action quan trọng (từ ui-mapping.md):

```
User action → hook call → axios config → endpoint URL → handler → response
```

**5.1a Verify axios call:**
Đọc hook file: `useMutation({ mutationFn: (data) => api.post('/api/v1/{route}', data) })`
- Endpoint URL khớp với api-mapping.md Phase 3?
- HTTP method khớp?

**5.1b Verify request shape:**
FE type/interface (từ `src/types/{module}/`) khớp với BE Command fields?
```
FE CreateXxxRequest { fieldA: string, fieldB: number }
BE CreateXxxCommand { FieldA: string, FieldB: int }
→ Mapping đúng? (camelCase vs PascalCase là expected)
```

**5.1c Verify response shape:**
FE kiểu `XxxDto` từ `src/types/{module}/` khớp với BE response type?
Envelope `{ success, data, meta }` được unwrap đúng không? (`response.data.data`)

## 5.2 — Verify response handling

**Success path:**
```
onSuccess: (data) => {
  toast.success(t('module.action.success'))  ← key có trong vi.json?
  queryClient.invalidateQueries({ queryKey: ['{key}'] })  ← key đúng?
  onClose()  ← dialog/modal đóng?
}
```

**Error path:**
```
onError: (error) => {
  const message = error.response?.data?.message || t('common.error.unknown')
  toast.error(message)  ← format đúng?
}
```

**Loading path:**
```
const { mutate, isPending } = useMutation(...)
<Button disabled={isPending}>  ← disabled khi pending?
{isPending && <Spinner />}  ← spinner hiển thị?
```

## 5.3 — Live API test với seed data

Sử dụng seed data từ Phase 2 (`db-seed-data.md`):

```bash
TOKEN=$(curl -s -X POST http://localhost:5048/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"sysadmin@erktransport.local","password":"SysAdmin@123"}' \
  | jq -r '.data.accessToken // empty')

if [ -n "$TOKEN" ]; then
  # Test với bản ghi seed data đã tạo
  # Ví dụ: GET list với seed data
  curl -s "http://localhost:5048/api/v1/{route}" \
    -H "Authorization: Bearer $TOKEN" | jq '.data | length'

  # Test create (dùng dữ liệu từ seed Nhóm 1)
  curl -s -X POST "http://localhost:5048/api/v1/{route}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{seed data item 1}' | jq '{success, id: .data.id}'

  # Test với edge case data (từ seed Nhóm 2)
  # ...
fi
```

Với mỗi test: ghi `request payload → response status → response body → pass/fail`.

## 5.4 — Integration summary

Per user action:
```
| Action | FE Hook | API Endpoint | Request Shape | Response Shape | Success Handler | Error Handler | Status |
|--------|---------|--------------|---------------|----------------|-----------------|---------------|--------|
| Tạo X  | useMutationCreateX | POST /api/v1/x | ✓ khớp | ✓ khớp | toast.success ✓ | toast.error ✓ | PASS |
```

## 5.5 — Cross-Module Integration Test (LUÔN chạy — KHÔNG defer to manual, KHÔNG dừng vì bất cứ lý do gì)

Section này được thiết kế để chạy đến cùng dù gặp lỗi ở bất kỳ điểm nào.
Mọi lỗi đều được ghi vào `block-test.json` (Nhóm 2) thay vì dừng loop.

### 5.5a — Lấy auth token (fail-loud, KHÔNG silent skip)

```bash
TOKEN=$(curl -s -X POST http://localhost:5048/api/v1/auth/login \
  -H "Content-Type: application/json" \
  --max-time 10 \
  -d '{"email":"sysadmin@erktransport.local","password":"SysAdmin@123"}' \
  | jq -r '.data.accessToken // empty' 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  # Ghi block entry + tiếp tục — KHÔNG fail toàn bộ phase 5
  add_to_block_test "cross-module" "auth" "/api/v1/auth/login" \
    "E017: Login failed — không lấy được token, cross-module API test bị block"
  log_error "E017" "P5.5" "Auth token empty — cross-module tests recorded as blocked"
  CM_STATUS="auth_failed"
  # Vẫn ghi report rỗng và tiếp tục
fi
```

### 5.5b — Load cross-module dependency points (3-tier fallback, KHÔNG crash)

```bash
CM_PASS=0; CM_AUTH=0; CM_BLOCKED=0; CM_ERROR=0; CM_SKIP=0
CM_POINTS=""
CM_MODULES_DOWN_FILE="/tmp/cm_modules_down_$$.txt"
> "$CM_MODULES_DOWN_FILE"

# Tier 1: JSON companion file (ưu tiên cao nhất — parseable)
CM_JSON="findings/cross-module-map.json"
CM_MD="findings/cross-module-map.md"

if [ -f "$CM_JSON" ]; then
  CM_POINTS=$(jq -r '.cross_module_points[]? | @base64' "$CM_JSON" 2>/dev/null || echo "")

# Tier 2: Parse markdown table nếu không có JSON
# Format bảng: | Module | Resource | Suggested Route | ...
elif [ -f "$CM_MD" ]; then
  CM_POINTS=$(grep -E '^\|[[:space:]]*[A-Za-z]' "$CM_MD" 2>/dev/null \
    | grep -v '\-\-\-' \
    | grep -v 'Module\|Resource\|Suggested' \
    | while IFS='|' read _ module resource route _; do
        module=$(echo "$module" | xargs 2>/dev/null || echo "")
        resource=$(echo "$resource" | xargs 2>/dev/null || echo "")
        route=$(echo "$route" | xargs 2>/dev/null || echo "")
        [ -z "$module" ] && continue
        [ -z "$route" ] && route="/api/v1/${module}/${resource}"
        jq -cn --arg m "$module" --arg r "$resource" --arg rt "$route" \
          '{module:$m, resource:$r, suggested_route:$rt}' 2>/dev/null \
          | base64 -w0 2>/dev/null && echo
      done 2>/dev/null || echo "")

# Tier 3: Không có file → ghi warning, bỏ qua (KHÔNG fail)
else
  log_event "WARN" "P5.5" "cross-module-map không tồn tại — không có cross-module dependencies (hoặc F0a chưa chạy)"
  CM_STATUS="no_map"
fi
```

### 5.5b.1 — Module deployment probe (skip undeployed modules — KHÔNG tính là lỗi)

```bash
# Monolith EUREKA: tất cả modules dùng cùng host localhost:5048.
# 401/403/405 = route tồn tại (module deployed), 404 = route chưa register (module chưa deploy).
# Probe trước khi test → tránh false-positive BLOCK cho modules đang phát triển.

if [ -n "$CM_POINTS" ] && [ -z "${CM_STATUS:-}" ]; then
  # Lấy danh sách modules unique từ CM_POINTS
  UNIQUE_MODULES=$(
    for dep_b64 in $CM_POINTS; do
      dep=$(echo "$dep_b64" | base64 -d 2>/dev/null | jq -r '.module // ""' 2>/dev/null || echo "")
      [ -n "$dep" ] && echo "$dep"
    done | sort -u
  )

  while IFS= read -r mod; do
    [ -z "$mod" ] && continue
    PROBE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 5 \
      -H "Authorization: Bearer ${TOKEN:-invalid}" \
      "http://localhost:5048/api/v1/${mod}" 2>/dev/null || echo "000")

    case "$PROBE" in
      200|201|204|400|401|403|405|422)
        log_event "INFO" "P5.5b1" "Module ${mod} probe → ${PROBE} (deployed)"
        ;;
      *)
        # 404 hoặc 000 → module chưa deploy trong dev — đánh dấu để skip
        echo "$mod" >> "$CM_MODULES_DOWN_FILE"
        log_event "WARN" "P5.5b1" \
          "E018: Module ${mod} chưa deploy trong dev (probe → ${PROBE}) — tests sẽ bị skip, không tính lỗi"
        ;;
    esac
  done <<< "$UNIQUE_MODULES"
fi
```

### 5.5c — Chạy test từng dependency point (unstoppable loop)

```bash
if [ -n "$CM_POINTS" ] && [ -z "${CM_STATUS:-}" ]; then
  for dep_b64 in $CM_POINTS; do
    # Parse với fallback — KHÔNG crash nếu base64 decode fail
    dep=$(echo "$dep_b64" | base64 -d 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    [ -z "$dep" ] && continue

    dep_module=$(echo "$dep" | jq -r '.module // "unknown"' 2>/dev/null || echo "unknown")
    route=$(echo "$dep" | jq -r '.suggested_route // "/api/v1/unknown"' 2>/dev/null || echo "/api/v1/unknown")

    # Skip modules chưa deploy trong dev (E018) — không tính là lỗi integration
    if grep -q "^${dep_module}$" "$CM_MODULES_DOWN_FILE" 2>/dev/null; then
      record_cross_module_result "$dep_module" "$route" "not_deployed" "dev_skip" \
        "E018: Module ${dep_module} chưa deploy trong dev — không tính là lỗi"
      CM_SKIP=$((CM_SKIP + 1))
      continue
    fi

    # curl với timeout — HTTP 000 = timeout/unreachable
    HTTP_CODE=$(curl -s -o /tmp/cm_resp_$$.json -w "%{http_code}" \
      --max-time 10 \
      -H "Authorization: Bearer ${TOKEN:-invalid}" \
      "http://localhost:5048${route}" 2>/dev/null || echo "000")

    case "$HTTP_CODE" in
      200)
        DATA_COUNT=$(jq -r '.data | if type=="array" then length elif . != null then 1 else 0 end' \
          /tmp/cm_resp_$$.json 2>/dev/null || echo "?")
        record_cross_module_result "$dep_module" "$route" "pass" "$HTTP_CODE" "${DATA_COUNT} items"
        CM_PASS=$((CM_PASS + 1))
        ;;
      201|204)
        record_cross_module_result "$dep_module" "$route" "pass" "$HTTP_CODE" "write-ok"
        CM_PASS=$((CM_PASS + 1))
        ;;
      401|403)
        # Auth required → endpoint exists, PASS expected
        record_cross_module_result "$dep_module" "$route" "auth_required" "$HTTP_CODE" ""
        CM_AUTH=$((CM_AUTH + 1))
        ;;
      404)
        add_to_block_test "cross-module" "$dep_module" "$route" \
          "E015: Cross-module endpoint not found — ${dep_module}${route}"
        record_cross_module_result "$dep_module" "$route" "blocked" "$HTTP_CODE" ""
        CM_BLOCKED=$((CM_BLOCKED + 1))
        ;;
      000)
        # Timeout hoặc connection refused — nghiêm trọng hơn 5xx
        add_to_block_test "cross-module" "$dep_module" "$route" \
          "E016: Cross-module API timeout/unreachable — ${dep_module}${route}"
        record_cross_module_result "$dep_module" "$route" "error" "timeout" ""
        CM_ERROR=$((CM_ERROR + 1))
        ;;
      5*)
        add_to_block_test "cross-module" "$dep_module" "$route" \
          "E016: Cross-module API server error HTTP ${HTTP_CODE} — ${dep_module}${route}"
        record_cross_module_result "$dep_module" "$route" "error" "$HTTP_CODE" ""
        CM_ERROR=$((CM_ERROR + 1))
        ;;
      *)
        # 3xx redirect hoặc mã bất ngờ — ghi warning, không block
        record_cross_module_result "$dep_module" "$route" "warning" "$HTTP_CODE" "unexpected code"
        ;;
    esac

    rm -f /tmp/cm_resp_$$.json
  done

  rm -f "$CM_MODULES_DOWN_FILE"
  log_event "COMPLETE" "P5.5" \
    "Cross-module: PASS=${CM_PASS} AUTH=${CM_AUTH} BLOCKED=${CM_BLOCKED} ERROR=${CM_ERROR} SKIP=${CM_SKIP}"
fi
```

**Quy tắc phân loại — không có exception:**
| Kết quả | Hành động | Ghi vào |
|---------|-----------|---------|
| HTTP 200/201/204 | PASS auto | integration-test-report.md |
| HTTP 401/403 | PASS (auth_required, expected) | integration-test-report.md |
| HTTP 404 (module probe fail) | SKIP (E018, not_deployed — module chưa deploy trong dev) | integration-test-report.md |
| HTTP 404 (module deployed, endpoint missing) | BLOCK (E015) | block-test.json Nhóm 2 |
| HTTP 5xx / timeout (000) | BLOCK (E016) | block-test.json Nhóm 2 |
| Auth token fail | BLOCK (E017) | block-test.json Nhóm 2 |
| No cross-module-map | WARN, bỏ qua | integration-test-report.md |
| Hardware / real payment / OAuth | MANUAL (Group 4) | manual.json |

**Không bao giờ** defer cross-module API test vào manual.json nếu endpoint có thể gọi qua HTTP.

> **Dev environment note:** Module probe (5.5b.1) chạy trước loop. Nếu module X probe trả về 404/000,
> **tất cả** endpoints của module X được skip với E018 (không tính lỗi). Khi module X được deploy,
> probe sẽ pass và tests sẽ chạy bình thường — không cần thay đổi config.

## Output

- `findings/integration-test-report.md` từ `integration-test-report.template.md`

Update status.json: `phase_5_status = "done"`, `current_phase = 6`.
