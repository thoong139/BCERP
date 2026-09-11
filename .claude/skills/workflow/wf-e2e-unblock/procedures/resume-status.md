# F3 wf-e2e-unblock — Resume + Status Handlers

## --status

```
1. Resolve $SESSION_DIR từ --session=<id>
2. Read $SESSION_DIR/F3-unblock/status.json (own state)
3. Read $SESSION_DIR/block-test.json (summary)
4. Display dashboard:

================================================================
F3 wf-e2e-unblock — Status Dashboard
Session: {SESSION_DIR}
FEAT-ID: {feat_id}
================================================================

Block Processing Progress:
| BLK-ID | Test                      | Group | Status     | Action            | Result    |
|--------|---------------------------|-------|------------|-------------------|-----------|
| BLK-001| GET /api/customers...     | 1     | unblocked  | seed inserted     | PASS      |
| BLK-002| POST /api/orders...       | 2     | unblocked  | BE auto-start     | PASS      |
| BLK-003| validation duplicate...   | 3     | blocked    | skip → F4         | DEFERRED  |
| BLK-004| VNPay sandbox...          | 4     | resolved   | static review     | PASS+MAN  |
| BLK-005| flaky integration...      | 4     | blocked    | flaky 1/3         | NEEDS HUM |

Summary:
- Total blocks: 5
- Unblocked: 2 (Groups 1+2)
- Resolved (Group 4 verified): 1
- Still blocked: 2 (1 Group 3 deferred + 1 Group 4 needs-human)

Group 3 deferred (require F4 wf-e2e-implement):
  - BLK-003 → IMPL-REQ-001 (validation_missing, P0)

Group 4 manual entries:
  - MAN-001 (VNPay) — code verified PASS, QA test theo recommended_test_steps[]
================================================================

5. STOP (no execution)
```

## --resume

```
1. Resolve $SESSION_DIR
2. Acquire $SESSION_DIR/F3-unblock/.lock (heartbeat check 30 min stale)
3. Read $F3_DIR/status.json:
   - current_blk: BLK-NNN đang xử lý (nullable)
   - processed_blks: [BLK-001, BLK-002, ...]
4. Read block-test.json → find blocks NOT in processed_blks
5. Continue loop từ blk đầu tiên chưa processed
6. Idempotent: skip BLK đã unblocked/resolved (status != "blocked")
```

## Idempotency

- F3 reads `status` field của mỗi BLK-NNN. Skip nếu `status` ∈ {unblocked, resolved}.
- Group 1/2 retry max 2 lần. Sau 2 retry fail → keep blocked, mark E032/E033.
- Group 4 verify chỉ chạy 1 lần (verify_code không idempotent về kết quả, retry không giúp).
- `unblock_attempts[]` luôn APPEND, không overwrite.

## Error Codes

| Code | Mô tả |
|------|-------|
| E030 | block-test invalid |
| E031 | --session missing |
| E007 | Lock active |
| E008 | Stale lock auto-released |
| E009 | Context >90% |
