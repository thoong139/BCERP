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
