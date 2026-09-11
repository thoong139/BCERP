## A6-EXT. Executable Implementation Specification

> **Structured fragment** — architect agent (wf-plan-modules Phase 7.5) PHẢI POPULATE template này, KHÔNG viết tự do.
> Mục tiêu: developer agent (wf-implement-feature Phase 3) đọc A6-EXT TRƯỚC, KHÔNG cần load Phase 2/3 docs.
>
> **Bắt buộc:** Mỗi feature có ≥1 file spec. Mỗi file spec có ≥1 method (nếu Service/Repository/Controller) hoặc ≥1 field (nếu Entity).

### A6-EXT.0 Coverage Summary

| Metric | Value |
|--------|-------|
| **Total files** | *[N]* |
| **Files breakdown** | Entity: *[X]* / Service: *[Y]* / Controller: *[Z]* / Test: *[W]* / Other: *[V]* |
| **Total methods** | *[M]* (chỉ Service/Repository/Controller) |
| **Total test cases** | *[T]* (happy + error + edge) |
| **REQ-IDs covered** | *[REQ-XXX-001, REQ-XXX-002, ...]* |
| **External imports** | *[N]* libraries (typeorm, @nestjs/common, ...) |

> **Verify-gate (Phase 7a check 7a.12):** A6-EXT phải có ≥200 từ + ≥1 file spec + Coverage Summary đầy đủ.

---

### A6-EXT.1 File Specifications

> Lặp lại block dưới cho MỖI file. Mỗi file = một heading `### File [N]: [path]`.

#### File 1: `[absolute-or-relative-path]`

| Metadata | Value |
|----------|-------|
| **REQ-IDs** | *[REQ-XXX-001, ...]* |
| **Loại** | Entity / Service / Repository / Controller / DTO / Test / Component |
| **Mục đích** | *[1-2 câu mô tả]* |

**Imports & Dependencies:**

| Import | Từ | Loại | Ghi chú |
|--------|-----|------|---------|
| *[Symbol]* | *[Module path]* | External / Custom / Interface / Shared | *[Tùy chọn]* |

**Fields / Columns** *(BẮT BUỘC nếu loại = Entity)*:

| Tên | Loại | Constraints | Decorators / Validation | Ghi chú |
|-----|------|-------------|------------------------|---------|
| *[fieldName]* | *[type]* | PK / NOT NULL / UNIQUE / nullable | *[@Column(...), @IsNotEmpty()]* | *[business meaning]* |

**Relations** *(BẮT BUỘC nếu loại = Entity và có quan hệ)*:

| Relationship | Target Entity | Cardinality | Decorator |
|--------------|---------------|-------------|-----------|
| *[propName]* | *[EntityName]* | OneToOne / OneToMany / ManyToOne / ManyToMany | *[@OneToMany(...)]* |

**Methods** *(BẮT BUỘC nếu loại = Service / Repository / Controller — mỗi method là 1 sub-block)*:

##### Method: `methodName(param: Type): ReturnType`

- **Purpose:** *[1 câu]*
- **Logic:**
  1. *[Step 1]*
  2. *[Step 2]*
  3. *[Step N: return]*
- **Error Handling:**
  - *[scenario]* → `throw AppError('CODE', statusCode)`
- **Dependencies (từ imports):** *[List interface methods this calls]*
- **Test Cases:**

  | TC ID | Scenario | Input | Expected Output | Type |
  |-------|----------|-------|-----------------|------|
  | TC-001 | Happy path | *[input]* | *[output]* | ✅ Pass |
  | TC-002 | *[error case]* | *[input]* | `AppError CODE statusCode` | ❌ Error |
  | TC-003 | *[edge case]* | *[input]* | *[expected]* | ❌ Edge |

**DTOs** *(nếu loại = Controller / Service):*

| DTO | Fields | Validation | Notes |
|-----|--------|------------|-------|
| *[CreateXxxDTO]* | *[field1, field2]* | *[@IsNotEmpty(), @IsEmail()]* | *[Used in POST endpoint]* |

**API Endpoints** *(BẮT BUỘC nếu loại = Controller):*

| Endpoint | Method | Input | Output | Status | Error Cases |
|----------|--------|-------|--------|--------|-------------|
| *[/path]* | *[GET/POST/PATCH/DELETE]* | *[DTO / param]* | *[ResponseDTO]* | *[200/201/204]* | *[400, 404, 409]* |

---

#### File 2: `[next-file-path]`

*[Lặp lại structure trên]*

---

### A6-EXT.2 Cross-File Contracts

> Liệt kê interfaces / types được share giữa các files trong feature này.

| Symbol | Defined in | Used by | Note |
|--------|------------|---------|------|
| *[ICustomerRepository]* | *[File 2]* | *[File 3, File 5]* | *[Interface, immutable trong Phase 3]* |

---

### A6-EXT.3 Verification Checklist (architect tự check trước khi APPEND)

- [ ] Coverage Summary section đầy đủ tất cả fields
- [ ] Mỗi file có Imports table
- [ ] Mỗi Entity có Fields table (≥1 row) + Relations table (nếu có)
- [ ] Mỗi Service/Repository/Controller có ≥1 Method với Test Cases (≥1 happy + ≥1 error)
- [ ] Mỗi Controller có API Endpoints table
- [ ] REQ-IDs khớp với feature.req_id trong registry
- [ ] Tổng word count ≥200 từ
- [ ] KHÔNG có placeholder `[...]` còn lại sau khi POPULATE

> **Lưu ý:** Nếu KHÔNG đáp ứng checklist → architect agent PHẢI bổ sung TRƯỚC khi WRITE task file. Phase 7a check 7a.12 sẽ verify.
