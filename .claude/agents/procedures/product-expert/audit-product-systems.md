# Playbook: Audit Existing Product Management Systems

> **Type**: Agent Procedure
> **Agent**: product-expert
> **Triggered by**: /wf-legacy-scan khi dự án có product management tools hiện có
> **Output**: `.mc-data/docs/phase1-business/product-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Product Management
- Khi cần đánh giá PM tool stack hiện tại (Jira, Linear, Notion, Productboard...)
- Khi cần tìm gaps trước khi thiết kế lại hoặc migrate

---

## Procedure

### Bước 1: Inventory thu thập

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, KNOWLEDGE_BASE

Thu thập thông tin từ codebase hoặc stakeholders:
□ PM Tools đang dùng: Jira / Linear / Notion / Productboard / Aha! / Trello / GitHub Projects
□ Roadmap tool: Riêng (ProductPlan, Roadmunk) hay trong PM tool?
□ User feedback tool: Intercom, Pendo, Hotjar, UserVoice?
□ Analytics: Amplitude, Mixpanel, Google Analytics?
□ Documentation: Confluence, Notion, Google Docs?
□ Communication: Slack channels cho product updates?
```

### Bước 2: Đánh giá backlog health

```
READ: .claude/references/team-expert/product/requirements-framework.md

Kiểm tra trạng thái backlog hiện tại:
□ Tổng số items: Bao nhiêu? Có quá nhiều không? (>500 = red flag)
□ Item age: % items cũ hơn 6 tháng chưa được touch?
□ Story quality: Có đủ Acceptance Criteria không?
□ Prioritization: Có score (RICE/MoSCoW) không hay ad-hoc?
□ Stale items: Có items mô tả vague "improve performance" tồn tại lâu?
□ Duplicate detection: Có items duplicate không?
□ Epic coverage: Mọi story có link với Epic không?
□ Labels/Tags: Có nhất quán không?
```

### Bước 3: Process documentation gaps

```
Đánh giá process maturity:
□ Definition of Ready (DoR): Có tồn tại và được follow không?
□ Definition of Done (DoD): Có tồn tại và được follow không?
□ Grooming cadence: Có backlog grooming meeting regular không?
□ Sprint planning process: Có documented không?
□ Retrospective: Có actions từ retro được track không?
□ Tech debt budget: Có allocate % sprint capacity không?
□ Change request process: Có process chính thức không?
□ Stakeholder communication: PM có update stakeholders định kỳ không?
```

### Bước 4: Metrics tracking gaps

```
READ: .claude/references/team-expert/product/discovery-framework.md

Kiểm tra metrics hiện tại:
□ Velocity: Có track không? Trend 6 sprints gần nhất?
□ Throughput: Stories completed per sprint?
□ Cycle time: Từ "In Progress" → "Done" trung bình bao lâu?
□ Lead time: Từ "Created" → "Done" trung bình bao lâu?
□ Bug rate: Bugs found in production per sprint?
□ Tech debt ratio: % capacity dùng để trả tech debt?
□ Product metrics: NPS / CSAT / Activation rate / Retention — có track không?
□ OKR progress: Có dashboard theo dõi OKR không?
```

### Bước 5: Team alignment issues

```
□ PM ↔ Engineering: Có shared understanding về priorities không?
□ PM ↔ Design: Có design handoff process không?
□ PM ↔ Stakeholders: Roadmap có được share regularly không?
□ Conflicting priorities: Nhiều stakeholders push different items?
□ Decision authority: Ai là final decision maker cho scope changes?
□ Context switching: Developers bị interrupt bao nhiêu lần per sprint?
□ Documentation debt: Có nhiều "undocumented" decisions không?
```

### Bước 6: Tool migration assessment

```
Nếu cần migrate hoặc consolidate tools:
□ Data export feasibility: Tool hiện tại có export full data không?
□ Data quality: Exported data có đủ sạch để import không?
□ Custom fields: Tool mới có support custom fields tương đương không?
□ Integrations: Tool mới có integrate được với CI/CD, Slack, etc.?
□ Team adoption risk: Có resistance thay đổi không?
□ Migration timeline: Có active sprints bị ảnh hưởng không?
□ Training needs: Team cần training bao lâu?
```

### Bước 7: Output — As-Is Analysis Report

```
Ghi vào: .mc-data/docs/phase1-business/product-as-is-analysis.md

Cấu trúc:
```markdown
# Product Management As-Is Analysis

## Executive Summary
[3-5 dòng: overall PM maturity, strengths, critical gaps]

## Current Tool Stack
[Table: Tool | Purpose | Status | Issues]

## Backlog Health Assessment
[Table: Metric | Current | Target | Gap | Priority]

## Process Maturity
[Table: Process | Exists | Followed | Quality | Recommendation]

## Metrics Coverage
[Table: Metric | Tracked | Tool | Data Quality | Missing]

## Team Alignment Findings
[List của alignment issues với impact assessment]

## Gap Summary
### Critical Gaps (block product delivery)
- [Gap]: [Impact] → [Recommendation]

### Important Gaps (hurt efficiency)
- [Gap]: [Impact] → [Recommendation]

### Nice-to-have Improvements
- [Improvement]: [Benefit]

## Tool Migration Assessment
[Nếu applicable: migration feasibility, risks, timeline]

## Priority Recommendations
1. [Quick win] — Effort: Low, Impact: High
2. ...
```
```

---

## Checklist trước khi submit

```
□ Tất cả PM tools đã được inventoried
□ Backlog health metrics đã được assessed
□ Process gaps đã được documented với severity
□ Metrics tracking gaps đã được identified
□ Team alignment issues đã được noted
□ Priority recommendations có effort/impact estimates
□ Migration risks đã được flagged nếu applicable
```
