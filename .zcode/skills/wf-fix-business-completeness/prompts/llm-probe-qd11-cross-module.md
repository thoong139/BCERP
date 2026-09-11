# LLM Probe — QD11 Cross-Module Pattern Comparison (Pass 1)

Vai tro: Senior business analyst chuyen phat hien pattern inconsistency giua cac module cung domain. So sanh entity forms, lists, workflows giua cac module de tim MISSING features/fields/validations.

> **v1.0 (2026-05-12):** Pass 1 cua QD11 Business Completeness. HIGH confidence signals.

---

## 1. Tap trung phat hien

### 1.1 Entity Form Comparison

So sanh fields, types, validators giua cac form cung loai (vd: "Tao khach hang" trong CRM vs "Tao nha cung cap" trong Procurement):

1. **MISSING_FIELD**: Field ton tai trong reference module nhung thieu trong target module. Vd: CRM co field "tax_code" trong customer form nhung Procurement khong co "tax_code" trong supplier form.
2. **TYPE_MISMATCH**: Cung field name nhung khac type giua cac module. Vd: "amount" la Decimal(10,2) trong Sales nhung Integer trong Invoice → khong the chua decimal values.
3. **VALIDATION_GAP**: Reference module co validation (required, format, range) nhung target module khong co. Vd: Sales validate phone format nhung CRM khong validate.

### 1.2 List/Table Feature Comparison

So sanh search, filter, sort, pagination, export features:

4. **MISSING_FEATURE (search/filter)**: Module A co search full-text + filter theo status/date, module B cung domain chi co sort don gian.
5. **MISSING_FEATURE (export)**: Module A co export PDF/Excel, module B cung domain khong co export nao.
6. **MISSING_FEATURE (pagination)**: Module A co pagination + page size selector, module B khong co (tat ca records tren 1 trang).

### 1.3 Action Button Comparison

So sanh Save/Cancel/Reset/Delete/Export/Import actions:

7. **MISSING_FEATURE (action)**: Reference module co "Duplicate" / "Archive" / "Send Email" action, target module thieu.

### 1.4 Workflow Step Comparison

So sanh approval steps, notifications, status transitions:

8. **MISSING_FEATURE (workflow)**: Reference module co approval flow (submit → review → approve) nhung target module cung loai chi co direct save.

---

## 2. Severity Calibration (QD11 Pass 1)

| Signal | Default severity | Bump khi |
|--------|------------------|----------|
| MISSING_FEATURE | **HIGH** | Anh huong core business flow → CDG-ENHANCEMENT |
| MISSING_FIELD | **MEDIUM** | La mandatory field domain → HIGH |
| TYPE_MISMATCH | **MEDIUM** | Gay silent data loss khi share data → HIGH |
| VALIDATION_GAP | **LOW** | La validation compliance → MEDIUM |

---

## 3. KHONG focus (tranh false positive)

1. **Differences ve naming convention**: kebab-case vs camelCase vs snake_case — KHONG emit.
2. **Differences ve UI styling**: mau sac, font, spacing, layout — KHONG emit.
3. **Features chi co 1 module co**: Khong co reference module de so sanh → KHONG emit (khong biet do la "missing" hay "intentional").
4. **Differences do domain khac nhau**: Module A (finance) co fields module B (HR) khong co — day la intentional domain scope, KHONG emit.
5. **Differences ve version library/framework**: Module A dung React 18, module B dung React 17 — KHONG emit (khong phai business completeness).

---

## 4. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de enhance cross-module comparison:

- **Entity field inventory**: `mcp__serena__get_symbols_overview({relative_path})` → lay tat ca fields cua entity class (vd: Customer vs Supplier).
- **Route/feature mapping**: `mcp__plugin_gitnexus_gitnexus__route_map()` → so sanh endpoint list giua cac module.
- **Validation usage**: `mcp__serena__find_referencing_symbols({name_path: "validate" | "z.object" | "class-validator", relative_path})` → dem validation usage per module.

Populate `evidence.ci_citation` voi `serena_refs_count`, `tools_used`.

---

## 5. Vi du

### 5.1 Positive — Missing export feature

```json
{
  "title": "Module Invoice thieu export PDF — Sales module da co tinh nang nay",
  "description": "Trong Sales module (reference), nguoi dung co the export danh sach don hang ra PDF qua nut 'Export PDF'. Trong Invoice module (target), khong co bat ky export feature nao. Ca 2 module cung domain (finance/sales), cung nguoi dung ke toan — ho can export invoice de gui cho khach hang.",
  "severity": "high",
  "signal_type": "MISSING_FEATURE",
  "target_module": "invoice",
  "reference_module": "sales",
  "detail": "SalesOrders.tsx:145 co <ExportButton format='pdf' />, Invoices.tsx khong co export component nao",
  "suggestion": "Them export PDF button trong Invoice list, reuse SalesOrders export component (extract sang shared package)",
  "fixability": "agent_fix",
  "domain": "finance",
  "req_ids": [],
  "feat_ids": ["FEAT-INVOICE-LIST"],
  "location": {"file": "apps/invoice/src/pages/Invoices.tsx", "line": null},
  "evidence": {
    "code_snippet": "// SalesOrders.tsx:145 — co export\n<Button onClick={handleExportPdf}>Export PDF</Button>\n\n// Invoices.tsx — khong export\n// (no export component found)",
    "confidence": 0.85,
    "ci_citation": {"tools_used": ["serena", "gitnexus_route_map"]}
  },
  "remediation": {
    "suggested_action": "Trich xuat ExportButton thanh shared component trong packages/ui, them vao Invoices.tsx, dong thoi them export Excel (da co trong Sales module).",
    "estimated_effort_min": 60,
    "regression_risk": "low"
  }
}
```

### 5.2 Edge case — TYPE_MISMATCH

```json
{
  "title": "Field 'discount' khac type giua Sales va Invoice → khong the share data",
  "description": "Trong Sales module, 'discount' la DECIMAL(5,2) (percentage, vd: 15.50%). Trong Invoice module, 'discount' la INTEGER (absolute VND). Khi chuyen tu Sales order → Invoice, discount value bi sai (15.5% vs 15 VND).",
  "severity": "medium",
  "signal_type": "TYPE_MISMATCH",
  "target_module": "invoice",
  "reference_module": "sales",
  "detail": "Sales: discount DECIMAL(5,2) -- Invoice: discount INTEGER",
  "suggestion": "Unify discount field type thanh DECIMAL(10,2) absolute VND o ca 2 module, hoac rename thanh discount_percent vs discount_amount de tranh confusion",
  "fixability": "manual_fix",
  "domain": "finance"
}
```

### 5.3 Counter-example — DO NOT emit

```typescript
// CRM: CustomerForm.tsx
<Form>
  <Input name="name" label="Ten khach hang" />
  <Input name="email" label="Email" />
  <Input name="phone" label="So dien thoai" />
  <Select name="industry" label="Nganh nghe" />
</Form>

// HR: EmployeeForm.tsx
<Form>
  <Input name="name" label="Ten nhan vien" />
  <Input name="email" label="Email" />
  <Input name="department" label="Phong ban" />
</Form>
// LLM TEMPTED: "CRM co 'industry' field, HR khong co → MISSING_FIELD!" → SAI
```

**Ly do KHONG emit:**
- CRM va HR la 2 domain KHAC NHAU (customer vs employee).
- "industry" la CRM-specific field, khong lien quan den HR.
- KHONG cung domain → KHONG compare.

---

> **Tham chieu**: QD11 dimension.json, `SKILL.md` Pass 1 description.
