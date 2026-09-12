# Tính Năng: BI/BOD Dashboard & P&L Realtime

> **Dựa trên:** REQ-FIN-016 trong `phase1-business/departments/finance/finance.md` (Phần A — phối hợp BOD)
> **Phân hệ:** DataHub & BI — Data Integration Hub, BI/BOD Dashboard (SYS-BCERP-WEB)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/datahub-bi/bi-bod-dashboard-pnl.md`, `phase5-implementation/tasks/bcerp-web/datahub-bi/feat-erp-dhub-005-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-DHUB-005 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-FIN-016 (BI/BOD dashboard & P&L realtime — phối hợp BOD); liên kết chéo REQ-BOD-003 (BOD oversight yêu cầu P&L realtime — FEAT-ERP-DHUB-001 là bản BOD của cùng luồng) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | FEAT-ERP-DHUB-001 (nền P&L realtime dựng từ MVP — REQ-BOD-003); FEAT-ERP-DHUB-004 (dashboard FIN nội bộ GĐ2); star schema + conformed dimensions của SYS-CORE-BACKEND |
| Ghi chú Expert (A7) | Dept doc finance có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-FIN-016 — không có thay đổi phạm vi từ Expert Review |

REQ-FIN-016 fan-out ra 3 hệ thống; bản này là bản riêng cho **SYS-BCERP-WEB** — kênh xem chính của dashboard P&L theo dự án/khách cho đội tài chính. Phân vai fan-out: REQ-BOD-003 (FEAT-ERP-DHUB-001) là góc nhìn BOD của cùng luồng dữ liệu; bản này bổ sung góc nhìn FIN: FIN_L1/FIN_L2 dùng P&L như công cụ vận hành và kiểm soát dữ liệu nguồn trước khi BOD tiêu thụ. Counterparts: SYS-CORE-BACKEND, SYS-MOBILE-INTERNAL (dashboard BOD + alert dòng tiền).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Chấm dứt "mỗi người một bảng tính" trong phòng tài chính bằng cách đưa P&L realtime theo dự án/khách từ star schema (conformed dimensions: Khách, Dự án, TKQC, Nền tảng) lên web nội bộ cho FIN_L1/FIN_L2 dùng hằng ngày — đối chiếu doanh thu dịch vụ với chi phí thực, xác minh dữ liệu nguồn trước kỳ khóa, và bảo đảm mọi con số BOD nhìn thấy đều đi qua cùng một định nghĩa Metric Catalog do CFO duyệt với lịch sử hiệu lực đầy đủ.

**Phạm vi:**
- Bao gồm:
  - Dashboard P&L theo dự án/khách cho đội FIN: doanh thu dịch vụ, chi phí (giờ đã duyệt × cost rate, outsource, tools), margin theo dự án/khách/nền tảng với freshness ≤15 phút.
  - Widget kiểm soát dữ liệu nguồn của FIN: giờ timesheet chờ duyệt (tác động nếu duyệt), chi chưa phân loại overhead, lệch đối soát ảnh hưởng P&L — danh sách việc FIN cần xử lý để P&L "sạch".
  - Widget GM theo nhóm dịch vụ (Agency account, Ads ops, SEO, Web/Thiết kế) đối chiếu ngưỡng policy bảng giá/chiết khấu.
  - Xem/tìm kiếm Metric Catalog và lịch sử hiệu lực định nghĩa (FIN là bên đề xuất chỉnh định nghĩa tài chính, CFO duyệt).
  - So sánh P&L giữa các kỳ với cơ chế version: số chốt kỳ vs số tạm tính, hiển thị dòng điều chỉnh reversal riêng.
  - Xuất P&L chi tiết phục vụ khóa kỳ và luồng báo cáo (có watermark + audit log).
- Không bao gồm:
  - Dashboard điều hành đa KPI (ROAS, SLA attainment, pipeline...) — thuộc FEAT-ERP-DHUB-002; ở đây chỉ các metric tài chính.
  - Việc tính toán, ingestion, quality test — thuộc SYS-CORE-BACKEND; web gọi API hiển thị và thu thập thao tác.
  - Bản mobile BOD + alert dòng tiền — thuộc SYS-MOBILE-INTERNAL.
  - Sửa giao dịch nguồn (timesheet, lệnh chi, hóa đơn) — điều chỉnh chỉ diễn ra ở hệ thống nguồn qua luồng có reason code; dashboard read-only.
  - Bất kỳ khung xem nào cho khách qua Portal — biên tin cậy nội bộ theo BR-FIN-307.

---

## 2. Luồng Người Dùng (User Stories)

Đối với FIN, P&L realtime không phải công cụ xem mà là công cụ kiểm soát: dashboard chỉ ra chỗ dữ liệu chưa sạch, FIN xử lý ở hệ thống nguồn, P&L tự cập nhật — không ai chỉnh số trực tiếp trên báo cáo.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem P&L theo khách/nền tảng đang phụ trách đối soát với freshness ≤15 phút | Phát hiện sớm khoản chi bất thường thay vì đợi cuối tháng |
| 2 | FIN_L1 | Thấy danh sách giờ timesheet chờ duyệt và tác động của chúng lên P&L từng dự án | Ước lượng margin thật trước khi khuyến nghị duyệt/hắt lại timesheet |
| 3 | FIN_L2 | Xem chi chưa gắn mã dự án đang chờ phân loại overhead kèm lý do đã nhập | Ép dữ liệu sạch trước khóa kỳ, chi không lơ lửng trong margin |
| 4 | FIN_L2 | So sánh P&L tháng này với các tháng chốt, thấy rõ phần tạm tính vs phần đã chốt | Trình BOD số có độ tin cậy rõ ràng, không giải thích vớ vẩn khi số đổi |
| 5 | FIN_L2 | Đề xuất chỉnh định nghĩa metric tài chính qua Metric Catalog ngay trên web và theo dõi trạng thái duyệt của CFO | Định nghĩa tài chính do người trong nghề đề xuất, quy trình duyệt có dấu vết |
| 6 | BOD_CFO_CTO | Xem GM theo nhóm dịch vụ so với ngưỡng policy ngay trong dashboard P&L | Nhận biết deal/dịch vụ nào đang bán dưới ngưỡng để can thiệp giá |
| 7 | BOD_CFO_CTO | Tra lịch sử hiệu lực của một định nghĩa P&L cũ | Giải thích cho kiểm toán vì sao số năm trước tính khác số năm nay |
| 8 | FIN_L2 | Khi nguồn dữ liệu degraded, thấy nhãn "manual" + timestamp trên P&L | Không trình số có nguồn không sạch mà không biết |

---

## 3. Quy Tắc Nghiệp Vụ

Bản chất của REQ-FIN-016 là chuẩn hóa: một star schema, một Metric Catalog, một nguyên tắc tiền giữ hộ — áp cho cả góc nhìn FIN lẫn góc nhìn BOD (REQ-BOD-003) không cho phép hai luồng ra hai con số.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | P&L realtime tính từ star schema theo công thức Metric Catalog: **Doanh thu dịch vụ − (Σ giờ đã duyệt × cost rate + outsource + tools)**; conformed dimensions (Khách, Dự án, TKQC, Nền tảng) dùng chung mọi báo cáo | Báo cáo dùng dimension riêng → số không khớp luồng BOD; chặn và báo cáo lệch chuẩn |
| BR-002 | **Tiền giữ hộ (nạp ví TKQC) hiển thị tách bạch khỏi doanh thu** ở mọi widget, mọi cấp drill-down; chỉ tính doanh thu phí dịch vụ/markup | Gộp tiền khách vào doanh thu → chặn render + alert CTO |
| BR-003 | **Không nhập tay kết quả BI/P&L** — mọi con số sinh tự động từ star schema | Có đường nhập tay → vi phạm kiến trúc, chặn, đưa vào review |
| BR-004 | **Đổi định nghĩa metric phải CFO duyệt + có lịch sử hiệu lực**; FIN_L1/L2 chỉ ở vai đề xuất; báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu | Định nghĩa đổi không qua duyệt → không áp dụng; trạng thái "chờ duyệt" hiển thị rõ |
| BR-005 | Freshness ≤15 phút; chỉ báo "cập nhật lúc HH:MM + nguồn api/manual" bắt buộc trên dashboard và từng widget | Widget thiếu freshness → không hiển thị số |
| BR-006 | DataHub gom dữ liệu modules + GW; **degraded mode gắn nhãn "manual" + disclaimer độ trễ**, hiển thị dữ liệu hợp lệ cuối, không nội suy số ẩn | Nhãn bị tắt/số bị nội suy → vi phạm nghiêm trọng, log sự cố |
| BR-007 | **Giờ timesheet chưa duyệt không vào P&L**; dashboard hiển thị riêng dải "giờ chờ duyệt" để FIN ước lượng tác động | Giờ chưa duyệt lẫn vào chi → số sai, chặn và truy nguồn timesheet |
| BR-008 | **Chi không gắn mã dự án buộc phân loại overhead + lý do** ở hệ thống ghi nhận trước khi vào P&L; dashboard liệt kê chi chưa phân loại làm việc tồn của FIN | Chi lơ lửng → không vào P&L, nổi trong danh sách "chờ phân loại" |
| BR-009 | Dữ liệu lương/PII chỉ aggregate khi được phép: P&L hiển thị chi nhân sự qua cost rate version ở mức vai; chi tiết lương cá nhân không bao giờ xuất hiện trong drill-down P&L | Drill chạm mức lương cá nhân → chặn ở API + ghi vi phạm |
| BR-010 | **Audit truy xuất BOD**: mọi truy xuất/xuất P&L của FIN và BOD ghi audit log (ai, lúc nào, phạm vi); BOD truy xuất cũng bị log (meta-log); bản xuất có watermark | Xuất/truy xuất không log → từ chối thực hiện; thiếu meta-log là lỗi tuân thủ quarterly review |
| BR-011 | P&L của luồng FIN và luồng BOD (REQ-BOD-003/FEAT-ERP-DHUB-001) đọc cùng star schema cùng version metric — **không được tồn tại hai luồng tính ra hai con số** | Hai dashboard lệch số → sự cố P1, khóa widget và điều tra mapping |

---

## 4. Phân Quyền

FIN là bên vận hành và kiểm soát dữ liệu của P&L; BOD_CFO_CTO là điểm giao giữa góc nhìn FIN và BOD (CEO xem qua FEAT-ERP-DHUB-001 — bản BOD của REQ-BOD-003). Enforcement ở service layer; web ẩn/hiện để dẫn hướng.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Xem P&L theo dự án/khách/nền tảng + drill-down | ✅ (phạm vi phụ trách đối soát) | ✅ (toàn bộ) | ✅ (toàn bộ) |
| Xem dải "giờ chờ duyệt" / "chi chờ phân loại" | ✅ | ✅ | ✅ |
| Đề xuất định nghĩa metric mới/chỉnh định nghĩa | ✅ (đề xuất) | ✅ (đề xuất chính thức) | ✅ (duyệt — chỉ CFO) |
| Xem lịch sử hiệu lực Metric Catalog | ✅ | ✅ | ✅ |
| Xuất P&L chi tiết (khóa kỳ/báo cáo) | ✅ (bản vận hành) | ✅ (bản chính thức, có log) | ✅ |
| Khóa kỳ báo cáo | ❌ | ✅ (qua luồng khóa kỳ — state machine FEAT-ERP-DHUB-004) | ❌ (theo dõi; mở/đóng kỳ quản trị theo BR phân hệ FIN) |
| Xem giá trị cost rate T3/T4 trong drill-down | ❌ | ✅ | ✅ |
| Sửa số P&L đã tổng hợp | ❌ | ❌ | ❌ (read-only; điều chỉnh qua luồng nguồn có reason code) |
| Xem thống kê truy xuất P&L (audit) | ❌ | ✅ (phạm vi FIN) | ✅ (toàn bộ, gồm meta-log BOD) |

---

## 5. Trường Hợp Đặc Biệt

- **Hai REQ, một luồng dữ liệu:** REQ-FIN-016 và REQ-BOD-003 cùng đọc star schema; nếu phát hiện dashboard FIN và dashboard BOD lệch số (do version metric hoặc filter), hệ thống ưu tiên hiển thị cảnh báo lệch chuẩn thay vì để mỗi bên tin bảng của mình — sửa mapping là nhiệm vụ chung FIN + SYS.
- **GM theo nhóm dịch vụ có số chưa chốt ngưỡng:** ngưỡng GM khởi tạo (Agency account ≥15%, Ads ops ≥20%, SEO ≥35%, Web/Thiết kế ≥30%) đang gắn `[CẦN CHỐT SỐ]` theo policy bảng giá/chiết khấu; widget GM hiển thị ngưỡng cấu hình theo version và nhãn "ngưỡng chờ xác nhận chính thức" cho tới khi chủ dự án chốt.
- **Deal pilot và ngoại lệ GM:** deal pilot 1 tháng được GM dưới ngưỡng một kỳ (tối đa 60 ngày, GDKD duyệt) — dashboard hiển thị deal ngoại lệ có dấu và ngày hết hạn ngoại lệ, không coi ngoại lệ là chuẩn mới.
- **Chi phí media pass-through:** tính giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ — widget GM tách dòng media pass-through khỏi doanh thu dịch vụ để không làm loãng margin danh mục.
- **Connector kế toán VAS (DI-004):** kết nối ngoại vi vendor-agnostic cấu hình tại MOD-SETTINGS-GW; khi nguồn sổ kế toán degraded, P&L chạy với nhãn "manual" cho phần dữ liệu sổ, đối chiếu với phần GW/api vẫn hoạt động bình thường.
- **Định nghĩa pipeline không ảnh hưởng trực tiếp:** khác với FEAT-ERP-DHUB-002, các assumption `[KXN-17]`/`[KXN-21]` (nhóm LOST) không nằm trong phạm vi metric tài chính của FEAT này — chỉ ghi nhận để tránh đội FIN xây metric doanh thu dựa trên định nghĩa pipeline chưa chốt.
- **Cuối kỳ giao thời điểm chốt 23:59 timesheet:** dải "giờ chờ duyệt" đạt đỉnh trước giờ chốt; dashboard hiển thị timestamp giờ chốt để FIN biết margin trong khung này chưa gồm đợt giờ cuối ngày.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity có vòng đời trong phạm vi FEAT này là **Metric Definition (nhóm tài chính)** — dùng chung state machine với Metric Catalog (FEAT-ERP-DHUB-002) nhưng luồng đề xuất xuất phát từ FIN. Ngoài ra P&L kỳ báo cáo kế thừa state machine khóa kỳ của FEAT-ERP-DHUB-004.

**Entity:** Metric Definition — nhóm metric tài chính (P&L, GM, các thành phần chi)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(FIN đề xuất)──► [PENDING_APPROVAL] ──(CFO duyệt)──► [ACTIVE]
                                │                                  │
                                │ (CFO từ chối)                    │ (FIN/BOD đề xuất version mới)
                                ▼                                  ▼
                           [REJECTED]                        [CHANGE_PENDING] ──(CFO duyệt)──► [ACTIVE] (version mới;
                                │                                                                    bản cũ RETIRED)
                                └──(sửa lại)──► [DRAFT]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit đề xuất | `PENDING_APPROVAL` | FIN_L1, FIN_L2, BOD_CFO_CTO | Đủ tên, công thức, nguồn, phạm vi áp dụng |
| `PENDING_APPROVAL` | Duyệt | `ACTIVE` | BOD_CFO_CTO (chỉ CFO) | Ghi version + effective_from ≤2 ngày làm việc |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | BOD_CFO_CTO | Lý do từ chối bắt buộc |
| `REJECTED` | Chỉnh sửa lại | `DRAFT` | Người đề xuất | Cập nhật theo lý do |
| `ACTIVE` | Đề xuất version mới | `CHANGE_PENDING` | FIN_L1, FIN_L2, BOD_CFO_CTO | Bản đang chạy giữ nguyên đến khi duyệt |
| `CHANGE_PENDING` | Duyệt version mới | `ACTIVE` (version mới) | BOD_CFO_CTO | Bản cũ `RETIRED` với effective_to; báo cáo lịch sử dùng version theo thời điểm |

**Quy tắc:**
- Metric tài chính đã `ACTIVE` không xóa được — chỉ retire; P&L lịch sử luôn tái lập được theo version hiệu lực tại thời điểm.
- Widget P&L chỉ tham chiếu metric `ACTIVE`; khi có `CHANGE_PENDING`, widget hiển thị badge "đang có đề xuất đổi định nghĩa" để người xem biết số sắp thay đổi công thức.
- Trạng thái khóa kỳ của P&L tuân theo `reporting_period` (OPEN/LOCK_PENDING/CLOSED) — kết hợp hai trạng thái (metric version × kỳ) quyết định nhãn trên từng con số hiển thị.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pnl_fact` | `period_month`, `project_id`, `client_id`, `platform_id`, `revenue_service`, `cost_labor`, `cost_outsource`, `cost_tools`, `state` (tạm tính/chốt), `computed_at` | FK → `dim_*` conformed | Dùng chung FEAT-ERP-DHUB-001 |
| `pnl_adjustment` | `pnl_ref`, `reason_code`, `amount`, `created_by` | FK → `pnl_fact` | Dòng reversal có dấu vết, hiển thị riêng |
| `metric_definition` / `metric_version_history` | `code`, `formula`, `version`, `effective_from/to`, `proposed_by_role`, `state` | 1-N | State machine Mục 6; nhóm tài chính |
| `service_group_gm` | `service_group`, `gm_percent`, `threshold_vnd_config`, `threshold_version` | FK → `metric_definition` | GM theo nhóm dịch vụ, ngưỡng theo version |
| `unclassified_cost` | `cost_ref`, `amount`, `overhead_reason`, `state` (chờ/đã phân loại) | FK → chi phí nguồn | Việc tồn của FIN trước khóa kỳ |
| `pending_timesheet_summary` | `project_id`, `hours`, `impact_vnd`, `as_of` | FK → `dim_project` | Dải giờ chờ duyệt, không vào P&L |
| `export_log` / `pnl_access_log` | `user_id`, `at`, `scope_filter`, `action` (view/export) | FK → `users` | Audit + meta-log truy xuất BOD |

---

## 8. Acceptance Criteria

> Phác thảo Phase 2, chi tiết hóa ở Phase 5. Map về REQ-FIN-016 (và nhất quán với REQ-BOD-003).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: P&L FIN khớp P&L BOD | Cả hai dashboard chạy cùng star schema + version metric | So sánh P&L cùng kỳ cùng filter giữa FEAT-001 và FEAT-005 | Hai luồng trả về đúng một con số; mọi khác biệt đều giải thích được bằng version/filter hiển thị trên UI | [ ] |
| SC-002: Conformed dimensions đúng | Dữ liệu nạp từ timesheet, outsource, GW | Drill P&L theo Khách → Dự án → Nền tảng | Mỗi chiều roll-up đúng, tổng con khớp tổng cha; không có dimension riêng lẻ | [ ] |
| SC-003: Không nhập tay | FIN_L1 tìm chức năng chỉnh số P&L | Rà soát mọi màn hình | Không tồn tại đường nhập tay; mọi điều chỉnh chỉ qua luồng nguồn có reason code | [ ] |
| SC-004: Đổi định nghĩa đúng luồng | FIN_L2 đề xuất sửa công thức GM nhóm SEO | CFO duyệt trên web | Version mới áp dụng từ effective_from; báo cáo tháng trước tái lập vẫn ra công thức cũ | [ ] |
| SC-005: Giờ chờ duyệt tách riêng | 120 giờ timesheet chờ duyệt cuối tháng | Xem P&L dự án | Giờ chờ không nằm trong chi; dải "tác động nếu duyệt" hiển thị ước lượng riêng | [ ] |
| SC-006: Tiền giữ hộ tách bạch ở P&L | Khách nạp ví 300 triệu trong kỳ | Xem doanh thu kỳ | Doanh thu dịch vụ không đổi; 300 triệu hiển thị ở nhóm tiền giữ khách | [ ] |
| SC-007: GM ngưỡng theo version + nhãn chờ chốt | Ngưỡng GM đang ở `[CẦN CHỐT SỐ]` | Xem widget GM nhóm dịch vụ | Widget so sánh GM với ngưỡng theo version cấu hình; nhãn "ngưỡng chờ xác nhận chính thức" hiển thị | [ ] |
| SC-008: Audit truy xuất BOD đầy đủ | CFO truy xuất P&L chi tiết 3 lần, xuất 1 file | Rà soát audit log | 3 lần xem + 1 lần xuất được log; meta-log ghi cả truy xuất của BOD; file có watermark | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu star schema, SCD2, adjustment, GM config | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (P&L query, metric versioning, export, audit) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ FIN ↔ GW; nhất quán hai luồng FIN/BOD | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI P&L FIN + Metric Catalog (web nội bộ) | `phase4-ux/bcerp-web/datahub-bi/bi-bod-dashboard-pnl.md` |
| Business rule nguồn BR-FIN-307/308 | `phase1-business/departments/finance/finance.md` (Phần B) |
| Bản BOD của cùng luồng P&L | `phase2-features/bcerp-web/datahub-bi/p-va-l-toan-cong-ty-realtime.md` (FEAT-ERP-DHUB-001) |
| Counterpart CORE & MOBILE | `phase2-features/bcerp-core/datahub-bi/`, `phase2-features/mobile-internal/datahub-bi/` |
