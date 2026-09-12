# Tính Năng: Self-service nhân viên (ESS)

> **Dựa trên:** REQ-HR-005 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-005 → FEAT-ERP-HRCORE-005. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (row-level security + workflow duyệt thay đổi nhạy cảm ở service layer) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-005 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-005 — Self-service nhân viên (ESS) (MEDIUM, MVP) |
| Người dùng liên quan | Toàn bộ nhân viên nội bộ (mọi vai registry — người dùng chính), HR_L2 (duyệt thay đổi nhạy cảm), HR_L1 (hỗ trợ xử lý yêu cầu) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-ERP-HRCORE-001 (hồ sơ SSOT — ESS chỉ là cửa nhìn dữ liệu của chính mình); tích hợp màn của FEAT-003 (điều chỉnh công), FEAT-004 (đơn nghỉ), FEAT-002 (thông báo HĐLĐ) |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) xác nhận need "duyệt nhanh trên mobile" ngoài scope SYS-MOBILE-INTERNAL hiện tại — ESS chỉ trên web nội bộ; web responsive bảo đảm dùng được trên trình duyệt di động qua SSO |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp trang "Của tôi" trên web nội bộ — cổng tự thao tác cho toàn bộ nhân viên BC Agency: xem hồ sơ của mình (trường nhạy cảm hiển thị masked), lập đơn nghỉ, đề nghị điều chỉnh công, xem timesheet và dữ liệu gốc KPI của mình, cập nhật thông tin cá nhân, và nhận thông báo trong hệ thống (nhắc chốt timesheet, hạn duyệt, kỳ KPI). Tính năng giảm tải tác nghiệp cho HR_L1/HR_L2 bằng cách đẩy thao tác về đúng chủ thể dữ liệu, đồng thời siết an toàn PII: mỗi người chỉ thấy dữ liệu của mình, thay đổi nhạy cảm phải qua duyệt HR_L2 trước khi hiệu lực.

**Phạm vi:**
- Bao gồm: trang "Của tôi" — tổng quan hồ sơ, trạng thái các đơn đang chờ, thông báo; màn xem hồ sơ cá nhân với trường C1 masked; màn cập nhật thông tin cá nhân (địa chỉ liên hệ, SĐT, người liên hệ khẩn, TK ngân hàng) qua luồng yêu cầu có duyệt.
- Bao gồm: cửa vào các thao tác tự phục vụ đã có luồng riêng: xin nghỉ (FEAT-004), đề nghị điều chỉnh công (FEAT-003), xem timesheet của mình (CAPACITY-TIMESHEET), xem KPI + dữ liệu gốc KPI của mình (KPI-PERFORMANCE) — ESS là mặt điều hướng thống nhất, không tái định nghĩa luồng duyệt.
- Bao gồm: trung tâm thông báo trong hệ thống — nhắc chốt timesheet trước 12:00 thứ Hai, hạn duyệt đơn của mình, mốc kỳ KPI, cảnh báo HĐLĐ nhân sự nhóm (cho TL), với trạng thái đọc/chưa đọc.
- Bao gồm: luồng thay đổi trường nhạy cảm (TK ngân hàng, người liên hệ khẩn, thông tin ảnh hưởng payroll): tạo yêu cầu → HR_L2 duyệt 24h → hiệu lực; trước đó mọi hệ thống tiêu thụ (payroll) dùng giá trị cũ.
- Không bao gồm: row-level security và workflow duyệt — enforce ở service layer SYS-CORE-BACKEND; web chỉ ẩn/hiện và hiển thị lỗi từ chối của API.
- Không bao gồm: bản mobile app (SYS-MOBILE-INTERNAL không khai báo HR — xem lại khi mở rộng scope), xem dữ liệu của người khác (kể cả TL xem chi tiết C1 nhân sự nhóm — chỉ qua màn quản trị riêng không chứa C1), và tự sửa các trường master do HR quản (mã vai, Level, trạng thái — qua luồng đề xuất của FEAT-001).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive, đăng nhập qua SSO realm nội bộ; mọi thao tác ESS có audit log bất biến ở core.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên nội bộ | Mở trang "Của tôi" và thấy tổng hợp: hồ sơ, đơn đang chờ, thông báo mới | Nắm tình trạng các việc của mình trong một màn hình, không hỏi tay HR |
| 2 | Nhân viên nội bộ | Xem hồ sơ của mình với lương/CCCD/TK ngân hàng ở dạng masked | Biết thông tin đã đúng mà dữ liệu nhạy cảm không lộ trên màn hình |
| 3 | Nhân viên nội bộ | Cập nhật TK ngân hàng/người liên hệ khẩn bằng cách gửi yêu cầu | Thông tin mới chỉ áp dụng sau khi HR_L2 duyệt — payroll không nhận dữ liệu sai tràn lan |
| 4 | Nhân viên nội bộ | Xem timesheet và dữ liệu gốc KPI của mình (task, deliverable, SLA) trước kỳ review | Kiểm chứng dữ liệu trước khi điểm KPI công bố, chuẩn bị thắc mắc đúng hạn 3 ngày |
| 5 | Nhân viên nội bộ | Nhận nhắc chốt timesheet trước 12:00 thứ Hai và nhắc hạn duyệt đơn mình đã gửi | Không quên deadline, tự theo dõi tiến độ phê duyệt |
| 6 | TL | Nhận thông báo HĐLĐ nhân sự nhóm sắp hết hạn và đơn nghỉ chờ mình duyệt | Xử lý đúng hạn ngay trong cửa ESS mà không phải vào màn quản trị |
| 7 | HR_L2 | Duyệt yêu cầu thay đổi trường nhạy cảm trong 24h trên hàng đợi ESS | Thay đổi PII có người soát, có vết, payroll chỉ dùng giá trị đã duyệt |
| 8 | HR_L1 | Xem danh sách yêu cầu ESS đang treo quá 24h | Đôn đốc HR_L2 xử lý, không sót yêu cầu nhân viên |

Quy ước xuyên suốt: "mỗi người chỉ thấy dữ liệu của mình" do core enforce row-level — truy cập ID người khác qua API bị từ chối dù UI có ẩn hay không; web không phải lớp bảo mật.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Row-level security và workflow duyệt chạy ở service layer SYS-CORE-BACKEND; web phản chiếu đúng trạng thái machine-state.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: ESS chỉ đọc/hiển thị dữ liệu từ hồ sơ và các phân hệ, không giữ bảng dữ liệu riêng; nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track Sales/Business Ops/HCNS/Marketing-Creative). | Màn ESS tự cache/tự lưu bản sao dữ liệu hồ sơ bị loại ở review; hiển thị sai so với core là lỗi bug nghiêm trọng |
| BR-002 | Mỗi người chỉ thấy dữ liệu của mình — enforce row-level ở core, không chỉ ẩn UI: truy vấn dữ liệu profile khác qua API bị từ chối kể cả khi đúc tham số ID; duy nhất trường hợp TL nhận thông báo về nhân sự nhóm (không kèm C1). | Truy cập chéo bị 403 + log attempt bất biến; nỗ lực lách bằng tham số ID ghi nhận làm sự kiện bảo mật |
| BR-003 | Trường nhạy cảm (TK ngân hàng, người liên hệ khẩn, dữ liệu ảnh hưởng payroll) và mọi thay đổi ảnh hưởng payroll phải HR_L2 duyệt trong 24h trước khi hiệu lực; trước đó payroll và hệ thống tiêu thụ dùng giá trị cũ. | Thay đổi không qua duyệt không bao giờ hiệu lực; hệ thống tiêu thụ đọc giá trị chưa duyệt là lỗi đồng bộ nghiêm trọng |
| BR-004 | Trường C1 hiển thị masked cho chủ thể dữ liệu trên ESS; không có chức năng "xem đầy đủ" của chính người dùng ngoài kênh xác minh với HR — bản gốc chỉ HR_L2 mở được (log từng lượt). | Nỗ lực bỏ mask qua DevTools/API bị chặn ở tầng dữ liệu; xuất raw C1 từ ESS không tồn tại |
| BR-005 | Mọi thao tác ESS (xem trang, gửi yêu cầu, hủy yêu cầu, cập nhật) có audit log bất biến: ai — khi nào — hành động gì — trước/sau; log không thể xóa/sửa kể cả bởi SYS_ADMIN. | Thiếu log cho một thao tác là lỗi chấp nhận nghiệm thu; sửa/xóa log bị chặn cứng |
| BR-006 | HĐLĐ cảnh báo hết hạn 90/60/30 ngày và chấm công 40h/tuần trần 48h overtime: ESS hiển thị thông báo tương ứng (nhắc chốt timesheet, hạn duyệt) nhưng không thay đổi quy tắc của các luồng sở hữu — liên kết tới FEAT-002/003. | Thông báo ESS không tính lại mốc nhắc (đọc kết quả job core); hiển thị lệch mốc là lỗi liên kết dữ liệu |
| BR-007 | Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo `03_Quy_che_KPI_HR.md` §8: ESS hiển thị số dư hiện hành và trạng thái đơn — số dư không nhập tay, duyệt không thực hiện tại ESS. | ESS không xuất hiện nút duyệt đơn của người khác; số dư hiển thị phải khớp LeaveBalance của core tại thời điểm đọc |
| BR-008 | Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt), billable tại nguồn: dữ liệu cost/rate không xuất hiện trên ESS của nhân viên thường; giờ billable của chính mình hiển thị ở timesheet theo trạng thái máy (chờ duyệt/đã duyệt). | Rate/cost cá nhân lộ ra màn ESS là vi phạm Restricted (REQ-HR-010); hiển thị giờ chưa duyệt như đã duyệt là lỗi trạng thái |
| BR-009 | Delegate duyệt timesheet cho TL vẫn ở mức chưa chốt — assumption có tag `[KXN-DTS]` (SO3-09 nhóm D): ESS không cấu hình delegate duyệt trong bản này; thông báo hạn duyệt chỉ gửi đúng người duyệt theo routing hiện hành. | Không hiển thị tùy chọn delegate; yêu cầu cấu hình delegate bị từ chối kèm ghi chú chờ chốt |
| BR-010 | Đăng nhập ESS qua SSO realm nội bộ; phiên làm việc hết hạn tự động theo chính sách chung, không lưu mật khẩu/cookie riêng ngoài chuẩn; truy cập từ thiết bị ngoài công ty vẫn qua SSO (web responsive, không app riêng). | Truy cập không qua SSO bị từ chối; cơ chế đăng nhập riêng cho ESS bị loại ở review bảo mật |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API (row-level); bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. Mọi vai nội bộ dùng ESS với phạm vi "của mình".

| Hành động | Nhân viên (mọi vai) | TL | HR_L1 | HR_L2 |
|-----------|--------------------|----|-------|-------|
| Xem trang "Của tôi" | ✅ (của mình) | ✅ | ✅ | ✅ |
| Xem hồ sơ của mình (C1 masked) | ✅ (masked) | ✅ (masked) | ✅ (masked) | ✅ (đầy đủ qua màn quản trị) |
| Cập nhật thông tin thường (SĐT, địa chỉ) | ✅ (hiệu lực sau lưu) | ✅ | ✅ | ✅ |
| Gửi yêu cầu thay đổi trường nhạy cảm | ✅ | ✅ | ✅ | ✅ |
| Duyệt yêu cầu thay đổi nhạy cảm (24h) | ❌ | ❌ | ❌ | ✅ |
| Xem timesheet/KPI của mình | ✅ | ✅ | ✅ | ✅ |
| Xem dữ liệu của người khác | ❌ | ❌ (chỉ thông báo nhóm) | ❌ (qua màn quản trị riêng) | ✅ (qua màn quản trị, log) |
| Hủy yêu cầu của mình đang chờ | ✅ | ✅ | ✅ | ✅ |
| Xem hàng đợi yêu cầu treo quá 24h | ❌ | ❌ | ✅ | ✅ |

Không có nút duyệt của người khác trong ESS: duyệt đơn nghỉ/điều chỉnh công/timesheet xảy ra ở màn của luồng sở hữu (FEAT-003/004, CAPACITY-TIMESHEET) — ESS chỉ điều hướng tới. SYS_ADMIN không xuất hiện trong ma trận vì không có quyền xem dữ liệu nhân sự qua ESS (chỉ xem audit log, và xem log cũng bị log).

---

## 5. Trường Hợp Đặc Biệt

- Nhân viên đổi TK ngân hàng sát kỳ payroll: yêu cầu chờ HR_L2 duyệt; nếu kỳ payroll chốt trước khi duyệt, kỳ đó dùng TK cũ — hệ thống hiển thị cảnh báo "sẽ áp dụng từ kỳ sau" ngay khi gửi yêu cầu.
- HR_L2 tự thay đổi thông tin nhạy cảm của chính mình: không tự duyệt được — yêu cầu xếp hàng đợi cho BOD (quản lý cấp trên) duyệt; không tồn tại đường tự duyệt.
- Nhân viên nghỉ việc: tài khoản SSO thu hồi trong 24h theo offboarding (FEAT-001), trang ESS mất truy cập tự nhiên; dữ liệu đã tạo (đơn, yêu cầu) giữ lại theo retention phục vụ chốt phép và đối chiếu.
- Nhân viên thắc mắc KPI trong kỳ công bố 3 ngày làm việc: từ ESS mở dữ liệu gốc KPI của mình (task, deliverable, SLA) và gửi thắc mắc — luồng đối chiếu thuộc KPI-PERFORMANCE, ESS chỉ là điểm vào.
- Thông báo tràn (nhiều đơn chờ, nhiều nhắc): trung tâm thông báo gom nhóm theo loại, hiển thị số đếm và thứ tự theo hạn gần nhất; không xóa thông báo có hạn duyệt chưa xử lý.
- Trình duyệt trên thiết bị di động qua trình duyệt web: layout responsive bảo đảm thao tác được; không có offline mode và không push notification (app mobile ngoài scope — A7.2), thông báo chỉ trong hệ thống.
- Nhân viên kiêm nhiệm nhiều vai (2 mã vai): trang "Của tôi" hợp nhất dữ liệu theo 1 profile duy nhất với các vai đang hiệu lực; phạm vi menu theo vai cao hơn nhưng dữ liệu cá nhân vẫn chỉ của chính mình.
- Yêu cầu thay đổi bị từ chối: HR_L2 nhập lý do bắt buộc; nhân viên thấy lý do và có thể gửi yêu cầu mới — yêu cầu cũ giữ trạng thái `REJECTED` làm lịch sử, không xóa.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu thay đổi thông tin cá nhân (ProfileChangeRequest) — thực thể ESS riêng có vòng đời duyệt.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_HR_L2] ──(duyệt ≤24h)──► [APPROVED] ──(áp dụng hiệu lực)──► [EFFECTIVE]
[PENDING_HR_L2] ──(từ chối)──► [REJECTED]
[PENDING_HR_L2] ──(người gửi rút)──► [WITHDRAWN]
[EFFECTIVE] ──(yêu cầu chỉnh tiếp)──► (tạo request mới)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_HR_L2` | Chủ thể dữ liệu | Đủ giá trị mới cho các trường chọn thay đổi |
| `PENDING_HR_L2` | Duyệt | `APPROVED` | HR_L2 (24h; tự mình → BOD) | Không tự duyệt yêu cầu của chính mình |
| `PENDING_HR_L2` | Từ chối | `REJECTED` | HR_L2 | Lý do bắt buộc, hiển thị cho người gửi |
| `PENDING_HR_L2` | Rút yêu cầu | `WITHDRAWN` | Người gửi (khi chưa duyệt) | Không có vết thay đổi dữ liệu |
| `APPROVED` | Áp dụng hiệu lực | `EFFECTIVE` | Hệ thống | Ghi giá trị mới vào hồ sơ (version mới); payroll dùng giá trị mới từ kỳ kế tiếp |

**Quy tắc:**
- `EFFECTIVE`, `REJECTED`, `WITHDRAWN` là trạng thái kết thúc của một yêu cầu — chỉnh tiếp tạo yêu cầu mới, không tái dùng yêu cầu cũ.
- Khoảng `APPROVED` → `EFFECTIVE` ghi rõ thời điểm hiệu lực; dữ liệu tiêu thụ (payroll, BHXH) đọc theo giá trị hiệu lực tại kỳ của chúng.
- Mọi chuyển trạng thái ghi audit log bất biến kèm giá trị trước/sau (chỉ hiện đầy đủ cho HR_L2; masked cho người gửi).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ProfileChangeRequest | `profile_id`, `field_path`, `old_value`, `new_value`, `status`, `sensitivity` | FK → `EmployeeProfile.id` | sensitivity=high phải HR_L2 duyệt |
| Notification | `profile_id`, `type`, `payload`, `due_at`, `read_at` | FK → `EmployeeProfile.id` | Nhắc timesheet/duyệt/KPI; đọc kết quả job core |
| MyTimesheetView (read model) | `profile_id`, `week`, `hours`, `approval_state` | Read-only từ CAPACITY-TIMESHEET | Không lưu bản sao vĩnh viễn |
| MyKpiView (read model) | `profile_id`, `period`, `pillar_scores`, `source_data_uri` | Read-only từ KPI-PERFORMANCE | Dữ liệu gốc xem trước review |
| AuditLog (tham chiếu) | `actor_id`, `action`, `object`, `before`, `after`, `channel` | Append-only, hash-chain | Mọi thao tác ESS; xem log cũng bị log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Row-level chặn truy cập chéo | NV A biết ID của NV B | Gọi API xem profile của B | Core trả 403 + log attempt; UI không có đường vào | [ ] |
| SC-002: C1 masked | NV mở hồ sơ của mình | Xem lương/TK ngân hàng | Hiển thị dạng masked; không có nút xem đầy đủ | [ ] |
| SC-003: Thay đổi nhạy cảm cần duyệt | NV gửi đổi TK ngân hàng | HR_L2 chưa duyệt | Payroll vẫn dùng TK cũ; sau duyệt 24h, hiệu lực ghi rõ kỳ áp dụng | [ ] |
| SC-004: Không tự duyệt yêu cầu của mình | HR_L2 gửi yêu cầu đổi thông tin của chính mình | Thử duyệt | Hàng đợi chuyển BOD; nút duyệt của chính mình không tồn tại | [ ] |
| SC-005: Thông báo đúng hạn | Đến 08:00 thứ Hai | Job nhắc chốt timesheet chạy | Nhân viên chưa chốt nhận nhắc "trước 12:00 thứ Hai"; TL nhận đếm tồn duyệt | [ ] |
| SC-006: Audit đầy đủ | NV thực hiện 5 thao tác ESS trong phiên | Rà audit log | Đủ 5 bản ghi ai—khi nào—hành động—trước/sau; không xóa/sửa được | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-HR-005 (Mục 2 — row-level, masked, duyệt thay đổi nhạy cảm, thông báo, audit log).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/ess-cua-toi.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (row-level security + workflow duyệt) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (HR v3.9, §8 nội quy hiển thị trên ESS) |
