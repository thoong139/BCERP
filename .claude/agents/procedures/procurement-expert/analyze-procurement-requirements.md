# Playbook: Phân tích Procurement Requirements

> **Type**: Agent Skill Playbook
> **Agent**: procurement-expert
> **Triggered by**: /wf-analyze-requirements khi có procurement/vendor management modules
> **Output**: `.mc-data/docs/phase1-business/procurement-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: procurement, sourcing, vendor/supplier management, PO, RFQ, contract, spend management, mua sắm, thu mua, nhà cung cấp
- Khi cần xác định procurement requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình doanh nghiệp (sản xuất, thương mại, dịch vụ, IT)
□ Quy mô (SMB / Mid-market / Enterprise)
□ Loại thu mua chính (Direct: nguyên vật liệu / Indirect: dịch vụ, văn phòng phẩm)
□ Có hệ thống procurement hiện tại chưa? Nếu có → đang dùng gì?
□ Số lượng PO/tháng ước tính (để định quy mô hệ thống)
□ Số lượng vendor hiện tại và dự kiến
```

### Bước 2: Xác định procurement modules cần có

Dựa trên loại business, map ra modules:

| Business Type | Modules thường cần |
|--------------|-------------------|
| Sản xuất (Manufacturing) | Sourcing, Vendor Mgmt, RFQ, PO, Contract, Goods Receipt, 3-way Matching |
| Thương mại (Trading) | Vendor Mgmt, PO, Goods Receipt, Spend Analysis |
| Dịch vụ (Service) | Indirect Procurement, Vendor Mgmt, Contract Mgmt, Spend Control |
| IT / SaaS | Software/License Procurement, Vendor Mgmt, Contract Renewal alerts |
| Xây dựng (Construction) | Project-based PO, Sub-contractor Mgmt, RFQ/RFP, Contract |

Sau khi xác định → load knowledge file tương ứng:
```
Vendor/Supplier → READ: personas.md (Vendor persona) + processes.md (Vendor Onboarding)
PR/PO workflow → READ: processes.md (PR-to-PO) + controls.md (Authorization Matrix)
RFQ/RFP → READ: processes.md (RFQ Process)
Controls/Compliance → READ: controls.md
Spend/Reporting → READ: processes.md (KPIs section)
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng procurement system:
□ Procurement Manager → cần oversight, spend visibility, vendor governance
□ Buyer / Purchasing Officer → cần execution tools (RFQ, PO creation)
□ Requisitioner / Requester → cần guided PR creation, status tracking
□ Category Manager → cần spend analytics, supplier base management
□ Vendor / Supplier → cần portal để respond RFQ, acknowledge PO, submit invoice
□ Finance / AP → cần 3-way matching, invoice approval, payment scheduling
□ Department Manager → cần PR approval workflow, budget visibility

Với mỗi persona: note down pain points và must-have features
```

### Bước 4: Xác định approval thresholds

```
READ: controls.md → Authorization Matrix + Approval Limits Detail

Hỏi hoặc suy luận từ context:
□ Threshold tự động approve PR (ví dụ: <$1,000 auto-approve)?
□ Level approval theo giá trị (Dept Manager / Procurement / Finance / C-level)?
□ Có cần CapEx approval riêng không?
□ Emergency procurement process như thế nào?
□ Sole-source (single vendor) có cần waiver approval không?
□ Có split-order prevention rules không?

Ghi rõ threshold matrix sẽ được cấu hình vào system
```

### Bước 5: Xác định compliance requirements

```
READ: controls.md → Segregation of Duties Matrix + Vendor Onboarding Controls

Checklist tuân thủ:
□ Segregation of Duties: Requester ≠ Approver ≠ Receiver ≠ AP?
□ Three-quotes rule: Cần bao nhiêu quotes trước khi chọn vendor?
□ Anti-bribery controls:
   - Conflict of interest declaration bắt buộc không?
   - Gift register / entertainment tracking cần không?
   - Politically Exposed Person (PEP) screening cần không?
□ Vendor sanctions screening (OFAC, UN lists)?
□ Audit trail yêu cầu: Cần lưu tối thiểu bao nhiêu năm?
□ Contract obligations: Có regulated industries (food, pharma, defense)?
□ ESG/Sustainability: Có vendor sustainability scoring cần không?
```

### Bước 6: Xác định integration points

```
Procurement thường kết nối với:
□ Finance / Accounts Payable:
   - Budget check khi tạo PR/PO
   - 3-way matching (PO + GRN + Invoice)
   - Payment scheduling sau khi match
□ Inventory / Warehouse:
   - Goods Receipt Note (GRN) sau khi nhận hàng
   - Reorder point triggers PR tự động
   - Inventory valuation update
□ ERP:
   - Master data sync (vendors, items, GL accounts)
   - Cost center allocation
□ Vendor Portal:
   - RFQ distribution và quote collection
   - PO acknowledgment
   - Invoice submission
□ Contract Management:
   - Contract expiry alerts
   - Contract-to-PO linkage (spend vs. commitment)
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-PROC-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

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
REQ-PROC-SRC-001   → Sourcing / Strategic procurement
REQ-PROC-VND-001   → Vendor Management
REQ-PROC-RFQ-001   → RFQ / RFP process
REQ-PROC-PO-001    → Purchase Order management
REQ-PROC-PR-001    → Purchase Requisition
REQ-PROC-CON-001   → Contract Management
REQ-PROC-GRN-001   → Goods Receipt
REQ-PROC-INV-001   → Invoice / 3-way Matching
REQ-PROC-SPD-001   → Spend Analysis / Reporting
REQ-PROC-CTL-001   → Controls / Compliance
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/procurement-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope procurement)
2. Procurement Modules cần build (list)
3. Personas affected (summary)
4. Approval Threshold Matrix
5. Requirements (theo module, có REQ-ID)
6. Integration requirements với Finance, Inventory, Vendor Portal
7. Compliance checklist items cần implement
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format (REQ-PROC-[MODULE]-[NNN])
□ Mỗi REQ có Business Value rõ ràng
□ Approval threshold matrix đã được ghi rõ
□ Segregation of Duties đã được xác định
□ Compliance requirements (anti-bribery, audit trail) đã covered
□ Integration với Finance AP và Inventory đã noted
□ Vendor portal requirements đã included (nếu applicable)
□ Open questions được list ra để stakeholders review
```
