# Playbook: Design Email Automation Module

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi có Email module
> **Output**: Email automation spec + Sequence designs + Deliverability requirements

---

## Khi nào dùng playbook này

- Khi cần spec module "Email Marketing" hoặc "Marketing Automation"
- Khi thiết kế email sequences, trigger flows
- Khi review email deliverability requirements

---

## Procedure

### Bước 1: Xác định scope email automation

```
□ Loại emails cần support:
  - Transactional (order confirm, password reset) → thường tách riêng
  - Marketing automation (nurture, lifecycle) → scope này
  - Newsletters / broadcasts → bulk sending
  - Triggered / behavioral (based on actions) → automation engine

□ Volume ước tính: Contacts? Emails/tháng?
□ Personalization level cần: Basic / Segment / Behavioral / AI-driven?
□ Integration: Có CRM không? Lead scoring?
□ Consent model: Single opt-in hay Double opt-in?
□ Multi-language cần không?
```

### Bước 2: Đọc email knowledge

```
READ: digital-channels.md → Section 4: Email Marketing

Key sections:
- Email Types & Requirements (triggers, consent, frequency)
- Deliverability Requirements (SPF/DKIM, list hygiene)
- Personalization Levels
```

### Bước 3: Thiết kế Email Data Model

```
EmailTemplate:
  - id, name, type (welcome/nurture/promo/transactional)
  - subject, preview_text
  - html_body, text_body
  - personalization_tokens (JSON: [{token, source_field}])
  - created_by, version, status (draft/active/archived)

EmailSequence:
  - id, name, description, goal
  - trigger_event, trigger_conditions (JSON)
  - enrollment_filters (JSON: segment criteria)
  - exit_conditions (JSON: event-based or state-based)
  - status (draft/active/paused)

SequenceStep:
  - sequence_id, step_number
  - delay_value, delay_unit (hours/days)
  - delay_from (previous_step / sequence_start / trigger_event)
  - template_id
  - send_conditions (JSON: branch logic)
  - goal_event (optional: if user does X, mark step complete)

EmailSend:
  - contact_id, template_id, sequence_id, step_id
  - subject (rendered), from_email, from_name
  - sent_at, opened_at, clicked_at, replied_at, bounced_at, unsubscribed_at
  - status (queued/sent/delivered/opened/clicked/bounced/spam/unsubscribed)

ContactEmailPreferences:
  - contact_id, email
  - marketing_opt_in (boolean), marketing_opt_in_at, opt_in_method
  - transactional_opt_in (boolean)
  - frequency_cap (override)
  - unsubscribed_at, unsubscribe_reason
  - bounced (boolean), bounce_type (hard/soft), bounce_count
  - last_engaged_at
```

### Bước 4: Thiết kế Sequence Flows

**Sequence Builder Requirements:**
```
□ Visual drag-drop builder (Step → Delay → Step → Branch)
□ Branch conditions: If [event] / If [field] = [value] → different path
□ A/B test at step level (subject line, template)
□ Wait for event: "Mục tiêu đạt được → exit sequence"
□ Time window: Chỉ gửi trong business hours
□ Smart send time: Optimize per contact timezone
```

**Standard Sequences spec:**

| Sequence | Trigger | Exit condition | Steps |
|----------|---------|----------------|-------|
| Welcome | New contact opt-in | Purchases / Requests demo | 4 emails / 2 tuần |
| Trial Onboarding | Trial starts | Converts to paid | 7 emails / 2 tuần |
| Lead Nurture | Score = working_lead | Reaches MQL | Weekly edu content |
| High-Intent | Score > 60 (near-MQL) | Reaches MQL | 3 emails / 1 tuần |
| Re-engagement | Inactive 30 days | Clicks any email | 3 emails / 2 tuần |
| Post-purchase | Payment confirmed | - | 3 emails / 1 tháng |
| Win-back | Cancelled subscription | Re-subscribes | 5 emails / 3 tuần |

### Bước 5: Thiết kế Deliverability Requirements

```
READ: digital-channels.md → Deliverability Requirements

Technical requirements:
□ SPF record configuration
□ DKIM signing (1024-bit minimum, 2048-bit recommended)
□ DMARC policy (start with p=none, then p=quarantine)
□ Custom sending domain (no shared IP for high volume)
□ BIMI (Brand Indicators for Message Identification) — nên có

List hygiene automation:
□ Hard bounce → immediately suppress, flag as invalid
□ Soft bounce × 3 → suppress temporarily
□ Spam complaint → immediately suppress + unsubscribe
□ Inactive 6 months → move to re-engagement sequence
□ Inactive after re-engagement → unsubscribe

Frequency capping:
□ Max emails per contact: configurable (default: 3/week marketing)
□ Override: transactional always send regardless of cap
□ Cooldown after unsubscribe attempt: 24 hours
```

### Bước 6: Thiết kế Consent Management

```
READ: controls.md → Consent section

Consent flow:
Single opt-in:  Form submit → immediately subscribed (simpler, higher list size)
Double opt-in:  Form submit → confirmation email → click → subscribed (better quality)

Consent audit trail requirements:
□ Log: contact_id, consent_type, method, timestamp, IP, form_id, UTM
□ Immutable: không được modify consent records
□ Exportable: để respond to data subject requests
□ Retention: theo quy định (GDPR: vô thời hạn khi đang subscribed + 3 năm sau unsubscribe)

Preference center:
□ Cho phép chọn email categories
□ Frequency preferences
□ One-click global unsubscribe
□ Pause option (1-3 months, thay vì unsubscribe hoàn toàn)
```

### Bước 7: Thiết kế Analytics

```
READ: metrics-framework.md → Email Metrics

Per email / per sequence metrics:
□ Sent, Delivered, Delivery rate
□ Open rate, Unique opens
□ Click rate, Click-to-open rate (CTOR)
□ Unsubscribe rate, Spam complaint rate
□ Bounce rate (hard/soft breakdown)
□ Conversion rate (goal completions / sent)
□ Revenue attributed (nếu có e-commerce integration)

Alerts:
□ Spam complaint rate > 0.1% → immediate alert + pause
□ Bounce rate > 5% → alert + list hygiene trigger
□ Unsubscribe rate > 1% → alert + content review
□ Open rate drops > 30% vs 4-week avg → alert
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Email Automation

## REQ-IDs
REQ-MKT-EMAIL-001: Email template builder (drag-drop + HTML)
REQ-MKT-EMAIL-002: Sequence/automation builder với visual flow
REQ-MKT-EMAIL-003: Trigger-based enrollment (event + segment)
REQ-MKT-EMAIL-004: A/B testing per step
REQ-MKT-EMAIL-005: Deliverability infrastructure (SPF/DKIM/DMARC)
REQ-MKT-EMAIL-006: List hygiene automation
REQ-MKT-EMAIL-007: Consent management + preference center
REQ-MKT-EMAIL-008: Performance analytics per email/sequence
REQ-MKT-EMAIL-009: Frequency capping
REQ-MKT-EMAIL-010: CRM sync (bi-directional, real-time)
```
