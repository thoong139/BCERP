# F2 wf-e2e-browser — Resume + Status Handlers

## --status

```
================================================================
F2 wf-e2e-browser — Status Dashboard
Session: {SESSION_DIR}
================================================================

Pre-Scan Summary:
- Candidates from 4 sources: 11
- After dedup: 8
- Tests to execute: 8

Execution Progress:
| # | Test ref                     | Source      | Status     | Result      |
|---|------------------------------|-------------|------------|-------------|
| 1 | RBAC sales-manager dashboard | ui-test     | executed   | ✅ PASS      |
| 2 | Customer create validation   | ui-test     | executed   | ❌ FAIL_BUG  |
| 3 | Order checkout flow          | integration | executed   | ✅ PASS      |
| 4 | Toast animation              | block-test  | executed   | ⚠️ MANUAL    |
| 5 | Loading state slow API       | issues      | executed   | ✅ PASS      |
| 6 | Bulk delete confirm dialog   | ui-test     | pending    | -           |
| 7 | Mobile responsive            | ui-test     | pending    | -           |
| 8 | Session timeout              | ui-test     | pending    | -           |

Issues added: 1 (ISS-012)
Manual entries added: 1 (MAN-002)
Implement-required added: 0
Block-test added: 1 (BLK-008)

Browser lock: NOT HELD
================================================================
STOP
```

## --resume

```
1. Acquire $LOCK
2. Read status.json: current_test_idx, executed_tests
3. Re-login if session timeout
4. Skip tests đã executed
5. Continue từ current_test_idx + 1
6. Idempotent: skip tests có screenshot + Pass/Fail filled
```

## Idempotency

- Tests đã có entry trong browser-test-report.md → SKIP
- Re-execute tests có screenshot nhưng chưa filled Pass/Fail
- block-test.json / implement-required.json / manual.json APPEND-only (dedupe by test_ref)

## Error Codes

| Code | Mô tả |
|------|-------|
| E020 | F1 outputs không đủ |
| E021 | Playwright/FE not running |
| E022 | --session thiếu |
| E023 | Browser lock |
| E009 | Context >90% |
