# Phase Preflight: Health Check

> Kiểm tra sức khỏe toàn diện trước verify — code quality, architecture compliance, docs sync.
> Routing dựa trên kết quả: PASS → Verify; WARN → user confirm; FAIL → gợi ý `/wf-fix-bugs`.

## PRE-GATE

- Phase 5b xong/skip (ít nhất 1 feature có `impl_status == "done"` HOẶC `"skipped"`, HOẶC user confirm bỏ qua)

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| pf.1 | Hiển thị: `▶ Phase Preflight: Health Check toàn diện` | - | - |
| pf.2 | Verify `.claude/skills/workflow/wf-preflight/SKILL.md` tồn tại | Read | File exists (else E004) |
| pf.3 | Gọi `Skill("wf-preflight", args="--scope=all")` | Skill | Sub-skill POST-GATE pass |

## POST-GATE

```bash
test -f .mc-data/work/wf-preflight/preflight-report.md
```

Nếu fail → E013 → retry 1 lần; nếu vẫn fail → cho phép skip preflight với user xác nhận.

## Parse kết quả Preflight

Đọc `preflight-report.md` → xác định verdict cuối: PASS / WARN / FAIL.

```bash
VERDICT=$(grep -oE '(verdict|status):\s*(PASS|WARN|FAIL)' .mc-data/work/wf-preflight/preflight-report.md \
  | head -1 | grep -oE '(PASS|WARN|FAIL)')
```

| Kết quả | Action |
|---------|--------|
| **PASS** | `✅ Preflight PASS` → tiếp tục phase-verify |
| **WARN** | Hiển thị danh sách warnings → hỏi user: *"Tiếp tục Verify? (yes/no)"* → yes → phase-verify; no → dừng, checkpoint |
| **FAIL** | Hiển thị errors → gợi ý `/wf-fix-bugs` + trigger E015 → dừng workflow, lưu checkpoint |

## Status File Update

```bash
jq --arg v "$VERDICT" '
  .preflight_verdict = $v
  | .phases_completed += ["preflight"]
  | (.current_step = if $v == "FAIL" then "preflight" elif $v == "WARN" then "preflight" else "verify" end)
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

> **Lưu ý:** preflight-report.md là input cho `/wf-fix-bugs` nếu cần fix.
> Workflow: Preflight → (optional) Fix Bugs → Verify.

## Transition

- **PASS:** `✅ Preflight hoàn thành — health check PASS` → phase-verify
- **WARN (tiếp tục):** `⚠ Preflight WARN — user confirmed tiếp tục` → phase-verify
- **WARN (dừng):** `⏸ Preflight WARN — workflow tạm dừng. Dùng /existing-project --resume sau khi xử lý warnings.`
- **FAIL:** `❌ Preflight FAIL — gợi ý chạy /wf-fix-bugs trước khi resume.`

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-preflight SKILL.md không tồn tại (STOP)
- **E013** — preflight-report không tồn tại sau retry
- **E015** — Preflight FAIL → gợi ý fix-bugs

Chi tiết: `_shared.md §Error Handling Reference`.
