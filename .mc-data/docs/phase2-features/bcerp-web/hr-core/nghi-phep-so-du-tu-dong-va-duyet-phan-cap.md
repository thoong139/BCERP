# Tính Năng: Nghỉ phép: số dư tự động & duyệt phân cấp

> **Dựa trên:** REQ-HR-004 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-004 → FEAT-ERP-HRCORE-004. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (validation số dư + routing phân cấp ở service layer) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-004 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-004 — Nghỉ phép: số dư tự động & duyệt phân cấp (HIGH, MVP) |
| Người dùng liên quan | Nhân viên nội bộ (mọi vai registry — lập đơn), TL (duyệt ≤5 ngày), HR_L2 (duyệt >5 ngày/nghỉ không lương), HR_L1 (xử lý bổ sung giấy tờ), OPS (thấy capacity khả dụng giảm) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-ERP-HRCORE-001 (hồ sơ SSOT — ngày vào công gốc, TL trực tiếp, trạng thái nhân sự); nối luồng REQ-HR-009 (nghỉ đã duyệt tự trừ capacity tuần) |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) ghi nhận need duyệt phép trên mobile ngoài scope SYS-MOBILE-INTERNAL hiện tại — duyệt chỉ trên web; quy tắc cộng dồn phép năm chưa chốt `[CẦN CHỐT SỐ]` (đề xuất Điều 113 BLLĐ 2019: tối đa 3 tháng) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng quản lý vòng đời đơn nghỉ phép của BC Agency trên web nội bộ: tích lũy phép năm tự động 12 ngày/năm (1 ngày/tháng), hiển thị số dư hiện hành tại thời điểm lập đơn, và duyệt phân cấp tự động theo độ dài kỳ nghỉ (≤5 ngày TL duyệt 24h; >5 ngày hoặc nghỉ không lương HR_L2 duyệt 48h). Hệ thống chặn duyệt vượt số dư ở tầng validation và khi đơn được duyệt sẽ tự trừ số dư, đồng thời tự giảm capacity tuần để DEPT-OPS phân việc — không thông báo tay.

**Phạm vi:**
- Bao gồm: web form lập đơn nghỉ (loại nghỉ, từ–đến, lý do, đính kèm giấy tờ) với số dư hiện hành hiển thị trực tiếp, lịch nghỉ của nhóm để tránh trùng, hàng đợi duyệt của TL và HR_L2 kèm SLA đếm ngược và nhắc/escalate.
- Bao gồm: tích lũy tự động và bảng số dư theo loại nghỉ (phép năm, nghỉ ốm, nghỉ không lương, thai sản... theo BLLĐ 2019), không nhập tay số dư.
- Bao gồm: validation và routing phân cấp: chặn duyệt vượt số dư (UI không có nút duyệt khi không đủ số dư, core chặn lại khi gọi API); route ≤5 ngày → TL 24h, >5 ngày hoặc nghỉ không lương → HR_L2 48h; quá SLA nhắc rồi escalate cấp trên.
- Bao gồm: hiệu ứng sau duyệt — trừ số dư, tự giảm capacity tuần của nhân sự (luồng REQ-HR-009), cập nhật công tự động (nối FEAT-ERP-HRCORE-003); hiển thị nội quy nghỉ phép + chế tài xử phạt theo `documents/03_Quy_che_KPI_HR.md` §8.
- Không bao gồm: validation số dư và routing — chạy ở service layer SYS-CORE-BACKEND; web chỉ hiển thị kết quả validation và trạng thái machine-state.
- Không bao gồm: tính lương kỳ nghỉ (payroll DEPT-FINANCE), KPI prorate/miễn chi tiết (module KPI-PERFORMANCE — chỉ ghi nhận xác nhận HR_L2), và quản lý capacity/gán việc (module CAPACITY-TIMESHEET).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; mọi bước duyệt ghi người duyệt, thời điểm, lý do vào audit log bất biến ở core.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên nội bộ | Lập đơn nghỉ trên web với số dư hiện hành và lịch nhóm hiển thị sẵn | Chọn thời điểm nghỉ hợp lệ, không đụng độ kỳ nghỉ của đồng đội |
| 2 | Nhân viên nội bộ | Đính kèm giấy khám bệnh khi nghỉ ốm ≥3 ngày | Đơn đủ chứng từ, không bị trả lại vì thiếu hồ sơ |
| 3 | TL | Duyệt đơn ≤5 ngày của nhân sự nhóm trong 24h trên hàng đợi có SLA đếm ngược | Nghỉ ngắn không bị treo, quá hạn có nhắc tự động |
| 4 | HR_L2 | Duyệt đơn >5 ngày hoặc nghỉ không lương trong 48h | Kỳ nghỉ dài ảnh hưởng capacity/KPI được cấp HR soát trước khi chốt |
| 5 | Nhân viên nội bộ | Xem số dư còn lại và lịch sử nghỉ của mình mọi lúc | Chủ động kế hoạch nghỉ, biết đơn nào đang chờ/đã duyệt |
| 6 | OPS (Planner/AM) | Thấy capacity khả dụng của nhân sự giảm tự động khi đơn nghỉ được duyệt | Phân việc không đụng ngày nghỉ đã duyệt, không cần hỏi tay HR |
| 7 | HR_L1 | Theo dõi đơn treo thiếu chứng từ (ốm ≥3 ngày) và đôn đốc bổ sung | Không có đơn duyệt xong mà thiếu giấy tờ hợp lệ |
| 8 | HR_L2 | Xem báo cáo nghỉ theo phòng/tháng (tỷ lệ nghỉ, nghỉ không phép theo §8, nghỉ đột xuất retro) | Phát hiện xu hướng bất thường và vận dụng chế tài nội quy đúng mốc |

Quy ước xuyên suốt: chặn vượt số dư thực thi ở tầng validation — khi số dư không đủ, nút duyệt không xuất hiện và API từ chối; không có đường "duyệt trước, trừ sau".

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Validation số dư và routing chạy ở service layer SYS-CORE-BACKEND; web phản chiếu đúng trạng thái.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: ngày vào công gốc, TL trực tiếp, trạng thái nhân sự và loại nghỉ khả dụng đọc từ hồ sơ (FEAT-ERP-HRCORE-001); nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track). | Lập đơn cho profile không hợp lệ/ngưng hoạt động bị từ chối; loại nghỉ không áp dụng cho trạng thái hiện tại bị khóa |
| BR-002 | Tích lũy phép năm tự động 12 ngày/năm (1 ngày/tháng vào ngày vào công gốc), hiển thị số dư hiện hành; không ai nhập tay số dư — điều chỉnh chỉ bằng bản ghi hiệu chỉnh có phê duyệt HR_L2 kèm lý do. | Số dư lệch tích lũy là lỗi dữ liệu; nhập tay trực tiếp bị chặn, phải qua bản ghi hiệu chỉnh có vết |
| BR-003 | Đề nghị nghỉ trước ≥3 ngày làm việc (đơn đột xuất đi luồng retro có lý do); nội quy `03_Quy_che_KPI_HR.md` §8 quy định thông báo trước theo khoảng nghỉ (nghỉ buổi Sáng/Chiều ≥½ ngày; 1–dưới 3 ngày ≥1 ngày; từ 3 ngày trở lên ≥4 ngày; ngày làm việc không tính T7/CN/Lễ Tết) — hệ thống cấu hình ngưỡng theo policy, khi 2 nguồn lệch nhau áp mức nghiêm ngặt hơn làm mặc định, chốt cuối thuộc HR_L2 `[CẦN CHỐT SỐ]`. | Đơn gửi sát ngày không đủ ngưỡng bị cảnh báo trước khi gửi; luồng retro yêu cầu lý do bắt buộc |
| BR-004 | Duyệt phân cấp tự động: ≤5 ngày → TL duyệt 24h; >5 ngày hoặc nghỉ không lương → HR_L2 duyệt 48h; quá SLA nhắc người duyệt, tiếp tục quá → escalate cấp trên (TL → Manager; HR_L2 → BOD). | Đơn không treo vô hạn — mỗi quá SLA sinh thông báo escalate; duyệt sai cấp bị core từ chối theo routing |
| BR-005 | Chặn duyệt vượt số dư ở tầng validation (web không hiển thị nút duyệt, core chặn API); riêng §8: nghỉ hết phép không được duyệt đơn xin nghỉ riêng trừ bất khả kháng (ốm đau có chứng minh, gia đình có tang sự) — luồng bất khả kháng do HR_L2 duyệt và không trừ số dư phép năm. | Yêu cầu duyệt vượt số dư bị từ chối kèm thông báo số dư; luồng bất khả kháng thiếu chứng minh bị trả lại |
| BR-006 | Nghỉ ốm ≥3 ngày bắt buộc đính kèm giấy khám bệnh; các loại nghỉ khác theo BLLĐ 2019; thai sản/ốm dài: KPI prorate/miễn theo xác nhận HR_L2 (thực thi ở module KPI). | Đơn ốm ≥3 ngày thiếu giấy khám không được chuyển trạng thái duyệt; xác nhận prorate thiếu HR_L2 bị từ chối |
| BR-007 | Đơn được duyệt tự trừ số dư và tự giảm capacity tuần (luồng REQ-HR-009 — DEPT-OPS thấy capacity khả dụng giảm, không thông báo tay); đồng thời cập nhật chấm công theo loại nghỉ (nối FEAT-ERP-HRCORE-003). | Ngày nghỉ đã duyệt vẫn bị gán việc/capacity là lỗi đồng bộ; capacity không giảm làm lệch phân công — discrepancy bắt buộc xử lý |
| BR-008 | Nội quy + chế tài theo §8: nghỉ không phép ≥2 lần (buổi/ngày)/tháng → cảnh cáo–đình chỉ; nghỉ không phép ≥5 ngày/tháng → căn cứ chấm dứt HĐLĐ; hệ thống đếm tần suất nghỉ không phép và gắn nhãn lên hồ sơ làm căn cứ pháp lý. | Đếm sai tần suất là lỗi tính toán; đề xuất chấm dứt HĐ theo §8 thiếu hồ sơ vi phạm gắn kèm bị chặn luồng (nối FEAT-ERP-HRCORE-002) |
| BR-009 | Cost Rate Card version hóa do HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt, billable ghi nhận tại nguồn: ngày nghỉ đã duyệt tự loại khỏi giờ billable khả dụng trong timesheet, không cần gỡ tay. | Gán việc billable vào ngày nghỉ đã duyệt bị cảnh báo chặn; capacity billable hiển thị sai là lỗi đồng bộ hồ sơ |
| BR-010 | Phép năm chưa dùng có cộng dồn sang năm sau hay không chưa chốt — assumption có tag `[CẦN CHỐT SỐ]` (đề xuất Điều 113 BLLĐ 2019: cộng dồn tối đa 3 tháng, thỏa thuận được dài hơn); đến hạn chưa chốt, hệ thống giữ số dư theo luật và hiển thị nhãn "chờ quy định cộng dồn". Delegate duyệt timesheet cho TL cũng ở mức chưa chốt — `[KXN-DTS]` (SO3-09 nhóm D): luồng duyệt phép không mở delegate trong bản này, approver theo routing phân cấp. | Không cấu hình cộng dồn vượt khung luật khi chưa chốt; nút delegate không hiển thị — yêu cầu delegate bị từ chối kèm ghi chú chờ chốt |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. TL/Manager là chức danh tổ chức gán qua trường "TL trực tiếp" trong hồ sơ (FEAT-ERP-HRCORE-001), không phải vai registry riêng.

| Hành động | Nhân viên (mọi vai) | TL | HR_L1 | HR_L2 | OPS_PLAN |
|-----------|--------------------|----|-------|-------|----------|
| Lập đơn nghỉ của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem số dư + lịch sử nghỉ của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem lịch nghỉ nhóm (để tránh trùng) | ✅ (nhóm mình) | ✅ | ✅ | ✅ | ✅ |
| Duyệt đơn ≤5 ngày | ❌ | ✅ (24h) | ❌ | ✅ | ❌ |
| Duyệt đơn >5 ngày / nghỉ không lương | ❌ | ❌ | ❌ | ✅ (48h) | ❌ |
| Duyệt luồng bất khả kháng (hết phép) | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xác nhận KPI prorate/miễn (thai sản/ốm dài) | ❌ | ❌ | ❌ | ✅ | ❌ |
| Yêu cầu bổ sung giấy tờ / xử lý đơn treo | ❌ | ❌ | ✅ | ✅ | ❌ |
| Xem báo cáo nghỉ theo phòng/tháng + tần suất nghỉ không phép | ❌ | ✅ (nhóm mình) | ✅ | ✅ | ❌ (chỉ capacity) |

Không ai tự duyệt đơn nghỉ của chính mình kể cả cấp quản lý: đơn của TL đi hàng đợi Manager, đơn của HR_L2 đi hàng đợi BOD. Mọi lượt duyệt/từ chối ghi người duyệt, thời điểm, lý do (bắt buộc khi từ chối) vào audit log bất biến.

---

## 5. Trường Hợp Đặc Biệt

- Nghỉ đột xuất (sự cố gia đình, ốm bất ngờ): lập đơn retro trong ngày đi làm lại kèm lý do; TL duyệt như bình thường nhưng đơn đánh dấu retro để thống kê — không tính vi phạm nội quy nếu lý do hợp lệ.
- Nghỉ không lương >30 ngày: ngoài duyệt HR_L2, hệ thống nối trạng thái hồ sơ `LONG_LEAVE` của FEAT-ERP-HRCORE-001 — đóng băng allocation/capacity và đánh dấu KPI prorate/miễn; ngày nghỉ không lương không trừ số dư phép năm.
- Nghỉ ốm dài/thai sản kéo qua nhiều tháng: tạo một đơn dài hạn duyệt một lần theo giấy tờ; số dư phép năm tiếp tục tích lũy theo luật trong thời gian nghỉ, hệ thống gạch ngày nghỉ khỏi định mức chấm công tuần tự động.
- Đơn trùng thời điểm giữa các thành viên nhóm (ví dụ 2 người cùng nghỉ tuần cao điểm campaign): web hiển thị lịch nhóm khi lập đơn; nếu vẫn trùng, TL quyết định duyệt hay từ chối dựa theo nhân lực — hệ thống chỉ cảnh báo, không tự chặn trùng.
- Đơn đã duyệt cần hủy/rút ngắn: nhân viên lập yêu cầu hủy/giảm số ngày, người duyệt ban đầu xác nhận; số dư hoàn lại theo phần hủy, capacity phục hồi — có vết, không xóa đơn đã duyệt.
- Nghỉ hết phép xin nghỉ riêng bất khả kháng (ốm có chứng minh, tang sự): luồng HR_L2 duyệt, không trừ số dư phép năm, ghi loại "nghỉ riêng theo §8" để tách bạch thống kê.
- BOD/HR_L2 đi nghỉ: đơn của họ xếp hàng đợi cho cấp trên duyệt; không có delegate duyệt — đơn treo có SLA nhắc, không ai duyệt hộ trong bản này (`[KXN-DTS]` chờ chốt).
- Cộng dồn cuối năm chưa chốt quy tắc: số dư 31/12 giữ nguyên theo luật, hiển thị nhãn "chờ quy định cộng dồn `[CẦN CHỐT SỐ]`" — không tự mất, không tự cộng vượt khung luật.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Đơn nghỉ phép (LeaveRequest).

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING] ──(route theo số ngày/loại nghỉ)──► [PENDING_TL] hoặc [PENDING_HR]
[PENDING_TL] ──(duyệt ≤24h)──► [APPROVED] ──(hết kỳ nghỉ)──► [CONSUMED]
[PENDING_HR] ──(duyệt ≤48h)──► [APPROVED] ──► [CONSUMED]
[PENDING_*] ──(từ chối)──► [REJECTED]
[APPROVED] ──(hủy/thu hồi theo phần)──► [PARTIALLY_CANCELLED] hoặc [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING` | Người lập đơn | Đủ loại nghỉ, khoảng ngày, lý do; đủ ngưỡng báo trước hoặc chọn retro có lý do |
| `PENDING` | Route phân cấp | `PENDING_TL`/`PENDING_HR` | Hệ thống | ≤5 ngày → TL; >5 ngày hoặc không lương → HR_L2 |
| `PENDING_TL` | Duyệt | `APPROVED` | TL ≠ người lập (24h) | Đủ số dư; ốm ≥3 ngày có giấy khám |
| `PENDING_HR` | Duyệt | `APPROVED` | HR_L2 (48h) | Đủ số dư hoặc luồng bất khả kháng có chứng minh |
| `PENDING_*` | Từ chối | `REJECTED` | Người duyệt theo cấp | Lý do bắt buộc |
| `APPROVED` | Hết kỳ nghỉ | `CONSUMED` | Hệ thống | Số dư đã trừ; capacity đã giảm; chấm công đã cập nhật |
| `APPROVED` | Hủy/giảm | `CANCELLED`/`PARTIALLY_CANCELLED` | Người lập + người duyệt ban đầu | Xác nhận 2 chiều; hoàn số dư + phục hồi capacity theo phần |

**Quy tắc:**
- `CONSUMED`, `REJECTED`, `CANCELLED` là trạng thái kết thúc; hủy `CONSUMED` không được — tạo đơn điều chỉnh mới.
- SLA đếm từ thời điểm vào hàng đợi; quá hạn sinh nhắc rồi escalate, không tự duyệt hộ và không tự từ chối.
- Mọi chuyển trạng thái ghi audit log bất biến; số dư chỉ thay đổi tại `APPROVED` (trừ) và hủy/giảm (hoàn) — có bản ghi hiệu chỉnh riêng.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| LeaveRequest | `profile_id`, `leave_type`, `from_date`, `to_date`, `days`, `status`, `reason`, `is_retro` | FK → `EmployeeProfile.id` | Routing theo days/type |
| LeaveBalance | `profile_id`, `leave_type`, `year`, `accrued`, `used`, `available` | FK → `EmployeeProfile.id` | Tích lũy tự động 12 ngày/năm |
| LeaveAttachment | `request_id`, `doc_type`, `file_uri` | FK → `LeaveRequest.id` | Giấy khám bắt buộc ốm ≥3 ngày |
| LeaveApprovalLog | `request_id`, `approver_id`, `action`, `sla_due_at`, `acted_at`, `comment` | FK → `LeaveRequest.id` | SLA 24h/48h + escalate |
| CapacityImpactEvent | `profile_id`, `request_id`, `week`, `hours_reduced` | FK → `LeaveRequest.id` | Nối REQ-HR-009/DEPT-OPS |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tích lũy tự động | NV vào công ngày 15/03 | Đến 15/04 | Số dư +1 ngày tự động, không thao tác tay; tổng năm 12 ngày | [ ] |
| SC-002: Route phân cấp đúng | Đơn nghỉ 3 ngày | Submit | Đơn vào hàng đợi TL, SLA 24h hiển thị; đơn 8 ngày → HR_L2 48h | [ ] |
| SC-003: Chặn vượt số dư | Số dư còn 2 ngày | Đơn nghỉ 5 ngày được đưa ra duyệt | Nút duyệt không hiển thị; API từ chối với thông báo số dư | [ ] |
| SC-004: Giấy khám bắt buộc | Đơn nghỉ ốm 4 ngày không đính kèm | Submit | Không chuyển được sang chờ duyệt; bổ sung giấy khám mới hợp lệ | [ ] |
| SC-005: Capacity tự giảm | Đơn 5 ngày được duyệt | Sau duyệt | Capacity tuần của NV giảm tự động trong view OPS; số dư trừ đúng 5 ngày | [ ] |
| SC-006: Escalate quá SLA | Đơn TL quá 24h chưa duyệt | Hệ thống đo SLA | Nhắc TL; quá hạn tiếp theo escalate Manager; không tự duyệt | [ ] |
| SC-007: Đếm nghỉ không phép theo §8 | NV nghỉ không phép 2 buổi trong tháng | Chạy thống kê tháng | Gắn nhãn cảnh cáo–đình chỉ theo §8 lên báo cáo HR; ≥5 ngày/tháng gắn căn cứ chấm dứt HĐ | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-HR-004 (Mục 2 — tích lũy, số dư, duyệt phân cấp, chặn vượt số dư, giấy khám, capacity, nội quy §8).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/nghi-phep.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (validation số dư + routing phân cấp) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (§8 nội quy nghỉ phép + chế tài, §9 entity TMS) |
