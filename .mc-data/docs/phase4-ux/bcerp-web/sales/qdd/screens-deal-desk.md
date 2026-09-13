# Screen Group: Deal Desk (quote + duyệt + e-sign)

Implements: FEAT-ERP-QDD-001, FEAT-ERP-QDD-002

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `qdd` (MOD-QUOTATION-DEALDESK)
> **Tính năng:** FEAT-ERP-QDD-001..002
> **Route:** `/sales/deal-desk`
> **Main UI-ID:** `UI-WEB-DEAL-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-DEAL-001` |
| Route | `/sales/deal-desk` |
| Loại | Surface đa mode: List (mặc định) + Builder/Form + Detail + Approval + Contracting |
| FEAT-ID | FEAT-ERP-QDD-001 (quotation, margin check, chiết khấu phân cấp), FEAT-ERP-QDD-002 (HĐ/LOI/NDA, Brand Safety, e-sign) |
| Người dùng | SALES_L2 (NVKD — soạn/tự duyệt ≤5%/gửi khách), SALES_L4 TPKD (duyệt >5–15%), SALES_L5 GDKD (duyệt >15–20% + GM dưới ngưỡng + exception), BOD_CEO (duyệt >20%), SALES_L3 TNKD (xem nhóm), SALES_L1 (xem deal được gán), FIN_L1 (phối hợp soạn, read), OPS_AM (xem ràng buộc hợp đồng) |
| Pattern bố cục | W3 — content giữa + panel phải 360px (Navigation §4.5), density comfortable, panel collapse được |

**Checklist workflow context (Bước 0):** (A) Đối tượng: Quotation/Deal — draft → margin_check → discount_approval (vượt định mức → GM) → approved → contracting (e-sign) → signed;Contract kế tiếp: TEMPLATE → DRAFT → LEGAL_REVIEW → VALUE_APPROVAL → COUNTERPARTY → FINAL → SIGNED → AWAITING_ACTIVATION → ACTIVE. (B) Primary actors: NVKD soạn + duyệt theo ma trận + ký. (C) Related: FIN (đầu vào contracting, xác nhận nạp 100% NSQC), OPS_AM (ràng buộc sau ký), legal qua GDKD. (D) Waiting-on số 1: **SALES chờ GM duyệt chiết khấu** — mọi trạng thái chờ phải thấy "chờ ai, bao lâu rồi". (E) Cross-module: deal từ S1 My Pipeline (Gate 2 signed), Client 360 (S28), Handoff Bridge (S4 — `deal.signed`), tài chính (kích hoạt D+0). (F) Thông tin: GM theo nhóm dịch vụ, định mức tier, SLA duyệt, vòng sửa theo tier, hiệu lực 30/60 ngày, brand safety 7 tiêu chí, trạng thái chờ kích hoạt. (G) Quyết định: duyệt/từ chối chiết khấu, duyệt GM dưới ngưỡng, mở exception, từ chối vận hành, ký. (H) Exceptions: GM dưới ngưỡng, `DISCOUNT_OVER_LIMIT`, SLA quá hạn, quá 2 ngày chưa gửi, vượt vòng sửa, red-line diff, brand safety fail 1/7, GDKD trùng vai BOD. (J) Không tách page — 1 surface đa mode (quyết định consolidation S3, §2.0.5).

---

## 1. TRANG CHÍNH

### 1.1. Layout (W3 — content + panel phải 360px)

```
┌──────┬────────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ Sales > Deal Desk                                        [+ Tạo báo giá] [⋯]   │
│ rail ├────────────────────────────────────────────────────────────────────────────────┤
│ 60px │ Deal Desk — Báo giá · Duyệt chiết khấu · Hợp đồng                              │
│      ├────────────────────────────────────────────────────────────────────────────────┤
│      │ [Báo giá] [Chờ tôi duyệt ·4] [Hợp đồng & e-sign ·9]      [Tìm nhanh……] [Lọc ▾] │
│      │ Chips: (Chờ duyệt 18 ×)(GM dưới ngưỡng 3 ×)(SLA đỏ 2 ×)(Duyệt xong chưa gửi 1×)│
│      ├─────────────────────────────────────────────────────────────────┬──────────────┤
│      │ Mã · Khách        Deal        Giá trị        CK    GM  Trạng thái│ DEAL CONTEXT │
│      ├─────────────────────────────────────────────────────────────────┤ (360px)      │
│      │ QOT-0148 Toyota  T2·Ads     850.000.000 ₫  12%   17%⚠ Chờ duyệt │              │
│      │   Hải Dương                                           ⏳ GDKD 1ng│ QOT-0148     │
│      │ QOT-0147 Viettel T1·Rental  1.200.000.000 ₫   4%   22%  Đã duyệt│ Toyota H.Dương│
│      │   Post                                                           │              │
│      │ QOT-0144 SHB      B·MANAGED 640.000.000 ₫  18%   16%⚠ SLA đỏ   │ ● Duyệt:     │
│      │   ⚠ SLA vỡ 2h — GDKD quá hạn                                   │   NVKD ✓ 12% │
│      │ QOT-0141 TH True  D·SEO      180.000.000 ₫   3%   31%  Đã gửi  │   TPKD ✓ 5–15│
│      │   khóa 12/09 · còn hiệu lực 21 ngày                            │   ⏳ GDKD…    │
│      ├─────────────────────────────────────────────────────────────────┤ ● Chờ: GDKD  │
│      │ ← 1 2 3 … 8 →   20/50/100 · Tổng 148        Bulk: [Duyệt đã chọn]│   18 giờ    │
│      └─────────────────────────────────────────────────────────────────┴──────────────┤
└────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Mặc định mở tab Báo giá (list mode M1).** Chọn hàng → panel phải S1 hiển thị Deal Context; nhấn đúp/Enter → view mode M3 (chi tiết quote thay content giữa, giữ nguyên panel).
- **SLA breach tự nhảy đầu queue** kèm `--state-sla-breach` + icon chuông ( WaitingOnIndicator theo design-system §4.11).

### 1.2. Danh sách Báo giá (R6 grid)

| Thành phần | Cấu hình |
|------------|----------|
| Tìm nhanh | debounce 300ms — theo mã quote, tên khách, mã deal nguồn |
| Quick filter chips | Chờ duyệt · GM dưới ngưỡng · SLA đỏ/vỡ · Duyệt xong chưa gửi (quá 2 ngày LV) · Sắp hết hạn (≤7 ngày) · Của tôi — tháo được từng chip |
| Bộ lọc | `status`, tier khách, `serviceType` (RENTAL/MANAGED), owner, kỳ (`period`) |
| Sort | `createdAt`, `validUntil`, `discountPercent`, `gmPercent` (click header) |
| Pagination | server-side 20/50/100 |
| Bulk actions | Duyệt hàng loạt (chỉ row trong thẩm quyền duyệt của user, điều kiện đủ tầng trước đó) — bar trượt lên khi chọn ≥1 |
| Cột owner/status/exception | Owner (avatar+tên), Trạng thái (StatusBadge), Đang chờ ai (WaitingOnIndicator chip), GM dưới ngưỡng (WarningIndicator inline) |

### 1.3. Cột hiển thị

| Tên | Trường | Định dạng | Sort | Ghi chú |
|-----|--------|-----------|------|---------|
| Mã · Khách | `quotation.id`, `customerName` | Mã nghiệp vụ + link Client 360 | — | Mã quote, không UUID |
| Deal · Tier · Dịch vụ | `dealId`, `tier`, `serviceType` | Text + chip | Có | RENTAL/MANAGED phân màu nhạt |
| Giá trị | `amount` | MoneyDisplay, right-align, `tabular-nums` | Có | USD/VND không gộp (multi-currency) |
| CK % | `discountPercent` | Số + delta so định mức | Có | ≥5% hiện mũi tên cấp duyệt cần |
| GM % | `gmPercent` | Số + so ngưỡng nhóm dịch vụ | Có | **Che theo vai** (xem 1.5) |
| Trạng thái | `status` | StatusBadge: Nháp · Chờ duyệt · Đã duyệt · Đã gửi · Đã chấp nhận · Bị từ chối · Hết hạn | Có | Machine-state từ API, WEB không tự đoán |
| Đang chờ | approval chain hiện hành | WaitingOnIndicator | — | "chờ GDKD 18 giờ" — chip SLA màu |
| Hạn hiệu lực | `validUntil` | Ngày + còn X ngày | Có | Hết hạn → badge `--state-overdue` |

**Trạng thái loading/empty/error:** loading = skeleton 10 hàng; empty = EmptyState "Chưa có báo giá trong phạm vi của bạn" + CTA "Tạo báo giá" (ẩn với SALES_L1/L3 không có quyền soạn); error = hàng lỗi + retry, giữ filter đang có.

### 1.4. Hành động chính

| Sự kiện | Hành động | Kết quả |
|---------|-----------|---------|
| [+ Tạo báo giá] | Mở builder mode M2 (D1 nếu tạo từ deal có sẵn) | Form soạn theo định mức tier |
| Nhấn hàng / Enter | Mở view mode M3 + panel S1 | Chi tiết quote + approval chain |
| Row action "Gửi khách" | Dialog D2 | `SENT`, khóa vĩnh viễn read-only |
| Row action "Duyệt" (tab 2 / trong thẩm quyền) | Modal D3 | Duyệt/từ chối tầng hiện hành |
| Row action "Version mới" | Mở M2 với payload bản gửi, bộ đếm vòng sửa hiển thị | Duyệt lại toàn bộ |
| `deal.signed` | Banner "Deal đã ký — Submit handoff" link S4 | Chuyển sang Handoff Bridge |

### 1.5. Phân quyền trên list (PEP — ẩn, không disabled)

| Thành phần | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4/L5 | FIN_L1 | BOD_CEO |
|-----------|----------|----------|----------|-------------|--------|---------|
| Scope dữ liệu | deal được gán | của mình | nhóm | phòng/toàn bộ | toàn bộ (read) | toàn bộ (read) |
| [+ Tạo báo giá], "Gửi khách", "Version mới" | ẩn | hiện | ẩn | ẩn | hiện (phối hợp) | ẩn |
| Cột GM % chi tiết + giá vốn | chỉ GM% tổng, **không giá vốn** (API không trả) | GM% tổng, không giá vốn | GM% tổng | đầy đủ | đầy đủ | đầy đủ |
| Nút Duyệt (theo tầng ma trận) | ẩn | tự duyệt ≤5% | ẩn | TPKD 5–15% / GDKD 15–20% | ẩn | >20% |
| Cấu hình định mức/ngưỡng | ẩn — chỉ đọc tại CORE, không có trong surface này | | | | | |

Deal của chính mình: nút Duyệt **ẩn** với chủ deal (BR-QDD-004 cấm tự duyệt; GDKD kiêm BOD → hệ thống điều hướng người duyệt thay thế BOD_CFO_CTO, hiển thị chip "trùng vai — chuyển người duyệt thay thế").

---

## 2. TABS

Global context: header giữ mã quote + trạng thái + panel S1 khi chuyển tab (record context không mất).

### Tab T1 — Báo giá (`UI-WEB-DEAL-001-T1`, mặc định)

- **Mục tiêu:** quản lý toàn bộ quotation trong scope; nhìn ngay hàng chờ duyệt/gần hạn.
- **Thông tin + components:** grid §1.2–1.3; panel S1 khi chọn hàng.
- **Actions:** tạo (M2), mở M3, gửi khách (D2), version mới, bulk duyệt.
- **States:** đúng §1.2.
- **Permissions:** scope theo 1.5.
- **Quan hệ tab khác:** quote ở trạng thái cần quyết định của user xuất hiện đồng thời trong T2 (không nhân bản dữ liệu — filter theo approval chain).

### Tab T2 — Chờ tôi duyệt (`UI-WEB-DEAL-001-T2`, count-badge `{quotes_cho_duyet}`)

- **Mục tiêu:** inbox duyệt chiết khấu/GM theo đúng thẩm quyền ma trận của user đăng nhập — quyết định nhanh không mất context (approval-with-context).
- **Thông tin:** mỗi entry là 1 DiscountApproval chờ: mã quote, khách, giá trị, CK % + chênh lệch định mức, GM % vs ngưỡng nhóm dịch vụ, SLA còn lại (TPKD 8h LV · GDKD 1 ngày + nhận định chiến lược · BOD 2 ngày + văn bản), lý do của NVKD.
- **Components:** danh sách ApprovalCard (design-system §4.10, keyboard A/R/↑↓/Enter) + panel S2 mở đồng thời khi focus card.
- **Actions:** Duyệt (D3), Từ chối (D3, lý do ≥10 ký tự), "Mở exception" (D4 — chỉ GDKD), delegate không có trong lane (không phải feature — không hiển thị).
- **States:** idle/processing (khóa nút chống double-submit)/done (card collapse vào feed, focus chuyển card kế tiếp); quá SLA → `--state-sla-breach` + đã escalate cấp trên (chip "đã escalate").
- **Permissions:** mỗi user chỉ thấy tầng thuộc thẩm quyền (L2 tự duyệt ≤5% tức thời không vào queue; L4: 5–15%; L5: 15–20% + GM dưới ngưỡng + exception; BOD_CEO: >20% + ngoài ma trận BOD-sponsored). Chủ deal không thấy nút duyệt deal của mình.
- **Quan hệ:** quyết định ở T2 cập nhật ngay cột "Đang chờ" trong T1; đủ tầng → quote chuyển `APPROVED`.

### Tab T3 — Hợp đồng & e-sign (`UI-WEB-DEAL-001-T3`)

- **Mục tiêu:** vòng đời contracting từ quotation APPROVED: soạn HĐ/LOI/NDA từ mẫu chuẩn, Brand Safety, duyệt giá trị, e-sign, theo dõi chờ kích hoạt.
- **Thông tin:** grid hợp đồng — cột: Mã HĐ · Khách (link Client 360) · Loại (NDA/LOI/RENTAL/MANAGED) · `serviceType` (bất biến) · Giá trị · Version hiện hành (v0.x/v1.x/v2.0) · Trạng thái (Soạn · Legal review · Chờ duyệt giá trị · Đối tác duyệt · Bản cuối · Ký · **Chờ kích hoạt** · Active · Chấm dứt · Lưu trữ) · Điều kiện còn thiếu (nạp 100% NSQC / ký đủ ≤7 ngày — đếm ngược) · Owner.
- **Components:** grid + chip "Chờ kích hoạt" (`--state-pending`, banner WarningIndicator "đã ký nhưng chưa nạp đủ 100% NSQC — block tạo chiến dịch, còn X ngày hạn ký"); panel S3 (Brand Safety 7 tiêu chí), S4 (diff red-line); row action "Mở luồng ký" chỉ bật khi checklist 7/7 pass + đủ duyệt ma trận.
- **Actions:** soạn từ mẫu (chỉ mẫu đã legal review xuất hiện — SYS_ADMIN quản danh mục), điền checklist Brand Safety, "Từ chối vận hành" (D5), duyệt giá trị (D3 dùng chung), e-sign (D6), xem trạng thái kích hoạt (điều kiện còn thiếu — đọc từ FIN/CORE, read-only).
- **States:** `LEGAL_REVIEW` treo khi mẫu đối tác/red-line → đếm ngày thẩm định GDKD + luật sư 5–7 ngày LV; `AWAITING_ACTIVATION` không có đường tắt; SIGNED khóa cứng — mọi nút sửa ẩn, chỉ còn "Phụ lục/HĐ mới".
- **Permissions:** soạn/checklist: SALES_L2; review checklist + duyệt ngưỡng thấp/trung: SALES_L3/L4/L5; HĐ giá trị lớn/red-line/mẫu đối tác: GDKD trình + BOD_CEO; ký e-sign đại diện BC: SALES_L3 (theo ủy quyền giá trị)/SALES_L5/BOD_CEO; OPS_AM thấy bản tóm tắt ràng buộc (read); FIN_L1 thấy trạng thái nạp (read).
- **Quan hệ:** đầu vào bắt buộc là quotation `APPROVED` (BR-QDD-012 — quote chưa duyệt không thấy nút soạn HĐ); sau `SIGNED` → banner link S4 Handoff Bridge.

---

## 3. DIALOGS

| UI-ID | Dialog | Nội dung bắt buộc | Ghi chú |
|-------|--------|-------------------|---------|
| `UI-WEB-DEAL-001-D1` | Tạo báo giá / tạo version mới | Chọn deal nguồn (từ S1), `serviceType` (RENTAL/MANAGED — tách cấu phần phí ngay từ lúc soạn), currency bind rate card, loại hiệu lực 30/60 ngày (60 chỉ HĐ năm/đa giai đoạn) | Tạo version mới hiển thị "Vòng sửa 2/4 (tier B)" + chặn khi vượt nếu chưa có exception |
| `UI-WEB-DEAL-001-D2` | Gửi khách (khóa bản gửi) | Preview cấu phần giá, xác nhận "sau khi gửi, bản này khóa vĩnh viễn read-only", hiển thị `rateCardVersionId` traceable | Chỉ bật khi `APPROVED` + còn hiệu lực; thiếu tầng duyệt → nút ẩn + WarningIndicator giải thích tầng còn thiếu |
| `UI-WEB-DEAL-001-D3` | Quyết định duyệt chiết khấu / GM | Tóm tắt: CK % vs định mức tier, GM % vs ngưỡng, lý do NVKD; Duyệt: GDKD bắt buộc nhận định chiến lược, BOD gắn văn bản; Từ chối: lý do ≥10 ký tự | Gọi API-ERP-013; lỗi `DISCOUNT_OVER_LIMIT` (409) → banner "vượt định mức tier — chờ GM duyệt"; `SOD_VIOLATION` → lỗi không tự duyệt |
| `UI-WEB-DEAL-001-D4` | Mở exception (chỉ GDKD) | Loại (vượt vòng sửa / pilot 1 tháng ≤60 ngày / tái ký giữ bảng giá cũ lần 2), lý do bắt buộc, mục tiêu chuyển đổi (pilot) | Gắn nhãn "Pilot" + ngày hết hạn đặc biệt lên quote |
| `UI-WEB-DEAL-001-D5` | "Từ chối vận hành" (Brand Safety) | Tick tiêu chí vi phạm trong 7 tiêu chí, mô tả, tự notify legal + OPS_AM | Fail ≥1/7 → dừng, không sang PROPOSAL, chặn luồng ký |
| `UI-WEB-DEAL-001-D6` | Xác nhận e-sign | Bên ký, vai, xác nhận audit trail (thời gian/IP/người ký — Luật GDTĐT 2023 + NĐ 91/2022) | Sau ký thành công → `SIGNED` lock cứng; sự cố CA → quay lại `E_SIGNING`, không có "coi như đã ký" |

---

## 4. SHEETS

| UI-ID | Panel | Nội dung |
|-------|-------|----------|
| `UI-WEB-DEAL-001-S1` | **Deal Context Panel** (360px phải, collapse được — W3) | WaitingOn hiện tại ("chờ GDKD duyệt 18 giờ"), ProgressTracker stages quote (Draft→Margin check→Duyệt CK→Đã duyệt→Đã gửi→Ký→Handoff), Timeline 3 sự kiện cuối, liên kết: Client 360 (`/sales/clients/:id`), deal nguồn (`/sales/pipeline`), Handoff (`/ops/handoff` — khi đã signed), hợp đồng liên quan (tab T3) |
| `UI-WEB-DEAL-001-S2` | **Approval Context Panel** (720px — approval-with-context) | Deal gốc: cấu phần giá đầy đủ (giá vốn/GM chi tiết chỉ với vai đủ quyền), version history + diff với bản trước, approval chain từng tầng (decided/decidedAt/reason/slaDeadline), lý do chiết khấu của NVKD, activity quote. Focus card T2 → panel mở đồng bộ |
| `UI-WEB-DEAL-001-S3` | **Brand Safety Checklist** (480px) | 7 tiêu chí pass/fail + bằng chứng đính kèm từng mục; fail → đỏ + gợi ý D5; chưa đủ 7 mục → chặn mở luồng ký (chặn 2 tầng UI + API) |
| `UI-WEB-DEAL-001-S4` | **Diff red-line** (480px) | So sánh phiên bản với template: điều khoản red-line (không cam kết KPI cứng, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa → cảnh báo; luồng chuyển yêu cầu GDKD + luật sư 5–7 ngày LV |

Ưu tiên drawer/panel đúng ngữ cảnh quyết định: duyệt ở T2 không rời màn (S2), kiểm tra rủi ro ở T3 không rời màn (S3/S4).

---

## 5. VIEW MODES

Cùng surface `/sales/deal-desk` — chuyển mode đổi content giữa, header + panel S1 giữ ngữ cảnh.

| UI-ID | Mode | Vào khi nào | Điểm chính |
|-------|------|-------------|-----------|
| `UI-WEB-DEAL-001-M1` | List (mặc định) | Mở route | §1 |
| `UI-WEB-DEAL-001-M2` | Builder/Form | [+ Tạo báo giá], "Version mới", edit bản `DRAFT` | Form max 960px: cấu phần giá theo `serviceType`, tự tính GM theo nhóm dịch vụ (agency ≥15% · ads ≥20% · SEO ≥35% · web/design ≥30%), cảnh báo đỏ GM dưới ngưỡng + chỉ cho submit vào luồng duyệt GM; media pass-through giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ; bind `rateCardVersionId` hiệu lực; đồng hồ hiệu lực 30/60 ngày; nút "Tự duyệt ≤5%" tức thời khi GM đạt ngưỡng (SALES_L2); cấm trường "tặng kèm không định giá" (BR-QDD-009) |
| `UI-WEB-DEAL-001-M3` | View/Read-only | Nhấn hàng; mọi bản `SENT`/`ACCEPTED`/`EXPIRED`/`REJECTED` | Read-only vĩnh viễn với bản đã gửi; hiển thị version history, bộ đếm vòng sửa, approval chain, audit trail (người gửi/thời điểm), CTA "Version mới" (chủ deal) |
| `UI-WEB-DEAL-001-M4` | Approval | Tab T2 | ApprovalCard + S2; duyệt theo tầng, chống tự duyệt |
| `UI-WEB-DEAL-001-M5` | Contracting | Tab T3 chọn HĐ | Timeline phiên bản (Draft→Legal→Duyệt giá trị→Counterparty→Final→Signed→Chờ kích hoạt→Active), S3/S4, trạng thái chờ kích hoạt kèm điều kiện còn thiếu (read từ FIN/CORE) |

---

## 6. API ENDPOINTS

Endpoint thật từ `phase3-architecture/technical-specs/api-contract.md` (§6.1 COMP-ERP-001). List endpoint chuẩn `page/limit/sort/order` server-side.

| Nút/Thành phần | API | Method + Path | Ghi chú |
|----------------|-----|---------------|---------|
| Grid tab T1 | API-ERP-011 | GET `/api/v1/erp/quotations` | filter `status,tier,owner_id,period` + search; sort `createdAt/validUntil/discountPercent/gmPercent` |
| View M3 + panel S1/S2 | API-ERP-011 | GET `/api/v1/erp/quotations/{id}` | detail margin + approval chain; trường giá vốn chỉ trả cho vai đủ quyền (che tại API) |
| Tạo quote / version mới (M2, D1) | API-ERP-010 | POST `/api/v1/erp/quotations` | gắn lead + tier; `margin_check` định mức theo tier |
| Submit duyệt, gửi khách, ghi nhận chấp nhận (D2, M2) | API-ERP-012 | POST `/api/v1/erp/quotations/{id}/transitions` | draft→margin_check→discount_approval→approved→contracting→signed/rejected; response trả trạng thái mới + `guards_passed` |
| Duyệt chiết khấu phân cấp (D3, T2) | API-ERP-013 | POST `/api/v1/erp/quotations/{id}/discount-approval` | SALES_L2/L3 trong định mức, GM vượt định mức; 409 `DISCOUNT_OVER_LIMIT` |
| E-sign hoàn tất + brand safety (D6, T3) | API-ERP-014 | POST `/api/v1/erp/contracts/{id}/esign-complete` | body provider-agnostic `{provider_ref, signed_document_uri}`; phát event `deal.signed`; [NEEDS_REVIEW] e-sign provider + đường dẫn (P3-01 Phụ lục A #4) |
| Timeline / audit trail (S1, M3) | API-CORE-029 | GET `/core/audit/events` | filter `actor/object/time/action`, pagination 20/100; lượt query tự ghi audit |

[NEEDS_REVIEW: thiếu endpoint list/detail hợp đồng — GET `/api/v1/erp/contracts` + `/contracts/{id}` (versions, diffReport, BrandSafetyChecklist, SignatureEvent, trạng thái AWAITING_ACTIVATION) chưa có trong api-contract; tab T3 và panel S3/S4 hiện chỉ có API-ERP-014 cho bước ký. Cần bổ sung trước khi triển khai T3.]
[NEEDS_REVIEW: thiếu endpoint thư viện mẫu chuẩn — GET contract templates (chỉ mẫu đã legal review) và danh mục mẫu của SYS_ADMIN.]
[NEEDS_REVIEW: thiếu endpoint ghi nhận khách chấp nhận riêng nếu tách khỏi API-ERP-012 — hiện dùng transitions SENT→ACCEPTED.]

---

## 7. UI-ID Registry

| UI-ID | Tên | Loại | Tab/Mode |
|-------|-----|------|----------|
| `UI-WEB-DEAL-001` | Deal Desk — surface chính | list (đa mode) | — |
| `UI-WEB-DEAL-001-T1` | Tab Báo giá | tab | T1 |
| `UI-WEB-DEAL-001-T2` | Tab Chờ tôi duyệt (inbox chiết khấu/GM) | tab | T2 |
| `UI-WEB-DEAL-001-T3` | Tab Hợp đồng & e-sign | tab | T3 |
| `UI-WEB-DEAL-001-D1` | Dialog tạo báo giá / version mới | dialog | T1/M2 |
| `UI-WEB-DEAL-001-D2` | Dialog gửi khách (khóa bản gửi) | dialog | T1/M3 |
| `UI-WEB-DEAL-001-D3` | Modal quyết định duyệt chiết khấu / GM | dialog | T2/T3 |
| `UI-WEB-DEAL-001-D4` | Dialog mở exception (vòng sửa / pilot) | dialog | T2 |
| `UI-WEB-DEAL-001-D5` | Dialog "Từ chối vận hành" (Brand Safety) | dialog | T3 |
| `UI-WEB-DEAL-001-D6` | Modal xác nhận e-sign | dialog | T3 |
| `UI-WEB-DEAL-001-S1` | Deal Context Panel 360px | sheet | mọi mode |
| `UI-WEB-DEAL-001-S2` | Approval Context Panel 720px (approval-with-context) | sheet | T2 |
| `UI-WEB-DEAL-001-S3` | Panel Brand Safety Checklist 480px | sheet | T3 |
| `UI-WEB-DEAL-001-S4` | Panel Diff red-line 480px | sheet | T3 |
| `UI-WEB-DEAL-001-M1` | List mode | view-mode | mặc định |
| `UI-WEB-DEAL-001-M2` | Builder/Form mode | view-mode | soạn quote |
| `UI-WEB-DEAL-001-M3` | View/Read-only mode | view-mode | chi tiết |
| `UI-WEB-DEAL-001-M4` | Approval mode | view-mode | duyệt |
| `UI-WEB-DEAL-001-M5` | Contracting mode | view-mode | hợp đồng |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/quotation-dealdesk` | FEAT-ERP-QDD-001/002 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.1 COMP-ERP-001 |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
| Surface liên quan | `../crm/screens-pipeline.md` (S1 — deal nguồn), `../crm/screens-client-360.md` (S28), `../../ops/honb/screens-handoff-bridge.md` (S4) | Link |


## Bổ sung Cross-Module Status (stakeholder F-D-05 — R5)

> Panel "Trạng thái tiền & hoa hồng theo deal" trong Deal 360 pane (nguồn integration-map §7.A):

| Khối | Dữ liệu | Endpoint (thật) |
|---|---|---|
| Payment status | AR invoice của deal + aging + trạng thái khớp tiền | API-ERP-030 (đã map) |
| Commission theo deal | computed/clawback/approved/paid + thực nhận | API-ERP-039, API-ERP-042 (đã map) |
| Hiển thị | Summary chip trong pane + drill-down sheet; link S10 (AR tab) + S5 (commission) | — |
