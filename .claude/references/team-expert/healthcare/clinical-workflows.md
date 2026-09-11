# Clinical Workflows Reference

> Reference file cho healthcare-expert agent
> Load file này khi cần hiểu về clinical workflows trong domain Healthcare

## Patient Care Workflows

### 1. Outpatient Visit Workflow

```
Schedule → Check-in → Vitals → Provider Encounter → Orders → Check-out
```

**Detailed Steps:**

| Step | Actions | System Support |
|------|---------|----------------|
| Schedule | Book appointment, assign provider | Scheduling module |
| Check-in | Verify demographics, insurance, collect forms | Registration |
| Vitals | Weight, BP, temperature, pulse | Vitals documentation |
| Encounter | History, exam, assessment, plan | Clinical documentation |
| Orders | Labs, imaging, meds, referrals | CPOE |
| Check-out | Follow-up, education, payment | Billing |

---

### 2. Inpatient Admission Workflow

```
Admission Order → Registration → Bed Assignment → Nursing Assessment →
Provider Assessment → Ongoing Care → Discharge Planning → Discharge
```

**ADT Events (Admission-Discharge-Transfer):**

| Event | Description | System Impact |
|-------|-------------|---------------|
| Admission | Patient enters facility | Create encounter, assign bed |
| Transfer | Move between units/beds | Update location |
| Discharge | Patient leaves facility | Close encounter, generate summary |

---

### 3. Medication Administration

```
Order → Pharmacy Review → Dispense → Administration → Documentation
```

**Five Rights of Medication:**
- Right patient
- Right medication
- Right dose
- Right route
- Right time

**MAR (Medication Administration Record):**
| Field | Description |
|-------|-------------|
| Medication | Drug name, strength |
| Dose | Amount to give |
| Route | How administered |
| Frequency | How often |
| Time | Scheduled time |
| Status | Given, held, refused |

---

### 4. Laboratory Workflow

```
Order → Collect → Process → Analyze → Result → Review
```

**Specimen Collection:**
- Patient identification (2 identifiers)
- Label at bedside
- Time stamp
- Collector ID

**Result Communication:**
| Result Type | Action |
|-------------|--------|
| Critical | Immediate call to provider |
| Abnormal | Flag in system, notify |
| Normal | Available in portal |

---

### 5. Discharge Process

```
Discharge Order → Discharge Summary → Patient Education →
Medication Reconciliation → Follow-up Instructions → Discharge
```

**Discharge Summary Elements:**
- Admission diagnosis
- Procedures performed
- Condition at discharge
- Medications at discharge
- Follow-up instructions
- Patient education provided

---

## Care Coordination

### Handoff Communication (SBAR)

| Element | Information |
|---------|-------------|
| Situation | What's happening now |
| Background | Relevant history |
| Assessment | Your assessment |
| Recommendation | What you recommend |

### Multidisciplinary Rounds

- Daily team huddles
- Review all patients
- Plan of care updates
- Discharge planning

---

## Clinical Decision Support

### Alert Types

| Alert | Purpose | Example |
|-------|---------|---------|
| Drug interaction | Safety | Duplicate therapy warning |
| Allergy | Safety | Penicillin allergy alert |
| Reminder | Quality | Screening overdue |
| Best practice | Standardization | Protocol suggestion |

---

## Key Performance Indicators

### Quality Metrics

| Metric | Target |
|--------|--------|
| Hospital-acquired infections | < 1 per 1000 patient days |
| Medication errors | < 1 per 1000 doses |
| Patient falls | < 2 per 1000 patient days |
| Pressure ulcers | < 2% |
| Readmission rate (30-day) | < 10% |

### Operational Metrics

| Metric | Target |
|--------|--------|
| Average length of stay | Benchmark varies |
| Bed occupancy | 75-85% |
| ED wait time | < 30 min to provider |
| Surgery on-time starts | > 85% |
