# Playbook: Thiết kế Payroll System

> **Type**: Agent Skill Playbook
> **Agent**: hr-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế hệ thống tính lương
> **Output**: Feature spec payroll module tại phase2-features/

---

## Khi nào dùng playbook này

- Dự án có requirement về payroll / tính lương / BHXH / thuế TNCN
- Cần thiết kế workflow từ chấm công đến chuyển khoản ngân hàng
- Invoke trong Phase 2 (Features) hoặc Phase 3 (Architecture)

> Nếu payroll phức tạp (nhiều entity, expatriate, sales commission) → invoke thêm `finance-expert`

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
Đọc: REQ-HR-PAY-* từ phase1-business/hr-requirements.md (nếu có)
READ: controls.md (Section 7 — Compliance, Section 3 — Approvals)
READ: operations.md (Process 4 — Payroll Processing)

Xác định scope payroll:
□ Loại hợp đồng: toàn thời gian / bán thời gian / CTV / thời vụ
□ Chu kỳ lương: tháng / 2 lần/tháng / tuần
□ Cách tính lương: theo tháng cố định / theo ngày công / theo giờ
□ Có overtime không? Công thức như thế nào?
□ Phụ cấp nào? (ăn trưa, xăng xe, điện thoại, trách nhiệm, nhà ở...)
□ Thưởng: KPI-based / fixed / discretionary?
□ Multi-entity (nhiều công ty con) không?
□ Có nhân sự nước ngoài (expatriate) không?
```

### Bước 2: Thiết kế Payroll Period Setup

```
Payroll period configuration:
□ Ngày bắt đầu / kết thúc kỳ lương (vd: 1-30, 26-25, 21-20)
□ Ngày chốt chấm công (cutoff date)
□ Ngày thanh toán (payment date)
□ Lock mechanism: sau khi run payroll → lock data tháng đó
□ Adjustment period: cho phép điều chỉnh trong bao nhiêu ngày sau run?

Trạng thái kỳ lương:
Open → Cutoff → Processing → Review → Approved → Paid → Closed
```

### Bước 3: Thiết kế Salary Components

```
Gross Salary structure (parameterize, không hardcode):

EARNINGS (+):
□ Lương cơ bản (basic salary)
□ Phụ cấp chức vụ (position allowance)
□ Phụ cấp xăng xe (transport allowance)
□ Phụ cấp điện thoại (phone allowance)
□ Phụ cấp ăn trưa (meal allowance) — ≤ 730.000đ/tháng miễn thuế
□ Phụ cấp nhà ở (housing allowance)
□ Phụ cấp chuyên cần (attendance bonus)
□ Overtime pay (lương làm thêm giờ)
□ Thưởng KPI / Thưởng dự án

DEDUCTIONS (-):
□ BHXH người lao động: 8% * lương đóng BHXH
□ BHYT người lao động: 1.5% * lương đóng BHYT
□ BHTN người lao động: 1% * lương đóng BHTN
□ Thuế TNCN (PIT — xem Bước 4)
□ Khấu trừ ứng lương (salary advance deduction)
□ Khấu trừ tài sản (equipment deduction nếu có)

Lưu ý: mỗi component có flag:
- taxable: true/false (có tính vào thu nhập chịu thuế không)
- insurance_base: true/false (có tính vào mức đóng BHXH không)
- editable_per_employee: true/false (cố định hay nhập riêng từng người)
```

### Bước 4: Thiết kế PIT (Thuế TNCN) Calculation

```
Thuế TNCN theo biểu lũy tiến 7 bậc (Luật Thuế TNCN VN):

Thu nhập tính thuế = Tổng thu nhập - Giảm trừ gia cảnh - BHXH/BHYT/BHTN - Đóng góp từ thiện

Giảm trừ gia cảnh:
- Bản thân: 11.000.000đ/tháng
- Người phụ thuộc: 4.400.000đ/người/tháng (đã đăng ký)

Biểu thuế lũy tiến (tính trên thu nhập tính thuế/tháng):
┌─────────────────────────────┬──────────┬───────────────────────────────┐
│ Bậc │ Thu nhập tính thuế    │ Thuế suất│ Cách tính nhanh              │
├─────────────────────────────┼──────────┼───────────────────────────────┤
│  1  │ ≤ 5.000.000           │   5%     │ TNT × 5%                      │
│  2  │ 5tr – 10tr            │  10%     │ TNT × 10% - 250.000           │
│  3  │ 10tr – 18tr           │  15%     │ TNT × 15% - 750.000           │
│  4  │ 18tr – 32tr           │  20%     │ TNT × 20% - 1.650.000         │
│  5  │ 32tr – 52tr           │  25%     │ TNT × 25% - 3.250.000         │
│  6  │ 52tr – 80tr           │  30%     │ TNT × 30% - 5.850.000         │
│  7  │ > 80.000.000          │  35%     │ TNT × 35% - 9.850.000         │
└─────────────────────────────┴──────────┴───────────────────────────────┘

QUAN TRỌNG — Edge cases phải handle:
□ Nhân viên mới trong tháng: tính theo ngày thực tế
□ Nhân viên có nhiều nguồn thu nhập: lũy kế năm
□ Quyết toán thuế năm (year-end finalization)
□ Cá nhân không cư trú (non-resident): flat 20% trên tổng thu nhập
□ Người phụ thuộc chỉ có hiệu lực từ tháng đăng ký
```

### Bước 5: Thiết kế BHXH/BHYT/BHTN Calculation

```
Mức đóng bảo hiểm xã hội (theo quy định hiện hành):

NGƯỜI LAO ĐỘNG đóng (trừ vào lương):
□ BHXH: 8% × mức lương đóng BHXH
□ BHYT: 1.5% × mức lương đóng BHYT
□ BHTN: 1% × mức lương đóng BHTN
□ Tổng: 10.5% × mức lương đóng BHXH

DOANH NGHIỆP đóng (chi phí công ty, không ảnh hưởng lương net):
□ BHXH: 17.5% × mức lương đóng BHXH
□ BHYT: 3% × mức lương đóng BHYT
□ BHTN: 1% × mức lương đóng BHTN
□ KPCĐ: 2% × tổng quỹ lương
□ Tổng: 23.5% × mức lương đóng BHXH

Mức lương đóng BHXH:
- Tối thiểu: lương tối thiểu vùng (parameterize theo vùng 1-4)
- Tối đa: 20 × mức lương cơ sở (thay đổi theo nghị định)
- Phải parameterize — KHÔNG hardcode mức lương tối thiểu

BHXH report:
□ File D02-LT (danh sách lao động đóng BHXH) → submit monthly
□ File C12-TS (phiếu điều chỉnh) → khi có thay đổi
```

### Bước 6: Thiết kế Attendance Integration

```
Data từ chấm công vào payroll:
□ Ngày công thực tế (actual working days)
□ Số giờ làm thêm theo loại (weekday overtime, weekend, holiday)
□ Ngày nghỉ phép đã duyệt (approved leave)
□ Ngày nghỉ không phép / không lương
□ Ngày lễ tết (theo lịch công ty/nhà nước)

Công thức tính lương theo ngày công:
Lương thực nhận = (Lương cơ bản / Số ngày làm việc chuẩn) × Số ngày công thực tế

Overtime calculation:
□ Ngày thường: lương giờ × 1.5
□ Cuối tuần: lương giờ × 2.0
□ Ngày lễ / Tết: lương giờ × 3.0
□ Lương giờ = Lương tháng / (Số ngày làm việc chuẩn × Số giờ/ngày)

Leave deductions:
□ Nghỉ phép năm: không khấu trừ lương
□ Nghỉ không phép: khấu trừ theo ngày công
□ Nghỉ ốm không có lương: khấu trừ + BHXH chi trả phần ốm đau
```

### Bước 7: Thiết kế Payslip Generation

```
Payslip phải hiển thị:
□ Kỳ lương (tháng/năm)
□ Thông tin nhân viên (name, code, department, position)
□ Chi tiết thu nhập (từng dòng earnings)
□ Chi tiết khấu trừ (BHXH, BHYT, BHTN, PIT, ứng lương...)
□ Lương thực nhận (net pay)
□ Số ngày công / Số giờ OT
□ Số người phụ thuộc đang áp dụng

Format:
□ Web view (employee self-service)
□ PDF export (để lưu trữ)
□ Email gửi tự động sau khi payroll được approve

Confidentiality:
□ Employee chỉ thấy payslip của chính mình
□ Manager KHÔNG thấy salary cụ thể của team member (chỉ budget tổng)
□ HR Manager thấy tất cả
```

### Bước 8: Thiết kế Bank Transfer File

```
Bank transfer file generation:
□ Format theo từng ngân hàng (Vietcombank, BIDV, Vietinbank, Techcombank...)
□ Cần parameterize format — mỗi ngân hàng có template khác nhau
□ Thông tin mỗi dòng: Mã nhân viên, Tên, Số tài khoản, Số tiền, Nội dung

Quy trình:
1. Generate file từ approved payroll
2. Maker review file
3. Export + Upload lên internet banking (manual) hoặc API direct nếu có
4. Mark as paid sau khi xác nhận bank

Lưu ý: KHÔNG tự động gửi tiền — phải có human approval trước khi payment
```

### Bước 9: Thiết kế Year-End Finalization

```
Quyết toán thuế năm (annual PIT finalization):
□ Tổng thu nhập cả năm (12 tháng)
□ Tổng khấu trừ đã đăng ký (bản thân + người phụ thuộc)
□ Tổng BHXH/BHYT/BHTN đã đóng
□ Tổng thuế đã tạm khấu trừ hàng tháng
□ Thuế phải nộp thêm / được hoàn

Báo cáo quyết toán:
□ Tờ khai quyết toán thuế TNCN (Mẫu 05/QTT-TNCN)
□ Phụ lục danh sách cá nhân (Mẫu 05-1/BK-QTT-TNCN, 05-2/BK-QTT-TNCN)
□ Export file XML để nộp trên thuế điện tử (HTKK)

Invoke finance-expert nếu:
- Có GL posting requirements
- Có cost center allocation phức tạp
- Cần reconcile với accounting system
```

### Bước 10: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/hr/payroll/[feature-name].md

Cấu trúc output:
1. Module Overview — phạm vi payroll module
2. Payroll Workflow Diagram (text-based)
3. Feature List (có mapping REQ-ID)
4. Feature Specs chi tiết (mỗi feature một section)
5. Data Model sơ bộ (entities: PayrollPeriod, PayrollRecord, SalaryComponent, TaxRecord)
6. Compliance Notes (BHXH rates, PIT brackets — dẫn nguồn, nhắc parameterize)
7. Integration Points (Attendance, Finance/GL, Banking)
8. Edge Cases cần xử lý
9. Open Items / Decisions Needed
```

---

## Checklist trước khi submit

```
□ Tất cả BHXH/BHYT/BHTN rates đã documented (và nhắc parameterize — không hardcode)
□ PIT 7 bậc lũy tiến đã covered đầy đủ + edge cases
□ Year-end finalization workflow đã có
□ Payslip access control: employee chỉ thấy own data
□ Bank transfer file: human approval trước khi payment
□ Payroll lock sau khi đã run (tránh retroactive changes)
□ Audit trail cho mọi salary changes
□ GL posting đã noted (invoke finance-expert nếu cần chi tiết)
□ Lương tối thiểu vùng parameterize (không hardcode)
```
