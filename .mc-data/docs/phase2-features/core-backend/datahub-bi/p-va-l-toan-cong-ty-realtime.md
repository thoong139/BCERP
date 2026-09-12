# Tính Năng: P&L toàn công ty realtime

> **Dựa trên:** REQ-BOD-003 trong `phase1-business/departments/bod/bod.md` (Phần A — Mục REQ-BOD-003; Phần B — Mục B3)
> **Phân hệ:** Data Integration Hub & Analytics — BI/BOD Dashboard (SYS-CORE-BACKEND)
> **Module:** Data Integration Hub & Analytics — BI/BOD Dashboard (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/datahub-bi/*.md`, `phase5-implementation/tasks/core-backend/datahub-bi/feat-core-dhub-001-impl.md`

> **Hướng dẫn ID:** FEAT-CORE-DHUB-001 được tạo từ REQ-BOD-003 theo quy tắc chung trong req-registry (SYS=CORE-BACKEND, MOD=DATAHUB-BI). REQ này fan-out trên 3 systems — file này là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-BCERP-WEB (dashboard đầy đủ, drill-down), SYS-MOBILE-INTERNAL (bản rút gọn read-only).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-DHUB-001 |
| Module | MOD-DATAHUB-BI (SYS-CORE-BACKEND) |
| Yêu cầu nghiệp vụ | REQ-BOD-003 — P&L toàn công ty realtime (HIGH · MVP star schema + P&L cơ bản → Phase3 realtime ≤15 phút) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP: star schema + P&L cơ bản) → Phase3 (realtime ≤15 phút) |
| Phụ thuộc | Sổ phụ ví & lệnh (REQ-FIN-001/002), timesheet đã duyệt + Cost Rate Card SCD2 (REQ-HR-006), dữ liệu 7 nền tảng từ GW (nhãn `api`/`manual`, degraded mode theo DI-007), connector kế toán VAS vendor-agnostic (REQ-FIN-013 — cấu hình tại MOD-SETTINGS-GW theo DI-004) |
| Ghi chú Expert (A7) | Dept doc `bod.md` có Mục A7 nhưng chưa ghi điều chỉnh đã chốt (chờ expert review) — spec hiện hành theo Phần A/B; khi A7 có điều chỉnh sẽ cập nhật dòng này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp Báo cáo Lãi Lỗ (P&L) toàn công ty theo thời gian thực trên core backend, tính từ star schema với conformed dimensions (Khách, Dự án, TKQC, Nền tảng, Cost Rate SCD2) và công thức chuẩn hóa theo Metric Catalog. Phân vai rõ: FIN là nguồn số (sổ phụ ví, đối soát, kế toán, AR/AP), BOD là bên tiêu thụ số — tính năng này là lớp tổng hợp/enforcement nằm giữa, chấm dứt tình trạng "mỗi người một bảng tính".

**Phạm vi:**
- Bao gồm: Data Integration Hub gom dữ liệu từ các modules nội bộ (ledger ví, timesheet, AR/AP, kế toán) + Integration Gateway (GW); nạp star schema; service tính P&L = Doanh thu dịch vụ − (Σ giờ × cost rate + outsource + tools) với freshness ≤15 phút; API headless phục vụ WEB dashboard đầy đủ và MOBILE bản rút gọn; chỉ báo freshness "cập nhật lúc HH:MM + nguồn api/manual" ở mức dữ liệu; chế độ degraded khi thiếu nguồn; audit mọi truy xuất P&L của BOD.
- Không bao gồm: màn hình dashboard UI đầy đủ (counterpart SYS-BCERP-WEB), bản KPI rút gọn mobile (counterpart SYS-MOBILE-INTERNAL), vòng đời Metric Catalog và BI dashboard điều hành đa KPI (FEAT-CORE-DHUB-002), alert center (FEAT-CORE-DHUB-003), dashboard vận hành tài chính hằng ngày của FIN (FEAT-CORE-DHUB-004), dữ liệu ví read-only cho khách (REQ-FIN-017), thu thập dữ liệu gốc ở GW (phân hệ GW sở hữu connector).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Gọi API xem P&L toàn công ty theo tháng/khách/dự án/nền tảng qua dashboard WEB | Nắm kết quả kinh doanh realtime ≤15 phút, ra quyết định không chờ báo cáo cuối tháng |
| 2 | BOD_CEO | Drill-down từ một dòng P&L tới cấu phần chi (timesheet, outsource, tools) | Xác định nhanh khoản nào làm hao margin |
| 3 | BOD_CFO_CTO | Xem margin theo dự án/khách với cost rate phiên bản hiệu lực (SCD2) | Đánh giá đúng chi phí nhân sự/outsource tại thời điểm phát sinh |
| 4 | BOD_CFO_CTO | Thấy tiền giữ hộ hiển thị tách bạch khỏi doanh thu ở mọi chiều dữ liệu | Không bao giờ đọc nhầm tiền nạp của khách là doanh thu |
| 5 | SYS_ADMIN | Giám sát trạng thái pipeline nạp star schema (job nào thành công/stale/thiếu nguồn) | Kịp thời khắc phục nguồn lỗi, giữ freshness ≤15 phút |
| 6 | SYS_ADMIN | Truy vết meta-log các lần BOD truy xuất P&L (ai xem, xem gì, lúc nào) | Phục vụ audit; lưu ý SYS_ADMIN không thấy giá trị dữ liệu T3/T4 |
| 7 | Hệ thống (service CORE) | Tự tính lại P&L mỗi khi có dữ liệu mới và gắn nhãn nguồn từng thành phần | Mọi kênh tiêu thụ (WEB/MOBILE) đọc đúng một nguồn sự thật |

**Đặc thù touchpoint SYS-CORE-BACKEND:** tính năng là headless API/domain service — mọi business rule (tách tiền giữ hộ, chặn giờ chưa duyệt, gắn nhãn manual, mask T3/T4) được enforce ở tầng service và tầng dữ liệu, không tin vào UI; WEB là kênh xem chính (responsive browser UI), MOBILE nội bộ chỉ đọc bản rút gọn và không export; Portal khách (SYS-PORTAL-WEB) tuyệt đối không có API truy cập P&L — đây là biên tin cậy nội bộ.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, toàn bộ enforce ở service layer của CORE.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-BOD-003.1 | Tiền khách nạp vào ví TKQC là tiền giữ hộ — nợ phải trả (liability), tách tuyệt đối khỏi doanh thu trên mọi báo cáo, mọi kênh; doanh thu chỉ ghi nhận phí dịch vụ/markup theo hợp đồng | Service chặn cấu hình "tự động hạch toán nạp → doanh thu"; mọi kết quả P&L trả về đều có cột tiền giữ hộ tách riêng, không thể gộp |
| BR-BOD-003.2 | Giờ timesheet chưa được duyệt không được đưa vào P&L | Job tổng hợp chỉ nhận timesheet trạng thái đã duyệt; nếu có giờ chưa duyệt thì bỏ khỏi phép tính và ghi nhận vào danh sách chờ, không tính gần đúng |
| BR-BOD-003.3 | Mọi khoản chi phải gắn mã dự án; chi không gắn được mã dự án buộc chọn overhead + nhập lý do | Ghi dữ liệu bị từ chối nạp vào fact chi phí, tạo bản ghi ngoại lệ buộc hoàn thiện trước khi vào P&L |
| BR-BOD-003.4 | Connector lỗi / thiếu nguồn → degraded mode: dữ liệu gắn nhãn "manual", hiển thị "stale" + timestamp dữ liệu hợp lệ cuối cùng, không nội suy số ẩn, không tắt nhãn | API trả kèm cờ freshness `stale` và nguồn; kênh tiêu thụ phải hiển thị nguyên trạng — service không được trả số trông như thật khi nguồn là nhập tay |
| BR-DHUB-101 | P&L tính theo công thức đăng ký trong Metric Catalog: P&L = Doanh thu DV − (Σ giờ × cost rate + outsource + tools); cost rate dùng phiên bản SCD2 hiệu lực theo ngày ghi giờ; cấm nhập tay kết quả P&L | Kết quả không đăng ký công thức không được phát hành; service từ chối ghi đè kết quả tính bằng giá trị tay |
| BR-DHUB-102 | Freshness P&L ≤15 phút kể từ dữ liệu gốc (GW pull hourly 7 nền tảng, ví QC realtime ≤15 phút sau giao dịch, timesheet chốt 23:59, sổ kế toán qua connector VAS) | Nếu vượt ngưỡng, service đánh dấu stale toàn bộ view phụ thuộc và phát sự kiện cho alert center (FEAT-CORE-DHUB-003) |
| BR-DHUB-103 | Dữ liệu lương/PII chỉ aggregate khi được phép: cost rate nhân sự (T4) chỉ CEO/CFO xem giá trị; SYS_ADMIN không thấy giá trị T3/T4; chi tiết lương không bao giờ xuất hiện ở mức drill-down công khai | Service mask/ẩn giá trị theo vai; trả về mức tổng hợp duy nhất cho vai không đủ thẩm quyền |
| BR-DHUB-104 | Data Integration Hub gom dữ liệu từ modules nội bộ + GW; nguồn nào thiếu (kể cả connector kế toán VAS vendor-agnostic cấu hình tại MOD-SETTINGS-GW theo DI-004) thì phần P&L liên quan chuyển degraded mode, phần còn lại vẫn tính đúng | Không chặn toàn bộ P&L vì một nguồn lỗi; nguồn thiếu được liệt kê tường minh trong metadata phản hồi |
| BR-DHUB-105 | Mọi truy xuất P&L của BOD đều ghi meta-log (ai, khi nào, tham số nào) — "xem cũng bị log"; tenant isolation: truy vấn luôn bọc theo tenant/context được cấp quyền | Truy cập không qua điểm check quyền tập trung (REQ-BOD-011) bị từ chối ở tầng API gateway/service, kể cả Super Admin |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem P&L toàn công ty (tổng + mọi chiều) | ✅ | ✅ | ❌ (chỉ thấy trạng thái pipeline, không thấy giá trị nghiệp vụ) |
| Drill-down tới timesheet/outsource/tools | ✅ | ✅ | ❌ |
| Xem giá trị cost rate nhân sự (T4) | ✅ | ✅ (vai CFO) | ❌ (mask ở service) |
| Xem trạng thái freshness/pipeline nguồn | ✅ | ✅ | ✅ |
| Cấu hình job nạp/đồng bộ star schema | ❌ | ❌ | ✅ (thực thi sau duyệt, mọi thao tác bị log) |
| Sửa/xóa dữ liệu P&L đã tính | ❌ | ❌ | ❌ (append-only + chỉ qua điều chỉnh nguồn) |
| Xuất P&L ngoài báo cáo chuẩn | ✅ (tự ký) | ✅ (CFO) | ❌ |

> Ghi chú: FIN_L1/FIN_L2 không xem dashboard BOD trong tính năng này — họ sở hữu dữ liệu nguồn và dashboard vận hành riêng (FEAT-CORE-DHUB-004); CUSTOMER/Portal không có bất kỳ quyền nào ở đây.

---

## 5. Trường Hợp Đặc Biệt

- Connector GW lỗi hoặc chưa có quyền API developer (DI-007 — tiến trình Business Verification 7 nền tảng chưa hoàn tất): nguồn gắn nhãn "manual", minh chứng nhập tay lưu kèm từng kỳ, backfill tự động khi được cấp quyền; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát.
- Connector kế toán VAS: vendor-agnostic theo DI-004 — connection profile + field mapping cấu hình tại MOD-SETTINGS-GW, không hardcode vendor; VAS chỉ hỗ trợ import file thì GW xuất file chuẩn schema + log lượt xuất; connector fail → hàng chờ retry + alert, không ghi sổ tay đè lên luồng chuẩn.
- Timesheet chốt 23:59 nhưng duyệt trễ sang ngày hôm sau: giờ đó chưa vào P&L của chu kỳ hiện tại; khi được duyệt, job tính lại và P&L cập nhật trong chu kỳ freshness kế tiếp — BOD thấy biến động có mốc thời gian tường minh.
- TK client-owned (khách tự nạp trực tiếp nền tảng): không phát sinh lệnh nạp của BC, chỉ tham gia đối soát — không tạo doanh thu hay chi phí giả trong P&L agency.
- Chi phí outsource/tools phát sinh trên nhà cung cấp ngoài: phải gắn mã dự án khi nhập; không gắn được thì bắt buộc chọn overhead + lý do (BR-BOD-003.3), không được treo "chờ xử lý" vô thời hạn.
- BOD truy xuất phục vụ thanh tra/kiểm toán: dùng đúng luồng API chuẩn có meta-log; không có đường xuất "ngoài luồng" kể cả với Super Admin.
- Dữ liệu ví lệch so với kế toán vượt dung sai đối soát (theo chính sách dung sai DI-001 đã chốt): view P&L đánh dấu chất lượng dữ liệu "cảnh báo đối soát" thay vì im lặng dùng số lệch.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Nguồn dữ liệu thành phần của P&L (source freshness — ví QC, GW hourly, timesheet, kế toán VAS)

**Sơ đồ trạng thái:**
```
[FRESH] ──(quá SLA freshness nguồn)──► [STALE] ──(sync thành công)──► [FRESH]
   │                                        │
   │ (nguồn mất kết nối / chưa có quyền API)│ (sync lỗi liên tiếp)
   ▼                                        ▼
[MANUAL] ◄──(backfill khi có quyền)── [DEGRADED] ──(retry ok)──► [FRESH]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `FRESH` | Quá SLA freshness nguồn | `STALE` | Hệ thống (scheduler) | SLA theo nguồn: ví ≤15 phút, GW hourly, timesheet 23:59, kế toán theo kỳ |
| `STALE` | Sync thành công | `FRESH` | Hệ thống | Dữ liệu pass quality gate cơ bản (not-null, khớp lệnh) |
| `FRESH`/`STALE` | Mất kết nối nguồn | `DEGRADED` | Hệ thống | Connector lỗi ≥ số lần retry cho phép |
| `DEGRADED` | Nhập tay có minh chứng | `MANUAL` | SYS_ADMIN (thực thi) + FIN_L1 (chủ số) | Chứng từ nhập tay lưu kèm từng kỳ, gắn nhãn "manual" |
| `MANUAL` | Backfill dữ liệu API | `FRESH` | Hệ thống | Khi quyền API được cấp (DI-007); chênh lệch manual vs API >±0,1% ghi vào báo cáo đối soát |

**Quy tắc:**
- Nhãn nguồn ("api"/"manual") đi kèm dữ liệu xuyên suốt tới mọi kênh tiêu thụ — không tắt nhãn (BR-BOD-003.4).
- Trạng thái `STALE`/`MANUAL`/`DEGRADED` bắt buộc phát sự kiện cho alert center (FEAT-CORE-DHUB-003) khi đạt ngưỡng "stale nghiêm trọng".
- Không có trạng thái ẩn: mọi nguồn phải nằm ở một trạng thái tường minh trong bảng trên.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `fact_financial_entry` | `entry_id`, `dim_customer_id`, `dim_project_id`, `dim_adaccount_id`, `dim_platform_id`, `entry_type`, `amount`, `currency`, `fx_snapshot_id`, `source_label`, `data_status` | FK → các conformed dimensions | Append-only; tiền giữ hộ tách `entry_type` khỏi doanh thu |
| `dim_cost_rate` | `rate_id`, `person_id`, `rate`, `effective_from`, `effective_to` (SCD2) | FK → `hr_person` | T4 — chỉ CEO/CFO xem giá trị; version theo ngày ghi giờ |
| `dim_customer` / `dim_project` / `dim_adaccount` / `dim_platform` | Khóa conformed, mã nguồn, tenant_id | Dùng chung toàn phân hệ BI | Conformed dimensions GĐ3, tenant isolation bắt buộc |
| `source_freshness` | `source_code`, `last_sync_at`, `status` (`FRESH/STALE/DEGRADED/MANUAL`), `last_valid_at` | 1 dòng/nguồn | Nguồn sự thật của chỉ báo freshness và trigger alert |
| `pnl_query_audit` | `query_id`, `actor`, `role`, `params`, `queried_at` | FK → `users` | Meta-log append-only — truy xuất BOD cũng bị log (nối REQ-BOD-005) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền đầy đủ ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tách tiền giữ hộ | Có lệnh nạp ví khách 100 triệu đã khớp tiền | Tính P&L kỳ | 100 triệu nằm ở cột nợ phải trả, không cộng vào doanh thu; công thức chỉ tính phí dịch vụ/markup | [ ] |
| SC-002: Giờ chưa duyệt | Có 40 giờ timesheet chờ TL duyệt | Chạy job P&L | 40 giờ không vào chi phí; sau khi duyệt, P&L tính lại ≤15 phút | [ ] |
| SC-003: Degraded mode | Connector nền tảng X lỗi | Truy vấn P&L | Phần nguồn X gắn "manual" + timestamp hợp lệ cuối; không có số nội suy; nguồn khác vẫn đúng | [ ] |
| SC-004: Mask T4 | SYS_ADMIN gọi API drill-down chi phí nhân sự | Trả kết quả | Chỉ thấy tổng hợp; giá trị rate cá nhân bị mask; lần truy cập bị meta-log | [ ] |
| SC-005: Audit truy xuất BOD | BOD_CEO xem P&L khách A | Sau truy vấn | `pnl_query_audit` có bản ghi actor + params + timestamp | [ ] |

> **Liên kết:** Mỗi scenario map về REQ-BOD-003 (Mục 2 Phần A `bod.md`) và BR-BOD-003.x / BR-DHUB-10x ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — star schema, source freshness, audit | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — headless P&L query, freshness metadata | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW, connector VAS vendor-agnostic, degraded mode | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (counterpart WEB/MOBILE) | `phase4-ux/bcerp-web/datahub-bi/*.md`, `phase4-ux/mobile-internal/datahub-bi/*.md` |
| Feature liên quan cùng module | FEAT-CORE-DHUB-002 (Metric Catalog), FEAT-CORE-DHUB-003 (alert stale), FEAT-CORE-DHUB-004 (nguồn số FIN), FEAT-CORE-DHUB-005 (Bản FIN của BI/BOD P&L) |
