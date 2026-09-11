# Playbook: Implement Feature

> **Type**: Agent Skill Playbook
> **Agent**: developer
> **Triggered by**: `/wf-implement-feature` khi cần implement một feature mới từ task spec
> **Output**: Feature code (business logic + API handlers + migrations) kèm unit tests và integration tests

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature`
- Khi đã có task spec tại `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
- Khi technical design (Phase 3) đã được approve

---

## Procedure

### Bước 1: Đọc task spec và xác định scope

**Success Criteria:**
□ REQ-ID và FEAT-ID đã xác định
□ Dependencies và API contracts đã liệt kê đầy đủ
□ Acceptance criteria đã nêu rõ

```
INPUT: Path do skill cung cấp qua prompt
FALLBACK: .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md

Cần xác định:
□ REQ-ID và FEAT-ID của feature này
□ Module system và layer (API / Service / Repository / Domain)
□ Dependencies: external services, shared packages, database tables
□ API contracts: endpoints, request/response schema
□ Business rules và validation logic
□ Acceptance criteria để biết khi nào "done"
```

### Bước 2: Đọc architecture docs liên quan

```
Đọc theo thứ tự ưu tiên:

1. API contract: .mc-data/docs/phase3-architecture/[sys]/api-contracts.md
   → Endpoint signatures, HTTP methods, status codes
   → Request body schema, response schema

2. Database schema: .mc-data/docs/phase3-architecture/[sys]/database-schema.md
   → Table/collection structure
   → Foreign key relationships
   → Index hints nếu có

3. Architecture overview: .mc-data/docs/phase3-architecture/[sys]/architecture-overview.md
   → Layer structure (Controller → Service → Repository)
   → Dependency injection patterns
   → Error handling conventions dự án dùng

LOAD KNOWLEDGE khi cần:
→ API design patterns: READ .claude/references/team-expert/engineering/api-design.md
→ Database patterns: READ .claude/references/team-expert/engineering/database-patterns.md
→ Security checklist: READ .claude/references/team-expert/engineering/security-checklist.md
```

### Bước 3: Setup module structure

```
Tạo file structure theo architecture đã định sẵn. Ví dụ:

src/
├── [module]/
│   ├── [module].controller.ts    ← HTTP layer (routing, request parsing)
│   ├── [module].service.ts       ← Business logic (orchestration)
│   ├── [module].repository.ts    ← Data access (queries, ORM)
│   ├── [module].dto.ts           ← Input validation schemas
│   ├── [module].entity.ts        ← Domain model / DB entity
│   └── __tests__/
│       ├── [module].service.spec.ts
│       └── [module].controller.spec.ts

QUAN TRỌNG: Đặt tên file và class phản ánh domain rõ ràng.
Ưu tiên: calculateOrderTotalWithDiscount() >> calc()
```

### Bước 4: Implement business logic

**Assumption Gate — DỪNG và hỏi nếu: (BHV-001)**
- Task spec có business rule ambiguous hoặc conflicting
- Validation logic không rõ ngưỡng (min/max, required/optional)
- Error handling path chưa được define trong spec
- External API contract chưa có response schema

```
Thứ tự implement:
1. Domain model / Entity — đây là trung tâm của feature
2. Repository layer — data access, queries
3. Service layer — business logic, orchestration
4. Controller/Handler layer — HTTP request/response mapping
5. DTO / Input validation

Mỗi function/method:
□ Thêm comment REQ-ID ở đầu file hoặc đầu class
   Format: // REQ-ID: REQ-[DEPT]-[NNN]
□ Ghi WHY nếu có quyết định kỹ thuật không hiển nhiên
   Ví dụ: // Dùng optimistic locking vì concurrent updates xảy ra thường xuyên
□ Không hardcode business constants — đặt vào config hoặc enum
□ Xử lý null/undefined cases rõ ràng — không assume input luôn valid

LOAD KNOWLEDGE nếu cần:
→ Security: READ .claude/references/team-expert/engineering/security-checklist.md (Section OWASP A03 - Injection, A01 - Access Control)
→ Database: READ .claude/references/team-expert/engineering/database-patterns.md (Section N+1 prevention, ORM patterns)
```

### Bước 5: Unit tests (TDD nếu có thể)

**Success Criteria:**
□ Coverage ≥ 80% cho business logic (Service layer)
□ Happy path + validation failures + business rule violations đều có test
□ Tất cả tests pass (không skip, không todo)

```
Nếu TDD: viết tests TRƯỚC khi implement → red → green → refactor
Nếu không TDD: viết tests ngay sau implement từng layer

Target coverage: ≥ 80% cho business logic (Service layer)

Ưu tiên test:
1. Happy path — input hợp lệ → output đúng
2. Validation failures — input sai format, thiếu field bắt buộc
3. Business rule violations — vi phạm domain rules
4. Not found cases — entity không tồn tại
5. Concurrent/edge cases — nếu có trên task spec

Xem chi tiết: write-unit-tests.md
```

### Bước 6: Integration tests

```
Integration test kiểm tra luồng end-to-end qua nhiều layers:

□ API endpoint nhận đúng request → gọi service đúng → trả về đúng response
□ Database interactions thực sự (dùng test database, không mock DB)
□ External service calls (dùng mock/stub cho external APIs)

Scope integration test:
- Controller → Service → Repository → DB (in-memory hoặc test container)
- Không test third-party SDK internals
```

### Bước 7: Error handling và logging

```
Error handling:
□ Định nghĩa custom error types cho domain errors
   Ví dụ: OrderNotFoundError, InsufficientInventoryError
□ Không throw raw Error — throw typed errors để caller xử lý đúng
□ Controller layer: map domain errors → HTTP status codes
   (NotFoundError → 404, ValidationError → 400, AuthzError → 403)

Logging:
□ Log ở service layer, không ở repository (tránh noise)
□ Log format: structured (JSON) với fields: action, req_id, user_id, duration_ms
□ Log levels: INFO cho business events, WARN cho recoverable errors, ERROR cho unexpected
□ KHÔNG log sensitive data: password, credit card, PII
```

### Bước 8: Security self-check

```
READ: .claude/references/team-expert/engineering/security-checklist.md (Section 1 - OWASP Top 10)

Checklist bắt buộc trước khi hoàn tất:
□ Input validation: tất cả user input được validate trước khi xử lý
□ Parameterized queries: không string concatenation trong SQL
□ Authorization: mỗi endpoint kiểm tra quyền truy cập (CORE-003)
□ Secrets: không hardcode API keys, passwords, connection strings
□ Error messages: không leak stack trace hay internal paths cho client
```

### Bước 9: Self-review và submit

```
Self-review checklist:
□ Mỗi file code có REQ-ID comment đúng format (CORE-003)
□ Mọi public function có tên tự giải thích — không cần comment giải thích WHAT
□ Unit tests pass: chạy test suite locally
□ Lint/format: không warning/error
□ Không có TODO, workaround chưa ghi chú
□ Nếu có workaround: ghi rõ trong Implementation Report với đề xuất thời điểm refactor

Atomic commits:
□ Mỗi commit = 1 thay đổi logic (entity, service, controller, tests — commit riêng)
□ Conventional commits: feat(module): add [feature-name]

Output:
Ghi Implementation Report vào path do skill cung cấp.
Fallback: .mc-data/work/wf-implement-feature/[feat]-report.md
```

---

## Checklist trước khi submit

```
□ REQ-ID có trong mọi file code
□ Unit test coverage ≥ 80% cho business logic
□ Integration tests cover happy path
□ Không có hardcoded secrets
□ Error handling đầy đủ (typed errors + HTTP mapping)
□ Logging structured, không log PII
□ Security checklist đã pass
□ Atomic commits, mỗi commit có conventional commit message
□ Implementation Report ghi rõ technical decisions + any tech debt
```
