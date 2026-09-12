# Tính Năng: Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền

> **Dựa trên:** REQ-FIN-003 trong `phase1-business/departments/finance/finance.md` (Phần A, B.1 — BR-FIN-105/106)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.6)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-003-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-FIN-003 (fan-out 3 hệ thống); counterpart: SYS-CORE-BACKEND (engine chặn thiếu chữ ký), SYS-MOBILE-INTERNAL (FIN_L2/BOD duyệt khi di chuyển, MFA bắt buộc).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-003 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-003 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-WALLET-001 (sổ phụ ví + lệnh giao dịch — dual approval là lớp duyệt bọc ngoài lệnh); FEAT-ERP-WALLET-006 (hoàn tiền phải qua kiểm tra AML đúng nguồn) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể. Ngưỡng hoàn tiền/điều chỉnh >10 triệu VND thuộc thẩm quyền BOD_CFO_CTO đang dùng mức đề xuất `[CẦN CHỐT SỐ — chờ phê duyệt chính sách hạn mức chi]`, không tự quyết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tạo trên Web nội bộ luồng phê duyệt kép (dual approval) bắt buộc cho 3 nhóm giao dịch rủi ro cao nhất trên ví TKQC — điều chỉnh số dư thủ công, đổi tỷ giá thủ công, hoàn tiền cho khách — với nguyên tắc người đề xuất ≠ người duyệt, chế độ SINGLE/DUAL là công tắc toàn hệ thống, chặn thực thi khi thiếu một trong hai chữ ký, nhằm chống gian lận nội bộ trên dòng tiền giữ hộ.

**Phạm vi:**
- Bao gồm: form tạo đề xuất 3 loại giao dịch rủi ro cao (kèm căn cứ/biên bản bắt buộc); hàng chờ duyệt cho FIN_L2 và BOD_CFO_CTO theo ngưỡng; hiển thị trạng thái duyệt theo machine-state SINGLE/DUAL; ghi danh tính cả 2 chữ ký + audit log; ràng buộc hoàn tiền đúng nguồn nạp (dẫn chiếu giao dịch gốc, trùng tên pháp nhân KYC); ràng buộc biên bản đối chiếu khi đổi tỷ giá tay.
- Không bao gồm: engine chặn và SoD enforcement ở tầng API (SYS-CORE-BACKEND); kênh duyệt mobile với MFA TOTP (SYS-MOBILE-INTERNAL); rule engine AML T1–T6 (FEAT-ERP-WALLET-006 — Web chỉ hiển thị kết quả chấm); các giao dịch thường không thuộc 3 nhóm rủi ro cao (duyệt theo FEAT-ERP-WALLET-001 và quy trình duyệt chi REQ-FIN-008).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: workflow UI 2 bước — FIN_L1 (hoặc người đề xuất) tạo, FIN_L2/BOD_CFO_CTO duyệt tuần tự; mọi thao tác gọi API core và hiển thị đúng trạng thái machine-state.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Tạo đề xuất điều chỉnh số dư/đổi tỷ giá/hoàn tiền kèm căn cứ (biên bản, giao dịch nạp gốc) và gửi vào hàng chờ | Mọi can thiệp thủ công vào ví đều có dấu vết đề xuất rõ ràng, không ai tự sửa tay |
| 2 | FIN_L2 | Xem hàng chờ kèm toàn bộ căn cứ và bấm duyệt bước tiếp theo (bước 2 khi DUAL) | Kiểm soát chéo đề xuất của FIN_L1; hệ thống chặn nếu tôi là người đề xuất |
| 3 | BOD_CFO_CTO | Duyệt các khoản hoàn tiền/điều chỉnh vượt ngưỡng (>10 triệu VND — mức đề xuất chờ chính sách) | Giám sát trực tiếp các khoản tiền lớn rủi ro gian lận |
| 4 | FIN_L2 | Chế độ DUAL ép duyệt tuần tự đúng cấp bậc: bước 1 ACCOUNTANT (FIN_L1) → bước 2 CHIEF_ACCOUNTANT (FIN_L2), không đảo, không 1 người cả 2 bước | Luồng kiểm soát đúng thiết kế SoD khi phòng kế toán đã đủ người |
| 5 | SYS_ADMIN | Bật/tắt công tắc approvalMode SINGLE↔DUAL toàn hệ thống (CMS doc §3.6) | Chuyển chế độ theo nhân sự phòng kế toán, không theo ngưỡng tiền, không tự động |
| 6 | BOD_CFO_CTO | Tra audit log bất biến của mỗi giao dịch đã duyệt (ai đề xuất, ai duyệt, giá trị cũ→mới, reason code) | Có bằng chứng kiểm toán đầy đủ khi thanh tra hoặc điều tra nội bộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Chặn thực thi khi thiếu chữ ký là việc của CORE; Web phải phản ánh đúng và không dựng luồng duyệt song song.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-D01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — điều chỉnh/hoàn tiền tác động vào đúng ví-tiền tệ của khách, không bù trừ chéo | API từ chối lệnh tác động chéo tiền tệ; UI hiển thị cặp (ví, tiền tệ) rõ ràng trước khi duyệt |
| BR-D02 | Công thức topup k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5) — hoàn tiền tính trên số liệu giao dịch nạp gốc (đã snapshot), không tính lại theo % hiện hành | Form hoàn tiền hiển thị số liệu gốc từ giao dịch nạp; không có ô cho phép nhập lại % mới |
| BR-D03 | Dual approval cho 3 nhóm rủi ro cao (điều chỉnh số dư thủ công, đổi tỷ giá thủ công, hoàn tiền): người đề xuất ≠ người duyệt; ghi danh tính cả hai; chặn thực thi khi thiếu một trong hai chữ ký | Nút "thực thi" không xuất hiện cho giao dịch thiếu chữ ký; nếu ép gọi API, service layer từ chối |
| BR-D04 | approvalMode `SINGLE/DUAL` là **1 công tắc toàn hệ thống** (CMS doc §3.6): SINGLE — bất kỳ vai duyệt trong nhóm kế toán duyệt 1 lần; DUAL — duyệt tuần tự theo đúng cấp bậc: bước 1 bắt buộc ACCOUNTANT (FIN_L1), bước 2 bắt buộc CHIEF_ACCOUNTANT (FIN_L2), không đảo thứ tự, không 1 người duyệt cả 2 bước; bật/tắt thủ công, không theo ngưỡng, không tự động | Khi DUAL, giao dịch chưa qua bước 1 không hiển thị cho bước 2; hệ thống từ chối chữ ký sai cấp bậc |
| BR-D05 | Hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK ngân hàng/ví nguồn nạp **trùng tên pháp nhân KYC**; cấm hoàn cho bên thứ ba hoặc tài khoản khác tên; lệnh hoàn đổi beneficiary bị **chặn mặc định** + bắn cảnh báo AML T4 (đỏ) | Form hoàn không cho nhập beneficiary tùy ý — chỉ chọn từ danh sách TK đã KYC của khách; mọi ngoại lệ chỉ BOD xem xét bằng văn bản |
| BR-D06 | Đổi tỷ giá tay chỉ khi **biên bản đối chiếu với khách** ghi nhận sai khác (bắt buộc đính kèm biên bản); mặc định dùng snapshot tỷ giá hệ thống tại thời điểm tạo lệnh; sai lệch tỷ giá phát hiện sau ghi nhận xử lý qua khoản FX riêng, không sửa snapshot gốc | Submit đổi tỷ giá không có biên bản đính kèm bị chặn; UI hiển thị snapshot gốc cạnh số đề xuất sửa |
| BR-D07 | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h (BR-FIN-104) — điều chỉnh số dư không được dùng để "cứu" alert đỏ mà không qua căn cứ; mọi điều chỉnh ghi lý do + audit log bất biến (ai, khi nào, giá trị cũ→mới, reason code) | Audit entry thiếu reason code không được submit; việc xem log cũng bị meta-log (REQ-FIN-012) |
| BR-D08 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0 / 0,5%·10USD / 1%·20USD, chốt & khóa kỳ — điều chỉnh số dư phát sinh từ ticket chênh lệch phải đính kèm ticket và chỉ thực hiện được khi kỳ chưa khóa; kỳ đã khóa mở lại chỉ BOD_CFO_CTO duyệt bằng phiếu mở kỳ (lý do, phạm vi, thời hạn) | Trên kỳ đã khóa, form điều chỉnh bị vô hiệu hóa; đề nghị mở kỳ chuyển thành phiếu chờ BOD_CFO_CTO |
| BR-D09 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — hoàn tiền/điều chỉnh là đối tượng chấm AML tự động; rebate không nằm trong công thức topup và phải qua duyệt riêng khi bật | Giao dịch rủi ro cao ở trạng thái AML hold không thực thi dù đủ chữ ký duyệt; rebate không tự cộng vào lệnh hoàn |
| BR-D10 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: quy trình dual approval thuần nội bộ; khách chỉ thấy kết quả (số dư, trạng thái đối soát mức dành cho khách) qua Portal, không thấy hàng chờ duyệt, không tham gia duyệt | Không có route Portal nào đọc được trạng thái duyệt nội bộ; tenant khác không thấy lệnh điều chỉnh của nhau ngoài mức tổng hợp cho phép |
| BR-D11 | Refund khẩn (TKQC bị khóa, lỗi nạp trùng): BOD_CFO_CTO duyệt nhanh qua **kênh khẩn trong hệ thống**; chứng từ hợp thức hóa + hậu kiểm trong 24h — không có luồng khẩn ngoài hệ thống | Kênh khẩn vẫn tạo lệnh + ghi chữ ký BOD_CFO_CTO; quá 24h không hậu kiểm thì escalate tự động |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Mapping vai CMS (ACCOUNTANT → FIN_L1, CHIEF_ACCOUNTANT → FIN_L2, CFO → BOD_CFO_CTO).

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Tạo đề xuất điều chỉnh/đổi tỷ giá/hoàn tiền | ✅ | ✅ (khi là người đề xuất thì mất quyền duyệt lệnh đó) | ✅ (đề xuất của CFO vượt ngưỡng cao nhất → CEO duyệt — compensating control) | ❌ |
| Duyệt SINGLE (1 lần) | ❌ (bước khớp tiền ≠ duyệt) | ✅ | ✅ | ❌ |
| Duyệt DUAL bước 1 (ACCOUNTANT) | ✅ | ❌ | ❌ | ❌ |
| Duyệt DUAL bước 2 (CHIEF_ACCOUNTANT) | ❌ (không được duyệt cả 2 bước) | ✅ | ❌ | ❌ |
| Duyệt vượt ngưỡng (>10 triệu VND — mức đề xuất `[CẦN CHỐT SỐ]`) | ❌ | ❌ | ✅ | ❌ |
| Xem audit log + meta-log | ✅ (tra cứu) | ✅ (tra cứu) | ✅ | ❌ (việc xem cũng bị log) |
| Đổi công tắc SINGLE↔DUAL | ❌ | ❌ | ✅ (phê duyệt chuyển chế độ) | ✅ (thao tác kỹ thuật theo phê duyệt) |
| Duyệt mở kỳ đã khóa (phiếu mở kỳ) | ❌ | ❌ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- CFO kiêm CTO (Super Admin) là người đề xuất → giao dịch vượt ngưỡng cao nhất do CEO (BOD_CEO) duyệt thay — compensating control cho kiêm nhiệm; Web phải cho phép router duyệt thay đúng kịch bản này.
- Người duyệt đi công tác/nghỉ dài: chỉ có kênh mobile (SYS-MOBILE-INTERNAL, MFA TOTP) hoặc delegate theo quy trình ủy quyền — không có "duyệt hộ không ủy quyền" trên Web.
- Hoàn tiền cho TK bị khóa (die account còn dư do platform hoàn): FIN_L1 khớp tiền hoàn về theo giao dịch gốc trước, hoàn cho khách vẫn qua luồng dual approval đầy đủ.
- Giao dịch đang ở `PENDING` mà công tắc hệ thống chuyển SINGLE→DUAL: lệnh đang treo xử lý theo chế độ tại thời điểm tạo (ghi mode vào lệnh), không áp ngược chế độ mới cho lệnh cũ.
- Biên bản đối chiếu với khách cần bổ sung sau khi đã submit: phải thu hồi đề xuất (nếu chưa duyệt bước nào), sửa và nộp lại — không thay file đính kèm lặng lẽ trên lệnh đã vào hàng chờ.
- Nhiều điều chỉnh nhỏ cùng gốc rễ (một lỗi hệ thống tạo ra hàng loạt sai lệch): gom xử lý theo đợt với một phiếu giải trình, nhưng mỗi lệnh vẫn phải có đủ chữ ký riêng theo chế độ đang bật.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Đề xuất giao dịch rủi ro cao (RiskAdjustmentRequest — pattern RechargeRequest CMS doc §3.6).*

**Entity:** Đề xuất dual approval (RiskAdjustmentRequest)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING]
                         │  SINGLE: 1 chữ ký            DUAL: tuần tự
                         ├──────────────► [APPROVED] ◄── [STEP1_APPROVED (ACCOUNTANT)] ──(CHIEF_ACCOUNTANT)──┘
                         │                  │ thực thi
                         │                  ▼
                         │              [COMPLETED]
                         │ (reject)
                         ▼
                    [REJECTED] ──(khách/khiếu nại)──► [DISPUTED] ──(quay lại review)──► [PENDING]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING` | FIN_L1/FIN_L2/BOD_CFO_CTO (đề xuất) | Đủ căn cứ: lý do, giá trị cũ→mới, biên bản (đổi tỷ giá), giao dịch nạp gốc (hoàn tiền) |
| `PENDING` | Duyệt 1 lần (SINGLE) | `APPROVED` | FIN_L2 hoặc BOD_CFO_CTO | Mode ghi trên lệnh = SINGLE; duyệt ≠ đề xuất |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (ACCOUNTANT) | Mode = DUAL; đúng cấp bậc bước 1 |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (CHIEF_ACCOUNTANT) | ≠ người bước 1; đúng cấp bậc |
| `PENDING`/`STEP1_APPROVED` | Từ chối | `REJECTED` | Vai duyệt tương ứng | Lý do bắt buộc |
| `APPROVED` | Thực thi (CORE ghi sổ) | `COMPLETED` | Hệ thống | Không ở trạng thái AML hold; kỳ chưa khóa (hoặc có phiếu mở kỳ) |
| `REJECTED` | Khiếu nại → review lại | `DISPUTED` → `PENDING` | FIN_L1 ghi nhận | Có nội dung khiếu nại |

**Quy tắc:**
- `COMPLETED` là trạng thái kết thúc — mọi điều chỉnh sau đó là đề xuất mới gắn giao dịch reversal.
- Chữ ký ghi danh tính + timestamp; không có hành động "rút chữ ký đã bấm" — sai thì tạo đề xuất thu hồi mới.
- Giao dịch rủi ro cao chạm cảnh báo AML (T1–T6) → giữ ở `APPROVED` không thực thi đến khi AML có quyết định.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| RiskAdjustmentRequest | `type` (BALANCE_ADJUST/FX_CHANGE/REFUND), `walletId`, `oldValue`, `newValue`, `reasonCode`, `mode` (SINGLE/DUAL), `state` | FK → Wallet, gốc của RefundSourceTransaction khi REFUND | Mode chốt tại thời điểm tạo |
| ApprovalSignature | `requestId`, `step` (1/2), `approverId`, `role`, `timestamp` | FK → RiskAdjustmentRequest | Bất biến; tối đa 2 bước |
| RefundSourceTransaction | `requestId`, `sourceTopupId`, `beneficiaryAccountId`, `kycMatch` | FK → RiskAdjustmentRequest, WalletTransaction | Beneficiary chỉ chọn từ TK đã KYC |
| SettlementMinuteFile (biên bản) | `requestId`, `fileId`, `uploadedBy`, `uploadedAt` | FK → RiskAdjustmentRequest | Bắt buộc với FX_CHANGE |
| OpenPeriodTicket (phiếu mở kỳ) | `periodId`, `reason`, `scope`, `validUntil`, `approvedBy` | FK → AccountingPeriod | Chỉ BOD_CFO_CTO duyệt |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn thiếu chữ ký | Mode DUAL, lệnh mới qua bước 1 | FIN_L1 (người bước 1) thử thực thi | Chặn; lệnh đứng ở `STEP1_APPROVED` chờ FIN_L2 | [ ] |
| SC-002: Cấm tự duyệt lệnh mình | FIN_L2 vừa là người đề xuất | FIN_L2 mở hàng chờ | Nút duyệt không hiển thị; API từ chối vai trùng | [ ] |
| SC-003: Hoàn sai beneficiary | TK nhận không trùng tên pháp nhân KYC | Tạo hoàn tiền tới TK đó | Chặn mặc định + sinh cảnh báo T4 (đỏ) | [ ] |
| SC-004: Đổi tỷ giá thiếu biên bản | FX_CHANGE không đính biên bản | Submit | Bị chặn kèm thông báo yêu cầu biên bản đối chiếu | [ ] |
| SC-005: Vượt ngưỡng lên CFO | Hoàn tiền 15 triệu VND (mức đề xuất) | FIN_L2 duyệt xong | Vẫn chờ BOD_CFO_CTO duyệt thêm trước khi thực thi | [ ] |
| SC-006: Điều chỉnh trên kỳ đã khóa | Kỳ tháng trước đã khóa | FIN_L1 mở form điều chỉnh | Form vô hiệu; chuyển sang đề nghị phiếu mở kỳ cho BOD_CFO_CTO | [ ] |

> **Liên kết:** SC-001/SC-002 → REQ-FIN-003 (BR-D03/D04); SC-003 → REQ-FIN-003 + REQ-FIN-010 (BR-D05); SC-004 → REQ-FIN-003 (BR-D06); SC-005 → REQ-FIN-003 (ngưỡng `[CẦN CHỐT SỐ]`); SC-006 → REQ-FIN-003 (BR-D08) trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (risk adjustment, approval signature) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (approvals, risk-adjustments) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-003: CORE, MOBILE-INTERNAL) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (hàng chờ duyệt, chi tiết đề xuất) |
| Nguồn domain chi tiết | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.6 RechargeRequest SINGLE/DUAL) |
