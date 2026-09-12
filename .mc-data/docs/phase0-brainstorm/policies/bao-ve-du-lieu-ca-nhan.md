# Bảo Vệ Dữ Liệu Cá Nhân (NĐ 13/2023 + GDPR/CCPA + PII Nhân Sự) — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Pháp lý / Nhân sự / Khách hàng / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** legal-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Toàn bộ dữ liệu cá nhân (Personal Data) BC Agency thu thập, xử lý, lưu trữ trên **Client Portal** (dữ liệu khách hàng cuối do khách agency cung cấp cho chạy quảng cáo), **hệ thống nội bộ nhân sự** (hồ sơ, lương, hợp đồng lao động), dữ liệu liên hệ khách hàng doanh nghiệp, và dữ liệu từ các chiến dịch quảng cáo. Bao gồm vai trò BC là **bên kiểm soát (controller)** lẫn **bên xử lý (processor)**.
- **Không áp dụng cho:** Dữ liệu ẩn danh hoàn toàn (không thể định danh); bí mật thương mại không chứa yếu tố định danh cá nhân (thuộc NDA trong `hop-dong-loi-nda-brand-safety.md`).
- **Effective từ:** Ngày được Giám đốc xác nhận tại Section 6.

> **Ghi chú pháp lý:** Nội dung dưới đây là **phân tích khởi điểm — cần luật sư VN xác nhận** về nghĩa vụ theo NĐ 13/2023/NĐ-CP (đặc biệt hồ sơ Impact Assessment và thủ tục thông báo với Bộ Công an) và mức áp dụng GDPR/CCPA đối với khách hàng EU/US.

---

## 2. Nội Dung Chính Sách

### 2.1. Inventory dữ liệu

BC duy trì **danh mục dữ liệu cá nhân (data inventory)** cập nhật tối thiểu mỗi 6 tháng, phân theo 2 nhóm:

| Nhóm | Loại dữ liệu | Nguồn | Hệ thống |
|------|-------------|-------|----------|
| Client Portal | Họ tên, SĐT, email, địa chỉ khách cuối; dữ liệu hành vi/tệp mục tiêu quảng cáo | Khách hàng cung cấp, form landing page, pixel/SDK | Client Portal, nền tảng Ads |
| Nhân sự | Họ tên, CCCD, SĐT, email, lương, hợp đồng lao động, chấm công, đánh giá | Onboarding, HR ops | HR module BCERP |
| Doanh nghiệp | Liên hệ người đại diện khách hàng (tên, chức danh, email, SĐT công việc) | Sales/CRM | CRM |

### 2.2. Cơ sở pháp lý xử lý

Mỗi mục inventory gắn tối thiểu 1 cơ sở pháp lý: **sự đồng ý** (NĐ 13/2023: đồng ý phải cụ thể, có thể rút), **thực hiện hợp đồng**, **nghĩa vụ pháp lý** (thuế, BHXH, hóa đơn điện tử theo TT 78/2021 + NĐ 123/2020), **lợi ích hợp pháp**. Dữ liệu khách cuối trong Client Portal: BC xử lý theo **hướng dẫn của khách (processor)** — trách nhiệm có cơ sở thu thập thuộc về khách.

### 2.3. Phân loại PII & ma trận truy cập

| Mức | Ví dụ | Quy tắc truy cập |
|-----|-------|------------------|
| C1 — Nhạy cảm | CCCD, lương, tài khoản ngân hàng, dữ liệu y tế/sắc thái nếu vô tình xuất hiện | Chỉ HR + Giám đốc; cấm xuất raw; mã hóa khi lưu trữ |
| C2 — Định danh thường | Họ tên, SĐT, email khách cuối | Theo quyền vai trò trong portal; ghi log truy cập |
| C3 — Công việc | Email công ty, chức danh | Toàn bộ nhân viên liên quan |

- **Audit log bất biến** cho mọi thao tác xem/sửa **lương, hợp đồng lao động, dữ liệu nhân sự C1** (ai, khi nào, giá trị trước/sau).
- Ma trận truy cập review định kỳ mỗi quý; offboard nhân sự = thu hồi quyền trong 24 giờ.

### 2.4. Retention theo mục đích

| Dữ liệu | Thời hạn lưu | Sau đó |
|----------|-------------|--------|
| Hồ sơ nhân sự + hợp đồng lao động | Trong quan hệ lao động + tối thiểu theo pháp luật lao động; lương/chứng từ kế toán **10 năm** (Luật Kế toán 2015) | Xóa/ẩn danh |
| Dữ liệu khách cuối (portal) | Theo thời hạn hợp đồng với khách + tối đa 90 ngày sau chấm dứt để bàn giao | Xóa hoặc ẩn danh |
| Dữ liệu marketing/tệp quảng cáo | Theo mục đích chiến dịch, tối đa 24 tháng không tương tác | Xóa/ẩn danh |
| Hồ sơ ứng tuyển không trúng | 12 tháng | Xóa |

### 2.5. Breach notification — 72 giờ

- Phát hiện sự cố rò rỉ/mất dữ liệu cá nhân → **thông báo cho A06 (Bộ Công an) trong vòng 72 giờ** kể từ thời điểm biết, theo mẫu NĐ 13/2023; đồng thời thông báo chủ thể dữ liệu nếu rủi ro cao.
- Quy trình nội bộ: phát hiện → báo CISO/legal trong 4 giờ → khoanh vùng phạm vi → biện pháp khắc phục → nộp thông báo → hồ sơ bài học kinh nghiệm.
- Khách EU/US: thông báo theo nghĩa vụ GDPR (72h với authority) / quy định bang của CCPA **theo DPA** đã ký.

### 2.6. DSR — Tracking quyền chủ thể dữ liệu

- Hỗ trợ các quyền: **truy cập, sao chép, sửa, rút đồng ý, xóa** (NĐ 13/2023: miễn phí trừ trường hợp luật định; GDPR: phản hồi trong 1 tháng).
- Mọi yêu cầu DSR ghi nhận thành **ticket có trạng thái** (nhận → xác minh danh tính → xử lý → phản hồi → đóng) và **log thời hạn** để chứng minh tuân thủ.
- Yêu cầu xóa từ khách (processor role): BC xử lý phần dữ liệu do BC kiểm soát và **chuyển tiếp yêu cầu về khách** đối với dữ liệu khách kiểm soát.

### 2.7. DPA — Phân vai controller/processor với khách EU/US

- Khách hàng tại EU/UK/US (CCPA) ký **Data Processing Agreement (DPA)** trước khi triển khai: xác định BC = **processor/processor phụ**, khách = controller; quy định phạm vi xử lý, biện pháp bảo mật, tiểu xử lý (sub-processor), chuyển dữ liệu quốc tế, nghĩa vụ hỗ trợ DSR và breach notification.
- BC không dùng dữ liệu khách cuối cho mục đích nào ngoài chỉ dẫn của khách (không bán, không tái mục đích).

### 2.8. Data minimization & xóa/ẩn danh khi chấm dứt

- Form portal và tích hợp chỉ thu thập **trường bắt buộc tối thiểu** phục vụ mục đích đã công bố; cấm yêu cầu CCCD/giấy tờ nhạy cảm khi không cần thiết.
- Khi chấm dứt hợp đồng lao động hoặc hợp đồng với khách: dữ liệu cá nhân liên quan bị **xóa hoặc ẩn danh vĩnh viễn** sau khi hết thời hạn retention (mục 2.4), có phê duyệt và log hủy; backup được cập nhật theo chu kỳ xoay của hệ thống.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Nghĩa vụ lưu trữ theo luật (hóa đơn, chứng từ kế toán, hồ sơ BHXH) ưu tiên hơn yêu cầu xóa của chủ thể dữ liệu.
- Sự cố do nền tảng Ads (Meta/Google/TikTok/Yandex) rò rỉ: BC phối hợp khiếu nại và thông báo theo chuỗi DPA nhưng trách nhiệm gốc thuộc nền tảng.
- Yêu cầu DSR không xác minh được danh tính: từ chối xử lý và ghi nhận lý do trong ticket.
- Khách không thuộc EU/US nhưng yêu cầu chuẩn GDPR theo hợp đồng: áp dụng DPA tương tự theo thỏa thuận.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Bổ sung/sửa mục trong data inventory | legal-expert + quản trị hệ thống | 5 ngày làm việc |
| Thêm trường dữ liệu mới vào portal/form | legal-expert kiểm tra minimization + Giám đốc | 3 ngày làm việc |
| Thông báo breach cho A06 và chủ thể dữ liệu | Giám đốc (phát hành) + legal-expert (soạn) | Trong 72 giờ kể từ khi biết |
| Phản hồi yêu cầu DSR (truy cập/xóa) | legal-expert xác minh + bộ phận phụ trách dữ liệu thực thi | 15 ngày làm việc nội bộ (trước hạn pháp lý) |
| Ký DPA với khách EU/US | Giám đốc + legal-expert | 5 ngày làm việc |
| Cấp/thu hồi quyền truy cập dữ liệu C1 | Giám đốc + HR | 24 giờ |
| Tiêu hủy dữ liệu hết hạn retention | Giám đốc + log hủy | Theo chu kỳ review |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

> 🤖 Input trực tiếp cho `/wf-analyze-requirements` và `/wf-design`.

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Data inventory quản trị trong hệ thống, gắn cơ sở pháp lý + retention từng mục | Workflow | Pháp chế/Quản trị | MUST |
| Audit log bất biến (append-only) mọi thay đổi lương/hợp đồng lao động/dữ liệu C1: ai–khi nào–giá trị trước/sau | Audit Trail | HR | MUST |
| Ma trận phân quyền RBAC theo mức PII C1/C2/C3; thu hồi quyền tự động khi offboard | Access Control | Toàn hệ thống | MUST |
| Mã hóa dữ liệu C1 khi lưu trữ và truyền | Security | HR/Portal | MUST |
| Incident intake form breach + timer đếm ngược 72h + mẫu thông báo A06 | Workflow + Notification | Pháp chế | MUST |
| Ticket DSR có SLA tracking (nhận→xác minh→xử lý→đóng) | Workflow | Pháp chế/Portal | MUST |
| Chức năng xóa/ẩn danh chủ thể dữ liệu chạy toàn hệ thống + sinh log hủy có phê duyệt | Workflow | Toàn hệ thống | MUST |
| Chặn form/portal thu trường không nằm trong danh mục minimization được duyệt | Validation | Client Portal | SHOULD |
| Quản lý DPA theo hợp đồng: cờ "khách EU/US" bắt buộc có DPA signed trước khi kích hoạt dịch vụ | Validation | Sales/Hợp đồng | SHOULD |
| Retention timer tự động theo mục đích + báo cáo dữ liệu đến hạn xóa | Reporting | Toàn hệ thống | SHOULD |
| Báo cáo định kỳ: số DSR đã xử lý, breach drill, review truy cập C1 | Reporting | Pháp chế/HR | NICE |

**Cross-policy dependencies:** Phụ thuộc `hop-dong-loi-nda-brand-safety.md` (DPA/NDA gắn hợp đồng, điều khoản dữ liệu mục tiêu trong Brand Safety tiêu chí 6); đồng bộ chính sách an toàn thông tin (Luật ATTT 2015 + NĐ 53/2022/NĐ-CP — biện pháp kỹ thuật bảo vệ hệ thống); liên quan chính sách nhân sự (offboard, quyền truy cập C1) và chính sách vận hành quảng cáo (dữ liệu targeting, tuân thủ Ads Policy nền tảng).

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
