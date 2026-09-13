# Tính Năng: Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ)

> **Dựa trên:** REQ-FIN-001 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5 Wallet, §3.6 RechargeRequest, §3.8 TopupTransaction, §5 công thức k)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-001-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-001 (REQ xuất hiện ở 3 systems). Counterparts: SYS-BCERP-WEB (kênh thao tác chính), SYS-MOBILE-INTERNAL (theo dõi + cảnh báo). Touchpoint Core Backend là **headless API/domain service**: mọi business rule dưới đây được enforce ở tầng service (không tin UI), audit log bất biến + tenant isolation là bắt buộc.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-001 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-001 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO, OPS_AM/OPS_ADS (đề xuất lệnh), CUSTOMER (Portal read-only) |
| Độ ưu tiên | Cao (HIGH · GĐ2 — khung tối thiểu phục vụ Financial Hard Stop có từ GĐ1) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có — đây là nền móng ledger của module; FEAT-CORE-WALLET-002/003/004/005/006/007 đều phụ thuộc tính năng này |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); điểm phối hợp liên phòng đã xác định: gate Hard Stop + KYC nằm trong vòng đời cấp phát TKQC do OPS vận hành — FIN nắm quyền xác nhận; REQ-FIN-017 ranh giới dữ liệu Portal phối hợp customer-expert/legal-expert |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng sổ phụ ví (wallet ledger) per-khách trên Core Backend làm **nguồn sự thật duy nhất** của toàn bộ giao dịch tiền trong mô hình cho thuê TKQC — nạp, chi tiêu, phí, điều chỉnh, hoàn tiền, số dư khả dụng — với nguyên tắc bất di bất dịch: tiền khách nạp là **tiền giữ hộ (nợ phải trả — liability)**, tuyệt đối không tự động hạch toán thành doanh thu; doanh thu chỉ ghi nhận trên phí dịch vụ/markup theo hợp đồng. Mọi giao dịch tiền phải đi qua **lệnh hệ thống** chứa đủ dữ liệu bắt buộc; lệnh miệng qua Zalo/điện thoại/email riêng không có giá trị đối chiếu và bị kế toán từ chối.

**Phạm vi:**
- Bao gồm: Wallet per-khách multi-currency (USD/VND tách bạch, không gộp quy đổi); vòng lệnh nạp chuẩn 5 bước (tạo lệnh → khách chuyển khoản → FIN_L1 đối chiếu sao kê → ghi nhận ví + snapshot tỷ giá → "Đã khớp tiền"); lệnh nạp với approval mode SINGLE/DUAL (1 công tắc toàn hệ thống); lệnh top-up Wallet → AdAccount tính theo công thức k hai chiều NET/GROSS với snapshot fee %; chặn ghi nhận số tiền ngoài lệnh ở tầng service; ledger append-only (sửa chỉ qua reversal có reason code); cảnh báo số dư chỉ đọc số dư từ ledger (logic alert thuộc FEAT-CORE-WALLET-002).
- Không bao gồm: đối trừ 3 số và chốt/khóa kỳ (FEAT-CORE-WALLET-004); xác nhận "đã khớp tiền" mở Financial Hard Stop (FEAT-CORE-WALLET-005); dual approval cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền (FEAT-CORE-WALLET-003); AML monitoring T1–T6 (FEAT-CORE-WALLET-006); màn hình UI tạo/duyệt lệnh (SYS-BCERP-WEB); pull số dư/spend từ nền tảng (SYS-INTEGRATION-GW theo REQ-FIN-005); view số dư cho khách (SYS-PORTAL-WEB — Core chỉ cung cấp view đã lọc tenant).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM / OPS_ADS | Tạo lệnh đề xuất nạp trên hệ thống (qua WEB) chứa khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ | Mọi giao dịch tiền có dấu vết hệ thống, FIN chấp nhận đối chiếu, không còn lệnh miệng Zalo/điện thoại |
| 2 | FIN_L1 | Đối chiếu sao kê ngân hàng ↔ lệnh nạp: số tiền khớp, người chuyển trùng tên pháp nhân KYC, mã tham chiếu đúng | Chỉ ghi nhận tiền có căn cứ rõ ràng vào ví khách, không ghi "gần đúng" |
| 3 | FIN_L1 | Khi tiền về không khớp lệnh nào, treo trạng thái "chờ đối chiếu" và phối hợp AM xác định khách | Cấm ghi vào ví sai khách, giữ ledger sạch để đối trừ 3 số sau này đáng tin |
| 4 | FIN_L2 | Duyệt lệnh nạp theo approval mode của hệ thống (SINGLE 1 lần duyệt; DUAL tuần tự FIN_L1 → FIN_L2) | Kiểm soát dòng tiền vào ví khách đúng thẩm quyền, chống gian lận nội bộ |
| 5 | BOD_CFO_CTO | Xem tổng quan số dư tiền giữ hộ theo khách/tiền tệ và biết đây là nợ phải trả, tách khỏi P&L dịch vụ | Ra quyết định dòng tiền mà không bị số tiền khách gửi nhầm thành "doanh thu" đánh lừa |
| 6 | CUSTOMER (Portal, GĐ3) | Xem số dư ví của tenant mình qua view tổng hợp read-only do Core cấp | Minh bạch dữ liệu tài chính của mình mà không gọi hỏi AM; không thấy được tenant khác hay giá vốn |
| 7 | Hệ thống (Core service) | Tự động tạo snapshot tỷ giá (nguồn ngân hàng quy chuẩn) tại thời điểm ghi nhận và khóa snapshot sau ghi nhận | Không ai truy lịch sửa tỷ giá; sai lệch timing/tỷ giá xử lý qua khoản FX riêng, không sửa gốc |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; mọi vi phạm bị chặn ở API kể cả khi UI bị bỏ qua.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency: mỗi khách có Wallet tách theo `currency` (USD/VND không gộp quy đổi), tách `availableBalance`/`frozenBalance`; không gộp chung, không bù trừ chéo ví, không cho số dư âm nếu chưa có lệnh điều chỉnh được duyệt (CMS §3.5; BR-FIN-101) | Service từ chối giao dịch, trả lỗi `WALLET_CROSS_CURRENCY_DENIED` / `NEGATIVE_BALANCE_DENIED`; ghi audit log nỗ lực vi phạm |
| BR-W02 | Tiền khách nạp là **tiền giữ hộ — nợ phải trả**: Core cấm cấu hình tự động hạch toán nạp → doanh thu; mọi báo cáo tách bạch tiền giữ hộ khỏi P&L dịch vụ; doanh thu chỉ ghi trên phí dịch vụ/markup | Chặn cấu hình/lệnh hạch toán sai tại service layer; cảnh báo BOD_CFO_CTO khi phát hiện cấu hình bất thường |
| BR-W03 | Mọi top-up/refund/điều chỉnh phải tạo **lệnh hệ thống** chứa đủ: khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ; lệnh theo dõi trạng thái đến hoàn tất; lệnh miệng (Zalo/điện thoại/email riêng) không có giá trị đối chiếu (BR-FIN-102) | Service chặn mọi ghi nhận số tiền không dựa trên lệnh (`NO_ORDER_DENIED`); kế toán từ chối đối chiếu lệnh miệng |
| BR-W04 | Vòng lệnh nạp chuẩn 5 bước, mỗi bước ghi danh tính + timestamp: (1) khách chuyển khoản theo lệnh; (2) FIN_L1 đối chiếu sao kê ↔ lệnh (số tiền khớp, tên trùng pháp nhân KYC, mã tham chiếu đúng); (3) khớp → ghi nhận ví (tiền giữ hộ tăng), cấm ghi nhận khi chưa có lệnh hoặc số lệch; (4) Core tạo snapshot tỷ giá tại thời điểm ghi nhận, khóa sau ghi nhận; (5) số dư khả dụng cập nhật, lệnh chuyển "Đã khớp tiền" — mở điều kiện Financial Hard Stop (BR-FIN-103, FEAT-CORE-WALLET-005) | Chặn ghi nhận ở bước 3 khi thiếu lệnh/lệch số; snapshot không cho UPDATE/DELETE sau ghi nhận |
| BR-W05 | Approval mode của lệnh nạp: **1 công tắc toàn hệ thống** `SINGLE/DUAL`, SYS_ADMIN bật/tắt thủ công khi phòng kế toán đủ người — không theo ngưỡng số tiền, không tự động (CMS §3.6). `SINGLE`: bất kỳ FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần. `DUAL`: duyệt tuần tự đúng cấp — bước 1 bắt buộc FIN_L1 (ACCOUNTANT), bước 2 bắt buộc FIN_L2 (CHIEF_ACCOUNTANT), không đảo thứ tự, không cùng 1 người duyệt cả 2 bước | Service chặn submit thiếu chữ ký hoặc sai thứ tự (`APPROVAL_SEQUENCE_INVALID`); mọi lượt duyệt ghi audit log bất biến |
| BR-W06 | Công thức top-up Wallet → AdAccount: `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`; nhập NET (NSQC) → `grossAmount = netAmount × k` trừ ví; nhập GROSS (tổng tiền) → `netAmount = grossAmount / k` (CMS §5; ví dụ fee 3%, vatOnFee 8%, vatOnSpend 8% → k = 1,1124). Lưu **snapshot** fee/vat % tại thời điểm giao dịch, không tham chiếu sống tới Contract — Contract đổi % sau này không ảnh hưởng giao dịch cũ | Tính toán chạy trong service, test 2 chiều phải khớp ngược chính xác; sai khớp ngược → chặn giao dịch |
| BR-W07 | Ledger append-only: sửa số dư chỉ qua giao dịch điều chỉnh/reversal có **reason code bắt buộc**; chặn UPDATE/DELETE ở tầng dữ liệu; Super Admin cũng không sửa được dữ liệu giao dịch tiền (BR-FIN-101/501) | DB account của app chỉ có INSERT/SELECT trên bảng giao dịch; yêu cầu sửa trực tiếp bị từ chối + log |
| BR-W08 | SoD 4 vai dòng tiền: người tạo/đề xuất (OPS_AM/OPS_ADS) ≠ người khớp tiền (FIN_L1) ≠ người duyệt chi (FIN_L2) ≠ người ghi sổ; một người không giữ ≥2 vai trong cùng chuỗi giao dịch (BR-FIN-106) | SoD engine chặn submit/gán duyệt khi vai trùng; log vi phạm append-only cho BOD_CFO_CTO rà định kỳ |
| BR-W08a | SoD tường minh trên từng lệnh: người tạo lệnh không được duyệt chính lệnh đó (**approver ≠ creator**), áp dụng cả chế độ SINGLE — FIN_L1 không tự duyệt lệnh do mình khởi tạo; engine so sánh `createdBy` và `approvedBy` trên cùng một lệnh trước khi ghi nhận chữ ký duyệt | Vi phạm bị chặn ở service layer (`SOD_SELF_APPROVAL_DENIED`) + ghi audit log append-only cho BOD_CFO_CTO rà định kỳ |
| BR-W09 | Cảnh báo số dư đọc từ ledger này: Core tính số dư đủ chi theo ADS 7 ngày rolling, phân 3 mức Xanh (≥3 ngày)/Vàng (<3)/Đỏ (<1 hoặc dưới mức tối thiểu nền tảng), SLA đỏ 2h — chi tiết tại FEAT-CORE-WALLET-002 (BR-FIN-104) | — (rule chi tiết thuộc FEAT-002; ledger chỉ bảo đảm số dư real-time nhất quán) |
| BR-W10 | Đối trừ 3 số (sổ ví – platform – ngân hàng) dùng ledger này làm vế 1; dung sai nạp = 0/dòng (ngày), chi tiêu ≤0,5% hoặc ≤10 USD/TK/ngày, tích lũy ≤1% hoặc ≤20 USD/khách/tuần (mức mặc định đã chốt theo DI-001); chốt & khóa kỳ — chi tiết tại FEAT-CORE-WALLET-004 (BR-FIN-201/204) | — (rule chi tiết thuộc FEAT-004) |
| BR-W11 | AML monitoring T1–T6 + UBO ≥25% (ngưỡng mặc định đã chốt theo DI-001, cấu hình được không sửa code) chạy trên mọi lệnh nạp/hoàn/điều chỉnh của ledger; hoàn tiền đúng nguồn — chi tiết tại FEAT-CORE-WALLET-006; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10) — rebate không nằm trong công thức BR-W06 | Giao dịch nghi vấn bị khóa mềm (hold) đến khi có quyết định (chi tiết FEAT-006) |
| BR-W12 | Portal chỉ đọc số dư ví (REQ-FIN-017): Core cung cấp view tổng hợp đã lọc theo tenant, tenant isolation 2 lớp (RLS DB + filter API); Portal không ghi dữ liệu tài chính; khách không thấy giá vốn, chiết khấu, P&L, tenant khác | Mọi truy vấn từ Portal bị ép điều kiện `tenant_id`; truy cập chéo tenant bị từ chối + meta-log |

**Giả định chờ xác nhận:** mốc chốt kỳ "ngày 3 tháng kế tiếp" vẫn là `[CẦN CHỐT SỐ]` (BR-FIN-107/204); ngưỡng hoàn tiền/điều chỉnh >10 triệu VND thuộc thẩm quyền BOD_CFO_CTO dùng mức mặc định theo DI-001, rà lại khi chính sách hạn mức chi ban hành. 11 KXN còn mở (KXN-6/7/9/15–22) thuộc domain CRM/lifecycle — không tác động business rule của module này.

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_AM/OPS_ADS | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|----------------|-----------|-------------------|
| Xem sổ phụ ví khách được gán | ✅ | ✅ (toàn bộ khách) | ✅ (tổng hợp) | ❌ (chỉ trạng thái TKQC, không dòng tiền chi tiết) | ❌ (không xem dữ liệu nghiệp vụ) | ✅ (tenant mình, read-only) |
| Tạo lệnh nạp/đề xuất | ✅ | ✅ | ✅ | ✅ (đề xuất) | ❌ | ❌ |
| Duyệt lệnh nạp — SINGLE | ✅ (không tự duyệt lệnh do mình tạo — BR-W08a) | ✅ (≠ người tạo lệnh) | ✅ (≠ người tạo lệnh) | ❌ | ❌ | ❌ |
| Duyệt lệnh nạp — DUAL bước 1 | ✅ (bắt buộc) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt lệnh nạp — DUAL bước 2 | ❌ | ✅ (bắt buộc) | ❌ | ❌ | ❌ | ❌ |
| Đối chiếu sao kê ↔ lệnh, ghi nhận ví | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ghi sổ / thực thi giao dịch | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Bật/tắt approval mode SINGLE/DUAL | ❌ | ❌ | ❌ | ❌ | ✅ (công tắc hệ thống) | ❌ |
| Sửa/xóa dòng ledger | ❌ | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin) | ❌ — chỉ qua reversal có reason code |

---

## 5. Trường Hợp Đặc Biệt

- **Tiền về không khớp lệnh nào:** treo trạng thái "chờ đối chiếu", FIN_L1 phối hợp AM xác định khách; cấm ghi vào ví "gần đúng" — chỉ ghi khi xác định được khách và lệnh gốc.
- **Sai khác giữa biên bản đối chiếu với khách và lệnh gốc:** không sửa lệnh gốc; xử lý qua lệnh điều chỉnh dual approval (FEAT-CORE-WALLET-003), giữ nguyên lịch sử.
- **TK client-owned (khách tự nạp trực tiếp nền tảng):** không phát sinh lệnh nạp của BC — chỉ ghi nhận đối soát; TK Internal-Sandbox không gắn khách, không thuộc ví khách nào (BR-FIN-101 exception).
- **Khẩn ngoài giờ:** vẫn phải tạo lệnh trên hệ thống trước khi xử lý — approval không được bỏ qua; xử lý nhanh hơn nhưng không bỏ bước.
- **Refund từ platform (TK die còn dư):** FIN_L1 khớp tiền hoàn về theo giao dịch gốc và ghi có; không hoàn cho khách trước khi có đề xuất AM + duyệt FIN_L2.
- **Contract đổi fee % sau khi đã có giao dịch:** giao dịch cũ giữ snapshot fee % của thời điểm giao dịch — không recalculate, không sửa đè lịch sử.
- **Khách nhiều pháp nhân (tập đoàn):** ví gắn pháp nhân đã KYC; danh sách pháp nhân được phép liệt kê trắng trong hợp đồng (phối hợp KYC BR-FIN-401), mỗi pháp nhân là tenant riêng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh nạp (RechargeRequest) —approval mode SINGLE/DUAL theo công tắc hệ thống; trạng thái khớp tiền là đầu vào của Financial Hard Stop (FEAT-CORE-WALLET-005).

**Sơ đồ trạng thái:**
```
[PENDING] ──(duyệt, SINGLE)────────────────► [APPROVED] ──(đối chiếu sao kê khớp)──► [ĐÃ KHỚP TIỀN]
    │  └─(duyệt bước 1, DUAL — FIN_L1)► [STEP1_APPROVED] ──(duyệt bước 2 — FIN_L2)┘        │
    │                                            │                                          │
    │ (reject + lý do)                           │ (reject + lý do)                         │ (thu hồi xác nhận sai — FIN_L1)
    ▼                                            ▼                                          ▼
[REJECTED] ──(khách khiếu nại)──► [DISPUTED] ──(quay lại review)──► [PENDING]      [KHỚP TIỀN BỊ THU HỒI]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Duyệt (SINGLE) | `APPROVED` | FIN_L1 / FIN_L2 / BOD_CFO_CTO (1 người) | Mode hệ thống = SINGLE; duyệt 1 lần là xong; người duyệt ≠ người tạo lệnh (BR-W08a) |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (bắt buộc) | Mode hệ thống = DUAL; ghi danh tính + timestamp |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (bắt buộc) | Người duyệt ≠ người duyệt bước 1; không đảo thứ tự |
| `PENDING` / `STEP1_APPROVED` | Từ chối | `REJECTED` | Theo mode hiện hành | Bắt buộc nhập lý do từ chối |
| `REJECTED` | Khách khiếu nại | `DISPUTED` | CUSTOMER (qua AM) → FIN_L2 xem lại | Quay lại `PENDING` review; ghi cả hai vòng |
| `APPROVED` | Đối chiếu sao kê khớp | `ĐÃ KHỚP TIỀN` | FIN_L1 | Số tiền khớp, tên trùng pháp nhân KYC, mã tham chiếu đúng; snapshot tỷ giá đã tạo |
| `ĐÃ KHỚP TIỀN` | Thu hồi xác nhận sai | `KHỚP TIỀN BỊ THU HỒI` | FIN_L1 | TKQC tự chuyển "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL (BR-FIN-302) |

**Quy tắc:**
- Không được duyệt cả 2 bước DUAL bằng một người, kể cả BOD_CFO_CTO kiêm nhiệm — compensating control: giao dịch của BOD_CFO_CTO khởi tạo vượt ngưỡng do BOD_CEO duyệt thay.
- `ĐÃ KHỚP TIỀN` là điều kiện cần duy nhất để mở Financial Hard Stop; mọi yêu cầu mở khóa thủ công khi chưa khớp bị từ chối + audit log bất biến.
- Mọi chuyển trạng thái ghi audit log append-only: ai, khi nào, giá trị old→new, reason code.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Wallet` | `customer_id`, `currency`, `available_balance`, `frozen_balance` | FK → `customers.id` | 1 khách nhiều ví theo currency; USD/VND không gộp quy đổi |
| `WalletTransaction` | `wallet_id`, `type` (NẠP/CHI TIÊU/PHÍ/ĐIỀU CHỈNH/HOÀN), `amount`, `currency`, `fx_snapshot_id`, `balance_after`, `reason_code` | FK → `wallets.id`, `fx_snapshots.id` | Append-only; chặn UPDATE/DELETE tầng DB |
| `RechargeRequest` (lệnh nạp) | `customer_id`, `ad_account_id`, `amount`, `currency`, `approval_mode`, `status`, `evidence`, `step1_by`, `step2_by` | FK → `customers.id`, `ad_accounts.id` | State machine §6; lệnh là input duy nhất FIN chấp nhận |
| `TopupTransaction` | `input_mode` (NET/GROSS), `net_amount`, `fee_amount`, `vat_on_fee_amount`, `vat_on_spend_amount`, `gross_amount`, `fee_percent_snapshot`, `vat_on_fee_snapshot`, `vat_on_spend_snapshot` | FK → `wallets.id`, `ad_accounts.id`, `contracts.id` | Công thức k (CMS §5); snapshot fee % không tham chiếu sống Contract |
| `ExchangeRateSnapshot` | `rate`, `source` (ngân hàng quy chuẩn), `locked_at` | FK → `wallet_transactions.id` | Khóa sau ghi nhận; sai khác xử lý qua khoản FX riêng |
| `PortalBalanceView` | `tenant_id`, `wallet_balance`, `daily_spend`, `as_of` | View lọc `tenant_id` | Read-only, 2 lớp isolation (RLS + filter API); mask giá vốn |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Ghi nhận nạp đúng lệnh | Lệnh nạp `PENDING`, khách đã chuyển khoản đúng số/tên/mã tham chiếu | FIN_L1 đối chiếu sao kê và xác nhận khớp | Tiền giữ hộ tăng đúng currency; snapshot tỷ giá tạo và khóa; lệnh → `ĐÃ KHỚP TIỀN`; audit log ghi đủ | [ ] |
| SC-002: Chặn ghi nhận ngoài lệnh | Không tồn tại lệnh cho số tiền về | Gọi API ghi nhận ví | Service trả `NO_ORDER_DENIED`; không thay đổi số dư; nỗ lực được log | [ ] |
| SC-003: DUAL đúng thứ tự | Mode = DUAL, lệnh `PENDING` | FIN_L2 cố duyệt trước bước 1 | Chặn `APPROVAL_SEQUENCE_INVALID`; lệnh giữ `PENDING` | [ ] |
| SC-004: Công thức k 2 chiều | fee 3%, vatOnFee 8%, vatOnSpend 8% (k = 1,1124) | Nhập NET 1.000 → kiểm tra gross; nhập GROSS 1.112,4 → kiểm tra net | gross = 1.112,4; net = 1.000; snapshot fee % lưu tại thời điểm giao dịch | [ ] |
| SC-005: Không gộp chéo tiền tệ | Ví USD 500 và ví VND 10 triệu cùng khách | Thử bù trừ chéo/quy đổi gộp tự động | Từ chối; 2 ví tách bạch, số dư nguyên vẹn | [ ] |
| SC-006: Portal tenant isolation | Khách A có 2 ví; tenant B tồn tại | Khách A gọi Portal API truy ví tenant B | Từ chối; meta-log ghi nỗ lực; khách A chỉ thấy số dư tenant A | [ ] |
| SC-007: Reversal có reason code | Giao dịch ghi sai cần điều chỉnh | Tạo reversal không reason code | Chặn submit; bổ sung reason code → reversal ghi nhận, dòng gốc nguyên vẹn | [ ] |

> **Liên kết:** SC-001→005 map REQ-FIN-001 Mục 2 (A3); SC-006 map REQ-FIN-017 (ràng buộc biên Portal); SC-007 map REQ-FIN-012 (nền móng audit).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — Wallet, WalletTransaction, RechargeRequest, snapshot | `technical-specs/database-design.md` |
| API Endpoints — wallet ledger, lệnh nạp, topup NET/GROSS, portal balance view | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — biên GW (REQ-FIN-005), Portal (REQ-FIN-017), counterparts WEB/MOBILE | `technical-specs/integration-map.md` |
| Màn hình UI (kênh thao tác thuộc SYS-BCERP-WEB — sổ phụ, đối chiếu sao kê) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 (§3.5/3.6/3.8/§5) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
