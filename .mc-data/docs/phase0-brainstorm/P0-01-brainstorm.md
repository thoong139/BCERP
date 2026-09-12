# Thông Tin Tổ Chức & Phạm Vi Dự Án — BCERP

## Mục Đích (Purpose)

Tài liệu này được điền trong `/wf-brainstorm` — giai đoạn đầu tiên của DEVKIT workflow.
**Khi nào dùng:** Khi bắt đầu một dự án mới hoặc onboard dự án hiện có.
**Output của tài liệu này được dùng bởi:** `/wf-analyze-requirements` (Phase 1 context).

---

> **Loại tài liệu:** Discovery Phase 0
> **Ngày:** 11/09/2026
> **Trạng thái:** Đã chốt → Chuyển sang Phase 1
>
> READS: (user input Phase 1+2 với chủ doanh nghiệp + biên bản brainstorm 10 experts `.mc-data/work/wf-brainstorm/brainstorm-notes.md` + phân tích chính sách `.mc-data/work/wf-brainstorm/policy-analysis.md` + tài liệu cơ cấu tổ chức `documents/05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md`)
> USED BY: `P0-02-systems-users.md`, `phase1-business/P1-01-project-overview.md`, `phase1-business/P1-02-business-workflow.md`, `phase1-business/departments/`

---

## 1. Thông Tin Cơ Bản

| Câu hỏi | Trả lời |
| --- | --- |
| Tên tổ chức / Công ty? | BC Agency — Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam (MST 0109354342, Hà Nội; 2+ văn phòng đa quốc gia) |
| Ngành nghề kinh doanh? | Digital marketing agency — trung gian quản lý tài khoản quảng cáo (TKQC) đa nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) + Facebook/TikTok marketing, TikTok Shop, Google Ads, SEO, thiết kế web/đồ họa. Đối tác chính thức: Google, TikTok, Yandex |
| Quy mô (số nhân viên ước tính)? | 31–50 nhân sự; 5 phòng ban chính thức; phục vụ 1.000+ khách hàng toàn cầu (FMCG, F&B, Retail, Beauty, B2B), 2.600+ TKQC active |
| Doanh nghiệp kiếm tiền bằng cách nào? | Agency trung gian agency ad accounts + dịch vụ marketing trọn gói; doanh thu từ phí dịch vụ/markup. Tiền nạp QC của khách là **tiền giữ hộ** (nợ phải trả), không phải doanh thu |
| Nền tảng mong muốn? | Web + Mobile |
| Thời gian mong muốn giai đoạn 1? | Không đặt mốc cứng — phát triển đầy đủ, KHÔNG MVP |
| Có ràng buộc kỹ thuật bắt buộc không? | Chưa có ràng buộc bắt buộc (stack, DB, hosting để mở). Ghi chú: hiện **chưa có quyền API developer** của các nền tảng QC → cần module Settings & Integration Gateway cho phép cấu hình tích hợp API; lộ trình 2 lớp: chạy Business Verification song song với nhập tay có cấu trúc (degraded mode gắn nhãn "manual") |

---

## 2. Phòng Ban Tham Gia

> Theo cơ cấu tổ chức chính thức tại `documents/05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md`

| STT | Tên phòng ban | Chức năng chính | Sẽ dùng hệ thống? |
| --- | --- | --- | --- |
| 1 | Ban Điều Hành (BOD) | Quản trị chiến lược, phê duyệt chính sách, truy cập toàn bộ P&L và cảnh báo rủi ro vận hành; thành phần hiện hành: CEO Bùi Thị An, CFO kiêm CTO Hoàng Nam (CMO + COO/GDKD là vị trí quy hoạch, tạm BOD kiêm nhiệm) | Có |
| 2 | Phòng Hành chính Nhân sự (HR) | Hồ sơ nhân sự theo Level L1–L5, chấm công, HĐLĐ, quản lý headcount, phê duyệt KPI toàn công ty (NVHR `HR_L1`, TPHR `HR_L2`) | Có |
| 3 | Phòng Tài chính - Kế toán | Đối soát lệnh nạp/rút TKQC, kiểm tra chứng từ, rà soát timesheet/chi phí dự án, phê duyệt chi & giải ngân, chốt số liệu đối soát doanh thu và công nợ nền tảng (Kế toán viên `FIN_L1`, Kế toán trưởng `FIN_L2`) | Có |
| 4 | Phòng Kinh Doanh (Sales) | Pipeline lead → quotation → hợp đồng, quản lý chỉ tiêu doanh số và hoa hồng theo thang bậc 5 cấp (`SALES_L1` Intern → `SALES_L5` GDKD) | Có |
| 5 | Phòng Vận hành & Marketing nội bộ (OPS) | Đảm nhiệm song song Dự án Khách hàng và Dự án Nội bộ: chiến lược, quản lý khách (AM), content, design, edit, ads (mã vai `OPS_PLAN`, `OPS_AM`, `OPS_CONT`, `OPS_DES`, `OPS_EDIT`, `OPS_ADS`); khung năng lực L1–L5; Strategic Planner L5 kiêm quyền Trưởng phòng | Có |

**Ghi chú phân vai:** toàn bộ nhân sự được quản lý theo **Level L1–L5** và **mã vai** (OPS/FIN/SALES/HR) — đây là nguồn sự thật cho RBAC, hoa hồng, cost rate, capacity và KPI. Ngoài ra có **khách hàng (bên ngoài)** sử dụng Client Portal — xem số dư ví TKQC, chi tiêu hàng ngày, tiến độ nghiệm thu, ticket (chi tiết tại Section 4).

---

## 3. Phạm Vi Hệ Thống

### 3.1. Phân hệ cần có

> Tổng hợp từ biên bản brainstorm 10 experts; thứ tự Giai đoạn theo phụ thuộc xây dựng (không phải MVP — tất cả đều trong phạm vi, phát triển đầy đủ)

| STT | Phân hệ | Phòng ban liên quan | Giai đoạn | Ưu tiên |
| --- | --- | --- | --- | --- |
| 1 | RBAC & Audit Log (phân quyền theo vai+Level, audit log bất biến append-only + hash-chain) | Toàn công ty (nền móng) | GĐ1 | Cao |
| 2 | Settings & Integration Gateway (credentials vault, sync scheduler, cấu hình tích hợp API 7 nền tảng, degraded mode nhập tay) | BOD/CTO, FIN, OPS_ADS | GĐ1 | Cao |
| 3 | HR Core (hồ sơ L1–L5, mã vai, HĐLĐ, chấm công, nghỉ phép, Cost Rate Card version hóa) | HR, toàn công ty | GĐ1 | Cao |
| 4 | CRM & Lead Pipeline V6.0 (anti-duplicate đa kênh, AUTO SCORING K1–K12, Tier A–E, hard gate "không ghi nhận = không tồn tại") | Sales | GĐ1 | Cao |
| 5 | Quotation & Deal Desk (định mức tính giá, duyệt GM, version control, giới hạn vòng sửa theo tier) | Sales, FIN | GĐ1 | Cao |
| 6 | Quản lý TKQC — Ad Account Command Center (registry trung tâm 2.600+ TK: số dư, spend limit, trạng thái, map 1 khách + 1 owner, die account tracking) | OPS_ADS, FIN | GĐ1 | Cao |
| 7 | Wallet & Đối soát TKQC (sổ phụ ví từng khách, nạp/rút qua lệnh hệ thống, Financial Hard Stop "đã khớp tiền", snapshot tỷ giá) | FIN, OPS_ADS | GĐ2 | Cao |
| 8 | Công nợ AR/AP & Giải ngân phê duyệt (aging, nhắc nợ, workflow FIN_L1 → FIN_L2 → CFO/CEO theo ngưỡng, SoD, delegate) | FIN, BOD | GĐ2 | Cao |
| 9 | Handoff & Onboarding Bridge (Handoff Package 5 nhóm checklist, ký 3 bên Sales/SM/AM, SLA 4h, milestone Day 1/7/14/30) | Sales, OPS | GĐ2 | Cao |
| 10 | Proposal & Planning Workspace (stage-gate Lifecycle V6.0, Brand Safety 7 tiêu chí chặn cứng, template theo Tier, đếm vòng review) | OPS_PLAN, Sales | GĐ2 | Cao |
| 11 | Campaign & Deliverable Management (WBS, lịch nội dung, duyệt creative, campaign change log bất biến, nghiệm thu) | OPS toàn phòng | GĐ2 | Cao |
| 12 | Capacity & Timesheet (định mức giờ/tuần L1–L5, chặn gán >100%, nhãn Client Billable/Internal bắt buộc tại nguồn) | OPS, HR | GĐ2 | Cao |
| 13 | SLA & Notification Engine (ma trận tier×priority, SLA clock đa múi giờ, pre-alert 80%, escalation tự động) | OPS_AM, CSKH | GĐ2 | Cao |
| 14 | Ticket & CSKH (queue hợp nhất portal/email/Zalo, CSAT sau đóng, escalation khiếu nại nghiêm trọng) | OPS_AM | GĐ2 | TB |
| 15 | Commission & Quota (hoa hồng L1–L5 theo thanh toán thực nhận + clawback, chỉ tiêu theo cấp, pipeline coverage ≥3x) | Sales, HR, FIN | GĐ3 | TB |
| 16 | KPI & Performance (3 trụ cột tự tổng hợp từ timesheet + task SLA + target, không nhập điểm tay, PIP, calibration HR_L2) | HR, toàn công ty | GĐ3 | Cao |
| 17 | Client Portal (Web + Mobile, đa ngôn ngữ/đa múi giờ/đa tenant: số dư ví, chi tiêu daily, tiến độ, ticket; ranh giới dữ liệu rõ ràng) | Khách hàng, OPS_AM | GĐ3 | Cao |
| 18 | Data Integration Hub & Analytics — BI/BOD Dashboard (ingestion đa nền tảng chịu lỗi, star schema một nguồn sự thật, P&L realtime, metric catalog, alert center) | BOD, FIN | GĐ3 | Cao |
| 19 | TikTok Shop Monitoring (GMV/đơn/settlement/shop health qua API theo khách; tách bạch GMV khỏi P&L agency; cảnh báo SLA — không làm OMS/WMS) | OPS, ecommerce | GĐ3 | TB |

### 3.2. Ngoài phạm vi — KHÔNG làm

- **Không có** — chủ dự án xác nhận không loại trừ mảng nào khỏi phạm vi BCERP.

Hai điểm cần xác nhận thêm (không phải loại trừ, chỉ là chưa chốt thông tin):

- **Tên phần mềm kế toán hiện hữu** [Cần làm rõ] — BCERP **tích hợp, không thay thế**; cần đối chiếu sổ VAS song song định kỳ. Cần tên cụ thể + khả năng xuất dữ liệu để thiết kế connector.
- **PMS được nhắc trong quy trình V6.0** [Cần làm rõ] — tên và phạm vi PMS cũ chưa xác định; cần xác nhận BCERP (module CRM & Lead Pipeline V6.0) thay thế hoàn toàn hay cần migration dữ liệu.

### 3.3. Hệ thống hiện có cần tích hợp

- **Phần mềm kế toán riêng** [Cần làm rõ tên] — chỉ kết nối (bút toán, chứng từ, HĐĐT), không thay thế.
- **API nền tảng quảng cáo:** Meta Graph API, Google Ads API, TikTok Business API (kéo số dư, chi tiêu hàng giờ); Bing Ads API, X Ads API, Pinterest Ads API, Yandex Ads API ở giai đoạn sau — khi có quyền developer/Business Verification.
- **Nguồn lead:** Landing page (form/webhook), Zalo OA, Fanpage (Messenger), referral/cold data — đưa vào CRM qua anti-duplicate matching.
- **Google Drive** — lưu trữ proposal/tài liệu trong giai đoạn chuyển tiếp; sau đó hợp nhất vào quản lý tài liệu của BCERP.
- **Google Sheets/Excel** — nguồn import dữ liệu mở sổ (2.600+ TKQC, khách hàng, cost rate) trong migration; không duy trì song song sau go-live.

---

## 4. Đối Tượng Người Dùng Theo Hệ Thống

### 4.1. Bảng Ánh Xạ Hệ Thống → Đối Tượng Người Dùng

| STT | Hệ thống / Phân hệ | Loại | Đối tượng người dùng | Ghi chú |
| --- | --- | --- | --- | --- |
| 1 | ERP nội bộ (toàn bộ 19 phân hệ §3.1) | Web | Nhân viên toàn công ty: 5 phòng ban, Level L1–L5, TL/TP, BOD, Admin | Đăng nhập nội bộ, RBAC theo mã vai + Level; tài khoản do Admin/CTO tạo, không đăng ký tự do |
| 2 | Client Portal | Web + Mobile (cross-platform) | Khách hàng doanh nghiệp (1.000+ KH đa quốc gia, nhiều user/roles mỗi khách) | Truy cập đối ngoại qua đăng nhập được cấp; tenant isolation tuyệt đối giữa các khách; 2FA/OTP; đa ngôn ngữ + đa múi giờ |
| 3 | Mobile App nội bộ | Web + Mobile | AM, Sales, Quản lý (TL/TP), BOD — duyệt và theo dõi khi di chuyển | Dùng chung backend với ERP; trọng tâm: phê duyệt (giải ngân, Gate 1/Gate 2, GM), cảnh báo realtime (số dư ví, SLA breach), dashboard |

**Loại hệ thống:** `Web` / `Mobile (cross-platform)`.

### 4.2. Phân Loại Nhóm Người Dùng

| Nhóm người dùng | Mô tả | Dùng hệ thống nào | Cần đăng nhập? |
| --- | --- | --- | --- |
| Nhân viên nội bộ (5 phòng ban) | Thực thi hằng ngày: sales ghi lead, OPS ghi timesheet/task, FIN đối soát, HR quản lý hồ sơ — theo Level L1–L5 và mã vai | ERP nội bộ (Web) + Mobile nội bộ | Có |
| Quản lý / Team Leader / Trưởng phòng | SALES_L3 TNKD, OPS L5 (Planner kiêm TP), FIN_L2 Kế toán trưởng, HR_L2 TPHR — duyệt phân cấp, phân công capacity | ERP nội bộ + Mobile nội bộ | Có |
| BOD | CEO, CFO kiêm CTO — P&L toàn công ty, phê duyệt vượt ngưỡng, tra cứu audit log, cảnh báo rủi ro | ERP nội bộ (dashboard BOD) + Mobile nội bộ | Có |
| Admin hệ thống | CTO/Super Admin — cấu hình tích hợp API, quản trị credentials vault, RBAC, access review | ERP nội bộ (Settings & Integration Gateway) | Có |
| Khách hàng | Doanh nghiệp đa quốc gia dùng dịch vụ BC; mỗi khách là một tenant với nhiều user/roles tự quản | Client Portal (Web + Mobile) | Có (tài khoản do AM cấp/kích hoạt tại milestone onboarding) |

### 4.3. Lưu Ý Kiến Trúc Sơ Bộ

- ERP nội bộ + Mobile nội bộ → **dùng chung backend + auth layer**: một codebase API, RBAC tập trung, mobile chỉ là client kênh duyệt/cảnh báo.
- Client Portal là hệ thống **đối ngoại multi-tenant** → tenant isolation bắt buộc, bảo mật tầng riêng (2FA/OTP, rate limiting, session timeout, log IP), API công khai cần được thiết kế tách vùng với API nội bộ.
- **RBAC phải làm từ sớm**: 1 người – nhiều vai (CFO kiêm CTO, Planner kiêm TP OPS), tách xung đột phê duyệt (người ghi timesheet không tự duyệt), compensating control cho kiêm nhiệm (CEO duyệt vượt ngưỡng, quarterly access review).
- **Integration/API gateway trung tâm** cho 7 nền tảng QC: vault mã hóa credentials, batch/queue chống rate limit với 2.600+ TK, retry/backoff, degraded mode nhập tay gắn nhãn "manual" — chỉ trông API sẽ khiến P&L chết khi connector lỗi.
- **Immutable audit log là cross-cutting concern từ ngày đầu**: mọi giao dịch tiền/hợp đồng ghi qua cùng một event store append-only (old→new value + reason-code + hash-chain); kể cả Super Admin không xóa/sửa; việc xem log cũng bị log.
- P&L realtime đọc từ **dữ liệu hợp nhất (star schema)** với conformed dimensions (Khách, Dự án, TKQC, Nền tảng, Nhân sự cost rate SCD2) — thiết kế data model ngay từ GĐ1 để chấm dứt "mỗi người một bảng tính".

---

## 5. Chính Sách & Tuân Thủ

### 5.0. Đánh Giá Mức Độ Cần Chính Sách

| Tiêu chí | Giá trị |
| --- | --- |
| Loại dự án (`project_complexity`) | ENTERPRISE |
| Số phòng ban tham gia | 5 |
| Có modules quản trị/vận hành? | Có (tài chính, đối soát, hoa hồng, nhân sự, RBAC, audit) |
| Keywords phát hiện | ERP, quản trị, kế toán, nhân sự, đối soát, công nợ, hoa hồng/commission, ví/tiền giữ hộ, giải ngân |
| **Cần phân tích chính sách?** | **Có** — phân tích đầy đủ theo mức ENTERPRISE (gồm cả chính sách experts chủ động đề xuất) |

### 5.1. Tuân Thủ Pháp Lý & Quy Định

> Phân tích bởi `legal-expert` + `compliance-expert`

| Quy định / Luật | Áp dụng? | Yêu cầu cụ thể với dự án | Ưu tiên |
| --- | --- | --- | --- |
| Luật Quảng cáo 2012 (+ sửa đổi) | Có | SP hạn chế cần giấy phép — ERP lưu hồ sơ pháp lý sản phẩm, gắn Knockout K1 trong AUTO SCORING | Cao |
| Nghị định 13/2023/NĐ-CP — bảo vệ dữ liệu cá nhân | Có | Cơ sở pháp lý xử lý, phân quyền truy cập, thông báo vi phạm 72h, kiểm soát retention, DSR tracking | Cao |
| TT 78/2021/TT-BTC + NĐ 123/2020 — hóa đơn điện tử | Có | Xuất/kết nối HĐĐT mã cơ quan thuế, chuẩn XML, lưu trữ đúng quy định | Cao |
| Luật ATTT 2018 / NĐ 53/2022 | Có | Lưu dữ liệu tại VN (khi áp dụng), kiểm soát Client Portal truy cập từ nước ngoài | Cao |
| Luật Kế toán 2015 | Có | Hợp đồng + chứng từ đối soát lưu ≥10 năm; retention policy cấu hình được trong hệ thống | Cao |
| GDPR + CCPA (khách EU/US) | Có | DPA với khách, phân vai controller/processor, DSAR, transfer mechanism — tránh phạt tới 4% doanh thu | Cao |
| Luật GDTĐT 2023 / NĐ 91/2022 | Có | Chữ ký số/e-sign cho hợp đồng, LOI | TB |
| Hợp đồng đa quốc gia | Có | Phân định trách nhiệm và luật áp dụng với khách đa quốc gia; thanh toán đa tiền tệ | TB |
| Ads Policy nền tảng (Meta/Google/TikTok/Yandex) | Có | Business Verification, chống gian lận và resale TKQC, theo dõi trạng thái tuân thủ từng TK | Cao |

> **Ghi chú:** Đây là phân tích khởi điểm từ góc độ chuyên gia nội bộ — **cần luật sư VN chuyên dữ liệu/công nghệ và auditor độc lập xác nhận** trước khi trở thành bắt buộc thiết kế. Các điểm chưa xác nhận: mô hình thanh toán Portal (thẻ trực tiếp hay chuyển khoản), chính sách hoàn tiền, phương án phân tách quyền CFO/CTO kiêm nhiệm.

### 5.2. Chính Sách Công ty

> Chủ doanh nghiệp trả lời "Chưa có" cho cả 12/12 lĩnh vực tại Phase 2

| Lĩnh vực | Chính sách | Trạng thái | Ghi chú đặc thù |
| --- | --- | --- | --- |
| **Khách hàng** | Phân loại khách hàng theo tier (Tier A–E) | Chưa có | Tier sinh từ AUTO SCORING (CQ 30/25/20/15/10); hệ quả vận hành theo tier (AM, SLA, portal) |
| **Bán hàng** | Bảng giá & ma trận chiết khấu | Chưa có | Cần phân cấp duyệt: NVKD ≤5% → TPKD 10–15% → GDKD >15% → vượt lên BOD |
| **Bán hàng** | Hoa hồng Sales L1–L5 & chỉ tiêu (Quota) | Chưa có | Chưa có quy tắc → rủi ro tranh chấp "deal credit cho ai" |
| **Bán hàng** | Hợp đồng, LOI, NDA & pháp lý | Chưa có | Cần mẫu chuẩn IN/OUT of scope, nạp trước 100% NSQC, Brand Safety clause |
| **Vận hành** | Quản lý & cấp phát TKQC | Chưa có | Cần Financial Hard Stop "đã khớp tiền" từ FIN_L1 |
| **Tài chính** | Đối soát & công nợ nền tảng | Chưa có | Đang thủ công bằng ảnh chụp màn hình/Sheets |
| **Nhân sự** | Timesheet & Capacity | Chưa có | Chưa có định mức giờ/tuần L1–L5; P&L chưa tách billable/non-billable |
| **Vận hành** | SLA khách hàng | Chưa có | Khách đa quốc gia — cần định nghĩa SLA clock đa múi giờ |
| **Nhân sự** | Nhân sự hành chính (hồ sơ, cost rate) | Chưa có | Tài liệu cơ cấu tổ chức đã có khung vai/Level, chưa có chính sách vận hành |
| **Nhân sự** | KPI & hiệu suất | Chưa có | Hiện KPI cảm tính — cần 3 trụ cột tự tổng hợp |
| **Mua hàng** | Hạn mức chi, giải ngân & SoD | Chưa có | Cần ma trận FIN_L1 → FIN_L2 → CFO/CEO theo ngưỡng giá trị |
| **Công nghệ** | RBAC, backup/DR & change management | Chưa có | Credentials API nền tảng là tài sản nhạy cảm bậc nhất |

### 5.3. Chính Sách Cần Xây Dựng / Bổ Sung

> `final_policy_gaps[] = user_gaps ∪ expert_recommended_gaps` (dedup 12 user gaps + 35 chủ đề expert → 20 chính sách). Kết quả lưu tại: `phase0-brainstorm/policies/[ten-chinh-sach].md`

| STT | Chính sách | Nguồn | Agent phụ trách | Nội dung cốt lõi sẽ soạn | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| 1 | Phân loại khách hàng theo Tier A–E — `phan-loai-khach-hang-tier.md` | User gap 1 + Expert | `sales-expert` | Tiêu chí định tính + định lượng từ AUTO SCORING; hệ quả vận hành theo tier (AM assignment, SLA, portal, escalation); chuyển tier Sales → CS; rà soát quý theo win rate | Bắt buộc |
| 2 | Bảng giá, ma trận chiết khấu & duyệt Gross Margin — `bang-gia-chiet-khau-gross-margin.md` | User gap 2 + Expert | `sales-expert` (finance-expert phối hợp duyệt GM) | Ma trận chiết khấu phân cấp NVKD/TPKD/GDKD/BOD; định mức tính giá chuẩn cho Quotation; GM tối thiểu theo nhóm dịch vụ; hiệu lực báo giá 30–60 ngày | Bắt buộc |
| 3 | Hoa hồng Sales L1–L5 & chỉ tiêu doanh số — `hoa-hong-sales-quota.md` | User gap 3 + Expert | `sales-expert` | Credit theo thanh toán thực nhận + clawback; chỉ deal ghi nhận trước Gate 2 mới hưởng; quy tắc phân bổ tranh chấp nguồn lead; quota pipeline coverage ≥3x | Bắt buộc |
| 4 | Hợp đồng, LOI, NDA & Brand Safety — `hop-dong-loi-nda-brand-safety.md` | User gap 4 + Expert | `legal-expert` | Mẫu chuẩn IN/OUT of scope; nạp trước 100% NSQC; NDA mutual trước Full Brief; workflow duyệt → e-sign → archive; Brand Safety 7 tiêu chí hard stop; không cam kết KPI cứng, cap trách nhiệm; retention 10 năm | Bắt buộc |
| 5 | Quản lý & cấp phát TKQC + Financial Hard Stop — `quan-ly-cap-phat-tkqc-financial-hard-stop.md` | User gap 5 + Expert | `paid-media-expert` | Chỉ cấp TK khi FIN_L1 xác nhận "đã khớp tiền" (không override); 1 owner + 1 backup, không chia sẻ login; thu hồi 24h khi nghỉ/chuyển; naming & UTM convention bắt buộc | Bắt buộc |
| 6 | Kiểm soát ví TKQC & giao dịch tiền — `kiem-soat-vi-tkqc-giao-dich-tien.md` | Expert đề xuất | `paid-media-expert` (finance, compliance phối hợp) | Cảnh báo số dư đủ chi ≥3 ngày, SLA đỏ 2h, escalation owner → TL → AM; die account có trạng thái + evidence; dual approval điều chỉnh số dư/đổi tỷ giá/hoàn tiền (SoD 4 vai) | Bắt buộc |
| 7 | Đối soát công nợ nền tảng, doanh thu, tiền nạp & đa tiền tệ — `doi-soat-cong-no-doanh-thu-da-tien-te.md` | User gap 6 + Expert | `finance-expert` | Đối trừ 3 số (khách nạp ↔ nạp nền tảng ↔ chi tiêu); FIN_L2 chốt + khóa kỳ; tiền nạp = tiền giữ hộ, doanh thu trên phí dịch vụ/markup; sổ gốc VND, snapshot tỷ giá, FX ghi khoản riêng | Bắt buộc |
| 8 | Hạn mức chi, giải ngân, mua hàng & SoD — `han-muc-chi-giai-ngan-sod.md` | User gap 11 + Expert | `finance-expert` | Ma trận phê duyệt FIN_L1 → FIN_L2 → CFO/CEO theo ngưỡng; người tạo ≠ người duyệt ≠ người chi; delegate khi nghẽn; block vi phạm + log | Bắt buộc |
| 9 | AML/KYC & giám sát giao dịch bất thường — `aml-kyc-giam-sat-giao-dich.md` | Expert đề xuất | `compliance-expert` | Định danh pháp nhân khách trước cấp TK; hoàn tiền chỉ về đúng TK nguồn nạp; ngưỡng cảnh báo nạp gấp/tách nhỏ; monitoring 2.600+ TK đa kênh quốc tế | Bắt buộc |
| 10 | Timesheet & Capacity — `timesheet-capacity.md` | User gap 7 + Expert | `hr-expert` (marketing-expert phối hợp capacity check) | Định mức giờ/tuần L1–L5 (vàng 90% – đỏ 100%, chặn gán vượt); nhãn billable bắt buộc tại nguồn cấm sửa sau; ghi ngày chốt tuần, TL duyệt (cấm tự duyệt); giờ chưa duyệt không vào P&L | Bắt buộc |
| 11 | SLA khách hàng — `sla-khach-hang.md` | User gap 8 + Expert | `customer-expert` (marketing-expert phối hợp) | Ma trận tier × priority First Response/Resolution; định nghĩa SLA clock (múi giờ, giờ làm việc, luật tạm dừng); pre-alert 80%; breach báo đỏ AM + TL; override có audit log | Bắt buộc |
| 12 | Stage-Gate & điều kiện chuyển pha Lifecycle V6.0 — `stage-gate-lifecycle-v6.md` | Expert đề xuất | `marketing-expert` | Entry/done criteria machine-checkable từng stage; cấm chuyển pha thiếu điều kiện; SLA duyệt + escalation tự động khi quá hạn | Bắt buộc |
| 13 | Nhân sự hành chính, hồ sơ L1–L5 & Cost Rate Card — `nhan-su-hanh-chinh-cost-rate-card.md` | User gap 9 + Expert | `hr-expert` (finance-expert thẩm định rate) | Hồ sơ là nguồn sự thật cho RBAC/hoa hồng/P&L/KPI; cảnh báo hạn HĐLĐ, chấm công, nghỉ phép, self-service; Cost Rate Card version hóa từ ngày–đến ngày; lương Confidential | Bắt buộc |
| 14 | KPI & hiệu suất (3 trụ cột, PIP) — `kpi-hieu-suat.md` | User gap 10 + Expert | `hr-expert` | Tự tổng hợp từ timesheet + task SLA + target, không nhập điểm tay; trọng số theo bậc; review quý minh bạch; PIP 30-60-90; calibration HR_L2 trước khi trình BOD | Bắt buộc |
| 15 | Bảo vệ dữ liệu cá nhân (NĐ 13/2023 + GDPR/CCPA + PII nhân sự) — `bao-ve-du-lieu-ca-nhan.md` | Expert đề xuất | `legal-expert` | Inventory dữ liệu Portal + nhân sự; breach notification 72h; DSR tracking; DPA phân vai controller/processor; phân loại PII, ma trận truy cập, audit log lương/HĐ | Bắt buộc |
| 16 | Client Portal: minh bạch dữ liệu, bảo mật & CSAT — `client-portal-minh-bach-bao-mat.md` | Expert đề xuất | `customer-expert` (legal-expert phối hợp ranh giới dữ liệu) | Khách thấy số dư/chi tiêu daily/tiến độ/ticket, không thấy giá vốn/chiết khấu/P&L; disclaimer độ trễ; 2FA/OTP, tenant isolation, ví read-only, watermark; CSAT, detractor 48h, khiếu nại leo thang BOD | Bắt buộc |
| 17 | RBAC, phân loại dữ liệu & quản lý truy cập/credentials — `rbac-phan-loai-du-lieu-credentials.md` | User gap 12 + Expert | `sre` | 4 tier dữ liệu (Công khai/Nội bộ/Mật/Restricted); cost rate/lương = Restricted; RBAC 1 người nhiều vai + tách xung đột duyệt; vault mã hóa, MFA, rotate token, quarterly access review | Bắt buộc |
| 18 | Audit log bất biến, bảo lưu, backup/DR & change management — `audit-log-bao-luu-backup-dr.md` | User gap 12 + Expert | `sre` (compliance-expert phối hợp retention) | Append-only + old→new + reason-code + hash-chain; kể cả Super Admin không xóa/sửa; sự kiện tiền/HĐ ≥10 năm, WORM; backup mã hóa + test phục hồi; change management có phê duyệt + log | Bắt buộc |
| 19 | Quản trị metric & chất lượng/freshness dữ liệu — `quan-tri-metric-chat-luong-du-lieu.md` | Expert đề xuất | `data-expert` | Metric catalog khai báo (tên, công thức, nguồn, owner) định nghĩa duy nhất; đổi định nghĩa CFO duyệt + lịch sử hiệu lực; freshness SLA (chi tiêu QC ≤1h, timesheet chốt ngày); test đối soát ±0,1% | Bắt buộc |
| 20 | TikTok Shop: truy cập dữ liệu, tách bạch GMV & thẩm định shop — `tiktok-shop-du-lieu-gmv-tham-dinh.md` | Expert đề xuất | `paid-media-expert` | OAuth per-client, log truy cập, thu hồi khi hết HĐ, mask PII, isolation giữa shop; GMV/settlement chỉ tham chiếu — doanh thu agency = phí dịch vụ + phí ads thu hộ; checklist thẩm định chủ shop + giấy phép ngành hàng | Bắt buộc |

> **Ghi chú:** Chính sách "Expert đề xuất" là những chính sách domain experts nhận thấy CẦN THIẾT cho vận hành, quản trị, kiểm soát doanh nghiệp mà user chưa nghĩ tới. Điểm cần lưu ý cho phase sau: (1) các chính sách pháp lý (#4, #15) cần luật sư VN và auditor độc lập xác nhận; (2) policy #10, #13, #19 phụ thuộc việc chốt định mức nền (giờ/tuần L1–L5, cost-per-hour, khung SLA theo Tier) — hiện chưa có con số; (3) policy #5, #17 phụ thuộc tiến trình Business Verification API của 7 nền tảng. Xem chi tiết tại `.mc-data/work/wf-brainstorm/policy-analysis.md`.

---

## 6. Chốt Khung Dự Án

### 6.1. Tóm tắt dự án

Xây dựng **BCERP** — hệ thống ERP nội bộ đầy đủ (không MVP) cho BC Agency, digital marketing agency trung gian 2.600+ TKQC đa nền tảng với 1.000+ khách hàng toàn cầu. Hệ thống gồm 19 phân hệ trên 3 mặt bằng: **ERP nội bộ (Web)**, **Client Portal đối ngoại (Web + Mobile, multi-tenant)** và **Mobile nội bộ**, xoay quanh 4 trụ cột: minh bạch dữ liệu với khách, Financial Hard Stop kiểm soát tiền giữ hộ TKQC, P&L realtime theo dự án, và số hóa Lifecycle V6.0 từ lead tới deliverable.

### 6.2. Xác nhận sẵn sàng sang Phase 1

```
[x] Đã hoàn thành P0-01 (Thông tin tổ chức, phòng ban, phân hệ, đối tượng người dùng, chính sách nghiệp vụ)
[x] Đã hoàn thành P0-02 (Bản đồ hệ thống chi tiết, roles & quyền, NFR, tech stack) — hoàn thành trong cùng Phase 4 của /wf-brainstorm
[x] Chính sách còn thiếu đã được agents soạn thảo (policies/) — 20/20 chính sách Bắt buộc, danh sách file tại §5.3
[x] interface_type đã xác định: web+mobile
[ ] Đã hoàn thành stakeholder-review.md (3 góc review: Cross-Document, Consistency, Gap Analysis) — Phase 0 không tạo, chuyển sang Phase 1 theo luồng /wf-brainstorm
[x] Người phê duyệt đã đồng ý với phạm vi — Chủ dự án xác nhận qua Phase 1+2 của /wf-brainstorm
```

**Ngày chốt:** 11/09/2026
**Người chốt:** Chủ dự án BC Agency — xác nhận qua `/wf-brainstorm`

---

**→ Bước tiếp theo:** Chuyển sang **Phase 1** — điền `P1-01-project-overview.md` và `P1-02-business-workflow.md`, tạo folders trong `departments/`, thực hiện stakeholder review 3 góc (Cross-Document, Consistency, Gap Analysis) trên bộ tài liệu Phase 0.
