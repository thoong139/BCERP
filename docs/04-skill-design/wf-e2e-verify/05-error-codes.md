# 05 — Error Codes

> **Mục đích file:** Namespace E001-E099 (orchestrator E001-E009 + F0/F0a/F0b E010-E019 + delegated sub-skill errors).

---

## 1. Namespace allocation

| Range | Phase / Category | Số codes thực dùng |
|-------|-----------------|-------------------|
| E001-E009 | Orchestrator pipeline/session/lock | 9 |
| E010-E019 | F0 / F0a / F0b errors | 10 |
| E020-E089 | Delegated sub-skill errors (F1-F8 namespace) | per sub-skill |
| E090-E099 | CDG user-facing gates (AskUserQuestion escalations) | 10 |

---

## 2. Orchestrator errors (E001-E009)

| Code | Severity | Tình huống | Action |
|------|---------|-----------|--------|
| E001 | CRITICAL | FEAT-ID không hợp lệ (không tồn tại trong registry) | STOP, hỏi user — `<FEAT-ID>` typo? Hoặc chạy `/wf-define-features` |
| E002 | CRITICAL | Feature spec không tồn tại hoặc <500 bytes | STOP, suggest implement spec trước (chạy `/wf-design`) |
| E003 | CRITICAL | Sub-skill spawn fail (Agent tool error) | Retry x1, escalate AskUserQuestion |
| E004 | HIGH | Anti-loop F6↔F5 max 3 vòng | Escalate AskUserQuestion — Continue / Skip / Cancel. Mark issue `status=still_fail` |
| E005 | HIGH | Phase gating T4 cross-ref fail (outputs khớp contract) | Auto-fix retry x3, escalate |
| E006 | MEDIUM | Legacy flag mapping ambiguous (vd `--phase=X` không rõ) | WARN, ask user |
| E007 | HIGH | Lock active (process khác đang chạy cùng FEAT-ID) | Retry sau 30s, hoặc abort |
| E008 | LOW | Stale lock (>30 min) | Auto-release, retry |
| E009 | CRITICAL | Context >90% — FORCE STOP | Checkpoint bắt buộc, hướng dẫn `--resume` |

---

## 3. F0 / F0a / F0b errors (E010-E019)

| Code | Step | Severity | Tình huống | Action |
|------|------|---------|-----------|--------|
| E010 | F0 | HIGH | Infra check gặp lỗi không xác định | STOP, escalate |
| E011 | F0 | HIGH | Backend health fail (HTTP error / timeout) | BLOCKED_INFRA — orchestrator STOP, hướng dẫn user start backend |
| E012 | F0 | HIGH | Frontend health fail | BLOCKED_INFRA |
| E013 | F0 | HIGH | Playwright MCP không available | BLOCKED_INFRA — install Playwright MCP |
| E014 | F0 | HIGH | DB connection fail | BLOCKED_INFRA |
| E015 | F0a | HIGH | wf-e2e-finding spawn fail | Retry x1, escalate |
| E016 | F0a | HIGH | F0a outputs thiếu sau spawn (8 findings files) | E003 cascade |
| E017 | F0b | MEDIUM | seed-manifest spawn fail | BLOCKED_SEED — manual seed |
| E018 | F0b | MEDIUM | Seed data validation fail | BLOCKED_SEED |
| E019 | F0a/F0b | LOW | Context > 50% sau F0a — checkpoint suggested (G4 gate) | WARN không block — suggest `/clear + --resume` trước F1 |

---

## 4. Delegated sub-skill errors (E020-E089)

Mỗi sub-skill có namespace riêng (xem `_contract.json` của sub-skill):

| Sub-skill | Namespace | Số codes |
|-----------|-----------|----------|
| F1 `wf-e2e-test` | E020-E029 | 10 |
| F2 `wf-e2e-browser` | E030-E039 | 10 |
| F3 `wf-e2e-unblock` | E040-E049 | 10 |
| F4 `wf-e2e-implement` | E050-E059 | 10 (delegate `wf-implement-feature` errors map qua) |
| F5 `wf-e2e-retest` | E060-E069 | 10 |
| F6 `wf-e2e-fix` | E070-E079 | 10 |
| F7 `wf-e2e-scenario` | E080-E084 | 5 |
| F8 `wf-e2e-demo` | E085-E089 | 5 |

Orchestrator wrap sub-skill errors với context (`step`, `passes_used`) khi log vào `error-ledger.json`. KHÔNG cascade — sub-skill error mức HIGH+ → orchestrator detect failure → POST-VERIFY fail → retry/escalate.

---

## 5. CDG gates (E090-E099, user-facing)

| Code | Trigger | User question | Default action |
|------|---------|--------------|----------------|
| E090 | Anti-loop F6↔F5 hit 3 (CDG cascade từ E004) | "Vấn đề X không thể fix sau 3 vòng. Chọn: (a) Tiếp tục dù chưa fix / (b) Skip vấn đề / (c) Hủy" | (b) Skip |
| E091 | Standalone F6 với path không tồn tại | "File `<path>` không tồn tại. Chọn: (a) Path khác / (b) Hủy" | (b) Cancel |
| E092 | Browser auto-start fail 2 lần | "Playwright không khởi động được. Chọn: (a) Manual start + retry / (b) Skip F2/F5/F7/F8" | (a) Manual |
| E093 | Sub-skill output schema mismatch | "F{N} output không khớp contract. Chọn: (a) Re-run / (b) Continue dù sai / (c) Hủy" | (a) Re-run |

---

## 6. Error ledger pattern

File: `$SESSION_DIR/error-ledger.json` (APPEND-only JSONL)

```json
{"step": "F4", "code": "E050", "severity": "HIGH", "message": "wf-e2e-implement delegate failed for IMPL-REQ-002", "timestamp": "2026-05-13T14:32:00+07:00", "retry_count": 1, "context": { "sub_skill": "wf-implement-feature", "passes_used": ["FEAT-EW-CRM-001", "--from-fix-bugs"] }}
{"step": "F6", "code": "E004", "severity": "HIGH", "message": "Anti-loop F6↔F5 hit 3 — escalate", "timestamp": "2026-05-13T15:00:00+07:00", "context": { "f6_f5_loop_count": 3, "stuck_issues": ["ISS-005"] }}
```

**Quy tắc:** APPEND-only qua `ledger_log()` helper. KHÔNG đọc lại làm input context (CORE-026).

---

## 7. Auto-fix budget

| Phase | Max retries | Strategy |
|-------|-------------|----------|
| F0/F0a/F0b | 1 (re-spawn) | Re-spawn sub-skill với fresh context |
| F1-F8 sub-skill spawn fail | 1 (re-spawn) → escalate | Re-spawn → escalate AskUserQuestion |
| POST-VERIFY tier fail | 3 retries | Re-run sub-skill (T1/T2/T3) hoặc re-validate cross-ref (T4) |
| Anti-loop F6↔F5 | 3 vòng max | ESCALATE E004 |
| Anti-loop F3↔F2 | 2 vòng max | ESCALATE |

**Budget reset:** sau POST-GATE PASS per step. Budget hết → ESCALATE.

---

## 8. Escalation policy

Khi auto-fix budget exhausted, orchestrator dừng và chạy `AskUserQuestion`:

```
Sub-skill F{N} ({skill}) không thể tự fix sau 3 retries.
Lỗi cuối: E{XXX} — {message}.

Bạn muốn:
  1. Re-run F{N} từ đầu (clean state)
  2. Skip F{N} (mark skipped, continue pipeline — RISKY)
  3. Cancel orchestrator (lưu checkpoint cho --resume sau)
```

**Special:** E004 (anti-loop F6↔F5) và E009 (context >90%) luôn ESCALATE.

---

## 9. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §wf-e2e-verify
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md)
- Pattern: [`../../03-design-patterns/10-cdg-gate.md`](../../03-design-patterns/10-cdg-gate.md)
- Rules: CORE-034 (Namespaced Error Codes), CORE-026 (Execution Trace), Protocol 16 (CDG)
