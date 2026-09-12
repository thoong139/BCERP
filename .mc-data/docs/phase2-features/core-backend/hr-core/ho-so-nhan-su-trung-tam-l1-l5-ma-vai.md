# Tính Năng: Hồ sơ nhân sự trung tâm L1–L5 + mã vai

> **Dựa trên:** REQ-HR-001 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-001` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-001 xuất hiện ở 2 hệ thống — **SYS-CORE-BACKEND** (bản spec này) và **SYS-BCERP-WEB** (counterpart: form nhập, timeline version, hàng đợi duyệt). Tại touchpoint core backend, tính năng là **headless API / domain service**: mọi business rule bắt buộc được enforce ở tầng service (không tin UI), mọi thao tác ghi có audit log bất biến và dữ liệu luôn xử lý trong phạm vi tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-001 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-001 |
| Người dùng liên quan | HR_L1, HR_L2 (thao tác chính); SYS_ADMIN (provisioning RBAC); BOD_CEO/BOD_CFO_CTO (duyệt vượt kế hoạch headcount); RBAC, hoa hồng, P&L, KPI (module đọc SSOT) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có (đây là feature master data của MOD-HR-CORE; các feature còn lại của module phụ thuộc feature này) |
| Ghi chú Expert (A7) | A7.2: định mức giờ/cost-per-hour L1–L5 dùng khung mặc định import từ payroll khi migration (chờ HR + FIN chốt); need mobile HR (duyệt khi di chuyển) ngoài scope SYS-MOBILE-INTERNAL hiện tại. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng nguồn sự thật duy nhất (SSOT) cho toàn bộ hồ sơ nhân sự trung tâm theo cấp Level L1–L5 kèm mã vai: mỗi nhân sự đúng 1 hồ sơ (được phép nhiều vai), mọi thay đổi Level/vai/trạng thái được version hóa hiệu lực từ ngày–đến ngày theo mô hình SCD2, không bao giờ ghi đè lịch sử. Hồ sơ này là đầu vào bắt buộc cho RBAC, hoa hồng, P&L, KPI và Cost Rate Card — các module đọc chung từ đây, không được giữ bản sao riêng.

**Phạm vi:**
- Bao gồm: entity hồ sơ nhân sự (mã NV, phòng ban, TL trực tiếp, mã vai + Level + ngày hiệu lực, trạng thái làm việc, BHXH, TK lương); version hóa SCD2 cho Level/vai/trạng thái; validate "1 người 1 hồ sơ, nhiều vai"; phát lệnh cấp/thu hồi tài khoản RBAC theo mã vai (onboarding 24h, offboard 24h); workflow duyệt Requisition headcount; API domain service cho các module tiêu thụ (RBAC/hoa hồng/P&L/KPI); audit log bất biến cho mọi thay đổi; mã hóa trường C1.
- Không bao gồm: màn hình form/timeline/queue trên web nội bộ (SYS-BCERP-WEB — counterpart); vòng đời HĐLĐ (FEAT-CORE-HRCORE-002); chấm công (FEAT-CORE-HRCORE-003); nghỉ phép (FEAT-CORE-HRCORE-004); self-service nhân viên (FEAT-CORE-HRCORE-005); Cost Rate Card (FEAT-CORE-HRCORE-006); ma trận PII/retention chi tiết (REQ-HR-010 — feature riêng của lane security); KPI/PIP (REQ-HR-007/008 — lane KPI-PERFORMANCE); quy tắc duyệt timesheet/capacity (REQ-HR-009 — ranh giới với DEPT-OPS).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` (HR Domain Knowledge Base, quy trình HR chuẩn v3.9, 4 track nghề: Sales / Business Ops / HCNS / Marketing-Creative với mã cấp KD-1..5, BO-1..4, HR-1..4, MK-1..4, salary band Q2/2026). Mã vai + Level trong hồ sơ SSOT phải map được với 4 track này và đối chiếu role taxonomy của PMS khi thiết kế bảng `employee`/`role` (mục 9 nguồn 03 — điểm cần làm rõ, giữ ở mức assumption `[KXN-18]` vì quy trình HR trong lifecycle v2.3 chưa được xác nhận chính thức).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L1 | Tạo hồ sơ nhân sự mới qua API với mã NV tự sinh, mã vai + Level + ngày hiệu lực, trạng thái "Thử việc" | Mỗi người chỉ có đúng 1 hồ sơ SSOT, trường C1 được mã hóa ngay khi lưu |
| 2 | HR_L2 | Duyệt Requisition headcount trước khi đăng tin, và chuyển cấp BOD khi vượt kế hoạch năm | Tuyển dụng không vượt khung headcount đã duyệt |
| 3 | HR_L2 | Thẩm định đề xuất đổi Level/vai (chuẩn năng lực + KPI 2 chu kỳ liên tiếp) trước khi trình BOD | Thay đổi Level có căn cứ, không tùy tiện |
| 4 | Hệ thống (domain service) | Tự tạo version SCD2 mới của mã vai/Level/trạng thái hiệu lực từ ngày và đóng version cũ khi BOD duyệt thăng chức | RBAC/hoa hồng/P&L/KPI tự đọc version mới, quá khứ tái lập được |
| 5 | SYS_ADMIN | Nhận lệnh cấp RBAC do hệ thống phát theo mã vai khi hồ sơ được kích hoạt | Không cấp tay ngoài lệnh, mọi lệnh có log |
| 6 | HR_L1 | Tạo version cost rate đầu tiên cho NV theo Rate Card đang hiệu lực, hiệu lực từ ngày làm việc đầu tiên | NV mới có cost chuẩn ngay từ ngày 1 (nối FEAT-CORE-HRCORE-006) |
| 7 | HR_L1 | Tạo hồ sơ thôi việc với ngày hiệu lực + căn cứ pháp lý (Điều 34/35/36 BLLĐ 2019) và mở checklist thu hồi | Offboard đúng pháp luật, thu hồi tài khoản ERP + quyền TKQC trong 24h (OPS thực thi, HR đo SLA) |
| 8 | Module tiêu thụ (RBAC/hoa hồng/P&L/KPI) | Truy vấn API đọc version hồ sơ hiện hành theo một mốc ngày bất kỳ | Không module nào phải cập nhật tay khi Level/vai thay đổi |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR1-01 | Mỗi nhân sự đúng 1 hồ sơ duy nhất (validate "1 người 1 hồ sơ"), cho phép 1 người gắn nhiều mã vai cùng lúc | API trả lỗi trùng hồ sơ kèm mã nhân sự xung đột để form counterpart cảnh báo |
| BR-HR1-02 | Mọi thay đổi Level/vai/trạng thái/cost tạo **version SCD2 mới** hiệu lực từ ngày–đến ngày; cấm UPDATE ghi đè giá trị đã hiệu lực trong quá khứ | Service từ chối ghi đè, bắt buộc đi qua lệnh tạo version mới |
| BR-HR1-03 | Đổi Level/vai: Manager đề xuất → HR_L2 thẩm định (chuẩn năng lực + KPI 2 chu kỳ liên tiếp) → BOD duyệt → hệ thống mới đóng version cũ | Không đủ chuỗi duyệt thì version mới không được tạo |
| BR-HR1-04 | Hồ sơ mới → hệ thống tự phát **lệnh cấp tài khoản RBAC theo mã vai**; trạng thái "Nghỉ việc" → lệnh thu hồi tài khoản ERP + toàn bộ quyền trong **24h**; yêu cầu thu hồi TKQC phát cho OPS trong 24h, OPS thực thi và xác nhận (HR quản SLA) | Provisioning ngoài lệnh hệ thống bị từ chối và ghi log vi phạm |
| BR-HR1-05 | Freelancer ngoài biên chế **không tạo hồ sơ** — tính như chi phí dịch vụ | API từ chối tạo hồ sơ cho đối tượng không trong biên chế |
| BR-HR1-06 | Nghỉ không lương **>30 ngày** → đóng băng allocation/capacity, KPI prorate/miễn theo xác nhận HR_L2 | Báo cáo capacity/KPI loại trừ nhân sự đóng băng, có ghi dấu trạng thái |
| BR-HR1-07 | Onboarding checklist đạt **100%** là điều kiện đầu vào đánh giá hết thử việc | Không cho mở đánh giá hết thử việc khi checklist chưa đủ |
| BR-HR1-08 | Requisition headcount do HR_L2 duyệt trước khi đăng tin; vượt kế hoạch năm → BOD duyệt trong 3 ngày làm việc | Không phát lệnh tuyển khi chưa có duyệt đủ cấp |
| BR-HR1-09 | Trường C1 (CCCD, lương, TK ngân hàng) mã hóa khi lưu và khi truyền; hiển thị masked cho mọi vai không có quyền | Xuất raw bị chặn ở service layer, mọi lượt xem/sửa có audit log bất biến |
| BR-HR1-10 | Mọi thao tác ghi/sửa/duyệt trên hồ sơ có **audit log bất biến** (ai — khi nào — giá trị trước/sau) trong phạm vi tenant isolation | Thiếu log thì giao dịch bị rollback |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime (chi tiết ở FEAT-CORE-HRCORE-002/003).
3. Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo nguồn 03 §8 (chi tiết ở FEAT-CORE-HRCORE-004).
4. Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn (chi tiết ở FEAT-CORE-HRCORE-006).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]` (SO3-09 nhóm D), không tự quyết; khi chưa chốt, hệ thống giữ rule nền "approver ≠ người ghi" và không bật cơ chế ủy quyền duyệt.

---

## 4. Phân Quyền

| Hành động | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN | Vai khác (18-vai registry) |
|-----------|-------|-------|------------------------|-----------|-----------------------------|
| Xem hồ sơ (trường C2/C3) | ✅ | ✅ | ✅ | ❌ (chỉ hạ tầng) | ❌ (chỉ xem dữ liệu mình qua ESS) |
| Xem lương/cost cá nhân (C1) | ❌ | ✅ | ✅ | ❌ | ❌ (manager chỉ xem tổng cost nhóm) |
| Tạo hồ sơ / cập nhật C2-C3 | ✅ | ✅ | ❌ | ❌ | ❌ |
| Sửa trường C1 | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt Requisition headcount | ❌ | ✅ | ✅ (vượt kế hoạch năm) | ❌ | ❌ |
| Thẩm định + trình duyệt đổi Level/vai | ❌ | ✅ | ✅ (duyệt cuối) | ❌ | ❌ (Manager đề xuất qua WEB) |
| Kích hoạt tài khoản theo lệnh RBAC | ❌ | ❌ | ❌ | ✅ (theo lệnh hệ thống) | ❌ |
| Xóa hồ sơ | ❌ | ❌ | ❌ | ❌ (chỉ vô hiệu hóa theo lệnh offboard) | ❌ |
| Xem audit log hồ sơ | ✅ (log thao tác) | ✅ | ✅ | ✅ (xem log cũng bị log) | ❌ |

> Không dùng vai ngoài 18-vai registry; không tồn tại vai OPS_CX / FIN_COMPL (đã bị stakeholder từ chối — DI-006). HR_L1 **không xem lương** theo ma trận REQ-HR-010.

---

## 5. Trường Hợp Đặc Biệt

- Thăng chức giữa chu kỳ: version mới có hiệu lực từ ngày hiệu lực thực tế (không đợi đầu quý), version cũ đóng lại nhưng vẫn truy vấn được để tái lập báo cáo quá khứ.
- Một người nhiều vai: mỗi vai là 1 dòng version riêng với khoảng hiệu lực độc lập; khi 1 vai kết thúc, các vai khác không bị ảnh hưởng.
- Nghỉ không lương kéo dài (>30 ngày): hồ sơ giữ trạng thái "Nghỉ dài/Nghỉ không lương", allocation/capacity đóng băng tự động, KPI kỳ tương ứng prorate hoặc miễn theo xác nhận HR_L2.
- Freelancer làm việc liên tục ≥3 tháng: không tạo hồ sơ biên chế, nhưng BOD có thể yêu cầu Cost Rate Card tham chiếu riêng (nối FEAT-CORE-HRCORE-006).
- Trùng lặp dữ liệu (cùng CCCD/tên): service phát hiện khi tạo và trả danh sách nghi ngờ trùng để HR gộp/chốt — không tự gộp âm thầm.
- Offboarding khi còn công/timesheet chưa duyệt: checklist thu hồi liệt kê hạng mục chốt phép chưa dùng, công chưa duyệt, bàn giao tài liệu–tài sản; dữ liệu chuyển chế độ retention theo REQ-HR-010 (không xóa cứng).
- Tenant isolation: mọi truy vấn API phải scope theo tenant hiện hành; test chấp nhận phải bao gồm case cross-tenant bị từ chối.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ nhân sự (bản ghi `employee` — trạng thái làm việc hiện hành đọc từ version SCD2 mới nhất)

**Sơ đồ trạng thái:**
```
[TẠO MỚI/THỬ VIỆC] ──(đạt đánh giá hết thử việc)──► [CHÍNH THỨC]
        │                                              │
        │ (không đạt)                                  ├──(nghỉ dài/không lương >30 ngày)──► [NGHỈ DÀI / KHÔNG LƯƠNG]
        ▼                                              │                                      │
   [KHÔNG ĐẠT THỬ VIỆC → CHẤM DỨT] ◄───────────────────┴──(thôi việc có căn cứ pháp lý)──► [NGHỈ VIỆC]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Thử việc | Đánh giá hết thử việc đạt | Chính thức | HR_L2 duyệt | Checklist onboarding 100%; đánh giá thực hiện trước khi kết thúc thử việc ≥3 ngày; HĐLĐ chính thức được ký (nối FEAT-CORE-HRCORE-002) |
| Thử việc | Đánh giá không đạt | Nghỉ việc | HR_L2 duyệt | Biên bản đánh giá + căn cứ pháp lý lưu hồ sơ |
| Chính thức | Đổi Level/vai (được duyệt) | Chính thức (version mới) | BOD duyệt sau thẩm định HR_L2 | Chuẩn năng lực + KPI 2 chu kỳ liên tiếp; tạo version SCD2, đóng version cũ |
| Chính thức / Nghỉ dài | Nghỉ không lương | Nghỉ dài / Không lương | HR_L2 duyệt | >30 ngày tự động đóng băng allocation/capacity |
| Chính thức / Thử việc / Nghỉ dài | Thôi việc | Nghỉ việc | HR_L1 tạo, HR_L2 duyệt | Ngày hiệu lực + căn cứ Điều 34/35/36 BLLĐ 2019; checklist thu hồi mở tự động; thu hồi quyền 24h |

**Quy tắc:**
- "Nghỉ việc" là trạng thái kết thúc — hồ sơ chỉ lưu theo retention luật định, không xóa cứng, không mở lại thành hồ sơ mới (tái tuyển = hồ sơ mới, mã NV mới).
- Mỗi lần chuyển trạng thái tạo version SCD2 với người duyệt, ngày hiệu lực, căn cứ; không thể quay về trạng thái trước nếu không qua một version mới có duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `employee` | `employee_code`, `full_name`, `department_id`, `direct_lead_id`, `status`, `bhxn_no`, `bank_account_enc` (C1) | FK → `department`, tự tham chiếu TL | 1 hồ sơ/người; soft delete cấm — chỉ chuyển trạng thái |
| `employee_role_version` | `employee_id`, `role_code`, `career_level`, `valid_from`, `valid_to`, `approved_by` | FK → `employee`, `role` | SCD2; version cũ đóng `valid_to`, không UPDATE |
| `role` | `role_code`, `career_track` (KD/BO/HR/MKT), `track_level` | FK → `career_track` | Map 4 track của HR v3.9; đối chiếu role taxonomy PMS |
| `career_level` | `level_code` (L1–L5/track level), `criteria`, `salary_band_ref` | — | Tham chiếu khung lương Q2/2026 (nguồn 03 mục 5) |
| `headcount_requisition` | `position`, `quantity`, `status`, `approver_id`, `plan_year` | FK → `department` | HR_L2 duyệt; vượt kế hoạch → BOD |
| `onboarding_checklist` | `employee_id`, `item`, `done_at`, `done_by` | FK → `employee` | 100% là điều kiện đánh giá hết thử việc |
| `offboarding_checklist` | `employee_id`, `revoke_erp_at`, `tkqc_handoff_status`, `leave_balance_settled` | FK → `employee` | Thu hồi 24h; handoff TKQC qua OPS có SLA đo |
| `audit_log` | `actor_id`, `entity`, `entity_id`, `before`, `after`, `at`, `tenant_id` | — | Bất biến (append-only), tenant isolated |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tạo hồ sơ trùng | Đã tồn tại hồ sơ cho 1 CCCD | HR_L1 gọi API tạo hồ sơ thứ hai | API trả lỗi "1 người 1 hồ sơ" kèm mã NV xung đột; không tạo bản ghi; có log | [ ] |
| SC-002: Đổi Level có đủ chuỗi duyệt | NV chính thức L2, BOD đã duyệt đổi L3 từ 01/10 | Service tạo version SCD2 | Version L2 đóng `valid_to` 30/09; version L3 hiệu lực 01/10; báo cáo tháng 9 vẫn dùng L2 | [ ] |
| SC-003: Offboard 24h | HR_L2 duyệt hồ sơ thôi việc | Hệ thống xử lý checklist | Tài khoản ERP + RBAC vô hiệu hóa ≤24h; yêu cầu thu hồi TKQC phát cho OPS kèm SLA đo; log đầy đủ | [ ] |
| SC-004: Cross-tenant bị chặn | Tenant A gọi API đọc hồ sơ của tenant B | Service kiểm tra scope | Trả 403/404, không lộ dữ liệu, sự kiện ghi log bảo mật | [ ] |

> **Liên kết:** Mỗi scenario map đến REQ-HR-001 (Mục 2 của `hr.md`) và các BR-HR1-01/02/04/10 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/ho-so-nhan-su.md` |
| Nguồn domain 4 track / salary band / vòng đời v3.9 | `documents/03_Quy_che_KPI_HR.md` (mục 2, 4, 5, 9) |
