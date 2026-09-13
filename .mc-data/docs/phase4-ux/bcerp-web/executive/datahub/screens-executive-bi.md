# Screen Group: Executive BI (tabs: P&L realtime / Phòng ban)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `datahub` (MOD-DATAHUB-BI)
> **Tính năng:** FEAT-ERP-DHUB-001, 002, 004, 005
> **Route:** `/exec/bi`
> **Main UI-ID:** `UI-WEB-BI-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-DHUB-001 (P&L toàn công ty realtime), FEAT-ERP-DHUB-002 (BI dashboard điều hành — 8 nhóm KPI chuẩn, Metric Catalog, quality gate block publish), FEAT-ERP-DHUB-004 (dashboard & báo cáo tài chính nội bộ — góc FIN của tab Phòng ban), FEAT-ERP-DHUB-005 (P&L theo dự án/khách góc FIN + kiểm soát dữ liệu nguồn). FEAT-ERP-DHUB-003 (Alert Center) thuộc S24 `/exec/alerts`.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-BI-001` |
| Route | `/exec/bi` (`?tab=pnl\|dept`, dept = `?dept=sales\|finance\|ops\|hr`) |
| Loại | Dashboard (pattern W4 — KPI row → widget 12 cột, widget click → worklist đã lọc) |
| FEAT-ID | FEAT-ERP-DHUB-001, FEAT-ERP-DHUB-002, FEAT-ERP-DHUB-004, FEAT-ERP-DHUB-005 |
| Workspace | Executive (`/exec`) — trang đích workspace Exec |
| Đối tượng nghiệp vụ | P&L (pnl_fact), KPI điều hành (Metric Catalog × marts: sales_funnel, wallet, ar_ap, ops_delivery, people_cost, cs_sla, shop_reference), data_source/ingest pipeline (ETL health) |
| Vai trò chính | BOD_CEO, BOD_CFO_CTO |
| Vai trò liên quan | FIN_L1 (read — P&L phạm vi đối soát của mình + dashboard Finance), FIN_L2 (read — Finance toàn bộ + đề xuất metric), SYS_ADMIN (duy nhất dải Data Health — KHÔNG thấy giá trị tài chính T3/T4) |
| Workflow stage | ingest → reconcile → publish (freshness stream P&L ≤5 phút) → alert (object P&L/BI — $WORKFLOW_MAP dòng cuối) |

**Checklist workflow context (Bước 0):** (A) Object: bức tranh lãi/lỗ + KPI sức khỏe công ty — số sinh tự động từ star schema, KHÔNG có vòng đời thao tác trên số (read-only tuyệt đối); state thật nằm ở *nguồn dữ liệu* (FRESH/STALE/DEGRADED) và *kỳ báo cáo* (OPEN/LOCK_PENDING/CLOSED). (B) Actor chính: BOD đọc báo cáo buổi sáng, quyết định can thiệp chiều nào đang ăn mòn margin. (C) Liên phòng: FIN (nguồn số + kiểm soát dữ liệu sạch), OPS/SALES/HR (chủ worklist đích khi drill-down), SYS_ADMIN (vận hành pipeline), CTO duyệt backfill. (D) Lifecycle: ingest → quality gate → publish ≤5 phút; widget render chỉ khi `is_stale=false` hoặc hiển thị nhãn stale/manual bắt buộc. (E) Cross-module: mọi widget action-oriented phải dẫn về worklist nguồn đúng surface (S1/S3/S6/S7/S9/S10/S14/S15/S16/S17/S20/S22). (F) Thông tin cần: P&L 4 chiều (dự án/khách/nền tảng/tháng), tiền giữ hộ tách bạch, freshness + nguồn api/manual từng widget, dải giờ chờ duyệt, chi chờ phân loại, GM vs ngưỡng policy, 8 nhóm KPI chuẩn. (G) Quyết định: can thiệp giá/dự án, chốt quyết trên số chốt hay tạm tính, duyệt publish, duyệt đổi định nghĩa metric (CFO). (H) Action được phép: xem, drill-down, export (có audit), publish (CFO), đề xuất/duyệt metric, cấu hình layout cá nhân — KHÔNG có sửa số (BR-003/BR-007 không nhập tay). (I) Exception: stale nghiêm trọng (chi QC >8h, ví >2h, timesheet >24h → cảnh báo đỏ), nguồn degraded nhãn "manual", quality test fail chặn publish, metric CHANGE_PENDING, hai luồng FIN/BOD lệch số → cảnh báo lệch chuẩn. (J) 1 surface duy nhất tiêu thụ BI cho Exec + FIN read — tabs theo nội dung, không tách page theo vai.

---

## 1. TRANG CHÍNH

### 1.1. Layout — pattern W4 dashboard grid (spacious, container max 1600px center)

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Executive > Executive BI        Kỳ: T9/2026 [số tạm tính — còn biến động ▾]  [Export]│
│ [P&L Realtime] [Dashboard phòng ban]        ⏱ stream ≤5 phút · cập nhật 14:32:05 api │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ DATA HEALTH: GW-7nền tảng ●FRESH 08′ │ Ví ●FRESH 12′ │ Timesheet ●FRESH 40′          │
│ Sổ kế toán VAS ◐MANUAL cuối 13:00 ⚠ │ QC chi ●FRESH 22′ │ DLQ 0 │ [Chi tiết nguồn…]    │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ ┌───────────────┬───────────────┬───────────────┬───────────────┐                    │
│ │ Doanh thu DV  │ Tổng chi phí  │ P&L tháng     │ GM %          │  ← KPI row         │
│ │ 8,42 tỷ ₫     │ 6,15 tỷ ₫     │ +2,27 tỷ ₫    │ 27,0 %        │    4 ô số lớn      │
│ │ ▲ +6,2% vs T8 │ ▲ +3,1% vs T8 │ ▲ +11,4%      │ ▼ −1,2đ ⚠     │    + delta         │
│ │ ⏱14:32 api    │ ⏱14:30 api    │ ⏱14:32 api    │ ⏱14:28 api    │                    │
│ └───────────────┴───────────────┴───────────────┴───────────────┘                    │
│ ┌──────────────────────────────────────┬───────────────────────────────────────┐      │
│ │ P&L THEO KHÁCH (top 8)  12 cột       │ CHI PHÍ THEO NHÓM + GIỜ CHỜ DUYỆT     │      │
│ │ KH01 1,2 tỷ ▲ │ RET03 0,9 tỷ ▼      │ Nhân công 58% · Outsource 22% ·       │      │
│ │ click hàng → drill-down dự án →      │ Tools 12% · Media pass-through (tách) │      │
│ │ dòng chi (giờ×rate/outsource/tools)  │ ⚠ 120 giờ chờ duyệt · tác động 84tr ₫ │      │
│ │                                      │ → click mở worklist timesheet chờ     │      │
│ └──────────────────────────────────────┴───────────────────────────────────────┘      │
│ ┌──────────────────────────────────────┬───────────────────────────────────────┐      │
│ │ P&L THEO NỀN TẢNG TKQC               │ GM THEO NHÓM DỊCH VỤ vs NGƯỜNG        │      │
│ │ Meta │ Google │ TikTok │ …           │ Agency 18,2%/15% ✓ │ Ads ops 21,4/20% │      │
│ │ (tiền giữ hộ KHÔNG nằm ở đây —      │ SEO 31,8%/35% ⚠ │ Web 33,1/30% ✓      │      │
│ │  xem dải "Tiền giữ hộ khách" dưới)   │ (ngưỡng ver 2026-08 · "chờ chốt số")  │      │
│ └──────────────────────────────────────┴───────────────────────────────────────┘      │
│ ┌──────────────────────────────────────────────────────────────────────────────┐      │
│ │ Tiền giữ hộ khách (nợ phải trả — tách khỏi doanh thu)  12,8 tỷ ₫ ⏱14:30 api │      │
│ └──────────────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- **Freshness indicator bắt buộc trên từng widget** (BR-005/BR-006 — "cập nhật lúc HH:MM + nguồn api/manual"); widget thiếu chỉ báo thì không render số. Widget `is_stale=true` render khung cảnh báo đỏ + timestamp dữ liệu hợp lệ cuối, KHÔNG nội suy số ẩn. Stale nghiêm trọng (chi QC >8h, ví >2h, timesheet >24h) → viền đỏ + icon `clock-sla`.
- **Dải DATA HEALTH** (ETL pipeline health) nằm cố định dưới tabs: mỗi nguồn = dot trạng thái (FRESH xanh / STALE vàng / DEGRADED nhãn "manual" — token `--state-manual`) + tuổi watermark + DLQ count. SYS_ADMIN mở route này chỉ thấy dải + sheet S2 (không thấy mọi widget tài chính).
- **Nhãn kỳ** trên header: kỳ OPEN = "số tạm tính — còn biến động"; kỳ CLOSED = "đã chốt" (khóa kỳ do FIN_L2 thực hiện ở surface FIN, ở đây read-only). Có badge "đang có đề xuất đổi định nghĩa" khi tồn tại metric CHANGE_PENDING.
- **So sánh liên kỳ:** toggle "vs T8 / vs cùng kỳ 2025" trên KPI row — snapshot kỳ so sánh từ API-CORE-037.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| KPI StatCard (W4 hàng 1) | 4 ô số lớn `--text-3xl` `tabular-nums` + delta ±% màu success/error + freshness | Click card = drill-down chiều tương ứng |
| Widget grid | 12 cột, gutter 16px, spacious; **widget chỉ tồn tại nếu click ra được worklist/sheet đích** (W4 — không card trang trí) | Không card lồng card |
| FreshnessChip | "⏱ HH:MM · api\|manual" trên mọi widget + KPI | `is_stale` → đỏ; manual → badge `--state-manual` vĩnh viễn |
| WarningIndicator | banner mức trang (nguồn degraded, lệch chuẩn 2 luồng) + inline mức widget | 3 phần bắt buộc: chuyện gì / cần ai / timestamp cuối |
| DataHealthStrip | dot + watermark + DLQ per nguồn; click → Sheet S2 | Nguồn từ API-CORE-040/047 |
| MoneyDisplay | plain VND + delta + multi-currency (gốc USD + tỷ giá snapshot dùng chung) | Tiền giữ hộ = nhóm riêng nhãn "nợ phải trả", cấm cộng vào doanh thu |
| Tabs (page) | P&L Realtime / Phòng ban | Lazy-load tab chưa mở (performance) |
| Breadcrumb drill | Tổng công ty → Phòng → Khách/Dự án → Dòng chi | Click 1 nút quay lại 1 tầng; tầng sâu nhất mở Sheet S1 |

### 1.3. Widget Inventory (mỗi widget 1 đích click — action-oriented)

| Widget | Tab | Nguồn (mart) | Click → đích |
|--------|-----|--------------|--------------|
| P&L theo khách / dự án / nền tảng / tháng (4 chiều drill) | T1 | `pnl_realtime` (API-CORE-037) | Sheet S1 drill-down truy xuất nguồn |
| Giờ timesheet chờ duyệt + tác động VND (dải tách — BR-007) | T1 | `people_cost` | `/ops/capacity?view=approvals` (S15) hoặc FIN: `/finance/...` worklist duyệt |
| Chi chờ phân loại overhead (BR-008) | T1 | `pnl_realtime` | Worklist FIN xử lý (S7/S10 deep-link) |
| GM theo nhóm dịch vụ vs ngưỡng policy (deal pilot ngoại lệ có dấu + ngày hết hạn) | T1 | `sales_funnel` + threshold config | `/sales/deal-desk?filter=gm_below_threshold` (S3) |
| 8 KPI chuẩn: ROAS · GM · SLA attainment · on-time delivery · pipeline coverage · capacity · aging công nợ · die account | T2 | marts tương ứng (API-CORE-036) | worklist tương ứng từng KPI (bảng §2) |
| Finance: số dư ví + ngày chi dự kiến; đối soát; discrepancy tồn; aging AR/AP 30/60/90; hàng chờ duyệt quá SLA; hạn mức tuần nạp (6 nhóm bắt buộc REQ-FIN-015) | T2-Finance | `wallet`, `ar_ap` | `/finance/wallet` (S7), `/finance/ar-ap?tab=ar&bucket=…` (S10), `/finance/approvals?sla=breach` (S6) |
| Sales: pipeline theo tier, win rate, deals chờ Gate, chiết khấu chờ duyệt | T2-Sales | `sales_funnel` | `/sales/pipeline?stage=…` (S1), `/sales/deal-desk?filter=discount_pending` (S3) |
| Ops: deliverable overdue, ticket SLA đỏ, TKQC OUT_OF_MONEY/die, TikTok anomaly | T2-Ops | `ops_delivery`, `cs_sla`, `shop_reference` | `/ops/campaigns?filter=overdue` (S14), `/ops/tickets?sla_state=breach` (S16), `/ops/ad-accounts?platform_status=OUT_OF_MONEY` (S9), `/ops/tiktok-shop` (S17) |
| HR: headcount/attrition, capacity utilization, KPI dưới chuẩn → PIP, HĐLĐ sắp hết hạn (90/60/30) — aggregate mức vai/nhóm (BR-009 PII) | T2-HR | `people_cost` | `/hr/kpi?filter=pip` (S22), `/hr/records?tab=hodl&filter=expiring` (S20), `/ops/capacity` (S15) |

### 1.4. Hành Động Chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Chọn kỳ (header) | Dropdown kỳ OPEN/CLOSED | Cả trang re-render theo kỳ; kỳ CLOSED gắn "đã chốt"; so sánh liên kỳ dùng số chốt |
| Click KPI/widget | Drill-down tầng kế theo chiều | Breadcrumb cập nhật; tầng cuối mở Sheet S1 (bản ghi nguồn) |
| [Export] | Dialog D1 | CSV/PDF async, watermark user + thời điểm, ghi audit + meta-log |
| [Publish] (chỉ CFO) | Dialog D2 | Chỉ cho phép khi quality test pass; fail → chặn + liệt kê test lỗi |
| [Định nghĩa số này] (menu ⋯ mỗi widget) | Sheet S3 | Công thức hiệu lực + version + effective_from/to + usage 90 ngày |
| [Đề xuất đổi định nghĩa] (Sheet S3) | Dialog D3 | FIN/BOD đề xuất → CFO duyệt (≤2 ngày làm việc) |
| Click nguồn ở DataHealthStrip | Sheet S2 | Runs, quality test, DLQ; SYS_ADMIN thấy nút deep-link sang S27 (backfill thao tác ở đó) |
| Đổi bộ lọc mặc định | Dialog D4 | Lưu layout cá nhân (persist theo user) |

### 1.5. States

- **Loading:** skeleton theo khung widget (KPI skeleton 4 ô, widget skeleton khung); tab chưa mở lazy-load khi click.
- **Empty:** widget không có dữ liệu trong phạm vi quyền/scope → EmptyState "Không có dữ liệu cho kỳ/phạm vi này" (không render 0 giả); module tương lai chưa triển khai (CMS/TMS/AI) → giữ chỗ nhãn "nguồn chưa triển khai", không render cột rỗng.
- **Error:** widget lỗi render riêng khối lỗi + retry per-widget, không sập cả trang; `MART_STALE` 200 + `is_stale=true` → cảnh báo đỏ thay số tươi.
- **Lệch chuẩn 2 luồng:** phát hiện P&L luồng FIN ≠ luồng BOD → banner đỏ "phát hiện lệch số giữa hai luồng — đã khóa widget, điều tra mapping" (sự cố P1).

### 1.6. Phân Quyền (PEP — action thiếu quyền bị ẨN, không disabled)

| Thành phần | BOD_CEO | BOD_CFO_CTO | FIN_L1 | FIN_L2 | SYS_ADMIN |
|-----------|---------|-------------|--------|--------|-----------|
| Tab P&L Realtime | ✅ toàn công ty | ✅ toàn công ty | ✅ phạm vi đối soát của mình | ✅ toàn bộ | ❌ ẩn hẳn |
| Tab Phòng ban — Finance | ✅ | ✅ | ✅ (6 nhóm widget REQ-FIN-015, drill trong scope) | ✅ toàn bộ | ❌ |
| Tab Phòng ban — Sales/Ops/HR | ✅ | ✅ | ❌ | ❌ | ❌ |
| Drill-down + xem cost rate T3/T4 trong dòng chi | ✅ | ✅ | ❌ (masked) | ✅ | ❌ (chỉ trạng thái nguồn, không có giá trị) |
| [Export] D1 | ✅ | ✅ | ✅ (bản vận hành) | ✅ (chính thức, có log) | ❌ |
| [Publish] D2 | ❌ | ✅ (chỉ CFO; chặn khi quality fail) | ❌ | ❌ (xem trạng thái kỳ) | ❌ |
| Đề xuất metric (D3) / duyệt metric | ✅ (đề xuất) | ✅ (đề xuất + duyệt — CFO) | ✅ (đề xuất) | ✅ (đề xuất chính thức) | ❌ |
| Khóa kỳ | ❌ (theo dõi) | ❌ | ❌ | ❌ (thao tác ở surface FIN — deep-link) | ❌ |
| DataHealthStrip + Sheet S2 | ✅ (summary) | ✅ | ✅ (nguồn mình phụ trách) | ✅ | ✅ (duy nhất phần được thấy trên surface này) |
| Sửa số P&L / nhập tay | **Không tồn tại ở mọi vai** — không render, không đường nhập (BR-003/BR-007) | | | | |

Góc nhìn FIN và BOD đọc cùng star schema cùng version metric — KHÔNG được tồn tại hai con số (BR-011 DHUB-005). Mọi lượt xem/export của cả BOD lẫn FIN đều ghi audit + meta-log (BR-010).

---

## 2. TABS

Page tabs (`?tab=`), height 40px, indicator 2px `--color-primary`. Header context (kỳ, freshness stream, DataHealthStrip) giữ nguyên khi chuyển tab. Tab chưa mở lazy-load.

| Tab | UI-ID | Nội dung | Hiện với vai |
|-----|-------|----------|--------------|
| T1 — P&L Realtime | `UI-WEB-BI-001-T1` | Mặc định | BOD, FIN_L1 (scope), FIN_L2 |
| T2 — Dashboard phòng ban | `UI-WEB-BI-001-T2` | Dept switcher Sales/Finance/Ops/HR | BOD (4 dept); FIN (Finance) |

### Tab T1 — P&L Realtime (stream ≤5 phút)
- **Mục tiêu:** trả lời trong 1 phút "công ty đang lãi/lỗ ở chiều nào" trên số tươi ≤5 phút, biết chính xác đang tin vào số gì (freshness + nguồn + trạng thái kỳ).
- **Thông tin:** KPI row (Doanh thu DV · Tổng chi · P&L · GM%) + delta liên kỳ; 4 chiều phân tích (dự án/khách/nền tảng TKQC/tháng) roll-up cuộn về tổng; drill-down tới dòng chi (giờ đã duyệt × cost rate version SCD2, outsource, tools, media pass-through tách dòng); **tiền giữ hộ khách tách bạch** ở dải riêng nhãn "nợ phải trả" ở mọi cấp drill-down; dải tách "giờ chờ duyệt + tác động nếu duyệt" (không lẫn vào chi) kèm timestamp giờ chốt 23:59; chi chờ phân loại overhead; GM nhóm dịch vụ vs ngưỡng theo version (deal pilot ngoại lệ có dấu + hạn); nhãn số "tạm tính/chốt" theo trạng thái kỳ; đa tiền tệ quy VND theo snapshot tỷ giá dùng chung + xem gốc ngoại tệ.
- **Components:** KPI StatCard, widget grid 12 cột, MoneyDisplay, FreshnessChip, WarningIndicator (manual/stale/lệch chuẩn), Breadcrumb drill.
- **Actions:** drill-down (Sheet S1), Export (D1), Publish (D2 — CFO), Định nghĩa số này (S3), đổi kỳ, toggle so sánh liên kỳ.
- **States:** widget-level loading/error (§1.5); stale nghiêm trọng → đỏ; manual → nhãn không tắt được.
- **Permissions:** theo §1.6; FIN_L1 thấy P&L phạm vi đối soát của mình; SYS_ADMIN không thấy tab.
- **Quan hệ tab khác:** T2 mở rộng góc KPI đa lĩnh vực;anomaly tài chính tụt GM → chip dẫn sang S24 Alert Center.

### Tab T2 — Dashboard phòng ban (Sales · Finance · Ops · HR)
- **Mục tiêu:** BOD khoan từ KPI tổng xuống đúng phòng đang kéo chỉ số, rồi click thẳng vào worklist của phòng đó — số phải dẫn tới hành động, không dừng ở chart.
- **Thông tin:** dept switcher 4 segment (mặc định theo phòng của user khi có scope); mỗi dept = KPI row 4 ô + 3–5 widget 12 cột theo bảng §1.3; mỗi widget có freshness + owner phòng; widget exception tô theo token (SLA breach `--state-sla-breach`, aging `--state-overdue`); Finance = đủ 6 nhóm bắt buộc REQ-FIN-015 + dải "kiểm tra trước khóa kỳ" (discrepancy tồn = 0? hàng chờ duyệt = 0?); HR chỉ aggregate mức vai/nhóm, không bao giờ lộ lương cá nhân.
- **Components:** SegmentedControl (dept), KPI StatCard, widget grid, DataTable mini (top aging / top ticket SLA đỏ), WarningIndicator, WaitingOnIndicator trên widget "hàng chờ duyệt" (chờ ai bao lâu).
- **Actions:** mỗi widget 1 đích click (bảng §1.3); Export riêng từng widget (D1 với filter kèm theo);Publish (D2) cho báo cáo phòng.
- **States:** lazy-load theo dept; phòng thiếu quyền xem widget → ẩn widget (không disabled); dữ liệu stale → đỏ theo ngưỡng.
- **Permissions:** BOD cả 4; FIN_L1/L2 chỉ Finance (L1 scope đối soát); manager phòng khác xem KPI phòng mình qua workspace riêng — không vào surface này.
- **Quan hệ tab khác:** T1 là nguồn số tài chính chi tiết; S24 nhận exception tụt ngưỡng thành alert.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Export P&L / dashboard | `UI-WEB-BI-001-D1` | Form | [Export] |
| 2 | Publish báo cáo chính thức | `UI-WEB-BI-001-D2` | Confirm + quality gate | [Publish] (CFO) |
| 3 | Đề xuất đổi định nghĩa metric | `UI-WEB-BI-001-D3` | Form | [Đề xuất đổi định nghĩa] trong Sheet S3 |
| 4 | Cấu hình layout cá nhân | `UI-WEB-BI-001-D4` | Form | [⚙ Layout] |

### 3.1. D1 — Export P&L / dashboard
- **Fields:** phạm vi (widget hiện hành / cả tab), kỳ + filter đang áp (readonly preview), định dạng CSV/PDF, mục đích (khóa kỳ / báo cáo / kiểm toán — tùy chọn ghi log).
- **Quy tắc:** file có watermark tên người xuất + thời điểm; mọi export ghi audit + meta-log; rate limit 5 req/user/phút.
- **Actions:** [Xuất] → `POST /core/bi/exports` (API-CORE-039) — async job, toast "đang tạo, sẽ báo khi xong"; bản nháp export được nhưng dán nhãn "bản nháp — không phát hành".
- **States:** processing spinner; xong → toast + link tải; lỗi → toast error không tự đóng.

### 3.2. D2 — Publish báo cáo chính thức (chỉ CFO)
- **Nội dung:** snapshot quality gate tại thời điểm publish (danh sách test per nguồn: not-null/uniqueness/đối soát ví-kế toán ±0,1% + kết quả); nếu ≥1 test fail → nút Publish không render, thay bằng WarningIndicator liệt kê test fail + nguồn lỗi.
- **Actions:** [Publish] khi pass → ghi `quality_gate_snapshot` + audit; số publish mới được mang ra ngoài họp/external.
- **States:** chờ snapshot skeleton; fail → khối đỏ không dismiss.

### 3.3. D3 — Đề xuất đổi định nghĩa metric
- **Fields:** metric (lock theo Sheet S3 đang mở), công thức mới, nguồn, phạm vi áp dụng, lý do (bắt buộc ≥10 ký tự).
- **Quy tắc:** bản ACTIVE giữ nguyên tới khi duyệt; tạo version draft → CHANGE_PENDING; widget tham chiếu hiển thị badge "đang có đề xuất đổi định nghĩa"; CFO phản hồi ≤2 ngày làm việc; từ chối bắt buộc lý do.
- **Actions:** [Gửi duyệt] → `[NEEDS_REVIEW: thiếu endpoint CRUD/đề xuất metric_definition + duyệt version trong api-contract.md]`.

### 3.4. D4 — Cấu hình layout cá nhân
- **Fields:** chọn widget hiển thị/ẩn, thứ tự, filter mặc định (kỳ, dept, khách), mặc định tab mở.
- **Quy tắc:** layout theo user, không đụng số liệu; KHÔNG cho phép thêm widget tham chiếu metric ngoài Metric Catalog (validator chặn với thông báo "metric chưa đăng ký").
- **Actions:** [Lưu] → `[NEEDS_REVIEW: thiếu endpoint lưu layout dashboard theo user — API-CORE-038 chỉ GET registry]`.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Drill-down truy xuất nguồn | `UI-WEB-BI-001-S1` | Panel phải 720px | Click tầng cuối breadcrumb drill |
| 2 | Data Health — nguồn & pipeline | `UI-WEB-BI-001-S2` | Panel phải 480px | Click nguồn ở DataHealthStrip |
| 3 | Định nghĩa metric & version | `UI-WEB-BI-001-S3` | Panel phải 480px | Menu ⋯ widget → "Định nghĩa số này" |

### 4.1. Sheet S1 — Drill-down truy xuất nguồn (720px)
- **Mục tiêu:** từ 1 con số xem được nó đến từ bản ghi nguồn nào — breadcrumb truy xuất (BR: nguồn gốc số liệu).
- **Nội dung:** chuỗi roll-up (tổng → chiều → dự án → dòng chi: giờ × rate + rate version SCD2 hiệu lực tại ngày ghi giờ, outsource, tools); danh sách bản ghi nguồn gộp (timesheet đã duyệt, hóa đơn, statement GW) với mã nghiệp vụ + deep-link về surface nguồn (S15/S10/S7); T3/T4 masked theo vai (SYS_ADMIN không nhận giá trị — service layer chặn); dòng reversal có reason code hiển thị riêng.
- **Components:** definition-list chuỗi chiều, DataTable bản ghi nguồn, MoneyDisplay, badge nguồn `api/manual` per dòng.
- **Actions:** deep-link từng bản ghi nguồn; [Export phần này] (D1).
- **States:** skeleton 3 khối; nguồn degraded → banner manual; PII chạm ngưỡng cá nhân → dừng drill + chú thích "chỉ tới mức rate version ẩn danh".

### 4.2. Sheet S2 — Data Health / ETL pipeline (480px)
- **Nội dung:** per nguồn (GW 7 nền tảng, ví QC, timesheet, sổ kế toán VAS): state machine (ACTIVE/SYNCING/FRESH/STALE/DEGRADED), last watermark + loaded_at + freshness SLA, quality test gần nhất pass/fail, DLQ count, sync event lỗi gần nhất (mã lỗi).
- **Actions:** BOD/CFO: chỉ đọc + [Xem alert liên quan] → S24; SYS_ADMIN: deep-link `/settings` (S27 — workspace Settings, thao tác backfill/replay nằm ở đó, duyệt CTO) và `/admin/audit` khi điều tra.
- **Quy tắc:** không có nút "đặt thành FRESH" thủ công ở bất kỳ vai nào.

### 4.3. Sheet S3 — Định nghĩa metric & version history (480px)
- **Nội dung:** công thức hiệu lực + version + effective_from/to + người duyệt; lịch sử version (báo cáo cũ dùng đúng version theo thời điểm dữ liệu — giải thích được cho kiểm toán); usage 90 ngày (không lượt xem → hàng đợi review nghỉ hưu, CFO duyệt retire); trạng thái DRAFT/PENDING_APPROVAL/ACTIVE/CHANGE_PENDING/RETIRED.
- **Actions:** [Đề xuất đổi định nghĩa] (D3 — FIN/BOD); [Duyệt/Từ chối] chỉ render với BOD_CFO_CTO (CFO).
- **States:** metric RETIRED → chỉ đọc lịch sử; widget tham chiếu metric chưa ACTIVE → không render số.

---

## 5. VIEW MODES

N/A — P&L realtime và dashboard phòng ban đã là 2 page tabs của cùng surface; drill-down/export/health là sheets/dialogs; so sánh liên kỳ là toggle trong T1. Không có mode Create/Edit/Approve kiểu form vì surface read-only tuyệt đối (publish + metric duyệt là dialog có ngữ cảnh, không phải mode).

---

## 6. API ENDPOINTS

Endpoints THẬT từ `phase3-architecture/technical-specs/api-contract.md` (§6.6 BI Serving, §6.8 Ingest Admin, §6.4 audit):

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| KPI row + P&L 4 chiều + liên kỳ (T1) | GET | `/core/bi/pnl` (API-CORE-037) | `?period=&dimension=project\|client\|platform\|month&from=&to=`; freshness SLA stream P&L ≤5 phút (`freshness_sla_minutes: 5`) + snapshot kỳ so sánh + dòng tách timesheet-chưa-duyệt `[NEEDS_REVIEW: chốt FIN/BOD — P3-01 Phụ lục A #10]` |
| Widget KPI theo mart (T2, DataHealth summary) | GET | `/core/bi/marts/:martName` (API-CORE-036) | marts: `sales_funnel, wallet, ar_ap, ops_delivery, people_cost, cs_sla, shop_reference`; filter/sort server-side, pagination, freshness metadata, PDP check |
| Layout + định nghĩa widget (render cả trang) | GET | `/core/bi/dashboards` · `/:id` (API-CORE-038) | Registry + widget map vào marts; render chỉ khi `is_stale=false` (stale hiển thị cảnh báo, không số) |
| Export (D1) | POST | `/core/bi/exports` (API-CORE-039) | Body `{scope, filter_json, format}`; async job + audit truy xuất + watermark; rate limit 5 req/user/phút |
| Freshness từng nguồn (DataHealthStrip) | GET | `/core/bi/freshness` (API-CORE-040) | `last_watermark, loaded_at, sla, is_stale` per mart |
| ETL runs + DLQ + quality gate (Sheet S2) | GET | `/core/ingest/runs` (API-CORE-047) | `?source=&window=`; watermark/LSN, gate pass/fail, DLQ count |
| Quality test snapshot (D2) | GET | `/core/bi/freshness` (API-CORE-040) + runs (API-CORE-047) | Kết quả test per nguồn tại thời điểm publish `[NEEDS_REVIEW: thiếu endpoint quality test result theo thời điểm riêng]` |
| Audit + meta-log xem/export (tuân thủ BR-010) | POST | `/core/audit/events` (API-CORE-028 — internal, service token) | Ghi mọi lượt view/export P&L; meta-log truy xuất BOD |
| Tra cứu audit truy xuất P&L (FIN_L2/CFO) | GET | `/core/audit/events` (API-CORE-029) | Filter actor/object/time; pagination 20/100 |
| Deep-link worklist nguồn (widget click) | — | client routing tới S1/S3/S6/S7/S9/S10/S14/S15/S16/S17/S20/S22 | Filter kèm theo theo bảng §1.3 — không tốn endpoint BI riêng |
| Chuyển tab / dept | — | client routing `/exec/bi?tab=&dept=` | Lazy-load |

**[NEEDS_REVIEW] — endpoint thiếu trong api-contract.md, KHÔNG bịa:**
1. Publish báo cáo chính thức (`report_publication` + quality_gate_snapshot) — DHUB-002 US5/BR-004 (D2).
2. Metric Catalog: CRUD/đề xuất/duyệt `metric_definition` + `metric_version_history` + usage log (D3, S3) — DHUB-002/005.
3. Lưu layout dashboard theo user (`dashboard_widget` write) (D4) — API-CORE-038 hiện chỉ GET.
4. Truy xuất lineage bản ghi nguồn theo con số (Sheet S1) — hiện dùng API-CORE-036 filter + deep-link surface nguồn; chưa có endpoint lineage riêng.
5. Kết quả quality test theo thời điểm (snapshot lịch sử) cho D2.

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-BI-001` | Main Page | Executive BI — W4 dashboard grid, route `/exec/bi` |
| `UI-WEB-BI-001-T1` | Tab | P&L Realtime — stream ≤5 phút, 4 chiều drill, tiền giữ hộ tách bạch, GM vs ngưỡng |
| `UI-WEB-BI-001-T2` | Tab | Dashboard phòng ban — dept switcher Sales/Finance/Ops/HR, 8 KPI chuẩn, 6 nhóm Finance REQ-FIN-015 |
| `UI-WEB-BI-001-D1` | Dialog | Export CSV/PDF (watermark + audit) |
| `UI-WEB-BI-001-D2` | Dialog | Publish báo cáo chính thức (chỉ CFO, quality gate chặn) |
| `UI-WEB-BI-001-D3` | Dialog | Đề xuất đổi định nghĩa metric (CFO duyệt) |
| `UI-WEB-BI-001-D4` | Dialog | Cấu hình layout cá nhân |
| `UI-WEB-BI-001-S1` | Sheet | Drill-down truy xuất nguồn số liệu (720px) |
| `UI-WEB-BI-001-S2` | Sheet | Data Health — ETL pipeline per nguồn (480px) |
| `UI-WEB-BI-001-S3` | Sheet | Định nghĩa metric & version history (480px) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/p-va-l-toan-cong-ty-realtime.md` | Upstream — FEAT-ERP-DHUB-001 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/bi-dashboard-dieu-hanh.md` | Upstream — FEAT-ERP-DHUB-002 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/dashboard-va-bao-cao-tai-chinh-noi-bo.md` | Upstream — FEAT-ERP-DHUB-004 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` | Upstream — FEAT-ERP-DHUB-005 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — §6.6 BI Serving, §6.8 Ingest Admin |
| Design system | `../../../design-system.md` | Upstream — W4, FreshnessChip, MoneyDisplay |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S23 `/exec/bi` |
| Surface liên kết | `./screens-alert-center.md` | S24 — exception tụt ngưỡng thành alert, drill ngược lại từ S24 |


> **Accessibility note (audit 4.8):** chart widget (`role="img"` + `aria-label` mô tả xu hướng), bảng dữ liệu thay thế cho mỗi chart (xem qua SidePanel "Dạng bảng"), phân biệt series bằng màu + pattern/icon + legend text — không chỉ màu.
