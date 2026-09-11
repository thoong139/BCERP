# F5 wf-e2e-retest — Resume + Status Handlers

## --status

```
================================================================
F5 wf-e2e-retest — Status Dashboard
================================================================

Scan Summary:
- Reports scanned: 5
- Pending items found: 23
  - Reports PENDING/SKIP/⬜: 12
  - issues.json retest needed: 8
  - block-test.json retest needed: 3

Progress:
| Source | Total | Retested | PASS | FAIL | Remaining |
|--------|-------|----------|------|------|-----------|
| Reports | 12 | 10 | 8 | 2 | 2 |
| issues.json | 8 | 8 | 6 | 2 | 0 |
| block-test.json | 3 | 3 | 2 | 1 | 0 |

Current scope: all
Playwright: ENABLED (default)
Browser lock: HELD by wf-e2e-retest
Anti-loop counter: 1 / 3
================================================================
STOP
```

## --resume

```
1. Acquire lock (browser-mcp if Playwright)
2. Read F5-retest/status.json: items_retested, current_idx
3. Read pending-items.txt → skip processed entries
4. Continue retest từ current_idx + 1
5. Idempotent: items có report row đã updated với PASS/FAIL → SKIP
```

## Idempotency

- Items với report row đã update với PASS/FAIL + Re-tested ISO → SKIP
- issues.json signals retest_count > 0 → SKIP (đã retest)
- block-test entries retest_result ≠ PENDING → SKIP

## Error Codes

| Code | Mô tả |
|------|-------|
| E050 | Reports không tồn tại |
| E051 | --session thiếu |
| E052 | Browser lock conflict |
| E053 | Playwright/FE không available |
| E054 | Anti-loop max 3 vòng |
| E009 | Context >90% |
