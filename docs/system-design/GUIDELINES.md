# Tiêu chuẩn thiết kế giao diện EUREKA ERP (Fluent 2 + Lark Base)

Hệ thống Design System của EUREKA ERP được phát triển theo triết lý kết hợp giữa **Microsoft Fluent 2 / Microsoft 365** (hệ thống phân cấp phẳng, thanh lệnh rõ ràng, neutral surfaces, side drawers, dialogs, property grids) và **Lark Base** (bảng dữ liệu mật độ cao, ô sắc nét, status pills pastel, dải chỉ số tiến trình ngang, kanban).

---

## 1. Triết lý cốt lõi (Core Principles)

1. **Desktop-First & Data Density (Mật độ cao trên màn hình lớn)**:
   - ERP dành cho chuyên viên vận hành, kế toán, marketing, kho vận, mua hàng và sales làm việc liên tục 8 tiếng/ngày trên máy tính để bàn (24", 27" Full HD/2K).
   - Tối ưu không gian: Không để khoảng trắng dư thừa lãng phí (excessive whitespace). Hàng bảng có chiều cao 32px-36px.
   - Tránh các thẻ Card to cồng kềnh (oversized cards). Thay thế bằng **Metric Ribbon** (dải chỉ số ngang liền mạch cao 36px-40px) hoặc **FluentMetricCard** nhỏ gọn.

2. **Neutral Surfaces & Subtle Borders (Bề mặt trung tính & Viền 1px mảnh)**:
   - Nền trắng/xám trung tính (`bg-white`, `bg-zinc-50`, `dark:bg-zinc-950`).
   - CẤM các mảng màu gradient lòe loẹt, bóng đổ đen đậm (heavy drop shadows) phong cách ứng dụng tiêu dùng (consumer app).
   - Phân định các khối bằng viền 1px mảnh sắc nét (`border-zinc-200`, `dark:border-zinc-800`).

3. **Status Pills & Tags (Nhãn trạng thái Pastel tinh nhã)**:
   - Nhãn trạng thái dùng nền màu pastel nhẹ nhàng (`bg-emerald-50`, `bg-amber-50`, `bg-rose-50`, `bg-blue-50`) đi kèm chấm màu (Status Dot) bão hòa và chữ đậm nét để mắt dễ quét hàng trăm dòng dữ liệu mà không bị mỏi.

4. **Hierarchical Navigation, Drawers & Two-Pane Master-Detail**:
   - Khi xem chi tiết một bản ghi (Lead, Đơn hàng, Phiếu kho, Chứng từ, Hợp đồng), sử dụng:
     - **FluentSheet / FluentDrawer** (420px, 560px, 740px, 960px, half, full; vị trí `right`, `left`, `bottom`) để xem/sửa nhanh mà không mất ngữ cảnh danh sách.
     - **FluentMasterDetail (Two-Pane)** (30% danh sách bên trái + 70% chi tiết bên phải) cho các module quản lý sâu (CRM Customer 360, HRM Hồ sơ nhân viên, Sổ cái kế toán, Đơn hàng mua hộ).
     - **FluentDialog / FluentConfirmDialog / FluentPromptDialog** cho các tác vụ tạo mới, xác nhận hoặc nhập lý do từ chối/hủy.

5. **Kỷ luật Production (CẤM Mock / Dữ liệu giả)**:
   - Toàn bộ dữ liệu hiển thị phải kết nối với API backend thật. Khi chưa có dữ liệu, hiển thị ký tự "—", skeleton hoặc empty state sạch sẽ.

---

## 2. Danh mục Toàn bộ 40+ Thành phần Chuẩn (Component Catalog)

### Nhóm 1: Form Controls & Nhập liệu Chuyên Sâu (`@/design-system`)
- `FluentButton`: Nút bấm 5 biến thể (`primary`, `secondary`, `outline`, `ghost`, `danger`), 4 kích thước (`xs`, `sm`, `default`, `lg`), hỗ trợ loading spinner và icon.
- `FluentInput`: Ô nhập dữ liệu với label, required asterisk, helper text, error message, leading/trailing icon và clear button.
- `FluentNumberInput`: Ô nhập số lượng, khối lượng, kích thước có nút tăng giảm `+` / `-`, min, max, step, suffix (Kiện, kg, m3).
- `FluentMoneyInput`: Ô nhập tiền tệ chuẩn ERP (VND, CNY, USD, EUR), format phân cách hàng nghìn, prefix tiền tệ, parse số thực chính xác.
- `FluentCombobox`: Dropdown tìm kiếm chọn 1 mục từ danh mục lớn kèm debounce, clearable, `onCreateNew`.
- `FluentMultiSelect`: Dropdown chọn nhiều tag/vai trò với badges `+N`, search filter, Select All, Clear All.
- `FluentDatePicker`: Chọn 1 ngày dạng YYYY-MM-DD.
- `FluentDateRangePicker`: Chọn khoảng Từ ngày - Đến ngày kèm quick presets (Hôm nay, 7 ngày qua, Tháng này, Quý này, Năm nay).
- `FluentDateTimePicker` & `FluentTimePicker`: Chọn ngày giờ hoặc giờ giao nhận hàng.
- `FluentFileUpload`: Kéo thả & upload file, icon loại file (PDF, Excel, Ảnh, Zip), progress bar, preview thumbnail, size guard.
- `FluentFormSection` & `FluentFormGrid` & `FluentFieldset`: Phân chia nhóm biểu mẫu có collapsible toggle và grid 1/2/3/4 cột.
- `FluentStickyFormFooter`: Thanh nút hành động cố định chân form (Lưu, Hủy, Lưu & Tạo mới) có auto-elevation khi scroll.
- `FluentInlineEdit`: Chỉnh sửa trực tiếp giá trị ngay trên dòng (text, number, select) với nút tick lưu và x hủy.
- `FluentTextarea`: Ô nhập văn bản nhiều dòng với auto-scroll và auto-label.
- `FluentSelect`: Dropdown chọn chuẩn với chevron.
- `FluentCheckbox`: Checkbox 3 trạng thái (checked, unchecked, indeterminate).
- `FluentSwitch`: Công tắc bật/tắt nhanh cho cấu hình hệ thống.
- `FluentRadioGroup`: Chọn 1 trong nhiều lựa chọn theo chiều dọc hoặc ngang.
- `FluentBadge`: Nhãn đánh dấu phân loại dạng chip mỏng.

### Nhóm 2: Nhãn trạng thái (Status Pills & Dots)
- `StatusPill`: Pastel badge bo tròn mềm mại (`success`, `warning`, `danger`, `info`, `purple`, `teal`, `neutral`) kèm chấm phân biệt và pulse animation.
- `StatusDot`: Chấm tròn trạng thái độc lập (`sm`, `default`, `lg`).

### Nhóm 3: Thanh công cụ & Dải chỉ số
- `FluentCommandBar` & `CommandBarItem`: Thanh tác vụ trên cùng kiểu Microsoft 365 (Nút chính, View switcher, Batch actions, Import/Export, Refresh).
- `MetricRibbon`: Dải chỉ số ngang cao 36-40px thay thế Funnel card to, nhấp vào phân đoạn để lọc dữ liệu tức thì.
- `FluentMetricCard`: Thẻ chỉ số tổng quan nhỏ gọn kèm số liệu lớn, trend %, và icon.

### Nhóm 4: Bộ lọc & Bảng dữ liệu Mật độ cao (Lark Base Data Grid)
- `LarkFilterBar` & `FilterChip`: Thanh tìm kiếm nhanh kết hợp cascade filter chips và density toggle.
- `LarkDenseTable`: Bảng dữ liệu mật độ cao (row height 32px / 36px / 44px), sticky columns 2 chiều, expandable rows, summary footer row.
- `ColumnVisibilityDropdown`: Dropdown tùy biến bật/tắt hiển thị từng cột trong bảng.
- `TableCellRenderers`: Đầy đủ các renderer chuyên dụng (`LarkTextCell`, `LarkStatusCell`, `LarkMoneyCell`, `LarkDateCell`, `LarkContactCell`, `LarkAvatarCell`, `LarkLinkCell`, `LarkProgressCell`, `LarkActionCell`).
- `TablePagination`: Phân trang gọn gàng chân bảng.

### Nhóm 5: Dialogs, Sheets, Popovers & Menus
- `FluentDialog`: Hộp thoại modal chuẩn có header, subtitle, body cuộn độc lập và footer cố định.
- `FluentConfirmDialog`: Hộp thoại xác nhận thao tác quan trọng (Xóa, Hủy, Duyệt).
- `FluentPromptDialog`: Hộp thoại yêu cầu nhập lý do kèm danh sách lý do mẫu và validation.
- `FluentSheet` & `FluentDrawer`: Ngăn kéo trượt 4 hướng (`right`, `left`, `bottom`, `top`) với các width (`compact`, `default`, `wide`, `xl`, `half`, `full`).
- `FluentDropdownMenu` & `ActionDropdown`: Menu thả xuống 3-chấm thao tác dòng dữ liệu kèm shortcut và danger item.
- `FluentPopover`: Hộp nổi linh hoạt gắn vào trigger element.
- `FluentTooltip`: Tooltip chú thích nhanh khi hover.
- `FluentBatchActionBar`: Thanh công cụ nổi cố định ở đáy màn hình khi tick chọn nhiều dòng trong bảng.

### Nhóm 6: Điều hướng, Quy trình & Tiến độ
- `FluentPageHeader`: Header chuẩn của trang gồm Breadcrumbs, Title, Icon, Subtitle, Badges và Top Actions.
- `FluentTabs`: Tab phân nhánh 3 kiểu (`line`, `pill`, `segmented`).
- `FluentStepper`: Quy trình tiến độ nhiều bước (Horizontal & Vertical) cho đơn hàng và wizard nhập liệu.
- `FluentBreadcrumb`: Điều hướng đường dẫn nhỏ gọn chuẩn Fluent 2.
- `FluentProgressBar` & `FluentProgressRing`: Thanh tiến độ và vòng tròn tiến độ % dung lượng/tải trọng/chỉ tiêu.
- `FluentAccordion`: Khối gập mở nội dung nhiều tầng mượt mà.
- `FluentTreeView`: Cây danh mục kho, tài khoản kế toán, phòng ban có search và expand/collapse.
- `FluentMasterDetail`: Bố cục chia đôi Two-Pane (Danh sách bên trái + Chi tiết bên phải) hỗ trợ co giãn kích thước.
- `FluentPropertyGrid`: Bảng thuộc tính Key-Value 2/3/4 cột cho trang chi tiết, có nút copy to clipboard.
- `FluentTimeline`: Luồng thời gian (Order tracking, Logistics transit, CRM history).
- `FluentKanbanBoard`: Bảng Kanban kéo thả cho Pipeline cơ hội, Sourcing orders, WorkTasks.

### Nhóm 7: Phản hồi, Trạng thái & Audit Log
- `FluentBanner`: Banner thông báo hệ thống trên cùng (info, warning, danger, success).
- `FluentCallout`: Hộp thông báo/cảnh báo inline 4 cấp độ.
- `FluentEmptyState`: Trạng thái rỗng chuẩn kèm icon trung tính và nút hành động.
- `FluentSkeleton` & `FluentTableSkeleton`: Hiệu ứng tải dữ liệu chuẩn.
- `FluentSpinner` & `FluentLoadingOverlay`: Spinner và lớp phủ làm mờ loading khi thao tác dữ liệu.
- `FluentFormErrorSummary`: Hộp tổng kết danh sách lỗi validation ở đầu form.
- `FluentAuditHistoryTab`: Component tab Lịch sử chuẩn đáp ứng Trụ cột kiến trúc số 3 (`audit.entity_audit_logs`, AUD-001..004), hiển thị field-level diffs Before/After, Actor và Timestamp.

### Nhóm 8: Tiện ích Nghiệp vụ ERP
- `FluentCopyableText`: Chữ kèm nút copy 1-click có visual feedback.
- `FluentCurrencyDisplay`: Format hiển thị tiền tệ đa loại (VND, CNY, USD, EUR) kèm màu sắc âm/dương.
- `FluentStatusBadgeMapper`: Helper map mã trạng thái nghiệp vụ sang `StatusPill` tương ứng.

---

## 3. Bảng mã màu Nhãn trạng thái (Status Pills)

| Trạng thái | Nền (Background) | Viền (Border) | Chữ (Text) | Chấm (Dot) | Dùng cho |
| --- | --- | --- | --- | --- | --- |
| **Success** | `bg-emerald-50` | `border-emerald-200` | `text-emerald-800` | `bg-emerald-500` | Chốt deal, Hoàn thành, Đã duyệt, Đã xuất kho |
| **Warning** | `bg-amber-50` | `border-amber-200` | `text-amber-800` | `bg-amber-500` | Chờ duyệt, Sơ lọc C2, Đang kiểm hàng, Cần chú ý |
| **Danger** | `bg-rose-50` | `border-rose-200` | `text-rose-800` | `bg-rose-500` | Thất bại, Hủy, Quá hạn SLA, Lỗi hạch toán |
| **Info / Brand** | `bg-blue-50` | `border-blue-200` | `text-blue-800` | `bg-blue-500` | Mới tiếp nhận, C1 Thu thập, Đang vận chuyển |
| **Purple** | `bg-purple-50` | `border-purple-200` | `text-purple-800` | `bg-purple-500` | MQL C3 Sẵn sàng, Khách hàng VIP, Bút toán đặc biệt |
| **Teal** | `bg-teal-50` | `border-teal-200` | `text-teal-800` | `bg-teal-500` | Báo giá L2, Đàm phán, Phân bổ kho, Báo cáo thuế |
| **Neutral** | `bg-zinc-100` | `border-zinc-200` | `text-zinc-700` | `bg-zinc-400` | Bản nháp, Chưa phân loại, Mặc định |

---

## 4. i18n Đa ngôn ngữ bắt buộc

Mọi nhãn hiển thị trong Design System và giao diện ứng dụng phải được đưa vào file dịch:
- `apps/erp-web/src/messages/vi.json` (Tiếng Việt - chuẩn chính)
- `apps/erp-web/src/messages/en.json` (Tiếng Anh)
- `apps/erp-web/src/messages/zh.json` (Tiếng Trung)

Không bao giờ hardcode text tĩnh bên trong JSX của các component dùng chung.
