# F8 wf-e2e-demo — Resume + Status Handlers

## --status

```
================================================================
F8 wf-e2e-demo — Status Dashboard
Session: {SESSION_DIR}
================================================================

Demo Progress:
| # | Step Name                  | Match    | Screenshot              |
|---|----------------------------|----------|-------------------------|
| 1 | Đăng nhập sysadmin         | exact    | demo-01-login.png       |
| 2 | Điều hướng CRM > Customer  | exact    | demo-02-navigate.png    |
| 3 | Click Tạo Customer         | partial  | demo-03-tao.png         |
| 4 | Điền form                  | exact    | demo-04-fill.png        |
| 5 | Click Lưu                  | (pending)| -                       |
| 6 | Verify toast               | (pending)| -                       |

Summary:
- Total: 6 steps
- Demoed: 4
- Exact: 3 | Partial: 1 | None: 0
- Current accuracy: 87%

Browser lock: NOT HELD
Mode: desktop, headless
Auto-correct: OFF
================================================================
STOP
```

## --resume

```
1. Acquire browser-mcp.lock
2. Read status.json: current_step_idx
3. Skip steps có match field non-null (đã demoed)
4. Re-login (session timeout)
5. Continue từ current_step_idx + 1
6. Idempotent: skip steps đã có screenshot
```

## Idempotency

- Steps có `match=exact|partial|none` → SKIP (đã demoed)
- Steps có screenshot exists nhưng match=null → re-execute (incomplete)
- Screenshot overwrite OK

## Error Codes

| Code | Mô tả |
|------|-------|
| E080 | user-guide.md không tồn tại |
| E081 | Playwright không available |
| E082 | FE không running |
| E083 | Login fail |
| E084 | Browser lock conflict |
| E009 | Context >90% |
