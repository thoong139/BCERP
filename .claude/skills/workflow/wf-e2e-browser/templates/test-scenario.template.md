# Kịch Bản Test — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Tổng kịch bản: {N} | Happy path: {N} | Error: {N} | Edge case: {N}

---

## Kịch bản 1: {Tên kịch bản — Happy Path}

**Loại:** Happy path
**Precondition:**
- User đã đăng nhập với role {role}
- Tồn tại dữ liệu: {điều kiện data cần có, tham chiếu seed data #N từ db-seed-data.md}

**Actors:** {Role} — permission: `{module}.{resource}.{action}`

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|-----------------|-----------------|-----------|
| 1 | Truy cập {route URL} | Trang {tên trang} hiển thị, có danh sách | | - |
| 2 | Nhấn nút [{tên nút}] | Form/dialog mở | | - |
| 3 | Điền {field A} = "{giá trị hợp lệ}" | Field nhận input | | - |
| 4 | Điền {field B} = "{giá trị hợp lệ}" | Field nhận input | | - |
| 5 | Nhấn [Lưu] | Loading spinner hiện, button disabled | | - |
| 6 | Chờ response | Toast "Tạo thành công" hiện, dialog đóng, danh sách refresh | | - |

**Ghi chú:** {nếu có lưu ý đặc biệt}

---

## Kịch bản 2: {Tên — Validation Error}

**Loại:** Validation error
**Precondition:** User đã đăng nhập với role {role}

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|-----------------|-----------------|-----------|
| 1 | Mở form tạo mới | Form hiển thị | | - |
| 2 | Bỏ trống {required field} | - | | - |
| 3 | Nhấn [Lưu] | Error message "{field} không được để trống" hiện dưới input, form không submit | | - |

---

## Kịch bản 3: {Tên — Permission Error}

**Loại:** Auth/permission error
**Precondition:** User đăng nhập với role {role KHÔNG có quyền}

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|-----------------|-----------------|-----------|
| 1 | Truy cập {route} | Trang hiển thị nhưng nút [{action}] không có | | - |
| 2 | Gọi API trực tiếp POST /api/v1/{route} | 401/403 response | | - |

---

## Kịch bản 4: {Tên — Business Rule}

**Loại:** Edge case / Business rule
**Precondition:** {điều kiện}
**Business Rule:** BR-{N}: {tên rule}

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|-----------------|-----------------|-----------|
| 1 | {bước} | {mong đợi} | | - |

---

## Tóm Tắt Kết Quả

| Kịch bản | Loại | Kết quả | Ghi chú |
|----------|------|---------|---------|
| KK-001 | Happy path | PASS/FAIL/SKIP | |
| KK-002 | Validation | | |
| KK-003 | Permission | | |
| KK-004 | Business rule | | |

**Overall:** {N}/{M} PASS
