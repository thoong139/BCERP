# Phase 3: API — Chi tiết procedure

## FIND — Nguồn đọc

Tìm endpoint files theo naming convention (CLAUDE.md):

```bash
# ERP modules (root)
ls apps/backend/Eureka.Api/Endpoints/

# Customer mobile
ls apps/backend/Eureka.Api/Endpoints/CustomerMobile/

# Staff mobile
ls apps/backend/Eureka.Api/Endpoints/StaffMobile/

# SmartTax
ls apps/backend/Eureka.Api/Endpoints/SmartTax/
```

Grep pattern để tìm:
```bash
# Tìm endpoint file theo module name
grep -rl "{ModuleName}" apps/backend/Eureka.Api/Endpoints/ --include="*.cs"

# Tìm route pattern
grep -r "MapGroup\|MapGet\|MapPost\|MapPut\|MapDelete\|MapPatch" \
  apps/backend/Eureka.Api/Endpoints/{ModuleName}* --include="*.cs"
```

Với mỗi endpoint, trace:
1. Handler: `await mediator.Send(new {Command/Query}(...))`
2. Handler file: `Eureka.Modules.{Module}/Application/{Commands|Queries}/{Name}Handler.cs`
3. Validator: `{Name}Validator.cs` trong cùng folder
4. Permission: `.RequireAuthorization(p => p.RequireClaim("permission", "{module}.{resource}.{action}"))`
5. Response: `Results.Ok(result.Value)` → type của `result.Value`

Dùng Serena:
- `mcp__serena__find_symbol` với tên Handler class
- `mcp__serena__get_symbols_overview` với handler file
- `mcp__gitnexus__impact` với endpoint class để xem dependency

## ASSESS — Checklist

```
[ ] ≥1 endpoint với route + HTTP method
[ ] Handler class + file path biết
[ ] Command/Query type biết (tên class)
[ ] Validator biết (hoặc confirm không có)
[ ] Permission string biết (hoặc confirm public)
[ ] Response type/shape biết
```

Nếu thiếu → BỔ SUNG: grep rộng hơn, tìm theo REQ-ID comment trong code.

## TEST — Gọi API (LIVE BẮT BUỘC)

> **Quy tắc:** Live API test là **BẮT BUỘC**. Backend không chạy → **PHẢI cố gắng khởi động** (xem `_shared.md` §Infrastructure Auto-Start). KHÔNG silent fallback "code analysis only". Auto-start fail sau retry → ESCALATE Nhóm 2 (block-test.json), KHÔNG advance phase.

### Bước 0 — Bảo đảm hạ tầng chạy (cross-session safe)

```bash
# Reader lock — cho phép nhiều session test API song song
# (auto-start nếu chưa chạy; ESCALATE nếu fail sau retry)
ensure_infrastructure_running database read || exit_with_escalation
ensure_infrastructure_running backend  read || exit_with_escalation
```

Nếu auto-start thất bại sau 2 retry → escalate (block-test.json Nhóm 2 + AskUserQuestion). KHÔNG tiếp tục Phase 3 test.

> Khi BE crash giữa chừng test (vd session khác restart) → gọi `guard_restart_with_version_check backend` từ `_shared.md`. Trong `--auto` mode tự apply migration mới.

### Bước 1 — Lấy token

```bash
TOKEN=$(curl -s -X POST http://localhost:5048/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"sysadmin@erktransport.local","password":"SysAdmin@123"}' \
  | jq -r '.data.accessToken // empty')

if [ -z "$TOKEN" ]; then
  # Backend đã được auto-start ở Bước 0, nhưng login vẫn fail
  # → seed data thiếu (Nhóm 1) hoặc credential sai (Nhóm 2: missing_permissions)
  # → ESCALATE qua block-classification.md (Nhóm 1 hoặc Nhóm 2)
  # KHÔNG fallback "code analysis"
  classify_and_escalate_block \
    --reason "login_fail_after_auto_start" \
    --detail "POST /api/v1/auth/login returned empty token sau khi backend đã start. Kiểm tra seed accounts hoặc credentials."
  exit_with_escalation
fi
```

### Test cases phải cover

**1. Happy path:**
```bash
curl -s -X {METHOD} "http://localhost:5048{route}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{valid payload}' | jq .
```
Expected: 200/201, data có đúng fields.

**2. Validation fail:**
```bash
curl -s -X {METHOD} "http://localhost:5048{route}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{invalid payload — thiếu required field hoặc sai type}' | jq .
```
Expected: 400, message mô tả lỗi.

**3. Auth fail:**
```bash
curl -s -X {METHOD} "http://localhost:5048{route}" | jq .
```
Expected: 401 Unauthorized.

**4. Not found / Business rule fail:**
```bash
curl -s -X GET "http://localhost:5048{route}/00000000-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN" | jq .
```
Expected: 404 hoặc business error với message rõ.

### Static review BỔ SUNG (chạy SONG SONG, KHÔNG thay thế live test)

Sau khi live test xong, ghi thêm static review vào `api-test-report.md` để cross-check:

- Phân tích Response envelope `{success, data, meta}` từ handler code có khớp shape thực tế trả về không.
- Verify validator rules (FluentValidation / DataAnnotations) khớp business rules từ Phase 1 BR catalog.
- Cross-reference command/query handler logic với BR mapping.

Đây là **static review bổ sung** giúp catch logic bug mà response runtime có thể che giấu — KHÔNG phải fallback. Live test vẫn là nguồn truth chính.

### Cấm

- ❌ KHÔNG ghi `RESULT=PASS` cho test API mà chưa có live response (status code + body thực tế).
- ❌ KHÔNG ghi "Test sẽ là code analysis only" khi backend không khởi động được — phải ESCALATE qua block-classification.md (Nhóm 2 / Nhóm 1).
- ✅ Chỉ Nhóm 4 (vd: `requires_real_payment` cho VNPay sandbox) được ghi static-review-only kết quả — xem `block-classification.md`.

## Output

- `findings/api-mapping.md` từ `api-mapping.template.md`
- `findings/api-test-report.md` từ `api-test-report.template.md`

Update status.json: `phase_3_status = "done"`, `current_phase = 4`.
