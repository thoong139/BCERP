# Playbook: Review Customer Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: customer-expert
> **Triggered by**: /wf-implement-feature khi review code của customer support/success/feedback module
> **Output**: Customer implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của CX modules
- Khi cần validate implementation từ domain perspective (SLA logic, escalation rules, CSAT triggers)
- Khi cần check compliance access control, customer data protection
- Keywords kích hoạt: support module, ticket system, NPS, CSAT, onboarding, customer success code

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type từ task prompt:

□ Support Ticketing → check ticket lifecycle, SLA calculation, escalation rules
□ Feedback / NPS / CSAT → check survey triggers, closed-loop alerts, cooldown logic
□ Customer Success / Onboarding → check health score logic, milestone tracking
□ Knowledge Base → check article versioning, search, deflection tracking
□ CX Analytics / Dashboard → check metric calculations, data aggregation

Load context:
READ: support-operations.md → nếu review ticketing hoặc SLA
READ: success-framework.md → nếu review CS, health score, onboarding
READ: journey-mapping.md → nếu review touchpoint, journey analytics
```

### Bước 2: Review CX Requirements compliance

```
Đọc requirements từ req-registry.json hoặc phase2-features:
□ Xác định REQ-CX-* IDs liên quan đến module đang review
□ Liệt kê từng acceptance criteria
□ Check từng criterion trong code

Mỗi REQ-ID:
□ Code có reference REQ-ID đúng format trong comment không?
□ Logic implement đúng acceptance criteria không?
□ Edge cases đã được handle chưa?
```

### Bước 3: Review SLA Calculation Accuracy

```
[Áp dụng khi review ticketing module]

READ: support-operations.md → SLA Framework

Checklist SLA engine:
□ SLA clock bắt đầu tính từ đúng event? (ticket created / first customer message?)
□ Business hours được config và áp dụng đúng không? (P1+ bypass business hours)
□ SLA pause khi ticket PENDING (chờ khách) có implement không?
□ SLA resume khi khách reply có implement không?
□ SLA breach detection: trigger alert đúng lúc không? (80% warning, 100% breach)
□ Timezone handling: SLA tính theo timezone của khách hay timezone của team?
□ Daylight saving time: SLA engine có handle DST transition không?
□ Holiday calendar: có config ngày nghỉ không? SLA có skip ngày nghỉ không?
□ Priority escalation: khi priority thay đổi giữa chừng, SLA có recalculate không?
□ MTTR calculation: tính từ created đến closed, hay tính cả thời gian pending?

SLA reporting:
□ SLA compliance % được tính đúng chưa? (denominator là gì?)
□ Có exclude P0 khỏi business-hours SLA không?
□ Historical SLA data có được preserve khi priority thay đổi không?
```

### Bước 4: Review Escalation Rule Correctness

```
Escalation triggers — check từng rule:
□ SLA breach trigger: khi nào fire? (100% breach hay sớm hơn?)
□ Customer request trigger: detect "supervisor" / "manager" keyword trong message?
□ Ticket age trigger: open > N giờ không có activity → alert?
□ Manual escalation: agent có thể escalate bất kỳ lúc nào không?
□ Sentiment trigger (nếu có): từ ngữ tiêu cực trong customer message?

Escalation routing:
□ Escalation notify đúng người không? (L2 agent, not all agents)
□ Manager notification: chỉ P0/P1 hay tất cả escalations?
□ Slack/Teams integration: message format có đủ context không?
  Bắt buộc: ticket ID, customer name, issue summary, SLA status, priority
□ Escalation không bị loop: đã escalate rồi không escalate lại lần nữa?

Escalation state machine:
□ ESCALATED là state riêng hay chỉ là flag?
□ Khi escalation resolved, ticket trở về state gì?
□ Escalation history được log không? (ai escalate, khi nào, lý do gì)
```

### Bước 5: Review CSAT Trigger Reliability

```
[Áp dụng khi review CSAT / feedback module]

READ: support-operations.md → Customer Satisfaction

Trigger timing:
□ CSAT chỉ send sau ticket CLOSED? (không send khi RESOLVED nhưng chưa closed)
□ Delay đúng số giờ config sau close event?
□ Nếu khách reopen ticket → có cancel pending CSAT survey không?
□ Duplicate send: cùng ticket không gửi CSAT 2 lần?

Cooldown enforcement:
□ Global cooldown (30 ngày / khách) có được check trước khi send không?
□ Cooldown được store ở đâu? (db, cache) → có race condition không?
□ Unsubscribe được respect ngay lập tức không?

Survey delivery:
□ Email delivery failure được log không?
□ Bounce / invalid email → suppression list không?
□ Survey link expiry: link có expire sau N ngày không?
□ Survey accessible khi chưa login không? (one-click từ email)

Response processing:
□ Response được lưu với ticket_id reference không?
□ Detractor alert fire ngay khi submit không? (< 5 phút)
□ Closed-loop task được tạo tự động không? Assign cho đúng CSM không?
□ CSAT score được update vào agent performance stats không?
□ Race condition: 2 responses cùng lúc cho 1 survey → xử lý thế nào?
```

### Bước 6: Review Access Control

```
Customer data access — principle of least privilege:

Support Agent (L1):
□ Chỉ xem tickets ASSIGNED cho mình hoặc unassigned trong queue
□ KHÔNG xem tickets của team khác
□ KHÔNG xem account financial details
□ CÓ xem customer contact info (để liên hệ)
□ KHÔNG edit account data

L2 Specialist:
□ Xem tất cả tickets trong domain của mình
□ Có thể reassign tickets
□ CÓ xem extended customer history

Manager / Admin:
□ Xem tất cả tickets
□ Full access SLA reports, agent performance
□ Config SLA, routing rules, escalation rules

Customer (self-service portal):
□ Chỉ xem tickets của chính mình
□ KHÔNG xem tickets của khách khác (multi-tenant isolation)
□ Có thể add comment, upload attachment
□ KHÔNG thể change priority / assignment

API access:
□ API keys scoped đúng (không dùng master key cho integration)
□ Webhook payloads không expose PII không cần thiết
□ Rate limiting trên public endpoints
```

### Bước 7: Review Integration với CRM

```
Customer 360 view:
□ Ticket list có visible trong CRM contact record không?
□ Sync tần suất: real-time hay batch? Delay tối đa?
□ Field mapping đúng không? (ticket status → CRM activity type)
□ Khi customer record bị merge trong CRM → ticket history có migrate không?

CSM Assignment:
□ Khi ticket created → có lookup CSM từ CRM không?
□ CSM assignment được dùng cho escalation routing không?
□ Nếu CRM unavailable → fallback routing là gì? (không bị unassigned)

Data consistency:
□ Customer name/email update trong CRM → có sync sang support tool không?
□ Conflict resolution: nếu email thay đổi trong 2 system → system nào win?
□ Soft delete: khi account deactivated trong CRM → ticket history được giữ không?
```

### Bước 8: Review Performance với high-volume ticket queue

```
Database queries:
□ Ticket list query: có pagination không? (không load tất cả)
□ Search query: có full-text index không?
□ SLA recalculation: batch job hay real-time? → khi có nhiều tickets cần recalc?
□ Report queries: có pre-aggregation / materialized view cho dashboards không?
□ Index trên: ticket.status, ticket.assigned_to, ticket.created_at, ticket.priority

API performance:
□ Ticket list endpoint: response time < 200ms với 10,000 tickets?
□ Bulk operations (mass reassign, bulk close): có async job không?
□ Webhook delivery: có retry với exponential backoff không?
□ Rate limiting để tránh API abuse

File attachments:
□ Attachment upload: có virus scan không?
□ File size limit enforce ở client và server?
□ Attachments stored ở đâu? (S3 / local disk) → backup?

Real-time features:
□ Live ticket updates: WebSocket hay polling? Polling interval?
□ Agent presence / status: có race condition khi nhiều agents online?
□ CSAT email queue: có rate limiting để tránh email flood?
```

### Bước 9: Output — Review Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase5-implementation/review-customer-[module]-[date].md

---
# Customer Implementation Review: [Module Name]

## Compliance Status: PASS / FAIL / NEEDS ATTENTION

## Critical Issues (chặn go-live)
- [ ] [Issue]: [File / function] → [Required fix]

## Important Issues (fix trước sprint tiếp theo)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Domain Compliance Checklist
| Item | Status | Notes |
|------|--------|-------|
| SLA calculation accuracy | OK / ISSUE | |
| Escalation rules | OK / ISSUE | |
| CSAT trigger reliability | OK / ISSUE | |
| Access control | OK / ISSUE | |
| CRM integration | OK / ISSUE | |
| REQ-ID references in code | OK / ISSUE | |

## Performance Concerns
[List any performance issues found]

## Sign-off
□ CX Business logic: OK / ISSUE
□ SLA correctness: OK / ISSUE
□ Data access control: OK / ISSUE
□ Integration integrity: OK / ISSUE
□ Performance under load: OK / ISSUE
---
```

---

## Checklist trước khi submit

```
□ Đã xác định đúng module type và load knowledge files tương ứng
□ Tất cả REQ-CX-* IDs được check từng acceptance criteria
□ SLA calculation: business hours, pause/resume, timezone, DST
□ Escalation: trigger conditions, routing, không có loops
□ CSAT: cooldown, duplicate prevention, detractor alert timing
□ Access control: agent chỉ xem assigned tickets
□ CRM sync: field mapping, conflict resolution, fallback
□ Performance: pagination, index, bulk async
□ Critical issues được phân biệt rõ với suggestions
□ Sign-off checklist đã điền đầy đủ
```
