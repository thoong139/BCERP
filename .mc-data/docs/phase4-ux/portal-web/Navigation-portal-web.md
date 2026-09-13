# Navigation: Client Portal Web

> **System ID:** SYS-PORTAL-WEB
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `workflow-context.md §2.0.3–§2.0.5` (P1–P4, shared objects, consolidation), `phase2-features/portal-web/**/*.md` (CPORT-001/002), `phase3-architecture/P3-01-architecture.md`
> USED BY: `portal/[screen-group].md`

> **Nguyên tắc điều hướng:** portal **bên ngoài, client-facing, read-heavy, trust boundary riêng** — tối giản tuyệt đối. Chỉ hiển thị dữ liệu của tổ chức khách đang đăng nhập. Không có menu quản trị; thao tác ghi chỉ có 2: tạo ticket (P4) và tải invoice (P3).

---

## 1. Sơ Đồ Menu (Menu Tree)

```
Client Portal — /portal/*   (4 mục top-level, KHÔNG admin)
├── 🏠 Trang chủ                          → /portal             → portal/portal-home.md
│   └── Ví chi tiết (drill-down)          → view trong P1       → không route riêng
├── 📣 Campaign của tôi                   → /portal/campaigns   → portal/campaign-tracking.md
│   └── Chi tiết campaign + deliverable   → view trong P2       → không route riêng
├── 🧾 Hóa đơn & Thanh toán               → /portal/invoices    → portal/billing.md
│   └── Chi tiết hóa đơn                  → view trong P3       → không route riêng
└── 🎧 Hỗ trợ                             → /portal/tickets     → portal/tickets.md
    └── Chi tiết ticket                   → view trong P4       → không route riêng
```

Ghi chú:

- Mọi chi tiết/drill-down là **view mode trong cùng screen group** (master-detail, panel mở rộng) — portal không có route sâu hơn 1 cấp, đúng quyết định consolidation §2.0.5: *"P1–P4 KEEP; Ví chi tiết = drill-down từ P1 (không page riêng)"*.
- Không có mục: cấu hình, quản trị người dùng, báo cáo nội bộ, dữ liệu khách khác. Số dư ví chỉ **read-only** (trạng thái đối trừ 3 số, khóa kỳ thuộc nội bộ — không hiển thị).

---

## 2. Danh Sách Screen Groups

| Screen Group                           | Route                 | File                                           | UI-ID                | Module (FEAT)       |
| -------------------------------------- | --------------------- | ---------------------------------------------- | -------------------- | ------------------- |
| P1 — Portal Home                      | `/portal`           | `client-portal/screens-portal-home.md`       | `UI-PWEB-HOME-001` | CPORT-001           |
| P2 — Campaign theo dõi (client view) | `/portal/campaigns` | `client-portal/screens-campaign-tracking.md` | `UI-PWEB-CAMP-001` | CPORT-001, CAMP-002 |
| P3 — Billing / Invoices               | `/portal/invoices`  | `client-portal/screens-billing.md`           | `UI-PWEB-INV-001`  | CPORT-002, ARAP-001 |
| P4 — Ticket (client)                  | `/portal/tickets`   | `client-portal/screens-tickets.md`           | `UI-PWEB-TCKT-001` | CPORT-001, CSKH-001 |

**Screen Group = Main page + Tabs + Dialogs + Sheets + View modes.** Tổng: **đúng 4 surfaces** theo inventory §2.0.3 — không thêm screen nào ngoài inventory (thiếu gì → `[NEEDS_REVIEW]`).

### Cơ Sở Giữ Lại Màn Hình

| Màn hình            | Ai dùng                              | Làm gì                                                                                                         | Tần suất                    | Quyết định gì                                                                 | Vì sao surface riêng                                                                                                               |
| --------------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| P1 Portal Home        | Mọi client account                   | Xem số dư ví read-only (drill-down Ví chi tiết), campaign đang chạy, ticket đang mở, invoice gần nhất | Hằng ngày → hằng tuần    | "Còn bao nhiêu tiền, việc đang tới đâu, có hóa đơn phải trả không" | Điểm vào duy nhất hợp nhất 4 luồng — client không phải học cấu trúc nội bộ; ví để drill-down vì chỉ tra khi cần |
| P2 Campaign theo dõi | Client theo dõi tiến độ dịch vụ | Xem trạng thái campaign + deliverable đã nghiệm thu                                                         | Theo tuần / theo đợt chạy | Đánh giá tiến độ, chuẩn bị nghiệm thu phía khách                       | Cùng nguồn CAMP-002 nhưng chỉ client-scoped; tách khỏi S14 nội bộ vì trust boundary + ngôn ngữ hiển thị khác           |
| P3 Billing / Invoices | Bộ phận kế toán của khách       | Xem + tải invoice, xem lịch thanh toán                                                                        | Theo kỳ / tháng             | Chuẩn bị thanh toán, đối chiếu sổ                                          | Invoice có 2 audiences (§2.0.4): nội bộ ở S10 tab AR, external ở P3 — khác trust boundary → 2 surfaces hợp lệ             |
| P4 Ticket (client)    | Bất kỳ user của khách             | Tạo ticket + theo dõi tiến trình xử lý                                                                     | Theo nhu cầu (không đều)  | "Vấn đề của tôi xử lý đến đâu, có cần bổ sung gì"                  | Hành động ghi DUY NHẤT của portal; nội bộ ở S16 khác trust boundary → 2 surfaces                                           |

---

## 3. Phân Quyền & Hiển Thị Menu

> **Khác căn bản với hệ nội bộ (BCERP-WEB — ma trận 19 vai RBAC):** portal **không có ma trận vai nội bộ**. Quyền hiển thị gồm 3 tầng:

1. **Per-client authentication + scoping:** mỗi account gắn với đúng 1 tổ chức khách; mọi query bắt buộc lọc theo tổ chức đó. Hai account khác tổ chức không bao giờ thấy dữ liệu của nhau dù cùng route.
2. **Trạng thái account (active/suspended):** do OPS kiểm soát trên hệ nội bộ qua **S19 Portal Accounts (BCERP-WEB)**. `suspended` → full-page chặn "Tài khoản tạm khóa — vui lòng liên hệ nhân viên phụ trách", toàn bộ menu không render.
3. **Tier / gói dịch vụ:** quyết định khối dữ liệu mở rộng **trên cùng surface** (không đổi menu, không thêm mục). `[NEEDS_REVIEW: mapping tier → khối hiển thị chưa định nghĩa trong inventory — cần xác nhận từ business-context §3]`.

| Menu Item                | Route                 | Ai thấy            | Badge                  | Hiện khi nào                             |
| ------------------------ | --------------------- | ------------------- | ---------------------- | ------------------------------------------ |
| Trang chủ               | `/portal`           | Mọi account active | —                     | Luôn                                      |
| Campaign của tôi       | `/portal/campaigns` | Mọi account active | `{đang chạy}`      | Luôn; khối báo cáo chi tiết theo tier |
| Hóa đơn & Thanh toán | `/portal/invoices`  | Mọi account active | `{chờ thanh toán}` | Luôn                                      |
| Hỗ trợ                 | `/portal/tickets`   | Mọi account active | `{đang mở}`        | Luôn                                      |

Không có hàng nào cần quyền "Admin" — portal không có khái niệm này; account client không phân vai.

---

## 4. UI Notes

### 4.1. Quick Actions (giới hạn có chủ ý)

| Action              | Icon         | Mở gì                     | Ghi chú                               |
| ------------------- | ------------ | --------------------------- | -------------------------------------- |
| Tạo ticket         | `ticket`   | Dialog tạo ticket (P4)     | Quick action GHI duy nhất của portal |
| Tải hóa đơn PDF | `download` | File PDF invoice (trong P3) | Contextual — không nằm topbar       |

Không có: command palette, "Ctrl+N tạo mới đa ngữ cảnh", quick action quản trị. Tìm kiếm chỉ quét trong dữ liệu của tổ chức mình (campaign/invoice/ticket).

### 4.2. Breadcrumb Pattern — tối đa 2 cấp

```
[Mục menu] › [Tên cụ thể]
Trang chủ › Ví chi tiết
Campaign của tôi › [Tên campaign]
Hóa đơn & Thanh toán › INV-2026-0114
Hỗ trợ › #TCK-1042
```

### 4.3. Quy Ước Đặt Tên File

| Loại màn hình       | Filename                                                     | Route pattern                            |
| ---------------------- | ------------------------------------------------------------ | ---------------------------------------- |
| Trang chủ             | `portal-home.md`                                           | `/portal`                              |
| Danh sách / theo dõi | `campaign-tracking.md` · `billing.md` · `tickets.md` | `/portal/{campaigns\|invoices\|tickets}` |
| Chi tiết / drill-down | không có file riêng — view mode trong screen group       | không route riêng                      |

### 4.4. Icon Library

> Validation: dùng Lucide theo `design-system.md §6`; icon `wallet` thuộc bộ icon nghiệp vụ bắt buộc.

| Menu                     | Icon          |
| ------------------------ | ------------- |
| Trang chủ               | `home`      |
| Campaign của tôi       | `megaphone` |
| Hóa đơn & Thanh toán | `file-text` |
| Hỗ trợ                 | `ticket`    |
| Ví (drill-down)         | `wallet`    |
| Tải file                | `download`  |

### 4.5. Quy Ước Client-Facing (bắt buộc)

- **Không lộ dữ liệu nội bộ:** cấm hiển thị ghi chú nội bộ, tên nhân sự xử lý (chỉ "đội ngũ BCERP"), trạng thái machine thô, khớp tiền / hard stop / mismatch / khóa kỳ, SLA tier nội bộ.
- **Map trạng thái nội bộ → ngôn ngữ client:** CAMP `planned/in_flight/delivered/reported` → *Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo*; Ticket `open/assigned/in_progress/resolved/closed` → *Đã tiếp nhận · Đang xử lý · Đã xử lý — chờ bạn xác nhận · Đã đóng*; Invoice → *Chờ thanh toán · Đã thanh toán · Quá hạn*.
- **WaitingOnIndicator phiên client** (variant "chờ client" §4.11 design-system): nội bộ *"chờ FIN_L2 duyệt 2 ngày"* → client *"Chúng tôi đang xử lý — hoàn tất dự kiến 15/09"*; chờ phía khách: *"Đang chờ phản hồi từ bạn — vui lòng trả lời trước 18/09"* (icon ngoài, không nhấn nhá).
- Tái sử dụng **MoneyDisplay** (VND `tabular-nums`) + **StatusBadge**; số dư ví kèm nhãn *"Số liệu đã đối soát"* — tránh client tự đối chiếu.
- Density **comfortable** (đọc, không phải worklist nội bộ); WCAG 2.1 AA; cấm `text-transform: uppercase` cho tiếng Việt.

---

### 4.5. Bố Cục & Responsive (ux-architect)

#### Kiến trúc CSS

CÙNG codebase, chung `tokens.css`, app shell + entry bundle/deploy artifact RIÊNG cho portal (trust boundary external phản ánh vào kiến trúc; token không bao giờ lệch). Naming chốt prefix `bcportal-*` giữ ngữ pháp BEM (review bảo mật nhận diện được class external trong DOM; tránh collision), token giữ tên gốc vì shared. Thêm 2 token: `--portal-container-max: 1200px`, `--portal-topnav-h: 56px`.

#### Layout

Top nav 56px KHÔNG nav rail; mobile <768px chuyển bottom nav (4 mục + Tôi, dùng token `--color-mobile-bottomnav-*` + safe-area); container 1200px center; density COMFORTABLE toàn portal (`--row-height-comfortable`, không compact); portal KHÔNG áp quy tắc nội bộ "bảng không render trên mobile" — tablet giữ bảng, mobile render card 44px touch target.

#### Component boundaries

- **P1 Home** = W4 rút gọn read-only, 4 summary card + drill-down ví qua SidePanel 480px/bottom sheet.
- **P2 Campaign** = W3 đơn giản (ProgressTracker stepper + Timeline full).
- **P3 Invoices** = W1 lột bỏ (DataTable comfortable + MoneyDisplay, PDF trong SidePanel 720px).
- **P4 Tickets** = W2 split view 40/60, mobile full-screen thread.

Không hero/gradient/illustration — enterprise language, thân thiện bằng whitespace + EmptyState.

#### Bảo mật UI

`no-store` mọi API + cấm localStorage dữ liệu nhạy cảm + vô hiệu bfcache; mask tài khoản `****1234` cần re-auth/MFA để hiện, ví có toggle ẩn; session idle 30 phút, cảnh báo trước 2 phút bằng modal đếm ngược, hết hạn đăng nhập lại quay đúng surface không redirect đột ngột.

## Tài Liệu Liên Quan

| Nội dung                               | File                                                             |
| --------------------------------------- | ---------------------------------------------------------------- |
| Thiết kế chi tiết màn hình         | `portal/[screen-group].md`                                     |
| API endpoints                           | `../../phase3-architecture/technical-specs/api-contract.md`    |
| Tích hợp & quy tắc xuyên hệ thống | `../../phase3-architecture/technical-specs/integration-map.md` |
| Design system                           | `../design-system.md`                                          |
| REQ-IDs                                 | `../../_meta/req-registry.json`                                |
