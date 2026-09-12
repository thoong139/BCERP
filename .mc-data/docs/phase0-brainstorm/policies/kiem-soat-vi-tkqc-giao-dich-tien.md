# Kiểm Soát Ví TKQC & Giao Dịch Tiền — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Tài chính / Paid Media / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** paid-media-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `quan-ly-cap-phat-tkqc-financial-hard-stop.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `tiktok-shop-du-lieu-gmv-tham-dinh.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** mọi ví TKQC BC nắm giữ và vận hành trên 7 platform (Meta, Google, TikTok, Bing, X, Pinterest, Yandex); mọi giao dịch tiền liên quan ví: nạp tiền (top-up), hoàn tiền (refund), điều chỉnh số dư, quy đổi tỷ giá, thay đổi ngân sách chiến dịch; mọi media buyer, TL, AM, FIN_L1 và kế toán.
- **Không áp dụng cho:** tiền nằm trong tài khoản ngân hàng của BC (thuộc policy tài chính kế toán tổng thể); ví client-owned TK do khách tự nạp trực tiếp lên platform (BC chỉ đối soát, không thao tác lệnh).
- **Effective từ:** ngày BCERP go-live; số dư tồn tại được nhập liệu và đối chiếu back-dated trước khi kích hoạt cảnh báo.

---

## 2. Nội Dung Chính Sách

### 2.1. Ngưỡng cảnh báo số dư & SLA đỏ

- Mỗi ví/TK đặt ngưỡng cảnh báo riêng theo platform, nguyên tắc chung: **số dư phải đủ chi ≥ 3 ngày tới**, tính từ average daily spend (ADS) 7 ngày gần nhất (rolling, cập nhật hằng ngày).
- Ba mức: **Xanh** (đủ chi ≥ 3 ngày) — không hành động; **Vàng** (đủ chi < 3 ngày) — owner lập kế hoạch nạp, thông báo AM; **Đỏ** (đủ chi < 1 ngày hoặc số dư dưới mức tối thiểu platform) — vào SLA xử lý ngay.
- **SLA đỏ: 2 giờ làm việc** kể từ lúc bắn alert đỏ — owner phải thực hiện 1 trong 2 hành động trên hệ thống: tạo lệnh đề xuất top-up, hoặc giảm ngân sách để kéo dài số ngày chi được.
- **Escalation:** owner (0–2h) → TL (quá 2h không phản hồi) → AM (quá 4h, chủ động liên hệ khách yêu cầu nạp) → thông báo cho khách trong cùng ngày làm việc. Mỗi bước escalate ghi timestamp vào hệ thống.

### 2.2. Die account — xử lý chuẩn

- Khi TK bị platform khóa/hạn chế (die): owner ghi nhận **trạng thái die + evidence tại thời điểm xảy ra** — snapshot màn hình số dư, thông báo của platform, thời gian chính xác — hệ thống lưu evidence store bất biến, không cho sửa sau.
- **Lịch sử die account** theo platform/loại hình nạp được lưu tập trung để đánh giá rủi ro kênh khi quyết định nạp cho khách mới.
- **Phương án TK dự phòng:** mỗi khách phải có ít nhất 1 TK dự phòng đã khởi tạo trên platform chính (chưa bật chi tiêu). Khi cần chuyển, TK dự phòng chỉ hoạt động sau khi qua hard stop khớp tiền của policy quản lý TKQC; mục tiêu chuyển hướng vận hành trong 4h làm việc.

### 2.3. Giao dịch tiền — mọi lệnh qua hệ thống, cấm miệng

- Mọi top-up/refund/điều chỉnh **phải tạo lệnh trên BCERP**. Cấm xác nhận miệng qua Zalo/điện thoại/email riêng — lệnh miệng không có giá trị pháp lý nội bộ và kế toán từ chối đối chiếu.
- **Dual approval bắt buộc** cho 3 nhóm giao dịch rủi ro cao: điều chỉnh số dư thủ công, đổi tỷ giá thủ công, hoàn tiền. Người đề xuất ≠ người duyệt; hệ thống ghi danh tính cả hai.
- **SoD 4 vai** — một người không được giữ ≥ 2 vai trong cùng một giao dịch: **Đề xuất** (buyer/AM) ≠ **Khớp tiền** (FIN_L1) ≠ **Duyệt chi** (TL/FIN manager) ≠ **Ghi sổ** (kế toán).

### 2.4. Hạn mức thay đổi ngân sách chiến dịch (theo bậc)

| Bậc thay đổi | Ai quyết | Điều kiện |
|-------------|----------|-----------|
| Trong hạn mức ngày của buyer | Buyer tự quyết | Không vượt hạn mức VND/ngày gắn theo cấp buyer (Junior/Mid/Senior — hệ số do TL cấu hình) và không tăng tổng budget ngày dự án |
| Vượt hạn mức ngày | TL duyệt | Trên BCERP, có lý do |
| Vượt hạn mức dự án / tăng budget tổng | AM duyệt | Khách duyệt thêm nếu HĐ quy định |
| Mọi thay đổi | — | Ghi **lý do bắt buộc** + tự động vào **campaign change log bất biến** (giá trị cũ, giá trị mới, ai, khi nào, lý do) |

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Khách nạp trực tiếp lên platform** (client-owned): hệ thống chỉ ghi nhận số liệu đối soát, không phát sinh lệnh top-up của BC.
- **Refund từ platform** (ví dụ die account còn số dư): FIN_L1 khớp tiền hoàn về và ghi có theo giao dịch gốc; không hoàn cho khách trước khi có đề xuất AM + duyệt TL.
- **Tỷ giá:** mặc định lấy tỷ giá hệ thống (nguồn ngân hàng quy chuẩn) chốt tại thời điểm tạo lệnh. Chỉ khi biên bản đối chiếu với khách có sai khác mới cho phép chỉnh tay — qua dual approval, kèm biên bản đính kèm.
- **Khẩn cấp 24/7:** TK đỏ ngoài giờ làm việc — TL được escalate qua kênh on-call; lệnh top-up vẫn phải tạo trên hệ thống ngay cả khi xử lý ngoài giờ, approval không được bỏ qua.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Top-up thường (ví xanh/vàng) | FIN_L1 khớp tiền → hard stop mở theo policy TKQC | Trong ngày làm việc |
| Xử lý alert đỏ | Owner hành động, TL giám sát | SLA 2h làm việc |
| Điều chỉnh số dư thủ công | Đề xuất buyer/AM + dual approval TL/FIN | 1 ngày làm việc |
| Đổi tỷ giá thủ công | Dual approval FIN manager + TL | 1 ngày làm việc |
| Hoàn tiền cho khách | AM đề xuất + TL + FIN duyệt | 2 ngày làm việc |
| Tăng ngân sách vượt hạn mức ngày | TL → AM theo bậc | 4h làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Tính ADS 7 ngày rolling + so ngưỡng đủ chi ≥ 3 ngày per TK/platform, bắn alert 3 mức | Notification | Ví TKQC | MUST |
| Bộ đếm SLA 2h cho alert đỏ + auto-escalate owner → TL → AM kèm timestamp | Workflow | Ví TKQC | MUST |
| Mọi top-up/refund/điều chỉnh chỉ thực thi qua lệnh hệ thống; chặn ghi nhận ngoài lệnh | Validation | Ví TKQC / Kế toán | MUST |
| Dual approval cho điều chỉnh số dư, tỷ giá tay, hoàn tiền (đề xuất ≠ duyệt) | Authorization | Ví TKQC | MUST |
| SoD engine chặn 1 người giữ ≥ 2 vai trong 1 giao dịch | Authorization | Ví TKQC / Kế toán | MUST |
| Campaign change log bất biến + bắt buộc nhập lý do khi đổi ngân sách | Audit Trail | Quản lý chiến dịch | MUST |
| Snapshot evidence die account vào evidence store bất biến | Audit Trail | Ví TKQC | MUST |
| Hạn mức ngày theo cấp buyer, cấu hình bởi TL | Configuration | Quản lý chiến dịch | SHOULD |
| Dashboard số dư ví + ngày chi dự kiến theo platform/khách | Reporting | Ví TKQC | SHOULD |

**Cross-policy dependencies:** xác nhận "đã khớp tiền" của FIN_L1 tham chiếu `quan-ly-cap-phat-tkqc-financial-hard-stop.md` (hard stop là gate thực thi); TK dự phòng die account sinh theo vòng đời policy TKQC; `tiktok-shop-du-lieu-gmv-tham-dinh.md` dùng chung cơ chế dual approval và đối soát settlement; hạ tầng audit log bất biến dùng chung 3 policy.

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | paid-media-expert | Khởi tạo |
