# Finance User Personas

> Reference file cho finance-expert agent
> Load file này khi cần hiểu về users trong domain Finance

## Danh sách Personas

### 1. Kế toán viên (Accountant)

**Profile:**
- Chức danh: Accountant / Kế toán viên
- Kinh nghiệm: Entry to Mid level (1-5 năm)
- Technical skill: Medium - thoải mái với Excel, phần mềm kế toán
- Tần suất sử dụng hệ thống: Daily (6-8 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Nhập hóa đơn đầu vào | 20-50 cái/ngày | 5-10 phút/hóa đơn | High |
| Kiểm tra & đối soát công nợ | 2 lần/ngày | 30 phút/lần | High |
| Lập payment request | 5-10 cái/ngày | 10 phút/request | High |
| Reconcile bank statement | 1 lần/ngày | 1 giờ | High |
| Tạo journal entries | 10-20 entries/ngày | 5 phút/entry | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Accept invoice discrepancy | Tolerance threshold (±5%) | Payment proceed/hold | Yes - auto-flag discrepancies |
| Code expense to GL account | Nature of expense | Financial reporting accuracy | Yes - suggest based on vendor/history |
| Prioritize payments | Due date, vendor priority | Cash flow, vendor relationship | Yes - aging report with priorities |

**Pain Points:**
1. **Re-entry data**: Phải nhập lại data từ invoice giấy → Excel → ERP
2. **No visibility**: Không biết payment status real-time
3. **Manual reconciliation**: Đối soát thủ công giữa bank statement và system
4. **Version confusion**: Không biết invoice version nào là final

**Must-have Features:**
- OCR/scan invoice để giảm data entry
- Real-time payment status tracking
- Auto-matching bank transactions
- Invoice version control với audit trail

---

### 2. Kế toán trưởng (Chief Accountant)

**Profile:**
- Chức danh: Chief Accountant / Kế toán trưởng
- Kinh nghiệm: Senior level (7+ năm)
- Technical skill: High - am hiểu deep về accounting principles
- Tần suất sử dụng hệ thống: Daily (4-6 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review & approve transactions | 20-30 items/ngày | 3-5 phút/item | High |
| Phê duyệt payment > threshold | 5-10 items/ngày | 10 phút/item | High |
| Kiểm soát cash position | 2 lần/ngày | 15 phút/lần | High |
| Review aging report | 1 lần/ngày | 30 phút | High |
| Month-end close activities | 5 ngày/tháng | Full day | Critical |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Approve/Reject payment request | Cash availability, validity | Cash outflow, vendor relation | Yes - cash forecast dashboard |
| Write off bad debt | Aging, collectibility | P&L impact, tax deduction | Yes - provision calculation |
| Accrual estimates | Historical data, contracts | Accurate period reporting | Yes - accrual templates |

**Pain Points:**
1. **No consolidated view**: Phải mở nhiều reports để có full picture
2. **Approval bottlenecks**: Không delegate được khi vắng mặt
3. **Manual consolidation**: Consolidate manually từ nhiều entities
4. **Slow closing**: Month-end close tốn quá nhiều thời gian

**Must-have Features:**
- Executive dashboard với real-time metrics
- Delegable approval workflow
- Multi-entity consolidation support
- Automated close checklist

---

### 3. CFO / Trưởng phòng Tài chính

**Profile:**
- Chức danh: CFO / Finance Director
- Kinh nghiệm: Executive level (10+ năm)
- Technical skill: High - strategic view, less hands-on
- Tần suất sử dụng hệ thống: Daily review + Weekly deep dive

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review cash position dashboard | 1 lần/ngày | 15 phút | High |
| Approve large payments (>limit) | 2-5 items/tuần | 20 phút/item | High |
| Review financial KPIs | 1 lần/tuần | 1 giờ | High |
| Board reporting preparation | 1 lần/tháng | 4 giờ | Critical |
| Strategic planning support | Ad-hoc | Variable | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Release large payment | Cash forecast, priorities | Liquidity, business continuity | Yes - scenario analysis |
| Adjust budget allocation | Variance analysis, business needs | Resource reallocation | Yes - budget vs actual |
| Financing decisions | Cash gap, cost of capital | Debt/equity mix | Yes - cash forecast models |

**Pain Points:**
1. **Delayed information**: Reports không available khi cần
2. **Drill-down difficulty**: Khó trace từ summary to detail
3. **No forecasting**: Thiếu predictive analytics
4. **Manual board pack**: Phải compile manually từ nhiều sources

**Must-have Features:**
- Real-time executive dashboard
- Drill-down từ summary to transaction level
- Cash flow forecasting với scenarios
- Automated board reporting

---

### 4. Kế toán công nợ phải trả (AP Clerk)

**Profile:**
- Chức danh: AP Accountant / Kế toán công nợ phải trả
- Kinh nghiệm: Entry to Mid level
- Technical skill: Medium
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Process vendor invoices | 30-50 invoices/ngày | 5-10 phút/invoice | High |
| Verify 3-way match | Tất cả invoices | 3 phút/invoice | High |
| Follow up discrepancies | 5-10 cases/ngày | 15 phút/case | High |
| Prepare payment batch | 2 lần/tuần | 1-2 giờ/batch | High |
| Vendor reconciliation | 1 lần/tháng | 2 giờ/vendor | Medium |

**Pain Points:**
1. **Missing PO/GRN**: Invoice đến nhưng chưa có PO hoặc GRN
2. **Duplicate invoices**: Vendor gửi invoice nhiều lần
3. **Currency confusion**: Invoice ngoại tệ, thanh toán VND
4. **Vendor communication**: Track các promises từ vendor

---

### 5. Kế toán công nợ phải thu (AR Clerk)

**Profile:**
- Chức danh: AR Accountant / Kế toán công nợ phải thu
- Kinh nghiệm: Entry to Mid level
- Technical skill: Medium
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Issue sales invoices | 20-30 invoices/ngày | 5 phút/invoice | High |
| Apply customer payments | 10-20 payments/ngày | 3 phút/payment | High |
| Send reminder statements | 1 lần/tuần | 2 giờ | Medium |
| Collection calls | 5-10 calls/ngày | 10 phút/call | High |
| Customer reconciliation | 1 lần/tháng | 1 giờ/customer | Medium |

**Pain Points:**
1. **Payment unidentified**: Customer pay nhưng không rõ cho invoice nào
2. **Dispute resolution**: Customer dispute invoice, tốn thời gian
3. **Credit limit monitoring**: Không biết real-time credit utilization
4. **Dunning efficiency**: Manual reminders không hiệu quả

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Accountant | Transaction accuracy | Error rate, processing time |
| Chief Accountant | Control & compliance | Audit findings, close time |
| CFO | Strategic decisions | Cash position, ROI |
| AP Clerk | Vendor payments | DPO, duplicate rate |
| AR Clerk | Collections | DSO, aging buckets |
