# Playbook: Audit HR Systems (As-Is Analysis)

> **Type**: Agent Skill Playbook
> **Agent**: hr-expert
> **Triggered by**: /wf-legacy-scan khi project có HR system hiện tại
> **Output**: `.mc-data/docs/phase1-business/hr-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-legacy-scan`
- Dự án đang có HRIS / HRM system cũ hoặc dùng spreadsheets
- Cần audit trước khi build hoặc replace hệ thống
- Cần đánh giá migration risks và gaps

---

## Procedure

### Bước 1: Đọc context dự án hiện có

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PROJECT_ROOT

Tìm hiểu:
□ Hệ thống HR hiện tại là gì? (tên phần mềm, phiên bản, nhà cung cấp)
□ Dùng từ năm nào? Bao nhiêu nhân viên đang dùng?
□ Lý do muốn thay thế hoặc nâng cấp?
□ Có data xuất được ra không? (CSV, Excel, API?)
□ Còn hợp đồng với vendor cũ không? Thời hạn?
```

### Bước 2: Inventory hệ thống HR hiện có

```
READ: controls.md (Section 1 — Data Access Matrix)

Lập danh sách các tool/system đang dùng:

| Chức năng | Tool hiện tại | Số user | Ghi chú |
|-----------|---------------|---------|---------|
| Quản lý hồ sơ nhân viên | VD: Excel / phần mềm X | ? | |
| Tuyển dụng | VD: Email + form / ATS | ? | |
| Chấm công | VD: Máy chấm công / app | ? | |
| Tính lương | VD: Excel / phần mềm X | ? | |
| Xin nghỉ phép | VD: Email / form | ? | |
| Performance review | VD: Form giấy / Excel | ? | |
| Đào tạo | VD: Manual / LMS | ? | |

Mỗi tool: đánh giá
- Satisfaction score (1-5: nhân viên có hài lòng không?)
- Integration hiện tại với tool khác
- Data quality (dữ liệu tin cậy không?)
```

### Bước 3: Đánh giá chất lượng Employee Data

```
Data quality assessment — từng loại dữ liệu:

EMPLOYEE MASTER DATA:
□ Bao nhiêu nhân viên active hiện tại? Inactive?
□ Dữ liệu có đủ: họ tên, CCCD, mã nhân viên, ngày vào, phòng ban, chức vụ?
□ Có duplicate records không?
□ Email, số điện thoại có up-to-date không?
□ Org chart có chính xác không? (ai report to ai)

PAYROLL HISTORY:
□ Dữ liệu lương lưu từ năm nào?
□ Có đủ payslips lịch sử không? (cần 3-5 năm gần nhất)
□ BHXH records có khớp với sổ BHXH không?
□ Thuế TNCN đã quyết toán đủ năm chưa?

LEAVE HISTORY:
□ Số dư phép năm của từng nhân viên có chính xác không?
□ Có backlog phép chưa tính không?

Data quality scoring (mỗi loại):
- GREEN: > 90% complete, accurate
- YELLOW: 70-90%, cần cleanup
- RED: < 70%, cần major remediation trước khi migrate
```

### Bước 4: Đánh giá Payroll Accuracy

```
Payroll accuracy check:

□ Lấy payslip 3 tháng gần nhất của 5-10 nhân viên mẫu
□ Tái tính thủ công theo công thức BHXH + PIT
□ So sánh kết quả với payslip hiện tại

Các lỗi thường gặp cần kiểm tra:
□ BHXH tính sai mức trần / sàn
□ PIT không tính lũy tiến đúng
□ Phụ cấp ăn trưa tính vào thu nhập chịu thuế (sai nếu ≤ 730K)
□ Không tính thêm người phụ thuộc đúng kỳ
□ Overtime không đúng hệ số (1.5x/2x/3x)
□ Thiếu ghi nhận lương tháng 13 / thưởng tết vào PIT

Tài liệu evidence cần lưu:
- Screenshot payslip mẫu
- Bảng tái tính
- Delta (chênh lệch) nếu có
```

### Bước 5: Đánh giá Compliance Gaps

```
READ: controls.md (Section 7 — Compliance Requirements)

Labor Law compliance gaps:
□ Có track overtime hours không? Có vượt 200h OT/năm theo luật không?
□ Nghỉ phép năm có được tích lũy đúng (tăng theo thâm niên) không?
□ Hợp đồng lao động có đúng loại và thời hạn không?
□ Thử việc có vượt 60 ngày không?
□ Báo cáo BHXH hàng tháng có nộp đúng hạn không?

BHXH reporting gaps:
□ File D02-LT có generate được không?
□ Có nhân viên nào chưa tham gia BHXH mà bắt buộc phải tham gia?
□ Mức đóng BHXH có theo đúng mức lương hợp đồng không?

Tax compliance gaps:
□ Có nhân viên nào chưa đăng ký người phụ thuộc đúng cách?
□ Có tờ khai quyết toán PIT hàng năm không?
□ Có người nước ngoài không cư trú đang tính sai thuế suất không?

Data privacy gaps:
□ Dữ liệu nhân viên có được encrypt không?
□ Ai có quyền truy cập vào salary data hiện tại? Có over-privileged không?
□ Có log audit cho việc xem dữ liệu nhạy cảm không?
```

### Bước 6: Đánh giá Process Documentation

```
Process documentation assessment:

□ Có SOP (quy trình chuẩn) bằng văn bản không?
□ Ai hiện đang thực hiện payroll? Chỉ 1 người? (single point of failure)
□ Có checklist tháng không? (payroll checklist)
□ Knowledge transfer nếu người chủ chốt nghỉ?
□ Có test scenario nào để verify payroll đúng không?

Tài liệu nào cần migrate sang system mới:
□ Salary grade / pay bands
□ Leave policy (ngày phép theo loại, theo nhóm)
□ Overtime policy
□ Benefit package definitions
```

### Bước 7: Đánh giá Migration Risks

```
Migration risk assessment theo mức độ:

CRITICAL (phải resolve trước khi migrate):
□ Dữ liệu payroll history dưới RED threshold
□ Nhân viên active nhưng thiếu thông tin bắt buộc (CCCD, tài khoản ngân hàng)
□ BHXH records không khớp với sổ BHXH
□ Sensitive data (lương, CCCD) không được encrypt trong hệ thống cũ

HIGH (cần plan rõ ràng):
□ Năm payroll history cần migrate là mấy năm? Data format là gì?
□ Custom formulas trong Excel có thể re-create không?
□ Phép dư năm cũ có được carry forward không? Số dư chính xác chưa?

MEDIUM (cần document):
□ Integration với chấm công sẽ thay đổi thế nào?
□ Reporting habits của HR team (các báo cáo quen dùng)
□ Cut-over timing: migrate giữa tháng vs. đầu tháng vs. đầu năm

RECOMMENDED CUT-OVER TIMING:
- Lý tưởng nhất: đầu năm tài chính (tháng 1) hoặc đầu quý
- Tránh: giữa tháng lương đang chạy
- Cần: parallel run ít nhất 1 kỳ lương trước khi go-live
```

### Bước 8: Output

```
Ghi vào: .mc-data/docs/phase1-business/hr-as-is-analysis.md

Cấu trúc output:
1. Executive Summary
   - Tổng quan hệ thống HR hiện tại
   - Top 3 vấn đề cấp bách nhất
   - Recommendation (replace / upgrade / enhance)

2. System Inventory
   - Bảng các tool hiện tại
   - Integration map

3. Data Quality Assessment
   - Scorecard (GREEN/YELLOW/RED) theo từng loại data
   - Data cleanup effort estimate

4. Payroll Accuracy Review
   - Kết quả kiểm tra
   - Các lỗi phát hiện (nếu có)

5. Compliance Gaps
   - Labor law gaps
   - BHXH reporting gaps
   - Tax compliance gaps
   - Data privacy gaps

6. Migration Risk Register
   - Risk list (CRITICAL / HIGH / MEDIUM)
   - Recommended mitigation

7. Recommendations
   - Ưu tiên data cleanup trước migrate
   - Proposed cut-over timeline
   - Parallel run plan
```

---

## Checklist trước khi submit

```
□ Tất cả hệ thống HR hiện tại đã được inventory
□ Data quality đã scored theo từng category
□ Payroll accuracy đã verify bằng sample check
□ BHXH / PIT compliance gaps đã identified
□ Sensitive data protection gaps đã noted
□ Migration risks đã phân loại CRITICAL / HIGH / MEDIUM
□ Recommended timeline và parallel run plan đã có
□ Output path chính xác: .mc-data/docs/phase1-business/hr-as-is-analysis.md
```
