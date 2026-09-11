# LLM Probe — QD11 Registry Gap Detection (Pass 3)

Vai tro: Auditor kiem tra alignment giua requirements registry (SSOT) va code thuc te. So sanh `req-registry.json` voi source code de phat hien requirements co trong registry nhung khong co implementation, FEAT-ID khong map toi file nao, REQ-ID da mark "done" nhung code khong co annotation.

> **v1.0 (2026-05-12):** Pass 3 cua QD11 Business Completeness. HIGHEST confidence signals (registry la SSOT — CORE-004).

---

## 1. Tap trung phat hien

### 1.1 Unimplemented Requirements

1. **UNIMPLEMENTED_REQ**: REQ-ID co trong registry, `impl_status = "not_started"` hoac `"in_progress"`, nhung requirement nay lien quan den scope hien tai (cung module/system). Day la gap ro rang giua "da cam ket" va "da lam".

   Cach detect:
   - Doc `req-registry.json` → loc requirements co `impl_status != "done"` va `impl_status != "skipped"`
   - Kiem tra xem requirement do co lien quan den scope khong (qua `related_modules[]`)
   - Neu requirement lien quan den scope → emit UNIMPLEMENTED_REQ

### 1.2 Orphan REQ-ID Annotations

2. **ORPHAN_REQ_ID**: REQ-ID co `impl_status = "done"` trong registry, nhung KHONG tim thay REQ-ID annotation (`// REQ-ID: REQ-XXX-NNN`) trong bat ky source file nao. Co the:
   - Code da bi xoa nhung registry chua update
   - Registry bi mark "done" sai (false completion)
   - REQ-ID annotation bi format sai (khong match grep pattern)

   Cach detect:
   - Doc `req-registry.json` → loc requirements co `impl_status = "done"`
   - Grep source code cho pattern `REQ-ID: <req_id>`
   - Neu khong tim thay → emit ORPHAN_REQ_ID

### 1.3 Missing FEAT-ID Mapping

3. **GAP_REQ_TO_FEAT**: Requirement trong registry khong co `feat_id` mapping (field empty hoac missing). Requirement khong the trace toi feature → khong the implement.

   Cach detect:
   - Doc `req-registry.json` → loc requirements co `feat_id` empty/null/missing
   - Neu requirement khong phai `impl_status = "skipped"` → emit GAP_REQ_TO_FEAT

---

## 2. Severity Calibration (QD11 Pass 3)

| Signal | Default severity | Bump khi |
|--------|------------------|----------|
| UNIMPLEMENTED_REQ | **HIGH** | La P0 requirement (core business) → CRITICAL |
| ORPHAN_REQ_ID | **MEDIUM** | Nhieu REQ-ID don cung bi (systemic) → HIGH |
| GAP_REQ_TO_FEAT | **MEDIUM** | Requirement la mandatory → HIGH |

---

## 3. KHONG focus (tranh false positive)

1. **Requirements co `impl_status = "skipped"`**: Da duoc quyet dinh skip → KHONG emit.
2. **Requirements co `impl_status = "done"` va tim thay REQ-ID annotation**: Da implement day du → KHONG emit.
3. **Requirements thuoc module/system KHAC scope hien tai**: KHONG lien quan den scope → KHONG emit (khong gay anh huong den nguoi dung hien tai).
4. **FEAT-ID mapping trong future phase**: Requirement da co FEAT-ID plan cho phase sau → KHONG emit GAP_REQ_TO_FEAT.
5. **REQ-ID annotation format khac nhung van nhan dien duoc**: REQ-ID viet la `// REQ-ID:REQ-SALES-001` (thieu space) → van tim duoc, KHONG emit ORPHAN_REQ_ID.

---

## 4. CI Tools (uu tien khi available)

- **REQ-ID search trong code**: `Grep({pattern: "REQ-ID:\\s*REQ-\\w+-\\d+"})` → tim tat ca REQ-ID annotations.
- **FEAT-ID search**: `Grep({pattern: "FEAT-ID:\\s*FEAT-\\w+-\\d+"})` → tim tat ca FEAT-ID annotations.
- **Cross-reference impact**: `mcp__plugin_gitnexus_gitnexus__impact({target: <requirement_name>})` → verify implementation scope.

---

## 5. Vi du

### 5.1 Positive — Unimplemented requirement

```json
{
  "title": "REQ-INV-005 (Invoice Approval Workflow) co impl_status=not_started nhung lien quan den scope hien tai",
  "description": "Theo req-registry.json, REQ-INV-005 yeu cau invoice approval workflow (submit → manager_review → director_approve). impl_status=not_started. Module invoice dang trong scope fix bugs hien tai. Requirement nay la core business flow cho invoice processing.",
  "severity": "high",
  "signal_type": "UNIMPLEMENTED_REQ",
  "target_module": "invoice",
  "detail": "req-registry.json: REQ-INV-005 impl_status=not_started, related_modules=[\"invoice\"], priority=P0",
  "suggestion": "Implement invoice approval workflow theo spec trong phase2-features/invoice/approval.md. Can entity InvoiceApproval + state machine submit→review→approve/reject.",
  "fixability": "agent_fix",
  "domain": "finance",
  "req_ids": ["REQ-INV-005"],
  "feat_ids": [],
  "location": {"file": ".mc-data/docs/_meta/req-registry.json", "line": null},
  "evidence": {
    "code_snippet": "// REQ-INV-005 in req-registry.json:\n{\n  \"id\": \"REQ-INV-005\",\n  \"description\": \"Invoice approval workflow\",\n  \"impl_status\": \"not_started\",\n  \"related_modules\": [\"invoice\"],\n  \"priority\": \"P0\",\n  \"feat_id\": null\n}",
    "confidence": 0.95
  },
  "remediation": {
    "suggested_action": "Tao InvoiceApproval entity, implement state machine (SUBMITTED→REVIEWED→APPROVED|REJECTED), them approval UI page, send notification khi status change.",
    "estimated_effort_min": 240,
    "regression_risk": "medium"
  }
}
```

### 5.2 Edge case — Orphan REQ-ID

```json
{
  "title": "REQ-CRM-003 (Customer Import) mark done nhung khong tim thay REQ-ID annotation trong code",
  "description": "Trong req-registry.json, REQ-CRM-003 co impl_status=done. Tuy nhien, grep toan bo source code cho pattern 'REQ-ID: REQ-CRM-003' khong tra ve ket qua nao. Co the code da bi xoa trong 1 lan refactor hoac impl_status bi mark sai (false completion). Kiem tra git log cho thay file import-customers.ts da bi xoa 3 thang truoc.",
  "severity": "medium",
  "signal_type": "ORPHAN_REQ_ID",
  "target_module": "crm",
  "detail": "REQ-CRM-003 mark done trong registry nhung 0 annotation tim thay trong codebase. Git log: import-customers.ts deleted in commit abc123.",
  "suggestion": "Kiem tra lai: (1) neu import feature da duoc thay bang API khac → update registry mo ta, (2) neu code bi xoa nham → restore tu git, (3) neu feature da duoc drop → cap nhat impl_status=skipped",
  "fixability": "manual_fix",
  "domain": "sales"
}
```

### 5.3 Counter-example — DO NOT emit

```json
// req-registry.json
{
  "id": "REQ-HR-PAYROLL-012",
  "description": "Integration voi BHXH API (expected Q3/2026)",
  "impl_status": "not_started",
  "related_modules": ["hr-payroll"],
  "priority": "P2",
  "feat_id": "FEAT-HR-PAYROLL-BHXH"
}
// LLM TEMPTED: "REQ-HR-PAYROLL-012 not_started trong HR-payroll module → UNIMPLEMENTED_REQ!" → SAI
```

**Ly do KHONG emit:**
- Requirement nay la P2, planned cho Q3/2026 (future).
- Co FEAT-ID mapping ro rang (FEAT-HR-PAYROLL-BHXH).
- Module HR-payroll KHONG phai scope fix bugs hien tai (user dang fix bugs trong CRM).
- KHONG lien quan den scope → KHONG emit.

---

> **Tham chieu**: QD11 dimension.json, `req-registry.json` (SSOT — CORE-004), `SKILL.md` Pass 3 description.
