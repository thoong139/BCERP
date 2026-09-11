# Compliance - User Personas

> **Domain**: Compliance / Tuân thủ & Kiểm soát Nội bộ
> **Last Updated**: 2026-03-19

---

## Persona 1: Compliance Officer

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Chief Compliance Officer / Compliance Officer |
| **Experience** | 8-15 năm |
| **Report to** | CEO / Board of Directors / Audit Committee |
| **Focus** | Regulatory adherence, compliance program management, board reporting |

### Daily Tasks
1. Giám sát tuân thủ quy định pháp luật và chính sách nội bộ trên toàn doanh nghiệp
2. Review và xử lý các incidents và vi phạm được báo cáo qua compliance hotline
3. Theo dõi thay đổi pháp lý mới từ các cơ quan quản lý (bộ, ban ngành)
4. Phối hợp với các phòng ban để triển khai chính sách và quy trình tuân thủ
5. Chuẩn bị báo cáo tuân thủ định kỳ cho Ban giám đốc và Ủy ban kiểm toán

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phê duyệt chính sách tuân thủ nội bộ | Approve | Regulatory requirements, risk assessment |
| Khai báo vi phạm với cơ quan quản lý | Approve | Incident details, legal counsel input |
| Phân bổ ngân sách cho compliance program | Recommend | Budget request, risk priority matrix |
| Xác định mức độ ưu tiên kiểm tra audit nội bộ | Approve | Risk register, audit schedule |

### Pain Points
- Yêu cầu pháp lý thay đổi liên tục và không theo chu kỳ dự đoán được, gây khó khăn trong cập nhật chính sách
- Thiếu visibility thực thời vào mức độ tuân thủ của từng phòng ban — phụ thuộc vào báo cáo thủ công
- Khó lấy sign-off và acknowledgment từ các nhân viên với số lượng lớn trong thời hạn yêu cầu

### Must-have Features
- Compliance dashboard hiển thị trạng thái tuân thủ theo phòng ban và regulation
- Regulatory change tracking với impact assessment workflow
- Policy acknowledgment tracking với deadline alerts tự động

---

## Persona 2: Internal Auditor

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Internal Auditor / Senior Internal Auditor |
| **Experience** | 4-10 năm |
| **Report to** | Head of Internal Audit / Audit Committee |
| **Focus** | Audit plan execution, control gap identification, remediation tracking |

### Daily Tasks
1. Thực hiện kiểm tra kiểm soát nội bộ theo audit plan hàng năm
2. Thu thập và phân tích evidence cho từng control được kiểm tra
3. Phỏng vấn process owner để hiểu thiết kế và vận hành của controls
4. Ghi chép phát hiện audit (findings) và phân loại mức độ nghiêm trọng
5. Theo dõi tiến độ remediation của các findings từ audit trước

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phân loại mức độ finding (Critical / High / Medium / Low) | Execute | Evidence, impact analysis, control standards |
| Xác định scope mở rộng khi phát hiện vấn đề bất thường | Execute | Preliminary findings, risk threshold |
| Đề xuất remediation action cho control gap | Recommend | Root cause analysis, control design options |
| Đánh giá control là Effective / Partially Effective / Ineffective | Execute | Testing evidence, sample results |

### Pain Points
- Thu thập evidence từ nhiều hệ thống khác nhau, định dạng không đồng nhất, mất nhiều thời gian xử lý thủ công
- Audit findings tồn đọng lâu do process owner chậm thực hiện remediation — thiếu escalation tự động
- Khó duy trì audit trail đầy đủ khi làm việc với tài liệu giấy hoặc email

### Must-have Features
- Audit management system với work paper, evidence attachment và sign-off workflow
- Finding tracker với deadline, owner assignment và escalation alert
- Traceability từ control → test procedure → evidence → finding

---

## Persona 3: Risk Manager

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Enterprise Risk Manager / Risk Officer |
| **Experience** | 6-12 năm |
| **Report to** | CRO / CFO / CEO |
| **Focus** | Enterprise risk assessment, risk register maintenance, C-suite risk reporting |

### Daily Tasks
1. Cập nhật risk register khi có sự kiện mới hoặc thay đổi trong môi trường kinh doanh
2. Đánh giá rủi ro mới từ các phòng ban và phân loại theo ma trận likelihood × impact
3. Theo dõi Key Risk Indicators (KRIs) và phát hiện tín hiệu vượt ngưỡng cảnh báo
4. Phối hợp với business owners để xác định và giám sát các risk controls
5. Chuẩn bị báo cáo rủi ro định kỳ cho C-suite và Hội đồng quản trị

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phân loại risk rating (Critical / High / Medium / Low) | Execute | Likelihood score, impact score, risk matrix |
| Xác định risk response (Accept / Mitigate / Transfer / Avoid) | Recommend | Risk cost-benefit, risk appetite statement |
| Escalate risk lên Steering Committee | Execute | Risk threshold breach evidence |
| Approve risk acceptance waiver | Approve | Risk details, residual risk level, business justification |

### Pain Points
- Thiếu dữ liệu thực thời để cập nhật risk scoring — phụ thuộc vào email và cuộc họp định kỳ
- Risk register thường là spreadsheet, khó maintain khi số lượng risks lớn và nhiều người cùng chỉnh sửa
- Khó thể hiện mối liên hệ giữa các risks và giữa risks với controls trong reporting

### Must-have Features
- Risk register với version history, owner assignment và automated KRI monitoring
- Heat map visualization (likelihood × impact) với drill-down vào risk details
- Risk-control linkage map cho C-suite reporting

---

## Persona 4: Data Protection Officer (DPO)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Data Protection Officer |
| **Experience** | 5-10 năm |
| **Report to** | CEO / Legal Director (independence required by GDPR/Decree 13) |
| **Focus** | GDPR/Decree 13 compliance, data processing oversight, data subject rights |

### Daily Tasks
1. Xử lý yêu cầu từ data subjects (quyền truy cập, xóa dữ liệu, chỉnh sửa, di chuyển)
2. Đánh giá Data Protection Impact Assessment (DPIA) cho các dự án xử lý dữ liệu mới
3. Giám sát mục đích và cơ sở pháp lý của các hoạt động xử lý dữ liệu cá nhân
4. Báo cáo và quản lý data breach incidents theo thời hạn pháp lý (72 giờ theo GDPR)
5. Tư vấn nội bộ về privacy requirements cho các dự án IT và business mới

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phê duyệt DPIA cho project mới | Approve | Processing activity details, risk assessment |
| Xác định có cần khai báo data breach lên cơ quan quản lý | Approve | Breach scope, data category, affected persons count |
| Chấp thuận hoặc từ chối data subject request | Execute | Request details, legal grounds for processing |
| Chấp thuận contract điều khoản xử lý dữ liệu (DPA) với third parties | Approve | Contract terms, processor activities |

### Pain Points
- Data subject requests đến qua nhiều kênh (email, form, hotline) — thiếu tập trung và theo dõi SLA
- Thiếu inventory đầy đủ về nơi dữ liệu cá nhân được lưu trữ và ai đang xử lý
- Khó chứng minh accountability khi cần: consent records, processing basis phân tán nhiều hệ thống

### Must-have Features
- Data subject request portal với SLA tracking (30 ngày theo GDPR / Decree 13)
- Records of Processing Activities (RoPA) management với data inventory map
- Consent management platform với audit trail đầy đủ

---

## Persona 5: Compliance Analyst

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Compliance Analyst / Compliance Specialist |
| **Experience** | 1-4 năm |
| **Report to** | Compliance Officer / Compliance Manager |
| **Focus** | Daily monitoring, incident reporting, policy administration, data collection |

### Daily Tasks
1. Theo dõi transactions bất thường và cảnh báo từ compliance monitoring tools
2. Nhận và log các vi phạm hoặc câu hỏi từ nhân viên qua compliance hotline/email
3. Cập nhật compliance checklists và tracking spreadsheets hàng ngày
4. Hỗ trợ chuẩn bị tài liệu cho các cuộc audit nội bộ và bên ngoài
5. Gửi nhắc nhở policy training completion đến các phòng ban chưa hoàn thành

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Phân loại incident ban đầu (minor / major) | Execute | Incident description, policy reference |
| Escalate incident lên Compliance Officer | Execute | Incident details, initial classification |
| Xác nhận nhân viên hoàn thành training requirement | Execute | Training completion records |
| Đánh dấu compliance checklist item là Pass / Fail / N/A | Execute | Evidence, control standard |

### Pain Points
- Phần lớn công việc monitoring là thủ công — xem xét log, copy-paste vào spreadsheet
- Không có workflow rõ ràng khi phát hiện incident: ai cần biết, trong bao lâu, qua kênh nào
- Khó cập nhật kiến thức về quy định mới khi tài liệu tham khảo phân tán

### Must-have Features
- Automated transaction monitoring với alert queue có thể assign và escalate
- Incident management form với guided workflow và mandatory fields
- Compliance calendar với reminder tự động cho deadlines pháp lý

---

## Quick Reference: Access Matrix

| Data / Function | Compliance Officer | Internal Auditor | Risk Manager | DPO | Compliance Analyst |
|-----------------|:-----------------:|:----------------:|:------------:|:---:|:-----------------:|
| View compliance dashboard | ✅ | ✅ | ✅ | ⚠ Privacy scope | ✅ |
| Create/edit policy | ✅ | ❌ | ❌ | ⚠ Privacy policies | ❌ |
| Approve policy | ✅ | ❌ | ❌ | ⚠ Privacy scope | ❌ |
| View audit findings | ✅ | ✅ | ✅ | ⚠ Privacy scope | ⚠ Assigned only |
| Create audit finding | ❌ | ✅ | ❌ | ❌ | ❌ |
| View risk register | ✅ | ✅ | ✅ | ⚠ Privacy risks | ⚠ View only |
| Edit risk register | ⚠ Escalated risks | ❌ | ✅ | ⚠ Privacy risks | ❌ |
| Manage data subject requests | ❌ | ❌ | ❌ | ✅ | ❌ |
| Access personal data inventory | ⚠ Read only | ⚠ Audit scope | ❌ | ✅ | ❌ |
| Log compliance incident | ✅ | ❌ | ❌ | ⚠ Privacy breach | ✅ |
| Approve compliance waiver | ✅ | ❌ | ⚠ Risk waivers | ❌ | ❌ |
| View training completion | ✅ | ⚠ Audit scope | ❌ | ❌ | ✅ |
| Export compliance reports | ✅ | ✅ | ✅ | ⚠ Privacy reports | ⚠ Assigned |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional (ghi chú điều kiện) -->
