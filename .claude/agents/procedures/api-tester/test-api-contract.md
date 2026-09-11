# Playbook: Kiểm thử API Contract

> **Type**: Agent Skill Playbook
> **Agent**: api-tester
> **Triggered by**: Sau khi API endpoint được implement — contract và functional testing
> **Output**: API Contract Test Results tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Sau khi implement API endpoint mới — verify implementation khớp với spec
- Khi API thay đổi — kiểm tra backward compatibility
- Trước khi merge API changes vào main branch
- Khi onboard API mới từ external service — verify contract trước khi dùng

---

## Procedure

### Bước 1: Đọc API Specification

```
INPUT: Paths đến API spec và implementation do skill cung cấp
FALLBACK: tra .claude/references/path-registry.md → PHASE3

Cần thu thập:
□ OpenAPI/Swagger spec tại .mc-data/docs/phase3-architecture/
□ Hoặc API design docs trong phase3
□ REQ-IDs liên quan từ req-registry.json
□ Version API hiện tại và version trước (nếu update)

READ: .claude/references/team-expert/testing/api-testing-patterns.md
READ: .claude/references/team-expert/testing/api-test-examples.md

Kiểm kê endpoints cần test:
□ Danh sách đầy đủ endpoints
□ HTTP methods (GET/POST/PUT/PATCH/DELETE)
□ Authentication requirements
□ Business flows quan trọng
```

### Bước 2: Schema Validation

```
Với mỗi endpoint, validate request và response schema:

Request Schema:
□ Required fields có được enforce không? (thiếu → 422, không phải 500)
□ Optional fields hoạt động đúng không? (có/không có đều OK)
□ Data types đúng không?
  - string: length limits, pattern (email, phone, UUID)
  - number: range (min/max), integer vs float
  - boolean: strict (không nhận "true" string thay vì boolean true)
  - array: min/max items, unique items
  - object: nested validation
□ Enum values: chỉ nhận giá trị trong danh sách?
□ Date/time format đúng? (ISO 8601: YYYY-MM-DDTHH:mm:ssZ)
□ Unknown fields: ignored hoặc rejected theo spec?

Response Schema:
□ Response body khớp với spec? (field names, data types)
□ Null vs undefined handling nhất quán?
□ Date/time luôn trả về timezone-aware format?
□ Numeric precision đúng (decimal places)?
□ Empty array [] vs null cho empty collections?
□ Nested objects được serialize đúng?

Chuẩn bị test cases:
  valid_request_test: tất cả fields hợp lệ
  missing_required_field_test: từng required field bị bỏ
  invalid_type_test: wrong data types
  boundary_value_test: min, max, min-1, max+1
```

### Bước 3: Status Codes Verification

```
Test mọi HTTP status code mà API có thể trả về:

2xx Success:
□ 200 OK — GET, PUT, PATCH thành công
□ 201 Created — POST tạo resource mới (có Location header không?)
□ 204 No Content — DELETE thành công
□ 202 Accepted — async operation được nhận (có polling mechanism?)

4xx Client Errors:
□ 400 Bad Request — malformed request, invalid JSON
□ 401 Unauthorized — không có hoặc token hết hạn
□ 403 Forbidden — có token nhưng không có quyền
□ 404 Not Found — resource không tồn tại
□ 405 Method Not Allowed — wrong HTTP method
□ 409 Conflict — duplicate resource, state conflict
□ 410 Gone — resource đã bị xóa vĩnh viễn
□ 422 Unprocessable Entity — validation errors (business logic)
□ 429 Too Many Requests — rate limit exceeded

5xx Server Errors:
□ 500 Internal Server Error — không được leak stack trace
□ 503 Service Unavailable — dependency down

Không được phép:
□ 500 thay vì 4xx khi lỗi do input của client
□ 200 kèm error trong body (anti-pattern)
□ 200 cho DELETE (phải là 204)
```

### Bước 4: Required Fields Presence

```
Test strict field presence trong responses:

□ Với mỗi entity response:
  - ID field luôn có?
  - created_at / updated_at luôn có?
  - Fields được mark required trong spec luôn có?
  - Không có typos trong field names?

□ Consistency check:
  - List endpoint và single-item endpoint trả về cùng schema?
  - Create response và Get response có cùng structure?
  - Partial update (PATCH) trả về full object hay chỉ updated fields?

□ Computed fields:
  - Fields tính toán từ data khác có đúng không? (e.g., total = quantity * price)

Chuẩn bị:
  schema_diff_test: so sánh response với spec schema từng field
```

### Bước 5: Data Type Validation

```
Kiểm tra type safety trong responses:

□ IDs: string UUID hay integer? Nhất quán toàn API?
□ Prices/amounts: số nguyên (cents) hay decimal? Không float (precision issues)
□ Timestamps: epoch integer hay ISO string?
□ Booleans: true/false không phải 1/0 hay "true"/"false"
□ Arrays: luôn là array, không phải null khi empty
□ Enums: lowercase hay UPPERCASE? Nhất quán?

Cross-field validation:
□ end_date > start_date?
□ quantity > 0?
□ email format valid?
□ phone format theo E.164?

Test with invalid types:
  string_as_int_test: "abc" cho integer field → 422
  null_for_required_test: null cho required field → 422
  out_of_range_test: giá trị ngoài range cho phép → 422
```

### Bước 6: Pagination Testing

```
Nếu endpoint có pagination:

Offset-based pagination:
□ page=1&per_page=10 hoạt động?
□ page=0 hoặc page=-1 → 422?
□ per_page=0 → 422 hoặc default?
□ per_page > max_allowed → capped hay 422?
□ page vượt total pages → empty array, không phải 404
□ Total count trong response đúng?
□ Meta: { page, per_page, total, total_pages } đầy đủ?

Cursor-based pagination:
□ next_cursor và prev_cursor có trong response?
□ cursor cuối (no more pages): next_cursor = null?
□ Invalid cursor → 422?
□ Cursor từ page khác không được dùng lẫn lộn?

Kiểm tra ordering:
□ default_order nhất quán giữa các requests?
□ sort=created_at&order=desc hoạt động?
□ sort field không tồn tại → 422?
```

### Bước 7: Filter và Sort Testing

```
Nếu endpoint hỗ trợ filtering/sorting:

Filter testing:
□ Filter theo từng field được spec hỗ trợ
□ Filter với giá trị không tồn tại → empty array (không phải 404)
□ Filter với invalid value → 422
□ Multiple filters (AND logic): cả 2 điều kiện phải khớp
□ Case sensitivity: filter có case-sensitive không?
□ Wildcard/partial search nếu có (LIKE queries)?
□ Date range filters: ?from=2024-01-01&to=2024-12-31

Sort testing:
□ Sort ASC và DESC đều hoạt động?
□ Sort by multiple fields: ?sort=name,created_at
□ Sort với null values: null first hay last?

Search testing (nếu có full-text search):
□ Empty search string → all results?
□ Special characters trong search?
□ SQL injection trong search parameter → sanitized
```

### Bước 8: Error Response Formats

```
Verify error responses nhất quán và informative:

Standard error format:
□ Mọi error response có cùng structure không?
□ Recommended format:
  {
    "error": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [{"field": "email", "message": "Invalid format"}]
  }

□ error code là SCREAMING_SNAKE_CASE?
□ Validation errors list tất cả fields lỗi cùng lúc (không chỉ lỗi đầu tiên)?
□ Error messages bằng ngôn ngữ phù hợp (theo Accept-Language header)?
□ Stack traces và internal paths KHÔNG được expose trong production?
□ 500 errors có correlation ID để trace logs?
□ Rate limit errors có Retry-After header?
```

### Bước 9: Backward Compatibility Check

```
Chỉ áp dụng khi API đang update (không phải API mới):

BREAKING CHANGES (không được phép trong minor/patch versions):
□ Xóa endpoint?
□ Xóa required field trong response?
□ Đổi data type của field?
□ Đổi status code?
□ Thay đổi authentication method?
□ Đổi pagination mechanism?

NON-BREAKING (cho phép):
□ Thêm optional field trong response (consumers phải ignore unknown fields)
□ Thêm optional field trong request
□ Thêm new endpoint
□ Thêm enum value mới (consumers phải handle unknown enums)

Test với consumer cũ:
□ Old client (bỏ qua new fields) có bị break không?
□ Old client gửi request thiếu optional new field → vẫn hoạt động?
□ Kiểm tra API versioning scheme (URL path /v1/ vs header)?
```

### Bước 10: Consumer Contract Tests

```
Nếu có consumer-driven contract testing setup:

□ Provider tests chạy pass không? (API thoả mãn mọi consumer contracts)
□ Pact files được update khi API thay đổi?
□ Consumer tests được notify khi API có breaking change?

Manual consumer contract verification:
□ Liệt kê danh sách consumers đã biết của API này
□ Với mỗi consumer: test case quan trọng nhất của họ có còn pass không?
□ Frontend mock data có được update nếu API response thay đổi?
```

---

## Format Output: API Contract Test Results

```markdown
## API Contract Test Results

**Agent**: api-tester
**Ngày test**: [date]
**API Version**: [version]
**Spec Reference**: [path đến OpenAPI spec]
**Kết luận**: [PASS / FAIL / PARTIAL PASS]

---

### Tổng quan
[2-3 câu: tổng số endpoints tested, pass rate, vấn đề chính]

---

### Kết quả theo Endpoint

| Endpoint | Method | Schema | Status Codes | Pagination | Filters | Kết quả |
|----------|--------|--------|-------------|-----------|---------|---------|
| /users | GET | PASS | PASS | PASS | PASS | PASS |
| /users/:id | GET | PASS | FAIL | N/A | N/A | FAIL |
| ... | | | | | | |

---

### Chi tiết Failures

#### [POST /orders] — Schema Validation FAIL
- **Vấn đề**: Field `total_amount` trả về float thay vì integer (cents)
  - Expected: `total_amount: 1500` (cents)
  - Actual: `total_amount: 15.00` (float dollars)
- **Impact**: Consumer parsing có thể bị lỗi precision
- **REQ-ID**: REQ-ORDER-002

#### [GET /products] — Status Code FAIL
- **Vấn đề**: Trả về 500 khi filter `price_min > price_max`
  - Expected: 422 với validation error
  - Actual: 500 Internal Server Error
- **REQ-ID**: REQ-PROD-005

---

### Backward Compatibility
[COMPATIBLE / BREAKING CHANGES DETECTED]
[Liệt kê breaking changes nếu có]

### Test Coverage Summary
- Tổng endpoints: [N]
- Đã test: [N]
- PASS: [N] ([X]%)
- FAIL: [N]
- Blocked (cần data): [N]

### Khuyến nghị
[Action items để fix failures]
```

---

## Checklist trước khi submit

```
□ Đọc và hiểu toàn bộ API spec trước khi test
□ Test mọi endpoint (không bỏ sót)
□ Schema validation đi qua cả request lẫn response
□ Status codes cover happy path và sad path
□ Pagination tested nếu có
□ Error format nhất quán
□ Backward compatibility check nếu là API update
□ REQ-ID được reference trong mọi test case
□ Kết quả rõ ràng: PASS/FAIL per endpoint
```
