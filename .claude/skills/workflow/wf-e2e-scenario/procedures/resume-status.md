# F7 wf-e2e-scenario — Resume + Status Handlers

## --status

```
1. Read $F7_DIR/status.json
2. Read $SCENARIO (test-scenario.md) → parse all scenarios
3. Read $SCREENSHOTS/ → count existing PNG files
4. Display:

================================================================
F7 wf-e2e-scenario — Status Dashboard
Session: {SESSION_DIR}
FEAT-ID: {feat_id}
================================================================

Scenarios Progress:
| # | Name                          | Loại         | Status       | Pass/Fail | Screenshot     |
|---|-------------------------------|--------------|--------------|-----------|----------------|
| 1 | Tạo Customer happy            | happy        | executed     | ✅ PASS    | ✓              |
| 2 | Validation duplicate email    | validation   | executed     | ❌ FAIL    | ✓ + error.png  |
| 3 | Update Customer permission    | BR           | executed     | ✅ PASS    | ✓              |
| 4 | TMS → CRM cross-module        | cross-module | executed     | ✅ PASS    | ✓ × 2          |
| 5 | Empty state                   | edge         | pending      | -         | -              |
| 6 | Bulk delete                   | edge         | pending      | -         | -              |

Summary:
- Total: 6 scenarios
- Executed: 4 (3 PASS, 1 FAIL)
- Pending: 2
- Failed → issues: ISS-008

Browser lock: NOT HELD
Mobile mode: NO
Show browser: NO
================================================================

5. STOP
```

## --resume

```
1. Acquire $LOCK (browser-mcp.lock)
2. Read $F7_DIR/status.json: current_scenario_idx, last_executed
3. Read $SCENARIO → parse remaining scenarios (status=pending)
4. Re-login (nếu session đã timeout)
5. Continue execution từ current_scenario_idx + 1
6. Idempotent: skip scenarios đã có screenshot + Pass/Fail filled trong test-scenario.md
```

## Idempotency

- Scenarios đã có `Pass/Fail` filled trong test-scenario.md → SKIP
- Scenarios có screenshot tồn tại + Pass/Fail empty → re-execute (incomplete)
- Re-execute không tạo duplicate screenshot (overwrite)
- test-scenario.md updates qua atomic write (không corrupt)

## Error Codes

| Code | Mô tả |
|------|-------|
| E070 | test-scenario.md không tồn tại |
| E071 | Playwright MCP không available |
| E072 | FE không running |
| E074 | Browser lock conflict |
| E009 | Context >90% |
