# Tính Năng: Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ)

> **Dựa trên:** REQ-FIN-001 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5 Wallet, §3.6 RechargeRequest, §3.8 TopupTransaction, §5 công thức k)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-001-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-FIN-001 (REQ xuất hiện ở 3 systems). Counterparts: SYS-CORE-BACKEND (ledger nguồn sự thật — mọi rule enforce ở service layer), SYS-BCERP-WEB (kênh tạo/duyệt lệnh chính). Touchpoint Mobile nội bộ là **app React Native offline-capable** dành cho staff cần di động: bản spec này mô tả trải nghiệm **theo dõi sổ phụ ví, lệnh giao dịch tiền và số dư tiền giữ hộ khi di chuyển**, với cơ chế cache offline — đọc được số liệu đã sync khi mất mạng, mọi dữ liệu luôn kèm nhãn thời điểm sync.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-001 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-001 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2 — khung tối thiểu phục vụ Financial Hard Stop có từ GĐ1) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (ledger ví trên Core phải sẵn sàng — Mobile chỉ đọc dữ liệu do Core cấp qua API) |
| Ghi chú Expert (A7) | Dept doc finance.md có cấu trúc A7 nhưng phần review chưa thực hiện chính thức; điểm phối hợp liên phòng đã ghi nhận: gate Hard Stop + KYC do OPS vận hành, FIN nắm quyền xác nhận — Mobile chỉ phản ánh trạng thái, không nắm action duyệt nào |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa sổ phụ ví tiền giữ hộ per-khách lên Mobile nội bộ (React Native, offline-capable) để FIN_L1, FIN_L2 và BOD_CFO_CTO theo dõi mọi lệnh giao dịch tiền (nạp, chi tiêu, phí, điều chỉnh, hoàn) và số dư ví theo khách/tiền tệ ngay cả khi đang di chuyển hoặc mất mạng. App mobile luôn phản ánh đúng nguyên tắc bất di bất dịch của module: tiền khách nạp là **tiền giữ hộ — nợ phải trả**, không phải doanh thu — mọi màn hình hiển thị tách bạch hai đại lượng này để người xem không bị đánh lừa bởi tổng số dư.

**Phạm vi:**
- Bao gồm: màn danh sách ví theo khách với số dư khả dụng/bị khóa tách theo tiền tệ (USD/VND không gộp quy đổi); sổ phụ giao dịch chi tiết từng lệnh kèm trạng thái theo dõi đến hoàn tất; màn hình chi tiết lệnh nạp theo vòng 5 bước (ai đề xuất, ai đối chiếu, snapshot tỷ giá, căn cứ); push/thông báo trong app khi lệnh chuyển trạng thái; chế độ offline — cache danh sách ví và lệnh lần sync gần nhất, hiển thị nhãn "cập nhật lúc HH:MM" và cấm thao tác ghi khi offline; tra cứu theo khách, tiền tệ, loại giao dịch, trạng thái.
- Không bao gồm: tạo lệnh nạp mới và duyệt lệnh nạp (kênh thao tác chính thuộc SYS-BCERP-WEB; Core enforce); đối chiếu sao kê ngân hàng ↔ lệnh (FIN_L1 làm trên Web — màn chuyên dụng); ghi nhận ví và snapshot tỷ giá (SYS-CORE-BACKEND thực thi); dual approval điều chỉnh số dư/đổi tỷ giá/hoàn tiền (FEAT-MBI-WALLET-003); cảnh báo số dư đủ chi và SLA đỏ (FEAT-MBI-WALLET-002); xác nhận "đã khớp tiền" mở Financial Hard Stop (FEAT-MBI-WALLET-004 — mobile chỉ alert, tuyệt đối không có nút xác nhận); xem số dư cho khách hàng (SYS-PORTAL-WEB/SYS-MOBILE-PORTAL — khách không dùng app nội bộ này).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Mở app xem danh sách lệnh nạp đang chờ đối chiếu với số tiền, tiền tệ và khách của từng lệnh | Khi đang ngoài vị trí bàn làm việc vẫn biết có khoản tiền khách nào về cần xử lý ngay khi quay lại |
| 2 | FIN_L1 | Xem chi tiết vòng đời 5 bước của từng lệnh nạp kèm danh tính và timestamp từng bước | Trả lời được câu hỏi "lệnh này đang kẹt ở đâu, ai giữ" ngay trên điện thoại |
| 3 | FIN_L2 | Xem số dư tiền giữ hộ toàn bộ khách theo từng tiền tệ USD/VND tách bạch | Nắm dòng tiền nợ phải trả thật (không nhầm doanh thu) để chuẩn bị kế hoạch nạp nền tảng |
| 4 | FIN_L2 | Nhận thông báo trong app khi một lệnh nạp chuyển sang "Đã khớp tiền" hoặc bị từ chối | Theo dõi tiến độ cấp phát TKQC của OPS mà không phải hỏi từng đầu việc |
| 5 | BOD_CFO_CTO | Xem tổng quan tiền giữ hộ theo khách/tiền tệ kèm nhãn thời điểm sync trên điện thoại | Ra quyết định dòng tiền ở bất kỳ đâu mà vẫn biết độ tươi của số liệu |
| 6 | FIN_L1 | Mở app khi không có mạng và vẫn xem được danh sách ví/lệnh đã sync kèm cảnh báo "dữ liệu offline" | Tra cứu được căn cứ tại chỗ gặp khách/nhà cung cấp dù sóng yếu, không quyết định trên số cũ vì app đã gắn nhãn |
| 7 | FIN_L1 | Tra cứu nhanh một giao dịch theo mã tham chiếu hoặc tên khách trên ô tìm kiếm | Đối đáp tức thì khi AM/khách hỏi "tiền nạp sáng nay đã ghi nhận chưa" |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng: business rule được enforce ở service layer của SYS-CORE-BACKEND, app mobile chỉ hiển thị và không được tự tính lại số dư/số tiền; mọi con số trên mobile lấy từ API Core.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency: mỗi khách có ví tách theo `currency` (USD/VND **không gộp quy đổi**), tách `availableBalance`/`frozenBalance`; không gộp chung, không bù trừ chéo ví, không cho số dư âm khi chưa có lệnh điều chỉnh được duyệt (CMS §3.5; BR-FIN-101). Mobile hiển thị song song từng tiền tệ, không có màn hình "tổng quy đổi" tự tính | App chỉ render dữ liệu API trả về; nếu API từ chối (`WALLET_CROSS_CURRENCY_DENIED`) hiển thị thông báo nguyên văn, không tự quy đổi che lỗi |
| BR-W02 | Tiền khách nạp là **tiền giữ hộ — nợ phải trả**, không phải doanh thu; doanh thu chỉ ghi trên phí dịch vụ/markup. Mọi màn hình mobile (danh sách ví, tổng quan BOD, chi tiết lệnh) phải hiển thị tiền giữ hộ **tách bạch** khỏi doanh thu dịch vụ, có nhãn "Tiền giữ hộ (nợ phải trả)" | Màn hình nào gộp tiền giữ hộ vào chỉ số doanh thu bị coi là bug nghiệp vụ; QA chặn release |
| BR-W03 | Mọi top-up/refund/điều chỉnh phải qua **lệnh hệ thống** chứa đủ: khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ; lệnh miệng qua Zalo/điện thoại/email riêng không có giá trị đối chiếu (BR-FIN-102). Mobile không cung cấp bất kỳ kênh nhập số tiền ngoài lệnh nào (kể cả ghi chú/notes tự do dạng số) | App không có trường nhập số tiền tự do; mọi giao dịch hiển thị phải truy vết được về `RechargeRequest`/`WalletTransaction` trên Core |
| BR-W04 | Vòng lệnh nạp chuẩn 5 bước, mỗi bước ghi danh tính + timestamp: (1) khách chuyển khoản theo lệnh; (2) FIN_L1 đối chiếu sao kê — số khớp, tên trùng pháp nhân KYC, mã tham chiếu đúng; (3) khớp → ghi nhận ví (tiền giữ hộ tăng); (4) Core tạo snapshot tỷ giá tại thời điểm ghi nhận, khóa sau ghi nhận; (5) số dư cập nhật, lệnh chuyển "Đã khớp tiền" (BR-FIN-103). Mobile hiển thị đủ 5 bước + trạng thái hiện tại của từng bước | Chi tiết lệnh thiếu bước/timestamp nào đó → coi như lỗi dữ liệu, hiển thị trạng thái "dữ liệu chưa đầy đủ" và log; không bịa mặc định |
| BR-W05 | Approval mode lệnh nạp là **1 công tắc toàn hệ thống** SINGLE/DUAL do SYS_ADMIN bật/tắt thủ công khi phòng kế toán đủ người (CMS §3.6). SINGLE: FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần; DUAL: bước 1 bắt buộc FIN_L1, bước 2 bắt buộc FIN_L2, tuần tự không đảo. Mobile **chỉ hiển thị** mode hiện hành và người đã duyệt từng bước — không cho bấm duyệt lệnh nạp trên mobile | Nếu phát hiện luồng duyệt nạp khả dụng trên mobile → vi phạm biên touchpoint (duyệt nạp thuộc WEB); chặn ở build, log vi phạm |
| BR-W06 | Công thức top-up Wallet → AdAccount: `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`; NET → `grossAmount = netAmount × k`; GROSS → `netAmount = grossAmount / k`; snapshot fee % chốt tại thời điểm giao dịch, không tham chiếu sống tới Contract (CMS §5). Mobile hiển thị bảng breakdown phí (net, phí, VAT/phí, VAT/chi tiêu, gross) **lấy từ snapshot đã lưu** của Core | App không tự tính lại k từ fee % hiện tại của Contract — hiển thị sai snapshot bị coi là lỗi; chỉ render số liệu giao dịch cũ |
| BR-W07 | Ledger append-only: sửa số dư chỉ qua điều chỉnh/reversal có reason code; Super Admin cũng không sửa được giao dịch tiền (BR-FIN-101/501). Mobile hiển thị lịch sử điều chỉnh dạng dòng thời gian bất biến, không có action sửa/xóa bất kỳ vai nào | Không tồn tại nút sửa/xóa trên app; nếu API trả bản ghi đã reversal thì hiển thị cả dòng gốc + dòng đảo with reason code |
| BR-W08 | SoD 4 vai dòng tiền: đề xuất (OPS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ (BR-FIN-106). Mobile hiển thị danh tính từng vai trong chuỗi giao dịch để người xem tự kiểm tra tuân thủ | Màn chi tiết thiếu danh tính 4 vai → báo lỗi hiển thị; người dùng báo cáo bất thường qua luồng phản hồi trong app |
| BR-W09 | Offline-capable: app cache danh sách ví/lệnh đã sync; khi offline chỉ cho **đọc**, cấm mọi thao tác ghi; dữ liệu offline bắt buộc gắn nhãn "cập nhật lúc HH:MM — dữ liệu offline" trên mỗi màn | Nếu app cho phép submit bất kỳ action nào khi offline (kể cả "hàng đợi gửi sau") đối với dữ liệu tiền → chặn ở tầng UI + test bắt buộc |
| BR-W10 | Đối trừ 3 số (sổ ví – platform – ngân hàng) với dung sai 0/0,5%·10USD/1%·20USD và chốt & khóa kỳ thuộc counterpart Core/Web (REQ-FIN-004); mobile chỉ đọc được **trạng thái đối soát** từng lệnh (Chưa đối soát/Đã đối soát/Chênh lệch/Đã điều chỉnh) | Mobile không cung cấp thao tác xử lý ticket discrepancy; chỉ hiển thị trạng thái + hướng dẫn "xử lý trên Web nội bộ" |
| BR-W11 | AML monitoring T1–T6 + UBO ≥25% và quy tắc hoàn tiền đúng nguồn chạy trên Core (REQ-FIN-010 — FEAT-MBI-WALLET-005); Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10). Mobile hiển thị flag "lệnh đang hold AML" nếu lệnh bị khóa mềm | Lệnh bị hold vẫn hiển thị đúng trạng thái (không biến mất khỏi danh sách); mobile không cho bỏ hold |
| BR-W12 | Portal khách chỉ đọc số dư ví qua view tenant riêng (REQ-FIN-017) — **tenant isolation 2 lớp**; khách hàng KHÔNG dùng app nội bộ này. Dữ liệu tài chính khách nào chỉ được hiển thị cho vai nội bộ được phân quyền | Mọi API mobile phải ép phân quyền theo vai nội bộ; phát hiện lộ dữ liệu chéo khách/tenant → sự cố bảo mật, ghi meta-log |

**Giả định chờ xác nhận:** mốc chốt kỳ "ngày 3 tháng kế tiếp" vẫn `[CẦN CHỐT SỐ]` (BR-FIN-107/204) — mobile chỉ hiển thị trạng thái kỳ, không phụ thuộc con số này. 11 KXN còn mở (KXN-6/7/9/15–22) thuộc domain CRM/lifecycle — `[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]` không tác động business rule ví của spec này, không tự quyết bổ sung.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. App nội bộ không có vai CUSTOMER — khách xem ví qua Portal/M-PORTAL counterparts; cột CUSTOMER đặt để chốt biên.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER |
|-----------|--------|--------|-------------|-----------|----------|
| Xem danh sách ví + số dư (khách được gán) | ✅ | ✅ (toàn bộ khách) | ✅ (tổng hợp quản trị) | ❌ (không xem dữ liệu nghiệp vụ) | ❌ (chỉ Portal/M-PORTAL read-only) |
| Xem sổ phụ giao dịch chi tiết từng lệnh | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem vòng đời 5 bước lệnh nạp + danh tính từng bước | ✅ | ✅ | ✅ | ❌ (chỉ qua audit log kỹ thuật) | ❌ |
| Tạo lệnh nạp / đối chiếu sao kê / ghi nhận ví | ❌ (thuộc Web — màn chuyên dụng) | ❌ | ❌ | ❌ | ❌ |
| Duyệt lệnh nạp (SINGLE/DUAL) trên mobile | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem breakdown phí theo công thức k + snapshot | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem trạng thái đối soát từng lệnh | ✅ | ✅ | ✅ | ❌ | ❌ |
| Sửa/xóa dòng ledger | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin — append-only) | ❌ |
| Cấu hình offline cache / đăng ký thiết bị | ✅ (thiết bị của mình) | ✅ (thiết bị của mình) | ✅ (thiết bị của mình) | ✅ (policy bảo mật toàn app) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Mất mạng giữa giờ làm:** app chuyển chế độ offline, mọi màn hiển thị nhãn thời điểm sync; danh sách lệnh chờ đối chiếu được cache theo khách FIN_L1 được gán để vẫn tra cứu được; khi có mạng lại, app tự đồng bộ và làm mới nhãn.
- **Lệnh bị reversal sau khi đã hiển thị:** dòng thời gian giữ nguyên dòng gốc và hiển thị thêm dòng đảo (reversal) kèm reason code — người xem luôn thấy lịch sử thật, không có cơ chế "xóa khỏi màn hình".
- **Khách nhiều pháp nhân (tập đoàn):** ví gắn theo pháp nhân đã KYC; mỗi pháp nhân là một đơn vị tenant riêng — FIN_L1 thấy các ví được gán, FIN_L2/BOD_CFO_CTO thấy toàn bộ theo nhóm khách.
- **TK client-owned (khách tự nạp trực tiếp nền tảng):** không phát sinh lệnh nạp của BC — màn ví chỉ hiển thị nhãn "chỉ đối soát"; TK Internal-Sandbox không gắn khách, không xuất hiện trong danh sách ví khách.
- **Contract đổi fee % sau khi đã có giao dịch:** breakdown phí của giao dịch cũ vẫn hiển thị theo snapshot tại thời điểm giao dịch — app hiển thị thêm ghi chú "áp dụng fee % tại thời điểm giao dịch" để tránh hiểu nhầm với fee % hiện hành.
- **Thiết bị bị mất:** thiết bị đăng ký bị vô hiệu hóa bởi chính người dùng hoặc SYS_ADMIN qua policy bảo mật; cache local bị xóa ở lần đăng nhập kế tiếp, bắt buộc đăng nhập lại + MFA theo chuẩn app nội bộ.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh nạp (RechargeRequest) — app mobile là **bề mặt hiển thị chỉ-đọc** của state machine này; mọi chuyển trạng thái thực thi trên Core, mobile nhận qua đồng bộ.

**Sơ đồ trạng thái:**
```
[PENDING] ──(duyệt, SINGLE)────────────────► [APPROVED] ──(đối chiếu sao kê khớp)──► [ĐÃ KHỚP TIỀN]
    │  └─(duyệt bước 1, DUAL — FIN_L1)► [STEP1_APPROVED] ──(duyệt bước 2 — FIN_L2)┘        │
    │ (reject + lý do)                                                                     │
    ▼                                                                                      ▼
[REJECTED] ──(khách khiếu nại)──► [DISPUTED] ──(quay lại review)──► [PENDING]    [KHỚP TIỀN BỊ THU HỒI]
```

**Bảng chuyển đổi (mobile hiển thị đúng từng trạng thái và người thực hiện):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép (thực thi trên Core/Web) | Mobile hiển thị |
|---------------------|-----------|----------------|----------------------------------------|-----------------|
| `PENDING` | Duyệt (SINGLE) | `APPROVED` | FIN_L1 / FIN_L2 / BOD_CFO_CTO — 1 người | Nhãn trạng thái + người duyệt + timestamp |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (bắt buộc) | Hiển thị "chờ bước 2 — FIN_L2" |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (bắt buộc, ≠ người bước 1) | Hiển thị đủ hai chữ ký |
| `PENDING` / `STEP1_APPROVED` | Từ chối | `REJECTED` | Theo mode hiện hành | Hiển thị lý do từ chối |
| `REJECTED` | Khách khiếu nại | `DISPUTED` | CUSTOMER (qua AM) → FIN_L2 xem lại | Hiển thị "đang khiếu nại" |
| `APPROVED` | Đối chiếu sao kê khớp | `ĐÃ KHỚP TIỀN` | FIN_L1 trên Web (MFA) | Push thông báo — không có nút hành động nào trên mobile |
| `ĐÃ KHỚP TIỀN` | Thu hồi xác nhận sai | `KHỚP TIỀN BỊ THU HỒI` | FIN_L1 | Push alert + TKQC chuyển "Tạm dừng chi tiêu" (BR-FIN-302) |

**Quy tắc:**
- Mobile không phải là tác nhân của bất kỳ chuyển trạng thái nào trong bảng trên — mọi action bị chặn ở build; chỉ đọc và nhận thông báo.
- Không được duyệt cả 2 bước DUAL bằng một người (thực thi ở Core); mobile hiển thị rõ hai chữ ký để phát hiện bất thường bằng mắt.
- Mọi chuyển trạng thái ghi audit log bất biến trên Core — mobile hiển thị trích logs, không lưu bản sao dữ liệu tiền ngoài cache đọc.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mà app mobile tiêu thụ — nguồn sự thật và DDL đầy đủ thuộc counterpart Core (`technical-specs/database-design.md`); mobile chỉ giữ cache đọc.*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `Wallet` | `customer_id`, `currency`, `available_balance`, `frozen_balance` | FK → `customers.id` | Hiển thị tách theo tiền tệ, kèm nhãn "tiền giữ hộ — nợ phải trả" |
| `WalletTransaction` | `type`, `amount`, `currency`, `balance_after`, `reason_code`, `created_at` | FK → `wallets.id` | Dòng thời gian append-only; reversal hiển thị kèm dòng gốc |
| `RechargeRequest` | `status`, `amount`, `currency`, `step1_by`, `step2_by`, `evidence`, timestamps | FK → `customers.id`, `ad_accounts.id` | Màn chi tiết 5 bước; chỉ đọc |
| `TopupTransaction` | `input_mode` (NET/GROSS), `net_amount`, `fee_amount`, `vat_on_fee_amount`, `vat_on_spend_amount`, `gross_amount`, snapshots fee % | FK → `wallets.id`, `ad_accounts.id` | Breakdown phí hiển thị từ snapshot |
| `FxRateSnapshot` | `rate`, `source`, `locked_at` | FK → `wallet_transactions.id` | Hiển thị "tỷ giá chốt lúc HH:MM — nguồn ngân hàng quy chuẩn" |
| `OfflineCache` (client-side) | `synced_at`, `payload`, `device_id` | Gắn thiết bị đăng ký | Chỉ đọc khi offline; xóa khi vô hiệu hóa thiết bị |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xem ví tách tiền tệ | Khách A có ví USD và ví VND | Mở màn danh sách ví của khách A | Hai dòng số dư tách bạch USD/VND, kèm nhãn "tiền giữ hộ — nợ phải trả", không có cột quy đổi gộp | [ ] |
| SC-002: Chi tiết 5 bước lệnh | Lệnh nạp đã "Đã khớp tiền" | Mở chi tiết lệnh | Hiển thị đủ 5 bước với danh tính + timestamp từng bước và snapshot tỷ giá khóa | [ ] |
| SC-003: Breakdown công thức k | Giao dịch topup fee 3%, vatOnFee 8%, vatOnSpend 8% | Xem breakdown phí giao dịch | Hiển thị k = 1,1124 với các thành phần theo snapshot, đúng số đã lưu trên Core | [ ] |
| SC-004: Offline chỉ đọc | App đã sync; tắt kết nối mạng | Mở danh sách ví và thử thao tác | Dữ liệu hiển thị kèm nhãn "cập nhật lúc HH:MM — offline"; mọi nút ghi bị ẩn/vô hiệu | [ ] |
| SC-005: Không có nút duyệt trên mobile | Mode DUAL, lệnh `PENDING` | Đăng nhập FIN_L1, mở lệnh | Màn chỉ hiển thị "chờ bước 2 — FIN_L2 xử lý trên Web", không có nút duyệt | [ ] |
| SC-006: Thông báo chuyển trạng thái | Lệnh vừa được FIN_L1 xác nhận khớp tiền trên Web | App FIN_L2 online | Nhận thông báo trong app ≤ 1 phút từ lúc Core ghi nhận; mở được chi tiết lệnh | [ ] |
| SC-007: Lệnh hold AML hiển thị đúng | Lệnh bị khóa mềm AML (T2 đỏ) | Xem danh sách lệnh | Lệnh hiển thị trạng thái "đang hold AML", không biến mất, không có action bỏ hold | [ ] |
| SC-008: Vô hiệu hóa thiết bị mất | Thiết bị đã đăng ký cache dữ liệu | SYS_ADMIN vô hiệu hóa thiết bị; người dùng đăng nhập thiết bị khác | Thiết bị cũ không đồng bộ được nữa; cache bị xóa ở lần đăng nhập kế tiếp | [ ] |

> **Liên kết:** SC-001→003, 005, 007 map REQ-FIN-001 (A3 finance.md); SC-004, 008 map ràng buộc touchpoint mobile offline (A0); SC-006 map BR-FIN-103.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — Wallet, WalletTransaction, RechargeRequest, snapshot (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — wallet read API cho mobile, push notification service, offline sync | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — biên Core/Web/Mobile, tenant isolation, chuẩn push | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (danh sách ví, chi tiết lệnh, offline states) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 (§3.5/3.6/3.8/§5) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
