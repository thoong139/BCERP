# Procedure: Analyze Risk Management Requirements

> **Type**: Agent Procedure
> **Agent**: enterprise-risk-expert
> **Triggered when**: Dự án có module Risk Management, ERM System, GRC platform cần phân tích requirements
> **Output**: Feature requirements với REQ-RISK-[MODULE]-[NNN], risk personas mapping, user stories

---

## Khi nào dùng procedure này

Khi skill (`wf-analyze-requirements`, `wf-define-features`) invoke `enterprise-risk-expert` với context là
dự án CÓ risk management module cần phân tích — không phải đánh giá rủi ro của chính dự án.

Dấu hiệu nhận biết: requirements mention ERM system, risk register, GRC platform, KRI dashboard,
risk committee management, BCP management, risk reporting portal.

---

## Procedure

### Bước 1: Đọc project context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: .mc-data/docs/phase0-brainstorm/ + .mc-data/docs/phase1-business/ (nếu phase 2+)

Xác định:
□ Business domain của khách hàng (financial services, healthcare, manufacturing, SaaS...)
□ Tổ chức scale: startup / SME / enterprise / publicly listed company
□ Risk maturity hiện tại: có ERM program chưa? Đang dùng spreadsheet hay platform?
□ ERM framework preference: COSO ERM 2017 / ISO 31000:2018 / hybrid?
□ Regulatory environment: có yêu cầu pháp lý nào về risk reporting không?
□ Scope của module: full ERM suite / chỉ risk register / chỉ KRI dashboard?
```

### Bước 2: Map risk personas trong dự án

```
READ: .claude/references/team-expert/enterprise-risk/personas.md

Xác định personas nào THỰC SỰ tồn tại trong tổ chức khách hàng:
□ CRO / Head of Risk tồn tại? → Cần executive dashboard, board reporting
□ Dedicated Risk Manager? → Cần risk register management, RCSA tools
□ Business Risk Owners (department heads)? → Cần simple self-assessment forms
□ Internal Audit function? → Cần audit-risk integration, findings traceability
□ Risk Champions network? → Cần incident reporting, escalation workflow

Với mỗi persona xác nhận có:
→ Pain points từ personas.md có relevance với context dự án không?
→ Must-have features từ personas.md cần đưa vào requirements không?
```

### Bước 3: Map risk management activities → functional requirements

```
READ: .claude/references/team-expert/enterprise-risk/operations.md

Từ Risk Management Calendar, identify:
□ Daily activities → cần gì? (KRI dashboard, alert system, incident log)
□ Weekly activities → cần gì? (status report, escalation tracking)
□ Monthly activities → cần gì? (risk register update, control testing, committee reporting)
□ Quarterly activities → cần gì? (Board report generation, RCSA workflow, BCP tracking)
□ Annual activities → cần gì? (comprehensive RCSA, ERM program assessment)

Từ Integration Points:
□ Finance integration: risk-financial data linkage
□ IT/Security integration: cyber risk KRI feeds
□ HR integration: people risk data
□ Compliance integration: shared risk register
```

### Bước 4: Xác định ERM framework scope

```
READ: .claude/references/team-expert/enterprise-risk/erm-framework.md

Dựa trên scale và maturity của khách hàng, xác định:
□ Framework: COSO ERM 2017 (enterprise) hoặc ISO 31000:2018 (flexible) hoặc hybrid?
□ Risk Universe: mấy trong 7 categories áp dụng?
   → Strategic / Financial / Operational / Compliance / Reputational / Technology / ESG
□ Risk Appetite Framework cần build vào system không?
   → Risk appetite statement management
   → Tolerance band tracking (Green/Amber/Red)
□ Scope: full ERM / subset (chỉ operational risk / chỉ financial risk)?
```

### Bước 5: Xác định governance requirements

```
READ: .claude/references/team-expert/enterprise-risk/risk-governance.md

Identify:
□ Three Lines of Defense: cần enforce trong system? (role-based access per line)
□ Risk Committee structure: Board Risk Committee / Management Committee workflows?
□ RCSA workflow: digital RCSA forms, workshop facilitation, sign-off?
□ Reporting cadence: automated report generation per schedule?
□ Escalation workflow: KRI breach → alert → action → sign-off chain?
```

### Bước 6: Viết requirements với REQ-RISK-[MODULE]-[NNN]

**REQ-ID Format:**
```
REQ-RISK-REG-[NNN]   → Risk Register & Risk Lifecycle Management
REQ-RISK-KRI-[NNN]   → KRI Monitoring & Alert System
REQ-RISK-GOV-[NNN]   → Governance (Committee, RCSA, escalation)
REQ-RISK-RPT-[NNN]   → Risk Reporting & Dashboards
REQ-RISK-BCP-[NNN]   → BCP/DRP Management
REQ-RISK-INC-[NNN]   → Incident & Near-Miss Management
REQ-RISK-CTL-[NNN]   → Control Library & Treatment Tracking
```

**Format mỗi requirement:**
```markdown
### REQ-RISK-[MODULE]-[NNN]: [Tên ngắn gọn]

**Mô tả**: [Chi tiết tính năng/yêu cầu]
**Persona**: [CRO / Risk Manager / Business Risk Owner / Internal Auditor / Risk Champion]
**Business Value**: [Tại sao cần — giảm manual effort? cảnh báo sớm? board visibility?]
**Framework Basis**: [COSO Component X / ISO 31000 Step X / N/A nếu operational need]
**Acceptance Criteria**:
- [ ] [Tiêu chí cụ thể 1]
- [ ] [Tiêu chí cụ thể 2]
**Dependencies**: [REQ khác]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Risk Velocity implication**: [Rapid risks cần real-time / Slow risks cần trend view]
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/enterprise-risk-requirements.md

Cấu trúc output:
1. Executive Summary
   - ERM scope và framework được chọn
   - Personas xác nhận
   - Risk maturity target (Initial → Optimizing scale)

2. Personas & Pain Points
   - Personas relevant trong dự án + pain points + must-haves

3. ERM Framework Alignment
   - Framework standard áp dụng
   - Risk categories trong scope
   - Risk appetite framework scope

4. Requirements theo module (có REQ-ID)
   - REQ-RISK-REG, REQ-RISK-KRI, REQ-RISK-GOV, REQ-RISK-RPT...

5. Integration requirements
   - Finance, IT/Security, HR, Compliance data feeds

6. Non-functional requirements
   - Audit trail cho risk status changes
   - Role-based access (Three Lines of Defense)
   - Real-time vs batch cho KRI feeds

7. Open questions
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-RISK-[MODULE]-[NNN] đúng format
□ Mỗi REQ có Persona owner rõ ràng
□ Mỗi REQ có Framework Basis (hoặc N/A)
□ Risk velocity đã được address (rapid risks cần real-time alerting)
□ Three Lines of Defense role-based access đã được address trong GOV requirements
□ KRI thresholds (Green/Amber/Red) đã được address trong KRI requirements
□ Audit trail cho risk changes đã được address
□ BCP requirements đã được address nếu scope bao gồm operational resilience
□ Open questions được list để stakeholders confirm
```
