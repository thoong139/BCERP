# Playbook: Thiết kế Accounting Module

> **Type**: Agent Procedure
> **Agent**: finance-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design module kế toán (GL/AP/AR)
> **Output**: Feature spec cho accounting module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Khi cần spec module General Ledger, Accounts Payable, hoặc Accounts Receivable
- Khi thiết kế journal entry flow và Chart of Accounts
- Khi review/audit hệ thống kế toán hiện có cần redesign

---

## Procedure

### Bước 1: Đọc finance requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .mc-data/docs/phase1-business/finance-requirements.md

Cần xác định:
□ Accounting standard áp dụng (VAS / IFRS / Circular 133)
□ Modules nào trong scope: GL / AP / AR / tất cả
□ Multi-entity / single entity?
□ Multi-currency cần không?
□ Level of automation mong muốn
```

### Bước 2: Thiết kế Chart of Accounts

```
READ: controls.md → Section 6: VAS Compliance

Chart of Accounts theo VAS (Circular 200/2014):

Loại tài khoản:
1xx → Tài sản ngắn hạn (Current Assets)
2xx → Tài sản dài hạn (Non-current Assets)
3xx → Nợ phải trả (Liabilities)
4xx → Vốn chủ sở hữu (Equity)
5xx → Doanh thu (Revenue)
6xx → Chi phí (Expenses)
7xx → Thu nhập khác (Other Income)
8xx → Chi phí khác (Other Expenses)
9xx → Xác định kết quả kinh doanh (P&L Closing)

Data model Chart of Accounts:
Account:
  - account_code (VD: 1111, 131, 331)
  - account_name_vn, account_name_en
  - account_type (asset/liability/equity/revenue/expense)
  - parent_code (cho sub-accounts)
  - is_posting_account (chỉ tài khoản lá mới được posting)
  - normal_balance (debit/credit)
  - is_active, created_at
```

### Bước 3: Thiết kế Journal Entry Flow

```
READ: operations.md → Section 2.3: Month-End Close

Double-Entry rules (BẮT BUỘC):
□ Tổng Debit = Tổng Credit cho mọi journal entry
□ System PHẢI validate balance trước khi allow posting
□ Không cho phép unbalanced entries dưới bất kỳ điều kiện nào

Journal Entry Data Model:
JournalEntry:
  - je_id, je_number (auto-sequence)
  - je_date, period_id
  - description, reference
  - status (Draft → Reviewed → Posted → Reversed)
  - created_by, reviewed_by, posted_by
  - total_debit, total_credit (phải bằng nhau)
  - source (manual / auto-accrual / bank-feed / sub-ledger)

JournalEntryLine:
  - je_id, line_number
  - account_code, debit_amount, credit_amount
  - cost_center, project_code (optional)
  - description
```

### Bước 4: Thiết kế Approval & Posting Controls

```
READ: controls.md → Section 1: Authorization Matrix
READ: controls.md → Section 2: SoD Matrix

Controls bắt buộc:
□ JE Creator ≠ JE Poster (SoD)
□ Validation: Debit = Credit trước khi submit
□ Period check: Không post vào closed period
□ Approval workflow theo amount threshold
□ Reason required khi void posted entry

Posting workflow:
Draft → (Reviewer checks) → Reviewed → (Poster approves) → Posted
Posted → (Với reason + CFO approval) → Reversed
```

### Bước 5: Thiết kế Reporting Structure

```
Financial Statements cần generate:

1. Balance Sheet (Bảng cân đối kế toán):
   - Assets = Liabilities + Equity
   - Comparative: Current period vs Previous period

2. P&L Statement (Báo cáo kết quả kinh doanh):
   - Revenue - Expenses = Net Income
   - By period: Monthly / Quarterly / YTD

3. Cash Flow Statement (Báo cáo lưu chuyển tiền tệ):
   - Operating / Investing / Financing activities
   - Direct method (VAS) hoặc Indirect method

4. Trial Balance (Bảng cân đối số phát sinh):
   - Debit/Credit totals per account
   - Opening + Movements + Closing

Non-functional requirements:
□ Report generation < 10 giây cho standard periods
□ Drill-down từ summary → transaction level
□ Export: PDF, Excel, CSV
```

### Bước 6: Feature Spec Output

```markdown
# Feature Spec: Accounting Module — [GL/AP/AR]

## Overview
[Mô tả module và business value]

## User Stories
[Theo personas từ analyze-finance-requirements playbook]

## Functional Requirements

### Chart of Accounts
REQ-FIN-GL-001: Quản lý Chart of Accounts theo VAS
REQ-FIN-GL-002: Import CoA từ Excel với validation
REQ-FIN-GL-003: Sub-account support (tối đa 4 cấp)

### Journal Entries
REQ-FIN-GL-004: Tạo journal entry với double-entry validation
REQ-FIN-GL-005: Approval workflow trước khi posting
REQ-FIN-GL-006: Void entry với audit trail đầy đủ
REQ-FIN-GL-007: Recurring entries (tự động theo lịch)

### Period Management
REQ-FIN-GL-008: Period open/close controls
REQ-FIN-GL-009: Month-end close checklist

### Reporting
REQ-FIN-RPT-001: Balance Sheet tự động từ account balances
REQ-FIN-RPT-002: P&L Statement với drill-down
REQ-FIN-RPT-003: Trial Balance export

## Data Model
[ERD hoặc field definitions ở trên]

## Non-functional Requirements
- Double-entry validation: 100% enforcement
- Audit trail: 10 năm retention
- Period lock: Không cho post vào closed period
```

---

## Checklist trước khi submit

```
□ Chart of Accounts tuân thủ VAS (nếu applicable)
□ Double-entry validation được implement
□ SoD: JE Creator ≠ JE Poster
□ Period lock mechanics rõ ràng
□ Audit trail requirements đủ fields (xem controls.md Section 3)
□ Financial statements đủ 3 báo cáo chính
□ Mỗi REQ có REQ-ID format REQ-FIN-[MODULE]-[NNN]
```
