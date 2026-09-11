# Playbook: Phân tích Customer Experience Requirements

> **Type**: Agent Skill Playbook
> **Agent**: customer-expert
> **Triggered by**: /wf-analyze-requirements khi có customer success/support/CX modules
> **Output**: `.mc-data/docs/phase1-business/customer-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: support, helpdesk, ticketing, NPS, CSAT, CES, customer success, onboarding, feedback, customer journey, chăm sóc khách hàng
- Khi cần xác định CX requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm/dịch vụ (SaaS, E-commerce, Marketplace, App, B2B service...)
□ Business model (B2B / B2C / B2B2C)
□ Customer segments (Enterprise, SMB, Consumer, Prosumer...)
□ Giai đoạn tăng trưởng (Pre-launch / Early stage / Growth / Scale)
□ Đã có customer support tools chưa? Nếu có → đang dùng gì? (Zendesk, Freshdesk, email queue, in-house...)
□ Số lượng ticket ước tính / tháng
□ SLA expectations của business
```

### Bước 2: Xác định CX scope cần build

Dựa trên loại business, map ra modules CX cần thiết:

| Business Type | Modules thường cần |
|--------------|-------------------|
| B2B SaaS | Customer Success, Onboarding, Support Ticketing, Health Scoring, NPS |
| B2C E-commerce | Support Ticketing, CSAT, Live Chat, Returns/Refunds workflow |
| Marketplace | Two-sided support (buyer + seller), Dispute resolution, Rating |
| Mobile App | In-app support, Push-triggered surveys, Onboarding flow |
| Enterprise Software | Dedicated CSM, QBR workflow, SLA management, Escalation paths |

```
Sau khi xác định modules → load knowledge files tương ứng:

Support Ticketing → READ: support-operations.md (Channel Strategy, SLA Framework, Escalation)
Customer Success / Onboarding → READ: success-framework.md (Onboarding Playbook, Health Score)
Customer Journey → READ: journey-mapping.md (Customer Stages, Touchpoint Categories)
Feedback / NPS / CSAT → READ: support-operations.md (Key Metrics, Customer Satisfaction)
```

### Bước 3: Map personas bị ảnh hưởng

```
READ: journey-mapping.md → Touchpoint Categories

Xác định ai sẽ dùng và ai được phục vụ bởi CX system:

INTERNAL USERS (người vận hành):
□ CS Manager → cần dashboard tổng quan, SLA alerts, team performance
□ Support Agent (L1) → cần ticket queue, knowledge base, quick reply templates
□ Customer Success Manager (CSM) → cần customer health score, onboarding tasks, QBR tools
□ Account Manager → cần customer 360 view, history, renewal signals

EXTERNAL USERS (khách hàng):
□ End Customer (B2C) → cần tự tìm câu trả lời nhanh, submit ticket dễ, biết trạng thái xử lý
□ Business Customer (B2B) → cần dedicated contact, SLA transparency, escalation path
□ Admin/IT của khách (Enterprise) → cần SSO, audit logs, permission management

Với mỗi persona: ghi lại pain points và must-have features
```

### Bước 4: Phân tích Customer Journey stages

```
READ: journey-mapping.md → Customer Stages + Emotion Mapping

Với mỗi stage liên quan đến CX:

ONBOARDING:
□ Kênh onboarding nào? (in-app tour, email sequence, CSM call)
□ Time-to-first-value target?
□ Trigger điều kiện hoàn thành onboarding?

ADOPTION/USE:
□ Self-service knowledge base cần không?
□ Proactive health monitoring?
□ In-app guidance / tooltips?

SUPPORT (khi có vấn đề):
□ Channels nào? (chat, email, phone, in-app widget)
□ SLA tiers theo severity?
□ Escalation paths?

FEEDBACK:
□ Survey triggers nào? (post-purchase, post-resolution, periodic)
□ NPS hay CSAT hay CES?
□ Closed-loop: làm gì khi có detractor?

RETENTION/EXPANSION:
□ Churn risk signals cần detect?
□ Health score thresholds → action?
□ Expansion triggers?
```

### Bước 5: Xác định SLA requirements

```
READ: support-operations.md → SLA Framework

Xác định SLA tiers phù hợp với business:

□ Priority matrix: Critical / High / Medium / Low
□ First response time per tier
□ Resolution time per tier
□ Escalation rules: khi nào escalate? Escalate lên ai?
□ Business hours vs 24/7 support?
□ SLA tracking: ai nhận alert khi SLA breach?
□ SLA reporting: báo cáo cho stakeholders tần suất nào?
```

### Bước 6: Xác định integration points

```
Với mỗi external system cần integrate:

CRM (Salesforce, HubSpot):
□ Customer 360: ticket history có visible không?
□ Sync customer data: contact, account, deal stage
□ CSM assignment từ CRM

Billing / Finance system:
□ Billing issues → route đến team nào?
□ Refund requests → approval workflow?

Marketing:
□ CSAT/NPS data → feed vào customer segmentation?
□ Detractor alerts → marketing team suppress campaigns?

Product:
□ Bug reports từ tickets → product backlog integration?
□ Feature requests → tracking + notification khi shipped

Communication tools:
□ Email (SMTP/SendGrid) cho notifications
□ Slack/Teams cho agent alerts và escalations
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-CX-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì đến CX/retention/churn]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-CX-SUP-001  → Support ticketing
REQ-CX-NPS-001  → NPS/CSAT/Feedback
REQ-CX-ONB-001  → Onboarding
REQ-CX-CSM-001  → Customer Success Management
REQ-CX-KB-001   → Knowledge base / Self-service
REQ-CX-ANA-001  → CX Analytics / Reporting
REQ-CX-ESC-001  → Escalation management
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/customer-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về CX scope)
2. CX Modules cần build (list với mô tả ngắn)
3. Personas affected (internal + external, summary)
4. Customer Journey analysis (stages, pain points, opportunities)
5. Requirements (theo module, có REQ-ID đầy đủ)
6. SLA framework đề xuất (bảng tiers)
7. Integration requirements với các department khác
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-CX-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng (link đến retention/churn/CLV)
□ SLA requirements đã được định nghĩa rõ (response + resolution per tier)
□ Self-service requirements đã included (knowledge base, FAQ)
□ Integration với CRM/Billing/Product đã noted
□ Escalation paths đã được xác định
□ Open questions được list ra để stakeholders review
□ Không có requirements nào ngoài scope CX/CS/Support
```
