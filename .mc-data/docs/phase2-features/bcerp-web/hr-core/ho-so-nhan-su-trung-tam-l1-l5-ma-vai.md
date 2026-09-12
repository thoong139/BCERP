# Tính Năng: Hồ sơ nhân sự trung tâm L1–L5 + mã vai

> **Dựa trên:** REQ-HR-001 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-001 → FEAT-ERP-HRCORE-001. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (master data + SCD2 + validation ở service layer) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-001 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-001 — Hồ sơ nhân sự trung tâm L1–L5 + mã vai (HIGH, MVP) |
| Người dùng liên quan | HR_L1, HR_L2, BOD_CEO, SYS_ADMIN; gián tiếp mọi vai nội bộ (hồ sơ là nguồn RBAC/hoa hồng/P&L/KPI) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có cross-dependency ngoài module; các tính năng còn lại của MOD-HR-CORE (HĐLĐ, chấm công, nghỉ phép, ESS, Rate Card) đều đọc từ hồ sơ này — làm trước trong module |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) ghi nhận need mobile HR nằm ngoài scope SYS-MOBILE-INTERNAL hiện tại → quản lý hồ sơ chỉ trên web nội bộ; chi tiết tại hr.md Phần B (B1) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp trên web nội bộ nhóm màn hình quản trị hồ sơ nhân sự trung tâm — nguồn sự thật (SSOT) duy nhất cho toàn bộ L1–L5 và mã vai của BC Agency: tạo hồ sơ onboarding, version hóa thay đổi Level/vai/trạng thái (SCD2 hiệu lực từ ngày–đến ngày), offboarding kèm checklist thu hồi tài khoản. Mọi phân hệ khác (RBAC, hoa hồng, P&L, KPI) đọc từ hồ sơ này, không module nào giữ bản sao riêng, bảo đảm báo cáo quá khứ luôn tái lập được.

**Phạm vi:**
- Bao gồm: web form tạo/sửa hồ sơ (mã NV tự sinh, phòng ban, TL trực tiếp, mã vai + Level + ngày hiệu lực, trạng thái, BHXH, TK lương), timeline version SCD2 trực quan, checklist onboarding/offboarding, hàng đợi duyệt requisition và hồ sơ thôi việc, màn theo dõi trạng thái lệnh cấp/thu hồi RBAC và handoff thu hồi TKQC.
- Bao gồm: luồng thay đổi Level/vai theo trình tự Manager đề xuất → HR_L2 thẩm định (chuẩn năng lực + KPI 2 chu kỳ liên tiếp) → BOD duyệt → hệ thống tạo version mới và đóng version cũ; hỗ trợ 1 người nhiều vai.
- Bao gồm: offboarding đúng căn cứ pháp lý (Điều 34/35/36 BLLĐ 2019) với checklist thu hồi: vô hiệu hóa tài khoản ERP + quyền RBAC trong 24h, phát yêu cầu thu hồi TKQC cho DEPT-OPS thực thi và xác nhận trong 24h, chốt phép chưa dùng, chốt công/timesheet chưa duyệt, chuyển dữ liệu sang chế độ retention.
- Không bao gồm: enforcement validation cứng tầng dữ liệu (1 người 1 hồ sơ, SCD2, mã hóa C1, phát lệnh RBAC) — chạy ở service layer SYS-CORE-BACKEND; web chỉ hiển thị lỗi/validation do core trả về và trạng thái machine-state.
- Không bao gồm: Cost Rate Card (FEAT-ERP-HRCORE-006 — chỉ tạo version cost rate đầu tiên của NV theo Rate Card đang hiệu lực), HĐLĐ (FEAT-ERP-HRCORE-002), chấm công/nghỉ phép (FEAT-003/004), KPI/PIP (module khác); freelancer ngoài biên chế không tạo hồ sơ (tính chi phí dịch vụ).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive (Next.js); mọi thao tác duyệt/ghi log bất biến ở core, web hiển thị đúng trạng thái machine-state trả về từ API.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Duyệt requisition headcount trên hàng đợi web (vượt kế hoạch năm → chuyển BOD) | Không đăng tin tuyển khi chưa có phê duyệt nhu cầu nhân sự |
| 2 | HR_L1 | Tạo hồ sơ mới qua form có kiểm tra trùng tự động và mã NV tự sinh | Mỗi người đúng 1 hồ sơ, dữ liệu chuẩn ngay từ onboarding |
| 3 | HR_L1 | Chạy onboarding checklist (ký HĐLĐ, tài khoản, buddy, mục tiêu thử việc) theo tiến độ trên web | 100% checklist là điều kiện đầu vào đánh giá hết thử việc, không sót bước |
| 4 | SYS_ADMIN | Kích hoạt tài khoản theo lệnh cấp RBAC hệ thống phát tự động theo mã vai | Không cấp tay quyền ngoài lệnh, quyền gắn đúng mã vai hiện hành |
| 5 | Manager (chức danh gán theo hồ sơ) | Đề xuất thay đổi Level/vai của nhân sự nhóm mình qua web | Thăng tiến/điều chuyển đi đúng trình tự thẩm định, không sửa trực tiếp hồ sơ |
| 6 | HR_L2 | Thẩm định đề xuất đổi Level/vai và trình BOD duyệt trên web | Đổi Level có căn cứ chuẩn năng lực + KPI 2 chu kỳ, version mới tự hiệu lực từ ngày duyệt |
| 7 | HR_L1 | Tạo hồ sơ thôi việc kèm ngày hiệu lực + căn cứ pháp lý, theo dõi checklist thu hồi | Offboarding chặt chẽ: 24h thu hồi quyền ERP, 24h thu hồi TKQC do OPS thực thi và xác nhận |
| 8 | HR_L2 | Xem timeline version của mọi hồ sơ (mã vai, Level, trạng thái theo từng khoảng hiệu lực) | Truy vết được lịch sử nhân sự và tái lập báo cáo tại bất kỳ thời điểm nào |

Quy ước xuyên suốt: web là mặt làm việc, core là nơi enforce; HR_L1 chỉ thao tác dữ liệu thường (không xem lương — C1 masked), HR_L2 có quyền sửa cả trường nhạy cảm, mọi lượt xem/sửa C1 được log.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Validation cứng nằm ở service layer SYS-CORE-BACKEND; web không có đường tắt UI nào né luật.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: RBAC, hoa hồng, P&L, KPI đọc chung không bản sao; nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative, salary band Q2/2026 làm tham chiếu khi cấu hình Level). | Module nào tự giữ bản sao hồ sơ bị loại ở review kiến trúc; sai lệch SSOT tạo discrepancy ticket |
| BR-002 | 1 người 1 hồ sơ (validate duy nhất theo CCCD/mã định danh), được gán nhiều mã vai; mã NV tự sinh không tái sử dụng. | Tạo hồ sơ trùng bị chặn, form cảnh báo bản ghi trùng hiện có để người dùng rà lại |
| BR-003 | Mọi thay đổi mã vai/Level/trạng thái là version SCD2 mới hiệu lực từ ngày–đến ngày, cấm sửa đè quá khứ; RBAC/hoa hồng/P&L/KPI tự đọc version mới, báo cáo quá khứ tái lập bằng version cũ. | Yêu cầu UPDATE đè lịch sử bị core từ chối; chỉ được tạo version mới có hiệu lực hợp lệ |
| BR-004 | Onboarding: requisition phải được HR_L2 duyệt trước khi đăng tin (vượt kế hoạch năm → BOD duyệt); onboarding checklist 100% hoàn thành là điều kiện đầu vào đánh giá hết thử việc; freelancer ngoài biên chế không tạo hồ sơ. | Đăng tin trước duyệt hoặc tạo hồ sơ freelancer bị chặn; đánh giá hết thử việc khi checklist <100% bị khóa luồng |
| BR-005 | Offboarding: duyệt hồ sơ thôi việc → CORE vô hiệu hóa tài khoản ERP + toàn bộ quyền RBAC trong 24h; thu hồi TKQC phát yêu cầu cho OPS trong 24h, OPS thực thi trên TKQC Registry + nền tảng Ads và xác nhận lại (HR quản SLA, OPS thực thi — ranh giới REQ-HR-001). | Quá 24h phát cảnh báo SLA cho HR_L2; offboarding chưa xác nhận OPS không đóng trạng thái "Nghỉ việc" |
| BR-006 | Hồ sơ mới → lệnh cấp RBAC theo mã vai (không cấp tay ngoài lệnh); trạng thái "Nghỉ việc" lưu theo retention luật định, không xóa cứng; nghỉ không lương >30 ngày → đóng băng allocation/capacity, KPI prorate/miễn theo xác nhận HR_L2. | Cấp quyền ngoài lệnh bị log bất thường; hồ sơ nghỉ việc bị xóa cứng bị chặn — chỉ chuyển retention |
| BR-007 | Trường C1 (CCCD, lương, TK ngân hàng, dữ liệu y tế) mã hóa khi lưu/truyền, hiển thị masked cho mọi vai không có quyền; HR_L1 không xem lương; mọi lượt xem/sửa C1 có audit log bất biến (ai — khi nào — trước/sau). | Truy cập C1 sai quyền bị từ chối tầng API + log attempt; xuất raw C1 không được phép |
| BR-008 | Hồ sơ là SSOT cho các quy tắc nền của lane: HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime; nghỉ phép 12 ngày/năm với số dư tự động và duyệt phân cấp; Cost Rate Card version hóa do HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt với billable ghi nhận tại nguồn. | Thiếu hồ sơ/mã vai thì các phân hệ trên không hoạt động; dữ liệu lệch hồ sơ bị từ chối ghi nhận |
| BR-009 | Delegate duyệt timesheet cho TL vẫn ở mức chưa chốt — assumption có tag `[KXN-DTS]` (SO3-09 nhóm D): spec hiện hành không mở delegate, nguyên tắc approver ≠ người ghi; khi chủ dự án chốt sẽ cập nhật lại BR này. | Không cấu hình được delegate duyệt trong bản này; yêu cầu delegate bị từ chối kèm ghi chú chờ chốt |
| BR-010 | Mọi thao tác ghi/sửa/duyệt trên hồ sơ có audit log bất biến kèm kênh thao tác (web) và lý do khi HR_L2 yêu cầu; audit log append-only. | Xóa/sửa log bị chặn cứng; thao tác thiếu log bị coi là vi phạm bảo mật PII (REQ-HR-010) |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. TL/Manager là chức danh tổ chức gán qua trường "TL trực tiếp" trong hồ sơ (không phải vai registry riêng), quyền duyệt của họ gắn theo quan hệ hồ sơ.

| Hành động | HR_L1 | HR_L2 | BOD_CEO/BOD_CFO_CTO | SYS_ADMIN |
|-----------|-------|-------|---------------------|-----------|
| Xem hồ sơ (trường thường) | ✅ | ✅ | ✅ (theo báo cáo) | ❌ (không xem giá trị) |
| Xem trường C1 (lương, CCCD) | ❌ (masked) | ✅ | ✅ | ❌ (masked) |
| Tạo/sửa hồ sơ (thường) | ✅ | ✅ | ❌ | ❌ |
| Sửa trường C1 | ❌ | ✅ | ❌ | ❌ |
| Duyệt requisition headcount | ❌ | ✅ | ✅ (vượt kế hoạch năm) | ❌ |
| Đề xuất đổi Level/vai | ❌ | ✅ (thẩm định + trình) | ❌ (nhận trình duyệt) | ❌ |
| Duyệt đổi Level/vai | ❌ | ❌ | ✅ | ❌ |
| Tạo/duyệt hồ sơ thôi việc | ✅ (tạo) | ✅ (duyệt) | ❌ | ❌ |
| Kích hoạt/vô hiệu hóa tài khoản theo lệnh RBAC | ❌ | ❌ | ❌ | ✅ (thực thi lệnh) |
| Xem timeline version + audit log | ✅ | ✅ | ✅ | ✅ (xem log, xem log cũng bị log) |

Không ai tự duyệt hồ sơ do chính mình tạo: HR_L1 tạo → HR_L2 duyệt; HR_L2 soạn trình → BOD duyệt. SYS_ADMIN chỉ thực thi lệnh sau phê duyệt, không tự gán quyền kể cả cho mình.

---

## 5. Trường Hợp Đặc Biệt

- Thăng chức giữa chu kỳ: version mới của mã vai/Level hiệu lực từ ngày hiệu lực trong quyết định, version cũ đóng lại — hoa hồng, KPI, P&L tự chuyển sang version mới, không nhập tay từng phân hệ.
- Nghỉ không lương >30 ngày: hồ sơ chuyển trạng thái "Nghỉ không lương", hệ thống đóng băng allocation/capacity và đánh dấu KPI prorate/miễn; khi quay lại, HR_L2 xác nhận khôi phục trạng thái trước đó bằng version mới.
- Nhân sự kiêm nhiệm nhiều vai (ví dụ OPS_EDIT kiêm OPS_DES): 1 hồ sơ chứa nhiều dòng mã vai với khoảng hiệu lực riêng; RBAC phát lệnh theo từng vai, thu hồi từng vai khi hết hiệu lực mà không ảnh hưởng vai còn lại.
- Thu hồi TKQC khi OPS chưa xác nhận: offboarding giữ trạng thái "đang thu hồi" với nhãn SLA; HR_L2 thấy handoff queue, escalate nếu OPS quá 24h — không được đóng hồ sơ khi còn quyền TKQC sống.
- Freelancer/cộng tác viên dài hạn: không tạo hồ sơ nhân sự; nếu BOD yêu cầu rate tham chiếu riêng cho freelancer liên tục ≥3 tháng, xử lý ở FEAT-ERP-HRCORE-006, không đụng hồ sơ.
- Dữ liệu trùng khi nhập (trùng CCCD/tên–ngày sinh): form phát hiện và hiển thị hồ sơ nghiêm trùng để HR_L1 đối chiếu trước khi chặn tạo mới; nếu thật sự 2 người, HR_L2 xác nhận mở khóa tạo hồ sơ kèm ghi chú.
- Nhân sự thử việc không đạt: hồ sơ chuyển trạng thái kết thúc thử việc đúng ngày, gắn kết luận đánh giá (PASS/gia hạn 30 ngày kèm PIP/STOP theo quy trình HR v3.9) — luồng ký HĐLĐ chính thức do FEAT-ERP-HRCORE-002 sở hữu.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ nhân sự (EmployeeProfile) — trạng thái nhân sự; thay đổi trạng thái luôn tạo version SCD2 mới.

**Sơ đồ trạng thái:**
```
[PROBATION] ──(đạt thử việc + ký HĐ chính thức)──► [OFFICIAL]
    │                                                  │
    │ (STOP)                                           │ (đề nghị thôi việc được duyệt)
    ▼                                                  ▼
[TERMINATION_PENDING] ──(checklist thu hồi xong)──► [TERMINATED]
[OFFICIAL] ──(nghỉ dài/không lương >30 ngày)──► [LONG_LEAVE] ──(quay lại)──► [OFFICIAL]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PROBATION` (Thử việc) | Đánh giá đạt + ký HĐLĐ chính thức | `OFFICIAL` (Chính thức) | HR_L2 | Checklist onboarding 100%; đánh giá hết thử việc trước ≥3 ngày |
| `PROBATION` | Kết thúc thử việc (STOP) | `TERMINATION_PENDING` | HR_L2 | Căn cứ pháp lý + hồ sơ đánh giá |
| `OFFICIAL` | Đổi Level/vai | `OFFICIAL` (version mới) | BOD duyệt, core thực thi | Đã qua HR_L2 thẩm định; ngày hiệu lực rõ |
| `OFFICIAL` | Nghỉ dài/không lương | `LONG_LEAVE` | HR_L2 | >30 ngày → đóng băng allocation/capacity |
| `LONG_LEAVE` | Quay lại làm việc | `OFFICIAL` | HR_L2 | Xác nhận khôi phục, tạo version mới |
| `OFFICIAL`/`PROBATION` | Nộp/duyệt thôi việc | `TERMINATION_PENDING` | HR_L1 tạo, HR_L2 duyệt | Căn cứ Điều 34/35/36 BLLĐ 2019 |
| `TERMINATION_PENDING` | Hoàn tất checklist thu hồi | `TERMINATED` (Nghỉ việc) | Hệ thống | RBAC thu hồi ≤24h; OPS xác nhận thu hồi TKQC ≤24h; chốt phép/công/timesheet |

**Quy tắc:**
- `TERMINATED` là trạng thái kết thúc — không chuyển tiếp, chỉ đọc theo retention luật định; tái tuyển cùng người tạo hồ sơ mới với mã NV mới.
- Mọi chuyển trạng thái tạo version SCD2 kèm audit log bất biến; không sửa đè trạng thái cũ.
- `LONG_LEAVE` không tự hết hạn — quay lại do HR_L2 xác nhận; quá hạn HĐLĐ xử lý ở FEAT-ERP-HRCORE-002.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| EmployeeProfile | `employee_code`, `full_name`, `department`, `direct_tl_id`, `status`, `bhxh_no`, `bank_account` (C1) | FK → `department`, `users` | 1 người 1 hồ sơ; C1 mã hóa |
| EmployeeRoleVersion | `profile_id`, `role_code`, `level`, `effective_from`, `effective_to` | FK → `EmployeeProfile.id` | SCD2; nguồn RBAC/hoa hồng/P&L/KPI |
| OnboardingChecklist | `profile_id`, `item`, `done_at`, `owner` | FK → `EmployeeProfile.id` | 100% là điều kiện hết thử việc |
| OffboardingChecklist | `profile_id`, `rbac_revoked_at`, `tkqc_handoff_status`, `leave_settled`, `handover_done` | FK → `EmployeeProfile.id` | TKQC handoff do OPS xác nhận |
| RbacProvisioningCommand | `profile_id`, `role_code`, `command_type` (grant/revoke), `status` | FK → `EmployeeProfile.id` | Core phát tự động theo mã vai |
| EmployeeCostRateVersion | `profile_id`, `rate_version_id`, `effective_from` | FK → Rate Card version (FEAT-006) | Version đầu tiên theo Rate Card hiệu lực |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn hồ sơ trùng | Nhân sự A đã có hồ sơ | HR_L1 tạo hồ sơ thứ hai cùng CCCD | Core từ chối, form hiển thị hồ sơ trùng để đối chiếu | [ ] |
| SC-002: Đổi Level tạo version | NV mã vai OPS_EDIT L2 | BOD duyệt đề xuất lên L3 hiệu lực 01/10 | Version mới tự hiệu lực, version cũ đóng; báo cáo tháng 9 vẫn đọc version cũ | [ ] |
| SC-003: Offboard thu hồi 24h | NV nộp đơn thôi việc | HR_L2 duyệt hồ sơ thôi việc | RBAC thu hồi ≤24h; handoff TKQC phát cho OPS và được xác nhận; hồ sơ `TERMINATED` | [ ] |
| SC-004: Freelancer không tạo hồ sơ | HR_L1 nhập freelancer ngoài biên chế | Lưu hồ sơ | Bị chặn với lý do "freelancer tính chi phí dịch vụ, không tạo hồ sơ" | [ ] |
| SC-005: C1 masked | HR_L1 mở hồ sơ nhân sự | Xem trường lương/TK ngân hàng | Hiển thị masked; lượt truy cập bị log; mở raw bị từ chối | [ ] |
| SC-006: Đóng băng nghỉ không lương | NV nghỉ không lương từ 01/09 | Quá 30 ngày chưa quay lại | Allocation/capacity đóng băng, KPI đánh dấu prorate/miễn theo xác nhận HR_L2 | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-HR-001 (Mục 2 — tạo hồ sơ, SCD2, offboarding, freelancer, PII, nghỉ không lương).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/nhan-su-ho-so.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (master data + SCD2 + validation service layer) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track, salary band, entity TMS §9) |
