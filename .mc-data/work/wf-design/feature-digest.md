# Feature Digest — BCERP (170 features)

> Nguồn: feature-briefs.json + req-registry.json (2026-09-13). Bản nén cho agent tra nhanh; chi tiết đầy đủ ở file gốc phase2-features/ (cột file). Agent đọc file gốc CHỈ khi cần xác nhận chi tiết cụ thể.


## SYS-CORE-BACKEND — BCERP Core Backend (59 features)

### MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân (7 features)

- **FEAT-CORE-ARAP-001** Phe duyet vuot nguong  va  escalation — REQ: REQ-BOD-001 | HIGH | P1 | 3-5 days
  Phê duyệt vượt ngưỡng & escalation — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-ARAP-002** Phe duyet tai chinh doc quyen cua CFO — REQ: REQ-BOD-010 | MEDIUM | P2 | 3-5 days
  Phê duyệt tài chính độc quyền của CFO — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-ARAP-003** Cong no AR/AP + aging + nhac no — REQ: REQ-FIN-007 | HIGH | P1 | 3-5 days
  Công nợ AR/AP + aging + nhắc nợ — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-ARAP-004** Duyet chi/giai ngan: nguong, SoD, delegate — REQ: REQ-FIN-008 | HIGH | P1 | 3-5 days
  Duyệt chi/giải ngân: ngưỡng, SoD, delegate — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-ARAP-005** Hoa don dien tu TT78/2021 + NĐ123/2020 — REQ: REQ-FIN-011 | HIGH | P1 | 3-5 days
  Hóa đơn điện tử TT78/2021 + NĐ123/2020 — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-ARAP-006** Tich hop phan mem ke toan VAS hien huu — REQ: REQ-FIN-013 | MEDIUM | P2 | 3-5 days
  Tích hợp phần mềm kế toán VAS hiện hữu — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS,SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
- **FEAT-CORE-ARAP-007** Phi nen tang  va  nghia vu thue — REQ: REQ-FIN-014 | MEDIUM | P2 | 3-5 days
  Phí nền tảng & nghĩa vụ thuế — bản touchpoint SYS-CORE-BACKEND. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
### MOD-RBAC-AUDIT — RBAC & Audit Log (7 features)

- **FEAT-CORE-RBAC-001** Compensating control kiem nhiem CFO kiem CTO — REQ: REQ-BOD-002 | HIGH | P1 | 1-2 weeks
  Compensating control kiêm nhiệm CFO kiêm CTO — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-RBAC-002** Giam sat  va  truy xuat audit log — REQ: REQ-BOD-005 | HIGH | P1 | 1-2 weeks
  Giám sát & truy xuất audit log — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-RBAC-003** Quarterly access review  va  phan quyen — REQ: REQ-BOD-007 | HIGH | P1 | 1-2 weeks
  Quarterly access review & phân quyền — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
- **FEAT-CORE-RBAC-004** Phe duyet chinh sach, tham so quan tri  va  tier — REQ: REQ-BOD-009 | HIGH | P1 | 1-2 weeks
  Phê duyệt chính sách, tham số quản trị & tier — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-RBAC-005** Nen tang RBAC  va  SSO/MFA tap trung (cross-cutting) — REQ: REQ-BOD-011 | HIGH | P1 | 1-2 weeks
  Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-RBAC-006** Bao ve PII nhan su (luong Confidential/Restricted) — REQ: REQ-HR-010 | HIGH | P1 | 1-2 weeks
  Bảo vệ PII nhân sự (lương Confidential/Restricted) — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-RBAC-007** Luu tru chung tu  va  audit log tien ≥10 nam (WORM) — REQ: REQ-FIN-012 | HIGH | P1 | 1-2 weeks
  Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) — bản touchpoint SYS-CORE-BACKEND. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
### MOD-DATAHUB-BI — Data Integration Hub & Analytics — BI/BOD Dashboard (5 features)

- **FEAT-CORE-DHUB-001** P va L toan cong ty realtime — REQ: REQ-BOD-003 | HIGH | P1 | 3-5 days
  P&L toàn công ty realtime — bản touchpoint SYS-CORE-BACKEND. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-FIN-016 — P&L: FIN số liệu nguồn, BOD dashboard,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-DHUB-002** BI dashboard dieu hanh — REQ: REQ-BOD-004 | HIGH | P1 | 3-5 days
  BI dashboard điều hành — bản touchpoint SYS-CORE-BACKEND. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-DHUB-003** Alert center  va  canh bao rui ro van hanh — REQ: REQ-BOD-006 | HIGH | P1 | 3-5 days
  Alert center & cảnh báo rủi ro vận hành — bản touchpoint SYS-CORE-BACKEND. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-DHUB-004** Dashboard  va  bao cao tai chinh noi bo — REQ: REQ-FIN-015 | MEDIUM | P2 | 3-5 days
  Dashboard & báo cáo tài chính nội bộ — bản touchpoint SYS-CORE-BACKEND. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-DHUB-005** BI/BOD dashboard  va  P va L realtime — REQ: REQ-FIN-016 | MEDIUM | P2 | 3-5 days
  BI/BOD dashboard & P&L realtime — bản touchpoint SYS-CORE-BACKEND. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-BOD-003 — BOD oversight yêu cầu P&L realtime,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-SETTINGS-GW — Settings & Integration Gateway (2 features)

- **FEAT-CORE-STGW-001** Quan tri Integration Gateway  va  credentials vault (vai CTO) — REQ: REQ-BOD-008 | HIGH | P1 | 3-5 days
  Quản trị Integration Gateway & credentials vault (vai CTO) — bản touchpoint SYS-CORE-BACKEND. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-,SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
- **FEAT-CORE-STGW-002** API 7 nen tang + degraded mode manual — REQ: REQ-FIN-005 | HIGH | P1 | 3-5 days
  API 7 nền tảng + degraded mode manual — bản touchpoint SYS-CORE-BACKEND. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account CC + ví,SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
### MOD-HR-CORE — HR Core (6 features)

- **FEAT-CORE-HRCORE-001** Ho so nhan su trung tam L1–L5 + ma vai — REQ: REQ-HR-001 | HIGH | P1 | 1-2 weeks
  Hồ sơ nhân sự trung tâm L1–L5 + mã vai — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-HRCORE-002** HĐLĐ  va  canh bao het han 90/60/30 ngay — REQ: REQ-HR-002 | HIGH | P1 | 1-2 weeks
  HĐLĐ & cảnh báo hết hạn 90/60/30 ngày — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-HRCORE-003** Cham cong  va  overtime — REQ: REQ-HR-003 | HIGH | P1 | 1-2 weeks
  Chấm công & overtime — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-HRCORE-004** Nghi phep: so du tu dong  va  duyet phan cap — REQ: REQ-HR-004 | HIGH | P1 | 1-2 weeks
  Nghỉ phép: số dư tự động & duyệt phân cấp — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-HRCORE-005** Self-service nhan vien (ESS) — REQ: REQ-HR-005 | MEDIUM | P2 | 1-2 weeks
  Self-service nhân viên (ESS) — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-HRCORE-006** Cost Rate Card version hoa, tham dinh finance — REQ: REQ-HR-006 | HIGH | P1 | 1-2 weeks
  Cost Rate Card version hóa, thẩm định finance — bản touchpoint SYS-CORE-BACKEND. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
### MOD-KPI-PERFORMANCE — KPI & Performance (2 features)

- **FEAT-CORE-KPI-001** KPI 3 tru cot tu tong hop + calibration — REQ: REQ-HR-007 | HIGH | P1 | 3-5 days
  KPI 3 trụ cột tự tổng hợp + calibration — bản touchpoint SYS-CORE-BACKEND. KPI 3 trụ cột tự tổng hợp + calibration; PIP 30-60-90.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-KPI-002** PIP 30-60-90 — REQ: REQ-HR-008 | MEDIUM | P2 | 3-5 days
  PIP 30-60-90 — bản touchpoint SYS-CORE-BACKEND. KPI 3 trụ cột tự tổng hợp + calibration; PIP 30-60-90.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
### MOD-CAPACITY-TIMESHEET — Capacity & Timesheet (2 features)

- **FEAT-CORE-CAPTS-001** Duyet timesheet  va  capacity (phoi hop OPS) — REQ: REQ-HR-009 | HIGH | P1 | 3-5 days
  Duyệt timesheet & capacity (phối hợp OPS) — bản touchpoint SYS-CORE-BACKEND. Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  Deps: REQ-OPS-007 — timesheet: HR chính sách+duyệt, OPS ghi nhận,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-CAPTS-002** Capacity  va  Timesheet — REQ: REQ-OPS-007 | HIGH | P1 | 3-5 days
  Capacity & Timesheet — bản touchpoint SYS-CORE-BACKEND. Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  Deps: REQ-HR-009 — chính sách duyệt timesheet từ HR,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-WALLET-RECON — Wallet & Đối soát TKQC (7 features)

- **FEAT-CORE-WALLET-001** So phu vi TKQC  va  lenh giao dich tien (tien giu ho) — REQ: REQ-FIN-001 | HIGH | P1 | 1-2 weeks
  Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-WALLET-002** Canh bao so du du chi ≥3 ngay + SLA do 2h — REQ: REQ-FIN-002 | HIGH | P1 | 1-2 weeks
  Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-WALLET-003** Dual approval dieu chinh so du / doi ty gia / hoan tien — REQ: REQ-FIN-003 | HIGH | P1 | 1-2 weeks
  Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-WALLET-004** Đoi tru 3 so tu dong, da tien te, chot  va  khoa ky — REQ: REQ-FIN-004 | HIGH | P1 | 1-2 weeks
  Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB
- **FEAT-CORE-WALLET-005** Financial Hard Stop "da khop tien" FIN_L1 — REQ: REQ-FIN-006 | HIGH | P1 | 1-2 weeks
  Financial Hard Stop "đã khớp tiền" FIN_L1 — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn (DR handoff,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-WALLET-006** AML monitoring T1–T6 + hoan tien dung nguon — REQ: REQ-FIN-010 | HIGH | P1 | 1-2 weeks
  AML monitoring T1–T6 + hoàn tiền đúng nguồn — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-WALLET-007** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-CORE-BACKEND. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-ADACCOUNT-CC — Quản lý TKQC — Ad Account Command Center (3 features)

- **FEAT-CORE-ADACC-001** KYC phap nhan truoc cap phat TKQC — REQ: REQ-FIN-009 | HIGH | P1 | 1-2 weeks
  KYC pháp nhân trước cấp phát TKQC — bản touchpoint SYS-CORE-BACKEND. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: REQ-OPS-001/REQ-OPS-002 — KYC gate trước cấp phát TKQC,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-ADACC-002** Ad Account Command Center — registry  va  vong doi TKQC — REQ: REQ-OPS-001 | HIGH | P1 | 1-2 weeks
  Ad Account Command Center — registry & vòng đời TKQC — bản touchpoint SYS-CORE-BACKEND. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL
- **FEAT-CORE-ADACC-003** Financial Hard Stop chan cap phat TKQC — REQ: REQ-OPS-002 | HIGH | P1 | 1-2 weeks
  Financial Hard Stop chặn cấp phát TKQC — bản touchpoint SYS-CORE-BACKEND. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: REQ-FIN-006 — Financial Hard Stop: tín hiệu "đã khớp tiền" từ FIN,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
### MOD-CLIENT-PORTAL — Client Portal (2 features)

- **FEAT-CORE-CPORT-001** Du lieu vi read-only cho Client Portal — REQ: REQ-FIN-017 | MEDIUM | P2 | 3-5 days
  Dữ liệu ví read-only cho Client Portal — bản touchpoint SYS-CORE-BACKEND. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-OPS-010 — portal share model chung,SYS-CORE-BACKEND | Cross-system: SYS-PORTAL-WEB
- **FEAT-CORE-CPORT-002** Client Portal goc nhin ops — cap tai khoan  va  monitor — REQ: REQ-OPS-010 | HIGH | P1 | 3-5 days
  Client Portal góc nhìn ops — cấp tài khoản & monitor — bản touchpoint SYS-CORE-BACKEND. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-FIN-017 — portal ví read-only từ FIN,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-CRM-PIPELINE — CRM & Lead Pipeline V6.0 (5 features)

- **FEAT-CORE-CRM-001** Thu nhan lead da kenh  va  chong trung lap (anti-duplicate) — REQ: REQ-SALES-001 | HIGH | P1 | 1-2 weeks
  Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) — bản touchpoint SYS-CORE-BACKEND. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-CRM-002** Pipeline V6.0 — hard gate "khong ghi nhan = khong ton tai"  va  phan bo lead — REQ: REQ-SALES-002 | HIGH | P1 | 1-2 weeks
  Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead — bản touchpoint SYS-CORE-BACKEND. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-CRM-003** AUTO SCORING K1–K12  va  Tier A–E — REQ: REQ-SALES-003 | HIGH | P1 | 1-2 weeks
  AUTO SCORING K1–K12 & Tier A–E — bản touchpoint SYS-CORE-BACKEND. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
- **FEAT-CORE-CRM-004** Gate 1  va  Gate 2 — Go/No-Go va ky Handoff — REQ: REQ-SALES-004 | HIGH | P1 | 1-2 weeks
  Gate 1 & Gate 2 — Go/No-Go và ký Handoff — bản touchpoint SYS-CORE-BACKEND. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-CRM-005** Chuyen tier Sales → CS  va  ra soat quy tier — REQ: REQ-SALES-005 | MEDIUM | P2 | 1-2 weeks
  Chuyển tier Sales → CS & rà soát quý tier — bản touchpoint SYS-CORE-BACKEND. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB
### MOD-QUOTATION-DEALDESK — Quotation & Deal Desk (2 features)

- **FEAT-CORE-QDD-001** Quotation  va  Deal Desk — dinh muc, chiet khau phan cap, duyet GM — REQ: REQ-SALES-006 | HIGH | P1 | 3-5 days
  Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM — bản touchpoint SYS-CORE-BACKEND. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-QDD-002** Hop dong/LOI/NDA  va  Brand Safety + e-sign — REQ: REQ-SALES-007 | HIGH | P1 | 3-5 days
  Hợp đồng/LOI/NDA & Brand Safety + e-sign — bản touchpoint SYS-CORE-BACKEND. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-HANDOFF-ONBOARD — Handoff & Onboarding Bridge (2 features)

- **FEAT-CORE-HONB-001** Handoff  va  Onboarding Bridge — REQ: REQ-SALES-008 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-CORE-BACKEND. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-OPS-004 — Handoff Bridge: Sales bàn giao, OPS tiếp nhận,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
- **FEAT-CORE-HONB-002** Handoff  va  Onboarding Bridge — REQ: REQ-OPS-004 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-CORE-BACKEND. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-SALES-008 — Handoff Bridge: nguồn package từ Sales,SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-COMMISSION-QUOTA — Commission & Quota (1 features)

- **FEAT-CORE-COMM-001** Commission  va  Quota — hoa hong theo thuc nhan, clawback, coverage ≥3× — REQ: REQ-SALES-009 | MEDIUM | P2 | 3-5 days
  Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× — bản touchpoint SYS-CORE-BACKEND. Hoa hồng theo thực nhận + clawback >90 ngày; thang hoa hồng L1–L5 + quota coverage ≥3×.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-PROPOSAL-PLANNING — Proposal & Planning Workspace (1 features)

- **FEAT-CORE-PROPLN-001** Proposal  va  Planning Workspace (stage-gate V6.0) — REQ: REQ-OPS-005 | HIGH | P1 | 3-5 days
  Proposal & Planning Workspace (stage-gate V6.0) — bản touchpoint SYS-CORE-BACKEND. Stage-gate V6.0 30 stage; done-criteria machine-checkable (Deploy criteria đã phê chuẩn — KXN-10, stage-gate v1.2 bảng 2.1).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (2 features)

- **FEAT-CORE-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-CORE-BACKEND. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
- **FEAT-CORE-CAMP-002** A/B Testing  va  chien luoc campaign theo muc tieu khach — REQ: REQ-OPS-012 | MEDIUM | P2 | 3-5 days
  A/B Testing & chiến lược campaign theo mục tiêu khách — bản touchpoint SYS-CORE-BACKEND. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-SLA-NOTIF — SLA & Notification Engine (1 features)

- **FEAT-CORE-SLANOT-001** SLA  va  Notification Engine — REQ: REQ-OPS-008 | HIGH | P1 | 3-5 days
  SLA & Notification Engine — bản touchpoint SYS-CORE-BACKEND. SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TICKET-CSKH — Ticket & CSKH (1 features)

- **FEAT-CORE-CSKH-001** Ticket  va  CSKH — REQ: REQ-OPS-009 | MEDIUM | P2 | 3-5 days
  Ticket & CSKH — bản touchpoint SYS-CORE-BACKEND. Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TIKTOK-SHOP — TikTok Shop Monitoring (1 features)

- **FEAT-CORE-TIKTOK-001** TikTok Shop Monitoring — REQ: REQ-OPS-011 | MEDIUM | P2 | 3-5 days
  TikTok Shop Monitoring — bản touchpoint SYS-CORE-BACKEND. TikTok Shop Monitoring tách bạch GMV shop vs NSQC ads; sync qua GW, degraded mode manual khi mất API.
  Deps: SYS-CORE-BACKEND | Cross-system: SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL

## SYS-BCERP-WEB — BCERP Web nội bộ (58 features)

### MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân (7 features)

- **FEAT-ERP-ARAP-001** Phe duyet vuot nguong  va  escalation — REQ: REQ-BOD-001 | HIGH | P1 | 3-5 days
  Phê duyệt vượt ngưỡng & escalation — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-ARAP-002** Phe duyet tai chinh doc quyen cua CFO — REQ: REQ-BOD-010 | MEDIUM | P2 | 3-5 days
  Phê duyệt tài chính độc quyền của CFO — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-ARAP-003** Cong no AR/AP + aging + nhac no — REQ: REQ-FIN-007 | HIGH | P1 | 3-5 days
  Công nợ AR/AP + aging + nhắc nợ — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-ARAP-004** Duyet chi/giai ngan: nguong, SoD, delegate — REQ: REQ-FIN-008 | HIGH | P1 | 3-5 days
  Duyệt chi/giải ngân: ngưỡng, SoD, delegate — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-ARAP-005** Hoa don dien tu TT78/2021 + NĐ123/2020 — REQ: REQ-FIN-011 | HIGH | P1 | 3-5 days
  Hóa đơn điện tử TT78/2021 + NĐ123/2020 — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-ARAP-006** Tich hop phan mem ke toan VAS hien huu — REQ: REQ-FIN-013 | MEDIUM | P2 | 3-5 days
  Tích hợp phần mềm kế toán VAS hiện hữu — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS,SYS-BCERP-WEB | Cross-system: SYS-INTEGRATION-GW,SYS-CORE-BACKEND
- **FEAT-ERP-ARAP-007** Phi nen tang  va  nghia vu thue — REQ: REQ-FIN-014 | MEDIUM | P2 | 3-5 days
  Phí nền tảng & nghĩa vụ thuế — bản touchpoint SYS-BCERP-WEB. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW
### MOD-RBAC-AUDIT — RBAC & Audit Log (7 features)

- **FEAT-ERP-RBAC-001** Compensating control kiem nhiem CFO kiem CTO — REQ: REQ-BOD-002 | HIGH | P1 | 1-2 weeks
  Compensating control kiêm nhiệm CFO kiêm CTO — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-RBAC-002** Giam sat  va  truy xuat audit log — REQ: REQ-BOD-005 | HIGH | P1 | 1-2 weeks
  Giám sát & truy xuất audit log — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-RBAC-003** Quarterly access review  va  phan quyen — REQ: REQ-BOD-007 | HIGH | P1 | 1-2 weeks
  Quarterly access review & phân quyền — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW
- **FEAT-ERP-RBAC-004** Phe duyet chinh sach, tham so quan tri  va  tier — REQ: REQ-BOD-009 | HIGH | P1 | 1-2 weeks
  Phê duyệt chính sách, tham số quản trị & tier — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-RBAC-005** Nen tang RBAC  va  SSO/MFA tap trung (cross-cutting) — REQ: REQ-BOD-011 | HIGH | P1 | 1-2 weeks
  Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-PORTAL-WEB,SYS-MOBILE-INTERNAL
- **FEAT-ERP-RBAC-006** Bao ve PII nhan su (luong Confidential/Restricted) — REQ: REQ-HR-010 | HIGH | P1 | 1-2 weeks
  Bảo vệ PII nhân sự (lương Confidential/Restricted) — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-RBAC-007** Luu tru chung tu  va  audit log tien ≥10 nam (WORM) — REQ: REQ-FIN-012 | HIGH | P1 | 1-2 weeks
  Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM) — bản touchpoint SYS-BCERP-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
### MOD-DATAHUB-BI — Data Integration Hub & Analytics — BI/BOD Dashboard (5 features)

- **FEAT-ERP-DHUB-001** P va L toan cong ty realtime — REQ: REQ-BOD-003 | HIGH | P1 | 3-5 days
  P&L toàn công ty realtime — bản touchpoint SYS-BCERP-WEB. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-FIN-016 — P&L: FIN số liệu nguồn, BOD dashboard,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-DHUB-002** BI dashboard dieu hanh — REQ: REQ-BOD-004 | HIGH | P1 | 3-5 days
  BI dashboard điều hành — bản touchpoint SYS-BCERP-WEB. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-DHUB-003** Alert center  va  canh bao rui ro van hanh — REQ: REQ-BOD-006 | HIGH | P1 | 3-5 days
  Alert center & cảnh báo rủi ro vận hành — bản touchpoint SYS-BCERP-WEB. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-DHUB-004** Dashboard  va  bao cao tai chinh noi bo — REQ: REQ-FIN-015 | MEDIUM | P2 | 3-5 days
  Dashboard & báo cáo tài chính nội bộ — bản touchpoint SYS-BCERP-WEB. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-DHUB-005** BI/BOD dashboard  va  P va L realtime — REQ: REQ-FIN-016 | MEDIUM | P2 | 3-5 days
  BI/BOD dashboard & P&L realtime — bản touchpoint SYS-BCERP-WEB. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-BOD-003 — BOD oversight yêu cầu P&L realtime,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-SETTINGS-GW — Settings & Integration Gateway (2 features)

- **FEAT-ERP-STGW-001** Quan tri Integration Gateway  va  credentials vault (vai CTO) — REQ: REQ-BOD-008 | HIGH | P1 | 3-5 days
  Quản trị Integration Gateway & credentials vault (vai CTO) — bản touchpoint SYS-BCERP-WEB. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-,SYS-BCERP-WEB | Cross-system: SYS-INTEGRATION-GW,SYS-CORE-BACKEND
- **FEAT-ERP-STGW-002** API 7 nen tang + degraded mode manual — REQ: REQ-FIN-005 | HIGH | P1 | 3-5 days
  API 7 nền tảng + degraded mode manual — bản touchpoint SYS-BCERP-WEB. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account CC + ví,SYS-BCERP-WEB | Cross-system: SYS-INTEGRATION-GW,SYS-CORE-BACKEND
### MOD-HR-CORE — HR Core (6 features)

- **FEAT-ERP-HRCORE-001** Ho so nhan su trung tam L1–L5 + ma vai — REQ: REQ-HR-001 | HIGH | P1 | 1-2 weeks
  Hồ sơ nhân sự trung tâm L1–L5 + mã vai — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-HRCORE-002** HĐLĐ  va  canh bao het han 90/60/30 ngay — REQ: REQ-HR-002 | HIGH | P1 | 1-2 weeks
  HĐLĐ & cảnh báo hết hạn 90/60/30 ngày — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-HRCORE-003** Cham cong  va  overtime — REQ: REQ-HR-003 | HIGH | P1 | 1-2 weeks
  Chấm công & overtime — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-HRCORE-004** Nghi phep: so du tu dong  va  duyet phan cap — REQ: REQ-HR-004 | HIGH | P1 | 1-2 weeks
  Nghỉ phép: số dư tự động & duyệt phân cấp — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-HRCORE-005** Self-service nhan vien (ESS) — REQ: REQ-HR-005 | MEDIUM | P2 | 1-2 weeks
  Self-service nhân viên (ESS) — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-HRCORE-006** Cost Rate Card version hoa, tham dinh finance — REQ: REQ-HR-006 | HIGH | P1 | 1-2 weeks
  Cost Rate Card version hóa, thẩm định finance — bản touchpoint SYS-BCERP-WEB. Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
### MOD-KPI-PERFORMANCE — KPI & Performance (2 features)

- **FEAT-ERP-KPI-001** KPI 3 tru cot tu tong hop + calibration — REQ: REQ-HR-007 | HIGH | P1 | 3-5 days
  KPI 3 trụ cột tự tổng hợp + calibration — bản touchpoint SYS-BCERP-WEB. KPI 3 trụ cột tự tổng hợp + calibration; PIP 30-60-90.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-KPI-002** PIP 30-60-90 — REQ: REQ-HR-008 | MEDIUM | P2 | 3-5 days
  PIP 30-60-90 — bản touchpoint SYS-BCERP-WEB. KPI 3 trụ cột tự tổng hợp + calibration; PIP 30-60-90.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
### MOD-CAPACITY-TIMESHEET — Capacity & Timesheet (2 features)

- **FEAT-ERP-CAPTS-001** Duyet timesheet  va  capacity (phoi hop OPS) — REQ: REQ-HR-009 | HIGH | P1 | 3-5 days
  Duyệt timesheet & capacity (phối hợp OPS) — bản touchpoint SYS-BCERP-WEB. Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  Deps: REQ-OPS-007 — timesheet: HR chính sách+duyệt, OPS ghi nhận,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-CAPTS-002** Capacity  va  Timesheet — REQ: REQ-OPS-007 | HIGH | P1 | 3-5 days
  Capacity & Timesheet — bản touchpoint SYS-BCERP-WEB. Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  Deps: REQ-HR-009 — chính sách duyệt timesheet từ HR,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-WALLET-RECON — Wallet & Đối soát TKQC (7 features)

- **FEAT-ERP-WALLET-001** So phu vi TKQC  va  lenh giao dich tien (tien giu ho) — REQ: REQ-FIN-001 | HIGH | P1 | 1-2 weeks
  Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-WALLET-002** Canh bao so du du chi ≥3 ngay + SLA do 2h — REQ: REQ-FIN-002 | HIGH | P1 | 1-2 weeks
  Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-WALLET-003** Dual approval dieu chinh so du / doi ty gia / hoan tien — REQ: REQ-FIN-003 | HIGH | P1 | 1-2 weeks
  Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-WALLET-004** Đoi tru 3 so tu dong, da tien te, chot  va  khoa ky — REQ: REQ-FIN-004 | HIGH | P1 | 1-2 weeks
  Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW
- **FEAT-ERP-WALLET-005** Financial Hard Stop "da khop tien" FIN_L1 — REQ: REQ-FIN-006 | HIGH | P1 | 1-2 weeks
  Financial Hard Stop "đã khớp tiền" FIN_L1 — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn (DR handoff,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-WALLET-006** AML monitoring T1–T6 + hoan tien dung nguon — REQ: REQ-FIN-010 | HIGH | P1 | 1-2 weeks
  AML monitoring T1–T6 + hoàn tiền đúng nguồn — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-WALLET-007** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-BCERP-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-ADACCOUNT-CC — Quản lý TKQC — Ad Account Command Center (3 features)

- **FEAT-ERP-ADACC-001** KYC phap nhan truoc cap phat TKQC — REQ: REQ-FIN-009 | HIGH | P1 | 1-2 weeks
  KYC pháp nhân trước cấp phát TKQC — bản touchpoint SYS-BCERP-WEB. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: REQ-OPS-001/REQ-OPS-002 — KYC gate trước cấp phát TKQC,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-ADACC-002** Ad Account Command Center — registry  va  vong doi TKQC — REQ: REQ-OPS-001 | HIGH | P1 | 1-2 weeks
  Ad Account Command Center — registry & vòng đời TKQC — bản touchpoint SYS-BCERP-WEB. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL
- **FEAT-ERP-ADACC-003** Financial Hard Stop chan cap phat TKQC — REQ: REQ-OPS-002 | HIGH | P1 | 1-2 weeks
  Financial Hard Stop chặn cấp phát TKQC — bản touchpoint SYS-BCERP-WEB. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: REQ-FIN-006 — Financial Hard Stop: tín hiệu "đã khớp tiền" từ FIN,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
### MOD-CRM-PIPELINE — CRM & Lead Pipeline V6.0 (5 features)

- **FEAT-ERP-CRM-001** Thu nhan lead da kenh  va  chong trung lap (anti-duplicate) — REQ: REQ-SALES-001 | HIGH | P1 | 1-2 weeks
  Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) — bản touchpoint SYS-BCERP-WEB. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-CRM-002** Pipeline V6.0 — hard gate "khong ghi nhan = khong ton tai"  va  phan bo lead — REQ: REQ-SALES-002 | HIGH | P1 | 1-2 weeks
  Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead — bản touchpoint SYS-BCERP-WEB. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-CRM-003** AUTO SCORING K1–K12  va  Tier A–E — REQ: REQ-SALES-003 | HIGH | P1 | 1-2 weeks
  AUTO SCORING K1–K12 & Tier A–E — bản touchpoint SYS-BCERP-WEB. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-ERP-CRM-004** Gate 1  va  Gate 2 — Go/No-Go va ky Handoff — REQ: REQ-SALES-004 | HIGH | P1 | 1-2 weeks
  Gate 1 & Gate 2 — Go/No-Go và ký Handoff — bản touchpoint SYS-BCERP-WEB. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-CRM-005** Chuyen tier Sales → CS  va  ra soat quy tier — REQ: REQ-SALES-005 | MEDIUM | P2 | 1-2 weeks
  Chuyển tier Sales → CS & rà soát quý tier — bản touchpoint SYS-BCERP-WEB. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND
### MOD-QUOTATION-DEALDESK — Quotation & Deal Desk (2 features)

- **FEAT-ERP-QDD-001** Quotation  va  Deal Desk — dinh muc, chiet khau phan cap, duyet GM — REQ: REQ-SALES-006 | HIGH | P1 | 3-5 days
  Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM — bản touchpoint SYS-BCERP-WEB. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-QDD-002** Hop dong/LOI/NDA  va  Brand Safety + e-sign — REQ: REQ-SALES-007 | HIGH | P1 | 3-5 days
  Hợp đồng/LOI/NDA & Brand Safety + e-sign — bản touchpoint SYS-BCERP-WEB. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-HANDOFF-ONBOARD — Handoff & Onboarding Bridge (2 features)

- **FEAT-ERP-HONB-001** Handoff  va  Onboarding Bridge — REQ: REQ-SALES-008 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-BCERP-WEB. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-OPS-004 — Handoff Bridge: Sales bàn giao, OPS tiếp nhận,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
- **FEAT-ERP-HONB-002** Handoff  va  Onboarding Bridge — REQ: REQ-OPS-004 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-BCERP-WEB. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-SALES-008 — Handoff Bridge: nguồn package từ Sales,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-COMMISSION-QUOTA — Commission & Quota (1 features)

- **FEAT-ERP-COMM-001** Commission  va  Quota — hoa hong theo thuc nhan, clawback, coverage ≥3× — REQ: REQ-SALES-009 | MEDIUM | P2 | 3-5 days
  Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× — bản touchpoint SYS-BCERP-WEB. Hoa hồng theo thực nhận + clawback >90 ngày; thang hoa hồng L1–L5 + quota coverage ≥3×.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-PROPOSAL-PLANNING — Proposal & Planning Workspace (1 features)

- **FEAT-ERP-PROPLN-001** Proposal  va  Planning Workspace (stage-gate V6.0) — REQ: REQ-OPS-005 | HIGH | P1 | 3-5 days
  Proposal & Planning Workspace (stage-gate V6.0) — bản touchpoint SYS-BCERP-WEB. Stage-gate V6.0 30 stage; done-criteria machine-checkable (Deploy criteria đã phê chuẩn — KXN-10, stage-gate v1.2 bảng 2.1).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (2 features)

- **FEAT-ERP-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-BCERP-WEB. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
- **FEAT-ERP-CAMP-002** A/B Testing  va  chien luoc campaign theo muc tieu khach — REQ: REQ-OPS-012 | MEDIUM | P2 | 3-5 days
  A/B Testing & chiến lược campaign theo mục tiêu khách — bản touchpoint SYS-BCERP-WEB. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL
### MOD-SLA-NOTIF — SLA & Notification Engine (1 features)

- **FEAT-ERP-SLANOT-001** SLA  va  Notification Engine — REQ: REQ-OPS-008 | HIGH | P1 | 3-5 days
  SLA & Notification Engine — bản touchpoint SYS-BCERP-WEB. SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TICKET-CSKH — Ticket & CSKH (1 features)

- **FEAT-ERP-CSKH-001** Ticket  va  CSKH — REQ: REQ-OPS-009 | MEDIUM | P2 | 3-5 days
  Ticket & CSKH — bản touchpoint SYS-BCERP-WEB. Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-CLIENT-PORTAL — Client Portal (1 features)

- **FEAT-ERP-CPORT-001** Client Portal goc nhin ops — cap tai khoan  va  monitor — REQ: REQ-OPS-010 | HIGH | P1 | 3-5 days
  Client Portal góc nhìn ops — cấp tài khoản & monitor — bản touchpoint SYS-BCERP-WEB. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-FIN-017 — portal ví read-only từ FIN,SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TIKTOK-SHOP — TikTok Shop Monitoring (1 features)

- **FEAT-ERP-TIKTOK-001** TikTok Shop Monitoring — REQ: REQ-OPS-011 | MEDIUM | P2 | 3-5 days
  TikTok Shop Monitoring — bản touchpoint SYS-BCERP-WEB. TikTok Shop Monitoring tách bạch GMV shop vs NSQC ads; sync qua GW, degraded mode manual khi mất API.
  Deps: SYS-BCERP-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-MOBILE-INTERNAL

## SYS-MOBILE-INTERNAL — Mobile App — BCERP Internal (30 features)

### MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân (2 features)

- **FEAT-MBI-ARAP-001** Phe duyet vuot nguong  va  escalation — REQ: REQ-BOD-001 | HIGH | P1 | 3-5 days
  Phê duyệt vượt ngưỡng & escalation — bản touchpoint SYS-MOBILE-INTERNAL. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-ARAP-002** Duyet chi/giai ngan: nguong, SoD, delegate — REQ: REQ-FIN-008 | HIGH | P1 | 3-5 days
  Duyệt chi/giải ngân: ngưỡng, SoD, delegate — bản touchpoint SYS-MOBILE-INTERNAL. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-RBAC-AUDIT — RBAC & Audit Log (2 features)

- **FEAT-MBI-RBAC-001** Compensating control kiem nhiem CFO kiem CTO — REQ: REQ-BOD-002 | HIGH | P1 | 1-2 weeks
  Compensating control kiêm nhiệm CFO kiêm CTO — bản touchpoint SYS-MOBILE-INTERNAL. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-RBAC-002** Nen tang RBAC  va  SSO/MFA tap trung (cross-cutting) — REQ: REQ-BOD-011 | HIGH | P1 | 1-2 weeks
  Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) — bản touchpoint SYS-MOBILE-INTERNAL. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-PORTAL-WEB
### MOD-DATAHUB-BI — Data Integration Hub & Analytics — BI/BOD Dashboard (5 features)

- **FEAT-MBI-DHUB-001** P va L toan cong ty realtime — REQ: REQ-BOD-003 | HIGH | P1 | 3-5 days
  P&L toàn công ty realtime — bản touchpoint SYS-MOBILE-INTERNAL. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-FIN-016 — P&L: FIN số liệu nguồn, BOD dashboard,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-DHUB-002** BI dashboard dieu hanh — REQ: REQ-BOD-004 | HIGH | P1 | 3-5 days
  BI dashboard điều hành — bản touchpoint SYS-MOBILE-INTERNAL. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-DHUB-003** Alert center  va  canh bao rui ro van hanh — REQ: REQ-BOD-006 | HIGH | P1 | 3-5 days
  Alert center & cảnh báo rủi ro vận hành — bản touchpoint SYS-MOBILE-INTERNAL. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-DHUB-004** Dashboard  va  bao cao tai chinh noi bo — REQ: REQ-FIN-015 | MEDIUM | P2 | 3-5 days
  Dashboard & báo cáo tài chính nội bộ — bản touchpoint SYS-MOBILE-INTERNAL. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-DHUB-005** BI/BOD dashboard  va  P va L realtime — REQ: REQ-FIN-016 | MEDIUM | P2 | 3-5 days
  BI/BOD dashboard & P&L realtime — bản touchpoint SYS-MOBILE-INTERNAL. P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.
  Deps: REQ-BOD-003 — BOD oversight yêu cầu P&L realtime,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-WALLET-RECON — Wallet & Đối soát TKQC (6 features)

- **FEAT-MBI-WALLET-001** So phu vi TKQC  va  lenh giao dich tien (tien giu ho) — REQ: REQ-FIN-001 | HIGH | P1 | 1-2 weeks
  Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ) — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-WALLET-002** Canh bao so du du chi ≥3 ngay + SLA do 2h — REQ: REQ-FIN-002 | HIGH | P1 | 1-2 weeks
  Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-WALLET-003** Dual approval dieu chinh so du / doi ty gia / hoan tien — REQ: REQ-FIN-003 | HIGH | P1 | 1-2 weeks
  Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-WALLET-004** Financial Hard Stop "da khop tien" FIN_L1 — REQ: REQ-FIN-006 | HIGH | P1 | 1-2 weeks
  Financial Hard Stop "đã khớp tiền" FIN_L1 — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn (DR handoff,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-WALLET-005** AML monitoring T1–T6 + hoan tien dung nguon — REQ: REQ-FIN-010 | HIGH | P1 | 1-2 weeks
  AML monitoring T1–T6 + hoàn tiền đúng nguồn — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-WALLET-006** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-MOBILE-INTERNAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-CRM-PIPELINE — CRM & Lead Pipeline V6.0 (1 features)

- **FEAT-MBI-CRM-001** Gate 1  va  Gate 2 — Go/No-Go va ky Handoff — REQ: REQ-SALES-004 | HIGH | P1 | 1-2 weeks
  Gate 1 & Gate 2 — Go/No-Go và ký Handoff — bản touchpoint SYS-MOBILE-INTERNAL. Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-QUOTATION-DEALDESK — Quotation & Deal Desk (2 features)

- **FEAT-MBI-QDD-001** Quotation  va  Deal Desk — dinh muc, chiet khau phan cap, duyet GM — REQ: REQ-SALES-006 | HIGH | P1 | 3-5 days
  Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM — bản touchpoint SYS-MOBILE-INTERNAL. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-QDD-002** Hop dong/LOI/NDA  va  Brand Safety + e-sign — REQ: REQ-SALES-007 | HIGH | P1 | 3-5 days
  Hợp đồng/LOI/NDA & Brand Safety + e-sign — bản touchpoint SYS-MOBILE-INTERNAL. Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-HANDOFF-ONBOARD — Handoff & Onboarding Bridge (2 features)

- **FEAT-MBI-HONB-001** Handoff  va  Onboarding Bridge — REQ: REQ-SALES-008 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-MOBILE-INTERNAL. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-OPS-004 — Handoff Bridge: Sales bàn giao, OPS tiếp nhận,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-MBI-HONB-002** Handoff  va  Onboarding Bridge — REQ: REQ-OPS-004 | HIGH | P1 | 3-5 days
  Handoff & Onboarding Bridge — bản touchpoint SYS-MOBILE-INTERNAL. Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.
  Deps: REQ-SALES-008 — Handoff Bridge: nguồn package từ Sales,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-COMMISSION-QUOTA — Commission & Quota (1 features)

- **FEAT-MBI-COMM-001** Commission  va  Quota — hoa hong theo thuc nhan, clawback, coverage ≥3× — REQ: REQ-SALES-009 | MEDIUM | P2 | 3-5 days
  Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× — bản touchpoint SYS-MOBILE-INTERNAL. Hoa hồng theo thực nhận + clawback >90 ngày; thang hoa hồng L1–L5 + quota coverage ≥3×.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-ADACCOUNT-CC — Quản lý TKQC — Ad Account Command Center (1 features)

- **FEAT-MBI-ADACC-001** Ad Account Command Center — registry  va  vong doi TKQC — REQ: REQ-OPS-001 | HIGH | P1 | 1-2 weeks
  Ad Account Command Center — registry & vòng đời TKQC — bản touchpoint SYS-MOBILE-INTERNAL. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-INTEGRATION-GW
### MOD-PROPOSAL-PLANNING — Proposal & Planning Workspace (1 features)

- **FEAT-MBI-PROPLN-001** Proposal  va  Planning Workspace (stage-gate V6.0) — REQ: REQ-OPS-005 | HIGH | P1 | 3-5 days
  Proposal & Planning Workspace (stage-gate V6.0) — bản touchpoint SYS-MOBILE-INTERNAL. Stage-gate V6.0 30 stage; done-criteria machine-checkable (Deploy criteria đã phê chuẩn — KXN-10, stage-gate v1.2 bảng 2.1).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (2 features)

- **FEAT-MBI-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-MOBILE-INTERNAL. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
- **FEAT-MBI-CAMP-002** A/B Testing  va  chien luoc campaign theo muc tieu khach — REQ: REQ-OPS-012 | MEDIUM | P2 | 3-5 days
  A/B Testing & chiến lược campaign theo mục tiêu khách — bản touchpoint SYS-MOBILE-INTERNAL. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB
### MOD-CAPACITY-TIMESHEET — Capacity & Timesheet (1 features)

- **FEAT-MBI-CAPTS-001** Capacity  va  Timesheet — REQ: REQ-OPS-007 | HIGH | P1 | 3-5 days
  Capacity & Timesheet — bản touchpoint SYS-MOBILE-INTERNAL. Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  Deps: REQ-HR-009 — chính sách duyệt timesheet từ HR,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-SLA-NOTIF — SLA & Notification Engine (1 features)

- **FEAT-MBI-SLANOT-001** SLA  va  Notification Engine — REQ: REQ-OPS-008 | HIGH | P1 | 3-5 days
  SLA & Notification Engine — bản touchpoint SYS-MOBILE-INTERNAL. SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TICKET-CSKH — Ticket & CSKH (1 features)

- **FEAT-MBI-CSKH-001** Ticket  va  CSKH — REQ: REQ-OPS-009 | MEDIUM | P2 | 3-5 days
  Ticket & CSKH — bản touchpoint SYS-MOBILE-INTERNAL. Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-CLIENT-PORTAL — Client Portal (1 features)

- **FEAT-MBI-CPORT-001** Client Portal goc nhin ops — cap tai khoan  va  monitor — REQ: REQ-OPS-010 | HIGH | P1 | 3-5 days
  Client Portal góc nhìn ops — cấp tài khoản & monitor — bản touchpoint SYS-MOBILE-INTERNAL. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-FIN-017 — portal ví read-only từ FIN,SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-TIKTOK-SHOP — TikTok Shop Monitoring (1 features)

- **FEAT-MBI-TIKTOK-001** TikTok Shop Monitoring — REQ: REQ-OPS-011 | MEDIUM | P2 | 3-5 days
  TikTok Shop Monitoring — bản touchpoint SYS-MOBILE-INTERNAL. TikTok Shop Monitoring tách bạch GMV shop vs NSQC ads; sync qua GW, degraded mode manual khi mất API.
  Deps: SYS-MOBILE-INTERNAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB

## SYS-INTEGRATION-GW — API Integration Gateway (11 features)

### MOD-RBAC-AUDIT — RBAC & Audit Log (1 features)

- **FEAT-GW-RBAC-001** Quarterly access review  va  phan quyen — REQ: REQ-BOD-007 | HIGH | P1 | 1-2 weeks
  Quarterly access review & phân quyền — bản touchpoint SYS-INTEGRATION-GW. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-SETTINGS-GW — Settings & Integration Gateway (2 features)

- **FEAT-GW-STGW-001** Quan tri Integration Gateway  va  credentials vault (vai CTO) — REQ: REQ-BOD-008 | HIGH | P1 | 3-5 days
  Quản trị Integration Gateway & credentials vault (vai CTO) — bản touchpoint SYS-INTEGRATION-GW. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-,SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-GW-STGW-002** API 7 nen tang + degraded mode manual — REQ: REQ-FIN-005 | HIGH | P1 | 3-5 days
  API 7 nền tảng + degraded mode manual — bản touchpoint SYS-INTEGRATION-GW. Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho ph
  Deps: REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account CC + ví,SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-WALLET-RECON — Wallet & Đối soát TKQC (2 features)

- **FEAT-GW-WALLET-001** Đoi tru 3 so tu dong, da tien te, chot  va  khoa ky — REQ: REQ-FIN-004 | HIGH | P1 | 1-2 weeks
  Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ — bản touchpoint SYS-INTEGRATION-GW. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-GW-WALLET-002** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-INTEGRATION-GW. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
### MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân (2 features)

- **FEAT-GW-ARAP-001** Tich hop phan mem ke toan VAS hien huu — REQ: REQ-FIN-013 | MEDIUM | P2 | 3-5 days
  Tích hợp phần mềm kế toán VAS hiện hữu — bản touchpoint SYS-INTEGRATION-GW. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS,SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
- **FEAT-GW-ARAP-002** Phi nen tang  va  nghia vu thue — REQ: REQ-FIN-014 | MEDIUM | P2 | 3-5 days
  Phí nền tảng & nghĩa vụ thuế — bản touchpoint SYS-INTEGRATION-GW. Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB
### MOD-ADACCOUNT-CC — Quản lý TKQC — Ad Account Command Center (1 features)

- **FEAT-GW-ADACC-001** Ad Account Command Center — registry  va  vong doi TKQC — REQ: REQ-OPS-001 | HIGH | P1 | 1-2 weeks
  Ad Account Command Center — registry & vòng đời TKQC — bản touchpoint SYS-INTEGRATION-GW. Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (2 features)

- **FEAT-GW-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-INTEGRATION-GW. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB,SYS-MOBILE-PORTAL
- **FEAT-GW-CAMP-002** A/B Testing  va  chien luoc campaign theo muc tieu khach — REQ: REQ-OPS-012 | MEDIUM | P2 | 3-5 days
  A/B Testing & chiến lược campaign theo mục tiêu khách — bản touchpoint SYS-INTEGRATION-GW. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-TIKTOK-SHOP — TikTok Shop Monitoring (1 features)

- **FEAT-GW-TIKTOK-001** TikTok Shop Monitoring — REQ: REQ-OPS-011 | MEDIUM | P2 | 3-5 days
  TikTok Shop Monitoring — bản touchpoint SYS-INTEGRATION-GW. TikTok Shop Monitoring tách bạch GMV shop vs NSQC ads; sync qua GW, degraded mode manual khi mất API.
  Deps: SYS-INTEGRATION-GW | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL

## SYS-PORTAL-WEB — Client Portal Web (7 features)

### MOD-RBAC-AUDIT — RBAC & Audit Log (1 features)

- **FEAT-PORTAL-RBAC-001** Nen tang RBAC  va  SSO/MFA tap trung (cross-cutting) — REQ: REQ-BOD-011 | HIGH | P1 | 1-2 weeks
  Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) — bản touchpoint SYS-PORTAL-WEB. RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 
  Deps: SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL
### MOD-CLIENT-PORTAL — Client Portal (2 features)

- **FEAT-PORTAL-CPORT-001** Du lieu vi read-only cho Client Portal — REQ: REQ-FIN-017 | MEDIUM | P2 | 3-5 days
  Dữ liệu ví read-only cho Client Portal — bản touchpoint SYS-PORTAL-WEB. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-OPS-010 — portal share model chung,SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND
- **FEAT-PORTAL-CPORT-002** Client Portal goc nhin ops — cap tai khoan  va  monitor — REQ: REQ-OPS-010 | HIGH | P1 | 3-5 days
  Client Portal góc nhìn ops — cấp tài khoản & monitor — bản touchpoint SYS-PORTAL-WEB. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-FIN-017 — portal ví read-only từ FIN,SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-MOBILE-PORTAL
### MOD-WALLET-RECON — Wallet & Đối soát TKQC (1 features)

- **FEAT-PORTAL-WALLET-001** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-PORTAL-WEB. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-MOBILE-PORTAL
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (1 features)

- **FEAT-PORTAL-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-PORTAL-WEB. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-MOBILE-PORTAL
### MOD-SLA-NOTIF — SLA & Notification Engine (1 features)

- **FEAT-PORTAL-SLANOT-001** SLA  va  Notification Engine — REQ: REQ-OPS-008 | HIGH | P1 | 3-5 days
  SLA & Notification Engine — bản touchpoint SYS-PORTAL-WEB. SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).
  Deps: SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-MOBILE-PORTAL
### MOD-TICKET-CSKH — Ticket & CSKH (1 features)

- **FEAT-PORTAL-CSKH-001** Ticket  va  CSKH — REQ: REQ-OPS-009 | MEDIUM | P2 | 3-5 days
  Ticket & CSKH — bản touchpoint SYS-PORTAL-WEB. Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.
  Deps: SYS-PORTAL-WEB | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-MOBILE-PORTAL

## SYS-MOBILE-PORTAL — Mobile App — BC Portal (5 features)

### MOD-WALLET-RECON — Wallet & Đối soát TKQC (1 features)

- **FEAT-MPO-WALLET-001** Vi TKQC goc ops — canh bao so du  va  escalation — REQ: REQ-OPS-003 | HIGH | P1 | 1-2 weeks
  Ví TKQC góc ops — cảnh báo số dư & escalation — bản touchpoint SYS-MOBILE-PORTAL. Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).
  Deps: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN,SYS-MOBILE-PORTAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB
### MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management (1 features)

- **FEAT-MPO-CAMP-001** Campaign  va  Deliverable Management — REQ: REQ-OPS-006 | HIGH | P1 | 3-5 days
  Campaign & Deliverable Management — bản touchpoint SYS-MOBILE-PORTAL. Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".
  Deps: SYS-MOBILE-PORTAL | Cross-system: SYS-CORE-BACKEND,SYS-INTEGRATION-GW,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB
### MOD-SLA-NOTIF — SLA & Notification Engine (1 features)

- **FEAT-MPO-SLANOT-001** SLA  va  Notification Engine — REQ: REQ-OPS-008 | HIGH | P1 | 3-5 days
  SLA & Notification Engine — bản touchpoint SYS-MOBILE-PORTAL. SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).
  Deps: SYS-MOBILE-PORTAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB
### MOD-TICKET-CSKH — Ticket & CSKH (1 features)

- **FEAT-MPO-CSKH-001** Ticket  va  CSKH — REQ: REQ-OPS-009 | MEDIUM | P2 | 3-5 days
  Ticket & CSKH — bản touchpoint SYS-MOBILE-PORTAL. Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.
  Deps: SYS-MOBILE-PORTAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB
### MOD-CLIENT-PORTAL — Client Portal (1 features)

- **FEAT-MPO-CPORT-001** Client Portal goc nhin ops — cap tai khoan  va  monitor — REQ: REQ-OPS-010 | HIGH | P1 | 3-5 days
  Client Portal góc nhìn ops — cấp tài khoản & monitor — bản touchpoint SYS-MOBILE-PORTAL. Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).
  Deps: REQ-FIN-017 — portal ví read-only từ FIN,SYS-MOBILE-PORTAL | Cross-system: SYS-CORE-BACKEND,SYS-BCERP-WEB,SYS-MOBILE-INTERNAL,SYS-PORTAL-WEB