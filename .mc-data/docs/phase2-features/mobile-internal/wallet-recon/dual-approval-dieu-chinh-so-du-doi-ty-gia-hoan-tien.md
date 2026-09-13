# Tính Năng: Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền

> **Dựa trên:** REQ-FIN-003 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md` (BR-FIN-105/106, BR-FIN-402), `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS §3.6)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-003-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-FIN-003 (REQ xuất hiện ở 3 systems). Counterparts: SYS-CORE-BACKEND (chặn thực thi khi thiếu chữ ký — enforce ở service layer), SYS-BCERP-WEB (kênh tạo/duyệt chính). Touchpoint Mobile nội bộ là **app React Native offline-capable**: bản spec này mô tả trải nghiệm **duyệt-on-the-go** cho FIN_L2/BOD_CFO_CTO — đây là một trong hai use case mobile được phép có action (cùng duyệt giải ngân REQ-FIN-008), với **MFA TOTP bắt buộc** và điều kiện online bắt buộc cho mọi chữ ký.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-003 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-003 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (ledger + lệnh); FEAT-CORE-WALLET-003 (engine dual approval trên Core); FEAT-MBI-WALLET-001 (màn theo dõi ví/lệnh — nền hiển thị) |
| Ghi chú Expert (A7) | Dept doc finance.md có cấu trúc A7; phần review chưa thực hiện chính thức. Ngưỡng refund/điều chỉnh >10 triệu VND thuộc thẩm quyền BOD_CFO_CTO dùng mức mặc định đã chốt theo DI-001 (khung hạn mức chi 5/50/200 triệu), rà lại khi chính sách hạn mức chi ban hành — không tự quyết con số mới |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép FIN_L2 và BOD_CFO_CTO thực hiện chữ ký duyệt thứ hai (hoặc chữ ký duyệt ở chế độ SINGLE) cho 3 nhóm giao dịch rủi ro cao nhất của ví — **điều chỉnh số dư thủ công, đổi tỷ giá thủ công, hoàn tiền cho khách** — ngay trên điện thoại khi đang di chuyển, với MFA TOTP bắt buộc ở mọi chữ ký. Nguyên tắc cốt lõi: người đề xuất ≠ người duyệt, mọi bước ghi danh tính + timestamp vào audit log bất biến trên Core; mobile chỉ là **kênh nhập chữ ký**, toàn bộ logic chặn thiếu chữ ký nằm ở service layer của Core nên không thể bị vòng qua ứng dụng.

**Phạm vi:**
- Bao gồm: hàng chờ duyệt (queue) các lệnh điều chỉnh số dư/đổi tỷ giá/hoàn tiền chờ chữ ký của người dùng hiện tại; màn chi tiết lệnh đủ căn cứ duyệt (khách, lệnh nạp gốc, số tiền, tiền tệ, snapshot tỷ giá, lý do, biên bản đính kèm); hành động duyệt/từ chối với MFA TOTP bắt buộc + reason code bắt buộc khi từ chối; hiển thị trạng thái chữ ký theo mode SINGLE/DUAL (công tắc toàn hệ thống) và chặn thấy nút duyệt khi chính mình là người đề xuất; push nhắc duyệt theo SLA hàng chờ; chế độ online bắt buộc — offline chỉ đọc được chi tiết lệnh đã cache, không gửi được chữ ký.
- Không bao gồm: tạo mới lệnh điều chỉnh/đổi tỷ giá/hoàn tiền (kênh tạo chính là Web — màn FIN_L1 chuyên dụng; mobile không có form tạo); thực thi ghi sổ (Core); quyết định hoàn/điều chỉnh từ AML alert (FEAT-MBI-WALLET-005); duyệt giải ngân theo ngưỡng chi REQ-FIN-008 (phân hệ duyệt chi riêng); hiển thị hồ sơ KYC/UBO chi tiết (giới hạn theo BR-FIN-603 — mobile không hiển thị dữ liệu định danh nhạy cảm).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Nhận push về lệnh hoàn tiền chờ chữ ký thứ hai và duyệt bằng MFA TOTP ngay trên điện thoại | Không chặn luồng hoàn tiền của khách chỉ vì tôi đang ngoài văn phòng, mà vẫn giữ đúng dual approval |
| 2 | FIN_L2 | Xem trong màn duyệt đủ căn cứ: lệnh nạp gốc, số tiền, tiền tệ, biên bản đối chiếu và lý do điều chỉnh | Quyết định chữ ký dựa trên bằng chứng, không duyệt "tin lời" |
| 3 | FIN_L2 | Bị hệ thống chặn khi mở lệnh do chính mình đề xuất | Nguyên tắc người đề xuất ≠ người duyệt được thực thi kỹ thuật, không phụ thuộc ý thức |
| 4 | FIN_L1 | Tạo lệnh điều chỉnh từ Web rồi theo dõi trên mobile lệnh của mình đang đứng ở bước chữ ký nào | Biết khi nào cần nhắc người duyệt, không phải hỏi lại qua chat |
| 5 | BOD_CFO_CTO | Duyệt các lệnh hoàn/điều chỉnh vượt ngưỡng >10 triệu VND trên mobile với MFA TOTP | Kênh khẩn được xử lý nhanh đúng thẩm quyền, kể cả ngoài giờ |
| 6 | BOD_CFO_CTO | Nhận duyệt khẩn (kênh khẩn trong hệ thống) cho refund khẩn như TKQC bị khóa, lỗi nạp trùng | Không phải chờ quy trình thường khi có rủi ro mất tiền của khách, vẫn qua chữ ký hệ thống |
| 7 | FIN_L2 | Từ chối một lệnh kèm reason code bắt buộc ngay trên mobile | Lệnh sai quay về người đề xuất có căn cứ rõ ràng, lưu vĩnh viễn vào audit log |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — chặn thực thi khi thiếu chữ ký nằm hoàn toàn ở service layer Core; app mobile không được giữ trạng thái "đã duyệt" cục bộ nào ngoài phản hồi API.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS §3.5/3.8). Mọi lệnh duyệt trên mobile hiển thị đúng tiền tệ gốc và snapshot của lệnh — chữ ký không đổi dữ liệu tiền tệ/snapshot | Nếu API duyệt cho phép thay đổi số tiền/tỷ giá snapshot sau khi tạo → chặn; lệnh sai xử lý bằng lệnh mới, không sửa lệnh gốc |
| BR-W02 | Công thức topup `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`, NET/GROSS 2 chiều (CMS §5). Lệnh điều chỉnh phát sinh từ sai khác tính toán hiển thị breakdown theo snapshot; mobile không tự tính lại giá trị cần duyệt | Số hiển thị ở màn duyệt lấy từ Core; nếu mobile render khác Web cho cùng lệnh → lỗi hiển thị, chặn release |
| BR-W03 | **Dual approval 3 giao dịch rủi ro cao** (CMS §3.6; BR-FIN-105): điều chỉnh số dư thủ công, đổi tỷ giá thủ công, hoàn tiền — người đề xuất ≠ người duyệt, ghi danh tính cả hai; Core **chặn thực thi khi thiếu một chữ ký**. Mode SINGLE/DUAL là công tắc toàn hệ thống do SYS_ADMIN bật/tắt: SINGLE — bất kỳ FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần; DUAL — bước 1 bắt buộc FIN_L1 (ACCOUNTANT), bước 2 bắt buộc FIN_L2 (CHIEF_ACCOUNTANT), tuần tự không đảo, không 1 người cả 2 bước | Gọi API duyệt khi thiếu điều kiện → Core trả `DUAL_APPROVAL_REQUIRED`/`APPROVAL_SEQUENCE_INVALID`/`SELF_APPROVAL_DENIED`; mobile hiển thị nguyên văn, không retry ngầm |
| BR-W04 | **MFA TOTP bắt buộc cho mọi chữ ký trên mobile** (BR-FIN-105): mở màn duyệt không tự xác thực — nút duyệt chỉ khả dụng sau khi nhập mã TOTP hợp lệ trong phiên; phiên duyệt hết hạn sau thời gian ngắn (cấu hình), phải nhập lại | Thiếu/không kịp TOTP → API từ chối `MFA_REQUIRED`; mobile không có cơ chế "nhớ máy" bỏ qua MFA cho luồng này |
| BR-W05 | Đổi tỷ giá tay chỉ khi **biên bản đối chiếu với khách ghi nhận sai khác** — bắt buộc đính kèm biên bản; mặc định dùng snapshot tỷ giá hệ thống tại thời điểm tạo lệnh (BR-FIN-105). Màn duyệt mobile hiển thị đính kèm biên bản để đọc trước khi ký | Lệnh đổi tỷ giá thiếu biên bản → Core từ chối tạo/duyệt; mobile hiển thị "thiếu biên bản — xử lý trên Web" |
| BR-W06 | Hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK nguồn nạp trùng tên pháp nhân KYC — cấm hoàn cho bên thứ ba (BR-FIN-402); lệnh hoàn đổi beneficiary bị chặn mặc định + cảnh báo T4 đỏ | Lệnh đổi beneficiary không xuất hiện vào hàng chờ duyệt thường — mobile chỉ thấy trạng thái "bị chặn T4 — BOD xem xét bằng văn bản" |
| BR-W07 | Vượt ngưỡng → duyệt thêm: refund/điều chỉnh >10 triệu VND thuộc thẩm quyền BOD_CFO_CTO (mức mặc định theo DI-001) — Core yêu cầu chữ ký bổ sung của BOD_CFO_CTO trước khi hoàn tất | Mobile của FIN_L2 hiển thị "cần chữ ký BOD_CFO_CTO"; cố duyệt xong ở bước FIN_L2 không có chữ ký BOD → lệnh giữ trạng thái chờ |
| BR-W08 | **Audit log bất biến cho mọi bước** (BR-FIN-105/BR-FIN-501): ai, khi nào, giá trị cũ→mới, reason code — kể cả thao tác duyệt từ mobile đều ghi đúng chuẩn như Web; từ chối bắt buộc nhập lý do | Thao tác duyệt không để lại audit log đủ trường → coi là lỗi nghiêm trọng; Super Admin không sửa/xóa được log |
| BR-W09 | SoD 4 vai dòng tiền (BR-FIN-106): đề xuất (OPS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ; người đề xuất/nhập giao dịch không tự điều tra giao dịch đó (liên hệ AML — BR-FIN-404) | SoD engine chặn submit/gán duyệt khi vai trùng; nỗ lực vi phạm log append-only cho BOD rà định kỳ |
| BR-W10 | **Chế độ online bắt buộc khi ký**: offline mobile chỉ mở được chi tiết lệnh đã cache (chế độ đọc); mọi chữ ký yêu cầu kết nối tới Core — không có hàng đợi chữ ký "gửi sau" | App phát hiện yêu cầu ký khi offline → chặn với thông báo "cần kết nối mạng để duyệt"; không cache mã TOTP trên thiết bị |
| BR-W11 | Đối trừ 3 số (dung sai 0/0,5%·10USD/1%·20USD), chốt & khóa kỳ — điều chỉnh duyệt xong được hạch toán như "Đã điều chỉnh (có phiếu duyệt)" trong đối trừ counterpart (REQ-FIN-004); lệnh điều chỉnh không được dùng để "tự cân số" hai vế khớp (BR-FIN-202 cấm tự cân) | Lệnh điều chỉnh gắn vế khớp được Core từ chối `ADJUSTMENT_NOT_ALLOWED`; mobile hiển thị lý do |
| BR-W12 | AML T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn (REQ-FIN-010); Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10): giao dịch nghi vấn bị hold AML **không vào hàng chờ duyệt thường** — phải qua quy trình điều tra FEAT-MBI-WALLET-005 trước; Portal khách chỉ đọc số dư (REQ-FIN-017) — tenant isolation, không liên quan luồng duyệt nội bộ | Lệnh đang hold bị gọi API duyệt → Core từ chối `AML_HOLD_BLOCK`; mobile hiển thị trạng thái hold |

**Giả định chờ xác nhận:** thời gian hết hạn phiên TOTP trên mobile và thời hạn nhắc duyệt SLA của hàng chờ dùng cấu hình hệ thống (mặc định nhắc 24h — tham chiếu chuẩn REQ-FIN-008), không chốt con số mới trong spec. 11 KXN còn mở (`[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]`) thuộc domain CRM/lifecycle — không tác động rule dual approval, không tự quyết.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Đây là một trong rất ít điểm mobile nội bộ có action ghi — mọi quyền dưới đây vẫn enforce ở Core, mobile chỉ là kênh.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER |
|-----------|--------|--------|-------------|-----------|----------|
| Xem hàng chờ duyệt (lệnh chờ chữ ký của mình) | ✅ (chỉ khi mode SINGLE hoặc là bước 1 DUAL) | ✅ | ✅ | ❌ | ❌ |
| Tạo lệnh điều chỉnh/đổi tỷ giá/hoàn tiền | ❌ (tạo trên Web) | ❌ (tạo trên Web) | ❌ (tạo trên Web) | ❌ | ❌ |
| Duyệt lệnh — SINGLE | ✅ | ✅ | ✅ | ❌ | ❌ |
| Duyệt bước 1 (DUAL) | ✅ (bắt buộc) | ❌ | ❌ | ❌ | ❌ |
| Duyệt bước 2 (DUAL) | ❌ | ✅ (bắt buộc) | ❌ | ❌ | ❌ |
| Duyệt vượt ngưỡng >10 triệu VND (chữ ký bổ sung) | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt kênh khẩn (refund khẩn) | ❌ | ✅ (với CFO đồng duyệt theo luồng khẩn) | ✅ | ❌ | ❌ |
| Từ chối kèm reason code | ✅ (theo mode) | ✅ | ✅ | ❌ | ❌ |
| Đọc biên bản đối chiếu đính kèm | ✅ | ✅ | ✅ | ❌ | ❌ |
| Bật/tắt công tắc SINGLE/DUAL | ❌ | ❌ | ❌ | ✅ (công tắc hệ thống) | ❌ |
| Xem/sửa audit log chữ ký | ❌ (chỉ xem qua truy xuất chuẩn) | ❌ (chỉ xem) | ❌ (chỉ xem; truy xuất ngoài chuẩn cần BOD_CEO duyệt) | ❌ (kể cả Super Admin không sửa/xóa) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **CFO là người đề xuất:** compensating control kiêm nhiệm — giao dịch vượt ngưỡng cao nhất do BOD_CEO duyệt thay (BR-FIN-106); mobile của BOD_CFO_CTO hiển thị lệnh đó ở chế độ chỉ đọc kèm ghi chú "duyệt thay do CEO — xử lý theo luồng Web". 
- **Refund khẩn (TKQC bị khóa, lỗi nạp trùng):** BOD_CFO_CTO duyệt nhanh qua **kênh khẩn trong hệ thống** (mobile có thể nhận push khẩn và ký MFA); chứng từ hợp thức hóa + hậu kiểm trong 24h — mobile hiển thị nhãn "duyệt khẩn — hậu kiểm 24h".
- **Lệnh đổi beneficiary:** bị chặn mặc định (T4 đỏ) — không vào hàng chờ duyệt; chỉ BOD xem xét lại bằng văn bản 3 ngày làm việc, kết quả lưu vĩnh viễn hồ sơ AML; mobile chỉ phản ánh trạng thái.
- **Người duyệt mất mạng ngay khi ký:** chữ ký chỉ có hiệu lực khi Core xác nhận; nếu kết nối đứt giữa chừng, mobile hiển thị "chưa xác nhận — kiểm tra lại hàng chờ" thay vì tự kết luận thành công, chống chữ ký đôi.
- **SYS_ADMIN bật DUAL giữa lúc có lệnh đang SINGLE-pending:** lệnh đang chờ áp mode tại thời điểm tạo; chuyển mode không đổi lại trạng thái lệnh cũ (nguyên tắc công tắc hệ thống — CMS §3.6), mobile hiển thị mode áp dụng của từng lệnh.
- **Lệnh điều chỉnh ảnh hưởng kỳ đã khóa:** kỳ đã khóa chặn sửa chứng từ — lệnh điều chỉnh liên quan kỳ khóa phải kèm phiếu mở kỳ do BOD_CFO_CTO duyệt (lý do, phạm vi, thời hạn); mobile hiển thị phiếu mở kỳ như một phần căn cứ trước khi ký.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh điều chỉnh/đổi tỷ giá/hoàn tiền (Adjustment/Refund Request) — mobile là kênh nhập chữ ký; thực thi và khóa trạng thái nằm ở Core.

**Sơ đồ trạng thái:**
```
[PENDING] ──(duyệt, SINGLE + MFA)──────────────────► [APPROVED] ──(Core thực thi ghi sổ)──► [EXECUTED]
    │  └─(bước 1 DUAL — FIN_L1)► [STEP1_APPROVED] ──(bước 2 — FIN_L2)┘                        │
    │                                              └─(vượt ngưỡng)► [CẦN BOD] ──(BOD + MFA)──┘
    │ (từ chối + reason code bắt buộc)
    ▼
[REJECTED] ──(quay về người đề xuất chỉnh/sửa và nộp lại)──► [PENDING]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Duyệt (SINGLE) | `APPROVED` | FIN_L1 / FIN_L2 / BOD_CFO_CTO — 1 người, ≠ đề xuất | Mode hệ thống = SINGLE; MFA TOTP hợp lệ |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (bắt buộc) | MFA TOTP; ≠ người đề xuất |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (bắt buộc) | ≠ người bước 1; MFA TOTP |
| `APPROVED` (vượt >10 triệu) | Chữ ký bổ sung | `CẦN BOD` → `EXECUTED` | BOD_CFO_CTO | MFA TOTP; mức ngưỡng theo DI-001 |
| `PENDING` / `STEP1_APPROVED` / `CẦN BOD` | Từ chối | `REJECTED` | Người có quyền duyệt bước tương ứng | Reason code + lý do bắt buộc |
| `REJECTED` | Người đề xuất sửa và nộp lại | `PENDING` | Người đề xuất (trên Web) | Lịch sử vòng cũ giữ nguyên — mobile thấy cả hai vòng |
| `APPROVED` | Core thực thi ghi sổ | `EXECUTED` | Hệ thống (Core) | Đủ chữ ký; không hold AML; ghi audit log |

**Quy tắc:**
- Không một người nào giữ được 2 chữ ký trong cùng lệnh (SoD — chặn ở Core; mobile ẩn nút duyệt khi người hiện tại là đề xuất/bước trước).
- `EXECUTED` và `REJECTED` là điểm kết thúc của vòng hiện tại; sửa dữ liệu chỉ qua lệnh mới/reversal có reason code — không sửa lệnh gốc.
- Mỗi chữ ký ghi audit log bất biến kèm kênh thực hiện (WEB/MOBILE) để kiểm toán phân tích kênh duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mobile tiêu thụ/tương tác — nguồn sự thật và DDL thuộc Core (`technical-specs/database-design.md`).*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `AdjustmentRequest` (điều chỉnh/đổi tỷ giá/hoàn) | `type`, `customer_id`, `amount`, `currency`, `source_tx_id` (nạp gốc), `reason`, `attachment` (biên bản), `status` | FK → `wallets.id`, `wallet_transactions.id` | Hàng chờ duyệt của người dùng; hiển thị cả lịch sử vòng |
| `ApprovalSignature` | `request_id`, `step`, `approver_id`, `channel` (WEB/MOBILE), `mfa_verified`, `signed_at` | FK → `adjustment_requests.id` | Bất biến; mobile chỉ đọc, không cache bản sao có thể chỉnh |
| `AuditLog` | `actor`, `old_value`, `new_value`, `reason_code`, `at` | Gắn mọi giao dịch tiền | Hiển thị trích logs trong màn chi tiết lệnh |
| `FxRateSnapshot` | `rate`, `source`, `locked_at` | FK → giao dịch gốc | Màn duyệt hiển thị snapshot gốc + biên bản khi là đổi tỷ giá tay |
| `SystemConfig.approvalMode` | `mode` (SINGLE/DUAL), `updated_by`, `updated_at` | Cấu hình toàn hệ thống | Mobile hiển thị mode áp dụng cho từng lệnh, không cho sửa |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Duyệt mobile MFA đầy đủ | Mode DUAL, lệnh hoàn ở bước 2 chờ FIN_L2 | FIN_L2 mở app, nhập TOTP hợp lệ, bấm duyệt | Core ghi chữ ký (kênh MOBILE, mfa_verified=true); lệnh chuyển `APPROVED` | [ ] |
| SC-002: Chặn tự duyệt | FIN_L1 vừa tạo lệnh điều chỉnh ở mode SINGLE | FIN_L1 mở hàng chờ của mình | Lệnh không hiện nút duyệt; API từ chối `SELF_APPROVAL_DENIED` nếu gọi trực tiếp | [ ] |
| SC-003: Sai thứ tự DUAL | Mode DUAL, lệnh `PENDING` | FIN_L2 cố duyệt bước 1 từ mobile | Core trả `APPROVAL_SEQUENCE_INVALID`; lệnh giữ `PENDING` | [ ] |
| SC-004: Thiếu MFA | Phiên chưa nhập TOTP | Gọi API duyệt | `MFA_REQUIRED`; không có cơ chế nhớ máy bỏ qua | [ ] |
| SC-005: Đổi tỷ giá thiếu biên bản | Lệnh đổi tỷ giá tay không đính biên bản | Mở màn duyệt mobile | Hiển thị "thiếu biên bản — xử lý trên Web"; Core từ chối duyệt | [ ] |
| SC-006: Vượt ngưỡng cần BOD | Lệnh hoàn 25 triệu VND đã đủ 2 chữ ký thường | Kiểm tra trạng thái | Lệnh ở `CẦN BOD`; chỉ BOD_CFO_CTO ký thêm được, sau đó `EXECUTED` | [ ] |
| SC-007: Offline không ký được | App offline với lệnh đã cache | Thử bấm duyệt | Chặn "cần kết nối mạng để duyệt"; không có hàng đợi chữ ký gửi sau | [ ] |
| SC-008: Hold AML chặn duyệt | Lệnh hoàn bị khóa mềm T5 | FIN_L2 mở hàng chờ | Lệnh không xuất hiện trong hàng chờ duyệt thường; trạng thái hold hiển thị ở màn theo dõi | [ ] |
| SC-009: Từ chối bắt buộc lý do | Lệnh điều chỉnh không hợp lệ | Bấm từ chối, để trống lý do | Nút xác nhận bị vô hiệu tới khi nhập reason code; log ghi đủ | [ ] |

> **Liên kết:** SC-001→004, 009 map REQ-FIN-003 (BR-FIN-105); SC-005→006 map BR-FIN-105/402 + ngưỡng DI-001; SC-007 map ràng buộc touchpoint mobile; SC-008 map REQ-FIN-010 (BR-FIN-404).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — AdjustmentRequest, ApprovalSignature, AuditLog (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — approval queue, sign endpoint (MFA), reason-code submit | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — SoD engine, MFA service, audit hash-chain, counterparts | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (approval queue, detail + TOTP flow) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 (§3.6 approvalMode) + policy `aml-kyc-giam-sat-giao-dich.md` | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
