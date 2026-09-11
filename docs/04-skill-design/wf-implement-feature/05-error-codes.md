# 05 — Error Codes

> **Mục đích file:** Catalog 30+ error codes namespaced E1xx-E9xx + auto-fix budget + legacy alias map.

---

## 1. Namespace allocation (v4.0+)

| Range | Phase / Category | Số codes thực dùng |
|-------|-----------------|-------------------|
| E1xx | Phase 1 (context, registry, pattern scan) | 3 (E101, E102, E103) |
| E2xx | Phase 2 (planning, populate-spec, contracts) | 4 (E201, E202, E203, E204) |
| E3xx | Phase 3 (TDD, test gate, decisions) | 5 (E301, E302, E303, E304, E305) |
| E4xx | Phase 4 (review) | 2 (E401, E402) |
| E5xx | Phase 5a (cross-validation) | 1 (E501) |
| E6xx | Phase 6 (registry write, finalize) | 2 (E601, E602) |
| E9xx | Cross-cutting (lock, history, ledger) | 3 (E901, E902, E904) |

**Đăng ký:** Khớp 100% với [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §wf-implement-feature.

---

## 2. Error codes detail

### E1xx — Phase 1 (Context, Registry)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E101 | LOW | Pattern cache miss / pattern scan failed | Full scan triggered (auto-resolve) |
| E102 | HIGH | `req-registry.json` không tìm thấy hoặc inconsistent / re-run không có flag | ESCALATE — chạy `/wf-analyze-requirements` hoặc hỏi scenario EXTEND/MODIFY |
| E103 | CRITICAL | Không xác định được feature/REQ-ID (thiếu name hoặc lookup fail) | ESCALATE — hỏi user / Retry Phase 1 |

### E2xx — Phase 2 (Planning, Spec)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E201 | HIGH | Task file không tồn tại | Tự generate stub hoặc ESCALATE — chạy `/wf-plan-modules` |
| E202 | HIGH | Feature design không tồn tại / A6-EXT stub detected | ESCALATE — chạy `/wf-design` trước, hoặc populate spec qua Phase 2.4 |
| E203 | MEDIUM | Task list generation failed | Retry Phase 2 (max 3) |
| E204 | MEDIUM | A6-EXT populate failed | Retry Phase 2.4 với context, hoặc fallback A6 (full file) |

### E3xx — Phase 3 (TDD)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E301 | HIGH | Tests failing (test gate fail) | Debug + fix → retry up to 3 attempts. Vẫn fail → ESCALATE |
| E302 | MEDIUM | Decision conflict (Protocol 12) | Resolve theo precedence rule, escalate nếu cross-feature |
| E303 | HIGH | Source file không tạo được | Retry với error context (max 3) |
| E304 | LOW | Thiếu REQ-ID trong source code | Thêm REQ-ID comment (auto qua Phase 5a) |
| E305 | CRITICAL | Auto-fix gây regression | Rollback fix → ESCALATE with context |

### E4xx — Phase 4 (Review)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E401 | MEDIUM | Agent timeout trong Phase 4 | Retry 1 lần. Vẫn timeout → skip agent đó, log warning, tiếp tục agents còn lại |
| E402 | HIGH | Critical/Security issues từ review | Fix trong Review-Fix Loop (max 3 attempts) → ESCALATE |

### E5xx — Phase 5a (Cross-Validation)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E501 | HIGH | Cross-validation auto-correction loop > 3 | STOP — ESCALATE với context auto-correction history |

### E6xx — Phase 6 (Finalize)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E601 | MEDIUM | Registry mutex timeout | Kiểm tra session khác đang giữ lock — wait hoặc force release nếu stale (>60min) |
| E602 | CRITICAL | POST-GATE T1-T4 fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |

### E9xx — Cross-cutting (Lock, History, Ledger)

| Code | Severity | Tình huống | Auto-fix |
|------|---------|-----------|----------|
| E901 | HIGH | Per-feature lock busy / session lifecycle (fresh archive) | Wait, hoặc dùng `--fresh` để xóa impl-status.json, impl-plan.md, checkpoint.json |
| E902 | MEDIUM | History index append fail | Retry với atomic write, escalate nếu disk full |
| E904 | LOW | error-ledger.json truncated (>100 entries, oldest dropped) | Auto-resolve (warning only) |

---

## 3. Legacy alias map (backward compat)

User-facing messages có thể tham chiếu cả mã cũ và mới để clarity:

| Old code | New code | Mô tả |
|----------|----------|-------|
| E001 | E103 | Missing feature name / REQ-ID |
| E002 | E102 | `req-registry.json` không tìm thấy |
| E003 | E103 | Không xác định được feature/REQ-ID |
| E004a | E202 | Feature design không tồn tại |
| E004b | E201 | Task file không tồn tại |
| E005 | E203 | Task list generation failed |
| E006 | E303 | Source file creation failed |
| E007 | E304 | REQ-ID missing |
| E008 | E301 | Tests failing |
| E009 | E402 | Critical/Security issues |
| E010 | E401 | Agent timeout |
| E011 | E602 | POST-GATE fail |
| E012 | E305 | Auto-fix regression |
| E013 | E901 | Session lifecycle (fresh) |
| E014 | E102 | Re-run without flag |
| E015 | E204 | A6-EXT populate failed |

Skill code uses NEW codes (E1xx-E9xx). User-facing messages format: `Error E301 (was E008): Tests failing`.

---

## 4. Error ledger pattern

File: `$SESSION_DIR/error-ledger.json` (schema v1.0, **lazy-init** lần đầu có error, APPEND-only)

```json
{
  "$schema": "error-ledger-v1",
  "schema_version": "1.0",
  "session_id": "2026-05-15-100000-host1",
  "errors": [
    {
      "timestamp": "2026-05-15T14:32:00+07:00",
      "severity": "HIGH",
      "code": "E301",
      "phase": "phase_3_tdd",
      "message": "Tests failing: customer.service.spec.ts — 3 assertions failed",
      "context": { "batch": 2, "files_failed": ["customer.service.spec.ts"] },
      "action": "Retry attempt 1/3",
      "retry_count": 1
    }
  ]
}
```

**Quy tắc:**
- APPEND-only qua helper `ledger_log()` trong `implement-common.sh`
- KHÔNG đọc lại làm input context (CORE-026 output-only)
- Cap 100 entries (oldest dropped, ghi E904 warning)
- Atomic write tmp+mv → safe với parallel agents

Schema chi tiết: [`.claude/skills/workflow/wf-implement-feature/templates/error-ledger.schema.md`](../../../.claude/skills/workflow/wf-implement-feature/templates/error-ledger.schema.md)

---

## 5. Auto-fix budget

| Phase | Max retries | Strategy ordering |
|-------|-------------|-------------------|
| Phase 1 | 3 | T1 fail → re-run step → T2 fail → re-read template → T3 fail → re-generate |
| Phase 2 | 3 | Re-spawn architect agent với error context |
| Phase 3 | 3 | Re-spawn developer agent với failure log |
| Phase 4 | 1 (per agent timeout) | Skip agent timeout, continue với agents còn lại |
| Phase 5a | 3 iterations max | Auto-fix obvious issues (REQ-ID missing, test stub) |
| Phase 6 | 3 | Re-validate POST-GATE T1→T4 |

**Budget reset:** sau POST-GATE PASS. Budget hết → ESCALATE.

---

## 6. Escalation policy

Khi auto-fix budget exhausted, skill **dừng** và chạy `AskUserQuestion`:

```
Phase {N} không thể tự fix sau 3 retries.
Lỗi cuối: E{XXX} (was E{YY}) — {message}.

Bạn muốn:
  1. Re-run phase từ đầu
  2. Skip phase này (risky — chỉ dùng nếu hiểu rõ hậu quả)
  3. Cancel skill (lưu checkpoint cho --resume sau)
```

User chọn → skill route theo lựa chọn. KHÔNG tự skip mà không hỏi user (BHV-001).

**Special:** E602 (POST-GATE fail 3x) và E305 (auto-fix regression) là CRITICAL — luôn ESCALATE, không offer "Skip".

---

## 7. Liên kết

- Source error table chi tiết: [`.claude/skills/workflow/wf-implement-feature/procedures/_shared.md`](../../../.claude/skills/workflow/wf-implement-feature/procedures/_shared.md) §Error Codes Reference
- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md) §auto-fix budget
- Rules: CORE-034 (Namespaced error codes), CORE-026 (Execution trace), BHV-001 (Ask before assume)
