# Requirements Framework

> Reference file cho product-expert agent
> Load file này khi cần viết requirements cho sản phẩm

## User Story Format

### Standard Format

```
As a [type of user],
I want [to perform an action],
So that [I can achieve a goal].
```

### Example

```
As a returning customer,
I want to see my order history,
So that I can quickly reorder items I've purchased before.
```

---

## Acceptance Criteria

### Format Options

**Given-When-Then (BDD):**
```
Given [context/initial state]
When [action taken]
Then [expected outcome]
```

**Checklist Format:**
```
- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3
```

### Example Acceptance Criteria

```
Scenario: View order history

Given I am a logged-in customer
When I navigate to "My Orders"
Then I see a list of my past orders
  And each order shows:
    - Order date
    - Order number
    - Order total
    - Order status
  And orders are sorted by date (newest first)
  And I can click an order to see details
```

---

## Requirements Categories

### Functional Requirements

| Category | Description | Example |
|----------|-------------|---------|
| User management | Auth, profiles | User can reset password |
| Data entry | Create, update, delete | User can add item to cart |
| Calculations | Business logic | System calculates tax |
| Reporting | Data output | User can export orders |
| Integration | External systems | Sync with ERP |

### Non-Functional Requirements

| Category | Description | Example |
|----------|-------------|---------|
| Performance | Speed, response time | Page loads in < 3 seconds |
| Security | Data protection | Encrypt data at rest |
| Scalability | Growth capacity | Support 10K concurrent users |
| Availability | Uptime | 99.9% uptime SLA |
| Usability | User experience | WCAG 2.1 AA compliant |

---

## Requirements Documentation

### PRD Template

```markdown
# [Feature Name] - Product Requirements Document

## Overview
Brief description of the feature

## Problem Statement
What problem are we solving?

## Goals
- Goal 1
- Goal 2

## User Stories

### Story 1: [Title]
**As a** [user type]
**I want** [action]
**So that** [benefit]

**Acceptance Criteria:**
- AC 1
- AC 2

### Story 2: [Title]
...

## Non-Functional Requirements
- Performance: ...
- Security: ...

## Out of Scope
What we're NOT building

## Success Metrics
How we measure success

## Dependencies
What we need from others

## Timeline
Target release date
```

---

## Prioritization

### MoSCoW Method

| Priority | Description | Action |
|----------|-------------|--------|
| Must Have | Non-negotiable | Build first |
| Should Have | Important but not critical | Build if time permits |
| Could Have | Nice to have | Consider for later |
| Won't Have | Not this release | Defer |

### Priority Factors

| Factor | Weight | Consideration |
|--------|--------|---------------|
| User value | 30% | How much does it help users? |
| Business value | 25% | Impact on business metrics |
| Effort | 25% | How much work is needed? |
| Risk | 20% | What could go wrong? |

---

## Requirements Quality Checklist

### INVEST Criteria for User Stories

| Criteria | Description | Check |
|----------|-------------|-------|
| Independent | Can be developed separately | ✓/✗ |
| Negotiable | Can be discussed and changed | ✓/✗ |
| Valuable | Provides value to user | ✓/✗ |
| Estimable | Can be estimated | ✓/✗ |
| Small | Fits in a sprint | ✓/✗ |
| Testable | Can be verified | ✓/✗ |

### Quality Checklist

- [ ] Clear and unambiguous
- [ ] Complete (all scenarios covered)
- [ ] Consistent (no contradictions)
- [ ] Traceable (linked to business goal)
- [ ] Feasible (can be implemented)
- [ ] Testable (can be verified)

---

## Requirements Traceability

### Traceability Matrix

| Requirement ID | User Story | Source | Test Case | Status |
|----------------|------------|--------|-----------|--------|
| REQ-001 | US-101 | Interview 5 | TC-201 | Done |
| REQ-002 | US-102 | Survey Q3 | TC-202 | In Progress |

### Linking Requirements

```
Business Goal
    └── Feature
        └── User Story
            └── Acceptance Criteria
                └── Test Case
```

---

## Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Too vague | Unclear what to build | Add specific details |
| Too prescriptive | Limits solution options | Focus on what, not how |
| Gold plating | Over-engineering | Stick to requirements |
| Scope creep | Constant additions | Use change control |
| Missing acceptance criteria | Unclear completion | Always define AC |
