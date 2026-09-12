# Tính Năng: Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ

> **Dựa trên:** REQ-FIN-004 trong `phase1-business/departments/finance/finance.md` (Phần A, B.2 — BR-FIN-201..205, B.1 — BR-FIN-107)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5/3.8/5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-004-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-FIN-004 (fan-out 3 hệ thống); counterpart: SYS-CORE-BACKEND (logic khớp, lock tầng dữ liệu), SYS-INTEGRATION-GW (đầu vào vế 2–3: statement/API nền tảng, nhãn `api`/`manual`).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-004 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-004 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-WALLET-001 (sổ phụ ví — vế 1 của đối trừ); dữ liệu kéo nền tảng qua GW theo REQ-FIN-005 (adapter/degraded mode `manual`) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể. Lưu ý đã chốt 12/09 (DI-001): mức dung sai 0 / 0,5%·10USD / 1%·20USD là mức mặc định được duyệt;connector kế toán VAS thiết kế vendor-agnostic, cấu hình kết nối ngoại vi tại MOD-SETTINGS-GW (DI-004) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thay hoàn toàn đối soát bằng ảnh chụp màn hình bằng màn hình đối trừ 3 vế tự động trên Web nội bộ — sổ phụ ví BCERP ↔ số liệu nền tảng (statement/API) ↔ sao kê ngân hàng/chi tiêu báo cáo bởi nền tảng — theo TKQC/khách/nền tảng với dung sai chuẩn và 4 trạng thái đối soát; kèm quy trình chốt số liệu và khóa kỳ để mọi chứng từ trong kỳ đã chốt không thể sửa/xóa, bảo đảm số đối soát là nền tảng đáng tin cho HĐĐT, P&L và báo cáo BOD.

**Phạm vi:**
- Bao gồm: màn đối soát hiển thị 3 vế theo TKQC/khách/nền tảng với nhãn nguồn `api`/`manual`; xử lý kết quả khớp/chênh lệch theo dung sai (0 / 0,5%·10USD / 1%·20USD); tạo và theo dõi ticket discrepancy với luồng giải trình FIN_L1 → FIN_L2; hiển thị song song tiền gốc và quy VND theo snapshot tỷ giá; màn chốt kỳ + phiếu mở kỳ do BOD_CFO_CTO duyệt; dashboard khoản lãi/lỗ FX tách riêng.
- Không bao gồm: logic khớp, dung sai, 4 trạng thái và khóa cứng tầng dữ liệu (thực thi ở SYS-CORE-BACKEND); kéo dữ liệu statement/API nền tảng và gắn nhãn nguồn (SYS-INTEGRATION-GW theo REQ-FIN-005); xuất bút toán sang phần mềm kế toán VAS (REQ-FIN-013 — cấu hình kết nối ngoại vi tại MOD-SETTINGS-GW).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: màn làm việc đối soát + workflow chốt kỳ, gọi API core, hiển thị đúng trạng thái machine-state của từng dòng đối soát và của kỳ kế toán.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem kết quả đối trừ 3 vế hàng ngày theo TKQC/khách/nền tảng với 4 trạng thái (Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh) | Phát hiện ngay dòng lệch thay vì so tay từng ảnh chụp |
| 2 | FIN_L1 | Import/nhập tay statement có cấu trúc khi nền tảng chưa có API (nhãn `manual`, sai schema bị chặn) | Đối soát vẫn chạy đúng luồng trong khi chờ quyền API/Business Verification |
| 3 | FIN_L1 | Tạo ticket discrepancy đủ (TKQC, nền tảng, khách, hai con số, nguồn, timestamp) và viết giải trình | Chênh lệch vượt dung sai được xử lý có kiểm soát, không tự cân số |
| 4 | FIN_L2 | Chốt công nợ nền tảng tháng sau khi toàn bộ ticket đã giải trình | Số chốt là số sạch, chặn chốt khi còn ticket tồn |
| 5 | BOD_CFO_CTO | Duyệt phiếu mở kỳ (lý do, phạm vi, thời hạn) khi cần sửa số trên kỳ đã khóa | Mở khóa có kiểm soát, từng phiếu, không mở khóa hàng loạt |
| 6 | FIN_L2 | Xem lãi/lỗ FX ghi khoản riêng, tách khỏi giá vốn và GM dịch vụ | Hiệu ứng tỷ giá không làm méo P&L dịch vụ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Logic khớp và lock ở CORE; GW cấp dữ liệu; Web bảo đảm quy trình vận hành đúng thứ tự.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-R01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND **không gộp quy đổi**) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — đối trừ khớp theo đúng tiền tệ giao dịch gốc, không quy đổi để "cho khớp" | Dòng đối soát thiếu tiền tệ không được tạo; khớp chéo tiền tệ bị service layer từ chối |
| BR-R02 | Công thức topup k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5) — số "khách nạp theo sổ phụ" của vế 1 phải là grossAmount đã trừ ví, khớp với nạp thực tế vào nền tảng (net + phí theo snapshot giao dịch) | Con số đối chiếu hiển thị đầy đủ breakdown (net/fee/VAT/gross) để FIN_L1 so từng thành phần, không chỉ tổng |
| BR-R03 | **Đối trừ 3 số tự động**: (1) sổ phụ ví BCERP, (2) nạp thực tế vào nền tảng (statement/API), (3) sao kê ngân hàng + chi tiêu thực tế báo cáo bởi nền tảng — khớp theo TKQC/khách/nền tảng, chu kỳ: nạp = ngày, chi tiêu = ngày, tích lũy chi tiêu + số dư ví = tuần | Dòng không đủ 3 vế không thể đánh dấu "Đã đối soát"; hiển thị trạng thái "thiếu dữ liệu" kèm vế còn thiếu |
| BR-R04 | **Dung sai** (chốt mức mặc định 12/09 — DI-001): đối nạp sai số tuyệt đối = **0/dòng** (ngày); chi tiêu ≤**0,5% hoặc ≤10 USD**/TK/ngày (lấy mức thấp hơn); tích lũy ≤**1% hoặc ≤20 USD**/khách/tuần | Trong dung sai → "Đã đối soát (dung sai)", hạch toán tài khoản sai lệch đối soát, FIN_L2 rà tuần; vượt dung sai → bắt buộc ticket |
| BR-R05 | **4 trạng thái** chuẩn: Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh (có phiếu duyệt) — không thêm trạng thái tùy chế | Web chỉ render 4 trạng thái từ CORE; không có ô trạng thái text tự do |
| BR-R06 | **Vượt dung sai → ticket discrepancy**: FIN_L1 điều tra gốc rễ + giải trình FIN_L2 trước chốt kỳ đối soát đó (T+1); **cấm tự cân số** cho hai vế khớp; mọi điều chỉnh có chứng từ + dual approval (FEAT-ERP-WALLET-003) + audit log bất biến | Nút "cân số trực tiếp" không tồn tại; ticket quá hạn giải trình tự escalate FIN_L2 + báo cáo BOD_CFO_CTO |
| BR-R07 | **Đa tiền tệ & snapshot tỷ giá**: sổ gốc VND; snapshot tỷ giá (nguồn ngân hàng quy chuẩn) ghi ngay tại giao dịch, khóa sau ghi nhận, không truy lịch; lãi/lỗ FX ghi **khoản riêng** tách khỏi giá vốn và GM; sai lệch timing/tỷ giá xử lý qua khoản FX riêng, không tính vi phạm dung sai | Không có giao dịch nào cho sửa snapshot; chênh tỷ giá không tự động tính thành vi phạm đối soát |
| BR-R08 | **Chốt & khóa kỳ**: FIN_L2 chốt công nợ nền tảng tháng (mức đề xuất: ngày 3 tháng kế tiếp `[CẦN CHỐT SỐ — chờ xác nhận chính thức]`); chặn chốt khi còn ticket discrepancy chưa giải trình; sau chốt khóa kỳ — chặn sửa/xóa chứng từ ở tầng dữ liệu; mở kỳ chỉ BOD_CFO_CTO duyệt bằng phiếu mở kỳ (lý do, phạm vi, thời hạn) + audit log; sau khi sửa xong bắt buộc chốt lại | Nút "Chốt" disabled khi còn ticket; mọi thao tác trên kỳ đã khóa ngoài phiếu mở kỳ bị từ chối + log |
| BR-R09 | **Nhãn nguồn `api`/`manual`**: mọi số liệu đưa vào đối soát phải có nhãn; nhập tay có cấu trúc theo schema chuẩn (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) — sai schema bị chặn; khi API nền tảng sống lại, GW backfill và đối soát lại các kỳ đã nhập tay | Không có cơ chế nhập tự do dạng text; import fail schema báo lỗi từng dòng để FIN_L1 sửa và nạp lại |
| BR-R10 | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h (FEAT-ERP-WALLET-002): số dư hiển thị trên màn đối soát đồng bộ với dashboard cảnh báo — một nguồn sự thật từ CORE | Màn đối soát không tự tính lại số dư riêng; lệch số giữa 2 màn là bug chặn nghiệm thu |
| BR-R11 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — đối soát cấp dữ liệu giao dịch cho rule engine AML; rebate ghi nhận theo quý không tham gia đối trừ hàng ngày | Dòng rebate không rơi vào dung sai chi tiêu hằng ngày; dữ liệu đối soát đưa được cho AML rule engine truy xuất |
| BR-R12 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: khách chỉ thấy trạng thái đối soát ở mức dành cho khách; chi tiết 3 vế, dung sai, ticket là dữ liệu nội bộ | Không có route Portal đọc chi tiết ticket/dung sai; chi tiết nội bộ không lọt ra view tổng hợp khách |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Thực thi cứng (khớp, dung sai, lock) thuộc CORE; Web phản ánh đúng.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Xem màn đối soát 3 vế | ✅ | ✅ | ✅ | ❌ |
| Import/nhập tay statement (nhãn `manual`) | ✅ (ghi ai nhập + căn cứ) | ❌ | ❌ | ❌ |
| Tạo ticket discrepancy + giải trình | ✅ | ❌ | ❌ | ❌ |
| Duyệt điều chỉnh (qua dual approval) | ❌ | ✅ | ✅ (vượt ngưỡng) | ❌ |
| Chốt công nợ nền tảng tháng | ❌ | ✅ | ❌ | ❌ |
| Duyệt phiếu mở kỳ đã khóa | ❌ | ❌ | ✅ | ❌ |
| Cấu hình dung sai / chu kỳ đối soát | ❌ | ❌ | ✅ (phê duyệt chính sách) | ✅ (thiết lập kỹ thuật theo chính sách) |
| Xem báo cáo FX riêng | ✅ | ✅ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Nền tảng chưa có API (chờ Business Verification — DI-007): đối soát ngày hạ xuống **tuần** qua import statement chuẩn; khi được cấp API, GW backfill và đối soát lại các kỳ đã nhập tay.
- Sai lệch timing/tỷ giá giữa BC và nền tảng (nạp khuya cắt phiên, platform tính theo timezone riêng): xử lý qua khoản FX riêng, không tính vi phạm dung sai — Web hiển thị nhãn "chênh timing" để phân biệt.
- Chênh lệch do lỗi hệ thống/nhập liệu: xử lý bằng **reversal có reason code**, không sửa dòng gốc; ticket gắn reversal tương ứng.
- TK client-owned (khách tự nạp trực tiếp): chỉ đối soát, không phát sinh lệnh nạp BC — màn đối soát phân loại riêng để không đòi vế lệnh BC.
- Phí nền tảng trừ thẳng vào số dư ví: coi như một dòng chi tiêu trong đối soát, không ghi thành doanh thu âm (REQ-FIN-014).
- Điều chỉnh ảnh hưởng P&L tháng đã chốt: BOD_CFO_CTO duyệt trong 48h theo phiếu mở kỳ; mở kỳ xử lý từng phiếu, không mở khóa hàng loạt.
- Nhiều currency trong cùng khách (USD + VND): kỳ chốt vẫn khóa per kỳ kế toán chung nhưng báo cáo đối soát tách theo tiền tệ gốc — không tổng hợp quy đổi để quyết định khớp/lệch.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Dòng đối soát (ReconciliationLine) và Kỳ đối soát (ReconciliationPeriod) — Web hiển thị đúng machine-state.*

**Entity:** Dòng đối soát (ReconciliationLine)

**Sơ đồ trạng thái:**
```
[CHUA_DOI_SOAT] ──(khớp 3 vế trong dung sai)──► [DA_DOI_SOAT]
       │                                              │ (dung sai: hạch toán sai lệch đối soát)
       │ (vượt dung sai)                              ▼
       └──────────► [CHENH_LECH] ──(ticket + dual approval)──► [DA_DIEU_CHINH]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CHUA_DOI_SOAT` | Job khớp tự động qua dung sai | `DA_DOI_SOAT` | Hệ thống (CORE) | Đủ 3 vế; sai số trong dung sai BR-R04 |
| `CHUA_DOI_SOAT` | Phát hiện vượt dung sai | `CHENH_LECH` | Hệ thống (CORE) | Tự gán khi vượt dung sai |
| `CHENH_LECH` | Tạo ticket + giải trình + duyệt điều chỉnh | `DA_DIEU_CHINH` | FIN_L1 tạo; FIN_L2 (+BOD_CFO_CTO nếu vượt ngưỡng) duyệt | Ticket đủ dữ liệu; dual approval; chứng từ đính kèm |
| `CHENH_LECH` | Xác định là chênh timing/FX | `DA_DOI_SOAT` | Hệ thống theo quy tắc BR-R07 | Hạch toán khoản FX riêng |
| `DA_DOI_SOAT` | Period chốt + khóa | Bất biến | Không ai | Chỉ mở lại bằng phiếu mở kỳ BOD_CFO_CTO |

**Quy tắc:**
- Kỳ đối soát chỉ chốt được khi không còn dòng `CHENH_LECH` chưa giải trình (chặn ở CORE + Web disable nút).
- `DA_DIEU_CHINH` bắt buộc có phiếu duyệt liên kết — không có đường chuyển thủ công.
- Kỳ đã khóa là trạng thái kết thúc của kỳ; mở lại là thao tác riêng có phiếu, sau sửa buộc chốt lại.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ReconciliationLine | `adAccountId`, `customerId`, `platformId`, `date`, `walletAmount`, `platformAmount`, `bankSpendAmount`, `currency`, `source` (`api`/`manual`), `state` | FK → Wallet/AdAccount/Platform | 4 trạng thái chuẩn |
| ReconciliationTicket | `lineId`, `rootCause`, `explanation`, `deadline`, `resolvedBy` | FK → ReconciliationLine | Quá hạn tự escalate |
| DiscrepancyAllowance | `type` (TOPUP/SPEND_DAILY/ACCUM_WEEKLY), `absoluteOrPercent`, `usdCap` | Cấu hình theo chính sách đã duyệt | 0 / 0,5%·10USD / 1%·20USD |
| FXSnapshot | `transactionId`, `rate`, `source`, `lockedAt` | FK → WalletTransaction | Khóa sau ghi nhận, không truy lịch |
| FXGainLossEntry | `periodId`, `amount`, `type` | FK → AccountingPeriod | Khoản riêng, tách GM dịch vụ |
| AccountingPeriod | `period`, `closedBy`, `closedAt`, `lockState` | Cha của mọi dòng đối soát trong kỳ | Mở kỳ qua OpenPeriodTicket |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khớp 3 vế trong dung sai | Chi tiêu lệch 8 USD (<10 USD) trên TK/ngày | Job đối soát chạy | Dòng `DA_DOI_SOAT` (dung sai), hạch toán tài khoản sai lệch đối soát | [ ] |
| SC-002: Vượt dung sai sinh ticket | Chi tiêu lệch 15 USD (>10 USD) trên TK/ngày | Job chạy | Dòng `CHENH_LECH`, ticket tự sinh đủ (TKQC, nền tảng, khách, hai con số, nguồn, timestamp) | [ ] |
| SC-003: Chặn chốt khi còn ticket | Còn 1 ticket chưa giải trình | FIN_L2 bấm chốt tháng | Chặn; nút disabled kèm danh sách ticket tồn | [ ] |
| SC-004: Khóa kỳ tầng dữ liệu | Kỳ đã chốt | Thử UPDATE/DELETE chứng từ trong kỳ | Từ chối ở tầng dữ liệu; chỉ phiếu mở kỳ BOD_CFO_CTO mở được | [ ] |
| SC-005: Import manual sai schema | File statement thiếu cột mã tham chiếu | FIN_L1 import | Bị chặn, báo lỗi từng dòng; không tạo dòng đối soát hỏng | [ ] |
| SC-006: FX tách khoản riêng | Nạp USD, tỷ giá snapshot chênh so với platform | Đối soát tuần | Chênh tỷ giá vào FXGainLossEntry, không tính vi phạm dung sai | [ ] |

> **Liên kết:** SC-001/SC-002 → REQ-FIN-004 (BR-R04/R05); SC-003/SC-004 → REQ-FIN-004 (BR-R08); SC-005 → REQ-FIN-004 + REQ-FIN-005 (BR-R09); SC-006 → REQ-FIN-004 (BR-R07) trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (reconciliation, period lock, FX) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (reconciliation, periods, tickets) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-004: CORE-BACKEND, INTEGRATION-GW; connector VAS vendor-agnostic qua MOD-SETTINGS-GW — DI-004) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (màn đối soát, ticket, chốt kỳ) |
| Bản touchpoint khác | FEAT cho SYS-CORE-BACKEND / SYS-INTEGRATION-GW cùng REQ (lane riêng) |
