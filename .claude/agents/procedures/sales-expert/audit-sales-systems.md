# Playbook: Audit Existing Sales Systems

> **Type**: Agent Skill Playbook
> **Agent**: sales-expert
> **Triggered by**: /wf-legacy-scan khi có CRM/sales system hiện có
> **Output**: `.mc-data/docs/phase1-business/sales-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống CRM hoặc sales tools
- Khi cần đánh giá current state trước khi thiết kế lại
- Khi cần tìm data migration risks và process gaps

---

## Procedure

### Bước 1: Inventory công cụ và dữ liệu hiện có

```
Thu thập từ stakeholders hoặc codebase/config files:

CRM & Sales Tools:
□ CRM đang dùng: Salesforce, HubSpot, Pipedrive, Zoho, hay in-house?
□ Quản lý opportunity ở đâu? (CRM, Excel, hay phần mềm khác?)
□ Quotation tool: CRM built-in, phần mềm riêng, hay Excel?
□ Commission tracking: Automated hay tính tay (Excel/Google Sheet)?
□ Sales reporting: Tự build hay BI tool? Frequency?

Tích hợp hiện tại:
□ CRM ↔ Email (Gmail/Outlook sync?)
□ CRM ↔ Marketing (lead handoff đang dùng gì?)
□ CRM ↔ Finance/ERP (invoice tạo tự động hay manual?)
□ CRM ↔ Inventory (check stock khi quote?)
```

### Bước 2: Đánh giá chất lượng dữ liệu

```
READ: operations.md → Data quality standards

Leads & Contacts:
□ Tổng số leads/contacts trong hệ thống
□ % leads có đầy đủ thông tin (email, phone, company)
□ Duplicate rate ước tính (lead/contact trùng)
□ Lead source có được track không? % không có source?
□ Dữ liệu cũ (> 2 năm không có activity): có cần clean không?

Opportunities:
□ Tổng số open opportunities
□ % cơ hội có close date + amount (cần thiết cho forecasting)
□ Stale opportunities (không có activity > 30 ngày): bao nhiêu?
□ Stage distribution: Có bị tắc ở stage nào không? (bottleneck signal)
□ Pipeline có "dead wood" không? (deals cũ chưa close/lose)

Commission Records:
□ Commission history có không? Format gì?
□ Tính tay hay tự động? Dễ sai không?
□ Dispute history có ghi nhận không?
```

### Bước 3: Process Gaps Analysis

```
READ: operations.md → Sales process best practices

Lead Management:
□ Có SLA response time cho new lead không? Đang đạt không?
□ Lead qualification criteria rõ ràng chưa? (BANT/MEDDPICC)
□ Handoff từ Marketing sang Sales: Có friction không?
□ Lead recycling khi rep không follow up?

Pipeline Management:
□ Pipeline stages có được rep dùng nhất quán không?
□ Deal review cadence: Có weekly pipeline review không?
□ Forecast submission: Có commit discipline không?
□ Win/Loss analysis: Có review regularly không?

Quotation Process:
□ Quote turnaround time trung bình là bao lâu?
□ Có approval workflow không? Đang bypass không?
□ Quote version control: Khách hàng nhận quote nào là mới nhất?
□ Discount control: Ai có quyền approve? Có track không?
```

### Bước 4: Reporting Gaps

```
READ: pipeline-analytics.md → Key metrics

Metrics đang có vs cần có:

| Metric               | Đang có? | Cách tính? | Độ tin cậy |
|----------------------|----------|------------|------------|
| Win rate             | ?        | ?          | ?          |
| Average sales cycle  | ?        | ?          | ?          |
| Pipeline velocity    | ?        | ?          | ?          |
| Quota attainment %   | ?        | ?          | ?          |
| Commission accuracy  | ?        | ?          | ?          |
| Forecast accuracy    | ?        | ?          | ?          |

Với mỗi metric: ghi rõ đang tính thủ công hay tự động, nguồn dữ liệu
```

### Bước 5: Integration Health

```
Kiểm tra từng integration điểm:

Marketing → CRM:
□ Leads từ marketing form có auto-create trong CRM không?
□ UTM/source data có theo sang CRM không?
□ Duplicate detection khi lead đã có trong CRM?

CRM → Finance:
□ Closed-won deal có auto-tạo invoice/PO không?
□ Hay phải manual entry vào ERP?
□ Revenue recognition có nhất quán không?

Commission → Payroll:
□ Commission tính xong có export được cho Payroll không?
□ Sai số trước đây có không? (dẫn đến dispute)
```

### Bước 6: Migration Risks

```
Xác định rủi ro khi migrate:

Data Risks:
□ Custom fields không có trong hệ thống mới → mapping plan?
□ Relationship data (contact ↔ opportunity ↔ account) có intact không?
□ Historical activity logs: Migrate hay archive?
□ Commission history: Cần migrate đầy đủ để avoid disputes

Process Risks:
□ Rep quen với UI cũ → change management cần không?
□ Pipeline stages khác nhau → deal mapping strategy?
□ Open deals trong migration window: Ai chịu trách nhiệm?

Timeline Risks:
□ End-of-quarter migration: Tránh nếu có thể (forecast disruption)
□ Commission period cutover: Cần rõ ràng ngày nào chuyển hệ thống
```

### Bước 7: Output — As-Is Analysis Report

```markdown
# Sales System As-Is Analysis

## Executive Summary
[3-5 dòng: tổng quan health của hệ thống, strengths, critical gaps]

## Current Tools Inventory
[Table: Tool | Purpose | Users | Health | Issues]

## Data Quality Assessment
[Table: Data type | Volume | Completeness | Accuracy | Action needed]

## Process Gaps
### Critical (block operations)
- [Gap]: [Impact] → [Recommendation]

### Important (reduce efficiency)
- [Gap]: [Impact] → [Recommendation]

## Reporting Gaps
[Table: Metric | Currently available? | Quality | Notes]

## Integration Health
[Table: Integration | Status | Issues | Priority]

## Migration Risks & Recommendations
[Table: Risk | Severity | Mitigation]

## Priority Recommendations
1. [Highest impact] — Effort: [X], Impact: [Y]
2. ...

## Data Cleansing Needs Before Migration
[List specific cleansing tasks với estimated effort]
```

---

## Checklist trước khi submit

```
□ Inventory đầy đủ tất cả CRM/sales tools đang dùng
□ Data quality issues đã documented (duplicates, missing fields)
□ Process gaps đã prioritize theo impact
□ Integration health đã check từng điểm
□ Migration risks đã identify với severity
□ Data cleansing tasks đã estimate
□ Commission history migration plan đã ghi nhận
```
