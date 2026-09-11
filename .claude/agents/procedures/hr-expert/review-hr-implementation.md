# Playbook: Review HR Implementation

> **Type**: Agent Skill Playbook
> **Agent**: hr-expert
> **Triggered by**: Post-implementation review sau /wf-implement-feature cho HR modules
> **Output**: HR implementation review report

---

## Khi nào dùng playbook này

- Sau khi developer hoàn tất implementation HR module
- Khi code-reviewer cần domain review từ HR perspective
- Trước khi UAT với HR team thực tế
- Khi có change request ảnh hưởng đến payroll / compliance

---

## Procedure

### Bước 1: Đọc context implementation

```
INPUT: Paths do skill cung cấp qua prompt
Đọc:
□ Implementation report / PR description
□ REQ-HR-* requirements từ phase1-business/hr-requirements.md
□ Feature specs từ phase2-features/hr/
□ Code files được implement (nếu có quyền đọc)

READ: controls.md (Section 1, 2, 4, 5)
READ: operations.md (Process 4 — Payroll, để cross-check)

Xác định scope review:
□ Module(s) nào đã implement: Recruitment / Payroll / Leave / Performance / Training?
□ REQ-IDs nào được implement trong sprint này?
□ Có thay đổi gì so với spec ban đầu không?
```

### Bước 2: Kiểm tra Requirements Coverage

```
Với mỗi REQ-HR-* trong sprint này:

□ Feature đã implement đủ acceptance criteria chưa?
□ Edge cases trong spec có được handle không?
□ Có feature nào implement thêm ngoài spec (scope creep) không?

Tạo coverage matrix:
| REQ-ID | Feature | Implemented | Tested | Gap |
|--------|---------|-------------|--------|-----|
| REQ-HR-PAY-001 | Payroll calculation | ✅/❌ | ✅/❌ | ... |
| REQ-HR-PAY-002 | PIT withholding | ✅/❌ | ✅/❌ | ... |
```

### Bước 3: Kiểm tra Payroll Calculation Accuracy

```
Đây là phần quan trọng nhất — sai số tiền nghĩa là sai pháp lý.

TEST SCENARIOS bắt buộc phải verify:

BHXH Calculation:
□ Nhân viên lương 10tr → BHXH = 10tr × 10.5% = 1.050.000 đúng không?
□ Nhân viên lương 50tr → BHXH tính trên mức trần hay tổng lương?
  (Nếu mức trần BHXH là 36tr/tháng × 20 = 720tr/năm → cap ở mức này)
□ Nhân viên mới tháng này → BHXH tính từ tháng nào?
□ Nhân viên nghỉ việc giữa tháng → BHXH tính thế nào?

PIT Calculation (7 bậc lũy tiến):
□ Test case bậc 1: Thu nhập tính thuế = 4tr → PIT = 200.000 đúng không?
□ Test case cross-bracket: TNT = 12tr → PIT = (5tr × 5%) + (5tr × 10%) + (2tr × 15%) = 1.050.000
□ Người phụ thuộc: TNT giảm 4.4tr/người, đăng ký tháng 3 → chỉ áp dụng từ tháng 3
□ Non-resident: 20% flat, không có giảm trừ gia cảnh
□ Quyết toán năm: tổng thuế đã tạm khấu trừ vs. thuế thực tế

Overtime Calculation:
□ Ngày thường OT 2h lương giờ 50.000đ → 2h × 50.000 × 1.5 = 150.000
□ Cuối tuần OT → hệ số 2.0
□ Ngày lễ OT → hệ số 3.0
□ Lương giờ = Lương tháng / (Số ngày chuẩn × 8h) — công thức đúng không?

Year-end edge cases:
□ Nhân viên vào tháng 7, làm 6 tháng → quyết toán tính đủ năm không?
□ Thưởng Tết (tháng 13) → có tính vào PIT năm trả thưởng không?
```

### Bước 4: Kiểm tra BHXH Formula Verification

```
BHXH monthly report verification:

□ File D02-LT generate được không? Format đúng chuẩn BHXH không?
□ Danh sách đóng BHXH có đúng số người active không?
□ Mức đóng có theo lương hợp đồng (không phải lương thực nhận sau khấu trừ)?
□ Nhân viên mới tháng này: có trong D02-LT không?
□ Nhân viên nghỉ việc: có được remove đúng kỳ không?

Tình huống đặc biệt:
□ Thai sản: công ty dừng đóng BHXH, BHXH cơ quan trả thay — có handle không?
□ Ốm dài ngày: tương tự thai sản
□ Nhân viên làm 2 công ty: BHXH chỉ đóng ở 1 nơi — có cảnh báo không?
```

### Bước 5: Kiểm tra Access Control

```
READ: controls.md (Section 1 — Data Access Control Matrix)

Verify theo Access Matrix:

EMPLOYEE SELF-SERVICE:
□ Employee chỉ thấy payslip của mình → không thấy của người khác
□ Employee xem được số dư phép → không sửa được
□ Employee không thấy salary của đồng nghiệp
□ Employee không thấy performance review của người khác

MANAGER VIEW:
□ Manager chỉ thấy team trực tiếp của mình → không thấy team khác
□ Manager approve/reject leave của team mình
□ Manager KHÔNG thấy salary cụ thể (chỉ thấy budget tổng nếu có)
□ Manager không approve salary change (chỉ HR Manager)

HR ADMIN:
□ HR Admin tạo được employee record
□ HR Admin KHÔNG approve salary change (SoD violation)
□ HR Admin generate được payroll nhưng KHÔNG approve được

HR MANAGER:
□ HR Manager approve salary change, payroll, employee status
□ HR Manager KHÔNG process payroll (SoD violation)

Test: dùng tài khoản từng role → verify không có unauthorized access
```

### Bước 6: Kiểm tra Audit Trail

```
READ: controls.md (Section 5 — Audit Trail Requirements)

Verify audit logging:
□ Employee create: có log user_id, timestamp, tất cả fields?
□ Salary change: có log old_value → new_value + approver?
□ Payroll run: có log ai run, khi nào, kết quả?
□ Login vào payroll data: có log không?
□ Payslip export/download: có log không?

Audit log quality:
□ Không thể delete hoặc edit audit log
□ Timestamp là UTC (không phải local time)
□ User ID là immutable ID (không phải tên đăng nhập có thể đổi)
□ Log format có thể export để báo cáo compliance audit?

Retention check:
□ Salary change logs: giữ ít nhất 10 năm
□ Employee changes: giữ ít nhất 7 năm sau khi nghỉ việc
□ Access logs: giữ ít nhất 3 năm
```

### Bước 7: Kiểm tra Data Encryption

```
Sensitive data encryption verification:

□ Salary data: có encrypt at rest không? (không lưu plain text trong DB)
□ CCCD / Tax ID: có encrypt không?
□ Bank account number: có encrypt không?
□ API response: salary fields có bị masked không? (trả về "***" ngoại trừ khi cần thiết)
□ Logs: salary/CCCD/bank account có bị redacted trong logs không?
□ Database backup: có encrypt backup file không?

Transport security:
□ Tất cả API calls có dùng HTTPS không?
□ Bank transfer file export: có secure channel không?

Test: query DB trực tiếp → salary column có phải ciphertext không?
```

### Bước 8: Kiểm tra User Experience (HR Perspective)

```
Practical usability từ góc nhìn HR team:

PAYROLL WORKFLOW:
□ Payroll run có step-by-step guidance không?
□ Exception report có rõ ràng không? (ai sai, sai gì, cần action gì)
□ Có thể adjust từng dòng trước khi approve không?
□ Có confirm dialog trước khi lock payroll không?

LEAVE MANAGEMENT:
□ Nhân viên xin nghỉ trên mobile được không?
□ Manager nhận notification ngay khi có đơn không?
□ Leave calendar team có hiển thị được không?

RECRUITMENT:
□ Recruiter move candidate giữa stages có dễ không?
□ Bulk reject có không?
□ Email template cho candidate tự động gửi khi stage thay đổi?
```

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/hr-implementation-review-[sprint].md

Cấu trúc output:
1. Review Summary
   - Sprint / PR / Feature được review
   - Overall assessment: PASS / CONDITIONAL PASS / FAIL

2. Requirements Coverage
   - Coverage matrix (REQ-ID → implemented / gap)

3. Payroll Accuracy Findings
   - Test cases ran
   - Kết quả: PASS / FAIL + chi tiết nếu FAIL
   - Critical bugs (nếu có)

4. BHXH Verification
   - Kết quả verify
   - Gaps (nếu có)

5. Access Control Findings
   - Role-based access: PASS / FAIL per role
   - SoD violations found (nếu có)

6. Audit Trail Assessment
   - Coverage
   - Gaps

7. Data Security
   - Encryption status
   - Issues found

8. UX Observations (HR perspective)
   - Usability issues cần fix
   - Nice-to-have improvements

9. Action Items
   - BLOCKER: phải fix trước go-live
   - MAJOR: cần fix trong sprint tiếp theo
   - MINOR: backlog
```

---

## Checklist trước khi submit

```
□ Payroll test cases đã chạy đủ (BHXH, PIT 7 bậc, OT, year-end)
□ Access control đã test từng role theo Access Matrix
□ SoD violations đã kiểm tra (HR Admin không approve, HR Manager không process)
□ Audit trail đã verify (log đầy đủ, không thể xóa)
□ Sensitive data encryption đã verify tại DB level
□ BHXH report file format đã check
□ Action items đã phân loại BLOCKER / MAJOR / MINOR
□ Overall assessment rõ ràng: PASS / CONDITIONAL PASS / FAIL
```
