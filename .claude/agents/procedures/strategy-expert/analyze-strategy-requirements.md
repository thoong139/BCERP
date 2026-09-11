# Playbook: Phân tích Strategy Requirements

> **Type**: Agent Procedure
> **Agent**: strategy-expert
> **Triggered by**: /wf-analyze-requirements khi project có strategy/governance/executive modules
> **Output**: `.mc-data/docs/phase1-business/strategy-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào: executive dashboard, OKR/BSC, board portal, M&A, holding company, strategic planning
- Khi cần xác định strategy/governance requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại tổ chức: single entity / group holding / listed company / startup
□ Số tầng quản lý: Flat (CEO → Function Heads) vs Tall (CEO → C-suite → BU → Dept → Team)
□ Quy mô: SME (<50 người) / Mid (<500) / Enterprise (<5000) / Conglomerate (5000+)
□ Đã có strategy tools chưa? (Excel, Power BI, BSC software, chưa có gì)
□ Governance maturity: Ad hoc (không có formal governance) / Structured / Sophisticated (formal board)
□ Có subsidiaries không? Nếu có → bao nhiêu, có listed không?
```

### Bước 2: Identify C-suite personas

```
READ: .claude/references/team-expert/strategy/personas.md

Xác định personas hiện diện trong dự án:
□ CEO / TGĐ → hầu hết dự án
□ CFO / GĐ Tài chính → nếu có financial reporting
□ Board Directors → nếu có formal HĐQT (thường từ Mid-size trở lên)
□ Strategy Manager → nếu có strategy department hoặc planning function
□ BU Heads → nếu có multiple business units

⚠️ KHÔNG assign Board persona nếu là startup / SME không có formal HĐQT
Map: persona → needs → pain points cụ thể → must-have features
```

### Bước 3: Map strategic planning process

```
READ: .claude/references/team-expert/strategy/operations.md

Xác định:
□ Strategic planning maturity hiện tại (ad hoc / structured / sophisticated)
□ Reporting cadence hiện tại (monthly? quarterly? ad hoc?)
□ Governance calendar: HĐQT họp bao nhiêu lần/năm?
□ OKR/KPI maturity: đã có framework chưa, hay mới bắt đầu?
□ M&A activity: đang active deal flow không?
□ Holding structure complexity: bao nhiêu subsidiaries, có cross-border không?

Flag nếu:
→ Reporting cadence hiện tại < best practice → opportunity để improve
→ Governance chưa formal → cần educate client về governance requirements
```

### Bước 4: Kiểm soát và phân quyền

```
READ: .claude/references/team-expert/strategy/controls.md

Xác định:
□ DoA (Delegation of Authority) hiện có hay chưa?
  → Nếu chưa có: recommend design DoA trước khi build approval workflows
□ Information classification needs:
  → Có M&A activity → cần Board Confidential tier
  → Có listed company → cần stricter controls (insider trading)
□ Board vs Management data separation:
  → Board xem gì? Management xem gì? Ai KHÔNG được xem gì?
□ Audit trail requirements:
  → Board resolutions: vĩnh viễn
  → Strategy documents: 10 năm
```

### Bước 5: Gap analysis

```
So sánh: quy trình hiện tại vs yêu cầu phần mềm mới

Quick wins (Low complexity, High value):
□ KPI dashboard automation (replace manual Excel)
□ OKR check-in platform (replace email follow-up)
□ Board pack auto-generation (replace manual compilation)

Complex builds (High effort, High value):
□ Full OKR cascade system với hierarchy enforcement
□ M&A pipeline management với VDR integration
□ Consolidated reporting với intercompany elimination

Flag cross-agent dependencies:
→ Consolidated financials → finance-expert
→ M&A legal docs / SPA / shareholder agreements → legal-expert
→ Risk dashboard / ERM integration → enterprise-risk-expert
→ KPI data pipelines / ETL from operational systems → data-expert
→ Succession planning / performance linked to OKR → hr-expert
```

### Bước 6: Viết requirements

```
REQ-ID format: REQ-STR-[MODULE]-[NNN]
MODULE codes:
  EXEC  → Executive Dashboard / C-suite reporting
  OKR   → OKR / KPI / Balanced Scorecard
  BOARD → Board Portal / Governance
  MA    → M&A Pipeline / Due Diligence
  HOLD  → Holding Company / Subsidiary Management
  PLAN  → Strategic Planning / Scenario Modeling

OUTPUT: Ghi vào path do skill cung cấp.
FALLBACK: .mc-data/docs/phase1-business/strategy-requirements.md

Output structure:
1. Executive Summary (3-5 dòng: tổ chức là ai, scope strategy, maturity level)
2. Personas identified (list với priority)
3. Strategy modules cần build (list với priority và complexity estimate)
4. Governance requirements (DoA, information classification, audit trail)
5. Requirements (theo module, có REQ-ID)
6. Integration requirements (Finance, HR, Operations, Data)
7. Quick wins vs Complex builds
8. Open questions cần confirm với stakeholders
```

---

## Format Requirements

```markdown
### REQ-STR-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-STR-[MODULE]-[NNN]
□ Personas được xác định phù hợp với quy mô/loại tổ chức thực tế
□ DoA requirements đã captured nếu có approval workflows
□ Information classification đã defined cho Board / C-Suite / Management tiers
□ Audit trail requirements đã included
□ M&A confidentiality controls đã addressed nếu applicable
□ Integration points với finance/HR/data-expert đã noted
□ Cross-agent dependencies đã flagged
□ Open questions được list ra để stakeholders review
```
