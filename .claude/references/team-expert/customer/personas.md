# Customer Experience - User Personas

> **Domain**: Customer Experience / Trải nghiệm khách hàng
> **Last Updated**: 2026-03-22

---

## Persona 1: Support Agent (L1) — Nhân viên hỗ trợ tuyến đầu

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Front-line Support Agent — Tier 1 |
| **Experience** | 0–2 năm |
| **Report to** | Support Team Lead |
| **Focus** | First-contact resolution, ticket handling, SLA compliance |

### Daily Tasks

1. Handle inbound tickets via email, chat, and phone across assigned queues
2. Classify and prioritize tickets by category, channel, and urgency level
3. Look up knowledge base articles to resolve common issues without escalation
4. Log all customer interactions with full detail in ticketing system
5. Escalate tickets to L2/L3 when issue is outside defined resolution authority
6. Follow up on pending tickets to meet SLA response deadlines

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Assign ticket priority (Low/Medium/High/Critical) | Execute | Issue type, customer tier, SLA matrix |
| Resolve issue using KB article | Execute | Knowledge base, ticket history |
| Escalate to L2 | Execute | Escalation criteria checklist, SLA timer status |
| Issue small courtesy credit (≤ $25) | Execute | Customer order history, goodwill credit policy |
| Request account credit above limit | Request | Team Lead approval required |

### Pain Points

- Switching between 3–5 disconnected tools to resolve a single ticket
- No unified view of customer history across email, chat, and phone channels
- Knowledge base articles are outdated — agents build personal workaround notes instead
- Unclear escalation criteria leads to over-escalation and L2 pushback
- Manual copy-paste of customer data between ticketing system and CRM

### Must-have Features

- Unified inbox: all channels visible in one queue view
- Customer context panel on ticket: order history, prior tickets, subscription tier, customer tier
- KB article suggestions surfaced automatically based on ticket keywords
- One-click escalation with auto-populated escalation form
- SLA countdown timer per ticket with color-coded urgency (green / orange / red)

---

## Persona 2: Customer Success Manager (CSM) — Chuyên viên thành công khách hàng

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Customer Success Manager |
| **Experience** | 2–5 năm trong SaaS hoặc B2B services |
| **Report to** | CX Director hoặc Head of Customer Success |
| **Focus** | Retention, adoption, health scoring, expansion signals |

### Daily Tasks

1. Review health score dashboard and flag accounts dropping below threshold (< 60)
2. Conduct onboarding sessions with new accounts (Day 1–30 touchpoints)
3. Run Quarterly Business Reviews (QBR) with key stakeholders at assigned accounts
4. Log customer touchpoints and update account health notes in CRM
5. Identify expansion signals and coordinate Sales handoff for upsell opportunities
6. Respond to escalated tickets that require relationship-level engagement

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Trigger at-risk intervention playbook | Execute | Health score < 60, churn signal indicators |
| Approve service credit for retention (≤ $500) | Execute | Account ARR, credit policy, prior credit history |
| Escalate renewal risk to CX Director | Recommend | Churn probability score, account contract value |
| Initiate expansion conversation with Sales | Recommend | Usage growth trend, expansion signals, product fit |
| Extend onboarding timeline for struggling account | Execute | Adoption metrics, milestone completion rate |

### Pain Points

- Health scores are not updated in real-time — data is 24–48 hours stale
- No proactive alert when account usage drops significantly within a 7-day window
- QBR preparation requires pulling data manually from 4+ systems
- No visibility into open support tickets for accounts in own portfolio
- Expansion signals are not surfaced automatically — rely on manual periodic checks

### Must-have Features

- Real-time health score dashboard with per-account drill-down
- Automated churn risk alert when health score drops more than 10 points in 7 days
- QBR report auto-generated from product usage, support, and NPS data
- Unified account view: health score, open tickets, NPS history, billing status
- Expansion signal feed triggered by usage growth thresholds

---

## Persona 3: Support Team Lead — Trưởng nhóm hỗ trợ

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Support Team Lead / Supervisor |
| **Experience** | 3–7 năm trong support operations |
| **Report to** | CX Director |
| **Focus** | Queue management, SLA compliance, agent coaching, escalation resolution |

### Daily Tasks

1. Monitor queue health: ticket volume, SLA breach risk, agent workload distribution
2. Handle escalations from L1 that require authority beyond agent-level
3. Approve refund and credit requests above L1 threshold ($26–$500)
4. Review per-agent performance metrics: FCR, CSAT, AHT, SLA compliance rate
5. Update knowledge base with new issue resolutions and policy changes
6. Conduct daily stand-up and weekly 1:1 coaching sessions with agents

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve refund or credit ($26–$500) | Approve | Order history, refund policy, customer tier |
| Reassign ticket to specialist queue | Execute | Agent capacity, issue category, SLA status |
| Escalate to L3 (Engineering or Product) | Approve | Issue complexity, ticket history, reproduction steps |
| Apply SLA exception for VIP customer | Approve | Customer tier, SLA exception policy, contract terms |
| Suspend KB article pending accuracy review | Execute | Article flag, last-updated date, reported issue |

### Pain Points

- No real-time SLA breach forecast — alerts trigger after breach, not before
- Agent capacity data is scattered across scheduling tool and ticketing system
- Escalation to L3 requires manual email — no structured escalation path in system
- Knowledge base lacks version history — cannot audit who changed which article
- CSAT scores are not linked to individual ticket resolution, only aggregated by period

### Must-have Features

- Live queue dashboard: ticket volume by channel, SLA risk heatmap (orange/red forecast), agent workload
- SLA breach pre-alert at 80% of elapsed SLA time (proactive warning before breach)
- Per-agent performance scorecard: FCR, CSAT, AHT, SLA compliance rate
- Knowledge base with version control and change audit log (who edited, when, what changed)
- Escalation workflow with structured form, mandatory fields, and audit trail to L3

---

## Persona 4: Billing Specialist — Chuyên viên thanh toán

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Billing Specialist |
| **Experience** | 1–4 năm trong billing operations hoặc accounts receivable |
| **Report to** | Finance Manager (functional) / Support Team Lead (operational) |
| **Focus** | Billing dispute resolution, refund processing, invoice corrections |

### Daily Tasks

1. Process refund requests routed from Support queue under category "Billing"
2. Verify billing disputes against transaction records and subscription data
3. Issue invoice corrections and notify both the customer and Finance team
4. Coordinate with Finance Manager for refunds exceeding own authority (> $300)
5. Log all billing actions in ticketing system with transaction reference numbers
6. Respond to customer inquiries about invoice line items and payment methods

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Issue refund ≤ $300 | Execute | Transaction history, refund eligibility policy |
| Request refund approval > $300 | Request | Finance Manager approval required |
| Apply billing credit to future invoice | Execute | Account billing profile, credit balance limit |
| Waive late payment fee (one-time) | Execute | Payment history, customer tier, waiver policy |
| Escalate billing dispute to Finance Manager | Recommend | Dispute amount, dispute reason, supporting evidence |

### Pain Points

- No direct read access to payment gateway — relies on Finance team to pull raw transaction records
- Refund processing requires manual entry in 2 separate systems (ticketing + billing platform)
- Invoice correction workflow is email-based — no tracked approval or audit trail in system
- Customer subscription tier is not visible within the billing ticket context
- Ownership boundary between Billing Specialist and Finance is unclear for amounts $200–$500

### Must-have Features

- Billing context panel on ticket: subscription tier, payment history, outstanding balance, credit history
- Direct refund action within ticket UI (≤ $300) with write-back confirmation from billing system
- Automated routing for refund requests exceeding authority threshold (> $300) to Finance Manager
- Invoice correction workflow with structured form, Finance approval step, and full audit trail
- Boundary rule display on ticket: shows applicable approval authority based on refund amount

---

## Persona 5: CX Director — Giám đốc Trải nghiệm Khách hàng

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Director of Customer Experience / VP Customer Experience |
| **Experience** | 8+ năm trong CX, customer success, hoặc support operations |
| **Report to** | Chief Operating Officer (COO) hoặc CEO |
| **Focus** | CX strategy, NPS/CSAT targets, team performance, churn reduction, CX budget |

### Daily Tasks

1. Review executive CX dashboard: NPS trend, CSAT, churn rate, ticket SLA compliance
2. Approve refund and credit exceptions above Team Lead authority (> $500)
3. Set and review SLA policies and escalation frameworks on a quarterly basis
4. Collaborate with Product team on feedback-driven product roadmap input
5. Authorize customer recovery plans for at-risk accounts above ARR threshold
6. Prepare monthly CX performance report for C-suite and board review

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve refund or credit > $500 | Approve | Account ARR, refund history, policy precedent risk |
| Approve SLA exception policy change | Approve | SLA compliance trend data, customer impact analysis |
| Authorize customer recovery plan | Approve | Churn risk score, ARR at risk, recovery cost estimate |
| Approve knowledge base policy update | Approve | Change impact assessment, Team Lead recommendation |
| Allocate or adjust CX tooling budget | Approve | ROI analysis, current tooling gaps, headcount data |

### Pain Points

- CX data is spread across ticketing, CRM, and analytics platforms — no unified executive view
- NPS and CSAT scores are not correlated with specific journey stage or ticket category
- Churn data is post-mortem only — no leading-indicator churn risk report available
- Difficult to quantify ROI of CX investments without linked revenue and retention data
- Product feedback from support tickets is not systematically routed to Product team

### Must-have Features

- Executive CX dashboard: NPS trend, CSAT, churn rate, SLA compliance, MRR at risk — all in one view
- Feedback-to-product pipeline: aggregated themes from support tickets tagged and surfaced for Product
- Churn leading-indicator report: accounts with declining health score over 30/60/90-day windows
- Refund and credit exception approval workflow with full audit trail
- CX cost-per-resolution metric and team utilization reporting

---

## Quick Reference: Access Matrix

| Data / Function | Support Agent L1 | CSM | Support Team Lead | Billing Specialist | CX Director |
|---|:---:|:---:|:---:|:---:|:---:|
| View customer profile (name, email, company) | ✅ | ✅ | ✅ | ✅ | ✅ |
| View customer PII — phone number | ⚠ ticket context | ✅ | ✅ | ✅ | ✅ |
| View billing address | ❌ | ⚠ read only | ✅ | ✅ | ✅ |
| View payment method (last 4 digits) | ❌ | ❌ | ⚠ read only | ⚠ read only | ✅ |
| View full payment details | ❌ | ❌ | ❌ | ❌ | ❌ |
| View contract value / ARR | ❌ | ⚠ own portfolio | ⚠ own team accounts | ❌ | ✅ |
| View product usage data | ⚠ current ticket | ✅ | ✅ | ❌ | ✅ |
| View all customer tickets | ⚠ assigned only | ⚠ own portfolio | ✅ | ⚠ billing category | ✅ |
| Export customer data | ❌ | ⚠ own portfolio | ⚠ team scope | ❌ | ✅ |
| Issue refund / credit ≤ $25 | ✅ | ❌ | ✅ | ✅ | ✅ |
| Issue refund / credit $26–$300 | ❌ | ❌ | ✅ | ✅ | ✅ |
| Issue refund / credit $301–$500 | ❌ | ✅ | ❌ | ❌ | ✅ |
| Issue refund / credit > $500 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Edit knowledge base article | ❌ | ❌ | ✅ | ❌ | ✅ |
| View SLA compliance reports | ⚠ own tickets | ✅ | ✅ | ❌ | ✅ |
| View NPS / CSAT aggregate data | ❌ | ⚠ own portfolio | ✅ team view | ❌ | ✅ |
| Override SLA priority | ❌ | ❌ | ✅ | ❌ | ✅ |
| View executive CX dashboard | ❌ | ❌ | ⚠ team metrics only | ❌ | ✅ |
| Configure escalation rules | ❌ | ❌ | ⚠ recommend only | ❌ | ✅ |

> ✅ = Full access | ❌ = No access | ⚠ = Conditional (see note in column)
