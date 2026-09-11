# F6 wf-e2e-fix — Resume + Status Handlers

## --status

```
1. Read $F6_DIR/status.json (own state)
2. Read $ISSUES (signals[] + summary)
3. Display:

================================================================
F6 wf-e2e-fix — Status Dashboard
Session: {SESSION_DIR}
================================================================

Fix Loop Progress:
- Current round: {current_round} / max 50 (safety net)
- Issues attempted this session: {total_attempted}

Issues Status Counts:
| Status           | Count |
|------------------|-------|
| open             | 5     |
| fixed            | 12    |
| still_fail       | 2     |
| deferred-locked  | 1     |
| unfixable        | 0     |

Anti-loop counter (orchestrator): f6_f5_loop_count = 1 / 3

Top 3 still_fail (need manual):
- ISS-007: API validation logic — failed 3 retries, root cause: Domain entity missing field
- ISS-015: UI workflow regression — failed 3 retries, complex state interaction
- ISS-022: Cross-module event handler — failed 3 retries, requires architectural change
================================================================

4. STOP
```

## --resume

```
1. Acquire $F6_DIR/.lock
2. Read $F6_DIR/status.json:
   - current_round: N
   - in_progress_issue_id: ISS-NNN (nullable)
3. Continue fix loop từ ROUND_NUM=N
4. Skip issues đã fixed/still_fail/deferred-locked/unfixable
5. Process remaining open issues
```

## Idempotency

- Issues đã fixed → SKIP forever
- Issues still_fail → SKIP forever (đã exhausted retry budget)
- Issues deferred-locked → retry next round IF lock released
- Issues unfixable → SKIP (user manual override)

## Error Codes

| Code | Mô tả |
|------|-------|
| E060 | issues.json invalid |
| E061 | --session missing |
| E007 | Lock active |
| E008 | Stale lock |
| E009 | Context >90% |
