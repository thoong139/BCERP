# [FEATURE_NAME] — Implementation Plan & Tasks

> **Feature ID:** [FEAT-SYS-MOD-NNN]
> **REQ-IDs:** [REQ-XXX-NNN, ...]
>
> READS: `phase2-features/[sys]/[mod]/[feat].md`, `phase3-architecture/technical-specs/api-contract.md`, `phase3-architecture/technical-specs/database-design.md`, `phase3-architecture/technical-specs/integration-map.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`
> USED BY: implementation source code

---

## Phần A: Implementation Plan

### A1. Metadata

| Field | Value |
|-------|-------|
| **Feature ID** | FEAT-[SYS]-[MOD]-NNN |
| **Feature Name** | *[Tên feature]* |
| **REQ-IDs** | REQ-XXX-001, REQ-XXX-002 |
| **System** | *[SYSTEM]* |
| **Module** | *[MODULE]* |
| **Sprint** | S0X |
| **Priority** | Critical / High / Medium / Low |
| **Complexity** | Simple / Medium / Complex |
| **Story Points** | *[1-13]* |

---

### A2. Overview

#### A2.1 Business Value

*[Mô tả giá trị nghiệp vụ - user có thể làm gì sau khi feature hoàn thành]*

#### A2.2 Scope

**In Scope:**
- *[Đặc điểm 1]*
- *[Đặc điểm 2]*

**Out of Scope:**
- *[Những gì không làm trong feature này]*

#### A2.3 Dependencies

| Type | Item | Status |
|------|------|--------|
| Feature | FEAT-XXX-YYY | done / pending |
| Module | *[Tên module]* | done / pending |
| API | *[API endpoint]* | done / pending |
| DB | *[Bảng dữ liệu]* | done / pending |

---

#### A2.4 Scope Files & Parallel Safety (BẮT BUỘC — wf-plan-modules Phase 7.5 POPULATE)

> **Mục đích:** Cho phép user (và `wf-implement-feature`) biết feature này tạo/sửa file nào, file nào share với features khác. Dùng để xác định features có thể chạy song song an toàn.
>
> **wf-implement-feature Phase 0.7 sẽ đọc section này** để check cross-feature file conflict trước khi spawn developer agent.

| File Path | Mode | Shared with Features | Ghi chú |
|-----------|------|----------------------|---------|
| `src/modules/[mod]/entities/[Entity].ts` | EXCLUSIVE_WRITE | — | Entity chỉ feature này tạo |
| `src/modules/[mod]/services/[Service].ts` | EXCLUSIVE_WRITE | — | Service business logic |
| `src/modules/[mod]/controllers/[Controller].ts` | EXCLUSIVE_WRITE | — | API controller |
| `src/shared/types.ts` | SHARED_APPEND | FEAT-XXX-002, FEAT-YYY-003 | Append type, KHÔNG xóa types khác |
| `src/database/migrations/[ts]-[name].ts` | EXCLUSIVE_CREATE | — | Migration mới (timestamp unique) |
| `tests/modules/[mod]/[feature].test.ts` | EXCLUSIVE_WRITE | — | Test file của feature |

**Mode definitions:**

- **EXCLUSIVE_WRITE** — chỉ feature này được ghi. Nếu feature khác cần sửa → conflict, phải sequential.
- **EXCLUSIVE_CREATE** — file mới, không tồn tại trước. Conflict nếu 2 features cùng tạo cùng path.
- **SHARED_APPEND** — file shared, mọi feature chỉ APPEND (không modify/delete entries của feature khác). An toàn parallel.
- **SHARED_READ** — chỉ đọc. An toàn parallel hoàn toàn.

**Parallel-Safe Verdict:** *[populate by architect: "SAFE_PARALLEL" / "REQUIRES_SEQUENTIAL_WITH: FEAT-XXX-001"]*

---

#### A2.5 Quality Requirements (AUTO-GENERATED — không sửa tay)

> Các checklist dưới đây được tự động sinh bởi wf-plan-modules dựa trên module type,
> interface type, và tech stack. Agent wf-implement-feature PHẢI verify từng mục.

##### Security Checklist

- [ ] **AUTH-01:** JWT expiry ≤ 1h, refresh token rotation có sẵn
- [ ] **AUTH-02:** Không hardcoded secrets/fallback values trong source
- [ ] **INPUT-01:** Tất cả user input được validate (type, length, format)
- [ ] **SQL-01:** Tất cả SQL queries dùng parameterized statements (không string concat)
- [ ] **XSS-01:** User-generated content được sanitize trước khi render
- [ ] **CORS-01:** CORS origin configurable qua environment variable
- [ ] **RATE-01:** Rate limiting trên auth endpoints (login, forgot-password, verify-otp)

##### Data Integrity Checklist

- [ ] **VALID-01:** NOT NULL columns được validate trước INSERT/UPDATE
- [ ] **FK-01:** Foreign key constraints enabled (PRAGMA foreign_keys = ON)
- [ ] **CONS-01:** Constants (exchange rates, tax rates, tiers) có single source of truth
- [ ] **ENV-01:** API response format nhất quán `{success, data, error}`

##### i18n Checklist _(conditional: chỉ khi interface_type != "api-only")_

- [ ] **I18N-01:** Tất cả user-facing strings qua `t()` function
- [ ] **I18N-02:** Placeholder, aria-label, alt text được translate
- [ ] **I18N-03:** Number/date formats theo locale (không hardcode định dạng)

##### Accessibility Checklist _(conditional: chỉ khi interface_type != "api-only")_

- [ ] **A11Y-01:** Label có `htmlFor` match với input `id`
- [ ] **A11Y-02:** Images có descriptive alt text (không "Product", "Avatar")
- [ ] **A11Y-03:** Modal/Drawer có focus trap + Escape to close
- [ ] **A11Y-04:** Error/success feedback dùng Toast component (không `alert()`)
- [ ] **A11Y-05:** Color không phải là chỉ báo duy nhất (thêm icon/text)

##### Performance Checklist _(conditional: chỉ khi interface_type != "api-only")_

- [ ] **PERF-01:** Large components dùng React.lazy() code splitting
- [ ] **PERF-02:** Expensive computations dùng useMemo / useCallback
- [ ] **PERF-03:** Images dùng lazy loading (`loading="lazy"`)

---

#### A2.6 Environment Notes (AUTO-GENERATED)

| Aspect | Rule | Reason |
|--------|------|--------|
| Build tool | *[detected]* | *[specific rules]* |
| Env vars client | *[prefix pattern]* | *[security note]* |
| Env vars server | *[validation rule]* | *[fallback rule]* |
| Framework | *[React/Vue/etc]* | *[specific rules]* |
| CSS | *[Tailwind/CSS Modules/etc]* | *[optimization note]* |

---

### A3. Design Reference

> *(Optional nếu interface_type = api-only — bỏ qua UX references nếu không có UI)*

| Document | Path |
|----------|------|
| Feature Design | `phase2-features/[sys]/[mod]/[feat].md` |
| UX Design | `phase4-ux/[sys]/[mod]/[screen-group].md` |
| API Contract | `phase3-architecture/technical-specs/api-contract.md` |
| Database Design | `phase3-architecture/technical-specs/database-design.md` |

---

### A4. AC → REQ-ID Traceability Matrix

> *Điền matrix này TRƯỚC khi implement. Mỗi AC phải có REQ-ID tương ứng.*

| Acceptance Criteria | REQ-ID | Test ID | Story |
|---------------------|--------|---------|-------|
| [AC từ STORY-001] | REQ-[DEPT]-[NNN] | TC-001 | STORY-001 |
| [AC từ STORY-002] | REQ-[DEPT]-[NNN] | TC-002 | STORY-001 |

---

### A5. Story Breakdown

> **Naming:** `STORY-NNN` — số thứ tự tăng dần per feature, bắt đầu từ 001 (VD: STORY-001, STORY-002 trong FEAT-CRM-CUST-001). Không dùng ID toàn cục.

#### STORY-001: *[User Story Title]*

**As a** *[loại user]*
**I want to** *[hành động]*
**So that** *[lợi ích]*

**Acceptance Criteria:**
- [ ] *[AC 1]*
- [ ] *[AC 2]*
- [ ] *[AC 3]*

**Tasks:**

| Task ID | Description | File Path | Type | Est. Tokens | Status |
|---------|-------------|-----------|------|-------------|--------|
| T001 | *[Mô tả task]* | `src/.../Entity.ts` | entity | 500 | pending |
| T002 | *[Mô tả task]* | `src/.../Repository.ts` | repository | 800 | pending |
| T003 | *[Mô tả task]* | `src/.../Service.ts` | service | 1500 | pending |
| T004 | *[Mô tả task]* | `src/.../Controller.ts` | controller | 1000 | pending |
| T005 | *[Mô tả task]* | `tests/.../test.ts` | test | 1200 | pending |

**Context Budget:** ~5000 tokens
**Recommended Batch:** T001-T002, T003-T004, T005

---

#### STORY-002: *[User Story Title]*

**As a** *[loại user]*
**I want to** *[hành động]*
**So that** *[lợi ích]*

**Acceptance Criteria:**
- [ ] *[AC 1]*
- [ ] *[AC 2]*

**Tasks:**

| Task ID | Description | File Path | Type | Est. Tokens | Status |
|---------|-------------|-----------|------|-------------|--------|
| T006 | *[Mô tả task]* | `src/...` | *[type]* | *[tokens]* | pending |
| T007 | *[Mô tả task]* | `src/...` | *[type]* | *[tokens]* | pending |

---

#### STORY-003: *[User Story Title]*

...

---

### A6. Task Details

#### T001: *[Task Title]*

| Field | Value |
|-------|-------|
| **Type** | entity / repository / service / controller / component / hook / test |
| **File** | `src/modules/[module]/entities/[Entity].ts` |
| **Description** | *[Mô tả chi tiết]* |
| **REQ-ID** | REQ-XXX-001 |
| **Dependencies** | None / T00X |

**Implementation Notes:**
```
*[Ghi chú hướng dẫn implementation]*
- Fields cần có
- Validation rules
- Business logic
```

**Verify Command:**
```bash
*[Command để verify task hoàn thành]*
```

---

#### T002: *[Task Title]*

...

---

### A6-EXT. Executable Implementation Specification

> **NEW (Phiên 7):** Tài liệu này chứa blueprint chi tiết để developer agent lập trình KHÔNG CẦN đọc Phase 1-3 docs.
> Mỗi file, method, field được mô tả đầy đủ với logic, test cases, và dependencies rõ ràng.
> **Backward compatible:** Task files cũ không có A6-EXT → wf-implement-feature đọc A1-A6 như cũ.

#### A6-EXT Overview

Executable specification được sinh bởi architect agent (wf-plan-modules Phase 7.5) và serve như "source of truth" cho developer implementation. Mỗi file spec bao gồm:

- **File path & REQ-IDs:** Rõ ràng file nào map tới REQ-ID nào
- **Loại file:** Entity, Service, Controller, DTO, Test, etc.
- **Imports & Dependencies:** Danh sách modules cần import, interfaces phụ thuộc
- **Detailed Methods/Fields:** Signature đầy đủ, logic step-by-step, error handling
- **Test Cases:** Happy path, error cases, edge cases với expected behavior rõ ràng

---

#### A6-EXT.1. File Specification Template

```markdown
### File [N]: [file-path]

**REQ-IDs:** [list of REQ-ID mapping]
**Loại:** Entity / Service / Repository / Controller / DTO / Test / Component
**Mục đích:** *[Mô tả ngắn]* *[Ví dụ: "Định nghĩa Customer entity với soft-delete và audit trail"]*

---

#### Imports & Dependencies

| Import | Từ | Loại | Ghi chú |
|--------|-----|------|---------|
| `CustomerEntity` | `./customer.entity` | Custom class | Core entity |
| `ICustomerRepository` | `./repositories` | Interface | Dependency injection |
| `TypeORM` | `typeorm` | External | ORM framework |

---

#### Fields / Columns (Nếu Entity)

| Tên | Loại | Constraints | Decorators / Validation | Ghi chú |
|-----|------|-------------|------------------------|---------|
| `id` | `uuid` | PK, auto-generated | `@PrimaryGeneratedColumn('uuid')` | Unique identifier |
| `name` | `varchar(255)` | NOT NULL | `@Column({ length: 255 })` `@IsNotEmpty()` | Customer full name |
| `email` | `varchar(255)` | NOT NULL, UNIQUE | `@Column({ unique: true })` `@IsEmail()` | Business email |
| `deletedAt` | `timestamp` | nullable | `@Column({ nullable: true })` | Soft-delete marker |
| `createdAt` | `timestamp` | auto | `@CreateDateColumn()` | Auto-set on insert |
| `updatedAt` | `timestamp` | auto | `@UpdateDateColumn()` | Auto-set on update |

---

#### Relations (Nếu Entity)

| Relationship | Target Entity | Cardinality | Decorator | Ghi chú |
|--------------|---------------|-------------|-----------|---------|
| `orders` | `OrderEntity` | OneToMany | `@OneToMany(() => OrderEntity, order => order.customer)` | Customer có nhiều orders |
| `group` | `CustomerGroupEntity` | ManyToOne | `@ManyToOne(() => CustomerGroupEntity)` | Tham chiếu group |

---

#### Methods (Nếu Service / Repository / Controller)

##### Method 1: `[methodName]([params]): [ReturnType]`

**Signature:**
```typescript
[visibility] [methodName]([param1]: [Type1], [param2]: [Type2]): [ReturnType]
```

**Purpose:** *[Mục đích method]*

**Logic:**
```
1. [Step 1: mô tả rõ ràng]
2. [Step 2]
3. [Step N: return statement]
```

**Error Handling:**
```
- [Error scenario 1] → throw AppError('[CODE]', [status-code])
  Ví dụ: Email duplicate → throw AppError('CUSTOMER_EMAIL_EXISTS', 409)
- [Error scenario 2] → throw AppError('[CODE]', [status-code])
```

**Dependencies (từ imports):**
- `ICustomerRepository.findByEmail()`
- `ICustomerRepository.save()`

**Test Cases:**
| ID | Scenario | Input | Expected Output | Type |
|-----|----------|-------|-----------------|------|
| TC-001 | Happy path | Valid customer data | Customer saved & returned | ✅ Pass |
| TC-002 | Duplicate email | Email exists in DB | `AppError CUSTOMER_EMAIL_EXISTS 409` | ❌ Error |
| TC-003 | Missing fields | Partial customer data | Validation error | ❌ Error |
| TC-004 | Soft-deleted lookup | ID of soft-deleted customer | `AppError CUSTOMER_NOT_FOUND 404` | ❌ Edge case |

---

##### Method 2: `[methodName2]([params]): [ReturnType]`

*[Repeat structure above]*

---

#### DTOs / Input Models

| DTO | Fields | Validation | Notes |
|-----|--------|------------|-------|
| `CreateCustomerDTO` | `name`, `email`, `phone` | `@IsNotEmpty()`, `@IsEmail()` | Used in POST endpoint |
| `UpdateCustomerDTO` | `name`, `email`, `phone` | All optional `@IsOptional()` | Used in PATCH endpoint |
| `CustomerResponseDTO` | `id`, `name`, `email`, `createdAt` | None (output) | Safe for API response |

---

#### API Endpoints (Nếu Controller)

| Endpoint | Method | Input | Output | Status | Error Cases |
|----------|--------|-------|--------|--------|-------------|
| `/customers` | POST | `CreateCustomerDTO` | `CustomerResponseDTO` | 201 | 400 (validation), 409 (duplicate email) |
| `/customers/{id}` | GET | Path param: `id` | `CustomerResponseDTO` | 200 | 404 (not found) |
| `/customers/{id}` | PATCH | `UpdateCustomerDTO` | `CustomerResponseDTO` | 200 | 404, 409 (duplicate) |
| `/customers/{id}` | DELETE | Path param: `id` | `{ deleted: true }` | 204 | 404 |

---
```

---

#### A6-EXT.2. Example: Customer CRUD Feature

> Ví dụ đầy đủ cho feature giả lập "Customer Management"

```markdown
### File 1: src/modules/crm/entities/customer.entity.ts

**REQ-IDs:** REQ-SALES-001, REQ-SALES-003
**Loại:** Entity (TypeORM)
**Mục đích:** Định nghĩa Customer entity với soft-delete và audit trail

---

**Imports & Dependencies:**

| Import | Từ | Loại |
|--------|-----|------|
| `Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany, ManyToOne` | `typeorm` | External |
| `OrderEntity` | `../orders/order.entity` | Custom |
| `CustomerGroupEntity` | `../groups/group.entity` | Custom |

---

**Fields / Columns:**

| Tên | Loại | Constraints | Decorators | Ghi chú |
|-----|------|-------------|-----------|---------|
| `id` | `uuid` | PK, auto-generated | `@PrimaryGeneratedColumn('uuid')` | Unique identifier |
| `name` | `varchar(255)` | NOT NULL | `@Column({ length: 255 })` | Full name |
| `email` | `varchar(255)` | NOT NULL, UNIQUE | `@Column({ unique: true })` | Business email, indexed |
| `phone` | `varchar(20)` | nullable | `@Column({ nullable: true })` | Contact phone |
| `deletedAt` | `timestamp` | nullable | `@Column({ nullable: true })` | Soft-delete flag |
| `createdAt` | `timestamp` | auto | `@CreateDateColumn()` | Auto on insert |
| `updatedAt` | `timestamp` | auto | `@UpdateDateColumn()` | Auto on update |

---

**Relations:**

| Relationship | Target | Cardinality | Decorator |
|--------------|--------|-------------|-----------|
| `orders` | `OrderEntity` | OneToMany | `@OneToMany(() => OrderEntity, order => order.customer)` |
| `group` | `CustomerGroupEntity` | ManyToOne | `@ManyToOne(() => CustomerGroupEntity, group => group.customers)` |

---

### File 2: src/modules/crm/services/customer.service.ts

**REQ-IDs:** REQ-SALES-001, REQ-SALES-002, REQ-SALES-003
**Loại:** Service
**Mục đích:** Xử lý business logic cho customer (CRUD + soft-delete)

---

**Imports & Dependencies:**

| Import | Từ | Loại |
|--------|-----|------|
| `Injectable` | `@nestjs/common` | External |
| `InjectRepository` | `@nestjs/typeorm` | External |
| `Repository` | `typeorm` | External |
| `CustomerEntity` | `../entities/customer.entity` | Custom |
| `ICustomerRepository` | `../repositories/customer.repository.interface` | Interface |
| `CreateCustomerDTO, UpdateCustomerDTO` | `../dtos` | Custom |
| `AppError` | `@shared/errors` | Shared |

---

**Methods:**

##### `create(dto: CreateCustomerDTO): Promise<CustomerEntity>`

**Purpose:** Tạo customer mới với validation unique email

**Logic:**
```
1. Gọi repository.findByEmail(dto.email)
2. Nếu kết quả không null → throw AppError('CUSTOMER_EMAIL_EXISTS', 409)
3. Tạo entity mới: const customer = repository.create(dto)
4. Lưu vào DB: return repository.save(customer)
```

**Error Handling:**
- Email already exists → throw AppError('CUSTOMER_EMAIL_EXISTS', 409)
- Repository save error → propagate (handled by error middleware)

**Dependencies:**
- `ICustomerRepository.findByEmail()`
- `ICustomerRepository.create()`
- `ICustomerRepository.save()`

**Test Cases:**
| ID | Scenario | Input | Expected | Type |
|----|----------|-------|----------|------|
| TC-001 | Create success | `{ name: 'John', email: 'john@example.com' }` | Returns CustomerEntity with id | ✅ |
| TC-002 | Duplicate email | `{ name: 'Jane', email: 'john@example.com' }` | AppError 409 | ❌ |
| TC-003 | Missing name | `{ email: 'jane@example.com' }` | Validation error (DTO) | ❌ |

---

##### `findById(id: string): Promise<CustomerEntity>`

**Purpose:** Tìm customer theo ID, exclude soft-deleted

**Logic:**
```
1. Gọi repository.findOne({ where: { id, deletedAt: IsNull() } })
2. Nếu kết quả null → throw AppError('CUSTOMER_NOT_FOUND', 404)
3. Return customer entity
```

**Error Handling:**
- Customer not found → throw AppError('CUSTOMER_NOT_FOUND', 404)
- Soft-deleted customer → treat as not found (đã xử lý ở step 1)

**Test Cases:**
| ID | Scenario | Input | Expected | Type |
|----|----------|-------|----------|------|
| TC-004 | Find active | Valid active customer id | Returns CustomerEntity | ✅ |
| TC-005 | Not found | Non-existent id | AppError 404 | ❌ |
| TC-006 | Soft-deleted | Soft-deleted customer id | AppError 404 (treats as not found) | ❌ Edge |

---

##### `softDelete(id: string): Promise<void>`

**Purpose:** Soft-delete customer (set deletedAt)

**Logic:**
```
1. Gọi this.findById(id) — đảm bảo customer tồn tại
2. Set customer.deletedAt = new Date()
3. Gọi repository.save(customer)
```

**Error Handling:**
- Customer not found → throw AppError('CUSTOMER_NOT_FOUND', 404) (from findById)

**Test Cases:**
| ID | Scenario | Input | Expected | Type |
|----|----------|-------|----------|------|
| TC-007 | Soft-delete success | Valid customer id | deletedAt set, customer saved | ✅ |
| TC-008 | Not found | Non-existent id | AppError 404 | ❌ |

---

### File 3: src/modules/crm/repositories/customer.repository.ts

**REQ-IDs:** REQ-SALES-001
**Loại:** Repository
**Mục đích:** Data access layer cho Customer entity

---

**Methods:**

##### `findByEmail(email: string): Promise<CustomerEntity | null>`

**Purpose:** Tìm customer theo email (include soft-deleted)

**Logic:**
```
1. return this.find({ where: { email } })
```

**Note:** Includes soft-deleted để service layer có thể detect duplicate email (business rule)

---

### File 4: tests/modules/crm/services/customer.service.spec.ts

**REQ-IDs:** REQ-SALES-001, REQ-SALES-002, REQ-SALES-003
**Loại:** Test (Unit tests)
**Mục đích:** Unit test cho CustomerService với mocked repository

---

**Test Setup:**

```typescript
// Mock ICustomerRepository
// Create service with mocked repo
// Mocking strategy: jest.fn() cho mỗi method
```

**Test Cases:**

| Test | Happy Path / Error | Assertion |
|------|-------------------|-----------|
| `create() success` | ✅ | savedEntity returned |
| `create() duplicate email` | ❌ | AppError 409 thrown |
| `findById() success` | ✅ | Entity returned |
| `findById() not found` | ❌ | AppError 404 thrown |
| `softDelete() success` | ✅ | deletedAt set |
| `softDelete() not found` | ❌ | AppError 404 thrown |

---
```

---

#### A6-EXT.3. Verification Checklist

Trước khi developer agent bắt đầu code:

- [ ] A6-EXT section đầy đủ (files, methods, test cases)
- [ ] Tất cả methods có test cases (happy path + error cases)
- [ ] Dependencies rõ ràng (imports, interfaces)
- [ ] Error codes consistent với project conventions
- [ ] Database constraints/decorators chính xác
- [ ] API responses defined (DTOs)

---

---

### A7-EXT. Micro-Task Breakdown

> **NEW (Phiên 8):** Nếu feature có ≥ 3 files hoặc estimated time > 15 phút → chia thành micro-tasks.
> Mỗi micro-task ≤ 15 phút, self-contained, có dependency graph rõ ràng.
> **Khi dùng:** Chạy `/wf-implement-feature [feat] --micro-task=MT-[FEAT]-[NNN]`
> **Backward compatible:** Feature nhỏ (< 3 files) không cần A7-EXT — cứ implement như cũ.

#### A7-EXT Overview

Micro-task decomposition được sinh bởi architect agent (wf-plan-modules Phase 7.5) dựa trên A6-EXT.
Mỗi micro-task là một đơn vị implement độc lập, verifiable, ≤ 15 phút.

**Cấu trúc micro-task:**
- **micro_task_id:** MT-[FEAT]-[NNN] (ví dụ: MT-CUST-001)
- **name:** Tên ngắn (ví dụ: "Entity + Migration")
- **estimated_time:** ≤ 15 phút
- **input:** Danh sách files/specs cần đọc (cụ thể section)
- **output:** Files cần tạo/sửa
- **success_criteria:** Kiểm tra hoàn thành (compile, test, types)
- **dependencies:** MT nào phải hoàn thành trước
- **context_from_previous:** Info cần từ MT trước (types, interfaces)

---

#### A7-EXT.1. Micro-Task Specification Template

```markdown
### Micro-Task: [MT-FEAT-NNN] — [Name]

**Metadata:**

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-[FEAT]-[NNN] |
| Feature ID | FEAT-[SYS]-[MOD]-[NNN] |
| Name | *[Ngắn gọn, ví dụ: Entity + Migration]* |
| Estimated Time | N min (max 15) |
| Category | entity / repository / service / controller / dto / test / component |
| Complexity | simple / medium / complex |

---

**Input Files (Cụ thể section):**

| File | Section | Purpose |
|------|---------|---------|
| `phase2-features/...` | `## Features` | Entity definition |
| `phase3-architecture/...` | `## Table: Customer` | Constraints, relationships |
| `phase3-architecture/api-contract.md` | `POST /customers` | API spec (nếu controller) |

---

**Output Files:**

| File | Type | Purpose |
|------|------|---------|
| `src/modules/.../entity.ts` | Entity | Định nghĩa entity |
| `src/database/migrations/NNN-*.ts` | Migration | DB migration script |

---

**Dependencies:**

- Phụ thuộc: None (MT đầu tiên) / MT-FEAT-001, MT-FEAT-002
- Blocks: MT-FEAT-002 (MT này phải xong trước MT-FEAT-002)
- Context từ MT trước: None / [Kiểu dữ liệu, interfaces từ MT trước]

---

**Context from Previous Micro-Task:**

Nếu phụ thuộc MT trước, liệt kê rõ:
```
From MT-CUST-001:
  - Type: CustomerEntity (file: src/modules/crm/entities/customer.entity.ts)
  - Import: import { CustomerEntity } from '../entities/customer.entity'
  - Key exports: Entity class, column definitions
```

---

**Success Criteria (Verify):**

- [ ] `compile`: TypeScript compiles without errors → `tsc --noEmit`
- [ ] `entity`: Tất cả fields từ A6-EXT được define
- [ ] `types`: Exported types khớp A6-EXT specification
- [ ] `naming`: Kebab-case file names, PascalCase classes
- [ ] `tests`: SKIP nếu entity-only MT (viết test ở MT riêng)
- [ ] `linting`: No linting errors → `npm run lint`

---

**Implementation Notes:**

```
- [Chi tiết triển khai nếu cần]
- Fields cần có: [...]
- Validation rules: [...]
- Dependencies: [...]
```

---

**Verify Command:**

```bash
# Ví dụ
tsc --noEmit && test -s src/modules/crm/entities/customer.entity.ts
```

---
```

---

#### A7-EXT.2. Example: Customer CRUD Micro-Tasks

```markdown
### Micro-Task: MT-CUST-001 — Entity + Migration

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-CUST-001 |
| Estimated Time | 10 min |
| Category | entity |
| Complexity | simple |

**Input Files:**
- `phase2-features/crm/customer/customer-crud.md` → Section `## Features`
- `phase3-architecture/technical-specs/database-design.md` → Section `## Table: Customer`

**Output Files:**
- `src/modules/crm/entities/customer.entity.ts`
- `src/database/migrations/001-create-customers-table.ts`

**Dependencies:** None

**Success Criteria:**
- [ ] TypeScript: `tsc --noEmit` PASS
- [ ] Entity: CustomerEntity class defined với id, name, email, phone, deletedAt, createdAt, updatedAt
- [ ] Migration: Migration file executable
- [ ] Naming: Kebab-case file names

---

### Micro-Task: MT-CUST-002 — Repository + Interface

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-CUST-002 |
| Estimated Time | 8 min |
| Category | repository |
| Complexity | simple |

**Input Files:**
- `phase3-architecture/technical-specs/database-design.md` → Section `## Table: Customer`

**Output Files:**
- `src/modules/crm/repositories/customer.repository.interface.ts`
- `src/modules/crm/repositories/customer.repository.ts`

**Dependencies:** MT-CUST-001

**Context from Previous:**
```
From MT-CUST-001:
  - Type: CustomerEntity
  - File: src/modules/crm/entities/customer.entity.ts
  - Import: import { CustomerEntity } from '../entities/customer.entity'
```

**Success Criteria:**
- [ ] TypeScript: `tsc --noEmit` PASS
- [ ] Interface: ICustomerRepository defined với findById, findByEmail, create, save, softDelete
- [ ] Implementation: CustomerRepository implements interface
- [ ] Methods: Tất cả methods từ A6-EXT được implement

---

### Micro-Task: MT-CUST-003 — Service Layer

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-CUST-003 |
| Estimated Time | 12 min |
| Category | service |
| Complexity | medium |

**Input Files:**
- `phase2-features/crm/customer/customer-crud.md` → Section `## Acceptance Criteria`
- `phase3-architecture/api-contract.md` → Section `## /customers endpoints`

**Output Files:**
- `src/modules/crm/services/customer.service.ts`
- `src/modules/crm/dtos/create-customer.dto.ts`
- `src/modules/crm/dtos/update-customer.dto.ts`

**Dependencies:** MT-CUST-002

**Context from Previous:**
```
From MT-CUST-002:
  - Interface: ICustomerRepository
  - File: src/modules/crm/repositories/customer.repository.interface.ts
  - Key methods: findById, findByEmail, create, save, softDelete
```

**Success Criteria:**
- [ ] TypeScript: `tsc --noEmit` PASS
- [ ] Service: CustomerService injected with ICustomerRepository
- [ ] DTOs: CreateCustomerDTO, UpdateCustomerDTO defined với validation decorators
- [ ] Methods: create, findById, softDelete implemented theo A6-EXT

---

### Micro-Task: MT-CUST-004 — API Controller

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-CUST-004 |
| Estimated Time | 10 min |
| Category | controller |
| Complexity | medium |

**Input Files:**
- `phase3-architecture/api-contract.md` → Section `## /customers endpoints`

**Output Files:**
- `src/modules/crm/controllers/customer.controller.ts`
- `src/modules/crm/routes/customer.routes.ts`

**Dependencies:** MT-CUST-003

**Context from Previous:**
```
From MT-CUST-003:
  - Service: CustomerService
  - DTOs: CreateCustomerDTO, UpdateCustomerDTO
```

**Success Criteria:**
- [ ] TypeScript: `tsc --noEmit` PASS
- [ ] Controller: Methods POST /customers, GET /customers/:id, PATCH /customers/:id, DELETE /customers/:id
- [ ] Validation: DTOs validated ở controller
- [ ] Error handling: AppError thrown correctly

---

### Micro-Task: MT-CUST-005 — Integration Test

| Field | Value |
|-------|-------|
| Micro-Task ID | MT-CUST-005 |
| Estimated Time | 10 min |
| Category | test |
| Complexity | medium |

**Input Files:**
- A6-EXT test cases từ MT-CUST-003 (service test cases)

**Output Files:**
- `tests/modules/crm/customer.integration.test.ts`

**Dependencies:** MT-CUST-004

**Success Criteria:**
- [ ] All integration tests PASS
- [ ] Coverage ≥ 80%
- [ ] No linting errors
- [ ] E2E happy path + error cases covered
```

---

#### A7-EXT.3. Micro-Task Dependency Graph

Visualize dependencies:

```
┌─────────────────────────────────────┐
│ MT-CUST-001: Entity + Migration    │
│ (10 min, simple)                    │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ MT-CUST-002: Repository + Interface │
│ (8 min, simple)                     │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ MT-CUST-003: Service Layer          │
│ (12 min, medium)                    │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ MT-CUST-004: API Controller         │
│ (10 min, medium)                    │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ MT-CUST-005: Integration Test       │
│ (10 min, medium)                    │
└─────────────────────────────────────┘
```

**Sequential:** Mỗi MT phụ thuộc MT trước, phải chạy lần lượt.
**Total Time:** 10 + 8 + 12 + 10 + 10 = 50 min (nếu chạy liên tục)
**Nếu parallel (future):** Chỉ chạy MT-001 trước, rồi 002-005 có thể song song → ~12 min

---

#### A7-EXT.4. Verification Checklist

Trước developer agent bắt đầu:

- [ ] Tất cả micro-tasks listed (MT-[FEAT]-001 → MT-[FEAT]-NNN)
- [ ] Mỗi MT: estimated_time ≤ 15 min
- [ ] Mỗi MT: ≤ 3 output files
- [ ] Dependencies acyclic (không circular)
- [ ] Success criteria testable (cụ thể, verifiable)
- [ ] Context from previous rõ ràng (types, file paths)
- [ ] Total time ≤ 60 min (nếu sequential)

---

### A7. Execution Strategy

#### A6.1 Execution Mode

| Story | Mode | Rationale |
|-------|------|-----------|
| STORY-001 | Sequential (TDD) | Test-driven development required |
| STORY-002 | Parallel | Independent tasks |
| STORY-003 | Sequential | Dependencies between tasks |

#### A6.2 Batch Recommendations

| Batch | Tasks | Est. Context | When to Execute |
|-------|-------|--------------|-----------------|
| Batch 1 | T001, T002 | ~1300 tokens | Start of feature |
| Batch 2 | T003, T004 | ~2500 tokens | After Batch 1 done |
| Batch 3 | T005 | ~1200 tokens | After Batch 2 done |
| Batch 4 | T006, T007 | ~2000 tokens | STORY-002 parallel |

#### A6.3 Context Management

**Total Estimated Context:** ~10,000 tokens

**Checkpoint Points:**
- [ ] After STORY-001 complete
- [ ] After STORY-002 complete
- [ ] Before tests

---

### A8. Testing Strategy

#### A7.1 Unit Tests

| File | Coverage Target | Focus |
|------|-----------------|-------|
| `tests/.../Service.test.ts` | 80%+ | Business logic |
| `tests/.../Controller.test.ts` | 80%+ | API responses |
| `tests/.../Repository.test.ts` | 70%+ | DB operations |

#### A7.2 Integration Tests

| Scenario | Priority |
|----------|----------|
| *[Scenario 1]* | High |
| *[Scenario 2]* | Medium |

#### A7.3 E2E Tests (if applicable)

| Flow | Priority |
|------|----------|
| *[User flow 1]* | High |

---

### A9. Acceptance Checklist

#### Pre-Implementation
- [ ] Design document reviewed
- [ ] Dependencies confirmed available
- [ ] Development environment ready

#### Per-Story
- [ ] All tasks completed
- [ ] Tests written and passing
- [ ] REQ-ID added to all files
- [ ] Code follows `.claude/rules/`

#### Post-Implementation
- [ ] All stories completed
- [ ] Unit tests coverage >=80%
- [ ] Integration tests passing
- [ ] Code review completed
- [ ] Security review completed
- [ ] No hardcoded secrets
- [ ] No placeholder values
- [ ] Documentation updated

---

### A10. Status Summary

| Metric | Count |
|--------|-------|
| **Total Stories** | X |
| Completed | 0 |
| In Progress | 0 |
| Not Started | X |
| **Total Tasks** | X |
| Completed | 0 |
| In Progress | 0 |
| Not Started | X |

**Progress:** 0%

---

### A11. Execution Log

> Cập nhật trong quá trình implementation

| Date | Session | Tasks | Status | Notes |
|------|---------|-------|--------|-------|
| *[Date]* | 1 | T001-T003 | in_progress | *[Checkpoint notes]* |

---

## Phần B: Task Breakdown

### B1. Quick Status

| Metric | Status |
|--------|--------|
| **Feature ID** | FEAT-[SYS]-[MOD]-NNN |
| **Total Tasks** | X |
| Completed | 0 |
| In Progress | 0 |
| Not Started | X |
| **Progress** | 0% |

---

### B2. Session Log

#### Session 1: *[Date]*

**Goal:** *[Mục tiêu session]*

**Context Budget:**
- Start: 0 / 200,000 tokens
- Planned: ~5,000 tokens
- Actual: *[X]* tokens

| Task | Type | Status | Time | Notes |
|------|------|--------|------|-------|
| T001 | entity | pending | - | - |
| T002 | repository | pending | - | - |
| T003 | service | pending | - | - |

**Completed this session:**
- *[Task IDs completed]*

**Checkpoint:**
```
*[Ghi chú checkpoint - file nào đang làm, line nào pause, context còn bao nhiêu]*
```

**Next Session:**
- Resume from: *[Task ID]*
- First action: *[Hành động tiếp theo]*

---

#### Session 2: *[Date]*

**Goal:** *[Mục tiêu session]*

**Context Budget:**
- Start: *[X]* tokens (resumed)
- Planned: ~5,000 tokens
- Actual: *[X]* tokens

| Task | Type | Status | Time | Notes |
|------|------|--------|------|-------|
| T003 | service | done | 15min | Completed service layer |
| T004 | controller | done | 10min | Simple CRUD endpoints |
| T005 | test | in_progress | - | Paused at test case 3 |

**Completed this session:**
- T003, T004

**Checkpoint:**
```
T005 paused at test case 3 - need to add edge case for null values
File: tests/modules/.../Service.test.ts
Line: 45
```

**Next Session:**
- Resume from: T005
- First action: Complete edge case tests

---

### B3. Detailed Task Checklist

#### STORY-001: *[Story Title]*

##### T001: *[Task Title]*
- **File:** `src/.../Entity.ts`
- **Type:** entity
- **Status:** not_started / in_progress / done / blocked

**Subtasks:**
- [ ] Create entity class
- [ ] Add required fields
- [ ] Add validation decorators
- [ ] Add REQ-ID comment

**Verify:**
```bash
# Command to verify
test -s src/.../Entity.ts && grep -q "REQ-ID:" src/.../Entity.ts
```

**Notes:**
```
*[Implementation notes]*
```

---

##### T002: *[Task Title]*
- **File:** `src/.../Repository.ts`
- **Type:** repository
- **Status:** not_started

**Subtasks:**
- [ ] Create repository class
- [ ] Implement findById
- [ ] Implement findAll with pagination
- [ ] Implement create
- [ ] Implement update
- [ ] Implement soft delete
- [ ] Add REQ-ID comment

**Verify:**
```bash
test -s src/.../Repository.ts && grep -q "REQ-ID:" src/.../Repository.ts
```

---

##### T003: *[Task Title]*
- **File:** `src/.../Service.ts`
- **Type:** service
- **Status:** not_started

**Subtasks:**
- [ ] Create service class with DI
- [ ] Implement business logic methods
- [ ] Add error handling
- [ ] Add logging
- [ ] Add REQ-ID comment

---

##### T004: *[Task Title]*
- **File:** `src/.../Controller.ts`
- **Type:** controller
- **Status:** not_started

**Subtasks:**
- [ ] Create controller class
- [ ] Implement GET endpoint
- [ ] Implement POST endpoint
- [ ] Implement PUT endpoint
- [ ] Implement DELETE endpoint
- [ ] Add validation
- [ ] Add REQ-ID comment

---

##### T005: *[Task Title]*
- **File:** `tests/.../Service.test.ts`
- **Type:** test
- **Status:** not_started

**Subtasks:**
- [ ] Setup test file with mocks
- [ ] Test happy path
- [ ] Test validation errors
- [ ] Test edge cases
- [ ] Test error handling
- [ ] Verify 80%+ coverage

**Verify:**
```bash
npm test -- --coverage tests/.../Service.test.ts
```

---

#### STORY-002: *[Story Title]*

##### T006: *[Task Title]*
...

---

### B4. TDD Cycle Log

#### T001-T002: Entity & Repository

**RED Phase:**
- [ ] Write test for entity creation
- [ ] Write test for repository CRUD
- [ ] Run tests - MUST FAIL

**GREEN Phase:**
- [ ] Implement entity
- [ ] Implement repository
- [ ] Run tests - MUST PASS

**REFACTOR Phase:**
- [ ] Clean up code
- [ ] Add REQ-ID comments
- [ ] Run tests - MUST PASS

---

#### T003-T004: Service & Controller

**RED Phase:**
- [ ] Write test for service methods
- [ ] Write test for controller endpoints
- [ ] Run tests - MUST FAIL

**GREEN Phase:**
- [ ] Implement service
- [ ] Implement controller
- [ ] Run tests - MUST PASS

**REFACTOR Phase:**
- [ ] Clean up code
- [ ] Add REQ-ID comments
- [ ] Run tests - MUST PASS

---

### B5. Quality Gates

#### Pre-Implementation Gate
- [ ] Feature plan reviewed
- [ ] Design document accessible
- [ ] Dependencies available
- [ ] Environment ready

#### Per-Task Gate
- [ ] Task file created
- [ ] File non-empty
- [ ] REQ-ID present
- [ ] Tests pass (if applicable)

#### Post-Story Gate
- [ ] All story tasks complete
- [ ] Tests passing
- [ ] Coverage >=80%
- [ ] No placeholders

#### Post-Feature Gate
- [ ] All stories complete
- [ ] All tests passing
- [ ] Code review done
- [ ] Security review done
- [ ] Registry updated

---

### B6. Blockers & Issues

| ID | Task | Issue | Resolution | Status |
|----|------|-------|------------|--------|
| B001 | T003 | *[Mô tả vấn đề]* | *[Cách giải quyết]* | open / resolved |

---

### B7. Context Management

#### Token Budget Tracking

| Session | Start | Used | Remaining | % |
|---------|-------|------|-----------|---|
| 1 | 0 | 5,000 | 195,000 | 2.5% |
| 2 | 5,000 | 4,000 | 191,000 | 4.5% |
| ... | ... | ... | ... | ... |

**Warning Threshold:** 80% (160,000 tokens used)
**Stop Threshold:** 90% (180,000 tokens used)

#### Checkpoint Protocol

When context reaches **80%** or need to pause:

1. **Update this file** with current status
2. **Create checkpoint entry:**
   ```
   CHECKPOINT [Date Time]
   - Last completed task: T00X
   - Current task: T00Y (progress: X%)
   - File: [path], Line: [N]
   - Next action: [what to do next]
   - Context remaining: [X] tokens
   ```
3. **Commit changes** (if applicable)
4. **Notify user:** "Context approaching limit. Checkpoint saved. Resume with `/implement-feature [feature] --resume`"

---

### B8. Resume Instructions

When resuming this feature:

```bash
# 1. Read this file first
# 2. Find last checkpoint
# 3. Review "Next Session" in last session log
# 4. Continue from marked task
# 5. Update status as you progress
```

**Last Checkpoint:**
```
*[Last checkpoint entry or "No checkpoints yet"]*
```
