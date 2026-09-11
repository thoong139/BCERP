# Playbook: Thiết kế Budget Management Module

> **Type**: Agent Procedure
> **Agent**: finance-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design module ngân sách
> **Output**: Feature spec cho budget module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Ngân sách" hoặc "Budget Management"
- Khi cần thiết kế budget planning + variance analysis
- Khi project có cost center / department budget control

---

## Procedure

### Bước 1: Đọc requirements và xác định scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .mc-data/docs/phase1-business/finance-requirements.md

Cần xác định:
□ Budget hierarchy level: Company / Department / Project / Cost Center
□ Budget period: Annual / Quarterly / Monthly
□ Budget types: Operating (OPEX) / Capital (CAPEX) / Revenue
□ Approval flow: Ai submit, ai approve, bao nhiêu cấp?
□ Revision policy: Cho phép revise bao nhiêu lần/năm?
□ Có tracking actuals từ GL không? (integration với accounting)
```

### Bước 2: Thiết kế Budget Hierarchy

```
READ: personas.md → CFO, Chief Accountant sections

Hierarchy phổ biến:

Level 1 → Company Budget (tổng công ty)
Level 2 → Department Budget (từng phòng ban)
Level 3 → Cost Center / Project Budget
Level 4 → Account Level (chi tiết theo GL account)

Data model:
BudgetPlan:
  - budget_id, fiscal_year, budget_version
  - name, description
  - budget_type (operating/capital/revenue)
  - status (Draft → Submitted → Approved → Active → Closed)
  - created_by, approved_by, approved_at

BudgetLine:
  - budget_id, department_id, cost_center_id
  - account_code (link tới Chart of Accounts)
  - period (YYYY-MM)
  - amount_planned
  - notes

BudgetRevision:
  - original_budget_id, revision_number
  - reason, requested_by
  - status (Pending → Approved → Rejected)
```

### Bước 3: Thiết kế Budget Period & Approval Workflow

```
READ: controls.md → Section 1: Authorization Matrix

Period types:
□ Annual budget: Lập 1 lần đầu năm tài chính
□ Quarterly reforecast: Điều chỉnh hàng quý
□ Monthly monitoring: So sánh actual vs budget

Approval workflow (top-down):
Dept Head submits dept budget
  → CFO reviews consolidated budget
    → CEO/Board approves annual plan
      → System activates budget controls

Revision workflow:
Dept Head requests revision (kèm reason)
  → Chief Accountant reviews impact
    → CFO approves nếu >5% variance
      → Audit trail ghi revision history
```

### Bước 4: Thiết kế Budget vs Actual Tracking

```
READ: operations.md → Section 6: Operational Metrics

Tracking mechanics:
□ Actual data: Tự động pull từ GL transactions (theo account + period)
□ Committed: Purchase Orders chưa invoiced (encumbrance)
□ Available: Budget - Actual - Committed

Budget Consumption Formula:
Available Budget = Planned - Actual Spent - Committed (PO)

Pre-commitment check (khi tạo PO hoặc expense request):
IF (committed_amount > available_budget) THEN
  → Warning: "Vượt ngân sách X VND"
  → Có thể block hoặc require override approval
```

### Bước 5: Thiết kế Variance Analysis

```
Variance types cần tính:
□ Amount Variance = Actual - Budget (absolute)
□ Percentage Variance = (Actual - Budget) / Budget × 100%
□ YTD Variance: Lũy kế từ đầu năm
□ Forecast vs Budget: Dự báo cuối năm so với kế hoạch

Alert thresholds:
□ Warning: Variance > 10% hoặc > 50M VND
□ Critical: Variance > 20% hoặc > 200M VND
□ Over-budget: Actual > 100% budget

Variance Analysis Report:
| Dept | Account | Budget | Actual | Variance | % | Status |
|------|---------|--------|--------|----------|---|--------|
| Sales | Marketing | 100M | 115M | +15M | +15% | ⚠️ Over |
```

### Bước 6: Feature Spec Output

```markdown
# Feature Spec: Budget Management

## Overview
[Mô tả module và business value cho CFO, Dept Heads]

## User Stories
- As a CFO, I want to see consolidated budget vs actuals...
- As a Dept Head, I want to submit my annual budget...
- As a Chief Accountant, I want to lock budget after approval...

## Functional Requirements

### Budget Planning
REQ-FIN-BUD-001: Tạo và quản lý annual budget plan
REQ-FIN-BUD-002: Top-down budget allocation theo hierarchy
REQ-FIN-BUD-003: Budget import từ Excel template

### Approval Workflow
REQ-FIN-BUD-004: Multi-level approval workflow
REQ-FIN-BUD-005: Budget revision request với reason

### Budget Control
REQ-FIN-BUD-006: Pre-commitment check khi tạo PO/expense
REQ-FIN-BUD-007: Auto-lock khi vượt budget (configurable)

### Tracking & Reporting
REQ-FIN-BUD-008: Real-time Budget vs Actual dashboard
REQ-FIN-BUD-009: Variance analysis report với drill-down
REQ-FIN-BUD-010: Alert khi variance vượt threshold

## Non-functional Requirements
- Dashboard refresh: < 5 phút lag từ GL posting
- Budget import: Support Excel với 10,000+ rows
```

---

## Checklist trước khi submit

```
□ Budget hierarchy đủ cấp theo yêu cầu
□ Period types (Annual/Quarterly/Monthly) rõ ràng
□ Approval workflow có đủ cấp, có delegation
□ Budget vs Actual formula tính đúng (có Committed amount)
□ Variance alert thresholds configurable
□ Integration với GL accounts được chỉ định
□ Mỗi REQ có REQ-ID format REQ-FIN-BUD-[NNN]
```
