# Real Estate Controls

> Reference file cho real-estate-expert agent
> Load file này khi cần xác định kiểm soát pháp lý và tài chính trong BĐS

---

## 1. Giỏ hàng Lock/Hold Controls

### Quy tắc cơ bản

| Control | Quy định | Lý do |
|---------|----------|-------|
| Hold duration | Tối đa 48 giờ không có deposit → auto-release | Tránh inventory bị lock vô thời hạn |
| Concurrent holds | 1 broker chỉ được hold tối đa N căn cùng lúc (N do developer quy định theo policy đợt mở bán) | Ngăn broker chiếm giỏ hàng |
| Override | Sales Manager có thể extend hold (yêu cầu approval với lý do) | Trường hợp KH cần thêm thời gian hợp lý |
| Deposit confirmation | Lock chỉ được confirm sau khi ngân hàng xác nhận nhận tiền — KHÔNG auto-confirm khi chỉ có transfer slip của KH | Ngăn gian lận booking |

### Audit Trail Requirements

Mọi sự kiện sau phải được log với timestamp và user ID:
- Lock request (broker_id, unit_id, hold_duration)
- Deposit received (amount, bank_reference, confirmed_by)
- Manual override / extend (requested_by, approved_by, reason)
- Auto-release (reason: timeout / broker_cancel / system_release)
- Status change: Available → Hold → Reserved → Sold → Cancelled

---

## 2. Approval Matrix cho Discount & Giá

| Mức chiết khấu | Người phê duyệt | Thời gian xử lý |
|----------------|-----------------|-----------------|
| 0 – 2% | Nhân viên kinh doanh (tự quyết) | Ngay lập tức |
| 2 – 5% | Trưởng phòng kinh doanh | Trong 4 giờ làm việc |
| 5 – 10% | Giám đốc kinh doanh | Trong 1 ngày làm việc |
| > 10% | Tổng Giám đốc / Hội đồng | Trong 2 ngày làm việc |
| Cashback / gift / ưu đãi đặc biệt | Theo policy riêng từng đợt mở bán | Phải có văn bản policy |

### Ghi chú thực thi
- Hệ thống PHẢI enforce approval matrix — broker không thể tự ý áp discount vượt mức
- Mọi discount đặc biệt phải được ghi nhận vào HĐMB chính thức
- Discount không được tính vào base để tính hoa hồng (hoa hồng tính trên GTCH chính sách)

---

## 3. Revenue Recognition (BĐS Việt Nam)

### Theo Thông tư 200/2014/TT-BTC (chuẩn kế toán VN)

| Loại tiền nhận | Ghi nhận kế toán | Tài khoản |
|----------------|-----------------|-----------|
| Tiền đặt cọc (5%) | Deposits received (nợ phải trả) | TK 131 hoặc TK 338 |
| Tiền đợt 1-N (trước bàn giao) | Advance from customers | TK 131 |
| Bàn giao căn hộ | Ghi nhận Doanh thu (risk/reward transferred) | TK 511 |
| Đợt cuối + sổ đỏ | Doanh thu khi bàn giao pháp lý | TK 511 |

**Nguyên tắc cốt lõi**: Tiền KH đóng trước khi bàn giao **KHÔNG PHẢI doanh thu** — chỉ là deposits/advances. Revenue chỉ được ghi nhận khi bàn giao căn hộ thực tế.

### Theo IFRS 15 (nếu áp dụng)

- Có thể ghi nhận theo % hoàn thành (percentage-of-completion method) nếu:
  - KH có quyền sở hữu land/building đang xây dựng (enforceable right)
  - Developer thực hiện nghĩa vụ "over time"
- Cần tư vấn auditor để xác định phương pháp áp dụng

### Lưu ý cho hệ thống phần mềm

- Tách biệt rõ ràng: Collected cash ≠ Revenue
- Dashboard tài chính phải show cả 2: Cash collected và Revenue recognized
- KHÔNG hiển thị tiền đặt cọc là "doanh thu" trong bất kỳ report nào

---

## 4. Escrow Controls

### Yêu cầu Pháp lý (Luật KDBĐS 2023)

| Yêu cầu | Chi tiết | Penalty nếu vi phạm |
|---------|----------|---------------------|
| Bảo lãnh ngân hàng | Developer phải có bảo lãnh NH cho dự án off-plan trước khi mở bán | Không được mở bán, phạt hành chính |
| Separate escrow account | Tiền KH đóng phải vào tài khoản riêng biệt, không được dùng cho operating expenses | Truy cứu hình sự trong trường hợp nghiêm trọng |
| Release conditions | Chỉ được rút tiền từ escrow khi đạt milestone (nghiệm thu hạng mục, bàn giao) | Breach of fiduciary duty |

### Quy trình Escrow

```
Bước 1: KH chuyển khoản vào Escrow Account (số TK của NH bảo lãnh)
Bước 2: NH xác nhận nhận tiền → System cập nhật trạng thái booking
Bước 3: Developer xin release khi đạt milestone (gửi biên bản nghiệm thu)
Bước 4: NH verify milestone → Release tiền vào Operating Account developer
Bước 5: Hàng tháng: Reconcile Escrow Bank Statement vs System
```

### Điều kiện Release Tiền Escrow

| Milestone | % Release | Tài liệu cần thiết |
|-----------|-----------|---------------------|
| Hoàn thành móng | 10-15% | Biên bản nghiệm thu móng |
| Xong kết cấu | 15-20% | Biên bản nghiệm thu kết cấu |
| Hoàn thiện | 20-25% | Biên bản nghiệm thu hoàn thiện |
| Bàn giao KH | Phần còn lại | Biên bản bàn giao + nghiệm thu PCCC |

---

## 5. AML Check (Phòng chống Rửa tiền — BĐS)

### Khung Pháp lý

- **Luật Phòng chống Rửa tiền 2022** (sửa đổi): BĐS là lĩnh vực rủi ro cao
- **Thông tư 09/2023/TT-NHNN**: Hướng dẫn thực hiện phòng chống rửa tiền cho tổ chức kinh doanh BĐS

### Ngưỡng Báo cáo Bắt buộc

| Loại giao dịch | Ngưỡng | Hành động |
|----------------|--------|-----------|
| Giao dịch tiền mặt | > 300 triệu VND/lần | Báo cáo NHNN trong 1 ngày làm việc |
| Giao dịch điện tử đáng ngờ | Bất kỳ ngưỡng | Lập Báo cáo Giao dịch Đáng ngờ (STR) |
| Giao dịch phân nhỏ (structuring) | Nhiều giao dịch nhỏ cộng lại > 300tr | Báo cáo ngay khi phát hiện pattern |

### KYC Requirements cho Giao dịch BĐS

```
Bắt buộc cho tất cả KH:
□ CMND/CCCD + Hộ khẩu (còn hiệu lực)
□ Nguồn gốc thu nhập (payslip, BCTC, giải thích)
□ Beneficial Owner Identification: Ai là người thụ hưởng thực sự?
  → Nếu mua chung: cần KYC cả vợ/chồng
  → Nếu mua qua công ty: cần KYC cổ đông > 25%
  → Nếu người khác đứng tên: cần giải thích và chứng minh

Tăng cường cho giao dịch rủi ro cao:
□ KH là Politically Exposed Person (PEP): Enhanced due diligence
□ KH nước ngoài: Hộ chiếu + Visa + nguồn vốn từ nước ngoài
□ Thanh toán từ tài khoản bên thứ ba: Xác minh mối quan hệ
```

### Suspicious Transaction Reporting (STR)

Các dấu hiệu phải report:
- KH yêu cầu thanh toán tiền mặt lớn bất thường
- Mua nhiều căn cùng lúc không có lý do rõ ràng
- Hủy hợp đồng và yêu cầu hoàn tiền cho người khác
- Nguồn tiền từ quốc gia/vùng lãnh thổ rủi ro cao
- Giao dịch không khớp với thu nhập/tài sản kê khai

**Deadline**: Báo cáo STR trong vòng 24 giờ kể từ khi phát hiện giao dịch đáng ngờ.

---

## 6. Commission Dual Control

### Quy tắc Kiểm soát Hoa hồng

| Bước | Người thực hiện | Kiểm tra | Không được phép |
|------|-----------------|----------|-----------------|
| Tính hoa hồng | KD team | Bảng policy đợt, GTCH, điều kiện | Tự ý điều chỉnh %, không có căn cứ |
| Verify | Kế toán | Cross-check với hợp đồng, GTCH thực tế, điều kiện đã đủ chưa | Approve khi chưa đủ điều kiện |
| Approve | Giám đốc / CFO | Tổng commission batch, budget tháng | Bypass approval |
| Payment | Kế toán thanh toán | Sau khi có phê duyệt | Trả khi chưa approved |

### Điều kiện Đủ để Tính Hoa hồng

- KH đã ký HĐMB chính thức (có công chứng)
- KH đã đóng ít nhất threshold % (thường 30-50% GTCH, tùy policy)
- HĐMB chưa bị hủy và còn trong clawback period
- Broker không vi phạm điều khoản hợp đồng phân phối

### Clawback Tracking

```
Sự kiện trigger clawback:
- KH hủy HĐMB trong 30-60 ngày đầu (tùy điều khoản)
- Developer hủy vì lý do lỗi của sàn/broker

Quy trình clawback:
1. Hệ thống auto-flag hợp đồng có clawback risk
2. Thông báo cho sàn/broker trước khi clawback
3. Trừ vào batch commission tiếp theo (không yêu cầu hoàn tiền mặt)
4. Audit trail ghi nhận toàn bộ lý do, người xử lý
```

---

## 7. Legal Document Controls

### Kiểm soát Tài liệu Pháp lý

| Loại tài liệu | Retention | Quyền truy cập | Không được |
|---------------|-----------|----------------|-----------|
| HĐMB + Phụ lục | Vĩnh viễn | Legal, KD, KH (chính mình) | Xóa, sửa bản gốc |
| CMND/CCCD KH | 5 năm sau kết thúc HĐ | Legal, Compliance | Chia sẻ cho bên thứ 3 không liên quan |
| Biên lai thu tiền | 10 năm (theo quy định kế toán) | KH, Kế toán | Xóa |
| Biên bản bàn giao | Vĩnh viễn | Legal, KH | Sửa sau khi KH đã ký |
| Sổ đỏ (scan) | Vĩnh viễn | Legal, KH | Phát tán |

### Version Control Requirements

- Mọi phiên bản tài liệu phải được lưu (không overwrite)
- Version cuối cùng được ký là "final" — sau đó chỉ có thể tạo phụ lục
- Access log: Ghi nhận ai xem, ai tải về, khi nào
- Xóa tài liệu: Không được phép — chỉ archive với lý do và approval
