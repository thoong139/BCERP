# Tính Năng: P&L Toàn Công Ty Realtime

> **Dựa trên:** REQ-BOD-003 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** DataHub & BI — Data Integration Hub, BI/BOD Dashboard (SYS-BCERP-WEB)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/datahub-bi/pnl-realtime.md`, `phase5-implementation/tasks/bcerp-web/datahub-bi/feat-erp-dhub-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-DHUB-001 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-003 (P&L toàn công ty realtime); liên kết chéo REQ-FIN-016 — FIN là nguồn số liệu, BOD là bên tiêu thụ dashboard |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — star schema + P&L cơ bản) → Giai đoạn 3 (realtime, freshness ≤15 phút) |
| Phụ thuộc | Nền tảng ingestion của Data Integration Hub ở SYS-CORE-BACKEND; FEAT-ERP-DHUB-005 (nguồn số FIN: sổ kế toán, ví, trạng thái đối soát); Cost Rate Card version theo REQ-HR-006 |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-003 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-003 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-BCERP-WEB** (web nội bộ responsive Next.js cho nhân viên BC). Việc tính toán và nạp star schema thuộc SYS-CORE-BACKEND; bản rút gọn read-only thuộc SYS-MOBILE-INTERNAL — hai counterpart này không đặc tả tại đây.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp cho BOD (BOD_CEO, BOD_CFO_CTO) một dashboard P&L toàn công ty trên web nội bộ, cập nhật gần realtime với freshness mục tiêu ≤15 phút, cho biết công ty đang lãi/lỗ ở chiều nào (dự án, khách, nền tảng TKQC, tháng) mà không phải chờ báo cáo tay cuối tháng. Tính năng chấm dứt tình trạng "mỗi người một bảng tính" bằng cách trình bày một nguồn sự thật duy nhất từ star schema CORE nạp, với chỉ báo độ tươi và nguồn dữ liệu trên từng widget.

**Phạm vi:**
- Bao gồm:
  - Dashboard P&L trên web nội bộ theo 4 chiều phân tích: dự án, khách, nền tảng TKQC, tháng — với tổng hợp cuộn lên mức toàn công ty.
  - Drill-down từ số tổng xuống chi tiết thành phần: giờ timesheet đã duyệt × cost rate, chi outsource, chi tools, chi phí nền tảng (media pass-through).
  - Chỉ báo freshness "cập nhật lúc HH:MM + nguồn api/manual" ở mức dashboard và ở từng widget.
  - Nhãn degraded mode "manual" khi một nguồn dữ liệu thiếu (GW pull lỗi, connector outage) kèm timestamp dữ liệu hợp lệ cuối cùng.
  - Tách bạch hiển thị tiền giữ hộ (nạp ví TKQC của khách) khỏi doanh thu dịch vụ trên mọi góc nhìn.
  - Export báo cáo P&L (Excel/PDF) có watermark người xuất + thời điểm, ghi audit log.
  - Breadcrumb truy xuất nguồn số liệu: từ một con số trên dashboard xem được nó đến từ bản ghi nguồn nào (timesheet, hóa đơn, statement).
- Không bao gồm:
  - Việc tính toán, nạp star schema, conformed dimensions và job freshness — thuộc SYS-CORE-BACKEND (WEB chỉ gọi API hiển thị).
  - Bản P&L rút gọn trên mobile nội bộ (top khách/dự án, margin, dòng tiền) — thuộc SYS-MOBILE-INTERNAL; drill chi tiết chuyển về WEB.
  - Việc ghi timesheet, duyệt timesheet, duyệt chi outsource/tools — thuộc module HR-CORE / FIN tương ứng.
  - Cảnh báo rủi ro vận hành và alert center — thuộc FEAT-ERP-DHUB-003.
  - Định nghĩa KPI đa lĩnh vực ngoài P&L (ROAS, SLA attainment, pipeline coverage...) — thuộc FEAT-ERP-DHUB-002.
  - Sửa/xóa số liệu tài chính nguồn — P&L trên WEB là read-only tuyệt đối, mọi điều chỉnh diễn ra ở hệ thống nguồn.

---

## 2. Luồng Người Dùng (User Stories)

BOD mở web nội bộ, thấy ngay bức tranh lãi/lỗ tổng thể rồi khoan xuống chi tiết; các user story dưới đây phản ánh đúng các thao tác trên touchpoint web (form/list/workflow UI gọi API core, hiển thị đúng trạng thái machine-state của dữ liệu nguồn).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở dashboard P&L toàn công ty thấy doanh thu dịch vụ, tổng chi phí và lợi nhuận của tháng hiện tại với nhãn "cập nhật lúc HH:MM" | Ra quyết định điều hành dựa trên số tươi, không chốt nhầm trên dữ liệu cũ |
| 2 | BOD_CEO | Drill-down từ P&L tổng → phòng → dự án → từng dòng chi (giờ × rate, outsource, tools) | Xác định chính xác dự án nào đang ăn mòn margin |
| 3 | BOD_CFO_CTO | Xem P&L theo nền tảng TKQC (Meta, Google, TikTok...) và theo khách | Đàm phán chiết khấu/phí dịch vụ và quản trị rủi ro tập trung ngân sách |
| 4 | BOD_CFO_CTO | Thấy tiền giữ hộ nạp ví TKQC hiển thị tách bạch khỏi doanh thu, ở trạng thái nợ phải trả | Đảm bảo không ai đọc nhầm tiền khách thành doanh thu của công ty |
| 5 | BOD_CFO_CTO | Xem phiên bản hiệu lực của cost rate (SCD2) đang áp cho từng kỳ | Đối soát margin khi rate thay đổi giữa kỳ mà không làm sai lệch số liệu lịch sử |
| 6 | BOD_CEO/BOD_CFO_CTO | Khi một nguồn dữ liệu lỗi, thấy nhãn "manual — dữ liệu hợp lệ cuối 14:30" thay vì một con số im lặng bị nội suy | Biết chính xác mình đang tin vào số gì trước khi quyết |
| 7 | SYS_ADMIN | Kiểm tra trạng thái machine-state của các nguồn dữ liệu (api/manual, freshness từng nguồn) để vận hành | Chủ động phát hiện nguồn stale trước khi BOD nhìn thấy |
| 8 | BOD_CEO | Export P&L tháng ra file có log truy xuất | Gửi đối tác/kiểm toán với bằng chứng số liệu có nguồn gốc |

---

## 3. Quy Tắc Nghiệp Vụ

Các quy tắc dưới đây là bắt buộc; phần hiển thị (WEB) phải phản ánh đúng trạng thái do service layer của CORE enforce — web không tự tính lại P&L và không được phép che giấu nhãn chất lượng dữ liệu.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | P&L tính theo công thức Metric Catalog: **P&L = Doanh thu dịch vụ − (Σ giờ đã duyệt × cost rate + chi outsource + chi tools)**; công thức do CORE áp, WEB chỉ hiển thị kết quả và nhãn phiên bản công thức | UI hiển thị số sai nguồn gốc → chặn render, báo lỗi nguồn số |
| BR-002 | Tiền giữ hộ TKQC (khách nạp ví) là **nợ phải trả** — tách tuyệt đối khỏi doanh thu trên mọi báo cáo, mọi chiều drill-down | Widget gộp tiền giữ hộ vào doanh thu → chặn publish, alert CTO |
| BR-003 | Giờ timesheet **chưa duyệt không được vào P&L** — chỉ giờ ở trạng thái đã duyệt mới được nhân cost rate | Số P&L lệch so với sổ → CORE từ chối tính dòng chi đó, dashboard hiển thị lượng giờ đang chờ duyệt riêng |
| BR-004 | Chi outsource/tools **không gắn mã dự án buộc chọn overhead + nhập lý do** ở hệ thống ghi nhận; P&L hiển thị nhóm overhead tách khỏi chi trực tiếp dự án | Chi lơ lửng không phân loại được → không vào P&L, nổi lên danh sách "chi chờ phân loại" cho FIN xử lý |
| BR-005 | Freshness mục tiêu ≤15 phút; mọi dashboard và widget hiển thị chỉ báo "cập nhật lúc HH:MM + nguồn api/manual" | Thiếu chỉ báo freshness → widget không được phép hiển thị số |
| BR-006 | Degraded mode: khi nguồn thiếu (connector kế toán VAS lỗi, GW pull lỗi), dữ liệu gắn nhãn **"manual" không được tắt**, hiển thị kèm timestamp dữ liệu hợp lệ cuối; **không nội suy số ẩn** | UI tự điền khoảng trống bằng số ước lượng → vi phạm nghiêm trọng, chặn tính năng và log sự cố |
| BR-007 | Một nguồn sự thật: không nhập tay kết quả P&L, không cho phép duy trì bảng tính song song làm nguồn hiển thị | Phát hiện nhập tay → từ chối lưu, cảnh báo về BOD |
| BR-008 | Giá trị cost rate nhân sự (T4) và giá vốn gói dịch vụ (T3) chỉ hiển thị cho BOD_CEO/BOD_CFO_CTO; **SYS_ADMIN không thấy giá trị T3/T4** trên bất kỳ màn hình hay API response nào | API trả T3/T4 cho vai không phép → chặn ở service layer + ghi vi phạm vào audit |
| BR-009 | Dữ liệu lương/PII chỉ được tổng hợp (aggregate) vào P&L ở mức được phép — hiển thị theo cost rate version, không bao giờ lộ chi tiết lương cá nhân xuống mức dòng | Drill-down chạm dữ liệu mức cá nhân → chặn, chỉ cho tới mức rate version ẩn danh |
| BR-010 | Mỗi lần BOD truy xuất/export P&L đều ghi audit log (ai, lúc nào, phạm vi, tham số lọc); hành vi truy xuất của BOD cũng bị log | Thiếu audit → không xuất được file, request bị từ chối |
| BR-011 | Data Integration Hub gom dữ liệu từ các module nội bộ (timesheet, FIN, OPS) và GW (chi tiêu 7 nền tảng, statement) vào star schema trước khi dashboard đọc; nguồn chưa qua quality gate không lên số | Nguồn fail quality gate → widget tương ứng rơi vào trạng thái stale/manual như BR-006 |

---

## 4. Phân Quyền

Phân quyền tuân theo mô hình vai × Level × phạm vi dữ liệu của nền tảng RBAC (18 vai registry); bảng dưới liệt kê hành động chính trên touchpoint web nội bộ. Enforcement nằm ở service layer của core API — UI chỉ ẩn/hiện để dẫn hướng, không phải lớp bảo vệ.

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem P&L toàn công ty + drill-down mọi chiều | ✅ | ✅ | ❌ |
| Xem giá trị cost rate T3/T4 trong drill-down | ✅ | ✅ | ❌ (chỉ thấy trạng thái nguồn, không thấy giá trị) |
| Xuất P&L ra file (Excel/PDF) | ✅ | ✅ | ❌ |
| Xem trạng thái nguồn dữ liệu (api/manual, freshness) | ✅ | ✅ | ✅ |
| Cấu hình layout dashboard cá nhân (chọn widget, bộ lọc mặc định) | ✅ | ✅ | ✅ |
| Thay đổi công thức P&L / đăng ký Metric Catalog | ❌ (xem + phê duyệt cấp cao) | ✅ (CFO duyệt, có lịch sử hiệu lực) | ❌ |
| Sửa/xóa dữ liệu P&L đã tổng hợp | ❌ | ❌ | ❌ (read-only tuyệt đối, điều chỉnh chỉ ở hệ thống nguồn) |
| Xem audit log truy xuất P&L của BOD | ✅ | ✅ | ✅ (metadata, không xem nội dung nghiệp vụ ngoài scope) |

Nguyên tắc bổ sung: BOD xem toàn bộ; SYS_ADMIN vận hành được trạng thái nguồn nhưng không đọc được giá trị tài chính nhạy cảm T3/T4; mọi hành vi của cả ba vai đều ghi immutable audit log.

---

## 5. Trường Hợp Đặc Biệt

- **Connector sổ kế toán VAS lỗi:** theo quyết định DI-004 đã resolve, kết nối phần mềm kế toán là **cấu hình kết nối ngoại vi vendor-agnostic** quản lý tại MOD-SETTINGS-GW, không hardcode vendor. Khi connector lỗi, dashboard hiển thị trạng thái "stale" + timestamp dữ liệu hợp lệ cuối, tiếp tục chạy với phần dữ liệu còn lại (degraded mode có kiểm soát).
- **GW chưa có quyền API developer của nền tảng thứ 3** (DI-007 còn theo dõi): chi tiêu nền tảng nhận theo nhãn "manual" với minh chứng lưu kèm từng kỳ; khi được cấp quyền và backfill xong, số tự chuyển nhãn "api" — chênh lệch manual vs API >±0,1% phải vào báo cáo đối soát.
- **Đổi cost rate giữa kỳ (SCD2):** giờ đã ghi trong quá khứ giữ nguyên rate version hiệu lực tại ngày ghi giờ; dashboard cho phép xem lại margin theo từng version rate để giải thích vì sao P&L tháng trước "thay đổi" khi rate áp hồi tố theo quyết định BOD.
- **Kỳ đang mở vs kỳ đã khóa:** P&L tháng đã FIN khóa kỳ hiển thị nhãn "chốt" (số không còn biến động trừ reversal có reason code); tháng đang mở hiển thị nhãn "số tạm tính, còn biến động" để BOD không chốt nhầm quyết định trên số chưa khóa.
- **Giờ timesheet đang chờ duyệt cuối ngày 23:59:** P&L realtime trong khung giờ chốt có thể lệch so với P&L sau duyệt; dashboard hiển thị thêm dòng "giờ chờ duyệt" ước lượng tác động để CFO nhận biết độ nhạy của số.
- **Khách nhiều nền tảng, đa tiền tệ:** mọi số P&L quy VND theo snapshot tỷ giá dùng chung (REQ-FIN-004); widget cho phép xem gốc ngoại tệ kèm tỷ giá snapshot đã dùng, không dùng tỷ giá realtime riêng lẻ.
- **BOD vắng, cần xem trên mobile:** bản rút gọn (top khách/dự án, margin) thuộc counterpart SYS-MOBILE-INTERNAL; mọi thao tác drill sâu và export bắt buộc quay về web nội bộ này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chính chịu trạng thái trong tính năng này là **nguồn dữ liệu (data source)** trong Data Integration Hub — trạng thái của nguồn quyết định trạng thái hiển thị của widget và là "machine-state" mà web phải render đúng.

**Entity:** Data Source Feed (nguồn dữ liệu nạp star schema: GW pull 7 nền tảng, ví QC, timesheet, sổ kế toán VAS)

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(sync job chạy)──► [SYNCING] ──(thành công, trong SLA freshness)──► [FRESH]
    │                              │
    │ (lỗi kết nối / thiếu quyền API)   │ (quá hạn freshness)
    ▼                              ▼
[DEGRADED] ◄────────────────── [STALE]
    │  (backfill khi nguồn hồi phục)
    └────────(hồi phục + đối soát pass)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Sync job định kỳ chạy | `SYNCING` | Hệ thống | Job scheduler theo lịch nguồn |
| `SYNCING` | Sync thành công trong hạn freshness | `FRESH` | Hệ thống | Dữ liệu qua quality gate, không lỗi schema |
| `SYNCING` | Sync lỗi (mất kết nối, auth fail) | `DEGRADED` | Hệ thống | Ghi mã lỗi; nhãn "manual" bật tự động |
| `FRESH` | Quá hạn freshness của nguồn | `STALE` | Hệ thống | Bật chỉ báo stale trên widget phụ thuộc |
| `DEGRADED` | Nguồn hồi phục + backfill + đối soát đạt | `ACTIVE` | Hệ thống; SYS_ADMIN kích hoạt backfill | Chênh lệch manual vs api ≤±0,1% hoặc đã ghi nhận vào báo cáo đối soát |
| `STALE` | Sync lại thành công | `FRESH` | Hệ thống | Dữ liệu mới qua quality gate |

**Quy tắc:**
- Không có trạng thái nào cho phép ẩn nhãn nguồn: `DEGRADED`/`STALE` bắt buộc hiển thị "manual"/"stale" + timestamp hợp lệ cuối trên mọi widget phụ thuộc — web không được render số mà không render trạng thái.
- Không thể chuyển thẳng `DEGRADED` → `FRESH` mà không qua backfill và kiểm tra chất lượng; đây là chốt chống "số ma" khi nguồn chập chờn.
- Chuyển trạng thái do hệ thống quyết định; SYS_ADMIN chỉ có thể kích hoạt lại job/backfill, không có nút "đặt thành FRESH" thủ công.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity dưới đây là phần web tiêu thụ qua API; DDL đầy đủ thuộc technical spec của SYS-CORE-BACKEND.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pnl_fact` | `period_month`, `project_id`, `client_id`, `platform_id`, `revenue_service`, `cost_labor`, `cost_outsource`, `cost_tools`, `computed_at` | FK → `dim_project`, `dim_client`, `dim_platform` | Star schema do CORE nạp; WEB chỉ đọc |
| `dim_cost_rate` | `employee_role`, `rate_vnd`, `valid_from`, `valid_to` (SCD2) | FK → `dim_role` | Chỉ CEO/CFO thấy giá trị; version bất biến |
| `data_source` | `code`, `type` (gw/ví/timesheet/vas_ledger), `state` (ACTIVE/SYNCING/FRESH/STALE/DEGRADED), `last_valid_at` | 1-N → `sync_event` | Trạng thái render trên UI theo mục 6 |
| `metric_definition` | `code` (PNL_SERVICE_REV...), `formula`, `version`, `effective_from`, `approved_by` | 1-N → `metric_version_history` | Đổi định nghĩa chỉ CFO duyệt |
| `dashboard_widget` | `dashboard_id`, `metric_code`, `filter_json`, `position` | FK → `dashboard`, `metric_definition` | Layout theo user, không đụng số liệu |
| `export_log` | `user_id`, `exported_at`, `filter_json`, `file_ref` | FK → `users` | Immutable audit, dùng cho quarterly review |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5 (implementation tasks). Mỗi scenario map về REQ-BOD-003 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xem P&L tổng với freshness | BOD_CEO đăng nhập web nội bộ; các nguồn `FRESH` | Mở dashboard P&L toàn công ty | Thấy tổng doanh thu DV, chi, P&L tháng hiện tại; mỗi widget có "cập nhật lúc HH:MM + nguồn api"; độ lệch so với lần tính trước ≤15 phút | [ ] |
| SC-002: Drill-down đúng chiều | P&L tổng hiển thị | Click vào số P&L của một dự án → một dòng chi | Xem được chuỗi giờ đã duyệt × rate, outsource, tools; không thấy giờ chưa duyệt lẫn vào chi | [ ] |
| SC-003: Tiền giữ hộ tách bạch | Khách vừa nạp ví TKQC 200 triệu | Xem widget doanh thu | 200 triệu xuất hiện ở nhóm nợ phải trả "tiền giữ hộ khách", không làm tăng doanh thu dịch vụ | [ ] |
| SC-004: Degraded mode hiển thị đúng | Connector sổ kế toán VAS mất kết nối | Mở dashboard | Widget phụ thuộc nguồn kế toán hiển thị "manual — dữ liệu hợp lệ cuối HH:MM", không có số bị nội suy; widget của các nguồn còn lại vẫn ở trạng thái FRESH | [ ] |
| SC-005: Che giá trị T3/T4 với SYS_ADMIN | SYS_ADMIN đăng nhập | Gọi mọi màn hình/API dashboard | Không nhận được giá trị cost rate T3/T4 trong response; thấy được trạng thái nguồn | [ ] |
| SC-006: Export có audit | CFO export P&L tháng 08 | Tải file | File có watermark user + thời điểm; `export_log` ghi bản ghi; meta-log ghi cả lần xem và lần xuất | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint web.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) star schema, SCD2 cost rate | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (P&L query, drill-down, freshness, export) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ GW ↔ modules; degraded mode & backfill | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI dashboard P&L (web nội bộ responsive) | `phase4-ux/bcerp-web/datahub-bi/pnl-realtime.md` |
| Bản counterpart: tính toán nguồn (CORE) | `phase2-features/bcerp-core/datahub-bi/` (FEAT tương ứng REQ-BOD-003) |
| Bản counterpart: mobile rút gọn | `phase2-features/mobile-internal/datahub-bi/` (FEAT tương ứng REQ-BOD-003) |
