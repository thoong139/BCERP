# Tính Năng: BI/BOD dashboard & P&L realtime

> **Dựa trên:** REQ-FIN-016 trong `phase1-business/departments/finance/finance.md` (Phần A — Mục REQ-FIN-016; Phần B — BR-FIN-307); phối hợp REQ-BOD-003 trong `phase1-business/departments/bod/bod.md` (Phần B — Mục B3)
> **Phân hệ:** Data Integration Hub & Analytics — BI/BOD Dashboard (SYS-CORE-BACKEND)
> **Module:** Data Integration Hub & Analytics — BI/BOD Dashboard (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/datahub-bi/*.md`, `phase5-implementation/tasks/core-backend/datahub-bi/feat-core-dhub-005-impl.md`

> **Hướng dẫn ID:** FEAT-CORE-DHUB-005 được tạo từ REQ-FIN-016 theo quy tắc chung trong req-registry (SYS=CORE-BACKEND, MOD=DATAHUB-BI). REQ này fan-out trên 3 systems — file này là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-BCERP-WEB (dashboard BOD đầy đủ), SYS-MOBILE-INTERNAL (dashboard BOD rút gọn + alert center cảnh báo rủi ro dòng tiền). Quan hệ chéo: REQ-FIN-016 ↔ REQ-BOD-003 — BOD oversight yêu cầu P&L realtime; FIN là số liệu nguồn, BOD tiêu thụ.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-DHUB-005 |
| Module | MOD-DATAHUB-BI (SYS-CORE-BACKEND) |
| Yêu cầu nghiệp vụ | REQ-FIN-016 — BI/BOD dashboard & P&L realtime (MEDIUM · GĐ3/Phase3, phối hợp BOD); chéo: REQ-BOD-003 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (Phase3 — mở rộng star schema + conformed dimensions; nối tiếp nền MVP của FEAT-CORE-DHUB-001/004) |
| Phụ thuộc | FEAT-CORE-DHUB-001 (star schema + P&L cơ bản), FEAT-CORE-DHUB-004 (số liệu nguồn FIN), REQ-FIN-001/004 (ledger append-only, đối trừ 3 số, khóa kỳ), REQ-HR-006 (timesheet duyệt + cost rate SCD2), Metric Catalog từ REQ-BOD-004/FEAT-CORE-DHUB-002 |
| Ghi chú Expert (A7) | Dept doc `finance.md` có Mục A7 nhưng chưa ghi điều chỉnh đã chốt (chờ finance-expert review) — spec hiện hành theo Phần A/B; khi A7 có điều chỉnh sẽ cập nhật dòng này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Mở rộng hạ tầng BI của core backend ở GĐ3 thành mô hình star schema hoàn chỉnh với conformed dimensions (Khách, Dự án, TKQC, Nền tảng) để phục vụ P&L realtime theo dự án/khách — chấm dứt "mỗi người một bảng tính": FIN_L1/FIN_L2 chịu trách nhiệm chất lượng số liệu nguồn (sổ phụ, đối soát, AR/AP, timesheet duyệt, cost rate), BOD tiêu thụ qua dashboard mà không ai nhập tay kết quả. Phân vai nguồn–tiêu thụ là trục thiết kế: số FIN sai thì dashboard chặn phát hành, số FIN đúng thì BOD không cần hỏi ai.

**Phạm vi:**
- Bao gồm: mở rộng star schema GĐ3 + conformed dimensions; pipeline nạp dữ liệu theo batch có trạng thái; hiển thị tiền giữ hộ tách bạch khỏi doanh thu ở mọi chiều dữ liệu; quản trị thay đổi định nghĩa metric (CFO duyệt + lịch sử hiệu lực); cấm nhập tay kết quả BI; API dashboard BOD (P&L realtime ≤15 phút, freshness ≤15 phút) và alert rủi ro dòng tiền (kênh MOBILE ở counterpart); mask dữ liệu lương/PII; audit truy xuất BOD (meta-log); degraded mode gắn nhãn khi thiếu nguồn.
- Không bao gồm: Metric Catalog và BI workspace đa KPI (FEAT-CORE-DHUB-002), rule engine alert và delivery (FEAT-CORE-DHUB-003 — tính năng này phát sự kiện ngưỡng dòng tiền), dashboard vận hành FIN hằng ngày (FEAT-CORE-DHUB-004), UI WEB/MOBILE (counterparts), dữ liệu cho Portal khách (REQ-FIN-017).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Dữ liệu sổ phụ/lệnh của mình chảy tự động vào star schema sau khi đối trừ 3 số đạt | Số kế toán chỉ nhập một nơi, mọi báo cáo dùng lại không lệch |
| 2 | FIN_L1 | Thấy cờ dữ liệu nguồn lỗi (discrepancy, lệch đối soát) ngay trong pipeline nạp | Xử lý lệch trước khi số chảy lên dashboard BOD |
| 3 | FIN_L2 | Duyệt chất lượng dữ liệu kỳ (quality gate) trước khi dashboard kỳ đó phát hành cho BOD | Chịu trách nhiệm danh dự về số — không để BOD nhìn số bẩn |
| 4 | FIN_L2 | Đề xuất thay đổi định nghĩa metric tài chính và được CFO (BOD_CFO_CTO) duyệt có lịch sử hiệu lực | Định nghĩa GM/P&L đổi có kiểm soát, báo cáo liên kỳ vẫn so sánh đúng |
| 5 | BOD_CFO_CTO | Xem P&L realtime theo dự án/khách với conformed dimensions và freshness ≤15 phút | Điều hành trên một nguồn sự thật, drill đến đúng dự án lỗ/lãi |
| 6 | BOD_CFO_CTO | Nhận sự kiện cảnh báo rủi ro dòng tiền (ví sát ngưỡng, aging xấu đi) từ dashboard tài chính | Phản ứng trước khi dòng tiền đứt gãy |
| 7 | Hệ thống (service CORE) | Tính lại P&L và đánh giá quality gate tự động, chặn publish khi gate fail | Không ai — kể cả Super Admin — nhập tay kết quả BI |

**Đặc thù touchpoint SYS-CORE-BACKEND:** tính năng là headless API/domain service — quy tắc tách tiền giữ hộ, quality gate, lịch sử hiệu lực metric, mask PII, audit truy xuất đều enforce ở service layer; WEB/MOBILE nội bộ chỉ tiêu thụ; Portal khách không có API truy cập (khách chỉ xem qua REQ-FIN-017).

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, toàn bộ enforce ở service layer của CORE.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-FIN-307.1 | Tiền giữ hộ hiển thị tách bạch khỏi doanh thu ở mọi dashboard, mọi chiều dữ liệu (Khách/Dự án/TKQC/Nền tảng) — doanh thu chỉ là phí dịch vụ/markup (nối BR-FIN-101) | View/query gộp tiền giữ hộ vào doanh thu bị chặn ở tầng query; kết quả trả về luôn có cột liability tách riêng |
| BR-FIN-307.2 | Freshness "cập nhật lúc HH:MM" mọi widget; P&L realtime freshness ≤15 phút; chi tiêu QC tươi ≤1h | Quá SLA → đánh dấu stale + timestamp hợp lệ cuối; không hiển thị số cũ như số mới |
| BR-FIN-307.3 | Dữ liệu nguồn `manual` — hiển thị nhãn nguồn + disclaimer độ trễ; không nhập tay kết quả BI (nối BR-BOD-004.3, DI-007 degraded mode) | Giá trị ghi đè tay vào `kpi_snapshot`/`pnl_fact` bị từ chối ở service và log ngoại lệ |
| BR-BOD-003.1 | Tiền nạp ví TKQC là nợ phải trả — tách tuyệt đối khỏi doanh thu trên mọi báo cáo, mọi kênh | Cấu hình auto-hạch toán nạp → doanh thu bị chặn cứng ở service (không có flag bật) |
| BR-BOD-003.2 | Giờ timesheet chưa duyệt không vào P&L; chi không gắn mã dự án buộc chọn overhead + lý do (BR-BOD-003.3) | Job nạp bỏ giờ chưa duyệt và tạo ngoại lệ buộc hoàn thiện; số "gần đúng" không được tính |
| BR-BOD-004.2 | Đổi định nghĩa metric phải CFO duyệt + lịch sử hiệu lực; báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu | Version chưa duyệt không kích hoạt; sửa trực tiếp metric bị chặn ở tầng dữ liệu (append-only version) |
| BR-DHUB-501 | Star schema dùng conformed dimensions (Khách, Dự án, TKQC, Nền tảng) dùng chung toàn phân hệ BI; một thực thể một mã nguồn duy nhất — chống trùng dimension | Dimension trùng/mapping sai bị quality test bắt; nạp dimension lệch chuẩn bị từ chối |
| BR-DHUB-502 | FIN là số liệu nguồn, BOD tiêu thụ: quality gate của kỳ do FIN_L2 duyệt — gate fail thì dashboard kỳ đó chặn publish cho BOD cho đến khi pass hoặc có ghi nhận chấp nhận rủi ro | Không có đường publish qua gate fail không vết; mọi quyết định chấp nhận rủi ro ghi audit |
| BR-DHUB-503 | Dữ liệu lương/PII chỉ aggregate khi được phép: P&L theo dự án dùng cost rate tổng hợp; giá trị T3/T4 cá nhân chỉ CEO/CFO xem; mọi truy xuất dashboard BOD ghi meta-log | Truy vấn chi tiết PII bị mask; lần truy cập log vào `pnl_query_audit` (nối REQ-BOD-005) |
| BR-DHUB-504 | Data Integration Hub gom từ modules + GW; thiếu nguồn → degraded mode + nhãn; connector lỗi hiển thị "stale" + timestamp dữ liệu hợp lệ cuối, không nội suy số ẩn (BR-BOD-003.4) | P&L không được trả số "trông như thật" khi nguồn là nhập tay; metadata phản hồi liệt kê nguồn missing |
| BR-DHUB-505 | Ngưỡng rủi ro dòng tiền phát sự kiện cho alert center: ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]`, aging AR/AP xấu đi theo bucket, hàng chờ duyệt quá SLA (mốc PAUSE 15 ngày `[KXN-22 — chờ khách hàng xác nhận]`) | Ngưỡng cấu hình được, không hardcode; sự kiện phải phát đủ — dashboard không phải nơi duy nhất nhìn thấy rủi ro |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Nạp/kiểm tra dữ liệu nguồn vào star schema | ✅ (qua pipeline tự động, theo quyền nguồn) | ✅ (duyệt quality gate) | ❌ |
| Duyệt quality gate kỳ / chấp nhận rủi ro có ghi nhận | ❌ | ✅ | ✅ (oversight) |
| Xem P&L realtime theo dự án/khách | ✅ (phục vụ rà nguồn số) | ✅ | ✅ |
| Drill về cấu phần chi (timesheet/outsource/tools) | ✅ | ✅ | ✅ |
| Xem giá trị cost rate cá nhân (T3/T4) | ❌ (chỉ tổng hợp) | ❌ (chỉ tổng hợp) | ✅ (vai CFO; CEO ở lane BOD) |
| Đề xuất đổi định nghĩa metric | ✅ (đề xuất) | ✅ (đề xuất) | ✅ (duyệt — CFO) |
| Xuất báo cáo P&L cho BOD | ✅ (theo ủy nhiệm) | ✅ | ✅ (bị meta-log) |
| Nhập tay kết quả P&L/BI | ❌ | ❌ | ❌ (cấm tuyệt đối) |
| Sửa dữ liệu đã nạp vào star schema | ❌ | ❌ | ❌ (append-only; điều chỉnh qua luồng nguồn có reason code) |

> Ghi chú: SYS_ADMIN không có quyền xem giá trị nghiệp vụ (chỉ vận hành pipeline sau duyệt); CUSTOMER/Portal không có quyền truy cập — dữ liệu cho khách chỉ qua REQ-FIN-017 view tenant.

---

## 5. Trường Hợp Đặc Biệt

- Chưa có quyền API developer 7 nền tảng (DI-007): dữ liệu GW nhập tay gắn nhãn "manual" + minh chứng lưu kèm từng kỳ; khi Business Verification hoàn tất, backfill tự động; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát; phần P&L liên quan tính tiếp bình thường với nhãn đúng.
- Connector kế toán VAS (DI-004, vendor-agnostic): sổ kế toán nạp qua connection profile cấu hình tại MOD-SETTINGS-GW; VAS chỉ hỗ trợ import file thì xuất file chuẩn schema + log lượt xuất; connector fail → retry + alert, không ghi tay đè luồng chuẩn.
- Quality gate fail sát lịch họp BOD: FIN_L2 hoặc chặn phát hành (dashboard kỳ hiển thị "chưa phát hành — lỗi chất lượng") hoặc chấp nhận rủi ro có ghi nhận audit; không có cơ chế "phát hành rồi sửa sau".
- Đổi định nghĩa GM giữa năm (ngưỡng nhóm dịch vụ — Agency ≥15%, Ads ops ≥20%, SEO ≥35%, Web/Thiết kế ≥30% `[CẦN CHỐT SỐ]`): version mới do CFO duyệt, hiệu lực có mốc; báo cáo quá khứ giữ nguyên kèm chú thích điểm đổi.
- Tiền giữ hộ khách tăng đột biến cuối tháng (mùa top-up): dashboard tách rõ liability tăng — không tự động "đẹp" doanh thu; số dư ví hiển thị theo ngày chi dự kiến để BOD thấy nghĩa vụ chi hộ tương ứng.
- Timesheet duyệt trễ cuối kỳ: P&L kỳ tạm tính thiếu giờ chưa duyệt, có cờ "chờ duyệt N giờ"; khi duyệt xong, P&L tính lại ≤15 phút và ghi vết điều chỉnh — không bị số nhảy im lặng.
- Khách cần đối chiếu số qua Portal: không xuất dashboard nội bộ cho khách — chỉ cung cấp view REQ-FIN-017 (ví read-only, đã lọc tenant, không có giá vốn/chiết khấu/P&L).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Batch nạp dữ liệu star schema (load batch — mỗi nguồn, mỗi kỳ/chu kỳ)

**Sơ đồ trạng thái:**
```
[PENDING] ──(scheduler gọi)──► [RUNNING] ──(toàn bộ dòng hợp lệ)──► [SUCCESS]
                                  │
                                  │ (một phần dòng lỗi / thiếu nguồn)
                                  ▼
                             [PARTIAL] ──(bổ sung xong)──► [SUCCESS]
                                  │
                                  │ (retry hết lượt / nguồn chết)
                                  ▼
                              [FAILED] ──(SYS_ADMIN xử lý nguồn + FIN nộp manual có nhãn)──► [PARTIAL]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Scheduler kích hoạt | `RUNNING` | Hệ thống | Đến chu kỳ nạp (GW hourly, ví realtime ≤15 phút, timesheet 23:59, kế toán theo kỳ) |
| `RUNNING` | Tất cả dòng hợp lệ | `SUCCESS` | Hệ thống | Pass quality gate cơ bản (not-null, khớp lệnh, dung sai đối soát DI-001) |
| `RUNNING` | Một phần dòng lỗi | `PARTIAL` | Hệ thống | Danh sách dòng lỗi + ngoại lệ sinh cho FIN_L1 xử lý |
| `PARTIAL` | Bổ sung dữ liệu hợp lệ | `SUCCESS` | Hệ thống / FIN_L1 (manual có nhãn) | Dòng manual gắn nhãn + minh chứng; re-pass quality gate |
| `RUNNING`/`PARTIAL` | Retry hết lượt | `FAILED` | Hệ thống | Phát sự kiện alert (job sync fail — BR-BOD-006.1); hiển thị stale + timestamp hợp lệ cuối |

**Quy tắc:**
- Batch `FAILED` không được tự mất tích: bắt buộc nằm trong hàng chờ xử lý và phát alert; nguồn thay thế bằng nhập tay phải gắn nhãn "manual" không tắt.
- Batch `SUCCESS` ghi log bất biến (số dòng, mốc thời gian, hash dữ liệu) phục vụ truy vết "số này đến từ đâu" (data lineage).
- Không nạp đè batch cũ cùng kỳ — append-only version; điều chỉnh qua batch mới có tham chiếu batch gốc.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `load_batch` | `batch_id`, `source_code`, `period`, `status` (PENDING/RUNNING/PARTIAL/FAILED/SUCCESS), `row_count`, `data_hash`, `started_at`, `finished_at` | 1-N → dòng dữ liệu | Append-only + lineage; FAILED phát alert |
| `fact_pnl` | `batch_id`, `dim_customer_id`, `dim_project_id`, `dim_adaccount_id`, `dim_platform_id`, `revenue_service`, `cost_labor`, `cost_outsource`, `cost_tools`, `hold_liability` | FK → conformed dims + `load_batch` | Hold liability tách cột vĩnh viễn; không nhập tay |
| `dim_customer` / `dim_project` / `dim_adaccount` / `dim_platform` | Mã conformed, mã nguồn, tenant_id, effective dates | Dùng chung mọi fact | Một thực thể một mã — chống trùng dimension |
| `metric_effective_history` | `metric_id`, `version`, `formula_snapshot`, `effective_from/to`, `approved_by` (CFO) | FK → metric catalog | Nối FEAT-CORE-DHUB-002; báo cáo dùng version hiệu lực theo thời điểm dữ liệu |
| `quality_gate_result` | `gate_id`, `period`, `scope`, `checks`, `result`, `decided_by`, `risk_accept_note` | FK → kỳ dữ liệu | FIN_L2 duyệt; fail → chặn publish; chấp nhận rủi ro có audit |
| `pnl_query_audit` | `query_id`, `actor`, `role`, `params`, `queried_at` | FK → users | Meta-log truy xuất BOD — "xem cũng bị log" (nối REQ-BOD-005) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền đầy đủ ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Conformed dimension | Khách A tồn tại ở 3 nguồn (CRM, ví, TKQC) | Nạp star schema | Gộp về 1 mã khách conformed; không sinh 3 dimension trùng | [ ] |
| SC-002: Tách tiền giữ hộ | Khách nạp 200 triệu, phí dịch vụ 10 triệu | Xem P&L theo khách | Doanh thu = 10 triệu; 200 triệu hiển thị ở liability tách bạch | [ ] |
| SC-003: Quality gate chặn publish | Đối soát ví vs kế toán lệch 0,5% | FIN_L2 chạy gate kỳ | Gate fail → dashboard kỳ chặn publish cho BOD; quyết định sửa hoặc chấp nhận rủi ro được audit | [ ] |
| SC-004: Lịch sử hiệu lực metric | Định nghĩa GM đổi version 01/07 có CFO duyệt | Xem báo cáo tháng 06 và 07 | Tháng 06 dùng định nghĩa cũ, tháng 07 dùng mới; chú thích điểm đổi hiển thị | [ ] |
| SC-005: Không nhập tay | Cố ghi giá trị tay vào `fact_pnl` qua API | Request | Từ chối + log ngoại lệ; dữ liệu chỉ đến từ `load_batch` | [ ] |
| SC-006: Audit truy xuất | BOD_CFO_CTO xem P&L dự án X lúc 15:00 | Sau truy vấn | `pnl_query_audit` có bản ghi đầy đủ actor + params | [ ] |

> **Liên kết:** Mỗi scenario map về REQ-FIN-016 (Phần A `finance.md`, BR-FIN-307) và REQ-BOD-003 (Phần B `bod.md`, BR-BOD-003.x) cùng BR-DHUB-50x ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — star schema GĐ3, load batch, quality gate, lineage | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — P&L realtime query, quality gate, metric history | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — modules + GW, connector VAS, degraded/backfill DI-007 | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (counterpart WEB/MOBILE) | `phase4-ux/bcerp-web/datahub-bi/*.md`, `phase4-ux/mobile-internal/datahub-bi/*.md` |
| Feature liên quan cùng module | FEAT-CORE-DHUB-001 (nền star schema MVP), FEAT-CORE-DHUB-002 (Metric Catalog), FEAT-CORE-DHUB-003 (alert dòng tiền), FEAT-CORE-DHUB-004 (số liệu nguồn FIN) |
