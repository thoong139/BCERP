# Bản Đồ Hệ Thống & Người Dùng — BCERP

> **Loại tài liệu:** Discovery Phase 0
> **Ngày:** 11/09/2026
> **Trạng thái:** Đã chốt → Chuyển sang Phase 1
>
> READS: `P0-01-brainstorm.md` (org context, system areas, platform, business policies), `.mc-data/work/wf-brainstorm/brainstorm-notes.md` (yêu cầu 10 experts), `documents/05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md` (cơ cấu roles chính thức)
> USED BY: `stakeholder-review.md`, `phase1-business/P1-01-project-overview.md`, `phase1-business/P1-02-business-workflow.md`, `phase3-architecture/P3-01-architecture.md`

---

## 1. Bản Đồ Hệ Thống

### 1.1. Danh Sách Hệ Thống

| STT | Tên hệ thống | Loại | Phục vụ nhóm nào | Ưu tiên xây |
|-----|-------------|------|-----------------|-------------|
| 1 | **BCERP Core Backend** (API + DB + Job Queue) | API-only | Toàn bộ nhân viên nội bộ (31–50), phục vụ nguồn dữ liệu cho Portal | GĐ1 |
| 2 | **BCERP Web nội bộ** | Web | BOD, HR, Tài chính, Sales, Vận hành, IT/SYS_ADMIN | GĐ1 |
| 3 | **Client Portal Web** | Web | Khách hàng (1.000+ khách, đa quốc gia — nhiều user/tenant phía khách) | GĐ3 (bản đầy đủ); bản rút gọn read-only có thể bật cuối GĐ2 |
| 4 | **Mobile App — BCERP Internal** (variant nội bộ) | Mobile (cross-platform) | Nhân viên nội bộ: duyệt mobile, cảnh báo push, timesheet, dashboard BOD | GĐ2 |
| 5 | **Mobile App — BC Portal** (variant khách) | Mobile (cross-platform) | Client Portal User: xem số dư ví, chi tiêu, ticket, push cảnh báo | GĐ3 |
| 6 | **API Integration Gateway** (thành phần của Core Backend) | API-only | Adapter 7 nền tảng QC + TikTok Business + webhooks lead | GĐ1 |

**Quyết định kiến trúc Mobile — 1 codebase, 2 app variant phân phối độc lập.** Lý do: (a) biên tin cậy khác nhau — variant khách phân phối public store, tenant isolation, 2FA/OTP; variant nội bộ phân phối qua MDM/internal, MFA TOTP — trộn chung 1 app làm tăng bề mặt tấn công và ràng buộc chu kỳ release của nội bộ lên app public; (b) vẫn chia sẻ chung UI component library và API client (TypeScript), tiết kiệm ~40–50% công sức so với 2 codebase riêng; (c) version/release độc lập — portal khách cần chính sách review store riêng, internal không bị phụ thuộc.

### 1.2. Quan Hệ Giữa Các Hệ Thống

**Nhóm A — BCERP Core (backend chung + auth nội bộ):**
- BCERP Web nội bộ + Mobile Internal → gọi chung BCERP Core API, chung phiên đăng nhập (Keycloak realm nội bộ), cùng DB nguồn sự thật (PostgreSQL).
- Integration Gateway nằm trong Core: scheduler + job queue kéo số liệu 7 nền tảng, ghi raw payload + fact tables; credentials trong vault mã hóa.

**Nhóm B — Client Portal (bên ngoài, tenant-isolated):**
- Client Portal Web + Mobile BC Portal → gọi **Portal API Gateway riêng**, tách network zone với Core API; chỉ đọc dữ liệu qua **view tổng hợp đã lọc theo tenant** (không bao giờ chạm trực tiếp DB nội bộ). Tenant isolation thực thi ở 2 lớp: Row-Level Security PostgreSQL + filter theo `tenant_id` ở API layer.
- Ranh giới dữ liệu portal (theo customer/legal expert): khách chỉ thấy số dư ví, chi tiêu daily, tiến độ nghiệm thu, ticket — KHÔNG thấy giá vốn, chiết khấu, P&L, dữ liệu khách khác; có disclaimer độ trễ dữ liệu.

**Tích hợp ngang (Cross-cutting Integrations):**
- **7 nền tảng QC** (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) → outbound pull hourly qua adapter riêng; chưa có quyền API developer → **degraded mode**: import statement chuẩn hóa + nhập tay gắn nhãn `manual`; backfill khi được cấp API. Rate limit → batch/queue ngay từ đầu.
- **TikTok Business API (Shop + Ads)** per-client OAuth → GMV, đơn, settlement, shop health (GĐ3); GMV chỉ tham chiếu, tách khỏi P&L agency.
- **Phần mềm kế toán hiện hữu** [Cần làm rõ: tên phần mềm + cơ chế kết nối API hay import/export] → đối chiếu sổ VAS định kỳ, xuất XML HĐĐT theo TT 78/2021.
- **Nguồn lead** (Landing page, Zalo, Fanpage, Referral, Cold) → webhook/API đẩy vào CRM, chống trùng lặp đa kênh.
- **PSP thanh toán portal** [Cần làm rõ: mô hình thẻ trực tiếp hay chuyển khoản] → nếu có thẻ, dùng hosted payment page/redirect (PCI-DSS SAQ-A).

```
  Nguồn lead (Landing/Zalo/Fanpage/Referral/Cold)
        │ webhook
        ▼
┌────────────────────────────────────────────────────────────┐
│              BCERP CORE BACKEND  (Nhóm A)                  │
│  Auth/RBAC │ Audit Log (WORM) │ Vault │ Job Queue/Redis    │
│  CRM Pipeline │ TKQC Registry │ Wallet+Hard Stop │ Đối soát │
│  Công nợ AR/AP │ Timesheet/Capacity │ Campaign │ KPI │ HR  │
└───┬──────────────┬──────────────────────┬──────────────────┘
    │ HTTPS/JWT    │ HTTPS/JWT            │ HTTPS/OTP (realm riêng)
    │ realm nội bộ │ realm nội bộ         │ tenant-isolated, chỉ view lọc
┌───▼──────────┐ ┌─▼──────────────────┐ ┌▼──────────────────────────┐
│ BCERP Web    │ │ Mobile: BCERP      │ │ Nhóm B — Client Portal    │
│ (nội bộ)     │ │ Internal (GĐ2)     │ │ Web + Mobile BC Portal    │
└──────────────┘ └────────────────────┘ │ (GĐ2-lite / GĐ3 đầy đủ)   │
                                        └───────────────────────────┘
Outbound (Integration Gateway): Meta/Google/TikTok/Bing/X/Pinterest/Yandex
Ads API (hourly, batch/queue, degraded mode) │ TikTok Business API (GĐ3)
│ Phần mềm kế toán [Cần làm rõ] │ PSP [Cần làm rõ]
```

### 1.3. Thứ Tự Xây Dựng & Phụ Thuộc

```
GIAI ĐOẠN 1 — NỀN MÓNG (niềm tin + dòng tiền):
  Org/HR registra → Auth/RBAC → Audit Log Service (WORM, hash-chain)
  Settings + Integration Gateway (vault credentials, scheduler, degraded mode)
  → TKQC Registry (Ad Account Command Center, import 2.600 TK có kiểm soát)
  → CRM & Lead Pipeline V6.0 (anti-duplicate, AUTO SCORING, Hard Gate)
  → Wallet & Đối soát tối thiểu + Financial Hard Stop

GIAI ĐOẠN 2 — VẬN HÀNH:
  Đối soát 3 chiều đầy đủ → Công nợ AR/AP & Giải ngân (approval matrix)
  Timesheet & Capacity Engine → Handoff & Onboarding (Gate 2 cần capacity check)
  Quotation & Deal Desk → Proposal & Planning → Campaign & Deliverable
  HR Core → KPI & Performance; SLA & Notification Engine → Ticket & CSKH
  Mobile Internal variant; (tùy chọn) Portal bản rút gọn read-only

GIAI ĐOẠN 3 — MỞ RỘNG:
  Client Portal đầy đủ (đa ngôn ngữ/múi giờ/tenant) → BI Dashboard & Metric
  Catalog → TikTok Shop monitoring → Commission & Quota tự động
```

**Lý do phụ thuộc:**
- **Audit log trước mọi module tiền/hợp đồng:** immutable append-only + hash-chain phải tồn tại từ lệnh giao dịch tiền đầu tiên; nếu gắn sau, dữ liệu tiền GĐ1 không có bằng chứng kiểm toán (compliance + Luật Kế toán 2015: lưu ≥10 năm).
- **RBAC/Auth trước Portal và trước mọi phân hệ:** 4-tier phân loại dữ liệu (Công khai/Nội bộ/Mật/Restricted) và SoD chỉ có ý nghĩa khi phân quyền là nền móng; tenant isolation kế thừa RBAC.
- **Settings + Integration Gateway trước TKQC Registry:** vault credentials, sync scheduler, fallback nhập tay có kiểm soát là điều kiện để import 2.600 TK đúng chuẩn (sai map 1 TK là sai cả chuỗi đối soát).
- **Wallet + Hard Stop trước cấp phát TKQC:** Financial Hard Stop "đã khớp tiền (FIN_L1)" là ràng buộc nghiệp vụ cấm bypass — không thể cấp phát TK mà chưa có ví và cơ chế chặn máy.
- **Capacity check trước Handoff Gate 2:** Gate 2 yêu cầu "xác nhận Capacity trống" của AM (SLA 4h) — Handoff chỉ machine-checkable khi Timesheet/Capacity đã chạy.
- **CRM → Quotation → Handoff → Campaign:** pipeline nghiêm ngặt "không ghi nhận vào PMS = không tồn tại"; WON phải tự sinh dự án + kiểm tra capacity trước khi triển khai.
- **Timesheet gắn nhãn trước P&L/Commission:** COGS đúng từ nguồn (Client Billable vs Internal Non-billable); hoa hồng credit theo thanh toán thực nhận → cần Công nợ (GĐ2) trước khi tự động hóa Commission (GĐ3).
- **SLA & Notification Engine trước Ticket/Portal:** ticket queue và cảnh báo portal đều đo bằng SLA clock (múi giờ, giờ làm việc) — phải định nghĩa trước khi mở kênh khách.
- **Metric catalog trước BI portal:** một định nghĩa duy nhất cho ROAS/GM/P&L/On-time Delivery, tránh "mỗi người một bảng tính" tràn sang portal.

---

## 2. Users & Roles

### 2.1. Danh Sách Roles Toàn Hệ Thống

Theo tài liệu 05: BOD, HR, Tài chính, Sales (L1–L5), Vận hành (6 mã vai, mỗi vai có Level thuộc tính L1–L5 dùng cho Capacity/KPI — RBAC phân quyền theo mã vai, không theo level). Cộng vai hệ thống + vai bên ngoài: **20 roles**.

| STT | Role ID | Tên Role | Mô tả ngắn | Dùng hệ thống nào |
|-----|---------|---------|-----------|------------------|
| 1 | `BOD_CEO` | Tổng Giám đốc | Quản trị chiến lược, duyệt chính sách, truy cập toàn bộ P&L, duyệt vượt ngưỡng (compensating control) | BCERP Web + Mobile (dashboard, duyệt) |
| 2 | `BOD_CFO_CTO` | CFO kiêm CTO (**Super Admin**) | Quản lý dòng tiền, hạn mức tín dụng TKQC, thẩm định GM; đồng thời quyền hạn tối cao hệ thống — concentration of risk, áp compensating control (mục 2.3) | BCERP Web + Mobile |
| 3 | `HR_L1` | NVHR | Hồ sơ nhân sự, chấm công, hợp đồng, nhập KPI cơ bản | BCERP Web |
| 4 | `HR_L2` | TPHR | Duyệt KPI toàn công ty, headcount, đề xuất lương/thưởng, thẩm định Cost Rate Card, quản trị PII | BCERP Web |
| 5 | `FIN_L1` | Kế toán viên | Đối soát nạp/rút TKQC, xác nhận "đã khớp tiền" (Hard Stop), kiểm tra chứng từ, rà timesheet chi phí trực tiếp | BCERP Web |
| 6 | `FIN_L2` | Kế toán trưởng | Duyệt lệnh chi/giải ngân, chốt đối soát + khóa kỳ, báo cáo tài chính nội bộ | BCERP Web |
| 7 | `SALES_L1` | Intern Sales | Tìm data khách, nhập lead thô | BCERP Web |
| 8 | `SALES_L2` | NVKD | Tư vấn, chốt HĐ MKT/cho thuê TKQC, quản pipeline cá nhân | BCERP Web + Mobile |
| 9 | `SALES_L3` | TNKD (Team Leader / SM) | Duyệt Gate 1 (Go/No-Go), Gate 2 (ký Handoff), KPI nhóm, review scoring flag | BCERP Web + Mobile |
| 10 | `SALES_L4` | TPKD | Chỉ tiêu toàn phòng, duyệt chiết khấu 10–15%, chính sách bán hàng | BCERP Web + Mobile |
| 11 | `SALES_L5` | GDKD *(quy hoạch)* | Duyệt chiết khấu >15%, deal lớn, báo cáo trực tiếp BOD | BCERP Web + Mobile |
| 12 | `OPS_PLAN` | Strategic Planner (L5 kiêm quyền TP Vận hành) | Chiến lược dự án, phân bổ ngân sách, duyệt concept, điều phối nguồn lực chung | BCERP Web |
| 13 | `OPS_AM` | Account Manager | Đầu mối khách, nghiệm thu, bảo vệ SLA, xác nhận Handoff, dashboard portfolio | BCERP Web + Mobile |
| 14 | `OPS_CONT` | Content Creator | Kế hoạch nội dung, bài viết, kịch bản | BCERP Web |
| 15 | `OPS_DES` | Designer kiêm Photography | Key visual, ấn phẩm, chụp ảnh | BCERP Web |
| 16 | `OPS_EDIT` | Editor kiêm Cameraman | Quay dựng, TVC, hậu kỳ | BCERP Web |
| 17 | `OPS_ADS` | Ads Specialist (Media Buyer) | Triển khai/tối ưu chiến dịch, xử lý cảnh báo số dư/die, đề xuất nạp | BCERP Web + Mobile |
| 18 | `SYS_ADMIN` | Quản trị hệ thống | Provisioning tài khoản, cấu hình hệ thống, vận hành vault — ủy quyền từ Super Admin, mọi hành vi bị audit | BCERP Web |
| 19 | `CLIENT_USER` | Người dùng phía khách | Xem số dư ví, chi tiêu daily, tiến độ, ticket — **chỉ tenant của mình, read-only phần tài chính** | Client Portal Web + BC Portal |
| 20 | `CLIENT_ADMIN` | Quản trị phía khách | Quản lý user trong tenant khách, nhận escalation khiếu nại | Client Portal Web |

### 2.2. Phân Quyền Tổng Quát (các role chính)

| Role | Được làm | KHÔNG được làm |
|------|---------|----------------|
| `BOD_CEO` | Xem toàn bộ P&L, dashboard, audit log; duyệt giao dịch vượt ngưỡng cao nhất; duyệt chính sách | Ghi sổ kế toán trực tiếp; tự sửa/xóa audit log (kể cả Super Admin không xóa được) |
| `BOD_CFO_CTO` | Toàn quyền cấu hình hệ thống (Super Admin), duyệt hạn mức tín dụng TKQC, duyệt thay đổi định nghĩa metric, mở/đóng kỳ | Vừa đề xuất vừa duyệt cùng một lệnh chi (SoD); tự phê duyệt giao dịch vượt ngưỡng cao nhất — phải CEO duyệt (compensating control) |
| `SYS_ADMIN` | Tạo/vô hiệu tài khoản, quản lý vault credentials, cấu hình integration | Xem nội dung nghiệp vụ nhạy cảm ngoài scope vận hành; chỉnh sửa dữ liệu giao dịch tiền; mọi thao tác bị log |
| `FIN_L1` | Đối soát 3 số, xác nhận "đã khớp tiền", đề xuất điều chỉnh số dư, import statement | Tự duyệt lệnh chi mình đề xuất; cấp phát TK khi chưa khớp tiền (bị Hard Stop chặn cứng, không có nút override) |
| `FIN_L2` | Duyệt lệnh chi/giải ngân theo ngưỡng, chốt số đối soát, khóa kỳ, duyệt trong dual approval | Mở lại kỳ đã khóa (chỉ CFO); ghi đồng thời vai đề xuất nạp |
| `HR_L2` / `HR_L1` | Quản lý hồ sơ, chấm công, quy trình KPI; L2 duyệt toàn công ty + xem lương (Restricted) | HR_L1 không xem lương mã hóa Confidential (chỉ HR_L2+); không tự duyệt timesheet của mình |
| `SALES_L2` | Tạo lead/deal/quotation, chấm scoring sơ bộ, gửi báo giá theo biểu giá, chiết khấu ≤5% | Xem giá vốn/P&L; tự duyệt Gate 1/Gate 2 (SM ký); sửa deal sau Gate 2 không qua log |
| `SALES_L3` / `SALES_L4` / `SALES_L5` | SM: Go/No-Go Gate 1, ký Gate 2, review scoring 4h; TPKD: pipeline toàn phòng, chiết khấu 10–15%; GDKD: chiết khấu >15%, deal lớn | Bypass gate không để lại audit log; TNKD không xem pipeline của nhóm khác; TPKD/GDKD không sửa scoring tier trực tiếp |
| `OPS_AM` | Xác nhận Handoff, nghiệm thu, quản ticket + SLA portfolio, đề xuất nạp TKQC, dashboard khách | Tự khớp tiền (vai FIN_L1); xem giá vốn/chiết khấu nội bộ; duyệt timesheet của chính mình |
| `OPS_ADS` | Vận hành chiến dịch, thay đổi budget/bid trong hạn mức ngày (ghi lý do), nhận cảnh báo die/số dư | Chỉnh sửa số dư ví; nạp/rút ngoài lệnh hệ thống; đổi tỷ giá |
| `OPS_CONT` / `OPS_DES` / `OPS_EDIT` | Nhận task, nhập timesheet có nhãn billable, nộp deliverable qua workflow duyệt | Gán giờ vào dự án khách khi làm dự án nội bộ (bị chặn); tự duyệt task của mình |
| `CLIENT_USER` | Xem số dư ví, chi tiêu daily, tiến độ nghiệm thu, tạo ticket, tải báo cáo có watermark | Thấy giá vốn/chiết khấu/P&L/dữ liệu tenant khác; ghi bất kỳ dữ liệu tài chính (read-only); download không giới hạn |
| `CLIENT_ADMIN` | Quản lý user phía khách trong tenant, nhận escalation | Truy cập tenant khác; tự nâng quyền mình vượt khung tenant |

### 2.3. Phân Cấp Quyền

**Nguyên tắc cấp bậc:**
- Level cao hơn xem được dữ liệu của level thấp hơn **trong cùng phòng ban**: SALES_L3 (SM) xem pipeline nhóm; L4 toàn phòng Sales; L5 toàn công ty. Tương tự trong Vận hành: Team Leader (OPS_PLAN/AM tại L5) xem workload toàn nhóm.
- RBAC = **mã vai + thuộc tính Level**; quyền dữ liệu theo 4 tier (Công khai/Nội bộ/Mật/Restricted): cost rate, lương = Restricted, chỉ CEO/CFO/HR_L2 xem, mọi lượt truy cập bị log.
- SoD 4 vai dòng tiền: **đề xuất nạp (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ**; dual approval bắt buộc cho điều chỉnh số dư, đổi tỷ giá thủ công, hoàn tiền, chiết khấu ngoài biểu.
- Compensating control cho kiêm nhiệm CFO kiêm CTO = Super Admin: CEO duyệt mọi giao dịch vượt ngưỡng cao nhất; quarterly access review do CEO chủ trì; mọi hành vi Super Admin bị audit log và việc xem log cũng bị log.

**Nguyên tắc phân cấp phê duyệt:**

| Loại giao dịch | Thực hiện | Khớp tiền / duyệt cấp 1 | Duyệt cấp cao hơn |
|---------------|-------|---------|-----|
| Nạp/rút TKQC (top-up/refund) | OPS_AM/OPS_ADS đề xuất | FIN_L1 khớp tiền (Hard Stop) → FIN_L2 duyệt chi | CFO duyệt vượt ngưỡng [Cần làm rõ: mốc VND — chốt khi chính sách hạn mức chi được phê duyệt]; refund bắt buộc về đúng TK nguồn nạp (AML) |
| Điều chỉnh số dư / đổi tỷ giá thủ công | FIN_L1 đề xuất | Dual approval FIN_L2 | Vượt ngưỡng: CFO; CFO là người đề xuất thì CEO duyệt thay |
| Chiết khấu báo giá | SALES_L2 tạo | TPKD duyệt 10–15%; NVKD tự trong ≤5% | GDKD >15%; vượt khung biểu: BOD (CEO); mọi chiết khấu ngoài biểu có audit log |
| Cấp phát TKQC mới | OPS_ADS/AM yêu cầu | Hard Stop: FIN_L1 "đã khớp tiền" — cấm bypass, cấm trạng thái chờ duyệt | Hạn mức tín dụng TKQC: CFO phê duyệt |
| Thay đổi ngân sách chiến dịch | OPS_ADS trong hạn mức ngày | Vượt hạn mức: Team Leader → AM duyệt theo bậc | Ghi lý do bắt buộc, campaign change log bất biến |
| Mở lại kỳ kế toán (period unlock) | FIN_L2 đề xuất | Chỉ CFO duyệt | Log + lý do bắt buộc |
| Định mức giá / Cost Rate Card | HR_L2 + FIN_L2 thẩm định | BOD (CEO) duyệt thay đổi | Hiệu lực theo thời gian (không sửa quá khứ) |

### 2.4. Cơ Chế Xác Thực Đề Xuất Per Hệ Thống

| Hệ thống | Cơ chế đề xuất | Lý do |
|----------|----------------|-------|
| BCERP Web nội bộ | Email + password (băm Argon2id) + session JWT ngắn hạn + refresh token xoay vòng; **MFA TOTP bắt buộc** cho `FIN_L1`, `FIN_L2`, `BOD`, `SYS_ADMIN`; bật dần toàn nội bộ từ GĐ2 | ~40 user, không cần SSO phức tạp; role tiếp xúc tiền là mục tiêu gian lận nội bộ chính (compliance-expert) |
| Client Portal Web | Email + password + **OTP 2FA bắt buộc** (email/SMS), session timeout idle 15–30 phút, log IP/khu vực truy cập, watermark dữ liệu ví read-only | Public-facing, rủi ro credential stuffing cao; yêu cầu từ legal-expert (NĐ 13/2023 + GDPR) và customer-expert |
| Mobile (2 variant) | OIDC theo realm tương ứng; token gắn device; unlock sinh trắc học local (không lưu token thô ngoài secure storage); push notification | Tiện duyệt/cảnh báo realtime; hạn chế rủi ro token bị trích xuất |
| Mobile Internal | Phân phối qua MDM/internal testing, không lên public store | Tách biên tin cậy với app khách |

**Identity Provider (IdP) đề xuất:**
- **Keycloak self-hosted, 2 realm:** `bc-erp-internal` (nội bộ, MFA TOTP) và `bc-portal` (khách, OTP, tenant claims). Lý do: OIDC/OAuth2 chuẩn mở, multi-realm tách tự nhiên nội bộ/bên ngoài (hỗ trợ tenant isolation), mã nguồn mở không phí license theo user — phù hợp 2.000–3.000 portal user, dễ mở LDAP/SSO sau này khi công ty lớn.
- Phương án B: auth service tự xây trong NestJS — chỉ cân nhắc nếu muốn giảm một thành phần hạ tầng; trade-off là phải tự bảo mật đúng chuẩn OIDC.

### 2.5. Quản Lý Tài Khoản

| Quy tắc | Nội dung đề xuất |
|---------|-----------------|
| Tạo tài khoản | Nội bộ: SYS_ADMIN tạo theo lệnh onboarding (hồ sơ HR_L1 phải tồn tại trước — "một nguồn sự thật nhân sự"); Portal: CLIENT_ADMIN tự mời/thêm user trong tenant của mình, SYS_ADMIN không tạo hộ |
| Vô hiệu hóa tài khoản | HR_L1 báo nghỉ/chuyển → SYS_ADMIN vô hiệu tài khoản ERP và **thu hồi quyền truy cập TKQC nền tảng trong 24h** (1 owner + 1 backup); portal user do CLIENT_ADMIN tự quản, tự thu hồi khi hết HĐ; tài khoản 90 ngày không đăng nhập bị khóa tự động |
| Password policy | Tối thiểu 12 ký tự (hoa/thường/số/ký tự đặc biệt), chặn password phổ biến, khóa sau 5 lần sai/15 phút, rotate 90 ngày cho role tài chính/quản trị, không tái sử dụng 5 password gần nhất |
| Không chia sẻ login TKQC | Mọi thao tác trên nền tảng QC phải qua ERP dưới danh tính cá nhân (who/when/what vào audit log); chia sẻ credentials nền tảng là vi phạm kỷ luật; credentials chỉ nằm trong vault, không bao giờ hiển thị nguyên văn |

---

## 3. Yêu Cầu Phi Chức Năng (NFR)

### 3.1. Scale & Performance

**Ước tính concurrent users:**

| Phân khúc | Estimate DAU | Concurrent (peak) | Cơ sở |
|-----------|-------------|-------------------|-------|
| Nội bộ (BCERP Web + Mobile Internal) | 40–50 | ~30 | 31–50 nhân sự, đỉnh giờ hành chính VN, khung chốt timesheet/đối soát cuối ngày |
| Client Portal (Web + BC Portal) | ~700–1.000 (30–40% của 2.000–3.000 user) | 200–300 | 1.000+ khách, nhiều user/khách, trải đa múi giờ nên đỉnh dẹt |
| API ingestion | 2.600+ TKQC × sync theo giờ × 7 adapter | Job queue, batch + burst khi backfill | Rate limit nền tảng; phải chạy đủ vòng 2.600 TK trong ≤60 phút |

**Performance targets:**

| Tiêu chí | Target | Ghi chú |
|---------|--------|---------|
| API response time (P95) | < 500 ms | API nghiệp vụ tương tác; batch ingestion không tính |
| Page load time | < 3 s | Dashboard nặng (BOD/P&L) ≤ 5 s với skeleton + cache |
| Độ tươi dữ liệu chi tiêu QC | ≤ 1 giờ | Freshness SLA (data-expert); dashboard hiển thị "dữ liệu cập nhật lúc HH:MM" + disclaimer độ trễ trên portal |
| Cảnh báo realtime | ≤ 5 phút từ lúc sync phát hiện | Số dư chạm ngưỡng, die/spike/checkpoint; SLA đỏ xử lý 2h làm việc, escalation owner → TL → AM |
| Sync throughput | Đủ vòng hourly 2.600+ TK, retry/backoff tự động, lưu raw payload | Batch/queue ngay từ GĐ1; degraded mode gắn nhãn `manual` |
| Đối soát | Đối trừ 3 số tự động ±0,1% dung sai; chốt số cuối ngày | Chênh lệch vượt dung sai phải có reason code trước khi FIN_L2 chốt kỳ |

### 3.2. Availability & Reliability

| Tiêu chí | Đề xuất | Ghi chú |
|---------|---------|---------|
| Uptime target | 99,5% nội bộ (giờ hành chính VN); **99,9% portal** tính trên khung 7×24 (khách đa múi giờ) | Portal chết trong giờ đỉnh của khách EU/US là rủi ro uy tín trực tiếp — thay "single source of truth" cho Zalo/ảnh chụp |
| RTO | ≤ 4 giờ | Khôi phục dịch vụ sau sự cố toàn phần |
| RPO | ≤ 15 phút | PostgreSQL PITR + WAL archiving; tiền/giao dịch không được mất quá 15 phút |
| Backup strategy | Full hằng ngày + PITR liên tục; mã hóa AES-256; lưu 2 vùng (primary tại VN + bản sao vùng phụ); **test phục hồi định kỳ quý** | Backup không test = không đáng tin |
| Audit log | Append-only + hash-chain, **WORM storage, retention ≥10 năm** cho sự kiện tiền & hợp đồng (Luật Kế toán 2015; ≥7 năm cho phần còn lại); việc xem log cũng bị log | Kể cả Super Admin không xóa/sửa được (compliance-expert) |
| Monitoring & alerting | Alert center tập trung (ngưỡng số dư, die, SLA breach, vượt hạn mức, job sync fail); freshness indicator trên mọi dashboard | Nền cho triết lý "TÂM" — cảnh báo sớm chủ động |
| Bảo mật vận hành | Vault credentials (chỉ Super Admin truy cập, rotate token), quarterly access review, breach notification 72h theo NĐ 13/2023, DSR tracking cho portal | Gắn pháp lý EU/US (GDPR/CCPA) |

---

## 4. Tech Stack Đề Xuất

### 4.1. Stack Chính (Khuyến Nghị)

| Layer | Công nghệ đề xuất | Lý do |
|-------|------------------|-------|
| Backend API | **Node.js (TypeScript) + NestJS** | Một ngôn ngữ full-stack (TS) giảm context-switch cho team nhỏ; NestJS có sẵn guard/interceptor cho RBAC và decorator cho audit; tuyển dev Node tại VN dồi dào; tích hợp BullMQ tự nhiên |
| Frontend Web | **React + Next.js** | Dùng chung cho BCERP nội bộ và Client Portal (2 Next.js app, 1 shared component library); ecosystem lớn, dễ tuyển; hỗ trợ i18n cho portal đa ngôn ngữ |
| Mobile | **React Native — 1 codebase, 2 app variant** (BCERP Internal + BC Portal) | Chia sẻ TypeScript types + API client + UI components với web (~40–50% tiết kiệm); OTA update (CodePush tương đương) cho sửa nhanh không qua store; đủ tốt cho use case form/dashboard/push, không cần native performance |
| Database | **PostgreSQL 16** | ACID cho giao dịch tiền; append-only tables + trigger chặn UPDATE/DELETE cho immutable audit; **Row-Level Security** thực thi tenant isolation ở tầng DB; JSONB lưu raw payload connector; số học `NUMERIC` chuẩn cho tiền tệ |
| Cache / Queue | **Redis + BullMQ** (job queue, scheduler, token-bucket rate limit, cache dashboard) | Batch 2.600 TK hourly, retry/backoff, cron sync, chống burst khi backfill; đúng bài toán ingestion đa nền tảng |
| Auth / SSO | **Keycloak 2 realms** + JWT (RS256) + refresh rotation + TOTP MFA | Chuẩn OIDC, tách realm nội bộ/portal, tenant claims cho portal, miễn phí license |
| Infrastructure | **Docker + cloud có region tại Việt Nam** (AWS/Azure/GCP — hoặc provider VN: VNG Cloud, Viettel Cloud, FPT Smart Cloud); CI/CD GitHub Actions | Tuân thủ Luật ATTT 2018/NĐ 53/2022 về lưu dữ liệu tại VN (áp dụng cho dữ liệu khách VN); container hóa giúp scale queue worker độc lập web tier; backup 2 vùng |

### 4.2. Phương Án Thay Thế (Để Tham Khảo)

- **Laravel (PHP) cho backend:** nếu team hiện hữu quen PHP, tốc độ khởi dựng nhanh, có Horizon cho queue. Trade-off: type safety yếu hơn cho logic tiền tệ đa tiền tệ và audit hash-chain (phải tự xây nhiều hơn); rủi ro cao hơn ở các chỗ "chặn cứng" (Hard Stop, SoD) cần kiểm chứng kiểu chặt.
- **.NET 8 (C#):** mạnh về enterprise, `decimal` chuẩn cho tài chính, tooling audit tốt. Trade-off: chi phí tuyển dụng/thời gian khởi động chậm hơn Node cho quy mô team nhỏ; không chia sẻ ngôn ngữ với frontend.
- **Flutter thay React Native:** render nhất quán, hot reload tốt. Trade-off: không chia sẻ code TypeScript với web/backend như RN; nếu chọn Flutter nên chấp nhận Dart riêng cho mobile.
- **Low-code (Power Platform/AppSheet) cho core:** **loại từ sớm** — không đáp ứng Hard Stop machine-checkable, immutable hash-chain, batch sync 2.600 TK và tenant isolation depth. Có thể dùng cục bộ cho form hành chính nội bộ phụ trợ, không dùng cho dòng tiền.

---

**Ngày soạn:** 11/09/2026
**Phiên bản:** 1.0

<!-- Ghi chú: Cập nhật Phiên bản khi có thay đổi lớn về systems hoặc users scope -->
