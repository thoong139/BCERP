# Tính Năng: Dashboard & báo cáo tài chính nội bộ

> **Dựa trên:** REQ-FIN-015 trong `phase1-business/departments/finance/finance.md` (Phần A — Mục REQ-FIN-015; Phần B — BR-FIN-307)
> **Phân hệ:** Data Integration Hub & Analytics — BI/BOD Dashboard (SYS-CORE-BACKEND)
> **Module:** Data Integration Hub & Analytics — BI/BOD Dashboard (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/datahub-bi/*.md`, `phase5-implementation/tasks/core-backend/datahub-bi/feat-core-dhub-004-impl.md`

> **Hướng dẫn ID:** FEAT-CORE-DHUB-004 được tạo từ REQ-FIN-015 theo quy tắc chung trong req-registry (SYS=CORE-BACKEND, MOD=DATAHUB-BI). REQ này fan-out trên 3 systems — file này là bản riêng cho SYS-CORE-BACKEND (tổng hợp dữ liệu dashboard + enforcement); counterparts: SYS-BCERP-WEB (kênh xem chính), SYS-MOBILE-INTERNAL (dashboard rút gọn cho quản lý).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-DHUB-004 |
| Module | MOD-DATAHUB-BI (SYS-CORE-BACKEND) |
| Yêu cầu nghiệp vụ | REQ-FIN-015 — Dashboard & báo cáo tài chính nội bộ (MEDIUM · GĐ2/Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (Phase2 — dashboard FIN nội bộ; P&L/BI GĐ3 tách riêng theo FEAT-CORE-DHUB-005) |
| Phụ thuộc | Sổ phụ ví & lệnh (REQ-FIN-001/002), cảnh báo số dư (REQ-FIN-002), đối trừ 3 số + snapshot tỷ giá + khóa kỳ (REQ-FIN-004), AR/AP aging (REQ-FIN-007), hàng chờ duyệt chi SLA (REQ-FIN-008), hạn mức tuần nạp (REQ-FIN-001), connector kế toán VAS vendor-agnostic (REQ-FIN-013 — cấu hình MOD-SETTINGS-GW theo DI-004) |
| Ghi chú Expert (A7) | Dept doc `finance.md` có Mục A7 nhưng chưa ghi điều chỉnh đã chốt (chờ finance-expert review) — spec hiện hành theo Phần A/B; khi A7 có điều chỉnh sẽ cập nhật dòng này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép FIN_L1/FIN_L2 theo dõi sức khỏe dòng tiền hằng ngày trên core backend mà không phải tổng hợp tay từ nhiều nguồn: số dư ví theo khách/nền tảng kèm ngày chi dự kiến, trạng thái đối soát, discrepancy tồn, aging AR/AP, hàng chờ duyệt quá SLA và hạn mức tuần nạp — tất cả tổng hợp tự động bởi Data Integration Hub với chỉ báo freshness tường minh. Đây là lớp dữ liệu "nguồn số FIN" nằm trước dashboard BOD (FEAT-CORE-DHUB-005) — số FIN chuẩn thì dashboard điều hành mới chuẩn.

**Phạm vi:**
- Bao gồm: Data Integration Hub gom dữ liệu từ modules tài chính (ledger, đối soát, AR/AP, duyệt chi) + GW; tổng hợp snapshot dashboard theo chu kỳ (chi tiêu QC tươi ≤1h; cảnh báo ≤5 phút); API headless phục vụ dashboard FIN; chỉ báo "cập nhật lúc HH:MM + nguồn api/manual"; dữ liệu lương/PII chỉ aggregate khi được phép; audit mọi truy xuất (kể cả BOD_CFO_CTO); xuất báo cáo có log; degraded mode gắn nhãn khi thiếu nguồn; lý do duyệt/SoD thể hiện qua số "hàng chờ duyệt quá SLA".
- Không bao gồm: dashboard P&L/BI cho BOD (FEAT-CORE-DHUB-005), alert center và delivery push (FEAT-CORE-DHUB-003 — tính năng này phát sự kiện ngưỡng), nghiệp vụ tạo/duyệt lệnh và đối trừ (MOD-ARAP-PAYMENT sở hữu), UI dashboard (counterpart WEB/MOBILE), bất kỳ dữ liệu nào cho Portal khách (REQ-FIN-017 — biên tin cậy nội bộ).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Gọi API xem số dư ví theo khách/nền tảng kèm ngày chi dự kiến | Chủ động nhắc nạp trước khi TKQC khách cạn tiền, không tổng hợp tay từ sổ phụ |
| 2 | FIN_L1 | Xem trạng thái đối soát và discrepancy đang tồn | Biết ngay giao dịch nào lệch cần xử lý trong ca làm việc |
| 3 | FIN_L2 | Xem aging AR/AP theo bucket và hàng chờ duyệt đã quá SLA | Ưu tiên xử lý công nợ và duyệt chi trễ, giữ dòng tiền không nghẽn ở bàn duyệt |
| 4 | FIN_L2 | Xem hạn mức tuần nạp đã dùng của từng cấp buyer | Kiểm soát rủi ro chi vượt hạn mức trước khi ký duyệt lệnh mới |
| 5 | BOD_CFO_CTO | Xem dashboard tài chính tổng hợp với freshness "cập nhật lúc HH:MM" | Nắm dòng tiền cả công ty trong phiên họp mà không nhờ ai chạy số |
| 6 | SYS_ADMIN | Theo dõi trạng thái pipeline nạp dữ liệu dashboard (job nào stale/thiếu nguồn) | Sửa nguồn hỏng sớm để FIN không làm việc trên số cũ |
| 7 | Hệ thống (service CORE) | Tự đánh giá ngưỡng (discrepancy tồn quá hạn, duyệt quá SLA, ví sát ngưỡng) và phát sự kiện cho alert center | Chuyển từ "người nhìn ra vấn đề" sang "hệ thống tự hét" |

**Đặc thù touchpoint SYS-CORE-BACKEND:** mọi quy tắc (tách tiền giữ hộ, nhãn manual, mask PII/lương, audit truy xuất) enforce ở service layer — WEB là kênh xem chính (responsive browser UI), MOBILE chỉ bản rút gọn cho quản lý; Portal khách tuyệt đối không có API truy cập các dashboard nội bộ này.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, toàn bộ enforce ở service layer của CORE.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-FIN-307 | Nội dung dashboard theo chuẩn: số dư ví theo khách/nền tảng + ngày chi dự kiến; trạng thái đối soát; discrepancy tồn; aging AR/AP; hàng chờ duyệt quá SLA; hạn mức tuần nạp — WEB kênh xem chính, MOBILE rút gọn cho quản lý | Thiếu khối dữ liệu nào trong danh sách, dashboard không được phát hành cho FIN; API trả đủ bộ khối chuẩn |
| BR-FIN-307.1 | Tiền giữ hộ hiển thị tách bạch khỏi doanh thu ở mọi dashboard (nối BR-FIN-101 — bất di bất dịch) | Mọi view/endpoint trả số dư kèm cờ liability; gộp tiền giữ hộ vào doanh thu bị chặn ở tầng query |
| BR-FIN-307.2 | Freshness indicator "cập nhật lúc HH:MM" ở dashboard và từng widget; chi tiêu QC tươi ≤1h; cảnh báo ≤5 phút | Dữ liệu quá SLA freshness bị đánh dấu stale kèm timestamp hợp lệ cuối; không hiển thị số cũ như số mới |
| BR-FIN-307.3 | Dữ liệu nguồn "manual" (nhập tay, connector lỗi) — dashboard hiển thị nhãn nguồn + disclaimer độ trễ; minh chứng lưu kèm từng kỳ (DI-007: chưa có quyền API developer 7 nền tảng) | Số manual không nhãn không được lên dashboard; service gắn cờ nguồn bắt buộc |
| BR-FIN-307.4 | Portal khách không xem các dashboard này — biên tin cậy nội bộ; dữ liệu khách chỉ ra Portal qua view tổng hợp đã lọc tenant theo REQ-FIN-017 | Endpoint dashboard nội bộ không đăng ký cho realm portal; vi phạm tenant isolation bị chặn 2 lớp (RLS DB + filter API) |
| BR-DHUB-401 | Data Integration Hub gom dữ liệu từ modules + GW; nguồn thiếu (kể cả connector kế toán VAS theo DI-004 — vendor-agnostic, cấu hình tại MOD-SETTINGS-GW) → degraded mode: khối dữ liệu liên quan hiển thị trạng thái thiếu nguồn, khối còn lại hoạt động bình thường | Không được chặn cả dashboard vì một nguồn lỗi; nguồn missing liệt kê tường minh trong metadata |
| BR-DHUB-402 | Dữ liệu lương/PII chỉ aggregate khi được phép: dashboard FIN không hiển thị chi tiết lương cá nhân; cost rate nhân sự (T3/T4) chỉ tổng hợp; SYS_ADMIN vận hành pipeline không thấy giá trị nghiệp vụ; mọi truy xuất FIN/BOD ghi meta-log | Truy vấn chi tiết PII bị mask/từ chối ở service; lần truy cập log vào `pnl_query_audit` (nối REQ-BOD-005) |
| BR-DHUB-403 | Ngưỡng phát sự kiện: discrepancy tồn quá dung sai đối soát (theo chính sách DI-001 đã chốt); duyệt chi quá SLA; ví xuống sát ngưỡng theo ngày chi dự kiến — phát sự kiện cho alert center (FEAT-CORE-DHUB-003) | Sự kiện ngưỡng phải phát đủ — không được có ngưỡng "chỉ nhấp nháy trên dashboard" mà không đi vào alert |
| BR-DHUB-404 | Aging AR/AP dùng bucket chuẩn theo REQ-FIN-007; mốc xử lý nợ quá hạn tham chiếu đề xuất "15 ngày → PAUSE" `[KXN-22 — chưa có trong nguồn v2.3, chờ khách hàng xác nhận]` — cấu hình tham số, không hardcode | Bucket sai chuẩn bị quality test bắt; đổi mốc PAUSE phải qua cấu hình có audit |
| BR-DHUB-405 | Số liệu dashboard nhất quán với sổ nguồn tại thời điểm truy vấn; khóa kỳ (REQ-FIN-004) làm đóng băng snapshot kỳ đã chốt — dashboard không hiển thị số kỳ chốt "trôi nổi" theo thời gian | Truy vấn kỳ đã khóa trả đúng snapshot chốt; thay đổi sau chốt bị chặn ở tầng dữ liệu (append-only + reversal có reason) |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Xem số dư ví theo khách/nền tảng + ngày chi dự kiến | ✅ | ✅ | ✅ |
| Xem trạng thái đối soát + discrepancy tồn | ✅ | ✅ | ✅ |
| Xem aging AR/AP + hàng chờ duyệt quá SLA | ✅ | ✅ | ✅ |
| Xuất báo cáo tài chính nội bộ | ✅ (phạm vi ca/mình phụ trách) | ✅ (phạm vi phòng) | ✅ (toàn công ty, bị meta-log) |
| Xem chi tiết chứng từ nguồn (drill về lệnh/sổ phụ) | ✅ (theo quyền MOD-ARAP-PAYMENT) | ✅ | ✅ |
| Cấu hình widget/ngưỡng hiển thị | ❌ | ✅ (đề xuất) | ✅ (duyệt) |
| Sửa dữ liệu tài chính ngay trên dashboard | ❌ | ❌ | ❌ (luôn về phân hệ nguồn — ledger append-only) |
| Vận hành pipeline/chạy lại job tổng hợp | ❌ | ❌ | ❌ (SYS_ADMIN thực thi sau duyệt) |

> Ghi chú: SYS_ADMIN và CUSTOMER không xuất hiện trong ma trận vì không có quyền xem giá trị nghiệp vụ — SYS_ADMIN chỉ thấy trạng thái pipeline (không thấy số), Portal khách bị chặn hoàn toàn theo BR-FIN-307.4.

---

## 5. Trường Hợp Đặc Biệt

- Connector GW lỗi hoặc chưa có quyền API (DI-007): khối "chi tiêu QC" gắn nhãn manual + disclaimer độ trễ; FIN đối chiếu bằng statement import tay có minh chứng lưu kèm kỳ; khi được cấp quyền, backfill tự động và chênh lệch >±0,1% đưa vào báo cáo đối soát.
- Connector kế toán VAS (DI-004): vendor-agnostic — connection profile + field mapping cấu hình tại MOD-SETTINGS-GW; VAS chỉ hỗ trợ import file thì xuất file chuẩn schema + log lượt xuất; fail → hàng chờ retry + alert, không ghi sổ tay đè luồng chuẩn.
- Khách có nhiều ví/nhiều TKQC cùng nền tảng: dashboard tổng theo khách nhưng giữ drill về từng ví — không bù trừ chéo giữa các ví (BR-FIN-101: không gộp chung, không bù trừ chéo).
- Kỳ đã khóa (REQ-FIN-004): mọi widget liên quan kỳ chốt hiển thị snapshot khóa; điều chỉnh sau chốt chỉ qua reversal có reason code và xuất hiện ở kỳ hiện hành, không đổi số quá khứ.
- Hàng chờ duyệt có người duyệt nghỉ dài ngày: khối "quá SLA" làm nổi bật bản ghi trễ kèm delegate (nếu có); dữ liệu đưa vào cảnh báo để không nghẽn dòng tiền vì vắng người (nối nguyên tắc delegate REQ-BOD-002).
- Mốc PAUSE nợ quá hạn 15 ngày chưa được khách hàng xác nhận `[KXN-22]`: dashboard hiển thị aging theo bucket chuẩn, cảnh báo PAUSE chỉ bật khi cấu hình được phê duyệt — không tự PAUSE theo số chưa chốt.
- BOD_CFO_CTO xuất báo cáo phục vụ họp ban điều hành: xuất có log (meta-log ai xuất, cái gì, khi nào); số trong file xuất khớp snapshot dashboard tại thời điểm xuất.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Đợt tổng hợp dữ liệu dashboard theo kỳ (data snapshot cycle — mỗi khối dữ liệu, mỗi kỳ)

**Sơ đồ trạng thái:**
```
[SYNCING] ──(gom đủ nguồn)──► [VALIDATING] ──(pass quality)──► [READY] ──(publish)──► [PUBLISHED] ──(chốt kỳ)──► [LOCKED]
    │                              │
    │ (nguồn lỗi / thiếu nguồn)     │ (fail quality)
    ▼                              ▼
[DEGRADED] ──(retry ok)──► [SYNCING]                    [VALIDATING] (retry sau khi sửa nguồn)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `SYNCING` | Gom đủ nguồn | `VALIDATING` | Hệ thống | Đủ nguồn hoặc danh sách nguồn missing đã ghi nhận |
| `SYNCING` | Nguồn lỗi/thiếu | `DEGRADED` | Hệ thống | Phát sự kiện "nguồn mù" cho alert center; nhãn manual khi nhập tay |
| `DEGRADED` | Retry thành công | `SYNCING` | Hệ thống/SYS_ADMIN | Backfill dữ liệu thiếu trước khi tiếp tục |
| `VALIDATING` | Pass quality | `READY` | Hệ thống | Đối soát nhất quán với sổ nguồn; sai lệch trong dung sai DI-001 |
| `READY` | Publish | `PUBLISHED` | FIN_L2 duyệt | Ghi freshness "HH:MM" + nhãn nguồn từng khối |
| `PUBLISHED` | Chốt kỳ | `LOCKED` | FIN_L2 (khóa kỳ theo REQ-FIN-004) | Khóa kỳ có audit; snapshot bất biến |

**Quy tắc:**
- `LOCKED` là trạng thái kết thúc kỳ — không chuyển tiếp; chỉnh sửa chỉ qua reversal kỳ hiện hành.
- Trạng thái `DEGRADED` không được tự động publish — phải qua retry hoặc nhập tay có nhãn manual.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `wallet_balance_snap` | `customer_id`, `platform_id`, `balance`, `currency`, `fx_snapshot_id`, `planned_spend_date`, `balance_type` (liability) | FK → dim_customer/dim_platform | Tiền giữ hộ tách bạch; theo ví, không bù trừ chéo |
| `recon_status_fact` | `txn_ref`, `recon_state`, `discrepancy_id`, `delta`, `source_label` | FK → giao dịch nguồn | Trạng thái đối soát + discrepancy tồn; manual có minh chứng |
| `ar_ap_aging_fact` | `invoice_id`, `direction` (AR/AP), `bucket` (chuẩn REQ-FIN-007), `open_amount`, `due_date` | FK → hóa đơn | Nguồn clawback hoa hồng; mốc PAUSE `[KXN-22]` là tham số cấu hình |
| `approval_queue_snap` | `request_id`, `queue_type`, `wait_hours`, `sla_breach_flag`, `current_approver` | FK → luồng duyệt chi | Phát hiện quá SLA; feed alert center |
| `dash_snapshot_cycle` | `cycle_id`, `scope`, `status` (SYNCING→LOCKED), `published_at`, `freshness_at`, `missing_sources` | 1-N khối dữ liệu | Nguồn sự thật trạng thái đợt tổng hợp; khóa kỳ bất biến |
| `dashboard_query_audit` | `query_id`, `actor`, `role`, `params`, `queried_at` | FK → users | Meta-log mọi truy xuất — FIN và BOD_CFO_CTO đều bị log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền đầy đủ ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đủ khối chuẩn | Dashboard FIN cấu hình xong | Kiểm tra API | Trả đủ 6 khối: số dư ví + ngày chi dự kiến, đối soát, discrepancy, aging AR/AP, hàng chờ duyệt quá SLA, hạn mức tuần nạp | [ ] |
| SC-002: Freshness hiển thị | Chi tiêu QC cập nhật lúc 10:40 | Mở dashboard 11:20 | Widget QC gắn stale (>1h) kèm "cập nhật lúc 10:40"; không hiện như số tươi | [ ] |
| SC-003: Nhãn manual | Nền tảng X nhập tay trong kỳ | Truy vấn khối liên quan | Hiển thị nhãn "manual" + disclaimer độ trễ; minh chứng kỳ tồn tại | [ ] |
| SC-004: Portal bị chặn | Tài khoản realm portal gọi API dashboard nội bộ | Request | Từ chối 403 — không lộ dashboard nội bộ cho khách (BR-FIN-307.4) | [ ] |
| SC-005: Khóa kỳ | Kỳ 09 đã LOCKED | Truy vấn dashboard kỳ 09 | Trả snapshot chốt bất biến; điều chỉnh sau chốt chỉ thấy ở kỳ hiện hành qua reversal | [ ] |
| SC-006: Audit truy xuất | BOD_CFO_CTO xem dashboard 14:00 | Sau truy vấn | `dashboard_query_audit` có bản ghi actor + params + timestamp | [ ] |

> **Liên kết:** Mỗi scenario map về REQ-FIN-015 (Phần A `finance.md`) và BR-FIN-307.x / BR-DHUB-40x ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — snapshot ví, aging, cycle, audit | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — dashboard FIN query, snapshot publish/lock | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — modules tài chính, GW, connector VAS vendor-agnostic (DI-004) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (counterpart WEB/MOBILE) | `phase4-ux/bcerp-web/datahub-bi/*.md`, `phase4-ux/mobile-internal/datahub-bi/*.md` |
| Feature liên quan cùng module | FEAT-CORE-DHUB-001 (P&L dùng số FIN), FEAT-CORE-DHUB-003 (alert ngưỡng), FEAT-CORE-DHUB-005 (BI/BOD GĐ3 mở rộng) |
