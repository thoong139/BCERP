# Tính Năng: Dual approval điều chỉnh số dư / đổi tỷ giá / hoàn tiền

> **Dựa trên:** REQ-FIN-003 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.6 approvalMode SINGLE/DUAL)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-003-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-003 (REQ xuất hiện ở 3 systems). Counterparts: SYS-BCERP-WEB (kênh tạo/duyệt chính), SYS-MOBILE-INTERNAL (duyệt khi di chuyển, MFA TOTP bắt buộc). Touchpoint Core Backend là **headless API/domain service**: engine chặn thực thi khi thiếu chữ ký chạy ở tầng service — bất kỳ kênh nào (WEB/MOBILE) gọi API đều bị áp cùng quy tắc, không tin UI. Ánh xạ vai từ CMS Domain Model: ACCOUNTANT → FIN_L1, CHIEF_ACCOUNTANT → FIN_L2, CFO → BOD_CFO_CTO, ADMIN → SYS_ADMIN.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-003 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-003 |
| Người dùng liên quan | FIN_L1 (tạo lệnh/bước 1 DUAL), FIN_L2 (duyệt/bước 2 DUAL), BOD_CFO_CTO (duyệt vượt ngưỡng, SINGLE) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (ledger + lệnh hệ thống); liên kết FEAT-CORE-WALLET-006 (hoàn tiền đúng nguồn — AML T4) |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); compliance-expert (call-2) đã bổ sung BR-FIN-505 change management cho luồng tiền và BR-FIN-402 hoàn tiền đúng nguồn ghép với dual approval — người đề xuất/nhập không tự điều tra khi bị cảnh báo AML |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Kiểm soát bằng cơ chế duyệt kép (dual approval) cho 3 nhóm giao dịch rủi ro cao nhất trên ví TKQC — (1) điều chỉnh số dư thủ công, (2) đổi tỷ giá thủ công, (3) hoàn tiền cho khách — để chống gian lận nội bộ: không một cá nhân nào, kể cả quản lý cấp cao, có thể tự mình làm thay đổi số tiền của khách mà không có chữ ký thứ hai với thẩm quyền tương xứng. Core Backend là nơi **chặn thực thi cứng**: thiếu một trong hai chữ ký, giao dịch không bao giờ được thực hiện, bất kể kênh thao tác.

**Phạm vi:**
- Bao gồm: engine approval cho 3 nhóm giao dịch rủi ro cao theo công tắc hệ thống `SINGLE/DUAL` (chế độ DUAL duyệt tuần tự bắt buộc FIN_L1 → FIN_L2, không đảo thứ tự, không cùng một người duyệt cả hai bước); kiểm tra người đề xuất ≠ người duyệt; điều kiện riêng cho đổi tỷ giá tay (bắt buộc đính kèm biên bản đối chiếu với khách có sai khác); điều kiện hoàn tiền đúng nguồn (dẫn chiếu giao dịch nạp gốc, trả về đúng tài khoản nguồn trùng tên pháp nhân KYC, cấm hoàn bên thứ ba); ngưỡng vượt thẩm quyền → BOD_CFO_CTO duyệt thêm; audit log bất biến mọi bước (ai, khi nào, giá trị old→new, reason code).
- Không bao gồm: vòng lệnh nạp bình thường (FEAT-CORE-WALLET-001); màn hình tạo/duyệt trên WEB và kênh MOBILE (SYS-BCERP-WEB / SYS-MOBILE-INTERNAL — Core cung cấp API + xác thực MFA TOTP qua service); rule engine AML chấm điểm lệnh hoàn (FEAT-CORE-WALLET-006 — Core điều phối hold khi cảnh báo đỏ); điều chỉnh phát hiện từ đối trừ (FEAT-CORE-WALLET-004 — nhưng mọi điều chỉnh kết xuất từ đó phải đi qua dual approval của tính năng này).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Tạo lệnh điều chỉnh số dư/đổi tỷ giá/hoàn tiền với đầy đủ căn cứ (biên bản, giao dịch nạp gốc, lý do) | Đề xuất của tôi có dấu vết rõ ràng và được duyệt đúng thẩm quyền, không chịu trách nhiệm một mình |
| 2 | FIN_L2 | Duyệt bước 2 sau khi FIN_L1 đã duyệt bước 1, thấy rõ giá trị old→new và căn cứ | Tôi duyệt trên thông tin đầy đủ và không bao giờ duyệt chính đề xuất của mình |
| 3 | BOD_CFO_CTO | Được yêu cầu duyệt thêm khi refund/điều chỉnh vượt ngưỡng (>10 triệu VND — mức mặc định theo DI-001) | Các khoản rủi ro lớn có lớp kiểm soát cấp cao nhất |
| 4 | FIN_L2 / BOD_CFO_CTO | Duyệt trên MOBILE khi di chuyển với MFA TOTP bắt buộc | Không vì vắng mặt ở văn phòng mà nghẽn dòng tiền khẩn |
| 5 | Hệ thống (Core service) | Từ chối thực thi bất kỳ giao dịch 3 nhóm rủi ro cao nào khi thiếu một chữ ký hoặc sai thứ tự duyệt | Không tồn tại kẽ hở kỹ thuật để một người tự duyệt đề xuất của chính mình |
| 6 | CUSTOMER (Portal) | Xem lịch sử điều chỉnh ví của mình (mask giá vốn thành "điều chỉnh đối soát") | Minh bạch với khách về mọi thay đổi số dư mà không lộ dữ liệu nội bộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; engine approval áp dụng cho mọi kênh gọi API.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-D01 | Nền tảng: mọi lệnh điều chỉnh/hoàn tiền thao tác trên ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi); snapshot fee %/tỷ giá tại thời điểm giao dịch — sửa số dư chỉ qua lệnh, không UPDATE trực tiếp ledger (FEAT-CORE-WALLET-001) | Service từ chối lệnh thao tác chéo currency hoặc ghi thẳng vào ledger; mọi thay đổi qua bút toán reversal |
| BR-D02 | Phạm vi dual approval bắt buộc cho đúng 3 nhóm: (1) điều chỉnh số dư thủ công; (2) đổi tỷ giá thủ công; (3) hoàn tiền cho khách (BR-FIN-105; CMS §3.6 mở rộng cho Recharge/Withdraw) | Giao dịch thuộc 3 nhóm mà đi luồng xử lý khác → chặn `RISKY_TX_WRONG_FLOW` |
| BR-D03 | Công tắc `approvalMode`: `SINGLE/DUAL` là 1 công tắc toàn hệ thống, SYS_ADMIN bật/tắt thủ công khi phòng kế toán đủ người — không theo ngưỡng số tiền, không tự động. `SINGLE`: bất kỳ FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần. `DUAL`: tuần tự bắt buộc — bước 1 FIN_L1, bước 2 FIN_L2, không đảo thứ tự, không cùng một người duyệt cả 2 bước | Core chặn `APPROVAL_SEQUENCE_INVALID` khi sai vai/thứ tự; chuyển mode giữa chừng: lệnh đã tạo giữ mode tại thời điểm tạo |
| BR-D04 | Người đề xuất ≠ người duyệt (bắt buộc ở cả SINGLE và DUAL); ghi danh tính cả hai; chặn thực thi khi thiếu một trong hai chữ ký — kể cả vai Super Admin cũng không có quyền bypass | Engine chặn thực thi (`MISSING_SIGNATURE`); mọi nỗ lực ghi audit log bất biến |
| BR-D05 | Ngưỡng thẩm quyền: refund/điều chỉnh >10 triệu VND (quy VND theo snapshot tỷ giá ngày tạo lệnh) thuộc thẩm quyền BOD_CFO_CTO duyệt thêm (mức mặc định đã chốt theo DI-001, chờ chính sách hạn mức chi ban hành chính thức) | Service yêu cầu chữ ký thứ ba BOD_CFO_CTO trước khi thực thi; thiếu → giữ trạng thái chờ |
| BR-D06 | Đổi tỷ giá tay chỉ khi biên bản đối chiếu với khách ghi nhận sai khác — bắt buộc đính kèm biên bản khi tạo lệnh; mặc định dùng snapshot tỷ giá hệ thống tại thời điểm tạo lệnh; sai khác tỷ giá phát hiện sau ghi nhận xử lý qua khoản FX riêng, không sửa snapshot gốc (BR-FIN-203/105) | Lệnh đổi tỷ giá thiếu đính kèm biên bản bị chặn submit (`FX_ADJ_EVIDENCE_REQUIRED`) |
| BR-D07 | Hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK ngân hàng/ví nguồn nạp **trùng tên pháp nhân KYC**; cấm hoàn cho bên thứ ba hoặc tài khoản khác tên; lệnh hoàn đổi beneficiary bị chặn mặc định và bắn cảnh báo AML T4 (đỏ) — chỉ BOD xem xét lại bằng văn bản trong 3 ngày làm việc (BR-FIN-402) | Core tự khớp tên chủ TK nhận với tên pháp nhân đã KYC — lệch → chuyển rà thủ công + T4; chặn thực thi hoàn cho bên thứ ba |
| BR-D08 | Refund khẩn (TKQC bị khóa, lỗi nạp trùng): BOD_CFO_CTO duyệt nhanh qua kênh khẩn **trong hệ thống**; chứng từ hợp thức hóa + hậu kiểm trong 24h — kênh khẩn vẫn nằm trong engine approval, không có đường tắt ngoài hệ thống | Mọi lệnh kênh khẩn thiếu hậu kiểm 24h → escalate BOD; không tồn tại API duyệt ngoài workflow chuẩn |
| BR-D09 | SoD 4 vai dòng tiền: người tạo/đề xuất ≠ người khớp tiền (FIN_L1) ≠ người duyệt chi (FIN_L2) ≠ người ghi sổ; tối thiểu 2 người cho khoản trong hạn mức, 3 người cho khoản dual approval (BR-FIN-106) | SoD engine chặn submit/gán duyệt khi vai trùng; log vi phạm append-only cho BOD_CFO_CTO rà định kỳ |
| BR-D10 | Audit log bất biến mọi bước: ai (user, role), khi nào, giá trị old→new, reason code bắt buộc — thiếu reason code không được submit; kể cả Super Admin không sửa/xóa log; hash-chain kiểm tra toàn vẹn hằng ngày (BR-FIN-501/505) | Submit thiếu reason code bị chặn; đứt hash-chain → alert CTO + BOD_CEO ngay |
| BR-D11 | Đối trừ 3 số và chốt kỳ: mọi điều chỉnh đã duyệt qua tính năng này là cơ sở duy nhất để hạch toán chênh lệch đối soát (dung sai 0 / 0,5%·10USD / 1%·20USD — mặc định theo DI-001); cấm tự cân số hai vế cho khớp; kỳ đã khóa chỉ mở bằng phiếu do BOD_CFO_CTO duyệt (BR-FIN-202/204 — chi tiết FEAT-CORE-WALLET-004) | Điều chỉnh không qua dual approval không được tính vào đối soát; sửa chứng từ kỳ đã khóa bị chặn tầng dữ liệu |
| BR-D12 | AML T1–T6 + UBO ≥25% (mặc định theo DI-001) chấm điểm mọi lệnh hoàn/điều chỉnh; giao dịch nghi vấn bị khóa mềm đến khi có quyết định; người đề xuất/nhập giao dịch không được tự điều tra (BR-FIN-403/404 — chi tiết FEAT-CORE-WALLET-006); Rebate mặc định TẮT — hoàn rebate không tự động, Finance bật tay + nhập tay theo quý | Lệnh hoàn vi phạm T4/T5/T6 → hold tự động; không thể "duyệt nhanh" bỏ qua hold bằng dual approval |
| BR-D13 | Portal chỉ đọc số dư ví và lịch sử điều chỉnh ở mức dành cho khách (REQ-FIN-017) — tenant isolation; khách không thấy người duyệt, biên bản nội bộ, giá vốn | Truy vấn Portal ép điều kiện tenant; dữ liệu chi tiết duyệt không nằm trong view khách |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|-----------|-------------------|
| Tạo lệnh điều chỉnh số dư / đổi tỷ giá / hoàn tiền | ✅ | ✅ | ✅ | ❌ | ❌ |
| Duyệt — SINGLE (1 lần) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Duyệt — DUAL bước 1 | ✅ (bắt buộc) | ❌ | ❌ | ❌ | ❌ |
| Duyệt — DUAL bước 2 | ❌ | ✅ (bắt buộc) | ❌ | ❌ | ❌ |
| Duyệt thêm khoản >10 triệu VND | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt nhanh kênh khẩn (refund khẩn) | ❌ | ❌ | ✅ (hậu kiểm 24h) | ❌ | ❌ |
| Xem xét lại lệnh hoàn đổi beneficiary | ❌ | ❌ | ✅ (BOD, bằng văn bản 3 ngày) | ❌ | ❌ |
| Bật/tắt approvalMode SINGLE/DUAL | ❌ | ❌ | ❌ (phê duyệt chính sách) | ✅ (thao tác công tắc) | ❌ |
| Sửa/xóa lệnh đã duyệt hoặc audit log | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin) | ❌ — chỉ qua reversal |
| Xem lịch sử điều chỉnh ví (đã mask) | ✅ | ✅ | ✅ | ❌ | ✅ (tenant mình, read-only) |

---

## 5. Trường Hợp Đặc Biệt

- **CFO (BOD_CFO_CTO) là người đề xuất:** compensating control — giao dịch do BOD_CFO_CTO khởi tạo vượt ngưỡng cao nhất do BOD_CEO duyệt thay; DUAL vẫn yêu cầu đủ 2 bước với người khác.
- **Chuyển approvalMode giữa chừng:** lệnh đang chờ giữ nguyên mode tại thời điểm tạo; chỉ lệnh tạo mới áp dụng mode hiện hành — tránh lệnh bị "đổi luật giữa dòng".
- **Refund khẩn ngoài giờ:** duyệt nhanh qua kênh khẩn trong hệ thống bởi BOD_CFO_CTO; lệnh vẫn đủ 2 lớp dữ liệu (người tạo + người duyệt) và bắt buộc hậu kiểm 24h.
- **Khách nhiều pháp nhân:** tên tài khoản nhận hoàn phải khớp pháp nhân đã KYC của chính giao dịch nạp gốc — khách chuyển tiền giữa các pháp nhân nhóm mẹ/con không được coi là "trùng tên" tự động, phải qua BOD duyệt theo ngoại lệ KYC.
- **Tỷ giá phát hiện sai sau khi lệnh đã thực thi:** không sửa snapshot gốc — ghi khoản FX riêng; nếu số tiền ảnh hưởng lớn vượt dung sai → ticket discrepancy theo FEAT-CORE-WALLET-004.
- **Người duyệt nghỉ đột ngột/nghỉ việc:** delegate FIN_L2 chỉ do BOD_CFO_CTO ủy quyền cho cá nhân cụ thể, hạn mức ≤ FIN_L2, tối đa 14 ngày, tự thu hồi, log gắn nhãn "theo ủy quyền #id" (chuẩn REQ-FIN-008); không ủy quyền hàng loạt.
- **Lệnh hoàn bị AML hold khi đang chờ duyệt:** hold ưu tiên hơn duyệt — giao dịch giữ trạng thái hold đến khi FEAT-CORE-WALLET-006 kết luận; không hoàn release bằng chữ ký duyệt thông thường.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** RiskyTransactionRequest (lệnh điều chỉnh số dư / đổi tỷ giá / hoàn tiền)

**Sơ đồ trạng thái:**
```
                    ┌──────────── mode SINGLE ────────────┐
[PENDING] ──────────┤                                      ├──► [APPROVED] ──(thực thi)──► [EXECUTED]
    │               └──────────── mode DUAL ──────────────┘        ▲
    │ (bước 1 — FIN_L1) → [STEP1_APPROVED] ─(bước 2 — FIN_L2)──────┘
    │                                                               
    │ (từ chối + lý do, bất kỳ bước)                                │ (AML hold — T4/T5/T6)
    ▼                                                               ▼
[REJECTED] ──(khách khiếu nại)──► [DISPUTED] ──► [PENDING]     [ON_HOLD] ──(kết luận AML)──► [PENDING | BLOCKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Duyệt (SINGLE) | `APPROVED` | FIN_L1/FIN_L2/BOD_CFO_CTO, ≠ người tạo | Mode tại thời điểm tạo = SINGLE |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (bắt buộc) | Ghi danh tính + timestamp |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (bắt buộc) | ≠ người bước 1; không đảo thứ tự |
| `PENDING`/`STEP1_APPROVED` | Từ chối | `REJECTED` | Theo mode hiện hành | Lý do bắt buộc; ghi audit log |
| `REJECTED` | Khách khiếu nại | `DISPUTED` | CUSTOMER (qua AM) → FIN_L2 | Quay lại `PENDING` review |
| `APPROVED` | Thực thi ghi sổ | `EXECUTED` | Core (tự động) | Đủ chữ ký; reason code; snapshot đã tạo |
| Bất kỳ đang chờ | AML cảnh báo đỏ (T4/T5/T6) | `ON_HOLD` | Core (tự động) | Cấm xử lý song song; chờ kết luận điều tra |
| `ON_HOLD` | Kết luận vô hại | `PENDING` (tiếp tục duyệt) | FIN_L2 điều tra | Ghi lý do văn bản, lưu vĩnh viễn |
| `ON_HOLD` | Xác nhận nghi vấn | `BLOCKED` | BOD (quyết định đỏ) | Quyết định bằng văn bản, lưu vĩnh viễn |

**Quy tắc:**
- Không chuyển thẳng `PENDING → EXECUTED` dưới mọi hình thức — mọi đường thực thi đều phải đi qua `APPROVED` với đủ chữ ký.
- `EXECUTED` và `BLOCKED` là trạng thái kết thúc; sửa dữ liệu đã thực thi chỉ qua lệnh điều chỉnh ngược (reversal) mới có dual approval riêng.
- Người đề xuất không được xuất hiện lần nữa trong chuỗi duyệt của cùng một lệnh.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `RiskyTransactionRequest` | `type` (BALANCE_ADJ/FX_ADJ/REFUND), `wallet_id`, `amount`, `currency`, `approval_mode`, `status`, `proposed_by`, `step1_by`, `step2_by`, `extra_approver_by`, `reason_code`, `evidence[]` | FK → `wallets.id`, `wallet_transactions.id` (nạp gốc cho refund) | State machine §6; refund bắt buộc `source_transaction_id` |
| `AdjustmentEntry` (bút toán điều chỉnh) | `request_id`, `old_value`, `new_value`, `reversal_of` | FK → `risky_transaction_requests.id` | Ledger append-only; reversal giữ dấu vết old→new |
| `FxAdjustmentDocument` | `request_id`, `bien_ban_file_ref`, `difference_amount`, `period` | FK → `risky_transaction_requests.id` | Bắt buộc cho FX_ADJ (BR-D06) |
| `ApprovalAuditLog` | `request_id`, `actor`, `role`, `action`, `timestamp`, `old→new`, `hash_prev` | FK → `risky_transaction_requests.id` | Append-only + hash-chain; meta-log khi xem |
| `DelegationRecord` | `from_role` (FIN_L2 delegate của BOD_CFO_CTO), `to_user`, `limit`, `valid_until`, `label` ("theo ủy quyền #id") | FK → `users.id` | ≤14 ngày, tự thu hồi |
| `PortalAdjustmentView` | `tenant_id`, `adjustment_date`, `amount`, `masked_type` ("điều chỉnh đối soát") | View lọc `tenant_id` | Mask giá vốn; read-only |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn thiếu chữ ký (DUAL) | Mode DUAL, lệnh `STEP1_APPROVED` | Gọi API thực thi | Từ chối `MISSING_SIGNATURE`; lệnh giữ nguyên trạng thái; log nỗ lực | [ ] |
| SC-002: Cùng người 2 bước | Mode DUAL, FIN_L1 vừa duyệt bước 1 | FIN_L1 (tài khoản khác có cùng vai) cố duyệt bước 2 | Chặn `APPROVAL_SEQUENCE_INVALID`; yêu cầu FIN_L2 khác | [ ] |
| SC-003: Người đề xuất tự duyệt | FIN_L1 tạo lệnh điều chỉnh | FIN_L1 duyệt chính lệnh đó (kể cả SINGLE) | Từ chối; đề xuất ≠ duyệt ép ở engine | [ ] |
| SC-004: FX thiếu biên bản | Tạo lệnh đổi tỷ giá tay không đính biên bản đối chiếu | Submit | Chặn `FX_ADJ_EVIDENCE_REQUIRED`; đính biên bản → đi tiếp vào duyệt | [ ] |
| SC-005: Hoàn đổi beneficiary | Lệnh hoàn với TK nhận khác tên pháp nhân KYC | Submit | Chặn mặc định + cảnh báo T4 (đỏ); chỉ BOD xem xét lại bằng văn bản | [ ] |
| SC-006: Vượt ngưỡng cần CFO | Refund 15 triệu VND (mặc định DI-001) | Đủ 2 chữ ký FIN | Vẫn chưa thực thi; chờ chữ ký BOD_CFO_CTO; đủ mới `EXECUTED` | [ ] |
| SC-007: Audit log + reason code | Tạo lệnh không nhập reason code | Submit | Chặn; bổ sung reason code → submit thành công; log ghi old→new | [ ] |
| SC-008: Kỳ đã khóa | Kỳ tháng đã khóa | Thử sửa lệnh điều chỉnh trong kỳ | Chặn tầng dữ liệu; chỉ mở bằng phiếu BOD_CFO_CTO duyệt + chốt lại | [ ] |

> **Liên kết:** SC-001→004, 007 map REQ-FIN-003 Mục 2 (A3, BR-FIN-105/106); SC-005 map REQ-FIN-010 (BR-FIN-402); SC-006 map DI-001 (ngưỡng mặc định); SC-008 map REQ-FIN-004 (BR-FIN-204).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — RiskyTransactionRequest, ApprovalAuditLog, DelegationRecord | `technical-specs/database-design.md` |
| API Endpoints — approval engine, MFA TOTP verification, kênh khẩn | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — MOBILE duyệt MFA, AML hold (FEAT-006), đối soát (FEAT-004) | `technical-specs/integration-map.md` |
| Màn hình UI (hàng chờ duyệt thuộc SYS-BCERP-WEB) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 (§3.6 SINGLE/DUAL) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
