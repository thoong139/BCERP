# Auto-execution scripts

## `run-execution-prompt.sh` — Headless loop driver

Chạy `EXECUTION-PROMPT.md` tự động tới khi DONE. Mỗi iteration spawn 1 process Claude CLI mới (TAB mới thật sự, fresh context, không kế thừa context phiên trước).

### Cách chạy

Từ root MCV3 (`z:\Working\MCV3`), trong Git Bash hoặc WSL:

```bash
bash plans/wf-fix-bugs-dimensions-audit-v1/scripts/run-execution-prompt.sh
```

Script sẽ chạy nền 1 vòng lặp (MAX_ITER=50, timeout 90 phút/iter). Theo dõi qua master log:

```bash
tail -f plans/wf-fix-bugs-dimensions-audit-v1/logs/master-*.log
```

### Cấu hình qua env vars

```bash
# Test nhanh, không commit
NO_COMMIT=1 MAX_ITER=2 bash plans/.../scripts/run-execution-prompt.sh

# Dùng Opus thay Sonnet (khi Sonnet hết quota)
MODEL=opus bash plans/.../scripts/run-execution-prompt.sh

# Timeout 30 phút/iter (cho task nhỏ)
ITER_TIMEOUT_SEC=1800 bash plans/.../scripts/run-execution-prompt.sh
```

### Stop conditions (script tự dừng)

| Lý do | Hành động |
|---|---|
| `git tag plan-wf-fix-bugs-dimensions-audit-v1-DONE` đã tồn tại | exit 0 (PLAN COMPLETE) |
| Iteration không update `EXECUTION-PROMPT.md` | exit 1 (stuck — debug iter log) |
| Reach `MAX_ITER` | exit 2 (rerun để tiếp tục) |

### Logs

- `logs/master-<timestamp>.log` — tổng quan tất cả iterations
- `logs/iter-NNN-<timestamp>.log` — full output của từng phiên claude

Mỗi iteration claude chạy với:
- `--print` (headless, không TUI)
- `--dangerously-skip-permissions` (bypass mọi prompt — KHÔNG dùng cho việc untrusted)
- `--model sonnet` (configurable)
- 90 phút timeout (configurable)

### Phiên autonomous behavior

Prompt embedded trong script yêu cầu Claude:
- KHÔNG hỏi user (headless mode)
- Tự phân tích ≥2 phương án khi ambiguous, chọn theo CORE-023 (chất lượng > tốc độ), ghi rationale vào ACTIVITY LOG
- Gặp blocker thật → ghi vào BLOCKERS section + exit, không hang chờ
- 1 phiên = 1 task (không nhảy task)
- Cuối phiên BẮT BUỘC update EXECUTION-PROMPT.md + progress.md

### Auto-commit

Sau mỗi iteration thành công:
```
git add -A plans/wf-fix-bugs-dimensions-audit-v1/
git commit -m "auto-iter-N: <Current Task>"
```

Nếu cần tắt: `NO_COMMIT=1 bash ...`. Rollback: `git revert <commit-sha>` hoặc `git reset --hard HEAD~N`.

### Troubleshooting

**Script báo "EXECUTION-PROMPT.md KHÔNG được cập nhật":**
1. Mở iter log mới nhất (`logs/iter-NNN-*.log`)
2. Tìm error message từ claude (permission denied, file not found, ...)
3. Fix root cause → xóa backup `.bak` files nếu có → rerun script (nó sẽ resume từ Current Task)

**Quota hết giữa chừng:**
- Switch model: `MODEL=opus bash ...`
- Hoặc đợi quota reset → rerun (script idempotent qua state file)

**Cần dừng giữa chừng:**
- `Ctrl+C` master script — claude CLI con sẽ nhận SIGTERM, exit cleanly
- Iteration đang chạy có thể bị mất (file backup `.bak` còn) — kiểm tra:
  ```bash
  ls plans/wf-fix-bugs-dimensions-audit-v1/*.bak  # nếu có thì rollback
  ```
