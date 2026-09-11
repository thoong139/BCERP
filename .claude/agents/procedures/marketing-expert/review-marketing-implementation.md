# Playbook: Review Marketing Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-implement-feature khi review marketing code
> **Output**: Code review report từ marketing domain perspective

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của marketing module
- Khi cần validate implementation từ business logic perspective
- Khi cần check compliance (consent, privacy, tracking)

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Campaign Management → check campaign hierarchy, approval workflow
□ Lead Management → check scoring logic, handoff SLA
□ Email Automation → check consent, deliverability, sequences
□ Analytics/Tracking → check UTM, event tracking, attribution
□ Social Media → check platform integrations, content workflow
□ Growth/Referral → check viral mechanics, reward distribution
```

### Bước 2: Load controls knowledge

```
READ: controls.md → Luôn làm, bất kể module nào

Compliance checklist áp dụng cho mọi marketing module:
□ Consent: Có require opt-in trước khi gửi marketing comms?
□ Unsubscribe: Có xử lý unsubscribe ngay lập tức không?
□ Data retention: Có implement retention policy không?
□ PII handling: Email, phone, tên có được encrypt/mask đúng?
□ Audit trail: Có log consent actions không?
```

### Bước 3: Review theo module type

**Campaign Management:**
```
□ Campaign hierarchy đúng không? (Campaign → Channel → AdGroup → Ad)
□ Budget validation: Có check không vượt budget không?
□ Approval workflow: Thresholds đúng không? Có bypass không?
□ UTM auto-generation: Format đúng chuẩn? (lowercase, no spaces)
□ Status transitions: State machine đúng không? (Draft → Active → Paused)
□ Attribution: Campaign ID có được pass đến CRM không?
```

**Lead Management:**
```
□ Scoring engine: Real-time hay batch? Có decay logic không?
□ Score calculation: Công thức đúng không? (Demographic + Behavioral - Decay)
□ MQL threshold: Logic trigger đúng không? All criteria checked?
□ Handoff notification: Gửi trong SLA không? (Demo: <1h, MQL: <4h)
□ Consent check: KHÔNG được pass lead sang Sales nếu thiếu consent
□ Duplicate detection: Có merge logic không?
□ Lead recycling: Khi reject, có reset đúng fields không?
```

**Email Automation:**
```
□ Consent gate: Không gửi email nếu marketing_opt_in = false
□ Frequency capping: Có respect cap/tuần không?
□ Unsubscribe: One-click unsubscribe hoạt động không? Immediate effect?
□ SPF/DKIM: Có config đúng không? (check DNS records)
□ Hard bounce: Có auto-suppress ngay không?
□ Spam complaint: Có auto-suppress ngay không?
□ Sequence exit: Có exit khi goal achieved không? (không gửi tiếp)
□ Personalization tokens: Có fallback khi field trống không?
□ Send time: Có respect timezone không?
```

**Analytics/Tracking:**
```
□ UTM capture: Được lưu ở form submit không?
□ UTM preservation: Được pass đến CRM không?
□ Event firing: Có double-firing không? (count 2x)
□ Conversion dedup: Có prevent duplicate conversions không?
□ Cross-device: Anonymous ID và User ID có merge đúng không?
□ GDPR compliance: Tracking bị disabled khi user không consent không?
□ Data anonymization: IP address có bị truncate theo GDPR không?
□ PII in events: Có accidentaly log PII vào event properties không?
```

### Bước 4: Performance Check

```
□ Email sending: Có rate limiting không? (tránh spam blacklist)
□ Bulk operations: Có queue/batch processing không? (không block main thread)
□ Lead score recalc: Có trigger toàn bộ leads không? (performance risk)
□ Analytics queries: Có indexes đúng trên date columns không?
□ Real-time events: Có async processing không?
□ External API calls: Có retry logic? Timeout? Circuit breaker?
```

### Bước 5: Output — Review Report

```markdown
# Marketing Implementation Review: [Module Name]

## Compliance Status: ✅ PASS / ❌ FAIL / ⚠️ NEEDS ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [Location in code] → [Required fix]

## Important Issues (fix before next sprint)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Compliance Checklist
[Table: Item | Status | Notes]

## Performance Concerns
[List any performance issues found]

## Sign-off
□ Consent compliance: OK / ISSUE
□ Tracking accuracy: OK / ISSUE
□ Business logic: OK / ISSUE
□ Error handling: OK / ISSUE
```
