# DEPT-HR — Phòng Hành chính Nhân sự (HR)

> **Phòng ban:** Phòng Hành chính Nhân sự (NVHR `HR_L1`, TPHR `HR_L2`)
> **Ngày cập nhật:** 12/09/2026
> **Trạng thái:** Đang phân tích (Phần A hoàn thành — chờ Team Expert review)
>
> READS: `P1-01-project-overview.md`, `P0-01-brainstorm.md`, `P0-02-systems-users.md`, `policies/nhan-su-hanh-chinh-cost-rate-card.md`, `policies/timesheet-capacity.md`, `policies/kpi-hieu-suat.md`, `policies/bao-ve-du-lieu-ca-nhan.md`
> USED BY: `departments/_index.md`, `_meta/req-registry.json`, `phase2-features/[sys]/[mod]/[feat].md`

---

## Phần A — Phân Tích BA (Stakeholders & User Needs)

### A0. Phạm Vi Hệ Thống & Ma Trận Requirement × System

DEPT-HR phục vụ **SYS-BCERP-WEB + SYS-CORE-BACKEND** (HR Core là phân hệ GĐ1 trên web nội bộ):

- **SYS-CORE-BACKEND (primary đa số REQ):** master data nhân sự, rule engine (SCD2, validation chặn cứng, tự tổng hợp KPI), bảo mật PII — nơi RBAC, hoa hồng, P&L, KPI, BI đọc dữ liệu.
- **SYS-BCERP-WEB:** màn hình thao tác HR_L1/HR_L2, TL/Manager, cổng self-service toàn nhân viên.
- **SYS-MOBILE-INTERNAL:** *ngoài scope mobile hiện tại* (`related_departments` không khai báo HR). Need "duyệt phép/timesheet/OT khi di chuyển" ghi nhận tại REQ-HR-004/005/009 — xem xét khi mở rộng scope.
- **SYS-INTEGRATION-GW:** không có requirement riêng — HR không tích hợp API ngoài; import mở sổ (hồ sơ, cost rate từ Google Sheets) đi qua cơ chế import dùng chung của SYS-CORE-BACKEND.
- **SYS-PORTAL-WEB / SYS-MOBILE-PORTAL:** không có requirement riêng, dùng chung với SYS-CORE-BACKEND — dữ liệu HR/PII cấm tuyệt đối lộ qua portal khách.

| REQ-ID | Title | Systems liên quan | Primary system | Lý do tách/gộp |
|--------|-------|-------------------|----------------|----------------|
| REQ-HR-001 | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | CORE-BACKEND, BCERP-WEB | CORE-BACKEND | Master data dùng chung 5 phân hệ; rule ở backend |
| REQ-HR-002 | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | CORE-BACKEND, BCERP-WEB | BCERP-WEB | Touchpoint chính là màn hình HR + job nhắc |
| REQ-HR-003 | Chấm công & overtime | BCERP-WEB, CORE-BACKEND | BCERP-WEB | Nhập công hằng ngày trên web; rule trần giờ ở backend |
| REQ-HR-004 | Nghỉ phép: số dư & duyệt phân cấp | BCERP-WEB, CORE-BACKEND | BCERP-WEB | Workflow duyệt trên web; validation số dư ở backend |
| REQ-HR-005 | Self-service nhân viên (ESS) | BCERP-WEB, CORE-BACKEND | BCERP-WEB | Cổng cho toàn nhân viên trên web nội bộ |
| REQ-HR-006 | Cost Rate Card version hóa, thẩm định finance | CORE-BACKEND, BCERP-WEB | CORE-BACKEND | Đầu vào P&L/BI; vòng đời duyệt riêng (FIN_L2 + BOD) |
| REQ-HR-007 | KPI 3 trụ cột tự tổng hợp + calibration | CORE-BACKEND, BCERP-WEB | CORE-BACKEND | Tổng hợp tự động; tách khỏi PIP (dữ liệu vs. workflow) |
| REQ-HR-008 | PIP 30-60-90 | BCERP-WEB, CORE-BACKEND | BCERP-WEB | Workflow coaching, quản milestone riêng |
| REQ-HR-009 | Duyệt timesheet & capacity (phối hợp OPS) | CORE-BACKEND, BCERP-WEB | CORE-BACKEND | OPS sở hữu nhập giờ/gán việc, HR sở hữu quy tắc duyệt + định mức; không gộp tránh trùng REQ DEPT-OPS |
| REQ-HR-010 | Bảo vệ PII nhân sự (lương Confidential/Restricted) | CORE-BACKEND, BCERP-WEB | CORE-BACKEND | Security cross-cutting, ràng buộc NĐ 13/2023, áp cho mọi REQ |

---

### A1. Giới Thiệu Phòng Ban

**Phòng ban này làm gì:** Quản lý vòng đời nhân sự toàn công ty (31–50 người, 5 phòng ban) theo **Level L1–L5 + mã vai (OPS/FIN/SALES/HR)** — nguồn sự thật duy nhất cho RBAC, hoa hồng, cost rate, capacity, KPI. Nhiệm vụ: hồ sơ & HĐLĐ, chấm công/nghỉ phép, Cost Rate Card, KPI–PIP, bảo vệ PII.

**Những người sẽ dùng hệ thống:**

| Vai trò | Số lượng | Công việc hàng ngày | Cần hệ thống hỗ trợ gì | Concerns chính |
|---------|----------|--------------------|-----------------------|----------------|
| NVHR (`HR_L1`) | 1–2 | Hồ sơ, chấm công, đơn nghỉ | Màn hình hồ sơ/công, cảnh báo tự động | Nhập hai nơi, mất lịch sử sửa |
| TPHR (`HR_L2`) | 1 | Duyệt KPI, headcount, rate card, PII | Workflow duyệt, calibration, báo cáo | Lộ lương/cost, KPI cảm tính |
| TL/Manager toàn công ty | 5–8 | Duyệt phép/timesheet/OT, review KPI | Hàng đợi duyệt, dashboard workload | Đơn trôi, không biết ai quá tải |
| Nhân viên toàn công ty | 30–45 | Xin nghỉ, điều chỉnh công, xem KPI mình | Cổng self-service | KPI không minh bạch dữ liệu gốc |
| BOD (CEO, CFO kiêm CTO) | 2 | Duyệt định mức/rate, xem KPI | Trình duyệt, báo cáo | Thiếu số ra quyết định |
| FIN_L2 (Kế toán trưởng) | 1 | Thẩm định rate card vs. payroll | Bảng đối chiếu rate–payroll | Cost lệch làm sai P&L |
| SYS_ADMIN | 1 | Cấp/thu hồi tài khoản theo lệnh HR | Sync hồ sơ → tài khoản | Offboard chậm, quyền sót |

---

### A2. Tổng Hợp Nhu Cầu

> Mức độ: **HIGH = Bắt buộc**, **MEDIUM = Quan trọng**, **LOW = Nên có**. Phase gợi ý theo GĐ1/GĐ2/GĐ3 (tương ứng MVP=GĐ1 / Phase2=GĐ2 / Phase3=GĐ3).

| STT | Mã nhu cầu | Tên nhu cầu | Ưu tiên | Phase |
|-----|-----------|------------|---------|-------|
| 1 | REQ-HR-001 | Hồ sơ nhân sự trung tâm L1–L5 + mã vai | HIGH | GĐ1 |
| 2 | REQ-HR-002 | HĐLĐ & cảnh báo hết hạn 90/60/30 ngày | HIGH | GĐ1 |
| 3 | REQ-HR-003 | Chấm công & overtime | HIGH | GĐ1 |
| 4 | REQ-HR-004 | Nghỉ phép: số dư tự động & duyệt phân cấp | HIGH | GĐ1 |
| 5 | REQ-HR-005 | Self-service nhân viên (ESS) | MEDIUM | GĐ1 |
| 6 | REQ-HR-006 | Cost Rate Card version hóa, thẩm định finance | HIGH | GĐ1 |
| 7 | REQ-HR-007 | KPI 3 trụ cột tự tổng hợp + calibration | HIGH | GĐ3 |
| 8 | REQ-HR-008 | PIP 30-60-90 | MEDIUM | GĐ3 |
| 9 | REQ-HR-009 | Duyệt timesheet & capacity (phối hợp OPS) | HIGH | GĐ2 |
| 10 | REQ-HR-010 | Bảo vệ PII — lương Confidential/Restricted | HIGH | GĐ1 |

---

### A3. Chi Tiết Từng Nhu Cầu

#### REQ-HR-001: Hồ sơ nhân sự trung tâm L1–L5 + mã vai — nguồn sự thật

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-CORE-BACKEND (primary), SYS-BCERP-WEB
**Ai cần dùng:** HR_L1/HR_L2; RBAC, hoa hồng, P&L, KPI đọc từ đây.

**Tôi cần hệ thống làm được:**

- [ ] Mỗi nhân sự đúng 1 hồ sơ: mã NV, phòng ban, TL trực tiếp, mã vai + Level + ngày hiệu lực, trạng thái (thử việc/chính thức/nghỉ dài/nghỉ không lương/nghỉ việc), BHXH, TK lương.
- [ ] Thay đổi Level/vai/trạng thái **version hóa hiệu lực từ ngày–đến ngày (SCD2)**, không ghi đè lịch sử; RBAC/hoa hồng/P&L/KPI đọc chung, không bản sao riêng.
- [ ] Hồ sơ mới → lệnh cấp tài khoản gắn RBAC theo mã vai; "nghỉ việc" → lệnh thu hồi tài khoản + quyền TKQC trong 24h.
- [ ] Headcount: Requisition do HR_L2 duyệt trước khi đăng tin; vượt kế hoạch năm → BOD.

**Quy tắc:** freelancer ngoài biên chế không tạo hồ sơ (tính như chi phí dịch vụ); mọi thay đổi có audit log bất biến; hỗ trợ 1 người nhiều vai.
**Tình huống đặc biệt:** thăng chức giữa chu kỳ (version mới từ ngày hiệu lực); nghỉ không lương >30 ngày (đóng băng allocation/capacity); onboarding checklist là điều kiện đánh giá hết thử việc.

---

#### REQ-HR-002: HĐLĐ & cảnh báo hết hạn 90/60/30 ngày

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-BCERP-WEB (primary), SYS-CORE-BACKEND (job nhắc)
**Ai cần dùng:** HR_L1 (nhập); HR_L2 + TL (nhận cảnh báo).

**Tôi cần hệ thống làm được:**

- [ ] Lưu loại, số HĐ, ngày ký, hiệu lực, hết hạn, nội dung chính + file scan.
- [ ] Tự động nhắc trước hết hạn **90/60/30 ngày** cho HR_L2 và TL.
- [ ] HĐ xác định thời hạn hết hạn chưa ký tiếp → **cảnh báo đỏ** (rủi ro pháp lý).

**Quy tắc:** đánh giá hết thử việc trước ≥3 ngày; đạt mới ký HĐLĐ chính thức; lưu theo retention pháp luật lao động.
**Tình huống đặc biệt:** HĐ không xác định thời hạn (tắt nhắc); chấm dứt giữa hạn (ghi lý do đúng pháp luật).

---

#### REQ-HR-003: Chấm công & overtime

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-BCERP-WEB (primary), SYS-CORE-BACKEND (validation)
**Ai cần dùng:** toàn bộ nhân viên; HR_L1 xử lý; TL duyệt điều chỉnh.

**Tôi cần hệ thống làm được:**

- [ ] Ghi công theo ngày; giờ chuẩn **40h/tuần (T2–T6)**; giờ linh hoạt được phép nhưng đạt định mức giờ/tuần theo Level.
- [ ] OT duyệt trước (khẩn cấp retro 24h kèm lý do); **chặn khi tổng giờ chuẩn + OT > 48h/tuần** (Điều 107 BLLĐ 2019), trần 200h/năm.
- [ ] Tổng hợp công + OT cho payroll/BHXH và đối chiếu timesheet dự án (GĐ2).

**Quy tắc:** điều chỉnh công phải người khác duyệt + audit log; tuần có ngày lễ giảm định mức.
**Tình huống đặc biệt:** quên chấm công (điều chỉnh có duyệt); làm đa múi giờ với khách (ghi theo giờ làm việc VN).

---

#### REQ-HR-004: Nghỉ phép — số dư tự động & duyệt phân cấp

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-BCERP-WEB (primary), SYS-CORE-BACKEND (validation)
**Ai cần dùng:** toàn bộ nhân viên (đơn); TL, HR_L2 (duyệt).

**Tôi cần hệ thống làm được:**

- [ ] Tự động tích lũy phép năm **12 ngày/năm** (1 ngày/tháng), hiển thị số dư.
- [ ] Đơn nghỉ online: đề nghị trước ≥3 ngày làm việc; duyệt phân cấp — **≤5 ngày: TL duyệt 24h; >5 ngày hoặc nghỉ không lương: HR_L2 duyệt 48h**.
- [ ] **Chặn duyệt vượt số dư**; nghỉ đã duyệt tự trừ capacity tuần (nối REQ-HR-009).
- [ ] Nghỉ ốm ≥3 ngày kèm giấy khám bệnh; khác theo BLLĐ 2019.

**Tình huống đặc biệt:** nghỉ đột xuất (retro có lý do); nghỉ không lương >30 ngày (đóng băng allocation, KPI prorate); thai sản/ốm dài (prorate/miễn KPI theo HR_L2).

---

#### REQ-HR-005: Self-service nhân viên (ESS)

**Ưu tiên:** MEDIUM | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-BCERP-WEB (primary), SYS-CORE-BACKEND
**Ai cần dùng:** toàn bộ nhân viên; HR_L2 duyệt thay đổi nhạy cảm.

**Tôi cần hệ thống làm được:**

- [ ] Nhân sự tự thao tác: xem hồ sơ, xin nghỉ, đề nghị điều chỉnh công, xem timesheet + dữ liệu gốc KPI của mình, cập nhật thông tin cá nhân.
- [ ] Trường nhạy cảm (TK ngân hàng, liên hệ khẩn) và thay đổi ảnh hưởng payroll phải **HR_L2 duyệt** trước khi hiệu lực.
- [ ] Thông báo trong hệ thống: nhắc chốt timesheet, hạn duyệt, kỳ KPI.

**Ghi chú:** need "nhận nhắc + duyệt nhanh trên mobile" — ngoài scope mobile hiện tại (SYS-MOBILE-INTERNAL không khai báo HR).
**Quy tắc:** mỗi người chỉ thấy dữ liệu của mình; mọi thao tác ESS có audit log.

---

#### REQ-HR-006: Cost Rate Card version hóa — thẩm định finance

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-CORE-BACKEND (primary — đầu vào P&L/BI), SYS-BCERP-WEB
**Ai cần dùng:** HR_L2 (đề xuất); FIN_L2 (thẩm định); BOD (duyệt); P&L/BI đọc.

**Tôi cần hệ thống làm được:**

- [ ] Bảng **cost/hour chuẩn theo Level, version hóa hiệu lực từ ngày–đến ngày (SCD2)**: Level, cost/hour, khoảng hiệu lực, số version, người duyệt.
- [ ] P&L và báo cáo dự án **chọn đúng version theo ngày ghi giờ** — không sửa quá khứ.
- [ ] Thay đổi: HR_L2 đề xuất + **FIN_L2 thẩm định (đối chiếu payroll)** → **BOD duyệt** → phát hành version mới; version đã phát hành không sửa.
- [ ] Giá trị cost/hour từng Level: `[CẦN CHỐT SỐ]` — khung mặc định: import từ payroll thực tế khi migration mở sổ, duyệt lại chu kỳ năm.

**Quy tắc:** cost là Confidential/Restricted (xem REQ-HR-010); manager chỉ xem tổng cost nhóm.
**Tình huống đặc biệt:** thăng Level giữa năm (rate mới từ ngày hiệu lực); freelancer liên tục ≥3 tháng (BOD có thể yêu cầu Rate Card tham chiếu riêng).

---

#### REQ-HR-007: KPI 3 trụ cột tự tổng hợp + calibration HR_L2

**Ưu tiên:** HIGH | **Phase:** GĐ3 | **Hệ thống liên quan:** SYS-CORE-BACKEND (primary — tổng hợp tự động), SYS-BCERP-WEB
**Ai cần dùng:** toàn bộ nhân sự (xem); TL/Manager (review); HR_L2 (calibration); BOD (chốt L4–L5).

**Tôi cần hệ thống làm được:**

- [ ] Tự tổng hợp 3 trụ cột — **cấm nhập điểm tay**: (1) On-time Delivery từ task deadline; (2) Output Volume từ deliverable đạt QC; (3) Project Target/SLA từ dữ liệu dự án.
- [ ] Trọng số theo Level hiện hành (L1 20/50/15 → L5 20/10/55; chấm tay 15%); đổi trọng số: HR_L2 đề xuất → BOD duyệt.
- [ ] Tiêu chí chấm tay phải khai báo trọng số + rubric trước; mỗi điểm có người chấm, ngày, nhận xét.
- [ ] Review quý minh bạch: nhân sự xem dữ liệu gốc trước, thắc mắc trong 3 ngày làm việc; **calibration HR_L2** trước khi trình BOD (bắt buộc L4–L5, top/bottom); biên bản lưu hệ thống.
- [ ] Quá tải >100% liên tục ≥2 tuần → gắn cờ, **miễn phạt điểm On-time** cho trễ do quá tải; quá 3 lần cờ/quý → HR_L2 xem xét headcount.

**Tình huống đặc biệt:** nhân sự mới <30 ngày (định tính); nghỉ dài ≥1 tháng (prorate/miễn); dự án khẩn BOD duyệt loại trừ; thử việc chỉ áp Output Volume + tuân thủ (70/30), không PIP.

---

#### REQ-HR-008: PIP 30-60-90

**Ưu tiên:** MEDIUM | **Phase:** GĐ3 | **Hệ thống liên quan:** SYS-BCERP-WEB (primary), SYS-CORE-BACKEND
**Ai cần dùng:** Manager (đề xuất/coaching); HR_L2 (duyệt, lưu hồ sơ); BOD (quyết định cuối).

**Tôi cần hệ thống làm được:**

- [ ] Gợi ý điều kiện mở PIP từ KPI: điểm quý <60/100; 2 quý liên tiếp dưới kỳ vọng; vi phạm SLA nghiêm trọng đã xác nhận.
- [ ] Manager đề xuất + HR_L2 duyệt trong 5 ngày làm việc sau công bố KPI; theo dõi **mốc 30/60/90**, coaching tối thiểu 2 tuần/lần.
- [ ] Kết thúc: đạt → thoát; không đạt → BOD quyết định điều chuyển, hạ Level hoặc chấm dứt HĐLĐ đúng pháp luật; hồ sơ PIP lưu hệ thống.

**Tình huống đặc biệt:** nghỉ dài trong lúc PIP (tạm dừng, tính lại mốc); thử việc không áp PIP.

---

#### REQ-HR-009: Quy trình duyệt timesheet & capacity (phối hợp OPS)

**Ưu tiên:** HIGH | **Phase:** GĐ2 | **Hệ thống liên quan:** SYS-CORE-BACKEND (primary — validation engine), SYS-BCERP-WEB
**Ranh giới với DEPT-OPS:** OPS sở hữu ghi timesheet hằng ngày và gán capacity (xem DEPT-OPS); HR đồng sở hữu **quy tắc duyệt, định mức, escalation** — không gộp với REQ của OPS.
**Ai cần dùng:** TL/Manager (duyệt); nhân sự (chốt tuần); HR_L2 (OT vượt trần, cân đối); FIN (nhận giờ đã duyệt).

**Tôi cần hệ thống làm được:**

- [ ] Chốt tuần trước 12:00 thứ Hai; **TL duyệt trong 48h; cấm tự duyệt** (approver ≠ người ghi; timesheet của TL do Manager L4 duyệt).
- [ ] **Giờ chưa duyệt không tính vào P&L** — chỉ giờ đã duyệt nhân Cost Rate Card (REQ-HR-006) để allocate chi phí.
- [ ] Correction giờ đã ghi qua TL xác nhận + audit log; định mức giờ/tuần và tỷ lệ billable mục tiêu theo bậc do HR_L2 đề xuất → BOD duyệt (chu kỳ năm).
- [ ] Escalation capacity check: quá 4h → TL; quá 8h → **HR_L2 cân đối đầu người**; OT vượt trần/retro do HR_L2 duyệt 24h.

**Ghi chú:** need "duyệt trên mobile" — ngoài scope mobile hiện tại.

---

#### REQ-HR-010: Bảo vệ PII nhân sự — lương Confidential/Restricted

**Ưu tiên:** HIGH | **Phase:** GĐ1 | **Hệ thống liên quan:** SYS-CORE-BACKEND (primary — security cross-cutting), SYS-BCERP-WEB
**Ai cần dùng:** HR_L2 (quản trị PII); SYS_ADMIN (thu hồi quyền); legal (breach).

**Tôi cần hệ thống làm được:**

- [ ] Phân loại PII: C1 nhạy cảm (CCCD, lương, TK ngân hàng) — mã hóa khi lưu/truyền, cấm xuất raw; C2 định danh thường; C3 công việc.
- [ ] RBAC tier Restricted cho lương/cost: **chỉ HR_L2+ xem lương/cost cá nhân; HR_L1 không xem lương**; manager chỉ xem tổng cost nhóm; mọi lượt xem/sửa lương, HĐLĐ, dữ liệu C1 có **audit log bất biến** (ai — khi nào — trước/sau).
- [ ] Offboard thu hồi quyền trong 24h; review ma trận truy cập C1 theo quý.
- [ ] Retention: hồ sơ nhân sự theo pháp luật lao động; lương/chứng từ kế toán **10 năm** (Luật Kế toán 2015); hồ sơ ứng tuyển không trúng 12 tháng; hết hạn → xóa/ẩn danh có log.
- [ ] Data minimization cho form tuyển dụng/onboarding; phối hợp legal khi breach (thông báo 72h theo NĐ 13/2023).

**Tình huống đặc biệt:** nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa; xuất dữ liệu cho thuế/BHXH theo mẫu có log.

---

### A4. Dữ Liệu Phòng Ban Cần Quản Lý

| STT | Loại dữ liệu | Thông tin cần lưu | Ghi chú quan trọng |
|-----|-------------|------------------|--------------------|
| 1 | Hồ sơ nhân sự | Mã NV, phòng ban, TL, mã vai + Level + hiệu lực, trạng thái, BHXH, TK lương | SCD2; nguồn sự thật RBAC/hoa hồng/P&L/KPI |
| 2 | Hợp đồng lao động | Loại, số, hiệu lực, hết hạn, file scan | Cảnh báo 90/60/30 ngày |
| 3 | Chấm công & OT | Công ngày, giờ linh hoạt, OT có duyệt, điều chỉnh | Trần 48h/tuần; điều chỉnh có duyệt + log |
| 4 | Nghỉ phép | Loại, từ–đến, số dư, người duyệt, giấy tờ | Chặn vượt số dư; trừ capacity tuần |
| 5 | Cost Rate Card | Level, cost/hour, hiệu lực, version, người duyệt | SCD2; Confidential/Restricted |
| 6 | KPI kỳ & calibration | Điểm 3 trụ cột, trọng số, điểm chấm tay + rubric, biên bản | Cấm nhập điểm tay 3 trụ cột |
| 7 | Hồ sơ PIP | Lý do, mốc 30/60/90, coaching, kết luận | Lưu vết toàn bộ |
| 8 | Log truy cập PII | Ai, khi nào, xem/sửa dữ liệu C1 | Bất biến; xem log cũng bị log |

---

### A5. Báo Cáo & Thống Kê Cần Có

| STT | Tên báo cáo | Nội dung | Tần suất | Người xem |
|-----|------------|----------|----------|-----------|
| 1 | Headcount theo phòng/Level | Hiện hành vs. kế hoạch, biến động | Tháng | HR_L2, BOD |
| 2 | Cảnh báo HĐLĐ & thử việc | HĐ đến hạn 90/60/30 ngày, thử việc sắp hết | Tuần | HR_L2, TL |
| 3 | Tổng cost nhân sự theo team/Level | Tổng cost nhóm từ Rate Card (không lương cá nhân) | Tháng/quý | HR_L2, BOD; manager xem nhóm mình |
| 4 | Tỷ lệ billable thực tế theo bậc | Giờ billable đã duyệt ÷ tổng giờ, so mục tiêu | Tháng | HR_L2, BOD |
| 5 | Tổng hợp KPI & phân bố điểm | Điểm 3 trụ cột, outlier, cờ quá tải | Quý | HR_L2, BOD |
| 6 | Theo dõi PIP | PIP đang chạy, mốc 30/60/90, kết quả | Quý | HR_L2, BOD |
| 7 | Review truy cập dữ liệu C1 | Lượt xem/sửa lương, HĐLĐ; anomaly | Quý | HR_L2, SYS_ADMIN |

---

### A6. Điều Phòng Ban KHÔNG Muốn

- Không muốn **lương/cost cá nhân lộ** ngoài HR_L2+ — kể cả HR_L1, manager (ngoài tổng nhóm) hay xuất Excel.
- Không muốn **sửa đè dữ liệu quá khứ** (Level, vai, cost rate) — mọi thay đổi là version mới; P&L quá khứ tái lập được.
- Không muốn quay lại **KPI chấm cảm tính** — cấm nhập điểm tay 3 trụ cột.
- Không muốn ai **tự duyệt timesheet/phép của chính mình**, kể cả cấp quản lý.
- Không muốn dữ liệu PII nhân sự xuất hiện trên Client Portal hoặc báo cáo gửi khách.
- Không muốn mất lịch sử chấm công/điều chỉnh — sai sót xử lý bằng correction có audit log.

---

### A7. Đánh Giá Của Team Expert

*Team Expert điền phần này sau khi đánh giá Phần A.*

#### A7.1 Kết Quả Đánh Giá Tổng Thể

| Hạng mục | Kết quả | Ghi chú |
|----------|---------|---------|
| Mức độ đầy đủ / Tính khả thi / Độ rõ ràng | Chờ đánh giá | |
| Trùng lặp với PB khác | Chờ đánh giá | Ranh giới REQ-HR-009 với DEPT-OPS đã khai báo |

#### A7.2 Các Điểm Cần Làm Rõ / Bổ Sung

| # | Điểm cần làm rõ | Liên quan | Hành động | Trạng thái |
|---|----------------|-----------|-----------|-----------|
| 1 | Giá trị cost/hour từng Level chưa có số — dùng khung mặc định import từ payroll khi migration | REQ-HR-006 | HR + FIN chốt | Chờ |
| 2 | Định mức giờ/tuần, tỷ lệ billable theo bậc: có khung policy, chờ BOD duyệt chu kỳ năm | REQ-HR-009 | Xác nhận policy | Chờ |
| 3 | Need mobile HR (duyệt phép/timesheet) — ngoài scope SYS-MOBILE-INTERNAL hiện tại | REQ-HR-004/005/009 | Xem lại khi mở rộng scope | Chờ |

#### A7.3 Điều Chỉnh Sau Đánh Giá

(Chờ Team Expert review.)

#### A7.4 Kết Luận & Xác Nhận

**Kết luận:** Phần A đủ để chuyển sang Phần B (Workflow) và Phase 2 sau khi Team Expert xác nhận.

| Vai trò | Tên | Ngày xác nhận |
|---------|-----|--------------|
| Expert phụ trách viết | business-analyst (BA) | 12/09/2026 |
| Team Expert review | Chờ | |
| Đại diện phòng ban | Chờ | |

---

## Phần B — Quy Trình Nghiệp Vụ & Business Rules (HR Expert Review)

> **Người review:** hr-expert (CHRO) — **Ngày:** 12/09/2026 — **Profile:** LPM
> **Bám sát** 10 REQ của Phần A, không tạo REQ mới. DEPT-HR chỉ dùng 2 hệ thống: **SYS-CORE-BACKEND** (master data, SCD2, rule engine/validation, bảo mật PII) + **SYS-BCERP-WEB** (màn hình thao tác, workflow duyệt, ESS). **SYS-MOBILE-INTERNAL giữ nguyên ghi chú Phần A: ngoài scope mobile hiện tại** (need duyệt phép/timesheet/OT khi di chuyển tại REQ-HR-004/005/009 — xem lại khi mở rộng scope).
> **Quy ước nền áp cho mọi REQ:** R1 — mọi thay đổi Level/vai/trạng thái/cost là **version SCD2 mới** hiệu lực từ ngày–đến ngày, cấm sửa đè quá khứ; R2 — mọi thao tác ghi/sửa/duyệt/xem dữ liệu nhạy cảm có **audit log bất biến**; R3 — lương/cost cá nhân là **Restricted** theo REQ-HR-010.

### B1. REQ-HR-001 — Hồ sơ nhân sự & vòng đời (onboarding / đổi Level / offboarding)

**B1.1. Onboarding nhân sự mới**

| Bước | Actor | Hành động | Hệ thống — điều kiện |
|------|-------|-----------|----------------------|
| 1 | HR_L2 | Duyệt Requisition (headcount) trước khi đăng tin | WEB trình duyệt; vượt kế hoạch năm → BOD duyệt (3 ngày làm việc) |
| 2 | HR_L1 | Tạo hồ sơ: mã NV tự sinh, phòng ban, TL trực tiếp, mã vai + Level + ngày hiệu lực, trạng thái "Thử việc" | WEB form; CORE validate "1 người 1 hồ sơ" (cho phép nhiều vai), mã hóa trường C1 ngay khi lưu |
| 3 | SYS_ADMIN | Kích hoạt tài khoản theo **lệnh cấp RBAC** hệ thống phát theo mã vai | CORE phát lệnh + ghi log; không cấp tay ngoài lệnh |
| 4 | HR_L1 | Tạo **version cost rate đầu tiên** cho NV theo Rate Card đang hiệu lực (REQ-HR-006), hiệu lực từ ngày làm việc đầu tiên | CORE sinh tự động theo Level; điều chỉnh được trước khi FIN_L2 thẩm định |
| 5 | HR_L1 + buddy | Chạy onboarding checklist (ký HĐLĐ, tài khoản, buddy, mục tiêu thử việc) | WEB checklist; 100% hoàn thành là điều kiện đầu vào đánh giá hết thử việc |

**Thay đổi Level/vai (SCD2):** Manager đề xuất → HR_L2 thẩm định (chuẩn năng lực + KPI 2 chu kỳ liên tiếp) → BOD duyệt → CORE tạo version mới của mã vai/Level hiệu lực từ ngày hiệu lực và đóng version cũ. RBAC, hoa hồng, P&L, KPI **tự đọc version mới** — không module nào cập nhật tay; báo cáo quá khứ tái lập được bằng version cũ.

**Offboarding/thôi việc:**
1. HR_L1 tạo hồ sơ thôi việc (ngày hiệu lực + căn cứ pháp lý Điều 34/35/36 BLLĐ 2019) → HR_L2 duyệt.
2. Duyệt xong, hệ thống mở **checklist thu hồi**: (a) CORE vô hiệu hóa tài khoản ERP + toàn bộ quyền RBAC trong **24h**; (b) **handoff DEPT-OPS** — HR phát yêu cầu thu hồi TKQC trong **24h** qua hệ thống, OPS thực thi trên TKQC Registry + nền tảng Ads và xác nhận lại (HR quản SLA và theo dõi trạng thái, OPS thực thi — ranh giới rõ); (c) chốt phép chưa dùng, công/timesheet chưa duyệt, bàn giao tài liệu–tài sản; (d) dữ liệu chuyển chế độ retention theo REQ-HR-010.
3. Trạng thái hồ sơ = "Nghỉ việc" — lưu theo retention luật định, không xóa cứng.

**Rules:** freelancer ngoài biên chế không tạo hồ sơ (tính chi phí dịch vụ); nghỉ không lương >30 ngày → đóng băng allocation/capacity, KPI prorate/miễn theo xác nhận HR_L2.
**Hệ thống & UI:** CORE = master + SCD2 + validation + provisioning; WEB = form, **timeline version trực quan**, checklist, hàng đợi duyệt; trường C1 hiển thị masked cho mọi vai không có quyền.

### B2. REQ-HR-002 — HĐLĐ & cảnh báo hết hạn 90/60/30

Workflow: (1) HR_L1 nhập HĐLĐ (loại, số, ngày ký, hiệu lực, hết hạn) + upload file scan → CORE mã hóa, gắn hồ sơ NV. (2) Job CORE quét hằng ngày: trước hết hạn **90/60/30 ngày** → thông báo WEB cho HR_L2 + TL (90: quyết định ký tiếp hay không; 60: chuẩn bị; 30: phải chốt phương án). (3) HĐ xác định thời hạn quá hạn chưa tái ký → **cảnh báo đỏ** trên dashboard HR_L2 + escalate BOD theo tuần đến khi xử lý. (4) Tái ký: tạo bản ghi HĐ mới nối tiếp; HĐ cũ giữ nguyên lịch sử. (5) Chấm dứt giữa hạn: ghi căn cứ pháp lý + file quyết định, đóng trạng thái.

Rules: HĐ không xác định thời hạn → tắt nhắc (flag); đánh giá hết thử việc trước khi kết thúc ≥3 ngày, đạt mới ký HĐ chính thức; nội dung file scan chỉ HR_L2 mở được (C1); lưu theo retention pháp luật lao động.

### B3. REQ-HR-003 — Chấm công & overtime

Workflow: (1) NV ghi công hằng ngày trên WEB (giờ linh hoạt được phép); (2) CORE cộng dồn tuần và so định mức giờ/tuần theo Level (chuẩn 40h T2–T6; tuần có ngày lễ giảm định mức tương ứng) — thiếu giờ → nhắc NV + TL; (3) điều chỉnh công: NV đề nghị qua ESS → **người khác duyệt** (TL ≠ người đề nghị) + audit log giá trị trước/sau; (4) OT: duyệt trước khi làm → TL duyệt trong trần 8h OT/tuần; sự cố khẩn cấp retro trong **24h** kèm lý do; OT vượt trần tuần hoặc trần năm **200h** → chỉ **HR_L2** duyệt (24h); (5) CORE **chặn cứng** khi giờ chuẩn + OT > **48h/tuần** (Điều 107 BLLĐ 2019) — validation chạy kép: WEB chặn realtime khi nhập, CORE chặn lại khi duyệt; (6) chốt tháng: CORE tổng hợp công + OT đã duyệt → bàn giao **payroll/BHXH (handoff DEPT-FINANCE)** — FIN nhận số tổng hợp có log, không nhận bảng công thô.

### B4. REQ-HR-004 — Nghỉ phép: số dư & duyệt phân cấp

Workflow: (1) NV lập đơn trên WEB, hệ thống hiển thị **số dư hiện hành** (tích lũy tự động 12 ngày/năm, 1 ngày/tháng); nghỉ kế hoạch trước ≥3 ngày làm việc. (2) CORE validate: vượt số dư → **chặn duyệt** (chặn ở tầng validation, UI không có nút duyệt). (3) Route phân cấp tự động: **≤5 ngày → TL duyệt 24h; >5 ngày hoặc nghỉ không lương → HR_L2 duyệt 48h**; quá SLA → nhắc; tiếp tục quá → escalate cấp trên (TL → Manager; HR_L2 → BOD). (4) Duyệt xong: tự trừ số dư + **tự giảm capacity tuần** (luồng REQ-HR-009 — DEPT-OPS thấy capacity khả dụng giảm tự động, không thông báo tay). (5) Nghỉ ốm ≥3 ngày: đính kèm giấy khám; nghỉ đột xuất: retro có lý do; thai sản/ốm dài: prorate/miễn KPI theo xác nhận HR_L2.

Rule chưa chốt: phép năm chưa dùng có cộng dồn sang năm sau không — đề xuất theo Điều 113 BLLĐ 2019 (cộng dồn tối đa 3 tháng, thỏa thuận được dài hơn) `[CẦN CHỐT SỐ]`.

### B5. REQ-HR-005 — Self-service (ESS)

Workflow: đăng nhập WEB (SSO realm nội bộ) → trang "Của tôi": hồ sơ của mình (trường C1 chỉ hiện masked), đơn nghỉ, đề nghị điều chỉnh công, timesheet của mình, KPI + **dữ liệu gốc KPI của mình**, thông báo (nhắc chốt timesheet trước 12:00 T2, hạn duyệt, kỳ KPI). Thay đổi trường nhạy cảm (TK ngân hàng, người liên hệ khẩn, thông tin ảnh hưởng payroll): tạo yêu cầu → **HR_L2 duyệt 24h** → mới hiệu lực; trước đó payroll dùng giá trị cũ. Rules: mỗi người chỉ thấy dữ liệu mình — enforce **row-level ở CORE**, không chỉ ẩn UI; mọi thao tác ESS có audit log. SYS-MOBILE-INTERNAL: giữ ghi chú Phần A — ngoài scope mobile hiện tại.

### B6. REQ-HR-006 — Cost Rate Card version hóa (HR_L2 lập → FIN_L2 thẩm định → BOD duyệt)

Workflow duyệt (3 chặn): (1) **HR_L2 soạn** dự thảo (cost/hour theo Level, hiệu lực từ ngày–đến ngày) trên WEB → submit; (2) **FIN_L2 thẩm định** — WEB hiển thị bảng đối chiếu rate đề xuất vs payroll thực tế theo Level; lệch quá ngưỡng cho phép → trả về kèm lý do (đề xuất ngưỡng ±10% `[CẦN CHỐT SỐ]`); (3) **BOD duyệt** → CORE **phát hành version mới** (số version tự tăng, người duyệt, timestamp). Version đã phát hành **bất biến**: sai sót xử lý bằng version mới hiệu lực từ ngày khác, version cũ đóng lại và giữ history.

Rule tiêu thụ: P&L và báo cáo dự án **chọn version theo ngày ghi giờ** (không theo ngày chốt P&L); nếu không có version phủ ngày ghi giờ → dùng version gần nhất trước đó + gắn **cờ dữ liệu** cho FIN kiểm tra. Thăng Level giữa năm: NV tự áp rate Level mới từ ngày hiệu lực (kế thừa SCD2 hồ sơ — không nhập tay từng người). Migration mở sổ: import từ Google Sheets/payroll thực tế → version đầu tiên do BOD xác nhận phát hành; duyệt lại chu kỳ năm. Giá trị cost/hour từng Level `[CẦN CHỐT SỐ]`.

**Permission (Restricted):** chỉ HR_L2 + BOD xem cost/hour cá nhân; FIN_L2 có quyền đọc trong giai đoạn thẩm định (ghi log); manager chỉ xem **tổng cost nhóm mình**.

### B7. REQ-HR-007 — KPI 3 trụ cột: công thức, review quý, calibration

Công thức: `KPI kỳ = On-time×w1 + Output Volume×w2 + SLA/Target×w3 + Chấm tay×15%` — w1–w3 theo **Level hiện hành tại thời điểm đóng kỳ** (đọc SCD2 hồ sơ: L1 20/50/15 → L5 20/10/55); đổi trọng số: HR_L2 đề xuất → BOD duyệt, hiệu lực đầu năm tài chính.

Luồng review quý:
1. CORE tự tổng hợp khi **đóng kỳ** (khóa dữ liệu kỳ) — **cấm nhập điểm tay 3 trụ cột** (validation cứng; WEB không có ô nhập).
2. Công bố: NV xem trước điểm + 100% dữ liệu gốc (task, deliverable, SLA) trên ESS; thắc mắc trong **3 ngày làm việc** → CORE đối chiếu lại dữ liệu gốc và phản hồi.
3. TL/Manager phỏng vấn review trên WEB (ghi nhận xét).
4. **Calibration HR_L2** trước khi trình BOD: so sánh chéo team, xử lý outlier, chuẩn hóa thang chấm tay; bắt buộc với L4–L5 và top/bottom; biên bản (người dự, quyết định, lý do) lưu CORE; mọi điều chỉnh sau calibration qua audit log.
5. Chốt: L1–L3 Manager chốt sau calibration trong 10 ngày làm việc; L4–L5 + trường hợp biên → BOD chốt trong 15 ngày làm việc.

Rules: thành phần chấm tay phải khai báo trọng số + rubric trước kỳ; mỗi điểm có người chấm, ngày, nhận xét. Quá tải: Utilization >100% ≥2 tuần → gắn cờ tự động, **miễn phạt điểm On-time** cho trễ do quá tải; TL giải trình + tái cân bằng trong 5 ngày làm việc; ≥3 cờ/quý → HR_L2 xem headcount. Ngoại lệ: mới <30 ngày (định tính); nghỉ dài ≥1 tháng (prorate/miễn); dự án khẩn BOD duyệt loại trừ (trước hoặc trong 24h); thử việc chỉ Output + tuân thủ 70/30, không PIP.

### B8. REQ-HR-008 — PIP 30-60-90

Workflow: (1) CORE **gợi ý** mở PIP khi: điểm quý <60/100; 2 quý liên tiếp dưới kỳ vọng; vi phạm SLA nghiêm trọng đã xác nhận — chỉ gợi ý, không tự mở. (2) Manager đề xuất → **HR_L2 duyệt trong 5 ngày làm việc** sau công bố KPI → lập kế hoạch: mục tiêu, milestone 30/60/90, lịch coaching ≥2 tuần/lần (mỗi buổi coaching ghi nhận trên WEB). (3) Mốc 30: nhận diện vấn đề + hướng dẫn cụ thể; mốc 60: đo tiến bộ, coaching tăng cường; mốc 90: HR_L2 xác nhận dữ liệu → đạt: thoát PIP; không đạt: **BOD quyết định** điều chuyển, hạ Level hoặc chấm dứt HĐLĐ đúng pháp luật. (4) Nghỉ dài giữa PIP: tạm dừng, tính lại mốc khi quay lại; thử việc không áp PIP. Hồ sơ PIP **Restricted**: chỉ Manager trực tiếp + HR_L2 + BOD truy cập.

### B9. REQ-HR-009 — Duyệt timesheet & capacity (ranh giới DEPT-OPS)

**Ranh giới sở hữu:** DEPT-OPS sở hữu **ghi timesheet hằng ngày + gán capacity** (REQ của OPS); DEPT-HR sở hữu **quy tắc duyệt, định mức, escalation, chính sách OT**. HR không sửa nội dung giờ đã ghi — chỉ can thiệp tầng quy tắc.

Workflow chốt–duyệt: (1) NV chốt tuần trước **12:00 thứ Hai** (giờ do OPS ghi hằng ngày); (2) hệ thống tạo hàng đợi cho TL — **TL duyệt trong 48h; cấm tự duyệt** (approver ≠ người ghi — validation CORE, áp cả TL; timesheet của TL do **Manager L4** duyệt); (3) giờ duyệt xong được đánh dấu `approved` — **chỉ giờ approved được nhân Cost Rate Card để allocate chi phí P&L** (gate CORE; giờ chờ duyệt hiển thị trạng thái riêng trên WEB, không bao giờ lẫn vào báo cáo cost); (4) quá 48h: nhắc TL; quá 72h: escalate Manager; (5) correction giờ đã ghi: qua **TL xác nhận + audit log** (24h), giữ bản gốc; (6) OT vượt trần tuần/retro: **HR_L2 duyệt 24h** (nối B3); (7) escalation capacity check: quá SLA 4h → TL; quá **8h → HR_L2 cân đối đầu người** (mở requisition REQ-HR-001 nếu thiếu người); (8) định mức giờ/tuần + tỷ lệ billable mục tiêu theo bậc: HR_L2 đề xuất → **BOD duyệt chu kỳ năm**.

**Handoff qua dept khác:** ghi giờ/gán việc = DEPT-OPS; giờ approved → P&L của DEPT-FINANCE; dữ liệu task/deadline cho trụ cột KPI 1–2 là **đọc từ hệ thống OPS** (HR không ghi).

### B10. REQ-HR-010 — PII: phân loại, ma trận quyền, retention

Phân loại: **C1** (CCCD, lương, TK ngân hàng, dữ liệu y tế) — mã hóa khi lưu + truyền, cấm xuất raw; C2 định danh thường; C3 công việc.

**Ma trận quyền xem lương/cost (Restricted):**

| Vai | Lương cá nhân | Cost/hour cá nhân | Tổng cost nhóm | Log PII |
|-----|---------------|-------------------|----------------|---------|
| HR_L2 | Xem + sửa | Xem | Xem | Xem |
| HR_L1 | Không xem, không sửa | Không | Xem | Xem |
| BOD (CEO/CFO) | Xem | Xem | Xem | Xem |
| FIN_L2 | Xem khi thẩm định rate (log) | Xem khi thẩm định (log) | Xem | Xem |
| Manager/TL | Không | Không | Chỉ nhóm mình | Không |
| SYS_ADMIN | Không (quản hạ tầng, không xem giá trị) | Không | Không | Xem — xem log cũng bị log |

Rules: mọi lượt xem/sửa lương, HĐLĐ, dữ liệu C1 có audit log bất biến (ai — khi nào — giá trị trước/sau); review ma trận truy cập C1 **theo quý** (HR_L2 + SYS_ADMIN); offboard thu hồi quyền 24h (B1.3); retention: hồ sơ nhân sự theo pháp luật lao động, lương/chứng từ kế toán **10 năm** (Luật Kế toán 2015), hồ sơ ứng tuyển không trúng **12 tháng**; hết hạn → xóa/ẩn danh có log hủy có phê duyệt (nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa); breach: báo legal trong 4 giờ, thông báo A06 trong **72h** (NĐ 13/2023); xuất dữ liệu thuế/BHXH theo mẫu chuẩn, mỗi lần xuất có log.

### B11. Ma Trận Business-Rules × System

| # | Business Rule | SYS-CORE-BACKEND | SYS-BCERP-WEB | Ghi chú |
|---|---------------|------------------|---------------|---------|
| 1 | SCD2 version hóa Level/vai/trạng thái/cost | Lưu version, đóng version cũ | Timeline version, form hiệu lực từ ngày | Nguồn cho RBAC/hoa hồng/P&L/KPI (REQ-HR-001/006) |
| 2 | 1 người 1 hồ sơ, được nhiều vai | Validation duy nhất | Form cảnh báo trùng | REQ-HR-001 |
| 3 | Provisioning/thu hồi RBAC theo mã vai; offboard 24h | Phát lệnh tự động | Hiển thị trạng thái lệnh | Thu hồi TKQC do OPS thực thi (REQ-HR-001) |
| 4 | Thu hồi TKQC 24h phối hợp OPS | Phát yêu cầu + đo SLA | Handoff queue, OPS xác nhận | Ranh giới HR–OPS (REQ-HR-001) |
| 5 | HĐLĐ nhắc 90/60/30; quá hạn → cảnh báo đỏ | Job quét hằng ngày | Thông báo + dashboard đỏ | REQ-HR-002 |
| 6 | Chặn OT >48h/tuần, trần 200h/năm | Validation cứng khi duyệt | Chặn realtime khi nhập | Điều 107 BLLĐ 2019 (REQ-HR-003) |
| 7 | Chặn duyệt phép vượt số dư; route ≤5/>5 ngày | Validation + routing | Form đơn + hàng đợi duyệt | REQ-HR-004 |
| 8 | ESS chỉ thấy dữ liệu mình; thay đổi nhạy cảm HR_L2 duyệt 24h | Row-level + workflow | Trang "Của tôi" | REQ-HR-005 |
| 9 | Rate Card bất biến sau phát hành; P&L chọn version theo ngày ghi giờ | Version store + lookup theo ngày ghi giờ | Soạn thảo, đối chiếu FIN, trình BOD | REQ-HR-006 |
| 10 | Cấm nhập điểm tay 3 trụ cột KPI | Validation cứng | Không hiển thị ô nhập | REQ-HR-007 |
| 11 | Calibration bắt buộc + biên bản + audit điều chỉnh | Lưu biên bản, khóa dữ liệu kỳ | Workflow calibration | REQ-HR-007 |
| 12 | Cấm tự duyệt timesheet (approver ≠ người ghi) | Validation cứng | Hàng đợi duyệt | TL do Manager L4 duyệt (REQ-HR-009) |
| 13 | Giờ chưa duyệt không vào P&L | Gate trước module P&L | Hiển thị trạng thái chờ/đã duyệt | Đầu vào DEPT-FINANCE (REQ-HR-009) |
| 14 | Escalation capacity 4h → TL, 8h → HR_L2; OT retro HR_L2 24h | Job đo SLA | Thông báo escalate | Phối hợp DEPT-OPS (REQ-HR-009) |
| 15 | C1 mã hóa; chỉ HR_L2+BOD xem lương/cost; audit log bất biến; review truy cập quý | Mã hóa, RBAC tier Restricted, WORM log | UI masked + báo cáo review | NĐ 13/2023 (REQ-HR-010) |
| 16 | Retention 10 năm lương/chứng từ; 12 tháng hồ sơ ứng tuyển; xóa/ẩn danh có log | Retention timer + log hủy có phê duyệt | Báo cáo dữ liệu đến hạn | Luật Kế toán 2015 (REQ-HR-010) |

**Kết luận Phần B:** 10 REQ đã có workflow + business rules khả thi trên đúng 2 hệ thống chính (SYS-CORE-BACKEND + SYS-BCERP-WEB), thống nhất với 4 policy Phase 0 (`nhan-su-hanh-chinh-cost-rate-card.md`, `timesheet-capacity.md`, `kpi-hieu-suat.md`, `bao-ve-du-lieu-ca-nhan.md`). Các điểm chờ chốt số: giá trị cost/hour từng Level; ngưỡng lệch rate–payroll cho phép (đề xuất ±10%); quy tắc cộng dồn phép năm (đề xuất tối đa 3 tháng theo Điều 113 BLLĐ 2019).
