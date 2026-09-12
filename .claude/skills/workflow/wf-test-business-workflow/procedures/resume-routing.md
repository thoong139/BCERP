# Procedure: --status Dashboard & --resume Routing — wf-test-business-workflow

## --status (đọc, KHÔNG đổi state)

```
1. Đọc _runs/progress.json
2. In dashboard:

================================================================
wf-test-business-workflow — Progress Dashboard
================================================================
Run:      {số WF done}/{tổng} done, {inprogress} in-progress, {blocked} blocked, {pending} pending
Current:  {WF-id đang inprogress, nếu có} (session {SESSION_ID})

| WF-id    | Level | Status      | Presentation | Notes              |
|----------|-------|-------------|--------------|--------------------|
| WF-L1-01 | L1    | done        | ✓            | pass               |
| WF-L1-02 | L1    | blocked     | —            | E006 escalate      |
| ...      |       |             |              |                    |

Blocked summary (nếu có): WF-id + BUG reference + lý do escalate
================================================================
3. EXIT (không claim, không spawn)
```

## --resume Routing

```
1. Tìm session gần nhất của WF đang inprogress:
   ls -td .mc-data/work/wf-test-business-workflow/sessions/*-{WF-id}-* | head -1
2. Đọc SESSION_DIR/test-status.json → next_action
3. Route theo next_action:

   | next_action              | Nhảy tới                          |
   |--------------------------|-----------------------------------|
   | analyze_pending          | Phase 1 (ANALYZE)                 |
   | analyze_partial          | Phase 1, step cụ thể trong state  |
   | test_pending             | Phase 2 (TEST), Step 2.1          |
   | test_fixloop             | Phase 2, Step 2.3 (tiếp fix loop) |
   | test_mcp_verify          | Phase 2, Step 2.4                 |
   | test_record              | Phase 2, Step 2.5                 |
   | narrate_pending          | Phase 3 (NARRATE)                 |
   | spawn_pending            | Phase 4 (SPAWN NEXT)              |
   | (missing/unknown)        | Chạy Phase Completeness Audit     |
   |                          | (phase4-spawn-next.md Step 4.0)   |
   |                          | rồi route theo checklist kết quả  |

4. Không có session inprogress nào → về Step 0.5 claim WF pending kế tiếp.
```

## Quy tắc resume

- Không re-run step đã có artifact (idempotent check trước khi làm).
- test-status.json là SSOT của session — mọi step hoàn thành update ngay.
- Context > 70% giữa chừng → ghi checkpoint (E002) + hướng dẫn `--resume`.
