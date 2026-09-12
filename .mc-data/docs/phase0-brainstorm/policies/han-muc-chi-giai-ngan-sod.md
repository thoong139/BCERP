# Hạn mức chi, giải ngân, mua hàng & SoD — BCERP

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Tài chính / Mua hàng
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** finance-expert (Kế toán trưởng FIN_L2)
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md` (mô hình agency trung gian TKQC)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `doi-soat-cong-no-doanh-thu-da-tien-te.md` (ngưỡng duyệt refund/điều chỉnh)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Mọi khoản chi của BC Agency — nạp tiền vào nền tảng quảng cáo (AP), mua sắm hạ tầng & SaaS tools, thuê outsource (thiết kế, dev, content, media buy ngoài), tạm ứng/hoàn ứng, mọi giải ngân chuyển khoản/tiền mặt; gồm quy trình duyệt, SoD, ủy quyền và dual approval.
- **Không áp dụng cho:** Tiền khách nạp ví TKQC (dòng tiền giữ hộ — thuộc policy "Đối soát công nợ nền tảng, ghi nhận doanh thu & đa tiền tệ"); lương thưởng theo chu kỳ payroll đã được duyệt quỹ năm (trừ khoản phê duyệt ngoài quỹ lương).
- **Effective từ:** Ngày CFO phê duyệt chính sách (điền khi user xác nhận Section 6).

---

## 2. Nội Dung Chính Sách

### 2.1. Ma trận phê duyệt theo ngưỡng giá trị (mức đề xuất)

Toàn bộ giá trị quy VND theo **tỷ giá snapshot ngày duyệt**. Ngưỡng dưới đây là **đề xuất**, chốt khi user xác nhận Section 6.

| Ngưỡng giá trị | Người đề nghị | Người phê duyệt | Dual approval |
|---|---|---|---|
| ≤ 5 triệu VND | Nhân sự/FIN_L1 | FIN_L2 | Không |
| > 5 – 50 triệu VND | Trưởng bộ phận/FIN_L1 | FIN_L2 | Không |
| > 50 – 200 triệu VND | Trưởng bộ phận | FIN_L2 **+** CFO | Có |
| > 200 triệu VND hoặc hợp đồng dài hạn/năm | Giám đốc bộ phận | CFO **+** CEO | Có |

**Nạp nền tảng định kỳ:** theo kế hoạch tuần duyệt gộp (batch approval) — FIN_L1 thực hiện giao dịch con không duyệt lại; vượt hạn mức tuần phải duyệt bổ sung trước khi giải ngân.

### 2.2. Nguyên tắc SoD (Separation of Duties)

- Ba vai **tách biệt bắt buộc**: người tạo chứng từ ≠ người phê duyệt ≠ người thực hiện chi. Tối thiểu 2 người khác nhau cho khoản trong hạn mức; **3 người** cho khoản cần dual approval.
- Các cặp xung đột cấm khác: người đối soát ≠ người duyệt điều chỉnh công nợ; người quản lý danh mục NCC ≠ người duyệt thanh toán NCC đó.
- **Hệ thống block vi phạm**: từ chối submit/gán duyệt khi vai trùng; **log mọi cố gắng vi phạm** (ai, khi nào, giao dịch nào) để CFO rà định kỳ.

### 2.3. Quy trình mua sắm / outsource / tools theo hạn mức

- Mọi mua sắm/outsource/tools **tạo yêu cầu chi trước khi phát sinh**; không duyệt retroactive trừ ngoại lệ Section 3.
- **Bắt buộc gắn mã dự án/khách** khi tạo yêu cầu chi outsource/tools — phục vụ tính P&L: **P&L = Doanh thu DV − (Σ Giờ × Cost/Level + Outsource + Tools)**. Không gắn được dự án thì phải chọn phân loại overhead kèm lý do.
- Mức hình thức: mua nhỏ (≤ 5 triệu — trực tiếp); mua chuẩn (trên 5 – 200 triệu — ≥ 2 báo giá khi > 20 triệu); mua lớn (> 200 triệu — bảng so sánh + duyệt CFO + CEO).
- Chứng từ (báo giá, hợp đồng, quote SaaS) upload **trước** khi duyệt.

### 2.4. Cơ chế ủy quyền (delegate) khi FIN_L2 vắng

- Chỉ CFO có quyền ủy quyền; người được ủy quyền phải là cá nhân cụ thể (không ủy cho nhóm).
- Phiếu ủy quyền bắt buộc có: **hạn mức** (≤ hạn mức FIN_L2), **thời hạn** (tối đa 14 ngày), phạm vi loại chi.
- Hết hạn **tự động thu hồi**; hoạt động dưới ủy quyền ghi log tách biệt (nhãn "theo ủy quyền #id").

### 2.5. Dual approval

- Giao dịch vượt ngưỡng (bảng 2.1) yêu cầu **2 chữ ký duyệt độc lập**; hệ thống **chặn giải ngân khi thiếu bất kỳ chữ ký nào** — không có "duyệt trước, bổ sung sau".

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Chi khẩn** (nền tảng sắp khóa TKQC cần nạp gấp, sự cố khủng hoảng cần outsource ngay): FIN_L2 + CFO duyệt qua kênh khẩn trong hệ thống; chứng từ đầy đủ phải bổ sung và hậu kiểm trong 24h.
- **Chi định kỳ đã cam kết** (SaaS năm, retainer outsource): duyệt 1 lần đầu năm, tự giải ngân theo lịch; thay đổi giá trị/nhà cung cấp phải duyệt lại.
- **Nạp nền tảng trong hạn mức tuần đã duyệt**: FIN_L1 thực hiện không duyệt lại từng giao dịch con; sắp vượt hạn mức tuần phải cảnh báo và duyệt bổ sung.
- **Khoản < 500.000 VND cho vận hành khẩn** (taxi, in ấn gấp): gói hạn mức tháng theo nhân sự, FIN_L2 rà theo tháng.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|---|---|---|
| Yêu cầu chi ≤ 5 triệu VND | FIN_L2 | 24h làm việc |
| Yêu cầu chi > 5 – 50 triệu VND | FIN_L2 | 24h làm việc |
| Yêu cầu chi > 50 – 200 triệu VND | FIN_L2 + CFO | 48h làm việc |
| Yêu cầu chi > 200 triệu VND / hợp đồng năm | CFO + CEO | 72h làm việc |
| Chi khẩn | FIN_L2 + CFO | 4h (hậu kiểm trong 24h) |
| Duyệt kế hoạch nạp nền tảng tuần | FIN_L2 | Trước đầu tuần |
| Duyệt bổ sung vượt hạn mức tuần | FIN_L2 (≤ 50 triệu) / CFO (> 50 triệu) | 8h làm việc |
| Cấp/thu hồi ủy quyền FIN_L2 | CFO | 24h trước khi vắng |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---|---|---|---|
| Ma trận hạn mức cấu hình theo vai + ngưỡng + loại chi, áp động vào luồng duyệt | Config/Logic | Finance — Duyệt chi | MUST |
| Block submit/giải ngân khi thiếu duyệt, sai ngưỡng, hoặc người duyệt trùng người tạo | Enforcement | Finance — SoD | MUST |
| Log mọi vi phạm SoD bị chặn (ai, khi nào, giao dịch nào) — append-only | Audit Trail | Platform — Audit Log | MUST |
| Dual approval bắt buộc cho giao dịch vượt ngưỡng; chặn giải ngân khi thiếu 1 chữ ký | Enforcement | Finance — Duyệt chi | MUST |
| Bắt buộc gắn mã dự án/khách khi tạo chi outsource/tools; không gắn được phải chọn overhead + lý do | Validation | Finance — Chi phí / Dự án | MUST |
| Cơ chế ủy quyền có hạn mức + thời hạn + phạm vi, tự thu hồi khi hết hạn, log gắn nhãn ủy quyền | Logic | Finance — Phân quyền | MUST |
| Hạn mức tuần cho nạp nền tảng: cảnh báo sắp vượt, chặn vượt khi chưa duyệt bổ sung | Enforcement/Notification | Finance — Giải ngân | MUST |
| Quy định ≥ 2 báo giá khi > 20 triệu; chặn duyệt khi thiếu chứng từ đính kèm | Validation | Procurement | SHOULD |
| Chi khẩn có luồng riêng với deadline hậu kiểm 24h và cảnh báo tồn hậu kiểm | Workflow | Finance — Duyệt chi | SHOULD |
| Dashboard trạng thái yêu cầu chi, tồn đọng duyệt quá SLA, chi theo dự án/overhead | Reporting | Finance — Duyệt chi | SHOULD |
| Nhắc duyệt tự động theo SLA từng ngưỡng (24h/48h/72h) | Notification | Finance — Duyệt chi | SHOULD |
| Quy VND theo tỷ giá snapshot ngày duyệt cho giao dịch ngoại tệ | Logic | Finance — Đa tiền tệ | SHOULD |

**Cross-policy dependencies:** Phụ thuộc chéo `doi-soat-cong-no-doanh-thu-da-tien-te.md` (ngưỡng duyệt refund/điều chỉnh dùng ma trận hạn mức này; SoD đối soát ≠ duyệt điều chỉnh; dùng chung snapshot tỷ giá). Module phân quyền vai FIN_L1/FIN_L2/CFO/CEO là điều kiện tiên quyết — cấu hình vai trước khi bật enforcement.

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---|---|---|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Ma trận ngưỡng giá trị (bảng 2.1 — đang là mức đề xuất) | Đúng / Cần sửa | |
| Nguyên tắc SoD | Đúng / Cần sửa | |
| Quy trình mua sắm/outsource/tools | Đúng / Cần sửa | |
| Cơ chế ủy quyền & dual approval | Đúng / Cần sửa | |
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
