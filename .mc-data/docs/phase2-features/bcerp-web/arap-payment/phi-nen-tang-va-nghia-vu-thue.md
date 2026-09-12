# Tính Năng: Phí nền tảng & nghĩa vụ thuế

> **Dựa trên:** REQ-FIN-014 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Tài chính — Công nợ & Thanh toán (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ARAP-007 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-FIN-014 — Phí nền tảng & nghĩa vụ thuế (MEDIUM, Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (Phase2 — dữ liệu phí từ statement/API theo REQ-FIN-005) |
| Phụ thuộc | Không có cross-dependency ngoài module; dữ liệu nguồn từ statement/API 7 nền tảng (REQ-FIN-005) qua SYS-INTEGRATION-GW |
| Ghi chú Expert (A7) | Điểm phối hợp liên phòng (finance.md Mục A7): BR-FIN-306/602 do compliance-expert đồng phân tích — nghĩa vụ thuế FCT chốt với tư vấn thuế theo cấu hình có phê duyệt, không quyết miệng từng nền tảng |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng ghi nhận và theo dõi phí nền tảng/phí nạp cùng các nghĩa vụ thuế liên quan ngay trên web nội bộ, bảo đảm mọi khoản phí được nhận diện đúng giao dịch gốc để giá vốn media và gross margin (GM) không bị bóp méo. Phí nền tảng tách tuyệt đối khỏi doanh thu dịch vụ khi tính GM; thuế phí dịch vụ (VAT) và thuế hợp đồng với nhà thầu nước ngoài (FCT) khi thanh toán nền tảng quốc tế được ghi nhận theo cấu hình thuế có phê duyệt — kết luận từng nền tảng trace được, không quyết miệng.

**Phạm vi:**
- Bao gồm: màn danh sách phí nền tảng theo nền tảng/TKQC/giao dịch gốc — nhận diện từ statement/API (REQ-FIN-005), trạng thái map giao dịch, số tiền nguyên tệ và quy VND theo snapshot tỷ giá dùng chung (BR-FIN-203/REQ-FIN-004).
- Bao gồm: hàng đợi xử lý phí không map được giao dịch gốc → tạo ticket discrepancy theo BR-FIN-202 với người xử lý và hạn khép.
- Bao gồm: màn theo dõi nghĩa vụ thuế: VAT trên phí dịch vụ và FCT khi thanh toán nhà thầu nước ngoài — danh mục cấu hình thuế theo nền tảng (có phê duyệt), giá trị phát sinh kỳ, trạng thái kê khai/nộp, nhắc kỳ kê khai.
- Bao gồm: quy trình phê duyệt cấu hình thuế (nền tảng nào chịu FCT, tỷ lệ, kỳ kê khai — chốt với tư vấn thuế `[CẦN CHỐT SỐ]`): FIN_L2 đề xuất → CFO duyệt, version hóa, không hồi tố.
- Bao gồm: hiển thị tách bạch phí — doanh thu dịch vụ phục vụ tính GM (theo BR-FIN-308: media pass-through tính giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ).
- Bao gồm: hiển thị trạng thái đồng bộ số liệu phí/bút toán thuế sang phần mềm kế toán VAS qua connector (dùng chung REQ-FIN-013) để sổ kê khai khớp BCERP.
- Không bao gồm: kê khai và nộp thuế thực tế với cơ quan thuế — thực hiện trên phần mềm VAS/kê khai hiện hữu; BCERP cung cấp số liệu chuẩn đã đối chiếu.
- Không bao gồm: luồng cấp dữ liệu statement/API từ 7 nền tảng — thuộc SYS-INTEGRATION-GW (REQ-FIN-005, kèm degraded mode manual); web hiển thị nhãn nguồn và timestamp dữ liệu.
- Không bao gồm: hóa đơn điện tử đầu ra cho khách (FEAT-ERP-ARAP-005) — tính năng này chỉ bảo đảm dữ liệu đầu vào tách bạch giữa phí nền tảng (giá vốn) và phí dịch vụ (doanh thu).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; dữ liệu phí do core hạch toán tự động từ statement/API, web hiển thị đúng machine-state và không cho sửa số hạch toán trực tiếp.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem phí nền tảng từng ngày theo TKQC/giao dịch gốc, kèm nhãn nguồn (api/manual) và timestamp | Biết số phí "đúng tuổi" trước khi kiểm tra và đối chiếu |
| 2 | FIN_L1 | Nhận phí chưa map giao dịch gốc trong hàng đợi discrepancy, xử lý và ghi kết luận | Phí không "rơi tự do" làm sai giá vốn; mỗi khoản có người chịu trách nhiệm khép |
| 3 | FIN_L2 | Rà soát trước chốt kỳ: tổng phí theo nền tảng, tỷ lệ phí/doanh thu media, danh sách discrepancy còn mở | Chốt kỳ với giá vốn sạch, GM báo cáo không bị bóp méo |
| 4 | BOD_CFO_CTO | Duyệt cấu hình thuế theo nền tảng (có FCT hay không, tỷ lệ, kỳ kê khai) với version + ngày hiệu lực | Kết luận nghĩa vụ thuế có căn cứ tư vấn thuế và trace được về phê duyệt |
| 5 | FIN_L2 | Theo dõi giá trị FCT/VAT phát sinh theo kỳ, trạng thái kê khai/nộp và nhắc trước kỳ kê khai | Không bỏ sót nghĩa vụ thuế khi thanh toán nền tảng quốc tế dày đặc |
| 6 | BOD_CFO_CTO | Xem báo cáo GM tách bạch: doanh thu dịch vụ − giá vốn (gồm phí nền tảng) theo khách/nền tảng | Quyết định giá bán/chiết khấu trên margin thật, không lẫn tiền giữ hộ hay phí vào doanh thu |
| 7 | SYS_ADMIN | Thực thi cập nhật cấu hình hiển thị/danh mục sau phê duyệt, kiểm tra số liệu hiển thị đúng nguồn | Vai thực thi đúng biên, không can thiệp số liệu thuế |

Mọi thao tác (map phí, ghi giải trình, duyệt cấu hình thuế) đều qua API core với audit log immutable; web không tính lại thuế/fee — chỉ hiển thị kết quả hạch toán của core.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Hạch toán và tính thuế do core enforce; web chặn UI tương ứng.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Phí nền tảng/phí nạp ghi nhận theo giao dịch gốc, hạch toán vào giá vốn media đúng TKQC/giao dịch; tuyệt đối tách khỏi doanh thu dịch vụ khi tính GM; quy VND dùng chung snapshot tỷ giá (REQ-FIN-004). | Phí lẫn vào doanh thu là lỗi P1; báo cáo GM sai phải điều chỉnh trước khi dùng cho bất kỳ quyết định nào |
| BR-002 | Nền tảng trừ phí thẳng vào số dư ví → đối soát coi như một dòng chi tiêu, không ghi thành doanh thu âm; phí xuất hiện dưới dạng giảm trừ nạp xử lý theo cùng nguyên tắc giá vốn. | Ghi phí thành doanh thu âm bị chặn; discrepancy phát sinh nếu map không đúng giao dịch |
| BR-003 | Phí không map được giao dịch gốc → ticket discrepancy theo BR-FIN-202: người xử lý + hạn khép + kết luận bắt buộc; không khép kỳ khi còn discrepancy chưa có kết luận. | Chốt kỳ bị chặn/cảnh báo bởi core; discrepancy quá hạn phát alert cho CFO |
| BR-004 | Financial Hard Stop "đã khớp tiền" FIN_L1 (WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; thanh toán phí/thuế đi kèm giải ngân nền tảng phải tuân thủ cùng điều kiện — phí đã bị trừ trong ví xử lý theo đối soát, không tạo lệnh giải ngân mới. | Lệnh chi phí/thuế thiếu căn cứ khớp tiền bị chặn; Hard Stop không bị "đi vòng" qua luồng phí |
| BR-005 | SoD 4 vai dòng tiền (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ) áp dụng cho chuỗi thanh toán phí/thuế; người map phí ≠ người duyệt điều chỉnh hạch toán; ngưỡng giải ngân 5/50/200 triệu + delegate áp dụng cho khoản chi thuế/pay fee đủ điều kiện giải ngân. | Vai trùng bị core block + log; điều chỉnh hạch toán không có duyệt không có hiệu lực |
| BR-006 | Thuế nhà thầu nước ngoài (FCT): khi BC thanh toán cho nhà thầu nước ngoài không kinh doanh tại VN — khấu trừ, kê khai, nộp theo luật hiện hành; nền tảng nào chịu FCT, tỷ lệ, kỳ kê khai chốt với tư vấn thuế `[CẦN CHỐT SỐ]` và ghi trong cấu hình thuế có phê duyệt. | Không có cấu hình duyệt thì không hạch toán FCT — xử lý thành ticket chờ; tự quyết miệng là vi phạm quy trình |
| BR-007 | Cấu hình thuế effective-dated, version hóa (FIN_L2 đề xuất → CFO duyệt): báo cáo dùng đúng version hiệu lực tại thời điểm dữ liệu; nền tảng có pháp nhân VN thu tiền bằng hóa đơn VN → không áp FCT, hạch toán theo hóa đơn đầu vào thường. | Sửa cấu hình hồi tố bị từ chối; áp sai version phát hiện ở rà soát chốt kỳ là lỗi P1 |
| BR-008 | Công nợ AR/AP + aging + nhắc nợ: khoản thuế/phí phải nộp đưa vào AP theo hạn nộp (kê khai); aging AP hiển thị nhóm "nghĩa vụ thuế" riêng để ưu tiên thanh toán đúng hạn tránh phạt chậm. | Thuế quá hạn chưa nộp bật cảnh báo đỏ cho CFO; aging không tách nhóm thuế là lỗi hiển thị bắt buộc sửa |
| BR-009 | Hóa đơn điện tử TT78/2021 + NĐ123/2020: VAT đầu ra trên phí dịch vụ phản ánh trên HĐĐT phát hành từ chứng từ khóa kỳ; dữ liệu thuế đầu vào (gồm FCT khấu trừ) đối ứng chứng từ chi đã duyệt — không tự sáng tạo chứng từ thuế. | Số thuế trên HĐĐT lệch cấu hình bị chặn khi phát hành; lệch sau phát hành xử lý bằng điều chỉnh hóa đơn chuẩn |
| BR-010 | Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, DI-004 ngày 12/09) — vendor-agnostic, import/export chuẩn + adapter API; bút toán phí/thuế từ dữ liệu đã duyệt mới đồng bộ; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only. | Số thuế sổ VAS lệch BCERP phải giải trình trước kỳ kê khai; cấm ghi ngược legacy sau cutoff |
| BR-011 | Dữ liệu statement nguồn `manual` (degraded mode — DI-007): hiển thị nhãn nguồn + timestamp + disclaimer độ trễ; số phí manual chỉ vào báo cáo chính thức sau khi backfill dữ liệu API được xác nhận; không nội suy số ẩn. | Dùng số manual làm căn cứ chốt kỳ không được phép; backfill xong phải đối chiếu chênh lệch trước khi ghi nhận chính thức |
| BR-012 | Mọi thao tác map/giải trình/duyệt cấu hình thuế ghi audit log kèm reason code; dữ liệu thuế/phí thuộc dữ liệu tài chính Restricted — truy cập theo ma trận BR-FIN-603, OPS chỉ thấy trạng thái TKQC không thấy dòng tiền chi tiết. | Truy cập ngoài ma trận bị chặn + meta-log; log thiếu reason là lỗi kiểm toán |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Chỉ dùng 18 vai registry.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | OPS_* |
|-----------|--------|--------|-------------|-----------|-------|
| Xem danh sách phí theo giao dịch gốc | ✅ (khách được gán) | ✅ | ✅ | ❌ | ❌ (chỉ trạng thái TKQC) |
| Map phí ↔ giao dịch gốc | ✅ | ✅ (duyệt map phức tạp) | ❌ | ❌ | ❌ |
| Xử lý discrepancy phí | ✅ (nhập kết luận) | ✅ (khép ticket) | ✅ (duyệt khép kỳ còn mở) | ❌ | ❌ |
| Đề xuất cấu hình thuế (FCT/VAT) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt cấu hình thuế (version, hiệu lực) | ❌ | ❌ | ✅ | ❌ (thực thi sau duyệt) | ❌ |
| Xem giá trị FCT/VAT + trạng thái kê khai | ✅ (xem) | ✅ | ✅ | ❌ | ❌ |
| Xuất báo cáo phí/GM/thuế định kỳ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xuất ngoài báo cáo chuẩn | ❌ | ❌ | ✅ (sau phê duyệt CEO) | ❌ | ❌ |
| Sửa số hạch toán phí/thuế trực tiếp | ❌ (chỉ reversal có reason) | ❌ | ❌ (duyệt reversal) | ❌ | ❌ |

SYS_ADMIN chỉ thực thi cấu hình sau phê duyệt của BOD; người thử việc/freelancer không có quyền thao tác dữ liệu thuế. Review ma trận truy cập hằng quý theo BR-FIN-603.

---

## 5. Trường Hợp Đặc Biệt

- Nền tảng đổi chính sách tính phí giữa kỳ (ví dụ thêm surcharge): dữ liệu phí mới ghi theo giao dịch gốc ngày phát sinh; nếu ảnh hưởng GM đáng kể, FIN_L2 phát báo cáo tác động cho CFO trước chốt kỳ — không điều chỉnh hồi tố cấu hình GM.
- Statement bị trễ/degraded (chưa có quyền API — DI-007): phí hiển thị theo dữ liệu manual từ file nền tảng, gắn nhãn nguồn + disclaimer; khi API được cấp và backfill, đối chiếu chênh lệch manual ↔ api trước khi chính thức hóa số.
- Một thanh toán nền tảng bao nhiều TKQC/khách: map theo chi tiết phân bổ trong statement; nếu statement không đủ chi tiết, tạo discrepancy phân bổ có duyệt — không chia đều "cho nhanh" vì bóp méo GM từng khách.
- FCT phát hiện nộp thừa/thiếu sau kê khai: xử lý bằng giao dịch điều chỉnh có reason code tham chiếu kỳ kê khai; báo cáo theo dõi FCT hiển thị cả số điều chỉnh để trace toàn bộ lịch sử.
- Nền tảng chuyển mô hình từ "nước ngoài" sang "có pháp nhân VN thu tiền bằng hóa đơn VN": cập nhật cấu hình thuế theo version mới có hiệu lực tương lai; giao dịch trước/sau hiệu lực hạch toán theo đúng version của thời điểm — không đổi kết luận số cũ.
- Phí bị nền tảng hoàn lại (fee refund): ghi nhận đối ứng giao dịch phí gốc, điều chỉnh giá vốn kỳ phát sinh qua reversal có reason; không ghi thành doanh thu.
- Kỳ kê khai trùng kỳ chốt tháng mà connector VAS đang lỗi: chạy quy trình degraded có kiểm soát của REQ-FIN-013 (export file chuẩn + xác nhận kép) để số kê khai kịp hạn, gắn nhãn "đồng bộ thủ công" cho audit.
- Khách yêu cầu giải trình chi tiết phí trong báo cáo service: xuất báo cáo phí theo giao dịch gốc của tenant mình qua luồng portal/read-only (GĐ3) — không lộ phí của khách khác hay giá vốn tổng hợp BC.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi phí nền tảng (Platform Fee Record) — kèm theo dõi nghĩa vụ thuế phát sinh từ các giao dịch liên quan.

**Sơ đồ trạng thái:**
```
[RECEIVED] ──(auto-map theo giao dịch gốc)──► [MAPPED] ──(hạch toán giá vốn)──► [POSTED] ──(đối chiếu VAS khép)──► [RECONCILED]
     │                                              │
     │ (không map được)                              │ (phát hiện map sai)
     ▼                                              ▼
[UNMAPPED] ──(xử lý ticket + duyệt)──► [MAPPED]          [RE-MAPPING] ──► về [MAPPED] (reversal cũ + hạch toán mới)
[Tax Obligation]: [NOT_APPLICABLE] / [IDENTIFIED] ──(cấu hình duyệt)──► [ACCRUED] ──(kê khai)──► [FILED] ──(nộp)──► [PAID]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `RECEIVED` | Auto-map | `MAPPED` | Hệ thống | Khớp giao dịch gốc theo rule mapping cấu hình |
| `RECEIVED` | Không map được | `UNMAPPED` | Hệ thống | Tự động tạo ticket discrepancy |
| `UNMAPPED` | Xử lý ticket | `MAPPED` | FIN_L1 nhập, FIN_L2 duyệt | Kết luận + căn cứ đính kèm; hạn khép |
| `MAPPED` | Hạch toán | `POSTED` | Hệ thống | Giá vốn media đúng TKQC/giao dịch; snapshot tỷ giá |
| `MAPPED` | Map sai phát hiện | `RE-MAPPING` | FIN_L2 | Reversal hạch toán cũ có reason code |
| `POSTED` | Đối chiếu VAS khép | `RECONCILED` | FIN_L2 | Batch đối chiếu tháng tương ứng đã `RECONCILED` |
| `IDENTIFIED` (thuế) | Duyệt cấu hình | `ACCRUED` | CFO duyệt | Version cấu hình thuế hiệu lực; căn cứ tư vấn thuế |
| `ACCRUED` | Kê khai | `FILED` | FIN_L2 (ghi nhận) | Kỳ kê khai + số liệu khớp VAS sau đối chiếu |
| `FILED` | Nộp thuế | `PAID` | Hệ thống (từ lệnh chi đã duyệt) | Chứng từ nộp + Hard Stop/duyệt chi theo ngưỡng |

**Quy tắc:**
- `RECONCILED` và `PAID` là trạng thái kết thúc chu kỳ; sửa sau đó chỉ qua reversal có reason code và duyệt.
- `UNMAPPED` kéo quá hạn khép phát alert; không cho phép chốt kỳ khi còn `UNMAPPED`/`ACCRUED` quá hạn kê khai.
- Nghĩa vụ thuế `NOT_APPLICABLE` phải có cấu hình duyệt làm căn cứ (ví dụ nền tảng có pháp nhân VN) — không phải trạng thái mặc định bỏ qua.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| PlatformFeeRecord | `id`, `platform`, `adaccount_ref`, `original_txn_ref`, `amount`, `currency`, `fx_snapshot`, `status` | FK → giao dịch gốc, TKQC | Nguồn statement/API + nhãn nguồn |
| DiscrepancyTicket | `fee_id`, `opened_at`, `assignee`, `resolution`, `closed_at` | FK → fee record | Theo BR-FIN-202; hạn khép bắt buộc |
| TaxConfigVersion | `platform`, `tax_type` (VAT/FCT), `rate`, `filing_period`, `effective_from`, `approved_by` | FK → nền tảng | Effective-dated, CFO duyệt |
| TaxObligation | `config_version_id`, `period`, `amount`, `status`, `filing_ref`, `payment_ref` | FK → cấu hình; FK → lệnh chi | Trạng thái ACCRUED→FILED→PAID |
| JournalEntry (tham chiếu) | `fee_id`/`tax_id`, `account`, `debit`, `credit`, `voucher_ref` | FK → chứng từ đã duyệt | Xuất VAS qua connector REQ-FIN-013 |
| AuditLog (tham chiếu) | `object`, `action`, `reason_code` | Append-only | Map/giải trình/duyệt đều log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Phí map đúng giao dịch gốc | Statement ngày D có 500 dòng phí | Core auto-map | ≥98% vào `MAPPED` đúng giao dịch; phần còn lại vào `UNMAPPED` kèm ticket | [ ] |
| SC-002: Phí không thành doanh thu âm | Nền tảng trừ phí thẳng vào ví | Hạch toán | Ghi một dòng chi tiêu (giá vốn); không phát sinh doanh thu âm; GM không đổi doanh thu | [ ] |
| SC-003: Chặn chốt kỳ còn discrepancy | Còn 3 ticket `UNMAPPED` quá hạn | FIN_L2 chốt kỳ | Bị chặn/cảnh báo; alert CFO; phải khép ticket trước | [ ] |
| SC-004: FCT theo cấu hình duyệt | Nền tảng X cấu hình chịu FCT 5% (đã CFO duyệt) | Thanh toán nền tảng X | `ACCRUED` đúng tỷ lệ, đúng version hiệu lực; báo cáo FCT thể hiện kỳ kê khai | [ ] |
| SC-005: Không áp FCT không căn cứ | Nền tảng Y chưa có cấu hình duyệt | Phát sinh thanh toán quốc tế | Không hạch toán FCT tự động; tạo ticket chờ cấu hình duyệt | [ ] |
| SC-006: Tách bạch GM | Báo cáo GM tháng | Xem theo khách | Doanh thu chỉ gồm phí dịch vụ/markup; phí nền tảng nằm giá vốn; tiền giữ hộ không xuất hiện ở GM | [ ] |
| SC-007: Nhãn manual minh bạch | Statement nguồn manual do chưa có API | FIN_L1 xem số phí | Hiển thị nhãn "manual" + timestamp + disclaimer; không vào báo cáo chính thức trước backfill | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-FIN-014 (Mục 2 — phí theo giao dịch gốc, tách GM, VAT/FCT theo cấu hình duyệt).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/platform-fee-tax.md` |
| Bản fan-out counterpart | `phase2-features/integration-gw/arap-payment/` (statement/API fees), `phase2-features/core-backend/arap-payment/` (hạch toán, tax engine) |
