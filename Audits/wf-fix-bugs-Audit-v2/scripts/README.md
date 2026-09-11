# Auto-execution scripts — Audit v2

## `run-execution-prompt.sh` — Headless loop driver

Chạy `EXECUTION-PROMPT.md` tự động tới khi DONE. Mỗi iteration spawn 1 process Claude CLI mới (fresh context).

### Cách chạy

Từ root MCV3 (`z:\Working\MCV3`), trong Git Bash hoặc WSL:

```bash
bash Audits/wf-fix-bugs-Audit-v2/scripts/run-execution-prompt.sh
```

### Cấu hình qua env vars

```bash
# Test nhanh, không commit
NO_COMMIT=1 MAX_ITER=2 bash Audits/wf-fix-bugs-Audit-v2/scripts/run-execution-prompt.sh

# Dùng Opus thay Sonnet
MODEL=opus bash Audits/wf-fix-bugs-Audit-v2/scripts/run-execution-prompt.sh

# Timeout 30 phút/iter
ITER_TIMEOUT_SEC=1800 bash Audits/wf-fix-bugs-Audit-v2/scripts/run-execution-prompt.sh
```

### Stop conditions

| Lý do | Hành động |
|---|---|
| `git tag audit-wf-fix-bugs-v2-DONE` đã tồn tại | exit 0 (PLAN COMPLETE) |
| Iteration không update `EXECUTION-PROMPT.md` | exit 1 (stuck — debug iter log) |
| Reach `MAX_ITER` | exit 2 (rerun để tiếp tục) |

### Logs

- `logs/master-<timestamp>.log` — tổng quan tất cả iterations
- `logs/iter-NNN-<timestamp>.log` — full output của từng phiên claude

## `check-gate.sh` — Gate verification

```bash
# Check specific gate
bash Audits/wf-fix-bugs-Audit-v2/scripts/check-gate.sh g0
bash Audits/wf-fix-bugs-Audit-v2/scripts/check-gate.sh g1

# Check all gates
bash Audits/wf-fix-bugs-Audit-v2/scripts/check-gate.sh all
```

## Theo dõi tiến độ

```bash
# Xem task hiện tại
grep "Current Task" Audits/wf-fix-bugs-Audit-v2/EXECUTION-PROMPT.md

# Xem activity log
grep -A100 "ACTIVITY LOG" Audits/wf-fix-bugs-Audit-v2/EXECUTION-PROMPT.md

# Xem CP coverage
grep -A20 "CP Coverage Tracker" Audits/wf-fix-bugs-Audit-v2/progress.md
```
