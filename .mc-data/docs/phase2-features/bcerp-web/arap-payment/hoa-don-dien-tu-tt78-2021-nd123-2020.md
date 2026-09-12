# Tính Năng: Hóa đơn điện tử TT78/2021 + NĐ123/2020

> **Dựa trên:** REQ-FIN-011 trong `phase1-business/departments/finance/finance.md` (Phần A)
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
| ID tính năng | FEAT-ERP-ARAP-005 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-FIN-011 — Hóa đơn điện tử TT78/2021 + NĐ123/2020 (HIGH, Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2 — xuất XML từ chứng từ đã khóa kỳ; kết nối thuế dùng chung REQ-FIN-013) |
| Phụ thuộc | Không có cross-dependency ngoài module; phụ thuộc trạng thái khóa kỳ (REQ-FIN-004) và kết nối cơ quan thuế/DV HĐĐT qua connector VAS (REQ-FIN-013) |
| Ghi chú Expert (A7) | Điểm phối hợp liên phòng (finance.md Mục A7): REQ-FIN-011 thuộc phần compliance do compliance-expert phân tích (BR-FIN-601/602) — ranh giới bắt buộc HĐĐT chỉ phát hành trên doanh thu, khớp BR-FIN-101 tiền giữ hộ |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng phát hành, tra cứu và điều chỉnh hóa đơn điện tử theo Thông tư 78/2021/TT-BTC và Nghị định 123/2020/NĐ-CP ngay trên web nội bộ: hệ thống sinh HĐĐT chuẩn XML có mã cơ quan thuế từ chứng từ doanh thu đã đối soát/khóa kỳ, gắn hợp đồng và thanh toán thực nhận. Ranh giới nghiệp vụ cốt lõi là HĐĐT chỉ phát hành trên doanh thu phí dịch vụ/markup — tuyệt đối không xuất hóa đơn cho dòng tiền giữ hộ của khách, bảo đảm sổ sách pháp lý khớp với thực chất kinh doanh trung gian quảng cáo.

**Phạm vi:**
- Bao gồm: màn phát hành HĐĐT trên web — chọn chứng từ doanh thu đủ điều kiện (đã đối soát/khóa kỳ), xem trước nội dung hóa đơn, gửi phát hành và nhận kết quả mã cơ quan thuế.
- Bao gồm: màn tra cứu danh mục HĐĐT theo khách/hợp đồng/kỳ/trạng thái (đã phát hành, điều chỉnh, thay thế, hủy, lỗi kết nối) với bộ lọc và xuất danh sách chuẩn.
- Bao gồm: nghiệp vụ điều chỉnh/thay thế/hủy theo quy trình chuẩn TT78/2021 + NĐ123/2020 (hóa đơn điều chỉnh, biên bản thỏa thuận) với log bất biến từng bước.
- Bao gồm: hiển thị trạng thái machine-state của hóa đơn (nháp điều kiện, chờ phát hành, đã có mã, bị từ chối mã, đã điều chỉnh) đúng như API core trả về.
- Bao gồm: quản lý lưu trữ HĐĐT theo quy định retention (tham chiếu bảng retention BR-FIN-503 — tiền/hóa đơn ≥10 năm WORM) và tra cứu lại bản gốc bất kỳ lúc nào.
- Bao gồm: hiển thị thời điểm lập hóa đơn theo NĐ123/2020 (hoàn thành cung cấp dịch vụ) trên từng chứng từ để FIN kiểm soát trước khi phát hành; chi tiết thời điểm từng loại dịch vụ chốt với tư vấn thuế `[CẦN CHỐT SỐ]`.
- Không bao gồm: kết nối hạ tầng gửi nhận XML đến cơ quan thuế/DV HĐĐT — vận hành bởi connector ở SYS-INTEGRATION-GW dùng chung luồng REQ-FIN-013; web gọi qua API core.
- Không bao gồm: xác định nghĩa vụ thuế FCT của nhà thầu nước ngoài (chi tiết tại FEAT-ERP-ARAP-007 — phí nền tảng & nghĩa vụ thuế); tính năng này chỉ bảo đảm dữ liệu hóa đơn tách bạch đúng nền tảng phát sinh.
- Không bao gồm: phát hành hóa đơn cho tiền giữ hộ/khách nạp — bị chặn tuyệt đối theo BR-FIN-101/601; web không hiển thị tùy chọn phát hành trên dòng tiền giữ hộ.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; dữ liệu nguồn của hóa đơn là chứng từ đã đối soát/khóa kỳ do core xác nhận, web không cho phát hành ngoài luồng này.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Chọn lô chứng từ doanh thu đã khóa kỳ và phát hành HĐĐT theo lô trên web | Phát hành đúng nhịp chốt kỳ, không soạn hóa đơn tay trên phần mềm riêng |
| 2 | FIN_L1 | Xem trước nội dung XML hóa đơn (mã số thuế hai bên, nội dung phí dịch vụ, thuế GTGT) trước khi gửi mã cơ quan thuế | Bắt lỗi dữ liệu trước khi phát hành, giảm phải điều chỉnh/hủy sau này |
| 3 | FIN_L2 | Rà soát danh mục HĐ trước chốt kỳ: hóa đơn nào chưa phát, nào phát sai cần điều chỉnh, nào bị từ chối mã | Kỳ chốt xong thì sổ hóa đơn sạch, không tồn "hóa đơn treo" |
| 4 | BOD_CFO_CTO | Duyệt nghiệp vụ điều chỉnh/thay thế/hủy hóa đơn có giá trị lớn hoặc ảnh hưởng doanh thu quý | Nghĩa vụ pháp lý về hóa đơn có người chịu trách nhiệm cuối cùng |
| 5 | FIN_L1 | Tra cứu lại bản gốc hóa đơn đã phát hành (XML + bản hiển thị) theo khách/hợp đồng/kể từ trước đó | Phục vụ thanh tra, đối chiếu khách hàng mà không tìm kho lưu trữ thủ công |
| 6 | FIN_L2 | Ghi nhận biên bản thỏa thuận với khách khi hủy/điều chỉnh hóa đơn và đính kèm vào hồ sơ hóa đơn | Đủ chứng từ nghiệp vụ chuẩn theo NĐ123/2020, log không thể sửa |
| 7 | BOD_CFO_CTO | Xem báo cáo tổng hợp HĐĐT theo tháng: số lượng, giá trị, trạng thái mã cơ quan thuế, tỷ lệ điều chỉnh | Kiểm soát tuân thủ thuế ở tầm nhìn tổng thể, phát hiện bất thường sớm |

Mọi thao tác phát hành/điều chỉnh đều gọi API core; kết quả mã cơ quan thuế trả về qua connector GW và web chỉ hiển thị trạng thái — không có chế độ "phát hành offline" tách rời luồng chuẩn.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Ràng buộc pháp lý do core enforce; web phải chặn UI tương ứng và hiển thị đúng lỗi business.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | HĐĐT phát hành chuẩn XML có mã cơ quan thuế theo TT78/2021 + NĐ123/2020; dữ liệu nguồn bắt buộc là chứng từ đã đối soát/khóa kỳ, gắn hợp đồng và thanh toán thực nhận. | Chứng từ chưa khóa kỳ không xuất hiện trong danh sách phát hành; yêu cầu phát hành ngoài luồng bị core từ chối + log |
| BR-002 | Ranh giới bắt buộc: HĐĐT chỉ phát hành trên doanh thu phí dịch vụ/markup — tuyệt đối không xuất hóa đơn cho dòng tiền giữ hộ của khách (khớp BR-FIN-101); nạp tiền của khách là nợ phải trả, không phải doanh thu. | Web không hiển thị tùy chọn phát hành trên dòng giữ hộ; mọi attempt bị chặn cứng + audit log bất biến |
| BR-003 | Financial Hard Stop "đã khớp tiền" FIN_L1 (WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; hóa đơn doanh thu gắn thanh toán thực nhận — doanh thu của hóa đơn phải ứng khoản thu đã khớp, không lập trên "khách hứa chuyển". | Hóa đơn gắn thanh toán chưa khớp bị chặn khi tạo; dữ liệu đối ứng sai là lỗi P1 |
| BR-004 | Thời điểm lập HĐ theo NĐ123/2020 — hoàn thành cung cấp dịch vụ; chi tiết thời điểm từng loại dịch vụ (agency, ads ops, SEO, web/thiết kế) chốt với tư vấn thuế `[CẦN CHỐT SỐ]`; hệ thống cấu hình thời điểm theo nhóm dịch vụ, có phê duyệt. | Phát hành lệch thời điểm cấu hình bị cảnh báo bắt buộc giải trình trước khi gửi mã |
| BR-005 | Điều chỉnh/thay thế/hủy chỉ qua nghiệp vụ chuẩn (hóa đơn điều chỉnh, hóa đơn thay thế, biên bản thỏa thuận) có log bất biến — không xóa/sửa XML đã phát hành; cơ quan thuế từ chối mã → xử lý theo hướng dẫn, không phát hành lại đè lên hồ sơ cũ. | Yêu cầu sửa XML gốc bị chặn; phát hành đè hồ sơ cũ bị core từ chối và log |
| BR-006 | SoD 4 vai dòng tiền: người phát hành hóa đơn ≠ người duyệt điều chỉnh/hủy giá trị lớn ≠ người ghi sổ; ngưỡng giải ngân 5/50/200 triệu + delegate áp dụng cho chuỗi chứng từ chi đối ứng; công nợ AR/AP aging cập nhật khi hóa đơn điều chỉnh ảnh hưởng dư nợ. | Vai trùng bị core block; hóa đơn điều chỉnh không cập nhật aging là lỗi dữ liệu |
| BR-007 | HĐĐT lưu trữ theo quy định retention (BR-FIN-503 — tiền/hóa đơn ≥10 năm, WORM storage); bản gốc XML bất biến, có hash kiểm tra toàn vẹn; tra cứu/xuất ngoài báo cáo chuẩn cần phê duyệt. | Xuất không phê duyệt bị chặn; hash lệch phát alert nghiêm trọng cho BOD |
| BR-008 | Công nợ AR/AP + aging + nhắc nợ: hóa đơn phát hành là hóa đơn AR trong aging (REQ-FIN-007); hóa đơn điều chỉnh/giảm trừ cập nhật số dư AR qua giao dịch có reason code; nhắc nợ chạy trên số dư sau điều chỉnh. | Aging hiển thị số trước điều chỉnh bị coi là sai dữ liệu; mọi thay đổi số dư phải trace về hóa đơn/lệnh điều chỉnh |
| BR-009 | Kết nối cơ quan thuế/DV HĐĐT dùng chung connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, DI-004 ngày 12/09) — vendor-agnostic, import/export chuẩn + adapter API; connector fail → hàng chờ retry + alert, không ghi tay đè luồng chuẩn. | Gửi XML ngoài connector bị chặn; lỗi kết nối hiển thị trạng thái rõ cho FIN_L1 với timestamp |
| BR-010 | Legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only: hóa đơn dữ liệu lịch sử sau migrate chỉ đọc từ BCERP, không phát hành/điều chỉnh ngược trên hệ thống legacy. | Cố tình ghi dữ liệu hóa đơn về legacy sau cutoff bị chặn; hồ sơ legacy chỉ tham chiếu |
| BR-011 | Phí nền tảng & nghĩa vụ thuế: hóa đơn doanh thu tách bạch với phí nền tảng (giá vốn media) và nghĩa vụ thuế liên quan (VAT đầu ra trên phí dịch vụ; FCT xử lý riêng theo FEAT-ERP-ARAP-007); nội dung hóa đơn phản ánh đúng cấu trúc phí dịch vụ theo hợp đồng. | Hóa đơn ghi lẫn phí nền tảng/giá vốn bị chặn khi tạo; sai cấu trúc phí tạo discrepancy bắt buộc xử lý trước khi gửi mã |
| BR-012 | Mọi thao tác phát hành/điều chỉnh/hủy/tra cứu xuất ghi audit log kèm reason code và kênh (web); dữ liệu tài chính khách là mức Restricted — truy cập theo ma trận BR-FIN-603, mỗi lần xem bị meta-log. | Truy cập ngoài ma trận bị chặn; xem không meta-log là vi phạm bảo mật dữ liệu tài chính |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Chỉ dùng 18 vai registry; OPS không thấy dòng tiền/chi tiết hóa đơn (chỉ trạng thái TKQC — BR-FIN-603).

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | OPS_* |
|-----------|--------|--------|-------------|-----------|-------|
| Xem danh mục HĐĐT | ✅ (khách được gán) | ✅ | ✅ | ❌ | ❌ |
| Phát hành HĐĐT từ chứng từ khóa kỳ | ✅ | ✅ (phê duyệt lô lớn) | ❌ | ❌ | ❌ |
| Xem trước XML/nội dung hóa đơn | ✅ | ✅ | ✅ | ❌ | ❌ |
| Tạo đề nghị điều chỉnh/thay thế/hủy | ✅ (nhập hồ sơ) | ✅ | ❌ | ❌ | ❌ |
| Duyệt điều chỉnh/thay thế/hủy giá trị lớn | ❌ | ✅ (ngưỡng nhỏ) | ✅ (lớn/ảnh hưởng quý) | ❌ | ❌ |
| Đính kèm biên bản thỏa thuận | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xuất báo cáo HĐ định kỳ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xuất/truy xuất ngoài báo cáo chuẩn | ❌ | ❌ | ✅ (sau phê duyệt CEO) | ❌ | ❌ |
| Cấu hình thời điểm lập HĐ theo nhóm dịch vụ | ❌ | ✅ (đề xuất) | ✅ (phê duyệt) | ✅ (thực thi sau duyệt) | ❌ |

SYS_ADMIN chỉ thực thi cấu hình sau phê duyệt, không thao tác nghiệp vụ hóa đơn; người thử việc/freelancer không có quyền phát hành/điều chỉnh hóa đơn.

---

## 5. Trường Hợp Đặc Biệt

- Cơ quan thuế/DV HĐĐT từ chối mã: hóa đơn chuyển trạng thái "bị từ chối" kèm lý do từ connector; FIN_L1 xử lý theo hướng dẫn (sửa dữ liệu → tạo tờ khai phát hành mới), hồ sơ từ chối giữ nguyên làm lịch sử — không phát hành lại đè.
- Hóa đơn cần điều chỉnh sau khi khách đã thanh toán: nghiệp vụ điều chỉnh/giảm trừ tạo hóa đơn điều chỉnh đối ứng, cập nhật AR qua giao dịch có reason code; nếu ảnh hưởng thanh toán thực nhận, phải đối chiếu lại lệnh khớp tiền — không sửa trực tiếp hóa đơn gốc.
- Khách nước ngoài không có MST VN: hóa đơn lập theo mã số thuế/tương đương theo quy định cho tổ chức nước ngoài; dữ liệu KH đã được chuẩn hóa từ KYC (REQ-FIN-009) để tránh lỗi MST khi gửi mã.
- Lô phát hành lớn cuối tháng: phát hành theo lô có tiến độ và kết quả từng hóa đơn; lỗi từng hóa đơn không chặn toàn lô — hóa đơn lỗi ở lại hàng chờ xử lý, hóa đơn hợp lệ hoàn tất.
- Chứng từ doanh thu phát hiện sai sau khi khóa kỳ: xử lý bằng reversal khóa kỳ theo REQ-FIN-004 (CFO duyệt mở kỳ/backfill — REQ-BOD-010) trước khi hóa đơn được điều chỉnh; web hiển thị chuỗi phụ thuộc chứng từ ↔ hóa đơn để FIN thao tác đúng thứ tự.
- Connector thuế/VAS gián đoạn: hóa đơn chờ ở trạng thái "chờ kết nối" với timestamp; khi connector hồi phục, hàng chờ retry tự động và FIN_L1 được thông báo kết quả — không ghi tay kết quả mã.
- Hóa đơn cho hợp đồng nhiều kỳ dịch vụ: phát hành theo từng kỳ hoàn thành theo cấu hình thời điểm lập HĐ; mỗi hóa đơn gắn kỳ dịch vụ cụ thể để tra cứu và điều chỉnh không đè chéo kỳ.
- Tra cứu phục vụ thanh tra: xuất toàn bộ hồ sơ hóa đơn của khách/kỳ theo luồng xuất có phê duyệt (CEO duyệt xuất ngoài chuẩn); kết quả xuất bị log để truy vết ai lấy dữ liệu gì.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hóa đơn điện tử (E-Invoice).

**Sơ đồ trạng thái:**
```
[ELIGIBLE] ──(FIN_L1 tạo lô phát hành)──► [PENDING_ISSUANCE] ──(gửi qua connector GW)──► [ISSUED]
                                              │                                            │
                                              │ (lỗi dữ liệu bị từ chối trước gửi)          │ (cơ quan thuế cấp mã)
                                              ▼                                            ▼
                                         [DRAFT_ERROR]                              [ISSUED_WITH_CODE]
[ISSUED_WITH_CODE] ──(điều chỉnh/thay thế/hủy chuẩn)──► [ADJUSTED / REPLACED / CANCELLED] ──(lưu trữ WORM)──► [ARCHIVED]
[PENDING_ISSUANCE] ──(connector fail)──► [WAITING_CONNECTION] ──(retry OK)──► về luồng phát hành
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ELIGIBLE` | Tạo lô phát hành | `PENDING_ISSUANCE` | FIN_L1 | Chứng từ đã khóa kỳ; doanh thu khớp thanh toán thực nhận; đúng nhóm dịch vụ |
| `PENDING_ISSUANCE` | Gửi phát hành | `ISSUED` | Hệ thống (qua connector GW) | XML hợp lệ; nhận mã cơ quan thuế |
| `PENDING_ISSUANCE` | Lỗi dữ liệu | `DRAFT_ERROR` | FIN_L1 | Lỗi trả về trước gửi; sửa rồi tạo lô mới |
| `PENDING_ISSUANCE` | Connector fail | `WAITING_CONNECTION` | Hệ thống | Hàng chờ retry + alert |
| `ISSUED` | Điều chỉnh | `ADJUSTED` | FIN_L2 đề xuất / CFO duyệt giá trị lớn | Hóa đơn điều chỉnh + biên bản; log bất biến |
| `ISSUED` | Thay thế | `REPLACED` | FIN_L2 / CFO duyệt | Hóa đơn thay thế tham chiếu gốc |
| `ISSUED` | Hủy | `CANCELLED` | FIN_L2 / CFO duyệt | Biên bản thỏa thuận với khách; lý do bắt buộc |
| `ADJUSTED/REPLACED/CANCELLED` | Lưu trữ định kỳ | `ARCHIVED` | Hệ thống | Bản gốc + mọi phiên bản điều chỉnh giữ trên WORM ≥10 năm |

**Quy tắc:**
- `ARCHIVED`, `CANCELLED` là trạng thái kết thúc; `ISSUED` không bao giờ quay về `PENDING_ISSUANCE` — sửa sai chỉ qua điều chỉnh/thay thế/hủy chuẩn.
- XML đã phát hành bất biến: mọi chỉnh sửa là một tài liệu mới tham chiếu tài liệu cũ; hash-chain bảo vệ toàn vẹn chuỗi hóa đơn.
- Web hiển thị đúng trạng thái từ core; không có hành động UI nào không tương ứng một transition hợp lệ trong bảng trên.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| EInvoice | `id`, `series`, `number`, `client_tax_id`, `service_amount`, `vat`, `status`, `gov_code`, `issued_at` | FK → chứng từ doanh thu (đã khóa kỳ), FK → hợp đồng | XML gốc bất biến + hash |
| IssuanceBatch | `batch_id`, `period`, `items[]`, `sent_at`, `result_summary` | FK → `e_invoice.id` | Phát hành theo lô, lỗi từng item riêng |
| AdjustmentDoc | `invoice_id`, `type` (adjust/replace/cancel), `reason`, `approved_by`, `agreement_ref` | FK → `e_invoice.id` | Nghiệp vụ chuẩn TT78/NĐ123 |
| RevenueSource | `voucher_id`, `period_locked_at`, `matched_payment_ref` | FK → chứng từ khóa kỳ | Điều kiện tiên quyết của `ELIGIBLE` |
| AuditLog (tham chiếu) | `object`, `action`, `reason_code`, `channel` | Append-only, hash-chain | Phát hành/điều chỉnh/tra cứu xuất đều log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn phát hành trên tiền giữ hộ | Dòng tiền nạp của khách (nợ phải trả) | FIN tìm tùy chọn phát hành hóa đơn | Không có tùy chọn; attempt qua API bị chặn + log | [ ] |
| SC-002: Phát hành từ chứng từ khóa kỳ | Chứng từ doanh thu 09/2026 đã khóa kỳ, khớp thanh toán | FIN_L1 phát hành | Nhận mã cơ quan thuế; trạng thái `ISSUED`; XML lưu WORM | [ ] |
| SC-003: Chặn chứng từ chưa khóa kỳ | Chứng từ chưa đối soát xong | Thêm vào lô phát hành | Bị loại khỏi lô; thông báo lý do "chưa khóa kỳ" | [ ] |
| SC-004: Điều chỉnh chuẩn | Hóa đơn đã mã, sai số lượng dịch vụ | FIN_L2 tạo điều chỉnh + biên bản, CFO duyệt | Hóa đơn `ADJUSTED`; bản gốc giữ nguyên; AR cập nhật có reason code | [ ] |
| SC-005: Connector fail → retry | Kết nối DV HĐĐT gián đoạn lúc gửi lô | Lô đang gửi | Hóa đơn về `WAITING_CONNECTION`; retry tự động khi hồi phục; không ghi tay mã | [ ] |
| SC-006: Từ chối mã không đè hồ sơ | Cơ quan thuế từ chối cấp mã | FIN xử lý theo hướng dẫn | Hồ sơ từ chối giữ nguyên lịch sử; tờ phát hành mới tham chiếu hồ sơ cũ | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-FIN-011 (Mục 2 — XML mã cơ quan thuế, chứng từ khóa kỳ, điều chỉnh chuẩn, lưu trữ).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/einvoice-management.md` |
| Bản fan-out counterpart | `phase2-features/integration-gw/arap-payment/` (connector thuế/VAS), `phase2-features/core-backend/arap-payment/` (sinh XML) |
