# Design System — [TÊN DỰ ÁN]

> **Dùng cho:** Tất cả màn hình trong hệ thống
> **Cập nhật bởi:** [UX Designer / Frontend Lead]
> **Ngày:** [Ngày/Tháng/Năm]
>
> READS: `phase1-business/P1-01-project-overview.md`, `phase3-architecture/P3-01-architecture.md`
> USED BY: `[sys]/Navigation-[sys].md`, `[sys]/[mod]/[screen-group].md`

---

## 1. Màu Sắc

```css
/* Màu chính */
--color-primary:   [mã màu — VD: #2563EB];
--color-secondary: [mã màu];

/* Trạng thái */
--color-success:  [mã màu — VD: #16A34A];
--color-warning:  [mã màu — VD: #D97706];
--color-error:    [mã màu — VD: #DC2626];
--color-info:     [mã màu — VD: #0EA5E9];

/* Nền & văn bản */
--color-bg:          [mã màu];
--color-text:        [mã màu];
--color-text-muted:  [mã màu];
--color-border:      [mã màu];
```

---

## 2. Chữ (Typography)

```css
--font-family: '[Tên font]', sans-serif;  /* VD: 'Inter' */

/* Kích thước */
--text-xs:   12px;
--text-sm:   14px;
--text-base: 16px;
--text-lg:   18px;
--text-xl:   20px;
--text-2xl:  24px;
--text-3xl:  30px;

/* Độ đậm */
--font-normal:   400;
--font-medium:   500;
--font-semibold: 600;
--font-bold:     700;
```

---

## 3. Khoảng Cách (Spacing — lưới 8px)

```css
--space-1: 4px;   --space-2: 8px;   --space-3: 12px;
--space-4: 16px;  --space-6: 24px;  --space-8: 32px;
--space-10: 40px; --space-12: 48px; --space-16: 64px;
```

---

## 4. Thư Viện Icon

> **Lý do section này tồn tại:** Icons là design token cơ bản, cần được chuẩn hóa trước khi đưa vào components — F-TPL-B-001.

### 4a. Nguồn Icon

| Thuộc tính | Giá trị |
|-----------|---------|
| Thư viện icon | [Tên thư viện — VD: Lucide, Heroicons, Material Icons, Phosphor] |
| Phiên bản | [VD: v3.x] |
| Kiểu render | [SVG inline / Icon font / Sprite sheet] |
| Package | [VD: `lucide-react`, `@heroicons/react`] |

### 4b. Kích Thước Chuẩn

```css
/* Kích thước icon theo ngữ cảnh */
--icon-xs:  12px;  /* Inline text, badge */
--icon-sm:  16px;  /* Button nhỏ, input adornment */
--icon-md:  20px;  /* Button thường, menu item */
--icon-lg:  24px;  /* Tiêu đề, navigation */
--icon-xl:  32px;  /* Empty state, feature highlight */
--icon-2xl: 48px;  /* Onboarding, landing page */
```

### 4c. Quy Ước Đặt Tên

```
Định dạng: [danh-mục]-[mô-tả]-[biến-thể]

Ví dụ:
  action-add            → Thêm mới
  action-edit           → Chỉnh sửa
  action-delete         → Xóa
  action-save           → Lưu
  nav-home              → Trang chủ
  nav-settings          → Cài đặt
  status-success        → Thành công
  status-warning        → Cảnh báo
  status-error          → Lỗi
  status-info           → Thông tin
  ui-chevron-down       → Mũi tên xuống
  ui-search             → Tìm kiếm
  ui-close              → Đóng
```

### 4d. Danh Sách Icon Dùng Trong Hệ Thống

| Tên Icon | Thư viện / ID | Ngữ cảnh sử dụng |
|---------|--------------|-----------------|
| Plus / Add | lucide-react | Buttons, FABs, header actions |
| Edit / Pencil | lucide-react | Row actions, edit buttons |
| Trash / Delete | lucide-react | Row actions, danger actions |
| Search | lucide-react | Search bars, filter inputs |
| Dashboard | lucide-react | Navigation menu |
| Users / User | lucide-react | Navigation, user management |
| Settings / Cog | lucide-react | Navigation, config pages |
| ChevronDown / ChevronRight | lucide-react | Dropdowns, accordions |
| Check / CheckCircle | lucide-react | Status indicators, confirmations |
| X / XCircle | lucide-react | Modal close, error states |
| *(bổ sung khi thiết kế màn hình)* | — | — |

### 4e. Quy Tắc Sử Dụng

- **Icon + Label:** Luôn đi kèm văn bản hoặc `aria-label` — không dùng icon đơn độc cho hành động quan trọng
- **Màu sắc:** Kế thừa màu từ `currentColor` — không hardcode màu trực tiếp vào icon
- **Stroke width:** Thống nhất 1 giá trị trong toàn bộ dự án (VD: `strokeWidth={1.5}`)
- **Accessibility:** Icon trang trí dùng `aria-hidden="true"`; icon có nghĩa dùng `role="img"` + `aria-label`
- **Custom icon:** Nếu thư viện thiếu icon, thiết kế trên lưới `[24×24px / 20×20px]` với padding 2px

---

## 5. Thư Viện Component

| Component | Mục đích | Các dạng |
|-----------|---------|---------|
| Button | Hành động chính | `primary`, `secondary`, `danger`, `ghost` |
| Input | Nhập liệu văn bản | `default`, `error`, `disabled` |
| Select | Chọn từ danh sách | `default`, `multi-select` |
| DataTable | Hiển thị danh sách dạng bảng | — |
| Modal | Hộp thoại | — |
| Toast | Thông báo tạm thời | `success`, `error`, `warning`, `info` |
| Badge | Nhãn trạng thái | `success`, `warning`, `error`, `neutral` |
| Breadcrumb | Điều hướng vị trí | — |
| Pagination | Phân trang | — |
| EmptyState | Khi không có dữ liệu | — |
| LoadingSkeleton | Đang tải dữ liệu | — |

---

## 5. Bố Cục Trang (Layout)

**Khung ứng dụng:**
```
┌──────────────────────────────────────────────┐
│  [Logo]    [Menu điều hướng]    [Tên người dùng ▾] │  ← Topbar
├────────────┬─────────────────────────────────┤
│            │  [Breadcrumb]                   │
│  [Sidebar] │  [Tiêu đề trang]  [Nút hành động]│
│            │──────────────────────────────── │
│  [Menu]    │  [Nội dung chính]               │
│            │                                 │
│            │                                 │
└────────────┴─────────────────────────────────┘
```

**Trang danh sách:**
```
[Tiêu đề trang]                    [Nút: + Thêm mới]
[Ô tìm kiếm]  [Bộ lọc ▾]  [Sắp xếp ▾]
────────────────────────────────────────
[Tiêu đề cột 1] | [Cột 2] | [Cột 3] | [Hành động]
[Dữ liệu hàng 1]                      [Sửa] [Xóa]
[Dữ liệu hàng 2]                      [Sửa] [Xóa]
────────────────────────────────────────
[← Trước]  [1] [2] [3] ... [10]  [Sau →]
```

**Trang form (tạo / sửa):**
```
[Tiêu đề]                         [Hủy] [Lưu]
────────────────────────────────────────
[Nhãn trường *]
[Input / Select / ...]
[Thông báo lỗi — chỉ hiện khi có lỗi]

[Nhãn trường]
[Input]
────────────────────────────────────────
                           [Hủy] [Lưu]
```

---

## 6. Quy Ước Giao Diện

**Form:**
- Nhãn (label) đặt trên input — không dùng placeholder thay nhãn
- Trường bắt buộc: thêm dấu `*` màu đỏ vào nhãn
- Lỗi validation: thông báo ngay dưới trường, màu đỏ
- Nút Submit: disabled khi đang gửi (tránh submit nhiều lần)

**Thông báo:**
- Thành công: Toast màu xanh lá, tự đóng sau 3 giây
- Lỗi form: Hiện dưới từng trường, không dùng alert popup
- Lỗi server: Toast màu đỏ, có nút đóng thủ công
- Xóa dữ liệu: Hộp thoại xác nhận trước khi thực hiện

**Trạng thái tải:**
- Danh sách: Skeleton screen (không dùng spinner toàn trang)
- Nút đang xử lý: Spinner trong nút + disabled
- Không có dữ liệu: EmptyState có icon + mô tả + nút hành động

**Responsive:**
| Breakpoint | Layout |
|-----------|--------|
| Desktop (>1280px) | Sidebar cố định, bảng đầy đủ cột |
| Tablet (768–1280px) | Sidebar thu gọn, ẩn cột phụ trong bảng |
| Mobile (<768px) | Sidebar ẩn (hamburger menu), danh sách dạng card |

---

## 7. Common UI Patterns

> Các patterns giao diện phổ biến — chuẩn hóa để đảm bảo UX nhất quán toàn hệ thống.
> Điền vào khi thiết kế màn hình — patterns phát hiện trong quá trình thiết kế cần được cập nhật lại đây.

### 7.1 Form Patterns

| Pattern | Khi nào dùng | Ví dụ trong hệ thống |
|---------|-------------|---------------------|
| Single-column form | Form ≤5 trường, mobile-first | Đăng nhập, đổi mật khẩu |
| Two-column form | Form 6-10 trường, desktop view | Tạo hồ sơ, thông tin hợp đồng |
| Multi-step wizard | Form phức tạp >10 trường, có phụ thuộc | [Điền theo dự án] |
| Inline editing | Sửa nhanh không cần mở form riêng | Sửa tên, sửa số lượng trong bảng |
| Search-as-you-type | Dropdown search, autocomplete | Tìm khách hàng, tìm sản phẩm |

### 7.2 Navigation Patterns

| Pattern | Khi nào dùng | Ví dụ trong hệ thống |
|---------|-------------|---------------------|
| Sidebar navigation | App có ≥5 sections cấp 1 | Menu chính |
| Breadcrumb | Trang có hierarchy ≥3 cấp | Chi tiết → Module → Trang chủ |
| Tab navigation | Cùng entity, nhiều view | Chi tiết khách hàng: Thông tin / Lịch sử / Tài liệu |
| Drill-down | Danh sách → chi tiết | Danh sách đơn hàng → Chi tiết đơn hàng |
| Back button | Quay lại trang trước | Nút "← Quay lại" |

### 7.3 Feedback Patterns (Loading, Error, Empty State)

| Pattern | Khi nào dùng | Ví dụ trong hệ thống |
|---------|-------------|---------------------|
| Skeleton screen | Đang tải danh sách / trang | Tải danh sách, tải dashboard |
| Spinner in button | Đang submit form | Nút "Lưu" khi đang gửi |
| Toast notification | Kết quả hành động | "Lưu thành công", "Xóa thất bại" |
| Empty state with CTA | Danh sách chưa có dữ liệu | "Chưa có đơn hàng — Tạo đơn hàng đầu tiên" |
| Confirmation dialog | Hành động không thể hoàn tác | Xóa bản ghi, hủy đơn hàng |
| Error boundary | Lỗi component không crash toàn trang | [Điền theo dự án] |

---

> ## Ghi Chú Mở Rộng
>
> **Sections 1–7 ở trên là BẮT BUỘC** — mọi design system phải có đầy đủ.
> (Section 7 Common UI Patterns có thể điền dần trong quá trình thiết kế màn hình.)
>
> Tùy dự án, có thể bổ sung thêm các sections sau (OPTIONAL).
> Agent `ux-designer` được phép thêm sections mới khi cần thiết,
> miễn là KHÔNG xóa hoặc bỏ qua sections 1–7 bắt buộc.

---

## 8. Thiết Kế Mobile (Optional)

> **OPTIONAL — Include khi:** `interface_type` trong registry là `mobile` hoặc `web+mobile`, hoặc project yêu cầu mobile-first design.
> **Skip khi:** Project chỉ có web desktop (`interface_type = web`) và không có yêu cầu mobile optimization.
>
> *Bổ sung khi project có mobile app hoặc cần mobile-first design.*

| Thuộc tính | Giá trị |
|-----------|---------|
| Touch target size | Minimum 44×44px |
| Bottom navigation | Max 5 items |
| Gesture support | Swipe, pull-to-refresh, long-press |
| Safe area | Respect notch/home indicator |

---

## 9. Accessibility (Optional)

> **OPTIONAL — Include khi:** Project có yêu cầu WCAG compliance (healthcare, government, enterprise), hoặc target audience bao gồm người dùng có khuyết tật, hoặc có yêu cầu pháp lý về accessibility.
> **Skip khi:** Internal tool không có yêu cầu accessibility và không thuộc lĩnh vực có regulatory requirement.
>
> *Bổ sung khi project cần tuân thủ WCAG hoặc accessibility standards.*

```
Tiêu chuẩn: WCAG 2.1 Level [AA / AAA]

Yêu cầu:
- Color contrast ratio: ≥ 4.5:1 (text), ≥ 3:1 (large text)
- Keyboard navigation: Tab, Enter, Escape
- Screen reader: ARIA labels cho interactive elements
- Focus indicator: visible outline cho tất cả focusable elements
```

---

## 10. Đa Ngôn Ngữ / i18n (Optional)

> **OPTIONAL — Include khi:** Project phục vụ người dùng đa ngôn ngữ (VD: SaaS quốc tế, xuất khẩu phần mềm, hệ thống dùng nhiều quốc gia), hoặc có yêu cầu i18n rõ ràng trong Phase 1 business requirements.
> **Skip khi:** Single-language project không có kế hoạch mở rộng quốc tế.
>
> *Bổ sung khi project cần hỗ trợ nhiều ngôn ngữ.*

| Thuộc tính | Giá trị |
|-----------|---------|
| Ngôn ngữ mặc định | [vi / en] |
| Ngôn ngữ hỗ trợ | [vi, en, ...] |
| Date/Number format | Theo locale |
| RTL support | [Có / Không] |

---

## 11. [Tên Section Mở Rộng Khác] (Optional)

> **OPTIONAL — Include khi:** Có yêu cầu thiết kế đặc thù không nằm trong sections 1–10. Ví dụ: Dark Mode (khi có toggle theme requirement), Animation Guidelines (khi project có interaction phức tạp), Print Styles (khi cần in ấn), Data Visualization (khi có charts/graphs nhiều).
> **Skip khi:** Không có yêu cầu đặc thù ngoài sections 1–10.
>
> *Agent `ux-designer` tự thêm sections phù hợp với đặc thù dự án.*
> *Ví dụ: Dark Mode, Animation Guidelines, Print Styles, Data Visualization, v.v.*
> *Đánh số tiếp theo sau section 11 (12, 13, ...).*
