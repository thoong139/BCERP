# Tính Năng: Compensating Control Kiêm Nhiệm CFO Kiêm CTO

> **Dựa trên:** REQ-BOD-002 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-001 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-002 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — kích hoạt từ giao dịch tiền đầu tiên) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — cùng module, là điểm check quyền tập trung mà compensating control dựa vào) |
| Ghi chú Expert (A7) | bod.md Mục A7 đã thiết lập khung đánh giá nhưng chưa ghi điều chỉnh nào sau review — không có điều chỉnh nào làm thay đổi spec này; nguồn chi tiết nghiệp vụ là Phần B (B2) của bod.md |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Trong cơ cấu BC Agency, CFO kiêm luôn CTO và đồng thời là Super Admin — đây là điểm tập trung rủi ro duy nhất và lớn nhất của BCERP (một người vừa đề xuất, vừa duyệt, vừa quản trị hạ tầng). Tính năng này cài đặt compensating control: mọi giao dịch tiền do `BOD_CFO_CTO` khởi tạo vượt ngưỡng bị khóa cứng ở tầng service, buộc `BOD_CEO` phê duyệt trước khi thực thi — không đường tắt, không override, kể cả bằng quyền Super Admin.

**Phạm vi:**

- Bao gồm:
  - Engine phát hiện xung đột vai đề xuất–duyệt (SoD) theo luồng giao dịch tiền: nạp/rút ví QC, điều chỉnh số dư, đổi tỷ giá, hoàn tiền, chiết khấu ngoài biểu, lệnh chi vượt ngưỡng 5/50/200 triệu VND.
  - Hard block ở tầng service (headless API/domain service của SYS-CORE-BACKEND): giao dịch CFO khởi tạo rơi nhánh vượt ngưỡng chuyển sang "chờ CEO duyệt", không giải ngân khi thiếu chữ ký CEO.
  - Quarterly review quyền của BOD_CFO_CTO (role × level, phạm vi T3/T4, credentials từ inventory GW) — CEO ký trong 10 ngày đầu quý.
  - Cấp truy cập khẩn (break-glass) vào dữ liệu T3/T4: mở có thời hạn, alert CEO ngay khi mở, khai báo lý do trong 24 giờ.
  - Thiết kế vai CFO và CTO tách rời (role definition tách bạch) để tách vai sau không phải redesign.
- Không bao gồm:
  - Màn hình hàng đợi "chờ CEO duyệt" và ký quarterly review trên web — do SYS-BCERP-WEB (counterpart); bản này chỉ định nghĩa API mà web gọi.
  - Push duyệt khẩn ≤4h trên mobile — do SYS-MOBILE-INTERNAL (counterpart).
  - Hàng đợi phê duyệt đa ngưỡng chung cho mọi vai — thuộc tính năng phê duyệt tài chính DEPT-FINANCE; bản này chỉ xử lý nhánh SoD đặc thù CFO/CTO.
  - Quản trị credentials vault — thuộc REQ-BOD-008 (SYS-INTEGRATION-GW); bản này chỉ tiêu thụ inventory credentials khi sinh báo cáo review.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của feature này là **headless API/domain service trên core backend**: mọi business rule dưới đây được enforce ở tầng service, không tin vào UI; web/mobile chỉ là kênh gọi API.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Hệ thống tự chặn cứng mọi giao dịch tiền vượt ngưỡng do CFO/CTO khởi tạo cho đến khi tôi duyệt | Không ai (kể cả Super Admin) tự duyệt được khoản mình đề xuất — kiểm soát bắt buộc, không dựa vào thiện chí |
| 2 | BOD_CEO | Nhận yêu cầu duyệt kèm đầy đủ ngữ cảnh (loại giao dịch, số tiền quy VND theo tỷ giá snapshot, đối tượng, lý do) qua API hàng đợi "chờ CEO duyệt" | Quyết định nhanh và chính xác, duyệt khẩn ≤4h khi cần mà vẫn có chứng cứ đầy đủ |
| 3 | BOD_CEO | Ký quarterly review quyền của CFO/CTO trong 10 ngày đầu quý trên báo cáo core sinh tự động | Có bằng chứng kiểm soát định kỳ, phát hiện quyền dư thừa |
| 4 | BOD_CFO_CTO | Vai CFO và vai CTO được thiết kế tách rời, giao dịch của tôi bị khóa chờ duyệt không bị coi là lỗi hệ thống | Tôi biết rõ ranh giới vai của mình, và khi công ty tách vai CFO/CTO sau này không phải đổi kiến trúc |
| 5 | BOD_CFO_CTO | Khi xử lý sự cố nghiêm trọng cần truy cập khẩn T3/T4, hệ thống cho mở có thời hạn sau khi tôi khai báo mục đích | Xử lý sự cố không bị nghẽn nhưng mọi lần mở đều minh bạch và có giới hạn |
| 6 | SYS_ADMIN | Mọi thao tác của tôi trên các lệnh khóa "chờ CEO duyệt" đều được ghi immutable audit log, không thể xóa/sửa | Thực thi đúng thẩm quyền sau phê duyệt, không bị nghi ngờ can thiệp log |
| 7 | BOD_CEO | Nhận cảnh báo ngay khi có lệnh mở truy cập khẩn T3/T4 và khi lý do không được khai báo trong 24h | Kiểm soát liên tục điểm tập trung rủi ro, không chỉ theo quý |
| 8 | Hệ thống (job định kỳ) | Tự vô hiệu quyền CFO/CTO chưa được CEO ký review 2 quý liên tiếp | Compensating control không phụ thuộc trí nhớ con người |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ cho portal/mobile-portal). KHÔNG tồn tại vai OPS_CX/FIN_COMPL (DI-006 bị từ chối): trách nhiệm CX Head gán cho OPS_PLAN; Compliance gán cho FIN_L2 + BOD oversight | Service từ chối khởi tạo role/provisioning chứa vai ngoài 18 vai, trả lỗi nghiệp vụ kèm mã vai không hợp lệ |
| BR-002 | (Dùng chung lane) Audit log bất biến append-only hash-chain: mọi thao tác ghi có actor + timestamp + lý do (reason code); log tiền giữ WORM ≥10 năm; không interface xóa/sửa ở mọi tầng kể cả Super Admin | Thao tác thiếu reason code bị từ chối submit; mọi cố gắng sửa/xóa log thất bại ở tầng DB (chỉ INSERT/SELECT) và được ghi vết |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control theo REQ-BOD-002 — chính là tính năng này; quyền chưa review 2 quý liên tiếp tự vô hiệu | Giao dịch dùng quyền đã tự vô hiệu bị chặn với thông báo "quyền chưa được review — chờ kỳ review" |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung: mọi lệnh duyệt của BOD qua API bắt buộc phiên MFA TOTP hợp lệ; PII nhân sự (lương) ở mức Confidential/Restricted | API từ chối lệnh duyệt nếu phiên không có claim MFA; dữ liệu PII trả ra bị mask theo vai |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND (mức mặc định đã chốt tại phiên duyệt 12/09 — DI-001): >200tr/HĐ năm bắt buộc nhánh CEO; quá thẩm quyền tự escalation lên cấp duyệt trên + alert | Giao dịch thiếu chữ ký cấp đủ không giải ngân; escalation phát sự kiện cho alert center (REQ-BOD-006) |
| BR-006 | Cấm gán cặp vai xung đột SoD cùng luồng (đề xuất ≠ duyệt): riêng luồng tiền, khi `BOD_CFO_CTO` là người khởi tạo thì nhánh duyệt bắt buộc chỉ còn `BOD_CEO` — vì CFO là người đề xuất khoản vượt ngưỡng cao nhất | Service chặn hard trong code (không nút override, không cấu hình tắt được), trả mã lỗi SoD vi phạm và ghi log để CFO rà định kỳ |
| BR-007 | Giao dịch tiền vượt ngưỡng do CFO khởi tạo chuyển sang trạng thái `LOCKED_PENDING_CEO`: chưa giải ngân, chưa trừ số dư, chưa phát lệnh phụ thuộc; CEO từ chối → trả về luồng tài chính kèm reason code bắt buộc | Bất kỳ lời gọi thực thi tiếp theo trên giao dịch đang khóa bị từ chối; giao dịch không rơi vào nhánh khóa chạy luồng bình thường |
| BR-008 | Quy VND theo tỷ giá snapshot ngày duyệt trước khi xếp nhánh ngưỡng; snapshot tỷ giá ghi vào bản ghi giao dịch và audit log | Không có snapshot tỷ giá hợp lệ → giao dịch không được xếp nhánh, trả lỗi "thiếu tỷ giá snapshot" |
| BR-009 | Hành vi Super Admin (bao gồm mọi thao tác trên lệnh khóa, truy cập khẩn, credential inventory dùng cho review) ghi immutable audit; người thực thi không thể xóa/sửa log của chính mình | Cố tình can thiệp log bị chặn ở tầng quyền DB; meta-log ghi lại cả hành vi truy cập log |
| BR-010 | Quarterly review quyền CFO/CTO: core sinh báo cáo (role × level, phạm vi dữ liệu T3/T4, credentials từ inventory GW + ngày rotate) trong ngày 1–10 đầu quý; CEO ký qua API có MFA; ký review không ủy quyền — CEO vắng vẫn tự ký | Quá ngày 10 chưa ký → cảnh báo đỏ lên CEO + CFO; quyền chưa review 2 quý liên tiếp tự vô hiệu đến khi review xong |
| BR-011 | Truy cập khẩn T3/T4 (break-glass): mở có thời hạn (mặc định tối đa trong phiên sự cố, được cấu hình), alert CEO ngay tại thời điểm mở, khai báo lý do trong 24h kể từ lúc mở; quá hạn không khai báo → thu hồi quyền khẩn + alert đỏ | Lệnh truy cập khẩn hết hạn mà chưa khai báo lý do bị tự đóng; mọi thao tác trong phiên khẩn bị ghi audit chi tiết |
| BR-012 | Role definition của CFO và CTO lưu tách rời (2 bộ role, 2 bộ quyền) dù gán cho cùng một người; không gộp quyền vào một "super role" | Cấu hình gộp vai bị validation từ chối để bảo đảm tách vai sau này không phải redesign |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Khởi tạo giao dịch tiền (nạp/rút ví, điều chỉnh, hoàn tiền, chiết khấu ngoài biểu) | ✅ | ✅ | ❌ |
| Duyệt giao dịch do CFO khởi tạo vượt ngưỡng (nhánh khóa compensating control) | ✅ (duy nhất) | ❌ (không thể tự duyệt) | ❌ |
| Từ chối giao dịch do CFO khởi tạo | ✅ | ❌ | ❌ |
| Xem hàng đợi "chờ CEO duyệt" (API tra cứu) | ✅ | ✅ (chỉ thấy trạng thái khoản của mình) | ❌ |
| Sinh báo cáo quarterly review quyền CFO/CTO (job hệ thống) | ✅ (xem/ký) | ✅ (xuất nộp — đối tượng bị review) | ❌ |
| Ký quarterly review | ✅ (bắt buộc, không ủy quyền) | ❌ | ❌ |
| Mở truy cập khẩn T3/T4 (break-glass) | ✅ (xem alert + giám sát) | ✅ (khai báo lý do trong 24h) | ❌ (chỉ nhận alert kỹ thuật) |
| Xem audit log compensating control (ai khóa, ai duyệt, ai mở khẩn) | ✅ | ✅ | ❌ (nội dung nghiệp vụ ngoài scope; chỉ meta-log kỹ thuật) |
| Thực thi provisioning sau phê duyệt | ❌ (người duyệt) | ❌ (người đề xuất) | ✅ (thực thi sau duyệt, mọi thao tác bị log) |
| Sửa/xóa audit log hoặc hủy lệnh khóa | ❌ | ❌ | ❌ (không tồn tại interface) |

**Ghi chú phân quyền:** cột theo đúng 3 vai trong registry của REQ-BOD-002; CUSTOMER không xuất hiện trên feature nội bộ này.

---

## 5. Trường Hợp Đặc Biệt

- **CEO không phản hồi khoản khóa quá lâu:** lệnh `LOCKED_PENDING_CEO` tồn tại >4h → alert đỏ qua REQ-BOD-006 và re-push định kỳ; lệnh vẫn khóa — không có "quá hạn tự duyệt", an toàn theo thiết kế.
- **CFO vắng dài ngày:** vai CFO là "đối tượng kiểm soát" nên không cần phản hồi; CEO không được ủy quyền duyệt giao dịch do CFO khởi tạo cho CFO/CTO (vô hiệu compensating control) — CEO duyệt từ xa.
- **Trùng thời điểm quarterly review và sự cố:** CEO vẫn ký review đúng hạn; truy cập khẩn T3/T4 không thay thế review — hai cơ chế độc lập.
- **Giao dịch do CFO khởi tạo vừa thuộc chi khẩn (nền tảng sắp khóa TKQC):** vẫn vào nhánh khóa chờ CEO; CEO duyệt khẩn ≤4h với MFA step-up; hậu kiểm chứng từ 24h theo BR-BOD-001.4.
- **Thay đổi tỷ giá giữa lúc khóa:** hệ thống dùng snapshot tỷ giá đã lưu khi CEO duyệt, không tính lại theo tỷ giá lúc duyệt.
- **Tách vai trong tương lai:** khi tuyển CFO/CTO riêng, chỉ gán lại 2 role definition đã tách sẵn (BR-012) — không đổi code.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh khóa compensating control (Compensating Control Hold — gắn trên giao dịch tiền do CFO/CTO khởi tạo vượt ngưỡng)

**Sơ đồ trạng thái:**
```
[PROPOSED] ──(SoD engine phát hiện CFO khởi tạo + vượt ngưỡng)──► [LOCKED_PENDING_CEO]
                                                                      │
                                                        (CEO duyệt)   │   (CEO từ chối + reason)
                                                                      ▼
                                                                [CEO_APPROVED] ──(thực thi)──► [EXECUTED]
                                                                      │
[PROPOSED] ──(không rơi nhánh SoD)──► [NORMAL_FLOW]            [REJECTED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PROPOSED` | SoD engine đánh giá | `LOCKED_PENDING_CEO` | Hệ thống (tự động) | Người khởi tạo = BOD_CFO_CTO và số tiền quy VND vượt ngưỡng theo nhánh 5/50/200tr |
| `PROPOSED` | Đánh giá luồng thường | `NORMAL_FLOW` | Hệ thống (tự động) | Người khởi tạo không rơi xung đột SoD |
| `LOCKED_PENDING_CEO` | CEO duyệt | `CEO_APPROVED` | BOD_CEO (duy nhất) | Phiên MFA TOTP hợp lệ; đủ chứng từ; snapshot tỷ giá đã lưu |
| `LOCKED_PENDING_CEO` | CEO từ chối | `REJECTED` | BOD_CEO | Bắt buộc nhập reason code |
| `CEO_APPROVED` | Thực thi giải ngân | `EXECUTED` | Hệ thống (service thực thi) | Đủ chữ ký cấp đủ theo BR-005 |
| `LOCKED_PENDING_CEO` | Alert quá 4h | (giữ trạng thái) | Hệ thống | Gửi alert đỏ REQ-BOD-006, re-push định kỳ |

**Quy tắc:**
- `EXECUTED` và `REJECTED` là trạng thái kết thúc — không chuyển tiếp; sửa dữ liệu nhập sai xử lý bằng giao dịch reversal có reason code, không sửa bản ghi gốc.
- Không tồn tại chuyển tiếp từ `LOCKED_PENDING_CEO` về `PROPOSED` hay sang `EXECUTED` nếu thiếu chữ ký CEO — chặn ở tầng service và tầng DB.
- Mọi chuyển tiếp trạng thái ghi audit log hash-chain: actor + timestamp + lý do + giá trị trước/sau.

**Entity phụ:** Phiên truy cập khẩn (Emergency Access Grant): `OPENED` → `REASON_DECLARED` (trong 24h) hoặc `EXPIRED_CLOSED` (hết hạn/không khai báo → thu hồi + alert đỏ); mọi trạng thái nằm trong audit log.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `compensating_control_hold` | `transaction_id`, `initiator_role`, `amount_vnd_snapshot`, `fx_rate_snapshot`, `status`, `reason_code`, `locked_at`, `ceo_decided_at` | FK → giao dịch tiền nguồn | 1 giao dịch tối đa 1 hold đang mở; append-only trên phần lịch sử |
| `sod_conflict_rule` | `rule_code`, `conflict_role_pair`, `flow_scope`, `block_type` (`HARD`/`SOFT`), `effective_from` | Độc lập, tham chiếu bởi engine | Luồng tiền dùng `HARD` — không cấu hình tắt được |
| `quarterly_review_record` | `review_period`, `subject_user`, `role_snapshot`, `data_scope_tier`, `credential_inventory_ref`, `signed_by`, `signed_at` | FK → `user_account`, credential inventory GW | Sinh tự động ngày 1–10 đầu quý; thiếu ký 2 quý → tự vô hiệu quyền |
| `emergency_access_grant` | `grant_id`, `granted_to`, `tier_scope` (T3/T4), `opened_at`, `expires_at`, `reason_declared_at`, `reason_text` | FK → `user_account` | Alert CEO tại thời điểm mở; quá 24h không khai báo → tự đóng |
| `audit_event` | `event_id`, `actor`, `actor_role`, `timestamp`, `action`, `object_ref`, `old_value`, `new_value`, `reason_code`, `prev_hash`, `hash` | Ghi bởi mọi service | Append-only + hash-chain; chi tiết ở FEAT-CORE-RBAC-002 |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điển hình hóa ở Phase 5; dưới đây là phác thảo bắt buộc của Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn hard giao dịch CFO vượt ngưỡng | CFO/CTO có vai đề xuất+duyệt cùng luồng | CFO khởi tạo lệnh nạp ví >50tr | Service tạo hold `LOCKED_PENDING_CEO`, không giải ngân, ghi audit log, không tồn tại nút/API override | [ ] |
| SC-002: CEO duyệt mở khóa | Có hold đang mở | CEO duyệt qua API với MFA | Trạng thái `CEO_APPROVED` → hệ thống thực thi; log ghi actor + timestamp + lý do | [ ] |
| SC-003: CEO từ chối | Có hold đang mở | CEO từ chối không nhập lý do | API từ chối (thiếu reason code); nhập lý do xong → `REJECTED`, trả luồng tài chính | [ ] |
| SC-004: Quarterly review đúng hạn | Đang trong ngày 1–10 đầu quý | Job sinh báo cáo quyền CFO/CTO | Báo cáo gồm role × level × phạm vi T3/T4 + credentials inventory; CEO ký qua API có MFA; log ký lưu vết | [ ] |
| SC-005: Quyền không review 2 quý tự vô hiệu | Kỳ Q-1 và Q-2 không có ký review | Job chạy cuối kỳ | Quyền CFO/CTO rơi vào trạng thái vô hiệu; giao dịch mới bị chặn với thông báo "chờ review" | [ ] |
| SC-006: Truy cập khẩn có kiểm soát | Xảy ra sự cố P1 | CTO mở truy cập T3/T4 | Alert CEO ngay khi mở; grant có `expires_at`; sau 24h chưa khai báo → tự đóng + alert đỏ; toàn bộ thao tác trong phiên nằm trong audit log | [ ] |
| SC-007: Không ai sửa được log | Bất kỳ vai nào (kể cả Super Admin) | Gọi API/SQL cập nhật hoặc xóa `audit_event` | Thất bại ở tầng quyền DB (INSERT/SELECT only); meta-log ghi lại nỗ lực | [ ] |

> **Liên kết:** SC-001→003 map REQ-BOD-002 (compensating control); SC-004→005 map REQ-BOD-002/REQ-BOD-007 (quarterly review); SC-006→007 map REQ-BOD-002 (break-glass + audit bất biến).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (hold, duyệt, review, break-glass) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (SoD engine, alert REQ-BOD-006) | `technical-specs/integration-map.md` |
| Màn hình UI (hàng đợi chờ CEO duyệt, ký review — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB, SYS-MOBILE-INTERNAL (fan-out cùng REQ-BOD-002) |
