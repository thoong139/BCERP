### 4.5. Bố Cục & Responsive (ux-architect)

#### Kiến trúc & theming

Hướng **web-based PWA** (cài lên home screen, service worker). Lý do: toàn bộ tokens của design-system là CSS custom properties (§1) — PWA tái dùng 100% shared tokens và component semantics (StatusBadge, WarningIndicator) qua chung một file `:root`, không cần lớp mapping sang theme system native; ESS chỉ là tác vụ giao dịch ngắn (§7), API native cần dùng (geolocation check-in, camera) PWA đều đáp ứng được, và service worker cho sẵn nền tảng offline state.

```
┌──────────────────────────┐
│ Header: tiêu đề + bell   │  ← banner offline (khi mất mạng)
│ Content: 1 cột, scroll   │
├──────────────────────────┤
│ ⏱    🌴    📋    🔔   👤 │  ← bottom tab 56px + safe-area
└──────────────────────────┘
```

#### Khung bố cục

- **Bottom tab bar 5 mục** đúng menu tree §1: Home · Chấm công · Timesheet · Nghỉ phép · Tôi (Thông báo = chuông trên top app bar, KHÔNG chiếm tab). Nền `--color-mobile-bottomnav`, active `--color-primary`, padding-bottom `env(safe-area-inset-bottom)`.
- **M1 Home = landing screen** khi mở app; alert list rút gọn 3 mục ("Xem tất cả" → Thông báo), quick action deep-link thẳng tới tab tương ứng.
- **Stack navigation**: chi tiết/form push lên stack (slide 200ms, chỉ opacity + transform), back luôn về list gốc — không cây điều hướng sâu.
- **Single-column** toàn bộ; list render dạng card (`--mobile-card-padding: 16px`), không bảng — bảng data-heavy báo "Mở trên web" (§7).
- **Touch target ≥44×44px**, gap 8px giữa các action.
- **Form 1 màn hình, không wizard**: xin nghỉ phép (loại · từ/đến · lý do) và timesheet (project · ngày · giờ) gọn trong 1 màn; input body ≥16px chống zoom iOS, bàn phím đúng kiểu (date/số).

#### Offline state UI

- **Banner** (WarningIndicator variant banner, persistent) trên mọi màn khi mất mạng: "Mất kết nối — dữ liệu đang lưu nháp trên máy".
- **Draft local indicator**: chip `--state-draft` + icon đồng hồ trên card chưa sync; tự retry khi online, toast success sau khi sync xong.
- **Check-in/out bị chặn khi offline** — timestamp phải server-authoritative; nút chuyển trạng thái disabled kèm lý do.

#### Ranh giới component M1–M6

| Màn | Boundary |
|---|---|
| **M1 Home** | Quick action grid 2×2 (nút ≥44px + label) + Alert list (StatusBadge + WaitingOnIndicator; SLA breach đỏ xếp đầu) |
| **M2 Chấm công** | 1 nút Check-in/out full-width ~64px, trạng thái hiện tại ("Đã check-in 08:02") ngay phía trên; dưới là list card ngày theo token `--state-*` |
| **M3/M4 List + Form** | Card list, 1 StatusBadge/hàng; tap mở form 1 màn; trạng thái duyệt hiển thị "đang chờ ai" (WaitingOnIndicator chip) |
| **M6 Duyệt nhanh** (khi [NEEDS_REVIEW] được duyệt — hiện ở "Ứng viên tương lai") | Card tóm tắt (người · loại · ngày · số dư còn) + **swipe action**: phải = Duyệt (`--color-primary`), trái = Từ chối (`--color-error`, mở sheet bắt buộc lý do ≥10 ký tự); fallback nút Duyệt/Từ chối sticky footer 44px cho người không quen gesture. ESS không có lệnh tiền → không áp dụng quy tắc "không gesture ẩn cho tiền" |

#### Đồng bộ với web

Dùng chung file **shared tokens** (§1: màu, trạng thái, chữ, spacing 8px); mobile-only tokens chỉ bổ sung, không ghi đè semantics. **StatusBadge giữ nguyên 10 cặp bg/fg `--state-*`**, height 20px, luôn icon/chữ kèm màu (color-blind safe) — giống hệt web. WarningIndicator giữ đủ 3 phần (chuyện gì — cần ai làm gì — hạn); cấm `text-transform: uppercase` tiếng Việt; font Inter/Be Vietnam Pro.
