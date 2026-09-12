# Tính Năng: Financial Hard Stop "đã khớp tiền" FIN_L1

> **Dựa trên:** REQ-FIN-006 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-005-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-006 (REQ xuất hiện ở 3 systems). Counterparts: SYS-BCERP-WEB (nơi FIN_L1 xác nhận khớp tiền với MFA TOTP), SYS-MOBILE-INTERNAL (chỉ alert/xem — không xác nhận). Touchpoint Core Backend là **headless API/domain service**: enforcement **trong code** (workflow engine) — không nút override, không route bypass ở bất kỳ tầng nào. Cross-dependency: REQ-OPS-002 — Financial Hard Stop: FIN là nguồn xác nhận, OPS là điểm chặn vận hành (DR handoff: chặn cứng ở cả tầng API của CORE lẫn UI của WEB).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-005 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-006 (cross-dependency: REQ-OPS-002) |
| Người dùng liên quan | FIN_L1 (xác nhận/thu hồi), FIN_L2, BOD_CFO_CTO (giám sát, không bypass), OPS_AM/OPS_ADS (gặp gate khi cấp phát — chi tiết góc OPS tại bản REQ-OPS-002) |
| Độ ưu tiên | Cao (HIGH · GĐ1/MVP — trụ cột số 1 của FINANCE) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (vòng lệnh nạp 5 bước — trạng thái "Đã khớp tiền" sinh từ đây) |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); điểm phối hợp liên phòng đã xác định: gate Hard Stop nằm trong vòng đời cấp phát TKQC do OPS vận hành — FIN nắm quyền xác nhận; mobile chủ ý không có nút xác nhận để loại nguy cơ bypass |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thực thi trụ cột số 1 của FINANCE trên Core Backend: **không bao giờ cấp phát TKQC/bật chi tiêu khi tiền của khách chưa về tài khoản BC và chưa khớp số với lệnh nạp**. TKQC chỉ được cấp phát khi FIN_L1 xác nhận "Đã khớp tiền" trên hệ thống với MFA TOTP; hard stop được thực thi trong code của workflow engine — không có nút override, không có vai nào bypass, kể cả CEO/Super Admin. Đây là điểm cắt FIN → OPS trong luồng tiền giữ hộ: FIN bảo đảm "tiền thật đã về", OPS mới được mở khoá vận hành.

**Phạm vi:**
- Bao gồm: gate "Cấp phát TKQC" trong workflow engine — chỉ cho phép action khi trạng thái khớp tiền của lệnh nạp tương ứng = "Đã khớp tiền"; xác nhận khớp tiền bắt buộc gắn evidence (sao kê ngân hàng/lệnh nạp) + timestamp; xác thực MFA TOTP bắt buộc ở tầng service cho API xác nhận; từ chối mọi lý do "chờ duyệt"/"khách hứa chuyển"/"đang chuyển" — không có giá trị mở khóa; ghi audit log bất biến cho mọi yêu cầu mở khóa thủ công bị từ chối; thu hồi xác nhận sai → tự chuyển TKQC về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL; làm việc với trạng thái ví per-khách multi-currency của FEAT-CORE-WALLET-001 (không khớp chéo currency).
- Không bao gồm: màn hình xác nhận trên WEB và luồng đề xuất nạp của OPS (SYS-BCERP-WEB — REQ-OPS-002); registry TKQC và naming/UTM khi cấp phát (module Quản lý TKQC — REQ-OPS-001); push alert MOBILE (SYS-MOBILE-INTERNAL chỉ nhận thông tin); cảnh báo số dư sau cấp phát (FEAT-CORE-WALLET-002/007).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xác nhận "Đã khớp tiền" trên hệ thống với MFA TOTP, đính evidence (sao kê + lệnh nạp) và timestamp | Bút chi trách nhiệm rõ ràng: ai xác nhận, trên căn cứ nào, lúc nào |
| 2 | FIN_L1 | Hệ thống tự chặn mọi yêu cầu mở khóa khi chưa khớp tiền, kể cả từ cấp cao nhất | Tôi không chịu áp lực "duyệt trước, tiền tới sau" — câu trả lời là của hệ thống, không phải của cá nhân |
| 3 | OPS_ADS/OPS_AM | Chỉ nhận được quyền cấp phát sau khi gate hard stop mở | Cam kết với khách chỉ bắt đầu khi BC đã chắc chắn có tiền — không rủi ro chi "tiền gió" |
| 4 | FIN_L2 / BOD_CFO_CTO | Xem mọi nỗ lực mở khóa thủ công bị từ chối (ai, khi nào, lý do gì) | Có bằng chứng giám sát kỷ luật tài chính, kể cả với người có thẩm quyền cao |
| 5 | FIN_L1 | Thu hồi xác nhận khi phát hiện khớp sai → TK tự chuyển "Tạm dừng chi tiêu", khóa lệnh nạp mới | Sửa sai nhanh trước khi thiệt hại lan rộng; hệ thống tự hành động không phụ thuộc người |
| 6 | Hệ thống (Core service) | Từ chối mọi lý do không phải "tiền đã về + khớp số" ("khách hứa chuyển", "đang chuyển", "sếp đã OK") | Chuẩn khớp tiền là khách quan và giống nhau cho mọi khách, mọi thời điểm |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; đây là gate GĐ1, không có exception.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-H01 | Nền tảng: trạng thái "Đã khớp tiền" sinh từ vòng lệnh nạp chuẩn 5 bước của FEAT-CORE-WALLET-001 — tiền về tài khoản BC **và** khớp số với lệnh nạp; lệnh nạp thao tác trên ví per-khách multi-currency (USD/VND không gộp quy đổi), snapshot fee %/tỷ giá tại thời điểm giao dịch; approval SINGLE/DUAL theo công tắc hệ thống | Gate không đọc được trạng thái "Đã khớp tiền" từ lệnh hợp lệ → mặc định chặn (fail-closed), không mở theo suy đoán |
| BR-H02 | **Hard Stop thực thi trong code** — CORE workflow engine chỉ cho phép action "Cấp phát TKQC" khi trạng thái khớp tiền của lệnh nạp tương ứng = "Đã khớp tiền"; không có nút override, không route bypass; không tồn tại trạng thái trung gian "chờ duyệt có điều kiện" (BR-FIN-302; BR-OPS-2.1) | Mọi đường API mở gate không qua trạng thái khớp tiền bị từ chối `HARD_STOP_NOT_RELEASED`; code review bắt buộc kiểm chứng không có branch bypass |
| BR-H03 | **Không vai nào bypass — kể cả CEO/Super Admin**: mọi yêu cầu mở khóa thủ công khi chưa khớp tiền bị từ chối và ghi audit log bất biến (ai, khi nào, yêu cầu gì); UI (WEB) và API (CORE) chặn song song | Nỗ lực bằng vai cao nhất vẫn bị chặn; log nỗ lực xuất hiện trong báo cáo giám sát cho BOD |
| BR-H04 | Xác nhận "Đã khớp tiền" chỉ bởi FIN_L1, chỉ trên **WEB với MFA TOTP**; MOBILE chỉ alert/xem — không cho phép xác nhận khớp tiền; mỗi xác nhận bắt buộc gắn evidence (sao kê ngân hàng/lệnh nạp) + timestamp (BR-FIN-302) | API xác nhận thiếu MFA hoặc thiếu evidence bị từ chối; API xác nhận gọi từ kênh MOBILE bị từ chối `CHANNEL_NOT_ALLOWED` |
| BR-H05 | Không chấp nhận "chờ duyệt"/"khách hứa chuyển"/"đang chuyển"/"sếp đã OK" — các lý do này không có giá trị mở khóa; khẩn ngoài giờ vẫn chỉ mở khi đã khớp tiền — xử lý nhanh hơn, không bỏ bước (BR-OPS-2.1: **không có exception**) | Mọi đoạn text lý do không thuộc nhóm evidence chuẩn bị xử lý như "chưa khớp" — gate giữ chặn |
| BR-H06 | Thu hồi xác nhận sai: FIN_L1 thu hồi → CORE tự chuyển TKQC về "Tạm dừng chi tiêu", khóa lệnh nạp mới, bắn alert TL; mọi chuyển trạng thái vòng đời ghi audit log bất biến (BR-FIN-302; BR-OPS-2.2) | Sau thu hồi, mọi action cấp phát/chi tiêu trên TK bị chặn tức thì; mở lại chỉ khi có lệnh nạp đạt "Đã khớp tiền" mới |
| BR-H07 | Khớp tiền theo đúng currency của lệnh và ví: không khớp chéo USD↔VND, không khớp từ ví khách khác, không dùng số dư tổng hợp quy đổi; snapshot tỷ giá đã khóa tại thời điểm ghi nhận | Trạng thái khớp gắn đúng cặp (lệnh, ví, currency); dữ liệu chéo currency không được chấp nhận làm evidence |
| BR-H08 | Dual approval (SINGLE/DUAL — FIN_L1 → FIN_L2 tuần tự) vẫn áp dụng cho các giao dịch rủi ro cao liên quan (điều chỉnh số dư/đổi tỷ giá/hoàn tiền) trước hoặc sau khớp tiền (FEAT-CORE-WALLET-003); khớp tiền KHÔNG thay thế dual approval | Lệnh điều chỉnh chưa đủ chữ ký → không được tính vào số khớp; gate đọc số sau khi mọi giao dịch liên quan hoàn tất |
| BR-H09 | Đối trừ 3 số (FEAT-CORE-WALLET-004) dùng số khớp tiền làm vế chuẩn; dung sai nạp = 0/dòng (ngày) — số khớp "gần đúng" không tồn tại; chốt & khóa kỳ ghi nhận trạng thái khớp tiền như một phần số liệu kỳ | Phát hiện sai khác sau khớp → thu hồi theo BR-H06 + ticket discrepancy theo FEAT-004 |
| BR-H10 | AML T1–T6 + UBO ≥25% (mặc định theo DI-001): giao dịch nạp nghi vấn bị khóa mềm (hold) thì **chưa được tính "Đã khớp tiền"** cho đến khi kết luận; hoàn tiền đúng nguồn áp dụng khi xử lý hậu thu hồi; Rebate mặc định TẮT — không liên quan gate (FEAT-CORE-WALLET-006; CMS §3.10) | Gate đọc trạng thái hold từ AML engine; hold còn hiệu lực → gate giữ chặn |
| BR-H11 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation; khách không thấy trạng thái hard stop nội bộ, evidence, audit log; hiển thị ở mức "lệnh đã ghi nhận" qua view lọc | Truy vấn Portal ép điều kiện tenant; dữ liệu gate không nằm trong view khách |

**Giả định chờ xác nhận:** mối quan hệ 1 lệnh nạp ↔ nhiều TKQC (nạp gộp chia nhiều account) cần cấu trúc lệnh con — nguồn CMS mô tả 1 lệnh/1 TKQC; nếu nghiệp vụ có nạp gộp, mỗi phần chia phải đạt "Đã khớp tiền" riêng trước khi gate mở cho TK tương ứng (assumption thiết kế, trình stakeholder xác nhận tại Phase 3). 11 KXN còn mở (KXN-6/7/9/15–22) thuộc domain CRM/lifecycle — không tác động rule hard stop.

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_AM/OPS_ADS | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|----------------|-----------|-------------------|
| Xác nhận "Đã khớp tiền" (WEB + MFA TOTP + evidence) | ✅ (duy nhất) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thu hồi xác nhận khớp tiền | ✅ | ✅ (khi phát hiện sai) | ❌ | ❌ | ❌ | ❌ |
| Xem trạng thái hard stop theo TK/lệnh | ✅ | ✅ | ✅ | ✅ (TK mình gặp gate) | ❌ | ❌ (chỉ thấy "lệnh đã ghi nhận") |
| Yêu cầu mở khóa khi chưa khớp tiền | ❌ | ❌ | ❌ (bị từ chối) | ❌ | ❌ (bị từ chối) | ❌ |
| Override/bypass gate | ❌ | ❌ | ❌ (kể cả CEO) | ❌ | ❌ (kể cả Super Admin) | ❌ — không tồn tại quyền này |
| Hành động "Cấp phát TKQC" sau khi gate mở | ❌ | ❌ | ❌ | ✅ (OPS — theo REQ-OPS-001/002) | ❌ | ❌ |
| Xem audit log nỗ lực mở khóa bị từ chối | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình MFA/evidence requirement cho gate | ❌ | ❌ | ❌ | ❌ | ✅ (thay đổi cần BOD phê duyệt) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Khẩn cấp ngoài giờ:** vẫn chỉ mở khi đã khớp tiền — FIN_L1 xác nhận qua WEB (MFA) từ xa; xử lý nhanh hơn nhưng không bỏ bước; MOBILE không được dùng làm kênh xác nhận thay thế.
- **Nạp gộp nhiều TKQC (assumption thiết kế):** mỗi phần chia của lệnh đạt "Đã khớp tiền" riêng; gate mở theo từng TK có phần đã khớp — phần chưa khớp vẫn chặn TK tương ứng.
- **Xác nhận nhầm sang lệnh khác:** thu hồi theo BR-H06 — TK tự pause, khóa nạp mới, alert TL; xác nhận lại trên lệnh đúng.
- **Khách trả sai số nhỏ (lệch làm tròn):** dung sai nạp = 0/dòng — lệch dù nhỏ phải xử lý qua lệnh điều chỉnh dual approval (FEAT-003) hoặc khách chuyển bù; không có "khớp gần đúng".
- **TKQC bị platform khóa ngay sau cấp phát:** hard stop không quay lại — xử lý theo ReplacementRequest (module Quản lý TKQC); số dư chuyển theo quy trình thay thế, hard stop chỉ áp cho lệnh nạp mới.
- **Kiểm toán truy vết:** mọi xác nhận/thu hồi/nỗ lực mở khóa đều truy xuất theo khách/TKQC/lệnh với hash-chain audit log (REQ-FIN-012); việc xem log cũng bị meta-log.
- **Nghi vấn AML sau khi đã khớp tiền:** giao dịch nạp bị hold/điều tra (FEAT-006) → khuyến nghị FIN_L1 thu hồi xác nhận để TK tự pause trong khi điều tra — gate giữ chặn đến khi kết luận.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Trạng thái khớp tiền của lệnh nạp (MatchStatus) — đầu vào duy nhất của gate hard stop.

**Sơ đồ trạng thái:**
```
[CHỜ ĐỐI CHIẾU] ──(tiền về + khớp số + tên trùng KYC + evidence + MFA)──► [ĐÃ KHỚP TIỀN] ──(gate mở)──► CẤP PHÁT ĐƯỢC
       ▲  ▲                                                                │
       │  │ (lệnh điều chỉnh/khớp lại sau khiếu nại)                        │ (thu hồi — FIN_L1 phát hiện sai)
       │  └────────────────────────────────────────────────────────────────┤
       │                                                                   ▼
       └────────────────────────────────────────────────────── [KHỚP TIỀN BỊ THU HỒI]
                                            (TKQC tự "Tạm dừng chi tiêu" + khóa lệnh nạp mới + alert TL)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CHỜ ĐỐI CHIẾU` | Xác nhận khớp | `ĐÃ KHỚP TIỀN` | FIN_L1 (duy nhất) | WEB + MFA TOTP; evidence (sao kê/lệnh) + timestamp; tên người chuyển trùng pháp nhân KYC |
| `ĐÃ KHỚP TIỀN` | Thu hồi xác nhận sai | `KHỚP TIỀN BỊ THU HỒI` | FIN_L1 (FIN_L2 khi phát hiện sai) | Lý do bắt buộc; TKQC tự pause + khóa nạp mới + alert TL (tự động) |
| `KHỚP TIỀN BỊ THU HỒI` | Khớp lại trên lệnh đúng/điều chỉnh xong | `ĐÃ KHỚP TIỀN` | FIN_L1 | Chứng từ điều chỉnh đã duyệt (FEAT-003); evidence mới |
| Bất kỳ | Yêu cầu mở khóa khi chưa `ĐÃ KHỚP TIỀN` | (không đổi — từ chối) | Không ai (kể cả CEO/Super Admin) | Từ chối + audit log bất biến |

**Quy tắc:**
- Gate hard stop chỉ đọc đúng một điều kiện: `MatchStatus = ĐÃ KHỚP TIỀN` — không có điều kiện phụ ("khách VIP", "hợp đồng năm", "đã hứa").
- Thu hồi là hành động có hậu quả tự động (pause + khóa nạp + alert); không có chế độ "thu hồi im lặng".
- Trạng thái này append-only theo nghĩa lịch sử: mỗi chuyển đổi ghi bản ghi mới, không ghi đè bản ghi cũ.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `RechargeRequest.match_status` | `match_status` (CHỜ ĐỐI CHIẾU/ĐÃ KHỚP TIỀN/THU HỒI), `matched_by`, `matched_at` | Trên entity lệnh nạp FEAT-001 | Đầu vào duy nhất của gate |
| `MatchEvidence` | `recharge_request_id`, `type` (SAO KÊ/LỆNH), `file_ref`, `uploaded_by` | FK → `recharge_requests.id` | Bắt buộc khi xác nhận; không xóa |
| `HardStopGate` | `ad_account_id`, `contract_id`, `released` (bool), `released_from_match_id` | FK → `ad_accounts.id`, `recharge_requests.id` | Đọc bởi workflow engine; fail-closed |
| `MfaVerification` | `user_id`, `channel` (WEB only), `method` (TOTP), `verified_at`, `scope` (MATCH_CONFIRM) | FK → `users.id` | Bắt buộc trước confirm; mobile bị chặn scope này |
| `OverrideAttemptLog` | `requester`, `role`, `requested_at`, `target_gate`, `result` (TỪ CHỐI), `reason_text` | Append-only | Mọi nỗ lực bypass; hash-chain; báo cáo BOD |
| `AccountLifecycleLog` | `ad_account_id`, `transition` (PAUSE/RESUME), `trigger` (THU HỒI KHỚP TIỀN), `actor` (SYSTEM) | FK → `ad_accounts.id` | Thu hồi → tự pause, không phụ thuộc thao tác |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Gate chặn khi chưa khớp | Lệnh nạp `CHỜ ĐỐI CHIẾU` | OPS gọi API "Cấp phát TKQC" | Từ chối `HARD_STOP_NOT_RELEASED`; UI (WEB) khóa nút song song; log nỗ lực | [ ] |
| SC-002: Xác nhận đúng chuẩn | Tiền về khớp số, tên trùng KYC | FIN_L1 xác nhận trên WEB với MFA TOTP + evidence | Trạng thái → `ĐÃ KHỚP TIỀN`; gate mở; timestamp + evidence ghi đầy đủ | [ ] |
| SC-003: Thiếu evidence/MFA | FIN_L1 xác nhận nhưng chưa upload sao kê (hoặc chưa MFA) | Gọi API xác nhận | Từ chối; trạng thái giữ `CHỜ ĐỐI CHIẾU` | [ ] |
| SC-004: CEO/Super Admin không bypass | Tiền chưa về | BOD_CFO_CTO/SYS_ADMIN gọi API mở gate | Từ chối + audit log bất biến; không tồn tại endpoint bypass | [ ] |
| SC-005: Mobile không xác nhận | FIN_L1 trên MOBILE-INTERNAL | Gọi API xác nhận từ kênh mobile | Từ chối `CHANNEL_NOT_ALLOWED`; mobile chỉ alert/xem | [ ] |
| SC-006: Thu hồi → tự pause | Xác nhận bị phát hiện sai | FIN_L1 thu hồi | TKQC tự "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL; mọi bước có audit log | [ ] |
| SC-007: Khớp chéo currency bị chặn | Lệnh VND khớp nhưng ví USD của cùng khách | Thử xác nhận khớp từ số USD | Từ chối — khớp gắn đúng cặp lệnh/ví/currency | [ ] |
| SC-008: Hold AML giữ gate chặn | Giao dịch nạp bị AML hold (T2 đỏ) | Kiểm tra gate | Gate giữ chặn đến khi hold kết thúc bằng kết luận; không khớp tiền trong khi hold | [ ] |

> **Liên kết:** SC-001→006 map REQ-FIN-006 Mục 2 (A3, BR-FIN-302) + REQ-OPS-002 (BR-OPS-2.1/2.2); SC-007 map REQ-FIN-001 (multi-currency); SC-008 map REQ-FIN-010 (BR-FIN-404).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — MatchEvidence, HardStopGate, OverrideAttemptLog | `technical-specs/database-design.md` |
| API Endpoints — gate release, match confirm (MFA scope), thu hồi | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — REQ-OPS-002 (WEB chặn UI), module Quản lý TKQC (REQ-OPS-001), AML (FEAT-006) | `technical-specs/integration-map.md` |
| Màn hình UI (màn xác nhận khớp tiền thuộc SYS-BCERP-WEB) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
