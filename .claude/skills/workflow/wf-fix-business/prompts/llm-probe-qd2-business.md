# LLM Probe — QD2 Business Logic & Domain Rules (v2.0)

Vai tro: Senior business analyst + code reviewer. **Quan trong nhat trong 7 dimensions** vi business edge cases la blind spot lon nhat cua static probes.

> **v2.0:** mo rong 8 → 13 categories (idempotency, eventual consistency, unit confusion, audit gaps, multi-step form), severity matrix, 3 vi du.

---

## 1. Tap trung phat hien

### 1.1 Core (8 categories ban dau)

1. **State machine inconsistencies**: Status transition khong hop le (vd: lead "lost" → "qualified" trong khi spec yeu cau "lost" la terminal state).
2. **Calculation errors**: Discount/tax/commission tinh sai, rounding errors, tien te conversion thieu.
3. **Business rule violations**: Code khong respect rule trong phase2-features docs (vd: "khach hang VIP duoc giam 10%" nhung code khong check VIP status).
4. **Promotion/discount overlap**: Multiple promotions stack thieu kiem soat, double discount.
5. **Cross-entity consistency**: Order voi total < sum(items), invoice issued nhung payment chua reconcile.
6. **Time/timezone bugs**: Server-side date so sanh client-side date, DST handling, fiscal year boundary.
7. **Permission/role mismatch**: Code allow action ma business rule cam (vd: cashier issue refund khong qua manager approval).
8. **Loss of context**: Field bi reset khi update partial (vd: PATCH endpoint overwrite full object).

### 1.2 Mo rong (5 categories moi — v2.0)

9. **Idempotency bugs**: Retry logic tao duplicate (vd: webhook delivery khong co idempotency key, payment retry tao charge thu 2). Khong co `Idempotency-Key` header check, khong dung unique constraint cho retry.
10. **Eventual consistency assumptions**: Code assume read-after-write thay duoc ngay (read replica lag), distributed transaction khong co compensation, cache invalidation lag → user thay data cu sau action.
11. **Unit/quantity confusion**: kg vs lb, hours vs minutes, VND vs USD, percentage vs decimal (`0.05` vs `5`), sai unit conversion. Vd: `setTimeout(callback, 5)` cho 5 giay (should be 5000).
12. **Audit trail gaps**: Action nghiep vu (delete order, change status, override price, refund) khong duoc log → khong co bang chung khi audit. Compliance violation.
13. **Multi-step form data loss**: Wizard / multi-step form khong persist intermediate state → user back/refresh mat data. Validation chi check final step → step 1 invalid pass through.

---

## 2. Severity Calibration (QD2-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| State machine invalid transition | **high** | Lam mat audit/data → critical |
| Calculation error trong tien/billing | **critical** | Always (regulatory) |
| Promotion stacking double discount | **high** | Lam loss revenue → critical |
| Permission bypass | **high** | Production endpoint → critical |
| Time/TZ bug trong scheduled action | **high** | Cron/payroll/SLA → critical |
| Idempotency missing trong payment | **critical** | Always |
| Idempotency missing trong webhook | **high** | Lan chi 1 lan retry → critical |
| Eventual consistency assumption | **medium** | Trong financial flow → high |
| Unit confusion (currency/qty) | **high** | Trong checkout/billing → critical |
| Audit trail gap | **high** | Compliance-required action → critical |
| Multi-step form data loss | **medium** | Trong onboarding/checkout → high |

---

## 3. KHONG focus (tranh duplicate)

- Hardcoded null UUID → static probe (P-QD2-hardcoded-value-detect)
- Mutation thieu onError → static probe (P-QD1-react-contract-check)
- Calculation formula static check → static probe (P-QD2-calculation-check)
- Domain expert review (large-scale) → agent probe (P-QD2-domain-expert-review)

---

## 4. Negative Patterns — KHONG emit (QD2-specific)

> Bo sung cho `_shared.md` §5.

1. **Hardcoded value KHI** la enum constant theo design (vd: `STATUS_NEW = 'new'`).
2. **Permission check thieu KHI** route da co middleware o cap parent router.
3. **No idempotency KHI** endpoint la `GET` (read-only — khong can idempotency key).
4. **Time comparison khac TZ KHI** ca 2 ben da convert ve UTC truoc do (kiem tra by reading code carefully).
5. **Audit log thieu KHI** la action read-only (vd: `getCustomer`).
6. **Multi-step form khong persist KHI** la single-screen wizard < 30s → acceptable UX (chi cau lai khi user da invest time).

---

## 5. Cach tu loc context

Neu duoc cung cap `phase2-features/[mod]/[feat].md` doc → tham chieu rule trong do.
Neu KHONG co doc → emit signal voi confidence ≤ 0.7 (nho hon vi khong co spec ground truth).

---

## 6. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD2 business correctness:

- **Calculation/formula bugs**: `mcp__plugin_gitnexus_gitnexus__query({query: "<calculation_name>"})` → trace pipeline tinh toan tu input → output, dam bao khong miss step.
- **Hardcoded business value (commission rate, tax %, threshold)**: `mcp__serena__find_referencing_symbols({name_path: <const>, relative_path})` → xem gia tri lan ra dau, du lan rong → severity bump len `high`.
- **Domain rule vi pham (vd: order status workflow)**: `mcp__plugin_gitnexus_gitnexus__context({name: <state_machine_class>})` → xem callers + callees de hieu transition logic.
- **Missing audit/log cho compliance**: `mcp__serena__find_referencing_symbols({name_path: <audit_logger>})` → confirm coverage tren cac action quan trong.
- **Idempotency analysis**: `mcp__plugin_gitnexus_gitnexus__query({query: "payment retry"})` → trace flow + check whether idempotency-key wired.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`.

---

## 7. Vi du

### 7.1 Positive — Permission bypass

```json
{
  "title": "Lead routing skip permission check khi user co role 'agent'",
  "description": "Trong leads/page.tsx:155, function routeToSales() check role === 'manager' moi cho route nhung route handler /api/leads/route khong yeu cau permission. User role 'agent' co the bypass UI check qua direct API call → mat business rule 'chi manager moi route lead'.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-CRM-LEAD-005"],
  "feat_ids": ["FEAT-CRM-LEAD-ROUTING"],
  "affected_modules": ["crm-leads"],
  "location": {"file": "src/api/leads/route.ts", "line": 28},
  "evidence": {
    "code_snippet": "router.post('/route', async (req, res) => {\n  // missing: requireRole('manager') middleware\n  await routeLeadToSales(req.body);\n})",
    "reproduction_steps": "1. Login as agent, 2. POST /api/leads/route voi crmLeadId+routedToUserId, 3. Quan sat: route thanh cong (should be 403)",
    "confidence": 0.85
  },
  "remediation": {
    "suggested_action": "Them middleware requireRole('manager') vao route definition. Test: agent user nhan 403 khi POST /api/leads/route.",
    "test_recommendation": "E2E: agent user POST /api/leads/route → expect 403; manager → expect 200.",
    "estimated_effort_min": 15,
    "regression_risk": "low"
  }
}
```

### 7.2 Edge case — Idempotency missing in payment

```json
{
  "title": "Payment endpoint thieu idempotency key gay charge double khi retry",
  "description": "POST /api/payments/charge xu ly thanh toan nhung khong yeu cau hoac kiem tra Idempotency-Key header. Khi client network timeout → retry → charge thanh cong 2 lan → khach bi tru tien double. Vi pham PCI-DSS section 6.5.10 va Stripe best practice.",
  "severity": "critical",
  "fixability": "manual_fix",
  "domain": "backend",
  "req_ids": ["REQ-PAY-001"],
  "feat_ids": ["FEAT-PAYMENT-PROCESS"],
  "affected_modules": ["payment-service", "order-service"],
  "location": {"file": "src/api/payments/charge.ts", "line": 14},
  "evidence": {
    "code_snippet": "router.post('/charge', async (req, res) => {\n  const charge = await stripe.charges.create({\n    amount: req.body.amount,\n    currency: 'vnd',\n  });\n  return res.json(charge);\n});",
    "reproduction_steps": "1. POST /api/payments/charge body {amount:10000}, 2. Simulate network timeout (drop response), 3. Client auto-retry POST same body, 4. Quan sat DB: 2 charges thay vi 1.",
    "confidence": 0.9,
    "environment": "Production-like load, network instability"
  },
  "remediation": {
    "suggested_action": "Yeu cau Idempotency-Key header. Save (key, response) vao DB unique-indexed. Khi retry voi cung key → return cached response thay vi create charge moi.",
    "test_recommendation": "Integration test: POST same Idempotency-Key 5 times → assert 1 charge in DB + 5 identical responses.",
    "references": ["https://stripe.com/docs/api/idempotent_requests"],
    "estimated_effort_min": 90,
    "regression_risk": "medium"
  }
}
```

### 7.3 Counter-example — DO NOT emit

```typescript
// Read-only endpoint
router.get('/customers/:id', async (req, res) => {
  const customer = await db.customers.findById(req.params.id);
  return res.json(customer);
});
// LLM TEMPTED: "Thieu idempotency key!" → SAI
```

**Ly do KHONG emit:**
- `GET` la idempotent by HTTP spec — khong can `Idempotency-Key`.
- Read-only, khong gay side-effect khi retry.
- Match negative pattern §3 cua dimension QD2.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
