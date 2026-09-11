# Playbook: Viết API Documentation

> **Type**: Agent Skill Playbook
> **Agent**: tech-writer
> **Triggered by**: Khi cần viết API documentation — sau khi API design hoặc implementation hoàn thành
> **Output**: API documentation (format tùy context: OpenAPI HTML, Markdown, hoặc docs site)

---

## Khi nào dùng playbook này

- Sau khi `/wf-design` hoàn thành API design và có OpenAPI/Swagger spec
- Khi developer hoàn thành implementation của API endpoints mới
- Khi có breaking changes cần update docs trước release
- Khi audit phát hiện API thiếu documentation

---

## Procedure

### Bước 1: Đọc OpenAPI spec và codebase

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (API specs)
READ: tech-writing-patterns.md (OpenAPI best practices, API docs template)

Thu thập:
□ OpenAPI/Swagger spec file (YAML hoặc JSON)
□ Authentication implementation (JWT, API key, OAuth)
□ Rate limiting config và headers
□ Error response format (consistent hay per-endpoint?)
□ Versioning scheme (URL path vs header vs query param)
□ Code examples từ integration tests (nếu có)
□ REQ-IDs liên quan đến API endpoints
```

Phân loại audience:

```
Audience 1: External developers (public API)
→ Cần: Getting started < 5 phút, full reference, SDKs
→ Divio type: Tutorial + Reference

Audience 2: Internal developers (internal API)
→ Cần: Auth method, endpoint reference, error codes
→ Divio type: Reference + How-to

Audience 3: Integration partners
→ Cần: Authentication flow, webhooks, event types, idempotency
→ Divio type: How-to + Reference
```

### Bước 2: Overview và authentication

Viết Getting Started section — phải pass 5-second test:

```markdown
# [API Name]

[1-2 câu: API này làm gì và ai nên dùng nó]

## Base URL
```
Production: https://api.[domain].com/v[N]
Staging:    https://api-staging.[domain].com/v[N]
```

## Authentication

[API Key / JWT / OAuth 2.0] — chọn và document đầy đủ:

### API Key
```bash
# Header method (preferred)
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://api.[domain].com/v1/resource

# Query param (deprecated, avoid)
curl "https://api.[domain].com/v1/resource?api_key=YOUR_API_KEY"
```

Lấy API key: [link đến dashboard hoặc steps]
Rotate API key: [link hoặc steps]

### Errors khi auth fail
| HTTP Status | Error Code | Meaning |
|-------------|-----------|---------|
| 401 | `UNAUTHORIZED` | API key không hợp lệ hoặc expired |
| 403 | `FORBIDDEN` | API key không có quyền với resource này |
```

**Quy tắc**: Code examples trong Getting Started PHẢI test được ngay bằng curl. Không dùng placeholder URL mà không giải thích.

### Bước 3: Endpoint reference format

Format chuẩn cho mỗi endpoint — nhất quán 100% trong toàn bộ docs:

```markdown
## [Method] [Path]

[REQ-ID: REQ-[DEPT]-[NNN]]
[1-2 câu mô tả endpoint làm gì]

### Request

**HTTP Method**: `[GET/POST/PUT/PATCH/DELETE]`
**URL**: `[/v1/resource/{id}]`
**Authentication**: Required / Optional

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string (UUID) | Yes | ID của resource |

#### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `limit` | integer | No | 20 | Số items per page (max 100) |
| `cursor` | string | No | null | Pagination cursor từ response trước |

#### Request Body (nếu có)

```json
{
  "name": "string (required)",
  "email": "string (required, valid email)",
  "role": "admin | member | viewer (required)"
}
```

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `name` | string | Yes | 1-255 chars | Tên hiển thị |
| `email` | string | Yes | Valid email format | Email đăng nhập |
| `role` | enum | Yes | admin/member/viewer | Vai trò trong system |

### Response

#### Success Response (201 Created)

```json
{
  "id": "usr_01HX5Y...",
  "name": "Nguyen Van A",
  "email": "user@example.com",
  "role": "member",
  "created_at": "2026-03-19T10:00:00Z"
}
```

#### Error Responses

| HTTP Status | Error Code | When |
|-------------|-----------|------|
| 400 | `VALIDATION_ERROR` | Request body không hợp lệ |
| 409 | `EMAIL_ALREADY_EXISTS` | Email đã được dùng |
| 422 | `INVALID_ROLE` | Role không hợp lệ |

### Code Examples

Test tất cả code examples trước khi publish. Mỗi example phải runnable:

#### cURL
```bash
curl -X POST https://api.[domain].com/v1/users \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Nguyen Van A",
    "email": "user@example.com",
    "role": "member"
  }'
```

#### JavaScript (fetch)
```javascript
const response = await fetch('https://api.[domain].com/v1/users', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    name: 'Nguyen Van A',
    email: 'user@example.com',
    role: 'member',
  }),
});
const user = await response.json();
```

#### Python
```python
import httpx

response = httpx.post(
    "https://api.[domain].com/v1/users",
    headers={"Authorization": f"Bearer {api_key}"},
    json={
        "name": "Nguyen Van A",
        "email": "user@example.com",
        "role": "member",
    },
)
user = response.json()
```
```

### Bước 4: Error catalog

Tập hợp tất cả error codes vào một trang — không để developers tìm trong từng endpoint:

```markdown
## Error Reference

### Error Response Format (nhất quán toàn API)
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request body is invalid",
    "details": [
      { "field": "email", "message": "Must be a valid email address" }
    ],
    "request_id": "req_01HX5Y..."
  }
}
```

### HTTP Status Codes

| Status | Meaning | Khi nào xảy ra |
|--------|---------|----------------|
| 200 | OK | GET, PATCH thành công |
| 201 | Created | POST tạo resource thành công |
| 204 | No Content | DELETE thành công |
| 400 | Bad Request | Validation errors |
| 401 | Unauthorized | Auth fail |
| 403 | Forbidden | Không có permission |
| 404 | Not Found | Resource không tồn tại |
| 409 | Conflict | Duplicate resource |
| 422 | Unprocessable Entity | Business logic validation fail |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |

### Application Error Codes

| Code | Status | Description | How to fix |
|------|--------|-------------|-----------|
| `VALIDATION_ERROR` | 400 | Input không hợp lệ | Check `details` field |
| `EMAIL_ALREADY_EXISTS` | 409 | Email đã dùng | Dùng email khác hoặc login |
| `RATE_LIMIT_EXCEEDED` | 429 | Quá giới hạn | Xem Rate Limits section |
| `RESOURCE_NOT_FOUND` | 404 | ID không tồn tại | Verify ID, check permissions |
```

### Bước 5: Rate limits

```markdown
## Rate Limits

| Plan | Requests/minute | Requests/day |
|------|----------------|-------------|
| Free | 60 | 1,000 |
| Pro | 600 | 100,000 |
| Enterprise | Custom | Custom |

### Rate Limit Headers
Mỗi response trả về headers:
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1710844800
```

### Handling Rate Limits
```javascript
if (response.status === 429) {
  const resetTime = response.headers.get('X-RateLimit-Reset');
  const waitMs = (resetTime * 1000) - Date.now();
  await delay(waitMs);
  // retry request
}
```

Khuyến nghị: Implement exponential backoff với jitter cho production clients.
```

### Bước 6: Versioning guide

```markdown
## API Versioning

[API dùng scheme nào — document rõ ràng:]

### URL Versioning (ví dụ)
- Current stable: `v2`
- Previous: `v1` (deprecated, sunset date: 2027-01-01)
- Beta: `v3-beta` (không dùng cho production)

### Deprecation Policy
- Minimum 6 tháng notice trước khi sunset một version
- Deprecation notice trong response header: `Sunset: Sat, 01 Jan 2027 00:00:00 GMT`
- Migration guide available tại: [link]

### Breaking vs Non-Breaking Changes

**Non-breaking** (deploy mà không cần bump version):
- Thêm fields mới vào response
- Thêm optional request parameters
- Thêm endpoints mới

**Breaking** (cần version bump):
- Xóa hoặc rename fields
- Thay đổi kiểu dữ liệu
- Thay đổi authentication method
- Thay đổi URL structure
```

### Bước 7: Changelog

```markdown
## Changelog

### v2.1.0 — 2026-03-19
**New Features**
- `GET /users/{id}/activity` — Lấy activity log của user

**Improvements**
- `POST /users` — Thêm optional field `timezone` (default: UTC)

**Bug Fixes**
- Fix pagination cursor encoding khi có special characters trong filter

---

### v2.0.0 — 2026-01-15
**Breaking Changes**
- `role` field renamed từ `user_role` → `role`
- Migration guide: [link]

**New Features**
- OAuth 2.0 authentication support
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/api-docs/[api-name].md
          hoặc openapi/ folder nếu dùng OpenAPI format

Cấu trúc output:
1. Overview + Base URL
2. Authentication
3. Endpoints (nhóm theo resource/module)
4. Error Reference
5. Rate Limits
6. Versioning Guide
7. Changelog
8. SDK links (nếu có)
```

---

## Checklist trước khi submit

```
□ Tất cả code examples đã test và chạy được
□ Mọi endpoints có REQ-ID reference
□ Error catalog đầy đủ — không có error code "surprise"
□ Authentication flow đầy đủ với examples
□ Rate limit headers và handling code documented
□ Breaking changes clearly marked và migration guide có
□ Changelog có full ngày tháng
□ Không có placeholder text còn sót lại (YOUR_API_KEY, example.com)
```

---

## Lưu ý kỹ thuật

- **Idempotency keys**: Nếu API hỗ trợ, document `Idempotency-Key` header và behavior
- **Pagination**: Document rõ cursor-based vs offset-based — không để developer đoán
- **Webhooks**: Nếu có, document separately với payload examples và signature verification
- **OpenAPI spec**: Nếu có spec file, link đến interactive explorer (Redoc/Swagger UI)
