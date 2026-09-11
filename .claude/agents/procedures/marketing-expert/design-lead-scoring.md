# Playbook: Design Lead Scoring & Management Module

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có Lead module
> **Output**: Lead scoring spec + Data model + Handoff protocol

---

## Khi nào dùng playbook này

- Khi cần spec module "Lead Management" hoặc "Quản lý Khách hàng tiềm năng"
- Khi thiết kế lead scoring model
- Khi thiết kế MQL definition và Marketing-to-Sales handoff

---

## Procedure

### Bước 1: Thu thập context từ business

```
□ B2B hay B2C? (ảnh hưởng scoring approach hoàn toàn)
□ Average deal size? (quyết định effort cho mỗi lead)
□ Sales cycle length? (ảnh hưởng decay rules)
□ ICP (Ideal Customer Profile): Industry, Company size, Role?
□ Có Sales team chưa? (nếu không → không cần MQL/SQL)
□ CRM platform đang dùng? (ảnh hưởng integration design)
□ Số leads/tháng hiện tại hoặc kỳ vọng?
```

### Bước 2: Đọc lead management knowledge

```
READ: lead-management.md → Toàn bộ

Key sections cần nắm:
- Lead lifecycle stages
- Demographic scoring criteria
- Behavioral scoring criteria
- Score decay rules
- MQL threshold & criteria
- Handoff protocol
- Nurture sequence templates
```

### Bước 3: Thiết kế Scoring Model

**Cho B2B:**

```
Score = Demographic Score + Behavioral Score - Decay

Bước 3a: Xác định ICP criteria → map sang Demographic scores
Bước 3b: Xác định high-intent behaviors → map sang Behavioral scores
Bước 3c: Xác định MQL threshold (recommend: 75-100)
Bước 3d: Xác định Fast-track MQL triggers
Bước 3e: Xác định decay rules
```

**Cho B2C/Consumer:**
```
Thay demographic scoring bằng:
- Acquisition source quality
- Lifecycle stage
- Purchase history
- Product usage frequency
- RFM (Recency, Frequency, Monetary)
```

**Data model:**

```
Lead:
  - id, email, first_name, last_name
  - company, job_title, company_size, industry
  - phone, location, linkedin_url
  - source, utm_source, utm_medium, utm_campaign
  - created_at, first_seen_at, last_activity_at

LeadScore:
  - lead_id
  - demographic_score, behavioral_score, total_score
  - score_grade (A/B/C/D based on thresholds)
  - last_calculated_at
  - is_mql (boolean)
  - mql_at (timestamp khi đạt MQL)

LeadScoreHistory:
  - lead_id, timestamp
  - event_type, event_value
  - score_before, score_change, score_after
  - decay_applied (boolean)

LeadActivity:
  - lead_id, activity_type, activity_data (JSON)
  - score_impact, page_url, session_id
  - created_at
```

### Bước 4: Thiết kế Lead Lifecycle States

```
States:
  anonymous → raw_lead → working_lead → mql → sal → sql → customer
                                          ↓
                                       rejected → recycled_lead
                                          ↓
                                      disqualified

Transitions và conditions:
anonymous → raw_lead:     Form submission hoặc import
raw_lead → working_lead:  Có ít nhất 1 activity sau capture
working_lead → mql:       Score ≥ threshold AND passes MQL criteria
mql → sal:                Sales accepts (< 4 giờ SLA)
sal → sql:                BANT/MEDDPICC qualified
mql → rejected:           Sales rejects với lý do
rejected → recycled_lead: Marketing decides to re-nurture
recycled_lead → working_lead: Reset behavioral score, keep demographic
```

### Bước 5: Thiết kế Nurture Sequences

```
READ: lead-management.md → Nurture Sequences section

Cho mỗi sequence, spec:
□ Name và mục đích
□ Trigger: event hoặc state change
□ Enrollment conditions: Segment nào?
□ Exit conditions: Khi nào stop sequence?
□ Email list: Số emails, delay, điều kiện branching
□ Goal conversion: Conversion nào là success cho sequence này?

Minimum sequences cần có:
1. Welcome Series (mọi new leads)
2. Educational Nurture (working leads, không engage)
3. High-Intent Nurture (near-MQL, cần push)
4. Re-engagement (inactive > 30 ngày)
5. Post-MQL Education (để Sales có context)
```

### Bước 6: Thiết kế Handoff Module

```
READ: lead-management.md → Marketing-to-Sales Handoff Protocol

Requirements:
□ Auto-notify khi lead đạt MQL (email + in-app)
□ Lead profile card: score, activity, content consumed
□ SLA timer: hiển thị thời gian còn lại trước khi overdue
□ Accept/Reject action với mandatory rejection reason
□ Rejection reason → auto-trigger appropriate nurture flow
□ Handoff history log
□ SLA compliance report (% MQLs contacted within SLA)
```

### Bước 7: Feature Spec Output

```markdown
# Feature Spec: Lead Management & Scoring

## Lead Lifecycle
[Diagram + state definitions]

## Scoring Model
### Demographic Criteria [table]
### Behavioral Criteria [table]
### Decay Rules [table]
### MQL Threshold & Criteria

## Nurture Sequences
[Per sequence: trigger, emails, goals]

## Marketing-to-Sales Handoff
[Protocol, SLAs, Accept/Reject flow]

## REQ-IDs
REQ-MKT-LEAD-001: Lead capture & enrichment
REQ-MKT-LEAD-002: Lead scoring engine (real-time)
REQ-MKT-LEAD-003: MQL qualification & notification
REQ-MKT-LEAD-004: Nurture sequence automation
REQ-MKT-LEAD-005: Sales handoff + SLA tracking
REQ-MKT-LEAD-006: Lead recycling workflow
REQ-MKT-LEAD-007: Lead analytics dashboard
```
