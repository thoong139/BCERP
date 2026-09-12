# Tính Năng: Compensating Control Kiêm Nhiệm CFO kiêm CTO

> **Dựa trên:** REQ-BOD-002 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-001` — bản riêng của touchpoint SYS-BCERP-WEB (các bản counterpart: SYS-CORE-BACKEND, SYS-MOBILE-INTERNAL).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-001 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-002 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — chặn hard từ giao dịch tiền đầu tiên) |
| Phụ thuộc | FEAT-ERP-RBAC-005 (nền tảng RBAC & SSO/MFA — point check quyền tập trung), FEAT-ERP-RBAC-002 (audit log giám sát) |
| Ghi chú Expert (A7) | A7 của `bod.md` đã mở mục đánh giá chuyên gia; các điều chỉnh ảnh hưởng trực tiếp feature này đến từ stakeholder review 12/09: DI-001 chốt mức ngưỡng mặc định 5/50/200 triệu VND (không còn `[CẦN CHỐT SỐ]`), DI-006 gỡ vai OPS_CX/FIN_COMPL khỏi registry (18 vai) — chi tiết tại `bod.md` Mục A7 và `stakeholder-review.md` Phần F.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
BC Agency hiện có một người kiêm nhiệm đồng thời vai CFO và vai CTO (đồng thời là Super Admin) — đây là điểm tập trung rủi ro duy nhất của toàn hệ thống BCERP vì người này vừa đề xuất vừa có khả năng can thiệp kỹ thuật vào mọi giao dịch tiền. Tính năng này cung cấp compensating control trên web nội bộ: tự phát hiện xung đột vai đề xuất–duyệt, khóa hard mọi giao dịch tiền do BOD_CFO_CTO khởi tạo cho đến khi BOD_CEO duyệt, và cung cấp màn hình ký quarterly review quyền của CFO/CTO để kiểm soát này có bằng chứng định kỳ.

**Phạm vi:**
- Bao gồm: hàng đợi web "Chờ CEO duyệt" cho giao dịch tiền do CFO khởi tạo (nạp/rút ví QC, điều chỉnh số dư, đổi tỷ giá, hoàn tiền, chiết khấu ngoài biểu); màn hình ký quarterly review quyền BOD_CFO_CTO (role × level, phạm vi dữ liệu T3/T4, credentials từ inventory của GW) trong 10 ngày đầu quý; hiển thị trạng thái machine-state của giao dịch bị khóa/khóa mở; form khai báo lý do cho truy cập khẩn T3/T4 có thời hạn; bảng cảnh báo cố gắng vi phạm SoD bị chặn.
- Không bao gồm: enforcement chặn hard ở tầng API/domain service (SYS-CORE-BACKEND thực thi — web chỉ hiển thị đúng trạng thái và nhận kết quả); push duyệt khẩn ≤4h trên mobile nội bộ (SYS-MOBILE-INTERNAL — bản counterpart); inventory credentials/token (SYS-INTEGRATION-GW); alert engine đa kênh (REQ-BOD-006); lưu trữ log WORM (REQ-FIN-012, FEAT-ERP-RBAC-007).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Thấy hàng đợi riêng "Chờ CEO duyệt" liệt kê mọi giao dịch tiền do BOD_CFO_CTO khởi tạo, kèm ngữ cảnh đầy đủ (khách, TKQC, số tiền, căn cứ, chứng từ) | Quyết định duyệt/từ chối trên một màn hình duy nhất, không bỏ sót khoản nào |
| 2 | BOD_CEO | Duyệt hoặc từ chối từng khoản với reason code bắt buộc, trạng thái chuyển ngay trên web | Có bằng chứng kiểm soát rõ ràng, khoản từ chối được trả về luồng tài chính kèm lý do |
| 3 | BOD_CEO | Nhận nhắc và ký quarterly review quyền của CFO/CTO trong 10 ngày đầu quý ngay trên web | Hoàn tất nghĩa vụ kiểm soát định kỳ đúng hạn, có chữ ký lưu làm bằng chứng |
| 4 | BOD_CFO_CTO | Xem trước danh sách quyền, phạm vi dữ liệu và credentials của chính mình để xuất nộp CEO review | Hiểu rõ mình bị kiểm soát những gì và chuẩn bị dữ liệu đối chiếu đầy đủ |
| 5 | BOD_CFO_CTO | Khi cần truy cập khẩn dữ liệu T3/T4 xử lý sự cố, mở quyền có thời hạn và khai báo lý do ngay trên web | Xử lý sự cố nhanh nhưng vẫn để lại dấu vết kiểm soát minh bạch |
| 6 | SYS_ADMIN | Xem trạng thái các lệnh thực thi gắn với giao dịch đã được CEO duyệt (không thấy nội dung T3/T4 ngoài scope) | Thực thi đúng lệnh sau phê duyệt, không tự ý can thiệp |
| 7 | BOD_CEO | Xem thống kê các lần vi phạm SoD bị hệ thống chặn (ai, khi nào, loại xung đột) | Rà soát định kỳ và phát hiện sớm xu hướng lạm quyền |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính nằm ở SYS-CORE-BACKEND; SYS-BCERP-WEB cấm tự check quyền cục bộ, chỉ gọi điểm check quyền tập trung và hiển thị đúng machine-state trả về.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa trong registry (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không tồn tại vai OPS_CX và FIN_COMPL (DI-006 bị từ chối) — trách nhiệm CX Head gán vào OPS_PLAN, trách nhiệm Compliance gán vào FIN_L2 kèm oversight độc lập của BOD | Cấu hình vai ngoài 18 vai registry bị từ chối khi lưu; UI không hiển thị vai không hợp lệ |
| BR-002 | Giao dịch tiền vượt ngưỡng do BOD_CFO_CTO khởi tạo bị khóa hard "chờ CEO duyệt" — không nút override, không đường tắt trên web; cấm gán cặp vai xung đột SoD cùng luồng (đề xuất ≠ duyệt) | Mọi cố gắng vi phạm bị chặn, ghi log bất biến để CFO/BOD rà; UI hiển thị trạng thái khóa kèm lý do |
| BR-003 | Hành vi Super Admin (bao gồm thao tác trên chính giao dịch này) ghi immutable audit log — người dùng không thể xóa/sửa log của chính mình; log lưu theo chuỗi hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do | Thiếu reason code khi submit → không cho submit; attempt xóa/sửa log bị từ chối ở mọi tầng và ghi log |
| BR-004 | Quarterly review quyền BOD_CFO_CTO bắt buộc: CEO ký trong 10 ngày đầu quý; quyền chưa được review 2 quý liên tiếp tự vô hiệu cho đến khi review xong; kỳ review không ủy quyền — CEO vắng vẫn tự ký (mobile là kênh khẩn của bản counterpart) | Hết ngày 10 chưa ký → nhắc escalation; quyền quá 2 quý không review → chuyển SUSPENDED, web hiển thị "đã vô hiệu tự động" |
| BR-005 | Truy cập khẩn T3/T4 chỉ mở có thời hạn, alert CEO ngay khi mở, bắt buộc khai báo lý do trong 24h kể từ lúc mở | Hết 24h không có lý do → alert đỏ BOD_CEO (REQ-BOD-006) và quyền khẩn tự đóng |
| BR-006 | SSO/MFA tập trung: mọi thao tác duyệt/ký của CEO trên web yêu cầu phiên SSO hợp lệ; duyệt khẩn qua mobile (counterpart) bắt buộc MFA step-up; PII nhân sự liên quan (thu nhập của người kiêm nhiệm) ở mức Confidential/Restricted — chỉ hiển thị cho vai được phép | Phiên không hợp lệ/MFA chưa đăng ký → chặn thao tác, chuyển sang màn đăng ký MFA |
| BR-007 | Phê duyệt theo ngưỡng 5/50/200 triệu VND đã chốt (DI-001): giao dịch CFO khởi tạo rơi vào bất kỳ nhánh ngưỡng nào vẫn phải CEO duyệt; quá SLA duyệt → escalate lên cấp trên và alert đỏ | Thiếu một chữ ký trong chuỗi duyệt → chặn giải ngân, hiển thị trạng thái "chờ duyệt bổ sung" |
| BR-008 | Kiến trúc vai CFO và vai CTO thiết kế tách rời (2 binding vai độc lập) để tách vai sau này không phải redesign hệ thống | Không áp dụng tách cứng trong code theo người; cấu hình người giữ vai là dữ liệu, không phải hằng số |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | Vai khác (registry 18 vai) |
|-----------|---------|-------------|-----------|----------------------------|
| Xem hàng đợi "Chờ CEO duyệt" | ✅ | ◐ (xem khoản của mình ở chế độ chờ, không tự duyệt) | ❌ | ❌ |
| Duyệt/từ chối giao dịch CFO khởi tạo | ✅ (duyệt độc quyền) | ❌ (không tự duyệt khoản mình đề xuất) | ❌ | ❌ |
| Xem báo cáo quyền CFO/CTO (role × level, T3/T4, credentials) | ✅ | ✅ (xuất nộp — bị review) | ❌ (không xem giá trị T3/T4) | ❌ |
| Ký quarterly review | ✅ (không ủy quyền) | ❌ | ❌ | ❌ |
| Mở truy cập khẩn T3/T4 + khai lý do | ✅ (nhận alert) | ✅ (người mở, khai lý do 24h) | ❌ | ❌ |
| Thực thi lệnh sau duyệt (gỡ khóa, cấu hình) | ❌ | ◐ (đề xuất) | ✅ (sau duyệt, mọi thao tác bị log) | ❌ |
| Xem thống kê vi phạm SoD bị chặn | ✅ | ✅ (rà định kỳ theo REQ-BOD-006) | ❌ | ❌ |
| Xóa/sửa audit log (bất kể vai) | ❌ | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- CEO đi công tác dài ngày trong 10 ngày đầu quý: kỳ quarterly review không ủy quyền — CEO ký từ xa; nếu vẫn quá hạn, các quyền chưa review tự vô hiệu (an toàn theo thiết kế), web hiển thị danh sách quyền bị vô hiệu và quy trình khôi phục sau khi ký.
- Giao dịch CFO khởi tạo nằm trong chi khẩn (nền tảng sắp khóa TKQC): vẫn phải qua khóa "chờ CEO duyệt" — kênh khẩn ≤4h là push mobile (bản counterpart SYS-MOBILE-INTERNAL), web vẫn ghi nhận kết quả và hiển thị hồ sơ đầy đủ.
- SYS_ADMIN nhận được yêu cầu "gỡ khóa giúp" từ bất kỳ ai: bị từ chối — SYS_ADMIN chỉ thực thi sau lệnh đã duyệt của CEO, mọi attempt đều log; SYS_ADMIN không nhận ủy quyền Super Admin.
- Người kiêm nhiệm từ chức hoặc công ty tách vai CFO/CTO thành 2 người: chỉ cần cập nhật binding vai trên hồ sơ user (SCD2, hiệu lực theo ngày) — không sửa code, luồng compensating control tự chuyển sang chế độ chuẩn (xung đột biến mất, khóa tự không còn kích hoạt).
- Truy cập khẩn T3/T4 mở đúng lúc mất kết nối mạng: web hàng đợi (offline-capable ở mức form) và sync khi có lại mạng; timestamp hợp lệ lấy theo thời điểm CORE ghi nhận, không theo thời điểm device.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh giao dịch tiền do BOD_CFO_CTO khởi tạo (trạng thái hiển thị trên web)

**Sơ đồ trạng thái:**
```
[CREATED] ──(CORE phát hiện CFO khởi tạo)──► [LOCKED_PENDING_CEO]
                                                 │           │
                                    (CEO duyệt)  │           │ (CEO từ chối)
                                                 ▼           ▼
                                          [CEO_APPROVED]  [REJECTED]
                                          → giải ngân      → trả luồng tài chính kèm reason code
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `CREATED` | Core phát hiện xung đột vai đề xuất–duyệt | `LOCKED_PENDING_CEO` | Hệ thống (CORE) | Giao dịch tiền vượt ngưỡng do BOD_CFO_CTO khởi tạo |
| `LOCKED_PENDING_CEO` | CEO duyệt (kèm MFA) | `CEO_APPROVED` | BOD_CEO | Reason code nhập bắt buộc; giấy tờ chứng từ đã xem |
| `LOCKED_PENDING_CEO` | CEO từ chối | `REJECTED` | BOD_CEO | Reason code bắt buộc; trả về luồng tài chính |
| `LOCKED_PENDING_CEO` | Quá SLA duyệt | `LOCKED_PENDING_CEO` + escalate | Hệ thống | Nhắc 24h; escalate cấp trên + alert đỏ (REQ-BOD-006) |
| `CEO_APPROVED` | Giải ngân | Kết thúc luồng | Hệ thống (CORE) | Đủ chữ ký theo ma trận ngưỡng 5/50/200 triệu |
| `REJECTED` | Tạo lại giao dịch | `CREATED` | BOD_CFO_CTO | Giao dịch mới, giữ dấu vết giao dịch cũ bị từ chối |

**Quy tắc:**
- Không tồn tại chuyển tiếp từ `LOCKED_PENDING_CEO` về `CREATED` — không có "thu hồi đề xuất để né kiểm soát"; muốn hủy phải qua lệnh hủy có lý do và bị log.
- `CEO_APPROVED` và `REJECTED` là trạng thái kết thúc — không chuyển tiếp ngược.
- Song song, entity "Quyền CFO/CTO" có chu kỳ: `ACTIVE` → (CEO ký quý) → `ACTIVE` (ký mới) hoặc `SUSPENDED` (2 quý không ký) → `ACTIVE` sau review; `SUSPENDED` do hệ thống tự đặt, không do thao tác tay.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `financial_transaction` | `id`, `initiated_by`, `amount_vnd`, `threshold_band`, `sod_lock_state`, `ceo_approval_id`, `reason_code` | FK → `users.id` (initiated_by), FK → `approvals.id` | SOD lock do CORE đặt; WEB chỉ đọc hiển thị |
| `approval_record` | `id`, `transaction_id`, `approver_id`, `channel`, `decision`, `reason_code`, `decided_at` | FK → `financial_transaction.id` | Immutable; kênh web/mobile ghi rõ |
| `quarterly_review_record` | `id`, `period`, `reviewed_user_id`, `role_snapshot`, `scope_t3_t4`, `credential_ref`, `signed_by`, `signed_at` | FK → `users.id` (reviewed_user_id, signed_by) | Sinh tự động ngày 1 đầu quý; chữ ký là bằng chứng |
| `emergency_access_grant` | `id`, `granted_to`, `data_tier`, `opened_at`, `expires_at`, `reason`, `reason_declared_at`, `ceo_alerted_at` | FK → `users.id` | Tự đóng khi hết hạn; thiếu lý do 24h → alert đỏ |
| `sod_violation_log` | `id`, `user_id`, `conflict_type`, `blocked_at`, `context` | FK → `users.id` | Bất biến; nguồn cho thống kê rà định kỳ |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khóa giao dịch CFO khởi tạo | BOD_CFO_CTO tạo lệnh nạp ví vượt ngưỡng đã duyệt | CORE phân loại xung đột vai | Web hiển thị `LOCKED_PENDING_CEO` trong hàng đợi CEO; không có nút override ở bất kỳ vai nào | [ ] |
| SC-002: CEO duyệt kèm reason | Hàng đợi có 1 khoản chờ | BOD_CEO duyệt thiếu reason code | Từ chối submit cho đến khi nhập reason; sau khi hợp lệ chuyển `CEO_APPROVED` và CORE giải ngân | [ ] |
| SC-003: Quá hạn quarterly review | Quý mới bắt đầu, đến ngày 10 CEO chưa ký | Hệ thống chạy job đo hạn | Escalation + alert; nếu trôi qua 2 quý liên tiếp không ký, quyền tự chuyển `SUSPENDED` và web hiển thị trạng thái vô hiệu | [ ] |
| SC-004: Truy cập khẩn thiếu lý do | BOD_CFO_CTO mở quyền khẩn T3/T4 | Qua 24h chưa khai lý do | Alert đỏ gửi BOD_CEO; quyền khẩn tự đóng; toàn bộ chuỗi sự kiện vào audit log bất biến | [ ] |

> **Liên kết:** SC-001/002 → REQ-BOD-002; SC-003 → REQ-BOD-002 (quyền chưa review 2 quý tự vô hiệu); SC-004 → REQ-BOD-002 (truy cập khẩn khai lý do 24h).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart enforcement | `.mc-data/docs/phase2-features/core-backend/rbac-audit/` (SYS-CORE-BACKEND — chặn hard), `mobile-internal/rbac-audit/` (duyệt khẩn ≤4h) |
