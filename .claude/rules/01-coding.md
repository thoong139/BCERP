---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.java"
  - "**/*.cs"
  - "**/*.go"
  - "**/*.rs"
---

# Coding Standards

## 1. Naming Conventions

| Loại | Convention | Ví dụ |
|------|-----------|-------|
| File | `kebab-case` | `customer-service.ts` |
| Class/Interface/Type | `PascalCase` | `CustomerService`, `CreateCustomerDto` |
| Function/Method/Variable | `camelCase` | `getCustomerById()` |
| Constant | `SCREAMING_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Enum | `PascalCase` + values `SCREAMING_SNAKE` | `OrderStatus.PENDING` |
| DB table/column | `snake_case` | `customer_orders`, `created_at` |
| Route/URL | `kebab-case` | `/api/v1/customer-orders` |

## 2. File Structure

```
[feature]/
├── [feature].controller.ts   # HTTP handlers — KHÔNG business logic
├── [feature].service.ts      # Business logic — KHÔNG DB queries
├── [feature].repository.ts   # DB operations — KHÔNG business logic
├── [feature].dto.ts          # Types + validation
└── [feature].spec.ts         # Tests
```

**Limits:** File ≤500 lines | Function ≤50 lines | Nesting ≤4 levels | Params ≤4

## 3. Code Patterns

- **Immutability:** Tạo object mới `{ ...obj, field: value }`, KHÔNG mutate trực tiếp
- **Error handling:** Explicit try/catch, log error message, throw typed error. KHÔNG swallow `catch(e){}` hoặc expose `error.stack`
- **Validation:** Validate tại controller boundary. KHÔNG trust unvalidated input (`any`)
- **Import order:** Built-ins → External packages → Internal alias (`@/`) → Relative (`./`)
- **Comments:** Giải thích WHY + context, KHÔNG comment obvious code
- **DI:** Constructor injection, KHÔNG direct import (tight coupling)

## 4. Testing

- Coverage ≥80% service layer
- Unit tests (`*.spec.ts`): Mock dependencies, cover happy path + validation + edge cases
- Integration tests (`*.e2e-spec.ts`): Test DB (không production), cover auth + permissions + response format

## 5. Logging

| Level | Use case |
|-------|----------|
| `error` | Exceptions, unrecoverable |
| `warn` | Recoverable, deprecated |
| `info` | Business events |
| `debug` | Technical details (dev only) |

Structured format: `logger.info('Event', { key: value })`. KHÔNG log sensitive data (password, JWT, credit card).

## 6. TypeScript Strict Mode (BẮT BUỘC)

```json
{ "compilerOptions": { "strict": true, "noImplicitAny": true, "strictNullChecks": true }}
```

KHÔNG dùng `any` — luôn explicit type.
