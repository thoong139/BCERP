# Timesheet & Capacity — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Nhân sự / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** hr-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** 100% nhân sự có mã vai trong hệ thống (SALES_L1–L5, OPS_L1–L5, FIN_*, HR_*, PM/Lead) khi được gán vào bất kỳ dự án nào (Client Billable hoặc Internal Non-billable). Mọi giờ làm việc phục vụ dự án phải được ghi timesheet và chiếm capacity.
- **Không áp dụng cho:** BOD (ghi giờ theo mục tiêu quản trị, không bắt buộc chi tiết task); freelancer/cộng tác viên ngoài biên chế (quy chế riêng); thời gian nghỉ phép/ốm đã duyệt.
- **Effective từ:** 01/10/2026 (đề xuất — chờ xác nhận ở Section 6).

---

## 2. Nội Dung Chính Sách

### 2.1. Định mức giờ làm việc theo Level

| Level | Vai trò điển hình | Giờ chuẩn/tuần | Trần ghi nhận/tuần (gồm OT) | Tỷ lệ billable mục tiêu |
|-------|-------------------|----------------|------------------------------|--------------------------|
| L1 | Junior (OPS_L1, SALES_L1) | 40h | 48h | ≥ 80% |
| L2 | Staff (OPS_L2, SALES_L2) | 40h | 48h | ≥ 75% |
| L3 | Senior / Team Leader | 40h | 48h | 60–70% |
| L4 | Manager | 40h | 48h | 40–50% |
| L5 | Director / Head | 40h | 48h | 20–30% |

- **Capacity khả dụng/tuần** = giờ chuẩn − giờ nghỉ phép/ốm đã duyệt trong tuần.
- **Capacity Utilization** = tổng giờ đã gán ÷ capacity khả dụng (hệ thống tính tự động theo tuần).
- Tuần có ngày lễ: capacity khả dụng giảm tương ứng số ngày lễ.

### 2.2. Ngưỡng tải và cơ chế chặn

| Vùng | Utilization | Hệ quả |
|------|-------------|--------|
| Dưới tải | < 70% | Cảnh báo Team Leader: gán thêm việc hoặc đánh giá rủi ro cạn việc |
| Xanh | 70% – 90% | Bình thường — nhận gán mới không cần duyệt thêm |
| Vàng | > 90% | Dừng gán mới tự động; gán mới phải được Team Leader phê duyệt (escalate) |
| Đỏ | ≥ 100% | Hệ thống **chặn cứng** gán mới; bắt buộc escalate: dịch deadline, đổi người, hoặc duyệt OT |

### 2.3. Capacity check trước khi gán task

- Mọi thao tác gán task/assignment phải chạy **capacity check trước** khi tạo.
- Capacity check gắn với **Handoff Gate 2 — "xác nhận Capacity trống"**: khi bàn giao việc giữa các giai đoạn/vai trò, hệ thống phải xác nhận người nhận còn capacity trống trước khi handoff hoàn tất.
- **SLA xử lý capacity check: 4 giờ** kể từ khi phát yêu cầu; quá 4h chưa có xác nhận → tự động escalate lên Team Leader; quá 8h → escalate HR_L2 để cân đối đầu người.

### 2.4. Quy tắc ghi timesheet

1. **Ghi hằng ngày** trong ngày làm việc, chậm nhất trước 12:00 hôm sau; chậm quá 3 ngày → cảnh báo Team Leader.
2. Mỗi dòng timesheet **bắt buộc gắn nhãn Client Billable / Internal Non-billable ngay tại thời điểm ghi**; không chọn nhãn → không lưu được.
3. **Cấm sửa nhãn sau khi ghi.** Sai sót phải tạo **correction** — hệ thống giữ bản gốc và ghi **audit log** (ai, khi nào, sửa gì, lý do).
4. **Cấm ghi giờ nội bộ vào dự án khách hàng** (và ngược lại): validation chặn theo cặp loại dự án × nhãn.
5. **Chốt tuần:** nhân sự chốt trước 12:00 thứ Hai tuần kế tiếp; **Team Leader duyệt trong 48h**; **cấm tự duyệt** (approver bắt buộc khác người ghi; timesheet của Team Leader do Manager L4 duyệt).
6. **Giờ chưa duyệt không được tính vào P&L** — chỉ giờ đã duyệt mới được nhân Cost Rate Card để allocate chi phí nhân sự vào dự án.

### 2.5. Overtime (OT)

- OT phải được **duyệt trước** khi thực hiện; trừ sự cố khách hàng khẩn cấp — được duyệt retro trong 24h kèm lý do.
- Trần OT: tối đa **8h OT/tuần**, tổng giờ chuẩn + OT **không vượt 48h/tuần** (Điều 107 BLLĐ 2019), trần năm 200h/năm.
- OT có duyệt được tính hệ số lương làm thêm theo quy định pháp luật và nằm trong trần ghi nhận 48h/tuần (Section 2.1).

### 2.6. Tỷ lệ billable

- Tỷ lệ billable thực tế = giờ Client Billable đã duyệt ÷ tổng giờ đã duyệt; tổng hợp tự động theo tháng, so với mục tiêu theo bậc (Section 2.1) và là đầu vào cho KPI (policy `kpi-hieu-suat.md`) và P&L.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Nghỉ phép/ốm đã duyệt** không chiếm capacity và không tính vào utilization.
- **Sự cố khẩn cấp của khách hàng** (VD: tài khoản quảng cáo bị khóa ngoài giờ): Team Leader được cho phép vượt 100% tối đa **110%**, không quá **5 ngày làm việc liên tục**, bắt buộc log lý do; vượt mốc phải BOD duyệt.
- **L5/BOD** làm việc theo mục tiêu: ghi timesheet theo dự án, không bắt buộc chi tiết từng task.
- **Nhân sự mới tuần đầu (onboarding nội bộ):** 100% giờ Internal Non-billable, không áp ngưỡng billable.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Duyệt timesheet tuần | Team Leader (cấm tự duyệt; TL do Manager L4 duyệt) | 48h sau khi chốt |
| Correction timesheet đã ghi | Team Leader xác nhận + audit log | 24h |
| Gán mới ở vùng vàng (> 90%) | Team Leader | Trong SLA 4h của capacity check |
| Gán mới ở vùng đỏ (≥ 100%, escalate) | Team Leader; cần thêm đầu người → HR_L2 | 4h |
| Duyệt OT trong trần 8h/tuần | Team Leader | Trước khi thực hiện |
| Duyệt OT vượt trần tuần hoặc retro | HR_L2 | 24h |
| Điều chỉnh định mức giờ/tuần hoặc tỷ lệ billable theo bậc | HR_L2 đề xuất → BOD phê duyệt | Chu kỳ năm |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Tính Capacity Utilization theo tuần từ assignment + timesheet đã duyệt | Calculation | Capacity / HR | MUST |
| Chặn tạo assignment khi Utilization ≥ 100% | Validation | Capacity / Task | MUST |
| Cảnh báo vùng vàng > 90% và dưới tải < 70% cho Team Leader | Notification | Capacity | MUST |
| Capacity check bắt buộc trước khi gán; escalate 4h (Team Leader) → 8h (HR_L2) | Workflow | Capacity / Task | MUST |
| Bắt buộc chọn nhãn Billable/Non-billable tại thời điểm ghi | Validation | Timesheet | MUST |
| Cấm sửa nhãn sau ghi; correction bắt buộc qua audit log bất biến | Audit Trail | Timesheet | MUST |
| Chặn giờ nội bộ ghi vào dự án khách (validation loại dự án × nhãn) | Validation | Timesheet / Project | MUST |
| Chặn tự duyệt timesheet (approver ≠ người ghi) | Validation | Timesheet | MUST |
| Giờ chưa duyệt không được allocate cost vào P&L | Integration | Timesheet / P&L | MUST |
| Đếm OT theo tuần, chặn khi tổng giờ > 48h/tuần | Validation | Timesheet / HR | MUST |
| Nhắc ghi hằng ngày + dashboard ghi chậm cho Team Leader | Notification | Timesheet | SHOULD |
| Báo cáo tỷ lệ billable thực tế theo bậc/tháng, đối chiếu mục tiêu | Reporting | Timesheet / P&L | SHOULD |

**Cross-policy dependencies:**
- `nhan-su-hanh-chinh-cost-rate-card.md` — Cost Rate Card theo Level để quy đổi giờ đã duyệt thành cost; định mức 40h/tuần và trần OT 48h/tuần lấy từ policy nhân sự.
- `kpi-hieu-suat.md` — dữ liệu task/timesheet là nguồn cho On-time Delivery Rate và Output Volume; cảnh báo quá tải > 100% ≥ 2 tuần phát từ Capacity.
- Handoff Gate 2 của quy trình dự án — điều kiện "xác nhận Capacity trống" là prerequisite của handoff.

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
