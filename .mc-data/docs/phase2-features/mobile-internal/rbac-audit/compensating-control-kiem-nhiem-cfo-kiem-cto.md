# Tính Năng: Compensating Control Kiêm Nhiệm CFO Kiêm CTO (Mobile Nội Bộ)

> **Dựa trên:** REQ-BOD-002 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Mobile Nội Bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/rbac-audit/FEAT-MBI-RBAC-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID khai báo trong registry lane của `/wf-define-features`: REQ-BOD-002 (hệ thống đích SYS-MOBILE-INTERNAL) → FEAT-MBI-RBAC-001. REQ fan-out ở 3 hệ thống; bản CORE (chặn hard tại service layer) là counterpart trong SYS-CORE-BACKEND, bản WEB (hàng đợi đầy đủ + ký review) là counterpart trong SYS-BCERP-WEB — luồng nghiệp vụ là một, không nhân bản logic; mobile là kênh CEO thực thi compensating control khi di chuyển.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-RBAC-001 |
| Module | MOD-RBAC-AUDIT — RBAC & Audit Log |
| Yêu cầu nghiệp vụ | REQ-BOD-002 (Compensating control kiêm nhiệm CFO kiêm CTO) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — kích hoạt từ giao dịch tiền đầu tiên) |
| Phụ thuộc | FEAT-CORE-RBAC-001 (engine chặn hard + quarterly review tại CORE — mobile chỉ là kênh thực thi); FEAT-MBI-RBAC-002 (SSO/MFA, thiết bị step-up); alert center REQ-BOD-006 (kênh push) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` chưa ghi nhận điều chỉnh Expert nào tại thời điểm viết spec (A7 chờ bước đánh giá chuyên gia) — nguồn chi tiết nghiệp vụ là Phần B (B0, B2) của `bod.md`; cập nhật theo `bod.md` Mục A7 khi có điều chỉnh |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Trên mobile nội bộ (React Native, offline-capable, quản lý qua MDM), tính năng cho BOD_CEO thực thi compensating control đối với điểm tập trung rủi ro duy nhất của BCERP — CFO kiêm CTO đồng thời là Super Admin: nhận push ngay khi giao dịch tiền do `BOD_CFO_CTO` khởi tạo vượt ngưỡng bị CORE khóa "chờ CEO duyệt", duyệt khẩn ≤4 giờ với MFA step-up, ký quarterly review quyền của CFO/CTO từ xa, và giám sát phiên truy cập khẩn T3/T4. Mobile bảo đảm kiểm soát không nghẽn vì CEO vắng mặt — nhưng mobile chỉ là kênh thực thi, không phải lối tắt bỏ kiểm soát.

**Phạm vi:**
- Bao gồm:
  - Push realtime cho BOD_CEO khi SoD engine của CORE tạo lệnh khóa `LOCKED_PENDING_CEO` (nạp/rút ví QC, điều chỉnh số dư, đổi tỷ giá, hoàn tiền, chiết khấu ngoài biểu).
  - Hàng đợi "chờ CEO duyệt" dạng tóm tắt: loại giao dịch, số tiền quy VND theo tỷ giá snapshot, đối tượng, lý do, SLA đếm ngược; hồ sơ đầy đủ chuyển WEB.
  - Duyệt/từ chối với MFA step-up; chặn nút "Duyệt" cho đến khi mở bản tóm tắt/chứng từ; từ chối bắt buộc reason code.
  - Cảnh báo lệnh khóa quá 4h chưa duyệt (alert đỏ, re-push định kỳ) qua REQ-BOD-006.
  - Giám sát phiên truy cập khẩn T3/T4 (break-glass): alert khi mở, xem trạng thái, alert đỏ khi quá 24h chưa khai báo lý do.
  - Ký quarterly review quyền CFO/CTO qua mobile khi CEO vắng (không ủy quyền); xem offline read-only từ cache mã hóa.
- Không bao gồm:
  - Engine phát hiện SoD và chặn hard tại service layer — thuộc SYS-CORE-BACKEND (FEAT-CORE-RBAC-001); mobile không có nút/API override.
  - Hàng đợi đầy đủ với chứng từ chi tiết, workspace ký review — touchpoint chính thuộc SYS-BCERP-WEB.
  - Tra cứu audit log nội dung — cấm trên mobile (BR-BOD-005.3); chỉ nhận alert đứt chuỗi qua REQ-BOD-006.
  - Thao tác credentials vault — cấm trên mobile (BR-BOD-008.2, REQ-BOD-008).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **mobile nội bộ**: duyệt-on-the-go cho CEO, xem trạng thái cho CFO/CTO, alert cho SYS_ADMIN — mọi quyết định quyền vẫn do CORE enforcement, app không tự quyết.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Nhận push kèm SLA đếm ngược ngay khi giao dịch do CFO/CTO khởi tạo bị khóa chờ tôi duyệt | Không bỏ sót khoản khóa nào dù đang công tác xa |
| 2 | BOD_CEO | Duyệt khoản bị khóa trên điện thoại trong ≤4 giờ với MFA step-up | Dòng tiền không nghẽn vì tôi vắng văn phòng mà vẫn đủ kiểm soát |
| 3 | BOD_CEO | Bị chặn nút "Duyệt" cho đến khi tôi mở bản tóm tắt/chứng từ của khoản | Buộc nắm nội dung tối thiểu trước khi ký, không duyệt mù trên bản push |
| 4 | BOD_CEO | Từ chối kèm reason code ngay trên mobile | Luồng tài chính trả về CFO/CTO có căn cứ, có vết audit |
| 5 | BOD_CEO | Nhận alert đỏ khi khoản khóa quá 4h và khi có phiên khẩn T3/T4 mở hoặc quá 24h chưa khai báo | Phát hiện điểm rủi ro nóng ngay, không chờ kỳ review |
| 6 | BOD_CEO | Ký quarterly review quyền CFO/CTO qua mobile trong 10 ngày đầu quý khi vắng | Nghĩa vụ compensating control không trượt hạn và không ủy được cho ai |
| 7 | BOD_CFO_CTO | Xem trạng thái các giao dịch do tôi khởi tạo đang chờ CEO (chỉ khoản của mình) | Biết rõ khoản nào đang chờ, không nhầm là lỗi hệ thống |
| 8 | SYS_ADMIN | Nhận alert kỹ thuật khi lệnh khóa tồn lâu hoặc phiên khẩn quá hạn khai báo | Phối hợp truy vết hỗ trợ BOD — không tham gia duyệt |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — enforcement nguồn sự thật nằm ở SYS-CORE-BACKEND; mobile không nhân bản logic kiểm soát.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ cho portal/mobile-portal). KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối): CX Head gán OPS_PLAN; Compliance gán FIN_L2 + BOD oversight | App chỉ render 18 vai trong claim; tham chiếu vai ngoài registry bị API từ chối |
| BR-002 | (Dùng chung lane) Audit log bất biến append-only hash-chain: mọi thao tác ghi có actor + timestamp + lý do (reason code); log tiền giữ WORM ≥10 năm; không interface xóa/sửa kể cả Super Admin. Lệnh duyệt/từ chối/ký từ mobile ghi kèm nhãn kênh MOBILE | Thiếu reason code → thao tác bị từ chối; nỗ lực sửa log thất bại ở tầng DB và bị meta-log ghi vết |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control theo REQ-BOD-002 — chính là luồng này; quyền CFO/CTO chưa được CEO ký review 2 quý liên tiếp tự vô hiệu (do CORE) | Giao dịch dùng quyền đã vô hiệu bị chặn với thông báo "quyền chưa được review" trên mobile |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung: mọi lệnh duyệt/ký trên mobile bắt buộc phiên MFA TOTP hợp lệ kèm step-up tại thời điểm thao tác; PII nhân sự (lương) mức Confidential/Restricted, không hiển thị trên lock-screen | Thiết bị chưa MDM/MFA → chặn kênh duyệt; phiên thiếu claim MFA → API từ chối |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND (mặc định đã chốt 12/09 — DI-001): giao dịch do CFO/CTO khởi tạo rơi nhánh vượt ngưỡng đều khóa chờ CEO; quá thẩm quyền tự escalation lên cấp trên + alert | Thiếu chữ ký CEO không giải ngân; escalation phát sự kiện alert REQ-BOD-006 push lên mobile CEO |
| BR-006 | Chặn hard thuộc CORE: mobile không có nút/API/cấu hình nào đổi trạng thái lệnh khóa ngoài nhánh "CEO duyệt/từ chối"; khi CFO/CTO khởi tạo, danh sách người duyệt chỉ còn BOD_CEO — app không render nút hành động cho vai khác | Lời gọi hành động sai vai bị CORE từ chối kèm mã lỗi SoD và ghi log để CFO rà định kỳ |
| BR-007 | Push CEO ≤5 phút từ lúc khóa (kênh khẩn REQ-BOD-006); quá 4h chưa quyết → alert đỏ + re-push định kỳ; lệnh vẫn khóa — không có "quá hạn tự duyệt", an toàn theo thiết kế | Push thất bại → retry kênh phụ (SMS/email bridge) + log; khoản tiếp tục chờ CEO |
| BR-008 | MFA step-up bắt buộc tại thời điểm Duyệt/Từ chối/Ký trên mobile; thiết bị phải đăng ký qua MDM và enroll TOTP (FEAT-MBI-RBAC-002); thiết bị lạ không nhận challenge | Step-up thất bại → nút vô hiệu, sự kiện ghi audit; thiết bị chưa đăng ký không nhận step-up |
| BR-009 | Khoản khóa hiển thị bản tóm tắt (loại giao dịch, số tiền theo tỷ giá snapshot ngày duyệt, đối tượng, lý do, chứng từ rút gọn); nút "Duyệt" chỉ bật sau khi mở tóm tắt/chứng từ ≥1 lần trong phiên xem | Nút disabled kèm lý do "chưa xem chứng từ"; server kiểm tra sự kiện view nên không gọi API duyệt bỏ qua được |
| BR-010 | Từ chối bắt buộc reason code theo danh mục chuẩn; duyệt xong → CORE mới giải ngân, từ chối → trả luồng tài chính; mọi quyết định ghi audit kèm actor + timestamp + lý do + nhãn kênh MOBILE | Thiếu reason code → từ chối thao tác; bản ghi thiếu nhãn kênh coi là defect kiểm soát mức chặn |
| BR-011 | CEO ký quarterly review qua mobile là kênh hợp lệ khi vắng và KHÔNG ủy quyền cho ai (kể cả SYS_ADMIN); báo cáo dạng đọc (role × level, phạm vi T3/T4, credentials dạng đếm — không giá trị nhạy cảm); chữ ký qua MFA step-up | Quá ngày 10 đầu quý chưa ký → cảnh báo đỏ CEO + CFO; quyền chưa review 2 quý liên tiếp tự vô hiệu do CORE |
| BR-012 | Break-glass T3/T4: mobile chỉ nhận alert khi mở, xem trạng thái phiên (ai mở, tier, hạn, đã khai báo chưa) và nhắc khai báo 24h — không mở/thao tác trong phiên khẩn trên mobile; quá 24h không khai báo → alert đỏ, phiên tự đóng do CORE | Thử thao tác trong phiên khẩn từ mobile bị từ chối; cảnh báo re-push đến khi có người nhận trách nhiệm |
| BR-013 | Offline chỉ xem (cache mã hóa, TTL theo tier; T4/PII không cache, không lên lock-screen); lệnh duyệt/từ chối/ký chỉ thực thi online; biên touchpoint: cấm tra cứu audit log nội dung (BR-BOD-005.3) và cấm thao tác vault (BR-BOD-008.2); CFO/CTO chỉ xem khoản của mình | Bấm duyệt khi mất mạng → "cần kết nối", không tạo lệnh cục bộ; endpoint log/vault không tồn tại trong API mobile |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Nhận push + xem hàng đợi "chờ CEO duyệt" (tóm tắt) | ✅ | ❌ | ❌ |
| Xem trạng thái khoản bị khóa do mình khởi tạo | ❌ | ✅ (chỉ khoản của mình) | ❌ |
| Duyệt khoản bị khóa (step-up MFA, sau khi xem chứng từ) | ✅ (duy nhất) | ❌ (không thể tự duyệt) | ❌ |
| Từ chối khoản bị khóa kèm reason code | ✅ (duy nhất) | ❌ | ❌ |
| Nhận alert khóa quá 4h / phiên khẩn | ✅ | ✅ (khoản của mình) | ✅ (alert kỹ thuật) |
| Mở/thao tác trong phiên khẩn T3/T4 | ❌ | ✅ (trên WEB, khai báo 24h) | ❌ |
| Xem báo cáo quarterly review (dạng đọc) | ✅ | ✅ (đối tượng bị review) | ❌ |
| Ký quarterly review qua mobile | ✅ (không ủy quyền) | ❌ | ❌ |
| Tra cứu audit log nội dung | ❌ (chỉ WEB) | ❌ (chỉ WEB) | ❌ (cấm trên mobile) |
| Thực thi provisioning sau phê duyệt | ❌ (người duyệt) | ❌ (người đề xuất) | ✅ (trên WEB/API, log từng bước) |
| Override/hủy lệnh khóa | ❌ | ❌ | ❌ (không tồn tại interface) |

> Ghi chú: cột theo đúng 3 vai actors của REQ-BOD-002 trên touchpoint mobile; CUSTOMER không xuất hiện trên feature nội bộ này. SYS_ADMIN không nhận ủy quyền Super Admin (B0.3).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **CEO không phản hồi khoản khóa quá lâu:** lệnh `LOCKED_PENDING_CEO` tồn tại >4h → alert đỏ REQ-BOD-006 + re-push định kỳ; lệnh vẫn khóa — không có "quá hạn tự duyệt", an toàn theo thiết kế.
- **Cả CEO và CFO/CTO không thể duyệt từ xa:** theo B0.2 đề xuất treo lệnh, không duyệt hộ; CEO không được ủy quyền duyệt giao dịch do CFO/CTO khởi tạo cho chính CFO/CTO — vô hiệu compensating control; mobile là kênh duyệt từ xa chính thức của CEO.
- **Khoản vừa compensating control vừa chi khẩn (nền tảng sắp khóa TKQC):** vẫn khóa chờ CEO; CEO duyệt khẩn ≤4h qua mobile với step-up; hậu kiểm chứng từ 24h (BR-BOD-001.4), tồn hậu kiểm bật alert.
- **Ký review trùng sự cố:** hai cơ chế độc lập — ký quarterly review qua mobile vẫn đúng hạn trong 10 ngày đầu quý; phiên khẩn T3/T4 không thay thế hay hoãn review.
- **Thiết bị của CEO mất/mua mới:** thu hồi toàn bộ phiên + remote wipe MDM; re-enroll MFA theo FEAT-MBI-RBAC-002; lệnh từ thiết bị cũ sau thu hồi thất bại và ghi log chống mạo danh.
- **Tách vai CFO/CTO sau này:** luồng hiển thị dựa trên vai thực tế của người khởi tạo (không hardcode "CFO kiêm CTO") — khi tách vai, mobile không cần thay đổi.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh khóa compensating control (Compensating Control Hold) — sở hữu dữ liệu và engine chuyển trạng thái tại SYS-CORE-BACKEND (FEAT-CORE-RBAC-001); mobile là kênh push và kênh CEO kích hoạt chuyển tiếp "duyệt/từ chối".

**Sơ đồ trạng thái:**
```
[PROPOSED] ──(SoD engine: CFO/CTO khởi tạo + vượt ngưỡng)──► [LOCKED_PENDING_CEO]
                                                                 │
                                                  (CEO duyệt     │   (CEO từ chối + reason code,
                                                   qua MOBILE    │    qua MOBILE hoặc WEB)
                                                   hoặc WEB)    ▼
                                                                 ▼
                                                        [CEO_APPROVED] ──(thực thi)──► [EXECUTED]
                                                                 │
[PROPOSED] ──(không rơi nhánh SoD)──► [NORMAL_FLOW]         [REJECTED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PROPOSED` | SoD engine đánh giá | `LOCKED_PENDING_CEO` | Hệ thống (CORE) | Người khởi tạo = BOD_CFO_CTO và số tiền quy VND vượt ngưỡng 5/50/200tr |
| `LOCKED_PENDING_CEO` | Push CEO + hiển thị hàng đợi | (giữ trạng thái) | Hệ thống | Push ≤5 phút; bản tóm tắt kèm SLA đếm ngược |
| `LOCKED_PENDING_CEO` | CEO duyệt | `CEO_APPROVED` | BOD_CEO (duy nhất) | Step-up MFA hợp lệ; đã mở tóm tắt/chứng từ; snapshot tỷ giá đã lưu |
| `LOCKED_PENDING_CEO` | CEO từ chối | `REJECTED` | BOD_CEO (duy nhất) | Bắt buộc reason code; trả luồng tài chính |
| `LOCKED_PENDING_CEO` | Quá 4h chưa quyết | (giữ trạng thái) | Hệ thống | Alert đỏ + re-push — không tự duyệt |
| `CEO_APPROVED` | Thực thi giải ngân | `EXECUTED` | Hệ thống (CORE) | Đủ chữ ký cấp đủ; unlock do CORE phát |

**Quy tắc:**
- Mobile chỉ tham gia hai chuyển tiếp "CEO duyệt" và "CEO từ chối" qua API duyệt có kiểm soát; mọi chuyển tiếp khác do CORE sở hữu.
- `EXECUTED` và `REJECTED` là trạng thái kết thúc — sửa dữ liệu nhập sai qua giao dịch reversal có reason code, không sửa bản ghi gốc; không tồn tại đường từ `LOCKED_PENDING_CEO` sang `EXECUTED` khi thiếu chữ ký CEO.
- Mọi chuyển tiếp ghi audit hash-chain: actor + timestamp + lý do + nhãn kênh (MOBILE/WEB).

**Entity phụ:** Phiên truy cập khẩn (Emergency Access Grant): `OPENED` → `REASON_DECLARED` (khai báo trong 24h, trên WEB) hoặc `EXPIRED_CLOSED` (hết hạn/không khai báo → thu hồi + alert đỏ); mobile chỉ đọc trạng thái.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `database-design.md`; các entity sở hữu bởi CORE, mobile thao tác qua API và cache đọc.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `compensating_control_hold` | `transaction_id`, `initiator_role`, `amount_vnd_snapshot`, `fx_rate_snapshot`, `status`, `reason_code`, `locked_at`, `ceo_decided_at`, `decision_channel` | FK → giao dịch tiền nguồn | Mobile đọc qua API tóm tắt; `decision_channel` ghi kênh CEO thực thi (MOBILE/WEB) |
| `quarterly_review_record` | `review_period`, `subject_user`, `role_snapshot`, `data_scope_tier`, `credential_inventory_ref`, `signed_by`, `signed_at`, `signature_channel` | FK → `user_account`, credential inventory GW | Sinh tự động ngày 1–10 đầu quý; mobile cho phép ký, không ủy quyền |
| `emergency_access_grant` | `grant_id`, `granted_to`, `tier_scope`, `opened_at`, `expires_at`, `reason_declared_at`, `reason_text` | FK → `user_account` | Mobile chỉ đọc + nhận alert; mở/khai báo trên WEB |
| `push_notification` | `notification_id`, `recipient`, `event_ref`, `severity`, `sent_at`, `acknowledged_at` | FK → hold / grant | Re-push định kỳ với mức đỏ đến khi có người nhận trách nhiệm |
| `audit_event` | `event_id`, `actor`, `actor_role`, `timestamp`, `action`, `old_value`, `new_value`, `reason_code`, `channel`, `prev_hash`, `hash` | Ghi bởi CORE | Append-only hash-chain, WORM ≥10 năm với log tiền; mobile không tra cứu nội dung |

---

## 8. Acceptance Criteria

> *Chi tiết điển hình hóa ở Phase 5; dưới đây là phác thảo bắt buộc của Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push CEO khi có lệnh khóa | CORE tạo hold `LOCKED_PENDING_CEO` | Sự kiện push phát | Mobile CEO nhận push ≤5 phút kèm tóm tắt + SLA; push fail có retry + log | [ ] |
| SC-002: Chặn duyệt khi chưa xem chứng từ | Khoản khóa hiển thị | CEO bấm Duyệt trước khi mở tóm tắt | Nút disabled kèm lý do; sau khi mở ≥1 lần → bật; server từ chối API duyệt khi không có sự kiện view | [ ] |
| SC-003: Duyệt khẩn với step-up MFA | CEO đăng nhập, thiết bị MDM + MFA | CEO duyệt khoản khóa trong ≤4h | Step-up bắt buộc; `CEO_APPROVED` → CORE thực thi; audit ghi actor + timestamp + lý do + kênh MOBILE | [ ] |
| SC-004: Từ chối thiếu lý do | Khoản khóa đang mở | CEO từ chối không nhập lý do | Từ chối thao tác; nhập reason code xong → `REJECTED`, trả luồng tài chính | [ ] |
| SC-005: CFO không thấy nút duyệt khoản của mình | CFO/CTO mở khoản do mình khởi tạo | Kiểm tra UI và gọi API trực tiếp | Chỉ thấy trạng thái "chờ CEO duyệt"; mọi hành động duyệt bị CORE từ chối kèm mã SoD | [ ] |
| SC-006: Alert khóa quá 4h và break-glass | Khoản khóa >4h; CTO mở phiên khẩn T3/T4 | Hệ thống đánh giá alert | CEO nhận alert đỏ khoản quá 4h + alert phiên khẩn khi mở; quá 24h chưa khai báo → alert đỏ; không có thao tác khẩn trên mobile | [ ] |
| SC-007: Ký quarterly review qua mobile | Ngày 1–10 đầu quý, CEO vắng | CEO ký review trên mobile | Báo cáo dạng đọc đúng nội dung; ký qua step-up; `signature_channel = MOBILE`; không có tùy chọn ủy quyền | [ ] |
| SC-008: Offline chỉ xem | Thiết bị mất kết nối | CEO mở hàng đợi và bấm duyệt | Hàng đợi đọc từ cache mã hóa; bấm duyệt → "cần kết nối", không tạo lệnh cục bộ | [ ] |
| SC-009: Không ai override lệnh khóa | Bất kỳ vai nào (kể cả Super Admin) | Gọi API mobile đổi trạng thái hold ngoài nhánh CEO duyệt/từ chối | CORE từ chối + ghi log nỗ lực; mobile không có UI/endpoint tương ứng | [ ] |

> **Liên kết:** SC-001→005 map REQ-BOD-002 (kênh CEO thực thi compensating control); SC-006 map REQ-BOD-002 (giám sát break-glass, alert REQ-BOD-006); SC-007 map REQ-BOD-002/REQ-BOD-007 (ký review không ủy quyền); SC-008→009 map REQ-BOD-002 (offline an toàn, không override).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (hold summary, duyệt/từ chối, ký review, trạng thái break-glass) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (SoD engine CORE, alert REQ-BOD-006, MDM) | `technical-specs/integration-map.md` |
| Màn hình UI (hàng đợi tóm tắt, ký review, alert — touchpoint mobile) | `phase4-ux/mobile-internal/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-CORE-BACKEND (FEAT-CORE-RBAC-001), SYS-BCERP-WEB (hàng đợi đầy đủ + workspace ký) — fan-out cùng REQ-BOD-002 |
