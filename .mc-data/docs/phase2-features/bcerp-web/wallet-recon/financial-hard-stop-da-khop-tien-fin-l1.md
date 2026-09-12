# Tính Năng: Financial Hard Stop "đã khớp tiền" FIN_L1

> **Dựa trên:** REQ-FIN-006 trong `phase1-business/departments/finance/finance.md` (Phần A, B.3 — BR-FIN-302); phối hợp REQ-OPS-002 (`phase1-business/departments/operations/operations.md` — BR-OPS-2.1/2.2)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md` (REQ-OPS-002 — cross-dependency)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-005-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-FIN-006 (fan-out 3 hệ thống); counterpart: SYS-CORE-BACKEND (chặn cứng trong code — workflow engine), SYS-MOBILE-INTERNAL (chỉ alert/xem — **không** xác nhận khớp tiền trên mobile).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-005 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-006 (cross-dependency: REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn / DR handoff) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (gặp gate phía OPS: OPS_ADS/OPS_AM) |
| Độ ưu tiên | Cao (HIGH · GĐ1 — trụ cột số 1 của FINANCE, MVP) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | FEAT-ERP-WALLET-001 (vòng lệnh nạp 5 bước — "Đã khớp tiền" là bước 5); use-case gate cấp phát TKQC thuộc MOD-ADACCOUNT-CC (REQ-OPS-002) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể. Quy tắc không có exception đã khẳng định ở cả 2 dept docs: không vai nào bypass kể cả Giám đốc/Super Admin |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thực hiện trụ cột số 1 của FINANCE trên Web nội bộ: không bao giờ cấp TKQC/bật chi tiêu khi tiền của khách chưa về tài khoản BC và chưa khớp số với lệnh nạp — FIN_L1 là vai duy nhất xác nhận trạng thái **"Đã khớp tiền"** trên Web với MFA TOTP, kèm evidence (sao kê/lệnh) và timestamp; gate được chặn cứng trong code ở phía backend và Web không hiển thị bất kỳ nút override nào.

**Phạm vi:**
- Bao gồm: màn xác nhận "Đã khớp tiền" của FIN_L1 (MFA TOTP, đính evidence bắt buộc); hiển thị trạng thái hard stop trên từng TKQC/lệnh nạp cho mọi vai liên quan; màn thu hồi xác nhận sai (FIN_L1) với hệ quả tự động (TK về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL); hàng đợi các lệnh nạp chờ khớp cho FIN_L1 xử lý theo thứ tự.
- Không bao gồm: thực thi chặn tầng API/workflow engine (SYS-CORE-BACKEND — bản Web chỉ gọi và hiển thị đúng trạng thái); điểm chặn trong vòng đời cấp phát TKQC của OPS (REQ-OPS-002 — MOD-ADACCOUNT-CC); kênh mobile (SYS-MOBILE-INTERNAL — chỉ nhận alert/xem, chủ ý không có action để loại nguy cơ bypass).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: Web là **kênh xác nhận khớp tiền duy nhất** — luồng form/list/workflow UI gọi API core, hiển thị đúng trạng thái machine-state của gate.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xác nhận "Đã khớp tiền" trên Web với MFA TOTP sau khi đối chiếu sao kê ↔ lệnh nạp, kèm đính evidence (sao kê/lệnh) | Mở gate cấp phát TKQC chỉ khi tiền thật sự về và khớp số |
| 2 | FIN_L1 | Thấy hàng đợi lệnh nạp chờ khớp sắp theo thời gian chờ | Xử lý khớp tiền có thứ tự, không bỏ sót lệnh treo |
| 3 | OPS_ADS/OPS_AM | Xem trạng thái hard stop của từng TKQC (đang khóa vì chưa khớp tiền) trên Web | Biết rõ TK chưa cấp phát được vì thiếu bước nào, không đi hỏi FIN bằng miệng |
| 4 | FIN_L1 | Thu hồi xác nhận khớp tiền khi phát hiện khớp sai | Kéo TKQC về "Tạm dừng chi tiêu" ngay lập tức để chặn thiệt hại |
| 5 | FIN_L2 | Xem nhật ký mọi lần xác nhận/thu hồi + evidence + timestamp + người thực hiện | Truy vết đầy đủ khi có sai sót hoặc tranh chấp |
| 6 | BOD_CFO_CTO | Xem số liệu "case cấp TKQC khi chưa khớp tiền" = 0 realtime | Đo lường trực tiếp hiệu lực của trụ cột hard stop |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính nằm trong code phía CORE (workflow engine); Web bắt buộc không dựng lại bất kỳ lối tắt nào.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-H01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — "Đã khớp tiền" chỉ xác định trên lệnh nạp cụ thể, đúng tiền tệ, đúng số, đúng người chuyển trùng tên pháp nhân KYC | Không có xác nhận "khớp chung chung theo khách"; xác nhận gắn 1-1 với lệnh nạp |
| BR-H02 | Công thức topup k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5) — số khớp là grossAmount trừ ví theo snapshot giao dịch, không phải con số net khách nói miệng | Màn xác nhận hiển thị breakdown gross theo snapshot; lệch thành phần nào thì không khớp được |
| BR-H03 | **"Đã khớp tiền" = tiền đã về tài khoản BC VÀ khớp số với lệnh nạp** — FIN_L1 xác nhận trên hệ thống, ghi timestamp + căn cứ (sao kê ngân hàng/lệnh nạp); TKQC chỉ được cấp phát khi trạng thái khớp tiền của lệnh nạp tương ứng = "Đã khớp tiền" | Action "Cấp phát TKQC" chỉ xuất hiện khi gate mở; thiếu evidence thì nút xác nhận disabled |
| BR-H04 | Hard Stop thực thi **trong code** (workflow engine): không nút override, không route bypass — **không vai nào bypass, kể cả CEO/BOD_CEO, kể cả Super Admin**; không chấp nhận "chờ duyệt"/"khách hứa chuyển"/"đang chuyển" — các lý do này không có giá trị mở khóa; mọi yêu cầu mở khóa thủ công bị **từ chối + ghi audit log bất biến** | UI không render nút override trong mọi vai; request mở khóa thủ công trả lỗi cố ý và log lại vĩnh viễn |
| BR-H05 | Xác nhận chỉ thực hiện trên **WEB với MFA TOTP**; mobile (counterpart) chỉ alert/xem — không có xác nhận khớp tiền trên mobile | Endpoint xác nhận không được phép gọi từ touchpoint mobile; Web bắt buộc bước MFA trước khi ghi xác nhận |
| BR-H06 | **Thu hồi xác nhận sai**: FIN_L1 thu hồi → CORE tự chuyển TKQC về "Tạm dừng chi tiêu", khóa lệnh nạp mới, bắn alert TL; mọi chuyển trạng thái vòng đời ghi audit log bất biến | Thu hồi là thao tác có lý do bắt buộc; hệ quả 3 bước chạy tự động, không phụ thuộc người bấm |
| BR-H07 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0 / 0,5%·10USD / 1%·20USD, chốt & khóa kỳ — khớp tiền dùng cho hard stop phải là số đã đối chiếu sao kê ngân hàng (evidence), không phải con số chờ đối trừ | Lệnh chưa có evidence sao kê không thể xác nhận; trạng thái "chờ đối trừ" không mở gate |
| BR-H08 | Dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền — hard stop không nhận "cam kết duyệt sau" làm điều kiện mở | Không có trạng thái trung gian "đã duyệt chờ tiền"; chỉ 2 trạng thái hữu hiệu: đã khớp / chưa khớp |
| BR-H09 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — khớp tiền không vượt qua kiểm tra AML: giao dịch nạp đang AML hold chưa được coi là khớp hoàn tất cho mục đích mở gate dài hạn (chỉ mở khi AML có quyết định không nghi vấn) | Lệnh nạp đang hold hiển thị nhãn AML; gate vẫn khóa đến khi có quyết định |
| BR-H10 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: khách không thấy trạng thái hard stop nội bộ và không thao tác được gate; thông tin tới khách qua AM/Portal theo mức cho phép | Không có route Portal nào đọc/đụng gate; dữ liệu trạng thái nội bộ không lọt view khách |
| BR-H11 | **Không có exception** (BR-OPS-2.1): khẩn cấp ngoài giờ vẫn chỉ mở khi đã khớp tiền — xử lý nhanh hơn, không bỏ bước; khẩn ngoài giờ vẫn tạo lệnh trên hệ thống trước khi xử lý | Web luôn cho tạo lệnh + xác nhận (khi đủ điều kiện) 24/7, nhưng không bỏ được bất kỳ điều kiện nào |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Mọi vai đều KHÔNG có quyền override — hàng "Override/bypass" cố ý có đầy đủ ❌ để chốt thiết kế.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_ADS/OPS_AM | SYS_ADMIN |
|-----------|--------|--------|-------------|----------------|-----------|
| Xem trạng thái hard stop của TK/lệnh | ✅ | ✅ | ✅ | ✅ (TK của mình) | ❌ |
| Xác nhận "Đã khớp tiền" (Web + MFA TOTP) | ✅ (duy nhất) | ❌ | ❌ | ❌ | ❌ |
| Đính evidence sao kê/lệnh | ✅ | ❌ | ❌ | ❌ | ❌ |
| Thu hồi xác nhận khớp tiền | ✅ | ❌ (chỉ xem + nhắc quy trình) | ❌ | ❌ | ❌ |
| Override/bypass gate | ❌ | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin) |
| Xem audit log xác nhận/thu hồi | ✅ | ✅ | ✅ | ❌ | ❌ (việc xem cũng bị log) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Tiền về không khớp lệnh nào → lệnh không tồn tại để xác nhận; dòng sao kê treo ở hàng đợi "chờ đối chiếu" (FEAT-ERP-WALLET-001) — gate không mở theo bất kỳ cách nào cho đến khi có lệnh khớp đúng.
- Khách chuyển thiếu/ thừa so với lệnh → không xác nhận; FIN_L1 xử lý theo 2 hướng: xin khách hoàn tác/bổ sung, hoặc điều chỉnh qua dual approval (FEAT-ERP-WALLET-003) — không "khớp gần đúng".
- Xác nhận sai bị phát hiện sau khi TK đã cấp phát và chi tiêu → thu hồi xác nhận: TK tự "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL; xử lý thiệt hại phát sinh theo quy trình discrepancy/hoàn tiền.
- Khẩn ngoài giờ (nền tảng sắp khóa TK): luồng vẫn đúng — lệnh tạo trước, FIN_L1 xác nhận trên Web khi đủ evidence (có thể từ nhà qua Web), chỉ nhanh hơn chứ không bỏ bước.
- MFA TOTP lỗi/thiết bị mất của FIN_L1: khôi phục MFA theo quy trình quản trị truy cập — không có xác nhận "vượt MFA" tạm thời.
- TK nạp bằng USD nhưng hợp đồng tính theo VND: khớp trên đúng tiền tệ lệnh (USD); quy đổi hiển thị tham khảo theo snapshot, không dùng để quyết định khớp.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Xác nhận khớp tiền gắn lệnh nạp (FundMatchConfirmation) và hệ quả trên TKQC (AdAccount hold-state của REQ-OPS-002).*

**Entity:** FundMatchConfirmation (per lệnh nạp)

**Sơ đồ trạng thái:**
```
[CHỜ KHỚP] ──(FIN_L1 xác nhận: MFA + evidence + khớp số)──► [ĐÃ KHỚP TIỀN] ──(gate mở: cấp phát TKQC)──► [TK HOẠT ĐỘNG]
     ▲                                                            │
     │                                                            │ (FIN_L1 thu hồi + lý do)
     └────────────────────────────────────────────────────────────┴──► [ĐÃ THU HỒI] ──► TK tự về [TẠM DỪNG CHI TIÊU]
                                                                                        + khóa lệnh nạp mới + alert TL
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CHỜ KHỚP` | Xác nhận khớp | `ĐÃ KHỚP TIỀN` | FIN_L1 (duy nhất, trên Web) | MFA TOTP pass; evidence đính kèm; số khớp lệnh; người chuyển trùng tên pháp nhân KYC; không AML hold |
| `ĐÃ KHỚP TIỀN` | Mở gate cấp phát | TKQC được cấp phát | Hệ thống (CORE gate) | Tự động theo trạng thái; không cần hành động thêm |
| `ĐÃ KHỚP TIỀN` | Thu hồi | `ĐÃ THU HỒI` | FIN_L1 | Lý do bắt buộc; hệ quả tự động: TK tạm dừng chi tiêu + khóa nạp mới + alert TL |
| `CHỜ KHỚP` | Yêu cầu mở khóa thủ công | `CHỜ KHỚP` (bất biến) | Không ai | Request bị từ chối + audit log bất biến |

**Quy tắc:**
- `ĐÃ THU HỒI` quay lại `CHỜ KHỚP` thông qua lệnh nạp/làm rõ mới — không quay trạng thái trực tiếp trên cùng evidence sai.
- Không tồn tại trạng thái "chờ duyệt/khách hứa chuyển" trong máy trạng thái — cố ý bỏ để triệt tiêu mọi đường lách.
- Mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, evidence nào).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| FundMatchConfirmation | `topupTransactionId`, `state`, `confirmedBy`, `confirmedAt`, `mfaVerified`, `evidenceFileIds[]`, `revokeReason` | FK → WalletTransaction (lệnh nạp) | 1-1 với lệnh nạp; append-only kèm reversal khi thu hồi |
| EvidenceFile | `fileId`, `type` (BANK_STATEMENT/TOPUP_ORDER), `hash` | FK → FundMatchConfirmation | Lưu WORM (REQ-FIN-012) |
| AdAccountGateState | `adAccountId`, `spendingPaused`, `topupLocked`, `hardStopOpen` | FK → AdAccount | Do CORE cập nhật tự động |
| GateAuditEntry | `actor`, `action` (CONFIRM/REVOKE/BYPASS_ATTEMPT), `timestamp`, `reason` | FK → FundMatchConfirmation | Ghi cả nỗ lực bypass |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xác nhận hợp lệ | Lệnh nạp khớp sao kê, evidence đủ, FIN_L1 qua MFA | FIN_L1 bấm xác nhận | Trạng thái `ĐÃ KHỚP TIỀN`; gate cấp phát mở; audit ghi đủ | [ ] |
| SC-002: Thiếu evidence | Lệnh khớp số nhưng chưa đính sao kê | Nút xác nhận disabled | Không xác nhận được; hiển thị thiếu evidence cụ thể | [ ] |
| SC-003: Nỗ lực bypass | BOD_CEO/SYS_ADMIN gọi API yêu cầu mở khóa | Request gửi đi | Từ chối cứng + ghi `BYPASS_ATTEMPT` vào audit log bất biến | [ ] |
| SC-004: Lý do không có giá trị | Khách nhắn "hứa chuyển chiều nay" | Cố chuyển lệnh sang trạng thái khác | Máy trạng thái không có trạng thái đích — từ chối, gate giữ khóa | [ ] |
| SC-005: Thu hồi xác nhận sai | Xác nhận bị phát hiện khớp nhầm | FIN_L1 thu hồi kèm lý do | TKQC tự "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL — cả 3 hệ quả tự chạy | [ ] |
| SC-006: Mobile không có action | FIN_L1 mở counterpart mobile | Xem lệnh | Chỉ thấy trạng thái/alert; không có nút xác nhận — endpoint xác nhận trả lỗi từ mobile | [ ] |

> **Liên kết:** SC-001/SC-002 → REQ-FIN-006 (BR-H03/H05); SC-003/SC-004 → REQ-FIN-006 + REQ-OPS-002 (BR-H04); SC-005 → REQ-FIN-006 (BR-H06); SC-006 → REQ-FIN-006 (BR-H05) trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (fund match, gate state, gate audit) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (fund-match, gate-state) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-006: CORE, MOBILE-INTERNAL; cross REQ-OPS-002 → MOD-ADACCOUNT-CC) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (màn xác nhận khớp tiền, trạng thái gate) |
| Bản touchpoint khác | FEAT cho SYS-CORE-BACKEND / SYS-MOBILE-INTERNAL cùng REQ (lane riêng); góc OPS tại lane MOD-ADACCOUNT-CC |
