# 05 — Error Codes

> **Mục đích file:** 17 error codes E000-E016 + auto-fix budget per phase.

---

## 1. Error codes

| Code | Severity | Tình huống | Action |
|------|---------|-----------|--------|
| E000 | CRITICAL | `req-registry.json` không tìm thấy | STOP → chạy `/wf-analyze-requirements` |
| E001 | CRITICAL | Registry có modules nhưng chưa có requirements/features | STOP → chạy `/wf-analyze-requirements` hoặc `/wf-define-features` |
| E002 | CRITICAL | Phase 2 features forensic fail (<6 headings hoặc <400 words) | STOP → chạy `/wf-define-features` |
| E003 | HIGH | Agent timeout / không trả output | Re-spawn 1 lần; vẫn fail → skip + WARNING |
| E004 | MEDIUM | Architecture conflict giữa agent outputs | Flag conflict, present both options → user decide |
| E005 | MEDIUM | Output file write fail | Retry 3 lần, escalate |
| E006 | MEDIUM | Integration map inconsistency | Re-run Phase 3 |
| E007 | HIGH | Phase verification failed | Retry phase max 3× |
| E008 | CRITICAL | Max retries exceeded | Escalate với error details |
| E009 | HIGH | Cross-validation mismatch sau 3 iterations (Phase 4) | List mismatches → user decide |
| E010 | CRITICAL | POST-GATE fail sau 3 retries | STOP, báo cáo chi tiết → user quyết định |
| E011 | CRITICAL | Auto-fix gây regression | Rollback → escalate with context |
| E012 | HIGH | Stakeholder review Critical/High findings sau 3 iterations (Phase 5) | STOP + báo cáo findings → user |
| E013 | HIGH | `module-code-mapping.json` không tồn tại (Phase 7 LEGACY) | STOP → chạy `/wf-legacy-extract` trước |
| E014 | MEDIUM | Gap classification fail (Phase 7) | Retry với relaxed thresholds |
| E015 | LOW | Digest generation fail (Phase 8) | Log warning, continue (backward compatible) |
| E016 | LOW | Phase summary template thiếu | Fallback tạo summary inline |

---

## 2. Auto-fix budget per phase

| Phase | Max retries | Strategy |
|-------|-------------|----------|
| Phase 0 | 1 | Re-detect LEGACY, re-load context |
| Phase 0.5 | 1 | Re-compute workload |
| Phase 1 | 3 per lane | Re-spawn architect agent với error context |
| Phase 2 | 3 per spec | Re-spawn dba/devops/architect |
| Phase 3 | 3 | Re-aggregate, resolve conflicts |
| Phase 4 | 3 iterations | 8 checks → auto-fix → re-run all |
| Phase 5 | 3 iterations | Re-spawn review agents |
| Phase 6 | 3 | Re-validate registry write |
| Phase 7 | 3 | Re-classify gaps với relaxed thresholds |
| Phase 8 | 3 | Re-generate digest |

---

## 3. Error ledger pattern

File `sessions/{id}/error-ledger.json` (lazy-init, APPEND-only):

```json
{"phase": "P1", "lane": "crm", "code": "E003", "severity": "HIGH", "message": "architect timeout", "retry_count": 1, "timestamp": "..."}
```

---

## 4. Escalation policy

- E010 (POST-GATE fail) + E011 (regression) + E012 (Critical findings) → CRITICAL — luôn ESCALATE
- E008 (max retries) → ESCALATE với context dump
- E013 (LEGACY missing extract data) → STOP, KHÔNG fallback (cần extract data)

---

## 5. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §wf-design
- Pattern: [`../../03-design-patterns/10-cdg-gate.md`](../../03-design-patterns/10-cdg-gate.md)
- Source: [`procedures/_shared.md`](../../../.claude/skills/workflow/wf-design/procedures/_shared.md)
