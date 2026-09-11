# §6 On Failure — Standard Format

> Áp dụng cho mọi phase. Khi POST-GATE fail hoặc step quan trọng fail.

```
ON FAILURE (BẮT BUỘC mỗi phase):

1. APPEND error-ledger.json (Atomic Write Pattern):
   {
     "phase": "[phase-id]",
     "error_code": "[E0XX]",
     "message": "[mô tả ngắn]",
     "timestamp": "ISO-8601",
     "retry_count": $RETRY_COUNT[$PHASE]
   }

2. AUTO-FIX qua Auto-Fix & Escalation Protocol (max 3 retries / phase).

3. Nếu vẫn fail sau retry:
   a. WRITE Phase{N}-report.md với status=FAILED + reason
   b. WRITE session-log.json entry FAIL (Execution Trace)
   c. UPDATE fix-status.json: phases.phase{N}.status = "failed"
   d. STOP pipeline + AskUserQuestion: "Re-run --resume / Cancel"

4. KHÔNG advance sang phase tiếp theo khi POST-GATE chưa pass.
```
