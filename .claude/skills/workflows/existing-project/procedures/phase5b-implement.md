# Phase 5b: Implement Features (vòng lặp)

> Implement code cho từng feature theo kế hoạch. User có thể dừng/resume giữa vòng lặp —
> mỗi feature là 1 checkpoint. `wf-implement-feature` tự áp dụng Pre-Implementation Safety
> Gate (CORE-020) và route theo implementation_strategy từ task file (CORE-019 — LEGACY_MODE).

## PRE-GATE

- Phase 5a completed (`test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md`)
- Registry có features

## Preparation

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5b.0 | Đọc registry → lọc features chưa `impl_status == "done"` → `$PENDING_FEATURES[]` | Read | List built |
| 5b.0b | Nếu `$PENDING_FEATURES` rỗng → tất cả đã done → set `current_step = "preflight"` → skip | - | - |
| 5b.0c | Hiển thị danh sách features cần implement + tổng số | - | Displayed |

### Overview hiển thị

```
▶ Phase 5b: Triển khai Code
Tìm thấy [N] features cần implement:
  1. [feature-name-1] (FEAT-XXX)
  2. [feature-name-2] (FEAT-YYY)
  ...

Bắt đầu implement từng feature. Sau mỗi feature bạn có thể dừng và tiếp tục sau.
```

## Vòng lặp per feature

```
Cho mỗi FEAT_ID trong $PENDING_FEATURES (theo order từ roadmap):

  1. Hiển thị: `▶ Implement: [feature-name] ([i]/[total])`
  2. Verify .claude/skills/workflow/wf-implement-feature/SKILL.md tồn tại (else E004)
  3. Gọi Skill("wf-implement-feature", args=[feature-name])
  4. POST-GATE per-feature:
     jq -e --arg id "$FEAT_ID" \
       '.requirements[] | select(.id==$id) | .impl_status == "done"' \
       .mc-data/docs/_meta/req-registry.json
     NOTE: impl_status tracked ở requirements[] (theo CORE-006 fields_owned)
  5. Nếu POST-GATE fail → trigger E008 (hỏi user: retry hoặc skip)
  6. Cập nhật $STATUS_FILE.phase_5b_progress (xem §Checkpoint Update)
  7. Hỏi user: "Tiếp tục feature tiếp theo? (yes / no / skip)"
     - yes  → loop tiếp
     - skip → ghi impl_status: "skipped" trong registry cho feature này, loop tiếp
     - no   → dừng loop, lưu checkpoint, trigger E007
```

## Checkpoint Update sau mỗi feature (G1)

```bash
# Khi feature done:
jq --arg id "$FEAT_ID" '
  .phase_5b_progress.completed += [$id]
  | .phase_5b_progress.next_feature = "[FEAT_ID kế tiếp hoặc null]"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json

# Khi feature skip:
jq --arg id "$FEAT_ID" '
  .phase_5b_progress.skipped += [$id]
  | .phase_5b_progress.next_feature = "[FEAT_ID kế tiếp hoặc null]"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json

# Khi user dừng (no):
jq --arg id "$FEAT_ID" '
  .phase_5b_progress.next_feature = $id
  | .current_step = "phase5b"
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
exit_with E007
```

## LEGACY_MODE Guardrail (CORE-020 + CORE-019)

`wf-implement-feature` tự áp dụng Pre-Implementation Safety Gate và đọc
`implementation_strategy` từ task file. Orchestrator KHÔNG override — chỉ truyền
đúng `feature-name` argument.

Modules trong `$DEPRECATED_MODULES` đã được sub-skills upstream filter ra khỏi registry.features
→ vòng lặp này không gặp deprecated features.

## POST-GATE (khi hết vòng lặp)

```bash
# Ít nhất 1 feature có impl_status == "done" HOẶC user confirm bỏ qua
DONE_COUNT=$(jq '[.requirements[] | select(.impl_status=="done")] | length' \
  .mc-data/docs/_meta/req-registry.json)
test "$DONE_COUNT" -ge 1
```

Nếu `DONE_COUNT == 0` (user skip tất cả): WARNING — vẫn cho phép tiếp tục Preflight.

## Status File Update (khi hết vòng lặp)

```bash
jq '
  .phases_completed += ["phase5b"]
  | .current_step = "preflight"
  | .phase_5b_progress.next_feature = null
  | .updated_at = (now | todate)
' .mc-data/work/existing-project/checkpoint.json > tmp \
  && mv tmp .mc-data/work/existing-project/checkpoint.json
```

## Transition

```
✅ Phase 5b kết thúc — [M]/[N] features implemented (skipped: [S])

→ Next: phase-preflight
```

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-implement-feature SKILL.md không tồn tại (STOP)
- **E007** — User dừng giữa vòng lặp → lưu checkpoint, thoát workflow
- **E008** — Individual feature POST-GATE fail → hỏi skip/retry
- **E011** — Context overflow → force checkpoint ngay sau feature hiện tại

Chi tiết: `_shared.md §Error Handling Reference`.
