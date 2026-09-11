# Playbook: Thiết kế OKR / Balanced Scorecard System

> **Type**: Agent Procedure
> **Agent**: strategy-expert
> **Triggered by**: /wf-design khi cần thiết kế OKR tracking, BSC, hoặc strategic planning system
> **Output**: `.mc-data/docs/phase3-architecture/strategy/okr-system.md`

---

## Khi nào dùng playbook này

- Khi cần spec module "OKR Management", "Performance Management", "Strategic Planning Platform", "BSC system"
- Khi requirements include: OKR check-in tracking, KPI cascade, initiative management
- Khi cần link individual performance to company strategy

---

## Procedure

### Bước 1: Chọn framework (OKR vs BSC vs Hybrid)

```
INPUT: Paths do skill cung cấp qua prompt + strategy-requirements.md từ Phase 1
READ: .claude/references/team-expert/strategy/operations.md → Section 2 (OKR), Section 3 (BSC)

Decision matrix:

OKR — Phù hợp khi:
  □ Startup hoặc growth company (< 5 năm tuổi, < 500 người)
  □ Fast-paced, need frequent pivots
  □ Culture: transparent, bottom-up alignment expected
  □ Planning cycle: Quarterly
  □ Tool adoption: Team comfortable với modern tools

BSC — Phù hợp khi:
  □ Enterprise hoặc conglomerate (5000+ người)
  □ Stable industry, long planning horizons
  □ Culture: top-down strategy cascade
  □ Planning cycle: Annual
  □ Formal board governance present

Hybrid (BSC strategic objectives + OKR execution) — Phù hợp khi:
  □ Mid-size enterprise (500-5000 người)
  □ Strategy set annually (BSC) but executed quarterly (OKR)
  □ Want strategy map visualization + agile execution tracking
  □ Governance: formal but not rigid

Document decision và rationale trong output.
```

### Bước 2: OKR data model design

```
READ: .claude/references/team-expert/strategy/personas.md → Strategy Manager section

Core entities:

Objective:
  - objective_id (UUID)
  - title (max 100 chars — concise, inspirational)
  - description
  - owner_id (user)
  - timeframe (Q1 2026, H1 2026, FY 2026)
  - level (Company / BU / Department / Individual)
  - parent_objective_id (for cascade)
  - confidence_score (0-100, updated at check-in)
  - status (Draft | Active | Closed | Cancelled)
  - created_at, updated_at

KeyResult:
  - kr_id (UUID)
  - objective_id (FK)
  - metric_name (what are we measuring?)
  - baseline (starting value)
  - target (goal value)
  - current_value (updated at check-in)
  - unit (%, VND, count, score, etc.)
  - update_frequency (weekly / monthly / quarterly)
  - data_source (manual / system_auto / API_integration)
  - score (0.0 - 1.0, calculated: current/target)

Initiative:
  - initiative_id (UUID)
  - title
  - description
  - owner_id
  - linked_kr_ids (array — initiative contributes to these KRs)
  - start_date, due_date
  - status (Not Started / In Progress / Complete / Cancelled)
  - budget (optional)
  - milestones: [{milestone_id, title, due_date, status}]

OKRCycle:
  - cycle_id
  - name (Q1 2026, H1 2026, FY 2026)
  - start_date, end_date
  - status (Planning | Active | Scoring | Closed)

CheckIn:
  - checkin_id
  - kr_id (FK)
  - checkin_date
  - current_value (at time of check-in)
  - confidence_score (owner's confidence in achieving target)
  - notes (mandatory nếu confidence < 50%)
  - updated_by

Hierarchy rules:
  □ Company OKRs có NO parent
  □ BU OKRs MUST link to at least 1 Company Objective
  □ Department OKRs MUST link to at least 1 BU Objective
  □ Individual OKRs MUST link to at least 1 Department Objective
  □ Max cascade depth: 4 cấp (Company → BU → Dept → Individual)
  □ Orphan OKRs (không link parent) cần manager approval
```

### Bước 3: Check-in và update workflow

```
READ: .claude/references/team-expert/strategy/operations.md → Section 2: OKR Process Flow

Automated reminders (configurable):
  Weekly: Auto-reminder email + in-app notification → KR owner cập nhật values
  Monthly: Manager review trigger → Comment on team OKRs
  Quarterly: Scoring notification → Cycle closing workflow

Check-in flow:
1. KR owner receives reminder (D-2 before deadline)
2. Owner opens check-in form: enters current_value, confidence_score (0-100), optional notes
3. System auto-calculates KR score (current_value / target)
4. System recalculates Objective score (weighted average of KR scores)
5. Changes visible to: owner, manager, strategy team, CEO (per role)
6. Confidence < 50%: mandatory note required + manager notified

Escalation rules:
  □ KR confidence < 50% for 2 consecutive check-ins → Alert manager
  □ Objective score < 0.4 at mid-cycle → Alert to BU Head + Strategy Manager
  □ Check-in missed (owner không update) → Reminder escalation: D+3 days → manager
  □ Quarter-end: Missing check-ins auto-flagged; cycle cannot close until resolved

Quarter transition:
1. Scoring period opens (last week of quarter)
2. Owners submit final scores (0.0-1.0) with evidence
3. Managers review and confirm
4. Cycle closes: all OKRs archived with final scores
5. New cycle auto-created from planning template
6. Historical scores preserved for trend analysis
```

### Bước 4: Reporting và analytics

```
OKR Health Dashboard:
  □ Company-level: % Objectives On Track (score ≥ 0.7) / At Risk / Behind
  □ BU breakdown: OKR health per BU (radar/heatmap view)
  □ Department breakdown: drill-down per BU
  □ Lagging KRs: List of KRs with score < 0.4, sorted by priority
  □ At-risk Objectives: Objectives likely to miss (confidence < 50%)

Alignment Map (Visual Tree):
  □ Company OKR → BU OKR branches → Dept OKR leaves
  □ Color coding: Green/Amber/Red per health
  □ Click any node → expand sub-tree
  □ Filter: By cycle, by owner, by status

Historical Analytics:
  □ Quarter-over-quarter OKR score trend (line chart per level)
  □ Team scoring distribution (how many 0.7+, 0.4-0.7, <0.4)
  □ Initiative completion rate per cycle
  □ Goal-setting quality: average score over time (consistently 1.0 → targets too easy)

Export:
  □ Strategy Review deck (PDF): Company + BU OKR summary, auto-generated
  □ Raw data (Excel): All OKRs, all cycles, all scores (for Strategy Manager analysis)
  □ Individual performance report (PDF): Per employee, per review cycle (link to HR)
```

### Bước 5: Integration specs

```
HR System integration:
  □ Individual OKRs linked to performance review cycle
  □ OKR score → feeds into performance rating (configurable weight)
  □ SSO: Authenticate via company identity provider (SAML / OAuth2)
  □ User sync: Employee directory from HRIS (add/remove/update)

Finance system integration:
  □ Financial KRs (Revenue, EBITDA): Auto-pull from ERP (no manual entry)
  □ CAPEX KRs: Link to approved CAPEX from finance system
  □ Budget KRs: Link to budget vs actual from finance

Project Management integration (optional):
  □ Initiatives → linked to project tasks in PM tool (Jira, ClickUp, etc.)
  □ Milestone status synced bi-directionally

Executive Dashboard integration:
  □ OKR scores published to Executive Dashboard (L1/L2 level)
  □ CEO dashboard shows Company OKR score + BU OKR heatmap

Notification / Collaboration:
  □ Slack / Teams integration: Check-in reminders, score alerts
  □ Email: Weekly digest of team OKR status
```

---

## Output Structure

```markdown
# OKR System Design

## 1. Framework Decision (OKR / BSC / Hybrid)
[Decision + rationale]

## 2. Data Model
[Entity diagrams: Objective, KeyResult, Initiative, CheckIn, Cycle]

## 3. Cascade Hierarchy
[Diagram: Company → BU → Dept → Individual, với rules]

## 4. Check-in & Workflow
[Sequence diagram: reminder → check-in → escalation → quarter close]

## 5. Reporting & Analytics
[Screens: Health dashboard, Alignment map, Historical trends]

## 6. Integration Architecture
[Diagram: OKR system ↔ HR / Finance / PM / Dashboard]

## 7. Access Control
[Who sees what: Company OKRs, BU OKRs, peer visibility rules]

## 8. Open Questions
[Items requiring business decision before implementation]
```

---

## Checklist trước khi submit

```
□ Framework choice (OKR/BSC/Hybrid) documented với rationale
□ Data model: All entities với required fields
□ Cascade rules: Max 4 levels, parent linkage required
□ Check-in workflow: Reminder cadence, escalation rules, quarter close
□ Scoring formula defined và documented
□ Historical data: Archived per cycle, accessible for trend analysis
□ Integration points: HR (SSO + performance), Finance (auto-pull KRs), Dashboard
□ Export: Strategy review PDF + raw data Excel
□ Mobile: Check-in usable on mobile (CEO, BU Heads on the go)
□ Privacy: Individual OKR visibility rules (manager sees team, peer cannot see peer)
```
