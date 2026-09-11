# Phase Scan: Legacy Scan Pipeline

> Scan codebase hiện có. `wf-legacy-scan` tự orchestrate 4 stages nội bộ:
> detect → classify → extract → synthesize. Output: `project-context.md`,
> `ledger.json (pipeline_status=COMPLETE)`, `impl-status-snapshot.json`.

## PRE-GATE

- Phase 0 completed (`"phase0"` trong `phases_completed[]`)
- Codebase tồn tại
- Nếu `$STATUS_FILE.legacy_pipeline_done == true` → SKIP toàn bộ phase này (đã COMPLETE từ run trước)

## Skip Logic

```bash
if jq -e '.legacy_pipeline_done == true' .mc-data/work/existing-project/checkpoint.json > /dev/null; then
  echo "⏭ Phase Scan: Bỏ qua (pipeline đã COMPLETE từ run trước)"
  # Cập nhật checkpoint
  jq '.phases_skipped += ["scan"] | .current_step = "brainstorm"' \
    .mc-data/work/existing-project/checkpoint.json > tmp && mv tmp .mc-data/work/existing-project/checkpoint.json
  # Chuyển sang phase-brainstorm
fi
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| s.1 | Hiển thị: `▶ Phase Scan: Legacy Scan Pipeline (detect → classify → extract → synthesize)` | - | - |
| s.2 | Verify `.claude/skills/workflow/wf-legacy-scan/SKILL.md` tồn tại | Read | File exists (else E004) |
| s.3 | Gọi `Skill("wf-legacy-scan")` — sub-skill tự orchestrate 4 stages | Skill | Sub-skill POST-GATE pass |
| s.4 | Đọc `$STRATEGY` từ ledger.json để cache vào status file | Read | Saved |

## POST-GATE (CORE-011 Forensic + CORE-021)

```bash
# 1. project-context.md tồn tại và có nội dung (CORE-021 — required cho LEGACY_MODE detection)
test -f .mc-data/work/legacy-scan/project-context.md \
  && test "$(wc -c < .mc-data/work/legacy-scan/project-context.md)" -gt 500

# 2. Ledger COMPLETE
test -f .mc-data/work/legacy-scan/ledger.json \
  && jq -e '.pipeline_status == "COMPLETE"' .mc-data/work/legacy-scan/ledger.json

# 3. impl-status-snapshot tồn tại
test -f .mc-data/work/legacy-scan/impl-status-snapshot.json
```

Nếu fail → E005: kiểm tra wf-legacy-scan chưa hoàn thành, hướng dẫn user chạy lại với `--resume`.

## Status File Update

```bash
STRATEGY=$(jq -r '.strategy // "S2:CODE-FIRST"' .mc-data/work/legacy-scan/ledger.json)

jq --arg s "$STRATEGY" '
  .strategy = $s
  | .phases_completed += ["scan"]
  | .current_step = "brainstorm"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase Scan hoàn thành
  Strategy: [S1-S7 detected]
  project-context.md: [size] bytes
  pipeline_status: COMPLETE

→ Next: phase-brainstorm (shared skills cluster Buoc 0b)
```

Hỏi user xác nhận trước khi vào cluster Buoc 0b.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-legacy-scan SKILL.md không tồn tại (STOP)
- **E005** — project-context.md / ledger / impl-status-snapshot thiếu hoặc invalid
- **E014** — sub-skill fail sau retry → STOP, hỏi user retry/skip/abort

Chi tiết: `_shared.md §Error Handling Reference`.
