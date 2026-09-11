# Bước 4 — Phase 4: Design UX (conditional)

> Delegate đến `wf-design-ux`. Thiết kế UX/UI → Phase 4 docs.
> **SKIP CONDITION:** Nếu `interface_type == "api-only"` → skip toàn bộ, không chạy sub-skill.

**Sub-skill:** `wf-design-ux`
**DEVKIT Phase:** Phase 4

## PRE-GATE

```bash
# Phase 3 output phải có
test -f .mc-data/docs/phase3-architecture/stakeholder-review.md || exit_with E010
test -s .mc-data/docs/phase3-architecture/stakeholder-review.md || exit_with E010
```

## Skip Decision

```bash
# Đọc interface_type từ registry (hoặc status file đã cache)
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/docs/_meta/req-registry.json)

if [ "$INTERFACE_TYPE" = "api-only" ]; then
  # SKIP
  echo "Phase 4: Bỏ qua (API-only project)"
  # Cập nhật status file: steps_skipped += [4], phase5_skipped = true
  → Checkpoint Update (SKIP branch)
  → KHÔNG chạy POST-GATE
  → Transition sang Bước 5
  EXIT với status SKIPPED
fi
```

## Steps (chỉ chạy khi KHÔNG skip)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | Hiển thị: `▶ Bước 4 — Phase 4: Thiết kế UX/UI` | Output | — |
| 4.2 | VERIFY `.claude/skills/workflow/wf-design-ux/SKILL.md` tồn tại | Read | File loaded hoặc E004 |
| 4.3 | Gọi `Skill("wf-design-ux")` — thực thi đầy đủ | Skill | — |
| 4.4 | Đợi sub-skill hoàn thành POST-GATE nội bộ | - | Sub-skill done |

## POST-GATE (chỉ chạy khi phase KHÔNG bị skip)

```bash
test -f .mc-data/docs/phase4-ux/stakeholder-review.md || exit_with E001
test -s .mc-data/docs/phase4-ux/stakeholder-review.md || exit_with E001
jq -e '.ux_design_status' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1 || exit_with E001
```

Nếu POST-GATE fail → retry sub-skill (max 3 lần). Vẫn fail → E001.

## Checkpoint Update

### Nhánh RUN (phase chạy bình thường)

Cập nhật `$STATUS_FILE`:
- `steps_completed += [4]`
- `phase5_skipped = false`
- `current_step = 5`
- `current_phase = "phase6-plan"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 5 — Phase 5a: Plan Modules"`

### Nhánh SKIP (api-only)

Cập nhật `$STATUS_FILE`:
- `steps_skipped += [4]`
- `phase5_skipped = true`
- `current_step = 5`
- `current_phase = "phase6-plan"`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 5 — Phase 5a: Plan Modules (skip Phase 4 do api-only)"`

## Transition

```
✅ Bước 4 hoàn thành — Phase 4: UX/UI Design   (hoặc: ⏭ Bước 4 bỏ qua — API-only project)

→ Next: Bước 5 — Phase 5a: Plan Modules (phase6-plan.md)

Tiếp tục? (yes/no)
```

## Errors liên quan

- **E001** — POST-GATE fail sau 3 retries → STOP
- **E002** — User dừng → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E010** — Prerequisite fail (thiếu Phase 3 output) → báo user
- **E012** — `jq` không có → fallback python

Chi tiết: `_shared.md §Error Handling Reference`.
