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
