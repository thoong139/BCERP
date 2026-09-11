# API Design Guidelines - Thiết kế API chuẩn

> **Domain**: Engineering / API Design
> **Last Updated**: 2026-03-15
> **Nguồn**: RFC 7807, OpenAPI Specification 3.x, Google API Design Guide, Stripe API docs

---

## 1. REST API Design Conventions

### URL Naming Patterns

| Rule | Đúng | Sai |
|------|------|-----|
| Danh từ số nhiều | `/users`, `/orders` | `/getUser`, `/createOrder` |
| kebab-case | `/order-items`, `/user-addresses` | `/orderItems`, `/user_addresses` |
| Phân cấp tài nguyên | `/users/{id}/orders` | `/getUserOrders?userId=123` |
| Không trailing slash | `/users/123` | `/users/123/` |
| Lowercase | `/products/featured` | `/Products/Featured` |

```
Collection:  GET    /users              → Danh sách users
Single:      GET    /users/{id}         → User cụ thể
Create:      POST   /users              → Tạo user mới
Full update: PUT    /users/{id}         → Thay thế toàn bộ
Partial:     PATCH  /users/{id}         → Cập nhật một phần
Delete:      DELETE /users/{id}         → Xóa user

Nested:      GET    /users/{id}/orders  → Orders của user
Action:      POST   /orders/{id}/cancel → Action không phải CRUD
```

### HTTP Status Codes Reference

| Code | Tên | Dùng khi |
|------|-----|---------|
| 200 | OK | GET/PUT/PATCH thành công |
| 201 | Created | POST tạo resource thành công |
| 204 | No Content | DELETE thành công, không có body |
| 400 | Bad Request | Input validation failed, malformed request |
| 401 | Unauthorized | Chưa authenticate (thiếu token) |
| 403 | Forbidden | Đã authenticate nhưng không có quyền |
| 404 | Not Found | Resource không tồn tại |
| 409 | Conflict | Duplicate, version conflict (optimistic locking) |
| 422 | Unprocessable Entity | Semantically invalid (business rule violation) |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Lỗi server không mong đợi |
| 503 | Service Unavailable | Maintenance mode, dependency down |

### Pagination Patterns

**Cursor-based (khuyến nghị cho large datasets):**

```json
GET /orders?cursor=eyJpZCI6MTAwfQ&limit=20

Response:
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIwfQ",
    "prev_cursor": "eyJpZCI6ODl9",
    "has_next": true,
    "has_prev": true,
    "limit": 20
  }
}
```

**Offset-based (đơn giản hơn, phù hợp dataset nhỏ):**

```json
GET /products?page=2&per_page=20

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "per_page": 20,
    "total": 1543,
    "total_pages": 78
  }
}
```

**Lý do ưu tiên cursor:** OFFSET lớn gây full table scan; cursor stable khi data thay đổi.

### Filtering, Sorting, Field Selection

```
Filtering:       GET /products?category=electronics&min_price=100&is_active=true
Sorting:         GET /orders?sort=-created_at,+status  (- = DESC, + = ASC)
Field selection: GET /users?fields=id,name,email       (reduce payload size)
Search:          GET /products?q=laptop+gaming
```

### API Versioning Strategies

| Strategy | Ví dụ | Pros | Cons |
|---------|-------|------|------|
| URL Path | `/v1/users` | Rõ ràng, dễ test | URL thay đổi, cần maintain nhiều versions |
| Request Header | `API-Version: 2026-03-15` | URL stable | Khó test qua browser |
| Query Param | `/users?version=1` | Dễ override | Không chuẩn, pollute query |

**Khuyến nghị:** URL Path versioning (`/v1/`, `/v2/`) cho public APIs. Hỗ trợ version cũ tối thiểu 12 tháng sau deprecation.

---

## 2. Error Response Format (RFC 7807 Problem Details)

Chuẩn hóa error response theo RFC 7807 để client xử lý nhất quán:

```json
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://api.company.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more fields failed validation.",
  "instance": "/orders/checkout",
  "trace_id": "abc123def456",
  "errors": [
    {
      "field": "email",
      "code": "INVALID_FORMAT",
      "message": "Email không đúng định dạng"
    },
    {
      "field": "quantity",
      "code": "OUT_OF_RANGE",
      "message": "Số lượng phải từ 1 đến 999",
      "context": { "min": 1, "max": 999, "actual": 0 }
    }
  ]
}
```

**Nguyên tắc:**
- Luôn trả về `trace_id` để debug
- `type` là URI dẫn đến documentation của lỗi đó
- `errors[]` cho validation errors nhiều field
- Không expose stack trace, internal paths trong production

---

## 3. GraphQL Design Patterns

### Schema-First Development

```graphql
# Định nghĩa schema trước, generate code sau
type User {
  id: ID!
  name: String!
  email: String!
  orders(first: Int, after: String): OrderConnection!
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type OrderEdge {
  node: Order!
  cursor: String!
}
```

### Pagination với Connections (Relay spec)

Dùng Connection pattern cho tất cả list queries để consistent với pagination:

```graphql
query {
  orders(first: 10, after: "cursor123") {
    edges {
      node { id, status, total }
      cursor
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
  }
}
```

### Error Handling trong GraphQL

```json
{
  "data": { "createOrder": null },
  "errors": [
    {
      "message": "Insufficient stock for product SKU-123",
      "locations": [{ "line": 2, "column": 3 }],
      "path": ["createOrder"],
      "extensions": {
        "code": "INSUFFICIENT_STOCK",
        "http_status": 422,
        "trace_id": "abc123"
      }
    }
  ]
}
```

---

## 4. gRPC Patterns

### Proto3 Conventions

```protobuf
// Naming: CamelCase cho types, snake_case cho fields
syntax = "proto3";
package company.orders.v1;

// Luôn có request/response wrapper riêng cho flexibility
message CreateOrderRequest {
  string user_id = 1;
  repeated OrderItem items = 2;
  string idempotency_key = 3;  // Idempotency support
}

message CreateOrderResponse {
  Order order = 1;
}

// Streaming patterns
service OrderService {
  rpc CreateOrder (CreateOrderRequest) returns (CreateOrderResponse);
  rpc WatchOrderStatus (WatchOrderRequest) returns (stream OrderStatus); // Server streaming
  rpc BulkImportOrders (stream ImportOrderRequest) returns (ImportResult); // Client streaming
}
```

---

## 5. OpenAPI 3.x Documentation Standards

```yaml
# openapi.yaml structure tối thiểu
openapi: 3.1.0
info:
  title: Company API
  version: 1.0.0
  description: |
    API cho hệ thống Order Management.
    Base URL: https://api.company.com/v1

servers:
  - url: https://api.company.com/v1
    description: Production
  - url: https://staging-api.company.com/v1
    description: Staging

paths:
  /orders:
    post:
      summary: Tạo đơn hàng mới
      operationId: createOrder     # Dùng để generate client SDKs
      tags: [Orders]
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
      responses:
        '201':
          description: Đơn hàng được tạo thành công
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
        '422':
          $ref: '#/components/responses/ValidationError'
        '429':
          $ref: '#/components/responses/RateLimitExceeded'
```

---

## 6. Rate Limiting Patterns

| Algorithm | Cơ chế | Pros | Cons |
|-----------|--------|------|------|
| Token Bucket | Tokens tích lũy theo thời gian, consume per request | Cho phép burst | Phức tạp hơn |
| Sliding Window | Count requests trong cửa sổ thời gian di động | Smooth, fair | Memory cao hơn |
| Fixed Window | Count trong window cố định (mỗi phút) | Đơn giản | Spike ở ranh giới window |

**Response headers chuẩn:**

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1710496800
Retry-After: 60   (khi 429)
```

---

## 7. Idempotency Patterns

Đảm bảo retry an toàn cho non-idempotent operations:

```
Client → POST /orders
         Header: Idempotency-Key: uuid-v4-unique-per-request

Server logic:
  1. Check cache có Idempotency-Key này chưa?
  2. Nếu có → trả về response cũ (không execute lại)
  3. Nếu chưa → execute, lưu response vào cache (TTL 24h)
  4. Trả về response
```

```json
// Request
POST /payments
Idempotency-Key: 7f9a3b2c-1234-5678-abcd-ef0123456789

// Response (lần đầu AND lần retry đều trả về giống nhau)
{
  "payment_id": "pay_abc123",
  "status": "completed",
  "amount": 150000
}
```

---

## 8. Webhook Design

### Event Format

```json
{
  "id": "evt_01HXY789ABC",
  "type": "order.completed",
  "created_at": "2026-03-15T10:30:00Z",
  "api_version": "2026-03-15",
  "data": {
    "object": {
      "id": "ord_12345",
      "status": "completed",
      "total": 150000
    },
    "previous": {
      "status": "processing"
    }
  }
}
```

### Retry Policy

```
Attempt 1: Ngay lập tức
Attempt 2: 30 giây sau
Attempt 3: 5 phút sau
Attempt 4: 30 phút sau
Attempt 5: 2 giờ sau
Attempt 6: 5 giờ sau (final)

→ Nếu vẫn fail: mark as failed, notify webhook owner
```

### Signature Verification

```python
import hmac, hashlib

def verify_webhook(payload: bytes, signature: str, secret: str) -> bool:
    # Signature: HMAC-SHA256 của raw payload với webhook secret
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    # Dùng compare_digest để tránh timing attack
    return hmac.compare_digest(f"sha256={expected}", signature)
```

**Checklist webhook security:**
- [ ] Verify signature mọi request
- [ ] Kiểm tra timestamp trong payload (reject nếu > 5 phút cũ — replay attack)
- [ ] Idempotent processing (dùng `event.id` để deduplicate)
- [ ] Trả về 2xx trong < 5 giây (xử lý async nếu cần lâu hơn)
