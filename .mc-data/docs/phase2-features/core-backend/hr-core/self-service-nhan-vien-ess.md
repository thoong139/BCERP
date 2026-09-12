# Tính Năng: Self-service nhân viên (ESS)

> **Dựa trên:** REQ-HR-005 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-005` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-005 xuất hiện ở 2 hệ thống — **SYS-BCERP-WEB** (primary: trang "Của tôi", form ESS) và **SYS-CORE-BACKEND** (bản spec này: API ESS, row-level access control, workflow duyệt thay đổi nhạy cảm, notification service). Tại touchpoint core backend, nguyên tắc nền là **"mỗi người chỉ thấy dữ liệu của mình" được enforce row-level ở service layer, không chỉ ẩn UI**; mọi thao tác ESS có audit log bất biến và dữ liệu luôn xử lý trong tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-005 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-005 |
| Người dùng liên quan | Toàn bộ nhân viên (18-vai registry — chủ thể ESS), HR_L2 (duyệt thay đổi nhạy cảm), HR_L1 (hỗ trợ đối soát), SYS_ADMIN (hạ tầng SSO, không xem giá trị PII) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-HRCORE-001 (hồ sơ SSOT); FEAT-CORE-HRCORE-003 (điều chỉnh công); FEAT-CORE-HRCORE-004 (đơn nghỉ) |
| Ghi chú Expert (A7) | A7.2: need "nhận nhắc + duyệt nhanh trên mobile" ghi nhận tại REQ-HR-004/005/009 — ngoài scope SYS-MOBILE-INTERNAL hiện tại, xem lại khi mở rộng scope. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp bộ API self-service để toàn bộ nhân viên tự thao tác với dữ liệu của chính mình: xem hồ sơ (trường C1 chỉ hiển thị masked), lập đơn nghỉ, đề nghị điều chỉnh công, xem timesheet và **dữ liệu gốc KPI của mình**, cập nhật thông tin cá nhân, và nhận thông báo trong hệ thống (nhắc chốt timesheet trước 12:00 thứ Hai, hạn duyệt, kỳ KPI). Tính năng giảm tải thao tác thủ công cho HR_L1/HR_L2 và đồng thời là bề mặt kiểm soát truy cập dữ liệu cá nhân chặt nhất của hệ thống.

**Phạm vi:**
- Bao gồm: API "Của tôi" với row-level access control enforced ở service layer; luồng yêu cầu thay đổi trường nhạy cảm (TK ngân hàng, người liên hệ khẩn, thông tin ảnh hưởng payroll) — phải **HR_L2 duyệt trong 24h** trước khi hiệu lực, trước đó payroll tiếp tục dùng giá trị cũ; proxyAPI lập đơn nghỉ (nối FEAT-CORE-HRCORE-004) và đề nghị điều chỉnh công (nối FEAT-CORE-HRCORE-003); đọc timesheet + dữ liệu gốc KPI của mình (đọc từ nguồn OPS/REQ-HR-007, chỉ đọc); notification service phát nhắc chốt timesheet, hạn duyệt, kỳ KPI; audit log mọi thao tác ESS.
- Không bao gồm: màn hình trang "Của tôi" (SYS-BCERP-WEB — counterpart); mobile (SYS-MOBILE-INTERNAL — ngoài scope hiện tại theo Phần A/A7 của `hr.md`, need "duyệt nhanh trên mobile" chỉ ghi nhận); chấm điểm KPI (REQ-HR-007 — ESS chỉ xem dữ liệu gốc + điểm đã công bố); duyệt timesheet/capacity (REQ-HR-009); portal khách hàng (khác hệ thống — PII nhân sự cấm xuất hiện trên Client Portal theo A6).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` — quy trình HR v3.9 Phase 2–3 (checklist hội nhập, check-in monthly, engagement), 4 track Sales/Business Ops/HCNS/Marketing-Creative; mục 9 (entity `checkin_monthly`, `leave_request`, `attendance_violation` — các dữ liệu ESS hiển thị đọc từ các entity này). ESS không hiển thị lương chi tiết — lương/chứng từ thuộc nhóm Restricted theo REQ-HR-010.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên (mọi vai registry) | Đăng nhập SSO realm nội bộ và xem hồ sơ của mình, với trường C1 chỉ hiện masked | Nắm thông tin của mình mà PII nhạy cảm không bị lộ tràn |
| 2 | Nhân viên | Lập đơn nghỉ và đề nghị điều chỉnh công ngay trên ESS | Không phải gửi email/chat cho HR cho các tác vụ lặp lại |
| 3 | Nhân viên | Xem timesheet của mình và dữ liệu gốc KPI của mình (task, deliverable, SLA) | Hiểu điểm số đến từ dữ liệu nào trước kỳ review minh bạch |
| 4 | Nhân viên | Nộp yêu cầu cập nhật TK ngân hàng / người liên hệ khẩn | Thông tin mới có hiệu lực sau khi HR_L2 duyệt, payroll không bị sốc giữa kỳ |
| 5 | Hệ thống (workflow) | Đưa yêu cầu thay đổi nhạy cảm vào hàng đợi HR_L2 với SLA 24h | Thay đổi ảnh hưởng payroll luôn có người thẩm định |
| 6 | HR_L2 | Duyệt/từ chối yêu cầu thay đổi nhạy cảm kèm so sánh giá trị cũ–mới | Chỉ thay đổi hợp lệ mới hiệu lực; từ chối có lý do lưu hồ sơ |
| 7 | Hệ thống (notification) | Gửi nhắc chốt timesheet trước 12:00 thứ Hai, nhắc hạn duyệt, nhắc mở/đóng kỳ KPI | Nhân viên không bỏ lỡ deadline quy trình nội bộ |
| 8 | Hệ thống (bảo mật) | Chặn mọi truy vấn ESS vượt row của chính mình — kể cả khi gọi API trực tiếp | Row-level là cam kết service layer, không phải ẩn UI |
| 9 | HR_L1 | Tra audit log thao tác ESS khi có khiếu nại dữ liệu | Mọi thao tác "ai — khi nào — làm gì" truy vết được |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR5-01 | Mỗi người chỉ thấy dữ liệu của mình — **row-level access control enforced ở service layer** trên mọi API ESS (kể cả lọc theo `employee_id` truyền vào): truy vấn id người khác bị từ chối ở tầng query | Gọi API trực tiếp với id khác vẫn bị chặn; sự kiện chặn ghi log bảo mật |
| BR-HR5-02 | Trường C1 (CCCD, lương, TK ngân hàng, dữ liệu y tế) qua ESS chỉ trả giá trị **masked**; không có API ESS nào trả raw C1 cho chủ sở hữu | Xuất raw từ kênh ESS bị chặn; log mọi nỗ lực |
| BR-HR5-03 | Thay đổi trường nhạy cảm (TK ngân hàng, người liên hệ khẩn, thông tin ảnh hưởng payroll) phải tạo **yêu cầu** → **HR_L2 duyệt trong 24h** → mới hiệu lực; trước khi hiệu lực, payroll dùng giá trị cũ | Sửa trực tiếp trường nhạy cảm bị API từ chối — chỉ có luồng yêu cầu |
| BR-HR5-04 | Yêu cầu thay đổi: duyệt → áp giá trị mới từ thời điểm hiệu lực có log; từ chối → trả lý do, giữ nguyên giá trị cũ | Không tồn tại trạng thái "đã đổi nhưng chưa ai duyệt" |
| BR-HR5-05 | **Mọi thao tác ESS có audit log bất biến** (đăng nhập, xem, tạo yêu cầu, hủy, phản hồi) | Thiếu log thì thao tác không được tính; log cũng được kiểm tra định kỳ theo REQ-HR-010 |
| BR-HR5-06 | Dữ liệu timesheet và KPI qua ESS là **chỉ đọc** và chỉ của mình (nguồn: ghi giờ OPS + tổng hợp REQ-HR-007); ESS không sửa được dữ liệu gốc | Thao tác ghi vào luồng KPI/timesheet qua ESS bị từ chối |
| BR-HR5-07 | Đơn nghỉ và điều chỉnh công từ ESS đi đúng workflow của FEAT-CORE-HRCORE-004/003 (routing phân cấp, approver ≠ người lập) | ESS không được rút gọn workflow duyệt |
| BR-HR5-08 | Notification service phát nhắc: chốt timesheet trước **12:00 thứ Hai**, hạn duyệt của đơn/đề nghị, mở/đóng kỳ KPI; nhắc là kênh thông tin, không tự đổi trạng thái dữ liệu | Nhắc thất bại phải retry và đối soát số đã phát — không âm thầm mất nhắc |
| BR-HR5-09 | ESS chỉ phục vụ nhân viên trong biên chế theo hồ sơ SSOT; freelancer ngoài biên chế không có tài khoản ESS | Đăng nhập đối tượng không có hồ sơ biên chế bị từ chối |
| BR-HR5-10 | Chưa chốt — **delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt**: ESS hiển thị hàng đợi duyệt cho đúng vai theo rule hiện hành (approver ≠ người ghi; timesheet của TL do cấp quản lý trên duyệt) và **không bật cơ chế ủy quyền duyệt** cho đến khi chủ dự án chốt `[KXN-DI006]` | Bật ủy quyền tự ý là vi phạm scope; cấu hình ủy quyền chỉ thêm sau khi có quyết định |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime (FEAT-CORE-HRCORE-002/003).
3. Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8 (FEAT-CORE-HRCORE-004).
4. Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn (FEAT-CORE-HRCORE-006 — ESS không hiển thị cost cá nhân).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]` (SO3-09 nhóm D), không tự quyết (chi tiết BR-HR5-10).

---

## 4. Phân Quyền

| Hành động | Nhân viên (18-vai registry) | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN |
|-----------|------------------------------|-------|-------|------------------------|-----------|
| Xem hồ sơ của mình (C1 masked) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Sửa thông tin thường (C2/C3 của mình) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Nộp yêu cầu sửa trường nhạy cảm (C1) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duyệt yêu cầu sửa trường nhạy cảm (SLA 24h) | ❌ | ❌ | ✅ | ❌ | ❌ |
| Lập đơn nghỉ / đề nghị điều chỉnh công của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem timesheet + dữ liệu gốc KPI của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem dữ liệu ESS của người khác | ❌ | ✅ (nhiệm vụ HR) | ✅ | ✅ | ❌ |
| Cấu hình nội dung nhắc notification | ❌ | ❌ | ✅ | ❌ | ✅ (hạ tầng) |
| Xem audit log ESS | ❌ (chỉ log của mình) | ✅ | ✅ | ✅ | ✅ (xem log cũng bị log) |

> Không dùng vai ngoài 18-vai registry; không tồn tại OPS_CX / FIN_COMPL (DI-006). HR_L1 xem dữ liệu nhân sự theo nhiệm vụ nhưng **không xem lương** (REQ-HR-010); SYS_ADMIN quản hạ tầng, không xem giá trị PII.

---

## 5. Trường Hợp Đặc Biệt

- Nhân sự đổi TK ngân hàng sát kỳ payroll: yêu cầu được duyệt trong 24h nhưng áp dụng cho **kỳ payroll kế tiếp** nếu kỳ hiện tại đã chốt — không tái tính kỳ đã chốt.
- Người dùng cố truy cập dữ liệu người khác (kể cả TL truy vấn nhân sự ngoài nhóm qua kênh ESS): từ chối row-level, ghi log bảo mật; lặp lại nhiều lần đưa vào báo cáo review truy cập C1 theo quý (REQ-HR-010).
- Nhân sự "Nghỉ việc": tài khoản ESS bị thu hồi trong 24h theo offboard của FEAT-CORE-HRCORE-001; các yêu cầu đang chờ duyệt tự hủy kèm lý do.
- Thay đổi thông tin ảnh hưởng đến mã vai/Level (ví dụ chức danh): không phải luồng ESS — phải qua workflow đổi Level/vai có BOD duyệt (FEAT-CORE-HRCORE-001); ESS chỉ nhận diện và hướng dẫn chuyển luồng.
- Notification khi counterpart WEB đứt kết nối: sự kiện nhắc được persist trong hàng đợi và phát lại khi có kết nối; ESS API vẫn available cho các tác vụ đọc với degraded presentation ở counterpart.
- Dữ liệu KPI kỳ đang chờ calibration: ESS hiển thị dữ liệu gốc + trạng thái "chờ calibration", không hiển thị điểm chưa chốt để tránh tranh cãi sớm.
- Mobile: need "nhận nhắc + duyệt nhanh trên mobile" nằm ngoài scope SYS-MOBILE-INTERNAL hiện tại (theo Phần A/A7 `hr.md`) — API thiết kế sẵn khả năng tái sử dụng, nhưng không phát hành kênh mobile trong giai đoạn này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu thay đổi thông tin nhạy cảm ESS (`ess_change_request`)

**Sơ đồ trạng thái:**
```
[NHÁP] ──(gửi)──► [CHỜ HR_L2 DUYỆT (SLA 24h)] ──(duyệt)──► [ĐÃ HIỆU LỰC]
   │                     │                                       (giá trị cũ giữ đến thời điểm hiệu lực)
   │ (hủy)               │ (từ chối)
   ▼                     ▼
 [HỦY]              [TỪ CHỐI (lý do lưu hồ sơ)]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Nháp | Gửi | Chờ HR_L2 duyệt | Chủ sở hữu dữ liệu | Có giá trị mới + lý do; hệ thống chụp giá trị cũ |
| Chờ HR_L2 duyệt | Duyệt | Đã hiệu lực | HR_L2 (SLA 24h) | So sánh giá trị cũ–mới hiển thị khi duyệt; thời điểm hiệu lực ghi log |
| Chờ HR_L2 duyệt | Từ chối | Từ chối | HR_L2 | Ghi lý do; giá trị cũ giữ nguyên |
| Chờ HR_L2 duyệt | Quá SLA | Chờ duyệt (+ nhắc/escalate) | Hệ thống | Nhắc HR_L2; escalate theo cấu hình nếu tiếp tục quá hạn |
| Chờ HR_L2 duyệt | Hủy | Hủy | Người lập | Chỉ khi chưa được duyệt |
| Đã hiệu lực | Sửa tiếp | (yêu cầu mới) | Người lập | Luôn qua yêu cầu mới — không sửa đè giá trị đã hiệu lực |

**Quy tắc:**
- "Từ chối", "Hủy" là trạng thái kết thúc của yêu cầu; "Đã hiệu lực" không cho phép sửa đè — thay đổi tiếp theo là yêu cầu mới.
- Đơn nghỉ và đề nghị điều chỉnh công tạo từ ESS sử dụng state machine của FEAT-CORE-HRCORE-004/003 — không định nghĩa lại.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ess_change_request` | `employee_id`, `field_group`, `old_value_enc`, `new_value_enc`, `reason`, `status`, `decided_by`, `decided_at`, `effective_at` | FK → `employee`, `users` | Giá trị C1 mã hóa; chỉ HR_L2 quyết định |
| `ess_notification` | `employee_id`, `type` (TIMESHEET_REMINDER/APPROVAL_DUE/KPI_PERIOD), `payload`, `sent_at`, `read_at` | FK → `employee` | Nhắc 12:00 thứ Hai; persist + retry |
| `my_data_view` (read model) | `employee_id`, `profile_masked`, `timesheet_summary`, `kpi_raw_ref`, `leave_balance` | FK → `employee` | Chỉ đọc; tổng hợp từ các entity nguồn |
| `leave_request` / `attendance_correction` | (xem FEAT-CORE-HRCORE-004/003) | FK → `employee` | Tạo từ ESS nhưng workflow riêng feature tương ứng |
| `audit_log` | `actor_id`, `action`, `entity`, `before/after`, `at`, `tenant_id` | — | Bất biến; bao gồm cả thao tác đọc nhạy cảm |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Row-level chặn API trực tiếp | Nhân viên A đăng nhập hợp lệ | Gọi API ESS với `employee_id` của nhân viên B | Service từ chối bất kể tham số truyền; ghi log bảo mật; không trả dữ liệu | [ ] |
| SC-002: C1 masked | Hồ sơ có CCCD, TK ngân hàng | Chủ sở hữu xem hồ sơ qua ESS | Giá trị C1 trả dạng masked; không có trường raw nào trong payload | [ ] |
| SC-003: Thay đổi nhạy cảm phải duyệt | Nhân viên nộp yêu cầu đổi TK ngân hàng | Payroll chạy trước khi HR_L2 duyệt | Payroll dùng giá trị cũ; yêu cầu vẫn chờ; sau duyệt, giá trị mới áp từ thời điểm hiệu lực có log | [ ] |
| SC-004: SLA duyệt 24h | Yêu cầu gửi lúc 10:00 | Đến 10:00 hôm sau chưa duyệt | Hệ thống nhắc HR_L2; escalate nếu tiếp tục quá hạn | [ ] |
| SC-005: Nhắc chốt timesheet | 08:00 thứ Hai | Job notification chạy | Nhắc "chốt tuần trước trước 12:00" phát cho đúng tập nhân viên; idempotent; persist khi có người offline | [ ] |
| SC-006: ESS chỉ đọc KPI | KPI kỳ chưa calibration | Nhân viên mở trang KPI của mình | Hiển thị dữ liệu gốc + trạng thái chờ; không có điểm chưa chốt; không có ô ghi điểm | [ ] |

> **Liên kết:** Các scenario map đến REQ-HR-005 (`hr.md` Mục A3/B5) và BR-HR5-01..10 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/ess-cua-toi.md` |
| Nguồn domain hội nhập/check-in/entity TMS | `documents/03_Quy_che_KPI_HR.md` (mục 2, 3, 9) |
