# Design System — BCERP

> **Dùng cho:** Tất cả màn hình trong hệ thống
> **Cập nhật bởi:** ux-designer (DEVKIT /wf-design-ux)
> **Ngày:** 13/09/2026
>
> READS: `phase3-architecture/P3-01-architecture.md`, `phase2-features/**/*.md`
> USED BY: `[sys]/Navigation-[sys].md`, `[sys]/[mod]/[screen-group].md`

> **Nguyên tắc nền tảng:** Desktop-first, worklist-centric — "hàng đợi việc của tôi" là màn hình chính. State là first-class: mọi object hiển thị trạng thái + "đang chờ ai, chờ bao lâu rồi". UX an toàn tiền (hard stop, dual approval) tách biệt UX vận hành. Mobile chỉ phục vụ tác vụ giao dịch ngắn. Thiết kế hướng sản xuất (productivity), lấy cảm hứng Fluent/M365 enterprise — KHÔNG phong cách consumer.

---

## 1. Màu Sắc

Tokens chia 3 nhóm: **Shared** (dùng cả web + mobile), **Web-only**, **Mobile-only**.

```css
/* ═══ SHARED — dùng chung web + mobile ═══ */

/* Thương hiệu */
--color-primary:   #1E5AA8;  /* xanh doanh nghiệp — action chính, link, active nav */
--color-primary-hover: #17478A;
--color-secondary: #0E7490;  /* teal — action phụ, phần tử được chọn trong biểu đồ */
--color-accent:    #6D28D9;  /* tím — dùng tiết chế: KPI nổi bật, commission */

/* Trạng thái UI cơ bản */
--color-success: #107C41;
--color-warning: #B45309;
--color-error:   #C42B1C;
--color-info:    #0F6CBD;

/* Nền & văn bản */
--color-bg:         #F2F4F7;  /* canvas ứng dụng */
--color-surface:    #FFFFFF;  /* bảng, panel, card nội dung */
--color-surface-alt:#F8F9FB;  /* header bảng, vùng nền phụ */
--color-text:       #1A2029;
--color-text-muted: #5B6570;
--color-border:     #D9DEE4;

/* Trạng thái nghiệp vụ ERP — BẮT BUỘC dùng đúng token, cấm tint tự chế.
   Cặp bg/fg đảm bảo contrast AA. Trạng thái tiền giữ màu riêng để nhận biết tức thì. */
--state-draft:        #EEF0F3;  --state-draft-fg:        #4B5563;  /* Nháp */
--state-pending:      #FDF0DC;  --state-pending-fg:      #8A4B08;  /* Chờ duyệt / chờ ai đó */
--state-approved:     #E2F3E7;  --state-approved-fg:     #0B5A2A;  /* Đã duyệt / khớp tiền */
--state-rejected:     #FBE5E2;  --state-rejected-fg:     #9A2015;  /* Bị từ chối */
--state-overdue:      #F6D5D1;  --state-overdue-fg:      #7A150C;  /* Quá hạn thanh toán / aging */
--state-sla-warning:  #FDF0DC;  --state-sla-warning-fg:  #8A4B08;  /* SLA ≥50% thời gian */
--state-sla-breach:   #F6D5D1;  --state-sla-breach-fg:   #7A150C;  /* SLA vỡ — vào queue ưu tiên */
--state-manual:       #E8EEF6;  --state-manual-fg:       #33547A;  /* Dữ liệu thủ công (degraded) */
--state-mismatch:     #F6D5D1;  --state-mismatch-fg:     #7A150C;  /* Mismatch đối trừ 3 số */
--state-info:         #E3EEFA;  --state-info-fg:         #12508F;  /* Thông tin trung tính */

/* ═══ WEB-ONLY ═══ */
--color-nav-rail:      #1F2933;  /* nav rail tối trái — phân biệt khung web */
--color-nav-rail-text: #C7CDD4;
--color-row-hover:     #F0F4F9;  /* hover hàng bảng */
--color-row-selected:  #E3EEFA;

/* ═══ MOBILE-ONLY ═══ */
--color-mobile-bottomnav: #FFFFFF;   /* bottom nav nền trắng, viền trên */
--color-mobile-bottomnav-active: #1E5AA8;
--color-mobile-safe-area: env(safe-area-inset-bottom);
```

Quy tắc sử dụng:

- Phân biệt trạng thái KHÔNG chỉ dựa vào màu — luôn kèm icon hoặc chữ (draft/pending/rejected có hình dạng riêng, color-blind safe).
- Màu đỏ "tiền" (mismatch, hard stop, clawback) luôn đi kèm icon khóa/ví + câu giải thích — đỏ vận hành thông thường không được dùng cho nội dung tiền.
- Badge mỗi hàng tối đa 1 trạng thái chính; trạng thái phụ đưa vào tooltip hoặc cột riêng.

---

## 2. Chữ

```css
/* SHARED */
--font-family: 'Inter', 'Be Vietnam Pro', 'Segoe UI', Roboto, sans-serif;
/* Inter + fallback Be Vietnam Pro: hỗ trợ dấu tiếng Việt đầy đủ (ầ, ệ, ỗ, ữ…),
   có tabular figures cho cột số/tiền. */

/* Kích thước — 7 cấp */
--text-xs:   12px;  /* caption, metadata, nhãn lọc — line-height 16px */
--text-sm:   13px;  /* cell bảng compact, badge — line-height 18px */
--text-base: 14px;  /* body mặc định desktop, nội dung form — line-height 20px */
--text-lg:   16px;  /* h4, nhấn mạnh trong panel — line-height 22px */
--text-xl:   20px;  /* h3, tiêu đề panel — line-height 28px */
--text-2xl:  24px;  /* h2, tiêu đề trang — line-height 32px */
--text-3xl:  28px;  /* h1, số liệu lớn dashboard — line-height 36px */

/* Độ đậm */
--font-normal: 400; --font-medium: 500; --font-semibold: 600; --font-bold: 700;

/* Số liệu */
--font-numeric: 'Inter' tabular-nums;  /* BẮT BUỘC cho mọi cột tiền/số trong bảng */
```

/* MOBILE-ONLY: body 16px trở lên cho nội dung nhập (chống zoom iOS), tiêu đề màn hình 20px. */

Quy tắc tiếng Việt:

- **Cấm `text-transform: uppercase` cho nội dung tiếng Việt** — dấu thanh bị chen lấn, khó đọc. Nhãn cần nhấn mạnh viết hoa trực tiếp tối đa 2 từ (VD: "HARD STOP") hoặc dùng `--font-semibold` + màu token.
- Tiêu đề trang/h2 dùng `--font-semibold`; không dùng bold toàn đoạn.

---

## 3. Khoảng Cách

```css
/* SHARED — lưới 8px, đơn vị gốc 4px */
--space-1: 4px;   /* trong badge, icon-text gap */
--space-2: 8px;   /* trong control, cell compact */
--space-3: 12px;  /* giữa control trong form row */
--space-4: 16px;  /* padding card, gutter lưới */
--space-6: 24px;  /* giữa section trong trang */
--space-8: 32px;  /* giữa khối lớn, margin trang */
--space-12: 48px; /* tách vùng hợp tác vs vùng đọc */
--space-16: 64px; /* khoảng thở dashboard */

/* WEB-ONLY — density 2 chế độ, user persist được */
--row-height-compact: 32px;  /* padding-y 4px — worklist, sổ phụ ví, aging, datagrid mặc định */
--row-height-comfortable: 40px; /* padding-y 8px — hồ sơ, cấu hình */
--control-sm: 28px; --control-md: 32px; /* chiều cao control trong bảng/command bar */
--table-header-h: 36px;      /* header bảng, sticky */

/* MOBILE-ONLY */
--touch-target: 44px;        /* mọi control chạm được, gồm row action */
--mobile-card-padding: 16px; /* list mobile render dạng card, không bảng */
```

Nguyên tắc density: màn hình tiền + hàng đợi = compact; màn hình nhập liệu = comfortable; dashboard = spacious. Không trộn 2 density trong cùng một bảng.

---

## 4. Thư Viện Component

12 component nghiệp vụ bắt buộc (chi tiết bên dưới) + bộ nền: **Button** (`primary/secondary/danger/ghost`), **Input**, **Select/Combobox** (search-as-you-type), **Modal** (confirm hành động tiền luôn có lý do), **Toast** (`success/error/warning/info`, lỗi tiền không tự đóng), **EmptyState**, **LoadingSkeleton**, **Pagination** (25/50/100), **Breadcrumb**.

### 4.1 DataTable / DataGrid — xương sống mọi worklist

- **Variants:** standard; compact (row 32px, dùng cho tiền/aging); có bulk-selection; có saved-views.
- **Specs:** header 36px sticky, cột trạng thái 120px, cột tiền right-align `tabular-nums`; filter bar trên đầu + quick filter chips (tháo được từng chip); column config (ẩn/hiện/rộng — persist theo user); sort theo click header; bulk bar trượt lên khi chọn ≥1 hàng.
- **States:** loading = skeleton 10 hàng; empty = EmptyState kèm CTA; error = hàng lỗi + retry; row hover `--color-row-hover`, selected `--color-row-selected`.
- **Keyboard:** ↑↓ di chuyển, Space chọn, Enter mở detail.

### 4.2 StatusBadge

- **Variants:** 10 token trạng thái §1 + variant có count (`Chờ duyệt · 7`).
- **Specs:** height 20px, padding 2px 8px, radius 4px, text `--text-xs` `--font-medium`, bg/fg theo cặp token.
- **Usage:** 1 badge/hàng; kèm icon khi trạng thái tiền (khóa, ví). Static — không click.
- **States:** chỉ default; disabled = muted. Loading hiển thị skeleton chip 48×20.

### 4.3 WarningIndicator

- **Variants:** inline (trong row); banner (đầu panel — bắt buộc cho hard stop, mismatch); field-level (form).
- **Specs:** icon 16px + text `--text-sm` + link hành động; nền cặp token warning/error/mismatch, viền trái 3px cùng màu fg.
- **Usage:** nội dung BẮT BUỘC 3 phần: chuyện gì — cần ai làm gì — hạn còn lại. Hard stop/mismatch: không dismiss, có nút "Mở approval".
- **States:** persistent / dismissible (chỉ warning vận hành); lỗi tiền không bao giờ tự biến mất khi reload.

### 4.4 Tabs

- **Variants:** page tabs (chuyển view cùng entity); panel tabs (trong SidePanel); count-tab (nhãn + số pending, dùng cho approval inbox).
- **Specs:** height 40px, indicator gạch dưới 2px `--color-primary`, active `--font-semibold`; overflow cuộn ngang, không wrap.
- **States:** default/hover (nền `--surface-alt`)/active/disabled (tooltip lý do — thường do thiếu quyền RBAC).

### 4.5 SidePanel / Drawer

- **Variants:** web — panel phải đẩy nội dung (không overlay toàn màn), rộng 480px (detail sâu: 720px); mobile — bottom sheet full-width.
- **Specs:** header có tiêu đề + trạng thái + nút đóng; footer sticky chứa action chính; nội dung cuộn độc lập.
- **Usage:** xem/sửa nhanh mà giữ context worklist; Esc đóng, focus trap, trả focus về hàng vừa mở.

### 4.6 CommandBar / Toolbar

- **Variants:** page-level (mở đầu worklist: action trái — filter/search phải); selection-context (bulk action khi chọn hàng, thay thế tạm thời).
- **Specs:** height 40px, control `--control-md`, nút chính tối đa 1; action phụ gộp "⋯".
- **States:** action không có quyền → ẩn (không disabled), đúng mô hình PEP.

### 4.7 ProgressTracker

- **Variants:** stepper ngang (quy trình nhiều tầng: Lead→Gate 1→Quote→Gate 2→Handoff→Khớp tiền→Active→Nghiệm thu→Invoice); compact chip-line (mobile, chỉ current + tổng).
- **Specs:** node 20px; mỗi stage hiển thị: trạng thái + người giữ + số ngày đang chờ (gắn WaitingOnIndicator).
- **States:** completed (`--state-approved`), current (primary), pending (neutral), blocked/rejected (`--state-rejected` + icon). Stage có quyền xem → click mở chi tiết.

### 4.8 Timeline / ActivityFeed

- **Variants:** full (tab lịch sử); inline (3 sự kiện cuối trong SidePanel).
- **Specs:** mỗi entry: avatar actor + hành động + thời gian tuyệt đối (dd/MM HH:mm) + liên kết object; sự kiện ký handoff / dual approval hiển thị chữ ký + vai; event hệ thống (sync platform, degraded manual) icon riêng.
- **States:** loading skeleton 3 dòng; empty = "Chưa có hoạt động".

### 4.9 AssigneePicker

- **Variants:** single (gán ticket); multi (đội xử lý); queue (gán nhóm — dùng khi không chắc cá nhân).
- **Specs:** combobox search-as-you-type, lọc theo dept/role trong data-scope của người gán (RBAC — không gán ngoài scope); option: avatar + tên + dept; giá trị đã chọn hiển thị avatar + tooltip.
- **States:** loading, no-result (gợi ý đổi phạm vi), disabled với lý do.

### 4.10 ApprovalCard

- **Variants:** standard; dual-approval (hiện 2 slot: "FIN_L1 ✓ 10:32 · FIN_L2 đang chờ"); step-up MFA (badge "yêu cầu MFA" — lệnh tiền, khóa kỳ, vault).
- **Specs:** bắt buộc chứa: tóm tắt object + link, số tiền `MoneyDisplay` + chênh lệch so định mức (%), SLA còn lại, 2 nút **Duyệt** (primary) / **Từ chối** (outline `--color-error`). Từ chối: bắt buộc nhập lý do (≥10 ký tự). Dual: nút Duyệt của người thứ 2 khóa cho đến khi đủ slot trước — hiển thị rõ đang chờ ai.
- **States:** idle/hover/processing (spinner + khóa nút — chống double-submit)/done (collapse vào feed); sau duyệt tiền → bước MFA step-up modal.
- **Keyboard trong inbox:** ↑↓ chuyển card, **A** duyệt, **R** từ chối, Enter mở context.

### 4.11 WaitingOnIndicator

- **Variants:** chip trong row; khối trong header detail; tooltip mở rộng.
- **Specs:** avatar + tên người giữ + duration ("chờ 2 ngày 4 giờ"); màu theo ngưỡng SLA: neutral → `--state-sla-warning` (≥50%) → `--state-sla-breach` (vỡ, kèm icon chuông). Luôn kèm text — không chỉ màu.
- **States:** chờ người (click → modal nhắc/nhắn); chờ hệ thống (icon gear + mã sync); chờ client (icon ngoài — không nhấn nhá, dùng cho aging công nợ).

### 4.12 MoneyDisplay

- **Variants:** plain (VND); multi-currency (nguồn USD + quy đổi VND + tỷ giá + ngày áp tỷ giá — điều chỉnh tỷ giá luôn gắn nhãn dual approval); delta (±% so định mức, dấu +/- màu success/error); aging (số ngày quá hạn + bucket 30/60/90).
- **Specs:** format VND `1.234.567 ₫` (dấu chấm nghìn, không thập phân); `tabular-nums`, right-align trong bảng; số đủ chính xác trong tooltip khi hiển thị rút gọn ("1,2 tr").
- **Usage:** mọi con số tiền dùng component này — cấm format thủ công; hard stop hiển thị 3 số đối trừ cạnh nhau (portal vs bank vs ledger) với mismatch tô `--state-mismatch`.

---

## 5. Bố Cục Trang

**Grid & breakpoints (web):** lưới 12 cột, gutter 16px, margin trang 24px. Container: worklist/approval = full-width (max 1920px, ưu tiên ngang); dashboard max 1600px center; form max 960px.

| Breakpoint         | Bố cục                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------- |
| Desktop ≥1280px   | Kinh nghiệm chính: nav rail + đầy đủ cột + SidePanel                                 |
| Tablet 768–1279px | nav rail thu icon, bảng ẩn cột phụ (giữ cột tiền/trạng thái), SidePanel → overlay |
| Mobile <768px      | bottom nav, list → card, bảng data-heavy KHÔNG render (báo "xem trên web")             |

**Khung ứng dụng web:**

```
┌──────┬────────────────────────────────────────────┐
│ Nav  │ Topbar: tìm kiếm toàn cục · thông báo · user│
│ rail ├────────────────────────────────────────────┤
│ (60px│ Breadcrumb · Tiêu đề trang      [Action]    │
│ tối) │ CommandBar ─────────────────────────────── │
│      │ Content (grid 12 cột)                       │
└──────┴────────────────────────────────────────────┘
```

**Pattern W1 — Worklist / Approval inbox (màn hình mặc định, dùng cho 9 module OPS + FIN + HR duyệt):**

```
CommandBar: [+ Thêm] [Lưu views ▾]        [Tìm nhanh] [Bộ lọc ▾]
Quick chips: (Chờ tôi · 7 ×) (SLA đỏ · 2 ×) (Hôm nay ×)
─────────────────────────────────────────────
DataTable compact | cột: object · tiền · StatusBadge · WaitingOn · SLA
Bulk bar (khi chọn): [Đã chọn 3] [Duyệt hàng loạt] [Gán…]
─────────────────────────────────────────────
Pagination 25/50/100
```

**Pattern W2 — Split view (master-detail):** danh sách 40% trái + detail 60% phải (ticket, hồ sơ nhân viên, lệnh tiền). Chọn hàng không rời trang — Ops Conductor giảm context-switch.

**Pattern W3 — Detail + side context panel:** content giữa + panel phải 360px cố định chứa: WaitingOn hiện tại, ProgressTracker rút gọn, Timeline 3 sự kiện cuối, object liên quan. Dùng cho mọi trang detail deal/campaign/wallet.

**Pattern W4 — Dashboard operational:** hàng KPI (4 ô số lớn + delta) → widget 12 cột (bảng top aging, queue SLA đỏ, biểu đồ dòng tiền). Widget chỉ tồn tại nếu dẫn tới hành động (click → worklist đã lọc). Không trang trí, không card lồng card.

---

## 6. Quy Ước Giao Diện

**Naming:** tokens `--{nhóm}-{tên}-{biến-thể}`; components PascalCase; CSS class `bcerp-{component}` kebab; props boolean `isX/hasX`. Icon theo tiền tố `action-`, `status-`, `nav-`, `ui-`.

**Icon library:** Lucide — SVG inline, stroke 1.5, kích thước 12/16/20/24px, màu từ `currentColor`. Bộ icon nghiệp vụ bắt buộc: `gate` (cổng duyệt), `signature` (bàn giao có ký), `lock-money` (hard stop), `wallet`, `clock-sla`, `undo-clawback`, `file-manual` (dữ liệu thủ công), `shield-mfa`. Icon hành động quan trọng luôn + label hoặc `aria-label`.

**Animation/transition:** 100–200ms ease-out, chỉ `opacity` + `transform`; panel trượt 200ms. CẤM animation cho sort/filter/phân trang bảng (kết quả tức thời); skeleton shimmer cho trạng thái tải; tôn trọng `prefers-reduced-motion`. Không hiệu ứng khi duyệt tiền — phản hồi là cập nhật state + toast.

**Quy ước status/exception — khi nào dùng gì:**

- **StatusBadge** = trạng thái tĩnh của object, luôn hiển thị trong mọi list.
- **WarningIndicator** = exception cần ai hành động, kèm hướng dẫn — xuất hiện khi có exception, không dùng để trang trí.
- **Queue (worklist entry)** = mọi thứ cần tôi xử lý; SLA breach tự nhảy đầu queue + gắn `--state-sla-breach`.
- Hard stop, mismatch, clawback: LUÔN banner (WarningIndicator) + entry queue FIN — không bao giờ chỉ là badge. Degraded manual mode: badge `--state-manual` "Dữ liệu thủ công" hiển thị vĩnh viễn trên record + dòng trong audit.

**Density:** mặc định compact cho module tiền/vận hành; chỉ form và hồ sơ dùng comfortable; toggle density per-user trong Settings, persist.

**Design language:** modern enterprise, desktop-first productivity (Fluent-inspired, không copy): bề mặt phẳng, viền 1px `--color-border`, radius 4px (card 8px), shadow tối đa 2 lớp nhẹ, nav rail tối làm landmark. **Tránh:** gradient trang trí, illustration trong worklist, card-everything (dùng bảng + panel), nút màu mè theo sở thích, animation lặp, hero banner. Nút Duyệt luôn `--color-primary` (không xanh lá) để tránh phản xạ bấm; hành động tiền thêm bước xác nhận có ngữ cảnh, không confirm-empty.

---

## 7. Thiết Kế Mobile

Áp dụng cho 2 app: **ESS (nhân viên nội bộ)** và **Client Portal mobile** — chỉ tác vụ giao dịch ngắn, 1 màn hình là xong.

| Thuộc tính      | Giá trị                                                                                               |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| Touch target      | ≥44×44px, gap 8px giữa action                                                                        |
| Bottom navigation | Tối đa 5 mục (ESS: Chấm công · Nghỉ phép · Timesheet · Thông báo · Tôi)                   |
| Gesture           | Pull-to-refresh, swipe action trên card (duyệt/từ chối nghỉ phép) — không gesture ẩn cho tiền |
| Safe area         | Respect notch/home indicator (`--color-mobile-safe-area`)                                             |
| Form              | 1 cột, body ≥16px, bàn phím đúng kiểu (số cho tiền, date cho ngày)                            |

Ràng buộc nghiệp vụ: **vault management & cấu hình credential CẤM trên mobile** (kiến trúc từ chối tầng gateway) — app ẩn hẳn tính năng, không hiển thị disabled. MFA step-up cho lệnh tiền vẫn bắt buộc trên mobile nếu nghiệp vụ cho phép duyệt. Bảng data-heavy (sổ phụ ví, aging, datagrid 14 module) KHÔNG cần parity — hiển thị trạng thái tóm tắt + CTA "Mở trên web". Badge "Dữ liệu thủ công" hiển thị cả mobile.

---

## 8. Accessibility

```
Tiêu chuẩn: WCAG 2.1 Level AA

- Contrast: text ≥ 4.5:1, text lớn/icon ≥ 3:1 — cặp token bg/fg §1 đã kiểm chứng.
- Color-blind safe: SLA và trạng thái = màu + icon + text (không bao giờ màu đơn thuần);
  đỏ tiền có icon khóa/ví; validated với mô phỏng deuteranopia.
- Keyboard: worklist + approval inbox điều khiển đầy đủ bàn phím
  (↑↓ điều hướng, Space chọn, Enter mở, A duyệt, R từ chối, Esc đóng panel,
  Tab tuần tự hợp lý, focus trap trong Modal/SidePanel, focus luôn visible 2px).
- Screen reader: aria-label cho icon action; StatusBadge phát hành text đầy đủ
  ("Chờ FIN_L2 duyệt 2 ngày"); ProgressTracker có aria-current.
- Tiếng Việt: font đủ dấu (§2), không uppercase CSS, không cắt chữ bằng
  line-clamp trong trường tiền/trạng thái.
- Touch (mobile): ≥44px, spacing đủ tránh nhầm nút Duyệt/Từ chối.
```

---

## 8.1. Bổ sung từ Accessibility Audit (Phase 4.8 — ràng buộc bắt buộc mọi screen spec)

| #  | Quy tắc                             | Chi tiết                                                                                                                                                                        |
| -- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1 | Character Key Shortcuts (WCAG 2.1.4) | Phím tắt đơn ký tự (A/R/?) bind ở mức container component, tự vô hiệu khi focus trong input/textarea/contenteditable; phải có toggle bật/tắt trong Settings       |
| A2 | Tabs ARIA                            | `role=tablist/tab/tabpanel`, điều hướng ←→, `aria-selected`, focus về heading panel khi chuyển tab                                                                   |
| A3 | DataGrid table semantics             | `caption`, `th scope`, `aria-sort` khi sort, phím Home/End/PageUp/PageDown; bảng dữ liệu thay thế cho mọi chart (`role="img"` + `aria-label`)                    |
| A4 | Skip-link + landmarks                | Link "Tới nội dung chính" đầu trang; landmark`nav/main/complementary` cho nav rail + side panel                                                                           |
| A5 | Form error pattern                   | Nút submit luôn enable + validate on submit (không dùng disabled-only); lỗi gắn`aria-describedby` + focus lỗi đầu tiên; bộ đếm ký tự `aria-live="polite"`     |
| A6 | Gestures (2.5.1)                     | Mọi swipe action phải có nút bấm tương đương hiển thị (VD: duyệt nhanh mobile có sticky footer buttons)                                                            |
| A7 | Viền control                        | Thêm token`--color-border-control: #8A94A0` (≥3:1 trên nền trắng) cho viền input/control — `--color-border` chỉ dùng viền trang trí                               |
| A8 | Ngôn ngữ                           | `lang="vi"` ở html root; toast `aria-live`; SLA countdown `aria-hidden` (giá trị đã có ở text kèm theo); icon-only button có `aria-label` theo ngữ cảnh hàng |
