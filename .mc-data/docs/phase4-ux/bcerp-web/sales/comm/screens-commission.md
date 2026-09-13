# Screen Group: Commission (mine / team)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `comm` (MOD-COMMISSION-QUOTA)
> **Tính năng:** FEAT-ERP-COMM-001
> **Route:** `/sales/commission`
> **Main UI-ID:** `UI-WEB-COMM-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-COMM-001

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-COMM-001` |
| Route | `/sales/commission` |
| Loại | Dashboard + Worklist (1 surface, role view theo scope PII Restricted) |
| FEAT-ID | FEAT-ERP-COMM-001 |
| Người dùng | SALES_L1/L2 (của tôi) · SALES_L3 (nhóm) · SALES_L4 (phòng) · SALES_L5 (toàn phòng KD + duyệt) · FIN_L1/L2 (kiểm chứng, duyệt) · HR_L1 (attainment tổng hợp, không PII) |

**Workflow context checklist (BƯỚC 0):** A. Object: `commission_credit` (credit theo đợt thanh toán **thực nhận** đối chiếu AR — KHÔNG theo booking/ngày ký), `clawback_record`, `quota`/`attainment_snapshot`, `commission_period`. B. Actors: sale L1–L5, FIN. C. Liên quan: ARAP (nguồn payment), QDD (deal nguồn, Gate 2), WALLET (hoàn tiền → clawback), KPI (COMM = 1/3 trụ cột), HR. D. Lifecycle: credit ACTIVE/PAUSED/REVERSED; chu kỳ tính `computed → clawback_check → approved → paid`; clawback `PENDING_CONFIRM → FIN_CONFIRMED → APPROVED → APPLIED/REJECTED`; kỳ `OPEN/LOCKED`. E. Cross-module: `payment.received` sinh credit; aging >90 ngày / hoàn phí sinh clawback. F. Nhu cầu: thấy "tiền của mình" minh bạch, clawback rõ lý do, quota/coverage realtime. G. Quyết định: FIN xác nhận clawback, GDKD duyệt (SLA 3 ngày). H. Actions: xem + drill-down deal nguồn; duyệt qua API thật. I. Exceptions: clawback trượt SLA, kỳ LOCKED, deal bị trả về Gate 2 → PAUSED, coverage đỏ <2×, intern chưa phát sinh DT. J. Không tách màn — 1 surface, permission filter theo §4 FEAT.

**Nguyên tắc hiển thị:** mọi số tiền dùng `MoneyDisplay` (right-align, `tabular-nums`); web KHÔNG tự tính con số quyền lợi — chỉ render machine-state từ engine `SYS-CORE-BACKEND`; màu coverage vàng/đỏ đọc từ `attainment_snapshot`, không có form nhập attainment. PII Restricted: L1/L2 chỉ thấy của mình; L3 nhóm; L4 phòng; L5 toàn phòng KD; FIN xem để đối soát; vượt phạm vi bị chặn ở cả UI và API.

---

## 1. TRANG CHÍNH

### 1.1. Layout

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Sales / Commission        Kỳ: [2026-Q3 ▾]  Trạng thái kỳ: ● OPEN                   │
│ Commission của tôi — Hoàng Minh Tuấn (NVKD)      [Xuất báo cáo] [Khóa kỳ ▾]        │
├────────────────────────────────────────────────────────────────────────────────────┤
│ ⚠ (khi xem kỳ đã khóa) Kỳ 2026-Q2 đã khóa 05/07/2026 bởi Trần Thị Mai (GDKD) +    │
│   FIN_L2 — mọi form nhập vô hiệu. Chỉ clawback điều chỉnh đã duyệt được áp.        │
├────────────────────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────┬─────────────────┬─────────────────┬──────────────────────────┐│
│ │ CREDIT KỲ NÀY   │ CLAWBACK ĐÃ ÁP  │ THỰC NHẬN RÒNG  │ ATTAINMENT               ││
│ │ 15.120.000 ₫    │ −1.860.000 ₫    │ 13.260.000 ₫    │ 72% · hệ số ×0,9         ││
│ │ 128 đợt thực nhận│ 3 dòng (2 chờ) │ credit − clawback│ quota 600.000.000 ₫     ││
│ └─────────────────┴─────────────────┴─────────────────┴──────────────────────────┘│
│ [L3+] Coverage quota kỳ kế tiếp: 2,4×  ⚠ VÀNG (<3×) — bắt buộc kế hoạch bổ sung   │
│       lead; SM/TPKD chịu trách nhiệm. [Xem pipeline kỳ kế tiếp →]                  │
├────────────────────────────────────────────────────────────────────────────────────┤
│ Tabs: Credit thực nhận (128) · Clawback (2 chờ) · Quota & Attainment · Thang hoa   │
│       hồng & Kỳ                                                                    │
├────────────────────────────────────────────────────────────────────────────────────┤
│ [Lưu view ▾]            [Tìm deal/KH/payment…] [Trạng thái ▾] [Loại ▾] [Sort ▾]    │
│ Chips: (Đợt kỳ này ×) (ACTIVE ×)                                                   │
│ ┌──────────────────────────────────────────────────────────────────────────────┐  │
│ │ Deal nguồn      Khách hàng       Thực nhận     Credit       Tỷ lệ  Trạng thái│  │
│ │ DEAL-1042       Vinacafe ĐNai    38.000.000 ₫  931.000 ₫    70%   ● ACTIVE   │  │
│ │  đợt 2/4 · HĐ 12 tháng · 05/08/2026 · rate 3,5% (L2) · INV-2026-0388          │  │
│ │ DEAL-0987       Anpha Foods      52.000.000 ₫  1.820.000 ₫  100%  ● ACTIVE   │  │
│ │ DEAL-0876       Minh Long Co.   — tạm dừng —     0 ₫         —     ◌ PAUSED   │  │
│ │  ⚠ Deal bị trả về từ Gate 2 — handoff lại thành công sẽ tiếp tục              │  │
│ │ DEAL-0712       Thái Dương       45.000.000 ₫  0 ₫ (đã hồi) 70%   ↺ REVERSED│  │
│ └──────────────────────────────────────────────────────────────────────────────┘  │
│ Phân trang: ← 1 2 3 … 7 →   20/50/100 · server-side            Tổng: 128 dòng     │
└────────────────────────────────────────────────────────────────────────────────────┘
```

Layout pattern W4 (KPI hàng đầu, mọi ô click ra worklist đã lọc) + W1 (DataTable compact 32px cho tiền). Chọn kỳ ở header đổi ngữ cảnh toàn surface (KPI + 4 tabs cùng kỳ — global context giữ nguyên khi chuyển tab).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| PeriodSelector | Select kỳ `commission_period`, default kỳ hiện tại | Hiển thị `OPEN/LOCKED` cạnh tên; kỳ LOCKED gắn icon khóa |
| KPI Card ×4 | MoneyDisplay delta so kỳ trước | Click → lọc tab Credit/Clawback tương ứng |
| WarningIndicator (banner) | Coverage vàng/đỏ; kỳ LOCKED; clawback trượt SLA | 3 phần bắt buộc: chuyện gì — ai làm gì — hạn còn lại; không dismiss |
| DataTable | variant compact, sort theo header, filter server-side | Cột tiền right-align `tabular-nums`; 1 StatusBadge/hàng |
| StatusBadge | Chuẩn 10 token §1 design system | Credit: ACTIVE/PAUSED/REVERSED; clawback: 5 trạng thái §2 |
| MoneyDisplay | variant plain VND; variant delta cho KPI | Cấm format thủ công; số rút gọn có tooltip full |
| WaitingOnIndicator | chip trong hàng clawback | "Chờ FIN_L2 xác nhận · 1 ngày"; SLA 3 ngày GDKD → warning ≥50%, breach đỏ |
| Pagination | 20/50/100, server-side | Theo R6 |

### 1.3. Cột chính (tab Credit thực nhận)

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Deal nguồn | `commission_credit.deal_id` | Link text (`DEAL-1042`) — drill-down S3 Deal Desk | Có | auto |
| Khách hàng | qua `deal` | Text | Có | auto |
| Đợt thực nhận | `payment_ref` (AR) + ngày | Text + date dd/MM/yyyy | Có | 140px |
| Thực nhận | `recognized_amount` | MoneyDisplay (loại bỏ pass-through NSQC) | Có | 150px |
| Credit | `recognized_amount × rate_applied × split_ratio` | MoneyDisplay | Có | 130px |
| Tỷ lệ | `split_ratio` | % (70% chủ / 30% hỗ trợ) | Không | 70px |
| Trạng thái | `status` | Badge ACTIVE (info) / PAUSED (pending) / REVERSED (rejected) | Không | 120px |

HĐ dài hạn >12 tháng: mỗi đợt thực nhận theo schedule = 1 dòng riêng; khách trả lệch lịch → nhãn riêng "lệch lịch — đối soát FIN".

**Badge trạng thái chu kỳ tính** (hiển thị trong sheet chi tiết + tooltip hàng): `computed` (Đã tính — info) → `clawback_check` (Chờ kiểm tra clawback — pending) → `approved` (Đã duyệt — approved) → `paid` (Đã trả — approved + icon ví `wallet`).

### 1.4. Hành động chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Click hàng credit | Mở Sheet S1 chi tiết credit | Deal nguồn, AR payment ref, breakdown split, timeline |
| Click deal nguồn | Điều hướng S3 Deal Desk | Ngữ cảnh deal gốc (Gate, quote) |
| Click hàng clawback | Mở Sheet S2 chi tiết clawback | Lý do, dòng trừ, chứng từ AR, waiting-on |
| Chọn kỳ LOCKED | Banner + toàn bộ form nhập vô hiệu kèm lý do "kỳ đã khóa ngày X bởi Y" | BR-SALES-907 |
| [Xuất báo cáo] | Export credit/clawback/attainment kỳ đã chọn | Phân quyền theo scope; HR_L1 chỉ xuất tổng hợp không PII |

Không có form nhập/sửa credit thủ công (BR-SALES-901 — cấm); không có form nhập attainment (BR-SALES-904 — cấm).

### 1.5. Phân Quyền

| Thành phần | Điều kiện hiển thị |
|-----------|------------------|
| View "Của tôi" (M1) | SALES_L1–L5, FIN (scope bản thân) — mặc định |
| View "Nhóm/Phòng/Toàn KD" (M2) | L3 (nhóm) / L4 (phòng) / L5 (toàn KD) — ẩn với L1/L2 (quyền ❌ theo FEAT §4, không disable) |
| Nút duyệt clawback / ApprovalCard | FIN (xác nhận) + GDKD SALES_L5 (duyệt) — ẩn với sales thường; L4/L5 menu hiện ẩn toàn phần chờ chốt vai [NEEDS_REVIEW #8 Navigation] |
| Tab Quota: nút "Trình điều chỉnh" | L3/L4 — ẩn với L1/L2 |
| Khóa kỳ (GDKD + FIN_L2 đồng chốt) | L5 + FIN_L2 — nút ẩn với vai khác; kỳ LOCKED → toàn form vô hiệu + banner lý do |
| PII: HR_L1 | Chỉ tổng hợp attainment không PII tài chính chi tiết |

Loading: skeleton 10 hàng + 4 ô KPI skeleton. Empty: "Chưa có credit trong kỳ này — credit sinh khi khách thanh toán thực nhận sau Gate 2" (intern/chưa phát sinh DT hiển thị mức hỗ trợ học việc theo bậc, tránh hiểu "0 ₫" là bị phạt). Error: hàng lỗi + retry; lỗi 403 vượt phạm vi PII → "Không có quyền xem dữ liệu này", không render dữ liệu (SC-006).

---

## 2. TABS

Global context (kỳ đã chọn + trạng thái kỳ + KPI header) giữ nguyên khi chuyển tab.

### Tab T1 — Credit thực nhận (mặc định)

- **Mục tiêu:** sale thấy từng đợt tiền khách trả sinh credit bao nhiêu, minh bạch theo thực nhận.
- **Thông tin:** bảng §1.3; breakdown split (chủ deal ≤70% / hỗ trợ 30%; SM/TPKD pre-sale ≤20%; tổng ≤100%); rate cấp áp tại thời điểm phát sinh (BR-SALES-905 — đọc từ policy effective-dated, không hardcode).
- **Components:** DataTable compact + quick chips (ACTIVE/PAUSED/REVERSED, đợt kỳ này) + Sheet S1.
- **Actions:** xem, drill-down deal nguồn; "Ghi split credit" (D1) — chỉ hiện với deal chưa qua Gate 2 và người có quyền; deal đã qua Gate 2 mở form chế độ chỉ đọc + chú thích "khóa sau Gate 2" (BR-SALES-903).
- **States:** loading/empty/error §1.5; deal treo do tranh chấp credit → badge "Tranh chấp — credit tạm treo" + banner nhãn "đang phân xử cấp SM/GDKD" (BR-SALES-908).
- **Permissions:** scope theo role (M1/M2); không ai sửa credit trực tiếp.
- **Quan hệ tab khác:** clawback liên kết ngược về dòng credit nguồn (T2 → T1).

### Tab T2 — Clawback (count-tab: số dòng chờ xử lý của tôi)

- **Mục tiêu:** hiển thị RÕ dòng trừ khi hoàn tiền/hủy và nợ quá hạn >90 ngày — lý do, số trừ, deal nguồn, đang chờ ai.
- **Thông tin:** bảng: Deal nguồn · Khách · Lý do (`CANCEL_REFUND` — hoàn phí theo tỷ lệ tiền hoàn / `OVERDUE_90` — hồi 100% phần chưa thu) · Số trừ (MoneyDisplay, dấu −, đỏ tiền + icon `undo-clawback`) · Chứng từ AR (hóa đơn/phiếu thu/công nợ — dẫn chiếu bắt buộc) · Kỳ áp · StatusBadge (`PENDING_CONFIRM` pending / `FIN_CONFIRMED` info / `APPROVED` approved / `APPLIED` approved + icon / `REJECTED` rejected) · WaitingOnIndicator.
- **Components:** DataTable compact; ApprovalCard cho người duyệt (FIN xác nhận số liệu đối chiếu sổ AR; GDKD duyệt trong SLA 3 ngày làm việc kể từ khi aging vượt 90); WarningIndicator banner khi trượt SLA ("quá SLA — đã escalate lên GDKD/BOD"; duyệt muộn vẫn ghi "duyệt quá SLA" vào audit log, không xóa dấu vết).
- **Actions:** FIN: "Xác nhận số liệu" (PENDING_CONFIRM → FIN_CONFIRMED); GDKD: "Duyệt" / "Từ chối" (D3 — từ chối bắt buộc lý do ≥10 ký tự). Nút duyệt vô hiệu kèm tooltip khi FIN chưa xác nhận (2 chặn: UI + API từ chối — SC-003). Cấm xóa dòng đã áp; sai sót xử lý bằng dòng điều chỉnh ngược có phê duyệt.
- **States:** loading skeleton; empty "Không có clawback trong kỳ"; error retry.
- **Permissions:** GET list: FIN + SALES (thấy clawback của phạm vi mình); POST approve: theo contract FIN_L1 [NEEDS_REVIEW: FEAT quy định FIN_L2 xác nhận + GDKD (SALES_L5) duyệt — contract API-ERP-041 chỉ khai POST approve FIN_L1, cần thống nhất vai].
- **Quan hệ tab khác:** mỗi clawback link về credit nguồn ở T1; dòng APPLIED làm giảm Thực nhận ròng KPI và cảnh báo kỳ kế tiếp.

### Tab T3 — Quota & Attainment

- **Mục tiêu:** theo dõi chỉ tiêu, attainment tự động và coverage dẫn tới hành động bổ sung lead.
- **Thông tin:** Quota gốc vs Quota điều chỉnh (song song, history các phiên điều chỉnh giữ nguyên); DTT thực nhận kỳ này; attainment % + hệ số quý (≥100% ×1,2 · 80–99% ×1,0 · 70–79% ×0,9 · <70% ×0,8); Coverage pipeline kỳ kế tiếp với màu: ≥3× on-track (xanh) / <3× VÀNG / <2× ĐỎ + "bắt buộc kế hoạch bổ sung lead" (SC-004 — đọc từ `attainment_snapshot`, không nhập tay).
- **Components:** KPI so sánh (MoneyDisplay + delta), ProgressTracker attainment (0% → quota), bảng thành viên nhóm/phòng cho M2 (mỗi dòng: thành viên · quota · attainment · coverage màu · StatusBadge) — click → lọc của thành viên đó (trong scope).
- **Actions:** L3/L4: "Trình điều chỉnh quota giữa kỳ" (D2 — nghỉ ốm/thai sản/chuyển vị trí, tỷ lệ ngày làm việc + ngày hiệu lực + lý do bắt buộc); L5: duyệt/từ chối đơn (ApprovalCard); mọi vai: xem.
- **States:** loading skeleton; empty "Chưa có quota cho kỳ này — liên hệ GDKD"; màu coverage luôn kèm icon + text (color-blind safe).
- **Permissions:** L1/L2 chỉ bản thân; L3 nhóm; L4 phòng; L5 toàn KD; HR_L1 tổng hợp không PII; BOD báo cáo. Đơn REJECTED hiển thị lý do ngay trên đơn cho người trình.
- **Quan hệ tab khác:** attainment ảnh hưởng rate hiệu lực hiển thị ở T4; coverage đỏ link ra S1 pipeline kỳ kế tiếp.

### Tab T4 — Thang hoa hồng & Kỳ

- **Mục tiêu:** tra thang hiệu lực tại thời điểm phát sinh credit và trạng thái khóa kỳ — nguồn sự thật là policy effective-dated.
- **Thông tin:** bảng thang theo cấp L1–L5 (rate khởi tạo 2,5% → 6,5%; L4/L5 +0,5% doanh thu đơn vị — DI-001 12/09/2026), phiên bản + hiệu lực từ/đến, hệ số attainment; danh sách kỳ hoa hồng: code (2026-Q3), OPEN/LOCKED, khóa lúc, khóa bởi (GDKD + FIN_L2 đồng chốt).
- **Components:** DataTable comfortable (dữ liệu tham chiếu); chọn phiên bản xem lịch sử (append-only, chỉ đọc — sửa = ban hành phiên bản mới, không sửa tay trên màn).
- **Actions:** xem; "Khóa kỳ" (L5 + FIN_L2 đồng xác nhận, dual-confirm kèm tóm tắt số dòng sẽ chốt) [NEEDS_REVIEW: thiếu endpoint khóa kỳ `commission_period`]; "Trình mở khóa" (L5 → BOD_CFO_CTO duyệt + audit log bất biến) [NEEDS_REVIEW: thiếu endpoint mở khóa kỳ].
- **States:** loading; empty; phiên bản quá khứ badge "Không còn hiệu lực".
- **Permissions:** đọc cho mọi vai trong scope; ban hành phiên bản thang: SYS_ADMIN trên phê duyệt BOD_CEO (ngoài surface này — link tới module cấu hình).
- **Quan hệ tab khác:** rate hiển thị ở T1 trỏ về phiên bản hiệu lực ở T4.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Ghi Split Credit | `UI-WEB-COMM-001-D1` | Form | T1 — nút "Ghi split" trên deal chưa qua Gate 2 |
| 2 | Đề xuất điều chỉnh quota | `UI-WEB-COMM-001-D2` | Form | T3 — L3/L4 trình đơn |
| 3 | Duyệt / Từ chối clawback | `UI-WEB-COMM-001-D3` | Confirm (tiền) | T2 — GDKD duyệt / từ chối dòng FIN_CONFIRMED |

### 3.1. Dialog: Ghi Split Credit (D1)

**Loại:** Form (tổng ≤100% validate realtime; sau Gate 2 mở chế độ chỉ đọc + chú thích "khóa sau Gate 2").

**Fields:**

| Nhãn | Loại | Bắt buộc | Validation |
|------|------|---------|------------|
| Deal | text (điền sẵn từ ngữ cảnh) | Có | Deal chưa qua Gate 2 |
| Chủ deal | Select người trong phòng | Có | 70% mặc định |
| Người hỗ trợ | Select người | Không | % hỗ trợ + chủ ≤100% |
| Pre-sale SM/TPKD | Select + % | Không | ≤20% credit deal (BR-SALES-903) |
| Tổng tỷ lệ | readonly | — | >100% → chặn lưu, tô lỗi field-level |

**Actions:** Lưu → [NEEDS_REVIEW: thiếu endpoint POST `commission_split` — FEAT có entity nhưng api-contract chưa khai] · Hủy → đóng.

### 3.2. Dialog: Đề xuất điều chỉnh quota (D2)

**Loại:** Form — state `DRAFT → PENDING_GDKD → APPROVED/REJECTED` (REJECTED sửa lại về DRAFT, giữ history).

**Fields:** Nhân sự (Select trong scope) · Kỳ (Select) · Lý do (Select: nghỉ ốm/thai sản/chuyển vị trí — bắt buộc) · Số ngày nghỉ (number) · Tỷ lệ ngày làm việc (auto tính, hiển thị công khai) · Ngày hiệu lực (date, bắt buộc) · Ghi chú (text).

**Actions:** Gửi duyệt → [NEEDS_REVIEW: thiếu endpoint POST `quota_adjustment_request`]; quota sau duyệt hiển thị song song quota gốc ở T3 (BR-SALES-906).

### 3.3. Dialog: Duyệt / Từ chối clawback (D3)

**Loại:** Confirm hành động tiền — Modal có ngữ cảnh (design system §4.10): tóm tắt dòng clawback + MoneyDisplay số trừ + dẫn chiếu hóa đơn/phiếu thu/công nợ + SLA còn lại; nút **Duyệt** (primary) / **Từ chối** (outline error, bắt buộc lý do ≥10 ký tự). Processing: spinner + khóa nút chống double-submit. Sau duyệt → toast + dòng cập nhật trạng thái; hành động tiền yêu cầu MFA step-up theo contract §6.2.

**Actions:** Duyệt → POST `/api/v1/erp/clawbacks/{id}/approve` (API-ERP-041) · Từ chối → cùng endpoint với body lý do.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Chi tiết credit + deal nguồn | `UI-WEB-COMM-001-S1` | Right 480px | Click hàng credit (T1) |
| 2 | Chi tiết clawback | `UI-WEB-COMM-001-S2` | Right 480px | Click hàng clawback (T2) |

### 4.1. Sheet: Chi tiết credit (S1)

Header: deal nguồn + khách + StatusBadge trạng thái credit; chu kỳ tính dạng stepper ngang (computed → clawback_check → approved → paid) gắn WaitingOn ("clawback_check · chờ sweep FIN"). Nội dung: thông tin đợt thanh toán (ngày, số tiền thực nhận MoneyDisplay, AR payment/invoice ref — loại trừ pass-through NSQC ghi chú riêng), rate áp + phiên bản policy (link T4), breakdown split (chủ/hỗ trợ/pre-sale kèm avatar), nếu PAUSED → WarningIndicator "Deal bị trả về từ Gate 2 — handoff lại thành công sẽ tiếp tục"; nếu REVERSED → link sang clawback nguồn (S2). Footer: nút "Mở Deal Desk" (điều hướng S3). Timeline 3 sự kiện cuối (inline).

### 4.2. Sheet: Chi tiết clawback (S2)

Header: mã clawback + StatusBadge + MoneyDisplay số trừ (đỏ tiền, icon `undo-clawback`). Nội dung: lý do (CANCEL_REFUND kèm tỷ lệ tiền hoàn / OVERDUE_90 kèm số ngày aging + bucket), deal nguồn + khách, credit gốc bị hồi, chứng từ AR bắt buộc (hóa đơn/phiếu thu/công nợ — link read-only sang S10 tab AR), kỳ áp (kỳ kế tiếp), WaitingOnIndicator ("Chờ FIN_L2 xác nhận · 1 ngày" / "Chờ GDKD duyệt · SLA còn 1 ngày" — warning khi ≥50%, breach đỏ kèm chuông + "đã escalate"), ghi chú "duyệt quá SLA" nếu trễ. Footer: nút Xác nhận (FIN) / Duyệt · Từ chối (GDKD, D3) — ẩn với vai không có quyền; vô hiệu kèm lý do khi chưa đủ điều kiện nghiệp vụ (chưa FIN xác nhận).

---

## 5. VIEW MODES

| Mode | UI-ID | Icon | Hiện khi nào |
|------|-------|------|-------------|
| Của tôi (mine) | `UI-WEB-COMM-001-M1` | `user` | Mặc định mọi vai có quyền xem của mình (L1–L5, FIN) |
| Nhóm / Phòng / Toàn KD (team) | `UI-WEB-COMM-001-M2` | `users` | L3 (nhóm) / L4 (phòng) / L5 (toàn KD) — ẩn với L1/L2; L4/L5 chờ chốt vai #8 |
| Mode duyệt (kiểm chứng) | `UI-WEB-COMM-001-M3` | `gate` | FIN_L1/L2 + GDKD: hàng đợi ApprovalCard clawback + duyệt trả hoa hồng — ẩn với sales |

### Mode: Của tôi (M1)
Scope cố định bản thân; KPI header cá nhân; T3 chỉ quota/attainment của mình; intern (L1) hiển thị mức hỗ trợ học việc thay bảng hoa hồng trống.

### Mode: Team (M2)
Scope theo cấp; T1/T2 thêm cột "Người hưởng credit"; T3 thành bảng thành viên với coverage màu per member; tổng hợp hàng đầu là SUM scope (MoneyDisplay). PII: mỗi sale trong bảng chỉ thấy được khi nằm trong scope — API chặn chéo, UI không render khi 403.

### Mode: Duyệt (M3)
Bố cục chuyển thành worklist approval (pattern W1): hàng đợi clawback PENDING_CONFIRM (FIN) và FIN_CONFIRMED (GDKD, sắp theo SLA còn lại — breach lên đầu); mỗi item là ApprovalCard: tóm tắt + số tiền + chứng từ + SLA + Duyệt/Từ chối (keyboard: ↑↓ · A duyệt · R từ chối · Enter mở context). Kèm hàng đợi "duyệt trả hoa hồng sau clawback_check" (POST `commissions/{id}/approve` — API-ERP-040, FIN_L1). Quyết định duyệt chỉ thực hiện trên web (mobile chỉ xem).

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint (API-ID) | Tham số / Body |
|---------|--------|-------------------|----------------|
| Tải credit list theo kỳ + scope | GET | `/api/v1/erp/commissions` (API-ERP-039) | `period=2026-Q3&sales_id=&status=computed\|clawback_check\|approved\|paid&page=1&limit=20` (server-side) |
| KPI header (credit/clawback/thực nhận ròng) | GET | `/api/v1/erp/commissions` (API-ERP-039) | aggregate client-side từ list kỳ (`period=`) — không endpoint summary riêng cho web |
| Duyệt trả hoa hồng sau clawback_check (M3 — FIN_L1) | POST | `/api/v1/erp/commissions/{id}/approve` (API-ERP-040) | `Idempotency-Key` + MFA step-up |
| Tải clawback list (T2) | GET | `/api/v1/erp/clawbacks` (API-ERP-041) | `period=&status=&sales_id=` — GET: FIN/SALES theo scope |
| Xác nhận / Duyệt / Từ chối clawback (D3, M3) | POST | `/api/v1/erp/clawbacks/{id}/approve` (API-ERP-041) | Body: quyết định + lý do (từ chối ≥10 ký tự); MFA step-up. [NEEDS_REVIEW: contract chỉ có 1 nút approve FIN_L1 trong khi FEAT yêu cầu 2 bước FIN_L2 xác nhận → GDKD duyệt SLA 3 ngày — cần bổ sung endpoint/step riêng cho bước xác nhận] |
| Tải quota + coverage/attainment (T3, KPI) | GET | `/api/v1/erp/quotas` (API-ERP-042) | `user_id=&period=` — coverage ≥3× per sales [NEEDS_REVIEW: công thức tử/mẫu số coverage — P3-01 Phụ lục A #7] |
| Ghi split credit (D1) | POST | [NEEDS_REVIEW: thiếu endpoint POST `commission_split` trong api-contract] | — |
| Trình/duyệt điều chỉnh quota (D2, T3) | POST | [NEEDS_REVIEW: thiếu endpoint `quota_adjustment_request` (submit + approve) trong api-contract] | — |
| Hàng đợi phân xử tranh chấp credit (T1 exception) | GET/POST | [NEEDS_REVIEW: thiếu endpoint `credit_dispute` trong api-contract] | — |
| Khóa kỳ / trình mở khóa kỳ (T4) | POST | [NEEDS_REVIEW: thiếu endpoint quản lý `commission_period` (lock/unlock)] | — |
| Nguồn sweep clawback tự tính (kiểm chứng job) | GET | `/api/v1/erp/jobs` (API-ERP-075) | Job clawback trong registry — dùng cho chú thích nguồn dữ liệu, không thao tác tại surface này |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-COMM-001` | Main Page | Surface Commission (mine/team) — route `/sales/commission` |
| `UI-WEB-COMM-001-T1` | Tab | Credit thực nhận (list credit theo đợt, split, drill-down deal nguồn) |
| `UI-WEB-COMM-001-T2` | Tab | Clawback (dòng trừ, lý do, chứng từ AR, workflow duyệt) |
| `UI-WEB-COMM-001-T3` | Tab | Quota & Attainment (gốc/điều chỉnh, coverage vàng/đỏ) |
| `UI-WEB-COMM-001-T4` | Tab | Thang hoa hồng & Kỳ (policy effective-dated, OPEN/LOCKED) |
| `UI-WEB-COMM-001-D1` | Dialog | Ghi Split Credit (trước Gate 2, tổng ≤100%) |
| `UI-WEB-COMM-001-D2` | Dialog | Đề xuất điều chỉnh quota giữa kỳ |
| `UI-WEB-COMM-001-D3` | Dialog | Duyệt / Từ chối clawback (confirm tiền + MFA step-up) |
| `UI-WEB-COMM-001-S1` | Sheet | Chi tiết credit + deal nguồn (chu kỳ tính, split, timeline) |
| `UI-WEB-COMM-001-S2` | Sheet | Chi tiết clawback (lý do, số trừ, chứng từ, waiting-on) |
| `UI-WEB-COMM-001-M1` | View Mode | Của tôi (mine — thực nhận cá nhân) |
| `UI-WEB-COMM-001-M2` | View Mode | Nhóm / Phòng / Toàn phòng KD (team + quota tracking) |
| `UI-WEB-COMM-001-M3` | View Mode | Mode duyệt/kiểm chứng (FIN + GDKD approval queue) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` | Upstream — FEAT-ERP-COMM-001 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — API-ERP-039…042 |
| Design system | `../../../design-system.md` | Upstream — MoneyDisplay, StatusBadge, ApprovalCard, WaitingOnIndicator |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S5, phân quyền `/sales/commission` |
| Deal Desk (deal nguồn) | `../qdd` | Liên kết drill-down S3 |
| Công nợ AR (chứng từ clawback) | `../../finance/arap` | Liên kết read-only S10 |
