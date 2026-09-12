# Bảng giá, ma trận chiết khấu & duyệt Gross Margin — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Bán hàng / Tài chính
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** sales-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), policies: `phan-loai-khach-hang-tier.md`, `hoa-hong-sales-quota.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** mọi Quotation phát hành cho khách hàng mới và hiện hữu, covering toàn bộ nhóm dịch vụ (trung gian TKQC đa nền tảng / Agency account, vận hành FB Ads – Google – TikTok, SEO, Web/thiết kế); mọi vai trò NVKD, TPKD, GDKD, SM, Accountant liên quan lập và duyệt báo giá.
- **Không áp dụng cho:** chi phí mua media từ nhà mạng (theo chính sách Mua hàng), báo giá nội bộ/demo, dịch vụ tặng kèm không phát sinh doanh thu.
- **Effective từ:** *(chờ user xác nhận)*

---

## 2. Nội Dung Chính Sách

### 2.1. Định mức tính giá chuẩn

- Mọi Quotation do **Accountant lập theo Định mức tính giá chuẩn**, gồm: giá mua media/TKQC sau chiết khấu agency từ nền tảng, định mức giờ nhân sự theo cấp L1–L5, phí nền tảng/công cụ, % dự phòng rủi ro.
- Định mức cập nhật theo quý theo version; mọi Quotation phải trace được về đúng version định mức đang hiệu lực tại thời điểm phát hành.
- Công thức: **GM = (Doanh thu bán − Giá vốn theo định mức) / Doanh thu bán × 100%**. Chi phí media pass-through tính giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ.

### 2.2. GM tối thiểu theo nhóm dịch vụ (mức khởi tạo — user xác nhận)

| Nhóm dịch vụ | GM tối thiểu | Ghi chú |
|--------------|-------------|---------|
| Agency account (trung gian TKQC đa nền tảng) | ≥ 15% | Rủi ro quy đổi/số dư ví — gắn với nguyên tắc "Khớp tiền" |
| FB Ads / Ads ops (Meta, Google, TikTok, Bing…) | ≥ 20% | Tính trên phí dịch vụ, không tính phần pass-through |
| SEO | ≥ 35% | Chi phí chủ yếu là giờ nhân sự |
| Web / Thiết kế đồ họa | ≥ 30% | Tính theo định mức giờ theo cấp bậc |

### 2.3. Ma trận phân quyền chiết khấu

| Vai trò | Hạn mức chiết khấu trên bảng giá | Điều kiện |
|---------|--------------------------------|-----------|
| NVKD | ≤ 5% | GM vẫn phải ≥ ngưỡng nhóm dịch vụ |
| TPKD | > 5% đến 15% | GM ≥ ngưỡng; ghi lý do chiết khấu |
| GDKD | > 15% đến 20% | Duyệt GM kèm nhận định chiến lược |
| BOD | > 20% | Trình minh bạch GM; quyết định bằng văn bản |

Cấm "chiết khấu ẩn": tặng thêm giờ/đầu việc/tài nguyên không ghi giá mà không có duyệt theo ma trận trên.

### 2.4. Hiệu lực báo giá

- Mặc định **30 ngày** kể từ ngày phát hành; hợp đồng năm/dự án đa giai đoạn tối đa **60 ngày**.
- Quá hiệu lực: hệ thống tự chuyển "Hết hạn"; tiếp tục bán phải phát hành version mới theo giá và định mức hiện hành.

### 2.5. Version control — bản gửi khách hàng bị khóa

- Mỗi Quotation có số version tăng dần; chỉ version đang hoạt động được gửi.
- Khi bấm "Gửi khách hàng": bản đó **bị khóa vĩnh viễn (read-only)**, log người gửi, thời điểm, nội dung; mọi chỉnh sửa phải tạo version mới và duyệt lại GM.
- Giới hạn vòng sửa theo tier khách hàng (liên kết Policy Tier): **Tier D/E ≤ 2 vòng; Tier B/C ≤ 4 vòng**; vượt sẽ chặn và yêu cầu GDKD mởexception có lý do.

### 2.6. Duyệt GM trước khi gửi

- Trình tự bắt buộc: Accountant lập Quotation theo định mức → hệ thống tính GM → duyệt chiết khấu theo ma trận (nếu vượt hạn mức NVKD) → duyệt GM → mới được gửi khách hàng.
- **SLA gửi:** sau khi GM được duyệt, tối đa **2 ngày làm việc** phải gửi KH; quá hạn cảnh báo SM + GDKD.
- Deal có GM dưới ngưỡng nhóm dịch vụ: bắt buộc GDKD duyệt (đến 20%) hoặc BOD (>20%) trước khi gửi.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Deal pilot/test 1 tháng: được chấp nhận GM thấp hơn ngưỡng tối đa một kỳ và không quá 60 ngày, GDKD duyệt kèm mục tiêu chuyển đổi thành hợp đồng chính.
- Tái ký khách hiện hữu trong 12 tháng: giữ bảng giá cũ tối đa một lần tái ký; lần sau áp định mức mới.
- Khách BOD-sponsored: giá có thể ký ngoài ma trận với quyết định bằng văn bản của BOD.
- Biến động tỷ giá/phí nền tảng > 5% trong thời gian hiệu lực: Accountant phát hành version điều chỉnh, không tính vào giới hạn vòng sửa.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Chiết khấu ≤ 5% (GM đạt ngưỡng) | NVKD (hệ thống duyệt theo ma trận) | Tức thời |
| Chiết khấu > 5% đến 15% | TPKD | SLA 8 giờ làm việc |
| Chiết khấu > 15% đến 20%, hoặc GM dưới ngưỡng nhóm dịch vụ | GDKD | SLA 1 ngày làm việc |
| Chiết khấu > 20% | BOD | SLA 2 ngày làm việc |
| Gia hạn quotation hết hiệu lực | Accountant + TPKD | SLA 1 ngày làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Chặn gửi KH khi quotation hết hiệu lực, chưa duyệt GM, hoặc chưa duyệt chiết khấu theo ma trận | Validation | Quotation & Deal Desk | MUST |
| Tự động tính GM theo version định mức hiện hành; cảnh báo đỏ khi GM < ngưỡng nhóm dịch vụ | Validation | Quotation & Deal Desk | MUST |
| Khóa vĩnh viễn bản đã gửi KH (read-only), cấm sửa/xóa, chỉnh sửa chỉ qua version mới | Validation | Quotation & Deal Desk | MUST |
| Đếm vòng sửa theo tier (D/E ≤ 2, B/C ≤ 4) và chặn vượt không có duyệt exception | Validation | Quotation & Deal Desk | MUST |
| Tự chuyển trạng thái "Hết hạn" sau 30/60 ngày | Validation | Quotation & Deal Desk | MUST |
| Audit log toàn bộ version, người duyệt, lý do chiết khấu, thời điểm gửi KH | Audit Trail | Quotation & Deal Desk | MUST |
| Nhắc TPKD/GDKD/BOD khi yêu cầu duyệt tới hạn SLA; quá SLA escalate | Notification | SLA & Notification Engine | MUST |
| Cảnh báo SM + GDKD khi quotation đã duyệt GM nhưng quá 2 ngày chưa gửi KH | Notification | SLA & Notification Engine | MUST |
| Báo cáo tháng: GM theo nhóm dịch vụ/deal/NVKD, GM thực tế vs tối thiểu | Reporting | Dashboard GDKD/BOD | SHOULD |
| Báo cáo tuần: danh sách quotation hết hạn/chờ duyệt quá SLA | Reporting | Dashboard GDKD | NICE |

**Cross-policy dependencies:** `phan-loai-khach-hang-tier.md` (giới hạn vòng sửa ≤2/≤4 theo tier, tier quyết định template proposal); `hoa-hong-sales-quota.md` (doanh thu tính hoa hồng chỉ dựa trên quotation đã duyệt GM); P1 Phân quyền & phân loại dữ liệu (giá vốn, GM là dữ liệu mức "Mật/Restricted").

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
| 1.0 | 11/09/2026 | sales-expert | Khởi tạo |
