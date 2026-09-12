# Tính Năng: Financial Hard Stop Chặn Cấp Phát TKQC

> **Dựa trên:** REQ-OPS-002 trong `phase1-business/departments/operations/operations.md` (Phần A3, Phần B.2 — BR-OPS-2.1/2.2); tín hiệu "đã khớp tiền" từ REQ-FIN-006 trong `phase1-business/departments/finance/finance.md` (BR-FIN-302)
> **Phân hệ:** Vận hành & Marketing nội bộ — Paid Media / Ad Ops, phối hợp Tài chính (SYS-CORE-BACKEND)
> **Module:** Quản lý Tài khoản Quảng cáo — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/adaccount-cc/[screen-group].md`, `phase5-implementation/tasks/core-backend/adaccount-cc/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-OPS-002 fan-out ra 2 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-ADACC-003); counterpart: SYS-BCERP-WEB (luồng đề xuất nạp, trạng thái khóa, màn xác nhận khớp tiền MFA của FIN_L1). **Chủ ý không có bản M-INT/PORTAL** — không tạo kênh duyệt nào có thể bypass Hard Stop. Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ADACC-003 |
| Module | MOD-ADACCOUNT-CC (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-002 (Financial Hard Stop chặn cấp phát TKQC); tín hiệu đầu vào REQ-FIN-006 (Financial Hard Stop "đã khớp tiền" — FIN_L1) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (gặp gate); FIN_L1 (nguồn tín hiệu khớp tiền); FIN_L2 (duyệt chi — SoD); SYS_ADMIN (không có quyền override) |
| Độ ưu tiên | Cao (HIGH · MVP · GĐ1) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | FEAT-CORE-ADACC-001 (gate KYC) và FEAT-CORE-ADACC-002 (registry tiêu thụ trạng thái gate để chuyển "Cấp phát") |
| Ghi chú Expert (A7) | Chưa có điều chỉnh — Mục A7 trong `operations.md`/`finance.md` đang "chờ review"; việc tách REQ-OPS-002 khỏi REQ-OPS-001 để traceability độc lập control đã chốt tại A0 `operations.md` |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Financial Hard Stop là chốt kiểm soát tiền quan trọng nhất của mô hình trung gian TKQC: **không cấp phát TKQC, không bật chi tiêu khi FIN_L1 chưa xác nhận "Đã khớp tiền"** cho lệnh nạp tương ứng. Feature này hiện thực hóa chốt kiểm soát đó như một **rule engine thực thi trong code trên core backend** — không nút override ở bất kỳ tầng nào (UI, API, DB, script vận hành), không vai nào bypass kể cả Giám đốc và Super Admin. Tiền nạp QC của khách là tiền giữ hộ — hệ thống bảo đảm tuyệt đối chi tiêu chỉ chạy trên tiền đã về tài khoản BC và khớp số.

**Phạm vi:**
- Bao gồm: rule engine Hard Stop thực thi tầng API — mọi action "Cấp phát TKQC"/"bật chi tiêu" phải qua kiểm tra trạng thái khớp tiền của lệnh nạp tương ứng; tiêu chí "Đã khớp tiền" (tiền đã về tài khoản BC **và** khớp số với lệnh nạp, người chuyển trùng tên pháp nhân KYC, evidence sao kê + timestamp bắt buộc); thu hồi xác nhận khớp tiền → TKQC tự về "Tạm dừng chi tiêu", khóa nạp mới, alert TL; từ chối + ghi audit log bất biến mọi yêu cầu mở khóa thủ công; SoD 4 vai dòng tiền (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ); chặn lệnh nạp miệng.
- Không bao gồm: màn hình đề xuất nạp, hiển thị trạng thái khóa và màn xác nhận khớp tiền MFA TOTP của FIN_L1 (SYS-BCERP-WEB — CORE chỉ xác thực kết quả + evidence); workflow đối trừ 3 số đầy đủ của ví (REQ-FIN-001/004); cảnh báo số dư 3 mức và SLA đỏ (REQ-OPS-003); alert push mobile (M-INT chỉ nhận thông tin, không có action — không thuộc phạm vi system này).

---

## 2. Luồng Người Dùng (User Stories)

Luồng dưới đây mô tả trải nghiệm qua WEB nội bộ cho các thao tác đề xuất/xác nhận; mọi điều kiện đều được core backend xác thực lại tại tầng API.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Tạo lệnh đề xuất nạp trên hệ thống (khách/TKQC/số tiền/tỷ giá/căn cứ) và chỉ đưa TK vào cấp phát khi gate tự mở sau khi FIN_L1 khớp tiền | Luôn có căn cứ hệ thống để đòi tiền khách — không thể "hứa trước chi sau" |
| 2 | OPS_ADS | Bị chặn ngay ở tầng API khi bật chi tiêu trên TK chưa khớp tiền, kèm thông báo trạng thái lệnh nạp hiện tại | Thấy rõ mình đang ở đâu trong luồng, không mất công thử đường tắt không tồn tại |
| 3 | FIN_L1 | Ghi "Đã khớp tiền" kèm evidence (sao kê/lệnh nạp) + timestamp, và được bảo đảm chỉ tín hiệu này mở được Hard Stop | Tôi là nguồn sự thật duy nhất của điều kiện tiền — không ai tạo được tín hiệu thay thế |
| 4 | FIN_L1 | Thu hồi xác nhận khớp tiền khi phát hiện khớp sai, hệ thống tự pause TK và khóa nạp mới | Sửa sai trong có kiểm soát — tiền chưa chắc chắn thì chi tiêu dừng ngay, không cần họp |
| 5 | FIN_L2 | Duyệt chi theo SoD, engine tự chặn trường hợp 1 người giữ ≥2 vai trong 1 giao dịch dòng tiền | Trách nhiệm phân đúng 4 vai: đề xuất — khớp tiền — duyệt chi — ghi sổ |
| 6 | BOD_CFO_CTO | Tra audit log bất biến chứng minh không giao dịch nào vượt Hard Stop, kể cả từ tài khoản quản trị cao nhất | Có bằng chứng kiểm soát kiểm chứng được trước auditor và khách hàng |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Hard Stop là control đặc biệt: mọi rule dưới đây enforce tại tầng service/workflow engine của core backend và phải được thiết kế sao cho không tồn tại đường code nào bỏ qua điều kiện kiểm tra.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Chỉ khớp tiền mở khóa:** action "Cấp phát TKQC"/"bật chi tiêu" chỉ thực thi khi trạng thái khớp tiền của lệnh nạp tương ứng = **"Đã khớp tiền"**. Enforcement trong code (workflow engine + service layer), kiểm tra bắt buộc trên mọi đường vào (API, job, script); không nhận tham số trạng thái từ client. Nguồn: BR-OPS-2.1, BR-FIN-302. | API từ chối với mã "HARD_STOP_CHUA_MO"; lần thử vi phạm ghi audit log |
| BR-002 | **Không override, không "chờ duyệt":** không tồn tại nút override, route bypass, trạng thái "chờ duyệt để chi trước" ở mọi tầng (UI, API, DB, script vận hành); không vai nào bypass — kể cả Giám đốc (BOD_CEO/BOD_CFO_CTO), kể cả Super Admin. Mọi yêu cầu mở khóa thủ công bị từ chối và ghi audit log bất biến. Nguồn: BR-OPS-2.1, `operations.md` BR-OPS-2.1, ma trận REQ-OPS-002. | Từ chối + audit log; hiển thị thông điệp "không có vai nào bypass" |
| BR-003 | **Định nghĩa "Đã khớp tiền":** tiền đã về tài khoản ngân hàng BC **và** khớp số với lệnh nạp; người chuyển trùng tên pháp nhân đã KYC; mỗi xác nhận bắt buộc gắn evidence (sao kê ngân hàng/lệnh nạp) + timestamp + danh tính người xác nhận. CORE chặn ghi nhận khi chưa có lệnh hoặc số lệch. Nguồn: BR-FIN-302/BR-FIN-103, P1-02 luồng 2 B2–B4. | Thiếu evidence/số lệch/tên lệch → xác nhận không được ghi, gate không mở; lệch tên chuyển rà thủ công theo luồng KYC |
| BR-004 | **Không có exception, kể cả khẩn cấp:** "khách hứa chuyển/đang chuyển/sếp đã OK" không có giá trị mở khóa; khẩn cấp ngoài giờ vẫn chỉ mở khi đã khớp tiền — xử lý nhanh hơn (ưu tiên đối soát), không bỏ bước. Nguồn: BR-OPS-2.1. | Mọi yêu cầu ngoại lệ bị từ chối mặc định + log; không có luồng "ngoại lệ tạm thời" |
| BR-005 | **Lệnh hệ thống là input duy nhất:** OPS_AM/OPS_ADS đề xuất nạp chỉ qua lệnh trên hệ thống (cấm xác nhận miệng Zalo/điện thoại/email riêng) — FIN từ chối đối chiếu lệnh miệng. Lệnh chứa khách/TKQC/số tiền/tỷ giá/căn cứ. Nguồn: REQ-OPS-002 A3, BR-OPS-2.5. | Lệnh không tồn tại trong hệ thống → FIN_L1 không thể khớp, gate không bao giờ mở |
| BR-006 | **Thu hồi xác nhận khớp tiền:** FIN_L1 phát hiện khớp sai → thu hồi xác nhận → CORE tự chuyển TK liên quan về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL (OPS_PLAN); thu hồi ghi reason code + evidence; TK chỉ mở lại khi có xác nhận khớp tiền hợp lệ mới. Nguồn: BR-OPS-2.2, REQ-OPS-002. | Chi tiêu đang chạy bị pause tự động; thử tiếp tục chi → chặn bởi BR-001 |
| BR-007 | **SoD 4 vai dòng tiền:** đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ (kế toán) — SoD engine chặn 1 người giữ ≥2 vai trong 1 giao dịch. Dual approval (đề xuất ≠ duyệt) cho 3 nhóm rủi ro cao: điều chỉnh số dư tay, đổi tỷ giá tay, hoàn tiền. Nguồn: BR-OPS-2.5, BR-FIN-105/106, REQ-OPS-002 A3. | Giao dịch có xung đột vai bị từ chối tại tầng engine |
| BR-008 | **Audit log bất biến:** mọi event (đề xuất, xác nhận, thu hồi, chặn, yêu cầu mở khóa bị từ chối) ghi append-only + hash-chain: ai (user, role), khi nào (timestamp), làm gì, trên đối tượng nào, old→new value + reason code bắt buộc; không tồn tại interface xóa/sửa log ở mọi tầng, kể cả Super Admin; sửa sai = giao dịch reversal. Nguồn: BR-FIN-501, REQ-OPS-002. | Thiếu reason code → không submit; đứt chuỗi hash → alert CTO + BOD_CEO |
| BR-009 | **Xác nhận khớp tiền chỉ từ kênh được phép:** hành động xác nhận FIN_L1 chỉ hợp lệ khi phát từ counterpart WEB với MFA TOTP (CORE xác thực bối cảnh phiên + evidence); không có endpoint xác nhận trên mobile/portal — chủ ý không tạo kênh duyệt có thể bypass; mobile chỉ nhận thông tin, portal không tạo được lệnh. Nguồn: BR-FIN-302, bản riêng theo hệ thống B.2. | Xác nhận từ kênh không hợp lệ → từ chối + audit log bảo mật |
| BR-010 | **Gate kép với KYC:** Hard Stop khớp tiền là điều kiện cần nhưng không đủ — registry vẫn phải qua gate KYC (FEAT-CORE-ADACC-001: KYC = `Verified`) trước khi "Cấp phát"; hai gate độc lập, không thay thế nhau. Nguồn: REQ-FIN-009 × REQ-OPS-002 phối hợp. | Mở một gate không tự mở gate còn lại; thiếu KYC → chặn với mã riêng |
| BR-011 | **Tenant isolation + role check tại service layer:** mọi API Hard Stop scop cứng theo tenant (khách); role/quyền xác thực lại ở tầng API cho từng action (không tin trạng thái phiên do client gửi). Nguồn: Notes lane. | Truy vấn vượt tenant / giả mạo vai → từ chối + audit log bảo mật |

---

## 4. Phân Quyền

| Hành động | OPS_AM / OPS_ADS | FIN_L1 | FIN_L2 | OPS_PLAN (TL) | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN |
|-----------|------------------|--------|--------|---------------|------------------------|-----------|
| Xem trạng thái Hard Stop của TK/lệnh nạp | ✅ (TK của mình) | ✅ | ✅ | ✅ (phạm vi nhóm) | ✅ | ✅ |
| Tạo lệnh đề xuất nạp | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận "Đã khớp tiền" (gắn evidence + MFA từ WEB) | ❌ | ✅ (duy nhất) | ❌ | ❌ | ❌ | ❌ |
| Thu hồi xác nhận khớp tiền | ❌ | ✅ (reason code bắt buộc) | ❌ | ❌ | ❌ | ❌ |
| Duyệt chi (SoD — vai thứ 3) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Ghi sổ (SoD — vai thứ 4) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cấp phát/bật chi tiêu (thực thi khi gate mở) | ✅ (owner/backup) | ❌ (billing không sửa ngân sách) | ❌ | ❌ | ❌ | ❌ |
| Override / mở khóa thủ công Hard Stop | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (**không vai nào — hành động không tồn tại trong API**) |
| Xem/tra cứu audit log Hard Stop | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Xóa/sửa bản ghi audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |

> Ghi chú touchpoint: trên mobile nội bộ (SYS-MOBILE-INTERNAL) và portal khách không tồn tại action duyệt/override nào của luồng này — chỉ nhận thông tin trạng thái; quyết định chủ ý chống bypass đã chốt ở A0 (`operations.md`). Mọi quyền enforce bằng vai tại tầng API core backend.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khẩn cấp ngoài giờ:** không có exception — FIN_L1 vẫn phải khớp tiền trên WEB + MFA; "nhanh hơn" chỉ là ưu tiên xử lý đối soát (on-call FIN theo DI-005: xoay vòng SLA 4h ngoài giờ), không bỏ bước.
- **"Khách hứa chuyển / đang chuyển / sếp đã OK":** không có giá trị mở khóa — hệ thống không có trường dữ liệu nào nhận các trạng thái này làm căn cứ; yêu cầu dạng này bị ghi là mở khóa thủ công → từ chối + log.
- **Tiền về nhưng lệch số / lệch tên người chuyển:** lệch số → không cho ghi "Đã khớp tiền", xử lý theo quy trình đối soát (REQ-FIN-004) trước; lệch tên → chặn khớp tự động, rà thủ công theo luồng KYC (ngoại lệ nhóm mẹ/con cần văn bản + BOD duyệt — FEAT-CORE-ADACC-001 BR-006).
- **Thu hồi khớp tiền khi TK đang chi tiêu:** TK tự về "Tạm dừng chi tiêu" ngay cả giữa ngày chạy chiến dịch; hệ thống alert TL để owner giảm ngân sách khẩn; không có cơ chế "gia hạn chi trong chờ xác minh".
- **Nhiều lệnh nạp song song của 1 khách:** Hard Stop áp theo mapping lệnh nạp ↔ lệnh cấp phát (bắt buộc, 1-1); không cho khớp 1 lệnh rồi mở nhiều cấp phát.
- **Lệnh nạp ngoài hệ thống (miệng Zalo/điện thoại):** FIN từ chối đối chiếu; OPS phải tạo lệnh đầy đủ căn cứ trước — dòng tiền chưa vào luồng thì gate không bao giờ thấy nó.
- **Yêu cầu mở khóa từ Super Admin:** bị từ chối như mọi vai; sự kiện được log + alert BOD_CEO — bằng chứng kiểm soát cho auditor.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh đề xuất nạp (`RechargeIntent`) và trạng thái gate Hard Stop của lệnh cấp phát TKQC tương ứng. Trạng thái lệnh nạp chi tiết (SINGLE/DUAL, PENDING → APPROVED...) thuộc feature ví của FIN (REQ-FIN-001/003) — ở đây chỉ mô hình hóa các trạng thái mà gate Hard Stop tiêu thụ.

**Sơ đồ trạng thái:**
```
[PENDING] ──(FIN_L1 khớp tiền + evidence + MFA)──► [MATCHED] ──(mở Hard Stop: TK "Cấp phát"/bật chi tiêu)──► [GATE_OPEN]
    │                                                    │                                                        │
    │ (FIN_L1 từ chối/lệnh hủy)                          │ (FIN_L1 thu hồi + reason)                              │
    ▼                                                    ▼                                                        ▼
[REJECTED]                                          [REVOKED] ──► TK tự về "Tạm dừng chi tiêu",            [GATE_OPEN]
                                                khóa nạp mới, alert TL  ──(khớp lại)──► [MATCHED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Khớp tiền | `MATCHED` | FIN_L1 (duy nhất; SoD: không phải người đề xuất) | Tiền về TK BC + khớp số + người chuyển trùng tên pháp nhân KYC + evidence (sao kê/lệnh) + timestamp + MFA từ WEB |
| `PENDING` | Từ chối | `REJECTED` | FIN_L1 | Reason code bắt buộc; OPS_AM/OPS_ADS tạo lệnh mới khi đủ căn cứ |
| `MATCHED` | Thu hồi khớp tiền | `REVOKED` | FIN_L1 | Reason code + evidence; CORE tự pause TK liên quan, khóa nạp mới, alert OPS_PLAN (TL) |
| `MATCHED` | Mở Hard Stop | Gate mở (TK "Cấp phát") | Hệ thống (tự động khi điều kiện đủ) | Gate KYC của khách cũng đã mở (BR-010); mapping lệnh nạp ↔ cấp phát 1-1 |
| `REVOKED` | Khớp lại | `MATCHED` | FIN_L1 | Đủ lại toàn bộ điều kiện khớp tiền như lần đầu; lịch sử thu hồi giữ nguyên trong audit log |

**Quy tắc:**
- `REJECTED` và `REVOKED` không chuyển thẳng sang `MATCHED` — luôn đi lại luồng khớp tiền đầy đủ; `REVOKED` không xóa dấu vết lần khớp cũ (append-only).
- Trạng thái gate chỉ đọc từ nguồn sự thật FIN trong cùng transaction với action "Cấp phát" — không có khoảng cửa thời gian (race window) cho phép chi trên trạng thái cũ.
- Không tồn tại trạng thái trung gian "đang chờ duyệt để mở gate" — `PENDING` đồng nghĩa gate đóng cứng.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; workflow đối chiếu đầy đủ của ví thuộc feature FIN (REQ-FIN-001/004/006).*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `RechargeIntent` (lệnh đề xuất nạp) | `customer_id`, `ad_account_id`, `amount`, `currency`, `fx_rate`, `basis_ref`, `proposed_by`, `state`, `match_status` (`PENDING/MATCHED/REJECTED/REVOKED`) | FK → `customers`, `ad_accounts` | Input duy nhất FIN chấp nhận đối chiếu; cấm lệnh ngoài hệ thống |
| `MatchConfirmation` | `recharge_intent_id`, `confirmed_by` (FIN_L1), `confirmed_at`, `evidence_ref` (sao kê/lệnh), `channel` (WEB+MFA), `revoked_by`, `revoke_reason` | FK → `recharge_intents` | Nguồn sự thật duy nhất gate đọc; thu hồi giữ bản ghi cũ |
| `HardStopGate` / gate state | `ad_account_id`, `gate_kyc_status`, `gate_money_status`, `enforced_at` | FK → `ad_accounts`, `match_confirmations` | Đọc trong cùng transaction với action cấp phát; không cache client-side |
| `HardStopAuditLog` | `actor_id`, `role`, `action`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only + hash-chain; không có interface xóa/sửa ở mọi tầng |
| `ManualUnlockRequest` | `requested_by`, `role`, `requested_at`, `outcome` (`DENIED` — cố định) | FK → `users` | Bắt mọi yêu cầu mở khóa thủ công thành bản ghi từ chối + trigger alert BOD_CEO |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-002 (`operations.md` Mục A3/B.2) và REQ-FIN-006 (`finance.md` BR-FIN-302).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn cấp phát khi chưa khớp tiền (REQ-OPS-002) | Lệnh nạp ở `PENDING`, gate đóng | OPS_ADS gọi API cấp phát/bật chi tiêu | API từ chối `HARD_STOP_CHUA_MO`; không có đường UI/API nào thành công; sự kiện thử vi phạm ghi audit log | [ ] |
| SC-002: Chỉ khớp tiền đủ điều kiện mở gate (REQ-FIN-006) | Tiền về nhưng số lệch với lệnh nạp | FIN_L1 thử ghi "Đã khớp tiền" | Xác nhận bị chặn (BR-003); gate vẫn đóng; FIN_L1 phải xử lý theo quy trình đối soát trước | [ ] |
| SC-003: Không vai nào override (REQ-OPS-002) | Gate đóng | SYS_ADMIN / BOD_CEO gọi mọi API liên quan mở khóa | Toàn bộ bị từ chối; `ManualUnlockRequest` ghi `DENIED`; alert BOD_CEO; không tồn tại route ẩn (kiểm tra code + penetration test) | [ ] |
| SC-004: Thu hồi khớp tiền tự pause TK (REQ-OPS-002) | TK đang "Vận hành" sau khi đã khớp tiền | FIN_L1 thu hồi xác nhận (reason code + evidence) | TK tự về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert OPS_PLAN; chi tiêu mới bị chặn; lịch sử khớp cũ còn nguyên trong audit log | [ ] |
| SC-005: SoD chặn xung đột vai (REQ-OPS-002) | 1 người được gán cả vai FIN_L1 (khớp tiền) và là người đề xuất lệnh nạp | Người đó thử tự khớp tiền lệnh mình đề xuất | Engine từ chối (1 người ≥2 vai trong 1 giao dịch); giao dịch cần 1 vai đề xuất (OPS) + 1 vai khớp tiền (FIN_L1) khác biệt | [ ] |
| SC-006: Gate kép — khớp tiền không thay thế KYC (REQ-OPS-002 × REQ-FIN-009) | Khớp tiền đã MATCHED nhưng KYC khách `EXPIRED` | Hệ thống xử lý cấp phát | Vẫn chặn với mã "KYC chưa Verified"; 2 gate độc lập, mỗi mã lỗi riêng biệt | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (tín hiệu khớp tiền từ module FIN REQ-FIN-006; WEB xác nhận MFA; không có endpoint duyệt trên M-INT/PORTAL — chống bypass) |
| Màn hình UI (WEB — trạng thái khóa, xác nhận MFA) | `phase4-ux/bcerp-web/adaccount-cc/[screen-group].md` |
| Domain model nguồn | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.4 `AdAccount`, §3.6 `RechargeRequest`) |
| Policy nghiệp vụ | `policies/quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.1 |
| Feature liên quan cùng module | `kyc-phap-nhan-truoc-cap-phat-tkqc.md` (FEAT-CORE-ADACC-001 — gate kép), `ad-account-command-center-registry-va-vong-doi-tkqc.md` (FEAT-CORE-ADACC-002 — registry tiêu thụ trạng thái gate) |
