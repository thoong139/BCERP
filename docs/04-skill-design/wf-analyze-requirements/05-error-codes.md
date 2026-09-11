# 05 — Error Codes

> **Mục đích file:** Catalog error codes — chính: E000-E007 (skill-specific) + CDG-A01/A02 user-facing.

---

## 1. Error codes

| Code | Severity | Tình huống | Action |
|------|---------|-----------|--------|
| E000 | CRITICAL | `req-registry.json` không tồn tại / invalid | STOP, hướng dẫn chạy `/wf-brainstorm` trước |
| E001 | CRITICAL | PRE-GATE fail — brainstorm docs chưa có | STOP, hướng dẫn `/wf-brainstorm` |
| E002 | MEDIUM | `req-registry.json` schema fields missing | Auto-fix: tạo schema rỗng với required keys |
| E003 | HIGH | Agent timeout / không trả output | Re-spawn 1 lần; vẫn fail → skip + WARNING |
| E004 | HIGH | Conflict giữa expert outputs (cross-dept) | Route Phase 6d resolve hoặc DEFER-TO-DESIGN |
| E005 | MEDIUM | Output file write fail | Retry 3 lần, sau đó escalate |
| E006 | LOW | User cancel giữa workflow | Lưu checkpoint, hướng dẫn `--resume` |
| E007 | CRITICAL | Phase 8b auto-correction loop > 3 | STOP, báo cáo chi tiết errors còn lại |
| E010 | HIGH | Lane dispatch fail (`_shared/lane/dispatcher.py` error) | Re-import + retry, escalate sau 3 |
| E016 | CRITICAL | `P0-01-brainstorm.md` không tồn tại | STOP, hướng dẫn `/wf-brainstorm` |
| E020 | HIGH | Phase 2 plan generation fail (expert mapping incomplete) | Retry với context Phase 1 |
| E030 | MEDIUM | Phase 3 BA agent missing dept file (Phần A) | Re-spawn BA cho dept thiếu |
| E040 | MEDIUM | Phase 4 expert lane signal.json invalid schema | Re-spawn expert với schema error context |
| E050 | LOW | Phase 6 dedup conflict không resolve được tự động | Route Phase 6d EXPERT-RESOLVE |
| E060 | MEDIUM | Template strip phát hiện `_*` keys leak vào canonical | Re-run strip + atomic write |

---

## 2. CDG gates (E090-E099, user-facing)

| Code | Trigger | User question | Default action |
|------|---------|--------------|----------------|
| CDG-A01 | Domain ambiguity (vd "ERP" có thể là Manufacturing hoặc Retail) | "Domain X có thể là A hoặc B. Chọn (a) A / (b) B / (c) Cả hai" | (a) Hỏi expert |
| CDG-A02 | Workload Gate `block` zone — user muốn Override | "Workload estimate ratio > 1.5 ({minutes} min dự kiến). Chọn (a) Plan A narrow scope / (b) Plan B Override + CDG / (c) Cancel" | (a) Plan A |

CDG decisions log vào `sessions/{id}/cdg-tokens.json`:

```json
{
  "$schema": "cdg-tokens-v1",
  "tokens": [
    {
      "cdg_id": "CDG-A02-workload-override",
      "timestamp": "ISO 8601",
      "context": { "ratio": 1.8, "estimated_minutes": 81 },
      "decision": "accept",
      "user_acknowledged": true,
      "audit_chain": { "source": "...", "checksum": "..." }
    }
  ]
}
```

---

## 3. Auto-fix budget

| Phase | Max retries | Strategy |
|-------|-------------|----------|
| Phase 0 | 1 | Re-detect LEGACY_MODE |
| Phase 0.5 | 1 | Re-compute workload, ESCALATE nếu vẫn block |
| Phase 3 | 3 | Re-spawn BA agent với error context |
| Phase 4 | 3 per lane | Re-spawn expert; nếu vẫn fail → skip lane + WARN |
| Phase 6 | 3 | Re-aggregate với clean state |
| Phase 8 | 3 | Re-validate + re-write registry |
| Phase 8b | 3 iterations | 8 checks → auto-fix → re-run all 8 (không chỉ check lỗi cũ) |

---

## 4. Error ledger pattern

File: `sessions/{id}/error-ledger.json` (lazy-init, APPEND-only)

```json
{"phase": "P4", "lane": "sales", "code": "E040", "severity": "MEDIUM", "message": "...", "timestamp": "...", "retry_count": 1}
```

CORE-026: output-only, không đọc lại làm input.

---

## 5. Escalation policy

Khi auto-fix budget exhausted:
- Phase 8b loop > 3 → STOP với iteration log + errors remaining
- Phase 4 lane fail 3 lần → skip lane + WARN trong report
- Phase 3 BA fail 3 lần → ESCALATE, không thể tiếp tục

**CDG escalation:** CDG-A02 Override luôn yêu cầu user confirmation rõ. KHÔNG bypass.

---

## 6. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §wf-analyze-requirements
- Pattern: [`../../03-design-patterns/10-cdg-gate.md`](../../03-design-patterns/10-cdg-gate.md)
- Source: [`procedures/_shared.md`](../../../.claude/skills/workflow/wf-analyze-requirements/procedures/_shared.md) §Error Codes
- Rules: CORE-027 (CDG), CORE-034 (Namespaced error codes)
