# Screen Group: Leave Management (duyệt phân cấp + số dư tự động + lịch team)

Implements: FEAT-ERP-HRCORE-004 (nghỉ phép: số dư tự động & duyệt phân cấp — chính), FEAT-ERP-HRCORE-003 (nghiệp vụ nối: đơn đã duyệt tự cập nhật chấm công)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `hr-core` (MOD-HR-CORE)
> **Tính năng:** FEAT-ERP-HRCORE-004/003 — bản fan-out cho touchpoint SYS-BCERP-WEB (registry giữ FEAT-ID canonical `FEAT-ERP-HRCORE-*`; không có tiền tố `FEAT-WEB-*` trong req-registry)
> **Route:** `/hr/leave`
> **Main UI-ID:** `UI-WEB-LEAVE-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-LEAVE-001` |
| Route | `/hr/leave` — HR Workspace, badge `{phep_cho_duyet}` (Navigation S21); quick action "Duyệt phép" của workspace trỏ về đây |
| Loại | Worklist duyệt (Pattern W1 + bulk) + tab bar 3 tab: T1 Hàng đợi duyệt · T2 Lịch nghỉ team · T3 Số dư & tuân thủ §8 |
| Workspace | HR — TL duyệt cấp 1 ngay tại đây qua role view (không nhân bản surface); nhân viên lập đơn qua form web (ESS) hoặc M4 mobile |
| Đối tượng nghiệp vụ | LeaveRequest (routing `PENDING_TL`/`PENDING_HR`) + LeaveBalance (tích lũy tự động 12 ngày/năm = 1 ngày/tháng) + LeaveAttachment + LeaveApprovalLog (SLA 24h/48h) + CapacityImpactEvent |
| Vai trò chính | TL (duyệt ≤5 ngày — SLA 24h, chức danh tổ chức theo hồ sơ) · HR_L2 (duyệt >5 ngày/nghỉ không lương/luồng bất khả kháng — SLA 48h) · HR_L1 (yêu cầu bổ sung giấy tờ, đơn treo, báo cáo — không duyệt) |
| Vai trò liên quan | Nhân viên mọi vai (lập đơn, xem số dư + lịch nhóm mình) · Manager (duyệt đơn của TL; BOD duyệt đơn của HR_L2 — không ai tự duyệt đơn mình) · OPS_PLAN (thấy capacity khả dụng giảm tự động — S15, không thông báo tay) |
| Workflow stage | `DRAFT → PENDING → PENDING_TL (≤5 ngày, 24h) / PENDING_HR (>5 ngày hoặc không lương, 48h) → APPROVED → CONSUMED` · nhánh `REJECTED` (lý do bắt buộc) · `APPROVED → CANCELLED / PARTIALLY_CANCELLED` (xác nhận 2 chiều, hoàn số dư + phục hồi capacity theo phần) · quá SLA nhắc rồi escalate (TL→Manager; HR_L2→BOD), không tự duyệt hộ |

**Checklist ngữ cảnh (BƯỚC 0):** (A) Object = đơn nghỉ phép chạy qua routing phân cấp theo số ngày + loại nghỉ; số dư là kết quả tích lũy tự động — không nhập tay. (B) Primary actors: TL (cấp 1), HR_L2 (cấp 2), nhân viên (lập đơn). (C) Related: HR_L1 (giấy tờ), OPS (capacity — REQ-HR-009), chấm công FEAT-003 (cập nhật công theo loại nghỉ), Rate Card (ngày nghỉ đã duyệt tự loại khỏi giờ billable), KPI (prorate/miễn thai sản/ốm dài). (D) Stages: SLA 24h (TL) / 48h (HR_L2) đếm từ lúc vào hàng đợi; quá hạn → nhắc → escalate cấp trên. (E) Cross-module: S15 (capacity + duyệt timesheet ∥ HR), S20 (hồ sơ SSOT: ngày vào công, TL trực tiếp, `LONG_LEAVE` >30 ngày), S22 (KPI prorate), S24 (escalation), M4 (lập đơn mobile). (F) Thông tin: số dư hiện hành theo loại nghỉ, lịch nhóm, chứng từ, SLA còn lại, tần suất nghỉ không phép §8. (G) Quyết định: duyệt/từ chối theo cấp; luồng bất khả kháng; hủy/giảm đơn đã duyệt; xác nhận prorate. (H) Actions: lập đơn (mọi người), duyệt/từ chối/bulk (TL/HR_L2), yêu cầu bổ sung giấy tờ (HR_L1). (I) Exceptions: thiếu giấy khám ốm ≥3 ngày, vượt số dư (ẩn nút duyệt + API chặn), đơn quá SLA, trùng lịch nhóm, nghỉ không phép ≥2 lần/tháng (cảnh cáo) / ≥5 ngày/tháng (căn cứ chấm dứt HĐLĐ §8). (J) 1 surface `/hr/leave` — duyệt, lịch và số dư cùng bề mặt; không tách page theo cấp duyệt.

---

## 1. TRANG CHÍNH

### 1.1. Layout — worklist W1 full-width (queue duyệt là tab mặc định), click hàng mở Sheet S1

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: HR > Leave Management        {phep_cho_duyet} ·9      [+ Lập đơn nghỉ] [Lưu views▾]│
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tabs: [Hàng đợi duyệt ·9] [Lịch nghỉ team] [Số dư & §8]                                      │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ── TAB T1: HÀNG ĐỢI DUYỆT ───────────────────────────────────────────────────────────────── │
│ (Chờ tôi ·4×)(Quá SLA ·1×)(Thiếu giấy khám ·2×)(Tuần này nghỉ ·6×)      [Tìm nhanh…][Lọc▾]  │
│ ┌────────────────────────────────────────────────────────────────────────────────────────┐   │
│ │ ☐ NV          Loại nghỉ    Từ–Đến        Ngày  Cấp duyệt  SLA      Số dư  Trạng thái   │   │
│ │ ☑ Nguyễn A.   Phép năm     15/09–17/09    3   TL (24h)   ⏱ 14h    6.5   [Chờ TL]      │   │
│ │ ☑ Lê B.       Ốm           12/09–15/09    4   TL (24h)   ⏱ 5h     —     [Thiếu giấy⚠] │   │
│ │ ▸ Trần C.     Không lương  20/09–03/10   14   HR_L2(48h) ⏱ 40h    8.0   [Chờ HR_L2]   │   │
│ │ ▸ Phạm D.     Phép năm     14/09–25/09   12   HR_L2(48h) ⏱ -2h 🔴 6.5   [Quá SLA🔴]   │   │
│ │ [mình] Hoàng E. Phép năm …(row của người đang đăng nhập — tự loại khỏi bulk, ẩn nút)  │   │
│ │ Bulk: [Đã chọn 2] [Duyệt hàng loạt] [Từ chối…] [⋯]                                     │   │
│ │ Phân trang ← 1 2 →  20/50/100                                                          │   │
│ └────────────────────────────────────────────────────────────────────────────────────────┘   │
│ Row actions: Xem (S1) · Duyệt · Từ chối… (D2) · Yêu cầu bổ sung giấy tờ… (D4 — HR_L1)        │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Mobile <768px: queue → card (swipe duyệt/từ chối qua M4/M6 cho manager); bảng số dư T3 báo "xem trên web".

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable compact | row 32px, bulk-selection, sort click header, pagination server-side 20/50/100 | Pattern W1 |
| Quick filter chips | tháo từng chip; mặc định theo role: TL = "Chờ tôi" · "Quá SLA"; HR_L2 = "Chờ HR_L2" · "Bất khả kháng"; HR_L1 = "Thiếu giấy khám" · "Đơn treo" | Chip "Quá SLA" `--state-sla-breach` tự nhảy đầu queue |
| StatusBadge | 1 badge/hàng — bảng §1.4 | Token §1 design-system |
| SLA countdown | Cột "SLA": còn Xh; ≥50% thời gian → `--state-sla-warning`, quá hạn → `--state-sla-breach` + icon chuông | 24h (TL) / 48h (HR_L2) từ lúc vào queue |
| WarningIndicator | inline: thiếu giấy khám, vượt ngưỡng báo trước (BR-003), trùng lịch nhóm ≥2 người | 3 phần: chuyện gì — ai làm — hạn |
| WaitingOnIndicator | chip "chờ HR_L2 — Lê T. · 6h" cho đơn đã qua cấp TL | Click → D6 nhắc |
| Bulk bar | trượt lên khi chọn ≥1; tự loại row `[mình]` | Cấm tự duyệt — approver ≠ người lập |

### 1.3. Cột hàng đợi

| Tên | Trường | Định dạng | Sắp xếp | Ghi chú |
|-----|--------|----------|---------|---------|
| Nhân viên | `profile_id` | Avatar + tên + phòng | Có | Link S20 khi có quyền |
| Loại nghỉ | `leave_type` | Chip (phép năm/ốm/không lương/thai sản/nghỉ riêng §8) | Có | Loại không lương → force route HR_L2 |
| Từ–Đến / Ngày | `from_date, to_date, days` | dd/MM–dd/MM · số ngày | Có | Số ngày quyết định routing |
| Retro | `is_retro` | Nhãn "đột xuất" khi true | Không | Lý do bắt buộc, thống kê riêng |
| Cấp duyệt | routing | "TL (24h)" / "HR_L2 (48h)" | Có | Do hệ thống route, không chọn tay |
| SLA | `sla_due_at` | Countdown | Có (breach đầu) | Quá hạn đỏ + chuông |
| Số dư | LeaveBalance.available | Số ngày, `tabular-nums` | Có | Không đủ → nút duyệt ẩn (BR-005) |
| Chứng từ | LeaveAttachment | Icon đính kèm / ⚠ thiếu | Không | Ốm ≥3 ngày bắt buộc giấy khám |
| Trạng thái | `status` | StatusBadge | Có | Bảng §1.4 |

### 1.4. Trạng thái & badge

Nháp `--state-draft` · Chờ TL `--state-pending` · Chờ HR_L2 `--state-pending` (+ chip WaitingOn) · Quá SLA `--state-sla-breach` + icon chuông · Thiếu chứng từ `--state-sla-warning` · Đã duyệt `--state-approved` · Đã tiêu (CONSUMED) `--state-manual` · Bị từ chối `--state-rejected` · Đã hủy/giảm `--state-info`. Badge mỗi hàng tối đa 1 trạng thái chính — chi tiết vào tooltip.

**Trạng thái hệ thống:** loading = skeleton 10 hàng; empty theo role — TL: "Không có đơn nào chờ bạn duyệt"; HR_L2: "Hàng đợi HR_L2 trống"; nhân viên: "Bạn chưa có đơn nào — lập đơn đầu tiên" (CTA D3); error = hàng lỗi + retry. Mọi số dư/SLA/mốc render machine-state từ CORE tại thời điểm đọc — không cache, không tính lại phía UI.

### 1.5. Hành động chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| "Duyệt" (1 hàng / S1) | POST approve theo cấp đăng nhập | `APPROVED` → tự trừ số dư + tự giảm capacity tuần (REQ-HR-009) + cập nhật công theo loại nghỉ (FEAT-003) |
| "Từ chối…" | D2 — lý do ≥10 ký tự bắt buộc | `REJECTED`; người lập thấy lý do, tạo đơn mới nếu cần |
| Bulk (chọn nhiều) | D1 | Duyệt hàng loạt 1 bước; từ chối loạt = lý do chung + ghi chú riêng; row `[mình]` tự loại |
| "Yêu cầu bổ sung giấy tờ…" | D4 (HR_L1) | Đơn đánh dấu "thiếu chứng từ", nhắc người lập; không chuyển duyệt khi thiếu |
| Click chip WaitingOn | D6 | Nhắc người duyệt đang giữ |
| "Hủy/giảm ngày" trên đơn APPROVED | D5 | Xác nhận 2 chiều (người lập + người duyệt ban đầu); hoàn số dư + phục hồi capacity theo phần; không xóa đơn |
| "+ Lập đơn nghỉ" | D3 | Form với số dư hiện hành + lịch nhóm hiển thị sẵn; `balance_check` tự động trước khi vào approval |

### 1.6. Phân Quyền (hide khi không có quyền — PEP; routing phân cấp do CORE enforce)

| Thành phần | Nhân viên (mọi vai) | TL | HR_L1 | HR_L2 | OPS_PLAN | BOD/Manager |
|-----------|--------------------|----|-------|-------|----------|-------------|
| Lập đơn của mình (D3) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem số dư + lịch sử của mình | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem lịch nghỉ nhóm | ✅ (nhóm mình) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Duyệt đơn ≤5 ngày (24h) | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ (Manager duyệt đơn của TL) |
| Duyệt đơn >5 ngày / không lương (48h) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ (BOD duyệt đơn của HR_L2) |
| Duyệt luồng bất khả kháng (hết phép) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Bulk duyệt/từ chối | ❌ | ✅ (nhóm mình) | ❌ | ✅ | ❌ | ❌ |
| Yêu cầu bổ sung giấy tờ / xử lý đơn treo | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Xác nhận KPI prorate/miễn (thai sản/ốm dài) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Xem báo cáo nghỉ theo phòng/tháng + tần suất không phép §8 | ❌ (chỉ mình) | ✅ (nhóm mình) | ✅ | ✅ | ❌ (chỉ capacity — S15) | ❌ |

Cấm tự duyệt đơn của chính mình kể cả cấp quản lý: đơn của TL → hàng đợi Manager; đơn của HR_L2 → hàng đợi BOD. Không có delegate duyệt `[KXN-DTS]` — BOD/HR_L2 đi nghỉ: đơn treo có SLA nhắc + escalate, không ai duyệt hộ. Lý do bắt buộc khi từ chối; mọi lượt duyệt ghi người duyệt + thời điểm + lý do vào audit bất biến.

---

## 2. TABS

Global context (kỳ đang xem + role view) giữ nguyên khi chuyển tab; T2/T3 lazy-load.

### Tab T1 — Hàng đợi duyệt `UI-WEB-LEAVE-001-T1`
- **Mục tiêu:** xử lý hết hàng đợi trong SLA 24h/48h — đơn không treo vô hạn: quá SLA sinh nhắc rồi escalate cấp trên, không tự duyệt/tự từ chối.
- **Thông tin:** queue theo §1.3; KPI chips đầu tab: Chờ tôi · Quá SLA · Thiếu giấy khám · Đã duyệt tuần này.
- **Components/actions/states:** theo §1.2–1.6.
- **Quan hệ tab khác:** duyệt xong → dòng biến khỏi queue, xuất hiện trong T2 (lịch) và làm giảm số dư trong T3; thiếu giấy khám nhắc bổ sung ở đây; luồng bất khả kháng là 1 hàng đợi con của HR_L2 trong T1.

### Tab T2 — Lịch nghỉ team `UI-WEB-LEAVE-001-T2`
- **Mục tiêu:** tránh cả team nghỉ cùng lúc — thấy đụng độ TRƯỚC khi lập đơn và khi duyệt; hệ thống chỉ cảnh báo trùng, không tự chặn (TL quyết theo nhân lực).
- **Thông tin:** lịch tháng (chọn phòng/team, điều hướng ◀ tháng ▶); mỗi ô ngày hiển thị chip nhân sự nghỉ: đã duyệt (đặc `--state-approved`) / chờ duyệt (viền `--state-pending`) / nghỉ không phép ghi nhận (đỏ nhạt `--state-overdue`); ngày có ≥2 người cùng nghỉ → viền `--state-sla-warning` + nhãn "X người — kiểm tra nhân lực"; overlay số capacity khả dụng tuần (đọc GET capacity — vàng >90%, đỏ ≥100% khớp token S15). Nhấp 1 tuần → S3 (panel tuần).
- **Components:** Calendar grid (desktop tháng, mobile tuần); chip nhân sự; legend 3 loại; WarningIndicator cho tuần chạm ngưỡng capacity.
- **Actions:** click chip → mở S1 (chi tiết đơn) nếu có quyền; click ô trống → D3 lập đơn lấy sẵn ngày; đổi phòng/team (theo data-scope).
- **States:** lazy-load; empty "Không có ngày nghỉ nào trong tháng này"; error retry từng tháng; không hiển thị đơn của người ngoài data-scope (row-level core enforce).
- **Quan hệ:** đơn mới duyệt/đơn hủy tự phản chiếu; ngày nghỉ đã duyệt tự loại khỏi giờ billable khả dụng (BR-009 FEAT-ERP-HRCORE-004); capacity overlay đồng bộ S15.

### Tab T3 — Số dư & tuân thủ §8 `UI-WEB-LEAVE-001-T3`
- **Mục tiêu:** số dư minh bạch theo thời gian thực (tích lũy 12 ngày/năm, không nhập tay) + theo dõi nội quy nghỉ phép và chế tài xử phạt theo `03_Quy_che_KPI_HR.md` §8.
- **Thông tin:** (1) Bảng số dư theo nhân viên (data-scope): ngày vào công gốc, phép năm tích lũy/đã dùng/còn lại, nghỉ ốm, không lương, thai sản; nhãn "chờ quy định cộng dồn `[CẦN CHỐT SỐ]`" trên số dư cuối năm (đề xuất Điều 113 BLLĐ 2019: cộng dồn tối đa 3 tháng). Điều chỉnh số dư chỉ bằng bản ghi hiệu chỉnh có phê duyệt HR_L2 kèm lý do — không ô nhập tay. (2) Báo cáo nghỉ theo phòng/tháng: tỷ lệ nghỉ, nghỉ đột xuất retro, nghỉ không phép — tần suất ≥2 lần (buổi/ngày)/tháng → nhãn "cảnh cáo–đình chỉ"; ≥5 ngày/tháng → nhãn "căn cứ chấm dứt HĐLĐ §8" kèm link sang hồ sơ (S20 T2 — luồng chấm dứt bắt buộc gắn hồ sơ vi phạm). (3) Đơn treo thiếu chứng từ (HR_L1 xử lý).
- **Components:** DataTable + số `tabular-nums`; nhãn chế tài là StatusBadge + text (color-blind safe); WarningIndicator khi gắn nhãn §8; drill-down phòng → nhân viên.
- **Actions:** tạo bản ghi hiệu chỉnh số dư (HR_L2 — form lý do bắt buộc); xuất báo cáo (không có C1); gắn nhãn §8 là hệ thống tự đếm — không tick tay.
- **States:** lazy-load; nhân viên chỉ thấy hàng của mình; empty "Chưa có dữ liệu kỳ này"; nhãn "chờ quy định cộng dồn" hiển thị vĩnh viễn cho đến khi BOD chốt.
- **Quan hệ:** nhãn chấm dứt §8 → S20 T2 (chấm dứt HĐLĐ thiếu hồ sơ vi phạm bị chặn luồng); xác nhận prorate/miễn (D8) nối S22 KPI; nghỉ không lương >30 ngày → đề xuất chuyển hồ sơ `LONG_LEAVE` (S20).

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Duyệt / Từ chối hàng loạt | `UI-WEB-LEAVE-001-D1` | Confirm + form lý do | Bulk bar khi chọn ≥1 |
| 2 | Từ chối 1 đơn | `UI-WEB-LEAVE-001-D2` | Form lý do | "Từ chối…" trên 1 hàng |
| 3 | Lập đơn nghỉ (web ESS) | `UI-WEB-LEAVE-001-D3` | Form + lịch nhóm | [+ Lập đơn nghỉ] / click ô lịch |
| 4 | Yêu cầu bổ sung giấy tờ | `UI-WEB-LEAVE-001-D4` | Form | Row action HR_L1 trên đơn thiếu chứng từ |
| 5 | Hủy/giảm đơn đã duyệt | `UI-WEB-LEAVE-001-D5` | Form + xác nhận 2 chiều | Đơn APPROVED — "Hủy/giảm ngày" |
| 6 | Nhắc người duyệt | `UI-WEB-LEAVE-001-D6` | Modal nhắn | Click WaitingOnIndicator |
| 7 | Duyệt luồng bất khả kháng | `UI-WEB-LEAVE-001-D7` | ApprovalCard | Đơn "nghỉ riêng theo §8" hết phép — HR_L2 |
| 8 | Xác nhận KPI prorate/miễn | `UI-WEB-LEAVE-001-D8` | Form xác nhận | Thai sản/ốm dài — HR_L2 |

Chi tiết trọng yếu:
- **D1:** tóm tắt số đơn, tổng ngày, cấp sẽ duyệt. Duyệt: 1 bước + toast, lặp approve per-id (idempotent); CORE chặn từng item không đủ điều kiện → kết quả per-item accepted/rejected + lý do (ví dụ số dư vừa thay đổi). Từ chối: lý do chung ≥10 ký tự BẬT BUỘC. Row của chính người đăng nhập tự loại — nếu selection chỉ còn row của mình, nút vô hiệu kèm lý do "không được tự duyệt".
- **D3:** loại nghỉ (theo trạng thái hồ sơ — loại không áp dụng bị khóa), từ–đến (date picker), số ngày tự tính (ngày làm việc, trừ T7/CN/Lễ — BR-003), lý do, đính kèm giấy tờ (ốm ≥3 ngày bắt buộc giấy khám — không đính không submit được). Header hiển thị: số dư hiện hành từng loại + mini lịch nhóm tuần được chọn (chips đồng nghiệp nghỉ + cảnh báo trùng); nghỉ sát ngày dưới ngưỡng báo trước → cảnh báo trước khi gửi; toggle "nghỉ đột xuất (retro)" hiện kèm lý do bắt buộc. Submit → `balance_check` ở CORE: không đủ số dư → thông báo số dư, đơn không vào hàng đợi (riêng bất khả kháng chọn luồng D7).
- **D5:** phần ngày hủy/giảm (không cho xóa đơn đã duyệt); yêu cầu đi 2 bước: người lập gửi → người duyệt ban đầu xác nhận; hiển thị hiệu ứng dự kiến: hoàn X ngày số dư + capacity phục hồi Y giờ; có vết — `CANCELLED`/`PARTIALLY_CANCELLED`.
- **D7:** ApprovalCard: loại "nghỉ riêng theo §8" (ốm có chứng minh / tang sự), chứng minh đính kèm bắt buộc, không trừ số dư phép năm, ghi loại riêng để tách thống kê; SLA HR_L2 48h.
- **D8:** nhân sự, kỳ nghỉ dài (thai sản/ốm dài qua nhiều tháng), xác nhận "KPI prorate/miễn kỳ X" — nối module KPI (S22 thực thi), HR_L2 ký xác nhận có audit.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Chi tiết đơn nghỉ | `UI-WEB-LEAVE-001-S1` | Right 720px | Click 1 hàng T1 / 1 chip lịch T2 |
| 2 | Số dư & lịch sử nghỉ 1 nhân viên | `UI-WEB-LEAVE-001-S2` | Right 480px | Click tên NV trong T3 |
| 3 | Panel tuần team | `UI-WEB-LEAVE-001-S3` | Right 480px | Click 1 tuần trong lịch T2 |

- **S1:** header: NV + loại nghỉ + StatusBadge + SLA countdown. Nội dung: từ–đến + số ngày (ngày làm việc), lý do, retro flag, chứng từ (xem/tải tệp đính kèm theo quyền), số dư trước/sau nếu duyệt, xung đột lịch nhóm trong kỳ, CapacityImpactEvent dự kiến (giờ giảm theo tuần), ProgressTracker routing (PENDING_TL/PENDING_HR + đã qua cấp nào), Timeline (submit → nhắc SLA → escalate → duyệt). Footer sticky theo quyền: [Duyệt] [Từ chối…] (người đúng cấp, ẩn khi thiếu số dư/giấy khám) · [Yêu cầu bổ sung giấy tờ…] (HR_L1) · [Hủy/giảm ngày] (đơn APPROVED) — Esc đóng, trả focus về hàng.
- **S2:** bảng số dư theo loại + năm (tích lũy/đã dùng/còn), nhãn "chờ quy định cộng dồn `[CẦN CHỐT SỐ]`"; lịch sử đơn (đã duyệt/đã tiêu/đã hủy/từ chối) 12 tháng; bản ghi hiệu chỉnh số dư (ai, lý do, khi nào). Không ô sửa trực tiếp.
- **S3:** danh sách nhân sự nghỉ trong tuần (mỗi dòng: ngày, loại, trạng thái), tổng người nghỉ mỗi ngày, capacity khả dụng tuần so định mức (băng vàng/đỏ khớp S15), cảnh báo "≥2 người cùng nghỉ ngày X". Action: mở S1 từng đơn; lập đơn cho ngày trống (D3).

---

## 5. VIEW MODES

1 surface `/hr/leave` — role views; KHÔNG tách page theo cấp duyệt (routing là dữ liệu, không phải navigation).

| Mode | UI-ID | Hiện khi nào | Khác biệt |
|------|-------|--------------|-----------|
| TL | `UI-WEB-LEAVE-001-M1` | Chức danh TL/Manager | Hàng đợi ≤5 ngày nhóm mình (SLA 24h), bulk duyệt; chip "Chờ tôi" · "Quá SLA"; đơn của chính mình nằm ở hàng đợi cấp trên (read-only row `[mình]`) |
| HR_L2 | `UI-WEB-LEAVE-001-M2` | Role HR_L2 | Hàng đợi >5 ngày/không lương/bất khả kháng (48h) + hàng đợi con escalate từ TL; D7/D8; tab T3 full (báo cáo + nhãn §8 + hiệu chỉnh số dư); mặc định mở T1 khi `{phep_cho_duyet}` > 0 |
| HR_L1 | `UI-WEB-LEAVE-001-M3` | Role HR_L1 | KHÔNG có nút duyệt; chip "Thiếu giấy khám" · "Đơn treo"; D4; tab T3 (báo cáo + đơn treo); hỗ trợ nhập hộ giấy tờ người lập không có tài khoản active |
| Nhân viên | `UI-WEB-LEAVE-001-M4` | Mọi vai nội bộ | Chỉ đơn của mình + số dư (S2) + lịch nhóm mình (T2); D3 là hành động chính; thấy lý do từ chối + trạng thái cấp duyệt hiện tại; CTA phụ "lập trên mobile M4" |

---

## 6. API ENDPOINTS

> Endpoint thật từ `api-contract.md` §6.5 (COMP-ERP-005) + các mục liên quan. WEB render machine-state từ CORE — `balance_check` và routing thực thi ở service layer, UI phản chiếu kết quả. Pagination server-side 20/50/100.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Hàng đợi duyệt + lịch sử đơn (T1) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/leave-requests]` | Cần filter `status, route(PENDING_TL/PENDING_HR), approver, profile_id, from_date, to_date, leave_type` + `sort, page, limit`; API-ERP-065 hiện chỉ khai POST + /{id}/approve |
| Lập đơn (D3) | POST | `/api/v1/erp/leave-requests` | Body: leave_type, from/to, reason, attachments; `balance_check` tự động trước khi vào approval; thiếu giấy khám ốm ≥3 ngày → từ chối chuyển trạng thái — API-ERP-065 |
| Duyệt / từ chối (D1/D2/D7) | POST | `/api/v1/erp/leave-requests/{id}/approve` | Body `{action: approve|reject, comment}`; routing phân cấp enforce ở CORE — sai cấp → từ chối; tự duyệt → chặn + audit — API-ERP-065; bulk = lặp per-id (idempotent). `[NEEDS_REVIEW: lệch vai cấp 1 — contract ghi "HR_L1→HR_L2", spec FEAT-ERP-HRCORE-004 ghi TL (≤5 ngày, 24h) → HR_L2; TL là chức danh tổ chức theo hồ sơ, không phải vai registry]` |
| Số dư + đơn của mình (M4/S2) | GET | `/api/v1/erp/ess/me` | Self-service: công, phép, timesheet — API-ERP-066 (chỉ bản thân) |
| Bảng số dư theo nhân viên (T3) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/leave-balances]` | Cần filter `year, department, profile_id, leave_type`; số dư hiện chỉ đọc được qua /ess/me (bản thân) |
| Lịch nghỉ team (T2) | GET | `[NEEDS_REVIEW: thiếu endpoint lịch nghỉ (calendar)]` | Cần `month/team_id` trả danh sách đơn theo ngày + trạng thái; GET capacity không trả ngày nghỉ theo lịch |
| Capacity tuần overlay (T2/S3) | GET | `/api/v1/erp/capacity` | Params `week_key, team_id`; vàng 90%, đỏ 100% — API-ERP-069 |
| Hủy/giảm đơn đã duyệt (D5) | POST | `[NEEDS_REVIEW: thiếu transition cancel/partial-cancel]` | Xác nhận 2 chiều; hoàn số dư + phục hồi capacity theo phần; `/{id}/approve` hiện không phủ luồng này |
| Xác nhận KPI prorate/miễn (D8) | POST | `[NEEDS_REVIEW: thiếu endpoint xác nhận prorate — không nằm trong /api/v1/erp/pips (API-ERP-071) lẫn kpi-periods]` | Nối module KPI (S22 thực thi) |
| Báo cáo nghỉ phòng/tháng + đếm không phép §8 (T3) | GET | `[NEEDS_REVIEW: thiếu endpoint báo cáo nghỉ]` | Tần suất ≥2 lần/tháng (cảnh cáo) / ≥5 ngày/tháng (chấm dứt HĐ) — server-side đếm, không tự tính UI |
| SLA 24h/48h + escalate | GET | `/api/v1/erp/sla-timers` | `object_type=leave_request` — API-ERP-073 (scope theo permission) |
| Nhắc / escalate (D6) | GET/POST | `/api/v1/erp/notifications` | Log dispatch đa kênh — API-ERP-074 |
| Danh mục nhân sự (picker D3, cột NV) | GET | `/api/v1/erp/employees` | Scope theo data-scope; lương masked — API-ERP-062 |

**[NEEDS_REVIEW] các điểm thiếu endpoint (KHÔNG bịa — cần bổ sung vào api-contract):**
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/leave-requests — hàng đợi duyệt + lịch sử với filter/sort/pagination server-side; API-ERP-065 chỉ có POST + /{id}/approve]`
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/leave-balances — bảng số dư theo nhân viên/loại nghỉ (T3); hiện chỉ /ess/me trả số dư của bản thân]`
- `[NEEDS_REVIEW: thiếu endpoint lịch nghỉ team (calendar theo tháng/team) — cần cho T2 và mini-lịch trong D3]`
- `[NEEDS_REVIEW: thiếu transition hủy/giảm đơn đã duyệt (cancel/partial-cancel + hoàn số dư + phục hồi capacity)]`
- `[NEEDS_REVIEW: thiếu endpoint báo cáo nghỉ theo phòng/tháng + đếm tần suất nghỉ không phép §8 (nhãn cảnh cáo/chấm dứt HĐ)]`
- `[NEEDS_REVIEW: thiếu endpoint xác nhận KPI prorate/miễn (thai sản/ốm dài) — API-ERP-071 chỉ phủ PIP]`
- `[NEEDS_REVIEW: bulk duyệt — giả định lặp per-id qua /{id}/approve; nếu cần 1 call batch thì bổ sung endpoint]`
- `[NEEDS_REVIEW: lệch vai duyệt cấp 1 — API-ERP-065 ghi "HR_L1→HR_L2 phân cấp", FEAT-ERP-HRCORE-004 ghi TL duyệt ≤5 ngày (24h); cần chốt routing trong contract]`

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-LEAVE-001` | Main Page | Leave Management — worklist W1 + 3 tab, route `/hr/leave`, badge `{phep_cho_duyet}` |
| `UI-WEB-LEAVE-001-T1` | Tab | Hàng đợi duyệt phân cấp TL (≤5 ngày, 24h) → HR_L2 (>5 ngày/không lương, 48h), bulk, escalate |
| `UI-WEB-LEAVE-001-T2` | Tab | Lịch nghỉ team — cảnh báo trùng, overlay capacity, legend đã duyệt/chờ/không phép |
| `UI-WEB-LEAVE-001-T3` | Tab | Số dư tự động + báo cáo phòng/tháng + tần suất nghỉ không phép §8 + hiệu chỉnh có duyệt |
| `UI-WEB-LEAVE-001-D1` | Dialog | Duyệt / từ chối hàng loạt (lý do bắt buộc khi từ chối, tự loại row của mình) |
| `UI-WEB-LEAVE-001-D2` | Dialog | Từ chối 1 đơn (lý do ≥10 ký tự) |
| `UI-WEB-LEAVE-001-D3` | Dialog | Lập đơn nghỉ — số dư + mini lịch nhóm sẵn, giấy khám ốm ≥3 ngày, retro có lý do |
| `UI-WEB-LEAVE-001-D4` | Dialog | Yêu cầu bổ sung giấy tờ (HR_L1) |
| `UI-WEB-LEAVE-001-D5` | Dialog | Hủy/giảm đơn đã duyệt (xác nhận 2 chiều, hoàn số dư + capacity) |
| `UI-WEB-LEAVE-001-D6` | Dialog | Nhắc người duyệt (từ WaitingOnIndicator) |
| `UI-WEB-LEAVE-001-D7` | Dialog | Duyệt luồng bất khả kháng "nghỉ riêng §8" (HR_L2, không trừ số dư) |
| `UI-WEB-LEAVE-001-D8` | Dialog | Xác nhận KPI prorate/miễn (thai sản/ốm dài — nối S22) |
| `UI-WEB-LEAVE-001-S1` | Sheet | Chi tiết đơn — chứng từ, số dư trước/sau, xung đột, routing + timeline (right 720px) |
| `UI-WEB-LEAVE-001-S2` | Sheet | Số dư & lịch sử 1 nhân viên — theo loại, bản ghi hiệu chỉnh (right 480px) |
| `UI-WEB-LEAVE-001-S3` | Sheet | Panel tuần team — ai nghỉ, capacity khả dụng, cảnh báo trùng (right 480px) |
| `UI-WEB-LEAVE-001-M1` | View Mode | TL — hàng đợi ≤5 ngày nhóm mình, bulk duyệt |
| `UI-WEB-LEAVE-001-M2` | View Mode | HR_L2 — hàng đợi >5 ngày/không lương/bất khả kháng, báo cáo + §8 |
| `UI-WEB-LEAVE-001-M3` | View Mode | HR_L1 — giấy tờ + đơn treo, không nút duyệt |
| `UI-WEB-LEAVE-001-M4` | View Mode | Nhân viên — đơn của tôi + số dư + lịch nhóm mình, lập qua D3/M4 |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng: nghỉ phép | `../../../../phase2-features/bcerp-web/hr-core/nghi-phep-so-du-tu-dong-va-duyet-phan-cap.md` | FEAT-ERP-HRCORE-004 |
| Tính năng: chấm công (nối sau duyệt) | `../../../../phase2-features/bcerp-web/hr-core/cham-cong-va-overtime.md` | FEAT-ERP-HRCORE-003 |
| Tính năng: ESS | `../../../../phase2-features/bcerp-web/hr-core/self-service-nhan-vien-ess.md` | FEAT-ERP-HRCORE-005 — điểm vào lập đơn |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.5 COMP-ERP-005 (API-ERP-065/066/069) |
| Design system | `../../../design-system.md` | Pattern W1 + ApprovalCard + WaitingOnIndicator |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | S21 — `/hr/leave`, badge `{phep_cho_duyet}` |
| Screen liên quan | `./screens-hr-records.md` | S20 — hồ sơ SSOT + luồng chấm dứt §8 |
| Screen liên quan (capacity) | `../../ops/capts/screens-capacity-timesheet.md` | S15 — capacity giảm tự động khi duyệt |
| Mobile counterpart | `../../../mobile-internal` | M4 Nghỉ phép của tôi · M6 duyệt nhanh `[NEEDS_REVIEW]` |
