# §5 Auto-Fix & Escalation Protocol

> Áp dụng SAU mỗi POST-GATE. Mục tiêu: tự sửa lỗi nhỏ, không làm phiền user khi không cần.

```
WORKFLOW khi POST-GATE Tier T1-T4 fail:

BUDGET MODEL: PER-PHASE (max 3 retries total / phase).
  - Mỗi tier fail trigger 1 attempt fix → increment $RETRY_COUNT[$PHASE]
  - Khác tier cũng share 1 budget
  - Reset $RETRY_COUNT[$PHASE] = 0 khi POST-GATE PASS

1. ATTEMPT auto-fix theo Fix Rules:
   - T1 fail (file missing) → re-run step tạo file
   - T2 fail (structure wrong) → re-read template + populate lại
   - T3 fail (content too short) → re-generate với more context
   - T4 fail (cross-ref mismatch) → re-read source + re-write target

2. ESCALATE khi:
   - $RETRY_COUNT[$PHASE] >= 3 → STOP với error message
   - Hoặc auto-fix không khả thi

3. ESCALATION format:
   - Hiện AskUserQuestion với options: "Re-run phase" / "Skip (risky)" / "Cancel"
   - Append entry vào error-ledger.json
```

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `template_missing` | Đọc lại template từ git history | Không có history → escalate |
| `post_gate_t1_t4_fail` | Retry phase x1 với verbose logging | Vẫn fail → escalate |
| `agent_output_invalid` | Re-spawn agent x1 với prompt nhấn mạnh schema | Vẫn invalid → STOP |
| `context_overflow` | FORCE checkpoint, STOP | — |
| `lock_stale` | Auto-release, WARN, continue | — |
| `ci_detection_fail` | Fallback Grep/Glob | — |
