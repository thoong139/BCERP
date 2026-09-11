# Tính Năng: [Tên Tính Năng]

> **Dựa trên:** [REQ-[DEPT]-[NNN]] trong `phase1-business/departments/[dept]/[dept].md` (Phần A)
> **Phân hệ:** [Tên phân hệ] (SYS-[XXX])
> **Module:** [Tên module] (MOD-[SYS]-[MOD])
> **Ngày:** [Ngày/Tháng/Năm]
> **Trạng thái:** Chờ triển khai / Đang triển khai / Hoàn thành
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/[dept]/[dept].md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc:
> `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`
> Ví dụ: `REQ-SALES-001` → `FEAT-CRM-CUST-001`
> Tra `req-registry.json` để xác nhận SYS và MOD tương ứng.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-[SYS]-[MOD]-[NNN] |
| Module | MOD-[SYS]-[MOD] |
| Yêu cầu nghiệp vụ | [REQ-[DEPT]-[NNN], REQ-[DEPT]-[NNN]] |
| Người dùng liên quan | [Tên nhóm người dùng 1, Nhóm 2] |
| Độ ưu tiên | Cao / Trung bình / Thấp |
| Giai đoạn | Giai đoạn 1 / Giai đoạn 2 |
| Phụ thuộc | [Tính năng nào phải làm trước — FEAT-[SYS]-[MOD]-NNN] |
| Ghi chú Expert (A7) | [Tóm tắt điều chỉnh từ Expert Review — xem chi tiết tại `[dept].md` Mục A7.3. Xóa dòng này nếu không có điều chỉnh] |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
[1-2 câu mô tả tính năng này làm gì và tại sao cần có nó]

**Phạm vi:**
- Bao gồm: [Danh sách những gì tính năng này xử lý]
- Không bao gồm: [Những gì tính năng này KHÔNG làm — delegate cho tính năng/phân hệ khác]

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | [Tên nhóm người dùng] | [Hành động] | [Mục đích / lợi ích] |
| 2 | [Tên nhóm người dùng] | [Hành động] | [Mục đích] |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | [Quy tắc nghiệp vụ cụ thể] | [Thông báo lỗi / hành động xảy ra] |
| BR-002 | [Quy tắc tính toán nếu có] | [Xử lý] |
| BR-003 | [Quy tắc trạng thái / flow] | [Xử lý] |

---

## 4. Phân Quyền

| Hành động | [Nhóm NV 1] | [Nhóm NV 2] | [Quản lý] | Admin |
|-----------|------------|------------|----------|-------|
| Xem tất cả | ❌ | ❌ | ✅ | ✅ |
| Xem của mình | ✅ | ✅ | ✅ | ✅ |
| Tạo mới | ✅ | ✅ | ✅ | ✅ |
| Sửa (của mình) | ✅ | ✅ | ✅ | ✅ |
| Sửa (bất kỳ) | ❌ | ❌ | ✅ | ✅ |
| Xóa | ❌ | ❌ | ❌ | ✅ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- [VD: Khi khách hàng có nhiều người liên hệ → cần lưu nhiều đầu mối]
- [VD: Nhân viên nghỉ việc → cần chuyển toàn bộ dữ liệu sang người khác]
- [VD: Dữ liệu trùng lặp → cần cách phát hiện và gộp]

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Xóa section này nếu entity chính không có trạng thái (status).*
> *Điền bảng chuyển đổi trạng thái — developer sẽ dùng trực tiếp để implement validation.*

**Entity:** [Tên entity chính — VD: Đơn hàng, Lead, Ticket]

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING] ──(approve)──► [APPROVED] ──(complete)──► [COMPLETED]
                          │                        │
                          │ (reject)               │ (cancel)
                          ▼                        ▼
                      [REJECTED]              [CANCELLED]
```

*Vẽ lại sơ đồ cho phù hợp với entity thực tế.*

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING` | [Người tạo] | [Điền đầy đủ required fields] |
| `PENDING` | Approve | `APPROVED` | [Quản lý] | [Không vượt hạn mức] |
| `PENDING` | Reject | `REJECTED` | [Quản lý] | [Phải nhập lý do từ chối] |
| `APPROVED` | Complete | `COMPLETED` | [Hệ thống / Người dùng] | [Điều kiện hoàn thành] |
| `APPROVED` | Cancel | `CANCELLED` | [Quản lý, Admin] | [Phải nhập lý do hủy] |

**Quy tắc:**
- Không thể quay về trạng thái trước (trừ khi ghi rõ ở trên)
- Trạng thái `COMPLETED` và `CANCELLED` là trạng thái kết thúc — không chuyển tiếp
- [Thêm quy tắc đặc biệt nếu có]

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| [Entity 1] | `name`, `email`, `phone`, `status`, `assigned_to` | FK → `users.id` | Soft delete |
| [Entity 2] | `code`, `total`, `status`, `[entity1]_id` | FK → `[entity1].id` | Auto-gen code |
| [Entity liên kết] | `[entity1]_id`, `[entity2]_id`, `quantity` | FK → cả 2 entity trên | Junction table |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Acceptance Criteria được điền chi tiết ở Phase 5 (implementation tasks). Phase 2 có thể để trống hoặc ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| [SC-001: Tên scenario] | [Trạng thái ban đầu] | [Hành động] | [Kết quả mong đợi] | [ ] |
| [SC-002: Tên scenario] | [Trạng thái ban đầu] | [Hành động] | [Kết quả mong đợi] | [ ] |

> **Liên kết:** Mỗi scenario PHẢI map đến ít nhất 1 REQ-[DEPT]-[NNN] trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/[sys]/[mod]/[screen-group].md` |
