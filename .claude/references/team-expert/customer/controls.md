# Customer Experience - Controls & Access Management

> **Domain**: Customer Experience / Trải nghiệm khách hàng
> **Last Updated**: 2026-03-22

---

## 1. Approval Matrix — Ma trận phê duyệt

### Refund & Credit Approval by Amount

| Amount | L1 Agent | Billing Specialist | Support Team Lead | CSM | CX Director |
|--------|:--------:|:------------------:|:-----------------:|:---:|:-----------:|
| ≤ $25 (goodwill credit) | ✅ | ✅ | ✅ | ✅ | ✅ |
| $26–$300 | ❌ | ✅ | ✅ | ❌ | ✅ |
| $301–$500 | ❌ | ❌ | ❌ | ✅ | ✅ |
| $501–$2,000 | ❌ | ❌ | ❌ | ❌ | ✅ |
| > $2,000 | ❌ | ❌ | ❌ | ❌ | ⚠ CEO co-sign required |

> L1 Agent goodwill credit ≤ $25 is capped at 3 issuances per customer per calendar month.
> Refunds > $2,000 require CX Director + CEO dual approval.
> Billing Specialist authority (≤ $300) applies to billing-category tickets only.

### SLA Override Authority

| SLA Override Type | L1 Agent | Billing Specialist | Support Team Lead | CX Director |
|-------------------|:--------:|:------------------:|:-----------------:|:-----------:|
| Extend response deadline ≤ 2 hours | ❌ | ❌ | ✅ | ✅ |
| Extend response deadline > 2 hours | ❌ | ❌ | ❌ | ✅ |
| Upgrade ticket priority | ⚠ flag to Lead | ❌ | ✅ | ✅ |
| Downgrade ticket priority | ❌ | ❌ | ✅ | ✅ |
| Waive SLA breach penalty for account | ❌ | ❌ | ❌ | ✅ |

### Escalation Authorization

| Escalation Type | L1 Agent | Billing Specialist | Support Team Lead | CSM | CX Director |
|-----------------|:--------:|:------------------:|:-----------------:|:---:|:-----------:|
| L1 → L2 ticket escalation | ✅ | ✅ (billing only) | ✅ | ❌ | ✅ |
| L2 → Product bug filing | ❌ | ❌ | ✅ | ❌ | ✅ |
| Complaint → Executive escalation | ❌ | ❌ | ✅ | ✅ | ✅ |
| Account → Churn risk alert to CX Director | ❌ | ❌ | ⚠ via CSM | ✅ | — |
| Billing dispute → Finance Manager | ❌ | ✅ | ❌ | ❌ | ✅ |

---

## 2. Access Control — Kiểm soát truy cập

### Customer Data Access Matrix

| Resource | L1 Agent | Billing Specialist | Support Team Lead | CSM | CX Director |
|----------|:--------:|:------------------:|:-----------------:|:---:|:-----------:|
| Customer name, email, company | ✅ | ✅ | ✅ | ✅ | ✅ |
| Phone number (PII) | ⚠ ticket context only | ✅ | ✅ | ✅ | ✅ |
| Billing address (PII) | ❌ | ✅ | ✅ | ⚠ read only | ✅ |
| Payment method (last 4 digits) | ❌ | ⚠ read only | ⚠ read only | ❌ | ✅ |
| Full payment details | ❌ | ❌ | ❌ | ❌ | ❌ |
| Contract value / ARR | ❌ | ❌ | ⚠ own team accounts | ✅ own portfolio | ✅ |
| Product usage data | ⚠ current ticket | ❌ | ✅ | ✅ | ✅ |
| All historical support tickets | ⚠ assigned only | ⚠ billing category | ✅ | ⚠ own portfolio | ✅ |
| Internal agent notes | ❌ | ❌ | ✅ | ⚠ read only | ✅ |
| NPS verbatim responses | ❌ | ❌ | ⚠ team aggregate | ✅ own portfolio | ✅ |
| Transaction / payment records | ❌ | ✅ | ❌ | ❌ | ✅ |

> Full payment details are never exposed to any internal role — processed by billing system only.
> L1 Agent PII access is scoped to the specific ticket being handled, not stored for browsing.

### Knowledge Base Access Matrix

| KB Function | L1 Agent | Billing Specialist | Support Team Lead | CSM | CX Director |
|-------------|:--------:|:------------------:|:-----------------:|:---:|:-----------:|
| Read published articles | ✅ | ✅ | ✅ | ✅ | ✅ |
| Submit article update request | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit and publish KB articles | ❌ | ❌ | ✅ | ⚠ own domain | ✅ |
| Archive or delete articles | ❌ | ❌ | ✅ | ❌ | ✅ |
| View article analytics (views, helpfulness rate) | ❌ | ❌ | ✅ | ✅ | ✅ |

### Ownership Rules

| Scenario | Rule | Override Authority |
|----------|------|--------------------|
| Ticket assigned to agent out of office | System auto-reassigns to team queue | Support Team Lead |
| CSM absent — customer account unassigned | Interim CSM assigned from same team pod | CX Director |
| VIP account ticket unassigned for > 15 min | Auto-escalates to Team Lead queue | CX Director |
| Duplicate tickets — same customer, same issue | Merge to oldest ticket, close duplicate | L1 Agent |
| Billing ticket mis-routed to general support queue | Re-route to Billing Specialist queue | Support Team Lead |

---

## 3. Workflow Controls — Kiểm soát luồng xử lý

### Ticket State Transition Rules

| From | To | Criteria | Validation |
|------|----|----------|------------|
| New | Open | Agent accepts ticket | Agent assignment logged with timestamp |
| Open | Pending | Awaiting customer reply | Customer notified; auto-follow-up scheduled after 48h |
| Pending | Open | Customer replies | Reply received; SLA clock resumes |
| Open | Escalated | Escalation criteria met | Escalation form completed: reason, steps taken, KB articles checked |
| Escalated | Resolved | L2 or Team Lead provides fix | Resolution notes logged; customer notified |
| Open | Resolved | Solution confirmed | Resolution notes logged; workaround or fix documented |
| Resolved | Closed | 48h after resolution with no customer reopen | CSAT survey triggered automatically |
| Closed | Reopened | Customer contacts within 7 days of closure | Original ticket restored; prior CSAT voided |

### Escalation Criteria — Mandatory Triggers

| Criteria | Escalation Path | Response Timeline |
|----------|----------------|-------------------|
| Issue beyond KB coverage after 15-minute search | L1 → L2 | Immediate |
| Customer explicitly requests manager | L1 → Support Team Lead | Within 5 minutes |
| SLA elapsed > 80% with no resolution | System alert → Support Team Lead | Automated |
| VIP / Enterprise account — any Critical ticket | L1 → Team Lead → CX Director notification | Immediate |
| Suspected data breach or security incident | L1 → Security team (bypass normal L2) | Immediate |
| Same bug reported by ≥ 3 customers within 24h | L2 → Product bug channel | Within 1 hour |
| Billing dispute amount > $300 | Billing Specialist → Finance Manager | Within 1 business day |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Tickets unassigned in queue > 30 minutes | Continuous | System alert sent to Support Team Lead |
| Tickets in Pending with no follow-up > 72h | Daily | Auto follow-up email sent to customer; Team Lead notified |
| Tickets in Open status > 5 days | Weekly | Escalation prompt to Team Lead for review |
| KB articles not reviewed in > 90 days | Monthly | Article flagged as "needs review" in KB system |
| CSAT survey not sent after ticket closure | Daily | System auto-sends at closure + 1 hour |
| Refund issued without logged approval | Per refund | System blocks submission without approval record ID |
| Billing action without ticket reference | Per action | Billing system requires linked ticket ID to process |

---

## 4. Audit Trail Requirements — Yêu cầu nhật ký kiểm tra

### Customer Interaction Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Ticket created | Timestamp, channel, customer ID, agent ID, priority, category | 3 years |
| Ticket status change | Old status, new status, actor ID, timestamp, reason | 3 years |
| Escalation triggered | Trigger reason, from/to agent/tier, timestamp | 3 years |
| Ticket resolved | Resolution type, KB article referenced, time-to-resolve | 3 years |
| CSAT survey submitted | Rating, verbatim comment, ticket ID, timestamp | 3 years |
| Customer call logged | Duration, agent ID, call notes summary, outcome | 3 years |
| Onboarding milestone completed | Milestone type, customer ID, CSM ID, completion date | Lifetime of account |
| Health score change | Previous score, new score, trigger signal, timestamp | 2 years |

### Financial Action Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Refund issued | Amount, approver ID, customer ID, ticket ID, reason code | 7 years (financial compliance) |
| Credit applied to account | Amount, approver ID, expiry date, reason code | 7 years |
| Invoice correction issued | Original amount, corrected amount, reason, approver ID | 7 years |
| SLA override authorized | Override type, authorizer ID, reason, duration | 3 years |
| Subscription downgrade (customer-initiated) | Old plan, new plan, stated reason, CSM who handled | Lifetime of account |
| Account cancellation | Cancel date, reason category, ARR lost, last CSM contact date | Lifetime of account |
| Late fee waived | Amount waived, waiver authority, customer ID, ticket ID | 7 years |

### Sensitive Data Access Log

| Data Accessed | Who Can Access | Logged Fields | Purpose |
|---------------|----------------|---------------|---------|
| Customer PII (phone, billing address) | Team Lead, CSM, Billing Specialist, CX Director | Actor ID, timestamp, customer ID, access reason | GDPR audit trail |
| Payment last-4 digits | Team Lead, Billing Specialist, CX Director | Actor ID, timestamp, ticket ID | Billing dispute support |
| NPS verbatim responses | CSM (own portfolio), CX Director | Actor ID, timestamp, batch accessed | Prevent individual targeting misuse |
| Contract / ARR value | CSM (own portfolio), CX Director | Actor ID, timestamp | Revenue sensitivity |
| Agent performance data | Support Team Lead (own team), CX Director | Accessor ID, timestamp | HR data sensitivity |
| Transaction records | Billing Specialist, CX Director | Actor ID, timestamp, records accessed | Financial audit compliance |

---

## Quick Reference: Approval Checklist

### Before Issuing Refund or Credit — Trước khi phê duyệt hoàn tiền

- [ ] Confirm refund amount and match to approval tier in section 1
- [ ] Verify that approval from correct authority role is logged in system before processing
- [ ] Link refund record to originating ticket ID
- [ ] Check customer refund history — flag for CX Director review if > 3 refunds in 12 months
- [ ] Confirm billing system is updated and customer notified within 24 hours

### Before Escalating Ticket — Trước khi leo thang ticket

- [ ] At least one mandatory escalation criterion from section 3 is met and documented in ticket
- [ ] Full ticket context transferred to receiving tier: steps taken, KB articles checked, customer history
- [ ] Customer notified of escalation with estimated response timeframe
- [ ] SLA clock status recorded at the moment of escalation handoff

### Before Closing Ticket — Trước khi đóng ticket

- [ ] Resolution confirmed by customer OR 48-hour no-reply rule has elapsed
- [ ] Resolution notes logged: workaround applied, fix delivered, or KB article used
- [ ] CSAT survey queued for sending
- [ ] If a product bug was reported: Product bug ticket is linked to this support ticket
