# Playbook: Thiết kế Claims Management System

> **Type**: Agent Procedure
> **Agent**: insurance-expert
> **Triggered by**: /wf-design khi cần thiết kế claims management, FNOL, settlement
> **Output**: `.mc-data/docs/phase3-architecture/insurance/claims-management.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` cho insurance projects
- Khi cần thiết kế: Claims intake (FNOL), investigation workflow, settlement calculation, fraud detection

---

## Procedure

### Bước 1: Đọc Context và Requirements

```
INPUT: Paths do skill cung cấp qua prompt
READ: .mc-data/docs/phase1-business/insurance-requirements.md → xác định REQ-INS-CLAIM-*
READ: .mc-data/docs/_meta/req-registry.json → confirm scope

Xác định:
□ Line of business: Motor / Property / Life / Health / Liability / Marine
□ Claims volume: # FNOL/tháng, # open claims at any time
□ Settlement complexity: Simple (motor minor) vs Complex (life death, large property)
□ Fraud risk profile: High frequency LoB cần ML-based detection
□ Payment flow: Direct to claimant vs Direct to service provider (repair shop/hospital)
□ Regulatory: Thời hạn settlement per LoB (Luật KDBH), report obligations
```

### Bước 2: Claim Data Model

**Claim entity (header):**
```
Claim {
  claim_number: string (unique, format: CLM-YYYY-NNNNNN)
  policy_id: FK → Policy
  coverage_type: string (coverage being claimed against)
  event_type: string (ACCIDENT | FIRE | THEFT | DEATH | ILLNESS | ...)
  event_date: date
  event_location: string
  fnol_date: datetime
  fnol_channel: PHONE | PORTAL | AGENT | AUTO_TRIGGER
  status: enum (REGISTERED | UNDER_INVESTIGATION | PENDING_DECISION | APPROVED | PARTIALLY_APPROVED | DENIED | PAID | CLOSED | SUBROGATION_PENDING)
  assigned_adjuster_id: FK → User
  fraud_score: decimal (0-100)
  is_fraud_flagged: boolean
  reserve_amount: decimal (current outstanding reserve)
  assigned_at: datetime
  closed_at: datetime (nullable)
  created_at, updated_at
}
```

**Loss Detail entity:**
```
LossDetail {
  loss_id: string
  claim_id: FK → Claim
  loss_description: text
  estimated_loss_amount: decimal
  actual_loss_amount: decimal (nullable — filled after assessment)
  loss_items[]: array of {item_description, quantity, estimated_value}
  documents[]: array of {doc_type, file_url, uploaded_at, uploaded_by}
  police_report_number: string (nullable)
  witness_info: JSON (nullable)
}
```

**Investigation entity:**
```
Investigation {
  investigation_id: string
  claim_id: FK → Claim
  investigator_id: FK → User
  investigation_type: DESK_REVIEW | SITE_VISIT | THIRD_PARTY_INVESTIGATOR
  start_date: date
  completion_date: date (nullable)
  checklist_completed[]: array of {item, completed, notes}
  findings: text
  fraud_indicators[]: array of {rule_triggered, severity}
  recommended_decision: APPROVE | PARTIAL | DENY
  investigation_cost: decimal
}
```

**Settlement entity:**
```
Settlement {
  settlement_id: string
  claim_id: FK → Claim
  loss_amount: decimal (assessed)
  deductible_applied: decimal
  co_insurance_applied: decimal (if applicable)
  net_payable: decimal = loss_amount - deductible - co_insurance
  salvage_value: decimal (motor total loss — offsets payment)
  approval_chain[]: array of {approver_id, role, amount_limit, decision, timestamp, comments}
  payment_method: BANK_TRANSFER | CHEQUE | DIRECT_TO_PROVIDER
  payment_beneficiary: {name, bank, account_number} | {provider_id}
  payment_reference: string
  payment_date: date (nullable)
  status: PENDING_APPROVAL | APPROVED | PAID | DISPUTED
}
```

**Reserve Tracking entity:**
```
ReserveMovement {
  movement_id: string
  claim_id: FK → Claim
  movement_date: datetime
  previous_reserve: decimal
  new_reserve: decimal
  reason: FNOL_INITIAL | INVESTIGATION_UPDATE | SETTLEMENT_APPROVED | PAID | RELEASED
  updated_by: user_id
}
```

### Bước 3: FNOL Intake (Multi-channel)

**Channel design:**

```
Phone channel:
  □ Guided script cho call center agent
  □ Structured intake form: Date/time of loss, description, estimated loss,
    witness info, police report (if applicable), contact preference
  □ Auto-assign claim number và adjuster tại cuối cuộc gọi
  □ Send confirmation SMS/email to policyholder

Portal / Mobile App:
  □ Self-service FNOL form với guided questions per event type
  □ Photo/document upload (compressed, max 10MB/file)
  □ Pre-fill from policy details (coverage type, policyholder info)
  □ Claim tracking number generated immediately
  □ Push notification: Claim received + assigned adjuster info

Agent-submitted:
  □ Agent portal: Submit FNOL on behalf of policyholder
  □ Agent receives acknowledgment, KH also receives notification
  □ Agent can track case status for their policyholders

Auto-trigger:
  □ IoT/Telematics (motor): Accident detected → FNOL auto-created
  □ Bancassurance (life): Bank detects death certificate → notify insurance
  □ Hospital network (health): Hospital submits cashless claim directly
```

### Bước 4: Investigation & Coverage Workflow

**Assignment logic:**
```
Auto-assignment rules:
  □ By claim type: Motor → Motor adjuster pool; Life → Life adjuster pool
  □ By location: Geographic assignment if site visit needed
  □ By workload: Round-robin or least-loaded within eligible pool
  □ By amount: Large claims (> threshold) → Senior Adjuster mandatory

Checklist per claim type (configurable, not hardcode):
  Motor:
    □ Police report (if accident)
    □ Vehicle photos (damage)
    □ Repair shop quote
    □ Driver license copy
    □ Certificate of vehicle registration
  Property:
    □ Fire brigade report (if fire)
    □ Police report (if theft/vandalism)
    □ Photos of damage
    □ Inventory list with values
    □ Purchase receipts (for high-value items)
  Life/Death:
    □ Death certificate (official)
    □ Medical records (cause of death)
    □ Beneficiary ID documents
  Health:
    □ Doctor diagnosis
    □ Hospital admission/discharge records
    □ Medical bills (itemized)
```

**Fraud detection execution:**
```
Rule engine (runs automatically at each milestone):
  □ Velocity check: FNOL within 30 days of inception
  □ Frequency check: Same claimant/provider > threshold
  □ Blacklist match: CCCD, vehicle, license, provider
  □ Document inconsistency: Cross-check fields across documents
  □ Round number: Settlement exactly round number

ML fraud scoring (runs after investigation data collected):
  □ Input features: claim characteristics, claimant history, provider history, timing
  □ Score 0-100 → thresholds: 0-30 Normal, 31-60 Review, 61-80 Investigate, 81-100 Block

Fraud flag actions:
  □ Flag raised → Notify Senior Adjuster + Fraud Team
  □ Score > 80 → Payment hold until fraud team clears
  □ Confirmed fraud → Submit to industry fraud registry
```

### Bước 5: Settlement Calculation & Approval

**Calculation logic:**

```
Motor (actual cash value basis):
  Net Payable = Market Value of Vehicle at Loss Date
                - Deductible
                - Salvage Value (if total loss)
  If repair: Net Payable = Repair Cost (approved estimate) - Deductible

Property (replacement cost basis):
  Net Payable = Replacement Cost New - Deductible - Co-insurance portion
  Co-insurance: If sum insured < 80% of actual value → proportional reduction

Life/Death benefit:
  Net Payable = Sum Insured (death benefit)
                + Accrued bonus (if participating policy)
                - Policy loan outstanding (if any)
                - Premium due (if any within grace period)

Health (reimbursement basis):
  Net Payable = Eligible medical bills
                - Deductible
                - Co-payment %
                - Non-eligible items (per exclusion list)

Cashless health (direct payment to hospital):
  Insurance pays hospital directly for pre-authorized amount
  KH pays only the co-payment portion at discharge
```

**Approval routing:**
```
Calculate net_payable →
  ≤ 10M: Claims Assistant can approve
  ≤ 50M: Claims Adjuster can approve
  ≤ 200M: Senior Adjuster can approve
  ≤ 1B: Claims Manager can approve
  > 1B: CEO approval required

Denial routing:
  Any denial → Claims Manager must sign-off (minimum)
  → Generate denial letter with reason code + coverage cited
  → Notify policyholder via registered channel (email + SMS)
  → Inform of dispute resolution rights (Cục GS BH)
```

### Bước 6: Post-Settlement

**Closure:**
```
□ Payment confirmed (bank transfer receipt or provider acknowledgment)
□ Reserve released (ReserveMovement record created)
□ Documents finalized and archived
□ Claim status → CLOSED
□ Policyholder survey sent (NPS/satisfaction)
□ Adjuster performance metrics updated
```

**Subrogation:**
```
□ Flag if event caused by third party (accident fault, defective product)
□ System generates subrogation referral to Legal team
□ Track recovery amount separately
□ Net recovery offsets claims cost in loss ratio calculation
```

**Analytics output:**
```
□ Claim frequency by: Risk type, location, agent, product, season
□ Average settlement amount by claim type
□ Cycle time: FNOL to closure (target: < 30 days for standard claims)
□ Adjuster performance: Open cases, cycle time, reopened cases
□ Fraud metrics: Detection rate, confirmed fraud rate, recovery from subrogation
□ Reserve adequacy: Actual vs initial reserve at closure (variance %)
```

---

## Checklist trước khi submit design

```
□ Claim data model bao gồm đầy đủ status transitions
□ FNOL intake có structured form (không free-text chính)
□ Multi-channel FNOL support được thiết kế
□ Fraud scoring chạy tự động (không chỉ manual flag)
□ Dual control enforced: Investigator ≠ Approver
□ Denial workflow có mandatory Claims Manager sign-off
□ Settlement calculator tính đúng deductible + co-insurance per LoB
□ Reserve movement tracked per claim (audit trail)
□ Subrogation flag tự động khi applicable
□ Medical data fields encrypted nếu có health claims
□ Payment routing: Direct to claimant vs Provider (configurable per claim type)
□ SLA tracking: Cảnh báo khi approach Luật KDBH statutory deadlines
□ REQ-ID traceability: Mỗi design decision map về REQ-INS-CLAIM-*
```
