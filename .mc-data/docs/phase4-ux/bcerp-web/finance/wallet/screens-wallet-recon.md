# Screen Group: Ví & Đối soát

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `wallet`
> **Tính năng:** FEAT-ERP-WALLET-001..007
> **Route:** `/finance/wallet`
> **Main UI-ID:** `UI-WEB-WALLET-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-WALLET-001 (sổ phụ ví + lệnh giao dịch), FEAT-ERP-WALLET-002 (cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h — góc FIN), FEAT-ERP-WALLET-003 (tạo đề xuất dual approval), FEAT-ERP-WALLET-004 (đối trừ 3 số + chốt & khóa kỳ), FEAT-ERP-WALLET-005 (hard stop "đã khớp tiền" FIN_L1), FEAT-ERP-WALLET-006 (AML T1–T6 + hoàn tiền đúng nguồn), FEAT-ERP-WALLET-007 (dữ liệu cảnh báo cùng nguồn CORE — bề mặt góc OPS thuộc S9 TKQC Registry + banner Ops, không nhân bản tại đây).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Workspace | Finance (`/finance/*`) — OPS không thấy menu, chỉ nhận banner cảnh báo trong Ops |
| Đối tượng nghiệp vụ | Wallet per-khách per-currency (USD/VND không gộp, available/frozen), WalletTransaction (lệnh), ReconciliationLine/Run (đối trừ 3 số), AccountingPeriod (khóa kỳ), FundMatchConfirmation (hard stop), AmlAlert |
| Vai trò chính | FIN_L1 (đối trừ, import manual, ticket, khớp tiền — MFA, tạo đề xuất), FIN_L2 (duyệt dual, chốt kỳ — MFA, tạm giữ giải ngân), BOD_CFO_CTO (duyệt vượt ngưỡng, phiếu mở kỳ, phê duyệt ngưỡng) |
| Workflow stage | Ví: entry → reconciling (3 số) → matched/mismatch → period_locked; lệnh: draft → dual_approval → executed; khớp tiền: CHỜ KHỚP → ĐÃ KHỚP TIỀN (→ gate cấp phát TKQC) / ĐÃ THU HỒI |
| Liên quan | S9 TKQC Registry (OPS đọc trạng thái gate — read-only), S6 Approval Inbox (duyệt), S27 Connections (degraded mode), S24 Alert Center, Portal P1 (khách đọc số dư — tenant isolation) |

**Checklist workflow (Bước 0):** A. Tiền giữ hộ khách = nợ phải trả — mọi biến động qua lệnh hệ thống, ledger append-only. B. FIN_L1/L2 là người dùng duy nhất của surface này. C. OPS xem trạng thái hard stop ở S9; BOD qua BI; khách qua Portal (read-only). D. Stages theo máy trạng thái CORE — Web chỉ render nguyên văn. E. Cross-module: GW (statement `api`/`manual`), ADACC (gate cấp phát), SLANOT, Portal. F. Thông tin: 3 vế portal vs bank vs ledger per TKQC, dung sai 0 / 0,5%·10USD / 1%·20USD, số dư per tiền tệ, số ngày chi dự kiến (ADS 7 ngày), nhãn nguồn, FX tách khoản riêng. G. Quyết định: khớp tiền per lệnh nạp, tạo điều chỉnh (dual), chốt kỳ, mở kỳ. H. Actions: đối trừ, điều chỉnh (dual), khóa kỳ, khớp tiền (MFA + evidence), thu hồi, import manual. I. Exceptions: mismatch chặn chốt kỳ (`PERIOD_LOCKED`), AML hold, thiếu evidence, ví <3 ngày, dữ liệu manual, chênh timing/FX. J. 1 surface 5 tabs — không tách page.

---

## 1. TRANG CHÍNH

### 1.1. Layout (Pattern W4 dashboard trên T1 + W1 bảng; density compact)

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Finance / Ví & Đối soát      Kỳ đối soát: T8/2026 · Đang mở · 2 mismatch chưa xử lý  │
│                                                          [+ Tạo lệnh ▾] [Import ▾]   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ ⛔ Banner đỏ (không dismiss): 2 TKQC chưa "đã khớp tiền" — chặn cấp phát [Mở khớp    │
│    tiền] · 1 dòng MISMATCH vượt dung sai [Mở đối trừ]                                │
│ ⚠ Banner vàng: 1 ví < đủ chi 3 ngày — SLA đỏ 2h đang chạy (còn 1h05) [Xem alert]     │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ Tổng quan │ Đối trừ 3 số │ Sổ phụ & lệnh │ Khớp tiền & hard stop │ AML & hoàn tiền    │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────┬──────────────┬───────────────┬───────────────┐                       │
│ │ Dư ví khả    │ Ví <3 ngày   │ Mismatch chờ  │ Chờ khớp tiền │  (KPI → click ra      │
│ │ dụng USD/VND │ (XVĐ) ·1     │ xử lý ·2      │ ·3 lệnh       │   worklist tương ứng) │
│ │ tách 2 sổ    │              │               │               │                       │
│ └──────────────┴──────────────┴───────────────┴───────────────┘                       │
│ Bảng ví per khách × currency: Khách · USD avail/frozen · VND avail/frozen · XVĐ       │
│  (số ngày chi) · Mức ●●● / ●●○ / ●○○ · Nguồn api/manual · Đang đối soát? · Hard stop │
│  CTCP An Phát   12.480,00/0,00     210.400.000/0,00   4,2 ngày  ●●●  api   —   ĐÃ KHỚP│
│  Công ty Bee   980,00/2.150,00     0/0               0,8 ngày  ●○○  manual  ⚠  CHỜ KHỚP│
│ Tìm nhanh [______] Chips: (<3 ngày ×)(Đỏ ×)(manual ×)(Đang đối soát ×) [Bộ lọc ▾]     │
│ Phân trang 20/50/100 (server-side) · sort theo click header                          │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**Loading/Empty/Error:** loading = skeleton 10 hàng KPI + bảng; empty = EmptyState theo tab (ví dụ "Không có dòng chênh lệch trong kỳ"); error = khối lỗi + retry; lỗi `PERIOD_LOCKED`/`AML_FLAGGED`/`HARD_STOP_ACTIVE` hiển thị WarningIndicator kèm link hành động, không tự biến mất khi reload.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| WarningIndicator banner | hard stop + mismatch: variant banner, không dismiss | Bắt buộc 3 phần: chuyện gì — cần ai — hạn còn lại; có nút "Mở …" |
| StatusBadge | 4 trạng thái đối soát + trạng thái hard stop + badge `--state-manual` | Badge "Dữ liệu thủ công" hiển thị vĩnh viễn trên record manual |
| MoneyDisplay | multi-currency + hard-stop 3 số cạnh nhau | Mismatch tô `--state-mismatch`; tabular-nums, right-align |
| WaitingOnIndicator | chip dòng ví đỏ | "Chờ owner 1h05 (SLA 2h)" — breach kèm chuông |
| KPI widgets | 4 ô số + delta | Operational: click → worklist đã lọc, không trang trí |
| DataTable compact | filter bar + chips + sort + pagination 20/50/100 server-side | Cột tiền/tabular-nums; column config persist |

### 1.3. Cột chính (bảng ví T1)

| Cột | Trường | Định dạng | Sắp xếp |
|-----|--------|-----------|---------|
| Khách | `customer.name` | Text + link Client 360 | Có |
| USD available/frozen | `wallets[USD].availableBalance/frozenBalance` | MoneyDisplay — không gộp VND | Có |
| VND available/frozen | `wallets[VND].availableBalance/frozenBalance` | MoneyDisplay | Có |
| Số ngày chi dự kiến | ADS 7 ngày rolling (CORE) | "4,2 ngày" | Có |
| Mức cảnh báo | Xanh ≥3 ngày / Vàng <3 / Đỏ <1 ngày | ●●● màu + text (color-blind safe) | Có |
| Nguồn dữ liệu | `source` api/manual | Badge `manual` + tooltip disclaimer độ trễ | Không |
| Đang đối soát | ticket mismatch mở | Badge "đang đối soát" | Có |
| Hard stop | `hard-stop-status` | ĐÃ KHỚP / CHỜ KHỚP / ĐÃ THU HỒI | Có |

---

## 2. TABS

| Tab | UI-ID | Nội dung | Feat |
|-----|-------|---------|------|
| Tổng quan | `UI-WEB-WALLET-001-T1` | KPI + bảng ví + banner + SLA alert FIN | 002, 007 (data) |
| Đối trừ 3 số | `UI-WEB-WALLET-001-T2` | Dải đối trừ portal/bank/ledger + ticket + FX + chốt kỳ | 004 |
| Sổ phụ & lệnh | `UI-WEB-WALLET-001-T3` | Ledger append-only + tạo lệnh (NET/GROSS k) | 001, 003 |
| Khớp tiền & hard stop | `UI-WEB-WALLET-001-T4` | Hàng đợi chờ khớp + confirm/thu hồi + gate per TKQC | 005 |
| AML & hoàn tiền | `UI-WEB-WALLET-001-T5` | Cảnh báo T1–T6 + workflow điều tra + hoàn tiền đúng nguồn | 006 |

**R7 tab completeness:**

- **T1 Tổng quan:** mục tiêu — nắm rủi ro dòng tiền và nhảy thẳng worklist. Thông tin: KPI 4 ô, bảng ví per khách × currency (§1.3), bảng alert đỏ đang chạy SLA 2h với từng chặng escalation owner→TL→AM có timestamp (read-only góc FIN), hành động FIN: đánh dấu "rủi ro gián đoạn chi tiêu" (FIN_L1/L2), tạm giữ/mở giữ giải ngân kế hoạch tuần (FIN_L2 — bắt buộc reason code + audit). States alert: TRIGGERED/ACTIONED/ESCALATED_TL/ESCALATED_AM/RESOLVED. Ngoài giờ: hiển thị "ngoài giờ, chờ on-call" thay vì đếm tiếp. Permissions: FIN xem mọi khách; OPS chỉ qua banner Ops/S9; SYS_ADMIN ❌. Quan hệ: click ví → S1; click alert → worklist T1 của alert đó; nhãn `manual` kèm disclaimer (đồng bộ BR-C07 — số dư một nguồn sự thật từ CORE, màn này không tự tính lại).
- **T2 Đối trừ 3 số:** mục tiêu — thay đối soát ảnh chụp bằng đối trừ tự động 3 vế per TKQC/khách/nền tảng (nạp = ngày, chi tiêu = ngày, tích lũy + số dư = tuần). Dải đối trừ riêng per dòng:
  ```
  ┌ Dải đối trừ — TKQC Meta · CTCP An Phát · USD · 12/09/2026 · nguồn: portal api · bank api · ledger api ┐
  │  PORTAL (nạp thực tế)      BANK (sao kê + chi báo cáo)   LEDGER (sổ phụ BCERP)   KẾT QUẢ             │
  │  4.312,50 USD              4.304,50 USD                  4.312,50 USD             chênh −8 USD      │
  │  ── breakdown gross: net 3.876,53 + fee 116,30 + VAT 9,30/9,37 → gross 4.312,50 (k=1,1124) ──         │
  │  ≤10 USD → [ĐÃ ĐỐI SOÁT (dung sai)] — hạch toán tài khoản sai lệch đối soát, FIN_L2 rà tuần          │
  └───────────────────────────────────────────────────────────────────────────────────────────────────────┘
  mismatch (vượt dung sai): 3 số tô `--state-mismatch` + nút [Tạo ticket] [Tạo điều chỉnh (dual)]
  ```
  Thông tin đủ 3 vế mới được "Đã đối soát" — thiếu vế hiển thị "thiếu dữ liệu" kèm vế còn thiếu; 4 trạng thái chuẩn (Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh — không có text tự do); nhãn nguồn `api`/`manual` trên từng vế; chênh timing/tỷ giá gắn nhãn riêng → hạch toán FXGainLossEntry, không tính vi phạm dung sai; tiền gốc + quy VND theo snapshot song song. Actions: tạo ticket discrepancy (FIN_L1 — đủ TKQC, nền tảng, khách, hai con số, nguồn, timestamp; quá hạn T+1 escalate FIN_L2 + báo cáo BOD), tạo điều chỉnh (D3 — cấm "cân số trực tiếp", nút không tồn tại), chốt kỳ (D4). Kỳ đã khóa: mọi dòng read-only + badge "kỳ đã khóa". Quan hệ: ticket → điều chỉnh dual tại S6; chốt kỳ ở header trang.
- **T3 Sổ phụ & lệnh:** mục tiêu — sổ append-only per ví + tạo lệnh đúng luồng. Thông tin: lịch sử giao dịch (type TOPUP/REFUND/ADJUST/WITHDRAW/REVALUATION, amount, currency, snapshot fee %/VAT cố định — không có nút "cập nhật theo hợp đồng hiện tại"), ai đề xuất/khớp/duyệt từng bước, evidence. Form tạo lệnh (D3): khách – TKQC – số tiền – tiền tệ – snapshot tỷ giá – căn cứ; NET/GROSS 2 chiều theo k (nhập net → gross trừ ví; nhập gross → net vào TKQC; sai khác làm tròn chặn submit); TK client-owned/Internal-Sandbox bị ẩn/chặn (BR-W09). Sửa số dư chỉ qua reversal + reason code — nút "sửa" không tồn tại. Permissions: FIN_L1/L2 tạo (người đề xuất mất quyền duyệt lệnh đó); OPS tạo đề xuất từ workspace ops (S9/banner) — tại đây chỉ xem lệnh của mình. Quan hệ: lệnh `PENDING` → S6; khớp tiền nạp → T4.
- **T4 Khớp tiền & hard stop:** mục tiêu — trụ cột hard stop: FIN_L1 là vai DUY NHẤT xác nhận "đã khớp tiền" trên Web với MFA TOTP. Hàng đợi lệnh nạp chờ khớp sort theo thời gian chờ; mỗi dòng: lệnh nạp + dòng sao kê đối ứng + trạng thái check (số khớp gross theo k · người chuyển trùng tên pháp nhân KYC · evidence · AML hold). Nút xác nhận disabled khi thiếu evidence (hiển thị thiếu cụ thể); **không có nút override trong mọi vai** — yêu cầu mở khóa thủ công bị từ chối + log `BYPASS_ATTEMPT`; không có trạng thái "chờ duyệt/khách hứa chuyển". Thu hồi (FIN_L1, lý do bắt buộc): hệ quả tự động — TKQC về "Tạm dừng chi tiêu" + khóa lệnh nạp mới + alert TL. Trạng thái gate per TKQC (API-ERP-027) hiển thị read-only + link "Xem tại S9 TKQC Registry". Nhật ký xác nhận/thu hồi + evidence (WORM) ở panel lịch sử. AML hold: lệnh hold hiển thị nhãn AML, gate giữ khóa đến khi có quyết định.
- **T5 AML & hoàn tiền:** mục tiêu — điều tra cảnh báo T1–T6 đúng SLA 24h + ép hoàn tiền đúng nguồn. Danh sách cảnh báo vàng/đỏ (rule, ngưỡng chạm + breakdown, khách/TKQC/giao dịch, nhãn EDD "ngưỡng siết 50%", trạng thái HOLD giao dịch). Workflow: FIN_L2 nhận điều tra (nút disabled cho người đề xuất/nhập giao dịch — SoD), đóng vàng vô hại (lý do + bằng chứng), nâng vàng→đỏ, đỏ tự escalate BOD 24h, quyết định BOD ghi lý do văn bản lưu vĩnh viễn; hold nhả tự động khi alert đóng. Hoàn tiền đúng nguồn: form hoàn chỉ chọn beneficiary từ danh sách TK đã KYC trùng tên pháp nhân; đổi beneficiary chặn mặc định + T4 đỏ (chỉ BOD xem xét bằng văn bản). Rebate: mặc định TẮT, nhập tay theo quý + approvedBy — không tự cộng vào lệnh hoàn. Không có giao diện xóa hồ sơ AML (retention ≥5 năm). Báo cáo AML tháng (số lượng vàng/đỏ, SLA, tỷ lệ escalation) — xuất cho BOD.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Xác nhận khớp tiền | `UI-WEB-WALLET-001-D1` | Confirm + MFA + evidence | T4 — nút "Xác nhận đã khớp tiền" (FIN_L1) |
| 2 | Thu hồi xác nhận | `UI-WEB-WALLET-001-D2` | Confirm lý do | T4 — dòng đã khớp |
| 3 | Tạo đề xuất điều chỉnh/đổi tỷ giá/hoàn tiền | `UI-WEB-WALLET-001-D3` | Form (3 chế độ) | T2/T3 — "Tạo lệnh ▾" / từ ticket mismatch |
| 4 | Chốt & khóa kỳ | `UI-WEB-WALLET-001-D4` | Confirm + MFA | Header kỳ (FIN_L2) |
| 5 | Phiếu mở kỳ | `UI-WEB-WALLET-001-D5` | Form | Kỳ đã khóa (BOD_CFO_CTO) |
| 6 | Import statement manual | `UI-WEB-WALLET-001-D6` | Form upload | T2 — nền tảng chưa API (degraded) |

### 3.1. Xác nhận khớp tiền (D1)
**Loại:** Confirm có ngữ cảnh + MFA. Nội dung: lệnh nạp + số gross theo snapshot (breakdown net/fee/VAT) vs sao kê; checklist tự động (số khớp · tên người chuyển trùng pháp nhân KYC · evidence đính kèm · không AML hold) — mục nào fail thì nút xác nhận disabled kèm lý do; đính evidence (sao kê/lệnh) bắt buộc trước khi bật nút; xác nhận MFA TOTP (`purpose: payment_approval`). Sau xác nhận: trạng thái `ĐÃ KHỚP TIỀN`, gate cấp phát TKQC mở tự động, event `wallet.matched`, audit ghi actor + timestamp + evidence hash.

### 3.2. Thu hồi xác nhận (D2)
Lý do bắt buộc (≥10 ký tự); hiển thị cảnh báo hệ quả 3 bước tự chạy (TK tạm dừng chi tiêu · khóa nạp mới · alert TL). Không quay trực tiếp trạng thái trên evidence sai — quay lại CHỜ KHỚP qua lệnh/làm rõ mới.

### 3.3. Tạo đề xuất (D3)
**Loại:** Form 3 chế độ (chọn loại đầu form): ADJUST (old→new + reason code bắt buộc + ticket liên quan nếu phát sinh từ mismatch), FX_CHANGE (snapshot gốc hiển thị cạnh số đề xuất + biên bản đối chiếu khách — thiếu biên bản chặn submit), REFUND (bắt buộc dẫn chiếu giao dịch nạp gốc + beneficiary chỉ chọn từ TK đã KYC trùng tên pháp nhân; không có ô nhập beneficiary tùy ý, không có ô nhập % mới). Kỳ đã khóa → form vô hiệu + chuyển đề nghị phiếu mở kỳ (D5). Submit → `PENDING` vào S6; người đề xuất không tự duyệt lệnh của mình.

### 3.4. Chốt & khóa kỳ (D4)
FIN_L2 + MFA (`purpose: period_lock`). Hiển thị điều kiện tiên quyết: số ticket mismatch chưa giải trình (còn >0 → nút disabled + danh sách ticket tồn); xác nhận phạm vi kỳ + số dòng đối soát. Sau chốt: khóa tầng dữ liệu, mọi chứng từ trong kỳ read-only, thông báo số chốt là nền cho HĐĐT/P&L.

### 3.5. Phiếu mở kỳ (D5)
BOD_CFO_CTO duyệt. Fields: lý do, phạm vi (chứng từ/dòng chỉ định — không mở khóa hàng loạt), thời hạn hiệu lực. Sau sửa xong bắt buộc chốt lại. Mở kỳ + thao tác trên kỳ mở đều ghi audit log bất biến.

### 3.6. Import statement manual (D6)
Upload file theo schema chuẩn 8 trường (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) + metadata `entered_by`/`evidence_ref`. Sai schema: chặn, báo lỗi **từng dòng** để sửa và nạp lại — không tạo dòng đối soát hỏng. Dòng hợp lệ gắn nhãn `manual`; khi API nền tảng sống lại GW backfill và đối soát lại (ghi chú hiển thị trên kỳ đã nhập tay).

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Ví khách 360 (góc FIN) | `UI-WEB-WALLET-001-S1` | Right 480px | T1/T3 — click dòng ví |
| 2 | Dòng đối trừ + ticket | `UI-WEB-WALLET-001-S2` | Right 720px | T2 — click dòng đối soát |

### 4.1. Sheet Ví khách (S1)
Header: khách + sổ USD/VND tách dòng (available/frozen — không dòng tổng quy đổi). Tabs: Số dư + lệnh đang treo (PENDING/STEP1_APPROVED hiển thị riêng, không cộng vào available) · Lịch sử giao dịch (5 entry + link full T3) · Cảnh báo (mức XVĐ per TK + trạng thái alert + tạm giữ giải ngân nếu có) · Hard stop (trạng thái per TKQC + link S9). Footer: [+ Tạo lệnh] [+ Đề xuất hoàn tiền] (theo quyền).

### 4.2. Sheet Dòng đối trừ (S2)
Dải 3 số cạnh nhau (portal/bank/ledger) + breakdown gross theo k + nhãn nguồn từng vế + kết quả trạng thái/dung sai; tab ticket (root cause, giải trình FIN_L1, deadline T+1, người duyệt), tab FX (chênh timing/tỷ giá → FXGainLossEntry), tab audit (job khớp, ai nhập manual, timestamps). Footer: [Tạo ticket] / [Tạo điều chỉnh (dual)] / [Xác nhận chênh timing→FX] theo trạng thái + quyền.

---

## 5. VIEW MODES

| Mode | UI-ID | Mô tả | Hiện khi nào |
|------|-------|-------|--------------|
| Chuẩn (api) | `UI-WEB-WALLET-001-M1` | Dữ liệu đồng bộ GW đầy đủ; badge nguồn `api` | Default |
| Degraded — nhập manual | `UI-WEB-WALLET-001-M2` | Bật khi nền tảng chưa API: mở D6 import/nhập tay; toàn bộ record manual gắn badge `--state-manual` "Dữ liệu thủ công" vĩnh viễn + disclaimer độ trễ; chu kỳ đối soát ngày hạ xuống tuần | Connection degraded (theo S27) |

---

## 6. API ENDPOINTS

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| T1 — danh sách ví | GET | `/api/v1/erp/wallets` (API-ERP-020) | Filter `balance_status=low` (XVĐ <3 ngày), `currency`, `customer_id`; pagination 20/50/100 |
| T3 — sổ phụ | GET | `/api/v1/erp/wallets/{id}/ledger` (API-ERP-021) | Filter `period, entry_type, source(api\|manual)` |
| T3/D3 — tạo lệnh | POST | `/api/v1/erp/wallets/{id}/transactions` (API-ERP-022) | `type: topup\|spend\|adjustment\|revaluation\|refund`; snapshot fee %; 409 `PERIOD_LOCKED\|AML_FLAGGED\|APPROVAL_REQUIRED` |
| D3 — gửi duyệt dual | POST | `/api/v1/erp/wallet-transactions/{id}/approvals` (API-ERP-023) | Từ S6 gọi; `SOD_VIOLATION` khi trùng người |
| T2 — kỳ + dòng đối soát | GET | `/api/v1/erp/reconciliation-runs` (API-ERP-024) | Detail items matched/mismatch (portal vs bank vs ledger) |
| D4 — chốt & khóa kỳ | POST | `/api/v1/erp/reconciliation-runs/{period}/close` (API-ERP-025) | Chặn khi còn mismatch; `[STEP-UP]` MFA |
| D1 — khớp tiền | POST | `/api/v1/erp/wallets/{customerId}/hard-stop/confirm` (API-ERP-026) | Body gắn `topup_transaction_id` + `evidence[]` theo FEAT-005 `[NEEDS_REVIEW: contract ghi per-khách, FEAT ghi per-lệnh nạp 1-1 — chốt granularity body]`; phát `wallet.matched` |
| T4 — trạng thái gate | GET | `/api/v1/erp/wallets/{customerId}/hard-stop-status` (API-ERP-027) | Nguồn sự thật cho badge hard stop (link S9) |
| T5 — cảnh báo AML | GET/POST | `/api/v1/erp/aml-flags[/{id}/resolve]` (API-ERP-028) | Resolve hoàn tiền đúng nguồn cần dual |
| D6 — import manual | POST | `/gw/imports/statements` (API-GW-028) | Schema 8 trường; nhận dòng hợp lệ, lỗi từng dòng |
| T2 — nguồn statement | GET | `/gw/statements` (API-GW-032) | Filter `platform, adaccountRef, windowFrom/To, sourceLabel` |
| D1/D4 — MFA step-up | POST | `/api/v1/core/auth/mfa/step-up` (API-CORE-003) | `purpose: "payment_approval" \| "period_lock"` |
| T1 — alert SLA | GET/POST | `/core/alerts/instances[/:id/transitions]` (API-CORE-043/044) | Rule "ví < đủ chi 3 ngày", "mismatch đối trừ"; ack không auto-close |
| D5 — phiếu mở kỳ | POST | `[NEEDS_REVIEW: thiếu endpoint phiếu mở kỳ OpenPeriodTicket — đề xuất POST /api/v1/erp/periods/{id}/open-tickets]` | BOD_CFO_CTO duyệt |
| T2 — ticket discrepancy | POST | `[NEEDS_REVIEW: thiếu endpoint riêng ticket discrepancy (ERP tickets API-ERP-058 là CSKH) — đề xuất POST /api/v1/erp/reconciliation-runs/{period}/tickets]` | FIN_L1 tạo + giải trình |
| D3 — beneficiary đã KYC | GET | `[NEEDS_REVIEW: thiếu endpoint danh sách TK nhận hợp lệ trùng tên pháp nhân KYC (thuộc REQ-FIN-009 module KYC) — cần endpoint tra cứu cho form hoàn tiền]` | Lọc `kycMatch=true` |

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-WALLET-001` | Main Page | Ví & Đối soát — khung 5 tabs + banner + kỳ đối soát |
| `UI-WEB-WALLET-001-T1` | Tab | Tổng quan & cảnh báo số dư |
| `UI-WEB-WALLET-001-T2` | Tab | Đối trừ 3 số (dải portal/bank/ledger + ticket + FX) |
| `UI-WEB-WALLET-001-T3` | Tab | Sổ phụ & lệnh giao dịch |
| `UI-WEB-WALLET-001-T4` | Tab | Khớp tiền & hard stop |
| `UI-WEB-WALLET-001-T5` | Tab | AML T1–T6 & hoàn tiền đúng nguồn |
| `UI-WEB-WALLET-001-D1` | Dialog | Xác nhận khớp tiền (MFA + evidence) |
| `UI-WEB-WALLET-001-D2` | Dialog | Thu hồi xác nhận khớp tiền |
| `UI-WEB-WALLET-001-D3` | Dialog | Tạo đề xuất điều chỉnh/đổi tỷ giá/hoàn tiền |
| `UI-WEB-WALLET-001-D4` | Dialog | Chốt & khóa kỳ (MFA) |
| `UI-WEB-WALLET-001-D5` | Dialog | Phiếu mở kỳ |
| `UI-WEB-WALLET-001-D6` | Dialog | Import statement manual (degraded) |
| `UI-WEB-WALLET-001-S1` | Sheet | SidePanel ví khách 480px |
| `UI-WEB-WALLET-001-S2` | Sheet | SidePanel dòng đối trừ + ticket 720px |
| `UI-WEB-WALLET-001-M1` | View Mode | Chuẩn (api) |
| `UI-WEB-WALLET-001-M2` | View Mode | Degraded — nhập manual + nhãn "Dữ liệu thủ công" |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
