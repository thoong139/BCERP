# Enterprise Risk Management - Risk Controls & Treatment

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 31000:2018, COSO ERM 2017, IRM Control Framework

---

## 1. Risk Treatment Options (ISO 31000)

### Overview
Risk treatment là việc chọn và implement options để modify risk. Có 5 options:

### Option 1: Avoid (Tránh né)
- **Định nghĩa**: Không tham gia hoặc thoát khỏi hoạt động tạo ra rủi ro
- **Khi nào dùng**: Risk score quá cao, không có treatment khả thi, hoặc residual risk > risk appetite
- **Ví dụ**: Không triển khai vào thị trường mới vì rủi ro regulatory quá cao; thoái vốn khỏi business line
- **Lưu ý**: Cũng đồng thời mất cơ hội tiềm năng — cần cân nhắc kỹ

### Option 2: Reduce / Mitigate (Giảm thiểu)
- **Định nghĩa**: Implement controls để giảm likelihood và/hoặc impact
- **Khi nào dùng**: Most common option — khi risk đáng pursue nhưng cần kiểm soát
- **Reduce likelihood**: Training, process improvement, access controls, system redundancy
- **Reduce impact**: Insurance, diversification, BCP/DRP, contingency funds
- **Ví dụ**: Implement MFA để giảm likelihood của unauthorized access

### Option 3: Transfer / Share (Chuyển giao)
- **Định nghĩa**: Chuyển một phần hoặc toàn bộ financial consequence cho bên khác
- **Khi nào dùng**: Khi tổ chức không có năng lực quản lý risk tốt bằng specialist bên ngoài
- **Công cụ**: Insurance, outsourcing, contracts (bao gồm SLA với penalties), hedging (financial risks)
- **Lưu ý**: Transfer không eliminate risk — reputational risk vẫn thuộc về tổ chức; nghĩa vụ pháp lý không transfer được

### Option 4: Accept (Chấp nhận)
- **Định nghĩa**: Conscious decision giữ nguyên risk mà không có additional treatment
- **Khi nào dùng**: Risk score trong risk appetite; cost of treatment > potential loss; treatment không khả thi
- **Yêu cầu bắt buộc**: Documented decision với justification + authorized approval + review date
- **Không được**: Accept risk mà không ghi chép — đây là "unknowing acceptance" = lỗi governance

### Option 5: Exploit (Khai thác — cho Positive Risks / Opportunities)
- **Định nghĩa**: Tăng likelihood của opportunity hoặc maximize upside
- **Khi nào dùng**: Khi "risk" là positive (opportunity) — áp dụng risk management cho upside
- **Ví dụ**: Tăng investment vào technology khi thấy early mover advantage
- **Lưu ý**: ISO 31000 bao gồm cả positive risks (opportunities) không chỉ negative risks

---

## 2. Control Design Principles

### 2a. Control Types by Function

| Type | Mục đích | Ví dụ | Timing |
|------|---------|-------|--------|
| **Preventive** | Ngăn ngừa risk xảy ra | Access controls, segregation of duties, training | Trước khi risk xảy ra |
| **Detective** | Phát hiện risk khi xảy ra hoặc sau đó | Monitoring, audits, reconciliations, alarms | Trong hoặc sau khi xảy ra |
| **Corrective** | Giảm impact và restore sau khi risk xảy ra | BCP activation, data recovery, incident response | Sau khi xảy ra |
| **Directive** | Hướng dẫn hành vi đúng | Policies, procedures, training | Ongoing |

Best practice: Có đủ bộ Preventive + Detective + Corrective cho mỗi significant risk.

### 2b. Control Types by Nature

| Type | Mô tả | Ưu điểm | Nhược điểm |
|------|-------|---------|-----------|
| **Manual** | Con người thực hiện | Flexible, judgment-based | Human error, inconsistent, không scale |
| **Automated** | System thực hiện | Consistent, real-time, scalable | Setup cost, system dependency |
| **Semi-automated** | Combination: system flag, human review | Balance flexibility và consistency | Cần clear human decision rules |

**Rule of thumb**: Ưu tiên automated controls cho high-volume, routine processes; manual controls cho judgment-based decisions.

### 2c. Key Control vs Supporting Control

| | Key Control | Supporting Control |
|-|------------|-------------------|
| **Định nghĩa** | Control cần thiết để risk không exceed tolerance | Control hỗ trợ, backup cho key control |
| **Testing frequency** | Cao hơn (quarterly/semi-annual) | Thấp hơn (annual) |
| **Failure impact** | Nghiêm trọng — risk lên trên appetite | Moderate — key control vẫn work |
| **Resource focus** | Ưu tiên resources cho testing, maintenance | Second priority |

### 2d. Control Effectiveness Rating

| Rating | Định nghĩa | Residual risk implication |
|--------|-----------|--------------------------|
| **Effective** | Control designed và operating đúng, ngăn/phát hiện risk reliably | Residual = Inherent × 0.2-0.4 (70-80% reduction) |
| **Partially Effective** | Control có gaps: design ok nhưng không follow, hoặc không đủ frequency | Residual = Inherent × 0.5-0.7 (30-50% reduction) |
| **Ineffective** | Control không work: design sai, không thực hiện, bypass | Residual ≈ Inherent (minimal reduction) |
| **Not Tested** | Chưa có evidence về effectiveness | Assume ineffective until proven otherwise |

---

## 3. Risk Ownership Matrix

### Definitions

| Role | Trách nhiệm | Accountability |
|------|-------------|----------------|
| **Risk Owner** | Chịu trách nhiệm quản lý và treat risk; có authority và resources để action | Primary — nếu risk materializes, Risk Owner phải giải trình |
| **Control Owner** | Chịu trách nhiệm design, operation, và maintenance của specific control | Operational — nếu control fails, Control Owner giải trình |
| **Risk Manager** | Facilitate identification, scoring, reporting; không own individual risks | Framework + oversight |
| **Accountable Executive** | Chịu trách nhiệm cuối cùng trước Board cho risk category | Strategic |

### RACI per Risk Activity

| Activity | Risk Owner | Control Owner | Risk Manager | CRO | Internal Audit |
|----------|:----------:|:-------------:|:------------:|:---:|:--------------:|
| Identify risk | A/R | I | C | I | I |
| Score risk (inherent) | C | I | R | A | I |
| Design control | C | A/R | C | I | I |
| Operate control | I | A/R | I | I | I |
| Test control effectiveness | I | C | R | A | A/R |
| Update residual risk | R | C | A | I | I |
| Approve risk acceptance | C | I | R | A/R | I |
| Escalate to Board | I | I | C | R | C |

(A = Accountable, R = Responsible, C = Consulted, I = Informed)

### Assignment Rules
- Mỗi risk có đúng 1 Risk Owner (không được để trống hoặc assign cho nhóm chung chung)
- Risk Owner phải có authority để action (budget, headcount)
- Control Owner có thể khác Risk Owner — Control Owner là người vận hành control hàng ngày
- Không thể self-test: Control Owner không tự test control của mình (3rd line tests)

---

## 4. Control Testing

### Testing Frequency by Risk Level

| Risk Level (Residual) | Testing Frequency | Type of Testing |
|----------------------|-------------------|-----------------|
| **Critical (20-25)** | Quarterly | Full test + continuous monitoring |
| **High (13-19)** | Semi-annual | Full test |
| **Medium (7-12)** | Annual | Representative sample |
| **Low (1-6)** | Every 2 years | Annual walkthrough sufficient |

### Test Procedures

| Procedure | Mô tả | Phù hợp cho |
|-----------|-------|-------------|
| **Inquiry** | Hỏi control owner về cách control hoạt động | Hiểu control design, không đủ làm evidence |
| **Observation** | Quan sát control được thực hiện thực tế | Manual controls, process controls |
| **Inspection** | Xem xét documents, logs, records | Automated controls, approval records |
| **Re-performance** | Tự thực hiện lại control để verify kết quả | Highest confidence; calculations, reconciliations |

**Best practice**: Sử dụng kết hợp ít nhất 2 procedures cho Key Controls.

### Exception Reporting
- **Definition**: Trường hợp control không được thực hiện đúng (exception to the control)
- **Exception rate**: Số exceptions / Tổng số transactions tested × 100%
- **Thresholds**: Critical controls: 0% exception; High: <2%; Medium: <5%
- **Actions khi breach**: Investigate root cause, escalate, determine control still effective?

---

## 5. Action Plan Management

### SMART Format cho Risk Action Plans

```
RISK ACTION PLAN

Risk ID: [RISK-XXXX]
Action ID: [ACT-XXXX]
Action description: [Specific, concrete action — không chung chung]
  SMART checklist:
  S (Specific): Hành động cụ thể là gì?
  M (Measurable): Làm sao biết đã xong? Metric là gì?
  A (Achievable): Có resources không?
  R (Relevant): Action này giảm risk như thế nào?
  T (Time-bound): Deadline cụ thể là ngày nào?

Owner: [Tên + chức danh — đích danh, không phải department]
Deadline: [DD/MM/YYYY]
Expected outcome: [Residual risk score sau khi action complete]
Resources required: [Budget, headcount, tools]
Progress: [Not started / In progress / Complete / Overdue]
Last updated: [Date] by [Who]
```

### 90-Day Action Plan Template

```markdown
## 90-Day Risk Action Plan — [Risk Register Extract]

Prepared by: [Risk Manager]  |  Period: [Start] → [End]  |  Review: [Risk Committee ngày...]

### Critical / High Priority Actions (Complete trong 30 ngày)
| # | Risk ID | Action | Owner | Deadline | Status |
|---|---------|--------|-------|----------|--------|
| 1 | | | | | |

### Medium Priority Actions (Complete trong 90 ngày)
| # | Risk ID | Action | Owner | Deadline | Status |
|---|---------|--------|-------|----------|--------|
| 1 | | | | | |

### Review Meeting Schedule
- Week 2: Check-in với high priority owners
- Week 4: Monthly risk committee — full review
- Week 8: Mid-period update
- Week 12: 90-day close-out review
```

### Tracking và Escalation cho Overdue Actions

| Overdue duration | Action |
|-----------------|--------|
| **1-7 ngày** | Automated reminder email cho Owner |
| **8-14 ngày** | Risk Manager contact Owner directly |
| **15-30 ngày** | Escalate lên Risk Owner's manager |
| **>30 ngày** | Report lên Risk Committee với explanation; xem xét change owner |
| **>60 ngày** (Critical risk) | Escalate lên CRO và CEO |
