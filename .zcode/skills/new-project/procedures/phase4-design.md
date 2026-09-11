# Bước 3 — Phase 3: Design Architecture

> Delegate đến `wf-design`. Thiết kế kiến trúc, API, DB design → Phase 3 docs.
> Sau khi hoàn thành, đọc `interface_type` từ registry để quyết định skip Bước 4 (UX).

**Sub-skill:** `wf-design`
**DEVKIT Phase:** Phase 3

## PRE-GATE

```bash
# Registry có ≥1 feature
jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E010
```

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Hiển thị: `▶ Bước 3 — Phase 3: Thiết kế Kiến trúc` | Output | — |
| 3.2 | VERIFY `.claude/skills/workflow/wf-design/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 3.3 | Gọi `Skill("wf-design")` — thực thi đầy đủ | Skill | — |
| 3.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |
| 3.5 | Đọc `interface_type` từ registry → lưu vào `$INTERFACE_TYPE` + status file | Bash | Saved |

## POST-GATE

```bash
# T1-T4 checks
test -f .mc-data/docs/phase3-architecture/stakeholder-review.md || exit_with E001
test -s .mc-data/docs/phase3-architecture/stakeholder-review.md || exit_with E001
jq -e '.design_status' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1 || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Đọc interface_type (sau POST-GATE)

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/docs/_meta/req-registry.json)
```

Fallback nếu `jq` không có (E012):
```bash
INTERFACE_TYPE=$(python -c "import json; d=json.load(open('.mc-data/docs/_meta/req-registry.json')); print(d.get('interface_type','web+mobile'))")
```

Ghi `interface_type` vào `$STATUS_FILE` để Bước 4 đọc lại.

## Checkpoint Update

Cập nhật `$STATUS_FILE`:
- `steps_completed += [3]`
- `interface_type = $INTERFACE_TYPE`
- `current_step = 4`
- `current_phase = "phase5-ux"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 4 — Phase 4: Design UX (hoặc skip nếu api-only)"`

## Transition

```
✅ Bước 3 hoàn thành — Phase 3: Architecture Design

interface_type = [web+mobile | api-only | web-only | mobile-only]

→ Next: Bước 4 — Phase 4: Design UX (phase5-ux.md)
   [nếu api-only → sẽ skip tự động]

Tiếp tục? (yes/no)
```

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu features[]) → báo user
- **E012** — `jq` không có → fallback python

Chi tiết: `_shared.md §Error Handling Reference`.
