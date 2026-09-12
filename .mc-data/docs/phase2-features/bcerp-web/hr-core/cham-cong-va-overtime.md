# Tính Năng: Chấm công & overtime

> **Dựa trên:** REQ-HR-003 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-003 → FEAT-ERP-HRCORE-003. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (validation cứng trần 48h + cộng dồn tuần ở service layer) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-003 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-003 — Chấm công & overtime (HIGH, MVP) |
| Người dùng liên quan | Nhân viên nội bộ (mọi vai registry), TL (duyệt OT/điều chỉnh), HR_L1 (xử lý tổng hợp), HR_L2 (duyệt OT vượt trần/retro), FIN_L1 (nhận tổng hợp payroll/BHXH) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP); tổng hợp công đối chiếu timesheet dự án ở GĐ2 |
| Phụ thuộc | FEAT-ERP-HRCORE-001 (hồ sơ SSOT — định mức giờ/tuần theo Level đọc từ hồ sơ) |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) xác nhận định mức giờ/tuần theo bậc có khung policy, chờ BOD duyệt chu kỳ năm → hệ thống cấu hình tham số effective-dated, không hardcode; need mobile ghi công ngoài scope SYS-MOBILE-INTERNAL hiện tại |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cho phép toàn bộ nhân viên BC Agency ghi công hằng ngày trên web nội bộ với giờ chuẩn 40h/tuần (T2–T6), quản lý overtime theo nguyên tắc "duyệt trước khi làm" và chặn cứng trần pháp lý 48h/tuần (Điều 107 BLLĐ 2019, trần năm 200h). Tính năng bảo đảm số công/OT dùng cho payroll và BHXH luôn chỉ tính giờ đã được duyệt, mọi điều chỉnh có người khác xác nhận kèm audit log — phục vụ cả tuân thủ lao động lẫn đối soát chi phí nhân sự.

**Phạm vi:**
- Bao gồm: màn ghi công hằng ngày (giờ vào/ra, giờ linh hoạt được phép nhưng hệ thống so định mức giờ/tuần theo Level), màn tổng hợp tuần của cá nhân và TL, màn đề nghị + duyệt OT (trần 8h OT/tuần do TL duyệt trước), luồng retro khẩn cấp trong 24h kèm lý do.
- Bao gồm: luồng đề nghị điều chỉnh công qua ESS — người khác duyệt (TL ≠ người đề nghị) với audit log giá trị trước/sau; nhắc thiếu giờ cho NV và TL khi cộng dồn tuần dưới định mức.
- Bao gồm: chốt tháng — tổng hợp công + OT đã duyệt bàn giao payroll/BHXH (handoff DEPT-FINANCE), FIN nhận số tổng hợp có log; tuần có ngày lễ giảm định mức tương ứng.
- Bao gồm: hiển thị chế tài nội quy theo `documents/03_Quy_che_KPI_HR.md` §8 (đi muộn/về sớm, quên chấm công) trong báo cáo công của HR, phục vụ quỹ phúc lợi.
- Không bao gồm: validation cứng trần 48h/tuần và trần 200h/năm — chạy kép ở service layer SYS-CORE-BACKEND (web chặn realtime khi nhập, core chặn lại khi duyệt); web chỉ hiển thị lỗi chặn.
- Không bao gồm: ghi timesheet theo dự án nhãn billable/non-billable và duyệt tuần timesheet (module CAPACITY-TIMESHEET — REQ-OPS-007/REQ-HR-009); tính lương OT thành tiền (payroll DEPT-FINANCE); nghỉ phép (FEAT-ERP-HRCORE-004).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; mọi giờ ghi ở múi giờ làm việc Việt Nam, dù làm việc đa múi giờ với khách.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên nội bộ | Ghi công hằng ngày trên web (giờ vào/ra linh hoạt, xem dồn tuần so định mức Level) | Đúng giờ chuẩn 40h/tuần mà vẫn linh hoạt khung giờ theo tính chất agency |
| 2 | Nhân viên nội bộ | Đăng ký OT trước khi làm với thời lượng và lý do | OT được duyệt trước, không làm xong mới bị từ chối thanh toán |
| 3 | TL | Duyệt/từ chối đăng ký OT của nhân sự nhóm trong trần 8h OT/tuần/người | Kiểm soát tổng giờ an toàn pháp lý trước khi phát sinh giờ thực |
| 4 | Nhân viên nội bộ | Ghi nhận OT khẩn cấp retro trong 24h kèm lý do sự cố | Sự cố ngoài giờ vẫn được ghi nhận hợp lệ khi không kịp xin trước |
| 5 | HR_L2 | Duyệt OT vượt trần tuần hoặc trần năm 200h trong 24h với lý do | Trường hợp đặc biệt có phê duyệt cấp cao, có vết pháp lý |
| 6 | Nhân viên nội bộ | Đề nghị điều chỉnh công khi quên ghi/ghi sai, có người khác duyệt | Số công chính xác mà không ai tự sửa công của chính mình |
| 7 | HR_L1 | Xem tổng hợp tuần/tháng theo phòng, xử lý ca thiếu giờ và điều chỉnh treo | Chốt công tháng đúng hạn, không sót ca cần xử lý |
| 8 | FIN_L1 | Nhận bảng tổng hợp công + OT đã duyệt của tháng kèm log bàn giao | Số liệu payroll/BHXH dùng được ngay, không nhận bảng công thô chưa duyệt |

Quy ước xuyên suốt: web chặn realtime khi nhập vượt trần, core chặn lại khi duyệt (validation kép); mọi điều chỉnh giữ bản gốc + giá trị trước/sau trong audit log bất biến.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Validation trần giờ chạy kép: chặn realtime ở web, chặn lại ở service layer SYS-CORE-BACKEND khi duyệt.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: định mức giờ/tuần theo Level, TL trực tiếp, trạng thái nhân sự đọc từ hồ sơ (FEAT-ERP-HRCORE-001); tham số định mức là cấu hình effective-dated do BOD duyệt chu kỳ năm; nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track). | Ghi công cho profile không hợp lệ/ngưng hoạt động bị từ chối; định mức hardcode trong code bị loại ở review |
| BR-002 | Giờ chuẩn 40h/tuần (T2–T6); giờ linh hoạt được phép nhưng cộng dồn tuần phải đạt định mức theo Level; tuần có ngày lễ giảm định mức tương ứng; thiếu giờ → nhắc NV + TL. | Tuần dưới định mức không tự tính đủ công — hiển thị thiếu giờ và nằm trong hàng đợi xử lý của HR_L1 |
| BR-003 | Chặn cứng tổng giờ chuẩn + OT > 48h/tuần (Điều 107 BLLĐ 2019) và OT > trần 200h/năm: web chặn realtime khi nhập, core chặn lại khi duyệt — không có đường nào ghi nhận giờ vượt trần không phê duyệt. | Lượt nhập/lượt duyệt vượt trần bị từ chối kèm thông báo mốc pháp lý; attempt ghi log |
| BR-004 | OT duyệt trước khi làm: TL duyệt trong trần 8h OT/tuần/người; sự cố khẩn cấp retro trong 24h kèm lý do bắt buộc; OT vượt trần tuần hoặc trần năm do HR_L2 duyệt trong 24h. | OT không có đăng ký được duyệt trước chỉ ghi nhận qua retro 24h; retro quá 24h bị từ chối, cần đề nghị điều chỉnh riêng |
| BR-005 | Điều chỉnh công phải do người khác duyệt (approver ≠ người đề nghị, kể cả cấp quản lý) + audit log giá trị trước/sau; bản ghi gốc giữ nguyên — correction, không UPDATE đè. | Tự duyệt điều chỉnh của chính mình bị core từ chối; sửa đè bản ghi gốc bị chặn, mọi thay đổi là bản ghi correction |
| BR-006 | Nghỉ phép 12 ngày/năm với số dư tự động và duyệt phân cấp là dữ liệu đầu vào: ngày nghỉ đã duyệt tự tính công theo loại nghỉ, không cần ghi công; nội quy nghỉ phép + chế tài xử phạt theo `03_Quy_che_KPI_HR.md` §8 — đi muộn/về sớm tính theo mốc (≤5 phút 0đ; 6–10 phút 20.000đ; 11–30 phút 30.000đ; 31–45 phút 50.000đ; 46–60 phút 70.000đ; từ 61 phút tính ½ ngày công; lần thứ 4/tháng x2 mốc; cấp quản lý x2; Intern Kinh doanh không áp dụng). | Ngày nghỉ chưa duyệt không được tính công; chế tài hiển thị sai mốc là lỗi tính toán bắt buộc sửa trước chốt tháng |
| BR-007 | Quên chấm công xử lý bằng luồng điều chỉnh có duyệt; theo §8, trường hợp không có bản ghi: 2 lần đầu/tháng có xác nhận đến/về đúng giờ thì vẫn tính công, từ lần thứ 3 không tính công buổi/ngày đó — hệ thống đếm tần suất theo tháng tự động. | Điều chỉnh không qua duyệt không cộng vào tổng công; đếm tần suất sai làm áp chế tài sai mốc |
| BR-008 | Cost Rate Card version hóa do HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt, billable ghi nhận tại nguồn: tổng công/OT của tháng chỉ là đầu vào payroll; giờ làm việc gán dự án (billable) ghi ở timesheet riêng (CAPACITY-TIMESHEET) và chỉ giờ approved được nhân Rate Card vào P&L — chấm công không tự suy ra chi phí. | Gộp nhầm tổng công chấm công vào báo cáo chi phí P&L bị chặn; hai tập dữ liệu giữ tách bạch theo module |
| BR-009 | Delegate duyệt timesheet cho TL vẫn ở mức chưa chốt — assumption có tag `[KXN-DTS]` (SO3-09 nhóm D): luồng duyệt OT/điều chỉnh công không mở delegate trong bản này; khi chốt sẽ cập nhật BR cùng luồng timesheet. | Nút/parameter delegate không hiển thị; yêu cầu delegate bị từ chối kèm ghi chú chờ chốt |
| BR-010 | Ghi công theo giờ làm việc Việt Nam bất kể làm đa múi giờ với khách; tổng hợp chốt tháng đóng gói số đã duyệt bàn giao FIN có log handoff (ai, khi nào, kỳ nào) — FIN không nhận bảng thô. | Bản ghi giờ theo múi giờ khác VN bị quy đổi về VN khi lưu; chốt tháng thiếu log handoff không được FIN chấp nhận |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. TL là chức danh tổ chức gán qua trường "TL trực tiếp" trong hồ sơ (FEAT-ERP-HRCORE-001), không phải vai registry riêng.

| Hành động | Nhân viên (mọi vai) | TL | HR_L1 | HR_L2 | FIN_L1 |
|-----------|--------------------|----|-------|-------|--------|
| Ghi công của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem công của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem tổng hợp công nhóm/phòng | ❌ | ✅ (nhóm mình) | ✅ | ✅ | ✅ (theo kỳ payroll) |
| Đăng ký OT của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duyệt OT ≤8h/tuần | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt OT vượt trần tuần/năm, retro | ❌ | ❌ | ❌ | ✅ (24h) | ❌ |
| Đề nghị điều chỉnh công của mình | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duyệt điều chỉnh công | ❌ | ✅ (≠ người đề nghị) | ❌ | ✅ | ❌ |
| Chốt tháng + bàn giao payroll | ❌ | ❌ | ✅ (thực hiện) | ✅ (duyệt chốt) | ✅ (nhận có log) |
| Xem chế tài đi muộn/phạt theo §8 | ❌ (chỉ của mình) | ✅ (nhóm mình) | ✅ | ✅ | ✅ (theo kỳ payroll) |

Không ai tự duyệt OT/điều chỉnh công của chính mình — kể cả TL và HR_L2: đăng ký của TL do quản lý cấp trên duyệt, đăng ký của HR do HR_L2 duyệt. Mọi lượt duyệt ghi người duyệt, thời điểm và lý do (nếu có) vào audit log bất biến.

---

## 5. Trường Hợp Đặc Biệt

- Quên ghi công: nhân viên đề nghị điều chỉnh qua ESS, TL duyệt với audit log; nếu trùng ca không có bản ghi lần thứ 3 trong tháng, hệ thống áp quy định §8 — không tính công buổi/ngày đó, HR_L1 thấy nhãn tần suất để giải trình.
- Làm đa múi giờ với khách (chạy campaign cho khách múi giờ khác): toàn bộ giờ ghi theo giờ làm việc VN; web hiển thị tham chiếu múi giờ khách nhưng không dùng để tính công.
- OT khẩn cấp xử lý sự cố ngoài giờ (site down, chiến dịch lỗi khuya): nhân viên ghi retro trong 24h kèm lý do; nếu kéo dài vượt trần tuần, lượt duyệt tự chuyển hàng đợi HR_L2 — không bị kẹt ở TL.
- Tuần lễ/tết: định mức tuần giảm theo số ngày lễ; công dư do lễ không bị tính là thiếu giờ, OT trong tuần lễ vẫn áp trần 48h trên định mức đã giảm.
- Nhân sự nghỉ không lương >30 ngày (hồ sơ `LONG_LEAVE`): kỳ chấm công tạm dừng sinh thiếu giờ; khi quay lại, định mức tính lại từ ngày hiệu lực version mới.
- Nhân sự thử việc/Intern: vẫn ghi công đầy đủ; Intern Kinh doanh được gắn flag miễn chế tài đi muộn theo §8 — số công vẫn ghi nhận đầy đủ phục vụ đánh giá.
- Tranh chấp số công khi chốt tháng: các điều chỉnh đang chờ duyệt không cộng vào tổng chốt; HR_L1 có thể hoãn chốt cá nhân đó, chốt phần còn lại — không chặn toàn phòng.
- Nhân sự chuyển phòng giữa tháng: công trước/sau chuyển ngày ghi theo phòng tương ứng trong khoảng hiệu lực version hồ sơ (SCD2), tổng tháng không mất mát.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi công ngày (AttendanceDay) và Đăng ký OT (OvertimeRequest).

**Sơ đồ trạng thái:**
```
AttendanceDay:
[MISSING] ──(NV ghi)──► [RECORDED] ──(chốt tháng)──► [LOCKED]
[RECORDED] ──(đề nghị điều chỉnh + duyệt)──► [CORRECTED] ──(chốt tháng)──► [LOCKED]

OvertimeRequest:
[REQUESTED] ──(TL duyệt)──► [APPROVED] ──(ghi giờ thực)──► [CONFIRMED] ──(chốt tháng)──► [LOCKED]
[REQUESTED] ──(từ chối)──► [REJECTED]
[REQUESTED (vượt trần)] ──(HR_L2 duyệt 24h)──► [APPROVED]
[CONFIRMED (retro quá trần)] ──(HR_L2 duyệt)──► [APPROVED_OVERRIDDEN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `MISSING` | Ghi công | `RECORDED` | Nhân viên (của mình) | Không vượt trần 48h khi cộng dồn tuần |
| `RECORDED` | Điều chỉnh được duyệt | `CORRECTED` | TL/HR_L2 ≠ người đề nghị | Lý do bắt buộc; audit log trước/sau |
| `REQUESTED` | TL duyệt OT | `APPROVED` | TL (≠ người đăng ký) | Tổng OT tuần ≤8h |
| `REQUESTED` | TL từ chối | `REJECTED` | TL | Lý do bắt buộc |
| `REQUESTED` | Vượt trần tuần/năm → HR_L2 duyệt | `APPROVED` | HR_L2 (24h) | Lý do bắt buộc; không vượt 48h tổng |
| `APPROVED` | Ghi nhận giờ OT thực tế | `CONFIRMED` | Nhân viên | Giờ thực ≤ giờ duyệt (dư bỏ) |
| `RECORDED`/`CONFIRMED` | Chốt tháng | `LOCKED` | HR_L1 thực hiện, HR_L2 duyệt | Log handoff payroll sinh kèm |

**Quy tắc:**
- `LOCKED` là trạng thái kết thúc kỳ — sửa chỉ được bằng mở kỳ có phê duyệt và correction có audit log, không sửa đè.
- `REJECTED` kết thúc lượt đăng ký OT; đăng ký lại tạo lượt mới.
- `CONFIRMED` retro quá 24h không tạo được — quay về luồng điều chỉnh công riêng (BR-005).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| AttendanceDay | `profile_id`, `work_date`, `check_in`, `check_out`, `status`, `late_minutes` | FK → `EmployeeProfile.id` | Giờ VN; tuần lễ giảm định mức |
| OvertimeRequest | `profile_id`, `requested_hours`, `actual_hours`, `reason`, `status`, `approver_id` | FK → `EmployeeProfile.id` | Duyệt trước; retro 24h |
| AttendanceCorrection | `attendance_id`, `before_value`, `after_value`, `reason`, `requested_by`, `approved_by` | FK → `AttendanceDay.id` | Approver ≠ requester |
| AttendanceMonthlySummary | `profile_id`, `period`, `standard_hours`, `ot_approved_hours`, `violation_summary` | FK → `EmployeeProfile.id` | Đầu vào payroll/BHXH có log |
| PayrollHandoffLog | `period`, `handed_by`, `approved_by`, `handed_to`, `checksum` | — | Handoff DEPT-FINANCE |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn realtime vượt 48h | NV đã cộng dồn 46h trong tuần | Nhập thêm 4h | Web từ chối ngay với thông báo Điều 107 BLLĐ; core chặn lại nếu lọt qua API | [ ] |
| SC-002: OT duyệt trước trong trần | TL duyệt OT 4h | NV ghi giờ thực 3h | Tổng OT tuần cộng đúng 3h thực tế, phần duyệt dư không cộng | [ ] |
| SC-003: Retro 24h | Sự cố khẩn 22:00 ngày 01/09 | NV ghi retro 20:00 ngày 02/09 kèm lý do | Chấp nhận hợp lệ; ghi retro 26/09 sau 24h bị từ chối | [ ] |
| SC-004: Không tự duyệt điều chỉnh | NV đề nghị sửa công của mình | Người đề nghị bấm duyệt | Core từ chối (approver ≠ requester), chỉ TL/HR khác duyệt được | [ ] |
| SC-005: Chế tài đi muộn theo §8 | NV đi muộn 15 phút lần thứ 4 trong tháng | Chốt tổng hợp | Phạt 30.000đ x2 = 60.000đ hiển thị đúng mốc §8; Intern Kinh doanh được miễn | [ ] |
| SC-006: Chốt tháng handoff FIN | Tháng 08 đã khóa | HR chốt và bàn giao | FIN nhận tổng hợp công + OT đã duyệt kèm log handoff; bảng thô không truyền đi | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-HR-003 (Mục 2 — ghi công, OT duyệt trước, trần 48h/200h, điều chỉnh có duyệt, tổng hợp payroll).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/cham-cong-ot.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (validation trần giờ + cộng dồn tuần) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (§8 chế tài, §9 entity TMS) |
