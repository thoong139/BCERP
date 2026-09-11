# Playbook: Review Investment Module Implementation

> **Type**: Agent Procedure
> **Agent**: investment-expert
> **Triggered by**: /wf-implement-feature review pass cho investment modules
> **Output**: Review report (inline hoặc `.mc-data/work/wf-implement-feature/review-investment-[module]-[date].md`)

---

## Tổng quan

Review implementation của investment modules theo 5 category chính:
1. NAV Calculation Accuracy
2. Limit & Compliance Controls
3. Segregation of Duties (SoD) Enforcement
4. Reconciliation
5. Regulatory Reporting

Mỗi category có checklist cụ thể. Mọi item FAIL = blocking issue phải fix trước khi approve.

---

## Category 1: NAV Calculation Accuracy

```
Checklist:
```

- [ ] **NAV formula đúng**: `NAV = (Total Assets - Total Liabilities) / Units_Outstanding`
  - Kiểm tra: Có đủ components? Assets bao gồm cả accrued income? Liabilities bao gồm accrued fees?
  - Test case: Fund với 10 positions, 2 fee accruals, 1 pending dividend → verify NAV khớp manual calculation

- [ ] **Management fee accrual chính xác**: `daily_accrual = AUM × annual_rate / 365`
  - Kiểm tra: Accrual tính daily? Áp dụng đúng base (AUM đầu ngày hay cuối ngày)?
  - Test case: AUM 100 tỷ VND, rate 1.5%/year → daily accrual = 4,109,589 VND

- [ ] **Performance fee với HWM đúng**:
  - Kiểm tra: HWM được track correctly? Accrual chỉ khi NAV > HWM?
  - Test case: NAV 11,000 (HWM 10,500) → accrual = (11,000 - 10,500) × rate × units. NAV 10,200 (HWM 10,500) → accrual = 0

- [ ] **Corporate actions áp dụng đúng ex-date logic**:
  - Kiểm tra: Dividend receivable accrued vào ex-date? Cash received vào pay-date?
  - Test case: VCB dividend 500 VND/share, fund holds 100,000 shares → accrue 50M VND receivable on ex-date

- [ ] **Multi-class NAV tính riêng biệt per class**:
  - Kiểm tra: Class A và Class B có fee structures khác nhau? NAV per unit per class tính độc lập?
  - Test case: Class A (mgmt fee 1.5%), Class B (mgmt fee 1.0%) → verify different NAV per unit after 1 year

- [ ] **Rounding đúng**: NAV per unit round to 2 decimal places (VND) hoặc per fund prospectus

---

## Category 2: Limit & Compliance Controls

```
Checklist:
```

- [ ] **Pre-trade limit check BLOCKING**: Orders that would breach hard limits must be blocked, not just warned
  - Kiểm tra: Submit buy order that would push single issuer concentration to 11% → system must reject
  - Kiểm tra: Soft breach (9%) → warning shown but order can proceed

- [ ] **Concentration limits enforced (single issuer)**:
  - Open-end fund: Max 10% of NAV per UBCKNN regulations
  - Kiểm tra: Real-time calculation considers pending (not yet settled) orders?
  - Test case: Fund NAV 1,000 tỷ, VCB position already 95 tỷ (9.5%) → buying 6 tỷ more (total 10.1%) must be blocked

- [ ] **Sector concentration enforced** (fund-specific limit, typically 30%):
  - Kiểm tra: Sector classification correct for all securities?
  - Kiểm tra: Cross-sector securities classified consistently?

- [ ] **UBCKNN single stock ownership limit** (max 5% of outstanding shares):
  - Kiểm tra: System tracks fund's % ownership of each issuer's outstanding shares?
  - Requires: Outstanding share count from data feed, updated at least weekly

- [ ] **Chinese Wall enforced**: Front Office users CANNOT see compliance monitoring data
  - Kiểm tra: Fund Manager role — check that API endpoints for compliance monitoring return 403
  - Kiểm tra: Compliance Officer role — check that order creation endpoints return 403
  - Test: Login as Fund Manager → attempt to access `/compliance/monitoring` → must be forbidden

- [ ] **Restricted list**: Securities on compliance restricted list blocked from trading
  - Kiểm tra: Pre-trade check queries restricted_list table?
  - Test case: Add VCB to restricted list → attempt to buy VCB → blocked

---

## Category 3: SoD Enforcement

```
Checklist:
```

- [ ] **Front Office cannot access Back Office settlement screens**:
  - Roles in scope: fund_manager, analyst
  - Blocked actions: Confirm trade, mark as settled, create/modify reconciliation records
  - Test: Login as fund_manager → attempt POST `/settlement/confirm/{trade_id}` → 403

- [ ] **Back Office cannot create or modify orders**:
  - Roles in scope: fund_accountant, back_office_admin
  - Blocked actions: Create order, modify order, approve order
  - Test: Login as fund_accountant → attempt POST `/orders` → 403

- [ ] **Compliance is read-only on operational data**:
  - Roles in scope: compliance_officer, compliance_manager
  - Allowed: GET operations on portfolio, orders, transactions, investor data
  - Blocked: POST/PUT/DELETE on any operational record
  - Test: Login as compliance_officer → attempt PUT `/portfolio/{id}` → 403

- [ ] **Four-eyes: Large orders require second approver**:
  - Threshold: Orders > 1 tỷ VND cannot be routed by Fund Manager alone
  - Test case: Create order for 2 tỷ VND → status stays PENDING_APPROVAL (not auto-routed)
  - Test case: Risk Officer approves → status moves to APPROVED → routing allowed
  - Kiểm tra: same user cannot be both creator and approver

- [ ] **NAV sign-off requires two separate users**:
  - Fund Accountant calculates → Risk Officer verifies → cannot be same user
  - Test: Login as user who calculated NAV → attempt to also sign-off as Risk Officer → blocked

- [ ] **Subscription approval requires KYC-approved status**:
  - System must block subscription allocation if investor.kyc_status != 'approved'
  - Test: Create subscription for investor with kyc_status = 'pending' → allocation blocked

---

## Category 4: Reconciliation

```
Checklist:
```

- [ ] **Daily reconciliation runs automatically** after custodian file received:
  - Kiểm tra: Scheduled job triggers at expected time (e.g., 9:00 AM T+1)?
  - Kiểm tra: If custodian file not received by deadline → alert sent to Fund Accountant?

- [ ] **Breaks surfaced with severity classification**:
  - Severity levels: minor (<0.01% NAV), major (0.01-0.1% NAV), critical (>0.1% NAV)
  - Kiểm tra: Break record created with correct severity?
  - Test: Introduce 1-share discrepancy in 10M share position → minor break created

- [ ] **Resolution workflow tracked correctly**:
  - States: open → investigating → resolved → signed_off
  - Kiểm tra: Status transitions enforced (cannot jump from open to signed_off)?
  - Kiểm tra: Resolution notes required before marking as resolved?

- [ ] **Position changes blocked while critical break is open**:
  - Policy: No trades or position updates while critical reconciliation break unresolved
  - Test: Create critical break → attempt to create new order → blocked with clear error message
  - Kiểm tra: Only critical breaks (not minor/major) trigger this block?

- [ ] **Reconciliation history retained**:
  - At least 7 years retention (regulatory requirement)
  - Kiểm tra: Old reconciliation records are not deleted or overwritten?

---

## Category 5: Regulatory Reporting

```
Checklist:
```

- [ ] **UBCKNN report format matches official template**:
  - Kiểm tra: Exported Excel/XML matches UBCKNN template exactly (column names, order, data types)?
  - Test: Generate monthly portfolio report → open in Excel → verify against UBCKNN template v[current version]
  - Note: UBCKNN template changes periodically — verify system uses latest version

- [ ] **Submission deadline tracking và automated alerts**:
  - Monthly report deadline: 5th business day of following month
  - Kiểm tra: Alert sent to Compliance Manager at least 2 business days before deadline?
  - Kiểm tra: Deadline calculated correctly (business days, not calendar days)?

- [ ] **Audit trail: who submitted, what data, when**:
  - Kiểm tra: Each report submission stores: user_id, timestamp, data_snapshot_id, submission_reference
  - Kiểm tra: Cannot delete or modify submitted report records?
  - Test: Generate and submit a report → verify audit record created with all fields

- [ ] **KYC/AML complete for all active accounts**:
  - Kiểm tra: No active investor account with kyc_status != 'approved' can hold units
  - Kiểm tra: KYC expiry triggers renewal workflow (annual review)?
  - Test: Set investor KYC to 'expired' → verify system flags and blocks new subscriptions

- [ ] **STR (Suspicious Transaction Report) workflow**:
  - Kiểm tra: Compliance Officer can flag transactions for STR
  - Kiểm tra: STR records have audit trail (flagged by whom, when, outcome)
  - Kiểm tra: STR data is not accessible to Front Office

---

## Hướng dẫn Output Review Report

```
Cho mỗi item trong checklist:
  - PASS: Requirement met, test case verified
  - FAIL: Requirement not met — document specific issue + reproduction steps
  - N/A: Not applicable for this fund type/scope

Summary:
  - Total checks: [N]
  - PASS: [N]
  - FAIL: [N] — list all FAIL items
  - N/A: [N]
  - VERDICT: APPROVED (0 FAIL) / NEEDS_WORK ([N] FAIL items)

For each FAIL:
  - Item: [checklist item]
  - Issue: [specific description of what is wrong]
  - Evidence: [test case performed, result observed]
  - Severity: CRITICAL (security/SoD/regulatory) / MAJOR (functional) / MINOR (UX/performance)
  - Recommended fix: [specific action to take]
```

---

## Checklist Review Hoàn thành

- [ ] Tất cả 5 categories đã reviewed
- [ ] Tất cả test cases đã run với kết quả documented
- [ ] FAIL items đã có severity và recommended fix
- [ ] VERDICT rõ ràng: APPROVED hoặc NEEDS_WORK
- [ ] Review report đã ghi vào output path
