# Tính Năng: Sổ phụ ví TKQC & lệnh giao dịch tiền (tiền giữ hộ)

> **Dựa trên:** REQ-FIN-001 trong `phase1-business/departments/finance/finance.md` (Phần A, B.1)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5/3.8/5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID lấy từ req-registry theo mapping REQ → FEAT của lane (fan-out 3 hệ thống). Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB**; counterpart: SYS-CORE-BACKEND (ledger nguồn sự thật), SYS-MOBILE-INTERNAL (theo dõi/push).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-001 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-001 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (đề xuất lệnh cũng đến từ OPS_AM/OPS_ADS qua luồng cross-module) |
| Độ ưu tiên | Cao (HIGH · GĐ2 — khung tối thiểu phục vụ Financial Hard Stop có từ GĐ1) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có FEAT tiền đối — là tính năng nền móng của MOD-WALLET-RECON (FEAT-ERP-WALLET-002/003/004/005/006/007 đều phụ thuộc nó) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể. Điểm đã đánh dấu trong A7: dữ liệu chi tiêu/đối soát phụ thuộc tiến trình Business Verification API 7 nền tảng (ảnh hưởng đầu vào của tính năng này, xem REQ-FIN-005) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên Web nội bộ BCERP màn hình sổ phụ ví tiền giữ hộ per-khách (nạp, chi tiêu, phí, điều chỉnh, số dư khả dụng) và bộ form quản trị lệnh giao dịch tiền (top-up, refund, điều chỉnh, rút), để mọi biến động tiền của khách đều đi qua lệnh hệ thống có trạng thái — kế toán từ chối đối chiếu mọi lệnh miệng qua Zalo/điện thoại/email. Đây là điều kiện tiên quyết để Financial Hard Stop (FEAT-ERP-WALLET-005) và đối trừ 3 số (FEAT-ERP-WALLET-004) hoạt động đúng.

**Phạm vi:**
- Bao gồm: sổ phụ ví theo khách, tách theo tiền tệ (USD/VND multi-currency, không gộp quy đổi) với `availableBalance`/`frozenBalance`; form tạo/quản lý lệnh giao dịch tiền chứa đủ khách – TKQC – số tiền – tiền tệ – snapshot tỷ giá – căn cứ; theo dõi trạng thái lệnh theo machine-state; hiển thị snapshot `feePercent/vatOnFeePercent/vatOnSpendPercent` tại thời điểm giao dịch; tính toán 2 chiều NET/GROSS theo công thức k; màn đối chiếu sao kê ngân hàng ↔ lệnh nạp của FIN_L1.
- Không bao gồm: thực thi ledger append-only, SoD engine, hard stop tầng API (trách nhiệm SYS-CORE-BACKEND — Web chỉ gọi API và hiển thị đúng trạng thái); đối trừ 3 vế (FEAT-ERP-WALLET-004); dual approval engine (FEAT-ERP-WALLET-003); cảnh báo số dư (FEAT-ERP-WALLET-002); view read-only cho khách trên Portal (REQ-FIN-017 — SYS-PORTAL-WEB, tenant isolation, Web nội bộ không nhúng view này).

---

## 2. Luồng Người Dùng (User Stories)

Phần mô tả sau nằm trên touchpoint Web nội bộ responsive (Next.js) cho nhân viên BC — mọi hành động là form/list/workflow UI gọi API core và hiển thị đúng trạng thái machine-state trả về.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem sổ phụ ví từng khách tách theo USD/VND, số dư khả dụng/bị đóng băng, lịch sử giao dịch append-only | Đối chiếu và ghi nhận tiền về đúng ví, không nhầm lẫn giữa các tiền tệ |
| 2 | FIN_L1 | Đối chiếu sao kê ngân hàng ↔ lệnh nạp trên một màn hình (số tiền, người chuyển trùng tên pháp nhân KYC, mã tham chiếu) | Ghi nhận tiền giữ hộ tăng chỉ khi khớp lệnh, chặn ghi nhận "gần đúng" |
| 3 | OPS_AM/OPS_ADS | Tạo lệnh đề xuất top-up/refund chứa đủ khách, TKQC, số tiền, tiền tệ, căn cứ | Đề xuất nạp đúng luồng hệ thống thay vì nhắn tin — FIN mới chịu đối chiếu |
| 4 | FIN_L2 | Xem toàn bộ lệnh theo trạng thái (PENDING / STEP1_APPROVED / APPROVED / REJECTED / DISPUTED / COMPLETED) và người từng chạm vào lệnh | Kiểm soát dòng tiền và biết ai đề xuất, ai khớp, ai duyệt từng bước |
| 5 | BOD_CFO_CTO | Xem tổng quan số dư ví theo khách, tách bạch tiền giữ hộ (nợ phải trả) khỏi doanh thu phí dịch vụ | Đọc P&L không bị tiền nạp của khách làm méo doanh thu |
| 6 | SYS_ADMIN | Cấu hình snapshot fee % theo hợp đồng (Contract) nhưng không sửa được snapshot đã ghi vào giao dịch cũ | Đổi % cho giao dịch mới mà không ảnh hưởng lịch sử đã chốt |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. BR enforce ở service layer (SYS-CORE-BACKEND); Web bắt buộc phản ánh đúng, không cho thao tác tạo trạng thái ảo phía client.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách, multi-currency USD/VND **không gộp quy đổi** (CMS doc §3.5): mỗi khách một sổ phụ ví riêng với `availableBalance` + `frozenBalance` theo từng `currency`; không gộp chung, không bù trừ chéo ví, không cho số dư âm khi chưa có lệnh điều chỉnh được duyệt | API từ chối ghi nhận; UI hiển thị lỗi "Ví không đủ số dư khả dụng theo đúng tiền tệ" |
| BR-W02 | Tiền khách nạp là **tiền giữ hộ — nợ phải trả (liability)**, KHÔNG tự động tính thành doanh thu; doanh thu chỉ ghi trên phí dịch vụ/markup. CORE cấm cấu hình auto-hạch toán nạp → doanh thu; mọi báo cáo Web tách bạch 2 khoản | Ghi nhận sai bị chặn ở service layer; dashboard không có phương án hiển thị nạp như doanh thu |
| BR-W03 | Mọi top-up/refund/điều chỉnh phải tạo **lệnh trên BCERP** chứa đủ: khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ; lệnh miệng (Zalo/điện thoại/email riêng) không có giá trị đối chiếu | Form tạo lệnh là đầu vào duy nhất; FIN_L1 không thấy lệnh thì từ chối đối chiếu — hệ thống không có đường nhập tay ngoài lệnh |
| BR-W04 | Ledger **append-only**: sửa số dư chỉ qua giao dịch điều chỉnh/reversal có reason code bắt buộc; chặn UPDATE/DELETE ở tầng dữ liệu; mọi bước của lệnh ghi danh tính + timestamp | Thao tác sửa trực tiếp bị DB chặn; Web chỉ thấy nút "tạo giao dịch đảo/thu hồi" kèm reason code |
| BR-W05 | Lưu **snapshot** `feePercent/vatOnFeePercent/vatOnSpendPercent` tại thời điểm giao dịch (CMS doc §3.8) — không tham chiếu sống tới Contract; Contract đổi % sau này không ảnh hưởng giao dịch cũ | UI hiển thị snapshot cố định; không có nút "cập nhật theo hợp đồng hiện tại" trên giao dịch đã ghi |
| BR-W06 | **Công thức topup** k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5): nhập NSQC (net) → grossAmount trừ ví = netAmount × k; nhập Tổng tiền (gross) → netAmount vào TKQC = grossAmount / k. Ví dụ fee=3%, vatOnFee=8%, vatOnSpend=8% → k=1,1124: nhập net 1.000 → ví trừ 1.112,4; nhập gross 1.112,4 → net ra 1.000 | Form tính chiều còn lại tự động; làm tròn/sai khác tính toán làm form báo lỗi và chặn submit |
| BR-W07 | **Vòng lệnh nạp 5 bước** (mỗi bước ghi danh tính + timestamp): (1) khách chuyển khoản theo thông tin lệnh; (2) FIN_L1 đối chiếu sao kê ↔ lệnh — số khớp, người chuyển trùng tên pháp nhân KYC, mã tham chiếu đúng; (3) khớp → ghi nhận ví (tiền giữ hộ tăng), chặn ghi khi chưa có lệnh hoặc số lệch; (4) CORE tạo snapshot tỷ giá tại thời điểm ghi nhận (nguồn ngân hàng quy chuẩn), khóa sau ghi nhận; (5) số dư khả dụng cập nhật, lệnh chuyển "Đã khớp tiền" | Bước nào thiếu điều kiện thì lệnh đứng nguyên trạng thái cũ; Web hiển thị lý do dừng tại bước cụ thể |
| BR-W08 | **SoD 4 vai dòng tiền**: đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ; một người không giữ ≥2 vai trong cùng chuỗi giao dịch | SoD engine chặn submit/gán duyệt khi vai trùng; log vi phạm append-only cho CFO (BOD_CFO_CTO) rà định kỳ |
| BR-W09 | TK client-owned (khách tự nạp trực tiếp nền tảng) không phát sinh lệnh nạp của BC — chỉ ghi nhận đối soát; TK Internal-Sandbox không gắn khách, không thuộc ví khách | Form tạo lệnh nạp ẩn/zone các loại TK này; nếu cố tạo thì API từ chối kèm phân loại TK |
| BR-W10 | Khẩn ngoài giờ vẫn phải tạo lệnh trên hệ thống **trước** khi xử lý — approval không được bỏ qua; refund từ platform (TKQC die còn dư): FIN_L1 khớp tiền hoàn về theo giao dịch gốc, không hoàn cho khách trước khi có đề xuất AM + duyệt FIN_L2 | Web luôn cho phép tạo lệnh (kể cả ngoài giờ) nhưng không có đường "xử lý trước, lập lệnh sau"; lệnh khẩn được gắn nhãn để hậu kiểm |
| BR-W11 | Portal chỉ đọc số dư ví (REQ-FIN-017) với tenant isolation 2 lớp (RLS DB + filter API) — Web nội bộ không được tái sử dụng view Portal cho khách, và dữ liệu ví khách này không hiển thị lẫn vào ngữ cảnh tenant khác | UI nội bộ luôn kèm ngữ cảnh khách rõ ràng; không tồn tại route nội bộ trả dữ liệu ví đa khách không lọc tenant |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. SYS-CORE-BACKEND enforce lại toàn bộ ở service layer.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_AM/OPS_ADS | SYS_ADMIN |
|-----------|--------|--------|-------------|----------------|-----------|
| Xem sổ phụ ví mọi khách | ✅ | ✅ | ✅ | ❌ (chỉ ví khách mình phụ trách qua dashboard ops) | ❌ (chỉ khi được ủy quyền cấu hình, không xem số liệu mặc định) |
| Xem lịch sử lệnh + audit từng bước | ✅ | ✅ | ✅ | ✅ (lệnh của mình) | ❌ |
| Tạo lệnh đề xuất top-up/refund | ✅ | ✅ (qua lệnh riêng, không tự duyệt lệnh của mình) | ❌ | ✅ (đề xuất) | ❌ |
| Đối chiếu sao kê ↔ lệnh nạp (khớp tiền) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt lệnh (theo FEAT-ERP-WALLET-003) | ❌ (khớp tiền ≠ duyệt chi) | ✅ | ✅ (vượt ngưỡng) | ❌ | ❌ |
| Sửa/xóa dòng sổ phụ | ❌ (chỉ reversal + reason code) | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin không sửa dữ liệu giao dịch tiền) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Tiền về không khớp lệnh nào → treo trạng thái "chờ đối chiếu"; FIN_L1 phối hợp AM xác định khách; cấm ghi vào ví "gần đúng" — Web có hàng đợi "sao kê chưa khớp lệnh" riêng để xử lý.
- Sai khác giữa biên bản đối chiếu với khách và số đã ghi → xử lý qua điều chỉnh dual approval (FEAT-ERP-WALLET-003), không sửa lệnh gốc.
- Khách có nhiều ví theo nhiều tiền tệ và các TKQC khác nhau gắn trên cùng ví → lệnh bắt buộc chọn đúng cặp (TKQC, tiền tệ); hệ thống không tự quy đổi USD↔VND để "cho đủ".
- Contract bị TERMINATED/all toán (đổi serviceType, hoàn số dư trong 15 ngày làm việc) → lệnh mới không tạo thêm trên Contract cũ; ví vẫn giữ số dư đến khi tất toán xong theo luồng hoàn tiền.
- Nhân viên SOĐ ví (OPS_ADS) nghỉ việc/chuyển khách → cần chuyển ownership ví sang người khác mà không làm mất lịch sử lệnh đã tạo.
- Nền tảng hoàn phí/thu.extra sau nhiều tháng (retro adjustment) → ghi nhận qua lệnh điều chỉnh gắn giao dịch gốc, không đè dòng cũ.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính của tính năng này là Lệnh giao dịch tiền — Web hiển thị đúng machine-state do CORE trả về; không tự suy diễn trạng thái phía client.*

**Entity:** Lệnh giao dịch tiền (Recharge/Withdraw/Adjustment — pattern RechargeRequest CMS doc §3.6)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING] ──(duyệt 1 lần, SINGLE)──► [APPROVED] ──(thực thi + khớp tiền)──► [COMPLETED]
                          │                                  │
                          │ (DUAL: duyệt tuần tự)            │ (từ chối)
                          ▼                                  ▼
                  [STEP1_APPROVED] ──(duyệt bước 2)──►   [REJECTED] ──(khách khiếu nại)──► [DISPUTED]
                                                                                                     │ (quay lại review)
                                                                                                     ▼
                                                                                                [PENDING]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING` | Người tạo (OPS_AM/OPS_ADS/FIN_L1) | Đủ khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ |
| `PENDING` | Duyệt (chế độ SINGLE) | `APPROVED` | FIN_L2 hoặc BOD_CFO_CTO (1 trong các vai duyệt) | Người duyệt ≠ người đề xuất; chế độ hệ thống = SINGLE |
| `PENDING` | Duyệt bước 1 (chế độ DUAL) | `STEP1_APPROVED` | FIN_L1 (map ACCOUNTANT) | DUAL đang bật; đúng cấp bậc bước 1 |
| `STEP1_APPROVED` | Duyệt bước 2 (chế độ DUAL) | `APPROVED` | FIN_L2 (map CHIEF_ACCOUNTANT) | Đúng thứ tự tuần tự; không cho 1 người duyệt cả 2 bước |
| `PENDING`/`STEP1_APPROVED` | Từ chối | `REJECTED` | Vai duyệt tương ứng | Phải nhập lý do từ chối |
| `REJECTED` | Khiếu nại | `DISPUTED` | Khách qua AM (đề xuất), FIN_L1 ghi nhận | Có nội dung khiếu nại; quay lại review |
| `APPROVED` | Thực thi + khớp tiền | `COMPLETED` | FIN_L1 | Tiền về + khớp số lệnh; snapshot tỷ giá đã khóa; ghi evidence |
| `COMPLETED` | Thu hồi/sửa số liệu | Bất biến | Không ai | Chỉ tạo giao dịch reversal có reason code |

**Quy tắc:**
- Chế độ SINGLE/DUAL là **1 công tắc toàn hệ thống** do ADMIN (SYS_ADMIN/BOD) bật/tắt thủ công khi phòng kế toán đủ người — không theo ngưỡng số tiền, không tự động.
- `COMPLETED` là trạng thái kết thúc — mọi chỉnh sửa về sau là reversal, không quay trạng thái.
- Web hiển thị trạng thái nguyên văn từ API; không có nút hành động nào hiển thị khi người dùng không đủ vai thực hiện chuyển đổi đó.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| Wallet | `customerId`, `currency`, `availableBalance`, `frozenBalance` | FK → Customer; unique (customerId, currency) | Multi-currency không gộp; ledger append-only bên dưới |
| WalletTransaction (lệnh) | `type` (TOPUP/REFUND/ADJUST/WITHDRAW), `amount`, `currency`, `fxSnapshotId`, `basis`, `status`, `createdBy` | FK → Wallet, AdAccount, Contract | Snapshot fee % chôn vào giao dịch |
| FeeSnapshot | `feePercent`, `vatOnFeePercent`, `vatOnSpendPercent`, `effectiveAt` | FK → WalletTransaction (1-1) | Không tham chiếu sống tới Contract |
| BankStatementLine | `bankRef`, `amount`, `payerName`, `matchedTransactionId` | FK → WalletTransaction (nullable) | Hàng đợi "chờ đối chiếu" khi null |
| AuditEntry | `actor`, `timestamp`, `oldValue`, `newValue`, `reasonCode` | FK → mọi entity tiền | Append-only + hash-chain (REQ-FIN-012) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tạo lệnh nạp đủ điều kiện | OPS_ADS đăng nhập Web nội bộ | Tạo lệnh top-up đủ khách/TKQC/số tiền/tiền tệ/căn cứ | Lệnh ở `PENDING`, ghi danh tính + timestamp; không có dòng mới trong ví | [ ] |
| SC-002: Đối chiếu khớp | Lệnh `PENDING`, sao kê có dòng trùng số + trùng tên pháp nhân KYC | FIN_L1 bấm khớp | Ví tăng (tiền giữ hộ), snapshot tỷ giá khóa, lệnh `COMPLETED` "Đã khớp tiền" | [ ] |
| SC-003: Sao kê lệch lệnh | Sao kê có dòng không khớp lệnh nào | FIN_L1 thử ghi vào ví "gần đúng" | Hệ thống chặn; dòng treo ở hàng đợi "chờ đối chiếu" | [ ] |
| SC-004: Không gộp tiền tệ | Ví khách có USD 0 và VND 10.000.000 | Tạo lệnh top-up TKQC USD quá số dư USD | Từ chối với thông báo thiếu số dư theo đúng tiền tệ; không tự quy đổi | [ ] |
| SC-005: NET/GROSS 2 chiều | Contract fee=3%, vatOnFee=8%, vatOnSpend=8% | Nhập net 1.000 rồi nhập gross 1.112,4 | Hai chiều cùng ra k=1,1124; ví trừ 1.112,4 ↔ net vào TK 1.000 khớp ngược | [ ] |
| SC-006: Snapshot bất biến | Giao dịch đã COMPLETED với snapshot cũ | SYS_ADMIN đổi % trên Contract | Giao dịch cũ giữ nguyên snapshot; chỉ giao dịch mới dùng % mới | [ ] |

> **Liên kết:** Mỗi scenario map tối thiểu 1 lần vào REQ-FIN-001 (SC-001→BR-W03, SC-002→BR-W07, SC-003→BR-W07, SC-004→BR-W01, SC-005→BR-W06, SC-006→BR-W05) trong Mục 2/3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (mục Wallet & Ledger) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (wallet, transactions, statements) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-001: CORE-BACKEND, MOBILE-INTERNAL) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (sổ phụ, tạo lệnh, đối chiếu sao kê) |
| Nguồn domain chi tiết | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5/3.6/3.8, §5) |
