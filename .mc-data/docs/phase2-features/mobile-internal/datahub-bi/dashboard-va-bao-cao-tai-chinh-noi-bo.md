# Tính Năng: Dashboard & Báo Cáo Tài Chính Nội Bộ (Bản Rút Gọn Mobile)

> **Dựa trên:** REQ-FIN-015 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/datahub-bi/fin-dashboard.md`, `phase5-implementation/tasks/mobile-internal/datahub-bi/feat-mbi-dhub-004-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-DHUB-004 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-FIN-015 (Dashboard & báo cáo tài chính nội bộ) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (GĐ2) |
| Phụ thuộc | Dữ liệu đối soát, discrepancy, aging AR/AP từ phân hệ FIN (REQ-FIN-001–007); nền tảng Data Integration Hub (SYS-CORE-BACKEND); counterpart WEB FEAT-ERP-DHUB-004 (dashboard đầy đủ + thao tác khóa kỳ); FEAT-MBI-DHUB-003 (cảnh báo ≤5 phút qua push); REQ-BOD-011 (MDM + MFA TOTP) |
| Ghi chú Expert (A7) | Dept doc Finance có mục A7 (bảng đánh giá) nhưng chưa ghi điều chỉnh riêng cho REQ-FIN-015 — không có thay đổi phạm vi từ Expert Review |

REQ-FIN-015 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-MOBILE-INTERNAL** — dashboard tài chính rút gọn cho quản lý (FIN_L2/CFO) khi di động, theo đúng định nghĩa dept doc: "WEB là kênh xem chính; Mobile dashboard rút gọn". Mọi thao tác xử lý (duyệt chi, đối soát, xử lý discrepancy, khóa kỳ) diễn ra trên WEB/phân hệ FIN tương ứng; mobile là màn hình theo dõi sức khỏe dòng tiền và cảnh báo nhanh.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép FIN_L2/CFO (và FIN_L1 khi cần tra nhanh) theo dõi sức khỏe dòng tiền hằng ngày ngay trên điện thoại — số dư ví theo khách/nền tảng, ngày chi dự kiến, trạng thái đối soát, discrepancy tồn, aging AR/AP, hàng chờ duyệt quá SLA, hạn mức tuần nạp — mà không phải tổng hợp tay hay mở máy tính. Dashboard mobile là bản rút gọn read-only của dashboard FIN trên web, với freshness rõ ràng ("cập nhật lúc HH:MM") và cảnh báo sự kiện quan trọng qua kênh push ≤5 phút.

**Phạm vi:**
- Bao gồm:
  - Bộ widget rút gọn theo đúng nội dung REQ-FIN-015: số dư ví theo khách/nền tảng + ngày chi dự kiến; trạng thái đối soát; discrepancy tồn; aging AR/AP; hàng chờ duyệt quá SLA; hạn mức tuần nạp.
  - Chỉ báo freshness "cập nhật lúc HH:MM" trên mọi widget; **chi tiêu QC tươi ≤1 giờ**.
  - Widget dành riêng cho quản lý: tổng quan hạn mức tuần nạp và số dư khả dụng theo nhóm khách lớn — để CFO quyết định nhanh khi AM xin nạp khẩn.
  - Cảnh báo sự kiện quan trọng (ví dưới ngưỡng, discrepancy mới, duyệt quá SLA) hiển thị trên app và đẩy push qua FEAT-MBI-DHUB-003 (≤5 phút).
  - Điểm qua danh sách hàng chờ duyệt quá SLA trên mobile kèm deep-link sang đúng hồ sơ duyệt trên WEB để xử lý (duyệt chi thuộc phân hệ FIN — FEAT tương ứng REQ-FIN-008).
  - Cache offline read-only với nhãn "offline — dữ liệu lúc HH:MM"; audit mọi lần truy xuất.
- Không bao gồm:
  - Dashboard FIN đầy đủ, drill chi tiết, export báo cáo — thuộc SYS-BCERP-WEB; mobile không export, không cấu hình widget dùng chung.
  - Thao tác nghiệp vụ tài chính: duyệt chi/giải ngân, đối chỉnh discrepancy, khóa kỳ, tạo lệnh nạp — thuộc phân hệ FIN trên WEB (REQ-FIN-001–008); mobile chỉ xem + deep-link.
  - P&L/BI điều hành cho BOD — thuộc FEAT-MBI-DHUB-001/005; dashboard này phục vụ vận hành tài chính nội bộ.
  - Dữ liệu ví read-only cho khách — thuộc SYS-PORTAL-WEB (REQ-FIN-017, tenant isolation); dashboard này chỉ nội bộ, không có vai CUSTOMER.
  - Tính toán nguồn (ledger, đối trừ 3 số, aging) — thuộc SYS-CORE-BACKEND.

---

## 2. Luồng Người Dùng (User Stories)

Mobile FIN dashboard là màn "quản lý đọc nhanh dòng tiền — biết điểm nghẽn — chuyển WEB xử lý": các user story phản ánh đúng touchpoint rút gọn.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Mở app thấy tổng số dư ví khả dụng theo khách/nền tảng + ngày chi dự kiến của tuần này | Biết công ty có đủ tiền chi hôm nay/mai không ngay khi đi đường |
| 2 | FIN_L2 | Xem số discrepancy đối soát đang tồn và bao lâu rồi | Đẩy đội FIN_L1 xử lý trước khi chốt kỳ, không để tồn đọng âm thầm |
| 3 | BOD_CFO_CTO | Xem aging AR/AP rút gọn theo nhóm tuổi | Chuẩn bị nội dung đòi nợ/điều chỉnh lịch chi trước buổi họp |
| 4 | BOD_CFO_CTO | Thấy hàng chờ duyệt tài chính đã quá SLA với số ngày quá hạn | Nhắc người duyệt hoặc tự duyệt khẩn qua WEB trước khi chặn hoạt động OPS |
| 5 | FIN_L1 | Tra nhanh trạng thái đối soát của một khách cụ thể khi AM hỏi | Trả lời ngay tại chỗ thay vì "để tôi mở máy kiểm tra" |
| 6 | FIN_L2 | Nhận push ≤5 phút khi một ví khách rơi xuống ngưỡng không đủ chi ngày mai | Chủ động đặt lịch nạp thay vì bị động nhận ticket OPS |
| 7 | FIN_L2/BOD_CFO_CTO | Khi offline, xem snapshot "offline — dữ liệu lúc HH:MM" của các số dư | Vẫn trả lời được câu hỏi tiền trong lúc mất sóng mà không nhầm số cũ |
| 8 | FIN_L1 | Xem hạn mức tuần nạp còn lại của từng khách | Khi AM xin nạp, trả lời được ngay còn trong hạn mức hay cần xin CFO duyệt vượt |

---

## 3. Quy Tắc Nghiệp Vụ

Nguồn số do CORE tổng hợp (BR-FIN-307); mobile render đúng trạng thái và tôn trọng các rào cản read-only + bảo vệ dữ liệu nhạy cảm.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Tiền giữ hộ hiển thị tách bạch khỏi doanh thu** ở mọi widget: số dư ví khách là nợ phải trả, không bao giờ gộp vào chỉ số doanh thu dịch vụ | Widget gộp → chặn render; số liệu nguồn sai → report sự cố về CORE |
| BR-002 | Mọi widget có chỉ báo freshness "cập nhật lúc HH:MM"; **chi tiêu QC tươi ≤1 giờ**; dữ liệu nguồn `manual` hiển thị nhãn nguồn + disclaimer độ trễ | Widget thiếu freshness → không render số; nhãn manual bị tắt → lỗi hiển thị nghiêm trọng |
| BR-003 | Không nhập tay kết quả: mọi con số đến từ pipeline Data Integration Hub; mobile **read-only tuyệt đối** — không duyệt, không sửa, không export | Build có luồng ghi/export → chặn phát hành; API từ chối method ghi từ kênh mobile |
| BR-004 | Cảnh báo sự kiện quan trọng (ví dưới ngưỡng đủ chi, discrepancy mới vượt ngưỡng, duyệt quá SLA) đi qua kênh push ≤5 phút (FEAT-MBI-DHUB-003); widget trên app phản ánh trạng thái cảnh báo tương ứng | Sự kiện hợp lệ không có cảnh báo → đo tại telemetry, xử lý như thiếu sót kênh |
| BR-005 | "Hàng chờ duyệt quá SLA" tính theo SLA đã chốt từ phiên resolve DI-005; mỗi dòng hiển thị người duyệt hiện tại + số ngày quá hạn | Hiển thị sai người duyệt → lỗi dữ liệu, chặn dòng và log |
| BR-006 | Dữ liệu lương/PII không xuất hiện ở bất kỳ widget nào trên mobile; số dư/tổng hợp ở mức khách/nền tảng, không xuống mức cá nhân | API trả PII → chặn ở service layer + audit vi phạm |
| BR-007 | Hạn mức tuần nạp hiển thị theo cấu hình hạn mức hiện hành của từng khách; vượt hạn mức sinh cảnh báo và không cho hiển thị như "còn khả dụng" | Widget cộng dồn sai → chặn render, đối chiếu với lệnh nạp |
| BR-008 | Mỗi lần truy xuất dashboard tài chính trên mobile ghi audit log (user, thiết bị, thời điểm, phạm vi, channel="mobile"); dữ liệu ví khách là Mật — chỉ FIN + BOD xem | Offline → hàng đợi mã hóa flush khi có mạng; truy xuất không log → chặn phiên |
| BR-009 | Cache offline mã hóa (Keychain/Keystore), gắn nhãn thời điểm chụp, chịu remote wipe MDM; MFA TOTP bắt buộc; notification/lock-screen không hiển thị số dư cụ thể | Cache không mã hóa hay push lộ số → lỗi bảo mật P1 |
| BR-010 | Client Portal không truy cập được bất kỳ endpoint nào của dashboard này — biên tin cậy nội bộ theo REQ-FIN-017; vai CUSTOMER không tồn tại trên tính năng này | Request từ realm portal → từ chối ở RBAC; không có nhánh chia sẻ dữ liệu |

---

## 4. Phân Quyền

Enforcement ở service layer core API; bảng dưới liệt kê hành động chính trên touchpoint mobile cho ba vai trong phạm vi REQ-FIN-015 (18 vai registry).

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Xem số dư ví theo khách/nền tảng + ngày chi dự kiến | ✅ | ✅ | ✅ |
| Xem trạng thái đối soát + discrepancy tồn | ✅ | ✅ | ✅ |
| Xem aging AR/AP | ✅ | ✅ | ✅ |
| Xem hàng chờ duyệt quá SLA | ✅ (phần liên quan nghiệp vụ đối soát) | ✅ (toàn bộ, kèm người duyệt) | ✅ (toàn bộ) |
| Xem hạn mức tuần nạp theo khách | ✅ | ✅ | ✅ |
| Duyệt chi / xử lý discrepancy / khóa kỳ từ mobile | ❌ (đưa về WEB) | ❌ (đưa về WEB) | ❌ (đưa về WEB — duyệt chi trên WEB theo REQ-FIN-008) |
| Export báo cáo / cấu hình widget dùng chung | ❌ | ❌ | ❌ (chỉ trên WEB) |
| Xem số dư của mọi khách không thuộc scope | ❌ (theo phạm vi được gán) | ✅ | ✅ |
| Xem audit log chi tiết lượt truy xuất trên mobile | ❌ (cấm trên mobile theo BR-BOD-005.3) | ❌ | ❌ |

Nguyên tắc bổ sung: WEB là kênh xem chính và kênh thao tác; mobile phục vụ FIN_L2/CFO khi di động, FIN_L1 dùng để tra nhanh; mọi truy xuất từ kênh mobile ghi immutable audit log; SYS_ADMIN không xuất hiện trong bảng vì không có vai xem dữ liệu tài chính (chỉ vận hành trạng thái nguồn — xem FEAT-MBI-DHUB-001).

---

## 5. Trường Hợp Đặc Biệt

- **Ví khách sắp không đủ chi ngày mai:** widget "ngày chi dự kiến" đổi màu cảnh báo khi số dư khả dụng < nhu cầu chi dự kiến; đồng thời sinh alert qua FEAT-MBI-DHUB-003 với ngưỡng `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]` cho cảnh báo BOD; trên mobile FIN hiển thị sớm hơn (mức amber) để kịp đặt lịch nạp.
- **Discrepancy tồn kéo dài:** nếu một discrepancy mở quá SLA xử lý nội bộ, widget tồn hiển thị thêm nhãn thời gian và người phụ trách; mobile không cho xử lý — deep-link mở đúng ticket đối soát trên WEB.
- **Nguồn đối soát là phần mềm kế toán VAS:** theo DI-004 đã resolve, connector VAS là cấu hình kết nối ngoại vi vendor-agnostic tại MOD-SETTINGS-GW; connector lỗi → widget đối soát/trạng thái sổ hiển thị "manual + timestamp dữ liệu hợp lệ cuối", phần dữ liệu nguồn khác vẫn tươi.
- **Aging công nợ và mốc PAUSE non-payment:** quy trình vận hành có đề xuất 2 bậc 15/30 ngày chờ khách hàng xác nhận `[KXN-22]` — widget aging hiển thị theo nhóm tuổi cấu hình trung tâm; khi `[KXN-22]` chốt, mốc PAUSE được nối vào cảnh báo mà không phải đổi thiết kế widget.
- **Kỳ đang mở vs đã khóa:** các widget theo tháng gắn nhãn kỳ "tạm tính"/"đã chốt" do API cung cấp (state machine kỳ báo cáo — xem mục 6); mobile chỉ render, thao tác khóa kỳ chỉ trên WEB.
- **Cuối tuần/nghỉ lễ có nạp khẩn:** CFO xem trên mobile thấy hàng chờ duyệt + hạn mức tuần; việc duyệt khẩn vẫn thực hiện trên WEB theo REQ-FIN-008 (dual approval) — mobile không mở luồng duyệt để tránh suy yếu SoD.
- **Đa tiền tệ:** số dư ví khách nạp USD/EUR quy VND theo snapshot tỷ giá dùng chung (REQ-FIN-004); widget cho xem gốc ngoại tệ kèm tỷ giá snapshot, không dùng tỷ giá realtime riêng trên client.
- **Mất thiết bị của CFO:** remote wipe qua MDM + thu hồi thiết bị MFA ≤24h theo offboarding khẩn; cache mã hóa trên thiết bị mất bị vô hiệu hóa từ xa, phiên không dùng lại được.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chịu trạng thái mà mobile render trực tiếp là **kỳ báo cáo tài chính nội bộ (Reporting Period)** — quyết định các widget theo tháng hiển thị số "tạm tính" hay "đã chốt". Thao tác chuyển trạng thái chỉ trên WEB; mobile passive.

**Entity:** Reporting Period (kỳ tháng tài chính dùng cho dashboard & báo cáo nội bộ)

**Sơ đồ trạng thái:**
```
[OPEN] ──(đủ điều kiện: discrepancy tồn = 0, hàng chờ duyệt = 0)──► [LOCK_PENDING] ──(FIN_L2 khóa kỳ)──► [CLOSED]
   ▲                                                                      │
   │                (phát hiện sai sót — luồng reversal có reason code)    │
   └──────────────────────────── [CLOSED] ◄───────────────────────────────┘ (không mở lại — chỉ điều chỉnh reversal)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Kiểm tra điều kiện khóa | `LOCK_PENDING` | FIN_L2 | Checklist trước khóa: discrepancy tồn = 0, không có hàng chờ duyệt quá hạn |
| `LOCK_PENDING` | Khóa kỳ | `CLOSED` | FIN_L2 (trên WEB) | Xác nhận khóa; audit ai khóa lúc nào; widget kỳ đó gắn nhãn "đã chốt" |
| `LOCK_PENDING` | Hoàn tác kiểm tra | `OPEN` | FIN_L2 | Còn hạng mục chưa xong phát hiện khi soát |
| `CLOSED` | Điều chỉnh số | `CLOSED` (không đổi trạng thái) | FIN_L2 đề xuất + BOD duyệt | Chỉ qua luồng reversal có reason code; dashboard hiển thị dòng điều chỉnh riêng, không ghi đè lịch sử |

**Quy tắc:**
- Kỳ `CLOSED` không mở lại — mọi thay đổi là dòng reversal có dấu vết; so sánh giữa các kỳ luôn dùng số đã chốt.
- Trạng thái kỳ hiển thị trên mọi widget theo tháng: người xem trên mobile phải biết đang nhìn số tạm tính hay số chốt.
- Mọi chuyển trạng thái thực hiện trên WEB; mobile không có nút khóa/mở kỳ — đúng nguyên tắc touchpoint thao tác.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity do phân hệ FIN + CORE sở hữu; mobile tiêu thụ qua API rút gọn + cache mã hóa. DDL đầy đủ tại technical spec CORE.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `client_wallet_balance` | `client_id`, `platform_id`, `currency`, `balance`, `available`, `updated_at` | FK → `dim_client`, `dim_platform` | Nguồn sổ phụ ví CORE; hiển thị tách tiền giữ hộ |
| `recon_status` | `client_id`, `period`, `state`, `discrepancy_count`, `last_check_at` | FK → `dim_client` | Trạng thái đối soát 3 số (REQ-FIN-004) |
| `discrepancy` | `code`, `client_id`, `type`, `amount`, `state`, `owner`, `opened_at` | FK → `recon_status`, `users` | Widget "discrepancy tồn"; xử lý chỉ trên WEB |
| `ar_ap_aging` | `party_type` (AR/AP), `client_id`/`vendor_id`, `bucket` (0-30/31-60/...), `amount` | FK → `dim_client`, `dim_vendor` | Nhóm tuổi cấu hình trung tâm; nối mốc PAUSE khi `[KXN-22]` chốt |
| `approval_queue_item` | `request_id`, `type`, `current_approver`, `sla_due_at`, `overdue_days` | FK → `users` | Hàng chờ quá SLA theo DI-005; deep-link sang hồ sơ duyệt WEB |
| `topup_quota` | `client_id`, `week`, `quota_vnd`, `used_vnd` | FK → `dim_client` | Hạn mức tuần nạp; cấu hình theo policy hiện hành |
| `mobile_cache_manifest` | `device_id`, `user_id`, `snapshot_at`, `scope_hash`, `expiry` | FK → `users`, `device_registry` | Cache offline mã hóa, chịu remote wipe |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-FIN-015 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Bộ widget rút gọn đủ và có freshness | FIN_L2 đăng nhập MFA; nguồn FRESH | Mở tab tài chính | Thấy đủ: số dư ví + ngày chi dự kiến, đối soát, discrepancy tồn, aging AR/AP, hàng chờ quá SLA, hạn mức tuần; mỗi widget có "HH:MM" | [ ] |
| SC-002: Chi tiêu QC tươi ≤1 giờ | Chi tiêu QC vừa cập nhật từ GW 40 phút trước | Mở widget liên quan | Số hiển thị có timestamp ≤1 giờ; nguồn ghi "api" | [ ] |
| SC-003: Tiền giữ hộ tách bạch | Khách nạp ví 500 triệu | Xem widget số dư/doanh thu | 500 triệu nằm ở nhóm ví khách (nợ phải trả); không xuất hiện trong bất kỳ chỉ số doanh thu | [ ] |
| SC-004: Cảnh báo ví dưới ngưỡng ≤5 phút | Ví khách A rơi dưới ngưỡng đủ chi | Chờ 5 phút | Push đến app FIN_L2/CFO; widget ví khách A đổi mức cảnh báo; acknowledged qua FEAT-MBI-DHUB-003 | [ ] |
| SC-005: Hàng chờ quá SLA đúng người | Một hồ sơ duyệt chi quá SLA 2 ngày | Mở widget hàng chờ | Dòng hiển thị người duyệt hiện tại + số ngày quá hạn; deep-link mở đúng hồ sơ trên WEB | [ ] |
| SC-006: Read-only và offline | Mất mạng; cố gọi API ghi từ mobile | Mở app | Snapshot "offline — dữ liệu lúc HH:MM"; mọi API ghi từ kênh mobile bị từ chối; audit queue flush khi có mạng | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint mobile nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu ví, đối soát, aging, approval queue, quota | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (FIN dashboard rút gọn, freshness, cảnh báo) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ FIN ↔ GW; connector VAS vendor-agnostic (DI-004) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI FIN dashboard rút gọn (React Native) | `phase4-ux/mobile-internal/datahub-bi/fin-dashboard.md` |
| Bản counterpart: dashboard FIN đầy đủ + khóa kỳ (WEB) | `phase2-features/bcerp-web/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` (FEAT-ERP-DHUB-004) |
| Bản counterpart: pipeline dữ liệu tài chính (CORE) | `phase2-features/core-backend/datahub-bi/` (FEAT tương ứng REQ-FIN-015) |
| Kênh push cảnh báo khẩn | `phase2-features/mobile-internal/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (FEAT-MBI-DHUB-003) |
