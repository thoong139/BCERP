<!-- bug-dashboard-version: [DASHBOARD_VERSION] -->
<!-- last-writer: [LAST_WRITER] -->
<!-- last-updated: [UPDATED_AT] -->

# Bảng Theo Dõi Sửa Lỗi — wf-fix-bugs v10.11.0

> **Session:** [SESSION_ID] | **Dự án:** [PROJECT_NAME] | **Phạm vi:** [SCOPE] | **Mức độ:** [PROFILE]
> **Cập nhật lúc:** [UPDATED_AT] | **Giai đoạn:** [CURRENT_PHASE] | **Version:** [DASHBOARD_VERSION]

> **CORE-025 note:** `bug-dashboard.md` được 4 phase update (Phase 1 init → Phase 5 populate → Phase 6 update → Phase 7 finalize). Mỗi writer PHẢI đọc prior version từ HTML comment trên cùng, bump N+1, và ghi vào HTML comment + bảng "Version" để consumer detect concurrent write conflict.

---

## Tổng Quan

| Chỉ số | Giá trị |
|--------|---------|
| Tín hiệu phát hiện | [TOTAL_SIGNALS] |
| Lỗi đã phân loại | [TOTAL_ISSUES] |
| Đã sửa xong | [FIXED_COUNT] |
| Đang chờ xử lý | [PENDING_COUNT] |
| Hoãn lại | [DEFERRED_COUNT] |
| Thất bại | [FAILED_COUNT] |
| Khía cạnh đã kiểm tra | [DIMENSIONS_COVERED] / [DIMENSIONS_TOTAL] |

**Tiến độ:** [PROGRESS_PCT]% hoàn thành ([FIXED_COUNT]/[TOTAL_ISSUES])

---

## Danh Sách Lỗi

[BEGIN_ISSUE_ROWS]

### [STATUS_ICON] [ISSUE_ID] — [SEVERITY_BADGE] [ISSUE_TITLE]

- **File:** `[TARGET_FILE]` ([TARGET_LINE_RANGE])
- **Khía cạnh:** [DIMENSIONS]
- **Mô tả:** [DESCRIPTION]
- **Trạng thái:** [FIX_STATUS_LABEL]
- **Hành động:** [ACTION_TAKEN]
[GUIDANCE_SECTION]

---

[END_ISSUE_ROWS]

## Tổng Kết Theo Trạng Thái

| Trạng thái | Số lượng | Tỷ lệ |
|-----------|----------|-------|
| ✅ Đã sửa | [FIXED_COUNT] | [FIXED_PCT]% |
| ⬜ Chưa xử lý | [PENDING_COUNT] | [PENDING_PCT]% |
| ⏸️ Hoãn lại | [DEFERRED_COUNT] | [DEFERRED_PCT]% |
| ❌ Thất bại | [FAILED_COUNT] | [FAILED_PCT]% |

## Hạng Mục Cần Xử Lý Thêm

[CUSTOM_ACTIONS_SECTION]

## Hướng Dẫn Xử Lý Từng Loại

[GUIDANCE_LEGEND_SECTION]

## Chú Thích

### Biểu tượng Trạng thái

| Icon | Ý nghĩa |
|------|---------|
| ✅ | Đã sửa — lỗi đã được fix thành công |
| ⬜ | Chưa xử lý — đợi trong hàng đợi sửa |
| 🔄 | Đang sửa — đang được xử lý |
| ⏸️ | Hoãn lại — cần điều kiện đặc biệt (xem hướng dẫn) |
| ❌ | Thất bại — không thể tự động sửa (xem hướng dẫn) |
| ⚠️ | Cần CDG — cần người dùng quyết định trước khi sửa |
| ℹ️ | Thông tin — mức độ thấp, không bắt buộc sửa |

### Mức Độ Nghiêm Trọng

| Mức | Ý nghĩa |
|-----|---------|
| 🔴 CRITICAL | Phải sửa ngay — ảnh hưởng đến hoạt động chính |
| 🟠 HIGH | Nên sửa sớm — ảnh hưởng đến chất lượng |
| 🟡 MEDIUM | Cân nhắc sửa — ảnh hưởng đến UX hoặc bảo trì |
| 🟢 LOW | Có thể sửa sau — tối ưu nhỏ |
| 🔵 INFO | Tham khảo — gợi ý cải thiện |

### Các Skill MCV3 Có Thể Dùng Để Xử Lý Riêng

| Vấn đề | Skill khuyến nghị |
|--------|-------------------|
| Lỗi chức năng / logic phức tạp | `/wf-implement-feature [tên]` |
| Lỗi kiến trúc / thiết kế hệ thống | `/wf-design` |
| Lỗi bảo mật (OWASP) | `/wf-fix-bugs --dims=QD3 --profile=deep` |
| Lỗi hiệu năng (chậm, nặng) | `/wf-fix-bugs --dims=QD4 --profile=deep` |
| Lỗi giao diện / UX | `/ui-ux-pro-max` hoặc `/wf-design-ux` |
| Lỗi truy cập / accessibility | `/wf-fix-bugs --dims=QD5 --profile=deep` |
| Lỗi dữ liệu / database | `/wf-fix-bugs --dims=QD6 --profile=deep` |
| Lỗi tương thích (trình duyệt, thiết bị) | `/wf-fix-bugs --dims=QD7 --profile=deep` |
| Lỗi runtime (console, network, auth) | `/wf-fix-bugs --dims=QD9 --profile=deep` |
| Lỗi tích hợp (cross-module, API contract) | `/wf-fix-bugs --dims=QD10 --profile=deep` |
| Thiếu logic nghiệp vụ | `/wf-fix-bugs --dims=QD11 --profile=deep` |
| Cần phân tích yêu cầu lại | `/wf-analyze-requirements` |
| Cần kiểm tra đồng bộ | `/wf-verify-sync` |
| Cần kiểm tra tổng quan dự án | `/status` |

---

> **Tự động tạo bởi:** wf-fix-bugs dashboard generator
> **Output:** `$SESSION_DIR/bug-dashboard.md` (theo dõi xuyên suốt phiên xử lý)
> **Template:** templates/phase5-triage/bug-dashboard.md
> **Cập nhật lần cuối:** [UPDATED_AT]
