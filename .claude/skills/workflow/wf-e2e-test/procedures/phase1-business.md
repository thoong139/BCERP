# Phase 1 Business — ĐÃ DI CHUYỂN

> **Redirect:** Phase 1 Business analysis đã được tách sang **wf-e2e-finding (F0a)** kể từ v2.0.0 (2026-05-15).

wf-e2e-test (F1) bây giờ **consume** findings từ F0a thay vì tự generate.

**Xem implementation đầy đủ tại:**
`.claude/skills/workflow/wf-e2e-finding/procedures/phase1-business.md`

---

## Lý do tách (WHY)

Phase 1 Business Analysis (FIND→ASSESS→BỔ SUNG→VERIFY) là bước đọc spec + code, không có live-test.
Việc tách sang F0a cho phép:
1. **Context separation**: F0a chạy xong → `/clear` → F1 chạy với context sạch hơn
2. **Reuse**: Nhiều F1 sessions có thể consume cùng 1 F0a finding (không cần re-analyze)
3. **Parallel**: F0a và các tác vụ khác có thể chạy song song trong orchestrator

---

## F1 sử dụng F0a findings thế nào

Sau khi Phase 0 SETUP verify F0a outputs (PRE-GATE CONSUME):

```
findings/business-understanding.md  → F1 đọc context cho live-test Phase 2-5
findings/business-rule-catalog.md   → F1 đọc BR list → generate BR violation test cases
findings/state-machine.md           → F1 đọc states → generate state transition tests
findings/cross-module-map.md        → F1 đọc consumers → Phase 5 integration test
```

F1 KHÔNG cần AskUserQuestion VERIFY (đó là việc của F0a).
F1 bắt đầu ngay Phase 2 DB LIVE-TEST sau khi verify F0a findings.
