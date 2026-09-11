---
paths:
  - "**/*.controller.ts"
  - "**/*.route.ts"
  - "**/*.routes.ts"
  - "**/*.router.ts"
  - "**/api/**"
  - "**/controllers/**"
---

# API Rules

## 1. Endpoint Structure

- External: `/api/v1/[system]/[resource]` — BẮT BUỘC có version
- Internal: `/internal/[resource]` — chỉ accept service token
- CẤM: `/api/customers` (thiếu version), `/customers` (thiếu prefix)

## 2. Response Envelope

```typescript
// Success
{ "success": true, "data": { ... }, "meta": { "total": 100, "page": 1 } }
// Error
{ "success": false, "error": "MESSAGE", "code": "ERROR_CODE" }
```

KHÔNG expose stack trace cho client.

## 3. HTTP Status Codes

| Code | Use case |
|------|----------|
| 200 | GET/PUT/PATCH success |
| 201 | POST success |
| 400 | Validation error |
| 401 | Missing/invalid token |
| 403 | No permission |
| 404 | Resource không tồn tại |
| 409 | Duplicate/business rule violation |
| 422 | Validation failed |
| 429 | Rate limited |
| 500 | Server error |

## 4. Pagination & Rate Limiting

- Pagination: Default 20, max 100. Query: `?page=1&limit=20&sort=created_at&order=desc`
- Rate limit: Auth 5/phút, Public 100/phút, Internal service-to-service token

## 5. Error Handling Layers

```
Repository → Throw DatabaseError, RecordNotFoundError
Service    → Transform → ValidationError, NotFoundError, ConflictError
Controller → Map → HTTP response (không throw)
Global     → Catch uncaught → log + return 500
```

## 6. Cross-System Integration

- Sync calls: timeout (internal 3s, external 5s) + retry (max 3, exponential backoff)
- Async calls: idempotency key bắt buộc
- Events: publish SAU transaction commit, consumer idempotent, DLQ for failures
- CẤM: Đọc/ghi DB system khác, >2 sync external calls/request, nested transactions

## 7. Resilience & Observability

- Circuit breaker: failureThreshold 5, resetTimeout 30s
- Correlation ID: `x-correlation-id` header, propagate qua tất cả services
- Health check: `/health` endpoint kiểm tra DB, cache, eventBus
