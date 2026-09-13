# Screen Group: Approval Inbox (FIN)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `wallet`
> **Tính năng:** FEAT-ERP-WALLET-003..006, FEAT-ERP-ARAP-003..004
> **Route:** `/finance/approvals`
> **Main UI-ID:** `UI-WEB-APPR-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-WALLET-003 (dual approval điều chỉnh số dư/đổi tỷ giá/hoàn tiền), FEAT-ERP-WALLET-004 (điều chỉnh phát sinh từ ticket mismatch — duyệt tại đây), FEAT-ERP-WALLET-006 (resolve cảnh báo AML khi hoàn tiền), FEAT-ERP-ARAP-003/004 (lệnh chi theo ngưỡng 5/50/200tr + delegate).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Workspace | Finance (`/finance/*`) |
| Đối tượng nghiệp vụ | Lệnh tiền chờ FIN: (1) dual approval điều chỉnh ví/đổi tỷ giá/hoàn tiền (RiskAdjustmentRequest — `PENDING`/`STEP1_APPROVED`), (2) lệnh chi theo ngưỡng (PaymentOrder), (3) cảnh báo AML chờ resolve |
| Vai trò chính | FIN_L1 (DUAL bước 1), FIN_L2 (SINGLE/DUAL bước 2, lệnh chi <50tr), BOD_CFO_CTO (<200tr + vượt ngưỡng), BOD_CEO (≥200tr — escalation cuối) |
| Workflow stage | Lệnh: `PENDING → (STEP1_APPROVED) → APPROVED → COMPLETED` / `REJECTED`; lệnh chi: ngưỡng FIN_L2 → CFO → CEO → disburse (FIN_L1) |
| Liên quan | OPS đề xuất (người đề xuất ≠ người duyệt — SoD); SYS_ADMIN cấu hình delegate; kỳ khóa chặn thực thi (`PERIOD_LOCKED`); AML hold chặn thực thi dù đủ chữ ký |

**Checklist workflow (Bước 0):** A. Lệnh tiền giữ hộ cần 2 lớp kiểm soát (SoD 4 vai + dual approval). B–C. Actors: FIN_L1/L2/CFO/CEO duyệt; OPS đề xuất (chỉ xem lệnh của mình). D. Máy trạng thái do CORE trả về — Web không suy diễn. E. Cross-module: MOD-ARAP-PAYMENT (lệnh chi), MOD-ADACCOUNT-CC (hard stop — link S9), AML rule engine, Alert Center. F. Thông tin cần: object + số tiền (MoneyDisplay, breakdown gross theo k snapshot) + người đề xuất + bước duyệt hiện tại + chữ ký đã có + ngưỡng áp dụng + AML state + SLA. G. Quyết định: duyệt / từ chối (lý do ≥10 ký tự) / delegate. H. Actions: A, R, Enter, Space (bulk), delegate, MFA step-up. I. Exceptions: SLA đỏ 2h, SoD violation, thiếu biên bản (đổi tỷ giá), AML hold, kỳ khóa. J. Không chuyển màn — duyệt tại chỗ trên card, context qua SidePanel.

---

## 1. TRANG CHÍNH

### 1.1. Layout — keyboard-first inbox (Pattern W1, density compact)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Finance / Approval Inbox          [Ủy quyền (delegate)]   [Tìm nhanh____] [Bộ lọc ▾]│
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Tất cả ·12 │ Dual approval ví ·5 │ Lệnh chi ·4 │ Cảnh báo AML ·3        (count-tab) │
│ Chips: (Chờ tôi ·7 ×) (SLA đỏ ·2 ×) (Vượt ngưỡng CFO ·1 ×) (Hôm nay ×)              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ▌►[ADJ] Điều chỉnh số dư +2.150,00 USD · CTCP An Phát · USD · TK Meta                │
│ ▌  Đề xuất: L.M.H (FIN_L1) 10:32 · k=1,1124 · lý do: bù ticket RC-217                │
│ ▌  Slot 1 ✓ FIN_L1 10:45  →  Slot 2 ⏳ đang chờ FIN_L2              [MFA] [SLA 1h24]│
│ ▌  [A Duyệt]  [R Từ chối]  [Enter Context]                                      ▢   │
│ ─────────────────────────────────────────────────────────────────────────────────   │
│  [CHI] Lệnh chi #PO-1042 · Chi phí nền tảng Meta T8 · 187.500.000 ₫                 │
│  Ngưỡng 50–200tr → chờ BOD_CFO_CTO · ⏰ Chờ CFO 3h12 — SLA ĐỎ (escalation)          │
│  [A Duyệt]  [R Từ chối]  [Enter Context]                                        ▢   │
│ ─────────────────────────────────────────────────────────────────────────────────   │
│  [AML] T2 ĐỎ · 3 lệnh nạp/24h ≥200tr · Khách XYZ · giao dịch HOLD · SLA 24h còn 9h  │
│  Người đề xuất bị chặn điều tra (SoD) · [Enter Context] → [Resolve (dual)]      ▢   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Bulk: [Đã chọn 2] [Duyệt hàng loạt (MFA)] [Từ chối hàng loạt] [Delegate…]           │
│ Phân trang 20/50/100 (server-side)                          Phím [?] = cheat-sheet  │
└─────────────────────────────────────────────────────────────────────────────────────┘
                     │ Enter → SidePanel 480px đẩy content phải (không overlay)
                     ▼
```

**Loading/Empty/Error:** loading = skeleton 10 card; empty = EmptyState "Không có lệnh chờ bạn duyệt" + chip tháo filter; error = khối lỗi + retry (lỗi tiền không tự biến mất khi reload).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| ApprovalCard (§4.10) | variant `dual-approval` + `step-up MFA` | Card đang focus viền trái 3px primary; SLA breach tự nhảy đầu queue |
| Count-tabs (§4.4) | nhãn + số pending | Đếm theo vai người dùng — FIN_L1 không thấy tab Lệnh chi |
| Quick chips | tháo được từng chip | Nguồn: filter server-side |
| WaitingOnIndicator (§4.11) | chip trong card | "Chờ CFO 3h12" — màu `sla-warning` ≥50%, `sla-breach` kèm icon chuông |
| MoneyDisplay (§4.12) | multi-currency + delta so định mức | USD hiển thị gốc, không gộp với VND (BR-W01) |
| Bulk bar | trượt lên khi chọn ≥1 | Hành động tiền — mọi lệnh vẫn qua engine kiểm tra riêng |

### 1.3. Trường trên ApprovalCard (bắt buộc theo design-system)

| Trường | Nguồn | Định dạng |
|--------|-------|-----------|
| Loại + tóm tắt object + link | `type`, object ref | Chip [ADJ]/[FX]/[REFUND]/[CHI]/[AML] + link về S7/S10 |
| Số tiền | `amount`, `currency` | MoneyDisplay + chênh lệch % so định mức/ngưỡng |
| Người đề xuất + thời điểm | `createdBy`, `createdAt` | Avatar + tên + vai (SoD: người duyệt nhìn thấy để xác nhận ≠ mình) |
| 2 slot chữ ký (dual) | ApprovalSignature | "FIN_L1 ✓ 10:45 · FIN_L2 đang chờ" — nút Duyệt slot 2 khóa đến khi đủ slot trước |
| Ngưỡng áp dụng (lệnh chi) | policy ngưỡng 5/50/200tr | "50–200tr → CFO" |
| SLA còn lại | SLA engine | ⏱ đếm ngược; đỏ 2h — quá hạn `--state-sla-breach` |
| Cờ [MFA] | endpoint `[STEP-UP]` | Badge "yêu cầu MFA" trên mọi lệnh tiền |

### 1.4. Hành động + phím tắt

| Phím / Nút | Hành động | Kết quả |
|-----------|-----------|---------|
| ↑ ↓ | Chuyển ApprovalCard | Roving tabindex; không reload danh sách |
| A | Duyệt lệnh đang focus | Nếu lệnh tiền → mở MFA step-up (D2) rồi ghi chữ ký; sau duyệt focus chuyển card kế tiếp |
| R | Từ chối | Mở D1, focus thẳng textarea lý do (≥10 ký tự bắt buộc) |
| Enter | Mở context SidePanel 480px (S1) | Esc đóng, trả focus về card vừa mở |
| Space | Chọn card (bulk) | Bulk bar trượt lên |
| ? | Cheat-sheet phím tắt | Modal liệt kê phím |
| Delegate (nút) | Ủy quyền khi vắng | Mở D3 |

### 1.5. Phân Quyền (hide khi không có quyền — PEP)

| Thành phần | FIN_L1 | FIN_L2 | BOD_CFO_CTO | BOD_CEO |
|-----------|--------|--------|-------------|---------|
| Dual ví bước 1 (DUAL) | ✅ duyệt | Ẩn (chỉ xem) | Ẩn | Ẩn |
| Dual ví bước 2 / SINGLE | Ẩn nút duyệt (khớp tiền ≠ duyệt) | ✅ | ✅ | Ẩn |
| Lệnh chi <50tr | Ẩn | ✅ | ✅ | Ẩn |
| Lệnh chi 50–200tr / vượt ngưỡng | Ẩn | Ẩn nút (chỉ thấy "chờ CFO") | ✅ | ✅ |
| Lệnh chi ≥200tr | Ẩn | Ẩn | Ẩn nút (chỉ thấy "chờ CEO") | ✅ |
| Duyệt lệnh do chính mình đề xuất | ❌ nút ẩn + backend `SOD_VIOLATION` | ❌ | ❌ (đề xuất của CFO vượt ngưỡng cao nhất → CEO duyệt — compensating control) | ❌ |
| Resolve AML (dual FIN_L1+L2) | ✅ | ✅ | Xem oversight | Ẩn |
| Tabinbox tương ứng | Dual ví + AML | Tất cả trừ slot đã chiếm | + Lệnh chi ngưỡng CFO | Lệnh chi ≥200tr |

Lưu ý máy trạng thái: khi DUAL, lệnh chưa qua bước 1 không hiện card cho người duyệt bước 2; khi chế độ chuyển SINGLE↔DUAL giữa chừng, lệnh treo xử lý theo mode ghi trên lệnh tại thời điểm tạo.

---

## 2. TABS (count-tabs theo loại lệnh — global context giữ nguyên khi chuyển tab)

| Tab | UI-ID | Nội dung | Hiện với vai |
|-----|-------|---------|--------------|
| Tất cả | `UI-WEB-APPR-001-T1` | Hợp nhất mọi lệnh chờ đúng vai, sort SLA gần breach lên đầu | Tất cả |
| Dual approval ví | `UI-WEB-APPR-001-T2` | Điều chỉnh số dư / đổi tỷ giá / hoàn tiền (`PENDING`/`STEP1_APPROVED`) | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Lệnh chi | `UI-WEB-APPR-001-T3` | PaymentOrder theo ngưỡng + trạng thái disburse | FIN_L2, BOD_CFO_CTO, BOD_CEO (+FIN_L1 xem lệnh mình cần disburse) |
| Cảnh báo AML | `UI-WEB-APPR-001-T4` | AML T1–T6 vàng/đỏ chờ resolve — resolve hoàn tiền cần dual | FIN_L1 (xem), FIN_L2 (điều tra), BOD_CFO_CTO (quyết định đỏ) |

**R7 tab completeness:**

- **T2 Dual approval ví:** mục tiêu — duyệt tuần tự đúng cấp bậc (bước 1 ACCOUNTANT/FIN_L1 → bước 2 CHIEF_ACCOUNTANT/FIN_L2, không đảo, không 1 người 2 bước). Thông tin: old→new value, lý do + reason code, biên bản đính kèm (FX_CHANGE bắt buộc — thiếu biên bản card hiển thị WarningIndicator "chưa hợp lệ để duyệt"), giao dịch nạp gốc (REFUND — beneficiary chỉ từ danh sách TK đã KYC, trùng tên pháp nhân). Components: ApprovalCard dual + SidePanel S1. Actions: A/R + MFA. States: `PENDING`/`STEP1_APPROVED`/`APPROVED`/`REJECTED`/`DISPUTED`/AML hold (badge cam "AML hold — không thực thi dù đủ chữ ký"). Permissions: bảng §1.5. Quan hệ: duyệt xong → S7 ledger cập nhật; mismatch nguồn → link ticket ở T2 của S7.
- **T3 Lệnh chi:** mục tiêu — duyệt đúng ngưỡng 5/50/200tr, đúng vai, đúng thứ tự (FIN_L2 → CFO → CEO, delegate khi vắng). Thông tin: số tiền + nhà cung cấp + báo giá đính kèm + hợp đồng + số dư ví khả dụng theo đúng tiền tệ (thiếu dư → WarningIndicator chặn). Actions: A duyệt (MFA), R từ chối, disburse (chỉ FIN_L1, khác người duyệt). States: `PENDING` theo tầng ngưỡng → `APPROVED` → `DISBURSED`. Permissions: nút duyệt tầng nào chỉ hiện cho vai tầng đó; escalation timeout tự nhảy tầng trên + chip `sla-breach`.
- **T4 Cảnh báo AML:** mục tiêu — xử lý cảnh báo T1–T6 đúng SLA 24h, SoD điều tra (người đề xuất/nhập giao dịch không được điều tra — nút disabled kèm lý do). Thông tin: rule chạm ngưỡng + breakdown tính toán (gross theo snapshot), khách/TKQC/giao dịch, nhãn EDD "ngưỡng siết 50%", giao dịch đang HOLD. Actions: nhận điều tra, đóng vàng (lý do bắt buộc), nâng vàng→đỏ, resolve (dual FIN_L1+L2 — `AML_FLAGGED`), BOD quyết định đỏ (lý do văn bản, lưu vĩnh viễn). Permissions: FIN_L2 điều tra; BOD quyết định; không ai tắt monitoring. Quan hệ: hold nhả tự động khi alert đóng; hồ sơ tại T5 S7 (chi tiết điều tra).

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Từ chối lệnh | `UI-WEB-APPR-001-D1` | Form confirm | Phím R / nút Từ chối |
| 2 | MFA step-up | `UI-WEB-APPR-001-D2` | Confirm OTP | Trước khi ghi duyệt lệnh tiền |
| 3 | Ủy quyền (delegate) | `UI-WEB-APPR-001-D3` | Form | Nút "Ủy quyền" — người duyệt vắng |
| 4 | Xác nhận duyệt hàng loạt | `UI-WEB-APPR-001-D4` | Confirm | Bulk bar, chỉ cùng loại lệnh |

### 3.1. Dialog Từ chối (D1)
**Loại:** Confirm bắt buộc lý do. Focus thẳng textarea. Validation: lý do ≥10 ký tự (đếm ký tự hiển thị), không cho submit khi thiếu. Hiển thị tóm tắt lệnh + người đề xuất (sẽ nhận thông báo kèm lý do). Actions: [Xác nhận từ chối] → API duyệt với `decision=reject`; [Hủy] — Esc.

### 3.2. Dialog MFA step-up (D2)
**Loại:** Confirm OTP. Nhập mã TOTP → `POST /core/auth/mfa/step-up` purpose `payment_approval`; thành công → retry request duyệt kèm claim step-up; thất bại ≥5 → thông báo theo chính sách khóa, không có đường "vượt MFA tạm thời".

### 3.3. Dialog Ủy quyền (D3)
**Loại:** Form. Fields: người được ủy quyền (AssigneePicker lọc đúng vai trong data-scope), phạm vi (loại lệnh), thời hạn. Backend: `GET/PUT /core/policies/delegates` `[STEP-UP]`. Không có "duyệt hộ không ủy quyền" — mọi chữ ký ghi danh tính người thật.

### 3.4. Dialog Duyệt hàng loạt (D4)
**Loại:** Confirm có ngữ cảnh. Điều kiện: chỉ card cùng loại + đã đủ slot trước + không có AML hold + không có card do chính mình đề xuất (được loại bỏ tự động, hiển thị danh sách loại trừ). Mỗi lệnh vẫn đi qua engine ngưỡng/SoD/dual riêng — một lệnh lỗi không chặn các lệnh khác, báo cáo kết quả từng dòng.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Context lệnh | `UI-WEB-APPR-001-S1` | Right panel 480px (đẩy content) | Enter / click card |

### 4.1. Sheet: Context lệnh (S1)
**Kích thước:** 480px; giữ context inbox (không overlay toàn màn).
**Nội dung (tabs trong panel):** (a) *Chi tiết* — MoneyDisplay breakdown gross/net/fee/VAT theo k snapshot (không có ô sửa % — snapshot chôn vào lệnh), oldValue→newValue, căn cứ/biên bản (xem/tải), giao dịch nạp gốc + beneficiary KYC (refund), chain duyệt ProgressTracker (slot 1/2 + ngưỡng CFO/CEO), WaitingOn + SLA; (b) *Timeline* — 3 sự kiện cuối (mỗi chữ ký hiển thị tên + vai + timestamp); (c) *Liên quan* — ví nguồn (link T3 S7), ticket mismatch (link T2 S7), TKQC (link S9), audit trail (API-CORE-030). **Footer sticky:** nút Duyệt / Từ chối (theo quyền) — cùng luồng D1/D2. Esc đóng, focus trả về card.

---

## 5. VIEW MODES

| Mode | UI-ID | Mô tả | Hiện khi nào |
|------|-------|-------|--------------|
| Inbox card (mặc định) | `UI-WEB-APPR-001-M1` | ApprovalCard dọc, keyboard-first, tối ưu duyệt tuần tự | Default |
| Bảng compact | `UI-WEB-APPR-001-M2` | DataTable compact: object · tiền · StatusBadge · WaitingOn · SLA — rà soát/số lượng lớn, hành động qua row menu | Toggle người dùng, persist |

---

## 6. API ENDPOINTS

Mọi endpoint tiền: header `Idempotency-Key` + MFA step-up claim (`mfa_level>=stepup`). Danh sách dưới lấy từ `api-contract.md`.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải inbox theo vai | GET | `[NEEDS_REVIEW: thiếu endpoint GET list approvals cho web — hiện chỉ có API-MBI-011 GET /api/v1/mbi/approvals (BFF mobile); đề xuất GET /api/v1/erp/approvals?type=&state=PENDING&priority=&page=&limit=20]` | Filter `type` (wallet_adjustment / payment_order / aml_flag), sort SLA |
| Duyệt/từ chối dual approval ví | POST | `/api/v1/erp/wallet-transactions/{id}/approvals` (API-ERP-023) | Body `{decision, step_up_token, note}`; cùng người 2 bước → `SOD_VIOLATION`; gắn cờ AML → `AML_FLAGGED` |
| Duyệt lệnh chi theo ngưỡng | POST | `/api/v1/erp/payment-orders/{id}/approve` (API-ERP-034) | FIN_L2 <50tr → CFO <200tr → CEO ≥200tr; delegate khi vắng; cùng người 2 chân → `SOD_VIOLATION` |
| Giải ngân sau duyệt | POST | `/api/v1/erp/payment-orders/{id}/disburse` (API-ERP-035) | FIN_L1 thực thi, khác người duyệt |
| Resolve cảnh báo AML | POST | `/api/v1/erp/aml-flags/{id}/resolve` (API-ERP-028) | Dual FIN_L1+L2; GET `/api/v1/erp/aml-flags` cho T4 |
| MFA step-up | POST | `/api/v1/core/auth/mfa/step-up` (API-CORE-003) | `purpose: "payment_approval"` |
| Delegate | GET/PUT | `/core/policies/delegates` (API-CORE-023) `[STEP-UP]` | FIN_L2 delegate FIN; CFO kiêm CTO vắng → CEO (compensating control) |
| Timeline lệnh (S1) | GET | `/core/audit/objects/:objectId/timeline` (API-CORE-030) | Feed chữ ký + từng bước |
| Ledger ví nguồn (S1) | GET | `/api/v1/erp/wallets/{id}/ledger` (API-ERP-021) | `period, entry_type, source` |
| SLA/escalation chip | GET | `/core/alerts/instances` (API-CORE-043) | Filter severity/status — nguồn chip SLA đỏ |

Ràng buộc hiển thị lỗi: 409 `APPROVAL_REQUIRED` / `SOD_VIOLATION` / `AML_FLAGGED` / `PERIOD_LOCKED` — toast lỗi tiền không tự đóng; nút hành động không render khi thiếu vai (PEP), không hiển thị disabled để tránh gây nhiễu.

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-APPR-001` | Main Page | Approval Inbox FIN — keyboard-first worklist |
| `UI-WEB-APPR-001-T1` | Tab | Tất cả lệnh chờ |
| `UI-WEB-APPR-001-T2` | Tab | Dual approval ví (điều chỉnh/đổi tỷ giá/hoàn tiền) |
| `UI-WEB-APPR-001-T3` | Tab | Lệnh chi theo ngưỡng |
| `UI-WEB-APPR-001-T4` | Tab | Cảnh báo AML chờ resolve |
| `UI-WEB-APPR-001-D1` | Dialog | Từ chối — lý do ≥10 ký tự |
| `UI-WEB-APPR-001-D2` | Dialog | MFA step-up OTP |
| `UI-WEB-APPR-001-D3` | Dialog | Ủy quyền (delegate) |
| `UI-WEB-APPR-001-D4` | Dialog | Xác nhận duyệt hàng loạt |
| `UI-WEB-APPR-001-S1` | Sheet | SidePanel context lệnh 480px |
| `UI-WEB-APPR-001-M1` | View Mode | Inbox card (keyboard-first) |
| `UI-WEB-APPR-001-M2` | View Mode | Bảng compact |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |


> **Accessibility note (audit 4.8 — WCAG 2.1.4 Character Key Shortcuts):** phím tắt A/R/? bind ở MỨC CONTAINER inbox (chỉ khi một ApprovalCard đang focus), tự vô hiệu khi `event.target` là input/textarea/contenteditable; toggle "Bật/tắt phím tắt" trong Settings (persist). Textarea lý do từ chối: `aria-describedby` trỏ helper "≥10 ký tự", `aria-invalid` khi lỗi, bộ đếm `aria-live="polite"`; nút Từ chối luôn enable + validate on submit, focus về lỗi đầu tiên (không dùng disabled-only signal).
