# Tính Năng: Cost Rate Card version hóa, thẩm định finance

> **Dựa trên:** REQ-HR-006 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-006` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-006 xuất hiện ở 2 hệ thống — **SYS-CORE-BACKEND** (bản spec này: version store SCD2, lookup theo ngày ghi giờ, gate cho P&L/BI) và **SYS-BCERP-WEB** (counterpart: soạn thảo, đối chiếu FIN, trình duyệt). Tại touchpoint core backend, mọi business rule được enforce ở tầng service (không tin UI); dữ liệu cost là **Confidential/Restricted** — mã hóa khi lưu/truyền, mọi lượt xem/sửa có audit log bất biến, luôn trong tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-006 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-006 |
| Người dùng liên quan | HR_L2 (soạn dự thảo), FIN_L2 (thẩm định đối chiếu payroll — quyền đọc có log trong giai đoạn thẩm định), BOD_CEO/BOD_CFO_CTO (duyệt phát hành), DEPT-FINANCE (tiêu thụ version cho P&L), OPS_PLAN/OPS_AM (báo cáo dự án), Manager (chỉ xem tổng cost nhóm mình) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-HRCORE-001 (hồ sơ SSOT — Level hiện hành theo SCD2; version cost rate đầu tiên của NV sinh theo Rate Card hiệu lực) |
| Ghi chú Expert (A7) | A7.2: giá trị cost/hour từng Level chưa có số — dùng khung mặc định import từ payroll khi migration (HR + FIN chốt); need mobile HR ngoài scope hiện tại. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Quản lý bảng **cost/hour chuẩn theo Level** dưới dạng version store SCD2 hiệu lực từ ngày–đến ngày, đi qua vòng đời duyệt 3 chặn: **HR_L2 soạn → FIN_L2 thẩm định (đối chiếu payroll thực tế) → BOD duyệt → phát hành version mới**. P&L và báo cáo dự án tiêu thụ version bằng cách **chọn đúng version theo ngày ghi giờ** — không sửa quá khứ, không để chi phí nhân sự trong báo cáo biến động mỗi khi rate đổi. Đây là đầu vào bắt buộc của luồng "Nhân Sự Chi Phí → P&L" (P1-02 Luồng 4).

**Phạm vi:**
- Bao gồm: entity Rate Card version (Level, cost/hour, khoảng hiệu lực, số version, người duyệt); workflow duyệt 3 chặn kèm bảng đối chiếu rate đề xuất vs payroll thực tế (ngưỡng đề xuất ±10% `[CẦN CHỐT SỐ]`); bất biến sau phát hành (sai sót xử lý bằng version mới); API lookup version theo ngày ghi giờ cho P&L/báo cáo dự án (không phủ → version gần nhất trước đó + gắn cờ dữ liệu); rate cá nhân kế thừa SCD2 khi thăng Level giữa năm; migration import payroll → version đầu tiên do BOD xác nhận; duyệt lại chu kỳ năm; rate tham chiếu riêng cho freelancer ≥3 tháng khi BOD yêu cầu.
- Không bao gồm: lương chi tiết/điểm payroll (DEPT-FINANCE — Rate Card chỉ là cost/hour chuẩn); allocation chi phí P&L chi tiết (REQ-FIN-016 — feature này chỉ cung cấp lookup); hình thành nhãn billable tại nguồn (ghi giờ OPS + REQ-HR-009 — Rate Card tiêu thụ, không tự gán); màn hình soạn thảo/đối chiếu (SYS-BCERP-WEB — counterpart).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` — 4 track Sales/Business Ops/HCNS/Marketing-Creative (KD-1..5 / BO-1..4 / HR-1..4 / MK-1..4) và salary band Q2/2026 (mục 4–5: band là mẫu tham khảo thị trường, dữ liệu mục 6 là lương thực tế — hai nguồn có thể lệch, đối chiếu định kỳ Q4); mục 9 (`salary_band`, `salary_review`). Cost/hour đầu vào dùng khung mặc định import từ payroll thực tế khi migration mở sổ `[CẦN CHỐT SỐ-costhour]` — spec theo assumption có tag, không tự quyết con số.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Soạn dự thảo Rate Card mới (cost/hour theo Level, hiệu lực từ ngày–đến ngày) và submit | Dự thảo có trạng thái rõ, không đụng version đang hiệu lực |
| 2 | FIN_L2 | Thấy bảng đối chiếu rate đề xuất vs payroll thực tế theo Level khi thẩm định | Lệch bất thường bị phát hiện trước khi trình BOD |
| 3 | FIN_L2 | Trả về dự thảo kèm lý do khi lệch quá ngưỡng cho phép (đề xuất ±10% `[CẦN CHỐT SỐ]`) | HR_L2 phải điều chỉnh trước khi trình lên |
| 4 | BOD_CEO / BOD_CFO_CTO | Duyệt dự thảo đã thẩm định để phát hành version mới | Chỉ BOD có quyền phát hành; phát hành ghi người duyệt + timestamp |
| 5 | Hệ thống (version store) | Đóng version cũ và phát hành version mới với số version tự tăng, bất biến sau phát hành | Lịch sử rate không đổi, P&L quá khứ tái lập được |
| 6 | DEPT-FINANCE (P&L) | Lookup rate đúng theo **ngày ghi giờ** của từng dòng giờ đã duyệt | Chi phí allocated đúng version thời điểm phát sinh |
| 7 | Hệ thống (lookup) | Gắn cờ dữ liệu khi không có version phủ ngày ghi giờ, dùng version gần nhất trước đó | FIN biết dòng nào cần kiểm tra thay vì âm thầm sai số |
| 8 | HR_L2 | Cho phép NV thăng Level giữa năm tự áp rate Level mới từ ngày hiệu lực (kế thừa SCD2 hồ sơ) | Không nhập tay rate cho từng người |
| 9 | Manager (OPS_PLAN/OPS_AM...) | Xem **tổng cost nhóm mình** | Quản lý chi phí nhóm mà không thấy cost/lương cá nhân |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR6-01 | Rate Card lưu theo **version SCD2 hiệu lực từ ngày–đến ngày**: Level, cost/hour, khoảng hiệu lực, số version tự tăng, người duyệt, timestamp | UPDATE version đã phát hành bị cấm ở service layer |
| BR-HR6-02 | Vòng đời duyệt **3 chặn**: HR_L2 soạn + submit → **FIN_L2 thẩm định** (đối chiếu payroll thực tế theo Level) → **BOD duyệt** → phát hành version mới | Thiếu bất kỳ chặn nào thì version không phát hành; duyệt sai thẩm quyền bị API từ chối |
| BR-HR6-03 | Thẩm định FIN: lệch rate đề xuất vs payroll thực tế quá ngưỡng cho phép → **trả về kèm lý do** (ngưỡng đề xuất **±10%** `[CẦN CHỐT SỐ-nguong10]` — cấu hình, không hardcode cho đến khi chốt) | Chỉ FIN_L2 mới set kết quả thẩm định; mọi lượt đọc payroll phục vụ thẩm định có log |
| BR-HR6-04 | Version đã phát hành **bất biến**: sai sót xử lý bằng version mới hiệu lực từ ngày khác; version cũ đóng lại và giữ history | Không có API sửa/xóa version published; chỉ đóng bằng version kế tiếp |
| BR-HR6-05 | P&L và báo cáo dự án **chọn version theo ngày ghi giờ** (không theo ngày chốt P&L) — API lookup là cửa vào duy nhất cho module tiêu thụ | Module nào tự cache rate vượt qua ngày ghi giờ là vi phạm kiến trúc; báo cáo phải tái lập được |
| BR-HR6-06 | Không có version phủ ngày ghi giờ → dùng **version gần nhất trước đó + gắn cờ dữ liệu** cho FIN kiểm tra | Lookup không được trả null âm thầm hay chọn version tương lai |
| BR-HR6-07 | Thăng Level giữa năm: NV tự áp rate Level mới từ ngày hiệu lực — **kế thừa SCD2 hồ sơ (FEAT-CORE-HRCORE-001), không nhập tay từng người** | Có bản ghi rate cá nhân lệch với SCD2 Level hiện hành là dữ liệu lỗi, bị đối soát phát hiện |
| BR-HR6-08 | Migration mở sổ: import từ Google Sheets/payroll thực tế → **version đầu tiên do BOD xác nhận phát hành**; Rate Card duyệt lại **chu kỳ năm** | Version đầu không qua BOD xác nhận không được đánh dấu published |
| BR-HR6-09 | Giá trị cost/hour từng Level là `[CẦN CHỐT SỐ-costhour]` — khung mặc định import từ payroll thực tế khi migration; hệ thống không hardcode con số, nhập khi cấu hình | Bật môi trường chưa cấu hình giá trị → module lookup trả lỗi cấu hình thiếu, không đoán số |
| BR-HR6-10 | **Billable tại nguồn**: Rate Card chỉ nhân với giờ đã duyệt và đã mang nhãn billable/non-billable ghi tại nguồn (REQ-HR-009/OPS); Rate Card không tự phân loại billable | Lookup không phân loại — nhận nhãn từ dữ liệu ghi giờ; chỉ giờ approved được nhân rate (gate vào P&L) |
| BR-HR6-11 | Phân quyền Restricted: chỉ **HR_L2 + BOD** xem cost/hour cá nhân; **FIN_L2 đọc trong giai đoạn thẩm định (có log)**; **manager chỉ xem tổng cost nhóm mình**; mọi lượt xem/sửa có audit log bất biến | API trả cost cá nhân cho vai khác bị từ chối; FIN_L2 đọc ngoài giai đoạn thẩm định bị chặn |
| BR-HR6-12 | Freelancer liên tục ≥3 tháng: BOD có thể yêu cầu **Rate Card tham chiếu riêng** — lưu như version tham chiếu, không trộn vào rate biên chế theo Level | Rate tham chiếu không được lookup nhầm cho nhân sự biên chế |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime (FEAT-CORE-HRCORE-002/003).
3. Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8 (FEAT-CORE-HRCORE-004).
4. **Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn** (nội dung feature này).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]`, không tự quyết; Rate Card tiêu thụ giờ đã duyệt theo rule duyệt hiện hành, không xây dựng kịch bản "giờ do TL được ủy quyền duyệt" cho đến khi chốt.

---

## 4. Phân Quyền

| Hành động | HR_L1 | HR_L2 | FIN_L2 | BOD_CEO / BOD_CFO_CTO | Manager (nhóm) | SYS_ADMIN |
|-----------|-------|-------|--------|------------------------|----------------|-----------|
| Xem bảng Rate Card theo Level (không cá nhân hóa) | ❌ | ✅ | ✅ (lúc thẩm định, log) | ✅ | ❌ | ❌ |
| Xem cost/hour cá nhân | ❌ | ✅ | ✅ (khi thẩm định, log) | ✅ | ❌ | ❌ |
| Xem tổng cost nhóm mình | ✅ (đối soát tổng) | ✅ | ✅ | ✅ | ✅ (chỉ nhóm mình) | ❌ |
| Soạn dự thảo version mới | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Thẩm định (đối chiếu payroll, trả về/lành hóa) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt + phát hành version | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Lookup rate theo ngày ghi giờ (service P&L/BI) | ❌ (qua module) | ❌ (qua module) | ✅ | ✅ | ❌ | ❌ |
| Import migration version đầu tiên | ❌ | ✅ (chuẩn bị) | ✅ (đối chiếu) | ✅ (xác nhận phát hành) | ❌ | ❌ |
| Xem audit log Rate Card | ❌ | ✅ | ✅ (log liên quan thẩm định) | ✅ | ❌ | ✅ (xem log cũng bị log) |

> Không dùng vai ngoài 18-vai registry; không tồn tại OPS_CX / FIN_COMPL (DI-006 — trách nhiệm compliance gán FIN_L2 xử lý + BOD oversight). HR_L1 không xem cost cá nhân theo ma trận REQ-HR-010.

---

## 5. Trường Hợp Đặc Biệt

- Thăng Level giữa năm: rate mới áp từ ngày hiệu lực của version SCD2 hồ sơ; giờ ghi trước đó vẫn nhân rate Level cũ — P&L hai bên ngày đó khác nhau nhưng đều tái lập được.
- Version mới hiệu lực giữa tuần: từng dòng giờ chọn version theo **ngày ghi giờ của dòng đó**, không áp toàn tuần theo ngày duyệt.
- Khoảng trống version: lookup dùng version gần nhất trước đó + gắn cờ dữ liệu; báo cáo hiển thị nhãn "rate ước tính, chờ FIN xác nhận".
- Sai sót sau phát hành: không sửa — phát hành version điều chỉnh hiệu lực từ ngày phù hợp, version lỗi đóng lại, nhật ký hai version liên kết lý do.
- Dự thảo bị trả về nhiều lần: mỗi vòng FIN trả về tạo vòng thẩm định mới có log; số vòng hiển thị ở counterpart để theo dõi.
- Migration khi chưa chốt cost/hour `[CẦN CHỐT SỐ-costhour]`: import khung payroll thực tế làm dự thảo; chỉ khi BOD xác nhận mới thành version đầu tiên — không có trạng thái "tạm dùng chưa duyệt".
- Rate tham chiếu freelancer (≥3 tháng): tách khỏi rate biên chế, chỉ lookup cho đúng đối tượng được gắn; gán sai bị đối soát gắn cờ.
- Tenant isolation: version store và lookup scope theo tenant — rate tenant khác không lọt vào P&L của tenant này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Rate Card version (`cost_rate_card_version`)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [FIN_REVIEW] ──(thẩm định đạt)──► [BOD_APPROVAL] ──(duyệt)──► [PUBLISHED — bất biến]
                          │                                │                            │ (phát hành version mới)
                          │ (trả về: lệch > ngưỡng)         │ (từ chối)                  ▼
                          ▼                                ▼                        [CLOSED — giữ history]
                      [RETURNED]                      [REJECTED]
                          │ (sửa lại → submit)
                          ▼
                      [DRAFT]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| DRAFT | Submit | FIN_REVIEW | HR_L2 | Đủ cost/hour theo Level + khoảng hiệu lực; không giao ngày với version published cùng tenant |
| FIN_REVIEW | Thẩm định đạt | BOD_APPROVAL | FIN_L2 | Bảng đối chiếu payroll thực hiện; lệch ≤ ngưỡng `[CẦN CHỐT SỐ-nguong10]` |
| FIN_REVIEW | Trả về | RETURNED | FIN_L2 | Lệch quá ngưỡng — bắt buộc lý do |
| RETURNED | Sửa + submit lại | DRAFT → FIN_REVIEW | HR_L2 | Ghi nhận vòng thẩm định mới có log |
| BOD_APPROVAL | Duyệt | PUBLISHED | BOD_CEO / BOD_CFO_CTO | Phiên bản khóa snapshot; ghi người duyệt + timestamp; số version tự tăng |
| BOD_APPROVAL | Từ chối | REJECTED | BOD_CEO / BOD_CFO_CTO | Bắt buộc lý do |
| PUBLISHED | Phát hành version mới | CLOSED | BOD (qua version mới) | Version cũ giữ history, không xóa; lookup thời gian trước đó vẫn dùng version cũ |

**Quy tắc:**
- `PUBLISHED` là trạng thái **bất biến** — mọi sửa đổi phải tạo version mới; `CLOSED`/`REJECTED` là trạng thái kết thúc của version đó.
- Tại một mốc ngày, chỉ tối đa 1 version PUBLISHED phủ ngày đó trong cùng tenant — ràng buộc service kiểm tra khi phát hành.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `cost_rate_card_version` | `version_no`, `tenant_id`, `career_level`, `cost_per_hour`, `valid_from`, `valid_to`, `status`, `published_by`, `published_at` | FK → `career_level` | SCD2; bất biến khi PUBLISHED; unique khoảng hiệu lực/tenant |
| `rate_review_task` | `version_id`, `reviewer_id` (FIN_L2), `payroll_compare_ref`, `result` (PASS/RETURN), `reason`, `decided_at` | FK → `cost_rate_card_version` | Lượt đọc payroll phục vụ thẩm định có log |
| `rate_approval` | `version_id`, `approver_id` (BOD), `decision`, `decided_at` | FK → `cost_rate_card_version` | Chỉ BOD phát hành |
| `rate_lookup_log` | `version_id`, `called_by_module`, `service_date`, `flagged` (bool), `at` | FK → `cost_rate_card_version` | Gắn cờ dữ liệu khi không phủ ngày ghi giờ |
| `employee_cost_rate` | `employee_id`, `rate_version_id`, `valid_from`, `valid_to` | FK → `employee`, `cost_rate_card_version` | Sinh kế thừa theo SCD2 Level — không nhập tay |
| `freelancer_rate_ref` | `freelancer_ref`, `rate`, `valid_from`, `valid_to`, `approved_by` (BOD) | — | Rate tham chiếu riêng ≥3 tháng; tách khỏi rate biên chế |
| `audit_log` | `actor_id`, `entity`, `before/after`, `at`, `tenant_id` | — | Bất biến; bao gồm lượt xem cost cá nhân |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đủ chuỗi 3 chặn mới phát hành | Dự thảo mới submit | HR_L2 cố gọi API phát hành trực tiếp | API từ chối sai thẩm quyền; chỉ BOD duyệt được sau khi FIN_L2 đã PASS | [ ] |
| SC-002: Trả về khi lệch payroll | Rate đề xuất lệch payroll thực tế > ngưỡng cấu hình | FIN_L2 thẩm định | Kết quả RETURN với lý do; version về DRAFT; vòng thẩm định log | [ ] |
| SC-003: Lookup theo ngày ghi giờ | Version v2 hiệu lực từ 01/10; giờ ghi 25/09 đã duyệt | P&L gọi lookup với service_date 25/09 | Trả v1; dùng v2 là lỗi; log lookup đầy đủ | [ ] |
| SC-004: Không phủ ngày → cờ dữ liệu | Khoảng trống version sau 15/03 | Lookup service_date 20/03 | Trả version gần nhất trước đó + `flagged=true`; FIN thấy nhãn "chờ xác nhận" trong báo cáo | [ ] |
| SC-005: Version published bất biến | Version v2 đang PUBLISHED | Gọi API UPDATE cost_per_hour | Service từ chối; chỉ có đường phát hành v3 + đóng v2; history v2 nguyên vẹn | [ ] |
| SC-006: Thăng Level kế thừa rate | NV được duyệt lên Level cao hơn từ 01/11 | Service xử lý SCD2 hồ sơ | `employee_cost_rate` tự sinh theo rate Level mới từ 01/11; không có nhập tay; P&L tháng 10 vẫn dùng rate cũ | [ ] |
| SC-007: Manager chỉ xem tổng nhóm | Manager gọi API xem cost cá nhân thành viên | Service kiểm tra quyền | Từ chối; API tổng cost nhóm trả đúng phạm vi nhóm của manager | [ ] |

> **Liên kết:** Các scenario map đến REQ-HR-006 (`hr.md` Mục A3/B6, P1-02 Luồng 4 bước B1/B5) và BR-HR6-01..12 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/cost-rate-card.md` |
| Nguồn domain salary band / 4 track / entity TMS | `documents/03_Quy_che_KPI_HR.md` (mục 4, 5, 6, 9) |
