# Playbook: Phân tích Sales Requirements

> **Type**: Agent Skill Playbook
> **Agent**: sales-expert
> **Triggered by**: /wf-analyze-requirements khi project có sales/CRM modules
> **Output**: `.mc-data/docs/phase1-business/sales-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: sales pipeline, quotation, order, commission, CRM, deal, opportunity, forecast
- Khi cần xác định sales requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm/dịch vụ (SaaS, E-commerce, Dịch vụ B2B, Phần mềm...)
□ Sales model: B2B hay B2C? Inside Sales hay Field Sales?
□ Deal size & complexity: Transactional (nhanh) hay Enterprise (dài hạn)?
□ Quy mô sales team dự kiến (số lượng rep, manager)
□ Đã có CRM/sales tool chưa? Đang dùng gì?
```

### Bước 2: Xác định sales model và cấu trúc team

```
READ: personas.md

Xác định sales model để biết modules nào cần build:

| Sales Model       | Modules thường cần                                      |
|-------------------|---------------------------------------------------------|
| B2B Inside Sales  | Pipeline, Quotation, Commission, Forecasting, Sequences |
| B2B Field Sales   | Pipeline, Territory, Account Mgmt, POC/Demo, Commission |
| B2C / E-commerce  | Order Mgmt, Promotion, Basic pipeline (nếu có telesales)|
| SaaS Self-serve   | Pipeline nhẹ, Trial tracking, Expansion revenue (NRR)   |
| Enterprise/Complex| MEDDPICC scoring, Multi-stakeholder, Contract mgmt      |

Personas affected:
□ SDR/BDR — cần outbound tools, sequence, lead qualification
□ Account Executive (AE) — cần pipeline, quote, deal management
□ Sales Manager — cần forecasting, team performance dashboard
□ Sales Ops — cần reporting, commission calculation, CRM admin
□ Sales Director — cần pipeline health, revenue forecast, win/loss
```

### Bước 3: Xác định pipeline stages

```
READ: operations.md

Hỏi hoặc suy luận từ context:
□ Số stages trong pipeline (thường 4-7 stages)
□ Entry criteria mỗi stage (qualification gate)
□ Exit criteria (definition of done per stage)
□ Probability mặc định mỗi stage (dùng cho weighted forecast)
□ Có deal scoring (MEDDPICC/BANT) không?
□ Win/Loss tracking: Có capture reason không?

Ví dụ standard pipeline:
Prospecting → Qualified → Demo/Proposal → Negotiation → Closed Won / Closed Lost
```

### Bước 4: Phân tích commission structure

```
READ: controls.md

Xác định:
□ Commission plan type: Flat rate, Tiered, hay Accelerator?
□ Quota basis: Revenue, Volume, hay Mix?
□ Payment periods: Monthly / Quarterly / Annual?
□ SPIFs & bonuses có không?
□ Clawback rules (khi customer churn/cancel)?
□ Manager override commission?
□ Ai approve commission calculations? Dispute process?

Nếu commission phức tạp → note "cần design-commission-system.md" ở Phase 2-3
```

### Bước 5: Phân tích integration requirements

```
Xác định dependencies:
□ Marketing → Sales: Lead handoff từ MQL → SQL, lead source tracking
□ Finance → Sales: Invoice tạo từ closed-won deals, AR tracking
□ Inventory/Ops → Sales: Stock check khi tạo quote
□ HR/Payroll → Sales: Commission payout integration
□ External CRM: Có migrate từ Salesforce/HubSpot không?
```

### Bước 6: Viết requirements

Format mỗi requirement:

```markdown
### REQ-SALES-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

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
REQ-SALES-PIPE-001  → Pipeline management
REQ-SALES-QUOT-001  → Quotation
REQ-SALES-ORD-001   → Order management
REQ-SALES-COMM-001  → Commission & incentives
REQ-SALES-FORE-001  → Forecasting
REQ-SALES-TERR-001  → Territory management
REQ-SALES-ANA-001   → Analytics & reporting
REQ-SALES-INT-001   → Integrations
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/sales-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope sales)
2. Sales Model & Team Structure
3. Sales Modules cần build (list có ưu tiên)
4. Personas affected (summary)
5. Requirements (theo module, có REQ-ID)
6. Integration requirements với các department khác
7. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-SALES-[MODULE]-[NNN]
□ Sales model (B2B/B2C, inside/field) đã xác định rõ
□ Pipeline stages đã được define với probability per stage
□ Commission structure scope đã ghi nhận (dù chưa design chi tiết)
□ Integration với Marketing (lead handoff) đã noted
□ Integration với Finance (invoicing, payroll) đã noted
□ Phân quyền territory/account ownership đã noted
□ Open questions được list để stakeholders review
```
