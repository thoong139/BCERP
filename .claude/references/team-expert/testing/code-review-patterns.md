# Testing - Code Review Patterns & Anti-Patterns

> **Domain**: Testing / Code Quality Review
> **Last Updated**: 2026-03-15

---

## 1. Anti-Patterns Phổ biến

### Callback Hell

```typescript
// ANTI-PATTERN:
getData(function(a) {
  getMoreData(a, function(b) {
    getMoreData(b, function(c) { ... })
  })
})

// FIX: async/await
const a = await getData()
const b = await getMoreData(a)
const c = await getMoreData(b)
```

### Magic Numbers

```typescript
// ANTI-PATTERN:
if (status === 3) { ... }

// FIX: named constants
const ORDER_STATUS_SHIPPED = 3
if (status === ORDER_STATUS_SHIPPED) { ... }
```

### God Function

```typescript
// ANTI-PATTERN: 1 function làm mọi thứ
function processOrder(order) {
  // validate... 50 lines
  // calculate... 30 lines
  // save... 20 lines
  // notify... 15 lines
}

// FIX: tách responsibilities
function validateOrder(order) { ... }
function calculateTotal(order) { ... }
function saveOrder(order) { ... }
function notifyCustomer(order) { ... }
```

### N+1 Query

```typescript
// ANTI-PATTERN:
for (const order of orders) {
  const user = await db.findUser(order.userId) // N queries
}

// FIX: batch query
const userIds = orders.map(o => o.userId)
const users = await db.findUsers({ id: { in: userIds } }) // 1 query
```

---

## 2. Security Patterns cần kiểm tra

| Loại | Kiểm tra | Ví dụ lỗi |
|------|----------|-----------|
| SQL Injection | Parameterized queries | `db.query('SELECT * FROM users WHERE name = ' + name)` |
| XSS | Output encoding | `innerHTML = userInput` |
| Command Injection | Input sanitization | `exec('ls ' + userPath)` |
| Auth Bypass | Middleware check | Route thiếu auth middleware |
| Secrets Exposure | No hardcoded secrets | `const API_KEY = 'sk-xxx'` |
| IDOR | Object-level authorization | Truy cập resource bằng ID không thuộc user |

---

## 3. REQ-ID Traceability Pattern

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-001
// Module: Order Management
export class OrderService {
  // ...
}
```

Mọi code file thực thi business logic cần có REQ-ID reference.

---

## 4. Architecture Patterns cần kiểm tra

| Pattern | Kiểm tra | Violation |
|---------|----------|-----------|
| Separation of Concerns | Controller không chứa business logic | Business logic trong route handler |
| Dependency Injection | Dependencies injected, không hardcoded | `new DatabaseService()` trong constructor |
| Single Responsibility | 1 class/function = 1 responsibility | Class có >5 public methods không liên quan |
| Error Handling | Consistent error handling pattern | Mix try-catch và .catch(), inconsistent error types |

---

## 5. Review Priority Order

1. **Correctness** — Logic thực hiện đúng yêu cầu? Edge cases?
2. **Security** — Injection, auth bypass, input validation, secrets?
3. **Performance** — N+1 queries, bottlenecks, allocations trong loop?
4. **Maintainability** — Naming, complexity, duplication, architecture?
5. **Test Coverage** — Critical flows tested? Positive/negative/edge cases?

---

## 6. Review Output Severity Levels

| Level | Marker | Ý nghĩa | Action |
|-------|--------|---------|--------|
| BLOCKER | 🔴 | Phải sửa trước khi merge | Block merge |
| SUGGESTION | 🟡 | Nên sửa để code tốt hơn | Recommend |
| NIT | 💭 | Tốt nếu sửa, không bắt buộc | Optional |
