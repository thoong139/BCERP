# Customer Success Framework

> Reference file cho customer-expert agent
> Load file này khi cần thiết kế hệ thống CS

## Customer Success Maturity Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                   REACTIVE                  │
│             (Churn management, basic support)                │
├─────────────────────────────────────────────────────────────────────┤
│                   PROACTIVE                 │
│        (Health scoring, risk identification)                │
├─────────────────────────────────────────────────────────────────────┤
│                  PREDICTIVE                  │
│      (Expansion, advocacy identification)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Health Score Framework

### Health Score Components
| Factor | Weight | Indicators |
|--------|--------|------------|
| Product usage | 30% | Login frequency, feature adoption |
| Engagement | 25% | Support tickets, NPS responses |
| Financial | 25% | Contract value, payment history |
| Relationship | 20% | Stakeholder interactions, expansion potential |

### Health Score Calculation
```
Health Score = (Usage Score × 0.30) + (Engagement Score × 0.25) +
                (Financial Score × 0.25) + (Relationship Score × 0.20)
```

### Health Bands
| Score | Status | Action |
|-------|--------|--------|
| 80-100 | Excellent | Expansion opportunities, testimonials |
| 60-79 | Good | Regular check-ins, upsell opportunities |
| 40-59 | Fair | Increased monitoring, proactive outreach |
| 20-39 | At Risk | Immediate intervention, recovery plan |
| 0-19 | Critical | Executive escalation, intensive support |

---

## Customer Success Journey

### Onboarding Phase
| Day | Activities | Success Metrics |
|-----|------------|------------------|
| 1 | Welcome email, login credentials | Login rate |
| 2-7 | Product tours, initial training | Feature activation |
| 8-14 | First value milestone | Time to value |
| 15-30 | Regular usage patterns | Adoption rate |

### Adoption Phase
| Phase | Activities | Success Metrics |
|-------|------------|------------------|
| Month 1-3 | Regular check-ins, usage tips | Engagement score |
| Month 4-6 | Power user identification | Feature depth |
| Month 7-12 | Success planning | Upsell readiness |

### Expansion Phase
| Trigger | Activities |
|---------|------------|
| Usage growth | Add seats, upgrade discussions |
| New use cases | Cross-sell opportunities |
| Advocacy signals | Reference program, case studies |

---

## Playbook Components

### Onboarding Playbook
| Day | Touchpoint | Owner | Content |
|-----|------------|-------|---------|
| 1 | Welcome email | System | Credentials, getting started guide |
| 3 | Training invite | CS Team | Calendar invite, agenda |
| 7 | Success milestone | Product | In-app celebration, email |
| 14 | Check-in | CSM | Call to review progress, answer questions |
| 30 | QBR session | CSM | Business review, success plan |

### Quarterly Business Review (QBR)
| Section | Content |
|---------|---------|
| Accomplishments | Key wins, value delivered |
| Usage metrics | Adoption, engagement |
| Roadmap preview | Upcoming features, timeline |
| Challenges | Blockers, support needed |
| Action items | Next steps, goals |

---

## Risk Identification

### Churn Indicators
| Signal | Weight | Action |
|--------|--------|--------|
| Login drop | High | Immediate outreach |
| Feature usage decline | Medium | Check-in call |
| Support ticket increase | Medium | Proactive contact |
| NPS drop | High | Executive escalation |
| Payment delay | High | Finance collaboration |

### At-Risk Playbook
| Trigger | Action | Timeline |
|---------|---------|---------|
| Health score drops below 60 | CSM outreach | Within 24 hours |
| Multiple negative signals | Executive escalation | Immediate |
| Churn confirmed | Retention offer | Same day |

---

## Expansion Signals
| Signal | Action |
|--------|--------|
| Growing usage | Cross-sell opportunity |
| Multiple positive feedback | Request testimonial |
| Referral inquiry | Activate referral program |
| Expansion request | Present upgrade options |

---

## Success Metrics

### Team KPIs
| Metric | Target |
|--------|--------|
| Gross churn rate | < 5% monthly |
| Net retention rate | > 100% |
| Health score average | > 70 |
| Time to first value | < 30 days |
| Expansion rate | > 20% |

### Individual KPIs
| Metric | Target |
|--------|--------|
| Response time (first contact) | < 4 hours |
| Customer satisfaction (CSAT) | > 90% |
| QBR completion rate | 100% |
| Renewal rate | > 90% |

---

## Communication Templates

### Health Check-in Email
```
Hi [Name],

I wanted to check in on how things are going with [Product].

[Quick health score summary]
[Key metrics]

[Recent highlights]

[Questions or concerns?]

Let me know if you'd like to schedule a quick call.

Best regards,
[CS Manager]
```

### At-Risk Alert
```
Subject: Attention needed: [Account] account health

Hi [POC/Sponsor name],

Your health score has dropped to [score], indicating potential risk of churn.

Key indicators:
- [Indicator 1]
- [Indicator 2]

Last activity: [date]

Our team is reaching out to ensure your success. Can we schedule a call this week?

Please let me know your availability.

Best regards,
[CS Manager]
```
