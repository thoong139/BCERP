# Navigation: Mobile App — BC Portal (Client)

> **System ID:** SYS-MOBILE-PORTAL
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `workflow-context.md §2.0.3–§2.0.5`, `portal-web/Navigation-portal-web.md` (đối tác cùng dữ liệu), `phase2-features/mobile-portal/**/*.md` (FEAT-MPO-*)
> USED BY: `[mod]/[screen-group].md`

> **Nguyên tắc điều hướng:** mirror 1:1 của portal web — cùng audience, cùng dữ liệu, trust boundary external, UI mobile. Chỉ đọc + 2 thao tác ghi (tạo ticket, tải invoice); tác vụ sâu → CTA "Mở trên web".

---

## 1. Sơ Đồ Menu (Menu Tree)

```
BC Portal Mobile — bottom tab bar 5 mục (tối đa 5 theo design-system §7)
├── 🏠 Trang chủ      → /home        → portal-home.md        (mirror P1)
│   └── Ví chi tiết   → view trong group → không route riêng (drill-down, như web)
├── 📣 Campaign       → /campaigns   → campaign-tracking.md  (mirror P2)
│   └── Chi tiết campaign + deliverable → view full-screen trong group
├── 🧾 Hóa đơn        → /invoices    → billing.md            (mirror P3)
│   └── Chi tiết hóa đơn + tải PDF → view trong group
├── 🎧 Hỗ trợ         → /tickets     → tickets.md            (mirror P4)
│   └── Chi tiết ticket (thread) → view full-screen trong group
└── 👤 Tôi            → /me          → account.md            (account shell)
    ├── Thông tin tài khoản & tổ chức (read-only)
    ├── Bảo mật: mở số dư đang ẩn (re-auth), thiết bị nhận push, đăng xuất
    └── Ngôn ngữ · "Mở trên web"
```

Ghi chú:
- Chi tiết/drill-down là **view mode trong cùng screen group** (consolidation §2.0.5) — mobile không tạo route group mới.
- Tab "Tôi" không phải surface dữ liệu mới: đã quy định trong portal-web §4.5 ("4 mục + Tôi") — chỉ chứa tài khoản + bảo mật phiên.
- Push deep-link thẳng vào view chi tiết (§4.3).

---

## 2. Danh Sách Screen Groups

| Screen Group | Route | File | UI-ID | Module (FEAT-MPO) |
|-------------|-------|------|-------|-------------------|
| MPO-01 — Trang chủ (mirror P1) | `/home` | `client-portal/screens-portal-home.md` | `UI-MPO-HOME-001` | CPORT-001, WALLET-001, SLANOT-001 |
| MPO-02 — Campaign theo dõi (mirror P2) | `/campaigns` | `client-portal/screens-campaign-tracking.md` | `UI-MPO-CAMP-001` | CAMP-001 |
| MPO-03 — Hóa đơn (mirror P3) | `/invoices` | `client-portal/screens-billing.md` | `UI-MPO-INV-001` | CPORT-001 `[NEEDS_REVIEW: a]` |
| MPO-04 — Hỗ trợ / Ticket (mirror P4) | `/tickets` | `client-portal/screens-tickets.md` | `UI-MPO-TCKT-001` | CSKH-001, SLANOT-001 |
| MPO-05 — Tôi (account shell) | `/me` | `client-portal/screens-account.md` | `UI-MPO-ACC-001` | CPORT-001 |

`[a]` Registry mobile-portal không có feature riêng view hóa đơn (web P3 dùng CPORT-002 + ARAP-001). Giữ MPO-03 theo inventory §2.0.3 (P1–P4 dùng chung SYS-PORTAL-WEB + SYS-MOBILE-PORTAL) — xác nhận FEAT ở Phase 3 check 4.1.

**Screen Group = Main view + tabs + dialogs + bottom sheets + view modes.** Cả 5 FEAT-MPO-* (CAMP-001, CPORT-001, SLANOT-001, CSKH-001, WALLET-001) nằm gọn trong các nhóm trên — không feature nào vượt 4 nhóm mirror.

### Cơ Sở Giữ Lại Màn Hình

| Màn hình | Client làm gì trên mobile | Tần suất | Vì sao client cần trên mobile |
|----------|--------------------------|----------|-------------------------------|
| MPO-01 Trang chủ | Liếc nhanh: ví read-only (drill-down), campaign đang chạy, ticket đang mở, invoice gần nhất; đích hạ cánh của push | Hằng ngày | Glanceable — trả lời "còn bao nhiêu tiền, việc tới đâu" không cần mở máy tính |
| MPO-02 Campaign | Xem trạng thái campaign + deliverable đã nghiệm thu (stepper rút gọn + timeline) | Theo tuần / khi có push | Tiến độ đổi lúc khách không ngồi máy; push "campaign cập nhật" đưa thẳng tới đúng campaign |
| MPO-03 Hóa đơn | Xem hóa đơn mới, tải PDF để chuyển tiếp, xem hạn thanh toán | Theo kỳ / khi có push | Hóa đơn phát hành cả ngoài giờ hành chính; chi tiết đối chiếu để "Mở trên web" |
| MPO-04 Hỗ trợ | Tạo ticket, đọc phản hồi, trả lời ngắn, theo dõi tiến trình | Theo nhu cầu | Phản hồi ticket đến dưới dạng push — khách trả lời ngay nơi nhận, vòng xử lý không đứt quãng |
| MPO-05 Tôi | Xem tài khoản/tổ chức, re-auth mở số dư ẩn, quản lý thiết bị nhận push, đăng xuất | Thỉnh thoảng | Điểm lắp bảo mật phiên (mask/re-auth, thu hồi push) tập trung một nơi |

---

## 3. Phân Quyền & Hiển Thị Menu

> Giống portal web: **không RBAC 19 vai**, account client không phân vai. Quyền hiển thị 3 tầng:

1. **Per-client scoping:** mỗi account gắn đúng 1 tổ chức; mọi query lọc theo tổ chức — khác tổ chức không bao giờ thấy dữ liệu nhau dù cùng deep-link.
2. **Trạng thái account (active/suspended):** OPS kiểm soát qua S19 Portal Accounts (BCERP-WEB). `suspended` → full-page chặn "Tài khoản tạm khóa — vui lòng liên hệ nhân viên phụ trách", cả 5 tab không render; push token thu hồi cùng phiên.
3. **Tier dịch vụ:** mở rộng khối dữ liệu trên cùng tab (không đổi menu, không thêm mục). `[NEEDS_REVIEW: mapping tier → khối hiển thị chưa định nghĩa — đồng bộ portal-web §3]`.

| Tab | Route | Ai thấy | Badge trên icon | Hiện khi nào |
|-----|-------|---------|-----------------|--------------|
| Trang chủ | `/home` | Mọi account active | — | Luôn |
| Campaign | `/campaigns` | Mọi account active | `{đang chạy}` | Luôn; khối báo cáo chi tiết theo tier |
| Hóa đơn | `/invoices` | Mọi account active | `{chờ thanh toán}` | Luôn |
| Hỗ trợ | `/tickets` | Mọi account active | `{đang mở}` (tối đa 9+) | Luôn |
| Tôi | `/me` | Mọi account active | — | Luôn |

---

## 4. UI Notes

### 4.1. Touch & bố cục mobile

- Touch target ≥44×44px (`--touch-target`), gap 8px — gồm cả row action; bottom nav dùng `--color-mobile-bottomnav-*` + safe-area (notch/home indicator).
- List render card 16px, không bảng; bảng data-heavy (sổ phụ, aging) không parity — tóm tắt + CTA "Mở trên web" (design-system §7).
- Density comfortable toàn app; body ≥16px; pull-to-refresh; không gesture ẩn cho nội dung tiền.

### 4.2. Session & bảo mật (mirror portal-web §4.5)

- `no-store` mọi API; cấm lưu dữ liệu nhạy cảm trong localStorage/webview cache.
- Idle 30 phút — modal đếm ngược cảnh báo trước 2 phút; hết hạn → đăng nhập lại rồi quay đúng surface đang mở, không redirect đột ngột.
- Mask tài khoản `****1234` cần re-auth/MFA để hiện; số dư ví có toggle ẩn; MoneyDisplay VND `tabular-nums` kèm nhãn "Số liệu đã đối soát".
- Push token gắn phiên: đăng xuất / suspended / hết hạn → thu hồi, ngừng push.

### 4.3. Push notification → surface mapping (SLANOT-001)

| Sự kiện | Nội dung đẩy (không lộ số liệu trên lock screen) | Deep-link tới |
|---------|--------------------------------------------------|---------------|
| Campaign cập nhật | "Campaign [tên] vừa cập nhật tiến độ" | `/campaigns` → view chi tiết campaign |
| Ticket phản hồi | "Đội ngũ BCERP đã phản hồi ticket #[mã]" | `/tickets` → view thread ticket |
| Invoice mới | "Bạn có hóa đơn mới chờ thanh toán" | `/invoices` → view chi tiết invoice |

Tap push khi chưa đăng nhập / hết hạn phiên → đăng nhập lại rồi vào đúng đích; số tiền chỉ hiển thị sau khi đã auth trong app.

### 4.4. Quy ước client-facing

- **Không lộ dữ liệu nội bộ:** ghi chú nội bộ, tên nhân sự xử lý (chỉ "đội ngũ BCERP"), khớp tiền / hard stop / khóa kỳ, SLA tier nội bộ, trạng thái machine thô.
- **Map trạng thái như portal web §4.5:** Campaign → *Chuẩn bị · Đang thực hiện · Đã bàn giao · Đã báo cáo*; Ticket → *Đã tiếp nhận · Đang xử lý · Đã xử lý — chờ bạn xác nhận · Đã đóng*; Invoice → *Chờ thanh toán · Đã thanh toán · Quá hạn*. WaitingOnIndicator phiên client ("Đang chờ phản hồi từ bạn — …").
- WCAG 2.1 AA; cấm `text-transform: uppercase` cho tiếng Việt; trạng thái luôn = màu + icon + chữ.

### 4.5. Icon (Lucide — design-system §6)

| Điểm dùng | Icon |
|-----------|------|
| Tab Trang chủ | `home` |
| Tab Campaign | `megaphone` |
| Tab Hóa đơn | `file-text` |
| Tab Hỗ trợ | `ticket` |
| Tab Tôi | `user` |
| Ví (drill-down) | `wallet` |
| Tải PDF | `download` |
| Quay lại (view chi tiết) | `chevron-left` |

---

### 4.5. Bố Cục & Responsive (ux-architect)

#### CSS namespace — chốt `bcportal-m-*`

Không dùng chung `bcportal-*` với portal web. Mobile portal là bundle PWA riêng, layout khác về bản chất (bottom tab vs top nav, card vs bảng); chung namespace sẽ buộc dual-layout theo media query trên hai codebase không chia sẻ code. Tiền tố giữ gốc `bcportal` (tách khỏi namespace app ESS nội bộ) để báo hiệu cùng family dữ liệu + cùng trust boundary external với portal web; `-m` đánh dấu tầng layout mobile. Khối class: `bcportal-m-shell` (khung app: tabbar 56px + safe-area), `-view` (màn stack), `-card`, `-sheet`, `-money`, `-tabbar`. Tokens dùng đúng design-system §1/§7 (mobile-only: `--touch-target`, `--mobile-card-padding`, `--color-mobile-*`), không tự chế.

#### Khác biệt so ESS (nhận nền, trừ đi)

- **Giữ từ ESS:** bottom tab 56px + safe-area, stack navigation (view chi tiết trong cùng screen group, không route mới), touch ≥44px, card 1 cột padding 16px, form ticket 1 màn hình.
- **Bỏ offline-draft:** client chỉ đọc + 2 thao tác ghi (tạo ticket, tải invoice), cả hai bắt buộc online. Không service worker cache dữ liệu (khớp bảo mật §4), không draft queue. Mất mạng → banner "Cần kết nối mạng để gửi ticket", composer khóa; phần đọc hiển thị skeleton + retry, không phục vụ từ cache.
- **Bỏ geolocation:** không xin quyền vị trí — khác ESS chấm công GPS; không khai báo permission location trong manifest.

#### Tiền trên mobile — pattern `MoneyDisplay + PrivacyShield`

- MoneyDisplay (design-system §4) bọc trong `bcportal-m-money`: `tabular-nums`, format VND `1.234.567 ₫`, không format thủ công.
- **Mask mặc định:** số dư render `••••• ₫` bằng thay ký tự trong DOM (CẤM `filter: blur()` — text vẫn đọc/screenshot được). Tap → bottom-sheet `bcportal-m-sheet-auth` re-auth/MFA → reveal; tự re-mask sau 60s hoặc khi app xuống background.
- **PrivacyShield:** overlay full-screen (logo + "Ứng dụng đã khóa") bật trên `visibilitychange → hidden`, chặn lộ số dư qua app switcher/screenshot. Số tiền cấm trong `document.title`, badge đếm và push payload (khớp UI Notes: push không số).

#### MPO-05 "Tôi" — boundary tối giản

Route tĩnh `/me`, không view-in-group, không deep-link con. Một cột: card hồ sơ (tên, tổ chức — read-only) → khối bảo mật (mở số dư đang ẩn, thiết bị nhận push + thu hồi) → phiên (đăng xuất, nhắc idle 30') → ngôn ngữ + CTA "Mở trên web". Đây là nơi duy nhất mount logic phiên/bảo mật — cấp shell; 4 tab còn lại không chạm vào.

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Thiết kế chi tiết màn hình | `mobile-portal/[screen-group].md` |
| Navigation portal web (đối tác cùng dữ liệu) | `../portal-web/Navigation-portal-web.md` |
| API endpoints | `../../phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `../../phase3-architecture/technical-specs/integration-map.md` |
| Design system | `../design-system.md` |
| REQ-IDs | `../../_meta/req-registry.json` |
