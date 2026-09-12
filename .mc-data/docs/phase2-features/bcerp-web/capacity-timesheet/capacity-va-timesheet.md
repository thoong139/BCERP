# Tính Năng: Capacity & Timesheet

> **Dựa trên:** REQ-OPS-007 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục A3/B.8)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Capacity & Timesheet (MOD-CAPACITY-TIMESHEET)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/hr/hr.md` (B9 — ranh giới HR), `documents/03_Quy_che_KPI_HR.md` (§8 — nội quy giờ làm việc/nghỉ phép), `phase0-brainstorm/policies/timesheet-capacity.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/capacity-timesheet/feat-erp-capts-002-impl.md`
>
> **Fan-out:** REQ-OPS-007 xuất hiện ở 3 systems (SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL) — đây là bản riêng cho SYS-BCERP-WEB (WEB là touchpoint chính: nhập timesheet, duyệt, dashboard nhóm của TL); counterparts: SYS-CORE-BACKEND (capacity engine + validation) và SYS-MOBILE-INTERNAL (ghi nhanh cuối ngày, TL duyệt trên di động, push cảnh báo). Business rule enforce ở tầng service layer của CORE; WEB render form/list/workflow UI và hiển thị đúng trạng thái machine-state.
>
> **Hướng dẫn ID:** FEAT-ERP-CAPTS-002 là ID lane cấp cho REQ-OPS-007 trên module MOD-CAPACITY-TIMESHEET (tra `req-registry.json` để xác nhận).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CAPTS-002 |
| Module | MOD-CAPACITY-TIMESHEET |
| Yêu cầu nghiệp vụ | REQ-OPS-007 — Capacity & Timesheet |
| Người dùng liên quan | OPS_PLAN (TL — duyệt lần 1, duyệt gán vùng vàng), OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (người ghi + nhận gán); HR_L2 (thẩm quyền định mức — ranh giới); BOD_CEO (duyệt khẩn cấp vượt mốc) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-OPS-005/REQ-OPS-006 (WBS + project type khóa tập nhãn timesheet); REQ-HR-009 (chính sách duyệt timesheet từ HR); REQ-HR-004 (nghỉ đã duyệt tự trừ capacity) |
| Ghi chú Expert (A7) | A7 của `operations.md` đang chờ Team Expert review, nhưng đã khai báo ranh giới REQ-OPS-007 với DEPT-HR: engine chặn gán ở CORE, ghi + duyệt trên WEB và M-INT, thẩm quyền điều chỉnh định mức thuộc HR_L2 đề xuất → BOD duyệt — OPS chỉ sử dụng. Điều này được giữ nguyên vẹn trong spec này. |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là điểm vào chính trên BCERP Web nội bộ (Next.js, responsive) để toàn bộ nhân sự OPS **ghi timesheet hằng ngày với nhãn Client Billable / Internal Non-billable bắt buộc tại nguồn** và vận hành **capacity theo tuần** thông qua dashboard nhóm của TL: xem utilization, cảnh báo dưới tải/quá tải, duyệt gán vùng vàng và bị chặn khi vùng đỏ. Dữ liệu ghi tại nguồn đúng nhãn là điều kiện tiên quyết cho chuỗi duyệt (FEAT-ERP-CAPTS-001 góc HR) và cho chi phí P&L của FIN.

**Phạm vi:**
- Bao gồm:
  - Form ghi timesheet hằng ngày: chọn dự án/task (WBS từ REQ-OPS-006), nhập giờ, bắt buộc chọn nhãn billable trước khi lưu; validation theo cặp loại dự án × nhãn chạy ở CORE.
  - Quy trình correction: sai nhãn/giờ tạo yêu cầu correction kèm lý do — bản gốc giữ nguyên, audit log bất biến, TL xác nhận trong 24h.
  - Chốt tuần trước 12:00 thứ Hai và hàng đợi duyệt lần 1 của TL (SLA 48h, quá 72h escalate Manager) — hiển thị đúng machine-state từ CORE.
  - Dashboard nhóm của TL: utilization theo tuần theo băng màu (dưới tải <70% / xanh 70–90% / vàng >90% / đỏ ≥100%), danh sách người ghi chậm (>3 ngày), hàng đợi duyệt gán vùng vàng.
  - Capacity check bắt buộc trước mọi thao tác gán task (kết quả do CORE capacity engine trả về; WEB hiển thị và chặn theo kết quả).
  - Đăng ký OT trong trần 8h/tuần (duyệt trước khi thực hiện) và log khẩn cấp khách vượt 110% ≤5 ngày làm việc liên tục kèm lý do.
- Không bao gồm:
  - Capacity engine tính utilization, chặn gán vùng đỏ, escalate 4h/8h — thực thi ở SYS-CORE-BACKEND; WEB chỉ hiển thị kết quả và trạng thái.
  - Ghi nhanh cuối ngày, push cảnh báo và duyệt trên di động — thuộc SYS-MOBILE-INTERNAL (bản counterpart của cùng REQ).
  - Chính sách duyệt, định mức giờ/tuần, tỷ lệ billable mục tiêu, duyệt OT vượt trần/retro — thẩm quyền của DEPT-HR (REQ-HR-009 / FEAT-ERP-CAPTS-001); OPS chỉ sử dụng cấu hình.
  - Quy đổi giờ đã duyệt thành chi phí P&L — đầu vào của DEPT-FINANCE qua gate CORE.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Ghi timesheet hằng ngày với nhãn Client Billable / Internal Non-billable chọn ngay khi nhập (không chọn không lưu được) | Chi phí dự án đúng nguồn ngay từ thời điểm ghi, không phải đoán lại cuối tháng |
| 2 | OPS_AM | Tạo correction kèm lý do khi ghi sai giờ/nhãn | Sai sót được sửa minh bạch trong khi bản gốc và audit log được bảo toàn |
| 3 | OPS_PLAN (TL) | Có dashboard nhóm hiển thị utilization băng màu + danh sách ghi chậm | Phát hiện sớm người cạn việc (<70%) và người quá tải trước khi dồn việc |
| 4 | OPS_PLAN (TL) | Duyệt gán mới cho người đang ở vùng vàng (>90%) ngay trên hàng đợi | Kiểm soát quá tải có chủ đích mà không chặn hoàn toàn hoạt động |
| 5 | OPS_AM | Được hệ thống chặn khi cố gán việc cho người đã ≥100% capacity | Không tạo overtime ngầm; buộc dịch deadline, đổi người hoặc duyệt OT |
| 6 | OPS_CONT | Đăng ký OT trong trần 8h/tuần và được TL duyệt trước khi làm | Giờ làm thêm được công nhận hợp lệ theo nội quy |
| 7 | OPS_DES | Ghi log khẩn cấp khách (VD die account ngoài giờ) cho phép tạm vượt tới 110% tối đa 5 ngày làm việc | Xử lý sự cố khách mà vẫn để lại dấu vết audit để BOD rà soát |
| 8 | OPS_EDIT | Chốt tuần trước 12:00 thứ Hai chỉ với một thao tác | Tuần của tôi vào hàng đợi duyệt đúng SLA, không bị trễ do quy trình |
| 9 | OPS_PLAN (TL) | Nhận cảnh báo khi khả năng xử lý capacity check quá 4h và escalate tự động 8h sang HR_L2 | Không để yêu cầu gán việc treo làm chậm tiến độ dự án |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (validation cứng ở tầng service CORE; WEB phản ánh kết quả). Nguồn policy: `timesheet-capacity.md` §2.1–2.6; ranh giới HR: `operations.md` B.8.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Nhãn billable bắt buộc tại nguồn:** mỗi dòng timesheet phải gắn nhãn Client Billable / Internal Non-billable ngay tại thời điểm ghi — không chọn nhãn thì không lưu được; nhãn khóa theo project type từ WBS (REQ-OPS-006). | Nút lưu bị vô hiệu khi thiếu nhãn; API từ chối payload thiếu `billing_label` |
| BR-002 | **Cấm sửa nhãn/giờ sau khi ghi:** sai sót tạo correction — bản gốc giữ nguyên, audit log bất biến (ai — khi nào — sửa gì — lý do), TL xác nhận trong 24h. | Không có đường sửa chỗ trên UI; correction chưa được TL xác nhận không thay đổi dữ liệu gốc |
| BR-003 | **Validation cặp project type × nhãn:** cấm ghi giờ nội bộ với nhãn Client Billable vào dự án khách và ngược lại. Exception: dự án nội bộ phục vụ trực tiếp 1 khách (VD case study có approval khách) — AM đề xuất, TL duyệt chuyển một phần giờ thành Client Billable, có log. | Dòng ghi sai cặp bị chặn tại thời điểm lưu với thông báo rõ nhãn hợp lệ của project type |
| BR-004 | **Nhịp ghi và chốt tuần:** ghi hằng ngày trong ngày làm việc, chậm nhất trước 12:00 hôm sau; chậm quá 3 ngày → cảnh báo TL; chốt tuần trước 12:00 thứ Hai tuần kế; TL duyệt trong 48h, quá 72h escalate Manager. | WEB hiển thị badge ghi chậm trên dashboard nhóm; quá hạn chốt không cho phép đính vào tuần đã khóa — tạo bản ghi tuần sau có ghi chú |
| BR-005 | **Cấm tự duyệt:** approver bắt buộc khác người ghi (validation CORE); timesheet của TL do Manager L4 duyệt; delegate quyền duyệt của TL `[KXN]` — chưa chốt (DI-006/SO3-09 nhóm D), không xây tính năng delegate. | UI ẩn nút duyệt cho chính người ghi; API duyệt chính mình trả 403 + audit log |
| BR-006 | **Giờ chưa duyệt không vào P&L** — chỉ giờ `APPROVED` được nhân Cost Rate Card để allocate chi phí nhân sự (handoff FIN). | Báo cáo cost tách bạch "chờ duyệt" khỏi "đã duyệt"; gate CORE từ chối allocate giờ chưa duyệt |
| BR-007 | **Capacity utilization theo tuần** = tổng giờ đã gán ÷ capacity khả dụng (40h chuẩn − nghỉ phép/ốm đã duyệt; tuần lễ giảm theo ngày lễ): **<70% cảnh báo TL (dưới tải); 70–90% xanh nhận gán tự do; >90% vàng dừng gán tự động — gán mới phải TL phê duyệt; ≥100% đỏ chặn cứng gán vượt** — buộc dịch deadline, đổi người hoặc duyệt OT. | Gán vùng vàng chưa duyệt không tạo assignment; gán vùng đỏ bị chặn tầng API với mã lỗi băng màu |
| BR-008 | **Khẩn cấp khách:** tối đa 110% trong ≤5 ngày làm việc liên tục, bắt buộc log lý do; vượt mốc phải BOD duyệt. Nghỉ phép/ốm đã duyệt không chiếm capacity và không tính utilization. | Gán vượt 110% hoặc quá 5 ngày liên tục bị chặn nếu chưa có phê duyệt BOD; log khẩn cấp hiển thị trên dashboard OPS_PLAN |
| BR-009 | **Capacity check bắt buộc trước mọi gán task và tại Gate 2 (handoff REQ-OPS-004):** SLA xử lý 4h; quá 4h escalate TL; quá 8h escalate HR_L2 cân đối đầu người. | Không thể tạo assignment khi chưa chạy capacity check; escalate tự động kèm context |
| BR-010 | **Ranh giới thẩm quyền định mức:** 40h chuẩn/tuần, trần ghi nhận 48h/tuần gồm OT, tỷ lệ billable mục tiêu (L1 ≥80%, L2 ≥75%, L3 60–70%, L4 40–50%, L5 20–30%) do HR_L2 đề xuất → BOD duyệt (chu kỳ năm) — OPS chỉ sử dụng, không tự thay. | OPS không thấy nút sửa định mức (RBAC); gọi API sửa định mức bị từ chối và ghi log |
| BR-011 | **OT:** duyệt trước khi thực hiện (TL, trong trần 8h/tuần; tổng chuẩn + OT ≤48h/tuần — Điều 107 BLLĐ 2019); retro 24h chỉ cho sự cố khẩn cấp; OT vượt trần/retro do HR_L2 duyệt trong 24h. | OT chưa duyệt không được tính; vượt trần tuần tự route sang hàng đợi HR_L2 của FEAT-ERP-CAPTS-001 |
| BR-012 | **Ngoại lệ đối tượng ghi:** L5/BOD ghi theo dự án (không bắt buộc chi tiết task); nhân sự mới tuần đầu 100% Internal Non-billable, không áp ngưỡng billable; giờ làm việc/nghỉ phép theo nội quy `03_Quy_che_KPI_HR.md` §8 (sáng 08h30–12h00, chiều 13h00–17h30, không tính T7/CN/lễ; mobile chấm công cho staff thuộc SYS-MOBILE-INTERNAL). | Form ghi của L5/BOD ẩn bắt buộc task; profile nhân sự mới tự áp nhãn Internal mặc định tuần đầu |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry — các vai đã bị gỡ khỏi registry (quyết định stakeholder 12/09/2026, DI-006) không xuất hiện trong ma trận này. TL trong luồng duyệt là vai vận hành của OPS_PLAN theo cấu hình OPS hiện tại; người duyệt timesheet cấp TL/OPS_PLAN (Manager L4) hiện không có chuyên trách `[KXN]` — chờ chốt tổ chức.

| Hành động | OPS_AM/CONT/DES/EDIT/ADS | OPS_PLAN (TL) | HR_L1 | HR_L2 | BOD_CEO | SYS_ADMIN |
|-----------|--------------------------|---------------|-------|-------|---------|-----------|
| Ghi timesheet của mình (kèm nhãn bắt buộc) | ✅ | ✅ | ❌ | ❌ | ❌ (L5/BOD ghi theo dự án — xem BR-012) | ❌ |
| Chốt tuần của mình | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo yêu cầu correction | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận correction của nhóm | ❌ | ✅ (24h) | ❌ | ❌ | ❌ | ❌ |
| Duyệt timesheet nhóm (duyệt lần 1, 48h) | ❌ | ✅ (khác người ghi) | ❌ | ❌ | ❌ | ❌ |
| Gán task qua capacity check | ✅ (cho thành viên nhóm dự án) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt gán vùng vàng (>90%) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo log khẩn cấp vượt 110% | ✅ (đề xuất kèm lý do) | ✅ | ❌ | ❌ | ✅ (duyệt vượt mốc 5 ngày) | ❌ |
| Duyệt OT trong trần 8h/tuần | ❌ | ✅ (trước khi thực hiện) | ❌ | ✅ (vượt trần/retro — 24h) | ❌ | ❌ |
| Xem dashboard nhóm (utilization, ghi chậm) | ❌ (chỉ của mình) | ✅ | ✅ (không cost — REQ-HR-010) | ✅ | ✅ | ❌ |
| Sửa nhãn/giờ sau khi ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Sửa định mức giờ/tuần, tỷ lệ billable mục tiêu | ❌ | ❌ | ❌ | ✅ (đề xuất; BOD duyệt) | ✅ (duyệt) | ❌ |

**Ghi chú:** SYS_ADMIN không có quyền nghiệp vụ trên dữ liệu timesheet/capacity — chỉ truy cập kỹ thuật có audit log. Quyền gán task của OPS_AM/CONT/DES/EDIT/ADS giới hạn trong thành viên dự án mình sở hữu/tham gia (row-level scoping ở CORE).

---

## 5. Trường Hợp Đặc Biệt

- **Die account khẩn cấp ngoài giờ:** nhóm ads (OPS_ADS) cần tăng tải tức thời — TL tạo log khẩn cấp cho phép vượt tới 110% trong ≤5 ngày làm việc liên tục kèm lý do; quá mốc tự chặn và phải trình BOD duyệt trước khi gán tiếp.
- **Nghỉ phép duyệt retro giữa tuần:** nhân viên nghỉ ốm đột xuất khi assignment đang treo — khi đơn nghỉ (REQ-HR-004) được duyệt, capacity khả dụng tự tăng lại và assignment treo phải chạy lại capacity check; FEAT-ERP-CAPTS-001 mô tả phía HR của cùng luồng.
- **Correction chéo tuần đã allocate:** correction được xác nhận sau khi giờ của tuần đó đã vào P&L — tạo bút toán điều chỉnh kỳ sau, không sửa dữ liệu đã hạch toán; audit log giữ cả hai phiên bản cho FIN đối soát.
- **Người ghi chậm quá 3 ngày:** hệ thống cảnh báo TL và ghi chậm hiển thị trên dashboard; nếu trễ do nghỉ ốm có chứng minh thì TL ghi chú ngoại lệ, không tính vi phạm nhịp ghi vào đánh giá.
- **Nhân sự mới (tuần đầu onboarding):** toàn bộ giờ mặc định Internal Non-billable, không so với ngưỡng billable mục tiêu; từ tuần thứ hai áp dụng quy tắc thường.
- **Dự án nội bộ phục vụ trực tiếp một khách:** AM đề xuất, TL duyệt chuyển một phần giờ sang Client Billable kèm approval của khách — validation BR-003 mở ngoại lệ có log, không phải sửa nhãn thủ công.
- **Sai lệch khung giờ làm việc giữa nguồn §8 và JD:** `03_Quy_che_KPI_HR.md` §8 ghi 08h30–17h30 (nghỉ trưa 12h00–13h00) trong khi một số JD ghi 08h00–17h30 (nghỉ trưa 12h00–13h30) — hệ thống dùng một tham số `work_schedule` duy nhất, mặc định theo §8, cập nhật khi chủ dự án xác nhận giờ chuẩn `[KXN]`.
- **Duyệt trên di động khi ngoài văn phòng:** REQ-OPS-007 cho phép TL duyệt trên M-INT (counterpart SYS-MOBILE-INTERNAL); nếu M-INT không khả dụng, WEB responsive là kênh dự phòng trên browser — không có phương thức duyệt ngoài hai kênh này, đảm bảo mọi lượt duyệt đi qua validation CORE `[KXN-9]` (phạm vi "tương lai" TMS/mobile chờ chốt, không tự quyết).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** TimesheetEntry (dòng timesheet) và Assignment (gán task) — trạng thái lưu/validate ở CORE; WEB hiển thị machine-state và khóa thao tác theo băng màu.

**Sơ đồ trạng thái (TimesheetEntry):**
```
[DRAFT] ──(ghi xong dòng có nhãn)──► [LOGGED] ──(chốt tuần trước 12:00 T2)──► [SUBMITTED] ──(TL duyệt ≤48h)──► [APPROVED] ──(job allocate × Rate Card)──► [ALLOCATED]
                                                                                   │                              │
                                                                                   │ (từ chối — lý do bắt buộc)     │ (correction — bản gốc giữ nguyên)
                                                                                   ▼                              ▼
                                                                               [REJECTED]                    [CORRECTION_PENDING] ──(TL xác nhận ≤24h)──► [APPROVED]
```

**Sơ đồ trạng thái (Assignment — quyết định của capacity engine):**
```
[REQUESTED] ──(capacity check 4h)──► [APPROVED_AUTO] (xanh 70–90%)
                  │
                  ├─(vàng >90%)──► [PENDING_TL] ──(TL duyệt)──► [ASSIGNED]
                  │                      │
                  │                      └─(TL từ chối)──► [REJECTED]
                  └─(đỏ ≥100%)──► [BLOCKED] ──(dịch deadline / đổi người / duyệt OT)──► [REQUESTED]
```

**Bảng chuyển đổi (Assignment):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `REQUESTED` | Capacity check trả băng xanh | `APPROVED_AUTO` | Hệ thống | Utilization 70–90%; SLA 4h |
| `REQUESTED` | Capacity check trả băng vàng | `PENDING_TL` | Hệ thống | Utilization >90%; vào hàng đợi TL |
| `REQUESTED` | Capacity check trả băng đỏ | `BLOCKED` | Hệ thống | Utilization ≥100% và không có phê duyệt khẩn cấp hợp lệ |
| `PENDING_TL` | Duyệt gán | `ASSIGNED` | OPS_PLAN (TL) | Trong SLA 4h của capacity check |
| `PENDING_TL` | Từ chối gán | `REJECTED` | OPS_PLAN (TL) | Bắt buộc lý do |
| `BLOCKED` | Khẩn cấp khách có log | `ASSIGNED` | OPS_PLAN (TL) | ≤110%, ≤5 ngày LV liên tục, log lý do; quá mốc cần BOD |

**Quy tắc:**
- `ASSIGNED` và `REJECTED` là trạng thái kết thúc của một yêu cầu gán — muốn gán lại phải tạo request mới chạy capacity check.
- Nghỉ đã duyệt làm capacity khả dụng thay đổi → mọi assignment chưa kết thúc chạy lại capacity check tuần kế tiếp.
- TimesheetEntry không bao giờ nhảy cóc trạng thái; `LOGGED` chỉ tồn tại trong tuần đang mở (chưa chốt).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `timesheet_entry` | `id`, `user_id`, `project_id`, `task_id`, `week_key`, `work_date`, `hours`, `billing_label`, `status` | FK → `users.id`, `projects.id`, `tasks.id` | Nhãn không sửa sau ghi; audit log bất biến |
| `timesheet_correction` | `entry_id`, `old_values`, `new_values`, `reason`, `requested_by`, `confirmed_by`, `confirmed_at` | FK → `timesheet_entry.id` | TL xác nhận 24h; bản gốc bất biến |
| `assignment` | `id`, `task_id`, `assignee_id`, `requested_by`, `capacity_check_result`, `band`, `status`, `override_log_id` | FK → `tasks.id`, `users.id` | Không tạo khi chưa có capacity check |
| `capacity_week` (derived) | `user_id`, `week_key`, `standard_hours`, `leave_hours_approved`, `available_capacity`, `assigned_hours`, `utilization_percent`, `band` | FK → `users.id` | Tính ở CORE theo tuần; WEB read-only |
| `emergency_override_log` | `user_id`, `week_key`, `reason`, `utilization_percent`, `consecutive_days`, `approved_by`, `expires_at` | FK → `users.id` | Trần 110% ≤5 ngày LV; quá mốc BOD duyệt |
| `ot_request` | `user_id`, `week_key`, `hours`, `kind` (pre/retro), `status`, `approver_role` | FK → `users.id` | Trần 8h/tuần; retro 24h; vượt trần route HR_L2 |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Bắt buộc nhãn tại nguồn | Form ghi timesheet mở | Người dùng bấm lưu khi chưa chọn nhãn | Nút lưu vô hiệu/API từ chối; hiển thị nhãn hợp lệ theo project type | [ ] |
| SC-002: Chặn đỏ | Người nhận có utilization ≥100% | AM gán task mới | Assignment ở trạng thái `BLOCKED`; gợi ý dịch deadline/đổi người/duyệt OT | [ ] |
| SC-003: Duyệt gán vùng vàng | Người nhận ở vùng >90% | Gán mới phát sinh | Assignment vào `PENDING_TL`; chỉ tạo `ASSIGNED` sau khi TL duyệt trong SLA 4h | [ ] |
| SC-004: Correction bảo toàn bản gốc | Dòng timesheet đã ghi sai nhãn | Người ghi tạo correction, TL xác nhận | Bản gốc giữ nguyên; audit log ghi đủ ai/khi nào/sửa gì/lý do; dữ liệu mới áp từ dòng correction | [ ] |
| SC-005: Khẩn cấp 110% có log | Die account ngoài giờ, người phụ trách ở 100% | TL tạo log khẩn cấp và gán | Gán thành công tối đa 110% trong ≤5 ngày LV; quá mốc bị chặn chờ BOD | [ ] |
| SC-006: Ghi chậm cảnh báo TL | Nhân viên không ghi 3 ngày liên tiếp | Job kiểm tra nhịp ghi chạy | Cảnh báo gửi TL; badge ghi chậm hiển thị trên dashboard nhóm | [ ] |

> **Liên kết:** SC-001/004/006 map REQ-OPS-007 (B.8 — BR-OPS-8.1/8.2); SC-002/003/005 map REQ-OPS-007 (BR-OPS-8.3) và policy `timesheet-capacity.md` §2.2–2.3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (capacity engine CORE, handoff M-INT, gate P&L FIN) |
| Màn hình UI | `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md` |
| Policy nguồn | `phase0-brainstorm/policies/timesheet-capacity.md` §2.1–2.6, §3, §5 |
| Domain knowledge HR | `documents/03_Quy_che_KPI_HR.md` §8 (giờ làm việc, nghỉ phép, chế tài) |
