# Lint Rules cho E2E Test Scenarios (G1.1)

## Mục đích

Ngăn flaky test bằng cách enforce coding standards ngay khi generate scenarios (phase4-ui-mapping).
6 rules được áp dụng ở PRE-GATE của wf-e2e-scenario trước khi execute.

---

## Rules (BLOCK scenario nếu vi phạm)

### RULE 1: NO_HARDCODED_SLEEP

Vi phạm (bất kỳ dạng nào):
- `await page.waitForTimeout(2000)`
- `setTimeout(() => ..., 1000)`
- `sleep(2000)`

Thay thế đúng:
- `await page.locator('...').waitFor({ state: 'visible', timeout: 5000 })`
- `await page.waitForLoadState('networkidle')`
- `await page.waitForResponse(r => r.url().includes('/api/') && r.status() === 200)`

Lý do: Hardcoded sleep gây flakiness khi môi trường chậm hơn thời gian hardcode. Wait động bám theo trạng thái thực tế của DOM/network.

---

### RULE 2: NO_INDEX_SELECTORS

Vi phạm:
- `page.locator('.btn:nth-child(3)')`
- `//div[3]/button[2]`
- `page.locator('tr').nth(0)`

Thay thế đúng:
- `page.locator('[data-testid="submit-btn"]')`
- `page.getByRole('button', { name: 'Submit' })`
- `page.getByLabel('Email')`

Lý do: Index selector phụ thuộc thứ tự DOM — thay đổi UI nhỏ làm test fail sai.

---

### RULE 3: NO_REAL_EXTERNAL_CALLS

Vi phạm:
- Direct call tới `api.sendgrid.com`, `twilio.com`, `smtp.gmail.com`
- `fetch('https://real-banking-api.com/...')`

Thay thế đúng:
- MSW mock setup ở scenario init
- Mock fixture trong `.mc-data/work/wf-e2e-verify/sessions/{id}/mocks/`

Lý do: Real external calls gây flakiness do rate-limit, network latency, và side effects.

---

### RULE 4: NO_RAW_TIME_LOGIC

Vi phạm:
- `Date.now()` trong assertions
- `new Date().getFullYear()` trong test logic

Thay thế đúng:
- `const NOW = '2026-05-15T10:00:00Z'; jest.useFakeTimers().setSystemTime(NOW)`
- Dùng constant time fixture

Lý do: Test phụ thuộc thời gian thực tế thay đổi theo ngày chạy → flaky hoặc fail sau khi deploy.

---

### RULE 5: NO_SHARED_STATE_LEAKAGE

Vi phạm:
- Test A rely on localStorage từ Test B
- Global state mutation giữa các scenarios

Thay thế đúng:
- Mỗi scenario: `await page.context().clearCookies()` + clearStorage()
- Fresh browser context per scenario

Lý do: Shared state tạo ra test order dependency — không thể chạy độc lập hay parallel.

---

### RULE 6: EXPLICIT_WAIT_ASSERTIONS

Vi phạm:
- `expect(text).toBe('Success')` — immediate assertion (không có timeout)

Thay thế đúng:
- `await expect(page.locator('.toast')).toContainText('Success', { timeout: 5000 })`

Lý do: Immediate assertion fail khi element chưa render xong — cần explicit wait với timeout hợp lý.

---

## Lint Output Schema

```json
{
  "lint_report_v1": true,
  "scenario_file": "",
  "violations": [
    {
      "rule": "NO_HARDCODED_SLEEP",
      "line": 42,
      "code": "await page.waitForTimeout(2000)",
      "suggestion": "await page.locator('.submit').waitFor({ state: 'visible', timeout: 5000 })"
    }
  ],
  "block_execution": true,
  "auto_fix_available": true
}
```

`block_execution: true` khi có ≥1 vi phạm.
`auto_fix_available: true` khi suggestion có thể áp dụng tự động (RULE 1, 6).

---

## Điểm áp dụng trong pipeline

1. **wf-e2e-finding phase4-ui-mapping**: Generate scenarios tuân theo lint rules ngay từ đầu.
2. **wf-e2e-scenario SKILL.md PRE-GATE**: Chạy `lint-scenario.sh` trước khi execute — BLOCK nếu vi phạm.
3. **Pre-commit hook** (tùy chọn): `.claude/scripts/wf-e2e-verify/lint-scenario.sh` tích hợp vào git hooks.

---

## Script tham chiếu

`.claude/scripts/wf-e2e-verify/lint-scenario.sh` — CLI lint tool theo 6 rules.

Usage:
```bash
lint-scenario.sh <scenario-file>         # Human-readable output
lint-scenario.sh <scenario-file> --json  # JSON output cho machine-read
```

Exit code 0 = PASS, 1 = FAIL (có vi phạm BLOCK).
