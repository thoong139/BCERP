# Tính Năng: Phê duyệt vượt ngưỡng & escalation (Mobile Nội Bộ)

> **Dựa trên:** REQ-BOD-001 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Mobile Nội Bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Công nợ AR/AP & Giải ngân (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/arap-payment/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/arap-payment/FEAT-MBI-ARAP-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID khai báo trong registry lane của `/wf-define-features`: REQ-BOD-001 (hệ thống đích SYS-MOBILE-INTERNAL) → FEAT-MBI-ARAP-001. REQ fan-out ở 3 hệ thống; bản WEB (hồ sơ đầy đủ) và bản CORE (approval engine) là counterpart trong SYS-BCERP-WEB và SYS-CORE-BACKEND — luồng nghiệp vụ là một, không nhân bản logic.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-ARAP-001 |
| Module | MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân |
| Yêu cầu nghiệp vụ | REQ-BOD-001 (Phê duyệt vượt ngưỡng & escalation); ma trận ngưỡng dùng chung với REQ-FIN-008 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (lõi approval engine + duyệt di động) — hoàn thiện luồng giải ngân đầy đủ ở Giai đoạn 2 |
| Phụ thuộc | Approval engine + SoD engine tại SYS-CORE-BACKEND (cross-dependencies: không có FEAT chéo lane); RBAC/SSO/MFA (REQ-BOD-011); Alert center (REQ-BOD-006) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` chưa ghi nhận điều chỉnh Expert nào tại thời điểm viết spec (A7 chờ bước đánh giá chuyên gia) — cập nhật khi có điều chỉnh, chi tiết tại `bod.md` Mục A7 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp kênh duyệt di động (React Native, offline-capable, quản lý qua MDM) để BOD_CEO và BOD_CFO_CTO xử lý hàng đợi phê duyệt vượt ngưỡng mọi lúc mọi nơi: push kèm SLA đếm ngược, duyệt khoản khẩn trong 4 giờ, dual approval và escalation khi trượt hạn. Tính năng bảo đảm không khoản chi nào kẹt duyệt vì người duyệt vắng mặt, đồng thời giữ nguyên kiểm soát ngưỡng, SoD và audit log như kênh web — mobile là kênh thực thi, không phải lối tắt bỏ kiểm soát.

**Phạm vi:**
- Bao gồm:
  - Hàng đợi duyệt hợp nhất dạng tóm tắt (giải ngân, chi khẩn, chiết khấu vượt biểu, hợp đồng năm) với SLA đếm ngược, ngữ cảnh công nợ AR/AP liên quan và cờ escalation.
  - Push + nhắc SLA 24/48/72 giờ; quá hạn tự escalate lên cấp duyệt trên và phát alert đỏ (REQ-BOD-006).
  - Duyệt/từ chối kèm reason code với MFA step-up; khoản ≥200 triệu chặn nút "Duyệt" cho đến khi mở tối thiểu 1 chứng từ.
  - Dual approval nhánh >50–200 triệu (FIN_L2 + CFO) và >200 triệu/hợp đồng năm (CFO + CEO) ngay trên mobile.
  - Delegate vắng mặt ≤14 ngày tự hết hạn; chi khẩn 4 giờ kênh khẩn (mobile ưu tiên) với hậu kiểm 24 giờ.
  - Xem offline read-only (cache); mọi lệnh duyệt chỉ thực thi khi online.
- Không bao gồm:
  - Tạo đề nghị chi và xem hồ sơ đầy đủ — thuộc SYS-BCERP-WEB; mobile tóm tắt và chuyển người dùng sang web khi cần.
  - Enforcement ma trận ngưỡng, SoD engine, snapshot tỷ giá — thuộc SYS-CORE-BACKEND.
  - Xác nhận "Đã khớp tiền" Hard Stop — chỉ WEB với MFA (REQ-FIN-006); mobile chỉ alert/xem.
  - Duyệt chính sách/tham số (REQ-BOD-009 — chỉ web); vault/gateway (REQ-BOD-008 — mobile cấm); chấm công/timesheet (module CAPACITY-TIMESHEET); dashboard P&L (REQ-BOD-003/004).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Nhận push kèm SLA đếm ngược cho khoản cần tôi duyệt | Không bỏ sót hạn duyệt dù đang công tác xa |
| 2 | BOD_CEO | Duyệt khoản khẩn (nền tảng sắp khóa TKQC) trên điện thoại trong 4 giờ | TKQC khách không bị khóa vì chờ duyệt tại văn phòng |
| 3 | BOD_CEO | Bị chặn nút "Duyệt" với khoản ≥200 triệu cho đến khi tôi mở ≥1 chứng từ | Buộc nắm nội dung tối thiểu trước khi ký, dù chỉ trên bản tóm tắt |
| 4 | BOD_CFO_CTO | Đồng duyệt (chữ ký hai) khoản >50–200 triệu trên mobile sau FIN_L2 | Dual approval không chậm khi tôi di chuyển |
| 5 | BOD_CFO_CTO | Ủy quyền duyệt phần hạn mức của tôi cho một cá nhân khi vắng ≤14 ngày | Hàng đợi không ùn, hạn mức ủy không vượt hạn mức của tôi |
| 6 | BOD_CEO | Khoản trượt SLA tự escalate lên cấp trên kèm alert đỏ | Khoản trễ được tháo gỡ theo tầng, không dò thủ công |
| 7 | BOD_CFO_CTO | Xem aging AR/AP và hạn thanh toán AP nền tảng trên màn tóm tắt | Quyết duyệt có căn cứ dòng tiền, không chỉ theo số tiền |
| 8 | SYS_ADMIN | Nhận cảnh báo khoản khẩn tồn hậu kiểm quá 24 giờ | Phối hợp truy vết hỗ trợ BOD — không tham gia duyệt |
| 9 | BOD_CEO | Xem hàng đợi offline (cache) khi mất mạng | Nắm backlog cần xử lý ngay khi có kết nối lại |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-101 | Ma trận ngưỡng (5/50/200 triệu đã chốt theo DI-001, 12/09): ≤5 triệu → FIN_L2; >5–50 triệu → FIN_L2; >50–200 triệu → FIN_L2 + BOD_CFO_CTO (dual, SLA 48h); >200 triệu/hợp đồng năm → BOD_CFO_CTO + BOD_CEO (SLA 72h). CEO duyệt mọi ngưỡng; nhánh >200 triệu bắt buộc chữ ký CEO | CORE từ chối chuyển trạng thái; thiếu chữ ký bị chặn giải ngân và hiển thị "thiếu chữ ký" trên hàng đợi |
| BR-102 | Ngoại tệ quy VND theo tỷ giá snapshot ngày duyệt; snapshot lưu bất biến kèm yêu cầu | Thiếu snapshot → từ chối submit; mobile chỉ hiển thị tỷ giá đã chốt |
| BR-103 | Cấm "duyệt trước, bổ sung sau" (BR-BOD-001.1): đủ chứng từ, ≥2 báo giá khi >20 triệu, mã dự án/khách (hoặc overhead + lý do) trước khi vào hàng đợi | Khoản thiếu điều kiện không xuất hiện để duyệt; nút Duyệt vô hiệu kèm danh sách mục thiếu |
| BR-104 | CFO là người đề xuất khoản vượt ngưỡng cao nhất → nhánh duyệt chỉ còn CEO (BR-BOD-001.2, nền compensating control REQ-BOD-002); CEO duyệt từ xa qua MOBILE, không ủy lại cho CFO/CTO | Hệ thống loại CFO khỏi danh sách người duyệt giao dịch do chính họ khởi tạo — chặn hard tầng service |
| BR-105 | Nạp định kỳ trong hạn mức tuần đã duyệt không duyệt lại giao dịch con; sắp vượt tuần phải duyệt bổ sung trước khi giải ngân (BR-BOD-001.3) | Giao dịch con vượt hạn mức bị chặn; mobile push cảnh báo cho người duyệt kế hoạch |
| BR-106 | Chi khẩn duyệt 4 giờ qua kênh khẩn (mobile ưu tiên) + hậu kiểm chứng từ 24 giờ; tồn hậu kiểm quá hạn bật alert đỏ (BR-BOD-001.4) | Quá 24h chưa hậu kiểm → alert đỏ BOD + SYS_ADMIN; khoản đánh dấu "tồn hậu kiểm" |
| BR-107 | Escalation: quá 24h chưa duyệt → nhắc lại; quá SLA nhánh ngưỡng → escalate cấp trên + alert đỏ (REQ-BOD-006). Mốc escalate theo ngưỡng cấu hình theo chính sách hạn mức chi — đang dùng mặc định đề xuất, chốt khi BOD duyệt chính sách (assumption, không thuộc nhóm KXN đang mở) | Khoản quá SLA chuyển lên hàng đợi cấp trên; log escalation có timestamp |
| BR-108 | Mọi duyệt/từ chối ghi audit log bất biến kèm reason code (bắt buộc khi từ chối) và nhãn kênh (WEB/MOBILE) | Thiếu reason code → từ chối thao tác |
| BR-109 | Mobile: MFA step-up bắt buộc mọi lệnh duyệt; thiết bị qua MDM, MFA TOTP bắt buộc cho BOD (REQ-BOD-011); khoản ≥200 triệu chặn nút "Duyệt" đến khi mở ≥1 chứng từ | Thiết bị chưa MDM/MFA → chặn kênh duyệt; chưa mở chứng từ → nút disabled kèm lý do |
| BR-110 | Mobile offline chỉ xem (read-only cache); mọi lệnh duyệt/từ chối/ủy quyền thực thi online để bảo đảm thứ tự hiệu lực và audit timestamp duy nhất | Bấm duyệt khi mất mạng → thông báo "cần kết nối", không tạo lệnh cục bộ |
| BR-111 | Delegate (B0.2): ủy cá nhân cụ thể, hạn mức ≤ người ủy theo loại chi, tối đa 14 ngày, tự hết hạn, log "theo ủy quyền #id". CEO không ủy cho CFO/CTO quyết giao dịch do chính họ khởi tạo; hành vi Super Admin/vault không ủy quyền | Delegate quá hạn tự vô hiệu; lệnh vượt hạn mức ủy bị chặn |
| BR-112 | Financial Hard Stop: mọi giải ngân liên quan TKQC chỉ thực thi khi lệnh nạp tương ứng được FIN_L1 xác nhận "Đã khớp tiền" — điều kiện tiên quyết, chặn cứng trong code, không vai nào override kể cả CEO/Super Admin (REQ-FIN-006); xác nhận chỉ trên WEB + MFA, mobile chỉ alert/xem | Thiếu khớp tiền → CORE từ chối chuyển APPROVED → EXECUTED; mobile hiển thị "chờ khớp tiền" |
| BR-113 | SoD 4 vai dòng tiền: đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ; SYS_ADMIN không duyệt/sửa lệnh chi — chỉ thực thi cấu hình sau CR được duyệt | Block submit khi vai trùng + log vi phạm cho CFO rà định kỳ; mobile vô hiệu nút duyệt sai vai |
| BR-114 | Hàng đợi hiển thị ngữ cảnh công nợ AR/AP (REQ-FIN-007): aging 0–30/31–60/61–90/>90 ngày, hạn thanh toán AP nền tảng, lịch sử nhắc nợ; AR >90 ngày là căn cứ clawback hoa hồng 100% | Thiếu ngữ cảnh (lỗi dữ liệu) → khoản vẫn duyệt được nhưng gắn cảnh báo dữ liệu |
| BR-115 | Bút toán khoản đã duyệt xuất về phần mềm kế toán VAS qua connector cấu hình tại Settings — MOD-SETTINGS-GW (DI-004): vendor-agnostic (connection profile + field mapping + import/export chuẩn schema + adapter API); chỉ xuất từ chứng từ đã duyệt/khóa kỳ. Legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng), phần còn lại legacy read-only | Connector fail → hàng chờ retry + alert, không ghi sổ tay; bản nháp không bao giờ xuất |
| BR-116 | Khoản chi đã duyệt là căn cứ hạch toán phí nền tảng và nghĩa vụ thuế; HĐĐT theo TT78/2021 + NĐ123/2020 chỉ phát hành trên doanh thu dịch vụ từ chứng từ đã khóa kỳ — không xuất cho dòng tiền giữ hộ (REQ-FIN-011/014) | Chứng từ chưa khóa kỳ bị chặn phát hành HĐĐT; dòng giữ hộ bị chặn xuất hóa đơn |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem hàng đợi duyệt hợp nhất + tóm tắt trên mobile | ✅ | ✅ | ❌ |
| Xem chứng từ đính kèm (bản tóm tắt) | ✅ | ✅ | ❌ |
| Duyệt/từ chối nhánh ≤50 triệu | ✅ | ❌ | ❌ |
| Duyệt cấp một nhánh >50–200 triệu | ✅ | ❌ (chữ ký hai) | ❌ |
| Đồng duyệt (chữ ký hai) >50–200 triệu | ✅ | ✅ | ❌ |
| Duyệt nhánh >200 triệu / hợp đồng năm (cùng CFO) | ✅ (bắt buộc) | ✅ | ❌ |
| Duyệt thay khi CFO là người đề xuất | ✅ (duy nhất) | ❌ | ❌ |
| Duyệt chi khẩn kênh khẩn 4h | ✅ | ✅ (nhánh FIN) | ❌ |
| Gán/thu hồi delegate của mình | ✅ | ✅ | ❌ |
| Cấu hình tham số ngưỡng/escalation theo CR | ❌ | ❌ (phê duyệt CR) | ✅ |
| Sửa/xóa lệnh chi | ❌ | ❌ | ❌ |
| Xem audit log chi tiết đầy đủ | ✅ | ✅ | ✅ |

> Ghi chú: mọi nút duyệt nằm sau MFA step-up (BR-109). FIN_L2 không phải actor chính của feature này nhưng là chữ ký cấp một trong dual approval — chi tiết duyệt FIN thuộc FEAT-MBI-ARAP-002.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Cả CEO và CFO đồng thời vắng mặt: khoản >200 triệu giữ trong hàng đợi, escalate theo SLA + alert đỏ; CEO duyệt từ xa qua MOBILE là con đường chính thức — không có "duyệt hộ" thay thế (B0.2 đề xuất treo lệnh khi cả hai không thể duyệt từ xa — assumption chờ chốt trong chính sách hạn mức chi).
- Chi khẩn ngoài giờ: vẫn phải tạo lệnh trên hệ thống trước khi xử lý; "khẩn" rút ngắn SLA 4h nhưng không bỏ bước duyệt hay bỏ Hard Stop.
- Thiết bị mất/mua mới: đăng ký lại MFA theo REQ-BOD-011; phiên thiết bị cũ thu hồi và ghi audit log chống mạo danh lệnh duyệt.
- Tồn hậu kiểm quá 24 giờ: bật alert đỏ BOD + SYS_ADMIN; khoản theo dõi đến khi đóng hậu kiểm.
- Nhận push khi thiết bị offline: xem hàng đợi từ cache (read-only); khi có mạng, SLA tính theo thời gian server, không theo thiết bị.
- Nhiều khoản cùng chờ dual approval của một người: gom nhóm theo loại chi và SLA gần nhất; duyệt từng khoản độc lập, không "duyệt tất cả" hàng loạt.
- Người ủy quay lại sớm: thu hồi delegate ngay; lệnh đã duyệt theo ủy quyền giữ hiệu lực với nhãn "theo ủy quyền #id".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính là Yêu cầu phê duyệt; mobile thực thi chuyển trạng thái, CORE hợp lệ hóa.*

**Entity:** Yêu cầu phê duyệt (approval_request)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit, WEB)──► [PENDING] ──(duyệt cấp 1)──► [PENDING_DUAL] ──(duyệt cấp 2)──► [APPROVED]
                             │   ▲                          │                              │
                             │   └──(quá SLA: cờ ESCALATED) │ (từ chối)                    ├─(thực hiện chi, qua Hard Stop nếu TKQC)─► [EXECUTED]
                             │ (từ chối)                    ▼                              │ (chi khẩn)
                             ▼                          [REJECTED]                         ▼
                        [REJECTED]                                                    [POST_AUDIT] ──(đạt)──► [CLOSED]
```
*ESCALATED không phải trạng thái riêng — là cờ trên PENDING/PENDING_DUAL kèm alert.

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING` | Người đề nghị (WEB) | Đủ chứng từ, ≥2 báo giá nếu >20 triệu, mã dự án/khách hoặc overhead + lý do (BR-103) |
| `PENDING` | Duyệt (nhánh 1 chữ ký ≤50 triệu) | `APPROVED` | FIN_L2 hoặc BOD_CEO | MFA step-up; ≥200 triệu phải mở ≥1 chứng từ; đúng vai BR-101 |
| `PENDING` | Duyệt cấp một (nhánh dual) | `PENDING_DUAL` | FIN_L2 (>50–200 triệu) hoặc BOD_CFO_CTO (>200 triệu) | Không trùng người đề xuất (BR-113) |
| `PENDING_DUAL` | Duyệt cấp hai | `APPROVED` | BOD_CFO_CTO (50–200 triệu) hoặc BOD_CEO (>200 triệu, bắt buộc) | Đủ 2 chữ ký khác nhau; delegate hợp lệ nếu dùng |
| `PENDING` / `PENDING_DUAL` | Từ chối | `REJECTED` | Người duyệt đúng vai | Bắt buộc reason code |
| `PENDING` / `PENDING_DUAL` | Quá SLA | Giữ nguyên + cờ `ESCALATED` | Hệ thống | Nhắc 24h; quá SLA escalate cấp trên + alert đỏ (BR-107) |
| `APPROVED` | Thực hiện chi | `EXECUTED` | Hệ thống / thu ngân (FIN_L1) | Khoản TKQC: lệnh nạp tương ứng "Đã khớp tiền" (BR-112) |
| `APPROVED` (chi khẩn) | Mở hậu kiểm | `POST_AUDIT` | Hệ thống | Hậu kiểm 24h; tồn quá hạn bật alert (BR-106) |
| `POST_AUDIT` | Đóng hậu kiểm | `CLOSED` | FIN_L2 / BOD_CFO_CTO | Ghi kết luận hậu kiểm vào audit log |
| `PENDING` / `PENDING_DUAL` | Hủy bởi người đề nghị | `CANCELLED` | Người đề nghị | Chưa có chữ ký nào; có chữ ký → luồng từ chối |

**Quy tắc:**
- Không quay về trạng thái trước; bị từ chối thì tạo yêu cầu mới, không sửa hồ sơ cũ.
- `EXECUTED`, `CLOSED`, `REJECTED`, `CANCELLED` là trạng thái kết thúc — không chuyển tiếp.
- Mọi chuyển trạng thái ghi audit log bất biến kèm kênh (WEB/MOBILE) và reason code khi từ chối/hủy.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `approval_request` | `id`, `type` (giải ngân/chi khẩn/chiết khấu/hợp đồng năm), `amount`, `currency`, `fx_snapshot`, `threshold_branch`, `status`, `escalated_flag`, `sla_deadline` | FK → `payment_order.id` (nếu gắn lệnh chi) | Nguồn CORE; mobile đọc/ghi qua API |
| `approval_step` | `request_id`, `step_no`, `required_role`, `approver_id`, `decision`, `reason_code`, `channel`, `decided_at` | FK → `approval_request.id` | Dual approval = 2 dòng |
| `delegate_authorization` | `delegator_id`, `delegate_id`, `chi_type`, `limit_amount`, `valid_from`, `valid_to`, `status` | FK → `users.id` (2 chiều) | Tự hết hạn; log "theo ủy quyền #id" |
| `audit_log` | `actor_id`, `entity`, `entity_id`, `action`, `reason_code`, `channel`, `timestamp` | Polymorphic | Append-only, WORM ≥10 năm (REQ-FIN-012) |
| `escalation_log` | `request_id`, `from_role`, `to_role`, `triggered_at`, `alert_id` | FK → `approval_request.id`, alert center | Tạo khi vượt SLA |
| `mobile_cache_manifest` | `user_id`, `queue_version`, `synced_at` | FK → `users.id` | Điều khiển cache offline read-only |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Chi tiết điền ở Phase 5; Phase 2 ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Duyệt khoản khẩn 4h trên mobile | Chi khẩn `PENDING`, CEO có thiết bị MFA hợp lệ | CEO mở khoản, MFA step-up, bấm Duyệt | `APPROVED`; audit log ghi kênh MOBILE; push xác nhận ≤30 giây | [ ] |
| SC-002: Chặn duyệt khi chưa mở chứng từ (≥200 triệu) | Khoản >200 triệu `PENDING_DUAL`, CFO chưa mở chứng từ | CFO bấm "Duyệt" | Nút vô hiệu kèm thông báo "cần mở ≥1 chứng từ"; không ghi chữ ký | [ ] |
| SC-003: Escalate khi quá SLA | Khoản >50–200 triệu quá SLA 48h | Bộ đếm SLA quá hạn | Cờ ESCALATED bật, đẩy lên hàng đợi cấp trên, alert đỏ REQ-BOD-006 | [ ] |
| SC-004: Delegate tự hết hạn | Delegate của CFO hết hạn 14:00 | Người được ủy duyệt lúc 14:05 | Từ chối vai delegate; khoản quay về hàng đợi CFO | [ ] |
| SC-005: Chặn giải ngân khi chưa khớp tiền | Khoản nạp TKQC `APPROVED` nhưng lệnh nạp chưa được FIN_L1 xác nhận khớp tiền | Hệ thống thực hiện chi | Chặn cứng; nhãn "chờ khớp tiền"; không có override | [ ] |
| SC-006: Offline read-only | Thiết bị mất mạng, hàng đợi đã cache | Xem hàng đợi và thử duyệt | Xem được cache; duyệt bị chặn kèm thông báo cần kết nối | [ ] |

> **Liên kết:** SC-001/SC-002 map REQ-BOD-001 (duyệt khẩn, ≥200 triệu mở chứng từ); SC-003/SC-004 map REQ-BOD-001 (escalation, delegate); SC-005 map REQ-FIN-006/008 (Hard Stop); SC-006 map touchpoint mobile offline-capable.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (mobile — approval queue, push, offline sync) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (approval engine CORE, alert center, connector VAS) | `technical-specs/integration-map.md` |
| Màn hình UI (mobile — hàng đợi duyệt, tóm tắt, MFA step-up) | `phase4-ux/mobile-internal/arap-payment/approval-queue.md` |
| Feature counterpart cùng REQ (WEB, CORE) | `phase2-features/bcerp-web/arap-payment/`, `phase2-features/core-backend/arap-payment/` |
