# Checklist Chuẩn Tuân Thủ 100% EUREKA Design System (Fluent 2 + Lark Base)

> **Phạm vi áp dụng:** Toàn bộ giao diện trên ứng dụng `apps/erp-web`.
> **Cơ sở tiêu chuẩn:** Bất biến **DS-001 → DS-006** ([`.agents/rules/19-design-system.md`](file:///d:/Working/EUREKA-2026/.agents/rules/19-design-system.md)), Thư viện chuẩn [`@/design-system`](file:///d:/Working/EUREKA-2026/apps/erp-web/src/design-system), Hướng dẫn [`GUIDELINES.md`](file:///d:/Working/EUREKA-2026/apps/erp-web/src/design-system/docs/GUIDELINES.md), Quy tắc [`DO_AND_DONT.md`](file:///d:/Working/EUREKA-2026/apps/erp-web/src/design-system/docs/DO_AND_DONT.md), Danh mục [`COMPONENTS_CATALOG.md`](file:///d:/Working/EUREKA-2026/apps/erp-web/src/design-system/docs/COMPONENTS_CATALOG.md), Khung màn hình mẫu [`RECIPES.md`](file:///d:/Working/EUREKA-2026/apps/erp-web/src/design-system/docs/RECIPES.md), và các Rules liên quan (`04-i18n`, `09-production-readiness`, `13-performance`, `16-frontend-safety`, `17-api-contract-feedback`, `18-finance`).

---

## 📌 6 BẤT BIẾN THIẾT KẾ BẮT BUỘC (DS-001 → DS-006)

| Mã | Tên bất biến | Nguyên tắc thực thi bắt buộc |
| :--- | :--- | :--- |
| **DS-001** | **Single Design System** | 100% UI trên `erp-web` dựng từ component của `@/design-system`. Cấm dựng UI kit / component primitive song song trong feature folder. |
| **DS-002** | **Desktop-First & Mật độ cao** | Chiều cao hàng bảng 32/36/44px (`LarkDenseTable`); KPI tổng quan dùng `MetricRibbon` (36-40px) hoặc `FluentMetricCard` nhỏ gọn; cấm Card to cồng kềnh (150-200px) và khoảng trắng lãng phí (`p-8`, `p-12`, `gap-8`). |
| **DS-003** | **Neutral Surfaces & Viền 1px** | Nền trung tính `bg-white`/`bg-zinc-50`/`dark:bg-zinc-950`, phân khối bằng viền mảnh 1px `border-zinc-200 dark:border-zinc-800`; cấm gradient màu mè và bóng đậm consumer (`shadow-xl`, `shadow-2xl`); dùng token `fluentElevation`. |
| **DS-004** | **Status Pills Pastel** | Trạng thái hiển thị qua `StatusPill`/`StatusDot`/`FluentStatusBadgeMapper` theo 7 nhóm màu chuẩn (Emerald, Amber, Rose, Blue, Purple, Teal, Zinc) kèm chấm tròn (Dot); cấm tự chế màu lạ. |
| **DS-005** | **Giữ ngữ cảnh bản ghi** | Xem/sửa nhanh dùng `FluentSheet`/`FluentDrawer` (420px → 960px); tạo mới/xác nhận dùng `FluentDialog`/`FluentConfirmDialog`; nhập lý do từ chối dùng `FluentPromptDialog`; module chuyên sâu dùng `FluentMasterDetail` (Two-Pane). |
| **DS-006** | **Tiền tệ & Font chuẩn** | Nhập tiền qua `FluentMoneyInput`, hiển thị tiền qua `FluentCurrencyDisplay`/`LarkMoneyCell` (cấm ghép chuỗi `amount + " VND"`); font duy nhất **Noto Sans** (`--font-noto-sans`); màu/spacing/typography ưu tiên token từ `@/design-system`. |

---

## 📋 MA TRẬN CHECKLIST RÀ SOÁT CHI TIẾT 100% (14 HẠNG MỤC)

### 1. Kiến Trúc & Import Thành Phần (DS-001)
- [ ] **1.1.** 100% component giao diện được import từ barrel `@/design-system` (không import trực tiếp từ đường dẫn file con sâu trong thư mục `design-system`).
- [ ] **1.2.** Không tồn tại component UI primitive tự chế (nút bấm, input, modal, dropdown, card) nằm trong feature folder.
- [ ] **1.3.** Trường hợp cần component mới hoặc biến thể chưa có trong `docs/COMPONENTS_CATALOG.md`:
  - [ ] Đã thêm vào `src/design-system/components/<nhóm>/` theo quy ước đặt tên `Fluent*` hoặc `Lark*`.
  - [ ] Đã typed đầy đủ props TypeScript, hỗ trợ đầy đủ Light/Dark Mode và i18n 3 ngôn ngữ.
  - [ ] Đã export qua `src/design-system/components/index.ts` và cập nhật tài liệu `COMPONENTS_CATALOG.md`.
- [ ] **1.4.** Tuyệt đối không dùng thư viện UI kit bên ngoài chưa được duyệt (shadcn/ui tự chế, generic slide design-system, v.v.).

---

### 2. Khung Bố Cục Trang & 10 Recipes Mẫu (DS-002 & RECIPES.md)
- [ ] **2.1.** Màn hình đã áp dụng chính xác 1 trong 10 khung chuẩn tại `docs/RECIPES.md`:
  - [ ] *Recipe 1 (Danh sách chuẩn 4 tầng):* `FluentPageHeader` → `FluentCommandBar` → `MetricRibbon` → `LarkFilterBar` → `LarkDenseTable` + `TablePagination`.
  - [ ] *Recipe 2 (Master-Detail Two-Pane):* `FluentMasterDetail` (30% Master bên trái + 70% Detail bên phải) + `FluentPropertyGrid` + `FluentCard`.
  - [ ] *Recipe 3 (Chi tiết Tabbed + Audit Log):* `FluentTabs` → Content Tabs → `FluentAuditHistoryTab` (Tab Nhật ký thay đổi AUD-001..004).
  - [ ] *Recipe 4 (Kanban Board):* `FluentKanbanBoard` phân cột kéo thả, nhấp thẻ mở `FluentSheet`.
  - [ ] *Recipe 5 (Modal Form & Xác nhận):* `FluentDialog` / `FluentConfirmDialog` / `FluentPromptDialog`.
  - [ ] *Recipe 6 (Form phức tạp đa cột):* `FluentFormSection` (collapsible) + `FluentFormGrid` (1/2/3/4 cột) + `FluentStickyFormFooter`.
  - [ ] *Recipe 7 (Side Sheet Xem/Sửa nhanh):* `FluentSheet` trượt từ phải (`position="right"`, width `compact` 420px / `default` 560px / `wide` 740px / `xl` 960px).
  - [ ] *Recipe 8 (Bảng nâng cao & Batch Actions):* `LarkDenseTable` (expandable/summaryRow) + `FluentBatchActionBar` cố định đáy màn hình.
  - [ ] *Recipe 9 (Quy trình Stepper & Từ chối):* `FluentStepper` + `FluentBanner` + `FluentPromptDialog` (nhập lý do từ chối có gợi ý mẫu).
  - [ ] *Recipe 10 (Cây phân cấp & Accordion):* `FluentTreeView` + `FluentAccordion`.
- [ ] **2.2. Tiêu đề trang chuẩn:**
  - Dùng `FluentPageHeader` cho trang nghiệp vụ cụ thể (đầy đủ `title`, `breadcrumbs`, `subtitle`, `badges`, `actions`).
  - Dùng `FluentWorkspacePageHeader` cho trang chủ phân hệ lớn (CRM, WMS, Finance, Marketing, HRM) có bộ chọn Workspace.
- [ ] **2.3. Cấm thẻ Card quá khổ:** CẤM dùng Card to cao 150px-200px chỉ chứa 1-2 con số KPI trên trang danh sách; đã thay thế bằng `MetricRibbon` (cao 36-40px, có click-to-filter) hoặc `FluentMetricCard` nhỏ gọn.
- [ ] **2.4. Mật độ Desktop-First:** Không để padding lãng phí (`p-8`, `p-12`, `gap-8`) trên màn hình vận hành máy tính để bàn (24-27").

---

### 3. Bề Mặt, Viền, Đổ Bóng & Màu Sắc (DS-003 & Tokens)
- [ ] **3.1. Nền trung tính (Neutral Surfaces):** Sử dụng nền phẳng chuẩn `fluentColors.surface` (`bg-white`, `bg-zinc-50`, `dark:bg-zinc-950`).
- [ ] **3.2. Viền 1px phân định (Subtle Borders):** Khối nội dung, bảng, thẻ được phân tách bằng viền mảnh `border-zinc-200 dark:border-zinc-800` (`fluentColors.border.subtle`).
- [ ] **3.3. CẤM Gradient & Bóng đổ đậm phong cách Consumer UI:** Tuyệt đối không dùng linear-gradient lòe loẹt hoặc bóng đen nặng (`shadow-xl`, `shadow-2xl`).
- [ ] **3.4. Đổ bóng theo token `fluentElevation`:**
  - `flat`: Viền 1px không bóng (khối thông tin, bảng).
  - `subtle`: Bóng siêu nhẹ `shadow-[0_1px_2px_rgba(0,0,0,0.03)]` (thẻ `FluentCard`, inset panel).
  - `dropdown`: `shadow-[0_4px_12px_rgba(0,0,0,0.08)]` (menu thả xuống, `FluentPopover`).
  - `drawer`: `shadow-[-4px_0_16px_rgba(0,0,0,0.06)]` (`FluentSheet`, `FluentDrawer`).
  - `modal`: `shadow-[0_12px_32px_rgba(0,0,0,0.12)]` (`FluentDialog`, `FluentConfirmDialog`).
- [ ] **3.5. Màu thương hiệu:** Nút chính, chỉ báo active và điểm nhấn sử dụng màu Microsoft Fluent Blue `#0F6CBD` (`fluentColors.brand[600]`).
- [ ] **3.6. Dark Mode đồng bộ:** 100% thành phần giao diện hiển thị chuẩn xác và có tương phản rõ ràng trên cả Light Mode và Dark Mode (kiểm tra các tiền tố `dark:*`).

---

### 4. Nhãn Trạng Thái Pastel & Phân Loại (DS-004)
- [ ] **4.1. Component chuẩn:** Mọi trạng thái nghiệp vụ được hiển thị bằng `StatusPill`, `StatusDot` hoặc thông qua helper `FluentStatusBadgeMapper`.
- [ ] **4.2. Tuân thủ chính xác 7 nhóm màu pastel chuẩn:**
  - [ ] `success` (`bg-emerald-50`, `border-emerald-200`, `text-emerald-800`, `dot: bg-emerald-500`): Hoàn thành, Đã duyệt, Đã xuất kho, Thành công, Đã thanh toán.
  - [ ] `warning` (`bg-amber-50`, `border-amber-200`, `text-amber-800`, `dot: bg-amber-500`): Chờ duyệt, Đang kiểm hàng, Sơ lọc C2, Cần chú ý, Chờ giải ngân.
  - [ ] `danger` (`bg-rose-50`, `border-rose-200`, `text-rose-800`, `dot: bg-rose-500`): Thất bại, Hủy, Quá hạn SLA, Lỗi hạch toán, Từ chối.
  - [ ] `info` (`bg-blue-50`, `border-blue-200`, `text-blue-800`, `dot: bg-blue-500`): Mới tiếp nhận, Đang vận chuyển, C1 Thu thập, Đang xử lý.
  - [ ] `purple` (`bg-purple-50`, `border-purple-200`, `text-purple-800`, `dot: bg-purple-500`): MQL C3 Sẵn sàng, Khách VIP, Bút toán đặc biệt, Đơn ưu tiên.
  - [ ] `teal` (`bg-teal-50`, `border-teal-200`, `text-teal-800`, `dot: bg-teal-500`): Báo giá L2, Đàm phán, Phân bổ kho, Báo cáo thuế, Hợp đồng ký điện tử.
  - [ ] `neutral` (`bg-zinc-100`, `border-zinc-200`, `text-zinc-700`, `dot: bg-zinc-400`): Bản nháp, Chưa phân loại, Mặc định.
- [ ] **4.3. Không tự chế màu:** Tuyệt đối không thêm màu trạng thái tự phát làm mất tính nhất quán thị giác toàn hệ thống.

---

### 5. Bảng Dữ Liệu Lark Base & Cell Renderers (Data Grid)
- [ ] **5.1. Component bảng:** Bảng dữ liệu sử dụng `LarkDenseTable` kèm `TablePagination` ở chân bảng.
- [ ] **5.2. Mật độ hàng (Row Height):** Hỗ trợ chuyển đổi mật độ qua `TableDensityToggle`:
  - `compact`: 32px (`h-8 min-h-[32px]`) — mật độ cao tối đa.
  - `default`: 36px (`h-9 min-h-[36px]`) — chuẩn Lark Base.
  - `relaxed`: 44px (`h-11 min-h-[44px]`) — khi ô chứa nhiều badge hoặc avatar.
- [ ] **5.3. Sử dụng đầy đủ 9 Cell Renderers chuyên dụng:**
  - [ ] `LarkTextCell`: Text thường (font 13px `compact`, hỗ trợ copyable hoặc truncate).
  - [ ] `LarkStatusCell`: Bọc `StatusPill` chuẩn vào ô bảng.
  - [ ] `LarkMoneyCell`: Format tiền tệ (phân cách hàng nghìn, đơn vị VND/CNY/USD/EUR, `colorize` âm/dương).
  - [ ] `LarkDateCell`: Format ngày tháng chuẩn theo locale người dùng (`vi-VN`, `en-US`, `zh-CN`).
  - [ ] `LarkContactCell`: Thông tin liên hệ (Tên, SĐT, Email có icon trực quan).
  - [ ] `LarkAvatarCell`: Hình đại diện nhân sự/khách hàng kèm fallback tên viết tắt.
  - [ ] `LarkLinkCell`: Mã liên kết điều hướng xem chi tiết.
  - [ ] `LarkProgressCell`: Thanh tiến độ % hoặc trạng thái hoàn thành.
  - [ ] `LarkActionCell` / `ActionDropdown`: Menu thao tác 3-chấm dòng (Sửa, Xóa, Chi tiết, Duyệt).
- [ ] **5.4. Tính năng bảng nâng cao:**
  - [ ] Tùy biến ẩn/hiện cột: Tích hợp `ColumnVisibilityDropdown`.
  - [ ] Hàng mở rộng (Expandable Row): Dùng `expandable` + `renderExpandedRow` cho danh sách con (SKU items, kiện hàng con, bút toán chi tiết).
  - [ ] Hàng tổng cộng (Summary Row): Dùng `summaryRow` ở chân bảng để tổng kết số tiền, số lượng.
  - [ ] Thao tác hàng loạt: Khi tick chọn nhiều dòng, hiển thị thanh nổi `FluentBatchActionBar` cố định đáy màn hình.

---

### 6. Ngăn Kéo (Drawer), Hộp Thoại (Dialog) & Giữ Ngữ Cảnh (DS-005)
- [ ] **6.1. Xem/Sửa chi tiết nhanh:** Dùng `FluentSheet` / `FluentDrawer` trượt từ phải (`position="right"`) để người dùng vừa xem/sửa chi tiết vừa đối chiếu bảng danh sách phía sau mà không bị tải lại trang.
- [ ] **6.2. Kích thước Drawer theo ngữ cảnh:**
  - `compact` (420px): Xem thông tin nhanh, ghi chú ngắn.
  - `default` (560px): Biểu mẫu cập nhật thông tin chung.
  - `wide` (740px): Chi tiết đơn hàng, hợp đồng có bảng danh mục mặt hàng.
  - `xl` (960px): Chi tiết chứng từ phức tạp, hồ sơ nhiều tab.
- [ ] **6.3. Hộp thoại tạo mới / thao tác ngắn:** Dùng `FluentDialog` (có header, subtitle, body cuộn độc lập và footer cố định).
- [ ] **6.4. Hộp thoại xác nhận thao tác quan trọng:** Dùng `FluentConfirmDialog` với tiêu đề, cảnh báo hậu quả rõ ràng và `variant="danger"` khi thao tác không thể hoàn tác (Xóa, Hủy, Hủy niêm phong).
- [ ] **6.5. Hộp thoại từ chối / hủy yêu cầu lý do:** Dùng `FluentPromptDialog` có danh sách lý do mẫu (`predefinedReasons`) và bắt buộc nhập giải trình.
- [ ] **6.6. Bố cục chia đôi có thể co giãn:** Sử dụng `FluentSplitPanel` khi cần chia 2 pane tỷ lệ tùy biến.

---

### 7. Biểu Mẫu Nhập Liệu & Form Controls (Form Standards)
- [ ] **7.1. Tiền tệ (`FluentMoneyInput`):** Bắt buộc dùng cho mọi trường tiền (VND, CNY, USD, EUR); CẤM ghép chuỗi `amount + " VND"` hay viết regex tự parse.
- [ ] **7.2. Số lượng & Quy cách (`FluentNumberInput`):** Có nút `+`/`-`, min, max, step và suffix rõ ràng (`kg`, `m3`, `Kiện`, `Hộp`, `Bộ`).
- [ ] **7.3. Tìm kiếm danh mục lớn (`FluentCombobox`):** Dùng cho tìm kiếm đối tác, khách hàng, nhà cung cấp, kho bãi, tài khoản kế toán; có debounce và `onCreateNew` tạo nhanh inline.
- [ ] **7.4. Chọn nhiều (`FluentMultiSelect`):** Dùng cho phân quyền vai trò, chọn nhiều tag/kho; có badge tóm tắt `+N`.
- [ ] **7.5. Chọn ngày tháng:** Dùng `FluentDatePicker` (1 ngày) hoặc `FluentDateRangePicker` (khoảng ngày kèm quick presets: Hôm nay, 7 ngày qua, Tháng này, Quý này, Năm nay).
- [ ] **7.6. Chọn ngày giờ:** Dùng `FluentDateTimePicker` hoặc `FluentTimePicker` cho lịch hẹn giao nhận hàng, ca làm việc.
- [ ] **7.7. Tải lên tệp tin (`FluentFileUpload`):** Hiển thị icon loại file (PDF, Excel, Word, Ảnh), tiến độ tải lên %, hỗ trợ kéo thả và chặn kích thước tệp vượt giới hạn.
- [ ] **7.8. Sửa trực tiếp trên dòng (`FluentInlineEdit`):** Cho phép sửa nhanh giá trị ngay trên dòng (text, number, select) với nút tick lưu và x hủy.
- [ ] **7.9. Bố cục biểu mẫu dài:**
  - [ ] Chia nhóm thông tin bằng `FluentFormSection` (hỗ trợ collapsible).
  - [ ] Bố cục đa cột cân đối bằng `FluentFormGrid` (1/2/3/4 cột).
  - [ ] Cố định thanh nút hành động ở chân form bằng `FluentStickyFormFooter` (đảm bảo nút Lưu/Hủy luôn hiển thị khi cuộn trang dài).
- [ ] **7.10. Tổng hợp lỗi biểu mẫu:** Lỗi validation form được tổng hợp ở đầu form qua `FluentFormErrorSummary` bên cạnh thông báo lỗi chi tiết dưới từng trường nhập liệu.

---

### 8. Typography, Tiền Tệ & Định Dạng (DS-006 & Tokens)
- [ ] **8.1. Font chữ duy nhất:** 100% giao diện sử dụng font **Noto Sans** qua biến `--font-noto-sans`. Tuyệt đối không import font ngoài (Inter, Roboto, Arial, Be Vietnam Pro...).
- [ ] **8.2. Cỡ chữ chuẩn theo phân cấp `fluentTypography`:**
  - `2xs` (11px): Subtext, badge siêu nhỏ, metadata.
  - `xs` (12px): Dòng phụ bảng dữ liệu, status pills.
  - `compact` (13px): Dữ liệu chuẩn trong ô bảng Lark Base.
  - `sm` (14px): Thân văn bản chuẩn, nhãn form, nút lệnh command bar.
  - `base` (15px) / `md` (16px): Section header, tiêu đề thẻ card.
  - `lg` (18px) / `xl` (20px): Tiêu đề Dialog/Drawer, Workspace header.
  - `2xl` (24px): Tiêu đề trang (`FluentPageHeader`).
- [ ] **8.3. Hiển thị tiền tệ:** Dùng `FluentCurrencyDisplay` hoặc `LarkMoneyCell`.
- [ ] **8.4. Sao chép 1-click:** Các mã định danh quan trọng (Mã đơn hàng, Mã vận đơn, Mã khách hàng, MST, SĐT) được bọc trong `FluentCopyableText` để người dùng sao chép nhanh có phản hồi trực quan.

---

### 9. Đa Ngôn Ngữ i18n (Tri-lingual Requirement: vi / en / zh) (Rule 04)
- [ ] **9.1. Đầy đủ 3 ngôn ngữ:** 100% chuỗi hiển thị được khai báo đầy đủ trong 3 file message:
  - `apps/erp-web/src/messages/vi.json` (Tiếng Việt)
  - `apps/erp-web/src/messages/en.json` (Tiếng Anh)
  - `apps/erp-web/src/messages/zh.json` (Tiếng Trung)
- [ ] **9.2. CẤM hardcode chuỗi tĩnh trong JSX:** Tuyệt đối không để text tĩnh trong JSX (bao gồm: title, subtitle, breadcrumbs, placeholder, helper text, error message, dialog message, table headers, empty state text, aria-labels).
- [ ] **9.3. Hook dịch chuẩn:** Sử dụng `useTranslations(namespace)` từ `next-intl`.

---

### 10. Kỷ Luật Production, Trạng Thái Dữ Liệu & API Contract (Rule 09 & 17)
- [ ] **10.1. CẤM Mock / Dữ liệu giả / Fallback giả (Rule 09):**
  - [ ] CẤM fallback số giả (ví dụ: `val ?? 26500000`, `name ?? "Công ty Demo"`).
  - [ ] CẤM fake timeout hay setTimeout giả lập API.
  - [ ] Khi chưa có dữ liệu hoặc null/undefined: Bắt buộc hiển thị ký tự gạch ngang "—" (em-dash), skeleton hoặc empty state chuẩn.
- [ ] **10.2. Trạng thái Loading mượt mà:** Khi đang tải, hiển thị `FluentSkeleton` hoặc `FluentTableSkeleton` có cấu trúc khớp với dữ liệu thực (tránh nhấp nháy layout Shift). Khi thực thi tác vụ, dùng `FluentLoadingOverlay` hoặc spinner trên nút `FluentButton isLoading`.
- [ ] **10.3. Trạng thái Rỗng (Empty State):** Khi không có kết quả, hiển thị `FluentEmptyState` kèm biểu tượng trung tính, thông điệp rõ ràng và nút hành động khắc phục ("Tạo mới", "Xóa bộ lọc").
- [ ] **10.4. Trạng thái Trang đặc biệt (`FluentPageStates`):** Xử lý rõ ràng các trường hợp `ErrorState`, `PermissionDeniedState` (403), `NotFoundState` (404).
- [ ] **10.5. Phản hồi Mutation qua API (Rule 17):**
  - [ ] Thành công: Gọi `toastFromApi(res)` từ `@/lib/api`.
  - [ ] Lỗi: Gọi `toastApiError(err)` từ `@/lib/api`.
  - [ ] Cấm `toast.success("...")`/`toast.error("...")` hardcode literal cho kết quả mutation.
  - [ ] Không phát toast thành công trước khi API phản hồi thật (cấm fake optimistic toast không rollback).
- [ ] **10.6. API Contract Fidelity & Optimistic Concurrency:**
  - [ ] Route lấy từ registry `apps/erp-web/src/lib/api/endpoints.ts`; đúng HTTP verb (POST tạo, PATCH sửa từng phần, PUT thay thế toàn bộ, DELETE xóa).
  - [ ] Truyền `rowVersion` nguyên trạng từ bản ghi đã load để kiểm soát xung đột dữ liệu đồng thời (xử lý lỗi 409 `ConcurrencyConflict`).

---

### 11. An Toàn Frontend (Frontend Safety: FE-001 → FE-104) (Rule 16)
- [ ] **11.1. Defensive Render (FE-001):** Không giả định API luôn trả đúng shape; mọi thao tác `.map()`, `.forEach()`, truy cập thuộc tính sâu trên dữ liệu API phải có guard (optional chaining `?.` và fallback rỗng `[]`/`{}`).
- [ ] **11.2. React Key ổn định (FE-002):** Mọi danh sách render phải có `key` duy nhất và ổn định (`item.id`), tuyệt đối không dùng array index làm key.
- [ ] **11.3. XSS-Safe URL (FE-101):** Mọi đường dẫn URL từ dữ liệu (`href`, `src`, link chuyển hướng) phải được validate scheme chỉ cho phép `http:` / `https:` trước khi gán vào thẻ `<a>`; chuỗi không hợp lệ chỉ render dạng text thuần (tránh lỗi `javascript:` XSS).
- [ ] **11.4. Cấm `dangerouslySetInnerHTML` tùy tiện (FE-102):** Cấm render HTML thô từ dữ liệu người dùng; nếu bắt buộc phải qua sanitization bằng thư viện được duyệt (DOMPurify).
- [ ] **11.5. Cleanup Hooks (FE-003):** Mọi `useEffect` có timer, event listener, subscription hoặc fetch phải có hàm cleanup; không `setState` sau khi component đã unmount.
- [ ] **11.6. Chống Double-Click (Frontend Idempotency):** Nút submit form phải có thuộc tính `disabled={isLoading}` và `isLoading` để tránh người dùng nhấn đúp gửi trùng request.

---

### 12. Tối Ưu Hiệu Năng Frontend (Performance: PERF-101 → PERF-107) (Rule 13)
- [ ] **12.1. Dynamic Import Thư Viện Nặng (PERF-101):** CẤM static import các thư viện nặng (Recharts, Chart.js, XLSX, ExcelJS, PDF, FullCalendar) vào trực tiếp page/layout; bắt buộc dynamic import qua `@/lib/dynamic-imports` (hoặc `LazyChart`).
- [ ] **12.2. TanStack Query Cache (PERF-102):** Cấu hình `staleTime` theo `CACHE_TIMES` chuẩn; cấm cấu hình polling dày không dừng khi tab trình duyệt bị ẩn.
- [ ] **12.3. Tối ưu Bảng Dữ Liệu Nóng (PERF-107):** Bảng có nhiều dòng dùng `memo` cho component hàng/ô và `useMemo` cho mảng định nghĩa `columns`.
- [ ] **12.4. Tối ưu Hình ảnh (PERF-103):** Ảnh đại diện, ảnh sản phẩm dùng `next/image` với kích thước cố định và `loading="lazy"`.

---

### 13. Tích Hợp Ba Trụ Cột Hệ Thống (Audit Log, RBAC & Multi-Tenant)
- [ ] **13.1. Audit Log (Trụ cột 3 - AUD-001..004):** Mọi trang chi tiết thực thể nghiệp vụ (Đơn hàng, Khách hàng, Hóa đơn, Phiếu kho, Hợp đồng, v.v.) bắt buộc có tab "Nhật ký thay đổi" sử dụng `FluentAuditHistoryTab` kết nối nguồn `audit.entity_audit_logs`.
- [ ] **13.2. Phân quyền RBAC (Trụ cột 1):** Các nút hành động chính (Tạo mới, Sửa, Duyệt, Xóa, Xuất Excel, Xem giá vốn) được kiểm soát hiển thị/disabled theo tuple quyền hiệu dụng `(module, featureCode, actions)` thông qua hook permission chuẩn.
- [ ] **13.3. Tenant Boundary (INT-006):** Không truyền `CompanyId` qua query/body giao diện; context tenant được xử lý tự động từ signed workspace session.

---

### 14. Kiểm Thử, Khả Năng Tiếp Cận & Nghiệm Thu (Validation Gates)
- [ ] **14.1. Khả năng tiếp cận & Phím tắt (A11y & Keyboard):**
  - [ ] Hỗ trợ phím `Esc` để đóng nhanh `FluentDialog` / `FluentSheet`.
  - [ ] Nút bấm và trigger hỗ trợ điều hướng bằng phím `Tab` và kích hoạt bằng `Enter`/`Space`.
  - [ ] Hiển thị vòng focus rõ ràng (`ring-2 ring-blue-500/20`).
  - [ ] Các icon buttons có `aria-label` và `FluentTooltip` chú thích rõ ràng.
- [ ] **14.2. Lệnh kiểm tra Typecheck bắt buộc:**
  ```powershell
  pnpm --dir apps/erp-web typecheck
  # hoặc
  pnpm --dir apps/erp-web quick-check
  ```
- [ ] **14.3. Kiểm tra Trình duyệt thực tế (Browser Smoke Test):**
  - [ ] Giao diện hiển thị hoàn hảo trên cả Light Mode và Dark Mode.
  - [ ] Mở Console: Không có lỗi JavaScript runtime, không có cảnh báo hydration mismatch, không có React duplicate key warnings.
  - [ ] Mở Network: Không có request lỗi (4xx, 5xx) trên các luồng thao tác chính.
  - [ ] Đối chiếu trực quan với catalog mẫu tại route `(dashboard)/design-system`.

---

## 🎯 BẢNG TRA CỨU NHANH: KHI NÀO DÙNG THÀNH PHẦN NÀO?

| Nghiệp vụ cần làm | Component / Token bắt buộc dùng | Ghi chú & Quy tắc |
| :--- | :--- | :--- |
| **Tiêu đề trang chi tiết** | `FluentPageHeader` | Có breadcrumbs, title 24px, subtitle, actions |
| **Tiêu đề trang phân hệ lớn** | `FluentWorkspacePageHeader` | Có bộ chọn Workspace, search bar, tabs lớn |
| **Thanh công cụ tác vụ trên bảng** | `FluentCommandBar`, `CommandBarItem` | Cao 40px, chứa nút Tạo mới, Xuất Excel, Filter |
| **Dải chỉ số tiến trình KPI ngang** | `MetricRibbon` | Cao 36-40px, nhấp từng phân đoạn để lọc nhanh |
| **Thẻ chỉ số tổng quan nhỏ gọn** | `FluentMetricCard` | Gồm số liệu lớn, % trend, icon nhỏ gọn |
| **Thanh tìm kiếm & lọc đa tầng** | `LarkFilterBar`, `FilterChip` | Tích hợp toggle mật độ bảng và cascade chips |
| **Bảng dữ liệu mật độ cao** | `LarkDenseTable`, `TablePagination` | Hàng cao 32/36/44px, sticky header & columns |
| **Hiển thị ô dữ liệu trong bảng** | `LarkTextCell`, `LarkStatusCell`, `LarkMoneyCell`, `LarkDateCell`, `LarkContactCell`, `LarkAvatarCell`, `LarkLinkCell`, `LarkProgressCell`, `LarkActionCell` | Sử dụng đúng renderer cho từng kiểu dữ liệu |
| **Thao tác chọn nhiều dòng** | `FluentBatchActionBar` | Thanh nổi cố định ở đáy màn hình khi tick chọn |
| **Xem / Sửa chi tiết không mất ngữ cảnh** | `FluentSheet` / `FluentDrawer` | Trượt từ phải, width `compact` (420) → `xl` (960) |
| **Bố cục chia đôi Two-Pane chuyên sâu** | `FluentMasterDetail`, `FluentSplitPanel` | Danh sách 30% bên trái + Chi tiết 70% bên phải |
| **Bảng thuộc tính Key-Value chi tiết** | `FluentPropertyGrid` | Hiển thị thông tin 2/3/4 cột, có nút copy |
| **Thẻ bao bọc nội dung** | `FluentCard` | Viền 1px chuẩn, elevation subtle |
| **Hộp thoại tạo mới / form ngắn** | `FluentDialog` | Modal có header, body cuộn, footer nút cố định |
| **Hộp thoại xác nhận nguy hiểm / duyệt** | `FluentConfirmDialog` | `variant="danger" \| "warning" \| "primary"` |
| **Hộp thoại yêu cầu nhập lý do từ chối** | `FluentPromptDialog` | Kèm danh sách gợi ý lý do mẫu |
| **Nhãn trạng thái màu pastel** | `StatusPill`, `StatusDot`, `FluentStatusBadgeMapper` | 7 nhóm màu chuẩn có chấm tròn (Dot) |
| **Nhập tiền tệ ERP** | `FluentMoneyInput` | Hỗ trợ VND, CNY, USD, EUR, format phân cách |
| **Hiển thị tiền tệ ERP** | `FluentCurrencyDisplay`, `LarkMoneyCell` | Format chuẩn theo locale, có màu âm/dương |
| **Tìm kiếm chọn 1 từ danh mục lớn** | `FluentCombobox` | Có debounce, hỗ trợ `onCreateNew` inline |
| **Chọn nhiều vai trò / tags** | `FluentMultiSelect` | Hiển thị badge rút gọn `+N` |
| **Chọn khoảng ngày Từ - Đến** | `FluentDateRangePicker` | Kèm presets nhanh (Hôm nay, 7 ngày, Tháng này) |
| **Chọn ngày / ngày giờ** | `FluentDatePicker`, `FluentDateTimePicker`, `FluentTimePicker` | Chuẩn ISO YYYY-MM-DD |
| **Tải lên tệp chứng từ** | `FluentFileUpload` | Icon loại file, dung lượng, progress bar |
| **Chỉnh sửa trực tiếp trên dòng** | `FluentInlineEdit` | Nút tick lưu và x hủy inline |
| **Nhóm biểu mẫu nhiều phần** | `FluentFormSection`, `FluentFieldset` | Có thể gập/mở collapsible |
| **Bố cục lưới form đa cột** | `FluentFormGrid` | Chia 1/2/3/4 cột responsive |
| **Thanh nút hành động cố định chân form** | `FluentStickyFormFooter` | Nút Lưu/Hủy luôn nhìn thấy khi cuộn form dài |
| **Hiển thị tổng hợp lỗi ở đầu form** | `FluentFormErrorSummary` | Danh sách lỗi validation có liên kết tới ô |
| **Quy trình tiến độ nhiều bước** | `FluentStepper` | Dạng ngang hoặc dọc, các trạng thái bước |
| **Dòng thời gian sự kiện** | `FluentTimeline` | Luồng trạng thái đơn hàng, tracking vận chuyển |
| **Bảng Kanban** | `FluentKanbanBoard` | Kéo thả thẻ cơ hội bán hàng, work tasks |
| **Tab phân nhánh nội dung** | `FluentTabs` | Kiểu `line`, `pill`, hoặc `segmented` |
| **Cây danh mục phân cấp** | `FluentTreeView` | Cây kho bãi, cơ cấu tổ chức, phòng ban |
| **Khối gập mở nội dung** | `FluentAccordion` | Quy định, hướng dẫn, chính sách |
| **Tab Nhật ký thay đổi (Audit Log)** | `FluentAuditHistoryTab` | Bắt buộc cho mọi trang chi tiết (AUD-001..004) |
| **Sao chép mã định danh 1-click** | `FluentCopyableText` | Mã đơn hàng, Vận đơn, SĐT, MST |
| **Trạng thái rỗng / Tải dữ liệu** | `FluentEmptyState`, `FluentSkeleton`, `FluentTableSkeleton`, `FluentSpinner`, `FluentLoadingOverlay` | Tránh nhấp nháy layout, không bịa dữ liệu |
| **Trạng thái trang lỗi / phân quyền** | `FluentPageStates` | ErrorState, PermissionDeniedState, NotFoundState |
| **Banner thông báo toàn trang** | `FluentBanner`, `FluentCallout` | 4 cấp độ: info, warning, danger, success |
| **Toast phản hồi thao tác API** | `toastFromApi(res)`, `toastApiError(err)` | Lấy message thật từ backend |
