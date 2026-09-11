# F4 wf-e2e-implement — Resume + Status Handlers

## --status

```
================================================================
F4 wf-e2e-implement — Status Dashboard
Session: {SESSION_DIR}
================================================================

Implement Queue:
- Total entries: 5
- pending: 2
- in_progress: 1 (IMPL-REQ-003)
- done: 1
- skipped: 1

Current item: IMPL-REQ-003
  Priority: P1
  Strategy: COMPLETE_EXISTING
  Delegate session: wf-implement-feature/sessions/2026-05-13-...
  Started: 2026-05-13T18:30:00Z (waiting ~5 min...)

Progress by priority:
| Priority | Total | Done | Skipped | Pending |
|----------|-------|------|---------|---------|
| P0       | 1     | 1    | 0       | 0       |
| P1       | 2     | 0    | 0       | 1 (+1 in_progress) |
| P2       | 2     | 0    | 1       | 1       |

Registry updates:
- REQ-CRM-001 (from IMPL-REQ-001): not_started → done

Per-entry log:
| IMPL-REQ | Result   | Delegate session    | Registry  |
|----------|----------|---------------------|-----------|
| IMPL-REQ-001 | success | session-001 | done |
| IMPL-REQ-002 | skipped (timeout) | session-002 | not_updated |
| IMPL-REQ-003 | in_progress | session-003 | (pending) |
================================================================
STOP
```

## --resume

```
1. Read F4-implement/status.json: current_impl_req_id, processed_ids
2. Read implement-required.json → find entries NOT in processed_ids and status != done/skipped
3. For each pending: continue delegate spawn
4. Idempotent: skip entries status ∈ {done, skipped}
5. Re-handle current_impl_req_id (in_progress) — check if receipt arrived during downtime
```

## Idempotency

- Entries done/skipped → SKIP (immutable terminal states)
- Entries in_progress: check receipt file existence
  - Receipt exists → process verify-completion → mark done/skipped
  - Receipt missing → retry delegate spawn (lost session) hoặc mark skipped (timeout)

## Error Codes

| Code | Mô tả |
|------|-------|
| E040 | implement-required.json không có pending |
| E041 | --session thiếu |
| E044 | Delegate timeout |
| E045 | Registry SAFE-UPDATE refused |
| E009 | Context >90% |

## Special: Standalone Invocation

User CÓ THỂ chạy `/wf-e2e-implement <FEAT-ID> --session=<id>` riêng (không qua orchestrator). Vd: sau khi user manually populated implement-required.json.

Yêu cầu vẫn là `--session=<id>` (F4 KHÔNG tự tạo session). Session phải đã tồn tại với:
- `implement-required.json` populated
- Registry hợp lệ
- Findings/ context (để inform strategy)
