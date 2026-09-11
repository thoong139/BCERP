# Sales Domain - User Personas

> **Domain**: Sales / Quản trị Bán hàng
> **Last Updated**: 2026-03-07

---

## Persona 1: Sales Representative

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Sales Representative |
| **Experience** | 1-5 năm |
| **Report to** | Sales Manager |
| **Focus** | Pipeline management, Deal closing |

### Daily Tasks
1. Follow up với leads và opportunities
2. Update opportunity stages trong CRM
3. Create và send quotations
4. Conduct product demos
5. Negotiate với prospects

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Apply standard discount (≤5%) | Execute | Price list, margin |
| Create quotation | Execute | Product info, pricing |
| Move opportunity stage | Execute | Qualification criteria |
| Request discount approval | Request | Deal size, justification |

### Pain Points
- Manual quote generation
- Lost opportunities do to slow follow-up
- No visibility vào inventory availability
- Duplicate data entry

### Must-have Features
- ✅ Mobile CRM access
- ✅ Quick quote generation
- ✅ Real-time inventory check
- ✅ Automated follow-up reminders

---

## Persona 2: Sales Manager

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Sales Manager |
| **Experience** | 5-10 năm |
| **Report to** | Sales Director |
| **Focus** | Team performance, Forecasting |

### Daily Tasks
1. Review team pipeline
2. Approve quotations và discounts
3. Coach team members
4. Forecast revenue
5. Handle escalations

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve discount (≤15%) | Approve | Deal margin, customer history |
| Assign leads | Execute | Lead scoring, rep capacity |
| Override territory | Execute | Justification |
| Approve special pricing | Recommend | Competitive analysis |

### Pain Points
- Inaccurate sales forecasts
- No visibility into individual rep performance
- Manual pipeline reviews
- Slow approval turnaround

### Must-have Features
- ✅ Pipeline dashboard
- ✅ Forecast analytics
- ✅ Approval workflow mobile
- ✅ Team performance metrics

---

## Persona 3: Sales Director

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Sales Director / VP Sales |
| **Experience** | 10+ năm |
| **Report to** | CEO / CRO |
| **Focus** | Strategy, Revenue targets |

### Daily Tasks
1. Monitor overall revenue performance
2. Strategic account reviews
3. Approve large deals
4. Set sales targets
5. Coordinate với other departments

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve discount (>15%) | Approve | Deal size, strategic value |
| Set territory rules | Execute | Market analysis |
| Approve non-standard terms | Approve | Legal review |
| Adjust quotas | Execute | Performance data |

### Pain Points
- Lack of strategic insights
- No real-time revenue visibility
- Difficulty predicting quarter
- Manual executive reporting

### Must-have Features
- ✅ Executive dashboard
- ✅ Revenue analytics
- ✅ Strategic account view
- ✅ Automated reporting

---

## Persona 4: Sales Operations

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Sales Operations Analyst |
| **Experience** | 3-5 năm |
| **Report to** | Sales Director |
| **Focus** | Process, Systems, Analytics |

### Daily Tasks
1. Maintain CRM data quality
2. Generate sales reports
3. Configure system settings
4. Manage territories
5. Calculate commissions

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Update CRM fields | Execute | Business requirements |
| Generate reports | Execute | Report parameters |
| Adjust territory alignment | Recommend | Performance data |
| Commission calculations | Execute | Sales data, plan rules |

### Pain Points
- Manual data cleanup
- Report requests backlog
- Commission calculation errors
- Territory conflicts

### Must-have Features
- ✅ Data quality tools
- ✅ Report builder
- ✅ Commission calculator
- ✅ Territory management

---

## Persona 5: Inside Sales Rep

### Profile
| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Inside Sales Representative |
| **Experience** | 1-3 năm |
| **Report to** | Sales Manager |
| **Focus** | High-volume, Quick turnaround |

### Daily Tasks
1. Handle inbound leads
2. Make outbound calls
3. Process small orders
4. Cross-sell/upsell
5. Update CRM records

### Key Decisions
| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Qualify lead | Execute | Lead scoring criteria |
| Apply standard terms | Execute | Price book |
| Close small deal (<threshold) | Execute | Credit check |
| Escalate to Field Sales | Execute | Deal size, complexity |

### Pain Points
- High volume, low visibility
- Repetitive data entry
- No call integration
- Slow quote generation

### Must-have Features
- ✅ Call integration (CTI)
- ✅ Lead queue management
- ✅ Quick order entry
- ✅ Script/templates

---

## Quick Reference: Sales Persona Access Matrix

| Data/Function | Sales Rep | Inside Sales | Sales Manager | Sales Director | Sales Ops |
|---------------|:---------:|:------------:|:-------------:|:--------------:|:---------:|
| Own opportunities | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ View |
| Team opportunities | ❌ | ❌ | ✅ Full | ✅ Full | ✅ View |
| All opportunities | ❌ | ❌ | ⚠ Territory | ✅ Full | ✅ Full |
| Pricing | ✅ Standard | ✅ Standard | ✅ Discounts | ✅ Full | ✅ View |
| Quotations | ✅ Create | ✅ Create | ✅ Approve | ✅ Approve | ✅ View |
| Reports | ⚠ Own only | ⚠ Own only | ✅ Team | ✅ Full | ✅ Full |
| Commission data | ✅ Own | ✅ Own | ⚠ Team | ✅ Full | ✅ Calculate |

---

## Quick Reference: Pipeline Stage Ownership

| Stage | Primary Owner | Actions |
|-------|---------------|---------|
| Lead | Inside Sales / Rep | Qualify, Score |
| Qualified | Rep | Discovery, Demo |
| Proposal | Rep | Quote, Negotiate |
| Negotiation | Rep + Manager | Terms, Discount |
| Closed Won | Rep + Ops | Handoff, Commission |
| Closed Lost | Rep | Analysis, Feedback |
