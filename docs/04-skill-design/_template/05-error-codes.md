<!--
_template_notes:
  purpose: Định nghĩa namespace error codes của skill + severity + auto-fix.
  populate:
    - §1 Namespace allocation: range E0xx-E0yy (phải khớp 02-standards/08-error-code-registry.md)
    - §2 Bảng error codes: ID, phase, severity, ý nghĩa, auto-fix strategy
    - §3 Error ledger pattern: cấu trúc JSONL append-only
    - §4 Escalation policy: khi nào ESCALATE qua AskUserQuestion
    - §5 User-facing CDG gates (E090-E099 nếu có)
  độ dài tham khảo: 150-300 dòng
-->

# 05 — Error Codes

> **Mục đích file:** Catalog error codes — registry/severity/auto-fix budget cho skill.

---

## 1. Namespace allocation

| Range | Phase / Category | Số codes |
|-------|-----------------|---------|
| E001-E009 | Shared (pipeline, session, lock) | 9 |
| E010-E019 | Phase 1 (Init) | 10 |
| E020-E029 | Phase 2 ({name}) | 10 |
| E030-E039 | Phase 3 ({name}) | 10 |
| E040-E049 | Phase 4 ({name}) | 10 |
| E090-E099 | CDG user-facing gates | 10 |
| E100-E109 | Recommendations / Warnings | 10 |

**Đăng ký:** Phải khớp 100% với [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §{skill section}.

---

## 2. Error codes detail

### Shared (E001-E009)

| Code | Phase | Severity | Ý nghĩa | Auto-fix strategy |
|------|-------|---------|---------|-------------------|
| E001 | Any | CRITICAL | Session lock conflict | Wait + retry (max 3) |
| E002 | Any | HIGH | Heartbeat stale | Auto-release sau 30 min |
| E009 | Any | CRITICAL | Context budget >90% | FORCE STOP, checkpoint bắt buộc |

### Phase 1 — Init (E010-E019)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E010 | CRITICAL | Args invalid | ESCALATE |
| E011 | CRITICAL | Registry missing/invalid | ESCALATE |
| E012 | HIGH | Registry empty | ESCALATE |
| E013 | MEDIUM | Registry-phase2 drift | Re-validate (max 1) |

{... lặp cho mỗi range ...}

### CDG gates (E090-E099, user-facing)

| Code | Trigger | User question | Default action |
|------|---------|--------------|----------------|
| E090 | Conflict A vs B | "Chọn cách xử lý A hay B?" | ABORT |
| E091 | Destructive op | "Có chắc xóa X?" | ABORT |
| {...} | {...} | {...} | {...} |

---

## 3. Error ledger pattern

File: `$SESSION_DIR/error-ledger.json` (JSONL, APPEND-only)

```json
{"phase": 2, "error_code": "E020", "message": "...", "timestamp": "2026-05-15T14:32:00+07:00", "retry_count": 1}
{"phase": 2, "error_code": "E020", "message": "...", "timestamp": "2026-05-15T14:32:30+07:00", "retry_count": 2}
{"phase": 2, "error_code": "E020", "message": "...", "timestamp": "2026-05-15T14:33:00+07:00", "retry_count": 3}
```

**Quy tắc:** APPEND-only, không đọc lại làm input context (CORE-026).

---

## 4. Auto-fix budget

| Phase | Max retries | Strategy ordering |
|-------|-------------|-------------------|
| Phase 1 | 3 | T1 fail → re-run step → T2 fail → re-read template → T3 fail → re-generate |
| Phase 2-N | 3 | Same pattern |

**Budget reset:** sau POST-GATE PASS. Budget hết → ESCALATE.

---

## 5. Escalation policy

Khi auto-fix budget exhausted, skill **dừng** và chạy `AskUserQuestion`:

```
Phase {N} không thể tự fix sau 3 retries.
Lỗi cuối: E0{XX} — {message}.

Bạn muốn:
  1. Re-run phase từ đầu
  2. Skip phase này (risky)
  3. Cancel skill
```

User chọn → skill route theo lựa chọn.

---

## 6. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md) §auto-fix budget
- Rules: CORE-034 (Namespaced error codes), CORE-026 (Execution trace)
