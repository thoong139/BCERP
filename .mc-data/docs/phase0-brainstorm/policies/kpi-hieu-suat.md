# KPI & Hiệu Suất (3 Trụ Cột, PIP) — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Nhân sự / Hiệu suất
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** hr-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** 100% nhân sự có mã vai trong hồ sơ (SALES_*, OPS_*, FIN_*, HR_*, PM/Lead), gồm cả thử việc (đánh giá đơn giản hóa).
- **Không áp dụng cho:** BOD (đánh giá theo mục tiêu doanh thu/lợi nhuận do cơ quan chủ quản quyết định); freelancer/cộng tác viên ngoài biên chế.
- **Effective từ:** 01/10/2026 (đề xuất — chờ xác nhận ở Section 6).

---

## 2. Nội Dung Chính Sách

### 2.1. Ba trụ cột KPI — tự tổng hợp từ hệ thống

| Trụ cột | Nguồn dữ liệu tự động | Công thức |
|---------|------------------------|-----------|
| On-time Delivery Rate | Task deadline trong module Task/Project | Số task giao đúng hạn ÷ tổng số task đã giao trong kỳ |
| Output Volume | Deliverable đạt chuẩn QC | Số deliverable đạt chuẩn ÷ mục tiêu chuẩn theo vai + Level trong kỳ |
| Project Target/SLA Delivery | SLA + target của dự án | Tỷ lệ dự án/mốc đạt SLA và target cam kết trong kỳ |

**Nguyên tắc cốt lõi:** ba trụ cột được hệ thống **tự tổng hợp từ dữ liệu vận hành** — nhân sự và quản lý **không được phép nhập/trị điểm tay** cho bất kỳ trụ cột nào. Mọi thành phần chấm tay phải được khai báo thành thành phần riêng có trọng số riêng (Section 2.3).

### 2.2. Trọng số theo bậc

| Level | On-time Delivery | Output Volume | Project Target/SLA | Thành phần chấm tay | Tổng |
|-------|------------------|---------------|--------------------|---------------------|------|
| L1 | 20% | 50% | 15% | 15% | 100% |
| L2 | 20% | 45% | 20% | 15% | 100% |
| L3 | 25% | 30% | 30% | 15% | 100% |
| L4 | 25% | 15% | 45% | 15% | 100% |
| L5 | 20% | 10% | 55% | 15% | 100% |

- L1–L2 nặng **Output Volume** (công việc sản xuất trực tiếp); L4–L5 nặng **Project Target/SLA** (chịu trách nhiệm kết quả dự án).
- Trọng số cấu hình theo Level trong hệ thống; thay đổi phải qua quy trình Section 4.

### 2.3. Thành phần chấm tay

- Mọi tiêu chí chấm tay (VD: teamwork, tuân thủ quy trình, sáng kiến) phải được **khai báo trong cấu hình KPI** với trọng số riêng và rubric chấm rõ ràng trước khi sử dụng.
- Không khai báo → hệ thống không cho phép chấm tay. Mọi điểm chấm tay phải có người chấm, ngày chấm, nhận xét lưu vết.

### 2.4. Chu kỳ review minh bạch

- **Review quý.** Luồng: hệ thống tổng hợp tự động (đóng kỳ) → nhân sự **xem trước dữ liệu gốc của chính mình** (task, deliverable, SLA — minh bạch 100%) → Team Leader/Manager phỏng vấn review → **calibration HR_L2** → chốt → trình BOD (bắt buộc với L4–L5 và trường hợp top/bottom).
- Nhân sự có quyền thắc mắc và đề nghị đối chiếu dữ liệu gốc trong vòng 3 ngày làm việc sau khi xem trước.

### 2.5. Calibration

- HR_L2 tổ chức **calibration trước khi trình BOD**: so sánh chéo giữa các team, phát hiện và xử lý outlier, chuẩn hóa thang chấm tay.
- Biên bản calibration (người tham dự, quyết định, lý do điều chỉnh) lưu trong hệ thống; mọi điều chỉnh điểm sau calibration phải qua audit log.

### 2.6. PIP 30-60-90 ngày

- **Điều kiện vào PIP:** điểm KPI quý < 60/100; hoặc 2 quý liên tiếp dưới kỳ vọng; hoặc vi phạm SLA nghiêm trọng được xác nhận.
- **Cấu trúc 30-60-90:** mốc 30 ngày — nhận diện vấn đề + hướng dẫn cụ thể (milestone 1); mốc 60 ngày — đo tiến bộ, coaching tăng cường (milestone 2); mốc 90 ngày — quyết định: đạt → thoát PIP; không đạt → BOD quyết định điều chuyển, hạ Level, hoặc chấm dứt HĐLĐ theo pháp luật lao động.
- Manager coaching tối thiểu 2 tuần/lần trong suốt PIP; HR_L2 lưu toàn bộ hồ sơ PIP trong hệ thống.

### 2.7. Xử lý cảnh báo quá tải > 100% liên tục ≥ 2 tuần

- Khi Capacity Utilization > 100% liên tục ≥ 2 tuần: hệ thống **tự gắn cờ quá tải** vào chu kỳ review kỳ đó.
- Nhân sự bị gắn cờ **không bị phạt điểm On-time Delivery** do trễ phát sinh từ quá tải (hệ thống ghi chú vào kết quả KPI).
- Team Leader phải giải trình và tái cân bằng tải trong 5 ngày làm việc; quá 3 lần gắn cờ trong một quý → HR_L2 xem xét đề xuất headcount.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Nhân sự mới** (< 30 ngày trong kỳ): không tính KPI đầy đủ, đánh giá định tính.
- **Nghỉ dài ≥ 1 tháng** (thai sản, ốm dài, nghỉ không lương): KPI kỳ đó tính prorate hoặc miễn theo xác nhận HR_L2.
- **Dự án khẩn cấp/lực lượng bất khả kháng** được BOD duyệt loại trừ khỏi tính On-time (phải duyệt trước hoặc trong 24h).
- **Thử việc:** chỉ áp Output Volume + tuân thủ quy trình, trọng số 70/30, không áp PIP.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Chốt kết quả KPI cá nhân (L1–L3) | Manager, sau calibration HR_L2 | 10 ngày làm việc sau khi hết quý |
| Kết quả KPI L4–L5 / điều chỉnh biên | BOD | 15 ngày làm việc sau khi hết quý |
| Mở PIP | Manager đề xuất + HR_L2 duyệt | 5 ngày làm việc sau khi công bố KPI |
| Kết thúc PIP (đạt/không đạt) | HR_L2 xác nhận dữ liệu; chấm dứt HĐLĐ → BOD | Đúng mốc 90 ngày |
| Thay đổi trọng số/công thức KPI | HR_L2 đề xuất → BOD phê duyệt | Chu kỳ năm, hiệu lực đầu năm tài chính |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Tự động tổng hợp On-time Delivery Rate từ task deadline | Calculation | KPI / Task | MUST |
| Tự động tổng hợp Output Volume từ deliverable đạt chuẩn QC | Calculation | KPI / Deliverable | MUST |
| Tự động tổng hợp SLA/Target delivery từ dữ liệu dự án | Calculation | KPI / Project | MUST |
| Chặn nhập điểm tay cho 3 trụ cột tự động | Validation | KPI | MUST |
| Bắt buộc khai báo trọng số + rubric cho thành phần chấm tay trước khi dùng | Validation | KPI Config | MUST |
| Cấu hình và áp dụng trọng số theo Level | Config | KPI Config | MUST |
| Dashboard minh bạch dữ liệu gốc KPI cho từng nhân sự | Reporting | ESS / KPI | MUST |
| Cảnh báo quá tải > 100% ≥ 2 tuần + gắn cờ miễn phạt On-time vào review | Notification | Capacity / KPI | MUST |
| Workflow calibration kèm biên bản lưu vết | Workflow | KPI / HR | MUST |
| Theo dõi PIP 30-60-90 với milestone và lịch coaching | Workflow | HR | MUST |
| Audit log mọi điều chỉnh điểm sau calibration | Audit Trail | KPI | MUST |
| Báo cáo phân bố điểm theo team/Level cho BOD | Reporting | KPI | NICE |

**Cross-policy dependencies:**
- `timesheet-capacity.md` — dữ liệu task/timesheet là nguồn tính trụ cột; cảnh báo quá tải > 100% ≥ 2 tuần phát từ Capacity Utilization.
- `nhan-su-hanh-chinh-cost-rate-card.md` — Level hiện hành trong hồ sơ nhân sự quyết định bảng trọng số; KPI 2 chu kỳ là điều kiện thăng Level.
- Policy Quản lý dự án & SLA — nguồn dữ liệu SLA/target cho trụ cột 3.
- Policy Hoa hồng (Sales) — kết quả KPI là điều kiện phê duyệt chi hoa hồng.

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
