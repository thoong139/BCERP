# Screen Group: MPO-05 — Tôi (account shell)

> **System:** Mobile App BC Portal (SYS-MOBILE-PORTAL)
> **Module:** `client-portal`
> **Tính năng:** FEAT-MPO-CPORT-001
> **Route:** `/me`
> **Main UI-ID:** `UI-MPO-ACC-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-portal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MPO-CPORT-001

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-MPO-ACC-001` |
| Route | `/me` (tĩnh — không view-in-group, không deep-link con) |
| Loại | Form/Shell (1 cột, comfortable) |
| FEAT-ID | FEAT-MPO-CPORT-001 |
| Người dùng | CUSTOMER (CLIENT_ADMIN / CLIENT_USER) |

**Checklist B0:** Workspace = Client Portal. Đối tượng = portal_user + phiên + thiết bị push của chính mình (không phải surface dữ liệu nghiệp vụ). Vai: CLIENT_ADMIN thêm quản lý portal user trong hạn mức. Stage: tài khoản INVITED → ACTIVE → LOCKED/DISABLED do CORE sở hữu — app chỉ hiển thị trạng thái của chính mình. Đây là **nơi duy nhất mount logic phiên/bảo mật** (mask/re-auth, thu hồi push, idle 30') — cấp shell; 4 tab còn lại không chạm vào. Quyết định tại đây: thu hồi thiết bị/phiên, tắt push, đổi ngôn ngữ. Cấm: cấu hình credential/vault, dữ liệu gate nội bộ, quota tăng từ app.

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌──────────────────────────────────────────────┐
│ Tôi                                          │
├──────────────────────────────────────────────┤
│ ┌ Hồ sơ ────────────────────────────────────┐│
│ │ Nguyễn Văn A · CLIENT_USER · ĐANG HOẠT    ││
│ │ Công ty TNHH ABC · Tier B  [Đổi tenant ▾] ││ ← chỉ liệt kê tenant được gán
│ └───────────────────────────────────────────┘│
│ ┌ Bảo mật ───────────────────────────────────┐│
│ │ Mở số dư đang ẩn                    →     ││ ← về /home, mở sheet re-auth
│ │ Thiết bị nhận push (2)              →     ││
│ │  · iPhone 15 · bật · đồng bộ 09:00 [Thu hồi]││
│ │  · iPad Pro  · tắt              [Thu hồi] ││ ← thu hồi riêng từng thiết bị
│ │ Đăng xuất từ xa toàn bộ phiên             ││ ← CLIENT_ADMIN (mình) / POC
│ └───────────────────────────────────────────┘│
│ ┌ Phiên ────────────────────────────────────┐│
│ │ Tự khóa sau 30 phút không dùng (info)     ││
│ │ Đăng xuất                          →     ││ ← thu hồi phiên + push token
│ └───────────────────────────────────────────┘│
│ Ngôn ngữ: Tiếng Việt ▾ · Múi giờ: GMT+7 ▾    │
│ [Mở trên web — đối tác đầy đủ]               │
├──────────────────────────────────────────────┤
│  🏠      📣      🧾      🎧      👤         │
└──────────────────────────────────────────────┘
```

### 1.2. Components & quy tắc

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| Card hồ sơ | read-only toàn bộ | Email, vai portal, trạng thái tài khoản; không sửa được gì ngoài preferences |
| Danh sách thiết bị | touch ≥44px mỗi hàng | Từ đăng ký sau đăng nhập 2FA; thu hồi 1 thiết bị không ảnh hưởng thiết bị khác |
| Row action | Thu hồi = danger, luôn có confirm (S1) | Push token revoke (soft) ngay lập tức |
| Tenant switcher | chỉ khi claim `tenants[]` > 1 | Push tách theo tenant đang chọn |

**States:** loading skeleton card; error + Thử lại; sau đăng xuất → về màn đăng nhập, push token thiết bị gọi thu hồi cùng request.

### 1.3. Phân Quyền

| Thành phần | CLIENT_ADMIN | CLIENT_USER |
|-----------|:---:|:---:|
| Hồ sơ, ngôn ngữ, thiết bị, đăng xuất | ✅ | ✅ |
| Mở số dư đang ẩn (re-auth) | ✅ | ✅ |
| Đăng xuất từ xa toàn bộ phiên | ✅ (mình) / POC | ❌ (ẩn) |
| Quản lý portal user trong hạn mức | ✅ (+OTP) | ❌ (ẩn hoàn toàn) |

---

## 2. TABS

N/A — shell 1 cột theo boundary tối giản (Navigation §4.5); mục "Người dùng portal" chỉ CLIENT_ADMIN thấy, mở sheet S3, không route con.

---

## 3. DIALOGS

### 3.1. Dialog: Sắp hết phiên (`UI-MPO-ACC-001-D1`)

Idle 28/30 phút → modal đếm ngược 2 phút: "Phiên sắp hết hạn — Tiếp tục / Đăng nhập lại". Hết hạn → đăng nhập lại (2FA) rồi quay đúng surface đang mở, không redirect đột ngột. Mount cấp shell từ đây.

---

## 4. SHEETS

### 4.1. Sheet: Xác nhận đăng xuất từ xa (`UI-MPO-ACC-001-S1`)

Confirm hành động nhạy cảm: cảnh báo mọi thiết bị sẽ nhận push, hết phiên ngay; CLIENT_ADMIN thu hồi giúp người khác cần xác minh POC. Xác nhận → `API-MPO-013`.

### 4.2. Sheet: Cấu hình thiết bị push (`UI-MPO-ACC-001-S2`)

Opt-in/out per thiết bị + mức cảnh báo nhận + giờ im lặng (chỉ áp Low/Medium; Critical/breach luôn xuyên qua). Tắt quyền thông báo OS → cảnh báo fallback in-app + email/Zalo trước khi rời màn.

### 4.3. Sheet: Người dùng portal (`UI-MPO-ACC-001-S3`, chỉ CLIENT_ADMIN)

Danh sách user + quota_used/quota_limit; mời user / gửi lại invite / vô hiệu hóa — mỗi hành động nhạy cảm thêm lớp OTP (`API-MPO-003/004`). Vượt hạn mức → chặn "Vượt hạn mức theo hợp đồng, liên hệ AM".

---

## 5. VIEW MODES

N/A — route tĩnh, mọi hành động trong sheet S1–S3; tác vụ sâu (đổi mật khẩu, xuất dữ liệu) → CTA "Mở trên web" `[NEEDS_REVIEW: BFF chưa có endpoint đổi mật khẩu/exu dữ liệu cho MPO — dùng kênh web]`.

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải hồ sơ | GET | `/api/v1/mpo/me` | API-MPO-007; profile + 2FA + locale/timezone |
| Lưu ngôn ngữ/múi giờ | PUT | `/api/v1/mpo/me/preferences` | API-MPO-008 |
| Đăng xuất | POST | `/api/v1/mpo/auth/logout` | API-MPO-006; revoke phiên + push token thiết bị gọi |
| Đăng xuất từ xa | POST | `/api/v1/mpo/sessions/revoke-all` | API-MPO-013; CLIENT_ADMIN (mình) / POC |
| Danh sách thiết bị | GET | — trên /me gộp từ đăng ký thiết bị | `[NEEDS_REVIEW: MPO chưa có GET /devices — danh sách render từ trạng thái device đã bind]` |
| Opt-in/giờ im lặng | PUT | `/api/v1/mpo/devices/:id` | API-MPO-015; chỉ Low/Medium |
| Thu hồi thiết bị | DELETE | `/api/v1/mpo/devices/:id` | API-MPO-016; chủ thiết bị / CLIENT_ADMIN |
| OTP hành động nhạy cảm | POST | `/api/v1/mpo/auth/otp` + `/api/v1/mpo/auth/otp/verify` | API-MPO-003/004 |
| Quản lý portal user | GET/POST | `/api/v1/mpo/portal-users`, `/portal-users/invites`, `/portal-users/:id/invites/resend`, `/portal-users/:id/disable` | API-MPO-009..012; CLIENT_ADMIN + OTP; quota do CORE kiểm tra → 409 `QUOTA_EXCEEDED` |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-MPO-ACC-001` | Main | Shell hồ sơ + bảo mật + phiên (1 cột) |
| `UI-MPO-ACC-001-D1` | Dialog | Sắp hết phiên — đếm ngược 2 phút (idle 30') |
| `UI-MPO-ACC-001-S1` | Sheet | Xác nhận đăng xuất từ xa toàn bộ phiên |
| `UI-MPO-ACC-001-S2` | Sheet | Cấu hình thiết bị push (opt-in, giờ im lặng) |
| `UI-MPO-ACC-001-S3` | Sheet | Người dùng portal (CLIENT_ADMIN + OTP) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-portal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | FEAT-MPO-CPORT-001 (BR-008, BR-009) |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | §5 Auth + §6.1 Hồ sơ & Portal Account + §6.2 Thiết bị & Push |
| Design system | `../../design-system.md` | §7 mobile, §8 accessibility |
| Navigation tổng quan | `../Navigation-mobile-portal.md` | §4.2 session & bảo mật, §4.5 boundary MPO-05 |
