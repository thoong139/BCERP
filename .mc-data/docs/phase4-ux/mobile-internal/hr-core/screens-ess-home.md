# Screen Group: M1 — ESS Home

> **System:** Mobile App BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** `hr-core`
> **Tính năng:** FEAT-MBI-CAPTS-001, FEAT-MBI-SLANOT-001, FEAT-ERP-HRCORE-005
> **Route:** `/m/home`
> **Main UI-ID:** `UI-MBI-HOME-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-mobile-internal.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-MBI-CAPTS-001 · FEAT-MBI-SLANOT-001 · FEAT-ERP-HRCORE-005 (Self-service nhân viên — ESS)

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Mobile ESS — mọi nhân viên nội bộ (18 vai registry, trừ CUSTOMER), chỉ dữ liệu của chính mình |
| Đối tượng nghiệp vụ | Dữ liệu cá nhân hợp nhất: trạng thái chấm công hôm nay, timesheet tuần, đơn nghỉ phép đang chờ, alert cá nhân (SLANOT) |
| Vai trò chính | Nhân viên ESS (đọc + điều hướng); người duyệt (TL/HR_L2) chỉ xuất hiện dưới dạng "đang chờ ai" |
| Workflow stage | Điểm vào (landing) — KHÔNG đổi state nghiệp vụ tại đây; mọi state đọc từ server |
| Checklist A–J | A: alert + tác vụ cá nhân · B: nhân viên · C: TL/HR (bên duyệt) · D: read-only aggregate · E: CAPTS + HR-CORE + SLANOT · F: "tôi cần làm gì hôm nay" · G: không có quyết định · H: chỉ deep-link · I: ghi chậm 3 ngày, gán vùng vàng, đơn bị từ chối · J: cần — landing duy nhất của app |

Layout theo `Navigation-mobile-internal.md` §4.5: PWA 1 cột, bottom tab bar 5 mục, thông báo = chuông trên top app bar. Quick action grid 2×2 đã chốt — không đổi.

---

## 1. TRANG CHÍNH

```
┌──────────────────────────────────────────────┐
│ BCERP                                     🔔³ │  top app bar
├──────────────────────────────────────────────┤
│ Xin chào, Minh Anh · Thứ Hai 14/09           │
│ [Banner: Mất kết nối — dữ liệu nháp trên máy]│  ← chỉ khi offline
│                                              │
│ Cần chú ý (3)                     Xem tất cả │
│ ┌──────────────────────────────────────────┐ │
│ │ ⏰ Chưa ghi timesheet 2 ngày              │ │
│ │    Ghi trước 12:00 thứ Hai        [Ghi →]│ │
│ ├──────────────────────────────────────────┤ │
│ │ 🌴 Đơn nghỉ 18–19/09: chờ duyệt          │ │
│ │    Chờ TL Minh Đức · đã 5 giờ            │ │
│ ├──────────────────────────────────────────┤ │
│ │ ⚠ Tuần 37: đã gán 92% — vùng vàng        │ │
│ │    Gán mới cần TL phê duyệt              │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Thao tác nhanh                               │
│ ┌────────────────┐  ┌────────────────┐       │
│ │ ⏱ Chấm công    │  │ 📋 Timesheet   │       │
│ │ Đã check-in    │  │ Tuần 37: 32.5h │       │
│ │ 08:02       →  │  | chờ duyệt   → │       │
│ └────────────────┘  └────────────────┘       │
│ ┌────────────────┐  ┌────────────────┐       │
│ │ 🌴 Nghỉ phép    │  │ 👤 Tôi         │       │
│ │ Còn 8.5 ngày → │  │ HĐLĐ còn 63 ngày→      │
│ └────────────────┘  └────────────────┘       │
├──────────────────────────────────────────────┤
│ [Home] [Chấm công] [Timesheet] [Nghỉ] [Tôi]  │
└──────────────────────────────────────────────┘
```

- **Alert cá nhân — tối đa 3 mục xếp theo độ nghiêm trọng** (SLA breach đỏ `--state-sla-breach` xếp đầu, rồi cảnh báo vàng, rồi kết quả đơn): mỗi alert đủ 3 phần chuyện gì — cần làm gì — hạn (WarningIndicator 3 phần, rút gọn 2 dòng). "Xem tất cả" mở drawer thông báo (chuông top bar). Alert là media push/in-app từ SLANOT, không tự tính trên thiết bị.
- **Quick action grid 2×2** (nút ≥44px + label, gap 8px): Chấm công → `/m/attendance` (subtitle = trạng thái hôm nay từ server), Timesheet → `/m/timesheet` (subtitle = tổng tuần + số dòng chờ duyệt), Nghỉ phép → `/m/leave` (subtitle = số dư phép năm), Tôi → `/m/profile` (subtitle = hạn HĐLĐ gần nhất, chỉ khi <90 ngày, ngược lại "Hồ sơ của tôi").
- **Trạng thái màn hình:** loading = skeleton 3 alert + 4 ô quick action; empty alert = "Không có việc cần chú ý" + ngày; error = EmptyState kèm nút "Thử lại" (giữ quick action luôn dùng được — landing không được trắng màn).
- **Deep-link từ push** (`mobile://home` và các link push khác) mở đúng surface; link ngoài quyền → fallback `/m/home` (PEP — ẩn, không disabled).

---

## 2. TABS

N/A — Home là landing 1 màn hình của app 5-tab; không có tab con (nguyên tắc tác vụ giao dịch ngắn, design-system §7).

---

## 3. DIALOGS

N/A — Home không thao tác ghi dữ liệu; mọi action là điều hướng.

---

## 4. SHEETS

N/A — "Xem tất cả" dùng drawer thông báo toàn cục của top bar (đã consolidate ở §2.0.5), không sinh sheet riêng trên Home.

---

## 5. VIEW MODES

N/A — Home chỉ có 1 mode đọc; tạo/sửa diễn ra ở M2/M3/M4.

---

## 6. API ENDPOINTS

| Endpoint | Method | Dùng cho | Ghi chú |
|----------|--------|----------|---------|
| `/api/v1/erp/ess/me` (API-ERP-066) | GET | Snapshot cá nhân: trạng thái công hôm nay, số dư phép, tổng giờ tuần, đơn đang chờ | ESS aggregate dùng chung với WEB |
| `/api/v1/mbi/ess/attendance/today` (API-MBI-020) | GET | Subtitle ô Chấm công | Không cache client (contract: forbidden) |
| `/api/v1/erp/notifications` (API-ERP-074) | GET | Alert cá nhân + drawer "Xem tất cả" | Filter theo user sở hữu object, phân trang server-side 20/50/100 `[NEEDS_REVIEW: MBI chưa có GET /api/v1/mbi/ess/notifications riêng — đi qua ERP-074]` |
| `/api/v1/mbi/app-config` (API-MBI-010) | GET | Bootstrap: surface map theo vai, force-update | Cache client được (payload ký số) |
| `/internal/mbi/push/dispatch` (API-MBI-034) | POST | Nguồn push notification (internal) | Không gọi từ UI — liệt kê để traceability |

Quick actions không gọi API riêng — chỉ deep-link tới surface tương ứng.

---

## 7. UI-ID Registry

| UI-ID | Tên | Loại | Mô tả |
|-------|-----|------|-------|
| UI-MBI-HOME-001 | ESS Home — Alert + quick actions | dashboard | Landing `/m/home`; alert 3 mục + grid 2×2 |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` | Upstream |
| Tính năng ESS | `../../../phase2-features/bcerp-web/hr-core/self-service-nhan-vien-ess.md` | Upstream |
| API chi tiết | `../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../design-system.md` | Upstream |
| Navigation tổng quan | `../Navigation-mobile-internal.md` | Upstream |
