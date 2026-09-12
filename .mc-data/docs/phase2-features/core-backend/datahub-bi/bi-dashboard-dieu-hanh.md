# Tính Năng: BI dashboard điều hành

> **Dựa trên:** REQ-BOD-004 trong `phase1-business/departments/bod/bod.md` (Phần A — Mục REQ-BOD-004; Phần B — Mục B4)
> **Phân hệ:** Data Integration Hub & Analytics — BI/BOD Dashboard (SYS-CORE-BACKEND)
> **Module:** Data Integration Hub & Analytics — BI/BOD Dashboard (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/datahub-bi/*.md`, `phase5-implementation/tasks/core-backend/datahub-bi/feat-core-dhub-002-impl.md`

> **Hướng dẫn ID:** FEAT-CORE-DHUB-002 được tạo từ REQ-BOD-004 theo quy tắc chung trong req-registry (SYS=CORE-BACKEND, MOD=DATAHUB-BI). REQ này fan-out trên 3 systems — file này là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-BCERP-WEB (BI workspace — kênh xem chính), SYS-MOBILE-INTERNAL (bản KPI rút gọn + cảnh báo đỏ khi stale nghiêm trọng).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-DHUB-002 |
| Module | MOD-DATAHUB-BI (SYS-CORE-BACKEND) |
| Yêu cầu nghiệp vụ | REQ-BOD-004 — BI dashboard điều hành tổng quan (HIGH · Phase3; Metric Catalog dựng từ MVP) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase3 — phân hệ BI/BOD Dashboard; Metric Catalog dựng từ MVP của Giai đoạn 1) |
| Phụ thuộc | FEAT-CORE-DHUB-001 (star schema + P&L), ingestion đa nền tảng từ GW (nhãn api/manual theo DI-007), dữ liệu SLA/timesheet từ OPS/HR, aging công nợ từ FIN (REQ-FIN-007), pipeline coverage từ SALES |
| Ghi chú Expert (A7) | Dept doc `bod.md` có Mục A7 nhưng chưa ghi điều chỉnh đã chốt (chờ expert review) — spec hiện hành theo Phần A/B; khi A7 có điều chỉnh sẽ cập nhật dòng này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên core backend bộ KPI điều hành "một nguồn sự thật" cho BOD — ROAS, GM, SLA attainment, on-time delivery, pipeline coverage, capacity, aging công nợ, tỷ lệ die account — thông qua Metric Catalog chuẩn hóa và ingestion đa nền tảng chịu lỗi. Tính năng bảo đảm mỗi KPI trên dashboard điều hành chỉ có đúng một định nghĩa, một công thức, một chủ sở hữu, được kiểm định chất lượng tự động trước khi đến tay điều hành.

**Phạm vi:**
- Bao gồm: Metric Catalog (đăng ký tên/công thức/nguồn/owner, CFO duyệt, lịch sử hiệu lực); Data Integration Hub gom dữ liệu từ modules + GW; quality test tự động (not-null, uniqueness, đối soát ví vs kế toán ±0,1%); chặn publish báo cáo chính thức khi quality test đang fail; API phục vụ BI workspace drill tổng công ty → phòng → dự án (WEB) và bản KPI rút gọn (MOBILE); usage tracking từng widget; chỉ báo freshness mọi widget; nhãn "manual" + minh chứng lưu kèm từng kỳ khi chưa có quyền API.
- Không bao gồm: tính toán P&L chi tiết (FEAT-CORE-DHUB-001), alert center và delivery cảnh báo (FEAT-CORE-DHUB-003 — tính năng này chỉ phát sự kiện "stale nghiêm trọng"), dashboard vận hành tài chính của FIN (FEAT-CORE-DHUB-004), UI BI workspace (counterpart SYS-BCERP-WEB), dữ liệu cho khách/Portal (biên tin cậy nội bộ).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Gọi API xem bộ KPI điều hành theo tổng công ty → phòng → dự án | Đánh giá sức khỏe công ty theo cùng một nguồn số với mọi cấp |
| 2 | BOD_CEO | Thấy chỉ báo freshness và cảnh báo đỏ khi stale nghiêm trọng (chi tiêu QC >8h, số dư ví >2h, timesheet >24h) | Biết chắc con số mình đang nhìn "tươi" đến đâu trước khi quyết |
| 3 | BOD_CFO_CTO | Đăng ký metric mới/sửa định nghĩa metric trong Metric Catalog và duyệt (hoặc được CEO ủy phạm vi duyệt theo BR) | Kiểm soát toàn bộ định nghĩa KPI — không ai tự chế số ngoài luồng |
| 4 | BOD_CFO_CTO | Xem lịch sử hiệu lực định nghĩa metric | So sánh báo cáo các kỳ theo đúng định nghĩa hiệu lực tại thời điểm dữ liệu |
| 5 | SYS_ADMIN | Theo dõi health của ingestion đa nền tảng và kết quả quality test | Phát hiện sớm pipeline hỏng, giữ dashboard không chết số |
| 6 | Hệ thống (service CORE) | Tự chặn publish báo cáo chính thức khi quality test đang fail | Báo cáo điều hành không bao giờ xây trên dữ liệu bẩn |
| 7 | BOD_CFO_CTO | Xem usage tracking từng widget (ai xem, xem bao nhiêu) | Rà định kỳ widget không dùng để nghỉ hưu, giữ dashboard gọn |

**Đặc thù touchpoint SYS-CORE-BACKEND:** toàn bộ quy tắc (một định nghĩa/metric, chặn publish khi fail quality test, mask dữ liệu nhạy cảm, gắn nhãn manual) được enforce ở service layer — WEB/MOBILE chỉ hiển thị những gì service cho phép; không có nút "ghi đè số" ở bất kỳ kênh nào; Portal khách không được cấp API truy cập BI điều hành.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, toàn bộ enforce ở service layer của CORE.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-BOD-004.1 | Một metric chỉ có đúng một định nghĩa trong Metric Catalog (tên, công thức, nguồn, owner); metric chưa đăng ký không được xuất hiện trên dashboard | Service từ chối render/trả dữ liệu cho widget tham chiếu metric ngoài catalog; yêu cầu đi qua luồng đăng ký |
| BR-BOD-004.2 | Đổi định nghĩa metric chỉ CFO duyệt (≤2 ngày làm việc), có lịch sử hiệu lực; báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu | Version mới chưa duyệt không được kích hoạt; sửa trực tiếp DB bị chặn ở tầng dữ liệu (append-only version) |
| BR-BOD-004.3 | Chưa có quyền API (DI-007) → dữ liệu gắn nhãn "manual", minh chứng lưu kèm từng kỳ; Business Verification hoàn tất thì backfill tự động | Dữ liệu nhập tay không nhãn không được nạp vào KPI chính thức; service gắn cờ nguồn bắt buộc |
| BR-BOD-004.4 | Widget/metric không có usage 90 ngày đưa vào review nghỉ hưu | Báo cáo review sinh tự động; nghỉ hưu do CFO duyệt, không tự xóa dữ liệu lịch sử |
| BR-DHUB-201 | Data Integration Hub gom dữ liệu từ modules nội bộ + GW theo scheduler chịu lỗi (retry, backlog); nguồn thiếu → degraded mode, KPI liên quan hiển thị trạng thái thiếu nguồn tường minh | Không được im lặng trả KPI thiếu dữ liệu; metadata phản hồi phải liệt kê nguồn missing |
| BR-DHUB-202 | Quality test tự động: not-null, uniqueness, đối soát ví vs kế toán ±0,1% (dung sai theo chính sách đối soát DI-001); fail → block publish báo cáo chính thức cho đến khi pass hoặc CFO chấp nhận rủi ro có ghi nhận | Nút/API publish trả lỗi kèm danh sách test fail; không có đường bypass không vết |
| BR-DHUB-203 | Dữ liệu lương/PII chỉ aggregate khi được phép: KPI involving chi phí nhân sự chỉ trả ở mức tổng hợp cho BOD; SYS_ADMIN không thấy giá trị T3/T4; audit mọi truy xuất BOD (meta-log) | Truy vấn vượt phạm vi bị service mask/từ chối; lần truy cập bị log phục vụ REQ-BOD-005 |
| BR-DHUB-204 | Freshness SLA mỗi loại dữ liệu: chi tiêu QC ≤1h là tươi; stale nghiêm trọng — chi QC >8h, số dư ví >2h, timesheet >24h — phải phát sự kiện cảnh báo đỏ cho alert center | Widget stale phải hiển thị timestamp hợp lệ cuối; service phát sự kiện `stale_critical` cho FEAT-CORE-DHUB-003 |
| BR-DHUB-205 | KPI nội dung phản ánh đúng nghiệp vụ nguồn: GM theo ngưỡng nhóm dịch vụ (Agency ≥15%, Ads ops ≥20%, SEO ≥35%, Web/Thiết kế ≥30% `[CẦN CHỐT SỐ — ngưỡng khởi tạo]`, BR-FIN-308); SLA attainment từ dữ liệu SLA khách (Luồng 5); die account từ dữ liệu TKQC; tiêu chí đánh giá chất lượng vận hành dùng bộ tiêu chí đang hiệu lực `[KXN-6 — bộ tiêu chí Evaluation chính thức còn mở]` | KPI tính lệch nguồn/sai công thức bị quality test bắt; công thức sai lệch với catalog → chặn phát hành |
| BR-DHUB-206 | P&L/BI: tách tiền giữ hộ khỏi mọi KPI doanh thu (nối BR-BOD-003.1); không nhập tay kết quả BI | Phát hiện giá trị ghi đè tay → từ chối ghi và log ngoại lệ |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem dashboard KPI điều hành (tổng công ty → phòng → dự án) | ✅ | ✅ | ❌ (chỉ health pipeline, không thấy giá trị KPI) |
| Đăng ký metric mới vào Metric Catalog | ✅ (đề xuất) | ✅ (đề xuất + duyệt) | ❌ |
| Duyệt/sửa định nghĩa metric | ❌ (chỉ CFO duyệt) | ✅ | ❌ |
| Publish báo cáo chính thức | ✅ | ✅ | ❌ (bị chặn khi quality test fail — không có quyền bypass) |
| Xem usage tracking / review nghỉ hưu widget | ✅ | ✅ | ❌ |
| Vận hành ingestion, retry pipeline, chạy quality test | ❌ | ❌ | ✅ (thực thi, mọi thao tác bị log) |
| Sửa dữ liệu KPI đã tổng hợp | ❌ | ❌ | ❌ |

> Ghi chú: không tồn tại vai nào — kể cả Super Admin — sửa được định nghĩa metric ngoài luồng duyệt CFO; CUSTOMER/Portal không có quyền truy cập BI điều hành.

---

## 5. Trường Hợp Đặc Biệt

- Chưa có quyền API developer cho 7 nền tảng (DI-007): giữ nhãn "manual" + minh chứng lưu kèm từng kỳ; khi Business Verification được cấp, backfill tự động và đối chiếu chênh lệch >±0,1% vào báo cáo.
- Quality test fail đúng giờ họp BOD: dashboard vẫn xem được bản "draft có cảnh báo", nhưng publish báo cáo chính thức bị chặn cho đến khi pass — không cơ chế "publish trước, test sau".
- Metric cần đổi định nghĩa giữa quý (ví dụ cách tính on-time delivery): tạo version mới → CFO duyệt → hiệu lực từ mốc chỉ định; dữ liệu quá khứ giữ nguyên định nghĩa cũ; báo cáo so sánh liên kỳ hiển thị chú thích đổi định nghĩa.
- Widget 90 ngày không ai xem: hệ thống đưa vào danh sách review nghỉ hưu kỳ quý — CFO duyệt nghỉ hưu; dữ liệu nền không xóa, chỉ ngừng render.
- Nguồn dữ liệu SLA khách (Luồng 5) trễ: KPI SLA attainment đánh dấu stale theo ngưỡng; nếu trễ >24h đồng nghĩa với stale nghiêm trọng timesheet — phát cảnh báo đỏ.
- KPI đánh giá chất lượng vận hành (Brand Safety/Evaluation) phụ thuộc bộ tiêu chí chưa chốt chính thức `[KXN-6]` và cấu trúc báo cáo khách hàng `[KXN-7]`: metric chỉ đăng ký phần đã có nguồn xác định; phần còn lại ghi rõ trong catalog là "chờ định nghĩa" — không tự chế tiêu chí thay khách hàng.
- Pipeline coverage/LOST metrics phụ thuộc định nghĩa 4 nhóm LOST còn mở `[KXN-17]`: dùng enum đề xuất hiện hành, đánh dấu assumption, thay khi khách chốt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Metric trong Metric Catalog

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_REVIEW] ──(CFO approve)──► [APPROVED] ──(revise)──► [PENDING_REVIEW (v+1)]
                            │                                │
                            │ (reject)                       │ (deprecate)
                            ▼                                ▼
                       [REJECTED]                      [DEPRECATED] (ngừng render, giữ lịch sử)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_REVIEW` | BOD_CEO / BOD_CFO_CTO | Đủ tên, công thức, nguồn, owner |
| `PENDING_REVIEW` | Approve | `APPROVED` | BOD_CFO_CTO (CFO) | ≤2 ngày làm việc; ghi version + thời điểm hiệu lực |
| `PENDING_REVIEW` | Reject | `REJECTED` | BOD_CFO_CTO | Bắt buộc nhập lý do từ chối |
| `APPROVED` | Revise | `PENDING_REVIEW` (version mới) | BOD_CEO / BOD_CFO_CTO | Version cũ giữ nguyên hiệu lực đến khi version mới được duyệt |
| `APPROVED` | Deprecate | `DEPRECATED` | BOD_CFO_CTO | Widget phụ thuộc phải được chuyển/ngừng trước khi deprecate |

**Quy tắc:**
- Không xóa metric đã APPROVED — chỉ DEPRECATED; lịch sử hiệu lực append-only.
- Metric `REJECTED`/`DEPRECATED` không được render trên dashboard; service chặn ở tầng API.
- Mọi chuyển trạng thái ghi audit log (actor, timestamp, reason) — nối REQ-BOD-005.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `metric_catalog` | `metric_id`, `name`, `formula`, `source_refs`, `owner`, `status` | 1-N → `metric_version` | Một định nghĩa duy nhất mỗi metric |
| `metric_version` | `metric_id`, `version`, `formula_snapshot`, `effective_from`, `approved_by`, `approved_at` | FK → `metric_catalog`, `users` | Append-only; báo cáo dùng version hiệu lực tại thời điểm dữ liệu |
| `quality_test_result` | `test_id`, `scope`, `test_type`, `run_at`, `result`, `delta` | FK → nguồn dữ liệu | not-null/uniqueness/đối soát ±0,1%; fail → block publish |
| `kpi_snapshot` | `metric_id`, `period`, `value`, `source_label` (api/manual), `freshness_at`, `quality_flags` | FK → `metric_version` | Không nhập tay kết quả; kèm freshness + nhãn nguồn |
| `widget_usage` | `widget_id`, `actor`, `viewed_at`, `params` | FK → users | Usage tracking; 90 ngày không dùng → review nghỉ hưu; đồng thời là meta-log truy xuất |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền đầy đủ ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Metric chưa đăng ký | Widget gọi metric ngoài catalog | Request API | Service từ chối trả dữ liệu kèm hướng dẫn đăng ký; dashboard không render widget | [ ] |
| SC-002: Đổi định nghĩa metric | Metric ROAS version 1 APPROVED | CFO duyệt version 2 hiệu lực 01/10 | Báo cáo tháng 09 dùng v1, tháng 10 dùng v2; lịch sử hiển thị đủ | [ ] |
| SC-003: Block publish | Quality test đối soát ví vs kế toán lệch >±0,1% | Cố publish báo cáo chính thức | Publish bị chặn kèm danh sách test fail; mọi cố gắng bị log | [ ] |
| SC-004: Stale nghiêm trọng | Chi tiêu QC không cập nhật 9 giờ | Scheduler đánh giá freshness | KPI gắn cờ stale + timestamp hợp lệ cuối; sự kiện cảnh báo đỏ gửi alert center | [ ] |
| SC-005: Nhãn manual | Nền tảng X nhập tay trong kỳ | Truy vấn KPI liên quan | Dữ liệu mang nhãn "manual" + minh chứng kỳ; không thể tắt nhãn | [ ] |

> **Liên kết:** Mỗi scenario map về REQ-BOD-004 (Phần A/B `bod.md`) và BR-BOD-004.x / BR-DHUB-20x ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — metric catalog, version, quality test, usage | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — BI query, metric admin, publish gate | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — ingestion GW, degraded mode, backfill DI-007 | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (counterpart WEB/MOBILE) | `phase4-ux/bcerp-web/datahub-bi/*.md`, `phase4-ux/mobile-internal/datahub-bi/*.md` |
| Feature liên quan cùng module | FEAT-CORE-DHUB-001 (P&L + star schema), FEAT-CORE-DHUB-003 (alert stale), FEAT-CORE-DHUB-004 (nguồn số FIN), FEAT-CORE-DHUB-005 (BI/BOD theo góc nhìn FIN) |
