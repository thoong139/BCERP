# Playbook: Thiết kế Backlog Prioritization System

> **Type**: Agent Procedure
> **Agent**: product-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần thiết kế backlog management module
> **Output**: Feature spec cho backlog management module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Trong `/wf-define-features` khi dự án có Backlog Management module
- Trong `/wf-design` khi architect cần product domain guidance cho data model
- Khi cần translate REQ-PROD-BACK-xxx thành feature specs cụ thể

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE2

READ: .claude/references/team-expert/product/requirements-framework.md

Cần xác định:
□ REQ-PROD-BACK-xxx nào cần implement?
□ Methodology: Scrum / Kanban / Scrumban / SAFe?
□ Team size: 1 team hay multi-team (program backlog)?
□ Tech debt tracking riêng hay trong cùng backlog?
□ External tool integration: Jira, Linear, GitHub Issues, Azure DevOps?
```

### Bước 2: RICE scoring model setup

```
Define RICE fields cho mỗi backlog item:

Reach (1-10000):
□ Đơn vị đo: users/month hay percentage of user base?
□ Data source: Analytics hay PM estimate?
□ Time window: Per quarter hay per month?

Impact (0.25 / 0.5 / 1 / 2 / 3):
□ Mapping rõ: 3=Game changer, 2=Significant, 1=Moderate, 0.5=Low, 0.25=Minimal
□ Impact đo trên metric nào? (Revenue, Retention, NPS, Activation)

Confidence (%):
□ 100% = Có data ủng hộ
□ 80%  = Có qualitative evidence
□ 50%  = Assumption / gut feel

Effort (person-weeks):
□ Ai estimate: PM, Tech Lead, hay Planning Poker?
□ Include design + dev + QA hay dev only?
□ Historical velocity để calibrate?
```

### Bước 3: Impact/Effort matrix

```
2x2 Matrix quadrants:
□ High Impact + Low Effort  → Quick Wins (DO FIRST)
□ High Impact + High Effort → Major Projects (PLAN CAREFULLY)
□ Low Impact + Low Effort   → Fill-ins (DO IF TIME)
□ Low Impact + High Effort  → Time Wasters (AVOID/DEFER)

Với mỗi backlog item:
□ Assign quadrant
□ Review với team → consensus building?
□ Override mechanism: Ai có quyền override matrix?
```

### Bước 4: User story mapping

```
Story Map structure:
□ Backbone (top level): User activities / Journeys
□ Walking skeleton: Minimum viable flow per activity
□ Details: Individual user stories per activity step

Với mỗi User Story:
□ Format: "As a [persona], I want [goal] so that [benefit]"
□ Acceptance Criteria: Given/When/Then format
□ Story Points: Fibonacci (1, 2, 3, 5, 8, 13, 21)
□ Definition of Done: Tiêu chí rõ ràng trước khi start

Tag system:
□ Type: Feature / Bug / Tech Debt / Research / Spike
□ Component: Frontend / Backend / Mobile / Infra
□ Epic link: Story phải link với Epic
```

### Bước 5: Sprint planning integration

```
□ Sprint length: 1 week / 2 weeks / 4 weeks?
□ Capacity planning: Story points per sprint per team?
□ Sprint goal: Phải có 1 theme/goal per sprint
□ Velocity tracking: Rolling average 3 sprints
□ Burndown / Burnup: Cả 2 hay chỉ 1?
□ Mid-sprint change policy: Có cho phép không? Under what conditions?
□ Definition of Ready: Story phải đáp ứng trước khi vào sprint
```

### Bước 6: Tech debt tracking

```
□ Tech debt items có label riêng không?
□ Tech debt budget per sprint: % capacity allocated (khuyến nghị 20%)
□ Debt severity levels: Critical / High / Medium / Low
□ Impact assessment: Đo bằng developer hours wasted?
□ Debt age tracking: Created date và last reviewed date
□ Payoff tracking: Effort saved sau khi fix

Lý do ghi rõ technical debt thay vì để ngầm:
- Giúp stakeholders hiểu trade-off
- Tránh debt accumulation vô kiểm soát
- Cho phép planned paydown trong roadmap
```

### Bước 7: Dependency mapping

```
□ Dependency types: Hard (blocks) / Soft (related) / External (3rd party)
□ Dependency visualization: List hay graph?
□ Critical path identification: Đâu là bottlenecks?
□ Cross-team dependencies: Escalation process khi bị block?
□ External dependencies: 3rd party API, infrastructure, legal approval

Dependency rules:
□ Story không được đưa vào sprint nếu blocker chưa done
□ Dependency owner phải được notify tự động
□ SLA: Blocker phải được resolved trong bao lâu?
```

### Bước 8: Output — Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/product/backlog/backlog-module.md

Cấu trúc feature spec:
1. Module Overview (scope, personas, methodology)
2. Features List (với FEAT-PROD-BACK-xxx IDs)
3. Data Model sketch (Epic, Story, Task, Sprint entities)
4. RICE scoring data model
5. Story Map structure
6. Integration points (sprint board, roadmap, reporting)
7. Acceptance Criteria per feature
8. Out of scope (explicitly)
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-PROD-BACK-xxx đã được cover bởi feature specs
□ RICE scoring model đã được defined rõ ràng
□ Story format và Acceptance Criteria standard đã specify
□ Tech debt tracking approach đã documented
□ Dependency mapping strategy đã defined
□ Sprint planning integration đã covered
□ Methodology (Scrum/Kanban/...) đã confirmed với stakeholders
```
