# DEPT-BOD — Ban Điều Hành (BOD)

> **Phòng ban:** Ban Điều Hành — CEO Bùi Thị An, CFO kiêm CTO Hoàng Nam
> **Ngày cập nhật:** 12/09/2026
> **Trạng thái:** Đang phân tích (Phần A — BA viết; Phần B — workflow chuyên gia đã thêm; A7 chờ bước đánh giá chuyên gia)
>
> READS: `P1-01-project-overview.md`, `phase0-brainstorm/P0-01-brainstorm.md`, `P0-02-systems-users.md`, policies: `han-muc-chi-giai-ngan-sod.md`, `audit-log-bao-luu-backup-dr.md`, `rbac-phan-loai-du-lieu-credentials.md`, `quan-tri-metric-chat-luong-du-lieu.md`
> USED BY: `departments/_index.md`, `_meta/req-registry.json`, `phase2-features/`

---

## Phần A — Phân Tích BA (Stakeholders & User Needs)

### A0. Ma Trận Requirement × System

Hệ thống registry khai báo cho DEPT-BOD: **SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-INTEGRATION-GW, SYS-MOBILE-INTERNAL** (ký hiệu: CORE, WEB, GW, MOBILE). Quy ước phase: MVP = GĐ1, Phase2 = GĐ2, Phase3 = GĐ3 (dự án phát triển đầy đủ, nhãn phase chỉ là thứ tự xây dựng).

| REQ-ID | Title | Systems | Primary | Lý do tách/gộp |
|---|---|---|---|---|
| REQ-BOD-001 | Phê duyệt vượt ngưỡng & escalation | CORE, WEB, MOBILE | CORE | 1 luồng duy nhất; WEB = bản đầy đủ, MOBILE = bản di động |
| REQ-BOD-002 | Compensating control kiêm nhiệm CFO/CTO | CORE, WEB, MOBILE | CORE | Chặn hard ở core; WEB/MOBILE là kênh CEO thực thi |
| REQ-BOD-003 | P&L toàn công ty realtime | CORE, WEB, MOBILE | CORE | Tính toán ở core; WEB đầy đủ, MOBILE rút gọn |
| REQ-BOD-004 | BI dashboard điều hành | CORE, WEB, MOBILE | WEB | Tách khỏi 003: khác phạm vi (đa KPI vs P&L) và phase (GĐ3) |
| REQ-BOD-005 | Giám sát & truy xuất audit log | CORE, WEB | CORE | Chỉ bản web; MOBILE không có riêng — nhận alert qua 006 |
| REQ-BOD-006 | Alert center & cảnh báo rủi ro | CORE, WEB, MOBILE | MOBILE | MOBILE kênh chính cảnh báo khẩn (push); WEB là trung tâm tổng hợp |
| REQ-BOD-007 | Quarterly access review & phân quyền | CORE, GW, WEB | CORE | RBAC ở core; GW cấp inventory credentials; MOBILE dùng chung WEB |
| REQ-BOD-008 | Quản trị Gateway & credentials vault (CTO) | GW, CORE, WEB | GW | Need riêng vai CTO; MOBILE cấm (giảm bề mặt tấn công) |
| REQ-BOD-009 | Duyệt chính sách, tham số & tier | CORE, WEB | CORE | Cấu hình effective-dated; không có touchpoint mobile |
| REQ-BOD-010 | Duyệt tài chính độc quyền CFO | CORE, WEB | CORE | Nhóm quyền chỉ CFO có; tần suất thấp → chỉ web |
| REQ-BOD-011 | Nền tảng RBAC & SSO/MFA tập trung (cross-cutting) | CORE, WEB, PORTAL, MOBILE | CORE | Bổ sung Phase 6d (SO3-01); enforcement RBAC ở CORE; PORTAL = SYS-PORTAL-WEB (OTP portal khách) — bổ sung ngoài 4 hệ thống declared của BOD; mọi phân hệ tham chiếu |

Cả 4 hệ thống declared đều có vai primary: CORE (005), WEB (004), GW (008), MOBILE (006).

---

### A1. Giới Thiệu Phòng Ban

**BOD làm gì:** Quản trị chiến lược — phê duyệt vượt ngưỡng, ban hành chính sách, theo dõi P&L toàn công ty, giám sát rủi ro vận hành và kiểm soát nội bộ. Thành phần: CEO Bùi Thị An, CFO kiêm CTO Hoàng Nam (CMO, COO/GDKD quy hoạch, tạm kiêm nhiệm).

**Rủi ro then chốt:** CFO kiêm CTO = **1 người 2 vai** đồng thời là **Super Admin** — điểm tập trung rủi ro duy nhất của hệ thống (policy RBAC §2.4), bắt buộc compensating control (REQ-BOD-002). Vai `SYS_ADMIN` thuộc trách nhiệm `BOD_CFO_CTO` — quản trị gateway/credentials là need chính thức của BOD (vai CTO).

| Vai trò | SL | Công việc hàng ngày | Cần hệ thống hỗ trợ gì |
|---|---|---|---|
| CEO (`BOD_CEO`) | 1 | Duyệt vượt ngưỡng, chính sách; quyết định từ số liệu | Dashboard P&L, hàng đợi duyệt, cảnh báo, access review |
| CFO kiêm CTO (`BOD_CFO_CTO`) | 1 | Dòng tiền, hạn mức tín dụng TKQC, duyệt GM/metric; quản trị gateway + credentials | Hàng đợi duyệt tài chính, console vault/gateway, metric catalog, audit log |
| SYS_ADMIN (ủy quyền Super Admin) | 1–2 | Thực thi cấu hình, provisioning, change theo CR được duyệt | Console có audit, workflow change, inventory credentials |

---

### A2. Tổng Hợp Nhu Cầu

| STT | Mã | Tên nhu cầu | Ưu tiên |
|---|---|---|---|
| 1 | REQ-BOD-001 | Phê duyệt vượt ngưỡng & escalation matrix | HIGH |
| 2 | REQ-BOD-002 | Compensating control kiêm nhiệm CFO kiêm CTO | HIGH |
| 3 | REQ-BOD-003 | P&L toàn công ty realtime | HIGH |
| 4 | REQ-BOD-004 | BI dashboard điều hành tổng quan | HIGH |
| 5 | REQ-BOD-005 | Giám sát & truy xuất audit log | HIGH |
| 6 | REQ-BOD-006 | Alert center & cảnh báo rủi ro vận hành | HIGH |
| 7 | REQ-BOD-007 | Quarterly access review & quản trị phân quyền | HIGH |
| 8 | REQ-BOD-008 | Quản trị Integration Gateway & credentials vault (vai CTO) | HIGH |
| 9 | REQ-BOD-009 | Phê duyệt chính sách, tham số quản trị & tier | HIGH |
| 10 | REQ-BOD-010 | Phê duyệt tài chính độc quyền của CFO | MEDIUM |

> HIGH = Bắt buộc (không có thì không kiểm soát được rủi ro tiền/hệ thống); MEDIUM = Quan trọng (tần suất thấp nhưng bắt buộc về quản trị); LOW = Nên có.

---

### A3. Chi Tiết Từng Nhu Cầu

#### REQ-BOD-001: Phê duyệt vượt ngưỡng & ma trận escalation

**Ưu tiên:** HIGH — **Phase:** MVP (approval engine) → Phase2 (luồng giải ngân đầy đủ). **Ai dùng:** BOD_CEO (duyệt >200 triệu, hợp đồng năm, chiết khấu vượt biểu `[CẦN CHỐT SỐ]`), BOD_CFO_CTO (50–200 triệu, dual approval).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): approval engine — ma trận hạn mức theo vai × ngưỡng × loại chi; dual approval; chặn giải ngân thiếu chữ ký; log vi phạm SoD.
- `SYS-BCERP-WEB`: bản duyệt đầy đủ — hồ sơ, chứng từ, ≥2 báo giá khi >20 triệu, mã dự án/khách; nhắc duyệt SLA 24/48/72h.
- `SYS-MOBILE-INTERNAL`: bản duyệt di động — push, duyệt nhanh khoản khẩn (4h), xem tóm tắt, chuyển web khi cần hồ sơ đầy đủ.

**Tôi cần hệ thống làm được:**
- [ ] Hàng đợi phê duyệt hợp nhất (giải ngân, chi khẩn, chiết khấu vượt biểu, hợp đồng năm) với SLA đếm ngược
- [ ] Dual approval tự động khi vượt ngưỡng; escalation khi quá hạn; delegate khi vắng (≤14 ngày, tự hết hạn)
- [ ] Mọi duyệt/từ chối ghi audit log kèm reason code

**Quy tắc:** CFO là người đề xuất khoản vượt ngưỡng cao nhất → chỉ CEO duyệt; quy VND theo tỷ giá snapshot ngày duyệt. **Đặc biệt:** chi khẩn (nền tảng sắp khóa TKQC) — duyệt 4h + hậu kiểm 24h.

#### REQ-BOD-002: Compensating control cho kiêm nhiệm CFO kiêm CTO

**Ưu tiên:** HIGH — **Phase:** MVP (từ giao dịch tiền đầu tiên). **Ai dùng:** BOD_CEO (thực thi kiểm soát), BOD_CFO_CTO (đối tượng kiểm soát).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): chặn hard — giao dịch tiền vượt ngưỡng do `BOD_CFO_CTO` khởi tạo không thực thi khi chưa có `BOD_CEO` duyệt; không đường tắt, không override.
- `SYS-BCERP-WEB`: hàng đợi "chờ CEO duyệt" cho giao dịch do CFO khởi tạo; màn hình ký quarterly review.
- `SYS-MOBILE-INTERNAL`: CEO duyệt khẩn ≤4h qua push.

**Tôi cần hệ thống làm được:**
- [ ] Tự phát hiện vai trùng đề xuất–duyệt và chặn trên mọi giao dịch tiền
- [ ] Quarterly review quyền của BOD_CFO_CTO (roles, phạm vi dữ liệu, credentials) — CEO ký trong 10 ngày đầu quý
- [ ] Mọi hành vi Super Admin ghi immutable audit log — không xóa/sửa được log của chính mình
- [ ] Hỗ trợ tách vai CFO/CTO sau này không phải redesign

**Quy tắc:** cấm gán cặp vai xung đột SoD cùng luồng; ủy quyền có thời hạn, báo CEO. **Đặc biệt:** truy cập khẩn T3/T4 xử lý sự cố — khai báo lý do 24h, alert CEO ngay.

#### REQ-BOD-003: P&L toàn công ty realtime

**Ưu tiên:** HIGH — **Phase:** MVP (star schema + P&L cơ bản) → Phase3 (realtime ≤15 phút). **Ai dùng:** BOD_CEO, BOD_CFO_CTO.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): star schema, conformed dimensions (Khách, Dự án, TKQC, Nền tảng, Cost Rate SCD2); công thức theo Metric Catalog; freshness ≤15 phút.
- `SYS-BCERP-WEB`: dashboard đầy đủ theo dự án/khách/nền tảng/tháng, drill-down tới timesheet, outsource/tools; chỉ báo "cập nhật lúc HH:MM + nguồn api/manual".
- `SYS-MOBILE-INTERNAL`: bản rút gọn — P&L khách/dự án top, margin, dòng tiền; chỉ xem.

**Tôi cần hệ thống làm được:**
- [ ] P&L = Doanh thu DV − (Σ giờ × cost rate + outsource + tools) — tách tuyệt đối với tiền giữ hộ TKQC (nạp khách = nợ phải trả, không vào doanh thu)
- [ ] Một nguồn sự thật, xem nhiều chiều; dữ liệu degraded mode gắn nhãn "manual"

**Quy tắc:** giờ timesheet chưa duyệt không vào P&L; chi không gắn mã dự án phải chọn overhead + lý do. **Đặc biệt:** connector lỗi — hiển thị "stale" + timestamp dữ liệu hợp lệ cuối, không nội suy số ẩn.

#### REQ-BOD-004: BI dashboard điều hành tổng quan

**Ưu tiên:** HIGH — **Phase:** Phase3 (phân hệ BI/BOD Dashboard; metric catalog dựng từ MVP). **Ai dùng:** BOD_CEO, BOD_CFO_CTO.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND`: ingestion đa nền tảng chịu lỗi; Metric Catalog; quality test tự động.
- `SYS-BCERP-WEB` (primary): BI workspace — drill-down tổng công ty → phòng → dự án; usage tracking.
- `SYS-MOBILE-INTERNAL`: bản KPI rút gọn; cảnh báo đỏ khi stale nghiêm trọng.

**Tôi cần hệ thống làm được:**
- [ ] KPI một nguồn sự thật: ROAS, GM, SLA attainment, on-time delivery, pipeline coverage, capacity, aging công nợ, tỷ lệ die account
- [ ] Chỉ báo freshness mọi widget; cảnh báo đỏ BOD khi stale nghiêm trọng (chi tiêu QC >8h, số dư ví >2h, timesheet >24h)
- [ ] Block publish báo cáo chính thức khi quality test đang fail

**Quy tắc:** metric phải đăng ký Metric Catalog trước khi dùng; đổi định nghĩa CFO duyệt, có lịch sử hiệu lực. **Đặc biệt:** chưa có quyền API — giữ nhãn "manual", minh chứng lưu kèm từng kỳ.

#### REQ-BOD-005: Giám sát & truy xuất audit log

**Ưu tiên:** HIGH — **Phase:** MVP (nền móng GĐ1, không bổ sung sau được). **Ai dùng:** BOD_CEO, BOD_CFO_CTO.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): audit service append-only + hash-chain; job kiểm tra toàn vẹn hằng ngày, đứt chuỗi alert CTO + BOD_CEO; meta-log (xem log cũng bị log).
- `SYS-BCERP-WEB`: tra cứu theo thời gian/đối tượng/người; truy xuất/xuất ngoài báo cáo chuẩn phải CEO duyệt; dashboard retention WORM.
- `SYS-MOBILE-INTERNAL`: **không có requirement riêng** — không tra cứu log trên mobile (dữ liệu Mật/Restricted); alert đứt chuỗi nhận qua REQ-BOD-006.

**Tôi cần hệ thống làm được:**
- [ ] Tra cứu giao dịch tiền/hợp đồng/phân quyền theo chuỗi old → new value + reason code
- [ ] Xem trạng thái hash-chain hằng ngày; báo cáo retention; duyệt xóa/archive log hết hạn (CTO đề xuất + CEO duyệt, việc xóa cũng bị log)

**Quy tắc:** kể cả Super Admin không sửa/xóa được log; log tiền/hợp đồng giữ ≥10 năm (WORM). **Đặc biệt:** thanh tra/kiểm toán — xuất có phê duyệt; retention chỉ được kéo dài, không rút ngắn.

#### REQ-BOD-006: Alert center & cảnh báo rủi ro vận hành

**Ưu tiên:** HIGH — **Phase:** MVP (sync/hard stop/backup) → Phase2 (SLA, khiếu nại) → Phase3 (alert center BI). **Ai dùng:** BOD_CEO, BOD_CFO_CTO.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND`: rule engine theo ngưỡng cấu hình được; delivery đa kênh; phân mức nghiêm trọng.
- `SYS-BCERP-WEB`: alert center tổng hợp — đã/chưa xử lý, phân loại, drill về nguồn, ghi nhận xử lý.
- `SYS-MOBILE-INTERNAL` (primary cảnh báo khẩn): push realtime ≤5 phút từ lúc phát hiện; cảnh báo đỏ nổi bật.

**Tôi cần hệ thống làm được:**
- [ ] Cảnh báo: đứt hash-chain; số dư ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi]`; die/spike/checkpoint; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại (30 phút); job sync fail; stale dữ liệu nghiêm trọng
- [ ] Khiếu nại nghiêm trọng từ khách leo thang BOD theo SLA
- [ ] Thống kê vi phạm SoD bị chặn, gửi CFO rà định kỳ

**Quy tắc:** alert chỉ tắt bằng acknowledge + reason; cảnh báo đỏ phải có người nhận trách nhiệm. **Đặc biệt:** connector outage — gộp alert theo nguồn, ưu tiên theo mức, không ngập người nhận.

#### REQ-BOD-007: Quarterly access review & quản trị phân quyền

**Ưu tiên:** HIGH — **Phase:** MVP (RBAC nền GĐ1; chu kỳ từ go-live). **Ai dùng:** BOD_CEO (chủ trì, ký), BOD_CFO_CTO (xuất báo cáo, bị review).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): sinh báo cáo user × role × level; tự vô hiệu quyền không review 2 quý liên tiếp; duyệt gán/thu hồi role thuộc CEO.
- `SYS-INTEGRATION-GW`: inventory credentials/token đang quản trị + ngày rotate.
- `SYS-BCERP-WEB`: workspace review — đối chiếu, đánh dấu giữ/thu hồi, CEO ký.
- `SYS-MOBILE-INTERNAL`: **không có requirement riêng — dùng chung với SYS-BCERP-WEB** (thao tác quý, thực hiện trên web).

**Tôi cần hệ thống làm được:**
- [ ] Chu trình review hoàn tất trong 10 ngày đầu quý, có bằng chứng ký xác nhận
- [ ] Cảnh báo token đến hạn rotate (T-7); offboarding → thu hồi + rotate ≤24h có checklist CTO xác nhận
- [ ] Người thử việc/freelancer không có quyền phê duyệt; guest tối đa 90 ngày

**Quy tắc:** SYS_ADMIN không tự gán quyền kể cả cho chính mình — chỉ thực thi sau phê duyệt của CEO. **Đặc biệt:** nghỉ đột xuất — offboarding khẩn 24h, lệch chuẩn ghi nhận vào kỳ review.

#### REQ-BOD-008: Quản trị Integration Gateway & credentials vault (vai CTO)

**Ưu tiên:** HIGH — **Phase:** MVP (phân hệ GĐ1). **Ai dùng:** BOD_CFO_CTO (CTO/Super Admin), SYS_ADMIN (thực thi sau phê duyệt).

**Hệ thống liên quan:**
- `SYS-INTEGRATION-GW` (primary): vault mã hóa credentials 7 nền tảng; rotate ≥90 ngày; scheduler sync 2.600+ TK; degraded mode gắn nhãn "manual"; log mọi lần gọi API.
- `SYS-CORE-BACKEND`: MFA TOTP cho tài khoản quản trị; audit mọi thao tác vault; job queue + monitoring sync.
- `SYS-BCERP-WEB`: console quản trị — thêm/sửa/rotate/thu hồi credentials, trạng thái adapter, cấu hình sync.
- `SYS-MOBILE-INTERNAL`: **không có requirement riêng** — cấm quản trị vault trên mobile (giảm bề mặt tấn công).

**Tôi cần hệ thống làm được:**
- [ ] Sức khỏe 7 adapter (thành công/thất bại/degraded, tuổi dữ liệu từng nguồn)
- [ ] Theo dõi hạn rotate; thu hồi khẩn credentials khi nghi ngờ rò rỉ hoặc liên quan nghỉ việc
- [ ] Credentials chỉ nằm trong vault — không bao giờ hiển thị plaintext ở giao diện nào

**Quy tắc:** chỉ CTO/Super Admin quản trị vault; MFA bắt buộc; mọi hành vi quản trị ghi immutable audit log. **Đặc biệt:** chưa có quyền API developer — degraded mode có kiểm soát, backfill tự động khi được cấp.

#### REQ-BOD-009: Phê duyệt chính sách, tham số quản trị & tier

**Ưu tiên:** HIGH — **Phase:** MVP. **Ai dùng:** BOD_CEO (chính sách, định mức), BOD_CFO_CTO (ngưỡng freshness, định nghĩa metric).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): cấu hình effective-dated — hiệu lực theo ngày, không sửa quá khứ; versioning + lịch sử hiệu lực gắn audit log.
- `SYS-BCERP-WEB`: trình duyệt và ký duyệt kèm ngày hiệu lực.
- `SYS-MOBILE-INTERNAL`: **không có touchpoint riêng** — duyệt chính sách cần hồ sơ đầy đủ, thực hiện trên web.

**Tôi cần hệ thống làm được:**
- [ ] Duyệt & ban hành: ma trận hạn mức chi/giải ngân `[CẦN CHỐT SỐ — đang là đề xuất 5/50/200 triệu VND]`; định mức giá/Cost Rate Card; khung SLA theo tier; tham số Tier A–E (rà soát quý)
- [ ] Mỗi tham số có version, ngày hiệu lực, người duyệt; báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu

**Quy tắc:** không hồi tố; mọi thay đổi tham số trace về audit log; đổi định nghĩa metric chỉ CFO duyệt. **Đặc biệt:** áp gấp giữa kỳ — cho phép hiệu lực giữa tháng nhưng mốc hiệu lực rõ ràng.

#### REQ-BOD-010: Phê duyệt tài chính độc quyền của CFO

**Ưu tiên:** MEDIUM — **Phase:** MVP (hạn mức tín dụng TKQC) → Phase2 (period unlock, gắn đối soát GĐ2). **Ai dùng:** BOD_CFO_CTO.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): enforcement — các lệnh dưới đây chỉ role CFO thực thi được, log + lý do bắt buộc.
- `SYS-BCERP-WEB`: giao diện duyệt với ngữ cảnh đầy đủ (kỳ số liệu, chênh lệch, lý do).
- `SYS-MOBILE-INTERNAL`: **không có requirement riêng** — tần suất thấp, thực hiện trên web.

**Tôi cần hệ thống làm được:**
- [ ] Duyệt hạn mức tín dụng TKQC theo nền tảng/khách
- [ ] Mở lại kỳ kế toán đã khóa (quyền duy nhất của CFO, log + lý do bắt buộc)
- [ ] Duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc; cùng BOD_CEO quyết sự cố M3/cảnh báo đỏ trong 4h

**Quy tắc:** backfill ghi nhận ai sửa, trước/sau, lý do — cấm sửa đè không vết; kỳ mở lại phải chốt lần hai có ghi nhận. **Đặc biệt:** quyết toán lại quý cũ phục vụ kiểm toán — qua backfill có phê duyệt, không đụng bản ghi gốc.

---

### A4. Dữ Liệu Phòng Ban Cần Quản Lý

| STT | Loại dữ liệu | Thông tin cần lưu | Ghi chú quan trọng |
|---|---|---|---|
| 1 | Ma trận hạn mức & phê duyệt | Loại chi, ngưỡng VND, vai duyệt, cờ dual approval | `[CẦN CHỐT SỐ]` ngưỡng; effective-dated, version hóa |
| 2 | Bản ghi phê duyệt | Ai duyệt, khi nào, lý do, kênh (web/mobile) | Immutable, hash-chain, ≥10 năm |
| 3 | P&L & metric | Định nghĩa theo Metric Catalog, nguồn api/manual | Lịch sử hiệu lực; đổi metric CFO duyệt |
| 4 | Access review record | user × role × level × credentials, kết quả, chữ ký CEO | Sinh tự động mỗi quý |
| 5 | Credential inventory | 7 nền tảng, ngày rotate, trạng thái token | Không plaintext; log mọi lần gọi API |
| 6 | Alert/incident log | Loại, mức M1–M3, người xử lý, resolution | M2 báo CFO 24h; M3 báo BOD 4h |
| 7 | Tham số chính sách | Tier A–E, ngưỡng SLA, freshness SLA | Version + ngày hiệu lực, không hồi tố |

---

### A5. Báo Cáo & Thống Kê Cần Có

| STT | Tên báo cáo | Nội dung | Tần suất | Người xem |
|---|---|---|---|---|
| 1 | Dashboard P&L realtime | P&L theo dự án/khách/nền tảng + freshness | Realtime (≤15 phút) | BOD |
| 2 | Báo cáo điều hành tuần/tháng | Doanh thu, GM, dòng tiền, aging, pipeline coverage | Tuần/tháng | BOD |
| 3 | Quarterly access review | user × role × level × credentials + đề xuất thu hồi | Quý | BOD_CEO ký |
| 4 | Audit log health & retention | Trạng thái hash-chain, log sắp hết hạn WORM | Hằng ngày/quý | BOD |
| 5 | Kết quả test restore DR | RTO/RPO thực tế, biên bản | Quý | BOD_CEO |
| 6 | Báo cáo sự cố dữ liệu M2/M3 | Nguyên nhân, giá trị trước/sau, phòng ngừa | Theo sự cố (M3 ≤4h) | BOD |

---

### A6. Điều BOD KHÔNG Muốn

- Không duyệt lại từng giao dịch con trong hạn mức tuần đã duyệt (batch approval phải được tôn trọng).
- Không nhìn thấy con số "không biết tuổi" — mọi số liệu có timestamp + nguồn (api/manual).
- Không để tiền giữ hộ của khách bị trộn thành doanh thu trên bất kỳ báo cáo nào.
- Không tồn tại bất kỳ ai — kể cả Super Admin — sửa/xóa được audit log.
- Không để quyết định nghẽn vì vắng người — delegate có hạn mức, tự hết hạn.

---

### A7. Đánh Giá Của Team Expert

*Điền ở bước đánh giá chuyên gia sau khi Phần A được review — gồm kết quả đánh giá tổng thể (đầy đủ/khả thi/rõ ràng/trùng lặp), điểm cần làm rõ theo REQ-ID, điều chỉnh sau đánh giá, và ký xác nhận của expert phụ trách, team expert, đại diện phòng ban.*

---

### Bổ sung Phase 6d: REQ-BOD-011 — Nền tảng RBAC & SSO/MFA tập trung (cross-cutting)

> **Nguồn:** Resolve finding SO3-01 (Stakeholder Review — High): phân hệ 1 "RBAC & Audit Log" chưa có REQ sở hữu. Quyết định AI-recommended — stakeholder có thể điều chỉnh. Đăng ký vào `_meta/req-registry.json` cùng batch SO2-01 ở Phase 8.

**Ưu tiên:** HIGH — **Phase:** MVP (GĐ1 — nền móng, không bổ sung sau được: RBAC engine là dependency của TẤT CẢ phân hệ). **Ai dùng:** toàn bộ vai nội bộ + CLIENT_USER/CLIENT_ADMIN (đăng nhập SSO); BOD_CEO duyệt gán/thu hồi vai; BOD_CFO_CTO (CTO/Super Admin) quản trị Keycloak 2 realms; SYS_ADMIN thực thi provisioning sau phê duyệt.

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary — enforcement): RBAC engine tập trung — mô hình vai × Level × phạm vi dữ liệu 4-tier (C1/C2/C3/T1–T4); hỗ trợ 1 người nhiều vai với tách xung đột duyệt (SoD theo luồng); mọi API đi qua 1 điểm check quyền duy nhất; lifecycle tài khoản nội bộ (tạo → thử việc → chính thức → offboarding thu hồi ≤24h); SSO Keycloak 2 realms (realm nội bộ + realm portal khách).
- `SYS-BCERP-WEB`: màn hình quản trị vai/phân quyền, hồ sơ user, đăng ký MFA TOTP cho nhân viên nội bộ.
- `SYS-PORTAL-WEB` (OTP portal): xác thực OTP cho user portal khách; reset/tạm khóa tài khoản portal có audit log.
- `SYS-MOBILE-INTERNAL` (MFA device): đăng ký/xác thực thiết bị MFA cho duyệt mobile (step-up).

**Tôi cần hệ thống làm được:**
- [ ] RBAC engine phục vụ mọi phân hệ: check quyền tập trung 1 điểm, vai × Level × tier dữ liệu; 1 người nhiều vai không vi phạm SoD — hệ thống phát hiện và tách xung đột duyệt theo luồng (nối REQ-BOD-002)
- [ ] SSO Keycloak 2 realms: realm nội bộ (nhân viên, MFA TOTP bắt buộc) + realm portal (khách, OTP); chính sách session/refresh theo tier dữ liệu truy cập
- [ ] Phân loại dữ liệu toàn cục C1/C2/C3/T1–T4 gắn quyền truy cập — mask/ẩn tự động theo vai (nối REQ-FIN-017 cho biên portal)
- [ ] Lifecycle tài khoản nội bộ: thử việc không có quyền phê duyệt; offboarding thu hồi + rotate ≤24h có checklist (nối REQ-BOD-007)

**Quy tắc:** enforcement nằm ở SYS-CORE-BACKEND — cấm phân hệ nào tự check quyền cục bộ; gán/thu hồi vai chỉ thực thi sau phê duyệt CEO (REQ-BOD-007); MFA TOTP bắt buộc nội bộ, OTP cho portal khách. **Đặc biệt:** REQ-BOD-007 (access review), REQ-FIN-012 (audit log lưu trữ), REQ-HR-010 (PII), REQ-FIN-006 (MFA điểm chức năng Hard Stop) giữ scope riêng và tham chiếu REQ-BOD-011 làm nền tảng — không phân hệ nào dựng RBAC/SSO riêng lẻ.

---

## Phần B — Quy Trình Nghiệp Vụ & Business Rules (Expert Review)

> Bám sát 10 REQ của Phần A, không tạo REQ mới. Quy ước: CORE = `SYS-CORE-BACKEND`, WEB = `SYS-BCERP-WEB`, GW = `SYS-INTEGRATION-GW`, MOBILE = `SYS-MOBILE-INTERNAL`. Rule ID `BR-BOD-0XX.n` trace về REQ tương ứng; số chưa chốt ghi `[CẦN CHỐT SỐ]` kèm đề xuất mặc định.

### B0. Nguyên Tắc Chung (áp dụng cho mọi REQ)

1. **Phân kênh:** WEB = hồ sơ đầy đủ + thao tác quản trị; MOBILE = duyệt nhanh, cảnh báo, xem rút gọn. MOBILE qua MDM, MFA TOTP bắt buộc với BOD/SYS_ADMIN; mọi lệnh duyệt ghi kênh vào audit log.
2. **Delegate vắng mặt:** ủy cho cá nhân cụ thể, hạn mức ≤ người ủy theo loại chi, tối đa 14 ngày, tự hết hạn, log nhãn "theo ủy quyền #id". CEO không ủy cho CFO/CTO quyết định trên giao dịch do chính CFO/CTO khởi tạo (vô hiệu compensating control) — CEO duyệt từ xa qua MOBILE; hành vi Super Admin/vault không ủy quyền. `[CẦN CHỐT SỐ: cả hai BOD không thể duyệt từ xa → đề xuất treo lệnh, không duyệt hộ]`.
3. **SYS_ADMIN** chỉ thực thi sau phê duyệt (CEO: phân quyền; CTO: change kỹ thuật), không tự gán quyền kể cả cho mình.

### B1. REQ-BOD-001 — Phê duyệt vượt ngưỡng & escalation

**Workflow:**
1. Người đề nghị tạo yêu cầu chi trên WEB; CORE quy VND theo tỷ giá snapshot ngày duyệt, tự phân nhánh ngưỡng ≤5tr / >5–50tr / >50–200tr / >200tr hoặc HĐ dài hạn–năm `[CẦN CHỐT SỐ — đề xuất 5/50/200 triệu]`.
2. CORE chặn submit nếu thiếu: chứng từ; ≥2 báo giá khi >20tr; mã dự án/khách (hoặc overhead + lý do); SoD người tạo ≠ người duyệt.
3. Rót duyệt theo ma trận vai × ngưỡng × loại chi: 50–200tr → FIN_L2 + CFO (SLA 48h); >200tr/HĐ năm → CFO + CEO (SLA 72h); chặn giải ngân khi thiếu 1 chữ ký.
4. MOBILE: push kèm SLA đếm ngược; duyệt buộc MFA step-up; khoản ≥200tr chặn nút "Duyệt" đến khi mở ≥1 chứng từ (MOBILE tóm tắt, hồ sơ đầy đủ trên WEB).
5. Quá hạn: 24h nhắc người duyệt; quá SLA escalate lên cấp duyệt trên và phát alert đỏ (REQ-BOD-006) `[CẦN CHỐT SỐ: mốc escalate theo ngưỡng]`. Duyệt/từ chối ghi audit log kèm reason code.

**Business rules:** BR-BOD-001.1 cấm "duyệt trước, bổ sung sau"; BR-BOD-001.2 CFO là người đề xuất khoản vượt ngưỡng cao nhất → nhánh duyệt chỉ có CEO (nền cho REQ-BOD-002); BR-BOD-001.3 nạp định kỳ trong hạn mức tuần đã duyệt không duyệt lại giao dịch con — sắp vượt tuần phải duyệt bổ sung trước khi giải ngân; BR-BOD-001.4 chi khẩn duyệt 4h qua kênh khẩn (MOBILE ưu tiên) + hậu kiểm chứng từ 24h, tồn hậu kiểm bật alert.

**Ngoại lệ/delegate:** CFO vắng → FIN_L2 xử phần hạn mức mình, dual approval chờ CFO hoặc delegate; CEO vắng → theo B0.2. **Quyền:** BOD_CEO duyệt mọi ngưỡng (bắt buộc nhánh >200tr); BOD_CFO_CTO duyệt 50–200tr + đồng duyệt >200tr; SYS_ADMIN không duyệt/sửa lệnh chi.

### B2. REQ-BOD-002 — Compensating control kiêm nhiệm CFO kiêm CTO

**Workflow:**
1. CORE phát hiện giao dịch tiền vượt ngưỡng (nạp/rút ví QC, điều chỉnh số dư, đổi tỷ giá, hoàn tiền, chiết khấu ngoài biểu) do `BOD_CFO_CTO` khởi tạo → khóa "chờ CEO duyệt": chặn hard trong code, không override.
2. WEB hiện hàng đợi "chờ CEO duyệt" riêng; MOBILE push CEO — duyệt khẩn ≤4h với MFA step-up.
3. CEO duyệt → CORE mới cho giải ngân; từ chối → trả luồng tài chính kèm reason code.
4. Ngày 1–10 đầu quý: CORE sinh báo cáo toàn bộ quyền của CFO/CTO (role × level, phạm vi T3/T4, credentials từ inventory GW) → CEO ký trên WEB.
5. Truy cập khẩn T3/T4 xử lý sự cố: mở có thời hạn, alert CEO ngay khi mở, khai báo lý do trong 24h.

**Business rules:** BR-BOD-002.1 cấm gán cặp vai xung đột SoD cùng luồng; mọi cố gắng vi phạm bị chặn + log để CFO rà; BR-BOD-002.2 hành vi Super Admin ghi immutable audit — không thể xóa/sửa log của chính mình; BR-BOD-002.3 quyền chưa được CEO ký review 2 quý liên tiếp tự vô hiệu; BR-BOD-002.4 role CFO và CTO thiết kế tách rời để tách vai sau không phải redesign.

**Ngoại lệ/delegate:** quarterly review không ủy quyền — CEO vắng vẫn tự ký qua MOBILE; SYS_ADMIN không nhận ủy quyền Super Admin; change khẩn P1: CTO làm ngay, hậu phê duyệt ≤24h. **Quyền:** BOD_CEO duyệt giao dịch CFO khởi tạo + ký review; BOD_CFO_CTO đề xuất, không tự duyệt; SYS_ADMIN thực thi sau duyệt, mọi thao tác bị log.

### B3. REQ-BOD-003 — P&L toàn công ty realtime

**Workflow (nguồn dữ liệu):** GW pull hourly 7 nền tảng (raw payload + fact), ví QC realtime ≤15 phút sau giao dịch, timesheet chốt 23:59, sổ kế toán — CORE nạp star schema (Khách, Dự án, TKQC, Nền tảng, Cost Rate SCD2); P&L tính lại ≤15 phút theo Metric Catalog: Doanh thu DV − (Σ giờ × cost rate + outsource + tools).
1. WEB: dashboard theo dự án/khách/nền tảng/tháng, drill-down tới timesheet/outsource/tools; chỉ báo "cập nhật lúc HH:MM + nguồn api/manual" ở dashboard và từng widget.
2. MOBILE: read-only — P&L top khách/dự án, margin, dòng tiền; không export, không cấu hình, drill chi tiết chuyển WEB.
3. Connector lỗi → hiển thị "stale" + timestamp dữ liệu hợp lệ cuối, không nội suy số ẩn (cả hai kênh).

**Business rules:** BR-BOD-003.1 tiền giữ hộ nạp ví TKQC là nợ phải trả — tách tuyệt đối khỏi doanh thu trên mọi báo cáo, mọi kênh; BR-BOD-003.2 giờ timesheet chưa duyệt không vào P&L; BR-BOD-003.3 chi không gắn mã dự án buộc chọn overhead + lý do; BR-BOD-003.4 degraded mode gắn nhãn "manual", không tắt nhãn.

**Ngoại lệ/delegate:** T4 (cost rate nhân sự) chỉ CEO/CFO — MOBILE không hiển thị T4 trên lock-screen. **Quyền:** BOD xem toàn bộ; SYS_ADMIN không thấy giá trị T3/T4.

### B4. REQ-BOD-004 — BI dashboard điều hành (Phase 3; metric catalog dựng từ MVP)

**Workflow:**
1. Metric đăng ký Metric Catalog (tên, công thức, nguồn, owner) — CFO duyệt ≤2 ngày làm việc; chưa đăng ký thì không được lên dashboard.
2. CORE: ingestion đa nền tảng chịu lỗi + quality test định kỳ (not-null, uniqueness, đối soát ví vs kế toán ±0,1%).
3. WEB (primary): BI workspace drill tổng công ty → phòng → dự án; widget có chỉ báo freshness; usage tracking; block publish báo cáo chính thức khi quality test đang fail.
4. MOBILE: bản KPI rút gọn (ROAS, GM, SLA attainment, aging công nợ, die account) + cảnh báo đỏ khi stale nghiêm trọng: chi QC >8h, số dư ví >2h, timesheet >24h.

**Business rules:** BR-BOD-004.1 một định nghĩa duy nhất mỗi metric; BR-BOD-004.2 đổi định nghĩa chỉ CFO duyệt, có lịch sử hiệu lực — báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu; BR-BOD-004.3 chưa có quyền API → nhãn "manual" + minh chứng lưu kèm từng kỳ; BR-BOD-004.4 báo cáo không usage 90 ngày đưa vào review nghỉ hưu.

**Ngoại lệ/delegate:** không phát sinh (chỉ xem); KPI mới luôn đi qua catalog, cấm view ngoài luồng.
**Quyền:** BOD xem; CFO duyệt metric + publish; SYS_ADMIN không sửa định nghĩa.

### B5. REQ-BOD-005 — Giám sát & truy xuất audit log

**Workflow:**
1. BOD tra cứu trên WEB theo thời gian/đối tượng/người → chuỗi old → new value + reason code; CORE ghi meta-log mỗi lần xem (xem log cũng bị log).
2. Job CORE kiểm tra hash-chain hằng ngày, kết quả lên dashboard trạng thái; đứt chuỗi → alert CTO + CEO ngay (REQ-BOD-006).
3. Xuất log ngoài báo cáo chuẩn: yêu cầu → CEO duyệt ≤2 ngày làm việc → xuất có log; thanh tra/kiểm toán dùng đúng luồng này.
4. Dashboard retention WORM: log tiền/hợp đồng ≥10 năm, log hệ thống ≥7 năm; xóa/archive hết hạn do CTO đề xuất + CEO duyệt theo quý — chính việc xóa cũng bị log; retention chỉ được kéo dài.

**Business rules:** BR-BOD-005.1 append-only ở tầng quyền DB — kể cả Super Admin không sửa/xóa được; BR-BOD-005.2 thiếu reason code → không submit; BR-BOD-005.3 MOBILE cấm tra cứu log (Mật/Restricted) — chỉ nhận alert đứt chuỗi qua REQ-BOD-006.

**Ngoại lệ/delegate:** duyệt xuất log không ủy cho người liên quan sự kiện bị tra cứu (SoD tra cứu ≠ đối tượng). **Quyền:** BOD_CEO duyệt xuất; CEO + CFO xem; SYS_ADMIN không xem nội dung nghiệp vụ ngoài scope; không có interface xóa ở mọi tầng.

### B6. REQ-BOD-006 — Alert center & cảnh báo rủi ro vận hành

**Workflow:**
1. CORE rule engine đánh giá sự kiện theo ngưỡng cấu hình, phân mức nghiêm trọng, delivery đa kênh; MOBILE push ≤5 phút từ lúc phát hiện (kênh chính cảnh báo khẩn).
2. WEB alert center tổng hợp: đã/chưa xử lý, phân loại, drill về nguồn, ghi nhận người xử lý + resolution.
3. Tắt alert chỉ bằng acknowledge + reason; cảnh báo đỏ bắt buộc có người nhận trách nhiệm; re-push đến khi có người nhận `[CẦN CHỐT SỐ: đề xuất 15 phút với mức đỏ]`.
4. Phân kênh: MOBILE push tóm tắt + deep-link WEB, không hiển thị T3/T4 trên lock-screen; WEB là nơi phân tích/xử lý đầy đủ.

**Business rules:** BR-BOD-006.1 cảnh báo BOD bắt buộc: đứt hash-chain; số dư ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]`; die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại (30 phút); job sync fail; stale dữ liệu nghiêm trọng; BR-BOD-006.2 connector outage → gộp alert theo nguồn, ưu tiên theo mức, không ngập người nhận; BR-BOD-006.3 khiếu nại nghiêm trọng leo thang BOD theo SLA; BR-BOD-006.4 thống kê vi phạm SoD bị chặn gửi CFO rà định kỳ.

**Ngoại lệ/delegate:** alert gửi cả hai BOD; người vắng cho delegate nhận (không delegate xử lý). **Quyền:** BOD nhận + ack mọi mức; SYS_ADMIN nhận alert kỹ thuật, không tự đóng alert đỏ của BOD.

### B7. REQ-BOD-007 — Quarterly access review & quản trị phân quyền

**Workflow:**
1. Ngày 1–10 đầu quý: CORE sinh báo cáo user × role × level; GW bổ sung inventory credentials/token + ngày rotate; CFO/CTO (bị review) xuất nộp CEO trên WEB.
2. CEO đối chiếu, đánh dấu giữ/thu hồi từng dòng; quyết định gán/thu hồi role; SYS_ADMIN thực thi; bằng chứng ký lưu vào access review record.
3. Quyền không được review 2 quý liên tiếp → CORE tự vô hiệu đến khi review xong.
4. Liên tục: cảnh báo token đến hạn rotate T-7; offboarding → tự revoke + rotate credentials ≤24h, checklist xác nhận CTO; nghỉ đột xuất chạy offboarding khẩn 24h, lệch chuẩn ghi nhận vào kỳ review.

**Business rules:** BR-BOD-007.1 chỉ CEO duyệt gán/thu hồi role — SYS_ADMIN không tự gán kể cả cho chính mình; BR-BOD-007.2 người thử việc/freelancer không có quyền phê duyệt; guest tối đa 90 ngày (gia hạn phải duyệt); BR-BOD-007.3 MOBILE không có touchpoint riêng — chu trình quý thực hiện trên WEB (bảng lớn, đối chiếu nhiều nguồn).

**Ngoại lệ/delegate:** CEO ký quarterly review không ủy quyền (compensating control); CEO vắng dài ngày → quyền không review tự vô hiệu — an toàn theo thiết kế. **Quyền:** BOD_CEO chủ trì + ký; BOD_CFO_CTO xuất báo cáo và bị review; SYS_ADMIN thực thi sau duyệt.

### B8. REQ-BOD-008 — Quản trị Integration Gateway & credentials vault (vai CTO)

**Workflow:**
1. CTO đăng nhập WEB console với MFA TOTP; thêm/sửa/rotate/thu hồi credentials 7 nền tảng — giá trị chỉ nằm trong vault GW mã hóa, không bao giờ trả plaintext về UI/API.
2. SYS_ADMIN thực thi thay đổi theo change được CTO duyệt (policy change management); mọi thao tác vault ghi immutable audit (CORE); GW log mọi lần gọi API nền tảng.
3. Theo dõi sức khỏe 7 adapter (thành công/thất bại/degraded + tuổi dữ liệu từng nguồn); scheduler sync 2.600+ TK; degraded mode gắn nhãn "manual".
4. Thu hồi khẩn khi nghi ngờ rò rỉ hoặc người liên quan nghỉ việc: revoke + rotate ≤24h; rotate định kỳ ≥90 ngày.

**Business rules:** BR-BOD-008.1 MFA bắt buộc mọi tài khoản quản trị vault; BR-BOD-008.2 **MOBILE cấm toàn bộ thao tác vault** — thiết bị di động dễ mất, môi trường không kiểm soát, trong khi credentials là tài sản tương đương tiền (mất = mất quyền điều hành ngân sách QC của khách); MOBILE chỉ nhận alert sức khỏe adapter (REQ-BOD-006), không hiển thị chi tiết credentials; BR-BOD-008.3 chưa có quyền API developer → degraded mode có kiểm soát, backfill tự động khi được cấp, chênh lệch manual vs API >±0,1% vào báo cáo đối soát.

**Ngoại lệ/delegate:** hành vi vault không ủy quyền; SYS_ADMIN không thấy plaintext, thao tác qua API có log. **Quyền:** BOD_CFO_CTO (CTO) quản trị vault; SYS_ADMIN thực thi; vai khác dùng credentials gián tiếp.

### B9. REQ-BOD-009 — Duyệt chính sách, tham số quản trị & tier

**Workflow:**
1. Soạn thảo trên WEB: ma trận hạn mức chi/giải ngân `[CẦN CHỐT SỐ — đề xuất 5/50/200 triệu]`, định mức giá/Cost Rate Card, khung SLA theo tier, tham số Tier A–E, ngưỡng freshness — CORE tạo version nháp kèm ngày hiệu lực đề xuất.
2. Duyệt: chính sách/định mức/tier → CEO; định nghĩa metric + ngưỡng freshness → CFO; Tier A–E rà soát định kỳ quý.
3. Ban hành effective-dated: áp theo ngày hiệu lực đã duyệt, không sửa quá khứ; luồng duyệt và báo cáo dùng đúng phiên bản hiệu lực tại thời điểm dữ liệu.
4. Mỗi tham số lưu version, ngày hiệu lực, người duyệt; thay đổi trace audit log (old → new).

**Business rules:** BR-BOD-009.1 không hồi tố — chỉ hiệu lực tương lai; BR-BOD-009.2 áp gấp giữa kỳ được phép nhưng mốc hiệu lực rõ ràng, có thông báo; BR-BOD-009.3 MOBILE không có touchpoint — duyệt chính sách cần hồ sơ đầy đủ trên WEB.

**Ngoại lệ/delegate:** CEO ủy quyền duyệt chính sách theo B0 được, trừ thay đổi liên quan giao dịch do CFO khởi tạo; hiệu lực hồi tố bị CORE chặn tuyệt đối. **Quyền:** BOD_CEO duyệt chính sách/định mức/tier; BOD_CFO_CTO duyệt metric/freshness; SYS_ADMIN áp cấu hình sau duyệt, không tự chỉnh giá trị.

### B10. REQ-BOD-010 — Phê duyệt tài chính độc quyền của CFO

**Workflow:**
1. CFO vào WEB màn hình duyệt có ngữ cảnh đầy đủ: kỳ số liệu, chênh lệch đối soát, lý do bắt buộc.
2. Lệnh chỉ role `BOD_CFO_CTO` thực thi được (CORE enforce, log + lý do): duyệt hạn mức tín dụng TKQC theo nền tảng/khách; mở lại kỳ kế toán đã khóa (FIN_L2 đề xuất → CFO duyệt); duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc.
3. Sự cố M3/cảnh báo đỏ: CFO cùng CEO quyết trong 4h — MOBILE chỉ nhận push thông báo, quyết định ký trên WEB.
4. Kỳ mở lại phải chốt lần hai có ghi nhận; backfill ghi ai sửa, giá trị trước/sau, lý do.

**Business rules:** BR-BOD-010.1 vai khác gọi các lệnh trên bị CORE từ chối, mọi attempt log; BR-BOD-010.2 cấm sửa đè không vết — điều chỉnh luôn qua giao dịch ngược (reversal) có reason code; BR-BOD-010.3 quyết toán lại quý cũ phục vụ kiểm toán đi qua backfill có phê duyệt, không đụng bản ghi gốc; BR-BOD-010.4 MOBILE không có requirement riêng — tần suất thấp, thực hiện trên WEB.

**Ngoại lệ/delegate:** lệnh độc quyền CFO không ủy quyền (kể cả cho CEO); CFO vắng → lệnh treo đến khi CFO thao tác từ xa. **Quyền:** BOD_CFO_CTO duyệt độc quyền; BOD_CEO đồng quyết M3; FIN_L2/SYS_ADMIN chỉ đề xuất.

### B11. Ma Trận Business-Rules × System

✔ = thực thi tại hệ thống; ◐ = một phần (hiển thị/nhận sự kiện); — = không liên quan.

| Business Rule | SYS-CORE | SYS-WEB | SYS-GW | SYS-MOBILE | Ghi chú |
|---|---|---|---|---|---|
| BR-BOD-001.1 Chặn giải ngân thiếu chữ ký / SoD | ✔ | ✔ hàng đợi + SLA | — | ✔ duyệt MFA; ≥200tr phải mở chứng từ | Dual approval |
| BR-BOD-001.3/001.4 Hạn mức tuần; chi khẩn 4h/hậu kiểm 24h | ✔ | ✔ | — | ✔ kênh khẩn chính | |
| BR-BOD-002.1 Hard block giao dịch CFO khởi tạo → CEO duyệt | ✔ | ✔ hàng đợi CEO | — | ✔ duyệt khẩn ≤4h | Compensating control |
| BR-BOD-002.2/002.3 Quarterly review; tự vô hiệu 2 quý | ✔ | ✔ CEO ký | ✔ inventory credentials | — | Ngày 1–10 đầu quý |
| BR-BOD-003.1 Tách tiền giữ hộ khỏi doanh thu | ✔ | ✔ | ✔ nguồn ví | ✔ chỉ xem | Nạp khách = nợ phải trả |
| BR-BOD-003.2/003.4 Freshness + nhãn api/manual | ✔ | ✔ | ✔ sync | ✔ chỉ báo + cảnh báo đỏ | Không nội suy |
| BR-BOD-004.1/004.2 Metric Catalog; block publish | ✔ | ✔ | — | ◐ hiển thị nhãn | Phase 3 |
| BR-BOD-005.1/005.2 Append-only; hash-chain; meta-log | ✔ | ✔ tra cứu | — | ✖ cấm tra cứu | WORM ≥10/7 năm |
| BR-BOD-005.3 Xuất log phải CEO duyệt | ✔ | ✔ | — | — | Thanh tra cùng luồng |
| BR-BOD-006.1/006.2 Push ≤5 phút; ack + reason; gộp outage | ✔ rule engine | ✔ tổng hợp | ◐ nguồn sự kiện | ✔ kênh chính | Lock-screen ẩn T3/T4 |
| BR-BOD-007.1 CEO duyệt gán/thu hồi role | ✔ | ✔ workspace | ✔ inventory | — | Review trên WEB |
| BR-BOD-008.1/008.2 Vault không plaintext; MFA; cấm mobile | ✔ MFA/audit | ✔ console | ✔ vault + log API | ✖ cấm | Tài sản tương đương tiền |
| BR-BOD-009.1/009.3 Effective-dated; version; không hồi tố | ✔ | ✔ duyệt/ký | — | — | Không touchpoint mobile |
| BR-BOD-010.1 Lệnh tài chính CFO-only | ✔ | ✔ | — | — | Log + lý do bắt buộc |
