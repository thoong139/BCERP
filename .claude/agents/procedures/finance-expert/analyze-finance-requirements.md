# Playbook: Phân tích Finance Requirements

> **Type**: Agent Procedure
> **Agent**: finance-expert
> **Triggered by**: /wf-analyze-requirements khi project có finance/accounting modules
> **Output**: `.mc-data/docs/phase1-business/finance-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan: kế toán, ngân sách, công nợ, thanh toán, ERP, thuế
- Khi cần xác định finance requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình doanh nghiệp (công ty CP, TNHH, startup, tập đoàn)
□ Quy mô (SME / Mid-market / Enterprise)
□ Chuẩn kế toán áp dụng (VAS / IFRS / Circular 133)
□ Finance scope hiện tại: AR / AP / GL / Budget / Tax / Treasury
□ Đã có phần mềm kế toán chưa? Nếu có → đang dùng gì?
□ Số lượng giao dịch/tháng ước tính
```

### Bước 2: Xác định finance modules cần có

```
READ: operations.md → Section 2: Typical Finance Processes

Dựa trên loại business, map ra modules:

| Business Type | Modules thường cần |
|--------------|-------------------|
| Trading / Phân phối | AR, AP, GL, Inventory Accounting |
| SaaS / Dịch vụ | AR, GL, Budget, Revenue Recognition |
| Manufacturing | AP, GL, Cost Accounting, Budget |
| Retail | AR, AP, GL, Cash Management |
| Holding / Group | GL, Intercompany, Consolidation |

Sau khi xác định → load knowledge file tương ứng:
AR/AP → READ: operations.md (Section 2.1, 2.2)
GL / Month-end → READ: operations.md (Section 2.3)
Controls → READ: controls.md (Section 1, 2, 3)
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng finance system:
□ Accountant → cần data entry + reconciliation tools
□ AP Clerk → cần invoice processing + payment workflow
□ AR Clerk → cần invoicing + collection tools
□ Chief Accountant → cần approval + close management
□ CFO → cần executive dashboard + cash forecast

Với mỗi persona: note down pain points và must-have features
```

### Bước 4: Phân tích compliance requirements

```
READ: controls.md → Section 6: Compliance Requirements

Xác định applicable standards:
□ VAS (Circular 200/2014): Bắt buộc với DN Việt Nam
□ Circular 133/2016: Nếu là SME
□ IFRS: Nếu là công ty niêm yết hoặc FDI

Compliance checklist:
□ Chart of Accounts structure phù hợp VAS?
□ VAT reporting (monthly/quarterly)?
□ CIT estimation (quarterly)?
□ FCT nếu có thanh toán cho nhà thầu nước ngoài?
□ Audit trail: Retention 10 năm theo quy định?
□ Period lock / cut-off controls?
```

### Bước 5: Phân tích controls cần có

```
READ: controls.md → Section 1, 2, 3

Checklist:
□ Approval thresholds phù hợp quy mô DN?
□ SoD matrix: Ai không được kiêm nhiệm gì?
□ Audit trail: Mọi transaction phải log đủ fields
□ Period controls: Month-end lock mechanics
□ Access controls: Role-based permissions
```

### Bước 6: Viết requirements

Format mỗi requirement:

```markdown
### REQ-FIN-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-FIN-AR-001   → Accounts Receivable
REQ-FIN-AP-001   → Accounts Payable
REQ-FIN-GL-001   → General Ledger
REQ-FIN-BUD-001  → Budget Management
REQ-FIN-TAX-001  → Tax / Thuế
REQ-FIN-TRE-001  → Treasury / Cash Management
REQ-FIN-RPT-001  → Financial Reporting
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/finance-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope finance)
2. Finance Modules cần build (list)
3. Accounting Standard áp dụng
4. Personas affected (summary)
5. Requirements (theo module, có REQ-ID)
6. Compliance & Control requirements
7. Integration requirements (Sales, Procurement, HR, Bank)
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-FIN-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Accounting standard (VAS/IFRS/Circular 133) đã xác định
□ SoD requirements đã included
□ Audit trail requirements đã covered
□ Tax compliance (VAT/CIT) đã addressed nếu applicable
□ Integration với departments khác đã noted
□ Open questions được list ra để stakeholders review
```
