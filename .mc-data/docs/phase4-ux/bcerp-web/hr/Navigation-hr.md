# Navigation: HR Workspace — BCERP Web

> **System ID:** SYS-BCERP-WEB | **Workspace:** HR (`/hr`) — DEPT-HR
> **Ngày:** 13/09/2026 (R3 — workspace folder structure)
>
> READS: `../Navigation-bcerp-web.md`, `../../design-system.md`, `../../../phase2-features/bcerp-web/`, `../../../phase3-architecture/P3-01-architecture.md`
> USED BY: `hr-core/screens-*.md`, `kpi/screens-kpi-performance.md`, `../Navigation-bcerp-web.md`

> Navigation cấp workspace — con của `Navigation-bcerp-web.md` (§1.0 Bảng A/B). Workspace HR phục vụ **Phòng Hành chính Nhân sự (DEPT-HR)**: HR_L1/L2 (+manager các phòng view giới hạn). Phân hệ: MOD-HR-CORE (12 FEAT) · MOD-KPI-PERFORMANCE (4) = **16 FEAT** + MOD-CAPACITY-TIMESHEET (5, duyệt song song ∥ Ops). Trang đích workspace = **S21 Leave Management**. Nhân viên tự phục vụ (chấm công, timesheet, xin phép, hồ sơ) qua mobile ESS — xem `../../mobile-internal/Navigation-mobile-internal.md`.

---

## 1. Sơ Đồ Menu (Menu Tree)

```
HR (/hr) — quick: Duyệt phép · Duyệt timesheet · Cập nhật hồ sơ
│
├── HR Records (tabs: Hồ sơ · HĐLĐ 90/60/30 · Rate card) → /hr/records → hr-core/screens-hr-records.md [{hodl_sap_het_han}]
├── Leave Management                        → /hr/leave             → hr-core/screens-leave.md           [{phep_cho_duyet}]
├── KPI & Performance                       → /hr/kpi               → kpi/screens-kpi-performance.md
└── Capacity & Timesheet (role view HR)     → /ops/capacity         → ../ops/capts/screens-capacity-timesheet.md [{timesheet_cho_duyet}] ¹
```

¹ S15 duyệt song song OPS ∥ HR theo THIẾT KẾ nghiệp vụ — 1 route `/ops/capacity`, 1 queue, permission filter quyết định ai thấy gì; KHÔNG nhân bản surface. File spec + menu Ops xem `../ops/Navigation-ops.md`.

## 2. Danh Sách Screen Groups

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S20 | HR Records (tabs: Hồ sơ / HĐLĐ / Rate card) | `/hr/records` | `hr-core/screens-hr-records.md` | `UI-WEB-HRREC-001` | MOD-HR-CORE |
| S21 | Leave Management | `/hr/leave` | `hr-core/screens-leave.md` | `UI-WEB-LEAVE-001` | MOD-HR-CORE |
| S22 | KPI & Performance | `/hr/kpi` | `kpi/screens-kpi-performance.md` | `UI-WEB-KPI-001` | MOD-KPI-PERFORMANCE |
| S15 | Capacity & Timesheet (duyệt ∥ Ops) | `/ops/capacity` | `../ops/capts/screens-capacity-timesheet.md` | `UI-WEB-CAPTS-001` | MOD-CAPACITY-TIMESHEET |

> Rate card đã MERGE thành tab của S20 (thẩm định HR ∥ FIN_L2 [NR]). Mobile ESS M1–M5 là bề mặt cá nhân của nhân viên — không thuộc workspace này.

## 3. Phân Quyền & Hiển Thị Menu

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| HR Records | `/hr/records` | HR_L1/L2 · manager các phòng (view giới hạn, PII lương masked) | CRUD hồ sơ, gia hạn HĐLĐ; rate card tab (FIN read thẩm định [NR]) | `{hodl_sap_het_han}` | Luôn |
| Leave Management | `/hr/leave` | HR_L1 → L2 (duyệt phân cấp) | Approve/reject | `{phep_cho_duyet}` | Luôn |
| KPI & Performance | `/hr/kpi` | HR_L2 (calibration) · quản lý (team) · BOD (view) | Calibration, PIP checkpoint | `{pip_dang_chay}` | Permission KPI |
| Capacity & Timesheet | `/ops/capacity` | OPS_AM + HR_L1/L2 (1 queue, permission filter) | Duyệt/từ chối theo vai | `{timesheet_cho_duyet}` | Menu ở cả Ops + HR |

- PII hồ sơ L1–L5 phân lớp Confidential/Restricted — lương masked theo permission, không có chế độ "xem tất cả".

## 4. UI Notes

### 4.1. Quick Actions

| Action | Mở gì | Ghi chú |
|---|---|---|
| Duyệt phép | S21 — queue phân cấp L1→L2 | Số dư tự động + lịch team |
| Duyệt timesheet | `/ops/capacity` (S15) | Cùng queue với Ops |
| Cập nhật hồ sơ | S20 — SidePanel 480px | PII masking theo vai |

### 4.2. Breadcrumb & Pattern

- Breadcrumb: `HR > Leave Management > [Yêu cầu #mã]` · `HR > HR Records > [Nhân sự #mã]`.
- Pattern: S20/S21 = Registry/admin (bảng + SidePanel 480px, comfortable); S22 = W4 hàng KPI + thân W1 (calibration, PIP 30-60-90).
- WaitingOn: phép chờ duyệt phân cấp · HĐLĐ 90/60/30 sắp hết hạn · timesheet chờ duyệt ∥ Ops.
- Icon workspace: `users` (Lucide).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Navigation tổng quan hệ thống (workspace map, §1.0) | `../Navigation-bcerp-web.md` |
| Thiết kế chi tiết màn hình | `hr-core/screens-hr-records.md`, `hr-core/screens-leave.md`, `kpi/screens-kpi-performance.md` |
| S15 Capacity & Timesheet (surface Ops) | `../ops/capts/screens-capacity-timesheet.md` |
| Mobile ESS (M1–M5) | `../../mobile-internal/Navigation-mobile-internal.md` |
| API endpoints | `../../../phase3-architecture/technical-specs/api-contract.md` |
| Design system | `../../design-system.md` |
| REQ-IDs / FEAT | `../../../_meta/req-registry.json` |
