# Screen Group: TikTok Shop Monitor

Implements: FEAT-ERP-TIKTOK-001 (REQ-OPS-011) — bản touchpoint SYS-BCERP-WEB

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `tiktok`
> **Tính năng:** FEAT-ERP-TIKTOK-001
> **Route:** `/ops/tiktok-shop`
> **Main UI-ID:** `UI-WEB-TTSHOP-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Ops (`/ops/*`) — S17, mục "TikTok Shop Monitor" |
| Đối tượng nghiệp vụ | TikTok Shop Connection (OAuth per-client, 1 shop-1 ủy quyền-1 khách) + chỉ số pull-based `reference_only=true` — WEB chỉ **hiển thị machine-state** do core/GW trả về (BR-001), KHÔNG sở hữu state |
| Vai trò chính | OPS_AM (shop phụ trách), OPS_ADS (số liệu), OPS_PLAN (toàn bộ shop — điều phối); OPS_CONT/DES/EDIT view-only |
| Vai liên quan | FIN_L1 (read — ngữ cảnh đối soát Gate 3 tại S7), SYS_ADMIN (degraded/connector tại S27), SALES_L4 (ký Gate 2 — ngoài S17), BOD (escalation cuối tại S24) |
| Workflow stage | Sau kết nối: `operating` (Gate 3 định kỳ) / `degraded_manual` / `revoked` — S17 là bề mặt **monitor**, không phải CRUD app (R11) |
| Screen liên quan | S24 Alert Center (escalation), S7 Ví & Đối soát (Gate 3 — FIN), S27 Integration & Settings (connection degraded/revoke) |

**BƯỚC 0 — Workflow checklist:** (A) Object = shop kết nối + chỉ số giám sát, trạng thái auto từ API pull. (B) Actor chính: OPS_AM/ADS/PLAN. (C) Liên quan: FIN_L1, SYS_ADMIN, S24, M-INT push (REQ-OPS-008). (D) Lifecycle hiển thị theo 3-Gate P3-01 §9.2 — xem chú thích bên dưới. (E) Phụ thuộc: GW pull + core alert engine. (F) Thông tin cần: shop nào ở gate nào, sức khỏe, freshness + nguồn (`api`/`manual`), anomaly. (G) Quyết định: ack/xử lý cảnh báo, escalate. (H) Hành động: xem, ack (reason bắt buộc khi đóng), drill-down — KHÔNG thêm/sửa/xóa (BR-009/011). (I) Exceptions: shop khóa, settlement lệch, giấy phép/OAuth hết hạn, baseline lệch, mất pull. (J) Không cần tách page — 1 surface + sheet drill-down.

> **Chú thích lifecycle ([NEEDS_REVIEW: F-C-02 — DEFERRED]):** 3 nguồn từng lệch nhau (baseline "connected→monitoring→alert" ≠ P3-01 §9.2 ≠ DB TBL-GW-014). Theo stakeholder-review, **P3-01 §9.2 (workflow 3-Gate, KXN-14) là nguồn chính thống**: `proposed → verifying (Gate 1) → gate2_signed → operating → degraded_manual/revoked`. Nhãn hiển thị tiếng Việt map 1-1 từ machine-state API; `gate2_signed` mô hình hóa qua cột `gate_stage` (không có trong DB CHECK — chấp nhận semantic). Baseline §2.0.1 đã superseded cho object này; chờ owner GW/OPS xác nhận trước pre-launch.

---

## 1. TRANG CHÍNH

**Mục tiêu:** cho OPS nhìn trong ~10 giây: shop nào khỏe, shop nào đang có anomaly cần ai xử lý, dữ liệu còn "sống" không (freshness + nguồn). Dashboard operational W4 thu gọn — mọi số click ra được worklist đã lọc; không card trang trí.

### Wireframe (desktop ≥1280px, container full-width max 1920px)

```
┌──────┬──────────────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ OPS / TikTok Shop Monitor                        [Làm mới]  ⏱ Pull lúc 09:24 · 4 phút trước │
│ rail ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ [!] Mất API TikTok 06:50 — shop "Pet House" chuyển nguồn manual; đối chiếu backfill   │
│      │     đang chờ. → Xem kết nối (S27)            (WarningIndicator banner — chỉ khi degraded)│
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ ┌ Vận hành ──┐ ┌ Đang cảnh báo ┐ ┌ Dữ liệu trễ ─┐ ┌ Hết hạn ≤14 ngày ┐              │
│      │ │     8      │ │   2  [chuông] │ │ 1  [đồng hồ] │ │        1         │  ← click = lọc │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ CẢNH BÁO ANOMALY (2 mở)                    [Xem tất cả trong Alert Center → S24]      │
│      │ ▲ đỏ  · MP Beauty — Settlement lệch 4,2tr vs đơn (Gate 3)  · OPS_ADS N.Vũ · còn 5h  │
│      │   [Ack] [Chi tiết]                                                                  │
│      │ ▲ vàng · Nông Sản VN — OAuth hết hạn sau 9 ngày · OPS_AM T.Hằng · còn 2 ngày        │
│      │   [Ack] [Chi tiết]                                                                  │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ [Đang cảnh báo ·2 ×] [Dữ liệu trễ ·1 ×] [Chờ Gate ·1 ×] [Manual ·1 ×]  [Tìm shop/khách]│
│      │                                        [Bộ lọc ▾: trạng thái · nguồn · owner]       │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ SHOP                 KHÁCH   TRẠNG THÁI 3-GATE  SỨC KHỎE  FRESHNESS   GMV 7N‖NSQC 7N │
│      │ MP Beauty            KH-0124 ● Đang vận hành      92▼     api·09:20   218,4tr‖ 35,2tr │
│      │                      ⚠ 1 cảnh báo settlement lệch · owner OPS_ADS N.Vũ       [⋯]    │
│      │ Thời Trang XYZ       KH-0087 ● Đang vận hành      61▼↓    api·09:20    96,1tr‖ 12,0tr │
│      │ Đồ Chơi Kid          KH-0203 ◐ Gate 1 — thẩm định  —       —          —     ‖  —     │
│      │                      ⏳ chờ FIN_L1 đối chiếu pháp lý · 2 ngày (WaitingOn)     [⋯]    │
│      │ Nông Sản VN          KH-0151 ● Đang vận hành      78→     api·09:18    41,7tr‖  8,9tr │
│      │ Pet House            KH-0095 ○ Degraded manual    —       manual·08:00  12,3tr‖  —     │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │                                    ‹ 1 2 3 ›   20/50/100 (server-side)               │
└──────┴──────────────────────────────────────────────────────────────────────────────────────┘
     ‖ GMV 7 ngày (nhóm SHOP) và chi NSQC 7 ngày (nhóm ADS) là 2 cột nhóm RIÊNG — không cột tổng (BR-002)
```

### Vùng nội dung

- **Thanh freshness (header):** "Pull lúc dd/MM HH:mm · X phút trước" + nhãn nguồn tổng (`api`/`manual`) — BR-003; làm mới theo poll chuẩn web nội bộ (machine-state phản ánh ≤1 chu kỳ làm mới — spec §6). Pull trễ > ngưỡng cấu hình → ô "Dữ liệu trễ" sáng + banner.
- **KPI strip (Pattern W4):** 4 ô: Vận hành (số shop `operating`) · Đang cảnh báo (alert mở) · Dữ liệu trễ (freshness vi phạm SLA pull) · Hết hạn ≤14 ngày (giấy phép ngành hàng + OAuth `EXPIRING`). Click ô → áp quick chip tương ứng lên bảng (dashboard phải dẫn hành động).
- **Cảnh báo anomaly (feed API-GW-046):** tối đa 5 mục mới nhất, mỗi mục: severity + shop + loại (shop khóa / settlement lệch / giấy phép-OAuth hết hạn / baseline lệch) + owner + WaitingOn SLA (chip `--state-sla-warning`/`--state-sla-breach`, BR-008: quá hạn → escalate, hiển thị "đã escalate → OPS_PLAN/BOD"). Nút **Ack** (D1) và **Chi tiết** (S1). Quá 5 mục → "Xem tất cả trong Alert Center" (S24 — escalation inbox, không nhân bản ở đây).
- **Danh sách shop (DataTable compact 32px, Pattern W1):**
  - Cột: Shop · Khách (tenant) · **Trạng thái 3-Gate** (StatusBadge theo machine-state — 1 badge/hàng) · Sức khỏe (`health_score` + mũi tên delta; <70 nền warning) · Freshness (nguồn `api`|badge `--state-manual` "manual" + thời điểm pull) · GMV 7N · NSQC 7N (2 cột nhóm riêng, `MoneyDisplay` right-align tabular-nums, `reference_only=true`) · Cảnh báo (badge count) · Owner · row action `[⋯]` → Chi tiết (S1).
  - Exception inline: hàng có alert → WarningIndicator dòng phụ dưới tên shop (chuyện gì — ai làm — hạn còn lại).
  - **WaitingOn:** shop đang kẹt ở Gate 1 (`verifying`) hiển thị chip "chờ FIN_L1 đối chiếu pháp lý · X ngày"; task thu hồi 24h quá hạn → chip đỏ "thu hồi quá 24h — đã escalate" (BR-007).
  - Quick filter chips (tháo được từng chip) + search theo tên shop/khách + filter dropdown (trạng thái gate, nguồn, owner, tenant — tenant do API enforce RLS, UI không gửi tham số tenant tay — BR-006). Sort theo click header (sức khỏe, freshness, GMV). Bulk actions: KHÔNG (monitor không có thao tác hàng loạt — R11).
- **Row grouping không cần** — số shop nhỏ (theo tenant scope); pagination server-side 20/50/100.

**States:** loading = skeleton 10 hàng + KPI shimmer; empty = EmptyState "Chưa có shop nào trong phạm vi của bạn — đăng ký shop do OPS_AM thực hiện" (không CTA tạo nếu không có quyền); error = hàng lỗi + Retry, không fallback dữ liệu mặc định (BR-006); machine-state không trả về → badge "Không xác định" + toàn bộ action khóa (BR-001).

**Permission-aware (ẩn theo PEP — action không có quyền bị ẩn, không disabled):** bảng chỉ hiện shop theo tenant được gán; cột/chức năng giống nhau mọi vai OPS + FIN_L1 (read) — khác nhau ở: **Ack** chỉ hiện với vai trong severity routing của alert (OPS_AM/OPS_PLAN theo BR-008); banner degraded + link S27 chỉ hiện SYS_ADMIN/OPS_AM; drill-down số tài chính chi tiết: OPS_CONT/DES/EDIT view-only (ẩn nút Ack), FIN_L1 thấy thêm link đối soát S7.

---

## 2. TABS

N/A — S17 là monitor 1 surface: KPI strip + alert feed + danh sách nằm cùng trang vì cùng một luồng nhìn (tổng quan → cảnh báo → shop); drill-down là Sheet giữ ngữ cảnh list. Tách tab dashboard/list = thêm navigation vô ích cho màn hình đọc (R11). Gate workflow thao tác (checklist Gate 1, ký Gate 2, bảng đối soát Gate 3) KHÔNG thuộc S17 — xem ghi chú tại mục 5.

---

## 3. DIALOGS

### D1 — Ack / xử lý cảnh báo anomaly (`UI-WEB-TTSHOP-001-D1`)

- **Kích hoạt:** nút [Ack] trên alert feed hoặc trong sheet S1.
- **Nội dung:** tóm tắt alert (loại, shop, giá trị lệch `MoneyDisplay`, phát hiện lúc, nguồn dữ liệu) + owner hiện tại + SLA còn lại (WaitingOnIndicator) + link object nguồn.
- **Hành động (theo lifecycle alert engine — không auto-close):**
  - **Tiếp nhận (acknowledged):** ghi nhận người tiếp nhận + thời gian; ghi chú tùy chọn.
  - **Đang điều tra (investigating):** gán/chuyển owner (AssigneePicker, trong data-scope).
  - **Đóng (resolved):** **bắt buộc reason ≥10 ký tự** (BR-008 — tắt cảnh báo không reason → form từ chối) + ghi audit log bất biến.
- **States:** processing khóa nút (chống double-submit); lỗi → Toast error không tự đóng; sau thành công → alert rời feed mở, entry mới trong activity.
- **Permission:** Ack/đóng chỉ với vai theo severity routing (BR-008, API-CORE-044 permission); vai khác không thấy nút.

---

## 4. SHEETS

### S1 — Drill-down shop / điều tra anomaly (`UI-WEB-TTSHOP-001-S01`)

Drawer phải 720px (không rời trang — giữ ngữ cảnh list; Esc đóng, focus về hàng vừa mở).

- **Header:** tên shop + khách (tenant) + StatusBadge machine-state + nút đóng. Machine-state không xác định → hiển thị "Không xác định" và khóa mọi action (BR-001).
- **Tiến trình 3-Gate (ProgressTracker compact):** `proposed → verifying (Gate 1) → gate2_signed → operating`, nhánh `degraded_manual`/`revoked` hiển thị node blocked/rejected; node hiện tại gắn WaitingOn (ai giữ việc + bao lâu — VD "Gate 1: chờ FIN_L1 đối chiếu pháp lý · 2 ngày").
- **Sức khỏe + freshness:** `health_score` + delta 7 ngày; dòng "Nguồn: api · pull 09:20 (4 phút trước)" hoặc badge `--state-manual` "Dữ liệu thủ công" (hiển thị vĩnh viễn trên record — design-system §6) + banner đối chiếu backfill khi có lại API (`manual` vs `api`, sai số vượt dung sai → "tranh chấp — chờ FIN_L1", BR-003).
- **Chỉ số tách nhóm (BR-002 — cấm trộn):**
  - Nhóm SHOP — kết quả shop: GMV · đơn · settlement (7/30 ngày, `MoneyDisplay`).
  - Nhóm ADS — chi tiêu NSQC: `ad_spend` (7/30 ngày).
  - Không có hàng/widget "tổng cộng" chung hai nhóm; không quy đổi GMV ↔ chi tiêu.
- **OAuth grant:** scope, ngày cấp, ngày hết hạn, trạng thái `ACTIVE/EXPIRING/EXPIRED/REVOKED`; `EXPIRING` → WarningIndicator trước hạn; `EXPIRED/REVOKED` → dừng dữ liệu mới từ mốc thời điểm, hiển thị task thu hồi 24h + deadline; token KHÔNG BAO GIỜ hiển thị.
- **Cảnh báo đang mở của shop:** list rút gọn + [Ack] (D1) — cùng permission rule với feed chính.
- **Access log (read-only, append-only):** 5 entry gần nhất (actor, action, api_object, scope_used, timestamp) — API-GW-040.
- **Footer (link, không thao tác số liệu):** "Mở Alert Center (S24)" · "Xem đối soát Gate 3 (S7 — FIN_L1)" · "Quản lý kết nối/degraded (S27 — SYS_ADMIN)". KHÔNG có nút sửa GMV/settlement/baseline (BR-011), KHÔNG có thao tác đơn/fulfillment (BR-009 — OMS/WMS ngoài phạm vi).

---

## 5. VIEW MODES

N/A — monitor read-only: không có mode Create/Edit (không CRUD, R11); hành động duyệt duy nhất của surface là Ack alert (D1). Phân quyền là **scope hiển thị**, không phải mode riêng:

| Vai | Danh sách + dashboard | Alert feed | Ack/đóng alert | Drill-down S1 |
|-----|----------------------|-----------|----------------|----------------|
| OPS_AM | Shop phụ trách | ✓ | ✓ (alert của shop phụ trách) | Đầy đủ |
| OPS_ADS | Shop phụ trách | ✓ | ✗ (chỉ xem) | Đầy đủ; mở PII TTL theo purpose riêng (API-GW-044, ngoài S17) |
| OPS_PLAN | Toàn bộ shop | ✓ | ✓ (escalation — BR-008) | Đầy đủ |
| OPS_CONT/DES/EDIT | View-only | Xem | ✗ ẩn | Chỉ sức khỏe + GMV nhóm shop |
| FIN_L1 | View-only | Xem | ✗ (đóng ở S24/core theo routing) | + link S7 đối soát |
| SYS_ADMIN | View-only | Xem | ✗ | + banner degraded, link S27 |

> **Ghi chú ranh giới scope:** các thao tác workflow 3-Gate (submit checklist Gate 1 — OPS_AM+FIN_L1; ký Gate 2 — SALES_L4 duy nhất; chạy đối soát Gate 3 — FIN_L1 chủ trì; cấu hình ngưỡng/tần suất) thuộc FEAT-ERP-TIKTOK-001 nhưng **ngoài surface monitor S17**; S17 chỉ phản chiếu trạng thái + WaitingOn. `[NEEDS_REVIEW: vị trí bề mặt Gate-workflow UI — inventory hiện chỉ có S17 cho module tiktok; đề nghị gắn Gate 1/2 vào surface mở rộng của S17 hoặc điều phối qua S7/S27 theo vai — chốt ở Phase 3 check]`.

---

## 6. API ENDPOINTS

> Endpoint THẬT từ `api-contract.md`. Pagination mọi list: `?page=1&limit=20&sort=&order=` — server-side, mặc định 20, tối đa 100.

| API-ID | Method + Path | Gắn với UI | Tham số chính / ghi chú |
|--------|---------------|-----------|--------------------------|
| API-ERP-054 | GET `/api/v1/erp/tiktok-shop/monitor` | KPI strip + danh sách shop (BFF web) | `reference_only=true`; trả nhãn `api`/`manual` + timestamp + độ trễ khi degraded; permission OPS |
| API-GW-037 | GET `/gw/shop/connections` | Danh sách shop + filter | filter `tenantId,status,gateStage`; tenant-scoped (RLS phía API — BR-006); sort/pagination server-side |
| API-GW-038 | GET `/gw/shop/connections/:id` | Sheet S1 — header + 3-Gate + OAuth | Trả scope + `gate_stage` + `expires_at` (machine-state) |
| API-GW-041 | GET `/gw/shop/metrics` | S1 — khối chỉ số tách nhóm + freshness | filter `shopId,window,metricType,sourceLabel`; luôn `referenceOnly=true`; nhóm `metricType` shop vs ads render riêng (BR-002) |
| API-GW-046 | GET `/gw/shop/alerts` | Feed cảnh báo anomaly + badge count | Alert: shop khóa, settlement lệch, giấy phép/OAuth hết hạn, baseline lệch |
| API-CORE-043 | GET `/core/alerts/instances` | Feed (nguồn phụ hợp nhất) + link S24 | filter `status/severity/window` — routing theo vai |
| API-CORE-044 | POST `/core/alerts/instances/:id/transitions` | D1 — Ack/investigating/resolved | Lifecycle `open→acknowledged→investigating→resolved`; không auto-close; `[STEP-UP]` severity CRITICAL; reason resolved ghi audit |
| API-GW-040 | GET `/gw/shop/connections/:id/access-logs` | S1 — access log | Bất biến, read-only; permission CTO/OPS_AM |

Không có endpoint ack riêng cấp GW cho shop-alert — ack đi qua alert engine core (API-CORE-044), khớp BR-008 (reason + audit) và model "không auto-close". **Không dùng endpoint nào ngoài bảng này; không bịa endpoint sửa số liệu** (BR-011 — read-only, append-only).

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-TTSHOP-001` | Main Page | TikTok Shop Monitor — KPI strip + alert feed + danh sách shop (Pattern W4 gọn + W1), route `/ops/tiktok-shop`, badge nav `{tiktok_anomaly}` |
| `UI-WEB-TTSHOP-001-D1` | Dialog | Ack / xử lý cảnh báo anomaly (acknowledged / investigating / resolved — reason bắt buộc khi đóng) |
| `UI-WEB-TTSHOP-001-S01` | Sheet | Drill-down shop / điều tra anomaly (720px: 3-Gate, sức khỏe + freshness + nguồn, GMV‖NSQC tách nhóm, OAuth, alert, access log) |

Không đăng ký T (tabs — N/A) và M (view modes — N/A) vì section 2/5 ghi N/A.

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/tiktok-shop/tiktok-shop-monitoring.md` | Upstream — FEAT-ERP-TIKTOK-001, BR-001…012, ma trận phân quyền |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — API-ERP-054; API-GW-036…048; API-CORE-043/044 |
| Lifecycle chính thống 3-Gate | `../../../../phase3-architecture/P3-01-architecture.md` §9.2 | Nguồn chính thống — [NEEDS_REVIEW: F-C-02, DEFERRED] |
| Design system | `../../../design-system.md` | Upstream — tokens, StatusBadge, WarningIndicator, WaitingOnIndicator, MoneyDisplay |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S17, quyền TIKTOK, badge `{tiktok_anomaly}` |
| Alert Center (S24) | `../../executive/datahub` | Screen liên quan — escalation inbox |
| Ví & Đối soát (S7) | `../../finance/wallet` | Gate 3 đối soát — FIN_L1 |
| Integration & Settings (S27) | `../../settings/stgw` | Connection degraded / revoke |


## Bổ sung Gate-Workflow Surface (stakeholder F-D-01 — [NEEDS_REVIEW #8])

> Đối chiếu integration-map + P3-01 §9.2: vòng đời TikTok Shop 3-Gate (proposed → verifying → gate2_signed → operating…) có API-GW-039 nhưng 0 UI tiêu thụ. Nhận bề mặt vào S17 (không tạo screen mới — consolidation guard):

| Thành phần | Nội dung |
|---|---|
| Tab mới T2 "Gate Workflow" (`UI-WEB-TTSHOP-001-T2`) | Bảng shop theo stage 3-Gate; stage hiện tại + gate tiếp theo (ProgressTracker); action: OPS_AM đề xuất Gate 1 → checklist xác minh FIN_L1 (Gate 1) → ký Gate 2 `[NEEDS_REVIEW #8: SALES_L4 ký — chờ BOD chốt vai]` → operating; Gate 3 đối soát về S7. |
| Quyền | OPS_AM (đề xuất), FIN_L1 (checklist Gate 1), ký Gate 2 chờ NEEDS_REVIEW #8; xem: BOD |
| Endpoint | API-GW-039 (thật, có trong api-contract) |

**Cập nhật inventory:** workflow-context.md §2.0.3 S17 — ghi nhận thêm Tab Gate-Workflow (không tăng số surface).
