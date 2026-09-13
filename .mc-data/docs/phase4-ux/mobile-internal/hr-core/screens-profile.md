# Screen Group: M5 — Hồ sơ cá nhân

> **System:** Mobile App BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** `hr-core`
> **Tính năng:** FEAT-ERP-HRCORE-001 (xem ghi chú registry)
> **Route:** `/m/profile`
> **Main UI-ID:** `UI-MBI-PROF-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-internal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-HRCORE-001 (Hồ sơ nhân sự SSOT — REQ-HR-001; xem thông tin của chính mình, PII masking)

> `[NEEDS_REVIEW: REQ-HR-003/004/005 chưa có FEAT touchpoint MBI trong registry (api-contract §6.4) — Navigation §2 giữ M5 trong scope với upstream FEAT-ERP-HRCORE-001; endpoint thật API-MBI-026]`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Mobile ESS — self-data duy nhất; không có bất kỳ màn hình nào xem dữ liệu nhân viên khác |
| Đối tượng nghiệp vụ | `EmployeeProfile` (view của chính mình, field-level security phía backend) + HĐLĐ của mình + thiết bị/push preference |
| Vai trò chính | Nhân viên đọc; không có thao tác quản trị (HR không thao tác qua app này) |
| Workflow stage | Read-only; thay đổi thông tin nhạy cảm đi luồng yêu cầu có duyệt HR_L2 trên WEB/CORE (ESS — FEAT-ERP-HRCORE-005) |
| Checklist A–J | A: hồ sơ bản thân · B: nhân viên · C: HR_L2 (bên duyệt thay đổi, ngoài mobile) · D: read-only · E: HR-CORE, MBI device/push · F: "thông tin của tôi có đúng không" · G: không có quyết định · H: chỉ đọc + quản lý thiết bị của mình · I: PII lộ, HĐLĐ sắp hết hạn, thiết bị lạ · J: cần — tab "Tôi" của bottom nav |

---

## 1. TRANG CHÍNH

```
┌──────────────────────────────────────────────┐
│ ← Tôi                                   🔔   │
├──────────────────────────────────────────────┤
│ (avatar) Nguyễn Minh Anh · OPS_AM (L2)       │
│ ┌ Thông tin của tôi ───────────────────────┐ │
│ │ Mã NV: OPS-0142 · Ngày vào 02/01/2023    │ │
│ │ TL trực tiếp: Minh Đức                   │ │
│ │ SĐT: 0912•••488 · Email: m.anh@bc.vn     │ │
│ │ TK ngân hàng: ••••4881                   │ │
│ │ Lương/CCCD: •••••• (masked)              │ │
│ │ → Cập nhật SĐT/TK ngân hàng: gửi yêu     │ │
│ │   cầu qua WEB — HR_L2 duyệt 24h          │ │
│ │   [Mở trên web]                          │ │
│ └──────────────────────────────────────────┘ │
│ ┌ HĐLĐ của tôi ────────────────────────────┐ │
│ │ HĐLĐ HD-2023-042 · hết hạn 15/11/2026    │ │
│ │ [còn 63 ngày] — trong ngưỡng nhắc 90/60/30│ │
│ └──────────────────────────────────────────┘ │
│ ┌ Thiết bị & thông báo ────────────────────┐ │
│ │ iPhone 15 · binding 02/09/2026      [⋯]  │ │
│ │ Push: Duyệt ✓ · SLA vàng ✓ · SLA đỏ 🔒   │ │
│ └──────────────────────────────────────────┘ │
│ [Đăng xuất]                                  │
└──────────────────────────────────────────────┘
```

- **UI-MBI-PROF-001 — Thông tin của tôi** (`/m/profile`): dữ liệu đọc từ profile render theo **field-level security của backend** — trường C1 (lương, CCCD, TK ngân hàng) hiển thị **masked, không có nút "xem đầy đủ"** (BR-004 ESS — bản gốc chỉ HR_L2 mở, log từng lượt); RBAC-006: người khác không bao giờ thấy lương của nhau, và app này chỉ có self-data. **PII lương KHÔNG cache thiết bị** (contract API-MBI-026).
- **HĐLĐ của tôi:** số hợp đồng, ngày hết hạn + chip còn/x quá ngày so ngưỡng cảnh báo 90/60/30 — chỉ hiển thị kết quả job core, không tự tính mốc.
- **Cập nhật thông tin:** SĐT/thường (hiệu lực sau lưu) và nhạy cảm (TK ngân hàng, người liên hệ khẩn) đi luồng yêu cầu HR_L2 duyệt — **không có endpoint ghi profile trên MBI** → CTA "Mở trên web" (design-system §7: quy trình dài không parity mobile), không bịa nút gửi trên app.
- **Thiết bị & thông báo:** danh sách thiết bị đã binding của chính mình (revoke thiết bị lạ) + bật/tắt push theo category; **kênh escalation SLA đỏ cấm tắt** (chỉ backend quyết).
- **Trạng thái:** loading = skeleton 3 khối; error = retry; offline → khối profile hiển thị cache kèm mốc đọc, khối thiết bị/thông báo cần mạng (hiển thị thông báo cần kết nối).

---

## 2. TABS

N/A — 1 màn hình cuộn dọc 3 khối (thông tin · HĐLĐ · thiết bị); không phân tab.

---

## 3. DIALOGS

**Xác nhận đăng xuất** — Modal 1 nút chính "Đăng xuất": revoke session + push token, purge local cache theo API-MBI-003 (remote wipe). Không dùng cho thao tác khác.

---

## 4. SHEETS

**UI-MBI-PROF-001-S — Quản lý thiết bị** (bottom sheet từ `[⋯]` trên dòng thiết bị): thông tin binding (platform, OS/app version, ngày đăng ký, last_seen) + nút "Thu hồi thiết bị" (danger — dùng khi mất máy/thiết bị lạ; xác nhận trong sheet, có audit log).

---

## 5. VIEW MODES

N/A — chỉ mode đọc (self-data). Không Create/Edit/Approve trên mobile.

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng cho | Ghi chú |
|----------|--------|----------|---------|
| `/api/v1/mbi/ess/profile` (API-MBI-026) | GET | Hồ sơ của chính mình + HĐLĐ, render theo field-level security backend | Không cache client; PII lương không cache thiết bị |
| `/api/v1/mbi/devices` (API-MBI-007) | GET | Danh sách thiết bị đã binding | — |
| `/api/v1/mbi/devices/:deviceId` (API-MBI-006) | DELETE | Thu hồi thiết bị (sheet quản lý thiết bị) | Online bắt buộc |
| `/api/v1/mbi/push-preferences` (API-MBI-008/009) | GET/PUT | Bật/tắt push theo category + quiet hours | Kênh SLA đỏ cấm tắt |
| `/api/v1/mbi/auth/logout` (API-MBI-003) | POST | Đăng xuất + purge cache | — |
| `/api/v1/erp/ess/me` (API-ERP-066) | GET | Dự phòng aggregate cá nhân (dùng cho M1) | Cập nhật thông tin → luồng ESS trên WEB `[NEEDS_REVIEW: MBI chưa có PUT profile / POST profile-change-request]` |

---

## 7. UI-ID Registry

| UI-ID | Tên | Loại | Mô tả |
|-------|-----|------|-------|
| UI-MBI-PROF-001 | Thông tin của tôi | detail | PII masked, HĐLĐ 90/60/30, thiết bị + push, đăng xuất |
| UI-MBI-PROF-001-S | Sheet quản lý thiết bị | sheet | Thông tin binding + thu hồi thiết bị |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/bcerp-web/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` | Upstream (REQ-HR-001) |
| Tính năng ESS | `../../../phase2-features/bcerp-web/hr-core/self-service-nhan-vien-ess.md` | Upstream (masking, luồng đổi thông tin) |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-mobile-internal.md` | Upstream |
