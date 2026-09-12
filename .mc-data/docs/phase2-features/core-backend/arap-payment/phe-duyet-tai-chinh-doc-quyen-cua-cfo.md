# Tính Năng: Phê duyệt tài chính độc quyền của CFO

> **Dựa trên:** REQ-BOD-010 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Phê duyệt & Giải ngân (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-002 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-BOD-010] — liên quan: REQ-BOD-002 (compensating control kiêm nhiệm CFO/CTO), REQ-FIN-012 (audit log WORM), REQ-BOD-011 (RBAC nền tảng) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN (FIN_L2 giữ vai đề xuất trong luồng mở kỳ) |
| Độ ưu tiên | Trung bình (MEDIUM) |
| Giai đoạn | Giai đoạn 1 (hạn mức tín dụng TKQC) — mở kỳ khóa + backfill hoàn thiện ở Giai đoạn 2 gắn đối soát |
| Phụ thuộc | FEAT-CORE-ARAP-001 (approval engine + audit log dùng chung); RBAC engine (REQ-BOD-011); đối soát/khóa kỳ (REQ-FIN-004) cho phần mở kỳ Giai đoạn 2 |
| Ghi chú Expert (A7) | `bod.md` có Mục A7 nhưng chưa ghi điều chỉnh cụ thể cho REQ-BOD-010 tại thời điểm phân tích (12/09/2026); theo quyết định DI-006 (12/09/2026) vai FIN_COMPL không được duyệt — trách nhiệm compliance gán cho FIN_L2 xử lý + BOD oversight |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Khóa cứng nhóm lệnh tài chính nhạy cảm nhất (duyệt hạn mức tín dụng TKQC, mở lại kỳ kế toán đã khóa, duyệt backfill/điều chỉnh M2, đồng quyết sự cố M3) vào quyền thực thi độc quyền của vai BOD_CFO_CTO — enforce ở tầng service của SYS-CORE-BACKEND, log + lý do bắt buộc, sao cho bất kỳ vai nào khác gọi các lệnh này đều bị từ chối và attempt đều bị ghi vết.

**Phạm vi:**
- Bao gồm: API/domain service thực thi 4 nhóm lệnh độc quyền — (1) duyệt hạn mức tín dụng TKQC theo nền tảng/khách; (2) mở lại kỳ kế toán đã khóa (theo đề xuất của FIN_L2); (3) duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc; (4) đồng quyết cùng BOD_CEO sự cố M3/cảnh báo đỏ trong 4h; kiểm tra vai tại tầng service; bắt buộc reason code; ghi nhận hai chặn (chốt lần hai) khi kỳ mở lại; backfill ghi ai sửa, giá trị trước/sau, lý do.
- Không bao gồm: giao diện duyệt với ngữ cảnh đầy đủ trên web (counterpart SYS-BCERP-WEB); việc đề xuất mở kỳ do FIN_L2 thực hiện ở màn counterpart; quy trình M1–M3 alert chi tiết (REQ-BOD-006); hạch toán bút toán xuống sổ VAS (FEAT-CORE-ARAP-006).

**Đặc thù touchpoint SYS-CORE-BACKEND:** đây là feature thuần enforcement — không có "nút duyệt" ở bất kỳ kênh nào ngoài lệnh gọi API đã qua check vai tập trung; counterpart WEB chỉ render ngữ cảnh (kỳ số liệu, chênh lệch đối soát, lý do) từ API. Quy tắc "độc quyền" được kiểm tra trong domain service, không tin token UI; mọi attempt (thành công lẫn thất bại) ghi audit log bất biến kèm reason; dữ liệu kỳ kế toán/bút toán phân loại Restricted, tenant isolation bắt buộc.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO | Gọi API `POST /credit-limits` duyệt hạn mức tín dụng TKQC theo nền tảng/khách với lý do bắt buộc | Khống chế rủi ro nợ xấu theo từng cặp nền tảng–khách từ một điểm duy nhất |
| 2 | BOD_CFO_CTO | Thực thi lệnh mở lại kỳ kế toán đã khóa qua API, chỉ sau khi FIN_L2 có phiếu đề xuất | Đảm bảo kỳ chỉ được mở khi có căn cứ và có vết duyệt của mình |
| 3 | BOD_CFO_CTO | Duyệt backfill/điều chỉnh M2 qua API trong 1 ngày làm việc kèm lý do | Quyết toán lại số liệu phục vụ kiểm toán mà không đụng bản ghi gốc |
| 4 | BOD_CEO | Nhận yêu cầu đồng quyết M3/cảnh báo đỏ qua API escalation và ký quyết định chung với CFO trong 4h | Sự cố nghiêm trọng tài chính được quyết bởi đúng 2 vai có thẩm quyền |
| 5 | BOD_CFO_CTO | Nhận push thông báo M3 qua counterpart mobile nhưng ký quyết định trên web/API đầy đủ ngữ cảnh | Thao tác khẩn không đánh đổi hồ sơ đầy đủ (REQ-BOD-010 không có requirement mobile riêng) |
| 6 | FIN_L2 | Gửi phiếu đề xuất mở kỳ qua API đề nghị (`POST /period-reopen-requests`) | Tham gia luồng đúng vai mà không có quyền thực thi |
| 7 | BOD_CEO | Tra cứu mọi attempt gọi lệnh độc quyền (kể cả bị từ chối) qua API audit | Giám sát độc lập quyền của CFO theo compensating control REQ-BOD-002 |
| 8 | SYS_ADMIN | Xem cấu hình nhóm lệnh độc quyền hiện hành (read-only) | Hỗ trợ vận hành mà không tự gán hay thực thi lệnh |

**Diễn giải luồng chính (service layer):** service khai báo registry các lệnh độc quyền CFO (`CFO_EXCLUSIVE_COMMANDS`) — mỗi lệnh có guard role bắt buộc. Khi nhận request: (1) check vai qua RBAC; sai vai → từ chối `CFO_EXCLUSIVE_VIOLATION` + ghi audit log; (2) đúng vai → bắt buộc reason code, nếu thiếu thì rollback; (3) với lệnh mở kỳ: xác nhận tồn tại phiếu đề xuất FIN_L2 ở trạng thái hợp lệ; (4) thực thi lệnh trong một transaction có ghi old→new; (5) với kỳ mở lại: bật cờ yêu cầu "chốt lần hai" — kỳ không thể ở trạng thái mở vĩnh viễn.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-201 | Nhóm lệnh sau chỉ vai `BOD_CFO_CTO` thực thi được (CORE enforce, log + lý do bắt buộc): duyệt hạn mức tín dụng TKQC theo nền tảng/khách; mở lại kỳ kế toán đã khóa (FIN_L2 đề xuất → CFO duyệt); duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc | Vai khác gọi → từ chối `CFO_EXCLUSIVE_VIOLATION`, mọi attempt (kể cả thành công của CFO) ghi audit log bất biến |
| BR-ARAP-202 | Cấm sửa đè không vết: mọi điều chỉnh số liệu kế toán đi qua giao dịch ngược (reversal) có reason code; backfill bắt buộc ghi ai sửa, giá trị trước/sau, lý do — không hard-delete, không UPDATE đè bản ghi gốc | Chặn UPDATE/DELETE ở tầng service + dữ liệu (`IMMUTABLE_RECORD`), chỉ INSERT reversal |
| BR-ARAP-203 | Quyết toán lại quý cũ phục vụ kiểm toán đi qua backfill có phê duyệt CFO — không đụng bản ghi gốc; backfill M2 phải được duyệt trong 1 ngày làm việc kể từ khi tạo | Backfill quá hạn SLA tự escalate cho BOD; backfill không phê duyệt không được áp vào số liệu |
| BR-ARAP-204 | Kỳ mở lại phải chốt lần hai có ghi nhận (re-close) — kỳ không được đứng ở trạng thái mở quá thời hạn cấu hình; khi kỳ mở, chặn các thao tác chốt tự động khác trên kỳ đó | Hết hạn mở mà chưa re-close → alert CFO + tự khóa `FORCED_RECLOSE` có log |
| BR-ARAP-205 | Sự cố M3/cảnh báo đỏ: CFO cùng CEO quyết trong 4h; mobile chỉ nhận push thông báo, quyết định ký trên web/API — không có requirement mobile riêng cho lệnh độc quyền | Quá 4h chưa đồng quyết → escalation BOD + alert đỏ, timestamp từng chặng |
| BR-ARAP-206 | Lệnh độc quyền CFO không ủy quyền (kể cả cho CEO); CFO vắng → lệnh treo đến khi CFO thao tác từ xa; CEO không được duyệt thay các lệnh này (khác với nhánh >200 triệu của FEAT-CORE-ARAP-001) | Service từ chối mọi delegate gắn nhóm lệnh độc quyền (`NON_DELEGABLE_COMMAND`) |
| BR-ARAP-207 | Financial Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC — kể cả khi hạn mức tín dụng đã được CFO duyệt; hạn mức chỉ là trần, không phải lệnh giải ngân | Duyệt hạn mức không tự mở giải ngân; release vẫn phải qua Hard Stop check của FEAT-CORE-ARAP-001/004 |
| BR-ARAP-208 | Mọi lệnh độc quyền và dữ liệu kỳ/bút toán tuân thủ audit log WORM ≥10 năm (REQ-FIN-012); dữ liệu Restricted — mã hóa, meta-log mọi lần xem; connector phần mềm kế toán VAS chỉ nhận bút toán từ chứng từ đã duyệt/khóa kỳ qua cấu hình kết nối ngoại vi trong Settings (DI-004 12/09, vendor-agnostic); legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) sau đó legacy read-only; hóa đơn điện tử TT78/2021 + NĐ123/2020 và phí/thuế phát sinh từ các điều chỉnh được duyệt hạch toán theo FEAT-CORE-ARAP-005/007 | Thiếu audit/meta-log → transaction bị rollback; xuất dữ liệu từ kỳ chưa re-close bị chặn |

---

## 4. Phân Quyền

> Enforce tại tầng service; FIN_L2 xuất hiện với vai đề xuất — không có quyền thực thi lệnh độc quyền.

| Hành động (API) | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | FIN_L2 |
|-----------------|---------|-------------|-----------|--------|
| Duyệt hạn mức tín dụng TKQC | ❌ | ✅ (độc quyền) | ❌ | ❌ |
| Đề xuất mở lại kỳ kế toán | ❌ | ❌ | ❌ | ✅ (đề xuất) |
| Thực thi mở lại kỳ đã khóa | ❌ | ✅ (độc quyền) | ❌ | ❌ |
| Chốt lần hai (re-close) kỳ đã mở | ❌ | ✅ (độc quyền) | ❌ | ❌ |
| Tạo backfill/điều chỉnh M2 | ❌ | ✅ | ❌ | ✅ (soạn thảo) |
| Duyệt backfill/điều chỉnh M2 | ❌ | ✅ (độc quyền, ≤1 ngày làm việc) | ❌ | ❌ |
| Đồng quyết M3/cảnh báo đỏ | ✅ (cùng CFO) | ✅ (cùng CEO) | ❌ | ❌ |
| Xem ngữ cảnh duyệt (kỳ, chênh lệch, lý do) | ✅ | ✅ | ❌ | ✅ |
| Tra cứu audit log lệnh độc quyền | ✅ (giám sát) | ✅ | ❌ | ✅ (theo phạm vi) |
| Gán quyền thực thi nhóm lệnh độc quyền | ✅ (duyệt phân quyền) | ❌ | ❌ (chỉ thực thi sau duyệt) | ❌ |
| Xóa/sửa bản ghi đã ghi sổ | ❌ | ❌ (chỉ reversal có duyệt) | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **CFO vắng mặt dài ngày:** lệnh độc quyền không ủy quyền được — các phiếu đề xuất mở kỳ/backfill treo trong hàng đợi đến khi CFO thao tác từ xa; nếu tồn đọng quá SLA, hệ thống alert BOD_CEO về tắc nghẽn quản trị chứ không tự chuyển quyền.
- **Kiêm nhiệm CFO kiêm CTO:** cùng một người giữ BOD_CFO_CTO — compensating control REQ-BOD-002 vẫn áp: giao dịch tiền do chính người này khởi tạo vượt ngưỡng phải CEO duyệt; lệnh độc quyền của feature này không đè lên cơ chế đó.
- **Cần quyết toán quý cũ phục vụ kiểm toán:** chỉ qua backfill có phê duyệt CFO; bản ghi gốc giữ nguyên, báo cáo dựng lại theo phiên bản hiệu lực — phục vụ tái lập số liệu cho audit mà không vi phạm BR-ARAP-202.
- **Kỳ mở lại bị bỏ dở (người thực hiện điều chỉnh nghỉ giữa chừng):** timer re-close nhắc CFO; nếu quá hạn, hệ thống tự khóa kỳ (`FORCED_RECLOSE`) và ghi nhận danh mục điều chỉnh chưa hoàn tất để theo dõi.
- **Hạn mức tín dụng giảm giữa chu kỳ:** duyệt hạn mức mới effective-dated từ ngày duyệt; các lệnh nạp đã khớp tiền trước đó không hồi tố — chỉ chặn lệnh mới vượt trần.
- **Multi-tenant:** hạn mức tín dụng, kỳ kế toán, backfill đều gắn tenant; API từ chối thao tác chéo tenant, kể cả lệnh của CFO phải chọn đúng ngữ cảnh tenant trong token.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Phiếu đề xuất mở lại kỳ kế toán (`period_reopen_request`)

**Sơ đồ trạng thái:**
```
[DRAFT(FIN_L2)] ──(submit)──► [PROPOSED] ──(CFO duyệt)──► [REOPENED] ──(điều chỉnh xong + re-close)──► [RECLOSED]
                                  │                          │
                                  │ (CFO từ chối)            │ (quá hạn mở)
                                  ▼                          ▼
                              [REJECTED]                 [FORCED_RECLOSED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PROPOSED` | FIN_L2 | Phiếu có căn cứ (kỳ, lý do, danh mục điều chỉnh dự kiến) |
| `PROPOSED` | Duyệt mở kỳ | `REOPENED` | BOD_CFO_CTO (độc quyền) | Reason code bắt buộc; audit log old→new |
| `PROPOSED` | Từ chối | `REJECTED` | BOD_CFO_CTO | Reason code bắt buộc |
| `REOPENED` | Re-close | `RECLOSED` | BOD_CFO_CTO | Điều chỉnh hoàn tất; ghi nhận hai chặn |
| `REOPENED` | Tự khóa quá hạn | `FORCED_RECLOSED` | Service tự động | Timer hết hạn mở; alert CFO; log danh mục điều chỉnh dở |

**Quy tắc:**
- Mọi chuyển trạng thái do đúng một vai kích hoạt theo bảng; không có nhánh hồi lại `REOPENED` từ `RECLOSED` — cần mở lại thì tạo phiếu mới.
- `REJECTED`, `RECLOSED`, `FORCED_RECLOSED` là trạng thái kết thúc.
- Song song, entity `backfill_adjustment` có vòng đời riêng: `DRAFT` → `PENDING_CFO_APPROVAL` → `APPLIED`/`REJECTED`, SLA duyệt 1 ngày làm việc, áp dụng bằng INSERT reversal có reason code.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `credit_limit` | `tenant_id`, `platform`, `customer_id`, `limit_amount_vnd`, `effective_from`, `effective_to`, `approved_by`, `reason` | FK → `tenants.id`, `customers.id` | Effective-dated, không hồi tố; duyệt độc quyền CFO |
| `accounting_period` | `tenant_id`, `period_code`, `status` (OPEN/CLOSED/REOPENED/RECLOSED), `closed_at`, `reopened_by`, `reclosed_at` | FK → `tenants.id` | Trạng thái kỳ kiểm tra ở mọi API ghi số liệu |
| `period_reopen_request` | `period_id`, `proposed_by` (FIN_L2), `reason`, `status`, `approved_by`, `approved_at` | FK → `accounting_period.id` | Luồng đề xuất → duyệt độc quyền |
| `backfill_adjustment` | `target_entity`, `target_id`, `old_value`, `new_value`, `reason_code`, `requested_by`, `approved_by`, `applied_at`, `reversal_entry_id` | FK → bản ghi gốc + `ledger_entries.id` | INSERT-only; SLA duyệt 1 ngày làm việc |
| `cfo_command_registry` | `command_code`, `exclusive_role`, `delegable`, `reason_required` | Độc lập (cấu hình service) | Nguồn sự thật cho guard role |
| `audit_log` | `entity`, `entity_id`, `actor`, `old_value`, `new_value`, `reason_code`, `hash_prev`, `hash_self` | Polymorphic | Append-only, hash-chain, WORM ≥10 năm |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Sai vai gọi lệnh độc quyền | FIN_L2 gọi API duyệt hạn mức tín dụng | Service check vai | Từ chối `CFO_EXCLUSIVE_VIOLATION`, attempt ghi audit log | [ ] |
| SC-002: Mở kỳ thiếu phiếu đề xuất | Không có `period_reopen_request` hợp lệ | CFO gọi API mở kỳ | Từ chối `PROPOSAL_REQUIRED` | [ ] |
| SC-003: Duyệt hạn mức thiếu lý do | CFO gọi API, reason rỗng | Thực thi | Rollback, trả `REASON_REQUIRED` | [ ] |
| SC-004: Backfill không sửa đè | Backfill được CFO duyệt | Áp dụng | Chỉ INSERT reversal old→new; bản ghi gốc nguyên vẹn | [ ] |
| SC-005: Re-close bắt buộc | Kỳ `REOPENED` quá hạn mở | Timer chạy | `FORCED_RECLOSED` + alert CFO + log danh mục dở | [ ] |
| SC-006: M3 quá 4h | Cảnh báo đỏ chưa đồng quyết | Hết 4h | Escalation BOD, alert đỏ, timestamp chặng | [ ] |
| SC-007: Hard Stop không bị hạn mức vô hiệu | Hạn mức tín dụng đã duyệt, lệnh nạp chưa khớp tiền | Release giải ngân | Vẫn bị chặn bởi Hard Stop khớp tiền | [ ] |

> **Liên kết:** SC-001–SC-006 map REQ-BOD-010; SC-007 map REQ-FIN-006 (điều kiện tiên quyết mọi giải ngân TKQC).

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (CFO exclusive commands) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/bod/bod.md` (B10 — BR-BOD-010.1–010.4, B2 compensating control), `phase1-business/P1-02-business-workflow.md` (kỳ đã chốt chỉ CFO mở lại có phiếu lý do) |
