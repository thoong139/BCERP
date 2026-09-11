# Product Roadmap Template

> Reference file cho product-expert agent
> Load file này khi cần tạo product roadmap

## Roadmap Structure

```
Q1  q2  q3  q4
│ ┌───── q2───────┬── q2───────────────┤
q2         │ Q3     │ Q4          │
q3   └─── q4      │         ┌───────────┼─────────┬─────────┤
│
│        Launch (q1)
│            │
│    q1.1 (Jan)    │   │─────┬── q2─────┬── q3─────┬──
│                │
│  q1.2 (Feb)    │   │─────┬── q2─────┬── q3─────┬──
│                │
│    Grow                                 │
│    Maturity  │   Retain  │   Expand  │   Sunset  │
│        │
│   ...and so on
│
│  Notes:
│  - Prioritize ruthlessly
│  - Focus on what matters first
│  - Kill your darlings early
```
- **Discovery**: Problem → Solution fit
  - Research users deeply before designing
  - Conduct interviews (5-10 users)
  - Surveys
  - Support tickets analysis
  - Feedback analysis

**Example User research:**
- Goal: Understand user problems and context
- Questions to ask:
  1. What problem are you trying to solve?
  2. How are you currently solving it?
  3. What have you tried before?
  4. What constraints or limitations do your current solutions?

**Discovery Methods:**

| Method | Best for | Output |
|------|--------------|---------|
| User interviews | Problems, context | Interview notes, personas |
| Surveys | Quantitative data | Survey results, patterns |
| Observation | Context, behaviors | Field notes |
| Support tickets | Issues, frequency | Ticket analysis |
| Data analysis | Usage patterns | Usage metrics, dashboards |

---

## Phase 2: Problem Validation

### Problem-Solution Fit

```
Is this a real problem worth solving?
├── Is the market big enough?
├── Is the timing right?
├── Are people willing to pay for solutions?
├── Can we build a solution?
```

**Validation techniques:**

| Technique | Purpose |
|----------|---------|
| Landing page | Initial interest test |
| Fake door test | Demand validation |
| Concierge MVP test | Early adopter feedback |
| Smoke test | Feasibility check |
```

---

## Phase 3: Solution Ideation

### Brainstorming

| Technique | Best for |
|----------|---------|
| Brainstorming | Team | Generate ideas |
| How might we | How might we |
| Crazy 8s | Expand thinking |
| SCAMPER | Explore ideas quickly |

### Prioritization
| Technique | Purpose |
|----------|---------|
| Dot voting | Democratic selection |
| Stack ranking | Individual ranking |
| RICE scoring | Quantitative prioritization |

---

## Phase 4: Prototyping

### Prototype types
| Type | Purpose |
|------|---------|
| Paper prototype | Quick validation, low effort |
| Wireframe | Test flow, validate concept |
| Clickable prototype | Test interactions, get real feedback |
| MVP | Test core assumptions cheaply |

### Testing checklist
- [ ] Defined success metrics
- [ ] Build measurement plan
- [ ] Create analytics dashboard
- [ ] Set up feedback collection
- [ ] Run tests with target users

---

## Phase 5: Testing & Learning

### Metrics to track

| Metric | Target |
|--------|--------|
| Adoption rate | % users completing onboarding |
| Activation rate | % completing key action |
| Retention (Week 1) | % returning after 1 week |
| NPS (post-test) | > 50% promoters |
| task completion | % users completing core task |

**Learning cycles:**
- Review metrics weekly
- Interview users about experience
- Analyze feedback for patterns
- Iterate on solution

---

## Discovery Documentation Template

```markdown
# Discovery Document

## Document info
- Project: [Project name]
- Created: [Date]
- Author: [name]
- Status: [Draft/In Review/Approved]

## Executive Summary
[2-3 sentences capturing key findings]

## Problem Statement
[Clear description of the problem and its impact]

## User research
### Methodology
- Participants
- Sample size
- Key findings

### User Personae
[description of primary user types]

### Pain points
[current solutions + workarounds]

### Jobs to be Done
[detailed job stories]

## Solution overview
[proposed solution at high level]

## Key features
[must-have features to solve problem]

## Success metrics
[how we'll measure success]

## Assumptions
[risky assumptions to validate]

## Next steps
[recommended actions]
```

---

## Key frameworks

### Jobs-to-be-Done (JTBD)
- Focus on user goals, not solutions
- Structured around:
  1. What job are you trying to get done?
  2. What pains do they experience?
  3. What gains do they expect to achieve?

### Opportunity Canvas
- Business opportunity statement
- Target market
- competitive landscape

### Outcome statements
- Desired outcomes for business impact
```

---

## Quick reference files needed

```
.claude/references/team-expert/product/discovery-framework.md
.claude/references/team-expert/product/roadmap-template.md
.claude/references/team-expert/product/requirements-framework.md
```

 --- User research log
   - Support tickets

   - Feedback analysis

## Personas

   - Salesperson
   - Customer service rep
   - Product manager
   - Marketing manager
   - Operations manager
```
- CAC
- SCAMPER

- Dot voting
- 100 vote test (validate core assumptions)

### Focus areas:
- Core features (must-have for MVP)
- Nice-to-have features
- Future considerations

### Timeline: 12 weeks
