# API Contract — [TÊN DỰ ÁN]

> READS: `phase2-features/[sys]/[mod]/[feat].md` (business rules, user stories), `P3-01-architecture.md`
> OUTPUT: API conventions, response formats, endpoint registry
> USED BY: `integration-map.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: YYYY-MM-DD | VERSION: v1
>
> **📐 Hướng dẫn scale:** Khi hệ thống có >5 modules hoặc >30 endpoints:
> - Tách file: `api-contract/shared.md` (sections 1-5, 7-8) + `api-contract/[system]-[module].md` (section 6 per module)
> - File này giữ vai trò registry tổng — chỉ liệt kê bảng tóm tắt endpoints
> - Chi tiết request/response body nằm trong feature file tương ứng

> **Mapping Features → Endpoints:** Mỗi endpoint phải trace được về ít nhất 1 FEAT-ID.
> Format: `FEAT-[SYS]-[MOD]-[NNN]` → `[METHOD] /api/v1/[path]`
> Ví dụ: `FEAT-CRM-CUST-001` → `POST /api/v1/customers`
> Ghi chú FEAT-ID vào comment của mỗi endpoint group.

---

## 1. Global Conventions

```
Base URL:      /api/v1
Auth:          Bearer JWT trong header "Authorization: Bearer <token>"
Content-Type:  application/json
Date format:   ISO 8601 (2024-01-15T10:30:00Z) — UTC
ID format:     UUID v4
Soft delete:   DELETE trả { success: true }, record vẫn còn trong DB
```

**Pagination (bắt buộc cho mọi list endpoint):**
```
Query params:
  page:   number (default: 1)
  limit:  number (default: 20, max: 100)
  sort:   string (field name, default: 'createdAt')
  order:  'asc' | 'desc' (default: 'desc')
```

**Filtering:**
```
Query params:
  search: string (full-text search trên các field được phép)
  status: enum value(s)
  [field]: specific filter value
```

---

## 2. Standard Response Envelopes

```typescript
// ✅ Success — single item
{
  "success": true,
  "data": { ...EntityObject }
}

// ✅ Success — list với pagination
{
  "success": true,
  "data": [ ...EntityArray ],
  "meta": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "totalPages": 8
  }
}

// ❌ Error — mọi loại lỗi
{
  "success": false,
  "error": "Human-readable error message",
  "code": "MACHINE_READABLE_CODE",
  "details": [                              // Optional, chỉ cho validation errors
    { "field": "email", "message": "Email không hợp lệ" }
  ]
}
```

---

## 3. HTTP Status Codes

| Code | Khi nào | Error code thường gặp |
|------|---------|----------------------|
| 200 | Success (GET, PUT, DELETE) | — |
| 201 | Created (POST thành công) | — |
| 400 | Bad request, validation failed | `VALIDATION_ERROR` |
| 401 | Chưa auth hoặc token hết hạn | `UNAUTHORIZED` |
| 403 | Không đủ quyền | `FORBIDDEN` |
| 404 | Resource không tồn tại | `NOT_FOUND` |
| 409 | Conflict (duplicate, state invalid) | `CONFLICT`, `DUPLICATE` |
| 429 | Rate limit exceeded | `RATE_LIMIT_EXCEEDED` |
| 500 | Server error | `INTERNAL_ERROR` |
| 503 | Service unavailable / dependency down | `SERVICE_UNAVAILABLE` |

---

## 4. Error Codes Registry

| Code | HTTP | Mô tả |
|------|------|-------|
| `VALIDATION_ERROR` | 400 | Input không đúng format hoặc vi phạm constraint |
| `UNAUTHORIZED` | 401 | Thiếu token hoặc token không hợp lệ |
| `TOKEN_EXPIRED` | 401 | JWT đã hết hạn |
| `FORBIDDEN` | 403 | Có token nhưng không đủ quyền |
| `NOT_FOUND` | 404 | Resource không tồn tại hoặc đã bị xóa |
| `DUPLICATE` | 409 | Vi phạm unique constraint |
| `INVALID_STATE` | 409 | Thao tác không hợp lệ với trạng thái hiện tại |
| `DEPENDENCY_EXISTS` | 409 | Không thể xóa vì đang được reference |
| `RATE_LIMIT_EXCEEDED` | 429 | Quá nhiều request |
| `INTERNAL_ERROR` | 500 | Lỗi server — không expose chi tiết |
| `SERVICE_UNAVAILABLE` | 503 | Dependent service không phản hồi |
| `[ENTITY]_NOT_FOUND` | 404 | Entity cụ thể không tìm thấy |
| `[ENTITY]_DUPLICATE` | 409 | Entity bị trùng |

---

## 5. Authentication Endpoints

### POST /api/v1/auth/login
```
Request:
  { "email": string, "password": string }

Response 200:
  {
    "success": true,
    "data": {
      "accessToken": "eyJ...",
      "refreshToken": "eyJ...",
      "expiresIn": 3600,
      "user": {
        "id": "uuid",
        "email": "string",
        "fullName": "string",
        "role": "string"
      }
    }
  }

Error 401: { "success": false, "code": "INVALID_CREDENTIALS" }
```

### POST /api/v1/auth/refresh
```
Request:
  { "refreshToken": string }

Response 200:
  { "success": true, "data": { "accessToken": "...", "expiresIn": 3600 } }

Error 401: { "success": false, "code": "INVALID_REFRESH_TOKEN" }
```

### POST /api/v1/auth/logout
```
Request: (Bearer token trong header)
Response 200: { "success": true }
```

---

## 6. Endpoints By System

> Copy pattern này cho mỗi system/module. Chi tiết request/response xem feature file tương ứng.

> **BẮT BUỘC — FEAT-ID Traceability:** Mỗi API endpoint PHẢI được tag với FEAT-ID từ `phase2-features/`. Cột FEAT-ID trong bảng endpoint registry là **BẮT BUỘC** — không được để trống. FEAT-ID format: `FEAT-[SYS]-[MOD]-[NNN]`. Validate trước sign-off: mọi FEAT-ID phải tồn tại trong `req-registry.json`. Thiếu FEAT-ID → wf-verify-sync không thể trace requirement-to-API coverage.

### SYS-[XXX]: [System Name]

#### Module: [Module Name] (MOD-[SYS]-[MOD])

| Method | Path | Auth | Description | FEAT-ID |
|--------|------|------|-------------|---------|
| GET | `/api/v1/[sys]/[resource]` | JWT | List + pagination + filter | [FEAT-XXX-NNN] |
| GET | `/api/v1/[sys]/[resource]/:id` | JWT | Detail | [FEAT-XXX-NNN] |
| POST | `/api/v1/[sys]/[resource]` | JWT | Create | [FEAT-XXX-NNN] |
| PUT | `/api/v1/[sys]/[resource]/:id` | JWT | Update | [FEAT-XXX-NNN] |
| DELETE | `/api/v1/[sys]/[resource]/:id` | JWT | Soft delete | [FEAT-XXX-NNN] |

#### Module: [Module Name 2] (MOD-[SYS]-[MOD2])

| Method | Path | Auth | Description | FEAT-ID |
|--------|------|------|-------------|---------|
| GET | `/api/v1/[sys]/[resource]` | JWT | List + pagination + filter | [FEAT-XXX-NNN] |

---

## 7. Internal API (Service-to-Service)

> Prefix `/internal/` — KHÔNG expose ra public, chỉ dùng giữa services.
>
> **📐 Lưu ý kiến trúc:**
> - **Microservices:** Dùng REST `/internal/` calls như mô tả bên dưới
> - **Modular Monolith:** Thay REST calls bằng internal method calls (IMediator, DI, hoặc module interface).
>   Section này vẫn hữu ích để define service boundaries và contracts — chỉ khác transport layer.
>   Ghi rõ trong P3-01-architecture.md kiến trúc đã chọn.

```
Auth: Service-to-service token (khác user JWT)
Header: "X-Internal-Token: <service-secret>"
Timeout: 3s default, 10s cho heavy queries
Retry: 3 lần với exponential backoff
```

| Method | Path | Caller | Purpose |
|--------|------|--------|---------|
| GET | `/internal/users/:id` | Any system | Verify user info |
| GET | `/internal/[sys]/[resource]/:id` | [SYS-YY] | [Mục đích] |

---

## 8. Rate Limiting

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| Auth endpoints (`/auth/*`) | 10 req | 1 phút |
| General API | 200 req | 1 phút |
| Internal API | 1000 req | 1 phút |
| Export/Report | 5 req | 1 phút |
