# Đối soát công nợ nền tảng, ghi nhận doanh thu & đa tiền tệ — BCERP

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Tài chính
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** finance-expert (Kế toán trưởng FIN_L2)
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md` (mô hình agency trung gian TKQC)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `han-muc-chi-giai-ngan-sod.md` (ngưỡng duyệt điều chỉnh)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Toàn bộ dòng tiền ví tài khoản quảng cáo (TKQC) của khách trên mọi nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) — nạp của khách, nạp thực tế vào nền tảng, chi tiêu thực tế; sổ phụ ví từng khách; công nợ AR (khách) và AP (nền tảng); ghi nhận doanh thu dịch vụ; refund/điều chỉnh; đa tiền tệ; import statement khi chưa có API.
- **Không áp dụng cho:** Chi phí vận hành nội bộ — thuộc policy "Hạn mức chi, giải ngân, mua hàng & SoD"; dịch vụ phi quảng cáo (SEO, web, thiết kế) chỉ áp dụng nguyên tắc ghi nhận doanh thu theo hợp đồng.
- **Effective từ:** Ngày CFO phê duyệt chính sách (điền khi user xác nhận Section 6).

---

## 2. Nội Dung Chính Sách

### 2.1. Nguyên tắc gốc — tiền nạp ví TKQC là TIỀN GIỮ HỘ

- Tiền khách nạp vào ví TKQC là **tiền giữ hộ (nợ phải trả — liability)**, **KHÔNG phải doanh thu**.
- Khách nạp → ghi tăng tiền giữ hộ (đối ứng tiền nhận về/công nợ AR); nền tảng trừ chi tiêu → ghi giảm tiền giữ hộ và ghi nhận **doanh thu chỉ trên phần phí dịch vụ/markup** theo hợp đồng.
- Mỗi khách có **sổ phụ ví riêng**: nạp, chi tiêu, phí, điều chỉnh, số dư khả dụng — không gộp chung, không bù trừ chéo ví.

### 2.2. Đối trừ 3 số theo TK/khách/nền tảng

Ba vế bắt buộc khớp, ở 3 cấp độ (TKQC → khách → nền tảng):

1. **Số khách nạp** (sổ phụ ví BCERP);
2. **Số thực nạp vào nền tảng** (statement/API dashboard nền tảng);
3. **Chi tiêu thực tế** (spend báo cáo bởi nền tảng).

| Cấp đối trừ | Chu kỳ | Mức dung sai (đề xuất) | Người thực hiện |
|---|---|---|---|
| Nạp: sổ phụ ví ↔ nền tảng, theo dòng tiền | Ngày | Sai số tuyệt đối = 0 trên từng dòng nạp | FIN_L1 |
| Chi tiêu: hệ thống ↔ nền tảng, theo TKQC | Ngày | ≤ 0,5% hoặc ≤ 10 USD/TK/ngày (mức thấp hơn) | FIN_L1 |
| Chi tiêu tích lũy theo khách + số dư ví | Tuần | ≤ 1% hoặc ≤ 20 USD/khách/tuần | FIN_L1 |
| Chốt công nợ AR/AP toàn nền tảng | Tháng | Chênh lệch nào cũng phải có giải trình — không có mức "chấp nhận được" | FIN_L2 |

> Mức dung sai là **đề xuất**, chốt khi user xác nhận Section 6.

### 2.3. Quy trình xử lý sai lệch (discrepancy)

- Trong dung sai → đánh dấu **"Đã đối soát (dung sai)"**, hạch toán vào tài khoản sai lệch đối soát, FIN_L2 rà theo tuần.
- Vượt dung sai → tạo **ticket discrepancy** với đủ: TKQC, nền tảng, khách, hai con số, nguồn, timestamp. FIN_L1 điều tra gốc rễ và **phải giải trình FIN_L2 trước chốt ngày đối soát đó**. Cấm tự cân số để hai vế khớp.
- Trạng thái đối soát chuẩn hóa: **Chưa đối soát / Đã đối soát / Chênh lệch (đang xử lý) / Đã điều chỉnh (có phiếu duyệt)**.

### 2.4. Chốt kỳ & khóa kỳ (period lock)

- FIN_L2 **chốt công nợ nền tảng hằng tháng** (đề xuất: ngày 3 tháng kế tiếp): khớp AR/AP, rà discrepancy chưa xử lý.
- Sau chốt: **khóa kỳ** — mọi chứng từ trong kỳ bị chặn sửa/xóa.
- **Mở kỳ chỉ CFO duyệt** bằng phiếu mở kỳ ghi rõ lý do, phạm vi, thời hạn; ghi audit log bất biến; sau khi sửa xong bắt buộc chốt lại.

### 2.5. Refund & điều chỉnh công nợ

- Mọi refund/điều chỉnh số dư ví **chỉ thực hiện qua phiếu duyệt** (lý do, số tiền, TKQC, người duyệt đúng hạn mức theo policy hạn mức chi) — không có kênh ngoài hệ thống.
- Mọi điều chỉnh ghi **audit log bất biến (append-only)**: ai, khi nào, giá trị trước/sau, phiếu tham chiếu. Không hỗ trợ hard-delete.

### 2.6. Đa tiền tệ

- **Sổ gốc VND**: mọi giao dịch ngoại tệ quy đổi theo **snapshot tỷ giá ghi ngay tại thời điểm giao dịch** và khóa lại — không cập nhật truy lịch.
- **Lãi/lỗ FX ghi khoản riêng**, tách biệt hoàn toàn khỏi giá vốn và gross margin dịch vụ — hiệu ứng tỷ giá không được làm méo P&L dịch vụ.

### 2.7. Import statement khi chưa có API

- Nền tảng chưa kết nối API phải nạp statement theo **chuẩn import thống nhất** (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu).
- Sau import, hệ thống tự đối soát và gắn **trạng thái đã đối soát/chênh lệch** như luồng API; import sai schema bị chặn.

### 2.8. Công nợ AR/AP: aging & nhắc nợ

- Aging AR (khách) & AP (nền tảng) theo bucket: **0–30 / 31–60 / 61–90 / >90 ngày**.
- Nhắc tự động: cảnh báo ví khách sắp hết quỹ (dưới ngưỡng cấu hình), nhắc AR quá hạn; theo dõi hạn thanh toán AP nền tảng để tránh gián đoạn TKQC.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Nền tảng không có API statement**: đối soát ngày hạ xuống tuần qua import; bù khớp tích lũy khi có API.
- **Sai lệch do chênh giờ ghi nhận/tỷ giá giữa BC và nền tảng**: xử lý qua khoản FX/timing riêng, không tính vi phạm dung sai chi tiêu.
- **Refund khẩn** (TKQC bị khóa, lỗi nạp trùng): CFO duyệt nhanh qua kênh khẩn, chứng từ hợp thức hóa và hậu kiểm trong 24h.
- **Khách có hợp đồng riêng** về chu kỳ đối soát: theo hợp đồng, không thấp hơn chuẩn tối thiểu (đối soát tuần, chốt tháng).

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|---|---|---|
| Đối soát trong dung sai | FIN_L1 tự xử lý, FIN_L2 rà soát | Hằng ngày |
| Discrepancy vượt dung sai | FIN_L2 (giải trình bởi FIN_L1) | Trước chốt ngày đối soát (T+1) |
| Chốt công nợ nền tảng + khóa kỳ | FIN_L2 | Ngày 3 tháng kế tiếp |
| Mở kỳ đã khóa | CFO | 24h kể từ yêu cầu |
| Refund/điều chỉnh ≤ 10 triệu VND (hoặc quy đổi) | FIN_L2 | 24h |
| Refund/điều chỉnh > 10 triệu VND | CFO | 24h |
| Điều chỉnh ảnh hưởng P&L tháng đã chốt | CFO | 48h |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---|---|---|---|
| Sổ phụ ví riêng từng khách; tiền nạp ghi nhận là nợ phải trả (tiền giữ hộ), cấm tự động tính thành doanh thu | Logic | Finance — Ví & Sổ phụ | MUST |
| Đối trừ 3 số tự động theo TK/khách/nền tảng, chu kỳ ngày/tuần/tháng, dung sai cấu hình được | Logic | Finance — Đối soát | MUST |
| Trạng thái đối soát: Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh | Validation | Finance — Đối soát | MUST |
| Ticket discrepancy bắt buộc khi vượt dung sai; chặn chốt kỳ khi còn ticket chưa giải trình | Enforcement | Finance — Đối soát + Khóa kỳ | MUST |
| Period lock: chặn sửa/xóa chứng từ đã chốt; mở kỳ yêu cầu duyệt CFO + lý do | Enforcement | Finance — Khóa kỳ | MUST |
| Audit log bất biến (append-only) cho refund/điều chỉnh/mở kỳ; không hard-delete | Audit Trail | Platform — Audit Log | MUST |
| Snapshot tỷ giá từng giao dịch, khóa sau ghi nhận; lãi/lỗ FX tách khoản riêng khỏi GM dịch vụ | Logic | Finance — Đa tiền tệ | MUST |
| Import statement chuẩn (schema validation, ánh xạ nền tảng/TKQC), tự gắn trạng thái đối soát | Import | Finance — Đối soát | MUST |
| Báo cáo AR/AP aging theo bucket + nhắc nợ tự động | Reporting | Finance — Công nợ | SHOULD |
| Alert số dư ví khách dưới ngưỡng cảnh báo | Notification | Finance — Ví | SHOULD |
| Dashboard discrepancy theo nền tảng/TK/khách | Reporting | Finance — Đối soát | SHOULD |

**Cross-policy dependencies:** Phụ thuộc `han-muc-chi-giai-ngan-sod.md` (ngưỡng duyệt refund/điều chỉnh; SoD: người đối soát ≠ người duyệt điều chỉnh; dùng chung snapshot tỷ giá). Cần mapping TKQC ↔ khách ↔ nền tảng từ module quản lý TKQC.

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---|---|---|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách (đối trừ 3 số, tiền giữ hộ, đa tiền tệ) | Đúng / Cần sửa | |
| Mức dung sai (bảng 2.2 — đang là mức đề xuất) | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — CFO / Chủ dự án BCERP
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|---|---|---|---|
| 1.0 | 11/09/2026 | finance-expert | Khởi tạo |
