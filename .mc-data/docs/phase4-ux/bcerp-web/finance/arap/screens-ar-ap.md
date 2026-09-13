# Screen Group: Công nợ & Giải ngân (tabs: AR / AP-Giải ngân / HĐĐT)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `arap`
> **Tính năng:** FEAT-ERP-ARAP-001..007
> **Route:** `/finance/ar-ap` (tab: `?tab=ar|ap|hddt`)
> **Main UI-ID:** `UI-WEB-ARAP-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-ARAP-003 (công nợ AR/AP + aging bucket + nhắc nợ + tranh chấp + cờ clawback — T1, phần AP của T2), FEAT-ERP-ARAP-004 (duyệt chi/giải ngân: ngưỡng 5/50/200tr, SoD 4 vai, delegate, chi khẩn, nạp định kỳ tuần — T2), FEAT-ERP-ARAP-005 (HĐĐT TT78/2021 + NĐ123/2020: draft → issued → delivered, điều chỉnh chuẩn — T3), FEAT-ERP-ARAP-001 (hàng đợi duyệt hợp nhất + escalation SLA + delegate có nhãn — T2), FEAT-ERP-ARAP-002 (lệnh độc quyền CFO: hiển thị trạng thái liên quan tại T2, surface thao tác riêng — không nhân bản), FEAT-ERP-ARAP-007 (phí nền tảng + nghĩa vụ thuế VAT/FCT — nhóm AP riêng trong T2, read-only theo API-ERP-038), FEAT-ERP-ARAP-006 (connector VAS: trạng thái sync + degraded trong header/T3; cấu hình tại S27 Settings DI-004 — không nhân bản console).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Finance (`/finance/*`) — OPS không thấy dòng tiền chi tiết (chỉ trạng thái TKQC theo BR-FIN-603); khách đọc invoice qua Portal P3 |
| Đối tượng nghiệp vụ | ARInvoice (hóa đơn phải thu), PaymentReceipt (thanh toán thực nhận), ReminderLog (nhắc nợ), DisputeTicket (tranh chấp), AgingSnapshot (bucket — chỉ đọc), APBill/PlatformFeeRecord (phải trả nền tảng), DisbursementVoucher/PaymentOrder (lệnh chi), DelegateGrant, TaxObligation (VAT/FCT), EInvoice (HĐĐT) + IssuanceBatch + AdjustmentDoc |
| Vai trò chính | FIN_L1 (tạo hóa đơn, ghi thanh toán — MFA, nhắc nợ, tạo lệnh chi, phát hành HĐĐT, disburse ≠ người duyệt), FIN_L2 (duyệt ≤50tr, chữ ký 1 dual, cấu hình nhắc/duyệt tranh chấp ngưỡng nhỏ, đề xuất điều chỉnh), BOD_CFO_CTO (dual approval 50–200tr, CFO+CEO ≥200tr, duyệt cấu hình thuế, delegate FIN_L2), BOD_CEO (nhánh ≥200tr bắt buộc) |
| Workflow stage | AR: invoice → aging (0–30/31–60/61–90/>90) → dunning → paid (chỉ khi khớp tiền); AP: PAYMENT_DUE_SOON (T-7/T-3) → lệnh chi DRAFT → PENDING/DUAL/CEO_PENDING → APPROVED → READY_TO_PAY (Hard Stop) → PAID (disburse) → CLOSED (hậu kiểm 24h với chi khẩn); HĐĐT: ELIGIBLE → PENDING_ISSUANCE → ISSUED (mã CQT) → ADJUSTED/REPLACED/CANCELLED → ARCHIVED |
| Liên quan | S6 Approval Inbox (duyệt lệnh chi — cùng machine-state), S7 Ví & Đối soát (khớp tiền/hard stop, khóa kỳ), S9 TKQC Registry (hard stop gate read-only góc OPS), S27 Integration & Settings (connector VAS + tham số DI-004), S28 Client 360 (khách), Portal P3 (khách nhận invoice), S24 Alert Center (escalation cuối) |

**Checklist workflow (Bước 0):** A. Công nợ phải thu/phải trả + lệnh chi (cổng trước khi tiền rời công ty) + HĐĐT pháp lý; số dư là dẫn xuất từ ledger — web không sửa trực tiếp. B. FIN_L1/L2 là người dùng chính; BOD duyệt theo ngưỡng; CFO độc quyền nhóm lệnh riêng. C. OPS chỉ thấy trạng thái hard stop TKQC (S9); SALES thấy cờ clawback qua commission (S5); khách qua Portal P3. D. Stages do core enforce (ngưỡng, SoD, hard stop, XML) — Web chỉ render machine-state + chặn submit UI. E. Cross-module: ví/hard stop (S7), HĐĐT đối ứng AR, VAS connector (GW), commission (clawback), SLANOT (SLA duyệt 24/48/72h). F. Thông tin: bucket aging, hạn theo hợp đồng từng khách, snapshot tỷ giá ngày duyệt, trạng thái khớp tiền, chuỗi chữ ký duyệt, mã CQT + hash XML. G. Quyết định: duyệt chi đúng cấp, nhắc nợ, đánh dấu tranh chấp, phát hành/điều chỉnh HĐĐT, delegate. H. Actions: tạo hóa đơn, ghi thanh toán (khớp tiền), gửi nhắc, tạo/duyệt/disburse lệnh chi, phát hành lô HĐĐT. I. Exceptions: thiếu báo giá >20tr, SOD_VIOLATION, thiếu khớp tiền (giữ READY_TO_PAY), quá SLA escalate, connector fail (WAITING_CONNECTION), clawback >90 ngày, tranh chấp tách aging. J. 1 surface 3 tabs + header context chung — không tách page (S12 đã merge vào tab theo consolidation).

---

## 1. TRANG CHÍNH

### 1.1. Layout (Pattern W1 worklist + dải KPI; density compact — màn hình tiền)

Mặc định mở tab **Công nợ AR** (`?tab=ar` mặc định; tab cuối dùng được ghi nhớ theo user). Header context chung ba tab: kỳ kế toán + tổng exposure.

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ Finance / Công nợ & Giải ngân        Kỳ kế toán: T08/2026 · ĐÃ KHÓA · Ledger cập nhật 16:05 │
│ Exposure: AR phải thu 2,84 tỷ ₫ · AR quá hạn 412 tr (18 HĐ) · AP đến hạn ≤7 ngày 1,15 tỷ ₫  │
│                                              [Xuất báo cáo ▾]   [+ Tạo mới ▾]              │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ ⚠ Banner vàng: 3 HĐ quá hạn >90 ngày gắn cờ clawback 100% — SALES/HR đối chiếu hoa hồng    │
│    thực nhận [Xem 3 HĐ]   ·   2 AP nền tảng đến hạn T-7 — đề xuất duyệt chi [Mở tab AP]    │
│ ℹ VAS connector (DI-004): khỏe — sync 15:40 · HĐĐT gửi mã qua cùng connector (cấu hình S27)│
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ Công nợ AR │ AP & Giải ngân (7 chờ duyệt) │ HĐĐT (2 lỗi mã)                                │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ AGING (tính từ hạn thanh toán — core, chỉ đọc):                                            │
│ ┌────────────┬────────────┬────────────┬──────────────────────────┐  ┌──────────────────┐  │
│ │ 0–30 ngày  │ 31–60 ngày │ 61–90 ngày │ >90 ngày ● ĐỎ            │  │ Đang tranh chấp  │  │
│ │ 1,62 tỷ ₫  │ 640 tr ◐   │ 168 tr ◐   │ 412 tr · clawback: 3 🚩  │  │ 96,5 tr (2 HĐ)   │  │
│ └────────────┴────────────┴────────────┴──────────────────────────┘  └──────────────────┘  │
│  (click bucket → lọc danh sách; tranh chấp TÁCH KHỎI aging thường — không cộng trộn)       │
│ Tìm nhanh [__________]  Chips: (Quá hạn ×)(Clawback ×)(Khách: An Phát ×)   [Bộ lọc ▾]      │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ Số HĐ · Khách/HĐ     Còn nợ (MoneyDisplay)  Hạn         Bucket  Nhắc   Trạng thái          │
│ INV-0912 CTCP An Phát   384.000.000 ₫       10/08/2026  31–60   ×2    ● QUÁ HẠN             │
│ INV-0901 Công ty Bee     96.500.000 ₫       02/07/2026  >90     ×4    ● QUÁ HẠN 🚩CLAWBACK  │
│ INV-0930 DEF Media HĐ03 148.900.000 ₫       30/09/2026  0–30    —     ⏸ ĐANG TRANH CHẤP     │
│ Row actions: [Chi tiết] [Ghi thanh toán] [Nhắc nợ] [⋯]                                     │
│ Phân trang 20/50/100 (server-side) · sort theo click header                                │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Loading/Empty/Error:** loading = skeleton 10 hàng cho bảng + skeleton dải aging; empty = EmptyState theo tab kèm CTA (AR: "Chưa có hóa đơn trong bộ lọc — [Tạo hóa đơn]"); error = khối lỗi + retry từng khối (aging, bảng riêng biệt); lỗi business từ core (`PERIOD_LOCKED`, `SOD_VIOLATION`, `HARD_STOP_ACTIVE`, `MISSING_QUOTATION`) hiển thị WarningIndicator kèm link hành động, không tự biến mất khi reload. Dữ liệu degraded: nhãn "dữ liệu tới HH:MM" — không cho kết luận chốt số (M2).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| Header context | Kỳ kế toán (trạng thái khóa read-only — khóa/mở kỳ tại S7) + exposure AR/AP | Giữ nguyên khi chuyển tab — global context record |
| WarningIndicator banner | Clawback + AP đến hạn T-7 + connector VAS | 3 phần: chuyện gì — cần ai — hạn; clawback không dismiss |
| Dải aging buckets | 4 bucket + khối tranh chấp riêng | 0–30 neutral/info · 31–60 `--state-sla-warning` · 61–90 warning đậm · >90 `--state-overdue` (error) + icon cờ; màu + chữ + icon (color-blind safe) |
| Count-tab | Nhãn tab kèm số pending ("AP & Giải ngân · 7") | Đếm từ approval engine core |
| DataTable compact | Filter bar + quick chips + sort + pagination 20/50/100 server-side | Cột tiền right-align `tabular-nums`; column config persist |
| MoneyDisplay | plain VND; multi-currency (nguyên tệ + quy VND snapshot) | Mọi số tiền bắt buộc dùng component này — cấm format thủ công |
| StatusBadge | Trạng thái AR/AP/HĐĐT theo token §1 design-system | Tối đa 1 badge chính/hàng; clawback là icon cờ + tooltip |
| WaitingOnIndicator | Chip dòng lệnh chi: ai giữ, chờ bao lâu | SLA 24/48/72h: neutral → warning ≥50% → breach kèm chuông |
| KPI strip | 4 ô: chờ duyệt của tôi · quá SLA · AP đến hạn 7 ngày · hạn mức tuần còn lại | Operational — click → filter worklist tương ứng |

---

## 2. TABS

| Tab | UI-ID | Nội dung | Feat |
|-----|-------|---------|------|
| Công nợ AR | `UI-WEB-ARAP-001-T1` | Invoice list + aging buckets + dunning/nhắc nợ + trạng thái paid/overdue + clawback + tranh chấp | 003 |
| AP & Giải ngân | `UI-WEB-ARAP-001-T2` | AP nền tảng đến hạn + lệnh chi draft → ngưỡng 5/50/200tr → SoD 4 vai → disbursed; delegate; chi khẩn; nạp tuần | 001, 002, 003 (AP), 004, 007 |
| HĐĐT | `UI-WEB-ARAP-001-T3` | TT78/2021 + NĐ123/2020: draft → issued → delivered; lô phát hành; điều chỉnh chuẩn; connector VAS DI-004 | 005, 006 (trạng thái) |

**R7 tab completeness:**

- **T1 Công nợ AR — UI-WEB-ARAP-001-T1:** mục tiêu — theo dõi phải thu đến khi tiền về thật (chỉ khớp tiền mới giảm dư nợ, "khách hứa chuyển" không có giá trị). **Thông tin:** dải aging 4 bucket + khối tranh chấp tách riêng (BR-007 — hai khối không cộng trộn); bảng hóa đơn: số HĐ, khách + hợp đồng (hạn tính theo đúng chu kỳ hợp đồng từng khách — BR-008, trace về hợp đồng), số tiền gốc (ngoại tệ hiển thị song song nguyên tệ + quy VND theo snapshot), đã thu, còn nợ (MoneyDisplay), hạn thanh toán, bucket, số lần nhắc + kênh + lần cuối (từ ReminderLog), trạng thái (`OPEN`/`PARTIALLY_PAID`/`SETTLED`/`OVERDUE`/`DISPUTED`), cờ clawback (>90 ngày — tự động, "đã giải tỏa" kèm timestamp khi khách trả muộn), HĐĐT đối ứng (link T3). Hóa đơn khách >15 ngày quá hạn hiển thị cảnh báo nội bộ "đề xuất PAUSE sau 15 ngày · escalate sau 30 `[KXN-22 — chờ chốt]`" — hệ thống KHÔNG tự dừng dịch vụ trước khi chốt. **Components:** dải aging (click lọc), DataTable compact, MoneyDisplay aging variant (số ngày quá hạn + bucket), StatusBadge, WarningIndicator clawback, quick chips. **Actions:** tạo hóa đơn (D1 — FIN_L1; tự động từ `deal.signed` schedule + manual), ghi thanh toán (D2 — FIN_L1, MFA, chỉ khi khớp tiền Hard Stop; một phần → `PARTIALLY_PAID`, aging tiếp tục từ hạn gốc; không rõ hóa đơn → FIFO theo hạn + ghi chú, không map được → ticket có duyệt), nhắc nợ manual (D3) + cron tự động theo lịch cấu hình (D4 — FIN_L2 đề xuất, BOD phê duyệt mốc ngày + mẫu nội dung + người nhận; mọi lần nhắc ghi ReminderLog — nhắc không vết không tính), ghi nhận liên lạc đòi nợ + thỏa thuận gia hạn (D3 — FIN_L1 nhập thô/FIN_L2), tranh chấp (D5 — FIN_L2 mở ticket, tách khỏi aging + dừng nhắc tự động; kết luận FIN_L2 đề xuất + CFO duyệt), điều chỉnh/gia hạn công nợ chỉ qua reversal (FIN_L2 đề xuất, CFO duyệt — nút "sửa số dư" không tồn tại), xuất báo cáo aging chuẩn (D10). **States:** skeleton/empty/error như §1.1; hóa đơn `DISPUTED` hiển thị người phụ trách + hạn khép. **Permissions:** xem aging toàn bộ — FIN_L2/BOD; FIN_L1 thấy khách được gán; SYS_ADMIN/OPS ❌; cấu hình nhắc — FIN_L2 (BOD phê duyệt); tranh chấp — FIN_L2; reversal — FIN_L2 đề xuất + CFO duyệt; xuất ngoài chuẩn — BOD sau phê duyệt CEO. **Quan hệ tab khác:** cột HĐĐT link T3 (điều chỉnh AR chạm hóa đơn đã phát hành bắt buộc đi kèm điều chỉnh hóa đơn chuẩn — BR-009); thanh toán chỉ mở khi khớp tiền tại S7 (link "Mở khớp tiền"); khách link S28; cờ clawback là nguồn sự thật cho S5 commission.

- **T2 AP & Giải ngân — UI-WEB-ARAP-001-T2:** mục tiêu — cổng bắt buộc trước khi tiền rời công ty: chứng từ đủ hồ sơ → duyệt đúng ngưỡng → đủ chữ ký SoD → Hard Stop → FIN_L1 disbursed; không có "duyệt trước, bổ sung sau". **Thông tin:** 2 khối — (a) **AP nền tảng phải trả**: nền tảng, TKQC, số tiền nguyên tệ + quy VND, hạn thanh toán, trạng thái `PAYMENT_DUE_SOON` (cảnh báo T-7/T-3 theo cấu hình nền tảng) / `AP_OVERDUE` (bật cảnh báo FIN_L2/CFO), nhóm "nghĩa vụ thuế" riêng (VAT đầu ra trên phí dịch vụ + FCT theo cấu hình có phê duyệt — read-only từ API-ERP-038, nhắc kỳ kê khai; thuế quá hạn → cảnh báo đỏ CFO); phí hiển thị theo hồ sơ đã map giao dịch gốc — phí unmapped là discrepancy ticket, không nằm aging thường. (b) **Lệnh chi (payment orders)**: mã, loại (thường / khẩn / định kỳ đã cam kết / bổ sung hạn mức tuần), số tiền (nguyên tệ + quy VND theo snapshot tỷ giá NGÀY DUYỀT — bất biến, chênh tỷ giá sau không đổi cấp duyệt), mã dự án/khách hoặc overhead + lý do, cấp duyệt hiện tại + người giữ (WaitingOnIndicator + đếm ngược SLA 24/48/72h), Hard Stop status (lệnh liên quan TKQC — "đã khớp tiền" / "chờ khớp" link S7), trạng thái (`DRAFT` → `PENDING_APPROVAL` → `DUAL_PENDING`/`CEO_PENDING` → `APPROVED` → `READY_TO_PAY` → `PAID` → `CLOSED`; `ESCALATED`/`REJECTED`/`CANCELLED`). **Luồng ngưỡng 5/50/200 triệu (DI-001):** ≤5tr FIN_L2 · >5–50tr FIN_L2 · >50–200tr FIN_L2 (chữ ký 1) + CFO dual · >200tr hoặc hợp đồng năm CFO + CEO; CFO là người đề xuất → chỉ CEO duyệt (compensating control kiêm nhiệm); quá SLA tự escalate cấp trên + alert đỏ — escalate không tự thông qua. **SoD 4 vai:** đề xuất ≠ khớp tiền (FIN_L1) ≠ duyệt chi ≠ ghi sổ; cùng người 2 chân → submit bị chặn + `SOD_VIOLATION` log cho CFO. **Thiếu báo giá → chặn:** checklist tự động tại form tạo (D6) — chứng từ đính kèm bắt buộc; ≥2 báo giá khi >20 triệu (thiếu → nút Submit disabled + lỗi nêu rõ thiếu gì); mã dự án/khách bắt buộc, không gắn được → chọn overhead + lý do. **Delegate khi vắng:** CFO ủy quyền cho cá nhân FIN_L2 cụ thể (D7), hạn mức ≤ FIN_L2, tối đa 14 ngày, tự hết hạn; mọi lệnh do delegate duyệt gắn nhãn "theo ủy quyền #id"; delegate không duyệt chứng từ do chính mình tạo; lệnh độc quyền CFO (mở kỳ/backfill/hạn mức tín dụng — FEAT-002) KHÔNG ủy quyền được — hiển thị nhãn "chờ CFO thao tác từ xa", surface thao tác riêng không nhân bản tại đây. **Chi đặc biệt:** chi khẩn (nền tảng sắp khóa TKQC) — FIN_L2 + CFO qua kênh khẩn, SLA 4h, quá 4h escalate + alert đỏ, hậu kiểm chứng từ 24h (fail → alert CFO, xử lý reversal không sửa đè); chi định kỳ (SaaS năm, retainer) — duyệt 1 lần đầu năm, tự giải ngân theo lịch công khai (mỗi lần tạo instance riêng tham chiếu duyệt gốc); nạp nền tảng tuần — duyệt gộp kế hoạch trước đầu tuần, FIN_L1 thực hiện giao dịch con không duyệt lại, sắp vượt hạn mức tuần → duyệt bổ sung đúng cấp (FIN_L2 ≤50tr, CFO >50tr), phần vượt chờ duyệt bổ sung mới giải ngân. **Actions:** tạo lệnh chi (D6 — API-ERP-033 kiểm số dư ví khả dụng + báo giá), gửi duyệt (API-ERP-034), disburse (API-ERP-035 — FIN_L1, khác người duyệt, chỉ khi `READY_TO_PAY`), cấu hình delegate (D7 — CFO), duyệt bổ sung hạn mức, xuất lịch giải ngân định kỳ. Nút Duyệt/Từ chối chính nằm ở **S6 Approval Inbox** — tại T2 hiển thị trạng thái + link "Mở S6"; khoản do chính mình tạo ẩn nút duyệt. **States:** lệnh `APPROVED` nhưng Hard Stop chưa thỏa → giữ badge "đã duyệt — chờ khớp tiền" (hai điều kiện tách bạch rõ); chi khẩn hiển thị huy hiệu "KHẨN — SLA 4h" đầu hàng đợi. **Permissions:** tạo — FIN_L1 (giao dịch con kế hoạch tuần)/FIN_L2; duyệt ≤50tr — FIN_L2; dual 50–200tr — FIN_L2 + CFO; ≥200tr/HĐ năm — CFO + CEO bắt buộc; chi khẩn — FIN_L2 + CFO; delegate — chỉ CFO; disburse — FIN_L1 ≠ người duyệt; xem — FIN/BOD theo scope; SYS_ADMIN không duyệt/sửa gì. **Quan hệ tab khác:** lệnh chi thanh toán AP gắn hóa đơn trong aging (T1 — thanh toán làm giảm dư nợ chỉ khi khớp tiền); chứng từ chi đối ứng doanh thu phải khớp HĐĐT (T3 — không khớp → discrepancy bắt buộc giải trình); hard stop nằm ở S7; escalation cuối cùng ở S24.

- **T3 HĐĐT — UI-WEB-ARAP-001-T3:** mục tiêu — phát hành/tra cứu/điều chỉnh hóa đơn điện tử đúng TT78/2021 + NĐ123/2020: chỉ từ chứng từ đã khóa kỳ, chỉ trên doanh thu phí dịch vụ/markup — tuyệt đối không xuất hóa đơn cho tiền giữ hộ (nút + tùy chọn không tồn tại, attempt bị chặn + log). **Thông tin:** hàng đợi "đủ điều kiện phát hành" (`ELIGIBLE` — chứng từ đã đối soát/khóa kỳ + doanh thu khớp thanh toán thực nhận); danh mục HĐ: ký hiệu/số, khách + MST (KH nước ngoài dùng mã thuế tương đương đã chuẩn hóa từ KYC), tiền phí dịch vụ + VAT tách bạch giá vốn media (ghi lẫn phí nền tảng → chặn khi tạo), kỳ dịch vụ, thời điểm lập theo nhóm dịch vụ (NĐ123 — hoàn thành cung cấp dịch vụ; cấu hình theo nhóm dịch vụ có phê duyệt `[CẦN CHỐT SỐ]`), trạng thái (`PENDING_ISSUANCE`/`ISSUED_WITH_CODE`/`DRAFT_ERROR`/`WAITING_CONNECTION`/`ADJUSTED`/`REPLACED`/`CANCELLED`/`ARCHIVED`), mã CQT + ngày phát hành, hash kiểm tra toàn vẹn + WORM ≥10 năm, HĐ AR đối ứng (link T1). **Components:** DataTable + count-tab lỗi mã; preview XML (MST hai bên, nội dung phí, thuế GTGT) trong Sheet S3 trước khi gửi; ProgressTracker lô phát hành (tiến độ từng hóa đơn — lỗi lẻ không chặn lô, hóa đơn lỗi ở lại hàng chờ); StatusBadge trạng thái connector. **Actions:** tạo lô phát hành (D8 — FIN_L1, MFA, gửi qua connector GW; nhận mã CQT), phát hành lại sau `DRAFT_ERROR` (sửa dữ liệu → tờ khai mới tham chiếu hồ sơ cũ — cơ quan thuế từ chối mã không đè hồ sơ), điều chỉnh/thay thế/hủy chuẩn (D9 — FIN_L1/L2 đề xuất + biên bản thỏa thuận đính kèm; FIN_L2 duyệt ngưỡng nhỏ, CFO duyệt giá trị lớn/ảnh hưởng doanh thu quý; XML gốc bất biến — mọi chỉnh sửa là tài liệu mới tham chiếu cũ, hash-chain), đính biên bản thỏa thuận, xuất báo cáo HĐ định kỳ, tra cứu bản gốc (XML + bản hiển thị). **Connector VAS (DI-004):** trạng thái gửi mã + đồng bộ hóa đơn sang sổ VAS hiển thị tại đây với timestamp; connector fail → `WAITING_CONNECTION` + hàng chờ retry tự động + alert — KHÔNG ghi tay kết quả mã; cấu hình profile/mapping/credential tại **S27 Settings** (link điều hướng, không nhân bản console). **States:** loading skeleton; empty ("Không có hóa đơn đủ điều kiện — chứng từ chưa khóa kỳ sẽ không xuất hiện"); error connector = banner `WAITING_CONNECTION` không dismiss. **Permissions:** xem — FIN_L1 (khách được gán)/FIN_L2/BOD; phát hành — FIN_L1 (MFA), FIN_L2 phê duyệt lô lớn; đề nghị điều chỉnh — FIN_L1 nhập/L2; duyệt điều chỉnh lớn — CFO; cấu hình thời điểm lập HĐ — FIN_L2 đề xuất, BOD phê duyệt, SYS_ADMIN thực thi sau duyệt; xuất/truy xuất ngoài chuẩn — BOD sau phê duyệt CEO (kết quả xuất bị log). **Quan hệ tab khác:** hóa đơn phát hành chính là hóa đơn AR trong T1 (điều chỉnh/giảm trừ cập nhật số dư AR qua giao dịch có reason code — nhắc nợ chạy trên số sau điều chỉnh); chứng từ nguồn khóa kỳ tại S7; đồng bộ VAS trạng thái dùng chung FEAT-006.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Tạo hóa đơn AR | `UI-WEB-ARAP-001-D1` | Form | T1 — "[+ Tạo mới ▾] Hóa đơn" (FIN_L1) |
| 2 | Ghi nhận thanh toán | `UI-WEB-ARAP-001-D2` | Confirm + MFA + evidence | T1 — row action "Ghi thanh toán" (FIN_L1) |
| 3 | Nhắc nợ / ghi nhận đòi nợ | `UI-WEB-ARAP-001-D3` | Form 2 chế độ | T1/S1 — "Nhắc nợ" hoặc "Ghi nhận liên lạc" |
| 4 | Cấu hình lịch + mẫu nhắc nợ | `UI-WEB-ARAP-001-D4` | Form + duyệt | T1 — "Cấu hình dunning" (FIN_L2) |
| 5 | Tranh chấp: mở ticket / kết luận | `UI-WEB-ARAP-001-D5` | Form | T1/S1 — row action "⋯" (FIN_L2) |
| 6 | Tạo lệnh chi | `UI-WEB-ARAP-001-D6` | Form + checklist | T2 — "[+ Tạo mới ▾] Lệnh chi" |
| 7 | Delegate FIN_L2 | `UI-WEB-ARAP-001-D7` | Form | T2 — "Quản lý delegate" (CFO) |
| 8 | Phát hành HĐĐT theo lô | `UI-WEB-ARAP-001-D8` | Wizard + MFA | T3 — "Phát hành lô" (FIN_L1) |
| 9 | Điều chỉnh / thay thế / hủy HĐĐT | `UI-WEB-ARAP-001-D9` | Form + duyệt | T3/S3 — row action (FIN_L1/L2 đề xuất) |
| 10 | Xuất báo cáo aging/HĐ | `UI-WEB-ARAP-001-D10` | Form cấu hình xuất | Header — "Xuất báo cáo ▾" |

### 3.1. Tạo hóa đơn AR (D1)
Form: khách (combobox — chỉ khách có hợp đồng hiệu lực), hợp đồng + chu kỳ thanh toán (điền theo hợp đồng — không cho sửa mốc thấp hơn chuẩn), kỳ dịch vụ, số tiền (nguyên tệ + quy VND snapshot nếu ngoại tệ), hạn thanh toán, ghi chú. Auto-sync: hóa đơn từ `deal.signed` schedule hiển thị nhãn "tự động từ lịch hợp đồng" — bản manual ghi người tạo. Kỳ đã khóa → chặn với lý do + link đề nghị mở kỳ (S7/S6). Submit gọi API-ERP-029.

### 3.2. Ghi nhận thanh toán (D2)
Confirm có ngữ cảnh + MFA (`purpose: payment_approval`): hóa đơn + còn nợ (MoneyDisplay) + số tiền thu (một phần → cảnh báo "aging tiếp tục từ hạn gốc"); checklist bắt buộc: tiền ĐÃ khớp tại ví (Hard Stop FIN_L1 — link S7 khi chưa khớp; chưa khớp → nút disabled + giải thích "khách hứa chuyển không giảm dư nợ"), evidence (sao kê/lệnh khớp) đính kèm. Không rõ hóa đơn nào → gợi ý phân bổ FIFO theo hạn + ghi chú; không map được → chuyển tạo ticket xử lý có duyệt. Sau lưu: event `payment.received` (feed commission), dư nợ + aging cập nhật ngay.

### 3.3. Nhắc nợ / ghi nhận đòi nợ (D3)
Chế độ **Gửi nhắc** (manual trigger API-ERP-032 hoặc chờ cron theo lịch D4): chọn mẫu nội dung theo bucket, kênh (email/portal-offline), người nhận — preview trước khi gửi; kết quả ghi ReminderLog (thời điểm, kênh, người gửi, nội dung). Chế độ **Ghi nhận liên lạc đòi nợ** (FIN_L1 nhập thô / FIN_L2): loại (cuộc gọi, cam kết thanh toán, thỏa thuận gia hạn), tóm tắt, cam kết ngày; hóa đơn tranh chấp → nhắc tự động dừng, chỉ ghi theo ticket D5.

### 3.4. Cấu hình lịch + mẫu nhắc nợ (D4)
FIN_L2 soạn: mốc ngày nhắc theo bucket (vd T+3/T+7/T+15 quá hạn), mẫu nội dung từng mốc, người nhận (khách + CC owner SALES), kênh. Hiển thị trạng thái phê duyệt: BOD phê duyệt mới hiệu lực (SYS_ADMIN chỉ thực thi sau duyệt). Lịch sử phiên bản cấu hình + ai duyệt.

### 3.5. Tranh chấp (D5)
**Mở ticket:** hóa đơn + lý do + người phụ trách + hạn khép → hóa đơn chuyển `DISPUTED`, tách khỏi aging thường, dừng nhắc tự động. **Kết luận:** lý do bắt buộc + trạng thái trở về (về trạng thái cũ hoặc `SETTLED`); FIN_L2 đề xuất — CFO duyệt. Log bất biến từng bước.

### 3.6. Tạo lệnh chi (D6)
Form + checklist tự động chạy theo thời gian thực: loại chi (thường/khẩn/định kỳ/bổ sung hạn mức), beneficiary, số tiền (nguyên tệ + quy VND theo snapshot tỷ giá hôm nay — hiển thị "ngưỡng áp dụng: 50–200 triệu → FIN_L2 + CFO dual" ngay khi nhập), chứng từ đính kèm (upload bắt buộc), **≥2 báo giá khi >20 triệu** (thiếu → item checklist đỏ + Submit disabled + lỗi "thiếu báo giá thứ 2"), mã dự án/khách (không gắn được → chọn overhead + lý do bắt buộc), lệnh liên quan TKQC hiển thị Hard Stop status (chưa khớp → cảnh báo "sẽ giữ ở chờ khớp tiền sau khi duyệt"). SoD pre-check: người tạo trùng vai duyệt → chặn trước submit với mã `SOD_VIOLATION`. Kế hoạch nạp tuần: chọn kế hoạch đã duyệt → giao dịch con không cần duyệt lại; vượt hạn mức còn lại → tự chuyển thành "duyệt bổ sung" đúng cấp. Submit gọi API-ERP-033.

### 3.7. Delegate FIN_L2 (D7)
Chỉ BOD_CFO_CTO mở: người được ủy quyền (cá nhân cụ thể — combobox theo scope), hạn mức tối đa (≤ FIN_L2), thời hạn (≤14 ngày — picker chặn ngày thứ 15), lý do. Hiển thị danh sách delegate đang hiệu lực + countdown tự hết hạn + mọi lệnh đã duyệt theo ủy quyền (nhãn "theo ủy quyền #id"). Hủy trước hạn được phép (ghi log). Lệnh độc quyền CFO không xuất hiện trong phạm vi ủy quyền — hiển thị ghi chú giải thích.

### 3.8. Phát hành HĐĐT theo lô (D8)
Wizard 3 bước: (1) chọn từ hàng đợi `ELIGIBLE` — checkbox từng chứng từ; item chưa khóa kỳ/chưa khớp thanh toán bị loại sẵn với lý do; (2) preview XML từng hóa đơn (Sheet S3) + tổng hợp lô; (3) xác nhận MFA (`purpose: einvoice_issue`) → gửi qua connector GW. Kết quả theo từng hóa đơn: mã CQT / lỗi dữ liệu (`DRAFT_ERROR` — sửa rồi tạo lô mới) / `WAITING_CONNECTION` (retry tự động); lô hiển thị tiến độ, lỗi lẻ không chặn phần còn lại.

### 3.9. Điều chỉnh / thay thế / hủy HĐĐT (D9)
Chọn loại nghiệp vụ chuẩn (hóa đơn điều chỉnh / hóa đơn thay thế / hủy + biên bản): lý do bắt buộc, biên bản thỏa thuận với khách đính kèm (bắt buộc với hủy), số tiền điều chỉnh (cập nhật AR đối ứng qua giao dịch có reason code). Hiển thị cảnh báo phân quyền duyệt: ngưỡng nhỏ — FIN_L2; giá trị lớn/ảnh hưởng doanh thu quý — CFO. XML gốc hiển thị read-only cạnh form — nhắc "không sửa được, tạo tài liệu mới tham chiếu gốc".

### 3.10. Xuất báo cáo (D10)
Báo cáo chuẩn: aging AR/AP tuần/tháng, danh mục HĐĐT theo kỳ, lịch giải ngân định kỳ — chọn kỳ + phạm vi (khách/nền tảng) → xuất qua job async (CSV/PDF) kèm audit truy xuất. Xuất ngoài báo cáo chuẩn: chỉ BOD, hiển thị "cần phê duyệt CEO" → tạo yêu cầu chờ duyệt, không xuất ngay.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Hóa đơn AR 360 | `UI-WEB-ARAP-001-S1` | Right 720px | T1 — click dòng hóa đơn |
| 2 | Lệnh chi detail | `UI-WEB-ARAP-001-S2` | Right 720px | T2 — click dòng lệnh chi |
| 3 | HĐĐT detail + XML | `UI-WEB-ARAP-001-S3` | Right 720px | T3 — click dòng hóa đơn / preview tại D8 |

### 4.1. Sheet Hóa đơn AR 360 (S1)
Header: số HĐ + khách (link S28) + StatusBadge + MoneyDisplay còn nợ + bucket hiện tại. Tabs panel: **Chi tiết** (hợp đồng, chu kỳ, kỳ dịch vụ, HĐĐT đối ứng link T3); **Thanh toán** (danh sách PaymentReceipt — mỗi dòng: số tiền, ngày khớp, evidence, người xác nhận khớp tiền; link "Mở khớp tiền tại S7" khi chưa có); **Nhắc nợ** (ReminderLog đầy đủ + nút D3 theo quyền); **Tranh chấp** (nếu có — người phụ trách, hạn khép, tiến độ kết luận); **Timeline** (activity feed từ API-CORE-030 — tạo, điều chỉnh, thu, nhắc, tranh chấp). Footer sticky: [Ghi thanh toán] [Nhắc nợ] [⋯ Tranh chấp/Điều chỉnh] theo quyền.

### 4.2. Sheet Lệnh chi (S2)
Header: mã + loại + StatusBadge + MoneyDisplay (nguyên tệ + quy VND snapshot ngày duyệt — bất biến). ProgressTracker ngang các stage: Draft → Duyệt (hiển thị cấp ngưỡng + ai giữ + WaitingOnIndicator + SLA còn lại) → Hard Stop (nếu TKQC — trạng thái khớp tiền + link S7; không bypass kể cả CEO) → Sẵn sàng chi → Đã chi (người thực hiện ≠ duyệt) → Hậu kiểm 24h (riêng chi khẩn — kết quả + alert nếu fail). Body: checklist hồ sơ (chứng từ + báo giá — click mở), mã dự án/khách/overhead, chuỗi ApprovalStep (dual = 2 slot kiểu ApprovalCard: "FIN_L2 ✓ 10:32 · CFO đang chờ"; chữ ký delegate gắn nhãn "theo ủy quyền #id"), escalation record nếu quá SLA. Footer: [Mở duyệt tại S6] [Disburse] (FIN_L1, chỉ khi `READY_TO_PAY`) [Hủy] (draft — lý do).

### 4.3. Sheet HĐĐT detail (S3)
Header: ký hiệu/số + khách + MST + StatusBadge + mã CQT. Body: preview nội dung hóa đơn (render) + tab **XML gốc** (bất biến, hash hiển thị + ngày WORM); chuỗi phiên bản điều chỉnh (hash-chain — click từng phiên bản xem doc tham chiếu); thời điểm lập theo nhóm dịch vụ; trạng thái connector (timestamp gửi, retry); audit (ai phát hành/điều chỉnh, reason code, kênh). Footer: [Điều chỉnh/thay thế/hủy] (D9 theo quyền) [Tải XML] (trong chuẩn) [Xuất ngoài chuẩn → yêu cầu duyệt CEO].

---

## 5. VIEW MODES

| Mode | UI-ID | Mô tả | Hiện khi nào |
|------|-------|-------|--------------|
| Chuẩn | `UI-WEB-ARAP-001-M1` | Dữ liệu ledger đồng bộ đầy đủ; connector VAS khỏe; kỳ hiển thị trạng thái thật (mở/đã khóa) | Default |
| Degraded — dữ liệu trễ | `UI-WEB-ARAP-001-M2` | Ledger/connector VAS lỗi: banner nhãn "dữ liệu tới HH:MM" trên dải aging + danh sách; không cho kết luận chốt số; HĐĐT mới về `WAITING_CONNECTION` (retry tự động, không ghi tay mã); bút toán xuất VAS bị treo hiển thị hàng chờ | Sync lỗi / connector fail (theo S27) |

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| T1 — danh sách hóa đơn AR | GET | `/api/v1/erp/ar-invoices` (API-ERP-030) | Filter `aging_bucket, paid_status, customer_id, period`; pagination 20/50/100 server-side; scope theo FIN_L1 gán khách |
| T1/S1 — chi tiết hóa đơn | GET | `[NEEDS_REVIEW: thiếu endpoint GET /api/v1/erp/ar-invoices/{id} (contract chỉ định nghĩa list) — đề xuất bổ sung]` | Detail + receipts + reminder logs |
| D1 — tạo hóa đơn AR | POST | `/api/v1/erp/ar-invoices` (API-ERP-029) | FIN_L1; auto từ `deal.signed` schedule + manual |
| D2 — ghi thanh toán | POST | `/api/v1/erp/ar-invoices/{id}/payments` (API-ERP-031) | Money command — MFA step-up + `Idempotency-Key`; phát `payment.received` |
| D3 — nhắc nợ | POST | `/api/v1/erp/ar-invoices/{id}/dunning` (API-ERP-032) | Cron tự động + manual trigger; log dunning (ReminderLog) |
| D4 — cấu hình lịch nhắc | GET/POST | `[NEEDS_REVIEW: thiếu endpoint cấu hình dunning schedule + mẫu nội dung (mốc ngày, mẫu, người nhận) — đề xuất GET/POST /api/v1/erp/dunning-policies]` | FIN_L2 soạn, BOD phê duyệt |
| D5 — ticket tranh chấp | GET/POST | `[NEEDS_REVIEW: thiếu endpoint DisputeTicket (mở/kết luận tranh chấp công nợ) — đề xuất POST /api/v1/erp/ar-invoices/{id}/disputes]` | FIN_L2 mở; kết luận CFO duyệt |
| T2 — danh sách lệnh chi | GET | `[NEEDS_REVIEW: thiếu endpoint GET /api/v1/erp/payment-orders (contract chỉ có POST/approve/disburse) — đề xuất bổ sung list filter status,type,period,approver]` | Machine-state + SLA countdown từ core |
| D6 — tạo lệnh chi | POST | `/api/v1/erp/payment-orders` (API-ERP-033) | Kiểm số dư ví khả dụng + báo giá đính kèm; lỗi `MISSING_QUOTATION`/`SOD_VIOLATION` |
| Duyệt lệnh chi | POST | `/api/v1/erp/payment-orders/{id}/approve` (API-ERP-034) | Route ngưỡng FIN_L2 (<50tr) → CFO (<200tr) → CEO (≥200tr); delegate; cùng người 2 chân → `SOD_VIOLATION` |
| Disburse | POST | `/api/v1/erp/payment-orders/{id}/disburse` (API-ERP-035) | FIN_L1 ≠ người duyệt; ghi journal trừ ví |
| T2 — trạng thái hard stop | GET | `/api/v1/erp/wallets/{customerId}/hard-stop-status` (API-ERP-027) | Hiển thị trên lệnh chi liên quan TKQC; link khớp tiền S7 |
| T2 — phí nền tảng + thuế | GET | `/api/v1/erp/platform-fees` (API-ERP-038) | Filter kỳ/nền tảng; nhóm "nghĩa vụ thuế" VAT/FCT read-only |
| T3 — danh mục HĐĐT | GET | `/api/v1/erp/einvoices` (API-ERP-037) | Filter `status, period, customer_id`; evidence push WORM |
| T3/S3 — chi tiết HĐĐT | GET | `[NEEDS_REVIEW: thiếu endpoint GET /api/v1/erp/einvoices/{id} (XML + hash + chuỗi điều chỉnh) — đề xuất bổ sung]` | Bản gốc bất biến + hash-chain |
| D8 — phát hành HĐĐT | POST | `/api/v1/erp/einvoices/{id}/issue` (API-ERP-036) | FIN_L1 + MFA; draft → issued → delivered; lô = N lần gọi + batch wrapper `[NEEDS_REVIEW: thiếu endpoint lô phát hành IssuanceBatch — đề xuất POST /api/v1/erp/einvoice-batches]` |
| D9 — điều chỉnh/hủy HĐĐT | POST | `[NEEDS_REVIEW: thiếu endpoint AdjustmentDoc (điều chỉnh/thay thế/hủy chuẩn TT78/NĐ123) — đề xuất POST /api/v1/erp/einvoices/{id}/adjustments]` | FIN_L2/CFO duyệt theo ngưỡng |
| D6 — upload chứng từ/báo giá | POST | `[NEEDS_REVIEW: thiếu endpoint upload attachment cho payment-order — đề xuất POST /api/v1/erp/payment-orders/{id}/attachments]` | Bắt buộc trước submit; ≥2 báo giá >20tr |
| D7 — delegate | GET/PUT | `/core/policies/delegates` (API-CORE-023) `[STEP-UP]` | CFO ủy quyền FIN_L2; ≤14 ngày, tự hết hạn `[NEEDS_REVIEW: contract ghi chú "CEO thay nấc hay defer" — chốt hành vi nhánh CFO]` |
| S1–S3 — timeline | GET | `/core/audit/objects/:objectId/timeline` (API-CORE-030) | Activity feed per hóa đơn/lệnh/HĐĐT |
| D2/D8 — MFA step-up | POST | `/api/v1/core/auth/mfa/step-up` (API-CORE-003) | `purpose: payment_approval \| einvoice_issue` |
| D10 — xuất báo cáo | POST | `/core/bi/exports` (API-CORE-039) | Job async CSV/PDF + audit; ngoài chuẩn → yêu cầu duyệt CEO |
| M2 — export VAS | POST | `/gw/exports` (API-GW-023) | File chuẩn schema cho connector VAS (DI-004); cấu hình profile tại S27 |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-ARAP-001` | Main Page | Công nợ & Giải ngân — khung 3 tabs + header kỳ kế toán/exposure + banner |
| `UI-WEB-ARAP-001-T1` | Tab | Công nợ AR — aging buckets + invoice list + dunning + clawback + tranh chấp |
| `UI-WEB-ARAP-001-T2` | Tab | AP & Giải ngân — AP đến hạn + lệnh chi theo ngưỡng 5/50/200tr + SoD + delegate |
| `UI-WEB-ARAP-001-T3` | Tab | HĐĐT — phát hành/tra cứu/điều chỉnh TT78/NĐ123 + connector VAS |
| `UI-WEB-ARAP-001-D1` | Dialog | Tạo hóa đơn AR |
| `UI-WEB-ARAP-001-D2` | Dialog | Ghi nhận thanh toán (MFA + evidence + Hard Stop check) |
| `UI-WEB-ARAP-001-D3` | Dialog | Nhắc nợ / ghi nhận đòi nợ |
| `UI-WEB-ARAP-001-D4` | Dialog | Cấu hình lịch + mẫu nhắc nợ (duyệt BOD) |
| `UI-WEB-ARAP-001-D5` | Dialog | Tranh chấp: mở ticket / kết luận |
| `UI-WEB-ARAP-001-D6` | Dialog | Tạo lệnh chi (checklist báo giá + SoD pre-check) |
| `UI-WEB-ARAP-001-D7` | Dialog | Delegate FIN_L2 (CFO ủy quyền, ≤14 ngày) |
| `UI-WEB-ARAP-001-D8` | Dialog | Phát hành HĐĐT theo lô (wizard + MFA) |
| `UI-WEB-ARAP-001-D9` | Dialog | Điều chỉnh / thay thế / hủy HĐĐT |
| `UI-WEB-ARAP-001-D10` | Dialog | Xuất báo cáo aging/HĐ (chuẩn / ngoài chuẩn) |
| `UI-WEB-ARAP-001-S1` | Sheet | SidePanel Hóa đơn AR 360 (720px) |
| `UI-WEB-ARAP-001-S2` | Sheet | SidePanel Lệnh chi detail — approval chain + Hard Stop (720px) |
| `UI-WEB-ARAP-001-S3` | Sheet | SidePanel HĐĐT detail + XML gốc + hash-chain (720px) |
| `UI-WEB-ARAP-001-M1` | View Mode | Chuẩn |
| `UI-WEB-ARAP-001-M2` | View Mode | Degraded — dữ liệu trễ / connector fail (WAITING_CONNECTION) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
