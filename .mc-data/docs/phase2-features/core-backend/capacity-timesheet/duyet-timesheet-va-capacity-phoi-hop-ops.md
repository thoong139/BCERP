# Tính Năng: Duyệt Timesheet & Capacity (Phối Hợp OPS)

> **Dựa trên:** REQ-HR-009 trong `phase1-business/departments/hr/hr.md` (Phần A3, Phần B.9 — ranh giới DEPT-OPS); phối hợp REQ-OPS-007 trong `phase1-business/departments/operations/operations.md` (Phần B.8 — OPS ghi nhận và duyệt lần 1)
> **Phân hệ:** Nhân sự — Quản lý timesheet, capacity và quy tắc duyệt (SYS-CORE-BACKEND)
> **Module:** Capacity & Timesheet (MOD-CAPACITY-TIMESHEET)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 4, Luồng 9), `policies/timesheet-capacity.md` §2.1–2.6, `documents/03_Quy_che_KPI_HR.md` (§8 nội quy, §9 đề xuất entity TMS)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/capacity-timesheet/[screen-group].md`, `phase5-implementation/tasks/core-backend/capacity-timesheet/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-HR-009 fan-out ra 2 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-CAPTS-001); counterpart: SYS-BCERP-WEB (màn hàng đợi duyệt, chốt tuần, dashboard trạng thái). Cross-dependency: REQ-OPS-007 — timesheet do HR định chính sách + duyệt, OPS ghi nhận (bản OPS của REQ-OPS-007 trên chính hệ thống này là FEAT-CORE-CAPTS-002). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CAPTS-001 |
| Module | MOD-CAPACITY-TIMESHEET (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-HR-009 (Duyệt timesheet & capacity — phối hợp OPS); cross-dependency REQ-OPS-007 (Capacity & Timesheet — OPS ghi nhận) |
| Người dùng liên quan | HR_L1, HR_L2 (nguồn sự thật quy tắc duyệt/định mức/escalation); OPS_PLAN (TL — duyệt lần 1 48h); OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (người ghi, chốt tuần); FIN_L1, FIN_L2 (nhận giờ đã duyệt cho P&L); BOD_CEO, BOD_CFO_CTO (duyệt định mức năm); SYS_ADMIN (không có quyền nghiệp vụ) |
| Độ ưu tiên | Cao (HIGH · Phase 2 · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Hồ sơ nhân sự + vai/Level (REQ-HR-001); Cost Rate Card version hóa (REQ-HR-006); đơn nghỉ đã duyệt (REQ-HR-004); dữ liệu ghi timesheet từ FEAT-CORE-CAPTS-002 (REQ-OPS-007) |
| Ghi chú Expert (A7) | `hr.md` A7.2 điểm 2: định mức giờ/tuần + tỷ lệ billable theo bậc — có khung policy, chờ BOD duyệt chu kỳ năm (giá trị hiện dùng là mức mặc định đã chốt theo DI-001). A7.2 điểm 3: need mobile HR duyệt phép/timesheet — ngoài scope SYS-MOBILE-INTERNAL hiện tại. A7.3 chưa có điều chỉnh (chờ Team Expert review) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Feature này hiện thực hóa **quy tắc duyệt timesheet và capacity góc HR** dưới dạng domain service trên core backend: chốt tuần, hàng đợi duyệt phân cấp, cấm tự duyệt, escalation SLA, gate "giờ chưa duyệt không vào P&L", duyệt OT vượt trần và vòng đời định mức giờ/billable mục tiêu theo bậc. Nguyên tắc sở hữu được enforce trong code: **HR là nguồn sự thật của quy tắc duyệt, định mức và escalation; OPS ghi nhận giờ và duyệt lần 1 theo đúng quy tắc HR đặt** — HR không bao giờ sửa nội dung giờ đã ghi, chỉ can thiệp ở tầng quy tắc.

**Phạm vi:**
- Bao gồm: state machine chốt tuần–duyệt (chốt trước 12:00 thứ Hai; TL duyệt 48h; quá 72h escalate Manager); validation cấm tự duyệt (approver ≠ người ghi, áp cả TL); gate "giờ chưa duyệt không vào P&L" (chỉ giờ `approved` nhân Cost Rate Card REQ-HR-006); correction giữ bản gốc + audit log (TL xác nhận 24h); duyệt OT vượt trần tuần/retro bởi HR_L2 24h; escalation capacity check (4h → TL, 8h → HR_L2); vòng đời chính sách định mức + billable mục tiêu (HR_L2 đề xuất → BOD duyệt, effective-dated); tự trừ capacity khi nghỉ được duyệt (nối REQ-HR-004).
- Không bao gồm: giao diện ghi timesheet, nhãn billable tại nguồn và capacity engine chặn gán (FEAT-CORE-CAPTS-002 — REQ-OPS-007); màn hình duyệt/chốt tuần (SYS-BCERP-WEB — counterpart); tính lương OT theo hệ số pháp luật (REQ-HR-003); allocate chi phí P&L chi tiết (DEPT-FINANCE tiêu thụ đầu ra); chấm công vân tay vật lý (chỉ đối chiếu dữ liệu).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản spec này là **core backend headless**: các actor thao tác qua WEB nội bộ hoặc M-INT, nhưng mọi điều kiện nghiệp vụ đều được service layer xác thực lại tại tầng API — client không bao giờ là nguồn quyết định duyệt/từ chối. Các user story phản ánh đúng ranh giới HR (quy tắc) — OPS (ghi nhận) đã chốt ở B9 `hr.md`.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN (TL) | Gọi API lấy hàng đợi timesheet tuần của nhóm, sắp theo SLA 48h và tự nhắc/escalate khi quá hạn | Không tỳ duyệt — giờ vào P&L đúng kỳ, trách nhiệm duyệt đo được |
| 2 | OPS staff (AM/CONT/DES/EDIT/ADS) | Chốt tuần trước 12:00 thứ Hai qua service từ WEB hoặc mobile chấm công (M-INT), tra được trạng thái duyệt từng tuần | Giờ được duyệt kịp, minh bạch thay vì hỏi miệng |
| 3 | HR_L2 | Duyệt OT vượt trần/retro trong 24h trên service có audit log | Mọi OT ngoài trần 8h/tuần qua một cửa duyệt duy nhất, có dấu vết pháp lý |
| 4 | HR_L2 | Đề xuất điều chỉnh định mức giờ/tuần + billable mục tiêu theo bậc (effective-dated) trình BOD duyệt | Chính sách có hiệu lực theo ngày, OPS chỉ dùng cấu hình không tự thay |
| 5 | FIN_L1 / FIN_L2 | Chỉ nhận dòng "giờ đã duyệt × Cost Rate Card" từ gate của core backend | P&L không bao giờ chứa giờ chưa duyệt — chứng minh được cho auditor |
| 6 | HR_L1 | Xem tình trạng chốt/duyệt toàn công ty (tỷ lệ chốt đúng hạn, hàng đợi tồn, escalation đang mở) qua API báo cáo | Phối hợp OPS xử lý tồn đọng trước khi ảnh hưởng P&L và KPI |
| 7 | SYS_ADMIN | Tra audit log bất biến (append-only, hash-chain) của mọi event duyệt/correction/escalation | Kiểm chứng kiểm soát mà không có quyền sửa nghiệp vụ hay xóa log |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Tất cả rule enforce tại tầng service/workflow engine của core backend: validation cứng trên mọi đường vào (API, job, script), không nhận quyết định trạng thái từ client, audit log append-only + hash-chain, tenant isolation trên mọi endpoint.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Cấm tự duyệt timesheet:** approver bắt buộc khác người ghi — validation cứng tầng service, áp cả TL; timesheet của TL (OPS_PLAN) do Manager L4 duyệt. Người duyệt timesheet cấp TL/OPS_PLAN: OPS không có L4 chuyên trách — `[CẦN CHỐT SỐ: người duyệt timesheet cấp TL/OPS_PLAN]` (SO3-09 nhóm D / DI-006). Nguồn: `hr.md` B9, BR-HR số 12; `operations.md` BR-OPS-8.2. | API từ chối "CAM_TU_DUYET"; lần thử ghi audit log bảo mật |
| BR-002 | **Delegate duyệt của TL [KXN] chưa chốt — không tự quyết:** ủy quyền duyệt timesheet cho TL cụ thể vẫn chờ stakeholder xác nhận (DI-006). Mặc định **không mở chức năng delegate**; TL vắng chỉ chuyển theo escalation Manager (BR-003), người nhận escalate vẫn ≠ người ghi. | Endpoint delegate không tồn tại; yêu cầu ủy quyền tay bị từ chối + log |
| BR-003 | **SLA chốt–duyệt–escalate:** chốt tuần trước 12:00 thứ Hai; TL duyệt 48h kể từ chốt; quá 48h nhắc TL (job đo SLA); quá 72h escalate Manager. Nguồn: `hr.md` B9 (1)(2)(4). | Tự nhắc/escalate + ghi báo cáo SLA duyệt của TL/Manager |
| BR-004 | **Giờ chưa duyệt không vào P&L:** gate cứng trước module P&L — chỉ giờ `approved` được nhân Cost Rate Card (REQ-HR-006, lookup theo ngày ghi giờ) để allocate chi phí; giờ chờ hiển thị trạng thái riêng, không lẫn vào báo cáo cost. Nguồn: `hr.md` B9 (3), BR-HR số 13, P1-02 Luồng 9. | Allocate trên giờ chưa duyệt bị chặn "GIO_CHUA_DUYET" |
| BR-005 | **Phối hợp HR/OPS — nguồn sự thật quy tắc là HR:** quy tắc duyệt, định mức, escalation, chính sách OT do HR sở hữu; OPS ghi nhận hằng ngày + duyệt lần 1 theo đúng quy tắc. HR không có endpoint sửa nội dung giờ đã ghi — chỉ can thiệp tầng quy tắc/cấu hình. Nguồn: `hr.md` B9 ranh giới sở hữu; REQ-OPS-007. | API sửa giờ từ vai HR bị từ chối "VUOT_RANH_GIOI" + log |
| BR-006 | **Correction có kiểm soát:** giờ đã ghi không sửa đè — correction tạo bản ghi mới, bản gốc bất biến; TL xác nhận 24h; audit log bắt buộc (ai, khi nào, sửa gì, lý do); giờ sau correction đi lại gate duyệt (BR-004) trước khi tính cost. Nguồn: `hr.md` B9 (5); BR-OPS-8.1. | Correction thiếu lý do/xác nhận không có hiệu lực; nhãn sau correction không vượt validation cặp project type × nhãn |
| BR-007 | **OT theo trần pháp luật:** OT duyệt trước, trần 8h OT/tuần do TL duyệt; vượt trần tuần/retro (sự cố khẩn cấp) do **HR_L2 duyệt 24h**; tổng chuẩn + OT chặn cứng >48h/tuần (Điều 107 BLLĐ 2019); trần năm 200h. Nguồn: `hr.md` B9 (6), B3, BR-HR số 6; `timesheet-capacity.md` §2.5. | Duyệt vượt trần không qua HR_L2 → từ chối "OT_VUOT_TRAN"; tổng >48h → chặn ghi nhận |
| BR-008 | **Escalation capacity check:** SLA xác nhận 4h — quá 4h escalate TL; quá 8h escalate **HR_L2 cân đối đầu người** (kích hoạt đề xuất requisition REQ-HR-001 nếu thiếu người). Job đo SLA tự động, phát event cho WEB/M-INT. Nguồn: `hr.md` B9 (7), BR-HR số 14, P1-02 B3. | Quá SLA tự escalate + log; không có "reset SLA tay" |
| BR-009 | **Định mức + billable mục tiêu là chính sách HR, effective-dated:** điều chỉnh do **HR_L2 đề xuất → BOD duyệt (chu kỳ năm)**, lưu version hiệu lực theo ngày; OPS chỉ tiêu thụ. Giá trị mặc định hiện hành theo policy đã chốt (DI-001): 40h chuẩn/tuần, trần ghi 48h gồm OT, billable mục tiêu L1 ≥80%, L2 ≥75%, L3 60–70%, L4 40–50%, L5 20–30%. Nguồn: `hr.md` B9 (8); `timesheet-capacity.md` §2.1, §4. | Thay đổi không qua chu kỳ đề xuất→BOD bị từ chối; lookup luôn theo version hiệu lực tại ngày ghi giờ |
| BR-010 | **Nghỉ đã duyệt tự trừ capacity tuần:** đơn nghỉ được duyệt (REQ-HR-004 — chặn duyệt vượt số dư; ≤5 ngày TL duyệt, >5 ngày/không lương HR_L2) → service tự giảm capacity khả dụng tuần tương ứng, **không tính vào utilization**; OPS thấy giảm tự động, không thông báo tay. Nguồn: `hr.md` A3 luồng nghỉ phép (4); `timesheet-capacity.md` §3. | Tính utilization trên ngày nghỉ đã duyệt bị loại khỏi mẫu số; trừ tay không tồn tại |
| BR-011 | **Giờ làm việc/nghỉ phép nội quy theo `03_Quy_che_KPI_HR.md` §8:** sáng 08h30–12h00, trưa 12h00–13h00, chiều 13h00–17h30 (T7/CN/lễ không tính) — **giờ chuẩn lệch giữa Welcome Deck và JD, chờ xác nhận khi build `work_schedule` [KXN — nguồn 03 §9 điểm 2]**; quy định báo trước nghỉ (½ ngày/≥1 ngày/≥4 ngày theo độ dài; công tác 2 tiếng; duyệt quản lý trực tiếp + HCNS/HR_L1); chế tài muộn, quên chấm công, nghỉ không phép là dữ liệu chấm công đối chiếu timesheet. Nguồn: `03_Quy_che_KPI_HR.md` §8, §9. | Cấu hình `work_schedule` chỉ tham số hóa, không hardcode khi chưa chốt giờ chuẩn |
| BR-012 | **Mobile chấm công cho staff:** endpoint ghi/submit và tra trạng thái dùng chung cho SYS-MOBILE-INTERNAL (ghi nhanh cuối ngày, push nhắc); **duyệt timesheet của HR trên mobile chưa khai báo scope** (A7.2 `hr.md` điểm 3, P1-02 Luồng 4) — không tạo endpoint duyệt ngoài WEB cho đến khi chốt mở scope. | Gọi API duyệt từ kênh chưa khai báo → từ chối + audit log bảo mật |
| BR-013 | **Audit log bất biến + tenant isolation:** mọi event (chốt, duyệt, từ chối, correction, OT, escalation, đổi policy) ghi append-only + hash-chain (actor, timestamp, đối tượng, old→new, reason); không có interface xóa/sửa log ở mọi tầng kể cả SYS_ADMIN; mọi API scope cứng theo tenant + role re-check tại service layer. Nguồn: Notes lane touchpoint; BR-HR số 12–14. | Thiếu reason → không submit; đứt hash → alert BOD_CEO; vượt tenant → từ chối |

---

## 4. Phân Quyền

> Quyền enforce bằng vai tại tầng API core backend (role re-check mỗi request); bảng dưới là hợp đồng phân quyền service phải thực thi — counterpart WEB chỉ hiển thị theo kết quả tra quyền.

| Hành động | HR_L1 | HR_L2 | OPS_PLAN (TL) | OPS staff (AM/CONT/DES/EDIT/ADS) | FIN_L1 / FIN_L2 | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN |
|-----------|-------|-------|---------------|----------------------------------|-----------------|------------------------|-----------|
| Xem timesheet/trạng thái duyệt của mình | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem tình trạng chốt/duyệt toàn công ty | ✅ | ✅ | ✅ (phòng mình) | ❌ | ✅ (chỉ trạng thái) | ✅ | ❌ |
| Chốt tuần (submit) | ✅ (của mình) | ✅ (của mình) | ✅ | ✅ | ❌ | ⚠️ (L5/BOD ghi theo dự án) | ❌ |
| Duyệt timesheet lần 1 (48h) | ❌ | ❌ | ✅ (phòng mình) | ❌ | ❌ | ❌ | ❌ |
| Duyệt timesheet của TL (Manager L4) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (`[CẦN CHỐT SỐ]` người giữ vai — BR-001) |
| Xác nhận correction (24h) | ❌ | ❌ | ✅ (có lý do) | ❌ | ❌ | ❌ | ❌ |
| Duyệt OT vượt trần/retro (24h) | ❌ | ✅ (duy nhất) | ❌ (chỉ OT trong trần 8h) | ❌ | ❌ | ❌ | ❌ |
| Xử lý escalation capacity quá 8h | ❌ | ✅ (cân đối đầu người) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Đề xuất định mức giờ/billable theo bậc | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt định mức (version effective-dated) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (chu kỳ năm) | ❌ |
| Sửa nội dung giờ đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ qua correction BR-006) |
| Delegate quyền duyệt timesheet | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chức năng không mở — `[KXN]` BR-002) |
| Nhận giờ `approved` × Cost Rate Card cho P&L | ❌ | ❌ | ❌ | ❌ | ✅ (đọc gate) | ❌ | ❌ |
| Xem audit log duyệt/correction/escalation | ✅ | ✅ | ✅ (phòng mình — đọc) | ❌ | ✅ (đọc) | ✅ | ✅ (đọc — xem log cũng bị log) |
| Xóa/sửa audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |

> Ghi chú touchpoint: portal khách không có action nào trên luồng này; M-INT chỉ ghi/chốt và nhận thông báo cho staff — duyệt qua mobile cho HR chưa khai báo scope (BR-012). SYS_ADMIN quản hạ tầng, không xem/sửa giá trị lương-cost theo ma trận PII REQ-HR-010.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý — mọi xử lý qua service layer và ghi audit log, không có ngoại lệ "sửa tay trên DB".*

- **Timesheet của chính TL:** cấm tự duyệt áp cả TL — chuyển Manager L4; người giữ vai Manager L4 duyệt timesheet cấp TL/OPS_PLAN chưa chốt `[CẦN CHỐT SỐ — SO3-09 nhóm D]` nên phải cấu hình được theo vai mà không phá rule approver ≠ người ghi.
- **TL vắng mặt/nghỉ dài:** không dùng delegate (chưa chốt `[KXN]`) — escalate theo BR-003 (quá 72h → Manager); nếu vẫn không xử lý thì escalate tiếp HR_L2; toàn bộ chuỗi escalation có log truy trách nhiệm.
- **Giờ đã duyệt phát hiện sai sau khi vào P&L:** chỉ sửa bằng correction mới (BR-006) — cost cũ không xóa mà tạo bản đảo/điều chỉnh kỳ sau; FIN nhận dòng điều chỉnh có tham chiếu correction ID.
- **Nghỉ ốm dài/thai sản giữa tuần:** nghỉ đã duyệt tự trừ capacity (BR-010); nghỉ không lương/ốm dài có xác nhận HR_L2 → capacity tuần giảm và các gán đang mở phải qua lại capacity check, không tự dịch deadline ngầm.
- **OT khẩn cấp ngoài giờ (die account):** retro do HR_L2 duyệt 24h kèm lý do; nếu retro làm tổng tuần vượt 48h thì từ chối phần vượt — pháp luật không có ngoại lệ, chỉ xử lý nhanh hơn (ưu tiên duyệt, không bỏ gate).
- **Chốt trễ quá 12:00 thứ Hai:** vẫn nhận chốt muộn nhưng ghi trễ + tính báo cáo SLA cá nhân; chu kỳ duyệt 48h tính từ lúc chốt thực tế — không "hợp lệ hóa ngược" thời điểm chốt.
- **Sai lệch giờ làm việc chuẩn giữa 2 nguồn nội quy (§8 vs JD):** `work_schedule` giữ mặc định Welcome Deck + đánh dấu chờ xác nhận `[KXN]` — không hardcode, không tự chọn nguồn làm chuẩn.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Chu kỳ timesheet tuần của một nhân sự (`TimesheetWeek`) — dòng giờ kế thừa trạng thái chu kỳ chứa nó; correction là bản ghi con của chu kỳ đã `APPROVED`. OT là phễu duyệt song song gắn với chu kỳ.

**Sơ đồ trạng thái:**
```
[OPEN] ──(chốt tuần trước 12:00 T2)──► [SUBMITTED] ──(TL duyệt ≤48h)──► [APPROVED] ──(job P&L)──► [COST_ALLOCATED]
   │  ▲                                     │                              │
   │  │ (từ chối, lý do)                    │ (nhắc 48h; escalate 72h)     │ (correction: TL xác nhận ≤24h)
   │  └─────────────────────────────────────┘                              ▼
   │                                                  [CORRECTION_PENDING] ──► [CORRECTED] ──(duyệt lại)──► [APPROVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Chốt tuần | `SUBMITTED` | Người ghi | Trước 12:00 thứ Hai tuần kế; mọi dòng có nhãn hợp lệ; tổng ≤ 48h |
| `OPEN` | Sửa dòng giờ | `OPEN` | Người ghi | Chỉ khi tuần còn mở — sau chốt chỉ correction (BR-006) |
| `SUBMITTED` | Duyệt | `APPROVED` | TL phòng (timesheet TL → Manager L4) | Approver ≠ người ghi (BR-001); trong SLA 48h |
| `SUBMITTED` | Từ chối | `OPEN` | TL | Lý do bắt buộc; quá 48h nhắc, quá 72h escalate Manager (BR-003) |
| `APPROVED` | Tạo correction | `CORRECTION_PENDING` | Người ghi | Lý do bắt buộc; bản gốc giữ nguyên; TL xác nhận 24h (BR-006) |
| `CORRECTION_PENDING` | Xác nhận correction | `CORRECTED` → gate duyệt lại | TL | Audit log old→new; phải `APPROVED` lại mới tính cost |
| `APPROVED` | Allocate cost | `COST_ALLOCATED` | Hệ thống (job P&L) | Nhân Cost Rate Card theo ngày ghi giờ (REQ-HR-006) — gate BR-004 |

**Quy tắc:**
- Chỉ `APPROVED` được job P&L đọc — `OPEN`, `SUBMITTED`, `CORRECTION_PENDING` không bao giờ vào cost (BR-004).
- Dòng OT trong `SUBMITTED`: trong trần 8h do TL duyệt cùng lượt; vượt trần/retro phải có phê duyệt HR_L2 (24h) thì tuần mới được `APPROVED`.
- Không có trạng thái "duyệt khẩn bỏ qua gate" — mọi đường tắt bị loại khỏi thiết kế.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; entity đề xuất đối chiếu mô hình TMS tại `documents/03_Quy_che_KPI_HR.md` §9 (cần review trước khi vào schema chính thức).*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `TimesheetWeek` | `user_id`, `week_start`, `state` (`OPEN/SUBMITTED/APPROVED/CORRECTION_PENDING/COST_ALLOCATED`), `submitted_at`, `approved_by/at` | FK → `users` | Unique (`user_id`, `week_start`) |
| `TimesheetEntry` | `week_id`, `project_id`, `task_id`, `hours`, `billable_label`, `work_date` | FK → `timesheet_weeks`, `projects` | Nhãn bắt buộc tại nguồn; ghi nhận chi tiết thuộc FEAT-CORE-CAPTS-002 |
| `ApprovalTask` | `week_id`, `approver_id`, `due_at` (48h), `escalation_level` (TL→Manager), `state` | FK → `timesheet_weeks`, `users` | Hàng đợi duyệt; job SLA nhắc 48h / escalate 72h |
| `TimesheetCorrection` | `entry_id`, `old_values`, `new_values`, `reason`, `requested_by`, `confirmed_by/at` (TL) | FK → `timesheet_entries` | Bản gốc bất biến; chỉ tạo bản ghi mới |
| `OvertimeApproval` | `week_id`, `hours`, `type` (`TRONG_TRAN/VUOT_TRAN/RETRO`), `approved_by` (TL/HR_L2), `sla_due` (24h HR_L2), `reason` | FK → `timesheet_weeks` | Trần 8h/tuần, 48h tổng, 200h/năm |
| `CapacityPolicy` | `level`, `standard_hours` (40), `cap_hours` (48), `billable_target`, `effective_from/to`, `proposed_by` (HR_L2), `approved_by` (BOD) | FK → `career_levels` | Effective-dated; OPS chỉ đọc |
| `CapacityEscalation` | `assignment_id`, `opened_at`, `sla_4h_at`, `sla_8h_at`, `handled_by` (TL/HR_L2), `outcome` | FK → `assignments`, `users` | Job SLA tự sinh; 8h → HR_L2 cân đối đầu người |
| `AuditLog` | `actor_id`, `role`, `action`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only + hash-chain; không có interface xóa/sửa |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-HR-009 (`hr.md` A3/B.9, BR-HR số 12–14) và điểm phối hợp REQ-OPS-007 (`operations.md` B.8).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn tự duyệt — kể cả TL (REQ-HR-009) | Nhân sự A (hoặc TL) đã chốt tuần của mình | A/TL gọi API tự duyệt tuần | Từ chối "CAM_TU_DUYET"; ghi audit log; tuần vẫn `SUBMITTED` chờ approver khác người ghi | [ ] |
| SC-002: SLA nhắc và escalate (REQ-HR-009) | Tuần `SUBMITTED` quá hạn | Job SLA chạy | Nhắc TL tại 48h; quá 72h escalate Manager; toàn bộ có log + báo cáo SLA duyệt | [ ] |
| SC-003: Giờ chưa duyệt không vào P&L (REQ-HR-009) | Tuần đang `SUBMITTED` | Job allocate cost chạy kỳ P&L | Không dòng nào được nhân Cost Rate Card; mã chặn "GIO_CHUA_DUYET" cho mọi đường allocate | [ ] |
| SC-004: Correction giữ bản gốc (REQ-HR-009) | Tuần đã `APPROVED` | Người ghi tạo correction (số giờ + lý do) | Bản gốc bất biến; `CORRECTION_PENDING` chờ TL xác nhận 24h; phải `APPROVED` lại mới tính cost | [ ] |
| SC-005: OT vượt trần do HR_L2 duyệt 24h (REQ-HR-009) | Dòng OT 10h/tuần (vượt trần 8h) | TL duyệt lần 1 | Tuần không `APPROVED` nếu thiếu phê duyệt HR_L2 trong 24h; tổng >48h chặn cứng (Điều 107 BLLĐ 2019) | [ ] |
| SC-006: Nghỉ đã duyệt tự trừ capacity (REQ-HR-009 × REQ-HR-004) | Đơn nghỉ 2 ngày đã duyệt | Hệ thống tính utilization tuần | Capacity khả dụng tự giảm; ngày nghỉ không vào mẫu số; OPS thấy thay đổi không cần thông báo tay | [ ] |
| SC-007: Định mức effective-dated — HR đề xuất, BOD duyệt (REQ-HR-009) | `CapacityPolicy` phiên bản đang hiệu lực | OPS_PLAN gọi API sửa billable target | Từ chối "VUOT_RANH_GIOI"; chỉ HR_L2 tạo draft và BOD phê duyệt tạo phiên hiệu lực theo ngày | [ ] |
| SC-008: Escalation capacity 8h về HR_L2 (REQ-HR-009) | Capacity check mở quá 8h không xác nhận | Job SLA chạy | Escalate HR_L2 + gợi ý requisition (REQ-HR-001); lịch sử 4h→TL, 8h→HR_L2 có log | [ ] |
| SC-009: Tenant isolation + audit bất biến (Notes lane) | Tenant A | SYS_ADMIN truy vấn timesheet tenant B và thử sửa 1 dòng log | Cả hai bị từ chối; truy vấn sai tenant và ý định sửa log đều ghi audit log bảo mật | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (gate "giờ chưa duyệt không vào P&L" → P&L FIN; đồng bộ nghỉ REQ-HR-004 trừ capacity; event cho WEB/M-INT) |
| Màn hình UI (WEB — hàng đợi duyệt, chốt tuần, dashboard) | `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md` |
| Domain model nguồn | `documents/03_Quy_che_KPI_HR.md` (§8 giờ làm việc/nghỉ phép nội quy; §9 đề xuất entity TMS) |
| Policy nghiệp vụ | `policies/timesheet-capacity.md` §2.1–2.6, §4 (quy trình phê duyệt), §5 (yêu cầu hệ thống MUST) |
| Feature liên quan cùng module | `capacity-va-timesheet.md` (FEAT-CORE-CAPTS-002 — ghi nhận OPS + capacity engine trên cùng core backend) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 4 B2 ghi–duyệt; Luồng 9 giờ approved → chi phí dự án) |
