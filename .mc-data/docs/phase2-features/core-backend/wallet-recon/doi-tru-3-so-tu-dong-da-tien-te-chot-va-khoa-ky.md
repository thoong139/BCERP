# Tính Năng: Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ

> **Dựa trên:** REQ-FIN-004 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5/§3.8, §5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-004-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-004 (REQ xuất hiện ở 3 systems). Counterparts: SYS-INTEGRATION-GW (cấp dữ liệu vế 2–3: statement/API nền tảng, nhãn `api`/`manual` — theo REQ-FIN-005), SYS-BCERP-WEB (màn đối soát + ticket). Touchpoint Core Backend là **headless API/domain service**: logic khớp 3 vế, dung sai, chốt & khóa kỳ thực thi ở tầng service — GW chỉ cấp dữ liệu, không có logic đối trừ; mọi thao tác khóa/mở kỳ bị chặn ở tầng dữ liệu.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-004 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-004 |
| Người dùng liên quan | FIN_L1 (xử lý kết quả đối soát, giải trình), FIN_L2 (rà tuần, chốt & khóa kỳ), BOD_CFO_CTO (duyệt mở kỳ, rà khoản FX) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (sổ phụ ví — vế 1 của đối trừ); dữ liệu vế 2–3 từ REQ-FIN-005 (GW); điều chỉnh kết xuất đi qua FEAT-CORE-WALLET-003 |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng — nền tảng chưa có API hạ đối soát xuống tuần qua import, đối trừ phải chạy được với dữ liệu nhãn `manual` |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thay hoàn toàn đối soát bằng ảnh chụp màn hình bằng **đối trừ 3 vế tự động** trên Core Backend: (1) khách nạp theo sổ phụ ví BCERP, (2) nạp thực tế vào nền tảng (statement/API), (3) chi tiêu thực tế báo cáo bởi nền tảng — khớp theo TKQC/khách/nền tảng hằng ngày, tự phát hiện chênh lệch vượt dung sai và chuyển ticket discrepancy thay vì để số sai âm thầm tích tụ. Tính năng cũng quản lý chu kỳ chốt số liệu & khóa kỳ (period lock): sau chốt, chứng từ trong kỳ bị khóa sửa/xóa ở tầng dữ liệu; mở kỳ chỉ khi BOD_CFO_CTO duyệt phiếu mở kỳ có lý do, phạm vi, thời hạn.

**Phạm vi:**
- Bao gồm: job đối trừ tự động theo lịch (nạp = ngày, chi tiêu = ngày, tích lũy chi tiêu + số dư ví = tuần); bộ dung sai 3 tầng (0 / 0,5%·10USD / 1%·20USD — mức mặc định đã chốt theo DI-001); gán 4 trạng thái chuẩn cho từng dòng đối soát (Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh); tạo ticket discrepancy tự động khi vượt dung sai; chặn chốt kỳ khi còn ticket chưa giải trình; khóa kỳ tầng dữ liệu; quản lý phiếu mở kỳ; đa tiền tệ — snapshot tỷ giá per-giao-dịch khóa sau ghi nhận, lãi/lỗ FX ghi khoản riêng tách khỏi giá vốn và GM dịch vụ.
- Không bao gồm: kéo số liệu nền tảng qua API/import (SYS-INTEGRATION-GW — REQ-FIN-005; Core chỉ tiêu thụ dữ liệu đã gắn nhãn nguồn); màn hình đối soát/ticket và phiếu mở kỳ trên WEB (SYS-BCERP-WEB); dual approval cho lệnh điều chỉnh (FEAT-CORE-WALLET-003); cảnh báo số dư (FEAT-CORE-WALLET-002).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Core tự khớp 3 số mỗi sáng và chỉ đưa tôi những dòng Chưa đối soát/Chênh lệch | Không dò tay hàng nghìn dòng; tập trung xử lý đúng chỗ có vấn đề |
| 2 | FIN_L1 | Khi vượt dung sai, hệ thống tự mở ticket discrepancy đủ thông tin (TKQC, nền tảng, khách, hai con số, nguồn, timestamp) | Có đơn vị công việc rõ ràng để điều tra gốc rễ và giải trình FIN_L2 trước chốt kỳ |
| 3 | FIN_L2 | Rà các khoản sai lệch trong dung sai theo tuần và chốt công nợ nền tảng tháng khi mọi ticket đã giải trình | Chốt số liệu đáng tin; không chốt khi còn issue chưa xử lý |
| 4 | FIN_L2 | Bấm chốt kỳ và hệ thống khóa mọi chứng từ trong kỳ ở tầng dữ liệu | Không ai (kể cả vô ý) sửa được số đã chốt — số báo cáo = số sổ |
| 5 | BOD_CFO_CTO | Duyệt phiếu mở kỳ ghi rõ lý do, phạm vi, thời hạn khi bắt buộc sửa số đã chốt | Có kiểm soát cao nhất đối với việc "mở lại quá khứ kế toán" |
| 6 | BOD_CFO_CTO | Xem lãi/lỗ FX ghi khoản riêng, tách khỏi giá vốn và GM dịch vụ | Biến động tỷ giá không làm méo báo cáo P&L dịch vụ |
| 7 | Hệ thống (Core service) | Tự gán trạng thái từng dòng đối soát và cấm mọi thao tác "tự cân số" hai vế cho khớp | Giữ tính trung thực của dữ liệu đối soát — chênh lệch phải được giải trình, không bị che |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; đối trừ chạy phía server theo lịch, không phụ thuộc thao tác UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-R01 | Nền tảng dữ liệu: vế 1 là sổ phụ ví per-khách multi-currency (USD/VND không gộp quy đổi) của FEAT-CORE-WALLET-001; mọi giao dịch sinh từ lệnh hệ thống với snapshot fee %/tỷ giá tại thời điểm giao dịch | Khớp chỉ diễn ra giữa các dòng có cùng `ad_account_id` + `customer_id` + `platform_id` + `currency`; khớp chéo TK/cross currency không được tự ghép |
| BR-R02 | 3 vế bắt buộc khớp theo TKQC/khách/nền tảng: (1) khách nạp theo sổ phụ ví BCERP; (2) nạp thực tế vào nền tảng (statement/API — đầu vào GW theo REQ-FIN-005); (3) chi tiêu thực tế báo cáo bởi nền tảng. Chu kỳ: nạp = ngày; chi tiêu = ngày; tích lũy chi tiêu + số dư ví = tuần (BR-FIN-201) | Dòng thiếu một trong 3 vế → giữ "Chưa đối soát", không tự suy đoán số còn thiếu |
| BR-R03 | Dung sai 3 tầng (mức mặc định đã chốt theo DI-001): đối **nạp** sai số tuyệt đối = 0/dòng (ngày); đối **chi tiêu** ≤0,5% hoặc ≤10 USD/TK/ngày (lấy mức thấp hơn); **tích lũy** chi tiêu + số dư ví ≤1% hoặc ≤20 USD/khách/tuần (lấy mức thấp hơn) | Trong dung sai → "Đã đối soát (dung sai)", hạch toán tài khoản sai lệch đối soát, FIN_L2 rà theo tuần; vượt → ticket |
| BR-R04 | 4 trạng thái chuẩn của dòng đối soát: Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh (có phiếu duyệt); Core gán tự động sau mỗi run | Trạng thái tự do ngoài 4 giá trị bị schema chặn; chuyển "Đã điều chỉnh" bắt buộc dẫn chiếu phiếu duyệt (FEAT-CORE-WALLET-003) |
| BR-R05 | Vượt dung sai → ticket discrepancy tự động đủ (TKQC, nền tảng, khách, hai con số, nguồn, timestamp); FIN_L1 điều tra gốc rễ + giải trình FIN_L2 trước chốt kỳ đối soát đó; **cấm tự cân số** cho hai vế khớp (BR-FIN-202) | Tạo/cập nhật số liệu để hai vế khớp thủ công không qua phiếu duyệt → chặn + log; ticket quá hạn giải trình tự escalate FIN_L2 + báo cáo BOD_CFO_CTO |
| BR-R06 | Đa tiền tệ: sổ gốc VND; mọi giao dịch ngoại tệ quy đổi theo snapshot tỷ giá ghi ngay tại thời điểm giao dịch (nguồn ngân hàng quy chuẩn), khóa sau ghi nhận, không truy lịch; WEB hiển thị song song tiền gốc + quy VND (BR-FIN-203) | UPDATE snapshot tỷ giá sau ghi nhận bị chặn tầng dữ liệu; sai khác tỷ giá → khoản FX riêng, không sửa snapshot gốc |
| BR-R07 | Lãi/lỗ FX ghi **khoản riêng**, tách hoàn toàn khỏi giá vốn và GM dịch vụ — hiệu ứng tỷ giá không được làm méo P&L dịch vụ; chỉ lệnh đổi tỷ giá tay dual approval (FEAT-CORE-WALLET-003) được đổi tỷ giá, và chỉ khi có biên bản đối chiếu với khách | Hạch toán FX lẫn vào giá vốn/doanh thu dịch vụ → chặn; báo cáo GM bỏ qua khoản FX riêng |
| BR-R08 | Nền tảng chưa có API → đối soát ngày hạ xuống tuần qua import nhãn `manual` (REQ-FIN-005); mọi số liệu đầu vào phải có nhãn `api`/`manual`; nhập tay có cấu trúc — sai schema bị chặn; khi API sống lại GW backfill và Core đối soát lại các kỳ đã nhập tay (BR-FIN-205/301) | Số liệu không nhãn nguồn bị loại khỏi đối trừ; import sai schema báo lỗi từng dòng, không có kênh nhập tự do dạng text |
| BR-R09 | Chốt kỳ: FIN_L2 chốt công nợ nền tảng tháng vào ngày 3 tháng kế tiếp `[CẦN CHỐT SỐ — ngày mốc chờ CFO xác nhận]`; hệ thống **chặn chốt khi còn ticket discrepancy chưa giải trình** (BR-FIN-107/204) | Nút/thao tác chốt bị service từ chối khi tồn tại ticket mở trong kỳ; lý do bị chặn hiển thị kèm danh sách ticket |
| BR-R10 | Sau chốt: **khóa kỳ** — mọi chứng từ trong kỳ chặn sửa/xóa ở tầng dữ liệu (DB trigger/rule, không chỉ UI); điều chỉnh ảnh hưởng P&L tháng đã chốt do BOD_CFO_CTO duyệt trong 48h (BR-FIN-204) | UPDATE/DELETE chứng từ kỳ đã khóa bị từ chối ở DB; app account không có quyền ghi đè |
| BR-R11 | Mở kỳ chỉ BOD_CFO_CTO duyệt bằng phiếu mở kỳ ghi rõ lý do, phạm vi, thời hạn + audit log bất biến; mở theo từng phiếu, không mở khóa hàng loạt; sau khi sửa xong bắt buộc chốt lại | Yêu cầu mở kỳ thiếu phiếu/mở hàng loạt bị từ chối; mọi phiếu mở kỳ xuất hiện trong báo cáo cho BOD |
| BR-R12 | Cảnh báo số dư (FEAT-CORE-WALLET-002) đọc số dư và ngày chi dự kiến từ dữ liệu đã đối soát; alert không dùng để tự cân số — chênh lệch phát hiện qua alert chuyển ticket theo BR-R05 | — (tính chất liên kết; không có hành vi đối trừ trong alert engine) |
| BR-R13 | AML T1–T6 + UBO ≥25% (mặc định theo DI-001) chấm điểm trên dữ liệu giao dịch của ledger; điều chỉnh phát hiện từ đối trừ vẫn qua dual approval + AML; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý — không tự động tính từ số đối soát (CMS §3.10) | Điều chỉnh vượt ngưỡng AML → hold theo FEAT-CORE-WALLET-006; không thể "điều chỉnh cho khớp" trùng lúc nghi vấn AML |
| BR-R14 | Portal chỉ đọc số dư ví + trạng thái đối soát ở mức dành cho khách (REQ-FIN-017) — tenant isolation; số tranh chấp hiển thị "Đang đối soát"; khách không thấy ticket nội bộ, dung sai, giá vốn | Truy vấn Portal ép điều kiện tenant; trạng thái đối soát chi tiết nội bộ không nằm trong view khách |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|-----------|-------------------|
| Xem kết quả đối soát theo khách được gán | ✅ | ✅ (toàn bộ) | ✅ (tổng hợp) | ❌ | ✅ (tenant mình, mức tổng hợp) |
| Xử lý ticket discrepancy, giải trình | ✅ | ✅ (duyệt giải trình) | ❌ | ❌ | ❌ |
| Rà khoản sai lệch trong dung sai theo tuần | ✅ | ✅ | ✅ | ❌ | ❌ |
| Chốt công nợ nền tảng tháng / chốt kỳ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt mở kỳ (phiếu lý do/phạm vi/thời hạn) | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt điều chỉnh >10 triệu VND / ảnh hưởng P&L đã chốt | ❌ | ❌ | ✅ | ❌ | ❌ |
| Import/nhập tay dữ liệu đối soát nhãn `manual` | ✅ (qua WEB, ghi ai nhập + căn cứ) | ❌ | ❌ | ❌ | ❌ |
| Cấu hình dung sai / lịch đối trừ | ❌ | ❌ | ✅ (phê duyệt mức) | ✅ (thao tác cấu hình) | ❌ |
| Sửa/xóa chứng từ kỳ đã khóa | ❌ | ❌ | ❌ (chỉ qua phiếu mở kỳ) | ❌ | ❌ |
| Tự cân số hai vế cho khớp | ❌ | ❌ | ❌ | ❌ | ❌ (bị cấm tuyệt đối) |

---

## 5. Trường Hợp Đặc Biệt

- **Sai lệch timing/tỷ giá giữa BC và nền tảng:** nạp ghi ngày D trên sổ BC nhưng nền tảng phản ánh D+1, hoặc tỷ giá chênh — xử lý qua khoản FX riêng/khớp theo chu kỳ, không tính vi phạm dung sai (BR-FIN-201 exception).
- **Nền tảng chưa có API (degraded `manual`):** đối soát ngày hạ xuống tuần qua import statement chuẩn; khi được cấp API/Business Verification, GW backfill và Core tự đối soát lại các kỳ nhập tay — chênh lệch phát sinh sau backfill tạo ticket mới, không sửa ticket cũ.
- **Tiền về không khớp lệnh nào (treo chờ đối chiếu):** dòng chưa xác định khách chưa tham gia đối trừ vế 1; khi FIN_L1 xác định xong mới đưa vào — tránh khớp nhầm sang ví khách khác.
- **Refund từ nền tảng (TKQC die còn dư):** khớp tiền hoàn về theo giao dịch gốc; hoàn cho khách qua dual approval — dòng đối soát liên quan gắn với cả 2 lệnh để truy vết.
- **Ticket quá hạn giải trình:** tự escalate FIN_L2 và báo cáo BOD_CFO_CTO; kỳ chứa ticket quá hạn bị chặn chốt cho đến khi xử lý.
- **Chốt kỳ trùng ngày 1–2 tháng (lễ/Tết):** mốc "ngày 3" là ngày làm việc kế tiếp `[CẦN CHỐT SỐ]`; hệ thống vẫn chặn chốt khi còn ticket bất kể áp lực thời gian.
- **Điều chỉnh phát hiện lỗi hệ thống/nhập liệu:** xử lý bằng reversal có reason code, không sửa dòng gốc; dòng gốc giữ nguyên làm bằng chứng kiểm toán.
- **Khách có nhiều ví multi-currency:** đối trừ chạy riêng từng currency; tổng hợp tuần/tiêu tích lũy quy VND theo snapshot tỷ giá từng giao dịch — không dùng tỷ giá hiện hành để quy hồi.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity 1:** Dòng đối soát (ReconciliationLine) · **Entity 2:** Kỳ kế toán (AccountingPeriod)

**Sơ đồ trạng thái (Entity 1):**
```
[CHƯA ĐỐI SOÁT] ──(run đối trừ)──► [ĐÃ ĐỐI SOÁT] (khớp hoặc trong dung sai)
        │
        └──(vượt dung sai)──► [CHÊNH LỆCH] ──(điều chỉnh qua dual approval)──► [ĐÃ ĐIỀU CHỈNH]
```

**Bảng chuyển đổi (Entity 1):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CHƯA ĐỐI SOÁT` | Run đối trừ khớp/within dung sai | `ĐÃ ĐỐI SOÁT` | Hệ thống | 3 vế đủ; ghi nhãn nguồn từng vế |
| `CHƯA ĐỐI SOÁT` | Run đối trừ vượt dung sai | `CHÊNH LỆCH` | Hệ thống | Tự tạo ticket discrepancy đủ thông tin |
| `CHÊNH LỆCH` | Điều chỉnh có phiếu duyệt | `ĐÃ ĐIỀU CHỈNH` | FIN_L1 đề xuất + FIN_L2/BOD_CFO_CTO duyệt | Phiếu duyệt từ FEAT-CORE-WALLET-003; reason code |
| `CHÊNH LỆCH` | Kết luận sai lệch trong dung sai sau điều tra | `ĐÃ ĐỐI SOÁT (dung sai)` | FIN_L2 | Hạch toán tài khoản sai lệch đối soát |

**Bảng chuyển đổi (Entity 2 — Kỳ):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Chốt kỳ | `LOCKED` | FIN_L2 | Không còn ticket discrepancy mở trong kỳ |
| `LOCKED` | Mở kỳ theo phiếu | `REOPENED` | BOD_CFO_CTO | Phiếu mở kỳ: lý do, phạm vi, thời hạn + audit log |
| `REOPENED` | Chốt lại | `LOCKED` | FIN_L2 | Bắt buộc chốt lại sau sửa; phiếu mở kỳ đóng |

**Quy tắc:**
- `LOCKED` là trạng thái mục tiêu của mọi kỳ; `REOPENED` là ngoại lệ có kiểm soát — không tồn tại trạng thái "mở vĩnh viễn".
- Dòng `ĐÃ ĐIỀU CHỈNH` là trạng thái kết thúc của dòng đối soát; sửa tiếp chỉ qua dòng điều chỉnh mới (reversal).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ReconciliationLine` | `ad_account_id`, `customer_id`, `platform_id`, `currency`, `date`, `v1_ledger`, `v2_platform`, `v3_spend`, `status`, `tolerance_applied` | FK → `wallets.id`, `ad_accounts.id` | 4 trạng thái; gán tự động sau run |
| `DiscrepancyTicket` | `recon_line_id`, `two_numbers`, `sources`, `opened_at`, `explain_due`, `resolved_at`, `resolution` | FK → `reconciliation_lines.id` | Quá hạn giải trình tự escalate FIN_L2 + BOD |
| `FxRateSnapshot` | `rate`, `source` (ngân hàng quy chuẩn), `locked_at`, `transaction_id` | FK → `wallet_transactions.id` | Khóa sau ghi nhận; sai khác → khoản FX riêng |
| `FxGainLossEntry` | `customer_id`, `period`, `amount`, `nature` (lãi/lỗ) | FK → `customers.id` | Khoản riêng, tách khỏi giá vốn & GM |
| `AccountingPeriod` | `period`, `status` (OPEN/LOCKED/REOPENED), `closed_by`, `closed_at` | — | Chốt ngày 3 `[CẦN CHỐT SỐ]`; chặn khi còn ticket |
| `PeriodReopenSlip` (phiếu mở kỳ) | `period_id`, `reason`, `scope`, `valid_until`, `approved_by` (BOD_CFO_CTO) | FK → `accounting_periods.id` | Mở theo phiếu, không hàng loạt; chốt lại bắt buộc |
| `ReconDataSource` | `platform_id`, `source` (`api`/`manual`), `import_batch_id`, `imported_by`, `basis` | FK → `platforms.id` | Sai schema chặn từng dòng; backfill khi API sống |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khớp 3 vế đúng dung sai | Nạp sổ = nạp platform = 1.000 USD; chi tiêu lệch 3 USD (≤0,5% & ≤10 USD) | Job ngày chạy | 2 dòng `ĐÃ ĐỐI SOÁT` (chi tiêu ghi "dung sai"); không tạo ticket | [ ] |
| SC-002: Vượt dung sai mở ticket | Chi tiêu platform cao hơn 15 USD/TK/ngày | Job ngày chạy | Dòng → `CHÊNH LỆCH`; ticket đủ (TKQC, nền tảng, khách, 2 con số, nguồn, timestamp) | [ ] |
| SC-003: Cấm tự cân số | Ticket đang mở | FIN_L1 sửa số vế 1 cho khớp vế 2 không qua phiếu duyệt | Chặn + log; số vế 1 nguyên vẹn (append-only) | [ ] |
| SC-004: Chặn chốt khi còn ticket | Kỳ tháng còn 1 ticket chưa giải trình | FIN_L2 bấm chốt kỳ | Service từ chối kèm danh sách ticket; kỳ giữ `OPEN` | [ ] |
| SC-005: Khóa kỳ tầng dữ liệu | Kỳ đã `LOCKED` | Gọi SQL/API sửa chứng từ trong kỳ | DB từ chối (không chỉ UI); audit log ghi nỗ lực | [ ] |
| SC-006: Mở kỳ đúng phiếu | Kỳ `LOCKED` | BOD_CFO_CTO lập phiếu lý do/phạm vi/thời hạn và duyệt | Kỳ → `REOPENED` theo phạm vi phiếu; sau sửa bắt buộc chốt lại | [ ] |
| SC-007: Snapshot tỷ giá không truy lịch | Giao dịch USD đã ghi với snapshot 25.500 | Thử UPDATE snapshot | Chặn tầng dữ liệu; sai khác xử lý qua `FxGainLossEntry` | [ ] |
| SC-008: Đối soát hạ tuần khi manual | Nền tảng X chưa có API, dữ liệu import nhãn `manual` | Job tuần chạy | Đối trừ theo chu kỳ tuần; nhãn nguồn hiển thị; API sống → backfill + đối soát lại | [ ] |

> **Liên kết:** SC-001→008 map REQ-FIN-004 Mục 2 (A3, BR-FIN-201…205); SC-008 dùng chung REQ-FIN-005 (degraded mode); SC-007 liên kết REQ-FIN-003 (đổi tỷ giá tay).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — ReconciliationLine, DiscrepancyTicket, AccountingPeriod, FxRateSnapshot | `technical-specs/database-design.md` |
| API Endpoints — job đối trừ, ticket, chốt/khóa kỳ, phiếu mở kỳ | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW vế 2–3 (REQ-FIN-005), dual approval (FEAT-003) | `technical-specs/integration-map.md` |
| Màn hình UI (đối soát + ticket thuộc SYS-BCERP-WEB) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 (§3.5/§3.8/§5) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
