# Playbook: Phân tích Insurance Requirements

> **Type**: Agent Procedure
> **Agent**: insurance-expert
> **Triggered by**: /wf-analyze-requirements khi project có insurance/insurtech modules
> **Output**: `.mc-data/docs/phase1-business/insurance-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan: bảo hiểm, policy, claims, underwriting, premium, tái bảo hiểm
- Khi cần xác định insurance requirements từ business idea hoặc existing system

---

## Procedure

### Bước 1: Xác định Line of Business và Scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Line of business:
  - Life insurance: Term life, whole life, endowment, unit-linked (ULIP), health rider
  - Non-life: Motor, property, liability, marine, aviation, travel, accident & health
  - Composite: Cả nhân thọ và phi nhân thọ (Luật VN yêu cầu tách công ty)
□ Distribution channel: Direct, agency, broker, bancassurance, digital/app
□ Quy mô:
  - # active policies hiện tại / dự kiến
  - # claims/tháng
  - # agents/brokers đang quản lý
  - AUM nếu có life with investment component (ULIP)
□ Hệ thống hiện tại: Đang dùng core insurance system nào? (Majesco, Duck Creek, in-house?)
□ Integration cần thiết: Bancassurance partner, payment gateway, hospital network (health)
```

### Bước 2: Map Personas

```
READ: .claude/references/team-expert/insurance/personas.md

Xác định personas relevant cho dự án:
□ Underwriter (nếu có UW module)
□ Claims Adjuster (nếu có claims module)
□ Insurance Agent / Broker (nếu có agency/broker portal)
□ Actuary (nếu cần reserve calculation, pricing)
□ Policyholder (nếu có self-service portal)

Với insurtech/digital-first:
□ Digital UW: Rule-based automation, no human in the loop cho standard risks
□ Chatbot claims intake: Guided FNOL submission via chat
□ Telematics UW: IoT data (motor) → risk scoring

Với mỗi persona relevant: note pain points và must-have features từ personas.md
```

### Bước 3: Map Quy trình Bảo hiểm Hiện tại

```
READ: .claude/references/team-expert/insurance/operations.md

Với mỗi module trong scope:
□ Policy Admin: Map 10 bước trong Policy Lifecycle
□ Claims: Map 11 bước trong Claims Lifecycle
□ UW: Map Underwriting Process (low/medium/high risk routing)
□ Reinsurance: Nếu có treaty/facultative arrangements

Document:
□ Current process: Bước nào đang làm manual? Bước nào đã có system support?
□ STP Rate hiện tại: % applications/claims được xử lý auto
□ Pain points per step: Bottleneck ở đâu?
□ STP potential: Bước nào có thể automate để tăng STP?

Flag các bước có STP potential cao → label "[STP-CANDIDATE]" trong requirements
```

### Bước 4: Xác định Controls

```
READ: .claude/references/team-expert/insurance/controls.md

Checklist:
□ UW Authority Matrix: Junior/Senior/Manager/CUO limits phù hợp quy mô?
□ Retention Limits: Cần parameterize per product?
□ Claims Approval Matrix: Adjuster/Manager/CEO limits?
□ Dual control enforcement: System có enforce adjuster ≠ approver?
□ Fraud detection: Rule engine + ML model cần build?
□ Industry fraud registry: Cần integrate?
□ Solvency controls: SCR calculation, Cục GS BH reporting?
□ Health data privacy: Nghị định 13/2023 compliance nếu có health data?

Flag: mandatory regulatory controls vs operational best practices
Mandatory (phải có): Grace period 30 ngày, Cục GS BH reporting format
Best practice (nên có): Fraud scoring, STP routing
```

### Bước 5: Cross-agent Dependencies

```
Identify và tag cross-domain requirements:

Finance-expert (tag: [FINANCE]):
□ Premium accounting (earned premium, UPR)
□ Claims reserves (OCR, IBNR)
□ Reinsurance premium ceded accounting
□ Investment income (life with savings component)

Legal-expert (tag: [LEGAL]):
□ Policy wording review và approval workflow
□ Exclusion clause library
□ Claim dispute resolution process
□ Reinsurance treaty terms

Compliance-expert (tag: [COMPLIANCE]):
□ Cục GS Bảo hiểm reporting (Thông tư 67/2023)
□ Solvency Capital Requirement calculation
□ Annual Actuarial Report format
□ Luật KDBH 08/2022 compliance checklist

Customer-expert (tag: [CX]):
□ Policyholder self-service portal UX
□ Claims status communication
□ Renewal journey
□ Post-claim NPS/satisfaction
```

### Bước 6: Viết Requirements

Format mỗi requirement:

```markdown
### REQ-INS-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì, STP, loss ratio, compliance]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Tags**: [STP-CANDIDATE] [FINANCE] [LEGAL] [COMPLIANCE] [CX]
```

**REQ-ID Format:**
```
REQ-INS-POLICY-001  → Policy Administration
REQ-INS-UW-001      → Underwriting
REQ-INS-CLAIM-001   → Claims Management
REQ-INS-REIN-001    → Reinsurance
REQ-INS-DIST-001    → Distribution / Agency
REQ-INS-ACT-001     → Actuarial / Reserving
REQ-INS-RPT-001     → Reporting & Compliance
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/insurance-requirements.md

Cấu trúc output:
1. Executive Summary (scope, LoB, scale)
2. Line of Business & Distribution Channel
3. Personas affected (summary, link to personas.md)
4. Insurance Modules cần build (list)
5. STP Potential Analysis (current rate → target rate)
6. Requirements (theo module, có REQ-ID + tags)
7. Regulatory & Compliance Requirements (mandatory)
8. Cross-agent Dependencies (FINANCE/LEGAL/COMPLIANCE/CX)
9. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-INS-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng (STP, loss ratio, compliance impact)
□ Line of Business đã xác định (Life/Non-life/Composite)
□ Regulatory mandatory controls đã included (Grace period, Cục GS BH reporting)
□ Dual control requirements đã covered (UW, Claims)
□ Health data privacy đã addressed nếu có health/life module
□ STP candidates đã labeled
□ Cross-agent tags ([FINANCE], [LEGAL], [COMPLIANCE], [CX]) đã gán
□ Open questions được list ra để stakeholders review
```
