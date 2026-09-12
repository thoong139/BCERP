# Define Features Plan

> **Muc dich:** Ke hoach chi tiet de chuyen requirements thanh feature specifications.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-define-features`
>
> **Khi viet:** Phase 1 cua define-features skill (resume session 20260912-112934-6bcf)
>
> **Cap nhat:** Tu dong cap nhat sau moi phase hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Skill Run ID** | `DEFINE-FEAT-20260912-001` |
| **Scope** | `all` |
| **Target** | `all` (Plan B full scope — CDG-A02) |
| **Created** | `2026-09-12 19:39:29` |
| **Last Updated** | `2026-09-12 19:39:29` |
| **Status** | `In Progress` |
| **Large Project Mode** | `true` (59 REQ ≥ 50) — max_parallel=3, digest ~300 từ, checkpoint sau MỖI phase |

---

## 1. Scope Overview

### 1.1 Requirements Summary

| Muc | So luong |
|-----|---------|
| Total REQ-IDs trong registry | 59 |
| REQ-IDs trong scope | 59 (100%) |
| Systems can xu ly | 6 |
| Modules can xu ly | 19 |
| Feature files se tao | 170 (fan-out per-system: Σ len(REQ.systems[])) |

### 1.2 Target Systems & Modules

| # | System ID | System Name | Modules | REQ count | Priority |
|---|-----------|-------------|---------|-----------|----------|
| 1 | `SYS-BCERP-WEB` | BCERP Web nội bộ | MOD-ARAP-PAYMENT, MOD-RBAC-AUDIT, MOD-DATAHUB-BI, MOD-SETTINGS-GW, MOD-HR-CORE, MOD-KPI-PERFORMANCE, MOD-CAPACITY-TIMESHEET, MOD-WALLET-RECON, MOD-ADACCOUNT-CC, MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD, MOD-COMMISSION-QUOTA, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE, MOD-SLA-NOTIF, MOD-TICKET-CSKH, MOD-CLIENT-PORTAL, MOD-TIKTOK-SHOP | 58 | MVP |
| 2 | `SYS-CORE-BACKEND` | BCERP Core Backend | MOD-ARAP-PAYMENT, MOD-RBAC-AUDIT, MOD-DATAHUB-BI, MOD-SETTINGS-GW, MOD-HR-CORE, MOD-KPI-PERFORMANCE, MOD-CAPACITY-TIMESHEET, MOD-WALLET-RECON, MOD-ADACCOUNT-CC, MOD-CLIENT-PORTAL, MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD, MOD-COMMISSION-QUOTA, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE, MOD-SLA-NOTIF, MOD-TICKET-CSKH, MOD-TIKTOK-SHOP | 59 | MVP |
| 3 | `SYS-INTEGRATION-GW` | API Integration Gateway | MOD-RBAC-AUDIT, MOD-SETTINGS-GW, MOD-WALLET-RECON, MOD-ARAP-PAYMENT, MOD-ADACCOUNT-CC, MOD-CAMPAIGN-DELIVERABLE, MOD-TIKTOK-SHOP | 11 | MVP |
| 4 | `SYS-PORTAL-WEB` | Client Portal Web | MOD-RBAC-AUDIT, MOD-CLIENT-PORTAL, MOD-WALLET-RECON, MOD-CAMPAIGN-DELIVERABLE, MOD-SLA-NOTIF, MOD-TICKET-CSKH | 7 | Phase3 |
| 5 | `SYS-MOBILE-INTERNAL` | Mobile App — BCERP Internal | MOD-ARAP-PAYMENT, MOD-RBAC-AUDIT, MOD-DATAHUB-BI, MOD-WALLET-RECON, MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD, MOD-COMMISSION-QUOTA, MOD-ADACCOUNT-CC, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE, MOD-CAPACITY-TIMESHEET, MOD-SLA-NOTIF, MOD-TICKET-CSKH, MOD-CLIENT-PORTAL, MOD-TIKTOK-SHOP | 30 | Phase2 |
| 6 | `SYS-MOBILE-PORTAL` | Mobile App — BC Portal | MOD-WALLET-RECON, MOD-CAMPAIGN-DELIVERABLE, MOD-SLA-NOTIF, MOD-TICKET-CSKH, MOD-CLIENT-PORTAL | 5 | Phase3 |

### 1.4-COV Per-system Feature Count Preview (BẮT BUỘC)

| system_id | feature_count | req_ids contributing |
|-----------|---------------|----------------------|
| `SYS-BCERP-WEB` | 58 | 58 REQs |
| `SYS-CORE-BACKEND` | 59 | 59 REQs |
| `SYS-INTEGRATION-GW` | 11 | 11 REQs |
| `SYS-PORTAL-WEB` | 7 | 7 REQs |
| `SYS-MOBILE-INTERNAL` | 30 | 30 REQs |
| `SYS-MOBILE-PORTAL` | 5 | 5 REQs |

> MVP systems: SYS-BCERP-WEB, SYS-CORE-BACKEND, SYS-INTEGRATION-GW — coverage check: PASS (mọi MVP system ≥1 feature)

### 1.3 Handoff Inputs

| Input | Location | Vai trò |
|-------|----------|---------|
| Project intent digest | `.mc-data/work/wf-brainstorm/project-intent-digest.json` | Giữ intent và scope gọn cho Phase 2 |
| Phase 1 handoff | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` | REQ clusters, actors, business rule keywords |
| Feature briefs | `.mc-data/work/wf-define-features/feature-briefs.json` | Artifact ngắn dùng chung cho review và validation (170 briefs) |
| Quy trình chính thức v1.1 | `documents/quy-trinh-lam-viec/` (11 file) | Nguồn BR tier A–E, Deploy D+0→D+5, RACI/Gate/SLA, hằng số; 11 KXN còn mở = assumption có tag |
| CMS Domain Model | `documents/02_Quy_trinh_Cho_thue_TKQC.md` | Domain TKQC: OADS, Contract serviceType, Wallet, Topup k-formula, Replacement, Rebate OFF |
| HR Knowledge Base | `documents/03_Quy_che_KPI_HR.md` (MỚI 12/09) | HR lifecycle v3.9, salary band, KPI/hoa hồng theo vị trí, nội quy — context cho HR/KPI/Commission/Capacity |

---

## 2. FEAT-ID Assignment

### 2.1 Scheme

```
FEAT-[SYS]-[MOD]-NNN
```
- [SYS]: CORE / ERP / GW / MBI / PORTAL / MPO (6 systems)
- [MOD]: RBAC, STGW, HRCORE, CRM, QDD, ADACC, WALLET, ARAP, HONB, PROPLN, CAMP, CAPTS, SLANOT, CSKH, COMM, KPI, CPORT, DHUB, TIKTOK
- NNN: sequential per (system, module) — ví dụ FEAT-ERP-WALLET-001
- Kiểm tra trùng: registry.features[] hiện 0 entries → không xung đột.

### 2.2 Feature Groups & FEAT-IDs (170 features)

| FEAT-ID | Feature Name | System | Module | REQ-IDs Covered | Output File |
|---------|-------------|--------|--------|-----------------|-------------|
| `FEAT-CORE-ARAP-001` | Phê duyệt vượt ngưỡng & escalation | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-BOD-001` | `phase2-features/core-backend/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` |
| `FEAT-ERP-ARAP-001` | Phê duyệt vượt ngưỡng & escalation | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-BOD-001` | `phase2-features/bcerp-web/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` |
| `FEAT-MBI-ARAP-001` | Phê duyệt vượt ngưỡng & escalation | SYS-MOBILE-INTERNAL | MOD-ARAP-PAYMENT | `REQ-BOD-001` | `phase2-features/mobile-internal/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` |
| `FEAT-CORE-RBAC-001` | Compensating control kiêm nhiệm CFO kiêm CTO | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-BOD-002` | `phase2-features/core-backend/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` |
| `FEAT-ERP-RBAC-001` | Compensating control kiêm nhiệm CFO kiêm CTO | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-BOD-002` | `phase2-features/bcerp-web/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` |
| `FEAT-MBI-RBAC-001` | Compensating control kiêm nhiệm CFO kiêm CTO | SYS-MOBILE-INTERNAL | MOD-RBAC-AUDIT | `REQ-BOD-002` | `phase2-features/mobile-internal/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` |
| `FEAT-CORE-DHUB-001` | P&L toàn công ty realtime | SYS-CORE-BACKEND | MOD-DATAHUB-BI | `REQ-BOD-003` | `phase2-features/core-backend/datahub-bi/p-va-l-toan-cong-ty-realtime.md` |
| `FEAT-ERP-DHUB-001` | P&L toàn công ty realtime | SYS-BCERP-WEB | MOD-DATAHUB-BI | `REQ-BOD-003` | `phase2-features/bcerp-web/datahub-bi/p-va-l-toan-cong-ty-realtime.md` |
| `FEAT-MBI-DHUB-001` | P&L toàn công ty realtime | SYS-MOBILE-INTERNAL | MOD-DATAHUB-BI | `REQ-BOD-003` | `phase2-features/mobile-internal/datahub-bi/p-va-l-toan-cong-ty-realtime.md` |
| `FEAT-CORE-DHUB-002` | BI dashboard điều hành | SYS-CORE-BACKEND | MOD-DATAHUB-BI | `REQ-BOD-004` | `phase2-features/core-backend/datahub-bi/bi-dashboard-dieu-hanh.md` |
| `FEAT-ERP-DHUB-002` | BI dashboard điều hành | SYS-BCERP-WEB | MOD-DATAHUB-BI | `REQ-BOD-004` | `phase2-features/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md` |
| `FEAT-MBI-DHUB-002` | BI dashboard điều hành | SYS-MOBILE-INTERNAL | MOD-DATAHUB-BI | `REQ-BOD-004` | `phase2-features/mobile-internal/datahub-bi/bi-dashboard-dieu-hanh.md` |
| `FEAT-CORE-RBAC-002` | Giám sát & truy xuất audit log | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-BOD-005` | `phase2-features/core-backend/rbac-audit/giam-sat-va-truy-xuat-audit-log.md` |
| `FEAT-ERP-RBAC-002` | Giám sát & truy xuất audit log | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-BOD-005` | `phase2-features/bcerp-web/rbac-audit/giam-sat-va-truy-xuat-audit-log.md` |
| `FEAT-CORE-DHUB-003` | Alert center & cảnh báo rủi ro vận hành | SYS-CORE-BACKEND | MOD-DATAHUB-BI | `REQ-BOD-006` | `phase2-features/core-backend/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` |
| `FEAT-ERP-DHUB-003` | Alert center & cảnh báo rủi ro vận hành | SYS-BCERP-WEB | MOD-DATAHUB-BI | `REQ-BOD-006` | `phase2-features/bcerp-web/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` |
| `FEAT-MBI-DHUB-003` | Alert center & cảnh báo rủi ro vận hành | SYS-MOBILE-INTERNAL | MOD-DATAHUB-BI | `REQ-BOD-006` | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` |
| `FEAT-CORE-RBAC-003` | Quarterly access review & phân quyền | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-BOD-007` | `phase2-features/core-backend/rbac-audit/quarterly-access-review-va-phan-quyen.md` |
| `FEAT-GW-RBAC-001` | Quarterly access review & phân quyền | SYS-INTEGRATION-GW | MOD-RBAC-AUDIT | `REQ-BOD-007` | `phase2-features/integration-gw/rbac-audit/quarterly-access-review-va-phan-quyen.md` |
| `FEAT-ERP-RBAC-003` | Quarterly access review & phân quyền | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-BOD-007` | `phase2-features/bcerp-web/rbac-audit/quarterly-access-review-va-phan-quyen.md` |
| `FEAT-GW-STGW-001` | Quản trị Integration Gateway & credentials vault (vai CTO) | SYS-INTEGRATION-GW | MOD-SETTINGS-GW | `REQ-BOD-008` | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` |
| `FEAT-CORE-STGW-001` | Quản trị Integration Gateway & credentials vault (vai CTO) | SYS-CORE-BACKEND | MOD-SETTINGS-GW | `REQ-BOD-008` | `phase2-features/core-backend/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` |
| `FEAT-ERP-STGW-001` | Quản trị Integration Gateway & credentials vault (vai CTO) | SYS-BCERP-WEB | MOD-SETTINGS-GW | `REQ-BOD-008` | `phase2-features/bcerp-web/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` |
| `FEAT-CORE-RBAC-004` | Phê duyệt chính sách, tham số quản trị & tier | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-BOD-009` | `phase2-features/core-backend/rbac-audit/phe-duyet-chinh-sach-tham-so-quan-tri-va-tier.md` |
| `FEAT-ERP-RBAC-004` | Phê duyệt chính sách, tham số quản trị & tier | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-BOD-009` | `phase2-features/bcerp-web/rbac-audit/phe-duyet-chinh-sach-tham-so-quan-tri-va-tier.md` |
| `FEAT-CORE-ARAP-002` | Phê duyệt tài chính độc quyền của CFO | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-BOD-010` | `phase2-features/core-backend/arap-payment/phe-duyet-tai-chinh-doc-quyen-cua-cfo.md` |
| `FEAT-ERP-ARAP-002` | Phê duyệt tài chính độc quyền của CFO | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-BOD-010` | `phase2-features/bcerp-web/arap-payment/phe-duyet-tai-chinh-doc-quyen-cua-cfo.md` |
| `FEAT-CORE-RBAC-005` | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-BOD-011` | `phase2-features/core-backend/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` |
| `FEAT-ERP-RBAC-005` | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-BOD-011` | `phase2-features/bcerp-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` |
| `FEAT-PORTAL-RBAC-001` | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | SYS-PORTAL-WEB | MOD-RBAC-AUDIT | `REQ-BOD-011` | `phase2-features/portal-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` |
| `FEAT-MBI-RBAC-002` | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | SYS-MOBILE-INTERNAL | MOD-RBAC-AUDIT | `REQ-BOD-011` | `phase2-features/mobile-internal/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` |
| `FEAT-CORE-HRCORE-001` | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-001` | `phase2-features/core-backend/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` |
| `FEAT-ERP-HRCORE-001` | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-001` | `phase2-features/bcerp-web/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` |
| `FEAT-CORE-HRCORE-002` | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-002` | `phase2-features/core-backend/hr-core/hdld-va-canh-bao-het-han-90-60-30-ngay.md` |
| `FEAT-ERP-HRCORE-002` | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-002` | `phase2-features/bcerp-web/hr-core/hdld-va-canh-bao-het-han-90-60-30-ngay.md` |
| `FEAT-ERP-HRCORE-003` | Chấm công & overtime | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-003` | `phase2-features/bcerp-web/hr-core/cham-cong-va-overtime.md` |
| `FEAT-CORE-HRCORE-003` | Chấm công & overtime | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-003` | `phase2-features/core-backend/hr-core/cham-cong-va-overtime.md` |
| `FEAT-ERP-HRCORE-004` | Nghỉ phép: số dư tự động & duyệt phân cấp | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-004` | `phase2-features/bcerp-web/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` |
| `FEAT-CORE-HRCORE-004` | Nghỉ phép: số dư tự động & duyệt phân cấp | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-004` | `phase2-features/core-backend/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` |
| `FEAT-ERP-HRCORE-005` | Self-service nhân viên (ESS) | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-005` | `phase2-features/bcerp-web/hr-core/self-service-nhan-vien-ess.md` |
| `FEAT-CORE-HRCORE-005` | Self-service nhân viên (ESS) | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-005` | `phase2-features/core-backend/hr-core/self-service-nhan-vien-ess.md` |
| `FEAT-CORE-HRCORE-006` | Cost Rate Card version hóa, thẩm định finance | SYS-CORE-BACKEND | MOD-HR-CORE | `REQ-HR-006` | `phase2-features/core-backend/hr-core/cost-rate-card-version-hoa-tham-dinh-finance.md` |
| `FEAT-ERP-HRCORE-006` | Cost Rate Card version hóa, thẩm định finance | SYS-BCERP-WEB | MOD-HR-CORE | `REQ-HR-006` | `phase2-features/bcerp-web/hr-core/cost-rate-card-version-hoa-tham-dinh-finance.md` |
| `FEAT-CORE-KPI-001` | KPI 3 trụ cột tự tổng hợp + calibration | SYS-CORE-BACKEND | MOD-KPI-PERFORMANCE | `REQ-HR-007` | `phase2-features/core-backend/kpi-performance/kpi-3-tru-cot-tu-tong-hop-calibration.md` |
| `FEAT-ERP-KPI-001` | KPI 3 trụ cột tự tổng hợp + calibration | SYS-BCERP-WEB | MOD-KPI-PERFORMANCE | `REQ-HR-007` | `phase2-features/bcerp-web/kpi-performance/kpi-3-tru-cot-tu-tong-hop-calibration.md` |
| `FEAT-ERP-KPI-002` | PIP 30-60-90 | SYS-BCERP-WEB | MOD-KPI-PERFORMANCE | `REQ-HR-008` | `phase2-features/bcerp-web/kpi-performance/pip-30-60-90.md` |
| `FEAT-CORE-KPI-002` | PIP 30-60-90 | SYS-CORE-BACKEND | MOD-KPI-PERFORMANCE | `REQ-HR-008` | `phase2-features/core-backend/kpi-performance/pip-30-60-90.md` |
| `FEAT-CORE-CAPTS-001` | Duyệt timesheet & capacity (phối hợp OPS) | SYS-CORE-BACKEND | MOD-CAPACITY-TIMESHEET | `REQ-HR-009` | `phase2-features/core-backend/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md` |
| `FEAT-ERP-CAPTS-001` | Duyệt timesheet & capacity (phối hợp OPS) | SYS-BCERP-WEB | MOD-CAPACITY-TIMESHEET | `REQ-HR-009` | `phase2-features/bcerp-web/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md` |
| `FEAT-CORE-RBAC-006` | Bảo vệ PII nhân sự (lương Confidential/Restricted) | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-HR-010` | `phase2-features/core-backend/rbac-audit/bao-ve-pii-nhan-su-luong-confidential-restricted.md` |
| `FEAT-ERP-RBAC-006` | Bảo vệ PII nhân sự (lương Confidential/Restricted) | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-HR-010` | `phase2-features/bcerp-web/rbac-audit/bao-ve-pii-nhan-su-luong-confidential-restricted.md` |
| `FEAT-CORE-WALLET-001` | Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-001` | `phase2-features/core-backend/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` |
| `FEAT-ERP-WALLET-001` | Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-001` | `phase2-features/bcerp-web/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` |
| `FEAT-MBI-WALLET-001` | Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-FIN-001` | `phase2-features/mobile-internal/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` |
| `FEAT-CORE-WALLET-002` | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-002` | `phase2-features/core-backend/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` |
| `FEAT-ERP-WALLET-002` | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-002` | `phase2-features/bcerp-web/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` |
| `FEAT-MBI-WALLET-002` | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-FIN-002` | `phase2-features/mobile-internal/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` |
| `FEAT-CORE-WALLET-003` | Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-003` | `phase2-features/core-backend/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` |
| `FEAT-ERP-WALLET-003` | Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-003` | `phase2-features/bcerp-web/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` |
| `FEAT-MBI-WALLET-003` | Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-FIN-003` | `phase2-features/mobile-internal/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` |
| `FEAT-CORE-WALLET-004` | Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-004` | `phase2-features/core-backend/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` |
| `FEAT-GW-WALLET-001` | Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ | SYS-INTEGRATION-GW | MOD-WALLET-RECON | `REQ-FIN-004` | `phase2-features/integration-gw/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` |
| `FEAT-ERP-WALLET-004` | Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-004` | `phase2-features/bcerp-web/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` |
| `FEAT-GW-STGW-002` | API 7 nền tảng + degraded mode manual | SYS-INTEGRATION-GW | MOD-SETTINGS-GW | `REQ-FIN-005` | `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` |
| `FEAT-CORE-STGW-002` | API 7 nền tảng + degraded mode manual | SYS-CORE-BACKEND | MOD-SETTINGS-GW | `REQ-FIN-005` | `phase2-features/core-backend/settings-gw/api-7-nen-tang-degraded-mode-manual.md` |
| `FEAT-ERP-STGW-002` | API 7 nền tảng + degraded mode manual | SYS-BCERP-WEB | MOD-SETTINGS-GW | `REQ-FIN-005` | `phase2-features/bcerp-web/settings-gw/api-7-nen-tang-degraded-mode-manual.md` |
| `FEAT-CORE-WALLET-005` | Financial Hard Stop "đã khớp tiền" FIN_L1 | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-006` | `phase2-features/core-backend/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` |
| `FEAT-ERP-WALLET-005` | Financial Hard Stop "đã khớp tiền" FIN_L1 | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-006` | `phase2-features/bcerp-web/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` |
| `FEAT-MBI-WALLET-004` | Financial Hard Stop "đã khớp tiền" FIN_L1 | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-FIN-006` | `phase2-features/mobile-internal/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` |
| `FEAT-CORE-ARAP-003` | Công nợ AR/AP + aging + nhắc nợ | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-FIN-007` | `phase2-features/core-backend/arap-payment/cong-no-ar-ap-aging-nhac-no.md` |
| `FEAT-ERP-ARAP-003` | Công nợ AR/AP + aging + nhắc nợ | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-FIN-007` | `phase2-features/bcerp-web/arap-payment/cong-no-ar-ap-aging-nhac-no.md` |
| `FEAT-CORE-ARAP-004` | Duyệt chi/giải ngân: ngưỡng, SoD, delegate | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-FIN-008` | `phase2-features/core-backend/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` |
| `FEAT-ERP-ARAP-004` | Duyệt chi/giải ngân: ngưỡng, SoD, delegate | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-FIN-008` | `phase2-features/bcerp-web/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` |
| `FEAT-MBI-ARAP-002` | Duyệt chi/giải ngân: ngưỡng, SoD, delegate | SYS-MOBILE-INTERNAL | MOD-ARAP-PAYMENT | `REQ-FIN-008` | `phase2-features/mobile-internal/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` |
| `FEAT-CORE-ADACC-001` | KYC pháp nhân trước cấp phát TKQC | SYS-CORE-BACKEND | MOD-ADACCOUNT-CC | `REQ-FIN-009` | `phase2-features/core-backend/adaccount-cc/kyc-phap-nhan-truoc-cap-phat-tkqc.md` |
| `FEAT-ERP-ADACC-001` | KYC pháp nhân trước cấp phát TKQC | SYS-BCERP-WEB | MOD-ADACCOUNT-CC | `REQ-FIN-009` | `phase2-features/bcerp-web/adaccount-cc/kyc-phap-nhan-truoc-cap-phat-tkqc.md` |
| `FEAT-CORE-WALLET-006` | AML monitoring T1–T6 + hoàn tiền đúng nguồn | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-FIN-010` | `phase2-features/core-backend/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` |
| `FEAT-ERP-WALLET-006` | AML monitoring T1–T6 + hoàn tiền đúng nguồn | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-FIN-010` | `phase2-features/bcerp-web/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` |
| `FEAT-MBI-WALLET-005` | AML monitoring T1–T6 + hoàn tiền đúng nguồn | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-FIN-010` | `phase2-features/mobile-internal/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` |
| `FEAT-CORE-ARAP-005` | Hóa đơn điện tử TT78/2021 + NĐ123/2020 | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-FIN-011` | `phase2-features/core-backend/arap-payment/hoa-don-dien-tu-tt78-2021-nd123-2020.md` |
| `FEAT-ERP-ARAP-005` | Hóa đơn điện tử TT78/2021 + NĐ123/2020 | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-FIN-011` | `phase2-features/bcerp-web/arap-payment/hoa-don-dien-tu-tt78-2021-nd123-2020.md` |
| `FEAT-CORE-RBAC-007` | Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) | SYS-CORE-BACKEND | MOD-RBAC-AUDIT | `REQ-FIN-012` | `phase2-features/core-backend/rbac-audit/luu-tru-chung-tu-va-audit-log-tien-10-nam-worm.md` |
| `FEAT-ERP-RBAC-007` | Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) | SYS-BCERP-WEB | MOD-RBAC-AUDIT | `REQ-FIN-012` | `phase2-features/bcerp-web/rbac-audit/luu-tru-chung-tu-va-audit-log-tien-10-nam-worm.md` |
| `FEAT-GW-ARAP-001` | Tích hợp phần mềm kế toán VAS hiện hữu | SYS-INTEGRATION-GW | MOD-ARAP-PAYMENT | `REQ-FIN-013` | `phase2-features/integration-gw/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| `FEAT-CORE-ARAP-006` | Tích hợp phần mềm kế toán VAS hiện hữu | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-FIN-013` | `phase2-features/core-backend/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| `FEAT-ERP-ARAP-006` | Tích hợp phần mềm kế toán VAS hiện hữu | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-FIN-013` | `phase2-features/bcerp-web/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| `FEAT-CORE-ARAP-007` | Phí nền tảng & nghĩa vụ thuế | SYS-CORE-BACKEND | MOD-ARAP-PAYMENT | `REQ-FIN-014` | `phase2-features/core-backend/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` |
| `FEAT-GW-ARAP-002` | Phí nền tảng & nghĩa vụ thuế | SYS-INTEGRATION-GW | MOD-ARAP-PAYMENT | `REQ-FIN-014` | `phase2-features/integration-gw/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` |
| `FEAT-ERP-ARAP-007` | Phí nền tảng & nghĩa vụ thuế | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | `REQ-FIN-014` | `phase2-features/bcerp-web/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` |
| `FEAT-CORE-DHUB-004` | Dashboard & báo cáo tài chính nội bộ | SYS-CORE-BACKEND | MOD-DATAHUB-BI | `REQ-FIN-015` | `phase2-features/core-backend/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` |
| `FEAT-ERP-DHUB-004` | Dashboard & báo cáo tài chính nội bộ | SYS-BCERP-WEB | MOD-DATAHUB-BI | `REQ-FIN-015` | `phase2-features/bcerp-web/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` |
| `FEAT-MBI-DHUB-004` | Dashboard & báo cáo tài chính nội bộ | SYS-MOBILE-INTERNAL | MOD-DATAHUB-BI | `REQ-FIN-015` | `phase2-features/mobile-internal/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` |
| `FEAT-CORE-DHUB-005` | BI/BOD dashboard & P&L realtime | SYS-CORE-BACKEND | MOD-DATAHUB-BI | `REQ-FIN-016` | `phase2-features/core-backend/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` |
| `FEAT-ERP-DHUB-005` | BI/BOD dashboard & P&L realtime | SYS-BCERP-WEB | MOD-DATAHUB-BI | `REQ-FIN-016` | `phase2-features/bcerp-web/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` |
| `FEAT-MBI-DHUB-005` | BI/BOD dashboard & P&L realtime | SYS-MOBILE-INTERNAL | MOD-DATAHUB-BI | `REQ-FIN-016` | `phase2-features/mobile-internal/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` |
| `FEAT-PORTAL-CPORT-001` | Dữ liệu ví read-only cho Client Portal | SYS-PORTAL-WEB | MOD-CLIENT-PORTAL | `REQ-FIN-017` | `phase2-features/portal-web/client-portal/du-lieu-vi-read-only-cho-client-portal.md` |
| `FEAT-CORE-CPORT-001` | Dữ liệu ví read-only cho Client Portal | SYS-CORE-BACKEND | MOD-CLIENT-PORTAL | `REQ-FIN-017` | `phase2-features/core-backend/client-portal/du-lieu-vi-read-only-cho-client-portal.md` |
| `FEAT-CORE-CRM-001` | Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) | SYS-CORE-BACKEND | MOD-CRM-PIPELINE | `REQ-SALES-001` | `phase2-features/core-backend/crm-pipeline/thu-nhan-lead-da-kenh-va-chong-trung-lap-anti-duplicate.md` |
| `FEAT-ERP-CRM-001` | Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) | SYS-BCERP-WEB | MOD-CRM-PIPELINE | `REQ-SALES-001` | `phase2-features/bcerp-web/crm-pipeline/thu-nhan-lead-da-kenh-va-chong-trung-lap-anti-duplicate.md` |
| `FEAT-CORE-CRM-002` | Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead | SYS-CORE-BACKEND | MOD-CRM-PIPELINE | `REQ-SALES-002` | `phase2-features/core-backend/crm-pipeline/pipeline-v6-0-hard-gate-khong-ghi-nhan-khong-ton-tai-va-phan-bo-lead.md` |
| `FEAT-ERP-CRM-002` | Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead | SYS-BCERP-WEB | MOD-CRM-PIPELINE | `REQ-SALES-002` | `phase2-features/bcerp-web/crm-pipeline/pipeline-v6-0-hard-gate-khong-ghi-nhan-khong-ton-tai-va-phan-bo-lead.md` |
| `FEAT-CORE-CRM-003` | AUTO SCORING K1–K12 & Tier A–E | SYS-CORE-BACKEND | MOD-CRM-PIPELINE | `REQ-SALES-003` | `phase2-features/core-backend/crm-pipeline/auto-scoring-k1-k12-va-tier-a-e.md` |
| `FEAT-ERP-CRM-003` | AUTO SCORING K1–K12 & Tier A–E | SYS-BCERP-WEB | MOD-CRM-PIPELINE | `REQ-SALES-003` | `phase2-features/bcerp-web/crm-pipeline/auto-scoring-k1-k12-va-tier-a-e.md` |
| `FEAT-CORE-CRM-004` | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | SYS-CORE-BACKEND | MOD-CRM-PIPELINE | `REQ-SALES-004` | `phase2-features/core-backend/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` |
| `FEAT-ERP-CRM-004` | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | SYS-BCERP-WEB | MOD-CRM-PIPELINE | `REQ-SALES-004` | `phase2-features/bcerp-web/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` |
| `FEAT-MBI-CRM-001` | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | SYS-MOBILE-INTERNAL | MOD-CRM-PIPELINE | `REQ-SALES-004` | `phase2-features/mobile-internal/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` |
| `FEAT-CORE-CRM-005` | Chuyển tier Sales → CS & rà soát quý tier | SYS-CORE-BACKEND | MOD-CRM-PIPELINE | `REQ-SALES-005` | `phase2-features/core-backend/crm-pipeline/chuyen-tier-sales-cs-va-ra-soat-quy-tier.md` |
| `FEAT-ERP-CRM-005` | Chuyển tier Sales → CS & rà soát quý tier | SYS-BCERP-WEB | MOD-CRM-PIPELINE | `REQ-SALES-005` | `phase2-features/bcerp-web/crm-pipeline/chuyen-tier-sales-cs-va-ra-soat-quy-tier.md` |
| `FEAT-CORE-QDD-001` | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | SYS-CORE-BACKEND | MOD-QUOTATION-DEALDESK | `REQ-SALES-006` | `phase2-features/core-backend/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` |
| `FEAT-ERP-QDD-001` | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | SYS-BCERP-WEB | MOD-QUOTATION-DEALDESK | `REQ-SALES-006` | `phase2-features/bcerp-web/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` |
| `FEAT-MBI-QDD-001` | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | SYS-MOBILE-INTERNAL | MOD-QUOTATION-DEALDESK | `REQ-SALES-006` | `phase2-features/mobile-internal/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` |
| `FEAT-CORE-QDD-002` | Hợp đồng/LOI/NDA & Brand Safety + e-sign | SYS-CORE-BACKEND | MOD-QUOTATION-DEALDESK | `REQ-SALES-007` | `phase2-features/core-backend/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` |
| `FEAT-ERP-QDD-002` | Hợp đồng/LOI/NDA & Brand Safety + e-sign | SYS-BCERP-WEB | MOD-QUOTATION-DEALDESK | `REQ-SALES-007` | `phase2-features/bcerp-web/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` |
| `FEAT-MBI-QDD-002` | Hợp đồng/LOI/NDA & Brand Safety + e-sign | SYS-MOBILE-INTERNAL | MOD-QUOTATION-DEALDESK | `REQ-SALES-007` | `phase2-features/mobile-internal/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` |
| `FEAT-CORE-HONB-001` | Handoff & Onboarding Bridge | SYS-CORE-BACKEND | MOD-HANDOFF-ONBOARD | `REQ-SALES-008` | `phase2-features/core-backend/handoff-onboard/handoff-va-onboarding-bridge.md` |
| `FEAT-ERP-HONB-001` | Handoff & Onboarding Bridge | SYS-BCERP-WEB | MOD-HANDOFF-ONBOARD | `REQ-SALES-008` | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md` |
| `FEAT-MBI-HONB-001` | Handoff & Onboarding Bridge | SYS-MOBILE-INTERNAL | MOD-HANDOFF-ONBOARD | `REQ-SALES-008` | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge.md` |
| `FEAT-CORE-COMM-001` | Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× | SYS-CORE-BACKEND | MOD-COMMISSION-QUOTA | `REQ-SALES-009` | `phase2-features/core-backend/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` |
| `FEAT-ERP-COMM-001` | Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× | SYS-BCERP-WEB | MOD-COMMISSION-QUOTA | `REQ-SALES-009` | `phase2-features/bcerp-web/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` |
| `FEAT-MBI-COMM-001` | Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× | SYS-MOBILE-INTERNAL | MOD-COMMISSION-QUOTA | `REQ-SALES-009` | `phase2-features/mobile-internal/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` |
| `FEAT-CORE-ADACC-002` | Ad Account Command Center — registry & vòng đời TKQC | SYS-CORE-BACKEND | MOD-ADACCOUNT-CC | `REQ-OPS-001` | `phase2-features/core-backend/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` |
| `FEAT-ERP-ADACC-002` | Ad Account Command Center — registry & vòng đời TKQC | SYS-BCERP-WEB | MOD-ADACCOUNT-CC | `REQ-OPS-001` | `phase2-features/bcerp-web/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` |
| `FEAT-GW-ADACC-001` | Ad Account Command Center — registry & vòng đời TKQC | SYS-INTEGRATION-GW | MOD-ADACCOUNT-CC | `REQ-OPS-001` | `phase2-features/integration-gw/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` |
| `FEAT-MBI-ADACC-001` | Ad Account Command Center — registry & vòng đời TKQC | SYS-MOBILE-INTERNAL | MOD-ADACCOUNT-CC | `REQ-OPS-001` | `phase2-features/mobile-internal/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` |
| `FEAT-CORE-ADACC-003` | Financial Hard Stop chặn cấp phát TKQC | SYS-CORE-BACKEND | MOD-ADACCOUNT-CC | `REQ-OPS-002` | `phase2-features/core-backend/adaccount-cc/financial-hard-stop-chan-cap-phat-tkqc.md` |
| `FEAT-ERP-ADACC-003` | Financial Hard Stop chặn cấp phát TKQC | SYS-BCERP-WEB | MOD-ADACCOUNT-CC | `REQ-OPS-002` | `phase2-features/bcerp-web/adaccount-cc/financial-hard-stop-chan-cap-phat-tkqc.md` |
| `FEAT-CORE-WALLET-007` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-CORE-BACKEND | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/core-backend/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-GW-WALLET-002` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-INTEGRATION-GW | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/integration-gw/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-ERP-WALLET-007` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-BCERP-WEB | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/bcerp-web/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-MBI-WALLET-006` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-MOBILE-INTERNAL | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/mobile-internal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-PORTAL-WALLET-001` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-PORTAL-WEB | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/portal-web/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-MPO-WALLET-001` | Ví TKQC góc ops — cảnh báo số dư & escalation | SYS-MOBILE-PORTAL | MOD-WALLET-RECON | `REQ-OPS-003` | `phase2-features/mobile-portal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` |
| `FEAT-CORE-HONB-002` | Handoff & Onboarding Bridge | SYS-CORE-BACKEND | MOD-HANDOFF-ONBOARD | `REQ-OPS-004` | `phase2-features/core-backend/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` |
| `FEAT-ERP-HONB-002` | Handoff & Onboarding Bridge | SYS-BCERP-WEB | MOD-HANDOFF-ONBOARD | `REQ-OPS-004` | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` |
| `FEAT-MBI-HONB-002` | Handoff & Onboarding Bridge | SYS-MOBILE-INTERNAL | MOD-HANDOFF-ONBOARD | `REQ-OPS-004` | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` |
| `FEAT-CORE-PROPLN-001` | Proposal & Planning Workspace (stage-gate V6.0) | SYS-CORE-BACKEND | MOD-PROPOSAL-PLANNING | `REQ-OPS-005` | `phase2-features/core-backend/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` |
| `FEAT-ERP-PROPLN-001` | Proposal & Planning Workspace (stage-gate V6.0) | SYS-BCERP-WEB | MOD-PROPOSAL-PLANNING | `REQ-OPS-005` | `phase2-features/bcerp-web/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` |
| `FEAT-MBI-PROPLN-001` | Proposal & Planning Workspace (stage-gate V6.0) | SYS-MOBILE-INTERNAL | MOD-PROPOSAL-PLANNING | `REQ-OPS-005` | `phase2-features/mobile-internal/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` |
| `FEAT-CORE-CAMP-001` | Campaign & Deliverable Management | SYS-CORE-BACKEND | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/core-backend/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-GW-CAMP-001` | Campaign & Deliverable Management | SYS-INTEGRATION-GW | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/integration-gw/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-ERP-CAMP-001` | Campaign & Deliverable Management | SYS-BCERP-WEB | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/bcerp-web/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-MBI-CAMP-001` | Campaign & Deliverable Management | SYS-MOBILE-INTERNAL | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/mobile-internal/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-PORTAL-CAMP-001` | Campaign & Deliverable Management | SYS-PORTAL-WEB | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/portal-web/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-MPO-CAMP-001` | Campaign & Deliverable Management | SYS-MOBILE-PORTAL | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-006` | `phase2-features/mobile-portal/campaign-deliverable/campaign-va-deliverable-management.md` |
| `FEAT-CORE-CAPTS-002` | Capacity & Timesheet | SYS-CORE-BACKEND | MOD-CAPACITY-TIMESHEET | `REQ-OPS-007` | `phase2-features/core-backend/capacity-timesheet/capacity-va-timesheet.md` |
| `FEAT-ERP-CAPTS-002` | Capacity & Timesheet | SYS-BCERP-WEB | MOD-CAPACITY-TIMESHEET | `REQ-OPS-007` | `phase2-features/bcerp-web/capacity-timesheet/capacity-va-timesheet.md` |
| `FEAT-MBI-CAPTS-001` | Capacity & Timesheet | SYS-MOBILE-INTERNAL | MOD-CAPACITY-TIMESHEET | `REQ-OPS-007` | `phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` |
| `FEAT-CORE-SLANOT-001` | SLA & Notification Engine | SYS-CORE-BACKEND | MOD-SLA-NOTIF | `REQ-OPS-008` | `phase2-features/core-backend/sla-notif/sla-va-notification-engine.md` |
| `FEAT-ERP-SLANOT-001` | SLA & Notification Engine | SYS-BCERP-WEB | MOD-SLA-NOTIF | `REQ-OPS-008` | `phase2-features/bcerp-web/sla-notif/sla-va-notification-engine.md` |
| `FEAT-MBI-SLANOT-001` | SLA & Notification Engine | SYS-MOBILE-INTERNAL | MOD-SLA-NOTIF | `REQ-OPS-008` | `phase2-features/mobile-internal/sla-notif/sla-va-notification-engine.md` |
| `FEAT-PORTAL-SLANOT-001` | SLA & Notification Engine | SYS-PORTAL-WEB | MOD-SLA-NOTIF | `REQ-OPS-008` | `phase2-features/portal-web/sla-notif/sla-va-notification-engine.md` |
| `FEAT-MPO-SLANOT-001` | SLA & Notification Engine | SYS-MOBILE-PORTAL | MOD-SLA-NOTIF | `REQ-OPS-008` | `phase2-features/mobile-portal/sla-notif/sla-va-notification-engine.md` |
| `FEAT-CORE-CSKH-001` | Ticket & CSKH | SYS-CORE-BACKEND | MOD-TICKET-CSKH | `REQ-OPS-009` | `phase2-features/core-backend/ticket-cskh/ticket-va-cskh.md` |
| `FEAT-ERP-CSKH-001` | Ticket & CSKH | SYS-BCERP-WEB | MOD-TICKET-CSKH | `REQ-OPS-009` | `phase2-features/bcerp-web/ticket-cskh/ticket-va-cskh.md` |
| `FEAT-MBI-CSKH-001` | Ticket & CSKH | SYS-MOBILE-INTERNAL | MOD-TICKET-CSKH | `REQ-OPS-009` | `phase2-features/mobile-internal/ticket-cskh/ticket-va-cskh.md` |
| `FEAT-PORTAL-CSKH-001` | Ticket & CSKH | SYS-PORTAL-WEB | MOD-TICKET-CSKH | `REQ-OPS-009` | `phase2-features/portal-web/ticket-cskh/ticket-va-cskh.md` |
| `FEAT-MPO-CSKH-001` | Ticket & CSKH | SYS-MOBILE-PORTAL | MOD-TICKET-CSKH | `REQ-OPS-009` | `phase2-features/mobile-portal/ticket-cskh/ticket-va-cskh.md` |
| `FEAT-CORE-CPORT-002` | Client Portal góc nhìn ops — cấp tài khoản & monitor | SYS-CORE-BACKEND | MOD-CLIENT-PORTAL | `REQ-OPS-010` | `phase2-features/core-backend/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` |
| `FEAT-ERP-CPORT-001` | Client Portal góc nhìn ops — cấp tài khoản & monitor | SYS-BCERP-WEB | MOD-CLIENT-PORTAL | `REQ-OPS-010` | `phase2-features/bcerp-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` |
| `FEAT-MBI-CPORT-001` | Client Portal góc nhìn ops — cấp tài khoản & monitor | SYS-MOBILE-INTERNAL | MOD-CLIENT-PORTAL | `REQ-OPS-010` | `phase2-features/mobile-internal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` |
| `FEAT-PORTAL-CPORT-002` | Client Portal góc nhìn ops — cấp tài khoản & monitor | SYS-PORTAL-WEB | MOD-CLIENT-PORTAL | `REQ-OPS-010` | `phase2-features/portal-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` |
| `FEAT-MPO-CPORT-001` | Client Portal góc nhìn ops — cấp tài khoản & monitor | SYS-MOBILE-PORTAL | MOD-CLIENT-PORTAL | `REQ-OPS-010` | `phase2-features/mobile-portal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` |
| `FEAT-CORE-TIKTOK-001` | TikTok Shop Monitoring | SYS-CORE-BACKEND | MOD-TIKTOK-SHOP | `REQ-OPS-011` | `phase2-features/core-backend/tiktok-shop/tiktok-shop-monitoring.md` |
| `FEAT-GW-TIKTOK-001` | TikTok Shop Monitoring | SYS-INTEGRATION-GW | MOD-TIKTOK-SHOP | `REQ-OPS-011` | `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` |
| `FEAT-ERP-TIKTOK-001` | TikTok Shop Monitoring | SYS-BCERP-WEB | MOD-TIKTOK-SHOP | `REQ-OPS-011` | `phase2-features/bcerp-web/tiktok-shop/tiktok-shop-monitoring.md` |
| `FEAT-MBI-TIKTOK-001` | TikTok Shop Monitoring | SYS-MOBILE-INTERNAL | MOD-TIKTOK-SHOP | `REQ-OPS-011` | `phase2-features/mobile-internal/tiktok-shop/tiktok-shop-monitoring.md` |
| `FEAT-CORE-CAMP-002` | A/B Testing & chiến lược campaign theo mục tiêu khách | SYS-CORE-BACKEND | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-012` | `phase2-features/core-backend/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` |
| `FEAT-GW-CAMP-002` | A/B Testing & chiến lược campaign theo mục tiêu khách | SYS-INTEGRATION-GW | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-012` | `phase2-features/integration-gw/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` |
| `FEAT-ERP-CAMP-002` | A/B Testing & chiến lược campaign theo mục tiêu khách | SYS-BCERP-WEB | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-012` | `phase2-features/bcerp-web/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` |
| `FEAT-MBI-CAMP-002` | A/B Testing & chiến lược campaign theo mục tiêu khách | SYS-MOBILE-INTERNAL | MOD-CAMPAIGN-DELIVERABLE | `REQ-OPS-012` | `phase2-features/mobile-internal/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` |

---

## 3. Session Breakdown

```
SESSION 1: Context & Planning ✅ (đã xong từ phiên trước + resume 12/09 tối)
├── Phase 0: Context Loading — Completed
└── Phase 0.5: Workload Gate — Completed (BLOCK 4.22x → user override CDG-A02 full scope)

SESSION 2 (HIỆN TẠI — resume): Feature Spec Creation (Resumable)
├── Phase 1: Scope & Feature Mapping — Completed (170 features, plan này)
├── Phase 2: Create Feature Specs — ~72 lanes (system×module), batches ≤3 song song (LPM)
│   ├── Lanes lớn (tách theo system): WALLET-RECON 24, RBAC-AUDIT 18, ARAP-PAYMENT 18, HR-CORE 12, CRM 11, DATAHUB-BI 10, QDD 6, ADACC 7...
│   └── CHECKPOINT sau mỗi system hoàn thành
├── Phase 3: Cross-Validation (max 3 iterations) — CHECKPOINT
└── Phase 4: Stakeholder Review (BA + product-expert song song, max 3) — CHECKPOINT

SESSION 3: Finalize
└── Phase 5: Safe-Write features[] registry + report — CHECKPOINT
```

### 3.1 Progress Tracking

| Phase | Name | Status | Started | Completed | Output |
|-------|------|--------|---------|-----------|--------|
| 0 | Context Loading | Completed | 2026-09-12 11:29 | 2026-09-12 11:31 | define-features-status.json |
| 0.5 | Workload Gate | Completed | 2026-09-12 11:31 | 2026-09-12 11:47 | workload-report.md (override CDG-A02) |
| 1 | Scope & Feature Mapping | Completed | 2026-09-12 19:39:29 | 2026-09-12 19:39:29 | define-features-plan.md + feature-briefs.json |
| 2 | Create Feature Specs | Pending | — | — | phase2-features/**/*.md (170 files) |
| 3 | Cross-Validation | Pending | — | — | (auto-fix in-place) |
| 4 | Stakeholder Review | Pending | — | — | phase2-features/stakeholder-review.md |
| 5 | Update Registry | Pending | — | — | registry.json + report.md |

**Overall Progress:** ~30% (2.5/6 phases)

---

## 4. File-Level Progress

| # | Output File | FEAT-ID | Status | Lines | REQ-IDs |
|---|-------------|---------|--------|-------|---------|
| 1 | `phase2-features/core-backend/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` | `FEAT-CORE-ARAP-001` | Pending | 0 | `REQ-BOD-001` |
| 2 | `phase2-features/bcerp-web/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` | `FEAT-ERP-ARAP-001` | Pending | 0 | `REQ-BOD-001` |
| 3 | `phase2-features/mobile-internal/arap-payment/phe-duyet-vuot-nguong-va-escalation.md` | `FEAT-MBI-ARAP-001` | Pending | 0 | `REQ-BOD-001` |
| 4 | `phase2-features/core-backend/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` | `FEAT-CORE-RBAC-001` | Pending | 0 | `REQ-BOD-002` |
| 5 | `phase2-features/bcerp-web/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` | `FEAT-ERP-RBAC-001` | Pending | 0 | `REQ-BOD-002` |
| 6 | `phase2-features/mobile-internal/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md` | `FEAT-MBI-RBAC-001` | Pending | 0 | `REQ-BOD-002` |
| 7 | `phase2-features/core-backend/datahub-bi/p-va-l-toan-cong-ty-realtime.md` | `FEAT-CORE-DHUB-001` | Pending | 0 | `REQ-BOD-003` |
| 8 | `phase2-features/bcerp-web/datahub-bi/p-va-l-toan-cong-ty-realtime.md` | `FEAT-ERP-DHUB-001` | Pending | 0 | `REQ-BOD-003` |
| 9 | `phase2-features/mobile-internal/datahub-bi/p-va-l-toan-cong-ty-realtime.md` | `FEAT-MBI-DHUB-001` | Pending | 0 | `REQ-BOD-003` |
| 10 | `phase2-features/core-backend/datahub-bi/bi-dashboard-dieu-hanh.md` | `FEAT-CORE-DHUB-002` | Pending | 0 | `REQ-BOD-004` |
| 11 | `phase2-features/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md` | `FEAT-ERP-DHUB-002` | Pending | 0 | `REQ-BOD-004` |
| 12 | `phase2-features/mobile-internal/datahub-bi/bi-dashboard-dieu-hanh.md` | `FEAT-MBI-DHUB-002` | Pending | 0 | `REQ-BOD-004` |
| 13 | `phase2-features/core-backend/rbac-audit/giam-sat-va-truy-xuat-audit-log.md` | `FEAT-CORE-RBAC-002` | Pending | 0 | `REQ-BOD-005` |
| 14 | `phase2-features/bcerp-web/rbac-audit/giam-sat-va-truy-xuat-audit-log.md` | `FEAT-ERP-RBAC-002` | Pending | 0 | `REQ-BOD-005` |
| 15 | `phase2-features/core-backend/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` | `FEAT-CORE-DHUB-003` | Pending | 0 | `REQ-BOD-006` |
| 16 | `phase2-features/bcerp-web/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` | `FEAT-ERP-DHUB-003` | Pending | 0 | `REQ-BOD-006` |
| 17 | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` | `FEAT-MBI-DHUB-003` | Pending | 0 | `REQ-BOD-006` |
| 18 | `phase2-features/core-backend/rbac-audit/quarterly-access-review-va-phan-quyen.md` | `FEAT-CORE-RBAC-003` | Pending | 0 | `REQ-BOD-007` |
| 19 | `phase2-features/integration-gw/rbac-audit/quarterly-access-review-va-phan-quyen.md` | `FEAT-GW-RBAC-001` | Pending | 0 | `REQ-BOD-007` |
| 20 | `phase2-features/bcerp-web/rbac-audit/quarterly-access-review-va-phan-quyen.md` | `FEAT-ERP-RBAC-003` | Pending | 0 | `REQ-BOD-007` |
| 21 | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` | `FEAT-GW-STGW-001` | Pending | 0 | `REQ-BOD-008` |
| 22 | `phase2-features/core-backend/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` | `FEAT-CORE-STGW-001` | Pending | 0 | `REQ-BOD-008` |
| 23 | `phase2-features/bcerp-web/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` | `FEAT-ERP-STGW-001` | Pending | 0 | `REQ-BOD-008` |
| 24 | `phase2-features/core-backend/rbac-audit/phe-duyet-chinh-sach-tham-so-quan-tri-va-tier.md` | `FEAT-CORE-RBAC-004` | Pending | 0 | `REQ-BOD-009` |
| 25 | `phase2-features/bcerp-web/rbac-audit/phe-duyet-chinh-sach-tham-so-quan-tri-va-tier.md` | `FEAT-ERP-RBAC-004` | Pending | 0 | `REQ-BOD-009` |
| 26 | `phase2-features/core-backend/arap-payment/phe-duyet-tai-chinh-doc-quyen-cua-cfo.md` | `FEAT-CORE-ARAP-002` | Pending | 0 | `REQ-BOD-010` |
| 27 | `phase2-features/bcerp-web/arap-payment/phe-duyet-tai-chinh-doc-quyen-cua-cfo.md` | `FEAT-ERP-ARAP-002` | Pending | 0 | `REQ-BOD-010` |
| 28 | `phase2-features/core-backend/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` | `FEAT-CORE-RBAC-005` | Pending | 0 | `REQ-BOD-011` |
| 29 | `phase2-features/bcerp-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` | `FEAT-ERP-RBAC-005` | Pending | 0 | `REQ-BOD-011` |
| 30 | `phase2-features/portal-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` | `FEAT-PORTAL-RBAC-001` | Pending | 0 | `REQ-BOD-011` |
| 31 | `phase2-features/mobile-internal/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md` | `FEAT-MBI-RBAC-002` | Pending | 0 | `REQ-BOD-011` |
| 32 | `phase2-features/core-backend/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` | `FEAT-CORE-HRCORE-001` | Pending | 0 | `REQ-HR-001` |
| 33 | `phase2-features/bcerp-web/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` | `FEAT-ERP-HRCORE-001` | Pending | 0 | `REQ-HR-001` |
| 34 | `phase2-features/core-backend/hr-core/hdld-va-canh-bao-het-han-90-60-30-ngay.md` | `FEAT-CORE-HRCORE-002` | Pending | 0 | `REQ-HR-002` |
| 35 | `phase2-features/bcerp-web/hr-core/hdld-va-canh-bao-het-han-90-60-30-ngay.md` | `FEAT-ERP-HRCORE-002` | Pending | 0 | `REQ-HR-002` |
| 36 | `phase2-features/bcerp-web/hr-core/cham-cong-va-overtime.md` | `FEAT-ERP-HRCORE-003` | Pending | 0 | `REQ-HR-003` |
| 37 | `phase2-features/core-backend/hr-core/cham-cong-va-overtime.md` | `FEAT-CORE-HRCORE-003` | Pending | 0 | `REQ-HR-003` |
| 38 | `phase2-features/bcerp-web/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` | `FEAT-ERP-HRCORE-004` | Pending | 0 | `REQ-HR-004` |
| 39 | `phase2-features/core-backend/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` | `FEAT-CORE-HRCORE-004` | Pending | 0 | `REQ-HR-004` |
| 40 | `phase2-features/bcerp-web/hr-core/self-service-nhan-vien-ess.md` | `FEAT-ERP-HRCORE-005` | Pending | 0 | `REQ-HR-005` |
| 41 | `phase2-features/core-backend/hr-core/self-service-nhan-vien-ess.md` | `FEAT-CORE-HRCORE-005` | Pending | 0 | `REQ-HR-005` |
| 42 | `phase2-features/core-backend/hr-core/cost-rate-card-version-hoa-tham-dinh-finance.md` | `FEAT-CORE-HRCORE-006` | Pending | 0 | `REQ-HR-006` |
| 43 | `phase2-features/bcerp-web/hr-core/cost-rate-card-version-hoa-tham-dinh-finance.md` | `FEAT-ERP-HRCORE-006` | Pending | 0 | `REQ-HR-006` |
| 44 | `phase2-features/core-backend/kpi-performance/kpi-3-tru-cot-tu-tong-hop-calibration.md` | `FEAT-CORE-KPI-001` | Pending | 0 | `REQ-HR-007` |
| 45 | `phase2-features/bcerp-web/kpi-performance/kpi-3-tru-cot-tu-tong-hop-calibration.md` | `FEAT-ERP-KPI-001` | Pending | 0 | `REQ-HR-007` |
| 46 | `phase2-features/bcerp-web/kpi-performance/pip-30-60-90.md` | `FEAT-ERP-KPI-002` | Pending | 0 | `REQ-HR-008` |
| 47 | `phase2-features/core-backend/kpi-performance/pip-30-60-90.md` | `FEAT-CORE-KPI-002` | Pending | 0 | `REQ-HR-008` |
| 48 | `phase2-features/core-backend/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md` | `FEAT-CORE-CAPTS-001` | Pending | 0 | `REQ-HR-009` |
| 49 | `phase2-features/bcerp-web/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md` | `FEAT-ERP-CAPTS-001` | Pending | 0 | `REQ-HR-009` |
| 50 | `phase2-features/core-backend/rbac-audit/bao-ve-pii-nhan-su-luong-confidential-restricted.md` | `FEAT-CORE-RBAC-006` | Pending | 0 | `REQ-HR-010` |
| 51 | `phase2-features/bcerp-web/rbac-audit/bao-ve-pii-nhan-su-luong-confidential-restricted.md` | `FEAT-ERP-RBAC-006` | Pending | 0 | `REQ-HR-010` |
| 52 | `phase2-features/core-backend/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` | `FEAT-CORE-WALLET-001` | Pending | 0 | `REQ-FIN-001` |
| 53 | `phase2-features/bcerp-web/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` | `FEAT-ERP-WALLET-001` | Pending | 0 | `REQ-FIN-001` |
| 54 | `phase2-features/mobile-internal/wallet-recon/so-phu-vi-tkqc-va-lenh-giao-dich-tien-tien-giu-ho.md` | `FEAT-MBI-WALLET-001` | Pending | 0 | `REQ-FIN-001` |
| 55 | `phase2-features/core-backend/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` | `FEAT-CORE-WALLET-002` | Pending | 0 | `REQ-FIN-002` |
| 56 | `phase2-features/bcerp-web/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` | `FEAT-ERP-WALLET-002` | Pending | 0 | `REQ-FIN-002` |
| 57 | `phase2-features/mobile-internal/wallet-recon/canh-bao-so-du-du-chi-3-ngay-sla-do-2h.md` | `FEAT-MBI-WALLET-002` | Pending | 0 | `REQ-FIN-002` |
| 58 | `phase2-features/core-backend/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` | `FEAT-CORE-WALLET-003` | Pending | 0 | `REQ-FIN-003` |
| 59 | `phase2-features/bcerp-web/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` | `FEAT-ERP-WALLET-003` | Pending | 0 | `REQ-FIN-003` |
| 60 | `phase2-features/mobile-internal/wallet-recon/dual-approval-dieu-chinh-so-du-doi-ty-gia-hoan-tien.md` | `FEAT-MBI-WALLET-003` | Pending | 0 | `REQ-FIN-003` |
| 61 | `phase2-features/core-backend/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` | `FEAT-CORE-WALLET-004` | Pending | 0 | `REQ-FIN-004` |
| 62 | `phase2-features/integration-gw/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` | `FEAT-GW-WALLET-001` | Pending | 0 | `REQ-FIN-004` |
| 63 | `phase2-features/bcerp-web/wallet-recon/doi-tru-3-so-tu-dong-da-tien-te-chot-va-khoa-ky.md` | `FEAT-ERP-WALLET-004` | Pending | 0 | `REQ-FIN-004` |
| 64 | `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` | `FEAT-GW-STGW-002` | Pending | 0 | `REQ-FIN-005` |
| 65 | `phase2-features/core-backend/settings-gw/api-7-nen-tang-degraded-mode-manual.md` | `FEAT-CORE-STGW-002` | Pending | 0 | `REQ-FIN-005` |
| 66 | `phase2-features/bcerp-web/settings-gw/api-7-nen-tang-degraded-mode-manual.md` | `FEAT-ERP-STGW-002` | Pending | 0 | `REQ-FIN-005` |
| 67 | `phase2-features/core-backend/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` | `FEAT-CORE-WALLET-005` | Pending | 0 | `REQ-FIN-006` |
| 68 | `phase2-features/bcerp-web/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` | `FEAT-ERP-WALLET-005` | Pending | 0 | `REQ-FIN-006` |
| 69 | `phase2-features/mobile-internal/wallet-recon/financial-hard-stop-da-khop-tien-fin-l1.md` | `FEAT-MBI-WALLET-004` | Pending | 0 | `REQ-FIN-006` |
| 70 | `phase2-features/core-backend/arap-payment/cong-no-ar-ap-aging-nhac-no.md` | `FEAT-CORE-ARAP-003` | Pending | 0 | `REQ-FIN-007` |
| 71 | `phase2-features/bcerp-web/arap-payment/cong-no-ar-ap-aging-nhac-no.md` | `FEAT-ERP-ARAP-003` | Pending | 0 | `REQ-FIN-007` |
| 72 | `phase2-features/core-backend/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` | `FEAT-CORE-ARAP-004` | Pending | 0 | `REQ-FIN-008` |
| 73 | `phase2-features/bcerp-web/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` | `FEAT-ERP-ARAP-004` | Pending | 0 | `REQ-FIN-008` |
| 74 | `phase2-features/mobile-internal/arap-payment/duyet-chi-giai-ngan-nguong-sod-delegate.md` | `FEAT-MBI-ARAP-002` | Pending | 0 | `REQ-FIN-008` |
| 75 | `phase2-features/core-backend/adaccount-cc/kyc-phap-nhan-truoc-cap-phat-tkqc.md` | `FEAT-CORE-ADACC-001` | Pending | 0 | `REQ-FIN-009` |
| 76 | `phase2-features/bcerp-web/adaccount-cc/kyc-phap-nhan-truoc-cap-phat-tkqc.md` | `FEAT-ERP-ADACC-001` | Pending | 0 | `REQ-FIN-009` |
| 77 | `phase2-features/core-backend/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` | `FEAT-CORE-WALLET-006` | Pending | 0 | `REQ-FIN-010` |
| 78 | `phase2-features/bcerp-web/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` | `FEAT-ERP-WALLET-006` | Pending | 0 | `REQ-FIN-010` |
| 79 | `phase2-features/mobile-internal/wallet-recon/aml-monitoring-t1-t6-hoan-tien-dung-nguon.md` | `FEAT-MBI-WALLET-005` | Pending | 0 | `REQ-FIN-010` |
| 80 | `phase2-features/core-backend/arap-payment/hoa-don-dien-tu-tt78-2021-nd123-2020.md` | `FEAT-CORE-ARAP-005` | Pending | 0 | `REQ-FIN-011` |
| 81 | `phase2-features/bcerp-web/arap-payment/hoa-don-dien-tu-tt78-2021-nd123-2020.md` | `FEAT-ERP-ARAP-005` | Pending | 0 | `REQ-FIN-011` |
| 82 | `phase2-features/core-backend/rbac-audit/luu-tru-chung-tu-va-audit-log-tien-10-nam-worm.md` | `FEAT-CORE-RBAC-007` | Pending | 0 | `REQ-FIN-012` |
| 83 | `phase2-features/bcerp-web/rbac-audit/luu-tru-chung-tu-va-audit-log-tien-10-nam-worm.md` | `FEAT-ERP-RBAC-007` | Pending | 0 | `REQ-FIN-012` |
| 84 | `phase2-features/integration-gw/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` | `FEAT-GW-ARAP-001` | Pending | 0 | `REQ-FIN-013` |
| 85 | `phase2-features/core-backend/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` | `FEAT-CORE-ARAP-006` | Pending | 0 | `REQ-FIN-013` |
| 86 | `phase2-features/bcerp-web/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` | `FEAT-ERP-ARAP-006` | Pending | 0 | `REQ-FIN-013` |
| 87 | `phase2-features/core-backend/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` | `FEAT-CORE-ARAP-007` | Pending | 0 | `REQ-FIN-014` |
| 88 | `phase2-features/integration-gw/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` | `FEAT-GW-ARAP-002` | Pending | 0 | `REQ-FIN-014` |
| 89 | `phase2-features/bcerp-web/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` | `FEAT-ERP-ARAP-007` | Pending | 0 | `REQ-FIN-014` |
| 90 | `phase2-features/core-backend/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` | `FEAT-CORE-DHUB-004` | Pending | 0 | `REQ-FIN-015` |
| 91 | `phase2-features/bcerp-web/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` | `FEAT-ERP-DHUB-004` | Pending | 0 | `REQ-FIN-015` |
| 92 | `phase2-features/mobile-internal/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` | `FEAT-MBI-DHUB-004` | Pending | 0 | `REQ-FIN-015` |
| 93 | `phase2-features/core-backend/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` | `FEAT-CORE-DHUB-005` | Pending | 0 | `REQ-FIN-016` |
| 94 | `phase2-features/bcerp-web/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` | `FEAT-ERP-DHUB-005` | Pending | 0 | `REQ-FIN-016` |
| 95 | `phase2-features/mobile-internal/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` | `FEAT-MBI-DHUB-005` | Pending | 0 | `REQ-FIN-016` |
| 96 | `phase2-features/portal-web/client-portal/du-lieu-vi-read-only-cho-client-portal.md` | `FEAT-PORTAL-CPORT-001` | Pending | 0 | `REQ-FIN-017` |
| 97 | `phase2-features/core-backend/client-portal/du-lieu-vi-read-only-cho-client-portal.md` | `FEAT-CORE-CPORT-001` | Pending | 0 | `REQ-FIN-017` |
| 98 | `phase2-features/core-backend/crm-pipeline/thu-nhan-lead-da-kenh-va-chong-trung-lap-anti-duplicate.md` | `FEAT-CORE-CRM-001` | Pending | 0 | `REQ-SALES-001` |
| 99 | `phase2-features/bcerp-web/crm-pipeline/thu-nhan-lead-da-kenh-va-chong-trung-lap-anti-duplicate.md` | `FEAT-ERP-CRM-001` | Pending | 0 | `REQ-SALES-001` |
| 100 | `phase2-features/core-backend/crm-pipeline/pipeline-v6-0-hard-gate-khong-ghi-nhan-khong-ton-tai-va-phan-bo-lead.md` | `FEAT-CORE-CRM-002` | Pending | 0 | `REQ-SALES-002` |
| 101 | `phase2-features/bcerp-web/crm-pipeline/pipeline-v6-0-hard-gate-khong-ghi-nhan-khong-ton-tai-va-phan-bo-lead.md` | `FEAT-ERP-CRM-002` | Pending | 0 | `REQ-SALES-002` |
| 102 | `phase2-features/core-backend/crm-pipeline/auto-scoring-k1-k12-va-tier-a-e.md` | `FEAT-CORE-CRM-003` | Pending | 0 | `REQ-SALES-003` |
| 103 | `phase2-features/bcerp-web/crm-pipeline/auto-scoring-k1-k12-va-tier-a-e.md` | `FEAT-ERP-CRM-003` | Pending | 0 | `REQ-SALES-003` |
| 104 | `phase2-features/core-backend/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` | `FEAT-CORE-CRM-004` | Pending | 0 | `REQ-SALES-004` |
| 105 | `phase2-features/bcerp-web/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` | `FEAT-ERP-CRM-004` | Pending | 0 | `REQ-SALES-004` |
| 106 | `phase2-features/mobile-internal/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md` | `FEAT-MBI-CRM-001` | Pending | 0 | `REQ-SALES-004` |
| 107 | `phase2-features/core-backend/crm-pipeline/chuyen-tier-sales-cs-va-ra-soat-quy-tier.md` | `FEAT-CORE-CRM-005` | Pending | 0 | `REQ-SALES-005` |
| 108 | `phase2-features/bcerp-web/crm-pipeline/chuyen-tier-sales-cs-va-ra-soat-quy-tier.md` | `FEAT-ERP-CRM-005` | Pending | 0 | `REQ-SALES-005` |
| 109 | `phase2-features/core-backend/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` | `FEAT-CORE-QDD-001` | Pending | 0 | `REQ-SALES-006` |
| 110 | `phase2-features/bcerp-web/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` | `FEAT-ERP-QDD-001` | Pending | 0 | `REQ-SALES-006` |
| 111 | `phase2-features/mobile-internal/quotation-dealdesk/quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` | `FEAT-MBI-QDD-001` | Pending | 0 | `REQ-SALES-006` |
| 112 | `phase2-features/core-backend/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` | `FEAT-CORE-QDD-002` | Pending | 0 | `REQ-SALES-007` |
| 113 | `phase2-features/bcerp-web/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` | `FEAT-ERP-QDD-002` | Pending | 0 | `REQ-SALES-007` |
| 114 | `phase2-features/mobile-internal/quotation-dealdesk/hop-dong-loi-nda-va-brand-safety-e-sign.md` | `FEAT-MBI-QDD-002` | Pending | 0 | `REQ-SALES-007` |
| 115 | `phase2-features/core-backend/handoff-onboard/handoff-va-onboarding-bridge.md` | `FEAT-CORE-HONB-001` | Pending | 0 | `REQ-SALES-008` |
| 116 | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md` | `FEAT-ERP-HONB-001` | Pending | 0 | `REQ-SALES-008` |
| 117 | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge.md` | `FEAT-MBI-HONB-001` | Pending | 0 | `REQ-SALES-008` |
| 118 | `phase2-features/core-backend/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` | `FEAT-CORE-COMM-001` | Pending | 0 | `REQ-SALES-009` |
| 119 | `phase2-features/bcerp-web/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` | `FEAT-ERP-COMM-001` | Pending | 0 | `REQ-SALES-009` |
| 120 | `phase2-features/mobile-internal/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` | `FEAT-MBI-COMM-001` | Pending | 0 | `REQ-SALES-009` |
| 121 | `phase2-features/core-backend/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` | `FEAT-CORE-ADACC-002` | Pending | 0 | `REQ-OPS-001` |
| 122 | `phase2-features/bcerp-web/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` | `FEAT-ERP-ADACC-002` | Pending | 0 | `REQ-OPS-001` |
| 123 | `phase2-features/integration-gw/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` | `FEAT-GW-ADACC-001` | Pending | 0 | `REQ-OPS-001` |
| 124 | `phase2-features/mobile-internal/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` | `FEAT-MBI-ADACC-001` | Pending | 0 | `REQ-OPS-001` |
| 125 | `phase2-features/core-backend/adaccount-cc/financial-hard-stop-chan-cap-phat-tkqc.md` | `FEAT-CORE-ADACC-003` | Pending | 0 | `REQ-OPS-002` |
| 126 | `phase2-features/bcerp-web/adaccount-cc/financial-hard-stop-chan-cap-phat-tkqc.md` | `FEAT-ERP-ADACC-003` | Pending | 0 | `REQ-OPS-002` |
| 127 | `phase2-features/core-backend/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-CORE-WALLET-007` | Pending | 0 | `REQ-OPS-003` |
| 128 | `phase2-features/integration-gw/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-GW-WALLET-002` | Pending | 0 | `REQ-OPS-003` |
| 129 | `phase2-features/bcerp-web/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-ERP-WALLET-007` | Pending | 0 | `REQ-OPS-003` |
| 130 | `phase2-features/mobile-internal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-MBI-WALLET-006` | Pending | 0 | `REQ-OPS-003` |
| 131 | `phase2-features/portal-web/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-PORTAL-WALLET-001` | Pending | 0 | `REQ-OPS-003` |
| 132 | `phase2-features/mobile-portal/wallet-recon/vi-tkqc-goc-ops-canh-bao-so-du-va-escalation.md` | `FEAT-MPO-WALLET-001` | Pending | 0 | `REQ-OPS-003` |
| 133 | `phase2-features/core-backend/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` | `FEAT-CORE-HONB-002` | Pending | 0 | `REQ-OPS-004` |
| 134 | `phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` | `FEAT-ERP-HONB-002` | Pending | 0 | `REQ-OPS-004` |
| 135 | `phase2-features/mobile-internal/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` | `FEAT-MBI-HONB-002` | Pending | 0 | `REQ-OPS-004` |
| 136 | `phase2-features/core-backend/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` | `FEAT-CORE-PROPLN-001` | Pending | 0 | `REQ-OPS-005` |
| 137 | `phase2-features/bcerp-web/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` | `FEAT-ERP-PROPLN-001` | Pending | 0 | `REQ-OPS-005` |
| 138 | `phase2-features/mobile-internal/proposal-planning/proposal-va-planning-workspace-stage-gate-v6-0.md` | `FEAT-MBI-PROPLN-001` | Pending | 0 | `REQ-OPS-005` |
| 139 | `phase2-features/core-backend/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-CORE-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 140 | `phase2-features/integration-gw/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-GW-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 141 | `phase2-features/bcerp-web/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-ERP-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 142 | `phase2-features/mobile-internal/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-MBI-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 143 | `phase2-features/portal-web/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-PORTAL-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 144 | `phase2-features/mobile-portal/campaign-deliverable/campaign-va-deliverable-management.md` | `FEAT-MPO-CAMP-001` | Pending | 0 | `REQ-OPS-006` |
| 145 | `phase2-features/core-backend/capacity-timesheet/capacity-va-timesheet.md` | `FEAT-CORE-CAPTS-002` | Pending | 0 | `REQ-OPS-007` |
| 146 | `phase2-features/bcerp-web/capacity-timesheet/capacity-va-timesheet.md` | `FEAT-ERP-CAPTS-002` | Pending | 0 | `REQ-OPS-007` |
| 147 | `phase2-features/mobile-internal/capacity-timesheet/capacity-va-timesheet.md` | `FEAT-MBI-CAPTS-001` | Pending | 0 | `REQ-OPS-007` |
| 148 | `phase2-features/core-backend/sla-notif/sla-va-notification-engine.md` | `FEAT-CORE-SLANOT-001` | Pending | 0 | `REQ-OPS-008` |
| 149 | `phase2-features/bcerp-web/sla-notif/sla-va-notification-engine.md` | `FEAT-ERP-SLANOT-001` | Pending | 0 | `REQ-OPS-008` |
| 150 | `phase2-features/mobile-internal/sla-notif/sla-va-notification-engine.md` | `FEAT-MBI-SLANOT-001` | Pending | 0 | `REQ-OPS-008` |
| 151 | `phase2-features/portal-web/sla-notif/sla-va-notification-engine.md` | `FEAT-PORTAL-SLANOT-001` | Pending | 0 | `REQ-OPS-008` |
| 152 | `phase2-features/mobile-portal/sla-notif/sla-va-notification-engine.md` | `FEAT-MPO-SLANOT-001` | Pending | 0 | `REQ-OPS-008` |
| 153 | `phase2-features/core-backend/ticket-cskh/ticket-va-cskh.md` | `FEAT-CORE-CSKH-001` | Pending | 0 | `REQ-OPS-009` |
| 154 | `phase2-features/bcerp-web/ticket-cskh/ticket-va-cskh.md` | `FEAT-ERP-CSKH-001` | Pending | 0 | `REQ-OPS-009` |
| 155 | `phase2-features/mobile-internal/ticket-cskh/ticket-va-cskh.md` | `FEAT-MBI-CSKH-001` | Pending | 0 | `REQ-OPS-009` |
| 156 | `phase2-features/portal-web/ticket-cskh/ticket-va-cskh.md` | `FEAT-PORTAL-CSKH-001` | Pending | 0 | `REQ-OPS-009` |
| 157 | `phase2-features/mobile-portal/ticket-cskh/ticket-va-cskh.md` | `FEAT-MPO-CSKH-001` | Pending | 0 | `REQ-OPS-009` |
| 158 | `phase2-features/core-backend/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | `FEAT-CORE-CPORT-002` | Pending | 0 | `REQ-OPS-010` |
| 159 | `phase2-features/bcerp-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | `FEAT-ERP-CPORT-001` | Pending | 0 | `REQ-OPS-010` |
| 160 | `phase2-features/mobile-internal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | `FEAT-MBI-CPORT-001` | Pending | 0 | `REQ-OPS-010` |
| 161 | `phase2-features/portal-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | `FEAT-PORTAL-CPORT-002` | Pending | 0 | `REQ-OPS-010` |
| 162 | `phase2-features/mobile-portal/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | `FEAT-MPO-CPORT-001` | Pending | 0 | `REQ-OPS-010` |
| 163 | `phase2-features/core-backend/tiktok-shop/tiktok-shop-monitoring.md` | `FEAT-CORE-TIKTOK-001` | Pending | 0 | `REQ-OPS-011` |
| 164 | `phase2-features/integration-gw/tiktok-shop/tiktok-shop-monitoring.md` | `FEAT-GW-TIKTOK-001` | Pending | 0 | `REQ-OPS-011` |
| 165 | `phase2-features/bcerp-web/tiktok-shop/tiktok-shop-monitoring.md` | `FEAT-ERP-TIKTOK-001` | Pending | 0 | `REQ-OPS-011` |
| 166 | `phase2-features/mobile-internal/tiktok-shop/tiktok-shop-monitoring.md` | `FEAT-MBI-TIKTOK-001` | Pending | 0 | `REQ-OPS-011` |
| 167 | `phase2-features/core-backend/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` | `FEAT-CORE-CAMP-002` | Pending | 0 | `REQ-OPS-012` |
| 168 | `phase2-features/integration-gw/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` | `FEAT-GW-CAMP-002` | Pending | 0 | `REQ-OPS-012` |
| 169 | `phase2-features/bcerp-web/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` | `FEAT-ERP-CAMP-002` | Pending | 0 | `REQ-OPS-012` |
| 170 | `phase2-features/mobile-internal/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` | `FEAT-MBI-CAMP-002` | Pending | 0 | `REQ-OPS-012` |

**Files Progress:** `0/170 (0%)`

---

## 5. Context Sources

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | FOUND (59 REQ, 6 systems, 19 modules) |
| phase1-handoff.json | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` | FOUND |
| Department docs | `.mc-data/docs/phase1-business/departments/` | FOUND (5 dept) |
| Business workflow | `.mc-data/docs/phase1-business/P1-02-business-workflow.md` | FOUND |
| Deferred issues | `.mc-data/work/wf-analyze-requirements/deferred-issues.md` | FOUND (DI-004 đã resolve 12/09 phiên resume) |
| Quy trình v1.1 | `documents/quy-trinh-lam-viec/` | FOUND (11 file, nhật ký file 10 §8) |
| CMS Domain Model | `documents/02_Quy_trinh_Cho_thue_TKQC.md` | FOUND |
| HR Knowledge Base | `documents/03_Quy_che_KPI_HR.md` | FOUND (MỚI — nạp 12/09 phiên resume) |
| Feature template | `.claude/doc-framework/phase2-features/` | FOUND |

---

## 6. Checkpoint Strategy (LPM — sau MỖI phase)

| Trigger | Nguong | Hanh dong |
|---------|--------|-----------|
| Context Warning | 65% | Log warning, finish batch hiện tại → checkpoint |
| System/Lane Batch Complete | Any | Save checkpoint (session-state + checkpoint.json dual write) |
| Context Checkpoint | 80% | Save checkpoint, KHÔNG spawn agent mới |
| Context Critical | 90% | Force checkpoint, stop gracefully |

---

## 7. Validation Checklist

### Pre-Execution
- [x] req-registry.json ton tai (59 REQ)
- [x] requirements[] khong rong
- [x] Dept docs co san (5 dept)
- [x] Feature template co san

### Per-File
- [ ] File non-empty
- [ ] 9 sections theo template
- [ ] REQ-IDs referenced (format: REQ-[DEPT]-[NNN])
- [ ] FEAT-ID dung format (FEAT-[SYS]-[MOD]-NNN)
- [ ] Khong co TODO/TBD
- [ ] Khong co YAML front-matter

### Post-Execution
- [ ] 100% REQ-IDs (59/59) duoc map sang >= 1 feature
- [ ] Khong co duplicate FEAT-IDs (170 IDs duy nhất)
- [ ] Stakeholder review APPROVED/APPROVED_WITH_CONDITIONS
- [ ] Registry updated, features[] populated (170 entries)
- [ ] define-features-report.md ton tai

---

## 8. Notes

1. **Fan-out per-system (ADR):** 59 REQ × systems[] = 170 feature groups — mỗi (REQ, system) là 1 FEAT-ID riêng (bài học EUREKA: KHÔNG gộp multi-system vào 1 feature). Feature cùng REQ ở systems khác được cross-reference qua notes.
2. **Thay đổi tài liệu 12/09 (phiên resume):** (a) `documents/03_Quy_che_KPI_HR.md` MỚI → nạp context cho HR-CORE/KPI/COMM/CAPTS; (b) `02_Quy_trinh_Cho_thue_TKQC.md` (CMS domain) đã có từ commit c4faf4c → context ADACC/WALLET/QDD; (c) 01/05 chỉ khác CRLF, không đổi nội dung → không ảnh hưởng scope.
3. **DI-004 đã resolve:** user định hướng "module cấu hình trong Settings để quản lý kết nối ngoại vi" → REQ-FIN-013 vendor-agnostic, STGW có phạm vi external connections; đã ghi vào deferred-issues.md + briefs.
4. **11 KXN còn mở (6,7,9,15–22):** không chặn — mọi feature brief/spec ghi assumption có tag `[KXN-n]`, không tự quyết.
5. **Phase feature = priority REQ:** HIGH→1 (46 REQ), MEDIUM→2 (13 REQ). Không có LOW.
6. **Ước lượng token (Protocol 9.3):** input context ~150K (registry + 5 dept docs + 3 nguồn documents + handoff); Phase 2: 72 lanes × (in ~6–10K + out ~170×2.5K) — tổng ước ~1.2M tokens, chạy nhiều batch có checkpoint.
