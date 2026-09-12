# Tính Năng: Công nợ AR/AP + aging + nhắc nợ

> **Dựa trên:** REQ-FIN-007 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Công nợ (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-003-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-003 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-007] — liên quan: REQ-FIN-001 (ledger dùng chung), REQ-FIN-006 (Hard Stop khớp tiền), REQ-FIN-013 (connector sổ VAS), REQ-FIN-012 (audit log WORM) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Sổ phụ ví/ledger append-only (REQ-FIN-001) và xác nhận khớp tiền (REQ-FIN-006) phải sẵn sàng trước; FEAT-CORE-ARAP-004 (luồng duyệt chi tạo bút toán AP); FEAT-CORE-ARAP-006 (đối chiếu sổ VAS dùng số dư AR/AP) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; các quy tắc aging/clawback lấy từ BR-FIN-303 (call-1 finance-expert) — không có điều chỉnh expert nào thay đổi business rules dưới đây |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thay thế quản lý công nợ bằng Sheets bằng domain service tính toán AR (phải thu khách) và AP (phải trả nền tảng) trên cùng ledger của BCERP, tự động phân bucket aging, gửi nhắc nợ tự động cho AR quá hạn và theo dõi hạn thanh toán AP để tránh gián đoạn tài khoản quảng cáo — đồng thời cung cấp số dư AR làm nguồn sự thật cho clawback hoa hồng của SALES/HR ở Giai đoạn 3.

**Phạm vi:**
- Bao gồm: service tính aging AR/AP theo bucket 0–30 / 31–60 / 61–90 / >90 ngày; job nhắc nợ tự động AR quá hạn theo lịch cấu hình; theo dõi hạn thanh toán AP nền tảng với cảnh báo trước hạn; API tra cứu công nợ theo khách/nền tảng/giao dịch; tách công nợ tranh chấp khỏi aging bình thường; ghi nhận lịch sử nhắc nợ; xuất số dư AR phục vụ clawback (nợ >90 ngày → clawback 100%); đối chiếu số dư với sổ phần mềm kế toán VAS qua cấu hình kết nối ngoại vi trong Settings.
- Không bao gồm: màn hình aging và lịch sử nhắc nợ trên web (counterpart SYS-BCERP-WEB); tạo lệnh thu/chi mới (FEAT-CORE-ARAP-004); phát hành hóa đơn điện tử đòi nợ (FEAT-CORE-ARAP-005); tính hoa hồng/clawback chi tiết (module COMMISSION-QUOTA, Giai đoạn 3).

**Đặc thù touchpoint SYS-CORE-BACKEND:** toàn bộ logic aging, nhắc nợ, clawback tính toán chạy ở tầng service — counterpart web/mobile chỉ đọc kết quả qua API; job aging/nhắc nợ chạy server-side theo lịch, không phụ thuộc ai mở màn hình; ledger append-only làm nguồn duy nhất, mọi điều chỉnh công nợ qua giao dịch reversal có reason code; dữ liệu công nợ phân loại Restricted — tenant isolation (RLS + filter API 2 lớp), mọi truy cập ghi log theo BR-FIN-603.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Gọi API aging báo cáo bucket 0–30/31–60/61–90/>90 theo khách và theo nền tảng | Biết tình trạng công nợ realtime không phải cộng tay từ Sheets |
| 2 | FIN_L1 | Nhận danh sách AR quá hạn qua API kèm lịch sử nhắc nợ từng khách | Ưu tiên theo dõi đúng khoản nguy cơ cao |
| 3 | FIN_L2 | Cấu hình lịch nhắc nợ tự động qua API (chu kỳ, kênh, mẫu) | Nhắc nợ chạy đều theo chuẩn tối thiểu mà không cần nhớ tay |
| 4 | FIN_L2 | Đánh dấu công nợ tranh chấp qua API để tách khỏi aging bình thường | Không để khoản đang tranh chấp làm méo báo cáo và clawback |
| 5 | BOD_CFO_CTO | Xem tổng quan AR/AP + aging trend qua API tổng hợp | Ra quyết định chính sách tín dụng và duyệt hạn mức (nối FEAT-CORE-ARAP-002) |
| 6 | FIN_L2 | Nhận cảnh báo AP sắp đến hạn thanh toán nền tảng | Trả tiền đúng hạn, tránh nền tảng khóa TKQC gây gián đoạn vận hành |
| 7 | Hệ thống (job) | Tự tính lại aging mỗi ngày và ghi snapshot phục vụ truy vết | Báo cáo clawback/hoa hồng GĐ3 dùng đúng số tại thời điểm chốt |
| 8 | SALES (qua module hoa hồng GĐ3, gọi API read-only) | Lấy số dư AR theo khách từ nguồn sự thật duy nhất | Tính hoa hồng thực nhận và clawback nợ >90 ngày theo đúng quy chế |

**Diễn giải luồng chính (service layer):** job hằng ngày (1) đọc ledger REQ-FIN-001 lấy các dòng AR/AP chưa tất toán, (2) tính số ngày quá hạn theo ngày đáo hạn (AR theo hợp đồng/hóa đơn; AP theo hạn nền tảng), (3) gán bucket và cập nhật snapshot aging, (4) sinh hàng đợi nhắc nợ cho AR quá hạn theo lịch cấu hình và ghi `dunning_history`, (5) sinh cảnh báo AP trước hạn, (6) đánh c flag clawback cho AR >90 ngày. Mọi bước idempotent, chạy lại không sinh nhắc trùng.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-301 | Aging AR (khách) và AP (nền tảng) tính theo bucket 0–30 / 31–60 / 61–90 / >90 ngày từ hạn thanh toán; nguồn dữ liệu duy nhất là ledger REQ-FIN-001 (append-only) — cấm tính aging từ bảng phụ không đối soát | Service từ chối dữ liệu ngoài ledger (`LEDGER_SOURCE_REQUIRED`) |
| BR-ARAP-302 | Số dư AR là nguồn sự thật clawback hoa hồng: nợ >90 ngày → clawback 100% phần chưa thu; API cung cấp số cho module hoa hồng (GĐ3) kèm snapshot thời điểm chốt; không module nào tự tính lại AR từ nguồn khác | Truy xuất AR ngoài API chuẩn bị từ chối; sai khác số → ticket discrepancy |
| BR-ARAP-303 | Nhắc nợ tự động AR quá hạn theo lịch cấu hình (mẫu, chu kỳ, kênh qua counterpart web/SLA-NOTIF); mỗi lần nhắc ghi `dunning_history` (thời điểm, mẫu, người nhận); nhắc lại không trùng trong chu kỳ đã cấu hình | Job nhắc trùng → idempotency key chặn; thiếu history → rollback job |
| BR-ARAP-304 | Theo dõi hạn thanh toán AP nền tảng: cảnh báo trước hạn theo cấu hình (mặc định T-7 và T-2); AP quá hạn bật alert nguy cơ gián đoạn TKQC và đưa vào hàng ưu tiên duyệt chi (nối FEAT-CORE-ARAP-004) | Quá hạn không cảnh báo → incident log; alert đỏ theo REQ-BOD-006 |
| BR-ARAP-305 | Khách có hợp đồng riêng về chu kỳ thanh toán → aging và nhắc nợ theo hợp đồng, không thấp hơn chuẩn tối thiểu (đối soát tuần, chốt tháng); hợp đồng là cấu hình effective-dated, không hồi tố | Job đọc sai chu kỳ → cảnh báo cấu hình; nhắc sớm hơn hợp đồng bị chặn |
| BR-ARAP-306 | Công nợ tranh chấp → tách ticket riêng khỏi aging bình thường đến khi giải quyết; trong thời gian tranh chấp, khoản không tham gia clawback; kết quả giải quyết cập nhật lại aging có audit log | Tranh chấp không tách → báo cáo sai → bắt buộc correction có reason code |
| BR-ARAP-307 | Financial Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006): AR chỉ ghi nhận "đã thu" khi tiền về tài khoản BC và khớp số với lệnh/ghi nhận thu; không chấp nhận "khách hứa chuyển" hay bằng chứng ngoài hệ thống để tất toán AR | Tất toán AR không có evidence → từ chối `SETTLEMENT_EVIDENCE_REQUIRED` + log |
| BR-ARAP-308 | Điều chỉnh công nợ chỉ qua giao dịch reversal có reason code; audit log bất biến ≥10 năm; connector phần mềm kế toán VAS nhận số dư/bút toán công nợ qua cấu hình kết nối ngoại vi trong Settings (DI-004 12/09 — vendor-agnostic, import/export chuẩn + adapter API), legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) rồi legacy read-only; hóa đơn điện tử TT78/2021 + NĐ123/2020 liên quan đòi nợ và phí nền tảng/thuế phát sinh xử lý theo FEAT-CORE-ARAP-005/007; giải ngân trả AP phải qua Hard Stop và SoD ngưỡng 5/50/200 triệu | Thiếu audit log/reason → rollback; xuất bút toán từ kỳ chưa khóa bị chặn |

---

## 4. Phân Quyền

> Enforce tại tầng service; counterpart web chỉ hiển thị theo quyền đã check qua RBAC tập trung.

| Hành động (API) | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------------|--------|--------|-------------|
| Xem aging khách được gán | ✅ | ✅ | ✅ |
| Xem aging toàn bộ khách | ❌ | ✅ | ✅ |
| Xem AP nền tảng + cảnh báo hạn | ✅ | ✅ | ✅ |
| Cấu hình lịch/mẫu nhắc nợ | ❌ | ✅ | ✅ (duyệt) |
| Kích hoạt/tạm dừng nhắc nợ cho 1 khách | ❌ | ✅ (kèm lý do) | ❌ |
| Đánh dấu/gỡ tranh chấp công nợ | ❌ | ✅ (kèm lý do) | ✅ (oversight) |
| Tất toán AR khi có thu (gắn evidence) | ✅ | ✅ | ❌ |
| Điều chỉnh công nợ (reversal) | ❌ | ✅ (kèm reason code) | ✅ (duyệt độc quyền theo FEAT-CORE-ARAP-002 khi liên quan kỳ khóa) |
| Xuất số AR cho clawback/hoa hồng (GĐ3) | ✅ (API chuẩn) | ✅ | ✅ |
| Xem audit log công nợ | ✅ (theo phạm vi) | ✅ | ✅ |
| Xóa dòng công nợ | ❌ | ❌ | ❌ (chỉ reversal có duyệt) |

---

## 5. Trường Hợp Đặc Biệt

- **Khách có nhiều hợp đồng với chu kỳ thanh toán khác nhau:** aging tính riêng theo từng hợp đồng/hóa đơn rồi cộng dồn về khách; nhắc nợ theo chu kỳ của từng khoản nợ, không áp chung một mốc cho cả khách.
- **Thu một phần trên nhiều khoản nợ:** thanh toán không chỉ định khoản → service áp theo quy tắc FIFO theo hạn đáo hạn (khoản đến hạn trước được trừ trước); ghi log phân bổ để truy vết.
- **AR phát sinh từ hoàn tiền trừ lùi (netting):** nếu khách có cả AR và hoàn tiền đến cùng khách, cho phép bù trừ có phê duyệt FIN_L2 kèm lý do — không tự netting tự động; bù trừ là giao dịch có vết.
- **Nền tảng trừ công nợ AP bằng số dư tín dụng/credit note:** ghi nhận là giao dịch giảm AP dẫn chiếu chứng từ nền tảng; không xóa dòng AP gốc.
- **Job aging lỗi giữa chừng:** chạy lại phải idempotent — snapshot aging ghi theo ngày, job ngày hôm sau ghi đè snapshot cùng ngày bằng version mới, giữ lịch sử version phục vụ truy vết.
- **Khách nước ngoài đa tiền tệ:** AR ghi theo tiền tệ gốc và quy VND theo tỷ giá snapshot dùng chung (REQ-FIN-004) tại thời điểm báo cáo; aging theo VND, nguyên tệ lưu kèm.
- **Dữ liệu legacy PMS:** sau migrate chọn lọc (master data + dự án active + payment history 12 tháng), công nợ phát sinh trước ngày go-live ở legacy chỉ read-only — tra cứu qua connector, không cập nhật hai chiều.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Khoản công nợ (`receivable_payable`)

**Sơ đồ trạng thái:**
```
[OPEN] ──(đến hạn chưa thu/trả)──► [OVERDUE] ──(bucket >90)──► [SEVERELY_OVERDUE] ──(clawback flag)──► [CLAWBACK_FLAGGED]
   │                                  │                              │
   │ (dispute)                        │ (dispute)                    │ (settle)
   ▼                                  ▼                              ▼
[DISPUTED] ──(resolved → quay lại bucket tương ứng)            [SETTLED]
[OPEN/OVERDUE] ──(thanh toán đủ)──► [SETTLED]
[SEVERELY_OVERDUE] ──(hủy nợ có duyệt)──► [WRITTEN_OFF]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Job aging | `OVERDUE` | Service tự động | Quá hạn theo hạn hợp đồng/hóa đơn/AP |
| `OPEN`/`OVERDUE` | Settle | `SETTLED` | FIN_L1 (gắn evidence khớp tiền) | Evidence sao kê/ghi nhận thu; Hard Stop thỏa |
| `OPEN`/`OVERDUE` | Đánh dấu tranh chấp | `DISPUTED` | FIN_L2 (lý do bắt buộc) | Tạo ticket tranh chấp liên kết |
| `DISPUTED` | Giải quyết | Trạng thái bucket tương ứng | FIN_L2 | Kết quả giải quyết có audit log |
| `OVERDUE` | Job aging | `SEVERELY_OVERDUE` | Service tự động | Quá hạn >90 ngày |
| `SEVERELY_OVERDUE` | Đánh cờ clawback | `CLAWBACK_FLAGGED` | Service tự động | Xuất signal cho module hoa hồng GĐ3 |
| `SEVERELY_OVERDUE` | Hủy nợ | `WRITTEN_OFF` | FIN_L2 đề xuất + BOD_CFO_CTO duyệt | Reason code; audit log; không hard-delete |

**Quy tắc:**
- `SETTLED`, `WRITTEN_OFF` là trạng thái kết thúc; mở lại chỉ qua giao dịch reversal có duyệt.
- Chuyển trạng thái bởi job phải idempotent và ghi snapshot theo ngày.
- Mọi chuyển trạng thái ghi audit log bất biến; khoản tranh chấp tách khỏi aging chuẩn đến khi xử lý xong.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `receivable_payable` | `id`, `tenant_id`, `direction` (AR/AP), `counterparty_type` (customer/platform), `counterparty_id`, `amount_original`, `currency`, `amount_vnd`, `due_date`, `status`, `bucket` | FK → `tenants.id`, `customers.id`/`platforms.id` | Nguồn từ ledger REQ-FIN-001 |
| `aging_snapshot` | `as_of_date`, `arap_id`, `days_overdue`, `bucket`, `amount_vnd`, `version` | FK → `receivable_payable.id` | Snapshot hằng ngày, version hóa |
| `dunning_history` | `arap_id`, `sent_at`, `template`, `channel`, `recipient`, `idempotency_key` | FK → `receivable_payable.id` | Ghi mọi lần nhắc; unique key chặn trùng |
| `payment_allocation` | `arap_id`, `settlement_id`, `amount`, `method` (FIFO/manual), `approved_by` | FK → `receivable_payable.id` | Phân bổ thanh toán → khoản nợ |
| `dispute_case` | `arap_id`, `reason`, `opened_by`, `status`, `resolution` | FK → `receivable_payable.id` | Tách khỏi aging chuẩn |
| `clawback_signal` | `arap_id`, `flagged_at`, `outstanding_vnd`, `consumed_by` | FK → `receivable_payable.id` | Nguồn cho hoa hồng GĐ3 |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Bucket aging đúng | AR hạn 2026-08-01, hôm nay 12/09 | Job aging chạy | Bucket 31–60, snapshot lưu theo ngày | [ ] |
| SC-002: Nhắc nợ tự động | AR quá hạn theo lịch nhắc 7 ngày | Job nhắc chạy | Gửi qua kênh cấu hình + ghi `dunning_history`; chạy lại không nhắc trùng | [ ] |
| SC-003: Clawback flag | Nợ quá hạn 95 ngày chưa thu | Job aging chạy | `CLAWBACK_FLAGGED`, API hoa hồng nhận đúng số outstanding | [ ] |
| SC-004: Cảnh báo AP trước hạn | AP nền tảng đến hạn sau 6 ngày | Job cảnh báo | Bắn cảnh báo theo mốc T-7/T-2, đưa vào ưu tiên duyệt chi | [ ] |
| SC-005: Tất toán thiếu evidence | Gọi API settle không gắn sao kê | Thực thi | Từ chối `SETTLEMENT_EVIDENCE_REQUIRED` | [ ] |
| SC-006: Tranh chấp tách aging | Khoản nợ bị đánh dấu tranh chấp | Xem aging | Không tính vào bucket chuẩn; ticket liên kết tồn tại | [ ] |
| SC-007: Tenant isolation | API aging của tenant A gọi với token tenant B | Truy vấn | Trả rỗng/403, meta-log ghi attempt | [ ] |

> **Liên kết:** SC-001–SC-004 map REQ-FIN-007; SC-005 map REQ-FIN-006/REQ-FIN-007; SC-006–SC-007 map REQ-FIN-007 + BR-FIN-603.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (aging, dunning, allocation) | `technical-specs/api-contract.md` |
| Tích hợp (connector VAS, clawback signal) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-007, BR-FIN-303), `phase1-business/P1-02-business-workflow.md` (chỉ số #10 aging/clawback) |
| Giả định mở | [KXN-22] mốc "15 ngày → PAUSE" non-payment (đề xuất 2 bậc 15/30 ngày) — chờ khách hàng xác nhận; cấu hình PAUSE tách khỏi aging chuẩn, bật khi được chốt |
