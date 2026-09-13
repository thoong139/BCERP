# Tính Năng: P&L Toàn Công Ty Realtime (Bản Rút Gọn Mobile)

> **Dựa trên:** REQ-BOD-003 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/datahub-bi/pnl-realtime.md`, `phase5-implementation/tasks/mobile-internal/datahub-bi/feat-mbi-dhub-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-DHUB-001 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-003 (P&L toàn công ty realtime); liên kết chéo REQ-FIN-016 — FIN là nguồn số liệu, BOD là bên tiêu thụ dashboard |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — P&L cơ bản từ star schema) → Giai đoạn 3 (realtime, freshness ≤15 phút) |
| Phụ thuộc | Nền tảng ingestion + star schema của SYS-CORE-BACKEND (Data Integration Hub); FEAT-MBI-DHUB-003 (alert stale/đứt nguồn); MDM + MFA TOTP theo REQ-BOD-011; counterpart WEB: FEAT-ERP-DHUB-001 |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-003 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-003 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-MOBILE-INTERNAL** — ứng dụng React Native offline-capable. Toàn bộ tính toán P&L, nạp star schema và drill chi tiết thuộc counterpart SYS-CORE-BACKEND và SYS-BCERP-WEB; mobile chỉ tiêu thụ kết quả ở dạng **read-only rút gọn** theo nguyên tắc phân kênh (MOBILE = xem nhanh, cảnh báo; WEB = phân tích đầy đủ).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép BOD_CEO và BOD_CFO_CTO mở app mobile nội bộ thấy ngay bức tranh lãi/lỗ toàn công ty — doanh thu dịch vụ, tổng chi, margin, dòng tiền — ở dạng rút gọn cho màn hình nhỏ, độ tươi mục tiêu ≤15 phút, kèm nhãn nguồn dữ liệu (api/manual) trên từng con số. BOD không bao giờ ra quyết định trên mobile mà không biết mình đang tin dữ liệu tươi hay dữ liệu cũ, và không bao giờ đọc nhầm tiền giữ hộ của khách thành doanh thu của công ty.

**Phạm vi:**
- Bao gồm:
  - Dashboard P&L rút gọn theo đúng định nghĩa REQ-BOD-003 cho MOBILE: P&L top khách, top dự án, margin, dòng tiền — cuộn lên mức toàn công ty.
  - Chỉ báo freshness "cập nhật lúc HH:MM + nguồn api/manual" bắt buộc ở đầu dashboard và trên từng widget.
  - Nhãn degraded mode "manual — dữ liệu hợp lệ cuối HH:MM" khi một nguồn thiếu (connector lỗi, GW pull fail), kèm trạng thái "stale" nổi bật.
  - Hiển thị tách bạch tiền giữ hộ (nạp ví TKQC của khách — nợ phải trả) khỏi doanh thu dịch vụ ở mọi góc nhìn.
  - Drill-down một cấp trên mobile (tổng → nhóm khách/dự án); drill sâu hơn chuyển bằng deep-link sang web nội bộ (SYS-BCERP-WEB).
  - Cache offline read-only: khi mất mạng, hiển thị snapshot lần cuối đồng bộ kèm nhãn "offline — dữ liệu lúc HH:MM".
  - Audit truy xuất: mọi lần mở dashboard, lọc, drill trên mobile đều ghi audit log về CORE (ai, lúc nào, thiết bị, phạm vi).
- Không bao gồm:
  - Tính toán P&L, nạp star schema, conformed dimensions, job freshness — thuộc SYS-CORE-BACKEND.
  - Dashboard đầy đủ, export Excel/PDF, cấu hình widget, phân tích đa chiều — thuộc SYS-BCERP-WEB; mobile **không export, không cấu hình**.
  - Tra cứu audit log chi tiết trên mobile — **cấm** theo BR-BOD-005.3 (dữ liệu Mật/Restricted); chỉ nhận alert đứt chuỗi qua FEAT-MBI-DHUB-003.
  - Ghi/duyệt timesheet, duyệt chi outsource/tools — thuộc module HR-CORE / FIN tương ứng.
  - Cảnh báo rủi ro vận hành và luồng acknowledge — thuộc FEAT-MBI-DHUB-003.
  - KPI đa lĩnh vực (ROAS, SLA attainment...) — thuộc FEAT-MBI-DHUB-002.

---

## 2. Luồng Người Dùng (User Stories)

BOD dùng app nội bộ trên điện thoại được quản lý qua MDM, đăng nhập MFA TOTP bắt buộc; các user story phản ánh đúng touchpoint mobile — đọc nhanh, thao tác tối thiểu, phân tích sâu chuyển về web.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở app thấy ngay P&L tháng (doanh thu DV − chi phí) với nhãn "cập nhật lúc HH:MM" | Nắm sức khỏe công ty ngay khi đang di chuyển |
| 2 | BOD_CEO | Xem top khách và top dự án theo margin, sắp xếp từ thấp lên | Phát hiện sớm dự án đang ăn mòn lợi nhuận |
| 3 | BOD_CFO_CTO | Xem dòng tiền (số dư ví khả dụng theo nhóm, thu/chi tuần) rút gọn | Quyết định nhanh về hạn mức nạp, chi outsource khi ngoài công ty |
| 4 | BOD_CFO_CTO | Thấy tiền giữ hộ khách ở mục riêng "nợ phải trả", tách khỏi doanh thu | Không báo nhầm tiền khách thành doanh thu khi trình bày nhanh |
| 5 | BOD_CEO/BOD_CFO_CTO | Khi nguồn lỗi, thấy "manual — dữ liệu hợp lệ cuối 14:30" thay vì con số im lặng | Biết độ tin cậy của số trước khi chốt quyết định |
| 6 | BOD_CEO/BOD_CFO_CTO | Khi mất mạng, xem snapshot cuối kèm nhãn "offline — dữ liệu lúc HH:MM" | Có thông tin tham chiếu mà không nhầm với số tươi |
| 7 | BOD_CEO/BOD_CFO_CTO | Drill một cấp rồi bấm "phân tích chi tiết trên web" mở đúng màn WEB | Đọc nhanh trên mobile, đào sâu trên màn hình lớn đúng ngữ cảnh |
| 8 | SYS_ADMIN | Xem trạng thái nguồn dữ liệu (api/manual, freshness từng nguồn) để vận hành | Phát hiện nguồn stale trước khi BOD nhìn thấy |

---

## 3. Quy Tắc Nghiệp Vụ

Các quy tắc bắt buộc; phần lớn do service layer của SYS-CORE-BACKEND enforce — app mobile phải render đúng trạng thái API trả về, không tự tính lại, không nội suy, không che nhãn chất lượng dữ liệu.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Mobile là touchpoint **read-only tuyệt đối** cho P&L: không nhập, không sửa, không export, không cấu hình metric/widget dùng chung; chỉ tùy chọn hiển thị cá nhân | App có luồng ghi/export → chặn phát hành build; API từ chối method ghi |
| BR-002 | P&L hiển thị theo công thức Metric Catalog: **P&L = Doanh thu dịch vụ − (Σ giờ đã duyệt × cost rate + chi outsource + chi tools)**; app chỉ render kết quả + nhãn phiên bản công thức | App tự tính lại số → chặn build; số lấy nguyên trạng từ API |
| BR-003 | Tiền giữ hộ TKQC (khách nạp ví) là **nợ phải trả** — tách tuyệt đối khỏi doanh thu trên mọi widget, mọi khoảng tổng hợp | Widget gộp tiền giữ hộ vào doanh thu → chặn render, report sự cố |
| BR-004 | Giờ timesheet **chưa duyệt không vào P&L**; hiển thị dòng phụ "giờ đang chờ duyệt" tách riêng để CFO biết độ nhạy của số | API trả giờ chưa duyệt vào chi → CORE chặn; app hiển thị đúng phân tách |
| BR-005 | Freshness mục tiêu ≤15 phút; đầu dashboard và từng widget bắt buộc có "cập nhật lúc HH:MM + nguồn api/manual" | Widget thiếu freshness → không render số, hiển thị placeholder trạng thái |
| BR-006 | Degraded mode: nguồn thiếu → nhãn **"manual"/"stale" không được tắt**, kèm timestamp dữ liệu hợp lệ cuối; **cấm nội suy số ẩn** trên client | App nội suy số thiếu → vi phạm nghiêm trọng, hiển thị "không có dữ liệu" thay thế |
| BR-007 | Drill-down giới hạn một cấp (tổng → nhóm khách/dự án); đào sâu tiếp qua deep-link mở đúng màn tương ứng trên SYS-BCERP-WEB (phiên SSO hợp lệ) | App tự kéo cây drill chi tiết → API giới hạn depth cho kênh mobile |
| BR-008 | Giá trị cost rate nhân sự (T4) và giá vốn gói dịch vụ (T3) chỉ render cho BOD_CEO/BOD_CFO_CTO; **SYS_ADMIN không thấy giá trị T3/T4**; lock-screen/notification không hiển thị giá trị tài chính | API trả T3/T4 cho vai không phép → chặn ở service layer + audit vi phạm; notification lộ số → lỗi bảo mật P1 |
| BR-009 | Dữ liệu lương/PII chỉ tổng hợp (aggregate) vào P&L ở mức được phép — theo cost rate version ẩn danh, không xuống mức cá nhân trên mobile | Drill chạm mức cá nhân → API chặn, hiển thị mức nhỏ nhất cho phép |
| BR-010 | Mỗi lần truy xuất P&L trên mobile (mở, lọc, drill, xem snapshot offline) ghi audit log về CORE: user, thiết bị, thời điểm, phạm vi — hành vi truy xuất của BOD cũng bị log (meta-log) | Offline không ghi được → hàng đợi local mã hóa, flush bắt buộc khi có mạng trước khi xem dữ liệu mới |
| BR-011 | Cache offline chỉ chứa dữ liệu read-only đã mã hóa (Keychain/Keystore), gắn nhãn thời điểm chụp, chịu remote wipe MDM; không cache T3/T4 ngoài phạm vi vai | Thiết bị mất không wipe → sự cố an toàn dữ liệu; thu hồi phiên + rotate token ≤24h |
| BR-012 | Truy cập qua **MDM + MFA TOTP bắt buộc** với cả ba vai; mọi phiên ghi kênh "mobile" vào audit log; không có chế độ đăng nhập không MFA | Thiếu MFA → từ chối ở cả client và API, không có nhánh bỏ qua |

---

## 4. Phân Quyền

Phân quyền theo mô hình vai × Level × phạm vi dữ liệu của nền tảng RBAC (REQ-BOD-011); enforcement nằm ở service layer core API, app chỉ ẩn/hiện để dẫn hướng. Chỉ dùng 18 vai registry; vai ngoài BOD/SYS_ADMIN không có touchpoint trên tính năng này.

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem dashboard P&L rút gọn (top khách/dự án, margin, dòng tiền) | ✅ | ✅ | ❌ |
| Drill một cấp + deep-link sang WEB | ✅ | ✅ | ❌ |
| Xem giá trị cost rate T3/T4 trong biểu thị margin | ✅ | ✅ | ❌ (chỉ thấy trạng thái nguồn) |
| Export / cấu hình metric / chỉnh widget dùng chung | ❌ (đưa về WEB) | ❌ (đưa về WEB) | ❌ |
| Xem trạng thái nguồn dữ liệu (FRESH/STALE/DEGRADED, freshness) | ✅ | ✅ | ✅ |
| Tùy chỉnh hiển thị cá nhân trên thiết bị của mình | ✅ | ✅ | ✅ |
| Sửa/nhập số liệu P&L từ mobile | ❌ | ❌ | ❌ (read-only tuyệt đối mọi vai) |
| Đăng ký thiết bị MFA của mình | ✅ | ✅ | ✅ (thực thi sau phê duyệt, bị log) |
| Xem audit log chi tiết lượt truy xuất | ❌ (cấm trên mobile theo BR-BOD-005.3) | ❌ | ❌ |

Nguyên tắc bổ sung: BOD xem toàn bộ số thuộc phạm vi P&L; SYS_ADMIN chỉ vận hành trạng thái nguồn, không đọc giá trị T3/T4; mọi truy xuất từ kênh mobile ghi immutable audit log.

---

## 5. Trường Hợp Đặc Biệt

- **Mất kết nối mạng khi di chuyển:** app mở bằng snapshot cache mã hóa lần cuối đồng bộ, gắn nhãn lớn "offline — dữ liệu lúc HH:MM"; drill/deep-link vô hiệu; khi có mạng, flush hàng đợi audit (BR-010) rồi làm mới — không trộn số cũ vào luồng mới.
- **Connector sổ kế toán VAS lỗi:** theo DI-004 đã resolve, kết nối phần mềm kế toán là cấu hình kết nối ngoại vi vendor-agnostic tại MOD-SETTINGS-GW, không hardcode vendor; widget phụ thuộc hiển thị "stale + timestamp hợp lệ cuối", các nguồn còn lại vẫn tươi — không khóa toàn dashboard.
- **GW chưa có quyền API developer của nền tảng thứ 3:** chi tiêu nền tảng đó vào P&L theo nhãn "manual" kèm minh chứng từng kỳ; khi được cấp quyền và backfill xong, nhãn tự chuyển "api" — chênh lệch manual vs api >±0,1% vào báo cáo đối soát.
- **Đổi cost rate giữa kỳ (SCD2):** giờ trong quá khứ giữ nguyên rate version hiệu lực tại ngày ghi giờ; mobile hiển thị nhãn version đang áp để CFO giải thích margin tháng trước "thay đổi" khi duyệt rate hồi tố.
- **Kỳ mở vs kỳ đã khóa:** tháng FIN đã khóa hiển thị nhãn "đã chốt"; tháng đang mở hiển thị "tạm tính — còn biến động" (nhãn do API cung cấp) để BOD không chốt nhầm trên số chưa khóa.
- **Khung giờ chốt timesheet 23:59:** P&L trước/sau duyệt có thể nhảy; màn hiển thị dòng phụ "giờ chờ duyệt" kèm tác động ước lượng, tách khỏi số chính thức.
- **Đa tiền tệ:** số quy VND theo snapshot tỷ giá dùng chung (REQ-FIN-004); cho xem gốc ngoại tệ kèm tỷ giá snapshot, không dùng tỷ giá realtime riêng trên client.
- **Mất/thay thiết bị:** SYS_ADMIN thực thi remote wipe qua MDM + thu hồi thiết bị MFA theo offboarding khẩn ≤24h; thiết bị mới chỉ hoạt động sau đăng ký MFA step-up thành công.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chịu trạng thái và được mobile render trực tiếp là **nguồn dữ liệu (Data Source Feed)** trong Data Integration Hub — trạng thái nguồn quyết định cách từng widget hiển thị; app render đúng machine-state do API trả về, không suy diễn ở client.

**Entity:** Data Source Feed (nguồn nạp star schema: GW pull 7 nền tảng, ví QC realtime, timesheet, sổ kế toán VAS)

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(sync job chạy)──► [SYNCING] ──(thành công, trong SLA freshness)──► [FRESH]
    │                              │
    │ (lỗi kết nối / thiếu quyền API)   │ (quá hạn freshness)
    ▼                              ▼
[DEGRADED] ◄────────────────── [STALE]
    │  (backfill khi nguồn hồi phục)
    └──────(hồi phục + đối soát pass)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Sync job định kỳ chạy | `SYNCING` | Hệ thống | Theo lịch pull của từng nguồn |
| `SYNCING` | Sync thành công trong hạn freshness | `FRESH` | Hệ thống | Dữ liệu qua quality gate của CORE |
| `SYNCING` | Sync lỗi (mất kết nối, auth fail) | `DEGRADED` | Hệ thống | Ghi mã lỗi; nhãn "manual" bật tự động |
| `FRESH` | Quá hạn freshness của nguồn | `STALE` | Hệ thống | Widget phụ thuộc hiển thị stale; stale nghiêm trọng phát alert (FEAT-MBI-DHUB-003) |
| `DEGRADED` | Nguồn hồi phục + backfill + đối soát đạt | `ACTIVE` | Hệ thống; SYS_ADMIN kích hoạt backfill từ WEB | Chênh lệch manual vs api ≤±0,1% hoặc đã ghi vào báo cáo đối soát |
| `STALE` | Sync lại thành công | `FRESH` | Hệ thống | Dữ liệu mới qua quality gate |

**Quy tắc:**
- Không trạng thái nào cho phép ẩn nhãn nguồn: `DEGRADED`/`STALE` bắt buộc hiển thị "manual"/"stale" + timestamp hợp lệ cuối trên mọi widget phụ thuộc.
- Không thể chuyển thẳng `DEGRADED` → `FRESH` mà không qua backfill và kiểm tra chất lượng — chốt chống "số ma".
- Chuyển trạng thái do CORE quyết định; mobile không có nút đặt lại trạng thái; SYS_ADMIN chỉ kích hoạt backfill từ WEB.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity do SYS-CORE-BACKEND sở hữu; mobile tiêu thụ qua API và giữ cache mã hóa có kiểm soát. DDL đầy đủ tại technical spec của CORE.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pnl_fact` | `period_month`, `project_id`, `client_id`, `platform_id`, `revenue_service`, `cost_labor`, `cost_outsource`, `cost_tools`, `computed_at` | FK → `dim_project`, `dim_client`, `dim_platform` | Star schema do CORE nạp; mobile chỉ đọc qua API rút gọn |
| `dim_cost_rate` | `employee_role`, `rate_vnd`, `valid_from`, `valid_to` (SCD2) | FK → `dim_role` | Giá trị chỉ render cho CEO/CFO; không cache ngoài phạm vi vai |
| `data_source` | `code`, `type` (gw/wallet/timesheet/vas_ledger), `state`, `last_valid_at` | 1-N → `sync_event` | Trạng thái render theo mục 6 |
| `metric_definition` | `code`, `formula`, `version`, `effective_from`, `approved_by` | 1-N → `metric_version_history` | Định nghĩa chỉ CFO duyệt; mobile hiển thị nhãn version |
| `mobile_cache_manifest` | `device_id`, `user_id`, `snapshot_at`, `scope_hash`, `encryption_key_ref` | FK → `users`, `device_registry` | Siêu dữ liệu cache offline; MDM wipe dựa vào đây |
| `access_log` | `user_id`, `device_id`, `action`, `scope`, `channel` ("mobile"), `at` | FK → `users` | Append-only + hash-chain; truy xuất chi tiết chỉ trên WEB |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-BOD-003 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xem P&L rút gọn với freshness | BOD_CEO đăng nhập MFA; nguồn `FRESH` | Mở dashboard P&L | Thấy P&L tháng, top khách/dự án, margin, dòng tiền; mỗi widget có "HH:MM + nguồn api"; dữ liệu chênh ≤15 phút | [ ] |
| SC-002: Tiền giữ hộ tách bạch | Khách vừa nạp ví TKQC 200 triệu | Xem widget doanh thu | 200 triệu ở nhóm "nợ phải trả — tiền giữ hộ khách", doanh thu dịch vụ không tăng | [ ] |
| SC-003: Degraded mode đúng | Connector VAS mất kết nối | Mở dashboard | Widget phụ thuộc kế toán hiển thị "manual — dữ liệu hợp lệ cuối HH:MM", không có số nội suy; nguồn khác vẫn FRESH | [ ] |
| SC-004: Offline snapshot | App mất mạng sau khi đã sync | Mở lại app | Thấy snapshot kèm nhãn "offline — dữ liệu lúc HH:MM"; drill/deep-link vô hiệu; có mạng, audit queue flush rồi làm mới | [ ] |
| SC-005: Che T3/T4 theo vai và lock-screen | SYS_ADMIN đăng nhập; thiết bị khóa | Gọi mọi màn/API; nhận push | SYS_ADMIN không nhận giá trị T3/T4; lock-screen chỉ chữ "Dashboard P&L có cập nhật", không có số | [ ] |
| SC-006: Audit truy xuất mobile | CFO drill và lọc trên mobile | Kiểm tra `access_log` từ WEB | Mỗi thao tác có bản ghi user, thiết bị, thời điểm, phạm vi, channel="mobile"; meta-log ghi cả lần xem | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint mobile nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) star schema, SCD2 cost rate, cache manifest | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (P&L rút gọn, freshness, trạng thái nguồn, audit queue sync) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ GW ↔ modules; cache/offline và remote wipe MDM | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI dashboard P&L (React Native offline-capable) | `phase4-ux/mobile-internal/datahub-bi/pnl-realtime.md` |
| Bản counterpart: tính toán nguồn (CORE) | `phase2-features/core-backend/datahub-bi/` (FEAT tương ứng REQ-BOD-003) |
| Bản counterpart: dashboard đầy đủ + export (WEB) | `phase2-features/bcerp-web/datahub-bi/p-va-l-toan-cong-ty-realtime.md` (FEAT-ERP-DHUB-001) |
| Kênh cảnh báo khẩn trên mobile | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (FEAT-MBI-DHUB-003) |
