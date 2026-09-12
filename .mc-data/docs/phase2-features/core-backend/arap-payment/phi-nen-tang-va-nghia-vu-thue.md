# Tính Năng: Phí nền tảng & nghĩa vụ thuế

> **Dựa trên:** REQ-FIN-014 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Phí & Thuế (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-007-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-007 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-014] — liên quan: REQ-FIN-005 (dữ liệu statement/API nguồn), REQ-FIN-004 (snapshot tỷ giá dùng chung, đối trừ 3 số), REQ-FIN-011 (HĐĐT doanh thu), REQ-FIN-013 (connector VAS xuất bút toán), REQ-FIN-016 (P&L dùng GM) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình (MEDIUM — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-FIN-005 (statement/API phí từ GW) phải sẵn sàng; FEAT-CORE-ARAP-003 (giao dịch gốc trên ledger), FEAT-CORE-ARAP-006 (xuất bút toán phí/thuế xuống sổ VAS), FEAT-CORE-ARAP-005 (VAT trên hóa đơn doanh thu) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; business rules lấy từ BR-FIN-306 + BR-FIN-602 (compliance-expert call-2); chi tiết FCT (nền tảng nào chịu thuế, tỷ lệ, kỳ kê khai) chốt với tư vấn thuế khi triển khai — hệ thống thiết kế theo hướng cấu hình thuế effective-dated có phê duyệt, không chặn kiến trúc |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Hạch toán phí nền tảng/phí nạp và các nghĩa vụ thuế liên quan (VAT phí dịch vụ, thuế nhà thầu nước ngoài FCT) đúng giao dịch gốc ngay trên SYS-CORE-BACKEND — để giá vốn media và Gross Margin không bị bóp méo, doanh thu dịch vụ được tách bạch khỏi phí, và nghĩa vụ thuế với nền tảng quốc tế được nhận diện có hệ thống thay vì quyết định thủ công.

**Phạm vi:**
- Bao gồm: service hạch toán tự động phí nền tảng từ dữ liệu statement/API (REQ-FIN-005) vào đúng TKQC/giao dịch gốc; tách phí khỏi doanh thu dịch vụ khi tính GM; quy VND dùng chung snapshot tỷ giá (REQ-FIN-004/BR-FIN-203); nhận diện dòng "nền tảng trừ phí thẳng vào ví" và hạch toán như một dòng chi tiêu; tạo ticket discrepancy cho phí không map được giao dịch gốc; mô hình cấu hình thuế effective-dated có phê duyệt cho VAT/FCT theo từng nền tảng; hạch toán tách FCT khỏi giá vốn media và doanh thu dịch vụ khi phát sinh; xuất bút toán phí/thuế xuống sổ VAS qua connector (FEAT-CORE-ARAP-006).
- Không bao gồm: màn hình hiển thị tách bạch phí–doanh thu trên web (counterpart SYS-BCERP-WEB); cấp dữ liệu statement từ các nền tảng (REQ-FIN-005 — GW counterpart); phát hành hóa đơn doanh thu (FEAT-CORE-ARAP-005); tính GM trên dashboard BI (REQ-FIN-016/REQ-BOD-003).

**Đặc thù touchpoint SYS-CORE-BACKEND:** mọi quy tắc phân loại (phí vs doanh thu vs thuế) enforce ở tầng service — dữ liệu thô từ statement không bao giờ vào báo cáo chưa qua phân loại; cấu hình thuế là dữ liệu có version + ngày hiệu lực + người duyệt (effective-dated, không hồi tố theo BR-BOD-009); hạch toán ghi vào ledger append-only, sửa chỉ qua reversal có reason code; dữ liệu phí/thuế phân loại Restricted (giá vốn là T4 theo phân loại dữ liệu) — tenant isolation, audit log bất biến.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Gọi API hạch toán phí từ statement kỳ mới vào giao dịch gốc từng TKQC | Phí được nhận diện đúng ngay từ đầu kỳ, không cộng dồn nhòe ở cuối kỳ |
| 2 | FIN_L1 | Nhận danh sách phí không map được giao dịch gốc qua API dạng ticket discrepancy | Xử lý từng dòng kẹt thay vì để số "lơ lửng" làm sai GM |
| 3 | FIN_L2 | Rà soát bản phân loại phí–doanh thu–thuế trước chốt kỳ qua API kiểm tra chéo | Chốt kỳ với GM tin cậy, không phải điều chỉnh sau |
| 4 | BOD_CFO_CTO | Duyệt cấu hình thuế theo nền tảng (VAT, có/không FCT, tỷ lệ, kỳ kê khai) qua API effective-dated | Nghĩa vụ thuế ghi nhận theo văn bản có phê duyệt, không "quyết miệng" |
| 5 | FIN_L2 | Ghi giải trình cho dòng phí đặc biệt qua API (lý do + điều chỉnh) | Mọi ngoại lệ có vết phục vụ kiểm toán |
| 6 | Hệ thống (service) | Tự tách dòng "nền tảng trừ phí thẳng vào ví" thành chi tiêu theo giao dịch gốc | Không ghi thành doanh thu âm làm méo báo cáo |
| 7 | Hệ thống (service) | Hạch toán FCT tách khỏi giá vốn media khi cấu hình thuế quy định nền tảng chịu thuế | Số giá vốn và nghĩa vụ thuế không trộn lẫn nhau |
| 8 | BOD_CFO_CTO | Xem báo cáo tổng hợp phí theo nền tảng/khách và nghĩa vụ thuế theo kỳ qua API tổng hợp | Ra quyết định giá bán và dự phòng thuế chính xác |

**Diễn giải luồng chính (service layer):** (1) nhận dữ liệu phí từ statement/API (REQ-FIN-005) → chuẩn hóa + quy VND theo snapshot tỷ giá dùng chung; (2) map từng dòng phí về giao dịch gốc (top-up, lệnh chi, TKQC) — mapping fail thì sinh ticket discrepancy; (3) phân loại theo cấu hình: giá vốn media (phí nạp/phí giao dịch) / phí dịch vụ (thuần doanh thu) / thuế (VAT/FCT theo cấu hình có phê duyệt); (4) ghi bút toán append-only có dẫn chiếu giao dịch gốc; (5) đẩy bút toán đã duyệt xuống sổ VAS qua luồng FEAT-CORE-ARAP-006; (6) báo cáo tách bạch phục vụ GM (REQ-FIN-016).

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-701 | Phí nền tảng/phí nạp ghi nhận **theo giao dịch gốc**: mỗi dòng phí map về đúng TKQC/giao dịch (top-up, lệnh chi) trên ledger REQ-FIN-001; quy VND dùng chung snapshot tỷ giá REQ-FIN-004/BR-FIN-203 — không dùng tỷ giá khác | Map fail → sinh ticket discrepancy (BR-FIN-202), dòng không được vào báo cáo GM |
| BR-ARAP-702 | Phí tách khỏi doanh thu dịch vụ khi tính GM: giá vốn media = chi phí nền tảng + phí; doanh thu chỉ gồm phí dịch vụ/markup; cấm cấu hình hạch toán phí vào doanh thu hoặc ngược lại | Vi phạm phân loại → từ chối bút toán `MISCLASSIFICATION_BLOCKED` + log |
| BR-ARAP-703 | Nền tảng trừ phí thẳng vào số dư ví → đối soát coi như một dòng chi tiêu theo giao dịch gốc, không ghi thành doanh thu âm; dòng trừ phí phải khớp statement (đối trừ 3 số REQ-FIN-004) | Dòng trừ phí không khớp statement → ticket discrepancy + hold, không tự nhận diện |
| BR-ARAP-704 | Cấu hình thuế (VAT phí dịch vụ; FCT khi thanh toán nhà thầu nước ngoài — nền tảng nào chịu, tỷ lệ, kỳ kê khai) là dữ liệu effective-dated có phê duyệt BOD_CFO_CTO, xác nhận với tư vấn thuế trước ban hành; không hồi tố; kết luận từng nền tảng ghi trong cấu hình — không quyết miệng | Hạch toán thuế thiếu cấu hình hiệu lực → từ chối `TAX_CONFIG_MISSING` |
| BR-ARAP-705 | Khi BC thanh toán cho nhà thầu nước ngoài không kinh doanh tại VN: khấu trừ, kê khai và nộp FCT theo cấu hình có phê duyệt; CORE tách thuế FCT khỏi giá vốn media và doanh thu dịch vụ khi phát sinh; GW cấp dữ liệu thanh toán quốc tế từ statement/API (REQ-FIN-005) | Bút toán không tách FCT → chặn chốt kỳ `FCT_NOT_SEPARATED` |
| BR-ARAP-706 | Nền tảng có pháp nhân VN thu tiền bằng hóa đơn VN → không áp FCT, hạch toán theo hóa đơn đầu vào thường; liên quan hóa đơn doanh thu phía BC thì VAT xử lý theo FEAT-CORE-ARAP-005 (TT78/2021 + NĐ123/2020) | Trùng cấu hình FCT + hóa đơn VN → cảnh báo cấu hình mâu thuẫn, chặn đến khi CFO xử |
| BR-ARAP-707 | Sửa số liệu phí/thuế chỉ qua giao dịch reversal có reason code (audit log bất biến ≥10 năm); FIN_L1 kiểm tra, FIN_L2 rà trước chốt kỳ; người nhập/khớp statement không tự điều chỉnh số do mình khớp (SoD đối soát ≠ điều chỉnh) | Sửa đè → chặn ở tầng service + dữ liệu; vi phạm SoD → log cho CFO rà |
| BR-ARAP-708 | Bút toán phí/thuế đã duyệt xuất xuống sổ VAS qua connector theo FEAT-CORE-ARAP-006 (cấu hình kết nối ngoại vi Settings — DI-004 12/09, vendor-agnostic, legacy PMS read-only sau migrate chọn lọc); mọi giải ngân nạp/quốc tế liên quan phải qua Hard Stop "đã khớp tiền" FIN_L1 và luồng duyệt chi ngưỡng 5/50/200 triệu + delegate (FEAT-CORE-ARAP-004) | Xuất bút toán chưa duyệt/khóa kỳ bị chặn; giải ngân thiếu Hard Stop bị từ chối tuyệt đối |

---

## 4. Phân Quyền

> Enforce tại tầng service; dữ liệu giá vốn/thuế thuộc phân loại Restricted (T4) — quyền xem theo ma trận BR-FIN-603.

| Hành động (API) | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------------|--------|--------|-------------|
| Chạy hạch toán phí theo kỳ | ✅ | ✅ | ❌ |
| Xem bản phân loại phí–doanh thu–thuế | ✅ | ✅ | ✅ (tổng hợp) |
| Xem giá vốn media chi tiết theo TKQC | ✅ (khách được gán) | ✅ | ✅ |
| Xử lý ticket discrepancy | ✅ (đề xuất mapping) | ✅ (duyệt xử lý) | ❌ |
| Ghi giải trình dòng phí đặc biệt | ❌ | ✅ (lý do bắt buộc) | ✅ (oversight) |
| Đề xuất cấu hình thuế (VAT/FCT theo nền tảng) | ❌ | ✅ | ❌ |
| Duyệt/ban hành cấu hình thuế | ❌ | ❌ | ✅ |
| Rà soát phân loại trước chốt kỳ | ❌ | ✅ | ✅ (duyệt chốt) |
| Điều chỉnh (reversal) số phí/thuế | ❌ | ✅ (kèm reason code) | ✅ |
| Xuất bút toán phí/thuế xuống VAS | ✅ (lô chuẩn) | ✅ (phê duyệt lô) | ❌ |
| Xem báo cáo nghĩa vụ thuế theo kỳ | ✅ | ✅ | ✅ |
| Xóa dòng phí/thuế đã hạch toán | ❌ | ❌ | ❌ (chỉ reversal có duyệt) |

---

## 5. Trường Hợp Đặc Biệt

- **Statement phí đến trễ so với giao dịch gốc (nền tảng chốt phí sau):** phí hạch toán bổ sung theo kỳ statement, dẫn chiếu giao dịch gốc cũ; nếu đã chốt kỳ thì xử lý qua reversal/điều chỉnh có duyệt theo FEAT-CORE-ARAP-002 (kỳ khóa chỉ CFO mở lại) — không sửa im lặng.
- **Một giao dịch phát sinh nhiều loại phí (phí nạp + phí chuyển đổi + phí giao dịch):** statement phân tách từng loại → hạch toán riêng theo TK/hạng mục cấu hình; statement không tách → FIN_L1 đề xuất cách tách, FIN_L2 duyệt, ghi giải trình.
- **Nền tảng đổi chính sách thuế giữa kỳ:** cấu hình thuế effective-dated theo ngày hiệu lực mới; giao dịch trước/sau mốc dùng đúng phiên bản cấu hình tại thời điểm dữ liệu (khớp BR-BOD-009) — báo cáo dựng lại không hồi tố bản ghi.
- **Phí tính bằng ngoại tệ với tỷ giá dao động trong ngày:** dùng snapshot tỷ giá dùng chung tại thời điểm giao dịch gốc; sai khác làm tròn với statement xử lý theo dung sai đối soát (đã chốt DI-001: 0 / 0,5%·10 USD / 1%·20 USD theo mức), vượt dung sai → ticket discrepancy.
- **Khách yêu cầu hạch toán phí vào đúng chiến dịch:** map phí đến mức giao dịch gốc cho phép truy ngược chiến dịch nếu statement có đủ dữ liệu; statement thiếu → ghi ở mức TKQC + ghi chú giới hạn mapping, không suy diễn.
- **FCT nộp qua đại lý thuế/đối tác thanh toán:** bút toán nộp tách khỏi bút toán khấu trừ — khấu trừ ghi khi thanh toán nền tảng, nộp ghi khi có chứng từ nộp; hai vòng đời riêng nhưng dẫn chiếu nhau.
- **Multi-tenant:** cấu hình thuế và bản phân loại gắn tenant/pháp nhân; API tổng hợp trả đúng phạm vi tenant của token, giá vốn không lộ chéo tenant.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Dòng phí từ statement (`fee_line_item`)

**Sơ đồ trạng thái:**
```
[RAW] ──(auto-map giao dịch gốc)──► [MAPPED] ──(FIN_L2 rà/duyệt theo lô)──► [VERIFIED] ──(ghi bút toán + khóa kỳ)──► [POSTED]
   │                                     │
   │ (map fail)                          │ (dispute/mapping sai)
   ▼                                     ▼
[DISCREPANCY] ──(xử lý xong)──► [MAPPED]                           [POSTED] ──(reversal có duyệt)──► [POSTED] (dòng đảo) + [REVERSED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `RAW` | Auto-map | `MAPPED` | Service tự động | Tìm được giao dịch gốc; quy VND đúng snapshot; dung sai đối soát thỏa |
| `RAW` | Map fail | `DISCREPANCY` | Service tự động | Sinh ticket discrepancy tự động |
| `DISCREPANCY` | Xử lý xong | `MAPPED` | FIN_L1 đề xuất + FIN_L2 duyệt | Lý do + mapping dẫn chiếu ticket |
| `MAPPED` | Rà/duyệt theo lô | `VERIFIED` | FIN_L2 | Bản phân loại đúng cấu hình thuế hiệu lực |
| `VERIFIED` | Ghi bút toán (khóa kỳ) | `POSTED` | Service tự động | Thuế tách đúng (FCT nếu cấu hình); ghi audit log |
| `POSTED` | Reversal | `REVERSED` (kèm dòng đảo `POSTED`) | FIN_L2/CFO | Reason code; không hard-delete |

**Quy tắc:**
- `POSTED`, `REVERSED` là trạng thái kết thúc của dòng gốc; điều chỉnh qua dòng mới có dẫn chiếu.
- Job hạch toán idempotent — statement nạp lại không sinh dòng trùng (unique key nguồn).
- Mọi chuyển trạng thái ghi audit log bất biến; cấu hình thuế tham chiếu theo phiên bản hiệu lực tại thời điểm chuyển.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `fee_line_item` | `id`, `tenant_id`, `statement_ref`, `source_txn_id`, `platform`, `adaccount_id`, `type` (nạp/chuyển đổi/giao dịch), `amount_original`, `currency`, `amount_vnd`, `fx_snapshot_id`, `classification` (COGS/REVENUE/TAX), `status` | FK → `tenants.id`, `ledger_entries.id`, `fx_snapshots.id` | Unique key nguồn chống nạp trùng |
| `discrepancy_ticket` | `fee_line_id`, `reason`, `proposed_mapping`, `status`, `resolved_by` | FK → `fee_line_item.id` | Theo BR-FIN-202; SoD khớp ≠ điều chỉnh |
| `tax_config` | `platform`, `tax_type` (VAT/FCT/NONE), `rate`, `filing_period`, `effective_from`, `effective_to`, `approved_by`, `version` | Độc lập theo nền tảng | Effective-dated; duyệt CFO; tư vấn thuế xác nhận |
| `fct_entry` | `payment_txn_id`, `tax_amount_vnd`, `config_version`, `paid_ref` | FK → `fee_line_item.id`, `tax_config.id` | Tách khấu trừ vs nộp |
| `posting_entry` | `fee_line_id`, `debit_account`, `credit_account`, `amount_vnd`, `export_batch_id` | FK → `export_batch.id` (FEAT-CORE-ARAP-006) | Append-only; reversal có reason |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Map đúng giao dịch gốc | Dòng phí statement có ref top-up | Job hạch toán | `MAPPED` đúng TKQC/giao dịch, quy VND theo snapshot | [ ] |
| SC-002: Map fail sinh ticket | Dòng phí không tìm thấy giao dịch gốc | Job chạy | `DISCREPANCY` + ticket sinh tự động, không vào GM | [ ] |
| SC-003: Trừ phí thẳng ví | Nền tảng trừ phí vào số dư ví | Đối soát | Ghi như dòng chi tiêu theo giao dịch gốc, không phải doanh thu âm | [ ] |
| SC-004: FCT tách bút toán | Cấu hình nền tảng X chịu FCT 5%, hiệu lực trong kỳ | Thanh toán quốc tế phát sinh | Bút toán tách FCT khỏi giá vốn + doanh thu; `POSTED` đúng phiên bản cấu hình | [ ] |
| SC-005: Thiếu cấu hình thuế | Nền tảng mới chưa có tax_config | Hạch toán phát sinh | Từ chối `TAX_CONFIG_MISSING`, cảnh báo CFO | [ ] |
| SC-006: Reversal có vết | Dòng `POSTED` sai phân loại | FIN_L2 reversal | Dòng đảo mới có reason code; dòng gốc nguyên vẹn | [ ] |
| SC-007: Tenant isolation | Token tenant A xem phí tenant B | Truy vấn API | Rỗng/403, meta-log ghi attempt | [ ] |

> **Liên kết:** SC-001–SC-003, SC-006–SC-007 map REQ-FIN-014; SC-004–SC-005 map REQ-FIN-014 + BR-FIN-602; điều kiện giải ngân nền tảng map REQ-FIN-006/REQ-FIN-008.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (fee classification, tax config) | `technical-specs/api-contract.md` |
| Tích hợp (statement REQ-FIN-005, connector VAS) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-014, BR-FIN-306, B.6 — BR-FIN-602), `phase1-business/P1-02-business-workflow.md` (bên ngoài #6, nguyên tắc #1/#3) |
