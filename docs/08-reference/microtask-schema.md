# Micro-Task Schema Specification

> **Phiên 8 — Master Optimization Plan Section 4.4**
> Định nghĩa cấu trúc chi tiết cho micro-task decomposition

**Ngày tạo:** 2026-04-04
**Phiên bản:** 1.0.0

---

## 1. Micro-Task Definition

Mỗi micro-task là một đơn vị implement **độc lập, verifiable, < 15 phút** thuộc một feature lớn hơn.

### 1.1 Micro-Task ID Format

```
MT-[FEAT-PREFIX]-[NNN]
```

**Thành phần:**
- `MT` — Tiền tố "Micro-Task"
- `[FEAT-PREFIX]` — 3 ký tự từ feature ID (ví dụ: `CUST` từ `FEAT-CRM-CUST-001`)
- `[NNN]` — Số thứ tự 3 chữ số (001, 002, 003, ...)

**Ví dụ:**
- `MT-CUST-001` — Micro-task 1 của feature CUST
- `MT-CUST-002` — Micro-task 2 của feature CUST
- `MT-ORD-001` — Micro-task 1 của feature ORD

---

## 2. Micro-Task Schema (JSON)

```json
{
  "micro_task_id": "MT-CUST-001",
  "feature_id": "FEAT-CRM-CUST-001",
  "name": "Entity + Migration",
  "description": "Tạo CustomerEntity và database migration để quản lý khách hàng",

  "estimated_time": "10 min",
  "complexity": "simple",
  "category": "entity",

  "input": {
    "files": [
      {
        "path": "phase2-features/crm/customer/customer-crud.md",
        "section": "## Features → Quản lý khách hàng",
        "reason": "Định nghĩa entity fields"
      },
      {
        "path": "phase3-architecture/technical-specs/database-design.md",
        "section": "## Table: Customer",
        "reason": "Chi tiết constraints, relationships"
      }
    ],
    "context_from_previous": []
  },

  "output": {
    "files": [
      "src/modules/crm/entities/customer.entity.ts",
      "src/database/migrations/001-create-customers-table.ts"
    ],
    "documentation": [
      "README section: Entity fields"
    ]
  },

  "success_criteria": [
    "compile: TypeScript file compiles without errors",
    "entity: CustomerEntity class defined with all fields",
    "migration: Migration file executes without errors",
    "types: Entity types match A6-EXT specification"
  ],

  "dependencies": [],
  "blocks": ["MT-CUST-002", "MT-CUST-003"],

  "tags": ["entity", "database", "typeorm"]
}
```

---

## 3. Micro-Task Fields Detail

| Field | Type | Required | Mô tả |
|-------|------|----------|--------|
| `micro_task_id` | string | ✅ | Unique identifier theo format MT-[PREFIX]-[NNN] |
| `feature_id` | string | ✅ | Feature ID cha (ví dụ: FEAT-CRM-CUST-001) |
| `name` | string | ✅ | Tên ngắn gọn (ví dụ: "Entity + Migration") |
| `description` | string | ✅ | Mô tả 1-2 dòng mục đích của micro-task |
| `estimated_time` | string | ✅ | Thời gian ước lượng (format: "N min", max 15) |
| `complexity` | enum | ✅ | "simple" \| "medium" \| "complex" |
| `category` | string | ✅ | Loại file chính (entity, repository, service, controller, dto, test, component, hook) |
| `input.files[]` | array | ✅ | List files/specs cần đọc (cụ thể section, không "đọc hết") |
| `input.context_from_previous` | array | ⭕ | Info từ micro-task trước (types, interfaces) |
| `output.files[]` | array | ✅ | List file paths cần tạo/sửa |
| `output.documentation` | array | ⭕ | Doc sections cần cập nhật |
| `success_criteria[]` | array | ✅ | List check để verify hoàn thành (compile, test, lint, types) |
| `dependencies[]` | array | ⭕ | Micro-task IDs phải hoàn thành trước |
| `blocks[]` | array | ⭕ | Micro-task IDs bị block bởi MT này |
| `tags[]` | array | ⭕ | Danh sách tags (entity, service, test, database, api, async, etc.) |

---

## 4. Dependency Graph

Mối quan hệ giữa micro-tasks trong feature:

```
MT-CUST-001 (Entity + Migration)
    ↓
MT-CUST-002 (Repository + Interface)
    ↓
MT-CUST-003 (Service Layer)
    ↓
MT-CUST-004 (API Controller)
    ↓
MT-CUST-005 (Integration Test)
```

**Quy tắc:**
- Mỗi MT phụ thuộc vào trước không thể chạy trước MT phụ thuộc
- Các MT **không phụ thuộc** có thể **chạy song song** (future enhancement)
- `input.context_from_previous` tả rõ "MT trước export cái gì" → "MT hiện tại import gì"

---

## 5. Standard Decomposition Pattern

### Pattern: Backend CRUD Feature

```
Feature: Customer CRUD (FEAT-CRM-CUST-001)

MT-CUST-001: Entity + Migration
  Files: entity, migration
  Time: 10 min
  Prev: none
  Exports: CustomerEntity type

MT-CUST-002: Repository + Interface
  Files: repository interface, repository impl
  Time: 8 min
  Prev: MT-CUST-001 (CustomerEntity type)
  Exports: ICustomerRepository interface

MT-CUST-003: Service Layer
  Files: service class, DTO files
  Time: 12 min
  Prev: MT-CUST-002 (ICustomerRepository)
  Exports: CustomerService interface

MT-CUST-004: API Controller
  Files: controller class, routes
  Time: 10 min
  Prev: MT-CUST-003 (CustomerService)
  Exports: POST /customers, GET /customers/:id, etc.

MT-CUST-005: Integration Test + Cleanup
  Files: e2e test file
  Time: 10 min
  Prev: MT-CUST-004 (all endpoints)
  Exports: Test results, final verification
```

---

## 6. Input Specification Rules

Mỗi `input.files[]` entry **PHẢI cụ thể:**

❌ **KHÔNG chấp nhận:**
```json
{
  "path": "phase2-features/crm/customer/customer-crud.md",
  "reason": "đọc spec"
}
```

✅ **CỦA CHẤP NHẬN:**
```json
{
  "path": "phase2-features/crm/customer/customer-crud.md",
  "section": "## Features → Quản lý khách hàng",
  "reason": "Định nghĩa entity fields (name, email, phone)"
}
```

**Tại sao?** Giúp agent tập trung, không bị noise từ doc dài.

---

## 7. Context Carry-Over Rules

### Khi MT2 phụ thuộc MT1:

**MT1 — Entity (Output)**
```
+ Type definition: CustomerEntity
+ Column definitions: id, name, email, ...
+ Relations: OneToMany(orders)
```

**MT2 — Repository (Input from MT1)**
```
context_from_previous: [
  "Type: CustomerEntity (đã define ở MT-CUST-001)",
  "File: src/modules/crm/entities/customer.entity.ts",
  "Import vào repository: import { CustomerEntity } from '../entities/customer.entity'"
]
```

**Quy tắc:**
- KHÔNG copy toàn bộ code MT1 → Chỉ tham chiếu **types, interfaces, file paths**
- MT2 agent đọc `context_from_previous`, tự import từ file MT1 tạo
- Giảm context size, tăng realism (simulate real multi-session flow)

---

## 8. Success Criteria Format

Mỗi criterion phải:
1. **Cụ thể** — Có thể verify tự động hoặc manual
2. **Testable** — Đúng hoặc sai, không "tương đối"
3. **Binary** — Pass hoặc Fail

### Ví dụ tốt:

| Criterion | Cách verify |
|-----------|-------------|
| `compile: No TypeScript errors` | `tsc --noEmit` |
| `entity: All fields defined` | Check fields vs A6-EXT |
| `migration: executes without error` | Run migration, check table created |
| `types: CustomerEntity exports | grep "export class CustomerEntity" |
| `naming: kebab-case file names` | Regex match file names |

### Ví dụ không tốt:

❌ "Code quality looks good"
❌ "Phù hợp với design"
❌ "Hoàn thành"

---

## 9. Backward Compatibility

### Khi feature không cần chia micro-tasks:

Feature có **≤ 2 files** → **KHÔNG tạo A7-EXT section** trong task file.

**Quy tắc:** wf-implement-feature chạy bình thường (không dùng --micro-task).

### Khi feature cần chia micro-tasks:

Feature có **≥ 3 files** **HOẶC** **estimated time > 15 min** → **PHẢI tạo A7-EXT** + sinh micro-tasks.

---

## 10. Example: Complete Micro-Task Set

Feature: Order Management (FEAT-ORD-001)
Files: 7 files, 45 min estimated

### Micro-Task Breakdown:

```
MT-ORD-001: Entity + Relationships
  Input: phase2 order-spec, phase3 db-design
  Output: order.entity.ts, order-item.entity.ts
  Time: 12 min
  Deps: none
  Exports: OrderEntity, OrderItemEntity types

MT-ORD-002: Repository
  Input: MT-ORD-001 entities, phase3 db-design
  Output: order.repository.ts, order.repository.interface.ts
  Time: 10 min
  Deps: MT-ORD-001
  Exports: IOrderRepository interface

MT-ORD-003: Service Layer
  Input: MT-ORD-002 repository, phase2 order-spec
  Output: order.service.ts, order-dtos.ts
  Time: 12 min
  Deps: MT-ORD-002
  Exports: OrderService public methods

MT-ORD-004: API Controller
  Input: MT-ORD-003 service, phase3 api-contract
  Output: order.controller.ts, order.routes.ts
  Time: 8 min
  Deps: MT-ORD-003
  Exports: REST endpoints

MT-ORD-005: Integration Tests
  Input: All MT output files
  Output: order.integration.test.ts
  Time: 10 min
  Deps: MT-ORD-004
  Success: All tests green, coverage ≥ 80%
```

---

## 11. Registry Integration

Micro-tasks được **sinh từ A6-EXT**, lưu trong **A7-EXT section** của task file.

**Không có separate registry** — Micro-tasks là internal structure của 1 feature.

**Khi implement:**
- User chạy: `/wf-implement-feature FEAT-ORD-001 --micro-task=MT-ORD-001`
- Agent chỉ implement MT-ORD-001
- Checkpoint lưu context digest per micro-task
- User resume: `/wf-implement-feature FEAT-ORD-001 --micro-task=MT-ORD-002 --resume`

---

## 12. Validation Rules (for wf-plan-modules Phase 7.5)

Trước khi sinh A7-EXT, verify:

- [ ] A6-EXT section tồn tại trong task file
- [ ] Files listed ≥ 3 (nếu < 3 → skip A7-EXT)
- [ ] Mỗi micro-task: `estimated_time` ≤ 15 min
- [ ] Mỗi micro-task: ≤ 3 output files
- [ ] Dependency graph acyclic (no circular deps)
- [ ] Tất cả micro-task IDs unique trong feature
- [ ] Success criteria testable (không mơ hồ)

---

## Tóm tắt

Micro-task schema giúp:
1. **Giảm context degradation** — Mỗi session ≤ 15 min, AI tập trung 100%
2. **Tăng accuracy** — Input/output rõ ràng, không suy luận
3. **Parallel potential** — MT không phụ thuộc có thể chạy song song (Phase 3)
4. **Resume-friendly** — Context digest carry-over giữa MT
5. **Backward compatible** — Feature nhỏ không bắt buộc dùng A7-EXT
