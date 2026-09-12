# Tính Năng: Duyệt Timesheet & Capacity (Phối Hợp OPS)

> **Dựa trên:** REQ-HR-009 trong `phase1-business/departments/hr/hr.md` (Phần A — Mục A3/B9)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Capacity & Timesheet (MOD-CAPACITY-TIMESHEET)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `phase1-business/departments/operations/operations.md`, `documents/03_Quy_che_KPI_HR.md` (§8 — nội quy giờ làm việc/nghỉ phép), `phase0-brainstorm/policies/timesheet-capacity.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/capacity-timesheet/feat-erp-capts-001-impl.md`
>
> **Fan-out:** REQ-HR-009 xuất hiện ở 2 systems (SYS-CORE-BACKEND, SYS-BCERP-WEB) — đây là bản riêng cho SYS-BCERP-WEB; bản đối ứng headless API/domain service nằm ở SYS-CORE-BACKEND. Tất cả business rule được enforce ở tầng service layer của CORE; WEB chỉ render form/list/workflow UI và hiển thị đúng trạng thái machine-state trả về từ CORE.
>
> **Hướng dẫn ID:** FEAT-ERP-CAPTS-001 là ID lane cấp cho REQ-HR-009 trên module MOD-CAPACITY-TIMESHEET (tra `req-registry.json` để xác nhận).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CAPTS-001 |
| Module | MOD-CAPACITY-TIMESHEET |
| Yêu cầu nghiệp vụ | REQ-HR-009 — Duyệt timesheet & capacity (phối hợp OPS) |
| Người dùng liên quan | HR_L1, HR_L2 (chính); OPS_PLAN (TL — duyệt lần 1); Manager L4 (duyệt timesheet của TL); OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (người ghi); BOD_CEO (duyệt định mức chu kỳ năm) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-HR-006 (Cost Rate Card — quy đổi giờ đã duyệt thành cost); REQ-HR-004 (nghỉ phép đã duyệt tự trừ capacity tuần); REQ-OPS-007 (bản đối ứng góc OPS — ghi giờ và gán việc) |
| Ghi chú Expert (A7) | A7.2 của `hr.md` flag 2 điểm gắn trực tiếp REQ-HR-009: (1) định mức giờ/tuần và tỷ lệ billable theo bậc đã có khung policy `timesheet-capacity.md` nhưng chờ BOD duyệt chu kỳ năm; (2) nhu cầu duyệt timesheet trên mobile hiện ngoài scope SYS-MOBILE-INTERNAL — xem xét khi mở rộng scope `[KXN]`. A7.3 chưa có điều chỉnh chính thức (chờ Team Expert review). |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp trên BCERP Web nội bộ (Next.js, responsive browser UI) toàn bộ màn hình phục vụ **tầng quy tắc duyệt** timesheet và capacity theo ranh giới sở hữu đã chốt: DEPT-HR sở hữu quy tắc duyệt, định mức, escalation và chính sách OT; DEPT-OPS sở hữu ghi giờ hằng ngày và gán việc (xem FEAT-ERP-CAPTS-002). HR không sửa nội dung giờ đã ghi — HR can thiệp ở tầng quy tắc: duyệt OT vượt trần/retro, nhận escalation capacity, đề xuất định mức trình BOD, và giám sát tiến độ duyệt của các nhóm thông qua dashboard trạng thái.

**Phạm vi:**
- Bao gồm:
  - Hàng đợi duyệt timesheet tuần cho Team Leader (OPS_PLAN) với SLA 48h, cảnh báo quá 48h, escalate Manager sau 72h — hiển thị trạng thái machine-state (`DRAFT/SUBMITTED/APPROVED/REJECTED/CORRECTION_PENDING`) trả về từ CORE.
  - Màn hình duyệt OT vượt trần tuần 8h và duyệt retro (24h) của HR_L2; đếm trần OT 200h/năm.
  - Cơ chế escalation capacity check: quá SLA 4h → TL, quá 8h → HR_L2 cân đối đầu người (nối requisition REQ-HR-001 nếu thiếu người).
  - Workflow đề xuất → duyệt định mức giờ/tuần và tỷ lệ billable mục tiêu theo bậc (HR_L2 đề xuất → BOD duyệt, chu kỳ năm) — tham số effective-dated.
  - Dashboard trạng thái "giờ chờ duyệt / giờ đã duyệt" tách bạch hoàn toàn khỏi báo cáo cost; gate "giờ chưa duyệt không vào P&L" hiển thị đúng nguồn sự thật của CORE.
  - Xác nhận correction giờ đã ghi (TL xác nhận trong 24h kèm audit log bất biến) và báo cáo tỷ lệ billable thực tế theo tháng gửi HR_L2 đối chiếu mục tiêu.
- Không bao gồm:
  - Form ghi timesheet hằng ngày, gắn nhãn billable tại nguồn và thao tác gán task qua capacity check — thuộc FEAT-ERP-CAPTS-002 (góc OPS) và SYS-MOBILE-INTERNAL (ghi nhanh cuối ngày).
  - Capacity engine tính utilization và chặn gán vùng đỏ — chạy ở SYS-CORE-BACKEND, WEB chỉ hiển thị kết quả.
  - Hạch toán chi phí P&L — đầu vào của DEPT-FINANCE (chỉ giờ `APPROVED` × Cost Rate Card REQ-HR-006 được allocate ở CORE).
  - Quy trình nghỉ phép (REQ-HR-004) và chấm công vân tay (REQ-HR-003) — chỉ tiêu thụ kết quả "nghỉ đã duyệt tự trừ capacity".

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Soạn và trình BOD đề xuất điều chỉnh định mức giờ/tuần + tỷ lệ billable mục tiêu theo bậc (chu kỳ năm, effective-dated) | Chính sách áp dụng nhất quán toàn công ty và OPS chỉ sử dụng cấu hình, không tự thay |
| 2 | HR_L2 | Duyệt OT vượt trần tuần 8h và OT retro trong 24h ngay trên web | Kiểm soát tổng giờ ≤48h/tuần và trần 200h/năm đúng Điều 107 BLLĐ 2019 |
| 3 | HR_L2 | Nhận escalation capacity check quá 8h kèm dữ liệu đầu người | Cân đối nhân lực và mở requisition (REQ-HR-001) khi nhóm thiếu người |
| 4 | HR_L1 | Theo dõi dashboard tiến độ duyệt timesheet toàn công ty (tỷ lệ chốt tuần, giờ chờ duyệt, nhóm ghi chậm) — không có cột cost cá nhân | Nắm tình hình tuân thủ mà không truy cập dữ liệu lương/cost thuộc Restricted (REQ-HR-010) |
| 5 | OPS_PLAN (TL) | Có hàng đợi duyệt tuần gom timesheet của thành viên, nhắc SLA 48h và tự escalate Manager sau 72h | Duyệt đúng hạn mà không phải tự theo dõi deadline thủ công |
| 6 | Manager L4 | Duyệt timesheet của TL trong hàng đợi riêng | Ràng buộc "cấm tự duyệt" áp cả tầng quản lý |
| 7 | HR_L2 | Xem trạng thái "giờ chờ duyệt" tách bạch khỏi "giờ đã duyệt" trên mọi báo cáo | Bảo đảm chỉ giờ approved mới là đầu vào P&L cho DEPT-FINANCE |
| 8 | HR_L2 | Nhận báo cáo tỷ lệ billable thực tế theo tháng đối chiếu mục tiêu L1 ≥80% → L5 20–30% | Đối chiếu chênh lệch và dùng làm đầu vào KPI 3 trụ cột (REQ-HR-007) |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (validation cứng ở tầng service CORE; WEB chỉ phản ánh kết quả).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Cấm tự duyệt timesheet** — approver bắt buộc khác người ghi (validation cứng CORE, áp cả TL); timesheet của TL (OPS_PLAN) do Manager L4 duyệt. Việc delegate quyền duyệt của TL cho người khác `[KXN]` — chưa chốt (theo DI-006/SO3-09 nhóm D), hệ thống KHÔNG xây tính năng delegate cho đến khi được xác nhận. | Nút duyệt không hiển thị cho chính người ghi; gọi API duyệt chính mình bị từ chối 403 kèm audit log |
| BR-002 | **Giờ chưa duyệt không vào P&L** — chỉ timesheet ở trạng thái `APPROVED` được nhân Cost Rate Card (REQ-HR-006) để allocate chi phí nhân sự vào dự án. | Gate trước module P&L từ chối allocate; WEB hiển thị trạng thái chờ riêng, giờ chờ không bao giờ lẫn vào báo cáo cost |
| BR-003 | **SLA duyệt tuần:** nhân sự chốt tuần trước 12:00 thứ Hai; TL duyệt trong 48h; quá 48h hệ thống nhắc TL; quá 72h tự escalate Manager L4. Job đo SLA chạy ở CORE. | Thông báo escalate gửi Manager; trễ duyệt được ghi nhận trên dashboard compliance của HR_L2 |
| BR-004 | **OT:** trong trần 8h/tuần do TL duyệt trước khi thực hiện (retro 24h cho sự cố khẩn cấp); OT vượt trần tuần hoặc retro bắt buộc HR_L2 duyệt trong 24h; tổng giờ chuẩn + OT ≤48h/tuần và trần năm 200h (Điều 107 BLLĐ 2019). | OT vượt trần chưa duyệt HR_L2 không được tính công/giờ; chặn duyệt khi vượt 48h/tuần hoặc 200h/năm |
| BR-005 | **Escalation capacity check:** SLA 4h kể từ khi phát yêu cầu; quá 4h escalate TL; quá 8h escalate HR_L2 để cân đối đầu người (đề xuất mở requisition REQ-HR-001 nếu thiếu người). | Thông báo escalate tự động kèm context assignment; sự kiện escalation ghi audit log |
| BR-006 | **Định mức giờ/tuần (40h chuẩn, trần ghi nhận 48h gồm OT) và tỷ lệ billable mục tiêu theo bậc (L1 ≥80%, L2 ≥75%, L3 60–70%, L4 40–50%, L5 20–30%)** do HR_L2 đề xuất → BOD duyệt, chu kỳ năm, lưu effective-dated; OPS chỉ sử dụng cấu hình. | RBAC ẩn nút sửa định mức với mọi vai OPS; thay đổi trực tiếp ở API bị từ chối và ghi log |
| BR-007 | **Correction giờ đã ghi** phải qua TL xác nhận trong 24h kèm audit log bất biến (ai — khi nào — sửa gì — lý do), bản gốc giữ nguyên; HR không được sửa trực tiếp nội dung giờ đã ghi, chỉ can thiệp tầng quy tắc. | Không có đường sửa chỗ trên UI cho bản ghi đã ghi; correction chưa xác nhận không thay đổi dữ liệu gốc |
| BR-008 | **Capacity vàng/đỏ (khung chung với FEAT-ERP-CAPTS-002):** utilization >90% (vàng) dừng gán tự động — gán mới phải TL phê duyệt; ≥100% (đỏ) chặn cứng gán vượt; khẩn cấp khách tối đa 110% trong ≤5 ngày làm việc liên tục có log lý do, vượt mốc phải BOD duyệt. | WEB hiển thị băng màu từ CORE; gán vùng vàng chưa duyệt không tạo assignment; gán vùng đỏ bị chặn tầng API |
| BR-009 | **Giờ làm việc/nghỉ phép nội quy theo `03_Quy_che_KPI_HR.md` §8:** ngày làm sáng 08h30–12h00, chiều 13h00–17h30, không tính T7/CN/lễ; nghỉ phép đã duyệt tự trừ capacity tuần và không tính utilization. Sai lệch khung giờ giữa Welcome Deck và JD được xử lý như Trường Hợp Đặc Biệt số 6. | Cấu hình `work_schedule` là tham số duy nhất cho mọi tính giờ; đơn nghỉ duyệt xong cập nhật capacity khả dụng ngay, không cần thông báo tay OPS |
| BR-010 | **PII/Restricted (REQ-HR-010):** giờ × cost rate = dữ liệu cost — chỉ HR_L2 trở lên xem chi tiết cá nhân; HR_L1 không xem lương/cost cá nhân; mọi lượt xem dữ liệu cost có audit log. | UI mask cột cost cho HR_L1; truy cập trái phép bị RBAC chặn và ghi log bất biến |
| BR-011 | **Báo cáo tỷ lệ billable thực tế** = giờ Client Billable đã duyệt ÷ tổng giờ đã duyệt, tổng hợp tự động theo tháng theo bậc, gửi HR_L2 đối chiếu mục tiêu và là đầu vào KPI (REQ-HR-007). | Báo cáo chỉ đếm giờ `APPROVED`; thiếu dữ liệu duyệt khiến con số thấp — hệ thống hiển thị % giờ chưa duyệt cạnh con số billable |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry — các vai đã bị gỡ khỏi registry (quyết định stakeholder 12/09/2026, DI-006) không xuất hiện trong ma trận này. "TL" trong luồng duyệt lần 1 là vai vận hành của OPS_PLAN theo cấu hình OPS hiện tại; Manager L4 tương ứng vai L4 trong phòng (OPS hiện không có L4 chuyên trách `[KXN]` — người duyệt timesheet cấp TL/OPS_PLAN chờ chốt).

| Hành động | HR_L1 | HR_L2 | OPS_PLAN (TL) | OPS_AM/CONT/DES/EDIT/ADS | BOD_CEO | SYS_ADMIN |
|-----------|-------|-------|---------------|--------------------------|---------|-----------|
| Xem dashboard trạng thái duyệt toàn công ty (không cost) | ✅ | ✅ | ✅ (nhóm mình) | ❌ (chỉ của mình) | ✅ | ❌ |
| Xem giờ/cost chi tiết cá nhân | ❌ (mask cost) | ✅ | ✅ (nhóm mình, cost nhóm) | ✅ (của mình) | ✅ | ❌ (mask theo REQ-HR-010) |
| Duyệt timesheet tuần (duyệt lần 1) | ❌ | ❌ | ✅ (khác người ghi) | ❌ | ❌ | ❌ |
| Duyệt timesheet của TL | ❌ | ❌ | ❌ | ❌ | ❌ (Manager L4 — xem ghi chú) | ❌ |
| Duyệt OT vượt trần tuần / retro | ❌ | ✅ (24h) | ❌ | ❌ | ❌ | ❌ |
| Xác nhận correction giờ đã ghi | ❌ | ❌ | ✅ (24h) | ❌ (chỉ tạo yêu cầu correction) | ❌ | ❌ |
| Sửa nội dung bản ghi giờ đã ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Đề xuất điều chỉnh định mức giờ/billable | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt định mức (chu kỳ năm, effective-dated) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Nhận escalation capacity quá 8h / cân đối đầu người | ❌ | ✅ | ✅ (mốc 4h) | ❌ | ❌ | ❌ |
| Duyệt khẩn cấp vượt 110% quá 5 ngày LV | ❌ | ❌ | ❌ (chỉ tạo log lý do) | ❌ | ✅ | ❌ |

**Ghi chú:** SYS_ADMIN không được cấp quyền nghiệp vụ xem/duyệt dữ liệu timesheet-cost; chỉ truy cập kỹ thuật có audit log theo REQ-HR-010. Quyền duyệt timesheet của Manager L4 gắn với vai quản lý trực tiếp — cấu hình approver theo cây tổ chức ở CORE.

---

## 5. Trường Hợp Đặc Biệt

- **TL vắng mặt dài hạn:** hàng đợi duyệt không có người xử lý — vì delegate duyệt của TL `[KXN]` chưa chốt, hệ thống chỉ chạy escalation 48h/72h về Manager; nếu không xác định được Manager (OPS thiếu L4 chuyên trách), escalate về HR_L2 làm điều phối tạm và ghi log — KHÔNG tự gán approver thay thế.
- **Nhân sự offboard giữa tuần:** timesheet chưa chốt/duyệt của nhân sự nghỉ việc phải đưa thẳng vào hàng đợi của Manager trực tiếp; capacity tuần còn lại được giải phóng tự động để không "khóa" utilization nhóm.
- **Correction sau khi giờ đã allocate vào P&L:** correction được xác nhận tạo bút toán điều chỉnh cho kỳ tiếp theo — không sửa bản ghi cost đã hạch toán; audit log giữ cả hai phiên bản để đối soát với FIN.
- **Tuần có ngày lễ:** capacity khả dụng giảm tương ứng số ngày lễ theo `work_schedule`; ngưỡng vàng/đỏ tính trên capacity khả dụng đã giảm, không phải 40h cố định.
- **Nghỉ ốm đột xuất trong tuần đã có giờ được gán:** khi đơn nghỉ (REQ-HR-004) được duyệt retro kèm lý do, assignment đang treo phải chạy lại capacity check và các dòng timesheet tương ứng tự chuyển nhãn Internal theo quy tắc nghỉ đã duyệt.
- **Sai lệch khung giờ làm việc giữa các nguồn:** `03_Quy_che_KPI_HR.md` §8 ghi sáng 08h30–12h00, chiều 13h00–17h30, trong khi một số JD ghi 08h00–17h30 (nghỉ trưa 12h00–13h30) — điểm cần làm rõ số 2 của tài liệu nguồn; hệ thống cấu hình `work_schedule` thành một tham số duy nhất, giá trị mặc định theo §8 Welcome Deck và thay đổi khi chủ dự án xác nhận giờ chuẩn `[KXN]`.
- **Nhu cầu duyệt trên mobile:** REQ-HR-009 ghi chú need "duyệt trên mobile" nhưng A7.2 (hr.md) xác nhận ngoài scope SYS-MOBILE-INTERNAL hiện tại `[KXN]` — bản WEB giữ nguyên hàng đợi duyệt trên browser responsive; mở scope mobile sẽ qua `/wf-add-scope`.
- **Nhân sự mới tuần đầu:** 100% giờ Internal Non-billable và không áp ngưỡng billable mục tiêu trong báo cáo tháng đầu.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** TimesheetEntry (dòng timesheet tuần/nhân viên/dự án) — trạng thái lưu và validate ở CORE, WEB chỉ hiển thị machine-state.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(chốt tuần trước 12:00 thứ Hai)──► [SUBMITTED] ──(TL duyệt ≤48h)──► [APPROVED] ──(job allocate × Cost Rate Card)──► [ALLOCATED]
                                                 │                              │
                                                 │ (từ chối — bắt buộc lý do)    │ (yêu cầu correction — bản gốc giữ nguyên)
                                                 ▼                              ▼
                                             [REJECTED]                    [CORRECTION_PENDING] ──(TL xác nhận ≤24h)──► [APPROVED]
                                                 │
                                                 │ (sửa nội dung + nộp lại)
                                                 └──────────────────────────► [SUBMITTED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Chốt tuần | `SUBMITTED` | Người ghi | Chốt trước 12:00 thứ Hai tuần kế; đủ nhãn billable từng dòng |
| `SUBMITTED` | Duyệt | `APPROVED` | TL (Manager L4 với timesheet của TL) | Approver ≠ người ghi (BR-001); trong SLA 48h |
| `SUBMITTED` | Từ chối | `REJECTED` | TL | Bắt buộc nhập lý do từ chối |
| `REJECTED` | Sửa + nộp lại | `SUBMITTED` | Người ghi | Sửa qua dòng mới/correction — bản gốc không đổi |
| `APPROVED` | Allocate cost | `ALLOCATED` | Hệ thống (job CORE) | Chỉ chạy trên `APPROVED`; nhân Cost Rate Card hiệu lực theo ngày ghi giờ (REQ-HR-006) |
| `APPROVED` | Yêu cầu correction | `CORRECTION_PENDING` | Người ghi | Bắt buộc lý do; audit log; TL xác nhận trong 24h |
| `CORRECTION_PENDING` | Xác nhận correction | `APPROVED` | TL | Chênh lệch giờ/nhãn ghi bút toán điều chỉnh kỳ sau |

**Quy tắc:**
- `ALLOCATED` là trạng thái kết thúc cho kỳ hạch toán — mọi chỉnh sửa sau đó chỉ qua correction tạo bút toán mới, không quay lại `APPROVED` của bản gốc.
- Giờ ở trạng thái `DRAFT/SUBMITTED/REJECTED/CORRECTION_PENDING` không bao giờ được allocate vào P&L (BR-002).
- OT trong tuần phải duyệt trước khi thực hiện (retro 24h exception) — OT chưa duyệt hiển thị trạng thái riêng và không cộng vào giờ `APPROVED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `timesheet_entry` | `id`, `user_id`, `project_id`, `week_key`, `work_date`, `hours`, `billing_label`, `status`, `approver_id`, `approved_at` | FK → `users.id`, `projects.id` | `billing_label` không sửa được sau ghi; audit log bất biến |
| `timesheet_correction` | `entry_id`, `old_values`, `new_values`, `reason`, `requested_by`, `confirmed_by`, `confirmed_at` | FK → `timesheet_entry.id` | Giữ bản gốc; TL xác nhận 24h |
| `approval_queue` | `week_key`, `submitter_id`, `approver_id`, `sla_deadline`, `escalation_level`, `status` | FK → `users.id` | Job SLA 48h/72h; escalation ghi level |
| `ot_request` | `user_id`, `week_key`, `hours`, `kind` (trước/retro), `approver_role`, `status`, `reason` | FK → `users.id` | Trần 8h/tuần, 200h/năm; HR_L2 duyệt vượt trần 24h |
| `capacity_policy_version` | `level`, `standard_hours`, `max_logged_hours`, `billable_target_min/max`, `effective_from`, `approved_by` | FK → `bod_approval` | HR_L2 đề xuất → BOD duyệt chu kỳ năm; effective-dated |
| `capacity_week` (derived) | `user_id`, `week_key`, `available_capacity`, `assigned_hours`, `utilization_percent`, `band` | FK → `users.id` | Tính ở CORE; WEB chỉ đọc |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn tự duyệt | TL có timesheet do chính mình ghi trong hàng đợi | TL bấm duyệt / gọi API duyệt | Hệ thống từ chối (UI ẩn nút, API 403), ghi audit log | [ ] |
| SC-002: Giờ chưa duyệt không vào P&L | Tuần vừa chốt, TL chưa duyệt | Chạy job allocate cuối kỳ | Không dòng nào được nhân Rate Card; báo cáo cost hiển thị trạng thái "chờ duyệt" riêng | [ ] |
| SC-003: SLA duyệt và escalation | Timesheet SUBMITTED quá 48h | Job SLA chạy | Nhắc TL; quá 72h tự escalate Manager kèm log escalation_level | [ ] |
| SC-004: OT vượt trần | Nhân viên có 8h OT duyệt trong tuần | Đăng ký thêm OT | Bắt buộc route HR_L2 duyệt 24h; vượt 48h/tuần bị chặn cứng | [ ] |
| SC-005: Escalation capacity 8h | Capacity check quá 8h chưa xác nhận | Job escalation chạy | Thông báo tới HR_L2 kèm dữ liệu đầu người; HR_L2 có thể khởi tạo requisition | [ ] |
| SC-006: Định mức effective-dated | BOD đã duyệt policy năm mới | Hệ thống qua ngày effective_from | Mọi tính toán capacity/billable dùng version mới; version cũ chỉ áp cho dữ liệu lịch sử | [ ] |

> **Liên kết:** SC-001/002/003 map REQ-HR-009; SC-004/005 map REQ-HR-009 + B9 (hr.md); SC-006 map REQ-HR-009 (định mức) và policy `timesheet-capacity.md` §2.1.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (gate giờ-approved→P&L, handoff REQ-HR-004/REQ-OPS-007) |
| Màn hình UI | `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md` |
| Policy nguồn | `phase0-brainstorm/policies/timesheet-capacity.md` §2.4–2.6, §4 |
| Domain knowledge HR | `documents/03_Quy_che_KPI_HR.md` §8 (nội quy giờ làm việc/nghỉ phép) |
