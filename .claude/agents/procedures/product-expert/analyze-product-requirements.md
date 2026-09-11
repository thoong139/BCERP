# Playbook: Phân tích Product Requirements

> **Type**: Agent Procedure
> **Agent**: product-expert
> **Triggered by**: /wf-analyze-requirements khi có product management modules
> **Output**: `.mc-data/docs/phase1-business/product-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có module liên quan đến: product management, roadmap, backlog, feature prioritization, user feedback
- Khi cần xác định product requirements từ góc độ PM/PO

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm: SaaS / Mobile App / Platform / Marketplace / Internal Tool
□ Product stage: Discovery / MVP / Growth / Scale
□ Business model: B2B / B2C / B2B2C
□ Đã có product management tool chưa? (Jira, Linear, Productboard, Notion...)
□ Team structure: PM, PO, Dev, Designer — size và maturity?
```

### Bước 2: Xác định product personas

```
READ: .claude/references/team-expert/product/discovery-framework.md

Map personas sử dụng hệ thống:
□ Product Manager → cần strategic view, roadmap, metrics
□ Product Owner → cần backlog management, sprint planning
□ Developer → cần user stories rõ ràng, acceptance criteria
□ End User → cần feedback channel, NPS/CSAT tracking
□ Stakeholder → cần visibility, progress reporting

Với mỗi persona: note pain points và must-have capabilities
```

### Bước 3: Phân tích market và competitive landscape

```
READ: .claude/references/team-expert/product/market-intelligence-framework.md

Xác định:
□ TAM/SAM/SOM — market có đủ lớn để justify build?
□ Top 3 competitors: features, pricing, positioning
□ Differentiator dự án này so với market
□ Market timing signals — trend đang đi theo hướng nào?
```

### Bước 4: Xác định core product capabilities

```
Dựa trên product type, map capabilities cần có:

| Product Type        | Core Capabilities                                          |
|---------------------|------------------------------------------------------------|
| SaaS Platform       | Roadmap, Backlog, User stories, Metrics, Feedback loop     |
| Mobile App          | Feature flags, Release management, Crash/ANR tracking      |
| Marketplace         | Supply/demand balance, Review system, GTM sequencing       |
| Internal Tool       | Requirements capture, Prioritization, Sprint tracking      |

Load knowledge files tương ứng:
Roadmap → READ: roadmap-template.md
Requirements/Stories → READ: requirements-framework.md
Discovery/Validation → READ: discovery-framework.md
```

### Bước 5: User research needs

```
□ Có user interview process không?
□ Feedback channels: in-app, email survey, support tickets?
□ NPS/CSAT — đang collect ở đâu? Frequency?
□ Churn reasons — có capture không?
□ Feature request triage process?
□ Beta/early adopter program?
```

### Bước 6: Define success metrics

```
READ: .claude/references/team-expert/product/requirements-framework.md

Với mỗi product capability:
□ Activation metric — user có thực sự dùng tính năng không?
□ Retention metric — user có quay lại không?
□ Satisfaction metric — user có hài lòng không? (NPS, CSAT)
□ Business metric — tính năng đóng góp gì vào revenue/growth?
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-PROD-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-PROD-MAP-001  → Roadmap management
REQ-PROD-BACK-001 → Backlog management
REQ-PROD-DISC-001 → Discovery / user research
REQ-PROD-MET-001  → Metrics / analytics
REQ-PROD-FB-001   → Feedback management
REQ-PROD-GTM-001  → Go-to-market / launch
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/product-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope product management)
2. Product Type & Stage
3. Personas affected (summary)
4. Market Context (TAM, competitors, differentiator)
5. Core Capabilities cần build
6. Requirements (theo module, có REQ-ID)
7. Success Metrics
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-PROD-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Product type và stage đã xác định
□ Personas đã được map với pain points cụ thể
□ Success metrics đã defined cho mỗi capability chính
□ Open questions được list ra để stakeholders review
```
