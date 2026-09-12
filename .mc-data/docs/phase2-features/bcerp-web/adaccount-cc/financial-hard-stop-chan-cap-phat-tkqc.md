# Tính Năng: Financial Hard Stop chặn cấp phát TKQC

> **Dựa trên:** REQ-OPS-002 trong `phase1-business/departments/operations/operations.md` (Phần A, B.2)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Quản lý TKQC — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ADACC-003 |
| Module | MOD-ADACCOUNT-CC |
| Yêu cầu nghiệp vụ | REQ-OPS-002 — Financial Hard Stop chặn cấp phát TKQC (HIGH, MVP) |
| Người dùng liên quan | OPS_ADS, OPS_AM (gặp gate), OPS_PLAN (TL — nhận alert), OPS_CONT, OPS_DES, OPS_EDIT; FIN_L1 phối hợp xác nhận (thuộc bản REQ-FIN-006 — MOD-WALLET-RECON) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng kiểm soát dòng tiền, áp dụng từ giao dịch tiền đầu tiên) |
| Phụ thuộc | Cross-dependency REQ-FIN-006 — Financial Hard Stop: tín hiệu "đã khớp tiền" từ FIN_L1 (bản WEB của REQ-FIN-006 thuộc MOD-WALLET-RECON); phối hợp trong module với FEAT-ERP-ADACC-001 (KYC gate) và FEAT-ERP-ADACC-002 (vòng đời registry) |
| Ghi chú Expert (A7) | Operations.md Mục A7: chưa có đánh giá chính thức (chờ review); REQ-OPS-002 được tách khỏi REQ-OPS-001 để traceability độc lập control phối hợp FIN_L1 — không có bản mobile/portal vì không tồn tại nút duyệt để bypass |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Financial Hard Stop là cơ chế chặn cứng không cho cấp phát hay bật chi tiêu trên bất kỳ TKQC nào khi FIN_L1 chưa xác nhận **"Đã khớp tiền"** cho lệnh nạp tương ứng — bảo vệ nguyên tắc "khách nạp trước 100%" của mô hình trung gian TKQC và loại bỏ rủi ro chạy nợ/quà cho khách. Trên web nội bộ BCERP, tính năng bao gồm luồng đề xuất nạp của OPS (input duy nhất FIN chấp nhận đối chiếu), hiển thị trạng thái khóa của từng TKQC, và ghi nhận mọi yêu cầu mở khóa thủ công bị từ chối; bản thân engine chặn thực thi ở tầng API của core (nguồn sự thật là FIN, OPS là điểm tiêu thụ).

**Phạm vi:**
- Bao gồm: form tạo lệnh đề xuất nạp trên web (khách/TKQC/số tiền/tỷ giá/căn cứ) — bắt buộc qua lệnh hệ thống, cấm xác nhận miệng; danh sách lệnh đang chờ khớp tiền kèm trạng thái từng lệnh.
- Bao gồm: hiển thị trạng thái Financial Hard Stop của từng TKQC trong registry (đang khóa / đã mở) với lý do và căn cứ khớp tiền; trạng thái machine-state đọc từ core, web không tự tính.
- Bao gồm: màn hình phản hồi khi gate chặn — thông báo rõ lý do (chưa khớp tiền / KYC chưa Verified), hướng dẫn tạo lệnh nạp và liên hệ FIN_L1; mọi thao tác "mở khóa thủ công" từ phía OPS bị từ chối và ghi audit log bất biến.
- Bao gồm: hiển thị trạng thái "Tạm dừng chi tiêu" tức thì khi FIN_L1 thu hồi xác nhận khớp tiền, kèm alert cho OPS_PLAN (TL) và owner.
- Bao gồm: luồng khẩn cấp ngoài giờ — vẫn qua lệnh hệ thống, chỉ xử lý nhanh hơn (nhắc FIN_L1 qua kênh on-call), không bỏ bước.
- Không bao gồm: màn xác nhận "Đã khớp tiền" với MFA và thu hồi xác nhận của FIN_L1 — thuộc bản WEB của REQ-FIN-006 (MOD-WALLET-RECON); tính năng này tiêu thụ tín hiệu đó.
- Không bao gồm: đối trừ 3 số, ghi nhận ví giữ hộ, snapshot tỷ giá (REQ-FIN-001/004) và cảnh báo số dư 3 mức + SLA đỏ (REQ-OPS-003).
- Không bao gồm: KYC gate (FEAT-ERP-ADACC-001) — hai gate độc lập cùng phải thỏa trước khi registry chuyển "Cấp phát"; tính năng chỉ phối hợp hiển thị kết quả cả hai.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive (Next.js): OPS tạo lệnh và theo dõi gate; mọi trạng thái khóa/mở là machine-state do core quyết định. REQ-OPS-002 chủ ý chỉ có bản CORE + WEB — không có bản mobile/portal để không tồn tại nút duyệt nào có thể bypass (mobile chỉ nhận thông tin trạng thái, không có action).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Tạo lệnh đề xuất nạp trên hệ thống cho khách/TKQC cần cấp phát hoặc top-up | FIN_L1 có input chuẩn để đối chiếu sao kê, không đối chiếu theo tin nhắn Zalo/điện thoại |
| 2 | OPS_ADS | Thấy rõ trạng thái Hard Stop của từng TKQC (đang khóa — chưa khớp tiền) ngay trên màn Command Center | Biết TK nào chưa được bật chi tiêu mà không phải hỏi từng người |
| 3 | OPS_ADS | Nhận thông báo chặn kèm lý do cụ thể khi cố bật chi tiêu trước khi khớp tiền | Hiểu mình cần chờ gì (khớp tiền, KYC) thay vì đoán lỗi hệ thống |
| 4 | OPS_AM | Xem danh sách lệnh nạp đang chờ khớp tiền theo khách mình phụ trách | Chủ động theo dõi tiến độ khớp tiền với FIN và báo khách đúng thời điểm |
| 5 | OPS_PLAN | Nhận alert khi FIN_L1 thu hồi xác nhận khớp tiền và TKQC tự chuyển "Tạm dừng chi tiêu" | Phối hợp xử lý ngay — liên hệ khách/kiểm tra bất thường trước khi campaign gián đoạn |
| 6 | OPS_ADS | Yêu cầu xử lý khẩn ngoài giờ cho lệnh nạp đã khớp tiền nhưng chưa được bật | Vẫn qua lệnh hệ thống có vết, FIN_L1 xử lý nhanh hơn nhưng không bỏ bước |
| 7 | OPS_CONT | Xem trạng thái khóa của TKQC gắn hồ sơ OADS mình đang theo | Không hẹn khách chạy campaign trên TK chưa đủ điều kiện |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đây là control đặc thù: engine chặn nằm ở service layer SYS-CORE-BACKEND; web là bề mặt tạo lệnh + hiển thị và KHÔNG được có logic nới lỏng gate. Nguồn: policy `quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.1; tham chiếu CMS Domain Model cho vòng đời cấp phát.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Chỉ cho phép cấp phát/bật chi tiêu khi FIN_L1 xác nhận **"Đã khớp tiền"** cho lệnh nạp tương ứng; nguồn sự thật là FIN (sao kê ngân hàng đối chiếu lệnh nạp), OPS là điểm tiêu thụ tín hiệu — web hiển thị theo, không tự suy diễn trạng thái. | Cố bật chi tiêu khi chưa khớp: core chặn ở tầng API; UI chặn trước để trải nghiệm rõ ràng nhưng UI không phải lớp enforcement |
| BR-002 | Chặn cứng trong code ở cả UI lẫn API; không nút override, không trạng thái "chờ duyệt" — gate chỉ có 2 trạng thái machine: khóa/mở theo tín hiệu khớp tiền; không tồn tại trường cấu hình để tắt gate cho bất kỳ khách/TK/platform nào. | Mọi nhánh code "nếu khẩn cấp thì bỏ qua kiểm tra" bị cấm — code review và audit theo chuẩn này; phát hiện là lỗi P0 |
| BR-003 | "Khách hứa chuyển", "đang chuyển", "sếp đã OK" không có giá trị mở khóa; chỉ tín hiệu "Đã khớp tiền" do FIN_L1 ghi trên hệ thống (kèm evidence sao kê + timestamp, MFA — bản REQ-FIN-006) mới đổi trạng thái gate. | Ghi chú/chứng cứ ngoài hệ thống không được nạp vào quyết định; lệnh chưa khớp tiền không được hưởng bất kỳ ưu tiên nào |
| BR-004 | Mọi yêu cầu mở khóa thủ công bị từ chối và ghi audit log bất biến (ai yêu cầu, khi nào, lý do, ai từ chối — hệ thống tự từ chối); không vai nào bypass kể cả BOD_CEO, kể cả Super Admin. | Yêu cầu mở khóa ghi log và báo cáo định kỳ cho BOD; áp lực "mở tạm" là dữ liệu giám sát văn hóa tuân thủ |
| BR-005 | Khi FIN_L1 thu hồi xác nhận khớp tiền: core tự chuyển TKQC về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert OPS_PLAN (TL) và owner; web hiển thị trạng thái khóa tức thì (freshness theo sync, không chờ refresh tay). | Chi tiêu phát sinh sau thu hồi bị coi là vi phạm dòng tiền nghiêm trọng — trace qua audit log + dữ liệu platform |
| BR-006 | Đề xuất nạp chỉ qua lệnh hệ thống trên web: lệnh chứa khách/TKQC/số tiền/tỷ giá/căn cứ; cấm xác nhận miệng Zalo/điện thoại/email riêng — FIN từ chối đối chiếu lệnh miệng; cấm mượn chéo ví giữa khách (không dùng tiền khách khác đắp ví). | Lệnh miệng không tồn tại trong hệ thống đối chiếu; phát hiện đắp chéo ví là vi phạm P0 báo cáo BOD |
| BR-007 | SoD 4 vai dòng tiền: đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ (kế toán); SoD engine chặn 1 người giữ ≥2 vai trong 1 giao dịch. | Core block khi vai trùng; vi phạm log cho CFO rà định kỳ |
| BR-008 | Không có bản M-INT/PORTAL/M-PORTAL cho luồng duyệt Hard Stop — chủ ý thiết kế để không tồn tại kênh bypass; mobile nội bộ chỉ nhận alert thông tin trạng thái (không action), portal khách không tạo được lệnh. | Nếu phase sau muốn thêm kênh, phải giữ nguyên tắc "chỉ CORE + WEB có action" — thêm kênh có action là vi phạm kiến trúc control |
| BR-009 | Hard Stop và KYC gate là 2 điều kiện độc lập cùng phải thỏa trước khi registry chuyển "Khớp tiền → Cấp phát": khớp tiền mở Hard Stop (feature này), KYC = Verified mở KYC gate (FEAT-ERP-ADACC-001); thỏa một trong hai chưa đủ. | Thiếu một gate: chuyển trạng thái bị chặn; web hiển thị trạng thái cả hai gate để OPS biết chính xác còn thiếu gì |
| BR-010 | Khẩn cấp ngoài giờ: không có exception — chỉ xử lý nhanh hơn (nhắc FIN_L1 qua kênh on-call SLA 4h), lệnh vẫn tạo trên hệ thống và xác nhận khớp tiền vẫn bắt buộc trước khi gate mở. | Nghiệp vụ "chạy trước, mai bổ sung giấy tờ" bị từ chối; hệ thống không có luồng hậu nghiệm cho gate này |
| BR-011 | Mọi sự kiện gate (chặn, mở, thu hồi, yêu cầu mở khóa bị từ chối) ghi audit log bất biến hash-chain: ai, khi nào, trên TKQC nào, căn cứ (lệnh nạp, xác nhận FIN); dữ liệu phục vụ đối soát và kiểm tra chỉ tiêu "case cấp TKQC khi chưa khớp tiền = 0". | Audit log thiếu hoặc đứt hash-chain là sự cố hệ thống báo ngay CTO + BOD_CEO |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Nguyên tắc nền: không ai có quyền mở khóa thủ công — cột nào cũng ❌ cho hành động này; FIN_L1 xuất hiện chỉ để phân định ranh giới với bản REQ-FIN-006 (MOD-WALLET-RECON), không thuộc actors chính của lane.

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN | OPS_CONT / OPS_DES / OPS_EDIT | FIN_L1 | SYS_ADMIN |
|-----------|---------|--------|----------|------------------------------|--------|-----------|
| Tạo lệnh đề xuất nạp | ✅ | ✅ | ❌ | ❌ | ❌ (nhận lệnh để đối chiếu) | ❌ |
| Xem trạng thái Hard Stop theo TKQC | ✅ | ✅ | ✅ | ✅ (view-only) | ✅ | ❌ |
| Xem danh sách lệnh chờ khớp tiền | ✅ (khách phụ trách) | ✅ (khách phụ trách) | ✅ (toàn team) | ❌ | ✅ | ❌ |
| Xác nhận "Đã khớp tiền" (MFA) | ❌ | ❌ | ❌ | ❌ | ✅ (bản REQ-FIN-006 — MOD-WALLET-RECON) | ❌ |
| Thu hồi xác nhận khớp tiền | ❌ | ❌ | ❌ | ❌ | ✅ (bản REQ-FIN-006 — MOD-WALLET-RECON) | ❌ |
| Yêu cầu xử lý khẩn (lệnh đã khớp tiền) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Mở khóa thủ công gate | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (yêu cầu bị từ chối + audit log) |
| Cấu hình/tắt gate cho khách hoặc TK | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại cấu hình này) |
| Xem lịch sử gate chặn/từ chối mở khóa | ✅ (TK phụ trách) | ✅ | ✅ | ❌ | ✅ | ❌ |

SYS_ADMIN không có quyền nghiệp vụ và không có quyền cấu hình bypass — vai admin chỉ hỗ trợ vận hành hệ thống, mọi thao tác quản trị bị audit log. Hành động mở khóa không tồn tại ở mọi vai để code không có nhánh kiểm tra quyền mở khóa (chính là điểm "chặn cứng trong code").

---

## 5. Trường Hợp Đặc Biệt

- Khách nạp dư so với lệnh: FIN_L1 khớp theo số lệnh, phần dư ghi nhận theo quy trình ví (MOD-WALLET-RECON) — gate mở đúng phần tương ứng lệnh; web hiển thị số khớp và số dư chờ xử lý, OPS không tự quyết định áp phần dư vào lệnh khác.
- Một lệnh nạp gộp cho nhiều TKQC của cùng khách: FIN_L1 khớp và phân bổ theo chi tiết lệnh; từng TKQC có trạng thái gate riêng theo phần đã khớp — không mở gate toàn bộ khi chỉ một phần được khớp.
- TK die có refund từ platform: hoàn về ghi có theo giao dịch gốc (FIN_L1 khớp tiền hoàn) — đây là dòng hoàn, không phải điều kiện mở gate cấp phát mới; TK thay thế (ReplacementRequest) vẫn phải qua Hard Stop khớp tiền riêng trước khi bật chi tiêu.
- Thu hồi khớp tiền đúng lúc campaign đang chạy: core tự pause chi tiêu; dữ liệu chi tiêu phát sinh trong khoảng đóng mở (nếu có) được đối soát riêng và báo cáo BOD — không tự điều chỉnh số.
- Khách quen yêu cầu "chạy trước evening nạp sau": bị từ chối theo thiết kế; OPS_AM dùng trạng thái gate trên web làm căn cứ giải thích khách — hệ thống cung cấp view trạng thái để giảm áp lực đàm phán.
- Lỗi kỹ thuật làm GW hiển thị sai trạng thái platform (TK thực tế đã hết tiền dù gate đang mở): gate Hard Stop không thay thế cảnh báo số dư — bản phối hợp với REQ-OPS-003 (cảnh báo 3 mức) xử lý rủi ro số dư; hai cơ chế độc lập, không thay nhau.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Trạng thái Financial Hard Stop gắn với cặp (TKQC, lệnh nạp) — machine-state do core quyết định từ tín hiệu khớp tiền của FIN_L1; web chỉ gửi hành động hợp lệ và hiển thị.

**Sơ đồ trạng thái:**
```
Lệnh đề xuất nạp:
[CREATED] ──(gửi)──► [WAITING_MATCH] ──(FIN_L1 xác nhận + MFA)──► [MATCHED]
                          │                                          │
                          │ (hủy/điều chỉnh lệnh mới)                │ (FIN_L1 thu hồi)
                          ▼                                          ▼
                      [CANCELLED]                                [REVOKED]

Trạng thái Hard Stop của TKQC:
[LOCKED] ──(xác nhận khớp tiền cho lệnh tương ứng)──► [OPEN] ──(thu hồi xác nhận)──► [LOCKED + SPEND_PAUSED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CREATED` | Gửi lệnh cho FIN | `WAITING_MATCH` | OPS_ADS/OPS_AM | Lệnh đủ khách/TKQC/số tiền/tỷ giá/căn cứ |
| `WAITING_MATCH` | Hủy lệnh | `CANCELLED` | Người tạo + OPS_PLAN | Lý do bắt buộc; lệnh đã gửi không sửa mà hủy + tạo mới |
| `WAITING_MATCH` | Xác nhận khớp tiền | `MATCHED` | FIN_L1 (MFA — bản REQ-FIN-006) | Sao kê khớp số + tên trùng KYC; evidence + timestamp |
| `MATCHED` | Mở gate cấp phát | TKQC `Khớp tiền → Cấp phát` | Hệ thống | Cả 2 gate thỏa (khớp tiền + KYC Verified) |
| `MATCHED` | Thu hồi xác nhận | `REVOKED` | FIN_L1 (bản REQ-FIN-006) | Lý do văn bản bắt buộc |
| `REVOKED` | Áp dụng thu hồi | TKQC `LOCKED + SPEND_PAUSED` | Hệ thống | Tự pause chi tiêu, khóa nạp mới, alert OPS_PLAN + owner |
| `LOCKED` | Yêu cầu mở khóa thủ công | `LOCKED` (không đổi) | Bất kỳ vai nào | Không có đường chuyển — yêu cầu bị từ chối + audit log bất biến |

**Quy tắc:**
- `OPEN` không phải trạng thái "duyệt xong" mà là trạng thái phản ánh tín hiệu FIN — không nút nào trên web đặt nó trực tiếp; duy nhất luồng xác nhận khớp tiền (REQ-FIN-006) thay đổi được.
- `LOCKED + SPEND_PAUSED` không tự mở lại — phải có xác nhận khớp tiền mới cho lệnh nạp tiếp theo.
- Không tồn tại trạng thái trung gian "chờ duyệt mở khóa" — mọi yêu cầu loại này bị hệ thống từ chối ngay tại API.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| TopupProposal | `id`, `customer_id`, `ad_account_id`, `amount`, `fx_rate`, `basis`, `status`, `created_by`, `created_at` | FK → Customer, AdAccount | Lệnh đề xuất nạp — input duy nhất FIN chấp nhận |
| MatchConfirmation | `topup_proposal_id`, `confirmed_by`, `confirmed_at`, `mfa_verified`, `evidence_ref`, `revoked_at`, `revoke_reason` | FK → `topup_proposal.id` | Tín hiệu "đã khớp tiền" — quản lý bởi bản REQ-FIN-006 |
| HardStopState | `ad_account_id`, `state`, `last_changed_at`, `basis_proposal_id` | FK → AdAccount | Machine-state gate: LOCKED / OPEN / LOCKED+SPEND_PAUSED |
| OverrideDenialLog | `id`, `requested_by`, `requested_at`, `ad_account_id`, `denied_reason` | FK → AdAccount | Append-only — mọi yêu cầu mở khóa bị từ chối |
| GateAuditLog | `ad_account_id`, `event`, `actor_id`, `timestamp`, `old_state`, `new_state`, `reason_code`, `prev_hash` | FK → AdAccount | Hash-chain bất biến; job kiểm tra toàn vẹn hằng ngày |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn cấp phát chưa khớp tiền | TKQC ở "Khớp tiền", chưa có xác nhận FIN_L1 | OPS_ADS bấm bật chi tiêu | UI chặn kèm lý do; gọi thẳng API vẫn bị core từ chối — không nhánh bỏ qua | [ ] |
| SC-002: Hứa chuyển không mở khóa | Khách gửi ảnh chụp chuyển khoản qua Zalo | OPS cố ghi chú làm căn cứ mở | Hệ thống không chấp nhận — chỉ tín hiệu MatchConfirmation của FIN_L1 đổi trạng thái gate | [ ] |
| SC-003: Yêu cầu mở khóa bị từ chối + log | TKQC đang LOCKED | Bất kỳ vai nào (kể cả SYS_ADMIN) gửi yêu cầu mở khóa | Yêu cầu bị từ chối ngay; OverrideDenialLog ghi ai/khi nào/lý do; không đổi trạng thái | [ ] |
| SC-004: Thu hồi khớp tiền → tự pause | TKQC đang chi tiêu, FIN_L1 thu hồi xác nhận | Core xử lý thu hồi | TKQC chuyển LOCKED + SPEND_PAUSED, khóa nạp mới, alert OPS_PLAN + owner có timestamp | [ ] |
| SC-005: Khớp tiền mở gate | Lệnh nạp MATCHED, KYC khách = Verified | Hệ thống đánh giá gate | TKQC chuyển "Cấp phát", owner nhận quyền; audit log ghi căn cứ lệnh nạp | [ ] |
| SC-006: Thiếu KYC vẫn chặn | Lệnh nạp MATCHED nhưng KYC ≠ Verified | Gate đánh giá | Không chuyển "Cấp phát"; web hiển thị cả 2 trạng thái gate và phần còn thiếu | [ ] |
| SC-007: SoD chặn vai trùng | Người cùng tài khoản vừa tạo lệnh nạp | Cố xác nhận khớp tiền cho lệnh đó | Core block với lý do tách vai; vi phạm log cho CFO | [ ] |
| SC-008: Khẩn ngoài giờ không bỏ bước | 22h đêm, khách cần bật gấp, lệnh đã khớp tiền | OPS_ADS yêu cầu xử lý khẩn | Yêu cầu ghi nhận + nhắc FIN_L1 on-call; gate vẫn chỉ mở sau xác nhận khớp tiền trên hệ thống | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-002 (Mục 2 — gate chặn cấp phát, không override, thu hồi xác nhận, lệnh hệ thống, SoD, khẩn không bỏ bước).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/adaccount-cc/financial-hard-stop.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/adaccount-cc/` (hard stop engine tầng API, SoD engine); bản WEB của tín hiệu khớp tiền: `phase2-features/bcerp-web/wallet-recon/` (REQ-FIN-006 — MOD-WALLET-RECON) — REQ-OPS-002 xuất hiện ở 2 systems (SYS-CORE-BACKEND + SYS-BCERP-WEB), chủ ý không có bản mobile/portal |
| Nguồn domain | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — vòng đời cấp phát, Contract) + policy `quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.1 |
