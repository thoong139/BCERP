# Nhân Sự Hành Chính, Hồ Sơ Level L1–L5 & Cost Rate Card — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Nhân sự
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** hr-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** toàn bộ nhân sự thử việc và chính thức của BC Agency (quy mô 31–50 người) thuộc mọi nhóm vai (SALES_*, OPS_*, FIN_*, HR_*, PM/Lead); và mọi module hệ thống đọc dữ liệu nhân sự (RBAC, hoa hồng, P&L, KPI).
- **Không áp dụng cho:** freelancer/cộng tác viên ngoài biên chế (quản lý như chi phí dịch vụ); nhân sự thuê lại từ bên thứ ba (hồ sơ lưu tham chiếu, không phải nguồn sự thật).
- **Effective từ:** 01/10/2026 (đề xuất — chờ xác nhận ở Section 6).

---

## 2. Nội Dung Chính Sách

### 2.1. Hồ sơ nhân sự — nguồn sự thật duy nhất (Single Source of Truth)

Mỗi nhân sự có đúng một hồ sơ điện tử, gồm tối thiểu:

- Họ tên, mã nhân viên, phòng ban, Team Leader trực tiếp.
- **Mã vai** (OPS_L1…L5, SALES_L1…L5, FIN_*, HR_*, PM_*) và **Level hiện hành + ngày hiệu lực**.
- **HĐLĐ**: loại, số, ngày ký, hiệu lực, hết hạn, nội dung chính.
- **Trạng thái**: Thử việc / Chính thức / Nghỉ phép dài / Nghỉ không lương / Nghỉ việc.
- Thông tin BHXH, người phụ thuộc, số tài khoản lương.

Nguyên tắc: **RBAC, hoa hồng, P&L, KPI đọc chung từ hồ sơ này** — không module nào giữ bản sao riêng. Mọi thay đổi Level/vai/trạng thái được **version hóa theo hiệu lực từ ngày–đến ngày (SCD2)**, không ghi đè mất lịch sử.

### 2.2. Hợp đồng lao động & cảnh báo hạn

- Hệ thống nhắc tự động trước hạn hết hạn HĐLĐ: **90 / 60 / 30 ngày** cho HR_L2 và Team Leader.
- HĐ xác định thời hạn hết hạn mà chưa ký tiếp → chuyển cảnh báo đỏ (rủi ro pháp lý).

### 2.3. Chấm công, nghỉ phép, OT, thử việc, BHXH

- **Chấm công:** giờ chuẩn 40h/tuần (T2–T6); giờ linh hoạt được phép nhưng phải đạt định mức giờ/tuần theo Level (policy `timesheet-capacity.md`).
- **Nghỉ phép năm:** **12 ngày phép/năm theo BLLĐ 2019** (Điều 113), tích lũy 1 ngày/tháng làm việc. Nghỉ có kế hoạch: đề nghị trước ≥ 3 ngày làm việc; nghỉ ốm ≥ 3 ngày kèm giấy khám bệnh; trường hợp khác theo BLLĐ.
- **Overtime:** tổng giờ làm bình thường + làm thêm **không vượt 48h/tuần** (Điều 107 BLLĐ 2019); OT phải được duyệt trước (khẩn cấp retro 24h) và hưởng hệ số lương làm thêm theo pháp luật.
- **Thử việc:** thời hạn theo Điều 25 BLLĐ 2019; đánh giá trước khi kết thúc ít nhất 3 ngày; đạt → ký HĐLĐ chính thức; không đạt → chấm dứt đúng pháp luật.
- **BHXH:** tham gia BHXH bắt buộc (XH, YT, TN, thất nghiệp) kể từ thời điểm pháp luật quy định; hồ sơ tham gia quản lý trong hồ sơ nhân sự.

### 2.4. Tuyển dụng & duyệt headcount

- Mọi vị trí tuyển mới phải mở **Requisition** (vị trí, mã vai, Level, lý do, ngân sách, ngày cần nhân sự): **HR_L2 duyệt headcount** trước khi đăng tin; vượt headcount kế hoạch năm → BOD phê duyệt.

### 2.5. Onboarding, đào tạo & lộ trình thăng Level

- **Onboarding checklist chuẩn:** ký HĐLĐ + hồ sơ; cấp tài khoản ERP gắn RBAC theo mã vai; phân công buddy; mục tiêu thử việc theo khung năng lực. Checklist hoàn thành là điều kiện đánh giá cuối thử việc.
- **Đào tạo theo khung năng lực 5 cấp (L1–L5)** cho từng nhóm vai; kế hoạch đào tạo gắn khoảng cách năng lực hiện tại → Level kế tiếp.
- **Lộ trình thăng Level:** đạt chuẩn năng lực + KPI 2 chu kỳ liên tiếp → manager đề xuất → HR_L2 thẩm định → BOD phê duyệt → cập nhật Level trong hồ sơ, hiệu lực từ đầu chu kỳ sau.

### 2.6. Self-service (ESS)

- Nhân sự tự thao tác: xem hồ sơ của mình, xin nghỉ phép, đề nghị điều chỉnh chấm công, xem timesheet/KPI của mình, cập nhật thông tin cá nhân. Trường nhạy cảm (tài khoản ngân hàng, người liên hệ khẩn) và mọi thay đổi ảnh hưởng payroll phải HR_L2 duyệt.

### 2.7. Cost Rate Card

- Bảng **cost/hour chuẩn theo Level**, **version hóa từ ngày–đến ngày (SCD2)**: mỗi dòng gồm Level, cost/hour, khoảng hiệu lực, số version, người duyệt. P&L và báo cáo dự án **chọn đúng version theo ngày ghi giờ**.
- Quy trình thay đổi: **HR_L2 đề xuất + FIN_L2 thẩm định** (đối chiếu payroll thực tế) → **BOD phê duyệt** → phát hành version mới kèm ngày hiệu lực; version đã phát hành không được sửa.
- **Bảo mật:** lương và cost là dữ liệu **Confidential, mã hóa**; chỉ **HR_L2 trở lên** được xem số lương/cost cá nhân; Manager chỉ xem tổng cost nhóm, không xem lương từng người.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Thăng chức/điều chuyển giữa chu kỳ: tạo version mới của mã vai/Level/cost từ ngày hiệu lực, không sửa dữ liệu quá khứ.
- Nghỉ không lương > 30 ngày: tạm đóng băng allocation và capacity; KPI tính theo ngoại lệ policy `kpi-hieu-suat.md`.
- Freelancer làm liên tục ≥ 3 tháng: BOD có thể yêu cầu lập Rate Card tham chiếu riêng.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Duyệt headcount (Requisition) | HR_L2; vượt kế hoạch năm → BOD | 3 ngày làm việc |
| Kết thúc thử việc / ký HĐLĐ chính thức | Manager đánh giá + HR_L2 duyệt | Trước hạn thử việc ≥ 3 ngày |
| Duyệt nghỉ phép ≤ 5 ngày | Team Leader | 24h |
| Duyệt nghỉ phép > 5 ngày / nghỉ không lương | HR_L2 | 48h |
| Thăng Level | HR_L2 thẩm định → BOD phê duyệt | Chu kỳ quý |
| Thay đổi Cost Rate Card | HR_L2 đề xuất + FIN_L2 thẩm định → BOD phê duyệt | Trước kỳ P&L áp dụng |
| Sửa hồ sơ (trường nhạy cảm/payroll) | HR_L2 | 24h, kèm audit log |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Hồ sơ nhân sự là master data duy nhất; RBAC/Hoa hồng/P&L/KPI đọc từ đó | Integration | HR Core | MUST |
| Version hóa Level, vai, trạng thái, cost theo hiệu lực từ ngày–đến ngày (SCD2) | Data Model | HR Core / P&L | MUST |
| Cảnh báo hết hạn HĐLĐ 90/60/30 ngày | Notification | HR Core | MUST |
| Tích lũy phép năm tự động (12 ngày/năm, 1 ngày/tháng); chặn duyệt vượt số dư | Validation | Leave | MUST |
| Chặn OT khi tổng giờ tuần > 48h | Validation | Attendance / Timesheet | MUST |
| Workflow Requisition duyệt headcount trước khi đăng tin | Workflow | Recruitment | MUST |
| Onboarding checklist gắn cấp tài khoản + RBAC theo mã vai | Workflow | Onboarding / RBAC | MUST |
| Cost Rate Card SCD2; P&L chọn version theo ngày ghi giờ | Calculation | P&L / HR | MUST |
| Mã hóa dữ liệu lương/cost; RBAC chỉ HR_L2+ xem cá nhân | Security | HR Core | MUST |
| Audit log bất biến mọi thay đổi hồ sơ và Cost Rate Card | Audit Trail | HR Core | MUST |
| Cổng ESS self-service cho nhân sự | UX | ESS | SHOULD |
| Báo cáo headcount, nghỉ phép, tổng cost theo team cho HR_L2/BOD | Reporting | HR | SHOULD |

**Cross-policy dependencies:**
- `timesheet-capacity.md` — định mức 40h/tuần, trần OT 48h/tuần; Cost Rate Card là đầu vào quy đổi giờ đã duyệt thành chi phí P&L.
- `kpi-hieu-suat.md` — Level hiện hành quyết định trọng số KPI; KPI 2 chu kỳ liên tiếp là điều kiện thăng Level.
- Policy RBAC & phân quyền — mã vai trong hồ sơ là khóa phân quyền hệ thống.
- Policy Tài chính/P&L — Cost Rate Card là đầu vào chi phí nhân sự theo dự án.

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
| 1.0 | 11/09/2026 | hr-expert | Khởi tạo |
