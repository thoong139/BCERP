# Phase 6: Preflight — Health Check

> Kiểm tra sức khỏe dự án sau khi implement features. Xử lý routing dựa trên kết quả (PASS/WARN/FAIL).

## PRE-GATE

- Phase 5b completed (hoặc E006: không có feature cần implement)
- Ít nhất 1 feature có `impl_status == "done"` HOẶC user confirm bỏ qua implement

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 6.1 | Hiển thị: `▶ Preflight: Kiểm tra Sức khỏe` | - | - |
| 6.2 | Verify `.claude/skills/workflow/wf-preflight/SKILL.md` tồn tại | Read | File exists (else E004) |
| 6.3 | Gọi `Skill("wf-preflight")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
test -f .mc-data/work/wf-preflight/preflight-report.md
```

### Parse kết quả Preflight

Đọc `preflight-report.md` → xác định status cuối: PASS / WARN / FAIL.

| Kết quả | Action |
|---------|--------|
| **PASS** | `✅ Preflight PASS` → tiếp tục Phase 7 (Verify) |
| **WARN** | Hiển thị danh sách warnings → hỏi user: *"Tiếp tục Verify? (yes/no)"* → yes → Phase 7; no → dừng, checkpoint |
| **FAIL** | Hiển thị errors → hiển thị recovery path đầy đủ → trigger E015 → dừng workflow, lưu checkpoint |

- `$STATUS_FILE.phases_completed += "preflight"`
- Nếu tiếp tục: `$STATUS_FILE.current_phase = "verify"`
- Nếu dừng (FAIL hoặc user chọn no sau WARN): giữ `current_phase = "preflight"` cho resume

## Transition

- **PASS:** `✅ Preflight hoàn thành — health check PASS` → Phase 7
- **WARN (tiếp tục):** `⚠ Preflight WARN — user confirmed tiếp tục` → Phase 7
- **WARN (dừng):**
  ```
  ⏸ Preflight WARN — workflow tạm dừng.

  Để tiếp tục sau khi xử lý warnings:
    → Chạy /feature-addition --resume
  ```
- **FAIL:**
  ```
  ❌ Preflight FAIL — [N] lỗi cần sửa trước khi tiếp tục.

  Lỗi phát hiện:
    [danh sách từ preflight-report.md]

  Bước tiếp theo:
    1. Chạy /wf-fix-bugs để sửa các lỗi trên
    2. Sau khi /wf-fix-bugs hoàn thành → chạy /feature-addition --resume
       (Workflow sẽ tiếp tục từ bước Preflight, chạy lại kiểm tra)

  Checkpoint đã lưu. Current phase: "preflight".
  ```

## Errors liên quan

- **E004** — wf-preflight SKILL.md không tồn tại
- **E015** — Preflight FAIL → stop + gợi ý fix-bugs

Chi tiết: `_shared.md §Error Handling Reference`.
