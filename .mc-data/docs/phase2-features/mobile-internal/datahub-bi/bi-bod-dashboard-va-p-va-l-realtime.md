# Tính Năng: BI/BOD Dashboard & P&L Realtime — Góc Nhìn FIN (Bản Mobile)

> **Dựa trên:** REQ-FIN-016 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/datahub-bi/bi-bod-pnl.md`, `phase5-implementation/tasks/mobile-internal/datahub-bi/feat-mbi-dhub-005-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-DHUB-005 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-FIN-016 (BI/BOD dashboard & P&L realtime — phối hợp BOD); liên kết chéo REQ-BOD-003 — BOD oversight yêu cầu P&L realtime |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 3 (GĐ3 — star schema mở rộng + conformed dimensions + Metric Catalog full lifecycle) |
| Phụ thuộc | FEAT-MBI-DHUB-001 (nền P&L rút gọn dựng từ MVP — REQ-BOD-003); FEAT-MBI-DHUB-004 (dashboard FIN nội bộ GĐ2); star schema + conformed dimensions (Khách, Dự án, TKQC, Nền tảng) của SYS-CORE-BACKEND; Metric Catalog CFO duyệt; FEAT-MBI-DHUB-003 (alert rủi ro dòng tiền); REQ-BOD-011 (MDM + MFA TOTP) |
| Ghi chú Expert (A7) | Dept doc Finance có mục A7 (bảng đánh giá) nhưng chưa ghi điều chỉnh riêng cho REQ-FIN-016 — không có thay đổi phạm vi từ Expert Review |

REQ-FIN-016 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-MOBILE-INTERNAL**. REQ-FIN-016 là góc nhìn FIN của cùng thực thể P&L/BI mà REQ-BOD-003/004 mô tả từ góc nhìn BOD: FIN là chủ nguồn số liệu; BOD là bên tiêu thụ. Trên mobile, tính năng mang **dashboard BOD rút gọn cho CFO + giám sát rủi ro dòng tiền của FIN** — dashboard đầy đủ và thao tác quản trị metric thuộc counterpart WEB (FEAT-ERP-DHUB-005) và CORE.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Ở Giai đoạn 3, khi P&L realtime chạy đầy đủ trên star schema với conformed dimensions, cho phép FIN_L2/CFO theo dõi ngay trên điện thoại chất lượng số liệu mà mình cung cấp cho BOD: P&L theo dự án/khách với nhãn phiên bản định nghĩa, trạng thái fresh/manual của từng nguồn, và các cảnh báo rủi ro dòng tiền — chấm dứt triệt để "mỗi người một bảng tính" cả trên kênh di động. CFO anywhere-là-CFO: nhìn số BOD đang nhìn, biết đúng độ tin cậy của nó, nhận cảnh báo trước khi BOD kịp gọi hỏi.

**Phạm vi:**
- Bao gồm:
  - Màn P&L/BI rút gọn theo conformed dimensions (Khách, Dự án, TKQC, Nền tảng): P&L theo dự án/khách, margin, với freshness ≤15 phút và nhãn nguồn api/manual trên từng widget.
  - Hiển thị phiên bản Metric Catalog đang áp cho từng metric tài chính (P&L, GM, thành phần chi) kèm trạng thái hiệu lực — để CFO xác nhận số BOD nhìn đúng định nghĩa đã duyệt.
  - Tiền giữ hộ hiển thị tách bạch khỏi doanh thu ở mọi góc nhìn; không nhập tay kết quả BI từ mobile (thực chất: không nhập tay từ bất kỳ kênh nào).
  - **Giám sát rủi ro dòng tiền cho FIN**: tổng hợp trạng thái cảnh báo ví (dưới ngưỡng đủ chi, vượt hạn mức tuần nạp) và các nguồn stale — với push khẩn đi qua FEAT-MBI-DHUB-003.
  - Điểm qua danh sách nguồn dữ liệu và kết quả quality test của các nguồn tài chính; deep-link sang WEB để xử lý.
  - Cache offline read-only với nhãn thời điểm chụp; audit mọi truy xuất.
- Không bao gồm:
  - Dashboard BOD đầy đủ, drill đa tầng tổng công ty → phòng → dự án, publish báo cáo — thuộc SYS-BCERP-WEB (FEAT-ERP-DHUB-005); mobile không publish, không cấu hình.
  - Duyệt đăng ký/đổi định nghĩa metric — thao tác CFO chỉ trên WEB; mobile chỉ xem trạng thái + nhận thông báo "có metric chờ CFO duyệt".
  - Tính toán, nạp star schema, conformed dimensions, quality test — thuộc SYS-CORE-BACKEND.
  - P&L rút gọn cơ bản dựng từ MVP — thuộc FEAT-MBI-DHUB-001; tính năng này là mở rộng GĐ3 theo đúng phân giai đoạn của REQ-FIN-016.
  - Dữ liệu cho Portal khách — thuộc REQ-FIN-017 (SYS-PORTAL-WEB, tenant isolation); không vai CUSTOMER trên tính năng này.

---

## 2. Luồng Người Dùng (User Stories)

Mobile ở GĐ3 là màn "CFO giám sát chất lượng số + rủi ro dòng tiền": các user story phản ánh vai trò FIN là chủ nguồn số liệu, không phải chỉ người đọc.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO | Mở app thấy P&L theo dự án/khách đúng như màn BOD sẽ nhìn, kèm freshness ≤15 phút | Trả lời CEO tức thì khi được hỏi số qua điện thoại, không cần mở laptop |
| 2 | BOD_CFO_CTO | Xem phiên bản Metric Catalog đang áp cho P&L/GM từng kỳ | Chắc chắn không có ai dùng định nghĩa chưa duyệt khi nói chuyện số liệu |
| 3 | BOD_CFO_CTO | Nhận thông báo trên app khi có metric đang chờ mình duyệt (định nghĩa mới/đổi định nghĩa) | Không để metric mới treo ngoài luồng chỉ vì mình vắng văn phòng |
| 4 | FIN_L2 | Xem tổng hợp trạng thái các nguồn tài chính (ví, sổ kế toán VAS, statement) — FRESH/STALE/DEGRADED | Báo trước cho BOD "số này manual" trước khi họ tự phát hiện |
| 5 | FIN_L2 | Nhận push ≤5 phút khi ví khách rơi dưới ngưỡng đủ chi hoặc vượt hạn mức tuần nạp | Xử lý nạp/điều chỉnh trước khi campaign khách bị ảnh hưởng |
| 6 | FIN_L1 | Xem nhanh P&L theo khách mình phụ trách đối soát | Nhận diện sớm dự án có margin bất thường để rà soát chi phí gắn mã |
| 7 | FIN_L2/BOD_CFO_CTO | Khi offline, xem snapshot kèm nhãn "offline — dữ liệu lúc HH:MM" | Vẫn có số tham chiếu khi di chuyển mà không nhầm với số tươi |
| 8 | BOD_CFO_CTO | Deep-link từ một widget sang màn BI workspace đầy đủ trên WEB | Kết thúc việc đọc nhanh và đào sâu ngay đúng ngữ cảnh lọc |

---

## 3. Quy Tắc Nghiệp Vụ

Số liệu và trạng thái do CORE enforce (BR-FIN-307, BR-BOD-003/004); mobile render đúng, không phá rào cản read-only, và bảo vệ dữ liệu nhạy cảm trên thiết bị.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Tiền giữ hộ hiển thị tách bạch khỏi doanh thu** trên mọi widget, mọi chiều tổng hợp — nguyên tắc bất di bất dịch của P&L (BR-BOD-003.1/BR-FIN-307) | Widget gộp tiền giữ hộ vào doanh thu → chặn render + report sự cố |
| BR-002 | P&L tính từ star schema theo Metric Catalog; **không nhập tay kết quả BI** trên bất kỳ kênh nào, mobile chỉ đọc; app không tự tính lại số | API nhận giá trị ghi từ kênh mobile → từ chối; build có luồng nhập → chặn phát hành |
| BR-003 | **Đổi định nghĩa metric phải CFO duyệt + có lịch sử hiệu lực**; widget hiển thị số theo đúng version hiệu lực tại thời điểm dữ liệu, kèm nhãn version | App hiển thị số trộn version → chặn render; metric chờ duyệt không lên số mới |
| BR-004 | Freshness ≤15 phút; mọi widget có "cập nhật lúc HH:MM + nguồn api/manual"; nguồn degraded gắn nhãn "manual" kèm timestamp hợp lệ cuối, **không nội suy số ẩn** | Widget thiếu freshness/nhãn → không render số; nội suy trên client → lỗi nghiêm trọng |
| BR-005 | Giờ timesheet chưa duyệt không vào P&L; chi không gắn mã dự án nằm ở nhóm overhead tách riêng, không được "ẩn" vào chi trực tiếp | Phân tách sai → chặn render, đối chiếu với nguồn timesheet |
| BR-006 | Cảnh báo rủi ro dòng tiền (ví dưới ngưỡng `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]`, vượt hạn mức tuần nạp) đẩy qua kênh push ≤5 phút của FEAT-MBI-DHUB-003; widget phản ánh trạng thái tương ứng | Sự kiện không có push → thiếu sót kênh delivery, đo tại telemetry |
| BR-007 | Giá trị T3/T4 và PII chỉ tổng hợp ở mức cho phép; SYS_ADMIN không thấy giá trị; drill không xuống mức cá nhân; lock-screen/notification không hiển thị số | API trả mức không phép → chặn ở service layer + audit vi phạm |
| BR-008 | Mọi truy xuất P&L/BI trên mobile ghi audit log (user, thiết bị, thời điểm, phạm vi, channel="mobile"); hành vi truy xuất của CFO cũng bị log (meta-log) | Offline → hàng đợi mã hóa flush bắt buộc khi có mạng |
| BR-009 | Cache offline mã hóa (Keychain/Keystore), gắn nhãn thời điểm chụp, chịu remote wipe MDM; MFA TOTP bắt buộc mọi phiên | Thiếu mã hóa/MFA → chặn phiên, coi như sự cố an toàn dữ liệu |
| BR-010 | Data Integration Hub gom dữ liệu từ các module nội bộ + GW vào star schema; nguồn chưa qua quality test không lên số trên bất kỳ kênh nào; portal khách không truy cập được endpoint nào của tính năng này | Nguồn fail test vẫn render → API chặn; request từ realm portal → từ chối RBAC |

---

## 4. Phân Quyền

Enforcement ở service layer core API; bảng dưới liệt kê hành động chính trên touchpoint mobile cho ba vai trong phạm vi REQ-FIN-016 (18 vai registry).

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Xem P&L theo dự án/khách (rút gọn) + freshness | ✅ (khách/phạm vi phụ trách) | ✅ | ✅ |
| Xem phiên bản Metric Catalog hiệu lực + trạng thái | ✅ (metadata) | ✅ | ✅ |
| Xem trạng thái nguồn tài chính + quality test | ✅ | ✅ | ✅ |
| Nhận push rủi ro dòng tiền (ví dưới ngưỡng, vượt hạn mức) | ❌ (chỉ FIN_L2/CFO — ngưỡng BOD) | ✅ | ✅ |
| Nhận thông báo metric chờ CFO duyệt | ❌ | ❌ | ✅ (thao tác duyệt trên WEB) |
| Đăng ký/duyệt/đổi định nghĩa metric từ mobile | ❌ | ❌ | ❌ (chỉ trên WEB — yêu cầu ký duyệt có audit đầy đủ) |
| Export báo cáo / publish / cấu hình workspace | ❌ | ❌ | ❌ (chỉ trên WEB) |
| Xem giá trị T3/T4 | ❌ | ❌ | ✅ |
| Xem audit log chi tiết trên mobile | ❌ (cấm theo BR-BOD-005.3) | ❌ | ❌ |

Nguyên tắc bổ sung: CFO nhìn được mọi thứ FIN nhìn và thêm tầng T3/T4 theo vai; FIN_L1 giới hạn theo phạm vi đối soát được gán; mọi truy xuất từ kênh mobile ghi immutable audit log.

---

## 5. Trường Hợp Đặc Biệt

- **BOD hỏi số ngay trên mobile khi nguồn đang degraded:** CFO mở app thấy chính widget đó gắn "manual — dữ liệu hợp lệ cuối HH:MM" và trả lời được "số này theo nguồn tay đến 14:30, phần api đã cập nhật" — đúng BR-BOD-003.4, không có kịch bản nào cho CFO một con số không nhãn.
- **Đổi định nghĩa GM giữa quý:** phiên bản mới chờ CFO duyệt hiển thị huy hiệu "CHANGE_PENDING" trên app; khi CFO duyệt (trên WEB), widget chuyển sang version mới với effective_from, số lịch sử không viết lại — báo cáo cũ vẫn tái lập được theo version hiệu lực tại thời điểm dữ liệu.
- **Connector VAS lỗi kéo dài (DI-004):** connector kế toán là cấu hình ngoại vi vendor-agnostic tại MOD-SETTINGS-GW; khi lỗi, widget P&L thành phần chi kế toán gắn "manual + timestamp hợp lệ cuối", FIN_L2 xem trạng thái nguồn để ước lượng thời gian backfill; chênh lệch manual vs api >±0,1% phải vào báo cáo đối soát.
- **Ví khách chạm ngưỡng cảnh báo trong lúc CFO họp:** push ≤5 phút qua FEAT-MBI-DHUB-003 đến cả FIN_L2 và CFO; acknowledge có reason có thể thực hiện ngay trên mobile; hành động nạp/điều chỉnh vẫn qua luồng lệnh trên WEB (REQ-FIN-001) — mobile không tạo lệnh tiền.
- **Kỳ đã khóa vs tạm tính:** widget theo tháng gắn nhãn kỳ (OPEN/LOCK_PENDING/CLOSED — xem FEAT-MBI-DHUB-004 mục 6); so sánh P&L giữa các kỳ trên mobile luôn dùng số đã chốt, số tháng mở ghi rõ "tạm tính".
- **Chi không gắn mã dự án đột tăng:** widget nhóm overhead hiển thị cảnh báo khi tỷ lệ chi không phân loại vượt ngưỡng cấu hình; FIN_L1 tra từ mobile thấy ngay và đôn đốc phân loại + nhập lý do ở hệ thống ghi nhận — không cho phép "gán tạm" cho đẹp số.
- **Đa tiền tệ và snapshot tỷ giá:** P&L khách nạp ngoại tệ quy VND theo snapshot tỷ giá dùng chung (REQ-FIN-004); mobile cho xem gốc ngoại tệ kèm tỷ giá snapshot đã dùng, không dùng tỷ giá realtime riêng trên client.
- **Dữ liệu BOD cùng nguồn, hai góc nhìn:** số trên màn này khớp 1:1 với màn BOD (FEAT-MBI-DHUB-001/002) vì cùng đọc `kpi_snapshot`/`pnl_fact` từ CORE; nếu phát hiện lệch (do cache offline) — app hiển thị thời điểm chụp từng nguồn, không tự "hiệu chỉnh cho khớp".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity lõi có vòng đời là **Metric Definition — nhóm metric tài chính** (P&L, GM, thành phần chi) trong Metric Catalog; mobile chỉ render số khi metric ACTIVE và luôn hiển thị version hiệu lực. Thao tác chuyển trạng thái chỉ trên WEB.

**Entity:** Metric Definition — nhóm metric tài chính (P&L, GM, các thành phần chi)

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
- Không có đường `DRAFT` → `ACTIVE` bỏ qua CFO; metric từng `ACTIVE` không xóa — chỉ retire với effective_to, mọi báo cáo cũ tái lập được.
- Trên mobile, widget chỉ render số khi metric `ACTIVE`; `PENDING_APPROVAL`/`CHANGE_PENDING` hiển thị huy hiệu trạng thái; `RETIRED` hiển thị "định nghĩa đã nghỉ hưu" kèm ngày.
- Thông báo "có metric chờ CFO duyệt" đẩy lên app của BOD_CFO_CTO để không metric nào treo ngoài luồng khi CFO di chuyển; hành động duyệt vẫn trên WEB.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity do CORE sở hữu; mobile tiêu thụ qua API rút gọn + cache mã hóa. DDL đầy đủ tại technical spec CORE.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `pnl_fact` | `period_month`, `project_id`, `client_id`, `platform_id`, `revenue_service`, `cost_labor`, `cost_outsource`, `cost_tools`, `metric_version`, `computed_at` | FK → `dim_*` | GĐ3: đủ conformed dimensions; GĐ2 chỉ aggregates |
| `dim_client` / `dim_project` / `dim_platform` | `id`, `code`, `name`, `tier`, `status` | — | Conformed dimensions dùng chung mọi marts |
| `metric_definition` | `code`, `formula`, `state`, `version`, `effective_from/to`, `approved_by` | 1-N → `metric_version_history` | Nhóm metric tài chính; chỉ ACTIVE lên widget |
| `metric_version_history` | `metric_id`, `version`, `formula_json`, `approved_by`, `approved_at` | FK → `metric_definition`, `users` | Lịch sử vĩnh viễn; tái lập báo cáo theo thời điểm |
| `kpi_snapshot` | `metric_code`, `period`, `value`, `source_label`, `computed_at` | FK → `metric_definition` | Nguồn đọc chung cho màn FIN và màn BOD — khớp 1:1 |
| `data_source` | `code`, `type`, `state`, `last_valid_at`, `quality_test_status` | 1-N → `sync_event` | Widget giám sát nguồn của FIN_L2 |
| `mobile_cache_manifest` | `device_id`, `user_id`, `snapshot_at`, `scope_hash`, `expiry` | FK → `users`, `device_registry` | Cache offline mã hóa, chịu remote wipe |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-FIN-016 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: P&L GĐ3 theo conformed dimensions | Nguồn FRESH; CFO đăng nhập MFA | Mở màn P&L theo dự án/khách | Đủ 4 chiều Khách/Dự án/TKQC/Nền tảng ở mức rút gọn; freshness "HH:MM + nguồn api"; số khớp 1:1 với màn BOD | [ ] |
| SC-002: Tiền giữ hộ tách bạch | Khách nạp ví 300 triệu | Xem mọi widget P&L | 300 triệu nằm nhóm nợ phải trả; doanh thu dịch vụ không đổi | [ ] |
| SC-003: Version metric hiển thị đúng | GM vừa chuyển sang version mới do CFO duyệt | Xem widget GM | Widget hiển thị version mới + effective_from; số kỳ trước tính theo version cũ không bị viết lại | [ ] |
| SC-004: Nhận thông báo metric chờ duyệt | Một định nghĩa mới submit | CFO mở app | Thông báo "metric chờ duyệt" hiển thị; nút duyệt không tồn tại trên mobile, deep-link đưa về WEB | [ ] |
| SC-005: Giám sát nguồn tài chính | Connector VAS lỗi | FIN_L2 mở widget trạng thái nguồn | Nguồn VAS hiển thị DEGRADED + "manual — hợp lệ cuối HH:MM"; widget phụ thuộc không có số nội suy | [ ] |
| SC-006: Push rủi ro dòng tiền ≤5 phút | Ví khách rơi dưới ngưỡng đủ chi | Chờ 5 phút | Push đến app FIN_L2 + CFO; acknowledge + reason thực hiện được trên mobile; không tạo được lệnh tiền từ mobile | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint mobile nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu star schema GĐ3, conformed dimensions, metric catalog | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (P&L GĐ3 rút gọn, version metric, trạng thái nguồn, push đăng ký) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ FIN ↔ GW; degraded mode & backfill; snapshot tỷ giá | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI BI/BOD P&L rút gọn (React Native) | `phase4-ux/mobile-internal/datahub-bi/bi-bod-pnl.md` |
| Bản counterpart: BI workspace + P&L realtime đầy đủ (WEB) | `phase2-features/bcerp-web/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` (FEAT-ERP-DHUB-005) |
| Bản counterpart: star schema + metric catalog (CORE) | `phase2-features/core-backend/datahub-bi/` (FEAT tương ứng REQ-FIN-016) |
| Nền P&L rút gọn từ MVP | `phase2-features/mobile-internal/datahub-bi/p-va-l-toan-cong-ty-realtime.md` (FEAT-MBI-DHUB-001) |
| Kênh push rủi ro dòng tiền | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (FEAT-MBI-DHUB-003) |
