# Tính Năng: Chấm công & overtime

> **Dựa trên:** REQ-HR-003 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-003` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-003 xuất hiện ở 2 hệ thống — **SYS-BCERP-WEB** (primary: nhập công hằng ngày, đề nghị điều chỉnh) và **SYS-CORE-BACKEND** (bản spec này: rule engine cộng dồn tuần, trần overtime, validation kép khi duyệt, tổng hợp bàn giao payroll). Tại touchpoint core backend, mọi business rule phải được enforce ở tầng service (không tin UI); toàn bộ thay đổi công có audit log bất biến và dữ liệu luôn xử lý trong tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-003 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-003 |
| Người dùng liên quan | Toàn bộ nhân viên (18-vai registry — ghi công qua counterpart WEB), TL (duyệt điều chỉnh/OT trong trần), HR_L1 (xử lý), HR_L2 (duyệt OT vượt trần/retro), DEPT-FINANCE (nhận tổng hợp payroll/BHXH) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-HRCORE-001 (định mức giờ/tuần đọc theo Level từ hồ sơ SSOT) |
| Ghi chú Expert (A7) | A7.2: định mức giờ/tuần theo bậc có khung policy, chờ BOD duyệt chu kỳ năm; need mobile HR ngoài scope SYS-MOBILE-INTERNAL hiện tại. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp domain service ghi nhận và tổng hợp công theo ngày trên nền giờ chuẩn **40h/tuần (T2–T6)**, cho phép giờ linh hoạt nhưng kiểm soát đạt định mức giờ/tuần theo Level, đồng thời quản lý overtime (OT) với nguyên tắc **duyệt trước khi làm** và **trần cứng 48h/tuần gồm giờ chuẩn + OT** theo Điều 107 BLLĐ 2019 (trần 200h OT/năm). Dữ liệu công + OT đã duyệt là đầu vào duy nhất cho payroll/BHXH (handoff DEPT-FINANCE) và là nền đối chiếu với timesheet dự án ở Giai đoạn 2.

**Phạm vi:**
- Bao gồm: entity bản ghi công theo ngày; cộng dồn tuần và so định mức theo Level (tuần có ngày lễ giảm định mức tương ứng); luồng điều chỉnh công (người khác duyệt, bắt buộc audit log giá trị trước/sau); luồng đăng ký OT duyệt trước (TL duyệt trong trần 8h OT/tuần), OT retro khẩn cấp trong 24h kèm lý do, OT vượt trần tuần/năm chỉ HR_L2 duyệt trong 24h; validation kép (WEB chặn realtime khi nhập — CORE chặn lại khi duyệt); chốt tháng tổng hợp công + OT đã duyệt bàn giao payroll/BHXH có log; ánh xạ chế tài đi muộn/về sớm/quên chấm công theo nội quy nguồn 03 §8.
- Không bao gồm: màn hình nhập công hằng ngày và hàng đợi duyệt (SYS-BCERP-WEB — counterpart); quy tắc duyệt timesheet dự án & capacity (REQ-HR-009 — ranh giới DEPT-OPS, riêng biệt, không gộp); nghỉ phép và trừ số dư (FEAT-CORE-HRCORE-004); tính lương/thuế chi tiết (DEPT-FINANCE).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` — mục 8 (giờ làm việc sáng 08h30–12h00, chiều 13h00–17h30; chế tài đi muộn/về sớm theo mốc 20k–70k–½ ngày công, x2 từ lần thứ 4/tháng, cấp quản lý nhân đôi, intern Kinh doanh không áp; quên chấm vân tay 2 lần đầu/tháng có HCNS xác nhận thì vẫn tính công), mục 9 (entity `work_schedule`, `attendance_violation`), và ghi chú sai lệch giờ làm việc giữa Welcome Deck (08h30–17h30) với một số JD (08h00–17h30) — cần chủ dự án chốt giờ chuẩn khi cấu hình `work_schedule` `[KXN-giolamviec]` (assumption, không tự quyết).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên (mọi vai registry) | Ghi công theo ngày với giờ vào/ra linh hoạt | Giờ làm được ghi đúng thực tế, không bị ép khung cứng |
| 2 | Hệ thống (rule engine) | Cộng dồn giờ tuần từng nhân sự và so với định mức theo Level (chuẩn 40h T2–T6; tuần lễ giảm tương ứng) | Thiếu giờ được phát hiện sớm để nhắc nhân viên + TL |
| 3 | Nhân viên | Đề nghị điều chỉnh công (quên chấm, sai giờ) qua ESS | Sai sót được sửa bằng correction có người khác duyệt, không sửa đè |
| 4 | TL | Duyệt điều chỉnh công của thành viên (không tự duyệt đề nghị của chính mình) | Mọi thay đổi công có approval + audit log trước/sau |
| 5 | TL | Duyệt đăng ký OT trước khi làm, trong trần 8h OT/tuần | OT được lập kế hoạch, không phát sinh ngoài ý muốn |
| 6 | Nhân viên | Ghi nhận OT retro khẩn cấp trong 24h kèm lý do | Sự cố ngoài ý muốn vẫn được ghi nhận hợp lệ |
| 7 | HR_L2 | Duyệt OT vượt trần tuần hoặc trần năm 200h trong 24h | Ngoại lệ có thẩm quyền rõ, có căn cứ lưu hồ sơ |
| 8 | Hệ thống (validation) | Chặn cứng khi tổng giờ chuẩn + OT > 48h/tuần tại thời điểm duyệt | Tuân thủ Điều 107 BLLĐ 2019 ngay cả khi UI bị bỏ qua (gọi API trực tiếp) |
| 9 | DEPT-FINANCE (FIN_L1) | Nhận tổng hợp công + OT đã duyệt cuối tháng qua handoff có log | Payroll/BHXH chạy trên số tổng hợp chuẩn, không nhận bảng công thô |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR3-01 | Giờ chuẩn **40h/tuần (T2–T6)**; giờ linh hoạt được phép nhưng tổng tuần phải đạt định mức giờ/tuần theo Level (định mức đọc từ hồ sơ SSOT; tuần có ngày lễ giảm định mức tương ứng) | Thiếu giờ → sinh nhắc cho nhân viên + TL; không tự tính trừ lương |
| BR-HR3-02 | OT phải **duyệt trước khi làm**; TL duyệt trong trần **8h OT/tuần**; OT khẩn cấp retro ghi nhận trong **24h** kèm lý do bắt buộc | OT không có duyệt trước và không rơi vào retro 24h → không được tính |
| BR-HR3-03 | OT vượt trần tuần 8h hoặc tiến tới trần năm **200h** → chỉ **HR_L2** duyệt, SLA 24h | TL không được duyệt vượt trần; API từ chối approval sai thẩm quyền |
| BR-HR3-04 | **Chặn cứng khi giờ chuẩn + OT > 48h/tuần** (Điều 107 BLLĐ 2019) — validation chạy kép: counterpart WEB chặn realtime khi nhập, CORE chặn lại khi duyệt | Gọi API trực tiếp vẫn bị chặn ở service layer; không có cơ chế bypass |
| BR-HR3-05 | Điều chỉnh công phải do **người khác** duyệt (approver ≠ người đề nghị) + audit log giá trị trước/sau; giữ bản gốc | Tự duyệt bị từ chối; sửa đè bản ghi gốc bị cấm — chỉ thêm bản ghi correction |
| BR-HR3-06 | Quên chấm công: xử lý bằng luồng điều chỉnh có duyệt (nối BR-HR3-05); theo nội quy 03 §8, quên chấm vân tay 2 lần đầu/tháng có HCNS xác nhận đến/về đúng giờ thì không áp chế tài và vẫn tính công | Từ lần thứ 3 trở đi áp rule nội quy (không tính công buổi/ngày đó) — cấu hình trong `attendance_violation` |
| BR-HR3-07 | Chế tài đi muộn/về sớm theo mốc nguồn 03 §8 (≤5 phút 0đ; 6–10 phút 20.000đ; 11–30 phút 30.000đ; 31–45 phút 50.000đ; 46–60 phút 70.000đ; ≥61 phút ½ ngày công; lần thứ 4/tháng x2; cấp quản lý x2 mọi mức; intern Kinh doanh không áp) | Cấu hình dạng bảng tra cứu theo `career_level`/nhóm đối tượng — không hardcode; vi phạm ghi vào `attendance_violation` để tổng hợp |
| BR-HR3-08 | Làm việc đa múi giờ với khách: mọi giờ công ghi theo **giờ làm việc Việt Nam** | Giờ ghi theo mốc khác bị chuẩn hóa + log lệch múi giờ |
| BR-HR3-09 | Chốt tháng: tổng hợp công + OT **đã duyệt** → bàn giao payroll/BHXH (handoff DEPT-FINANCE) có log; FIN nhận số tổng hợp, không nhận bảng công thô; correction sau chốt tháng xử lý bằng điều chỉnh kỳ sau có log | Số chưa duyệt không được lọt vào file handoff |
| BR-HR3-10 | Tổng hợp công + OT phục vụ đối chiếu timesheet dự án ở Giai đoạn 2 (REQ-HR-009/REQ-OPS) — chỉ đọc, không ghi chéo | Không module nào ghi đè dữ liệu chấm công từ luồng timesheet |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn 90/60/30 ngày (FEAT-CORE-HRCORE-002); **chấm công 40h/tuần, trần 48h overtime** (nội dung feature này).
3. Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8 (FEAT-CORE-HRCORE-004 — ngày nghỉ đã duyệt không tính vào giờ công chuẩn).
4. Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn (FEAT-CORE-HRCORE-006).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]`, không tự quyết; luồng duyệt điều chỉnh công của TL do cấp quản lý trên trực tiếp xử lý cho đến khi được chốt.

---

## 4. Phân Quyền

| Hành động | Nhân viên (18-vai registry) | TL | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO |
|-----------|------------------------------|-----|-------|-------|------------------------|
| Ghi công của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Đề nghị điều chỉnh công của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Duyệt điều chỉnh công (của thành viên) | ❌ | ✅ (≠ người đề nghị) | ✅ (hỗ trợ HR) | ✅ | ❌ |
| Đăng ký OT của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Duyệt OT trong trần 8h/tuần | ❌ | ✅ (≠ người đăng ký) | ❌ | ✅ | ❌ |
| Duyệt OT vượt trần tuần / trần năm 200h | ❌ | ❌ | ❌ | ✅ (SLA 24h) | ❌ |
| Xem báo cáo tổng hợp công/OT nhóm | ❌ | ✅ (nhóm mình) | ✅ | ✅ | ✅ |
| Kích hoạt handoff payroll tháng | ❌ | ❌ | ✅ (chuẩn bị) | ✅ (chốt) | ❌ |
| Sửa bảng chế tài/định mức giờ theo Level | ❌ | ❌ | ❌ | ✅ (đề xuất) | ✅ (duyệt chu kỳ năm) |

> Không dùng vai ngoài 18-vai registry; không tồn tại OPS_CX / FIN_COMPL (DI-006). Nguyên tắc nền: **không ai tự duyệt chấm công/điều chỉnh của chính mình**, kể cả cấp quản lý (A6 của DEPT-HR).

---

## 5. Trường Hợp Đặc Biệt

- Quên chấm công nhiều ngày: xử lý bằng chuỗi đề nghị điều chỉnh có duyệt; hệ thống đánh dấu anomaly để HR_L1 rà soát (phòng gian lận).
- Tuần có nhiều ngày lễ: định mức tuần giảm tương ứng; công trong ngày lễ làm thêm phải qua luồng OT có duyệt, không cộng dồn tự do.
- OT retro quá hạn (>24h): ghi nhận "OT đề nghị không hợp lệ" cho HR_L2 xem xét ngoại lệ có lý do; không tự động tính.
- Nhân sự "Nghỉ dài/Không lương" (>30 ngày, FEAT-CORE-HRCORE-001): job ngừng yêu cầu ghi công và nhắc; quay lại làm việc tự khởi động lại định mức.
- Làm xuyên nửa đêm: bản ghi tách theo business date theo giờ Việt Nam để cộng dồn tuần không sai.
- Thay đổi định mức giữa kỳ (BOD duyệt chu kỳ năm): chỉ áp dụng cho tuần sau ngày hiệu lực; tuần đã chốt không tính lại.
- Giờ làm việc chuẩn (`work_schedule`) chưa chốt do lệch nguồn (Welcome Deck 08h30–17h30 vs JD 08h00–17h30) — thiết kế dạng cấu hình theo tenant, nhập khi chủ dự án chốt `[KXN-giolamviec]`.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi công ngày (`attendance_record`) và Đăng ký OT (`ot_request`)

**Sơ đồ trạng thái:**
```
attendance_record:
[ĐÃ GHI] ──(đề nghị điều chỉnh)──► [CHỜ DUYỆT ĐIỀU CHỈNH] ──(duyệt)──► [ĐÃ CHỐT THÁNG]
    │                                    │
    │                                    │ (từ chối)
    ▼                                    ▼
[ĐÃ CHỐT THÁNG]                    [ĐIỀU CHỈNH BỊ TỪ CHỐI (bản gốc giữ nguyên)]

ot_request:
[NHÁP] ──(gửi)──► [CHỜ DUYỆT] ──(TL duyệt ≤8h/tuần | HR_L2 duyệt vượt trần)──► [ĐÃ DUYỆT]
                      │
                      │ (từ chối / quá hạn retro)
                      ▼
                  [TỪ CHỐI]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Đã ghi | Gửi đề nghị điều chỉnh | Chờ duyệt điều chỉnh | Nhân viên (người sở hữu) | Lý do bắt buộc; không sửa bản gốc |
| Chờ duyệt điều chỉnh | Duyệt | Đã ghi (kèm correction đã duyệt) | TL/HR — người khác người đề nghị | Audit log trước/sau; giữ bản gốc |
| Chờ duyệt điều chỉnh | Từ chối | Điều chỉnh bị từ chối | TL/HR | Ghi lý do từ chối |
| Đã ghi (toàn bộ tuần) | Chốt tháng | Đã chốt tháng | Hệ thống (job chốt kỳ) | Hết kỳ + mọi correction đã xử lý; sinh file handoff payroll |
| OT: Nháp | Gửi đăng ký | Chờ duyệt | Nhân viên | Ngày giờ OT + nội dung công việc |
| OT: Chờ duyệt | Duyệt | Đã duyệt | TL (≤8h OT/tuần) hoặc HR_L2 (vượt trần, SLA 24h) | Tổng giờ chuẩn + OT ≤ 48h/tuần — chặn cứng nếu vượt mà chưa có duyệt HR_L2 |
| OT: Chờ duyệt | Từ chối | Từ chối | TL/HR_L2 | Ghi lý do |

**Quy tắc:**
- "Đã chốt tháng" là trạng thái kết thúc của chu kỳ — correction sau chốt tạo bản ghi điều chỉnh kỳ kế tiếp, không mở lại kỳ đã chốt.
- OT request không thể chuyển từ "Từ chối" sang "Đã duyệt" — phải tạo đăng ký mới.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `attendance_record` | `employee_id`, `business_date`, `check_in`, `check_out`, `standard_hours`, `status` | FK → `employee` | Giờ VN; business date xử lý xuyên nửa đêm |
| `attendance_correction` | `attendance_id`, `before`, `after`, `reason`, `requested_by`, `approved_by` | FK → `attendance_record`, `users` | Approver ≠ requester; giữ bản gốc |
| `ot_request` | `employee_id`, `planned_from`, `planned_to`, `hours`, `reason`, `mode` (PRE/RETRO), `status`, `approver_id`, `approval_level` (TL/HR_L2) | FK → `employee` | Retro SLA 24h; chặn cứng >48h/tuần |
| `attendance_violation` | `employee_id`, `date`, `type` (MUỘN/SỚM/QUÊN_CHẤM), `minutes`, `fine_amount`, `multiplier` | FK → `employee` | Bảng mốc 03 §8; x2 lần 4/tháng; x2 quản lý; loại trừ intern KD |
| `work_schedule` | `tenant_id`, `shift_start`, `shift_end`, `lunch_break`, `weekly_standard_hours` | — | Cấu hình theo tenant — `[KXN-giolamviec]` chờ chốt giờ chuẩn |
| `payroll_handoff` | `period`, `employee_id`, `approved_std_hours`, `approved_ot_hours`, `handoff_at`, `checksum` | FK → `employee` | Chỉ giờ đã duyệt; log cho DEPT-FINANCE |
| `audit_log` | `actor_id`, `entity`, `before/after`, `at`, `tenant_id` | — | Bất biến, tenant isolated |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn 48h ở service layer | Nhân sự đã có 44h chuẩn duyệt trong tuần | API duyệt thêm 5h OT (không qua WEB) | Service từ chối tổng >48h bất kể kênh; trả mã lỗi Điều 107; có log | [ ] |
| SC-002: OT vượt trần chỉ HR_L2 | Đăng ký OT đẩy tổng OT tuần lên 10h | TL cố duyệt | API từ chối sai thẩm quyền; chỉ HR_L2 duyệt được trong SLA 24h | [ ] |
| SC-003: Tự duyệt điều chỉnh bị chặn | TL gửi đề nghị điều chỉnh công của chính mình | TL mở hàng đợi duyệt | Bản ghi của mình không xuất hiện ở hàng đợi; gọi API trực tiếp cũng bị từ chối (approver ≠ requester) | [ ] |
| SC-004: Chế tài muộn theo mốc | Nhân viên vận hành muộn 12 phút lần đầu trong tháng | Job tính vi phạm đêm | Ghi `attendance_violation` 30.000đ theo mốc 03 §8; intern KD được loại trừ; quản lý nhân đôi | [ ] |
| SC-005: Handoff chỉ chứa giờ đã duyệt | Tháng kết thúc, còn 1 correction chờ duyệt | Job chốt tháng chạy | File handoff payroll chỉ gồm giờ approved; giờ chờ duyệt nằm ngoài và có log cảnh báo | [ ] |

> **Liên kết:** Các scenario map đến REQ-HR-003 (`hr.md` Mục A3/B3) và BR-HR3-01..09 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/cham-cong-overtime.md` |
| Nguồn domain nội quy/chế tài/giờ làm việc | `documents/03_Quy_che_KPI_HR.md` (mục 8, 9) |
