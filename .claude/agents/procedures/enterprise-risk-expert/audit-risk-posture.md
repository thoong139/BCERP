# Procedure: Audit Enterprise Risk Posture

> **Type**: Agent Procedure
> **Agent**: enterprise-risk-expert
> **Triggered when**: wf-legacy-scan — cần đánh giá risk management maturity của tổ chức đang được onboard
> **Output**: Risk Maturity Assessment, gap analysis, prioritized improvement roadmap

---

## Khi nào dùng procedure này

Khi `wf-legacy-scan` skill invoke `enterprise-risk-expert` để đánh giá current state của
risk management practices tại tổ chức. Input là existing documents, org charts, system descriptions.

Dấu hiệu nhận biết:
- Context từ `/wf-legacy-scan` với tổ chức có risk management function
- Yêu cầu "assess risk maturity", "evaluate ERM program", "risk posture review"
- Khách hàng muốn biết "chúng tôi đang ở đâu" trước khi build ERM system

---

## Procedure

### Bước 1: Thu thập evidence từ existing documents

```
INPUT: Paths do wf-legacy-scan cung cấp
FALLBACK: .mc-data/docs/ hoặc knowledge-base nếu onboard đã partial

Tìm kiếm:
□ Org chart: CRO có không? Risk function được structure thế nào?
□ Risk policy / ERM policy documents
□ Risk register (Excel, Word, hay system?)
□ Risk appetite statement hoặc board risk policy
□ Internal audit charter và recent audit reports
□ Board / Risk Committee meeting minutes
□ Incident logs (nếu có)
□ BCP / DRP documents
□ Control framework documentation
□ Any regulatory correspondence về risk management

Nếu tài liệu thiếu → ghi nhận là gap evidence
```

### Bước 2: Assess governance structure

```
READ: .claude/references/team-expert/enterprise-risk/risk-governance.md
→ Three Lines of Defense, governance structures, RCSA, reporting cadence

Đánh giá:
□ Three Lines of Defense: có cả 3 lines không?
   Level 1 (1st line exists): Business operations có risk ownership chưa?
   Level 2 (2nd line exists): Dedicated risk management function có không?
   Level 3 (3rd line exists): Independent internal audit có không?

□ Risk Committee: Board Risk Committee tồn tại? Meeting frequency?
□ CRO role: có CRO không? Report line đến đâu? (CEO/Board = good; COO = potential conflict)
□ RCSA process: có RCSA không? Frequency? Documentation?
□ Risk Appetite Statement: đã có và approved by Board chưa?
□ Escalation path: có defined escalation procedures không?
```

### Bước 3: Assess ERM framework và risk register

```
READ: .claude/references/team-expert/enterprise-risk/erm-framework.md
→ COSO ERM 2017, ISO 31000:2018, Risk Universe, Risk Appetite Framework

Đánh giá:
□ Framework: có documented risk framework không? COSO / ISO 31000 / custom?
□ Risk taxonomy: có standard risk categories không? Bao nhiêu categories? Consistent usage?
□ Risk register: có không? Format (spreadsheet vs system)? Last updated? Owner?
□ Risk assessment methodology: có scoring methodology documented không? Consistent?
□ Risk appetite: được define quantitatively hay chỉ qualitative?
□ Risk universe coverage: có bao gồm cả 7 risk categories (Strategic/Financial/Operational/
   Compliance/Reputational/Technology/ESG) không?
```

### Bước 4: Assess operational risk management practices

```
READ: .claude/references/team-expert/enterprise-risk/operations.md
→ Risk Management Calendar, incident management, KPIs

Đánh giá:
□ Routine monitoring: có KRI system không? Monitored daily/weekly?
□ Risk register updates: how often? Trigger-based hay chỉ annual?
□ Incident management: có incident reporting process không? Near-miss reporting?
□ Action plan tracking: có systematic tracking không? Overdue alerts?
□ Risk reporting: frequency, recipients, format — manual hay automated?
□ Risk culture indicators:
   - Near-miss reporting volume (0 reports = likely under-reporting, not zero incidents)
   - Risk champion network: có không? Active không?
   - Risk training: last completed? Coverage?
```

### Bước 5: Assess BCP/DRP maturity

```
READ: .claude/references/team-expert/enterprise-risk/bcp-drp.md
→ BIA, BCP structure, DRP, testing requirements

Đánh giá:
□ BIA: Business Impact Analysis done? RTO/RPO defined per critical function?
□ BCP: documented? Last reviewed? Activation criteria clear?
□ DRP: IT Disaster Recovery Plan exists? Recovery strategies per tier?
□ Testing: last BCP/DRP test date? Type (tabletop/functional/full-scale)?
□ Crisis Management Team: roster defined? Contacts current?
□ Vietnam-specific: DR site location adequate? Data localization compliance?
```

### Bước 6: Assign maturity scores và produce gap matrix

**Maturity Scale (CMMI-inspired, 5 levels):**

| Level | Name | Characteristics |
|-------|------|-----------------|
| 1 | **Initial** | Ad-hoc, reactive. Risk management không consistent, không documented |
| 2 | **Developing** | Some processes exist nhưng not standardized. Spreadsheet-based |
| 3 | **Defined** | Documented framework, consistent process, active risk register |
| 4 | **Managed** | Quantitative management, KRI monitoring, predictive analytics |
| 5 | **Optimizing** | Continuous improvement, risk-informed decisions, integrated culture |

**Assess per dimension (score 1-5):**
```
□ Governance structure  □ Risk framework  □ Risk register & assessment
□ KRI monitoring        □ Risk reporting  □ Incident management
□ BCP/DRP               □ Risk culture

Overall = Average score (hoặc weighted nếu governance được ưu tiên)
```

### Bước 7: Output

**Format:**
```markdown
## ENTERPRISE RISK POSTURE ASSESSMENT
Organization: [Name] | Date: [DD/MM/YYYY] | Assessor: enterprise-risk-expert

### Executive Summary
- Overall maturity: Level [N] — [Name]
- Strongest dimension: [dimension]
- Most critical gap: [gap]
- Recommended quick wins: [top 3 immediate actions]

### Maturity Assessment by Dimension

| Dimension | Current Level | Target Level | Gap |
|-----------|:------------:|:------------:|:---:|
| Governance structure | 2 | 4 | ▼▼ |
| Risk framework | 1 | 3 | ▼▼ |
| ...                  | | | |

### Evidence Summary
- Governance: [what exists vs what's missing]
- Framework: [...]
- Operations: [...]
- BCP/DRP: [...]
- Risk culture: [...]

### Gap Analysis

| Capability | Current State | Target State | Gap | Priority |
|------------|--------------|--------------|-----|---------|
| Board Risk Committee | Ad-hoc risk discussion | Formal Committee, quarterly | HIGH | P1 |
| Risk appetite statement | Not documented | Board-approved RAS | HIGH | P1 |
| Risk register | Excel, updated irregularly | System, updated monthly | MEDIUM | P2 |

### Improvement Roadmap

Phase 1 — Foundation (0-3 months):
- Quick wins và must-haves để achieve Level 2 → 3
- [Specific actions]

Phase 2 — Standardization (3-9 months):
- Build defined, consistent processes
- [Specific actions]

Phase 3 — Optimization (9-18 months):
- KRI monitoring, automated reporting, risk culture
- [Specific actions]
```

---

## Checklist trước khi submit

```
□ Mỗi dimension scored với evidence (không assumption)
□ Gaps prioritized (P1/P2/P3), quick wins identified (<30 ngày)
□ Roadmap 3 phases rõ ràng
□ Regulatory implications flagged nếu regulated industry
□ Risk culture indicators assessed (không chỉ process/governance)
□ Vietnam-specific (BCP, data localization) đã check
□ Mỗi finding có evidence support — tránh đánh giá chủ quan
```
