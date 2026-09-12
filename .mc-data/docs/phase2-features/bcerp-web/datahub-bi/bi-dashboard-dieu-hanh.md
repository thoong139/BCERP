# Tính Năng: BI Dashboard Điều Hành

> **Dựa trên:** REQ-BOD-004 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** DataHub & BI — Data Integration Hub, BI/BOD Dashboard (SYS-BCERP-WEB)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md`, `phase5-implementation/tasks/bcerp-web/datahub-bi/feat-erp-dhub-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-DHUB-002 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-004 (BI dashboard điều hành tổng quan) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 3 (phân hệ BI/BOD Dashboard; Metric Catalog dựng từ MVP) |
| Phụ thuộc | FEAT-ERP-DHUB-001 (P&L realtime — một trong các KPI nguồn); Metric Catalog + ingestion đa nền tảng chịu lỗi của SYS-CORE-BACKEND; nền tảng RBAC/SSO |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-004 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-004 fan-out ra 3 hệ thống; bản này là bản riêng cho **SYS-BCERP-WEB** (web nội bộ responsive Next.js) — nơi BI workspace đầy đủ đặt tại. Counterparts: SYS-CORE-BACKEND (ingestion chịu lỗi, quality test, Metric Catalog service) và SYS-MOBILE-INTERNAL (bản KPI rút gọn + cảnh báo đỏ khi stale nghiêm trọng).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng BI workspace điều hành trên web nội bộ nơi BOD theo dõi tập hợp KPI một nguồn sự thật của toàn công ty — ROAS, GM (gross margin), SLA attainment, on-time delivery, pipeline coverage, capacity, aging công nợ, tỷ lệ die account — với khả năng drill-down tổng công ty → phòng → dự án. Tính năng tách khỏi REQ-BOD-003 vì khác phạm vi (đa KPI vận hành thay vì riêng P&L tài chính) và khác giai đoạn (Giai đoạn 3), nhưng dùng chung Metric Catalog và hạ tầng Data Integration Hub để mọi KPI chỉ có đúng một định nghĩa duy nhất trong toàn tổ chức.

**Phạm vi:**
- Bao gồm:
  - BI workspace trên web: trang tổng quan điều hành + trang theo phòng ban + trang theo dự án, drill-down qua 3 tầng tổng công ty → phòng → dự án.
  - Widget KPI đọc từ Metric Catalog, mỗi widget có chỉ báo freshness (nguồn + thời điểm cập nhật).
  - Quản lý Metric Catalog trên web: đăng ký metric mới (tên, công thức, nguồn, owner), đề xuất đổi định nghĩa — luồng duyệt của CFO tích hợp trong UI.
  - Cơ chế block publish báo cáo chính thức khi quality test của nguồn đang fail (hiển thị lý do block ngay trên màn hình publish).
  - Usage tracking: ghi nhận lượt xem từng widget/báo cáo phục vụ review nghỉ hưu metric.
  - Cảnh báo đỏ trên dashboard khi dữ liệu stale nghiêm trọng: chi tiêu QC >8 giờ, số dư ví >2 giờ, timesheet >24 giờ.
  - Breadcrumb truy xuất định nghĩa: từ một KPI xem được công thức hiệu lực, version và thời điểm có hiệu lực.
- Không bao gồm:
  - Chạy quality test tự động (not-null, uniqueness, đối soát ví vs kế toán ±0,1%) — thực thi ở SYS-CORE-BACKEND; WEB chỉ hiển thị kết quả pass/fail và chặn publish theo trạng thái.
  - P&L chi tiết và drill-down chi phí — thuộc FEAT-ERP-DHUB-001/005.
  - Alert center đa kênh (acknowledge, re-push, phân mức) — thuộc FEAT-ERP-DHUB-003; cảnh báo stale ở đây chỉ là trạng thái hiển thị trên widget.
  - Bản KPI rút gọn trên mobile — thuộc SYS-MOBILE-INTERNAL.
  - Nhập tay số liệu vào dashboard — bị cấm tuyệt đối (xem BR-007).

---

## 2. Luồng Người Dùng (User Stories)

BI workspace là nơi BOD "đọc báo cáo buổi sáng": mở một trang, thấy đủ sức khỏe công ty theo KPI đã chuẩn hóa, khoan xuống chỗ bất thường, và tin rằng mọi người trong công ty định nghĩa các con số đó giống nhau.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở dashboard điều hành thấy 8 nhóm KPI chuẩn (ROAS, GM, SLA attainment, on-time delivery, pipeline coverage, capacity, aging công nợ, die account) trên một màn hình | Nắm sức khỏe công ty trong vài phút mỗi sáng thay vì xin từng báo cáo rời |
| 2 | BOD_CEO | Drill-down từ KPI tổng công ty → phòng → dự án ngay trên workspace | Xác định phòng/dự án nào đang kéo KPI xuống mà không phải chờ phân tích |
| 3 | BOD_CFO_CTO | Đăng ký KPI mới vào Metric Catalog và duyệt đổi định nghĩa ngay trên web, có lịch sử hiệu lực | Mọi bộ phận dùng chung một định nghĩa; khi đổi, báo cáo cũ vẫn giải thích được |
| 4 | BOD_CFO_CTO | Thấy cảnh báo đỏ trên widget khi dữ liệu stale nghiêm trọng (chi QC >8h, ví >2h, timesheet >24h) | Không trình bày quyết định dựa trên số đã "ngủ" quá lâu |
| 5 | BOD_CFO_CTO | Khi publish báo cáo chính thức, hệ thống chặn nếu quality test của nguồn đang fail | Báo cáo phát ra ngoài chỉ được dựng trên dữ liệu đã qua kiểm định |
| 6 | SYS_ADMIN | Xem usage tracking và trạng thái quality test các nguồn để vận hành dashboard | Đề xuất nghỉ hưu widget/metric không ai dùng, giữ workspace gọn |
| 7 | BOD_CEO | Xem phiên bản định nghĩa KPI hiệu lực tại thời điểm của từng báo cáo cũ | So sánh quý này quý trước công bằng ngay cả khi định nghĩa đã đổi |
| 8 | BOD_CFO_CTO | Khi một nguồn chưa có quyền API, thấy nhãn "manual" kèm minh chứng lưu kèm từng kỳ | Vẫn dùng được số nhưng biết rõ chất lượng và trách nhiệm giải trình |

---

## 3. Quy Tắc Nghiệp Vụ

Các quy tắc về Metric Catalog và quality gate được enforce ở service layer; touchpoint web có trách nhiệm hiển thị đúng trạng thái (kể cả trạng thái "bị chặn") và không cung cấp đường vòng.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Mỗi metric có **một định nghĩa duy nhất** trong Metric Catalog; metric chưa đăng ký (tên, công thức, nguồn, owner) thì không được lên bất kỳ dashboard nào | Widget tham chiếu metric không tồn tại trong catalog → chặn render, báo "metric chưa đăng ký" |
| BR-002 | **Đổi định nghĩa metric chỉ CFO duyệt**, phản hồi ≤2 ngày làm việc; mọi thay đổi có lịch sử hiệu lực — báo cáo dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu | Định nghĩa đổi không qua duyệt → không áp dụng; UI hiển thị trạng thái "chờ duyệt" |
| BR-003 | Data Integration Hub gom dữ liệu từ các module nội bộ + GW; nguồn chưa qua quality gate (not-null, uniqueness, đối soát ví vs kế toán ±0,1%) không được tính KPI | Nguồn fail test → KPI phụ thuộc rơi trạng thái stale, dashboard hiển thị cảnh báo đỏ theo ngưỡng |
| BR-004 | **Block publish báo cáo chính thức khi quality test đang fail** — màn hình publish phải hiển thị đúng danh sách test đang fail và nguồn lỗi | Cố gắng publish khi fail → chặn ở tầng API, ghi sự cố vào audit |
| BR-005 | Chỉ báo freshness bắt buộc trên mọi widget; stale nghiêm trọng theo ngưỡng: chi tiêu QC >8h, số dư ví >2h, timesheet >24h → **cảnh báo đỏ** hiển thị nổi bật cho BOD | Widget thiếu freshness → không hiển thị số |
| BR-006 | Degraded mode: nguồn thiếu (chưa có quyền API developer — DI-007) thì dữ liệu gắn nhãn "manual" + minh chứng lưu kèm từng kỳ; nhãn không được tắt | Hiện số manual như số api → vi phạm, log sự cố và báo cáo đối soát |
| BR-007 | **Không nhập tay kết quả BI** — mọi số trên dashboard sinh tự động từ star schema qua Metric Catalog | Có chức năng nhập tay → vi phạm kiến trúc, chặn và đưa vào review |
| BR-008 | Báo cáo/widget **không có lượt xem trong 90 ngày** đưa vào danh sách review nghỉ hưu; quyết định nghỉ hưu do CFO duyệt trên web | Thêm metric mới tràn lan không kiểm soát → usage tracking flag vào hàng đợi review |
| BR-009 | Dữ liệu lương/PII chỉ aggregate khi được phép: KPI capacity/productivity hiển thị ở mức vai/nhóm, không lộ chi tiết cá nhân (giờ, lương) ngoài đúng quyền | Drill-down chạm mức cá nhân không phép → chặn ở API + ghi vi phạm |
| BR-010 | Mỗi lần BOD xem/xuất dashboard điều hành ghi audit log (meta-log); SYS_ADMIN không xem nội dung KPI nhạy cảm ngoài scope vận hành | Thiếu audit → request từ chối; lần truy xuất không log được thì không thực hiện |

---

## 4. Phân Quyền

Enforcement ở service layer core API; web ẩn/hiện theo vai để dẫn hướng. Các vai trong bảng thuộc 18 vai registry; không tồn tại vai ngoài registry (OPS_CX/FIN_COMPL đã bị loại theo DI-006).

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem dashboard điều hành + drill-down 3 tầng | ✅ | ✅ | ❌ |
| Đăng ký metric mới vào Metric Catalog | ✅ (đề xuất) | ✅ (đề xuất + duyệt) | ❌ |
| Duyệt đổi định nghĩa metric | ❌ | ✅ (chỉ CFO) | ❌ |
| Publish báo cáo chính thức | ❌ | ✅ (chỉ khi quality test pass) | ❌ |
| Xem trạng thái quality test / freshness nguồn | ✅ | ✅ | ✅ |
| Xem usage tracking, đề xuất nghỉ hưu widget | ❌ | ✅ (duyệt nghỉ hưu) | ✅ (xem số liệu, đề xuất kỹ thuật) |
| Cấu hình layout dashboard cá nhân | ✅ | ✅ | ✅ |
| Sửa/xóa số liệu KPI đã tổng hợp | ❌ | ❌ | ❌ (read-only tuyệt đối) |
| Xem giá trị nhạy cảm (T3/T4, P&L chi tiết) | ✅ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Định nghĩa pipeline còn chờ chốt nguồn:** KPI pipeline coverage phụ thuộc phân loại deal LOST và enum lý do mất deal — hiện là assumption `[KXN-17]`, `[KXN-21]` (định nghĩa 4 nhóm LOST A/B/C/D và 4 lý do LOST tại pitching/negotiation còn mở, chờ khách hàng xác nhận). Metric Catalog đăng ký định nghĩa tạm theo tài liệu v1.1, đánh dấu phiên bản "chờ chuẩn hóa"; khi KXN chốt thì đổi định nghĩa qua luồng BR-002, không tự ý đổi.
- **Metric mới phát sinh ngoài 8 nhóm chuẩn:** BOD_CEO/CFO muốn theo dõi thêm KPI (ví dụ tỉ lệ upsell) — bắt buộc đăng ký Metric Catalog qua luồng CFO duyệt; cấm dựng view ngoài luồng (SQL ad-hoc lên dashboard).
- **Module tương lai chưa có dữ liệu:** CMS/TMS/AI Agent đánh dấu "tương lai" trong bộ quy trình (phạm vi vẫn là assumption `[KXN-9]`); dashboard giữ sẵn chỗ cho widget nhưng không render KPI cho nguồn chưa triển khai — tránh cột rỗng gây hiểu nhầm.
- **Cả BOD vắng cùng lúc:** dashboard vẫn cập nhật; khi stale nghiêm trọng xảy ra, cảnh báo đỏ hiển thị lại ngay khi mở phiên làm việc tiếp theo — web không có cơ chế "đọc là xong" với cảnh báo mức đỏ (acknowledge thật thuộc FEAT-ERP-DHUB-003).
- **Tranh chấp số giữa phòng:** hai phòng trình bày hai con số khác nhau cho cùng "on-time delivery" — hệ thống trả lời bằng Metric Catalog: chỉ một định nghĩa hợp lệ; con số không khớp catalog không được công nhận trong họp điều hành.
- **Export phục vụ họp external:** xuất dashboard ra slide/PDF chỉ dành cho báo cáo chính thức đã publish (quality test pass); bản nháp nội bộ export được nhưng dán nhãn "bản nháp — không phát hành".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chính có vòng đời là **Metric Definition** trong Metric Catalog — đây là state machine lõi bảo đảm "một định nghĩa duy nhất" và lịch sử hiệu lực; trạng thái này web phải hiển thị đúng ở mọi widget tham chiếu.

**Entity:** Metric Definition (định nghĩa KPI trong Metric Catalog)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đăng ký)──► [PENDING_APPROVAL] ──(CFO duyệt ≤2 ngày LV)──► [ACTIVE]
                                    │                                          │
                                    │ (CFO từ chối)                            │ (đề xuất định nghĩa mới)
                                    ▼                                          ▼
                               [REJECTED]                              [CHANGE_PENDING]
                                    │                                          │
                                    └─(sửa lại)──► [DRAFT]                    │ (CFO duyệt bản mới)
                                                                               ▼
                                                                          [ACTIVE] (version mới,
                                                                           bản cũ RETIRED có hiệu lực lùi)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit đăng ký | `PENDING_APPROVAL` | BOD_CEO, BOD_CFO_CTO | Đủ tên, công thức, nguồn, owner |
| `PENDING_APPROVAL` | Duyệt | `ACTIVE` | BOD_CFO_CTO (CFO) | Trong ≤2 ngày làm việc; ghi version + effective_from |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | BOD_CFO_CTO | Nhập lý do từ chối bắt buộc |
| `REJECTED` | Sửa và submit lại | `DRAFT` | Người đề xuất | Cập nhật theo lý do từ chối |
| `ACTIVE` | Đề xuất đổi định nghĩa | `CHANGE_PENDING` | BOD_CEO, BOD_CFO_CTO | Tạo version draft mới, bản đang ACTIVE không đổi |
| `CHANGE_PENDING` | Duyệt bản mới | `ACTIVE` (version mới) | BOD_CFO_CTO | Version cũ chuyển `RETIRED` với effective_to; báo cáo lịch sử dùng đúng version theo thời điểm dữ liệu |

**Quy tắc:**
- Không thể chuyển thẳng `DRAFT` → `ACTIVE` (mọi metric phải qua CFO); không xóa metric đã từng `ACTIVE` — chỉ retire, bảo đảm báo cáo cũ luôn giải thích được.
- Widget chỉ được tham chiếu metric ở trạng thái `ACTIVE`; trạng thái khác → widget hiển thị "metric chờ duyệt/đã nghỉ hưu", không render số.
- Trạng thái `RETIRED` là kết thúc phiên bản (không kết thúc entity) — lịch sử version giữ vĩnh viễn kèm người duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `metric_definition` | `code`, `name`, `formula`, `source_ref`, `owner_role`, `state` | 1-N → `metric_version_history` | State machine Mục 6 |
| `metric_version_history` | `metric_code`, `version`, `formula`, `effective_from`, `effective_to`, `approved_by` | FK → `metric_definition` | Báo cáo tra cứu version theo thời điểm |
| `quality_test_run` | `source_code`, `test_type` (not-null/uniqueness/recon), `result`, `ran_at` | FK → `data_source` | Pass/fail điều khiển block publish |
| `data_source` | `code`, `type`, `state` (FRESH/STALE/DEGRADED...), `last_valid_at` | 1-N → `quality_test_run` | Chia sẻ với FEAT-ERP-DHUB-001 |
| `dashboard` / `dashboard_widget` | `dashboard_id`, `scope` (company/dept/project), `metric_code`, `filter_json` | FK → `metric_definition` | Layout 3 tầng drill |
| `widget_usage_log` | `widget_id`, `user_id`, `viewed_at` | FK → `dashboard_widget` | Nguồn cho review nghỉ hưu 90 ngày |
| `report_publication` | `report_id`, `version`, `published_by`, `quality_gate_snapshot` | FK → `dashboard` | Lưu snapshot kết quả test tại lúc publish |

---

## 8. Acceptance Criteria

> Phác thảo Phase 2, chi tiết hóa ở Phase 5. Map về REQ-BOD-004.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: KPI một nguồn sự thật | Metric Catalog có 8 nhóm KPI ACTIVE | BOD_CEO mở dashboard điều hành | 8 widget KPI render đúng định nghĩa ACTIVE, mỗi widget có freshness; không có widget nào dùng định nghĩa ngoài catalog | [ ] |
| SC-002: Block publish khi quality fail | Nguồn ví đang fail test đối soát ±0,1% | CFO bấm publish báo cáo chính thức phụ thuộc nguồn đó | Publish bị chặn; màn hình liệt kê test fail + nguồn; sự cố ghi audit | [ ] |
| SC-003: Đổi định nghĩa có lịch sử | CFO đề xuất đổi định nghĩa "on-time delivery" | CFO duyệt bản mới | Từ thời điểm hiệu lực mới, dashboard dùng bản mới; báo cáo cũ tra cứu vẫn ra bản cũ theo thời điểm dữ liệu | [ ] |
| SC-004: Metric chưa đăng ký không lên dashboard | Dev cấu hình widget tham chiếu metric lạ | Lưu cấu hình widget | Bị từ chối với thông báo "metric chưa đăng ký trong Metric Catalog" | [ ] |
| SC-005: Cảnh báo đỏ stale nghiêm trọng | Chi tiêu QC ngừng cập nhật >8 giờ | BOD mở dashboard | Widget chi tiêu QC hiển thị cảnh báo đỏ + thời điểm dữ liệu cuối; không hiện số như thể còn tươi | [ ] |
| SC-006: Review nghỉ hưu theo usage | Widget không lượt xem 90 ngày | Chạy kỳ review | Widget nằm trong danh sách đề xuất nghỉ hưu; CFO duyệt retire trên web | [ ] |
| SC-007: Đề xuất từ KXN mở | Định nghĩa nhóm LOST chưa chốt `[KXN-17]` | Đăng ký metric pipeline coverage | Metric lên dashboard ở trạng thái "định nghĩa tạm chờ chuẩn hóa", có nhãn rõ ràng trên UI | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu Metric Catalog, quality test, usage log | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (metric CRUD, quality status, publish gate) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp ingestion đa nền tảng chịu lỗi; DataHub ↔ GW | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI BI workspace (web nội bộ responsive) | `phase4-ux/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md` |
| Policy quản trị metric & chất lượng dữ liệu | `policies/quan-tri-metric-chat-luong-du-lieu.md` |
| Counterpart CORE (ingestion, quality engine) & MOBILE (KPI rút gọn) | `phase2-features/bcerp-core/datahub-bi/`, `phase2-features/mobile-internal/datahub-bi/` |
