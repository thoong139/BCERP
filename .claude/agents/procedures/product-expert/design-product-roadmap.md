# Playbook: Thiết kế Product Roadmap Module

> **Type**: Agent Procedure
> **Agent**: product-expert
> **Triggered by**: /wf-define-features khi cần thiết kế roadmap module trong hệ thống quản lý sản phẩm
> **Output**: Feature spec cho roadmap module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Trong `/wf-define-features` khi dự án có module Roadmap
- Khi cần translate REQ-PROD-MAP-xxx thành feature specs cụ thể
- Khi cần thiết kế hệ thống lập kế hoạch sản phẩm chiến lược

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE2

READ: .claude/references/team-expert/product/roadmap-template.md

Cần xác định:
□ REQ-PROD-MAP-xxx nào cần implement?
□ Roadmap horizon: Quarterly / Annual / Multi-year?
□ Audience: Internal team only hay External (public roadmap)?
□ Có OKR system không? Roadmap cần link với OKR?
□ Integrate với backlog tool nào? (Jira, Linear, GitHub)
```

### Bước 2: Define roadmap horizons

```
Dùng Now/Next/Later framework:

NOW  (0-3 tháng)  → In-progress initiatives, committed releases
NEXT (3-6 tháng)  → Planned themes, validated opportunities
LATER (6+ tháng)  → Strategic bets, exploratory ideas

Với mỗi horizon, define:
□ Granularity: Epic / Theme / Initiative?
□ Confidence level: Committed / Likely / Exploratory?
□ Visibility: Public / Internal / Restricted?
```

### Bước 3: Feature prioritization framework

```
READ: .claude/references/team-expert/product/requirements-framework.md

Chọn framework phù hợp với product stage:

RICE Score = (Reach × Impact × Confidence) / Effort
□ Reach:      Bao nhiêu user bị ảnh hưởng trong 1 quarter?
□ Impact:     3=Massive / 2=High / 1=Medium / 0.5=Low / 0.25=Minimal
□ Confidence: 100%=High / 80%=Medium / 50%=Low
□ Effort:     Person-weeks để implement

MoSCoW phân loại:
□ Must-have    → Không có thì không ship được
□ Should-have  → Quan trọng nhưng có thể delay
□ Could-have   → Nice-to-have nếu có thời gian
□ Won't-have   → Explicitly out of scope
```

### Bước 4: Initiative mapping

```
Với mỗi Initiative trên roadmap:
□ Initiative name + description (1-2 câu)
□ Linked OKRs (nếu có)
□ Target personas bị ảnh hưởng
□ Success metrics (measurable outcomes)
□ Dependencies với initiatives khác
□ Estimated effort (T-shirt sizing: XS/S/M/L/XL)
□ Confidence level (Committed/Likely/Exploratory)
```

### Bước 5: OKR alignment

```
Nếu dự án có OKR system:
□ Mỗi Initiative phải link với ít nhất 1 Key Result
□ Key Results phải measurable và time-bound
□ Roadmap review cadence sync với OKR review cycle
□ Progress tracking: % complete hay leading indicator?
```

### Bước 6: Stakeholder review process

```
□ Roadmap review frequency: Weekly / Monthly / Quarterly?
□ Approval workflow: PM → Head of Product → C-Level?
□ Stakeholder tiers: Who sees what?
   - Engineering: Full technical details
   - Sales/CS: Committed features only
   - External users: Public roadmap view
□ Change management: Ai có quyền re-prioritize?
```

### Bước 7: Release planning cadence

```
□ Release types: Major / Minor / Patch / Hotfix
□ Release frequency: Continuous / Sprint / Monthly?
□ Changelog generation: Automatic hay manual?
□ Feature flags: Có support gradual rollout không?
□ Release notes: Internal vs Customer-facing format
```

### Bước 8: Output — Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/product/roadmap/roadmap-module.md

Cấu trúc feature spec:
1. Module Overview (scope, personas, dependencies)
2. Features List (với FEAT-PROD-MAP-xxx IDs)
3. Data Model sketch (Initiative, Theme, Release entities)
4. UI/UX considerations (timeline view, kanban view)
5. Integration points (backlog, OKR, notification system)
6. Acceptance Criteria per feature
7. Out of scope (explicitly)
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-PROD-MAP-xxx đã được cover bởi feature specs
□ RICE hoặc MoSCoW đã áp dụng để prioritize features
□ Horizons (Now/Next/Later) đã define rõ ràng
□ OKR alignment đã noted (nếu applicable)
□ Stakeholder review process đã specify
□ Integration points với các module khác đã documented
```
