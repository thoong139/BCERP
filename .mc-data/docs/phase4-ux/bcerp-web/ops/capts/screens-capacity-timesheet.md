# Screen Group: Capacity & Timesheet (duyệt song song OPS ∥ HR)

Implements: FEAT-ERP-CAPTS-001, FEAT-ERP-CAPTS-002

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `capts` (MOD-CAPACITY-TIMESHEET)
> **Tính năng:** FEAT-ERP-CAPTS-001 (REQ-HR-009 — tầng quy tắc duyệt, góc HR) + FEAT-ERP-CAPTS-002 (REQ-OPS-007 — ghi giờ + capacity, góc OPS)
> **Route:** `/ops/capacity`
> **Main UI-ID:** `UI-WEB-CAPTS-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-CAPTS-001` |
| Route | `/ops/capacity` — menu entry ở CẢ Ops Workspace (badge `{timesheet_cho_duyet}`) + HR Workspace (role view HR, cùng surface — không nhân bản, Navigation ¹) |
| Loại | Worklist duyệt (split view W2) + Capacity board + Dashboard tuân thủ (W4) — 1 surface, 3 role views |
| Workspace | Ops + HR (shared surface theo §2.0.4: "duyệt KHÔNG nhân bản page cho OPS và HR — 1 surface, permission filter") |
| Đối tượng nghiệp vụ | Timesheet tuần (nhân viên × tuần × dự án) + `capacity_week` (derived, read-only từ CORE) + correction + OT + log khẩn cấp |
| Vai trò chính | Lane OPS duyệt lần 1: TL nhóm — vai vận hành của OPS_PLAN (feature spec; API-ERP-068 ghi permission lane "OPS_AM ∥ HR"; approver cấu hình theo cây tổ chức ở CORE) · Lane HR duyệt song song: HR_L1/L2 (góc compliance/nghỉ) |
| Vai trò liên quan | OPS_AM/CONT/DES/EDIT/ADS (người ghi — chỉ xem của mình, nhập chính trên M3) · Manager L4 (duyệt timesheet của TL) · BOD_CEO (duyệt khẩn cấp vượt mốc, duyệt định mức) · SYS_ADMIN (không quyền nghiệp vụ — mask) |
| Workflow stage | `draft → submitted → reviewed (2 chân OPS ∥ HR độc lập) → approved → capacity_computed` (machine-state API-ERP-068); sub-state từ feature spec: `REJECTED` (lý do bắt buộc → sửa + nộp lại), `CORRECTION_PENDING` (TL xác nhận ≤24h → approved); event `timesheet.approved` (payload có `reviewerPair`) phát khi cả 2 chân xong |

**Checklist ngữ cảnh (BƯỚC 0):** (A) Object = timesheet tuần của 1 nhân viên (chốt trước 12:00 thứ Hai) chạy qua 2 chân duyệt độc lập, song song đó là capacity tuần (`capacity_week`) phục vụ gán việc. (B) Primary actors: TL lane OPS (duyệt lần 1 — góc dự án/capacity), HR_L1/L2 lane HR (duyệt song song — góc compliance/nghỉ), nhân viên (chỉ xem của mình). (C) Related: HR-CORE (nghỉ đã duyệt tự trừ capacity — REQ-HR-004), KPI (S22 nhận giờ đã duyệt — 1 trong 3 trụ cột), COMM (trụ cột aggregate cùng cụm), FIN/BOD (giờ APPROVED × Rate Card → P&L, giờ chưa duyệt tách dòng — DC-005), M3 mobile (nhập). (D) Stages: SLA 48h duyệt → quá 72h escalate Manager; correction 24h; capacity check 4h → 8h escalate HR_L2. (E) Cross-module: S20 (rate card), S21 (nghỉ), S22 (KPI), S23 (P&L), M3. (F) Thông tin: utilization băng màu, giờ chờ/đã duyệt, ghi chậm >3 ngày, OT trần, xung đột phân bổ. (G) Quyết định: duyệt/từ chối từng chân, bulk, xác nhận correction, duyệt OT, duyệt gán vùng vàng, log khẩn cấp. (H) Actions: transitions machine-state, tất cả approver ≠ người ghi (cấm tự duyệt — 403). (I) Exceptions: quá SLA 48/72h, vàng >90% / đỏ ≥100%, vượt 110%/5 ngày → BOD, OT vượt trần → HR_L2, correction quá 24h. (J) 1 surface `/ops/capacity` — KHÔNG tách page theo role.

---

## 1. TRANG CHÍNH

### 1.1. Layout — split view W2 (queue 40% trái + detail 60% phải), tab bar trên cùng

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: Ops > Capacity & Timesheet      Role view: [OPS — TL]   Tuần: ◀ T37/2026 ▶   │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ Tabs: [Duyệt Timesheet ·12] [Capacity Board] [Correction & OT ·3] [Tuân thủ & Feed]      │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ ── TAB T1: DUYỆT TIMESHEET ─────────────────────────────────────────────────────────────  │
│ (Chờ chân tôi ·9×) (Quá 48h ·2×) (Chưa đủ 2 chân ·4×) (Ghi chậm ·3×)   [Tìm nhanh…][Lọc▾]│
│ ┌──────────────────────────────┬─────────────────────────────────────────────────────┐   │
│ │ ☐ NV · Tuần · Giờ · OPS·HR   │ Tuần T36 · Trần B. (OPS_CONT) · Badge [Đang duyệt]  │   │
│ │ ☑ Trần B.  T36 42h ✓OPS ○HR  │ SLA 48h: ⏱ còn 31h — nộp 11/09 16:00                │   │
│ │ ☑ Lê C.    T36 40h ○OPS ✓HR⚠ │ 2 chân: [OPS: TL Nguyễn V. — chờ] [HR: ✓ 12/09]     │   │
│ │ ▸ Phạm D.  T36 46h ⏱ quá 48h │ ⚠ WarningIndicator: Ghi chậm 4 ngày (T36) — cần TL  │   │
│ │ ▸ Hoàng E. T36 38h ○ ○ [mình]│   nhắc; quá 72h escalate Manager. Hạn: 14/09 16:00  │   │
│ │ …                            │ Bảng dòng: Dự án · Ngày · Giờ · Nhãn (CB/INB)       │   │
│ │                              │  · Dự án ABC  09/09  8h  Client Billable            │   │
│ │                              │  · Nội bộ     10/09  4h  Internal Non-billable      │   │
│ │                              │ OT tuần: 6h (trần 8h — TL duyệt) · Nghỉ đã duyệt: 0h│   │
│ │ Bulk: [Đã chọn 2] [Duyệt    │ [Duyệt (chân OPS)] [Từ chối…] [Yêu cầu correction…] │   │
│ │ hàng loạt] [Từ chối…] [⋯]   │ Timeline: nộp 11/09 16:00 → nhắc SLA 13/09 16:00    │   │
│ │ Phân trang ← 1 2 →  20/50/100│                                                     │   │
│ └──────────────────────────────┴─────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

Legend 2 chân (cột OPS·HR): `✓` đã duyệt chân đó · `○` chờ · `[mình]` = timesheet của chính người đang đăng nhập — dòng này bị lọc khỏi bulk và nút duyệt ẩn (cấm tự duyệt). Trên mobile <768px: queue → card, bảng dòng chi tiết không render (báo "xem trên web"), duyệt qua M3/M6 mobile cho manager.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable compact | sticky header, row 32px, bulk-selection, sort click header, pagination server-side 20/50/100 | Pattern W1 cho queue duyệt |
| Quick filter chips | tháo từng chip; mặc định theo role: OPS = "Chờ chân tôi" · "Quá 48h"; HR = "Chưa đủ 2 chân" · "OT chờ duyệt" | Chip "Quá 48h" `--state-sla-breach` tự nhảy đầu queue |
| Dual-slot reviewer | 2 ô trạng thái chân OPS / chân HR (dạng ApprovalCard dual-approval) — mỗi ô: vai + tên + thời điểm | Map `reviewerPair` từ event `timesheet.approved`; "song song" = 2 slot độc lập, không chặn nhau |
| StatusBadge | 1 badge/hàng; quá SLA gắn `--state-sla-breach` + icon chuông | Token §1 design-system |
| WaitingOnIndicator | chip trong row + khối trong header detail ("chờ chân HR — Lê C. (HR_L1) · 6h") | Màu theo ngưỡng 48h: ≥50% → sla-warning, quá → sla-breach |
| WarningIndicator | banner trong detail: ghi chậm >3 ngày, escalate 72h, đỏ ≥100%, OT vượt trần | Bắt buộc 3 phần: chuyện gì — ai làm gì — hạn còn lại |
| Tabs | page tabs, count-tab cho queue + correction | T2/T3/T4 lazy-load |
| ProgressTracker chip-line | draft → submitted → reviewed → approved → capacity_computed | Hiển thị stage hiện tại + ai đang giữ |

### 1.3. Cột queue (nửa trái)

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Nhân viên | `timesheet_entry.user_id` | Avatar + tên (link S20 khi có quyền) | Có | 160px |
| Tuần | `week_key` | Tnn/yyyy, mặc định tuần hiện tại | Có | 90px |
| Tổng giờ | SUM(hours) | Number, tabular-nums, right-align | Có | 80px |
| Chân OPS | reviewer slot | ✓/○ + thời điểm hoặc WaitingOn | Không | 110px |
| Chân HR | reviewer slot | ✓/○ + thời điểm hoặc WaitingOn | Không | 110px |
| Trạng thái | `status` | Badge (bảng dưới) | Có | 130px |
| SLA 48h | `sla_deadline` | Countdown / "—" khi đã xong | Có (breach đầu) | 110px |
| Exception | ghi chậm / OT chờ / correction | Icon WarningIndicator inline + tooltip | Không | auto |

**Badge màu:** Nháp `--state-draft` · Chờ duyệt `--state-pending` (quá 48h → `--state-sla-breach`) · 1/2 chân xong (reviewed) `--state-info` · Đã duyệt `--state-approved` · Bị từ chối `--state-rejected` · Chờ correction `--state-sla-warning` · Đã tính capacity (capacity_computed) `--state-approved` + icon gear.

**Trạng thái hệ thống:** loading = skeleton 10 hàng (queue) / skeleton pane (detail); empty theo role — OPS: "Không có tuần nào chờ chân của bạn"; HR: "Không có tuần chờ duyệt HR"; nhân viên: "Chưa có timesheet nào — nhập trên Timesheet của tôi (M3)"; error = hàng lỗi + retry. Mọi state render machine-state từ CORE — WEB không lưu state cục bộ.

### 1.4. Hành động chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Chọn hàng trái | Mở detail pane (S1) | Header context (tuần + NV + 2 slot) giữ nguyên khi chuyển tab |
| "Duyệt (chân của tôi)" | POST transition `review` | Chỉ 1 chân của người đăng nhập; approver ≠ người ghi (ẩn nút + API 403 + audit khi vi phạm) |
| "Từ chối…" | Dialog D2 | REJECTED — lý do bắt buộc ≥10 ký tự; người ghi sửa qua dòng mới/correction rồi nộp lại |
| Chọn nhiều hàng | Bulk bar: Duyệt hàng loạt (D1) / Từ chối hàng loạt (D1 — lý do áp chung + ghi chú từng dòng) | Lặp transition từng id; row `[mình]` tự loại khỏi selection |
| "Yêu cầu correction…" | Dialog D3 (người ghi) → D4 (TL xác nhận ≤24h) | Bản gốc giữ nguyên, audit bất biến; chênh lệch ghi bút toán điều chỉnh kỳ sau |
| Chuyển tuần ◀ ▶ | Đổi `week_key` toàn surface | Queue + board + dashboard cùng tuần |
| Click chip WaitingOn | Dialog D8 | Nhắc người đang giữ chân duyệt |

### 1.5. Phân Quyền (hide khi không có quyền — PEP; approver từng chân cấu hình theo cây tổ chức ở CORE)

| Thành phần | OPS nhân sự (AM/CONT/DES/EDIT/ADS) | OPS_PLAN (TL) lane OPS | Manager L4 | HR_L1 | HR_L2 | BOD_CEO | SYS_ADMIN |
|-----------|----|----|----|----|----|----|----|
| Xem queue duyệt | ❌ (chỉ của mình — M3 view) | ✅ nhóm mình | ✅ (timesheet của TL) | ✅ toàn công ty | ✅ toàn công ty | ✅ read-only | ❌ (mask nghiệp vụ) |
| Duyệt/từ chối chân OPS (lần 1, SLA 48h) | ❌ | ✅ (≠ người ghi) | ✅ (duyệt TL) | ❌ | ❌ | ❌ | ❌ |
| Duyệt/từ chối chân HR (song song — compliance/nghỉ) | ❌ | ❌ | ❌ | ✅ (không thấy cost — REQ-HR-010) | ✅ | ❌ | ❌ |
| Bulk duyệt/từ chối | ❌ | ✅ (phạm vi nhóm) | ✅ | ✅ (chân HR) | ✅ | ❌ | ❌ |
| Xác nhận correction (≤24h) | ❌ | ✅ | ✅ (của TL) | ❌ | ❌ | ❌ | ❌ |
| Duyệt OT trong trần 8h/tuần | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt OT vượt trần / retro (24h) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Xem cost cá nhân (giờ × rate) | của mình | nhóm mình | ✅ | ❌ (mask) | ✅ | ✅ | ❌ (mask) |
| Duyệt gán vùng vàng / log khẩn cấp | đề xuất log | ✅ duyệt | ❌ | ❌ | ❌ | ✅ (vượt 5 ngày) | ❌ |
| Sửa nội dung giờ đã ghi / sửa định mức | ❌ | ❌ | ❌ | ❌ | đề xuất định mức → BOD | ✅ duyệt định mức | ❌ |

Ghi chú ranh giới: lane prompt + API-ERP-068 + $WORKFLOW_MAP xác nhận thiết kế **duyệt song song 2 chân OPS ∥ HR** (1 queue, permission quyết định ai thấy gì); feature spec FEAT-ERP-CAPTS-001 §4 mô tả duyệt lần 1 thuần TL — RBAC CORE cấu hình approver từng chân theo cây tổ chức, cả 2 chân cùng bắt buộc approver ≠ người ghi. Delegate duyệt của TL `[KXN]` chưa chốt — KHÔNG xây UI delegate; khi TL vắng, chỉ chạy escalate 48h/72h về Manager (nếu không xác định Manager → HR_L2 điều phối tạm, có log).

---

## 2. TABS

Global context (tuần đang chọn + role view) giữ nguyên khi chuyển tab; T2/T3/T4 lazy-load.

### Tab T1 — Duyệt Timesheet `UI-WEB-CAPTS-001-T1`
- **Mục tiêu:** xử lý hết hàng đợi tuần trong SLA 48h, đủ 2 chân OPS ∥ HR — giờ APPROVED mới được tính capacity và vào P&L (BR-002).
- **Thông tin:** queue tuần theo nhân viên (mô tả §1); KPI chips đầu tab: Chờ duyệt · Quá 48h · Giờ chờ (148h) · Giờ đã duyệt tuần (962h ✓).
- **Components/actions/states:** theo §1.2–1.5.
- **Quan hệ tab khác:** từ chối → người ghi sửa trên M3 rồi nộp lại (queue đếm lại); correction mở từ detail → xử lý ở T3; sau `approved` → job CORE tính capacity → dòng biến khỏi queue, xuất hiện ở T2.

### Tab T2 — Capacity Board `UI-WEB-CAPTS-001-T2`
- **Mục tiêu:** thấy phân bổ nhân sự theo dự án/tuần, utilization băng màu và xung đột phân bổ TRƯỚC khi gán việc; xử lý gán vùng vàng và log khẩn cấp.
- **Thông tin:** chọn tuần (dòng thời gian ◀ T35 · **T36** · T37 ▶, nhóm theo team). Bảng chính: Nhân sự | Dự án đang gán (chip: tên + giờ/tuần) | Giờ gán / khả dụng (40h − nghỉ đã duyệt − lễ) | Utilization % + băng màu | Xung đột | OT | Ghi chậm. Băng màu (từ CORE — WEB read-only): **<70% dưới tải** (`--state-info`, cảnh báo TL "cạn việc") · **70–90% xanh** nhận gán tự do · **>90% vàng** dừng gán tự động — gán mới vào `PENDING_TL` (`--state-sla-warning`) · **≥100% đỏ** chặn cứng gán vượt (`--state-rejected` + icon chặn) — buộc dịch deadline / đổi người / duyệt OT. Panel phải: hàng đợi "Gán chờ TL duyệt (PENDING_TL — SLA capacity check 4h, quá 8h escalate HR_L2)" + "Log khẩn cấp 110%" (ai, lý do, ngày thứ mấy/5, hết hạn khi nào; quá 5 ngày LV → chờ BOD duyệt — nút chỉ hiện cho BOD_CEO).
- **Components:** DataTable + cell băng màu kèm % + chữ (color-blind safe); ApprovalCard cho duyệt gán vàng (D7); WarningIndicator banner cho đỏ/xung đột; AssigneePicker (gán task — lọc theo thành viên dự án + chạy capacity check bắt buộc).
- **Actions:** duyệt gán vùng vàng (D7); tạo log khẩn cấp vượt 110% (D6 — TL/AM đề xuất kèm lý do); xem xung đột (S3); drill-down nhân sự (S2). Không có nút sửa utilization — `capacity_week` derived, read-only.
- **States:** lazy-load; empty "Chưa có phân bổ trong tuần này"; error retry từng khối; results hiển thị mã lỗi băng màu khi CORE chặn (đỏ) — không tự đoán phía UI.
- **Quan hệ:** nghỉ mới duyệt (S21) → capacity khả dụng tự tăng → assignment treo chạy lại check (hiển thị badge "re-check"); assignment treo quá SLA → escalate TL 4h / HR_L2 8h (WaitingOn + link Alert Center S24 khi đã escalation).

### Tab T3 — Correction & OT `UI-WEB-CAPTS-001-T3`
- **Mục tiêu:** xử lý 2 loại ngoại lệ chờ quyết định người: correction ghi sai (TL xác nhận ≤24h) và đăng ký OT (TL trong trần / HR_L2 vượt trần-retro).
- **Thông tin:** 2 khối. (1) **Correction**: bảng — nhân viên, tuần, old → new (giờ/nhãn, diff highlight), lý do, requested lúc nào, SLA còn lại (24h), trạng thái; bản gốc giữ nguyên + audit "ai — khi nào — sửa gì — lý do"; correction sau khi tuần đã vào P&L hiển thị nhãn "bút toán điều chỉnh kỳ sau" (không sửa dữ liệu đã hạch toán). (2) **OT**: bảng — nhân viên, tuần, giờ, loại (trước/retro), lý do, mức duyệt cần: trong trần 8h/tuần → TL (trước khi thực hiện; retro ≤24h); vượt trần hoặc retro quá hạn → HR_L2 (24h); đồng hồ context: tổng chuẩn + OT ≤48h/tuần, trần năm 200h còn lại (đếm theo nhân viên).
- **Components:** 2 DataTable + ApprovalCard (D4/D5); diff view old/new; WarningIndicator khi sắp quá SLA 24h.
- **Actions:** xác nhận correction (D4 — TL); từ chối correction (lý do); duyệt OT (D5); OT chưa duyệt hiển thị trạng thái riêng, KHÔNG cộng vào giờ APPROVED.
- **States:** lazy-load; empty "Không có correction/OT chờ xử lý"; permission ẩn khối không đúng vai (HR_L1 thấy OT queue read-only; TL không thấy khối vượt trần).
- **Quan hệ:** correction làm capacity tuần thay đổi → chạy lại capacity check (badge ở T2); OT duyệt xong cộng vào utilization tuần đó.

### Tab T4 — Tuân thủ & Feed `UI-WEB-CAPTS-001-T4`
- **Mục tiêu:** dashboard trạng thái "giờ chờ duyệt / giờ đã duyệt" tách bạch khỏi cost, giám sát SLA duyệt và nhịp ghi — đầu vào cho KPI (S22) và P&L (S23).
- **Thông tin (W4 — mọi widget click ra được worklist):** hàng KPI 4 ô: % chốt tuần đúng hạn (trước 12:00 T2) · Giờ chờ duyệt (tách khỏi đã duyệt) · SLA duyệt (số tuần quá 48h / đã escalate 72h) · Tỷ lệ billable thực tế tháng theo bậc vs mục tiêu (L1 ≥80% → L5 20–30%, % giờ chưa duyệt hiển thị cạnh con số — BR-011 FEAT-ERP-CAPTS-001). Widget: Nhóm ghi chậm >3 ngày (badge, click → queue đã lọc) · Escalation capacity quá 8h (HR_L2 — đề xuất mở requisition REQ-HR-001, link S20) · **Cross-module feed**: KPI — trạng thái aggregate kỳ (giờ đã duyệt đã chảy vào trụ cột CAPTS của S22 — link S22, GET kpi-periods); COMM — ghi chú cross-module: commission là trụ cột aggregate song song (dữ liệu không sửa tại đây, chỉ trạng thái + link); P&L — dòng tách "timesheet-chưa-duyệt" trên `/core/bi/pnl` (chỉ BOD/FIN thấy — link S23).
- **Components:** KPI cards + delta; DataTable top ghi chậm; Timeline escalation; panel feed (không card lồng card).
- **Actions:** chỉ đọc + jump-to-worklist; HR_L2 thấy thêm nút "Đề xuất điều chỉnh định mức" (route về quy trình HR_L2 → BOD, chu kỳ năm, effective-dated — outside this surface).
- **States:** lazy-load; HR_L1 thấy toàn bộ tab KHÔNG có cột cost (mask REQ-HR-010, có ghi chú "cost đã ẩn theo quyền"); empty khi chưa có dữ liệu tuần nào chốt.
- **Quan hệ:** S22 KPI (feed đầu vào), S23 BI (P&L), S24 Alert Center (escalation đã vượt).

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Duyệt / Từ chối hàng loạt | `UI-WEB-CAPTS-001-D1` | Confirm + form lý do | Bulk bar khi chọn ≥1 hàng |
| 2 | Từ chối 1 tuần | `UI-WEB-CAPTS-001-D2` | Form lý do | Nhấn "Từ chối…" trên 1 hàng |
| 3 | Yêu cầu correction (người ghi) | `UI-WEB-CAPTS-001-D3` | Form | Nhấn "Yêu cầu correction…" trên tuần của mình |
| 4 | Xác nhận correction (TL) | `UI-WEB-CAPTS-001-D4` | ApprovalCard + diff | Nhấn 1 correction ở T3 |
| 5 | Duyệt OT | `UI-WEB-CAPTS-001-D5` | ApprovalCard | Nhấn 1 dòng OT ở T3 |
| 6 | Log khẩn cấp vượt 110% | `UI-WEB-CAPTS-001-D6` | Form (+duyệt BOD) | T2 — "Tạo log khẩn cấp"; BOD duyệt vượt mốc 5 ngày |
| 7 | Duyệt gán vùng vàng | `UI-WEB-CAPTS-001-D7` | ApprovalCard | T2 — hàng đợi PENDING_TL |
| 8 | Nhắc người đang chờ | `UI-WEB-CAPTS-001-D8` | Modal nhắn | Click WaitingOnIndicator |

### 3.1. D1 — Duyệt / Từ chối hàng loạt
Tóm tắt: số tuần đã chọn, tổng giờ, chân sẽ duyệt (theo role đăng nhập). Duyệt: confirm 1 bước + toast; tự loại row `[mình]` (cấm tự duyệt — nếu selection chỉ còn row của mình, nút vô hiệu kèm lý do). Từ chối: lý do chung ≥10 ký tự BẮT BUỘC + tùy chọn ghi chú riêng từng dòng. Processing: spinner + khóa nút chống double-submit; kết quả per-item accepted/rejected + lý do (khi CORE chặn — ví dụ tuần đã khóa). Không có dialog khi chọn 1 hàng — dùng S1.

### 3.2. D2 — Từ chối 1 tuần
Lý do bắt buộc ≥10 ký tự (gợi ý mẫu: sai nhãn billable, thiếu giờ, trùng ngày). Xác nhận → transition REJECTED; người ghi thấy banner lý do trên M3; sửa qua dòng mới/correction → nộp lại → queue đếm lại. Audit log ghi approver + lý do.

### 3.3. D3 — Yêu cầu correction (người ghi, tuần của mình)
Fields: dòng (select từ tuần của mình), giá trị cũ (read-only), giờ mới + nhãn mới (validation cặp project type × nhãn — BR-003), lý do bắt buộc. Lưu → tạo `CORRECTION_PENDING`, bản gốc + audit bất biến; TL xác nhận trong 24h.

### 3.4. D4 — Xác nhận correction (TL, ≤24h)
Diff old → new highlight; lý do người ghi; SLA còn lại; audit hint "bản gốc giữ nguyên — chênh lệch tạo bút toán điều chỉnh kỳ sau nếu tuần đã allocate". 2 nút **Xác nhận** (primary) / **Không chấp nhận** (outline `--color-error`, lý do bắt buộc). Sau xác nhận → APPROVED + job tính lại capacity.

### 3.5. D5 — Duyệt OT
Context: giờ đăng ký, loại (trước/retro), lý do, trần tuần còn lại (8h), tổng chuẩn+OT tuần (≤48h — chặn cứng khi vượt), trần năm còn lại (200h). TL duyệt trong trần; vượt trần/retro quá hạn → chỉ HR_L2 thấy nút Duyệt (24h SLA), TL thấy WaitingOn "chờ HR_L2". OT chưa duyệt không tính công/giờ.

### 3.6. D6 — Log khẩn cấp vượt 110%
Tạo (TL/AM đề xuất): nhân sự, tuần, lý do bắt buộc (VD die account ngoài giờ), utilization dự kiến, ngày liên tục (≤5 LV). Trong mốc 110%/5 ngày → TL duyệt gán được ngay (log hiển thị trên T2). Quá mốc → chặn chờ **BOD_CEO duyệt** (nút duyệt chỉ hiện cho BOD — read-only với vai khác); hết hạn `expires_at` hiển thị rõ.

### 3.7. D7 — Duyệt gán vùng vàng (PENDING_TL)
ApprovalCard: task + dự án, người nhận, utilization hiện tại (>90% vàng), SLA capacity check còn lại (4h — quá 8h escalate HR_L2), tùy chọn dịch deadline/đổi người. **Duyệt gán** (primary) / **Từ chối** (lý do bắt buộc). Băng đỏ ≥100% không mở dialog — hiển thị block gợi ý 3 lối thoát (dịch deadline / đổi người / duyệt OT D5).

### 3.8. D8 — Nhắc người đang chờ
Người nhận từ WaitingOn chip (VD: "chờ chân HR — Lê C. · 6h"), tin nhắn nhanh qua hạ tầng notification chung (SLANOT — global drawer); lịch sử nhắc vào activity feed của tuần.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Chi tiết tuần timesheet | `UI-WEB-CAPTS-001-S1` | Right 720px | Click 1 hàng queue (T1) — hoặc mở sẵn làm detail pane |
| 2 | Hồ sơ capacity nhân sự | `UI-WEB-CAPTS-001-S2` | Right 480px | Click 1 nhân sự ở T2 |
| 3 | Xung đột phân bổ | `UI-WEB-CAPTS-001-S3` | Right 480px | Click icon xung đột ở T2 |

### 4.1. S1 — Chi tiết tuần timesheet
Header: nhân viên + tuần + StatusBadge + SLA countdown. Nội dung: bảng dòng chi tiết (dự án · task · ngày · giờ · nhãn CB/INB — nhãn không sửa sau ghi), 2 slot reviewer (chân OPS / chân HR — tên + thời điểm + chữ ký audit), OT tuần, nghỉ đã duyệt trừ, ProgressTracker stage machine-state, Timeline (nộp → nhắc SLA → escalate → duyệt từng chân). Footer sticky theo quyền: [Duyệt (chân của tôi)] [Từ chối…] [Yêu cầu correction…] (người ghi — xem của mình) — Esc đóng, trả focus về hàng.

### 4.2. S2 — Hồ sơ capacity nhân sự
`capacity_week` các tuần gần nhất (băng màu + %), giờ khả dụng = 40h − nghỉ đã duyệt − lễ, assignment đang gán theo dự án, assignment treo PENDING_TL/BLOCKED, OT đã duyệt trong trần, log khẩn cấp còn hiệu lực. Action theo quyền: duyệt gán vàng (D7), tạo log khẩn cấp (D6). Cost chỉ hiện cho role được phép (HR_L1 mask — REQ-HR-010).

### 4.3. S3 — Xung đột phân bổ
Danh sách nguồn xung đột của 1 nhân sự/tuần: tổng gán vượt khả dụng (số giờ thiếu), gán trùng khung giữa 2 dự án, assignment treo quá SLA check, re-check do nghỉ duyệt retro. Mỗi dòng gợi ý đúng 3 lối thoát nghiệp vụ: dịch deadline · đổi người (AssigneePicker + capacity check) · duyệt OT (D5) — khẩn cấp thì D6. Không sửa trực tiếp utilization tại đây.

---

## 5. VIEW MODES

1 surface `/ops/capacity` — role views theo role đăng nhập (§2.0.5: "duyệt KHÔNG nhân bản page cho OPS và HR"); các mode là cùng bộ tabs, khác nhấn mạnh + nút hiển thị.

| Mode | UI-ID | Hiện khi nào | Khác biệt |
|------|-------|--------------|-----------|
| OPS view — duyệt lần 1 | `UI-WEB-CAPTS-001-M1` | Role OPS (TL/OPS_PLAN; Manager L4 biến thể duyệt TL) | Góc dự án/capacity: mặc định T1 + T2; thấy cost nhóm; bulk duyệt chân OPS; duyệt gán vàng + log khẩn cấp; chip "Chờ chân tôi", "Quá 48h" |
| HR view — duyệt song song | `UI-WEB-CAPTS-001-M2` | Role HR_L1/L2 | Góc compliance/nghỉ: duyệt chân HR (nghỉ đã duyệt, nhãn, tuân thủ nhịp ghi), dashboard T4 nổi bật; HR_L1 mask cost vĩnh viễn; duyệt OT vượt trần (L2); chip "Chưa đủ 2 chân", "OT chờ duyệt" |
| Nhân viên view — của tôi | `UI-WEB-CAPTS-001-M3` | OPS_AM/CONT/DES/EDIT/ADS (+L5/BOD ghi theo dự án) | Chỉ xem timesheet của mình (read-only queue cá nhân + trạng thái 2 chân + lý do từ chối); CTA "Nhập trên Timesheet của tôi (M3)"; L5/BOD: form ẩn bắt buộc task (BR-012); KHÔNG thấy queue nhóm, KHÔNG thấy tab T2/T4 |
| Read-only oversight | — (không phải mode riêng) | BOD_CEO, SYS_ADMIN (mask) | Toàn bộ action ẩn trừ duyệt khẩn cấp vượt mốc (BOD, D6) + duyệt định mức (nơi khác); SYS_ADMIN mask dữ liệu nghiệp vụ |

---

## 6. API ENDPOINTS

> Endpoint thật từ `api-contract.md` §6.5 (COMP-ERP-005) + các mục liên quan. WEB render machine-state từ CORE — không lưu state cục bộ. Pagination server-side 20/50/100 cho mọi list.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải queue duyệt tuần (T1) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/timesheets]` | Cần filter `week_key,status,approver_lane,user_id` + `sort,page,limit`; API-ERP-068 hiện chỉ khai POST + transitions |
| Ghi dòng timesheet (web fallback; nhập chính trên M3) | POST | `/api/v1/erp/timesheets` | Body: project_id, task_id, week_key, work_date, hours, `billing_label` bắt buộc (BR-001) — API-ERP-068 |
| Duyệt / từ chối / correction transitions (D1–D4) | POST | `/api/v1/erp/timesheets/{id}/transitions` | Machine: draft→submitted→reviewed→approved (2 chân độc lập)→capacity_computed; tự duyệt → 403 + audit — API-ERP-068; bulk = lặp per-id (idempotent) |
| Capacity board (T2) | GET | `/api/v1/erp/capacity` | Params: `week_key,team_id,user_id`; trả utilization % + band (vàng 90%, đỏ 100%) — API-ERP-069 |
| Timesheet của mình (M3 nhân viên view) | GET | `/api/v1/erp/ess/me` | Self-service: công, phép, timesheet — API-ERP-066 |
| SLA timer duyệt 48h/72h + capacity check 4h/8h | GET | `/api/v1/erp/sla-timers` | `object_type=timesheet_week|capacity_check` — API-ERP-073 (scope theo permission) |
| Log escalation / nhắc (D8) | GET | `/api/v1/erp/notifications` | Log dispatch đa kênh, role sở hữu object — API-ERP-074 |
| Job capacity (registry, read-only T4) | GET | `/api/v1/erp/jobs` | Xem run history job capacity/aggregate — API-ERP-075 |
| Feed KPI (T4) | GET | `/api/v1/erp/kpi-periods/{id}` | Trạng thái aggregate trụ cột CAPTS — API-ERP-070 (read); link S22 |
| P&L tách dòng giờ-chưa-duyệt (T4, BOD/FIN) | GET | `/core/bi/pnl` | Dòng tách timesheet-chưa-duyệt — API-CORE-037; link S23 |
| Danh mục nhân sự/team (avatar, tên, bậc) | GET | `/api/v1/erp/employees[/{id}]` | Scope theo quyền; cost masked thiếu quyền `PII_ACCESS_DENIED` — API-ERP-062 |

**[NEEDS_REVIEW] các điểm thiếu endpoint (KHÔNG bịa — cần bổ sung vào api-contract):**
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/timesheets — hàng đợi duyệt + list tuần có filter/sort/pagination server-side; API-ERP-068 chỉ có POST + /{id}/transitions]`
- `[NEEDS_REVIEW: thiếu endpoint correction (entity timesheet_correction) — tạo yêu cầu (D3) + TL xác nhận ≤24h (D4); T3 khối 1 không có API thật]`
- `[NEEDS_REVIEW: thiếu endpoint OT request + duyệt 2 tầng (TL trần 8h / HR_L2 vượt trần-retro 24h, trần năm 200h) — POST /api/v1/erp/attendance chỉ ghi nhận overtime, không phải luồng duyệt; D5 cần nó]`
- `[NEEDS_REVIEW: thiếu endpoint assignment/capacity-check (duyệt gán vùng vàng PENDING_TL, BLOCKED, log khẩn cấp emergency_override_log + duyệt BOD) — GET /api/v1/erp/capacity chỉ đọc; D6/D7 + S3 cần nó]`
- `[NEEDS_REVIEW: thiếu endpoint đọc/đề xuất định mức giờ-billable theo bậc (capacity_policy_version — HR_L2 đề xuất → BOD duyệt, effective-dated); có thể nằm trong /core/policies (API-CORE-020) nhưng chưa có shape riêng]`
- `[NEEDS_REVIEW: thiếu endpoint bulk duyệt (batch transitions 1 call) — hiện giả định lặp per-id; và endpoint báo cáo tỷ lệ billable tháng theo bậc (T4 widget, BR-011)]`

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-CAPTS-001` | Main Page | Capacity & Timesheet — 1 surface duyệt song song OPS ∥ HR, route `/ops/capacity`, split view + tab bar |
| `UI-WEB-CAPTS-001-T1` | Tab | Duyệt Timesheet — queue tuần, 2 slot reviewer, bulk, SLA 48h/72h |
| `UI-WEB-CAPTS-001-T2` | Tab | Capacity Board — phân bổ theo dự án/tuần, utilization băng màu, xung đột, PENDING_TL, log 110% |
| `UI-WEB-CAPTS-001-T3` | Tab | Correction & OT — xác nhận correction 24h, duyệt OT 2 tầng TL/HR_L2 |
| `UI-WEB-CAPTS-001-T4` | Tab | Tuân thủ & Feed — giờ chờ/đã duyệt, ghi chậm, SLA duyệt, billable %, feed KPI + COMM + P&L |
| `UI-WEB-CAPTS-001-D1` | Dialog | Duyệt / Từ chối hàng loạt (lý do bắt buộc khi từ chối) |
| `UI-WEB-CAPTS-001-D2` | Dialog | Từ chối 1 tuần (lý do ≥10 ký tự) |
| `UI-WEB-CAPTS-001-D3` | Dialog | Yêu cầu correction (người ghi — old/new + lý do) |
| `UI-WEB-CAPTS-001-D4` | Dialog | Xác nhận correction (TL — ApprovalCard + diff, ≤24h) |
| `UI-WEB-CAPTS-001-D5` | Dialog | Duyệt OT (TL trong trần / HR_L2 vượt trần-retro) |
| `UI-WEB-CAPTS-001-D6` | Dialog | Log khẩn cấp vượt 110% (+ duyệt BOD quá 5 ngày LV) |
| `UI-WEB-CAPTS-001-D7` | Dialog | Duyệt gán vùng vàng PENDING_TL (ApprovalCard, SLA 4h) |
| `UI-WEB-CAPTS-001-D8` | Dialog | Nhắc người đang chờ (từ WaitingOnIndicator) |
| `UI-WEB-CAPTS-001-S1` | Sheet | Chi tiết tuần timesheet — dòng, 2 slot, timeline (right 720px) |
| `UI-WEB-CAPTS-001-S2` | Sheet | Hồ sơ capacity nhân sự — capacity_week, assignment, OT (right 480px) |
| `UI-WEB-CAPTS-001-S3` | Sheet | Xung đột phân bổ + 3 lối thoát (right 480px) |
| `UI-WEB-CAPTS-001-M1` | View Mode | OPS view — duyệt lần 1 góc dự án/capacity (TL; Manager L4 duyệt TL) |
| `UI-WEB-CAPTS-001-M2` | View Mode | HR view — duyệt song song góc compliance/nghỉ (L1 mask cost) |
| `UI-WEB-CAPTS-001-M3` | View Mode | Nhân viên view — chỉ xem của mình, CTA nhập trên M3 |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ (góc OPS) | `../../../../phase2-features/bcerp-web/capacity-timesheet/capacity-va-timesheet.md` | FEAT-ERP-CAPTS-002 |
| Tính năng nghiệp vụ (góc HR) | `../../../../phase2-features/bcerp-web/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md` | FEAT-ERP-CAPTS-001 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.5 COMP-ERP-005 — API-ERP-066/068/069 |
| Design system | `../../../design-system.md` | Tokens + ApprovalCard dual-approval + W1/W2/W4 |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | S15 — menu ở cả Ops + HR, không nhân bản |
| Mobile counterpart | `../../../mobile-internal` | M3 Timesheet của tôi (nhập) · M6 duyệt nhanh `[NEEDS_REVIEW]` |
