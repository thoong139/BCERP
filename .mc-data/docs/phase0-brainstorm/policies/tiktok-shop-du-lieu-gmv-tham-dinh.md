# TikTok Shop: Truy Cập Dữ Liệu Khách, Tách Bạch GMV & Thẩm Định Shop — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** E-commerce / Dữ liệu khách hàng / Paid Media
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** paid-media-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`, `quan-ly-cap-phat-tkqc-financial-hard-stop.md`, `kiem-soat-vi-tkqc-giao-dich-tien.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), `phase4-` data model (PII masking, tenant isolation)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** mọi hoạt động kết nối, truy cập và xử lý dữ liệu TikTok Shop của khách (đơn hàng, GMV, settlement, sản phẩm, khách mua); mọi dịch vụ vận hành shop BC thực hiện cho khách; mọi vai trò tiếp xúc dữ liệu: buyer, AM, service/operations, FIN_L1, kỹ thuật.
- **Không áp dụng cho:** dữ liệu TikTok Shop của chính BC (shop nội bộ); dữ liệu quảng cáo TikTok Ads thường (thuộc policy quản lý TKQC); platform TMĐT khác (Shopee/Lazada — áp dụng nguyên tắc tương đương khi có policy riêng).
- **Effective từ:** ngày go-live module TikTok Shop; kết nối hiện có phải chuyển sang OAuth ủy quyền đúng chuẩn trong 30 ngày.

---

## 2. Nội Dung Chính Sách

### 2.1. Truy cập dữ liệu khách — OAuth per-client + log đầy đủ

- Dữ liệu TikTok Shop của khách **chỉ được kết nối qua OAuth ủy quyền riêng từng khách (per-client)** — cấm dùng tài khoản đăng nhập chủ shop chia sẻ, cấm gom nhiều shop vào 1 ủy quyền chung. Mỗi ủy quyền ghi rõ phạm vi scope được khách cấp.
- **Log mọi truy cập**: ai, khi nào, API/đối tượng dữ liệu nào, scope nào — log bất biến, phục vụ thanh tra và phản hồi khách khi có yêu cầu.
- **Thu hồi ủy quyền trong 24h** khi hết hợp đồng hoặc khách yêu cầu; AM xác nhận đã revoke cho khách bằng văn bản.
- **Không lưu PII thô người mua cuối**: SĐT, địa chỉ chi tiết, họ tên đầy đủ được **mask mặc định** trong BCERP (ví dụ SĐT `090****123`, địa chỉ chỉ còn tỉnh/huyện). Trường hợp nghiệp vụ bắt buộc dùng đầy đủ (ví dụ đối soát giao hàng) → xử lý trong phiên có TTL, không persist vào database.
- **Isolation dữ liệu giữa các khách**: dữ liệu shop A không bao giờ xuất hiện trong báo cáo, API hay export của shop B; tách theo tenant + client code; kiểm tra truy cập chéo định kỳ hàng quý.

### 2.2. Tách bạch GMV — GMV KHÔNG phải doanh thu agency

- GMV, settlement, đơn hàng TikTok Shop là **chỉ số tham chiếu thuộc về khách** — chỉ dùng trong báo cáo hiệu quả vận hành/quảng cáo của khách đó.
- **Tuyệt đối không ghi nhận GMV/settlement thành doanh thu agency.** Doanh thu BC = phí dịch vụ (service fee) + phí ads thu hộ (nếu có) + phí vận hành shop nếu HĐ quy định.
- Hệ thống chặn mọi mapping GMV/settlement vào tài khoản doanh thu trên sổ kế toán; bút toán doanh thu chỉ sinh từ hợp đồng dịch vụ/fee.

### 2.3. Thẩm định chủ shop & giấy phép ngành hàng trước khi vận hành

Checklist bắt buộc trước khi nhận vận hành:

- **Chủ shop:** giấy ĐKKD/hộ kinh doanh, người đại diện pháp luật, chứng từ sở hữu shop (TikTok Shop seller account đăng ký dưới danh nghĩa ai), khớp giữa người ký HĐ và chủ shop.
- **Giấy phép ngành hàng:** kiểm tra theo chính sách ngành hàng TikTok Shop hiện hành (ví dụ thực phẩm chức năng, mỹ phẩm, thực phẩm tươi sống, health care... phải có giấy phép con hợp lệ). Hệ thống lưu ngày hết hạn và cảnh báo trước khi hết hạn.

### 2.4. TikTok Shop Lifecycle — 3 Gate

| Gate | Tên | Nội dung | Người chịu trách nhiệm |
|------|-----|----------|----------------------|
| Gate 1 | Verification | Hoàn tất checklist thẩm định (2.3), giấy phép đầy đủ, BC lưu hồ sơ | AM + FIN_L1 đối chiếu pháp lý |
| Gate 2 | Go-live | Service Manager (SM) **ký duyệt** vận hành; **baseline KPI được chốt lúc bàn giao** (GMV hiện tại, ADS, tỷ lệ chuyển đổi, tình trạng shop) | SM |
| Gate 3 | Đối soát định kỳ | Đối soát **settlement vs đơn vs ads** theo tần suất HĐ (mặc định hàng tháng); chênh lệch vượt ngưỡng → điều tra, xử lý theo policy ví TKQC | FIN_L1 + AM |

### 2.5. Logistics & cam kết KPI

- **Không nhận logistics/fulfillment** cho khách trừ khi HĐ quy định rõ phạm vi, trách nhiệm và phí; trường hợp có, vận hành theo SLA riêng đính kèm HĐ.
- **Không cam kết KPI cứng** (GMV, ROAS, đơn...) ngoài hợp đồng. Baseline KPI chốt tại Gate 2 là mốc đo lường; mọi con số cam kết chỉ có giá trị khi nằm trong HĐ/phụ lục do AM + SM duyệt.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Khách tự vận hành shop, BC chỉ chạy ads:** chỉ áp dụng Gate 1 rút gọn — xác nhận ownership + scope đọc dữ liệu; không cần Gate 2 full.
- **Khách từ chối cấp OAuth:** BC không truy cập dữ liệu; báo cáo chỉ dựa trên số liệu khách tự cung cấp và ghi chú rõ nguồn "theo số liệu khách cung cấp" — không chịu trách nhiệm đối soát.
- **Hợp đồng chia doanh thu theo GMV** (nếu có): doanh thu ghi nhận là **phần share theo HĐ**, không phải toàn bộ GMV; hạch toán sau khi settlement đối soát khớp.
- **Ủy quyền OAuth hết hạn giữa chừng:** hệ thống cảnh báo và dừng kéo dữ liệu mới; không tự ý xin lại scope mở rộng mà không có đồng ý mới của khách.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Kết nối OAuth mới / mở rộng scope | AM đề xuất + SM duyệt | 2 ngày làm việc |
| Go-live vận hành shop | SM ký duyệt (Gate 2) | Sau khi Gate 1 hoàn tất |
| Đối soát có chênh lệch vượt ngưỡng | FIN_L1 + AM | 3 ngày làm việc |
| Thu hồi ủy quyền hết HĐ | Tự động theo sự kiện HĐ + AM xác nhận | 24h |
| Nhận thêm logistics vào phạm vi | SM + Giám đốc (phụ lục HĐ) | Theo luồng ký HĐ |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Kết nối TikTok Shop qua OAuth per-client, lưu scope từng ủy quyền | Integration | TikTok Shop Integration | MUST |
| Access log bất biến mọi lần gọi API dữ liệu shop | Audit Trail | TikTok Shop Integration | MUST |
| Mask PII người mua mặc định (SĐT/địa chỉ/tên); dữ liệu đầy đủ chỉ trong phiên TTL, không persist | Data Protection | CRM / Đơn hàng | MUST |
| Tenant isolation dữ liệu giữa shop các khách + bài test truy cập chéo định kỳ | Security | Nền tảng dữ liệu | MUST |
| Chặn mapping GMV/settlement vào tài khoản doanh thu trên sổ kế toán | Validation | Kế toán | MUST |
| Checklist thẩm định chủ shop + trạng thái giấy phép ngành hàng + cảnh báo hết hạn | Workflow | Onboarding khách | MUST |
| Workflow 3 Gate (Verification → Go-live có chữ ký SM → Đối soát định kỳ) | Workflow | Dự án / Vận hành | MUST |
| Tự thu hồi OAuth trong 24h khi sự kiện hết HĐ | Automation | Integration / Hợp đồng | MUST |
| Báo cáo đối soát settlement vs đơn vs ads + flag chênh lệch | Reporting / Reconciliation | Kế toán / TikTok Shop | SHOULD |
| Snapshot baseline KPI lúc bàn giao (Gate 2) | Reporting | Dự án | SHOULD |

**Cross-policy dependencies:** dùng hard stop "đã khớp tiền" và chuẩn naming/gắn project của `quan-ly-cap-phat-tkqc-financial-hard-stop.md`; dùng dual approval, SoD và luồng đối soát của `kiem-soat-vi-tkqc-giao-dich-tien.md`; hạ tầng audit log bất biến dùng chung 3 policy.

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
