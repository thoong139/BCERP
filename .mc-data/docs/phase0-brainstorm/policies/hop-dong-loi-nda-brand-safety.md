# Hợp Đồng, LOI, NDA & Brand Safety — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Pháp lý / Khách hàng / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** legal-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Mọi giao dịch dịch vụ của BC Agency với khách hàng — gồm LOI, hợp đồng dịch vụ marketing/quản lý tài khoản quảng cáo, phụ lục (Brand Safety, phạm vi dịch vụ, bảng giá), NDA hai chiều trước khi nhận Full Brief, mọi phụ lục kỹ thuật gắn hợp đồng; áp dụng với cả khách mới và gia hạn/tái ký.
- **Không áp dụng cho:** Hợp đồng lao động và NDA nội bộ nhân sự (thuộc chính sách nhân sự); hợp đồng mua hàng với nhà cung cấp (thuộc chính sách mua hàng); mẫu giấy phép quảng cáo chuyên biệt do khách tự nộp.
- **Effective từ:** Ngày được Giám đốc xác nhận tại Section 6.

> **Ghi chú pháp lý:** Toàn bộ điều khoản dưới đây là **phân tích khởi điểm — cần luật sư VN xác nhận** trước khi đưa vào mẫu hợp đồng phát hành chính thức, đặc biệt các điều khoản giới hạn trách nhiệm và miễn trừ liên quan thuật toán nền tảng.

---

## 2. Nội Dung Chính Sách

### 2.1. Mẫu chuẩn HĐ/LOI — IN/OUT of scope rõ ràng

- Mọi HĐ/LOI sử dụng **mẫu chuẩn** do legal-expert duyệt; không dùng mẫu của đối tác khi chưa qua legal review.
- Mỗi HĐ/LOI bắt buộc có mục **IN of scope** (dịch vụ, nền tảng, ngân sách, số tài khoản, deliverables) và **OUT of scope** (mọi việc ngoài IN đều cần phụ lục mới + tính phí). Cấm mô tả phạm vi bằng ngôn ngữ mơ hồ ("hỗ trợ khi cần", "và các công việc liên quan").

### 2.2. Cơ chế tài chính — Nạp trước 100% NSQC (Knockout K4)

- NSQC (ad spend) phải được khách **nạp trước 100%** vào tài khoản quảng cáo trước khi BC vận hành; BC **không ứng tiền NSQC** và không cam kết tài trợ dòng tiền quảng cáo dưới mọi hình thức.
- Chưa xác nhận nhận nạp đủ → trạng thái hợp đồng = "chờ kích hoạt", không tạo chiến dịch.
- Phí dịch vụ (service fee) thanh toán theo kỳ đã thỏa thuận; nợ phí quá hạn → quyền tạm dừng dịch vụ theo HĐ.

### 2.3. NDA mutual bắt buộc trước Full Brief

- Trước khi khách gửi **Full Brief 8 sections** (thông tin NSQC, targeting, sản phẩm, dữ liệu khách hàng...), hai bên ký **NDA hai chiều (mutual)**. Nhận brief mà chưa có NDA là vi phạm chính sách — sales không được phép trigger bước nhận brief.
- NDA quy định: định nghĩa thông tin mật, mục đích sử dụng, thời hạn bảo mật (tối thiểu 3 năm sau chấm dứt), nghĩa vụ trả lại/xóa dữ liệu khi chấm dứt.

### 2.4. Brand Safety Clause — 7 tiêu chí hard stop

- Khách **cam kết bằng văn bản** trong HĐ rằng sản phẩm/dịch vụ quảng cáo **hợp pháp** và có đầy đủ **giấy phép con** theo Luật Quảng cáo 2012 đối với sản phẩm hạn chế (thực phẩm chức năng, mỹ phẩm, dược, tài chính, giáo dục...).
- **7 tiêu chí Brand Safety** được ban hành dưới dạng **Phụ lục gắn chặt vào HĐ** (ràng buộc pháp lý như phần thân HĐ): (1) tính hợp pháp của SP + giấy phép; (2) nội dung không vi phạm Ads Policy nền tảng (Meta/Google/TikTok/Yandex); (3) không spam/leading/misleading; (4) quyền sử dụng image/video/bản quyền hợp lệ; (5) landing page hợp pháp, nội dung khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập hợp lệ; (7) không thuộc ngành cấm/nhạy cảm chưa được duyệt nội bộ.
- BC có **quyền từ chối vận hành** ngay khi phát hiện vi phạm bất kỳ 1/7 tiêu chí — không cần bồi thường, không hoàn phí dịch vụ phần đã thực hiện; vi phạm K1 (SP hạn chế không giấy phép) là **knockout — chấm dứt hợp đồng**.

### 2.5. Giới hạn trách nhiệm & miễn trừ (Knockout K2)

- **Không cam kết KPI cứng** (số lead, CPA, ROAS, doanh số) — HĐ chỉ cam kết đầu vào: ngân sách, khối lượng công việc, SLA vận hành.
- **Cap tổng trách nhiệm** của BC = tổng phí dịch vụ **đã thực nhận** trong 12 tháng liền trước phát sinh khiếu nại; không chịu trách nhiệm cho lợi nhuận mất mát, dữ liệu gián tiếp.
- **Miễn trừ trách nhiệm** khi nền tảng (Meta/Google/TikTok/Yandex) **khóa tài khoản, from-time-out, giảm phân phối hoặc thay đổi thuật toán** — đây là rủi ro thuộc hệ sinh thái nền tảng, không thuộc kiểm soát của BC; BC có nghĩa vụ hỗ trợ khiếu nại và xử lý khôi phục trong phạm vi khả năng.

### 2.6. Workflow duyệt hợp đồng & version control

Luồng chuẩn: **Template → Draft → Legal review → Duyệt theo ma trận giá trị → E-sign → Archive**.

- Version control bắt buộc: `Draft (v0.x nội bộ) → Counterparty review (v1.x) → Final (v2.0, hai bên chốt nội dung) → Signed (khoá cứng, không sửa được)`. Mọi chỉnh sửa sau Final phải tạo version mới và chạy lại phê duyệt.
- **E-sign** theo Luật Giao dịch điện tử 2023: chữ ký số CA cấp bởi tổ chức cung cấp dịch vụ chứng thực chữ ký số được chấp nhận; ký điện tử trên nền tảng e-sign có lưu vết (audit trail thời gian, IP).
- HĐ ký xong được **archive tập trung**, hệ thống **alert trước 30/60/90 ngày** khi đến hạn chấm dứt, gia hạn hoặc điều khoản cần rà soát.

### 2.7. Retention & Disposal

- Hợp đồng, hóa đơn, chứng từ kế toán liên quan lưu trữ **tối thiểu 10 năm** theo Luật Kế toán 2015.
- Hết thời hạn lưu: tiêu hủy/xóa chỉ khi có **phê duyệt** của người có thẩm quyền và **log hủy** (thời gian, người duyệt, danh mục hủy). Không xóa tài liệu thuộc vụ kiện/tranh chấp đang treo.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Khách hàng chiến lược/tập đoàn đa quốc gia yêu cầu dùng mẫu của họ: phải qua **legal review bắt buộc** và Giám đốc phê duyệt; các điều khoản cap trách nhiệm, không cam kết KPI, miễn trừ nền tảng là **red-line** — không chấp nhận xóa.
- LOI/MOU giai đoạn đàm phán: có thể ký trước HĐ chính nhưng vẫn cấm nhận Full Brief khi chưa có NDA.
- Gia hạn tự động (auto-renewal): chỉ áp dụng khi HĐ gốc có điều khoản này và khách không từ chối trước hạn — hệ thống vẫn gửi alert nhắc.
- Trường hợp nền tảng khóa TK do lỗi phía nền tảng (không do nội dung khách): BC hỗ trợ khiếu nại, không tính phí dịch vụ trong thời gian dừng do nền tảng (theo điều khoản SLA trong HĐ).

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Dùng đúng template, giá trong khung chuẩn | Trưởng bộ phận Sales + legal-expert review nhanh | 1–2 ngày làm việc |
| Sửa điều khoản trong khung đã duyệt (không đụng red-line) | legal-expert | 2 ngày làm việc |
| HĐ/NSQC năm vượt ngưỡng ma trận giá trị do Ban Giám đốc ban hành | Giám đốc | 3 ngày làm việc |
| Dùng mẫu của đối tác / xóa-sửa điều khoản red-line | Giám đốc + luật sư tư vấn | 5–7 ngày làm việc |
| Từ chối vận hành theo Brand Safety (vi phạm 1/7 tiêu chí) | legal-expert xác nhận + Trưởng bộ phận Vận hành | 24 giờ |
| Tiêu hủy tài liệu hết hạn lưu trữ | Giám đốc (kèm log hủy) | Theo đợt review định kỳ |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

> 🤖 Input trực tiếp cho `/wf-analyze-requirements` và `/wf-design`.

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Block kích hoạt chiến dịch nếu chưa có xác nhận nạp đủ 100% NSQC (K4) | Validation | Sales/Hợp đồng + Tài chính | MUST |
| Block nhận Full Brief 8 sections nếu chưa có NDA signed gắn khách hàng | Validation | Sales/CRM | MUST |
| Checklist Brand Safety 7 tiêu chí gắn từng hợp đồng + trạng thái pass/fail từng tiêu chí | Workflow | Vận hành/Hợp đồng | MUST |
| Nút "Từ chối vận hành" ghi nhận tiêu chí vi phạm, khóa trạng thái hợp đồng, notify legal + vận hành | Workflow | Hợp đồng | MUST |
| Version control hợp đồng: Draft → Counterparty → Final → Signed (lock cứng, cấm sửa sau Signed) | Audit Trail | Document/Hợp đồng | MUST |
| E-sign tích hợp + lưu audit trail (thời gian, IP, người ký) | Integration | Hợp đồng/E-sign | MUST |
| Archive tập trung + alert 30/60/90 ngày trước hạn hết HĐ | Notification | Hợp đồng | MUST |
| Cảnh báo khi mẫu/draft chứa điều khoản red-line bị xóa/sửa (diff check với template) | Validation | Hợp đồng | SHOULD |
| Ma trận giá trị hợp đồng cấu hình được (ngưỡng → người duyệt) | Workflow | Hợp đồng | SHOULD |
| Retention timer 10 năm + quy trình tiêu hủy có phê duyệt và log hủy bất biến | Audit Trail | Document | SHOULD |
| Báo cáo danh mục HĐ sắp hết hạn, HĐ chờ nạp NSQC, HĐ bị từ chối vận hành | Reporting | Hợp đồng | NICE |

**Cross-policy dependencies:** Phụ thuộc `bao-ve-du-lieu-ca-nhan.md` (dữ liệu brief/NDA là dữ liệu cá nhân và bí mật kinh doanh cần phân loại); đồng bộ Knockout K1/K2/K4 trong lifecycle V6.0 (Phase 0 brainstorm) và Brand Safety 7 tiêu chí hard stop; liên quan policy tài chính (thu phí dịch vụ, đối soát nạp NSQC) và policy vận hành quảng cáo (tuân thủ Ads Policy Meta/Google/TikTok/Yandex).

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — Giám đốc BC Agency
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | legal-expert | Khởi tạo — phân tích khởi điểm, chờ luật sư VN xác nhận |
