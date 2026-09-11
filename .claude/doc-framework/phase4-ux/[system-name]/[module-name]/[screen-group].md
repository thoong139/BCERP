# Screen Group: [Tên Nhóm Màn Hình]

> **System:** [Tên phân hệ] (SYS-[XXX])
> **Module:** [Tên module] (MOD-[SYS]-[MOD])
> **Tính năng:** [FEAT-[SYS]-[MOD]-NNN]
> **Route:** `/[phân-hệ]/[module]/[resource]`
> **Ngày:** [Ngày/Tháng/Năm]
>
> READS: `design-system.md`, `Navigation-[sys].md`, `phase2-features/[sys]/[mod]/[feat].md`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Main UI-ID | `UI-[SYS]-[MOD]-[SCREEN]-001` |
| Route | `/[phân-hệ]/[module]/[resource]` |
| Loại | List / Detail / Form / Dashboard / Report |
| FEAT-ID | [FEAT-[SYS]-[MOD]-001] |
| Người dùng | [Nhóm người dùng] |

---

## 1. TRANG CHÍNH (Main Page)

### 1.1. Layout

```
┌────────────────────────────────────────────────────────────┐
│ [Tiêu đề trang]                     [Nút hành động chính] │
├────────────────────────────────────────────────────────────┤
│ [Tìm kiếm...]   [Bộ lọc: Trạng thái ▾]   [Sắp xếp ▾]      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  [Nội dung chính — bảng / form / cards / chart]            │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ [Phân trang: ← 1 2 3 ... 10 →]                Tổng: [N]   │
└────────────────────────────────────────────────────────────┘
```

*Chỉnh sửa layout cho phù hợp với màn hình thực tế.*

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable | `sortable=true`, `20 dòng/trang` | [Ghi chú] |
| SearchInput | `debounce=300ms` | Tìm theo: [trường 1, trường 2] |
| [Component khác] | [Cấu hình] | [Ghi chú] |

### 1.3. Cột / Trường Hiển Thị

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| [Tên cột] | `entity.field` | Text / Date / Badge / Number | Có/Không | [px/auto] |
| Trạng thái | `entity.status` | Badge màu | Không | 120px |

**Badge màu:**
| Giá trị | Màu |
|---------|-----|
| [STATUS_A] | Xanh lá (success) |
| [STATUS_B] | Vàng (warning) |
| [STATUS_C] | Đỏ (error) |

### 1.4. Hành Động Chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Nhấn "Thêm mới" | Mở Dialog [Tên] | Form trống |
| Nhấn vào hàng | Mở Sheet [Tên] / Điều hướng | Chi tiết |
| Nhấn "Sửa" | Mở Dialog [Tên] | Form điền sẵn |
| Nhấn "Xóa" | Dialog xác nhận | Xóa sau khi xác nhận |

### 1.5. Phân Quyền

| Thành phần | Điều kiện hiển thị |
|-----------|------------------|
| Nút "Thêm mới" | [Role có quyền tạo] |
| Nút "Xóa" | Admin |
| [Thành phần khác] | [Điều kiện] |

---

## 2. TABS (Nếu có)

> *Xóa section này nếu trang không có tab system.*

| Tab | UI-ID | Nội dung | Hiện khi nào |
|-----|-------|---------|--------------|
| [Tab 1] | `UI-[SYS]-[MOD]-[SCREEN]-001-T1` | [Mô tả ngắn] | Luôn |
| [Tab 2] | `UI-[SYS]-[MOD]-[SCREEN]-001-T2` | [Mô tả ngắn] | [Điều kiện] |
| [Tab 3] | `UI-[SYS]-[MOD]-[SCREEN]-001-T3` | [Mô tả ngắn] | [Điều kiện] |

### Tab [Tên Tab 1]
*Chi tiết nội dung của tab này: cột, fields, actions...*

### Tab [Tên Tab 2]
*Chi tiết nội dung của tab này...*

---

## 3. DIALOGS / POPUPS

> *Liệt kê tất cả dialogs mở từ trang này.*

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | [Tên Dialog 1] | `UI-[SYS]-[MOD]-[SCREEN]-D1` | Form / Confirm / Wizard | Click [button] |
| 2 | [Tên Dialog 2] | `UI-[SYS]-[MOD]-[SCREEN]-D2` | Form / Confirm / Wizard | Click [button] |
| 3 | [Tên Dialog 3] | `UI-[SYS]-[MOD]-[SCREEN]-D3` | Form / Confirm / Wizard | Click [button] |

### 3.1. Dialog: [Tên Dialog 1]

**Loại:** Form tạo/sửa / Confirm / Wizard

**Fields (nếu là form):**
| Nhãn | Loại | Bắt buộc | Validation |
|------|------|---------|------------|
| [Field 1] | text/select/date | Có/Không | [Ràng buộc] |
| [Field 2] | text/select/date | Có/Không | [Ràng buộc] |

**Actions:**
| Nút | Xử lý | API |
|-----|-------|-----|
| Lưu | Validate → Gọi API → Đóng | POST /xxx |
| Hủy | Đóng dialog | — |

### 3.2. Dialog: [Tên Dialog 2]
*Chi tiết tương tự...*

---

## 4. SHEETS / DRAWERS

> *Liệt kê tất cả sheets/drawers mở từ trang này.*

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | [Tên Sheet 1] | `UI-[SYS]-[MOD]-[SCREEN]-S1` | Right / Bottom | Click [element] |

### 4.1. Sheet: [Tên Sheet 1]

**Kích thước:** Full width / 50% / Custom [px]

**Tabs (nếu có):**
| Tab | Nội dung |
|-----|---------|
| [Tab 1] | [Mô tả] |
| [Tab 2] | [Mô tả] |

**Nội dung:**
*Mô tả layout và nội dung của sheet...*

---

## 5. VIEW MODES (Nếu có)

> *Xóa section này nếu trang chỉ có 1 chế độ xem.*

| Mode | UI-ID | Icon | Hiện khi nào |
|------|-------|------|--------------|
| Bảng (Table) | `UI-[SYS]-[MOD]-[SCREEN]-M1` | `Table` | Default |
| Kanban | `UI-[SYS]-[MOD]-[SCREEN]-M2` | `Kanban` | [Điều kiện] |
| Calendar | `UI-[SYS]-[MOD]-[SCREEN]-M3` | `Calendar` | [Điều kiện] |

### Mode: Bảng (Table)
*Chi tiết đã có ở section 1*

### Mode: Kanban
*Layout và nội dung của view kanban...*

### Mode: Calendar
*Layout và nội dung của view calendar...*

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số |
|---------|--------|----------|--------|
| Tải trang | GET | `/api/v1/[sys]/[resource]` | `page=1&limit=20` |
| Tìm kiếm | GET | `/api/v1/[sys]/[resource]` | `search=xxx&status=yyy` |
| Tạo mới | POST | `/api/v1/[sys]/[resource]` | Body: dữ liệu form |
| Cập nhật | PUT | `/api/v1/[sys]/[resource]/:id` | Body: dữ liệu thay đổi |
| Xóa | DELETE | `/api/v1/[sys]/[resource]/:id` | — |
| [Dialog 1] submit | POST | `/api/v1/[sys]/xxx` | Body: dữ liệu |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-[SYS]-[MOD]-[SCREEN]-001` | Main Page | Trang chính |
| `UI-[SYS]-[MOD]-[SCREEN]-001-T1` | Tab | [Tên tab] |
| `UI-[SYS]-[MOD]-[SCREEN]-D1` | Dialog | [Tên dialog] |
| `UI-[SYS]-[MOD]-[SCREEN]-S1` | Sheet | [Tên sheet] |
| `UI-[SYS]-[MOD]-[SCREEN]-M1` | View Mode | [Tên mode] |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/[sys]/[mod]/[feature].md` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Database schema | `../../../phase3-architecture/technical-specs/database-design.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-[system].md` | Upstream |
| Implementation tasks | `../../../phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | Downstream — file này được tham chiếu từ Phase 5, không phải ngược lại |
