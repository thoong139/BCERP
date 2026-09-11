# Product Discovery Framework

> Reference file cho product-expert agent
> Load file này khi cần thực hiện product discovery

## Discovery Process Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  PRODUCT DISCOVERY FRAMEWORK                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  OPPORTUNITY →  PROBLEM  →  SOLUTION  →  PROTOTYPE  →  TEST    │
│  IDENTIFICATION  VALIDATION  IDEATION   CREATION    & LEARN     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Opportunity Identification

### Market Research

| Activity | Purpose | Output |
|----------|---------|--------|
| Market analysis | Understand market size, trends | Market report |
| Competitive analysis | Know the landscape | Competitor matrix |
| Trend analysis | Spot emerging opportunities | Trend report |

### Opportunity Assessment

| Criteria | Questions |
|----------|-----------|
| Market size | How big is the opportunity? |
| Growth potential | Is the market growing? |
| Competitive intensity | How crowded is the space? |
| Strategic fit | Does it align with company goals? |
| Feasibility | Can we build it? |

---

## Phase 2: Problem Validation

### User Research Methods

| Method | When to Use | Output |
|--------|-------------|--------|
| User interviews | Deep understanding | Interview notes |
| Surveys | Quantify insights | Survey data |
| Observation | See actual behavior | Field notes |
| Focus groups | Explore attitudes | Discussion summary |
| Analytics review | Understand current usage | Usage patterns |

### Problem Statement Template

```
[User type] experiences [problem]
when trying to [goal/task]
because [root cause]
which results in [negative outcome]
```

### Validation Criteria

| Signal | Description | Confidence Level |
|--------|-------------|------------------|
| Users mention unprompted | Strong signal | High |
| Users agree when asked | Moderate signal | Medium |
| Users don't see problem | Weak signal | Low |

---

## Phase 3: Solution Ideation

### Ideation Techniques

| Technique | Description |
|-----------|-------------|
| Brainstorming | Generate many ideas quickly |
| Crazy 8s | Sketch 8 ideas in 8 minutes |
| How Might We | Reframe problems as opportunities |
| SCAMPER | Substitute, Combine, Adapt, Modify, Put to other use, Eliminate, Reverse |
| Jobs to be Done | Focus on user's job |

### Solution Assessment

| Criteria | Weight | Scoring |
|----------|--------|---------|
| User value | 30% | 1-5 |
| Business value | 25% | 1-5 |
| Technical feasibility | 25% | 1-5 |
| Effort required | 20% | 1-5 (inverse) |

---

## Phase 4: Prototype Creation

### Prototype Types

| Fidelity | When to Use | Time to Create |
|----------|-------------|----------------|
| Paper sketch | Early exploration | Minutes |
| Wireframe | Structure and flow | Hours |
| Mockup | Visual design | Hours-Days |
| Interactive prototype | User testing | Days |
| MVP | Real usage validation | Weeks |

### Prototype Scope

| Type | Includes | Excludes |
|------|----------|----------|
| Smoke test | Landing page | Actual product |
| Wizard of Oz | Manual backend | Automation |
| Concierge | Manual service | Self-service |
| Single feature | One capability | Full product |

---

## Phase 5: Testing & Learning

### Testing Methods

| Method | What it Tests |
|--------|---------------|
| Usability testing | Can users use it? |
| A/B testing | Which version performs better? |
| Fake door testing | Is there demand? |
| Concierge testing | Will users pay? |
| Beta testing | Does it work at scale? |

### Learning Framework

| Question | Metric | Method |
|----------|--------|--------|
| Do they want it? | Interest | Interviews, landing page |
| Will they use it? | Adoption | Usage data |
| Will they pay? | Revenue | Pre-sales, pricing tests |
| Can they use it? | Success rate | Usability testing |

---

## Jobs to be Done (JTBD)

### JTBD Framework

```
When [situation],
I want to [motivation],
So I can [expected outcome].
```

### Example JTBD

| Situation | Motivation | Outcome |
|-----------|------------|---------|
| When I'm running late | I want to quickly order coffee | So I don't miss my train |
| When I'm stressed | I want a calming playlist | So I can focus on work |

---

## Hypothesis-Driven Development

### Hypothesis Format

```
We believe that [building this feature]
for [this user segment]
will result in [this outcome].

We will know we're right when [measurable signal].
```

### Example Hypothesis

```
We believe that adding a progress indicator
for first-time users
will result in higher completion rates.

We will know we're right when
onboarding completion increases from 40% to 55%.
```

---

## Decision Framework

### Go/No-Go Criteria

| Decision | Criteria |
|----------|----------|
| Go | Problem validated, solution feasible, business case positive |
| No-Go | Problem not validated, too difficult, no business case |
| Pivot | Problem real but solution wrong |
| Persevere | On track, continue building |

### Confidence Levels

| Confidence | Evidence | Action |
|------------|----------|--------|
| High | Multiple validation methods agree | Proceed |
| Medium | Some evidence, need more | Continue testing |
| Low | Assumptions not validated | More research needed |

---

## Discovery Checklist

- [ ] Problem clearly defined
- [ ] Target user identified
- [ ] User research completed
- [ ] Problem validated with users
- [ ] Solutions generated
- [ ] Solution tested with users
- [ ] Business case validated
- [ ] Success metrics defined
- [ ] Go/No-Go decision made
