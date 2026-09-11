# Testing - API Testing Patterns & Practices

> **Domain**: Testing / API Quality Assurance
> **Last Updated**: 2026-03-15
> **Nguồn**: REST API testing best practices, Pact docs, OWASP API Security Top 10, Postman API Testing Guide

---

## 1. API Test Layer Model

Mỗi tầng kiểm tra một khía cạnh khác nhau, chạy theo thứ tự từ fast/cheap đến slow/expensive.

```
Contract Tests (schema validation — OpenAPI, Pact)
├── Functional Tests (CRUD operations, business logic)
│   ├── Boundary Tests (limits, edge cases, invalid inputs)
│   │   ├── Security Tests (auth, injection, OWASP Top 10)
│   │   │   └── Performance Tests (load, stress, rate limits)
```

**Nguyên tắc:** Lỗi được bắt càng sớm (tầng trên) → chi phí fix càng thấp.

---

## 2. Contract Testing Patterns

### Consumer-Driven Contracts (Pact)

```
Consumer Service         Pact Broker          Provider Service
─────────────────        ───────────          ────────────────
1. Viết interaction  →   2. Publish pact  →   3. Verify pact
   (expected request,        contract             (chạy real API
   expected response)                             với mock data)
```

**Lợi ích:** Phát hiện breaking changes trước khi deploy — không cần integration env.

### Schema Validation (OpenAPI / JSON Schema)

- Validate request body, response body, headers, status codes
- Dùng `ajv` (JS), `pydantic` (Python), `openapi-validator` trong CI
- Mỗi endpoint phải có schema — không accept `additionalProperties: true` ở production contract

### Provider Verification Checklist

- [ ] Tất cả Pact interactions pass trên CI provider side
- [ ] Schema không bị breaking change (field removed, type changed)
- [ ] Required fields không được thêm vào response mà consumer không expect
- [ ] Version được tag trong Pact Broker sau mỗi successful verification

---

## 3. REST API Test Checklist by HTTP Method

| Method | Happy Path | Auth | Validation | Edge Cases | Idempotency |
|--------|-----------|------|------------|------------|-------------|
| GET | 200 + correct body | 401 (no token), 403 (wrong role) | Invalid ID format → 400/404 | Empty result → 200 + `[]`, large dataset pagination | Gọi 2 lần → cùng kết quả |
| POST | 201 + resource created | 401, 403 | Missing required field → 422, invalid type → 422 | Duplicate → 409, max payload size | Không idempotent — double submit phải xử lý |
| PUT | 200/204 + updated | 401, 403 | Partial body → 422, wrong ID → 404 | Concurrent update → 409/412 | Gọi 2 lần → cùng kết quả |
| PATCH | 200/204 + patched | 401, 403 | Invalid field name → 422 | Patch non-existent → 404 | Gọi 2 lần → cùng kết quả |
| DELETE | 200/204 | 401, 403 | Non-existent ID → 404 | Double delete → 404/409 | Gọi 2 lần → 404 lần 2 |

---

## 4. Common API Test Scenarios

### 4a. Authentication & Authorization

| Scenario | Expected Status | Ghi chú |
|----------|----------------|---------|
| Không có Authorization header | 401 Unauthorized | Message không tiết lộ thông tin hệ thống |
| Token hết hạn | 401 Unauthorized | Body chứa error code `TOKEN_EXPIRED` |
| Token sai chữ ký | 401 Unauthorized | |
| Token hợp lệ nhưng sai role | 403 Forbidden | |
| Token hợp lệ, đúng role | 200 OK | |
| API key bị revoke | 401 Unauthorized | |
| Token của user khác truy cập resource | 403 Forbidden | Kiểm tra object-level authorization (BOLA) |

### 4b. Pagination

| Scenario | Expected Behavior |
|----------|------------------|
| Trang đầu tiên (`page=1`) | Items đúng, `meta.total` chính xác, `links.prev` null |
| Trang cuối cùng | Items đúng, `links.next` null |
| `page` vượt quá tổng số trang | 200 + `data: []` hoặc 404 tùy convention |
| `page=0` hoặc `page=-1` | 400 Bad Request |
| `limit=0` | 400 hoặc default limit |
| `limit` vượt max (ví dụ > 1000) | Tự động cap về max, không error |
| Không có record nào | 200 + `data: []`, không phải 404 |

### 4c. Filtering & Sorting

| Scenario | Expected Behavior |
|----------|------------------|
| Filter theo field hợp lệ | Kết quả đúng, performance đạt SLA |
| Filter theo field không tồn tại | 400 Bad Request với message rõ ràng |
| Sort field không tồn tại | 400 Bad Request |
| SQL injection trong filter value | Sanitized — không trả về dữ liệu ngoài scope |
| Special characters (`'`, `"`, `<`, `>`) | Escaped đúng, không gây lỗi |

### 4d. Concurrent Requests (Race Conditions)

```
Scenario: Hai user cùng đặt hàng item cuối cùng trong kho

Request A                    Request B
    │                            │
    ├─── GET /inventory ──────►  │  (stock = 1)
    │                            ├─ GET /inventory ──► (stock = 1)
    ├─── POST /orders ────────►  │  (success → stock = 0)
    │                            ├─ POST /orders ──────► 409 Conflict
    │                            │  hoặc 422 (stock insufficient)
```

**Kiểm tra:** Optimistic locking (`If-Match: "<etag>"`), pessimistic locking, database-level constraints.

### 4e. Error Handling Reference

| Status | Scenario | Response Body phải có |
|--------|----------|----------------------|
| 400 | Request syntax sai | `error_code`, `message`, field errors nếu validation |
| 401 | Chưa xác thực | `error_code: "UNAUTHORIZED"` |
| 403 | Không có quyền | `error_code: "FORBIDDEN"` — không leak resource existence |
| 404 | Resource không tồn tại | `error_code: "NOT_FOUND"` |
| 409 | Conflict (duplicate, stale update) | `error_code`, detail về conflict |
| 422 | Validation failed | Array of field errors với path + message |
| 429 | Rate limit exceeded | `Retry-After` header, `error_code: "RATE_LIMIT"` |
| 500 | Server error | Generic message — không leak stack trace, log internally |

---

## 5. API Test Data Management

### Chiến lược Test Data

| Chiến lược | Cách dùng | Ưu điểm | Nhược điểm |
|-----------|-----------|---------|------------|
| Fixtures (static JSON) | Load trước khi test suite | Đơn giản, reproducible | Stale, hard-code relationships |
| Factories (dynamic generation) | Tạo on-demand mỗi test | Flexible, isolated | Cần cleanup |
| Database seeding | Chạy migration + seed script | Full control | Chậm, cần env riêng |
| API-driven setup | Dùng API tạo data trong `beforeEach` | Realistic, production-like | Phụ thuộc API hoạt động |

### Cleanup Pattern

```javascript
// Pattern: Create → Test → Cleanup
beforeEach(async () => {
  testUser = await api.post('/users', factory.user());
  authToken = await api.post('/auth/login', testUser.credentials);
});

afterEach(async () => {
  await api.delete(`/users/${testUser.id}`, { headers: { Authorization: adminToken } });
});
```

**Data isolation rule:** Mỗi test phải có data riêng — không share state giữa tests.

---

## 6. API Mocking Strategies

| Tool | Dùng khi | Protocol | Ghi chú |
|------|---------|----------|---------|
| MSW (Mock Service Worker) | Frontend test, Storybook | HTTP | Intercept ở network layer, không cần server |
| WireMock | Integration test, Java/JVM | HTTP, HTTPS | Flexible stub/proxy, record-and-replay |
| Prism (Stoplight) | Contract validation từ OpenAPI | HTTP | Auto-mock từ spec, validation mode |
| Nock (Node.js) | Unit test backend | HTTP | Intercept http module — không cần server |
| Pact Mock Server | Contract testing | HTTP | Generated từ consumer pact |

**Khi nào không nên mock:** Integration test với real database, contract test provider side, performance test.

---

## 7. CI/CD Integration Patterns

### Pipeline Test Execution Order

```
PR Opened
    │
    ▼
[Unit Tests] ──fail──► Block merge
    │ pass
    ▼
[Contract Tests] ──fail──► Block merge
    │ pass
    ▼
[Integration Tests] ──fail──► Block merge
    │ pass
    ▼
[Security Scan (SAST)] ──fail──► Block merge (critical/high)
    │ pass
    ▼
Merge to main
    │
    ▼
[Deploy to Staging]
    │
    ▼
[E2E / Smoke Tests] ──fail──► Rollback + alert
    │ pass
    ▼
[Performance Tests] ──fail──► Alert, manual review
    │ pass
    ▼
[Deploy to Production]
```

### Parallel Test Execution

- Chia tests theo module/domain, chạy song song trên multiple CI workers
- Target: Tổng CI time < 10 phút
- Dùng test sharding (Vitest `--shard`, pytest-xdist, Jest `--runInBand=false`)

### Test Environment Data Isolation

- Mỗi PR/branch có database riêng hoặc schema riêng
- Dùng prefix/namespace cho test data: `test_<branch_name>_<resource>`
- Cleanup scheduled job sau khi PR đóng

---

## 8. Webhook Testing Patterns

### Delivery Verification

```
Test Setup:
  1. Dùng webhook.site hoặc local ngrok tunnel làm receiver
  2. Trigger action tạo event
  3. Verify receiver nhận đúng payload trong < 5 giây

Kiểm tra:
  - Payload structure đúng với schema
  - Headers bao gồm signature (X-Signature-256)
  - Content-Type: application/json
  - HTTP method: POST
```

### Retry Testing

| Scenario | Expected Behavior |
|----------|------------------|
| Receiver trả về 200 | Không retry |
| Receiver trả về 500 | Retry với exponential backoff (1s, 2s, 4s...) |
| Receiver timeout (> 30s) | Retry, log timeout |
| Sau N lần fail | Dead-letter queue, alert, manual replay |
| Receiver trả về 200 sau retry | Mark delivered, không gửi lại |

### Signature Validation

```javascript
// Verify webhook signature (HMAC-SHA256)
const expectedSignature = crypto
  .createHmac('sha256', webhookSecret)
  .update(rawBody)
  .digest('hex');

const receivedSignature = req.headers['x-signature-256'].replace('sha256=', '');

// Dùng timingSafeEqual để tránh timing attack
const isValid = crypto.timingSafeEqual(
  Buffer.from(expectedSignature),
  Buffer.from(receivedSignature)
);
```

**Test case bắt buộc:**
- [ ] Signature hợp lệ → chấp nhận
- [ ] Signature sai → 401, không xử lý payload
- [ ] Thiếu signature header → 400
- [ ] Replay attack (timestamp cũ > 5 phút) → 400
