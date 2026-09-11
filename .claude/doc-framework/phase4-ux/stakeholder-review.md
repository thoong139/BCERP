# Stakeholder Review — Phase 4 UX Design

> Tổng hợp 3 góc đánh giá: UX Cross-Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo UX design đầy đủ, nhất quán với features và architecture, xác nhận coverage trước Phase 5.
>
> READS: `design-system.md`, `[sys]/Navigation-[sys].md`, `[sys]/[mod]/[screen-group].md`, `phase2-features/[sys]/[mod]/[feat].md`, `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/P5-00-implementation-roadmap.md`

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 4
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành design-system, Navigation-[sys], tất cả screen groups
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 4 hoàn thành → Chuyển sang Phase 5 (Implementation Planning)

### A.1. Trạng Thái Tài Liệu Đầu Vào

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Design System | `design-system.md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | |
| Navigation [SYS-1] | `[sys-1]/Navigation-[sys-1].md` | ⬜ / 🔄 / ✅ | |
| Screen Groups | `[sys]/[mod]/*.md` | ⬜ / 🔄 / ✅ | |

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên UX specs | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

### A.3. Tổng Hợp Vấn Đề & Hành Động

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Critical / High / Medium / Low | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |

### A.4. Xác Nhận Phase 4 Hoàn Thành

```
□ Design System đã hoàn thành (colors, typography, spacing, components)
□ Navigation specs đã hoàn thành cho tất cả systems
□ Screen groups đã hoàn thành cho tất cả modules có UI
□ Mọi UI-ID trong registry có file tương ứng
□ Phần B (UX Cross-Review) — hoàn thành
□ Phần C (Consistency Check) — hoàn thành
□ Phần D (Gap Analysis) — hoàn thành
□ Tổng hợp vấn đề (mục A.3) — tất cả đã xử lý xong
```

**Ngày xác nhận Phase 4 hoàn thành:** [Ngày/Tháng/Năm]

---

## Phần B: Rà Soát Xuyên UX Specs (UX Cross-Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### B.1. Ma Trận Feature → Screen Coverage

> *Kiểm tra mỗi feature có ít nhất 1 screen group tương ứng.*

| FEAT-ID | Mô tả | Screen Group(s) | UI-ID(s) | Coverage | Ghi chú |
|---------|-------|----------------|----------|----------|---------|
| [FEAT-CRM-CUST-001] | [Quản lý KH] | [customer-list] | [UI-CRM-CUST-LIST-001] | ✅ | |
| [FEAT-FIN-RPT-001] | [Báo cáo TC] | ❌ Thiếu | ❌ | ❌ | Cần tạo screen |

### B.2. Kiểm Tra Design System Consistency

> *Kiểm tra tất cả screen groups sử dụng đúng design tokens từ design-system.md.*

| Screen Group | Colors đúng? | Typography đúng? | Spacing đúng? | Components đúng? | Ghi chú |
|-------------|-------------|-----------------|--------------|-----------------|---------|
| [customer-list] | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | |

### B.3. Kiểm Tra Navigation Completeness

> *Kiểm tra tất cả screen groups xuất hiện trong Navigation-[sys].md.*

| Screen Group | Trong Navigation? | Route đúng? | Permission khớp? | Ghi chú |
|-------------|-------------------|------------|-----------------|---------|
| [customer-list] | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | |

### B.4. Kiểm Tra API Endpoint References

> *Kiểm tra API endpoints referenced trong screen groups tồn tại trong api-contract.md.*
>
> **Lưu ý:** API consistency check ở đây là informational — Phase 3 stakeholder-review.md là nơi chính thức validate API. Đội UX chỉ cần verify UI components gọi đúng endpoints đã documented.

| Screen Group | API Endpoint Referenced | Có trong api-contract? | Ghi chú |
|-------------|----------------------|----------------------|---------|
| [customer-list] | [GET /api/v1/customers] | ✅ / ❌ | |

---

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### C.1. Nhất Quán Với Feature Specs (Phase 2)

> *Kiểm tra UX design phản ánh đúng user stories và business rules từ feature specs.*

| FEAT-ID | User Stories covered? | Business Rules reflected? | Permissions matched? | Ghi chú |
|---------|----------------------|--------------------------|---------------------|---------|
| [FEAT-CRM-CUST-001] | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | |

### C.2. Nhất Quán Với Architecture (Phase 3)

> *Kiểm tra UX design align với architecture decisions.*

| Quyết định Architecture | UX phản ánh đúng? | Ghi chú |
|-------------------------|-------------------|---------|
| [VD: RBAC permissions] | ✅ / ❌ | [Menu items theo role?] |
| [VD: Multi-tenant] | ✅ / ❌ | [Tenant selector hiển thị?] |

### C.3. Nhất Quán Về UI-ID

> *Kiểm tra UI-ID naming convention nhất quán và không trùng.*

| Vấn đề | UI-ID(s) | Ghi chú |
|--------|---------|---------|
| [VD: Trùng ID] | [UI-CRM-CUST-LIST-001 xuất hiện 2 lần] | Cần đổi tên |
| [VD: Naming sai convention] | [UI-crm-cust-list-001] | Phải viết hoa |

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### D.1. Gap Về Screen Coverage

> *Features chưa có screen group tương ứng.*

| FEAT-ID | Mô tả | Priority | Hành động |
|---------|-------|----------|-----------|
| [FEAT-XX-NNN] | [Mô tả] | High/Medium/Low | Tạo screen group / N/A (backend only) |

### D.2. Gap Về UX Components

> *Components cần thiết nhưng chưa có trong design-system.md.*

| Component cần | Screen Group sử dụng | Có trong design-system? | Hành động |
|--------------|---------------------|------------------------|-----------|
| [VD: DataTable with filters] | [customer-list] | ❌ | Bổ sung vào design-system |

### D.3. Gap Về Accessibility

> *Kiểm tra accessibility requirements.*

| Yêu cầu | Có được đề cập? | Ở đâu | Ghi chú |
|---------|----------------|-------|---------|
| Keyboard navigation | ✅ / ❌ | | |
| Screen reader support | ✅ / ❌ | | |
| Color contrast (WCAG AA) | ✅ / ❌ | | |
| Responsive design | ✅ / ❌ | | |

### D.4. Tổng Kết Gap Analysis

| Loại gap | Số lượng | Critical | High | Medium | Low |
|----------|----------|----------|------|--------|-----|
| Screen coverage | [Số] | | | | |
| Components thiếu | [Số] | | | | |
| Accessibility | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |
