# Phase 4: Design UX (conditional)

> Thiết kế UX/UI. Tự động skip nếu `interface_type == "api-only"` hoặc user xác nhận
> UI không đổi. `wf-design-ux` shared skill tự detect legacy mode (CORE-021) và inject
> context — trích xuất UX từ code hiện có thay vì thiết kế mới.

## PRE-GATE

- Phase Annotate xong/skip (`phases_completed/skipped` chứa `"annotate"`)
- `pipeline_status == COMPLETE`
- `$INTERFACE_TYPE` đã load từ checkpoint

## Skip Detection (theo thứ tự — STOP ngay khi gặp điều kiện skip)

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/work/existing-project/checkpoint.json)
```

| Điều kiện | Action | Skip reason |
|-----------|--------|-------------|
| `INTERFACE_TYPE == "api-only"` | Hiển thị `⏭ Phase 4: Bỏ qua (API-only)` → persist + skip | `api-only` |
| Hỏi user: *"UI có thay đổi không? (yes/no)"* | Nếu `no` → `⏭ Phase 4: Bỏ qua (UI không đổi)` → persist + skip | `ui-unchanged` |

## Persist skip decision (G2)

```bash
SKIP_REASON="api-only"  # hoặc "ui-unchanged"

jq --arg r "$SKIP_REASON" '
  .phase_4_skip_reason = $r
  | .phases_skipped += ["phase4"]
  | .current_step = "phase5a"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Steps (chỉ chạy khi KHÔNG skip)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| ux.1 | Hiển thị: `▶ Phase 4: Thiết kế UX/UI` | - | - |
| ux.2 | Verify `.claude/skills/workflow/wf-design-ux/SKILL.md` tồn tại | Read | File exists (else E004) |
| ux.3 | Gọi `Skill("wf-design-ux")` — sub-skill tự detect legacy và inject context | Skill | Sub-skill POST-GATE pass |

## POST-GATE (chỉ khi không skip)

```bash
test -d .mc-data/docs/phase4-ux \
  && test -n "$(ls .mc-data/docs/phase4-ux/*.md 2>/dev/null)"
```

Nếu fail → E003 → retry sub-skill tối đa 3 lần.

## Status File Update (khi không skip)

```bash
jq '
  .phase_4_skip_reason = null
  | .phases_completed += ["phase4"]
  | .current_step = "phase5a"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

- **Skip:** `⏭ Phase 4 bỏ qua (lý do: [skip_reason])` → phase5a-plan
- **Done:** `✅ Phase 4 hoàn thành — UX docs created` → hỏi user xác nhận → phase5a-plan

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-design-ux SKILL.md không tồn tại (STOP)
- **E014** — sub-skill fail sau retry

Chi tiết: `_shared.md §Error Handling Reference`.
