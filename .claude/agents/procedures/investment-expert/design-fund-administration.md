# Playbook: Thiết kế Fund Administration System

> **Type**: Agent Procedure
> **Agent**: investment-expert
> **Triggered by**: /wf-design khi cần thiết kế fund admin, NAV system, investor portal
> **Output**: `.mc-data/docs/phase3-architecture/investment/fund-administration.md`

---

## Bước 1: NAV Calculation Engine

```
Input sources cho NAV calculation:
  1. Positions: From OMS/Portfolio system (quantity per security, as of valuation date)
  2. Prices: Market data feed (end-of-day) + manual override for illiquid
  3. Accruals: Management fee, performance fee, fund expenses
  4. Corporate actions: Pending dividends, splits, rights issues
  5. Cash positions: From custodian bank statement

Accrual calculation:
  Management fee:
    - Daily accrual = AUM × annual_mgmt_rate / 365
    - Deducted from fund assets daily, paid monthly to AMC
  Performance fee:
    - High Water Mark (HWM) based
    - Accrued only when NAV > HWM
    - Accrual = max(0, NAV - HWM) × performance_fee_rate × units_outstanding
    - Crystallization: Annually or on redemption
  Fund expenses:
    - Audit fee, custodian fee, legal fee, admin fee
    - Straight-line daily accrual

Corporate actions:
  - Dividend (cash): Ex-date → accrue receivable, pay-date → receive cash, update NAV
  - Dividend (stock): Ex-date → increase position quantity, no cash impact
  - Stock split: Adjust quantity and avg_cost (split ratio)
  - Rights issue: Accrue subscription, apply on pay-date
  - Merger/acquisition: Manual handling with compliance sign-off

NAV formula:
  Total Assets = Σ(market_value of all positions) + cash + accrued_income
  Total Liabilities = management_fee_payable + performance_fee_payable + other_expenses
  NAV = Total Assets - Total Liabilities
  NAV per unit = NAV / units_outstanding

Multi-class shares:
  - Class A (retail): Standard management fee, performance fee
  - Class B (institutional): Reduced management fee, same performance fee
  - NAV per unit calculated separately per class
  - Allocation of P&L proportional to units in each class
```

---

## Bước 2: Unit Registry

```
Investor record:
  - investor_id: UUID
  - investor_type: enum (individual, corporate, pe_lp)
  - kyc_status: enum (pending, approved, rejected, under_review, expired)
  - kyc_expiry: date (annual review trigger)
  - holdings: [{ class_id, units, avg_nav, subscription_date }]
  - bank_account: { bank_name, account_number, branch } (for redemption payments)
  - total_invested: decimal (total capital contributed)
  - total_redeemed: decimal (total capital returned)

Subscription workflow:
  1. DRAFT: Investor submits application (portal/paper form)
  2. KYC_PENDING: Compliance reviews KYC documents
  3. AML_CHECK: Automated screening (PEP, sanctions)
  4. FUND_ACCOUNTANT_REVIEW: Amount verification, source of funds
  5. APPROVED: Fund Accountant approves
  6. UNIT_ALLOCATED: Units allocated at next NAV after approval
  7. CONFIRMED: Confirmation sent to investor (email + portal)

  Business rules:
  - Minimum subscription: Per fund prospectus (e.g., 10 triệu VND)
  - Cash must be received before unit allocation
  - KYC must be APPROVED before subscription processed

Redemption workflow:
  1. REQUEST: Investor submits redemption request
  2. VALIDATION: Check cooling-off period, gate rules
  3. QUEUED: Queued for next NAV calculation date
  4. PROCESSED: Units redeemed at NAV of processing date
  5. PAYMENT_PENDING: Cash payment T+3 from processing date
  6. COMPLETED: Payment confirmed, investor record updated
  7. STATEMENT_UPDATED: Transaction reflected in investor statement

  Business rules:
  - Large redemption (>5% NAV): 3-5 business day notice required
  - Liquidity gate: Fund Manager can defer up to 10% of requests if liquidity stress
  - Cooling-off: Per fund prospectus (typically 30-90 days for some fund types)

Transfer between investors:
  - Requires compliance pre-approval (KYC for receiving investor)
  - Transfer at current NAV or agreed price (within regulatory bounds)
  - Both parties confirmation required

Statement generation:
  - Monthly: Auto-generated and emailed by 5th business day
  - Content: Opening balance, transactions, closing balance, returns, performance chart
  - Format: PDF (branded), downloadable from portal
  - Ad hoc: On-demand generation via portal (any date range)
```

---

## Bước 3: Reconciliation Engine

```
Daily reconciliation — positions:
  - Source 1: Internal portfolio system (positions as of EOD)
  - Source 2: Custodian VSDC statement (received T+1 morning)
  - Match: By security ISIN, compare quantity
  - Tolerance: 0 (position quantity must match exactly)
  - Exception: Any difference → create break record → assign to Fund Accountant

Daily reconciliation — cash:
  - Source 1: Internal cash ledger
  - Source 2: Bank statement (custodian bank)
  - Match: By date, compare balance
  - Tolerance: 0 VND (exact match required)
  - Exception: Difference → break record → investigate

Monthly NAV reconciliation (if external administrator):
  - Compare internal NAV with external admin's independent calculation
  - Tolerance: 0.01% of NAV
  - Exception: Difference > tolerance → mandatory investigation → restate if needed

Break record structure:
  - break_id: UUID
  - break_type: enum (position, cash, nav)
  - source_1_value, source_2_value, difference
  - severity: enum (minor < 0.01%, major 0.01-0.1%, critical > 0.1%)
  - status: enum (open, investigating, resolved, signed_off)
  - assigned_to: FK → User
  - opened_date, resolved_date
  - resolution_notes, approver_id

Exception workflow:
  1. Break detected → auto-create break record
  2. Alert sent to Fund Accountant
  3. Fund Accountant investigates → update status = investigating
  4. Resolution documented → status = resolved
  5. Risk Officer sign-off → status = signed_off
  6. Policy: No position changes allowed if critical break is open (>threshold)
```

---

## Bước 4: UBCKNN Regulatory Reporting

```
Báo cáo định kỳ:

Monthly — Danh mục đầu tư (Portfolio Report):
  - Deadline: 5th business day of following month
  - Content: All holdings as of month-end, weights, market values
  - Format: UBCKNN Excel template (version-locked)
  - Auto-generate: System pulls from positions as of month-end
  - Submission: Upload to UBCKNN portal (manual submission after review)
  - Approval: Fund Manager + Compliance sign-off before submit

Quarterly — Báo cáo tài chính:
  - Deadline: 45 days after quarter end
  - Content: NAV statement, performance, holdings detail
  - Format: UBCKNN-prescribed XML format + PDF narrative
  - Requires: Fund Accountant + external auditor sign-off (for annual)

Annual — Audited financial statements:
  - Deadline: 90 days after year end
  - Requires: External auditor opinion
  - Submission: UBCKNN + published on fund website

Event-based reporting:
  - System triggers reminder when reportable event occurs
  - Deadline tracking: Calendar view with color-coded status
  - Escalation: Alert to Compliance Manager if deadline within 2 business days

Audit trail for reporting:
  - Who generated report, when, with what data snapshot
  - Who reviewed and approved
  - Submission timestamp and reference number from UBCKNN portal
  - Version history: If report amended, previous version retained
```

---

## Bước 5: Investor Portal

```
Dashboard (landing page after login):
  - Current NAV per unit (with as-of date)
  - My portfolio value (units × NAV)
  - Total return since investment (%)
  - Return vs benchmark (chart, last 12 months)
  - Last 5 transactions summary

Performance view:
  - Historical NAV chart (daily, configurable period)
  - Return table: 1M, 3M, 6M, YTD, 1Y, 3Y, Since Inception
  - Benchmark comparison overlay
  - Fund ranking vs peers (if data available)

Statements:
  - List: All statements sorted by date
  - Filter: By period, by type (monthly, quarterly, annual)
  - Download: PDF format, branded
  - Preview: In-browser before download

Transaction history:
  - Subscriptions, redemptions, distributions
  - Filter by type and date range
  - Export: CSV for investor's own records

Documents library:
  - Fund prospectus (current version)
  - Annual reports
  - Semi-annual reports
  - Meeting minutes (AGM/EGM)
  - KYC forms and policy documents

Self-service actions:
  - Redemption request: Amount or units, with confirmation and cooling-off notice
  - Bank account update: New bank details (requires document upload + compliance review)
  - Change contact details: Email, phone, address

PE/VC specific (Capital Account):
  - Total capital committed vs called
  - Distributions received
  - Current NAV of residual interest
  - IRR, TVPI, DPI, RVPI
  - Upcoming capital calls (if any)

Security:
  - 2FA required for login (OTP via email or authenticator app)
  - Session timeout: 30 minutes inactivity
  - Transaction confirmation: OTP for redemption requests
  - Login audit log: Accessible to investor (last 10 logins)
```

---

## Checklist Thiết kế Fund Administration

- [ ] NAV formula đúng và đủ (assets, liabilities, units)
- [ ] Accrual types đầy đủ (mgmt fee, perf fee với HWM, fund expenses)
- [ ] Corporate action types covered (cash dividend, stock dividend, split, rights)
- [ ] Multi-class shares thiết kế riêng biệt per class
- [ ] Unit registry: subscription + redemption workflows với business rules
- [ ] Large redemption gate logic đúng (5% NAV threshold, 3-5 day notice)
- [ ] Reconciliation engine: position + cash daily, NAV monthly
- [ ] Break record workflow: open → investigating → resolved → signed_off
- [ ] UBCKNN reports: monthly + quarterly + annual + event-based
- [ ] Investor portal: NAV, performance, statements, self-service, 2FA
- [ ] Audit trail: NAV sign-off, report submission, investor actions
- [ ] Output file tồn tại tại đường dẫn đã chỉ định
