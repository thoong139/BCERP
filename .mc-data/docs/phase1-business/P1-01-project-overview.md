# Tổng Quan Dự Án — BCERP

> **Loại tài liệu:** Tổng quan — Mọi thành viên dự án đều cần đọc
> **Cập nhật bởi:** business-analyst (tự động qua `/wf-analyze-requirements`)
> **Ngày cập nhật:** 12/09/2026
>
> READS: `phase0-brainstorm/P0-01-brainstorm.md`, `phase0-brainstorm/P0-02-systems-users.md`
> USED BY: `P1-02-business-workflow.md`, `departments/[dept]/[dept].md`, `_meta/req-registry.json`

---

## 1. Thông Tin Chung

| Thông tin           | Nội dung                                                                                                                                                                                                   |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tên dự án         | BCERP — Hệ thống ERP nội bộ tích hợp cho BC Agency                                                                                                                                                   |
| Mục tiêu           | Số hóa toàn bộ vận hành của digital marketing agency BC Agency: từ lead → deliverable (Lifecycle V6.0), đối soát TKQC qua API, quản lý tiền giữ hộ khách hàng, P&L realtime theo dự án |
| Phạm vi             | 19 phân hệ trên 3 mặt bằng: ERP nội bộ (Web), Client Portal đối ngoại (Web + Mobile multi-tenant), Mobile nội bộ — phục vụ 5 phòng ban + khách hàng                                       |
| Thời gian           | 11/09/2026 (khởi động Phase 1) → Không đặt mốc go-live cứng — phát triển đầy đủ, KHÔNG MVP                                                                                                 |
| Trạng thái         | Đang lên kế hoạch                                                                                                                                                                                       |
| Đơn vị chủ quản | BC Agency — Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam (MST 0109354342, Hà Nội)                                                                                                               |
| Người phụ trách  | Chủ dự án BC Agency (CEO Bùi Thị An, CFO kiêm CTO Hoàng Nam)                                                                                                                                         |

---

## 2. Bối Cảnh & Lý Do Thực Hiện

**Tình hình hiện tại:**

BC Agency là trung gian quản lý 2.600+ tài khoản quảng cáo (TKQC) đa nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) cho 1.000+ khách hàng toàn cầu với 31–50 nhân sự. Toàn bộ vận hành đang thủ công trên Sheets/Excel:

- Đối soát TKQC bằng ảnh chụp màn hình — không có số liệu tươi, sai sót cao, không đối trừ được 3 số (khách nạp ↔ nạp nền tảng ↔ chi tiêu).
- "Mỗi người một bảng tính": P&L không realtime, không tách bạch billable/non-billable, tiền nạp QC của khách (tiền giữ hộ) lẫn với doanh thu dịch vụ.
- Chưa có chính sách vận hành viết (12/12 lĩnh vực "Chưa có"): chiết khấu, hoa hồng, SLA, KPI cảm tính, định mức giờ/tuần chưa có.
- Rủi ro kiểm soát dòng tiền: chưa có cơ chế chặn cấp TKQC khi chưa khớp tiền; kiêm nhiệm CFO kiêm CTO không có compensating control.

**Dự án này sẽ giải quyết:**

- **Minh bạch dữ liệu với khách:** Client Portal multi-tenant — khách tự xem số dư ví, chi tiêu daily, tiến độ nghiệm thu, ticket; không thấy giá vốn/chiết khấu/P&L.
- **Financial Hard Stop:** cấm cấp phát TKQC khi FIN_L1 chưa xác nhận "đã khớp tiền" — chặn cứng trong code; tiền nạp khách hạch toán là tiền giữ hộ, tách bạch khỏi doanh thu.
- **P&L realtime theo dự án:** dữ liệu hợp nhất star-schema từ timesheet + cost rate + chi tiêu QC; chấm dứt bảng tính phân tán.
- **Số hóa Lifecycle V6.0:** lead → quotation → handoff → campaign → deliverable với stage-gate machine-checkable, RBAC 4-tier + audit log bất biến.

---

## 3. Mục Tiêu Dự Án

**Mục tiêu chính:**

Xây dựng BCERP — ERP nội bộ đầy đủ (không MVP) giúp BC Agency kiểm soát tiền giữ hộ TKQC chặt chẽ, tự động hóa đối soát qua API 7 nền tảng, và minh bạch dữ liệu với 1.000+ khách hàng qua Client Portal.

**Kết quả mong đợi:**

| Kết quả cụ thể                  | Cách đo lường                                                                             | Mốc thời gian |
| ----------------------------------- | --------------------------------------------------------------------------------------------- | --------------- |
| Đối soát TKQC tự động qua API | Chi tiêu QC tươi ≤1h; đối trừ 3 số sai lệch ±0,1%; chấm dứt ảnh chụp màn hình | GĐ1–GĐ2      |
| Financial Hard Stop vận hành      | 0 case cấp TKQC khi chưa khớp tiền; 100% giao dịch tiền có audit log hash-chain        | Từ GĐ1        |
| P&L realtime theo dự án/khách    | Dashboard BOD cập nhật realtime; timesheet chốt ngày, giờ chưa duyệt không vào P&L   | GĐ2–GĐ3      |
| Client Portal minh bạch            | ~2.000–3.000 user khách (1.000+ tenant); uptime 99,9%; CSAT đo sau mỗi ticket             | GĐ3            |

---

## 4. Phạm Vi Hệ Thống

**Bao gồm trong dự án (19 phân hệ):**

| STT | Phân hệ                                   | Mô tả ngắn                                                             | Giai đoạn |
| --- | ------------------------------------------- | ------------------------------------------------------------------------- | ----------- |
| 1   | RBAC & Audit Log                            | Phân quyền theo vai+Level, audit log bất biến append-only hash-chain  | GĐ1        |
| 2   | Settings & Integration Gateway              | Credentials vault, sync scheduler, API 7 nền tảng, degraded mode        | GĐ1        |
| 3   | HR Core                                     | Hồ sơ L1–L5, mã vai, HĐLĐ, chấm công, Cost Rate Card version hóa | GĐ1        |
| 4   | CRM & Lead Pipeline V6.0                    | Anti-duplicate đa kênh, AUTO SCORING K1–K12, Tier A–E                 | GĐ1        |
| 5   | Quotation & Deal Desk                       | Định mức tính giá, duyệt GM, version control theo tier              | GĐ1        |
| 6   | Quản lý TKQC — Ad Account Command Center | Registry 2.600+ TK: số dư, spend limit, owner, die account              | GĐ1        |
| 7   | Wallet & Đối soát TKQC                   | Sổ phụ ví, Financial Hard Stop, snapshot tỷ giá                      | GĐ2 (riêng Gate "đã khớp tiền" của Financial Hard Stop: GĐ1 — điều kiện cấp phát TKQC) |
| 8   | Công nợ AR/AP & Giải ngân               | Aging, workflow FIN_L1→FIN_L2→CFO/CEO theo ngưỡng, SoD                | GĐ2        |
| 9   | Handoff & Onboarding Bridge                 | Handoff Package 5 nhóm checklist, ký 3 bên, SLA 4h                     | GĐ2        |
| 10  | Proposal & Planning Workspace               | Stage-gate V6.0, Brand Safety 7 tiêu chí, template theo Tier            | GĐ2        |
| 11  | Campaign & Deliverable Management           | WBS, lịch nội dung, duyệt creative, change log bất biến              | GĐ2        |
| 12  | Capacity & Timesheet                        | Định mức giờ L1–L5, chặn gán >100%, nhãn billable tại nguồn     | GĐ2        |
| 13  | SLA & Notification Engine                   | Ma trận tier×priority, SLA clock đa múi giờ, escalation              | GĐ2        |
| 14  | Ticket & CSKH                               | Queue hợp nhất portal/email/Zalo, CSAT, escalation                      | GĐ2        |
| 15  | Commission & Quota                          | Hoa hồng theo thanh toán thực nhận + clawback, quota ≥3x coverage    | GĐ3        |
| 16  | KPI & Performance                           | 3 trụ cột tự tổng hợp, không nhập điểm tay, PIP                  | GĐ3        |
| 17  | Client Portal (Web + Mobile)                | Multi-tenant, đa ngôn ngữ/múi giờ; ví read-only                     | GĐ3        |
| 18  | Data Integration Hub & BI/BOD Dashboard     | Star schema, P&L realtime, metric catalog, alert center                   | GĐ3        |
| 19  | TikTok Shop Monitoring                      | GMV/đơn/settlement qua API; tách bạch GMV khỏi P&L agency            | GĐ3        |

**Không bao gồm trong dự án này:**

- Không loại trừ mảng nào — chủ dự án xác nhận full scope (P0-01 §3.2).
- BCERP **tích hợp, không thay thế** phần mềm kế toán hiện hữu (tên chưa xác định) — chỉ kết nối bút toán/chứng từ/HĐĐT.
- TikTok Shop: chỉ monitoring GMV/settlement — KHÔNG làm OMS/WMS.
- 2 điểm chưa chốt (không phải loại trừ): tên phần mềm kế toán hiện hữu; tên/phạm vi PMS cũ trong quy trình V6.0 (BCERP CRM thay thế hay cần migration).

---

## 5. Đối Tượng Sử Dụng

| STT | Nhóm người dùng                 | Họ là ai                                                        | Họ dùng hệ thống để làm gì                                             |
| --- | ----------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1   | Nhân viên nội bộ (5 phòng ban) | 31–50 nhân sự, Level L1–L5, mã vai OPS/FIN/SALES/HR          | Sales ghi lead; OPS ghi timesheet/task; FIN đối soát; HR quản lý hồ sơ  |
| 2   | Quản lý / TL / Trưởng phòng    | SALES_L3 TNKD, OPS L5, FIN_L2, HR_L2                              | Duyệt phân cấp, phân công capacity, phê duyệt theo ngưỡng             |
| 3   | BOD                                 | CEO, CFO kiêm CTO                                                | P&L toàn công ty, phê duyệt vượt ngưỡng, audit log, cảnh báo rủi ro |
| 4   | Admin hệ thống                    | CTO/Super Admin                                                   | Cấu hình integration API, credentials vault, RBAC, access review             |
| 5   | Khách hàng                        | 1.000+ doanh nghiệp đa quốc gia, nhiều user/roles mỗi khách | Client Portal: xem số dư ví, chi tiêu daily, tiến độ, ticket            |

---

## 6. Phối Hợp Giữa Các Phân Hệ

```
Khi sales chốt hợp đồng (Gate 2):
  CRM & Pipeline V6.0  →  Handoff Package ký 3 bên (SLA 4h)  →  OPS nhận dự án
  OPS lên proposal WBS →  gán capacity (chặn >100%)          →  Campaign chạy
  OPS ghi timesheet (nhãn billable) →  chi phí dự án         →  P&L realtime
  Khách nạp tiền      →  Wallet (tiền giữ hộ)                →  FIN đối soát 3 số
  FIN_L1 xác nhận "đã khớp tiền" →  Financial Hard Stop mở   →  OPS_ADS cấp TKQC
  Mọi giao dịch tiền/hợp đồng → Audit Log hash-chain (≥10 năm, kể cả Super Admin không sửa)
```

---

## 7. Giới Hạn & Giả Định

**Những điều đã xác định (không thay đổi):**

- Phát triển đầy đủ, KHÔNG MVP; không đặt mốc go-live cứng.
- interface_type = web+mobile; Client Portal multi-tenant tách vùng bảo mật với ERP nội bộ.
- Tiền nạp QC của khách = tiền giữ hộ (nợ phải trả), không phải doanh thu.
- Immutable audit log append-only + hash-chain ≥10 năm cho sự kiện tiền/hợp đồng.
- SoD 4 vai dòng tiền + dual approval; compensating control cho kiêm nhiệm CFO kiêm CTO.
- Tech stack (đề xuất P0-02): Node.js/TypeScript + NestJS, React/Next.js, React Native (1 codebase 2 variant), PostgreSQL (RLS), Redis + BullMQ, Keycloak 2 realms, Docker trên cloud có region VN.

**Những điều đang được giả định:**

- Chưa có quyền API developer của 7 nền tảng QC → degraded mode nhập tay có cấu trúc (gắn nhãn "manual"), backfill khi được cấp; Business Verification chạy song song.
- Định mức nền (giờ/tuần L1–L5, cost-per-hour, khung SLA theo Tier) chưa có con số — sẽ chốt trong phase phân tích chính sách và có thể điều chỉnh sau.
- Chính sách pháp lý (#4, #15) cần luật sư VN chuyên dữ liệu/công nghệ và auditor độc lập xác nhận trước khi trở thành bắt buộc thiết kế.
- Migration mở sổ từ Google Sheets/Excel (2.600+ TKQC, khách hàng, cost rate) — không duy trì song song sau go-live.

---

## 8. Các Bên Liên Quan

| Vai trò                                   | Tên / Bộ phận                                                                                                                 | Trách nhiệm trong dự án                                                                            |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Chủ dự án (Sponsor)                     | BC Agency — CEO Bùi Thị An                                                                                                    | Phê duyệt phạm vi, ngân sách, quyết định cuối cùng                                           |
| Đại diện nghiệp vụ                    | 5 phòng ban: BOD, HR, Tài chính - Kế toán, Kinh doanh, Vận hành & Marketing nội bộ                                      | Cung cấp yêu cầu, xác nhận nghiệm thu theo department                                            |
| Quản lý dự án                          | CFO kiêm CTO Hoàng Nam                                                                                                         | Điều phối, quyết định kiến trúc, compensating control                                          |
| Đội phát triển                         | DEVKIT workflow (AI-driven) qua các phase`/wf-analyze-requirements` → `/wf-define-features` → `/wf-design` → implement | Thiết kế và xây dựng hệ thống                                                                   |
| Bên xác nhận độc lập (khuyến nghị) | Luật sư VN chuyên dữ liệu/công nghệ; auditor độc lập                                                                   | Xác nhận chính sách pháp lý (NĐ 13/2023, GDPR/CCPA, Luật Kế toán, TT99/2025 theo quy định) |

---

## 9. Yêu Cầu Chất Lượng Tổng Thể

| Tiêu chí           | Yêu cầu                                                                                                                                                                     |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tốc độ            | API P95 <500ms; sync hourly 2.600+ TK (queue ≤60 phút/vòng); chi tiêu QC tươi ≤1h; cảnh báo ≤5 phút                                                                |
| Độ ổn định      | Uptime 99,9% cho Client Portal 7×24 đa múi giờ; degraded mode khi connector lỗi                                                                                          |
| Bảo mật            | MFA TOTP nội bộ, OTP portal; vault credentials; RBAC 4-tier dữ liệu; tenant isolation tuyệt đối; quarterly access review; breach notification 72h (NĐ 13/2023 + GDPR) |
| Khả năng mở rộng | Portal 1.000+ khách ~2.000–3.000 user (concurrent 200–300); RTO ≤4h, RPO ≤15 phút                                                                                       |
| Lưu trữ dữ liệu  | Sự kiện tiền/hợp đồng ≥10 năm (WORM, hash-chain); hợp đồng + chứng từ đối soát ≥10 năm (Luật Kế toán 2015)                                               |
