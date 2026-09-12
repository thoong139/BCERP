# Tính Năng: Cost Rate Card version hóa, thẩm định finance

> **Dựa trên:** REQ-HR-006 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-006 → FEAT-ERP-HRCORE-006. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (version store bất biến + lookup theo ngày ghi giờ ở service layer — đầu vào P&L/BI) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-006 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-006 — Cost Rate Card version hóa, thẩm định finance (HIGH, MVP) |
| Người dùng liên quan | HR_L2 (soạn/đề xuất), FIN_L2 (thẩm định đối chiếu payroll), BOD_CEO/BOD_CFO_CTO (duyệt phát hành), gián tiếp P&L/BI (đọc version theo ngày ghi giờ) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP); duyệt lại chu kỳ năm |
| Phụ thuộc | FEAT-ERP-HRCORE-001 (hồ sơ SSOT — Level/thời gian hiệu lực của nhân sự kế thừa SCD2); dữ liệu payroll thực tế từ DEPT-FINANCE dùng cho đối chiếu thẩm định |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) ghi nhận giá trị cost/hour từng Level chưa có số — dùng khung mặc định import từ payroll khi migration, HR + FIN chốt; ngưỡng lệch rate–payroll đề xuất ±10% `[CẦN CHỐT SỐ]` |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng quản lý bảng cost/hour chuẩn theo Level trên web nội bộ với cơ chế version hóa SCD2 (hiệu lực từ ngày–đến ngày) và vòng đời duyệt 3 chặn: HR_L2 soạn → FIN_L2 thẩm định (đối chiếu payroll thực tế) → BOD duyệt phát hành. Version đã phát hành là bất biến; P&L và báo cáo dự án chọn đúng version theo ngày ghi giờ — chi phí hạch toán nhất quán, không sửa quá khứ, là đầu vào trực tiếp của báo cáo lợi nhuận theo dự án.

**Phạm vi:**
- Bao gồm: màn soạn dự thảo Rate Card (cost/hour theo Level, khoảng hiệu lực từ ngày–đến ngày) của HR_L2; màn thẩm định FIN_L2 hiển thị bảng đối chiếu rate đề xuất vs payroll thực tế theo Level kèm phần trăm lệch; màn trình duyệt BOD và kết quả phát hành version (số version tự tăng, người duyệt, timestamp).
- Bao gồm: màn tra cứu version theo khoảng thời gian (timeline, trạng thái hiệu lực), lịch sử duyệt đầy đủ (ai soạn, ai thẩm định, ai duyệt, lý do trả về), và màn migration mở sổ — import khung mặc định từ payroll thực tế để tạo version đầu tiên do BOD xác nhận phát hành, kèm lịch duyệt lại chu kỳ năm.
- Không bao gồm: version store bất biến và lookup theo ngày ghi giờ — chạy ở service layer SYS-CORE-BACKEND; web chỉ soạn thảo, đối chiếu, trình duyệt và hiển thị trạng thái machine-state.
- Không bao gồm: tính chi phí P&L (module DATAHUB-BI/FINANCE nhân giờ approved × rate), lương thực trả cá nhân (payroll DEPT-FINANCE — Rate Card là cost chuẩn, không phải bảng lương), và giá cost/hour của freelancer (ngoài biên chế, chỉ rate tham chiếu riêng khi BOD yêu cầu).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; dữ liệu payroll dùng đối chiếu được đọc từ FIN, quyền Restricted enforce ở core (FIN_L2 chỉ đọc trong giai đoạn thẩm định, có log).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Soạn dự thảo Rate Card mới (cost/hour theo Level, hiệu lực từ ngày) trên web | Đề xuất điều chỉnh cost chuẩn theo salary band và payroll thực tế một cách có hệ thống |
| 2 | FIN_L2 | Thấy bảng đối chiếu rate đề xuất vs payroll thực tế theo Level với % lệch | Thẩm định có căn cứ số, trả về kèm lý do khi lệch quá ngưỡng |
| 3 | FIN_L2 | Trả về dự thảo kèm lý do khi lệch quá ngưỡng cho phép (đề xuất ±10% `[CẦN CHỐT SỐ]`) | Không phát hành rate làm méo chi phí so với payroll thực tế |
| 4 | BOD_CEO/BOD_CFO_CTO | Duyệt/từ chối dự thảo đã qua thẩm định với ngữ cảnh đầy đủ (bảng đối chiếu, lịch sử version) | Quyết định phát hành version mới là quyết định của lãnh đạo, có vết duyệt |
| 5 | HR_L2 | Xem timeline các version Rate Card (hiệu lực từ–đến, số version, người duyệt) | Tra cứu đúng rate áp dụng cho bất kỳ khoảng thời gian nào trong quá khứ |
| 6 | BOD_CEO | Chốt giá cost/hour từng Level khi migration mở sổ và duyệt lại chu kỳ năm | Con số mở sổ là quyết định lãnh đạo, không phải giá trị hệ thống tự sinh |

Quy ước xuyên suốt: cost là dữ liệu Confidential/Restricted; mọi lượt xem/sửa trong phạm vi cho phép đều có audit log bất biến — chi tiết tại BR-008, Mục 4.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Version store và lookup theo ngày ghi giờ chạy ở service layer SYS-CORE-BACKEND; web không có đường sửa version đã phát hành.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: Rate Card định nghĩa cost/hour theo Level; nhân sự áp rate theo Level hiện hành tại thời điểm ghi giờ, kế thừa SCD2 hồ sơ (thăng Level giữa năm tự áp rate mới từ ngày hiệu lực); nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track, salary band Q2/2026 làm tham chiếu). | Rate cá nhân lệch khung Level của hồ sơ bị phát hiện là lỗi dữ liệu; nhập tay rate theo từng người bị từ chối |
| BR-002 | HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime (quy tắc nền lane): Rate Card chỉ nhân với giờ đã duyệt — giờ chờ duyệt không lẫn vào báo cáo cost; trạng thái giờ đọc từ chấm công/timesheet. | Nhân rate với giờ chưa duyệt làm lệch P&L là lỗi nghiêm trọng; trạng thái sai là lỗi liên kết dữ liệu |
| BR-003 | Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo `03_Quy_che_KPI_HR.md` §8: ngày nghỉ đã duyệt tự loại khỏi giờ rate-able — Rate Card không tính cost cho ngày nghỉ không làm việc trừ khi loại nghỉ có hưởng lương theo policy (đánh dấu riêng). | Tính cost cho ngày nghỉ chưa duyệt là lỗi đầu vào; phân biệt loại nghỉ có/không hưởng lương phải rõ theo cấu hình |
| BR-004 | Cost Rate Card version hóa: dự thảo HR_L2 soạn → FIN_L2 thẩm định (bảng đối chiếu payroll; lệch quá ngưỡng đề xuất ±10% `[CẦN CHỐT SỐ]` → trả về kèm lý do) → BOD duyệt → core phát hành version mới (số version tự tăng, người duyệt, timestamp); version đã phát hành bất biến — sai sót xử lý bằng version mới hiệu lực từ ngày khác, version cũ đóng lại giữ history. | Sửa version đã phát hành bị chặn cứng; duyệt nhảy bước (bỏ thẩm định) bị core từ chối; trả về không lý do không hợp lệ |
| BR-005 | P&L và báo cáo dự án chọn version theo ngày ghi giờ (không theo ngày chốt P&L, không theo ngày chốt báo cáo); nếu không có version phủ ngày ghi giờ → dùng version gần nhất trước đó + gắn cờ dữ liệu cho FIN kiểm tra. | Báo cáo dùng version sai thời điểm là lỗi tính toán; khoảng thiếu version không gắn cờ làm FIN không rà được là lỗi hiển thị |
| BR-006 | Billable ghi nhận tại nguồn: nhãn Client Billable/Internal Non-billable do người ghi timesheet chọn khi ghi, cấm sửa nhãn sau ghi (correction có audit log); Rate Card nhân đúng giờ đã duyệt theo nhãn tại nguồn. | Sửa nhãn billable sau khi cost đã allocate là thao tác cấm; chênh lệch phát sinh tạo discrepancy ticket FIN_L2 |
| BR-007 | Giá trị cost/hour từng Level `[CẦN CHỐT SỐ]`: khung mặc định import từ payroll thực tế khi migration mở sổ, BOD xác nhận phát hành version đầu tiên; duyệt lại chu kỳ năm; hệ thống không tự sinh con số cost/hour không qua duyệt. | Bất kỳ version nào không có người duyệt + timestamp không được coi là hiệu lực; import thiếu xác nhận BOD không mở sổ được |
| BR-008 | Quyền Restricted theo REQ-HR-010: chỉ HR_L2 + BOD xem cost/hour cá nhân; FIN_L2 có quyền đọc trong giai đoạn thẩm định (ghi log); HR_L1 không xem cost cá nhân; manager chỉ xem tổng cost nhóm mình; dữ liệu PII/cost không xuất hiện trên Client Portal. | Truy cập cost sai vai/giai đoạn bị từ chối tầng API + log attempt; lộ cost cá nhân ra ngoài phạm vi là sự cố bảo mật PII |
| BR-009 | Delegate duyệt timesheet cho TL vẫn ở mức chưa chốt — assumption có tag `[KXN-DTS]` (SO3-09 nhóm D): luồng duyệt Rate Card không có delegate — HR_L2 soạn, FIN_L2 thẩm định, BOD duyệt là cố định; vắng người thì luồng treo có nhãn chờ, không ủy quyền. | Không hiển thị cấu hình delegate; yêu cầu ủy quyền duyệt Rate Card bị từ chối kèm ghi chú chờ chốt |
| BR-010 | Freelancer liên tục ≥3 tháng: BOD có thể yêu cầu rate tham chiếu riêng (không tạo hồ sơ nhân sự); rate tham chiếu cũng version hóa và bất biến như Rate Card chính, đánh dấu loại "tham chiếu" để tách bạch với cost nhân sự chính thức. | Freelancer không có hồ sơ không được gắn rate của nhân viên chính thức; rate tham chiếu không đánh dấu loại làm nhầm báo cáo cost |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. Dữ liệu cost là Restricted — mọi lượt xem ngoài phạm vi đều bị chặn và log.

| Hành động | HR_L1 | HR_L2 | FIN_L2 | BOD_CEO/BOD_CFO_CTO |
|-----------|-------|-------|--------|---------------------|
| Xem Rate Card đang hiệu lực (khung theo Level) | ✅ (không cost cá nhân) | ✅ | ✅ | ✅ |
| Xem cost/hour cá nhân cụ thể | ❌ | ✅ | ✅ (chỉ khi thẩm định, log) | ✅ |
| Soạn dự thảo Rate Card mới | ❌ | ✅ | ❌ | ❌ |
| Thẩm định đối chiếu payroll | ❌ | ❌ | ✅ | ❌ |
| Trả về dự thảo kèm lý do | ❌ | ❌ | ✅ | ✅ (trả về khi duyệt) |
| Duyệt phát hành version mới | ❌ | ❌ | ❌ | ✅ |
| Sửa version đã phát hành | ❌ | ❌ | ❌ | ❌ (bất biến) |
| Xem timeline + lịch sử duyệt version | ✅ (metadata) | ✅ | ✅ | ✅ |
| Xem tổng cost nhóm (manager/TL) | ❌ | ✅ | ✅ | ✅ (toàn công ty) |
| Import khung mặc định khi migration | ❌ | ✅ (soạn) | ✅ (đối chiếu) | ✅ (xác nhận phát hành) |

Không ai tự duyệt dự thảo do chính mình soạn: HR_L2 soạn → FIN_L2 thẩm định → BOD duyệt là chuỗi 3 vai tách bạch (SoD); FIN_L2 thẩm định chỉ trong giai đoạn chờ, sau phát hành quyền đọc quay về phạm vi thường với log. SYS_ADMIN không xem giá trị cost (chỉ hạ tầng).

---

## 5. Trường Hợp Đặc Biệt

- Migration mở sổ lần đầu: chưa có version nào — HR_L2 import khung mặc định từ payroll thực tế tạo dự thảo version đầu; FIN_L2 đối chiếu ngược payroll; BOD xác nhận phát hành; trước đó mọi báo cáo cost hiển thị "chưa có Rate Card hiệu lực" thay vì 0.
- Thăng Level giữa năm: nhân sự lên Level mới hiệu lực 15/06 — giờ trước 15/06 nhân rate Level cũ, giờ sau đó nhân rate Level mới, toàn bộ theo version + SCD2 hồ sơ; không cần điều chỉnh báo cáo đã chốt.
- Version hiệu lực tương lai: BOD duyệt version mới hiệu lực 01/01 năm sau — báo cáo vẫn dùng version hiện hành đến khi version mới active; version tương lai hiển thị "chờ hiệu lực".
- Khoảng hở version (version cũ hết 31/12, version mới quên phát hành): báo cáo từ 01/01 dùng version gần nhất trước đó kèm cờ dữ liệu; FIN_L2 thấy hàng đợi cờ và thúc phát hành — dữ liệu không tự dừng nhưng gắn nhãn rõ.
- Dự thảo sai sót trước phát hành: FIN_L2 trả về kèm lý do, HR_L2 sửa và submit lại (số vòng thẩm định lưu history); sau phát hành phát hiện sai → chỉ tạo version mới hiệu lực từ ngày phù hợp, version cũ đóng — không sửa đè.
- Freelancer liên tục ≥3 tháng: BOD yêu cầu rate tham chiếu riêng cho cá nhân freelancer (ví dụ mount dài hạn) — rate tham chiếu version hóa riêng, gắn dự án, không tạo hồ sơ; kết thúc hợp đồng thì version tham chiếu đóng.
- Đối chiếu lệch lớn so với salary band thị trường (mục 5 `03_Quy_che_KPI_HR.md`): FIN_L2 trả về yêu cầu HR_L2 kèm giải trình payroll thực tế vs band tham khảo — giải trình lưu kèm dự thảo, không chặn luồng.
- BOD vắng khi duyệt lại chu kỳ năm: luồng treo có nhãn SLA; báo cáo chờ dùng version cũ + cờ — không ai ký duyệt hộ (BR-009, không delegate).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Rate Card Version (bảng cost/hour theo Level, một phiên bản).

**Sơ đồ trạng thái:**
```
[DRAFT] ──(HR_L2 submit)──► [FIN_REVIEW] ──(FIN_L2 duyệt)──► [PENDING_BOD] ──(BOD duyệt)──► [PUBLISHED]
[DRAFT/FIN_REVIEW] ──(trả về)──► [DRAFT] (vòng sửa)
[PENDING_BOD] ──(BOD từ chối)──► [REJECTED]
[PUBLISHED] ──(đến ngày hiệu lực)──► [ACTIVE] ──(hết ngày hiệu lực / version mới thay)──► [CLOSED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `FIN_REVIEW` | HR_L2 | Đủ cost/hour theo mọi Level + khoảng hiệu lực |
| `FIN_REVIEW` | Trả về | `DRAFT` | FIN_L2 | Lý do bắt buộc (kèm % lệch payroll nếu vượt ngưỡng) |
| `FIN_REVIEW` | Duyệt thẩm định | `PENDING_BOD` | FIN_L2 | Bảng đối chiếu payroll đính kèm |
| `PENDING_BOD` | Duyệt phát hành | `PUBLISHED` | BOD (không delegate) | Không trùng khoảng hiệu lực version đã phát hành (trừ thay thế) |
| `PENDING_BOD` | Từ chối | `REJECTED` | BOD | Lý do bắt buộc |
| `PUBLISHED` | Đến ngày hiệu lực | `ACTIVE` | Hệ thống | Version trước chuyển `CLOSED` từ cùng thời điểm |
| `ACTIVE` | Version mới thay thế / hết hạn | `CLOSED` | Hệ thống | Giữ nguyên dữ liệu — lookup quá khứ đọc từ version đóng |

**Quy tắc:**
- `PUBLISHED`/`ACTIVE` là trạng thái bất biến nội dung — mọi chỉnh sửa chỉ bằng version mới; `REJECTED`/`CLOSED` kết thúc vòng đời, không chuyển tiếp.
- Chuỗi 3 vai (soạn–thẩm định–duyệt) tách bạch: cùng 1 người không thể chiếm 2 bước trong cùng luồng.
- Mọi chuyển trạng thái ghi audit log bất biến (người, thời điểm, lý do, số vòng thẩm định); web hiển thị đúng trạng thái core trả về.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| RateCardVersion | `version_no`, `effective_from`, `effective_to`, `status`, `published_by`, `published_at` | FK → người duyệt | Bất biến sau phát hành |
| RateCardLine | `version_id`, `level`, `cost_per_hour` | FK → `RateCardVersion.id` | Theo Level; `[CẦN CHỐT SỐ]` khi migration |
| RateReviewLog | `version_id`, `step` (soạn/thẩm định/duyệt), `actor_id`, `action`, `reason` | FK → `RateCardVersion.id` | 3 chặn + số vòng trả về |
| PayrollComparisonSnapshot | `version_id`, `level`, `proposed_rate`, `payroll_actual`, `diff_pct` | FK → `RateCardVersion.id` | Đính kèm giai đoạn thẩm định |
| DataFlag | `object`, `period`, `flag_type` (thiếu version phủ ngày), `resolved_by` | FK → báo cáo sử dụng | Cho FIN rà khoảng thiếu version |
| EmployeeCostRateVersion | `profile_id`, `rate_line_id`, `effective_from` | FK → `RateCardLine` + `EmployeeProfile.id` | Kế thừa SCD2 hồ sơ khi thăng Level |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Duyệt đủ 3 chặn | Dự thảo Rate Card mới | HR_L2 submit → FIN_L2 thẩm định → BOD duyệt | Version phát hành đủ người duyệt từng bước + timestamp; bỏ bước nào bị chặn | [ ] |
| SC-002: Trả về khi lệch ngưỡng | Rate đề xuất lệch payroll thực tế >±10% | FIN_L2 thẩm định | Trả về kèm lý do và % lệch; dự thảo quay lại `DRAFT` cho HR_L2 sửa | [ ] |
| SC-003: Version bất biến | Version đã phát hành đang hiệu lực | Thử sửa cost/hour | Core từ chối; chỉ tạo được version mới hiệu lực từ ngày khác | [ ] |
| SC-004: Lookup theo ngày ghi giờ | Version A hiệu lực 01/01–30/06, version B từ 01/07 | Báo cáo giờ ngày 20/06 và 20/07 | Tự nhân đúng version A/B theo ngày ghi giờ, không theo ngày chốt báo cáo | [ ] |
| SC-005: Cờ thiếu version | Không có version phủ 15/08 | Chạy báo cáo cost 15/08 | Dùng version gần nhất trước đó + gắn cờ dữ liệu; FIN_L2 thấy hàng đợi cờ | [ ] |
| SC-006: Thăng Level giữa năm | NV lên Level mới hiệu lực 15/06 | Tính cost tháng 06 | Giờ 01–14/06 nhân rate cũ, 15–30/06 nhân rate mới, tự động theo SCD2 | [ ] |
| SC-007: Restricted permission | Manager nhóm truy cập cost cá nhân nhân viên nhóm | Gọi API | Chỉ thấy tổng cost nhóm; truy cập cá nhân bị từ chối + log attempt | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-HR-006 (Mục 2 — version hóa, thẩm định FIN, duyệt BOD, lookup theo ngày ghi giờ, migration, Restricted).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/cost-rate-card.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (version store bất biến + lookup theo ngày ghi giờ) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (salary band Q2/2026 mục 5, bảng lương thực tế mục 6, §9 entity TMS) |
