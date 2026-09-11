# Playbook: Thiết kế API Contracts

> **Type**: Agent Skill Playbook
> **Agent**: architect
> **Triggered by**: /wf-design — Phase 3 khi cần thiết kế API layer
> **Output**: `.mc-data/docs/phase3-architecture/api-contracts.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` sau khi system architecture đã được chốt
- Khi hệ thống có nhiều client (Web, Mobile, 3rd-party) cần consume API
- Khi cần tạo OpenAPI spec để frontend/mobile team implement song song
- Khi thiết kế public API hoặc partner API cần contract ổn định

---

## Procedure

### Bước 1: Đọc context đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (feature specs), PHASE3 (system architecture)

Cần xác định:
□ Danh sách features cần expose qua API (từ req-registry.json)
□ Client types: Web SPA / Mobile App / 3rd-party integrations / B2B partners
□ Authentication mechanism đã chọn (từ system-architecture.md hoặc platform-foundations.md)
□ Interface type: Internal API only / Public API / Partner API
□ Performance SLA cho từng endpoint category
□ Existing API nào (nếu là brownfield project)

READ: .claude/references/team-expert/engineering/api-design.md (Section 1 — REST Conventions)
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 5 — API Security)
```

### Bước 2: Chọn API Style với Justification

```
Đánh giá từng API style theo use case:

| Tiêu chí | REST | GraphQL | gRPC |
|---------|------|---------|------|
| Client flexibility | Thấp | Cao (query bất kỳ) | Thấp (typed contract) |
| Performance | Trung bình | Có thể N+1 | Cao (binary protocol) |
| Caching | Dễ (HTTP cache) | Phức tạp | Không native |
| Browser support | Native | Native | Cần gRPC-Web |
| Learning curve | Thấp | Trung bình | Cao |
| Phù hợp | CRUD APIs, public | Complex data fetching, mobile | Internal service-to-service |

Decision rules:
- Public API hoặc 3rd-party integration → REST (với OpenAPI spec)
- Mobile với complex data requirements → REST + hoặc GraphQL BFF
- Internal service-to-service (low latency) → gRPC
- Complex frontend data requirements → GraphQL (phía client-facing)

→ Ghi ADR: "Chọn [REST/GraphQL/gRPC] cho [use case] vì [lý do cụ thể]"
→ Nhiều client types → có thể dùng hybrid (REST public + gRPC internal)

READ: .claude/references/team-expert/engineering/api-design.md (toàn bộ file theo style được chọn)
```

### Bước 3: Resource Modeling

```
Với mỗi domain entity trong hệ thống:

a) Xác định Resources (danh từ, không phải hành động):
   ✓ /users, /orders, /products, /invoices
   ✗ /getUser, /createOrder, /processPayment

b) Xác định Resource Hierarchy (nested khi có ownership):
   /users/{userId}/orders         → Orders của user cụ thể
   /orders/{orderId}/items        → Items trong order
   /projects/{projectId}/members  → Members của project

c) Xác định Actions (không phải CRUD → dùng verb):
   POST /orders/{id}/cancel       → Hủy đơn hàng
   POST /invoices/{id}/send       → Gửi invoice
   POST /users/{id}/verify        → Xác thực tài khoản

d) Mapping Feature → Endpoint:
   Với mỗi feature trong req-registry.json:
   □ Tên feature: ___
   □ REQ-ID: ___
   □ Endpoints cần:
     - [METHOD] /resource → [Mô tả]
     - [METHOD] /resource/{id} → [Mô tả]
```

### Bước 4: Thiết kế Endpoints chi tiết

```
Với mỗi endpoint, xác định đầy đủ:

READ: .claude/references/team-expert/engineering/api-design.md (Section 1 — URL Naming, HTTP Status Codes)

a) URL Pattern (theo naming conventions):
   - Danh từ số nhiều: /products không phải /product
   - kebab-case: /order-items không phải /orderItems
   - Lowercase: /users/123 không phải /Users/123

b) Request design:
   - Path params: cho resource identifier (/users/{id})
   - Query params: cho filtering, sorting, pagination
     GET /products?category=electronics&min_price=100&sort=-created_at&page=1&per_page=20
   - Request body: cho POST/PUT/PATCH (JSON)
   - Headers: Authorization, Content-Type, Idempotency-Key

c) Response design:
   - Success: 200/201/204 với body structure
   - Pagination: cursor-based (large datasets) hoặc offset-based (small datasets)
   - Error: RFC 7807 Problem Details format

d) Bảng endpoint summary:
   | Method | Path | Auth | Rate Limit | REQ-ID |
   |--------|------|------|-----------|--------|
   | GET    | /users | JWT | 100/min | REQ-AUTH-001 |
   | POST   | /users | Admin | 10/min | REQ-AUTH-002 |
   | GET    | /users/{id} | JWT | 100/min | REQ-AUTH-001 |
```

### Bước 5: Request/Response Schema Design

```
Thiết kế schemas theo contract-first approach:

a) Naming conventions:
   - camelCase cho JSON field names
   - snake_case KHÔNG dùng (chọn 1 convention, nhất quán toàn API)
   - Không viết tắt: "orderId" tốt hơn "oid"

b) Data types:
   - ID: string UUID (không phải integer — tránh enumeration attack)
   - Timestamps: ISO 8601 UTC ("2026-03-19T10:30:00Z")
   - Money: integer (cents/đồng — tránh floating point)
   - Enums: string literals ("PENDING" / "ACTIVE" / "CANCELLED")
   - Booleans: "isActive", "hasPermission" — dùng prefix is/has/can

c) Schema template (OpenAPI 3.x):
   schemas:
     CreateOrderRequest:
       type: object
       required: [customerId, items]
       properties:
         customerId:
           type: string
           format: uuid
           description: ID của khách hàng
         items:
           type: array
           minItems: 1
           items:
             $ref: '#/components/schemas/OrderItemInput'
         note:
           type: string
           maxLength: 500

     Order:
       type: object
       properties:
         id:
           type: string
           format: uuid
         status:
           type: string
           enum: [PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED]
         totalAmount:
           type: integer
           description: Tổng tiền tính bằng VND (đơn vị nhỏ nhất)
         createdAt:
           type: string
           format: date-time

d) Common response wrappers:
   List response:
     { "data": [...], "pagination": { "nextCursor": "...", "hasNext": true } }

   Single resource:
     { "data": {...} }

   Error (RFC 7807):
     { "type": "...", "title": "...", "status": 422, "detail": "...", "errors": [...] }
```

### Bước 6: Error Handling Standards

```
READ: .claude/references/team-expert/engineering/api-design.md (Section 2 — Error Response Format)

Chuẩn hóa error codes per domain:

| Error Code | HTTP Status | Khi nào |
|-----------|------------|---------|
| VALIDATION_FAILED | 422 | Input không đúng format/rules |
| RESOURCE_NOT_FOUND | 404 | Entity không tồn tại |
| DUPLICATE_ENTRY | 409 | Trùng unique constraint |
| UNAUTHORIZED | 401 | Thiếu hoặc token invalid |
| FORBIDDEN | 403 | Có token nhưng không có quyền |
| RATE_LIMIT_EXCEEDED | 429 | Vượt rate limit |
| BUSINESS_RULE_VIOLATION | 422 | Không đáp ứng business rule |
| SERVICE_UNAVAILABLE | 503 | Dependency down |

Mỗi error response PHẢI có:
□ trace_id (để debug, correlate với logs)
□ type (URI đến documentation của error)
□ errors[] (khi có nhiều validation errors)
□ KHÔNG expose stack trace hoặc internal paths trong production
```

### Bước 7: Versioning Strategy

```
READ: .claude/references/team-expert/engineering/api-design.md (Section 1 — Versioning Strategies)

Chọn versioning strategy:
- URL Path versioning (/v1/, /v2/) — khuyến nghị cho public API
  → Rõ ràng, dễ test, client có thể pin version
  → Maintain version cũ tối thiểu 12 tháng sau deprecation

Deprecation policy:
1. Announce deprecation: header "Deprecation: true", "Sunset: [date]"
2. Migration guide: publish trước 3 tháng
3. Sunset date: remove sau thời hạn công bố

Backward compatibility rules:
□ KHÔNG xóa field từ response (breaking change)
□ KHÔNG đổi field name (breaking change)
□ KHÔNG đổi field type (breaking change)
□ CÓ THỂ thêm optional field mới (non-breaking)
□ CÓ THỂ thêm enum value mới — nhưng cần thông báo
```

### Bước 8: Authentication & Authorization per Endpoint

```
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 2, 3)

Với mỗi endpoint, xác định:

a) Authentication level:
   - PUBLIC: Không cần token (trang landing, health check)
   - AUTHENTICATED: Cần valid JWT
   - ADMIN: Cần role=admin trong JWT claims

b) Authorization rules:
   - Ownership check: User chỉ xem data của chính mình
   - Role check: Manager xem tất cả trong department
   - Resource-level check: Chỉ owner hoặc shared-with

c) Security headers cho mỗi response:
   □ Không leak sensitive data trong error messages
   □ Không trả về PII trong response không cần thiết

d) Rate limiting per endpoint category:
   READ: .claude/references/team-expert/engineering/api-design.md (Section 6 — Rate Limiting)

   | Category | Limit | Algorithm |
   |---------|-------|-----------|
   | Auth endpoints | 5 req/phút/IP | Token Bucket |
   | Read endpoints | 100 req/phút/user | Sliding Window |
   | Write endpoints | 30 req/phút/user | Token Bucket |
   | Webhook delivery | 1000 req/phút | Fixed Window |
```

### Bước 9: Idempotency & Webhook Design

```
READ: .claude/references/team-expert/engineering/api-design.md (Section 7 — Idempotency, Section 8 — Webhook)

Idempotency cho POST endpoints:
□ Xác định endpoints nào cần Idempotency-Key header
   → Payment creation, Order placement, Invoice generation
□ TTL của idempotency cache: 24 giờ
□ Lưu: key → (status, response body, timestamp)

Webhook design (nếu hệ thống publish events):
□ Event naming: "resource.action" format (order.completed, user.created)
□ Event payload: id, type, created_at, api_version, data.object, data.previous
□ Retry policy: 6 attempts với exponential backoff
□ Signature: HMAC-SHA256 trong header "X-Signature-256"
□ Verify timestamp trong payload (reject nếu > 5 phút — replay attack)
```

### Bước 10: Generate OpenAPI Spec

```
READ: .claude/references/team-expert/engineering/api-design.md (Section 5 — OpenAPI 3.x)

Tạo file openapi.yaml với:
□ info.title, version, description
□ servers[] (production, staging, local)
□ paths{}: mỗi endpoint với summary, operationId, tags, security, requestBody, responses
□ components.schemas{}: tất cả request/response schemas
□ components.responses{}: reusable error responses (ValidationError, NotFound, RateLimitExceeded)
□ components.securitySchemes{}: bearerAuth, apiKeyAuth

operationId format: [verb][Resource] — createOrder, getUser, listProducts, cancelOrder

Lưu tại: .mc-data/docs/phase3-architecture/openapi.yaml
```

### Bước 11: Viết Output

```
Ghi vào: .mc-data/docs/phase3-architecture/api-contracts.md

Cấu trúc output:

# API Contracts — [Tên dự án]

## 1. API Style Decision
[Style được chọn + lý do + link ADR]

## 2. Base URL & Versioning
[Base URL, versioning strategy, deprecation policy]

## 3. Authentication & Rate Limits
[Cơ chế auth, rate limit per category]

## 4. Standard Response Format
[Success / Error response format với examples]

## 5. Error Code Reference
[Bảng error codes]

## 6. Endpoint Catalog
[Nhóm theo domain/module]
[Với mỗi endpoint: Method, Path, Auth, Description, REQ-ID]

## 7. Schema Reference
[Key schemas với descriptions]
[Link đến openapi.yaml đầy đủ]

## 8. Idempotency Guidelines
[Endpoints nào cần Idempotency-Key]

## 9. Webhook Events (nếu có)
[Event catalog, payload format, retry policy]

## 10. Breaking Change Policy
[Quy tắc backward compatibility, deprecation timeline]
```

---

## Checklist trước khi submit

```
□ Mỗi endpoint có REQ-ID tham chiếu
□ ADR tồn tại cho API style selection
□ OpenAPI spec sinh ra từ schemas đã thiết kế
□ Error format nhất quán theo RFC 7807
□ Authentication rõ ràng cho từng endpoint (PUBLIC / AUTHENTICATED / ADMIN)
□ Rate limits đã xác định cho mỗi endpoint category
□ Idempotency-Key bắt buộc cho non-idempotent POST endpoints (payment, order)
□ Backward compatibility rules được ghi rõ
□ Không expose internal paths hoặc stack traces trong error responses
□ Versioning strategy và deprecation policy đã documented
```
