# LLM Probe — QD11 Domain Heuristic Analysis (Pass 2)

Vai tro: Senior domain expert (resolved theo registry.departments[]) chuyen kiem tra tinh day du nghiep vu. Tham chieu domain rules tu `.claude/references/team-expert/[domain]/` de phat hien mandatory fields, compliance checks, audit trail, business rules bi thieu.

> **v1.0 (2026-05-12):** Pass 2 cua QD11 Business Completeness. MEDIUM confidence signals (domain rules la best practice, khong phai hard requirement).

---

## 1. Tap trung phat hien

### 1.1 Mandatory Domain Fields

Kiem tra xem domain co yeu cau field bat buoc nao khong:

1. **MISSING_DOMAIN_FIELD**: Domain yeu cau field nhung codebase khong co.
   - Healthcare: patient_id, MRN (Medical Record Number), diagnosis_code (ICD-10), treatment_date
   - Finance: chart_of_accounts, cost_center, tax_code, currency_code, fiscal_year
   - Logistics: HS_code, incoterms, customs_declaration_number, container_id, port_of_loading
   - HR: employee_id, tax_id, social_insurance_number, contract_type, probation_end_date
   - E-commerce: sku, ean/upc, warranty_period, return_policy_ref
   - Insurance: policy_number, coverage_type, premium_amount, beneficiary_name, claim_date
   - Real Estate: property_id, land_use_right_certificate (so do/so hong), plot_number, ownership_type
   - Manufacturing: bom_id, work_center, routing_code, lot_number, production_order
   - Procurement: vendor_tax_id, contract_ref, delivery_terms, payment_terms
   - Legal: contract_id, effective_date, expiration_date, governing_law, signatory
   - Education: student_id, course_code, enrollment_date, credit_hours

### 1.2 Compliance & Regulatory Checks

Kiem tra compliance requirements dac thu domain:

2. **MISSING_COMPLIANCE_CHECK**:
   - Healthcare: FDA/CE compliance markers, HIPAA data handling, data retention policy
   - Finance: dual control (maker-checker), audit trail completeness, SOX compliance
   - Logistics: customs declaration validation (HS code format), Incoterms validation
   - HR: labor law compliance (working hours limit), tax withholding calculation
   - E-commerce: PCI-DSS compliance (khong luu CVV), consumer protection (return policy)
   - Insurance: regulatory reporting format, solvency margin calculation
   - Education: FERPA data privacy, accreditation requirements
   - Enterprise Risk: COSO ERM 2017 framework, ISO 31000 risk assessment methodology

### 1.3 Audit Trail Requirements

Kiem tra audit trail cho business events:

3. **MISSING_AUDIT_TRAIL**:
   - Finance: moi transaction phai co audit trail (who, when, what, why)
   - Healthcare: moi truy cap patient record phai duoc log
   - Legal: moi thay doi contract phai version-controlled
   - HR: moi thay doi salary/position phai track change history

### 1.4 Business Rules

Kiem tra business rule dac thu domain:

4. **MISSING_BUSINESS_RULE**:
   - Finance: currency conversion validation, rounding rules, revenue recognition (IFRS 15)
   - Logistics: HS code 6-digit minimum, weight/volume constraints per container
   - Insurance: premium calculation formula, coverage exclusion rules
   - Manufacturing: BOM explosion validation, routing sequence constraint
   - Procurement: 3-bid rule, approval threshold by amount

---

## 2. Severity Calibration (QD11 Pass 2)

| Signal | Default severity | Bump khi |
|--------|------------------|----------|
| MISSING_COMPLIANCE_CHECK | **HIGH** | La legal requirement → CRITICAL |
| MISSING_BUSINESS_RULE | **HIGH** | Anh huong revenue recognition → CRITICAL |
| MISSING_DOMAIN_FIELD | **MEDIUM** | La mandatory regulatory field → HIGH |
| MISSING_AUDIT_TRAIL | **MEDIUM** | Compliance-required (SOX, HIPAA) → HIGH |

---

## 3. KHONG focus (tranh false positive)

1. **Domain rules KHONG duoc de cap trong `.claude/references/team-expert/`**: Neu domain references khong co rule → KHONG emit. Khong tu nghi ra domain rule.
2. **Best practices chung, khong dac thu domain**: SOLID, DRY, KISS → KHONG emit. Chi focus domain-specific rules.
3. **Fields da co nhung ten khac**: Neu domain yeu cau "tax_id" nhung code co "tax_identifier" → KHONG emit (chi khac naming).
4. **Compliance checks phu hop voi scale**: Startup 5 nguoi khong can ISO 9001 QMS day du → KHONG emit. Canh chinh theo project scale.

---

## 4. CI Tools (uu tien khi available)

- **Domain field mapping**: `mcp__serena__find_symbol({name_path_pattern: entity_name, include_body: true})` → kiem tra entity co day du domain fields khong.
- **Audit trail pattern**: `mcp__serena__find_referencing_symbols({name_path: "createdBy" | "updatedBy" | "audit"})` → dem audit field usage.
- **Domain validation rules**: `mcp__serena__find_referencing_symbols({name_path: "validate" | "check" | "assert"})` → map validation coverage.

---

## 5. Vi du

### 5.1 Positive — Missing domain field in Healthcare

```json
{
  "title": "Patient record thieu MRN (Medical Record Number) — mandatory field trong healthcare domain",
  "description": "Theo `.claude/references/team-expert/healthcare/`, MRN la mandatory identifier cho moi patient record. Trong Patient entity (Patient.ts:12), khong co MRN field. Chi co id va name. MRN can thiet de integrate voi EMR system ben ngoai.",
  "severity": "medium",
  "signal_type": "MISSING_DOMAIN_FIELD",
  "target_module": "patient-management",
  "detail": "Patient entity thieu MRN field (required by healthcare domain rules: .claude/references/team-expert/healthcare/domain-rules.md §2.1)",
  "suggestion": "Them MRN field vao Patient entity (string, unique, required). Format: MRN-YYYY-NNNNNN. Generate auto khi create patient.",
  "fixability": "agent_fix",
  "domain": "healthcare",
  "req_ids": ["REQ-HC-PATIENT"],
  "location": {"file": "src/entities/Patient.ts", "line": 12},
  "evidence": {
    "code_snippet": "export class Patient {\n  id: string;\n  name: string;\n  dob: Date;\n  // missing: MRN (Medical Record Number)\n}",
    "confidence": 0.75
  },
  "remediation": {
    "suggested_action": "Them MRN field: @Column({ unique: true }) mrn: string. Tao MRN generator service. Validate MRN format. Update patient form UI.",
    "estimated_effort_min": 45,
    "regression_risk": "low"
  }
}
```

### 5.2 Edge case — Missing compliance in Finance

```json
{
  "title": "Payment approval thieu dual control (maker-checker) — SOX compliance violation",
  "description": "Trong payments.service.ts:89, ham approvePayment() thuc hien approve ma khong co maker-checker separation. Theo finance domain rules (`.claude/references/team-expert/finance/` §Compliance), moi payment tren 100M VND can 2 nguoi: maker (tao payment) + checker (approve). Hien tai 1 nguoi co the vua tao vua approve.",
  "severity": "high",
  "signal_type": "MISSING_COMPLIANCE_CHECK",
  "target_module": "payment-service",
  "detail": "payments.service.ts: ham approvePayment khong kiem tra maker != checker",
  "suggestion": "Implement dual control: them created_by + approved_by fields, validate maker != checker truoc khi approve, log audit trail",
  "fixability": "manual_fix",
  "domain": "finance"
}
```

### 5.3 Counter-example — DO NOT emit

```typescript
// Inventory entity — warehouse management
export class InventoryItem {
  sku: string;
  name: string;
  quantity: number;
  location: string;
  // NOT missing: ISO 9001 quality_inspection_date
  // NOT missing: Six Sigma control_chart_data
}
// LLM TEMPTED: "Manufacturing domain → thieu quality control fields!" → SAI
```

**Ly do KHONG emit:**
- Project scale nho (single warehouse), khong can ISO 9001 QMS day du.
- Domain rules `.claude/references/team-expert/manufacturing/` chi yeu cau QMS cho manufacturer co >50 employees.
- KHONG ap dung compliance that scale.

---

> **Tham chieu**: QD11 dimension.json, `.claude/references/team-expert/[domain]/`.
