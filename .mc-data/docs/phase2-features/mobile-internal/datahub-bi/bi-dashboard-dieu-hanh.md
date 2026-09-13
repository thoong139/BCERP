# Tính Năng: BI Dashboard Điều Hành (Bản KPI Rút Gọn Mobile)

> **Dựa trên:** REQ-BOD-004 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/datahub-bi/bi-dashboard.md`, `phase5-implementation/tasks/mobile-internal/datahub-bi/feat-mbi-dhub-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-DHUB-002 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-004 (BI dashboard điều hành) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 3 (phân hệ BI/BOD Dashboard; Metric Catalog dựng từ MVP trên CORE) |
| Phụ thuộc | Metric Catalog + ingestion chịu lỗi + quality test của SYS-CORE-BACKEND; counterpart WEB FEAT-ERP-DHUB-002 (BI workspace đầy đủ, publish báo cáo); FEAT-MBI-DHUB-003 (cảnh báo đỏ stale đẩy về mobile); REQ-BOD-011 (MDM + MFA TOTP) |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-004 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-004 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-MOBILE-INTERNAL** — React Native offline-capable. Tách khỏi REQ-BOD-003 theo đúng định nghĩa dept doc: REQ-BOD-003 là P&L (một chỉ số tài chính, realtime ≤15 phút); REQ-BOD-004 là bộ KPI điều hành đa lĩnh vực (hiệu quả QC, SLA, bán hàng, năng lực, công nợ) và thuộc Giai đoạn 3. Trên mobile, REQ-BOD-004 chỉ mang **bản KPI rút gọn** — BI workspace đầy đủ với drill-down đa tầng và publish báo cáo thuộc SYS-BCERP-WEB.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa lên điện thoại của BOD_CEO/BOD_CFO_CTO bộ KPI điều hành rút gọn một nguồn sự thật (ROAS, GM, SLA attainment, aging công nợ, tỷ lệ die account) với chỉ báo freshness trên từng widget, cùng cảnh báo đỏ ngay trên app khi dữ liệu stale nghiêm trọng — để lãnh đạo nắm nhịp vận hành mọi lúc mà vẫn biết chính xác mình đang nhìn dữ liệu tươi hay dữ liệu cũ. Mọi con số đều đến từ Metric Catalog đã CFO duyệt, chấm dứt tình trạng mỗi phòng dùng một định nghĩa KPI riêng.

**Phạm vi:**
- Bao gồm:
  - Màn KPI rút gọn theo đúng danh mục REQ-BOD-004 dành cho MOBILE: ROAS, GM (gross margin), SLA attainment, aging công nợ, tỷ lệ die account — tổng hợp cấp công ty, cho phép lọc nhanh theo tháng/khách.
  - Chỉ báo freshness bắt buộc trên mọi widget ("cập nhật lúc HH:MM + nguồn api/manual").
  - **Cảnh báo đỏ khi stale nghiêm trọng** hiển thị nổi bật trên app theo ngưỡng đã chốt: chi tiêu QC >8 giờ, số dư ví >2 giờ, timesheet >24 giờ (dẫn nguồn về FEAT-MBI-DHUB-003 để nhận push).
  - Hiển thị trạng thái Metric Catalog của từng KPI (mã, phiên bản định nghĩa đang hiệu lực, người duyệt) để người xem biết số đang tính theo định nghĩa nào.
  - Deep-link một chạm từ widget sang màn phân tích tương ứng trên SYS-BCERP-WEB (SSO, đúng ngữ cảnh lọc).
  - Audit truy xuất: mọi lần mở/lọc KPI trên mobile ghi log về CORE (meta-log).
- Không bao gồm:
  - BI workspace đầy đủ, drill tổng công ty → phòng → dự án, usage tracking, publish báo cáo chính thức — thuộc SYS-BCERP-WEB; **mobile không có nút publish**, không cấu hình widget dùng chung.
  - Việc đăng ký/duyệt định nghĩa metric — thao tác thuộc WEB; mobile chỉ **xem** trạng thái và phiên bản hiệu lực.
  - P&L realtime chi tiết — thuộc FEAT-MBI-DHUB-001/005.
  - Luồng nhận + acknowledge alert — thuộc FEAT-MBI-DHUB-003; màn này chỉ hiển thị trạng thái stale dạng banner.
  - Việc tính toán, quality test, ingestion đa nền tảng — thuộc SYS-CORE-BACKEND.

---

## 2. Luồng Người Dùng (User Stories)

Mobile BI là màn "đọc nhanh — biết tin — chuyển web để đào sâu": các user story phản ánh đúng giới hạn touchpoint đọc-only rút gọn.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở app thấy 5 nhóm KPI rút gọn (ROAS, GM, SLA attainment, aging công nợ, die account) của tháng với nhãn freshness | Nắm nhịp vận hành toàn công ty trong lúc chờ họp/đi đường |
| 2 | BOD_CEO | Thấy banner đỏ ngay khi chi tiêu QC stale >8 giờ | Không trích số ROAS cũ để phán xét hiệu quả campaign trước khi hỏi OPS |
| 3 | BOD_CFO_CTO | Chạm vào một KPI để xem định nghĩa đang hiệu lực (phiên bản Metric Catalog, ngày CFO duyệt) | Biết chắc mình so sánh số theo đúng định nghĩa, không so trôi version |
| 4 | BOD_CFO_CTO | Lọc nhanh aging công nợ theo nhóm khách | Chuẩn bị câu hỏi cho buổi họp với AM của nhóm khách chậm thanh toán |
| 5 | BOD_CEO/BOD_CFO_CTO | Nhấn "phân tích chi tiết trên web" từ bất kỳ widget | Chuyển liền mạch sang BI workspace đầy đủ với đúng bộ lọc đang chọn |
| 6 | BOD_CEO/BOD_CFO_CTO | Khi máy offline, xem snapshot KPI cuối kèm nhãn "offline — dữ liệu lúc HH:MM" | Vẫn có tham chiếu mà không nhầm số cũ thành số tươi |
| 7 | SYS_ADMIN | Xem trạng thái nguồn và quality test của từng KPI nguồn | Phát hiện nguồn fail test trước khi nó hiển thị sai lên màn BOD |
| 8 | BOD_CFO_CTO | Thấy nhãn "manual" trên KPI của nền tảng chưa cấp quyền API kèm minh chứng kỳ | Minh bạch độ tin cậy số khi báo cáo lên chủ nợ/đối tác từ chính điện thoại |

---

## 3. Quy Tắc Nghiệp Vụ

Các quy tắc bắt buộc; enforce chính ở service layer CORE (Metric Catalog, quality gate), app mobile có trách nhiệm render đúng trạng thái và không phá vỡ rào cản read-only.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Widget KPI chỉ được tham chiếu metric đã đăng ký Metric Catalog và ở trạng thái **ACTIVE**; metric chưa đăng ký/không ACTIVE không được lên màn mobile | Widget tham chiếu metric chờ duyệt → hiển thị "metric chờ duyệt/đã nghỉ hưu", không render số |
| BR-002 | Một định nghĩa duy nhất mỗi metric; **đổi định nghĩa chỉ CFO (BOD_CFO_CTO) duyệt**, có lịch sử hiệu lực; báo cáo/dashboards dùng đúng định nghĩa hiệu lực tại thời điểm dữ liệu | App hiển thị số trộn version → chặn render; API phải trả kèm version cho mọi điểm số |
| BR-003 | Chưa có quyền API của nền tảng → KPI liên quan giữ nhãn **"manual"** kèm minh chứng lưu theo từng kỳ; không tắt nhãn, không nội suy | App tự làm trơn/điền số → vi phạm nghiêm trọng, hiển thị "không có dữ liệu" |
| BR-004 | Mọi widget có chỉ báo freshness "cập nhật lúc HH:MM + nguồn"; **cảnh báo đỏ stale nghiêm trọng theo ngưỡng chốt: chi tiêu QC >8h, số dư ví >2h, timesheet >24h** | Widget stale vượt ngưỡng mà không bật cảnh báo đỏ → lỗi P2, banner đỏ bắt buộc hiển thị trên đầu app |
| BR-005 | Mobile chỉ xem: không publish, không export, không sửa định nghĩa, không cấu hình widget dùng chung; tùy chỉnh chỉ ở mức hiển thị cá nhân trên thiết bị | Build có luồng ghi → chặn phát hành; API từ chối mọi method ghi từ kênh mobile |
| BR-006 | Chỉ số gắn dữ liệu lương/PII chỉ tổng hợp ở mức được phép; drill mức cá nhân không tồn tại trên mobile | API lộ mức cá nhân → chặn ở service layer + audit vi phạm |
| BR-007 | Mọi truy xuất KPI trên mobile ghi audit log (user, thiết bị, thời điểm, phạm vi, channel="mobile"); hành vi xem của BOD cũng bị log | Offline không ghi được → đưa vào hàng đợi mã hóa, flush bắt buộc khi có mạng |
| BR-008 | Cache offline mã hóa (Keychain/Keystore), gắn nhãn thời điểm chụp, chịu remote wipe MDM; MFA TOTP bắt buộc mọi phiên | Cache không mã hóa/phiên không MFA → chặn đăng nhập, coi như sự cố an toàn dữ liệu |
| BR-009 | Trên lock-screen/notification không hiển thị giá trị KPI hay trạng thái tài chính chi tiết — chỉ văn bản trung tính | Push lộ số → lỗi bảo mật P1, sửa ở tầng nội dung notification |
| BR-010 | Data Integration Hub gom dữ liệu từ các module nội bộ và GW vào star schema; nguồn chưa qua quality test không lên số trên bất kỳ kênh nào, kể cả mobile | Nguồn fail test vẫn render → API chặn; widget rơi vào trạng thái stale/manual |

---

## 4. Phân Quyền

Enforcement ở service layer core API; bảng dưới liệt kê hành động chính trên touchpoint mobile. Các vai ngoài ba vai dưới đây không có touchpoint trên tính năng này (phân quyền chỉ dùng 18 vai registry).

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem màn KPI rút gọn + freshness mọi widget | ✅ | ✅ | ❌ |
| Xem phiên bản định nghĩa Metric Catalog đang hiệu lực | ✅ | ✅ | ✅ (metadata, không xem giá trị T3/T4) |
| Nhận banner đỏ stale nghiêm trọng trên app | ✅ | ✅ | ✅ (dạng kỹ thuật, không gắn giá trị tài chính) |
| Đề xuất đăng ký/đổi định nghĩa metric từ mobile | ❌ (đưa về WEB) | ❌ (duyệt trên WEB) | ❌ |
| Publish báo cáo chính thức | ❌ (chỉ trên WEB) | ❌ (chỉ trên WEB) | ❌ |
| Cấu hình widget dùng chung / dashboard workspace | ❌ | ❌ | ❌ |
| Xem trạng thái nguồn + kết quả quality test | ✅ | ✅ | ✅ |
| Tùy chỉnh hiển thị cá nhân trên thiết bị | ✅ | ✅ | ✅ |
| Đăng ký/thu hồi thiết bị MFA của mình | ✅ | ✅ | ✅ (thực thi sau phê duyệt, bị log) |

Nguyên tắc bổ sung: SYS_ADMIN không thấy giá trị T3/T4 trên bất kỳ màn hình nào; mọi thao tác của ba vai từ kênh mobile đều ghi immutable audit log.

---

## 5. Trường Hợp Đặc Biệt

- **Stale nghiêm trọng vào giờ chốt:** khi chi tiêu QC stale quá 8 giờ vào cuối ngày chạy campaign, banner đỏ hiển thị trên đầu mọi màn KPI kèm deep-link sang màn trạng thái nguồn; ROAS của nền tảng liên quan tự chìm xám "dữ liệu cũ" thay vì hiển thị như thường — BOD không thể bỏ qua mà vẫn không nhầm số.
- **Metric đang trong chu kỳ đổi định nghĩa (CHANGE_PENDING):** widget tiếp tục dùng định nghĩa ACTIVE hiện hành và hiển thị huy hiệu "có bản định nghĩa mới chờ CFO duyệt"; sau khi duyệt, số lịch sử không tự viết lại — app hiển thị theo đúng version hiệu lực tại thời điểm dữ liệu (BR-BOD-004.2).
- **Cờ cảnh báo K6–K12 từ quy trình TMKD:** danh sách đầy đủ các cờ cảnh báo vận hành chưa được khách hàng chốt `[KXN-20]` — màn mobile khởi tạo với 3 ngưỡng stale đã chốt (chi QC >8h, ví >2h, timesheet >24h) và bộ alert BOD theo REQ-BOD-006; các cờ K6–K12 bổ sung sau khi `[KXN-20]` chốt, không tự phát minh ngưỡng.
- **Nền tảng chưa cấp quyền API developer:** KPI ROAS/chi tiêu của nền tảng đó hiển thị nhãn "manual" kèm minh chứng kỳ; khi quyền được cấp và backfill hoàn tất, nhãn chuyển "api" tự động — chênh lệch manual vs api >±0,1% vào báo cáo đối soát.
- **Offline kéo dài (chuyến bay/roaming):** snapshot cache chỉ giữ tối đa cửa sổ dữ liệu cấu hình được (đề xuất 7 ngày) để giới hạn dữ liệu nhạy cảm trên thiết bị; quá hạn → cache tự xóa, app yêu cầu online để xem tiếp.
- **Khách die account tăng đột biến:** widget die account đổi màu mức cảnh báo nhưng không thay thế luồng alert chính — cảnh báo khẩn đi qua FEAT-MBI-DHUB-003 với acknowledge có trách nhiệm; màn KPI chỉ là điểm nhìn thụ động.
- **BOD dùng tablet/thiết bị màn lớn:** layout responsive cho tablet nhưng giới hạn chức năng không thay đổi — vẫn read-only rút gọn; workspace đầy đủ vẫn thuộc WEB.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity lõi có vòng đời là **Metric Definition** trong Metric Catalog — bảo đảm "một định nghĩa duy nhất" và lịch sử hiệu lực; mobile phải hiển thị đúng trạng thái này ở mọi widget tham chiếu (chỉ render số khi metric ACTIVE).

**Entity:** Metric Definition (định nghĩa KPI trong Metric Catalog)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đăng ký)──► [PENDING_APPROVAL] ──(CFO duyệt ≤2 ngày LV)──► [ACTIVE]
                                    │                                          │
                                    │ (CFO từ chối)                            │ (đề xuất định nghĩa mới)
                                    ▼                                          ▼
                               [REJECTED]                              [CHANGE_PENDING]
                                    │                                          │
                                    └─(sửa lại)──► [DRAFT]                     │ (CFO duyệt bản mới)
                                                                               ▼
                                                                        [ACTIVE] (version mới;
                                                                         bản cũ RETIRED có hiệu lực lùi)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit đăng ký | `PENDING_APPROVAL` | BOD_CEO, BOD_CFO_CTO | Đủ tên, công thức, nguồn, owner |
| `PENDING_APPROVAL` | Duyệt | `ACTIVE` | BOD_CFO_CTO (CFO) | ≤2 ngày làm việc; ghi version + effective_from |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | BOD_CFO_CTO | Lý do từ chối bắt buộc |
| `REJECTED` | Sửa và submit lại | `DRAFT` | Người đề xuất | Cập nhật theo lý do từ chối |
| `ACTIVE` | Đề xuất đổi định nghĩa | `CHANGE_PENDING` | BOD_CEO, BOD_CFO_CTO | Tạo version draft; bản ACTIVE giữ nguyên |
| `CHANGE_PENDING` | Duyệt bản mới | `ACTIVE` (version mới) | BOD_CFO_CTO | Version cũ chuyển `RETIRED` với effective_to; báo cáo lịch sử dùng đúng version theo thời điểm dữ liệu |

**Quy tắc:**
- Không có đường `DRAFT` → `ACTIVE` bỏ qua CFO; không xóa metric từng `ACTIVE` — chỉ retire, mọi báo cáo cũ luôn giải thích được.
- Trên mobile, widget chỉ render số khi metric `ACTIVE`; các trạng thái khác hiển thị nhãn trạng thái, không render số.
- Các thao tác chuyển trạng thái (submit/duyệt) chỉ thực hiện trên WEB — mobile hoàn toàn passive với state machine này.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity do SYS-CORE-BACKEND sở hữu; mobile tiêu thụ qua API rút gọn và cache mã hóa có kiểm soát. DDL đầy đủ tại technical spec CORE.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `metric_definition` | `code`, `name`, `formula`, `source`, `owner`, `state`, `version`, `effective_from/to` | 1-N → `metric_version_history` | Chỉ trạng thái ACTIVE lên widget mobile |
| `metric_version_history` | `metric_id`, `version`, `formula_json`, `approved_by`, `approved_at`, `effective_from` | FK → `metric_definition`, `users` | Lịch sử vĩnh viễn; dùng để hiển thị "định nghĩa đang áp" |
| `kpi_snapshot` | `metric_code`, `period`, `value`, `unit`, `source_label` (api/manual), `computed_at` | FK → `metric_definition` | Kết quả mobile đọc; không tính lại trên client |
| `data_source` | `code`, `type`, `state`, `last_valid_at`, `quality_test_status` | 1-N → `sync_event` | Nguồn fail test → widget stale/manual |
| `stale_threshold` | `scope` (chi_qc/ví/timesheet), `hours`, `severity` | — | Ngưỡng chốt 8h/2h/24h; cấu hình trung tâm, mobile đọc theo |
| `mobile_cache_manifest` | `device_id`, `user_id`, `snapshot_at`, `scope_hash`, `expiry` | FK → `users`, `device_registry` | Cache offline mã hóa, chịu remote wipe |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-BOD-004 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Màn KPI rút gọn đúng danh mục | BOD_CEO đăng nhập MFA; nguồn FRESH | Mở tab BI | Thấy đúng 5 nhóm KPI (ROAS, GM, SLA attainment, aging công nợ, die account), mỗi widget có "HH:MM + nguồn api" | [ ] |
| SC-002: Cảnh báo đỏ stale | Chi tiêu QC stale 9 giờ | Mở app | Banner đỏ nổi bật hiển thị ngay; widget liên quan xám nhãn "dữ liệu cũ"; deep-link sang trạng thái nguồn hoạt động | [ ] |
| SC-003: Hiển thị version định nghĩa | KPI GM vừa đổi định nghĩa do CFO duyệt | Chạm vào KPI GM | Thấy phiên bản mới hiệu lực, ngày duyệt, người duyệt; số tháng trước không bị viết lại | [ ] |
| SC-004: Metric chưa ACTIVE | Một widget tham chiếu metric đang PENDING_APPROVAL | Mở màn KPI | Widget hiển thị "metric chờ duyệt", không render số | [ ] |
| SC-005: Offline snapshot | App offline | Mở BI | Snapshot kèm nhãn "offline — dữ liệu lúc HH:MM"; không nhầm với dữ liệu tươi; audit queue flush khi có mạng | [ ] |
| SC-006: Read-only tuyệt đối | Vai bất kỳ trên mobile | Cố gắng gọi API ghi (publish/cấu hình/định nghĩa) | API từ chối mọi method ghi từ kênh mobile; không có nút tương ứng trên UI | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint mobile nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu Metric Catalog, kpi_snapshot, stale threshold | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (KPI rút gọn, version metric, freshness, quality test status) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp ingestion đa nền tảng, quality gate, cache/offline MDM | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI BI rút gọn (React Native) | `phase4-ux/mobile-internal/datahub-bi/bi-dashboard.md` |
| Bản counterpart: BI workspace đầy đủ + publish (WEB) | `phase2-features/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md` (FEAT-ERP-DHUB-002) |
| Bản counterpart: Metric Catalog + ingestion (CORE) | `phase2-features/core-backend/datahub-bi/` (FEAT tương ứng REQ-BOD-004) |
| Kênh nhận + acknowledge cảnh báo khẩn | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (FEAT-MBI-DHUB-003) |
