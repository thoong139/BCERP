# Tính Năng: Capacity & Timesheet (Ghi Nhận và Capacity Engine — Góc OPS)

> **Dựa trên:** REQ-OPS-007 trong `phase1-business/departments/operations/operations.md` (Phần A3, Phần B.8 — BR-OPS-8.1/8.2/8.3/8.4); policy `timesheet-capacity.md` §2.1–2.6; phối hợp REQ-HR-009 trong `phase1-business/departments/hr/hr.md` (Phần B.9 — chính sách duyệt từ HR)
> **Phân hệ:** Vận hành — Quản lý năng lực đội OPS và ghi nhận giờ làm việc (SYS-CORE-BACKEND)
> **Module:** Capacity & Timesheet (MOD-CAPACITY-TIMESHEET)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/hr/hr.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 3 B3, Luồng 4 B2), `policies/timesheet-capacity.md`, `documents/03_Quy_che_KPI_HR.md` (§8 nội quy)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/capacity-timesheet/[screen-group].md`, `phase5-implementation/tasks/core-backend/capacity-timesheet/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-OPS-007 fan-out ra 3 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-CAPTS-002); counterparts: SYS-BCERP-WEB (nhập timesheet, duyệt, dashboard nhóm) và SYS-MOBILE-INTERNAL (ghi nhanh cuối ngày, TL duyệt trên di động, push cảnh báo). Cross-dependency: REQ-HR-009 — chính sách duyệt timesheet, định mức và escalation thuộc HR (FEAT-CORE-CAPTS-001 trên chính hệ thống này). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CAPTS-002 |
| Module | MOD-CAPACITY-TIMESHEET (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-007 (Capacity & Timesheet); cross-dependency REQ-HR-009 (chính sách duyệt timesheet từ HR) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (actor chính — ghi giờ, TL/OPS_PLAN duyệt lần 1 và duyệt gán vùng vàng); HR_L2 (định mức, escalation 8h, OT vượt trần); FIN_L1, FIN_L2 (nhận giờ đã duyệt cho P&L); BOD_CEO, BOD_CFO_CTO (duyệt định mức năm, duyệt khẩn cấp vượt mốc); SYS_ADMIN (hạ tầng, không có quyền nghiệp vụ) |
| Độ ưu tiên | Cao (HIGH · Phase 2 · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Dự án + WBS + project type (REQ-OPS-005/006) để validate cặp project type × nhãn; hồ sơ nhân sự + Level (REQ-HR-001); CapacityPolicy effective-dated từ FEAT-CORE-CAPTS-001 (REQ-HR-009); đơn nghỉ đã duyệt (REQ-HR-004) trừ capacity |
| Ghi chú Expert (A7) | Mục A7 trong `operations.md` đang "chờ đánh giá" — chưa có điều chỉnh chính thức; ghi chú ranh giới đã khai báo: REQ-OPS-007 cần đối chiếu chéo ranh giới HR (thẩm quyền định mức + duyệt thuộc HR_L2/BOD, OPS chỉ sử dụng). Vai đã gán lại sau DI-006 (không có OPS_CX) trong danh sách actor của lane |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Feature này là **capacity engine và dịch vụ ghi nhận timesheet của đội OPS** trên core backend, hiện thực hóa triết lý "không ghi nhận = không tồn tại": mọi giờ làm việc của OPS được ghi hằng ngày với **nhãn Client Billable / Internal Non-billable bắt buộc tại nguồn**, và mọi quyết định gán việc đều qua **capacity check với ngưỡng vàng 90% / đỏ 100%** chặn ngay tại tầng API. Engine cung cấp ảnh utilization trung thực theo tuần cho TL ra quyết định gán việc, đồng thời phát dòng "giờ đã duyệt" duy nhất cho allocate chi phí P&L của FIN.

**Phạm vi:**
- Bao gồm: API ghi timesheet hằng ngày (nhãn bắt buộc tại nguồn, không chọn không lưu; validation cặp project type × nhãn; cấm sửa nhãn sau ghi — correction qua audit log, TL xác nhận 24h); chốt tuần 12:00 thứ Hai và đẩy vào hàng đợi duyệt 48h của TL (cấm tự duyệt); capacity utilization tính tự động theo tuần (nghỉ đã duyệt không tính vào mẫu số); ngưỡng <70% cảnh báo TL, >90% vàng dừng gán tự động (TL duyệt), ≥100% đỏ chặn cứng; capacity check bắt buộc trước mọi gán task và tại Gate 2 (SLA 4h → TL, 8h → HR_L2); khẩn cấp khách tối đa 110% trong ≤5 ngày làm việc liên tục có log; OT trong trần 8h/tuần duyệt trước, chặn tổng >48h; expose API cho WEB và M-INT (ghi nhanh, push cảnh báo ghi chậm/quá tải).
- Không bao gồm: hàng đợi duyệt, SLA duyệt 48h/72h, gate "giờ chưa duyệt không vào P&L" và vòng đời định mức (FEAT-CORE-CAPTS-001 — REQ-HR-009); màn hình nhập/duyệt/dashboard (SYS-BCERP-WEB) và app mobile ghi nhanh (SYS-MOBILE-INTERNAL — counterpart tiêu thụ cùng API); tính lương OT theo hệ số pháp luật (REQ-HR-003); allocate cost P&L chi tiết (DEPT-FINANCE).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản spec này là **core backend headless**: OPS ghi giờ và nhận việc qua WEB nội bộ hoặc M-INT, nhưng mọi ràng buộc (nhãn bắt buộc, ngưỡng vàng/đỏ, cặp project type × nhãn) đều được service layer kiểm tra lại trên từng request — client hiển thị chứ không quyết định. Luồng phản ánh đúng ranh giới REQ-OPS-007 ↔ REQ-HR-009: OPS ghi nhận và duyệt lần 1, chính sách thuộc HR.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM (và CONT/DES/EDIT/ADS) | Gọi API ghi timesheet hằng ngày với nhãn Client Billable / Internal Non-billable bắt buộc tại thời điểm ghi — từ WEB hoặc ghi nhanh trên mobile | Dữ liệu billable đúng từ nguồn, không có cơ hội ghi xong rồi sửa nhãn theo tiện lợi |
| 2 | OPS_AM | Bị chặn lưu ngay khi không chọn nhãn hoặc ghi giờ nội bộ vào dự án khách (và ngược lại) | Lỗi bị chặn tại giây phút phát sinh thay vì correction qua nhiều tầng sau |
| 3 | OPS_AM | Tạo correction khi ghi sai, kèm lý do — bản gốc giữ nguyên, TL xác nhận 24h | Sửa sai minh bạch có dấu vết, không đụng dữ liệu đã ghi |
| 4 | OPS_PLAN (TL) | Xem dashboard nhóm qua API: ai chưa ghi, ghi chậm quá 3 ngày, utilization từng người theo tuần | Can thiệp sớm trước khi giờ thiếu hoặc quá tải thành rủi ro SLA và KPI |
| 5 | OPS_PLAN | Mọi gán task chạy capacity check; vùng vàng >90% gán mới phải tôi duyệt, vùng đỏ ≥100% chặn cứng | Đội không bị nạp quá tải — chỉ nhận việc khi còn capacity thật |
| 6 | OPS_AM | Khi khách khẩn cấp (die account ngoài giờ), đề xuất gán vượt tối đa 110% trong ≤5 ngày làm việc liên tục, có log lý do | Xử lý sự cố khách ngay mà vẫn để lại dấu vết kiểm soát |
| 7 | OPS_PLAN | Duyệt OT trong trần 8h/tuần trước khi thực hiện; hệ thống tự chặn tổng tuần vượt 48h | OT nằm trong khung pháp luật, không phát sinh OT "ngầm" |
| 8 | OPS_PLAN | Khi capacity check quá 8h không xử lý được, tự escalate HR_L2 cân đối đầu người | Thiếu người được giải ở nguồn (tuyển/thay người) thay vì dồn việc vô hạn |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Tất cả rule enforce tại tầng service/capacity engine của core backend; counterpart WEB/M-INT chỉ gọi API và hiển thị kết quả; audit log append-only + hash-chain; tenant isolation trên mọi endpoint.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Nhãn billable bắt buộc tại nguồn:** mỗi dòng timesheet gắn nhãn Client Billable / Internal Non-billable ngay tại thời điểm ghi — không chọn không lưu được; nhãn là dữ liệu cấp dòng, không suy diễn từ project. Nguồn: BR-OPS-8.1; `timesheet-capacity.md` §2.4 (2). | API từ chối "THIEU_NHAN_BILLABLE"; không có chế độ "điền nhãn sau" |
| BR-002 | **Cấm sửa nhãn/giờ sau khi ghi:** sai sót xử lý bằng correction — bản gốc bất biến, kèm lý do, TL xác nhận 24h; audit log bắt buộc (ai, khi nào, sửa gì, lý do). Nguồn: BR-OPS-8.1; REQ-OPS-007 A3. | Endpoint "sửa dòng giờ" không tồn tại; correction chưa xác nhận không đổi dữ liệu tính cost |
| BR-003 | **Validation cặp project type × nhãn:** cấm ghi giờ nội bộ vào dự án khách với nhãn Client Billable và ngược lại (khớp BR-OPS-7.1 — campaign không gắn dự án = không tồn tại). Exception: dự án nội bộ phục vụ trực tiếp 1 khách (VD case study có approval khách) — AM đề xuất, TL duyệt chuyển một phần giờ thành Client Billable, có log. Nguồn: BR-OPS-8.1; `operations.md` B.7 ngoại lệ. | Ghi sai cặp chặn "SAI_CAP_PROJECT_NHAN"; chuyển nhãn exception phải có phê duyệt TL + log |
| BR-004 | **Nhịp ghi và cảnh báo ghi chậm:** ghi hằng ngày, chậm nhất trước 12:00 hôm sau; chậm quá 3 ngày → cảnh báo TL (dashboard ghi chậm + push M-INT). Nguồn: BR-OPS-8.1; `timesheet-capacity.md` §2.4 (1). | Trễ tính vào báo cáo kỷ luật ghi timesheet TL theo dõi; dữ liệu vẫn nhận nhưng có dấu trễ |
| BR-005 | **Chốt tuần + duyệt lần 1 góc OPS:** chốt trước 12:00 thứ Hai tuần kế; TL duyệt 48h theo chính sách HR (REQ-HR-009 — FEAT-CORE-CAPTS-001); **cấm tự duyệt** — approver ≠ người ghi; timesheet của TL (OPS_PLAN) do Manager L4 duyệt `[CẦN CHỐT SỐ: người duyệt timesheet cấp TL/OPS_PLAN — SO3-09 nhóm D]`. Nguồn: BR-OPS-8.2; REQ-OPS-007 ranh giới thẩm quyền. | Tự duyệt chặn "CAM_TU_DUYET" tại service; SLA duyệt/escalate theo FEAT-CORE-CAPTS-001 |
| BR-006 | **Utilization tuần tính tự động:** Utilization = tổng giờ đã gán ÷ capacity khả dụng; capacity khả dụng = 40h chuẩn − giờ nghỉ phép/ốm đã duyệt trong tuần; tuần lễ giảm tương ứng; **nghỉ đã duyệt không chiếm capacity, không tính vào utilization**. Nguồn: `timesheet-capacity.md` §2.1, §3; P1-02 B2. | Công thức tính phía server từ assignment + nghỉ đã duyệt — client không gửi mẫu số |
| BR-007 | **Ngưỡng vàng/đỏ chặn gán vượt:** <70% cảnh báo TL (rủi ro cạn việc); 70–90% nhận gán tự do; **>90% (vàng) dừng gán tự động — gán mới phải TL phê duyệt** (trong SLA 4h); **≥100% (đỏ) chặn cứng** — buộc dịch deadline, đổi người hoặc duyệt OT. Nguồn: BR-OPS-8.3; `timesheet-capacity.md` §2.2; REQ-OPS-007 A3. | Gán vùng đỏ từ chối "CAPACITY_DO"; gán vàng thiếu duyệt treo ở `PENDING_APPROVAL` |
| BR-008 | **Capacity check bắt buộc trước mọi gán task và tại Gate 2:** không đường gán nào bỏ qua check (API, job, bulk); SLA 4h — quá 4h escalate TL, quá 8h escalate **HR_L2 cân đối đầu người** (mở requisition REQ-HR-001 nếu thiếu người); "xác nhận capacity trống" là prerequisite của Gate 2. Nguồn: BR-OPS-8.3; `timesheet-capacity.md` §2.3; P1-02 Luồng 3 B3. | Gán không qua check không thể tạo; quá SLA tự escalate + log 4h/8h |
| BR-009 | **Ngoại lệ khẩn cấp khách có trần:** sự cố khẩn cấp (VD die account ngoài giờ) cho phép vượt tối đa **110% trong ≤5 ngày làm việc liên tục**, bắt buộc log lý do; vượt mốc (110% hoặc 5 ngày) phải BOD duyệt. Nguồn: BR-OPS-8.3; `timesheet-capacity.md` §3. | Gán khẩn thứ 6 liên tục hoặc >110% chặn "VUOT_TRAN_KHAN_CAP" chờ BOD |
| BR-010 | **Định mức là cấu hình HR, OPS chỉ sử dụng:** 40h chuẩn/tuần mọi Level, trần ghi nhận 48h gồm OT, billable mục tiêu L1 ≥80%, L2 ≥75%, L3 60–70%, L4 40–50%, L5 20–30% — số gốc từ policy, không phải con số OPS tự đặt; điều chỉnh thuộc **HR_L2 đề xuất → BOD duyệt (chu kỳ năm)**, effective-dated; OPS không có endpoint sửa (RBAC — không thấy nút sửa ở mọi kênh). Nguồn: BR-OPS-8.2/8.4; REQ-HR-009; `timesheet-capacity.md` §2.1/§4. | API sửa định mức bằng vai OPS → từ chối "VUOT_RANH_GIOI" + log; engine lookup phiên hiệu lực theo ngày ghi giờ |
| BR-011 | **OT trong khung pháp luật:** OT duyệt trước khi thực hiện, trần 8h OT/tuần do TL duyệt (retro 24h chỉ cho sự cố khẩn cấp, kèm lý do); tổng chuẩn + OT chặn cứng >48h/tuần (Điều 107 BLLĐ 2019); trần năm 200h — OT vượt trần/retro do HR_L2 duyệt 24h (phễu duyệt chi tiết thuộc REQ-HR-009). Nguồn: BR-OPS-8.4; `timesheet-capacity.md` §2.5. | Ghi nhận vượt 48h/tuần chặn "OT_VUOT_48H"; OT chưa duyệt không ghi vào dòng giờ dự án |
| BR-012 | **Nhóm đặc biệt:** nhân sự mới tuần đầu 100% Internal Non-billable, không áp ngưỡng billable; L5/BOD ghi theo dự án, không bắt buộc chi tiết task; BOD ghi theo mục tiêu quản trị. Nguồn: BR-OPS-8.1 exception; `timesheet-capacity.md` §1/§3. | Nhân sự mới ghi nhãn billable tuần đầu → cảnh báo lệch quy tắc onboarding; L5/BOD không bị ép chi tiết task |
| BR-013 | **Giờ chưa duyệt không vào P&L (đầu ra của engine):** chỉ giờ `approved` bàn giao FIN để nhân Cost Rate Card (REQ-HR-006) — gate thuộc FEAT-CORE-CAPTS-001 nhưng dữ liệu ghi nhận phải mang trạng thái chính xác từng dòng; báo cáo billable thực tế theo tháng gửi HR_L2 đối chiếu mục tiêu theo bậc. Nguồn: BR-OPS-8.2/8.4; P1-02 Luồng 9. | Trạng thái dòng giờ không khớp chuỗi duyệt → job P&L loại khỏi allocate và báo lệch dữ liệu |
| BR-014 | **Audit bất biến + tenant isolation + đa kênh có kiểm soát:** mọi event (ghi, correction, gán, duyệt gán vàng, khẩn cấp, OT) ghi append-only + hash-chain; endpoint scope cứng theo tenant; M-INT dùng chung API ghi nhanh + TL duyệt gán vàng/OT trên di động (kênh đã khai báo trong REQ-OPS-007), WEB là kênh nhập chính — không có kênh duyệt nào ngoài danh sách này. Nguồn: BR-OPS-8.1/8.3 "Hệ thống"; Notes lane touchpoint. | Request sai kênh/tenant → từ chối + audit log bảo mật; đứt hash → alert BOD_CEO |

---

## 4. Phân Quyền

> Quyền enforce bằng vai tại tầng API core backend (role re-check mỗi request); counterpart WEB/M-INT chỉ phản chiếu kết quả tra quyền — không tạo quyền riêng ở tầng UI.

| Hành động | OPS staff (AM/CONT/DES/EDIT/ADS) | OPS_PLAN (TL) | HR_L1 / HR_L2 | FIN_L1 / FIN_L2 | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN |
|-----------|----------------------------------|---------------|----------------|-----------------|------------------------|-----------|
| Ghi timesheet hằng ngày (nhãn bắt buộc) | ✅ | ✅ | ✅ (của mình) | ❌ | ⚠️ (theo dự án, không ép chi tiết task) | ❌ |
| Tạo correction (có lý do) | ✅ | ✅ | ✅ (của mình) | ❌ | ❌ | ❌ |
| Xác nhận correction (24h) | ❌ | ✅ (phòng mình) | ❌ | ❌ | ❌ | ❌ |
| Xem timesheet/ghi chậm của nhóm | ❌ | ✅ | ✅ (dashboard toàn công ty) | ❌ (chỉ trạng thái duyệt) | ✅ (tổng hợp) | ❌ |
| Gán task (qua capacity check) | ❌ | ✅ (vùng xanh) | ❌ | ❌ | ❌ | ❌ |
| Duyệt gán vùng vàng >90% (SLA 4h) | ❌ | ✅ (duy nhất) | ❌ | ❌ | ❌ | ❌ |
| Gán khi đỏ ≥100% (bypass chặn cứng) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ dịch deadline / đổi người / duyệt OT) |
| Đề xuất gán khẩn cấp ≤110% ≤5 ngày (log) | ✅ | ✅ (phê duyệt) | ❌ | ❌ | ✅ (duyệt vượt mốc) | ❌ |
| Duyệt OT trong trần 8h/tuần | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt OT vượt trần / retro (24h) | ❌ | ❌ | ✅ (HR_L2) | ❌ | ❌ | ❌ |
| Sửa định mức giờ/billable theo bậc | ❌ | ❌ | ✅ (HR_L2 đề xuất) — BOD duyệt | ❌ | ✅ (phê duyệt) | ❌ (OPS và SYS_ADMIN không có endpoint) |
| Nhận giờ `approved` cho P&L | ❌ | ❌ | ❌ | ✅ (đọc gate) | ❌ | ❌ |
| Xem audit log ghi/correction/gán | ❌ | ✅ (phòng mình — đọc) | ✅ | ✅ (đọc) | ✅ | ✅ (đọc — xem log cũng bị log) |
| Xóa/sửa audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |

> Ghi chú touchpoint: portal khách (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL) không có quyền nào trên timesheet/capacity nội bộ; M-INT chỉ ghi nhanh, chốt và duyệt gán vàng/OT trong trần cho TL theo REQ-OPS-007 đã khai báo. Mọi quyền thực thi tại service layer của core backend.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý — mọi xử lý qua service layer, có log, không sửa tay trên dữ liệu.*

- **Nhân sự mới tuần đầu (onboarding):** 100% Internal Non-billable, không áp ngưỡng billable mục tiêu khi đối chiếu theo bậc — engine đánh dấu giai đoạn onboarding để loại khỏi cảnh báo lệch billable, tránh méo KPI tháng đầu.
- **L5/BOD ghi giờ theo dự án:** không bắt buộc chi tiết task — engine nhận dòng giờ cấp dự án nhưng vẫn bắt nhãn billable và vẫn chiếm capacity; không có chế độ "miễn ghi".
- **Khẩn cấp kéo dài quá mốc:** ngày thứ 6 liên tục hoặc vượt 110% — engine chặn gán mới, chỉ mở khi BOD duyệt; khi sự cố kết thúc, utilization trở về tính bình thường từ tuần kế, không "xóa nợ" retro trong 5 ngày đã dùng.
- **Nghỉ phép/ốm đã duyệt phát sinh giữa tuần:** capacity khả dụng giảm tự động (nối REQ-HR-004); các gán đang mở của người nghỉ phải đưa lại qua capacity check khi quay lại — không tự giữ nguyên gán cũ.
- **Dự án nội bộ phục vụ trực tiếp 1 khách (case study có approval khách):** một phần giờ chuyển thành Client Billable sau AM đề xuất + TL duyệt, có log — luồng exception duy nhất cho phép "đổi nhãn" và phải qua correction, không sửa nhãn trực tiếp.
- **Gán hàng loạt (bulk) khi setup dự án:** bulk vẫn chạy capacity check từng dòng; dòng đẩy lên vùng vàng cần duyệt TL, vùng đỏ bị từ chối trong kết quả (partial success có báo cáo) — không có "duyệt trọn gói bỏ qua ngưỡng".
- **Hai phễu duyệt song song của TL:** duyệt gán vàng SLA 4h và duyệt timesheet 48h độc lập nhưng dùng chung rule cấm tự duyệt và chung escalation Manager/HR_L2; bận phễu này không gia hạn phễu kia.
- **Giờ chuẩn nội quy có sai lệch nguồn (§8):** `work_schedule` giữ mặc định Welcome Deck (08h30–17h30, trưa 12h00–13h00) và đánh dấu chờ xác nhận `[KXN]` — việc tính OT/giờ hạn chót dựa trên tham số, không hardcode.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh gán việc (`Assignment`) — đơn vị capacity engine quản trạng thái; dòng timesheet (`TimesheetEntry`) có chuỗi trạng thái ghi nhận riêng và kế thừa phễu duyệt tuần từ FEAT-CORE-CAPTS-001.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(capacity check: xanh 70–90%)──► [ASSIGNED]
   │  │
   │  └─(vàng >90%)──► [PENDING_APPROVAL] ──(TL duyệt ≤SLA 4h)──► [ASSIGNED]
   │                          │
   │                          │ (TL từ chối / quá SLA escalate)
   │                          ▼
   │                     [REJECTED]
   │
   └─(đỏ ≥100%)──► chặn tạo — không có entity (buộc dịch deadline / đổi người / duyệt OT)
[ASSIGNED] ──(khẩn cấp đã log ≤110% ≤5 ngày)──► [ASSIGNED] (tag OVERRIDE_LOGGED)
[ASSIGNED] ──(hủy gán có lý do)──► [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Tạo gán (check vùng xanh 70–90%) | `ASSIGNED` | OPS_PLAN | Check pass tự động; có project/task/assignee hợp lệ |
| `DRAFT` | Tạo gán (vùng vàng >90%) | `PENDING_APPROVAL` | OPS_PLAN (đề xuất) | Ghi nhận vượt ngưỡng; chờ TL duyệt trong SLA 4h |
| `PENDING_APPROVAL` | Duyệt gán vàng | `ASSIGNED` | OPS_PLAN (TL) | SLA 4h; quá 4h escalate TL, quá 8h HR_L2 (BR-008) |
| `PENDING_APPROVAL` | Từ chối gán | `REJECTED` | OPS_PLAN | Lý do bắt buộc; đề xuất chọn dịch deadline/đổi người |
| `DRAFT` | Tạo gán khi đỏ ≥100% | (bị chặn) | — | Chặn cứng "CAPACITY_DO" — buộc dịch deadline, đổi người hoặc duyệt OT trước khi tạo lại |
| `ASSIGNED` | Tag khẩn cấp | `ASSIGNED` (OVERRIDE_LOGGED) | OPS staff đề xuất + TL duyệt | ≤110% và ≤5 ngày LV liên tục, log lý do; vượt mốc → BOD duyệt (BR-009) |
| `ASSIGNED` | Hủy gán | `CANCELLED` | OPS_PLAN | Lý do bắt buộc; capacity hoàn trả tức thì cho check sau |

**Quy tắc:**
- Không tồn tại đường tạo `ASSIGNED` không qua capacity check — mọi API/job/bulk đều qua engine (BR-008).
- `REJECTED` và `CANCELLED` kết thúc lệnh gán — gán lại tạo lệnh mới và check lại theo utilization hiện thời, không tái sử dụng kết quả check cũ.
- Dòng timesheet: `RECORDED` (đã ghi có nhãn) → `LOCKED` (chốt tuần) → `APPROVED` (phễu duyệt FEAT-CORE-CAPTS-001) → chỉ `APPROVED` vào allocate cost; correction tạo bản ghi con, không đổi bản gốc.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; entity đề xuất đối chiếu mô hình TMS tại `documents/03_Quy_che_KPI_HR.md` §9 trước khi vào schema chính thức.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `TimesheetEntry` | `user_id`, `project_id`, `task_id`, `work_date`, `hours`, `billable_label` (`CLIENT_BILLABLE/INTERNAL_NON_BILLABLE`), `state` (`RECORDED/LOCKED/APPROVED`) | FK → `users`, `projects`, `tasks` | Nhãn bắt buộc tại nguồn; cấm sửa sau ghi — chỉ correction |
| `TimesheetCorrection` | `entry_id`, `old_values`, `new_values`, `reason`, `requested_by`, `confirmed_by/at` (TL) | FK → `timesheet_entries` | Bản gốc bất biến; TL xác nhận 24h |
| `Assignment` | `project_id`, `task_id`, `assignee_id`, `estimated_hours`, `state` (`DRAFT/ASSIGNED/PENDING_APPROVAL/REJECTED/CANCELLED`), `override_flag` | FK → `projects`, `tasks`, `users` | Capacity check bắt buộc trước khi `ASSIGNED` |
| `CapacityCheckLog` | `assignment_id`, `week_start`, `utilization_before`, `zone` (`LOW/GREEN/YELLOW/RED`), `result` (`PASS/PENDING/BLOCKED`), `checked_at` | FK → `assignments` | Kết quả check không tái sử dụng; log mọi lần check |
| `CapacitySnapshot` (tuần) | `user_id`, `week_start`, `standard_hours` (40), `leave_deducted`, `available_capacity`, `assigned_hours`, `utilization` | FK → `users` | Tính server-side; nghỉ đã duyệt trừ khỏi mẫu số; tuần lễ giảm |
| `OvertimeRequest` | `user_id`, `week_start`, `hours`, `type` (`TRONG_TRAN/VUOT_TRAN/RETRO`), `approved_by` (TL/HR_L2), `reason` | FK → `users` | Trần 8h/tuần, 48h tổng, 200h/năm |
| `CapacityPolicy` (đọc) | `level`, `standard_hours`, `cap_hours`, `billable_target`, `effective_from/to`, `approved_by` (BOD) | FK → `career_levels` | Quản bởi FEAT-CORE-CAPTS-001 — engine chỉ lookup theo ngày |
| `WorkSchedule` (tham số) | `morning_start` (08:30), `lunch_start/end`, `evening_end` (17:30), `holiday_calendar` | — | Giờ chuẩn chờ xác nhận `[KXN — 03 §9 điểm 2]`; không hardcode |
| `AuditLog` | `actor_id`, `role`, `action`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only + hash-chain; không có interface xóa/sửa |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-007 (`operations.md` A3/B.8 — BR-OPS-8.1 đến 8.4) và policy `timesheet-capacity.md` §2–§3.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Nhãn billable bắt buộc tại nguồn (REQ-OPS-007) | Người dùng tạo dòng giờ chưa chọn nhãn | Gọi API lưu | Từ chối "THIEU_NHAN_BILLABLE"; không có lưu nháp không nhãn từ bất kỳ kênh nào | [ ] |
| SC-002: Cấm sửa nhãn sau ghi (REQ-OPS-007) | Dòng giờ đã `RECORDED` | Gọi API sửa trực tiếp nhãn/hours | Endpoint không tồn tại; buộc correction có lý do; bản gốc bất biến; TL xác nhận 24h | [ ] |
| SC-003: Chặn cặp project type × nhãn (REQ-OPS-007) | Dự án khách (Client Billable) | Ghi giờ nội bộ với nhãn Client Billable | Chặn "SAI_CAP_PROJECT_NHAN"; exception case study chỉ qua AM đề xuất + TL duyệt + log | [ ] |
| SC-004: Vàng >90% dừng gán tự động (REQ-OPS-007) | Utilization người nhận = 92% | OPS_PLAN tạo gán mới | Gán vào `PENDING_APPROVAL`; chỉ `ASSIGNED` khi TL duyệt trong SLA 4h; quá hạn escalate | [ ] |
| SC-005: Đỏ ≥100% chặn cứng (REQ-OPS-007) | Utilization người nhận = 100% | OPS_PLAN tạo gán mới (kể cả bulk) | Chặn "CAPACITY_DO" ở tầng API; phải dịch deadline / đổi người / duyệt OT | [ ] |
| SC-006: Khẩn cấp 110% ≤5 ngày có log (REQ-OPS-007) | Sự cố die account ngoài giờ | Tạo gán khẩn cấp tag OVERRIDE_LOGGED | Nhận được ở ≤110% và ≤5 ngày LV liên tục với log lý do; ngày thứ 6 hoặc >110% chặn chờ BOD | [ ] |
| SC-007: Nghỉ đã duyệt không tính utilization (REQ-OPS-007 × REQ-HR-004) | Nhân sự nghỉ 2 ngày đã duyệt trong tuần 40h | Hệ thống tính utilization tuần | Capacity khả dụng = 24h; mẫu số không gồm ngày nghỉ; cảnh báo vàng/đỏ tính trên capacity mới | [ ] |
| SC-008: OT chặn cứng >48h/tuần (REQ-OPS-007) | Tổng chuẩn + OT đã duyệt = 47h | Ghi thêm 2h OT | Chặn "OT_VUOT_48H" (Điều 107 BLLĐ 2019); OT trong trần 8h cần duyệt TL trước, vượt trần cần HR_L2 24h | [ ] |
| SC-009: Nhân sự mới tuần đầu (REQ-OPS-007) | Nhân sự mới trong tuần onboarding đầu | Ghi 100% Internal Non-billable | Hợp lệ; không sinh cảnh báo lệch billable mục tiêu; từ tuần 2 áp ngưỡng bình thường | [ ] |
| SC-010: OPS không sửa được định mức (REQ-OPS-007 × REQ-HR-009) | OPS_PLAN đăng nhập | Gọi API đổi billable target của L2 | Từ chối "VUOT_RANH_GIOI" + audit log; chỉ HR_L2 đề xuất, BOD duyệt tạo phiên effective-dated | [ ] |
| SC-011: Ghi chậm cảnh báo TL (REQ-OPS-007) | Nhân sự chưa ghi giờ quá 3 ngày | Job quét hằng ngày chạy | Cảnh báo TL qua dashboard + push M-INT; dữ liệu trễ vẫn nhận khi ghi bổ sung nhưng có dấu trễ | [ ] |
| SC-012: Tenant isolation (Notes lane) | Tenant A (khách A) | OPS tenant A truy vấn timesheet/capacity tenant B | Từ chối ở tầng API + audit log bảo mật; không lộ dữ liệu nội bộ qua portal | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (capacity check cho Luồng 3 B3 + Gate 2; trạng thái giờ cho Luồng 9 P&L; event cảnh báo cho WEB/M-INT) |
| Màn hình UI (WEB — nhập timesheet, duyệt, dashboard nhóm) | `phase4-ux/bcerp-web/capacity-timesheet/[screen-group].md` |
| Domain model nguồn | `documents/03_Quy_che_KPI_HR.md` (§8 giờ làm việc/nghỉ phép; §9 đề xuất entity TMS) |
| Policy nghiệp vụ | `policies/timesheet-capacity.md` §1–§5 (định mức, ngưỡng, OT, yêu cầu hệ thống MUST) |
| Feature liên quan cùng module | `duyet-timesheet-va-capacity-phoi-hop-ops.md` (FEAT-CORE-CAPTS-001 — phễu duyệt, gate P&L, vòng đời định mức trên cùng core backend) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 3 B3 gán task qua capacity check; Luồng 4 B2 ghi timesheet) |
