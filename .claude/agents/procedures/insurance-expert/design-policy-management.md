# Playbook: Thiết kế Policy Management System

> **Type**: Agent Procedure
> **Agent**: insurance-expert
> **Triggered by**: /wf-design khi cần thiết kế policy admin, issuance, renewal
> **Output**: `.mc-data/docs/phase3-architecture/insurance/policy-management.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` cho insurance projects
- Khi cần thiết kế: Policy administration, quote engine, issuance workflow, premium collection, policy service

---

## Procedure

### Bước 1: Đọc Context và Requirements

```
INPUT: Paths do skill cung cấp qua prompt
READ: .mc-data/docs/phase1-business/insurance-requirements.md → xác định REQ-INS-POLICY-*, REQ-INS-UW-*
READ: .mc-data/docs/_meta/req-registry.json → confirm scope

Xác định:
□ Line of business: Life / Non-life / Health / Composite
□ Distribution channel: Direct / Agency / Broker / Bancassurance / Digital
□ Policy volume: # new policies/tháng, # in-force policies
□ Product catalog: Danh sách sản phẩm cần support
□ Regulatory: Luật KDBH 08/2022 requirements cho loại BH này
```

### Bước 2: Policy Data Model

Thiết kế schema cho các entities chính:

**Policy entity:**
```
Policy {
  policy_number: string (unique, format per LoB)
  product_id: FK → Product
  policyholder_id: FK → Customer
  insured_id: FK → Customer (khác policyholder nếu third-party)
  beneficiary[]: array of {person_id, percentage, relationship}
  effective_date: date
  expiry_date: date
  sum_insured: decimal
  premium_annual: decimal
  payment_frequency: ANNUAL | SEMI_ANNUAL | QUARTERLY | MONTHLY
  payment_method: BANK_TRANSFER | AUTO_DEBIT | VNPAY | MOMO
  status: enum (NEW | UNDERWRITING | PENDING_PAYMENT | IN_FORCE | GRACE | LAPSED | CANCELLED | EXPIRED)
  uw_decision: STANDARD | RATED | CONDITIONAL | DECLINED
  agent_id: FK → Agent (nullable if direct)
  created_at, updated_at, created_by
}
```

**Coverage entity:**
```
Coverage {
  coverage_id: string
  policy_id: FK → Policy
  coverage_type: string (DEATH | TPD | CRITICAL_ILLNESS | PROPERTY_DAMAGE | ...)
  limit: decimal
  deductible: decimal
  exclusions[]: array of {exclusion_code, description, effective_date}
  sub_limit[]: array of {sub_limit_type, amount}
}
```

**Premium Schedule entity:**
```
PremiumInstallment {
  installment_id: string
  policy_id: FK → Policy
  due_date: date
  amount: decimal
  status: PENDING | PAID | OVERDUE | WAIVED
  paid_date: date (nullable)
  payment_reference: string (nullable)
}
```

**Endorsement entity:**
```
Endorsement {
  endorsement_number: string
  policy_id: FK → Policy
  endorsement_type: enum (SUM_INSURED_CHANGE | BENEFICIARY_CHANGE | ADDRESS_CHANGE | PAYMENT_CHANGE | RIDER_ADD | RIDER_REMOVE)
  effective_date: date
  change_details: JSON (before/after values)
  requested_by: user_id
  approved_by: user_id
  requires_uw_review: boolean
  status: PENDING | APPROVED | REJECTED
}
```

### Bước 3: Quote Engine Design

**Input → Processing → Output:**

```
Input:
  □ Risk characteristics (age, location, occupation, asset details)
  □ Product selected
  □ Coverage options desired
  □ Payment frequency preference

Rating Engine:
  □ Base rate: Configurable per product (không hardcode)
  □ Rating factors: age_factor × location_factor × occupation_factor × claims_history_factor
  □ Surcharge/discount: Apply additional factors (multi-policy, loyalty, no-claim)
  □ STP Rules:
     - Score < low_risk_threshold → Auto-accept → Bind immediately
     - low_risk_threshold ≤ Score < high_risk_threshold → Manual UW review
     - Score ≥ high_risk_threshold → Senior UW + reinsurer if needed

Output:
  □ Premium quote với breakdown (base + surcharges + discounts)
  □ Coverage details per coverage type
  □ Payment options (4 frequencies với amounts)
  □ Quote validity period (typically 30-60 days)
  □ Indicative UW requirements (documents needed)
```

### Bước 4: Policy Issuance Workflow

**End-to-end flow:**

```
[Application Received]
        ↓
[KYC Verification]
  □ CCCD/Passport scan và validation
  □ eKYC nếu digital channel
  □ AML check (PEP/Sanctions screening nếu required)
        ↓
[Underwriting Decision]
  □ Auto-route based on risk score
  □ LOW: Auto-issue → skip manual review
  □ MEDIUM: Assign to Underwriter queue
  □ HIGH: Assign to Senior UW, trigger reinsurer referral if needed
        ↓
[Premium Payment Confirmation]
  □ Payment gateway callback or manual confirmation
  □ Bind date = payment confirmed date
        ↓
[Policy Document Generation]
  □ Merge fields vào policy schedule template (per LoB)
  □ Generate PDF: Policy schedule + Standard wordings + Endorsement (if any)
  □ Delivery: Email PDF, digital wallet, physical mail (configurable per product)
        ↓
[Policy Activated]
  □ Effective date logic: Immediate | Next day | Specified date (configurable)
  □ Premium schedule generated
  □ Agent commission calculated and queued
```

### Bước 5: Premium Collection & Lapse Management

**Collection mechanisms:**
```
□ Direct bank transfer: Upload payment advice manually
□ VNPay/Momo: Payment gateway integration, webhook confirmation
□ Auto-debit: Bank authorization setup at policy issuance, auto-debit on due date
□ Bancassurance: Debit KH account tại partner bank

Lapse notification schedule (per Luật KDBH 08/2022):
D-7: Reminder SMS/email
D-3: Final reminder + payment link
D+1: Overdue notification
D+15: Warning — policy at risk of lapse
D+30: Policy lapsed — coverage ended
D+30 → D+730: Reinstatement window
```

**Reinstatement conditions:**
```
Non-life: Back premium + interest + health/risk declaration (if changed)
Life: 
  □ Within 2 years of lapse
  □ Back premium + interest payment
  □ New health declaration (simplified or full per product rule)
  □ Underwriting review (if health change declared)
```

### Bước 6: Policy Service Transactions

**Endorsement workflow per type:**

```
For each endorsement type:
  1. Request submitted (by policyholder, agent, or call center)
  2. System validates: policy in-force, change permissible at this stage
  3. If requires_uw_review: Route to Underwriter → decision
  4. If no UW review needed: Auto-approve + generate endorsement certificate
  5. Endorse certificate delivered (email/portal)
  6. Policy record updated with new values
  7. Audit trail: before/after values, approver, timestamp

Special: Renewal Process
  □ D-60: Auto-generate renewal quote (same or updated rates)
  □ D-60: Send renewal notice with quote to policyholder and agent
  □ D-30: Reminder if no action taken
  □ Auto-renewal option: If KH opted in → auto-bind on expiry date
  □ E-consent: KH confirm renewal digitally
  □ Premium adjustment: Apply updated rating factors if applicable
```

---

## Checklist trước khi submit design

```
□ Policy data model bao gồm đầy đủ lifecycle status transitions
□ Quote engine sử dụng configurable parameters (không hardcode rates)
□ STP routing thresholds configurable per product
□ Grace period 30 ngày enforced trong system (Luật KDBH mandatory)
□ Lapse notification schedule configurable
□ Endorsement workflow có audit trail (before/after values)
□ Policy document generation dùng template system (không hardcode)
□ Payment integration có webhook error handling
□ Health data fields encrypted nếu có life/health products
□ Agent commission calculation logic documented
□ REQ-ID traceability: Mỗi design decision map về REQ-INS-POLICY-* hoặc REQ-INS-UW-*
```
