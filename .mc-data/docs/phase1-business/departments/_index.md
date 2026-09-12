# Tổng Hợp Tài Liệu Phòng Ban — BCERP

> **Loại tài liệu:** Tổng hợp — Theo dõi tiến độ tài liệu tất cả phòng ban
> **Cập nhật bởi:** business-analyst /wf-analyze-requirements (tệp được tạo lại bởi audit 2026-09-12 — resolve SO3-08)
> **Ngày cập nhật:** 12/09/2026
>
> READS: `departments/[dept]/[dept].md`
> USED BY: `phase1-business/stakeholder-review.md`

---

## 1. Trạng Thái Tài Liệu Từng Phòng Ban

> Mỗi phòng ban có **1 folder riêng** chứa 1 tài liệu: `[tên-phòng-ban]/[tên].md` — Phần A (User Needs, gồm A7 — đánh giá Team Expert) + Phần B (Workflow).

| STT | Phòng ban | Folder | User Needs | Workflow | Trạng thái cuối |
|-----|-----------|--------|-----------|---------|----------------|
| 1 | Ban Điều Hành (BOD) | `bod/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |
| 2 | Hành chính Nhân sự (HR) | `hr/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |
| 3 | Tài chính - Kế toán (FIN) | `finance/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |
| 4 | Kinh Doanh (SALES) | `sales/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |
| 5 | Vận Hành Dự Án & Marketing Nội Bộ (OPS) | `operations/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |

**Tiến độ tổng thể:**
```
User Needs hoàn thành:  [5] / [5] phòng ban
Workflow hoàn thành:    [5] / [5] phòng ban
Sẵn sàng cho review:   [5] / [5] phòng ban (stakeholder-review.md đã chạy 12/09/2026)
```

### 1.1. Bảng Ký Hiệu Hệ Thống Chuẩn (resolve SO2-07)

> Dùng thống nhất bộ ký hiệu ngắn này trong mọi dept doc; ID đầy đủ nằm trong `_meta/req-registry.json` → `systems[]`.

| Ký hiệu ngắn | ID đầy đủ | Tên hệ thống | Phase |
|--------------|-----------|--------------|-------|
| `WEB` | `SYS-BCERP-WEB` | BCERP Web nội bộ | MVP |
| `CORE` | `SYS-CORE-BACKEND` | BCERP Core Backend | MVP |
| `GW` | `SYS-INTEGRATION-GW` | API Integration Gateway | MVP |
| `PORTAL` | `SYS-PORTAL-WEB` | Client Portal Web | Phase3 |
| `M-INT` | `SYS-MOBILE-INTERNAL` | Mobile App — BCERP Internal | Phase2 |
| `M-PORTAL` | `SYS-MOBILE-PORTAL` | Mobile App — BC Portal | Phase3 |

---

## 2. Tổng Hợp Nhu Cầu Người Dùng

| STT | Mã nhu cầu | Phòng ban | Tên nhu cầu | Mức độ ưu tiên | Phase | Phân hệ chính |
|-----|-----------|-----------|------------|---------------|-------|----------------|
| 1 | REQ-BOD-001 | BOD | Phê duyệt vượt ngưỡng & escalation | Bắt buộc | MVP | MOD-ARAP-PAYMENT |
| 2 | REQ-BOD-002 | BOD | Compensating control kiêm nhiệm CFO kiêm CTO | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 3 | REQ-BOD-003 | BOD | P&L toàn công ty realtime | Bắt buộc | MVP | MOD-DATAHUB-BI |
| 4 | REQ-BOD-004 | BOD | BI dashboard điều hành | Bắt buộc | Phase3 | MOD-DATAHUB-BI |
| 5 | REQ-BOD-005 | BOD | Giám sát & truy xuất audit log | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 6 | REQ-BOD-006 | BOD | Alert center & cảnh báo rủi ro vận hành | Bắt buộc | MVP | MOD-DATAHUB-BI |
| 7 | REQ-BOD-007 | BOD | Quarterly access review & phân quyền | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 8 | REQ-BOD-008 | BOD | Quản trị Integration Gateway & credentials vault (vai CTO) | Bắt buộc | MVP | MOD-SETTINGS-GW |
| 9 | REQ-BOD-009 | BOD | Phê duyệt chính sách, tham số quản trị & tier | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 10 | REQ-BOD-010 | BOD | Phê duyệt tài chính độc quyền của CFO | Quan trọng | MVP | MOD-ARAP-PAYMENT |
| 11 | REQ-BOD-011 | BOD | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 12 | REQ-HR-001 | HR | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | Bắt buộc | MVP | MOD-HR-CORE |
| 13 | REQ-HR-002 | HR | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | Bắt buộc | MVP | MOD-HR-CORE |
| 14 | REQ-HR-003 | HR | Chấm công & overtime | Bắt buộc | MVP | MOD-HR-CORE |
| 15 | REQ-HR-004 | HR | Nghỉ phép: số dư tự động & duyệt phân cấp | Bắt buộc | MVP | MOD-HR-CORE |
| 16 | REQ-HR-005 | HR | Self-service nhân viên (ESS) | Quan trọng | MVP | MOD-HR-CORE |
| 17 | REQ-HR-006 | HR | Cost Rate Card version hóa, thẩm định finance | Bắt buộc | MVP | MOD-HR-CORE |
| 18 | REQ-HR-007 | HR | KPI 3 trụ cột tự tổng hợp + calibration | Bắt buộc | Phase3 | MOD-KPI-PERFORMANCE |
| 19 | REQ-HR-008 | HR | PIP 30-60-90 | Quan trọng | Phase3 | MOD-KPI-PERFORMANCE |
| 20 | REQ-HR-009 | HR | Duyệt timesheet & capacity (phối hợp OPS) | Bắt buộc | Phase2 | MOD-CAPACITY-TIMESHEET |
| 21 | REQ-HR-010 | HR | Bảo vệ PII nhân sự (lương Confidential/Restricted) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 22 | REQ-FIN-001 | FINANCE | Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 23 | REQ-FIN-002 | FINANCE | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 24 | REQ-FIN-003 | FINANCE | Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 25 | REQ-FIN-004 | FINANCE | Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 26 | REQ-FIN-005 | FINANCE | API 7 nền tảng + degraded mode manual | Bắt buộc | MVP | MOD-SETTINGS-GW |
| 27 | REQ-FIN-006 | FINANCE | Financial Hard Stop "đã khớp tiền" FIN_L1 | Bắt buộc | MVP | MOD-WALLET-RECON |
| 28 | REQ-FIN-007 | FINANCE | Công nợ AR/AP + aging + nhắc nợ | Bắt buộc | Phase2 | MOD-ARAP-PAYMENT |
| 29 | REQ-FIN-008 | FINANCE | Duyệt chi/giải ngân: ngưỡng, SoD, delegate | Bắt buộc | Phase2 | MOD-ARAP-PAYMENT |
| 30 | REQ-FIN-009 | FINANCE | KYC pháp nhân trước cấp phát TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |
| 31 | REQ-FIN-010 | FINANCE | AML monitoring T1–T6 + hoàn tiền đúng nguồn | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 32 | REQ-FIN-011 | FINANCE | Hóa đơn điện tử TT78/2021 + NĐ123/2020 | Bắt buộc | Phase2 | MOD-ARAP-PAYMENT |
| 33 | REQ-FIN-012 | FINANCE | Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 34 | REQ-FIN-013 | FINANCE | Tích hợp phần mềm kế toán VAS hiện hữu | Quan trọng | Phase2 | MOD-ARAP-PAYMENT |
| 35 | REQ-FIN-014 | FINANCE | Phí nền tảng & nghĩa vụ thuế | Quan trọng | Phase2 | MOD-ARAP-PAYMENT |
| 36 | REQ-FIN-015 | FINANCE | Dashboard & báo cáo tài chính nội bộ | Quan trọng | Phase2 | MOD-DATAHUB-BI |
| 37 | REQ-FIN-016 | FINANCE | BI/BOD dashboard & P&L realtime | Quan trọng | Phase3 | MOD-DATAHUB-BI |
| 38 | REQ-FIN-017 | FINANCE | Dữ liệu ví read-only cho Client Portal | Quan trọng | Phase3 | MOD-CLIENT-PORTAL |
| 39 | REQ-SALES-001 | SALES | Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 40 | REQ-SALES-002 | SALES | Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 41 | REQ-SALES-003 | SALES | AUTO SCORING K1–K12 & Tier A–E | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 42 | REQ-SALES-004 | SALES | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 43 | REQ-SALES-005 | SALES | Chuyển tier Sales → CS & rà soát quý tier | Quan trọng | MVP | MOD-CRM-PIPELINE |
| 44 | REQ-SALES-006 | SALES | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | Bắt buộc | MVP | MOD-QUOTATION-DEALDESK |
| 45 | REQ-SALES-007 | SALES | Hợp đồng/LOI/NDA & Brand Safety + e-sign | Bắt buộc | MVP | MOD-QUOTATION-DEALDESK |
| 46 | REQ-SALES-008 | SALES | Handoff & Onboarding Bridge | Bắt buộc | Phase2 | MOD-HANDOFF-ONBOARD |
| 47 | REQ-SALES-009 | SALES | Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× | Quan trọng | Phase3 | MOD-COMMISSION-QUOTA |
| 48 | REQ-OPS-001 | OPS | Ad Account Command Center — registry & vòng đời TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |
| 49 | REQ-OPS-002 | OPS | Financial Hard Stop chặn cấp phát TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |
| 50 | REQ-OPS-003 | OPS | Ví TKQC góc ops — cảnh báo số dư & escalation | Bắt buộc | Phase2 | MOD-WALLET-RECON |
| 51 | REQ-OPS-004 | OPS | Handoff & Onboarding Bridge | Bắt buộc | Phase2 | MOD-HANDOFF-ONBOARD |
| 52 | REQ-OPS-005 | OPS | Proposal & Planning Workspace (stage-gate V6.0) | Bắt buộc | Phase2 | MOD-PROPOSAL-PLANNING |
| 53 | REQ-OPS-006 | OPS | Campaign & Deliverable Management | Bắt buộc | Phase2 | MOD-CAMPAIGN-DELIVERABLE |
| 54 | REQ-OPS-007 | OPS | Capacity & Timesheet | Bắt buộc | Phase2 | MOD-CAPACITY-TIMESHEET |
| 55 | REQ-OPS-008 | OPS | SLA & Notification Engine | Bắt buộc | Phase2 | MOD-SLA-NOTIF |
| 56 | REQ-OPS-009 | OPS | Ticket & CSKH | Quan trọng | Phase2 | MOD-TICKET-CSKH |
| 57 | REQ-OPS-010 | OPS | Client Portal góc nhìn ops — cấp tài khoản & monitor | Bắt buộc | Phase3 | MOD-CLIENT-PORTAL |
| 58 | REQ-OPS-011 | OPS | TikTok Shop Monitoring | Quan trọng | Phase3 | MOD-TIKTOK-SHOP |
| 59 | REQ-OPS-012 | OPS | A/B Testing & chiến lược campaign theo mục tiêu khách | Quan trọng | Phase2 | MOD-CAMPAIGN-DELIVERABLE |

**Phân bố ưu tiên:**

| Mức độ | Số lượng | Tỷ lệ |
|--------|----------|-------|
| Bắt buộc (HIGH) | 46 | 78% |
| Quan trọng (MEDIUM) | 13 | 22% |
| **Tổng** | **59** | 100% |

---

## 3. Nhu Cầu Ưu Tiên Cao — Giai Đoạn 1 (MVP)

| STT | Mã | Phòng ban | Nhu cầu | Phân hệ chính |
|-----|-----|-----------|---------|----------------|
| 1 | REQ-BOD-001 | BOD | Phê duyệt vượt ngưỡng & escalation | Bắt buộc | MVP | MOD-ARAP-PAYMENT |
| 2 | REQ-BOD-002 | BOD | Compensating control kiêm nhiệm CFO kiêm CTO | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 3 | REQ-BOD-003 | BOD | P&L toàn công ty realtime | Bắt buộc | MVP | MOD-DATAHUB-BI |
| 4 | REQ-BOD-005 | BOD | Giám sát & truy xuất audit log | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 5 | REQ-BOD-006 | BOD | Alert center & cảnh báo rủi ro vận hành | Bắt buộc | MVP | MOD-DATAHUB-BI |
| 6 | REQ-BOD-007 | BOD | Quarterly access review & phân quyền | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 7 | REQ-BOD-008 | BOD | Quản trị Integration Gateway & credentials vault (vai CTO) | Bắt buộc | MVP | MOD-SETTINGS-GW |
| 8 | REQ-BOD-009 | BOD | Phê duyệt chính sách, tham số quản trị & tier | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 9 | REQ-BOD-010 | BOD | Phê duyệt tài chính độc quyền của CFO | Quan trọng | MVP | MOD-ARAP-PAYMENT |
| 10 | REQ-BOD-011 | BOD | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 11 | REQ-HR-001 | HR | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | Bắt buộc | MVP | MOD-HR-CORE |
| 12 | REQ-HR-002 | HR | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | Bắt buộc | MVP | MOD-HR-CORE |
| 13 | REQ-HR-003 | HR | Chấm công & overtime | Bắt buộc | MVP | MOD-HR-CORE |
| 14 | REQ-HR-004 | HR | Nghỉ phép: số dư tự động & duyệt phân cấp | Bắt buộc | MVP | MOD-HR-CORE |
| 15 | REQ-HR-005 | HR | Self-service nhân viên (ESS) | Quan trọng | MVP | MOD-HR-CORE |
| 16 | REQ-HR-006 | HR | Cost Rate Card version hóa, thẩm định finance | Bắt buộc | MVP | MOD-HR-CORE |
| 17 | REQ-HR-010 | HR | Bảo vệ PII nhân sự (lương Confidential/Restricted) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 18 | REQ-FIN-005 | FINANCE | API 7 nền tảng + degraded mode manual | Bắt buộc | MVP | MOD-SETTINGS-GW |
| 19 | REQ-FIN-006 | FINANCE | Financial Hard Stop "đã khớp tiền" FIN_L1 | Bắt buộc | MVP | MOD-WALLET-RECON |
| 20 | REQ-FIN-009 | FINANCE | KYC pháp nhân trước cấp phát TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |
| 21 | REQ-FIN-012 | FINANCE | Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) | Bắt buộc | MVP | MOD-RBAC-AUDIT |
| 22 | REQ-SALES-001 | SALES | Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 23 | REQ-SALES-002 | SALES | Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 24 | REQ-SALES-003 | SALES | AUTO SCORING K1–K12 & Tier A–E | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 25 | REQ-SALES-004 | SALES | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | Bắt buộc | MVP | MOD-CRM-PIPELINE |
| 26 | REQ-SALES-005 | SALES | Chuyển tier Sales → CS & rà soát quý tier | Quan trọng | MVP | MOD-CRM-PIPELINE |
| 27 | REQ-SALES-006 | SALES | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | Bắt buộc | MVP | MOD-QUOTATION-DEALDESK |
| 28 | REQ-SALES-007 | SALES | Hợp đồng/LOI/NDA & Brand Safety + e-sign | Bắt buộc | MVP | MOD-QUOTATION-DEALDESK |
| 29 | REQ-OPS-001 | OPS | Ad Account Command Center — registry & vòng đời TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |
| 30 | REQ-OPS-002 | OPS | Financial Hard Stop chặn cấp phát TKQC | Bắt buộc | MVP | MOD-ADACCOUNT-CC |

**Tổng MVP: 30 REQ.**

---

## 4. Nhu Cầu Liên Phòng Ban

> Trích từ `_meta/phase1-handoff.json` → cross_department_dependencies (đã ghi AI Decision Record — xem stakeholder-review.md Phần E).

| Nhóm nhu cầu | REQ các bên | Ghi chú |
|--------------|-------------|---------|
| Financial Hard Stop (chặn cấp phát TKQC) | REQ-FIN-006, REQ-OPS-002 | FIN là nguồn xác nhận "đã khớp tiền"; OPS là điểm chặn |
| Cảnh báo số dư ví TKQC | REQ-FIN-002, REQ-OPS-003 | REQ-OPS-003 làm leader engine cảnh báo (SO1-02) |
| Duyệt timesheet & capacity | REQ-HR-009, REQ-OPS-007 | HR sở hữu quy tắc duyệt/định mức; OPS ghi nhận |
| P&L realtime & BI dashboard | REQ-BOD-003, REQ-FIN-016 (+REQ-BOD-004) | FIN-016 chủ star schema/metric catalog; BOD-003/004 chủ trải nghiệm dashboard |
| RBAC & SSO/MFA nền tảng (cross-cutting) | REQ-BOD-011 (+BOD-002/005/007/009, HR-010, FIN-012) | REQ sở hữu phân hệ MOD-RBAC-AUDIT (resolve SO3-01/DR-003) |

---

## 5. Yêu Cầu Chất Lượng Chung (Phi Chức Năng)

> Chi tiết đầy đủ tại `P0-02-systems-users.md` §3 (NFR) và `P1-01-project-overview.md` §9. NFR nghiệm thu per-system sẽ đưa vào acceptance criteria ở Phase 2 (SO3-06).

| Tiêu chí | Yêu cầu | Mức độ quan trọng |
|----------|---------|------------------|
| Tốc độ | API P95 < 500ms; page load < 3s (dashboard ≤ 5s) | Bắt buộc |
| Độ ổn định | Uptime portal 99,9% (7×24); concurrent 200–300 | Bắt buộc |
| Bảo mật | RBAC vai×Level, SSO/MFA, tenant isolation portal, audit log bất biến | Bắt buộc |
| Truy cập | Web + Mobile (nội bộ + portal variant) | Bắt buộc |
| Lưu trữ | Chứng từ tiền & audit log WORM ≥ 10 năm | Bắt buộc |
| Khả năng mở rộng | Scale gấp đôi không thiết kế lại | Quan trọng |

---

## 6. Xác Nhận Hoàn Thành Tài Liệu Phòng Ban

```
☒ Tất cả [dept].md đã hoàn thành Phần A (User Needs) + Phần B (Workflow) — 5/5
☒ Bảng "Tổng Hợp Nhu Cầu" (mục 2) đã điền đầy đủ — 59 REQ khớp req-registry.json
☒ Danh sách "Nhu Cầu Liên Phòng Ban" (mục 4) đã được xác định
☒ Sẵn sàng chuyển cho stakeholder-review.md để review — review đã chạy 12/09/2026 (28 findings)
```
