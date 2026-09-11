# Healthcare - Operational Analysis Framework

> **Domain**: Healthcare / Y tế & Chăm sóc sức khỏe
> **Last Updated**: 2026-03-19

---

## 1. Core Processes

### Process 1: Patient Registration & Scheduling

```
Request → Eligibility Check → Slot Assignment → Pre-visit Prep → Check-in
    │              │                 │                 │              │
    ▼              ▼                 ▼                 ▼              ▼
  Walk-in /     Insurance /       Provider        Forms sent     Verify ID
  Call / App    BHYT verify       Calendar        to patient     & insurance
```

| Step | Owner | System Actions | Validation |
|------|-------|----------------|------------|
| Request | Reception / Patient | Create appointment record | Required demographics |
| Eligibility Check | Reception | Query BHYT / Insurance portal | Coverage active, service covered |
| Slot Assignment | Reception / Scheduling | Block provider calendar | No double-booking |
| Pre-visit Prep | System / Nurse | Send forms, prep medical history | Forms completed before arrival |
| Check-in | Reception | Verify ID, update demographics, create encounter | Identity confirmed (2 identifiers) |

### Process 2: Clinical Consultation

```
Check-in → Triage → Vitals → Consultation → Diagnosis → Orders → Check-out
    │          │        │           │             │          │         │
    ▼          ▼        ▼           ▼             ▼          ▼         ▼
  Encounter  Assign  Document    History &     ICD-10      Lab /    Follow-up
  Created    Urgency  Weight,     Exam,         Code       Rx /     & Billing
             Level    BP, Temp    Assessment    Assigned   Imaging
```

| Step | Owner | SLA |
|------|-------|-----|
| Check-in → Triage | Nurse | <5 min (Emergency), <15 min (Routine) |
| Triage → Vitals | Nurse | Per urgency queue |
| Vitals → Consultation | Physician | Target wait time <30 min (Outpatient) |
| Consultation → Orders | Physician | During encounter |
| Orders → Check-out | Reception / Billing | Before patient leaves |

### Process 3: Prescription Management

```
Prescribe → Pharmacy Review → Dispensing → Counseling → Administration
     │               │              │             │              │
     ▼               ▼              ▼             ▼              ▼
  e-Rx in         Drug-drug /    Fill by      Patient         MAR
  CPOE system     allergy check  pharmacist   education       updated
```

| Step | Owner | Validation |
|------|-------|------------|
| Prescribe | Physician / Authorized prescriber | Drug–allergy check, drug–drug interaction check |
| Pharmacy Review | Pharmacist | Clinical appropriateness, dose range |
| Dispensing | Pharmacist | Right drug, dose, route, frequency, patient |
| Counseling | Pharmacist / Nurse | 5 Rights verified with patient |
| Administration | Nurse | MAR documented with timestamp + nurse ID |

### Process 4: Lab & Diagnostic Ordering

```
Order → Specimen Collection → Processing → Analysis → Result → Review → Action
  │               │               │            │          │        │        │
  ▼               ▼               ▼            ▼          ▼        ▼        ▼
CPOE          2-identifier    LIS receives  Analyzer   Auto-     Physician Critical
entry         verification    label scan    runs test  post to   notified  value
              bedside label                            EMR       of result  alert
```

| Result Class | Definition | Notification Action |
|--------------|------------|---------------------|
| Critical | Life-threatening range | Immediate phone call to ordering physician (<30 min) |
| Abnormal | Outside normal range | In-system flag + notification |
| Normal | Within normal range | Available in EMR / patient portal |
| Amended | Result corrected | Re-notification to original orderer |

### Process 5: Billing & Insurance Claims

```
Encounter → Coding → Claim Generation → Submission → Adjudication → Payment
     │           │            │               │              │           │
     ▼           ▼            ▼               ▼              ▼           ▼
  Charges     ICD-10 +     CMS-1500 /      BHYT /         Approved /  Post to
  captured    CPT codes    UB-04 form      Insurer        Denied /    patient
                                           portal         Pending     account
```

| Step | Owner | Common Failure Points |
|------|-------|-----------------------|
| Coding | Medical Coder | Incomplete clinical documentation |
| Claim Submission | Billing | Wrong payer ID, missing prior authorization |
| Adjudication | Insurer | Coding mismatch, eligibility lapse |
| Payment Posting | Finance | Partial payment, ERA matching errors |
| Denial Management | Billing | Missed appeal deadline (30–60 days) |

---

## 2. Task Frequency Analysis

### Daily Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Patient scheduling & queue management | Reception | 2–3 hours | Overbooking, no-show management |
| Clinical documentation per encounter | Physician | 10–15 min / patient | Time-consuming, alert fatigue |
| Vital signs & MAR documentation | Nurse | 5 min / patient per round | Interruptions, workstation scarcity |
| Lab result review & follow-up | Physician | 30–60 min | Delayed results, notification failures |
| Prescription processing | Pharmacist | Full day | Drug interaction alerts, stock outs |
| Claim coding (outpatient) | Medical Coder | 4–6 hours | Incomplete physician notes |
| Patient inquiry & support | Reception / CS | 2–3 hours | Multiple systems to check |

### Weekly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Quality review (clinical documentation) | Department Head | 2 hours | Manual sampling, no auto-audit |
| Staff scheduling & coverage | Nurse Manager | 2 hours | Manual spreadsheet |
| Denial management & resubmission | Billing | 4 hours | High volume, tracking in Excel |
| Pharmacy inventory reconciliation | Pharmacist | 2 hours | Manual count vs system |
| Patient satisfaction review | Admin | 1 hour | Data delayed from surveys |

### Monthly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Compliance reporting (Ministry of Health) | Admin / Compliance | 4 hours | Data extraction from multiple systems |
| Equipment maintenance scheduling | Facilities | 3 hours | Paper-based asset logs |
| Revenue cycle performance review | Finance / Director | 3 hours | AR aging, denial rate analysis |
| Credentialing & license renewal check | HR / Admin | 2 hours | Manual expiry tracking |
| Infection control metrics reporting | Infection Control | 2 hours | Manual data aggregation |

### Quarterly Tasks

| Task | Owner | Time Spent | Pain Points |
|------|-------|------------|-------------|
| Accreditation preparation (JCI / MOH) | Admin | 1–2 weeks | Document gaps, no central repository |
| Policy & procedure review | Department Heads | 4 hours each | Version control, outdated documents |
| Drug formulary review | Pharmacy Committee | 4 hours | Evidence review, cost analysis |
| Capital equipment assessment | Facilities / Finance | 4 hours | Manual asset inventory |

---

## 3. Decision Support Requirements

### Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| Operational Overview | Hospital Administrator | Bed occupancy, ED wait time, OR utilization, daily census |
| Revenue Cycle | Finance / Director | Clean claim rate, denial rate, AR days, collections |
| Clinical Quality | Department Head | Readmission rate, infection rate, medication errors |
| Patient Flow | Ops / Nursing | Queue length, average length of stay, discharge rate |
| Pharmacy | Pharmacist / Ops | Drug stock level, expiry alerts, dispensing volume |

### Reports

| Report | Frequency | Purpose | Audience |
|--------|-----------|---------|----------|
| Daily census | Daily | Bed management | Nursing, Admin |
| OR schedule utilization | Daily | Resource planning | OR Manager |
| Claim submission status | Weekly | Revenue tracking | Billing, Finance |
| Quality indicators | Monthly | Accreditation prep | Department Heads, Admin |
| Compliance report (Sở Y tế) | Monthly | Regulatory submission | Admin, Legal |
| Infection control report | Monthly | Patient safety | Infection Control, Director |

---

## 4. Integration Touchpoints

### Internal Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **EMR / EHR → Pharmacy** | Orders → Dispensing | e-Prescription fulfillment |
| **EMR → LIS** | Lab orders → Results | Test workflow management |
| **EMR → PACS** | Imaging orders → Reports | Radiology / diagnostic integration |
| **EMR → Billing** | Diagnoses + procedures → Claims | Revenue cycle |
| **Scheduling → EMR** | Appointments → Encounters | Patient flow management |

### External Integrations

| System | Data Flow | Purpose |
|--------|-----------|---------|
| **BHYT (Vietnam Social Insurance)** | Bidirectional | Bảo hiểm y tế eligibility & claims |
| **Sở Y tế / Ministry of Health portal** | Outbound | Regulatory reporting (Decree 117/2020) |
| **Telemedicine platforms** | Bidirectional | Remote consultation, e-prescription |
| **Laboratory (external)** | Bidirectional | Outsourced tests, results integration |
| **National Drug Database** | Read-only | Drug interaction, formulary reference |
| **Insurance companies (private)** | Bidirectional | Private claim submission & adjudication |

---

## 5. KPIs & Metrics

### Patient Flow Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Appointment No-show Rate | No-shows / Scheduled × 100 | <15% |
| Average Wait Time (Outpatient) | Avg minutes from check-in to consultation | <30 min |
| Bed Occupancy Rate | Occupied beds / Total beds × 100 | 75–85% |
| Average Length of Stay (ALOS) | Total inpatient days / Discharges | Benchmark by DRG |
| ED Door-to-Doctor Time | Avg minutes from arrival to physician | <30 min |

### Clinical Quality Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Readmission Rate (30-day) | Readmissions within 30 days / Discharges × 100 | <10% |
| Patient Satisfaction (HCAHPS) | Standardized survey score | Top quartile for facility type |
| Medication Error Rate | Errors / 1,000 doses administered | <1 per 1,000 |
| Hospital-Acquired Infection Rate | HAIs / 1,000 patient-days | <1 |
| Surgical Site Infection Rate | SSIs / 100 surgical procedures | <2% |

### Revenue Cycle Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Clean Claim Rate | Claims paid first submission / Total claims × 100 | >95% |
| Denial Rate | Denied claims / Total claims × 100 | <5% |
| AR Days (Days Sales Outstanding) | AR balance / Avg daily revenue | <45 days |
| Net Collection Rate | Net collections / Net charges × 100 | >95% |
| Cost per Claim | Total billing cost / Claims processed | Varies by org size |

---

## Quick Reference: Common Bottlenecks by Area

| Area | Primary Bottleneck | Secondary Bottleneck |
|------|--------------------|----------------------|
| Outpatient | Physician documentation time | Lab result turnaround |
| Inpatient | Discharge planning delays | Bed assignment after admission |
| Pharmacy | Drug interaction review backlog | Formulary compliance queries |
| Billing | Incomplete clinical notes for coding | High denial rate from payer |
| Lab | Critical result notification speed | Specimen collection errors |
| Scheduling | No-show management | Insurance pre-authorization |
