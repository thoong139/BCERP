# Playbook: Phân tích Legal Requirements

> **Type**: Agent Skill Playbook
> **Agent**: legal-expert
> **Triggered by**: /wf-analyze-requirements khi có legal/compliance modules
> **Output**: `.mc-data/docs/phase1-business/legal-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: contract, compliance, GDPR, legal docs, NDA, CLM, e-signature, regulatory, IP
- Khi cần xác định legal requirements từ business idea hoặc mô tả hệ thống

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Ngành nghề & lĩnh vực kinh doanh (Banking, Healthcare, Manufacturing, SaaS...)
□ Jurisdictions áp dụng (Vietnam only / Multi-country / Global)
□ Loại thực thể pháp lý (JSC, LLC, Branch office, Listed company...)
□ Quy mô doanh nghiệp (SME / Enterprise / Group of companies)
□ Đã có legal system chưa? Nếu có → đang dùng gì?
□ Các đối tác và khách hàng nước ngoài (ảnh hưởng cross-border compliance)
```

### Bước 2: Xác định legal scope

Dựa trên loại business, map ra các domain pháp lý cần cover:

| Domain | Khi nào cần | Modules thường cần |
|--------|-------------|-------------------|
| **CLM** – Contract Lifecycle | Luôn cần | Template library, Drafting, Approval, E-signature, Repository |
| **Policy Management** | Khi cần quản lý nội bộ | Policy CRUD, Version control, Acknowledgment tracking |
| **Data Privacy / GDPR** | Khi có data cá nhân | Consent management, DPR/DSAR, Retention policy |
| **Regulatory Compliance** | Theo ngành | Control library, Compliance calendar, Evidence management |
| **IP Management** | Khi có tài sản trí tuệ | Trademark/Patent tracking, License management |
| **Dispute Management** | Khi cần theo dõi tranh chấp | Case tracking, Timeline, Settlement |

Sau khi xác định → load knowledge files tương ứng:
```
CLM → READ: operations.md (Section 1 + Section 2) + controls.md (Section 1 + 2)
Data Privacy → READ: controls.md (Section 4 + 5) + operations.md (Section 4)
E-signature → READ: controls.md (Section 5)
Retention/Disposal → READ: controls.md (Section 6)
Audit trail → READ: controls.md (Section 7)
```

### Bước 3: Xác định Legal Personas

```
READ: personas.md

Xác định ai sẽ dùng legal system:
□ Legal Counsel → cần contract review tools, template library, version control
□ Legal Manager → cần team dashboard, workload tracking, compliance overview
□ Compliance Officer → cần regulatory calendar, control tracking, evidence management
□ Contract Administrator → cần workflow automation, expiry alerts, e-signature
□ Company Secretary → cần board portal, corporate records, filing deadlines
□ Business User (Sales/Procurement/HR) → cần self-service contract request

Với mỗi persona: ghi lại pain points hiện tại và must-have features
```

### Bước 4: Xác định Regulatory Framework

```
Dựa trên jurisdictions đã xác định ở Bước 1:

Vietnam:
□ Luật Doanh nghiệp 2020 – corporate governance
□ Bộ Luật Dân sự 2015 – hợp đồng dân sự
□ Luật Thương mại 2005 – hợp đồng thương mại
□ Luật Bảo vệ Dữ liệu Cá nhân (PDP) – nếu xử lý dữ liệu cá nhân
□ Quy định ngành (Ngân hàng: Thông tư NHNN / Y tế: Thông tư BYT...)

Cross-border (nếu applicable):
□ GDPR – EU data subjects
□ CCPA – California customers
□ eIDAS – EU electronic signatures
□ ESIGN Act – US electronic signatures
□ Singapore PDPA – Singapore operations
□ Industry-specific: MiFID II (Finance), HIPAA (Healthcare)...

Với mỗi regulation applicable:
→ Note: Đây là compliance requirement bắt buộc hay best practice?
→ Note: Có penalty cụ thể nếu vi phạm không?
```

### Bước 5: Xác định Data Privacy Requirements

```
READ: controls.md → Section 5 (E-Signature) và Section 6 (Retention)

Checklist:
□ Có xử lý dữ liệu cá nhân không? (tên, CMND, email, địa chỉ trong contracts)
□ Data residency requirements? (Dữ liệu phải lưu trong nước?)
□ Encryption at rest required? (Hợp đồng bí mật, NDA)
□ Retention policy: Bao lâu lưu mỗi loại tài liệu? Xử lý sau khi hết hạn?
□ Consent records cần lưu trữ với audit trail?
□ DSAR (Data Subject Access Request) cần support?
□ Right to erasure – giới hạn bởi retention schedule pháp lý
```

### Bước 6: Phân tích authorization và security controls

```
READ: controls.md → Section 1 (Authorization Matrix) và Section 3 (Document Security)

Xác định:
□ Contract authorization matrix: Ai được duyệt giá trị bao nhiêu?
□ Document classification: Confidential / Internal / Public
□ Access control model: Role-based hay Attribute-based?
□ E-signature levels: Standard / Advanced / Qualified (theo eIDAS)
□ External party access: Counterparty có view portal riêng không?
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-LEGAL-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần – impact gì]
**Regulatory Basis**: [Regulation/Law nào yêu cầu điều này – nếu có]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Risk if missing**: [Rủi ro pháp lý hoặc vận hành nếu không có]
```

**REQ-ID Format:**
```
REQ-LEGAL-CLM-001   → Contract Lifecycle Management
REQ-LEGAL-COMP-001  → Compliance & Regulatory
REQ-LEGAL-POL-001   → Policy Management
REQ-LEGAL-PRIV-001  → Data Privacy / GDPR
REQ-LEGAL-IP-001    → Intellectual Property
REQ-LEGAL-DISP-001  → Dispute Management
REQ-LEGAL-ESIGN-001 → E-Signature
REQ-LEGAL-CORP-001  → Corporate Governance
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/legal-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope pháp lý, jurisdictions)
2. Legal Domains cần build (list với lý do)
3. Regulatory Framework áp dụng (table: Regulation | Jurisdiction | Mandatory)
4. Personas affected (summary với pain points)
5. Requirements (theo domain, có REQ-ID)
6. Integration requirements với các department khác (HR, Finance, Sales, IT)
7. Open questions cần confirm với Legal Director và stakeholders
8. Compliance risks nếu không implement (risk register sơ bộ)
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format (REQ-LEGAL-[MODULE]-[NNN])
□ Mỗi REQ có Business Value rõ ràng
□ Mỗi REQ bắt buộc (từ regulation) có ghi Regulatory Basis
□ Audit trail requirements đã covered cho mọi document actions
□ E-signature compliance đã xác định (eIDAS level / ESIGN Act)
□ Data retention policy đã mapped (per document type)
□ Authorization matrix đã outline (không cần detail ở phase 1)
□ Integration với HR, Finance, Sales, Procurement đã noted
□ Open questions được list để stakeholders review
□ Risk if missing đã ghi cho mọi Must-have requirements
```
