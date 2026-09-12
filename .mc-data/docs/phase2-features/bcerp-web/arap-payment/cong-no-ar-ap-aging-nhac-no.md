# Tính Năng: Công nợ AR/AP + aging + nhắc nợ

> **Dựa trên:** REQ-FIN-007 trong `phase1-business/departments/finance/finance.md` (Phần A)
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
| ID tính năng | FEAT-ERP-ARAP-003 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-FIN-007 — Công nợ AR/AP + aging + nhắc nợ (HIGH, Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2 — thay Sheets bằng quản trị công nợ có hệ thống) |
| Phụ thuộc | Không có cross-dependency ngoài module; dùng chung ledger ví (REQ-FIN-001) làm nguồn sự thật số dư AR |
| Ghi chú Expert (A7) | Điểm phối hợp liên phòng (finance.md Mục A7): REQ-FIN-007 — số AR là nguồn sự thật clawback hoa hồng thực nhận của SALES (GĐ3); REQ-FIN-006 — FIN nắm quyền xác nhận Hard Stop trong vòng đời cấp phát TKQC do OPS vận hành |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng thay thế việc theo dõi công nợ trên Sheets bằng màn hình aging AR/AP có hệ thống trên web nội bộ: phải thu khách (AR) và phải trả nền tảng (AP) được phân bucket 0–30 / 31–60 / 61–90 / >90 ngày tự động từ ledger, kèm nhắc nợ tự động cho AR quá hạn và theo dõi hạn thanh toán AP nền tảng để tránh gián đoạn TKQC. Số dư AR trở thành nguồn sự thật duy nhất phục vụ clawback hoa hồng (nợ >90 ngày → clawback 100%) và là căn cứ cho FIN_L2/CFO xử lý nợ quá hạn có dữ liệu.

**Phạm vi:**
- Bao gồm: màn danh sách và chi tiết công nợ AR (theo khách/hợp đồng/hóa đơn) và AP (theo nền tảng/tài khoản quảng cáo) với số dư, hạn thanh toán, trạng thái, lịch sử thanh toán.
- Bao gồm: aging tự động theo bucket 0–30 / 31–60 / 61–90 / >90 ngày cho cả AR và AP, tính từ hạn thanh toán; dashboard tổng hợp theo khách/nền tảng với drill-down về từng hóa đơn.
- Bao gồm: cấu hình và vận hành nhắc nợ tự động cho AR quá hạn (lịch nhắc cấu hình được, lịch sử từng lần nhắc, kênh gửi, người gửi, nội dung mẫu) và lịch sử ghi nhận liên lạc đòi nợ của FIN_L2.
- Bao gồm: theo dõi hạn thanh toán AP nền tảng với cảnh báo trước hạn (early warning) để duyệt chi/giải ngân kịp, tránh TKQC bị gián đoạn chi tiêu.
- Bao gồm: quản lý công nợ tranh chấp — tách khỏi aging bình thường thành ticket riêng đến khi giải quyết, kèm người xử lý và kết luận.
- Bao gồm: hiển thị cờ clawback cho hóa đơn AR vượt 90 ngày (phục vụ SALES/HR GĐ3 — hoa hồng thực nhận đối chiếu sổ AR).
- Không bao gồm: tính toán clawback vào hoa hồng và chi trả hoa hồng — thuộc SALES/HR (GĐ3), tính năng chỉ cung cấp số AR chuẩn từ ledger.
- Không bao gồm: đối trừ 3 số, khóa kỳ, chênh lệch đối soát (REQ-FIN-004) và luồng duyệt chi thanh toán AP (FEAT-ERP-ARAP-004); aging nhận kết quả đối soát/trạng thái hóa đơn từ các luồng đó.
- Không bao gồm: gửi nhắc nợ trực tiếp đến khách qua portal — khách chỉ đọc số dư tổng hợp đã lọc tenant (GĐ3, REQ-FIN-017); nhắc nợ trong scope này là hoạt động nội bộ FIN.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; dữ liệu aging do core tính từ ledger (nguồn REQ-FIN-001), web hiển thị đúng machine-state và không cho sửa số dư trực tiếp.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem aging AR/AP theo bucket 0–30/31–60/61–90/>90 ngày cập nhật từ ledger, lọc theo khách/nền tảng | Nắm tình hình công nợ hằng ngày mà không tổng hợp tay trên Sheets |
| 2 | FIN_L1 | Theo dõi hạn thanh toán AP nền tảng với cảnh báo trước hạn | Đề xuất duyệt chi kịp thời, tránh nền tảng khóa/gián đoạn chi tiêu TKQC của khách |
| 3 | FIN_L2 | Ghi nhận kết quả từng lần đòi nợ (liên lạc, cam kết thanh toán, thỏa thuận gia hạn) ngay trên hóa đơn | Lịch sử đòi nợ đầy đủ phục vụ quyết định xử lý và bằng chứng khi escalate |
| 4 | BOD_CFO_CTO | Xem dashboard công nợ tổng hợp: tổng AR theo bucket, top khách nợ lâu, AP sắp đến hạn, tỷ lệ thu | Định hướng chính sách tín dụng và quyết định xử lý nợ quá hạn bằng dữ liệu |
| 5 | FIN_L2 | Đánh dấu hóa đơn tranh chấp để tách khỏi aging bình thường, gán người xử lý và theo dõi ticket đến khi kết luận | Tranh chấp được theo dõi riêng, không lẫn vào số chung |
| 6 | FIN_L2 | Cấu hình lịch nhắc nợ tự động (mốc ngày, mẫu nội dung, người nhận) cho AR quá hạn | Nhắc đúng nhịp không bỏ sót khách, giảm việc thủ công và chuẩn hóa thông điệp |
| 7 | BOD_CFO_CTO | Xuất báo cáo aging định kỳ (tuần/tháng) phục vụ họp điều hành và đối chiếu với kế toán VAS | Ra quyết định trên số thống nhất giữa BCERP và sổ kế toán |

Mọi thao tác ghi (ghi nhận đòi nợ, đánh dấu tranh chấp, cấu hình nhắc) đều qua API core với audit log; web không lưu trạng thái cục bộ tách rời machine-state.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Tính toán aging nằm ở service layer SYS-CORE-BACKEND từ ledger; web chỉ hiển thị và thu thập input.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Aging AR/AP theo bucket 0–30 / 31–60 / 61–90 / >90 ngày tính từ hạn thanh toán; nguồn dữ liệu là ledger dùng chung (REQ-FIN-001) — web không cho nhập/sửa số dư công nợ trực tiếp. | Yêu cầu sửa số dư bị core từ chối; điều chỉnh chỉ qua giao dịch điều chỉnh/reversal có reason code |
| BR-002 | Nhắc tự động AR quá hạn theo lịch cấu hình: FIN_L2 cấu hình mốc ngày + mẫu nội dung; mỗi lần nhắc ghi lịch sử (thời điểm, kênh, người gửi, nội dung) vào hóa đơn; không nhắc "miệng" không vết. | Lần nhắc không ghi lịch sử không được tính vào quá trình đòi nợ; audit thiếu vết là lỗi P1 |
| BR-003 | Theo dõi hạn thanh toán AP nền tảng: cảnh báo trước hạn theo cấu hình (đề xuất mặc định T-7 và T-3); AP quá hạn chưa thanh toán bật cảnh báo cho FIN_L2/CFO vì rủi ro gián đoạn TKQC. | Bỏ sót cảnh báo AP đến hạn phát alert lên BOD theo REQ-BOD-006 |
| BR-004 | Số dư AR là nguồn sự thật clawback hoa hồng: nợ >90 ngày → clawback 100% phần chưa thu; hệ thống gắn cờ clawback tự động trên hóa đơn vượt ngưỡng; dữ liệu đối chiếu cho SALES/HR ở GĐ3 đọc từ cờ này, không tính trùng lặp ở module khác. | Báo cáo hoa hồng dùng số AR từ nguồn khác không được công nhận; cờ clawback sai là lỗi dữ liệu nghiêm trọng |
| BR-005 | Financial Hard Stop "đã khớp tiền" (FIN_L1 xác nhận, WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; công nợ AR chỉ ghi nhận thanh toán thực nhận đã khớp — "khách hứa chuyển" không giảm được số dư nợ. | Ghi giảm AR khi chưa khớp tiền bị chặn; aging không phản ánh "tiền sắp về" |
| BR-006 | SoD 4 vai dòng tiền: đề xuất ≠ khớp tiền (FIN_L1) ≠ duyệt chi ≠ ghi sổ; người ghi nhận đòi nợ/thỏa thuận gia hạn ≠ người duyệt điều chỉnh/gia xóa công nợ; ngưỡng giải ngân thanh toán AP theo ma trận 5/50/200 triệu + delegate (đã chốt DI-001) áp dụng ở luồng duyệt chi. | Core block khi vai trùng; vi phạm log cho CFO rà định kỳ |
| BR-007 | Công nợ tranh chấp tách ticket riêng khỏi aging bình thường đến khi giải quyết; aging hiển thị hai khối "đang tranh chấp" và "bình thường" không cộng trộn; kết luận tranh chấp ghi lý do và được duyệt. | Tranh chấp "gây" vào aging thường làm sai báo cáo; tách sai bị chặn ở API |
| BR-008 | Khách có hợp đồng riêng về chu kỳ thanh toán: theo hợp đồng, không thấp hơn chuẩn tối thiểu (đối soát tuần, chốt tháng); aging tính hạn theo đúng chu kỳ hợp đồng từng khách, không áp đồng loạt mốc chuẩn. | Aging tính sai hạn theo hợp đồng tạo nhắc nợ/cảnh báo giả; cấu hình hạn từng khách phải trace về hợp đồng |
| BR-009 | Hóa đơn điện tử TT78/2021 + NĐ123/2020 phát hành trên doanh thu từ chứng từ đã khóa kỳ; AR ghi nhận gắn với HĐĐT đã phát hành; điều chỉnh công nợ chạm hóa đơn đã phát hành phải đi kèm nghiệp vụ điều chỉnh/thay thế hóa đơn chuẩn. | Điều chỉnh AR không khớp HĐĐT bị chặn trước khi chốt kỳ; tạo discrepancy bắt buộc giải trình |
| BR-010 | Phí nền tảng (AP) hạch toán vào giá vốn theo giao dịch gốc, tách khỏi doanh thu dịch vụ; aging AP hiển thị theo hồ sơ phí đã map giao dịch gốc; nghĩa vụ thuế liên quan (VAT/FCT) tham chiếu cấu hình thuế có phê duyệt. | AP không map được giao dịch gốc chuyển thành discrepancy ticket (theo BR-FIN-202/306), không nằm trong aging thường |
| BR-011 | Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, DI-004 ngày 12/09) — vendor-agnostic, import/export chuẩn + adapter API; đối chiếu sổ VAS định kỳ hàng tháng, chênh lệch phải có giải trình FIN_L2; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only. | Số aging BCERP lệch sổ VAS mà không có giải trình được coi là bất thường cần xử lý; cấm ghi ngược dữ liệu đã cutoff về legacy |
| BR-012 | Mốc xử lý khách không thanh toán: đề xuất giữ 2 bậc cảnh báo — tạm dừng dịch vụ (PAUSE) sau 15 ngày quá hạn và escalate xử lý sau 30 ngày `[KXN-22]` (đề xuất chờ khách hàng xác nhận, chưa chốt chính thức). | Trước khi KXN-22 chốt, hệ thống chỉ chạy cảnh báo nội bộ, không tự động tạm dừng dịch vụ của khách |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Chỉ dùng 18 vai registry; OPS chỉ thấy trạng thái TKQC, không thấy dòng tiền chi tiết (theo BR-FIN-603).

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | OPS_* |
|-----------|--------|--------|-------------|-----------|-------|
| Xem aging AR/AP toàn bộ | ✅ (khách được gán) | ✅ | ✅ | ❌ | ❌ (chỉ trạng thái TKQC) |
| Xem chi tiết hóa đơn + lịch sử thanh toán | ✅ (phạm vi gán) | ✅ | ✅ | ❌ | ❌ |
| Ghi nhận đòi nợ/liên lạc | ✅ (nhập thô) | ✅ | ❌ | ❌ | ❌ |
| Cấu hình lịch + mẫu nhắc nợ | ❌ | ✅ | ✅ (phê duyệt) | ❌ (thực thi sau duyệt) | ❌ |
| Đánh dấu/giải quyết tranh chấp | ❌ | ✅ | ✅ (duyệt kết luận) | ❌ | ❌ |
| Điều chỉnh/gia hạn công nợ (reversal) | ❌ | ✅ (đề xuất) | ✅ (duyệt) | ❌ | ❌ |
| Xuất báo cáo aging định kỳ | ✅ (chuẩn) | ✅ | ✅ | ❌ | ❌ |
| Xuất ngoài báo cáo chuẩn | ❌ | ❌ | ✅ (sau phê duyệt CEO) | ❌ | ❌ |

FIN_L1 xem số dư ví/lệnh/đối soát của khách được gán; FIN_L2 thấy toàn bộ khách; CFO/BOD xem tổng hợp + audit log — review ma trận truy cập hằng quý theo BR-FIN-603. Người thử việc/freelancer không có quyền thao tác công nợ.

---

## 5. Trường Hợp Đặc Biệt

- Khách có nhiều hợp đồng/chu kỳ thanh toán khác nhau: aging tính hạn riêng từng hóa đơn theo hợp đồng của hóa đơn đó; dashboard tổng hợp theo khách vẫn cộng đúng trên các bucket của từng hóa đơn.
- Thanh toán một phần: hóa đơn chuyển trạng thái "thanh toán một phần", phần còn lại tiếp tục aging từ hạn gốc; mỗi đợt thanh toán phải khớp tiền (Hard Stop FIN_L1) trước khi giảm dư nợ.
- Thanh toán không ghi rõ hóa đơn nào: FIN_L1 áp dụng theo quy tắc đối ứng cấu hình (FIFO theo hạn) và ghi chú; nếu không map được → tạo ticket xử lý thủ công có duyệt, không để tiền "treo" làm sai aging.
- Khách nước ngoài thanh toán bằng ngoại tệ: quy VND theo snapshot tỷ giá của giao dịch (dùng chung cơ chế REQ-FIN-004); aging hiển thị cả nguyên tệ và quy VND, chênh lệch tỷ giá xử lý theo nghiệp vụ kế toán chuẩn.
- Hóa đơn đã gắn cờ clawback (nợ >90 ngày) rồi khách thanh toán muộn: cờ clawback chuyển "đã giải tỏa" kèm timestamp — SALES/HR đối chiếu hoa hồng thực nhận theo khoảng thời gian nợ thực tế.
- Nhắc nợ trúng thời điểm khách đang tranh chấp: hệ thống tạm dừng lịch nhắc tự động cho hóa đơn tranh chấp, chuyển sang nhắc theo ticket tranh chấp có người phụ trách.
- AP của nền tảng tính phí theo tiền tệ khác VND: hạn thanh toán và số tiền hiển thị nguyên tệ; cảnh báo trước hạn dùng mốc cấu hình riêng từng nền tảng theo chu kỳ xuất hóa đơn của nền tảng đó.
- Dữ liệu ledger đang ở chế độ degraded (sync lỗi): aging hiển thị nhãn "dữ liệu tới HH:MM" và không cho kết luận chốt số; không nội suy số ẩn để báo cáo "cho đẹp".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hóa đơn công nợ (AR Invoice / AP Bill) — aging và cờ clawback là thuộc tính dẫn xuất do core tính, không phải trạng thái nhập tay.

**Sơ đồ trạng thái:**
```
[OPEN] ──(thanh toán một phần, đã khớp tiền)──► [PARTIALLY_PAID] ──(thanh toán đủ)──► [SETTLED]
   │                                                        │
   └──(quá hạn)──► [OVERDUE] ──(nợ >90 ngày: cờ clawback)──► [OVERDUE+CLAWBACK_FLAG]
[OPEN/…/OVERDUE] ──(phát sinh tranh chấp)──► [DISPUTED] ──(kết luận duyệt)──► về trạng thái tương ứng
[AP — Platform Bill] ──(đến hạn chưa chi)──► [PAYMENT_DUE_SOON] ──(quá hạn)──► [AP_OVERDUE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Thanh toán một phần | `PARTIALLY_PAID` | Hệ thống (từ khớp tiền FIN_L1) | Tiền đã khớp lệnh nạp — Hard Stop thỏa |
| `PARTIALLY_PAID` | Thanh toán đủ | `SETTLED` | Hệ thống | Tổng thanh toán khớp số dư nợ |
| `OPEN` | Quá hạn | `OVERDUE` | Hệ thống (timer aging) | Vượt hạn thanh toán theo hợp đồng |
| `OVERDUE` | Cờ clawback | `OVERDUE + CLAWBACK_FLAG` | Hệ thống | Quá hạn >90 ngày; thông báo SALES/HR đối chiếu |
| `OPEN/OVERDUE` | Tranh chấp | `DISPUTED` | FIN_L2 | Ticket tranh chấp + người phụ trách |
| `DISPUTED` | Kết luận | Về trạng thái cũ / `SETTLED` | FIN_L2 đề xuất, CFO duyệt | Lý do kết luận bắt buộc |
| `PAYMENT_DUE_SOON` | Chi thanh toán | `SETTLED` | Qua luồng duyệt chi FEAT-004 | Đủ chữ ký theo ngưỡng 5/50/200tr |

**Quy tắc:**
- `SETTLED` là trạng thái kết thúc; mở lại chỉ qua reversal có reason code và duyệt CFO.
- `DISPUTED` tách khỏi aging bình thường — aging tổng hiển thị riêng hai khối; hóa đơn tranh chấp không nhận nhắc nợ tự động.
- Aging bucket và cờ clawback do core tính lại định kỳ từ ledger; web không ghi đè.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ARInvoice | `id`, `client_id`, `contract_id`, `amount`, `due_date`, `status`, `einvoice_ref` | FK → khách/hợp đồng; FK → hóa đơn điện tử | Nguồn clawback flag |
| APBill | `id`, `platform`, `adaccount_ref`, `amount`, `currency`, `due_date`, `status` | FK → nền tảng/TKQC | Gắn phí theo giao dịch gốc |
| PaymentReceipt | `invoice_id`, `amount`, `matched_at`, `evidence_ref` | FK → `ar_invoice.id` | Chỉ ghi khi Hard Stop khớp tiền thỏa |
| DisputeTicket | `invoice_id`, `opened_by`, `resolution`, `resolved_at` | FK → hóa đơn | Tách khỏi aging thường |
| ReminderLog | `invoice_id`, `sent_at`, `channel`, `content_ref`, `sent_by` | FK → `ar_invoice.id` | Lịch sử nhắc nợ bắt buộc có vết |
| AgingSnapshot | `invoice_id`, `bucket`, `computed_at` | FK → hóa đơn | Dẫn xuất từ ledger, chỉ đọc |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Aging đúng bucket | Hóa đơn hạn 10/08, hôm nay 12/09 | Core chạy aging | Hóa đơn vào bucket 31–60; không thể sửa bucket tay | [ ] |
| SC-002: Nhắc nợ có vết | Hóa đơn quá hạn theo lịch nhắc ngày 5 | Hệ thống gửi nhắc | ReminderLog ghi thời điểm/kênh/nội dung; hiển thị ở lịch sử hóa đơn | [ ] |
| SC-003: Cờ clawback >90 ngày | Nợ quá hạn 91 ngày chưa thu | Core chạy job clawback flag | Cờ clawback bật; báo cáo đối chiếu SALES/HR thấy đúng hóa đơn | [ ] |
| SC-004: Tranh chấp tách aging | Hóa đơn 45 ngày bị khách tranh chấp | FIN_L2 mở ticket tranh chấp | Hóa đơn chuyển `DISPUTED`, tách khỏi aging thường; nhắc tự động dừng | [ ] |
| SC-005: Hard Stop bảo vệ số dư AR | Khách hứa chuyển tiền qua email | FIN thử ghi giảm nợ | Bị chặn — chỉ ghi nhận khi tiền khớp (FIN_L1 xác nhận); aging không đổi | [ ] |
| SC-006: Cảnh báo AP trước hạn | AP nền tảng đến hạn sau 7 ngày | Hệ thống tới mốc T-7 | Cảnh báo hiển thị cho FIN_L2/CFO; đề xuất duyệt chi kèm link hóa đơn | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-FIN-007 (Mục 2 — aging bucket, nhắc nợ, theo dõi AP, nguồn clawback).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/aging-ar-ap.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/arap-payment/` (aging engine, nhắc nợ); liên quan GĐ3: hoa hồng thực nhận SALES/HR |
