# Tính Năng: Phê duyệt vượt ngưỡng & escalation

> **Dựa trên:** REQ-BOD-001 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Tài chính — Công nợ & Thanh toán (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ARAP-001 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-BOD-001 — Phê duyệt vượt ngưỡng & escalation (HIGH, MVP → Phase2) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — approval engine) → Giai đoạn 2 (luồng giải ngân đầy đủ) |
| Phụ thuộc | Không có cross-dependency ngoài module; tham chiếu nền tảng RBAC/SSO/MFA (REQ-BOD-011) và Hard Stop khớp tiền (REQ-FIN-006) |
| Ghi chú Expert (A7) | Team Expert (bod.md Mục A7) xác nhận REQ-BOD-001 duy nhất 1 luồng duyệt — WEB là bản đầy đủ (hồ sơ, chứng từ, ≥2 báo giá khi >20 triệu), MOBILE là bản di động rút gọn; điều chỉnh chi tiết nằm tại Phần B (BR-BOD-001.1–001.4) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp hàng đợi phê duyệt hợp nhất trên web nội bộ cho mọi yêu cầu vượt ngưỡng (giải ngân, chi khẩn, chiết khấu vượt biểu, hợp đồng năm), với SLA đếm ngược 24/48/72h, dual approval tự động theo ma trận vai × ngưỡng × loại chi, escalation khi quá hạn và delegate có kiểm soát khi người duyệt vắng mặt. Mục tiêu là BOD điều khiển được mọi khoản chi lớn ngay trên giao diện web đầy đủ hồ sơ, không bị nghẽn quyết định vì vắng người, đồng thời mọi hành vi duyệt/từ chối/escalate đều để lại vết kiểm toán.

**Phạm vi:**
- Bao gồm: màn hình hàng đợi phê duyệt hợp nhất (giải ngân, chi khẩn, chiết khấu vượt biểu, hợp đồng năm) với SLA đếm ngược từng khoản trên web nội bộ responsive (Next.js).
- Bao gồm: hiển thị hồ sơ duyệt đầy đủ — chứng từ đính kèm, ≥2 báo giá khi giá trị >20 triệu VND, mã dự án/khách (hoặc overhead + lý do), lịch sử trạng thái machine-state.
- Bao gồm: dual approval tự động khi vượt ngưỡng; escalation lên cấp duyệt trên khi quá SLA 24/48/72h; banner trạng thái treo/từ chối/đã duyệt đúng machine-state trả về từ API core.
- Bao gồm: quản lý delegate vắng mặt (≤14 ngày, tự hết hạn) và màn hình ký nhãn "theo ủy quyền #id".
- Bao gồm: form nhập reason code bắt buộc cho mọi hành động duyệt/từ chối/escalate, gửi về audit service của core backend.
- Không bao gồm: enforcement ma trận ngưỡng, SoD engine và chặn giải ngân thiếu chữ ký — thực thi tại SYS-CORE-BACKEND (service layer); web chỉ hiển thị kết quả enforce và chặn submit phía UI.
- Không bao gồm: bản duyệt di động (push, duyệt khẩn 4h, MFA step-up) — thuộc SYS-MOBILE-INTERNAL, spec riêng theo fan-out REQ-BOD-001.
- Không bao gồm: xác nhận khớp tiền Hard Stop (FIN_L1, REQ-FIN-006) và luồng thực hiện chi/ghi sổ — web chỉ hiển thị trạng thái Hard Stop đã thỏa mãn hay chưa.

---

## 2. Luồng Người Dùng (User Stories)

Luồng dưới đây mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive cho nhân viên BC, gọi API core và hiển thị đúng trạng thái machine-state do service layer trả về.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO | Xem hàng đợi phê duyệt hợp nhất theo nhóm ngưỡng (50–200 triệu dual approval, >200 triệu/HĐ năm) với SLA đếm ngược 48/72h | Chủ động xử lý đúng thứ tự ưu tiên, không để khoản nào rơi quá hạn mà không có người chịu trách nhiệm |
| 2 | BOD_CEO | Mở hồ sơ đầy đủ trên web (chứng từ, ≥2 báo giá, mã dự án/khách, snapshot tỷ giá ngày duyệt) trước khi duyệt khoản >200 triệu | Quyết định trên đầy đủ căn cứ, không duyệt "mù" qua thông báo tóm tắt |
| 3 | BOD_CEO | Nhận khoản do CFO là người đề xuất trong hàng đợi riêng "chờ CEO duyệt" | Đảm bảo compensating control kiêm nhiệm CFO/CTO — khoản vượt ngưỡng cao nhất chỉ CEO được phê |
| 4 | BOD_CFO_CTO | Ủy quyền delegate cho một cá nhân cụ thể với hạn mức ≤ FIN_L2, thời hạn tối đa 14 ngày, tự hết hạn | Nghỉ phép/đi công tác mà luồng duyệt không tắc, mọi lệnh do delegate duyệt vẫn mang nhãn "theo ủy quyền #id" |
| 5 | BOD_CEO | Thấy cảnh báo escalation đỏ khi khoản duyệt quá SLA (24/48/72h) và theo dõi việc leo thang lên cấp duyệt trên | Không để quyết định tài chính nghẽn vì vắng người; vi phạm SLA có người nhận trách nhiệm |
| 6 | SYS_ADMIN | Cấu hình/đồng bộ tham số hiển thị hàng đợi, người nhận escalation sau khi có phê duyệt của BOD | Thực thi đúng vai trò thực thi — không tự ý thay đổi ma trận duyệt hay tự duyệt/sửa lệnh chi |
| 7 | BOD_CFO_CTO | Tra cứu lịch sử mọi lệnh duyệt/từ chối kèm reason code và người thao tác | Đối soát nội bộ, phục vụ audit và review định kỳ của BOD |

Sau khi duyệt trên web, trạng thái machine-state chuyển tức thời và các bên liên quan thấy cùng một trạng thái duy nhất từ API core; web không tự tính lại trạng thái. Nếu kết nối API gián đoạn, web hiển thị trạng thái cuối cùng đã đồng bộ kèm timestamp, không cho thao tác duyệt trên dữ liệu stale.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính nằm ở service layer của SYS-CORE-BACKEND; web phải phản ánh đúng và không có đường tắt UI nào né luật.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Ma trận ngưỡng giải ngân (đã chốt theo DI-001, mức 5/50/200 triệu VND): ≤5 triệu FIN_L2 duyệt; >5–50 triệu FIN_L2 duyệt; >50–200 triệu FIN_L2 + CFO (dual approval, SLA 48h); >200 triệu hoặc hợp đồng năm → CFO + CEO (SLA 72h). Giá trị quy VND theo tỷ giá snapshot ngày duyệt. | Web chặn submit; core từ chối route sai ngưỡng và trả lỗi business kèm mã ngưỡng |
| BR-002 | SoD 4 vai dòng tiền: người đề xuất ≠ người khớp tiền (FIN_L1) ≠ người duyệt chi ≠ người ghi sổ; dual approval cần 2 người; người tạo chứng từ không được xuất hiện trong chuỗi duyệt của chính chứng từ đó. | Core block submit khi vai trùng, log vi phạm SoD cho CFO rà định kỳ; web hiển thị lỗi ngay tại form |
| BR-003 | Financial Hard Stop "đã khớp tiền" (FIN_L1 xác nhận trên web với MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; không vai nào bypass kể cả CEO; "chờ duyệt"/"khách hứa chuyển" không có giá trị mở khóa. | Mọi yêu cầu giải ngân thiếu xác nhận khớp tiền bị từ chối cứng + audit log bất biến |
| BR-004 | Cấm "duyệt trước, bổ sung sau": chứng từ upload đầy đủ trước khi duyệt; ≥2 báo giá bắt buộc khi giá trị >20 triệu; mã dự án/khách bắt buộc, không gắn được phải chọn overhead kèm lý do. | Nút "Duyệt" disabled khi thiếu điều kiện; core từ chối yêu cầu thiếu hồ sơ |
| BR-005 | CFO là người đề xuất khoản vượt ngưỡng cao nhất → nhánh duyệt chỉ có BOD_CEO (compensating control kiêm nhiệm CFO/CTO); giao dịch do CFO khởi tạo khóa "chờ CEO duyệt", không đường tắt. | Core chặn hard trong code, không override; web hiển thị hàng đợi riêng "chờ CEO duyệt" |
| BR-006 | Escalation quá hạn: 24h nhắc người duyệt trên web; quá SLA (24/48/72h theo ngưỡng) hệ thống tự escalate lên cấp duyệt trên và phát alert đỏ; khoản đã escalate vẫn cần người đúng cấp duyệt, escalate không tự động thông qua. | Timer escalation chạy ở core; web tô đỏ hàng quá hạn, ghi nhận escalate vào audit log |
| BR-007 | Delegate vắng mặt: chỉ ủy cho cá nhân cụ thể, hạn mức ≤ FIN_L2 theo loại chi, tối đa 14 ngày, tự hết hạn; CEO không ủy cho CFO/CTO quyết định giao dịch do chính CFO/CTO khởi tạo; hành vi Super Admin/vault không ủy quyền. | Lệnh duyệt do delegate quá hạn mức/hạn thời gian bị từ chối; log gắn nhãn "theo ủy quyền #id" |
| BR-008 | Nạp định kỳ trong hạn mức tuần đã duyệt không duyệt lại giao dịch con; sắp vượt hạn mức tuần phải duyệt bổ sung trước khi giải ngân (FIN_L2 ≤50 triệu, CFO >50 triệu). | Core cảnh báo khi tiến sát hạn mức và chặn giải ngân vượt phần chưa duyệt bổ sung |
| BR-009 | Chi khẩn (nền tảng sắp khóa TKQC): duyệt 4h qua kênh khẩn, MOBILE ưu tiên nhưng quyết định hồ sơ đầy đủ vẫn ở web; hậu kiểm chứng từ trong 24h, tồn hậu kiểm bật alert đỏ. | Khoản khẩn quá 4h không duyệt bị escalate ngay; hậu kiểm trễ phát alert cho BOD |
| BR-010 | Mọi hành vi duyệt/từ chối/escalate/delegate ghi audit log kèm reason code bắt buộc; log bất biến — kể cả Super Admin không sửa/xóa được; web không hiển thị plaintext credential nào. | Hành động thiếu reason code bị từ chối ở API; log thiếu vết là lỗi nghiêm trọng P1 |
| BR-011 | Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, theo DI-004 ngày 12/09) — vendor-agnostic, hỗ trợ import/export chuẩn schema + adapter API cắm được; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng), sau cutoff legacy chỉ read-only. | Dữ liệu đã migrate không được ghi ngược về legacy; cấu hình connector sai profile bị chặn trước khi sync |
| BR-012 | Hóa đơn điện tử theo TT78/2021 + NĐ123/2020 chỉ phát hành trên doanh thu phí dịch vụ/markup từ chứng từ đã khóa kỳ; phí nền tảng hạch toán vào giá vốn media theo giao dịch gốc; khoản duyệt liên quan phải tách bạch tiền giữ hộ khỏi doanh thu. | Chứng từ chưa khóa kỳ/chưa khớp tiền không cho phép phát hành hay đối ứng hóa đơn; ghi nhận discrepancy ticket |

---

## 4. Phân Quyền

Phân quyền hiển thị và thao tác trên web nội bộ; quyền duyệt thực chất do RBAC engine của core backend kiểm tra tại API — bảng dưới là hợp đồng UI phải tuân thủ. Chỉ dùng 18 vai trong registry; người thử việc/freelancer không có quyền phê duyệt.

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | FIN_L2 | FIN_L1 |
|-----------|---------|-------------|-----------|--------|--------|
| Xem hàng đợi theo phạm vi của mình | ✅ (tất cả) | ✅ (dual + >200tr) | ❌ | ✅ (≤50tr, theo hạn mức) | ❌ (chỉ xem trạng thái) |
| Duyệt ≤5 triệu / >5–50 triệu | ✅ | ❌ (không nhánh) | ❌ | ✅ | ❌ |
| Đồng duyệt 50–200 triệu (dual) | ✅ | ✅ | ❌ | ✅ (chữ ký thứ nhất) | ❌ |
| Duyệt >200 triệu / HĐ năm | ✅ (bắt buộc nhánh) | ✅ (đề xuất/đồng duyệt) | ❌ | ❌ | ❌ |
| Duyệt khoản do CFO đề xuất | ✅ (duy nhất CEO) | ❌ (bị chặn SoD) | ❌ | ❌ | ❌ |
| Từ chối kèm reason code | ✅ | ✅ | ❌ | ✅ (trong hạn mức) | ❌ |
| Thiết lập delegate cho FIN_L2 | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình tham số/người nhận escalation | ✅ (phê duyệt) | ✅ (đề xuất) | ✅ (thực thi sau duyệt) | ❌ | ❌ |
| Sửa/xóa lệnh chi đã submit | ❌ | ❌ | ❌ | ❌ (chỉ reversal có reason) | ❌ |

SYS_ADMIN không duyệt/sửa lệnh chi — vai này chỉ thực thi cấu hình sau phê duyệt của BOD, kể cả đối với chính tài khoản của mình. Mọi lệnh duyệt qua web ghi kênh thao tác (web/mobile) vào audit log để đối chiếu sau.

---

## 5. Trường Hợp Đặc Biệt

- Người duyệt vắng mặt đột xuất quá 14 ngày: delegate tự hết hạn đúng hạn, luồng quay về người duyệt gốc; nếu vẫn vắng, CFO ủy quyền lại (với FIN_L2) hoặc khoản leo thang cấp trên — không tồn tại "delegate vĩnh viễn".
- CFO vừa là người đề xuất vừa nằm trong nhánh duyệt: hệ thống tự tách — toàn bộ khoản đó chuyển thẳng CEO, web hiển thị nhãn "CFO đề xuất → chỉ CEO duyệt"; mọi nỗ lực route khác bị chặn và log.
- Hai người duyệt thao tác gần như đồng thời trên một khoản (dual approval): core xử lý optimistic locking — lệnh sau nhận lỗi "trạng thái đã thay đổi", web bắt người dùng refresh machine-state trước khi thao tác lại.
- Khoản chi ngoại tệ: quy VND theo tỷ giá snapshot chốt tại ngày duyệt; web hiển thị cả nguyên tệ và quy VND; snapshot được lưu bất biến vào chứng từ, không dùng tỷ giá hiện hành lúc xem.
- Khoản liên quan TKQC mà lệnh nạp chưa khớp tiền: nút duyệt có thể bấm nhưng core giữ lệnh ở "đã duyệt — chờ Hard Stop", không cho giải ngân đến khi FIN_L1 xác nhận "đã khớp tiền"; web hiển thị rõ hai trạng thái này là hai điều kiện khác nhau.
- Escalate đến cấp cao nhất mà cả BOD_CEO và BOD_CFO_CTO đều không duyệt được từ xa (theo đề xuất B0.2 đang `[CẦN CHỐT SỐ]`): lệnh treo có nhãn rõ, cảnh báo đỏ duy trì đến khi một trong hai thao tác; web không tạo cơ chế "duyệt hộ" thay thế.
- Chi khẩn ngoài giờ: MOBILE nhận push trước, nhưng khi mở web, khoản khẩn hiển thị trên đầu hàng đợi với huy hiệu "KHẨN — SLA 4h" và hậu kiểm 24h được đặt lịch tự động.
- Khoản có chứng từ sau khi duyệt bị phát hiện sai: không sửa đè — xử lý bằng reversal/reject có reason code, bản gốc giữ nguyên cho audit.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu chi/phê duyệt (Payment Request) — web hiển thị đúng machine-state do core trả về; web không tự suy diễn trạng thái.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_APPROVAL] ──(duyệt ≤50tr)──► [APPROVED] ──(Hard Stop OK + thực hiện chi)──► [EXECUTED]
                          │        │
                          │        └─(50–200tr: FIN_L2 duyệt xong)──► [DUAL_PENDING] ──(CFO duyệt)──► [APPROVED]
                          │                                      └─(>200tr/HĐ năm)──► [CEO_PENDING] ──(CEO duyệt)──► [APPROVED]
                          │ (quá SLA 24/48/72h)
                          ▼
                    [ESCALATED] ──(cấp trên duyệt)──► về nhánh APPROVED tương ứng
[PENDING_*/ESCALATED] ──(reject kèm reason)──► [REJECTED]
[DRAFT/PENDING_*] ──(hủy có lý do)──► [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_APPROVAL` | Người đề nghị | Đủ chứng từ; ≥2 báo giá nếu >20tr; mã dự án/khách hoặc overhead + lý do; SoD hợp lệ |
| `PENDING_APPROVAL` | Approve | `APPROVED` | FIN_L2 | Giá trị ≤50 triệu; Hard Stop khớp tiền thỏa nếu liên quan TKQC |
| `PENDING_APPROVAL` | Approve | `DUAL_PENDING` | FIN_L2 | Giá trị >50–200 triệu — chuyển CFO đồng duyệt |
| `DUAL_PENDING` | Dual approve | `APPROVED` | BOD_CFO_CTO | 50–200 triệu: đủ 2 chữ ký khác người |
| `DUAL_PENDING` | Chuyển nhánh | `CEO_PENDING` | BOD_CFO_CTO | Giá trị >200 triệu hoặc hợp đồng năm |
| `CEO_PENDING` | Approve | `APPROVED` | BOD_CEO | Khoản CFO đề xuất chỉ có nhánh này |
| `PENDING_*` | Escalate (tự động) | `ESCALATED` | Hệ thống | Quá SLA 24/48/72h; alert đỏ đã phát |
| `PENDING_*/ESCALATED` | Reject | `REJECTED` | Người đúng cấp duyệt | Bắt buộc reason code |
| `APPROVED` | Thực hiện chi | `EXECUTED` | FIN (người thực hiện ≠ duyệt) | Hard Stop "đã khớp tiền" nếu liên quan TKQC |
| `DRAFT/PENDING_*` | Cancel | `CANCELLED` | Người tạo / CFO | Phải nhập lý do hủy |

**Quy tắc:**
- Không thể quay về trạng thái trước; sửa nội dung sau submit chỉ qua hủy + tạo lại hoặc reversal có reason code.
- `EXECUTED`, `REJECTED`, `CANCELLED` là trạng thái kết thúc — không chuyển tiếp; khoản khẩn bổ sung luồng hậu kiểm 24h gắn trên `EXECUTED`.
- Timer SLA do core vận hành; web chỉ hiển thị đếm ngược và trạng thái escalate, không tự chuyển trạng thái.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| PaymentRequest | `id`, `type` (giải ngân/chi khẩn/chiết khấu/HD năm), `amount`, `currency`, `fx_snapshot`, `project_code`, `status` | FK → `users` (người tạo), FK → `attachments` | Machine-state do core sở hữu |
| ApprovalStep | `request_id`, `level` (L2/CFO/CEO), `approver_id`, `delegate_of`, `decision`, `reason_code`, `decided_at` | FK → `payment_request.id` | Dual approval = 2 step bắt buộc; nhãn "theo ủy quyền #id" |
| EscalationRecord | `request_id`, `sla_breached_at`, `escalated_to`, `alert_id` | FK → `payment_request.id`, FK → alert REQ-BOD-006 | Tạo tự động khi quá SLA |
| DelegateGrant | `grantor_id`, `grantee_id`, `max_amount`, `valid_from`, `valid_to`, `status` | FK → `users` | Tối đa 14 ngày, tự hết hạn |
| AuditLog (tham chiếu) | `object`, `old_value`, `new_value`, `reason_code`, `channel` | Append-only, hash-chain | Bất biến, không xóa/sửa |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Dual approval 50–200tr | Khoản 120 triệu FIN_L2 đã duyệt | CFO đồng duyệt trên web | Trạng thái `APPROVED`; đủ 2 step khác người; audit log có 2 reason code | [ ] |
| SC-002: CFO đề xuất → chỉ CEO | Khoản 300 triệu do CFO khởi tạo | CFO thử tự duyệt | Core chặn hard; lệnh nằm ở hàng đợi "chờ CEO duyệt"; attempt được log | [ ] |
| SC-003: Escalation quá SLA | Khoản 50–200tr treo quá 48h | Hệ thống tới hạn | Tự escalate + alert đỏ; hàng đợi tô đỏ; escalate ghi audit log | [ ] |
| SC-004: Delegate hết hạn | Delegate 14 ngày đã hết hạn ngày 15 | Delegate duyệt khoản ≤50tr | Từ chối; luồng trả về người duyệt gốc; log "theo ủy quyền #id — hết hạn" | [ ] |
| SC-005: Hard Stop chặn giải ngân | Khoản nạp TKQC 80 triệu chưa khớp tiền | Đã đủ chữ ký duyệt | Trạng thái giữ "đã duyệt — chờ Hard Stop", không `EXECUTED` đến khi FIN_L1 xác nhận | [ ] |
| SC-006: Thiếu hồ sơ chặn submit | Chứng từ 30 triệu chỉ có 1 báo giá | Người tạo bấm Submit | UI chặn + core từ chối; lỗi nêu rõ thiếu báo giá thứ 2 | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-BOD-001 (Mục 2 — hàng đợi hợp nhất, dual approval, escalation, delegate, audit log).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/approval-queue.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/arap-payment/` (enforcement), `phase2-features/mobile-internal/arap-payment/` (duyệt di động) |
