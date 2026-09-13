# Tính Năng: Capacity & Timesheet (Mobile Nội Bộ)

> **Dựa trên:** REQ-OPS-007 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục A3/B.8)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** Capacity & Timesheet (MOD-CAPACITY-TIMESHEET)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/hr/hr.md` (ranh giới REQ-HR-009 — HR chưa khai báo M-INT), `phase1-business/P1-02-business-workflow.md` (Luồng 4), `documents/03_Quy_che_KPI_HR.md` (§8 — nội quy giờ làm việc/nghỉ phép/chấm công)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/capacity-timesheet/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/capacity-timesheet/feat-mbi-capts-001-impl.md`
>
> **Fan-out:** REQ-OPS-007 xuất hiện ở 3 systems (SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL) — đây là bản riêng cho SYS-MOBILE-INTERNAL (touchpoint di động: ghi nhanh cuối ngày, TL duyệt trên di động, chấm công cho staff, push cảnh báo ghi chậm/quá tải); counterparts: SYS-CORE-BACKEND (capacity engine + validation + gate P&L) và SYS-BCERP-WEB (nhập timesheet chi tiết, duyệt, dashboard nhóm). Mọi business rule enforce ở service layer của CORE; M-INT là client React Native offline-capable — kết quả capacity check và trạng thái duyệt luôn đọc từ server, không tự quyết trên thiết bị.
>
> **Hướng dẫn ID:** FEAT-MBI-CAPTS-001 là ID lane cấp cho REQ-OPS-007 trên module MOD-CAPACITY-TIMESHEET, hệ thống SYS-MOBILE-INTERNAL (tra `req-registry.json` để xác nhận).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CAPTS-001 |
| Module | MOD-CAPACITY-TIMESHEET |
| Yêu cầu nghiệp vụ | REQ-OPS-007 — Capacity & Timesheet |
| Người dùng liên quan | OPS_PLAN (TL — duyệt on-the-go, duyệt gán vùng vàng), OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (ghi nhanh, chấm công); HR_L2 (thẩm quyền định mức — ranh giới, không thao tác trên M-INT); BOD_CEO (duyệt khẩn cấp vượt mốc) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-CAPTS-002 (bản WEB cùng REQ — form nhập chi tiết, dashboard nhóm); REQ-OPS-006 (project type khóa tập nhãn timesheet); REQ-HR-009 (chính sách duyệt timesheet từ HR — nguồn sự thật quy tắc duyệt thuộc HR, OPS ghi nhận và duyệt lần 1) |
| Ghi chú Expert (A7) | A7 của `operations.md` đang chờ Team Expert review, nhưng ranh giới REQ-OPS-007 đã khai báo rõ: engine chặn gán ở CORE, ghi + duyệt trên WEB và M-INT, thẩm quyền điều chỉnh định mức thuộc HR_L2 đề xuất → BOD duyệt — OPS chỉ sử dụng. Đồng thời `hr.md` ghi chú SYS-MOBILE-INTERNAL hiện không khai báo HR: duyệt phép/timesheet/OT **góc HR** trên di động ngoài scope hiện tại — spec này chỉ đưa luồng duyệt góc OPS (TL duyệt lần 1) lên mobile, không xây màn hình duyệt cho HR_L2. |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Điểm chạm di động (React Native, offline-capable) của REQ-OPS-007 cho nhân sự OPS ra ngoài văn phòng: **ghi nhanh timesheet cuối ngày** (nhãn Client Billable / Internal Non-billable bắt buộc tại nguồn), **chấm công cho staff theo nội quy §8**, nhận **push cảnh báo** ghi chậm/quá tải, và cho TL **duyệt on-the-go** (timesheet nhóm, gán vùng vàng, OT trong trần). Mobile là kênh ghi nhanh + duyệt nhanh, không thay thế WEB; mọi validation, capacity check và gate "giờ chưa duyệt không vào P&L" vẫn chạy ở CORE.

**Phạm vi:**
- Bao gồm:
  - Form ghi nhanh timesheet cuối ngày: chọn dự án/task, nhập giờ, chọn nhãn billable trước khi lưu; hoạt động offline — ghi vào hàng đợi cục bộ và tự đồng bộ khi có mạng (server-side validation tại thời điểm sync).
  - Chấm công mobile cho staff: check-in/check-out theo khung giờ nội quy `03_Quy_che_KPI_HR.md` §8 (sáng 08h30–12h00, chiều 13h00–17h30), dữ liệu đối chiếu với attendance của HR (REQ-HR-003).
  - Đăng ký nghỉ phép/công tác từ mobile theo quy định thông báo trước của §8 (½ ngày tới ≥4 ngày) — đơn đi vào workflow duyệt của REQ-HR-004 trên WEB/CORE, mobile chỉ là điểm tạo đơn.
  - Hàng đợi duyệt trên di động cho TL/OPS_PLAN: duyệt timesheet nhóm (SLA 48h), duyệt gán vùng vàng (>90%), duyệt OT trong trần 8h/tuần, xác nhận correction (24h) — với cơ chế cấm tự duyệt.
  - Push notification: nhắc ghi timesheet (chậm 3 ngày cảnh báo TL), nhắc chốt tuần trước 12:00 thứ Hai, cảnh báo duyệt sắp quá hạn, cảnh báo quá tải/nhận gán vùng vàng.
  - Xem dashboard rút gọn: utilization cá nhân và nhóm theo băng màu (<70% / 70–90% / vàng >90% / đỏ ≥100%), danh sách ghi chậm, trạng thái tuần đang mở.
- Không bao gồm:
  - Capacity engine tính utilization, chặn gán vùng đỏ, escalate 4h/8h — thực thi ở SYS-CORE-BACKEND; mobile chỉ hiển thị kết quả do server trả về.
  - Nhập timesheet chi tiết theo WBS nhiều dòng, dashboard phân tích nhóm đầy đủ — touchpoint chính là SYS-BCERP-WEB (FEAT-ERP-CAPTS-002).
  - Quy tắc duyệt, định mức giờ/tuần, tỷ lệ billable mục tiêu, duyệt OT vượt trần/retro — thẩm quyền DEPT-HR (REQ-HR-009); HR_L2 không có màn hình thao tác trên M-INT trong scope hiện tại.
  - Quy đổi giờ đã duyệt thành chi phí P&L — đầu vào của DEPT-FINANCE qua gate CORE.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Ghi nhanh giờ làm cuối ngày ngay trên điện thoại (kể cả khi không có mạng) | Dữ liệu không bị quên hay bịa lại cuối tuần; nhãn billable chốt đúng tại nguồn |
| 2 | OPS_CONT | Check-in/check-out trên mobile theo khung giờ nội quy §8 | Công của tôi được ghi nhận đúng ngay cả khi làm việc tại khách hoặc di chuyển |
| 3 | OPS_DES | Nhận push nhắc khi tôi quên ghi timesheet 3 ngày hoặc sắp tới hạn chốt tuần | Không để dòng giờ nào rơi ra ngoài, tránh cảnh báo TL |
| 4 | OPS_EDIT | Đăng ký nghỉ phép/công tác từ điện thoại với mức thông báo trước đúng quy định | Đơn vào luồng duyệt ngay cả khi tôi chưa thể ngồi máy tính |
| 5 | OPS_PLAN (TL) | Duyệt timesheet của nhóm trên di động trong 48h ngay cả khi đang họp/ra ngoài | Tuần của nhóm không bị trễ duyệt, giờ sớm vào được P&L |
| 6 | OPS_PLAN (TL) | Nhận và duyệt gán vùng vàng (>90%) trên điện thoại trong SLA 4h của capacity check | Việc gán không bị treo chờ tôi quay lại văn phòng |
| 7 | OPS_ADS | Đăng ký OT và được TL duyệt trước khi làm ngay trên mobile | Giờ làm thêm hợp lệ theo nội quy, không phải chờ đợi thủ công |
| 8 | OPS_PLAN (TL) | Xác nhận correction do nhân viên tạo ngay trên di động trong 24h | Sai sót dữ liệu được xử lý nhanh mà bản gốc vẫn bất biến |
| 9 | OPS_EDIT | Xem utilization của chính mình theo băng màu trước khi nhận việc mới | Tôi chủ động báo TL trước khi bị chặn ở vùng đỏ |
| 10 | OPS_PLAN (TL) | Nhận cảnh báo escalate khi duyệt quá 72h hoặc capacity check quá 4h/8h | Không để đơn trôi vì tôi không mở app |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Validation cứng và capacity engine nằm ở service layer CORE; M-INT bắt buộc phản ánh kết quả server, không tự chặn/duyệt cục bộ. Nguồn: `operations.md` B.8 (BR-OPS-8.1–8.4), `hr.md` REQ-HR-009, `documents/03_Quy_che_KPI_HR.md` §8.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Nhãn billable bắt buộc tại nguồn, kể cả ghi nhanh:** mỗi dòng timesheet tạo từ mobile phải chọn nhãn Client Billable / Internal Non-billable trước khi lưu vào hàng đợi offline; nhãn hợp lệ khóa theo project type (REQ-OPS-006) — danh sách project/nhãn tải về cùng bộ form offline. | Bản ghi thiếu nhãn không được phép vào hàng đợi sync; lúc sync server từ chối và bản ghi quay lại trạng thái cần sửa kèm thông báo |
| BR-002 | **Cấm sửa nhãn/giờ sau khi ghi:** mobile không có chức năng sửa dòng đã sync; sai sót tạo correction kèm lý do — bản gốc giữ nguyên, audit log bất biến, TL xác nhận trong 24h (có thể xác nhận trên mobile). | Màn hình chi tiết dòng đã sync chỉ hiện nút "Tạo correction"; thao tác sửa trực tiếp không tồn tại ở cả UI lẫn API |
| BR-003 | **Cấm tự duyệt:** approver bắt buộc khác người ghi (validation CORE); timesheet của TL (OPS_PLAN) do Manager L4 duyệt; delegate quyền duyệt của TL `[KXN]` — chưa chốt (DI-006/SO3-09 nhóm D), không xây tính năng delegate trên mobile. | Nút duyệt ẩn với chính người ghi; API duyệt chính mình trả 403 + audit log; không có UI hẹn ủy quyền duyệt |
| BR-004 | **Giờ chưa duyệt không vào P&L** — chỉ giờ `APPROVED` được nhân Cost Rate Card để allocate chi phí (gate CORE); mobile hiển thị rõ trạng thái chờ duyệt của từng dòng/tuần. | Màn hình của người dùng phân tách "chờ duyệt"/"đã duyệt"; không có con số chi phí nào hiển thị từ giờ chưa duyệt |
| BR-005 | **Capacity theo băng màu, server quyết:** utilization tuần = giờ đã gán ÷ capacity khả dụng — <70% cảnh báo TL (dưới tải); 70–90% xanh nhận gán tự do; **vàng >90% dừng gán tự động — gán mới phải TL phê duyệt trên hàng đợi mobile/WEB; đỏ ≥100% chặn cứng gán vượt** — buộc dịch deadline, đổi người hoặc duyệt OT. Mobile chỉ hiển thị băng màu và hàng đợi duyệt. | Mọi API gán từ mobile đi qua capacity engine CORE; kết quả BLOCKED hiển thị kèm gợi ý xử lý; client không có chế độ ghi đè cục bộ |
| BR-006 | **Khẩn cấp khách có log:** tối đa 110% trong ≤5 ngày làm việc liên tục, bắt buộc nhập lý do khi tạo từ mobile; quá mốc phải BOD duyệt. Nghỉ phép/ốm đã duyệt không chiếm capacity và không tính utilization. | Log khẩn cấp thiếu lý do không gửi được; gán vượt 110% hoặc quá 5 ngày bị server chặn chờ phê duyệt BOD |
| BR-007 | **Chấm công mobile theo nội quy §8:** khung giờ sáng 08h30–12h00, chiều 13h00–17h30, nghỉ trưa 12h00–13h00, ngày làm việc không tính T7/CN/lễ; chế tài đi muộn/về sớm, quên chấm công, nghỉ không phép áp theo bảng §8 (nhân x2 với cấp quản lý). Hệ thống dùng một tham số `work_schedule` duy nhất, mặc định theo §8 — lệch giờ với một số JD chờ xác nhận `[KXN]`. | Check-in ngoài khung vẫn ghi nhận nhưng gắn cờ để áp chế tài; cấu hình giờ chỉ sửa được ở tham số trung tâm, không phải trên thiết bị |
| BR-008 | **Đăng ký nghỉ/công tác từ mobile đúng mức thông báo trước của §8:** nghỉ buổi ½ ngày báo trước ½ ngày; 1–dưới 3 ngày ≥1 ngày; ≥3 ngày ≥4 ngày; công tác trước 2 tiếng — phê duyệt theo phân cấp REQ-HR-004 (≤5 ngày TL duyệt 24h; >5 ngày/không lương HR_L2 duyệt 48h) trên WEB/CORE; nghỉ hết phép chỉ duyệt riêng cho bất khả kháng có chứng minh. | Đơn thiếu mức thông báo trước bị cảnh báo ngay khi soạn; duyệt chỉ xảy ra ở server theo REQ-HR-004 — mobile không có nút duyệt nghỉ phép cho vai OPS |
| BR-009 | **OT:** duyệt trước khi thực hiện — TL duyệt trên mobile trong trần 8h/tuần (tổng chuẩn + OT ≤48h/tuần, Điều 107 BLLĐ 2019); retro 24h chỉ cho sự cố khẩn cấp; OT vượt trần/retro do HR_L2 duyệt — không có màn hình HR_L2 trên M-INT, các đơn này chuyển sang hàng đợi HR của REQ-HR-009. | Đăng ký OT vượt trần từ mobile được tạo nhưng trạng thái "chờ HR_L2"; TL không thể tự duyệt vượt trần trên di động |
| BR-010 | **Nhịp ghi và chốt tuần:** ghi hằng ngày, chậm nhất trước 12:00 hôm sau; chậm quá 3 ngày → push cảnh báo người ghi + TL; chốt tuần trước 12:00 thứ Hai tuần kế; TL duyệt trong 48h, quá 72h escalate Manager (thông báo đẩy tới cấp trên). | App hiển thị badge ghi chậm; quá hạn chốt, bản ghi offline không thể gắn vào tuần đã khóa — phải tạo ở tuần sau kèm ghi chú |
| BR-011 | **Phối hợp duyệt HR/OPS — nguồn sự thật quy tắc thuộc HR:** quy trình duyệt, định mức giờ/tuần, tỷ lệ billable mục tiêu (L1 ≥80%, L2 ≥75%, L3 60–70%, L4 40–50%, L5 20–30%), OT vượt trần/retro do HR_L2 đề xuất → BOD duyệt (chu kỳ năm); OPS ghi nhận giờ và duyệt lần 1 trong 48h; cấu hình định mức không xuất hiện trên mobile. | Mobile không có màn hình sửa định mức; gọi API sửa từ client bị RBAC từ chối và ghi log |
| BR-012 | **Offline-first nhưng không offline-authoritative:** bản ghi tạo offline vào hàng đợi cục bộ kèm dấu thời gian tạo; khi sync, server tái validation toàn bộ (nhãn, tuần mở, trần 48h, cặp project type × nhãn); xung đột giải theo nguyên tắc append-only, không ghi đè dữ liệu server; mọi quyết định duyệt/capacity chỉ khi online. | Sync bị từ chối một phần không làm mất bản ghi trên thiết bị — quay lại hàng đợi "cần hành động" kèm lý do |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry — các vai đã bị gỡ khỏi registry (quyết định stakeholder 12/09/2026, DI-006) không xuất hiện. TL trong luồng duyệt là vai vận hành của OPS_PLAN; người duyệt timesheet cấp TL/OPS_PLAN (Manager L4) hiện không có chuyên trách `[KXN]` — chờ chốt tổ chức. HR_L1/HR_L2 không có màn hình thao tác timesheet trên M-INT trong scope hiện tại (`hr.md`: SYS-MOBILE-INTERNAL chưa khai báo HR); CUSTOMER không dùng app nội bộ này.

| Hành động | OPS_AM/CONT/DES/EDIT/ADS | OPS_PLAN (TL) | HR_L1 | HR_L2 | BOD_CEO | SYS_ADMIN |
|-----------|--------------------------|---------------|-------|-------|---------|-----------|
| Ghi nhanh timesheet của mình (kèm nhãn) | ✅ | ✅ | ❌ | ❌ | ❌ (L5/BOD ghi theo dự án trên WEB) | ❌ |
| Chấm công check-in/check-out của mình | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo đơn nghỉ phép/công tác của mình | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt đơn nghỉ phép | ❌ | ❌ (theo REQ-HR-004 duyệt trên WEB/CORE) | ❌ (WEB/CORE) | ❌ (WEB/CORE) | ❌ | ❌ |
| Tạo yêu cầu correction | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận correction của nhóm (24h) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt timesheet nhóm trên mobile (48h) | ❌ | ✅ (khác người ghi) | ❌ | ❌ | ❌ | ❌ |
| Duyệt gán vùng vàng (>90%) trên mobile | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt OT trong trần 8h/tuần trên mobile | ❌ | ✅ (trước khi thực hiện) | ❌ | ❌ (vượt trần/retro → hàng đợi WEB/CORE) | ❌ | ❌ |
| Tạo log khẩn cấp vượt 110% | ✅ (đề xuất kèm lý do) | ✅ | ❌ | ❌ | ✅ (duyệt vượt mốc — trên WEB) | ❌ |
| Xem dashboard rút gọn (băng màu, ghi chậm) | ✅ (chỉ của mình) | ✅ (nhóm mình) | ❌ | ❌ (xem qua WEB) | ❌ (xem qua WEB) | ❌ |
| Sửa nhãn/giờ sau khi ghi | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Sửa định mức giờ/tuần, tỷ lệ billable mục tiêu | ❌ | ❌ | ❌ | ❌ (đề xuất trên WEB/CORE) | ❌ (duyệt trên WEB/CORE) | ❌ |

**Ghi chú:** SYS_ADMIN không có quyền nghiệp vụ trên dữ liệu timesheet/capacity — chỉ truy cập kỹ thuật có audit log. Quyền duyệt trên mobile của OPS_PLAN giới hạn trong nhóm mình phụ trách (row-level scoping ở CORE); người dùng bị ẩn cả nút bấm và API call khi không đúng vai.

---

## 5. Trường Hợp Đặc Biệt

- **Mất mạng khi ghi cuối ngày tại khách:** app lưu bản ghi vào hàng đợi cục bộ với dấu thời gian tạo; khi có mạng, sync chạy nền và server tái validation (BR-012) — người dùng thấy rõ trạng thái "chờ sync / đã ghi nhận / bị từ chối kèm lý do", không bị mất giờ vì mạng yếu.
- **Die account khẩn cấp ngoài giờ (OPS_ADS):** TL nhận push cảnh báo quá tải, tạo log khẩn cấp từ mobile cho phép vượt tới 110% trong ≤5 ngày làm việc liên tục kèm lý do; quá mốc buộc trình BOD duyệt trên WEB — mobile chỉ hỗ trợ tạo log, không duyệt vượt mốc.
- **Nghỉ ốm đột xuất giữa tuần:** đơn nghỉ tạo từ mobile, khi được duyệt (theo REQ-HR-004) capacity khả dụng tự tăng lại và các assignment treo chạy lại capacity check ở CORE — băng màu trên mobile cập nhật ở lần sync kế.
- **Duyệt muộn do TL nghỉ dài:** delegate quyền duyệt của TL chưa chốt `[KXN]` — trong thời gian chờ, escalate tự động (48h duyệt timesheet → 72h escalate Manager) là cơ chế chống trôi duyệt; không xây màn hình hẹn ủy quyền trên mobile.
- **Nhân sự mới (tuần đầu onboarding):** toàn bộ giờ mặc định Internal Non-billable, không so ngưỡng billable; form ghi nhanh trên mobile hiển thị nhãn mặc định khóa cho tuần đầu.
- **Quên chấm công:** theo §8 — 2 lần đầu/tháng có xác nhận của HCNS thì vẫn tính công, không áp chế tài; từ lần thứ 3 không tính công buổi/ngày đó. Mobile chấm công bổ sung cho kênh vân tay: khi hai nguồn lệch nhau, bản ghi attendance điều chỉnh phải qua luồng duyệt của REQ-HR-003, mobile không tự ghi đè công.
- **Làm đa múi giờ với khách:** ghi timesheet theo giờ làm việc Việt Nam (mốc ngày/tuần tính theo múi giờ VN) dù nhân sự đang ở nước ngoài — app không cho đổi mốc tuần theo thiết bị.
- **Duyệt on-the-go nhưng cần context đầy đủ:** màn hình duyệt mobile rút gọn (người ghi, tuần, tổng giờ, nhãn, cảnh báo); cần chi tiết WBS/dashboard đầy đủ thì deep-link sang WEB — mọi lượt duyệt dù trên mobile hay WEB đều đi qua validation CORE `[KXN-9]` (phạm vi "tương lai" TMS/mobile chờ chốt, không tự quyết).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** TimesheetEntry (dòng timesheet) — trạng thái lưu/validate ở CORE; mobile hiển thị machine-state và khóa thao tác theo trạng thái. Riêng trên mobile có thêm trạng thái client-side `QUEUED_OFFLINE` (chưa sync) không phải trạng thái nghiệp vụ.

**Sơ đồ trạng thái (TimesheetEntry):**
```
[QUEUED_OFFLINE (client)] ──(sync)──► [LOGGED] ──(chốt tuần trước 12:00 T2)──► [SUBMITTED]
                                                                           │
                                              ┌─(TL duyệt ≤48h — mobile/WEB)─┴─(từ chối, lý do bắt buộc)─┐
                                              ▼                                                          ▼
                                          [APPROVED] ──(job allocate × Rate Card ở CORE)──► [ALLOCATED]  [REJECTED]
                                              │
                                              │ (correction — bản gốc giữ nguyên)
                                              ▼
                                     [CORRECTION_PENDING] ──(TL xác nhận ≤24h — mobile/WEB)──► [APPROVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED_OFFLINE` (client) | Sync online | `LOGGED` | Hệ thống (app) | Server validation pass: đủ nhãn, tuần còn mở, đúng cặp project type × nhãn, trong trần 48h |
| `QUEUED_OFFLINE` (client) | Sync bị từ chối | `QUEUED_OFFLINE` (kèm lý do) | Hệ thống (app) | Bản ghi giữ nguyên trên thiết bị; người dùng sửa theo lý do rồi sync lại |
| `LOGGED` | Chốt tuần | `SUBMITTED` | Người ghi | Trước 12:00 thứ Hai tuần kế |
| `SUBMITTED` | Duyệt | `APPROVED` | OPS_PLAN (TL — khác người ghi), qua mobile hoặc WEB | Trong SLA 48h; quá 72h escalate Manager |
| `SUBMITTED` | Từ chối | `REJECTED` | OPS_PLAN (TL) | Bắt buộc lý do từ chối |
| `APPROVED` | Tạo correction | `CORRECTION_PENDING` | Người ghi | Kèm lý do; bản gốc bất biến |
| `CORRECTION_PENDING` | Xác nhận correction | `APPROVED` | OPS_PLAN (TL) | Trong 24h; audit log ghi đủ ai/khi nào/sửa gì/lý do |

**Quy tắc:**
- `QUEUED_OFFLINE` chỉ tồn tại trên thiết bị — server không bao giờ thấy trạng thái này; mọi truy vấn từ WEB/BI chỉ nhìn thấy trạng thái nghiệp vụ.
- `ALLOCATED` và `REJECTED` là trạng thái kết thúc; `REJECTED` sửa lại bằng cách tạo dòng/correction mới, không mở lại dòng cũ.
- Dòng không bao giờ nhảy cóc trạng thái; chỉ giờ đã `APPROVED`/`ALLOCATED` được tính vào P&L (BR-004).

---

## 7. Tóm Tắt Entity (Quick Reference)

> Entity dùng chung với bản CORE/WEB (FEAT-ERP-CAPTS-002); mobile chỉ đọc/ghi qua API — không có schema cục bộ ngoài bảng hàng đợi sync.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `timesheet_entry` | `id`, `user_id`, `project_id`, `task_id`, `week_key`, `work_date`, `hours`, `billing_label`, `status` | FK → `users.id`, `projects.id`, `tasks.id` | Nhãn không sửa sau ghi; audit log bất biến; mobile tạo qua sync queue |
| `timesheet_correction` | `entry_id`, `old_values`, `new_values`, `reason`, `requested_by`, `confirmed_by`, `confirmed_at` | FK → `timesheet_entry.id` | TL xác nhận 24h — xác nhận được từ mobile |
| `assignment` | `id`, `task_id`, `assignee_id`, `requested_by`, `capacity_check_result`, `band`, `status`, `override_log_id` | FK → `tasks.id`, `users.id` | Duyệt vùng vàng được từ mobile; chặn đỏ ở CORE |
| `capacity_week` (derived) | `user_id`, `week_key`, `standard_hours`, `leave_hours_approved`, `available_capacity`, `assigned_hours`, `utilization_percent`, `band` | FK → `users.id` | Tính ở CORE; mobile đọc để render băng màu |
| `emergency_override_log` | `user_id`, `week_key`, `reason`, `utilization_percent`, `consecutive_days`, `approved_by`, `expires_at` | FK → `users.id` | Trần 110% ≤5 ngày LV; quá mốc BOD duyệt (WEB) |
| `ot_request` | `user_id`, `week_key`, `hours`, `kind` (pre/retro), `status`, `approver_role` | FK → `users.id` | TL duyệt mobile trong trần 8h/tuần; vượt trần route HR (WEB/CORE) |
| `attendance_record` | `user_id`, `check_in_at`, `check_out_at`, `source` (mobile/fingerprint), `flag_late`, `adjusted_by` | FK → `users.id` | Nguồn mobile đối chiếu vân tay; điều chỉnh theo REQ-HR-003 |
| `sync_queue` (client-only) | `local_id`, `payload`, `created_at_device`, `sync_status`, `server_error` | Bảng cục bộ trên thiết bị | Không phải entity server; append-only, xóa sau khi sync thành công |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Ghi nhanh offline | App mất mạng, người dùng ở ngoài văn phòng | Người dùng ghi dòng timesheet đủ nhãn | Bản ghi vào hàng đợi cục bộ; khi có mạng tự sync và chuyển `LOGGED` với dấu thời gian tạo gốc | [ ] |
| SC-002: Thiếu nhãn không ghi được | Form ghi nhanh mở | Người dùng bấm lưu khi chưa chọn nhãn | Nút lưu vô hiệu; bản ghi không vào hàng đợi | [ ] |
| SC-003: Duyệt on-the-go trong SLA | Tuần của nhóm đã SUBMITTED, TL đang ngoài văn phòng | TL duyệt từ mobile trong 48h | Dòng chuyển `APPROVED`; không thể duyệt dòng của chính mình (403 + audit log) | [ ] |
| SC-004: Duyệt gán vùng vàng từ điện thoại | Người nhận có utilization >90% | Gán mới phát sinh, TL duyệt trên mobile trong SLA 4h | Assignment `PENDING_TL` → `ASSIGNED`; quá 8h escalate HR_L2 hiển thị trên luồng WEB | [ ] |
| SC-005: Chặn đỏ hiển thị đúng | Người nhận ≥100% | AM gán task từ app | Server trả BLOCKED; app hiển thị gợi ý dịch deadline/đổi người/duyệt OT, không có tùy chọn ghi đè | [ ] |
| SC-006: Chấm công ngoài khung | Ngoài giờ nội quy §8 | Người dùng check-in | Bản ghi nhận kèm cờ trễ để áp chế tài §8; mốc ngày tính theo giờ VN | [ ] |
| SC-007: Sync bị từ chối một phần | Hàng đợi có bản ghi vào tuần đã khóa | Sync chạy | Bản ghi lỗi giữ lại với lý do rõ; các bản hợp lệ vẫn sync thành công | [ ] |
| SC-008: Push nhắc ghi chậm | Người dùng không ghi 3 ngày | Job kiểm tra chạy | Push tới người dùng + cảnh báo tới TL; badge ghi chậm trên dashboard rút gọn | [ ] |

> **Liên kết:** SC-001/002/007/008 map REQ-OPS-007 (B.8 — BR-OPS-8.1/8.2); SC-003/004/005 map REQ-OPS-007 (BR-OPS-8.3/8.4) và REQ-HR-009 (cấm tự duyệt, escalation); SC-006 map `03_Quy_che_KPI_HR.md` §8.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (kèm hợp đồng sync offline cho M-INT) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (capacity engine CORE, handoff WEB, gate P&L FIN, đối chiếu attendance HR) |
| Màn hình UI | `phase4-ux/mobile-internal/capacity-timesheet/[screen-group].md` |
| Policy nguồn | `timesheet-capacity.md` §2.1–2.6 (40h chuẩn, trần 48h, billable mục tiêu theo Level) |
| Domain knowledge HR | `documents/03_Quy_che_KPI_HR.md` §8 (giờ làm việc, nghỉ phép, chế tài, chấm công) |
| Counterparts cùng REQ | `phase2-features/bcerp-web/capacity-timesheet/capacity-va-timesheet.md`, `phase2-features/core-backend/capacity-timesheet/` (khi có) |
